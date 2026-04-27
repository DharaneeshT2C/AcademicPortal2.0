import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProgramTemplatesForSemester from '@salesforce/apex/KenPortalCourseEnrollmentController.getProgramTemplatesForSemester';
import getCoursesForSemester from '@salesforce/apex/KenPortalCourseEnrollmentController.getCoursesForSemester';
import enrollInPathways from '@salesforce/apex/KenPortalCourseEnrollmentController.enrollInPathways';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';

const EMPTY_MODAL_DATA = {
    id: '',
    name: '-',
    mandatoryCredits: 0,
    electiveCredits: 0,
    mandatoryCourses: [],
    electiveCourses: [],
    hasMandatoryCourses: false,
    hasElectiveCourses: false
};

export default class PortalCourseBroucher extends LightningElement {
    static DEFAULT_PRIMARY = '#3061FF';
    static DEFAULT_SECONDARY = '#EAEFFF';

    allPrograms = [];
    programCourseMap = {};
    selectedProgramId = null;
    isCourseModalOpen = false;
    modalProgramId = null;
    searchKeyword = '';
    isLoading = false;
    errorMessage = '';
    organizationDefaults = {};

    selectedSemester = null;
    selectedAcademicSessionId = null;
    selectedPathwayType = '';

    applyOrganizationTheme(primary, secondary) {
        const resolvedPrimary = primary || this.organizationDefaults?.primary || PortalCourseBroucher.DEFAULT_PRIMARY;
        const resolvedSecondary = secondary || this.organizationDefaults?.secondary || PortalCourseBroucher.DEFAULT_SECONDARY;

        if (!this.template?.host) {
            return;
        }

        this.template.host.style.setProperty('--primary-color', resolvedPrimary);
        this.template.host.style.setProperty('--secondary-color', resolvedSecondary);
    }

    @wire(OrganizationDefaultsApiController)
    wiredOrganizationDefaults({ data, error }) {
        if (data) {
            this.organizationDefaults = data;
            this.applyOrganizationTheme(data.primary, data.secondary);
            return;
        }

        if (error) {
            this.organizationDefaults = {};
        }
        this.applyOrganizationTheme();
    }

    connectedCallback() {
        this.applyOrganizationTheme();
        const params = new URLSearchParams(window.location.search || '');
        const semesterParam = params.get('semester') || params.get('c__semester');
        const sessionParam = params.get('academicSessionId') || params.get('c__academicSessionId');
        const pathwayTypeParam =
            params.get('pathwayType') ||
            params.get('c__pathwayType') ||
            params.get('templateType') ||
            params.get('c__templateType') ||
            params.get('templateName') ||
            params.get('c__templateName');

        const parsedSemester = Number(semesterParam);
        if (!Number.isNaN(parsedSemester) && parsedSemester > 0) {
            this.selectedSemester = parsedSemester;
        }
        if (sessionParam) {
            this.selectedAcademicSessionId = sessionParam;
        }
        if (pathwayTypeParam) {
            this.selectedPathwayType = pathwayTypeParam;
        }

        this.loadData();
    }

    get programs() {
        const keyword = this.searchKeyword.trim().toLowerCase();
        const filteredPrograms = keyword
            ? this.allPrograms.filter(
                  (program) =>
                      program.name.toLowerCase().includes(keyword) ||
                      program.credits.toLowerCase().includes(keyword)
              )
            : this.allPrograms;

        const selectedVisible = filteredPrograms.some((program) => program.id === this.selectedProgramId);
        const hasSelection = Boolean(this.selectedProgramId) && selectedVisible;

        return filteredPrograms.map((program) => {
            const isSelected = this.selectedProgramId === program.id;
            const isSelectDisabled = program.isEnrolled || (hasSelection && !isSelected);
            const isViewDisabled = hasSelection && !isSelected;
            return {
                ...program,
                isSelected,
                isSelectDisabled,
                isViewDisabled,
                cardClass: isSelected ? 'program-card program-card-selected' : 'program-card',
                checkboxClass: isSelected ? 'select-box select-box-checked' : 'select-box'
            };
        });
    }

    get hasPrograms() {
        return this.programs.length > 0;
    }

    get activeProgram() {
        const program = this.allPrograms.find((item) => item.id === this.modalProgramId);
        if (!program) {
            return EMPTY_MODAL_DATA;
        }
        const modalData = this.programCourseMap[program.id] || EMPTY_MODAL_DATA;
        return { ...program, ...modalData };
    }

    get isSubmitDisabled() {
        return this.isLoading || !this.selectedProgramId;
    }

    async loadData() {
        if (!this.selectedSemester) {
            this.errorMessage = 'Semester is missing in URL.';
            this.allPrograms = [];
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';

        try {
            const [templateRows, courseRows] = await Promise.all([
                getProgramTemplatesForSemester({
                    semesterNumber: this.selectedSemester
                }),
                getCoursesForSemester({
                    semesterNumber: this.selectedSemester,
                    academicSessionId: this.selectedAcademicSessionId,
                    learningPathwayTemplateId: null,
                    selectedPathwaysOnly: false
                })
            ]);

            this.programCourseMap = this.buildProgramCourseMap(courseRows || []);
            this.allPrograms = this.buildPrograms(templateRows || []);
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Failed to load programs.';
            this.allPrograms = [];
            this.programCourseMap = {};
        } finally {
            this.isLoading = false;
        }
    }

    buildPrograms(templateRows) {
        const normalizedTargetType = this.normalizeText(this.selectedPathwayType);
        const seenTemplateIds = new Set();
        const rows = [];

        templateRows.forEach((row, index) => {
            const templateId = row.learningPathwayTemplateId;
            if (!templateId || seenTemplateIds.has(templateId)) {
                return;
            }

            const templateType = row.templateType || '';
            if (normalizedTargetType && this.normalizeText(templateType) !== normalizedTargetType) {
                return;
            }

            seenTemplateIds.add(templateId);
            const summary = this.programCourseMap[templateId] || EMPTY_MODAL_DATA;
            rows.push({
                id: templateId,
                index,
                name: row.learningPathwayTemplateName || '-',
                templateType,
                isEnrolled: row.isEnrolled === true,
                credits: `${summary.mandatoryCredits} Mandatory Credits • ${summary.electiveCredits} Elective Credits`
            });
        });

        rows.sort((a, b) => a.name.localeCompare(b.name));
        return rows;
    }

    buildProgramCourseMap(courseRows) {
        const mapByTemplate = {};

        (courseRows || []).forEach((course, index) => {
            const templateId = course.learningPathwayTemplateId;
            if (!templateId) {
                return;
            }

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

        Object.keys(mapByTemplate).forEach((templateId) => {
            const bucket = mapByTemplate[templateId];
            mapByTemplate[templateId] = {
                ...bucket,
                hasMandatoryCourses: bucket.mandatoryCourses.length > 0,
                hasElectiveCourses: bucket.electiveCourses.length > 0
            };
        });

        return mapByTemplate;
    }

    normalizeText(value) {
        return String(value || '')
            .trim()
            .toLowerCase();
    }

    handleProgramSelect(event) {
        const { id } = event.currentTarget.dataset;
        if (!id) {
            return;
        }
        const selected = this.allPrograms.find((program) => program.id === id);
        if (selected && selected.isEnrolled) {
            return;
        }
        this.selectedProgramId = this.selectedProgramId === id ? null : id;
    }

    handleSearchInput(event) {
        this.searchKeyword = event.target.value || '';
    }

    handleViewCourses(event) {
        const { id } = event.currentTarget.dataset;
        if (!id) {
            return;
        }
        this.modalProgramId = id;
        this.isCourseModalOpen = true;
    }

    handleCloseCoursesModal() {
        this.isCourseModalOpen = false;
        this.modalProgramId = null;
    }

    handleDiscardChanges() {
        this.selectedProgramId = null;
    }

    async handleSubmitSelection() {
        if (!this.selectedProgramId) {
            return;
        }
        this.isLoading = true;
        try {
            await enrollInPathways({
                learningPathwayTemplateIds: [this.selectedProgramId]
            });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Pathway selection submitted.',
                    variant: 'success'
                })
            );
            this.navigateBackToEnrollmentDetails();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error?.body?.message || error?.message || 'Failed to submit pathway selection.',
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    navigateBackToEnrollmentDetails() {
        const currentPath = window.location.pathname || '';
        const currentPagePrefix = currentPath.replace(/\/coursebroucher(?:\/.*)?$/i, '');
        const sitePrefix = currentPagePrefix && currentPagePrefix !== '/' ? currentPagePrefix : '';
        const queryParts = [];
        if (this.selectedSemester) {
            queryParts.push(`semester=${encodeURIComponent(String(this.selectedSemester))}`);
        }
        if (this.selectedAcademicSessionId) {
            queryParts.push(`academicSessionId=${encodeURIComponent(this.selectedAcademicSessionId)}`);
        }
        const query = queryParts.length ? `?${queryParts.join('&')}` : '';
        window.location.assign(`${sitePrefix}/courseenrollmentdetails${query}`);
    }
}