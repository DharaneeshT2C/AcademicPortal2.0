import { LightningElement, wire, track } from 'lwc';
import { feedbackData } from 'c/mockData';
import getActiveSurvey from '@salesforce/apex/KenFeedbackController.getActiveSurvey';
import submitFeedback from '@salesforce/apex/KenFeedbackController.submitFeedback';

export default class FeedbackPage extends LightningElement {
    @track _apex;
    @track _toastVisible = false;
    @track _toastMessage = '';
    @track _toastVariant = 'success';
    _seed = feedbackData;

    showAToast(msg, v = 'success') { this._toastMessage = msg; this._toastVariant = v; this._toastVisible = true; }
    handleToastClose() { this._toastVisible = false; }
    get showToast() { return this._toastVisible; }
    get toastMessage() { return this._toastMessage; }
    get toastVariant() { return this._toastVariant; }

    @wire(getActiveSurvey)
    wiredSurvey({ data, error }) {
        if (data) this._apex = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[feedbackPage] Apex failed, using seed:', error);
        }
    }

    get data() {
        if (this._apex) return Object.assign({}, this._seed, this._apex);
        return this._seed;
    }

    get formCards() {
        return (this.data.forms || []).map(f => ({
            ...f,
            statusClass: f.status === 'pending' ? 'form-status pending' : 'form-status completed'
        }));
    }

    handleSubmitFeedback(event) {
        const s = (event && event.detail) || {};
        submitFeedback({ s })
            .then(() => { this.showAToast('Thanks for the feedback'); })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not submit feedback.';
                this.showAToast(msg, 'error');
            });
    }
}