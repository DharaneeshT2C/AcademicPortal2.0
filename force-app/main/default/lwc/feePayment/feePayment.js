import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { feeData } from 'c/mockData';
import getFeeSummary    from '@salesforce/apex/KenFeePaymentController.getFeeSummary';
import initiatePayment  from '@salesforce/apex/KenFeePaymentController.initiatePayment';
import confirmPayment   from '@salesforce/apex/KenFeePaymentController.confirmPayment';

const PAY_METHODS = [
    { id: 'UPI',         label: 'UPI',           hint: 'Pay via PhonePe, GPay, Paytm', icon: 'phone_android' },
    { id: 'Card',        label: 'Card',          hint: 'Debit or credit card',         icon: 'credit_card'   },
    { id: 'Net Banking', label: 'Net Banking',   hint: 'All major banks',              icon: 'account_balance' },
    { id: 'Wallet',      label: 'Wallet',        hint: 'Paytm, Mobikwik, etc.',        icon: 'account_balance_wallet' }
];

export default class FeePayment extends LightningElement {
    @track _apex;
    _seed = feeData;
    @track showToast = false;
    @track toastMessage = '';
    @track toastVariant = 'success';

    // Razorpay-style multi-step modal state.
    // Step 1: 'method'   — choose UPI / Card / NB / Wallet
    // Step 2: 'gateway'  — mock Razorpay overlay (loading)
    // Step 3: 'success'  — receipt
    // Step 3': 'failure' — failure with retry
    @track payStep = '';                 // '' = closed
    @track selectedMethod = 'UPI';
    @track selectedInstallment = null;   // { installmentId, feeHead, amount, dueDate }
    @track gatewayRef = '';
    @track paymentId = null;
    @track _busy = false;

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
            if (f.status === 'Partially Paid') cls += ' partial';
            else if (f.status === 'Pending')    cls += ' pending';
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
    get formattedTotalPaid()    { return this._formatNum(this.data.totalPaid); }
    get formattedTotalPaidOf()  { return this._formatNum(this.data.totalPaidOf); }
    get formattedPending()      { return this._formatNum(this.data.totalPending); }
    get formattedPendingOf()    { return this._formatNum(this.data.totalPendingOf); }
    get formattedFeeAmount()    { return this._formatNum(this.data.totalFeeAmount); }
    _formatNum(n) {
        if (!n) return '0';
        return Number(n).toLocaleString('en-IN');
    }

    // ── Modal step booleans ──────────────────────────────────────────────────
    get showPayModal()       { return !!this.payStep; }
    get isStepMethod()       { return this.payStep === 'method'; }
    get isStepGateway()      { return this.payStep === 'gateway'; }
    get isStepSuccess()      { return this.payStep === 'success'; }
    get isStepFailure()      { return this.payStep === 'failure'; }

    get formattedMethods() {
        return PAY_METHODS.map(m => ({
            ...m,
            isSelected: m.id === this.selectedMethod,
            cardClass: m.id === this.selectedMethod ? 'pay-method-card selected' : 'pay-method-card'
        }));
    }

    get formattedSelectedAmount() { return this._formatNum(this.selectedInstallment ? this.selectedInstallment.amount : 0); }
    get selectedFeeHead()         { return (this.selectedInstallment && this.selectedInstallment.feeHead) || 'Tuition fee'; }
    get selectedDueDate()         { return (this.selectedInstallment && this.selectedInstallment.dueDate) || ''; }

    // ── Routing helpers ──────────────────────────────────────────────────────
    navigateTo(route) { this.dispatchEvent(new CustomEvent('navigate', { detail: { route } })); }
    handleViewPlan()      { this.navigateTo('fee-plan'); }
    handleViewDetails()   { this.navigateTo('fee-payment-detail'); }
    handleTransactions()  { this.navigateTo('transaction-history'); }
    handleInvoices()      { this.navigateTo('invoices'); }
    handleRefunds()       { this.navigateTo('refunds'); }

    // ── Step 1: pick method ──────────────────────────────────────────────────
    handleMakePayments() {
        // Pick the first non-Paid installment as the target.
        const fees = this.currentFees || [];
        const target = fees.find(f => f.status !== 'Paid') || fees[0] || null;
        this.selectedInstallment = target ? {
            installmentId: target.installmentId || target.id || null,
            feeHead: target.item || target.feeHead || 'Tuition Fee',
            amount: this._toNumber(target.totalPayable || target.amount || this.data.totalPending || 0),
            dueDate: target.dueDate || ''
        } : { installmentId: null, feeHead: 'Tuition Fee', amount: this._toNumber(this.data.totalPending), dueDate: '' };
        this.selectedMethod = 'UPI';
        this.payStep = 'method';
    }
    _toNumber(v) {
        if (typeof v === 'number') return v;
        const n = Number(String(v || '').replace(/[, ]/g, ''));
        return isFinite(n) ? n : 0;
    }

    handleClosePayModal() {
        if (this._busy) return; // don't allow close mid-gateway
        this.payStep = '';
        this.gatewayRef = '';
        this.paymentId = null;
    }
    stopProp(event) { event.stopPropagation(); }

    handleSelectMethod(event) {
        const id = event.currentTarget.dataset.id;
        if (id) this.selectedMethod = id;
    }

    // ── Step 1 → Step 2 (gateway) ────────────────────────────────────────────
    handleProceedToGateway() {
        if (!this.selectedInstallment || !this.selectedInstallment.amount) {
            this._toast('No outstanding installment to pay.', 'info');
            this.handleClosePayModal();
            return;
        }
        this._busy = true;
        this.payStep = 'gateway';
        const { installmentId, amount } = this.selectedInstallment;
        // If we have a real installment id, hit Apex; otherwise simulate.
        const initStart = installmentId
            ? initiatePayment({ installmentId, amount })
            : Promise.resolve(null);
        initStart
            .then(payId => {
                this.paymentId = payId;
                // Simulate Razorpay processing time, then auto-confirm success.
                return new Promise(resolve => setTimeout(resolve, 2200));
            })
            .then(() => this._finalisePayment(true))
            .catch(err => {
                // eslint-disable-next-line no-console
                console.warn('[feePayment] initiate/confirm failed:', err);
                this._busy = false;
                this.payStep = 'failure';
            });
    }

    _finalisePayment(success) {
        const mode = this.selectedMethod;
        const gwRef = 'rzp_' + Math.random().toString(36).substring(2, 10).toUpperCase();
        this.gatewayRef = gwRef;
        if (this.paymentId) {
            confirmPayment({ paymentId: this.paymentId, success, mode, gatewayRef: gwRef })
                .then(() => {
                    this._busy = false;
                    this.payStep = success ? 'success' : 'failure';
                    if (this._wireResp) refreshApex(this._wireResp);
                })
                .catch(err => {
                    // eslint-disable-next-line no-console
                    console.warn('[feePayment] confirmPayment failed:', err);
                    this._busy = false;
                    this.payStep = 'failure';
                });
        } else {
            this._busy = false;
            this.payStep = success ? 'success' : 'failure';
        }
    }

    handleRetry() { this.payStep = 'method'; }

    handleDoneSuccess() {
        this.payStep = '';
        this._toast('Payment successful (' + this.gatewayRef + ')', 'success');
        if (this._wireResp) refreshApex(this._wireResp);
    }

    handleDownloadInvoice() {
        this._toast('Invoice downloaded successfully', 'success');
    }
    handleRetryTransaction() {
        this._toast('Retrying transaction. Please wait...', 'info');
    }
    handleToastClose() { this.showToast = false; }

    _toast(msg, variant) {
        this.toastMessage = msg;
        this.toastVariant = variant || 'success';
        this.showToast = true;
    }
}