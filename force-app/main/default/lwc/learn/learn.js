import { LightningElement, wire, track } from 'lwc';
import { courses } from 'c/mockData';
import getLearnBundle from '@salesforce/apex/KenLearnController.getLearnBundle';
import getCourseDetail from '@salesforce/apex/KenLearnController.getCourseDetail';

const THEMES = ['green', 'purple', 'purple', 'orange', 'green', 'blue', 'orange', 'green'];
const PROGRAMS = ['BA., Psychology', 'Digital Marketing & E-Commerce', 'Financial Markets & Investment Management'];
const SEMESTERS = ['Semester 1', 'Semester 2', 'Semester 3'];

export default class Learn extends LightningElement {
    @track selectedProgram = PROGRAMS[0];
    @track selectedSemester = SEMESTERS[0];
    @track _apex;
    @track _selectedCourse;
    @track _detailLoading = false;
    @track _detailError;
    courses = courses;

    @wire(getLearnBundle)
    wiredLearn({ data, error }) {
        if (data) this._apex = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[learn] Apex failed, using seed:', error);
        }
    }

    get effectiveCourses() {
        if (this._apex && this._apex.courses && this._apex.courses.length) return this._apex.courses;
        return this.courses;
    }

    get formattedPrograms() {
        return PROGRAMS.map(p => ({
            name: p,
            tabClass: p === this.selectedProgram ? 'tab active' : 'tab'
        }));
    }

    get semesterOptions() {
        return SEMESTERS.map(s => ({ label: s, value: s, selected: s === this.selectedSemester }));
    }

    get filteredCourses() {
        const filtered = this.effectiveCourses.filter(c => {
            const programMatch = !c.program || c.program === this.selectedProgram;
            const semesterMatch = !c.semester || c.semester === this.selectedSemester;
            return programMatch && semesterMatch;
        });
        return filtered.map((c, i) => ({
            ...c,
            formattedTags: (c.tags || []).map((t, j) => ({
                label: t,
                key: 'tag-' + (c.id || i) + '-' + j,
                tagClass: 'tag ' + t.toLowerCase().replace(/\s+/g, '-')
            })),
            thumbTheme: THEMES[i % THEMES.length],
            isCurrent: i < 3,
            cardClass: 'course-card clickable'
        }));
    }

    get hasResults() { return this.filteredCourses.length > 0; }
    get emptyMessage() {
        return `No courses enrolled for ${this.selectedProgram} — ${this.selectedSemester}.`;
    }
    get showCourseDetail() { return !!this._selectedCourse; }
    get detailTags() {
        if (!this._selectedCourse || !this._selectedCourse.tags) return [];
        return this._selectedCourse.tags.map((t, j) => ({
            label: t,
            key: 'dt-' + j,
            tagClass: 'tag ' + t.toLowerCase().replace(/\s+/g, '-')
        }));
    }
    get hasDetailError() { return !!this._detailError; }

    handleProgramSwitch(event) {
        this.selectedProgram = event.currentTarget.dataset.prog;
    }

    handleSemesterChange(event) {
        this.selectedSemester = event.target.value;
    }

    stopPropagation(event) { event.stopPropagation(); }

    handleCourseClick(event) {
        const courseId = event.currentTarget.dataset.id;
        if (!courseId) return;
        // Find local copy first so the modal opens immediately, then enrich via Apex.
        const local = this.effectiveCourses.find(c => String(c.id) === String(courseId));
        if (local) this._selectedCourse = Object.assign({}, local);
        this._detailError = null;
        this._detailLoading = true;
        getCourseDetail({ courseId })
            .then(detail => {
                if (detail) {
                    // Merge Apex detail onto local seed; Apex wins on overlapping keys.
                    this._selectedCourse = Object.assign({}, local || {}, detail);
                }
                this._detailLoading = false;
            })
            .catch(err => {
                // eslint-disable-next-line no-console
                console.warn('[learn] getCourseDetail failed:', err);
                this._detailLoading = false;
                if (!local) {
                    this._detailError = (err && err.body && err.body.message)
                        ? err.body.message : 'Could not load course details.';
                }
            });
    }

    handleCloseDetail() {
        this._selectedCourse = null;
        this._detailError = null;
    }
}