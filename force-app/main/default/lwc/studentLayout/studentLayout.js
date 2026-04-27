import { LightningElement, wire, track } from 'lwc';
import userId from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import USER_CONTACT_ID from '@salesforce/schema/User.ContactId';
import CONTACT_NAME from '@salesforce/schema/Contact.Name';

export default class StudentLayout extends LightningElement {
    @track activeScreen = 'home';
    @track mandatoryCourses = [];
    @track electiveCourses = [];

    studentName;
    contactId;

    @wire(getRecord, {
        recordId: userId,
        fields: [USER_CONTACT_ID]
    })
    userRecord({ data }) {
        if (data) {
            this.contactId = data.fields.ContactId.value;
        }
    }

    @wire(getRecord, {
        recordId: '$contactId',
        fields: [CONTACT_NAME]
    })
    contactRecord({ data }) {
        if (data) {
            this.studentName = data.fields.Name.value;
        }
    }

    handleMenuSelect(event) {
        this.activeScreen = event.detail;
    }

    handleEnroll(event) {
        this.selectedSemester = event.detail.semesterNumber;
        this.selectedAcademicSessionId = event.detail.academicSessionId;
        this.activeScreen = 'courseSelection';
    }

    handleCoursesSelected(event) {
        this.mandatoryCourses = event.detail.mandatory;
        this.electiveCourses = event.detail.elective;
        this.activeScreen = 'summary'; 
    }

    get showHome() {
        return this.activeScreen === 'home';
    }

    get showCourseEnrollment() {
        return this.activeScreen === 'learn';
    }

    get showCourseSelection() {
        return this.activeScreen === 'courseSelection';
    }

    get showSummary() {
        return this.activeScreen === 'summary';
    }

    get showProgramPath(){
        return this.activeScreen === 'programPath';
    }

    get showSchedule(){
        return this.activeScreen === 'schedule';
    }
}