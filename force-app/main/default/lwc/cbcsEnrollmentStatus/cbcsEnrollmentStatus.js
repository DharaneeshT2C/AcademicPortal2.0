import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getLearnerPathwayItemsForAfterEnrollment from '@salesforce/apex/KenPortalCourseEnrollmentController.getLearnerPathwayItemsForAfterEnrollment';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';

const COURSE_ENROLMENT_PAGE = 'CourseEnrolment__c';
const PATH_CONFIG_PAGE = 'Path_Configuration__c';
const PATH_CONFIG_ROUTE = 'course-enrolment/semester-details/choose-program/path-configuration';

export default class CbcsEnrollmentStatus extends NavigationMixin(LightningElement) {
    @track semester = { id: null, name: 'Semester' };
    @track academicSessionId = null;

    @track pathwaySections = [];
    @track summary = { total: 0, approved: 0, rejected: 0, inReview: 0 };
    @track loading = true;
    @track errorMessage = '';
    @track isScheduleModalOpen = false;
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
        const state = (ref && ref.state) || {};
        const sid = state.c__semesterId;
        const aid = state.c__academicSessionId;
        if (sid) {
            const parsed = parseInt(sid, 10);
            if (!Number.isNaN(parsed)) {
                this.semester = { id: parsed, name: 'Semester ' + parsed };
            }
        }
        if (aid) this.academicSessionId = aid;
        this.loadEnrollmentDetails();
    }

    loadEnrollmentDetails() {
        this.loading = true;
        this.errorMessage = '';
        getLearnerPathwayItemsForAfterEnrollment({ academicSessionId: this.academicSessionId })
            .then(courses => {
                const sectionByTemplate = new Map();
                const summary = { total: 0, approved: 0, rejected: 0, inReview: 0 };
                (courses || []).forEach((course, index) => {
                    const templateId = course.learningPathwayTemplateId || course.learningPathwayTemplateName || `template-${index}`;
                    if (!sectionByTemplate.has(templateId)) {
                        sectionByTemplate.set(templateId, {
                            id: templateId,
                            title: course.learningPathwayTemplateName || 'Pathway',
                            mandatoryCredits: 0,
                            electiveCredits: 0,
                            rows: []
                        });
                    }
                    const rowType = (course.courseType || '').toLowerCase() === 'requirement' ? 'Mandatory' : 'Elective';
                    const credits = Number(course.credits) || 0;
                    const section = sectionByTemplate.get(templateId);
                    if (rowType === 'Mandatory') {
                        section.mandatoryCredits += credits;
                    } else {
                        section.electiveCredits += credits;
                    }
                    const statusKey = this.normalizeStatusKey(course.enrollmentStatus);
                    summary.total += 1;
                    if (statusKey === 'approved') summary.approved += 1;
                    else if (statusKey === 'rejected') summary.rejected += 1;
                    else summary.inReview += 1;

                    section.rows.push({
                        id: course.learningPathwayTemplateItemId || `${templateId}-${index}`,
                        courseName: course.courseName || '-',
                        courseCode: course.courseCode || '-',
                        credits,
                        type: rowType,
                        faculty: '-',
                        status: this.resolveStatusLabel(course.enrollmentStatus),
                        statusClass: this.resolveStatusClass(course.enrollmentStatus)
                    });
                });

                this.pathwaySections = Array.from(sectionByTemplate.values()).map(section => ({
                    ...section,
                    metaText: `Mandatory: ${section.mandatoryCredits} credits  •  Elective: ${section.electiveCredits} credits`,
                    hasRows: section.rows.length > 0
                }));
                this.summary = summary;
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.warn('[cbcsEnrollmentStatus] Apex failed:', error);
                this.errorMessage = (error && error.body && error.body.message) || error.message || 'Failed to load enrollment details.';
                this.pathwaySections = [];
                this.summary = { total: 0, approved: 0, rejected: 0, inReview: 0 };
            })
            .finally(() => {
                this.loading = false;
            });
    }

    normalizeStatusKey(rawStatus) {
        const normalized = String(rawStatus || '').trim().toLowerCase();
        if (normalized === 'approved') return 'approved';
        if (normalized === 'rejected') return 'rejected';
        return 'inreview';
    }

    resolveStatusLabel(rawStatus) {
        const label = String(rawStatus || '').trim();
        return label || 'In Review';
    }

    resolveStatusClass(rawStatus) {
        const key = this.normalizeStatusKey(rawStatus);
        if (key === 'approved') return 'status-pill status-pill-approved';
        if (key === 'rejected') return 'status-pill status-pill-rejected';
        return 'status-pill status-pill-warning';
    }

    /* ── Banner state machine (replicates kenPortalAfterEnrollment.bannerModel) ── */
    get banner() {
        const total = Number(this.summary.total || 0);
        const approved = Number(this.summary.approved || 0);
        const rejected = Number(this.summary.rejected || 0);

        if (total > 0 && approved === total) {
            return {
                title: 'Enrollment Approved!',
                description: 'The enrolment window is now closed. No further changes can be made.',
                pillLabel: 'Enrollment Closed',
                pillClass: 'status-pill status-pill-approved',
                bannerClass: 'status-banner status-banner-approved',
                iconText: '✓',
                iconClass: 'banner-icon banner-icon-approved',
                showEditButton: false,
                editButtonLabel: '',
                showViewScheduleButton: true
            };
        }
        if (total > 0 && rejected === total) {
            return {
                title: 'Enrollment Rejected',
                description: 'Your enrolment could not be approved.',
                pillLabel: 'Rejected',
                pillClass: 'status-pill status-pill-rejected',
                bannerClass: 'status-banner status-banner-rejected',
                iconText: '×',
                iconClass: 'banner-icon banner-icon-rejected',
                showEditButton: true,
                editButtonLabel: 'Edit & Resubmit',
                showViewScheduleButton: false
            };
        }
        if (approved > 0 && approved < total) {
            return {
                title: 'Partially Approved',
                description: 'Your enrolment was approved partially. You can find the schedule for all the approved courses.',
                pillLabel: 'Partially Approved',
                pillClass: 'status-pill status-pill-warning',
                bannerClass: 'status-banner status-banner-warning',
                iconText: '!',
                iconClass: 'banner-icon banner-icon-warning',
                showEditButton: true,
                editButtonLabel: 'Edit & Resubmit',
                showViewScheduleButton: true
            };
        }
        return {
            title: 'Enrollment Window is Open.',
            description: 'The enrollment is under review. You can still make changes while it is in review.',
            pillLabel: 'In Review',
            pillClass: 'status-pill status-pill-warning',
            bannerClass: 'status-banner status-banner-warning',
            iconText: '!',
            iconClass: 'banner-icon banner-icon-warning',
            showEditButton: true,
            editButtonLabel: 'Edit Enrollment',
            showViewScheduleButton: false
        };
    }

    get hasContent() {
        return this.pathwaySections && this.pathwaySections.length > 0;
    }

    get crumbs() {
        return [
            { label: 'Home',             pageName: 'Home' },
            { label: 'Course Enrolment', pageName: COURSE_ENROLMENT_PAGE },
            { label: this.semester ? this.semester.name : 'Semester' }
        ];
    }

    handleBreadcrumbHome(event) {
        event.preventDefault();
        this.dispatchEvent(new CustomEvent('navigate', { detail: { route: 'home' } }));
        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: 'Home' }
            });
        } catch (e) { /* SPA-only */ }
    }

    handleBreadcrumbCourseEnrolment(event) {
        event.preventDefault();
        this.dispatchEvent(new CustomEvent('navigate', { detail: { route: 'course-enrolment' } }));
        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: COURSE_ENROLMENT_PAGE }
            });
        } catch (e) { /* SPA-only */ }
    }

    handleEditEnrollment() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { route: PATH_CONFIG_ROUTE, semesterId: this.semester.id }
        }));
        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: PATH_CONFIG_PAGE },
                state: {
                    c__semesterId: this.semester.id ? String(this.semester.id) : '',
                    c__academicSessionId: this.academicSessionId || '',
                    c__selectedPathwaysOnly: 'true'
                }
            });
        } catch (e) {
            const base = window.location.pathname.split('/').filter(Boolean)[0] || 'newportal';
            const params = [
                `c__semesterId=${encodeURIComponent(this.semester.id ? String(this.semester.id) : '')}`,
                `c__academicSessionId=${encodeURIComponent(this.academicSessionId || '')}`,
                `c__selectedPathwaysOnly=true`
            ];
            window.location.href = `/${base}/${PATH_CONFIG_ROUTE}?${params.join('&')}`;
        }
    }

    handleViewSchedule() {
        this.isScheduleModalOpen = true;
    }

    handleCloseScheduleModal() {
        this.isScheduleModalOpen = false;
    }
}
