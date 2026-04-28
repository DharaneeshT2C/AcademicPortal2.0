import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { pageNameForRoute } from 'c/navHelper';
import { feeData } from 'c/mockData';
import getInvoices from '@salesforce/apex/KenInvoicesController.getInvoices';
import getDownloadUrl from '@salesforce/apex/KenInvoicesController.getDownloadUrl';

export default class Invoices extends NavigationMixin(LightningElement) {
    @track _apex;
    // Seed fallback.
    _seed = feeData.invoices;

    @wire(getInvoices)
    wiredInvoices({ data, error }) {
        if (data) this._apex = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[invoices] Apex failed, using seed:', error);
        }
    }

    get invoices() {
        if (this._apex && this._apex.length) return this._apex;
        return this._seed;
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
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: pageNameForRoute(route) }
        });
    }
    handleBack() { this.navigateTo('fee-payment'); }
    goFeePayment() { this.navigateTo('fee-payment'); }
    goFeePlan() { this.navigateTo('fee-plan'); }
    goTransactions() { this.navigateTo('transaction-history'); }
    goRefunds() { this.navigateTo('refunds'); }
    handleGetHelp() { this.navigateTo('service-support'); }
}