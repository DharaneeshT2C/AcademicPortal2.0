import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

const SELECTED_COURSE_STORAGE_KEY = 'ken_student_attendance_selected_course';

export default class StudentAttendance extends NavigationMixin(LightningElement) {
    @api historyPageApiName = 'StudentAttendanceHistory__c';

    currentView = 'dashboard';
    selectedCourse = {};

    handleAttendanceOverview() {
        if (this.historyPageApiName) {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: this.historyPageApiName }
            });
            return;
        }
        this.currentView = 'history';
    }

    handleViewDetails(evt) {
        console.log('🎯 Parent: viewdetails event caught!', evt.detail);
        this.selectedCourse = evt.detail || {};
        try {
            window.sessionStorage.setItem(SELECTED_COURSE_STORAGE_KEY, JSON.stringify(this.selectedCourse));
        } catch (e) {
            console.error('Error saving course:', e);
        }
        this.currentView = 'details';
    }

    handleBackToDashboard() {
        console.log('🎯 Parent: backtodashboard event caught!');
        this.currentView = 'dashboard';
    }

    handleBackToHistory() {
        console.log('🎯 Parent: backtohistory event caught!');
        this.currentView = 'history';
    }

    get isDashboardView() {
        return this.currentView === 'dashboard';
    }

    get isHistoryView() {
        return this.currentView === 'history';
    }

    get isDetailsView() {
        return this.currentView === 'details';
    }
}