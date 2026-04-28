import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getRefunds from '@salesforce/apex/KenRefundsController.getRefunds';
import createRefundRequest from '@salesforce/apex/KenRefundsController.createRefundRequest';

export default class Refunds extends LightningElement {
    @track _apex;
    @track _wireResp;
    @track _toastVisible = false;
    @track _toastMessage = '';
    @track _toastVariant = 'success';
    showAToast(msg, v = 'success') { this._toastMessage = msg; this._toastVariant = v; this._toastVisible = true; }
    handleToastClose() { this._toastVisible = false; }
    get showToast() { return this._toastVisible; }
    get toastMessage() { return this._toastMessage; }
    get toastVariant() { return this._toastVariant; }

    @wire(getRefunds)
    wiredRefunds(response) {
        this._wireResp = response;
        const { data, error } = response;
        if (data) this._apex = data;
        else if (error) {
            const _msg = (error && error.body && error.body.message) || '';
            if (_msg && !_msg.includes('not have access') && !_msg.includes('No rows')) {
                // eslint-disable-next-line no-console
                console.warn('[refunds] Apex failed, using seed:', error);
            }
        }
    }

    get effectiveRefunds() {
        return (this._apex && this._apex.length) ? this._apex : [];
    }

    get hasRefunds() {
        return this.effectiveRefunds && this.effectiveRefunds.length > 0;
    }
    /**
     * Apex DTO: { id, requestDate, amount, reason, status, processedDate, originalPaymentRef }
     * Mock:    { id, requestDate, feeItem, currency, amount, status, processedOn }
     * Normalise both shapes for the template.
     */
    get formattedRefunds() {
        const fmt = (n) => (n == null) ? '' : Number(n).toLocaleString('en-IN');
        return this.effectiveRefunds.map(r => {
            let cls = 'status';
            if (r.status === 'Processed' || r.status === 'Approved') cls += ' success';
            else if (r.status === 'Pending') cls += ' pending';
            else if (r.status === 'Rejected') cls += ' rejected';
            const id = r.id ? (String(r.id).startsWith('a') ? 'REF-' + String(r.id).slice(-6).toUpperCase() : r.id) : '';
            return {
                id,
                requestDate: r.requestDate || '',
                feeItem: r.feeItem || r.reason || 'Tuition fee',
                currency: r.currency || 'INR',
                amount: typeof r.amount === 'number' ? fmt(r.amount) : (r.amount || ''),
                status: r.status,
                statusClass: cls,
                processedOn: r.processedOn || r.processedDate || (r.status === 'Pending' ? '--' : '')
            };
        });
    }

    handleCreateRefund(event) {
        const req = (event && event.detail) || {};
        createRefundRequest({ req })
            .then(id => {
                this.showAToast(`Refund request submitted (id ${id || ''})`);
                if (this._wireResp) refreshApex(this._wireResp);
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not submit refund.';
                this.showAToast(msg, 'error');
            });
    }

    @track _searchTerm = '';
    handleSearchInput(event) { this._searchTerm = event.target.value || ''; }
    get filteredRefunds() {
        const t = (this._searchTerm || '').toLowerCase().trim();
        if (!t) return this.formattedRefunds;
        return this.formattedRefunds.filter(r =>
            (r.id && String(r.id).toLowerCase().includes(t)) ||
            (r.feeItem && String(r.feeItem).toLowerCase().includes(t)) ||
            (r.status && String(r.status).toLowerCase().includes(t))
        );
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
    goFeePayment() { this.navigateTo('fee-payment'); }
    goFeePlan() { this.navigateTo('fee-plan'); }
    goInvoices() { this.navigateTo('invoices'); }
    goTransactions() { this.navigateTo('transaction-history'); }
    handleGetHelp() { this.navigateTo('service-support'); }
}