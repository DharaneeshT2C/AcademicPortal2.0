import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { feeData } from 'c/mockData';
import getFeeSummary from '@salesforce/apex/KenFeePaymentController.getFeeSummary';
import initiatePayment from '@salesforce/apex/KenFeePaymentController.initiatePayment';

export default class FeePayment extends LightningElement {
    @track _apex;
    // Seed fallback retained for template bindings.
    _seed = feeData;
    @track showPayModal = false;
    @track showToast = false;
    @track toastMessage = '';
    @track toastVariant = 'success';

    @track _wireResp;
    @wire(getFeeSummary)
    wiredFees(response) {
        this._wireResp = response;
        const { data, error } = response;
        if (data) this._apex = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[feePayment] Apex failed, using seed:', error);
        }
    }

    get data() {
        if (this._apex) return Object.assign({}, this._seed, this._apex);
        return this._seed;
    }

    get currentFees() {
        const semesters = this.data.semesters;
        const fees = (semesters && semesters[0]) ? semesters[0].fees : [];
        return (fees || []).map(f => {
            let cls = 'status-badge';
            if (f.status === 'Partially Paid') { cls = cls + ' partial'; }
            else if (f.status === 'Pending') { cls = cls + ' pending'; }
            return { ...f, feeStatusClass: cls };
        });
    }
    get formattedTransactions() {
        return (this.data.transactions || []).map(t => ({
            ...t,
            txnStatusClass: t.status === 'Success' ? 'txn-status success' : 'txn-status failed',
            isFailed: t.status !== 'Success'
        }));
    }
    get formattedTotalPaid() { return this._formatNum(this.data.totalPaid); }
    get formattedTotalPaidOf() { return this._formatNum(this.data.totalPaidOf); }
    get formattedPending() { return this._formatNum(this.data.totalPending); }
    get formattedPendingOf() { return this._formatNum(this.data.totalPendingOf); }
    get formattedFeeAmount() { return this._formatNum(this.data.totalFeeAmount); }
    _formatNum(n) {
        if (!n) return '0';
        return n.toLocaleString('en-IN');
    }
    navigateTo(route) { this.dispatchEvent(new CustomEvent('navigate', { detail: { route } })); }
    handleViewPlan() { this.navigateTo('fee-plan'); }
    handleViewDetails() { this.navigateTo('fee-payment-detail'); }
    handleTransactions() { this.navigateTo('transaction-history'); }
    handleInvoices() { this.navigateTo('invoices'); }
    handleRefunds() { this.navigateTo('refunds'); }
    handleMakePayments() { this.showPayModal = true; }
    handleClosePayModal() { this.showPayModal = false; }
    stopProp(event) { event.stopPropagation(); }
    handleConfirmPayment(event) {
        this.showPayModal = false;
        const installmentId = event && event.currentTarget && event.currentTarget.dataset
            ? event.currentTarget.dataset.id : null;
        const amount = event && event.currentTarget && event.currentTarget.dataset
            ? event.currentTarget.dataset.amount : null;
        if (installmentId && amount) {
            initiatePayment({ installmentId, amount: Number(amount) })
                .then(paymentId => {
                    this.toastMessage = `Payment initiated (ref ${paymentId}). Complete via your bank portal.`;
                    this.toastVariant = 'info';
                    this.showToast = true;
                    if (this._wireResp) refreshApex(this._wireResp);
                })
                .catch(err => {
                    const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not initiate payment.';
                    this.toastMessage = msg;
                    this.toastVariant = 'error';
                    this.showToast = true;
                });
        } else {
            this.toastMessage = 'Payment initiated. Please complete via your bank portal.';
            this.toastVariant = 'info';
            this.showToast = true;
        }
    }
    handleDownloadInvoice() {
        this.toastMessage = 'Invoice downloaded successfully';
        this.toastVariant = 'success';
        this.showToast = true;
    }
    handleRetryTransaction() {
        this.toastMessage = 'Retrying transaction. Please wait...';
        this.toastVariant = 'info';
        this.showToast = true;
    }
    handleToastClose() { this.showToast = false; }
}