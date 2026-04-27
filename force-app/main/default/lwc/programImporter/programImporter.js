import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LightningConfirm from "lightning/confirm";
import startProgramImportBatch from "@salesforce/apex/ProgramImportController.startProgramImportBatch";
import getProgramImportResult from "@salesforce/apex/ProgramImportController.getProgramImportResult";
import getUniversities from "@salesforce/apex/KenImportUtils.getUniversities";
import getInstitutes from "@salesforce/apex/KenImportUtils.getInstitutes";
import getCampuses from "@salesforce/apex/KenImportUtils.getCampuses";
import getFacultyContacts from "@salesforce/apex/KenImportUtils.getFacultyContacts";
import getBatchStatus from "@salesforce/apex/KenImportUtils.getBatchStatus";

export default class ProgramImporter extends LightningElement {
  file;
  rows = [];
  headers = ["Name", "Program Code", "Program Alias", "Description", "Program Duration in Weeks", "Duration", "HOD Email", "Phone", "ActiveFromDate", "ActiveToDate"];
  universities = [];
  institutes = [];
  campuses = [];
  facultyEmailToId = {};
  selectedUniversityId = "";
  selectedInstituteId = "";
  selectedCampusId = "";
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
  insertedCount = 0;
  updatedCount = 0;
  showHelpModal = false;

  // UI state: search / sort / pagination
  searchTerm = "";
  sortField = null;
  sortDirection = "asc";
  pageSize = 10;
  currentPage = 1;
  previewVisible = false;

  get fileName() {
    return this.file ? this.file.name : "No file chosen";
  }

  get hasFile() {
    return !!this.file;
  }

  get showPreview() {
    return !!this.file && !!this.rows && this.rows.length > 0 && this.previewVisible;
  }

  get pageSizeValue() {
    return String(this.pageSize);
  }

  get importDisabled() {
    return !this.file || !this.rows || this.rows.length === 0 || !this.selectedInstituteId || !this.selectedCampusId;
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

  get instituteDisabled() {
    return !this.selectedUniversityId;
  }

  get helpExampleHeaders() {
    return this.headers;
  }

  get helpExampleRow() {
    const sample = {
      Name: "B.Tech Computer Science",
      "Program Code": "CSE101",
      "Program Alias": "BTech CS",
      Description: "Computer Science undergraduate program",
      "Program Duration in Weeks": "208",
      Duration: "4",
      "HOD Email": "hod@example.edu",
      Phone: "9876543210",
      ActiveFromDate: "2026-01-01",
      ActiveToDate: "2026-12-31",
    };
    return this.helpExampleHeaders.map((header, index) => ({
      key: `program-help-${index}`,
      value: sample[header] || "",
    }));
  }

  // filtered rows according to search
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

  // sorted rows according to sortField and direction
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
    if (this.pageSize >= len) return 1;
    return Math.max(1, Math.ceil(len / this.pageSize));
  }

  get displayedRows() {
    const start = (this.currentPage - 1) * this.pageSize;
    if (this.pageSize >= this.sortedRows.length) return this.sortedRows;
    return this.sortedRows.slice(start, start + this.pageSize);
  }

  // show headers with row number column
  get previewHeaders() {
    const base = [{ label: "#", field: "#" }];
    const rest = (this.headers || []).map((h) => ({ label: h, field: h }));
    return base.concat(rest);
  }

  // produce stable row keys and cell keys/values for template
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

    const fileName = (file.name || "").trim();
    if (!/\.csv$/i.test(fileName)) {
      this.file = null;
      this.rows = [];
      this.searchTerm = "";
      this.sortField = null;
      this.sortDirection = "asc";
      this.pageSize = 10;
      this.currentPage = 1;
      this.previewVisible = false;
      event.target.value = null;
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Invalid file type",
          message: "Please upload a CSV (.csv) file.",
          variant: "error",
          mode: "sticky",
        }),
      );
      return;
    }

    this.file = file;
    const reader = new FileReader();
    reader.onload = () => {
      const text = reader.result;
      const parsedRows = this.parseCsv(text);
      if (!this.hasMatchingTemplateHeaders(this.parsedHeaders, this.headers)) {
        const expectedHeaders = this.headers.join(", ");
        this.resetFileState();
        event.target.value = null;
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Template mismatch",
            message: `Upload the correct Program template. Expected headers: ${expectedHeaders}.`,
            variant: "error",
            mode: "sticky",
          }),
        );
        return;
      }
      this.rows = parsedRows;
      // reset UI state
      this.searchTerm = "";
      this.sortField = null;
      this.sortDirection = "asc";
      this.pageSize = 10;
      this.currentPage = 1;
      this.previewVisible = false;
    };
    reader.readAsText(file);
  }

  handleFileNameClick() {
    if (!this.file || !this.rows || this.rows.length === 0) return;
    this.previewVisible = true;
    this.scrollPreviewIntoView();
  }

  handleDeleteFile() {
    this.resetFileState();
  }

  scrollPreviewIntoView() {
    window.clearTimeout(this.previewScrollHandle);
    this.previewScrollHandle = window.setTimeout(() => {
      const previewSection = this.template.querySelector("[data-preview-section]");
      if (previewSection) {
        previewSection.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    }, 0);
  }

  connectedCallback() {
    this.loadUniversities();
    this.loadCampuses();
    this.loadFacultyContacts();
  }

  loadUniversities() {
    getUniversities()
      .then((data) => {
        this.universities = (data || []).map((u) => ({ label: u.name, value: u.id }));
      })
      .catch(() => {
        this.universities = [];
      });
  }

  loadInstitutes() {
    if (!this.selectedUniversityId) {
      this.institutes = [];
      return;
    }
    getInstitutes({ universityId: this.selectedUniversityId })
      .then((data) => {
        this.institutes = (data || []).map((i) => ({ label: i.name, value: i.id }));
      })
      .catch(() => {
        this.institutes = [];
      });
  }

  loadCampuses() {
    getCampuses()
      .then((data) => {
        this.campuses = (data || []).map((c) => ({ label: c.name, value: c.id }));
      })
      .catch(() => {
        this.campuses = [];
      });
  }

  loadFacultyContacts() {
    getFacultyContacts()
      .then((data) => {
        const nextMap = {};
        (data || []).forEach((con) => {
          const normalizedEmail = (con.email || "").trim().toLowerCase();
          if (normalizedEmail) {
            nextMap[normalizedEmail] = con.id;
          }
        });
        this.facultyEmailToId = nextMap;
      })
      .catch(() => {
        this.facultyEmailToId = {};
      });
  }

  parseCsv(text) {
    const rows = this.readCsvRows(text);
    if (!rows || rows.length < 1) return [];
    const hdrs = (rows[0] || []).map((h) => (h != null ? String(h).trim() : ""));
    this.parsedHeaders = hdrs;
    const out = [];
    for (let i = 1; i < rows.length; i++) {
      const cells = rows[i] || [];
      if (cells.length === 0) continue;
      const obj = {};
      for (let j = 0; j < hdrs.length; j++) {
        obj[hdrs[j]] = cells[j] != null ? String(cells[j]).trim() : null;
      }
      if (!Object.prototype.hasOwnProperty.call(obj, "RowNumber")) {
        obj.RowNumber = String(i);
      }
      out.push(obj);
    }
    return out;
  }

  hasMatchingTemplateHeaders(actualHeaders, expectedHeaders) {
    const actual = (actualHeaders || []).map((header) => String(header || "").trim().toLowerCase());
    const expected = (expectedHeaders || []).map((header) => String(header || "").trim().toLowerCase());
    if (actual.length !== expected.length) {
      return false;
    }
    for (let i = 0; i < expected.length; i++) {
      if (actual[i] !== expected[i]) {
        return false;
      }
    }
    return true;
  }

  readCsvRows(text) {
    const input = String(text || "").replace(/^\uFEFF/, "");
    const rows = [];
    let row = [];
    let cell = "";
    let inQuotes = false;

    for (let i = 0; i < input.length; i++) {
      const ch = input[i];
      if (ch === '"') {
        if (inQuotes && input[i + 1] === '"') {
          cell += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (ch === "," && !inQuotes) {
        row.push(cell);
        cell = "";
        continue;
      }
      if ((ch === "\n" || ch === "\r") && !inQuotes) {
        row.push(cell);
        cell = "";
        rows.push(row);
        row = [];
        if (ch === "\r" && input[i + 1] === "\n") i++;
        continue;
      }
      cell += ch;
    }

    if (cell.length > 0 || row.length > 0) {
      row.push(cell);
      rows.push(row);
    }

    return rows.filter((r) => (r || []).some((c) => String(c || "").trim().length > 0));
  }

  splitCsvLine(line) {
    // simple CSV parsing supporting quoted values
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

  async handleImport() {
    if (!this.rows || this.rows.length === 0 || !this.selectedInstituteId || !this.selectedCampusId) return;
    const rowCount = this.rows ? this.rows.length : 0;
    const confirmed = await LightningConfirm.open({
      label: "Confirm import",
      message: `Start importing ${rowCount} program record${rowCount === 1 ? "" : "s"}? This will queue a batch job.`,
      theme: "warning",
    });
    if (!confirmed) return;

    this.failedRowIndexes = [];
    this.failedRows = [];
    this.failedRowErrors = {};
    this.unmatchedErrors = [];
    this.errorCount = 0;
    this.jobCompleted = false;
    this.processedSuccess = 0;
    this.insertedCount = 0;
    this.updatedCount = 0;
    startProgramImportBatch({ jsonRows: JSON.stringify(this.buildImportRows()), providerId: this.selectedInstituteId, campusId: this.selectedCampusId })
      .then((jobId) => {
        this.jobId = jobId;
        this.jobStatus = "Queued";
        this.totalRecords = this.rows ? this.rows.length : 0;
        this.startPolling();
        this.dispatchEvent(new ShowToastEvent({ title: "Import started", message: "Program batch job queued.", variant: "info" }));
      })
      .catch((err) => {
        const errMsg = err && err.body ? err.body.message : err && err.message ? err.message : String(err);
        this.dispatchEvent(new ShowToastEvent({ title: "Import failed", message: errMsg, variant: "error", mode: "sticky" }));
      });
  }

  buildImportRows() {
    return (this.rows || []).map((row) => {
      const filteredRow = {};
      filteredRow.Name = row ? row.Name : null;
      filteredRow.CipCode = row ? row["Program Code"] || row.CipCode : null;
      filteredRow.Description = row ? row.Description : null;
      filteredRow.Alias__c = row ? row["Program Alias"] : null;
      filteredRow.Program_Duration_in_Weeks__c = row ? row["Program Duration in Weeks"] : null;
      filteredRow.Duration = row ? row.Duration : null;
      filteredRow.DurationUnit = "Years";
      filteredRow.Phone = row ? row.Phone : null;
      filteredRow.ActiveFromDate = row ? row.ActiveFromDate : null;
      filteredRow.ActiveToDate = row ? row.ActiveToDate : null;
      filteredRow.RowNumber = row ? row.RowNumber : null;

      const hodEmail = (row["HOD Email"] || "").trim().toLowerCase();
      if (hodEmail && this.facultyEmailToId[hodEmail]) {
        filteredRow.HOD__c = this.facultyEmailToId[hodEmail];
      }
      if (this.selectedInstituteId) {
        filteredRow.Institute__c = this.selectedInstituteId;
      }
      return filteredRow;
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
    getProgramImportResult({ jobId: this.jobId })
      .then((result) => {
        const list = (result && result.errors) || [];
        this.insertedCount = result && typeof result.insertedCount === "number" ? result.insertedCount : 0;
        this.updatedCount = result && typeof result.updatedCount === "number" ? result.updatedCount : 0;
        this.errorCount = list.length;
        const idxSet = new Set();
        const rowErrors = {};
        const unmatched = [];
        for (const msg of list) {
          const idx = this.getRowIndexFromMessage(msg, this.rows, ["Name"]);
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
        this.processedSuccess = this.insertedCount + this.updatedCount;
        this.errorCount = failedCount;
        this.jobCompleted = true;
        if (list.length > 0) {
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Import finished with errors",
              message: `${this.insertedCount} inserted, ${this.updatedCount} updated, ${failedCount} failed. Download failed rows for details.`,
              variant: "error",
              mode: "sticky",
            }),
          );
        } else if (this.jobErrors && this.jobErrors > 0) {
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Import finished with errors",
              message: `${this.insertedCount} inserted, ${this.updatedCount} updated. Errors occurred during import. Check audit logs for details.`,
              variant: "error",
              mode: "sticky",
            }),
          );
        } else {
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Import completed",
              message: `${this.insertedCount} inserted, ${this.updatedCount} updated successfully.`,
              variant: "success",
            }),
          );
        }
        this.notifyImportRefresh();
      })
      .catch((err) => {
        const errMsg = err && err.body ? err.body.message : err && err.message ? err.message : String(err);
        this.dispatchEvent(new ShowToastEvent({ title: "Import finished", message: errMsg, variant: "warning" }));
      });
  }

  notifyImportRefresh() {
    window.clearTimeout(this.refreshImportHandle);
    this.refreshImportHandle = window.setTimeout(() => {
      this.dispatchEvent(new CustomEvent("refreshimport", { bubbles: true, composed: true }));
    }, 0);
  }

  handleDownloadFailed() {
    if ((this.failedRows && this.failedRows.length > 0) || (this.unmatchedErrors && this.unmatchedErrors.length > 0)) {
      const csv = this.buildFailedCsv();
      this.downloadCsv(csv, "program_failed_rows.csv");
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

  buildCsv(headers, rows) {
    const lines = [];
    lines.push(headers.join(","));
    for (const row of rows) {
      const cells = headers.map((h) => this.csvCell(row && row[h] != null ? row[h] : ""));
      lines.push(cells.join(","));
    }
    return "\uFEFF" + lines.join("\n");
  }

  csvCell(value) {
    const s = String(value);
    if (s.includes('"')) {
      return '"' + s.replace(/\"/g, '""') + '"';
    }
    if (s.includes(",") || s.includes("\n") || s.includes("\r")) {
      return '"' + s + '"';
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

  downloadCsv(csvText, filename) {
    try {
      const dataUri = "data:text/csv;charset=utf-8," + encodeURIComponent(csvText);
      const link = document.createElement("a");
      link.style.display = "none";
      link.href = dataUri;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      return;
    } catch (e) {
      // fall through to blob approach
    }
    const blob = new Blob([csvText], { type: "text/csv;charset=utf-8;" });
    if (navigator && navigator.msSaveBlob) {
      navigator.msSaveBlob(blob, filename);
      return;
    }
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.style.display = "none";
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    setTimeout(() => {
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    }, 500);
  }

  get processedRecords() {
    const processed = (this.jobProcessed || 0) * 200;
    return Math.min(processed, this.totalRecords || 0);
  }

  handleUniversityChange(e) {
    this.selectedUniversityId = e.detail.value;
    this.selectedInstituteId = "";
    this.loadInstitutes();
  }

  handleInstituteChange(e) {
    this.selectedInstituteId = e.detail.value;
  }

  handleCampusChange(e) {
    this.selectedCampusId = e.detail.value;
  }

  /* Search / Sort / Paging handlers */
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

  handleDownloadTemplate() {
    const csv = this.headers.join(",") + "\n";
    // Prepend BOM so Excel recognises UTF-8 CSVs on Windows
    const csvWithBOM = "\uFEFF" + csv;

    // Try data URI first (simple, works in many browsers)
    try {
      const dataUri = "data:text/csv;charset=utf-8," + encodeURIComponent(csvWithBOM);
      const link = document.createElement("a");
      link.style.display = "none";
      link.href = dataUri;
      link.download = "learning_program_template.csv";
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      return;
    } catch (e) {
      // fall through to blob approach
    }

    // Fallback: use Blob + createObjectURL
    const blob = new Blob([csvWithBOM], { type: "text/csv;charset=utf-8;" });
    if (navigator && navigator.msSaveBlob) {
      // IE10+
      navigator.msSaveBlob(blob, "learning_program_template.csv");
      return;
    }
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.style.display = "none";
    a.href = url;
    a.download = "learning_program_template.csv";
    document.body.appendChild(a);
    a.click();
    setTimeout(() => {
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    }, 500);
  }

  handleOpenHelp() {
    this.showHelpModal = true;
  }

  handleCloseHelp() {
    this.showHelpModal = false;
  }

  resetFileState() {
    if (this.pollHandle) {
      clearInterval(this.pollHandle);
      this.pollHandle = null;
    }
    window.clearTimeout(this.previewScrollHandle);
    this.file = null;
    this.rows = [];
    this.parsedHeaders = [];
    this.jobId = null;
    this.jobStatus = "";
    this.jobProcessed = 0;
    this.jobTotal = 0;
    this.jobErrors = 0;
    this.totalRecords = 0;
    this.searchTerm = "";
    this.sortField = null;
    this.sortDirection = "asc";
    this.pageSize = 10;
    this.currentPage = 1;
    this.previewVisible = false;
    this.failedRowIndexes = [];
    this.failedRows = [];
    this.failedRowErrors = {};
    this.unmatchedErrors = [];
    this.errorCount = 0;
    this.jobCompleted = false;
    this.processedSuccess = 0;
    this.showHelpModal = false;
    this.insertedCount = 0;
    this.updatedCount = 0;
    const fileInput = this.template.querySelector('input[type="file"]');
    if (fileInput) {
      fileInput.value = null;
    }
  }
}