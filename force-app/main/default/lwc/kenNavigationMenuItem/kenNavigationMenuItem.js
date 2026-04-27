import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPrimaryColor from '@salesforce/apex/KenPortalConfigController.getPortalConfigs';

const ROOT_ROUTE_SEGMENTS = new Set([
    'home',
    'campuslife',
    'mess-dashboard',
    'residenceallocation',
    'residenceselection',
    'hosteldetails',
    'feed',
    'events',
    'jobs',
    'mentorship'
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

export default class KenNavigationMenuItem extends NavigationMixin(LightningElement) {
    @api item = {};
    @api isSelected = false;

    @track href = 'javascript:void(0);';
    @track isSubMenuVisible = false;
    showTooltip = false;
    tooltipStyle = '';
    pageReference;

    connectedCallback() {
        this.isSubMenuVisible = (this.item.subMenu || []).some(sub => sub.isSelected);
        getPrimaryColor().then(color => {
            document.documentElement.style.setProperty('--primary-color', color?.primaryColor);
            document.documentElement.style.setProperty('--secondary-color', color?.secondaryColor);
            document.documentElement.style.setProperty('--tertiary-color', color?.tertiaryColor);  
        }).catch(() => {
            console.log('Error getting primary color');
        });
        const { type, target } = this.item;

        if (!target) {
            console.warn(
                'Navigation menu item missing target/actionValue:',
                JSON.stringify(this.item)
            );
            return;
        }

        if (type === 'InternalLink' || type === 'ExternalLink') {
            this.pageReference = {
                type: 'standard__webPage',
                attributes: {
                    url: target
                }
            };
        }

        if (this.pageReference) {
            this[NavigationMixin.GenerateUrl](this.pageReference).then(url => {
                this.href = url;
            });
        }
    }

    get itemClass() {
        let classes = 'nav-item';

        if (this.isSelected && !this.isSubMenuVisible) {
            classes += ' selected';
        }

        if (this.isSubMenuVisible) {
            classes += ' submenu-open';
        }

        if (this.item?.isActive) {
            classes += ' active';
        }
        return classes;
    }

    get textClass() {
        return 'nav-text';
    }

    get label() {
        return this.item?.label || '';
    }

    get iconName() {
        return this.item?.iconName || '';
    }

    get hasIcon() {
        return !!this.item?.iconName;
    }

    get isUtilityIcon() {
        return this.iconName && this.iconName.startsWith('utility:');
    }

    get iconMaskStyle() {
        const url = this.item?.iconName || '';
        if (!url || this.isUtilityIcon) return '';
        return `mask-image: url("${url}"); -webkit-mask-image: url("${url}");`;
    }

    get showDropdown() {
        return (this.item.subMenu && this.item.subMenu.length > 0);
    }

    handleClick(evt) {
        const selectEvent = new CustomEvent('itemselect', {
            detail: {
                selectedItem: this.item,
                selectedItemId: this.item.id
            },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(selectEvent);

        evt.stopPropagation();
        evt.preventDefault();

        if (this.item.label === 'Logout') {
            window.location.href = `${resolveCommunityBasePath()}/secur/logout.jsp?retUrl/login`;
            return;
        }

        const hasSubMenu = Array.isArray(this.item.subMenu) && this.item.subMenu.length > 0;

        if (hasSubMenu) {
            this.isSubMenuVisible = !this.isSubMenuVisible;
            if (this.isSubMenuVisible) {
                this.showTooltip = false;
                this.tooltipStyle = '';
            }
            return;
        }

        if (this.pageReference) {
            this[NavigationMixin.GenerateUrl](this.pageReference).then(generatedUrl => {
                const isExternal = this.isExternalUrl(generatedUrl);
                const targetWindow = isExternal ? '_blank' : '_self';
                window.open(generatedUrl, targetWindow);
            });
        } else {
            console.error(
                `Navigation menu type "${this.item.type}" not implemented for item`,
                JSON.stringify(this.item)
            );
        }
    }

    handleMouseEnter(event) {
        if (event.relatedTarget && event.currentTarget.contains(event.relatedTarget)) {
            return;
        }

        if (this.isSubMenuVisible) {
            this.showTooltip = false;
            this.tooltipStyle = '';
            return;
        }

        this.showTooltip = true;
        const triggerEl = event.currentTarget;
        if (triggerEl) {
            const rect = triggerEl.getBoundingClientRect();
            const top = rect.top + rect.height / 2;
            const left = rect.right + 12;
            this.tooltipStyle = `top:${top}px; left:${left}px; transform: translateY(-50%);`;
        } else {
            this.tooltipStyle = '';
        }
    }

    handleMouseLeave(event) {
        if (event.relatedTarget && event.currentTarget.contains(event.relatedTarget)) {
            return;
        }

        this.showTooltip = false;
        this.tooltipStyle = '';
    }

    handleSubMenuSelect(event) {
        this.isSubMenuVisible = true;
        this.showTooltip = false;
        this.tooltipStyle = '';

        const selectedSubmenuItemId = event.detail.selectedItemId;

        const selectEvent = new CustomEvent('submenuselect', {
            detail: {
                parentItemId: this.item.id,
                selectedItem: event.detail.selectedItem,
                selectedItemId: selectedSubmenuItemId
            },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(selectEvent);
    }

    isExternalUrl(url) {
        if (!url || typeof window === 'undefined') {
            return false;
        }

        try {
            const currentOrigin = window.location?.origin || '';
            const parsedUrl = new URL(url, currentOrigin || undefined);
            return parsedUrl.origin !== currentOrigin;
        } catch (error) {
            console.warn('Failed to evaluate URL origin', error);
            return true;
        }
    }
}