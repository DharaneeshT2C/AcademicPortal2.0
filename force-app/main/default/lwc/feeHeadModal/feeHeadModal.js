import LightningModal from "lightning/modal";
import { api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import createFeeHead from "@salesforce/apex/FeeHeadsController.createFeeHead";
import getRemittanceAccountOptions from "@salesforce/apex/FeeHeadsController.getRemittanceAccountOptions";
import getTaxDefinitionOptions from "@salesforce/apex/FeeHeadsController.getTaxDefinitionOptions";

export default class FeeHeadModal extends LightningModal {
    @api feeHeadTypeOptions = [];

    feeHeadName = "";
    feeHeadType = "";
    isActive = true;
    refundable = false;
    taxable = false;
    defaultRemittanceAccountId = "";
    taxDefinitionId = "";
    taxPercentage = "";
    description = "";

    remittanceAccountOptions = [];
    taxDefinitionOptions = [];
    taxRateByDefinitionId = {};

    isSaving = false;
    isLoadingOptions = true;

    connectedCallback() {
        if (!Array.isArray(this.feeHeadTypeOptions)) {
            this.feeHeadTypeOptions = [];
        }
        this.loadLookupOptions();
    }

    get modalTitle() {
        return "New Fee Head";
    }

    get isBusy() {
        return this.isSaving || this.isLoadingOptions;
    }

    handleFieldInput(event) {
        const fieldName = event.target.name;
        const isBooleanInput =
            event.target.type === "checkbox" || event.target.type === "toggle";
        const fieldValue =
            isBooleanInput
                ? event.target.checked
                : event.detail && event.detail.value !== undefined
                  ? event.detail.value
                  : event.target.value;

        if (fieldName === "feeHeadName") {
            this.feeHeadName = fieldValue;
        } else if (fieldName === "feeHeadType") {
            this.feeHeadType = fieldValue;
        } else if (fieldName === "isActive") {
            this.isActive = fieldValue;
        } else if (fieldName === "refundable") {
            this.refundable = fieldValue;
        } else if (fieldName === "taxable") {
            this.taxable = fieldValue;
        } else if (fieldName === "defaultRemittanceAccountId") {
            this.defaultRemittanceAccountId = fieldValue;
        } else if (fieldName === "taxDefinitionId") {
            this.taxDefinitionId = fieldValue;
            this.syncTaxPercentage();
        } else if (fieldName === "description") {
            this.description = fieldValue;
        }
    }

    async loadLookupOptions() {
        this.isLoadingOptions = true;
        try {
            const [remittanceRows, taxRows] = await Promise.all([
                getRemittanceAccountOptions(),
                getTaxDefinitionOptions()
            ]);

            this.remittanceAccountOptions = (Array.isArray(remittanceRows) ? remittanceRows : []).map((row) => ({
                label: row.label,
                value: row.value
            }));

            const taxRateByDefinitionId = {};
            this.taxDefinitionOptions = (Array.isArray(taxRows) ? taxRows : []).map((row) => {
                taxRateByDefinitionId[row.value] = row.taxRate;
                return {
                    label: row.label,
                    value: row.value
                };
            });
            this.taxRateByDefinitionId = taxRateByDefinitionId;
            this.syncTaxPercentage();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: this.getErrorMessage(error),
                    variant: "error"
                })
            );
        } finally {
            this.isLoadingOptions = false;
        }
    }

    syncTaxPercentage() {
        if (!this.taxDefinitionId) {
            this.taxPercentage = "";
            return;
        }

        const selectedTaxRate = this.taxRateByDefinitionId[this.taxDefinitionId];
        this.taxPercentage =
            selectedTaxRate === undefined || selectedTaxRate === null
                ? ""
                : `${selectedTaxRate}`;
    }

    async handleSave() {
        await this.saveFeeHead(false);
    }

    async handleSaveAndNew() {
        await this.saveFeeHead(true);
    }

    async saveFeeHead(saveAndNew) {
        const feeHeadNameInput = this.template.querySelector('[data-id="feeHeadName"]');
        const feeHeadTypeInput = this.template.querySelector('[data-id="feeHeadType"]');

        this.feeHeadName = feeHeadNameInput ? feeHeadNameInput.value : this.feeHeadName;
        this.feeHeadType = feeHeadTypeInput ? feeHeadTypeInput.value : this.feeHeadType;

        const normalizedName = (this.feeHeadName || "").trim();
        if (!normalizedName) {
            if (feeHeadNameInput && typeof feeHeadNameInput.reportValidity === "function") {
                feeHeadNameInput.reportValidity();
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: "Fee Head Name is required.",
                    variant: "error"
                })
            );
            return;
        }

        if (!this.feeHeadType) {
            if (feeHeadTypeInput && typeof feeHeadTypeInput.reportValidity === "function") {
                feeHeadTypeInput.reportValidity();
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: "Head Category is required.",
                    variant: "error"
                })
            );
            return;
        }

        this.isSaving = true;
        try {
            await createFeeHead({
                feeHeadName: normalizedName,
                feeHeadType: this.feeHeadType,
                isActive: this.isActive,
                refundable: this.refundable,
                taxable: this.taxable,
                defaultRemittanceAccountId: this.defaultRemittanceAccountId || null,
                taxDefinitionId: this.taxDefinitionId || null,
                description: this.description
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Success",
                    message: "Fee Head created.",
                    variant: "success"
                })
            );

            if (saveAndNew) {
                this.resetForm();
            } else {
                this.close("saved");
            }
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: this.getErrorMessage(error),
                    variant: "error"
                })
            );
        } finally {
            this.isSaving = false;
        }
    }

    resetForm() {
        this.feeHeadName = "";
        this.feeHeadType = "";
        this.isActive = true;
        this.refundable = false;
        this.taxable = false;
        this.defaultRemittanceAccountId = "";
        this.taxDefinitionId = "";
        this.taxPercentage = "";
        this.description = "";
    }

    handleCancel() {
        this.close("cancel");
    }

    getErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return "Failed to create fee head.";
    }
}