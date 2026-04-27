import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRoomCategories from '@salesforce/apex/KenRoomCategoryController.getRoomCategories';
import getLinkedRoomsByCategory from '@salesforce/apex/KenRoomCategoryController.getLinkedRoomsByCategory';
import getRoomCategoryActivityHistory from '@salesforce/apex/KenRoomCategoryController.getRoomCategoryActivityHistory';
import getRoomCategoryFormOptions from '@salesforce/apex/KenRoomCategoryController.getRoomCategoryFormOptions';
import createRoomCategory from '@salesforce/apex/KenRoomCategoryController.createRoomCategory';
import updateRoomCategory from '@salesforce/apex/KenRoomCategoryController.updateRoomCategory';
import deleteRoomCategoryRecord from '@salesforce/apex/KenRoomCategoryController.deleteRoomCategory';
import addCustomAmenity from '@salesforce/apex/KenRoomCategoryController.addCustomAmenity';
import getRoomCategoryDetail from '@salesforce/apex/KenRoomCategoryController.getRoomCategoryDetail';
import getBuildings from '@salesforce/apex/KenBuildingController.getBuildings';
import getBuildingDetail from '@salesforce/apex/KenBuildingController.getBuildingDetail';
import getBuildingFormOptions from '@salesforce/apex/KenBuildingController.getBuildingFormOptions';
import createBuilding from '@salesforce/apex/KenBuildingController.createBuilding';
import updateBuilding from '@salesforce/apex/KenBuildingController.updateBuilding';
import deleteBuildingRecord from '@salesforce/apex/KenBuildingController.deleteBuilding';
import getBuildingFloorWardenDetails from '@salesforce/apex/KenBuildingController.getBuildingFloorWardenDetails';
import createFloorWarden from '@salesforce/apex/KenBuildingController.createFloorWarden';
import getBuildingActivityHistory from '@salesforce/apex/KenBuildingController.getBuildingActivityHistory';
import getRooms from '@salesforce/apex/KenRoomController.getRooms';
import getRoomFormOptions from '@salesforce/apex/KenRoomController.getRoomFormOptions';
import getRoomById from '@salesforce/apex/KenRoomController.getRoomById';
import getRoomOccupancyDetails from '@salesforce/apex/KenRoomController.getRoomOccupancyDetails';
import createRoom from '@salesforce/apex/KenRoomController.createRoom';
import updateRoom from '@salesforce/apex/KenRoomController.updateRoom';
import deleteRoomRecord from '@salesforce/apex/KenRoomController.deleteRoom';

const MASTER_TAB_STORAGE_KEY = 'masterDataStaticView.activeMasterTab';
const FLOOR_WARDEN_ASSIGNMENT_TYPE_OPTIONS = [
    { label: 'Floor Warden', value: 'Floor Warden' },
    { label: 'Building Warden', value: 'Building Warden' }
];

export default class MasterDataStaticView extends LightningElement {
    isNewBuildingModalOpen = false;
    isNewRoomCategoryModalOpen = false;
    isNewRoomModalOpen = false;
    isSavingBuilding = false;
    isSavingRoomCategory = false;
    isSavingRoom = false;
    isSavingFloorWarden = false;
    isLoadingBuildings = false;
    isLoadingRooms = false;
    isLoadingRoomCategories = false;
    isLoadingLinkedRooms = false;
    isLoadingBuildingFloors = false;
    isLoadingRoomOccupants = false;
    isFloorWardenModalOpen = false;
    roomCategoryViewMode = 'list';
    isKenRoomCategoryDetailView = false;
    kenRoomCategoryDetailId = null;
    buildingViewMode = 'list';
    roomViewMode = 'list';
    activeTopTab = 'dashboard';
    activeMasterTab = 'roomCategories';
    hasInitializedMasterData = false;
    pendingDashboardQuickAction = null;
    pendingReportsNavigation = null;
    selectedStatus = 'all';
    buildingRows = [];
    roomRows = [];
    roomCategoryRows = [];
    linkedRoomRows = [];
    buildingDetailRoomRows = [];
    expandedBuildingFloorKeys = [];
    buildingFloorWardenByNo = {};
    buildingActivityHistory = null;
    roomCategoryActivityHistory = null;
    roomOccupancyDetails = null;
    roomCurrentOccupants = [];
    roomPastOccupants = [];
    buildingGenderOptions = [];
    buildingHostelTypeOptions = [];
    buildingStatusOptions = [];
    buildingWardenModeOptions = [];
    buildingWardenOptions = [];
    roomCategoryGenderOptions = [];
    roomCategoryFeeTypeOptions = [];
    roomCategoryAmenitiesOptions = [];
    roomCategoryStatusOptions = [];
    roomBuildingOptions = [];
    roomFloorOptions = [];
    roomCategoryOptions = [];
    roomStatusOptions = [];
    roomCategoryCapacityById = {};
    customAmenityInput = '';
    selectedBuilding = null;
    selectedRoom = null;
    selectedRoomCategory = null;
    editingRoomCategoryId = null;
    editingBuildingId = null;
    editingRoomId = null;
    editingRoomInitialFloorId = '';
    roomCategoryForm = {
        categoryName: '',
        description: '',
        genderAllowed: '',
        defaultFeeTypeId: '',
        statusValue: 'active',
        amenities: []
    };
    buildingForm = {
        buildingName: '',
        genderValue: '',
        hostelTypeValue: '',
        statusValue: 'Active',
        numberOfFloors: '',
        wardenMode: 'Building Level',
        buildingWarden: ''
    };
    roomForm = {
        buildingValue: '',
        floorId: '',
        roomNumber: '',
        roomCategoryId: '',
        capacity: '',
        statusValue: 'active'
    };
    floorWardenForm = {
        floorNo: '',
        wardenId: '',
        assignmentType: 'Floor Warden',
        phone: '',
        description: ''
    };
    buildingFallbackByName = {
        'Block A - Boys': {
            buildingIdentifier: 'B001',
            floors: 4,
            wardenMode: 'Building-level',
            capacity: 150,
            roomsCount: 45,
            wardenName: 'Dr. Ramesh Kumar',
            currentOccupancy: '142 / 150',
            occupancyPercent: 95
        },
        'Block B - Boys': {
            buildingIdentifier: 'B002',
            floors: 3,
            wardenMode: 'Per-floor',
            capacity: 120,
            roomsCount: 38,
            wardenName: 'Mr. Arun Prakash',
            currentOccupancy: '96 / 120',
            occupancyPercent: 80
        },
        'Block C - Girls': {
            buildingIdentifier: 'B003',
            floors: 3,
            wardenMode: 'Building-level',
            capacity: 100,
            roomsCount: 32,
            wardenName: 'Dr. Meera Nair',
            currentOccupancy: '85 / 100',
            occupancyPercent: 85
        },
        'Block D - Premium': {
            buildingIdentifier: 'B004',
            floors: 4,
            wardenMode: 'Building-level',
            capacity: 130,
            roomsCount: 0,
            wardenName: 'Ms. Kavitha Rao',
            currentOccupancy: '0 / 130',
            occupancyPercent: 0
        }
    };
    topTabsConfig = [
        { key: 'dashboard', label: 'Dashboard', iconName: 'utility:apps' },
        { key: 'masterData', label: 'Master Data', iconName: 'utility:database' },
        { key: 'hostelCycle', label: 'Hostel Cycle', iconName: 'utility:event' },
        { key: 'accommodation', label: 'Accommodation', iconName: 'utility:home' },
        { key: 'reports', label: 'Reports', iconName: 'utility:chart' }
    ];

    masterTabsConfig = [
        { key: 'roomCategories', label: 'Room Categories' },
        { key: 'feeTypes', label: 'Fee Types' },
        { key: 'buildings', label: 'Buildings' },
        { key: 'rooms', label: 'Rooms' }
    ];

    connectedCallback() {
        this.restoreNavigationState();
        this.initializeActiveTopTab();
    }

    initializeActiveTopTab() {
        if (this.activeTopTab === 'masterData') {
            this.initializeMasterData();
        }
    }

    initializeMasterData() {
        if (this.hasInitializedMasterData) {
            return;
        }
        this.hasInitializedMasterData = true;

        this.loadInitialMasterTabData();
        this.loadActiveMasterTabFormOptions();
    }

    loadActiveMasterTabFormOptions() {
        if (this.activeMasterTab === 'buildings') {
            this.loadBuildingFormOptions();
            return;
        }
        if (this.activeMasterTab === 'rooms') {
            this.loadRoomFormOptions();
        }
    }

    restoreNavigationState() {
        if (typeof window === 'undefined' || !window.sessionStorage) {
            return;
        }
        window.sessionStorage.removeItem('masterDataStaticView.activeTopTab');

        const validMasterTabKeys = this.masterTabsConfig.map((tab) => tab.key);
        const storedMasterTab = window.sessionStorage.getItem(MASTER_TAB_STORAGE_KEY);
        if (validMasterTabKeys.includes(storedMasterTab)) {
            this.activeMasterTab = storedMasterTab;
        }
    }

    persistNavigationState() {
        if (typeof window === 'undefined' || !window.sessionStorage) {
            return;
        }

        window.sessionStorage.removeItem('masterDataStaticView.activeTopTab');
        window.sessionStorage.setItem(MASTER_TAB_STORAGE_KEY, this.activeMasterTab);
    }

    loadInitialMasterTabData() {
        if (this.activeMasterTab === 'buildings') {
            this.loadBuildings();
            return;
        }
        if (this.activeMasterTab === 'rooms') {
            this.loadRooms();
            return;
        }
    }

    get topTabs() {
        return this.topTabsConfig.map((tab) => ({
            ...tab,
            className: tab.key === this.activeTopTab ? 'top-nav-item active' : 'top-nav-item'
        }));
    }

    get masterTabs() {
        return this.masterTabsConfig.map((tab) => ({
            ...tab,
            className: tab.key === this.activeMasterTab ? 'inner-tab active' : 'inner-tab'
        }));
    }

    get isMasterDataTopTab() {
        return this.activeTopTab === 'masterData';
    }

    get isDashboardTopTab() {
        return this.activeTopTab === 'dashboard';
    }

    get isHostelCycleTopTab() {
        return this.activeTopTab === 'hostelCycle';
    }

    get isAccommodationTopTab() {
        return this.activeTopTab === 'accommodation';
    }

    get isReportsTopTab() {
        return this.activeTopTab === 'reports';
    }

    get isRoomCategoriesTab() {
        return this.activeMasterTab === 'roomCategories';
    }

    get isFeeTypesTab() {
        return this.activeMasterTab === 'feeTypes';
    }

    get isRoomCategoryListView() {
        return this.isRoomCategoriesTab && this.roomCategoryViewMode === 'list';
    }

    get isRoomCategoryDetailView() {
        return this.isRoomCategoriesTab && this.roomCategoryViewMode === 'detail';
    }

    get isBuildingDetailView() {
        return this.isBuildingsTab && this.buildingViewMode === 'detail';
    }

    get isRoomDetailView() {
        return this.isRoomsTab && this.roomViewMode === 'detail';
    }

    get isMasterListView() {
        return !this.isKenRoomCategoryDetailView && !this.isBuildingDetailView && !this.isRoomDetailView;
    }

    get isBuildingsTab() {
        return this.activeMasterTab === 'buildings';
    }

    get isRoomsTab() {
        return this.activeMasterTab === 'rooms';
    }

    renderedCallback() {
        this.runPendingDashboardQuickAction();
        this.runPendingReportsNavigation();
    }

    get primaryActionLabel() {
        if (this.isRoomCategoriesTab) {
            return 'New Room Category';
        }
        if (this.isBuildingsTab) {
            return 'New Building';
        }
        if (this.isRoomsTab) {
            return 'New Room';
        }
        return 'New';
    }

    get selectedRoomCategoryName() {
        return this.selectedRoomCategory?.categoryName || '--';
    }

    get selectedRoomCategoryGenderLabel() {
        const value = this.selectedRoomCategory?.genderAllowed;
        if (value === 'Male') {
            return 'Boys';
        }
        if (value === 'Female') {
            return 'Girls';
        }
        if (value === 'Any') {
            return 'Co-ed';
        }
        return value || '--';
    }

    get selectedRoomCategoryStatus() {
        return this.selectedRoomCategory?.status || '--';
    }

    get selectedRoomCategoryStatusClass() {
        return this.selectedRoomCategory?.statusValue === 'inactive'
            ? 'status-pill status-inactive'
            : 'status-pill status-active';
    }

    get selectedRoomCategoryDefaultFeeType() {
        return this.selectedRoomCategory?.defaultFeeType || '--';
    }

    get selectedRoomCategoryAmenities() {
        return this.selectedRoomCategory?.amenitiesList || [];
    }

    get linkedRoomsCount() {
        return (this.linkedRoomRows || []).length;
    }

    get linkedRoomsHeading() {
        return `Linked Rooms (${this.linkedRoomsCount})`;
    }

    get roomCategoryActivityCreatedByText() {
        const by = this.firstNonBlankUi(this.roomCategoryActivityHistory?.createdByName, '--');
        const at = this.formatDateValue(this.roomCategoryActivityHistory?.createdDate, false);
        return `${by} • ${at}`;
    }

    get roomCategoryActivityLastModifiedText() {
        const by = this.firstNonBlankUi(this.roomCategoryActivityHistory?.lastModifiedByName, '--');
        const at = this.formatDateValue(this.roomCategoryActivityHistory?.lastModifiedDate, false);
        return `${by} • ${at}`;
    }

    get roomCategoryActivityEvents() {
        const events = this.roomCategoryActivityHistory?.events || [];
        return events.map((event, index) => ({
            ...event,
            key: `${index}-${event.title || 'event'}`,
            eventAtText: this.formatDateValue(event.eventAt, true)
        }));
    }

    get selectedBuildingName() {
        return this.selectedBuilding?.name || '--';
    }

    get selectedBuildingStatus() {
        return this.selectedBuilding?.status || '--';
    }

    get selectedBuildingStatusClass() {
        return this.selectedBuilding?.statusValue === 'inactive'
            ? 'status-pill status-inactive'
            : 'status-pill status-active';
    }

    get selectedBuildingOverview() {
        const row = this.selectedBuilding || {};
        const fallback = this.buildingFallbackByName[row.name] || {};
        const capacityValue = this.toPositiveInt(row.capacity) || this.toPositiveInt(fallback.capacity);
        const floorsValue = this.toPositiveInt(row.floors) || this.toPositiveInt(fallback.floors);
        const roomsValue = this.toPositiveInt(row.roomsCount) || this.toPositiveInt(fallback.roomsCount);
        const occupancyPercent = this.resolveBuildingOccupancyPercent(row, fallback, capacityValue);
        const currentOccupancyText = this.resolveCurrentOccupancyText(row, fallback, capacityValue, occupancyPercent);
        const buildingIdentifier =
            this.firstNonBlankUi(row.buildingIdentifier, fallback.buildingIdentifier) ||
            this.buildingIdentifierFromId(row.id);
        const wardenName = this.firstNonBlankUi(row.wardenName, fallback.wardenName) || '--';

        return {
            buildingIdentifier,
            buildingName: this.selectedBuildingName,
            status: this.selectedBuildingStatus,
            floors: floorsValue || this.firstNonBlankUi(row.floors, '0'),
            wardenMode: this.firstNonBlankUi(row.wardenMode, fallback.wardenMode) || '--',
            wardenName,
            wardenPhone: this.firstNonBlankUi(row.wardenPhone, '--') || '--',
            capacity: capacityValue,
            currentOccupancyText,
            totalRooms: roomsValue || 0,
            occupancyPercent,
            utilizationStyle: `width: ${occupancyPercent}%`
        };
    }

    get buildingFloorSections() {
        const selectedBuildingId = this.selectedBuilding?.id;
        if (!selectedBuildingId) {
            return [];
        }

        const totalFloors = this.toPositiveInt(this.selectedBuildingOverview?.floors);
        if (totalFloors <= 0) {
            return [];
        }

        const roomsByFloor = new Map();
        (this.buildingDetailRoomRows || []).forEach((room) => {
            const floorNo = this.toFloorNumber(room.floor);
            if (floorNo <= 0) {
                return;
            }
            if (!roomsByFloor.has(floorNo)) {
                roomsByFloor.set(floorNo, []);
            }
            roomsByFloor.get(floorNo).push(room);
        });

        const sections = [];
        for (let floorNo = 1; floorNo <= totalFloors; floorNo += 1) {
            const floorKey = String(floorNo);
            const floorRooms = roomsByFloor.get(floorNo) || [];
            const floorCapacity = floorRooms.reduce((sum, room) => sum + this.toPositiveInt(room.capacity), 0);
            const floorOccupancy = floorRooms.reduce((sum, room) => sum + this.toPositiveInt(room.occupancy), 0);
            const occupancyPercent = floorCapacity > 0 ? Math.round((floorOccupancy / floorCapacity) * 100) : 0;
            const isExpanded = this.expandedBuildingFloorKeys.includes(floorKey);
            const floorWarden = this.buildingFloorWardenByNo?.[floorKey] || {};
            const isInheritedFromBuilding = floorWarden.isInheritedFromBuilding !== false;
            const wardenId =
                this.firstNonBlankUi(floorWarden.wardenId, this.selectedBuilding?.wardenId) || '';
            const detailWardenName = this.firstNonBlankUi(
                floorWarden.wardenName,
                this.selectedBuildingOverview?.wardenName,
                '--'
            );
            const detailWardenPhone = this.firstNonBlankUi(
                floorWarden.wardenPhone,
                this.selectedBuildingOverview?.wardenPhone,
                '--'
            );
            const summaryWardenName = this.firstNonBlankUi(detailWardenName, '--');
            const inheritedText = isInheritedFromBuilding ? '(Inherited from building)' : '';

            sections.push({
                key: floorKey,
                floorNo,
                title: `Floor ${floorNo}`,
                wardenId,
                roomsCount: floorRooms.length,
                hasRooms: floorRooms.length > 0,
                capacity: floorCapacity,
                occupancyText: `${floorOccupancy} / ${floorCapacity}`,
                occupancyPercent,
                wardenName: summaryWardenName,
                detailWardenName,
                detailWardenPhone,
                inheritedText,
                showInheritedNote: isInheritedFromBuilding,
                assignmentTypeLabel: this.firstNonBlankUi(
                    floorWarden.assignmentTypeLabel,
                    isInheritedFromBuilding ? 'Building Warden' : 'Floor Warden'
                ),
                rooms: floorRooms,
                isExpanded,
                chevronIcon: isExpanded ? 'utility:chevronup' : 'utility:chevrondown'
            });
        }
        return sections;
    }

    get floorWardenAssignmentTypeOptions() {
        return FLOOR_WARDEN_ASSIGNMENT_TYPE_OPTIONS;
    }

    get floorWardenModalTitle() {
        const floorNo = this.firstNonBlankUi(this.floorWardenForm?.floorNo);
        return floorNo ? `Add Warden - Floor ${floorNo}` : 'Add Warden';
    }

    get saveFloorWardenButtonLabel() {
        return this.isSavingFloorWarden ? 'Saving...' : 'Save Warden';
    }

    get buildingActivityCreatedByText() {
        const by = this.firstNonBlankUi(this.buildingActivityHistory?.createdByName, '--');
        const at = this.formatDateValue(this.buildingActivityHistory?.createdDate, false);
        return `${by} • ${at}`;
    }

    get buildingActivityCreatedByName() {
        return this.firstNonBlankUi(this.buildingActivityHistory?.createdByName, '--');
    }

    get buildingActivityCreatedDateText() {
        return this.formatDateValue(this.buildingActivityHistory?.createdDate, false);
    }

    get buildingActivityLastModifiedText() {
        const by = this.firstNonBlankUi(this.buildingActivityHistory?.lastModifiedByName, '--');
        const at = this.formatDateValue(this.buildingActivityHistory?.lastModifiedDate, false);
        return `${by} • ${at}`;
    }

    get buildingActivityEvents() {
        const events = this.buildingActivityHistory?.events || [];
        return events.map((event, index) => ({
            ...event,
            key: `${index}-${event.title || 'event'}`,
            eventAtText: this.formatDateValue(event.eventAt, true)
        }));
    }

    get selectedRoomNo() {
        return this.selectedRoom?.roomNo || '--';
    }

    get selectedRoomStatus() {
        return this.selectedRoom?.status || '--';
    }

    get selectedRoomBuildingId() {
        return this.selectedRoom?.buildingId || null;
    }

    get selectedRoomCategoryId() {
        return this.selectedRoom?.categoryId || null;
    }

    get canOpenLinkedBuildingFromRoom() {
        return !!this.selectedRoomBuildingId || this.hasUsableText(this.selectedRoomOverview?.building);
    }

    get canOpenLinkedCategoryFromRoom() {
        return !!this.selectedRoomCategoryId || this.hasUsableText(this.selectedRoomOverview?.category);
    }

    get isBuildingLinkDisabled() {
        return !this.canOpenLinkedBuildingFromRoom;
    }

    get isCategoryLinkDisabled() {
        return !this.canOpenLinkedCategoryFromRoom;
    }

    get selectedRoomStatusClass() {
        return this.resolveRoomStatusPillClass(this.selectedRoom?.statusValue);
    }

    resolveRoomStatusPillClass(statusValue, linked = false) {
        const normalized = this.normalizeRoomStatusForForm(statusValue);
        if (linked) {
            return normalized === 'inactive'
                ? 'status-pill status-linked-inactive'
                : 'status-pill status-linked-available';
        }
        return normalized === 'inactive'
            ? 'status-pill status-inactive'
            : 'status-pill status-active';
    }

    get selectedRoomOverview() {
        const row = this.selectedRoom || {};
        const rowCapacity = this.toPositiveInt(row.capacity);
        const displayCapacity = rowCapacity || 0;
        const safeCapacity = Math.max(1, displayCapacity || 1);
        const statusValue = this.firstNonBlankUi(
            row.statusValue,
            this.normalizeRoomStatusForForm(row.status),
            'active'
        );

        let occupancy = this.toPositiveInt(row.occupancy);
        if (occupancy <= 0 && statusValue === 'occupied') {
            occupancy = safeCapacity;
        } else if (occupancy <= 0 && statusValue === 'partiallyOccupied') {
            occupancy = Math.min(safeCapacity, 1);
        }

        const clampedOccupancy = Math.max(0, Math.min(occupancy, safeCapacity));
        const occupancyText = displayCapacity > 0 ? `${clampedOccupancy} / ${displayCapacity}` : '--';
        const roomNoText = this.firstNonBlankUi(row.roomNo, '--');
        const buildingText = this.firstNonBlankUi(row.building, '--');
        const title = this.firstNonBlankUi(row.roomTitle) ||
            (buildingText && buildingText !== '--' ? `${roomNoText} - ${buildingText}` : roomNoText);
        const feeType = this.firstNonBlankUi(row.feeType) || '--';

        return {
            roomTitle: title,
            roomIdentifier: this.firstNonBlankUi(row.roomIdentifier, '--'),
            buildingId: row.buildingId || null,
            building: buildingText,
            categoryId: row.categoryId || null,
            category: this.firstNonBlankUi(row.category, '--'),
            floor: this.firstNonBlankUi(row.floor, '--'),
            capacity: displayCapacity,
            occupancyText,
            status: this.selectedRoomStatus,
            feeType,
            utilizationStyle: `width: ${Math.round((clampedOccupancy / safeCapacity) * 100)}%`
        };
    }

    get selectedRoomAmenitiesFromCategory() {
        return this.selectedRoom?.amenitiesList || [];
    }

    get currentOccupantsCount() {
        return (this.roomCurrentOccupants || []).length;
    }

    get currentOccupantsHeading() {
        return `Current Occupants (${this.currentOccupantsCount})`;
    }

    get roomCurrentOccupantsUiRows() {
        return (this.roomCurrentOccupants || []).map((row, index) => ({
            ...row,
            key: row.id || `current-${index}`,
            checkInDateText: this.formatDateValue(row.checkInDate, false),
            enrollmentCycleText: this.firstNonBlankUi(row.enrollmentCycle, '--')
        }));
    }

    get roomPastOccupantsUiRows() {
        return (this.roomPastOccupants || []).map((row, index) => ({
            ...row,
            key: row.id || `past-${index}`,
            checkInDateText: this.formatDateValue(row.checkInDate, false),
            checkOutDateText: this.formatDateValue(row.checkOutDate, false),
            academicYearText: '--',
            statusText: row.active ? 'Active' : 'Completed',
            statusClass: row.active ? 'status-pill status-active' : 'status-pill status-completed'
        }));
    }

    get roomActivityCreatedByText() {
        const by = this.firstNonBlankUi(this.roomOccupancyDetails?.createdByName, '--');
        const at = this.formatDateValue(this.roomOccupancyDetails?.createdDate, false);
        return `${by} • ${at}`;
    }

    get roomActivityCreatedByName() {
        return this.firstNonBlankUi(this.roomOccupancyDetails?.createdByName, '--');
    }

    get roomActivityCreatedDateText() {
        return this.formatDateValue(this.roomOccupancyDetails?.createdDate, false);
    }

    get roomActivityLastModifiedText() {
        const by = this.firstNonBlankUi(this.roomOccupancyDetails?.lastModifiedByName, '--');
        const at = this.formatDateValue(this.roomOccupancyDetails?.lastModifiedDate, false);
        return `${by} • ${at}`;
    }

    get roomActivityEvents() {
        const events = this.roomOccupancyDetails?.events || [];
        return events.map((event, index) => ({
            ...event,
            key: `${index}-${event.title || 'event'}`,
            eventAtText: this.formatDateValue(event.eventAt, true)
        }));
    }

    get createRoomCategoryButtonLabel() {
        if (this.isSavingRoomCategory) {
            return this.isEditingRoomCategory ? 'Updating...' : 'Creating...';
        }
        return this.isEditingRoomCategory ? 'Update' : 'Create';
    }

    get isEditingRoomCategory() {
        return !!this.editingRoomCategoryId;
    }

    get roomCategoryModalTitle() {
        return this.isEditingRoomCategory ? 'Edit Room Category' : 'New Room Category';
    }

    get isEditingBuilding() {
        return !!this.editingBuildingId;
    }

    get isEditingRoom() {
        return !!this.editingRoomId;
    }

    get buildingModalTitle() {
        return this.isEditingBuilding ? 'Edit Building' : 'New Building';
    }

    get roomModalTitle() {
        return this.isEditingRoom ? 'Edit Room' : 'New Room';
    }

    get createBuildingButtonLabel() {
        if (this.isSavingBuilding) {
            return this.isEditingBuilding ? 'Updating...' : 'Creating...';
        }
        return this.isEditingBuilding ? 'Update' : 'Create';
    }

    get createRoomButtonLabel() {
        if (this.isSavingRoom) {
            return this.isEditingRoom ? 'Updating...' : 'Creating...';
        }
        return this.isEditingRoom ? 'Update' : 'Create';
    }

    get filteredRoomFloorOptions() {
        const selectedBuildingValue = this.roomForm?.buildingValue;
        if (!selectedBuildingValue) {
            return [];
        }
        return (this.roomFloorOptions || []).filter((item) => item.buildingValue === selectedBuildingValue);
    }

    get isRoomFloorDisabled() {
        return !this.roomForm?.buildingValue;
    }

    get buildingWardenModeUiOptions() {
        const selectedMode = this.buildingForm.wardenMode;
        return (this.buildingWardenModeOptions || []).map((item) => ({
            ...item,
            checked: item.value === selectedMode
        }));
    }

    get roomCategoryAmenitiesUiOptions() {
        const selected = new Set(this.roomCategoryForm.amenities || []);
        return (this.roomCategoryAmenitiesOptions || []).map((item) => ({
            ...item,
            checked: selected.has(item.value)
        }));
    }

    get selectedAmenitiesText() {
        const selected = this.roomCategoryForm.amenities || [];
        return selected.length ? selected.join(', ') : '';
    }

    get statusOptions() {
        if (this.isRoomsTab) {
            const roomOptions = this.roomStatusOptions || [];
            if (roomOptions.length) {
                return [{ value: 'all', label: 'All Status' }, ...roomOptions];
            }
            return [
                { value: 'all', label: 'All Status' },
                { value: 'active', label: 'Active' },
                { value: 'inactive', label: 'Inactive' }
            ];
        }

        if (this.isBuildingsTab || this.isRoomCategoriesTab) {
            return [
                { value: 'all', label: 'All Status' },
                { value: 'active', label: 'Active' },
                { value: 'inactive', label: 'Inactive' }
            ];
        }

        return [{ value: 'all', label: 'All Status' }];
    }

    get filteredBuildingRows() {
        if (this.selectedStatus === 'all') {
            return this.buildingRows;
        }
        return this.buildingRows.filter((row) => row.statusValue === this.selectedStatus);
    }

    get filteredRoomCategoryRows() {
        return this.roomCategoryRows;
    }

    get filteredRoomRows() {
        if (this.selectedStatus === 'all') {
            return this.roomRows;
        }
        return this.roomRows.filter((row) => row.statusValue === this.selectedStatus);
    }

    handleTopTabClick(event) {
        const key = event.currentTarget.dataset.key;
        this.activeTopTab = key;
        this.pendingDashboardQuickAction = null;
        this.persistNavigationState();
        if (key === 'masterData') {
            this.initializeMasterData();
        }
        this.dispatchEvent(new CustomEvent('toptabchange', { detail: { key } }));
    }

    handleMasterTabClick(event) {
        const key = event.currentTarget.dataset.key;
        this.activateMasterTab(key);
    }

    handleBreadcrumbDashboardClick() {
        const key = 'dashboard';
        this.activeTopTab = key;
        this.persistNavigationState();
        this.dispatchEvent(new CustomEvent('toptabchange', { detail: { key } }));
    }

    handleBreadcrumbMasterDataClick() {
        const key = 'masterData';
        this.activeTopTab = key;
        this.persistNavigationState();
        this.dispatchEvent(new CustomEvent('toptabchange', { detail: { key } }));
        this.activateMasterTab(this.activeMasterTab || 'roomCategories');
    }

    handleBreadcrumbMasterTabClick(event) {
        const key = event.currentTarget.dataset.key;
        if (!key) {
            return;
        }

        this.activeTopTab = 'masterData';
        this.persistNavigationState();
        this.dispatchEvent(new CustomEvent('toptabchange', { detail: { key: 'masterData' } }));
        this.activateMasterTab(key);
    }

    activateMasterTab(key) {
        if (!key) {
            return;
        }

        this.activeMasterTab = key;
        this.selectedStatus = 'all';
        this.isKenRoomCategoryDetailView = false;
        this.kenRoomCategoryDetailId = null;
        this.roomCategoryViewMode = 'list';
        this.buildingViewMode = 'list';
        this.roomViewMode = 'list';
        this.selectedBuilding = null;
        this.selectedRoom = null;
        this.selectedRoomCategory = null;
        this.persistNavigationState();

        if (key === 'buildings') {
            this.loadBuildings();
            this.loadBuildingFormOptions();
        } else if (key === 'rooms') {
            this.loadRooms();
            this.loadRoomFormOptions();
        }

        this.dispatchEvent(new CustomEvent('mastertabchange', { detail: { key } }));
    }

    handleDashboardQuickAction(event) {
        const action = event.detail?.action;
        const cycleId = event.detail?.cycleId || '';
        const windowId = event.detail?.windowId || '';
        const reportSection = event.detail?.reportSection || '';
        if (!action) {
            return;
        }

        let nextTopTab = '';
        if (action === 'createCycle' || action === 'addWindow') {
            nextTopTab = 'hostelCycle';
            this.pendingDashboardQuickAction = { action, cycleId };
            this.pendingReportsNavigation = null;
        } else if (action === 'runAutoAllotment' || action === 'viewAccommodation') {
            nextTopTab = 'accommodation';
            this.pendingDashboardQuickAction = null;
            this.pendingReportsNavigation = null;
        } else if (action === 'reports') {
            nextTopTab = 'reports';
            this.pendingDashboardQuickAction = null;
            this.pendingReportsNavigation = {
                cycleId,
                windowId,
                reportSection
            };
        }

        if (!nextTopTab) {
            return;
        }

        this.activeTopTab = nextTopTab;
        this.persistNavigationState();
        this.dispatchEvent(new CustomEvent('toptabchange', { detail: { key: nextTopTab } }));
    }

    runPendingDashboardQuickAction() {
        const pendingAction = this.pendingDashboardQuickAction;
        if (!pendingAction || this.activeTopTab !== 'hostelCycle') {
            return;
        }

        const hostelCycleScreen = this.template.querySelector('c-ken-hostel-cycle-screen');
        if (!hostelCycleScreen) {
            return;
        }

        this.pendingDashboardQuickAction = null;
        if (pendingAction.action === 'createCycle') {
            hostelCycleScreen.openCreateCycleForm();
            return;
        }

        if (pendingAction.action === 'addWindow') {
            hostelCycleScreen.openAddWindowForm(pendingAction.cycleId);
        }
    }

    runPendingReportsNavigation() {
        const pendingNavigation = this.pendingReportsNavigation;
        if (!pendingNavigation || this.activeTopTab !== 'reports') {
            return;
        }

        const reportsScreen = this.template.querySelector('c-ken-reports-analytics-screen');
        if (!reportsScreen || typeof reportsScreen.openReportView !== 'function') {
            return;
        }

        this.pendingReportsNavigation = null;
        Promise.resolve(
            reportsScreen.openReportView(
                pendingNavigation.cycleId,
                pendingNavigation.windowId,
                pendingNavigation.reportSection
            )
        ).catch(() => {});
    }

    handleKenRoomCategoryViewModeChange(event) {
        this.isKenRoomCategoryDetailView = !!event.detail?.isDetail;
        this.kenRoomCategoryDetailId = event.detail?.selectedRoomCategoryId || null;
    }

    handleOpenPrimaryModal() {
        if (this.isRoomCategoryDetailView || this.isBuildingDetailView || this.isRoomDetailView) {
            return;
        }

        if (this.isRoomCategoriesTab) {
            const roomCategoryCmp = this.template.querySelector('c-ken-room-category');
            if (roomCategoryCmp && typeof roomCategoryCmp.openNewRoomCategoryModal === 'function') {
                roomCategoryCmp.openNewRoomCategoryModal();
            }
            return;
        }

        if (this.isBuildingsTab) {
            this.editingBuildingId = null;
            this.resetBuildingForm();
            this.isNewBuildingModalOpen = true;
            return;
        }

        if (this.isRoomsTab) {
            this.loadRoomFormOptions();
            this.editingRoomId = null;
            this.editingRoomInitialFloorId = '';
            this.isNewRoomModalOpen = true;
        }
    }

    handleStatusChange(event) {
        this.selectedStatus = event.target.value;
        if (this.isRoomCategoriesTab) {
            this.loadRoomCategories();
        } else if (this.isBuildingsTab) {
            this.loadBuildings();
        } else if (this.isRoomsTab) {
            this.loadRooms();
        }
    }

    handleKenChildStatusChange(event) {
        const value = event.detail?.value;
        if (!value) {
            return;
        }
        this.selectedStatus = value;
        if (this.isBuildingsTab) {
            this.loadBuildings();
            return;
        }
        if (this.isRoomsTab) {
            this.loadRooms();
        }
    }

    handleKenChildOpenModal() {
        this.handleOpenPrimaryModal();
    }

    handleKenBuildingToggleFloorSection(event) {
        const floorKey = event.detail?.floorKey;
        if (!floorKey) {
            return;
        }
        this.handleToggleFloorSection({
            currentTarget: {
                dataset: {
                    floorKey
                }
            }
        });
    }

    async handleKenBuildingAddRoomForFloor(event) {
        const floorNo = event.detail?.floorNo;
        await this.handleAddRoomForFloor({
            currentTarget: {
                dataset: {
                    floorNo
                }
            }
        });
    }

    handleKenBuildingOpenFloorWardenModal(event) {
        const floorNo = this.toPositiveInt(event.detail?.floorNo);
        if (!this.selectedBuilding?.id || floorNo <= 0) {
            return;
        }

        const existingFloorWarden = this.buildingFloorWardenByNo?.[String(floorNo)] || {};
        const wardenId = existingFloorWarden.wardenId || '';
        const wardenMeta = this.resolveWardenMeta(wardenId);
        this.floorWardenForm = {
            floorNo: String(floorNo),
            wardenId,
            assignmentType: existingFloorWarden.assignmentTypeLabel || 'Floor Warden',
            phone: this.firstNonBlankUi(wardenMeta.phone, existingFloorWarden.wardenPhone, '') || '',
            description: this.firstNonBlankUi(wardenMeta.description, '') || ''
        };
        this.isFloorWardenModalOpen = true;
    }

    handleKenBuildingFloorWardenFieldChange(event) {
        const field = event.detail?.field;
        if (!field) {
            return;
        }

        const value = event.detail?.value || '';

        if (field === 'wardenId') {
            const wardenMeta = this.resolveWardenMeta(value);
            this.floorWardenForm = {
                ...this.floorWardenForm,
                wardenId: value,
                phone: this.firstNonBlankUi(wardenMeta.phone, '') || '',
                description: this.firstNonBlankUi(wardenMeta.description, '') || ''
            };
            return;
        }

        this.floorWardenForm = {
            ...this.floorWardenForm,
            [field]: value
        };
    }

    handleCloseFloorWardenModal() {
        if (this.isSavingFloorWarden) {
            return;
        }
        this.isFloorWardenModalOpen = false;
        this.resetFloorWardenForm();
    }

    async handleKenBuildingViewRoomFromFloor(event) {
        const id = event.detail?.id;
        await this.handleViewRoomFromFloorSection({
            currentTarget: {
                dataset: {
                    id
                }
            }
        });
    }

    async handleKenBuildingEditRoomFromFloor(event) {
        const id = event.detail?.id;
        await this.handleEditRoomFromFloorSection({
            currentTarget: {
                dataset: {
                    id
                }
            }
        });
    }

    async handleKenBuildingDeleteRoomFromFloor(event) {
        const id = event.detail?.id;
        await this.handleDeleteRoomFromFloorSection({
            currentTarget: {
                dataset: {
                    id
                }
            }
        });
    }

    handleKenBuildingBreadcrumbMasterTab(event) {
        const key = event.detail?.key || 'buildings';
        this.handleBreadcrumbMasterTabClick({
            currentTarget: {
                dataset: {
                    key
                }
            }
        });
    }

    handleKenRoomBreadcrumbMasterTab(event) {
        const key = event.detail?.key || 'rooms';
        this.handleBreadcrumbMasterTabClick({
            currentTarget: {
                dataset: {
                    key
                }
            }
        });
    }

    handleKenBuildingFieldChange(event) {
        const field = event.detail?.field;
        if (!field) {
            return;
        }
        this.handleBuildingFieldChange({
            target: {
                dataset: {
                    field
                },
                value: event.detail?.value
            }
        });
    }

    handleKenRoomFieldChange(event) {
        const field = event.detail?.field;
        if (!field) {
            return;
        }
        this.handleRoomFieldChange({
            target: {
                dataset: {
                    field
                },
                value: event.detail?.value
            }
        });
    }

    async handleKenRoomCategoryNavigate(event) {
        const navigateType = event.detail?.type;
        if (!navigateType) {
            return;
        }

        if (navigateType === 'viewAllRooms') {
            this.selectedStatus = 'all';
            this.activeMasterTab = 'rooms';
            this.isKenRoomCategoryDetailView = false;
            this.kenRoomCategoryDetailId = null;
            this.roomCategoryViewMode = 'list';
            this.roomViewMode = 'list';
            this.selectedRoomCategory = null;
            this.persistNavigationState();
            await this.loadRooms();
            return;
        }

        if (navigateType === 'openRoom') {
            const roomId = event.detail?.roomId;
            if (!roomId) {
                return;
            }

            this.selectedStatus = 'all';
            this.activeMasterTab = 'rooms';
            this.isKenRoomCategoryDetailView = false;
            this.kenRoomCategoryDetailId = null;
            this.roomCategoryViewMode = 'list';
            this.buildingViewMode = 'list';
            this.selectedRoomCategory = null;
            this.persistNavigationState();
            await this.loadRooms();

            const selectedRow = (this.roomRows || []).find((row) => String(row.id) === String(roomId));
            if (!selectedRow) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Warning',
                        message: 'Linked room record was not found.',
                        variant: 'warning'
                    })
                );
                return;
            }

            this.selectedRoom = selectedRow;
            this.selectedBuilding = null;
            this.selectedRoomCategory = null;
            this.roomViewMode = 'detail';
            await this.loadRoomOccupancyDetails();
            return;
        }

        if (navigateType === 'openBuilding') {
            const linkedBuildingId = event.detail?.buildingId;
            const linkedBuildingName = event.detail?.buildingName;
            if (!linkedBuildingId && !this.hasUsableText(linkedBuildingName)) {
                return;
            }

            this.selectedStatus = 'all';
            this.activeMasterTab = 'buildings';
            this.isKenRoomCategoryDetailView = false;
            this.kenRoomCategoryDetailId = null;
            this.roomCategoryViewMode = 'list';
            this.roomViewMode = 'list';
            this.selectedRoomCategory = null;
            this.persistNavigationState();
            await this.loadBuildings();

            let linkedBuilding = null;
            if (linkedBuildingId) {
                linkedBuilding = (this.buildingRows || []).find((row) => String(row.id) === String(linkedBuildingId));
            }
            if (!linkedBuilding && this.hasUsableText(linkedBuildingName)) {
                linkedBuilding = (this.buildingRows || []).find(
                    (row) => this.normalizeLookupLabel(row.name) === this.normalizeLookupLabel(linkedBuildingName)
                );
            }
            if (!linkedBuilding) {
                try {
                    linkedBuilding = await getBuildingDetail({
                        buildingId: linkedBuildingId,
                        buildingName: linkedBuildingName
                    });
                    if (linkedBuilding) {
                        linkedBuilding = {
                            ...linkedBuilding,
                            statusClass:
                                linkedBuilding.statusValue === 'active'
                                    ? 'status-pill status-active'
                                    : 'status-pill status-inactive'
                        };
                    }
                } catch {
                    linkedBuilding = null;
                }
            }

            if (!linkedBuilding) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Warning',
                        message: 'Linked building record was not found.',
                        variant: 'warning'
                    })
                );
                return;
            }

            if (!(this.buildingRows || []).some((row) => String(row.id) === String(linkedBuilding.id))) {
                this.buildingRows = [linkedBuilding, ...(this.buildingRows || [])];
            }

            this.selectedBuilding = linkedBuilding;
            this.selectedRoom = null;
            this.selectedRoomCategory = null;
            this.buildingViewMode = 'detail';
            this.expandedBuildingFloorKeys = [];
            await Promise.all([this.loadBuildingFloorRooms(), this.loadBuildingActivityHistory()]);
        }
    }

    handleKenRoomCategoryRowAction(event) {
        const action = event.detail?.action;
        const rowId = event.detail?.id;
        if (!action || !rowId) {
            return;
        }
        const syntheticEvent = this.buildSyntheticActionEvent(rowId);
        if (action === 'open' || action === 'view') {
            this.handleOpenRoomCategoryDetail(syntheticEvent);
            return;
        }
        if (action === 'edit') {
            this.handleEditRoomCategoryAction(syntheticEvent);
            return;
        }
        if (action === 'delete') {
            this.handleDeleteRoomCategoryAction(syntheticEvent);
        }
    }

    handleKenBuildingRowAction(event) {
        const action = event.detail?.action;
        const rowId = event.detail?.id;
        if (!action || !rowId) {
            return;
        }
        const syntheticEvent = this.buildSyntheticActionEvent(rowId);
        if (action === 'open') {
            this.handleOpenBuildingDetail(syntheticEvent);
            return;
        }
        if (action === 'edit') {
            this.handleEditBuildingAction(syntheticEvent);
            return;
        }
        if (action === 'delete') {
            this.handleDeleteBuildingAction(syntheticEvent);
        }
    }

    handleKenRoomRowAction(event) {
        const action = event.detail?.action;
        const rowId = event.detail?.id;
        if (!action || !rowId) {
            return;
        }
        const syntheticEvent = this.buildSyntheticActionEvent(rowId);
        if (action === 'open') {
            this.handleOpenRoomDetail(syntheticEvent);
            return;
        }
        if (action === 'edit') {
            this.handleEditRoomAction(syntheticEvent);
            return;
        }
        if (action === 'delete') {
            this.handleDeleteRoomAction(syntheticEvent);
        }
    }

    handleCloseNewRoomCategoryModal() {
        this.isNewRoomCategoryModalOpen = false;
        this.editingRoomCategoryId = null;
        this.resetRoomCategoryForm();
    }

    handleCloseNewBuildingModal() {
        this.isNewBuildingModalOpen = false;
        this.editingBuildingId = null;
        this.resetBuildingForm();
    }

    handleCloseNewRoomModal() {
        this.isNewRoomModalOpen = false;
        this.editingRoomId = null;
        this.editingRoomInitialFloorId = '';
        this.resetRoomForm();
    }

    async handleOpenRoomCategoryDetail(event) {
        const rowId = event.currentTarget.dataset.id;
        const selectedRow = (this.roomCategoryRows || []).find((row) => String(row.id) === String(rowId));
        if (!selectedRow) {
            return;
        }

        this.selectedRoomCategory = selectedRow;
        this.roomCategoryViewMode = 'detail';
        await Promise.all([this.loadLinkedRoomsForSelectedCategory(), this.loadRoomCategoryActivityHistory()]);
    }

    handleBackToRoomCategoryList() {
        this.roomCategoryViewMode = 'list';
        this.linkedRoomRows = [];
        this.roomCategoryActivityHistory = null;
    }

    handleViewRoomCategoryAction(event) {
        this.handleOpenRoomCategoryDetail(event);
    }

    async handleViewAllLinkedRooms() {
        this.activeMasterTab = 'rooms';
        this.roomViewMode = 'list';
        this.selectedStatus = 'all';
        await this.loadRooms();
    }

    async handleOpenLinkedRoomFromCategory(event) {
        const rowId = event.currentTarget.dataset.id;
        const selectedRow = (this.linkedRoomRows || []).find((row) => String(row.id) === String(rowId));
        if (!selectedRow) {
            return;
        }

        this.selectedStatus = 'all';
        this.activeMasterTab = 'rooms';
        this.selectedRoom = selectedRow;
        this.selectedBuilding = null;
        this.selectedRoomCategory = null;
        this.roomCategoryViewMode = 'list';
        this.buildingViewMode = 'list';
        this.roomViewMode = 'detail';
        await this.loadRoomOccupancyDetails();
    }

    async handleOpenLinkedBuildingFromCategory(event) {
        const roomId = event.currentTarget.dataset.roomId;
        const selectedRoomRow = (this.linkedRoomRows || []).find((row) => String(row.id) === String(roomId));
        if (!selectedRoomRow) {
            return;
        }

        const linkedBuildingId = selectedRoomRow.buildingId;
        const linkedBuildingName = selectedRoomRow.building;
        if (!linkedBuildingId && !this.hasUsableText(linkedBuildingName)) {
            return;
        }

        let linkedBuilding = null;
        if (linkedBuildingId) {
            linkedBuilding = (this.buildingRows || []).find((row) => String(row.id) === String(linkedBuildingId));
        }
        if (!linkedBuilding && this.hasUsableText(linkedBuildingName)) {
            linkedBuilding = (this.buildingRows || []).find(
                (row) => this.normalizeLookupLabel(row.name) === this.normalizeLookupLabel(linkedBuildingName)
            );
        }
        if (!linkedBuilding) {
            try {
                linkedBuilding = await getBuildingDetail({
                    buildingId: linkedBuildingId,
                    buildingName: linkedBuildingName
                });
                if (linkedBuilding) {
                    linkedBuilding = {
                        ...linkedBuilding,
                        statusClass:
                            linkedBuilding.statusValue === 'active'
                                ? 'status-pill status-active'
                                : 'status-pill status-inactive'
                    };
                }
            } catch {
                linkedBuilding = null;
            }
        }

        if (!linkedBuilding) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Warning',
                    message: 'Linked building record was not found.',
                    variant: 'warning'
                })
            );
            return;
        }

        if (!(this.buildingRows || []).some((row) => String(row.id) === String(linkedBuilding.id))) {
            this.buildingRows = [linkedBuilding, ...(this.buildingRows || [])];
        }

        this.selectedStatus = 'all';
        this.activeMasterTab = 'buildings';
        this.selectedBuilding = linkedBuilding;
        this.selectedRoom = null;
        this.selectedRoomCategory = null;
        this.roomViewMode = 'list';
        this.roomCategoryViewMode = 'list';
        this.buildingViewMode = 'detail';
        this.expandedBuildingFloorKeys = [];
        await Promise.all([this.loadBuildingFloorRooms(), this.loadBuildingActivityHistory()]);
    }

    buildSyntheticActionEvent(recordId) {
        return {
            currentTarget: {
                dataset: {
                    id: recordId
                }
            }
        };
    }

    async handleEditSelectedRoomCategory() {
        const rowId = this.selectedRoomCategory?.id;
        if (!rowId) {
            return;
        }
        await this.handleEditRoomCategoryAction(this.buildSyntheticActionEvent(rowId));
    }

    async handleDeactivateSelectedRoomCategory() {
        const selectedRow = this.selectedRoomCategory;
        if (!selectedRow?.id) {
            return;
        }

        if (selectedRow.statusValue === 'inactive') {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Info',
                    message: 'Room category is already inactive.',
                    variant: 'info'
                })
            );
            return;
        }

        const confirmed = window.confirm(`Deactivate room category "${selectedRow.categoryName}"?`);
        if (!confirmed) {
            return;
        }

        try {
            await updateRoomCategory({
                roomCategoryId: String(selectedRow.id),
                inputRequest: { statusValue: 'inactive' }
            });
            this.selectedStatus = 'all';
            await this.loadRoomCategories();
            await this.loadRoomFormOptions();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Room category deactivated successfully.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        }
    }

    async handleEditRoomCategoryAction(event) {
        const rowId = event.currentTarget.dataset.id;
        const selectedRowFromList = (this.roomCategoryRows || []).find((row) => String(row.id) === String(rowId));
        const selectedRowFromDetail =
            this.selectedRoomCategory && this.idsEqual(this.selectedRoomCategory.id, rowId)
                ? this.selectedRoomCategory
                : null;
        const selectedRow = selectedRowFromDetail || selectedRowFromList;
        if (!selectedRow) {
            return;
        }

        if (
            !(this.roomCategoryGenderOptions || []).length ||
            !(this.roomCategoryAmenitiesOptions || []).length ||
            !(this.roomCategoryStatusOptions || []).length
        ) {
            await this.loadRoomCategoryFormOptions();
        }

        const feeTypeId =
            this.firstNonBlankUi(
                selectedRow.defaultFeeTypeId,
                this.findOptionValueByLabel(this.roomCategoryFeeTypeOptions, selectedRow.defaultFeeType)
            ) || '';
        const selectedAmenities = Array.isArray(selectedRow.amenitiesList)
            ? [...selectedRow.amenitiesList]
            : [];

        const statusValue = this.resolveRoomCategoryStatusValueForForm(
            selectedRow.statusValue,
            selectedRow.status
        );

        this.roomCategoryForm = {
            categoryName: this.firstNonBlankUi(selectedRow.categoryName, '') || '',
            description: this.firstNonBlankUi(selectedRow.description, '') || '',
            genderAllowed: this.firstNonBlankUi(selectedRow.genderAllowed, '') || '',
            defaultFeeTypeId: feeTypeId,
            statusValue: statusValue || 'active',
            amenities: selectedAmenities
        };
        this.editingRoomCategoryId = selectedRow.id;
        this.customAmenityInput = '';
        this.isNewRoomCategoryModalOpen = true;
    }

    async handleDeleteRoomCategoryAction(event) {
        const rowId = event.currentTarget.dataset.id;
        const selectedRow = (this.roomCategoryRows || []).find((row) => String(row.id) === String(rowId));
        if (!selectedRow) {
            return;
        }

        const confirmed = window.confirm(`Delete room category "${selectedRow.categoryName}"?`);
        if (!confirmed) {
            return;
        }

        try {
            await deleteRoomCategoryRecord({ roomCategoryId: String(rowId) });
            await this.loadRoomCategories();
            await this.loadRoomFormOptions();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Room category deleted successfully.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        }
    }

    async handleOpenBuildingDetail(event) {
        const rowId = event.currentTarget.dataset.id;
        const selectedRow = (this.buildingRows || []).find((row) => String(row.id) === String(rowId));
        if (!selectedRow) {
            return;
        }

        this.selectedBuilding = selectedRow;
        this.buildingViewMode = 'detail';
        this.expandedBuildingFloorKeys = [];
        await Promise.all([this.loadBuildingFloorRooms(), this.loadBuildingActivityHistory()]);
    }

    handleBackToBuildingList() {
        this.buildingViewMode = 'list';
        this.selectedBuilding = null;
        this.buildingDetailRoomRows = [];
        this.expandedBuildingFloorKeys = [];
        this.buildingFloorWardenByNo = {};
        this.buildingActivityHistory = null;
        this.isFloorWardenModalOpen = false;
        this.resetFloorWardenForm();
    }

    async handleEditSelectedBuilding() {
        const rowId = this.selectedBuilding?.id;
        if (!rowId) {
            return;
        }
        await this.handleEditBuildingAction(this.buildSyntheticActionEvent(rowId));
    }

    async handleDeactivateSelectedBuilding() {
        const selectedRow = this.selectedBuilding;
        if (!selectedRow?.id) {
            return;
        }

        if (selectedRow.statusValue === 'inactive') {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Info',
                    message: 'Building is already inactive.',
                    variant: 'info'
                })
            );
            return;
        }

        const confirmed = window.confirm(`Deactivate building "${selectedRow.name}"?`);
        if (!confirmed) {
            return;
        }

        try {
            await updateBuilding({
                buildingId: String(selectedRow.id),
                inputRequest: { statusValue: 'Inactive' }
            });
            this.selectedStatus = 'all';
            await this.loadBuildings();
            await this.loadRoomFormOptions();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Building deactivated successfully.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        }
    }

    async handleOpenRoomDetail(event) {
        const rowId = event.currentTarget.dataset.id;
        const selectedRow = (this.roomRows || []).find((row) => String(row.id) === String(rowId));
        if (!selectedRow) {
            return;
        }

        this.selectedRoom = selectedRow;
        this.roomViewMode = 'detail';
        await this.loadRoomOccupancyDetails();
    }

    handleBackToRoomList() {
        this.roomViewMode = 'list';
        this.selectedRoom = null;
        this.roomOccupancyDetails = null;
        this.roomCurrentOccupants = [];
        this.roomPastOccupants = [];
    }

    async handleEditSelectedRoom() {
        const rowId = this.selectedRoom?.id;
        if (!rowId) {
            return;
        }
        await this.handleEditRoomAction(this.buildSyntheticActionEvent(rowId));
    }

    async handleDeactivateSelectedRoom() {
        const selectedRow = this.selectedRoom;
        if (!selectedRow?.id) {
            return;
        }

        if (this.normalizeRoomStatusForForm(selectedRow.statusValue) === 'inactive') {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Info',
                    message: 'Room is already deactivated.',
                    variant: 'info'
                })
            );
            return;
        }

        const confirmed = window.confirm(`Deactivate room "${selectedRow.roomNo}"?`);
        if (!confirmed) {
            return;
        }

        try {
            await updateRoom({
                roomId: String(selectedRow.id),
                inputRequest: { statusValue: 'inactive' }
            });
            this.selectedStatus = 'all';
            await this.loadRooms();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Room deactivated successfully.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        }
    }

    async handleEditBuildingAction(event) {
        const rowId = event.currentTarget.dataset.id;
        const selectedRowFromList = (this.buildingRows || []).find((row) => String(row.id) === String(rowId));
        const selectedRowFromDetail =
            this.selectedBuilding && this.idsEqual(this.selectedBuilding.id, rowId)
                ? this.selectedBuilding
                : null;
        let selectedRow = selectedRowFromDetail || selectedRowFromList;
        if (!selectedRow) {
            return;
        }

        if (
            !(this.buildingGenderOptions || []).length ||
            !(this.buildingHostelTypeOptions || []).length ||
            !(this.buildingStatusOptions || []).length ||
            !(this.buildingWardenOptions || []).length
        ) {
            await this.loadBuildingFormOptions();
        }

        try {
            const serverRow = await getBuildingDetail({
                buildingId: String(rowId),
                buildingName: null
            });
            if (serverRow?.id) {
                selectedRow = {
                    ...selectedRow,
                    ...serverRow
                };
            }
        } catch {
            selectedRow = selectedRowFromDetail || selectedRowFromList;
        }

        const hostelTypeValue =
            this.resolveOptionValue(
                this.buildingHostelTypeOptions,
                selectedRow.hostelTypeValue,
                selectedRow.gender
            ) ||
            this.resolveOptionValue(
                this.buildingGenderOptions,
                selectedRow.hostelTypeValue,
                selectedRow.gender
            ) ||
            this.normalizeHostelTypeForForm(selectedRow.hostelTypeValue || selectedRow.gender) ||
            '';
        const statusValue =
            this.resolveBuildingStatusValueForForm(selectedRow.statusValue, selectedRow.status) || 'Active';
        const buildingWarden =
            this.resolveOptionValue(
                this.buildingWardenOptions,
                selectedRow.wardenId,
                selectedRow.wardenName
            ) || '';

        this.buildingForm = {
            buildingName: this.firstNonBlankUi(selectedRow.name, '') || '',
            genderValue: hostelTypeValue || '',
            hostelTypeValue: hostelTypeValue || '',
            statusValue,
            numberOfFloors: this.firstNonBlankUi(selectedRow.floors, '') || '',
            wardenMode: 'Building Level',
            buildingWarden
        };
        this.editingBuildingId = selectedRow.id;
        this.isNewBuildingModalOpen = true;
    }

    async handleDeleteBuildingAction(event) {
        const rowId = event.currentTarget.dataset.id;
        const selectedRow = (this.buildingRows || []).find((row) => String(row.id) === String(rowId));
        if (!selectedRow) {
            return;
        }

        const confirmed = window.confirm(`Delete building "${selectedRow.name}"?`);
        if (!confirmed) {
            return;
        }

        try {
            await deleteBuildingRecord({ buildingId: String(rowId) });
            await this.loadBuildings();
            await this.loadRoomFormOptions();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Building deleted successfully.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        }
    }

    async handleEditRoomAction(event) {
        const rowId = event.currentTarget.dataset.id;
        this.editingRoomId = rowId;

        const selectedRowFromState =
            (this.roomRows || []).find((row) => this.idsEqual(row.id, rowId)) ||
            (this.buildingDetailRoomRows || []).find((row) => this.idsEqual(row.id, rowId)) ||
            (this.linkedRoomRows || []).find((row) => this.idsEqual(row.id, rowId)) ||
            (this.selectedRoom && this.idsEqual(this.selectedRoom.id, rowId) ? this.selectedRoom : null);
        if (!selectedRowFromState) {
            return;
        }

        await this.loadRoomFormOptions(false);

        let selectedRow = selectedRowFromState;
        try {
            const serverRow = await getRoomById({ roomId: String(rowId) });
            if (serverRow?.id) {
                selectedRow = serverRow;
            }
        } catch {
            selectedRow = selectedRowFromState;
        }

        const buildingValue = this.firstNonBlankUi(selectedRow.buildingId, selectedRowFromState.buildingId, '') || '';
        const categoryValue = this.firstNonBlankUi(selectedRow.categoryId, selectedRowFromState.categoryId, '') || '';
        const floorId = this.firstNonBlankUi(selectedRow.floorId, selectedRowFromState.floorId, '');
        const floorLabel = this.firstNonBlankUi(selectedRow.floor, selectedRowFromState.floor, '');

        if (buildingValue && !(this.roomBuildingOptions || []).some((item) => this.idsEqual(item.value, buildingValue))) {
            this.roomBuildingOptions = [
                ...this.roomBuildingOptions,
                { label: this.firstNonBlankUi(selectedRow.building, 'Current Building'), value: buildingValue }
            ];
        }
        if (categoryValue && !(this.roomCategoryOptions || []).some((item) => this.idsEqual(item.value, categoryValue))) {
            this.roomCategoryOptions = [
                ...this.roomCategoryOptions,
                { label: this.firstNonBlankUi(selectedRow.category, 'Current Category'), value: categoryValue }
            ];
        }

        let floorValue = floorId;
        if (buildingValue && floorId && !(this.roomFloorOptions || []).some((item) => this.idsEqual(item.value, floorId))) {
            this.roomFloorOptions = [
                ...this.roomFloorOptions,
                {
                    label: `Floor ${this.toPositiveInt(floorLabel) || floorLabel || '--'}`,
                    value: floorId,
                    buildingValue
                }
            ];
        }
        if (!floorValue) {
            floorValue = this.resolveRoomFloorValueForForm(buildingValue, floorLabel);
        }

        const statusValue = this.resolveRoomStatusValueForForm(
            selectedRow.statusValue,
            selectedRow.status,
            selectedRowFromState.statusValue,
            selectedRowFromState.status
        );

        this.roomForm = {
            buildingValue,
            floorId: floorValue || '',
            roomNumber: this.firstNonBlankUi(selectedRow.roomNo, selectedRowFromState.roomNo, '') || '',
            roomCategoryId: categoryValue,
            capacity: this.firstNonBlankUi(selectedRow.capacity, selectedRowFromState.capacity, '') || '',
            statusValue: statusValue || 'active'
        };

        this.editingRoomId = selectedRow.id;
        this.editingRoomInitialFloorId = floorValue || '';
        this.isNewRoomModalOpen = true;
    }

    async handleDeleteRoomAction(event) {
        const rowId = event.currentTarget.dataset.id;
        const selectedRow = (this.roomRows || []).find((row) => String(row.id) === String(rowId));
        if (!selectedRow) {
            return;
        }

        const confirmed = window.confirm(`Delete room "${selectedRow.roomNo}"?`);
        if (!confirmed) {
            return;
        }

        try {
            await deleteRoomRecord({ roomId: String(rowId) });
            await this.loadRooms();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Room deleted successfully.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        }
    }

    async handleOpenLinkedBuildingFromRoom() {
        const linkedBuildingId = this.selectedRoomBuildingId;
        const linkedBuildingName = this.selectedRoomOverview?.building;
        if (!linkedBuildingId && !this.hasUsableText(linkedBuildingName)) {
            return;
        }

        let linkedBuilding = null;
        if (linkedBuildingId) {
            linkedBuilding = (this.buildingRows || []).find((row) => String(row.id) === String(linkedBuildingId));
        }
        if (!linkedBuilding && this.hasUsableText(linkedBuildingName)) {
            linkedBuilding = (this.buildingRows || []).find(
                (row) => this.normalizeLookupLabel(row.name) === this.normalizeLookupLabel(linkedBuildingName)
            );
        }
        if (!linkedBuilding) {
            try {
                linkedBuilding = await getBuildingDetail({
                    buildingId: linkedBuildingId,
                    buildingName: linkedBuildingName
                });
                if (linkedBuilding) {
                    linkedBuilding = {
                        ...linkedBuilding,
                        statusClass:
                            linkedBuilding.statusValue === 'active'
                                ? 'status-pill status-active'
                                : 'status-pill status-inactive'
                    };
                }
            } catch {
                linkedBuilding = null;
            }
        }
        if (!linkedBuilding) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Warning',
                    message: 'Linked building record was not found.',
                    variant: 'warning'
                })
            );
            return;
        }

        if (!(this.buildingRows || []).some((row) => String(row.id) === String(linkedBuilding.id))) {
            this.buildingRows = [linkedBuilding, ...(this.buildingRows || [])];
        }

        this.selectedStatus = 'all';
        this.activeMasterTab = 'buildings';
        this.selectedBuilding = linkedBuilding;
        this.selectedRoom = null;
        this.selectedRoomCategory = null;
        this.roomViewMode = 'list';
        this.roomCategoryViewMode = 'list';
        this.buildingViewMode = 'detail';
        this.expandedBuildingFloorKeys = [];
        await Promise.all([this.loadBuildingFloorRooms(), this.loadBuildingActivityHistory()]);
    }

    async handleOpenLinkedCategoryFromRoom() {
        const linkedCategoryId = this.selectedRoomCategoryId;
        const linkedCategoryName = this.selectedRoomOverview?.category;
        if (!linkedCategoryId && !this.hasUsableText(linkedCategoryName)) {
            return;
        }

        let linkedCategory = null;
        if (linkedCategoryId) {
            linkedCategory = (this.roomCategoryRows || []).find((row) => String(row.id) === String(linkedCategoryId));
        }
        if (!linkedCategory && this.hasUsableText(linkedCategoryName)) {
            linkedCategory = (this.roomCategoryRows || []).find(
                (row) => this.normalizeLookupLabel(row.categoryName) === this.normalizeLookupLabel(linkedCategoryName)
            );
        }
        if (!linkedCategory) {
            try {
                linkedCategory = await getRoomCategoryDetail({
                    categoryId: linkedCategoryId,
                    categoryName: linkedCategoryName
                });
                if (linkedCategory) {
                    linkedCategory = {
                        ...linkedCategory,
                        statusClass:
                            linkedCategory.statusValue === 'active'
                                ? 'status-pill status-active'
                                : 'status-pill status-inactive'
                    };
                }
            } catch {
                linkedCategory = null;
            }
        }
        if (!linkedCategory) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Warning',
                    message: 'Linked room category record was not found.',
                    variant: 'warning'
                })
            );
            return;
        }

        if (!(this.roomCategoryRows || []).some((row) => String(row.id) === String(linkedCategory.id))) {
            this.roomCategoryRows = [linkedCategory, ...(this.roomCategoryRows || [])];
        }

        this.selectedStatus = 'all';
        this.activeMasterTab = 'roomCategories';
        this.selectedRoomCategory = linkedCategory;
        this.selectedRoom = null;
        this.selectedBuilding = null;
        this.roomViewMode = 'list';
        this.buildingViewMode = 'list';
        this.roomCategoryViewMode = 'detail';
        await Promise.all([this.loadRoomCategories(), this.loadRoomCategoryActivityHistory()]);
    }

    handleToggleFloorSection(event) {
        const floorKey = event.currentTarget.dataset.floorKey;
        if (!floorKey) {
            return;
        }

        const currentKeys = [...(this.expandedBuildingFloorKeys || [])];
        const existingIndex = currentKeys.indexOf(floorKey);
        if (existingIndex >= 0) {
            currentKeys.splice(existingIndex, 1);
        } else {
            currentKeys.push(floorKey);
        }
        this.expandedBuildingFloorKeys = currentKeys;
    }

    async handleAddRoomForFloor(event) {
        const floorNo = this.toPositiveInt(event.currentTarget.dataset.floorNo);
        const buildingId = this.selectedBuilding?.id;
        if (!buildingId || floorNo <= 0) {
            return;
        }

        await this.loadRoomFormOptions();
        const floorOption = (this.roomFloorOptions || []).find(
            (item) => String(item.buildingValue) === String(buildingId) && this.toPositiveInt(item.label) === floorNo
        );

        this.roomForm = {
            ...this.roomForm,
            buildingValue: String(buildingId),
            floorId: floorOption?.value || '',
            statusValue: this.roomForm.statusValue || 'active'
        };
        this.editingRoomId = null;
        this.editingRoomInitialFloorId = '';
        this.isNewRoomModalOpen = true;
    }

    async handleViewRoomFromFloorSection(event) {
        const rowId = event.currentTarget.dataset.id;
        const selectedRow = (this.buildingDetailRoomRows || []).find((row) => String(row.id) === String(rowId));
        if (!selectedRow) {
            return;
        }

        this.selectedRoom = selectedRow;
        this.selectedRoomCategory = null;
        this.roomViewMode = 'detail';
        this.activeMasterTab = 'rooms';
        await this.loadRoomOccupancyDetails();
    }

    async handleEditRoomFromFloorSection(event) {
        await this.handleEditRoomAction(event);
    }

    async handleDeleteRoomFromFloorSection(event) {
        await this.handleDeleteRoomAction(event);
        await Promise.all([this.loadBuildingFloorRooms(), this.loadBuildingActivityHistory()]);
    }

    handleRoomCategoryFieldChange(event) {
        const fieldName = event.target.dataset.field;
        if (!fieldName) {
            return;
        }

        this.roomCategoryForm = {
            ...this.roomCategoryForm,
            [fieldName]: event.target.value
        };
    }

    handleBuildingFieldChange(event) {
        const fieldName = event.target.dataset.field;
        if (!fieldName) {
            return;
        }

        let nextValue = event.target.value;
        if (fieldName === 'genderValue') {
            this.buildingForm = {
                ...this.buildingForm,
                genderValue: nextValue,
                hostelTypeValue: nextValue
            };
            return;
        }

        if (fieldName === 'hostelTypeValue') {
            this.buildingForm = {
                ...this.buildingForm,
                hostelTypeValue: nextValue,
                genderValue: nextValue
            };
            return;
        }

        if (fieldName === 'numberOfFloors') {
            const raw = String(nextValue || '').trim();
            const match = raw.match(/^\d+/);
            nextValue = (match ? match[0] : '').replace(/^0+/, '');
        }

        this.buildingForm = {
            ...this.buildingForm,
            [fieldName]: nextValue
        };
    }

    handleBuildingWardenModeChange(event) {
        this.buildingForm = {
            ...this.buildingForm,
            wardenMode: event.target.value
        };
    }

    handleRoomFieldChange(event) {
        const fieldName = event.target.dataset.field;
        if (!fieldName) {
            return;
        }

        const nextValue = event.target.value;
        if (fieldName === 'buildingValue') {
            this.roomForm = {
                ...this.roomForm,
                buildingValue: nextValue,
                floorId: ''
            };
            return;
        }

        if (fieldName === 'roomCategoryId') {
            const categoryCapacity = this.roomCategoryCapacityById?.[nextValue];
            this.roomForm = {
                ...this.roomForm,
                roomCategoryId: nextValue,
                capacity: categoryCapacity || this.roomForm.capacity
            };
            return;
        }

        this.roomForm = {
            ...this.roomForm,
            [fieldName]: nextValue
        };
    }

    handleAmenityToggle(event) {
        const amenityValue = event.target.dataset.value;
        if (!amenityValue) {
            return;
        }

        const selected = new Set(this.roomCategoryForm.amenities || []);
        if (event.target.checked) {
            selected.add(amenityValue);
        } else {
            selected.delete(amenityValue);
        }

        this.roomCategoryForm = {
            ...this.roomCategoryForm,
            amenities: Array.from(selected)
        };
    }

    handleCustomAmenityInputChange(event) {
        this.customAmenityInput = event.target.value;
    }

    async handleAddCustomAmenity() {
        const amenityName = (this.customAmenityInput || '').trim();
        if (!amenityName) {
            return;
        }

        try {
            const addedOption = await addCustomAmenity({ amenityName });
            const exists = (this.roomCategoryAmenitiesOptions || []).some((item) => item.value === addedOption.value);
            if (!exists) {
                this.roomCategoryAmenitiesOptions = [...this.roomCategoryAmenitiesOptions, addedOption];
            }

            const selected = new Set(this.roomCategoryForm.amenities || []);
            selected.add(addedOption.value);
            this.roomCategoryForm = {
                ...this.roomCategoryForm,
                amenities: Array.from(selected)
            };
            this.customAmenityInput = '';
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        }
    }

    async handleCreateRoomCategory() {
        if (this.isSavingRoomCategory) {
            return;
        }

        if (!this.validateRoomCategoryForm()) {
            return;
        }

        this.isSavingRoomCategory = true;
        try {
            if (this.isEditingRoomCategory) {
                await updateRoomCategory({
                    roomCategoryId: this.editingRoomCategoryId,
                    inputRequest: this.roomCategoryForm
                });
            } else {
                await createRoomCategory({ inputRequest: this.roomCategoryForm });
            }
            this.selectedStatus = 'all';
            await this.loadRoomCategories();
            await this.loadRoomFormOptions();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: this.isEditingRoomCategory
                        ? 'Room category updated successfully.'
                        : 'Room category created successfully.',
                    variant: 'success'
                })
            );
            this.handleCloseNewRoomCategoryModal();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isSavingRoomCategory = false;
        }
    }

    async handleCreateBuilding() {
        if (this.isSavingBuilding) {
            return;
        }

        if (!this.validateBuildingForm()) {
            return;
        }

        this.isSavingBuilding = true;
        try {
            if (this.isEditingBuilding) {
                await updateBuilding({
                    buildingId: this.editingBuildingId,
                    inputRequest: this.buildingForm
                });
            } else {
                await createBuilding({ inputRequest: this.buildingForm });
            }
            this.selectedStatus = 'all';
            await this.loadBuildings();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: this.isEditingBuilding
                        ? 'Building updated successfully.'
                        : 'Building created successfully.',
                    variant: 'success'
                })
            );
            this.handleCloseNewBuildingModal();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isSavingBuilding = false;
        }
    }

    async handleSaveFloorWarden() {
        if (this.isSavingFloorWarden) {
            return;
        }

        if (!this.validateFloorWardenForm()) {
            return;
        }

        const buildingId = this.selectedBuilding?.id;
        if (!buildingId) {
            return;
        }

        this.isSavingFloorWarden = true;
        let saveSucceeded = false;
        try {
            await createFloorWarden({
                inputRequest: {
                    buildingId: String(buildingId),
                    floorNumber: String(this.floorWardenForm.floorNo || ''),
                    wardenId: this.floorWardenForm.wardenId,
                    assignmentType: this.floorWardenForm.assignmentType,
                    description: this.floorWardenForm.description
                }
            });

            await Promise.all([
                this.loadBuildings(),
                this.loadBuildingFloorRooms(),
                this.loadBuildingActivityHistory(),
                this.loadBuildingFormOptions()
            ]);

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Warden assigned successfully.',
                    variant: 'success'
                })
            );
            saveSucceeded = true;
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isSavingFloorWarden = false;
            if (saveSucceeded) {
                this.handleCloseFloorWardenModal();
            }
        }
    }

    async handleCreateRoom() {
        if (this.isSavingRoom) {
            return;
        }

        if (!this.validateRoomForm()) {
            return;
        }

        this.isSavingRoom = true;
        try {
            const roomPayload = {
                ...this.roomForm
            };
            if (this.isEditingRoom) {
                await updateRoom({
                    roomId: this.editingRoomId,
                    inputRequest: roomPayload
                });
            } else {
                await createRoom({ inputRequest: roomPayload });
            }
            await this.loadRooms();
            if (this.roomViewMode === 'detail' && this.selectedRoom?.id) {
                const allRows = await getRooms({
                    statusFilter: 'all'
                });
                const refreshed = (allRows || [])
                    .map((row) => ({
                        ...row,
                        statusClass: this.resolveRoomStatusPillClass(row.statusValue)
                    }))
                    .find((row) => String(row.id) === String(this.selectedRoom.id));
                if (refreshed) {
                    this.selectedRoom = refreshed;
                }
                await this.loadRoomOccupancyDetails();
            }
            if (this.isBuildingDetailView && this.selectedBuilding?.id) {
                await this.loadBuildingFloorRooms();
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: this.isEditingRoom
                        ? 'Room updated successfully.'
                        : 'Room created successfully.',
                    variant: 'success'
                })
            );
            this.handleCloseNewRoomModal();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isSavingRoom = false;
        }
    }

    async loadBuildings() {
        this.isLoadingBuildings = true;
        try {
            const rows = await getBuildings({
                statusFilter: this.selectedStatus
            });
            const mappedRows = (rows || []).map((row) => ({
                ...row,
                statusClass:
                    row.statusValue === 'active'
                        ? 'status-pill status-active'
                        : 'status-pill status-inactive'
            }));
            this.buildingRows = mappedRows;

            if (this.selectedBuilding?.id) {
                const refreshed = mappedRows.find((row) => String(row.id) === String(this.selectedBuilding.id));
                this.selectedBuilding = refreshed || this.selectedBuilding;
            }
        } catch (error) {
            this.buildingRows = [];
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isLoadingBuildings = false;
        }
    }

    async loadRooms() {
        this.isLoadingRooms = true;
        try {
            const rows = await getRooms({
                statusFilter: this.selectedStatus
            });
            const mappedRows = (rows || []).map((row) => ({
                ...row,
                statusClass: this.resolveRoomStatusPillClass(row.statusValue)
            }));
            this.roomRows = mappedRows;

            if (this.selectedRoom?.id) {
                const refreshed = mappedRows.find((row) => String(row.id) === String(this.selectedRoom.id));
                this.selectedRoom = refreshed || this.selectedRoom;
            }
        } catch (error) {
            this.roomRows = [];
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isLoadingRooms = false;
        }
    }

    async loadBuildingFloorRooms() {
        const selectedBuildingId = this.selectedBuilding?.id;
        if (!selectedBuildingId) {
            this.buildingDetailRoomRows = [];
            this.buildingFloorWardenByNo = {};
            return;
        }

        this.isLoadingBuildingFloors = true;
        try {
            const [rows, floorDetails] = await Promise.all([
                getRooms({
                    statusFilter: 'all'
                }),
                getBuildingFloorWardenDetails({
                    buildingId: String(selectedBuildingId)
                })
            ]);

            const floorMap = {};
            (floorDetails || []).forEach((floor) => {
                const floorKey = String(this.toPositiveInt(floor.floorNumber));
                if (!floorKey || floorKey === '0') {
                    return;
                }
                floorMap[floorKey] = {
                    wardenId: floor.wardenId || '',
                    wardenName: floor.wardenName || '',
                    wardenPhone: floor.wardenPhone || '',
                    assignmentTypeLabel: floor.assignmentTypeLabel || '',
                    isInheritedFromBuilding: floor.isInheritedFromBuilding !== false
                };
            });
            this.buildingFloorWardenByNo = floorMap;

            const mappedRows = (rows || []).map((row) => ({
                ...row,
                statusClass: this.resolveRoomStatusPillClass(row.statusValue)
            }));
            this.buildingDetailRoomRows = mappedRows.filter(
                (row) => String(row.buildingId || '') === String(selectedBuildingId)
            );
        } catch (error) {
            this.buildingDetailRoomRows = [];
            this.buildingFloorWardenByNo = {};
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isLoadingBuildingFloors = false;
        }
    }

    async loadBuildingActivityHistory() {
        const selectedBuildingId = this.selectedBuilding?.id;
        if (!selectedBuildingId) {
            this.buildingActivityHistory = null;
            return;
        }

        try {
            this.buildingActivityHistory = await getBuildingActivityHistory({
                buildingId: String(selectedBuildingId)
            });
        } catch {
            this.buildingActivityHistory = null;
        }
    }

    async loadRoomOccupancyDetails() {
        const selectedRoomId = this.selectedRoom?.id;
        if (!selectedRoomId) {
            this.roomOccupancyDetails = null;
            this.roomCurrentOccupants = [];
            this.roomPastOccupants = [];
            return;
        }

        this.isLoadingRoomOccupants = true;
        try {
            const response = await getRoomOccupancyDetails({
                roomId: String(selectedRoomId)
            });
            this.roomOccupancyDetails = response || null;
            this.roomCurrentOccupants = response?.currentOccupants || [];
            this.roomPastOccupants = response?.pastOccupants || [];
        } catch (error) {
            this.roomOccupancyDetails = null;
            this.roomCurrentOccupants = [];
            this.roomPastOccupants = [];
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isLoadingRoomOccupants = false;
        }
    }

    async loadBuildingFormOptions() {
        try {
            const response = await getBuildingFormOptions();
            this.buildingGenderOptions = response?.genderOptions || [];
            this.buildingHostelTypeOptions = response?.hostelTypeOptions || [];
            this.buildingStatusOptions = response?.statusOptions || [];
            this.buildingWardenOptions = response?.wardenOptions || [];
            this.resetBuildingForm();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        }
    }

    async loadRoomFormOptions(resetForm = true) {
        try {
            const response = await getRoomFormOptions();
            this.roomBuildingOptions = response?.buildingOptions || [];
            this.roomFloorOptions = response?.floorOptions || [];
            this.roomCategoryOptions = response?.categoryOptions || [];
            this.roomStatusOptions = response?.statusOptions || [];
            this.roomCategoryCapacityById = response?.categoryCapacityById || {};
            if (resetForm && !this.editingRoomId) {
                this.resetRoomForm();
            }
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        }
    }

    async loadRoomCategories() {
        this.isLoadingRoomCategories = true;
        try {
            const rows = await getRoomCategories({
                statusFilter: this.selectedStatus
            });
            this.roomCategoryRows = (rows || []).map((row) => ({
                ...row,
                statusClass:
                    row.statusValue === 'active'
                        ? 'status-pill status-active'
                        : 'status-pill status-inactive'
            }));

            if (this.selectedRoomCategory?.id) {
                const refreshed = this.roomCategoryRows.find(
                    (row) => String(row.id) === String(this.selectedRoomCategory.id)
                );
                this.selectedRoomCategory = refreshed || this.selectedRoomCategory;
                if (this.roomCategoryViewMode === 'detail' && this.selectedRoomCategory?.id) {
                    await this.loadLinkedRoomsForSelectedCategory();
                }
            }
        } catch (error) {
            this.roomCategoryRows = [];
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isLoadingRoomCategories = false;
        }
    }

    async loadLinkedRoomsForSelectedCategory() {
        const categoryId = this.selectedRoomCategory?.id;
        if (!categoryId) {
            this.linkedRoomRows = [];
            return;
        }

        this.isLoadingLinkedRooms = true;
        try {
            const rows = await getLinkedRoomsByCategory({
                categoryId: String(categoryId)
            });
            this.linkedRoomRows = (rows || []).map((row) => ({
                ...row,
                statusClass: this.resolveRoomStatusPillClass(row.statusValue, true)
            }));
        } catch (error) {
            this.linkedRoomRows = [];
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isLoadingLinkedRooms = false;
        }
    }

    async loadRoomCategoryActivityHistory() {
        const categoryId = this.selectedRoomCategory?.id;
        if (!categoryId) {
            this.roomCategoryActivityHistory = null;
            return;
        }
        try {
            this.roomCategoryActivityHistory = await getRoomCategoryActivityHistory({
                categoryId: String(categoryId)
            });
        } catch {
            this.roomCategoryActivityHistory = null;
        }
    }

    async loadRoomCategoryFormOptions() {
        try {
            const response = await getRoomCategoryFormOptions();
            this.roomCategoryGenderOptions = response?.genderOptions || [];
            this.roomCategoryFeeTypeOptions = response?.feeTypeOptions || [];
            this.roomCategoryAmenitiesOptions = response?.amenitiesOptions || [];
            this.roomCategoryStatusOptions = response?.statusOptions || [];
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        }
    }

    validateRoomCategoryForm() {
        const { categoryName, statusValue } = this.roomCategoryForm;
        if (this.isEditingRoomCategory) {
            return true;
        }

        if (!categoryName || !statusValue) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'Please fill all required Room Category fields.',
                    variant: 'warning'
                })
            );
            return false;
        }
        return true;
    }

    validateBuildingForm() {
        const { buildingName, genderValue, statusValue, numberOfFloors, buildingWarden } = this.buildingForm;
        if (this.isEditingBuilding) {
            if (this.hasUsableText(numberOfFloors) && !/^[1-9]\d*$/.test(String(numberOfFloors).trim())) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Validation Error',
                        message: 'Number of Floors must be a positive whole number.',
                        variant: 'warning'
                    })
                );
                return false;
            }
            return true;
        }

        if (!buildingName || !genderValue || !statusValue || !numberOfFloors || !buildingWarden) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'Please fill all required Building fields.',
                    variant: 'warning'
                })
            );
            return false;
        }

        if (!/^[1-9]\d*$/.test(numberOfFloors)) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'Number of Floors must be a positive whole number.',
                    variant: 'warning'
                })
            );
            return false;
        }

        return true;
    }

    validateFloorWardenForm() {
        const { floorNo, wardenId, assignmentType } = this.floorWardenForm;
        if (!floorNo || !wardenId || !assignmentType) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'Please fill all required warden fields.',
                    variant: 'warning'
                })
            );
            return false;
        }
        return true;
    }

    validateRoomForm() {
        const { buildingValue, floorId, roomNumber, roomCategoryId, capacity, statusValue } = this.roomForm;
        if (this.isEditingRoom) {
            if (this.hasUsableText(capacity) && !/^\d+$/.test(String(capacity).trim())) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Validation Error',
                        message: 'Capacity must be a whole number (0 or more).',
                        variant: 'warning'
                    })
                );
                return false;
            }
            return true;
        }

        if (!buildingValue || !floorId || !roomNumber || !roomCategoryId || !capacity || !statusValue) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'Please fill all required Room fields.',
                    variant: 'warning'
                })
            );
            return false;
        }

        if (!/^[1-9]\d*$/.test(String(capacity).trim())) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'Capacity must be a positive whole number.',
                    variant: 'warning'
                })
            );
            return false;
        }

        return true;
    }

    resetRoomCategoryForm() {
        this.roomCategoryForm = {
            categoryName: '',
            description: '',
            genderAllowed: '',
            defaultFeeTypeId: '',
            statusValue: 'active',
            amenities: []
        };
        this.customAmenityInput = '';
    }

    resetBuildingForm() {
        const firstStatusOption = (this.buildingStatusOptions || [])[0];
        const defaultStatus =
            (this.buildingStatusOptions || []).find((item) => item.value === 'Active')?.value ||
            firstStatusOption?.value ||
            'Active';

        this.buildingForm = {
            buildingName: '',
            genderValue: '',
            hostelTypeValue: '',
            statusValue: defaultStatus,
            numberOfFloors: '',
            wardenMode: 'Building Level',
            buildingWarden: ''
        };
    }

    resetFloorWardenForm() {
        this.floorWardenForm = {
            floorNo: '',
            wardenId: '',
            assignmentType: 'Floor Warden',
            phone: '',
            description: ''
        };
    }

    resetRoomForm() {
        const defaultStatus = (this.roomStatusOptions || []).find(
            (item) => this.normalizeRoomStatusForForm(item.value) === 'active'
        )?.value ||
            (this.roomStatusOptions || [])[0]?.value ||
            'active';

        this.roomForm = {
            buildingValue: '',
            floorId: '',
            roomNumber: '',
            roomCategoryId: '',
            capacity: '',
            statusValue: defaultStatus
        };
    }

    resolveWardenMeta(wardenId) {
        const id = this.firstNonBlankUi(wardenId);
        if (!id) {
            return { phone: '', description: '' };
        }

        const option = (this.buildingWardenOptions || []).find((item) => String(item.value) === String(id));
        return {
            phone: this.firstNonBlankUi(option?.phone, '') || '',
            description: this.firstNonBlankUi(option?.description, '') || ''
        };
    }

    firstNonBlankUi(...values) {
        for (const value of values) {
            if (value !== null && value !== undefined && String(value).trim() !== '') {
                return String(value).trim();
            }
        }
        return null;
    }

    hasUsableText(value) {
        const text = this.firstNonBlankUi(value);
        return !!text && text !== '--';
    }

    normalizeLookupLabel(value) {
        const text = this.firstNonBlankUi(value);
        if (!text) {
            return '';
        }
        return text.toLowerCase().replace(/\s+/g, ' ').trim();
    }

    toPositiveInt(value) {
        const raw = this.firstNonBlankUi(value);
        if (!raw) {
            return 0;
        }
        const numericText = raw.replace(/[^\d]/g, '');
        const parsed = parseInt(numericText, 10);
        return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
    }

    toFloorNumber(value) {
        return this.toPositiveInt(value);
    }

    formatDateValue(value, includeTime) {
        const raw = this.firstNonBlankUi(value);
        if (!raw) {
            return '--';
        }
        const date = new Date(raw);
        if (Number.isNaN(date.getTime())) {
            return '--';
        }
        if (includeTime) {
            return new Intl.DateTimeFormat('en-IN', {
                year: 'numeric',
                month: '2-digit',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit'
            }).format(date);
        }
        return new Intl.DateTimeFormat('en-CA', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        }).format(date);
    }

    buildingIdentifierFromId(recordId) {
        const raw = this.firstNonBlankUi(recordId);
        if (!raw) {
            return 'B000';
        }
        const compact = raw.replace(/[^a-zA-Z0-9]/g, '');
        const suffix = compact.slice(-3).toUpperCase();
        return `B${suffix.padStart(3, '0')}`;
    }

    resolveBuildingOccupancyPercent(row, fallback, capacityValue) {
        const percentFromField = this.percentFromText(row.occupancyPercent);
        if (percentFromField !== null) {
            return Math.max(1, percentFromField);
        }

        const currentAndCapacity = this.extractCurrentAndCapacity(row.currentOccupancy);
        if (currentAndCapacity !== null) {
            return currentAndCapacity.percent;
        }

        const fallbackPercent = this.percentFromText(fallback.occupancyPercent);
        if (fallbackPercent !== null) {
            return Math.max(1, fallbackPercent);
        }

        const fallbackCurrentAndCapacity = this.extractCurrentAndCapacity(fallback.currentOccupancy);
        if (fallbackCurrentAndCapacity !== null) {
            return fallbackCurrentAndCapacity.percent;
        }

        if (capacityValue > 0) {
            return 1;
        }
        return 1;
    }

    resolveCurrentOccupancyText(row, fallback, capacityValue, occupancyPercent) {
        const currentAndCapacity = this.extractCurrentAndCapacity(row.currentOccupancy);
        if (currentAndCapacity !== null) {
            return `${currentAndCapacity.current} / ${currentAndCapacity.capacity}`;
        }

        const fallbackCurrentAndCapacity = this.extractCurrentAndCapacity(fallback.currentOccupancy);
        if (fallbackCurrentAndCapacity !== null) {
            return `${fallbackCurrentAndCapacity.current} / ${fallbackCurrentAndCapacity.capacity}`;
        }

        const currentOnly = this.toPositiveInt(row.currentOccupancy);
        if (capacityValue > 0 && currentOnly > 0) {
            return `${currentOnly} / ${capacityValue}`;
        }

        if (capacityValue > 0) {
            const inferredCurrent = Math.round((occupancyPercent / 100) * capacityValue);
            return `${inferredCurrent} / ${capacityValue}`;
        }

        return '0 / 0';
    }

    percentFromText(value) {
        const raw = this.firstNonBlankUi(value);
        if (!raw) {
            return null;
        }
        const numericText = raw.replace(/[^\d.]/g, '');
        if (!numericText) {
            return null;
        }
        const parsed = Math.round(parseFloat(numericText));
        if (!Number.isFinite(parsed)) {
            return null;
        }
        return Math.max(0, Math.min(100, parsed));
    }

    extractCurrentAndCapacity(value) {
        const raw = this.firstNonBlankUi(value);
        if (!raw) {
            return null;
        }
        const match = raw.match(/(\d+)\s*\/\s*(\d+)/);
        if (!match) {
            return null;
        }
        const current = parseInt(match[1], 10);
        const capacity = parseInt(match[2], 10);
        if (!Number.isFinite(current) || !Number.isFinite(capacity) || capacity <= 0) {
            return null;
        }
        const percent = Math.max(0, Math.min(100, Math.round((current / capacity) * 100)));
        return { current, capacity, percent };
    }

    normalizeHostelTypeForForm(value) {
        const normalized = this.normalizeLookupLabel(value);
        if (normalized === 'male' || normalized === 'boys' || normalized === 'boy') {
            return 'Male';
        }
        if (normalized === 'female' || normalized === 'girls' || normalized === 'girl') {
            return 'Female';
        }
        if (normalized === 'co-ed' || normalized === 'coed' || normalized === 'co ed') {
            return 'Co-Ed';
        }
        return this.firstNonBlankUi(value);
    }

    normalizeWardenModeForForm(value) {
        const normalized = this.normalizeLookupLabel(value);
        if (
            normalized === 'building level' ||
            normalized === 'building-level' ||
            normalized === 'single warden for entire building'
        ) {
            return 'Building Level';
        }
        if (
            normalized === 'manual' ||
            normalized === 'per-floor' ||
            normalized === 'per floor' ||
            normalized === 'warden per floor'
        ) {
            return 'Manual';
        }
        return this.firstNonBlankUi(value);
    }

    normalizeRoomStatusForForm(value) {
        const normalized = this.normalizeLookupLabel(value).replace(/[\s-]/g, '');
        if (
            normalized.includes('inactive') ||
            normalized.includes('blocked') ||
            normalized.includes('maintenance') ||
            normalized.includes('deactivate')
        ) {
            return 'inactive';
        }
        if (
            normalized.includes('active') ||
            normalized.includes('available') ||
            normalized.includes('vacant') ||
            normalized.includes('occupied') ||
            normalized.includes('partial')
        ) {
            return 'active';
        }
        return null;
    }

    findOptionValueByLabel(options, label) {
        const normalizedLabel = this.normalizeLookupLabel(label);
        if (!normalizedLabel) {
            return null;
        }
        const option = (options || []).find((item) => {
            const optionLabel = this.normalizeLookupLabel(item.label);
            return optionLabel === normalizedLabel ||
                optionLabel.includes(normalizedLabel) ||
                normalizedLabel.includes(optionLabel);
        });
        return option?.value || null;
    }

    findOptionValueById(options, rawId) {
        const safeId = this.firstNonBlankUi(rawId);
        if (!safeId) {
            return null;
        }
        const option = (options || []).find((item) => this.idsEqual(item.value, safeId));
        return option?.value || null;
    }

    resolveOptionValue(options, ...candidates) {
        for (const candidate of candidates) {
            const byValue = this.findOptionValueById(options, candidate);
            if (byValue) {
                return byValue;
            }

            const byLabel = this.findOptionValueByLabel(options, candidate);
            if (byLabel) {
                return byLabel;
            }
        }

        return null;
    }

    resolveRoomStatusValueForForm(...candidates) {
        const options = this.roomStatusOptions || [];
        if (!options.length) {
            return this.firstNonBlankUi(...candidates, 'active') || 'active';
        }

        for (const candidate of candidates) {
            const normalized = this.normalizeRoomStatusForForm(candidate);
            if (!normalized) {
                continue;
            }

            const byExact = options.find((item) => this.normalizeLookupLabel(item.value) === this.normalizeLookupLabel(normalized));
            if (byExact?.value) {
                return byExact.value;
            }

            const bySemantic = options.find(
                (item) => this.normalizeRoomStatusForForm(item.value) === normalized || this.normalizeRoomStatusForForm(item.label) === normalized
            );
            if (bySemantic?.value) {
                return bySemantic.value;
            }
        }

        return options[0]?.value || 'active';
    }

    resolveRoomCategoryStatusValueForForm(...candidates) {
        const options = this.roomCategoryStatusOptions || [];
        if (!options.length) {
            const first = this.firstNonBlankUi(...candidates);
            return first ? first.toLowerCase() : 'active';
        }

        for (const candidate of candidates) {
            const normalized = this.normalizeLookupLabel(candidate);
            if (!normalized) {
                continue;
            }
            const byExact = options.find((item) => this.normalizeLookupLabel(item.value) === normalized);
            if (byExact?.value) {
                return byExact.value;
            }
            const byLabel = options.find((item) => this.normalizeLookupLabel(item.label) === normalized);
            if (byLabel?.value) {
                return byLabel.value;
            }
        }

        return options[0]?.value || 'active';
    }

    resolveBuildingStatusValueForForm(...candidates) {
        const options = this.buildingStatusOptions || [];
        if (!options.length) {
            return this.firstNonBlankUi(...candidates, 'Active') || 'Active';
        }

        for (const candidate of candidates) {
            const normalized = this.normalizeLookupLabel(candidate);
            if (!normalized) {
                continue;
            }
            const byExact = options.find((item) => this.normalizeLookupLabel(item.value) === normalized);
            if (byExact?.value) {
                return byExact.value;
            }
            const byLabel = options.find((item) => this.normalizeLookupLabel(item.label) === normalized);
            if (byLabel?.value) {
                return byLabel.value;
            }
        }

        return options[0]?.value || 'Active';
    }

    idsEqual(leftId, rightId) {
        const left = this.firstNonBlankUi(leftId);
        const right = this.firstNonBlankUi(rightId);
        if (!left || !right) {
            return false;
        }
        const left15 = left.substring(0, 15).toLowerCase();
        const right15 = right.substring(0, 15).toLowerCase();
        return left15 === right15;
    }

    buildSyntheticFloorValue(buildingId, floorNumber) {
        const safeBuildingId = this.firstNonBlankUi(buildingId);
        const safeFloor = parseInt(String(floorNumber), 10);
        if (!safeBuildingId || !Number.isFinite(safeFloor) || safeFloor <= 0) {
            return '';
        }
        return `SYNTH::${safeBuildingId}::${safeFloor}`;
    }

    resolveRoomFloorValueForForm(buildingValue, floorLabel) {
        if (!buildingValue) {
            return '';
        }

        const exactIdMatch = (this.roomFloorOptions || []).find(
            (item) => item.buildingValue === buildingValue && item.value === floorLabel
        );
        if (exactIdMatch) {
            return exactIdMatch.value;
        }

        const floorNumber = this.toPositiveInt(floorLabel);
        if (floorNumber > 0) {
            const syntheticValue = this.buildSyntheticFloorValue(buildingValue, floorNumber);
            const exists = (this.roomFloorOptions || []).some((item) => item.value === syntheticValue);
            if (exists) {
                return syntheticValue;
            }

            const byNumberOption = (this.roomFloorOptions || []).find(
                (item) => item.buildingValue === buildingValue && this.toPositiveInt(item.label) === floorNumber
            );
            if (byNumberOption) {
                return byNumberOption.value;
            }
        }

        const normalizedFloor = this.normalizeLookupLabel(floorLabel);
        if (!normalizedFloor) {
            return '';
        }

        const floorOption = (this.roomFloorOptions || []).find(
            (item) =>
                item.buildingValue === buildingValue && this.normalizeLookupLabel(item.label) === normalizedFloor
        );
        return floorOption?.value || '';
    }

    async handleRoomsCsvRefresh() {
        await this.loadRooms();
    }

    extractErrorMessage(error) {
        const body = error?.body;
        if (Array.isArray(body)) {
            const firstArrayMessage = body.find((item) => item?.message)?.message;
            if (firstArrayMessage) {
                return firstArrayMessage;
            }
        }

        const pageErrorMessage = body?.pageErrors?.find((item) => item?.message)?.message;
        if (pageErrorMessage) {
            return pageErrorMessage;
        }

        const fieldErrorGroups = body?.fieldErrors ? Object.values(body.fieldErrors) : [];
        for (const group of fieldErrorGroups) {
            if (Array.isArray(group)) {
                const fieldMessage = group.find((item) => item?.message)?.message;
                if (fieldMessage) {
                    return fieldMessage;
                }
            }
        }

        return (
            body?.message ||
            error?.message ||
            'Something went wrong. Please try again.'
        );
    }
}