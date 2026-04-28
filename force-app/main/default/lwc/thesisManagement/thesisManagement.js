import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getThesis from '@salesforce/apex/KenThesisManagementController.getThesis';
import uploadDraft from '@salesforce/apex/KenThesisManagementController.uploadDraft';
import addThesisTask from '@salesforce/apex/KenThesisManagementController.addThesisTask';

// Mock seed used while the Apex backing is not wired up. Flip USE_MOCK to false
// (or pass empty arrays) to verify the "No data available" empty state.
const MOCK_DATA = {
    phases: [
        { id: 1, name: 'Topic Selection',        status: 'In Progress' },
        { id: 2, name: 'Proposal Submission',    status: 'Locked' },
        { id: 3, name: 'Research & Drafting',    status: 'Locked' },
        { id: 4, name: 'Defense Preparation',    status: 'Locked' },
        { id: 5, name: 'Final Submission',       status: 'Locked' }
    ],
    requirements: [
        {
            text: 'Complete 24 credits in core courses',
            detail: '22 of 24 credits earned. Two more to go.',
            completed: false
        },
        {
            text: 'Maintain a CGPA of 7.5 or higher',
            detail: 'Current CGPA: 8.2',
            completed: true
        },
        {
            text: 'Clear all academic backlogs',
            detail: 'No backlogs pending.',
            completed: true
        },
        {
            text: 'Submit research interest form',
            detail: 'Submitted on 12 March 2026.',
            completed: true
        },
        {
            text: 'Attend mandatory research methodology workshop',
            detail: 'Workshop scheduled for 15 May 2026.',
            completed: false
        }
    ],
    preparationTips: [
        {
            title: 'Identify your research area early',
            description: 'Browse faculty profiles and recent publications to find a topic aligned with your interests.'
        },
        {
            title: 'Keep a literature review log',
            description: 'A running summary of papers you read saves significant time when writing the proposal.'
        },
        {
            title: 'Talk to senior students',
            description: 'Seniors who have completed a thesis can share practical advice on managing deliverables and timelines.'
        },
        {
            title: 'Plan a 9–12 month timeline',
            description: 'Map out milestones for proposal, drafts, mid-review and defense to stay on track.'
        }
    ]
};

const USE_MOCK = true;

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
        const apex = this._apex;
        const hasApexContent = apex && (
            (Array.isArray(apex.phases) && apex.phases.length > 0) ||
            (Array.isArray(apex.requirements) && apex.requirements.length > 0) ||
            (Array.isArray(apex.preparationTips) && apex.preparationTips.length > 0)
        );
        if (hasApexContent) return apex;
        return USE_MOCK ? MOCK_DATA : (apex || {});
    }

    get hasContent() {
        const d = this.data;
        return (
            (Array.isArray(d.phases) && d.phases.length > 0) ||
            (Array.isArray(d.requirements) && d.requirements.length > 0) ||
            (Array.isArray(d.preparationTips) && d.preparationTips.length > 0)
        );
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
