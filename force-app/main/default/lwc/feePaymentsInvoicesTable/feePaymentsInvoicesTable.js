import { api, LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import sortSvg from "@salesforce/resourceUrl/sortsvg";

export default class FeePaymentsInvoicesTable extends LightningElement {
  @api searchTerm = "";
  @api rows = [];
  @api isLoading = false;
  sortIcon = sortSvg;
  sortDirection = "asc";

  get filteredRows() {
    const needle = String(this.searchTerm || "").trim().toLowerCase();
    const sourceRows = Array.isArray(this.rows) ? this.rows : [];
    const rows = needle
      ? sourceRows.filter((row) =>
      [row.particulars, row.invoiceId, row.invoiceDate, row.totalPaid, row.currency, row.remaining].some((value) =>
        String(value || "").toLowerCase().includes(needle)
      )
    )
      : [...sourceRows];

    return [...rows].sort((first, second) =>
      this.sortDirection === "asc"
        ? this.parseInvoiceDate(first.invoiceDate) - this.parseInvoiceDate(second.invoiceDate)
        : this.parseInvoiceDate(second.invoiceDate) - this.parseInvoiceDate(first.invoiceDate)
    );
  }

  parseInvoiceDate(value) {
    if (!value) {
      return 0;
    }
    return new Date(value).getTime();
  }

  handleInvoiceDateSort() {
    this.sortDirection = this.sortDirection === "asc" ? "desc" : "asc";
  }

  handleDownload(event) {
    const row = (this.rows || []).find((item) => item.id === event.currentTarget.dataset.id);
    const kind = event.currentTarget.dataset.kind;
    if (!row) {
      return;
    }
    const fileText = [`Document Type: ${kind}`, `Particulars: ${row.particulars}`, `Invoice ID: ${row.invoiceId}`].join("\n");
    const link = document.createElement("a");
    link.href = `data:text/plain;charset=utf-8,${encodeURIComponent(fileText)}`;
    link.download = `${row.invoiceId}-${kind}.txt`;
    link.click();
    this.dispatchEvent(new ShowToastEvent({ title: "Downloaded", message: `${kind} downloaded for ${row.invoiceId}.`, variant: "success" }));
  }
}