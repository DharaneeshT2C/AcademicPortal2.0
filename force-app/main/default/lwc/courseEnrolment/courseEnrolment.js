import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getAcademicSessionsForUser from '@salesforce/apex/KenPortalCourseEnrollmentController.getAcademicSessionsForUser';

const SEMESTER_DETAIL_PAGE = 'Semester_Details__c';
const SEMESTER_DETAIL_ROUTE = 'course-enrolment/semester-details';
const DEFAULT_TOTALS = { major: '12/78', minor: '03/56' };
const MOCK_SEMESTERS = [
    {
        id: 1,
        name: 'Semester 1',
        status: 'Approved',
        statusClass: 'status status-approved',
        startDate: '30 Nov 2025',
        endDate: '22 Dec 2026',
        actionLabel: 'Completed',
        actionState: 'completed',
        actionClass: 'card-action action-completed',
        actionDisabled: true
    },
    {
        id: 2,
        name: 'Semester 2',
        status: 'Ongoing',
        statusClass: 'status status-ongoing',
        startDate: '01 Feb 2023',
        endDate: '01 May 2026',
        actionLabel: 'Get Started',
        actionState: 'primary',
        actionClass: 'card-action action-primary',
        actionDisabled: false
    },
    {
        id: 3,
        name: 'Semester 3',
        status: 'Upcoming',
        statusClass: 'status status-upcoming',
        startDate: '--',
        endDate: '--',
        actionLabel: 'Upcoming',
        actionState: 'upcoming',
        actionClass: 'card-action action-upcoming',
        actionDisabled: true
    },
    {
        id: 4,
        name: 'Semester 4',
        status: 'Upcoming',
        statusClass: 'status status-upcoming',
        startDate: '--',
        endDate: '--',
        actionLabel: 'Upcoming',
        actionState: 'upcoming',
        actionClass: 'card-action action-upcoming',
        actionDisabled: true
    },
    {
        id: 5,
        name: 'Semester 5',
        status: 'Upcoming',
        statusClass: 'status status-upcoming',
        startDate: '--',
        endDate: '--',
        actionLabel: 'Upcoming',
        actionState: 'upcoming',
        actionClass: 'card-action action-upcoming',
        actionDisabled: true
    },
    {
        id: 6,
        name: 'Semester 6',
        status: 'Upcoming',
        statusClass: 'status status-upcoming',
        startDate: '--',
        endDate: '--',
        actionLabel: 'Upcoming',
        actionState: 'upcoming',
        actionClass: 'card-action action-upcoming',
        actionDisabled: true
    }
];

export default class CourseEnrolment extends NavigationMixin(LightningElement) {
    banner = {
        title: 'Choose Program Pathways',
        description: 'Please select your minor programs to start course enrolment.',
        ctaLabel: 'Choose Program(s)',
        lastDate: '25th May 2024'
    };

    @track totals = { ...DEFAULT_TOTALS };
    @track semesters = [...MOCK_SEMESTERS];

    @wire(getAcademicSessionsForUser)
    wiredSessions({ data, error }) {
        const sessionRows = Array.isArray(data)
            ? data
            : (data && Array.isArray(data.returnValue) ? data.returnValue : []);

        if (sessionRows.length) {
            const sortedRows = [...sessionRows].sort((a, b) => Number(a.termNumber || 0) - Number(b.termNumber || 0));
            this.semesters = sortedRows.map((row, index) => this.mapSessionToCard(row, index));
            this.totals = this.buildTotals(sortedRows);
            return;
        }

        if (error) {
            // eslint-disable-next-line no-console
            console.warn('[courseEnrolment] Apex sessions failed, using mock:', error);
            this.semesters = [...MOCK_SEMESTERS];
            this.totals = { ...DEFAULT_TOTALS };
        }
    }

    mapSessionToCard(row, index) {
        const id = Number(row.termNumber) || index + 1;
        const status = this.normalizeStatus(row.registrationStatus);
        const isOngoing = status === 'ongoing';
        const isCompleted = status === 'completed';
        const canViewDetails = row.isProgramCompleted === true && isOngoing;
        return {
            id,
            name: row.termLabel || `Semester ${id}`,
            status: isOngoing ? 'Ongoing' : isCompleted ? 'Approved' : 'Upcoming',
            statusClass: isOngoing ? 'status status-ongoing' : isCompleted ? 'status status-approved' : 'status status-upcoming',
            startDate: this.formatDate(row.registrationStartDate),
            endDate: this.formatDate(row.registrationEndDate),
            actionLabel: isOngoing ? (canViewDetails ? 'View Details' : 'Get Started') : isCompleted ? 'Completed' : 'Upcoming',
            actionState: isOngoing ? 'primary' : isCompleted ? 'completed' : 'upcoming',
            actionClass: isOngoing ? 'card-action action-primary' : isCompleted ? 'card-action action-completed' : 'card-action action-upcoming',
            actionDisabled: !isOngoing
        };
    }

    buildTotals(rows) {
        const majorEarned = this.sumNumeric(rows, ['majorCreditsEarned', 'majorCreditsCompleted', 'earnedMajorCredits']);
        const majorTotal = this.sumNumeric(rows, ['majorCreditsTotal', 'totalMajorCredits', 'majorCredits']);
        const minorEarned = this.sumNumeric(rows, ['minorCreditsEarned', 'minorCreditsCompleted', 'earnedMinorCredits']);
        const minorTotal = this.sumNumeric(rows, ['minorCreditsTotal', 'totalMinorCredits', 'minorCredits']);
        return {
            major: this.formatCredits(majorEarned, majorTotal),
            minor: this.formatCredits(minorEarned, minorTotal)
        };
    }

    sumNumeric(rows, keys) {
        return rows.reduce((sum, row) => {
            for (let i = 0; i < keys.length; i += 1) {
                const value = row[keys[i]];
                const numeric = Number(value);
                if (!Number.isNaN(numeric) && Number.isFinite(numeric)) {
                    return sum + numeric;
                }
            }
            return sum;
        }, 0);
    }

    normalizeStatus(rawStatus) {
        const status = String(rawStatus || 'upcoming').trim().toLowerCase();
        if (status === 'ongoing' || status === 'in progress') return 'ongoing';
        if (status === 'completed' || status === 'closed') return 'completed';
        return 'upcoming';
    }

    formatCredits(earned, total) {
        const hasEarned = earned !== null && earned !== undefined && String(earned).trim() !== '';
        const hasTotal = total !== null && total !== undefined && String(total).trim() !== '';
        if (!hasEarned && !hasTotal) return '--';
        const earnedText = hasEarned ? this.formatCreditPart(earned, true) : '--';
        const totalText = hasTotal ? this.formatCreditPart(total, false) : '--';
        return `${earnedText}/${totalText}`;
    }

    formatCreditPart(value, shouldPad) {
        const numeric = Number(value);
        if (!Number.isNaN(numeric) && Number.isFinite(numeric)) {
            const intValue = Math.trunc(numeric);
            if (shouldPad && intValue >= 0 && intValue < 10) return `0${intValue}`;
            return String(intValue);
        }
        return String(value).trim() || '--';
    }

    formatDate(value) {
        if (!value) return '--';
        try {
            return new Intl.DateTimeFormat('en-GB', {
                day: '2-digit',
                month: 'short',
                year: 'numeric'
            }).format(new Date(value));
        } catch (e) {
            return '--';
        }
    }

    handleChooseProgram() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { route: SEMESTER_DETAIL_ROUTE }
        }));

        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: SEMESTER_DETAIL_PAGE }
            });
        } catch (e) {
            const base = window.location.pathname.split('/').filter(Boolean)[0] || 'newportal';
            window.location.href = `/${base}/${SEMESTER_DETAIL_ROUTE}`;
        }
    }

    handleSemesterAction(event) {
        const id = parseInt(event.currentTarget.dataset.id, 10);
        const sem = this.semesters.find(s => s.id === id);
        if (!sem || sem.actionState !== 'primary') return;

        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { route: SEMESTER_DETAIL_ROUTE, semesterId: id }
        }));

        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: SEMESTER_DETAIL_PAGE },
                state: { c__semesterId: String(id) }
            });
        } catch (e) {
            const base = window.location.pathname.split('/').filter(Boolean)[0] || 'newportal';
            window.location.href = `/${base}/${SEMESTER_DETAIL_ROUTE}?c__semesterId=${encodeURIComponent(String(id))}`;
        }
    }
}
