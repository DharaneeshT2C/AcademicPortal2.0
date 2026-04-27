import LightningModal from "lightning/modal";
import { api, track } from "lwc";
import saveQuota from "@salesforce/apex/QuotaCategoryController.saveQuota";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class QuotaModal extends LightningModal {
    static DUPLICATE_CODE_ERROR = "Quota code already exists. Enter a unique code.";

    _quotaId = null;
    _quotaName = "";
    _code = "";
    _reservationPercent = null;
    _priorityOrder = null;
    _isActive = false;

    @api
    get quotaId() {
        return this._quotaId;
    }

    set quotaId(value) {
        this._quotaId = value ?? null;
    }

    @api categoryId;

    @api
    get quotaName() {
        return this._quotaName;
    }

    set quotaName(value) {
        this._quotaName = value ?? "";
    }

    @api
    get code() {
        return this._code;
    }

    set code(value) {
        this._code = value ?? "";
    }

    @api
    get reservationPercent() {
        return this._reservationPercent;
    }

    set reservationPercent(value) {
        this._reservationPercent = value ?? null;
    }

    @api
    get priorityOrder() {
        return this._priorityOrder;
    }

    set priorityOrder(value) {
        this._priorityOrder = value ?? null;
    }

    @api
    get isActive() {
        return this._isActive;
    }

    set isActive(value) {
        this._isActive = value === true;
    }

    @track isSaving = false;
    @track showErrorPopup = false;
    @track errorPopupMessage = "";

    connectedCallback() {
        if (this.quotaId === null && this.isActive === false) {
            this._isActive = true;
        }
    }

    handleChange(event) {
        const field = event.target.name;
        const value =
            event.target.type === "checkbox"
                ? event.target.checked
                : event.detail && event.detail.value !== undefined
                  ? event.detail.value
                  : event.target.value;

        if (field === "quotaName") {
            this._quotaName = value;
        }
        if (field === "code") {
            this._code = value;
        }
        if (field === "reservationPercent") {
            this._reservationPercent = value === "" ? null : Number(value);
        }
        if (field === "priorityOrder") {
            this._priorityOrder = value === "" ? null : Number(value);
        }
        if (field === "isActive") {
            this._isActive = value === true;
        }
    }

    async handleSave() {
        const quotaNameInput = this.template.querySelector('[data-id="quotaName"]');
        const codeInput = this.template.querySelector('[data-id="code"]');
        const reservationPercentInput = this.template.querySelector('[data-id="reservationPercent"]');
        const priorityOrderInput = this.template.querySelector('[data-id="priorityOrder"]');
        const isActiveInput = this.template.querySelector('[data-id="isActive"]');

        this._quotaName = quotaNameInput ? quotaNameInput.value : this.quotaName;
        this._code = codeInput ? codeInput.value : this.code;
        if (reservationPercentInput) {
            this._reservationPercent = reservationPercentInput.value !== "" ? Number(reservationPercentInput.value) : null;
        }
        if (priorityOrderInput) {
            this._priorityOrder = priorityOrderInput.value !== "" ? Number(priorityOrderInput.value) : null;
        }
        this._isActive = isActiveInput ? isActiveInput.checked : this.isActive;

        const quotaName = (this.quotaName || "").trim();
        const code = (this.code || "").trim();
        const quotaNameValid = quotaName.length > 0;
        const codeValid = code.length > 0;

        this.clearCodeFieldError(codeInput);
        this.closeErrorPopup();

        if (!quotaNameValid) {
            if (quotaNameInput && typeof quotaNameInput.reportValidity === "function") {
                quotaNameInput.reportValidity();
            }
            this.dispatchEvent(new ShowToastEvent({ title: "Error", message: "Quota Name is required.", variant: "error" }));
            return;
        }
        if (!codeValid) {
            if (codeInput && typeof codeInput.reportValidity === "function") {
                codeInput.reportValidity();
            }
            this.dispatchEvent(new ShowToastEvent({ title: "Error", message: "Code is required.", variant: "error" }));
            return;
        }

        this.isSaving = true;
        try {
            await saveQuota({
                quotaId: this.quotaId,
                categoryId: this.categoryId,
                quotaName,
                code,
                reservationPercent: this.reservationPercent,
                priorityOrder: this.priorityOrder,
                isActive: this.isActive
            });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Success",
                    message: this.quotaId ? "Quota updated." : "Quota created.",
                    variant: "success"
                })
            );
            this.close("saved");
        } catch (e) {
            const message = e && e.body && e.body.message ? e.body.message : "Failed to save.";
            if (message === QuotaModal.DUPLICATE_CODE_ERROR) {
                this.setCodeFieldError(codeInput, message);
                this.openErrorPopup(message);
                return;
            }
            this.dispatchEvent(new ShowToastEvent({ title: "Error", message, variant: "error" }));
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.close("cancel");
    }

    handleErrorPopupClose() {
        this.closeErrorPopup();
    }

    get modalTitle() {
        return this.quotaId ? "Edit Quota" : "New Quota";
    }

    get saveButtonLabel() {
        return this.quotaId ? "Save" : "Create Quota Entry";
    }

    openErrorPopup(message) {
        this.errorPopupMessage = message;
        this.showErrorPopup = true;
    }

    closeErrorPopup() {
        this.showErrorPopup = false;
        this.errorPopupMessage = "";
    }

    setCodeFieldError(codeInput, message) {
        if (codeInput && typeof codeInput.setCustomValidity === "function") {
            codeInput.setCustomValidity(message);
            codeInput.reportValidity();
        }
    }

    clearCodeFieldError(codeInput) {
        if (codeInput && typeof codeInput.setCustomValidity === "function") {
            codeInput.setCustomValidity("");
            codeInput.reportValidity();
        }
    }
}