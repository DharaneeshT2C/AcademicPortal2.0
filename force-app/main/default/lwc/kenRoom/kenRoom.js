import { LightningElement, api } from 'lwc';

export default class KenRoom extends LightningElement {
    @api hideListHead = false;
    @api rows = [];
    @api isLoading = false;
    @api selectedStatus = 'all';
    searchTerm = '';
    @api statusOptions = [];
    @api primaryActionLabel = 'New Room';
    @api isDetailView = false;

    @api selectedRoomOverview;
    @api selectedRoomStatus = '--';
    @api selectedRoomStatusClass = 'status-pill status-available';
    @api isBuildingLinkDisabled = false;
    @api isCategoryLinkDisabled = false;
    @api selectedRoomAmenitiesFromCategory = [];
    @api currentOccupantsHeading = 'Current Occupants (0)';
    @api roomCurrentOccupantsUiRows = [];
    @api roomPastOccupantsUiRows = [];
    @api isLoadingRoomOccupants = false;
    @api roomActivityCreatedByText = '--';
    @api roomActivityCreatedByName = '--';
    @api roomActivityCreatedDateText = '--';
    @api roomActivityLastModifiedText = '--';
    @api roomActivityEvents = [];

    @api isModalOpen = false;
    @api isSavingRoom = false;
    @api roomModalTitle = 'New Room';
    @api roomForm;
    @api roomBuildingOptions = [];
    @api filteredRoomFloorOptions = [];
    @api isRoomFloorDisabled = false;
    @api roomCategoryOptions = [];
    @api roomStatusOptions = [];
    @api createRoomButtonLabel = 'Create';

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
                row.roomNo,
                row.roomIdentifier,
                row.building,
                row.floor,
                row.category,
                row.capacity,
                row.currentOccupancyText,
                row.occupancy,
                row.status,
                ...(Array.isArray(row.amenitiesList) ? row.amenitiesList : [])
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

    handleOpenLinkedBuilding() {
        this.emit('openlinkedbuilding');
    }

    handleOpenLinkedCategory() {
        this.emit('openlinkedcategory');
    }

    handleBreadcrumbDashboardClick() {
        this.emit('breadcrumbdashboard');
    }

    handleBreadcrumbMasterDataClick() {
        this.emit('breadcrumbmasterdata');
    }

    handleBreadcrumbMasterTabClick() {
        this.emit('breadcrumbmastertab', { key: 'rooms' });
    }

    handleCloseModal() {
        this.emit('closemodal');
    }

    handleRoomFieldChange(event) {
        this.emit('roomfieldchange', { field: event.target.dataset.field, value: event.target.value });
    }

    handleSaveRoom() {
        this.emit('saveroom');
    }

    normalizeText(value) {
        return (value || '')
            .toString()
            .toLowerCase()
            .replace(/\s+/g, ' ')
            .trim();
    }
}