import { LightningElement, api, track, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import getEnrollmentsByAcademicTerm from "@salesforce/apex/KenAcademicTermEnrollmentController.getEnrollmentsByAcademicTerm";

const COLUMNS = [
  { label: "Student Name", fieldName: "studentName" },
  { label: "Student Email", fieldName: "studentEmail" },
  { label: "Status", fieldName: "enrollmentStatus" },
  { label: "Enrollment Date", fieldName: "enrollmentDate", type: "date" },
  { label: "Academic Level", fieldName: "studentAcademicLevel" },
  { label: "Learner Account", fieldName: "learnerAccountName" },
];

export default class StudentEnrollmentScreen extends LightningElement {
  _recordId;
  _academicTermId;
  _initializedContextTermId;
  pageRef;
  @track rows = [];
  @track isLoading = false;
  @track errorMessage = "";

  columns = COLUMNS;

  @api
  get recordId() {
    return this._recordId;
  }

  set recordId(value) {
    this._recordId = value;
    this.initializeFromContext();
  }

  @api
  get academicTermId() {
    return this._academicTermId;
  }

  set academicTermId(value) {
    this._academicTermId = value;
    this.initializeFromContext();
  }

  @wire(CurrentPageReference)
  wiredPageRef(value) {
    this.pageRef = value;
    this.initializeFromContext();
  }

  get contextTermId() {
    const state = this.pageRef?.state || {};
    const attrs = this.pageRef?.attributes || {};
    return this._academicTermId || this._recordId || attrs.recordId || state.recordId || state.c__recordId || null;
  }

  get hasRows() {
    return this.rows.length > 0;
  }

  get showEmptyState() {
    return !this.isLoading && !this.errorMessage && !this.hasRows;
  }

  async initializeFromContext() {
    const contextTermId = this.contextTermId;
    if (!contextTermId) {
      return;
    }
    if (this._initializedContextTermId === contextTermId) {
      return;
    }
    this._initializedContextTermId = contextTermId;
    this._academicTermId = contextTermId;
    await this.loadEnrollments();
  }

  async loadEnrollments() {
    if (!this._academicTermId) {
      this.rows = [];
      this.errorMessage = "";
      return;
    }

    this.isLoading = true;
    this.errorMessage = "";
    try {
      const data = await getEnrollmentsByAcademicTerm({ academicTermId: this._academicTermId });
      this.rows = Array.isArray(data) ? data : [];
    } catch (e) {
      this.rows = [];
      this.errorMessage = e?.body?.message || e?.message || "Failed to load enrollments.";
    } finally {
      this.isLoading = false;
    }
  }
}