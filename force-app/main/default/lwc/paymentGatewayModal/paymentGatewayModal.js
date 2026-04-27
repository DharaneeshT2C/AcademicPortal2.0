import LightningModal from "lightning/modal";
import { api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import createPaymentGateway from "@salesforce/apex/PaymentGatewaysController.createPaymentGateway";
import updatePaymentGateway from "@salesforce/apex/PaymentGatewaysController.updatePaymentGateway";

export default class PaymentGatewayModal extends LightningModal {
    @api recordId = null;
    @api isEditMode = false;
    @api paymentGatewayName = "";
    @api gatewayDisplayName = "";
    @api paymentGatewayProviderId = null;
    @api environment = "";
    @api externalReference = "";
    @api merchantCredentialId = null;
    @api status = "";
    @api comments = "";
    @api providerOptions = [];
    @api merchantCredentialOptions = [];
    @api statusOptions = [];
    @api environmentOptions = [];

    isSaving = false;

    connectedCallback() {
        if (!Array.isArray(this.providerOptions)) {
            this.providerOptions = [];
        }
        if (!Array.isArray(this.merchantCredentialOptions)) {
            this.merchantCredentialOptions = [];
        }
        if (!Array.isArray(this.statusOptions)) {
            this.statusOptions = [];
        }
        if (!Array.isArray(this.environmentOptions)) {
            this.environmentOptions = [];
        }

        if (!this.status && this.statusOptions.length > 0) {
            this.status = this.statusOptions[0].value;
        }
        if (!this.environment && this.environmentOptions.length > 0) {
            this.environment = this.environmentOptions[0].value;
        }
    }

    get modalTitle() {
        return this.isEditMode ? "Edit Payment Gateway" : "New Payment Gateway";
    }

    handleFieldInput(event) {
        const fieldName = event.target.name;
        const fieldValue =
            event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;

        if (fieldName === "paymentGatewayProviderId") {
            this.paymentGatewayProviderId = fieldValue;
        } else if (fieldName === "paymentGatewayName") {
            this.paymentGatewayName = fieldValue;
        } else if (fieldName === "gatewayDisplayName") {
            this.gatewayDisplayName = fieldValue;
        } else if (fieldName === "status") {
            this.status = fieldValue;
        } else if (fieldName === "environment") {
            this.environment = fieldValue;
        } else if (fieldName === "externalReference") {
            this.externalReference = fieldValue;
        } else if (fieldName === "merchantCredentialId") {
            this.merchantCredentialId = fieldValue;
        } else if (fieldName === "comments") {
            this.comments = fieldValue;
        }
    }

    async handleSave() {
        const providerInput = this.template.querySelector('[data-id="paymentGatewayProviderId"]');
        const gatewayNameInput = this.template.querySelector('[data-id="paymentGatewayName"]');
        const gatewayDisplayNameInput = this.template.querySelector('[data-id="gatewayDisplayName"]');
        const statusInput = this.template.querySelector('[data-id="status"]');
        const environmentInput = this.template.querySelector('[data-id="environment"]');
        const externalReferenceInput = this.template.querySelector('[data-id="externalReference"]');

        this.paymentGatewayProviderId = providerInput ? providerInput.value : this.paymentGatewayProviderId;
        this.paymentGatewayName = gatewayNameInput ? gatewayNameInput.value : this.paymentGatewayName;
        this.gatewayDisplayName = gatewayDisplayNameInput ? gatewayDisplayNameInput.value : this.gatewayDisplayName;
        this.status = statusInput ? statusInput.value : this.status;
        this.environment = environmentInput ? environmentInput.value : this.environment;
        this.externalReference = externalReferenceInput ? externalReferenceInput.value : this.externalReference;

        // if (!this.paymentGatewayProviderId) {
        //     this.dispatchEvent(
        //         new ShowToastEvent({
        //             title: "Error",
        //             message: "Payment Gateway Provider is required.",
        //             variant: "error"
        //         })
        //     );
        //     return;
        // }

        if (!(this.paymentGatewayName || "").trim()) {
            if (gatewayNameInput && typeof gatewayNameInput.reportValidity === "function") {
                gatewayNameInput.reportValidity();
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: "Payment Gateway Name is required.",
                    variant: "error"
                })
            );
            return;
        }

        if (!(this.gatewayDisplayName || "").trim()) {
            if (gatewayDisplayNameInput && typeof gatewayDisplayNameInput.reportValidity === "function") {
                gatewayDisplayNameInput.reportValidity();
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: "Gateway Display Name is required.",
                    variant: "error"
                })
            );
            return;
        }

        if (!this.status) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: "Status is required.",
                    variant: "error"
                })
            );
            return;
        }

        if (!(this.externalReference || "").trim()) {
            if (externalReferenceInput && typeof externalReferenceInput.reportValidity === "function") {
                externalReferenceInput.reportValidity();
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: "External Reference is required.",
                    variant: "error"
                })
            );
            return;
        }

        this.isSaving = true;
        try {
            if (this.isEditMode) {
                await updatePaymentGateway({
                    paymentGatewayId: this.recordId,
                    paymentGatewayProviderId: this.paymentGatewayProviderId,
                    paymentGatewayName: this.paymentGatewayName,
                    gatewayDisplayName: this.gatewayDisplayName,
                    status: this.status,
                    environment: this.environment,
                    externalReference: this.externalReference,
                    merchantCredentialId: this.merchantCredentialId,
                    comments: this.comments
                });
            } else {
                await createPaymentGateway({
                    paymentGatewayProviderId: this.paymentGatewayProviderId,
                    paymentGatewayName: this.paymentGatewayName,
                    gatewayDisplayName: this.gatewayDisplayName,
                    status: this.status,
                    environment: this.environment,
                    externalReference: this.externalReference,
                    merchantCredentialId: this.merchantCredentialId,
                    comments: this.comments
                });
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Success",
                    message: this.isEditMode ? "Payment gateway updated." : "Payment gateway created.",
                    variant: "success"
                })
            );
            this.close("saved");
        } catch (error) {
            const message =
                error && error.body && error.body.message
                    ? error.body.message
                    : this.isEditMode
                      ? "Failed to update payment gateway."
                      : "Failed to create payment gateway.";
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message,
                    variant: "error"
                })
            );
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.close("cancel");
    }
}