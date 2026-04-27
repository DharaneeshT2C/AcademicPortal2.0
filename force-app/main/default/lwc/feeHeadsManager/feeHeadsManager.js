import { LightningElement, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";

import getFeeHeads from "@salesforce/apex/FeeHeadsController.getFeeHeads";
import getFeeHeadTypeOptions from "@salesforce/apex/FeeHeadsController.getFeeHeadTypeOptions";
import getRemittanceAccountOptions from "@salesforce/apex/FeeHeadsController.getRemittanceAccountOptions";
import getTaxDefinitionOptions from "@salesforce/apex/FeeHeadsController.getTaxDefinitionOptions";
import createFeeHead from "@salesforce/apex/FeeHeadsController.createFeeHead";
import updateFeeHead from "@salesforce/apex/FeeHeadsController.updateFeeHead";
import deleteFeeHead from "@salesforce/apex/FeeHeadsController.deleteFeeHead";

export default class FeeHeadsManager extends NavigationMixin(LightningElement) {
    @track isLoading = false;
    @track feeHeads = [];
    @track filteredFeeHeads = [];
    @track searchText = "";
    @track feeHeadTypeOptions = [];
    @track remittanceAccountOptions = [];
    @track taxDefinitionOptions = [];
    @track taxRateByDefinitionId = {};
    @track selectedFeeHeadId = null;
    @track openActionMenuFeeHeadId = null;
    @track isFormView = false;
    @track isEditMode = false;
    @track formIsSaving = false;

    @track formFeeHeadId = null;
    @track formFeeHeadName = "";
    @track formFeeHeadType = "";
    @track formIsActive = true;
    @track formRefundable = false;
    @track formTaxable = false;
    @track formDefaultRemittanceAccountId = "";
    @track formTaxDefinitionId = "";
    @track formTaxPercentage = "";
    @track formDescription = "";
    @track activeDetailTab = "details";
    @track notification = null;
    @track confirmDialog = null;

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        this.isLoading = true;
        try {
            const [feeHeadRows, typeOptions] = await Promise.all([
                getFeeHeads(),
                getFeeHeadTypeOptions()
            ]);

            this.feeHeads = (Array.isArray(feeHeadRows) ? feeHeadRows : []).map((row) =>
                this.mapFeeHeadRow(row)
            );
            if (this.selectedFeeHeadId) {
                const exists = this.feeHeads.some((row) => row.id === this.selectedFeeHeadId);
                if (!exists) {
                    this.selectedFeeHeadId = null;
                }
            }
            this.feeHeadTypeOptions = (Array.isArray(typeOptions) ? typeOptions : []).map((row) => ({
                label: row.label,
                value: row.value
            }));
            await this.loadFormOptions();
            this.applySearchFilter();
        } catch (error) {
            this.showToast("Error", this.getErrorMessage(error), "error");
        } finally {
            this.isLoading = false;
        }
    }

    mapFeeHeadRow(row) {
        const defaultRemittanceName = row.defaultRemittanceAccountName || "";
        const defaultRemittanceNumber = row.defaultRemittanceAccountNumber || "";
        const defaultRemittanceDisplay = defaultRemittanceName
            ? defaultRemittanceNumber
                ? `${defaultRemittanceName} - ${defaultRemittanceNumber}`
                : defaultRemittanceName
            : "-";

        const isActive = row.isActive === true;
        const refundable = row.refundable === true;
        const taxable = row.taxable === true;

        return {
            ...row,
            name: row.name || "-",
            feeHeadName: row.feeHeadName || "-",
            feeHeadType: row.feeHeadType || "-",
            isActive,
            refundable,
            taxable,
            activeLabel: isActive ? "Active" : "Inactive",
            activePillClass: `statusPill ${isActive ? "statusPillActive" : "statusPillInactive"}`,
            refundableLabel: refundable ? "Yes" : "No",
            refundableClass: `statusPill ${refundable ? "statusPillActive" : "statusPillInactive"}`,
            taxableLabel: taxable ? "Yes" : "No",
            taxableClass: `statusPill ${taxable ? "statusPillActive" : "statusPillInactive"}`,
            defaultRemittanceDisplay,
            defaultRemittanceListDisplay: defaultRemittanceName || "Not set",
            usedInFeePlans: Number(row.usedInFeePlans || 0),
            usedInProgrammeFees: Number(row.usedInProgrammeFees || 0),
            manualAssignments: Number(row.manualAssignments || 0),
            isChildText: row.isChild ? "Yes" : "No",
            parentFeeHeadName: row.parentFeeHeadName || "-",
            currencyIsoCode: row.currencyIsoCode || "-",
            ownerId: row.ownerId || "-",
            ownerName: row.ownerName || "-",
            recordTypeId: row.recordTypeId || "-",
            recordTypeName: row.recordTypeName || "-",
            createdById: row.createdById || "-",
            createdByName: row.createdByName || "-",
            createdDateOnly: row.createdDate ? this.formatDate(row.createdDate) : "-",
            createdDateText: row.createdDate
                ? new Date(row.createdDate).toLocaleString()
                : "-",
            lastModifiedById: row.lastModifiedById || "-",
            lastModifiedByName: row.lastModifiedByName || "-",
            lastModifiedRelative: row.lastModifiedDate
                ? this.formatRelativeDate(row.lastModifiedDate)
                : "-",
            lastModifiedText: row.lastModifiedDate
                ? new Date(row.lastModifiedDate).toLocaleString()
                : "-",
            isActionMenuOpen: row.id === this.openActionMenuFeeHeadId
        };
    }

    async loadFormOptions() {
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
    }

    formatDate(dateValue) {
        const dateObj = new Date(dateValue);
        if (Number.isNaN(dateObj.getTime())) {
            return "-";
        }
        return dateObj.toISOString().slice(0, 10);
    }

    formatRelativeDate(dateValue) {
        const dateObj = new Date(dateValue);
        if (Number.isNaN(dateObj.getTime())) {
            return "-";
        }

        const elapsedMs = Date.now() - dateObj.getTime();
        if (elapsedMs < 0) {
            return "just now";
        }

        const minutes = Math.floor(elapsedMs / 60000);
        if (minutes < 1) {
            return "just now";
        }
        if (minutes < 60) {
            return `${minutes} min ago`;
        }

        const hours = Math.floor(minutes / 60);
        if (hours < 24) {
            return `${hours} hour${hours === 1 ? "" : "s"} ago`;
        }

        const days = Math.floor(hours / 24);
        return `${days} day${days === 1 ? "" : "s"} ago`;
    }

    handleSearchChange(event) {
        this.searchText = event.target.value;
        this.applySearchFilter();
    }

    applySearchFilter() {
        const searchValue = (this.searchText || "").trim().toLowerCase();
        if (!searchValue) {
            this.filteredFeeHeads = this.feeHeads.map((row) => ({
                ...row,
                isActionMenuOpen: row.id === this.openActionMenuFeeHeadId
            }));
            return;
        }

        this.filteredFeeHeads = this.feeHeads
            .filter((row) => {
                const feeHeadName = (row.feeHeadName || "").toLowerCase();
                const feeHeadType = (row.feeHeadType || "").toLowerCase();
                const refundableLabel = (row.refundableLabel || "").toLowerCase();
                const taxableLabel = (row.taxableLabel || "").toLowerCase();
                const defaultRemittance = (row.defaultRemittanceListDisplay || "").toLowerCase();
                const activeLabel = (row.activeLabel || "").toLowerCase();

                return (
                    feeHeadName.includes(searchValue) ||
                    feeHeadType.includes(searchValue) ||
                    refundableLabel.includes(searchValue) ||
                    taxableLabel.includes(searchValue) ||
                    defaultRemittance.includes(searchValue) ||
                    activeLabel.includes(searchValue)
                );
            })
            .map((row) => ({
                ...row,
                isActionMenuOpen: row.id === this.openActionMenuFeeHeadId
            }));
    }

    get feeHeadCountText() {
        const total = this.feeHeads.length;
        return total === 1 ? "1 item" : `${total} items`;
    }

    get hasFeeHeads() {
        return this.filteredFeeHeads.length > 0;
    }

    get isFeeHeadDetailView() {
        return !!this.selectedFeeHeadId;
    }

    get isListView() {
        return !this.isFeeHeadDetailView && !this.isFormView;
    }

    get formPageTitle() {
        return this.isEditMode ? "Edit Fee Head" : "New Fee Head";
    }

    get isActivateDisabled() {
        return this.formIsSaving;
    }

    get selectedFeeHead() {
        if (!this.selectedFeeHeadId) {
            return null;
        }
        return this.feeHeads.find((row) => row.id === this.selectedFeeHeadId) || null;
    }

    handleOpenFeeHeadDetails(event) {
        const feeHeadId = event.currentTarget.dataset.feeHeadId;
        if (!feeHeadId) {
            return;
        }
        this.selectedFeeHeadId = feeHeadId;
        this.openActionMenuFeeHeadId = null;
        this.activeDetailTab = "details";
    }

    handleBackToFeeHeadList() {
        this.selectedFeeHeadId = null;
        this.openActionMenuFeeHeadId = null;
        this.isFormView = false;
        this.isEditMode = false;
        this.activeDetailTab = "details";
    }

    openNewFeeHeadModal() {
        this.resetForm();
        this.isFormView = true;
        this.isEditMode = false;
        this.selectedFeeHeadId = null;
    }

    handleToggleActionMenu(event) {
        event.preventDefault();
        event.stopPropagation();
        const feeHeadId = this.resolveFeeHeadId(event);
        if (!feeHeadId) {
            return;
        }
        this.openActionMenuFeeHeadId =
            this.openActionMenuFeeHeadId === feeHeadId ? null : feeHeadId;
        this.applySearchFilter();
    }

    handleActionClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const action = event.currentTarget.dataset.action;
        const feeHeadId = this.resolveFeeHeadId(event);
        this.openActionMenuFeeHeadId = null;
        this.applySearchFilter();

        if (action === "new") {
            this.openNewFeeHeadModal();
            return;
        }

        if (!feeHeadId) {
            return;
        }

        if (action === "view") {
            this.selectedFeeHeadId = feeHeadId;
            return;
        }
        if (action === "edit") {
            this.openEditFeeHeadPage(feeHeadId);
            return;
        }
        if (action === "delete") {
            this.handleDeleteFeeHead(feeHeadId);
        }
    }

    resolveFeeHeadId(event) {
        if (!event || !event.currentTarget || !event.currentTarget.dataset) {
            if (event && typeof event.composedPath === "function") {
                const source = event
                    .composedPath()
                    .find((node) => node && node.dataset && (node.dataset.feeHeadId || node.dataset.id));
                if (source && source.dataset) {
                    return source.dataset.feeHeadId || source.dataset.id || null;
                }
            }
            return null;
        }
        return (
            event.currentTarget.dataset.feeHeadId ||
            event.currentTarget.dataset.id ||
            null
        );
    }

    openEditFeeHeadPage(feeHeadId) {
        const row = this.feeHeads.find((item) => item.id === feeHeadId);
        if (!row) {
            this.showToast("Error", "Fee head not found.", "error");
            return;
        }
        const normalize = (value) => (value === "-" ? "" : value || "");
        this.resetForm();
        this.isFormView = true;
        this.isEditMode = true;
        this.selectedFeeHeadId = null;
        this.formFeeHeadId = row.id;
        this.formFeeHeadName = normalize(row.feeHeadName);
        this.formFeeHeadType = normalize(row.feeHeadType);
        this.formIsActive = row.isActive === true;
        this.formRefundable = row.refundable === true;
        this.formTaxable = row.taxable === true;
        this.formDefaultRemittanceAccountId = normalize(row.defaultRemittanceAccountId);
        this.formTaxDefinitionId = normalize(row.taxDefinitionId);
        this.formDescription = normalize(row.description);
        this.syncFormTaxPercentage();
    }

    handleDetailEdit() {
        if (!this.selectedFeeHeadId) {
            return;
        }
        this.openEditFeeHeadPage(this.selectedFeeHeadId);
    }

    handleDetailTabClick(event) {
        const tab = event.currentTarget.dataset.tab;
        if (!tab) {
            return;
        }
        this.activeDetailTab = tab;
    }

    get isDetailsTabActive() {
        return this.activeDetailTab === "details";
    }

    get isUsageTabActive() {
        return this.activeDetailTab === "usage";
    }

    tabClass(tabName) {
        return tabName === this.activeDetailTab ? "tab tabActive" : "tab";
    }

    get detailsTabClass() {
        return this.tabClass("details");
    }

    get usageTabClass() {
        return this.tabClass("usage");
    }

    async handleDeleteFeeHead(feeHeadId) {
        if (!feeHeadId) {
            return;
        }
        const feeHead = this.feeHeads.find((row) => row.id === feeHeadId);
        this.confirmDialog = {
            feeHeadId,
            title: "Delete Fee Head",
            message: feeHead
                ? `Delete "${feeHead.feeHeadName}"? This action cannot be undone.`
                : "Delete this fee head? This action cannot be undone."
        };
    }

    closeConfirmDialog() {
        this.confirmDialog = null;
    }

    async handleConfirmDelete() {
        const feeHeadId = this.confirmDialog?.feeHeadId;
        this.closeConfirmDialog();
        if (!feeHeadId) {
            return;
        }
        try {
            await deleteFeeHead({ feeHeadId });
            this.showToast("Success", "Fee head deleted.", "success");
            await this.loadData();
        } catch (error) {
            this.showToast("Error", this.getErrorMessage(error), "error");
        }
    }

    handleFormFieldChange(event) {
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
            this.formFeeHeadName = fieldValue;
        } else if (fieldName === "feeHeadType") {
            this.formFeeHeadType = fieldValue;
        } else if (fieldName === "isActive") {
            this.formIsActive = fieldValue;
        } else if (fieldName === "refundable") {
            this.formRefundable = fieldValue;
        } else if (fieldName === "taxable") {
            this.formTaxable = fieldValue;
        } else if (fieldName === "defaultRemittanceAccountId") {
            this.formDefaultRemittanceAccountId = fieldValue;
        } else if (fieldName === "taxDefinitionId") {
            this.formTaxDefinitionId = fieldValue;
            this.syncFormTaxPercentage();
        } else if (fieldName === "description") {
            this.formDescription = fieldValue;
        }
    }

    handleRecordPickerChange(event) {
        const fieldName = event.target?.name;
        const recordId = event.detail?.recordId || "";
        if (fieldName === "defaultRemittanceAccountId") {
            this.formDefaultRemittanceAccountId = recordId;
            return;
        }
        if (fieldName === "taxDefinitionId") {
            this.formTaxDefinitionId = recordId;
            this.syncFormTaxPercentage();
        }
    }

    syncFormTaxPercentage() {
        if (!this.formTaxDefinitionId) {
            this.formTaxPercentage = "";
            return;
        }
        const selectedTaxRate = this.taxRateByDefinitionId[this.formTaxDefinitionId];
        this.formTaxPercentage =
            selectedTaxRate === undefined || selectedTaxRate === null
                ? ""
                : `${selectedTaxRate}`;
    }

    async handleSaveDraft() {
        this.formIsActive = false;
        await this.handleFormSave({ isDraft: true });
    }

    async handleActivate() {
        this.formIsActive = true;
        await this.handleFormSave({ isDraft: false });
    }

    async handleFormSave({ isDraft = false } = {}) {
        const normalizedName = (this.formFeeHeadName || "").trim();
        if (!normalizedName) {
            this.showToast("Error", "Fee Head Name is required.", "error");
            return;
        }
        if (!this.formFeeHeadType) {
            this.showToast("Error", "Head Category is required.", "error");
            return;
        }
        const effectiveIsActive = isDraft ? false : this.formIsActive;
        this.formIsSaving = true;
        try {
            if (this.isEditMode) {
                await updateFeeHead({
                    feeHeadId: this.formFeeHeadId,
                    feeHeadName: normalizedName,
                    feeHeadType: this.formFeeHeadType,
                    isActive: effectiveIsActive,
                    refundable: this.formRefundable,
                    taxable: this.formTaxable,
                    defaultRemittanceAccountId: this.formDefaultRemittanceAccountId || null,
                    taxDefinitionId: this.formTaxDefinitionId || null,
                    description: this.formDescription
                });
                this.showToast("Success", "Fee Head updated.", "success");
            } else {
                await createFeeHead({
                    feeHeadName: normalizedName,
                    feeHeadType: this.formFeeHeadType,
                    isActive: effectiveIsActive,
                    refundable: this.formRefundable,
                    taxable: this.formTaxable,
                    defaultRemittanceAccountId: this.formDefaultRemittanceAccountId || null,
                    taxDefinitionId: this.formTaxDefinitionId || null,
                    description: this.formDescription
                });
                this.showToast("Success", "Fee Head created.", "success");
            }
            await this.loadData();
            this.isFormView = false;
            this.isEditMode = false;
            this.selectedFeeHeadId = null;
            this.resetForm();
        } catch (error) {
            this.showToast("Error", this.getErrorMessage(error), "error");
        } finally {
            this.formIsSaving = false;
        }
    }

    handleFormCancel() {
        this.isFormView = false;
        this.isEditMode = false;
        this.resetForm();
    }

    resetForm() {
        this.formFeeHeadId = null;
        this.formFeeHeadName = "";
        this.formFeeHeadType = "";
        this.formIsActive = true;
        this.formRefundable = false;
        this.formTaxable = false;
        this.formDefaultRemittanceAccountId = "";
        this.formTaxDefinitionId = "";
        this.formTaxPercentage = "";
        this.formDescription = "";
    }

    navigateToMasterData() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__masterDataLanding" }
        });
    }

    dismissNotification() {
        this.notification = null;
    }

    showToast(title, message, variant) {
        const normalizedVariant = variant === "success" ? "success" : variant === "warning" ? "warning" : "error";
        this.notification = {
            title,
            message,
            variant: normalizedVariant,
            containerClass: `noticeBanner noticeBanner${normalizedVariant.charAt(0).toUpperCase()}${normalizedVariant.slice(1)}`,
            iconName:
                normalizedVariant === "success"
                    ? "utility:success"
                    : normalizedVariant === "warning"
                      ? "utility:warning"
                      : "utility:error"
        };
    }

    getErrorMessage(error) {
        if (error && error.body) {
            if (typeof error.body.message === "string" && error.body.message) {
                return error.body.message;
            }
            if (Array.isArray(error.body.pageErrors) && error.body.pageErrors.length) {
                return error.body.pageErrors[0].message || "Unexpected error occurred.";
            }
            if (Array.isArray(error.body.fieldErrors)) {
                const first = error.body.fieldErrors.find((entry) => Array.isArray(entry) && entry.length);
                if (first && first[0] && first[0].message) {
                    return first[0].message;
                }
            }
        }
        return "Unexpected error occurred.";
    }
}