import { LightningElement, track, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LightningConfirm from "lightning/confirm";

import getCategoriesWithQuotas from "@salesforce/apex/QuotaCategoryController.getCategoriesWithQuotas";
import getCategoryWithQuotas from "@salesforce/apex/QuotaCategoryController.getCategoryWithQuotas";
import getCategoryTypeOptions from "@salesforce/apex/QuotaCategoryController.getCategoryTypeOptions";
import deleteCategory from "@salesforce/apex/QuotaCategoryController.deleteCategory";
import deleteQuota from "@salesforce/apex/QuotaCategoryController.deleteQuota";

import CategoryModal from "c/categoryModal";
import QuotaModal from "c/quotaModal";

export default class QuotaCategoryManager extends NavigationMixin(LightningElement) {
    @track isLoading = false;
    @track categories = [];
    @track filteredCategories = [];
    @track searchText = "";
    @track selectedCategoryId = null;
    @track selectedDetailTab = "details";
    @track selectedCategoryData = null;
    @track openCategoryMenuId = null;
    @track openQuotaMenuKey = null;
    currentPageReference;
    lastUrlStateSignature = null;

    connectedCallback() {
        this.loadData();
    }

    @wire(CurrentPageReference)
    async handleCurrentPageReference(pageRef) {
        this.currentPageReference = pageRef;
        const nextCategoryId = pageRef?.state?.c__categoryId || null;
        const requestedTab = String(pageRef?.state?.c__tab || "").toLowerCase();
        const nextTab = requestedTab === "related" ? "related" : "details";
        const stateSignature = `${nextCategoryId || ""}:${nextTab}`;

        if (stateSignature === this.lastUrlStateSignature) {
            return;
        }

        this.lastUrlStateSignature = stateSignature;
        this.selectedCategoryId = nextCategoryId;
        this.selectedDetailTab = nextTab;
        this.selectedCategoryData = null;
        this.closeAllActionMenus();

        if (this.selectedCategoryId) {
            await this.loadSelectedCategoryWithQuotas(this.selectedCategoryId);
        }
    }

    async loadData() {
        this.isLoading = true;
        try {
            const rows = await getCategoriesWithQuotas();
            const safeRows = Array.isArray(rows) ? rows : [];
            this.categories = safeRows.map((row, index) => this.mapCategoryRow(row, index));
            if (this.selectedCategoryId) {
                const exists = this.categories.some((row) => row.categoryId === this.selectedCategoryId);
                if (!exists) {
                    this.selectedCategoryId = null;
                    this.selectedDetailTab = "details";
                    this.selectedCategoryData = null;
                    this.updatePageState();
                } else {
                    await this.loadSelectedCategoryWithQuotas(this.selectedCategoryId);
                }
            }
            this.applySearchFilter();
        } catch (error) {
            this.showToast("Error", this.getErrorMessage(error), "error");
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.loadData();
    }

    handleSearchChange(event) {
        this.searchText = event.target.value;
        this.applySearchFilter();
    }

    handlePageClick() {
        this.closeAllActionMenus();
    }

    handleMenuContainerClick(event) {
        event.stopPropagation();
    }

    handleToggleCategory(event) {
        const categoryId = event.currentTarget.dataset.categoryId;
        if (!categoryId) {
            return;
        }
        this.categories = this.categories.map((row) =>
            row.categoryId === categoryId
                ? {
                      ...row,
                      isExpanded: !row.isExpanded,
                      toggleIconName: row.isExpanded ? "utility:chevronright" : "utility:chevrondown"
                  }
                : row
        );
        this.applySearchFilter();
    }

    handleFilterClick() {
        this.showToast("Info", "Filter options will be added here.", "info");
    }

    async handleOpenCategoryDetails(event) {
        const categoryId = event.currentTarget.dataset.categoryId;
        if (!categoryId) {
            return;
        }
        this.selectedCategoryId = categoryId;
        this.selectedDetailTab = "details";
        this.updatePageState();
        await this.loadSelectedCategoryWithQuotas(categoryId);
    }

    handleBackToCategoryList() {
        this.selectedCategoryId = null;
        this.selectedDetailTab = "details";
        this.selectedCategoryData = null;
        this.updatePageState();
    }

    async handleDetailTabClick(event) {
        const tab = event.currentTarget.dataset.tab;
        if (!tab) {
            return;
        }
        this.selectedDetailTab = tab;
        this.updatePageState();
        if (this.selectedCategoryId && tab === "related") {
            await this.loadSelectedCategoryWithQuotas(this.selectedCategoryId);
        }
    }

    applySearchFilter() {
        const searchValue = (this.searchText || "").trim().toLowerCase();

        if (!searchValue) {
            this.filteredCategories = this.categories;
            return;
        }

        const matched = [];
        for (const categoryRow of this.categories) {
            const categoryName = (categoryRow.categoryName || "").toLowerCase();
            const categoryType = (categoryRow.categoryType || "").toLowerCase();
            const regulatorySource = (categoryRow.regulatorySource || "").toLowerCase();

            let isMatch =
                categoryName.includes(searchValue) ||
                categoryType.includes(searchValue) ||
                regulatorySource.includes(searchValue);

            if (!isMatch && Array.isArray(categoryRow.quotas)) {
                for (const quotaRow of categoryRow.quotas) {
                    const quotaName = (quotaRow.quotaName || "").toLowerCase();
                    const quotaCode = (quotaRow.code || "").toLowerCase();
                    const quotaMatches = quotaName.includes(searchValue) || quotaCode.includes(searchValue);
                    isMatch = isMatch || quotaMatches;
                }
            }

            if (isMatch) {
                matched.push(categoryRow);
            }
        }

        this.filteredCategories = matched;
    }

    get categoryCountText() {
        const total = this.categories.length;
        if (total === 1) {
            return "1 category";
        }
        return `${total} categories`;
    }

    get isCategoryDetailView() {
        return !!this.selectedCategoryId;
    }

    get selectedCategory() {
        if (!this.selectedCategoryId) {
            return null;
        }
        if (this.selectedCategoryData && this.selectedCategoryData.categoryId === this.selectedCategoryId) {
            return this.selectedCategoryData;
        }
        return this.categories.find((row) => row.categoryId === this.selectedCategoryId) || null;
    }

    get isDetailsTab() {
        return this.selectedDetailTab === "details";
    }

    get isRelatedTab() {
        return this.selectedDetailTab === "related";
    }

    get detailsTabClass() {
        return this.isDetailsTab ? "tabButton activeTab" : "tabButton";
    }

    get relatedTabClass() {
        return this.isRelatedTab ? "tabButton activeTab" : "tabButton";
    }

    mapCategoryRow(row, index) {
        const quotas = Array.isArray(row.quotas)
            ? row.quotas.map((q) => ({
                  ...q,
                  reservationPercentText:
                      q.reservationPercent === null || q.reservationPercent === undefined ? "—" : `${q.reservationPercent}%`,
                  lastUpdatedText: q.lastUpdated ? new Date(q.lastUpdated).toLocaleString() : "—",
                  activeText: q.isActive ? "Active" : "Inactive",
                  activeClass: q.isActive ? "statusPill statusActive" : "statusPill statusInactive",
                  isQuotaMenuOpen: false,
                  quotaMenuCellClass: "menuCell"
              }))
            : [];

        const isExpanded = index === 0;
        return {
            ...row,
            currencyCode: row.currencyCode || "-",
            createdByName: row.createdByName || "System Admin",
            createdDateText: row.createdDate ? this.formatDate(row.createdDate) : "—",
            lastUpdatedText: row.lastUpdated ? new Date(row.lastUpdated).toLocaleString() : "—",
            activeText: row.isActive ? "Active" : "Inactive",
            activeClass: row.isActive ? "statusPill statusActive" : "statusPill statusInactive",
            quotaCountText: row.quotaCount === null || row.quotaCount === undefined ? "0" : String(row.quotaCount),
            quotas,
            isCategoryMenuOpen: false,
            isExpanded,
            toggleIconName: isExpanded ? "utility:chevrondown" : "utility:chevronright"
        };
    }

    formatDate(dateValue) {
        const dt = new Date(dateValue);
        if (Number.isNaN(dt.getTime())) {
            return "—";
        }
        const year = dt.getFullYear();
        const month = `${dt.getMonth() + 1}`.padStart(2, "0");
        const day = `${dt.getDate()}`.padStart(2, "0");
        return `${year}-${month}-${day}`;
    }

    async loadSelectedCategoryWithQuotas(categoryId) {
        if (!categoryId) {
            this.selectedCategoryData = null;
            return;
        }
        try {
            const row = await getCategoryWithQuotas({ categoryId });
            this.selectedCategoryData = row ? this.mapCategoryRow(row, 0) : null;
        } catch (error) {
            this.selectedCategoryData = null;
            this.showToast("Error", this.getErrorMessage(error), "error");
        }
    }

    async openNewCategoryModal() {
        await this.openCategoryModalWithOptions({
            categoryId: null,
            categoryName: "",
            categoryType: "",
            regulatorySource: "",
            isActive: true
        });
    }

    handleNewCategoryPage() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__quotaCategoryBuilderPage" }
        });
    }

    async openCategoryModalWithOptions(categoryData) {
        let categoryTypeOptions = [];
        try {
            const values = await getCategoryTypeOptions();
            categoryTypeOptions = (Array.isArray(values) ? values : []).map((value) => ({ label: value, value }));
        } catch (_error) {
            categoryTypeOptions = this.getCategoryTypeOptionsFromRows();
            this.showToast("Warning", "Using existing category types as fallback.", "warning");
        }

        const result = await CategoryModal.open({
            size: "small",
            description: categoryData && categoryData.categoryId ? "Edit Category" : "Create Category",
            categoryId: categoryData.categoryId,
            categoryName: categoryData.categoryName,
            categoryType: categoryData.categoryType,
            regulatorySource: categoryData.regulatorySource,
            isActive: categoryData.isActive,
            categoryTypeOptions
        });

        if (result === "saved") {
            await this.loadData();
        }
    }

    getCategoryTypeOptionsFromRows() {
        const values = new Set();
        for (const row of this.categories) {
            const value = (row && row.categoryType ? row.categoryType : "").trim();
            if (value) {
                values.add(value);
            }
        }
        return Array.from(values).map((value) => ({ label: value, value }));
    }

    async openNewQuotaModal(event) {
        const categoryId = event.currentTarget.dataset.categoryId;
        await this.openQuotaModalWithOptions({
            quotaId: null,
            categoryId,
            quotaName: "",
            code: "",
            reservationPercent: null,
            priorityOrder: null,
            isActive: true
        });
    }

    async openQuotaModalWithOptions(quotaData) {
        const result = await QuotaModal.open({
            size: "small",
            description: quotaData && quotaData.quotaId ? "Edit Quota" : "Create Quota",
            quotaId: quotaData.quotaId,
            categoryId: quotaData.categoryId,
            quotaName: quotaData.quotaName,
            code: quotaData.code,
            reservationPercent: quotaData.reservationPercent,
            priorityOrder: quotaData.priorityOrder,
            isActive: quotaData.isActive
        });

        if (result === "saved") {
            await this.loadData();
        }
    }

    handleCategoryActionButtonClick(event) {
        event.stopPropagation();
        const categoryId = event.currentTarget.dataset.categoryId;
        if (!categoryId) {
            return;
        }
        this.openQuotaMenuKey = null;
        this.openCategoryMenuId = this.openCategoryMenuId === categoryId ? null : categoryId;
        this.syncMenuState();
    }

    handleQuotaActionButtonClick(event) {
        event.stopPropagation();
        const categoryId = event.currentTarget.dataset.categoryId;
        const quotaId = event.currentTarget.dataset.quotaId;
        if (!categoryId || !quotaId) {
            return;
        }
        const key = `${categoryId}:${quotaId}`;
        this.openCategoryMenuId = null;
        this.openQuotaMenuKey = this.openQuotaMenuKey === key ? null : key;
        this.syncMenuState();
    }

    async handleCategoryActionClick(event) {
        event.stopPropagation();
        const action = event.currentTarget.dataset.action;
        const categoryId = event.currentTarget.dataset.categoryId;
        this.closeAllActionMenus();
        await this.runCategoryAction(action, categoryId);
    }

    async handleQuotaActionClick(event) {
        event.stopPropagation();
        const action = event.currentTarget.dataset.action;
        const categoryId = event.currentTarget.dataset.categoryId;
        const quotaId = event.currentTarget.dataset.quotaId;
        this.closeAllActionMenus();
        await this.runQuotaAction(action, categoryId, quotaId);
    }

    async runCategoryAction(action, categoryId) {
        const category = this.categories.find((row) => row.categoryId === categoryId);
        if (!category) {
            return;
        }

        if (action === "view") {
            this.selectedCategoryId = categoryId;
            this.selectedDetailTab = "details";
            this.updatePageState();
            await this.loadSelectedCategoryWithQuotas(categoryId);
            return;
        }

        if (action === "edit") {
            await this.openCategoryModalWithOptions({
                categoryId: category.categoryId,
                categoryName: category.categoryName || "",
                categoryType: category.categoryType || "",
                regulatorySource: category.regulatorySource || "",
                isActive: category.isActive
            });
            return;
        }

        if (action === "addQuota") {
            await this.openQuotaModalWithOptions({
                quotaId: null,
                categoryId: category.categoryId,
                quotaName: "",
                code: "",
                reservationPercent: null,
                priorityOrder: null,
                isActive: true
            });
            return;
        }

        if (action === "delete") {
            const confirmed = await LightningConfirm.open({
                message: "Delete this category and all its quotas?",
                variant: "headerless",
                label: "Delete Category"
            });
            if (!confirmed) {
                return;
            }
            try {
                await deleteCategory({ categoryId: category.categoryId });
                this.showToast("Success", "Category deleted.", "success");
                if (this.selectedCategoryId === category.categoryId) {
                    this.selectedCategoryId = null;
                    this.selectedDetailTab = "details";
                    this.selectedCategoryData = null;
                    this.updatePageState();
                }
                await this.loadData();
            } catch (error) {
                this.showToast("Error", this.getErrorMessage(error), "error");
            }
        }
    }

    async runQuotaAction(action, categoryId, quotaId) {
        const category = this.categories.find((row) => row.categoryId === categoryId);
        const quota = category && Array.isArray(category.quotas) ? category.quotas.find((q) => q.quotaId === quotaId) : null;
        if (!quota || !category) {
            return;
        }

        if (action === "edit") {
            await this.openQuotaModalWithOptions({
                quotaId: quota.quotaId,
                categoryId: category.categoryId,
                quotaName: quota.quotaName || "",
                code: quota.code || "",
                reservationPercent: quota.reservationPercent,
                priorityOrder: quota.priorityOrder,
                isActive: quota.isActive
            });
            return;
        }

        if (action === "delete") {
            const confirmed = await LightningConfirm.open({
                message: "Delete this quota entry?",
                variant: "headerless",
                label: "Delete Quota"
            });
            if (!confirmed) {
                return;
            }
            try {
                await deleteQuota({ quotaId: quota.quotaId });
                this.showToast("Success", "Quota deleted.", "success");
                await this.loadData();
            } catch (error) {
                this.showToast("Error", this.getErrorMessage(error), "error");
            }
        }
    }

    closeAllActionMenus() {
        if (!this.openCategoryMenuId && !this.openQuotaMenuKey) {
            return;
        }
        this.openCategoryMenuId = null;
        this.openQuotaMenuKey = null;
        this.syncMenuState();
    }

    syncMenuState() {
        this.categories = (this.categories || []).map((row) => {
            const isCategoryMenuOpen = row.categoryId === this.openCategoryMenuId;
            const quotas = (row.quotas || []).map((quota) => ({
                ...quota,
                isQuotaMenuOpen: `${row.categoryId}:${quota.quotaId}` === this.openQuotaMenuKey,
                quotaMenuCellClass:
                    `${row.categoryId}:${quota.quotaId}` === this.openQuotaMenuKey ? "menuCell menuCellOpen" : "menuCell"
            }));
            return {
                ...row,
                isCategoryMenuOpen,
                quotas
            };
        });

        if (this.selectedCategoryData) {
            const currentCategoryId = this.selectedCategoryData.categoryId;
            this.selectedCategoryData = {
                ...this.selectedCategoryData,
                isCategoryMenuOpen: currentCategoryId === this.openCategoryMenuId,
                quotas: (this.selectedCategoryData.quotas || []).map((quota) => ({
                    ...quota,
                    isQuotaMenuOpen: `${currentCategoryId}:${quota.quotaId}` === this.openQuotaMenuKey,
                    quotaMenuCellClass:
                        `${currentCategoryId}:${quota.quotaId}` === this.openQuotaMenuKey ? "menuCell menuCellOpen" : "menuCell"
                }))
            };
        }

        this.applySearchFilter();
    }

    navigateToMasterData() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__masterDataLanding" }
        });
    }

    updatePageState() {
        if (!this.currentPageReference) {
            return;
        }

        const state = { ...(this.currentPageReference.state || {}) };

        if (this.selectedCategoryId) {
            state.c__categoryId = this.selectedCategoryId;
            state.c__tab = this.selectedDetailTab || "details";
        } else {
            delete state.c__categoryId;
            delete state.c__tab;
        }

        const nextSignature = `${state.c__categoryId || ""}:${state.c__tab || "details"}`;
        this.lastUrlStateSignature = nextSignature;

        this[NavigationMixin.Navigate](
            {
                type: "standard__component",
                attributes: { componentName: "c__quotaCategoryManager" },
                state
            },
            true
        );
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    getErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return "Unexpected error occurred.";
    }
}