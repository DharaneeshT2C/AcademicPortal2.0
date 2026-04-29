import { LightningElement, api, track, wire } from "lwc";
import getCoursesForSemester from "@salesforce/apex/KenPortalCourseEnrollmentController.getCoursesForSemester";
import getLearnerPathwaysForUser from "@salesforce/apex/KenPortalCourseEnrollmentController.getLearnerPathwaysForUser";
import getProgramTemplatesForSemester from "@salesforce/apex/KenPortalCourseEnrollmentController.getProgramTemplatesForSemester";
import createLearnerPathwayItems from "@salesforce/apex/KenPortalCourseEnrollmentController.createLearnerPathwayItems";
import getLearnerPathwayItemsForAfterEnrollment from "@salesforce/apex/KenPortalCourseEnrollmentController.getLearnerPathwayItemsForAfterEnrollment";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import OrganizationDefaultsApiController from "@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults";

const LIVE_DAY_ORDER = [
  { key: "monday", label: "Monday" },
  { key: "tuesday", label: "Tuesday" },
  { key: "wednesday", label: "Wednesday" },
  { key: "thursday", label: "Thursday" },
  { key: "friday", label: "Friday" },
  { key: "saturday", label: "Saturday" },
  { key: "sunday", label: "Sunday" },
  { key: "unscheduled", label: "Unscheduled" },
];

const LIVE_DAY_ALIASES = {
  mon: "monday",
  monday: "monday",
  tu: "tuesday",
  tue: "tuesday",
  tues: "tuesday",
  tuesday: "tuesday",
  wed: "wednesday",
  wednesday: "wednesday",
  th: "thursday",
  thu: "thursday",
  thur: "thursday",
  thurs: "thursday",
  thursday: "thursday",
  fri: "friday",
  friday: "friday",
  sat: "saturday",
  saturday: "saturday",
  sun: "sunday",
  sunday: "sunday",
};

export default class CbcsCourseSelection extends LightningElement {
  @api selectedSemester;
  @api academicSessionId;
  @api selectedTemplateId;
  @api selectedPathwaysOnly = false;

  @track mandatoryCourses = [];
  @track electiveCourses = [];
  @track selectedTemplateName = "";
  @track selectedPathwayLabels = [];
  @track pathwayOptions = [];
  @track electiveGroupOpenState = {};
  @track selectedTemplateIds = [];
  @track allFetchedCourses = [];
  @track selectedElectiveTokens = [];
  @track blockedSelectionWarnings = {};
  @track selectedFacultyOptionByCourse = {};
  @track liveDayOpenState = {};
  organizationDefaults = {};
  themeLoading = true;
  dataLoading = true;

  isMandatoryOpen = true;
  isElectivesOpen = true;
  isReviewModalOpen = false;
  currentPathwayIndex = 0;
  isSubmitting = false;
  focusedCourseId = null;
  isLiveHidden = false;

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
    const templateNameParam = params.get("templateName") || params.get("c__templateName");
    const selectedOnlyParam = params.get("selectedPathwaysOnly") || params.get("c__selectedPathwaysOnly");

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
    if (templateNameParam) {
      this.selectedTemplateName = templateNameParam;
    }
    if (selectedOnlyParam !== null) {
      this.selectedPathwaysOnly = String(selectedOnlyParam).toLowerCase() !== "false";
    } else {
      this.selectedPathwaysOnly = true;
    }
    this.initializeScreenData();
  }

  initializeScreenData() {
    if (this.selectedPathwaysOnly === true) {
      this.loadLearnerPathways()
        .then(() => Promise.all([this.loadCoursesFromSelectedTemplates(), this.loadExistingSelections()]))
        .then(() => this.applyCurrentPathwayCourses())
        .catch((error) => {
          // eslint-disable-next-line no-console
          console.error("cbcsCourseSelection init error", error);
        })
        .finally(() => {
          this.dataLoading = false;
        });
      return;
    }
    this.loadCoursesFromSelectedTemplates()
      .then(() => this.loadExistingSelections())
      .then(() => this.applyCurrentPathwayCourses())
      .catch((error) => {
        // eslint-disable-next-line no-console
        console.error("cbcsCourseSelection init error", error);
      })
      .finally(() => {
        this.dataLoading = false;
      });
  }

  get showSkeleton() {
    return this.themeLoading || this.dataLoading;
  }

  get enrollmentLayoutClass() {
    return this.isLiveHidden ? "enrollment-layout1 live-hidden" : "enrollment-layout1";
  }

  get liveToggleLabel() {
    return this.isLiveHidden ? "Show Live" : "Hide Live";
  }

  toggleLiveSection() {
    this.isLiveHidden = !this.isLiveHidden;
  }

  loadExistingSelections() {
    if (!this.academicSessionId) {
      return Promise.resolve();
    }
    return getLearnerPathwayItemsForAfterEnrollment({ academicSessionId: this.academicSessionId })
      .then((rows) => {
        const tokens = [];
        (rows || []).forEach((row) => {
          const typeKey = this.normalizeRuleType(row?.courseType);
          if (typeKey !== "requirementplaceholder") {
            return;
          }
          if (row.learningPathwayTemplateItemId) {
            tokens.push(String(row.learningPathwayTemplateItemId));
          } else if (row.learningPathwayTemplateId && row.learningCourseId) {
            tokens.push(`${row.learningPathwayTemplateId}::${row.learningCourseId}`);
          }
        });
        this.selectedElectiveTokens = Array.from(new Set(tokens));
      })
      .catch((error) => {
        // eslint-disable-next-line no-console
        console.error("Failed to load existing selections", error);
      });
  }

  loadLearnerPathways() {
    return Promise.all([getLearnerPathwaysForUser(), getProgramTemplatesForSemester({ semesterNumber: this.selectedSemester || null })])
      .then(([rows, templateRows]) => {
        const seen = new Set();
        const pathwayOptions = [];
        const templateMetaById = new Map();
        const semesterTemplateIds = new Set();
        const semesterTemplateNameKeys = new Set();

        (templateRows || []).forEach((tpl) => {
          const templateId = tpl?.learningPathwayTemplateId;
          if (!templateId) {
            return;
          }
          semesterTemplateIds.add(String(templateId));
          const typeLabel = (tpl.templateType || "").trim();
          const nameLabel = (tpl.learningPathwayTemplateName || "").trim();
          const label = typeLabel || nameLabel;
          if (nameLabel) {
            semesterTemplateNameKeys.add(nameLabel.toLowerCase());
          }
          templateMetaById.set(String(templateId), {
            templateId,
            label,
            isMajorTemplate: label.toLowerCase().includes("major"),
            isDefaultPathway: tpl.isDefaultPathway === true,
          });
        });

        (rows || []).forEach((row) => {
          const label = (row.name || "").trim();
          if (!label) {
            return;
          }
          const templateId = row.learningPathwayTemplateId;
          const templateIdKey = templateId ? String(templateId) : null;
          const pathwayNameKey = label.toLowerCase();
          const inSemesterTemplateScope = templateIdKey ? semesterTemplateIds.has(templateIdKey) : semesterTemplateNameKeys.has(pathwayNameKey);
          if (!inSemesterTemplateScope) {
            return;
          }
          const dedupeKey = templateId ? String(templateId) : label.toLowerCase();
          if (!seen.has(dedupeKey)) {
            seen.add(dedupeKey);
            const meta = templateId ? templateMetaById.get(String(templateId)) : null;
            pathwayOptions.push({
              id: templateId || null,
              label,
              learnerPathwayId: row.learnerPathwayId || null,
              isMajorTemplate: meta ? meta.isMajorTemplate : label.toLowerCase().includes("major"),
              isDefaultPathway: meta ? meta.isDefaultPathway : false,
              originalIndex: pathwayOptions.length,
            });
          }
        });

        // Ensure major pathway is visible in stepper even if no LearnerPathway row exists yet.
        (templateRows || []).forEach((tpl) => {
          const typeLabel = (tpl.templateType || "").trim();
          const nameLabel = (tpl.learningPathwayTemplateName || "").trim();
          const majorLabel = typeLabel || nameLabel;
          const isMajor = majorLabel.toLowerCase().includes("major");
          const templateId = tpl.learningPathwayTemplateId;
          if (!isMajor || !templateId) {
            return;
          }
          const dedupeKey = String(templateId);
          if (seen.has(dedupeKey)) {
            return;
          }
          seen.add(dedupeKey);
          pathwayOptions.push({
            id: templateId,
            label: majorLabel,
            learnerPathwayId: null,
            isMajorTemplate: true,
            isDefaultPathway: tpl.isDefaultPathway === true,
            originalIndex: pathwayOptions.length,
          });
        });

        const orderedPathways = [...pathwayOptions].sort((a, b) => {
          const aDefaultMajor = a.isDefaultPathway && a.isMajorTemplate;
          const bDefaultMajor = b.isDefaultPathway && b.isMajorTemplate;
          if (aDefaultMajor !== bDefaultMajor) {
            return aDefaultMajor ? -1 : 1;
          }
          if (a.isMajorTemplate !== b.isMajorTemplate) {
            return a.isMajorTemplate ? -1 : 1;
          }
          return (a.originalIndex || 0) - (b.originalIndex || 0);
        });

        this.selectedPathwayLabels = orderedPathways.map((item) => item.label);
        this.pathwayOptions = orderedPathways;
        this.selectedTemplateIds = orderedPathways.map((item) => item.id).filter((id) => Boolean(id));
        this.currentPathwayIndex = 0;
        if (this.selectedPathwayLabels.length) {
          this.selectedTemplateName = this.selectedPathwayLabels[0];
        }
      })
      .catch((err) => {
        // eslint-disable-next-line no-console
        console.error("Failed to load learner pathways", err);
        this.selectedPathwayLabels = [];
        this.pathwayOptions = [];
        this.selectedTemplateIds = [];
      });
  }

  loadCoursesFromSelectedTemplates() {
    if (!this.selectedSemester) {
      this.processCourses([]);
      return Promise.resolve();
    }

    const explicitTemplateIds = this.selectedTemplateId ? [this.selectedTemplateId] : [];
    const templateIds = explicitTemplateIds.length ? explicitTemplateIds : this.selectedTemplateIds;

    if (!templateIds.length) {
      return getCoursesForSemester({
        semesterNumber: this.selectedSemester,
        academicSessionId: this.academicSessionId,
        learningPathwayTemplateId: null,
        selectedPathwaysOnly: this.selectedPathwaysOnly,
      })
        .then((data) => this.processCourses(data || []))
        .catch((error) => {
          // eslint-disable-next-line no-console
          console.error("cbcsCourseSelection Apex Error", error);
          this.processCourses([]);
        });
    }

    const calls = templateIds.map((templateId) =>
      getCoursesForSemester({
        semesterNumber: this.selectedSemester,
        academicSessionId: this.academicSessionId,
        learningPathwayTemplateId: templateId,
        selectedPathwaysOnly: false,
      }),
    );

    return Promise.all(calls)
      .then((responses) => {
        const merged = [];
        const seen = new Set();
        (responses || []).forEach((rows) => {
          (rows || []).forEach((course) => {
            const key = `${course.learningPathwayTemplateId || ""}::${course.learningCourseId || ""}`;
            if (seen.has(key)) {
              return;
            }
            seen.add(key);
            merged.push(course);
          });
        });
        this.processCourses(merged);
      })
      .catch((error) => {
        // eslint-disable-next-line no-console
        console.error("cbcsCourseSelection Apex Error", error);
        this.processCourses([]);
      });
  }

  processCourses(data) {
    if (!Array.isArray(data)) {
      data = [];
    }
    this.allFetchedCourses = data;
    const validTokens = new Set(
      data
        .filter((course) => this.normalizeRuleType(course?.courseType) === "requirementplaceholder")
        .map((course) => this.getElectiveTokenFromBackend(course))
        .filter((token) => Boolean(token)),
    );
    this.selectedElectiveTokens = (this.selectedElectiveTokens || []).filter((token) => validTokens.has(token));
    const nextBlockedWarnings = {};
    Object.keys(this.blockedSelectionWarnings || {}).forEach((token) => {
      if (validTokens.has(token)) {
        nextBlockedWarnings[token] = this.blockedSelectionWarnings[token];
      }
    });
    this.blockedSelectionWarnings = nextBlockedWarnings;
    const validCourseIds = new Set(data.map((course, index) => String(course.courseOfferingId || course.learningCourseId || `course-${index}`)));
    const nextSelectedFaculty = {};
    Object.keys(this.selectedFacultyOptionByCourse || {}).forEach((courseId) => {
      if (validCourseIds.has(courseId)) {
        nextSelectedFaculty[courseId] = this.selectedFacultyOptionByCourse[courseId];
      }
    });
    this.selectedFacultyOptionByCourse = nextSelectedFaculty;
    this.applyCurrentPathwayCourses();
  }

  applyCurrentPathwayCourses() {
    const currentPathway = this.currentPathway;
    const activeTemplateId = currentPathway?.id;
    const data = activeTemplateId ? this.allFetchedCourses.filter((course) => course.learningPathwayTemplateId === activeTemplateId) : this.allFetchedCourses;

    const mandatory = [];
    const elective = [];

    data.forEach((course, index) => {
      const key = course.courseOfferingId || course.learningCourseId || `course-${index}`;
      const subtitleBits = [];
      if (course.courseCode) {
        subtitleBits.push(course.courseCode);
      }
      if (course.learningPathwayTemplateName) {
        subtitleBits.push(course.learningPathwayTemplateName);
      }
      subtitleBits.push(`${course.credits || 0} credits`);

      const base = {
        id: key,
        title: course.courseName || "-",
        subtitle: subtitleBits.join(" - "),
        groupName: course.groupName,
        ruleType: course.ruleType,
        minCourseCount: course.minCourseCount,
        maxCourseCount: course.maxCourseCount,
        maxCreditLimit: course.maxCreditLimit,
        backendCourse: course,
      };

      const typeNormalized = (course.courseType || "").trim().toLowerCase();
      const typeKey = typeNormalized.replace(/[\s_]+/g, "");
      const isMandatory = typeKey === "requirement";
      const isElective = typeKey === "requirementplaceholder";
      if (isMandatory) {
        const facultyState = this.buildCourseFacultyState(course, key, "m");
        mandatory.push({
          ...base,
          cardClass: "course-card course-card-selected",
          checkClass: "check-icon",
          showConflict: false,
          conflictText: "",
          ...facultyState,
        });
      } else if (isElective) {
        const electiveToken = this.getElectiveTokenFromBackend(course);
        const facultyState = this.buildCourseFacultyState(course, key, "e");
        elective.push({
          ...base,
          selected: electiveToken ? (this.selectedElectiveTokens || []).includes(electiveToken) : false,
          selectable: true,
          showDetailsOnSelect: true,
          preference: "1st Preference",
          preferenceId: `preference-${key}`,
          electiveToken,
          ...facultyState,
          showWarning: false,
          warningText: "",
        });
      }
    });

    this.mandatoryCourses = mandatory;
    this.blockedSelectionWarnings = {};
    this.electiveCourses = this.applyElectiveGroupWarnings(elective, { enforceMinimum: false });
    this.selectedTemplateName = currentPathway?.label || this.selectedTemplateName || "Selected Pathway";
    this.initializeElectiveGroupState();
  }

  get mandatoryRequirementClass() {
    return this.isMandatoryOpen ? "requirement-card requirement-card-open" : "requirement-card requirement-card-collapsed";
  }

  get electivesRequirementClass() {
    return this.isElectivesOpen ? "requirement-card requirement-card-open" : "requirement-card requirement-card-collapsed";
  }

  get mandatoryBodyClass() {
    return this.isMandatoryOpen ? "accordion-body accordion-body-open" : "accordion-body accordion-body-collapsed";
  }

  get electivesBodyClass() {
    return this.isElectivesOpen ? "accordion-body accordion-body-open" : "accordion-body accordion-body-collapsed";
  }

  get mandatoryIndicatorClass() {
    return this.isMandatoryOpen ? "collapse-indicator collapse-indicator-open" : "collapse-indicator";
  }

  get electivesIndicatorClass() {
    return this.isElectivesOpen ? "collapse-indicator collapse-indicator-open" : "collapse-indicator";
  }

  get electiveSelectedCount() {
    return this.electiveCourses.filter((course) => course.selected).length;
  }

  get electiveSelectableCount() {
    return this.electiveCourses.filter((course) => course.selectable).length;
  }

  get electiveSummaryText() {
    return `${this.electiveSelectedCount} out of ${this.electiveSelectableCount} course(s) selected`;
  }

  get programHeaderTitle() {
    if (this.selectedTemplateName) {
      return this.selectedTemplateName;
    }
    return "Selected Pathway";
  }

  get semesterTitle() {
    if (this.selectedSemester) {
      return `Semester ${this.selectedSemester}`;
    }
    return "Semester";
  }

  get lastDateText() {
    return "Last Date: 12 May 2026";
  }

  get stepperItems() {
    const labels = this.pathwayOptions.length ? this.pathwayOptions.map((item) => item.label) : ["Selected Pathway"];
    const currentIndex = Math.min(this.currentPathwayIndex, labels.length - 1);
    return labels.map((label, index) => {
      const isCurrent = index === currentIndex;
      const isCompleted = index < currentIndex;
      return {
        id: `step-${index + 1}`,
        label,
        numberLabel: isCurrent ? String(index + 1) : isCompleted ? "✓" : "",
        circleClass: isCurrent ? "step-circle step-circle-active" : isCompleted ? "step-circle step-circle-completed" : "step-circle",
        labelClass: isCurrent ? "step-label step-label-active" : "step-label",
        showConnector: index < labels.length - 1,
      };
    });
  }

  get stepperProgressStyle() {
    const totalSteps = this.stepperItems.length || 1;
    const currentStep = Math.min(this.currentPathwayIndex + 1, totalSteps);
    const width = (currentStep / totalSteps) * 100;
    return `width:${width}%`;
  }

  get stepperCounterText() {
    const total = this.stepperItems.length || 1;
    const current = Math.min(this.currentPathwayIndex + 1, total);
    return `Step ${current} out of ${total}`;
  }

  get stepperFlowText() {
    const total = this.stepperItems.length || 1;
    return Array.from({ length: total }, (_, index) => `Step ${index + 1}`).join(" \u2192 ");
  }

  get workflowCurrentStep() {
    if (this.isSubmitting) {
      return 3;
    }
    if (this.isReviewModalOpen) {
      return 2;
    }
    return 1;
  }

  get workflowStepText() {
    return `Step ${this.workflowCurrentStep} of 3`;
  }

  get workflowFlowText() {
    return "Select Courses \u2192 Review \u2192 Confirm";
  }

  get totalSelectableCourseCount() {
    return this.mandatoryCourses.length + this.electiveSelectableCount;
  }

  get totalSelectedCourseCount() {
    return this.mandatoryCourses.length + this.electiveSelectedCount;
  }

  get selectedCourseCountText() {
    return `${this.totalSelectedCourseCount}/${this.totalSelectableCourseCount} courses selected`;
  }

  get totalSelectableCredits() {
    const mandatory = this.mandatoryCourses.reduce((sum, course) => sum + this.getCourseCredits(course), 0);
    const electives = this.electiveCourses.filter((course) => course.selectable).reduce((sum, course) => sum + this.getCourseCredits(course), 0);
    return mandatory + electives;
  }

  get selectedCredits() {
    const mandatory = this.mandatoryCourses.reduce((sum, course) => sum + this.getCourseCredits(course), 0);
    const electives = this.electiveCourses.filter((course) => course.selected).reduce((sum, course) => sum + this.getCourseCredits(course), 0);
    return mandatory + electives;
  }

  get creditCompletionText() {
    return `${this.selectedCredits}/${this.totalSelectableCredits} credits selected`;
  }

  get currentPathway() {
    if (!this.pathwayOptions.length) {
      return null;
    }
    return this.pathwayOptions[Math.min(this.currentPathwayIndex, this.pathwayOptions.length - 1)];
  }

  get isLastPathwayStep() {
    if (!this.pathwayOptions.length) {
      return true;
    }
    return this.currentPathwayIndex >= this.pathwayOptions.length - 1;
  }

  get isFirstPathwayStep() {
    return this.currentPathwayIndex <= 0;
  }

  get primaryFooterButtonLabel() {
    if (this.hasScheduleConflicts) {
      return "Resolve conflicts to continue";
    }
    return this.isLastPathwayStep ? "Submit Enrollment" : "Proceed to Next";
  }

  get isPrimaryFooterDisabled() {
    return this.hasScheduleConflicts;
  }

  get secondaryFooterButtonLabel() {
    return this.isFirstPathwayStep ? "Cancel" : "Previous Step";
  }

  handleSecondaryFooterAction() {
    if (this.isFirstPathwayStep) {
      this.handleCancelFlow();
      return;
    }
    this.currentPathwayIndex -= 1;
    this.applyCurrentPathwayCourses();
  }

  handlePrimaryFooterAction() {
    if (this.hasScheduleConflicts) {
      const firstConflict = this.conflictSummaryItems[0];
      const firstCourseId = firstConflict?.courseIds?.[0];
      if (firstCourseId) {
        this.openAccordionsForCourse(firstCourseId);
        this.focusedCourseId = firstCourseId;
        this.scrollCourseIntoView(firstCourseId);
      }
      return;
    }
    if (!this.validateElectiveSelections()) {
      return;
    }
    if (this.isLastPathwayStep) {
      this.isReviewModalOpen = true;
      return;
    }
    this.currentPathwayIndex += 1;
    this.applyCurrentPathwayCourses();
  }

  handleCancelFlow() {
    const currentPath = window.location.pathname || "";
    const currentPagePrefix = currentPath.replace(/\/(cbcscourseselection|courseparticulardetails)(?:\/.*)?$/i, "");
    const sitePrefix = currentPagePrefix && currentPagePrefix !== "/" ? currentPagePrefix : "/s";
    const queryParts = [];
    if (this.selectedSemester) {
      queryParts.push(`semester=${encodeURIComponent(String(this.selectedSemester))}`);
    }
    if (this.academicSessionId) {
      queryParts.push(`academicSessionId=${encodeURIComponent(this.academicSessionId)}`);
    }
    const query = queryParts.length ? `?${queryParts.join("&")}` : "";
    window.location.assign(`${sitePrefix}/courseenrollmentdetails${query}`);
  }

  navigateToCourseEnrollment() {
    const targetUrl = `${window.location.origin}/StudentPortalAcademics/`;
    window.location.assign(targetUrl);
  }

  handleCloseReviewModal() {
    this.isReviewModalOpen = false;
  }

  handleBackToSelection() {
    this.isReviewModalOpen = false;
  }

  handleEditPathway(event) {
    const pathwayId = event.currentTarget.dataset.id;
    const idx = this.reviewPathwaySummaries.findIndex((p) => p.id === pathwayId);
    if (idx !== -1) {
      this.currentPathwayIndex = idx;
    }
    this.isReviewModalOpen = false;
  }

  async handleConfirmEnrollment() {
    if (this.isSubmitting) {
      return;
    }

    const requests = this.buildLearnerPathwayItemRequests();
    if (!requests.length) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Validation Error",
          message: "Please select elective courses before submitting enrollment.",
          variant: "error",
        }),
      );
      return;
    }

    this.isSubmitting = true;
    try {
      const submissionResult = await createLearnerPathwayItems({ requests });
      const learnerPathwayItemIds = Array.isArray(submissionResult?.learnerPathwayItemIds) ? submissionResult.learnerPathwayItemIds : [];
      const enrolledCount = this.toNumber(submissionResult?.enrolledCount) || 0;
      const waitlistedCount = this.toNumber(submissionResult?.waitlistedCount) || 0;
      if (!learnerPathwayItemIds.length && waitlistedCount === 0) {
        throw new Error("No enrollment records were created by server.");
      }
      this.isReviewModalOpen = false;
      const message =
        submissionResult?.message ||
        (waitlistedCount > 0 && enrolledCount > 0 ? `${enrolledCount} course item(s) enrolled and ${waitlistedCount} waitlisted.` : waitlistedCount > 0 ? `${waitlistedCount} course item(s) added to waitlist.` : `${learnerPathwayItemIds.length} selected course item(s) enrolled.`);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Enrollment Submitted",
          message,
          variant: "success",
        }),
      );
      this.navigateToCourseEnrollment();
    } catch (error) {
      const message = error?.body?.message || error?.message || "Failed to submit enrollment.";
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Submission Failed",
          message,
          variant: "error",
        }),
      );
    } finally {
      this.isSubmitting = false;
    }
  }

  get reviewPathwaySummaries() {
    const options = this.pathwayOptions.length ? this.pathwayOptions : [{ id: null, label: this.selectedTemplateName || "Selected Pathway" }];
    const includedCourses = this.getIncludedReviewCourses();
    return options.map((pathway, index) => {
      const courses = pathway.id ? includedCourses.filter((course) => course.learningPathwayTemplateId === pathway.id) : includedCourses;

      const mandatoryCourses = [];
      const electiveCourses = [];

      courses.forEach((course, courseIndex) => {
        const typeKey = this.normalizeRuleType(course.courseType);
        const reviewCourse = {
          id: course.learningCourseId || `${index}-${courseIndex}`,
          name: course.courseName || "-",
          subtitle: `${course.courseCode || "-"} • ${course.credits || 0} credits`,
          credits: Number(course.credits) || 0,
        };
        if (typeKey === "requirement") {
          mandatoryCourses.push(reviewCourse);
        } else if (typeKey === "requirementplaceholder") {
          electiveCourses.push(reviewCourse);
        }
      });

      const mandatoryCredits = mandatoryCourses.reduce((sum, item) => sum + item.credits, 0);
      const electiveCredits = electiveCourses.reduce((sum, item) => sum + item.credits, 0);

      return {
        id: pathway.id || `path-${index}`,
        title: pathway.label,
        mandatoryCourses,
        electiveCourses,
        hasMandatoryCourses: mandatoryCourses.length > 0,
        hasElectiveCourses: electiveCourses.length > 0,
        mandatoryCredits,
        electiveCredits,
        totalCredits: mandatoryCredits + electiveCredits,
      };
    });
  }

  get reviewMajorCreditsText() {
    const total = this.reviewPathwaySummaries.reduce((sum, item) => sum + item.mandatoryCredits, 0);
    return `${total}/${total}`;
  }

  get reviewMinorCreditsText() {
    const total = this.reviewPathwaySummaries.reduce((sum, item) => sum + item.electiveCredits, 0);
    return `${total}/${total}`;
  }

  get confirmEnrollmentLabel() {
    return this.isSubmitting ? "Submitting..." : "Submit Enrollment";
  }

  get mandatorySelectedText() {
    return `${this.mandatoryCourses.length} course(s) selected`;
  }

  get mandatoryHeaderText() {
    return `Mandatory: ${this.mandatoryCourses.length} course(s) | Electives: ${this.electiveCourses.length} course(s)`;
  }

  get computedMandatoryCourses() {
    const conflictingCourseIds = this.liveSelectionData.conflictingCourseIds;
    return this.mandatoryCourses.map((course) => {
      const hasScheduleConflict = conflictingCourseIds.has(course.id);
      const isFocused = this.focusedCourseId === course.id;
      const baseCardClass = hasScheduleConflict ? "course-card course-card-selected course-card-conflict" : course.cardClass;
      return {
        ...course,
        cardClass: `${baseCardClass}${isFocused ? " course-card-focused" : ""}`,
        showConflict: hasScheduleConflict,
        conflictText: hasScheduleConflict ? this.getConflictPartnerText(course.id) : "",
        showResolveAction: hasScheduleConflict,
        resolveActionLabel: "Resolve Conflict",
        alternativeSuggestion: this.getAlternativeSuggestion(course),
      };
    });
  }

  get computedElectiveCourses() {
    const conflictingCourseIds = this.liveSelectionData.conflictingCourseIds;
    return this.electiveCourses.map((course) => ({
      ...course,
      hasScheduleConflict: conflictingCourseIds.has(course.id),
      cardClass: this.getElectiveCardClass({
        ...course,
        hasScheduleConflict: conflictingCourseIds.has(course.id),
      }),
      checkClass: this.getElectiveCheckClass(course),
      titleClass: this.getElectiveTitleClass(course),
      subtitleClass: this.getElectiveSubtitleClass(course),
      warningClass: this.getElectiveWarningClass(course),
      warningIconClass: this.getElectiveWarningIconClass(course),
      showDetails: course.selected && course.showDetailsOnSelect,
      showScheduleConflict: conflictingCourseIds.has(course.id),
      scheduleConflictText: conflictingCourseIds.has(course.id) ? this.getConflictPartnerText(course.id) : "",
      showResolveAction: conflictingCourseIds.has(course.id),
      resolveActionLabel: "Resolve Conflict",
      alternativeSuggestion: conflictingCourseIds.has(course.id) ? this.getAlternativeSuggestion(course) : "",
      isFocused: this.focusedCourseId === course.id,
    }));
  }

  get computedElectiveGroups() {
    const groupsByKey = new Map();
    this.computedElectiveCourses.forEach((course) => {
      const groupName = course.groupName && course.groupName.trim() ? course.groupName.trim() : "Elective";
      if (!groupsByKey.has(groupName)) {
        groupsByKey.set(groupName, {
          groupKey: groupName,
          groupName,
          ruleType: course.ruleType || "",
          minCourseCount: course.minCourseCount,
          maxCourseCount: course.maxCourseCount,
          maxCreditLimit: course.maxCreditLimit,
          courses: [],
        });
      }
      const grp = groupsByKey.get(groupName);
      if (!grp.ruleType && course.ruleType) {
        grp.ruleType = course.ruleType;
      }
      if (grp.minCourseCount == null && course.minCourseCount != null) {
        grp.minCourseCount = course.minCourseCount;
      }
      if (grp.maxCourseCount == null && course.maxCourseCount != null) {
        grp.maxCourseCount = course.maxCourseCount;
      }
      if (grp.maxCreditLimit == null && course.maxCreditLimit != null) {
        grp.maxCreditLimit = course.maxCreditLimit;
      }
      grp.courses.push(course);
    });
    return Array.from(groupsByKey.values()).map((group) => {
      const key = this.normalizeRuleType(group.ruleType);
      const pills = [];
      if (key === "minmaxcoursecount") {
        if (group.minCourseCount != null) {
          pills.push({ key: `${group.groupKey}-min`, label: `Min Courses: ${group.minCourseCount}` });
        }
        if (group.maxCourseCount != null) {
          pills.push({ key: `${group.groupKey}-max`, label: `Max Courses: ${group.maxCourseCount}` });
        }
      } else if (key === "maxcreditlimit" || key === "maxcredtilimit") {
        if (group.maxCreditLimit != null) {
          pills.push({ key: `${group.groupKey}-credit`, label: `Max Credits: ${group.maxCreditLimit}` });
        }
      }
      const isOpen = this.electiveGroupOpenState[group.groupKey] !== false;
      const sortedCourses = [...group.courses].sort((a, b) => {
        if (a.hasScheduleConflict !== b.hasScheduleConflict) {
          return a.hasScheduleConflict ? -1 : 1;
        }
        if (a.selected !== b.selected) {
          return a.selected ? -1 : 1;
        }
        return String(a.title || "").localeCompare(String(b.title || ""));
      });
      return {
        ...group,
        courses: sortedCourses,
        isOpen,
        indicatorClass: isOpen ? "collapse-indicator collapse-indicator-open" : "collapse-indicator",
        bodyClass: isOpen ? "accordion-body accordion-body-open" : "accordion-body accordion-body-collapsed",
        pills,
      };
    });
  }

  get liveSelectionData() {
    const sessionsByDay = new Map(LIVE_DAY_ORDER.map((day) => [day.key, []]));
    const selectedElectiveTokens = new Set(this.selectedElectiveTokens || []);
    const conflictingCourseIds = new Set();
    const conflictRows = [];
    const courseTitleById = new Map();
    const selectedCourses = [
      ...this.mandatoryCourses,
      ...this.electiveCourses.filter((course) => {
        const token = course.electiveToken || this.getElectiveToken(course);
        return course.selected || (token && selectedElectiveTokens.has(token));
      }),
    ];

    selectedCourses.forEach((course, courseIndex) => {
      const primaryFaculty = this.getSelectedFacultyOption(course);
      if (course?.id && course?.title) {
        courseTitleById.set(course.id, course.title);
      }
      const scheduleLines = Array.isArray(primaryFaculty?.scheduleLines) ? primaryFaculty.scheduleLines : [];
      const parsedSessions = this.parseLiveSessionsFromLines(scheduleLines);
      const detailBits = [];
      if (course.backendCourse?.courseCode) {
        detailBits.push(course.backendCourse.courseCode);
      }
      if (course.backendCourse?.learningPathwayTemplateName) {
        detailBits.push(course.backendCourse.learningPathwayTemplateName);
      }
      const sessionDetail = detailBits.join(" - ");

      if (!parsedSessions.length) {
        sessionsByDay.get("unscheduled").push({
          id: `${course.id || courseIndex}-unscheduled`,
          title: course.title,
          details: sessionDetail,
          faculty: primaryFaculty?.name || "",
          time: "",
          timeKey: "",
          isConflict: false,
        });
        return;
      }

      parsedSessions.forEach((session, sessionIndex) => {
        if (!sessionsByDay.has(session.dayKey)) {
          sessionsByDay.set(session.dayKey, []);
        }
        sessionsByDay.get(session.dayKey).push({
          id: `${course.id || courseIndex}-${session.dayKey}-${sessionIndex}`,
          sourceCourseId: course.id,
          title: course.title,
          details: sessionDetail,
          faculty: primaryFaculty?.name || "",
          time: session.timeLabel,
          timeKey: session.timeKey,
          sortMinutes: session.sortMinutes,
          isConflict: false,
          relatedCourseIds: [],
        });
      });
    });

    sessionsByDay.forEach((sessions, dayKey) => {
      sessions.sort((a, b) => {
        const aMinutes = Number.isFinite(a.sortMinutes) ? a.sortMinutes : Number.MAX_SAFE_INTEGER;
        const bMinutes = Number.isFinite(b.sortMinutes) ? b.sortMinutes : Number.MAX_SAFE_INTEGER;
        if (aMinutes !== bMinutes) {
          return aMinutes - bMinutes;
        }
        return (a.title || "").localeCompare(b.title || "");
      });
      const countsByTime = {};
      const sessionsByTime = {};
      sessions.forEach((session) => {
        const timeKey = session.timeKey || "";
        if (!timeKey) {
          return;
        }
        countsByTime[timeKey] = (countsByTime[timeKey] || 0) + 1;
        if (!sessionsByTime[timeKey]) {
          sessionsByTime[timeKey] = [];
        }
        sessionsByTime[timeKey].push(session);
      });

      Object.keys(sessionsByTime).forEach((timeKey) => {
        const slotSessions = sessionsByTime[timeKey] || [];
        if (slotSessions.length <= 1) {
          return;
        }
        const uniqueCourseIds = Array.from(new Set(slotSessions.map((s) => s.sourceCourseId).filter((id) => Boolean(id))));
        const courseTitles = uniqueCourseIds.map((id) => courseTitleById.get(id) || "Course");
        const dayLabel = LIVE_DAY_ORDER.find((d) => d.key === dayKey)?.label || "Day";
        const timeLabel = slotSessions.find((s) => s.time)?.time || "Time overlap";
        conflictRows.push({
          id: `${dayKey}-${timeKey}`,
          dayLabel,
          timeLabel,
          courseIds: uniqueCourseIds,
          courseTitles,
          summaryText: `${dayLabel} • ${timeLabel}`,
          overlapText: courseTitles.join(" overlaps "),
          resolveCourseId: uniqueCourseIds[0] || null,
        });
        slotSessions.forEach((session) => {
          session.relatedCourseIds = uniqueCourseIds;
        });
      });

      sessions.forEach((session) => {
        session.isConflict = Boolean(session.timeKey) && countsByTime[session.timeKey] > 1;
        if (session.isConflict && session.sourceCourseId) {
          conflictingCourseIds.add(session.sourceCourseId);
        }
        const isFocused = this.focusedCourseId && session.sourceCourseId === this.focusedCourseId;
        const isRelatedToFocus = this.focusedCourseId && Array.isArray(session.relatedCourseIds) && session.relatedCourseIds.includes(this.focusedCourseId);
        session.cardClass = ["schedule-item", session.isConflict ? "schedule-item-conflict" : "", isFocused ? "schedule-item-focused" : "", !isFocused && isRelatedToFocus ? "schedule-item-related" : ""].filter((value) => Boolean(value)).join(" ");
      });
    });

    const days = LIVE_DAY_ORDER.map((day) => ({
      id: day.key,
      day: day.label,
      sessions: sessionsByDay.get(day.key) || [],
    })).filter((day) => day.sessions.length);

    return {
      days,
      conflictingCourseIds,
      conflictRows,
      courseTitleById,
    };
  }

  get computedLiveSelection() {
    return this.liveSelectionData.days.map((day) => {
      const isOpen = this.liveDayOpenState[day.id] !== false;
      return {
        ...day,
        isOpen,
        indicatorClass: isOpen ? "collapse-indicator collapse-indicator-open" : "collapse-indicator",
        bodyClass: isOpen ? "live-day-body live-day-body-open" : "live-day-body live-day-body-collapsed",
      };
    });
  }

  get liveConflictCount() {
    return this.computedLiveSelection.reduce((count, day) => count + day.sessions.filter((session) => session.isConflict).length, 0);
  }

  get conflictSummaryItems() {
    return this.liveSelectionData.conflictRows || [];
  }

  get hasScheduleConflicts() {
    return this.conflictSummaryItems.length > 0;
  }

  get conflictSummaryTitle() {
    const count = this.conflictSummaryItems.length;
    return count > 0 ? `Fix these ${count} conflict${count === 1 ? "" : "s"}` : "No schedule conflicts";
  }

  get hasLiveSelection() {
    return this.computedLiveSelection.length > 0;
  }

  toggleMandatoryAccordion() {
    this.isMandatoryOpen = !this.isMandatoryOpen;
  }

  handleResolveConflict(event) {
    const courseId = event.currentTarget?.dataset?.courseId;
    if (!courseId) {
      return;
    }
    this.focusedCourseId = courseId;
    this.isMandatoryOpen = true;
    this.isElectivesOpen = true;
    Object.keys(this.electiveGroupOpenState || {}).forEach((groupKey) => {
      this.electiveGroupOpenState[groupKey] = true;
    });
    this.electiveGroupOpenState = { ...this.electiveGroupOpenState };
    this.scrollCourseIntoView(courseId);
  }

  openAccordionsForCourse(courseId) {
    if (!courseId) {
      return;
    }

    const inMandatory = this.mandatoryCourses.some((course) => course.id === courseId);
    if (inMandatory) {
      this.isMandatoryOpen = true;
      return;
    }

    const matchingElective = this.electiveCourses.find((course) => course.id === courseId);
    if (matchingElective) {
      this.isElectivesOpen = true;
      const groupKey = this.getElectiveGroupKey(matchingElective);
      this.electiveGroupOpenState = {
        ...this.electiveGroupOpenState,
        [groupKey]: true,
      };
    }
  }

  openAccordionsForValidationWarnings(courses) {
    const warningCourses = (courses || []).filter((course) => course.showWarning);
    if (!warningCourses.length) {
      return;
    }

    this.isElectivesOpen = true;
    const nextOpenState = { ...this.electiveGroupOpenState };
    warningCourses.forEach((course) => {
      const groupKey = this.getElectiveGroupKey(course);
      nextOpenState[groupKey] = true;
    });
    this.electiveGroupOpenState = nextOpenState;
  }

  handleCourseFocus(event) {
    const courseId = event.currentTarget?.dataset?.courseId;
    if (!courseId) {
      return;
    }
    this.focusedCourseId = courseId;
  }

  scrollCourseIntoView(courseId) {
    if (!courseId || !this.template) {
      return;
    }
    const node = this.template.querySelector(`[data-course-anchor="${courseId}"]`);
    if (node && typeof node.scrollIntoView === "function") {
      node.scrollIntoView({ behavior: "smooth", block: "center" });
    }
  }

  getConflictPartnerText(courseId) {
    const rows = this.conflictSummaryItems.filter((row) => (row.courseIds || []).includes(courseId));
    if (!rows.length) {
      return "This course conflicts with another selected course in your timetable.";
    }
    const row = rows[0];
    const otherCourses = (row.courseTitles || []).filter((title) => title !== (this.liveSelectionData.courseTitleById.get(courseId) || ""));
    if (!otherCourses.length) {
      return `Schedule conflict at ${row.summaryText}.`;
    }
    return `Conflicts with ${otherCourses.join(", ")} at ${row.summaryText}.`;
  }

  getAlternativeSuggestion(course) {
    if (!course || !Array.isArray(course.facultyOptions) || !course.facultyOptions.length) {
      return "";
    }
    const alternative = course.facultyOptions.find((option) => !option.isSelected && Array.isArray(option.scheduleLines) && option.scheduleLines.length > 0);
    if (!alternative) {
      return "Try another faculty/timing from the options below.";
    }
    const firstLine = alternative.scheduleLines[0]?.text || "alternate timing";
    return `Try ${alternative.name} (${firstLine}).`;
  }

  toggleElectivesAccordion() {
    this.isElectivesOpen = !this.isElectivesOpen;
  }

  toggleElectiveGroup(event) {
    const groupKey = event.currentTarget.dataset.group;
    if (!groupKey) {
      return;
    }
    const current = this.electiveGroupOpenState[groupKey] !== false;
    this.electiveGroupOpenState = {
      ...this.electiveGroupOpenState,
      [groupKey]: !current,
    };
  }

  toggleLiveDayAccordion(event) {
    const dayId = event.currentTarget?.dataset?.dayId;
    if (!dayId) {
      return;
    }
    const isCurrentlyOpen = this.liveDayOpenState[dayId] !== false;
    this.liveDayOpenState = {
      ...this.liveDayOpenState,
      [dayId]: !isCurrentlyOpen,
    };
  }

  initializeElectiveGroupState() {
    const nextState = { ...this.electiveGroupOpenState };
    this.electiveCourses.forEach((course) => {
      const groupKey = this.getElectiveGroupKey(course);
      if (!(groupKey in nextState)) {
        nextState[groupKey] = true;
      }
    });
    this.electiveGroupOpenState = nextState;
  }

  normalizeRuleType(ruleType) {
    return (ruleType || "").toLowerCase().replace(/[\s/_-]+/g, "");
  }

  buildFacultyOptions(course, key, modePrefix) {
    const options = Array.isArray(course?.facultyOptions) ? course.facultyOptions : [];
    const normalizedSelectedId = this.selectedFacultyOptionByCourse[key];
    const resolvedSelectedId = normalizedSelectedId || (options[0] ? String(options[0].courseOfferingId || 0) : null);
    return options
      .map((option, index) => {
        const optionId = String(option.courseOfferingId || index);
        const enrollmentCapacity = this.toNumber(option.enrollmentCapacity);
        const enrolleeCount = this.toNumber(option.enrolleeCount);
        const seatsRemaining = enrollmentCapacity != null && enrolleeCount != null ? enrollmentCapacity - enrolleeCount : this.toNumber(option.seatsRemaining);
        const waitlistCapacity = this.toNumber(option.waitlistCapacity);
        const waitlistCount = this.toNumber(option.waitlistCount);
        const waitlistSeatsRemaining = waitlistCapacity != null && waitlistCount != null ? waitlistCapacity - waitlistCount : this.toNumber(option.waitlistSeatsRemaining);
        const isWaitlistActive = option.isWaitlistActive === true;
        const isSelected = optionId === resolvedSelectedId;
        let seatCapacityText = "";
        /*if (enrollmentCapacity != null && enrolleeCount != null) {
          seatCapacityText = `${enrolleeCount}/${enrollmentCapacity} filled`;
          if (seatsRemaining <= 0 && isWaitlistActive && waitlistCapacity != null && waitlistCount != null) {
            seatCapacityText = `${waitlistCount}/${waitlistCapacity} waitlist filled`;
          }
        }*/

        let seatsRemainingText = "";
        if (seatsRemaining != null) {
          if (seatsRemaining > 0) {
            seatsRemainingText = `${seatsRemaining} seat${seatsRemaining === 1 ? "" : "s"} remaining`;
          } else if (isWaitlistActive && waitlistSeatsRemaining != null && waitlistSeatsRemaining > 0) {
            seatsRemainingText = `${waitlistSeatsRemaining} waitlist slot${waitlistSeatsRemaining === 1 ? "" : "s"} remaining`;
          } else if (isWaitlistActive && waitlistSeatsRemaining === 0) {
            seatsRemainingText = "Waitlist full";
          } else {
            seatsRemainingText = "Seats full";
          }
        }
        return {
          isAssigned: Boolean(option.facultyName) && String(option.facultyName).trim().toLowerCase() !== "faculty not assigned",
          id: `${key}-${modePrefix}-${option.courseOfferingId || index}`,
          facultyOptionId: optionId,
          name: Boolean(option.facultyName) && String(option.facultyName).trim().toLowerCase() !== "faculty not assigned" ? option.facultyName : "",
          radioClass: isSelected ? "radio-icon radio-icon-selected" : "radio-icon",
          optionClass: Boolean(option.facultyName) && String(option.facultyName).trim().toLowerCase() !== "faculty not assigned" ? (isSelected ? "faculty-option faculty-option-selected" : "faculty-option") : "faculty-option faculty-option-empty",
          isSelected,
          hasUnavailableSchedule: !Array.isArray(option.scheduleLines) || !option.scheduleLines.length || option.scheduleLines.every((line) => line === "Schedule unavailable"),
          enrollmentCapacity,
          enrolleeCount,
          seatsRemaining,
          waitlistCapacity,
          waitlistCount,
          waitlistSeatsRemaining,
          isWaitlistActive,
          hasSeatInfo: enrollmentCapacity != null && enrolleeCount != null,
          seatsRemainingText,
          seatCapacityText,
          scheduleCardClass: !Array.isArray(option.scheduleLines) || !option.scheduleLines.length || option.scheduleLines.every((line) => line === "Schedule unavailable") ? "time-block time-block-empty" : "time-block",
          scheduleLines: (Array.isArray(option.scheduleLines) && option.scheduleLines.length ? option.scheduleLines : [])
            .filter((line) => line && line !== "Schedule unavailable")
            .map((line, lineIndex) => ({
              id: `${key}-${modePrefix}-${option.courseOfferingId || index}-line-${lineIndex}`,
              text: line,
              lineClass: "schedule-line",
            })),
        };
      })
      .filter((option) => option.isAssigned || option.scheduleLines.length);
  }

  buildCourseFacultyState(course, key, modePrefix) {
    const facultyOptions = this.buildFacultyOptions(course, key, modePrefix);
    const hasAnyPublishedSchedule = facultyOptions.some((option) => !option.hasUnavailableSchedule);
    const selectedFaculty = facultyOptions.find((option) => option.isSelected) || facultyOptions[0] || null;
    return {
      facultyOptions,
      hasFacultyOptions: facultyOptions.length > 0,
      facultyGridClass: facultyOptions.length > 1 ? "faculty-grid faculty-grid-split" : "faculty-grid faculty-grid-single",
      facultySummaryClass: hasAnyPublishedSchedule ? "faculty-summary" : "faculty-summary faculty-summary-muted",
      hasFacultySummary: hasAnyPublishedSchedule,
      facultySummaryText: hasAnyPublishedSchedule ? "Faculty and class timings available below." : "",
      selectedFacultyOptionId: selectedFaculty ? selectedFaculty.facultyOptionId : null,
    };
  }

  getSelectedFacultyOption(course) {
    if (!course || !Array.isArray(course.facultyOptions) || !course.facultyOptions.length) {
      return null;
    }
    return course.facultyOptions.find((option) => option.isSelected) || course.facultyOptions[0];
  }

  toNumber(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }

  getElectiveGroupKey(course) {
    return course.groupName && course.groupName.trim() ? course.groupName.trim() : "Elective";
  }

  getElectiveTokenFromBackend(backendCourse) {
    if (!backendCourse) {
      return null;
    }
    if (backendCourse.learningPathwayTemplateItemId) {
      return String(backendCourse.learningPathwayTemplateItemId);
    }
    if (backendCourse.learningPathwayTemplateId && backendCourse.learningCourseId) {
      return `${backendCourse.learningPathwayTemplateId}::${backendCourse.learningCourseId}`;
    }
    return null;
  }

  normalizeLiveDayToken(token) {
    return LIVE_DAY_ALIASES[(token || "").trim().toLowerCase()] || null;
  }

  parseLiveSessionsFromLines(lines) {
    const sessions = [];
    (lines || []).forEach((line) => {
      const rawValue = typeof line === "string" ? line : line?.text;
      const rawLine = String(rawValue || "").trim();
      if (!rawLine) {
        return;
      }

      const separatorIndex = rawLine.indexOf(":");
      if (separatorIndex === -1) {
        sessions.push({
          dayKey: "unscheduled",
          timeLabel: rawLine,
          timeKey: rawLine.toLowerCase(),
        });
        return;
      }

      const dayPart = rawLine.slice(0, separatorIndex).trim();
      const timePart = rawLine.slice(separatorIndex + 1).trim();
      const sortMinutes = this.parseStartMinutes(timePart);
      const dayTokens = dayPart
        .split(",")
        .map((token) => this.normalizeLiveDayToken(token))
        .filter((token) => Boolean(token));

      if (!dayTokens.length) {
        sessions.push({
          dayKey: "unscheduled",
          timeLabel: timePart || rawLine,
          timeKey: (timePart || rawLine).toLowerCase(),
          sortMinutes,
        });
        return;
      }

      dayTokens.forEach((dayKey) => {
        sessions.push({
          dayKey,
          timeLabel: timePart,
          timeKey: timePart.toLowerCase(),
          sortMinutes,
        });
      });
    });
    return sessions;
  }

  parseStartMinutes(timeLabel) {
    const match = String(timeLabel || "")
      .trim()
      .match(/^(\d{1,2}):(\d{2})\s*(AM|PM)/i);
    if (!match) {
      return null;
    }
    let hours = Number(match[1]);
    const minutes = Number(match[2]);
    const meridiem = match[3].toUpperCase();
    if (meridiem === "PM" && hours !== 12) {
      hours += 12;
    }
    if (meridiem === "AM" && hours === 12) {
      hours = 0;
    }
    return hours * 60 + minutes;
  }

  syncGlobalSelectedElectives(nextCourses) {
    const nextTokenSet = new Set(this.selectedElectiveTokens || []);
    const visibleTokens = (nextCourses || []).map((course) => course.electiveToken || this.getElectiveTokenFromBackend(course.backendCourse)).filter((token) => Boolean(token));
    visibleTokens.forEach((token) => nextTokenSet.delete(token));
    (nextCourses || [])
      .filter((course) => course.selected)
      .forEach((course) => {
        const token = course.electiveToken || this.getElectiveTokenFromBackend(course.backendCourse);
        if (token) {
          nextTokenSet.add(token);
        }
      });
    this.selectedElectiveTokens = Array.from(nextTokenSet);
  }

  getLearnerPathwayIdForTemplate(templateId) {
    if (!templateId) {
      return this.currentPathway?.learnerPathwayId || null;
    }
    const pathway = (this.pathwayOptions || []).find((item) => item.id === templateId);
    if (pathway && pathway.learnerPathwayId) {
      return pathway.learnerPathwayId;
    }
    return this.currentPathway?.learnerPathwayId || null;
  }

  getCourseKey(course, index = 0) {
    if (!course) {
      return `course-${index}`;
    }
    return String(course.courseOfferingId || course.learningCourseId || `course-${index}`);
  }

  buildLearnerPathwayItemRequests() {
    const selectedCourses = this.getIncludedReviewCourses().map((course, index) => ({
      backendCourse: course,
      courseKey: this.getCourseKey(course, index),
    }));
    const dedupe = new Set();

    return selectedCourses
      .map((course) => {
        const backend = course.backendCourse || {};
        const learningPathwayTemplateId = backend.learningPathwayTemplateId || this.currentPathway?.id || this.selectedTemplateId || null;
        const learningCourseId = backend.learningCourseId || null;
        const academicSessionId = backend.academicSessionId || this.academicSessionId || null;

        return {
          learnerPathwayId: this.getLearnerPathwayIdForTemplate(learningPathwayTemplateId),
          learningPathwayTemplateId,
          learningPathwayTemplateItemId: backend.learningPathwayTemplateItemId || null,
          learningCourseId,
          academicSessionId,
          courseOfferingId: this.selectedFacultyOptionByCourse[course.courseKey] || backend.courseOfferingId || null,
        };
      })
      .filter((request) => {
        if (!request.learningPathwayTemplateItemId && (!request.learningPathwayTemplateId || !request.learningCourseId)) {
          return false;
        }
        const key = request.learningPathwayTemplateItemId ? String(request.learningPathwayTemplateItemId) : `${request.learningPathwayTemplateId}::${request.learningCourseId}`;
        if (dedupe.has(key)) {
          return false;
        }
        dedupe.add(key);
        return true;
      });
  }

  getIncludedReviewCourses() {
    const selectedElectiveTokens = new Set(this.selectedElectiveTokens || []);
    return (this.allFetchedCourses || []).filter((course, index) => {
      const typeKey = this.normalizeRuleType(course?.courseType);
      if (typeKey === "requirement") {
        return true;
      }
      if (typeKey !== "requirementplaceholder") {
        return false;
      }
      const courseKey = this.getElectiveTokenFromBackend(course) || String(course.courseOfferingId || course.learningCourseId || `course-${index}`);
      return selectedElectiveTokens.has(courseKey);
    });
  }

  getCourseCredits(course) {
    return this.toNumber(course?.backendCourse?.credits) || 0;
  }

  getElectiveToken(course) {
    return course?.electiveToken || this.getElectiveTokenFromBackend(course?.backendCourse);
  }

  buildElectiveGroupStats(courses) {
    const statsByGroup = new Map();
    (courses || []).forEach((course) => {
      const groupKey = this.getElectiveGroupKey(course);
      if (!statsByGroup.has(groupKey)) {
        statsByGroup.set(groupKey, {
          selectedCount: 0,
          selectedCredits: 0,
          minCourseCount: this.toNumber(course.minCourseCount),
          maxCourseCount: this.toNumber(course.maxCourseCount),
          maxCreditLimit: this.toNumber(course.maxCreditLimit),
        });
      }
      const stats = statsByGroup.get(groupKey);
      if (stats.minCourseCount == null && course.minCourseCount != null) {
        stats.minCourseCount = this.toNumber(course.minCourseCount);
      }
      if (stats.maxCourseCount == null && course.maxCourseCount != null) {
        stats.maxCourseCount = this.toNumber(course.maxCourseCount);
      }
      if (stats.maxCreditLimit == null && course.maxCreditLimit != null) {
        stats.maxCreditLimit = this.toNumber(course.maxCreditLimit);
      }
      if (course.selected) {
        stats.selectedCount += 1;
        stats.selectedCredits += this.getCourseCredits(course);
      }
    });
    return statsByGroup;
  }

  getGroupViolationMessage(stats, enforceMinimum, includeCapWarnings) {
    if (includeCapWarnings && stats.maxCourseCount != null && stats.selectedCount > stats.maxCourseCount) {
      return `You can select maximum ${stats.maxCourseCount} course(s) in this elective group.`;
    }
    if (includeCapWarnings && stats.maxCreditLimit != null && stats.selectedCredits > stats.maxCreditLimit) {
      return `Selected credits exceed the maximum limit of ${stats.maxCreditLimit} for this elective group.`;
    }
    if (enforceMinimum && stats.minCourseCount != null && stats.selectedCount < stats.minCourseCount) {
      return `Please select at least ${stats.minCourseCount} course(s) in this elective group.`;
    }
    return "";
  }

  getCourseFreezeWarning(stats, courseCredits) {
    if (stats.maxCourseCount != null && stats.selectedCount >= stats.maxCourseCount) {
      return `You can select only ${stats.maxCourseCount} course(s) in this elective group.`;
    }
    if (stats.maxCreditLimit != null && stats.selectedCredits + courseCredits > stats.maxCreditLimit) {
      const exceededBy = Math.max(0, stats.selectedCredits + courseCredits - stats.maxCreditLimit);
      return `Selecting this course would exceed credit limit by ${exceededBy} credits.`;
    }
    return "";
  }

  applyElectiveGroupWarnings(courses, { enforceMinimum = false, includeCapWarnings = false } = {}) {
    const statsByGroup = this.buildElectiveGroupStats(courses);
    const warningsByGroup = {};

    statsByGroup.forEach((stats, groupKey) => {
      const message = this.getGroupViolationMessage(stats, enforceMinimum, includeCapWarnings);
      if (message) {
        warningsByGroup[groupKey] = message;
      }
    });

    const firstIndexByGroup = {};
    (courses || []).forEach((course, index) => {
      const groupKey = this.getElectiveGroupKey(course);
      if (firstIndexByGroup[groupKey] == null) {
        firstIndexByGroup[groupKey] = index;
      }
    });

    return (courses || []).map((course, index) => {
      const groupKey = this.getElectiveGroupKey(course);
      const stats = statsByGroup.get(groupKey);
      const courseCredits = this.getCourseCredits(course);
      const freezeWarning = !course.selected ? this.getCourseFreezeWarning(stats, courseCredits) : "";
      const groupWarning = warningsByGroup[groupKey] || "";
      const courseToken = this.getElectiveToken(course);
      const shouldShowFreezeWarning = Boolean(freezeWarning && courseToken && this.blockedSelectionWarnings && this.blockedSelectionWarnings[courseToken]);
      const warningText = shouldShowFreezeWarning ? freezeWarning : groupWarning;
      if (!warningText) {
        return {
          ...course,
          selectable: course.selected ? true : !freezeWarning,
          showWarning: false,
          warningText: "",
          warningKind: "",
        };
      }

      const isFirstCourse = firstIndexByGroup[groupKey] === index;
      const isMinWarning = warningText === groupWarning && groupWarning.startsWith("Please select at least");
      const shouldWarn = shouldShowFreezeWarning ? true : isMinWarning ? course.selected || ((stats?.selectedCount || 0) === 0 && isFirstCourse) : course.selected;
      return {
        ...course,
        selectable: course.selected ? true : !freezeWarning,
        showWarning: shouldWarn,
        warningText: shouldWarn ? warningText : "",
        warningKind: shouldWarn ? (shouldShowFreezeWarning ? "blocked" : "group") : "",
      };
    });
  }

  validateElectiveSelections() {
    const nextCourses = this.applyElectiveGroupWarnings(this.electiveCourses, {
      enforceMinimum: true,
      includeCapWarnings: true,
    });
    this.electiveCourses = nextCourses;
    this.openAccordionsForValidationWarnings(nextCourses);
    const statsByGroup = this.buildElectiveGroupStats(nextCourses);
    const hasBlockingViolation = Array.from(statsByGroup.values()).some((stats) => Boolean(this.getGroupViolationMessage(stats, true, true)));
    return !hasBlockingViolation;
  }

  handleElectiveToggle(event) {
    const courseId = event.currentTarget.dataset.courseId;
    this.focusedCourseId = courseId || this.focusedCourseId;
    const targetCourse = this.electiveCourses.find((course) => course.id === courseId);
    if (!targetCourse) {
      return;
    }
    if (!targetCourse.selectable) {
      const statsByGroup = this.buildElectiveGroupStats(this.electiveCourses);
      const groupKey = this.getElectiveGroupKey(targetCourse);
      const stats = statsByGroup.get(groupKey);
      const freezeWarning = this.getCourseFreezeWarning(stats, this.getCourseCredits(targetCourse));
      const courseToken = this.getElectiveToken(targetCourse);
      if (freezeWarning && courseToken) {
        this.blockedSelectionWarnings = {
          ...(this.blockedSelectionWarnings || {}),
          [courseToken]: freezeWarning,
        };
        this.electiveCourses = this.applyElectiveGroupWarnings(this.electiveCourses, { enforceMinimum: false });
      }
      return;
    }

    this.blockedSelectionWarnings = {};
    const nextCourses = this.electiveCourses.map((course) => {
      if (course.id !== courseId) {
        return course;
      }
      return {
        ...course,
        selected: !course.selected,
      };
    });
    this.electiveCourses = this.applyElectiveGroupWarnings(nextCourses, { enforceMinimum: false });
    this.syncGlobalSelectedElectives(this.electiveCourses);
  }

  handleFacultySelection(event) {
    const courseId = event.currentTarget.dataset.courseId;
    const facultyOptionId = event.currentTarget.dataset.facultyId;
    if (!courseId || !facultyOptionId) {
      return;
    }
    this.focusedCourseId = courseId;
    this.selectedFacultyOptionByCourse = {
      ...(this.selectedFacultyOptionByCourse || {}),
      [courseId]: facultyOptionId,
    };
    this.mandatoryCourses = this.mandatoryCourses.map((course) => (course.id === courseId ? { ...course, ...this.buildCourseFacultyState(course.backendCourse, course.id, "m") } : course));
    this.electiveCourses = this.electiveCourses.map((course) => (course.id === courseId ? { ...course, ...this.buildCourseFacultyState(course.backendCourse, course.id, "e") } : course));
  }

  getElectiveCardClass(course) {
    const classes = ["course-card", "elective-card"];

    if (course.hasScheduleConflict || course.warningKind === "blocked") {
      classes.push("course-card-conflict");
    } else if (course.selected) {
      classes.push("course-card-selected");
    }

    if (!course.selectable) {
      classes.push("course-card-disabled");
    }

    return classes.join(" ");
  }

  getElectiveWarningClass(course) {
    if (course.warningKind === "blocked") {
      return "conflict-alert";
    }
    return "credit-warning";
  }

  getElectiveWarningIconClass(course) {
    if (course.warningKind === "blocked") {
      return "conflict-alert-icon";
    }
    return "warning-icon";
  }

  getElectiveCheckClass(course) {
    const classes = ["check-icon"];

    if (!course.selected) {
      classes.push("check-icon-empty");
    }

    if (!course.selectable) {
      classes.push("check-icon-disabled");
    }

    if (course.hasScheduleConflict || course.warningKind === "blocked") {
      classes.push("check-icon-conflict");
    }

    return classes.join(" ");
  }

  getElectiveTitleClass(course) {
    if (course.warningKind === "blocked") {
      return "course-title";
    }
    return course.selectable ? "course-title" : "course-title course-title-muted";
  }

  getElectiveSubtitleClass(course) {
    if (course.warningKind === "blocked") {
      return "course-subtitle";
    }
    return course.selectable ? "course-subtitle" : "course-subtitle course-subtitle-muted";
  }
}