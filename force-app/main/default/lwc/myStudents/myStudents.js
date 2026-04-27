import { LightningElement, wire } from 'lwc';
import communityBasePath from '@salesforce/community/basePath';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';

const STUDENTS = [
    {
        id: '1',
        rollNo: 'URKI7MT023',
        name: 'Daniel Anderson',
        attendance: '73',
        attendanceClass: 'attendance-value good',
        po: '97',
        poClass: 'score-pill good-pill',
        co: '97',
        coClass: 'score-pill good-pill',
        status: 'On Track',
        statusClass: 'status-pill on-track',
        showAlert: false
    },
    {
        id: '2',
        rollNo: 'URKI7MT024',
        name: 'Jessica Taylor',
        attendance: '63',
        attendanceClass: 'attendance-value risk',
        po: '--',
        poClass: 'score-pill na-pill',
        co: '12',
        coClass: 'score-pill danger-pill',
        status: 'Needs Attention',
        statusClass: 'status-pill needs-attention',
        showAlert: true
    },
    {
        id: '3',
        rollNo: 'URKI7MT025',
        name: 'David Wilson',
        attendance: '49',
        attendanceClass: 'attendance-value risk',
        po: '59',
        poClass: 'score-pill warn-pill',
        co: '59',
        coClass: 'score-pill warn-pill',
        status: 'On Track',
        statusClass: 'status-pill on-track',
        showAlert: false
    },
    {
        id: '4',
        rollNo: 'URKI7MT026',
        name: 'Sarah Davis',
        attendance: '75',
        attendanceClass: 'attendance-value good',
        po: '12',
        poClass: 'score-pill danger-pill',
        co: '91',
        coClass: 'score-pill good-pill',
        status: 'Needs Attention',
        statusClass: 'status-pill needs-attention',
        showAlert: true
    },
    {
        id: '5',
        rollNo: 'URKI7MT027',
        name: 'Michael Brown',
        attendance: '65',
        attendanceClass: 'attendance-value good',
        po: '91',
        poClass: 'score-pill good-pill',
        co: '--',
        coClass: 'score-pill na-pill',
        status: 'Needs Attention',
        statusClass: 'status-pill needs-attention',
        showAlert: true
    },
    {
        id: '6',
        rollNo: 'URKI7MT028',
        name: 'Emily Smith',
        attendance: '65',
        attendanceClass: 'attendance-value good',
        po: '83',
        poClass: 'score-pill good-pill',
        co: '71',
        coClass: 'score-pill warn-pill',
        status: 'On Track',
        statusClass: 'status-pill on-track',
        showAlert: false
    },
    {
        id: '7',
        rollNo: 'URKI7MT029',
        name: 'Alex Johnson',
        attendance: '65',
        attendanceClass: 'attendance-value good',
        po: '71',
        poClass: 'score-pill warn-pill',
        co: '83',
        coClass: 'score-pill good-pill',
        status: 'On Track',
        statusClass: 'status-pill on-track',
        showAlert: false
    }
];

export default class MyStudents extends LightningElement {
    organizationDefaults = {};

    get students() {
        return STUDENTS;
    }

    handleViewDetails() {
        window.open(this.buildCommunityUrl('my-students-details'), '_self');
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