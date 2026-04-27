import { LightningElement, api } from 'lwc';

export default class KenRoomView extends LightningElement {
    @api rows = [];
    @api isLoading = false;
    isAmenitiesModalOpen = false;
    selectedRoomLabel = '';
    selectedAmenities = [];

    get uiRows() {
        return (this.rows || []).map((row) => ({
            ...row,
            hasAmenities: Array.isArray(row.amenitiesList) && row.amenitiesList.length > 0
        }));
    }

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

        this.selectedRoomLabel = row.roomNo || 'Amenities';
        this.selectedAmenities = Array.isArray(row.amenitiesList) ? [...row.amenitiesList] : [];
        this.isAmenitiesModalOpen = this.selectedAmenities.length > 0;
    }

    handleCloseAmenities() {
        this.isAmenitiesModalOpen = false;
        this.selectedRoomLabel = '';
        this.selectedAmenities = [];
    }
}