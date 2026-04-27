import { LightningElement, track, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getTaxes from "@salesforce/apex/TaxesController.getTaxes";

export default class TaxesPage extends NavigationMixin(LightningElement) {
    @track isLoading = false;
    @track rows = [];
    @track filteredRows = [];

    searchTerm = "";
    selectedView = "all";
    lastRefreshToken;

    connectedCallback() {
        this.loadData();
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
            const taxRows = await getTaxes();
            this.rows = (taxRows || []).map((row) => ({
                ...row,
                taxRateLabel: row.taxRate === null || row.taxRate === undefined ? "-" : `${row.taxRate}%`,
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

        this.filteredRows = this.rows.filter((row) => {
            return (
                (row.name || "").toLowerCase().includes(term)
                || (row.parentTaxName || "").toLowerCase().includes(term)
            );
        });
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

    handleGoToTaxes() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__taxesPage" }
        });
    }

    handleNew() {
        this.navigateToBuilder();
    }

    handleEditTax(event) {
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) {
            return;
        }
        this.navigateToBuilder(recordId);
    }

    navigateToBuilder(recordId) {
        const state = recordId ? { c__mode: "edit", c__recordId: recordId } : { c__mode: "new" };
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__taxBuilderPage" },
            state
        });
    }

    get itemCountLabel() {
        const count = this.filteredRows.length;
        return `${count} item${count === 1 ? "" : "s"}`;
    }

    get hasRows() {
        return this.filteredRows.length > 0;
    }

    get viewOptions() {
        return [{ label: "All Taxes", value: "all" }];
    }

    handleViewChange(event) {
        this.selectedView = event.detail.value;
    }

    getErrorMessage(error) {
        return error?.body?.message || "Unexpected error occurred.";
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}