import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProgramPlansForOffering from '@salesforce/apex/KenCourseOfferingSplitController.getProgramPlansForOffering';
import getTimetableDetailData from '@salesforce/apex/KenTimetableManagementController.getTimetableDetailData';
import toggleTimetableLock from '@salesforce/apex/KenTimetableManagementController.toggleTimetableLock';

const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

function cloneDate(value) {
    return new Date(value.getFullYear(), value.getMonth(), value.getDate());
}

function parseDateOnlyValue(value) {
    if (!value) {
        return null;
    }
    if (value instanceof Date) {
        return cloneDate(value);
    }
    const parts = String(value).split('-').map((part) => Number(part));
    if (parts.length !== 3 || parts.some((part) => Number.isNaN(part))) {
        return null;
    }
    return new Date(parts[0], parts[1] - 1, parts[2]);
}

function toIsoDate(value) {
    return `${value.getFullYear()}-${String(value.getMonth() + 1).padStart(2, '0')}-${String(value.getDate()).padStart(2, '0')}`;
}

function startOfWeek(value) {
    const dateValue = cloneDate(value);
    const day = dateValue.getDay();
    const mondayOffset = day === 0 ? -6 : 1 - day;
    dateValue.setDate(dateValue.getDate() + mondayOffset);
    return dateValue;
}

function endOfWeek(value) {
    const dateValue = startOfWeek(value);
    dateValue.setDate(dateValue.getDate() + 6);
    return dateValue;
}

function rangesOverlap(rangeStart, rangeEnd, windowStart, windowEnd) {
    if (!rangeStart && !rangeEnd) {
        return true;
    }
    const effectiveStart = rangeStart || rangeEnd;
    const effectiveEnd = rangeEnd || rangeStart;
    return effectiveStart <= windowEnd && effectiveEnd >= windowStart;
}

function formatDateRange(startDate, endDate) {
    const sameMonth = startDate.getMonth() === endDate.getMonth() && startDate.getFullYear() === endDate.getFullYear();
    const sameYear = startDate.getFullYear() === endDate.getFullYear();
    const startOptions = sameMonth
        ? { month: 'short', day: 'numeric' }
        : { month: 'short', day: 'numeric', year: sameYear ? undefined : 'numeric' };
    const endOptions = { month: sameMonth ? undefined : 'short', day: 'numeric', year: 'numeric' };
    return `${new Intl.DateTimeFormat('en-US', startOptions).format(startDate)} - ${new Intl.DateTimeFormat('en-US', endOptions).format(endDate)}`;
}

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
    selectedPreviewDate = startOfWeek(new Date());
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
                startDateValue: parseDateOnlyValue(entry.startDate),
                endDateValue: parseDateOnlyValue(entry.endDate),
                key: `${entry.courseOfferingId}-${entry.dayName}-${entry.startTime}-${index}`,
                timeLabel: `${entry.dayName} ${formatTimeLabel(entry.startTime)}-${formatTimeLabel(entry.endTime)}`,
                courseLabel: entry.courseCode && data.courseName
                    ? `${entry.courseCode} - ${data.courseName}`
                    : (entry.courseCode || data.courseName || this.timetableName),
                status: 'Scheduled',
                statusClass: 'snapshot-badge scheduled'
            }));
            this.selectedPreviewDate = this.resolveInitialPreviewDate();
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
        const entries = this.visibleScheduleEntries;

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

                const previewSession = entries.find(
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

    get selectedWeekStartDate() {
        return startOfWeek(this.selectedPreviewDate);
    }

    get selectedWeekEndDate() {
        return endOfWeek(this.selectedPreviewDate);
    }

    get previewPeriodLabel() {
        if (this.showMonthlyPreview) {
            return new Intl.DateTimeFormat('en-US', { month: 'long', year: 'numeric' }).format(this.selectedPreviewDate);
        }
        return formatDateRange(this.selectedWeekStartDate, this.selectedWeekEndDate);
    }

    get previewPeriodControlLabel() {
        return this.showMonthlyPreview ? 'Month' : 'Week';
    }

    get previewPeriodInputValue() {
        return toIsoDate(this.selectedPreviewDate);
    }

    get previewCaption() {
        return this.showMonthlyPreview
            ? `Review sessions scheduled during ${this.previewPeriodLabel}.`
            : `Review sessions scheduled for ${this.previewPeriodLabel}.`;
    }

    get visibleScheduleEntries() {
        const windowStart = this.showMonthlyPreview
            ? new Date(this.selectedPreviewDate.getFullYear(), this.selectedPreviewDate.getMonth(), 1)
            : this.selectedWeekStartDate;
        const windowEnd = this.showMonthlyPreview
            ? new Date(this.selectedPreviewDate.getFullYear(), this.selectedPreviewDate.getMonth() + 1, 0)
            : this.selectedWeekEndDate;
        return this.scheduleEntries.filter((entry) =>
            rangesOverlap(entry.startDateValue, entry.endDateValue, windowStart, windowEnd)
        );
    }

    get monthlyPreviewDays() {
        const monthStart = new Date(this.selectedPreviewDate.getFullYear(), this.selectedPreviewDate.getMonth(), 1);
        const monthLength = new Date(this.selectedPreviewDate.getFullYear(), this.selectedPreviewDate.getMonth() + 1, 0).getDate();
        const entries = this.visibleScheduleEntries;
        return Array.from({ length: monthLength }, (_, index) => {
            const currentDate = new Date(monthStart);
            currentDate.setDate(index + 1);
            const weekdayLabel = currentDate.toLocaleDateString('en-US', { weekday: 'long' });
            const dayLabel = currentDate.toLocaleDateString('en-US', { weekday: 'short' });
            const sessions = entries
                .filter((entry) =>
                    entry.dayName === weekdayLabel &&
                    rangesOverlap(entry.startDateValue, entry.endDateValue, currentDate, currentDate)
                )
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

    handlePreviousPreviewPeriod() {
        this.shiftPreviewPeriod(-1);
    }

    handleNextPreviewPeriod() {
        this.shiftPreviewPeriod(1);
    }

    handlePreviewDateChange(event) {
        const selectedDate = parseDateOnlyValue(event.target.value);
        if (selectedDate) {
            this.selectedPreviewDate = selectedDate;
        }
    }

    shiftPreviewPeriod(direction) {
        const nextDate = cloneDate(this.selectedPreviewDate);
        if (this.showMonthlyPreview) {
            nextDate.setMonth(nextDate.getMonth() + direction, 1);
        } else {
            nextDate.setDate(nextDate.getDate() + (direction * 7));
        }
        this.selectedPreviewDate = nextDate;
    }

    resolveInitialPreviewDate() {
        const firstDatedEntry = this.scheduleEntries.find((entry) => entry.startDateValue || entry.endDateValue);
        if (firstDatedEntry) {
            return firstDatedEntry.startDateValue || firstDatedEntry.endDateValue;
        }
        return startOfWeek(new Date());
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
        return this.visibleScheduleEntries.map((entry, index) => ({
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