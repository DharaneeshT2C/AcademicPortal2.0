import { LightningElement, track, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import getFeePlans from "@salesforce/apex/FeePlansController.getFeePlans";
import cloneFeePlan from "@salesforce/apex/FeePlansController.cloneFeePlan";
import deleteFeePlan from "@salesforce/apex/FeePlansController.deleteFeePlan";

export default class FeePlansPage extends NavigationMixin(LightningElement) {
    @track isLoading = false;
    @track plans = [];
    @track filteredPlans = [];
    @track openActionMenu = null;
    @track notification = null;
    @track confirmDialog = null;

    searchTerm = "";
    selectedView = "all";
    lastRefreshToken = null;
    documentClickHandler;
    windowResizeHandler;
    windowScrollHandler;

    viewOptions = [{ label: "All Fee Plans", value: "all" }];

    connectedCallback() {
        this.loadFeePlans();
        this.documentClickHandler = this.handleDocumentClick.bind(this);
        this.windowResizeHandler = this.closeActionMenu.bind(this);
        this.windowScrollHandler = this.handleWindowScroll.bind(this);
        document.addEventListener("click", this.documentClickHandler);
        window.addEventListener("resize", this.windowResizeHandler);
        window.addEventListener("scroll", this.windowScrollHandler, true);
    }

    disconnectedCallback() {
        if (this.documentClickHandler) {
            document.removeEventListener("click", this.documentClickHandler);
            this.documentClickHandler = null;
        }
        if (this.windowResizeHandler) {
            window.removeEventListener("resize", this.windowResizeHandler);
            this.windowResizeHandler = null;
        }
        if (this.windowScrollHandler) {
            window.removeEventListener("scroll", this.windowScrollHandler, true);
            this.windowScrollHandler = null;
        }
    }

    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        const refreshToken = pageRef && pageRef.state ? pageRef.state.c__refresh : null;
        if (refreshToken && refreshToken !== this.lastRefreshToken) {
            this.lastRefreshToken = refreshToken;
            this.loadFeePlans();
        }
    }

    async loadFeePlans() {
        this.isLoading = true;
        try {
            const rows = await getFeePlans();
            this.plans = (rows || []).map((row) => this.mapRow(row));
            this.applyFilters();
        } catch (e) {
            this.plans = [];
            this.filteredPlans = [];
        } finally {
            this.isLoading = false;
        }
    }

    mapRow(row) {
        const statusText = row.status || "Draft";
        let statusClass = "badge badge-neutral";
        if (statusText.toLowerCase() === "active") {
            statusClass = "badge badge-active";
        } else if (statusText.toLowerCase() === "draft") {
            statusClass = "badge badge-draft";
        } else if (statusText.toLowerCase() === "archived") {
            statusClass = "badge badge-archived";
        }

        const categoryCount = row.categoryCount || 0;
        return {
            ...row,
            statusLabel: statusText,
            statusClass,
            categoryLabel: `${categoryCount} ${categoryCount === 1 ? "Category" : "Categories"}`,
            lastModifiedLabel: row.lastModified ? new Date(row.lastModified).toISOString().slice(0, 10) : "-"
        };
    }

    applyFilters() {
        const term = (this.searchTerm || "").trim().toLowerCase();
        const visiblePlans = !term
            ? [...this.plans]
            : this.plans.filter((plan) => (plan.feePlanName || "").toLowerCase().includes(term));

        this.filteredPlans = visiblePlans.map((plan) => ({
            ...plan,
            isActionMenuOpen: this.openActionMenu?.recordId === plan.feeSetId
        }));
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
        this.applyFilters();
    }

    handleViewChange(event) {
        this.selectedView = event.detail.value;
        this.applyFilters();
    }

    handleOpenRecord(event) {
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) {
            return;
        }
        this.openRecord(recordId);
    }

    async runRowAction(action, recordId) {
        if (!recordId || !action) {
            return;
        }

        if (action === "view") {
            this.openRecord(recordId);
            return;
        }

        if (action === "edit") {
            this[NavigationMixin.Navigate]({
                type: "standard__component",
                attributes: { componentName: "c__feePlanBuilderPage" },
                state: {
                    c__mode: "edit",
                    c__recordId: recordId
                }
            });
            return;
        }

        if (action === "clone") {
            await this.handleClone(recordId);
            return;
        }

        if (action === "delete") {
            await this.handleDelete(recordId);
        }
    }

    handleDocumentClick() {
        if (this.openActionMenu) {
            this.closeActionMenu();
        }
    }

    handleWindowScroll() {
        if (this.openActionMenu) {
            this.closeActionMenu();
        }
    }

    closeActionMenu() {
        if (!this.openActionMenu) {
            return;
        }
        this.openActionMenu = null;
        this.applyFilters();
    }

    handleToggleActionMenu(event) {
        event.preventDefault();
        event.stopPropagation();

        const recordId = event.currentTarget?.dataset?.id;
        if (!recordId) {
            return;
        }

        if (this.openActionMenu?.recordId === recordId) {
            this.closeActionMenu();
            return;
        }

        const rect = event.currentTarget.getBoundingClientRect();
        const menuWidth = 176;
        const menuHeight = 214;
        const viewportPadding = 16;
        const left = Math.max(viewportPadding, rect.right - menuWidth);
        const spaceBelow = window.innerHeight - rect.bottom - viewportPadding;
        const shouldOpenUp = spaceBelow < menuHeight;
        const top = shouldOpenUp
            ? Math.max(viewportPadding, rect.top - menuHeight - 8)
            : Math.max(viewportPadding, rect.bottom + 8);

        const canEdit = Number(this.plans.find((plan) => plan.feeSetId === recordId)?.usedInProgrammeFees || 0) === 0;
        this.openActionMenu = {
            recordId,
            canEdit,
            isEditDisabled: !canEdit,
            editButtonClass: canEdit ? "action-item" : "action-item action-item-disabled",
            editAriaDisabled: canEdit ? "false" : "true",
            style: `left:${left}px;top:${top}px;width:${menuWidth}px;`
        };
        this.applyFilters();
    }

    handleMenuContainerClick(event) {
        event.stopPropagation();
    }

    async handleActionClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const action = event.currentTarget.dataset.action;
        const recordId = event.currentTarget.dataset.id;
        if (action === "edit" && this.openActionMenu && this.openActionMenu.canEdit === false) {
            this.closeActionMenu();
            this.toast("Error", "Cannot edit this fee plan because it is used in programme fees.", "error");
            return;
        }
        this.closeActionMenu();
        await this.runRowAction(action, recordId);
    }

    openRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__feePlanRecordPage" },
            state: { c__recordId: recordId }
        });
    }

    async handleClone(recordId) {
        this.isLoading = true;
        try {
            const clonedRecordId = await cloneFeePlan({ feeSetId: recordId });
            this.toast("Success", "Fee plan cloned successfully.", "success");
            await this.loadFeePlans();
            this.openRecord(clonedRecordId);
        } catch (e) {
            this.toast("Error", this.getErrorMessage(e), "error");
        } finally {
            this.isLoading = false;
        }
    }

    async handleDelete(recordId) {
        if (!recordId) {
            return;
        }
        const plan = this.plans.find((row) => row.feeSetId === recordId);
        this.confirmDialog = {
            recordId,
            title: "Delete Fee Plan",
            message: plan
                ? `Delete "${plan.feePlanName}"? This action cannot be undone.`
                : "Delete this fee plan? This action cannot be undone."
        };
    }

    closeConfirmDialog() {
        this.confirmDialog = null;
    }

    async handleConfirmDelete() {
        const recordId = this.confirmDialog?.recordId;
        this.closeConfirmDialog();
        if (!recordId) {
            return;
        }

        this.isLoading = true;
        try {
            await deleteFeePlan({ feeSetId: recordId });
            this.toast("Success", "Fee plan deleted.", "success");
            await this.loadFeePlans();
        } catch (e) {
            this.toast("Error", this.getErrorMessage(e), "error");
        } finally {
            this.isLoading = false;
        }
    }

    handleNew() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__feePlanBuilderPage" }
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

    getErrorMessage(error) {
        return error && error.body && error.body.message ? error.body.message : "Unexpected error occurred.";
    }

    dismissNotification() {
        this.notification = null;
    }

    toast(title, message, variant) {
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

    get itemCountLabel() {
        const count = this.filteredPlans.length;
        return `${count} item${count === 1 ? "" : "s"}`;
    }

    get hasRows() {
        return this.filteredPlans.length > 0;
    }
}