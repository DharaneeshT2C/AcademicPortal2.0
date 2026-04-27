import { LightningElement, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import INTER_FONT from '@salesforce/resourceUrl/InterFont';

// Non-brand CSS tokens — previously loaded once via `public/index.html`'s :root block
// in the Rollup prototype. Salesforce has no index.html, so we set them on
// document.documentElement when <c-app> mounts. CSS custom properties inherit
// across shadow DOM boundaries, so every nested component picks them up.
const STATIC_TOKENS = {
    '--bg-main':        '#F8FAFC',
    '--bg-white':       '#ffffff',
    '--border':         '#E2E8F0',
    '--border-light':   '#F1F5F9',
    '--text-primary':   '#1A1D26',
    '--text-secondary': '#64748B',
    '--text-muted':     '#94A3B8',
    '--success':        '#12B76A',
    '--success-light':  '#ECFDF3',
    '--success-dark':   '#039855',
    '--warning':        '#F79009',
    '--warning-light':  '#FFFAEB',
    '--warning-dark':   '#DC6803',
    '--danger':         '#F04438',
    '--danger-light':   '#FEF3F2',
    '--danger-dark':    '#D92D20',
    '--neutral':        '#667085',
    '--neutral-light':  '#F2F4F7',
    '--shadow-sm':      '0 1px 2px rgba(16,24,40,0.04), 0 1px 3px rgba(16,24,40,0.06)',
    '--shadow-md':      '0 2px 4px rgba(16,24,40,0.04), 0 4px 8px rgba(16,24,40,0.06)',
    '--shadow-lg':      '0 4px 6px rgba(16,24,40,0.04), 0 12px 24px rgba(16,24,40,0.08)',
    '--shadow-xl':      '0 8px 16px rgba(16,24,40,0.06), 0 20px 40px rgba(16,24,40,0.1)',
    '--shadow-hover':   '0 4px 12px rgba(16,24,40,0.08)',
    '--radius-sm':      '8px',
    '--radius-md':      '12px',
    '--radius-lg':      '16px',
    '--radius-xl':      '20px',
    '--radius-full':    '9999px',
    '--font-family':    "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
};

function applyStaticTokens() {
    const root = document.documentElement;
    Object.keys(STATIC_TOKENS).forEach(k => root.style.setProperty(k, STATIC_TOKENS[k]));
    // Apply font-family to body so it cascades into LWC light DOM. CSS custom
    // properties don't reach the shadow root by default — use computed value.
    document.body.style.fontFamily = STATIC_TOKENS['--font-family'];
}

// Inject Inter @font-face rules at the document level using ABSOLUTE URLs
// derived from the InterFont static resource path. This works around the
// fact that loadStyle's relative-URL resolution sometimes fails inside the
// Salesforce LWR runtime, leaving fonts unloaded and pages rendering with
// the OS default sans-serif.
function injectInterFont(baseUrl) {
    if (!baseUrl) return;
    if (document.getElementById('inter-font-styles')) return; // Idempotent.
    const style = document.createElement('style');
    style.id = 'inter-font-styles';
    style.textContent = [
        ['400', 'Inter-Regular'],
        ['500', 'Inter-Medium'],
        ['600', 'Inter-SemiBold'],
        ['700', 'Inter-Bold'],
        ['800', 'Inter-ExtraBold']
    ].map(([weight, file]) =>
        `@font-face{font-family:'Inter';font-style:normal;font-weight:${weight};` +
        `font-display:swap;src:url('${baseUrl}/${file}.woff2') format('woff2');}`
    ).join('\n');
    document.head.appendChild(style);
}

const BRAND_THEMES = {
    ken: {
        '--primary':        '#4C6EF5',
        '--primary-light':  '#EDF2FF',
        '--primary-dark':   '#3B5BDB',
        '--primary-hover':  '#4263EB',
        '--primary-50':     '#EDF2FF',
        '--primary-100':    '#DBE4FF',
        '--primary-500':    '#4C6EF5',
        '--primary-600':    '#4263EB',
        '--primary-700':    '#3B5BDB',
        '--info':           '#4C6EF5',
        '--info-light':     '#EDF2FF',
        '--sidebar-bg':     '#1a1f36',
        '--spotlight-from': '#6366F1',
        '--spotlight-to':   '#8B5CF6'
    },
    smu: {
        '--primary':        '#D97706',
        '--primary-light':  '#FFF7ED',
        '--primary-dark':   '#B45309',
        '--primary-hover':  '#C2660B',
        '--primary-50':     '#FFF7ED',
        '--primary-100':    '#FFEDD5',
        '--primary-500':    '#F97316',
        '--primary-600':    '#EA580C',
        '--primary-700':    '#C2410C',
        '--info':           '#D97706',
        '--info-light':     '#FFF7ED',
        '--sidebar-bg':     '#2E1F18',
        '--spotlight-from': '#F97316',
        '--spotlight-to':   '#FDBA74'
    }
};

function applyBrandTheme(brand) {
    const theme = BRAND_THEMES[brand] || BRAND_THEMES.ken;
    const root = document.documentElement;
    Object.keys(theme).forEach(k => root.style.setProperty(k, theme[k]));
}

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