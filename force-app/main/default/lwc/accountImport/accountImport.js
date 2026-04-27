import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LightningConfirm from "lightning/confirm";
import startAccountImportBatch from "@salesforce/apex/KenAccountImportController.startAccountImportBatch";
import getAccountImportErrors from "@salesforce/apex/KenAccountImportController.getAccountImportErrors";
import getParentAccountsForImport from "@salesforce/apex/KenImportUtils.getParentAccountsForImport";
import getFacultyContacts from "@salesforce/apex/KenImportUtils.getFacultyContacts";
import getLocations from "@salesforce/apex/KenImportUtils.getLocations";
import getBatchStatus from "@salesforce/apex/KenImportUtils.getBatchStatus";

const COMMON_SUPPORTED_FIELDS = ["Name", "Phone", "Website", "Description", "BillingStreet", "Location__c"];
const ACCOUNT_TEMPLATE_CONFIG = {
  University: {
    filename: "university_account_template.csv",
    columns: ["Name", "Description", "Website", "Phone", "Address"],
    supportedFields: COMMON_SUPPORTED_FIELDS,
  },
  Institute: {
    filename: "institute_account_template.csv",
    columns: ["Name", "Type", "Description", "Website", "Phone", "Address"],
    supportedFields: COMMON_SUPPORTED_FIELDS.concat(["Type"]),
  },
  Department: {
    filename: "department_account_template.csv",
    columns: ["Name", "Type", "Code", "Phone", "Head of Department Email", "Description", "Address"],
    supportedFields: ["Name", "Type", "Code__c", "Phone", "Description", "BillingStreet", "Location__c", "Head_of_Department__c"],
  },
  School: {
    filename: "school_account_template.csv",
    columns: ["Name", "Description", "Campus (City/Location)", "Website", "Phone", "Address"],
    supportedFields: COMMON_SUPPORTED_FIELDS,
  },
};

export default class AccountImport extends LightningElement {
  file;
  rows = [];
  csvHeaders = [];

  recordTypeOptions = [
    { label: "University", value: "University" },
    { label: "Institute", value: "Institute" },
    { label: "Department", value: "Department" },
    { label: "School", value: "School" },
  ];
  selectedRecordType = "";

  parentOptions = [];
  selectedParentId = "";
  locationOptions = [];
  selectedLocationId = "";
  facultyEmailToId = {};

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
  showHelpModal = false;

  // UI state: search / sort / pagination
  searchTerm = "";
  sortField = null;
  sortDirection = "asc";
  pageSize = 10;
  currentPage = 1;
  previewVisible = false;

  connectedCallback() {
    this.loadParents();
    this.loadFacultyContacts();
    this.loadLocations();
  }

  loadParents() {
    const rt = this.selectedRecordType || null;
    getParentAccountsForImport({ recordTypeName: rt })
      .then((data) => {
        this.parentOptions = (data || []).map((a) => ({ label: a.name, value: a.id }));
        if (this.selectedParentId && !this.parentOptions.some((o) => o.value === this.selectedParentId)) {
          this.selectedParentId = "";
        }
      })
      .catch(() => {
        this.parentOptions = [];
        this.selectedParentId = "";
      });
  }

  loadLocations() {
    getLocations()
      .then((data) => {
        this.locationOptions = (data || []).map((loc) => ({ label: loc.name, value: loc.id }));
      })
      .catch(() => {
        this.locationOptions = [];
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

  get templateConfig() {
    return ACCOUNT_TEMPLATE_CONFIG[this.selectedRecordType] || null;
  }

  get templateHeaders() {
    return this.templateConfig ? this.templateConfig.columns : COMMON_SUPPORTED_FIELDS;
  }

  get activeHeaders() {
    return this.csvHeaders && this.csvHeaders.length > 0 ? this.csvHeaders : this.templateHeaders;
  }

  get supportedFields() {
    return this.templateConfig ? this.templateConfig.supportedFields : COMMON_SUPPORTED_FIELDS;
  }

  get templateHelpText() {
    if (!this.selectedRecordType) {
      return "Select a record type to download the matching template.";
    }
    if (this.selectedRecordType === "Institute") {
      return 'For Institute imports, enter Type exactly as either "Autonomous" or "Autonomous and Non-Autonomous".';
    }
    if (this.selectedRecordType === "Department") {
      return 'For Department imports, enter Type exactly as either "Academic" or "Non-Academic".';
    }
    return "";
  }

  get helpNotes() {
    if (this.selectedRecordType === "Institute") {
      return ['Enter Type exactly as "Autonomous" or "Autonomous and Non-Autonomous".'];
    }
    if (this.selectedRecordType === "Department") {
      return ['Enter Type exactly as "Academic" or "Non-Academic".'];
    }
    return [];
  }

  get hasHelpNotes() {
    return this.helpNotes.length > 0;
  }

  get helpExampleHeaders() {
    return this.templateHeaders;
  }

  get helpExampleRow() {
    const sampleRowsByType = {
      University: {
        Name: "Kenverse University",
        Description: "University description",
        Website: "https://example.edu",
        Phone: "9876543210",
        Address: "123 University Road",
      },
      Institute: {
        Name: "School of Engineering",
        Type: "Autonomous",
        Description: "Institute description",
        Website: "https://example.edu/engineering",
        Phone: "9876543210",
        Address: "45 Engineering Block",
      },
      Department: {
        Name: "Computer Science",
        Type: "Academic",
        Code: "CSE",
        Phone: "9876543210",
        "Head of Department Email": "hod@example.edu",
        Description: "Department description",
        Address: "Block A, Floor 2",
      },
      School: {
        Name: "School of Management",
        Description: "School description",
        "Campus (City/Location)": "Bengaluru",
        Website: "https://example.edu/management",
        Phone: "9876543210",
        Address: "78 Management Avenue",
      },
    };
    const sample = sampleRowsByType[this.selectedRecordType] || sampleRowsByType.University;
    return this.helpExampleHeaders.map((header, index) => ({
      key: `account-help-${index}`,
      value: sample[header] || "",
    }));
  }

  get downloadDisabled() {
    return !this.selectedRecordType;
  }

  get importDisabled() {
    return !this.file || !this.rows || this.rows.length === 0 || !this.selectedRecordType;
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
    if (this.pageSize >= len) return 1;
    return Math.max(1, Math.ceil(len / this.pageSize));
  }

  get displayedRows() {
    const start = (this.currentPage - 1) * this.pageSize;
    if (this.pageSize >= this.sortedRows.length) return this.sortedRows;
    return this.sortedRows.slice(start, start + this.pageSize);
  }

  get previewHeaders() {
    const base = [{ label: "#", field: "#" }];
    const rest = (this.activeHeaders || []).map((h) => ({ label: h, field: h }));
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

    if (!this.selectedRecordType) {
      event.target.value = null;
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Select record type",
          message: "Choose the account record type before uploading a template.",
          variant: "warning",
        }),
      );
      return;
    }

    const fileName = (file.name || "").trim();
    if (!/\.csv$/i.test(fileName)) {
      this.file = null;
      this.rows = [];
      this.csvHeaders = [];
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
      if (!this.hasMatchingTemplateHeaders(this.csvHeaders, this.templateHeaders)) {
        const expectedHeaders = this.templateHeaders.join(", ");
        this.resetFileState();
        event.target.value = null;
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Template mismatch",
            message: `Upload the correct ${this.selectedRecordType} template. Expected headers: ${expectedHeaders}.`,
            variant: "error",
            mode: "sticky",
          }),
        );
        return;
      }
      this.rows = parsedRows;
      this.searchTerm = "";
      this.sortField = null;
      this.sortDirection = "asc";
      this.pageSize = 10;
      this.currentPage = 1;
      this.previewVisible = false;
    };
    reader.readAsText(file);
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

  parseCsv(text) {
    const rows = this.readCsvRows(text);
    if (!rows || rows.length < 1) return [];
    const hdrs = (rows[0] || []).map((h) => (h != null ? String(h).trim() : ""));
    this.csvHeaders = hdrs;
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
    if (!this.rows || this.rows.length === 0) return;
    const rowCount = this.rows ? this.rows.length : 0;
    const recordTypeName = this.selectedRecordType || "Account";
    const confirmed = await LightningConfirm.open({
      label: "Confirm import",
      message: `Start importing ${rowCount} ${recordTypeName} record${rowCount === 1 ? "" : "s"}? This will queue a batch job.`,
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

    const importRows = this.buildImportRows();

    startAccountImportBatch({
      jsonRows: JSON.stringify(importRows),
      recordTypeName: this.selectedRecordType,
      parentId: this.selectedParentId || null,
    })
      .then((jobId) => {
        this.jobId = jobId;
        this.jobStatus = "Queued";
        this.totalRecords = this.rows ? this.rows.length : 0;
        this.startPolling();
        this.dispatchEvent(new ShowToastEvent({ title: "Import started", message: "Account batch job queued.", variant: "info" }));
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
    const processName = (this.selectedRecordType || "Account") + " Import";
    getAccountImportErrors({ jobId: this.jobId, processName })
      .then((errors) => {
        const list = errors || [];
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
            }),
          );
        } else {
          this.dispatchEvent(new ShowToastEvent({ title: "Import completed", message: "Account records imported.", variant: "success" }));
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
      this.downloadCsv(csv, "account_failed_rows.csv");
    }
  }

  buildFailedCsv() {
    if (this.failedRows && this.failedRows.length > 0) {
      const headers = this.activeHeaders.concat(["ErrorMessage"]);
      const lines = [];
      lines.push(headers.join(","));
      for (const idx of this.failedRowIndexes) {
        const row = this.rows[idx];
        const cells = this.activeHeaders.map((h) => this.csvCell(row && row[h] != null ? row[h] : ""));
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

  buildImportRows() {
    const allowed = new Set(this.supportedFields.concat(["RowNumber"]));
    return (this.rows || []).map((row) => {
      const filteredRow = {};
      Object.keys(row || {}).forEach((key) => {
        let targetKey = key;
        if (key === "Code") targetKey = "Code__c";
        if (key === "Address") targetKey = "BillingStreet";
        if (allowed.has(targetKey)) {
          filteredRow[targetKey] = row[key];
        }
      });
      if (this.selectedLocationId) {
        filteredRow.Location__c = this.selectedLocationId;
      }
      if (this.selectedRecordType === "Department") {
        const hodEmail = (row["Head of Department Email"] || row["HOD Email"] || "").trim().toLowerCase();
        if (hodEmail && this.facultyEmailToId[hodEmail]) {
          filteredRow.Head_of_Department__c = this.facultyEmailToId[hodEmail];
        }
      }
      return filteredRow;
    });
  }

  handleDownloadTemplate() {
    if (!this.templateConfig) {
      this.dispatchEvent(new ShowToastEvent({ title: "Select record type", message: "Choose a record type before downloading the template.", variant: "warning" }));
      return;
    }
    const csv = this.templateHeaders.join(",") + "\n";
    const csvWithBOM = "\uFEFF" + csv;
    const filename = this.templateConfig.filename;
    try {
      const dataUri = "data:text/csv;charset=utf-8," + encodeURIComponent(csvWithBOM);
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
    const blob = new Blob([csvWithBOM], { type: "text/csv;charset=utf-8;" });
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

  handleOpenHelp() {
    this.showHelpModal = true;
  }

  handleCloseHelp() {
    this.showHelpModal = false;
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

  handleRecordTypeChange(e) {
    this.selectedRecordType = e.detail.value;
    this.selectedParentId = "";
    this.loadParents();
    this.resetFileState();
  }

  handleParentChange(e) {
    this.selectedParentId = e.detail.value;
  }

  handleLocationChange(e) {
    this.selectedLocationId = e.detail.value;
  }

  resetFileState() {
    if (this.pollHandle) {
      clearInterval(this.pollHandle);
      this.pollHandle = null;
    }
    window.clearTimeout(this.previewScrollHandle);
    this.file = null;
    this.rows = [];
    this.csvHeaders = [];
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
    const fileInput = this.template.querySelector('input[type="file"]');
    if (fileInput) {
      fileInput.value = null;
    }
  }
}