import { LightningElement, wire } from 'lwc';
import getLearnerPathwayItemsForAfterEnrollment from '@salesforce/apex/KenPortalCourseEnrollmentController.getLearnerPathwayItemsForAfterEnrollment';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';

export default class KenPortalAfterEnrollment extends LightningElement {
    loading = true;
    themeLoading = true;
    errorMessage = '';
    selectedSemester = null;
    academicSessionId = null;
    isScheduleModalOpen = false;
    organizationDefaults = {};

    applyOrganizationTheme() {
        const primary = this.organizationDefaults?.primary;
        const secondary = this.organizationDefaults?.secondary;

        if (primary && typeof primary === 'string') {
            this.template.host.style.setProperty('--primary-color', primary);
        }
        if (secondary && typeof secondary === 'string') {
            this.template.host.style.setProperty('--secondary-color', secondary);
        }
    }

    @wire(OrganizationDefaultsApiController)
    wiredOrganizationDefaults({ data, error }) {
        if (data) {
            this.organizationDefaults = data;
            this.applyOrganizationTheme();
            this.themeLoading = false;
        } else if (error) {
            console.error('Organization Defaults load error', error);
            this.organizationDefaults = {};
            this.themeLoading = false;
        }
    }

    get showSkeleton() {
        return this.loading || this.themeLoading;
    }

    tableColumns = [
        { key: 'courseName', label: 'Course Name' },
        { key: 'courseCode', label: 'Course Code' },
        { key: 'credits', label: 'Credits' },
        { key: 'type', label: 'All Types', showChevron: true },
        { key: 'faculty', label: 'Faculty' },
        { key: 'status', label: 'Enrolment Status' }
    ];

    pathwaySections = [];
    enrollmentSummary = {
        total: 0,
        approved: 0,
        rejected: 0,
        inReview: 0
    };

    connectedCallback() {
        const params = new URLSearchParams(window.location.search || '');
        const semesterParam = Number(params.get('semester'));
        this.selectedSemester = Number.isNaN(semesterParam) ? null : semesterParam;
        this.academicSessionId = params.get('academicSessionId') || null;
        this.loadEnrollmentDetails();
    }

    async loadEnrollmentDetails() {
        this.loading = true;
        this.errorMessage = '';
        try {
            const courses = await getLearnerPathwayItemsForAfterEnrollment({
                academicSessionId: this.academicSessionId
            });

            const sectionByTemplate = new Map();
            const summary = {
                total: 0,
                approved: 0,
                rejected: 0,
                inReview: 0
            };
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
                const statusKey = this.normalizeEnrollmentStatusKey(course.enrollmentStatus);
                summary.total += 1;
                if (statusKey === 'approved') {
                    summary.approved += 1;
                } else if (statusKey === 'rejected') {
                    summary.rejected += 1;
                } else {
                    summary.inReview += 1;
                }
                section.rows.push({
                    id: course.learningPathwayTemplateItemId || `${templateId}-${index}`,
                    courseName: course.courseName || '-',
                    courseCode: course.courseCode || '-',
                    credits,
                    type: rowType,
                    faculty: '-',
                    status: this.resolveEnrollmentStatus(course.enrollmentStatus),
                    statusClass: this.resolveEnrollmentStatusClass(course.enrollmentStatus)
                });
            });

            this.pathwaySections = Array.from(sectionByTemplate.values());
            this.enrollmentSummary = summary;
        } catch (error) {
            console.error('Failed to load after-enrollment details', error);
            this.errorMessage = error?.body?.message || error?.message || 'Failed to load enrollment details.';
            this.pathwaySections = [];
            this.enrollmentSummary = {
                total: 0,
                approved: 0,
                rejected: 0,
                inReview: 0
            };
        } finally {
            this.loading = false;
        }
    }

    get semesterHeading() {
        return this.selectedSemester ? `Semester ${this.selectedSemester}` : 'Semester';
    }

    resolveEnrollmentStatus(rawStatus) {
        const status = String(rawStatus || '').trim();
        return status || 'In Review';
    }

    normalizeEnrollmentStatusKey(rawStatus) {
        const normalized = String(rawStatus || '').trim().toLowerCase();
        if (normalized === 'approved') {
            return 'approved';
        }
        if (normalized === 'rejected') {
            return 'rejected';
        }
        return 'inreview';
    }

    resolveEnrollmentStatusClass(rawStatus) {
        const normalized = this.normalizeEnrollmentStatusKey(rawStatus);
        if (normalized === 'approved') {
            return 'status-pill status-pill-approved';
        }
        if (normalized === 'rejected') {
            return 'status-pill status-pill-rejected';
        }
        return 'status-pill status-pill-warning';
    }

    get bannerModel() {
        const total = Number(this.enrollmentSummary?.total || 0);
        const approved = Number(this.enrollmentSummary?.approved || 0);
        const rejected = Number(this.enrollmentSummary?.rejected || 0);

        if (total > 0 && approved === total) {
            return {
                title: 'Enrollment Approved!',
                description: 'The enrolment window is now closed. No further changes can be made.',
                pillLabel: 'Enrollment Closed',
                pillClass: 'status-pill status-pill-approved',
                bannerClass: 'status-banner status-banner-approved',
                iconClass: 'banner-icon banner-icon-approved',
                iconText: '✓',
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
                iconClass: 'banner-icon banner-icon-rejected',
                iconText: '×',
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
                iconClass: 'banner-icon banner-icon-warning',
                iconText: '!',
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
            iconClass: 'banner-icon banner-icon-warning',
            iconText: '!',
            showEditButton: true,
            editButtonLabel: 'Edit Enrollment',
            showViewScheduleButton: false
        };
    }

    get showViewScheduleButton() {
        return this.bannerModel.showViewScheduleButton;
    }

    get showEditButton() {
        return this.bannerModel.showEditButton;
    }

    get editButtonLabel() {
        return this.bannerModel.editButtonLabel;
    }

    handleEditEnrollment() {
        const sitePrefix = this.getSitePrefix();
        const targetPath = '/courseparticulardetails';
        const queryParts = [];
        if (this.selectedSemester) {
            queryParts.push(`semester=${encodeURIComponent(String(this.selectedSemester))}`);
        }
        if (this.academicSessionId) {
            queryParts.push(`academicSessionId=${encodeURIComponent(this.academicSessionId)}`);
        }
        queryParts.push('selectedPathwaysOnly=true');
        const query = queryParts.length ? `?${queryParts.join('&')}` : '';
        const targetUrl = `${sitePrefix}${targetPath}${query}`;
        window.location.assign(targetUrl);
    }

    getSitePrefix() {
        const path = window.location.pathname || '';
        const normalizedPath = path.replace(/\/+$/, '');
        const segments = normalizedPath.split('/').filter((segment) => Boolean(segment));
        if (!segments.length) {
            return '/s';
        }
        // Experience Cloud default pattern: /<domainPrefix>/s/<page>
        const sIndex = segments.indexOf('s');
        if (sIndex >= 0) {
            return `/${segments.slice(0, sIndex + 1).join('/')}`;
        }
        // Custom pattern: /<sitePrefix>/<page>
        return `/${segments[0]}`;
    }

    handleViewEnrollmentSchedule() {
        this.isScheduleModalOpen = true;
    }

    handleCloseScheduleModal() {
        this.isScheduleModalOpen = false;
    }
}