import { LightningElement, track, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCategoryBuilderData from "@salesforce/apex/QuotaCategoryController.getCategoryBuilderData";
import saveCategory from "@salesforce/apex/QuotaCategoryController.saveCategory";

export default class QuotaCategoryBuilderPage extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track isSaving = false;

    categoryId;
    categoryName = "";
    categoryType = "";
    currencyCode = "";
    regulatorySource = "";
    isActive = true;

    @track categoryTypeOptions = [];
    @track currencyOptions = [];

    @wire(CurrentPageReference)
    setPageReference(pageRef) {
        this.categoryId = pageRef?.state?.c__categoryId || null;
    }

    connectedCallback() {
        this.loadBuilderData();
    }

    async loadBuilderData() {
        this.isLoading = true;
        try {
            const data = await getCategoryBuilderData({ categoryId: this.categoryId });
            this.categoryTypeOptions = (data?.categoryTypeOptions || []).map((value) => ({ label: value, value }));
            this.currencyOptions = data?.currencyOptions || [];
            const category = data?.category;
            if (category) {
                this.categoryName = category.categoryName || "";
                this.categoryType = category.categoryType || "";
                this.currencyCode = category.currencyCode || "";
                this.regulatorySource = category.regulatorySource || "";
                this.isActive = category.isActive !== false;
            } else if (this.currencyOptions.length && !this.currencyCode) {
                this.currencyCode = this.currencyOptions[0].value;
            }
        } catch (error) {
            this.toast("Error", this.parseError(error), "error");
        } finally {
            this.isLoading = false;
        }
    }

    handleInputChange(event) {
        const field = event.target.name;
        const value = event.target.type === "toggle" ? event.target.checked : event.detail.value;
        this[field] = value;
    }

    async handleSave() {
        if (this.isSaving) {
            return;
        }
        if (!this.categoryName?.trim()) {
            this.toast("Error", "Category Name is required.", "error");
            return;
        }
        if (!this.categoryType) {
            this.toast("Error", "Category Type is required.", "error");
            return;
        }

        this.isSaving = true;
        try {
            await saveCategory({
                categoryId: this.categoryId,
                categoryName: this.categoryName,
                categoryType: this.categoryType,
                currencyCode: this.currencyCode || null,
                regulatorySource: this.regulatorySource,
                isActive: this.isActive
            });
            this.toast("Success", this.categoryId ? "Category updated." : "Category created.", "success");
            this.navigateToList();
        } catch (error) {
            this.toast("Error", this.parseError(error), "error");
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.navigateToList();
    }

    navigateToMasterData() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__masterDataLanding" }
        });
    }

    navigateToQuotaCategories() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__quotaCategoryManager" }
        });
    }

    async navigateToList() {
        const pageReference = {
            type: "standard__component",
            attributes: { componentName: "c__quotaCategoryManager" },
            state: { c__refresh: Date.now().toString() }
        };
        const url = await this[NavigationMixin.GenerateUrl](pageReference);
        window.location.assign(url);
    }

    get pageTitle() {
        return this.categoryId ? "Edit Category" : "New Category";
    }

    get actionLabel() {
        return this.categoryId ? "Edit" : "New";
    }

    parseError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (Array.isArray(error?.body) && error.body[0]?.message) {
            return error.body[0].message;
        }
        return "Unable to save category.";
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}