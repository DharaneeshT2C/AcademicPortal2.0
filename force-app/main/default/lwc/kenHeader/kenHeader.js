import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { MessageContext } from 'lightning/messageService';
// import KenLogo from '@salesforce/resourceUrl/LoginKen';
import KenLogo from '@salesforce/resourceUrl/KenLogo';
import getNavigationMenuItems from '@salesforce/apex/KenHeaderController.getNavigationMenuItems';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';
// import loginBg from '@salesforce/resourceUrl/AlumniAlt';

const THEME_PRIMARY_STORAGE_KEY = 'ken_theme_primary';
const THEME_SECONDARY_STORAGE_KEY = 'ken_theme_secondary';
const BREADCRUMB_PARENT_MAP = {
    'courseenrollmentdetails': 'course-enrolment',
    'pathway-type-configuration': 'course-enrolment',
    'coursebroucher': 'courseenrollmentdetails',
    'pathway-configuration': 'courseenrollmentdetails',
    'courseparticulardetails': 'pathway-configuration',
    'courseafterenrollment': 'course-enrolment'
};
const BREADCRUMB_LABEL_MAP = {
    'course-enrolment': 'Course Enrolment',
    'courseenrollmentdetails': 'Course Enrolment Details',
    'pathway-type-configuration': 'Pathway Type Configuration',
    'coursebroucher': 'Course Broucher',
    'pathway-configuration': 'Pathway Configuration',
    'courseparticulardetails': 'Course Particular Details',
    'courseafterenrollment': 'Course After Enrollment'
};
const ENROLLMENT_FLOW_SEGMENTS = new Set([
    'course-enrolment',
    'courseenrollmentdetails',
    'pathway-type-configuration',
    'coursebroucher',
    'pathway-configuration',
    'courseparticulardetails',
    'courseafterenrollment'
]);

const ROOT_ROUTE_SEGMENTS = new Set([
    'home',
    'feed',
    'events',
    'jobs',
    'mentorship',
    ...ENROLLMENT_FLOW_SEGMENTS
]);

function resolveCommunityBasePath(pathname) {
    const safePathname =
        typeof pathname === 'string' && pathname.trim()
            ? pathname
            : typeof window !== 'undefined' && window.location
                ? window.location.pathname || '/'
                : '/';
    const segments = safePathname.split('/').filter(Boolean);
    if (!segments.length) {
        return '/';
    }

    const routingIndex = segments.findIndex((segment) => segment.toLowerCase() === 's');
    if (routingIndex === 0) {
        return '/';
    }
    if (routingIndex > 0) {
        return `/${segments[routingIndex - 1]}`;
    }

    const [firstSegment] = segments;
    if (segments.length === 1 && ROOT_ROUTE_SEGMENTS.has(firstSegment.toLowerCase())) {
        return '/';
    }

    return `/${firstSegment}`;
}

export default class KenHeader extends NavigationMixin(LightningElement) {
    static DEFAULT_PRIMARY = '#3061FF';
    static DEFAULT_SECONDARY = '#EAEFFF';

    @wire(MessageContext)
    messageContext;

    kenLogo = KenLogo;
    profilePhotoUrl;
    studentName;
    @api headerLabel;
    @api linkSetMasterLabel = 'Default Navigation';
    @api parentPageName = 'Home';
    @api parentPageApiName = 'Home';
    @api parentPageUrl;
    @api childPageName;
    @api childPageUrl;

    @track dynamicHeaderLabel = '';
    @track menuItems = [];
    @track breadcrumbLabel = '';
    @track breadcrumbs = [];
    @track hasBreadcrumbVisible = false;
    publishStatus;
    organizationDefaults = {};
    themeLoading = true;

    @wire(CurrentPageReference)
    setCurrentPageReference(ref) {
        const app = ref?.state?.app;
        this.publishStatus = app === 'commeditor' ? 'Draft' : 'Live';
        this.updateHeaderLabel();
    }

    @wire(getNavigationMenuItems, {
        navigationLinkSetMasterLabel: '$linkSetMasterLabel',
        publishStatus: '$publishStatus',
        addHomeMenuItem: false,
        includeImageUrl: false
    })
    wiredMenuItems() {
        // Hardcoded data
        const hardcodedData = [
            { label: 'Home', actionValue: '/home' },
            { label: 'My Feed', actionValue: '/feed' },
            { label: 'Events', actionValue: '/events' },
            { label: 'Jobs', actionValue: '/jobs' },
            { label: 'Mentorship', actionValue: '/mentorship' }
        ];

        const base = this.getCommunityBasePath();
        this.menuItems = hardcodedData.map(item => {
            const normalizedTarget = this.normalizePath(
                item.actionValue || (item.label === 'Home' ? base : ''),
                base
            );
            return {
                label: item.label,
                normalizedTarget
            };
        });
        this.updateHeaderLabel();
    }

    wiredUserDetails() {
        this.profilePhotoUrl = 'data:image/svg+xml;charset=utf-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%22100%22%20height%3D%22100%22%20viewBox%3D%220%200%20100%20100%22%3E%3Ccircle%20cx%3D%2250%22%20cy%3D%2250%22%20r%3D%2250%22%20fill%3D%22%23ccc%22%2F%3E%3Ccircle%20cx%3D%2250%22%20cy%3D%2240%22%20r%3D%2220%22%20fill%3D%22%23fff%22%2F%3E%3Cpath%20d%3D%22M20%2090%20Q50%2060%2080%2090%22%20fill%3D%22%23fff%22%2F%3E%3C%2Fsvg%3E';
        this.studentName = 'Rashi Gupta';
    }

    applyOrganizationTheme(primary, secondary) {
        const resolvedPrimary = this.resolveThemeColor(primary || this.organizationDefaults?.primary, KenHeader.DEFAULT_PRIMARY);
        const resolvedSecondary = this.resolveThemeColor(secondary || this.organizationDefaults?.secondary, KenHeader.DEFAULT_SECONDARY);

        if (!this.template?.host) {
            return;
        }

        this.template.host.style.setProperty('--primary-color', resolvedPrimary);
        this.template.host.style.setProperty('--secondary-color', resolvedSecondary);
    }

    @wire(OrganizationDefaultsApiController)
    wiredOrganizationDefaults({ data, error }) {
        if (data) {
            this.organizationDefaults = data;
            const resolvedPrimary = this.resolveThemeColor(data.primary, KenHeader.DEFAULT_PRIMARY);
            const resolvedSecondary = this.resolveThemeColor(data.secondary, KenHeader.DEFAULT_SECONDARY);
            this.storeTheme(resolvedPrimary, resolvedSecondary);
            this.applyOrganizationTheme(resolvedPrimary, resolvedSecondary);
            this.themeLoading = false;
            return;
        }
        if (error) {
            this.organizationDefaults = {};
            this.applyOrganizationTheme();
            this.themeLoading = false;
        }
    }

    connectedCallback() {
        const storedTheme = this.getStoredTheme();
        if (storedTheme) {
            this.applyOrganizationTheme(storedTheme.primary, storedTheme.secondary);
            this.themeLoading = false;
            return;
        }

        this.applyOrganizationTheme();
        Promise.resolve().then(() => {
            if (this.themeLoading) {
                this.themeLoading = false;
            }
        });
    }

    resolveThemeColor(value, fallback) {
        if (typeof value === 'string' && value.trim()) {
            return value.trim();
        }
        return fallback;
    }

    getStoredTheme() {
        try {
            const primary = window.localStorage.getItem(THEME_PRIMARY_STORAGE_KEY);
            const secondary = window.localStorage.getItem(THEME_SECONDARY_STORAGE_KEY);
            if (!primary && !secondary) {
                return null;
            }
            return {
                primary: this.resolveThemeColor(primary, KenHeader.DEFAULT_PRIMARY),
                secondary: this.resolveThemeColor(secondary, KenHeader.DEFAULT_SECONDARY)
            };
        } catch {
            return null;
        }
    }

    storeTheme(primary, secondary) {
        try {
            window.localStorage.setItem(THEME_PRIMARY_STORAGE_KEY, primary);
            window.localStorage.setItem(THEME_SECONDARY_STORAGE_KEY, secondary);
        } catch {
            // no-op
        }
    }

    get computedHeaderLabel() {
        return this.headerLabel || this.dynamicHeaderLabel || '';
    }

    get pageTitle() {
        if (this.headerLabel) return this.headerLabel;
        if (this.childPageName) return this.childPageName;
        return this.dynamicHeaderLabel || this.breadcrumbLabel || '';
    }

    get computedBreadcrumbs() {
        // If explicit child is set via API properties, build breadcrumbs from props
        if (this.childPageName) {
            const base = this.getCommunityBasePath();
            return [
                {
                    id: 'parent-0',
                    label: this.parentPageName || 'Home',
                    url: this.parentPageUrl || base,
                    pageName: this.parentPageApiName || 'Home',
                    clickable: true,
                    isLast: false,
                    hasNext: true,
                    cssClass: 'breadcrumb-link'
                },
                {
                    id: 'child-1',
                    label: this.childPageName,
                    url: this.childPageUrl || '',
                    pageName: '',
                    clickable: false,
                    isLast: true,
                    hasNext: false,
                    cssClass: 'breadcrumb-leaf'
                }
            ];
        }
        // Fall back to URL-based breadcrumbs
        return (this.breadcrumbs || []).map((crumb, index) => ({
            ...crumb,
            id: `crumb-${index}`
        }));
    }

    get hasComputedBreadcrumbs() {
        return this.computedBreadcrumbs && this.computedBreadcrumbs.length > 1;
    }

    handleBreadcrumbClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const pageName = event.currentTarget.dataset.pagename;
        const url = event.currentTarget.dataset.url;

        // Special handling for Home to stay within the community base path
        // Using window.location.assign for Home to prevent Salesforce's router from 
        // redirecting to /blank or other internal versions in sandbox previews.
        if (pageName === 'Home' && url) {
            try {
                window.location.assign(url);
            } catch {
                window.location.href = url;
            }
        } else if (pageName && pageName !== 'undefined') {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: pageName
                }
            });
        } else if (url) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: url
                }
            });
        }
    }

    handleBreadcrumbKeyDown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            this.handleBreadcrumbClick(event);
        }
    }

    get myFeedCardClass() {
        return this.hasComputedBreadcrumbs 
            ? 'my-feed-card has-breadcrumb' 
            : 'my-feed-card';
    }

    handleCalendarClick() {
        const basePath = this.getCommunityBasePath();
        const targetUrl = this.normalizePath('my-schedule', basePath);
        window.open(targetUrl, '_self');
    }

    handleSettingsClick() {
        const basePath = this.getCommunityBasePath();
        const targetUrl = this.normalizePath('settings', basePath);
        window.open(targetUrl, '_self');
    }

    handleNotificationClick() {
        // Handle notification click
        this.dispatchEvent(new CustomEvent('notificationclick', {
            bubbles: true,
            composed: true
        }));
    }

    @track isMobileMenuOpen = false;

    handleMenuClick() {
        console.log('KenHeader: Menu clicked (Local toggle)');
        this.isMobileMenuOpen = true;
    }

    handleCloseMenu() {
        this.isMobileMenuOpen = false;
    }

    handleBreadcrumbVisibilityChange(event) {
        this.hasBreadcrumbVisible = event.detail.isVisible;
    }

    updateHeaderLabel() {
        const base = this.getCommunityBasePath();
        const currentPath = this.normalizePath(window.location?.pathname || '/', base);

        this.updateBreadcrumbLabel(currentPath, base);

        if (!this.menuItems?.length) {
            return;
        }

        let bestMatch = { label: '', score: -1 };

        this.menuItems.forEach(item => {
            const target = item.normalizedTarget;
            if (!target) return;

            if (target === currentPath) {
                const score = target.length + 1000;
                if (score > bestMatch.score) bestMatch = { label: item.label, score };
            } else if (currentPath.startsWith(target + '/')) {
                const score = target.length;
                if (score > bestMatch.score) bestMatch = { label: item.label, score };
            }
        });

        this.dynamicHeaderLabel = bestMatch.label || '';
    }

    updateBreadcrumbLabel(currentPath, communityBasePath) {
        if (!currentPath) {
            this.breadcrumbLabel = '';
            this.breadcrumbs = [];
            return;
        }

        let pathAfterBase = currentPath;
        if (communityBasePath && currentPath.startsWith(communityBasePath)) {
            pathAfterBase = currentPath.slice(communityBasePath.length);
        }

        const segments = pathAfterBase.split('/').filter(seg => {
            const s = seg?.toLowerCase();
            return s && s !== 'home' && s !== 'index';
        });
        const normalizedSegments = segments.map(seg => String(seg).toLowerCase());
        const isEnrollmentFlow = normalizedSegments.some(seg => ENROLLMENT_FLOW_SEGMENTS.has(seg));
        const basePath = communityBasePath || '/';

        const crumbs = [
            {
                label: 'Home',
                url: basePath,
                clickable: segments.length > 0,
                isLast: segments.length === 0
            }
        ];

        if (segments.length && isEnrollmentFlow) {
            const flowSegments = this.expandSegmentsWithParents(normalizedSegments);
            const flowQuery = this.buildEnrollmentFlowQuery();
            flowSegments.forEach((seg, index) => {
                const targetPath = this.normalizePath(`${basePath}/${seg}`, basePath);
                crumbs.push({
                    label: this.getMappedBreadcrumbLabel(seg),
                    url: `${targetPath}${flowQuery}`,
                    clickable: index < flowSegments.length - 1,
                    isLast: index === flowSegments.length - 1
                });
            });
        } else if (segments.length) {
            let cumulativePath = basePath;
            segments.forEach((seg, index) => {
                const decoded = decodeURIComponent(seg);
                const label = this.formatBreadcrumbLabel(decoded);
                cumulativePath = this.normalizePath(`${cumulativePath}/${decoded}`, basePath);

                crumbs.push({
                    label,
                    url: cumulativePath,
                    clickable: index < segments.length - 1,
                    isLast: index === segments.length - 1
                });
            });
        }

        this.breadcrumbs = crumbs.map((crumb, index) => ({
            ...crumb,
            hasNext: index < crumbs.length - 1
        }));
        this.breadcrumbLabel = crumbs.length ? crumbs[crumbs.length - 1].label : '';
        this.breadcrumbs = crumbs.map((crumb, index) => ({
            ...crumb,
            hasNext: index < crumbs.length - 1,
            cssClass: crumb.isLast ? 'breadcrumb-leaf' : 'breadcrumb-link'
        }));
    }

    expandSegmentsWithParents(segments = []) {
        const expanded = [];
        const seen = new Set();

        const addWithParents = (segment) => {
            const normalized = String(segment || '').toLowerCase();
            if (!normalized || seen.has(normalized)) {
                return;
            }
            const parent = BREADCRUMB_PARENT_MAP[normalized];
            if (parent) {
                addWithParents(parent);
            }
            seen.add(normalized);
            expanded.push(normalized);
        };

        segments.forEach(addWithParents);
        return expanded;
    }

    buildEnrollmentFlowQuery() {
        const params = new URLSearchParams(window.location?.search || '');
        const semester = params.get('semester') || params.get('c__semester');
        const academicSessionId = params.get('academicSessionId') || params.get('c__academicSessionId');
        const query = new URLSearchParams();

        if (semester) {
            query.set('semester', semester);
        }
        if (academicSessionId) {
            query.set('academicSessionId', academicSessionId);
        }

        const queryString = query.toString();
        return queryString ? `?${queryString}` : '';
    }

    getMappedBreadcrumbLabel(segment) {
        const normalized = String(segment || '').toLowerCase();
        const mapped = BREADCRUMB_LABEL_MAP[normalized];
        if (mapped) {
            return mapped;
        }
        return this.formatBreadcrumbLabel(normalized);
    }

    formatBreadcrumbLabel(segment) {
        return segment
            .replace(/[-_]/g, ' ')
            .replace(/\s+/g, ' ')
            .trim()
            .replace(/\b\w/g, char => char.toUpperCase());
    }

    get hasBreadcrumbs() {
        return (this.breadcrumbs?.length || 0) > 1 || (this.breadcrumbs?.[0]?.label === 'Home');
    }

    getCommunityBasePath() {
        return resolveCommunityBasePath();
    }

    normalizePath(path, communityBasePath = '/') {
        if (!path) return '';

        if (/^https?:\/\//i.test(path)) {
            return '';
        }

        let normalized = path.trim();
        if (!normalized.startsWith('/')) {
            normalized = '/' + normalized;
        }

        normalized = normalized.replace(/\/+$/, '');
        if (normalized === '') normalized = '/';

        if (
            communityBasePath !== '/' &&
            normalized !== communityBasePath &&
            !normalized.startsWith(communityBasePath + '/')
        ) {
            const baseParts = communityBasePath.split('/').filter(Boolean);
            const communityRoot = baseParts.length > 0 ? `/${baseParts[0]}` : '/';

            if (normalized === communityRoot || normalized.startsWith(communityRoot + '/')) {
                normalized = normalized.replace(communityRoot, communityBasePath);
            } else {
                normalized = `${communityBasePath}${normalized}`;
            }
        }

        normalized = normalized.replace(/\/+$/, '');
        if (normalized === '') normalized = communityBasePath !== '/' ? communityBasePath : '/';

        return normalized;
    }
}