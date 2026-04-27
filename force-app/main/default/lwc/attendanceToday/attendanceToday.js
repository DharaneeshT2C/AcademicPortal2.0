import { LightningElement, track, wire } from 'lwc';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';

const STUDENTS = [
    { id: '1', rollNumber: 'URK17MT023', studentName: 'Absalom J' },
    { id: '2', rollNumber: 'URK17MT024', studentName: 'Ankit Kumar' },
    { id: '3', rollNumber: 'URK17MT025', studentName: 'Aron James' },
    { id: '4', rollNumber: 'URK17MT026', studentName: 'Bhavadharni K' },
    { id: '5', rollNumber: 'URK17MT027', studentName: 'Basil Antony' },
    { id: '6', rollNumber: 'URK17MT028', studentName: 'Cyril Lyle' },
    { id: '7', rollNumber: 'URK17MT029', studentName: 'Daniel Jeremy' }
];
const SUCCESS_MODAL_AUTO_CLOSE_MS = 2500;

export default class AttendanceToday extends LightningElement {
    @track rows = STUDENTS.map((row) => ({
        ...row,
        present: false,
        absent: false,
        doNotConsider: false,
        reason: '',
        reasonError: false
    }));

    reasonOptions = [
        { label: 'Select', value: '' },
        { label: 'Personal Leave', value: 'personal-leave' },
        { label: 'On-Duty', value: 'on-duty' }
    ];
    showSubmitConfirmModal = false;
    showSubmitSuccessModal = false;
    successModalTimeoutId;
    organizationDefaults = {};

    get tableRows() {
        return this.rows.map((row) => ({
            ...row,
            reasonSelectClass: row.reasonError ? 'reason-select reason-select-error' : 'reason-select'
        }));
    }

    get presentCount() {
        return this.rows.filter((row) => row.present).length;
    }

    get totalCount() {
        return this.rows.length;
    }

    get isSelectAllChecked() {
        return this.rows.length > 0 && this.rows.every((row) => row.present);
    }

    handleSelectAllChange(event) {
        const isChecked = event.target.checked;
        this.rows = this.rows.map((row) => ({
            ...row,
            present: isChecked,
            absent: false,
            doNotConsider: false,
            reason: '',
            reasonError: false
        }));
    }

    handleStatusChange(event) {
        const rowId = event.currentTarget.dataset.id;
        const statusType = event.currentTarget.dataset.status;
        const isChecked = event.target.checked;

        this.rows = this.rows.map((row) => {
            if (row.id !== rowId) {
                return row;
            }

            if (statusType === 'present') {
                if (isChecked) {
                    return { ...row, present: true, absent: false, doNotConsider: false, reason: '', reasonError: false };
                }
                return { ...row, present: false, absent: false, doNotConsider: false, reason: '', reasonError: false };
            }
            if (statusType === 'absent') {
                if (isChecked) {
                    return { ...row, present: false, absent: true, doNotConsider: false, reasonError: false };
                }
                return { ...row, present: false, absent: false, doNotConsider: false, reason: '', reasonError: false };
            }

            if (isChecked) {
                return { ...row, present: false, absent: false, doNotConsider: true, reason: '', reasonError: false };
            }
            return { ...row, present: false, absent: false, doNotConsider: false, reason: '', reasonError: false };
        });
    }

    handleReasonChange(event) {
        const rowId = event.currentTarget.dataset.id;
        const selectedReason = event.target.value;

        this.rows = this.rows.map((row) => {
            if (row.id !== rowId) {
                return row;
            }

            return {
                ...row,
                reason: selectedReason,
                reasonError: row.absent ? !selectedReason : false
            };
        });
    }

    handleSubmit() {
        let hasReasonError = false;

        this.rows = this.rows.map((row) => {
            if (!row.absent) {
                return { ...row, reasonError: false };
            }

            const missingReason = !row.reason;
            if (missingReason) {
                hasReasonError = true;
            }

            return {
                ...row,
                reasonError: missingReason
            };
        });

        if (hasReasonError) {
            return;
        }

        this.showSubmitConfirmModal = true;
    }

    closeSubmitConfirmModal() {
        this.showSubmitConfirmModal = false;
    }

    confirmSubmitAttendance() {
        this.showSubmitConfirmModal = false;
        this.showSubmitSuccessModal = true;

        if (this.successModalTimeoutId) {
            clearTimeout(this.successModalTimeoutId);
        }

        this.successModalTimeoutId = setTimeout(() => {
            this.showSubmitSuccessModal = false;
            this.successModalTimeoutId = undefined;
        }, SUCCESS_MODAL_AUTO_CLOSE_MS);
    }

    closeSubmitSuccessModal() {
        this.showSubmitSuccessModal = false;
        if (this.successModalTimeoutId) {
            clearTimeout(this.successModalTimeoutId);
            this.successModalTimeoutId = undefined;
        }
    }

    stopModalClose(event) {
        event.stopPropagation();
    }

    disconnectedCallback() {
        if (this.successModalTimeoutId) {
            clearTimeout(this.successModalTimeoutId);
            this.successModalTimeoutId = undefined;
        }
    }

    applyOrganizationTheme() {
        if (!this.template?.host) {
            return;
        }
        const primary = this.organizationDefaults?.primary;
        const secondary = this.organizationDefaults?.secondary;

        if (primary && typeof primary === 'string') {
            this.template.host.style.setProperty('--primary-color', primary);
        }
        if (secondary && typeof secondary === 'string') {
            this.template.host.style.setProperty('--secondary-color', secondary);
        }
    }

    @wire(OrganizationDefaultsApiController)
    wiredOrganizationDefaults({ data }) {
        if (data) {
            this.organizationDefaults = data;
            this.applyOrganizationTheme();
        }
    }
}