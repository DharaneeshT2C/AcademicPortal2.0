import { LightningElement, wire } from 'lwc';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';
import FilterIcon from '@salesforce/resourceUrl/FilterIcon';
import CancelIcon from '@salesforce/resourceUrl/CancelIcon';
import CalendarIcon from '@salesforce/resourceUrl/calendarIcon';
import AcceptIcon from '@salesforce/resourceUrl/AcceptIcon';

const REQUESTS = [
    {
        id: 'pending-1',
        status: 'pending',
        name: 'Rakesh Nair',
        studentCode: 'URKI7MT026',
        className: 'ECE - II',
        leaveType: 'Medical',
        period: '12 May 2026 - 14 May 2026',
        days: '3',
        appliedOn: '27 Feb 2026',
        reason: 'High fever and advised bed rest by doctor',
        fileName: 'Medical_Certificate.pdf'
    },
    {
        id: 'pending-2',
        status: 'pending',
        name: 'Aditi Sharma',
        studentCode: 'URKI7MT041',
        className: 'ECE - II',
        leaveType: 'Personal',
        period: '18 Mar 2026 - 19 Mar 2026',
        days: '2',
        appliedOn: '10 Mar 2026',
        reason: 'High fever and advised bed rest by doctor',
        fileName: 'Leave_Request_Form.pdf'
    },
    {
        id: 'pending-3',
        status: 'pending',
        name: 'Karthik Reddy',
        studentCode: 'URKI7MT033',
        className: 'ECE - II',
        leaveType: 'Medical',
        period: '05 Apr 2026',
        days: '1',
        appliedOn: '02 Apr 2026',
        reason: 'Undergoing minor surgery and recovery',
        fileName: 'Hospital_Report.pdf'
    },
    {
        id: 'approved-1',
        status: 'approved',
        name: 'Aditi Sharma',
        studentCode: 'URKI7MT041',
        className: 'ECE - II',
        leaveType: 'Personal',
        period: '18 Mar 2026 - 19 Mar 2026',
        days: '2',
        appliedOn: '10 Mar 2026',
        reason: 'High fever and advised bed rest by doctor',
        statusDate: '12 Mar 2026'
    },
    {
        id: 'approved-2',
        status: 'approved',
        name: 'Rakesh Nair',
        studentCode: 'URKI7MT026',
        className: 'ECE - II',
        leaveType: 'Medical',
        period: '12 May 2026 - 14 May 2026',
        days: '3',
        appliedOn: '27 Feb 2026',
        reason: 'High fever and advised bed rest by doctor',
        statusDate: '12 Mar 2026',
        fileName: 'Medical_Certificate.pdf'
    },
    {
        id: 'rejected-1',
        status: 'rejected',
        name: 'Karthik Reddy',
        studentCode: 'URKI7MT033',
        className: 'ECE - II',
        leaveType: 'Medical',
        period: '05 Apr 2026',
        days: '1',
        appliedOn: '02 Apr 2026',
        reason: 'Undergoing minor surgery and recovery',
        statusDate: '03 Apr 2026',
        rejectionReason: 'Insufficient justification provided'
    }
];

export default class AttendanceLeaveRequests extends LightningElement {
    activeTab = 'pending';
    semesterValue = 'semester1';
    organizationDefaults = {};
    requests = REQUESTS.map((item) => ({ ...item }));
    showRejectModal = false;
    selectedRejectRequestId = null;
    rejectionReasonInput = '';

    semesterOptions = [
        { label: 'Semester 1', value: 'semester1' },
        { label: 'Semester 2', value: 'semester2' }
    ];

    get displayRequests() {
        return this.requests.filter((item) => item.status === this.activeTab).map((item) => ({
            ...item,
            isPending: item.status === 'pending',
            isApproved: item.status === 'approved',
            isRejected: item.status === 'rejected'
        }));
    }

    get pendingTabClass() {
        return this.activeTab === 'pending' ? 'tab-btn tab-btn-active' : 'tab-btn';
    }

    get approvedTabClass() {
        return this.activeTab === 'approved' ? 'tab-btn tab-btn-active' : 'tab-btn';
    }

    get rejectedTabClass() {
        return this.activeTab === 'rejected' ? 'tab-btn tab-btn-active' : 'tab-btn';
    }

    get selectedSemesterOptions() {
        return this.semesterOptions.map((option) => ({
            ...option,
            selected: option.value === this.semesterValue
        }));
    }

    get isRejectSubmitDisabled() {
        return !this.rejectionReasonInput.trim();
    }

    get filterIconUrl() {
        return FilterIcon;
    }

    get cancelIconUrl() {
        return CancelIcon;
    }

    get calendarIconUrl() {
        return CalendarIcon;
    }

    get acceptIconUrl() {
        return AcceptIcon;
    }

    handleTabChange(event) {
        this.activeTab = event.currentTarget?.dataset?.tab || this.activeTab;
    }

    handleSemesterChange(event) {
        this.semesterValue = event.target.value;
    }

    handleRejectClick(event) {
        const requestId = event.currentTarget?.dataset?.requestId;
        if (!requestId) {
            return;
        }

        this.selectedRejectRequestId = requestId;
        this.rejectionReasonInput = '';
        this.showRejectModal = true;
    }

    handleRejectReasonChange(event) {
        this.rejectionReasonInput = event.target.value || '';
    }

    handleRejectCancel() {
        this.closeRejectModal();
    }

    handleRejectSubmit() {
        const reason = this.rejectionReasonInput.trim();
        const requestId = this.selectedRejectRequestId;
        if (!reason || !requestId) {
            return;
        }

        const statusDate = this.formatStatusDate(new Date());

        this.requests = this.requests.map((item) => {
            if (item.id !== requestId) {
                return item;
            }

            return {
                ...item,
                status: 'rejected',
                statusDate,
                rejectionReason: reason
            };
        });

        this.closeRejectModal();
    }

    closeRejectModal() {
        this.showRejectModal = false;
        this.selectedRejectRequestId = null;
        this.rejectionReasonInput = '';
    }

    formatStatusDate(dateValue) {
        return new Intl.DateTimeFormat('en-GB', {
            day: '2-digit',
            month: 'short',
            year: 'numeric'
        }).format(dateValue);
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