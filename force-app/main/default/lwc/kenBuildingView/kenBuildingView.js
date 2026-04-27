import { LightningElement, api } from 'lwc';

export default class KenBuildingView extends LightningElement {
    @api rows = [];
    @api isLoading = false;

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
}