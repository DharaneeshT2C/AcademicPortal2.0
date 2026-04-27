import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveTerms from '@salesforce/apex/KenTimetableManagementController.getActiveTerms';
import getLocationOptions from '@salesforce/apex/KenTimetableManagementController.getLocationOptions';
import getScheduleTemplateEntries from '@salesforce/apex/KenTimetableManagementController.getScheduleTemplateEntries';
import getScheduleTemplateOptions from '@salesforce/apex/KenTimetableManagementController.getScheduleTemplateOptions';
import getTimetableBuilderData from '@salesforce/apex/KenTimetableManagementController.getTimetableBuilderData';
import saveCourseOfferingSchedules from '@salesforce/apex/KenTimetableManagementController.saveCourseOfferingSchedules';

const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const TYPE_TONE = {
    Lecture: 'blue',
    Theory: 'blue',
    Lab: 'green',
    Practical: 'green',
    Tutorial: 'amber',
    Seminar: 'violet',
    Standard: 'slate'
};

function resolveTone(typeValue) {
    const normalized = (typeValue || '').trim().toLowerCase();
    if (!normalized) {
        return TYPE_TONE.Standard;
    }
    if (normalized.includes('lecture') || normalized.includes('theory')) {
        return TYPE_TONE.Lecture;
    }
    if (normalized.includes('lab') || normalized.includes('practical')) {
        return TYPE_TONE.Lab;
    }
    if (normalized.includes('tutorial')) {
        return TYPE_TONE.Tutorial;
    }
    if (normalized.includes('seminar')) {
        return TYPE_TONE.Seminar;
    }
    return TYPE_TONE[typeValue] || TYPE_TONE.Standard;
}

function resolveTypePillClass(typeValue) {
    return `grid-type-pill ${resolveTone(typeValue)}`;
}

function mapEnrollmentTypeByPlan(tokens = []) {
    return tokens.reduce((acc, token) => {
        if (!token || !token.includes('|')) {
            return acc;
        }
        const [planId, enrollmentType] = token.split('|');
        if (planId) {
            acc[planId] = enrollmentType || 'core';
        }
        return acc;
    }, {});
}

function isElectiveEnrollmentType(value) {
    return (value || '').trim().toLowerCase() === 'elective';
}

function getElectivePlanIds(tokens = []) {
    return tokens
        .filter((t) => {
            if (!t || !t.includes('|')) return false;
            const [, enrollmentType] = t.split('|');
            return isElectiveEnrollmentType(enrollmentType);
        })
        .map((t) => t.split('|')[0]);
}

function shouldBlockOverlap(planTokensOne = [], planTokensTwo = []) {
    if (!planTokensOne.length || !planTokensTwo.length) {
        return true;
    }

    const leftByPlan = mapEnrollmentTypeByPlan(planTokensOne);
    const rightByPlan = mapEnrollmentTypeByPlan(planTokensTwo);
    return Object.keys(leftByPlan).some((planId) => {
        if (!Object.prototype.hasOwnProperty.call(rightByPlan, planId)) {
            return false;
        }
        return !isElectiveEnrollmentType(leftByPlan[planId]) || !isElectiveEnrollmentType(rightByPlan[planId]);
    });
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

function defaultEndTime(startTime) {
    const startMinutes = parseTime(startTime) ?? 8 * 60;
    const endMinutes = Math.min(startMinutes + 60, 23 * 60 + 30);
    const hours = String(Math.floor(endMinutes / 60)).padStart(2, '0');
    const minutes = String(endMinutes % 60).padStart(2, '0');
    return `${hours}:${minutes}`;
}

function cloneDraft(entry = {}) {
    return {
        id: entry.id
            ? `${entry.id}-${entry.dayName || 'day'}-${entry.startTime || 'time'}`
            : `${Date.now()}-${Math.random().toString(16).slice(2)}`,
        scheduleId: entry.id || entry.scheduleId || null,
        dayName: entry.dayName || 'Sunday',
        startTime: entry.startTime || '08:00',
        endTime: entry.endTime || defaultEndTime(entry.startTime || '08:00'),
        room: entry.room || '',
        source: entry.source || 'Manual',
        rowError: ''
    };
}

function createEntryKey(entry, index = 0) {
    return `${entry.courseOfferingId}-${entry.dayName}-${entry.startTime}-${index}`;
}

function calculateSlotSpan(entry) {
    const startMinutes = parseTime(entry.startTime);
    const endMinutes = parseTime(entry.endTime);
    if (startMinutes === null || endMinutes === null || endMinutes <= startMinutes) {
        return 1;
    }

    return Math.max(1, Math.ceil((endMinutes - startMinutes) / 30));
}

export default class KenTimetableBuilder extends LightningElement {
    @api academicTermId;
    @api courseOfferingId;
    @api programPlanId;

    days = DAYS;
    termOptions = [];
    programPlanOptions = [];
    roomOptions = [{ label: 'No room selected', value: '' }];
    scheduleTemplateOptions = [];
    selectedAcademicTermId;
    selectedProgramPlanId = '';
    academicTermName = '';
    offerings = [];
    scheduledEntries = [];
    timeSlots = [];
    validation = { warnings: [], conflicts: [], suggestions: [] };

    isLoading = true;
    isSaving = false;
    loadError;
    draggedOfferingId;
    activeDropKey;

    isEditorOpen = false;
    editorOfferingId;
    editorDrafts = [];
    editorSeedSlot;
    editorTemplateId;
    editorTemplateName;
    editorTemplateRecurrencePattern = '';
    editorTemplateStartDate = '';
    editorTemplateEndDate = '';

    connectedCallback() {
        this.initializeBuilder();
    }

    async initializeBuilder() {
        this.isLoading = true;
        this.loadError = undefined;

        try {
            const [terms, templates, locations] = await Promise.all([
                getActiveTerms(),
                getScheduleTemplateOptions(),
                getLocationOptions()
            ]);
            this.termOptions = (terms || []).map((term) => ({
                label: term.name,
                value: term.id
            }));
            this.roomOptions = [
                { label: 'No room selected', value: '' },
                ...(locations || []).map((location) => ({
                    label: location.name,
                    value: location.id
                }))
            ];
            this.scheduleTemplateOptions = (templates || []).map((template) => ({
                label: template.name,
                value: template.id,
                recurrencePattern: template.recurrencePattern || '',
                startDate: template.startDate || '',
                endDate: template.endDate || ''
            }));
            this.selectedAcademicTermId = this.academicTermId || (this.termOptions.length ? this.termOptions[0].value : null);
            this.academicTermId = this.selectedAcademicTermId;
            await this.loadBuilderData();
        } catch (error) {
            this.loadError = this.normalizeError(error);
            this.isLoading = false;
        }
    }

    async loadBuilderData() {
        this.isLoading = true;
        this.loadError = undefined;

        try {
            const payload = await getTimetableBuilderData({
                academicTermId: this.selectedAcademicTermId || this.academicTermId || null,
                focusCourseOfferingId: this.courseOfferingId || null,
                learningProgramPlanId: this.selectedProgramPlanId || this.programPlanId || null
            });

            this.offerings = (payload.offerings || []).map((offering) => ({
                ...offering,
                planEnrollmentTokens: offering.planEnrollmentTokens || [],
                tone: resolveTone(offering.type),
                isDraggable: !offering.timetableLocked,
                lockLabel: offering.timetableLocked ? 'Locked' : null,
                hasTemplateEntries: !!(offering.templateEntries || []).length,
                templateRecurrencePattern: offering.templateRecurrencePattern || '',
                templateEntries: (offering.templateEntries || []).map((entry, index) => ({
                    ...entry,
                    entryKey: `${offering.id}-template-${entry.dayName}-${entry.startTime}-${index}`,
                    roomLabel: this.resolveRoomLabel(entry.room, entry.roomName),
                    tone: resolveTone(offering.type),
                    typePillClass: resolveTypePillClass(offering.type)
                }))
            }));
            this.scheduledEntries = (payload.scheduledEntries || []).map((entry, index) => ({
                ...entry,
                planEnrollmentTokens: entry.planEnrollmentTokens || [],
                entryKey: createEntryKey(entry, index),
                roomLabel: this.resolveRoomLabel(entry.room, entry.roomName),
                tone: resolveTone(entry.type),
                typePillClass: resolveTypePillClass(entry.type)
            }));
            this.timeSlots = payload.timeSlots || [];
            this.validation = payload.validation || { warnings: [], conflicts: [], suggestions: [] };
            this.academicTermId = payload.academicTermId || this.academicTermId;
            this.selectedAcademicTermId = this.academicTermId;
            this.academicTermName = payload.academicTermName || '';
            this.courseOfferingId = payload.focusCourseOfferingId || this.courseOfferingId;
            this.programPlanOptions = [
                { label: 'All Program Plans', value: '' },
                ...((payload.programPlanOptions || []).map((plan) => ({
                    label: plan.name,
                    value: plan.id
                })))
            ];
            this.selectedProgramPlanId = payload.selectedProgramPlanId || '';
            this.programPlanId = this.selectedProgramPlanId || null;
        } catch (error) {
            this.loadError = this.normalizeError(error);
            this.offerings = [];
            this.scheduledEntries = [];
            this.timeSlots = [];
            this.programPlanOptions = [{ label: 'All Program Plans', value: '' }];
        } finally {
            this.isLoading = false;
        }
    }

    normalizeError(error) {
        const body = error && error.body;
        if (Array.isArray(body)) {
            return body.map((item) => item.message).join(', ');
        }
        return (body && body.message) || error.message || 'Unable to load timetable builder.';
    }

    resolveRoomLabel(roomValue, roomName) {
        if (!roomValue) {
            return roomName || '';
        }
        const option = this.roomOptions.find((item) => item.value === roomValue);
        return option ? option.label : (roomName || roomValue);
    }

    get termLabel() {
        return this.academicTermName;
    }

    get isFocusedBuilder() {
        return !!this.courseOfferingId;
    }

    get showBuilderFilters() {
        return !this.isFocusedBuilder;
    }

    get hasProgramPlanOptions() {
        return this.programPlanOptions.length > 1;
    }

    get backlogOfferings() {
        return this.offerings.filter((offering) => !offering.hasSchedules);
    }

    get hasDataView() {
        return !this.isLoading && !this.loadError;
    }

    get scheduledOfferingCount() {
        return this.offerings.filter((offering) => offering.hasSchedules).length;
    }

    get unscheduledCount() {
        return this.backlogOfferings.length;
    }

    get totalOfferings() {
        return this.offerings.length;
    }

    get conflictCount() {
        return (this.validation.conflicts || []).length;
    }

    get gridRows() {
        const hiddenCellKeys = new Set();

        return this.timeSlots.map((time, timeIndex) => ({
            time,
            timeLabel: this.formatTimeLabel(time),
            slots: this.days.map((day) => {
                const slotKey = `${day}-${time}`;
                if (hiddenCellKeys.has(slotKey)) {
                    return {
                        slotKey,
                        render: false,
                        hasEntries: false,
                        rowSpan: 1
                    };
                }

                const entries = this.scheduledEntries
                    .filter((entry) => entry.dayName === day && entry.startTime === time)
                    .map((entry) => {
                        const requestedSpan = calculateSlotSpan(entry);
                        const availableSpan = Math.max(1, this.timeSlots.length - timeIndex);
                        const rowSpan = Math.min(requestedSpan, availableSpan);
                        for (let offset = 1; offset < rowSpan; offset += 1) {
                            hiddenCellKeys.add(`${day}-${this.timeSlots[timeIndex + offset]}`);
                        }

                        return {
                            ...entry,
                            rowSpan,
                            cardClass: `grid-session ${entry.tone}`
                        };
                    });

                return {
                    slotKey,
                    day,
                    time,
                    rowSpan: entries.length ? entries[0].rowSpan : 1,
                    slotStyle: `--slot-row-span: ${entries.length ? entries[0].rowSpan : 1};`,
                    render: true,
                    entries,
                    hasEntries: entries.length > 0,
                    slotClass: `grid-slot ${this.activeDropKey === slotKey ? 'drop-active' : ''}`
                };
            })
        }));
    }

    get summaryText() {
        return `${this.totalOfferings} course offerings in this term, ${this.scheduledOfferingCount} already scheduled and ${this.unscheduledCount} still in backlog.`;
    }

    get topWarnings() {
        return this.validation.warnings || [];
    }

    get hasTopWarnings() {
        return this.topWarnings.length > 0;
    }

    get topConflicts() {
        return this.validation.conflicts || [];
    }

    get hasTopConflicts() {
        return this.topConflicts.length > 0;
    }

    get topSuggestions() {
        return this.validation.suggestions || [];
    }

    get hasTopSuggestions() {
        return this.topSuggestions.length > 0;
    }

    get hasBacklogOfferings() {
        return this.backlogOfferings.length > 0;
    }

    get editorOffering() {
        return this.offerings.find((offering) => offering.id === this.editorOfferingId);
    }

    get editorTitle() {
        return this.editorOffering ? this.editorOffering.name : 'Schedule Offering';
    }

    get editorTemplateEntries() {
        return this.editorOffering ? this.editorOffering.templateEntries || [] : [];
    }

    get hasScheduleTemplateOptions() {
        return this.scheduleTemplateOptions.length > 0;
    }

    get selectedTemplateOption() {
        return this.scheduleTemplateOptions.find((option) => option.value === this.editorTemplateId);
    }

    get editorHasTemplate() {
        return this.editorTemplateEntries.length > 0 || !!this.editorTemplateId;
    }

    get editorConflicts() {
        return this.calculateEditorConflicts();
    }

    get hasEditorConflicts() {
        return this.editorConflicts.length > 0;
    }

    get editorElectiveWarnings() {
        const offering = this.editorOffering;
        if (!offering) {
            return [];
        }
        const electivePlanIds = getElectivePlanIds(offering.planEnrollmentTokens || []);
        if (!electivePlanIds.length) {
            return [];
        }

        const warnings = [];
        const seen = new Set();

        this.editorDrafts.forEach((draft) => {
            if (draft.rowError) {
                return;
            }
            electivePlanIds.forEach((planId) => {
                this.scheduledEntries.forEach((entry) => {
                    if (entry.courseOfferingId === offering.id) return;
                    if (entry.dayName !== draft.dayName) return;
                    const entryElectivePlanIds = getElectivePlanIds(entry.planEnrollmentTokens || []);
                    if (!entryElectivePlanIds.includes(planId)) return;
                    if (entry.startTime === draft.startTime && entry.endTime === draft.endTime) return;

                    const key = `${planId}|${draft.dayName}|${entry.courseOfferingId}`;
                    if (!seen.has(key)) {
                        seen.add(key);
                        warnings.push(
                            `${draft.dayName}: Elective time mismatch with "${entry.offeringName || entry.courseName}". ` +
                                `This offering is at ${this.formatTimeLabel(draft.startTime)}–${this.formatTimeLabel(draft.endTime)}, ` +
                                `but "${entry.offeringName || entry.courseName}" is at ${this.formatTimeLabel(entry.startTime)}–${this.formatTimeLabel(entry.endTime)}. ` +
                                `All electives for the same program plan must share one time slot.`
                        );
                    }
                });
            });
        });

        return warnings;
    }

    get hasEditorElectiveWarnings() {
        return this.editorElectiveWarnings.length > 0;
    }

    get editorHasBlockingIssues() {
        return this.editorConflicts.length > 0 || this.editorDrafts.some((draft) => draft.rowError);
    }

    get canClearSchedule() {
        return this.editorOffering && this.editorOffering.hasSchedules;
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    async handleTermChange(event) {
        this.selectedAcademicTermId = event.detail.value;
        this.academicTermId = this.selectedAcademicTermId;
        this.selectedProgramPlanId = '';
        this.programPlanId = null;
        this.courseOfferingId = null;
        this.handleCloseEditor();
        await this.loadBuilderData();
    }

    async handleProgramPlanChange(event) {
        this.selectedProgramPlanId = event.detail.value || '';
        this.programPlanId = this.selectedProgramPlanId || null;
        this.courseOfferingId = null;
        this.handleCloseEditor();
        await this.loadBuilderData();
    }

    async handleTopSave() {
        await this.loadBuilderData();
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Timetable up to date',
                message: 'The latest timetable data has been loaded. Each course offering is saved when you confirm its schedule.',
                variant: 'success'
            })
        );
    }

    handleBacklogDragStart(event) {
        if (event.currentTarget.dataset.locked === 'true') {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Timetable locked',
                    message: 'Unlock this course offering before editing its schedule.',
                    variant: 'warning'
                })
            );
            event.preventDefault();
            return;
        }
        this.draggedOfferingId = event.currentTarget.dataset.offeringId;
        event.dataTransfer.dropEffect = 'move';
        event.dataTransfer.setData('text/plain', this.draggedOfferingId);
    }

    handleDragEnd() {
        this.draggedOfferingId = null;
        this.activeDropKey = null;
    }

    handleCellDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
    }

    handleCellDragEnter(event) {
        event.preventDefault();
        this.activeDropKey = event.currentTarget.dataset.slotKey;
    }

    handleCellDragLeave(event) {
        if (this.activeDropKey === event.currentTarget.dataset.slotKey) {
            this.activeDropKey = null;
        }
    }

    handleCellDrop(event) {
        event.preventDefault();
        const slotKey = event.currentTarget.dataset.slotKey;
        const offeringId = this.draggedOfferingId || event.dataTransfer.getData('text/plain');
        this.activeDropKey = null;
        this.draggedOfferingId = null;
        if (!offeringId) {
            return;
        }

        const [dayName, startTime] = slotKey.split('-');
        this.openEditor(offeringId, { dayName, startTime });
    }

    handleEditScheduled(event) {
        if (event.currentTarget.dataset.locked === 'true') {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Timetable locked',
                    message: 'Unlock this course offering before editing its schedule.',
                    variant: 'warning'
                })
            );
            return;
        }
        this.openEditor(event.currentTarget.dataset.offeringId, {
            dayName: event.currentTarget.dataset.dayName,
            startTime: event.currentTarget.dataset.startTime
        });
    }

    openEditor(offeringId, seedSlot) {
        const offering = this.offerings.find((item) => item.id === offeringId);
        if (!offering) {
            return;
        }
        if (offering.timetableLocked) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Timetable locked',
                    message: 'Unlock this course offering before editing its schedule.',
                    variant: 'warning'
                })
            );
            return;
        }

        const existingRows = this.scheduledEntries
            .filter((entry) => entry.courseOfferingId === offeringId)
            .sort((left, right) => (left.dayNumber - right.dayNumber) || left.startTime.localeCompare(right.startTime));

        let drafts;
        if (existingRows.length) {
            drafts = existingRows.map((entry) => cloneDraft(entry));
        } else if (offering.templateEntries && offering.templateEntries.length) {
            drafts = offering.templateEntries.map((entry) => cloneDraft(entry));
        } else {
            drafts = [
                cloneDraft({
                    dayName: seedSlot ? seedSlot.dayName : 'Sunday',
                    startTime: seedSlot ? seedSlot.startTime : (this.timeSlots[0] || '08:00'),
                    endTime: defaultEndTime(seedSlot ? seedSlot.startTime : (this.timeSlots[0] || '08:00'))
                })
            ];
        }

        this.isEditorOpen = true;
        this.editorOfferingId = offeringId;
        this.editorDrafts = this.applyDraftValidation(drafts);
        this.editorSeedSlot = seedSlot;
        this.editorTemplateId = offering.templateId || null;
        this.editorTemplateName = offering.templateName || null;
        this.editorTemplateRecurrencePattern = offering.templateRecurrencePattern || '';
        this.editorTemplateStartDate = this.selectedTemplateOption ? this.selectedTemplateOption.startDate || '' : '';
        this.editorTemplateEndDate = this.selectedTemplateOption ? this.selectedTemplateOption.endDate || '' : '';

        if (!existingRows.length && this.editorTemplateId) {
            this.loadTemplateDrafts(this.editorTemplateId);
        }
    }

    handleCloseEditor() {
        this.isEditorOpen = false;
        this.editorOfferingId = null;
        this.editorDrafts = [];
        this.editorSeedSlot = null;
        this.editorTemplateId = null;
        this.editorTemplateName = null;
        this.editorTemplateRecurrencePattern = '';
        this.editorTemplateStartDate = '';
        this.editorTemplateEndDate = '';
    }

    async handleTemplateSelection(event) {
        this.editorTemplateId = event.detail.value || null;
        const selectedOption = this.selectedTemplateOption;
        this.editorTemplateName = selectedOption ? selectedOption.label : null;
        this.editorTemplateRecurrencePattern = selectedOption ? (selectedOption.recurrencePattern || '') : '';
        this.editorTemplateStartDate = selectedOption ? (selectedOption.startDate || '') : '';
        this.editorTemplateEndDate = selectedOption ? (selectedOption.endDate || '') : '';

        if (!this.editorTemplateId) {
            return;
        }

        await this.loadTemplateDrafts(this.editorTemplateId);
    }

    async loadTemplateDrafts(templateId) {
        if (!templateId || !this.editorOfferingId) {
            return;
        }

        try {
            const templateEntries = await getScheduleTemplateEntries({
                templateId,
                courseOfferingId: this.editorOfferingId
            });
            if ((templateEntries || []).length) {
                this.editorDrafts = this.applyDraftValidation(
                    templateEntries.map((entry) => cloneDraft(entry))
                );
                return;
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'No template rows found',
                    message: 'The selected schedule template does not contain any day/time entries.',
                    variant: 'warning'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Unable to load template',
                    message: this.normalizeError(error),
                    variant: 'error'
                })
            );
        }
    }

    handleTemplateRecurrenceChange(event) {
        this.editorTemplateRecurrencePattern = event.target.value;
    }

    handleTemplateStartDateChange(event) {
        this.editorTemplateStartDate = event.target.value || '';
    }

    handleTemplateEndDateChange(event) {
        this.editorTemplateEndDate = event.target.value || '';
    }

    handleDraftChange(event) {
        const { rowId, field } = event.currentTarget.dataset;
        const value = event.detail && event.detail.value !== undefined
            ? event.detail.value
            : event.target.value;
        this.editorDrafts = this.applyDraftValidation(
            this.editorDrafts.map((draft) => {
                if (draft.id !== rowId) {
                    return draft;
                }
                const nextDraft = { ...draft, [field]: value };
                if (field === 'startTime' && (!nextDraft.endTime || parseTime(nextDraft.endTime) <= parseTime(value))) {
                    nextDraft.endTime = defaultEndTime(value);
                }
                return nextDraft;
            })
        );
    }

    handleAddRow() {
        const baseTime = this.editorDrafts.length
            ? this.editorDrafts[this.editorDrafts.length - 1].startTime
            : (this.timeSlots[0] || '08:00');

        this.editorDrafts = this.applyDraftValidation([
            ...this.editorDrafts,
            cloneDraft({
                dayName: 'Sunday',
                startTime: baseTime,
                endTime: defaultEndTime(baseTime)
            })
        ]);
    }

    handleRemoveRow(event) {
        const rowId = event.currentTarget.dataset.rowId;
        const remaining = this.editorDrafts.filter((draft) => draft.id !== rowId);
        this.editorDrafts = this.applyDraftValidation(remaining.length ? remaining : [cloneDraft()]);
    }

    async handleClearSchedule() {
        if (!this.editorOfferingId) {
            return;
        }

        await this.persistSchedule([], { suppressSuccessToast: true });
    }

    async handleSaveOffering() {
        if (this.editorHasBlockingIssues) {
            return;
        }

        await this.persistSchedule(
            this.editorDrafts.map((draft) => ({
                id: draft.scheduleId,
                dayName: draft.dayName,
                startTime: draft.startTime,
                endTime: draft.endTime,
                room: draft.room
            }))
        );
    }

    async persistSchedule(scheduleEntries, options = {}) {
        this.isSaving = true;
        try {
            const saveResult = await saveCourseOfferingSchedules({
                courseOfferingId: this.editorOfferingId,
                scheduleEntriesJson: JSON.stringify(scheduleEntries),
                templateId: this.editorTemplateId,
                templateRecurrencePattern: this.editorTemplateRecurrencePattern,
                templateStartDate: this.editorTemplateStartDate,
                templateEndDate: this.editorTemplateEndDate
            });

            if (!options.suppressSuccessToast) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Schedule saved',
                        message: saveResult && saveResult.message
                            ? saveResult.message
                            : `${this.editorTitle} timetable updated successfully.`,
                        variant: 'success'
                    })
                );
            }
            this.handleCloseEditor();
            await this.loadBuilderData();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Unable to save schedule',
                    message: this.normalizeError(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isSaving = false;
        }
    }

    applyDraftValidation(drafts) {
        const normalized = drafts.map((draft) => ({ ...cloneDraft(draft), rowError: '' }));

        normalized.forEach((draft, index) => {
            if (!draft.dayName || !draft.startTime || !draft.endTime) {
                draft.rowError = 'Day, start time, and end time are required.';
                return;
            }

            const startMinutes = parseTime(draft.startTime);
            const endMinutes = parseTime(draft.endTime);
            if (startMinutes === null || endMinutes === null || endMinutes <= startMinutes) {
                draft.rowError = 'End time must be later than start time.';
                return;
            }

            const overlappingDraft = normalized.find(
                (other, otherIndex) =>
                    otherIndex !== index &&
                    other.dayName === draft.dayName &&
                    parseTime(other.startTime) < endMinutes &&
                    parseTime(other.endTime) > startMinutes
            );
            if (overlappingDraft) {
                draft.rowError = `Overlaps another ${draft.dayName} row in this offering.`;
            }
        });

        return normalized;
    }

    calculateEditorConflicts() {
        const offering = this.editorOffering;
        if (!offering) {
            return [];
        }

        const conflicts = [];
        this.editorDrafts.forEach((draft) => {
            if (draft.rowError) {
                return;
            }

            const startMinutes = parseTime(draft.startTime);
            const endMinutes = parseTime(draft.endTime);
            const overlappingGridEntry = this.scheduledEntries.find(
                (entry) =>
                    entry.courseOfferingId !== offering.id &&
                    shouldBlockOverlap(offering.planEnrollmentTokens || [], entry.planEnrollmentTokens || []) &&
                    entry.dayName === draft.dayName &&
                    parseTime(entry.startTime) < endMinutes &&
                    parseTime(entry.endTime) > startMinutes
            );

            if (overlappingGridEntry) {
                conflicts.push(
                    `${draft.dayName} ${this.formatTimeLabel(draft.startTime)}-${this.formatTimeLabel(draft.endTime)} overlaps with ${overlappingGridEntry.offeringName}.`
                );
                return;
            }

            if (!offering.facultyId) {
                return;
            }

            const overlappingFacultyEntry = this.scheduledEntries.find(
                (entry) =>
                    entry.courseOfferingId !== offering.id &&
                    entry.facultyId === offering.facultyId &&
                    entry.dayName === draft.dayName &&
                    parseTime(entry.startTime) < endMinutes &&
                    parseTime(entry.endTime) > startMinutes
            );

            if (overlappingFacultyEntry) {
                conflicts.push(
                    `${draft.dayName} ${this.formatTimeLabel(draft.startTime)}-${this.formatTimeLabel(draft.endTime)} conflicts with ${overlappingFacultyEntry.offeringName}.`
                );
            }
        });

        return [...new Set(conflicts)];
    }

    formatTimeLabel(value) {
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

    get dayOptions() {
        return this.days.map((day) => ({ label: day, value: day }));
    }

    get timeOptions() {
        return this.timeSlots.map((time) => ({ label: this.formatTimeLabel(time), value: time }));
    }

    get editorRows() {
        return this.editorDrafts.map((draft) => ({
            ...draft,
            dayOptions: this.dayOptions,
            startOptions: this.timeOptions,
            endOptions: this.timeOptions,
            roomOptions: this.roomOptions
        }));
    }
}