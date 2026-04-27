import { LightningElement, track, wire } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import getScholarshipDetails from "@salesforce/apex/ScholarshipsController.getScholarshipDetails";

export default class ScholarshipDetailsPage extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track recordData = null;
    @track activeTab = "details";

    recordId;

    @wire(CurrentPageReference)
    setPageRef(pageRef) {
        const nextRecordId = pageRef?.state?.c__recordId || null;
        if (nextRecordId && nextRecordId !== this.recordId) {
            this.recordId = nextRecordId;
            this.loadRecord();
        }
    }

    connectedCallback() {
        if (this.recordId) {
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
            this.recordData = await getScholarshipDetails({ scholarshipId: this.recordId });
        } catch (error) {
            this.recordData = null;
        } finally {
            this.isLoading = false;
        }
    }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab || "details";
    }

    handleBackToMasterData() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__masterDataLanding" }
        });
    }

    handleBackToScholarships() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__scholarshipsPage" }
        });
    }

    handleClone() {
        if (!this.recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__scholarshipBuilderPage" },
            state: { c__cloneId: this.recordId }
        });
    }

    handleEdit() {
        if (!this.recordId || this.isEditDisabled) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__scholarshipBuilderPage" },
            state: { c__recordId: this.recordId, c__mode: "edit" }
        });
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
        } catch (error) {
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
        } catch (error) {
            return "-";
        }
    }

    formatRelativeTime(value) {
        if (!value) {
            return "-";
        }

        const timestamp = new Date(value).getTime();
        if (Number.isNaN(timestamp)) {
            return "-";
        }

        const elapsedMinutes = Math.floor((Date.now() - timestamp) / 60000);
        if (elapsedMinutes < 1) {
            return "just now";
        }
        if (elapsedMinutes < 60) {
            return `${elapsedMinutes} min ago`;
        }
        const elapsedHours = Math.floor(elapsedMinutes / 60);
        if (elapsedHours < 24) {
            return `${elapsedHours} hour${elapsedHours === 1 ? "" : "s"} ago`;
        }
        const elapsedDays = Math.floor(elapsedHours / 24);
        return `${elapsedDays} day${elapsedDays === 1 ? "" : "s"} ago`;
    }

    getStatusClass(status) {
        const normalized = String(status || "").toLowerCase();
        if (normalized === "active") {
            return "status status-active";
        }
        if (normalized.includes("review")) {
            return "status status-review";
        }
        if (normalized === "archived") {
            return "status status-archived";
        }
        return "status status-draft";
    }

    tabClass(tabName) {
        return `tab ${this.activeTab === tabName ? "tab-active" : ""}`;
    }

    get detailsTabClass() {
        return this.tabClass("details");
    }

    get eligibilityTabClass() {
        return this.tabClass("eligibility");
    }

    get usageTabClass() {
        return this.tabClass("usage");
    }

    get versionTabClass() {
        return this.tabClass("versionHistory");
    }

    get auditTabClass() {
        return this.tabClass("auditLog");
    }

    get isDetailsTab() {
        return this.activeTab === "details";
    }

    get isEligibilityTab() {
        return this.activeTab === "eligibility";
    }

    get isUsageTab() {
        return this.activeTab === "usage";
    }

    get isVersionTab() {
        return this.activeTab === "versionHistory";
    }

    get isAuditTab() {
        return this.activeTab === "auditLog";
    }

    get scholarshipName() {
        return this.recordData?.name || "Scholarship";
    }

    get statusLabel() {
        return this.recordData?.status || "Draft";
    }

    get statusBadgeClass() {
        return this.getStatusClass(this.statusLabel);
    }

    get versionLabel() {
        return this.recordData?.version || "v1.0";
    }

    get lockText() {
        return this.recordData?.isLocked ? "Locked" : "Unlocked";
    }

    get createdByName() {
        return this.recordData?.createdByName || "-";
    }

    get lastModifiedRelative() {
        return this.formatRelativeTime(this.recordData?.lastModifiedDate);
    }

    get showActiveBanner() {
        return (this.statusLabel || "").toLowerCase() === "active";
    }

    get activeRecordMessage() {
        const students = this.recordData?.studentsAssigned ?? 0;
        const programmes = this.recordData?.programmes ?? 0;
        return `This Scholarship is currently active and assigned to ${students} students across ${programmes} programmes. Clone to create a new version for modifications.`;
    }

    get isEditDisabled() {
        return !this.recordId || !!this.recordData?.isLocked;
    }

    get headerTitle() {
        return `${this.scholarshipName} (${this.versionLabel})`;
    }

    get valueText() {
        return this.recordData?.valueDisplay || "-";
    }

    get createdDateText() {
        return this.formatDate(this.recordData?.createdDate);
    }

    get activatedDateText() {
        return this.formatDate(this.recordData?.activatedDate);
    }

    get eligibilityRows() {
        return (this.recordData?.connectionRows || []).map((row, index) => ({
            ...row,
            rowKey: row.id || `eligibility-${index}`,
            connectionName: row.connectionName || "-",
            linkedLevel: row.linkedLevel || "-",
            linkedRecordName: row.linkedRecordName || "-",
            instituteName: row.instituteName || "-",
            learningProgramPlanName: row.learningProgramPlanName || "-",
            masterFeeHeadName: row.masterFeeHeadName || "-",
            categoryName: row.categoryName || "-"
        }));
    }

    get hasEligibilityRows() {
        return this.eligibilityRows.length > 0;
    }

    get usageRows() {
        return (this.recordData?.usageRows || []).map((row, index) => ({
            ...row,
            rowKey: `usage-${index}`,
            statusClass: this.getStatusClass(row.status)
        }));
    }

    get hasUsageRows() {
        return this.usageRows.length > 0;
    }

    get versionRows() {
        return (this.recordData?.versionHistory || []).map((row, index) => ({
            ...row,
            rowKey: `version-${index}`,
            dateLabel: this.formatDate(row.changedOn),
            statusClass: this.getStatusClass(row.status)
        }));
    }

    get hasVersionRows() {
        return this.versionRows.length > 0;
    }

    get auditRows() {
        return (this.recordData?.auditLogs || []).map((row, index) => ({
            ...row,
            rowKey: `audit-${index}`,
            dateTimeLabel: this.formatDateTime(row.changedOn)
        }));
    }

    get hasAuditRows() {
        return this.auditRows.length > 0;
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

    get activeDotClass() {
        const status = this.statusLabel.toLowerCase();
        const isActiveOrArchived = status === "active" || status === "archived";
        return `lifecycle-dot ${isActiveOrArchived ? "dot-blue" : ""}`;
    }

    getStageClass(stage) {
        const status = this.statusLabel.toLowerCase();
        const activeByStage = {
            draft: true,
            review: status === "under review" || status === "active" || status === "archived",
            active: status === "active" || status === "archived",
            archived: status === "archived"
        };
        return `lifecycle-stage ${activeByStage[stage] ? "lifecycle-stage-active" : ""}`;
    }
}