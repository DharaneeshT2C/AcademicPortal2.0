import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

const SEMESTER_DETAIL_PAGE = 'Semester_Details__c';
const SEMESTER_DETAIL_ROUTE = 'course-enrolment/semester-details';

export default class CourseEnrolment extends NavigationMixin(LightningElement) {
    banner = {
        title: 'Choose Program Pathways',
        description: 'Please select your minor programs to start course enrolment.',
        ctaLabel: 'Choose Program(s)',
        lastDate: '25th May 2024'
    };

    totals = { major: '12/78', minor: '03/56' };

    @track semesters = [
        {
            id: 1,
            name: 'Semester 1',
            status: 'Approved',
            statusClass: 'status status-approved',
            major: '12/12',
            minor: '--',
            actionLabel: 'Completed',
            actionState: 'completed',
            actionClass: 'card-action action-completed',
            actionDisabled: true
        },
        {
            id: 2,
            name: 'Semester 2',
            status: 'Ongoing',
            statusClass: 'status status-ongoing',
            major: '00/12',
            minor: '--',
            actionLabel: 'Get Started',
            actionState: 'primary',
            actionClass: 'card-action action-primary',
            actionDisabled: false
        },
        {
            id: 3,
            name: 'Semester 3',
            status: 'Upcoming',
            statusClass: 'status status-upcoming',
            major: '--',
            minor: '--',
            actionLabel: 'Upcoming',
            actionState: 'upcoming',
            actionClass: 'card-action action-upcoming',
            actionDisabled: true
        },
        {
            id: 4,
            name: 'Semester 4',
            status: 'Upcoming',
            statusClass: 'status status-upcoming',
            major: '--',
            minor: '--',
            actionLabel: 'Upcoming',
            actionState: 'upcoming',
            actionClass: 'card-action action-upcoming',
            actionDisabled: true
        },
        {
            id: 5,
            name: 'Semester 5',
            status: 'Upcoming',
            statusClass: 'status status-upcoming',
            major: '--',
            minor: '--',
            actionLabel: 'Upcoming',
            actionState: 'upcoming',
            actionClass: 'card-action action-upcoming',
            actionDisabled: true
        },
        {
            id: 6,
            name: 'Semester 6',
            status: 'Upcoming',
            statusClass: 'status status-upcoming',
            major: '--',
            minor: '--',
            actionLabel: 'Upcoming',
            actionState: 'upcoming',
            actionClass: 'card-action action-upcoming',
            actionDisabled: true
        }
    ];

    handleChooseProgram() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { route: SEMESTER_DETAIL_ROUTE }
        }));

        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: SEMESTER_DETAIL_PAGE }
            });
        } catch (e) {
            const base = window.location.pathname.split('/').filter(Boolean)[0] || 'newportal';
            window.location.href = `/${base}/${SEMESTER_DETAIL_ROUTE}`;
        }
    }

    handleSemesterAction(event) {
        const id = parseInt(event.currentTarget.dataset.id, 10);
        const sem = this.semesters.find(s => s.id === id);
        if (!sem || sem.actionState !== 'primary') return;

        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { route: SEMESTER_DETAIL_ROUTE, semesterId: id }
        }));

        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: SEMESTER_DETAIL_PAGE },
                state: { c__semesterId: String(id) }
            });
        } catch (e) {
            const base = window.location.pathname.split('/').filter(Boolean)[0] || 'newportal';
            window.location.href = `/${base}/${SEMESTER_DETAIL_ROUTE}?c__semesterId=${encodeURIComponent(String(id))}`;
        }
    }
}
