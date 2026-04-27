import { LightningElement } from 'lwc';
import communityBasePath from '@salesforce/community/basePath';

export default class FacultyEvaluation extends LightningElement {
    evaluationRequests = [
        {
            id: 'request-1',
            subject: 'Network Analysis & Synthesis',
            bundleCode: '#DHIU1792',
            papers: 12,
            type: 'Theory'
        },
        {
            id: 'request-2',
            subject: 'Signals & Systems',
            bundleCode: '#DHIU38472',
            papers: 19,
            type: 'Practical'
        }
    ];

    get requestsCount() {
        return this.evaluationRequests.length;
    }

    navigateToEvaluationRequests() {
        window.open(this.buildCommunityUrl('exams/evaluation-requests/exam'), '_self');
    }

    navigateToEvaluationBooklets() {
        window.open(this.buildCommunityUrl('exams/evaluation-requests/booklets'), '_self');
    }

    buildCommunityUrl(path = '') {
        const basePath = communityBasePath || '/';
        const sanitizedPath = path.replace(/^\/+|\/+$/g, '');

        if (basePath === '/') {
            return sanitizedPath ? `/${sanitizedPath}` : '/';
        }

        return sanitizedPath ? `${basePath}/${sanitizedPath}` : basePath;
    }
}