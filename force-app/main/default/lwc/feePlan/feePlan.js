import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { feeData } from 'c/mockData';
import getPlans from '@salesforce/apex/KenFeePlanController.getPlans';
import switchToPlan from '@salesforce/apex/KenFeePlanController.switchToPlan';

export default class FeePlan extends LightningElement {
    @track _apex;
    @track _wireResp;
    _seed = feeData;

    @wire(getPlans)
    wiredPlans(response) {
        this._wireResp = response;
        const { data, error } = response;
        if (data) this._apex = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[feePlan] Apex failed, using seed:', error);
        }
    }

    get data() {
        return this._seed;
    }

    get planItems() {
        // If Apex has returned plan options, surface them alongside the seed shape expected
        // by the template. Falls back to the legacy feePlan list otherwise.
        if (this._apex && this._apex.length) {
            return this._apex.map(p => ({
                ...p,
                hasChildren: false,
                formattedChildren: []
            }));
        }
        return this._seed.feePlan.map(f => ({
            ...f,
            hasChildren: f.children && f.children.length > 0,
            formattedChildren: f.children || []
        }));
    }

    get formattedSemesters() {
        return this._seed.semesters.map((s, i) => ({
            ...s,
            hasFees: i === 0,
            formattedAmount: '\u20B9' + (s.totalFeeAmount ? s.totalFeeAmount.toLocaleString('en-IN') : '0'),
            expandIcon: i === 0 ? 'expand_less' : 'expand_more'
        }));
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

    navigateTo(route) { this.dispatchEvent(new CustomEvent('navigate', { detail: { route } })); }
    handleBack() { this.navigateTo('fee-payment'); }
    goFeePayment() { this.navigateTo('fee-payment'); }
    goInvoices() { this.navigateTo('invoices'); }
    goTransactions() { this.navigateTo('transaction-history'); }
    goRefunds() { this.navigateTo('refunds'); }
}