import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import startFacultyImportBatch from "@salesforce/apex/FacultyImportController.startFacultyImportBatch";
import getFacultyImportErrors from "@salesforce/apex/FacultyImportController.getFacultyImportErrors";
import getBatchStatus from "@salesforce/apex/ImportUtils.getBatchStatus";

export default class FacultyImporter extends LightningElement {
  file;
  rows = [];
  headers = [
    "FirstName",
    "LastName",
    "Salutation",
    "Title",
    "AccountId",
    "OwnerId",
    "Phone",
    "MobilePhone",
    "Email",
    "ReportsToId",
    "CurrencyIsoCode",
    "MailingStreet",
    "MailingCity",
    "MailingState",
    "MailingPostalCode",
    "MailingCountry",
    "OtherStreet",
    "OtherCity",
    "OtherState",
    "OtherPostalCode",
    "OtherCountry",
    "Fax",
    "HomePhone",
    "OtherPhone",
    "AssistantName",
    "AssistantPhone",
    "LeadSource",
    "Birthdate",
    "Department",
    "Description",
    "BirthPlace",
    "Ethnicity",
    "MilitaryBranch",
    "MilitaryService",
    "HighestEducationLevel",
    "Race",
    "IsFirstGenerationStudent",
    "PrimaryCitizenshipType",
    "BirthCountryId",
    "PrimaryCitizenshipId",
    "SecondaryCitizenshipId",
    "Status",
    "EffectiveStartDate",
    "EffectiveEndDate",
    "ContextRecordId",
  ];
  // UI state: search / sort / pagination
  searchTerm = "";
  sortField = null;
  sortDirection = "asc";
  pageSize = 10;
  currentPage = 1;
  jobId;
  jobStatus = "";
  jobProcessed = 0;
  jobTotal = 0;
  jobErrors = 0;
  totalRecords = 0;
  pollHandle;
  failedRowIndexes = [];
  failedRows = [];
  failedRowErrors = {};
  unmatchedErrors = [];
  errorCount = 0;
  jobCompleted = false;
  processedSuccess = 0;

  get fileName() {
    return this.file ? this.file.name : "No file chosen";
  }

  get importDisabled() {
    return !this.file || !this.rows || this.rows.length === 0;
  }

  get failedCount() {
    if (this.failedRowIndexes && this.failedRowIndexes.length > 0) return this.failedRowIndexes.length;
    return this.errorCount || 0;
  }

  get failedDownloadDisabled() {
    return this.failedCount === 0;
  }

  get processedDisplay() {
    if (this.jobCompleted) return this.processedSuccess;
    return this.processedRecords;
  }

  get filteredRows() {
    const term = (this.searchTerm || "").trim().toLowerCase();
    if (!term) return this.rows || [];
    return (this.rows || []).filter((r) => {
      for (const k in r) {
        if (!Object.prototype.hasOwnProperty.call(r, k)) continue;
        const v = r[k];
        if (v != null && String(v).toLowerCase().indexOf(term) !== -1) return true;
      }
      return false;
    });
  }

  get sortedRows() {
    const arr = this.filteredRows.slice();
    if (!this.sortField) return arr;
    const f = this.sortField;
    const dir = this.sortDirection === "asc" ? 1 : -1;
    arr.sort((a, b) => {
      const va = a && a[f] != null ? String(a[f]) : "";
      const vb = b && b[f] != null ? String(b[f]) : "";
      if (va === vb) return 0;
      return va < vb ? -1 * dir : 1 * dir;
    });
    return arr;
  }

  get totalPages() {
    const len = this.sortedRows.length || 0;
    return Math.max(1, Math.ceil(len / this.pageSize));
  }

  get displayedRows() {
    const start = (this.currentPage - 1) * this.pageSize;
    return this.sortedRows.slice(start, start + this.pageSize);
  }

  get previewHeaders() {
    const base = [{ label: "#", field: "#" }];
    const rest = (this.headers || []).map((h) => ({ label: h, field: h }));
    return base.concat(rest);
  }

  get previewRowValues() {
    const hdrs = this.previewHeaders;
    if (!this.displayedRows || !hdrs) return [];
    const baseIndex = (this.currentPage - 1) * this.pageSize;
    return this.displayedRows.map((r, ri) => ({
      rowKey: "row-" + (baseIndex + ri),
      cells: hdrs.map((hObj, ci) => {
        if (ci === 0) {
          const num = baseIndex + ri + 1;
          return { key: "cell-" + (baseIndex + ri) + "-" + ci, value: String(num) };
        }
        const field = hObj.field;
        const val = r && r[field] != null ? r[field] : "";
        return { key: "cell-" + (baseIndex + ri) + "-" + ci, value: val };
      }),
    }));
  }

  handleFileChange(event) {
    const file = event.target.files[0];
    if (!file) return;
    this.file = file;
    const reader = new FileReader();
    reader.onload = () => {
      const text = reader.result;
      this.rows = this.parseCsv(text);
      this.searchTerm = "";
      this.sortField = null;
      this.sortDirection = "asc";
      this.pageSize = 10;
      this.currentPage = 1;
    };
    reader.readAsText(file);
  }

  parseCsv(text) {
    const lines = text.split(/\r?\n/).filter((l) => l.trim().length > 0);
    if (lines.length < 1) return [];
    const hdrs = lines[0].split(",").map((h) => h.trim());
    const out = [];
    for (let i = 1; i < lines.length; i++) {
      const cells = this.splitCsvLine(lines[i]);
      if (cells.length === 0) continue;
      const obj = {};
      for (let j = 0; j < hdrs.length; j++) {
        obj[hdrs[j]] = cells[j] ? cells[j].trim() : null;
      }
      if (!Object.prototype.hasOwnProperty.call(obj, "RowNumber")) {
        obj.RowNumber = String(i);
      }
      out.push(obj);
    }
    return out;
  }

  splitCsvLine(line) {
    const res = [];
    let cur = "";
    let inQuotes = false;
    for (let i = 0; i < line.length; i++) {
      const ch = line[i];
      if (ch === '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (ch === "," && !inQuotes) {
        res.push(cur);
        cur = "";
        continue;
      }
      cur += ch;
    }
    res.push(cur);
    return res;
  }

  handleImport() {
    if (!this.rows || this.rows.length === 0) return;
    this.failedRowIndexes = [];
    this.failedRows = [];
    this.failedRowErrors = {};
    this.unmatchedErrors = [];
    this.errorCount = 0;
    this.jobCompleted = false;
    this.processedSuccess = 0;
    startFacultyImportBatch({ jsonRows: JSON.stringify(this.rows) })
      .then((jobId) => {
        this.jobId = jobId;
        this.jobStatus = "Queued";
        this.totalRecords = this.rows ? this.rows.length : 0;
        this.startPolling();
        this.dispatchEvent(new ShowToastEvent({ title: "Import started", message: "Faculty batch job queued.", variant: "info" }));
      })
      .catch((err) => {
        const errMsg = err && err.body ? err.body.message : err && err.message ? err.message : String(err);
        this.dispatchEvent(new ShowToastEvent({ title: "Import failed", message: errMsg, variant: "error", mode: "sticky" }));
      });
  }

  startPolling() {
    if (this.pollHandle) clearInterval(this.pollHandle);
    this.pollHandle = setInterval(() => {
      if (!this.jobId) return;
      getBatchStatus({ jobId: this.jobId })
        .then((info) => {
          if (!info) return;
          this.jobStatus = info.status;
          this.jobProcessed = info.processed;
          this.jobTotal = info.total;
          this.jobErrors = info.errors;
          if (["Completed", "Failed", "Aborted"].includes(info.status)) {
            clearInterval(this.pollHandle);
            this.pollHandle = null;
            this.handleJobComplete();
          }
        })
        .catch(() => {
          // ignore polling errors
        });
    }, 2000);
  }

  handleJobComplete() {
    if (!this.jobId) return;
    getFacultyImportErrors({ jobId: this.jobId })
      .then((errors) => {
        const list = errors || [];
        this.errorCount = list.length;
        const idxSet = new Set();
        const rowErrors = {};
        const unmatched = [];
        for (const msg of list) {
          const idx = this.getRowIndexFromMessage(msg, this.rows, ["Email", "LastName"]);
          if (idx !== null) {
            if (!isNaN(idx) && idx >= 0) {
              idxSet.add(idx);
              rowErrors[idx] = rowErrors[idx] ? rowErrors[idx] + " | " + msg : msg;
              continue;
            }
          }
          unmatched.push(msg);
        }
        this.failedRowIndexes = Array.from(idxSet).sort((a, b) => a - b);
        this.failedRowErrors = rowErrors;
        this.unmatchedErrors = unmatched;
        this.failedRows = this.failedRowIndexes.map((i) => this.rows[i]).filter((r) => r);
        const failedCount = this.failedRowIndexes.length > 0 ? this.failedRowIndexes.length : list.length;
        this.processedSuccess = Math.max(0, (this.totalRecords || 0) - failedCount);
        this.errorCount = failedCount;
        this.jobCompleted = true;
        if (list.length > 0) {
          const first = list[0];
          const suffix = list.length > 1 ? " (+" + (list.length - 1) + " more)" : "";
          this.dispatchEvent(new ShowToastEvent({ title: "Import finished with errors", message: first + suffix, variant: "error", mode: "sticky" }));
        } else if (this.jobErrors && this.jobErrors > 0) {
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Import finished with errors",
              message: "Errors occurred during import. Check audit logs for details.",
              variant: "error",
              mode: "sticky",
            })
          );
        } else {
          this.dispatchEvent(new ShowToastEvent({ title: "Import completed", message: "Faculty records imported.", variant: "success" }));
        }
      })
      .catch((err) => {
        const errMsg = err && err.body ? err.body.message : err && err.message ? err.message : String(err);
        this.dispatchEvent(new ShowToastEvent({ title: "Import finished", message: errMsg, variant: "warning" }));
      });
  }

  get processedRecords() {
    const processed = (this.jobProcessed || 0) * 200;
    return Math.min(processed, this.totalRecords || 0);
  }

  handleSearchChange(e) {
    this.searchTerm = e.target.value || "";
    this.currentPage = 1;
  }

  handlePageSizeChange(e) {
    const v = parseInt(e.target.value, 10);
    if (!isNaN(v) && v > 0) {
      this.pageSize = v;
      this.currentPage = 1;
    }
  }

  handlePrevPage() {
    if (this.currentPage > 1) this.currentPage--;
  }

  handleNextPage() {
    if (this.currentPage < this.totalPages) this.currentPage++;
  }

  handleSort(e) {
    const field = e.currentTarget.dataset.field;
    if (!field || field === "#") return;
    if (this.sortField === field) {
      this.sortDirection = this.sortDirection === "asc" ? "desc" : "asc";
    } else {
      this.sortField = field;
      this.sortDirection = "asc";
    }
    this.currentPage = 1;
  }

  get sortActive() {
    return !!this.sortField;
  }

  get sortStatusText() {
    if (!this.sortField) return "";
    return this.sortField + " " + (this.sortDirection === "asc" ? "▲" : "▼");
  }

  get prevDisabled() {
    return this.currentPage <= 1;
  }

  get nextDisabled() {
    return this.currentPage >= this.totalPages;
  }

  handleDownloadFailed() {
    if ((this.failedRows && this.failedRows.length > 0) || (this.unmatchedErrors && this.unmatchedErrors.length > 0)) {
      const csv = this.buildFailedCsv();
      this.downloadCsv(csv, "faculty_failed_rows.csv");
    }
  }

  buildFailedCsv() {
    if (this.failedRows && this.failedRows.length > 0) {
      const headers = this.headers.concat(["ErrorMessage"]);
      const lines = [];
      lines.push(headers.join(","));
      for (const idx of this.failedRowIndexes) {
        const row = this.rows[idx];
        const cells = this.headers.map((h) => this.csvCell(row && row[h] != null ? row[h] : ""));
        const err = this.failedRowErrors && this.failedRowErrors[idx] ? this.failedRowErrors[idx] : "";
        cells.push(this.csvCell(err));
        lines.push(cells.join(","));
      }
      return "\uFEFF" + lines.join("\n");
    }
    const headers = ["RowNumber", "ErrorMessage"];
    const lines = [];
    lines.push(headers.join(","));
    for (const msg of this.unmatchedErrors || []) {
      lines.push(this.csvCell("") + "," + this.csvCell(msg));
    }
    return "\uFEFF" + lines.join("\n");
  }

  csvCell(value) {
    const s = String(value);
    if (s.includes("\"")) {
      return "\"" + s.replace(/\"/g, "\"\"") + "\"";
    }
    if (s.includes(",") || s.includes("\n") || s.includes("\r")) {
      return "\"" + s + "\"";
    }
    return s;
  }

  getRowIndexFromMessage(msg, rows, fallbackFields) {
    if (!msg) return null;
    const m = String(msg).match(/Row[^0-9]*(\d+)/i);
    if (m && m[1]) {
      const rowNum = parseInt(m[1], 10);
      if (!isNaN(rowNum)) {
        const byRowNumber = this.findRowIndexByFieldValue(rows, "RowNumber", String(rowNum));
        if (byRowNumber !== null) return byRowNumber;
        return rowNum - 1;
      }
    }
    const fb = this.findRowIndexByField(msg, rows, fallbackFields);
    if (fb !== null) return fb;
    return null;
  }

  findRowIndexByField(msg, rows, fields) {
    if (!msg || !rows || !fields) return null;
    const text = String(msg);
    for (const f of fields) {
      const re = new RegExp(f + "=([^\\)\\,]+)", "i");
      const m = text.match(re);
      if (m && m[1]) {
        const val = m[1].trim();
        for (let i = 0; i < rows.length; i++) {
          const r = rows[i];
          if (r && r[f] != null && String(r[f]).trim() === val) return i;
        }
      }
    }
    return null;
  }

  findRowIndexByFieldValue(rows, field, value) {
    if (!rows || !field) return null;
    for (let i = 0; i < rows.length; i++) {
      const r = rows[i];
      if (r && r[field] != null && String(r[field]).trim() === value) return i;
    }
    return null;
  }

  handleDownloadTemplate() {
    const csv = this.headers.join(",") + "\n";
    const csvWithBOM = "\uFEFF" + csv;

    try {
      const dataUri = "data:text/csv;charset=utf-8," + encodeURIComponent(csvWithBOM);
      const link = document.createElement("a");
      link.style.display = "none";
      link.href = dataUri;
      link.download = "faculty_template.csv";
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      return;
    } catch (e) {
      // fall through to blob approach
    }

    const blob = new Blob([csvWithBOM], { type: "text/csv;charset=utf-8;" });
    if (navigator && navigator.msSaveBlob) {
      navigator.msSaveBlob(blob, "faculty_template.csv");
      return;
    }
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.style.display = "none";
    a.href = url;
    a.download = "faculty_template.csv";
    document.body.appendChild(a);
    a.click();
    setTimeout(() => {
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    }, 500);
  }
}