import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';

const SEMESTER_ENROLMENT_PAGE = 'CbcsSemesterEnrolment__c';
const SEMESTER_DETAIL_ROUTE = 'course-enrolment/semester-details';

export default class CbcsChooseProgram extends NavigationMixin(LightningElement) {
    @track context = {
        title: 'Minor Program 1',
        breadcrumb: 'Course Enrolment > Semester 2'
    };

    @track searchTerm = '';
    @track selectedId = 'ai-ml';
    @track showConfirmSubmit = false;

    allPrograms = [
        { id: 'ds',    name: 'Data Science & Analytics',                 mandatory: 24, electives: 8  },
        { id: 'ai-ml', name: 'Artificial Intelligence & Machine Learning', mandatory: 24, electives: 12 },
        { id: 'cyber', name: 'Cyber Security & Ethical Hacking',         mandatory: 12, electives: 10 },
        { id: 'biz',   name: 'Business Analytics',                       mandatory: 28, electives: 14 },
        { id: 'fin',   name: 'Financial Markets & Investment Management', mandatory: 20, electives: 12 }
    ];

    @wire(CurrentPageReference)
    wiredPageRef(ref) {
        const minor = ref && ref.state && ref.state.c__minor;
        const semester = ref && ref.state && ref.state.c__semesterId;
        if (minor) this.context.title = 'Minor Program ' + minor;
        if (semester) this.context.breadcrumb = 'Course Enrolment > Semester ' + semester;
    }

    get programs() {
        const term = this.searchTerm.trim().toLowerCase();
        const filtered = term
            ? this.allPrograms.filter(p => p.name.toLowerCase().includes(term))
            : this.allPrograms;
        return filtered.map(p => ({
            ...p,
            cardClass: this.selectedId === p.id ? 'program-card selected' : 'program-card',
            radioClass: this.selectedId === p.id ? 'radio-circle selected' : 'radio-circle',
            creditsLine: p.mandatory + ' Mandatory Credits  •  ' + p.electives + ' Elective Credits'
        }));
    }

    get hasPrograms() {
        return this.programs.length > 0;
    }

    get isSubmitDisabled() {
        return !this.selectedId;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
    }

    handleSelect(event) {
        this.selectedId = event.currentTarget.dataset.id;
    }

    handleBrochure(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('brochure', { detail: { programId: id } }));
    }

    handleViewCourses(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('viewcourses', { detail: { programId: id } }));
    }

    handleDiscard() {
        this.selectedId = null;
        this.searchTerm = '';
    }

    handleSubmit() {
        if (!this.selectedId) return;
        this.showConfirmSubmit = true;
    }

    handleConfirmCancel() {
        this.showConfirmSubmit = false;
    }

    handleConfirmSubmit() {
        this.showConfirmSubmit = false;
        if (!this.selectedId) return;
        this.dispatchEvent(new CustomEvent('submit', { detail: { programId: this.selectedId } }));
        this.goBackToSemester();
    }

    goBackToSemester() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { route: SEMESTER_DETAIL_ROUTE }
        }));
        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: SEMESTER_ENROLMENT_PAGE }
            });
        } catch (e) {
            const base = window.location.pathname.split('/').filter(Boolean)[0] || 'newportal';
            window.location.href = `/${base}/${SEMESTER_DETAIL_ROUTE}`;
        }
    }
}
