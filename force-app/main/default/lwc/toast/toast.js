import { LightningElement, api } from 'lwc';
export default class Toast extends LightningElement {
    @api message = '';
    @api variant = 'success';
    connectedCallback() {
        setTimeout(() => { this.dispatchEvent(new CustomEvent('close')); }, 3000);
    }
    get toastClass() { return 'toast toast-' + this.variant; }
    get iconName() {
        if (this.variant === 'success') return 'check_circle';
        if (this.variant === 'warning') return 'warning';
        if (this.variant === 'error')   return 'error';
        return 'info';
    }
    handleClose() { this.dispatchEvent(new CustomEvent('close')); }
}