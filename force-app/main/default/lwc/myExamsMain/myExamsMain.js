import { LightningElement, wire } from 'lwc';
import communityBasePath from '@salesforce/community/basePath';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';
import fetchEnrolledMyExams from '@salesforce/apex/KenExamEnrollmentController.fetchEnrolledMyExams';
import getMyHallTicketDownloadUrl from '@salesforce/apex/KenExamEnrollmentController.getMyHallTicketDownloadUrl';

const EXAM_ENROLMENT_ROUTE = 'my-exams/exam-enrolment';

const REQUEST_ROWS = [
    {
        id: 'rq-1',
        requestNo: '20240101',
        title: 'Network Analysis & Synthesis | ECE101',
        requestType: 'Re-evaluation',
        exam: 'End Semester Exam',
        format: 'Theory',
        statusDateLabel: 'Submitted on',
        statusDate: '09 Oct 2026',
        status: 'In Review',
        showFeedbackAction: false
    },
    {
        id: 'rq-2',
        requestNo: '20240101',
        title: 'Human Resource Management',
        requestType: 'Answer Sheet',
        exam: 'End Semester Exam',
        format: 'Theory',
        statusDateLabel: 'Closed on',
        statusDate: '12 Oct 2026',
        status: 'Closed',
        showFeedbackAction: true,
        attachmentName: 'answersheet.pdf'
    }
];

export default class MyExams extends LightningElement {
    activeTab = 'schedule';
    semesterValue = 'current-semester';
    currentSemesterValue = 'current-semester';
    currentSemesterLabel = 'Current Semester';
    enrollmentLastDate;
    organizationDefaults = {};
    scheduleRowsData = [];
    scheduleError;
    scheduleMessage;
    isScheduleLoading = true;
    hallTicketUrl;
    isHallTicketLoading = true;
    isDropdownOpen = false;
    isRaiseRequestModalOpen = false;
    isFeedbackModalOpen = false;
    showToast = false;
    toastMessage = '';
    toastVariant = 'info';
    selectedRequestType = 'Answer Sheet';
    selectedRating = 0;
    hoveredRating = 0;
    feedbackText = '';

    connectedCallback() {
        this.loadScheduleRows();
        this.loadHallTicketUrl();
    }

    get crumbs() {
        return [
            { label: 'Home',     pageName: 'Home' },
            { label: 'My Exams' }
        ];
    }

    get selectedSemesterLabel() {
        const match = this.semesterOptions.find((o) => o.value === this.semesterValue);
        return match ? match.label : '';
    }

    get selectedSemesterIsCurrent() {
        return this.semesterValue === this.currentSemesterValue;
    }

    get semesterOptionsForDropdown() {
        return this.semesterOptions;
    }

    get semesterOptions() {
        return [
            {
                label: this.currentSemesterLabel || 'Current Semester',
                value: this.currentSemesterValue || 'current-semester',
                isCurrent: true
            }
        ];
    }

    get bannerTitle() {
        return `${this.currentSemesterLabel || 'Current Semester'} Enrolment Open`;
    }

    get bannerDeadlineLabel() {
        const formattedDate = this.formatBannerDate(this.enrollmentLastDate);
        return formattedDate
            ? `Last date to enrol: ${formattedDate}`
            : 'Last date to enrol: -';
    }

    get scheduleTabClass() {
        return this.activeTab === 'schedule' ? 'tab-btn tab-active' : 'tab-btn';
    }

    get requestsTabClass() {
        return this.activeTab === 'requests' ? 'tab-btn tab-active' : 'tab-btn';
    }

    get isScheduleTab() {
        return this.activeTab === 'schedule';
    }

    get isRequestsTab() {
        return this.activeTab === 'requests';
    }

    get isAnswerSheetSelected() {
        return this.selectedRequestType === 'Answer Sheet';
    }

    get reEvaluationOptionClass() {
        return this.selectedRequestType === 'Re-evaluation'
            ? 'request-type-option request-type-option-active'
            : 'request-type-option';
    }

    get answerSheetOptionClass() {
        return this.selectedRequestType === 'Answer Sheet'
            ? 'request-type-option request-type-option-active'
            : 'request-type-option';
    }

    get activeRating() {
        return this.hoveredRating > 0 ? this.hoveredRating : this.selectedRating;
    }

    get starClass1() {
        return this.activeRating >= 1 ? 'star-btn star-active' : 'star-btn';
    }
    get starClass2() {
        return this.activeRating >= 2 ? 'star-btn star-active' : 'star-btn';
    }
    get starClass3() {
        return this.activeRating >= 3 ? 'star-btn star-active' : 'star-btn';
    }
    get starClass4() {
        return this.activeRating >= 4 ? 'star-btn star-active' : 'star-btn';
    }
    get starClass5() {
        return this.activeRating >= 5 ? 'star-btn star-active' : 'star-btn';
    }

    get ratingLabel() {
        const labels = { 1: 'Poor', 2: 'Fair', 3: 'Good', 4: 'Very Good', 5: 'Excellent' };
        return labels[this.activeRating] || '';
    }

    get scheduleRows() {
        return this.scheduleRowsData.map((item) => ({
            ...item,
            statusClass: 'status-pill status-approved'
        }));
    }

    get hasScheduleRows() {
        return this.scheduleRowsData.length > 0;
    }

    get requestRows() {
        return REQUEST_ROWS.map((item) => ({
            ...item,
            statusClass:
                item.status === 'Closed'
                    ? 'status-pill status-approved'
                    : 'status-pill status-review'
        }));
    }

    get hallTicketButtonLabel() {
        return this.isHallTicketLoading ? 'Loading...' : 'Download Hall Ticket';
    }

    get isHallTicketButtonDisabled() {
        return this.isHallTicketLoading;
    }

    async loadScheduleRows() {
        this.isScheduleLoading = true;
        this.scheduleError = undefined;
        this.scheduleMessage = undefined;

        try {
            const response = await fetchEnrolledMyExams();
            this.currentSemesterLabel =
                response?.currentSemesterLabel || 'Current Semester';
            this.currentSemesterValue =
                response?.currentSemesterValue || 'current-semester';
            this.enrollmentLastDate = response?.enrollmentLastDate;
            this.semesterValue = this.currentSemesterValue;
            this.scheduleRowsData = (response?.rows || []).map((row) => ({
                id: row.rowKey || row.personExaminationId,
                courseName: row.courseName || '-',
                courseCode: row.courseCode || '-',
                exam: row.exam || '-',
                credits: row.credits ?? '-',
                format: row.format || '-',
                type: row.type || '-',
                date: this.formatDate(row.examinationDateTime),
                time: this.formatTime(row.examinationDateTime),
                venue: row.venue || '',
                status: row.status || '-'
            }));

            if (!this.scheduleRowsData.length) {
                this.scheduleMessage =
                    response?.message || 'No enrolled examinations are available.';
            }
        } catch (error) {
            this.scheduleRowsData = [];
            this.scheduleError =
                error?.body?.message || error?.message || 'Unable to load my exams.';
        } finally {
            this.isScheduleLoading = false;
        }
    }

    async loadHallTicketUrl() {
        this.isHallTicketLoading = true;

        try {
            this.hallTicketUrl = await getMyHallTicketDownloadUrl();
        } catch (error) {
            this.hallTicketUrl = undefined;
        } finally {
            this.isHallTicketLoading = false;
        }
    }

    formatDate(value) {
        if (!value) {
            return '-';
        }
        return new Intl.DateTimeFormat('en-GB', {
            day: '2-digit',
            month: 'short',
            year: 'numeric'
        }).format(new Date(value));
    }

    formatTime(value) {
        if (!value) {
            return '-';
        }
        return new Intl.DateTimeFormat('en-US', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: true
        }).format(new Date(value));
    }

    formatBannerDate(value) {
        if (!value) {
            return '';
        }
        return new Intl.DateTimeFormat('en-GB', {
            day: '2-digit',
            month: 'short',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
            hour12: true
        }).format(new Date(value));
    }

    showScheduleTab() {
        this.activeTab = 'schedule';
    }

    showRequestsTab() {
        this.activeTab = 'requests';
    }

    handleDropdownToggle(event) {
        event.stopPropagation();
        this.isDropdownOpen = !this.isDropdownOpen;
    }

    handleOptionSelect(event) {
        event.stopPropagation();
        this.semesterValue = event.currentTarget.dataset.value;
        this.isDropdownOpen = false;
    }

    closeDropdown() {
        this.isDropdownOpen = false;
    }

    handleRequestCardClick(event) {
        if (event.target.closest('button')) return;
        const targetUrl = this.buildCommunityUrl('my-exams/request-details');
        window.open(targetUrl, '_self');
    }

    openRaiseRequestModal() {
        this.isRaiseRequestModalOpen = true;
    }

    closeRaiseRequestModal() {
        this.isRaiseRequestModalOpen = false;
    }

    handleRequestTypeSelect(event) {
        this.selectedRequestType = event.currentTarget?.dataset?.type || this.selectedRequestType;
    }

    proceedWithRequestType() {
        const targetUrl =
            this.selectedRequestType === 'Answer Sheet'
                ? this.buildCommunityUrl('my-exams/answersheet')
                : this.buildCommunityUrl('my-exams/enrolment');
        window.open(targetUrl, '_self');
    }

    handleEnrolNow() {
        const target = this.buildCommunityUrl(EXAM_ENROLMENT_ROUTE);
        window.open(target, '_self');
    }

    handleDownloadHallTicket() {
        if (this.isHallTicketLoading) {
            return;
        }

        if (!this.hallTicketUrl) {
            this.showToastMessage(
                'Your hall ticket is not generated yet. Please check again later.',
                'warning'
            );
            return;
        }

        window.open(this.hallTicketUrl, '_blank');
    }

    buildCommunityUrl(path = '') {
        const basePath = communityBasePath || '/';
        const sanitizedPath = path.replace(/^\/+|\/+$/g, '');

        if (basePath === '/') {
            return sanitizedPath ? `/${sanitizedPath}` : '/';
        }

        return sanitizedPath ? `${basePath}/${sanitizedPath}` : basePath;
    }

    applyOrganizationTheme() {
        if (!this.template?.host) return;
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
    wiredOrganizationDefaults({ data }) {
        if (data) {
            this.organizationDefaults = data;
            this.applyOrganizationTheme();
        }
    }

    stopModalClose(event) {
        event.stopPropagation();
    }

    openFeedbackModal() {
        this.isFeedbackModalOpen = true;
    }

    closeFeedbackModal() {
        this.isFeedbackModalOpen = false;
    }

    handleStarSelect(event) {
        const rating = Number(event.currentTarget?.dataset?.rating);
        this.selectedRating = Number.isFinite(rating) ? rating : this.selectedRating;
    }

    handleStarHover(event) {
        this.hoveredRating = Number(event.currentTarget?.dataset?.rating) || 0;
    }

    handleStarLeave() {
        this.hoveredRating = 0;
    }

    handleFeedbackTextChange(event) {
        this.feedbackText = event.target.value;
    }

    submitFeedback() {
        this.isFeedbackModalOpen = false;
    }

    showToastMessage(message, variant = 'info') {
        this.toastMessage = message;
        this.toastVariant = variant;
        this.showToast = true;
    }

    handleToastClose() {
        this.showToast = false;
    }
}