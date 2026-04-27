import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

const ATTENDANCE_ROWS = [
    { id: '1', serialNo: 1, courseName: 'Applied Physics', courseCode: 'KJ9844762', attendance: '73%', attendanceClass: 'attendance-value attendance-ok', status: 'On Track', statusType: 'ok' },
    { id: '2', serialNo: 2, courseName: 'Basics of Chemistry', courseCode: 'KJ9844763', attendance: '63%', attendanceClass: 'attendance-value attendance-warning', status: 'Needs Attention', statusType: 'attention' },
    { id: '3', serialNo: 3, courseName: 'Mathematics', courseCode: 'KJ9844764', attendance: '49%', attendanceClass: 'attendance-value attendance-warning', status: 'Needs Attention', statusType: 'attention' },
    { id: '4', serialNo: 4, courseName: 'Business English', courseCode: 'KJ9844765', attendance: '73%', attendanceClass: 'attendance-value attendance-ok', status: 'On Track', statusType: 'ok' },
    { id: '5', serialNo: 5, courseName: 'Programming in C', courseCode: 'KJ9844766', attendance: '66%', attendanceClass: 'attendance-value attendance-ok', status: 'On Track', statusType: 'ok' },
    { id: '6', serialNo: 6, courseName: 'Data Structures & Algorithms', courseCode: 'KJ9844767', attendance: '65%', attendanceClass: 'attendance-value attendance-ok', status: 'On Track', statusType: 'ok' },
    { id: '7', serialNo: 7, courseName: 'Database Management Systems (DBMS)', courseCode: 'KJ9844768', attendance: '45%', attendanceClass: 'attendance-value attendance-warning', status: 'On Track', statusType: 'ok' }
];

export default class StudentAttendanceHistory extends NavigationMixin(LightningElement) {
    @api dashboardPageApiName = 'Student_Attendance__c';
    @api detailsPageApiName = 'Attendnace_Details__c';

    semesterValue = 'semester1';
    activeMainTab = 'attendance';
    leaveRequestView = 'list';
    selectedLeaveRequest = null;

    semesterOptions = [
        { label: 'Semester 1', value: 'semester1' },
        { label: 'Semester 2', value: 'semester2' }
    ];

    rows = ATTENDANCE_ROWS;

    get selectedSemesterOptions() {
        return this.semesterOptions.map((option) => ({ ...option, selected: option.value === this.semesterValue }));
    }

    get tableRows() {
        return this.rows.map((row) => ({
            ...row,
            statusClass: row.statusType === 'attention' ? 'status-pill status-attention' : 'status-pill status-on-track'
        }));
    }

    get isAttendanceTab() {
        return this.activeMainTab === 'attendance';
    }

    get attendanceTabClass() {
        return this.activeMainTab === 'attendance' ? 'parent-tab-btn parent-tab-btn-active' : 'parent-tab-btn';
    }

    get leaveRequestTabClass() {
        return this.activeMainTab === 'leaveRequest' ? 'parent-tab-btn parent-tab-btn-active' : 'parent-tab-btn';
    }

    get isLeaveRequestListView() {
        return this.leaveRequestView === 'list';
    }

    handleSemesterChange(event) {
        this.semesterValue = event.target.value;
    }

    handleMainTabChange(event) {
        const tab = event.currentTarget?.dataset?.tab;
        if (!tab || tab === this.activeMainTab) {
            return;
        }
        this.activeMainTab = tab;
        if (tab === 'leaveRequest') {
            this.leaveRequestView = 'list';
            this.selectedLeaveRequest = null;
        }
    }

    handleLeaveRequestSelect(event) {
        this.selectedLeaveRequest = event.detail || null;
        this.leaveRequestView = 'details';
    }

    handleBackToLeaveRequestList() {
        this.leaveRequestView = 'list';
        this.selectedLeaveRequest = null;
    }

    handleBack() {
        if (this.dashboardPageApiName) {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: this.dashboardPageApiName }
            });
            return;
        }
        this.dispatchEvent(new CustomEvent('backtodashboard', {
            bubbles: true,
            composed: true
        }));
    }

    handleViewDetails(event) {
        const row = this.rows.find((item) => item.id === event.currentTarget.dataset.id);

        try {
            window.sessionStorage.setItem('ken_student_attendance_selected_course', JSON.stringify(row || {}));
        } catch (e) {
            console.error('Error saving course:', e);
        }

        if (this.detailsPageApiName) {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: this.detailsPageApiName }
            });
            return;
        }

        this.dispatchEvent(new CustomEvent('viewdetails', {
            bubbles: true,
            composed: true,
            detail: row || {}
        }));
    }
}