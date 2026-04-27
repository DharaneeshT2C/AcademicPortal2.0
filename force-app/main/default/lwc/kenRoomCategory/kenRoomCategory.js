import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRoomCategories from '@salesforce/apex/KenRoomCategoryController.getRoomCategories';
import getLinkedRoomsByCategory from '@salesforce/apex/KenRoomCategoryController.getLinkedRoomsByCategory';
import getRoomCategoryActivityHistory from '@salesforce/apex/KenRoomCategoryController.getRoomCategoryActivityHistory';
import getRoomCategoryFormOptions from '@salesforce/apex/KenRoomCategoryController.getRoomCategoryFormOptions';
import createRoomCategory from '@salesforce/apex/KenRoomCategoryController.createRoomCategory';
import updateRoomCategory from '@salesforce/apex/KenRoomCategoryController.updateRoomCategory';
import deleteRoomCategoryRecord from '@salesforce/apex/KenRoomCategoryController.deleteRoomCategory';
import addCustomAmenity from '@salesforce/apex/KenRoomCategoryController.addCustomAmenity';

export default class KenRoomCategory extends LightningElement {
    @api hideListHead = false;
    @api initialDetailId = null;
    isLoadingRoomCategories = false;
    isLoadingLinkedRooms = false;
    isSavingRoomCategory = false;
    roomCategoryRows = [];
    selectedRoomCategory = null;
    linkedRoomRows = [];
    roomCategoryActivityHistory = null;
    selectedStatus = 'all';
    searchTerm = '';
    viewMode = 'list';
    isNewRoomCategoryModalOpen = false;
    editingRoomCategoryId = null;
    customAmenityInput = '';
    editingCustomAmenityValue = null;
    editableCustomAmenityValues = [];
    hasAppliedInitialDetail = false;
    openDropdown = '';
    roomCategoryFeeTypeOptions = [];
    roomCategoryAmenitiesOptions = [];
    roomCategoryStatusOptions = [];
    roomCategoryAcOptions = [
        { label: 'Yes', value: 'Yes' },
        { label: 'No', value: 'No' }
    ];
    roomCategoryBathroomOptions = [
        { label: 'Attached', value: 'Attached' },
        { label: 'Common', value: 'Common' }
    ];
    roomCategoryForm = {
        categoryName: '',
        description: '',
        sharing: '',
        ac: '',
        bathroom: '',
        defaultFeeTypeIds: [],
        statusValue: 'active',
        amenities: []
    };

    connectedCallback() {
        this.boundHandleDocumentClick = this.handleDocumentClick.bind(this);
        document.addEventListener('click', this.boundHandleDocumentClick);
        this.initializeComponent();
    }

    disconnectedCallback() {
        if (this.boundHandleDocumentClick) {
            document.removeEventListener('click', this.boundHandleDocumentClick);
        }
    }

    @api
    openNewRoomCategoryModal() {
        this.handleOpenNewModal();
    }

    async initializeComponent() {
        await this.loadRoomCategories();
        await this.openInitialDetailIfNeeded();
    }

    get isDetailView() {
        return this.viewMode === 'detail';
    }

    get isEditingRoomCategory() {
        return !!this.editingRoomCategoryId;
    }

    get roomCategoryModalTitle() {
        return this.isEditingRoomCategory ? 'Edit Room Category' : 'New Room Category';
    }

    get createRoomCategoryButtonLabel() {
        if (this.isSavingRoomCategory) {
            return this.isEditingRoomCategory ? 'Updating...' : 'Creating...';
        }
        return this.isEditingRoomCategory ? 'Update' : 'Create';
    }

    get selectedRoomCategoryName() {
        return this.selectedRoomCategory?.categoryName || '--';
    }

    get selectedRoomCategoryIdentifier() {
        return this.selectedRoomCategory?.categoryIdentifier || '--';
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

    get roomCategoryFeeTypeUiOptions() {
        const selected = new Set(this.roomCategoryForm.defaultFeeTypeIds || []);
        return (this.roomCategoryFeeTypeOptions || []).map((item) => ({
            ...item,
            checked: selected.has(item.value)
        }));
    }

    get selectedFeeTypesText() {
        const selected = new Set(this.roomCategoryForm.defaultFeeTypeIds || []);
        const labels = (this.roomCategoryFeeTypeOptions || [])
            .filter((item) => selected.has(item.value))
            .map((item) => item.label);
        return labels.length ? labels.join(', ') : '';
    }

    get hasRoomCategoryFeeTypeOptions() {
        return (this.roomCategoryFeeTypeOptions || []).length > 0;
    }

    get isFeeTypeDropdownOpen() {
        return this.openDropdown === 'feeType';
    }

    get isAmenitiesDropdownOpen() {
        return this.openDropdown === 'amenities';
    }

    get feeTypeDropdownClass() {
        return this.isFeeTypeDropdownOpen ? 'dropdown-trigger open' : 'dropdown-trigger';
    }

    get amenitiesDropdownClass() {
        return this.isAmenitiesDropdownOpen ? 'dropdown-trigger open' : 'dropdown-trigger';
    }

    get selectedRoomCategorySharing() {
        return this.firstNonBlankUi(this.selectedRoomCategory?.sharing, '--') || '--';
    }

    get selectedRoomCategoryAc() {
        return this.firstNonBlankUi(this.selectedRoomCategory?.ac, '--') || '--';
    }

    get selectedRoomCategoryBathroom() {
        return this.firstNonBlankUi(this.selectedRoomCategory?.bathroom, '--') || '--';
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

    get roomCategoryActivityCreatedByName() {
        return this.firstNonBlankUi(this.roomCategoryActivityHistory?.createdByName, '--');
    }

    get roomCategoryActivityCreatedDateText() {
        return this.formatDateValue(this.roomCategoryActivityHistory?.createdDate, false);
    }

    get roomCategoryActivityLastModifiedText() {
        const by = this.firstNonBlankUi(this.roomCategoryActivityHistory?.lastModifiedByName, '--');
        const at = this.formatDateValue(this.roomCategoryActivityHistory?.lastModifiedDate, false);
        return `${by} \u2022 ${at}`;
    }

    get roomCategoryActivityEvents() {
        const events = this.roomCategoryActivityHistory?.events || [];
        return events.map((event, index) => ({
            ...event,
            key: `${index}-${event.title || 'event'}`,
            eventAtText: this.formatDateValue(event.eventAt, true)
        }));
    }

    get roomCategoryAmenitiesUiOptions() {
        const selected = new Set(this.roomCategoryForm.amenities || []);
        const editableCustomAmenityValues = new Set(this.editableCustomAmenityValues || []);
        return (this.roomCategoryAmenitiesOptions || []).map((item) => ({
            ...item,
            checked: selected.has(item.value),
            canEdit: editableCustomAmenityValues.has(item.value)
        }));
    }

    get selectedAmenitiesText() {
        const selected = this.roomCategoryForm.amenities || [];
        if (!selected.length) {
            return '';
        }

        const labelsByValue = new Map(
            (this.roomCategoryAmenitiesOptions || []).map((item) => [item.value, item.label || item.value])
        );
        return selected.map((value) => labelsByValue.get(value) || value).join(', ');
    }

    get isEditingCustomAmenity() {
        return !!this.editingCustomAmenityValue;
    }

    get customAmenityActionLabel() {
        return this.isEditingCustomAmenity ? 'Update' : 'Add';
    }

    get filteredRoomCategoryRows() {
        const normalizedSearch = this.normalizeLookupLabel(this.searchTerm);
        if (!normalizedSearch) {
            return this.roomCategoryRows;
        }

        return (this.roomCategoryRows || []).filter((row) => {
            const haystacks = [
                row.categoryName,
                row.categoryIdentifier,
                row.sharing,
                row.ac,
                row.bathroom,
                row.defaultFeeType,
                row.status,
                ...(Array.isArray(row.amenitiesList) ? row.amenitiesList : [])
            ];
            return haystacks.some((value) => this.normalizeLookupLabel(value).includes(normalizedSearch));
        });
    }

    handleStatusChange(event) {
        this.selectedStatus = event.target.value;
        this.loadRoomCategories();
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value || '';
    }

    async handleOpenNewModal() {
        if (
            !(this.roomCategoryFeeTypeOptions || []).length ||
            !(this.roomCategoryAmenitiesOptions || []).length ||
            !(this.roomCategoryStatusOptions || []).length
        ) {
            await this.loadRoomCategoryFormOptions();
        }

        this.editingRoomCategoryId = null;
        this.openDropdown = '';
        this.resetRoomCategoryForm();
        this.isNewRoomCategoryModalOpen = true;
    }

    handleCloseNewRoomCategoryModal() {
        this.openDropdown = '';
        this.isNewRoomCategoryModalOpen = false;
        this.editingRoomCategoryId = null;
        this.resetRoomCategoryForm();
    }

    handleBackToList() {
        this.viewMode = 'list';
        this.linkedRoomRows = [];
        this.roomCategoryActivityHistory = null;
        this.notifyViewModeChange();
    }

    handleBreadcrumbDashboardClick() {
        this.dispatchEvent(new CustomEvent('navigate', { detail: { type: 'dashboard' } }));
    }

    handleBreadcrumbMasterDataClick() {
        this.dispatchEvent(new CustomEvent('navigate', { detail: { type: 'masterData' } }));
    }

    handleRowAction(event) {
        const action = event.detail?.action;
        const rowId = event.detail?.id;
        if (!action || !rowId) {
            return;
        }
        const selectedRow = (this.roomCategoryRows || []).find((row) => String(row.id) === String(rowId));
        if (!selectedRow) {
            return;
        }
        if (action === 'open' || action === 'view') {
            this.openRoomCategoryDetail(selectedRow);
            return;
        }
        if (action === 'edit') {
            this.openEditRoomCategory(selectedRow);
            return;
        }
        if (action === 'delete') {
            this.handleDeleteRoomCategory(selectedRow);
        }
    }

    async openRoomCategoryDetail(selectedRow) {
        this.selectedRoomCategory = selectedRow;
        this.viewMode = 'detail';
        this.notifyViewModeChange();
        await Promise.all([this.loadLinkedRoomsForSelectedCategory(), this.loadRoomCategoryActivityHistory()]);
    }

    async loadRoomCategoryActivityHistory() {
        const categoryId = this.selectedRoomCategory?.id;
        if (!categoryId) {
            this.roomCategoryActivityHistory = null;
            return;
        }

        this.roomCategoryActivityHistory = null;
        try {
            this.roomCategoryActivityHistory = await getRoomCategoryActivityHistory({
                categoryId: String(categoryId)
            });
        } catch {
            // Meta section should still render safely with placeholder values.
            this.roomCategoryActivityHistory = null;
        }
    }

    handleEditSelectedRoomCategory() {
        if (!this.selectedRoomCategory) {
            return;
        }
        this.openEditRoomCategory(this.selectedRoomCategory);
    }

    async handleDeactivateSelectedRoomCategory() {
        const selectedRow = this.selectedRoomCategory;
        if (!selectedRow?.id) {
            return;
        }
        if (selectedRow.statusValue === 'inactive') {
            this.toast('Info', 'Room category is already inactive.', 'info');
            return;
        }
        if (!window.confirm(`Deactivate room category "${selectedRow.categoryName}"?`)) {
            return;
        }
        try {
            await updateRoomCategory({
                roomCategoryId: String(selectedRow.id),
                inputRequest: { statusValue: 'inactive' }
            });
            this.selectedStatus = 'all';
            await this.loadRoomCategories();
            this.toast('Success', 'Room category deactivated successfully.', 'success');
        } catch (error) {
            this.toast('Error', this.extractErrorMessage(error), 'error');
        }
    }

    async openEditRoomCategory(selectedRow) {
        if (
            !(this.roomCategoryFeeTypeOptions || []).length ||
            !(this.roomCategoryAmenitiesOptions || []).length ||
            !(this.roomCategoryStatusOptions || []).length
        ) {
            await this.loadRoomCategoryFormOptions();
        }
        const feeTypeIds = Array.isArray(selectedRow.defaultFeeTypeIds) ? [...selectedRow.defaultFeeTypeIds] : [];
        this.roomCategoryForm = {
            categoryName: this.firstNonBlankUi(selectedRow.categoryName, '') || '',
            description: this.firstNonBlankUi(selectedRow.description, '') || '',
            sharing: this.firstNonBlankUi(selectedRow.sharing, '') || '',
            ac: this.firstNonBlankUi(selectedRow.ac, '') || '',
            bathroom: this.firstNonBlankUi(selectedRow.bathroom, '') || '',
            defaultFeeTypeIds: feeTypeIds,
            statusValue: this.firstNonBlankUi(selectedRow.statusValue, 'active') || 'active',
            amenities: Array.isArray(selectedRow.amenitiesList) ? [...selectedRow.amenitiesList] : []
        };
        this.editingRoomCategoryId = selectedRow.id;
        this.customAmenityInput = '';
        this.editingCustomAmenityValue = null;
        this.editableCustomAmenityValues = [];
        this.openDropdown = '';
        this.isNewRoomCategoryModalOpen = true;
    }

    async handleDeleteRoomCategory(selectedRow) {
        if (!selectedRow?.id) {
            return;
        }
        if (!window.confirm(`Delete room category "${selectedRow.categoryName}"?`)) {
            return;
        }
        try {
            await deleteRoomCategoryRecord({ roomCategoryId: String(selectedRow.id) });
            await this.loadRoomCategories();
            this.toast('Success', 'Room category deleted successfully.', 'success');
        } catch (error) {
            this.toast('Error', this.extractErrorMessage(error), 'error');
        }
    }

    handleViewAllLinkedRooms() {
        this.dispatchEvent(new CustomEvent('navigate', { detail: { type: 'viewAllRooms' } }));
    }

    handleOpenLinkedRoom(event) {
        const rowId = event.currentTarget.dataset.id;
        const row = (this.linkedRoomRows || []).find((item) => String(item.id) === String(rowId));
        if (!row?.id) {
            return;
        }
        this.dispatchEvent(new CustomEvent('navigate', { detail: { type: 'openRoom', roomId: row.id } }));
    }

    handleOpenLinkedBuilding(event) {
        const rowId = event.currentTarget.dataset.id;
        const row = (this.linkedRoomRows || []).find((item) => String(item.id) === String(rowId));
        if (!row) {
            return;
        }
        this.dispatchEvent(
            new CustomEvent('navigate', {
                detail: { type: 'openBuilding', buildingId: row.buildingId, buildingName: row.building }
            })
        );
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

    handleDropdownToggle(event) {
        event.stopPropagation();
        const dropdown = event.currentTarget?.dataset?.dropdown;
        if (!dropdown) {
            return;
        }
        this.openDropdown = this.openDropdown === dropdown ? '' : dropdown;
    }

    handleDropdownContainerClick(event) {
        event.stopPropagation();
    }

    handleDocumentClick() {
        this.openDropdown = '';
    }

    handleAmenityToggle(event) {
        const amenityValue = event.target.dataset.value;
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

    handleFeeTypeToggle(event) {
        const feeTypeId = event.target.dataset.value;
        const selected = new Set(this.roomCategoryForm.defaultFeeTypeIds || []);
        if (event.target.checked) {
            selected.add(feeTypeId);
        } else {
            selected.delete(feeTypeId);
        }
        this.roomCategoryForm = {
            ...this.roomCategoryForm,
            defaultFeeTypeIds: Array.from(selected)
        };
    }

    handleCustomAmenityInputChange(event) {
        this.customAmenityInput = event.target.value || '';
    }

    handleEditCustomAmenity(event) {
        const amenityValue = event.currentTarget?.dataset?.value;
        if (!amenityValue) {
            return;
        }

        const selectedOption = (this.roomCategoryAmenitiesOptions || []).find((item) => item.value === amenityValue);
        if (!selectedOption) {
            return;
        }

        this.editingCustomAmenityValue = amenityValue;
        this.customAmenityInput = this.firstNonBlankUi(selectedOption.label, selectedOption.value, '') || '';
    }

    handleCancelCustomAmenityEdit() {
        this.editingCustomAmenityValue = null;
        this.customAmenityInput = '';
    }

    async handleAddCustomAmenity() {
        const amenityName = this.firstNonBlankUi(this.customAmenityInput);
        if (!amenityName) {
            return;
        }

        const duplicateOption = this.findAmenityOptionByLabel(
            amenityName,
            this.editingCustomAmenityValue
        );
        if (duplicateOption) {
            this.toast('Validation Error', 'Amenity already exists.', 'warning');
            return;
        }
        try {
            const addedOption = await addCustomAmenity({ amenityName });
            this.upsertCustomAmenityOption(addedOption);
            this.customAmenityInput = '';
            this.editingCustomAmenityValue = null;
        } catch (error) {
            this.toast('Error', this.extractErrorMessage(error), 'error');
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
            this.toast(
                'Success',
                this.isEditingRoomCategory ? 'Room category updated successfully.' : 'Room category created successfully.',
                'success'
            );
            this.handleCloseNewRoomCategoryModal();
        } catch (error) {
            this.toast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isSavingRoomCategory = false;
        }
    }

    async loadRoomCategories() {
        this.isLoadingRoomCategories = true;
        try {
            const rows = await getRoomCategories({ statusFilter: this.selectedStatus });
            this.roomCategoryRows = (rows || []).map((row) => ({
                ...row,
                hasAmenities: Array.isArray(row.amenitiesList) && row.amenitiesList.length > 0,
                statusClass: row.statusValue === 'active' ? 'status-pill status-active' : 'status-pill status-inactive'
            }));
            if (this.selectedRoomCategory?.id) {
                const refreshed = this.roomCategoryRows.find((row) => String(row.id) === String(this.selectedRoomCategory.id));
                this.selectedRoomCategory = refreshed || this.selectedRoomCategory;
                if (this.isDetailView && this.selectedRoomCategory?.id) {
                    await this.loadLinkedRoomsForSelectedCategory();
                }
            }
            await this.openInitialDetailIfNeeded();
        } catch (error) {
            this.roomCategoryRows = [];
            this.toast('Error', this.extractErrorMessage(error), 'error');
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
            const rows = await getLinkedRoomsByCategory({ categoryId: String(categoryId) });
            this.linkedRoomRows = (rows || []).map((row) => ({
                ...row,
                statusClass:
                    row.statusValue === 'occupied'
                        ? 'status-pill status-linked-occupied'
                        : row.statusValue === 'partiallyOccupied'
                            ? 'status-pill status-linked-partial'
                            : row.statusValue === 'blocked' || row.statusValue === 'maintenance'
                                ? 'status-pill status-linked-inactive'
                                : 'status-pill status-linked-available'
            }));
        } catch (error) {
            this.linkedRoomRows = [];
            this.toast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoadingLinkedRooms = false;
        }
    }

    async loadRoomCategoryFormOptions() {
        try {
            const response = await getRoomCategoryFormOptions();
            this.roomCategoryFeeTypeOptions = response?.feeTypeOptions || [];
            this.roomCategoryAmenitiesOptions = response?.amenitiesOptions || [];
            this.roomCategoryStatusOptions = response?.statusOptions || [];
        } catch (error) {
            this.toast('Error', this.extractErrorMessage(error), 'error');
        }
    }

    validateRoomCategoryForm() {
        const { categoryName, sharing, ac, bathroom, statusValue } = this.roomCategoryForm;
        if (!categoryName || !sharing || !ac || !bathroom || !statusValue) {
            this.toast('Validation Error', 'Please fill all required Room Category fields.', 'warning');
            return false;
        }
        if (!/^[1-9]\d*$/.test(String(sharing).trim())) {
            this.toast('Validation Error', 'Occupancy must be a positive whole number.', 'warning');
            return false;
        }
        return true;
    }

    resetRoomCategoryForm() {
        this.roomCategoryForm = {
            categoryName: '',
            description: '',
            sharing: '',
            ac: '',
            bathroom: '',
            defaultFeeTypeIds: [],
            statusValue: 'active',
            amenities: []
        };
        this.customAmenityInput = '';
        this.editingCustomAmenityValue = null;
        this.editableCustomAmenityValues = [];
    }

    findAmenityOptionByLabel(amenityLabel, excludedValue = null) {
        const normalizedAmenityLabel = this.normalizeLookupLabel(amenityLabel);
        if (!normalizedAmenityLabel) {
            return null;
        }

        return (this.roomCategoryAmenitiesOptions || []).find((item) => {
            if (!item) {
                return false;
            }
            if (excludedValue && item.value === excludedValue) {
                return false;
            }
            const normalizedOptionLabel = this.normalizeLookupLabel(
                this.firstNonBlankUi(item.label, item.value, '')
            );
            return normalizedOptionLabel === normalizedAmenityLabel;
        });
    }

    upsertCustomAmenityOption(addedOption) {
        if (!addedOption?.value) {
            return;
        }

        const previousValue = this.editingCustomAmenityValue;
        if (previousValue) {
            this.roomCategoryAmenitiesOptions = (this.roomCategoryAmenitiesOptions || []).map((item) =>
                item.value === previousValue
                    ? { ...item, label: addedOption.label, value: addedOption.value }
                    : item
            );

            const nextSelectedAmenities = (this.roomCategoryForm.amenities || []).map((item) =>
                item === previousValue ? addedOption.value : item
            );
            this.roomCategoryForm = {
                ...this.roomCategoryForm,
                amenities: Array.from(new Set(nextSelectedAmenities))
            };
            this.editableCustomAmenityValues = (this.editableCustomAmenityValues || []).map((item) =>
                item === previousValue ? addedOption.value : item
            );
            return;
        }

        if (!this.roomCategoryAmenitiesOptions.some((item) => item.value === addedOption.value)) {
            this.roomCategoryAmenitiesOptions = [...this.roomCategoryAmenitiesOptions, addedOption];
            this.editableCustomAmenityValues = [...this.editableCustomAmenityValues, addedOption.value];
        }

        const selected = new Set(this.roomCategoryForm.amenities || []);
        selected.add(addedOption.value);
        this.roomCategoryForm = {
            ...this.roomCategoryForm,
            amenities: Array.from(selected)
        };
    }

    findOptionValueByLabel(options, label) {
        const normalizedLabel = this.normalizeLookupLabel(label);
        if (!normalizedLabel) {
            return null;
        }
        const option = (options || []).find((item) => {
            const optionLabel = this.normalizeLookupLabel(item.label);
            return optionLabel === normalizedLabel || optionLabel.includes(normalizedLabel) || normalizedLabel.includes(optionLabel);
        });
        return option?.value || null;
    }

    normalizeLookupLabel(value) {
        const text = this.firstNonBlankUi(value);
        if (!text) {
            return '';
        }
        return text.toLowerCase().replace(/\s+/g, ' ').trim();
    }

    firstNonBlankUi(...values) {
        for (const value of values) {
            if (value !== null && value !== undefined && String(value).trim() !== '') {
                return String(value).trim();
            }
        }
        return null;
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
        return body?.message || error?.message || 'Something went wrong. Please try again.';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    notifyViewModeChange() {
        this.dispatchEvent(
            new CustomEvent('viewmodechange', {
                detail: {
                    isDetail: this.viewMode === 'detail',
                    selectedRoomCategoryId: this.selectedRoomCategory?.id || null
                }
            })
        );
    }

    async openInitialDetailIfNeeded() {
        if (this.hasAppliedInitialDetail || !this.initialDetailId || this.isDetailView) {
            return;
        }
        const row = (this.roomCategoryRows || []).find((item) => String(item.id) === String(this.initialDetailId));
        if (!row) {
            return;
        }
        this.hasAppliedInitialDetail = true;
        await this.openRoomCategoryDetail(row);
    }
}