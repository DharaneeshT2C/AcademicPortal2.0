import { LightningElement } from "lwc";
import getScholarshipTransactionsDashboard from "@salesforce/apex/ScholarshipTransactionsController.getScholarshipTransactionsDashboard";

const STATUS_CLASSES = {
    Active: "statusBadge statusActive",
    Pending: "statusBadge statusPending",
    Expired: "statusBadge statusExpired"
};

const TYPE_CLASSES = {
    Income: "typeBadge typeIncome",
    Expense: "typeBadge typeExpense"
};

export default class ScholarshipTransactions extends LightningElement {
    isLoading = false;
    errorMessage = "";
    metrics = [];
    scholarshipRows = [];

    connectedCallback() {
        this.loadDashboard();
    }

    async loadDashboard() {
        this.isLoading = true;
        this.errorMessage = "";

        try {
            const data = await getScholarshipTransactionsDashboard();
            this.metrics = this.buildMetrics(data);
            this.scholarshipRows = this.buildRows(data?.rows || []);
        } catch (error) {
            this.metrics = this.buildMetrics(null);
            this.scholarshipRows = [];
            this.errorMessage = this.getErrorMessage(
                error,
                "Unable to load scholarship transactions."
            );
        } finally {
            this.isLoading = false;
        }
    }

    get hasRows() {
        return this.scholarshipRows.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.errorMessage && !this.hasRows;
    }

    buildMetrics(data) {
        return [
            {
                id: "activeDeductions",
                label: "Active Scholarship Deductions",
                value: String(data?.activeScholarshipDeductions || 0),
                valueClass: "metricValue"
            },
            {
                id: "totalAmount",
                label: "Total Deduction Amount",
                value: this.formatCurrency(data?.totalDeductionAmount || 0),
                valueClass: "metricValue metricValueSuccess"
            },
            {
                id: "studentsImpacted",
                label: "Students Impacted",
                value: String(data?.studentsImpacted || 0),
                valueClass: "metricValue"
            },
            {
                id: "recentAdjustments",
                label: "Recent Adjustments",
                value: String(data?.recentAdjustments || 0),
                valueClass: "metricValue"
            }
        ];
    }

    buildRows(rows) {
        return rows.map((row) => {
            const scholarshipType = row.scholarshipType || "--";
            return {
                id: row.id,
                studentName: row.studentName || "--",
                studentId: row.studentId || "--",
                programme: row.programme || "--",
                scholarshipName: row.scholarshipName || "--",
                scholarshipType,
                typeClass: TYPE_CLASSES[scholarshipType] || "typeBadge typeNeutral",
                amountDeducted: this.formatCurrency(row.amountDeducted),
                appliedDate: this.formatDate(row.appliedDate),
                status: row.status || "Pending",
                statusClass: STATUS_CLASSES[row.status] || STATUS_CLASSES.Pending
            };
        });
    }

    formatCurrency(amountValue) {
        const amount = Number(amountValue || 0);
        if (!Number.isFinite(amount)) {
            return "INR 0.00";
        }
        return `INR ${amount.toLocaleString("en-IN", {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        })}`;
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

    getErrorMessage(error, fallbackMessage) {
        return error?.body?.message || fallbackMessage;
    }
}