import { LightningElement, track } from "lwc";
import fetchEnrolledStudents from "@salesforce/apex/ProgramEnrollmentController.fetchEnrolledStudents";
import enrollStudents from "@salesforce/apex/ProgramEnrollmentController.enrollStudents";
import getInstitutes from "@salesforce/apex/ProgramEnrollmentController.getInstitutes";
import getPrograms from "@salesforce/apex/ProgramEnrollmentController.getPrograms";
import getProgramPlan from "@salesforce/apex/ProgramEnrollmentController.getProgramPlan";
import getProgramSpecializations from "@salesforce/apex/ProgramEnrollmentController.getProgramSpecializations";

export default class ProgramEnrollment extends LightningElement {
  // -----------------------
  // OPTIONS
  // -----------------------
  @track instituteOptions = [];
  @track programOptions = [];
  @track programPlanOptions = [];
  @track pathwayOptions = [];
  @track students = [];

  // -----------------------
  // SELECTED VALUES
  // -----------------------
  selectedInstitute;
  selectedProgram;
  selectedProgramPlan;
  selectedPathway;
  section;

  selectedRows = [];

  columns = [
    { label: "Student Name", fieldName: "name" },
    { label: "Student Email", fieldName: "email" },
  ];

  connectedCallback() {
    this.loadInstitutes();
    this.loadPrograms();
  }

  async loadInstitutes() {
    const res = await getInstitutes();
    this.instituteOptions = res.map((i) => ({
      label: i.Name,
      value: i.Id,
    }));
  }

  async loadPrograms() {
    const res = await getPrograms();
    this.programOptions = res.map((p) => ({
      label: p.Name,
      value: p.Id,
    }));
  }

  async handleProgramChange(event) {
    this.selectedProgram = event.detail.value;
    this.programPlanOptions = [];
    this.pathwayOptions = [];
    this.selectedProgramPlan = null;
    this.selectedPathway = null;

    const plans = await getProgramPlan({
      learningProgramId: this.selectedProgram,
    });

    this.programPlanOptions = plans.map((p) => ({
      label: p.Name,
      value: p.Id,
    }));
  }

  async handleProgramPlanChange(event) {
    this.selectedProgramPlan = event.detail.value;
    this.pathwayOptions = [];

    const paths = await getProgramSpecializations({
      learningProgramPlanId: this.selectedProgramPlan,
    });

    this.pathwayOptions = paths.map((p) => ({
      label: p.LearningPathwayTemplate.Name,
      value: p.LearningPathwayTemplateId,
    }));
  }

  handlePathwayChange(event) {
    this.selectedPathway = event.detail.value;
  }

  handleInstituteChange(event) {
    this.selectedInstitute = event.detail.value;
  }

  handleSectionChange(event) {
    this.section = event.detail.value;
  }

  handleRowSelection(event) {
    this.selectedRows = event.detail.selectedRows;
  }

  async loadStudents() {
    this.students = await fetchEnrolledStudents({
      learningProgramId: this.selectedProgram,
    });
  }

  async enroll() {
    console.log({
      contactIds: this.selectedRows.map((r) => r.contactId),
      instituteId: this.selectedInstitute,
      learningProgramPlanId: this.selectedProgramPlan,
      learningPathwayTemplateId: this.selectedPathway,
      section: this.section,
    });

    await enrollStudents({
      contactIds: this.selectedRows.map((r) => r.contactId),
      instituteId: this.selectedInstitute,
      learningProgramPlanId: this.selectedProgramPlan,
      learningPathwayTemplateId: this.selectedPathway, // ✅ FIXED
      section: this.section,
    });

    this.students = [];
    this.selectedRows = [];
  }

  // -----------------------
  // GETTERS
  // -----------------------
  get isProgramPlanDisabled() {
    return !this.selectedProgram;
  }

  get isPathwayDisabled() {
    return !this.selectedProgramPlan;
  }

  get isEnrollDisabled() {
    return !this.selectedRows.length;
  }

  get hasStudents() {
    return this.students && this.students.length > 0;
  }
}