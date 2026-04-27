import { LightningElement, track, wire } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getFeePlanRecord from "@salesforce/apex/FeePlansController.getFeePlanRecord";

export default class FeePlanRecordPage extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track recordData;
    @track activeTab = "details";

    recordId;

    @wire(CurrentPageReference)
    setPageRef(pageRef) {
        const nextRecordId = pageRef && pageRef.state ? pageRef.state.c__recordId : null;
        if (nextRecordId && nextRecordId !== this.recordId) {
            this.recordId = nextRecordId;
            this.loadRecord();
        }
    }

    async loadRecord() {
        if (!this.recordId) {
            this.recordData = null;
            this.isLoading = false;
            return;
        }

        this.isLoading = true;
        try {
            this.recordData = await getFeePlanRecord({ feeSetId: this.recordId });
        } catch (e) {
            this.recordData = null;
        } finally {
            this.isLoading = false;
        }
    }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    handleBackToFeePlans() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__feePlansPage" }
        });
    }

    handleBackToMasterData() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__masterDataLanding" }
        });
    }

    handleEdit() {
        if (!this.recordId) {
            return;
        }
        if (this.isEditRestricted) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: "Cannot edit this fee plan because it is used in programme fees.",
                    variant: "error"
                })
            );
            return;
        }
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__feePlanBuilderPage" },
            state: {
                c__mode: "edit",
                c__recordId: this.recordId
            }
        });
    }

    formatDateTime(value) {
        if (!value) {
            return "-";
        }
        try {
            return new Intl.DateTimeFormat("en-IN", {
                year: "numeric",
                month: "2-digit",
                day: "2-digit",
                hour: "2-digit",
                minute: "2-digit"
            }).format(new Date(value));
        } catch (e) {
            return "-";
        }
    }

    formatDate(value) {
        if (!value) {
            return "-";
        }
        try {
            return new Intl.DateTimeFormat("en-IN", {
                year: "numeric",
                month: "2-digit",
                day: "2-digit"
            }).format(new Date(value));
        } catch (e) {
            return "-";
        }
    }

    formatCurrency(value) {
        const amount = Number(value || 0);
        return new Intl.NumberFormat(this.currencyLocale, {
            style: "currency",
            currency: this.currencyCode,
            maximumFractionDigits: 0
        }).format(amount);
    }

    formatAmount(value) {
        if (value === null || value === undefined || value === "") {
            return "-";
        }
        return this.formatCurrency(value);
    }

    getStatusClass(status) {
        const normalized = String(status || "").toLowerCase();
        if (normalized === "active") {
            return "status status-active";
        }
        if (normalized === "draft") {
            return "status status-draft";
        }
        if (normalized === "archived") {
            return "status status-archived";
        }
        return "status status-neutral";
    }

    get planName() {
        return this.recordData?.feePlanName || "Fee Plan";
    }

    get versionLabel() {
        return this.recordData?.versionLabel || "v1.0";
    }

    get statusLabel() {
        return (this.recordData?.status || "").trim() || "Draft";
    }

    get currencyPolicy() {
        return (this.recordData?.currencyPolicy || "").trim();
    }

    get currencyCode() {
        const value = this.currencyPolicy.toUpperCase();
        if (value === "USD" || value === "INR") {
            return value;
        }
        return "INR";
    }

    get currencyLocale() {
        return this.currencyCode === "USD" ? "en-US" : "en-IN";
    }

    get currencyLabel() {
        return this.currencyPolicy || this.currencyCode;
    }

    get createdByName() {
        return this.recordData?.createdByName || "-";
    }

    get lastModifiedText() {
        return this.formatDateTime(this.recordData?.lastModified);
    }

    get categories() {
        const categories = this.recordData?.categories || [];
        return categories.filter((category) => {
            const quotas = Array.isArray(category?.quotas) ? category.quotas : [];
            return quotas.length > 0;
        });
    }

    get feeStructureCategories() {
        return this.categories.map((category, categoryIndex) => {
            const headers = Array.isArray(category.quotaCodes) ? category.quotaCodes : [];
            const totalsByCode = {};
            headers.forEach((code) => {
                totalsByCode[code] = 0;
            });

            const rows = (category.feeRows || []).map((row, rowIndex) => {
                const amountMap = {};
                (row.quotaAmounts || []).forEach((entry) => {
                    amountMap[entry.quotaCode] = Number(entry.amount || 0);
                });

                const cells = headers.map((code) => {
                    const amountValue = amountMap[code];
                    if (amountValue !== undefined) {
                        totalsByCode[code] += amountValue;
                    }
                    return {
                        key: `${row.rowKey}-${code}`,
                        amountLabel: amountValue === undefined ? "-" : this.formatAmount(amountValue)
                    };
                });

                return {
                    ...row,
                    rowKey: row.rowKey || `row-${categoryIndex}-${rowIndex}`,
                    cells
                };
            });

            const totalCells = headers.map((code) => ({
                key: `total-${categoryIndex}-${code}`,
                amountLabel: this.formatAmount(totalsByCode[code] || 0)
            }));

            return {
                categoryName: category.categoryName,
                headers,
                rows,
                totalCells
            };
        });
    }

    get programmeFeesCount() {
        return this.recordData?.usageMetrics?.programmeFees ?? 0;
    }

    get isEditRestricted() {
        return this.programmeFeesCount > 0;
    }

    get studentsAssignedCount() {
        return this.recordData?.usageMetrics?.studentsAssigned ?? 0;
    }

    get totalRevenueLabel() {
        return this.formatCurrency(this.recordData?.usageMetrics?.totalRevenue);
    }

    get programmeFeeConfigs() {
        return (this.recordData?.programmeFeeConfigs || []).map((row, index) => ({
            ...row,
            rowKey: `programme-${index}`,
            statusClass: this.getStatusClass(row.status)
        }));
    }

    get hasProgrammeFeeConfigs() {
        return this.programmeFeeConfigs.length > 0;
    }

    get versionHistoryRows() {
        return (this.recordData?.versionHistory || []).map((row, index) => ({
            ...row,
            rowKey: `version-${index}`,
            dateLabel: this.formatDate(row.changedOn),
            statusClass: this.getStatusClass(row.status)
        }));
    }

    get hasVersionHistory() {
        return this.versionHistoryRows.length > 0;
    }

    get auditLogRows() {
        return (this.recordData?.auditLogs || []).map((row, index) => ({
            ...row,
            rowKey: `audit-${index}`,
            dateTimeLabel: this.formatDateTime(row.eventAt)
        }));
    }

    get hasAuditLogs() {
        return this.auditLogRows.length > 0;
    }

    get isDetailsTab() {
        return this.activeTab === "details";
    }

    get isCategoriesTab() {
        return this.activeTab === "categories";
    }

    get isFeeStructureTab() {
        return this.activeTab === "feeStructure";
    }

    get isUsageTab() {
        return this.activeTab === "usage";
    }

    get isVersionHistoryTab() {
        return this.activeTab === "versionHistory";
    }

    get isAuditLogTab() {
        return this.activeTab === "auditLog";
    }

    tabClass(tabName) {
        return `fp-tab ${this.activeTab === tabName ? "fp-tab-active" : ""}`;
    }

    get detailsTabClass() {
        return this.tabClass("details");
    }

    get categoriesTabClass() {
        return this.tabClass("categories");
    }

    get feeStructureTabClass() {
        return this.tabClass("feeStructure");
    }

    get usageTabClass() {
        return this.tabClass("usage");
    }

    get versionHistoryTabClass() {
        return this.tabClass("versionHistory");
    }

    get auditLogTabClass() {
        return this.tabClass("auditLog");
    }

    get statusBadgeClass() {
        return this.getStatusClass(this.statusLabel);
    }

    get isLocked() {
        return this.statusLabel.toLowerCase() === "active";
    }

    get lockText() {
        return this.isLocked ? "Locked" : "Unlocked";
    }

    get showActiveBanner() {
        return this.isLocked;
    }

    get draftStageClass() {
        return this.getStageClass("draft");
    }

    get reviewStageClass() {
        return this.getStageClass("review");
    }

    get activeStageClass() {
        return this.getStageClass("active");
    }

    get activeDotClass() {
        const status = this.statusLabel.toLowerCase();
        const isActiveOrArchived = status === "active" || status === "archived";
        return `fp-dot ${isActiveOrArchived ? "fp-dot-blue" : ""}`;
    }

    get archivedStageClass() {
        return this.getStageClass("archived");
    }

    getStageClass(stage) {
        const status = this.statusLabel.toLowerCase();
        const activeByStage = {
            draft: true,
            review: status === "active" || status === "archived",
            active: status === "active" || status === "archived",
            archived: status === "archived"
        };
        return `fp-stage ${activeByStage[stage] ? "fp-stage-active" : ""}`;
    }
}