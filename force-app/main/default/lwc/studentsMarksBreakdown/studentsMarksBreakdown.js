import { LightningElement, wire } from 'lwc';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';

const COMPONENT_ROWS = [
    { id: 'c1', component: 'Quiz', maximumMarks: '50', weightage: '40' },
    { id: 'c2', component: 'Mid Term', maximumMarks: '100', weightage: '30' },
    { id: 'c3', component: 'End Term', maximumMarks: '100', weightage: '30' }
];

export default class StudentsMarksBreakdown extends LightningElement {
    organizationDefaults = {};

    get marksRows() {
        return COMPONENT_ROWS;
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