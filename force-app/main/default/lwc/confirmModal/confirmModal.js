import { LightningElement, api } from 'lwc';

export default class ConfirmModal extends LightningElement {
    @api title = 'Are you sure?';
    @api message = '';
    @api cancelLabel = 'Cancel';
    @api confirmLabel = 'Confirm';
    @api variant = 'primary'; // 'primary' | 'danger'

    get confirmClass() {
        return this.variant === 'danger' ? 'btn-confirm danger' : 'btn-confirm primary';
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleConfirm() {
        this.dispatchEvent(new CustomEvent('confirm'));
    }

    handleOverlayClick(event) {
        if (event.target === event.currentTarget) {
            this.handleCancel();
        }
    }

    stop(event) {
        event.stopPropagation();
    }
}
