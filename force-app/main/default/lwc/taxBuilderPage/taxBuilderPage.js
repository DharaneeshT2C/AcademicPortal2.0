import { LightningElement, track, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { updateRecord } from "lightning/uiRecordApi";
import getTaxes from "@salesforce/apex/TaxesController.getTaxes";
import getTaxOptions from "@salesforce/apex/TaxesController.getTaxOptions";
import saveTax from "@salesforce/apex/TaxesController.saveTax";

export default class TaxBuilderPage extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track isSaving = false;
    @track parentTaxOptions = [];

    taxId = null;
    mode = "new";
    taxName = "";
    taxRate = null;
    parentTaxId = "";
    routeKey;

    @wire(CurrentPageReference)
    setPageReference(pageRef) {
        const recordId = pageRef?.state?.c__recordId || null;
        const requestedMode = String(pageRef?.state?.c__mode || "").toLowerCase();
        const nextMode = requestedMode === "edit" && recordId ? "edit" : "new";
        const nextRouteKey = `${nextMode}:${recordId || ""}`;
        if (nextRouteKey === this.routeKey) {
            return;
        }

        this.routeKey = nextRouteKey;
        this.mode = nextMode;
        this.taxId = nextMode === "edit" ? recordId : null;
        this.loadBuilderData();
    }

    async loadBuilderData() {
        this.isLoading = true;
        try {
            const [taxOptions, taxes] = await Promise.all([
                getTaxOptions(),
                this.isEditMode ? getTaxes() : Promise.resolve([])
            ]);
            this.parentTaxOptions = this.buildParentTaxOptions(taxOptions || []);

            if (this.isEditMode) {
                const taxRecord = (taxes || []).find((row) => row.id === this.taxId);
                if (!taxRecord) {
                    this.toast("Error", "Tax record was not found.", "error");
                    await this.navigateToTaxesWithRefresh();
                    return;
                }
                this.taxName = taxRecord.name || "";
                this.taxRate = taxRecord.taxRate;
                this.parentTaxId = this.resolveParentTaxId(taxRecord.parentTaxName, taxOptions || []);
            } else {
                this.resetForm();
            }
        } catch (error) {
            this.toast("Error", this.getErrorMessage(error), "error");
        } finally {
            this.isLoading = false;
        }
    }

    buildParentTaxOptions(optionRows) {
        const options = (optionRows || [])
            .filter((option) => option?.id && option.id !== this.taxId)
            .map((option) => ({ label: option.name, value: option.id }));

        return [{ label: "None", value: "" }, ...options];
    }

    resolveParentTaxId(parentTaxName, optionRows) {
        if (!parentTaxName || parentTaxName === "-") {
            return "";
        }
        const match = (optionRows || []).find((option) => option.name === parentTaxName && option.id !== this.taxId);
        return match ? match.id : "";
    }

    resetForm() {
        this.taxName = "";
        this.taxRate = null;
        this.parentTaxId = "";
    }

    handleInputChange(event) {
        const field = event.target.name;
        if (field === "parentTaxId") {
            this.parentTaxId = event.detail.value;
            return;
        }
        this[field] = event.target.value;
    }

    async handleSave() {
        if (this.isSaving) {
            return;
        }

        const trimmedName = (this.taxName || "").trim();
        if (!trimmedName) {
            this.toast("Error", "Tax Name is required.", "error");
            return;
        }

        const normalizedTaxRate = this.taxRate === "" || this.taxRate === null ? null : Number(this.taxRate);
        this.isSaving = true;
        try {
            if (this.isEditMode) {
                await updateRecord({
                    fields: {
                        Id: this.taxId,
                        Name: trimmedName,
                        Tax_Rate__c: normalizedTaxRate,
                        Parent_Tax__c: this.parentTaxId || null
                    }
                });
                this.toast("Success", "Tax updated successfully.", "success");
            } else {
                await saveTax({
                    taxName: trimmedName,
                    taxRate: normalizedTaxRate,
                    parentTaxId: this.parentTaxId || null
                });
                this.toast("Success", "Tax saved successfully.", "success");
            }
            await this.navigateToTaxesWithRefresh();
        } catch (error) {
            this.toast("Error", this.getErrorMessage(error), "error");
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        if (this.isSaving) {
            return;
        }
        this.navigateToTaxes();
    }

    handleGoToMasterData() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__masterDataLanding" }
        });
    }

    navigateToTaxes() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__taxesPage" }
        });
    }

    async navigateToTaxesWithRefresh() {
        const pageReference = {
            type: "standard__component",
            attributes: { componentName: "c__taxesPage" },
            state: { c__refresh: Date.now().toString() }
        };
        const generatedUrl = await this[NavigationMixin.GenerateUrl](pageReference);
        window.location.assign(generatedUrl);
    }

    get pageTitle() {
        return this.isEditMode ? "Edit Tax" : "New Tax";
    }

    get breadcrumbCurrent() {
        return this.isEditMode ? "Edit Tax" : "New Tax";
    }

    get isEditMode() {
        return this.mode === "edit" && !!this.taxId;
    }

    getErrorMessage(error) {
        return error?.body?.message || "Unexpected error occurred.";
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}