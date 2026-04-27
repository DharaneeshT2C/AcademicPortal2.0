import { LightningElement, track, wire } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import getInstallmentPlanDetails from "@salesforce/apex/InstallmentPlansController.getInstallmentPlanDetails";

export default class InstallmentPlanLinesPage extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track recordData;

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

    handleBackToPlanDetails() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__installmentPlanRecordPage" },
            state: { c__recordId: this.recordId }
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
        } catch (e) {
            return "-";
        }
    }

    get recordName() {
        return this.recordData?.planName || "Installment Plan";
    }

    get rows() {
        return (this.recordData?.installments || []).map((row, index) => ({
            ...row,
            rowKey: `line-${index}`,
            order: row.order || index + 1,
            startDateLabel: this.formatDate(row.startDate),
            dueDaysLabel: row.dueDays ?? "-"
        }));
    }

    get hasRows() {
        return this.rows.length > 0;
    }
}