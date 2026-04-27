import LightningModal from "lightning/modal";
import { api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import saveCategory from "@salesforce/apex/QuotaCategoryController.saveCategory";

export default class CategoryModal extends LightningModal {
    _categoryId = null;
    _categoryName = "";
    _categoryType = "";
    _regulatorySource = "";
    _isActive = false;
    _categoryTypeOptions = [];

    @api
    get categoryId() {
        return this._categoryId;
    }

    set categoryId(value) {
        this._categoryId = value ?? null;
    }

    @api
    get categoryName() {
        return this._categoryName;
    }

    set categoryName(value) {
        this._categoryName = value ?? "";
    }

    @api
    get categoryType() {
        return this._categoryType;
    }

    set categoryType(value) {
        this._categoryType = value ?? "";
    }

    @api
    get regulatorySource() {
        return this._regulatorySource;
    }

    set regulatorySource(value) {
        this._regulatorySource = value ?? "";
    }

    @api
    get isActive() {
        return this._isActive;
    }

    set isActive(value) {
        this._isActive = value === true;
    }

    @api
    get categoryTypeOptions() {
        return this._categoryTypeOptions;
    }

    set categoryTypeOptions(value) {
        this._categoryTypeOptions = Array.isArray(value) ? value : [];
    }

    connectedCallback() {
        if (this.categoryId === null && this.isActive === false) {
            this._isActive = true;
        }
    }

    handleFieldInput(event) {
        const fieldName = event.target.name;
        const fieldValue =
            event.target.type === "checkbox"
                ? event.target.checked
                : event.detail && event.detail.value !== undefined
                  ? event.detail.value
                  : event.target.value;

        if (fieldName === "categoryName") {
            this._categoryName = fieldValue;
        } else if (fieldName === "categoryType") {
            this._categoryType = fieldValue;
        } else if (fieldName === "regulatorySource") {
            this._regulatorySource = fieldValue;
        } else if (fieldName === "isActive") {
            this._isActive = fieldValue === true;
        }
    }

    async handleSave() {
        const categoryNameInput = this.template.querySelector('[data-id="categoryName"]');
        const categoryTypeInput = this.template.querySelector('[data-id="categoryType"]');
        const regulatorySourceInput = this.template.querySelector('[data-id="regulatorySource"]');
        const isActiveInput = this.template.querySelector('[data-id="isActive"]');

        this._categoryName = categoryNameInput ? categoryNameInput.value : this.categoryName;
        this._categoryType = categoryTypeInput ? categoryTypeInput.value : this.categoryType;
        this._regulatorySource = regulatorySourceInput ? regulatorySourceInput.value : this.regulatorySource;
        this._isActive = isActiveInput ? isActiveInput.checked : this.isActive;

        const nameValue = (this.categoryName || "").trim();
        const nameValid = nameValue.length > 0;
        const typeValue = (this.categoryType || "").trim();
        const typeValid = typeValue.length > 0;

        if (!nameValid) {
            if (categoryNameInput && typeof categoryNameInput.reportValidity === "function") {
                categoryNameInput.reportValidity();
            }
            this.dispatchEvent(new ShowToastEvent({ title: "Error", message: "Category Name is required.", variant: "error" }));
            return;
        }

        if (!typeValid) {
            if (categoryTypeInput && typeof categoryTypeInput.reportValidity === "function") {
                categoryTypeInput.reportValidity();
            }
            this.dispatchEvent(new ShowToastEvent({ title: "Error", message: "Category Type is required.", variant: "error" }));
            return;
        }

        try {
            await saveCategory({
                categoryId: this.categoryId,
                categoryName: nameValue,
                categoryType: typeValue,
                currencyCode: null,
                regulatorySource: this.regulatorySource,
                isActive: this.isActive
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Success",
                    message: this.categoryId ? "Category updated." : "Category created.",
                    variant: "success"
                })
            );
            this.close("saved");
        } catch (e) {
            const message = e && e.body && e.body.message ? e.body.message : "Failed to save category.";
            this.dispatchEvent(new ShowToastEvent({ title: "Error", message, variant: "error" }));
        }
    }

    handleCancel() {
        this.close("cancel");
    }

    get modalTitle() {
        return this.categoryId ? "Edit Category" : "New Category";
    }

    get saveButtonLabel() {
        return this.categoryId ? "Save" : "Create Category";
    }
}