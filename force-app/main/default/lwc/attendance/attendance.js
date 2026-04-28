import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getAttendanceBundle from '@salesforce/apex/KenAttendanceController.getAttendanceBundle';
import raiseAttendanceDispute from '@salesforce/apex/KenAttendanceController.raiseAttendanceDispute';
import submitLeaveRequest from '@salesforce/apex/KenAttendanceController.submitLeaveRequest';

const LEAVE_TYPES = ['Personal leave', 'Medical leave', 'Family emergency', 'Exception', 'Other'];

export default class Attendance extends LightningElement {
    @track _apex;
    @track _wireResponse;
    @track _localLeaveRequests;
    @track _showLeaveModal = false;
    @track _submitting = false;
    @track _formError;
    @track _successBanner;
    @track _showOverview = false;
    @track _showAllLeaves = false;
    // Form fields
    @track _form = {
        title: '',
        leaveType: 'Personal leave',
        fromDate: '',
        toDate: '',
        reason: ''
    };
    @wire(getAttendanceBundle)
    wiredAttendance(response) {
        this._wireResponse = response;
        const { data, error } = response;
        if (data) this._apex = data;
        else if (error) {
            const _msg = (error && error.body && error.body.message) || '';
            if (_msg && !_msg.includes('not have access') && !_msg.includes('No rows')) {
                // eslint-disable-next-line no-console
                console.warn('[attendance] Apex failed:', error);
            }
        }
    }

    get data() {
        return this._apex || {};
    }

    get todayItems() {
        return (this.data.today || []).map(item => ({
            ...item,
            statusClass: `status-badge ${item.status.toLowerCase()}`
        }));
    }

    get courseWiseData() {
        return (this.data.courseWise || []).map(item => ({
            ...item,
            barStyle: 'height:' + item.percentage + '%',
            barClass: item.atRisk ? 'bar-fill at-risk' : 'bar-fill',
            key: 'cw-' + item.code
        }));
    }

    get leaveRequests() {
        const full = this._localLeaveRequests
            ? this._localLeaveRequests
            : (this.data.leaveRequests || []);
        const list = this._showAllLeaves ? full : full.slice(0, 3);
        return list.map((item, idx) => {
            const type = item.type || item.leaveType || '';
            const status = item.status || '';
            const cls = `status-badge ${status.toLowerCase().replace(/\s+/g, '-')}`;
            return {
                ...item,
                key: item.id || `lr-${idx}`,
                type,
                status,
                statusClass: cls
            };
        });
    }

    get leaveTypeOptions() {
        return LEAVE_TYPES.map(t => ({ label: t, value: t, selected: t === this._form.leaveType }));
    }

    get isSubmitDisabled() { return this._submitting; }
    get submitLabel() { return this._submitting ? 'Submitting…' : 'Submit Request'; }
    get hasFormError() { return !!this._formError; }
    get hasSuccess() { return !!this._successBanner; }
    get showLeaveModal() { return this._showLeaveModal; }
    get formTitle() { return this._form.title; }
    get formLeaveType() { return this._form.leaveType; }
    get formFromDate() { return this._form.fromDate; }
    get formToDate() { return this._form.toDate; }
    get formReason() { return this._form.reason; }

    handleRaiseDispute(event) {
        const subjectId = event.currentTarget.dataset.id;
        const reason = event.currentTarget.dataset.reason || '';
        raiseAttendanceDispute({ subjectId, reason })
            .then(() => { this._successBanner = 'Attendance dispute submitted.'; })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not submit dispute.';
                this._formError = msg;
            });
    }

    stopPropagation(event) { event.stopPropagation(); }

    get showOverview() { return this._showOverview; }
    get overviewLabel() { return this._showOverview ? 'Hide Overview' : 'Attendance Overview'; }
    get viewAllLabel() { return this._showAllLeaves ? 'Show Less' : 'View All'; }
    get overallPct() {
        const apex = this._apex || {};
        if (apex.overallPercentage != null) return Math.round(apex.overallPercentage);
        const cw = this.data.courseWise || [];
        if (!cw.length) return 0;
        return Math.round(cw.reduce((s, c) => s + (c.percentage || 0), 0) / cw.length);
    }
    get atRiskCount() {
        const apex = this._apex || {};
        if (apex.subjectsAtRisk != null) return apex.subjectsAtRisk;
        return (this.data.courseWise || []).filter(c => c.atRisk).length;
    }
    get subjectCount() {
        return (this.data.courseWise || []).length;
    }
    handleToggleOverview() { this._showOverview = !this._showOverview; }
    handleToggleViewAllLeaves() { this._showAllLeaves = !this._showAllLeaves; }

    handleOpenLeaveModal() {
        this._formError = null;
        this._successBanner = null;
        this._form = { title: '', leaveType: 'Personal leave', fromDate: '', toDate: '', reason: '' };
        this._showLeaveModal = true;
    }

    handleCloseLeaveModal() {
        if (this._submitting) return;
        this._showLeaveModal = false;
    }

    handleFormChange(event) {
        const field = event.target.dataset.field;
        if (!field) return;
        this._form = Object.assign({}, this._form, { [field]: event.target.value });
    }

    handleSubmitLeave() {
        if (this._submitting) return;
        const f = this._form;
        if (!f.title || !f.title.trim()) { this._formError = 'Please enter a title.'; return; }
        if (f.title.trim().length > 120) { this._formError = 'Title must be 120 characters or fewer.'; return; }
        if (!f.fromDate)                  { this._formError = 'From date is required.'; return; }
        if (!f.toDate)                    { this._formError = 'To date is required.'; return; }
        if (f.toDate < f.fromDate)        { this._formError = 'To date must be on or after the from date.'; return; }
        const todayIso = new Date().toISOString().slice(0, 10);
        if (f.fromDate < todayIso)        { this._formError = 'Leave cannot start in the past — contact your teacher for a backdated request.'; return; }
        if ((f.reason || '').length > 1000) { this._formError = 'Reason must be 1000 characters or fewer.'; return; }
        this._formError = null;
        this._submitting = true;
        submitLeaveRequest({
            title: f.title.trim(),
            leaveType: f.leaveType,
            fromDate: f.fromDate,
            toDate: f.toDate,
            reason: (f.reason || '').trim()
        })
            .then(saved => {
                this._submitting = false;
                this._showLeaveModal = false;
                this._successBanner = `Submitted: "${saved.title}" (${saved.dates || ''}). Status: ${saved.status}.`;
                // Optimistically prepend so the new request appears immediately.
                const existing = (this.data.leaveRequests || []).slice();
                existing.unshift(saved);
                this._localLeaveRequests = existing;
                // Refresh the wire so the next paint sees the SOQL truth.
                if (this._wireResponse) refreshApex(this._wireResponse);
                // Auto-dismiss success banner after a few seconds.
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => { this._successBanner = null; }, 6000);
            })
            .catch(err => {
                this._submitting = false;
                const msg = (err && err.body && err.body.message) ? err.body.message
                          : (err && err.message) ? err.message
                          : 'Could not submit your leave request.';
                this._formError = msg;
            });
    }
}