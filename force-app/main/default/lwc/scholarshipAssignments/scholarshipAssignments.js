import { LightningElement } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getScholarshipAssignmentsData from "@salesforce/apex/AssignScholarshipPageController.getScholarshipAssignmentsData";

export default class ScholarshipAssignments extends NavigationMixin(LightningElement) {
    metricData = [];
    assignmentData = [];
    isLoading = false;
    errorMessage = "";

    connectedCallback() {
        this.loadAssignments();
    }

    async loadAssignments() {
        this.isLoading = true;
        this.errorMessage = "";

        try {
            const result = await getScholarshipAssignmentsData();
            this.assignmentData = (result?.rows || []).map((row) => ({
                key: row.id,
                studentName: row.studentName || "--",
                programme: row.programme || "--",
                gpa: "--",
                rank: "--",
                scholarshipName: row.scholarshipName || "--",
                status: row.status === "Active" ? "Active" : "InActive",
                appliedDate: this.formatDate(row.appliedDate),
                feeImpact: this.formatFeeImpact(row.feeImpact)
            }));

            this.metricData = [
                {
                    key: "total",
                    label: "TOTAL SCHOLARSHIPS ASSIGNED",
                    value: String(result?.totalScholarshipsAssigned || 0),
                    tone: "default"
                },
                {
                    key: "active",
                    label: "ACTIVE SCHOLARSHIPS",
                    value: String(result?.activeScholarships || 0),
                    tone: "default"
                },
                {
                    key: "inactive",
                    label: "IN ACTIVE",
                    value: String(result?.inactiveScholarships || 0),
                    tone: "warning"
                },
                {
                    key: "impact",
                    label: "TOTAL FINANCIAL IMPACT",
                    value: this.formatTotalCurrency(result?.totalFinancialImpact),
                    tone: "success"
                }
            ];
        } catch (error) {
            this.assignmentData = [];
            this.metricData = [
                { key: "total", label: "TOTAL SCHOLARSHIPS ASSIGNED", value: "0", tone: "default" },
                { key: "active", label: "ACTIVE SCHOLARSHIPS", value: "0", tone: "default" },
                { key: "inactive", label: "IN ACTIVE", value: "0", tone: "warning" },
                { key: "impact", label: "TOTAL FINANCIAL IMPACT", value: "INR 0.00", tone: "success" }
            ];
            this.errorMessage = this.getErrorMessage(error, "Unable to load scholarship assignments.");
        } finally {
            this.isLoading = false;
        }
    }

    get metrics() {
        return this.metricData.map((metric) => ({
            ...metric,
            valueClass:
                metric.tone === "success"
                    ? "metricValue metricValueSuccess"
                    : metric.tone === "warning"
                        ? "metricValue metricValueWarning"
                        : "metricValue"
        }));
    }

    get assignments() {
        return this.assignmentData.map((assignment) => ({
            ...assignment,
            statusClass:
                assignment.status === "Active"
                    ? "statusBadge statusActive"
                    : "statusBadge statusInactive"
        }));
    }

    get hasAssignments() {
        return this.assignmentData.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.errorMessage && !this.hasAssignments;
    }

    handleAssignScholarship() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: {
                componentName: "c__assignScholarshipPage"
            }
        });
    }

    formatDate(dateValue) {
        if (!dateValue) {
            return "--";
        }

        const parsedDate = new Date(dateValue);
        if (Number.isNaN(parsedDate.getTime())) {
            return "--";
        }

        return new Intl.DateTimeFormat("en-IN", {
            day: "2-digit",
            month: "short",
            year: "numeric"
        }).format(parsedDate);
    }

    formatFeeImpact(amountValue) {
        if (amountValue === null || amountValue === undefined) {
            return "--";
        }
        return this.formatAmount(amountValue);
    }

    formatTotalCurrency(amountValue) {
        return this.formatAmount(amountValue || 0);
    }

    formatAmount(amountValue) {
        const amount = Number(amountValue);
        if (!Number.isFinite(amount)) {
            return "INR 0.00";
        }

        return `INR ${amount.toLocaleString("en-IN", {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        })}`;
    }

    getErrorMessage(error, fallbackMessage) {
        return error?.body?.message || fallbackMessage;
    }
}