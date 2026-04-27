import { LightningElement, api } from "lwc";
import submitEnrollmentRequest from "@salesforce/apex/KenCourseEnrollmentController.submitEnrollmentRequest";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class SelectedCoursesSummary extends LightningElement {
  @api mandatoryCourses = [];
  @api electiveCourses = [];
  @api selectedSemester;

  get semesterLabel() {
    return this.selectedSemester ? `Semester ${this.selectedSemester}` : "";
  }

  get allCourses() {
    return [...this.mandatoryCourses.map((c) => ({ ...c, type: "Mandatory" })), ...this.electiveCourses.map((c) => ({ ...c, type: "Elective" }))];
  }

  get totalCredits() {
    return this.allCourses.reduce((sum, c) => sum + (c.credits || 0), 0);
  }

  get mandatoryCredits() {
    return this.mandatoryCourses.reduce((sum, c) => sum + (c.credits || 0), 0);
  }

  get electiveCredits() {
    return this.electiveCourses.reduce((sum, c) => sum + (c.credits || 0), 0);
  }

  handleSubmitEnrollment() {
    const courseOfferingIds = this.allCourses.map((c) => c.courseOfferingId);

    const planRequirementIds = this.allCourses.map((c) => c.learningProgramPlanRequirementId);

    submitEnrollmentRequest({
      courseOfferingIds,
      planRequirementIds,
    })
      .then(() => {
        this.showSuccessToast();
      })
      .catch((error) => {
        console.error("Enrollment error:", error);
      });
  }

  showSuccessToast() {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Success",
        message: "Enrollment request submitted successfully",
        variant: "success",
        mode: "dismissable",
      }),
    );
  }
}