import { LightningElement, wire } from "lwc";
import getFeeAssignmentsDashboard from "@salesforce/apex/FeeAssignmentsController.getFeeAssignmentsDashboard";

export default class FeeAssignments extends LightningElement {
    metrics = [
        { key: "totalAssignments", label: "TOTAL FEE ASSIGNMENTS", value: "0" },
        { key: "activeAssignments", label: "ACTIVE ASSIGNMENTS", value: "0" },
        { key: "studentsWithScholarships", label: "STUDENTS WITH SCHOLARSHIPS", value: "0" },
        { key: "outstandingBalance", label: "OUTSTANDING BALANCE", value: "INR 0" }
    ];

    studentRows = [];
    errorMessage;
    isLoading = true;

    @wire(getFeeAssignmentsDashboard)
    wiredFeeAssignments({ data, error }) {
        this.isLoading = false;

        if (data) {
            this.errorMessage = null;
            this.studentRows = (data.rows || []).map((row) => this.mapStudentRow(row));
            this.metrics = this.buildMetrics(data.metrics);
            return;
        }

        this.studentRows = [];
        this.metrics = this.buildMetrics();
        this.errorMessage = this.getErrorMessage(error);
    }

    mapStudentRow(row) {
        const status = row?.status || "--";
        return {
            key: row?.id,
            name: row?.studentName || "--",
            programme: row?.programme || "--",
            batch: "--",
            feePlan: "--",
            totalFee: this.formatCurrency(row?.totalFee, row?.currencyIsoCode),
            scholarshipApplied: this.formatCurrency(row?.scholarshipApplied, row?.currencyIsoCode),
            finalPayable: this.formatCurrency(row?.finalPayable, row?.currencyIsoCode),
            status,
            statusClass: this.getStatusClass(status)
        };
    }

    getStatusClass(status) {
        return String(status || "").toLowerCase() === "active"
            ? "statusBadge statusActive"
            : "statusBadge statusModified";
    }

    formatCurrency(value, currencyCode) {
        if (value === null || value === undefined) {
            return "--";
        }

        const normalizedCurrency = currencyCode || "INR";
        try {
            return new Intl.NumberFormat("en-IN", {
                style: "currency",
                currency: normalizedCurrency,
                maximumFractionDigits: 2
            }).format(Number(value));
        } catch (error) {
            return `${normalizedCurrency} ${Number(value).toLocaleString("en-IN", { maximumFractionDigits: 2 })}`;
        }
    }

    formatCompactCurrency(value, currencyCode) {
        if (value === null || value === undefined) {
            return "INR 0";
        }

        const normalizedCurrency = currencyCode || "INR";
        try {
            return new Intl.NumberFormat("en-IN", {
                style: "currency",
                currency: normalizedCurrency,
                notation: "compact",
                compactDisplay: "short",
                maximumFractionDigits: 2
            }).format(Number(value));
        } catch (error) {
            return `${normalizedCurrency} ${Number(value).toLocaleString("en-IN", { maximumFractionDigits: 2 })}`;
        }
    }

    buildMetrics(serverMetrics) {
        const totalAssignments = serverMetrics?.totalFeeAssignments || 0;
        const activeAssignments = serverMetrics?.activeAssignments || 0;
        const studentsWithScholarships = serverMetrics?.studentsWithScholarships || 0;
        const outstandingBalance = this.formatCompactCurrency(
            serverMetrics?.outstandingBalance || 0,
            serverMetrics?.outstandingCurrencyIsoCode
        );

        return [
            { key: "totalAssignments", label: "TOTAL FEE ASSIGNMENTS", value: String(totalAssignments) },
            { key: "activeAssignments", label: "ACTIVE ASSIGNMENTS", value: String(activeAssignments) },
            {
                key: "studentsWithScholarships",
                label: "STUDENTS WITH SCHOLARSHIPS",
                value: String(studentsWithScholarships)
            },
            { key: "outstandingBalance", label: "OUTSTANDING BALANCE", value: outstandingBalance }
        ];
    }

    get hasStudents() {
        return this.studentRows.length > 0;
    }

    getErrorMessage(error) {
        return error?.body?.message || "Unable to load fee assignments.";
    }
}