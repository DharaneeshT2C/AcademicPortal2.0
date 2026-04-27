import { api, LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import sortSvg from "@salesforce/resourceUrl/sortsvg";

export default class FeePaymentsTransactionsTable extends LightningElement {
  @api searchTerm = "";
  @api rows = [];
  @api isLoading = false;
  sortIcon = sortSvg;
  sortDirection = "asc";

  get filteredRows() {
    const needle = String(this.searchTerm || "").trim().toLowerCase();
    const sourceRows = Array.isArray(this.rows) ? this.rows : [];
    const decoratedRows = sourceRows.map((row) => ({
      ...row,
      isFailed: row.status === "Failed",
      statusClass: row.status === "Failed" ? "status-pill status-pill-error" : "status-pill status-pill-success"
    }));

    const filtered = needle
      ? decoratedRows.filter((row) =>
          [row.transactionId, row.transactionDate, row.paymentMode, row.currency, row.totalPaid, row.status].some((value) =>
            String(value || "").toLowerCase().includes(needle)
          )
        )
      : decoratedRows;

    return [...filtered].sort((first, second) =>
      this.sortDirection === "asc"
        ? this.parseTransactionDate(first.transactionDate) - this.parseTransactionDate(second.transactionDate)
        : this.parseTransactionDate(second.transactionDate) - this.parseTransactionDate(first.transactionDate)
    );
  }

  parseTransactionDate(value) {
    if (!value) {
      return 0;
    }
    return new Date(value).getTime();
  }

  handleTransactionDateSort() {
    this.sortDirection = this.sortDirection === "asc" ? "desc" : "asc";
  }

  handleRetry(event) {
    const row = (this.rows || []).find((item) => item.id === event.currentTarget.dataset.id);
    if (!row) {
      return;
    }
    this.dispatchEvent(new ShowToastEvent({ title: "Retry started", message: `Retry triggered for ${row.transactionId}.`, variant: "info" }));
  }

  handleDownload(event) {
    const row = (this.rows || []).find((item) => item.id === event.currentTarget.dataset.id);
    if (!row) {
      return;
    }
    const link = document.createElement("a");
    link.href = `data:text/plain;charset=utf-8,${encodeURIComponent(`Receipt for ${row.transactionId}`)}`;
    link.download = `${row.transactionId}-receipt.txt`;
    link.click();
  }
}