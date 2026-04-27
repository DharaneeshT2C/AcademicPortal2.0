import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { resumes } from 'c/placementData';
import getResumes from '@salesforce/apex/KenResumeController.getResumes';
import deleteResume from '@salesforce/apex/KenResumeController.deleteResume';

export default class ResumeLibrary extends LightningElement {
    @track _apexResumes;
    @track _wireResp;
    @track showDeleteModal = false;
    @track deleteId = null;
    @track showSuccessToast = false;
    @track _toastMessage = 'Resume deleted';
    @track _toastVariant = 'success';
    @track searchQuery = '';
    @track menuForResumeId = null;
    @track _deleteError;

    @wire(getResumes)
    wiredResumes(response) {
        this._wireResp = response;
        const { data } = response;
        if (data) {
            // Adapt Apex DTO into the seed-shaped object the template expects.
            this._apexResumes = data.map(r => ({
                id: r.id,
                filename: r.name,
                lastUsed: r.lastUsedDate ? this._formatDate(r.lastUsedDate) : 'Never',
                isDefault: r.isDefault === true
            }));
        }
    }

    _formatDate(d) {
        try { return new Date(d).toLocaleDateString(); } catch (e) { return ''; }
    }

    get resumeList() {
        if (this._apexResumes && this._apexResumes.length) return this._apexResumes;
        return resumes.map(r => ({ ...r }));
    }

    get filteredResumes() {
        return this.resumeList.filter(r =>
            !this.searchQuery || r.filename.toLowerCase().indexOf(this.searchQuery.toLowerCase()) !== -1
        );
    }

    get hasResumes() { return this.filteredResumes.length > 0; }

    get showToast() { return this.showSuccessToast; }
    get toastMessage() { return this._toastMessage; }
    get toastVariant() { return this._toastVariant; }
    handleToastClose() { this.showSuccessToast = false; }
    _toast(msg, v = 'success') { this._toastMessage = msg; this._toastVariant = v; this.showSuccessToast = true; }

    handleBack() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'landing' } }));
    }

    handleCreateResume() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'resume-editor' } }));
    }

    handleDeleteConfirm(event) {
        this.deleteId = event.currentTarget.dataset.id;
        this.showDeleteModal = true;
        this._deleteError = null;
    }

    handleConfirmDelete() {
        const id = this.deleteId;
        // Real Salesforce id: call Apex delete; otherwise just local filter.
        if (typeof id === 'string' && (id.length === 15 || id.length === 18)) {
            deleteResume({ resumeId: id })
                .then(() => {
                    this.showDeleteModal = false;
                    this._toast('Resume deleted', 'success');
                    if (this._wireResp) refreshApex(this._wireResp);
                })
                .catch(err => {
                    const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not delete resume.';
                    this._deleteError = msg;
                    this._toast(msg, 'error');
                });
        } else {
            // Local-only fallback for seed data.
            this._apexResumes = (this._apexResumes || []).filter(r => r.id !== id);
            this.showDeleteModal = false;
            this._toast('Resume removed (local)', 'info');
        }
    }

    handleCancelDelete() { this.showDeleteModal = false; }
    handleSearch(event) { this.searchQuery = event.target.value; }

    handleVoiceSearch() {
        try {
            const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
            if (!SR) { this.searchQuery = ''; return; }
            const r = new SR();
            r.lang = 'en-US';
            r.onresult = (e) => { this.searchQuery = (e.results[0][0].transcript || '').trim(); };
            r.start();
        } catch (e) { /* graceful fallback */ }
    }

    handleResumeOptions(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this.menuForResumeId = (this.menuForResumeId === id) ? null : id;
    }

    stopProp(event) { event.stopPropagation(); }
}