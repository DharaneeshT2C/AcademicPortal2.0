import { api, LightningElement } from "lwc";
import sortSvg from "@salesforce/resourceUrl/sortsvg";

export default class FeePaymentsRefundsTable extends LightningElement {
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
      statusClass: row.status === "Refund Processed" ? "status-pill status-pill-success" : "status-pill status-pill-warn"
    }));

    const filtered = needle
      ? decoratedRows.filter((row) =>
          [row.refundId, row.initiatedDate, row.currency, row.amount, row.refundDate, row.transactionId, row.status].some((value) =>
            String(value || "").toLowerCase().includes(needle)
          )
        )
      : decoratedRows;

    return [...filtered].sort((first, second) =>
      this.sortDirection === "asc"
        ? this.parseInitiatedDate(first.initiatedDate) - this.parseInitiatedDate(second.initiatedDate)
        : this.parseInitiatedDate(second.initiatedDate) - this.parseInitiatedDate(first.initiatedDate)
    );
  }

  parseInitiatedDate(value) {
    if (!value) {
      return 0;
    }
    return new Date(value).getTime();
  }

  handleInitiatedDateSort() {
    this.sortDirection = this.sortDirection === "asc" ? "desc" : "asc";
  }

  handleDownload(event) {
    const row = (this.rows || []).find((item) => item.id === event.currentTarget.dataset.id);
    if (!row) {
      return;
    }
    const link = document.createElement("a");
    link.href = `data:text/plain;charset=utf-8,${encodeURIComponent(`Refund receipt for ${row.refundId}`)}`;
    link.download = `${row.refundId}-refund-receipt.txt`;
    link.click();
  }
}