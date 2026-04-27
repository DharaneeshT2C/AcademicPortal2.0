import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import generateHallTickets from '@salesforce/apex/HallTicketController.generateHallTickets';

export default class HallTicketGenerator extends LightningElement {
    @api recordId;
    isBusy = false;

    async handleConfirm() {
        this.isBusy = true;
        try {
            const result = await generateHallTickets({ programPlanId: this.recordId });
            this.toast('Hall Tickets', result.message, result.count > 0 ? 'success' : 'warning');
            this.close();
        } catch (e) {
            const msg = e?.body?.message || e?.message || 'Unexpected error';
            this.toast('Generation Failed', msg, 'error');
        } finally {
            this.isBusy = false;
        }
    }

    handleCancel() {
        this.close();
    }

    close() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}