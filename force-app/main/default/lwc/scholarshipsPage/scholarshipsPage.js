import { LightningElement, track, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LightningConfirm from "lightning/confirm";

import getScholarships from "@salesforce/apex/ScholarshipsController.getScholarships";
import archiveScholarship from "@salesforce/apex/ScholarshipsController.archiveScholarship";

export default class ScholarshipsPage extends NavigationMixin(LightningElement) {
    @track isLoading = false;
    @track rows = [];
    @track filteredRows = [];

    searchTerm = "";
    selectedView = "all";
    lastRefreshToken;
    openActionMenuId = null;
    documentClickHandler;

    connectedCallback() {
        this.loadData();
        this.documentClickHandler = this.handleDocumentClick.bind(this);
        document.addEventListener("click", this.documentClickHandler);
    }

    disconnectedCallback() {
        if (this.documentClickHandler) {
            document.removeEventListener("click", this.documentClickHandler);
            this.documentClickHandler = null;
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
            const result = await getScholarships();
            this.rows = (result || []).map((row) => {
                const isReferenced = row.isReferenced === true || Number(row.usedInAssignments || 0) > 0;
                const isActionRestricted = row.isActionRestricted === true || this.isActiveStatus(row.status) || isReferenced;
                return {
                    ...row,
                    statusLabel: row.status || "Active",
                    statusClass: this.getStatusClass(row.status),
                    typeLabel: row.type || "-",
                    modeLabel: row.mode || "-",
                    isReferenced,
                    isActionRestricted,
                    isEditDisabled: isActionRestricted,
                    isDeleteDisabled: isActionRestricted,
                    editActionClass: isActionRestricted ? "action-item action-item-disabled" : "action-item",
                    archiveActionClass: isActionRestricted ? "action-item action-item-disabled" : "action-item",
                    lastModifiedLabel: row.lastModified
                        ? new Date(row.lastModified).toISOString().slice(0, 10)
                        : "-"
                };
            });
            this.openActionMenuId = null;
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
        const visibleRows = !term
            ? [...this.rows]
            : this.rows.filter((row) => {
                const name = (row.name || "").toLowerCase();
                const type = (row.typeLabel || "").toLowerCase();
                const mode = (row.modeLabel || "").toLowerCase();
                const status = (row.statusLabel || "").toLowerCase();
                return (
                    name.includes(term)
                    || type.includes(term)
                    || mode.includes(term)
                    || status.includes(term)
                );
            });

        this.filteredRows = visibleRows.map((row) => ({
            ...row,
            isActionMenuOpen: row.id === this.openActionMenuId
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

    handleGoToMasterData() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__masterDataLanding" }
        });
    }

    handleGoToScholarships() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__scholarshipsPage" }
        });
    }

    handleNew() {
        this.navigateToBuilder();
    }

    handleOpenRecord(event) {
        const scholarshipId = event.currentTarget.dataset.id;
        if (!scholarshipId) {
            return;
        }
        this.navigateToDetails(scholarshipId);
    }

    async runRowAction(action, scholarshipId) {
        if (!action || !scholarshipId) {
            return;
        }
        const row = this.rows.find((item) => item.id === scholarshipId);

        if (action === "view") {
            this.navigateToDetails(scholarshipId);
            return;
        }

        if (action === "edit") {
            if (row?.isEditDisabled) {
                this.toast("Error", this.getRowActionBlockedMessage(row), "error");
                return;
            }
            this.navigateToBuilder(scholarshipId);
            return;
        }

        if (action === "clone") {
            this.navigateToBuilder(null, scholarshipId);
            return;
        }

        if (action === "archive") {
            if (row?.isDeleteDisabled) {
                this.toast("Error", this.getRowActionBlockedMessage(row), "error");
                return;
            }
            await this.archiveRow(scholarshipId);
        }
    }

    handleDocumentClick() {
        if (this.openActionMenuId) {
            this.openActionMenuId = null;
            this.applyFilters();
        }
    }

    handleToggleActionMenu(event) {
        event.preventDefault();
        event.stopPropagation();
        const scholarshipId = event.currentTarget.dataset.id;
        this.openActionMenuId = this.openActionMenuId === scholarshipId ? null : scholarshipId;
        this.applyFilters();
    }

    async handleActionClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const action = event.currentTarget.dataset.action;
        const scholarshipId = event.currentTarget.dataset.id;
        this.openActionMenuId = null;
        this.applyFilters();
        await this.runRowAction(action, scholarshipId);
    }

    async archiveRow(scholarshipId) {
        const confirmed = await LightningConfirm.open({
            message: "Archive this scholarship?",
            variant: "header",
            label: "Confirm Archive"
        });
        if (!confirmed) {
            return;
        }

        try {
            await archiveScholarship({ scholarshipId });
            this.toast("Success", "Scholarship archived.", "success");
            await this.loadData();
        } catch (error) {
            this.toast("Error", this.getErrorMessage(error), "error");
        }
    }

    navigateToBuilder(recordId, cloneId) {
        const state = {};
        if (recordId) {
            state.c__recordId = recordId;
        }
        if (cloneId) {
            state.c__cloneId = cloneId;
        }
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__scholarshipBuilderPage" },
            state
        });
    }

    navigateToDetails(recordId) {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__scholarshipDetailsPage" },
            state: { c__recordId: recordId }
        });
    }

    getStatusClass(status) {
        const normalized = String(status || "").toLowerCase();
        if (normalized === "active") {
            return "badge badge-active";
        }
        if (normalized.includes("review")) {
            return "badge badge-review";
        }
        if (normalized === "archived") {
            return "badge badge-archived";
        }
        return "badge badge-draft";
    }

    isActiveStatus(status) {
        return String(status || "").toLowerCase() === "active";
    }

    getRowActionBlockedMessage(row) {
        const blockers = [];
        if (this.isActiveStatus(row?.status || row?.statusLabel)) {
            blockers.push("it is Active");
        }
        if (row?.isReferenced === true || Number(row?.usedInAssignments || 0) > 0) {
            blockers.push("it is referenced in child records");
        }
        if (!blockers.length) {
            return "This scholarship cannot be edited or deleted.";
        }
        return `Cannot edit or delete this Scholarship because ${blockers.join(" and ")}.`;
    }

    get itemCountLabel() {
        const count = this.filteredRows.length;
        return `${count} item${count === 1 ? "" : "s"}`;
    }

    get hasRows() {
        return this.filteredRows.length > 0;
    }

    get viewOptions() {
        return [{ label: "All Scholarships", value: "all" }];
    }

    getErrorMessage(error) {
        return error?.body?.message || "Unexpected error occurred.";
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}