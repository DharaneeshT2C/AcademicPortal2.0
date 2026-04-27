import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveTerms from '@salesforce/apex/KenTimetableManagementController.getActiveTerms';
import getCourseOfferingsByTerm from '@salesforce/apex/KenTimetableManagementController.getCourseOfferingsByTerm';
import getProgramPlansForTerm from '@salesforce/apex/KenTimetableManagementController.getProgramPlansForTerm';
import getProgramPlanWeeklyPreview from '@salesforce/apex/KenTimetableManagementController.getProgramPlanWeeklyPreview';
import publishProgramPlanTimetable from '@salesforce/apex/KenTimetableManagementController.publishProgramPlanTimetable';
import getScheduleTemplateOptions from '@salesforce/apex/KenTimetableManagementController.getScheduleTemplateOptions';
import getScheduleTemplateOption from '@salesforce/apex/KenTimetableManagementController.getScheduleTemplateOption';
import getScheduleTemplateEntries from '@salesforce/apex/KenTimetableManagementController.getScheduleTemplateEntries';
import createScheduleTemplate from '@salesforce/apex/KenTimetableManagementController.createScheduleTemplate';
import getOrganizationDefaults from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';

const ALL_TERMS_VALUE = 'ALL';
const ALL_PAGE_SIZE_VALUE = 'ALL';
const DEFAULT_PAGE_SIZE = '10';
const WEEK_DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

const STATUS_CLASS_BY_VALUE = {
    Active: 'status-badge active',
    Inactive: 'status-badge inactive'
};

const TYPE_CLASS_BY_VALUE = {
    Lecture: 'type-badge constant',
    Lab: 'type-badge constant',
    Standard: 'type-badge constant'
};

function resolveTone(typeValue) {
    const normalizedValue = String(typeValue || '').toLowerCase();
    if (normalizedValue.includes('lab') || normalizedValue.includes('practical')) {
        return 'green';
    }
    if (normalizedValue.includes('tutorial')) {
        return 'amber';
    }
    if (normalizedValue.includes('seminar')) {
        return 'violet';
    }
    if (normalizedValue.includes('lecture') || normalizedValue.includes('theory')) {
        return 'blue';
    }
    return 'slate';
}

function resolveTypePillClass(typeValue) {
    return `grid-type-pill ${resolveTone(typeValue)}`;
}

export default class KenTimetableManagement extends NavigationMixin(LightningElement) {
    currentView = 'management';
    selectedManagementTab = 'offerings';
    selectedTimetable;
    builderAcademicTermId;
    builderCourseOfferingId;
    termOptions = [];
    allOfferings = [];
    previewProgramPlanRows = [];
    selectedPreviewTermId = '';
    selectedPreviewProgramPlanId = '';
    selectedPreviewOrientation = 'vertical';
    selectedPreviewStartDate = this.formatDateInput(new Date());
    selectedPreviewEndDate = this.formatDateInput(this.addDays(new Date(), 7));
    planPreviewData;
    templateOptions = [];
    selectedTermId = ALL_TERMS_VALUE;
    selectedStatus = 'ALL';
    selectedType = 'ALL';
    selectedOfferingType = 'ALL';
    selectedPageSize = DEFAULT_PAGE_SIZE;
    searchText = '';
    currentPage = 1;
    isLoading = true;
    isPlanPreviewLoading = false;
    isPublishingPlan = false;
    isTemplateSaving = false;
    isTemplateModalOpen = false;
    loadError;
    templateForm = this.createEmptyTemplateForm();

    @wire(getOrganizationDefaults)
    wiredOrganizationDefaults({ data, error }) {
        if (data) {
            this.applyThemeColor(data);
        } else if (error) {
            this.applyThemeColor({});
        }
    }

    @wire(getActiveTerms)
    wiredTerms({ data, error }) {
        if (data) {
            this.termOptions = [
                { label: 'All Terms', value: ALL_TERMS_VALUE },
                ...data.map((term) => ({
                    label: term.name,
                    value: term.id
                }))
            ];
            if (!this.selectedPreviewTermId && data.length) {
                this.selectedPreviewTermId = data[0].id;
                this.loadPreviewProgramPlans();
            }
            this.loadError = undefined;
            this.loadOfferings();
        } else if (error) {
            this.termOptions = [];
            this.allOfferings = [];
            this.loadError = this.normalizeError(error);
            this.isLoading = false;
        }
    }

    applyThemeColor(colors) {
        const primary = colors && colors.primaryForSf ? colors.primaryForSf : colors && colors.primary ? colors.primary : '#0b5ec0';
        const secondary = colors && colors.secondaryForSf ? colors.secondaryForSf : colors && colors.secondary ? colors.secondary : '#edf4fb';
        this.template.host.style.setProperty('--theme-primary', primary);
        this.template.host.style.setProperty('--theme-secondary', secondary);
    }

    async loadOfferings() {
        if (!this.termOptions.length) {
            this.allOfferings = [];
            this.isLoading = false;
            return;
        }

        this.isLoading = true;
        this.loadError = undefined;
        this.currentPage = 1;

        try {
            let offerings = [];

            if (this.selectedTermId === ALL_TERMS_VALUE) {
                const termIds = this.termOptions
                    .filter((option) => option.value !== ALL_TERMS_VALUE)
                    .map((option) => option.value);

                const results = await Promise.all(
                    termIds.map((termId) => getCourseOfferingsByTerm({ academicTermId: termId }))
                );

                offerings = results.flat();
            } else {
                offerings = await getCourseOfferingsByTerm({ academicTermId: this.selectedTermId });
            }

            this.allOfferings = offerings.map((item) => this.mapOffering(item));
            if (this.selectedType !== 'ALL' && !this.allOfferings.some((item) => item.type === this.selectedType)) {
                this.selectedType = 'ALL';
            }
            if (
                this.selectedOfferingType !== 'ALL' &&
                !this.allOfferings.some((item) => item.offeringType === this.selectedOfferingType)
            ) {
                this.selectedOfferingType = 'ALL';
            }
            if (!this.selectedTimetable && this.allOfferings.length) {
                this.selectedTimetable = this.allOfferings[0];
            }
        } catch (error) {
            this.allOfferings = [];
            this.loadError = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async loadPreviewProgramPlans() {
        if (!this.selectedPreviewTermId) {
            this.previewProgramPlanRows = [];
            this.selectedPreviewProgramPlanId = '';
            this.planPreviewData = undefined;
            return;
        }

        try {
            const rows = await getProgramPlansForTerm({ academicTermId: this.selectedPreviewTermId });
            this.previewProgramPlanRows = rows || [];
            if (!this.previewProgramPlanRows.some((item) => item.id === this.selectedPreviewProgramPlanId)) {
                this.selectedPreviewProgramPlanId = '';
            }
            if (this.selectedPreviewProgramPlanId) {
                await this.loadProgramPlanWeeklyPreview();
            } else {
                this.planPreviewData = undefined;
            }
        } catch (error) {
            this.previewProgramPlanRows = [];
            this.selectedPreviewProgramPlanId = '';
            this.planPreviewData = undefined;
        }
    }

    async loadProgramPlanWeeklyPreview() {
        if (!this.selectedPreviewTermId || !this.selectedPreviewProgramPlanId) {
            this.planPreviewData = undefined;
            return;
        }

        this.isPlanPreviewLoading = true;
        try {
            this.planPreviewData = await getProgramPlanWeeklyPreview({
                academicTermId: this.selectedPreviewTermId,
                learningProgramPlanId: this.selectedPreviewProgramPlanId
            });
        } catch (error) {
            this.planPreviewData = undefined;
            this.loadError = this.normalizeError(error);
        } finally {
            this.isPlanPreviewLoading = false;
        }
    }

    addDays(dateValue, days) {
        const date = this.parseDateValue(dateValue);
        date.setDate(date.getDate() + days);
        return date;
    }

    formatDateInput(dateValue) {
        const date = this.parseDateValue(dateValue);
        if (Number.isNaN(date.getTime())) {
            return '';
        }
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    parseDateValue(value) {
        if (value instanceof Date) {
            return new Date(value.getFullYear(), value.getMonth(), value.getDate());
        }
        const dateText = String(value || '');
        const match = dateText.match(/^(\d{4})-(\d{2})-(\d{2})$/);
        if (match) {
            return new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
        }
        return new Date(value);
    }

    createEmptyTemplateForm() {
        return {
            name: '',
            recurrencePattern: 'RRULE:FREQ=WEEKLY;INTERVAL=1',
            startDate: '',
            endDate: '',
            startTime: '',
            endTime: '',
            description: '',
            isMonday: false,
            isTuesday: false,
            isWednesday: false,
            isThursday: false,
            isFriday: false,
            isSaturday: false,
            isSunday: false
        };
    }

    async loadTemplateOptions() {
        try {
            this.templateOptions = await getScheduleTemplateOptions();
        } catch (error) {
            this.templateOptions = [];
        }
    }

    mapOffering(item) {
        const typeValue = item.type || 'Standard';
        const statusValue = item.status || 'Inactive';

        return {
            id: item.id,
            academicTermId: item.termId,
            name: item.name,
            term: item.termName,
            termName: item.termName,
            department: item.sessionName,
            sessionName: item.sessionName,
            courseName: item.courseName,
            courseCode: item.courseCode,
            offeringType: item.offeringType || 'Unspecified',
            version: item.courseCode || 'N/A',
            facultyName: item.facultyName || 'Unassigned',
            status: statusValue,
            statusClass: STATUS_CLASS_BY_VALUE[statusValue] || 'status-badge inactive',
            mode: typeValue,
            type: typeValue,
            typeClass: TYPE_CLASS_BY_VALUE[typeValue] || 'type-badge constant',
            lastUpdated: this.formatDate(item.lastUpdated),
            searchText: [
                item.name,
                item.termName,
                item.sessionName,
                item.courseName,
                item.courseCode,
                item.offeringType,
                item.facultyName,
                statusValue,
                typeValue
            ]
                .filter(Boolean)
                .join(' ')
                .toLowerCase()
        };
    }

    formatDate(value) {
        if (!value) {
            return 'N/A';
        }

        return new Intl.DateTimeFormat('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric'
        }).format(this.parseDateValue(value));
    }

    formatShortDate(value) {
        return new Intl.DateTimeFormat('en-US', {
            month: 'short',
            day: 'numeric'
        }).format(this.parseDateValue(value));
    }

    formatTemplateFrequency(value) {
        if (!value) {
            return 'Unspecified';
        }

        const normalized = value.replace(/^RRULE:/i, '');
        const parts = normalized.split(';').reduce((acc, part) => {
            const [key, partValue] = part.split('=');
            if (key && partValue) {
                acc[key.toUpperCase()] = partValue;
            }
            return acc;
        }, {});
        const frequency = parts.FREQ ? parts.FREQ.charAt(0) + parts.FREQ.slice(1).toLowerCase() : 'Recurring';
        const interval = parts.INTERVAL && parts.INTERVAL !== '1' ? ` every ${parts.INTERVAL}` : '';
        return `${frequency}${interval}`;
    }

    normalizeError(error) {
        const body = error && error.body;

        if (Array.isArray(body)) {
            return body.map((item) => item.message).join(', ');
        }

        return (body && body.message) || (error && error.message) || 'Unable to load timetable data.';
    }

    parseTime(value) {
        if (!value || !value.includes(':')) {
            return null;
        }
        const [hour, minute] = value.split(':').map((part) => Number(part));
        if (Number.isNaN(hour) || Number.isNaN(minute)) {
            return null;
        }
        return hour * 60 + minute;
    }

    formatTimeLabel(value) {
        const totalMinutes = this.parseTime(value);
        if (totalMinutes === null) {
            return value;
        }
        const hour = Math.floor(totalMinutes / 60);
        const minute = totalMinutes % 60;
        const suffix = hour >= 12 ? 'PM' : 'AM';
        const displayHour = hour % 12 || 12;
        return `${displayHour}:${String(minute).padStart(2, '0')} ${suffix}`;
    }

    calculateSlotSpan(entry) {
        const startMinutes = this.parseTime(entry.startTime);
        const endMinutes = this.parseTime(entry.endTime);
        if (startMinutes === null || endMinutes === null || endMinutes <= startMinutes) {
            return 1;
        }
        return Math.max(1, Math.ceil((endMinutes - startMinutes) / 30));
    }

    handleCreateTimetable() {
        this.builderAcademicTermId = this.selectedTermId !== ALL_TERMS_VALUE
            ? this.selectedTermId
            : null;
        this.builderCourseOfferingId = null;
        this.currentView = 'builder';
    }

    handleBackToManagement() {
        this.currentView = 'management';
    }

    handleManagementTabChange(event) {
        this.selectedManagementTab = event.currentTarget.dataset.tab;
        if (this.selectedManagementTab === 'templates') {
            this.loadTemplateOptions();
        }
    }

    handlePreview(event) {
        const { offeringId } = event.currentTarget.dataset;
        const selected = this.allOfferings.find((item) => item.id === offeringId);

        if (selected) {
            this.selectedTimetable = selected;
            this.currentView = 'detail';
        }
    }

    handleOpenBuilder(event) {
        const offeringId =
            (event && event.detail && event.detail.courseOfferingId) ||
            (event && event.currentTarget ? event.currentTarget.dataset.offeringId : null);
        const selected = offeringId ? this.allOfferings.find((item) => item.id === offeringId) : this.selectedTimetable;

        if (selected) {
            this.selectedTimetable = selected;
            this.builderAcademicTermId = selected.academicTermId;
            this.builderCourseOfferingId = selected.id;
        }
        this.currentView = 'builder';
    }

    async handleTermChange(event) {
        this.selectedTermId = event.target.value;
        await this.loadOfferings();
    }

    async handlePreviewTermChange(event) {
        this.selectedPreviewTermId = event.target.value || '';
        this.selectedPreviewProgramPlanId = '';
        this.planPreviewData = undefined;
        await this.loadPreviewProgramPlans();
    }

    async handlePreviewProgramPlanChange(event) {
        this.selectedPreviewProgramPlanId = event.target.value || '';
        await this.loadProgramPlanWeeklyPreview();
    }

    handlePreviewStartDateChange(event) {
        this.selectedPreviewStartDate = event.target.value || '';
        if (this.selectedPreviewStartDate) {
            this.selectedPreviewEndDate = this.formatDateInput(this.addDays(this.selectedPreviewStartDate, 7));
        }
    }

    handlePreviewEndDateChange(event) {
        this.selectedPreviewEndDate = event.target.value || '';
    }

    handlePreviewOrientationChange(event) {
        this.selectedPreviewOrientation = event.currentTarget.dataset.view || 'vertical';
    }

    handleStatusChange(event) {
        this.selectedStatus = event.target.value || 'ALL';
        this.currentPage = 1;
    }

    handleTypeChange(event) {
        this.selectedType = event.target.value || 'ALL';
        this.currentPage = 1;
    }

    handleOfferingTypeChange(event) {
        this.selectedOfferingType = event.target.value || 'ALL';
        this.currentPage = 1;
    }

    handleSearchInput(event) {
        const rawValue = event.target.value || '';
        this.searchText = rawValue.trim().toLowerCase();
        this.currentPage = 1;
    }

    handlePageSizeChange(event) {
        this.selectedPageSize = event.target.value || DEFAULT_PAGE_SIZE;
        this.currentPage = 1;
    }

    handlePreviousPage() {
        if (this.hasPreviousPage) {
            this.currentPage -= 1;
        }
    }

    handleNextPage() {
        if (this.hasNextPage) {
            this.currentPage += 1;
        }
    }

    handleDownloadWeeklySchedule() {
        if (this.disablePlanDownload) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Download unavailable',
                    message: 'Select a program plan with scheduled rows before downloading.',
                    variant: 'warning'
                })
            );
            return;
        }
        const url =
            `/apex/KenTimetableWeeklySchedulePdf` +
            `?academicTermId=${encodeURIComponent(this.selectedPreviewTermId)}` +
            `&programPlanId=${encodeURIComponent(this.selectedPreviewProgramPlanId)}` +
            `&viewMode=${encodeURIComponent(this.selectedPreviewOrientation)}` +
            `&startDate=${encodeURIComponent(this.selectedPreviewStartDate)}` +
            `&endDate=${encodeURIComponent(this.selectedPreviewEndDate)}`;
        const pdfWindow = window.open(url, '_blank');
        if (!pdfWindow) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'PDF export failed',
                    message: 'Unable to open the PDF. Allow pop-ups for this Salesforce page and try again.',
                    variant: 'error'
                })
            );
            return;
        }
    }

    async handlePublishWeeklySchedule() {
        if (this.disablePlanPublish) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Publish unavailable',
                    message: 'Select a program plan with scheduled rows before publishing.',
                    variant: 'warning'
                })
            );
            return;
        }

        this.isPublishingPlan = true;
        try {
            const result = await publishProgramPlanTimetable({
                academicTermId: this.selectedPreviewTermId,
                learningProgramPlanId: this.selectedPreviewProgramPlanId
            });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Weekly timetable published',
                    message: result && result.message ? result.message : 'Program plan timetable published.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Publish failed',
                    message: error && error.body && error.body.message ? error.body.message : 'Unable to publish the program plan timetable.',
                    variant: 'error'
                })
            );
        } finally {
            this.isPublishingPlan = false;
        }
    }

    handleTemplateFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.templateForm = {
            ...this.templateForm,
            [field]: value
        };
    }

    handleResetTemplateForm() {
        this.templateForm = this.createEmptyTemplateForm();
    }

    handleOpenTemplateModal() {
        this.templateForm = this.createEmptyTemplateForm();
        this.isTemplateModalOpen = true;
    }

    stopModalClose(event) {
        event.stopPropagation();
    }

    handleCloseTemplateModal() {
        if (this.isTemplateSaving) {
            return;
        }
        this.isTemplateModalOpen = false;
        this.templateForm = this.createEmptyTemplateForm();
    }

    async handleTemplateSelectionChange(event) {
        const templateId = event.target.value || '';
        if (!templateId) {
            return;
        }
        await this.handleCloneTemplate({ currentTarget: { dataset: { templateId } } });
    }

    async handleCloneTemplate(event) {
        const templateId = event.currentTarget.dataset.templateId;
        if (!templateId) {
            return;
        }

        try {
            const [template, entries] = await Promise.all([
                getScheduleTemplateOption({ templateId }),
                getScheduleTemplateEntries({ templateId, courseOfferingId: null })
            ]);

            const dayFlags = this.createEmptyTemplateForm();
            (entries || []).forEach((entry) => {
                if (entry && entry.dayName) {
                    dayFlags[`is${entry.dayName}`] = true;
                }
            });
            const firstEntry = (entries || [])[0] || {};

            this.templateForm = {
                ...this.createEmptyTemplateForm(),
                ...dayFlags,
                name: template && template.name ? `${template.name} Copy` : 'Cloned Template',
                recurrencePattern: (template && template.recurrencePattern) || 'RRULE:FREQ=WEEKLY;INTERVAL=1',
                startDate: (template && template.startDate) || '',
                endDate: (template && template.endDate) || '',
                startTime: firstEntry.startTime || '',
                endTime: firstEntry.endTime || '',
                description: template && template.name ? `Cloned from ${template.name}` : ''
            };
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Unable to clone template',
                    message: this.normalizeError(error),
                    variant: 'error'
                })
            );
        }
    }

    handleTemplateCardClick(event) {
        const templateId = event.currentTarget.dataset.templateId;
        if (!templateId) {
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: templateId,
                actionName: 'view'
            }
        });
    }

    async handleCreateTemplate() {
        if (this.disableTemplateSave) {
            return;
        }

        this.isTemplateSaving = true;
        try {
            const result = await createScheduleTemplate({ ...this.templateForm });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Template created',
                    message: result && result.message ? result.message : 'Schedule template created successfully.',
                    variant: 'success'
                })
            );
            this.templateForm = this.createEmptyTemplateForm();
            this.isTemplateModalOpen = false;
            await this.loadTemplateOptions();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Template creation failed',
                    message: this.normalizeError(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isTemplateSaving = false;
        }
    }

    get showManagement() {
        return this.currentView === 'management';
    }

    get showDetail() {
        return this.currentView === 'detail';
    }

    get showBuilder() {
        return this.currentView === 'builder';
    }

    get showOfferingsTab() {
        return this.selectedManagementTab === 'offerings';
    }

    get showWeeklyPlanTab() {
        return this.selectedManagementTab === 'weekly';
    }

    get showTemplatesTab() {
        return this.selectedManagementTab === 'templates';
    }

    get managementTabs() {
        return [
            {
                id: 'offerings',
                label: 'Course Offerings',
                className: this.selectedManagementTab === 'offerings' ? 'management-tab active' : 'management-tab'
            },
            {
                id: 'weekly',
                label: 'Program Plan Weekly View',
                className: this.selectedManagementTab === 'weekly' ? 'management-tab active' : 'management-tab'
            },
            {
                id: 'templates',
                label: 'Schedule Templates',
                className: this.selectedManagementTab === 'templates' ? 'management-tab active' : 'management-tab'
            }
        ];
    }

    get disableTemplateSave() {
        return this.isTemplateSaving ||
            !this.templateForm.name ||
            !this.templateForm.startTime ||
            !this.templateForm.endTime ||
            !this.hasActiveTemplateDay;
    }

    get hasActiveTemplateDay() {
        return WEEK_DAYS.some((day) => this.templateForm[`is${day}`]);
    }

    get templateDayOptions() {
        return WEEK_DAYS.map((day) => ({
            key: day,
            label: day,
            field: `is${day}`,
            checked: !!this.templateForm[`is${day}`]
        }));
    }

    get templateSummaryText() {
        return this.templateOptions.length
            ? `${this.templateOptions.length} existing template(s) available for reuse in the builder.`
            : 'No schedule templates created yet.';
    }

    get recentTemplateOptions() {
        return this.templateOptions || [];
    }

    get hasRecentTemplates() {
        return this.recentTemplateOptions.length > 0;
    }

    get templateCards() {
        return this.recentTemplateOptions.map((template, index) => ({
            ...template,
            key: template.id || `${template.name}-${index}`,
            initials: this.getTemplateInitials(template.name),
            meta: `Course Offering Schedule Template ${String(index + 1).padStart(2, '0')}`
        }));
    }

    get templateRows() {
        return this.recentTemplateOptions.map((template, index) => {
            const hasDateRange = !!(template.startDate || template.endDate);
            return {
                ...template,
                key: template.id || `${template.name}-${index}`,
                frequencyLabel: this.formatTemplateFrequency(template.recurrencePattern),
                startDateLabel: this.formatDate(template.startDate),
                endDateLabel: this.formatDate(template.endDate),
                statusLabel: hasDateRange ? 'Date Bounded' : 'Reusable',
                statusClass: hasDateRange ? 'status-badge active' : 'status-badge inactive'
            };
        });
    }

    get templateSelectOptions() {
        return [
            { label: 'Select Existing Template', value: '' },
            ...(this.templateOptions || []).map((template) => ({
                label: template.name,
                value: template.id
            }))
        ];
    }

    get filteredOfferings() {
        return this.allOfferings.filter((item) => {
            const effectiveSearch = this.searchText || '';
            const effectiveStatus = this.selectedStatus || 'ALL';
            const effectiveType = this.selectedType || 'ALL';
            const effectiveOfferingType = this.selectedOfferingType || 'ALL';

            const matchesSearch = !effectiveSearch || item.searchText.includes(effectiveSearch);
            const matchesStatus = effectiveStatus === 'ALL' || item.status === effectiveStatus;
            const matchesType = effectiveType === 'ALL' || item.type === effectiveType;
            const matchesOfferingType =
                effectiveOfferingType === 'ALL' || item.offeringType === effectiveOfferingType;

            return matchesSearch && matchesStatus && matchesType && matchesOfferingType;
        });
    }

    get totalOfferings() {
        return this.allOfferings.length;
    }

    get activeCount() {
        return this.allOfferings.filter((item) => item.status === 'Active').length;
    }

    get inactiveCount() {
        return this.allOfferings.filter((item) => item.status === 'Inactive').length;
    }

    get assignedFacultyCount() {
        return this.allOfferings.filter((item) => item.facultyName && item.facultyName !== 'Unassigned').length;
    }

    get dashboardEyebrow() {
        if (this.showWeeklyPlanTab) {
            return 'Weekly Snapshot';
        }
        if (this.showTemplatesTab) {
            return 'Template Overview';
        }
        return 'Term Overview';
    }

    get dashboardSummaryText() {
        if (this.showWeeklyPlanTab) {
            if (!this.selectedPreviewTermId) {
                return 'Select an academic term to review weekly timetable coverage.';
            }
            if (this.selectedPreviewPlanName) {
                return `Weekly timetable metrics for ${this.selectedPreviewPlanName}.`;
            }
            return `${this.previewProgramPlanRows.length} program plan(s) available in the selected term.`;
        }

        if (this.showTemplatesTab) {
            return this.templateOptions.length
                ? `${this.templateOptions.length} reusable course offering schedule template(s) are available.`
                : 'No course offering schedule templates have been created yet.';
        }

        if (!this.selectedTermLabel) {
            return 'No active terms available';
        }

        return `${this.totalOfferings} course offerings in ${this.selectedTermLabel}`;
    }

    get dashboardStats() {
        if (this.showWeeklyPlanTab) {
            return [
                this.buildDashboardStat('Total Program Plans', this.previewProgramPlanRows.length),
                this.buildDashboardStat(
                    'Selected Plan',
                    this.selectedPreviewPlanName || 'Not Selected',
                    '',
                    true
                ),
                this.buildDashboardStat(
                    'Scheduled Offerings',
                    this.planPreviewData ? this.planPreviewData.scheduledOfferingCount : 0,
                    'success'
                ),
                this.buildDashboardStat(
                    'Total Sessions',
                    this.planPreviewData ? this.planPreviewData.totalSessions : 0,
                    'danger'
                )
            ];
        }

        if (this.showTemplatesTab) {
            const recurringCount = (this.templateOptions || []).filter(
                (template) => template && template.recurrencePattern
            ).length;
            const datedCount = (this.templateOptions || []).filter(
                (template) => template && (template.startDate || template.endDate)
            ).length;

            return [
                this.buildDashboardStat('Total Templates', this.templateOptions.length),
                this.buildDashboardStat('Recurring Rules', recurringCount, 'success'),
                this.buildDashboardStat('Date Bounded', datedCount, 'warning'),
                this.buildDashboardStat('Ready To Reuse', this.templateOptions.length, 'danger')
            ];
        }

        return [
            this.buildDashboardStat('Total Course Offerings', this.totalOfferings),
            this.buildDashboardStat('Active', this.activeCount, 'success'),
            this.buildDashboardStat('Inactive', this.inactiveCount, 'warning'),
            this.buildDashboardStat('Faculty Assigned', this.assignedFacultyCount, 'danger')
        ];
    }

    get totalResultsLabel() {
        if (!this.filteredOfferings.length) {
            return `Showing 0 of ${this.allOfferings.length} course offerings`;
        }

        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end = Math.min(start + this.pageSize - 1, this.filteredOfferings.length);
        return `Showing ${start}-${end} of ${this.filteredOfferings.length} filtered course offerings`;
    }

    get selectedTermLabel() {
        const selectedTerm = this.termOptions.find((item) => item.value === this.selectedTermId);
        return selectedTerm ? selectedTerm.label : '';
    }

    get hasOfferings() {
        return this.filteredOfferings.length > 0;
    }

    get isEmptyState() {
        return !this.isLoading && !this.loadError && !this.hasOfferings;
    }

    get statusOptions() {
        return [
            { label: 'All Statuses', value: 'ALL' },
            { label: 'Active', value: 'Active' },
            { label: 'Inactive', value: 'Inactive' }
        ];
    }

    get typeOptions() {
        const values = [...new Set(this.allOfferings.map((item) => item.type).filter(Boolean))].sort();
        return [{ label: 'All Course Types', value: 'ALL' }, ...values.map((value) => ({ label: value, value }))];
    }

    get offeringTypeOptions() {
        const values = [...new Set(this.allOfferings.map((item) => item.offeringType).filter(Boolean))].sort();
        return [{ label: 'All Offering Types', value: 'ALL' }, ...values.map((value) => ({ label: value, value }))];
    }

    get paginatedOfferings() {
        if (this.selectedPageSize === ALL_PAGE_SIZE_VALUE) {
            return this.filteredOfferings;
        }

        const startIndex = (this.currentPage - 1) * this.pageSize;
        return this.filteredOfferings.slice(startIndex, startIndex + this.pageSize);
    }

    get totalPages() {
        if (this.selectedPageSize === ALL_PAGE_SIZE_VALUE) {
            return 1;
        }

        return Math.max(1, Math.ceil(this.filteredOfferings.length / this.pageSize));
    }

    get hasPreviousPage() {
        return this.currentPage > 1;
    }

    get hasNextPage() {
        return this.currentPage < this.totalPages;
    }

    get disablePreviousPage() {
        return !this.hasPreviousPage;
    }

    get disableNextPage() {
        return !this.hasNextPage;
    }

    get pageLabel() {
        return `Page ${this.currentPage} of ${this.totalPages}`;
    }

    get pageSize() {
        return this.selectedPageSize === ALL_PAGE_SIZE_VALUE ? this.filteredOfferings.length || 1 : Number(this.selectedPageSize);
    }

    get pageSizeOptions() {
        return [
            { label: '5', value: '5' },
            { label: '10', value: '10' },
            { label: '25', value: '25' },
            { label: 'All', value: ALL_PAGE_SIZE_VALUE }
        ];
    }

    get tableWrapClass() {
        return this.selectedPageSize === ALL_PAGE_SIZE_VALUE ? 'table-wrap scrollable' : 'table-wrap';
    }

    get previewTermOptions() {
        return this.termOptions.filter((option) => option.value !== ALL_TERMS_VALUE);
    }

    get previewProgramPlanOptions() {
        return [
            { label: 'Select Program Plan', value: '' },
            ...this.previewProgramPlanRows.map((item) => ({
                label: item.name,
                value: item.id
            }))
        ];
    }

    get previewScheduleEntries() {
        return this.planPreviewData && this.planPreviewData.scheduleEntries ? this.planPreviewData.scheduleEntries : [];
    }

    get previewTimeSlots() {
        return this.planPreviewData && this.planPreviewData.timeSlots ? this.planPreviewData.timeSlots : [];
    }

    get previewDateColumns() {
        const startDate = this.parseDateValue(this.selectedPreviewStartDate);
        const endDate = this.parseDateValue(this.selectedPreviewEndDate);
        if (!this.selectedPreviewStartDate || !this.selectedPreviewEndDate || Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime()) || endDate < startDate) {
            return WEEK_DAYS.map((day) => ({
                key: day,
                dayName: day,
                label: day
            }));
        }

        const columns = [];
        const cursor = new Date(startDate);
        while (cursor <= endDate && columns.length < 14) {
            const dayName = WEEK_DAYS[cursor.getDay() === 0 ? 6 : cursor.getDay() - 1];
            columns.push({
                key: this.formatDateInput(cursor),
                dayName,
                label: `${dayName} ${this.formatShortDate(cursor)}`
            });
            cursor.setDate(cursor.getDate() + 1);
        }
        return columns;
    }

    get hasPlanPreview() {
        return this.previewScheduleEntries.length > 0;
    }

    get selectedPreviewPlanName() {
        const row = this.previewProgramPlanRows.find((item) => item.id === this.selectedPreviewProgramPlanId);
        return row ? row.name : '';
    }

    get disablePlanDownload() {
        return !this.selectedPreviewProgramPlanId || !this.hasPlanPreview || this.isPlanPreviewLoading;
    }

    get disablePlanPublish() {
        return !this.selectedPreviewProgramPlanId || !this.hasPlanPreview || this.isPlanPreviewLoading || this.isPublishingPlan;
    }

    get previewOrientationTabs() {
        return [
            {
                id: 'vertical',
                label: 'Vertical',
                className:
                    this.selectedPreviewOrientation === 'vertical'
                        ? 'management-tab active'
                        : 'management-tab'
            }
        ];
    }

    get showVerticalPreview() {
        return true;
    }

    get weeklyPreviewSummary() {
        if (!this.selectedPreviewProgramPlanId) {
            return 'Select a term and program plan to load the weekly schedule.';
        }
        if (!this.hasPlanPreview) {
            return 'No scheduled course offerings found for the selected program plan.';
        }
        return `${this.planPreviewData.scheduledOfferingCount} course offering(s) and ${this.planPreviewData.totalSessions} scheduled row(s) loaded for ${this.previewDateRangeLabel}.`;
    }

    get previewDateRangeLabel() {
        return `${this.formatDate(this.selectedPreviewStartDate)} - ${this.formatDate(this.selectedPreviewEndDate)}`;
    }

    get weeklyPreviewRows() {
        const hiddenCellKeys = new Set();
        return this.previewTimeSlots.map((time, timeIndex) => ({
            time: this.formatTimeLabel(time),
            slots: this.previewDateColumns.map((column) => {
                const key = `${column.key}-${time}`;
                if (hiddenCellKeys.has(key)) {
                    return { key, render: false, hasEntry: false, rowSpan: 1 };
                }

                const previewSession = this.previewScheduleEntries.find(
                    (entry) => entry.dayName === column.dayName && entry.startTime === time
                );
                if (!previewSession) {
                    return { key, render: true, hasEntry: false, rowSpan: 1, cellClass: 'preview-cell' };
                }

                const requestedSpan = this.calculateSlotSpan(previewSession);
                const availableSpan = Math.max(1, this.previewTimeSlots.length - timeIndex);
                const rowSpan = Math.min(requestedSpan, availableSpan);
                for (let offset = 1; offset < rowSpan; offset += 1) {
                    hiddenCellKeys.add(`${column.key}-${this.previewTimeSlots[timeIndex + offset]}`);
                }

                return {
                    key,
                    render: true,
                    hasEntry: true,
                    rowSpan,
                    cellClass: 'grid-cell',
                    cellStyle: `--preview-row-span: ${rowSpan};`,
                    label: previewSession.courseCode || previewSession.courseName || 'Course',
                    type: previewSession.type || null,
                    faculty: previewSession.facultyName || null,
                    timeLabel: `${previewSession.startTime} - ${previewSession.endTime}`,
                    tone: resolveTone(previewSession.type),
                    typePillClass: resolveTypePillClass(previewSession.type)
                };
            })
        }));
    }

    get weeklyPreviewHorizontalHeaders() {
        return this.previewTimeSlots.map((time) => this.formatTimeLabel(time));
    }

    get weeklyPreviewHorizontalRows() {
        const hiddenCellKeys = new Set();
        return WEEK_DAYS.map((day) => ({
            day,
            slots: this.previewTimeSlots.map((time, timeIndex) => {
                const key = `${day}-${time}`;
                if (hiddenCellKeys.has(key)) {
                    return { key, render: false, hasEntry: false, colSpan: 1 };
                }

                const previewSession = this.previewScheduleEntries.find(
                    (entry) => entry.dayName === day && entry.startTime === time
                );
                if (!previewSession) {
                    return { key, render: true, hasEntry: false, colSpan: 1, cellClass: 'preview-cell' };
                }

                const requestedSpan = this.calculateSlotSpan(previewSession);
                const availableSpan = Math.max(1, this.previewTimeSlots.length - timeIndex);
                const colSpan = Math.min(requestedSpan, availableSpan);
                for (let offset = 1; offset < colSpan; offset += 1) {
                    hiddenCellKeys.add(`${day}-${this.previewTimeSlots[timeIndex + offset]}`);
                }

                return {
                    key,
                    render: true,
                    hasEntry: true,
                    colSpan,
                    cellClass: 'grid-cell',
                    cellStyle: `--preview-col-span: ${colSpan};`,
                    label: previewSession.courseCode || previewSession.courseName || 'Course',
                    type: previewSession.type || null,
                    faculty: previewSession.facultyName || null,
                    timeLabel: `${previewSession.startTime} - ${previewSession.endTime}`,
                    tone: resolveTone(previewSession.type),
                    typePillClass: resolveTypePillClass(previewSession.type)
                };
            })
        }));
    }

    getTemplateInitials(name) {
        const words = String(name || 'Template')
            .trim()
            .split(/\s+/)
            .filter(Boolean)
            .slice(0, 2);
        if (!words.length) {
            return 'CT';
        }
        return words.map((word) => word.charAt(0).toUpperCase()).join('');
    }

    buildDashboardStat(label, value, tone = '', compact = false) {
        const classNames = ['stat-value'];
        if (tone) {
            classNames.push(tone);
        }
        if (compact) {
            classNames.push('stat-value-compact');
        }
        return {
            label,
            value,
            className: classNames.join(' ')
        };
    }
}