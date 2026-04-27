import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProgramPlansForOffering from '@salesforce/apex/KenCourseOfferingSplitController.getProgramPlansForOffering';
import getTimetableDetailData from '@salesforce/apex/KenTimetableManagementController.getTimetableDetailData';
import toggleTimetableLock from '@salesforce/apex/KenTimetableManagementController.toggleTimetableLock';

const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

function resolveTone(typeValue) {
    const normalized = String(typeValue || '').trim().toLowerCase();
    if (normalized.includes('lab') || normalized.includes('practical')) {
        return 'green';
    }
    if (normalized.includes('tutorial')) {
        return 'amber';
    }
    if (normalized.includes('seminar')) {
        return 'violet';
    }
    if (normalized.includes('lecture') || normalized.includes('theory')) {
        return 'blue';
    }
    return 'slate';
}

function resolveTypePillClass(typeValue) {
    return `grid-type-pill ${resolveTone(typeValue)}`;
}

function parseTime(value) {
    if (!value || !value.includes(':')) {
        return null;
    }
    const [hour, minute] = value.split(':').map((part) => Number(part));
    if (Number.isNaN(hour) || Number.isNaN(minute)) {
        return null;
    }
    return hour * 60 + minute;
}

function formatTimeLabel(value) {
    const totalMinutes = parseTime(value);
    if (totalMinutes === null) {
        return value;
    }
    const hour = Math.floor(totalMinutes / 60);
    const minute = totalMinutes % 60;
    const suffix = hour >= 12 ? 'PM' : 'AM';
    const displayHour = hour % 12 || 12;
    return `${displayHour}:${String(minute).padStart(2, '0')} ${suffix}`;
}

function formatDateTime(value) {
    if (!value) {
        return 'N/A';
    }
    return new Intl.DateTimeFormat('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric',
        hour: 'numeric',
        minute: '2-digit'
    }).format(new Date(value));
}

function formatDateOnly(value) {
    if (!value) {
        return 'N/A';
    }
    return new Intl.DateTimeFormat('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric'
    }).format(new Date(value));
}

function formatVersionLabel(versionValue) {
    const versionNumber = Number(versionValue);
    return Number.isFinite(versionNumber) && versionNumber > 0 ? `v${versionNumber}.0` : 'v1.0';
}

function calculateSlotSpan(entry) {
    const startMinutes = parseTime(entry.startTime);
    const endMinutes = parseTime(entry.endTime);
    if (startMinutes === null || endMinutes === null || endMinutes <= startMinutes) {
        return 1;
    }

    return Math.max(1, Math.ceil((endMinutes - startMinutes) / 30));
}

export default class KenTimetableDetail extends LightningElement {
    _courseOfferingId;

    @api timetableName = 'Timetable';
    @api term = '';
    @api department = '';
    @api version = 'N/A';
    @api status = 'Draft';
    @api mode = 'Manual';
    @api lastUpdated = 'N/A';

    days = DAYS;
    times = [];
    scheduleEntries = [];
    programPlanRows = [];
    selectedProgramPlanId = 'ALL';
    selectedEnrollmentType = 'ALL';
    activePreviewMode = 'weekly';
    detailData;
    loadError;
    isActing = false;

    @api
    get courseOfferingId() {
        return this._courseOfferingId;
    }

    set courseOfferingId(value) {
        this._courseOfferingId = value;
        if (value) {
            this.loadPreviewData();
        }
    }

    @wire(getProgramPlansForOffering, { courseOfferingId: '$_courseOfferingId' })
    wiredProgramPlans({ data, error }) {
        if (data) {
            this.programPlanRows = data;
            if (
                this.selectedProgramPlanId !== 'ALL' &&
                !this.programPlanRows.some((item) => item.id === this.selectedProgramPlanId)
            ) {
                this.selectedProgramPlanId = 'ALL';
            }
            if (
                this.selectedEnrollmentType !== 'ALL' &&
                !this.enrollmentTypeValues.includes(this.selectedEnrollmentType)
            ) {
                this.selectedEnrollmentType = 'ALL';
            }
        } else if (error) {
            this.programPlanRows = [];
        }
    }

    async loadPreviewData() {
        if (!this._courseOfferingId) {
            return;
        }

        try {
            const data = await getTimetableDetailData({ courseOfferingId: this._courseOfferingId });
            this.detailData = data;
            this.scheduleEntries = (data.scheduleEntries || []).map((entry, index) => ({
                ...entry,
                key: `${entry.courseOfferingId}-${entry.dayName}-${entry.startTime}-${index}`,
                timeLabel: `${entry.dayName} ${formatTimeLabel(entry.startTime)}-${formatTimeLabel(entry.endTime)}`,
                courseLabel: entry.courseCode && data.courseName
                    ? `${entry.courseCode} - ${data.courseName}`
                    : (entry.courseCode || data.courseName || this.timetableName),
                status: 'Scheduled',
                statusClass: 'snapshot-badge scheduled'
            }));
            this.times = data.timeSlots || [];
            this.loadError = undefined;
        } catch (error) {
            this.detailData = undefined;
            this.scheduleEntries = [];
            this.times = [];
            const body = error && error.body;
            this.loadError = (body && body.message) || error.message || 'Unable to load timetable preview.';
        }
    }

    get subtitle() {
        const versionLabel = this.detailData && this.detailData.timetableVersion
            ? `Version ${formatVersionLabel(this.detailData.timetableVersion)}`
            : `Version ${this.version}`;
        return `${this.term} • ${this.department} • ${versionLabel}`;
    }

    get statusClass() {
        return 'header-badge neutral';
    }

    get modeClass() {
        const isLocked = this.detailData ? this.detailData.timetableLocked : false;
        return isLocked ? 'header-badge automatic' : 'header-badge neutral';
    }

    get statusLabel() {
        return 'Preview';
    }

    get modeLabel() {
        return this.detailData && this.detailData.timetableLocked ? 'Locked' : 'Unlocked';
    }

    get previewRows() {
        const hiddenCellKeys = new Set();

        return this.times.map((time, timeIndex) => ({
            time: formatTimeLabel(time),
            slots: this.days.map((day) => {
                const key = `${day}-${time}`;
                if (hiddenCellKeys.has(key)) {
                    return {
                        key,
                        render: false,
                        hasEntry: false,
                        rowSpan: 1
                    };
                }

                const previewSession = this.scheduleEntries.find(
                    (entry) => entry.dayName === day && entry.startTime === time
                );
                if (!previewSession) {
                    return {
                        key,
                        render: true,
                        hasEntry: false,
                        rowSpan: 1,
                        cellClass: 'preview-cell'
                    };
                }

                const requestedSpan = calculateSlotSpan(previewSession);
                const availableSpan = Math.max(1, this.times.length - timeIndex);
                const rowSpan = Math.min(requestedSpan, availableSpan);
                for (let offset = 1; offset < rowSpan; offset += 1) {
                    hiddenCellKeys.add(`${day}-${this.times[timeIndex + offset]}`);
                }

                return {
                    key,
                    render: true,
                    hasEntry: true,
                    rowSpan,
                    tone: resolveTone(previewSession.type),
                    cellClass: 'grid-cell',
                    cellStyle: `--preview-row-span: ${rowSpan};`,
                    label: previewSession.courseCode || (this.detailData && this.detailData.courseCode) || this.timetableName,
                    faculty: previewSession.facultyName || (this.detailData && this.detailData.facultyName) || null,
                    type: previewSession.type || (this.detailData && this.detailData.type) || null,
                    timeLabel: `${formatTimeLabel(previewSession.startTime)} - ${formatTimeLabel(previewSession.endTime)}`,
                    typePillClass: resolveTypePillClass(previewSession.type || (this.detailData && this.detailData.type))
                };
            })
        }));
    }

    get previewModes() {
        return [
            {
                id: 'weekly',
                label: 'Weekly',
                className: this.activePreviewMode === 'weekly' ? 'tab active' : 'tab'
            },
            {
                id: 'monthly',
                label: 'Monthly',
                className: this.activePreviewMode === 'monthly' ? 'tab active' : 'tab'
            }
        ];
    }

    get showWeeklyPreview() {
        return this.activePreviewMode === 'weekly';
    }

    get showMonthlyPreview() {
        return this.activePreviewMode === 'monthly';
    }

    get monthlyPreviewDays() {
        const today = new Date();
        return Array.from({ length: 30 }, (_, index) => {
            const currentDate = new Date(today);
            currentDate.setDate(today.getDate() + index);
            const weekdayLabel = currentDate.toLocaleDateString('en-US', { weekday: 'long' });
            const dayLabel = currentDate.toLocaleDateString('en-US', { weekday: 'short' });
            const sessions = this.scheduleEntries
                .filter((entry) => entry.dayName === weekdayLabel)
                .map((entry) => `${entry.courseCode || (this.detailData && this.detailData.courseCode)} ${formatTimeLabel(entry.startTime)}`);
            return {
                key: `month-day-${currentDate.toISOString()}`,
                dayNumber: currentDate.getDate(),
                dayLabel,
                sessions,
                className: sessions.length ? 'month-cell filled' : 'month-cell'
            };
        });
    }

    get totalSessions() {
        return this.detailData ? this.detailData.totalSessions : 0;
    }

    get assignedRooms() {
        return this.detailData ? this.detailData.assignedRooms : 0;
    }

    get facultyAssigned() {
        return this.detailData ? this.detailData.facultyAssigned : 0;
    }

    get conflictCount() {
        return this.detailData ? this.detailData.conflictCount : 0;
    }

    get conflictCountClass() {
        return this.conflictCount === 0 ? 'metric-value success' : 'metric-value danger';
    }

    get hasSessionSnapshot() {
        return this.sessionSnapshot.length > 0;
    }

    get activityItems() {
        const items = [];
        if (this.detailData && this.detailData.lastModifiedDate) {
            items.push({
                id: 'updated',
                title: 'Updated',
                description: `${this.totalSessions} schedule row(s) currently mapped to this course offering.`,
                meta: `${this.detailData.lastModifiedByName || 'System'} • ${formatDateTime(this.detailData.lastModifiedDate)}`
            });
        }
        if (this.detailData && this.detailData.createdDate) {
            items.push({
                id: 'created',
                title: 'Created',
                description: 'Course offering timetable record opened in preview.',
                meta: `${this.detailData.createdByName || 'System'} • ${formatDateTime(this.detailData.createdDate)}`
            });
        }
        return items;
    }

    get createdByLabel() {
        return this.detailData && this.detailData.createdByName ? this.detailData.createdByName : '-';
    }

    get lastUpdatedLabel() {
        return this.detailData && this.detailData.lastModifiedDate
            ? formatDateOnly(this.detailData.lastModifiedDate)
            : this.lastUpdated;
    }

    get cohortCountLabel() {
        return this.detailData ? this.detailData.cohortCount : 0;
    }

    get lockButtonLabel() {
        return this.detailData && this.detailData.timetableLocked ? 'Unlock' : 'Lock';
    }

    get versionButtonLabel() {
        const versionValue = this.detailData && this.detailData.timetableVersion
            ? formatVersionLabel(this.detailData.timetableVersion)
            : this.version;
        return `Version ${versionValue}`;
    }

    get programPlanOptions() {
        return [
            { label: 'All Program Plans', value: 'ALL' },
            ...this.programPlanRows.map((item) => ({
                label: item.name,
                value: item.id
            }))
        ];
    }

    get enrollmentTypeValues() {
        return [...new Set(this.programPlanRows.map((item) => item.enrollmentType).filter(Boolean))].sort();
    }

    get enrollmentTypeOptions() {
        return [
            { label: 'All Enrollment Types', value: 'ALL' },
            ...this.enrollmentTypeValues.map((item) => ({
                label: item,
                value: item
            }))
        ];
    }

    handleProgramPlanChange(event) {
        this.selectedProgramPlanId = event.target.value;
        if (
            this.selectedEnrollmentType !== 'ALL' &&
            !this.filteredProgramPlans.some((item) => item.enrollmentType === this.selectedEnrollmentType)
        ) {
            this.selectedEnrollmentType = 'ALL';
        }
    }

    handleEnrollmentTypeChange(event) {
        this.selectedEnrollmentType = event.target.value;
    }

    handlePreviewModeChange(event) {
        this.activePreviewMode = event.currentTarget.dataset.mode;
    }

    get filteredProgramPlans() {
        return this.programPlanRows.filter((item) => {
            const matchesPlan = this.selectedProgramPlanId === 'ALL' || item.id === this.selectedProgramPlanId;
            const matchesType =
                this.selectedEnrollmentType === 'ALL' || item.enrollmentType === this.selectedEnrollmentType;
            return matchesPlan && matchesType;
        });
    }

    get sessionSnapshot() {
        const fallbackCourseName = (this.detailData && this.detailData.courseName) || this.timetableName;
        return this.scheduleEntries.map((entry, index) => ({
            id: entry.key || `${entry.courseOfferingId}-${entry.dayName}-${entry.startTime}-${index}`,
            course: entry.courseCode && entry.courseName
                ? `${entry.courseCode} - ${entry.courseName}`
                : (entry.courseCode || entry.courseName || fallbackCourseName),
            type: entry.type || (this.detailData && this.detailData.type) || '-',
            faculty: entry.facultyName || (this.detailData && this.detailData.facultyName) || '-',
            room: entry.room || '-',
            time: `${entry.dayName} ${formatTimeLabel(entry.startTime)}-${formatTimeLabel(entry.endTime)}`,
            status: 'Scheduled',
            statusClass: 'snapshot-badge scheduled'
        }));
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleOpenBuilder() {
        this.dispatchEvent(
            new CustomEvent('openbuilder', {
                detail: {
                    courseOfferingId: this._courseOfferingId
                }
            })
        );
    }

    async handleToggleLock() {
        await this.runAction(toggleTimetableLock, { courseOfferingId: this._courseOfferingId });
    }

    async runAction(actionMethod, params) {
        this.isActing = true;
        try {
            const result = await actionMethod(params);
            if (result && result.detail) {
                this.detailData = result.detail;
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Timetable updated',
                    message: result && result.message ? result.message : 'Action completed.',
                    variant: 'success'
                })
            );
            await this.loadPreviewData();
        } catch (error) {
            const body = error && error.body;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Action failed',
                    message: (body && body.message) || error.message || 'Unable to update timetable.',
                    variant: 'error'
                })
            );
        } finally {
            this.isActing = false;
        }
    }
}