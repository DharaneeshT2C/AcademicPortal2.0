import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getHostelDetails from '@salesforce/apex/KenHostelDetailsController.getHostelDetails';
import submitAllocationRequest from '@salesforce/apex/KenHostelDetailsController.submitAllocationRequest';

export default class HostelDetails extends LightningElement {
    @track _apex;

    @track _wireResp;
    @wire(getHostelDetails)
    wiredHostel(response) {
        this._wireResp = response;
        const { data, error } = response;
        if (data) this._apex = data;
        else if (error) {
            const _msg = (error && error.body && error.body.message) || '';
            if (_msg && !_msg.includes('not have access') && !_msg.includes('No rows')) {
                // eslint-disable-next-line no-console
                console.warn('[hostelDetails] Apex failed, using seed:', error);
            }
        }
    }

    get data() {
        return this._apex || {};
    }

    get formattedLeaveRequests() {
        return (this.data.leaveRequests || []).map(lr => ({
            ...lr,
            lrStatusClass: lr.status === 'In Review' ? 'status-badge review' : 'status-badge closed'
        }));
    }

    @track _showAllocModal = false;
    @track _allocForm = { roomType: 'Double sharing', preference: '' };
    @track _toastVisible = false;
    @track _toastMessage = '';
    @track _toastVariant = 'success';
    showAToast(msg, v = 'success') { this._toastMessage = msg; this._toastVariant = v; this._toastVisible = true; }
    handleToastClose() { this._toastVisible = false; }
    get showToast() { return this._toastVisible; }
    get toastMessage() { return this._toastMessage; }
    get toastVariant() { return this._toastVariant; }
    get showAllocModal() { return this._showAllocModal; }
    get allocFormRoomType() { return this._allocForm.roomType; }
    get allocFormPreference() { return this._allocForm.preference; }
    stopProp(event) { event.stopPropagation(); }
    handleGetStarted() { this._showAllocModal = true; }
    handleCloseAlloc() { this._showAllocModal = false; }
    handleAllocChange(event) {
        const f = event.target.dataset.field;
        if (!f) return;
        this._allocForm = Object.assign({}, this._allocForm, { [f]: event.target.value });
    }
    handleSubmitAlloc() {
        const f = this._allocForm;
        if (!f.roomType) { this.showAToast('Please pick a room type', 'error'); return; }
        if ((f.preference || '').length > 1000) {
            this.showAToast('Notes must be 1000 characters or fewer.', 'error'); return;
        }
        submitAllocationRequest({ roomType: f.roomType, preference: (f.preference || '').trim() })
            .then(id => {
                this._showAllocModal = false;
                this.showAToast(`Submitted preference (${f.roomType}). Reference: ${id}`);
                if (this._wireResp) refreshApex(this._wireResp);
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not submit your request.';
                this.showAToast(msg, 'error');
            });
    }

    navigateTo(route) { this.dispatchEvent(new CustomEvent('navigate', { detail: { route } })); }
    handleBack() { this.navigateTo('campus-life'); }
}