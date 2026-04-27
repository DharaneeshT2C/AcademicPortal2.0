import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { api } from 'lwc';
import getCycles from '@salesforce/apex/KenHostelCycleController.getCycles';
import getAcademicYearOptions from '@salesforce/apex/KenHostelCycleController.getAcademicYearOptions';
import getPreviousCycleOptions from '@salesforce/apex/KenHostelCycleController.getPreviousCycleOptions';
import getStatusOptions from '@salesforce/apex/KenHostelCycleController.getStatusOptions';
import getWindowFormOptions from '@salesforce/apex/KenHostelCycleController.getWindowFormOptions';
import getBuildingAllocationPreview from '@salesforce/apex/KenHostelCycleController.getBuildingAllocationPreview';
import getWindows from '@salesforce/apex/KenHostelCycleController.getWindows';
import createCycle from '@salesforce/apex/KenHostelCycleController.createCycle';
import updateCycle from '@salesforce/apex/KenHostelCycleController.updateCycle';
import deleteCycle from '@salesforce/apex/KenHostelCycleController.deleteCycle';
import createWindow from '@salesforce/apex/KenHostelCycleController.createWindow';
import updateWindow from '@salesforce/apex/KenHostelCycleController.updateWindow';
import deleteWindow from '@salesforce/apex/KenHostelCycleController.deleteWindow';

const LIMIT_MODE_FULL_CAPACITY = 'Use Full Capacity';
const LIMIT_MODE_CUSTOM_CAP = 'Custom Cap';

let windowScopeOptionsCache = null;
let windowScopeOptionsPromise = null;

function mapWindowScopeOptions(windowFormOptions) {
    return {
        programPathways: (windowFormOptions?.programPathways || []).map((item) => ({
            label: item.label,
            value: item.value
        })),
        buildings: (windowFormOptions?.buildings || []).map((item) => ({
            label: item.label,
            value: item.value
        })),
        floors: (windowFormOptions?.floors || []).map((item) => ({
            label: item.label,
            value: item.value,
            buildingValue: item.buildingValue
        })),
        roomCategories: (windowFormOptions?.roomCategories || []).map((item) => ({
            label: item.label,
            value: item.value,
            buildingValues: [...(item.buildingValues || [])],
            floorValues: [...(item.floorValues || [])]
        }))
    };
}

export default class KenHostelCycleScreen extends LightningElement {
    isCreateView = false;
    isDetailView = false;
    isWindowCreateView = false;
    isEditMode = false;
    isWindowEditMode = false;
    isCarryForwardEnabled = false;
    isSaving = false;
    isSavingWindow = false;
    isLoading = false;
    isLoadingWindowFormOptions = false;

    rows = [];
    editingCycleId = null;
    editingWindowId = null;
    selectedCycle = null;
    academicYearOptions = [];
    previousCycleOptions = [];
    statusOptions = [];
    windowScopeOptions = {
        programPathways: [],
        buildings: [],
        floors: [],
        roomCategories: []
    };
    openScopeDropdown = '';

    windowsByCycleId = {};
    buildingAllocationPreviewRequestId = 0;
    initializePromise = null;

    form = {
        name: '',
        academicYears: [],
        startDate: '',
        endDate: '',
        status: '',
        previousCycleId: ''
    };

    windowForm = {
        name: '',
        startDate: '',
        endDate: '',
        startTime: '',
        endTime: '',
        paymentDeadline: '',
        allotmentType: 'Direct',
        programPathwayIds: [],
        buildingIds: [],
        floorValues: [],
        roomCategoryIds: [],
        buildingAllocationRows: [],
        enableRoomPreference: false,
        maxRoomPreferences: '',
        enableMaximumRoomCapacity: false,
        maxRoomCapacity: '',
        allowRoommatePreference: false
    };

    connectedCallback() {
        this.boundHandleDocumentClick = this.handleDocumentClick.bind(this);
        document.addEventListener('click', this.boundHandleDocumentClick);
        this.initializePromise = this.initialize();
    }

    disconnectedCallback() {
        if (this.boundHandleDocumentClick) {
            document.removeEventListener('click', this.boundHandleDocumentClick);
        }
    }

    async initialize() {
        this.isLoading = true;
        try {
            const [rows, academicYears, previousCycles, statuses] = await Promise.all([
                getCycles(),
                getAcademicYearOptions(),
                getPreviousCycleOptions(),
                getStatusOptions()
            ]);
            this.rows = (rows || []).map((row, index) => ({
                ...row,
                code: `CYC-${String(index + 1).padStart(3, '0')}`
            }));
            this.academicYearOptions = (academicYears || []).map((item) => ({
                label: item.label,
                value: item.value
            }));
            this.previousCycleOptions = (previousCycles || []).map((item) => ({
                label: item.label,
                value: item.value
            }));
            this.statusOptions = (statuses || []).map((item) => ({
                label: item.label,
                value: item.value
            }));

            if (windowScopeOptionsCache) {
                this.windowScopeOptions = windowScopeOptionsCache;
            }
            if (!this.form.status && this.statusOptions.length) {
                this.form = { ...this.form, status: this.statusOptions[0].value };
            }
        } catch (error) {
            this.toast('Error', this.errorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    @api
    async openCreateCycleForm() {
        if (this.initializePromise) {
            await this.initializePromise;
        }
        this.handleOpenCreateCycle();
    }

    @api
    async openAddWindowForm(cycleId) {
        if (this.initializePromise) {
            await this.initializePromise;
        }

        const resolvedCycleId = cycleId || this.selectedCycle?.id || this.rows?.[0]?.id;
        if (!resolvedCycleId) {
            this.handleOpenCreateCycle();
            return;
        }

        await this.openCycleDetail(resolvedCycleId);
        this.handleOpenAddWindow();
    }

    async ensureWindowScopeOptionsLoaded() {
        if (windowScopeOptionsCache) {
            this.windowScopeOptions = windowScopeOptionsCache;
            return;
        }

        this.isLoadingWindowFormOptions = true;
        try {
            if (!windowScopeOptionsPromise) {
                windowScopeOptionsPromise = getWindowFormOptions()
                    .then((response) => {
                        windowScopeOptionsCache = mapWindowScopeOptions(response);
                        return windowScopeOptionsCache;
                    })
                    .finally(() => {
                        windowScopeOptionsPromise = null;
                    });
            }

            const resolvedOptions = await windowScopeOptionsPromise;
            if (resolvedOptions) {
                this.windowScopeOptions = resolvedOptions;
            }
        } catch (error) {
            this.toast('Error', this.errorMessage(error), 'error');
        } finally {
            this.isLoadingWindowFormOptions = false;
        }
    }

    getDefaultWindowForm() {
        return {
            name: '',
            startDate: '',
            endDate: '',
            roomAllotmentStartDate: '',
            roomAllotmentEndDate: '',
            startTime: '',
            endTime: '',
            paymentDeadline: '',
            allotmentType: 'Direct',
            programPathwayIds: [],
            buildingIds: [],
            floorValues: [],
            roomCategoryIds: [],
            buildingAllocationRows: [],
            enableRoomPreference: false,
            maxRoomPreferences: '',
            enableMaximumRoomCapacity: false,
            maxRoomCapacity: '',
            allowRoommatePreference: false
        };
    }

    buildWindowForm(windowRecord) {
        if (!windowRecord) {
            return this.getDefaultWindowForm();
        }

        return this.syncWindowBuildingAllocationRows({
            name: windowRecord.name || '',
            startDate: windowRecord.startDate || '',
            endDate: windowRecord.endDate || '',
            roomAllotmentStartDate: windowRecord.roomAllotmentStartDate || '',
            roomAllotmentEndDate: windowRecord.roomAllotmentEndDate || '',
            startTime: windowRecord.startTime || '',
            endTime: windowRecord.endTime || '',
            paymentDeadline: windowRecord.paymentDeadline || '',
            allotmentType: this.resolveWindowAllotmentMode(windowRecord.allotmentType),
            programPathwayIds: [...(windowRecord.programPathwayIds || [])],
            buildingIds: [...(windowRecord.buildingIds || [])],
            floorValues: [],
            roomCategoryIds: [...(windowRecord.roomCategoryIds || [])],
            buildingAllocationRows: (windowRecord.buildingAllocationRows || []).map((item) => ({
                buildingId: item.buildingId,
                building: item.building || '',
                roomCount: this.toNonNegativeInteger(item.roomCount),
                totalCapacity: this.toNonNegativeInteger(item.totalCapacity),
                alreadyAllocated: this.toNonNegativeInteger(item.alreadyAllocated),
                limitMode: item.limitMode || LIMIT_MODE_FULL_CAPACITY,
                allocationCap: item.allocationCap || ''
            })),
            enableRoomPreference: windowRecord.enableRoomPreference === true,
            maxRoomPreferences: windowRecord.maxRoomPreferences || '',
            enableMaximumRoomCapacity: windowRecord.enableMaximumRoomCapacity === true,
            maxRoomCapacity: windowRecord.maxRoomCapacity || '',
            allowRoommatePreference: windowRecord.allowRoommatePreference === true
        });
    }

    isProvisionalWindowAllotmentType(typeValue) {
        const normalizedKey = this.normalizeKey(typeValue);
        return normalizedKey === 'provisional'
            || normalizedKey === 'provisionalallotment'
            || normalizedKey === 'preferenceselected';
    }

    resolveWindowAllotmentMode(typeValue) {
        return this.isProvisionalWindowAllotmentType(typeValue) ? 'Provisional' : 'Direct';
    }

    getBuildingLabel(buildingId) {
        const option = (this.windowScopeOptions.buildings || []).find((item) => item.value === buildingId);
        return option?.label || '';
    }

    toNonNegativeInteger(value) {
        const numeric = parseInt(value, 10);
        return Number.isFinite(numeric) && numeric >= 0 ? numeric : 0;
    }

    normalizeNonNegativeInteger(value, allowBlank = false) {
        if (value === '' || value === null || value === undefined) {
            return allowBlank ? '' : '0';
        }
        const numeric = parseInt(value, 10);
        if (!Number.isFinite(numeric) || numeric < 0) {
            return allowBlank ? '' : '0';
        }
        return String(numeric);
    }

    decorateBuildingAllocationRow(row) {
        const normalizedLimitMode = row.limitMode === LIMIT_MODE_CUSTOM_CAP
            ? LIMIT_MODE_CUSTOM_CAP
            : LIMIT_MODE_FULL_CAPACITY;
        const roomCount = this.toNonNegativeInteger(row.roomCount);
        const totalCapacity = this.toNonNegativeInteger(row.totalCapacity);
        const alreadyAllocated = this.toNonNegativeInteger(row.alreadyAllocated);
        const allocationCap = normalizedLimitMode === LIMIT_MODE_CUSTOM_CAP
            ? this.normalizeNonNegativeInteger(row.allocationCap, true)
            : String(totalCapacity);
        const allocationCapNumericValue = parseInt(allocationCap, 10);
        const hasAllocationCapError = normalizedLimitMode === LIMIT_MODE_CUSTOM_CAP
            && Number.isFinite(allocationCapNumericValue)
            && allocationCapNumericValue > totalCapacity;
        const allocationCapErrorMessage = hasAllocationCapError
            ? `Custom limit cannot exceed total capacity (${totalCapacity}).`
            : '';

        return {
            key: row.buildingId,
            buildingId: row.buildingId,
            building: row.building || this.getBuildingLabel(row.buildingId),
            roomCount,
            totalCapacity,
            alreadyAllocated,
            limitMode: normalizedLimitMode,
            allocationCap,
            isFullCapacity: normalizedLimitMode === LIMIT_MODE_FULL_CAPACITY,
            isCustomCap: normalizedLimitMode === LIMIT_MODE_CUSTOM_CAP,
            isAllocationCapLocked: normalizedLimitMode === LIMIT_MODE_FULL_CAPACITY,
            hasAllocationCapError,
            allocationCapErrorMessage,
            allocationCapInputClass: hasAllocationCapError
                ? 'hc-table-input hc-table-input-error'
                : 'hc-table-input'
        };
    }

    syncWindowBuildingAllocationRows(form, previewRows = []) {
        const previewByBuildingId = new Map(
            (previewRows || [])
                .filter((item) => item?.buildingId)
                .map((item) => [item.buildingId, item])
        );
        const existingRowsByBuildingId = new Map(
            (form?.buildingAllocationRows || [])
                .filter((item) => item?.buildingId)
                .map((item) => [item.buildingId, item])
        );

        const rows = (form?.buildingIds || []).map((buildingId) => {
            const existingRow = existingRowsByBuildingId.get(buildingId) || {};
            const previewRow = previewByBuildingId.get(buildingId) || {};
            return this.decorateBuildingAllocationRow({
                buildingId,
                building: previewRow.building || existingRow.building || this.getBuildingLabel(buildingId),
                roomCount: previewRow.roomCount ?? existingRow.roomCount ?? 0,
                totalCapacity: previewRow.totalCapacity ?? existingRow.totalCapacity ?? 0,
                alreadyAllocated: previewRow.alreadyAllocated ?? existingRow.alreadyAllocated ?? 0,
                limitMode: existingRow.limitMode || previewRow.limitMode || LIMIT_MODE_FULL_CAPACITY,
                allocationCap: existingRow.allocationCap ?? previewRow.allocationCap ?? ''
            });
        });

        return {
            ...form,
            buildingAllocationRows: rows
        };
    }

    async refreshBuildingAllocationPreview() {
        const selectedBuildingIds = [...(this.windowForm.buildingIds || [])];
        if (!selectedBuildingIds.length) {
            this.windowForm = this.syncWindowBuildingAllocationRows({
                ...this.windowForm,
                buildingAllocationRows: []
            });
            return;
        }

        const requestId = ++this.buildingAllocationPreviewRequestId;
        try {
            const previewRows = await getBuildingAllocationPreview({
                buildingIds: selectedBuildingIds,
                roomCategoryIds: [...(this.windowForm.roomCategoryIds || [])]
            });

            if (requestId !== this.buildingAllocationPreviewRequestId) {
                return;
            }

            this.windowForm = this.syncWindowBuildingAllocationRows(this.windowForm, previewRows || []);
        } catch (error) {
            if (requestId !== this.buildingAllocationPreviewRequestId) {
                return;
            }
            this.toast('Error', this.errorMessage(error), 'error');
        }
    }

    async loadWindows(cycleId) {
        if (!cycleId) {
            return;
        }

        const windows = await getWindows({ cycleId });
        this.windowsByCycleId = {
            ...this.windowsByCycleId,
            [cycleId]: [...(windows || [])]
        };
        this.applyWindowCountToCycle(cycleId);
    }

    async openCycleDetail(cycleId) {
        if (!cycleId) {
            return;
        }

        this.selectedCycle = this.rows.find((row) => row.id === cycleId) || null;
        this.isDetailView = this.selectedCycle != null;
        this.isCreateView = false;
        this.isWindowCreateView = false;

        if (!this.selectedCycle) {
            return;
        }

        await this.loadWindows(cycleId);
    }

    applyWindowCountToCycle(cycleId) {
        const count = (this.windowsByCycleId[cycleId] || []).length;
        this.rows = (this.rows || []).map((row) =>
            row.id === cycleId ? { ...row, windows: count } : row
        );

        if (this.selectedCycle?.id === cycleId) {
            this.selectedCycle = {
                ...this.selectedCycle,
                windows: count
            };
        }
    }

    get hasRows() {
        return (this.rows || []).length > 0;
    }

    get selectedCycleIdText() {
        if (!this.selectedCycle) {
            return '';
        }
        return `Cycle ID: ${this.selectedCycle.code} · ${this.selectedCycle.academicYear || '--'}`;
    }

    get saveButtonLabel() {
        return this.isEditMode ? 'Update Cycle' : 'Create Cycle';
    }

    get createTitle() {
        return this.isEditMode ? 'Edit Hostel Cycle' : 'Create Hostel Cycle';
    }

    get academicYearUiOptions() {
        const selected = new Set(this.form.academicYears || []);
        return (this.academicYearOptions || []).map((item) => ({
            ...item,
            selected: selected.has(item.value)
        }));
    }

    get academicYearsDisplayValue() {
        const selectedValues = this.form.academicYears || [];
        if (!selectedValues.length) {
            return '';
        }
        const labels = (this.academicYearOptions || [])
            .filter((item) => selectedValues.includes(item.value))
            .map((item) => item.label);
        return labels.join(', ');
    }

    get isAcademicYearDropdownOpen() {
        return this.openScopeDropdown === 'academicYear';
    }

    get academicYearDropdownClass() {
        return this.isAcademicYearDropdownOpen ? 'hc-scope-trigger open' : 'hc-scope-trigger';
    }

    get previousCycleUiOptions() {
        const currentCycleId = this.editingCycleId;
        return (this.previousCycleOptions || []).filter((item) => item.value !== currentCycleId);
    }

    get selectedCycleWindows() {
        if (!this.selectedCycle?.id) {
            return [];
        }
        return this.windowsByCycleId[this.selectedCycle.id] || [];
    }

    get selectedCycleWindowsUi() {
        return this.selectedCycleWindows.map((item) => ({
            ...item,
            hasStatus: !!item.status,
            statusClass: item.status ? this.resolveWindowStatusClass(item.status) : '',
            statusKey: item.status ? this.normalizeKey(item.status) : '',
            allotmentTypeClass: this.resolveAllotmentTypeClass(item.allotmentType)
        }));
    }

    get isDirectAllotment() {
        return this.windowForm.allotmentType === 'Direct';
    }

    get isProvisionalAllotment() {
        return this.windowForm.allotmentType === 'Provisional';
    }

    get directAllotmentClass() {
        return this.isDirectAllotment ? 'hc-allotment-option selected' : 'hc-allotment-option';
    }

    get provisionalAllotmentClass() {
        return this.isProvisionalAllotment ? 'hc-allotment-option selected' : 'hc-allotment-option';
    }

    get isEditWindowMode() {
        return this.isWindowEditMode === true;
    }

    get showEditDirectInfo() {
        return this.isEditWindowMode && this.isDirectAllotment;
    }

    get showEditProvisionalCards() {
        return this.isEditWindowMode && this.isProvisionalAllotment;
    }

    get buildingAllocationLimitRows() {
        return this.windowForm.buildingAllocationRows || [];
    }

    get totalCapAcrossSelectedBuildings() {
        return (this.buildingAllocationLimitRows || []).reduce((sum, row) => sum + (parseInt(row.totalCapacity, 10) || 0), 0);
    }

    get totalProvisionalCapsSet() {
        return (this.buildingAllocationLimitRows || []).reduce((sum, row) => sum + (parseInt(row.allocationCap, 10) || 0), 0);
    }

    get programPathwayUiOptions() {
        return this.mapScopeOptions(this.windowScopeOptions.programPathways, this.windowForm.programPathwayIds);
    }

    get buildingScopeUiOptions() {
        return this.mapScopeOptions(this.windowScopeOptions.buildings, this.windowForm.buildingIds);
    }

    get floorScopeUiOptions() {
        return this.mapScopeOptions(this.filteredFloorScopeOptions, this.windowForm.floorValues);
    }

    get roomCategoryScopeUiOptions() {
        return this.mapScopeOptions(this.filteredRoomCategoryScopeOptions, this.windowForm.roomCategoryIds);
    }

    get selectedProgramPathwaysText() {
        return this.getSelectedScopeLabels(this.windowScopeOptions.programPathways, this.windowForm.programPathwayIds);
    }

    get selectedBuildingsText() {
        return this.getSelectedScopeLabels(this.windowScopeOptions.buildings, this.windowForm.buildingIds);
    }

    get selectedFloorsText() {
        return this.getSelectedScopeLabels(this.filteredFloorScopeOptions, this.windowForm.floorValues);
    }

    get selectedRoomCategoriesText() {
        return this.getSelectedScopeLabels(this.filteredRoomCategoryScopeOptions, this.windowForm.roomCategoryIds);
    }

    get isProgramPathwayDropdownOpen() {
        return this.openScopeDropdown === 'programPathway';
    }

    get isBuildingDropdownOpen() {
        return this.openScopeDropdown === 'building';
    }

    get isFloorDropdownOpen() {
        return this.openScopeDropdown === 'floor';
    }

    get isRoomCategoryDropdownOpen() {
        return this.openScopeDropdown === 'roomCategory';
    }

    get programPathwayDropdownClass() {
        return this.isProgramPathwayDropdownOpen ? 'hc-scope-trigger open' : 'hc-scope-trigger';
    }

    get buildingDropdownClass() {
        return this.isBuildingDropdownOpen ? 'hc-scope-trigger open' : 'hc-scope-trigger';
    }

    get floorDropdownClass() {
        return this.isFloorDropdownOpen ? 'hc-scope-trigger open' : 'hc-scope-trigger';
    }

    get roomCategoryDropdownClass() {
        return this.isRoomCategoryDropdownOpen ? 'hc-scope-trigger open' : 'hc-scope-trigger';
    }

    get filteredFloorScopeOptions() {
        const selectedBuildingIds = new Set(this.windowForm.buildingIds || []);
        if (!selectedBuildingIds.size) {
            return [];
        }
        return (this.windowScopeOptions.floors || []).filter((item) =>
            selectedBuildingIds.has(item.buildingValue)
        );
    }

    get filteredRoomCategoryScopeOptions() {
        return this.getEligibleRoomCategoryOptions(this.windowForm);
    }

    get totalWindowsCount() {
        return this.selectedCycleWindows.length;
    }

    get showLiveCapacitySummary() {
        return (this.buildingAllocationLimitRows || []).length > 0;
    }

    get liveCapacityBuildingsCount() {
        return (this.buildingAllocationLimitRows || []).length;
    }

    get liveCapacityTotalRooms() {
        return (this.buildingAllocationLimitRows || []).reduce((sum, row) => sum + (parseInt(row.roomCount, 10) || 0), 0);
    }

    get liveCapacityTotalBeds() {
        return this.totalCapAcrossSelectedBuildings;
    }

    get liveCapacityAvailableBeds() {
        return (this.buildingAllocationLimitRows || []).reduce((sum, row) => {
            const totalCapacity = parseInt(row.totalCapacity, 10) || 0;
            const alreadyAllocated = parseInt(row.alreadyAllocated, 10) || 0;
            return sum + Math.max(totalCapacity - alreadyAllocated, 0);
        }, 0);
    }

    get windowsHeading() {
        return `Windows (${this.totalWindowsCount})`;
    }

    get totalApplicationsDisplay() {
        if (!this.selectedCycle) {
            return '--';
        }

        const count = Number.parseInt(this.selectedCycle.applications, 10);
        return Number.isNaN(count) ? '0' : String(count);
    }

    get totalAllottedDisplay() {
        return '--';
    }

    get hasWindowRows() {
        return this.selectedCycleWindows.length > 0;
    }

    get cycleDateRangeText() {
        const startDate = this.extractDateFromDateTime(this.selectedCycle?.startDateRaw || this.selectedCycle?.startDate);
        const endDate = this.extractDateFromDateTime(this.selectedCycle?.endDateRaw || this.selectedCycle?.endDate);
        return `${startDate || '--'} to ${endDate || '--'}`;
    }

    get windowViewTitle() {
        return this.isWindowEditMode ? 'Edit Window' : 'Add Window';
    }

    get windowSaveLabel() {
        return this.isWindowEditMode ? 'Update Window' : 'Create Window';
    }

    get fieldHistoryEvents() {
        if (!this.selectedCycle?.id) {
            return [];
        }

        const events = [];
        if (this.selectedCycle?.createdAt) {
            events.push({
                id: `${this.selectedCycle.id}-record-created`,
                title: 'Record Created',
                subtitle: '',
                by: this.selectedCycle.createdBy,
                at: this.selectedCycle.createdAt
            });
        }

        (this.selectedCycleWindows || []).forEach((item) => {
            const lastTouched = item.lastModifiedAt || item.createdAt;
            if (!lastTouched) {
                return;
            }
            const isUpdated = item.lastModifiedAt && item.createdAt && item.lastModifiedAt !== item.createdAt;
            events.push({
                id: `${item.id}-${isUpdated ? 'updated' : 'created'}`,
                title: isUpdated ? 'Window Updated' : 'Window Created',
                subtitle: item.name,
                by: item.lastModifiedBy || item.createdBy,
                at: lastTouched
            });
        });

        return events
            .sort((left, right) => new Date(right.at).getTime() - new Date(left.at).getTime())
            .map((item) => ({
                ...item,
                key: `${item.id}`,
                byText: item.by || 'Admin User',
                atText: this.formatDateTime(item.at)
            }));
    }

    get auditCreatedByText() {
        const event = this.fieldHistoryEvents[this.fieldHistoryEvents.length - 1];
        return event?.byText || 'Admin User';
    }

    get auditCreatedDateText() {
        const event = this.fieldHistoryEvents[this.fieldHistoryEvents.length - 1];
        return event?.at ? this.formatDateOnly(event.at) : '--';
    }

    get auditLastModifiedText() {
        const event = this.fieldHistoryEvents[0];
        const by = event?.byText || 'Admin User';
        const at = event?.at ? this.formatDateOnly(event.at) : '--';
        return `${by} · ${at}`;
    }

    handleOpenCreateCycle() {
        this.resetForm();
        this.openScopeDropdown = '';
        this.isEditMode = false;
        this.editingCycleId = null;
        this.isCreateView = true;
        this.isDetailView = false;
    }

    handleBackToList() {
        if (this.isWindowCreateView) {
            this.closeWindowForm();
            return;
        }
        this.openScopeDropdown = '';
        this.isCreateView = false;
        this.isDetailView = false;
        this.isWindowCreateView = false;
        this.isEditMode = false;
        this.isWindowEditMode = false;
        this.editingCycleId = null;
        this.editingWindowId = null;
        this.selectedCycle = null;
    }

    handleCarryForwardToggle(event) {
        this.isCarryForwardEnabled = event.target.checked;
        if (!this.isCarryForwardEnabled) {
            this.form = { ...this.form, previousCycleId: '' };
        }
    }

    async handleOpenCycleDetail(event) {
        const cycleId = event.currentTarget?.dataset?.id;
        if (!cycleId) {
            return;
        }
        try {
            await this.openCycleDetail(cycleId);
        } catch (error) {
            this.toast('Error', this.errorMessage(error), 'error');
        }
    }

    handleEditSelectedCycle() {
        if (!this.selectedCycle?.id) {
            return;
        }
        this.handleEditById(this.selectedCycle.id);
    }

    handleDeleteSelectedCycle() {
        if (!this.selectedCycle?.id) {
            return;
        }
        this.deleteById(this.selectedCycle.id);
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }

        this.form = {
            ...this.form,
            [field]: event.target.value
        };
    }

    handleAcademicYearToggle(event) {
        const optionValue = event.target.dataset.value;
        if (!optionValue) {
            return;
        }
        const selectedValues = new Set(this.form.academicYears || []);
        if (event.target.checked) {
            selectedValues.add(optionValue);
        } else {
            selectedValues.delete(optionValue);
        }
        this.form = {
            ...this.form,
            academicYears: Array.from(selectedValues)
        };
    }

    async handlePreviewRow(event) {
        const cycleId = event.currentTarget?.dataset?.id;
        if (!cycleId) {
            return;
        }
        try {
            await this.openCycleDetail(cycleId);
        } catch (error) {
            this.toast('Error', this.errorMessage(error), 'error');
        }
    }

    handleEditRow(event) {
        const cycleId = event.currentTarget?.dataset?.id;
        if (!cycleId) {
            return;
        }
        this.handleEditById(cycleId);
    }

    handleEditById(cycleId) {
        const cycle = this.rows.find((row) => row.id === cycleId);
        if (!cycle) {
            return;
        }
        const resolvedPreviousCycleId = cycle.previousCycleId && cycle.previousCycleId !== cycle.id
            ? cycle.previousCycleId
            : '';
        this.form = {
            name: cycle.cycleName || '',
            academicYears: Array.isArray(cycle.academicYearIds)
                ? [...cycle.academicYearIds]
                : [],
            startDate: cycle.startDateRaw || this.toDateTimeLocal(cycle.startDate),
            endDate: cycle.endDateRaw || this.toDateTimeLocal(cycle.endDate),
            status: cycle.status || '',
            previousCycleId: resolvedPreviousCycleId
        };
        this.isCarryForwardEnabled = !!resolvedPreviousCycleId;
        this.openScopeDropdown = '';
        this.isEditMode = true;
        this.editingCycleId = cycle.id;
        this.isCreateView = true;
        this.isDetailView = false;
        this.isWindowCreateView = false;
    }

    async handleDeleteRow(event) {
        const cycleId = event.currentTarget?.dataset?.id;
        if (!cycleId) {
            return;
        }
        await this.deleteById(cycleId);
    }

    async deleteById(cycleId) {
        try {
            await deleteCycle({ cycleId });
            this.toast('Success', 'Cycle deleted.', 'success');
            await this.initialize();
            if (this.selectedCycle && this.selectedCycle.id === cycleId) {
                this.handleBackToList();
            }
        } catch (error) {
            this.toast('Error', this.errorMessage(error), 'error');
        }
    }

    async handleCreateCycle() {
        if (this.isSaving) {
            return;
        }
        if (!this.validateForm()) {
            return;
        }

        this.isSaving = true;
        try {
            const inputRequest = {
                name: this.form.name,
                academicYearIds: [...(this.form.academicYears || [])],
                startDate: this.form.startDate,
                endDate: this.form.endDate,
                status: this.form.status,
                carryForwardEnabled: this.isCarryForwardEnabled,
                previousCycleId: this.form.previousCycleId
            };

            if (this.isEditMode && this.editingCycleId) {
                await updateCycle({
                    cycleId: this.editingCycleId,
                    inputRequest
                });
                this.toast('Success', 'Hostel cycle updated.', 'success');
            } else {
                await createCycle({ inputRequest });
                this.toast('Success', 'Hostel cycle created.', 'success');
            }
            this.isCreateView = false;
            this.isDetailView = false;
            this.isEditMode = false;
            this.editingCycleId = null;
            await this.initialize();
        } catch (error) {
            this.toast('Error', this.errorMessage(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleOpenAddWindow() {
        if (!this.selectedCycle?.id) {
            return;
        }
        this.openScopeDropdown = '';
        this.isWindowEditMode = false;
        this.editingWindowId = null;
        this.windowForm = this.syncWindowBuildingAllocationRows(this.getDefaultWindowForm());
        this.isWindowCreateView = true;
        this.ensureWindowScopeOptionsLoaded();
        this.refreshBuildingAllocationPreview();
    }

    handleEditWindow(event) {
        const windowId = event.currentTarget?.dataset?.id;
        if (!windowId) {
            return;
        }

        const currentWindow = this.selectedCycleWindows.find((item) => item.id === windowId);
        if (!currentWindow) {
            return;
        }

        this.openScopeDropdown = '';
        this.isWindowEditMode = true;
        this.editingWindowId = windowId;
        this.windowForm = this.buildWindowForm(currentWindow);
        this.isWindowCreateView = true;
        this.ensureWindowScopeOptionsLoaded();
        this.refreshBuildingAllocationPreview();
    }

    async handleDeleteWindow(event) {
        const windowId = event.currentTarget?.dataset?.id;
        if (!windowId) {
            return;
        }

        const currentWindow = this.selectedCycleWindows.find((item) => item.id === windowId);
        const windowName = currentWindow?.name || 'this window';
        const confirmed = window.confirm(`Delete "${windowName}"?`);
        if (!confirmed) {
            return;
        }

        try {
            await deleteWindow({ windowId });
            await this.loadWindows(this.selectedCycle?.id);
            if (this.isWindowEditMode && this.editingWindowId === windowId) {
                this.closeWindowForm();
            }
            this.toast('Success', 'Window deleted.', 'success');
        } catch (error) {
            this.toast('Error', this.errorMessage(error), 'error');
        }
    }

    handleWindowFieldChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }

        this.windowForm = {
            ...this.windowForm,
            [field]: event.target.value
        };
    }

    handleAllocationTypeChange(event) {
        const nextValue = event.target.value;
        if (!nextValue) {
            return;
        }
        this.windowForm = {
            ...this.windowForm,
            allotmentType: nextValue
        };
    }

    handleWindowToggleChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }
        const nextForm = {
            ...this.windowForm,
            [field]: event.target.checked
        };
        if (field === 'enableRoomPreference' && !event.target.checked) {
            nextForm.maxRoomPreferences = '';
        }
        if (field === 'enableMaximumRoomCapacity' && !event.target.checked) {
            nextForm.maxRoomCapacity = '';
        }
        this.windowForm = nextForm;
    }

    handleWindowNumberChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }
        let value = event.target.value;
        if (value) {
            const numeric = parseInt(String(value), 10);
            if (Number.isFinite(numeric)) {
                value = String(Math.max(1, numeric));
            } else {
                value = '';
            }
        }
        this.windowForm = {
            ...this.windowForm,
            [field]: value
        };
    }

    handleScopeToggle(event) {
        event.stopPropagation();
        const field = event.target.dataset.field;
        const optionValue = event.target.dataset.value;
        if (!field || !optionValue) {
            return;
        }

        const selectedValues = new Set(this.windowForm[field] || []);
        if (event.target.checked) {
            selectedValues.add(optionValue);
        } else {
            selectedValues.delete(optionValue);
        }

        let nextForm = {
            ...this.windowForm,
            [field]: Array.from(selectedValues)
        };

        if (field === 'buildingIds') {
            nextForm.floorValues = (nextForm.floorValues || []).filter((value) =>
                this.filteredFloorScopeOptionsForForm(nextForm).some((item) => item.value === value)
            );
            nextForm = this.syncWindowBuildingAllocationRows(nextForm);
        }

        if (field === 'buildingIds' || field === 'floorValues') {
            nextForm.roomCategoryIds = (nextForm.roomCategoryIds || []).filter((value) =>
                this.getEligibleRoomCategoryOptions(nextForm).some((item) => item.value === value)
            );
        }

        this.windowForm = nextForm;

        if (field === 'buildingIds' || field === 'floorValues' || field === 'roomCategoryIds') {
            this.refreshBuildingAllocationPreview();
        }
    }

    handleBuildingAllocationModeChange(event) {
        const buildingId = event.target.dataset.buildingId;
        if (!buildingId) {
            return;
        }

        const rows = (this.windowForm.buildingAllocationRows || []).map((row) =>
            row.buildingId === buildingId
                ? this.decorateBuildingAllocationRow({
                    ...row,
                    limitMode: event.target.value,
                    allocationCap: event.target.value === LIMIT_MODE_CUSTOM_CAP ? row.allocationCap : String(row.totalCapacity)
                })
                : row
        );

        this.windowForm = {
            ...this.windowForm,
            buildingAllocationRows: rows
        };
    }

    handleBuildingAllocationCapChange(event) {
        const buildingId = event.target.dataset.buildingId;
        if (!buildingId) {
            return;
        }

        const value = this.normalizeNonNegativeInteger(event.target.value, true);
        this.windowForm = {
            ...this.windowForm,
            buildingAllocationRows: (this.windowForm.buildingAllocationRows || []).map((row) =>
                row.buildingId === buildingId
                    ? this.decorateBuildingAllocationRow({
                        ...row,
                        allocationCap: value
                    })
                    : row
            )
        };
    }

    handleCancelWindowForm() {
        this.closeWindowForm();
    }

    closeWindowForm() {
        this.openScopeDropdown = '';
        this.isWindowCreateView = false;
        this.isWindowEditMode = false;
        this.editingWindowId = null;
    }

    handleDropdownToggle(event) {
        event.stopPropagation();
        const dropdown = event.currentTarget?.dataset?.dropdown;
        if (!dropdown) {
            return;
        }
        this.openScopeDropdown = this.openScopeDropdown === dropdown ? '' : dropdown;
    }

    handleDropdownContainerClick(event) {
        event.stopPropagation();
    }

    handleDocumentClick() {
        this.openScopeDropdown = '';
    }

    async handleSaveWindow() {
        if (this.isSavingWindow) {
            return;
        }
        if (!this.validateWindowForm()) {
            return;
        }

        this.isSavingWindow = true;
        try {
            const cycleId = this.selectedCycle?.id;
            if (!cycleId) {
                return;
            }

            const inputRequest = {
                name: this.windowForm.name,
                startDate: this.windowForm.startDate,
                endDate: this.windowForm.endDate,
                roomAllotmentStartDate: this.windowForm.roomAllotmentStartDate,
                roomAllotmentEndDate: this.windowForm.roomAllotmentEndDate,
                startTime: this.windowForm.startTime,
                endTime: this.windowForm.endTime,
                paymentDeadline: this.windowForm.paymentDeadline,
                allotmentType: this.windowForm.allotmentType,
                programPathwayIds: [...(this.windowForm.programPathwayIds || [])],
                buildingIds: [...(this.windowForm.buildingIds || [])],
                roomCategoryIds: [...(this.windowForm.roomCategoryIds || [])],
                enableRoomPreference: this.windowForm.enableRoomPreference === true,
                maxRoomPreferences: this.windowForm.maxRoomPreferences,
                enableMaximumRoomCapacity: this.windowForm.enableMaximumRoomCapacity === true,
                maxRoomCapacity: this.windowForm.maxRoomCapacity,
                allowRoommatePreference: this.windowForm.allowRoommatePreference === true,
                buildingAllocationRows: (this.windowForm.buildingAllocationRows || []).map((row) => ({
                    buildingId: row.buildingId,
                    limitMode: row.limitMode,
                    allocationCap: row.limitMode === LIMIT_MODE_CUSTOM_CAP ? row.allocationCap : null
                }))
            };

            if (this.isWindowEditMode) {
                await updateWindow({
                    windowId: this.editingWindowId,
                    cycleId,
                    inputRequest
                });
            } else {
                await createWindow({
                    cycleId,
                    inputRequest
                });
            }

            await this.loadWindows(cycleId);
            this.toast('Success', this.isWindowEditMode ? 'Window updated.' : 'Window created.', 'success');
            this.closeWindowForm();
        } catch (error) {
            this.toast('Error', this.errorMessage(error), 'error');
        } finally {
            this.isSavingWindow = false;
        }
    }

    validateWindowForm() {
        const missing = [];
        if (!this.windowForm.name) missing.push('Window Name');
        if (!this.windowForm.startDate) missing.push('Start Date');
        if (!this.windowForm.endDate) missing.push('End Date');
        if (!this.windowForm.startTime) missing.push('Start Time');
        if (!this.windowForm.endTime) missing.push('End Time');
        if (!this.windowForm.paymentDeadline) missing.push('Payment Deadline');
        if (!(this.windowForm.programPathwayIds || []).length) missing.push('Eligible Learning Program Plan');
        if (!(this.windowForm.buildingIds || []).length) missing.push('Eligible Buildings');

        if (missing.length) {
            this.toast('Validation Error', `${missing.join(', ')} is required.`, 'error');
            return false;
        }

        const duplicateProgramPathwayConflicts = this.getDuplicateProgramPathwayConflicts();
        if (duplicateProgramPathwayConflicts.length) {
            this.toast(
                'Validation Error',
                this.buildDuplicateProgramPathwayMessage(duplicateProgramPathwayConflicts),
                'error'
            );
            return false;
        }

        const cycleStart = this.extractDateFromDateTime(this.selectedCycle?.startDateRaw || this.selectedCycle?.startDate);
        const cycleEnd = this.extractDateFromDateTime(this.selectedCycle?.endDateRaw || this.selectedCycle?.endDate);
        if (cycleStart && cycleEnd) {
            if (this.windowForm.startDate < cycleStart || this.windowForm.endDate > cycleEnd) {
                this.toast('Validation Error', 'Window dates must fall within the parent cycle range.', 'error');
                return false;
            }
        }

        if (this.windowForm.startDate > this.windowForm.endDate) {
            this.toast('Validation Error', 'Window End Date must be after Start Date.', 'error');
            return false;
        }

        const windowStartAt = this.combineDateAndTime(this.windowForm.startDate, this.windowForm.startTime);
        const windowEndAt = this.combineDateAndTime(this.windowForm.endDate, this.windowForm.endTime);
        if (windowStartAt && windowEndAt && windowEndAt <= windowStartAt) {
            this.toast('Validation Error', 'Window End Time must be after Start Time.', 'error');
            return false;
        }
        if (
            (this.windowForm.roomAllotmentStartDate && !this.windowForm.roomAllotmentEndDate)
            || (!this.windowForm.roomAllotmentStartDate && this.windowForm.roomAllotmentEndDate)
        ) {
            this.toast(
                'Validation Error',
                'Room Allotment Start Date and End Date must both be provided.',
                'error'
            );
            return false;
        }
        if (
            this.windowForm.roomAllotmentStartDate
            && this.windowForm.roomAllotmentEndDate
            && this.windowForm.roomAllotmentStartDate > this.windowForm.roomAllotmentEndDate
        ) {
            this.toast('Validation Error', 'Room Allotment End Date must be after Start Date.', 'error');
            return false;
        }

        if (this.windowForm.allotmentType === 'Provisional') {
            if (this.windowForm.enableRoomPreference) {
                const maxPref = parseInt(this.windowForm.maxRoomPreferences, 10);
                if (!Number.isFinite(maxPref) || maxPref < 1) {
                    this.toast('Validation Error', 'Maximum Room Preferences is required.', 'error');
                    return false;
                }
            }

            if (this.windowForm.enableMaximumRoomCapacity) {
                const maxCap = parseInt(this.windowForm.maxRoomCapacity, 10);
                if (!Number.isFinite(maxCap) || maxCap < 1) {
                    this.toast('Validation Error', 'Maximum Room Capacity is required.', 'error');
                    return false;
                }
            }

            const invalidBuildingRow = (this.buildingAllocationLimitRows || []).find((row) => {
                if (row.limitMode !== LIMIT_MODE_CUSTOM_CAP) {
                    return false;
                }
                const allocationCap = parseInt(row.allocationCap, 10);
                return !Number.isFinite(allocationCap) || allocationCap < 0 || allocationCap > row.totalCapacity;
            });

            if (invalidBuildingRow) {
                this.toast(
                    'Validation Error',
                    `Allocation Cap for ${invalidBuildingRow.building} must be between 0 and ${invalidBuildingRow.totalCapacity}.`,
                    'error'
                );
                return false;
            }
        }

        return true;
    }

    getDuplicateProgramPathwayConflicts() {
        const selectedProgramPathwayIds = [...new Set(this.windowForm.programPathwayIds || [])];
        if (!selectedProgramPathwayIds.length) {
            return [];
        }

        const currentWindowId = this.isWindowEditMode ? this.editingWindowId : null;
        const conflictsByProgramId = new Map(
            selectedProgramPathwayIds.map((programId) => [
                programId,
                {
                    programId,
                    programLabel: this.getProgramPathwayLabel(programId),
                    windowNames: new Set()
                }
            ])
        );

        (this.selectedCycleWindows || []).forEach((windowRecord) => {
            if (!windowRecord?.id || windowRecord.id === currentWindowId) {
                return;
            }

            (windowRecord.programPathwayIds || []).forEach((programId) => {
                const conflict = conflictsByProgramId.get(programId);
                if (!conflict) {
                    return;
                }
                conflict.windowNames.add(windowRecord.name || 'another window');
            });
        });

        return selectedProgramPathwayIds
            .map((programId) => conflictsByProgramId.get(programId))
            .filter((conflict) => conflict && conflict.windowNames.size);
    }

    getProgramPathwayLabel(programPathwayId) {
        const option = (this.windowScopeOptions.programPathways || []).find((item) => item.value === programPathwayId);
        return option?.label || 'Selected Learning Program Plan';
    }

    buildDuplicateProgramPathwayMessage(conflicts) {
        const details = (conflicts || []).map((conflict) => {
            const windowNames = [...(conflict.windowNames || [])].filter(Boolean).sort();
            const windowLabel = windowNames.length === 1
                ? `window "${windowNames[0]}"`
                : windowNames.length > 1
                    ? `windows "${windowNames.join('", "')}"`
                    : 'another window';
            return `"${conflict.programLabel}" is already assigned to ${windowLabel}`;
        });

        if (details.length === 1) {
            return `Learning Program Plan ${details[0]} in this cycle.`;
        }

        return `These Learning Program Plans are already assigned to other windows in this cycle: ${details.join('; ')}.`;
    }

    validateForm() {
        const missing = [];
        if (!this.form.name) missing.push('Cycle Name');
        if (!(this.form.academicYears || []).length) missing.push('Academic Year');
        if (!this.form.startDate) missing.push('Cycle Start Date & Time');
        if (!this.form.endDate) missing.push('Cycle End Date & Time');
        if (!this.form.status) missing.push('Status');
        if (this.isCarryForwardEnabled && !this.form.previousCycleId) missing.push('Select Previous Cycle');

        if (missing.length) {
            this.toast('Validation Error', `${missing.join(', ')} is required.`, 'error');
            return false;
        }

        if (!this.isEditMode) {
            const todayDate = this.getTodayDateString();
            const cycleStartDate = this.extractDateFromDateTime(this.form.startDate);
            if (cycleStartDate && cycleStartDate < todayDate) {
                this.toast('Validation Error', 'Cycle Start Date cannot be in the past.', 'error');
                return false;
            }

            const cycleStartAt = this.parseDateTimeLocal(this.form.startDate);
            const cycleEndAt = this.parseDateTimeLocal(this.form.endDate);
            if (cycleStartAt && cycleEndAt && cycleEndAt <= cycleStartAt) {
                this.toast('Validation Error', 'Cycle End Date & Time must be after Start Date & Time.', 'error');
                return false;
            }
        }
        return true;
    }

    resetForm() {
        this.form = {
            name: '',
            academicYears: [],
            startDate: '',
            endDate: '',
            status: this.statusOptions.length ? this.statusOptions[0].value : '',
            previousCycleId: ''
        };
        this.isCarryForwardEnabled = false;
    }

    toDateTimeLocal(dateText) {
        if (!dateText || dateText === '--') {
            return '';
        }
        const parts = dateText.split('/');
        if (parts.length !== 3) {
            return '';
        }
        const [month, day, year] = parts;
        if (!month || !day || !year) {
            return '';
        }
        const safeMonth = month.padStart(2, '0');
        const safeDay = day.padStart(2, '0');
        return `${year}-${safeMonth}-${safeDay}T00:00`;
    }

    mapScopeOptions(options, selectedValues) {
        const selected = new Set(selectedValues || []);
        return (options || []).map((item) => ({
            ...item,
            selected: selected.has(item.value)
        }));
    }

    filteredFloorScopeOptionsForForm(form) {
        const selectedBuildingIds = new Set(form?.buildingIds || []);
        if (!selectedBuildingIds.size) {
            return [];
        }
        return (this.windowScopeOptions.floors || []).filter((item) =>
            selectedBuildingIds.has(item.buildingValue)
        );
    }

    getEligibleRoomCategoryOptions(form) {
        const selectedBuildingIds = new Set(form?.buildingIds || []);
        const selectedFloorValues = new Set(form?.floorValues || []);

        return (this.windowScopeOptions.roomCategories || []).filter((item) => {
            const categoryBuildingValues = new Set(item.buildingValues || []);
            const categoryFloorValues = new Set(item.floorValues || []);
            const matchesBuilding = !selectedBuildingIds.size
                || !categoryBuildingValues.size
                || Array.from(selectedBuildingIds).some((value) => categoryBuildingValues.has(value));
            const matchesFloor = !selectedFloorValues.size
                || !categoryFloorValues.size
                || Array.from(selectedFloorValues).some((value) => categoryFloorValues.has(value));
            return matchesBuilding && matchesFloor;
        });
    }

    getSelectedScopeLabels(options, selectedValues) {
        const selected = new Set(selectedValues || []);
        if (!selected.size) {
            return '';
        }
        return (options || [])
            .filter((item) => selected.has(item.value))
            .map((item) => item.label)
            .join(', ');
    }

    normalizeKey(value) {
        return (value || '').toLowerCase().replace(/\s+/g, '');
    }

    resolveWindowStatusClass(status) {
        const key = this.normalizeKey(status);
        if (key === 'open') {
            return 'hc-status-pill hc-window-status-open';
        }
        if (key === 'upcoming') {
            return 'hc-status-pill hc-window-status-upcoming';
        }
        return 'hc-status-pill hc-window-status-closed';
    }

    resolveAllotmentTypeClass(type) {
        const key = this.normalizeKey(type);
        if (key === 'provisional' || key === 'provisionalallotment' || key === 'preferenceselected') {
            return 'hc-chip hc-chip-provisional';
        }
        if (key === 'direct' || key === 'directallotment' || key === 'confirmedallotment' || key === 'finalallotment') {
            return 'hc-chip hc-chip-direct';
        }
        return 'hc-chip';
    }

    extractDateFromDateTime(value) {
        if (!value) {
            return '';
        }

        if (/^\d{4}-\d{2}-\d{2}/.test(value)) {
            return value.substring(0, 10);
        }

        const dt = new Date(value);
        if (Number.isNaN(dt.getTime())) {
            return '';
        }

        const month = String(dt.getMonth() + 1).padStart(2, '0');
        const day = String(dt.getDate()).padStart(2, '0');
        return `${dt.getFullYear()}-${month}-${day}`;
    }

    parseDateTimeLocal(value) {
        if (!value) {
            return null;
        }
        const parsed = new Date(value);
        return Number.isNaN(parsed.getTime()) ? null : parsed;
    }

    combineDateAndTime(dateValue, timeValue) {
        if (!dateValue || !timeValue) {
            return null;
        }
        return this.parseDateTimeLocal(`${dateValue}T${timeValue}`);
    }

    getTodayDateString() {
        const today = new Date();
        const month = String(today.getMonth() + 1).padStart(2, '0');
        const day = String(today.getDate()).padStart(2, '0');
        return `${today.getFullYear()}-${month}-${day}`;
    }

    formatDateOnly(value) {
        const dt = new Date(value);
        if (Number.isNaN(dt.getTime())) {
            return '--';
        }
        const month = String(dt.getMonth() + 1).padStart(2, '0');
        const day = String(dt.getDate()).padStart(2, '0');
        return `${dt.getFullYear()}-${month}-${day}`;
    }

    formatDateTime(value) {
        const dt = new Date(value);
        if (Number.isNaN(dt.getTime())) {
            return '--';
        }

        const date = this.formatDateOnly(value);
        let hour = dt.getHours();
        const minute = String(dt.getMinutes()).padStart(2, '0');
        const amPm = hour >= 12 ? 'PM' : 'AM';
        hour = hour % 12;
        if (hour === 0) {
            hour = 12;
        }
        return `${date} ${String(hour).padStart(2, '0')}:${minute} ${amPm}`;
    }

    errorMessage(error) {
        return error?.body?.message || error?.message || 'Something went wrong.';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}