import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getTransactions from '@salesforce/apex/KenTransactionHistoryController.getTransactions';
import initiatePayment from '@salesforce/apex/KenFeePaymentController.initiatePayment';

export default class TransactionHistory extends LightningElement {
    @track _apex;
    @track _wireResp;
    @track _searchTerm = '';
    @track _toastVisible = false;
    @track _toastMessage = '';
    @track _toastVariant = 'success';
    @track _retryingId;

    @wire(getTransactions)
    wiredTransactions(response) {
        this._wireResp = response;
        const { data, error } = response;
        if (data) this._apex = data;
        else if (error) {
            const _msg = (error && error.body && error.body.message) || '';
            if (_msg && !_msg.includes('not have access') && !_msg.includes('No rows')) {
                // eslint-disable-next-line no-console
                console.warn('[transactionHistory] Apex failed, using seed:', error);
            }
        }
    }

    get effectiveTransactions() {
        return (this._apex && this._apex.length) ? this._apex : [];
    }

    /**
     * Apex DTO: { id, transactionDate, amount, mode, gatewayRef, status, feeHead }
     * Mock:    { id, date, paymentMode, totalPaid, currency }
     * Normalise both shapes for the template.
     */
    get transactions() {
        const t = (this._searchTerm || '').toLowerCase().trim();
        const fmt = (n) => (n == null) ? '' : Number(n).toLocaleString('en-IN');
        return this.effectiveTransactions
            .map(x => {
                const id          = x.gatewayRef || x.id;
                const date        = x.date || x.transactionDate || '';
                const paymentMode = x.paymentMode || x.mode || '';
                const totalPaid   = x.totalPaid != null ? x.totalPaid : (x.amount != null ? fmt(x.amount) : '');
                const currency    = x.currency || 'INR';
                return {
                    id,
                    date,
                    paymentMode,
                    currency,
                    totalPaid,
                    status: x.status,
                    statusClass: x.status === 'Success' ? 'status success' : 'status failed',
                    isFailed: x.status === 'Failed',
                    hasReceipt: x.status === 'Success',
                    isRetrying: this._retryingId === x.id,
                    retryLabel: this._retryingId === x.id ? 'Retrying…' : 'Retry'
                };
            })
            .filter(x => !t || (x.id && String(x.id).toLowerCase().includes(t)) || (x.paymentMode && String(x.paymentMode).toLowerCase().includes(t)));
    }

    get showToast() { return this._toastVisible; }
    get toastMessage() { return this._toastMessage; }
    get toastVariant() { return this._toastVariant; }
    showAToast(msg, variant = 'success') { this._toastMessage = msg; this._toastVariant = variant; this._toastVisible = true; }
    handleToastClose() { this._toastVisible = false; }

    handleSearchInput(event) { this._searchTerm = event.target.value || ''; }

    handleRetry(event) {
        const id = event.currentTarget.dataset.id;
        const txn = this.effectiveTransactions.find(t => String(t.id) === String(id));
        if (!txn) return;
        this._retryingId = id;
        initiatePayment({ installmentId: txn.installmentId || null, amount: txn.totalPaid || txn.amount || 0 })
            .then(paymentId => {
                this._retryingId = null;
                this.showAToast(`Payment retried — ref ${paymentId}`);
                if (this._wireResp) refreshApex(this._wireResp);
            })
            .catch(err => {
                this._retryingId = null;
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Retry failed.';
                this.showAToast(msg, 'error');
            });
    }

    handleDownloadReceipt(event) {
        const id = event.currentTarget.dataset.id;
        const txn = this.effectiveTransactions.find(t => String(t.id) === String(id));
        if (!txn) return;
        const lines = [
            'Receipt — ' + (txn.id || ''),
            'Date: ' + (txn.date || ''),
            'Mode: ' + (txn.paymentMode || ''),
            'Currency: ' + (txn.currency || 'INR'),
            'Total Paid: ' + (txn.totalPaid || ''),
            'Status: ' + (txn.status || '')
        ].join('\n');
        try {
            const blob = new Blob([lines], { type: 'text/plain;charset=utf-8' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url; a.download = `receipt-${txn.id || 'txn'}.txt`;
            document.body.appendChild(a); a.click(); document.body.removeChild(a);
            setTimeout(() => URL.revokeObjectURL(url), 1500);
            this.showAToast('Receipt downloaded');
        } catch (e) { this.showAToast('Download failed', 'error'); }
    }

    navigateTo(route) {
        try {
            const parts = window.location.pathname.split('/').filter(Boolean);
            const base = parts[0] || 'newportal';
            const target = route === 'home' ? `/${base}/` : `/${base}/${route}`;
            window.location.href = target;
        } catch (e) {
            this.dispatchEvent(new CustomEvent('navigate', { detail: { route } }));
        }
    }
    handleBack() { this.navigateTo('fee-payment'); }
    goFeePayment() { this.navigateTo('fee-payment'); }
    goFeePlan() { this.navigateTo('fee-plan'); }
    goInvoices() { this.navigateTo('invoices'); }
    goRefunds() { this.navigateTo('refunds'); }
    handleGetHelp() { this.navigateTo('service-support'); }
}