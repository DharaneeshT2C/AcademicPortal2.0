import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class KenBuilding extends NavigationMixin(LightningElement) {
    @api hideListHead = false;
    @api rows = [];
    @api isLoading = false;
    @api selectedStatus = 'all';
    searchTerm = '';
    @api statusOptions = [];
    @api primaryActionLabel = 'New Building';
    @api isDetailView = false;

    @api selectedBuildingName = '--';
    @api selectedBuildingStatus = '--';
    @api selectedBuildingStatusClass = 'status-pill status-inactive';
    @api selectedBuildingOverview;
    @api isLoadingBuildingFloors = false;
    @api buildingFloorSections = [];
    @api buildingActivityCreatedByText = '--';
    @api buildingActivityCreatedByName = '--';
    @api buildingActivityCreatedDateText = '--';
    @api buildingActivityLastModifiedText = '--';
    @api buildingActivityEvents = [];
    @api isFloorWardenModalOpen = false;
    @api isSavingFloorWarden = false;
    @api floorWardenModalTitle = 'Add Warden';
    @api floorWardenForm;
    @api floorWardenAssignmentTypeOptions = [];
    @api saveFloorWardenButtonLabel = 'Save Warden';

    @api isModalOpen = false;
    @api isSavingBuilding = false;
    @api buildingModalTitle = 'New Building';
    @api buildingForm;
    @api buildingGenderOptions = [];
    @api buildingHostelTypeOptions = [];
    @api buildingStatusOptions = [];
    @api buildingWardenOptions = [];
    @api createBuildingButtonLabel = 'Create';

    emit(name, detail) {
        this.dispatchEvent(new CustomEvent(name, { detail }));
    }

    get filteredRows() {
        const normalizedSearch = this.normalizeText(this.searchTerm);
        if (!normalizedSearch) {
            return this.rows;
        }

        return (this.rows || []).filter((row) => {
            const haystacks = [
                row.name,
                row.buildingIdentifier,
                row.floors,
                row.wardenMode,
                row.wardenName,
                row.status
            ];
            return haystacks.some((value) => this.normalizeText(value).includes(normalizedSearch));
        });
    }

    handleStatusChange(event) {
        this.emit('statuschange', { value: event.target.value });
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value || '';
    }

    handleOpenModal() {
        this.emit('openmodal');
    }

    handleRowAction(event) {
        this.emit('rowaction', event.detail);
    }

    handleBackToList() {
        this.emit('backtolist');
    }

    handleEditSelected() {
        this.emit('editselected');
    }

    handleDeactivateSelected() {
        this.emit('deactivateselected');
    }

    handleToggleFloorSection(event) {
        this.emit('togglefloor', { floorKey: event.currentTarget.dataset.floorKey });
    }

    handleAddRoomForFloor(event) {
        this.emit('addroomforfloor', { floorNo: event.currentTarget.dataset.floorNo });
    }

    handleOpenFloorWardenModal(event) {
        this.emit('openfloorwardenmodal', { floorNo: event.currentTarget.dataset.floorNo });
    }

    handleViewRoomFromFloor(event) {
        this.emit('viewroomfromfloor', { id: event.currentTarget.dataset.id });
    }

    handleEditRoomFromFloor(event) {
        this.emit('editroomfromfloor', { id: event.currentTarget.dataset.id });
    }

    handleDeleteRoomFromFloor(event) {
        this.emit('deleteroomfromfloor', { id: event.currentTarget.dataset.id });
    }

    handleBreadcrumbDashboardClick() {
        this.emit('breadcrumbdashboard');
    }

    handleBreadcrumbMasterDataClick() {
        this.emit('breadcrumbmasterdata');
    }

    handleBreadcrumbMasterTabClick() {
        this.emit('breadcrumbmastertab', { key: 'buildings' });
    }

    handleCloseModal() {
        this.emit('closemodal');
    }

    handleCloseFloorWarden() {
        this.emit('closefloorwarden');
    }

    handleOpenWardenAccount(event) {
        event.stopPropagation();
        const recordId = event.currentTarget?.dataset?.id;
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName: 'Account',
                actionName: 'view'
            }
        });
    }

    handleBuildingFieldChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }

        let value = event.target.value;
        if (field === 'numberOfFloors') {
            const raw = String(value || '').trim();
            const match = raw.match(/^\d+/);
            value = (match ? match[0] : '').replace(/^0+/, '');
        }

        this.emit('buildingfieldchange', { field, value });
    }

    handleSaveBuilding() {
        this.emit('savebuilding');
    }

    handleFloorWardenFieldChange(event) {
        this.emit('floorwardenfieldchange', { field: event.target.dataset.field, value: event.target.value });
    }

    handleSaveFloorWarden() {
        this.emit('savefloorwarden');
    }

    normalizeText(value) {
        return (value || '')
            .toString()
            .toLowerCase()
            .replace(/\s+/g, ' ')
            .trim();
    }
}