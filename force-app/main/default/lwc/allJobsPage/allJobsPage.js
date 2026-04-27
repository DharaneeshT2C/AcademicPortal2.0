import { LightningElement, track } from 'lwc';
import { jobs, studentPlacementStatus } from 'c/placementData';
import toggleSaveJob from '@salesforce/apex/KenPlacementsController.toggleSaveJob';

export default class AllJobsPage extends LightningElement {
    @track jobsTab = 'recommended';
    @track railTab = 'applied';
    @track preferenceTags = [...studentPlacementStatus.preferences];
    @track _savedJobs = new Set();
    @track _toastVisible = false;
    @track _toastMessage = '';
    @track _toastVariant = 'success';

    get showToast() { return this._toastVisible; }
    get toastMessage() { return this._toastMessage; }
    get toastVariant() { return this._toastVariant; }
    showAToast(msg, variant = 'success') { this._toastMessage = msg; this._toastVariant = variant; this._toastVisible = true; }
    handleToastClose() { this._toastVisible = false; }

    get recommendedTabClass() { return this.jobsTab === 'recommended' ? 'jobs-tab jobs-tab-active' : 'jobs-tab'; }
    get allTabClass()          { return this.jobsTab === 'all' ? 'jobs-tab jobs-tab-active' : 'jobs-tab'; }
    get appliedRailTabClass()  { return this.railTab === 'applied' ? 'rail-tab rail-tab-active' : 'rail-tab'; }
    get savedRailTabClass()    { return this.railTab === 'saved' ? 'rail-tab rail-tab-active' : 'rail-tab'; }

    _catClass(cat) {
        if (cat === 'Super Dream') return 'cat-badge cat-super-dream';
        if (cat === 'Dream') return 'cat-badge cat-dream';
        return 'cat-badge cat-regular';
    }

    _fmt(num) {
        const s = num.toString();
        const last3 = s.slice(-3);
        const rest = s.slice(0, -3);
        if (!rest) return last3;
        return rest.replace(/\B(?=(\d{2})+(?!\d))/g, ',') + ',' + last3;
    }

    _skillsPct(match, total) {
        if (!total) return '0%';
        return Math.round((match / total) * 100) + '%';
    }

    get filteredJobs() {
        const list = this.jobsTab === 'recommended' ? jobs.slice(0, 6) : jobs;
        return list.map(j => ({
            ...j,
            salaryFormatted: j.salary.currency + ' ' + this._fmt(j.salary.min) + ' – ' + j.salary.currency + ' ' + this._fmt(j.salary.max),
            categoryClass: this._catClass(j.category),
            categoryLabel: j.category,
            skillsPct: this._skillsPct(j.skillsMatch, j.skillsTotal),
            logoStyle: 'background:' + j.companyColor,
            tagChips: j.tags.map(t => ({ key: t, label: t })),
            isSaved: this._savedJobs.has(j.id),
            saveBtnClass: this._savedJobs.has(j.id) ? 'bookmark-btn saved' : 'bookmark-btn',
            saveBtnTitle: this._savedJobs.has(j.id) ? 'Remove from saved' : 'Save Job'
        }));
    }

    get totalCount() { return jobs.length; }

    handleJobsTab(event)  { this.jobsTab = event.currentTarget.dataset.tab; }
    handleRailTab(event)  { this.railTab = event.currentTarget.dataset.rtab; }

    handleViewDetail(event) {
        const jobId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'job-detail', jobId } }));
    }

    handleViewAllJobs() {
        this.jobsTab = 'all';
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'landing' } }));
    }

    handleSetupPrefs() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'career-compass' } }));
    }

    handleGoToResumeLibrary() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'resume-library' } }));
    }

    handleGoToPrepHub() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'prep-hub' } }));
    }

    handleGoToCompass() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'career-compass' } }));
    }

    handleToggleSave(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        const next = new Set(this._savedJobs);
        const wasSaved = next.has(id);
        if (wasSaved) next.delete(id); else next.add(id);
        this._savedJobs = next;
        // Persist to Apex if id looks like a real Salesforce id.
        if (typeof id === 'string' && (id.length === 15 || id.length === 18)) {
            toggleSaveJob({ jobId: id })
                .then(serverIsSaved => {
                    this.showAToast(serverIsSaved ? 'Job saved' : 'Removed from saved');
                })
                .catch(err => {
                    // Roll back on failure.
                    const rb = new Set(this._savedJobs);
                    if (wasSaved) rb.add(id); else rb.delete(id);
                    this._savedJobs = rb;
                    const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not save.';
                    this.showAToast(msg, 'error');
                });
        } else {
            // Seed/demo id — local only.
            this.showAToast(wasSaved ? 'Removed from saved' : 'Job saved');
        }
    }

    handleBookCounsellor() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'career-compass' } }));
        this.showAToast('Opening counsellor booking…');
    }

    handleSupport() {
        this.dispatchEvent(new CustomEvent('navigate', { detail: { route: 'service-support' } }));
    }
}