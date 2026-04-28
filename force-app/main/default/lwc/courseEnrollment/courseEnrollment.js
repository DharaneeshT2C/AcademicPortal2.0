import { LightningElement, wire, track } from 'lwc';
import getAcademicSessionsForUser from '@salesforce/apex/KenCourseEnrollmentController.getAcademicSessionsForUser';

/**
 * Course Enrollment screen.
 * Wires to STANDARD Salesforce Education Cloud objects via
 * `KenCourseEnrollmentController.getAcademicSessionsForUser` —
 * matches the academics-code-reference pattern.
 *
 * Shape returned by Apex: { academicSessionId, academicSessionName,
 * academicTermName, season, cadenceType, termNumber, termLabel, sequence }
 */
export default class CourseEnrollment extends LightningElement {
    @track _rows = [];
    @track _loading = true;
    @track _error;

    @wire(getAcademicSessionsForUser)
    wiredSessions({ data, error }) {
        this._loading = false;
        if (data) {
            this._rows = data;
        } else if (error) {
            this._error = (error.body && error.body.message) || 'Could not load academic sessions.';
            // eslint-disable-next-line no-console
            console.warn('[courseEnrollment] Apex error:', error);
        }
    }

    get loading()   { return this._loading; }
    get hasError()  { return !!this._error; }
    get errorMsg()  { return this._error; }
    get hasRows()   { return !this._loading && this._rows && this._rows.length > 0; }
    get isEmpty()   { return !this._loading && (!this._rows || this._rows.length === 0); }

    /** Aggregate credits across all academic sessions returned by Apex.
     *  Field-level credit tallies live on LearningProgramPlanRqmt; until
     *  that controller method is wired, we render '--' to be honest. */
    get majorCredits() { return '--'; }
    get minorCredits() { return '--'; }

    /**
     * Map each AcademicSessionDTO into the shape the existing template
     * expects (semester card with status pill, button label, credits).
     * Status defaults to "Upcoming" — when the controller surfaces a status
     * field per session, swap this in.
     */
    get formattedSemesters() {
        return (this._rows || []).map(s => {
            const statusType = 'upcoming';
            return {
                id:           s.academicSessionId,
                key:          'sem-' + s.academicSessionId,
                name:         s.termLabel || ('Semester ' + s.termNumber),
                academicSessionName: s.academicSessionName,
                academicTermName:    s.academicTermName,
                season:       s.season,
                cadenceType:  s.cadenceType,
                termNumber:   s.termNumber,
                statusType,
                statusClass:  'sem-status ' + statusType,
                btnLabel:     'Upcoming',
                btnClass:     'sem-btn ' + statusType,
                displayMajorCredits: '--',
                displayMinorCredits: '--'
            };
        });
    }

    navigateTo(route) {
        this.dispatchEvent(new CustomEvent('navigate', { detail: { route } }));
    }
    handleSemesterClick() { this.navigateTo('semester-detail'); }
    handleChooseProgram() { this.navigateTo('program-selection'); }
}