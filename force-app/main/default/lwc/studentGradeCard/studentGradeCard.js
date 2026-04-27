import { LightningElement, wire } from 'lwc';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';

const GRADE_CARDS = [
    { id: 'g1', label: 'Semester - I', credits: '12/12', available: true },
    { id: 'g2', label: 'Semester - I (Back-log)', credits: '12/12', available: true },
    { id: 'g3', label: 'Semester - II', credits: '12/12', available: true },
    { id: 'g4', label: 'Semester - III', credits: '12/12', available: true },
    { id: 'g5', label: 'Semester - IV', credits: '12/12', available: true },
    { id: 'g6', label: 'Semester - V', credits: '12/12', available: false },
    { id: 'g7', label: 'Semester - VI', credits: '12/12', available: false }
];

export default class StudentGradeCard extends LightningElement {
    organizationDefaults = {};
    isDownloadSuccessOpen = false;

    get gradeCards() {
        return GRADE_CARDS;
    }

    handleDownload() {
        this.isDownloadSuccessOpen = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.isDownloadSuccessOpen = false;
        }, 3000);
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