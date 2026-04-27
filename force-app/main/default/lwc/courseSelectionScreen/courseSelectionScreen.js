import { LightningElement, api, wire, track } from "lwc";
import getCoursesForSemester from "@salesforce/apex/KenCourseEnrollmentController.getCoursesForSemester";

const DEFAULT_IMAGE = "https://images.unsplash.com/photo-1531482615713-2afd69097998";

export default class CourseSelectionScreen extends LightningElement {
  @api selectedSemester;
  @api academicSessionId;

  @track courses = [];
  @track filteredCourses = [];

  activeTab = "MANDATORY";
  searchKey = "";

  // 🔹 ACCORDION STATE (NEW)
  openTemplateId = null;

  /* ------------------ APEX ------------------ */

  @wire(getCoursesForSemester, {
    semesterNumber: "$selectedSemester",
    academicSessionId: "$academicSessionId",
  })
  wiredCourses({ data, error }) {
    if (data) {
      this.courses = data.map((c, index) => ({
        ...c,
        courseOfferingId: c.courseOfferingId,
        learningProgramPlanRequirementId: c.learningProgramPlanRequirementId,
        imageUrl: c.imageUrl ? c.imageUrl : DEFAULT_IMAGE,
        sequence: c.sequence,
        courseCode: c.courseCode,

        // GROUPING FIELDS
        templateId: c.learningPathwayTemplateId,
        templateName: c.learningPathwayTemplateName,
        templateType: c.templateType,

        uniqueKey: c.courseOfferingId ? c.courseOfferingId : `${c.learningCourseId}-${index}`,

        isMandatory: c.courseType && c.courseType.toLowerCase() === "requirement",

        isAdded: false,
      }));

      this.applyFilters();
    } else if (error) {
      console.error("Courses Apex Error", error);
    }
  }

  /* ------------------ GROUPING ------------------ */

  get groupedCourses() {
    const map = new Map();

    this.filteredCourses.forEach((course) => {
      const key = course.templateId;

      if (!map.has(key)) {
        map.set(key, {
          templateId: key,
          templateName: course.templateName,
          templateType: course.templateType,
          isOpen: this.openTemplateId === key,
          courses: [],
        });
      }

      map.get(key).courses.push(course);
    });

    return Array.from(map.values());
  }

  /* ------------------ ACCORDION HANDLER (NEW) ------------------ */

  toggleAccordion(event) {
    const templateId = event.currentTarget.dataset.id;

    this.openTemplateId = this.openTemplateId === templateId ? null : templateId;
  }

  /* ------------------ FILTERING ------------------ */

  applyFilters() {
    let list = [...this.courses];

    if (this.activeTab === "MANDATORY") {
      list = list.filter((c) => c.isMandatory);
    } else {
      list = list.filter((c) => !c.isMandatory);
    }

    if (this.searchKey) {
      const key = this.searchKey.toLowerCase();
      list = list.filter((c) => c.courseName.toLowerCase().includes(key));
    }

    this.filteredCourses = list;
  }

  /* ------------------ TABS ------------------ */

  showMandatory() {
    this.activeTab = "MANDATORY";
    this.applyFilters();
  }

  showElective() {
    this.activeTab = "ELECTIVE";
    this.applyFilters();
  }

  handleSearch(event) {
    this.searchKey = event.target.value;
    this.applyFilters();
  }

  /* ------------------ ADD / REMOVE ------------------ */

  handleToggleAdd(event) {
    const key = event.currentTarget.dataset.key;

    this.courses = this.courses.map((course) => (course.uniqueKey === key ? { ...course, isAdded: !course.isAdded } : course));

    this.applyFilters();
  }

  /* ------------------ GETTERS ------------------ */

  get selectedCourses() {
    return this.courses.filter((c) => c.isAdded);
  }

  get totalSelectedCredits() {
    return this.selectedCourses.reduce((sum, c) => sum + (c.credits || 0), 0);
  }

  get mandatoryCredits() {
    return this.selectedCourses.filter((c) => c.isMandatory).reduce((sum, c) => sum + c.credits, 0);
  }

  get electiveCredits() {
    return this.selectedCourses.filter((c) => !c.isMandatory).reduce((sum, c) => sum + c.credits, 0);
  }

  /* ------------------ SUBMIT ------------------ */

  handleAddSelected() {
    const selectedMandatory = this.courses.filter((c) => c.isAdded && c.isMandatory);
    const selectedElective = this.courses.filter((c) => c.isAdded && !c.isMandatory);

    this.dispatchEvent(
      new CustomEvent("coursesselected", {
        detail: {
          mandatory: selectedMandatory,
          elective: selectedElective,
        },
        bubbles: true,
        composed: true,
      }),
    );
  }

  /* ------------------ CSS CLASSES ------------------ */

  get mandatoryTabClass() {
    return this.activeTab === "MANDATORY" ? "tab active" : "tab";
  }

  get electiveTabClass() {
    return this.activeTab === "ELECTIVE" ? "tab active" : "tab";
  }
}