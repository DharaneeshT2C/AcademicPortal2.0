import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getProgramTemplatesForSemester from '@salesforce/apex/KenPortalCourseEnrollmentController.getProgramTemplatesForSemester';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';

const COURSE_ENROLMENT_PAGE = 'CourseEnrolment__c';
const CHOOSE_PROGRAM_PAGE = 'Choose_Program__c';
const CHOOSE_PROGRAM_ROUTE = 'course-enrolment/semester-details/choose-program';
const PATH_CONFIG_PAGE = 'Path_Configuration__c';
const PATH_CONFIG_ROUTE = 'course-enrolment/semester-details/choose-program/path-configuration';

const DEFAULT_FOOTER = {
    message: 'Finish pathway enrollment to start with course selection',
    disabled: true
};

export default class CbcsSemesterEnrolment extends NavigationMixin(LightningElement) {
    @track semester = { id: null, name: 'Semester' };
    @track academicSessionId = null;

    @track majorProgram = null;
    @track minorPrograms = [];
    @track footer = { ...DEFAULT_FOOTER };
    @track loading = true;
    @track errorMessage = '';

    get crumbs() {
        return [
            { label: 'Home',             pageName: 'Home' },
            { label: 'Course Enrolment', pageName: COURSE_ENROLMENT_PAGE },
            { label: this.semester ? this.semester.name : 'Semester' }
        ];
    }

    @track showGetHelp = false;
    organizationDefaults = {};

    @wire(OrganizationDefaultsApiController)
    wiredOrganizationDefaults({ data }) {
        if (data) {
            this.organizationDefaults = data;
            this.applyOrganizationTheme();
        }
    }

    applyOrganizationTheme() {
        const primary = this.organizationDefaults?.primary;
        const secondary = this.organizationDefaults?.secondary;
        if (primary && typeof primary === 'string') {
            this.template?.host?.style.setProperty('--primary-color', primary);
            try { document.documentElement.style.setProperty('--primary-color', primary); } catch (e) {}
        }
        if (secondary && typeof secondary === 'string') {
            this.template?.host?.style.setProperty('--secondary-color', secondary);
            try { document.documentElement.style.setProperty('--secondary-color', secondary); } catch (e) {}
        }
    }

    @wire(CurrentPageReference)
    wiredPageRef(ref) {
        const sid = ref && ref.state && ref.state.c__semesterId;
        const aid = ref && ref.state && ref.state.c__academicSessionId;
        if (sid) {
            const parsed = parseInt(sid, 10);
            if (!Number.isNaN(parsed)) {
                this.semester = { id: parsed, name: 'Semester ' + parsed };
            }
        }
        if (aid) {
            this.academicSessionId = aid;
        }
        this.loadProgramTemplates();
    }

    loadProgramTemplates() {
        if (!this.semester || !this.semester.id) {
            return;
        }
        this.loading = true;
        this.errorMessage = '';
        getProgramTemplatesForSemester({ semesterNumber: this.semester.id })
            .then(rows => this.applyTemplateRows(rows || []))
            .catch(error => {
                // eslint-disable-next-line no-console
                console.warn('[cbcsSemesterEnrolment] Apex failed:', error);
                this.errorMessage = (error && error.body && error.body.message) || error.message || 'Failed to load program templates.';
                this.majorProgram = null;
                this.minorPrograms = [];
                this.footer = { ...DEFAULT_FOOTER };
            })
            .finally(() => {
                this.loading = false;
            });
    }

    applyTemplateRows(rows) {
        // Dedupe by templateType, OR'ing isEnrolled — same logic as portalCourseEnrollmentDetails
        const uniqueByType = new Map();
        rows.forEach(item => {
            const normalizedType = (item.templateType || '').trim().toLowerCase();
            const typeKey = normalizedType || item.learningPathwayTemplateId || '';
            if (!uniqueByType.has(typeKey)) {
                uniqueByType.set(typeKey, { ...item, isEnrolled: item.isEnrolled === true });
            } else {
                const existing = uniqueByType.get(typeKey);
                existing.isEnrolled = existing.isEnrolled || item.isEnrolled === true;
            }
        });

        const ordered = [...uniqueByType.values()].sort((a, b) => {
            const aLabel = (a.templateType || a.learningPathwayTemplateName || '').toLowerCase();
            const bLabel = (b.templateType || b.learningPathwayTemplateName || '').toLowerCase();
            const aMajor = aLabel.includes('major');
            const bMajor = bLabel.includes('major');
            if (aMajor === bMajor) return 0;
            return aMajor ? -1 : 1;
        });

        let major = null;
        const minors = [];
        ordered.forEach((item, index) => {
            const typeLabel = item.templateType || item.learningPathwayTemplateName || '-';
            const isPrimary = typeLabel.toLowerCase().includes('major');
            const isEnrolled = item.isEnrolled === true;
            if (isPrimary && !major) {
                major = {
                    name: typeLabel,
                    mandatory: '0 / 12 credits',
                    electives: '0 / 6 credits',
                    statusLabel: 'Incomplete',
                    lastDate: '12 May 2026',
                    templateId: item.learningPathwayTemplateId
                };
            } else {
                minors.push({
                    id: item.learningPathwayTemplateId || `row-${index}`,
                    name: typeLabel,
                    message: isEnrolled
                        ? 'Pathway enrolled.'
                        : 'Choose a minor pathway to get started with course enrolment.',
                    lastDate: '23 April 2026',
                    isEnrolled: isEnrolled,
                    showEnrolButton: !isEnrolled,
                    pathwayType: item.templateType || item.learningPathwayTemplateName || '',
                    templateId: item.learningPathwayTemplateId
                });
            }
        });

        this.majorProgram = major;
        this.minorPrograms = minors;
        const allMinorsEnrolled = minors.length === 0 || minors.every(m => m.isEnrolled);
        this.footer = {
            message: allMinorsEnrolled
                ? 'Ready to select courses.'
                : 'Finish pathway enrollment to start with course selection',
            disabled: !allMinorsEnrolled
        };
    }

    get hasMajor() { return !!(this.majorProgram && this.majorProgram.name); }
    get hasMinors() { return Array.isArray(this.minorPrograms) && this.minorPrograms.length > 0; }
    get hasPathways() { return this.hasMajor || this.hasMinors; }

    handleBreadcrumbHome(event) {
        event.preventDefault();
        this.dispatchEvent(new CustomEvent('navigate', { detail: { route: 'home' } }));
        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: 'Home' }
            });
        } catch (e) {
            // SPA-only context
        }
    }

    handleBreadcrumbCourseEnrolment(event) {
        event.preventDefault();
        this.dispatchEvent(new CustomEvent('navigate', { detail: { route: 'course-enrolment' } }));
        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: COURSE_ENROLMENT_PAGE }
            });
        } catch (e) {
            // SPA-only context
        }
    }

    handleGetHelp() {
        this.showGetHelp = true;
        this.dispatchEvent(new CustomEvent('gethelp', { detail: { semesterId: this.semester.id } }));
    }

    handleGetHelpClose() {
        this.showGetHelp = false;
    }

    handleGetHelpSubmit(event) {
        this.showGetHelp = false;
        this.dispatchEvent(new CustomEvent('helpsubmit', {
            detail: { semesterId: this.semester.id, ...event.detail }
        }));
    }

    handleEnrol(event) {
        const id = event.currentTarget.dataset.id;
        const minor = (this.minorPrograms || []).find(m => m.id === id);
        if (!minor || minor.isEnrolled) return;

        this.dispatchEvent(new CustomEvent('enrol', {
            detail: { semesterId: this.semester.id, programId: id }
        }));

        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: CHOOSE_PROGRAM_PAGE },
                state: {
                    c__semesterId: String(this.semester.id),
                    c__academicSessionId: this.academicSessionId || '',
                    c__templateId: minor.templateId || '',
                    c__pathwayType: minor.pathwayType || ''
                }
            });
        } catch (e) {
            const base = window.location.pathname.split('/').filter(Boolean)[0] || 'newportal';
            const params = [
                `c__semesterId=${encodeURIComponent(String(this.semester.id))}`,
                `c__academicSessionId=${encodeURIComponent(this.academicSessionId || '')}`,
                `c__templateId=${encodeURIComponent(minor.templateId || '')}`,
                `c__pathwayType=${encodeURIComponent(minor.pathwayType || '')}`
            ];
            window.location.href = `/${base}/${CHOOSE_PROGRAM_ROUTE}?${params.join('&')}`;
        }
    }

    handleSelectCourses() {
        if (this.footer.disabled) return;

        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { route: PATH_CONFIG_ROUTE, semesterId: this.semester.id }
        }));

        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: PATH_CONFIG_PAGE },
                state: {
                    c__semesterId: String(this.semester.id),
                    c__academicSessionId: this.academicSessionId || '',
                    c__selectedPathwaysOnly: 'true'
                }
            });
        } catch (e) {
            const base = window.location.pathname.split('/').filter(Boolean)[0] || 'newportal';
            const params = [
                `c__semesterId=${encodeURIComponent(String(this.semester.id))}`,
                `c__academicSessionId=${encodeURIComponent(this.academicSessionId || '')}`,
                `c__selectedPathwaysOnly=true`
            ];
            window.location.href = `/${base}/${PATH_CONFIG_ROUTE}?${params.join('&')}`;
        }
    }
}
