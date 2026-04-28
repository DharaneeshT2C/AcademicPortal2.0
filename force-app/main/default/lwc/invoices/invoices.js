import { LightningElement, wire, track } from 'lwc';
import getInvoices from '@salesforce/apex/KenInvoicesController.getInvoices';
import getDownloadUrl from '@salesforce/apex/KenInvoicesController.getDownloadUrl';

export default class Invoices extends LightningElement {
    @track _apex;

    @wire(getInvoices)
    wiredInvoices({ data, error }) {
        if (data) this._apex = data;
        else if (error) {
            const _msg = (error && error.body && error.body.message) || '';
            if (_msg && !_msg.includes('not have access') && !_msg.includes('No rows')) {
                // eslint-disable-next-line no-console
                console.warn('[invoices] Apex failed, using seed:', error);
            }
        }
    }

    /**
     * Apex DTO: { id, invoiceNumber, description, amount, issuedOn, status, downloadUrl }
     * Mock data: { id, particulars, invoiceId, date, totalPaid, currency, remaining, proForma, invoice }
     * Normalise to a single shape the template can render.
     */
    get invoices() {
        const fmt = (n) => (n == null) ? '' : Number(n).toLocaleString('en-IN');
        if (this._apex && this._apex.length) {
            return this._apex.map(r => ({
                id: r.id,
                particulars: r.description || r.particulars || 'Tuition fee',
                invoiceId: r.invoiceNumber || r.invoiceId || (r.id ? String(r.id).slice(-8) : ''),
                date: r.issuedOn || r.date || '',
                totalPaid: fmt(r.amount != null ? r.amount : r.totalPaid),
                currency: r.currency || 'INR',
                remaining: r.status === 'Paid' ? '0' : (r.remaining || fmt(r.amount)),
                proForma: !!(r.downloadUrl || r.proForma),
                invoice: r.status === 'Paid'
            }));
        }
        return [];
    }

    @track _bannerMsg;
    @track _bannerVariant = 'info';
    get hasBanner() { return !!this._bannerMsg; }
    get bannerClass() { return 'info-banner ' + this._bannerVariant; }
    get bannerMessage() { return this._bannerMsg; }
    handleDismissBanner() { this._bannerMsg = null; }

    handleDownload(event) {
        const invoiceId = event.currentTarget.dataset.id;
        if (!invoiceId) return;
        getDownloadUrl({ invoiceId })
            .then(url => {
                if (url) { window.open(url, '_blank'); }
                else {
                    this._bannerMsg = 'Invoice PDF is not available yet — try again in a few seconds.';
                    this._bannerVariant = 'info';
                }
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not download invoice.';
                this._bannerMsg = msg;
                this._bannerVariant = 'error';
            });
    }

    @track _searchTerm = '';
    handleSearchInput(event) { this._searchTerm = event.target.value || ''; }
    get filteredInvoices() {
        const t = (this._searchTerm || '').toLowerCase().trim();
        const list = this.invoices;
        if (!t) return list;
        return list.filter(i =>
            (i.particulars && String(i.particulars).toLowerCase().includes(t)) ||
            (i.invoiceId && String(i.invoiceId).toLowerCase().includes(t)) ||
            (i.id && String(i.id).toLowerCase().includes(t))
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
    handleBack() { this.navigateTo('fee-payment'); }
    goFeePayment() { this.navigateTo('fee-payment'); }
    goFeePlan() { this.navigateTo('fee-plan'); }
    goTransactions() { this.navigateTo('transaction-history'); }
    goRefunds() { this.navigateTo('refunds'); }
    handleGetHelp() { this.navigateTo('service-support'); }
}