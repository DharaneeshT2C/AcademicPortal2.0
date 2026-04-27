import { LightningElement } from "lwc";
import getStudentTransactionsDashboard from "@salesforce/apex/StudentTransactionsController.getStudentTransactionsDashboard";

const STATUS_CLASSES = {
    Success: "statusBadge statusSuccess",
    Failed: "statusBadge statusFailed",
    Pending: "statusBadge statusPending"
};

export default class StudentTransactions extends LightningElement {
    isLoading = false;
    errorMessage = "";
    metrics = [];
    transactionRows = [];

    connectedCallback() {
        this.loadDashboard();
    }

    async loadDashboard() {
        this.isLoading = true;
        this.errorMessage = "";

        try {
            const data = await getStudentTransactionsDashboard();
            this.metrics = this.buildMetrics(data);
            this.transactionRows = this.buildRows(data?.rows || []);
        } catch (error) {
            this.metrics = this.buildMetrics(null);
            this.transactionRows = [];
            this.errorMessage = this.getErrorMessage(error, "Unable to load student transactions.");
        } finally {
            this.isLoading = false;
        }
    }

    get hasRows() {
        return this.transactionRows.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.errorMessage && !this.hasRows;
    }

    buildMetrics(data) {
        const totalTransactionsToday = data?.totalTransactionsToday || 0;
        const totalCollectionToday = data?.totalCollectionToday || 0;
        const successfulPaymentsToday = data?.successfulPaymentsToday || 0;
        const failedOrPendingPaymentsToday = data?.failedOrPendingPaymentsToday || 0;

        return [
            {
                id: "transactionsToday",
                label: "Total Transactions Today",
                value: String(totalTransactionsToday),
                valueClass: "metricValue"
            },
            {
                id: "collectionToday",
                label: "Total Collection Today",
                value: this.formatCurrency(totalCollectionToday),
                valueClass: "metricValue metricValueSuccess"
            },
            {
                id: "successToday",
                label: "Successful Payments",
                value: String(successfulPaymentsToday),
                valueClass: "metricValue"
            },
            {
                id: "failureToday",
                label: "Failed / Pending Payments",
                value: String(failedOrPendingPaymentsToday),
                valueClass: "metricValue metricValueDanger"
            }
        ];
    }

    buildRows(rows) {
        return rows.map((row) => ({
            id: row.id,
            transactionId: row.transactionId || "--",
            studentName: row.studentName || "--",
            studentId: row.studentId || "--",
            programme: row.programme || "--",
            paymentMode: row.paymentMode || "--",
            amount: this.formatCurrency(row.amount),
            status: row.status || "Pending",
            statusClass: STATUS_CLASSES[row.status] || STATUS_CLASSES.Pending,
            paymentDate: this.formatDateTime(row.paymentDate)
        }));
    }

    formatCurrency(value) {
        const amount = Number(value || 0);
        if (!Number.isFinite(amount)) {
            return "INR 0.00";
        }
        return `INR ${amount.toLocaleString("en-IN", {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        })}`;
    }

    formatDateTime(value) {
        if (!value) {
            return "--";
        }
        const parsedDate = new Date(value);
        if (Number.isNaN(parsedDate.getTime())) {
            return "--";
        }
        return new Intl.DateTimeFormat("en-IN", {
            day: "2-digit",
            month: "short",
            year: "numeric",
            hour: "2-digit",
            minute: "2-digit"
        }).format(parsedDate);
    }

    getErrorMessage(error, fallbackMessage) {
        return error?.body?.message || fallbackMessage;
    }
}