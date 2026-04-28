import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { pageNameForRoute } from 'c/navHelper';
import { refreshApex } from '@salesforce/apex';
import { placementCycle, studentPlacementStatus, jobs, applications, savedJobs, placementSummary, placementInstructions } from 'c/placementData';
import savePreferences from '@salesforce/apex/KenCareerCompassController.savePreferences';
import getPreferences from '@salesforce/apex/KenCareerCompassController.getPreferences';
import withdrawApplication from '@salesforce/apex/KenPlacementsController.withdrawApplication';
import toggleSaveJob from '@salesforce/apex/KenPlacementsController.toggleSaveJob';
import getOfferLetterText from '@salesforce/apex/KenPlacementsController.getOfferLetterText';

export default class PlacementsLanding extends NavigationMixin(LightningElement) {
    // localStorage fallback removed — Salesforce Locker Service disallows it.
    // Career module is hidden in nav; this component only runs if re-enabled later.
    @track currentPhase = studentPlacementStatus.currentPhase;
    @track showRegistrationModal = false;
    @track showWithdrawModal = false;
    @track withdrawJobId = null;
    @track showSuccessModal = false;
    @track successMessage = '';
    @track showRegisteredModal = false;
    @track showOptedOutModal = false;
    @track showPrefsModal = false;
    @track activeTab = 'applications';
    @track jobsTab = 'recommended';
    @track selectedPreferences = [...studentPlacementStatus.preferences];
    @track termsAccepted = false;
    @track participation = '';
    @track optOutReason = '';
    @track preferredRoles = ['Frontend Developer', 'UX/UI Designer'];
    @track selectedIndustries = [...studentPlacementStatus.preferences];
    @track selectedFunctional = ['Engineering', 'Design'];
    @track selectedLocationTypes = ['Remote', 'On-site'];
    @track preferredCities = ['Bangalore', 'Mumbai'];
    @track _toastVisible = false;
    @track _toastMessage = '';
    @track _toastVariant = 'success';
    get showToast() { return this._toastVisible; }
    get toastMessage() { return this._toastMessage; }
    get toastVariant() { return this._toastVariant; }
    handleToastClose() { this._toastVisible = false; }
    _toast(msg, variant = 'success') { this._toastMessage = msg; this._toastVariant = variant; this._toastVisible = true; }
    showToastMsg(msg, variant) { this._toast(msg, variant); }

    cycle = placementCycle;
    summary = placementSummary;
    instructions = placementInstructions;

    /* ── Phase flags ── */
    get isOptedOut()   { return this.currentPhase === -1; }
    get isPhase0()     { return this.currentPhase === 0; }
    get isPhase1()     { return this.currentPhase === 1; }
    get isPhase2()     { return this.currentPhase === 2; }
    get isPhase5()     { return this.currentPhase === 5; }
    get isPhase1Plus() { return this.currentPhase >= 1; }
    get isPhase2Plus() { return this.currentPhase >= 2; }

    /* ── Hero class ── */
    get heroBannerClass() {
        return this.currentPhase === -1 ? 'hero-banner hero-banner-dark' : 'hero-banner';
    }

    /* ── Tabs ── */
    get isApplicationsTab() { return this.activeTab === 'applications'; }
    get isSavedJobsTab()    { return this.activeTab === 'saved-jobs'; }
    get applicationCount()  { return applications.length; }
    get savedCount()        { return savedJobs.length; }
    get applicationsTabClass() { return this.activeTab === 'applications' ? 'tab-btn tab-active' : 'tab-btn'; }
    get savedTabClass()     { return this.activeTab === 'saved-jobs'  ? 'tab-btn tab-active' : 'tab-btn'; }
    get recommendedSubTabClass() { return this.jobsTab === 'recommended' ? 'subtab-btn subtab-active' : 'subtab-btn'; }
    get allSubTabClass()    { return this.jobsTab === 'all' ? 'subtab-btn subtab-active' : 'subtab-btn'; }

    /* ── Registration modal ── */
    get isParticipationYes() { return this.participation === 'yes'; }
    get isParticipationNo()  { return this.participation === 'no'; }
    get cannotSubmitReg() {
        if (!this.participation) return true;
        if (!this.termsAccepted) return true;
        if (this.participation === 'no' && !this.optOutReason) return true;
        return false;
    }

    /* ── Job data ── */
    get recommendedJobs() {
        return jobs.slice(0, 3).map(j => ({
            ...j,
            salaryFormatted: j.salary.currency + ' ' + this._fmt(j.salary.min) + ' – ' + j.salary.currency + ' ' + this._fmt(j.salary.max),
            categoryClass: this._catClass(j.category),
            skillsText: j.skillsMatch + '/' + j.skillsTotal + ' Skills Match',
            logoStyle: 'background:' + j.companyColor
        }));
    }

    get myApplications() {
        return applications.map(app => ({
            ...app,
            statusBadgeClass: 'status-badge status-' + app.status,
            logoStyle: 'background:' + app.companyColor,
            hasOffer: app.status === 'offerReceived',
            stagesDots: app.stages.map(s => ({ ...s, dotClass: 'stage-dot stage-' + s.status }))
        }));
    }

    get mySavedJobs() {
        return jobs.filter(j => savedJobs.includes(j.id)).map(j => ({
            ...j,
            salaryFormatted: j.salary.currency + ' ' + this._fmt(j.salary.min) + ' – ' + j.salary.currency + ' ' + this._fmt(j.salary.max),
            categoryClass: this._catClass(j.category),
            skillsText: j.skillsMatch + '/' + j.skillsTotal + ' Skills Match',
            logoStyle: 'background:' + j.companyColor
        }));
    }

    /* ── Instructions ── */
    get beforeOptInList()   { return this.instructions.beforeOptIn.map((t, i) => ({ key: 'b' + i, text: t })); }
    get policiesToNoteList(){ return this.instructions.policiesToNote.map((p, i) => ({ key: 'p' + i, title: p.title, text: p.text })); }
    get nextStepsList()     { return this.instructions.nextSteps.map((t, i) => ({ key: 'n' + i, text: t })); }

    /* ── Preferences modal ── */
    get industryPrefsList() {
        const opts = ['Information Technology', 'Manufacturing & Engineering', 'Consumer Goods', 'EdTech', 'Healthcare', 'Finance', 'Retail', 'Logistics'];
        return opts.map(p => ({
            label: p, key: p,
            cls: this.selectedIndustries.includes(p) ? 'pref-option pref-selected' : 'pref-option'
        }));
    }
    get functionalAreaList() {
        const opts = ['Engineering', 'Design', 'Marketing', 'Sales', 'Finance', 'Operations', 'Product Management'];
        return opts.map(p => ({
            label: p, key: p,
            cls: this.selectedFunctional.includes(p) ? 'pref-option pref-selected' : 'pref-option'
        }));
    }
    get isRemoteChecked()  { return this.selectedLocationTypes.includes('Remote'); }
    get isOnsiteChecked()  { return this.selectedLocationTypes.includes('On-site'); }
    get isHybridChecked()  { return this.selectedLocationTypes.includes('Hybrid'); }

    /* ── Helpers ── */
    _catClass(cat) {
        if (cat === 'Super Dream') return 'cat-badge cat-super-dream';
        if (cat === 'Dream')       return 'cat-badge cat-dream';
        return 'cat-badge cat-regular';
    }
    _fmt(num) {
        const s = num.toString();
        if (s.length <= 3) return s;
        const last3 = s.slice(-3);
        const rest  = s.slice(0, -3);
        return rest.replace(/\B(?=(\d{2})+(?!\d))/g, ',') + ',' + last3;
    }
    stopProp(event) { event.stopPropagation(); }

    /* ── Registration flow ── */
    handleOptIn() {
        this.showRegistrationModal = true;
        this.participation  = '';
        this.termsAccepted  = false;
        this.optOutReason   = '';
    }
    handleCloseModal() { this.showRegistrationModal = false; }
    handleParticipationChange(event) {
        this.participation = event.target.value;
        this.termsAccepted = false;
    }
    handleTermsChange(event) { this.termsAccepted = event.target.checked; }
    handleOptOutReasonChange(event) { this.optOutReason = event.target.value; }

    handleSubmitRegistration() {
        const optedIn = this.participation === 'yes';
        // Persist the opt-in choice as a Career_Preference__c row.
        savePreferences({
            careerPath: 'placements',
            roles: this.preferredRoles || [],
            cities: this.preferredCities || [],
            salaryFloor: 0,
            workMode: 'Hybrid',
            optedIn
        })
            .then(() => {
                this.showRegistrationModal = false;
                if (optedIn) { this.currentPhase = 1; this.showRegisteredModal = true; }
                else        { this.currentPhase = -1; this.showOptedOutModal = true; }
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not save your registration.';
                this._toast(msg, 'error');
            });
    }

    /* ── Registered success ── */
    handleCloseRegistered() { this.showRegisteredModal = false; }
    handleSetupPrefsFromSuccess() {
        this.showRegisteredModal = false;
        this.showPrefsModal = true;
    }

    /* ── Opted-out success ── */
    handleCloseOptedOut() { this.showOptedOutModal = false; }

    /* ── Preferences modal ── */
    handleSetupPrefs() { this.showPrefsModal = true; }
    handleClosePrefs() { this.showPrefsModal = false; }
    handleSavePrefs() {
        const allRoles = [...(this.preferredRoles || []), ...(this.selectedFunctional || [])];
        savePreferences({
            careerPath: 'placements',
            roles: allRoles,
            cities: this.preferredCities || [],
            salaryFloor: 0,
            workMode: (this.selectedLocationTypes || []).includes('Remote') ? 'Remote'
                    : (this.selectedLocationTypes || []).includes('On-site') ? 'Onsite'
                    : 'Hybrid',
            optedIn: this.currentPhase >= 1
        })
            .then(() => {
                this.selectedPreferences = [...this.selectedIndustries];
                this.showPrefsModal = false;
                this._toast('Preferences saved', 'success');
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not save preferences.';
                this._toast(msg, 'error');
            });
    }

    handleTogglePref(event) {
        const pref = event.currentTarget.dataset.pref;
        const type = event.currentTarget.dataset.type;
        if (type === 'industry') {
            if (this.selectedIndustries.includes(pref)) {
                this.selectedIndustries = this.selectedIndustries.filter(p => p !== pref);
            } else {
                this.selectedIndustries = [...this.selectedIndustries, pref];
            }
        } else if (type === 'functional') {
            if (this.selectedFunctional.includes(pref)) {
                this.selectedFunctional = this.selectedFunctional.filter(p => p !== pref);
            } else {
                this.selectedFunctional = [...this.selectedFunctional, pref];
            }
        }
    }

    handleLocationTypeChange(event) {
        const val = event.target.dataset.val;
        if (event.target.checked) {
            this.selectedLocationTypes = [...this.selectedLocationTypes, val];
        } else {
            this.selectedLocationTypes = this.selectedLocationTypes.filter(t => t !== val);
        }
    }

    handleRemovePreference(event) {
        const val  = event.currentTarget.dataset.val;
        const type = event.currentTarget.dataset.type;
        if (type === 'role') {
            this.preferredRoles = this.preferredRoles.filter(r => r !== val);
        } else if (type === 'city') {
            this.preferredCities = this.preferredCities.filter(c => c !== val);
        }
    }

    handleAddRole()  { this.preferredRoles  = [...this.preferredRoles,  'New Role']; }
    handleAddCity()  { this.preferredCities = [...this.preferredCities, 'New City']; }

    /* ── Withdraw ── */
    handleWithdraw(event) {
        this.withdrawJobId  = event.currentTarget.dataset.id;
        this.showWithdrawModal = true;
    }
    handleConfirmWithdraw() {
        const id = this.withdrawJobId;
        if (!id) {
            this.showWithdrawModal = false;
            return;
        }
        // The data-id at line 266 is a job id from seed UI; treat ids that look
        // like Salesforce ids as application ids and call Apex withdraw.
        if (typeof id === 'string' && (id.length === 15 || id.length === 18)) {
            withdrawApplication({ applicationId: id })
                .then(() => {
                    this.showWithdrawModal = false;
                    this.showSuccessModal  = true;
                    this.successMessage    = 'Your application has been withdrawn.';
                })
                .catch(err => {
                    const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not withdraw application.';
                    this._toast(msg, 'error');
                });
        } else {
            // Seed-data withdraw: no Apex (no real record exists).
            this.showWithdrawModal = false;
            this.showSuccessModal  = true;
            this.successMessage    = 'Withdrawal recorded locally (demo data).';
        }
    }
    handleCancelWithdraw() { this.showWithdrawModal = false; }

    /* ── Generic success ── */
    handleCloseSuccess() { this.showSuccessModal = false; }

    /* ── Tab switches ── */
    handleTabSwitch(event)     { this.activeTab = event.currentTarget.dataset.tab; }
    handleJobsTabSwitch(event) { this.jobsTab   = event.currentTarget.dataset.tab; }

    /* ── Navigation ── */
    handleViewAllJobs() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'all-jobs' } }));
    }
    handleViewJobDetail(event) {
        const jobId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'job-detail', jobId } }));
    }
    handleGoToApplications() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'applications' } }));
    }
    handleGoToResumeLibrary() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'resume-library' } }));
    }
    handleGoToPrepHub() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'prep-hub' } }));
    }
    handleGoToCareerCompass() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'career-compass' } }));
    }
    handleCounsellor() {
        // Counsellor chat opens the campus Chat (KAI) so the student can request a slot.
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: pageNameForRoute('chat') }
        });
    }
    @track _bookmarkedRecs = new Set();
    handleToggleRecBookmark(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        // Optimistic toggle for snappy UI; server-side persists if id is real.
        const next = new Set(this._bookmarkedRecs);
        const wasSaved = next.has(id);
        if (wasSaved) next.delete(id); else next.add(id);
        this._bookmarkedRecs = next;
        // Only call Apex if the id looks like a Salesforce id (real Job_Posting__c).
        if (typeof id === 'string' && (id.length === 15 || id.length === 18)) {
            toggleSaveJob({ jobId: id })
                .catch(err => {
                    // Roll back optimistic toggle on error.
                    const rb = new Set(this._bookmarkedRecs);
                    if (wasSaved) rb.add(id); else rb.delete(id);
                    this._bookmarkedRecs = rb;
                    const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not save bookmark.';
                    this._toast(msg, 'error');
                });
        }
    }
    isRecBookmarked(id) { return this._bookmarkedRecs.has(id); }
    handleCompareOffers() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'compare-offers' } }));
    }
    handleRaiseQuery() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: pageNameForRoute('service-support') }
        });
    }
    handleDownloadOffer(event) {
        const id = event && event.currentTarget && event.currentTarget.dataset
            ? event.currentTarget.dataset.id : null;
        // If we have a real Salesforce application id, fetch the rendered text.
        if (typeof id === 'string' && (id.length === 15 || id.length === 18)) {
            getOfferLetterText({ applicationId: id })
                .then(text => {
                    if (!text) { this._toast('No offer letter available yet.', 'info'); return; }
                    try {
                        const blob = new Blob([text], { type: 'text/plain;charset=utf-8' });
                        const url = URL.createObjectURL(blob);
                        const a = document.createElement('a');
                        a.href = url; a.download = 'offer-letter.txt';
                        document.body.appendChild(a); a.click(); document.body.removeChild(a);
                        setTimeout(() => URL.revokeObjectURL(url), 1500);
                        this._toast('Offer letter downloaded', 'success');
                    } catch (e) { this._toast('Download failed in this browser.', 'error'); }
                })
                .catch(err => {
                    const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not load offer letter.';
                    this._toast(msg, 'error');
                });
        } else {
            // Seed/demo data — generate a placeholder client-side.
            try {
                const blob = new Blob(['Offer letter (demo data — no real application).'], { type: 'text/plain;charset=utf-8' });
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url; a.download = 'offer-letter-demo.txt';
                document.body.appendChild(a); a.click(); document.body.removeChild(a);
                setTimeout(() => URL.revokeObjectURL(url), 1500);
                this._toast('Demo offer letter downloaded', 'info');
            } catch (e) { this._toast('Download failed.', 'error'); }
        }
    }

}