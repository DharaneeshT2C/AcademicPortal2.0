import { LightningElement, wire } from 'lwc';
import communityBasePath from '@salesforce/community/basePath';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';

const ATTENDANCE_ROWS = [
    {
        id: '1',
        serialNo: 1,
        courseName: 'Applied Physics',
        courseCode: 'KJ9844762',
        className: 'ECE - I',
        attendance: '73%',
        attendanceClass: 'attendance-value attendance-ok',
        status: 'On Track',
        statusType: 'ok'
    },
    {
        id: '2',
        serialNo: 2,
        courseName: 'Basics of Chemistry',
        courseCode: 'KJ9844763',
        className: 'ECE - III',
        attendance: '82%',
        attendanceClass: 'attendance-value attendance-ok',
        status: 'Needs Attention',
        statusType: 'attention'
    },
    {
        id: '3',
        serialNo: 3,
        courseName: 'Mathematics',
        courseCode: 'KJ9844764',
        className: 'ECE - II',
        attendance: '76%',
        attendanceClass: 'attendance-value attendance-ok',
        status: 'Needs Attention',
        statusType: 'attention'
    },
    {
        id: '4',
        serialNo: 4,
        courseName: 'Business English',
        courseCode: 'KJ9844765',
        className: 'EEE - I',
        attendance: '84%',
        attendanceClass: 'attendance-value attendance-warning',
        status: 'On Track',
        statusType: 'ok'
    },
    {
        id: '5',
        serialNo: 5,
        courseName: 'Programming in C',
        courseCode: 'KJ9844766',
        className: 'EEE - II',
        attendance: '94%',
        attendanceClass: 'attendance-value attendance-ok',
        status: 'On Track',
        statusType: 'ok'
    },
    {
        id: '6',
        serialNo: 6,
        courseName: 'Data Structures & Algorithms',
        courseCode: 'KJ9844767',
        className: 'E&I - II',
        attendance: '98%',
        attendanceClass: 'attendance-value attendance-ok',
        status: 'On Track',
        statusType: 'ok'
    },
    {
        id: '7',
        serialNo: 7,
        courseName: 'Database Management Systems (DBMS)',
        courseCode: 'KJ9844768',
        className: 'E&I - III',
        attendance: '98%',
        attendanceClass: 'attendance-value attendance-ok',
        status: 'On Track',
        statusType: 'ok'
    }
];

export default class AttendanceHistory extends LightningElement {
    semesterValue = 'semester1';
    organizationDefaults = {};

    semesterOptions = [
        { label: 'Semester 1', value: 'semester1' },
        { label: 'Semester 2', value: 'semester2' }
    ];

    rows = ATTENDANCE_ROWS;

    get tableRows() {
        return this.rows.map((row) => ({
            ...row,
            statusClass:
                row.statusType === 'attention' ? 'status-pill status-attention' : 'status-pill status-on-track',
            showAttentionIcon: row.statusType === 'attention'
        }));
    }

    handleSemesterChange(event) {
        this.semesterValue = event.target.value;
    }

    handleViewDetails() {
        window.open(this.buildCommunityUrl('attendance/attendance-history/attendance-view-details'), '_self');
    }

    buildCommunityUrl(path = '') {
        const basePath = communityBasePath || '/';
        const sanitizedPath = path.replace(/^\/+|\/+$/g, '');

        if (basePath === '/') {
            return sanitizedPath ? `/${sanitizedPath}` : '/';
        }

        return sanitizedPath ? `${basePath}/${sanitizedPath}` : basePath;
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