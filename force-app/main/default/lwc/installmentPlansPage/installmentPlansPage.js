import { LightningElement, track, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import getInstallmentPlans from "@salesforce/apex/InstallmentPlansController.getInstallmentPlans";
import deleteInstallmentPlan from "@salesforce/apex/InstallmentPlansController.deleteInstallmentPlan";

export default class InstallmentPlansPage extends NavigationMixin(LightningElement) {
    @track isLoading = false;
    @track rows = [];
    @track filteredRows = [];
    @track openActionMenu = null;
    @track notification = null;
    @track confirmDialog = null;

    searchTerm = "";
    selectedView = "all";
    lastRefreshToken;
    documentClickHandler;
    windowResizeHandler;
    windowScrollHandler;

    connectedCallback() {
        this.loadData();
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
    setPageReference(pageRef) {
        const refreshToken = pageRef?.state?.c__refresh;
        if (refreshToken && refreshToken !== this.lastRefreshToken) {
            this.lastRefreshToken = refreshToken;
            this.loadData();
        }
    }

    async loadData() {
        this.isLoading = true;
        try {
            const result = await getInstallmentPlans();
            this.rows = (result || []).map((row) => ({
                ...row,
                usedInProgrammeFees: Number(row.usedInProgrammeFees || 0),
                isEditRestricted: Number(row.usedInProgrammeFees || 0) > 0,
                statusLabel: row.status || "Draft",
                statusClass: this.getStatusClass(row.status),
                startDateLabel: row.startDate || "-",
                endDateLabel: row.endDate || "-",
                lastModifiedLabel: row.lastModified ? new Date(row.lastModified).toISOString().slice(0, 10) : "-"
            }));
            this.applyFilters();
        } catch (error) {
            this.rows = [];
            this.filteredRows = [];
            this.toast("Error", this.getErrorMessage(error), "error");
        } finally {
            this.isLoading = false;
        }
    }

    applyFilters() {
        const term = (this.searchTerm || "").trim().toLowerCase();
        if (!term) {
            this.filteredRows = [...this.rows];
            return;
        }
        this.filteredRows = this.rows.filter((row) => (row.name || "").toLowerCase().includes(term));
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
        this.applyFilters();
    }

    handleGoToMasterData() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__masterDataLanding" }
        });
    }

    handleGoToInstallmentPlans() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__installmentPlansPage" }
        });
    }

    handleNew() {
        this.navigateToBuilder();
    }

    get itemCountLabel() {
        const count = this.filteredRows.length;
        return `${count} item${count === 1 ? "" : "s"}`;
    }

    get hasRows() {
        return this.filteredRows.length > 0;
    }

    get viewOptions() {
        return [{ label: "All Installment Plans", value: "all" }];
    }

    handleViewChange(event) {
        this.selectedView = event.detail.value;
    }

    async handleRowAction(action, scheduleId) {
        if (!scheduleId) {
            return;
        }

        if (action === "view") {
            this.navigateToRecordView(scheduleId);
            return;
        }

        if (action === "edit") {
            const schedule = this.rows.find((row) => row.id === scheduleId);
            if (schedule?.isEditRestricted) {
                this.toast("Error", "Cannot edit this installment plan because it is used in programme fee configurations.", "error");
                return;
            }
            this.navigateToBuilder(scheduleId);
            return;
        }

        if (action === "delete") {
            await this.deletePlan(scheduleId);
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
    }

    handleToggleActionMenu(event) {
        event.preventDefault();
        event.stopPropagation();

        const scheduleId = event.currentTarget?.dataset?.id;
        if (!scheduleId) {
            return;
        }

        if (this.openActionMenu?.recordId === scheduleId) {
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

        this.openActionMenu = {
            recordId: scheduleId,
            isEditRestricted: Number(this.rows.find((row) => row.id === scheduleId)?.usedInProgrammeFees || 0) > 0,
            style: `left:${left}px;top:${top}px;width:${menuWidth}px;`
        };
    }

    handleMenuContainerClick(event) {
        event.stopPropagation();
    }

    async handleActionClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const action = event.currentTarget.dataset.action;
        const scheduleId = event.currentTarget.dataset.id;
        this.closeActionMenu();
        await this.handleRowAction(action, scheduleId);
    }

    handleOpenRecord(event) {
        const scheduleId = event.currentTarget.dataset.id;
        if (!scheduleId) {
            return;
        }
        this.navigateToRecordView(scheduleId);
    }

    navigateToRecordView(scheduleId) {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__installmentPlanRecordPage" },
            state: { c__recordId: scheduleId }
        });
    }

    navigateToBuilder(scheduleId) {
        const state = scheduleId ? { c__recordId: scheduleId } : {};
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__installmentPlanBuilderPage" },
            state
        });
    }

    async deletePlan(scheduleId) {
        if (!scheduleId) {
            return;
        }
        const schedule = this.rows.find((row) => row.id === scheduleId);
        this.confirmDialog = {
            recordId: scheduleId,
            title: "Delete Installment Plan",
            message: schedule
                ? `Delete "${schedule.name}"? This action cannot be undone.`
                : "Delete this installment plan? This action cannot be undone."
        };
    }

    closeConfirmDialog() {
        this.confirmDialog = null;
    }

    async handleConfirmDelete() {
        const scheduleId = this.confirmDialog?.recordId;
        this.closeConfirmDialog();
        if (!scheduleId) {
            return;
        }

        try {
            await deleteInstallmentPlan({ scheduleId });
            this.toast("Success", "Installment plan deleted.", "success");
            await this.loadData();
        } catch (error) {
            this.toast("Error", this.getErrorMessage(error), "error");
        }
    }

    get isOpenActionMenuEditDisabled() {
        return this.openActionMenu?.isEditRestricted;
    }

    get openActionMenuEditClass() {
        return "action-item";
    }

    get openActionMenuDeleteClass() {
        return "action-item action-item-danger";
    }

    getErrorMessage(error) {
        return error?.body?.message || "Unexpected error occurred.";
    }

    getStatusClass(status) {
        const normalized = String(status || "draft").toLowerCase();
        if (normalized === "active") {
            return "badge badge-active";
        }
        if (normalized === "archived") {
            return "badge badge-archived";
        }
        return "badge badge-draft";
    }

    dismissNotification() {
        this.notification = null;
    }

    toast(title, message, variant) {
        const normalizedVariant = variant === "success" ? "success" : variant === "warning" ? "warning" : "error";
        this.notification = {
            title,
            message,
            containerClass: `noticeBanner noticeBanner${normalizedVariant.charAt(0).toUpperCase()}${normalizedVariant.slice(1)}`,
            iconName:
                normalizedVariant === "success"
                    ? "utility:success"
                    : normalizedVariant === "warning"
                      ? "utility:warning"
                      : "utility:error"
        };
    }
}