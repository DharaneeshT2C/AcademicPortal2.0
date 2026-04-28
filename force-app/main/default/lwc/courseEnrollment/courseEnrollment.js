import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { pageNameForRoute } from 'c/navHelper';
import { semesters } from 'c/mockData';

export default class CourseEnrollment extends NavigationMixin(LightningElement) {
    semesters = semesters;
    majorCredits = '12/78';
    minorCredits = '03/56';

    get formattedSemesters() {
        return this.semesters.map(s => {
            let btnLabel = 'Upcoming';
            if (s.statusType === 'completed') btnLabel = 'Completed';
            else if (s.statusType === 'ongoing') btnLabel = 'Get Started';
            return {
                ...s,
                key: `sem-${s.id}`,
                statusClass: `sem-status ${s.statusType}`,
                btnLabel,
                btnClass: `sem-btn ${s.statusType}`,
                displayMajorCredits: s.majorCredits || '--',
                displayMinorCredits: s.minorCredits || '--'
            };
        });
    }

    navigateTo(route) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: pageNameForRoute(route) }
        });
    }

    handleSemesterClick() {
        this.navigateTo('semester-detail');
    }
    handleChooseProgram() {
        this.navigateTo('program-selection');
    }
}