import { LightningElement, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import getRemittanceAccounts from "@salesforce/apex/RemittanceAccountsController.getRemittanceAccounts";
import getLinkedEntityOptions from "@salesforce/apex/RemittanceAccountsController.getLinkedEntityOptions";
import getCurrencyOptions from "@salesforce/apex/RemittanceAccountsController.getCurrencyOptions";
import createRemittanceAccountV2 from "@salesforce/apex/RemittanceAccountsController.createRemittanceAccountV2";
import updateRemittanceAccount from "@salesforce/apex/RemittanceAccountsController.updateRemittanceAccount";
import deleteRemittanceAccount from "@salesforce/apex/RemittanceAccountsController.deleteRemittanceAccount";
import getRemittanceGatewayLinks from "@salesforce/apex/RemittanceAccountsController.getRemittanceGatewayLinks";
import searchPaymentGateways from "@salesforce/apex/RemittanceAccountsController.searchPaymentGateways";
import upsertRemittanceGatewayLink from "@salesforce/apex/RemittanceAccountsController.upsertRemittanceGatewayLink";
import deleteRemittanceGatewayLink from "@salesforce/apex/RemittanceAccountsController.deleteRemittanceGatewayLink";

export default class RemittanceAccountsManager extends NavigationMixin(LightningElement) {
    @track isLoading = false;
    @track remittanceAccounts = [];
    @track filteredRemittanceAccounts = [];
    @track notification = null;
    @track confirmDialog = null;
    @track searchText = "";
    @track selectedRemittanceAccountId = null;
    @track openActionMenuAccountId = null;
    @track isFormView = false;
    @track isEditMode = false;
    @track formLinkedEntityOptions = [];
    @track formSelectedLinkedEntityIds = [];
    @track formIsSaving = false;
    @track formIsLoadingLinkedEntities = false;
    @track activeDetailTab = "details";

    @track formRecordId = null;
    @track formAccountName = "";
    @track formBankName = "";
    @track formAccountNumber = "";
    @track formLedgerCode = "";
    @track formCurrencyIsoCode = "";
    @track currencyOptions = [];
    @track formLinkedLevel = "";
    @track formIsActive = true;
    @track gatewayLinks = [];
    @track gatewayLinksLoading = false;
    @track formGatewayLinks = [];
    @track openActionMenuFormGatewayLinkKey = null;
    @track gatewaySearchText = "";
    @track gatewaySearchResults = [];
    @track isGatewaySearching = false;
    @track selectedGatewayId = null;
    @track selectedGatewayLabel = "";
    @track newLinkParentMerchantId = "";
    @track newLinkSubMerchantId = "";
    @track newLinkIsActive = true;
    @track isSavingGatewayLink = false;
    @track editingGatewayLinkId = null;
    @track openActionMenuGatewayLinkId = null;

    gatewaySearchTimeout;

    linkedLevelOptions = [
        { label: "Institute Level", value: "Institute Level" },
        { label: "Program Level", value: "Program Level" },
        { label: "Fee Head Level", value: "Fee Head Level" }
    ];

    connectedCallback() {
        this.loadData();
        this.loadCurrencyOptions();
    }

    disconnectedCallback() {
        if (this.gatewaySearchTimeout) {
            window.clearTimeout(this.gatewaySearchTimeout);
            this.gatewaySearchTimeout = null;
        }
    }

    async loadData() {
        this.isLoading = true;
        try {
            const accountRows = await getRemittanceAccounts();

            this.remittanceAccounts = (Array.isArray(accountRows) ? accountRows : []).map((row) =>
                this.mapAccountRow(row)
            );
            if (this.selectedRemittanceAccountId) {
                const exists = this.remittanceAccounts.some((row) => row.id === this.selectedRemittanceAccountId);
                if (!exists) {
                    this.selectedRemittanceAccountId = null;
                    this.gatewayLinks = [];
                } else {
                    await this.loadGatewayLinks();
                }
            }
            this.applySearchFilter();
        } catch (error) {
            this.showToast("Error", this.getErrorMessage(error), "error");
        } finally {
            this.isLoading = false;
        }
    }

    async loadCurrencyOptions() {
        try {
            const rows = await getCurrencyOptions();
            this.currencyOptions = (Array.isArray(rows) ? rows : []).map((row) => ({
                label: row.label,
                value: row.value,
                isDefault: row.isDefault === true
            }));
            if (!this.formCurrencyIsoCode) {
                this.formCurrencyIsoCode = this.getDefaultCurrencyIsoCode();
            }
        } catch (error) {
            this.currencyOptions = [];
            this.showToast("Error", this.getErrorMessage(error), "error");
        }
    }

    getDefaultCurrencyIsoCode() {
        const defaultOption = this.currencyOptions.find((option) => option.isDefault === true);
        if (defaultOption) {
            return defaultOption.value;
        }
        return this.currencyOptions.length ? this.currencyOptions[0].value : "";
    }

    mapAccountRow(row) {
        const isActive = row.isActive === true;
        const bankName = row.bankName || row.bankAccountName || "-";
        const accountNumber = row.accountNumber || "-";
        const listAccountName = row.bankAccountName || row.name || "-";
        const detailHeaderTitle =
            bankName !== "-" && accountNumber !== "-"
                ? `${bankName} - ${accountNumber}`
                : bankName !== "-"
                  ? bankName
                  : accountNumber;
        return {
            ...row,
            name: row.name || "-",
            bankAccountName: row.bankAccountName || "-",
            listAccountName,
            bankName,
            accountNumber,
            ledgerCode: row.ledgerCode || "-",
            parentMerchantId: row.parentMerchantId || "-",
            merchantId1: row.merchantId1 || "",
            merchantId2: row.merchantId2 || "",
            merchantId3: row.merchantId3 || "",
            detailHeaderTitle,
            accountType: row.accountType || "-",
            address: row.address || "-",
            currencyIsoCode: row.currencyIsoCode || "-",
            ownerId: row.ownerId || "-",
            ownerName: row.ownerName || "-",
            createdById: row.createdById || "-",
            createdByName: row.createdByName || "-",
            createdDateOnly: row.createdDate ? this.formatDate(row.createdDate) : "-",
            createdDateText: row.createdDate
                ? new Date(row.createdDate).toLocaleString()
                : "-",
            lastModifiedById: row.lastModifiedById || "-",
            lastModifiedByName: row.lastModifiedByName || "-",
            statusText: isActive ? "Active" : "Inactive",
            statusClass: isActive ? "statusPill statusActive" : "statusPill statusInactive",
            lastModifiedRelative: row.lastModifiedDate
                ? this.formatRelativeDate(row.lastModifiedDate)
                : "-",
            lastModifiedText: row.lastModifiedDate
                ? new Date(row.lastModifiedDate).toLocaleString()
                : "-",
            isActionMenuOpen: row.id === this.openActionMenuAccountId,
            actionsCellClass: row.id === this.openActionMenuAccountId ? "actionsCell actionsCellOpen" : "actionsCell"
        };
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
        if (days >= 7) {
            const weeks = Math.floor(days / 7);
            return `${weeks} week${weeks === 1 ? "" : "s"} ago`;
        }
        return `${days} day${days === 1 ? "" : "s"} ago`;
    }

    handleSearchChange(event) {
        this.searchText = event.target.value;
        this.applySearchFilter();
    }

    applySearchFilter() {
        const searchValue = (this.searchText || "").trim().toLowerCase();
        if (!searchValue) {
            this.filteredRemittanceAccounts = this.remittanceAccounts.map((row) => ({
                ...row,
                isActionMenuOpen: row.id === this.openActionMenuAccountId,
                actionsCellClass: row.id === this.openActionMenuAccountId ? "actionsCell actionsCellOpen" : "actionsCell"
            }));
            return;
        }

        this.filteredRemittanceAccounts = this.remittanceAccounts
            .filter((row) => {
                const listAccountName = (row.listAccountName || "").toLowerCase();
                const bankName = (row.bankName || "").toLowerCase();
                const accountNumber = (row.accountNumber || "").toLowerCase();
                const ledgerCode = (row.ledgerCode || "").toLowerCase();
                const statusText = (row.statusText || "").toLowerCase();

                return (
                    listAccountName.includes(searchValue) ||
                    bankName.includes(searchValue) ||
                    accountNumber.includes(searchValue) ||
                    ledgerCode.includes(searchValue) ||
                    statusText.includes(searchValue)
                );
            })
            .map((row) => ({
                ...row,
                isActionMenuOpen: row.id === this.openActionMenuAccountId,
                actionsCellClass: row.id === this.openActionMenuAccountId ? "actionsCell actionsCellOpen" : "actionsCell"
            }));
    }

    get remittanceAccountCountText() {
        const total = this.remittanceAccounts.length;
        return total === 1 ? "1 account" : `${total} accounts`;
    }

    get hasRemittanceAccounts() {
        return this.filteredRemittanceAccounts.length > 0;
    }

    get isRemittanceAccountDetailView() {
        return !!this.selectedRemittanceAccountId;
    }

    get isListView() {
        return !this.isRemittanceAccountDetailView && !this.isFormView;
    }

    get formPageTitle() {
        return this.isEditMode ? "Edit Remittance Account" : "New Remittance Account";
    }

    get formSaveLabel() {
        return this.isEditMode ? "Save Changes" : "Save";
    }

    get linkedEntityLabel() {
        if (this.formLinkedLevel === "Institute Level") {
            return "Institutes";
        }
        if (this.formLinkedLevel === "Program Level") {
            return "Programs";
        }
        if (this.formLinkedLevel === "Fee Head Level") {
            return "Fee Heads";
        }
        return "Linked Records";
    }

    get linkedEntityPlaceholder() {
        if (this.formLinkedLevel === "Institute Level") {
            return "Select institutes";
        }
        if (this.formLinkedLevel === "Program Level") {
            return "Select programs";
        }
        if (this.formLinkedLevel === "Fee Head Level") {
            return "Select fee heads";
        }
        return "Select records";
    }

    get isLinkedEntityDisabled() {
        return !this.formLinkedLevel || this.formIsLoadingLinkedEntities || this.isEditMode;
    }

    get selectedRemittanceAccount() {
        if (!this.selectedRemittanceAccountId) {
            return null;
        }
        return this.remittanceAccounts.find((row) => row.id === this.selectedRemittanceAccountId) || null;
    }

    get hasGatewayLinks() {
        return this.gatewayLinks.length > 0;
    }

    get hasGatewaySearchResults() {
        return this.gatewaySearchResults.length > 0;
    }

    get showGatewaySearchDropdown() {
        const hasSearchInput = (this.gatewaySearchText || "").trim().length > 0;
        return hasSearchInput && (this.isGatewaySearching || this.hasGatewaySearchResults || !this.selectedGatewayId);
    }

    get gatewaySaveLabel() {
        return this.editingGatewayLinkId ? "Update Gateway Link" : "Add Gateway Link";
    }

    get isDetailInfoTab() {
        return this.activeDetailTab === "details";
    }

    get isPaymentGatewayTab() {
        return this.activeDetailTab === "paymentGateway";
    }

    get detailsTabClass() {
        return this.isDetailInfoTab ? "tab tabActive" : "tab";
    }

    get paymentGatewayTabClass() {
        return this.isPaymentGatewayTab ? "tab tabActive" : "tab";
    }

    get hasFormGatewayLinks() {
        return this.formGatewayLinks.length > 0;
    }

    handleOpenRemittanceAccountDetails(event) {
        const accountId = event.currentTarget.dataset.accountId;
        if (!accountId) {
            return;
        }
        this.selectedRemittanceAccountId = accountId;
        this.openActionMenuAccountId = null;
        this.activeDetailTab = "details";
        this.loadGatewayLinks();
        this.resetGatewayLinkDraft();
    }

    handleBackToAccountList() {
        this.selectedRemittanceAccountId = null;
        this.openActionMenuAccountId = null;
        this.isFormView = false;
        this.isEditMode = false;
        this.gatewayLinks = [];
        this.formGatewayLinks = [];
        this.resetGatewayLinkDraft();
    }

    handleDetailEdit() {
        if (!this.selectedRemittanceAccountId) {
            return;
        }
        this.openEditAccountPage(this.selectedRemittanceAccountId);
    }

    openCloneAccountPage(accountId) {
        const row = this.remittanceAccounts.find((item) => item.id === accountId);
        if (!row) {
            this.showToast("Error", "Remittance account not found.", "error");
            return;
        }

        const normalize = (value) => (value === "-" ? "" : value || "");
        this.resetForm();
        this.isEditMode = false;
        this.isFormView = true;
        this.selectedRemittanceAccountId = null;
        this.openActionMenuAccountId = null;

        const sourceAccountName = normalize(row.bankAccountName) || normalize(row.name);
        this.formAccountName = sourceAccountName ? `${sourceAccountName} Copy` : "";
        this.formBankName = normalize(row.bankName);
        this.formAccountNumber = normalize(row.accountNumber);
        this.formLedgerCode = normalize(row.ledgerCode);
        this.formCurrencyIsoCode = normalize(row.currencyIsoCode) || this.getDefaultCurrencyIsoCode();
        this.formIsActive = row.isActive === true;

        const linkedLevelValue = normalize(row.accountType);
        const hasLinkedLevel = this.linkedLevelOptions.some((option) => option.value === linkedLevelValue);
        this.formLinkedLevel = hasLinkedLevel ? linkedLevelValue : "";

        if (this.formLinkedLevel) {
            this.loadFormLinkedEntityOptions();
        }
    }

    handleDetailClone() {
        if (!this.selectedRemittanceAccountId) {
            return;
        }
        this.openCloneAccountPage(this.selectedRemittanceAccountId);
    }

    async deleteAccount(accountId, successMessage) {
        if (!accountId) {
            return;
        }
        try {
            await deleteRemittanceAccount({ remittanceAccountId: accountId });
            if (this.selectedRemittanceAccountId === accountId) {
                this.selectedRemittanceAccountId = null;
            }
            this.notification = null;
            this.showToast("Success", successMessage || "Remittance account deleted.", "success");
            await this.loadData();
        } catch (error) {
            this.showNotification("Error", this.getErrorMessage(error), "error");
        } finally {
            this.confirmDialog = null;
        }
    }

    handleDetailDelete() {
        this.openConfirmDialog(
            "deleteAccount",
            this.selectedRemittanceAccountId,
            "Delete Remittance Account",
            "Delete this remittance account?",
            "Delete Remittance Account"
        );
    }

    handleToggleActionMenu(event) {
        const accountId = event.currentTarget.dataset.accountId;
        if (!accountId) {
            return;
        }
        this.openActionMenuAccountId =
            this.openActionMenuAccountId === accountId ? null : accountId;
        this.applySearchFilter();
    }

    async handleRowAction(event) {
        const accountId = event.currentTarget.dataset.accountId;
        const action = event.currentTarget.dataset.action;
        this.openActionMenuAccountId = null;
        this.applySearchFilter();

        if (!accountId || !action) {
            return;
        }

        if (action === "view") {
            this.selectedRemittanceAccountId = accountId;
            this.loadGatewayLinks();
            this.resetGatewayLinkDraft();
            return;
        }

        if (action === "edit") {
            this.openEditAccountPage(accountId);
            return;
        }

        if (action === "delete") {
            this.openConfirmDialog(
                "deleteAccount",
                accountId,
                "Delete Remittance Account",
                "Delete this remittance account?",
                "Delete Remittance Account"
            );
        }
    }

    openNewAccountModal() {
        this.resetForm();
        this.selectedRemittanceAccountId = null;
        this.isEditMode = false;
        this.isFormView = true;
        this.formGatewayLinks = [];
    }

    openEditAccountPage(accountId) {
        const row = this.remittanceAccounts.find((item) => item.id === accountId);
        if (!row) {
            this.showToast("Error", "Remittance account not found.", "error");
            return;
        }
        const normalize = (value) => (value === "-" ? "" : value || "");
        this.resetForm();
        this.isEditMode = true;
        this.isFormView = true;
        this.selectedRemittanceAccountId = null;
        this.formRecordId = row.id;
        this.formAccountName = normalize(row.bankAccountName) || normalize(row.name);
        this.formBankName = normalize(row.bankName);
        this.formAccountNumber = normalize(row.accountNumber);
        this.formLedgerCode = normalize(row.ledgerCode);
        this.formCurrencyIsoCode = normalize(row.currencyIsoCode) || this.getDefaultCurrencyIsoCode();
        this.formIsActive = row.isActive === true;
    }

    async loadGatewayLinks() {
        if (!this.selectedRemittanceAccountId) {
            this.gatewayLinks = [];
            return;
        }
        this.gatewayLinksLoading = true;
        try {
            const rows = await getRemittanceGatewayLinks({
                remittanceAccountId: this.selectedRemittanceAccountId
            });
            this.gatewayLinks = (Array.isArray(rows) ? rows : []).map((row) => {
                const isActive = row.isActive === true;
                return {
                    ...row,
                    gatewayName: row.paymentGatewayName || row.gatewayDisplayName || "Payment Gateway",
                    parentMerchantId: row.parentMerchantId || "-",
                    subMerchantId: row.subMerchantId || "-",
                    statusText: isActive ? "Active" : "Inactive",
                    statusClass: isActive ? "statusPill statusActive" : "statusPill statusInactive",
                    isActionMenuOpen: row.id === this.openActionMenuGatewayLinkId,
                    actionsCellClass: row.id === this.openActionMenuGatewayLinkId ? "actionsCell actionsCellOpen" : "actionsCell"
                };
            });
        } catch (error) {
            this.gatewayLinks = [];
            this.showNotification("Error", this.getErrorMessage(error), "error");
        } finally {
            this.gatewayLinksLoading = false;
        }
    }

    resetGatewayLinkDraft() {
        this.gatewaySearchText = "";
        this.gatewaySearchResults = [];
        this.isGatewaySearching = false;
        this.selectedGatewayId = null;
        this.selectedGatewayLabel = "";
        this.newLinkParentMerchantId = "";
        this.newLinkSubMerchantId = "";
        this.newLinkIsActive = true;
        this.editingGatewayLinkId = null;
        this.openActionMenuGatewayLinkId = null;
        if (this.gatewaySearchTimeout) {
            window.clearTimeout(this.gatewaySearchTimeout);
            this.gatewaySearchTimeout = null;
        }
    }

    handleGatewaySearchInput(event) {
        this.gatewaySearchText = event.target.value || "";
        this.selectedGatewayId = null;
        this.selectedGatewayLabel = "";
        const searchText = this.gatewaySearchText.trim();
        if (this.gatewaySearchTimeout) {
            window.clearTimeout(this.gatewaySearchTimeout);
            this.gatewaySearchTimeout = null;
        }

        if (!searchText) {
            this.gatewaySearchResults = [];
            this.isGatewaySearching = false;
            this.selectedGatewayId = null;
            this.selectedGatewayLabel = "";
            return;
        }

        this.gatewaySearchTimeout = window.setTimeout(() => {
            this.searchGatewayOptions(searchText);
        }, 250);
    }

    async searchGatewayOptions(searchText) {
        this.isGatewaySearching = true;
        try {
            const rows = await searchPaymentGateways({
                searchTerm: searchText,
                limitSize: 20
            });
            this.gatewaySearchResults = Array.isArray(rows)
                ? rows.map((row) => ({
                    label: row.label,
                    value: row.value
                }))
                : [];
        } catch (error) {
            this.gatewaySearchResults = [];
            this.showToast("Error", this.getErrorMessage(error), "error");
        } finally {
            this.isGatewaySearching = false;
        }
    }

    async handleSelectGatewayOption(event) {
        const gatewayId = event.currentTarget.dataset.gatewayId;
        if (!gatewayId) {
            return;
        }
        const selectedOption = this.gatewaySearchResults.find((option) => option.value === gatewayId);
        this.selectedGatewayId = gatewayId;
        this.selectedGatewayLabel = selectedOption ? selectedOption.label : "";
        this.gatewaySearchText = selectedOption ? selectedOption.label : this.gatewaySearchText;
        this.gatewaySearchResults = [];
        this.isGatewaySearching = false;
        this.newLinkParentMerchantId = "";
        this.newLinkSubMerchantId = "";
    }

    handleGatewayDraftFieldChange(event) {
        const fieldName = event.target.name;
        const fieldValue =
            event.target.type === "checkbox"
                ? event.target.checked
                : event.detail && event.detail.value !== undefined
                  ? event.detail.value
                  : event.target.value;

        if (fieldName === "newLinkParentMerchantId") {
            this.newLinkParentMerchantId = fieldValue;
        } else if (fieldName === "newLinkSubMerchantId") {
            this.newLinkSubMerchantId = fieldValue;
        } else if (fieldName === "newLinkIsActive") {
            this.newLinkIsActive = fieldValue;
        }
    }

    async handleSaveGatewayLink() {
        if (!this.selectedGatewayId) {
            this.showToast("Error", "Select a payment gateway.", "error");
            return;
        }

        if (this.isFormView && !this.isEditMode) {
            this.upsertFormGatewayLinkDraft();
            this.resetGatewayLinkDraft();
            return;
        }

        const remittanceAccountId = this.selectedRemittanceAccountId || this.formRecordId;
        if (!remittanceAccountId) {
            this.showToast("Error", "Select a remittance account first.", "error");
            return;
        }

        this.isSavingGatewayLink = true;
        try {
            await upsertRemittanceGatewayLink({
                remittanceGatewayLinkId: this.editingGatewayLinkId,
                remittanceAccountId,
                paymentGatewayId: this.selectedGatewayId,
                parentMerchantId: (this.newLinkParentMerchantId || "").trim() || null,
                subMerchantId: (this.newLinkSubMerchantId || "").trim() || null,
                isActive: this.newLinkIsActive
            });
            this.showToast("Success", this.editingGatewayLinkId ? "Gateway link updated." : "Gateway link added.", "success");
            await this.loadData();
            this.resetGatewayLinkDraft();
        } catch (error) {
            this.showToast("Error", this.getErrorMessage(error), "error");
        } finally {
            this.isSavingGatewayLink = false;
        }
    }

    async handleDeleteGatewayLink(event) {
        const linkId = event.currentTarget.dataset.linkId;
        await this.deleteGatewayLinkById(linkId);
    }

    async deleteGatewayLinkById(linkId) {
        if (!linkId) {
            return;
        }
        if (this.isFormView && !this.isEditMode) {
            this.formGatewayLinks = this.formGatewayLinks.filter((row) => row.key !== linkId);
            this.resetGatewayLinkDraft();
            return;
        }
        try {
            await deleteRemittanceGatewayLink({ remittanceGatewayLinkId: linkId });
            this.notification = null;
            this.showToast("Success", "Gateway link deleted.", "success");
            await this.loadData();
            this.resetGatewayLinkDraft();
        } catch (error) {
            this.showNotification("Error", this.getErrorMessage(error), "error");
        } finally {
            this.confirmDialog = null;
        }
    }

    handleToggleGatewayActionMenu(event) {
        const linkId = event.currentTarget.dataset.linkId;
        if (!linkId) {
            return;
        }
        this.openActionMenuGatewayLinkId =
            this.openActionMenuGatewayLinkId === linkId ? null : linkId;
        this.gatewayLinks = this.gatewayLinks.map((row) => ({
            ...row,
            isActionMenuOpen: row.id === this.openActionMenuGatewayLinkId,
            actionsCellClass: row.id === this.openActionMenuGatewayLinkId ? "actionsCell actionsCellOpen" : "actionsCell"
        }));
    }

    async handleGatewayRowAction(event) {
        const linkId = event.currentTarget.dataset.linkId;
        const action = event.currentTarget.dataset.action;
        this.openActionMenuGatewayLinkId = null;
        this.gatewayLinks = this.gatewayLinks.map((row) => ({
            ...row,
            isActionMenuOpen: false,
            actionsCellClass: "actionsCell"
        }));

        if (!linkId || !action) {
            return;
        }
        const row = this.gatewayLinks.find((item) => item.id === linkId);
        if (!row) {
            return;
        }

        if (action === "view") {
            this.openGatewayRecordById(row.paymentGatewayId);
            return;
        }
        if (action === "edit") {
            this.editingGatewayLinkId = row.id;
            this.selectedGatewayId = row.paymentGatewayId;
            this.selectedGatewayLabel = row.gatewayName;
            this.gatewaySearchText = row.gatewayName;
            this.newLinkParentMerchantId = row.parentMerchantId === "-" ? "" : row.parentMerchantId;
            this.newLinkSubMerchantId = row.subMerchantId === "-" ? "" : row.subMerchantId;
            this.newLinkIsActive = row.isActive === true;
            this.gatewaySearchResults = [];
            return;
        }
        if (action === "delete") {
            this.openConfirmDialog(
                "deleteGatewayLink",
                row.id,
                "Delete Payment Gateway Assignment",
                "Delete this payment gateway assignment?",
                "Delete Assignment"
            );
        }
    }

    handleToggleFormGatewayActionMenu(event) {
        const rowKey = event.currentTarget.dataset.linkId;
        if (!rowKey) {
            return;
        }
        this.openActionMenuFormGatewayLinkKey =
            this.openActionMenuFormGatewayLinkKey === rowKey ? null : rowKey;
        this.formGatewayLinks = this.formGatewayLinks.map((row) => ({
            ...row,
            isActionMenuOpen: row.key === this.openActionMenuFormGatewayLinkKey,
            actionsCellClass: row.key === this.openActionMenuFormGatewayLinkKey ? "actionsCell actionsCellOpen" : "actionsCell"
        }));
    }

    async handleFormGatewayRowAction(event) {
        const rowKey = event.currentTarget.dataset.linkId;
        const action = event.currentTarget.dataset.action;
        this.openActionMenuFormGatewayLinkKey = null;
        this.formGatewayLinks = this.formGatewayLinks.map((row) => ({
            ...row,
            isActionMenuOpen: false,
            actionsCellClass: "actionsCell"
        }));
        if (!rowKey || !action) {
            return;
        }
        const row = this.formGatewayLinks.find((item) => item.key === rowKey);
        if (!row) {
            return;
        }
        if (action === "view") {
            this.openGatewayRecordById(row.paymentGatewayId);
            return;
        }
        if (action === "edit") {
            this.editingGatewayLinkId = row.key;
            this.selectedGatewayId = row.paymentGatewayId;
            this.selectedGatewayLabel = row.gatewayName;
            this.gatewaySearchText = row.gatewayName;
            this.newLinkParentMerchantId = row.parentMerchantId === "-" ? "" : row.parentMerchantId;
            this.newLinkSubMerchantId = row.subMerchantId === "-" ? "" : row.subMerchantId;
            this.newLinkIsActive = row.isActive === true;
            return;
        }
        if (action === "delete") {
            this.openConfirmDialog(
                "deleteGatewayLinkDraft",
                row.key,
                "Delete Payment Gateway Assignment",
                "Delete this payment gateway assignment?",
                "Delete Assignment"
            );
        }
    }

    upsertFormGatewayLinkDraft() {
        const linkKey = this.editingGatewayLinkId || `tmp_${Date.now()}`;
        const draftRow = {
            key: linkKey,
            paymentGatewayId: this.selectedGatewayId,
            gatewayName: this.selectedGatewayLabel || this.gatewaySearchText || "Payment Gateway",
            parentMerchantId: (this.newLinkParentMerchantId || "").trim() || "-",
            subMerchantId: (this.newLinkSubMerchantId || "").trim() || "-",
            isActive: this.newLinkIsActive,
            statusText: this.newLinkIsActive ? "Active" : "Inactive",
            statusClass: this.newLinkIsActive ? "statusPill statusActive" : "statusPill statusInactive",
            isActionMenuOpen: false,
            actionsCellClass: "actionsCell"
        };
        let updatedRows = [];
        let hasUpdated = false;
        for (const row of this.formGatewayLinks) {
            if (row.key === linkKey) {
                updatedRows.push(draftRow);
                hasUpdated = true;
            } else {
                updatedRows.push(row);
            }
        }
        if (!hasUpdated) {
            updatedRows.push(draftRow);
        }
        this.formGatewayLinks = updatedRows;
        this.showToast("Success", this.editingGatewayLinkId ? "Gateway link updated." : "Gateway link added.", "success");
    }

    async saveFormGatewayLinks(remittanceAccountId) {
        if (!remittanceAccountId || !this.formGatewayLinks.length) {
            return;
        }
        for (const row of this.formGatewayLinks) {
            await upsertRemittanceGatewayLink({
                remittanceGatewayLinkId: null,
                remittanceAccountId,
                paymentGatewayId: row.paymentGatewayId,
                parentMerchantId: row.parentMerchantId === "-" ? null : row.parentMerchantId,
                subMerchantId: row.subMerchantId === "-" ? null : row.subMerchantId,
                isActive: row.isActive
            });
        }
    }

    handleOpenGatewayRecord(event) {
        const gatewayId = event.currentTarget.dataset.gatewayId;
        this.openGatewayRecordById(gatewayId);
    }

    openGatewayRecordById(gatewayId) {
        if (!gatewayId) {
            return;
        }
        window.open(`/${gatewayId}`, "_blank");
    }

    resetForm() {
        this.formRecordId = null;
        this.formAccountName = "";
        this.formBankName = "";
        this.formAccountNumber = "";
        this.formLedgerCode = "";
        this.formCurrencyIsoCode = this.getDefaultCurrencyIsoCode();
        this.formLinkedLevel = "";
        this.formSelectedLinkedEntityIds = [];
        this.formLinkedEntityOptions = [];
        this.formIsActive = true;
        this.formIsSaving = false;
        this.formIsLoadingLinkedEntities = false;
        this.formGatewayLinks = [];
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

        if (fieldName === "accountName") {
            this.formAccountName = fieldValue;
        } else if (fieldName === "bankName") {
            this.formBankName = fieldValue;
        } else if (fieldName === "accountNumber") {
            this.formAccountNumber = fieldValue;
        } else if (fieldName === "ledgerCode") {
            this.formLedgerCode = fieldValue;
        } else if (fieldName === "currencyIsoCode") {
            this.formCurrencyIsoCode = fieldValue;
        } else if (fieldName === "isActive") {
            this.formIsActive = fieldValue;
        } else if (fieldName === "linkedLevel") {
            this.formLinkedLevel = fieldValue;
            this.formSelectedLinkedEntityIds = [];
            this.loadFormLinkedEntityOptions();
        } else if (fieldName === "linkedEntityIds") {
            this.formSelectedLinkedEntityIds = Array.isArray(fieldValue) ? fieldValue : [];
        }
    }

    async loadFormLinkedEntityOptions() {
        if (!this.formLinkedLevel) {
            this.formLinkedEntityOptions = [];
            return;
        }
        this.formIsLoadingLinkedEntities = true;
        try {
            const rows = await getLinkedEntityOptions({ linkedLevel: this.formLinkedLevel });
            this.formLinkedEntityOptions = (Array.isArray(rows) ? rows : []).map((row) => ({
                label: row.label,
                value: row.value
            }));
        } catch (error) {
            this.formLinkedEntityOptions = [];
            this.showToast("Error", this.getErrorMessage(error), "error");
        } finally {
            this.formIsLoadingLinkedEntities = false;
        }
    }

    async handleFormSave() {
        const normalizedAccountName = (this.formAccountName || "").trim();
        const normalizedBankName = (this.formBankName || "").trim();
        const normalizedAccountNumber = (this.formAccountNumber || "").trim();
        const normalizedLedgerCode = (this.formLedgerCode || "").trim();
        const normalizedCurrencyIsoCode = (this.formCurrencyIsoCode || "").trim();

        if (!normalizedAccountName) {
            this.showToast("Error", "Account Name is required.", "error");
            return;
        }
        if (!normalizedBankName) {
            this.showToast("Error", "Bank is required.", "error");
            return;
        }
        if (!normalizedAccountNumber) {
            this.showToast("Error", "Account Number is required.", "error");
            return;
        }
        if (!normalizedLedgerCode) {
            this.showToast("Error", "Ledger Code is required.", "error");
            return;
        }
        if (!normalizedCurrencyIsoCode) {
            this.showToast("Error", "Currency is required.", "error");
            return;
        }
        if (!this.isEditMode && !this.formLinkedLevel) {
            this.showToast("Error", "Linked Level is required.", "error");
            return;
        }

        this.formIsSaving = true;
        try {
            if (this.isEditMode) {
                await updateRemittanceAccount({
                    remittanceAccountId: this.formRecordId,
                    accountName: normalizedAccountName,
                    bankName: normalizedBankName,
                    accountNumber: normalizedAccountNumber,
                    ledgerCode: normalizedLedgerCode,
                    merchantId1: null,
                    merchantId2: null,
                    merchantId3: null,
                    parentMerchantId: null,
                    isActive: this.formIsActive,
                    currencyIsoCode: normalizedCurrencyIsoCode
                });
                this.showToast("Success", "Remittance account updated.", "success");
            } else {
                const createdAccountId = await createRemittanceAccountV2({
                    accountName: normalizedAccountName,
                    bankName: normalizedBankName,
                    accountNumber: normalizedAccountNumber,
                    ledgerCode: normalizedLedgerCode,
                    linkedLevel: this.formLinkedLevel,
                    linkedEntityIds: this.formSelectedLinkedEntityIds,
                    merchantId1: null,
                    merchantId2: null,
                    merchantId3: null,
                    isActive: this.formIsActive,
                    parentMerchantId: null,
                    currencyIsoCode: normalizedCurrencyIsoCode
                });
                await this.saveFormGatewayLinks(createdAccountId);
                this.showToast("Success", "Remittance account created.", "success");
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
        this.resetGatewayLinkDraft();
        this.resetForm();
    }

    handleSwitchDetailTab(event) {
        const tabName = event.currentTarget.dataset.tab;
        this.activeDetailTab = tabName === "paymentGateway" ? "paymentGateway" : "details";
        if (this.activeDetailTab === "paymentGateway" && this.selectedRemittanceAccountId) {
            this.loadGatewayLinks();
        }
    }

    openConfirmDialog(type, recordId, title, message, confirmLabel) {
        if (!recordId) {
            return;
        }
        this.confirmDialog = {
            type,
            recordId,
            title,
            message,
            confirmLabel
        };
    }

    closeConfirmDialog() {
        this.confirmDialog = null;
    }

    async handleConfirmDelete() {
        const type = this.confirmDialog?.type;
        const recordId = this.confirmDialog?.recordId;
        if (!type || !recordId) {
            this.confirmDialog = null;
            return;
        }

        if (type === "deleteGatewayLink") {
            await this.deleteGatewayLinkById(recordId);
            return;
        }
        if (type === "deleteGatewayLinkDraft") {
            this.formGatewayLinks = this.formGatewayLinks.filter((row) => row.key !== recordId);
            this.resetGatewayLinkDraft();
            this.confirmDialog = null;
            return;
        }
        if (type === "deleteAccount") {
            await this.deleteAccount(recordId, "Remittance account deleted.");
        }
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