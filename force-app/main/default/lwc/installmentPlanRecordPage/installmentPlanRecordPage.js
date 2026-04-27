import { LightningElement, track, wire } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import getInstallmentPlanDetails from "@salesforce/apex/InstallmentPlansController.getInstallmentPlanDetails";

export default class InstallmentPlanRecordPage extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track recordData;
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

    async loadRecord() {
        if (!this.recordId) {
            this.recordData = null;
            this.isLoading = false;
            return;
        }

        this.isLoading = true;
        try {
            this.recordData = await getInstallmentPlanDetails({ scheduleId: this.recordId });
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

    handleBackToInstallmentPlans() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__installmentPlansPage" }
        });
    }

    handleOpenInstallmentLines() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__installmentPlanLinesPage" },
            state: { c__recordId: this.recordId }
        });
    }

    handleTabClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const selectedTab = event.currentTarget?.dataset?.tab;
        if (selectedTab === "lines") {
            this.handleOpenInstallmentLines();
            return;
        }
        this.activeTab = "details";
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

    get statusLabel() {
        return this.recordData?.status || "Draft";
    }

    get statusClass() {
        const normalized = this.statusLabel.toLowerCase();
        if (normalized === "active") {
            return "status status-active";
        }
        if (normalized === "archived") {
            return "status status-archived";
        }
        return "status status-draft";
    }

    get recordName() {
        return this.recordData?.planName || "Installment Plan";
    }

    get startDateLabel() {
        return this.formatDate(this.recordData?.startDate);
    }

    get endDateLabel() {
        return this.formatDate(this.recordData?.endDate);
    }

    get lastModifiedLabel() {
        return this.formatDateTime(this.recordData?.lastModified);
    }

    get lockText() {
        return this.statusLabel.toLowerCase() === "active" ? "Locked" : "Unlocked";
    }

    get showActiveBanner() {
        return this.statusLabel.toLowerCase() === "active";
    }

    tabClass(tabName) {
        return `tab ${this.activeTab === tabName ? "tab-active" : ""}`;
    }

    get detailsTabClass() {
        return this.tabClass("details");
    }

    get linesTabClass() {
        return this.tabClass("lines");
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
        return this.getDotClass("draft");
    }

    get reviewDotClass() {
        return this.getDotClass("review");
    }

    get activeDotClass() {
        return this.getDotClass("active");
    }

    get archivedDotClass() {
        return this.getDotClass("archived");
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

    getDotClass(stage) {
        const status = this.statusLabel.toLowerCase();
        const dotMap = {
            draft: "pfp-dot-green",
            review: status === "active" || status === "archived" ? "pfp-dot-green" : "",
            active: status === "active" || status === "archived" ? "pfp-dot-blue" : "",
            archived: status === "archived" ? "pfp-dot-blue" : ""
        };
        return `pfp-dot ${dotMap[stage] || ""}`;
    }
}