import { LightningElement, track } from 'lwc';
import raiseTicket from '@salesforce/apex/KenServiceSupportController.raiseTicket';

const CATEGORIES = [
    { id: 'Academic',  label: 'Academics',  hint: 'Course registration, grades, transcripts' },
    { id: 'Housing',   label: 'Housing',    hint: 'Hostel, accommodation, mess' },
    { id: 'Finance',   label: 'Finance',    hint: 'Fees, refunds, scholarships' },
    { id: 'IT',        label: 'IT',         hint: 'Wi-Fi, lab access, portal issues' },
    { id: 'Career',    label: 'Career',     hint: 'Internships, placements, mentorship' },
    { id: 'Other',     label: 'Other',      hint: 'Anything else' }
];

export default class ServiceRequest extends LightningElement {
    @track category = '';
    @track title = '';
    @track description = '';
    @track _busy = false;
    @track _toast = null;
    @track _success = null; // case id when successfully raised

    get formattedCategories() {
        return CATEGORIES.map(c => ({
            ...c,
            cardClass: c.id === this.category ? 'cat-card selected' : 'cat-card'
        }));
    }
    get isSubmitDisabled() {
        return this._busy || !this.category || !this.title.trim() || !this.description.trim();
    }
    get submitLabel() { return this._busy ? 'Submitting…' : 'Submit Request'; }
    get hasToast() { return !!this._toast; }
    get toastMessage() { return this._toast && this._toast.message; }
    get toastVariant() { return (this._toast && this._toast.variant) || 'success'; }
    get hasSuccess() { return !!this._success; }
    get successCaseId() { return this._success; }

    handleCategoryClick(event) {
        const id = event.currentTarget.dataset.id;
        if (id) this.category = id;
    }
    handleTitleChange(event)       { this.title = event.target.value; }
    handleDescriptionChange(event) { this.description = event.target.value; }

    handleSubmit() {
        if (this.isSubmitDisabled) return;
        this._busy = true;
        const req = {
            category: this.category,
            title: this.title.trim(),
            description: this.description.trim()
        };
        raiseTicket({ req })
            .then(caseId => {
                this._busy = false;
                this._success = caseId;
                this._toast = { message: 'Request submitted (#' + (caseId || '').slice(-6) + ')', variant: 'success' };
            })
            .catch(err => {
                this._busy = false;
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not submit request.';
                this._toast = { message: msg, variant: 'error' };
            });
    }

    handleAnother() {
        this._success = null;
        this.category = '';
        this.title = '';
        this.description = '';
    }
    handleToastClose() { this._toast = null; }

    navigateTo(route) { this.dispatchEvent(new CustomEvent('navigate', { detail: { route } })); }
    handleBack() { this.navigateTo('service-support'); }
}