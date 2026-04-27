import { LightningElement, api, wire, track } from "lwc";
import getCoursesForSemester from "@salesforce/apex/KenCourseEnrollmentController.getCoursesForSemester";
import OrganizationDefaultsApiController from "@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults";

const DEFAULT_IMAGE = "https://images.unsplash.com/photo-1531482615713-2afd69097998";

export default class PortalParticularCourseDetails extends LightningElement {
  @api selectedSemester;
  @api academicSessionId;
  @api selectedTemplateId;

  themeLoading = true;
  coursesLoading = true;
  organizationDefaults = {};

  @track courses = [];
  @track filteredCourses = [];

  activeTab = "MANDATORY";
  searchKey = "";

  // 🔹 ACCORDION STATE (NEW)
  openTemplateId = null;

  applyOrganizationTheme() {
    const primary = this.organizationDefaults?.primary;
    const secondary = this.organizationDefaults?.secondary;

    if (primary && typeof primary === "string") {
      this.template.host.style.setProperty("--primary-color", primary);
    }
    if (secondary && typeof secondary === "string") {
      this.template.host.style.setProperty("--secondary-color", secondary);
    }
  }

  @wire(OrganizationDefaultsApiController)
  wiredOrganizationDefaults({ data, error }) {
    if (data) {
      this.organizationDefaults = data;
      // eslint-disable-next-line no-console
      console.log("Organization Defaults loaded", this.organizationDefaults);
      this.applyOrganizationTheme();
      this.themeLoading = false;
    } else if (error) {
      // eslint-disable-next-line no-console
      console.error("Organization Defaults load error", error);
      this.organizationDefaults = {};
      this.themeLoading = false;
    }
  }

  connectedCallback() {
    const params = new URLSearchParams(window.location.search || "");
    const semesterParam = params.get("semester") || params.get("c__semester");
    const sessionParam = params.get("academicSessionId") || params.get("c__academicSessionId");
    const templateParam = params.get("templateId") || params.get("c__templateId");

    const parsedSemester = Number(semesterParam);
    if (!Number.isNaN(parsedSemester) && parsedSemester > 0) {
      this.selectedSemester = parsedSemester;
    }
    if (sessionParam) {
      this.academicSessionId = sessionParam;
    }
    if (templateParam) {
      this.selectedTemplateId = templateParam;
    }
  }

  /* ------------------ APEX ------------------ */

  @wire(getCoursesForSemester, {
    semesterNumber: "$selectedSemester",
    academicSessionId: "$academicSessionId",
    learningPathwayTemplateId: "$selectedTemplateId",
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
    this.coursesLoading = false;
  }

  get showSkeleton() {
    return this.themeLoading || this.coursesLoading;
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

    return Array.from(map.values()).map((group) => ({
      ...group,
      indicator: group.isOpen ? "−" : "+",
    }));
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