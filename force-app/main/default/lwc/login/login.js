import { LightningElement, track } from 'lwc';
import doLogin from '@salesforce/apex/KenPortalLoginController.login';

export default class Login extends LightningElement {
    @track studentId = '';
    @track password = '';
    @track showPassword = false;
    @track rememberMe = false;
    @track errorMessage = '';
    @track submitting = false;

    handleStudentIdChange(event) {
        this.studentId = event.target.value;
    }

    handlePasswordChange(event) {
        this.password = event.target.value;
    }

    togglePassword() {
        this.showPassword = !this.showPassword;
    }

    get passwordType() {
        return this.showPassword ? 'text' : 'password';
    }

    get hasError() {
        return !!this.errorMessage;
    }

    handleRememberMe() {
        this.rememberMe = !this.rememberMe;
    }

    async handleLogin(event) {
        if (event && event.preventDefault) event.preventDefault();
        this.errorMessage = '';

        if (!this.studentId || !this.password) {
            this.errorMessage = 'Please enter your student ID and password.';
            return;
        }

        this.submitting = true;
        try {
            // Preserve intended destination if user hit /newportal/<something> first
            const base = window.location.pathname.split('/').filter(Boolean)[0] || 'newportal';
            const startUrl = `/${base}/`;
            const redirect = await doLogin({
                username: this.studentId,
                password: this.password,
                startUrl
            });
            if (redirect) {
                window.location.href = redirect;
            } else {
                window.location.href = startUrl;
            }
        } catch (err) {
            this.errorMessage = (err && err.body && err.body.message) || 'Login failed. Please try again.';
        } finally {
            this.submitting = false;
        }
    }
}