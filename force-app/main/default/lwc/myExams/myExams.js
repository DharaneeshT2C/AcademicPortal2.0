import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { examData } from 'c/mockData';
import getMyExams from '@salesforce/apex/KenMyExamsController.getMyExams';
import enrollInExam from '@salesforce/apex/KenMyExamsController.enrollInExam';

export default class MyExams extends LightningElement {
    @track _apex;
    @track _wireResp;
    @track _toastVisible = false;
    @track _toastMessage = '';
    @track _toastVariant = 'success';

    showAToast(msg, v = 'success') { this._toastMessage = msg; this._toastVariant = v; this._toastVisible = true; }
    handleToastClose() { this._toastVisible = false; }
    get showToast() { return this._toastVisible; }
    get toastMessage() { return this._toastMessage; }
    get toastVariant() { return this._toastVariant; }

    @wire(getMyExams)
    wiredMyExams(response) {
        this._wireResp = response;
        const { data, error } = response;
        if (data) this._apex = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[myExams] Apex failed, using seed:', error);
        }
    }

    get effectiveCourses() {
        if (this._apex && this._apex.courses && this._apex.courses.length) return this._apex.courses;
        return examData.courses;
    }

    get formattedCourses() {
        return this.effectiveCourses.map(c => ({
            ...c,
            typeClass: c.type === 'Backlog' ? 'type-badge backlog' : 'type-badge',
            eligClass: c.eligibility === 'Not Eligible' ? 'elig-badge not-eligible' : 'elig-badge eligible'
        }));
    }

    navigateTo(route) { this.dispatchEvent(new CustomEvent('navigate', { detail: { route } })); }
    handleEnroll(event) {
        const examId = event && event.currentTarget && event.currentTarget.dataset
            ? event.currentTarget.dataset.id : null;
        if (examId) {
            enrollInExam({ examId })
                .then(() => {
                    if (this._wireResp) refreshApex(this._wireResp);
                    this.navigateTo('exam-enrollment');
                })
                .catch(err => {
                    const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not enroll.';
                    this.showAToast(msg, 'error');
                });
        } else {
            this.navigateTo('exam-enrollment');
        }
    }
    handleResults() { this.navigateTo('results'); }
}