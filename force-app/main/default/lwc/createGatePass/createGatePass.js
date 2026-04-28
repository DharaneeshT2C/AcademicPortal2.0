import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { pageNameForRoute } from 'c/navHelper';
import createGatePass from '@salesforce/apex/KenGatePassController.createGatePass';

export default class CreateGatePass extends NavigationMixin(LightningElement) {
    @track _form = {
        requestType: 'Student Exit Request',
        destination: '',
        exitDate: '',
        exitTime: '09:00',
        returnDate: '',
        returnTime: '18:00',
        reason: ''
    };
    @track _submitting = false;
    @track _error;
    @track _toastVisible = false;
    @track _toastMessage = '';
    @track _toastVariant = 'success';

    showAToast(msg, v = 'success') { this._toastMessage = msg; this._toastVariant = v; this._toastVisible = true; }
    handleToastClose() { this._toastVisible = false; }
    get showToast() { return this._toastVisible; }
    get toastMessage() { return this._toastMessage; }
    get toastVariant() { return this._toastVariant; }
    get formRequestType() { return this._form.requestType; }
    get formDestination() { return this._form.destination; }
    get formExitDate() { return this._form.exitDate; }
    get formExitTime() { return this._form.exitTime; }
    get formReturnDate() { return this._form.returnDate; }
    get formReturnTime() { return this._form.returnTime; }
    get formReason() { return this._form.reason; }
    get isSubmitDisabled() { return this._submitting; }
    get submitLabel() { return this._submitting ? 'Submitting…' : 'Submit Request'; }
    get hasError() { return !!this._error; }
    get errorMessage() { return this._error; }

    handleFieldChange(event) {
        const f = event.target.dataset.field;
        if (!f) return;
        this._form = Object.assign({}, this._form, { [f]: event.target.value });
    }

    navigateTo(route) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: pageNameForRoute(route) }
        });
    }
    handleBack() { this.navigateTo('gate-pass'); }

    _composeIso(dateStr, timeStr) {
        if (!dateStr) return '';
        const t = timeStr || '09:00';
        // Apex Datetime.valueOf accepts "yyyy-MM-dd HH:mm:ss"
        return `${dateStr} ${t}:00`;
    }

    handleSubmit(event) {
        if (event && event.preventDefault) event.preventDefault();
        if (this._submitting) return;
        const f = this._form;
        if (!f.destination || !f.destination.trim()) { this._error = 'Please enter your destination.'; return; }
        if (!f.exitDate)  { this._error = 'Please pick the exit date.'; return; }
        if (!f.returnDate){ this._error = 'Please pick the return date.'; return; }
        if (!f.reason || !f.reason.trim()) { this._error = 'Please describe the reason.'; return; }
        if (f.returnDate < f.exitDate) { this._error = 'Return date must be on or after the exit date.'; return; }

        this._error = null;
        this._submitting = true;
        const req = {
            reason: f.reason.trim(),
            destination: f.destination.trim(),
            outDateTime: this._composeIso(f.exitDate, f.exitTime),
            returnDateTime: this._composeIso(f.returnDate, f.returnTime),
            requestType: f.requestType
        };
        createGatePass({ req })
            .then(id => {
                this._submitting = false;
                this.showAToast(`Gate pass submitted (id ${id || ''})`);
                // Brief pause so toast is readable, then navigate back
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => this.navigateTo('gate-pass'), 900);
            })
            .catch(err => {
                this._submitting = false;
                const msg = (err && err.body && err.body.message) ? err.body.message
                          : (err && err.message) ? err.message
                          : 'Could not submit your gate pass.';
                this._error = msg;
                this.showAToast(msg, 'error');
            });
    }
}