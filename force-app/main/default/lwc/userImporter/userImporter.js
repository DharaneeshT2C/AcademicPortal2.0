import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LightningConfirm from "lightning/confirm";
import startUserImportBatch from "@salesforce/apex/UserImportController.startUserImportBatch";
import getUserImportErrors from "@salesforce/apex/UserImportController.getUserImportErrors";
import getActiveProgramPlans from "@salesforce/apex/UserImportController.getActiveProgramPlans";
import getCyclesByProgramPlan from "@salesforce/apex/UserImportController.getCyclesByProgramPlan";
import getBatchStatus from "@salesforce/apex/KenImportUtils.getBatchStatus";

export default class UserImporter extends LightningElement {
  file;
  rows = [];
  userTypeOptions = [
    { label: "Faculty", value: "Faculty" },
    { label: "Student", value: "Student" },
  ];
  selectedUserType = "Faculty";
  programPlanOptions = [];
  selectedProgramPlanId = "";
  cycleOptions = [];
  selectedCycle = "";
  sectionOptions = [
    { label: "A", value: "A" },
    { label: "B", value: "B" },
    { label: "C", value: "C" },
    { label: "D", value: "D" },
    { label: "E", value: "E" },
  ];
  selectedSection = "";
  headersByType = {
    Faculty: ["First Name", "Last Name", "Email", "Phone", "Employee ID", "DOB"],
    Student: ["First Name", "Last Name", "Email", "Phone", "Student ID", "Enrollment Status", "Admission Date", "Expected Graduation Date", "DOB"],
  };
  // UI state: search / sort / pagination
  searchTerm = "";
  sortField = null;
  sortDirection = "asc";
  pageSize = 10;
  currentPage = 1;
  previewVisible = false;
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

  get fileName() {
    return this.file ? this.file.name : "No file chosen";
  }

  get hasFile() {
    return !!this.file;
  }

  get importDisabled() {
    const needsStudentContext = this.selectedUserType === "Student";
    return !this.file || !this.rows || this.rows.length === 0 || !this.selectedUserType || (needsStudentContext && (!this.selectedProgramPlanId || !this.selectedSection));
  }

  get showPreview() {
    return !!this.file && !!this.rows && this.rows.length > 0 && this.previewVisible;
  }

  get pageSizeValue() {
    return String(this.pageSize);
  }

  get headers() {
    return this.headersByType[this.selectedUserType] || this.headersByType.Faculty;
  }

  get isStudentType() {
    return this.selectedUserType === "Student";
  }

  get helpExampleHeaders() {
    return this.headers;
  }

  get helpExampleRow() {
    const samplesByType = {
      Faculty: {
        "First Name": "Asha",
        "Last Name": "Sharma",
        Email: "asha.sharma@example.edu",
        Phone: "9876543210",
        "Employee ID": "EMP-1001",
        DOB: "1990-05-10",
      },
      Student: {
        "First Name": "Joy",
        "Last Name": "Grace",
        Email: "joy.grace@example.edu",
        Phone: "9876543210",
        "Student ID": "STUDENT-1001",
        "Enrollment Status": "Active",
        "Admission Date": "2026-06-01",
        "Expected Graduation Date": "2030-05-30",
        DOB: "2006-01-14",
      },
    };
    const sample = samplesByType[this.selectedUserType] || samplesByType.Faculty;
    return this.helpExampleHeaders.map((header, index) => ({
      key: `user-help-${index}`,
      value: sample[header] || "",
    }));
  }

  connectedCallback() {
    this.loadProgramPlans();
  }

  loadProgramPlans() {
    getActiveProgramPlans()
      .then((data) => {
        this.programPlanOptions = (data || []).map((plan) => ({ label: plan.name, value: plan.id }));
      })
      .catch(() => {
        this.programPlanOptions = [];
      });
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
            message: `Upload the correct ${this.selectedUserType} template. Expected headers: ${expectedHeaders}.`,
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
    const userType = this.selectedUserType || "User";
    const confirmed = await LightningConfirm.open({
      label: "Confirm import",
      message: `Start importing ${rowCount} ${userType} record${rowCount === 1 ? "" : "s"}? This will queue a batch job.`,
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
    startUserImportBatch({
      jsonRows: JSON.stringify(this.rows),
      userType: this.selectedUserType,
      learningProgramPlanId: this.isStudentType && this.selectedProgramPlanId ? this.selectedProgramPlanId : null,
      section: this.isStudentType && this.selectedSection ? this.selectedSection : null,
      cycle: this.isStudentType && this.selectedCycle ? this.selectedCycle : null,
    })
      .then((jobId) => {
        this.jobId = jobId;
        this.jobStatus = "Queued";
        this.totalRecords = this.rows ? this.rows.length : 0;
        this.startPolling();
        this.dispatchEvent(new ShowToastEvent({ title: "Import started", message: `${userType} batch job queued.`, variant: "info" }));
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
    getUserImportErrors({ jobId: this.jobId })
      .then((errors) => {
        const list = errors || [];
        this.errorCount = list.length;
        const idxSet = new Set();
        const rowErrors = {};
        const unmatched = [];
        for (const msg of list) {
          const idx = this.getRowIndexFromMessage(msg, this.rows, ["Email", "Last Name", "LastName"]);
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
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Import finished with errors",
              message: `${this.processedSuccess} ${this.selectedUserType.toLowerCase()} record(s) processed, ${failedCount} failed. Check failed rows for details.`,
              variant: "error",
              mode: "sticky",
            }),
          );
        } else if (this.jobErrors && this.jobErrors > 0) {
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Import finished with errors",
              message: `${this.processedSuccess} ${this.selectedUserType.toLowerCase()} record(s) processed. Check audit logs for details.`,
              variant: "error",
              mode: "sticky",
            }),
          );
        } else {
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Import completed",
              message: `${this.processedSuccess} ${this.selectedUserType.toLowerCase()} record(s) processed successfully.`,
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
      this.downloadCsv(csv, "user_failed_rows.csv");
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
    if (s.includes('"')) {
      return '"' + s.replace(/\"/g, '""') + '"';
    }
    if (s.includes(",") || s.includes("\n") || s.includes("\r")) {
      return '"' + s + '"';
    }
    return s;
  }

  downloadCsv(csv, filename) {
    try {
      const dataUri = "data:text/csv;charset=utf-8," + encodeURIComponent(csv);
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
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
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
      link.download = "user_template_" + this.selectedUserType.toLowerCase() + ".csv";
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      return;
    } catch (e) {
      // fall through to blob approach
    }

    const blob = new Blob([csvWithBOM], { type: "text/csv;charset=utf-8;" });
    if (navigator && navigator.msSaveBlob) {
      navigator.msSaveBlob(blob, "user_template_" + this.selectedUserType.toLowerCase() + ".csv");
      return;
    }
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.style.display = "none";
    a.href = url;
    a.download = "user_template_" + this.selectedUserType.toLowerCase() + ".csv";
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

  handleUserTypeChange(e) {
    this.selectedUserType = e.detail.value;
    this.selectedProgramPlanId = "";
    this.selectedSection = "";
    this.selectedCycle = "";
    this.cycleOptions = [];
    this.resetFileState();
  }

  handleProgramPlanChange(e) {
    this.selectedProgramPlanId = e.detail.value;
    this.selectedCycle = "";
    this.cycleOptions = [];
    if (this.selectedProgramPlanId) {
      this.loadCyclesForPlan();
    }
  }

  loadCyclesForPlan() {
    getCyclesByProgramPlan({ programPlanId: this.selectedProgramPlanId })
      .then((data) => {
        this.cycleOptions = (data || []).map((c) => ({ label: c.label, value: c.label }));
      })
      .catch(() => {
        this.cycleOptions = [];
      });
  }

  handleCycleChange(e) {
    this.selectedCycle = e.detail.value;
  }

  get hasCycleOptions() {
    return this.cycleOptions.length > 0;
  }

  handleSectionChange(e) {
    this.selectedSection = e.detail.value;
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
    this.selectedCycle = "";
    this.cycleOptions = [];
    this.showHelpModal = false;
    const fileInput = this.template.querySelector('input[type="file"]');
    if (fileInput) {
      fileInput.value = null;
    }
  }
}