import { LightningElement, api, track } from 'lwc';

const DEFAULT_ISSUE_TYPES = [
    { label: 'Examinations',           value: 'Examinations' },
    { label: 'Course Enrolment',       value: 'Course Enrolment' },
    { label: 'Fees & Payments',        value: 'Fees & Payments' },
    { label: 'Hostel & Accommodation', value: 'Hostel & Accommodation' },
    { label: 'Other',                  value: 'Other' }
];

export default class GetHelpModal extends LightningElement {
    @api title = 'Get Help';
    @api issueTypes;

    @track form = {
        description: '',
        issueType: 'Examinations',
        issueSubject: '',
        fileName: ''
    };

    get options() {
        return Array.isArray(this.issueTypes) && this.issueTypes.length
            ? this.issueTypes
            : DEFAULT_ISSUE_TYPES;
    }

    get isSubmitDisabled() {
        return !this.form.issueSubject || !this.form.issueSubject.trim() || !this.form.issueType;
    }

    handleDescriptionChange(event) {
        this.form = { ...this.form, description: event.target.value };
    }

    handleIssueTypeChange(event) {
        this.form = { ...this.form, issueType: event.target.value };
    }

    handleSubjectChange(event) {
        this.form = { ...this.form, issueSubject: event.target.value };
    }

    handleFileChange(event) {
        const file = event.target.files && event.target.files[0];
        this.form = { ...this.form, fileName: file ? file.name : '' };
    }

    triggerFileInput() {
        const input = this.template.querySelector('.hidden-file');
        if (input) input.click();
    }

    handleAutoCreate() {
        this.dispatchEvent(new CustomEvent('autocreate', {
            detail: { description: this.form.description }
        }));
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleSubmit() {
        if (this.isSubmitDisabled) return;
        this.dispatchEvent(new CustomEvent('submit', { detail: { ...this.form } }));
    }

    handleOverlayClick(event) {
        if (event.target === event.currentTarget) {
            this.handleClose();
        }
    }

    stop(event) {
        event.stopPropagation();
    }
}
