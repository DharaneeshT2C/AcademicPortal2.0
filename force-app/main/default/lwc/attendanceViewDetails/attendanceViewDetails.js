import { LightningElement, wire } from 'lwc';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';

const DAY_ROWS = [
    {
        id: '1',
        date: '27 Mar 2026',
        day: 'Monday',
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        present: '32',
        absent: '8',
        attendancePercent: '73%',
        status: 'Completed',
        statusType: 'completed'
    },
    {
        id: '2',
        date: '28 Mar 2026',
        day: 'Tuesday',
        startTime: '01:00 PM',
        endTime: '02:00 PM',
        present: '34',
        absent: '6',
        attendancePercent: '82%',
        status: 'Completed',
        statusType: 'completed'
    },
    {
        id: '3',
        date: '29 Mar 2026',
        day: 'Wednesday',
        startTime: '03:00 PM',
        endTime: '04:00 PM',
        present: '39',
        absent: '1',
        attendancePercent: '76%',
        status: 'Completed',
        statusType: 'completed'
    },
    {
        id: '4',
        date: '30 Mar 2026',
        day: 'Thursday',
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        present: '40',
        absent: '0',
        attendancePercent: '84%',
        status: 'Completed',
        statusType: 'completed'
    },
    {
        id: '5',
        date: '31 Mar 2026',
        day: 'Friday',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        present: '40',
        absent: '0',
        attendancePercent: '94%',
        status: 'Pending',
        statusType: 'pending'
    }
];

export default class AttendanceViewDetails extends LightningElement {
    activeTab = 'day';
    semesterValue = 'semester1';
    organizationDefaults = {};
    semesterOptions = [
        { label: 'Semester 1', value: 'semester1' },
        { label: 'Semester 2', value: 'semester2' }
    ];

    get selectedSemesterOptions() {
        return this.semesterOptions.map((option) => ({
            ...option,
            selected: option.value === this.semesterValue
        }));
    }

    get rows() {
        if (this.activeTab === 'month') {
            return [
                ...DAY_ROWS,
                {
                    id: '6',
                    date: '01 Apr 2026',
                    day: 'Monday',
                    startTime: '09:00 AM',
                    endTime: '10:00 AM',
                    present: '32',
                    absent: '8',
                    attendancePercent: '94%',
                    status: 'Pending',
                    statusType: 'pending'
                },
                {
                    id: '7',
                    date: '02 Apr 2026',
                    day: 'Tuesday',
                    startTime: '09:00 AM',
                    endTime: '10:00 AM',
                    present: '34',
                    absent: '6',
                    attendancePercent: '94%',
                    status: 'Completed',
                    statusType: 'completed'
                }
            ];
        }

        return DAY_ROWS;
    }

    get tableRows() {
        return this.rows.map((row) => ({
            ...row,
            statusClass:
                row.statusType === 'pending' ? 'status-pill status-pending' : 'status-pill status-completed'
        }));
    }

    get isWeekTab() {
        return this.activeTab === 'week';
    }

    get dayTabClass() {
        return this.activeTab === 'day' ? 'tab active' : 'tab';
    }

    get weekTabClass() {
        return this.activeTab === 'week' ? 'tab active' : 'tab';
    }

    get monthTabClass() {
        return this.activeTab === 'month' ? 'tab active' : 'tab';
    }

    handleTabChange(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    handleSemesterChange(event) {
        this.semesterValue = event.target.value;
    }

    handleViewDetails() {
        this.activeTab = 'day';
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