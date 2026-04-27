import { LightningElement, track, wire } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import getProgrammeFeeRecord from "@salesforce/apex/ProgrammeFeePublishingController.getProgrammeFeeRecord";

export default class ProgrammeFeePublishingRecordPage extends NavigationMixin(LightningElement) {
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
            this.recordData = await getProgrammeFeeRecord({ feeTypeId: this.recordId });
        } catch (e) {
            this.recordData = null;
        } finally {
            this.isLoading = false;
        }
    }

    handleBackToMasterData() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__masterDataLanding" }
        });
    }

    handleBackToProgrammeFees() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__programmeFeePublishingPage" }
        });
    }

    handleEdit() {
        if (!this.recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__programmeFeePublishingBuilderPage" },
            state: { c__recordId: this.recordId }
        });
    }

    async handleConfigurationRowClick(event) {
        const feePlanId = event.currentTarget?.dataset?.feePlanId;
        if (!feePlanId) {
            return;
        }

        const pageReference = {
            type: "standard__component",
            attributes: { componentName: "c__feePlanRecordPage" },
            state: { c__recordId: feePlanId }
        };

        // Open a tab immediately to avoid popup blockers, then assign the generated URL.
        const newTab = window.open("", "_blank");
        try {
            const url = await this[NavigationMixin.GenerateUrl](pageReference);
            if (newTab) {
                newTab.location = url;
                return;
            }
            window.open(url, "_blank");
        } catch (e) {
            if (newTab) {
                newTab.close();
            }
        }
    }

    handleTabClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const selectedTab = event.currentTarget?.dataset?.tab;
        if (selectedTab) {
            this.activeTab = selectedTab;
        }
    }

    tabClass(tabName) {
        return `tab ${this.activeTab === tabName ? "tab-active" : ""}`;
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

    formatNumber(value) {
        const parsedValue = Number(value);
        if (Number.isNaN(parsedValue)) {
            return "0.00";
        }
        try {
            return new Intl.NumberFormat("en-IN", {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            }).format(parsedValue);
        } catch (e) {
            return parsedValue.toFixed(2);
        }
    }

    getStatusClass(status) {
        const normalized = String(status || "").toLowerCase();
        if (normalized === "active" || normalized === "planned") {
            return "status status-active";
        }
        if (normalized === "draft" || normalized === "not planned") {
            return "status status-draft";
        }
        if (normalized === "archived") {
            return "status status-archived";
        }
        return "status status-neutral";
    }

    get recordName() {
        return this.recordData?.programmeFeeName || "Programme Fee";
    }

    get createdByName() {
        return this.recordData?.createdByName || "-";
    }

    get lastModifiedText() {
        if (!this.recordData?.lastModified) {
            return "-";
        }
        return this.formatDate(this.recordData.lastModified);
    }

    get statusLabel() {
        return this.recordData?.status || "Draft";
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

    get usedInAssignments() {
        return this.recordData?.usedInAssignments ?? 0;
    }

    get assignedStudentText() {
        const count = this.usedInAssignments;
        return `${count} student${count === 1 ? "" : "s"}`;
    }

    get programmeName() {
        return this.recordData?.contextName || this.recordData?.programmeName || "-";
    }

    get batchIntake() {
        return this.recordData?.batchIntake || "-";
    }

    get isInstituteLinkedRecord() {
        return this.recordData?.linkLevel === "Institute";
    }

    get headerTitle() {
        if (this.isInstituteLinkedRecord) {
            return this.programmeName;
        }
        if (this.batchIntake !== "-" && this.programmeName !== "-") {
            return `${this.programmeName} | ${this.batchIntake}`;
        }
        return this.programmeName;
    }

    get contextLabel() {
        return this.isInstituteLinkedRecord ? "Institute" : "Programme";
    }

    get showBatchIntakeField() {
        return this.batchIntake !== "-";
    }

    get showAcademicYearField() {
        return this.academicYear !== "-";
    }

    get totalAmountText() {
        return this.formatNumber(this.recordData?.totalAmount);
    }

    get academicYear() {
        return this.recordData?.academicYear || "-";
    }

    get frequencyLabel() {
        return this.recordData?.frequency || "-";
    }

    get feeCategoryLabel() {
        return this.recordData?.feeCategory || "-";
    }

    get activationDateText() {
        return this.formatDate(this.recordData?.activationDate);
    }

    get createdDateText() {
        return this.formatDate(this.recordData?.createdDate);
    }

    get defaultRemittanceName() {
        return this.recordData?.defaultRemittanceName || "-";
    }

    get remittanceAccountNames() {
        return this.recordData?.remittanceAccountNames || [];
    }

    get hasRemittanceAccountNames() {
        return this.remittanceAccountNames.length > 0;
    }

    get defaultPenaltyPlanName() {
        return this.recordData?.defaultPenaltyPlanName || "-";
    }

    get notesLabel() {
        return this.recordData?.notes || "-";
    }

    get configurationRows() {
        return (this.recordData?.configurationRows || []).map((row, index) => ({
            ...row,
            rowKey: `cfg-${index}`,
            startDateLabel: this.formatDate(row.startDate),
            dueDateLabel: this.formatDate(row.dueDate),
            amountLabel: this.formatNumber(row.amount),
            statusClass: this.getStatusClass(row.status),
            rowClass: row.feePlanId ? "configuration-row configuration-row-clickable" : "configuration-row"
        }));
    }

    get hasConfigurationRows() {
        return this.configurationRows.length > 0;
    }

    get remittanceConfigurationRows() {
        return this.configurationRows.map((row) => ({
            ...row,
            remittanceAccountNames: row.remittanceAccountNames || [],
            remittanceAccounts: row.remittanceAccounts || "-"
        }));
    }

    get hasRemittanceConfigurationRows() {
        return this.remittanceConfigurationRows.length > 0;
    }

    get usageRows() {
        return (this.recordData?.usageCategories || []).map((row, index) => ({
            ...row,
            rowKey: `usage-${index}`
        }));
    }

    get hasUsageRows() {
        return this.usageRows.length > 0;
    }

    get studentsAssignedCount() {
        return this.usedInAssignments;
    }

    get amendmentRows() {
        return (this.recordData?.amendmentHistory || []).map((row, index) => ({
            ...row,
            rowKey: `amend-${index}`,
            changedAtLabel: this.formatDate(row.changedAt),
            statusClass: this.getStatusClass(row.status)
        }));
    }

    get hasAmendments() {
        return this.amendmentRows.length > 0;
    }

    get auditRows() {
        return (this.recordData?.auditTrail || []).map((row, index) => ({
            ...row,
            rowKey: `audit-${index}`,
            changedAtLabel: this.formatDateTime(row.changedAt)
        }));
    }

    get hasAuditRows() {
        return this.auditRows.length > 0;
    }

    get configurationTitle() {
        const frequency = this.frequencyLabel.toLowerCase();
        if (frequency.includes("term") || frequency.includes("semester")) {
            return "Term Configuration";
        }
        if (frequency.includes("year")) {
            return "Year Configuration";
        }
        return "Fee Configuration";
    }

    get configurationCountLabel() {
        const count = this.configurationRows.length;
        const frequency = this.frequencyLabel.toLowerCase();
        if (frequency.includes("term") || frequency.includes("semester")) {
            return `${count} of ${count} terms planned`;
        }
        if (frequency.includes("year")) {
            return `${count} year row${count === 1 ? "" : "s"} configured`;
        }
        return `${count} configuration row${count === 1 ? "" : "s"} configured`;
    }

    get termColumnLabel() {
        const frequency = this.frequencyLabel.toLowerCase();
        if (frequency.includes("one")) {
            return "Configuration";
        }
        if (frequency.includes("year")) {
            return "Year";
        }
        return "Term";
    }

    get isOneTimeConfiguration() {
        const frequency = this.frequencyLabel.toLowerCase();
        return frequency.includes("one");
    }

    get configurationEmptyColspan() {
        return this.isOneTimeConfiguration ? "5" : "6";
    }

    get remittanceEmptyColspan() {
        return this.isOneTimeConfiguration ? "2" : "3";
    }

    get isDetailsTab() {
        return this.activeTab === "details";
    }

    get isConfigurationTab() {
        return this.activeTab === "configuration";
    }

    get isUsageTab() {
        return this.activeTab === "usage";
    }

    get isAmendmentsTab() {
        return this.activeTab === "amendments";
    }

    get isAuditTab() {
        return this.activeTab === "audit";
    }

    get detailsTabClass() {
        return this.tabClass("details");
    }

    get configurationTabClass() {
        return this.tabClass("configuration");
    }

    get usageTabClass() {
        return this.tabClass("usage");
    }

    get amendmentsTabClass() {
        return this.tabClass("amendments");
    }

    get auditTabClass() {
        return this.tabClass("audit");
    }

    getStageClass(stage) {
        const status = this.statusLabel.toLowerCase();
        const activeByStage = {
            draft: true,
            review: status === "active" || status === "archived",
            active: status === "active" || status === "archived",
            archived: status === "archived"
        };
        return `pfp-stage ${activeByStage[stage] ? "pfp-stage-active" : ""}`;
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

    get archivedStageClass() {
        return this.getStageClass("archived");
    }

    get draftDotClass() {
        return this.statusLabel.toLowerCase() === "draft" ? "pfp-dot pfp-dot-green" : "pfp-dot";
    }

    get reviewDotClass() {
        const status = this.statusLabel.toLowerCase();
        return status === "active" || status === "archived" ? "pfp-dot pfp-dot-green" : "pfp-dot";
    }

    get activeDotClass() {
        const status = this.statusLabel.toLowerCase();
        return status === "active" || status === "archived" ? "pfp-dot pfp-dot-blue" : "pfp-dot";
    }

    get archivedDotClass() {
        return this.statusLabel.toLowerCase() === "archived" ? "pfp-dot pfp-dot-blue" : "pfp-dot";
    }
}