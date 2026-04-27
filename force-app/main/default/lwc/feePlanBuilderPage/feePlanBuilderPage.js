import { LightningElement, track, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getBuilderData from "@salesforce/apex/FeePlansController.getBuilderData";
import saveFeePlan from "@salesforce/apex/FeePlansController.saveFeePlan";

export default class FeePlanBuilderPage extends NavigationMixin(LightningElement) {
    feePlanName = "";
    description = "";
    currencyPolicy = "";
    isSaving = false;

    @track quotaChoices = [];
    @track categoryChoices = [];
    @track feeHeadChoices = [];
    @track taxOptions = [];
    @track currencyOptions = [];
    @track selectedQuotas = [];
    @track matrixRows = [];
    @track matrixSections = [];
    @track matrixValues = {};
    @track taxValues = {};
    @track settlementOrderValues = {};
    @track modalCategoryOptions = [];
    @track modalQuotaOptions = [];
    @track modalFeeHeadOptions = [];

    showSelectionModal = false;
    modalStep = "category";
    editFeeSetId = null;
    isEditMode = false;
    versionLabel = "v1.0";
    initialized = false;

    connectedCallback() {
        if (!this.initialized) {
            this.initialized = true;
            this.loadBuilderData();
        }
    }

    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        const nextRecordId = pageRef && pageRef.state ? pageRef.state.c__recordId : null;
        const nextMode = pageRef && pageRef.state ? pageRef.state.c__mode : null;
        const nextIsEditMode = nextMode === "edit" && !!nextRecordId;
        if (this.editFeeSetId === nextRecordId && this.isEditMode === nextIsEditMode) {
            return;
        }
        this.editFeeSetId = nextRecordId;
        this.isEditMode = nextIsEditMode;
        this.loadBuilderData();
    }

    async loadBuilderData() {
        try {
            const data = await getBuilderData({ feeSetId: this.isEditMode ? this.editFeeSetId : null });
            if (this.isEditMode && data?.isEditRestricted) {
                this.toast("Error", data.editRestrictionMessage || "Cannot edit this fee plan because it is used in programme fees.", "error");
                this[NavigationMixin.Navigate]({
                    type: "standard__component",
                    attributes: { componentName: "c__feePlanRecordPage" },
                    state: { c__recordId: this.editFeeSetId }
                });
                return;
            }
            const quotas = Array.isArray(data?.quotas) ? data.quotas : [];
            const feeHeads = Array.isArray(data?.feeHeads) ? data.feeHeads : [];
            const taxes = Array.isArray(data?.taxes) ? data.taxes : [];
            const currencies = Array.isArray(data?.currencyOptions) ? data.currencyOptions : [];
            const existingLines = Array.isArray(data?.lines) ? data.lines : [];

            this.feePlanName = data?.feePlanName || "";
            this.versionLabel = data?.versionLabel || "v1.0";
            this.currencyOptions = currencies.map((currencyOption) => ({
                label: currencyOption.label,
                value: currencyOption.value
            }));
            this.currencyPolicy = data?.currencyPolicy || (this.currencyOptions[0] ? this.currencyOptions[0].value : "");

            const selectedFeeHeadIds = new Set();
            const selectedQuotaKeys = new Set();
            const selectedCategoryKeys = new Set();
            const initialTaxValues = {};
            const initialSettlementOrderValues = {};

            existingLines.forEach((line) => {
                if (line?.feeHeadId) {
                    selectedFeeHeadIds.add(line.feeHeadId);
                    if (line.taxId && !initialTaxValues[line.feeHeadId]) {
                        initialTaxValues[line.feeHeadId] = line.taxId;
                    }
                    if (line.settlementOrder !== undefined && line.settlementOrder !== null && !initialSettlementOrderValues[line.feeHeadId]) {
                        initialSettlementOrderValues[line.feeHeadId] = line.settlementOrder;
                    }
                }
                if (line?.quotaId) {
                    selectedQuotaKeys.add(String(line.quotaId));
                }
            });

            this.quotaChoices = quotas.map((q) => ({
                ...q,
                key: q.id,
                selected: selectedQuotaKeys.has(String(q.id))
            }));
            this.quotaChoices.forEach((quota) => {
                if (quota.selected) {
                    selectedCategoryKeys.add(this.getQuotaCategoryKey(quota));
                }
            });
            this.categoryChoices = this.buildCategoryChoices(this.quotaChoices, selectedCategoryKeys);
            this.feeHeadChoices = feeHeads.map((f) => ({
                ...f,
                selected: selectedFeeHeadIds.has(f.id)
            }));
            this.taxOptions = [
                { label: "None", value: "" },
                ...taxes.map((tax) => ({ label: tax.label, value: tax.id }))
            ];
            const quotaKeyById = {};
            const quotaKeyByLabel = {};
            this.quotaChoices.forEach((quota) => {
                quotaKeyById[quota.id] = quota.key;
                quotaKeyByLabel[quota.label] = quota.key;
            });
            const initialMatrixValues = {};
            existingLines.forEach((line) => {
                const quotaKey = quotaKeyById[line?.quotaId] || quotaKeyByLabel[line?.quotaLabel];
                if (!line?.feeHeadId || !quotaKey) {
                    return;
                }
                const matrixKey = `${line.feeHeadId}__${quotaKey}`;
                initialMatrixValues[matrixKey] = line.amount;
            });
            this.taxValues = initialTaxValues;
            this.settlementOrderValues = initialSettlementOrderValues;
            this.matrixValues = initialMatrixValues;
            this.rebuildMatrix();
        } catch (e) {
            this.toast("Error", this.getErrorMessage(e), "error");
        }
    }

    handleFieldChange(event) {
        const fieldName = event.target.name || event.target.dataset.id;
        const value = event.target.value;
        if (fieldName === "feePlanName") {
            this.feePlanName = value;
        } else if (fieldName === "currencyPolicy") {
            this.currencyPolicy = value;
        } else if (fieldName === "description") {
            this.description = value;
        }
    }

    openConfigureMatrixModal() {
        this.openSelectionModal("category");
    }

    openQuotaStepModal() {
        this.openSelectionModal("category");
    }

    openFeeHeadStepModal() {
        this.openSelectionModal("category");
    }

    openSelectionModal(initialStep) {
        this.modalStep = initialStep || "category";
        this.modalCategoryOptions = this.categoryChoices.map((item) => ({
            key: item.key,
            label: item.label,
            selected: item.selected
        }));
        this.rebuildModalQuotaOptions();
        this.modalFeeHeadOptions = this.feeHeadChoices.map((item) => ({
            key: item.id,
            label: item.label,
            subLabel: null,
            selected: item.selected
        }));
        this.showSelectionModal = true;
    }

    buildCategoryChoices(quotas, selectedNames) {
        const byName = new Map();
        (quotas || []).forEach((quota) => {
            const rawName = (quota?.categoryName || "").trim() || "Uncategorized";
            const categoryKey = this.getQuotaCategoryKey(quota);
            if (!byName.has(categoryKey)) {
                byName.set(categoryKey, {
                    key: categoryKey,
                    label: rawName,
                    selected: selectedNames ? selectedNames.has(categoryKey) : false
                });
            }
        });
        return Array.from(byName.values()).sort((a, b) => a.label.localeCompare(b.label));
    }

    getQuotaCategoryKey(quota) {
        const explicitCategoryId = quota?.categoryId;
        if (explicitCategoryId) {
            return String(explicitCategoryId);
        }
        return (quota?.categoryName || "").trim() || "Uncategorized";
    }

    rebuildModalQuotaOptions() {
        const selectedCategoryKeys = new Set(
            (this.modalCategoryOptions || []).filter((item) => item.selected).map((item) => item.key)
        );
        const currentSelections = new Map((this.modalQuotaOptions || []).map((item) => [item.key, item.selected]));
        this.modalQuotaOptions = this.quotaChoices
            .filter((quota) => {
                return selectedCategoryKeys.has(this.getQuotaCategoryKey(quota));
            })
            .map((quota) => ({
                key: quota.key,
                label: quota.label,
                subLabel: quota.categoryName,
                selected: currentSelections.has(quota.key) ? currentSelections.get(quota.key) : quota.selected
            }));
    }

    handleCategorySelectionChange(event) {
        const key = event.target.dataset.key;
        const checked = event.target.checked;
        this.modalCategoryOptions = this.modalCategoryOptions.map((item) =>
            item.key === key ? { ...item, selected: checked } : item
        );
        this.rebuildModalQuotaOptions();
    }

    handleQuotaSelectionChange(event) {
        const key = event.target.dataset.key;
        const checked = event.target.checked;
        this.modalQuotaOptions = this.modalQuotaOptions.map((item) =>
            item.key === key ? { ...item, selected: checked } : item
        );
    }

    handleFeeHeadSelectionChange(event) {
        const key = event.target.dataset.key;
        const checked = event.target.checked;
        this.modalFeeHeadOptions = this.modalFeeHeadOptions.map((item) =>
            item.key === key ? { ...item, selected: checked } : item
        );
    }

    handleModalNext() {
        if (this.isCategoryStep && this.selectedModalCategoryCount === 0) {
            this.toast("Error", "Select at least one category to continue.", "error");
            return;
        }
        if (this.isCategoryStep) {
            this.modalStep = "quota";
            return;
        }
        if (this.isQuotaStep && this.selectedModalQuotaCount === 0) {
            this.toast("Error", "Select at least one quota to continue.", "error");
            return;
        }
        if (this.isQuotaStep) {
            this.modalStep = "feeHead";
        }
    }

    handleModalBack() {
        if (this.isFeeHeadStep) {
            this.modalStep = "quota";
        } else if (this.isQuotaStep) {
            this.modalStep = "category";
        }
    }

    handleApplySelectionModal() {
        if (this.selectedModalFeeHeadCount === 0) {
            this.toast("Error", "Select at least one fee head.", "error");
            return;
        }

        const selectedQuotaByKey = new Map(
            this.modalQuotaOptions.map((item) => [item.key, item.selected])
        );
        const selectedCategoryByKey = new Map(
            this.modalCategoryOptions.map((item) => [item.key, item.selected])
        );
        const selectedFeeHeadByKey = new Map(
            this.modalFeeHeadOptions.map((item) => [item.key, item.selected])
        );

        this.categoryChoices = this.categoryChoices.map((item) => ({
            ...item,
            selected: selectedCategoryByKey.get(item.key) || false
        }));
        this.quotaChoices = this.quotaChoices.map((item) => ({
            ...item,
            selected: selectedQuotaByKey.get(item.key) || false
        }));
        this.feeHeadChoices = this.feeHeadChoices.map((item) => ({
            ...item,
            selected: selectedFeeHeadByKey.get(item.id) || false
        }));

        this.handleCloseSelectionModal();
        this.rebuildMatrix();
    }

    handleCloseSelectionModal() {
        this.showSelectionModal = false;
        this.modalStep = "category";
        this.modalCategoryOptions = [];
        this.modalQuotaOptions = [];
        this.modalFeeHeadOptions = [];
    }

    handleOverlayClick() {
        this.handleCloseSelectionModal();
    }

    preventModalClose(event) {
        event.stopPropagation();
    }

    handleAmountChange(event) {
        const matrixKey = event.target.dataset.matrixKey;
        if (!matrixKey) {
            return;
        }
        const rawValue = event.target.value;
        this.matrixValues = {
            ...this.matrixValues,
            [matrixKey]: rawValue === "" || rawValue === null ? null : rawValue
        };
        this.rebuildMatrix();
    }

    handleTaxChange(event) {
        const feeHeadId = event.target.dataset.feeHeadId;
        if (!feeHeadId) {
            return;
        }
        this.taxValues = {
            ...this.taxValues,
            [feeHeadId]: event.target.value || null
        };
        this.rebuildMatrix();
    }

    handleSettlementOrderChange(event) {
        const feeHeadId = event.target.dataset.feeHeadId;
        if (!feeHeadId) {
            return;
        }
        const rawValue = event.target.value;
        const parsed = rawValue === null || rawValue === undefined || rawValue === ""
            ? null
            : Number(rawValue);
        const settlementOrder = parsed !== null && Number.isFinite(parsed) ? Math.max(1, Math.round(parsed)) : null;
        this.settlementOrderValues = {
            ...this.settlementOrderValues,
            [feeHeadId]: settlementOrder
        };
        this.rebuildMatrix();
    }

    rebuildMatrix() {
        const selectedCategories = new Set(
            this.categoryChoices.filter((category) => category.selected).map((category) => category.key)
        );
        this.selectedQuotas = this.quotaChoices.filter((quota) => {
            if (!quota.selected) {
                return false;
            }
            return selectedCategories.has(this.getQuotaCategoryKey(quota));
        });
        this.syncCurrencyPolicyWithSelectedQuotas();
        const selectedFeeHeads = this.feeHeadChoices.filter((f) => f.selected);

        this.matrixRows = selectedFeeHeads.map((feeHead, index) => {
            const cells = this.selectedQuotas.map((quota) => {
                const matrixKey = `${feeHead.id}__${quota.key}`;
                return {
                    key: matrixKey,
                    quotaKey: quota.key,
                    amount: this.matrixValues[matrixKey]
                };
            });

            return {
                feeHeadId: feeHead.id,
                feeHeadLabel: feeHead.label,
                taxId: this.taxValues[feeHead.id] || feeHead.taxId || null,
                settlementOrder: this.settlementOrderValues[feeHead.id] || index + 1,
                cells
            };
        });

        const quotaByKey = new Map(this.selectedQuotas.map((quota) => [quota.key, quota]));
        this.matrixSections = this.categoryChoices
            .filter((category) => category.selected)
            .map((category) => {
                const sectionQuotas = this.selectedQuotas.filter((quota) => {
                    return this.getQuotaCategoryKey(quota) === category.key;
                });
                const sectionQuotaKeys = new Set(sectionQuotas.map((quota) => quota.key));
                const sectionRows = this.matrixRows.map((row) => ({
                    ...row,
                    cells: row.cells.filter((cell) => sectionQuotaKeys.has(cell.quotaKey)).map((cell) => ({
                        ...cell,
                        quotaLabel: quotaByKey.get(cell.quotaKey)?.label
                    }))
                }));
                return {
                    key: category.key,
                    label: category.label,
                    quotas: sectionQuotas.map((quota) => ({
                        ...quota,
                        displayLabel: this.buildQuotaCurrencyLabel(quota)
                    })),
                    rows: sectionRows
                };
            })
            .filter((section) => section.quotas.length > 0);
    }

    async handleSaveDraft() {
        await this.savePlan("Draft");
    }

    async handleActivate() {
        if (this.isActivateDisabled) {
            return;
        }
        await this.savePlan("Active");
    }

    async savePlan(status) {
        const feePlanNameInput = this.template.querySelector('[data-id="feePlanName"]');
        const planName = (this.feePlanName || "").trim();

        if (!planName) {
            if (feePlanNameInput) {
                feePlanNameInput.reportValidity();
            }
            this.toast("Error", "Fee Plan Name is required.", "error");
            return;
        }

        if (status === "Active") {
            if (this.selectedQuotas.length === 0) {
                this.toast("Error", "Select at least one quota.", "error");
                return;
            }
            if (this.selectedFeeHeads.length === 0) {
                this.toast("Error", "Select at least one fee head.", "error");
                return;
            }
            if (!this.hasAtLeastOneAmount) {
                this.toast("Error", "Enter at least one amount in the matrix.", "error");
                return;
            }
        }

        const duplicateSettlementOrder = this.findDuplicateSettlementOrder();
        if (duplicateSettlementOrder !== null) {
            this.toast("Error", `Settlement Order ${duplicateSettlementOrder} is duplicated. Each fee head must have a unique settlement order.`, "error");
            return;
        }

        const selectedCurrencies = this.getSelectedCategoryCurrencies();
        if (selectedCurrencies.length > 1) {
            this.toast("Error", `Selected categories use multiple currencies (${selectedCurrencies.join(", ")}). Select quotas with a single currency.`, "error");
            return;
        }
        if (selectedCurrencies.length === 1) {
            const selectedCurrency = selectedCurrencies[0];
            if (this.currencyOptions.some((option) => option.value === selectedCurrency)) {
                this.currencyPolicy = selectedCurrency;
            }
        }

        const lines = [];
        for (const row of this.matrixRows) {
            for (const cell of row.cells) {
                const quota = this.selectedQuotas.find((q) => q.key === cell.quotaKey);
                lines.push({
                    feeHeadId: row.feeHeadId,
                    quotaId: quota ? quota.id : null,
                    categoryId: quota ? quota.categoryId || null : null,
                    quotaLabel: quota ? quota.label : null,
                    quotaCode: quota ? quota.code : null,
                    taxId: row.taxId || null,
                    amount: this.toDecimal(cell.amount),
                    settlementOrder: row.settlementOrder
                });
            }
        }

        this.isSaving = true;
        try {
            await saveFeePlan({
                requestJson: JSON.stringify({
                    feeSetId: this.isEditMode ? this.editFeeSetId : null,
                    feePlanName: planName,
                    description: this.description,
                    currencyPolicy: this.currencyPolicy,
                    status,
                    lines
                })
            });

            this.toast(
                "Success",
                status === "Active" ? "Fee Plan activated." : this.isEditMode ? "Fee Plan updated." : "Fee Plan saved as draft.",
                "success"
            );
            if (status === "Active") {
                await this.navigateToFeePlansWithReload();
            } else if (this.isEditMode) {
                this[NavigationMixin.Navigate]({
                    type: "standard__component",
                    attributes: { componentName: "c__feePlanRecordPage" },
                    state: { c__recordId: this.editFeeSetId }
                });
            } else {
                this[NavigationMixin.Navigate]({
                    type: "standard__component",
                    attributes: { componentName: "c__feePlansPage" },
                    state: { c__refresh: Date.now().toString() }
                });
            }
        } catch (e) {
            this.toast("Error", this.getErrorMessage(e), "error");
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__feePlansPage" }
        });
    }

    handleGoToMasterData() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__masterDataLanding" }
        });
    }

    handleGoToFeePlans() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__feePlansPage" }
        });
    }

    get hasMatrix() {
        return this.matrixSections.length > 0 && this.selectedFeeHeads.length > 0;
    }

    get pageTitle() {
        return this.isEditMode ? "Edit Fee Plan" : "New Fee Plan";
    }

    get breadcrumbModeLabel() {
        return this.isEditMode ? "Edit" : "New";
    }

    get saveButtonLabel() {
        return this.isEditMode ? "Save" : "Save Draft";
    }

    get hasSelectionOptions() {
        if (this.isCategoryStep) {
            return this.modalCategoryOptions.length > 0;
        }
        if (this.isQuotaStep) {
            return this.modalQuotaOptions.length > 0;
        }
        return this.modalFeeHeadOptions.length > 0;
    }

    get selectionModalTitle() {
        if (this.isCategoryStep) {
            return "Step 1: Select Categories";
        }
        if (this.isQuotaStep) {
            return "Step 2: Select Quotas";
        }
        return "Step 3: Select Fee Heads";
    }

    get isCategoryStep() {
        return this.modalStep === "category";
    }

    get isQuotaStep() {
        return this.modalStep === "quota";
    }

    get isFeeHeadStep() {
        return this.modalStep === "feeHead";
    }

    get selectedModalQuotaCount() {
        return this.modalQuotaOptions.filter((item) => item.selected).length;
    }

    get selectedModalCategoryCount() {
        return this.modalCategoryOptions.filter((item) => item.selected).length;
    }

    get selectedModalFeeHeadCount() {
        return this.modalFeeHeadOptions.filter((item) => item.selected).length;
    }

    get hasAnySelection() {
        return this.selectedQuotas.length > 0 || this.selectedFeeHeads.length > 0;
    }

    get quotaStepClass() {
        return this.isQuotaStep ? "step-chip step-chip-active" : "step-chip";
    }

    get feeHeadStepClass() {
        return this.isFeeHeadStep ? "step-chip step-chip-active" : "step-chip";
    }

    get categoryStepClass() {
        return this.isCategoryStep ? "step-chip step-chip-active" : "step-chip";
    }

    get selectedFeeHeads() {
        return this.feeHeadChoices.filter((f) => f.selected);
    }

    get isActivateDisabled() {
        const hasName = (this.feePlanName || "").trim().length > 0;
        const hasQuota = this.selectedQuotas.length > 0;
        const hasFeeHead = this.selectedFeeHeads.length > 0;
        return this.isSaving || !hasName || !hasQuota || !hasFeeHead || !this.hasAtLeastOneAmount;
    }

    get hasAtLeastOneAmount() {
        for (const row of this.matrixRows) {
            for (const cell of row.cells) {
                const value = this.toDecimal(cell.amount);
                if (value !== null && value >= 0) {
                    return true;
                }
            }
        }
        return false;
    }

    toDecimal(value) {
        if (value === null || value === undefined || value === "") {
            return null;
        }
        const parsed = Number(value);
        return Number.isFinite(parsed) ? parsed : null;
    }

    findDuplicateSettlementOrder() {
        const seen = new Set();
        for (const row of this.matrixRows) {
            const order = this.toDecimal(row.settlementOrder);
            if (order === null) {
                continue;
            }
            const normalized = Math.max(1, Math.round(order));
            if (seen.has(normalized)) {
                return normalized;
            }
            seen.add(normalized);
        }
        return null;
    }

    getSelectedCategoryCurrencies() {
        const uniqueCurrencies = new Set();
        (this.selectedQuotas || []).forEach((quota) => {
            const currencyValue = (quota?.categoryCurrency || "").trim();
            if (currencyValue) {
                uniqueCurrencies.add(currencyValue);
            }
        });
        return Array.from(uniqueCurrencies).sort();
    }

    syncCurrencyPolicyWithSelectedQuotas() {
        const selectedCurrencies = this.getSelectedCategoryCurrencies();
        if (selectedCurrencies.length !== 1) {
            return;
        }
        const selectedCurrency = selectedCurrencies[0];
        if (this.currencyOptions.some((option) => option.value === selectedCurrency)) {
            this.currencyPolicy = selectedCurrency;
        }
    }

    buildQuotaCurrencyLabel(quota) {
        const quotaLabel = (quota?.label || "").trim() || "Quota";
        const currencyValue = (quota?.categoryCurrency || this.currencyPolicy || "").trim();
        return currencyValue ? `${quotaLabel} (${currencyValue})` : quotaLabel;
    }

    getErrorMessage(error) {
        return error && error.body && error.body.message
            ? error.body.message
            : "Unexpected error occurred.";
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    async navigateToFeePlansWithReload() {
        const pageReference = {
            type: "standard__component",
            attributes: { componentName: "c__feePlansPage" },
            state: { c__refresh: Date.now().toString() }
        };
        const generatedUrl = await this[NavigationMixin.GenerateUrl](pageReference);
        window.location.assign(generatedUrl);
    }
}