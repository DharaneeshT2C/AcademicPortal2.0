import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import getServiceName from '@salesforce/apex/KenServiceBreadcrumbController.getServiceName';

// Label mapping for special cases
const LABEL_MAP = {
    'event': 'Event',
    'host-event': 'Host Event',
    'service-support': 'Service and Support',
    'requestservice': 'Request for a service',
    'requestservicedetailview': null // Will be replaced with service name
};

// Mapping of detail view segments to their parent segments
// This ensures intermediate steps are shown in breadcrumbs
// Format: 'detailview-segment': 'parent-segment'
const DETAIL_VIEW_PARENTS = {
    'requestservicedetailview': 'requestservice'
    // Add more mappings as needed: 
    // 'eventdetailview': 'event',
    // 'jobdetailview': 'job'
};

const BASE_PATH = '/alumni';
let hasInjectedBreadcrumbStyles = false;

export default class KenBreadcrumb extends NavigationMixin(LightningElement) {
    @track breadcrumbItems = [];
    @track isLoadingServiceName = false;

    currentPageRef;

    connectedCallback() {
        // Build breadcrumbs on initial load
        this.buildBreadcrumbs();
        // Inject global styles for breadcrumb
        this.injectBreadcrumbStyles();
    }

    injectBreadcrumbStyles() {
        if (hasInjectedBreadcrumbStyles) {
            return;
        }

        const style = document.createElement('style');
        style.textContent = `
            .slds-breadcrumb .slds-breadcrumb__item > a,
            .slds-breadcrumb__item > a,
            [part="breadcrumb"] {
                font-size: 14px !important;
                font-weight: 400 !important;
                color: #373A45 !important;
            }
            .slds-breadcrumb__item > a:hover,
            [part="breadcrumb"]:hover {
                color: #373A45 !important;
                text-decoration: underline;
            }
        `;
        document.head.appendChild(style);
        hasInjectedBreadcrumbStyles = true;
    }

    @wire(CurrentPageReference)
    setCurrentPageReference(pageRef) {
        if (pageRef) {
            this.currentPageRef = pageRef;
            this.buildBreadcrumbs();
        }
    }

    get hasBreadcrumbs() {
        // Only show breadcrumbs when there are 2+ segments (sub-pages)
        // Don't show on main pages like /alumni/service-support (only 1 segment)
        const path = this.getPathFromUrl();
        const segments = this.parsePathSegments(path);
        const hasMultipleSegments = segments.length > 1;
        return hasMultipleSegments && this.breadcrumbItems && this.breadcrumbItems.length > 0;
    }

    dispatchBreadcrumbVisibility(isVisible) {
        this.dispatchEvent(new CustomEvent('breadcrumbvisibilitychange', {
            detail: { isVisible },
            bubbles: true,
            composed: true
        }));
    }

    get segmentCount() {
        const path = this.getPathFromUrl();
        const segments = this.parsePathSegments(path);
        return segments.length;
    }

    buildBreadcrumbs() {
        // Get path from URL (most reliable in Experience Cloud)
        const path = this.getPathFromUrl();
        
        // Get query params from URL or page reference
        const urlParams = new URLSearchParams(window.location?.search || '');
        const serviceId = urlParams.get('serviceId') || 
                         urlParams.get('serviceld') ||
                         (this.currentPageRef?.state?.serviceId) ||
                         (this.currentPageRef?.state?.serviceld);

        // Parse path segments
        const segments = this.parsePathSegments(path);
        
        // Debug logging
        console.log('Breadcrumb - Path:', path);
        console.log('Breadcrumb - Segments:', segments);
        
        // If no segments or only 1 segment (main page), don't show breadcrumbs
        // Only show breadcrumbs on sub-pages (2+ segments)
        if (segments.length <= 1) {
            this.breadcrumbItems = [];
            // Notify parent that breadcrumb is not visible
            this.dispatchBreadcrumbVisibility(false);
            return;
        }
        
        // Build breadcrumb items
        const items = [];
        let cumulativePath = BASE_PATH;

        // Add Home (optional - only if there are other segments)
        if (segments.length > 0) {
            items.push({
                id: 'home',
                label: 'Home',
                href: BASE_PATH,
                isClickable: true
            });
        }

        // Process each segment with intermediate segment insertion
        for (let i = 0; i < segments.length; i++) {
            const segment = segments[i];
            const isLast = i === segments.length - 1;
            
            // Check if this segment has a parent that should be inserted before it
            // This ensures intermediate steps are shown (e.g., requestservice before requestservicedetailview)
            // This works dynamically for any segment defined in DETAIL_VIEW_PARENTS
            if (Object.prototype.hasOwnProperty.call(DETAIL_VIEW_PARENTS, segment)) {
                const parentSegment = DETAIL_VIEW_PARENTS[segment];
                
                // Check if parent segment is not already in the path
                const parentExists = segments.slice(0, i).includes(parentSegment);
                
                if (!parentExists) {
                    // Insert the parent segment before the detail view
                    const parentLabel = this.getLabelForSegment(parentSegment);
                    cumulativePath = `${cumulativePath}/${parentSegment}`;
                    
                    items.push({
                        id: `segment-${i}-parent`,
                        label: parentLabel,
                        href: cumulativePath,
                        isClickable: true, // Parent is always clickable (not the last item)
                        segment: parentSegment
                    });
                }
            }
            
            // Check if this is requestservicedetailview and we need to fetch service name
            if (segment === 'requestservicedetailview' && isLast && serviceId) {
                // Will be handled separately after fetching service name
                cumulativePath = `${cumulativePath}/${segment}`;
                items.push({
                    id: `segment-${i}`,
                    label: 'Loading...',
                    href: cumulativePath,
                    isClickable: false,
                    segment: segment,
                    serviceId: serviceId,
                    isServiceDetail: true
                });
                this.fetchServiceName(serviceId, items, items.length - 1);
            } else {
                const label = this.getLabelForSegment(segment);
                cumulativePath = `${cumulativePath}/${segment}`;
                
                items.push({
                    id: `segment-${i}`,
                    label: label,
                    href: cumulativePath,
                    isClickable: !isLast,
                    segment: segment
                });
            }
        }

        this.breadcrumbItems = items;
        console.log('Breadcrumb - Items:', items);
        
        // Dispatch visibility change after building breadcrumbs
        const hasMultipleSegments = segments.length > 1;
        this.dispatchBreadcrumbVisibility(hasMultipleSegments && items.length > 0);
    }

    async fetchServiceName(serviceId, items, itemIndex) {
        if (!serviceId) return;

        this.isLoadingServiceName = true;
        try {
            const serviceName = await getServiceName({ serviceId: serviceId });
            if (items[itemIndex]) {
                items[itemIndex].label = serviceName || 'Service Detail';
                this.breadcrumbItems = [...items];
            }
        } catch (error) {
            console.error('Error fetching service name:', error);
            if (items[itemIndex]) {
                items[itemIndex].label = 'Service Detail';
                this.breadcrumbItems = [...items];
            }
        } finally {
            this.isLoadingServiceName = false;
        }
    }

    parsePathSegments(path) {
        if (!path) {
            console.log('Breadcrumb - No path provided');
            return [];
        }

        console.log('Breadcrumb - Parsing path:', path);

        // Remove leading/trailing slashes
        const cleanPath = path.replace(/^\/+|\/+$/g, '');
        if (!cleanPath) {
            console.log('Breadcrumb - Path is empty after cleaning');
            return [];
        }

        // Handle Experience Cloud paths that might include /s/ segment
        // e.g., /alumni/s/event or /alumni/event
        const pathParts = cleanPath.split('/').filter(p => p && p.trim() !== '');
        console.log('Breadcrumb - Path parts:', pathParts);
        
        const alumniIndex = pathParts.indexOf('alumni');
        
        if (alumniIndex >= 0) {
            // Get everything after 'alumni'
            const afterAlumni = pathParts.slice(alumniIndex + 1);
            // Filter out 's' if it exists (Experience Cloud routing segment)
            const segments = afterAlumni.filter(seg => seg && seg !== 's' && seg.trim() !== '');
            console.log('Breadcrumb - Segments after alumni:', segments);
            return segments;
        }

        // If path doesn't contain 'alumni', try to extract segments directly
        // This handles cases where the path might be relative
        const segments = pathParts.filter(seg => seg && seg !== 's' && seg.trim() !== '');
        console.log('Breadcrumb - Segments (no alumni found):', segments);
        
        return segments;
    }

    getLabelForSegment(segment) {
        if (!segment) return '';

        // Check if there's a mapping
        if (Object.prototype.hasOwnProperty.call(LABEL_MAP, segment)) {
            const mappedLabel = LABEL_MAP[segment];
            if (mappedLabel !== null) {
                return mappedLabel;
            }
            // If mapped to null, fall through to slug conversion
        }

        // Convert slug to friendly label
        return this.slugToLabel(segment);
    }

    slugToLabel(slug) {
        if (!slug) return '';

        return slug
            .split('-')
            .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
            .join(' ');
    }

    getPathFromUrl() {
        if (typeof window === 'undefined' || !window.location) {
            return '';
        }
        // Get pathname and remove query string/hash
        const pathname = window.location.pathname || '';
        return pathname;
    }

    handleBreadcrumbClick(event) {
        event.preventDefault();
        event.stopPropagation();
        this.navigateToBreadcrumb(event.currentTarget);
    }

    handleBreadcrumbKeyDown(event) {
        // Handle Enter and Space keys for keyboard navigation
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            event.stopPropagation();
            this.navigateToBreadcrumb(event.currentTarget);
        }
    }

    navigateToBreadcrumb(element) {
        const href = element.dataset.href || element.getAttribute('href');
        const isClickable = element.dataset.clickable === 'true';
        
        if (!href || !isClickable) return;

        // Find the breadcrumb item
        const item = this.breadcrumbItems.find(b => b.href === href);
        if (!item || !item.isClickable) return;

        // Navigate using NavigationMixin
        // Try standard__webPage first, fallback to URL navigation
        try {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: href
                },
                replace: true
            });
        } catch (error) {
            // Fallback to direct navigation
            console.warn('NavigationMixin failed, using direct navigation:', error);
            if (window.location) {
                window.location.href = href;
            }
        }
    }
}