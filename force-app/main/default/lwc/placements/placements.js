import { LightningElement, track } from 'lwc';

export default class Placements extends LightningElement {
    @track subRoute = 'landing';
    @track selectedJobId = null;
    @track mockInterviewId = null;

    handleSubNavigate(event) {
        const { route, jobId, interviewId } = event.detail;
        this.subRoute = route;
        if (jobId) this.selectedJobId = jobId;
        if (interviewId) this.mockInterviewId = interviewId;
    }

    get isLanding() { return this.subRoute === 'landing'; }
    get isAllJobs() { return this.subRoute === 'all-jobs'; }
    get isJobDetail() { return this.subRoute === 'job-detail'; }
    get isApplications() { return this.subRoute === 'applications'; }
    get isSavedJobs() { return this.subRoute === 'saved-jobs'; }
    get isResumeLibrary() { return this.subRoute === 'resume-library'; }
    get isResumeEditor() { return this.subRoute === 'resume-editor'; }
    get isPrepHub() { return this.subRoute === 'prep-hub'; }
    get isMockInterview() { return this.subRoute === 'mock-interview'; }
    get isInterviewResults() { return this.subRoute === 'interview-results'; }
    get isCareerCompass() { return this.subRoute === 'career-compass'; }
    get isCompareOffers() { return this.subRoute === 'compare-offers'; }
}