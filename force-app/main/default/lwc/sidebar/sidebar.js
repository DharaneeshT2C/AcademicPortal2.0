import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getStudentHeader from '@salesforce/apex/KenHomeDashboardController.getStudentHeader';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';

const THESIS_MANAGEMENT_PAGE = 'Thesis_Management__c';
const SIDEBAR_NAV_ITEMS = [
    { id: 'home', label: 'Home', icon: 'home', route: 'home' },
    {
        id: 'academics',
        label: 'Academics',
        icon: 'school',
        children: [
            { id: 'learn', label: 'Learn', route: 'learn' },
            { id: 'attendance', label: 'Attendance', route: 'attendance' },
            { id: 'course-enrolment', label: 'Course Enrolment', route: 'course-enrolment' },
            { id: 'thesis-management', label: 'Thesis Management', route: 'thesis-management' },
            { id: 'my-exams', label: 'My Exams', route: 'my-exams' },
            { id: 'results', label: 'Results', route: 'results' }
        ]
    },
    {
        id: 'campus-life',
        label: 'Campus Life',
        icon: 'apartment',
        children: [
            { id: 'campus-life-overview', label: 'Overview', route: 'overview' },
            { id: 'events', label: 'Events', route: 'events' },
            { id: 'clubs', label: 'Clubs', route: 'clubs' }
        ]
    },
    { id: 'fee-payment', label: 'Fee Payment', icon: 'payment', route: 'fee-payment' }
];

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
    organizationDefaults = {};

    @wire(OrganizationDefaultsApiController)
    wiredOrganizationDefaults({ data }) {
        if (data) {
            this.organizationDefaults = data;
            this.applyOrganizationTheme();
        }
    }

    applyOrganizationTheme() {
        const primary = this.organizationDefaults?.primary;
        const secondary = this.organizationDefaults?.secondary;
        if (primary && typeof primary === 'string') {
            this.template?.host?.style.setProperty('--primary-color', primary);
            try { document.documentElement.style.setProperty('--primary-color', primary); } catch (e) {}
        }
        if (secondary && typeof secondary === 'string') {
            this.template?.host?.style.setProperty('--secondary-color', secondary);
            try { document.documentElement.style.setProperty('--secondary-color', secondary); } catch (e) {}
        }
    }

    get programLabel() {
        if (this._header && this._header.program) return this._header.program;
        return '';
    }

    get avatarInitials() {
        const f = (this.student.FirstName || '').trim();
        const l = (this.student.LastName  || '').trim();
        const fi = f ? f[0].toUpperCase() : '';
        const li = l ? l[0].toUpperCase() : '';
        const combined = (fi + li);
        return combined || 'AR';
    }

    get streakText() {
        if (this._header && this._header.streakLine) return this._header.streakLine;
        return '12-day streak';
    }

    get attendanceText() {
        if (this._header && this._header.attendanceLine) return this._header.attendanceLine;
        return '82% attendance';
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
        const source = SIDEBAR_NAV_ITEMS;
        const findItem = (id) => source.find((item) => item && item.id === id);

        const homeItem       = findItem('home');
        const academicsItem  = findItem('academics');
        const campusLifeItem = findItem('campus-life');
        const feePaymentItem = findItem('fee-payment');

        // ── Academics group: keep core children, ensure course-enrolment + thesis-management,
        //    remove exam-related children (they move to their own group).
        const academicsRaw = (academicsItem && Array.isArray(academicsItem.children)) ? academicsItem.children : [];
        const isExamRoute = (route) => route === 'my-exams' || route === 'results';
        const examChildrenFromAcademics = academicsRaw.filter((c) => isExamRoute(c.route));
        let academicsChildren = academicsRaw.filter((c) => !isExamRoute(c.route));

        const ensureChild = (children, child, anchorRoute) => {
            if (children.some((c) => c.route === child.route)) return children;
            const anchorIndex = anchorRoute ? children.findIndex((c) => c.route === anchorRoute) : -1;
            if (anchorIndex === -1) return [...children, child];
            const next = [...children];
            next.splice(anchorIndex + 1, 0, child);
            return next;
        };
        academicsChildren = ensureChild(
            academicsChildren,
            { id: 'course-enrolment', label: 'Course Enrolment', route: 'course-enrolment' },
            'attendance'
        );
        academicsChildren = ensureChild(
            academicsChildren,
            { id: 'thesis-management', label: 'Thesis Management', route: 'thesis-management' },
            'course-enrolment'
        );

        // ── Exams group children: derived from whatever the source had,
        //    fall back to defaults; route names stay identical so redirection is preserved.
        const examChildren = examChildrenFromAcademics.length
            ? examChildrenFromAcademics
            : [
                { id: 'my-exams', label: 'My Exams', route: 'my-exams' },
                { id: 'results',  label: 'Results',  route: 'results' }
            ];
        const renamedExamChildren = examChildren.map((c) =>
            c.route === 'my-exams' ? { ...c, label: 'My Exams' } : c
        );

        // ── Compose the final ordered nav (with section labels).
        const result = [];
        if (homeItem) result.push(homeItem);

        if (academicsItem) {
            result.push({ id: 'sec-academics', isSection: true, label: 'ACADEMICS' });
            result.push({ ...academicsItem, children: academicsChildren });
        }

        result.push({ id: 'sec-exams', isSection: true, label: 'EXAMS' });
        result.push({
            id: 'exams',
            label: 'Exams',
            icon: 'library_books',
            children: renamedExamChildren
        });

        if (campusLifeItem) {
            result.push({ id: 'sec-campus-life', isSection: true, label: 'CAMPUS LIFE' });
            result.push(campusLifeItem);
        }

        if (feePaymentItem) result.push(feePaymentItem);

        return result;
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