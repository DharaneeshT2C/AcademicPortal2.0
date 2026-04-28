import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { pageNameForRoute } from 'c/navHelper';
import { semesterPrograms } from 'c/mockData';
import getSemesterDetail from '@salesforce/apex/KenResultsController.getSemesterDetail';

export default class SemesterDetail extends NavigationMixin(LightningElement) {
    @track _apex;
    @api semesterId;
    // Seed fallback.
    programs = semesterPrograms;

    connectedCallback() {
        this.loadSemester();
    }

    renderedCallback() {
        // No-op; rely on @api setter triggering loadSemester if parent changes the id.
    }

    loadSemester() {
        if (!this.semesterId) return;
        getSemesterDetail({ semesterId: this.semesterId })
            .then(data => { this._apex = data; })
            .catch(err => {
                // eslint-disable-next-line no-console
                console.warn('[semesterDetail] getSemesterDetail failed, using seed:', err);
            });
    }

    get effectiveSubjects() {
        return this._apex || [];
    }

    navigateTo(route) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: pageNameForRoute(route) }
        });
    }

    handleEnroll() { this.navigateTo('program-selection'); }
    handleSelectCourses() { this.navigateTo('learn'); }
    handleBack() { this.navigateTo('course-enrollment'); }
    handleGetHelp() { this.navigateTo('service-support'); }
}