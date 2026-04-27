import { LightningElement } from 'lwc';
import communityBasePath from '@salesforce/community/basePath';

export default class InvigilationSchedule extends LightningElement {
    showRequestModal = false;
    showAcceptModal = false;
    showRequestSuccessModal = false;
    showAcceptSuccessModal = false;
    substituteReason = '';

    rows = [
        {
            id: 'inv-1',
            date: '23-06-2025',
            time: '11:00 am',
            venue: 'Room no. 312',
            examType: 'End semester examination',
            className: 'ECE-Sem I',
            subject: 'Basics of Mechanical Engineering',
            actionType: 'accept-request',
            status: '--',
            statusType: 'none'
        },
        {
            id: 'inv-2',
            date: '23-06-2025',
            time: '11:00 am',
            venue: 'Rajji hall',
            examType: 'End semester examination',
            className: 'ECE-Sem I',
            subject: 'Basics of Mechanical Engineering',
            actionType: 'accept-request',
            status: '--',
            statusType: 'none'
        },
        {
            id: 'inv-3',
            date: '23-06-2025',
            time: '11:00 am',
            venue: 'Gandhi hall',
            examType: 'End semester examination',
            className: 'ECE-Sem I',
            subject: 'Basics of Mechanical Engineering',
            actionType: 'add-update',
            status: 'Pending',
            statusType: 'pending'
        },
        {
            id: 'inv-4',
            date: '23-06-2025',
            time: '11:00 am',
            venue: 'Room no. 121',
            examType: 'End semester examination',
            className: 'ECE-Sem I',
            subject: 'Basics of Mechanical Engineering',
            actionType: 'view',
            status: 'Closed',
            statusType: 'closed'
        },
        {
            id: 'inv-5',
            date: '23-06-2025',
            time: '11:00 am',
            venue: 'Room no. 121',
            examType: 'End semester examination',
            className: 'ECE-Sem I',
            subject: 'Basics of Mechanical Engineering',
            actionType: 'view',
            status: 'Closed',
            statusType: 'closed'
        },
        {
            id: 'inv-6',
            date: '23-06-2025',
            time: '11:00 am',
            venue: 'Room no. 121',
            examType: 'End semester examination',
            className: 'ECE-Sem I',
            subject: 'Basics of Mechanical Engineering',
            actionType: 'view',
            status: 'Closed',
            statusType: 'closed'
        },
        {
            id: 'inv-7',
            date: '23-06-2025',
            time: '11:00 am',
            venue: 'Room no. 121',
            examType: 'End semester examination',
            className: 'ECE-Sem I',
            subject: 'Basics of Mechanical Engineering',
            actionType: 'view',
            status: 'Closed',
            statusType: 'closed'
        },
        {
            id: 'inv-8',
            date: '23-06-2025',
            time: '11:00 am',
            venue: 'Room no. 121',
            examType: 'End semester examination',
            className: 'ECE-Sem I',
            subject: 'Basics of Mechanical Engineering',
            actionType: 'view',
            status: 'Closed',
            statusType: 'closed'
        },
        {
            id: 'inv-9',
            date: '23-06-2025',
            time: '11:00 am',
            venue: 'Room no. 121',
            examType: 'End semester examination',
            className: 'ECE-Sem I',
            subject: 'Basics of Mechanical Engineering',
            actionType: 'view',
            status: 'Closed',
            statusType: 'closed'
        },
        {
            id: 'inv-10',
            date: '23-06-2025',
            time: '11:00 am',
            venue: 'Room no. 121',
            examType: 'End semester examination',
            className: 'ECE-Sem I',
            subject: 'Basics of Mechanical Engineering',
            actionType: 'view',
            status: 'Closed',
            statusType: 'closed'
        }
    ];

    get tableRows() {
        return this.rows.map((row) => {
            return {
                ...row,
                statusClass: `status-pill status-${row.statusType}`,
                showAcceptRequest: row.actionType === 'accept-request',
                showAddUpdate: row.actionType === 'add-update',
                showView: row.actionType === 'view'
            };
        });
    }

    openRequestModal() {
        this.showAcceptModal = false;
        this.substituteReason = '';
        this.showRequestModal = true;
    }

    openAcceptModal() {
        this.showRequestModal = false;
        this.showAcceptModal = true;
    }

    handleReasonChange(event) {
        this.substituteReason = event.target.value;
    }

    closeAllModals() {
        this.showRequestModal = false;
        this.showAcceptModal = false;
    }

    submitSubstituteRequest() {
        this.closeAllModals();
        this.showRequestSuccessModal = true;
    }

    confirmAccept() {
        this.closeAllModals();
        this.showAcceptSuccessModal = true;
    }

    closeRequestSuccessModal() {
        this.showRequestSuccessModal = false;
    }

    closeAcceptSuccessModal() {
        this.showAcceptSuccessModal = false;
    }

    navigateToInvigilationDetails() {
        window.open(this.buildCommunityUrl('exams/invigilation/invigialtion-details'), '_self');
    }

    buildCommunityUrl(path = '') {
        const basePath = communityBasePath || '/';
        const sanitizedPath = path.replace(/^\/+|\/+$/g, '');

        if (basePath === '/') {
            return sanitizedPath ? `/${sanitizedPath}` : '/';
        }

        return sanitizedPath ? `${basePath}/${sanitizedPath}` : basePath;
    }

    stopModalClose(event) {
        event.stopPropagation();
    }
}