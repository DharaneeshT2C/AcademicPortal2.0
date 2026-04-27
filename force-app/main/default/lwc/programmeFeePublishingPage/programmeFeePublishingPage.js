import { LightningElement, track, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { deleteRecord } from "lightning/uiRecordApi";
import LightningConfirm from "lightning/confirm";
import getProgrammeFees from "@salesforce/apex/ProgrammeFeePublishingController.getProgrammeFees";

const TAB_TYPE = "type";
const TAB_STRUCTURE = "structure";
const CATEGORY_ACADEMIC = "academic";
const CATEGORY_ACADEMICS = "academics";
const FREQUENCY_ONE_TIME = "one time";
const FREQUENCY_ONE = "one";
const FREQUENCY_TIME = "time";

export default class ProgrammeFeePublishingPage extends NavigationMixin(LightningElement) {
    @track isLoading = false;
    @track rows = [];
    @track filteredRows = [];

    searchTerm = "";
    selectedView = "all";
    activeTab = TAB_STRUCTURE;
    openActionMenu = null;
    documentClickHandler;
    windowResizeHandler;
    windowScrollHandler;

    viewOptions = [{ label: "All Programme Fees", value: "all" }];

    connectedCallback() {
        this.loadRows();
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
        const requestedTab = pageRef?.state?.c__tab;
        if (requestedTab === TAB_TYPE || requestedTab === TAB_STRUCTURE) {
            this.activeTab = requestedTab;
            this.applyFilters();
        }
    }

    async loadRows() {
        this.isLoading = true;
        try {
            const result = await getProgrammeFees();
            this.rows = (result || []).map((row) => this.mapRow(row));
            this.applyFilters();
        } catch (e) {
            this.rows = [];
            this.filteredRows = [];
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

        return {
            ...row,
            feeCategory: row.feeCategory || null,
            statusLabel: statusText,
            statusClass,
            activationDateLabel: row.activationDate || "-",
            lastModifiedLabel: row.lastModified ? new Date(row.lastModified).toISOString().slice(0, 10) : "-"
        };
    }

    applyFilters() {
        const term = (this.searchTerm || "").trim().toLowerCase();
        const rowsForActiveTab = (this.rows || []).filter((row) => {
            const category = String(row.feeCategory || "").trim().toLowerCase();
            const isAcademicCategory = category === CATEGORY_ACADEMIC || category === CATEGORY_ACADEMICS;
            const isOneTimeFee = this.isOneTimeFee(row?.frequency);
            if (this.isFeeTypeTab) {
                return isOneTimeFee || (Boolean(category) && !isAcademicCategory);
            }
            return !isOneTimeFee && (!category || isAcademicCategory);
        });

        const matchedRows = !term
            ? [...rowsForActiveTab]
            : rowsForActiveTab.filter((row) => {
                return (
                    (row.programmeFeeName || "").toLowerCase().includes(term) ||
                    (row.programmeName || "").toLowerCase().includes(term)
                );
            });

        this.filteredRows = matchedRows.map((row) => ({
            ...row
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

    handleTabChange(event) {
        const nextTab = event.currentTarget.dataset.tab;
        if (!nextTab || nextTab === this.activeTab) {
            return;
        }
        this.activeTab = nextTab;
        this.closeActionMenu();
        this.applyFilters();
    }

    handleOpenRecord(event) {
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) {
            return;
        }
        this.navigateToRecordView(recordId);
    }

    navigateToRecordView(recordId) {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: {
                componentName: "c__programmeFeePublishingRecordPage"
            },
            state: {
                c__recordId: recordId
            }
        });
    }

    navigateToRecordEdit(recordId) {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: {
                componentName: "c__programmeFeePublishingBuilderPage"
            },
            state: {
                c__recordId: recordId
            }
        });
    }

    async handleRowAction(event) {
        const action = event.detail.value;
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) {
            return;
        }

        if (action === "view") {
            this.navigateToRecordView(recordId);
            return;
        }

        if (action === "edit") {
            this.navigateToRecordEdit(recordId);
            return;
        }

        if (action === "delete") {
            await this.handleDeleteRecord(recordId);
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
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) {
            return;
        }

        if (this.openActionMenu?.recordId === recordId) {
            this.closeActionMenu();
            return;
        }

        const rect = event.currentTarget.getBoundingClientRect();
        const menuWidth = 176;
        const menuHeight = 248;
        const viewportPadding = 16;
        const left = Math.max(viewportPadding, rect.right - menuWidth);
        const spaceBelow = window.innerHeight - rect.bottom - viewportPadding;
        const shouldOpenUp = spaceBelow < menuHeight;
        const top = shouldOpenUp
            ? Math.max(viewportPadding, rect.top - menuHeight - 8)
            : Math.max(viewportPadding, rect.bottom + 8);

        this.openActionMenu = {
            recordId,
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
        const recordId = event.currentTarget.dataset.id;
        this.closeActionMenu();

        if (!action || !recordId) {
            return;
        }
        if (action === "view") {
            this.navigateToRecordView(recordId);
            return;
        }
        if (action === "edit") {
            this.navigateToRecordEdit(recordId);
            return;
        }
        if (action === "delete") {
            await this.handleDeleteRecord(recordId);
        }
    }

    async handleDeleteRecord(recordId) {
        const confirmed = await LightningConfirm.open({
            message: "Delete this programme fee record? This action cannot be undone.",
            variant: "header",
            label: "Confirm Delete"
        });
        if (!confirmed) {
            return;
        }

        try {
            await deleteRecord(recordId);
            this.toast("Success", "Programme fee record deleted.", "success");
            await this.navigateToProgrammeFeePublishingWithReload();
        } catch (error) {
            this.toast("Error", this.parseError(error), "error");
        }
    }

    async navigateToProgrammeFeePublishingWithReload() {
        const pageReference = {
            type: "standard__component",
            attributes: { componentName: "c__programmeFeePublishingPage" },
            state: {
                c__refresh: Date.now().toString(),
                c__tab: this.isFeeTypeTab ? "type" : "structure"
            }
        };
        const generatedUrl = await this[NavigationMixin.GenerateUrl](pageReference);
        window.location.assign(generatedUrl);
    }

    handleGoToMasterData() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__masterDataLanding" }
        });
    }

    handleNew() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__programmeFeePublishingBuilderPage" },
            state: {
                c__feeMode: this.isFeeTypeTab ? "type" : "structure"
            }
        });
    }

    get itemCountLabel() {
        const count = this.filteredRows.length;
        return `${count} item${count === 1 ? "" : "s"}`;
    }

    get hasRows() {
        return this.filteredRows.length > 0;
    }

    get tabHeading() {
        return this.isFeeTypeTab ? "Fee Type Publishing" : "Programme Fee Publishing";
    }

    get tabEmptyStateLabel() {
        return this.isFeeTypeTab ? "No fee type records found." : "No programme fees found.";
    }

    get isStructureTab() {
        return this.activeTab === TAB_STRUCTURE;
    }

    get isFeeTypeTab() {
        return this.activeTab === TAB_TYPE;
    }

    get structureTabClass() {
        return this.isStructureTab ? "tab-btn tab-btn-active" : "tab-btn";
    }

    get typeTabClass() {
        return this.isFeeTypeTab ? "tab-btn tab-btn-active" : "tab-btn";
    }

    parseError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (Array.isArray(error?.body) && error.body.length && error.body[0]?.message) {
            return error.body[0].message;
        }
        return "Something went wrong.";
    }

    isOneTimeFee(frequencyValue) {
        const normalizedFrequency = String(frequencyValue || "")
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, " ")
            .trim();
        return normalizedFrequency === FREQUENCY_ONE_TIME
            || (normalizedFrequency.includes(FREQUENCY_ONE) && normalizedFrequency.includes(FREQUENCY_TIME));
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}