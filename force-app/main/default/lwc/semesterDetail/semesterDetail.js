import { LightningElement, api, track } from 'lwc';
import getSemesterDetail from '@salesforce/apex/KenResultsController.getSemesterDetail';

export default class SemesterDetail extends LightningElement {
    @track _apex;
    @api semesterId;
    programs = [];

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
        this.dispatchEvent(new CustomEvent('navigate', { detail: { route } }));
    }

    handleEnroll() { this.navigateTo('program-selection'); }
    handleSelectCourses() { this.navigateTo('learn'); }
    handleBack() { this.navigateTo('course-enrollment'); }
    handleGetHelp() { this.navigateTo('service-support'); }
}