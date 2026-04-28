import { LightningElement, api, track } from 'lwc';
import getInstallmentDetail from '@salesforce/apex/KenFeePaymentController.getInstallmentDetail';
import initiatePayment       from '@salesforce/apex/KenFeePaymentController.initiatePayment';

export default class FeePaymentDetail extends LightningElement {
    @api installmentId;
    @track _apex;
    @track _payRef;
    @track _paying = false;
    @track _toastVisible = false;
    @track _toastMessage = '';
    @track _toastVariant = 'success';

    connectedCallback() {
        if (this.installmentId) {
            getInstallmentDetail({ installmentId: this.installmentId })
                .then(detail => { this._apex = detail; })
                .catch(err => {
                    // eslint-disable-next-line no-console
                    console.warn('[feePaymentDetail] getInstallmentDetail failed, using seed:', err);
                });
        }
    }

    get data() { return this._apex || {}; }
    get semester() { return {}; }

    get fees() {
        if (this._apex && this._apex.item) {
            const row = { ...this._apex, hasChildren: false, formattedChildren: [] };
            return [row];
        }
        return [];
    }

    get payButtonLabel() { return this._paying ? 'Processing…' : 'Make Payment'; }
    get isPayDisabled() { return this._paying; }
    get hasPayRef() { return !!this._payRef; }
    get showToast() { return this._toastVisible; }
    get toastMessage() { return this._toastMessage; }
    get toastVariant() { return this._toastVariant; }

    showAToast(msg, variant = 'success') {
        this._toastMessage = msg; this._toastVariant = variant; this._toastVisible = true;
    }
    handleToastClose() { this._toastVisible = false; }

    navigateTo(route) { this.dispatchEvent(new CustomEvent('navigate', { detail: { route } })); }
    handleBack() { this.navigateTo('fee-payment'); }

    handleMakePayment() {
        if (this._paying) return;
        const amount = (this._apex && this._apex.amount) ? this._apex.amount : 0;
        const installmentId = this.installmentId || (this._apex && this._apex.installmentId);
        if (!amount || amount <= 0) {
            this.showAToast('Nothing to pay — this installment is settled.', 'info');
            return;
        }
        this._paying = true;
        initiatePayment({ installmentId: installmentId || null, amount: amount })
            .then(paymentId => {
                this._paying = false;
                this._payRef = String(paymentId || '');
                this.showAToast(`Payment initiated. Reference: ${this._payRef}`);
                // Re-fetch the installment so any new pending payment is reflected.
                if (this.installmentId) {
                    getInstallmentDetail({ installmentId: this.installmentId })
                        .then(detail => { this._apex = detail; })
                        .catch(() => { /* leave existing data */ });
                }
            })
            .catch(err => {
                this._paying = false;
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not start payment.';
                this.showAToast(msg, 'error');
            });
    }
}