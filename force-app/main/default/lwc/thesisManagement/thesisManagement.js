import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getThesis from '@salesforce/apex/KenThesisManagementController.getThesis';
import uploadDraft from '@salesforce/apex/KenThesisManagementController.uploadDraft';
import addThesisTask from '@salesforce/apex/KenThesisManagementController.addThesisTask';

export default class ThesisManagement extends LightningElement {
    @track _apex;

    @track _wireResp;
    @wire(getThesis)
    wiredThesis(response) {
        this._wireResp = response;
        const { data, error } = response;
        if (data) this._apex = data;
        else if (error) {
            const _msg = (error && error.body && error.body.message) || '';
            if (_msg && !_msg.includes('not have access') && !_msg.includes('No rows')) {
                // eslint-disable-next-line no-console
                console.warn('[thesisManagement] Apex failed, using seed:', error);
            }
        }
    }

    get data() {
        return this._apex || {};
    }

    get phases() {
        return (this.data.phases || []).map((p, i) => ({
            ...p,
            key: `ph-${i}`,
            phaseClass: `phase-item ${(p.status || '').toLowerCase().replace(' ', '-')}`,
            statusClass: `phase-status ${(p.status || '').toLowerCase().replace(' ', '-')}`
        }));
    }

    get requirements() {
        return (this.data.requirements || []).map((r, i) => ({
            ...r,
            key: `req-${i}`,
            reqIcon: r.completed ? 'check_circle' : 'radio_button_unchecked'
        }));
    }

    get tips() {
        return (this.data.preparationTips || []).map((t, i) => ({ ...t, key: `tip-${i}` }));
    }

    handleUploadDraft(event) {
        const detail = (event && event.detail) || {};
        const fileName = detail.fileName || '';
        const base64 = detail.base64 || '';
        uploadDraft({ fileName, base64 })
            .then(() => {
                this.showAToast('Draft uploaded');
                if (this._wireResp) refreshApex(this._wireResp);
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not upload draft.';
                this.showAToast(msg, 'error');
            });
    }

    @track _showAddTaskModal = false;
    @track _newTaskTitle = '';
    @track _tasks = [];
    @track _toastVisible = false;
    @track _toastMessage = '';
    @track _toastVariant = 'success';
    showAToast(msg, v = 'success') { this._toastMessage = msg; this._toastVariant = v; this._toastVisible = true; }
    handleToastClose() { this._toastVisible = false; }
    get showToast() { return this._toastVisible; }
    get toastMessage() { return this._toastMessage; }
    get toastVariant() { return this._toastVariant; }
    get showAddTaskModal() { return this._showAddTaskModal; }
    get newTaskTitle() { return this._newTaskTitle; }
    get extraTasks() { return this._tasks; }
    get hasExtraTasks() { return this._tasks.length > 0; }
    stopProp(event) { event.stopPropagation(); }
    handleOpenAddTask() { this._newTaskTitle = ''; this._showAddTaskModal = true; }
    handleCloseAddTask() { this._showAddTaskModal = false; }
    handleTaskInput(event) { this._newTaskTitle = event.target.value || ''; }
    handleSubmitAddTask() {
        const t = this._newTaskTitle.trim();
        if (!t) { this.showAToast('Please enter a task', 'error'); return; }
        if (t.length > 200) { this.showAToast('Task title must be 200 characters or fewer.', 'error'); return; }
        addThesisTask({ title: t, dueDate: null })
            .then(id => {
                this._tasks = [...this._tasks, { id: id || ('T' + Date.now()), title: t, status: 'Pending' }];
                this._showAddTaskModal = false;
                this.showAToast('Task added');
                if (this._wireResp) refreshApex(this._wireResp);
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not add the task.';
                this.showAToast(msg, 'error');
            });
    }
}