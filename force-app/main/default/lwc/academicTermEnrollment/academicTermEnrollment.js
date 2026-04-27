import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getInstitutes from "@salesforce/apex/KenAcademicTermEnrollmentController.getInstitutes";
import getInstituteDepartment from "@salesforce/apex/KenAcademicTermEnrollmentController.getInstituteDepartment";
import getPrograms from "@salesforce/apex/KenAcademicTermEnrollmentController.getPrograms";
import getProgramPlan from "@salesforce/apex/KenAcademicTermEnrollmentController.getProgramPlan";
import getProgramSpecializations from "@salesforce/apex/KenAcademicTermEnrollmentController.getProgramSpecializations";
import getAcademicTermsByProgramPlan from "@salesforce/apex/KenAcademicTermEnrollmentController.getAcademicTermsByProgramPlan";
import getSectionsByProgramPlan from "@salesforce/apex/KenAcademicTermEnrollmentController.getSectionsByProgramPlan";
import searchStudentsByCurrentTermAndProgramPlan from "@salesforce/apex/KenAcademicTermEnrollmentController.searchStudentsByCurrentTermAndProgramPlan";
import createAcademicTermEnrollments from "@salesforce/apex/KenAcademicTermEnrollmentController.createAcademicTermEnrollments";
import getThemeColors from "@salesforce/apex/UiThemeController.getThemeColors";

export default class AcademicTermEnrollment extends LightningElement {
  studentColumns = [
    { label: "Student Name", fieldName: "studentName" },
    { label: "Student Email", fieldName: "studentEmail" },
    { label: "Section", fieldName: "classCohort" },
  ];

  selectedInstitute;
  selectedInstituteDepartment;
  selectedProgram;
  selectedProgramPlan;
  selectedProgramSpecialization;
  selectedCurrentTerm;
  selectedNextTerm;
  selectedSection;

  @track sectionOptions = [];
  @track studentResults = [];
  @track instituteOptions = [];
  @track institudeDepartmentOptions = [];
  @track programOptions = [];
  @track programPlanOptions = [];
  @track programSpecializationOptions = [];
  @track templateInfo;
  @track selectedStudentRows = [];
  @track academicTermOptions = [];

  isThemeLoading = true;
  isInitLoading = true;
  pendingPrimary;
  pendingSecondary;

  connectedCallback() {
    this.initialize();
  }

  renderedCallback() {
    if (this.pendingPrimary) {
      this.setThemePrimary(this.pendingPrimary);
      this.pendingPrimary = null;
    }
    if (this.pendingSecondary) {
      this.setThemeSecondary(this.pendingSecondary);
      this.pendingSecondary = null;
    }
  }

  setThemePrimary(value) {
    if (!value) return;
    if (this.template && this.template.host) {
      this.template.host.style.setProperty("--theme-primary", value);
    } else {
      this.pendingPrimary = value;
    }
  }

  setThemeSecondary(value) {
    if (!value) return;
    if (this.template && this.template.host) {
      this.template.host.style.setProperty("--theme-secondary", value);
    } else {
      this.pendingSecondary = value;
    }
  }

  get isSkeletonLoading() {
    return this.isThemeLoading || this.isInitLoading;
  }

  async initialize() {
    this.isInitLoading = true;
    try {
      await Promise.allSettled([this.loadThemeColors(), this.loadInstitutes(), this.loadInstituteDepartments(), this.loadPrograms()]);
    } finally {
      this.isInitLoading = false;
    }
  }

  async loadThemeColors() {
    this.isThemeLoading = true;
    try {
      const colors = await getThemeColors();
      if (colors && colors.primary) {
        this.setThemePrimary(colors.primary);
      }
      if (colors && colors.secondary) {
        this.setThemeSecondary(colors.secondary);
      }
    } catch {
      // ignore theme load errors
    } finally {
      this.isThemeLoading = false;
    }
  }

  async loadInstitutes() {
    try {
      const res = await getInstitutes();
      this.instituteOptions = (res || []).map((r) => ({
        label: r.Name,
        value: r.Id,
      }));
    } catch (error) {
      this.instituteOptions = [];
      this.showToast("Error", error?.body?.message || error?.message || "Failed to load institutes", "error");
    }
  }

  async loadInstituteDepartments() {
    try {
      const res = await getInstituteDepartment();
      this.institudeDepartmentOptions = (res || []).map((r) => ({
        label: r.Name,
        value: r.Id,
      }));
    } catch (error) {
      this.institudeDepartmentOptions = [];
      this.showToast("Error", error?.body?.message || error?.message || "Failed to load departments", "error");
    }
  }

  async loadPrograms() {
    try {
      const res = await getPrograms();
      this.programOptions = (res || []).map((r) => ({
        label: r.Name,
        value: r.Id,
      }));
    } catch (error) {
      this.programOptions = [];
      this.showToast("Error", error?.body?.message || error?.message || "Failed to load programs", "error");
    }
  }

  handleInstituteChange(e) {
    this.selectedInstitute = e.detail.value;
  }

  handleDepartmentChange(e) {
    this.selectedInstituteDepartment = e.detail.value;
  }

  handleCurrentTermChange(event) {
    this.selectedCurrentTerm = event.detail.value;
  }

  handleNextTermChange(event) {
    this.selectedNextTerm = event.detail.value;
  }

  async handleProgramChange(e) {
    this.selectedProgram = e.detail.value;
    this.selectedProgramPlan = null;
    this.selectedProgramSpecialization = null;
    this.programPlanOptions = [];
    this.programSpecializationOptions = [];

    if (!this.selectedProgram) return;

    const plans = await getProgramPlan({
      learningProgramId: this.selectedProgram,
    });

    this.programPlanOptions = plans.map((p) => ({
      label: p.Name,
      value: p.Id,
    }));
  }

  async handleProgramPlanChange(e) {
    this.selectedProgramPlan = e.detail.value;
    this.selectedProgramSpecialization = null;
    this.programSpecializationOptions = [];
    this.selectedCurrentTerm = null;
    this.selectedNextTerm = null;
    this.academicTermOptions = [];

    if (!this.selectedProgramPlan) return;
    const specs = await getProgramSpecializations({
      learningProgramPlanId: this.selectedProgramPlan,
    });

    this.programSpecializationOptions = specs.map((s) => ({
      label: s.LearningPathwayTemplate.Name,
      value: s.LearningPathwayTemplateId,
    }));

    const terms = await getAcademicTermsByProgramPlan({
      learningProgramPlanId: this.selectedProgramPlan,
    });

    console.log("Academic terms from Apex:", terms);

    this.academicTermOptions = terms.map((t) => ({
      label: `${t.termName} (${t.academicYearName})`,
      value: t.termId,
    }));

    const sections = await getSectionsByProgramPlan({
      learningProgramPlanId: this.selectedProgramPlan,
    });

    this.sectionOptions = sections.map((sec) => ({
      label: sec,
      value: sec,
    }));
  }

  async handleSearch() {
    this.studentResults = [];

    if (!this.selectedCurrentTerm || !this.selectedProgramPlan || !this.selectedSection) {
      return;
    }

    const results = await searchStudentsByCurrentTermAndProgramPlan({
      currentAcademicTermId: this.selectedCurrentTerm,
      nextAcademicTermId: this.selectedNextTerm,
      learningProgramPlanId: this.selectedProgramPlan,
      classCohort: this.selectedSection,
    });

    this.studentResults = results;
  }

  async handleSaveEnrollment() {
  try {
    const learnerProgramIds = this.selectedStudentRows.map(
      (row) => row.learnerProgramId
    );

    await createAcademicTermEnrollments({
      learnerProgramIds: learnerProgramIds,
      nextAcademicTermId: this.selectedNextTerm,
      learnerAccountId: this.selectedInstitute,
    });

    this.studentResults = this.studentResults.filter(
      (row) => !learnerProgramIds.includes(row.learnerProgramId)
    );

    this.selectedStudentRows = [];
    this.showToast("Success", "Academic Term Enrollments created", "success");
  } catch (error) {
    console.error(error);
    this.showToast("Error", error.body?.message || "Failed to save", "error");
  }
}

get selectedRowIds() {
return this.selectedStudentRows.map((row) => row.learnerProgramId);
}

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  handleProgramSpecializationChange(e) {
    this.selectedProgramSpecialization = e.detail.value;
  }

  handleSectionChange(event) {
    this.selectedSection = event.detail.value;
  }

  get isProgramPlanDisabled() {
    return !this.selectedProgram;
  }

  get isProgramSpecializationDisabled() {
    return !this.selectedProgramPlan;
  }

  get isProgramDisabled() {
    return false;
  }
  handleRowSelection(event) {
    this.selectedStudentRows = event.detail.selectedRows;
  }
  get isSaveDisabled() {
    return !this.selectedStudentRows.length;
  }

  get isDepartmentDisabled() {
    return !this.selectedInstitute;
  }

  handleClear() {
    this.selectedInstitute = null;
    this.selectedInstituteDepartment = null;
    this.selectedProgram = null;
    this.selectedProgramPlan = null;
    this.selectedProgramSpecialization = null;
    this.selectedCurrentTerm = null;
    this.selectedNextTerm = null;
    this.selectedSection = null;
    this.academicTermOptions = [];
    this.programPlanOptions = [];
    this.programSpecializationOptions = [];
    this.sectionOptions = [];
    this.studentResults = [];
  }
}