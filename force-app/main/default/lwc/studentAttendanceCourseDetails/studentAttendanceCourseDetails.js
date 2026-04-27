import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

const ATTENDANCE_DATA = {
    courseInfo: {
        courseName: 'Applied Physics',
        courseCode: 'KJ9844763',
        faculty: 'Ms Smitha Beryl',
        sessionsAttended: 20,
        totalSessions: 24,
        overallPercentage: 63
    },
    dayRows: [
        { id: '1', date: '27 Mar 2026', startTime: '09:00 AM', endTime: '10:00 AM', status: 'Present', statusType: 'present', type: 'Theory', absenceType: '-', reason: '' },
        { id: '2', date: '27 Mar 2026', startTime: '01:00 PM', endTime: '02:00 PM', status: 'Absent', statusType: 'absent', type: 'Theory', absenceType: 'Personal', reason: 'Going for a vacation' },
        { id: '3', date: '26 Mar 2026', startTime: '03:00 PM', endTime: '04:00 PM', status: 'Absent', statusType: 'absent', type: 'Theory', absenceType: 'Exception', reason: '24th sports day practice' },
        { id: '4', date: '25 Mar 2026', startTime: '09:00 AM', endTime: '10:00 AM', status: 'Present', statusType: 'present', type: 'Theory', absenceType: '-', reason: '' },
        { id: '5', date: '24 Mar 2026', startTime: '10:00 AM', endTime: '11:00 AM', status: 'Present', statusType: 'present', type: 'Practical', absenceType: '-', reason: '' },
        { id: '6', date: '24 Mar 2026', startTime: '10:00 AM', endTime: '11:00 AM', status: 'Absent', statusType: 'absent', type: 'Practical', absenceType: 'On Leave', reason: '' },
        { id: '7', date: '23 Mar 2026', startTime: '10:00 AM', endTime: '11:00 AM', status: 'Present', statusType: 'present', type: 'Practical', absenceType: '-', reason: '' }
    ],
    weekData: [
        {
            date: '12 Feb',
            dayName: 'Mon',
            sessions: [
                { id: '1', time: '9 AM', status: 'Present', statusType: 'present' }
            ]
        },
        {
            date: '13 Feb',
            dayName: 'Tue',
            sessions: [
                { id: '2', time: '9 AM', status: 'Present', statusType: 'present' }
            ]
        },
        {
            date: '14 Feb',
            dayName: 'Wed',
            sessions: [
                { id: '3', time: '10 AM', status: 'Absent', statusType: 'absent' }
            ]
        },
        {
            date: '15 Feb',
            dayName: 'Thu',
            sessions: [
                { id: '4', time: '9 AM', status: 'Present', statusType: 'present' },
                { id: '5', time: '10 AM', status: 'Present', statusType: 'present' }
            ]
        },
        {
            date: '16 Feb',
            dayName: 'Fri',
            sessions: [
                { id: '6', time: '9 AM', status: 'Present', statusType: 'present' }
            ]
        },
        {
            date: '17 Feb',
            dayName: 'Sat',
            sessions: []
        },
        {
            date: '18 Feb',
            dayName: 'Sun',
            sessions: []
        }
    ],
    monthData: {
        month: 'February 2026',
        days: Array(29).fill(null).map((_, i) => {
            const dayNum = i + 1;
            const hasAttendance = [5, 6, 9, 11, 12, 13, 14, 15, 16].includes(dayNum);
            const attendance = [];
            if (hasAttendance) {
                if ([5, 12, 13, 15].includes(dayNum)) attendance.push({ id: '1', statusType: 'present' });
                if ([6, 14].includes(dayNum)) attendance.push({ id: '2', statusType: 'absent' });
                if ([9, 11, 16].includes(dayNum)) {
                    attendance.push({ id: '3', statusType: 'present' });
                    attendance.push({ id: '4', statusType: 'present' });
                }
            }
            return {
                date: dayNum.toString(),
                dayOfMonth: dayNum,
                isCurrentMonth: true,
                hasAttendance: attendance.length > 0,
                attendance: attendance.slice(0, 2).map((a, idx) => ({
                    ...a,
                    dotClass: `status-dot status-${a.statusType}`
                })),
                hasMore: attendance.length > 2,
                moreCount: attendance.length - 2
            };
        })
    }
};

export default class StudentAttendanceCourseDetails extends NavigationMixin(LightningElement) {
    @api selectedCourse;
    @api historyPageApiName = 'StudentAttendanceHistory__c';

    activeTab = 'day';
    currentDate = new Date('2026-02-22');

    connectedCallback() {
        if (!this.selectedCourse || !this.selectedCourse.courseCode) {
            try {
                const stored = window.sessionStorage.getItem('ken_student_attendance_selected_course');
                if (stored) {
                    this.selectedCourse = JSON.parse(stored);
                }
            } catch (e) {
                console.error('Error reading course from sessionStorage:', e);
            }
        }
    }

    get resolvedCourseName() {
        return this.selectedCourse?.courseName || ATTENDANCE_DATA.courseInfo.courseName;
    }

    get resolvedCourseCode() {
        return this.selectedCourse?.courseCode || ATTENDANCE_DATA.courseInfo.courseCode;
    }

    get facultyName() {
        return ATTENDANCE_DATA.courseInfo.faculty;
    }

    get sessionsAttended() {
        return ATTENDANCE_DATA.courseInfo.sessionsAttended;
    }

    get totalSessions() {
        return ATTENDANCE_DATA.courseInfo.totalSessions;
    }

    get overallPercentage() {
        return ATTENDANCE_DATA.courseInfo.overallPercentage;
    }

    get overallPercentageClass() {
        const percentage = this.overallPercentage;
        if (percentage >= 75) {
            return 'info-value info-percentage info-percentage-good';
        }
        return 'info-value info-percentage info-percentage-warning';
    }

    get displayDate() {
        const day = this.currentDate.getDate().toString().padStart(2, '0');
        const month = (this.currentDate.getMonth() + 1).toString().padStart(2, '0');
        const year = this.currentDate.getFullYear();
        return `${day}-${month}-${year}`;
    }

    get isDayView() {
        return this.activeTab === 'day';
    }

    get isWeekView() {
        return this.activeTab === 'week';
    }

    get isMonthView() {
        return this.activeTab === 'month';
    }

    get dayTableRows() {
        return ATTENDANCE_DATA.dayRows.map((row) => ({
            ...row,
            statusClass: row.statusType === 'absent' ? 'status-pill status-absent' : 'status-pill status-present'
        }));
    }

    get weekDays() {
        return ATTENDANCE_DATA.weekData.map((day) => ({
            ...day,
            sessions: day.sessions.map((session) => ({
                ...session,
                statusClass: session.statusType === 'absent' ? 'session-status status-absent' : 'session-status status-present'
            }))
        }));
    }

    get weekRange() {
        return 'Feb 12 – Feb 18, 2026';
    }

    get monthLabel() {
        return ATTENDANCE_DATA.monthData.month;
    }

    get monthDays() {
        return ATTENDANCE_DATA.monthData.days;
    }

    get dayTabClass() { return this.activeTab === 'day' ? 'tab active' : 'tab'; }
    get weekTabClass() { return this.activeTab === 'week' ? 'tab active' : 'tab'; }
    get monthTabClass() { return this.activeTab === 'month' ? 'tab active' : 'tab'; }

    handleTabChange(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    handlePrevDate() {
        this.currentDate = new Date(this.currentDate.getTime() - 24 * 60 * 60 * 1000);
    }

    handleNextDate() {
        this.currentDate = new Date(this.currentDate.getTime() + 24 * 60 * 60 * 1000);
    }

    handleBack() {
        if (this.historyPageApiName) {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: this.historyPageApiName }
            });
            return;
        }
        this.dispatchEvent(new CustomEvent('backtohistory', {
            bubbles: true,
            composed: true
        }));
    }
}