import { LightningElement, api } from 'lwc';

export default class LeaveRequestDetails extends LightningElement {
    @api requestData;
    showCancelModal = false;

    get requestTitle() {
        const requestType = this.requestData?.type || 'Leave Request';
        return `${requestType} Request`;
    }

    get requestStatus() {
        return this.requestData?.status || 'In Review';
    }

    get requestNumber() {
        return `#${this.requestData?.requestNumber || '45890'}`;
    }

    get requestDateTime() {
        return this.requestData?.dateValue || '09 Oct 2026, 8:00 AM';
    }

    get requestType() {
        return this.requestData?.type || 'Exception';
    }

    get description() {
        return this.requestData?.description || 'No description provided.';
    }

    openCancelModal() {
        this.showCancelModal = true;
    }

    closeCancelModal() {
        this.showCancelModal = false;
    }

    confirmCancelRequest() {
        // Keep same close behavior for now; backend cancel integration can be added here.
        this.showCancelModal = false;
    }
}