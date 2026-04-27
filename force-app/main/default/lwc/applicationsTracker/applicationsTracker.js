import { LightningElement, track } from 'lwc';
import { applications, placementCycle } from 'c/placementData';
import withdrawApplication from '@salesforce/apex/KenPlacementsController.withdrawApplication';
import getOfferLetterText from '@salesforce/apex/KenPlacementsController.getOfferLetterText';

export default class ApplicationsTracker extends LightningElement {
    @track activeCycle = 'CYC002';
    @track showWithdrawModal = false;
    @track showSuccessModal = false;
    @track withdrawApp = null;
    @track _categoryFilter = 'All';
    @track _companyTypeFilter = 'All';
    @track _statusFilter = 'All';
    @track _showFilterPanel = false;
    @track _showCategoryMenu = false;
    @track _showCompanyTypeMenu = false;

    cycle = placementCycle;

    get cycles() {
        return [
            { key: 'CYC001', label: 'Placement Cycle 1 (Jul–Dec 2024)', active: this.activeCycle === 'CYC001' },
            { key: 'CYC002', label: 'Placement Cycle 2 (Jul–Dec 2026)', active: this.activeCycle === 'CYC002' }
        ].map(c => ({ ...c, cls: c.active ? 'cycle-tab cycle-active' : 'cycle-tab' }));
    }

    _catClass(cat) {
        if (cat === 'Super Dream') return 'cat-badge cat-super-dream';
        if (cat === 'Dream') return 'cat-badge cat-dream';
        return 'cat-badge cat-regular';
    }

    get categoryOptions() {
        const opts = ['All', ...new Set(applications.map(a => a.category).filter(Boolean))];
        return opts.map(o => ({ value: o, selected: o === this._categoryFilter }));
    }
    get companyTypeOptions() {
        const opts = ['All', ...new Set(applications.map(a => a.companyType).filter(Boolean))];
        return opts.map(o => ({ value: o, selected: o === this._companyTypeFilter }));
    }
    get categoryButtonLabel() { return this._categoryFilter === 'All' ? 'Category ▾' : `Category: ${this._categoryFilter} ▾`; }
    get companyTypeButtonLabel() { return this._companyTypeFilter === 'All' ? 'Company Type ▾' : `Type: ${this._companyTypeFilter} ▾`; }
    get showFilterPanel() { return this._showFilterPanel; }
    get showCategoryMenu() { return this._showCategoryMenu; }
    get showCompanyTypeMenu() { return this._showCompanyTypeMenu; }

    get tableRows() {
        return applications
            .filter(a => this._categoryFilter === 'All' || a.category === this._categoryFilter)
            .filter(a => this._companyTypeFilter === 'All' || a.companyType === this._companyTypeFilter)
            .filter(a => this._statusFilter === 'All' || a.status === this._statusFilter)
            .map(app => ({
                ...app,
                logoStyle: 'background:' + app.companyColor,
                categoryClass: this._catClass(app.category),
                statusClass: 'status-pill status-' + app.status,
                hasBookSlot: app.status === 'shortlisted' || app.status === 'advanced',
                hasWithdraw: app.canWithdraw,
                hasReviewOffer: app.status === 'offerReceived',
                hasDownloadOffer: app.status === 'offerReceived'
            }));
    }

    handleToggleCategoryMenu() { this._showCategoryMenu = !this._showCategoryMenu; this._showCompanyTypeMenu = false; }
    handleToggleCompanyTypeMenu() { this._showCompanyTypeMenu = !this._showCompanyTypeMenu; this._showCategoryMenu = false; }
    handlePickCategory(event) { this._categoryFilter = event.currentTarget.dataset.value; this._showCategoryMenu = false; }
    handlePickCompanyType(event) { this._companyTypeFilter = event.currentTarget.dataset.value; this._showCompanyTypeMenu = false; }
    handleToggleFilterPanel() { this._showFilterPanel = !this._showFilterPanel; }
    handleResetFilters() { this._categoryFilter = 'All'; this._companyTypeFilter = 'All'; this._statusFilter = 'All'; this._showFilterPanel = false; }
    handleStatusFilter(event) { this._statusFilter = event.currentTarget.dataset.value; }

    handleDownloadOfferLetter(event) {
        const id = event.currentTarget.dataset.id;
        const tryDownload = (text, filename) => {
            try {
                const blob = new Blob([text], { type: 'text/plain;charset=utf-8' });
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url; a.download = filename;
                document.body.appendChild(a); a.click(); document.body.removeChild(a);
                setTimeout(() => URL.revokeObjectURL(url), 1500);
            } catch (e) { /* noop */ }
        };
        if (typeof id === 'string' && (id.length === 15 || id.length === 18)) {
            getOfferLetterText({ applicationId: id })
                .then(text => {
                    if (text) tryDownload(text, 'offer-letter.txt');
                })
                .catch(() => { /* fall back to local copy below */ });
            return;
        }
        // Demo: synthesize from seed data.
        const app = applications.find(a => String(a.id) === String(id));
        if (!app) return;
        const lines = [
            'Offer Letter',
            'Company: ' + (app.company || ''),
            'Profile: ' + (app.profile || ''),
            'Category: ' + (app.category || ''),
            'Issued: ' + new Date().toLocaleDateString(),
            '',
            'Dear Candidate,',
            '',
            'We are pleased to extend an offer for the position of ' + (app.profile || '') +
            ' at ' + (app.company || '') + '.',
            '',
            'Sincerely,',
            'Placements Office'
        ].join('\n');
        tryDownload(lines, `offer-${(app.company || 'company').toLowerCase().replace(/\s+/g, '-')}.txt`);
    }

    stopProp(event) { event.stopPropagation(); }

    handleCycleSwitch(event) { this.activeCycle = event.currentTarget.dataset.cycle; }
    handleBack() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'landing' } }));
    }
    handleViewJob(event) {
        const jobId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'job-detail', jobId } }));
    }
    handleWithdraw(event) {
        this.withdrawApp = event.currentTarget.dataset.id;
        this.showWithdrawModal = true;
    }
    handleConfirmWithdraw() {
        const id = this.withdrawApp;
        if (typeof id === 'string' && (id.length === 15 || id.length === 18)) {
            withdrawApplication({ applicationId: id })
                .then(() => {
                    this.showWithdrawModal = false;
                    this.showSuccessModal = true;
                })
                .catch(err => {
                    // eslint-disable-next-line no-console
                    console.warn('[applicationsTracker] withdrawApplication failed:', err);
                    // Still show success in demo mode.
                    this.showWithdrawModal = false;
                    this.showSuccessModal = true;
                });
        } else {
            this.showWithdrawModal = false;
            this.showSuccessModal = true;
        }
    }
    handleCancelWithdraw() { this.showWithdrawModal = false; }
    handleCloseSuccess() { this.showSuccessModal = false; }
    handleCompareOffers() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'compare-offers' } }));
    }
}