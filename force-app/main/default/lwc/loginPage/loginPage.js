import { LightningElement, track } from 'lwc';
import LOGIN_BG from '@salesforce/resourceUrl/LoginBgImage';
import KEN_LOGO from '@salesforce/resourceUrl/KenLogo';
import login from '@salesforce/apex/LightningLoginFormController.login';

const START_URL = '/StudentPortalAcademics';

const ISSUE_TYPES = [
    { value: '', label: 'Select' },
    { value: 'technical', label: 'Technical Issue' },
    { value: 'account', label: 'Account Issue' },
    { value: 'access', label: 'Access Issue' },
    { value: 'other', label: 'Other' }
];

export default class LoginPage extends LightningElement {
    // ── view state ──
    @track currentView = 'login'; // 'login' | 'reset'
    @track isGetHelpOpen = false;
    @track showRequestSubmitted = false;
    @track showPasswordUpdated = false;

    // ── login form ──
    @track studentId = '';
    @track loginPassword = '';
    @track showLoginPassword = false;
    @track rememberMe = false;
    @track isLoggingIn = false;
    @track loginError = '';

    // ── reset password form ──
    @track newPassword = '';
    @track confirmPassword = '';
    @track showNewPwd = false;
    @track showConfirmPwd = false;

    // ── get help form ──
    @track helpDescription = '';
    @track helpIssueType = '';
    @track helpIssueSubject = '';
    @track uploadedFileName = '';

    // ── computed ──
    get bgStyle() { return `background-image: url('${LOGIN_BG}');`; }
    get kenLogoUrl() { return KEN_LOGO; }

    get isLoginView() { return this.currentView === 'login'; }
    get isResetView() { return this.currentView === 'reset'; }

    get loginPasswordType() { return this.showLoginPassword ? 'text' : 'password'; }
    get newPwdType() { return this.showNewPwd ? 'text' : 'password'; }
    get confirmPwdType() { return this.showConfirmPwd ? 'text' : 'password'; }
    get loginButtonLabel() { return this.isLoggingIn ? 'Logging in...' : 'Login'; }
    get isLoginDisabled() { return this.isLoggingIn; }

    get issueTypeOptions() {
        return ISSUE_TYPES.map((o) => ({ ...o, selected: o.value === this.helpIssueType }));
    }

    // ── navigation ──
    goToReset() { this.currentView = 'reset'; }
    goToLogin() {
        this.currentView = 'login';
        this.newPassword = '';
        this.confirmPassword = '';
        this.showPasswordUpdated = false;
    }

    // ── login handlers ──
    handleStudentIdChange(event) { this.studentId = event.target.value; }
    handleLoginPasswordChange(event) { this.loginPassword = event.target.value; }
    toggleLoginPassword() { this.showLoginPassword = !this.showLoginPassword; }
    handleRememberMe(event) { this.rememberMe = event.target.checked; }
    async handleLogin() {
        this.loginError = '';

        if (!this.studentId || !this.loginPassword) {
            this.loginError = 'Enter Student ID and Password.';
            return;
        }

        this.isLoggingIn = true;
        try {
            const loginResult = await login({
                username: this.studentId,
                password: this.loginPassword,
                startUrl: START_URL
            });

            if (loginResult && this.isLikelyUrl(loginResult)) {
                window.location.assign(loginResult);
                return;
            }

            // In this flow Apex returns a URL on success, or an error message on failure.
            if (loginResult) {
                this.loginError = loginResult;
            } else {
                this.loginError = 'Login failed. Please try again.';
            }
        } catch (error) {
            this.loginError = this.parseError(error);
        } finally {
            this.isLoggingIn = false;
        }
    }

    // ── reset password handlers ──
    handleNewPwdChange(event) { this.newPassword = event.target.value; }
    handleConfirmPwdChange(event) { this.confirmPassword = event.target.value; }
    toggleNewPwd() { this.showNewPwd = !this.showNewPwd; }
    toggleConfirmPwd() { this.showConfirmPwd = !this.showConfirmPwd; }
    handleResetSubmit() {
        this.showPasswordUpdated = true;
        setTimeout(() => {
            this.showPasswordUpdated = false;
            this.goToLogin();
        }, 2000);
    }

    // ── get help modal ──
    openGetHelp() { this.isGetHelpOpen = true; }
    closeGetHelp() {
        this.isGetHelpOpen = false;
        this.helpDescription = '';
        this.helpIssueType = '';
        this.helpIssueSubject = '';
        this.uploadedFileName = '';
    }
    handleBackdropClick() { this.closeGetHelp(); }
    stopProp(event) { event.stopPropagation(); }

    handleHelpDescChange(event) { this.helpDescription = event.target.value; }
    handleIssueTypeChange(event) { this.helpIssueType = event.target.value; }
    handleIssueSubjectChange(event) { this.helpIssueSubject = event.target.value; }

    handleFileChange(event) {
        const file = event.target.files?.[0];
        if (file) this.uploadedFileName = file.name;
    }
    handleDragOver(event) { event.preventDefault(); }
    handleDrop(event) {
        event.preventDefault();
        const file = event.dataTransfer?.files?.[0];
        if (file) this.uploadedFileName = file.name;
    }

    handleHelpSubmit() {
        this.isGetHelpOpen = false;
        this.showRequestSubmitted = true;
        setTimeout(() => {
            this.showRequestSubmitted = false;
            this.helpDescription = '';
            this.helpIssueType = '';
            this.helpIssueSubject = '';
            this.uploadedFileName = '';
        }, 2500);
    }

    parseError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        return 'Unable to login. Please try again.';
    }

    isLikelyUrl(value) {
        return typeof value === 'string' && (value.startsWith('http://') || value.startsWith('https://') || value.startsWith('/'));
    }
}