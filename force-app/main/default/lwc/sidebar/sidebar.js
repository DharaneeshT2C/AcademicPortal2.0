import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { sidebarNavItems } from 'c/mockData';
import getStudentHeader from '@salesforce/apex/KenHomeDashboardController.getStudentHeader';

const THESIS_MANAGEMENT_PAGE = 'Thesis_Management__c';

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
    student = { FirstName: '', LastName: '' };

    get programLabel() {
        if (this._header && this._header.program) return this._header.program;
        return '';
    }

    @wire(getStudentHeader)
    wiredHeader({ data }) {
        if (data) {
            this._header = data;
            const isPlaceholder = !data.firstName || data.firstName === 'Student';
            if (!isPlaceholder) {
                this.student = {
                    FirstName: data.firstName,
                    LastName:  data.lastName || ''
                };
            }
        }
    }

    connectedCallback() {
        this._currentRoute = this._routeFromPath();
        this.rebuildNav();
    }

    _routeFromPath() {
        try {
            const parts = window.location.pathname.split('/').filter(Boolean);
            const last = parts[parts.length - 1];
            if (!last || last === 'newportal' || last === 's') return 'home';
            return last;
        } catch (e) {
            return this._currentRoute;
        }
    }

    _navigateTo(route) {
        if (route === 'thesis-management') {
            try {
                this[NavigationMixin.Navigate]({
                    type: 'comm__namedPage',
                    attributes: { name: THESIS_MANAGEMENT_PAGE }
                });
                return;
            } catch (e) {
                // Fallback to explicit URL when named page is unavailable.
            }
        }

        try {
            const parts = window.location.pathname.split('/').filter(Boolean);
            const base = parts[0] || 'newportal';
            const target = route === 'home' ? `/${base}/` : `/${base}/${route}`;
            window.location.href = target;
        } catch (e) {
            this.dispatchEvent(new CustomEvent('navigate', { detail: { route } }));
        }
    }

    rebuildNav() {
        const sourceNavItems = this.getSidebarNavItems();
        this.navItems = sourceNavItems.map(item => {
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

    getSidebarNavItems() {
        return sidebarNavItems.map((item) => {
            if (item.id !== 'academics' || !Array.isArray(item.children)) {
                return item;
            }

            const hasCourseEnrolment = item.children.some((child) => child.route === 'course-enrolment');
            const attendanceIndex = item.children.findIndex((child) => child.route === 'attendance');
            const courseEnrolmentItem = {
                id: 'course-enrolment',
                label: 'Course Enrolment',
                route: 'course-enrolment'
            };
            const thesisManagementItem = {
                id: 'thesis-management',
                label: 'Thesis Management',
                route: 'thesis-management'
            };

            let updatedChildren = [...item.children];

            if (!hasCourseEnrolment) {
                if (attendanceIndex === -1) {
                    updatedChildren = [...updatedChildren, courseEnrolmentItem];
                } else {
                    updatedChildren.splice(attendanceIndex + 1, 0, courseEnrolmentItem);
                }
            }

            const hasThesisManagement = updatedChildren.some((child) => child.route === 'thesis-management');
            if (!hasThesisManagement) {
                const courseEnrolmentIndex = updatedChildren.findIndex((child) => child.route === 'course-enrolment');
                if (courseEnrolmentIndex === -1) {
                    updatedChildren = [...updatedChildren, thesisManagementItem];
                } else {
                    updatedChildren.splice(courseEnrolmentIndex + 1, 0, thesisManagementItem);
                }
            }

            return { ...item, children: updatedChildren };
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
            this._navigateTo(route);
        }
    }

    handleChildClick(event) {
        const route = event.currentTarget.dataset.route;
        this._navigateTo(route);
    }

    handleLogout() {
        try {
            // Standard Salesforce community logout endpoint.
            window.location.href = '/secur/logout.jsp';
        } catch (e) {
            // Fallback for non-SF runtimes — navigate to in-app login.
            this.dispatchEvent(new CustomEvent('navigate', { detail: { route: 'login' } }));
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleOpenSettings() {
        this._navigateTo('settings');
    }
}