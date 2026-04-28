import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';

const COURSE_ENROLMENT_PAGE = 'CourseEnrolment__c';
const LEARN_ROUTE = 'learn';
const CHOOSE_PROGRAM_ROUTE = 'course-enrolment/semester-details/choose-program';
const CHOOSE_PROGRAM_PAGE = 'Choose_Program__c';
const LEARN_PAGE = 'Learn__c';

export default class CbcsSemesterEnrolment extends NavigationMixin(LightningElement) {
    @track semester = { id: 2, name: 'Semester 2' };

    @track majorProgram = {
        name: 'BA., Psychology',
        mandatory: '0 / 12 credits',
        electives: '0 / 6 credits',
        statusLabel: 'Incomplete',
        lastDate: '12 May 2026'
    };

    @track minorPrograms = [
        {
            id: 'm1',
            name: 'Minor Program 1',
            message: 'Choose a minor pathway to get started with course enrolment.',
            lastDate: '23 April 2026'
        },
        {
            id: 'm2',
            name: 'Minor Program 2',
            message: 'Choose a minor pathway to get started with course enrolment.',
            lastDate: '23 April 2026'
        }
    ];

    footer = {
        message: 'Finish pathway enrollment to start with course selection',
        disabled: false
    };

    @track showGetHelp = false;

    @wire(CurrentPageReference)
    wiredPageRef(ref) {
        const sid = ref && ref.state && ref.state.c__semesterId;
        if (sid) {
            const parsed = parseInt(sid, 10);
            if (!Number.isNaN(parsed)) {
                this.semester = { id: parsed, name: 'Semester ' + parsed };
            }
        }
    }

    get hasMajor() {
        return !!(this.majorProgram && this.majorProgram.name);
    }

    get hasMinors() {
        return Array.isArray(this.minorPrograms) && this.minorPrograms.length > 0;
    }

    get hasPathways() {
        return this.hasMajor || this.hasMinors;
    }

    handleBreadcrumbHome(event) {
        event.preventDefault();
        this.dispatchEvent(new CustomEvent('navigate', { detail: { route: 'home' } }));
        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: 'Home' }
            });
        } catch (e) {
            // SPA-only context
        }
    }

    handleBreadcrumbCourseEnrolment(event) {
        event.preventDefault();
        this.dispatchEvent(new CustomEvent('navigate', { detail: { route: 'course-enrolment' } }));
        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: COURSE_ENROLMENT_PAGE }
            });
        } catch (e) {
            // SPA-only context
        }
    }

    handleGetHelp() {
        this.showGetHelp = true;
        this.dispatchEvent(new CustomEvent('gethelp', { detail: { semesterId: this.semester.id } }));
    }

    handleGetHelpClose() {
        this.showGetHelp = false;
    }

    handleGetHelpSubmit(event) {
        this.showGetHelp = false;
        this.dispatchEvent(new CustomEvent('helpsubmit', {
            detail: { semesterId: this.semester.id, ...event.detail }
        }));
    }

    handleEnrol(event) {
        const id = event.currentTarget.dataset.id;
        const minorNumber = String(id).replace(/^m/, '');

        this.dispatchEvent(new CustomEvent('enrol', {
            detail: { semesterId: this.semester.id, programId: id }
        }));

        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: CHOOSE_PROGRAM_PAGE },
                state: {
                    c__semesterId: String(this.semester.id),
                    c__minor: minorNumber
                }
            });
        } catch (e) {
            const base = window.location.pathname.split('/').filter(Boolean)[0] || 'newportal';
            window.location.href =
                `/${base}/${CHOOSE_PROGRAM_ROUTE}?c__semesterId=${encodeURIComponent(String(this.semester.id))}` +
                `&c__minor=${encodeURIComponent(minorNumber)}`;
        }
    }

    handleSelectCourses() {
        if (this.footer.disabled) return;

        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { route: LEARN_ROUTE, semesterId: this.semester.id }
        }));

        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: LEARN_PAGE }
            });
        } catch (e) {
            const base = window.location.pathname.split('/').filter(Boolean)[0] || 'newportal';
            window.location.href = `/${base}/${LEARN_ROUTE}`;
        }
    }
}
