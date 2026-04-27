import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCycleOptions from '@salesforce/apex/KenAccommodationManagementController.getCycleOptions';
import getWindowOptions from '@salesforce/apex/KenAccommodationManagementController.getWindowOptions';
import getInProgressRows from '@salesforce/apex/KenAccommodationManagementController.getInProgressRows';
import getInProgressApplicationDetail from '@salesforce/apex/KenAccommodationManagementController.getInProgressApplicationDetail';
import getAllocatedRows from '@salesforce/apex/KenAccommodationManagementController.getAllocatedRows';
import getAllocatedDetail from '@salesforce/apex/KenAccommodationManagementController.getAllocatedDetail';
import getAssignableRooms from '@salesforce/apex/KenAccommodationManagementController.getAssignableRooms';
import assignRoomToAllotment from '@salesforce/apex/KenAccommodationManagementController.assignRoomToAllotment';
import cancelAllocation from '@salesforce/apex/KenAccommodationManagementController.cancelAllocation';
import checkoutAllocation from '@salesforce/apex/KenAccommodationManagementController.checkoutAllocation';
import rejectApplication from '@salesforce/apex/KenAccommodationManagementController.rejectApplication';
import saveWindowAutoAllotmentConfig from '@salesforce/apex/KenAccommodationManagementController.saveWindowAutoAllotmentConfig';

const DEFAULT_AUTO_ALLOTMENT_BATCH_SIZE = 50;
const AUTO_ALLOTMENT_RULE_OPTIONS = [
    { label: 'First Come First Serve', value: 'firstComeFirstServe' },
    { label: 'Program Priority', value: 'programPriority' },
    { label: 'Year Priority', value: 'yearPriority' }
];
const AUTO_ALLOTMENT_GROUPING_OPTIONS = [
    { label: 'By Program', value: 'program' },
    { label: 'By Year', value: 'year' },
    { label: 'By Category', value: 'category' }
];
const ALLOTMENT_TYPE_DIRECT = 'Direct Allotment';
const ALLOTMENT_TYPE_PROVISIONAL = 'Provisional Allotment';
const ALLOTMENT_TYPE_CONFIRMED = 'Confirmed Allotment';
const ALLOTMENT_TYPE_PREFERENCE = 'Preference Selected';
const ASSIGNMENT_ALLOTMENT_TYPE_OPTIONS = [
    { label: 'None', value: ALLOTMENT_TYPE_DIRECT },
    { label: ALLOTMENT_TYPE_PROVISIONAL, value: ALLOTMENT_TYPE_PROVISIONAL },
    { label: ALLOTMENT_TYPE_CONFIRMED, value: ALLOTMENT_TYPE_CONFIRMED }
];

function getValidOptionValue(options, value, fallbackValue) {
    return options.some((option) => option.value === value) ? value : fallbackValue;
}

function cloneAutoAllotmentConfig(config = {}) {
    return {
        allocationRule: getValidOptionValue(AUTO_ALLOTMENT_RULE_OPTIONS, config.allocationRule, 'firstComeFirstServe'),
        batchProcessing: config.batchProcessing === true,
        batchSize: config.batchSize ?? DEFAULT_AUTO_ALLOTMENT_BATCH_SIZE,
        batchGrouping: getValidOptionValue(AUTO_ALLOTMENT_GROUPING_OPTIONS, config.batchGrouping, 'program'),
        previousYearCarryForward: config.previousYearCarryForward === true
    };
}

function getDefaultAutoAllotmentConfig(windowRecord) {
    return {
        allocationRule: 'firstComeFirstServe',
        batchProcessing: false,
        batchSize: DEFAULT_AUTO_ALLOTMENT_BATCH_SIZE,
        batchGrouping: 'program',
        previousYearCarryForward: false
    };
}

function normalizeAutoAllotmentConfig(config = {}, windowRecord) {
    const defaults = getDefaultAutoAllotmentConfig(windowRecord);
    const batchSizeValue = Number.parseInt(config.batchSize, 10);

    return {
        allocationRule: getValidOptionValue(
            AUTO_ALLOTMENT_RULE_OPTIONS,
            config.allocationRule,
            defaults.allocationRule
        ),
        batchProcessing:
            typeof config.batchProcessing === 'boolean' ? config.batchProcessing : defaults.batchProcessing,
        batchSize:
            Number.isFinite(batchSizeValue) && batchSizeValue > 0
                ? batchSizeValue
                : defaults.batchSize,
        batchGrouping: getValidOptionValue(
            AUTO_ALLOTMENT_GROUPING_OPTIONS,
            config.batchGrouping,
            defaults.batchGrouping
        ),
        previousYearCarryForward:
            typeof config.previousYearCarryForward === 'boolean'
                ? config.previousYearCarryForward
                : defaults.previousYearCarryForward
    };
}

function getOptionLabel(options, value) {
    return options.find((option) => option.value === value)?.label || '';
}

function getFirstFilledValue(...values) {
    const nextValue = values.find((value) => value !== null && value !== undefined && value !== '');
    return nextValue ?? '';
}

function getPersistedAutoAllotmentConfig(windowRecord = {}) {
    return {
        allocationRule: windowRecord.autoAllotmentRule,
        batchProcessing: windowRecord.autoAllotmentBatchProcessing,
        batchSize: windowRecord.autoAllotmentBatchSize,
        batchGrouping: windowRecord.autoAllotmentBatchGrouping,
        previousYearCarryForward: windowRecord.autoAllotmentPreviousYearCarryForward
    };
}

function normalizeAllotmentTypeLabel(value) {
    const cleanedValue = `${value || ''}`.trim();
    const normalizedValue = cleanedValue.toLowerCase();
    if (normalizedValue === 'none') {
        return ALLOTMENT_TYPE_DIRECT;
    }
    if (normalizedValue === 'direct' || normalizedValue === 'direct allotment') {
        return ALLOTMENT_TYPE_DIRECT;
    }
    if (normalizedValue === 'provisional') {
        return ALLOTMENT_TYPE_PROVISIONAL;
    }
    if (normalizedValue === 'provisional allotment') {
        return ALLOTMENT_TYPE_PROVISIONAL;
    }
    if (normalizedValue === 'preference selected' || normalizedValue === 'preference allotment') {
        return ALLOTMENT_TYPE_PREFERENCE;
    }
    if (normalizedValue === 'final allotment' || normalizedValue === 'confirmed allotment') {
        return ALLOTMENT_TYPE_CONFIRMED;
    }
    return cleanedValue;
}

function normalizeAssignmentAllotmentType(value) {
    const normalizedValue = normalizeAllotmentTypeLabel(value);
    if (normalizedValue === ALLOTMENT_TYPE_CONFIRMED) {
        return ALLOTMENT_TYPE_CONFIRMED;
    }
    if (normalizedValue === ALLOTMENT_TYPE_PROVISIONAL) {
        return ALLOTMENT_TYPE_PROVISIONAL;
    }
    return ALLOTMENT_TYPE_DIRECT;
}

function resolveDefaultAssignmentAllotmentType(windowAllotmentType) {
    const normalizedWindowAllotmentType = normalizeAllotmentTypeLabel(windowAllotmentType);
    if (normalizedWindowAllotmentType === ALLOTMENT_TYPE_CONFIRMED) {
        return ALLOTMENT_TYPE_CONFIRMED;
    }
    if (normalizedWindowAllotmentType === ALLOTMENT_TYPE_DIRECT) {
        return ALLOTMENT_TYPE_DIRECT;
    }
    return ALLOTMENT_TYPE_PROVISIONAL;
}

function resolveInProgressAllotmentType(windowAllotmentType, fallbackValue) {
    const normalizedWindowAllotmentType = normalizeAllotmentTypeLabel(windowAllotmentType);
    if (normalizedWindowAllotmentType === ALLOTMENT_TYPE_PREFERENCE) {
        return ALLOTMENT_TYPE_PREFERENCE;
    }
    if (normalizedWindowAllotmentType === ALLOTMENT_TYPE_PROVISIONAL) {
        return ALLOTMENT_TYPE_PROVISIONAL;
    }

    const normalizedFallback = normalizeAllotmentTypeLabel(fallbackValue);
    if (normalizedFallback === ALLOTMENT_TYPE_PREFERENCE || normalizedFallback === ALLOTMENT_TYPE_PROVISIONAL) {
        return normalizedFallback;
    }
    return ALLOTMENT_TYPE_PROVISIONAL;
}

function buildAutoAllotmentEngineLabel(config) {
    if (!config) {
        return 'First Come First Serve';
    }

    const parts = [getOptionLabel(AUTO_ALLOTMENT_RULE_OPTIONS, config.allocationRule) || 'First Come First Serve'];
    if (config.batchProcessing) {
        const groupingLabel = getOptionLabel(AUTO_ALLOTMENT_GROUPING_OPTIONS, config.batchGrouping);
        parts.push(`Batch ${config.batchSize}`);
        if (groupingLabel) {
            parts.push(groupingLabel);
        }
    }

    return parts.join(' - ');
}

function getRoomOptionCapacity(option) {
    const value = Number.parseInt(option?.capacity, 10);
    return Number.isFinite(value) ? Math.max(value, 0) : 0;
}

function getRoomOptionOccupancy(option) {
    const value = Number.parseInt(option?.occupancy, 10);
    return Number.isFinite(value) ? Math.max(value, 0) : 0;
}

function getRoomOptionAvailableBeds(option) {
    return Math.max(getRoomOptionCapacity(option) - getRoomOptionOccupancy(option), 0);
}

function isPartiallyOccupiedRoomOption(option) {
    return getRoomOptionOccupancy(option) > 0 && getRoomOptionAvailableBeds(option) > 0;
}

function compareRoomFillPriority(left, right) {
    const leftPartial = isPartiallyOccupiedRoomOption(left);
    const rightPartial = isPartiallyOccupiedRoomOption(right);
    if (leftPartial !== rightPartial) {
        return leftPartial ? -1 : 1;
    }

    const leftAvailable = getRoomOptionAvailableBeds(left);
    const rightAvailable = getRoomOptionAvailableBeds(right);
    if (leftAvailable !== rightAvailable) {
        return leftAvailable - rightAvailable;
    }

    const leftCapacity = getRoomOptionCapacity(left);
    const rightCapacity = getRoomOptionCapacity(right);
    const leftOccupancyRatio = leftCapacity > 0 ? getRoomOptionOccupancy(left) / leftCapacity : 0;
    const rightOccupancyRatio = rightCapacity > 0 ? getRoomOptionOccupancy(right) / rightCapacity : 0;
    if (leftOccupancyRatio !== rightOccupancyRatio) {
        return rightOccupancyRatio - leftOccupancyRatio;
    }

    const leftOccupancy = getRoomOptionOccupancy(left);
    const rightOccupancy = getRoomOptionOccupancy(right);
    if (leftOccupancy !== rightOccupancy) {
        return rightOccupancy - leftOccupancy;
    }

    if (leftCapacity !== rightCapacity) {
        return leftCapacity - rightCapacity;
    }

    return 0;
}

function compareAssignableRoomOptions(left, right, { includeSelectable = false } = {}) {
    if (left?.preferenceMatch !== right?.preferenceMatch) {
        return left?.preferenceMatch ? -1 : 1;
    }
    if (left?.roommateMatch !== right?.roommateMatch) {
        return left?.roommateMatch ? -1 : 1;
    }
    if (includeSelectable && left?.selectable !== right?.selectable) {
        return left?.selectable ? -1 : 1;
    }

    const fillPriorityCompare = compareRoomFillPriority(left, right);
    if (fillPriorityCompare !== 0) {
        return fillPriorityCompare;
    }

    return `${left?.building || ''} ${left?.room || ''}`.localeCompare(`${right?.building || ''} ${right?.room || ''}`);
}

export default class KenAccommodationManagementScreen extends LightningElement {
    cycles = [];
    windows = [];
    windowConfigState = {};
    selectedCycleId = '';
    selectedWindowId = '';
    activeView = 'inProgress';
    isFilterPanelOpen = false;
    isLoadingCycles = false;
    isLoadingWindows = false;
    isLoadingInProgress = false;
    isLoadingAllocated = false;
    isLoadingDetail = false;
    selectedApplicationDetail = null;
    isAssignRoomModalOpen = false;
    isAssignRunAsModalOpen = false;
    isLoadingAssignableRooms = false;
    isSavingAssignRoom = false;
    assignRoomStudentName = '';
    assignRoomRollNo = '';
    assignRoomAllotmentId = '';
    assignRoomMode = 'inProgress';
    assignRoomPresentation = 'table';
    assignRoomOptions = [];
    selectedAssignRoomId = '';
    assignRoomAllotmentType = ALLOTMENT_TYPE_PROVISIONAL;
    isCancelModalOpen = false;
    isCancellingAllocation = false;
    cancelModalStudentName = '';
    cancelModalAllotmentId = '';
    isCheckoutModalOpen = false;
    isCheckingOutAllocation = false;
    checkoutModalStudentName = '';
    checkoutModalAllotmentId = '';
    isRejectModalOpen = false;
    rejectModalStudentName = '';
    rejectModalAllotmentId = '';
    rejectModalReason = '';
    isAutoAllotmentModalOpen = false;
    autoAllotmentModalMode = 'run';
    isRunningAutoAllotment = false;
    autoAllotmentDraft = cloneAutoAllotmentConfig();
    autoAllotmentRunAsType = ALLOTMENT_TYPE_PROVISIONAL;
    filters = {
        program: 'all',
        payment: 'all',
        status: 'all',
        building: 'all'
    };

    connectedCallback() {
        this.loadCycleOptions();
    }

    renderedCallback() {
        this.syncFilterSelectValues();
    }

    get cycleOptions() {
        return this.cycles;
    }

    get currentCycle() {
        return this.cycles.find((cycle) => cycle.value === this.selectedCycleId) || null;
    }

    get windowOptions() {
        return this.windows.map((windowRecord) => ({
            value: windowRecord.id,
            label: windowRecord.label
        }));
    }

    get selectedWindow() {
        return this.windows.find((windowRecord) => windowRecord.id === this.selectedWindowId) || null;
    }

    get hasSelectedWindow() {
        return !!this.selectedWindow;
    }

    get autoAllotmentRuleOptions() {
        return AUTO_ALLOTMENT_RULE_OPTIONS;
    }

    get autoAllotmentGroupingOptions() {
        return AUTO_ALLOTMENT_GROUPING_OPTIONS;
    }

    get assignmentAllotmentTypeOptions() {
        return ASSIGNMENT_ALLOTMENT_TYPE_OPTIONS;
    }

    get isAutoAllotmentConfigMode() {
        return this.autoAllotmentModalMode === 'configure';
    }

    get isAutoAllotmentRunMode() {
        return this.autoAllotmentModalMode !== 'configure';
    }

    get isAssignAllotmentTypeDisabled() {
        return this.isLoadingAssignableRooms || this.isSavingAssignRoom;
    }

    get autoAllotmentModalCardClass() {
        return 'acm-modal-card acm-modal-card--auto';
    }

    get autoAllotmentPrimaryActionLabel() {
        if (this.isRunningAutoAllotment) {
            return 'Running...';
        }
        return this.isAutoAllotmentConfigMode ? 'Save Configuration' : 'Run Allotment';
    }

    get isAutoAllotmentBatchProcessingEnabled() {
        return !!this.autoAllotmentDraft?.batchProcessing;
    }

    get showAutoAllotmentBatchSettings() {
        return this.isAutoAllotmentBatchProcessingEnabled;
    }

    get showAutoAllotmentCarryForwardNote() {
        return !!this.autoAllotmentDraft?.previousYearCarryForward;
    }

    get autoAllotmentEligibleCount() {
        return (this.selectedWindow?.inProgressRows || []).filter((row) => !!row.id).length;
    }

    get hasAutoAllotmentCandidates() {
        return this.autoAllotmentEligibleCount > 0;
    }

    get isAutoAllotmentPrimaryDisabled() {
        if (this.isRunningAutoAllotment) {
            return true;
        }
        if (this.isAutoAllotmentConfigMode) {
            return !this.hasSelectedWindow;
        }
        return !this.hasSelectedWindow;
    }

    get isAutoAllotmentActionDisabled() {
        return !this.hasSelectedWindow || this.isLoadingInProgress || this.isRunningAutoAllotment;
    }

    get isDetailView() {
        return !!this.selectedApplicationDetail;
    }

    get isListView() {
        return !this.isDetailView;
    }

    get selectedWindowSummary() {
        const selectedWindow = this.selectedWindow;
        if (!selectedWindow) {
            return [];
        }

        const inProgressRows = selectedWindow.inProgressRows || [];
        const allocatedRows = selectedWindow.allocatedRows || [];
        const submittedCount = inProgressRows.filter(
            (row) => row.status === 'Submitted' || row.status === 'Pending'
        ).length;
        const approvedCount = inProgressRows.filter(
            (row) => row.status === 'Approved' || row.status === 'Provisional Alloted' || row.status === 'Alloted'
        ).length;

        return [
            {
                key: 'inProgress',
                label: 'In Progress',
                value: inProgressRows.length,
                iconName: 'utility:user',
                tileClass: 'acm-summary-tile',
                iconClass: 'acm-summary-icon acm-summary-icon--blue'
            },
            {
                key: 'submitted',
                label: 'Submitted',
                value: submittedCount,
                iconName: 'utility:description',
                tileClass: 'acm-summary-tile',
                iconClass: 'acm-summary-icon acm-summary-icon--violet'
            },
            {
                key: 'approved',
                label: 'Approved',
                value: approvedCount,
                iconName: 'utility:check',
                tileClass: 'acm-summary-tile',
                iconClass: 'acm-summary-icon acm-summary-icon--green'
            },
            {
                key: 'allocated',
                label: 'Allocated',
                value: allocatedRows.length,
                iconName: 'utility:home',
                tileClass: 'acm-summary-tile',
                iconClass: 'acm-summary-icon acm-summary-icon--magenta'
            }
        ];
    }

    get currentViewTabs() {
        return [
            {
                value: 'inProgress',
                label: 'In Progress',
                iconName: 'utility:clock',
                className: this.activeView === 'inProgress' ? 'acm-view-tab active' : 'acm-view-tab'
            },
            {
                value: 'allocated',
                label: 'Allocated',
                iconName: 'utility:home',
                className: this.activeView === 'allocated' ? 'acm-view-tab active' : 'acm-view-tab'
            }
        ];
    }

    get isInProgressView() {
        return this.activeView === 'inProgress';
    }

    get isAllocatedView() {
        return this.activeView === 'allocated';
    }

    get isAllocatedDetailView() {
        return this.selectedApplicationDetail?.detailType === 'allocated';
    }

    get isInProgressDetailView() {
        return this.selectedApplicationDetail?.detailType !== 'allocated';
    }

    get detailBreadcrumbCurrent() {
        return this.isAllocatedDetailView ? 'Allocation Details' : 'Application Details';
    }

    get detailPageTitle() {
        return this.isAllocatedDetailView ? 'Allocation Details' : 'Application Details';
    }

    get detailHeaderSubtitle() {
        const detail = this.selectedApplicationDetail;
        if (!detail) {
            return '';
        }
        return this.isAllocatedDetailView
            ? [detail.rollNo, detail.roomNumber].filter((value) => !!value).join(' - ')
            : [detail.rollNo, detail.allotmentType].filter((value) => !!value).join(' - ');
    }

    get hasSelectedAssignRoom() {
        return !!this.selectedAssignRoomId;
    }

    get selectedAssignRoom() {
        return this.assignRoomOptions.find((option) => option.id === this.selectedAssignRoomId) || null;
    }

    get isAssignConfirmDisabled() {
        return !this.hasSelectedAssignRoom || this.isLoadingAssignableRooms || this.isSavingAssignRoom;
    }

    get isAssignRunAsConfirmDisabled() {
        return !this.hasSelectedAssignRoom || !this.assignRoomAllotmentId || this.isSavingAssignRoom;
    }

    get isAssignRoomCardDesign() {
        return this.assignRoomPresentation === 'card';
    }

    get isAssignRoomTableDesign() {
        return !this.isAssignRoomCardDesign;
    }

    get assignRoomModalCardClass() {
        return this.isAssignRoomCardDesign
            ? 'acm-modal-card acm-modal-card--xl acm-modal-card--square'
            : 'acm-modal-card acm-modal-card--xl';
    }

    get showAssignRoommateColumn() {
        return this.isAssignRoomTableDesign && this.assignRoomMode !== 'allocated';
    }

    get assignRoomConfirmLabel() {
        if (this.isAssignRoomCardDesign) {
            return this.assignRoomMode === 'inProgress' ? 'Assign Room' : 'Reassign Room';
        }
        return 'Confirm Assignment';
    }

    get assignRoomSubtitle() {
        const parts = [this.assignRoomStudentName];
        if (this.assignRoomRollNo) {
            parts.push(`(${this.assignRoomRollNo})`);
        }
        const summary = parts.filter((value) => !!value).join(' ');
        return summary ? `Assigning for ${summary}` : 'Assign room for this student';
    }

    get assignRoomHelperText() {
        return this.assignRoomMode === 'allocated'
            ? 'Select an available room to reassign this student.'
            : 'Select an available room to assign to this student.';
    }

    get assignRoomSelectionText() {
        const selectedRoom = this.selectedAssignRoom;
        if (!selectedRoom) {
            return 'Select a room';
        }
        return `Selected: ${selectedRoom.room} - ${selectedRoom.building}`;
    }

    get hasAssignableRoomRows() {
        return this.assignRoomRows.length > 0;
    }

    get assignRoomRows() {
        return [...this.assignRoomOptions]
            .sort((left, right) => compareAssignableRoomOptions(left, right, { includeSelectable: true }))
            .map((row) => {
                const isSelected = row.id === this.selectedAssignRoomId;
                return {
                    ...row,
                    occupancyLabel: `${row.occupancy}/${row.capacity}`,
                    rowClass: isSelected ? 'acm-room-picker-row acm-room-picker-row--selected' : 'acm-room-picker-row',
                    statusClass: this.getRoomStatusPillClass(row.statusTone),
                    preferenceClass: row.preferenceMatch
                        ? 'acm-room-match acm-room-match--yes'
                        : 'acm-room-match acm-room-match--no',
                    preferenceLabel: row.preferenceMatch ? 'Yes' : 'No',
                    roommateClass: row.roommateMatch
                        ? 'acm-room-match acm-room-match--yes'
                        : 'acm-room-match acm-room-match--no',
                    roommateLabel: row.roommateMatch ? 'Yes' : 'No',
                    actionLabel: isSelected ? 'Selected' : 'Select',
                    actionClass: isSelected
                        ? 'acm-room-picker-select-btn acm-room-picker-select-btn--selected'
                        : 'acm-room-picker-select-btn',
                    actionDisabled: !row.selectable
                };
            });
    }

    get hasAssignableRoomCards() {
        return this.assignRoomCards.length > 0;
    }

    get assignRoomCards() {
        return [...this.assignRoomOptions]
            .filter((row) => row.selectable)
            .sort((left, right) => compareAssignableRoomOptions(left, right))
            .map((row) => {
                const isSelected = row.id === this.selectedAssignRoomId;
                const availableBeds = getRoomOptionAvailableBeds(row);
                const subtitle = [row.building, row.floorLabel, row.category].filter((value) => !!value).join(' - ');
                return {
                    ...row,
                    subtitleLabel: [row.building, row.floorLabel, row.category].filter((value) => !!value).join(' - '),
                    subtitle,
                    cardClass: isSelected
                        ? 'acm-room-choice-card acm-room-choice-card--square acm-room-choice-card--selected'
                        : 'acm-room-choice-card acm-room-choice-card--square',
                    radioClass: isSelected
                        ? 'acm-room-choice-radio acm-room-choice-radio--selected'
                        : 'acm-room-choice-radio',
                    radioDotClass: isSelected
                        ? 'acm-room-choice-radio-dot acm-room-choice-radio-dot--selected'
                        : 'acm-room-choice-radio-dot',
                    availabilityLabel: `${availableBeds}/${row.capacity} available`,
                    availabilityClass:
                        availableBeds === row.capacity
                            ? 'acm-pill acm-pill--green-soft'
                            : 'acm-pill acm-pill--gray-soft'
                };
            });
    }

    get cancelModalPrompt() {
        return this.cancelModalStudentName
            ? `Cancel for ${this.cancelModalStudentName}?`
            : 'Cancel this allocation?';
    }

    get hasCancelModalStudentName() {
        return !!this.cancelModalStudentName;
    }

    get isCancelConfirmDisabled() {
        return !this.cancelModalAllotmentId || this.isCancellingAllocation;
    }

    get isCancelKeepDisabled() {
        return this.isCancellingAllocation;
    }

    get checkoutModalPrompt() {
        return this.checkoutModalStudentName
            ? `Checkout for ${this.checkoutModalStudentName}?`
            : 'Checkout this allocation?';
    }

    get hasCheckoutModalStudentName() {
        return !!this.checkoutModalStudentName;
    }

    get isCheckoutConfirmDisabled() {
        return !this.checkoutModalAllotmentId || this.isCheckingOutAllocation;
    }

    get isCheckoutKeepDisabled() {
        return this.isCheckingOutAllocation;
    }

    get hasRejectModalStudentName() {
        return !!this.rejectModalStudentName;
    }

    get isRejectDisabled() {
        return !this.rejectModalReason.trim();
    }

    get detailStudentFields() {
        const detail = this.selectedApplicationDetail;
        if (!detail) {
            return [];
        }
        return [
            { key: 'studentName', label: 'Student Name', value: detail.studentName || '' },
            { key: 'rollNo', label: 'Roll Number', value: detail.rollNo || '' },
            { key: 'program', label: 'Program', value: detail.program || '' },
            { key: 'year', label: 'Year', value: detail.year || '' },
            { key: 'email', label: 'Email', value: detail.email || '' },
            { key: 'phone', label: 'Phone', value: detail.phone || '' }
        ];
    }

    get detailApplicationFields() {
        const detail = this.selectedApplicationDetail;
        if (!detail) {
            return [];
        }
        return [
            { key: 'categoryApplied', label: 'Category Applied', value: detail.categoryApplied || '', pillClass: '' },
            {
                key: 'applicationStatus',
                label: 'Application Status',
                value: detail.applicationStatus || '',
                pillClass: detail.applicationStatus ? this.getStatusPillClass(detail.applicationStatus) : ''
            },
            {
                key: 'paymentStatus',
                label: 'Payment Status',
                value: detail.paymentStatus || '',
                pillClass: detail.paymentStatus ? this.getPaymentPillClass(detail.paymentStatus) : ''
            },
            { key: 'appliedOn', label: 'Applied On', value: detail.appliedOn || '', pillClass: '' }
        ];
    }

    get detailApplicationPrimaryFields() {
        return this.detailApplicationFields.filter((field) => field.key !== 'appliedOn');
    }

    get detailApplicationAppliedOnField() {
        return this.detailApplicationFields.find((field) => field.key === 'appliedOn') || null;
    }

    get detailAllocationFields() {
        const detail = this.selectedApplicationDetail;
        if (!detail) {
            return [];
        }
        return [
            { key: 'roomNumber', label: 'Room Number', value: detail.roomNumber || '', pillClass: '' },
            { key: 'building', label: 'Building', value: detail.building || '', pillClass: '' },
            { key: 'category', label: 'Category', value: detail.category || '', pillClass: '' },
            {
                key: 'allotmentType',
                label: 'Allotment Type',
                value: detail.allotmentType || '',
                pillClass: detail.allotmentType ? 'acm-pill acm-pill--violet-soft' : ''
            },
            {
                key: 'paymentStatus',
                label: 'Payment Status',
                value: detail.paymentStatus || '',
                pillClass: detail.paymentStatus ? this.getPaymentPillClass(detail.paymentStatus) : ''
            },
            {
                key: 'assignmentSource',
                label: 'Assignment Source',
                value: detail.assignmentSource || '',
                pillClass: detail.assignmentSource ? 'acm-pill acm-pill--gray-soft' : ''
            },
            { key: 'assignedOn', label: 'Assigned On', value: detail.assignedOn || '', pillClass: '' }
        ];
    }

    get detailPrimaryFields() {
        return this.isAllocatedDetailView ? this.detailAllocationFields : this.detailApplicationFields;
    }

    get detailPrimarySectionTitle() {
        return this.isAllocatedDetailView ? 'Allocation Details' : 'Application Details';
    }

    get detailPrimarySectionIconName() {
        return this.isAllocatedDetailView ? 'utility:home' : 'utility:file';
    }

    get detailPrimaryGridClass() {
        return this.isAllocatedDetailView
            ? 'acm-detail-info-grid acm-detail-info-grid--allocation'
            : 'acm-detail-info-grid acm-detail-info-grid--compact';
    }

    get showPreferenceSections() {
        return this.isInProgressDetailView;
    }

    get detailPrimaryActionLabel() {
        return this.isAllocatedDetailView ? 'Reassign Room' : 'Assign Room';
    }

    get detailSecondaryActionLabel() {
        return this.isAllocatedDetailView ? 'Cancel Allocation' : 'Reject Application';
    }

    get showDetailCheckoutAction() {
        return this.isAllocatedDetailView;
    }

    get detailPrimaryActionClass() {
        return this.isAllocatedDetailView ? 'acm-ghost-btn' : 'acm-primary-btn acm-primary-btn--wide';
    }

    get detailRoomPreferences() {
        return this.selectedApplicationDetail?.roomPreferences || [];
    }

    get hasRoommatePreference() {
        return !!this.selectedApplicationDetail?.roommatePreference?.name;
    }

    get roommatePreference() {
        return this.selectedApplicationDetail?.roommatePreference || {};
    }

    get filterToggleIcon() {
        return this.isFilterPanelOpen ? 'utility:chevronup' : 'utility:chevrondown';
    }

    get currentFilterRows() {
        return this.isInProgressView ? this.selectedWindow?.inProgressRows || [] : this.selectedWindow?.allocatedRows || [];
    }

    get programFilterOptions() {
        const programValues = [...new Set(this.currentFilterRows.map((row) => row.program).filter((value) => !!value))];
        return [
            { value: 'all', label: 'All' },
            ...programValues.map((value) => ({ value, label: value }))
        ];
    }

    get paymentFilterOptions() {
        const paymentValues = [...new Set(this.currentFilterRows.map((row) => row.payment).filter((value) => !!value))];
        return [
            { value: 'all', label: 'All' },
            ...paymentValues.map((value) => ({ value, label: value }))
        ];
    }

    get statusFilterOptions() {
        const statusValues = [...new Set(this.currentFilterRows.map((row) => row.status).filter((value) => !!value))];
        return [
            { value: 'all', label: 'All' },
            ...statusValues.map((value) => ({ value, label: value }))
        ];
    }

    get buildingFilterOptions() {
        const buildingValues = [...new Set(this.currentFilterRows.map((row) => row.building).filter((value) => !!value))];
        return [
            { value: 'all', label: 'All' },
            ...buildingValues.map((value) => ({ value, label: value }))
        ];
    }

    get filteredInProgressRows() {
        return (this.selectedWindow?.inProgressRows || [])
            .filter((row) => this.matchesInProgressFilters(row))
            .map((row) => ({
                ...row,
                paymentClass: row.payment ? this.getPaymentPillClass(row.payment) : '',
                allotmentTypeClass: 'acm-pill acm-pill--violet-soft',
                statusClass: row.status ? this.getStatusPillClass(row.status) : ''
            }));
    }

    get filteredAllocatedRows() {
        return (this.selectedWindow?.allocatedRows || [])
            .filter((row) => this.matchesAllocatedFilters(row))
            .map((row) => ({
                ...row,
                paymentClass: row.payment ? this.getPaymentPillClass(row.payment) : '',
                allotmentTypeClass: 'acm-pill acm-pill--violet-soft',
                sourceClass: row.source
                    ? row.source === 'Auto Allotment'
                        ? 'acm-pill acm-pill--blue-soft'
                        : 'acm-pill acm-pill--gray-soft'
                    : ''
            }));
    }

    get inProgressCountLabel() {
        return `In Progress (${this.filteredInProgressRows.length})`;
    }

    get allocatedCountLabel() {
        return `Allocated (${this.filteredAllocatedRows.length})`;
    }

    async loadCycleOptions() {
        this.isLoadingCycles = true;
        try {
            const cycleOptions = await getCycleOptions();
            this.cycles = Array.isArray(cycleOptions) ? cycleOptions : [];

            if (!this.selectedCycleId && this.cycles.length > 0) {
                this.selectedCycleId = this.cycles[0].value;
            } else if (this.selectedCycleId && !this.cycles.some((cycle) => cycle.value === this.selectedCycleId)) {
                this.selectedCycleId = this.cycles.length > 0 ? this.cycles[0].value : '';
            }

            await this.loadWindowOptions();
        } catch (error) {
            this.showErrorToast('Unable to load cycles.', error);
        } finally {
            this.isLoadingCycles = false;
        }
    }

    async loadWindowOptions() {
        if (!this.selectedCycleId) {
            this.windows = [];
            this.selectedWindowId = '';
            this.selectedApplicationDetail = null;
            return;
        }

        this.isLoadingWindows = true;
        try {
            const windowItems = await getWindowOptions({ cycleId: this.selectedCycleId });
            this.windows = (Array.isArray(windowItems) ? windowItems : []).map((windowRecord) => ({
                ...windowRecord,
                allotmentType: normalizeAllotmentTypeLabel(windowRecord.allotmentType),
                ...this.getWindowUiData(windowRecord)
            }));

            if (!this.windows.some((windowRecord) => windowRecord.id === this.selectedWindowId)) {
                this.selectedWindowId = '';
                this.selectedApplicationDetail = null;
            } else if (this.selectedWindowId) {
                await this.loadSelectedWindowData(this.selectedWindowId);
            }
        } catch (error) {
            this.windows = [];
            this.selectedWindowId = '';
            this.showErrorToast('Unable to load windows.', error);
        } finally {
            this.isLoadingWindows = false;
        }
    }

    getWindowUiData(windowRecord) {
        const autoAllotmentConfig = normalizeAutoAllotmentConfig(
            this.windowConfigState[windowRecord?.id] || getPersistedAutoAllotmentConfig(windowRecord),
            windowRecord
        );
        return {
            autoAllotmentConfig,
            engineMode: buildAutoAllotmentEngineLabel(autoAllotmentConfig),
            inProgressRows: [],
            allocatedRows: []
        };
    }

    updateWindowAutoAllotmentConfig(windowId, config) {
        if (!windowId) {
            return;
        }

        const windowRecord = this.windows.find((item) => item.id === windowId) || this.selectedWindow;
        const normalizedConfig = normalizeAutoAllotmentConfig(config, windowRecord);
        this.windowConfigState = {
            ...this.windowConfigState,
            [windowId]: normalizedConfig
        };
        this.windows = this.windows.map((item) =>
            item.id === windowId
                ? {
                      ...item,
                      autoAllotmentConfig: cloneAutoAllotmentConfig(normalizedConfig),
                      engineMode: buildAutoAllotmentEngineLabel(normalizedConfig)
                  }
                : item
        );
    }

    async loadSelectedWindowData(windowId) {
        await Promise.all([this.loadInProgressRows(windowId), this.loadAllocatedRows(windowId)]);
    }

    updateWindowRows(windowId, updater) {
        if (!windowId || typeof updater !== 'function') {
            return;
        }

        this.windows = this.windows.map((windowRecord) =>
            windowRecord.id === windowId ? updater(windowRecord) : windowRecord
        );
    }

    buildInProgressRowFromAllocation(allotmentId, nextAllotmentType) {
        const allocatedRow = (this.selectedWindow?.allocatedRows || []).find((row) => row.id === allotmentId) || null;
        const detail = this.selectedApplicationDetail?.allotmentId === allotmentId ? this.selectedApplicationDetail : null;
        const resolvedAllotmentType = resolveInProgressAllotmentType(
            this.selectedWindow?.allotmentType,
            getFirstFilledValue(nextAllotmentType, allocatedRow?.allotmentType, detail?.allotmentType)
        );

        return {
            id: allotmentId,
            student: getFirstFilledValue(allocatedRow?.student, detail?.studentName, this.cancelModalStudentName),
            rollNo: getFirstFilledValue(allocatedRow?.rollNo, detail?.rollNo),
            program: getFirstFilledValue(allocatedRow?.program, detail?.program),
            year: getFirstFilledValue(allocatedRow?.year, detail?.year),
            category: getFirstFilledValue(allocatedRow?.category, detail?.category, detail?.categoryApplied),
            payment: getFirstFilledValue(allocatedRow?.payment, detail?.paymentStatus),
            allotmentType: normalizeAllotmentTypeLabel(resolvedAllotmentType),
            status: getFirstFilledValue(detail?.applicationStatus)
        };
    }

    buildAllocatedRowFromAssignment(sourceAllotmentId, resultAllotmentId, selectedRoom, mode, assignedAllotmentType) {
        const nextAllotmentId = resultAllotmentId || sourceAllotmentId;
        const inProgressRow = (this.selectedWindow?.inProgressRows || []).find((row) => row.id === sourceAllotmentId) || null;
        const allocatedRow = (this.selectedWindow?.allocatedRows || []).find((row) => row.id === sourceAllotmentId) || null;
        const detail = this.selectedApplicationDetail?.allotmentId === sourceAllotmentId ? this.selectedApplicationDetail : null;
        const nextAllotmentType = assignedAllotmentType
            ? normalizeAssignmentAllotmentType(assignedAllotmentType)
            : normalizeAllotmentTypeLabel(
                getFirstFilledValue(inProgressRow?.allotmentType, allocatedRow?.allotmentType, detail?.allotmentType)
            );

        return {
            id: nextAllotmentId,
            student: getFirstFilledValue(inProgressRow?.student, allocatedRow?.student, detail?.studentName, this.assignRoomStudentName),
            rollNo: getFirstFilledValue(inProgressRow?.rollNo, allocatedRow?.rollNo, detail?.rollNo, this.assignRoomRollNo),
            program: getFirstFilledValue(inProgressRow?.program, allocatedRow?.program, detail?.program),
            year: getFirstFilledValue(inProgressRow?.year, allocatedRow?.year, detail?.year),
            room: getFirstFilledValue(selectedRoom?.room, allocatedRow?.room, detail?.roomNumber),
            building: getFirstFilledValue(selectedRoom?.building, allocatedRow?.building, detail?.building),
            category: getFirstFilledValue(
                selectedRoom?.category,
                inProgressRow?.category,
                allocatedRow?.category,
                detail?.category,
                detail?.categoryApplied
            ),
            allotmentType: normalizeAllotmentTypeLabel(nextAllotmentType),
            source: getFirstFilledValue(mode === 'allocated' ? allocatedRow?.source : '', detail?.assignmentSource),
            payment: getFirstFilledValue(inProgressRow?.payment, allocatedRow?.payment, detail?.paymentStatus),
            assignedOn: getFirstFilledValue(allocatedRow?.assignedOn, detail?.assignedOn)
        };
    }

    moveAllocationToInProgress(allotmentId, nextAllotmentType) {
        const nextInProgressRow = this.buildInProgressRowFromAllocation(allotmentId, nextAllotmentType);
        this.updateWindowRows(this.selectedWindowId, (windowRecord) => ({
            ...windowRecord,
            inProgressRows: [nextInProgressRow, ...(windowRecord.inProgressRows || []).filter((row) => row.id !== allotmentId)],
            allocatedRows: (windowRecord.allocatedRows || []).filter((row) => row.id !== allotmentId)
        }));
    }

    removeCheckedOutAllocation(allotmentId) {
        this.updateWindowRows(this.selectedWindowId, (windowRecord) => ({
            ...windowRecord,
            inProgressRows: (windowRecord.inProgressRows || []).filter((row) => row.id !== allotmentId),
            allocatedRows: (windowRecord.allocatedRows || []).filter((row) => row.id !== allotmentId)
        }));
    }

    applyAssignedRoomUpdate(sourceAllotmentId, resultAllotmentId, selectedRoom, mode, assignedAllotmentType) {
        const nextAllocatedRow = this.buildAllocatedRowFromAssignment(
            sourceAllotmentId,
            resultAllotmentId,
            selectedRoom,
            mode,
            assignedAllotmentType
        );
        this.updateWindowRows(this.selectedWindowId, (windowRecord) => {
            const allocatedRows = (windowRecord.allocatedRows || []).filter(
                (row) => row.id !== sourceAllotmentId && row.id !== nextAllocatedRow.id
            );
            const nextAllocatedRows = [nextAllocatedRow, ...allocatedRows];

            return {
                ...windowRecord,
                inProgressRows:
                    mode === 'inProgress'
                        ? (windowRecord.inProgressRows || []).filter((row) => row.id !== sourceAllotmentId)
                        : windowRecord.inProgressRows || [],
                allocatedRows: nextAllocatedRows
            };
        });
    }

    buildAllocatedDetailFromAssignment(sourceAllotmentId, resultAllotmentId, selectedRoom, mode, assignedAllotmentType) {
        const nextAllocatedRow = this.buildAllocatedRowFromAssignment(
            sourceAllotmentId,
            resultAllotmentId,
            selectedRoom,
            mode,
            assignedAllotmentType
        );
        const detail = this.selectedApplicationDetail?.allotmentId === sourceAllotmentId ? this.selectedApplicationDetail : null;

        return {
            detailType: 'allocated',
            allotmentId: nextAllocatedRow.id,
            studentName: getFirstFilledValue(detail?.studentName, nextAllocatedRow.student),
            rollNo: getFirstFilledValue(detail?.rollNo, nextAllocatedRow.rollNo),
            program: getFirstFilledValue(detail?.program, nextAllocatedRow.program),
            year: getFirstFilledValue(detail?.year, nextAllocatedRow.year),
            email: getFirstFilledValue(detail?.email),
            phone: getFirstFilledValue(detail?.phone),
            roomNumber: getFirstFilledValue(selectedRoom?.room, detail?.roomNumber, nextAllocatedRow.room),
            building: getFirstFilledValue(selectedRoom?.building, detail?.building, nextAllocatedRow.building),
            category: getFirstFilledValue(
                selectedRoom?.category,
                detail?.category,
                detail?.categoryApplied,
                nextAllocatedRow.category
            ),
            allotmentType: normalizeAllotmentTypeLabel(
                getFirstFilledValue(detail?.allotmentType, nextAllocatedRow.allotmentType)
            ),
            paymentStatus: getFirstFilledValue(detail?.paymentStatus, nextAllocatedRow.payment),
            assignmentSource: getFirstFilledValue(detail?.assignmentSource, nextAllocatedRow.source),
            assignedOn: getFirstFilledValue(detail?.assignedOn, nextAllocatedRow.assignedOn),
            roomPreferences: [],
            roommatePreference: {}
        };
    }

    async loadInProgressRows(windowId) {
        if (!windowId) {
            return;
        }

        this.isLoadingInProgress = true;
        try {
            const rows = await getInProgressRows({ windowId });
            this.windows = this.windows.map((windowRecord) =>
                windowRecord.id === windowId
                    ? {
                          ...windowRecord,
                          inProgressRows: (Array.isArray(rows) ? rows : []).map((row) => ({
                              ...row,
                              allotmentType: normalizeAllotmentTypeLabel(row.allotmentType)
                          }))
                      }
                    : windowRecord
            );
        } catch (error) {
            this.windows = this.windows.map((windowRecord) =>
                windowRecord.id === windowId
                    ? {
                          ...windowRecord,
                          inProgressRows: []
                      }
                    : windowRecord
            );
            this.showErrorToast('Unable to load in progress rows.', error);
        } finally {
            this.isLoadingInProgress = false;
        }
    }

    async loadAllocatedRows(windowId) {
        if (!windowId) {
            return;
        }

        this.isLoadingAllocated = true;
        try {
            const rows = await getAllocatedRows({ windowId });
            this.windows = this.windows.map((windowRecord) =>
                windowRecord.id === windowId
                    ? {
                          ...windowRecord,
                          allocatedRows: (Array.isArray(rows) ? rows : []).map((row) => ({
                              ...row,
                              allotmentType: normalizeAllotmentTypeLabel(row.allotmentType)
                          }))
                      }
                    : windowRecord
            );
        } catch (error) {
            this.windows = this.windows.map((windowRecord) =>
                windowRecord.id === windowId
                    ? {
                          ...windowRecord,
                          allocatedRows: []
                      }
                    : windowRecord
            );
            this.showErrorToast('Unable to load allocated rows.', error);
        } finally {
            this.isLoadingAllocated = false;
        }
    }

    async handleCycleChange(event) {
        this.selectedCycleId = event.target.value;
        this.selectedWindowId = '';
        this.activeView = 'inProgress';
        this.selectedApplicationDetail = null;
        this.closeAutoAllotmentModal();
        this.closeCancelModal();
        this.closeCheckoutModal();
        this.closeRejectModal();
        this.resetFilters();
        await this.loadWindowOptions();
    }

    async handleWindowChange(event) {
        this.selectedWindowId = event.target.value;
        this.activeView = 'inProgress';
        this.selectedApplicationDetail = null;
        this.closeAutoAllotmentModal();
        this.closeCancelModal();
        this.closeCheckoutModal();
        this.closeRejectModal();
        this.resetFilters();
        await this.loadSelectedWindowData(this.selectedWindowId);
    }

    handleViewChange(event) {
        const nextView = event.currentTarget.dataset.value;
        if (nextView) {
            this.activeView = nextView;
            this.selectedApplicationDetail = null;
        }
    }

    handleOpenAutoAllotmentModal(event) {
        if (!this.selectedWindow) {
            return;
        }

        this.closeAssignRoomModal();
        this.closeCancelModal();
        this.closeCheckoutModal();
        this.closeRejectModal();
        this.autoAllotmentModalMode = event.currentTarget.dataset.mode === 'configure' ? 'configure' : 'run';
        this.autoAllotmentDraft = cloneAutoAllotmentConfig(
            normalizeAutoAllotmentConfig(this.selectedWindow.autoAllotmentConfig, this.selectedWindow)
        );
        this.autoAllotmentRunAsType = resolveDefaultAssignmentAllotmentType(this.selectedWindow.allotmentType);
        this.isAutoAllotmentModalOpen = true;
    }

    handleCloseAutoAllotmentModal() {
        if (this.isRunningAutoAllotment) {
            return;
        }
        this.closeAutoAllotmentModal();
    }

    handleAutoAllotmentFieldChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }

        let value = event.target.value;
        if (field === 'batchSize') {
            value = value === '' ? '' : Number.parseInt(value, 10);
        }

        this.autoAllotmentDraft = {
            ...this.autoAllotmentDraft,
            [field]: value
        };
    }

    handleAutoAllotmentToggle(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }

        this.autoAllotmentDraft = {
            ...this.autoAllotmentDraft,
            [field]: event.target.checked
        };
    }

    handleAutoAllotmentRunAsChange(event) {
        this.autoAllotmentRunAsType = normalizeAssignmentAllotmentType(event.target.value);
    }

    async handleConfirmAutoAllotment() {
        if (!this.selectedWindow || !this.selectedWindowId) {
            return;
        }

        const normalizedConfig = normalizeAutoAllotmentConfig(this.autoAllotmentDraft, this.selectedWindow);

        try {
            await saveWindowAutoAllotmentConfig({
                windowId: this.selectedWindowId,
                allocationRule: normalizedConfig.allocationRule,
                batchProcessing: normalizedConfig.batchProcessing,
                batchSize: normalizedConfig.batchSize,
                batchGrouping: normalizedConfig.batchGrouping,
                previousYearCarryForward: normalizedConfig.previousYearCarryForward
            });
        } catch (error) {
            this.showErrorToast('Unable to save auto allotment configuration.', error);
            return;
        }

        this.updateWindowAutoAllotmentConfig(this.selectedWindowId, normalizedConfig);

        if (this.isAutoAllotmentConfigMode) {
            this.closeAutoAllotmentModal();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Configuration updated',
                    message: 'Auto allotment configuration was updated for this window.',
                    variant: 'success'
                })
            );
            return;
        }

        await this.runAutoAllotment(normalizedConfig, this.autoAllotmentRunAsType);
    }

    async handleOpenApplicationDetail(event) {
        const allotmentId = event.currentTarget.dataset.id;
        if (!allotmentId || !this.selectedWindowId) {
            return;
        }

        await this.loadApplicationDetail(allotmentId);
    }

    async handleOpenAllocatedDetail(event) {
        const allotmentId = event.currentTarget.dataset.id;
        if (!allotmentId || !this.selectedWindowId) {
            return;
        }

        await this.loadAllocationDetail(allotmentId);
    }

    handleBackToList() {
        this.selectedApplicationDetail = null;
        this.closeAutoAllotmentModal();
        this.closeAssignRoomModal();
        this.closeCancelModal();
        this.closeCheckoutModal();
        this.closeRejectModal();
    }

    async handleOpenAssignRoomModal(event) {
        await this.openAssignRoomModal({
            allotmentId: event.currentTarget.dataset.id,
            studentName: event.currentTarget.dataset.name,
            rollNo: event.currentTarget.dataset.roll,
            mode: event.currentTarget.dataset.mode || 'inProgress',
            presentation: event.currentTarget.dataset.presentation || 'table'
        });
    }

    handleOpenCancelModal(event) {
        this.openCancelModal({
            allotmentId: event.currentTarget.dataset.id,
            studentName: event.currentTarget.dataset.name
        });
    }

    handleOpenCheckoutModal(event) {
        this.openCheckoutModal({
            allotmentId: event.currentTarget.dataset.id,
            studentName: event.currentTarget.dataset.name
        });
    }

    handleOpenRejectModal(event) {
        this.openRejectModal({
            allotmentId: event.currentTarget.dataset.id,
            studentName: event.currentTarget.dataset.name
        });
    }

    async handlePrimaryDetailAction() {
        if (!this.selectedApplicationDetail || !this.selectedWindowId) {
            return;
        }

        await this.openAssignRoomModal({
            allotmentId: this.selectedApplicationDetail.allotmentId,
            studentName: this.selectedApplicationDetail.studentName,
            rollNo: this.selectedApplicationDetail.rollNo,
            mode: this.isAllocatedDetailView ? 'allocated' : 'inProgress',
            presentation: 'card'
        });
    }

    handleSecondaryDetailAction() {
        if (!this.selectedApplicationDetail) {
            return;
        }

        if (this.isAllocatedDetailView) {
            this.openCancelModal({
                allotmentId: this.selectedApplicationDetail.allotmentId,
                studentName: this.selectedApplicationDetail.studentName
            });
            return;
        }

        this.openRejectModal({
            allotmentId: this.selectedApplicationDetail.allotmentId,
            studentName: this.selectedApplicationDetail.studentName
        });
    }

    handleDetailCheckoutAction() {
        if (!this.isAllocatedDetailView || !this.selectedApplicationDetail) {
            return;
        }

        this.openCheckoutModal({
            allotmentId: this.selectedApplicationDetail.allotmentId,
            studentName: this.selectedApplicationDetail.studentName
        });
    }

    handleCloseCancelModal() {
        if (this.isCancellingAllocation) {
            return;
        }
        this.closeCancelModal();
    }

    async handleConfirmCancel() {
        if (!this.cancelModalAllotmentId || this.isCancellingAllocation || !this.selectedWindowId) {
            return;
        }

        const allotmentId = this.cancelModalAllotmentId;
        const studentName = this.cancelModalStudentName;
        const isCurrentDetail = this.selectedApplicationDetail?.allotmentId === allotmentId;

        this.isCancellingAllocation = true;
        try {
            await cancelAllocation({
                allotmentId,
                windowId: this.selectedWindowId
            });
            this.closeCancelModal();
            await this.loadSelectedWindowData(this.selectedWindowId);
            this.activeView = 'inProgress';

            if (isCurrentDetail) {
                this.selectedApplicationDetail = null;
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Allocation cancelled',
                    message: studentName
                        ? `${studentName}'s room allocation was cancelled.`
                        : 'Room allocation was cancelled.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.showErrorToast('Unable to cancel allocation.', error);
        } finally {
            this.isCancellingAllocation = false;
        }
    }

    handleCloseCheckoutModal() {
        if (this.isCheckingOutAllocation) {
            return;
        }
        this.closeCheckoutModal();
    }

    async handleConfirmCheckout() {
        if (!this.checkoutModalAllotmentId || this.isCheckingOutAllocation || !this.selectedWindowId) {
            return;
        }

        const allotmentId = this.checkoutModalAllotmentId;
        const studentName = this.checkoutModalStudentName;
        const isCurrentDetail = this.selectedApplicationDetail?.allotmentId === allotmentId;

        this.isCheckingOutAllocation = true;
        try {
            await checkoutAllocation({
                allotmentId,
                windowId: this.selectedWindowId
            });

            this.closeCheckoutModal();
            await this.loadSelectedWindowData(this.selectedWindowId);

            if (isCurrentDetail) {
                this.selectedApplicationDetail = null;
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Checkout completed',
                    message: studentName
                        ? `${studentName} checked out successfully.`
                        : 'Allocation checked out successfully.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.showErrorToast('Unable to checkout allocation.', error);
        } finally {
            this.isCheckingOutAllocation = false;
        }
    }

    handleCloseAssignRoomModal() {
        this.closeAssignRoomModal();
    }

    handleOpenAssignRunAsModal() {
        if (this.isAssignConfirmDisabled) {
            return;
        }
        this.isAssignRunAsModalOpen = true;
    }

    handleCloseAssignRunAsModal() {
        if (this.isSavingAssignRoom) {
            return;
        }
        this.closeAssignRunAsModal();
    }

    handleAssignAllotmentTypeChange(event) {
        this.assignRoomAllotmentType = normalizeAssignmentAllotmentType(event.target.value);
    }

    handleSelectAssignableRoom(event) {
        const roomId = event.currentTarget.dataset.id;
        const option = this.assignRoomOptions.find((row) => row.id === roomId);
        if (!option || !option.selectable) {
            return;
        }

        this.selectedAssignRoomId = roomId;
    }

    async handleConfirmAssignRoom() {
        if (!this.hasSelectedAssignRoom || !this.assignRoomAllotmentId || !this.selectedWindowId || this.isSavingAssignRoom) {
            return;
        }

        const allotmentId = this.assignRoomAllotmentId;
        const roomId = this.selectedAssignRoomId;
        const selectedRoom = this.selectedAssignRoom;
        const studentName = this.assignRoomStudentName;
        const mode = this.assignRoomMode;
        const assignedAllotmentType = normalizeAssignmentAllotmentType(this.assignRoomAllotmentType);
        const isCurrentDetail = this.selectedApplicationDetail?.allotmentId === allotmentId;

        this.isSavingAssignRoom = true;
        try {
            const assignedAllotmentId = await assignRoomToAllotment({
                allotmentId,
                roomId,
                windowId: this.selectedWindowId,
                allotmentType: assignedAllotmentType
            });

            this.closeAssignRunAsModal();
            this.closeAssignRoomModal();
            this.activeView = 'allocated';

            if (mode === 'allocated') {
                const nextAllotmentId = assignedAllotmentId || allotmentId;
                this.applyAssignedRoomUpdate(allotmentId, nextAllotmentId, selectedRoom, mode, assignedAllotmentType);
                if (isCurrentDetail) {
                    this.selectedApplicationDetail = this.buildAllocatedDetailFromAssignment(
                        allotmentId,
                        nextAllotmentId,
                        selectedRoom,
                        mode,
                        assignedAllotmentType
                    );
                }
            } else {
                await this.loadSelectedWindowData(this.selectedWindowId);
                if (isCurrentDetail) {
                    this.selectedApplicationDetail = null;
                    if (assignedAllotmentId) {
                        await this.loadAllocationDetail(assignedAllotmentId);
                    }
                }
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: mode === 'allocated' ? 'Room reassigned' : 'Room assigned',
                    message: this.buildAssignSuccessMessage(studentName, selectedRoom),
                    variant: 'success'
                })
            );
        } catch (error) {
            this.showErrorToast('Unable to assign room.', error);
        } finally {
            this.isSavingAssignRoom = false;
        }
    }

    handleRejectReasonChange(event) {
        this.rejectModalReason = event.target.value || '';
    }

    handleCloseRejectModal() {
        this.closeRejectModal();
    }

    handleConfirmReject() {
        if (this.isRejectDisabled || !this.rejectModalAllotmentId || !this.selectedWindowId) {
            return;
        }
        const applicationId = this.rejectModalAllotmentId;
        const studentName = this.rejectModalStudentName;
        const reason = this.rejectModalReason.trim();
        const isCurrentDetail = this.selectedApplicationDetail?.allotmentId === applicationId;

        rejectApplication({
            applicationId,
            rejectionReason: reason
        })
            .then(async () => {
                this.closeRejectModal();
                await this.loadSelectedWindowData(this.selectedWindowId);
                this.activeView = 'inProgress';

                if (isCurrentDetail) {
                    this.selectedApplicationDetail = null;
                }

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Application rejected',
                        message: studentName
                            ? `${studentName}'s application was rejected.`
                            : 'Application was rejected.',
                        variant: 'success'
                    })
                );
            })
            .catch((error) => {
                this.showErrorToast('Unable to reject application.', error);
            });
    }

    handleToggleFilters() {
        this.isFilterPanelOpen = !this.isFilterPanelOpen;
    }

    handleFilterChange(event) {
        const key = event.target.name;
        this.filters = {
            ...this.filters,
            [key]: event.target.value
        };
    }

    handleClearFilters() {
        this.resetFilters();
        Promise.resolve().then(() => {
            this.syncFilterSelectValues();
        });
    }

    resetFilters() {
        this.filters = {
            program: 'all',
            payment: 'all',
            status: 'all',
            building: 'all'
        };
    }

    syncFilterSelectValues() {
        const filterSelects = this.template.querySelectorAll('.acm-select--filter');
        if (!filterSelects || filterSelects.length === 0) {
            return;
        }

        filterSelects.forEach((selectElement) => {
            const fieldName = selectElement.name;
            const nextValue = fieldName && Object.prototype.hasOwnProperty.call(this.filters, fieldName)
                ? this.filters[fieldName]
                : 'all';

            if (selectElement.value !== nextValue) {
                selectElement.value = nextValue;
            }
        });
    }

    matchesBaseFilters(row) {
        const program = this.filters.program;
        const payment = this.filters.payment;

        if (program !== 'all' && row.program !== program) {
            return false;
        }

        if (payment !== 'all' && row.payment !== payment) {
            return false;
        }

        return true;
    }

    matchesInProgressFilters(row) {
        if (!this.matchesBaseFilters(row)) {
            return false;
        }

        const status = this.filters.status;

        if (status !== 'all' && row.status !== status) {
            return false;
        }

        return true;
    }

    matchesAllocatedFilters(row) {
        if (!this.matchesBaseFilters(row)) {
            return false;
        }

        const building = this.filters.building;
        if (building !== 'all' && row.building !== building) {
            return false;
        }

        return true;
    }

    getPaymentPillClass(paymentValue) {
        if (paymentValue === 'Paid') {
            return 'acm-pill acm-pill--green-soft';
        }
        if (paymentValue === 'Pending') {
            return 'acm-pill acm-pill--amber-soft';
        }
        if (paymentValue === 'Failed') {
            return 'acm-pill acm-pill--red-soft';
        }
        return 'acm-pill acm-pill--gray-soft';
    }

    getStatusPillClass(statusValue) {
        if (statusValue === 'Submitted') {
            return 'acm-pill acm-pill--blue-soft';
        }
        if (statusValue === 'Approved') {
            return 'acm-pill acm-pill--green-soft';
        }
        if (statusValue === 'Pending') {
            return 'acm-pill acm-pill--amber-soft';
        }
        if (statusValue === 'Canceled' || statusValue === 'Rejected') {
            return 'acm-pill acm-pill--red-soft';
        }
        if (statusValue === 'Provisional Alloted') {
            return 'acm-pill acm-pill--blue-soft';
        }
        if (statusValue === 'Alloted') {
            return 'acm-pill acm-pill--green-soft';
        }
        return 'acm-pill acm-pill--gray-soft';
    }

    getRoomStatusPillClass(statusTone) {
        if (statusTone === 'green') {
            return 'acm-pill acm-pill--green-soft';
        }
        if (statusTone === 'amber') {
            return 'acm-pill acm-pill--amber-soft';
        }
        if (statusTone === 'red') {
            return 'acm-pill acm-pill--red-soft';
        }
        return 'acm-pill acm-pill--gray-soft';
    }

    getAvailabilityPillClass(tone) {
        if (tone === 'success') {
            return 'acm-pill acm-pill--green-soft';
        }
        if (tone === 'danger') {
            return 'acm-pill acm-pill--red-soft';
        }
        return 'acm-pill acm-pill--gray-soft';
    }

    normalizeApplicationDetail(detail) {
        const roomPreferences = Array.isArray(detail?.roomPreferences)
            ? detail.roomPreferences.map((preference) => ({
                  ...preference,
                  availabilityClass: preference.availabilityLabel
                      ? this.getAvailabilityPillClass(preference.availabilityTone)
                      : '',
                  orderLabel: preference.order ? String(preference.order) : ''
              }))
            : [];

        const hasRoommatePreference = !!detail?.roommatePreference?.name;
        const roommatePreference = hasRoommatePreference
            ? {
                  ...detail.roommatePreference,
                  rollNo: detail.roommatePreference.rollNo || '--',
                  currentStatus: detail.roommatePreference.currentStatus || '--',
                  samePreferenceSelected: detail.roommatePreference.samePreferenceSelected || '--',
                  cardClass: 'acm-roommate-card acm-roommate-card--success',
                  matchClass: detail.roommatePreference.matchLabel
                      ? 'acm-pill acm-pill--green-soft'
                      : ''
              }
            : {};

        return {
            detailType: 'inProgress',
            allotmentId: detail?.allotmentId || '',
            studentName: detail?.studentName || '',
            rollNo: detail?.rollNo || '',
            program: detail?.program || '',
            year: detail?.year || '',
            email: detail?.email || '',
            phone: detail?.phone || '',
            allotmentType: normalizeAllotmentTypeLabel(detail?.allotmentType),
            categoryApplied: detail?.categoryApplied || '',
            applicationStatus: detail?.applicationStatus || '',
            paymentStatus: detail?.paymentStatus || '',
            appliedOn: detail?.appliedOn || '',
            roomPreferences,
            roommatePreference
        };
    }

    normalizeAllocatedDetail(detail) {
        return {
            detailType: 'allocated',
            allotmentId: detail?.allotmentId || '',
            studentName: detail?.studentName || '',
            rollNo: detail?.rollNo || '',
            program: detail?.program || '',
            year: detail?.year || '',
            email: detail?.email || '',
            phone: detail?.phone || '',
            roomNumber: detail?.roomNumber || '',
            building: detail?.building || '',
            category: detail?.category || '',
            allotmentType: normalizeAllotmentTypeLabel(detail?.allotmentType),
            paymentStatus: detail?.paymentStatus || '',
            assignmentSource: detail?.assignmentSource || '',
            assignedOn: detail?.assignedOn || '',
            roomPreferences: [],
            roommatePreference: {}
        };
    }

    validateAutoAllotmentConfig(config) {
        if (config.batchProcessing) {
            const batchSize = Number.parseInt(config.batchSize, 10);
            if (!Number.isFinite(batchSize) || batchSize <= 0) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Invalid batch size',
                        message: 'Batch size must be greater than 0.',
                        variant: 'error'
                    })
                );
                return false;
            }
        }

        return true;
    }

    buildAutoAllotmentGroups(rows, config) {
        if (!config.batchProcessing) {
            return [rows];
        }

        const groupedRows = new Map();
        rows.forEach((row) => {
            let keyField = row.program;
            if (config.batchGrouping === 'category') {
                keyField = row.category;
            } else if (config.batchGrouping === 'year') {
                keyField = row.academicYear || row.year;
            }
            const groupKey = keyField || 'Ungrouped';
            if (!groupedRows.has(groupKey)) {
                groupedRows.set(groupKey, []);
            }
            groupedRows.get(groupKey).push(row);
        });

        return Array.from(groupedRows.values());
    }

    buildAutoAllotmentQueue(rows, config) {
        const indexedRows = (Array.isArray(rows) ? rows : []).map((row, index) => ({
            row,
            index
        }));
        const firstComeComparator = (left, right) => right.index - left.index;
        if (config.allocationRule === 'programPriority') {
            const priorityPlanIds = Array.isArray(this.selectedWindow?.programPriorityPlanIds)
                ? this.selectedWindow.programPriorityPlanIds
                : [];
            indexedRows.sort((left, right) => {
                const leftPlanRank = this.getAutoAllotmentProgramPlanRank(left.row, priorityPlanIds);
                const rightPlanRank = this.getAutoAllotmentProgramPlanRank(right.row, priorityPlanIds);
                if (leftPlanRank !== rightPlanRank) {
                    return leftPlanRank - rightPlanRank;
                }

                const programCompare = `${left.row.program || ''}`.localeCompare(`${right.row.program || ''}`);
                if (programCompare !== 0) {
                    return programCompare;
                }
                return firstComeComparator(left, right);
            });
        } else if (config.allocationRule === 'yearPriority') {
            indexedRows.sort((left, right) => {
                const leftYearRank = this.getAutoAllotmentYearRank(left.row);
                const rightYearRank = this.getAutoAllotmentYearRank(right.row);
                if (leftYearRank !== rightYearRank) {
                    return rightYearRank - leftYearRank;
                }

                const yearCompare = `${left.row.academicYear || left.row.year || ''}`.localeCompare(
                    `${right.row.academicYear || right.row.year || ''}`
                );
                if (yearCompare !== 0) {
                    return yearCompare;
                }
                return firstComeComparator(left, right);
            });
        } else {
            indexedRows.sort(firstComeComparator);
        }

        return indexedRows.map((entry) => entry.row);
    }

    getAutoAllotmentProgramPlanRank(row, priorityPlanIds) {
        const planId = `${row?.programPlanId || ''}`.trim();
        if (!planId) {
            return Number.MAX_SAFE_INTEGER;
        }

        const rank = priorityPlanIds.indexOf(planId);
        return rank === -1 ? Number.MAX_SAFE_INTEGER : rank;
    }

    getAutoAllotmentYearRank(row) {
        const explicitRank = Number.parseInt(row?.yearPriorityRank, 10);
        if (Number.isFinite(explicitRank)) {
            return explicitRank;
        }

        const text = `${row?.year || ''}`;
        const match = text.match(/(\d+)/);
        if (!match) {
            return 0;
        }

        const value = Number.parseInt(match[1], 10);
        return Number.isFinite(value) ? value : 0;
    }

    buildAutoAllotmentBatches(rows, config) {
        const groupedRows = this.buildAutoAllotmentGroups(rows, config);
        if (!config.batchProcessing) {
            return groupedRows;
        }

        const batchSize = Math.max(1, Number.parseInt(config.batchSize, 10) || DEFAULT_AUTO_ALLOTMENT_BATCH_SIZE);
        const batches = [];
        groupedRows.forEach((groupRows) => {
            for (let index = 0; index < groupRows.length; index += batchSize) {
                batches.push(groupRows.slice(index, index + batchSize));
            }
        });
        return batches;
    }

    pickAutoAllotmentRoom(row, roomOptions, config) {
        const selectableOptions = (Array.isArray(roomOptions) ? roomOptions : []).filter((option) => option?.selectable);
        if (selectableOptions.length === 0) {
            return null;
        }

        if (config.previousYearCarryForward) {
            const previousRoom = selectableOptions.find(
                (option) => option.isPreviousRoom && Math.max((option.capacity || 0) - (option.occupancy || 0), 0) > 0
            );
            if (previousRoom) {
                return previousRoom;
            }
        }

        return [...selectableOptions].sort((left, right) => {
            return compareAssignableRoomOptions(left, right);
        })[0];
    }

    async runAutoAllotment(config, runAsAllotmentType) {
        const queue = this.buildAutoAllotmentQueue(
            (this.selectedWindow?.inProgressRows || []).filter((row) => !!row.id),
            config
        );
        const assignmentAllotmentType = normalizeAssignmentAllotmentType(runAsAllotmentType);
        if (queue.length === 0) {
            this.closeAutoAllotmentModal();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Nothing to run',
                    message: 'No in-progress applications available.',
                    variant: 'info'
                })
            );
            return;
        }

        this.isRunningAutoAllotment = true;
        let assignedCount = 0;
        let skippedCount = 0;

        try {
            const batches = this.buildAutoAllotmentBatches(queue, config);
            for (const batch of batches) {
                for (const row of batch) {
                    try {
                        const roomOptions = await getAssignableRooms({
                            allotmentId: row.id,
                            windowId: this.selectedWindowId
                        });
                        const selectedRoom = this.pickAutoAllotmentRoom(row, roomOptions, config);
                        if (!selectedRoom) {
                            skippedCount += 1;
                            continue;
                        }

                        await assignRoomToAllotment({
                            allotmentId: row.id,
                            roomId: selectedRoom.id,
                            windowId: this.selectedWindowId,
                            allotmentType: assignmentAllotmentType
                        });
                        assignedCount += 1;
                    } catch (error) {
                        skippedCount += 1;
                    }
                }
            }

            await this.loadSelectedWindowData(this.selectedWindowId);

            this.closeAutoAllotmentModal();

            const total = queue.length;
            const variant = skippedCount > 0 ? 'warning' : 'success';
            const message = skippedCount > 0
                ? `${assignedCount} of ${total} application(s) were allotted. ${skippedCount} skipped.`
                : `${assignedCount} application(s) were allotted successfully.`;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Auto allotment completed',
                    message,
                    variant
                })
            );
        } catch (error) {
            this.showErrorToast('Unable to run auto allotment.', error);
        } finally {
            this.isRunningAutoAllotment = false;
        }
    }

    closeAutoAllotmentModal() {
        this.isAutoAllotmentModalOpen = false;
        this.autoAllotmentModalMode = 'run';
        this.isRunningAutoAllotment = false;
        this.autoAllotmentDraft = cloneAutoAllotmentConfig();
        this.autoAllotmentRunAsType = ALLOTMENT_TYPE_PROVISIONAL;
    }

    buildAssignSuccessMessage(studentName, selectedRoom) {
        const roomLabel = [selectedRoom?.room, selectedRoom?.building].filter((value) => !!value).join(' - ');
        if (studentName && roomLabel) {
            return `${studentName} assigned to ${roomLabel}.`;
        }
        if (roomLabel) {
            return `${roomLabel} assigned successfully.`;
        }
        return 'Room assigned successfully.';
    }

    async loadApplicationDetail(allotmentId) {
        this.isLoadingDetail = true;
        this.selectedApplicationDetail = {
            allotmentId,
            detailType: 'inProgress',
            roomPreferences: [],
            roommatePreference: {}
        };
        try {
            const detail = await getInProgressApplicationDetail({
                allotmentId,
                windowId: this.selectedWindowId
            });
            this.selectedApplicationDetail = this.normalizeApplicationDetail(detail);
        } catch (error) {
            this.selectedApplicationDetail = null;
            this.showErrorToast('Unable to load application detail.', error);
        } finally {
            this.isLoadingDetail = false;
        }
    }

    async loadAllocationDetail(allotmentId) {
        this.isLoadingDetail = true;
        this.selectedApplicationDetail = {
            allotmentId,
            detailType: 'allocated'
        };
        try {
            const detail = await getAllocatedDetail({
                allotmentId,
                windowId: this.selectedWindowId
            });
            this.selectedApplicationDetail = this.normalizeAllocatedDetail(detail);
        } catch (error) {
            this.selectedApplicationDetail = null;
            this.showErrorToast('Unable to load allocation detail.', error);
        } finally {
            this.isLoadingDetail = false;
        }
    }

    showErrorToast(title, error) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message: this.getErrorMessage(error),
                variant: 'error'
            })
        );
    }

    getErrorMessage(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).filter((message) => !!message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown error';
    }

    openCancelModal({ allotmentId = '', studentName = '' } = {}) {
        this.closeAutoAllotmentModal();
        this.closeAssignRoomModal();
        this.closeCheckoutModal();
        this.closeRejectModal();
        this.cancelModalAllotmentId = allotmentId || '';
        this.cancelModalStudentName = studentName || '';
        this.isCancelModalOpen = true;
    }

    closeCancelModal() {
        this.isCancelModalOpen = false;
        this.isCancellingAllocation = false;
        this.cancelModalAllotmentId = '';
        this.cancelModalStudentName = '';
    }

    openCheckoutModal({ allotmentId = '', studentName = '' } = {}) {
        this.closeAutoAllotmentModal();
        this.closeAssignRoomModal();
        this.closeCancelModal();
        this.closeRejectModal();
        this.checkoutModalAllotmentId = allotmentId || '';
        this.checkoutModalStudentName = studentName || '';
        this.isCheckoutModalOpen = true;
    }

    closeCheckoutModal() {
        this.isCheckoutModalOpen = false;
        this.isCheckingOutAllocation = false;
        this.checkoutModalAllotmentId = '';
        this.checkoutModalStudentName = '';
    }

    openRejectModal({ allotmentId = '', studentName = '' } = {}) {
        this.closeAutoAllotmentModal();
        this.closeAssignRoomModal();
        this.closeCancelModal();
        this.closeCheckoutModal();
        this.rejectModalAllotmentId = allotmentId || '';
        this.rejectModalStudentName = studentName || '';
        this.rejectModalReason = '';
        this.isRejectModalOpen = true;
    }

    closeRejectModal() {
        this.isRejectModalOpen = false;
        this.rejectModalAllotmentId = '';
        this.rejectModalStudentName = '';
        this.rejectModalReason = '';
    }

    async openAssignRoomModal({ allotmentId = '', studentName = '', rollNo = '', mode = 'inProgress', presentation = 'table' } = {}) {
        if (!allotmentId || !this.selectedWindowId) {
            return;
        }

        this.closeAutoAllotmentModal();
        this.closeCancelModal();
        this.closeCheckoutModal();
        this.closeRejectModal();
        this.assignRoomAllotmentId = allotmentId;
        this.assignRoomStudentName = studentName || '';
        this.assignRoomRollNo = rollNo || '';
        this.assignRoomMode = mode || 'inProgress';
        this.assignRoomPresentation = presentation === 'card' ? 'card' : 'table';
        this.assignRoomAllotmentType = resolveDefaultAssignmentAllotmentType(this.selectedWindow?.allotmentType);
        this.assignRoomOptions = [];
        this.selectedAssignRoomId = '';
        this.isAssignRoomModalOpen = true;
        this.isLoadingAssignableRooms = true;

        try {
            const rows = await getAssignableRooms({
                allotmentId,
                windowId: this.selectedWindowId
            });
            this.assignRoomOptions = Array.isArray(rows) ? rows : [];
        } catch (error) {
            this.assignRoomOptions = [];
            this.showErrorToast('Unable to load rooms.', error);
        } finally {
            this.isLoadingAssignableRooms = false;
        }
    }

    closeAssignRoomModal() {
        this.isAssignRoomModalOpen = false;
        this.isAssignRunAsModalOpen = false;
        this.isLoadingAssignableRooms = false;
        this.isSavingAssignRoom = false;
        this.assignRoomStudentName = '';
        this.assignRoomRollNo = '';
        this.assignRoomAllotmentId = '';
        this.assignRoomMode = 'inProgress';
        this.assignRoomPresentation = 'table';
        this.assignRoomAllotmentType = ALLOTMENT_TYPE_PROVISIONAL;
        this.assignRoomOptions = [];
        this.selectedAssignRoomId = '';
    }

    closeAssignRunAsModal() {
        this.isAssignRunAsModalOpen = false;
    }
}