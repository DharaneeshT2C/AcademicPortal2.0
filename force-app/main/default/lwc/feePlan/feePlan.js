import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getPlans from '@salesforce/apex/KenFeePlanController.getPlans';
import getFeeSummary from '@salesforce/apex/KenFeePaymentController.getFeeSummary';
import switchToPlan from '@salesforce/apex/KenFeePlanController.switchToPlan';

export default class FeePlan extends LightningElement {
    @track _apex;
    @track _summary;
    @track _wireResp;

    @wire(getPlans)
    wiredPlans(response) {
        this._wireResp = response;
        const { data, error } = response;
        if (data) this._apex = data;
        else if (error) {
            const _msg = (error && error.body && error.body.message) || '';
            if (_msg && !_msg.includes('not have access') && !_msg.includes('No rows')) {
                // eslint-disable-next-line no-console
                console.warn('[feePlan] Apex failed, using seed:', error);
            }
        }
    }

    @wire(getFeeSummary)
    wiredSummary({ data, error }) {
        if (data) this._summary = data;
        else if (error) {
            const _msg = (error && error.body && error.body.message) || '';
            if (_msg && !_msg.includes('not have access') && !_msg.includes('No rows')) {
                // eslint-disable-next-line no-console
                console.warn('[feePlan] getFeeSummary failed, using seed:', error);
            }
        }
    }

    get data() {
        return this._apex || {};
    }

    _fmt(n) { return (n == null) ? '' : Number(n).toLocaleString('en-IN'); }

    get planItems() {
        // Prefer real installments from KenFeePaymentController.getFeeSummary
        // (FeeLineDTO has the right shape: feeHead/amount/dueDate/status).
        const real = this._summary && this._summary.installments;
        if (real && real.length) {
            return real.map(r => ({
                item:         r.feeHead || 'Installment',
                dueDate:      r.dueDate || '',
                currency:     'INR',
                totalAmount:  this._fmt(r.amount),
                concession:   '0',
                tax:          '0',
                tds:          '0',
                totalPayable: this._fmt(r.amount),
                status:       r.status,
                hasChildren:  false,
                formattedChildren: []
            }));
        }
        return [];
    }

    get formattedSemesters() {
        // Use real installments to compute the semester total when available.
        const real = this._summary && this._summary.installments;
        if (real && real.length) {
            const total = real.reduce((sum, r) => sum + (r.amount || 0), 0);
            return [{
                name: 'Current Semester',
                hasFees: true,
                formattedAmount: '\u20B9' + this._fmt(total),
                expandIcon: 'expand_less'
            }];
        }
        return [];
    }

    @track _toastVisible = false;
    @track _toastMessage = '';
    @track _toastVariant = 'success';

    get showToast() { return this._toastVisible; }
    get toastMessage() { return this._toastMessage; }
    get toastVariant() { return this._toastVariant; }
    showAToast(msg, variant = 'success') {
        this._toastMessage = msg; this._toastVariant = variant; this._toastVisible = true;
    }
    handleToastClose() { this._toastVisible = false; }

    handleSelectPlan(event) {
        const planId = event.currentTarget.dataset.id;
        if (!planId) return;
        switchToPlan({ planId })
            .then(() => {
                this.showAToast('Plan updated');
                if (this._wireResp) refreshApex(this._wireResp);
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not switch plan.';
                this.showAToast(msg, 'error');
            });
    }

    handleDownloadFeePlan(event) {
        const semName = (event && event.currentTarget && event.currentTarget.dataset)
            ? event.currentTarget.dataset.sem : 'Fee Plan';
        const rows = this.planItems;
        const lines = [
            'Fee Plan — ' + semName,
            'Generated: ' + new Date().toLocaleString(),
            '',
            ['Item', 'Due Date', 'Currency', 'Total', 'Concession', 'Tax', 'TDS', 'Payable', 'Status'].join(',')
        ];
        rows.forEach(r => {
            lines.push([r.item, r.dueDate, r.currency, r.totalAmount, r.concession, r.tax, r.tds, r.totalPayable, r.status || ''].map(v => `"${(v == null ? '' : String(v)).replace(/"/g, '""')}"`).join(','));
            (r.formattedChildren || []).forEach(c => {
                lines.push(['  ' + c.item, c.dueDate, c.currency, c.totalAmount, c.concession, c.tax, c.tds, c.totalPayable, ''].map(v => `"${(v == null ? '' : String(v)).replace(/"/g, '""')}"`).join(','));
            });
        });
        const csv = lines.join('\n');
        try {
            const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url; a.download = `fee-plan-${semName.replace(/\s+/g, '-').toLowerCase()}.csv`;
            document.body.appendChild(a); a.click(); document.body.removeChild(a);
            setTimeout(() => URL.revokeObjectURL(url), 1500);
            this.showAToast('Fee plan downloaded');
        } catch (e) {
            // eslint-disable-next-line no-console
            console.warn('[feePlan] download failed:', e);
            this.showAToast('Download failed in this browser', 'error');
        }
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
    goInvoices() { this.navigateTo('invoices'); }
    goTransactions() { this.navigateTo('transaction-history'); }
    goRefunds() { this.navigateTo('refunds'); }
}