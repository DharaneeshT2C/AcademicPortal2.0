import { LightningElement, track, wire } from "lwc";
import getProgramPath from "@salesforce/apex/KenCourseEnrollmentController.getProgramPath";
import enrollInPathway from "@salesforce/apex/KenCourseEnrollmentController.enrollInPathway";
export default class ProgramPath extends LightningElement {
  @track pathwayTemplates = [];

  @wire(getProgramPath)
  wiredPathwayTemplates({ data, error }) {
    if (data) {
      this.pathwayTemplates = data.map((c) => ({
        id: c.learningPathwayTemplateId,
        name: c.Name,
        pathway: c.pathwayType,
        status: c.status,
        isEnrolled: c.isEnrolled,
      }));
    } else if (error) {
      console.error("Error fetching program path", error);
    }
  }

  handleEnroll(event) {
    const templateId = event.target.dataset.id;
    console.log("templateId+++ " + templateId);

    enrollInPathway({ learningPathwayTemplateId: templateId })
      .then(() => {
        this.pathwayTemplates = this.pathwayTemplates.map((p) => (p.id === templateId ? { ...p, isEnrolled: true } : p));
      })
      .catch((error) => {
        console.error(error);
      });
  }
}