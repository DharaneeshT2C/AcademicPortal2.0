import { LightningElement, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import INTER_FONT from '@salesforce/resourceUrl/InterFont';
import { applyStaticTokens, applyBrandTheme, injectInterFont } from 'c/themeService';

const KNOWN_ROUTES = new Set([
    'home','learn','attendance','my-exams','exam-enrollment','results','semester-detail',
    'marks-breakdown','research','thesis','course-enrollment','program-selection',
    'campus-life','clubs','events','hostel-details','mess-menu','gate-pass',
    'create-gate-pass','schedule','fee-payment','fee-payment-detail','fee-plan',
    'invoices','transactions','transaction-history','refunds','service-support',
    'faqs','feedback','notifications','chat','settings','placements','mentors',
    'service-request'
]);

function routeFromPath() {
    try {
        const parts = window.location.pathname.split('/').filter(Boolean);
        const last = parts[parts.length - 1];
        if (!last || last === 'newportal' || last === 's') return 'home';
        const slug = last === 'transactions' ? 'transaction-history' : last;
        return KNOWN_ROUTES.has(slug) ? slug : 'home';
    } catch (e) {
        return 'home';
    }
}

export default class App extends LightningElement {
    @track currentRoute = 'home';
    @track sidebarOpen = false;
    @track isLoggedIn = true;

    @track devStage = 'middle';
    @track devCareerPath = 'placements';
    @track devViewMode = 'auto';
    @track devBrand = 'ken';

    connectedCallback() {
        // Inject @font-face rules with absolute URLs first — this works in all
        // Salesforce LWR contexts. Then ALSO call loadStyle as a belt-and-braces
        // fallback for environments where document.head injection is restricted.
        injectInterFont(INTER_FONT);
        loadStyle(this, INTER_FONT + '/inter.css').catch(() => {
            // Silent — the inline injection above is the primary path.
        });
        applyStaticTokens();
        applyBrandTheme(this.devBrand);
        this.currentRoute = routeFromPath();
        window.addEventListener('popstate', this._onPop);
    }

    disconnectedCallback() {
        window.removeEventListener('popstate', this._onPop);
    }

    _onPop = () => {
        this.currentRoute = routeFromPath();
    };

    get isLoginPage() {
        return this.currentRoute === 'login';
    }

    get isDevMode() {
        try {
            const h = window.location.hostname || '';
            return h === 'localhost' || h === '127.0.0.1' || h.startsWith('192.168.');
        } catch (e) { return false; }
    }

    get showLayout() {
        return this.isLoggedIn && this.currentRoute !== 'login';
    }

    get sidebarClass() {
        return `sidebar-container ${this.sidebarOpen ? 'sidebar-open' : ''}`;
    }

    get layoutClass() {
        return 'app-layout viewmode-' + this.devViewMode;
    }

    handleLogin() {
        this.isLoggedIn = true;
        this.currentRoute = 'home';
    }

    handleNavigate(event) {
        const route = event.detail.route;
        this.currentRoute = route;
        this.sidebarOpen = false;
        try {
            const base = window.location.pathname.split('/').filter(Boolean)[0] || 'newportal';
            const target = route === 'home' ? `/${base}/` : `/${base}/${route}`;
            if (window.location.pathname !== target) {
                window.history.pushState({ route }, '', target);
            }
        } catch (e) {}
    }

    handleToggleSidebar() {
        this.sidebarOpen = !this.sidebarOpen;
    }

    handleCloseSidebar() {
        this.sidebarOpen = false;
    }

    handleOverlayClick() {
        this.sidebarOpen = false;
    }

    handleStageChange(event)    { this.devStage      = event.detail.stage; }
    handlePathChange(event)     { this.devCareerPath  = event.detail.careerPath; }
    handleViewModeChange(event) { this.devViewMode    = event.detail.viewMode; }
    handleBrandChange(event) {
        this.devBrand = event.detail.brand;
        applyBrandTheme(this.devBrand);
    }

    get isHome() { return this.currentRoute === 'home'; }
    get isCourseEnrollment() { return this.currentRoute === 'course-enrollment'; }
    get isSemesterDetail() { return this.currentRoute === 'semester-detail'; }
    get isProgramSelection() { return this.currentRoute === 'program-selection'; }
    get isLearn() { return this.currentRoute === 'learn'; }
    get isAttendance() { return this.currentRoute === 'attendance'; }
    get isThesis() { return this.currentRoute === 'thesis'; }
    get isMentors() { return this.currentRoute === 'mentors'; }
    get isFeePayment() { return this.currentRoute === 'fee-payment'; }
    get isFeePaymentDetail() { return this.currentRoute === 'fee-payment-detail'; }
    get isFeePlan() { return this.currentRoute === 'fee-plan'; }
    get isTransactionHistory() { return this.currentRoute === 'transaction-history'; }
    get isInvoices() { return this.currentRoute === 'invoices'; }
    get isMyExams() { return this.currentRoute === 'my-exams'; }
    get isExamEnrollment() { return this.currentRoute === 'exam-enrollment'; }
    get isResults() { return this.currentRoute === 'results'; }
    get isMarksBreakdown() { return this.currentRoute === 'marks-breakdown'; }
    get isPlacements() { return this.currentRoute === 'placements'; }
    get isCampusLife() { return this.currentRoute === 'campus-life'; }
    get isClubs() { return this.currentRoute === 'clubs'; }
    get isGatePass() { return this.currentRoute === 'gate-pass'; }
    get isCreateGatePass() { return this.currentRoute === 'create-gate-pass'; }
    get isHostelDetails() { return this.currentRoute === 'hostel-details'; }
    get isMessMenu() { return this.currentRoute === 'mess-menu'; }
    get isServiceSupport() { return this.currentRoute === 'service-support'; }
    get isServiceRequest() { return this.currentRoute === 'service-request'; }
    get isFaqs() { return this.currentRoute === 'faqs'; }
    get isFeedback() { return this.currentRoute === 'feedback'; }
    get isSchedule() { return this.currentRoute === 'schedule'; }
    get isChat() { return this.currentRoute === 'chat'; }
    get isSettings() { return this.currentRoute === 'settings'; }
    get isNotifications() { return this.currentRoute === 'notifications'; }
    get isRefunds() { return this.currentRoute === 'refunds'; }
    get isEvents()    { return this.currentRoute === 'events'; }
    get isResearch()  { return this.currentRoute === 'research'; }
}