import { LightningElement, wire, track } from 'lwc';
import { examData } from 'c/mockData';
import getMyExams from '@salesforce/apex/KenMyExamsController.getMyExams';
import confirmExamEnrollment from '@salesforce/apex/KenMyExamsController.confirmExamEnrollment';

export default class ExamEnrollment extends LightningElement {
    @track _apex;
    @track _submitting = false;
    @track _confirmation;
    @track _errorMessage;
    _seed = examData;

    @wire(getMyExams)
    wiredMyExams({ data, error }) {
        if (data) this._apex = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[examEnrollment] Apex failed, using seed:', error);
        }
    }

    get data() {
        if (this._apex) return Object.assign({}, this._seed, this._apex);
        return this._seed;
    }

    get selectedCourses() {
        const courses = (this.data && this.data.courses) ? this.data.courses : [];
        return courses.filter(c => c.selected);
    }

    get totalFee() {
        return this.data.totalFee;
    }

    get hasSelection() {
        return this.selectedCourses.length > 0;
    }

    get payButtonLabel() {
        if (this._submitting) return 'Processing…';
        return `Pay INR ${this.totalFee} & Confirm`;
    }

    get isPayDisabled() {
        return this._submitting || !this.hasSelection;
    }

    get showConfirmation() {
        return !!this._confirmation;
    }

    get confirmationCourseList() {
        if (!this._confirmation || !this._confirmation.enrolledCourseCodes) return '';
        return this._confirmation.enrolledCourseCodes.join(', ');
    }

    get hasError() {
        return !!this._errorMessage;
    }

    navigateTo(route) { this.dispatchEvent(new CustomEvent('navigate', { detail: { route } })); }
    handleBack() { this.navigateTo('my-exams'); }

    handlePayAndConfirm() {
        if (this._submitting) return;
        const codes = this.selectedCourses.map(c => c.code).filter(Boolean);
        if (!codes.length) {
            this._errorMessage = 'Select at least one course before paying.';
            return;
        }
        this._submitting = true;
        this._errorMessage = null;
        confirmExamEnrollment({ courseCodes: codes, totalFee: this.totalFee })
            .then(result => {
                this._confirmation = result;
                this._submitting = false;
            })
            .catch(err => {
                // eslint-disable-next-line no-console
                console.error('[examEnrollment] confirmExamEnrollment failed:', err);
                const msg = (err && err.body && err.body.message) ? err.body.message
                          : (err && err.message) ? err.message
                          : 'Could not complete enrollment. Please try again.';
                this._errorMessage = msg;
                this._submitting = false;
            });
    }

    handleDoneClick() {
        this._confirmation = null;
        this.navigateTo('my-exams');
    }
}