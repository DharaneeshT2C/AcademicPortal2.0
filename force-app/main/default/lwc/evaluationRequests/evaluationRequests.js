import { LightningElement, track } from 'lwc';

const ASSIGNED_ROWS = [
    {
        id: 'assigned-1',
        bundleCode: '#DHIU37288',
        courseName: 'Network Analysis & Synthesis',
        courseCode: '#DHIU37288',
        format: 'Theory',
        semester: '1',
        totalPapers: '12',
        dateText: '13-08-2025'
    },
    {
        id: 'assigned-2',
        bundleCode: '#DHWO92748',
        courseName: 'Signals & Systems',
        courseCode: '#DHWO92748',
        format: 'Theory',
        semester: '2',
        totalPapers: '19',
        dateText: '14-08-2025'
    },
    {
        id: 'assigned-3',
        bundleCode: '#JFGH28263',
        courseName: 'VLSI Design',
        courseCode: '#JFGH28263',
        format: 'Practical',
        semester: '1',
        totalPapers: '34',
        dateText: '15-08-2025'
    },
    {
        id: 'assigned-4',
        bundleCode: '#SCHR83928',
        courseName: 'Microwave Engineering',
        courseCode: '#SCHR83928',
        format: 'Theory',
        semester: '1',
        totalPapers: '16',
        dateText: '16-08-2025'
    }
];

const COMPLETED_ROWS = [
    {
        id: 'completed-1',
        bundleCode: '#DHIU37288',
        courseName: 'Network Analysis & Synthesis',
        courseCode: '#DHIU37288',
        format: 'Theory',
        semester: '1',
        totalPapers: '50',
        dateText: '13-08-2025'
    },
    {
        id: 'completed-2',
        bundleCode: '#DHWO92748',
        courseName: 'Signals & Systems',
        courseCode: '#DHWO92748',
        format: 'Theory',
        semester: '2',
        totalPapers: '25',
        dateText: '14-08-2025'
    },
    {
        id: 'completed-3',
        bundleCode: '#JFGH28263',
        courseName: 'VLSI Design',
        courseCode: '#JFGH28263',
        format: 'Practical',
        semester: '1',
        totalPapers: '19',
        dateText: '15-08-2025'
    },
    {
        id: 'completed-4',
        bundleCode: '#SCHR83928',
        courseName: 'Microwave Engineering',
        courseCode: '#SCHR83928',
        format: 'Theory',
        semester: '2',
        totalPapers: '33',
        dateText: '16-08-2025'
    }
];

export default class EvaluationRequests extends LightningElement {
    @track activeTab = 'assigned';

    get isAssignedActive() {
        return this.activeTab === 'assigned';
    }

    get isCompletedActive() {
        return this.activeTab === 'completed';
    }

    get assignedTabClass() {
        return this.isAssignedActive ? 'tab-button tab-button-active' : 'tab-button';
    }

    get completedTabClass() {
        return this.isCompletedActive ? 'tab-button tab-button-active' : 'tab-button';
    }

    get displayRows() {
        return this.isAssignedActive ? ASSIGNED_ROWS : COMPLETED_ROWS;
    }

    get courseHeader() {
        return this.isAssignedActive ? 'Course name' : 'Course';
    }

    get dateHeader() {
        return this.isAssignedActive ? 'Due date' : 'Submitted on';
    }

    get showActionColumn() {
        return this.isAssignedActive;
    }

    showAssigned() {
        this.activeTab = 'assigned';
    }

    showCompleted() {
        this.activeTab = 'completed';
    }

    handleEvaluateClick() {
        window.open('/exams/evaluation-requests/booklets', '_self');
    }
}