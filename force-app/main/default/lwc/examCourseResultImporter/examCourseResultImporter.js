import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LightningConfirm from "lightning/confirm";
import getBatchStatus from "@salesforce/apex/KenImportUtils.getBatchStatus";
import getExamCycles from "@salesforce/apex/HistoricalDataImportController.getExamCycles";
import getImportErrors from "@salesforce/apex/HistoricalDataImportController.getImportErrors";
import startExamCourseResultImport from "@salesforce/apex/HistoricalDataImportController.startExamCourseResultImport";

const PROCESS_NAME = "Exam Course Result Import";

export default class ExamCourseResultImporter extends LightningElement {
  file;
  rows = [];
  headers = [
    "Student Registration ID",
    "Course Code",
    "Course Credit",
    "Internal Total Marks",
    "External Total Mark",
    "Revaluation Marks",
    "Retest/Suply Marks",
    "Total Marks",
    "Grade",
    "Grade Point",
  ];
  examCycleOptions = [];
  selectedExamCycleId = "";
  parsedHeaders = [];
  jobId;
  jobStatus = "";
  totalRecords = 0;
  jobProcessed = 0;
  jobCompleted = false;
  processedSuccess = 0;
  failedRowIndexes = [];
  failedRowErrors = {};
  unmatchedErrors = [];
  pollHandle;
  previewScrollHandle;
  showHelpModal = false;

  searchTerm = "";
  sortField = null;
  sortDirection = "asc";
  pageSize = 10;
  currentPage = 1;
  previewVisible = false;

  connectedCallback() {
    getExamCycles()
      .then((data) => {
        this.examCycleOptions = (data || []).map((item) => ({ label: item.name, value: item.id }));
      })
      .catch(() => {
        this.examCycleOptions = [];
      });
  }

  disconnectedCallback() {
    window.clearInterval(this.pollHandle);
    window.clearTimeout(this.previewScrollHandle);
  }

  get fileName() {
    return this.file ? this.file.name : "No file chosen";
  }

  get hasFile() {
    return !!this.file;
  }

  get showPreview() {
    return this.hasFile && this.rows.length > 0 && this.previewVisible;
  }

  get pageSizeValue() {
    return String(this.pageSize);
  }

  get importDisabled() {
    return !this.selectedExamCycleId || !this.rows.length;
  }

  get failedCount() {
    return this.failedRowIndexes.length || this.unmatchedErrors.length;
  }

  get failedDownloadDisabled() {
    return this.failedCount === 0;
  }

  get processedDisplay() {
    if (this.jobCompleted) {
      return this.processedSuccess;
    }
    return Math.min((this.jobProcessed || 0) * 100, this.totalRecords || 0);
  }

  get helpExampleHeaders() {
    return this.headers;
  }

  get helpExampleRow() {
    const sample = {
      "Student Registration ID": "2023000123",
      "Course Code": "BTME102",
      "Course Credit": "3",
      "Internal Total Marks": "20",
      "External Total Mark": "45",
      "Revaluation Marks": "",
      "Retest/Suply Marks": "",
      "Total Marks": "65",
      Grade: "A",
      "Grade Point": "10",
    };
    return this.helpExampleHeaders.map((header, index) => ({
      key: `exam-course-help-${index}`,
      value: sample[header] || "",
    }));
  }

  get filteredRows() {
    const term = (this.searchTerm || "").trim().toLowerCase();
    if (!term) return this.rows || [];
    return (this.rows || []).filter((row) => {
      for (const key in row) {
        if (!Object.prototype.hasOwnProperty.call(row, key)) continue;
        const value = row[key];
        if (value != null && String(value).toLowerCase().includes(term)) {
          return true;
        }
      }
      return false;
    });
  }

  get sortedRows() {
    const rows = this.filteredRows.slice();
    if (!this.sortField) return rows;
    const direction = this.sortDirection === "asc" ? 1 : -1;
    rows.sort((left, right) => {
      const leftValue = left && left[this.sortField] != null ? String(left[this.sortField]) : "";
      const rightValue = right && right[this.sortField] != null ? String(right[this.sortField]) : "";
      if (leftValue === rightValue) return 0;
      return leftValue < rightValue ? -1 * direction : 1 * direction;
    });
    return rows;
  }

  get totalPages() {
    const length = this.sortedRows.length || 0;
    if (this.pageSize >= length) return 1;
    return Math.max(1, Math.ceil(length / this.pageSize));
  }

  get displayedRows() {
    const start = (this.currentPage - 1) * this.pageSize;
    if (this.pageSize >= this.sortedRows.length) return this.sortedRows;
    return this.sortedRows.slice(start, start + this.pageSize);
  }

  get previewHeaders() {
    return [{ label: "#", field: "#" }].concat((this.headers || []).map((header) => ({ label: header, field: header })));
  }

  get previewRowValues() {
    const headers = this.previewHeaders;
    const baseIndex = (this.currentPage - 1) * this.pageSize;
    return (this.displayedRows || []).map((row, rowIndex) => ({
      rowKey: `row-${baseIndex + rowIndex}`,
      cells: headers.map((header, columnIndex) => {
        if (columnIndex === 0) {
          return {
            key: `cell-${baseIndex + rowIndex}-${columnIndex}`,
            value: String(baseIndex + rowIndex + 1),
          };
        }
        return {
          key: `cell-${baseIndex + rowIndex}-${columnIndex}`,
          value: row && row[header.field] != null ? row[header.field] : "",
        };
      }),
    }));
  }

  get sortActive() {
    return !!this.sortField;
  }

  get sortStatusText() {
    if (!this.sortField) return "";
    return `${this.sortField} (${this.sortDirection === "asc" ? "A-Z" : "Z-A"})`;
  }

  get prevDisabled() {
    return this.currentPage <= 1;
  }

  get nextDisabled() {
    return this.currentPage >= this.totalPages;
  }

  handleExamCycleChange(event) {
    this.selectedExamCycleId = event.detail.value;
  }

  handleFileChange(event) {
    const file = event.target.files[0];
    if (!file) return;
    if (!/\.csv$/i.test(file.name || "")) {
      this.resetFileState();
      event.target.value = null;
      this.showToast("Invalid file", "Please upload a CSV file.", "error");
      return;
    }

    this.file = file;
    const reader = new FileReader();
    reader.onload = () => {
      const parsedRows = this.parseCsv(reader.result);
      if (!this.hasMatchingTemplateHeaders(this.parsedHeaders, this.headers)) {
        this.resetFileState();
        event.target.value = null;
        this.showToast("Template mismatch", "Download the template and use the exact headers.", "error");
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
    if (!this.hasFile || !this.rows.length) return;
    this.previewVisible = true;
    this.scrollPreviewIntoView();
  }

  handleDeleteFile() {
    this.resetFileState();
  }

  handleSearchChange(event) {
    this.searchTerm = event.target.value || "";
    this.currentPage = 1;
  }

  handlePageSizeChange(event) {
    const nextValue = parseInt(event.target.value, 10);
    this.pageSize = Number.isNaN(nextValue) ? 10 : nextValue;
    this.currentPage = 1;
  }

  handlePrevPage() {
    if (this.currentPage > 1) {
      this.currentPage -= 1;
    }
  }

  handleNextPage() {
    if (this.currentPage < this.totalPages) {
      this.currentPage += 1;
    }
  }

  handleSort(event) {
    const field = event.currentTarget.dataset.field;
    if (!field || field === "#") return;
    if (this.sortField === field) {
      this.sortDirection = this.sortDirection === "asc" ? "desc" : "asc";
    } else {
      this.sortField = field;
      this.sortDirection = "asc";
    }
    this.currentPage = 1;
  }

  async handleImport() {
    if (this.importDisabled) return;

    const confirmed = await LightningConfirm.open({
      label: "Confirm import",
      message: `Start importing ${this.rows.length} exam course result row${this.rows.length === 1 ? "" : "s"}?`,
      theme: "warning",
    });
    if (!confirmed) return;

    this.failedRowIndexes = [];
    this.failedRowErrors = {};
    this.unmatchedErrors = [];
    this.jobCompleted = false;
    this.processedSuccess = 0;

    startExamCourseResultImport({
      jsonRows: JSON.stringify(this.rows),
      examCycleId: this.selectedExamCycleId,
    })
      .then((jobId) => {
        this.jobId = jobId;
        this.jobStatus = "Queued";
        this.totalRecords = this.rows.length;
        this.startPolling();
        this.showToast("Import started", "Exam course result batch job queued.", "info");
      })
      .catch((error) => {
        this.showToast("Import failed", this.reduceError(error), "error");
      });
  }

  handleOpenHelp() {
    this.showHelpModal = true;
  }

  handleCloseHelp() {
    this.showHelpModal = false;
  }

  startPolling() {
    window.clearInterval(this.pollHandle);
    this.pollHandle = window.setInterval(() => {
      getBatchStatus({ jobId: this.jobId })
        .then((info) => {
          if (!info) return;
          this.jobStatus = info.status;
          this.jobProcessed = info.processed;
          if (["Completed", "Failed", "Aborted"].includes(info.status)) {
            window.clearInterval(this.pollHandle);
            this.pollHandle = null;
            this.handleJobComplete();
          }
        })
        .catch(() => {});
    }, 2000);
  }

  handleJobComplete() {
    getImportErrors({ jobId: this.jobId, processName: PROCESS_NAME })
      .then((errors) => {
        const messages = errors || [];
        const rowIndexes = new Set();
        const rowErrors = {};
        const unmatched = [];
        for (const message of messages) {
          const match = /Row\s+(\d+)/i.exec(message || "");
          if (match) {
            const rowIndex = parseInt(match[1], 10) - 1;
            rowIndexes.add(rowIndex);
            rowErrors[rowIndex] = rowErrors[rowIndex] ? `${rowErrors[rowIndex]} | ${message}` : message;
          } else {
            unmatched.push(message);
          }
        }
        this.failedRowIndexes = Array.from(rowIndexes).sort((a, b) => a - b);
        this.failedRowErrors = rowErrors;
        this.unmatchedErrors = unmatched;
        const failedCount = this.failedRowIndexes.length || unmatched.length;
        this.processedSuccess = Math.max(0, this.totalRecords - failedCount);
        this.jobCompleted = true;
        this.showToast(
          failedCount ? "Import finished with errors" : "Import completed",
          failedCount ? `${this.processedSuccess} row(s) processed, ${failedCount} with errors.` : `${this.processedSuccess} row(s) processed successfully.`,
          failedCount ? "error" : "success",
        );
      })
      .catch((error) => {
        this.showToast("Import finished", this.reduceError(error), "warning");
      });
  }

  handleDownloadTemplate() {
    const content = [
      this.headers.join(","),
      [
        this.csvCell("2023000123"),
        this.csvCell("BTME102"),
        this.csvCell("3"),
        this.csvCell("20"),
        this.csvCell("45"),
        this.csvCell(""),
        this.csvCell(""),
        this.csvCell("65"),
        this.csvCell("A"),
        this.csvCell("10"),
      ].join(","),
    ].join("\n");
    this.downloadCsv(`\uFEFF${content}`, "exam_course_result_template.csv");
  }

  handleDownloadFailed() {
    const headers = this.headers.concat(["ErrorMessage"]);
    const lines = [headers.join(",")];
    for (const index of this.failedRowIndexes) {
      const row = this.rows[index] || {};
      const cells = this.headers.map((header) => this.csvCell(row[header] || ""));
      cells.push(this.csvCell(this.failedRowErrors[index] || ""));
      lines.push(cells.join(","));
    }
    for (const message of this.unmatchedErrors) {
      lines.push([new Array(this.headers.length).fill("").join(","), this.csvCell(message)].join(","));
    }
    this.downloadCsv(`\uFEFF${lines.join("\n")}`, "exam_course_result_failed_rows.csv");
  }

  parseCsv(text) {
    const rows = this.readCsvRows(text);
    if (!rows.length) return [];
    this.parsedHeaders = (rows[0] || []).map((header) => String(header || "").trim());
    return rows.slice(1).map((cells, index) => {
      const row = { RowNumber: String(index + 1) };
      this.parsedHeaders.forEach((header, cellIndex) => {
        row[header] = cells[cellIndex] != null ? String(cells[cellIndex]).trim() : "";
      });
      return row;
    });
  }

  readCsvRows(text) {
    const input = String(text || "").replace(/^\uFEFF/, "");
    const rows = [];
    let row = [];
    let cell = "";
    let inQuotes = false;

    for (let i = 0; i < input.length; i++) {
      const character = input[i];
      if (character === "\"") {
        if (inQuotes && input[i + 1] === "\"") {
          cell += "\"";
          i += 1;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (character === "," && !inQuotes) {
        row.push(cell);
        cell = "";
        continue;
      }
      if ((character === "\n" || character === "\r") && !inQuotes) {
        row.push(cell);
        rows.push(row);
        row = [];
        cell = "";
        if (character === "\r" && input[i + 1] === "\n") {
          i += 1;
        }
        continue;
      }
      cell += character;
    }

    if (cell.length > 0 || row.length > 0) {
      row.push(cell);
      rows.push(row);
    }

    return rows.filter((line) => line.some((value) => String(value || "").trim().length > 0));
  }

  hasMatchingTemplateHeaders(actualHeaders, expectedHeaders) {
    if ((actualHeaders || []).length !== (expectedHeaders || []).length) return false;
    return expectedHeaders.every((header, index) => this.normalize(header) === this.normalize(actualHeaders[index]));
  }

  normalize(value) {
    return String(value || "").trim().toLowerCase();
  }

  csvCell(value) {
    const text = String(value == null ? "" : value);
    return `"${text.replace(/"/g, "\"\"")}"`;
  }

  downloadCsv(content, fileName) {
    const anchor = document.createElement("a");
    anchor.href = URL.createObjectURL(new Blob([content], { type: "text/csv;charset=utf-8;" }));
    anchor.download = fileName;
    anchor.click();
    URL.revokeObjectURL(anchor.href);
  }

  resetFileState() {
    this.file = null;
    this.rows = [];
    this.parsedHeaders = [];
    this.previewVisible = false;
    this.searchTerm = "";
    this.sortField = null;
    this.sortDirection = "asc";
    this.pageSize = 10;
    this.currentPage = 1;
    const fileInput = this.template.querySelector('input[type="file"]');
    if (fileInput) {
      fileInput.value = null;
    }
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

  reduceError(error) {
    if (error && error.body && error.body.message) return error.body.message;
    if (error && error.message) return error.message;
    return "Unknown error";
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: variant === "error" ? "sticky" : "dismissable" }));
  }
}