import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LightningConfirm from "lightning/confirm";
import getExamCycles from "@salesforce/apex/HistoricalDataImportController.getExamCycles";
import getCourseOfferingNamesForTerm from "@salesforce/apex/KenCopBulkImportController.getCourseOfferingNamesForTerm";
import getParticipationStatuses from "@salesforce/apex/KenCopBulkImportController.getParticipationStatuses";
import getImportErrors from "@salesforce/apex/KenCopBulkImportController.getImportErrors";
import startImport from "@salesforce/apex/KenCopBulkImportController.startImport";
import getBatchStatus from "@salesforce/apex/KenImportUtils.getBatchStatus";

export default class CourseOfferingParticipantImporter extends LightningElement {
  headers = ["Course Offering Name", "Participant Email", "Participation Status", "Start Date", "End Date", "Exam Type"];
  rows = [];
  parsedHeaders = [];
  offeringOptions = [];
  statusOptions = [];
  examCycleOptions = [];
  selectedExamCycleId = "";
  selectedAcademicTermId = "";
  selectedAcademicTermName = "";
  validationErrors = [];
  file;
  previewVisible = false;
  showHelpModal = false;
  jobId;
  jobStatus = "";
  jobProcessed = 0;
  jobErrors = 0;
  totalRecords = 0;
  processedSuccess = 0;
  jobCompleted = false;
  pollHandle;
  failedRowIndexes = [];
  failedRows = [];
  failedRowErrors = {};
  unmatchedErrors = [];
  errorCount = 0;

  connectedCallback() {
    this.loadExamCycles();
    this.loadParticipationStatuses();
  }

  get hasFile() {
    return !!this.file;
  }

  get fileName() {
    return this.file ? this.file.name : "No file chosen";
  }

  get hasSelectedTerm() {
    return !!this.selectedAcademicTermId;
  }

  get importDisabled() {
    return !this.selectedAcademicTermId || !this.rows.length || this.hasValidationErrors;
  }

  get hasValidationErrors() {
    return this.validationErrors.length > 0;
  }

  get showPreview() {
    return this.previewVisible && this.rows.length > 0;
  }

  get displayedRows() {
    return this.rows.slice(0, 25);
  }

  get previewRowValues() {
    return this.displayedRows.map((row, rowIndex) => ({
      key: `row-${rowIndex}`,
      number: rowIndex + 1,
      cells: this.headers.map((header, cellIndex) => ({
        key: `cell-${rowIndex}-${cellIndex}`,
        value: row && row[header] != null ? row[header] : "",
      })),
    }));
  }

  get helpRow() {
    const sample = {
      "Course Offering Name": "BTCS306 - AR/VR Systems - Lecture",
      "Participant Email": "student@example.edu",
      "Participation Status": "Enrolled",
      "Start Date": "2026-06-01",
      "End Date": "2026-12-01",
      "Exam Type": "Regular",
    };

    return this.headers.map((header, index) => ({
      key: `help-${index}`,
      value: sample[header] || "",
    }));
  }

  get participationStatusHelpText() {
    if (!this.statusOptions.length) {
      return "Enrolled";
    }
    return this.statusOptions.map((option) => option.label).join(", ");
  }

  get failedCount() {
    if (this.failedRowIndexes.length > 0) {
      return this.failedRowIndexes.length;
    }
    return this.errorCount || 0;
  }

  get failedDownloadDisabled() {
    return this.failedCount === 0;
  }

  get processedDisplay() {
    if (this.jobCompleted) {
      return this.processedSuccess;
    }
    return Math.min((this.jobProcessed || 0) * 200, this.totalRecords || 0);
  }

  get selectedExamCycleSummary() {
    if (!this.selectedExamCycleId) {
      return "";
    }
    return this.selectedAcademicTermName
      ? `${this.getExamCycleLabel(this.selectedExamCycleId)} | Academic Term: ${this.selectedAcademicTermName}`
      : this.getExamCycleLabel(this.selectedExamCycleId);
  }

  disconnectedCallback() {
    if (this.pollHandle) {
      clearInterval(this.pollHandle);
    }
  }

  loadExamCycles() {
    getExamCycles()
      .then((data) => {
        this.examCycleOptions = (data || []).map((cycle) => ({
          label: cycle.name,
          value: cycle.id,
          academicTermId: cycle.academicTermId,
          academicTermName: cycle.academicTermName,
        }));
      })
      .catch(() => {
        this.examCycleOptions = [];
      });
  }

  loadParticipationStatuses() {
    getParticipationStatuses()
      .then((data) => {
        this.statusOptions = data || [];
        this.validateRows();
      })
      .catch(() => {
        this.statusOptions = [];
      });
  }

  handleExamCycleChange(event) {
    this.selectedExamCycleId = event.detail.value || "";
    const selectedCycle = this.examCycleOptions.find((option) => option.value === this.selectedExamCycleId);
    this.selectedAcademicTermId = selectedCycle && selectedCycle.academicTermId ? selectedCycle.academicTermId : "";
    this.selectedAcademicTermName = selectedCycle && selectedCycle.academicTermName ? selectedCycle.academicTermName : "";
    this.offeringOptions = [];
    this.resetFileState();
    if (this.selectedAcademicTermId) {
      this.loadOfferings();
    }
  }

  loadOfferings() {
    getCourseOfferingNamesForTerm({ academicTermId: this.selectedAcademicTermId })
      .then((data) => {
        this.offeringOptions = data || [];
        this.validateRows();
      })
      .catch(() => {
        this.offeringOptions = [];
      });
  }

  handleFileChange(event) {
    const selectedFile = event.target.files[0];
    if (!selectedFile) {
      return;
    }

    if (!/\.csv$/i.test(selectedFile.name || "")) {
      this.resetFileState();
      event.target.value = null;
      this.showToast("Invalid file type", "Please upload a CSV (.csv) file.", "error", "sticky");
      return;
    }

    const reader = new FileReader();
    reader.onload = () => {
      const parsedRows = this.parseCsv(reader.result);
      if (!this.hasMatchingTemplateHeaders(this.parsedHeaders, this.headers)) {
        this.resetFileState();
        event.target.value = null;
        this.showToast("Template mismatch", `Expected headers: ${this.headers.join(", ")}.`, "error", "sticky");
        return;
      }
      this.file = selectedFile;
      this.rows = parsedRows;
      this.previewVisible = false;
      this.validateRows();
    };
    reader.readAsText(selectedFile);
  }

  handleDeleteFile() {
    this.resetFileState();
  }

  handleFileNameClick() {
    this.handlePreview();
  }

  handlePreview() {
    this.previewVisible = true;
  }

  async handleImport() {
    if (this.importDisabled) {
      return;
    }

    const confirmed = await LightningConfirm.open({
      label: "Confirm import",
      message: `Start importing ${this.rows.length} course offering participant row${this.rows.length === 1 ? "" : "s"}?`,
      theme: "warning",
    });
    if (!confirmed) {
      return;
    }

    this.failedRowIndexes = [];
    this.failedRows = [];
    this.failedRowErrors = {};
    this.unmatchedErrors = [];
    this.errorCount = 0;
    this.jobCompleted = false;
    this.processedSuccess = 0;

    startImport({ jsonRows: JSON.stringify(this.rows), academicTermId: this.selectedAcademicTermId })
      .then((jobId) => {
        this.jobId = jobId;
        this.jobStatus = "Queued";
        this.totalRecords = this.rows.length;
        this.startPolling();
        this.showToast("Import started", "Course Offering Participant bulk import job queued.", "info");
      })
      .catch((error) => {
        this.showToast("Import failed", this.reduceError(error), "error", "sticky");
      });
  }

  startPolling() {
    if (this.pollHandle) {
      clearInterval(this.pollHandle);
    }
    this.pollHandle = setInterval(() => {
      if (!this.jobId) {
        return;
      }
      getBatchStatus({ jobId: this.jobId })
        .then((info) => {
          if (!info) {
            return;
          }
          this.jobStatus = info.status;
          this.jobProcessed = info.processed;
          this.jobErrors = info.errors;
          if (["Completed", "Failed", "Aborted"].includes(info.status)) {
            clearInterval(this.pollHandle);
            this.pollHandle = null;
            this.handleJobComplete();
          }
        })
        .catch(() => {});
    }, 2000);
  }

  handleJobComplete() {
    getImportErrors({ jobId: this.jobId })
      .then((errors) => {
        const list = errors || [];
        this.errorCount = list.length;
        const rowIndexes = new Set();
        const rowErrors = {};
        const unmatched = [];

        for (const message of list) {
          const rowIndex = this.getRowIndexFromMessage(message);
          if (rowIndex !== null && rowIndex >= 0 && rowIndex < this.rows.length) {
            rowIndexes.add(rowIndex);
            rowErrors[rowIndex] = rowErrors[rowIndex] ? `${rowErrors[rowIndex]} | ${message}` : message;
          } else {
            unmatched.push(message);
          }
        }

        this.failedRowIndexes = Array.from(rowIndexes).sort((a, b) => a - b);
        this.failedRowErrors = rowErrors;
        this.failedRows = this.failedRowIndexes.map((index) => this.rows[index]).filter((row) => row);
        this.unmatchedErrors = unmatched;
        const failedCount = this.failedRowIndexes.length > 0 ? this.failedRowIndexes.length : list.length;
        this.processedSuccess = Math.max(0, (this.totalRecords || 0) - failedCount);
        this.errorCount = failedCount;
        this.jobCompleted = true;

        if (failedCount > 0 || this.jobErrors > 0) {
          this.showToast("Import finished with errors", `${this.processedSuccess} row(s) processed, ${failedCount} failed.`, "error", "sticky");
        } else {
          this.showToast("Import completed", `${this.processedSuccess} row(s) processed successfully.`, "success");
        }

        this.dispatchEvent(new CustomEvent("refreshimport", { bubbles: true, composed: true }));
      })
      .catch((error) => {
        this.showToast("Import finished", this.reduceError(error), "warning");
      });
  }

  validateRows() {
    const errors = [];
    const offeringNames = new Set((this.offeringOptions || []).map((option) => this.normalize(option.value)));
    const statusValues = new Set((this.statusOptions || []).map((option) => this.normalize(option.value)));
    const seenKeys = new Set();

    for (let i = 0; i < this.rows.length; i += 1) {
      const row = this.rows[i];
      const rowNumber = row.RowNumber || String(i + 1);
      const offeringName = row["Course Offering Name"];
      const participantEmail = row["Participant Email"];
      const status = row["Participation Status"];

      if (!offeringName) {
        errors.push({ key: `offering-required-${i}`, message: `Row ${rowNumber}: Course Offering Name is required.` });
      } else if (offeringNames.size > 0 && !offeringNames.has(this.normalize(offeringName))) {
        errors.push({ key: `offering-invalid-${i}`, message: `Row ${rowNumber}: Course Offering "${offeringName}" is not under the Academic Term for the selected Exam Cycle.` });
      }

      if (!participantEmail) {
        errors.push({ key: `email-required-${i}`, message: `Row ${rowNumber}: Participant Email is required.` });
      }

      if (status && statusValues.size > 0 && !statusValues.has(this.normalize(status))) {
        errors.push({ key: `status-invalid-${i}`, message: `Row ${rowNumber}: Participation Status "${status}" is invalid.` });
      }

      const duplicateKey = `${this.normalize(offeringName)}|${this.normalize(participantEmail)}`;
      if (offeringName && participantEmail) {
        if (seenKeys.has(duplicateKey)) {
          errors.push({ key: `duplicate-${i}`, message: `Row ${rowNumber}: Duplicate Course Offering Name and Participant Email.` });
        }
        seenKeys.add(duplicateKey);
      }
    }

    this.validationErrors = errors.slice(0, 25);
  }

  parseCsv(text) {
    const rows = this.readCsvRows(text);
    if (!rows.length) {
      this.parsedHeaders = [];
      return [];
    }

    const headers = rows[0].map((header) => String(header || "").trim());
    this.parsedHeaders = headers;
    const output = [];
    for (let i = 1; i < rows.length; i += 1) {
      const cells = rows[i] || [];
      const row = {};
      for (let j = 0; j < headers.length; j += 1) {
        row[headers[j]] = cells[j] != null ? String(cells[j]).trim() : "";
      }
      row.RowNumber = String(i);
      output.push(row);
    }
    return output;
  }

  readCsvRows(text) {
    const input = String(text || "").replace(/^\uFEFF/, "");
    const rows = [];
    let row = [];
    let cell = "";
    let inQuotes = false;

    for (let i = 0; i < input.length; i += 1) {
      const ch = input[i];
      if (ch === '"') {
        if (inQuotes && input[i + 1] === '"') {
          cell += '"';
          i += 1;
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
        rows.push(row);
        row = [];
        cell = "";
        if (ch === "\r" && input[i + 1] === "\n") {
          i += 1;
        }
        continue;
      }
      cell += ch;
    }

    if (cell.length > 0 || row.length > 0) {
      row.push(cell);
      rows.push(row);
    }
    return rows.filter((line) => line.some((value) => String(value || "").trim().length > 0));
  }

  hasMatchingTemplateHeaders(actualHeaders, expectedHeaders) {
    const actual = (actualHeaders || []).map((header) => this.normalize(header));
    const expected = (expectedHeaders || []).map((header) => this.normalize(header));
    if (actual.length !== expected.length) {
      return false;
    }
    return expected.every((header, index) => header === actual[index]);
  }

  handleDownloadTemplate() {
    const lines = [
      this.headers.join(","),
      [
        this.csvCell("BTCS306 - AR/VR Systems - Lecture"),
        this.csvCell("student@example.edu"),
        this.csvCell("Enrolled"),
        this.csvCell("2026-06-01"),
        this.csvCell("2026-12-01"),
        this.csvCell("Regular"),
      ].join(","),
    ];
    this.downloadCsv(`\uFEFF${lines.join("\n")}`, "cop_bulk_import_template.csv");
  }

  handleDownloadFailed() {
    if (!this.failedRows.length && !this.unmatchedErrors.length) {
      return;
    }
    this.downloadCsv(this.buildFailedCsv(), "cop_bulk_import_failed_rows.csv");
  }

  buildFailedCsv() {
    if (this.failedRows.length) {
      const headers = this.headers.concat(["ErrorMessage"]);
      const lines = [headers.join(",")];
      for (const index of this.failedRowIndexes) {
        const row = this.rows[index] || {};
        const cells = this.headers.map((header) => this.csvCell(row[header] || ""));
        cells.push(this.csvCell(this.failedRowErrors[index] || ""));
        lines.push(cells.join(","));
      }
      return `\uFEFF${lines.join("\n")}`;
    }

    const lines = ["RowNumber,ErrorMessage"];
    for (const message of this.unmatchedErrors) {
      lines.push(`,${this.csvCell(message)}`);
    }
    return `\uFEFF${lines.join("\n")}`;
  }

  csvCell(value) {
    const text = String(value == null ? "" : value);
    if (text.includes('"') || text.includes(",") || text.includes("\n") || text.includes("\r")) {
      return `"${text.replace(/"/g, '""')}"`;
    }
    return text;
  }

  downloadCsv(csv, filename) {
    const dataUri = `data:text/csv;charset=utf-8,${encodeURIComponent(csv)}`;
    const link = document.createElement("a");
    link.style.display = "none";
    link.href = dataUri;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  resetFileState() {
    this.file = null;
    this.rows = [];
    this.parsedHeaders = [];
    this.validationErrors = [];
    this.previewVisible = false;
    this.failedRowIndexes = [];
    this.failedRows = [];
    this.failedRowErrors = {};
    this.unmatchedErrors = [];
    this.errorCount = 0;
    this.totalRecords = 0;
    this.processedSuccess = 0;
    this.jobId = null;
    this.jobStatus = "";
  }

  getRowIndexFromMessage(message) {
    const match = String(message || "").match(/Row[^0-9]*(\d+)/i);
    if (!match || !match[1]) {
      return null;
    }
    const rowNumber = parseInt(match[1], 10);
    if (Number.isNaN(rowNumber)) {
      return null;
    }
    return rowNumber - 1;
  }

  normalize(value) {
    return String(value || "").trim().toLowerCase();
  }

  handleOpenHelp() {
    this.showHelpModal = true;
  }

  handleCloseHelp() {
    this.showHelpModal = false;
  }

  getExamCycleLabel(examCycleId) {
    const selected = this.examCycleOptions.find((option) => option.value === examCycleId);
    return selected ? selected.label : "";
  }

  showToast(title, message, variant, mode = "dismissable") {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
  }

  reduceError(error) {
    if (!error) {
      return "Unknown error";
    }
    if (Array.isArray(error.body)) {
      return error.body.map((entry) => entry.message).join(", ");
    }
    if (error.body && typeof error.body.message === "string") {
      return error.body.message;
    }
    if (typeof error.message === "string") {
      return error.message;
    }
    return "Unknown error";
  }
}