import { LightningElement, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import getPaymentGateways from "@salesforce/apex/PaymentGatewaysController.getPaymentGateways";
import getProviderOptions from "@salesforce/apex/PaymentGatewaysController.getProviderOptions";
import getMerchantCredentialOptions from "@salesforce/apex/PaymentGatewaysController.getMerchantCredentialOptions";
import getStatusOptions from "@salesforce/apex/PaymentGatewaysController.getStatusOptions";
import getEnvironmentOptions from "@salesforce/apex/PaymentGatewaysController.getEnvironmentOptions";
import createPaymentGateway from "@salesforce/apex/PaymentGatewaysController.createPaymentGateway";
import updatePaymentGateway from "@salesforce/apex/PaymentGatewaysController.updatePaymentGateway";
import deletePaymentGateway from "@salesforce/apex/PaymentGatewaysController.deletePaymentGateway";

export default class PaymentGatewaysManager extends NavigationMixin(LightningElement) {
    @track isLoading = false;
    @track paymentGateways = [];
    @track filteredPaymentGateways = [];
    @track notification = null;
    @track confirmDialog = null;
    @track searchText = "";
    @track selectedGatewayScope = "all";
    @track providerOptions = [];
    @track merchantCredentialOptions = [];
    @track statusOptions = [];
    @track environmentOptions = [];
    @track selectedPaymentGatewayId = null;
    @track openActionMenuGatewayId = null;
    @track isFormView = false;
    @track isEditMode = false;
    @track formIsSaving = false;

    @track formRecordId = null;
    @track formPaymentGatewayProviderId = null;
    @track formProviderSearchText = "";
    @track isProviderDropdownOpen = false;
    @track formPaymentGatewayName = "";
    @track formGatewayDisplayName = "";
    @track formStatus = "";
    @track formEnvironment = "";
    @track formExternalReference = "";
    @track formMerchantCredentialId = null;
    @track formMerchantCredentialSearchText = "";
    @track isMerchantCredentialDropdownOpen = false;
    @track formComments = "";

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        this.isLoading = true;
        try {
            const [gatewayRows, providerRows, credentialRows, statusRows, environmentRows] = await Promise.all([
                getPaymentGateways(),
                getProviderOptions(),
                getMerchantCredentialOptions(),
                getStatusOptions(),
                getEnvironmentOptions()
            ]);

            this.paymentGateways = (Array.isArray(gatewayRows) ? gatewayRows : []).map((row) =>
                this.mapPaymentGatewayRow(row)
            );

            if (this.selectedPaymentGatewayId) {
                const exists = this.paymentGateways.some((row) => row.id === this.selectedPaymentGatewayId);
                if (!exists) {
                    this.selectedPaymentGatewayId = null;
                }
            }
            if (this.openActionMenuGatewayId) {
                const hasActionRow = this.paymentGateways.some((row) => row.id === this.openActionMenuGatewayId);
                if (!hasActionRow) {
                    this.openActionMenuGatewayId = null;
                }
            }

            this.providerOptions = this.mapOptions(providerRows);
            this.merchantCredentialOptions = this.mapOptions(credentialRows);
            this.statusOptions = this.mapOptions(statusRows);
            this.environmentOptions = this.mapOptions(environmentRows);
            this.applySearchFilter();
        } catch (error) {
            this.showToast("Error", this.getErrorMessage(error), "error");
        } finally {
            this.isLoading = false;
        }
    }

    mapOptions(rows) {
        return (Array.isArray(rows) ? rows : []).map((row) => ({
            label: row.label,
            value: row.value
        }));
    }

    mapPaymentGatewayRow(row) {
        const statusValue = (row.status || "").toLowerCase();
        const isActive = statusValue === "active";
        const environmentValue = row.environment || "";
        const displayName = row.gatewayDisplayName || row.paymentGatewayName || "-";
        const providerName = row.paymentGatewayProviderName || "-";
        const merchantCredentialName = row.merchantCredentialName || "-";

        return {
            ...row,
            paymentGatewayName: row.paymentGatewayName || "-",
            gatewayDisplayName: displayName,
            paymentGatewayProviderName: providerName,
            paymentGatewayProviderUrl:
                row.paymentGatewayProviderId && providerName !== "-"
                    ? `/${row.paymentGatewayProviderId}`
                    : "",
            externalReference: row.externalReference || "-",
            merchantCredentialName: merchantCredentialName,
            merchantCredentialUrl:
                row.merchantCredentialId && merchantCredentialName !== "-"
                    ? `/${row.merchantCredentialId}`
                    : "",
            environment: environmentValue || "-",
            environmentClass: environmentValue ? this.getEnvironmentClass(environmentValue) : "",
            status: row.status || "-",
            statusClass: isActive ? "statusPill statusActive" : "statusPill statusInactive",
            comments: row.comments || "-",
            lastModifiedText: row.lastModifiedDate
                ? new Date(row.lastModifiedDate).toLocaleDateString()
                : "-",
            lastModifiedRelative: row.lastModifiedDate
                ? this.formatRelativeDate(row.lastModifiedDate)
                : "-",
            isActionMenuOpen: row.id === this.openActionMenuGatewayId,
            actionsCellClass: row.id === this.openActionMenuGatewayId ? "actionsCell actionsCellOpen" : "actionsCell"
        };
    }

    getEnvironmentClass(value) {
        const normalized = (value || "").toLowerCase();
        if (normalized === "production") {
            return "envPill envPillProduction";
        }
        if (normalized === "sandbox") {
            return "envPill envPillSandbox";
        }
        return "envPill envPillDefault";
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
        const scopedRows = this.paymentGateways.filter((row) => this.matchesSelectedScope(row));

        if (!searchValue) {
            this.filteredPaymentGateways = scopedRows.map((row) => ({
                ...row,
                isActionMenuOpen: row.id === this.openActionMenuGatewayId,
                actionsCellClass: row.id === this.openActionMenuGatewayId ? "actionsCell actionsCellOpen" : "actionsCell"
            }));
            return;
        }

        this.filteredPaymentGateways = scopedRows
            .filter((row) => {
                const gatewayName = (row.paymentGatewayName || "").toLowerCase();
                const gatewayDisplayName = (row.gatewayDisplayName || "").toLowerCase();
                const providerName = (row.paymentGatewayProviderName || "").toLowerCase();
                const externalReference = (row.externalReference || "").toLowerCase();
                const merchantCredentialName = (row.merchantCredentialName || "").toLowerCase();
                const environment = (row.environment || "").toLowerCase();
                const status = (row.status || "").toLowerCase();
                const comments = (row.comments || "").toLowerCase();

                return (
                    gatewayName.includes(searchValue) ||
                    gatewayDisplayName.includes(searchValue) ||
                    providerName.includes(searchValue) ||
                    externalReference.includes(searchValue) ||
                    merchantCredentialName.includes(searchValue) ||
                    environment.includes(searchValue) ||
                    status.includes(searchValue) ||
                    comments.includes(searchValue)
                );
            })
            .map((row) => ({
                ...row,
                isActionMenuOpen: row.id === this.openActionMenuGatewayId,
                actionsCellClass: row.id === this.openActionMenuGatewayId ? "actionsCell actionsCellOpen" : "actionsCell"
            }));
    }

    matchesSelectedScope(row) {
        const normalizedStatus = (row.status || "").toLowerCase();
        if (this.selectedGatewayScope === "active") {
            return normalizedStatus === "active";
        }
        if (this.selectedGatewayScope === "inactive") {
            return normalizedStatus === "inactive";
        }
        return true;
    }

    handleGatewayScopeSelect(event) {
        const selectedValue = event?.detail?.value;
        if (!selectedValue || !["all", "active", "inactive"].includes(selectedValue)) {
            return;
        }
        this.selectedGatewayScope = selectedValue;
        this.openActionMenuGatewayId = null;
        this.applySearchFilter();
    }

    get gatewayScopeLabel() {
        if (this.selectedGatewayScope === "active") {
            return "Active Gateways";
        }
        if (this.selectedGatewayScope === "inactive") {
            return "Inactive Gateways";
        }
        return "All Gateways";
    }

    get isScopeAll() {
        return this.selectedGatewayScope === "all";
    }

    get isScopeActive() {
        return this.selectedGatewayScope === "active";
    }

    get isScopeInactive() {
        return this.selectedGatewayScope === "inactive";
    }

    get gatewayCountText() {
        const total = this.paymentGateways.length;
        return total === 1 ? "1 item" : `${total} items`;
    }

    get hasPaymentGateways() {
        return this.filteredPaymentGateways.length > 0;
    }

    get isPaymentGatewayDetailView() {
        return !!this.selectedPaymentGatewayId;
    }

    get isListView() {
        return !this.isPaymentGatewayDetailView && !this.isFormView;
    }

    get formPageTitle() {
        return this.isEditMode ? "Edit Payment Gateway" : "New Payment Gateway";
    }

    get formSaveLabel() {
        return this.isEditMode ? "Save Changes" : "Save";
    }

    get filteredProviderOptions() {
        return this.filterOptions(
            this.providerOptions,
            this.providerFilterText
        );
    }

    get filteredMerchantCredentialOptions() {
        return this.filterOptions(
            this.merchantCredentialOptions,
            this.merchantCredentialFilterText
        );
    }

    get providerFilterText() {
        const selectedLabel = this.getOptionLabelByValue(
            this.providerOptions,
            this.formPaymentGatewayProviderId
        );
        if (
            this.isProviderDropdownOpen &&
            this.formPaymentGatewayProviderId &&
            this.formProviderSearchText === selectedLabel
        ) {
            return "";
        }
        return this.formProviderSearchText;
    }

    get merchantCredentialFilterText() {
        const selectedLabel = this.getOptionLabelByValue(
            this.merchantCredentialOptions,
            this.formMerchantCredentialId
        );
        if (
            this.isMerchantCredentialDropdownOpen &&
            this.formMerchantCredentialId &&
            this.formMerchantCredentialSearchText === selectedLabel
        ) {
            return "";
        }
        return this.formMerchantCredentialSearchText;
    }

    get filteredProviderOptionRows() {
        return this.filteredProviderOptions.map((option) => ({
            ...option,
            optionClass:
                option.value === this.formPaymentGatewayProviderId
                    ? "searchableOption searchableOptionSelected"
                    : "searchableOption"
        }));
    }

    get filteredMerchantCredentialOptionRows() {
        return this.filteredMerchantCredentialOptions.map((option) => ({
            ...option,
            optionClass:
                option.value === this.formMerchantCredentialId
                    ? "searchableOption searchableOptionSelected"
                    : "searchableOption"
        }));
    }

    get hasFilteredProviderOptions() {
        return this.filteredProviderOptionRows.length > 0;
    }

    get hasFilteredMerchantCredentialOptions() {
        return this.filteredMerchantCredentialOptionRows.length > 0;
    }

    get selectedPaymentGateway() {
        if (!this.selectedPaymentGatewayId) {
            return null;
        }
        return this.paymentGateways.find((row) => row.id === this.selectedPaymentGatewayId) || null;
    }

    handleOpenPaymentGatewayDetails(event) {
        const gatewayId = event.currentTarget.dataset.gatewayId;
        if (!gatewayId) {
            return;
        }
        this.selectedPaymentGatewayId = gatewayId;
        this.openActionMenuGatewayId = null;
        this.isFormView = false;
        this.isEditMode = false;
    }

    handleBackToPaymentGatewayList() {
        this.selectedPaymentGatewayId = null;
        this.openActionMenuGatewayId = null;
        this.isFormView = false;
        this.isEditMode = false;
    }

    handleDetailEdit() {
        if (!this.selectedPaymentGatewayId) {
            return;
        }
        this.openEditGatewayPage(this.selectedPaymentGatewayId);
    }

    handleDetailClone() {
        if (!this.selectedPaymentGatewayId) {
            return;
        }
        this.openCloneGatewayPage(this.selectedPaymentGatewayId);
    }

    async deleteGateway(gatewayId, successMessage) {
        if (!gatewayId) {
            return;
        }
        try {
            await deletePaymentGateway({ paymentGatewayId: gatewayId });
            if (this.selectedPaymentGatewayId === gatewayId) {
                this.selectedPaymentGatewayId = null;
            }
            this.notification = null;
            this.showToast("Success", successMessage || "Payment gateway deleted.", "success");
            await this.loadData();
        } catch (error) {
            this.showNotification("Error", this.getErrorMessage(error), "error");
        } finally {
            this.confirmDialog = null;
        }
    }

    handleDetailDelete() {
        this.openDeleteConfirmDialog(this.selectedPaymentGatewayId);
    }

    handleToggleActionMenu(event) {
        const gatewayId = event.currentTarget.dataset.gatewayId;
        if (!gatewayId) {
            return;
        }
        this.openActionMenuGatewayId =
            this.openActionMenuGatewayId === gatewayId ? null : gatewayId;
        this.applySearchFilter();
    }

    handleRowAction(event) {
        const gatewayId = event.currentTarget.dataset.gatewayId;
        const action = event.currentTarget.dataset.action;
        this.openActionMenuGatewayId = null;
        this.applySearchFilter();

        if (!gatewayId || !action) {
            return;
        }

        if (action === "view") {
            this.selectedPaymentGatewayId = gatewayId;
            this.isFormView = false;
            this.isEditMode = false;
            return;
        }

        if (action === "edit") {
            this.openEditGatewayPage(gatewayId);
            return;
        }

        if (action === "delete") {
            this.openDeleteConfirmDialog(gatewayId);
        }
    }

    openEditGatewayPage(gatewayId) {
        const row = this.paymentGateways.find((item) => item.id === gatewayId);
        if (!row) {
            this.showToast("Error", "Payment gateway not found.", "error");
            return;
        }

        const normalize = (value) => (value === "-" ? "" : value || "");
        this.resetForm();
        this.isEditMode = true;
        this.isFormView = true;
        this.selectedPaymentGatewayId = null;
        this.openActionMenuGatewayId = null;
        this.formRecordId = row.id;
        this.formPaymentGatewayProviderId = row.paymentGatewayProviderId || null;
        this.formProviderSearchText = this.getOptionLabelByValue(
            this.providerOptions,
            this.formPaymentGatewayProviderId
        );
        this.isProviderDropdownOpen = false;
        this.formPaymentGatewayName = normalize(row.paymentGatewayName);
        this.formGatewayDisplayName = normalize(row.gatewayDisplayName);
        this.formStatus = normalize(row.status) || (this.statusOptions[0] ? this.statusOptions[0].value : "");
        this.formEnvironment = normalize(row.environment);
        this.formExternalReference = normalize(row.externalReference);
        this.formMerchantCredentialId = row.merchantCredentialId || null;
        this.formMerchantCredentialSearchText = this.getOptionLabelByValue(
            this.merchantCredentialOptions,
            this.formMerchantCredentialId
        );
        this.isMerchantCredentialDropdownOpen = false;
        this.formComments = normalize(row.comments);
    }

    openCloneGatewayPage(gatewayId) {
        const row = this.paymentGateways.find((item) => item.id === gatewayId);
        if (!row) {
            this.showToast("Error", "Payment gateway not found.", "error");
            return;
        }

        const normalize = (value) => (value === "-" ? "" : value || "");
        this.resetForm();
        this.isEditMode = false;
        this.isFormView = true;
        this.selectedPaymentGatewayId = null;
        this.openActionMenuGatewayId = null;
        const sourceName = normalize(row.paymentGatewayName);
        const sourceDisplayName = normalize(row.gatewayDisplayName);
        this.formPaymentGatewayProviderId = row.paymentGatewayProviderId || null;
        this.formProviderSearchText = this.getOptionLabelByValue(
            this.providerOptions,
            this.formPaymentGatewayProviderId
        );
        this.isProviderDropdownOpen = false;
        this.formPaymentGatewayName = sourceName ? `${sourceName} Copy` : "";
        this.formGatewayDisplayName = sourceDisplayName ? `${sourceDisplayName} Copy` : "";
        this.formStatus = normalize(row.status) || (this.statusOptions[0] ? this.statusOptions[0].value : "");
        this.formEnvironment = normalize(row.environment);
        this.formExternalReference = normalize(row.externalReference);
        this.formMerchantCredentialId = row.merchantCredentialId || null;
        this.formMerchantCredentialSearchText = this.getOptionLabelByValue(
            this.merchantCredentialOptions,
            this.formMerchantCredentialId
        );
        this.isMerchantCredentialDropdownOpen = false;
        this.formComments = normalize(row.comments);
    }

    resetForm() {
        this.formRecordId = null;
        this.formPaymentGatewayProviderId = null;
        this.formProviderSearchText = "";
        this.isProviderDropdownOpen = false;
        this.formPaymentGatewayName = "";
        this.formGatewayDisplayName = "";
        this.formStatus = this.statusOptions[0] ? this.statusOptions[0].value : "";
        this.formEnvironment = this.environmentOptions[0] ? this.environmentOptions[0].value : "";
        this.formExternalReference = "";
        this.formMerchantCredentialId = null;
        this.formMerchantCredentialSearchText = "";
        this.isMerchantCredentialDropdownOpen = false;
        this.formComments = "";
        this.formIsSaving = false;
    }

    openNewGatewayModal() {
        this.resetForm();
        this.isEditMode = false;
        this.isFormView = true;
        this.selectedPaymentGatewayId = null;
        this.openActionMenuGatewayId = null;
    }

    handleFormFieldChange(event) {
        const fieldName = event.target.name;
        const fieldValue =
            event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;

        if (fieldName === "paymentGatewayName") {
            this.formPaymentGatewayName = fieldValue;
        } else if (fieldName === "gatewayDisplayName") {
            this.formGatewayDisplayName = fieldValue;
        } else if (fieldName === "status") {
            this.formStatus = fieldValue;
        } else if (fieldName === "environment") {
            this.formEnvironment = fieldValue;
        } else if (fieldName === "externalReference") {
            this.formExternalReference = fieldValue;
        } else if (fieldName === "comments") {
            this.formComments = fieldValue;
        }
    }

    handleProviderInput(event) {
        this.formProviderSearchText = event.target.value || "";
        this.formPaymentGatewayProviderId = null;
        this.isProviderDropdownOpen = true;
    }

    handleProviderFocus() {
        this.isProviderDropdownOpen = true;
    }

    handleProviderBlur() {
        window.setTimeout(() => {
            this.isProviderDropdownOpen = false;
        }, 150);
    }

    handleProviderOptionSelect(event) {
        const selectedValue = event.currentTarget.dataset.value;
        const selectedLabel = event.currentTarget.dataset.label || "";
        this.formPaymentGatewayProviderId = selectedValue || null;
        this.formProviderSearchText = selectedLabel;
        this.isProviderDropdownOpen = false;
    }

    handleMerchantCredentialInput(event) {
        this.formMerchantCredentialSearchText = event.target.value || "";
        this.formMerchantCredentialId = null;
        this.isMerchantCredentialDropdownOpen = true;
    }

    handleMerchantCredentialFocus() {
        this.isMerchantCredentialDropdownOpen = true;
    }

    handleMerchantCredentialBlur() {
        window.setTimeout(() => {
            this.isMerchantCredentialDropdownOpen = false;
        }, 150);
    }

    handleMerchantCredentialOptionSelect(event) {
        const selectedValue = event.currentTarget.dataset.value;
        const selectedLabel = event.currentTarget.dataset.label || "";
        this.formMerchantCredentialId = selectedValue || null;
        this.formMerchantCredentialSearchText = selectedLabel;
        this.isMerchantCredentialDropdownOpen = false;
    }

    filterOptions(options, searchText) {
        const rows = Array.isArray(options) ? options : [];
        const normalizedSearch = (searchText || "").trim().toLowerCase();
        if (!normalizedSearch) {
            return rows;
        }

        return rows.filter((row) =>
            (row.label || "").toLowerCase().includes(normalizedSearch)
        );
    }

    getOptionLabelByValue(options, selectedValue) {
        if (!selectedValue) {
            return "";
        }
        const selectedRow = (Array.isArray(options) ? options : []).find(
            (row) => row.value === selectedValue
        );
        return selectedRow ? selectedRow.label || "" : "";
    }

    async handleFormSave() {
        const gatewayNameInput = this.template.querySelector('[data-id="paymentGatewayName"]');
        const gatewayDisplayNameInput = this.template.querySelector('[data-id="gatewayDisplayName"]');
        const statusInput = this.template.querySelector('[data-id="status"]');
        const externalReferenceInput = this.template.querySelector('[data-id="externalReference"]');

        const normalizedName = (this.formPaymentGatewayName || "").trim();
        if (!normalizedName) {
            gatewayNameInput?.reportValidity?.();
            this.showToast("Error", "Payment Gateway Name is required.", "error");
            return;
        }

        const normalizedDisplayName = (this.formGatewayDisplayName || "").trim();
        if (!normalizedDisplayName) {
            gatewayDisplayNameInput?.reportValidity?.();
            this.showToast("Error", "Gateway Display Name is required.", "error");
            return;
        }

        const normalizedStatus = (this.formStatus || "").trim();
        if (!normalizedStatus) {
            statusInput?.reportValidity?.();
            this.showToast("Error", "Status is required.", "error");
            return;
        }

        const normalizedExternalReference = (this.formExternalReference || "").trim();
        if (!normalizedExternalReference) {
            externalReferenceInput?.reportValidity?.();
            this.showToast("Error", "External Reference is required.", "error");
            return;
        }

        this.formIsSaving = true;
        try {
            if (this.isEditMode) {
                await updatePaymentGateway({
                    paymentGatewayId: this.formRecordId,
                    paymentGatewayProviderId: this.formPaymentGatewayProviderId,
                    paymentGatewayName: normalizedName,
                    gatewayDisplayName: normalizedDisplayName,
                    status: normalizedStatus,
                    environment: this.formEnvironment || null,
                    externalReference: normalizedExternalReference,
                    merchantCredentialId: this.formMerchantCredentialId,
                    comments: (this.formComments || "").trim() || null
                });
                this.showToast("Success", "Payment gateway updated.", "success");
            } else {
                await createPaymentGateway({
                    paymentGatewayProviderId: this.formPaymentGatewayProviderId,
                    paymentGatewayName: normalizedName,
                    gatewayDisplayName: normalizedDisplayName,
                    status: normalizedStatus,
                    environment: this.formEnvironment || null,
                    externalReference: normalizedExternalReference,
                    merchantCredentialId: this.formMerchantCredentialId,
                    comments: (this.formComments || "").trim() || null
                });
                this.showToast("Success", "Payment gateway created.", "success");
            }

            await this.loadData();
            this.isFormView = false;
            this.isEditMode = false;
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

    handleFilterClick() {
        this.showToast("Info", "Filter options will be added here.", "info");
    }

    openDeleteConfirmDialog(gatewayId) {
        if (!gatewayId) {
            return;
        }
        const gateway = this.paymentGateways.find((row) => row.id === gatewayId);
        this.confirmDialog = {
            recordId: gatewayId,
            title: "Delete Payment Gateway",
            message: `Delete ${gateway?.gatewayDisplayName || gateway?.paymentGatewayName || "this payment gateway"}?`,
            confirmLabel: "Delete Payment Gateway"
        };
    }

    closeConfirmDialog() {
        this.confirmDialog = null;
    }

    async handleConfirmDelete() {
        const gatewayId = this.confirmDialog?.recordId;
        if (!gatewayId) {
            this.confirmDialog = null;
            return;
        }
        await this.deleteGateway(gatewayId, "Payment gateway deleted.");
    }

    handleNotificationDismiss() {
        this.notification = null;
    }

    navigateToMasterData() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__masterDataLanding" }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    showNotification(title, message, variant = "error") {
        this.notification = {
            title,
            message,
            variant,
            className: variant === "error" ? "notificationBanner notificationBannerError" : "notificationBanner"
        };
    }

    getErrorMessage(error) {
        if (!error) {
            return "Unexpected error occurred.";
        }
        if (typeof error === "string") {
            return error;
        }

        const { body } = error;
        if (Array.isArray(body) && body.length && body[0] && body[0].message) {
            return body[0].message;
        }
        if (body && body.message) {
            return body.message;
        }
        if (body && body.output) {
            if (Array.isArray(body.output.errors) && body.output.errors.length && body.output.errors[0].message) {
                return body.output.errors[0].message;
            }
            const fieldErrors = body.output.fieldErrors || {};
            for (const fieldName of Object.keys(fieldErrors)) {
                const entries = fieldErrors[fieldName];
                if (Array.isArray(entries) && entries.length && entries[0].message) {
                    return entries[0].message;
                }
            }
        }
        if (error.message) {
            return error.message;
        }
        return "Unexpected error occurred.";
    }
}