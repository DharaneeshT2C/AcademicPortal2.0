import { LightningElement, api } from 'lwc';

export default class KenRoomCategoryView extends LightningElement {
    @api rows = [];
    @api isLoading = false;
    isAmenitiesModalOpen = false;
    selectedCategoryName = '';
    selectedAmenities = [];

    dispatchRowAction(action, event) {
        this.dispatchEvent(
            new CustomEvent('rowaction', {
                detail: {
                    action,
                    id: event.currentTarget.dataset.id
                }
            })
        );
    }

    handleOpen(event) {
        this.dispatchRowAction('open', event);
    }

    handleView(event) {
        this.dispatchRowAction('view', event);
    }

    handleEdit(event) {
        this.dispatchRowAction('edit', event);
    }

    handleDelete(event) {
        this.dispatchRowAction('delete', event);
    }

    handleOpenAmenities(event) {
        const rowId = event.currentTarget.dataset.id;
        const row = (this.rows || []).find((item) => String(item.id) === String(rowId));
        if (!row) {
            return;
        }

        this.selectedCategoryName = row.categoryName || 'Amenities';
        this.selectedAmenities = Array.isArray(row.amenitiesList) ? [...row.amenitiesList] : [];
        this.isAmenitiesModalOpen = this.selectedAmenities.length > 0;
    }

    handleCloseAmenities() {
        this.isAmenitiesModalOpen = false;
        this.selectedCategoryName = '';
        this.selectedAmenities = [];
    }
}