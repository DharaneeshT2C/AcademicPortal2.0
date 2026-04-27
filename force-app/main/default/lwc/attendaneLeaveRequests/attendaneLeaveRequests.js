import { LightningElement } from 'lwc';

const REQUESTS = [
    {
        id: 'req-1',
        requestNumber: '20240101',
        type: 'Exception',
        description:
            'Sports Day practice was scheduled during my class time, so I couldn\'t attend the session. Please mark this as an exception.',
        leaveDates: '26 - 30 Dec 2026 (5 days)',
        dateLabel: 'Submitted on',
        dateValue: '09 Oct 2026',
        status: 'In Review',
        statusClass: 'status-pill status-review'
    },
    {
        id: 'req-2',
        requestNumber: '20240101',
        type: 'Personal Leave',
        description:
            'I had to attend a family function out of town and couldn\'t join classes on these dates. Requesting leave approval for the absence.',
        leaveDates: '12, 13 Dec 2026 (2 days)',
        dateLabel: 'Approved on',
        dateValue: '23-12-23',
        status: 'Approved',
        statusClass: 'status-pill status-approved'
    },
    {
        id: 'req-3',
        requestNumber: '20240101',
        type: 'Personal Leave',
        description:
            'I applied for leave due to a family function, but it was submitted late. Requesting reconsideration based on the situation.',
        leaveDates: '26 Dec 2026 – 30 Dec 2026 (5 days)',
        dateLabel: 'Rejected on',
        dateValue: '23-12-23',
        status: 'Rejected',
        statusClass: 'status-pill status-rejected'
    }
];

export default class AttendaneLeaveRequests extends LightningElement {
    semesterValue = 'semester1';
    showHelpModal = false;
    helpDescription = '';
    helpIssueType = 'attendance';
    helpSubject = '';

    semesterOptions = [
        { label: 'Semester 1', value: 'semester1' },
        { label: 'Semester 2', value: 'semester2' }
    ];

    leaveRequests = REQUESTS;
    issueTypeOptions = [
        { label: 'Attendance', value: 'attendance' },
        { label: 'Leave Request', value: 'leave-request' },
        { label: 'Others', value: 'others' }
    ];

    get selectedSemesterOptions() {
        return this.semesterOptions.map((option) => ({
            ...option,
            selected: option.value === this.semesterValue
        }));
    }

    get selectedIssueTypeOptions() {
        return this.issueTypeOptions.map((option) => ({
            ...option,
            selected: option.value === this.helpIssueType
        }));
    }

    handleSemesterChange(event) {
        this.semesterValue = event.target.value;
    }

    openHelpModal() {
        this.showHelpModal = true;
    }

    closeHelpModal() {
        this.showHelpModal = false;
    }

    stopModalClose(event) {
        event.stopPropagation();
    }

    handleDescriptionChange(event) {
        this.helpDescription = event.target.value;
    }

    handleIssueTypeChange(event) {
        this.helpIssueType = event.target.value;
    }

    handleSubjectChange(event) {
        this.helpSubject = event.target.value;
    }

    submitHelpRequest() {
        this.showHelpModal = false;
    }

    handleOpenRequest(event) {
        const requestId = event.currentTarget?.dataset?.id;
        const selectedRequest = this.leaveRequests.find((item) => item.id === requestId);
        if (!selectedRequest) {
            return;
        }

        this.dispatchEvent(
            new CustomEvent('requestselect', {
                detail: selectedRequest,
                bubbles: true,
                composed: true
            })
        );
    }
}