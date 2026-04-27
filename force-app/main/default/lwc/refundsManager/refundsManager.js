import { LightningElement, wire, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getRefundDashboardData from "@salesforce/apex/RefundManagerController.getRefundDashboardData";
import updateRefunds from "@salesforce/apex/RefundManagerController.updateRefunds";
import REFUND_OBJECT from "@salesforce/schema/Refund__c";
const STATUS_CLASSES = {
    Initiated: "statusBadge statusInitiated",
    Refunded: "statusBadge statusRefunded",
    Rejected: "statusBadge statusRejected"
};

const OVERVIEW_CLASS_MAP = {
    Initiated: "overviewBlock overviewInitiated",
    Refunded: "overviewBlock overviewRefunded",
    Rejected: "overviewBlock overviewRejected"
};

export default class RefundsManager extends NavigationMixin(LightningElement) {
    @track metrics = [];
    @track overviewBlocks = [];
    @track refundRows = [];
    @track error;

    refundObjectApiName = REFUND_OBJECT;

    isLoading = true;
    isSaving = false;
    showModal = false;
    showBulkModal = false;

    wiredDashboardResult;
    selectedRowIds = [];

    utrNumber = "";
    bulkRefundDate = "";

    @wire(getRefundDashboardData)
    wiredRefundDashboard(result) {
        this.wiredDashboardResult = result;
        this.isLoading = false;

        const { data, error } = result;

        if (data) {
            this.error = undefined;
            this.metrics = this.mapMetrics(data.summary);
            this.overviewBlocks = this.mapOverviewBlocks(data.statusOverview);
            this.refundRows = this.mapRefundRows(data.transactions);
        } else if (error) {
            this.error = error;
            this.metrics = [];
            this.overviewBlocks = [];
            this.refundRows = [];
        }
    }

    openModal() {
        this.showModal = true;
    }

    closeModal() {
        if (this.isSaving) {
            return;
        }
        this.showModal = false;
    }

    handleSubmit(event) {
        event.preventDefault();
        this.isSaving = true;

        const fields = { ...event.detail.fields };
        fields.Status__c = "Initiated";

        this.template.querySelector(".createRefundForm").submit(fields);
    }

    async handleSuccess() {
        this.isSaving = false;

        this.dispatchEvent(
            new ShowToastEvent({
                title: "Success",
                message: "Refund record created successfully.",
                variant: "success"
            })
        );

        this.closeModal();

        if (this.wiredDashboardResult) {
            await refreshApex(this.wiredDashboardResult);
        }
    }

    handleError(event) {
        this.isSaving = false;

        this.dispatchEvent(
            new ShowToastEvent({
                title: "Error",
                message: event.detail?.message || "Error processing request.",
                variant: "error"
            })
        );
    }

    mapMetrics(summary = {}) {
        return [
            {
                id: "requestsToday",
                label: "Refund Requests Today",
                value: this.getSafeNumber(summary.refundRequestsToday),
                valueClass: "metricValue"
            },
            {
                id: "initiated",
                label: "Initiated",
                value: this.getSafeNumber(summary.initiatedCount),
                valueClass: "metricValue metricValueWarning"
            },
            {
                id: "refunded",
                label: "Refunded",
                value: this.getSafeNumber(summary.refundedCount),
                valueClass: "metricValue metricValueSuccess"
            },
            {
                id: "totalRefunded",
                label: "Total Refunded Amount",
                value: this.formatCurrencyCompact(summary.totalRefundedAmount),
                valueClass: "metricValue metricValueInfo"
            }
        ];
    }

    mapOverviewBlocks(statusOverview = []) {
        const statusMap = {};

        statusOverview.forEach((item) => {
            statusMap[item.status] = item;
        });

        const orderedStatuses = ["Initiated", "Refunded", "Rejected"];

        return orderedStatuses.map((status) => ({
            id: status.toLowerCase(),
            label: status.toUpperCase(),
            value: this.getSafeNumber(statusMap[status]?.count),
            blockClass: OVERVIEW_CLASS_MAP[status] || "overviewBlock"
        }));
    }

    mapRefundRows(transactions = []) {
        return transactions.map((row) => ({
            id: row.recordId,
            refundId: row.refundId || "",
            studentName: row.studentName || "",
            studentId: row.studentId || "",
            amount: this.formatCurrency(row.amount),
            withdrawalAmount: this.formatCurrency(row.withdrawalAmount),
            refundAmount: this.formatCurrency(row.refundAmount),
            status: row.status || "",
            statusClass: STATUS_CLASSES[row.status] || "statusBadge",
            refundDate: this.formatDateTime(row.refundDate),
            utrNumber: row.utrNumber || "",
            isSelectable: row.status !== "Refunded",
            isChecked: this.selectedRowIds.includes(row.recordId)
        }));
    }

    getSafeNumber(value) {
        return value ?? 0;
    }

    formatCurrency(amount) {
        const safeAmount = amount ?? 0;
        return new Intl.NumberFormat("en-IN", {
            style: "currency",
            currency: "INR",
            maximumFractionDigits: 0
        }).format(safeAmount);
    }

    formatCurrencyCompact(amount) {
        const safeAmount = amount ?? 0;

        if (safeAmount >= 100000) {
            const lakhs = safeAmount / 100000;
            return `₹${lakhs.toFixed(lakhs % 1 === 0 ? 0 : 1)}L`;
        }

        return this.formatCurrency(safeAmount);
    }

    formatDateTime(dateValue) {
        if (!dateValue) {
            return "";
        }

        try {
            const dt = new Date(dateValue);
            return new Intl.DateTimeFormat("en-GB", {
                day: "2-digit",
                month: "short",
                year: "numeric",
                hour: "2-digit",
                minute: "2-digit",
                hour12: true
            }).format(dt);
        } catch (e) {
            return dateValue;
        }
    }

    handleRefundClick(event) {
        const recordId = event.currentTarget.dataset.id;
        this.navigateToRecord(recordId);
    }

    handleTransactionClick(event) {
        const recordId = event.currentTarget.dataset.id;
        this.navigateToRecord(recordId);
    }

    navigateToRecord(recordId) {
        if (!recordId) {
            return;
        }

        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: recordId,
                actionName: "view"
            }
        });
    }

    handleRowSelect(event) {
        const recordId = event.target.dataset.id;
        const checked = event.target.checked;

        if (checked) {
            if (!this.selectedRowIds.includes(recordId)) {
                this.selectedRowIds = [...this.selectedRowIds, recordId];
            }
        } else {
            this.selectedRowIds = this.selectedRowIds.filter((id) => id !== recordId);
        }

        this.syncRowSelections();
    }

    handleSelectAll(event) {
        const checked = event.target.checked;

        if (checked) {
            const selectableIds = this.refundRows
                .filter((row) => row.isSelectable)
                .map((row) => row.id);
            this.selectedRowIds = [...selectableIds];
        } else {
            this.selectedRowIds = [];
        }

        this.syncRowSelections();
    }

    syncRowSelections() {
        this.refundRows = this.refundRows.map((row) => ({
            ...row,
            isChecked: this.selectedRowIds.includes(row.id)
        }));
    }

    get hasSelectedRows() {
        return this.selectedRowIds.length > 0;
    }

    openBulkModal() {
        this.showBulkModal = true;
    }

    closeBulkModal() {
        if (this.isSaving) {
            return;
        }
        this.showBulkModal = false;
        this.utrNumber = "";
        this.bulkRefundDate = "";
    }

    handleUtrChange(event) {
        this.utrNumber = event.target.value;
    }

    handleBulkDateChange(event) {
        this.bulkRefundDate = event.target.value;
    }

    async handleBulkUpdate() {
        if (!this.selectedRowIds.length) {
            this.showToast("Warning", "Please select at least one record.", "warning");
            return;
        }

        if (!this.utrNumber || !this.bulkRefundDate) {
            this.showToast("Warning", "Please enter UTR Number and Refunded Date.", "warning");
            return;
        }

        try {
            this.isSaving = true;

            await updateRefunds({
                recordIds: this.selectedRowIds,
                utrNumber: this.utrNumber,
                refundedDate: this.bulkRefundDate
            });

            this.showToast("Success", "Selected records updated successfully.", "success");

            this.selectedRowIds = [];
            this.closeBulkModal();

            if (this.wiredDashboardResult) {
                await refreshApex(this.wiredDashboardResult);
            }
        } catch (error) {
            console.error("Error updating refunds:", JSON.stringify(error) );
            this.showToast("Error", this.reduceError(error), "error");
        } finally {
            this.isSaving = false;
        }
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(", ");
        }
        return error?.body?.message || error?.message || "Unknown error";
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}