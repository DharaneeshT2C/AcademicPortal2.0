import { LightningElement, api } from 'lwc';

export default class ConfirmDeleteModal extends LightningElement {
    @api recordName = '';
    @api objectLabel = 'record';  // pass "academic term", "academic session", etc.

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleConfirm() {
        this.dispatchEvent(new CustomEvent('confirm'));
    }
}