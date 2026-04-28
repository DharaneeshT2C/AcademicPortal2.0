import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { pageNameForRoute } from 'c/navHelper';
import { sidebarNavItems, studentProfile } from 'c/mockData';
import getStudentHeader from '@salesforce/apex/KenHomeDashboardController.getStudentHeader';

export default class Sidebar extends NavigationMixin(LightningElement) {
    _currentRoute = 'home';

    @api
    get currentRoute() {
        return this._currentRoute;
    }
    set currentRoute(value) {
        this._currentRoute = value;
        this.rebuildNav();
    }

    @track navItems = [];
    @track expandedSections = {};
    @track _header;
    // Fallback seed student profile; swapped when @wire resolves.
    student = studentProfile;

    @wire(getStudentHeader)
    wiredHeader({ data }) {
        if (data) {
            this._header = data;
            // Apex returns "Student"/"" placeholder when the running user has no
            // linked Contact (e.g. admin previewing in Experience Builder). Keep
            // the seeded student profile in that case so the sidebar renders a
            // readable name and last initial.
            const isPlaceholder = !data.firstName || data.firstName === 'Student';
            if (!isPlaceholder) {
                this.student = {
                    ...this.student,
                    FirstName: data.firstName,
                    LastName:  data.lastName || ''
                };
            }
        }
    }

    connectedCallback() {
        this.rebuildNav();
    }

    rebuildNav() {
        this.navItems = sidebarNavItems.map(item => {
            if (item.isSection) {
                return { ...item, isSection: true, hasChildren: false, hasChildrenStr: 'false', children: [] };
            }
            const isActive = this.isItemActive(item);
            const isExpanded = this.shouldExpand(item);
            const hasChildren = item.children && item.children.length > 0;
            return {
                ...item,
                isActive,
                isExpanded,
                hasChildren,
                hasChildrenStr: hasChildren ? 'true' : 'false',
                chevronIcon: isExpanded ? 'expand_less' : 'expand_more',
                navClass: isActive ? 'nav-item active' : 'nav-item',
                childrenClass: isExpanded ? 'nav-children expanded' : 'nav-children',
                children: item.children ? item.children.map(child => ({
                    ...child,
                    isActive: child.route === this._currentRoute,
                    childClass: child.route === this._currentRoute ? 'nav-child active' : 'nav-child'
                })) : []
            };
        });
    }

    isItemActive(item) {
        if (item.route === this._currentRoute) return true;
        if (item.children) {
            return item.children.some(c => c.route === this._currentRoute);
        }
        return false;
    }

    shouldExpand(item) {
        if (!item.children) return false;
        return item.children.some(c => c.route === this._currentRoute) || !!this.expandedSections[item.id];
    }

    handleNavClick(event) {
        const hasChildren = event.currentTarget.dataset.haschildren === 'true';
        const itemId = event.currentTarget.dataset.id;
        const route = event.currentTarget.dataset.route;

        if (hasChildren) {
            this.expandedSections = {
                ...this.expandedSections,
                [itemId]: !this.expandedSections[itemId]
            };
            this.rebuildNav();
        } else {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: pageNameForRoute(route) }
            });
        }
    }

    handleChildClick(event) {
        const route = event.currentTarget.dataset.route;
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: pageNameForRoute(route) }
        });
    }

    handleLogout() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: pageNameForRoute('login') }
        });
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleOpenSettings() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: pageNameForRoute('settings') }
        });
    }
}