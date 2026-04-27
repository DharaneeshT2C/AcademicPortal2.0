import { LightningElement, api } from 'lwc';

export default class CustomToast extends LightningElement {
    @api title = 'Main Header';
    @api message = '';
    @api variant = 'success'; // success, error, warning
    @api autoCloseTime = 3000;

    show = false;
    toastTitle;
    toastMessage;
    toastVariant;
    toastDuration = 3000;
    animationName = 'toastLifecycleA';

    @api
    showToast(title, message, variant, options = {}) {
        this.toastTitle = title || this.title;
        this.toastMessage = message ?? '';
        this.toastVariant = variant || this.variant || 'success';
        this.toastDuration = this.resolveDuration(options?.autoCloseTime ?? this.autoCloseTime);
        this.animationName = this.animationName === 'toastLifecycleA' ? 'toastLifecycleB' : 'toastLifecycleA';
        this.show = true;
    }

    get containerClass() {
        return `toast-container ${this.currentVariant}`;
    }

    get containerStyle() {
        return `animation-name: ${this.animationName}; animation-duration: ${this.toastDuration}ms;`;
    }

    get isSuccess() {
        return this.currentVariant === 'success';
    }

    get isError() {
        return this.currentVariant === 'error';
    }

    get isWarning() {
        return this.currentVariant === 'warning';
    }

    get isInfo() {
        return this.currentVariant === 'info';
    }

    get displayTitle() {
        return this.toastTitle ?? this.title;
    }

    get displayMessage() {
        return this.toastMessage ?? this.message;
    }

    get currentVariant() {
        return this.toastVariant || this.variant || 'success';
    }

    handleAnimationEnd(event) {
        if (event.target !== event.currentTarget || !this.show) {
            return;
        }

        this.closeToast();
    }

    handleClose() {
        this.closeToast();
    }

    resolveDuration(value) {
        const parsed = Number(value);
        return Number.isFinite(parsed) && parsed > 0 ? parsed : 3000;
    }

    closeToast() {
        this.show = false;
        this.dispatchEvent(new CustomEvent('toastclosed', { bubbles: true, composed: true }));
    }
}