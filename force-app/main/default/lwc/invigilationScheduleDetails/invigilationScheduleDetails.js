import { LightningElement } from 'lwc';

export default class InvigilationScheduleDetails extends LightningElement {
    totalStudents = 40;
    studentsAbsent = '';
    fileName = '';

    showMisconductDetails = false;
    rollNumber = '';
    misconductType = '';
    description = '';

    showSuccessModal = false;

    handleStudentsAbsentChange(event) {
        this.studentsAbsent = event.target.value;
    }

    handleAddMisconduct() {
        this.showMisconductDetails = true;
    }

    handleRollNumberChange(event) {
        this.rollNumber = event.target.value;
    }

    handleMisconductTypeChange(event) {
        this.misconductType = event.target.value;
    }

    handleDescriptionChange(event) {
        this.description = event.target.value;
    }

    triggerFilePicker() {
        const fileInput = this.template.querySelector('.hidden-file-input');
        if (fileInput) {
            fileInput.click();
        }
    }

    handleFileChange(event) {
        const selectedFile = event.target.files && event.target.files[0];
        this.fileName = selectedFile ? selectedFile.name : '';
    }

    handleCancel() {
        this.studentsAbsent = '';
        this.fileName = '';
        this.showMisconductDetails = false;
        this.rollNumber = '';
        this.misconductType = '';
        this.description = '';
    }

    handleSave() {
        this.showSuccessModal = true;
    }

    closeSuccessModal() {
        this.showSuccessModal = false;
    }

    stopModalClose(event) {
        event.stopPropagation();
    }
}