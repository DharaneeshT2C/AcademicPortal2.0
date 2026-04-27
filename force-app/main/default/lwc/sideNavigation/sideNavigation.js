import { LightningElement, wire } from 'lwc';
import communityBasePath from '@salesforce/community/basePath';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';
import getCurrentUserProfile from '@salesforce/apex/SideNavigationController.getCurrentUserProfile';

const ACADEMICS_ROUTE_SEGMENTS = new Set([
    '',
    'home',
    'course-enrolment',
    'courseafterenrollment',
    'coursebroucher',
    'courseenrollmentdetails',
    'courseparticulardetails'
]);

const CAMPUS_LIFE_ROUTE_SEGMENTS = new Set([
    'campuslife',
    'residenceallocation',
    'residenceselection',
    'hosteldetails'
]);

const FEE_PAYMENT_ROUTE_SEGMENTS = new Set(['feepayment']);

const MY_EXAMS_ROUTE_SEGMENTS = new Set(['myexams', 'my-exams', 'my_exams']);
const EXAM_RESULTS_ROUTE_SEGMENTS = new Set(['results', 'examresults', 'exam-results', 'exam_results']);
const PLACEMENTS_ROUTE_SEGMENTS = new Set(['placements', 'placement']);

const FACULTY_THESIS_ROUTE_SEGMENTS = new Set(['thesismanagement', 'thesis-management', 'thesis']);
const FACULTY_ATTENDANCE_ROUTE_SEGMENTS = new Set(['attendance', 'facultyattendance', 'faculty-attendance']);
const FACULTY_EXAMS_ROUTE_SEGMENTS = new Set(['exams', 'facultyexams', 'faculty-exams']);
const FACULTY_MY_STUDENTS_ROUTE_SEGMENTS = new Set(['my-students', 'my_students', 'mystudents', 'my-student', 'mystudent', 'facultychoosecourse']);
const FACULTY_PAYROLL_ROUTE_SEGMENTS = new Set(['payroll', 'faculty-payroll', 'faculty_payroll']);
const FACULTY_INTERVIEW_ROUTE_SEGMENTS = new Set(['interview', 'faculty-interview', 'faculty_interview']);
const FACULTY_EVENTS_ROUTE_SEGMENTS = new Set(['events', 'faculty-events', 'faculty_events']);
const FACULTY_SERVICE_SUPPORT_ROUTE_SEGMENTS = new Set(['service-support', 'service_support']);
const FACULTY_PROFILE_ROUTE_SEGMENTS = new Set(['my-profile', 'myprofile']);
const FACULTY_ROOT_ROUTE_SEGMENTS = new Set(['academics']);

const THEME_PRIMARY_STORAGE_KEY = 'ken_theme_primary';
const THEME_SECONDARY_STORAGE_KEY = 'ken_theme_secondary';
const SIDE_NAV_ROLE_STORAGE_KEY = 'ken_side_nav_role';

export default class SideNavigation extends LightningElement {
    static DEFAULT_PRIMARY = '#3061FF';
    static DEFAULT_SECONDARY = '#EAEFFF';

    isAcademicsOpen = true;
    isExamsOpen = false;
    logoutUrl = '/secur/logout.jsp';
    organizationDefaults = {};
    pendingPrimary = SideNavigation.DEFAULT_PRIMARY;
    pendingSecondary = SideNavigation.DEFAULT_SECONDARY;
    themeLoading = true;
    profileLoading = true;
    userFirstName = '';
    userLastName = '';
    userPhotoUrl = '';
    userRole = '';
    role = 'student';

    connectedCallback() {
        const routeRole = this.resolveRoleFromRoute();
        const storedRole = this.getStoredRole();
        this.role = routeRole || storedRole || 'student';
        if (routeRole) {
            this.storeRole(routeRole);
        }

        this.loadCurrentUserProfile();

        const storedTheme = this.getStoredTheme();
        if (storedTheme) {
            this.applyTheme(storedTheme.primary, storedTheme.secondary);
            this.themeLoading = false;
            return;
        }

        this.applyTheme();
        Promise.resolve().then(() => {
            if (this.themeLoading) {
                this.themeLoading = false;
            }
        });
    }

    renderedCallback() {
        if (this.pendingPrimary || this.pendingSecondary) {
            this.applyTheme(this.pendingPrimary, this.pendingSecondary);
        }
    }

    @wire(OrganizationDefaultsApiController)
    wiredOrganizationDefaults({ data, error }) {
        if (data) {
            this.organizationDefaults = data;
            const resolvedPrimary = this.resolveThemeColor(data.primary, SideNavigation.DEFAULT_PRIMARY);
            const resolvedSecondary = this.resolveThemeColor(data.secondary, SideNavigation.DEFAULT_SECONDARY);
            this.storeTheme(resolvedPrimary, resolvedSecondary);
            this.applyTheme(resolvedPrimary, resolvedSecondary);
            this.themeLoading = false;
            return;
        }
        if (error) {
            this.organizationDefaults = {};
            this.applyTheme();
            this.themeLoading = false;
        }
    }

    async loadCurrentUserProfile() {
        try {
            const profile = await getCurrentUserProfile();
            this.userFirstName = profile?.firstName || '';
            this.userLastName = profile?.lastName || '';
            this.userPhotoUrl = profile?.photoUrl || '';
            this.userRole = profile?.roleType || '';
            const resolvedRole = this.resolveProfileRole(this.userRole);
            this.role = resolvedRole;
            this.storeRole(resolvedRole);
        } catch (error) {
            this.userFirstName = '';
            this.userLastName = '';
            this.userPhotoUrl = '';
            this.userRole = '';
            const fallbackRole = this.resolveRoleFromRoute() || this.getStoredRole();
            if (fallbackRole) {
                this.role = fallbackRole;
            }
        } finally {
            this.profileLoading = false;
        }
    }

    resolveProfileRole(roleType) {
        const normalized = String(roleType || '').trim().toLowerCase();
        if (normalized === 'faculty') {
            return 'faculty';
        }
        if (normalized === 'student') {
            return 'student';
        }
        const inferredRole = this.resolveRoleFromRoute() || this.getStoredRole();
        return inferredRole || 'student';
    }

    resolveRoleFromRoute() {
        if (this.isFacultyRoute) {
            return 'faculty';
        }
        return null;
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
                primary: this.resolveThemeColor(primary, SideNavigation.DEFAULT_PRIMARY),
                secondary: this.resolveThemeColor(secondary, SideNavigation.DEFAULT_SECONDARY)
            };
        } catch (e) {
            return null;
        }
    }

    storeTheme(primary, secondary) {
        try {
            window.localStorage.setItem(THEME_PRIMARY_STORAGE_KEY, primary);
            window.localStorage.setItem(THEME_SECONDARY_STORAGE_KEY, secondary);
        } catch (e) {
            // no-op
        }
    }

    applyTheme(primary, secondary) {
        const resolvedPrimary = primary || SideNavigation.DEFAULT_PRIMARY;
        const resolvedSecondary = secondary || SideNavigation.DEFAULT_SECONDARY;
        this.pendingPrimary = resolvedPrimary;
        this.pendingSecondary = resolvedSecondary;

        if (!this.template?.host) {
            return;
        }

        this.template.host.style.setProperty('--primary-color', resolvedPrimary);
        this.template.host.style.setProperty('--secondary-color', resolvedSecondary);
        this.pendingPrimary = null;
        this.pendingSecondary = null;
    }

    get academicsChevron() {
        return this.isAcademicsOpen ? 'utility:chevronup' : 'utility:chevrondown';
    }

    get examsChevron() {
        return this.isExamsOpen ? 'utility:chevronup' : 'utility:chevrondown';
    }

    get isStudentRole() {
        return this.role === 'student';
    }

    get sideNavClass() {
        return this.isStudentRole ? 'side-nav' : 'side-nav role-faculty';
    }

    get roleToggleLabel() {
        return this.isStudentRole ? 'Switch to Faculty' : 'Switch to Student';
    }

    get courseEnrollmentItemClass() {
        return this.isCourseEnrollmentActive ? 'submenu-item is-active' : 'submenu-item';
    }

    get studentAttendanceItemClass() {
        return this.isStudentAttendanceActive ? 'submenu-item is-active' : 'submenu-item';
    }

    get isStudentAttendanceActive() {
        if (!this.isStudentRole) {
            return false;
        }
        const parts = this.currentPathSegments;
        return (
            parts.includes('student-attendance') ||
            parts.includes('student-attendance-history') ||
            parts.includes('attendance-details')
        );
    }

    get myExamsItemClass() {
        return this.isMyExamsActive ? 'submenu-item is-active' : 'submenu-item';
    }

    get examResultsItemClass() {
        return this.isExamResultsActive ? 'submenu-item is-active' : 'submenu-item';
    }

    get placementsItemClass() {
        return this.isPlacementsActive ? 'menu-item is-active' : 'menu-item';
    }

    get campusLifeItemClass() {
        return this.isCampusLifeActive ? 'menu-item is-active' : 'menu-item';
    }

    get feePaymentItemClass() {
        return this.isFeePaymentActive ? 'menu-item is-active' : 'menu-item';
    }

    get facultyAcademicsItemClass() {
        return this.isFacultyAcademicsActive ? 'menu-item menu-item-group is-active' : 'menu-item menu-item-group';
    }

    get facultyThesisItemClass() {
        return this.isFacultyThesisActive ? 'submenu-item is-active' : 'submenu-item';
    }

    get facultyAttendanceItemClass() {
        return this.isFacultyAttendanceActive ? 'submenu-item is-active' : 'submenu-item';
    }

    get facultyExamsItemClass() {
        return this.isFacultyExamsActive ? 'submenu-item is-active' : 'submenu-item';
    }

    get facultyMyStudentsItemClass() {
        return this.isFacultyMyStudentsActive ? 'submenu-item is-active' : 'submenu-item';
    }

    get facultyPayrollItemClass() {
        return this.isFacultyPayrollActive ? 'submenu-item is-active' : 'submenu-item';
    }

    get facultyInterviewItemClass() {
        return this.isFacultyInterviewActive ? 'submenu-item is-active' : 'submenu-item';
    }

    get facultyEventsItemClass() {
        return this.isFacultyEventsActive ? 'submenu-item is-active' : 'submenu-item';
    }

    get facultyServiceSupportItemClass() {
        return this.isFacultyServiceSupportActive ? 'submenu-item is-active' : 'submenu-item';
    }

    get isCourseEnrollmentActive() {
        return ACADEMICS_ROUTE_SEGMENTS.has(this.currentRouteSegment);
    }

    get isCampusLifeActive() {
        return CAMPUS_LIFE_ROUTE_SEGMENTS.has(this.currentRouteSegment);
    }

    get isFeePaymentActive() {
        return FEE_PAYMENT_ROUTE_SEGMENTS.has(this.currentRouteSegment);
    }

    get isFacultyAcademicsActive() {
        return (
            this.isFacultyThesisActive ||
            this.isFacultyAttendanceActive ||
            this.isFacultyExamsActive ||
            this.isFacultyMyStudentsActive ||
            this.isFacultyPayrollActive ||
            this.isFacultyInterviewActive ||
            this.isFacultyEventsActive ||
            this.isFacultyServiceSupportActive
        );
    }

    get isFacultyThesisActive() {
        return FACULTY_THESIS_ROUTE_SEGMENTS.has(this.currentRouteSegment);
    }

    get isFacultyAttendanceActive() {
        return FACULTY_ATTENDANCE_ROUTE_SEGMENTS.has(this.currentRouteSegment);
    }

    get isFacultyExamsActive() {
        return FACULTY_EXAMS_ROUTE_SEGMENTS.has(this.currentRouteSegment);
    }

    get isFacultyMyStudentsActive() {
        return FACULTY_MY_STUDENTS_ROUTE_SEGMENTS.has(this.currentRouteSegment);
    }

    get isFacultyPayrollActive() {
        return FACULTY_PAYROLL_ROUTE_SEGMENTS.has(this.currentRouteSegment);
    }

    get isFacultyInterviewActive() {
        return FACULTY_INTERVIEW_ROUTE_SEGMENTS.has(this.currentRouteSegment);
    }

    get isFacultyEventsActive() {
        return FACULTY_EVENTS_ROUTE_SEGMENTS.has(this.currentRouteSegment);
    }

    get isFacultyServiceSupportActive() {
        return FACULTY_SERVICE_SUPPORT_ROUTE_SEGMENTS.has(this.currentRouteSegment);
    }

    get isMyExamsActive() {
        return MY_EXAMS_ROUTE_SEGMENTS.has(this.currentRouteSegment);
    }

    get isExamResultsActive() {
        return EXAM_RESULTS_ROUTE_SEGMENTS.has(this.currentRouteSegment);
    }

    get isPlacementsActive() {
        return PLACEMENTS_ROUTE_SEGMENTS.has(this.currentRouteSegment);
    }

    get currentRouteSegment() {
        const segments = this.currentPathSegments;
        return segments[0] || '';
    }

    get isFacultyRoute() {
        const segment = this.currentRouteSegment;
        return (
            FACULTY_ROOT_ROUTE_SEGMENTS.has(segment) ||
            FACULTY_PROFILE_ROUTE_SEGMENTS.has(segment) ||
            FACULTY_THESIS_ROUTE_SEGMENTS.has(segment) ||
            FACULTY_ATTENDANCE_ROUTE_SEGMENTS.has(segment) ||
            FACULTY_EXAMS_ROUTE_SEGMENTS.has(segment) ||
            FACULTY_MY_STUDENTS_ROUTE_SEGMENTS.has(segment) ||
            FACULTY_PAYROLL_ROUTE_SEGMENTS.has(segment) ||
            FACULTY_INTERVIEW_ROUTE_SEGMENTS.has(segment) ||
            FACULTY_EVENTS_ROUTE_SEGMENTS.has(segment) ||
            FACULTY_SERVICE_SUPPORT_ROUTE_SEGMENTS.has(segment)
        );
    }

    get currentPathSegments() {
        const basePath = communityBasePath || '/';
        const currentPath = this.normalizePath(window.location?.pathname || basePath, basePath);
        let relativePath = currentPath;

        if (basePath !== '/' && currentPath.startsWith(basePath)) {
            relativePath = currentPath.slice(basePath.length);
        }

        return relativePath
            .replace(/^\/+/, '')
            .split('/')
            .map((segment) => segment.toLowerCase())
            .filter(Boolean);
    }

    get currentUserName() {
        const fullName = [this.userFirstName, this.userLastName].filter(Boolean).join(' ').trim();
        return fullName || 'Current User';
    }

    get isLoading() {
        return this.themeLoading || this.profileLoading;
    }

    get hasUserPhoto() {
        return Boolean(this.userPhotoUrl);
    }

    get userInitials() {
        const first = (this.userFirstName || '').trim().charAt(0);
        const last = (this.userLastName || '').trim().charAt(0);
        const initials = `${first}${last}`.trim();
        return initials || 'U';
    }

    toggleAcademics() {
        this.isAcademicsOpen = !this.isAcademicsOpen;
    }

    toggleExams() {
        this.isExamsOpen = !this.isExamsOpen;
    }

    handleRoleToggle() {
        this.role = this.isStudentRole ? 'faculty' : 'student';
        this.storeRole(this.role);
        this.isAcademicsOpen = true;
        this.isExamsOpen = false;
    }

    handleLogout() {
        window.open(this.logoutUrl, '_self');
    }

    handleProfileClick() {
        const targetPath = this.role === 'faculty' ? 'my-profile' : 'my-students-details';
        window.open(this.buildCommunityUrl(targetPath), '_self');
    }

    handleHomeClick() {
        window.open(this.buildCommunityUrl(''), '_self');
    }

    handleCourseEnrollmentClick() {
        window.open(this.buildCommunityUrl('course-enrolment'), '_self');
    }

    handleLearnClick() {
        window.open(this.buildCommunityUrl('student-learn'), '_self');
    }

    handleFeePayment() {
        window.open(this.buildCommunityUrl('feepayment'), '_self');
    }

    handleCampusLifeClick() {
        // window.open(this.buildCommunityUrl('campuslife'), '_self');
    }

    handleAttendanceClick() {
        window.open(this.buildCommunityUrl('student-attendance'), '_self');
    }

    handleFacultyThesisClick() {
        window.open(this.buildCommunityUrl('thesismanagement'), '_self');
    }

    handleFacultyAcademicsClick() {
        window.open(this.buildCommunityUrl('Academics'), '_self');
    }

    handleFacultyAttendanceClick() {
        // Temporary: using the same attendance route for now.
        window.open(this.buildCommunityUrl('attendance'), '_self');
    }

    handleFacultyExamsClick() {
        window.open(this.buildCommunityUrl('exams'), '_self');
    }

    handleMyStudentsClick() {
        window.open(this.buildCommunityUrl('facultychoosecourse'), '_self');
    }

    handlePayrollClick() {
        // window.open(this.buildCommunityUrl('payroll'), '_self');
    }

    handleInterviewClick() {
        // window.open(this.buildCommunityUrl('interview'), '_self');
    }

    handleEventsClick() {
        // window.open(this.buildCommunityUrl('events'), '_self');
    }

    handleMyExamsClick() {
        window.open(this.buildCommunityUrl('my-exams'), '_self');
    }

    handleExamResultsClick() {
        window.open(this.buildCommunityUrl('student-results'), '_self');
    }

    handlePlacementsClick() {
        // window.open(this.buildCommunityUrl('placements'), '_self');
    }

    handleServiceSupportClick() {
        // window.open(this.buildCommunityUrl('service-support'), '_self');
    }

    handleFeedbackClick() {
        // window.open(this.buildCommunityUrl('feedback'), '_self');
    }

    getStoredRole() {
        try {
            const stored = window.localStorage.getItem(SIDE_NAV_ROLE_STORAGE_KEY);
            if (stored === 'student' || stored === 'faculty') {
                return stored;
            }
            return null;
        } catch (e) {
            return null;
        }
    }

    storeRole(role) {
        try {
            window.localStorage.setItem(SIDE_NAV_ROLE_STORAGE_KEY, role);
        } catch (e) {
            // no-op
        }
    }

    buildCommunityUrl(path = '') {
        const basePath = communityBasePath || '/';
        const sanitizedPath = path.replace(/^\/+|\/+$/g, '');

        if (basePath === '/') {
            return sanitizedPath ? `/${sanitizedPath}` : '/';
        }

        return sanitizedPath ? `${basePath}/${sanitizedPath}` : basePath;
    }

    normalizePath(path, basePath = '/') {
        if (!path) {
            return '';
        }

        let normalized = path.trim();
        if (!normalized.startsWith('/')) {
            normalized = '/' + normalized;
        }

        normalized = normalized.replace(/\/+$/, '');
        if (normalized === '') {
            normalized = '/';
        }

        if (basePath !== '/' && normalized !== basePath && !normalized.startsWith(basePath + '/')) {
            const baseParts = basePath.split('/').filter(Boolean);
            const communityRoot = baseParts.length > 0 ? `/${baseParts[0]}` : '/';

            if (normalized === communityRoot || normalized.startsWith(communityRoot + '/')) {
                normalized = normalized.replace(communityRoot, basePath);
            } else {
                normalized = `${basePath}${normalized}`;
            }
        }

        normalized = normalized.replace(/\/+$/, '');
        if (normalized === '') {
            normalized = basePath !== '/' ? basePath : '/';
        }

        return normalized;
    }
}