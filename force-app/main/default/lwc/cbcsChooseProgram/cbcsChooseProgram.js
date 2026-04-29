import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getProgramTemplatesForSemester from '@salesforce/apex/KenPortalCourseEnrollmentController.getProgramTemplatesForSemester';
import getCoursesForSemester from '@salesforce/apex/KenPortalCourseEnrollmentController.getCoursesForSemester';
import enrollInPathways from '@salesforce/apex/KenPortalCourseEnrollmentController.enrollInPathways';

const SEMESTER_ENROLMENT_PAGE = 'Semester_Details__c';
const SEMESTER_DETAIL_ROUTE = 'course-enrolment/semester-details';

const EMPTY_BUCKET = {
    mandatoryCredits: 0,
    electiveCredits: 0,
    mandatoryCourses: [],
    electiveCourses: []
};

export default class CbcsChooseProgram extends NavigationMixin(LightningElement) {
    @track context = {
        title: 'Minor Program',
        breadcrumb: 'Course Enrolment > Semester'
    };

    @track searchTerm = '';
    @track selectedId = null;
    @track showConfirmSubmit = false;
    @track loading = false;
    @track errorMessage = '';

    @track allPrograms = [];
    programCourseMap = {};

    selectedSemester = null;
    selectedAcademicSessionId = null;
    selectedTemplateId = null;
    selectedPathwayType = '';

    @wire(CurrentPageReference)
    wiredPageRef(ref) {
        const state = (ref && ref.state) || {};
        const sid = state.c__semesterId;
        const aid = state.c__academicSessionId;
        const tid = state.c__templateId;
        const pathwayType =
            state.c__pathwayType ||
            state.c__templateType ||
            state.c__templateName ||
            state.c__minor;

        if (sid) {
            const parsed = parseInt(sid, 10);
            if (!Number.isNaN(parsed)) {
                this.selectedSemester = parsed;
                this.context.breadcrumb = 'Course Enrolment > Semester ' + parsed;
            }
        }
        if (aid) this.selectedAcademicSessionId = aid;
        if (tid) this.selectedTemplateId = tid;
        if (pathwayType) {
            this.selectedPathwayType = pathwayType;
            this.context.title = pathwayType.toLowerCase().includes('minor')
                ? pathwayType
                : `${pathwayType}`;
        }

        this.loadData();
    }

    loadData() {
        if (!this.selectedSemester) {
            this.errorMessage = '';
            this.allPrograms = [];
            return;
        }

        this.loading = true;
        this.errorMessage = '';

        Promise.all([
            getProgramTemplatesForSemester({ semesterNumber: this.selectedSemester }),
            getCoursesForSemester({
                semesterNumber: this.selectedSemester,
                academicSessionId: this.selectedAcademicSessionId,
                learningPathwayTemplateId: null,
                selectedPathwaysOnly: false
            })
        ])
            .then(([templateRows, courseRows]) => {
                this.programCourseMap = this.buildProgramCourseMap(courseRows || []);
                this.allPrograms = this.buildPrograms(templateRows || []);
                // If a templateId came in, preselect that program
                if (this.selectedTemplateId && this.allPrograms.some(p => p.id === this.selectedTemplateId)) {
                    this.selectedId = this.selectedTemplateId;
                }
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.warn('[cbcsChooseProgram] Apex failed:', error);
                this.errorMessage = (error && error.body && error.body.message) || error.message || 'Failed to load programs.';
                this.allPrograms = [];
                this.programCourseMap = {};
            })
            .finally(() => {
                this.loading = false;
            });
    }

    buildPrograms(templateRows) {
        const normalizedTargetType = this.normalizeText(this.selectedPathwayType);
        const seen = new Set();
        const rows = [];

        templateRows.forEach((row, index) => {
            const templateId = row.learningPathwayTemplateId;
            if (!templateId || seen.has(templateId)) return;

            const templateType = row.templateType || '';
            // Filter to the requested pathway type (e.g. only Minor pathways).
            if (normalizedTargetType && this.normalizeText(templateType) !== normalizedTargetType) {
                return;
            }

            seen.add(templateId);
            const summary = this.programCourseMap[templateId] || EMPTY_BUCKET;
            rows.push({
                id: templateId,
                name: row.learningPathwayTemplateName || '-',
                templateType,
                isEnrolled: row.isEnrolled === true,
                mandatory: summary.mandatoryCredits,
                electives: summary.electiveCredits,
                index
            });
        });

        rows.sort((a, b) => a.name.localeCompare(b.name));
        return rows;
    }

    buildProgramCourseMap(courseRows) {
        const mapByTemplate = {};
        (courseRows || []).forEach((course, index) => {
            const templateId = course.learningPathwayTemplateId;
            if (!templateId) return;

            if (!mapByTemplate[templateId]) {
                mapByTemplate[templateId] = {
                    mandatoryCredits: 0,
                    electiveCredits: 0,
                    mandatoryCourses: [],
                    electiveCourses: []
                };
            }
            const bucket = mapByTemplate[templateId];
            const credits = Number(course.credits) || 0;
            const item = {
                id: course.learningCourseId || course.courseOfferingId || `${templateId}-${index}`,
                name: course.courseName || '-',
                code: course.courseCode || '-',
                credits
            };

            const typeKey = this.normalizeText(course.courseType).replace(/[\s_]+/g, '');
            if (typeKey === 'requirement') {
                bucket.mandatoryCourses.push(item);
                bucket.mandatoryCredits += credits;
            } else if (typeKey === 'requirementplaceholder') {
                bucket.electiveCourses.push(item);
                bucket.electiveCredits += credits;
            }
        });
        return mapByTemplate;
    }

    normalizeText(value) {
        return String(value || '').trim().toLowerCase();
    }

    /* ── Computed (template-facing) ──────────────────────────────────── */

    get programs() {
        const term = this.searchTerm.trim().toLowerCase();
        const filtered = term
            ? this.allPrograms.filter(p =>
                  p.name.toLowerCase().includes(term) ||
                  String(p.mandatory).includes(term) ||
                  String(p.electives).includes(term)
              )
            : this.allPrograms;

        return filtered.map(p => {
            const isSelected = this.selectedId === p.id;
            return {
                ...p,
                cardClass: isSelected ? 'program-card selected' : 'program-card',
                radioClass: isSelected ? 'radio-circle selected' : 'radio-circle',
                creditsLine: `${p.mandatory} Mandatory Credits  •  ${p.electives} Elective Credits`
            };
        });
    }

    get hasPrograms() {
        return this.programs.length > 0;
    }

    get isSubmitDisabled() {
        return !this.selectedId || this.loading;
    }

    /* ── Event handlers ──────────────────────────────────────────────── */

    handleSearch(event) {
        this.searchTerm = event.target.value;
    }

    handleSelect(event) {
        const id = event.currentTarget.dataset.id;
        const program = this.allPrograms.find(p => p.id === id);
        if (program && program.isEnrolled) return;
        this.selectedId = this.selectedId === id ? null : id;
    }

    handleBrochure(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('brochure', { detail: { programId: id } }));
    }

    handleViewCourses(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('viewcourses', { detail: { programId: id } }));
    }

    handleDiscard() {
        this.selectedId = null;
        this.searchTerm = '';
    }

    handleSubmit() {
        if (!this.selectedId) return;
        this.showConfirmSubmit = true;
    }

    handleConfirmCancel() {
        this.showConfirmSubmit = false;
    }

    handleConfirmSubmit() {
        this.showConfirmSubmit = false;
        if (!this.selectedId) return;
        this.loading = true;
        enrollInPathways({ learningPathwayTemplateIds: [this.selectedId] })
            .then(() => {
                this.dispatchEvent(new CustomEvent('submit', { detail: { programId: this.selectedId } }));
                this.goBackToSemester();
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.warn('[cbcsChooseProgram] enrollInPathways failed:', error);
                this.errorMessage = (error && error.body && error.body.message) || error.message || 'Failed to submit pathway selection.';
            })
            .finally(() => {
                this.loading = false;
            });
    }

    goBackToSemester() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { route: SEMESTER_DETAIL_ROUTE }
        }));
        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: SEMESTER_ENROLMENT_PAGE },
                state: {
                    c__semesterId: this.selectedSemester ? String(this.selectedSemester) : '',
                    c__academicSessionId: this.selectedAcademicSessionId || ''
                }
            });
        } catch (e) {
            const base = window.location.pathname.split('/').filter(Boolean)[0] || 'newportal';
            const params = [];
            if (this.selectedSemester) params.push(`c__semesterId=${encodeURIComponent(String(this.selectedSemester))}`);
            if (this.selectedAcademicSessionId) params.push(`c__academicSessionId=${encodeURIComponent(this.selectedAcademicSessionId)}`);
            const query = params.length ? `?${params.join('&')}` : '';
            window.location.href = `/${base}/${SEMESTER_DETAIL_ROUTE}${query}`;
        }
    }
}
