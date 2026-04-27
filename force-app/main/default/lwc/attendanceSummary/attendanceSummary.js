import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import communityBasePath from '@salesforce/community/basePath';

const ATTENDANCE_ROWS = [
    { id: '1', date: '01-03-2025', day: 'Monday', punchIn: '09:00 AM', punchOut: '06:10 PM', lateIn: '0', earlyOut: '10', overtime: '10 Mins', status: 'Present' },
    { id: '2', date: '01-03-2025', day: 'Tuesday', punchIn: 'N/A', punchOut: 'N/A', lateIn: '0', earlyOut: '0', overtime: '0', status: 'Absent' },
    { id: '3', date: '01-03-2025', day: 'Wednesday', punchIn: '09:00 AM', punchOut: '06:10 PM', lateIn: '0', earlyOut: '10', overtime: '10 Mins', status: 'Present' },
    { id: '4', date: '01-03-2025', day: 'Thursday', punchIn: '09:00 AM', punchOut: '06:10 PM', lateIn: '0', earlyOut: '10', overtime: '10 Mins', status: 'Present' },
    { id: '5', date: '01-03-2025', day: 'Friday', punchIn: '09:00 AM', punchOut: '06:10 PM', lateIn: '0', earlyOut: '10', overtime: '10 Mins', status: 'Present' },
    { id: '6', date: '01-03-2025', day: 'Saturday', punchIn: '09:00 AM', punchOut: '06:10 PM', lateIn: '0', earlyOut: '10', overtime: '10 Mins', status: 'Present' },
    { id: '7', date: '01-03-2025', day: 'Sunday', punchIn: '09:00 AM', punchOut: '06:10 PM', lateIn: '0', earlyOut: '10', overtime: '10 Mins', status: 'Present' }
];

const LEAVE_REQUESTS = [
    {
        id: 'lr-1',
        requestNo: '20240101',
        title: 'Request for Sick Leave',
        description:
            'I am writing to inform you that I am unwell and unable to attend my duties. I kindly request sick leave for the required period. I will ensure that any pending responsibilities are managed accordingly and will resume work as soon as I recover.',
        leaveDates: '26 Dec 2026 – 30 Dec 2026 (5 days)',
        submittedText: 'Submitted on',
        submittedDate: '09 Oct 2026',
        status: 'In Review'
    },
    {
        id: 'lr-2',
        requestNo: '20240101',
        title: 'Swap Request',
        description:
            'I have planned a vacation during this period and will be unavailable for classes. Kindly consider this leave request',
        leaveDates: '26 Dec 2026 – 26 Dec 2026 (1 days)',
        submittedText: 'Submitted on',
        submittedDate: '09 Oct 2026',
        status: 'In Review'
    },
    {
        id: 'lr-3',
        requestNo: '20240101',
        title: 'Personal Leave',
        description:
            'I applied for leave due to a family function, but it was submitted late. Requesting reconsideration based on the situation.',
        leaveDates: '26 Dec 2026 – 30 Dec 2026 (5 days)',
        submittedText: 'Rejected on',
        submittedDate: '23-12-23',
        status: 'Rejected'
    }
];

export default class AttendanceSummary extends NavigationMixin(LightningElement) {
    activeTab = 'attendance';
    isHelpModalOpen = false;
    isApplyModalOpen = false;
    requestType = 'leave';

    get isAttendanceTab() {
        return this.activeTab === 'attendance';
    }

    get isLeaveRequestsTab() {
        return this.activeTab === 'leaveRequests';
    }

    get attendanceTabClass() {
        return this.isAttendanceTab ? 'tab-btn tab-active' : 'tab-btn';
    }

    get leaveRequestsTabClass() {
        return this.isLeaveRequestsTab ? 'tab-btn tab-active' : 'tab-btn';
    }

    get isLeaveMode() {
        return this.requestType === 'leave';
    }

    get isSwapMode() {
        return this.requestType === 'swap';
    }

    get attendanceRows() {
        return ATTENDANCE_ROWS.map((item) => ({
            ...item,
            statusClass: item.status === 'Present' ? 'status-pill status-present' : 'status-pill status-absent'
        }));
    }

    get leaveRequests() {
        return LEAVE_REQUESTS.map((item) => ({
            ...item,
            statusClass: item.status === 'Rejected' ? 'request-status request-status-rejected' : 'request-status request-status-review'
        }));
    }

    showAttendanceTab() {
        this.activeTab = 'attendance';
    }

    showLeaveRequestsTab() {
        this.activeTab = 'leaveRequests';
    }

    openApplyModal() {
        this.isApplyModalOpen = true;
    }

    closeApplyModal() {
        this.isApplyModalOpen = false;
    }

    handleRequestTypeChange(event) {
        this.requestType = event.target.value;
    }

    submitApplyModal() {
        this.isApplyModalOpen = false;
    }

    openHelpModal() {
        this.isHelpModalOpen = true;
    }

    closeHelpModal() {
        this.isHelpModalOpen = false;
    }

    navigateToLeaveRequest() {
        const targetUrl = this.buildCommunityUrl('leave-request');
        const pageReference = {
            type: 'standard__webPage',
            attributes: {
                url: targetUrl
            }
        };

        try {
            this[NavigationMixin.Navigate](pageReference);
        } catch (error) {
            window.location.assign(targetUrl);
        }
    }

    buildCommunityUrl(path = '') {
        const basePath = communityBasePath || '/';
        const sanitizedPath = path.replace(/^\/+|\/+$/g, '');

        if (basePath === '/') {
            return sanitizedPath ? `/${sanitizedPath}` : '/';
        }

        return sanitizedPath ? `${basePath}/${sanitizedPath}` : basePath;
    }
}