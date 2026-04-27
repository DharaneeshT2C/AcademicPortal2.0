import { LightningElement, track, wire } from "lwc";
import getProgramTemplatesForSemester from "@salesforce/apex/KenPortalCourseEnrollmentController.getProgramTemplatesForSemester";
import OrganizationDefaultsApiController from "@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults";
import rightArrow from '@salesforce/resourceUrl/RightArrow';

export default class PortalCourseEnrollmentDetails extends LightningElement {
  courseBrochureRoute = "/coursebroucher";
  courseDetailsRoute = "/pathway-configuration";
  @track programs = [];
  @track errorMessage = "";
  @track isLoading = false;
  themeLoading = true;
  organizationDefaults = {};

  isHelpModalOpen = false;
  isScheduleModalOpen = false;
  selectedSemester = null;
  selectedAcademicSessionId = null;

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

  get showSkeleton() {
    return this.isLoading || this.themeLoading;
  }

  connectedCallback() {
    const params = new URLSearchParams(window.location.search || "");
    const semesterParam = params.get("semester") || params.get("c__semester");
    this.selectedAcademicSessionId = params.get("academicSessionId") || params.get("c__academicSessionId");
    const parsedSemester = Number(semesterParam);
    if (!Number.isNaN(parsedSemester) && parsedSemester > 0) {
      this.selectedSemester = parsedSemester;
    }
    this.loadProgramTemplates();
  }

  get semesterTitle() {
    return this.selectedSemester ? `Semester ${this.selectedSemester}` : "Semester";
  }

  get hasPrograms() {
    return Array.isArray(this.programs) && this.programs.length > 0;
  }

  get isSelectCoursesDisabled() {
    return this.programs.some((program) => program.requiresEnrollment);
  }

  loadProgramTemplates() {
    if (!this.selectedSemester) {
      this.programs = [];
      return;
    }
    this.isLoading = true;
    this.errorMessage = "";
    getProgramTemplatesForSemester({ semesterNumber: this.selectedSemester })
      .then((data) => {
        const uniqueByType = new Map();
        (data || []).forEach((item) => {
          const normalizedType = (item.templateType || "").trim().toLowerCase();
          const typeKey = normalizedType || item.learningPathwayTemplateId || "";
          if (!uniqueByType.has(typeKey)) {
            uniqueByType.set(typeKey, {
              ...item,
              isEnrolled: item.isEnrolled === true,
            });
          } else {
            const existing = uniqueByType.get(typeKey);
            existing.isEnrolled = existing.isEnrolled || item.isEnrolled === true;
          }
        });
        const uniquePrograms = Array.from(uniqueByType.values());

        const orderedPrograms = [...uniquePrograms].sort((a, b) => {
          const aLabel = (a.templateType || a.learningPathwayTemplateName || "").toLowerCase();
          const bLabel = (b.templateType || b.learningPathwayTemplateName || "").toLowerCase();
          const aIsMajor = aLabel.includes("major");
          const bIsMajor = bLabel.includes("major");
          if (aIsMajor === bIsMajor) {
            return 0;
          }
          return aIsMajor ? -1 : 1;
        });

        this.programs = orderedPrograms.map((item, index) => {
          const typeLabel = item.templateType || item.learningPathwayTemplateName || "-";
          const isPrimaryProgram = typeLabel.toLowerCase().includes("major");
          const isEnrolled = item.isEnrolled === true;
          return {
            id: item.learningPathwayTemplateId || `row-${index}`,
            name: typeLabel,
            mandatoryText: "Mandatory: 0 / 12 credits",
            electiveText: "Electives: 0 / 6 credits",
            statusText: isPrimaryProgram
              ? "Incomplete"
              : isEnrolled
                ? "Pathway enrolled."
                : "Choose a minor pathway to get started with course enrolment.",
            statusClass: "status-line status-warning",
            showCreditSummary: isPrimaryProgram,
            showEnrollButton: !isPrimaryProgram && !isEnrolled,
            requiresEnrollment: !isPrimaryProgram && !isEnrolled,
            lastDateText: isPrimaryProgram ? "Last Date: 12 May 2026" : "Last Date: 23 April 2026",
            pathwayType: typeLabel,
          };
        });
      })
      .catch((error) => {
        this.programs = [];
        this.errorMessage = error?.body?.message || error?.message || "Failed to load program templates.";
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  openHelpModal() {
    this.isHelpModalOpen = true;
  }

  closeHelpModal() {
    this.isHelpModalOpen = false;
  }

  openScheduleModal() {
    this.isScheduleModalOpen = true;
  }

      get rightArrowUrl() {
          return rightArrow;
      }

  closeScheduleModal() {
    this.isScheduleModalOpen = false;
  }

  handleOpenBrochure(event) {
    const route = event.currentTarget?.dataset?.route;
    const templateId = event.currentTarget?.dataset?.template;
    const pathwayType = event.currentTarget?.dataset?.pathwayType;
    if (route) {
      const currentPath = window.location.pathname || "";
      const targetRoute = route.startsWith("/") ? route : `/${route}`;
      const currentPagePrefix = currentPath.replace(
        /\/(?:courseenrollmentdetails|pathway-type-configuration|pathway-configuration)(?:\/.*)?$/i,
        "",
      );
      const sitePrefix = currentPagePrefix && currentPagePrefix !== "/" ? currentPagePrefix : "";
      const queryParts = [];
      if (this.selectedSemester) {
        queryParts.push(`semester=${encodeURIComponent(String(this.selectedSemester))}`);
      }
      if (this.selectedAcademicSessionId) {
        queryParts.push(`academicSessionId=${encodeURIComponent(this.selectedAcademicSessionId)}`);
      }
      if (templateId) {
        queryParts.push(`templateId=${encodeURIComponent(templateId)}`);
      }
      if (pathwayType) {
        queryParts.push(`pathwayType=${encodeURIComponent(pathwayType)}`);
      }
      const query = queryParts.length ? `?${queryParts.join("&")}` : "";
      window.location.assign(`${sitePrefix}${targetRoute}${query}`);
    }
  }

  handleSelectCourses(event) {
    const route = event.currentTarget?.dataset?.route;
    if (!route || this.isSelectCoursesDisabled) {
      return;
    }
    const currentPath = window.location.pathname || "";
    const targetRoute = route.startsWith("/") ? route : `/${route}`;
    const currentPagePrefix = currentPath.replace(
      /\/(?:courseenrollmentdetails|pathway-type-configuration|pathway-configuration)(?:\/.*)?$/i,
      "",
    );
    const sitePrefix = currentPagePrefix && currentPagePrefix !== "/" ? currentPagePrefix : "";
    const queryParts = [];
    if (this.selectedSemester) {
      queryParts.push(`semester=${encodeURIComponent(String(this.selectedSemester))}`);
    }
    if (this.selectedAcademicSessionId) {
      queryParts.push(`academicSessionId=${encodeURIComponent(this.selectedAcademicSessionId)}`);
    }
    queryParts.push("selectedPathwaysOnly=true");
    const query = queryParts.length ? `?${queryParts.join("&")}` : "";
    window.location.assign(`${sitePrefix}${targetRoute}${query}`);
  }
}