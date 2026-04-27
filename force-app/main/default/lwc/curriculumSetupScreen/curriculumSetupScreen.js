import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getLearningProgram from "@salesforce/apex/KenCurriculumScreenController.getLearningProgram";
import getLearningProgramPlan from "@salesforce/apex/KenCurriculumScreenController.getLearningProgramPlan";
import getAllAcademicTerms from "@salesforce/apex/KenCurriculumScreenController.getAllAcademicTerms";
import getPathwaysByProgramPlan from "@salesforce/apex/KenCurriculumScreenController.getPathwaysByProgramPlan";
import getAllLearningCourses from "@salesforce/apex/KenCurriculumScreenController.getAllLearningCourses";
import addCoursesToCurriculum from "@salesforce/apex/KenCurriculumScreenController.addCoursesToCurriculum";
import getTemplatePlanDetails from "@salesforce/apex/KenCurriculumScreenController.getTemplatePlanDetails";
import getAddedCoursesByPathway from "@salesforce/apex/KenCurriculumScreenController.getAddedCoursesByPathway";
import getEnrollmentTypes from "@salesforce/apex/KenCurriculumScreenController.getEnrollmentTypes";
import createEnrollmentType from "@salesforce/apex/KenCurriculumScreenController.createEnrollmentType";
import getAcademicCycles from "@salesforce/apex/KenCurriculumScreenController.getAcademicCycles";
import createAcademicCycle from "@salesforce/apex/KenCurriculumScreenController.createAcademicCycle";
import getThemeColors from "@salesforce/apex/UiThemeController.getThemeColors";

export default class CurriculumSetupScreen extends LightningElement {
  isThemeLoading = true;
  enrollmentTypeLoadPromise;
  COURSE_RENDER_LIMIT = 100;

  CADENCE_CONFIG = {
    Semester: { periodsPerYear: 2, label: "Semester" },
    Trimester: { periodsPerYear: 3, label: "Trimester" },
    Quarter: { periodsPerYear: 4, label: "Quarter" },
    Yearly: { periodsPerYear: 1, label: "Yearly" },
  };

  selectedProgram = "";
  selectedProgramPlan = "";
  selectedPathwayType = "";
  selectedPathwayTemplate = "";
  selectedAcademicTerm = "";
  pathwayTemplates = [];
  academicSessions = [];
  enrollmentTypeConfigs = [];

  @track allCourses = [];
  @track filteredCourses = [];
  @track programOptions = [];
  @track programPlanOptions = [];
  @track pathwayTypeOptions = [];
  @track pathwayTemplateOptions = [];
  @track academicTermOptions = [];
  @track showCourseModal = false;
  @track showRuleModal = false;
  @track showCategoryModal = false;
  @track showEnrollmentTypeModal = false;
  @track showCycleModal = false;
  @track academicCycles = [];
  @track newCycleName = "";
  @track newCycleDescription = "";
  @track groupNameInput = "";
  @track newEnrollmentTypeName = "";
  @track newEnrollmentTypeCourseManagementMode = "Both";
  @track newEnrollmentTypeRequirementNature = "Mandatory";
  @track ruleType = "";
  @track minCourses;
  @track maxCourses;
  @track maxCredits;
  @track currentCreditSum = 0;

  programDuration;
  programDurationUnit;
  activeSemesterId;
  activeEnrollmentTypeKey;
  activeGroupId;
  activeCycleName = "";
  startSemester;
  endSemester;
  cadenceType;
  searchKey = "";
  programSearchKey = "";
  programDropdownOpen = false;
  selectedCourseIds = new Set();
  electiveGroupRuleMap = {};

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  connectedCallback() {
    this.loadPrograms();
    this.loadAllAcademicTerms();
    this.loadThemeColors();
    this.enrollmentTypeLoadPromise = this.loadEnrollmentTypes();
  }

  // ─── Theme ────────────────────────────────────────────────────────────────

  async loadThemeColors() {
    this.isThemeLoading = true;
    try {
      await this.applyThemeColor();
    } catch {
      // ignore theme load errors
    } finally {
      this.isThemeLoading = false;
    }
  }

  async applyThemeColor() {
    const colors = await getThemeColors();
    if (colors?.primary) this.template.host.style.setProperty("--theme-primary", colors.primary);
    if (colors?.secondary) this.template.host.style.setProperty("--theme-secondary", colors.secondary);
  }

  // ─── Data Loading ─────────────────────────────────────────────────────────

  async loadPrograms() {
    try {
      const result = await getLearningProgram();
      this.programOptions = result.map((p) => ({
        label: p.Name,
        value: p.Id,
        duration: p.Duration,
        durationUnit: p.DurationUnit,
      }));
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    }
  }

  async loadProgramPlans() {
    try {
      const result = await getLearningProgramPlan({ learningProgramId: this.selectedProgram });
      this.programPlanOptions = result.map((p) => ({ label: p.Name, value: p.Id }));
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    }
  }

  async loadAllAcademicTerms() {
    try {
      const result = await getAllAcademicTerms();
      this.academicTermOptions = result.map((p) => ({ label: p.Name, value: p.Id }));
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    }
  }

  async loadEnrollmentTypes() {
    try {
      const result = await getEnrollmentTypes();
      this.enrollmentTypeConfigs = (result || []).map((item, index) => this.decorateEnrollmentTypeConfig(item, index));
      this.syncSessionsWithEnrollmentTypes();
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    }
  }

  decorateEnrollmentTypeConfig(item, index) {
    const courseManagementMode = item.courseManagementMode || (item.requiresGroup ? "Grouped" : "Direct");
    const allowsDirectCourses = courseManagementMode === "Direct" || courseManagementMode === "Both";
    const allowsGroupedCourses = courseManagementMode === "Grouped" || courseManagementMode === "Both";
    return {
      key: item.key,
      label: item.label,
      requiresGroup: !!item.requiresGroup,
      allowsDirectCourses,
      allowsGroupedCourses,
      courseManagementMode,
      requirementNature: item.requirementNature || "Mandatory",
      pathwayItemType: item.pathwayItemType,
      sortOrder: item.sortOrder,
      toneClass: `tone-${(index % 5) + 1}`,
    };
  }

  async loadPathwaysForPlan() {
    try {
      const result = await getPathwaysByProgramPlan({ learningProgramPlanId: this.selectedProgramPlan });
      this.pathwayTemplates = result;
      this.pathwayTypeOptions = [...new Set(result.map((t) => t.Pathway_Type__c).filter(Boolean))].map((t) => ({ label: t, value: t }));
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    }
  }

  async loadAllCourses() {
    try {
      const result = await getAllLearningCourses();
      this.allCourses = (result || []).map((course) => ({
        ...course,
        _searchText: `${String(course.CourseNumber || "").toLowerCase()} ${String(course.Name || "").toLowerCase()}`,
      }));
      this.updateFilteredCourses();
    } catch (error) {
      this.showToast("Error", error.body?.message || error.message, "error");
    }
  }

  // ─── Added Courses ────────────────────────────────────────────────────────
  //
  //  FIX: The original buildSessionEnrollmentTypes() accepted (existingMap, existingTypes[])
  //  and always resolved via:
  //
  //    existingTypes.find(t => t.key === config.key)  ← found the stale empty session type
  //    || existingMap[config.key]                     ← DB data never reached
  //
  //  We now use a dedicated buildSessionEnrollmentTypesFromDb() that inverts the priority:
  //  DB data wins, session state is only kept for locally-created groups not yet in the DB.

  async loadAddedCourses() {
    try {
      const records = await getAddedCoursesByPathway({
        learningProgramPlanId: this.selectedProgramPlan,
        learningPathwayTemplateId: this.selectedPathwayTemplate,
      });

      // semesterMap[semNum][typeKey] = { addedCourses: [], groups: { groupName: course[] } }
      const semesterMap = {};
      const groupRuleMap = {};

      (records || []).forEach((row) => {
        if (row?.semesterNumber == null) return;

        const semKey = Number(row.semesterNumber);
        const typeKey = this.resolveEnrollmentTypeKey(row.categoryKey || row.category);
        const config = this.getEnrollmentTypeConfig(typeKey);
        const effectiveTypeKey = config?.key || typeKey;

        if (!semesterMap[semKey]) semesterMap[semKey] = {};
        if (!semesterMap[semKey][effectiveTypeKey]) {
          semesterMap[semKey][effectiveTypeKey] = {
            key: effectiveTypeKey,
            label: row.category || config?.label || effectiveTypeKey,
            requiresGroup: row.requiresGroup ?? config?.requiresGroup ?? false,
            allowsDirectCourses: config?.allowsDirectCourses ?? !row.requiresGroup,
            allowsGroupedCourses: config?.allowsGroupedCourses ?? !!row.requiresGroup,
            courseManagementMode: config?.courseManagementMode || this.deriveCourseManagementMode(row),
            requirementNature: config?.requirementNature || "Mandatory",
            pathwayItemType: row.pathwayItemType || config?.pathwayItemType,
            toneClass: config?.toneClass || "tone-1",
            addedCourses: [],
            groups: {},
          };
        }

        const slot = semesterMap[semKey][effectiveTypeKey];

        if (this.isGroupedCourseRow(row, config)) {
          const groupName = row.groupName || config?.label || "Group";

          if (!slot.groups[groupName]) slot.groups[groupName] = [];

          // Persist rule info per group (only set once – first record wins)
          const ruleKey = this.getGroupRuleKey(semKey, effectiveTypeKey, groupName);
          if (!groupRuleMap[ruleKey] && (row.ruleType || row.minCourseCount != null || row.maxCourseCount != null || row.maxCreditLimit != null)) {
            groupRuleMap[ruleKey] = {
              ruleType: this.mapStoredRuleTypeToUi(row.ruleType),
              minCourses: row.minCourseCount,
              maxCourses: row.maxCourseCount,
              maxCredits: row.maxCreditLimit,
            };
          }

          slot.groups[groupName].push({
            id: row.courseId,
            code: row.courseCode,
            name: row.courseName,
            creditLabel: this.formatCourseCreditLabel(row.courseCredits),
            typeLabel: config?.label || row.category,
            badgeClass: this.getTypeBadgeClass(effectiveTypeKey),
            cycleName: row.cycleName || null,
          });
        } else {
          slot.addedCourses.push({
            id: row.courseId,
            code: row.courseCode,
            name: row.courseName,
            creditLabel: this.formatCourseCreditLabel(row.courseCredits),
            typeLabel: config?.label || row.category,
            badgeClass: this.getTypeBadgeClass(effectiveTypeKey),
            cycleName: row.cycleName || null,
          });
        }
      });

      this.electiveGroupRuleMap = groupRuleMap;

      // Re-map sessions using DB data as the authoritative source.
      // Existing session types are passed only to preserve locally-created
      // groups that haven't been saved yet.
      this.academicSessions = this.academicSessions.map((session) => {
        const dbTypeData = semesterMap[Number(session.Id)] || {};
        const nextTypes = this.buildSessionEnrollmentTypesFromDb(dbTypeData, session.enrollmentTypes);
        return this.decorateSession({ ...session, enrollmentTypes: nextTypes });
      });
    } catch (error) {
      this.showToast("Error", error?.body?.message || "Unable to load added courses", "error");
    }
  }

  /**
   * Builds the enrollmentTypes array for a single session.
   *
   * @param {Object} dbTypeMap     – { [typeKey]: { addedCourses[], groups: { [name]: course[] } } }
   *                                 Fresh data from Apex – AUTHORITATIVE.
   * @param {Array}  sessionTypes  – existing types on the session (may be stale / empty).
   *                                 Used only to carry forward locally-created groups not yet in DB.
   */
  buildSessionEnrollmentTypesFromDb(dbTypeMap, sessionTypes) {
    const mappedTypes = this.enrollmentTypeConfigs.map((config) => {
      const fromDb = this.getDbTypeDataForConfig(config, dbTypeMap); // DB record (may be undefined)
      const fromSession = (sessionTypes || []).find((t) => t.key === config.key); // stale UI state

      let addedCourses;
      let groups;

      if (fromDb) {
        // ── DB data is present: it is the source of truth ──────────────────
        addedCourses = fromDb.addedCourses || [];

        // fromDb.groups is a plain object { groupName: course[] }
        const rawGroups = fromDb.groups || {};
        const dbGroupNames = new Set(Object.keys(rawGroups));

        groups = Object.keys(rawGroups).map((groupName) => ({
          groupId: groupName,
          name: groupName,
          courses: rawGroups[groupName] || [],
          toneClass: config.toneClass,
        }));

        // Merge locally-created groups that don't exist in DB yet
        if (fromSession) {
          (fromSession.groups || []).forEach((sg) => {
            if (!dbGroupNames.has(sg.groupId)) {
              groups.push({ ...sg, toneClass: config.toneClass });
            }
          });
        }
      } else if (fromSession) {
        // ── No DB data: fall back to whatever is on the session ─────────────
        addedCourses = fromSession.addedCourses || [];

        const groupsSource = fromSession.groups || [];
        groups = Array.isArray(groupsSource)
          ? groupsSource.map((g) => ({ ...g, toneClass: config.toneClass }))
          : Object.keys(groupsSource).map((name) => ({
              groupId: name,
              name,
              courses: groupsSource[name] || [],
              toneClass: config.toneClass,
            }));
      } else {
        // ── Nothing anywhere: start fresh ───────────────────────────────────
        addedCourses = [];
        groups = [];
      }

      return {
        key: config.key,
        label: config.label,
        requiresGroup: config.requiresGroup,
        allowsDirectCourses: config.allowsDirectCourses,
        allowsGroupedCourses: config.allowsGroupedCourses,
        courseManagementMode: config.courseManagementMode,
        requirementNature: config.requirementNature,
        pathwayItemType: config.pathwayItemType,
        toneClass: config.toneClass,
        addedCourses,
        groups,
      };
    });

    const knownTypeKeys = new Set(mappedTypes.map((type) => String(type.key || "").toLowerCase()));
    const knownTypeLabels = new Set(mappedTypes.map((type) => String(type.label || "").toLowerCase()));
    const fallbackTypes = Object.keys(dbTypeMap || {})
      .filter((typeKey) => {
        const fromDb = dbTypeMap[typeKey] || {};
        const normalizedTypeKey = String(typeKey || "").toLowerCase();
        const normalizedLabel = String(fromDb.label || "").toLowerCase();
        return !knownTypeKeys.has(normalizedTypeKey) && !knownTypeLabels.has(normalizedLabel);
      })
      .map((typeKey) => {
        const fromDb = dbTypeMap[typeKey] || {};
        const rawGroups = fromDb.groups || {};

        return {
          key: fromDb.key || typeKey,
          label: fromDb.label || typeKey,
          requiresGroup: !!fromDb.requiresGroup,
          allowsDirectCourses: fromDb.allowsDirectCourses !== false,
          allowsGroupedCourses: !!fromDb.allowsGroupedCourses,
          courseManagementMode: fromDb.courseManagementMode || "Direct",
          requirementNature: fromDb.requirementNature || "Mandatory",
          pathwayItemType: fromDb.pathwayItemType,
          toneClass: fromDb.toneClass || "tone-1",
          addedCourses: fromDb.addedCourses || [],
          groups: Object.keys(rawGroups).map((groupName) => ({
            groupId: groupName,
            name: groupName,
            courses: rawGroups[groupName] || [],
            toneClass: fromDb.toneClass || "tone-1",
          })),
        };
      });

    return [...mappedTypes, ...fallbackTypes];
  }

  // ─── Event Handlers ───────────────────────────────────────────────────────

  handleProgramChange(event) {
    this.selectProgram(event.detail.value);
  }

  selectProgram(programId) {
    this.selectedProgram = programId;
    const selected = this.programOptions.find((p) => p.value === this.selectedProgram);
    if (selected) {
      this.programDuration = selected.duration;
      this.programDurationUnit = selected.durationUnit;
      this.programSearchKey = selected.label || "";
    }
    this.programDropdownOpen = false;
    this.selectedProgramPlan = "";
    this.programPlanOptions = [];
    this.selectedPathwayType = "";
    this.selectedPathwayTemplate = "";
    this.pathwayTypeOptions = [];
    this.pathwayTemplateOptions = [];
    this.pathwayTemplates = [];
    if (this.selectedProgram) this.loadProgramPlans();
  }

  handleProgramSearchChange(event) {
    this.programSearchKey = event.target.value || "";
    this.programDropdownOpen = true;

    if (!this.programSearchKey) {
      this.clearSelectedProgramState();
      return;
    }

    if (this.selectedProgram) {
      const selected = this.programOptions.find((p) => p.value === this.selectedProgram);
      if (selected && this.programSearchKey !== selected.label) {
        this.clearSelectedProgramState();
      }
    }
  }

  handleProgramInputFocus() {
    this.programDropdownOpen = true;
  }

  handleProgramInputBlur() {
    window.clearTimeout(this.programBlurTimeout);
    this.programBlurTimeout = window.setTimeout(() => {
      this.programDropdownOpen = false;
      if (!this.selectedProgram) {
        this.programSearchKey = "";
      }
    }, 200);
  }

  handleProgramOptionSelect(event) {
    const programId = event.currentTarget.dataset.value;
    if (!programId) {
      return;
    }
    window.clearTimeout(this.programBlurTimeout);
    this.selectProgram(programId);
  }

  clearSelectedProgramState() {
    this.selectedProgram = "";
    this.programDuration = null;
    this.programDurationUnit = null;
    this.selectedProgramPlan = "";
    this.programPlanOptions = [];
    this.selectedPathwayType = "";
    this.selectedPathwayTemplate = "";
    this.pathwayTypeOptions = [];
    this.pathwayTemplateOptions = [];
    this.pathwayTemplates = [];
    this.academicCycles = [];
  }

  handleProgramPlanChange(event) {
    this.selectedProgramPlan = event.detail.value;
    this.selectedPathwayType = "";
    this.selectedPathwayTemplate = "";
    this.pathwayTypeOptions = [];
    this.pathwayTemplateOptions = [];
    this.pathwayTemplates = [];
    this.academicCycles = [];
    if (this.selectedProgramPlan) {
      this.loadPathwaysForPlan();
      this.loadAcademicCycles();
    }
  }

  handlePathwayTypeChange(event) {
    this.selectedPathwayType = event.detail.value;
    this.pathwayTemplateOptions = this.pathwayTemplates.filter((t) => t.Pathway_Type__c === this.selectedPathwayType).map((t) => ({ label: t.Name, value: t.Id }));
    this.selectedPathwayTemplate = "";
  }

  async handlePathwayTemplateChange(event) {
    this.selectedPathwayTemplate = event.detail.value;
    await this.loadEnrollmentTypes();

    const templateDetails = await getTemplatePlanDetails({
      learningProgramPlanId: this.selectedProgramPlan,
      learningPathwayTemplateId: this.selectedPathwayTemplate,
    });

    this.cadenceType = templateDetails.Cadence_Type__c;
    this.startSemester = this.extractPeriodNumber(templateDetails.Start_Period__c);
    this.endSemester = this.extractPeriodNumber(templateDetails.End_Period__c);

    this.generatePeriods();
    await this.loadAddedCourses();
  }

  handleToggleSemester(event) {
    const semesterId = Number(event.currentTarget.dataset.id);
    const semester = this.getSessionById(semesterId);
    if (!semester?.isEditable) return;

    this.academicSessions = this.academicSessions.map((session) => {
      const expanded = session.Id === semesterId ? !session.isExpanded : false;
      return { ...session, isExpanded: expanded, iconName: expanded ? "utility:chevrondown" : "utility:chevronright" };
    });
  }

  handleEnrollmentTypeClick(event) {
    const semesterId = Number(event.currentTarget.dataset.semesterId);
    const typeKey = event.currentTarget.dataset.typeKey;
    this.academicSessions = this.academicSessions.map((session) => {
      if (session.Id !== semesterId) return session;
      return this.decorateSession({ ...session, selectedTypeKey: typeKey });
    });
  }

  handleSessionCycleChange(event) {
    const semesterId = Number(event.currentTarget.dataset.semesterId);
    const cycleName = event.detail.value || "";
    this.academicSessions = this.academicSessions.map((session) => {
      if (session.Id !== semesterId) return session;
      return this.decorateSession({ ...session, selectedCycleName: cycleName });
    });
  }

  handleCreateGroupClick(event) {
    this.activeSemesterId = Number(event.currentTarget.dataset.semesterId);
    this.activeEnrollmentTypeKey = event.currentTarget.dataset.typeKey;
    this.groupNameInput = "";
    this.showCourseModal = false;
    this.showRuleModal = false;
    this.showCategoryModal = true;
  }

  handleAddCourseClick(event) {
    this.openCoursePickerForType(event.currentTarget.dataset.semesterId, event.currentTarget.dataset.typeKey);
  }

  handleAddCourseToGroup(event) {
    this.activeSemesterId = Number(event.currentTarget.dataset.semesterId);
    this.activeEnrollmentTypeKey = event.currentTarget.dataset.typeKey;
    this.activeGroupId = event.currentTarget.dataset.groupId;
    const session = this.getSessionById(this.activeSemesterId);
    this.activeCycleName = session?.selectedCycleName || "";
    this.currentCreditSum = 0;
    this.selectedCourseIds.clear();

    const groupRuleKey = this.getGroupRuleKey(this.activeSemesterId, this.activeEnrollmentTypeKey, this.activeGroupId);
    const existingRule = this.electiveGroupRuleMap[groupRuleKey];

    if (existingRule) {
      this.ruleType = existingRule.ruleType || "";
      this.minCourses = existingRule.minCourses;
      this.maxCourses = existingRule.maxCourses;
      this.maxCredits = existingRule.maxCredits;
      this.showCategoryModal = false;
      this.showRuleModal = false;
      this.showCourseModal = true;
      if (this.allCourses.length === 0) this.loadAllCourses();
      else this.updateFilteredCourses();
      return;
    }

    if (!this.shouldPromptForGroupRule(this.activeEnrollmentTypeKey)) {
      this.showCategoryModal = false;
      this.showRuleModal = false;
      this.showCourseModal = true;
      if (this.allCourses.length === 0) this.loadAllCourses();
      else this.updateFilteredCourses();
      return;
    }

    this.ruleType = "";
    this.minCourses = null;
    this.maxCourses = null;
    this.maxCredits = null;
    this.showCategoryModal = false;
    this.showCourseModal = false;
    this.showRuleModal = true;
  }

  handleCategoryInput(event) {
    this.groupNameInput = event.target.value;
  }

  saveCategory() {
    if (!this.groupNameInput) {
      this.showToast("Error", "Group name is required", "error");
      return;
    }

    const normalizedGroupName = this.groupNameInput.trim();
    const session = this.getSessionById(this.activeSemesterId);
    const enrollmentType = this.getSessionEnrollmentType(session, this.activeEnrollmentTypeKey);
    const existingNames = new Set((enrollmentType?.groups || []).map((g) => g.name.toLowerCase()));

    if (existingNames.has(normalizedGroupName.toLowerCase())) {
      this.showToast("Error", "A group with this name already exists for the selected enrollment type.", "error");
      return;
    }

    this.academicSessions = this.academicSessions.map((currentSession) => {
      if (currentSession.Id !== this.activeSemesterId) return currentSession;

      const nextTypes = currentSession.enrollmentTypes.map((type) => {
        if (type.key !== this.activeEnrollmentTypeKey) return type;
        return {
          ...type,
          groups: [...(type.groups || []), { groupId: normalizedGroupName, name: normalizedGroupName, courses: [], toneClass: type.toneClass }],
        };
      });

      return this.decorateSession({ ...currentSession, enrollmentTypes: nextTypes, selectedTypeKey: this.activeEnrollmentTypeKey });
    });

    this.showCategoryModal = false;
  }

  closeCategoryModal() {
    this.showCategoryModal = false;
  }

  openEnrollmentTypeModal() {
    this.newEnrollmentTypeName = "";
    this.newEnrollmentTypeCourseManagementMode = "Both";
    this.newEnrollmentTypeRequirementNature = "Mandatory";
    this.showEnrollmentTypeModal = true;
  }

  closeEnrollmentTypeModal() {
    this.showEnrollmentTypeModal = false;
  }

  handleEnrollmentTypeNameChange(event) {
    this.newEnrollmentTypeName = event.target.value;
  }
  handleEnrollmentTypeModeChange(event) {
    this.newEnrollmentTypeCourseManagementMode = event.detail.value;
  }
  handleEnrollmentTypeRequirementNatureChange(event) {
    this.newEnrollmentTypeRequirementNature = event.detail.value;
  }

  async saveEnrollmentType() {
    if (!this.newEnrollmentTypeName?.trim()) {
      this.showToast("Error", "Enrollment type name is required", "error");
      return;
    }

    try {
      const response = await createEnrollmentType({
        label: this.newEnrollmentTypeName.trim(),
        courseManagementMode: this.newEnrollmentTypeCourseManagementMode,
        requirementNature: this.newEnrollmentTypeRequirementNature,
      });

      const newConfig = this.decorateEnrollmentTypeConfig(response.enrollmentType, this.enrollmentTypeConfigs.length);
      this.enrollmentTypeConfigs = [...this.enrollmentTypeConfigs, newConfig];
      this.syncSessionsWithEnrollmentTypes(newConfig.key);
      this.showEnrollmentTypeModal = false;
      this.showToast("Success", "Enrollment type added successfully", "success");
    } catch (error) {
      this.showToast("Error", error?.body?.message || error.message, "error");
    }
  }

  // ─── Academic Cycle Handlers ──────────────────────────────────────────────

  async loadAcademicCycles() {
    if (!this.selectedProgramPlanLabel || this.selectedProgramPlanLabel === "No plan selected") {
      this.academicCycles = [];
      return;
    }
    try {
      const result = await getAcademicCycles({ programPlanName: this.selectedProgramPlanLabel });
      this.academicCycles = (result || []).map((c, index) => ({
        ...c,
        toneClass: `tone-${(index % 5) + 1}`,
        cardClass: `type-admin-card tone-${(index % 5) + 1}`,
        pillClass: `meta-pill tone-${(index % 5) + 1}`,
      }));
      this.refreshSessionCycleOptions();
    } catch (error) {
      this.showToast("Error", error?.body?.message || "Unable to load academic cycles", "error");
    }
  }

  openCycleModal() {
    this.newCycleName = "";
    this.newCycleDescription = "";
    this.showCycleModal = true;
  }

  closeCycleModal() {
    this.showCycleModal = false;
  }

  handleCycleNameChange(event) {
    this.newCycleName = event.target.value;
  }

  handleCycleDescriptionChange(event) {
    this.newCycleDescription = event.target.value;
  }

  async saveCycle() {
    if (!this.newCycleName?.trim()) {
      this.showToast("Error", "Cycle name is required", "error");
      return;
    }

    try {
      const response = await createAcademicCycle({
        label: this.newCycleName.trim(),
        programPlanName: this.selectedProgramPlanLabel,
        description: this.newCycleDescription?.trim() || null,
      });

      const newCycle = {
        ...response.cycle,
        toneClass: `tone-${(this.academicCycles.length % 5) + 1}`,
        cardClass: `type-admin-card tone-${(this.academicCycles.length % 5) + 1}`,
        pillClass: `meta-pill tone-${(this.academicCycles.length % 5) + 1}`,
      };
      this.academicCycles = [...this.academicCycles, newCycle];
      this.refreshSessionCycleOptions();
      this.showCycleModal = false;
      this.showToast("Success", "Academic cycle created successfully", "success");
    } catch (error) {
      this.showToast("Error", error?.body?.message || error.message, "error");
    }
  }

  refreshSessionCycleOptions() {
    if (!this.academicSessions.length) return;
    this.academicSessions = this.academicSessions.map((session) => this.decorateSession(session));
  }

  get hasCycles() {
    return this.academicCycles?.length > 0;
  }

  get isCycleAddDisabled() {
    return !this.selectedProgramPlan;
  }

  get cyclePickerOptions() {
    return this.academicCycles.map((c) => ({ label: c.label, value: c.label }));
  }

  get showCyclePickerInCourseModal() {
    return this.academicCycles.length > 0;
  }

  handleActiveCycleChange(event) {
    this.activeCycleName = event.detail.value;
  }

  handleCourseSearch(event) {
    this.searchKey = event.target.value.toLowerCase();
    this.updateFilteredCourses();
  }

  handleCourseSelection(event) {
    const courseId = event.target.dataset.courseId;
    const checked = event.target.checked;
    const course = this.allCourses.find((c) => c.Id === courseId);
    const courseCredits = course?.Duration ? Number(course.Duration) : 0;

    if (checked) {
      this.selectedCourseIds.add(courseId);
      this.currentCreditSum += courseCredits;
    } else {
      this.selectedCourseIds.delete(courseId);
      this.currentCreditSum -= courseCredits;
    }
  }

  async handleDoneClick() {
    if (this.selectedCourseIds.size === 0) {
      this.showToast("Error", "Select at least one course", "error");
      return;
    }

    const requestedIds = Array.from(this.selectedCourseIds);
    const session = this.getSessionById(this.activeSemesterId);
    const enrollmentType = this.getSessionEnrollmentType(session, this.activeEnrollmentTypeKey);
    const category = enrollmentType?.label;
    const groupName = this.activeGroupId ? this.getActiveGroupName() : null;
    const rulePayload = this.buildRulePayloadForSave();

    try {
      const result = await addCoursesToCurriculum({
        learningCourseIds: requestedIds,
        semesterNumber: this.activeSemesterId,
        category,
        groupName,
        learningProgramPlanId: this.selectedProgramPlan,
        learningPathwayTemplateId: this.selectedPathwayTemplate,
        ruleType: rulePayload.ruleType,
        minCourseCount: rulePayload.minCourseCount,
        maxCourseCount: rulePayload.maxCourseCount,
        maxCreditLimit: rulePayload.maxCreditLimit,
        cycleName: this.activeCycleName || null,
      });

      const addedIds = new Set(result?.addedCourseIds || []);
      const addedCourses = (this.allCourses || []).filter((c) => addedIds.has(c.Id));
      const errorCount = (result?.errors || []).length;

      if (addedIds.size > 0) {
        this.academicSessions = this.academicSessions.map((currentSession) => {
          if (currentSession.Id !== this.activeSemesterId) return currentSession;

          const nextTypes = currentSession.enrollmentTypes.map((type) => {
            if (type.key !== this.activeEnrollmentTypeKey) return type;

            if (!this.activeGroupId) {
              return {
                ...type,
                addedCourses: [
                  ...(type.addedCourses || []),
                  ...addedCourses.map((course) => ({
                    id: course.Id,
                    name: course.Name,
                    code: course.CourseNumber,
                    creditLabel: this.formatCourseCreditLabel(course.Duration),
                    typeLabel: type.label,
                    badgeClass: this.getTypeBadgeClass(type.key),
                    cycleName: this.activeCycleName || null,
                  })),
                ],
              };
            }

            const updatedGroups = (type.groups || []).map((group) => {
              if (group.groupId !== this.activeGroupId) return group;
              return {
                ...group,
                courses: [
                  ...(group.courses || []),
                  ...addedCourses.map((course) => ({
                    id: course.Id,
                    name: course.Name,
                    code: course.CourseNumber,
                    creditLabel: this.formatCourseCreditLabel(course.Duration),
                    typeLabel: type.label,
                    badgeClass: this.getTypeBadgeClass(type.key),
                    cycleName: this.activeCycleName || null,
                  })),
                ],
              };
            });

            return { ...type, groups: updatedGroups };
          });

          return this.decorateSession({ ...currentSession, enrollmentTypes: nextTypes });
        });

        if (this.activeGroupId) {
          const groupRuleKey = this.getGroupRuleKey(this.activeSemesterId, this.activeEnrollmentTypeKey, this.activeGroupId);
          this.electiveGroupRuleMap = {
            ...this.electiveGroupRuleMap,
            [groupRuleKey]: { ruleType: this.ruleType, minCourses: this.minCourses, maxCourses: this.maxCourses, maxCredits: this.maxCredits },
          };
        }

        this.showToast(errorCount > 0 ? "Warning" : "Success", errorCount > 0 ? `Added ${addedIds.size} course(s). ${errorCount} failed (see Audit Log).` : "Courses added successfully", errorCount > 0 ? "warning" : "success");

        this.closeCourseModal();
        this.selectedCourseIds.clear();
        this.updateFilteredCourses();
      } else if (errorCount > 0) {
        this.showToast("Error", `No courses added. ${errorCount} failed (see Audit Log).`, "error");
      } else {
        this.showToast("Error", "No courses were added.", "error");
      }
    } catch (error) {
      this.showToast("Error", error?.body?.message || "Error adding courses", "error");
    }
  }

  handleRuleTypeChange(event) {
    this.ruleType = event.detail.value;
  }
  handleMinChange(event) {
    this.minCourses = Number(event.target.value);
  }
  handleMaxChange(event) {
    this.maxCourses = Number(event.target.value);
  }
  handleCreditChange(event) {
    this.maxCredits = Number(event.target.value);
  }

  proceedToCoursePicker() {
    if (!this.ruleType) {
      this.showToast("Error", "Select a rule type", "error");
      return;
    }
    if (this.ruleType === "COUNT" && (!this.minCourses || this.minCourses <= 0 || !this.maxCourses || this.maxCourses <= 0 || this.minCourses > this.maxCourses)) {
      this.showToast("Error", "Enter valid Min / Max values", "error");
      return;
    }
    if (this.ruleType === "CREDIT" && (!this.maxCredits || this.maxCredits <= 0)) {
      this.showToast("Error", "Enter valid credit limit", "error");
      return;
    }

    this.showRuleModal = false;
    this.showCategoryModal = false;
    this.showCourseModal = true;

    if (this.allCourses.length === 0) this.loadAllCourses();
    else this.updateFilteredCourses();
  }

  closeRuleModal() {
    this.showRuleModal = false;
  }

  closeCourseModal() {
    this.showCourseModal = false;
    this.activeSemesterId = null;
    this.activeEnrollmentTypeKey = null;
    this.activeGroupId = null;
    this.activeCycleName = "";
  }

  // ─── Period Generation ────────────────────────────────────────────────────

  generatePeriods() {
    this.academicSessions = [];
    if (!this.programDuration || this.programDurationUnit !== "Years") return;

    const cadence = this.CADENCE_CONFIG[this.cadenceType];
    if (!cadence) return;

    const totalPeriods = this.programDuration * cadence.periodsPerYear;

    this.academicSessions = Array.from({ length: totalPeriods }, (_, index) => {
      const periodNumber = index + 1;
      const isEditable = !this.startSemester || !this.endSemester ? true : periodNumber >= this.startSemester && periodNumber <= this.endSemester;

      return this.decorateSession({
        Id: periodNumber,
        displayType: `${cadence.label} ${periodNumber}`,
        isExpanded: false,
        iconName: "utility:chevronright",
        isEditable,
        isDisabled: !isEditable,
        disableAddCourse: !isEditable || !this.selectedPathwayTemplate,
        cssClass: isEditable ? "semester-header slds-p-around_small" : "semester-header slds-p-around_small disabled-semester",
        selectedTypeKey: this.enrollmentTypeConfigs[0]?.key,
        // Empty slate – loadAddedCourses() will populate via DB
        enrollmentTypes: this.buildSessionEnrollmentTypesFromDb({}, []),
      });
    });
  }

  // ─── Session / EnrollmentType Helpers ────────────────────────────────────

  /**
   * Called when enrollmentTypeConfigs changes (new type deployed).
   * Rebuilds sessions so the new type slot appears everywhere,
   * while preserving existing course / group data already on each session.
   */
  syncSessionsWithEnrollmentTypes(preferredTypeKey) {
    if (!this.academicSessions.length) return;

    this.academicSessions = this.academicSessions.map((session) => {
      const nextSelectedKey = preferredTypeKey && this.enrollmentTypeConfigs.some((t) => t.key === preferredTypeKey) ? preferredTypeKey : session.selectedTypeKey;

      return this.decorateSession({
        ...session,
        selectedTypeKey: nextSelectedKey || this.enrollmentTypeConfigs[0]?.key,
        // Pass no DB map so existing session data is preserved as-is
        enrollmentTypes: this.buildSessionEnrollmentTypesFromDb({}, session.enrollmentTypes),
      });
    });
  }

  decorateSession(session) {
    const selectedCycle = session.selectedCycleName || "";
    const cycleFilter = (course) => !selectedCycle || !course.cycleName || course.cycleName === selectedCycle;

    const availableTypes = (session.enrollmentTypes || []).map((type) => ({
      ...type,
      filteredCourses: (type.addedCourses || []).filter(cycleFilter),
      groups: (type.groups || []).map((group) => ({
        ...group,
        filteredGroupCourses: (group.courses || []).filter(cycleFilter),
        ruleSummary: this.getGroupRuleSummary(session.Id, type.key, group.groupId),
      })),
      buttonVariant: type.key === session.selectedTypeKey ? "brand" : "neutral",
      badgeClass: this.getTypeBadgeClass(type.key),
      buttonClass: `enrollment-type-button ${type.toneClass}`,
    }));

    const activeEnrollmentType = availableTypes.find((type) => type.key === session.selectedTypeKey) ||
      availableTypes[0] || {
        key: null,
        label: "",
        requiresGroup: false,
        allowsDirectCourses: false,
        allowsGroupedCourses: false,
        addedCourses: [],
        filteredCourses: [],
        groups: [],
      };

    const cadence = this.CADENCE_CONFIG[this.cadenceType];
    const periodsInYear1 = cadence ? cadence.periodsPerYear : 2;
    const isYear1 = session.Id >= 1 && session.Id <= periodsInYear1;

    const cycleOptions = isYear1
      ? [{ label: "No Cycle (common)", value: "" }, ...this.academicCycles.map((c) => ({ label: c.label, value: c.label }))]
      : [];
    const hasCycleOptions = isYear1 && this.academicCycles.length > 0;

    return {
      ...session,
      selectedTypeKey: activeEnrollmentType?.key,
      enrollmentTypes: availableTypes,
      activeEnrollmentType,
      cycleOptions,
      hasCycleOptions,
      isYear1,
      selectedCycleName: selectedCycle,
    };
  }

  openCoursePickerForType(semesterId, enrollmentTypeKey) {
    this.activeSemesterId = Number(semesterId);
    this.activeEnrollmentTypeKey = enrollmentTypeKey;
    this.activeGroupId = null;
    const session = this.getSessionById(this.activeSemesterId);
    this.activeCycleName = session?.selectedCycleName || "";
    this.ruleType = "";
    this.minCourses = null;
    this.maxCourses = null;
    this.maxCredits = null;
    this.currentCreditSum = 0;
    this.selectedCourseIds.clear();
    this.showCategoryModal = false;
    this.showRuleModal = false;
    this.showCourseModal = true;

    if (this.allCourses.length === 0) this.loadAllCourses();
    else this.updateFilteredCourses();
  }

  getExistingCourseIdsForActiveTarget() {
    const session = this.getSessionById(this.activeSemesterId);
    if (!session) return new Set();
    const enrollmentType = this.getSessionEnrollmentType(session, this.activeEnrollmentTypeKey);
    if (!enrollmentType) return new Set();

    if (!this.activeGroupId) {
      return new Set((enrollmentType.addedCourses || []).map((c) => c.id).filter(Boolean));
    }

    const group = (enrollmentType.groups || []).find((g) => g.groupId === this.activeGroupId);
    return new Set((group?.courses || []).map((c) => c.id).filter(Boolean));
  }

  updateFilteredCourses() {
    const term = (this.searchKey || "").trim().toLowerCase();
    const existing = this.getExistingCourseIdsForActiveTarget();

    const base = term
      ? (this.allCourses || []).filter((course) => course._searchText?.includes(term))
      : this.allCourses || [];

    const visibleCourses = term ? base : base.slice(0, this.COURSE_RENDER_LIMIT);

    this.filteredCourses = visibleCourses.map((course) => ({
      ...course,
      isAlreadyAddedToActiveTarget: existing.has(course.Id),
      isChecked: existing.has(course.Id) || this.selectedCourseIds.has(course.Id),
      rowClass: existing.has(course.Id) ? "course-row course-row-locked" : "course-row",
    }));
  }

  getActiveGroupName() {
    const session = this.getSessionById(this.activeSemesterId);
    const enrollmentType = this.getSessionEnrollmentType(session, this.activeEnrollmentTypeKey);
    const group = (enrollmentType?.groups || []).find((g) => g.groupId === this.activeGroupId);
    return group?.name;
  }

  getSessionById(sessionId) {
    return this.academicSessions.find((s) => s.Id === Number(sessionId));
  }

  getSessionEnrollmentType(session, typeKey) {
    return session?.enrollmentTypes?.find((t) => t.key === typeKey);
  }

  getEnrollmentTypeConfig(typeKey) {
    return this.enrollmentTypeConfigs.find((t) => t.key === typeKey || t.label === typeKey);
  }

  resolveEnrollmentTypeKey(identifier) {
    const normalized = String(identifier || "").toLowerCase();
    return this.enrollmentTypeConfigs.find((t) => t.key?.toLowerCase() === normalized || t.label?.toLowerCase() === normalized)?.key || identifier;
  }

  deriveCourseManagementMode(row) {
    if (row?.courseManagementMode) return row.courseManagementMode;
    if (row?.requiresGroup) return "Grouped";
    return "Direct";
  }

  isGroupedCourseRow(row, config) {
    const hasRule =
      !!row?.ruleType ||
      row?.minCourseCount != null ||
      row?.maxCourseCount != null ||
      row?.maxCreditLimit != null;
    const normalizedGroupName = String(row?.groupName || "").trim().toLowerCase();
    const normalizedCategory = String(row?.category || config?.label || "").trim().toLowerCase();

    if (!normalizedGroupName) return false;
    if (!hasRule && normalizedGroupName === normalizedCategory) return false;
    return true;
  }

  getDbTypeDataForConfig(config, dbTypeMap) {
    if (!config || !dbTypeMap) return null;
    if (dbTypeMap[config.key]) return dbTypeMap[config.key];

    const normalizedConfigLabel = String(config.label || "").trim().toLowerCase();
    return Object.values(dbTypeMap).find((typeData) => String(typeData?.label || "").trim().toLowerCase() === normalizedConfigLabel) || null;
  }

  getTypeBadgeClass(typeKey) {
    const config = this.getEnrollmentTypeConfig(typeKey);
    return `course-type-pill ${config?.toneClass || "tone-1"}`;
  }

  shouldPromptForGroupRule(typeKey) {
    const config = this.getEnrollmentTypeConfig(typeKey);
    const normalizedLabel = String(config?.label || typeKey || "").trim().toLowerCase();
    return normalizedLabel !== "core";
  }

  formatCourseCreditLabel(credits) {
    if (credits == null || credits === "") return "";
    const numericCredits = Number(credits);
    if (Number.isNaN(numericCredits)) return "";
    const normalizedCredits = Number.isInteger(numericCredits) ? numericCredits : numericCredits.toFixed(1);
    return `${normalizedCredits} Credit${numericCredits === 1 ? "" : "s"}`;
  }

  getGroupRuleKey(semesterId, typeKey, groupId) {
    return `${semesterId}::${typeKey}::${groupId}`;
  }

  getGroupRuleSummary(semesterId, typeKey, groupId) {
    const rule = this.electiveGroupRuleMap[this.getGroupRuleKey(semesterId, typeKey, groupId)];
    if (!rule) return "";
    if (rule.ruleType === "COUNT") return `Rule: Min / Max Course Count (${rule.minCourses ?? "-"} - ${rule.maxCourses ?? "-"})`;
    if (rule.ruleType === "CREDIT") return `Rule: Max Credit Limit (${rule.maxCredits ?? "-"})`;
    return "";
  }

  mapStoredRuleTypeToUi(ruleType) {
    if (ruleType === "Min/Max Course Count") return "COUNT";
    if (ruleType === "Max Credit Limit") return "CREDIT";
    return "";
  }

  buildRulePayloadForSave() {
    if (!this.activeGroupId) {
      return { ruleType: null, minCourseCount: null, maxCourseCount: null, maxCreditLimit: null };
    }
    if (this.ruleType === "COUNT") {
      return { ruleType: "Min/Max Course Count", minCourseCount: this.minCourses, maxCourseCount: this.maxCourses, maxCreditLimit: null };
    }
    if (this.ruleType === "CREDIT") {
      return { ruleType: "Max Credit Limit", minCourseCount: null, maxCourseCount: null, maxCreditLimit: this.maxCredits };
    }
    return { ruleType: null, minCourseCount: null, maxCourseCount: null, maxCreditLimit: null };
  }

  extractPeriodNumber(label) {
    return Number(String(label || "").replace(/\D/g, ""));
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  // ─── Computed Getters ─────────────────────────────────────────────────────

  get isProgramPlanDisabled() {
    return !this.selectedProgram;
  }

  get filteredProgramOptions() {
    const term = (this.programSearchKey || "").trim().toLowerCase();
    const selectedLabel = String(this.selectedProgramLabel || "").trim().toLowerCase();
    if (!term || (this.selectedProgram && term === selectedLabel)) {
      return this.programOptions;
    }
    return (this.programOptions || []).filter((item) => {
      const label = String(item.label || "").toLowerCase();
      return label.includes(term);
    });
  }

  get hasFilteredProgramOptions() {
    return this.filteredProgramOptions.length > 0;
  }

  get isProgramDropdownOpen() {
    return this.programDropdownOpen;
  }
  get isPathwayTypeDisabled() {
    return this.pathwayTypeOptions.length === 0;
  }
  get isPathwayNameDisabled() {
    return !this.selectedPathwayType;
  }
  get isAcademicTermDisabled() {
    return !this.selectedProgramPlan;
  }
  get hasAcademicSessions() {
    return this.academicSessions?.length > 0;
  }
  get isPathwaySelected() {
    return !!this.selectedPathwayTemplate;
  }

  get selectedProgramLabel() {
    return this.programOptions.find((item) => item.value === this.selectedProgram)?.label || "No program selected";
  }

  get selectedProgramPlanLabel() {
    return this.programPlanOptions.find((item) => item.value === this.selectedProgramPlan)?.label || "No plan selected";
  }

  get selectedPathwayTypeLabel() {
    return this.selectedPathwayType || "No pathway type";
  }

  get selectedPathwayTemplateLabel() {
    return this.pathwayTemplateOptions.find((item) => item.value === this.selectedPathwayTemplate)?.label || "No pathway selected";
  }

  get totalAddedCourseCount() {
    return (this.academicSessions || []).reduce((total, session) => {
      return (
        total +
        (session.enrollmentTypes || []).reduce((sessionTotal, type) => {
          const directCourses = (type.addedCourses || []).length;
          const groupedCourses = (type.groups || []).reduce((groupTotal, group) => groupTotal + (group.courses || []).length, 0);
          return sessionTotal + directCourses + groupedCourses;
        }, 0)
      );
    }, 0);
  }

  get totalGroupCount() {
    return (this.academicSessions || []).reduce((total, session) => {
      return total + (session.enrollmentTypes || []).reduce((sessionTotal, type) => sessionTotal + (type.groups || []).length, 0);
    }, 0);
  }

  get curriculumSummaryCards() {
    return [
      {
        key: "periods",
        label: "Active Periods",
        value: String(this.academicSessions?.length || 0),
        caption: this.cadenceType || "Select a pathway",
      },
      {
        key: "courses",
        label: "Mapped Courses",
        value: String(this.totalAddedCourseCount),
        caption: "Across all enrollment types",
      },
      {
        key: "groups",
        label: "Groups",
        value: String(this.totalGroupCount),
        caption: "For grouped enrollment types",
      },
    ];
  }

  get enrollmentTypeCards() {
    return this.enrollmentTypeConfigs.map((type) => ({
      ...type,
      cardClass: `type-admin-card ${type.toneClass}`,
      modeLabel: type.courseManagementMode === "Both" ? "Direct + Grouped" : type.courseManagementMode === "Grouped" ? "Grouped courses" : "Direct courses",
      natureLabel: type.requirementNature || "Mandatory",
      pillClass: `meta-pill ${type.toneClass}`,
    }));
  }

  get activeGroupModalTitle() {
    const config = this.getEnrollmentTypeConfig(this.activeEnrollmentTypeKey);
    return config ? `Create ${config.label} Group` : "Create Group";
  }

  get activeGroupModalLabel() {
    const config = this.getEnrollmentTypeConfig(this.activeEnrollmentTypeKey);
    return config ? `${config.label} Group Name` : "Group Name";
  }

  get activeEnrollmentTypeModeText() {
    if (this.newEnrollmentTypeCourseManagementMode === "Both") {
      return "This type will allow both direct course addition and named group-based course configuration.";
    }
    if (this.newEnrollmentTypeCourseManagementMode === "Grouped") {
      return "This type will manage courses through named groups and rule configuration.";
    }
    return "This type will allow courses to be added directly inside each period.";
  }

  get enrollmentTypeModeOptions() {
    return [
      { label: "Direct", value: "Direct" },
      { label: "Grouped", value: "Grouped" },
      { label: "Direct + Grouped", value: "Both" },
    ];
  }

  get requirementNatureOptions() {
    return [
      { label: "Mandatory", value: "Mandatory" },
      { label: "Not Mandatory", value: "Not Mandatory" },
      { label: "Zero Credit", value: "Zero Credit" },
    ];
  }

  get ruleOptions() {
    return [
      { label: "Min / Max Course Count", value: "COUNT" },
      { label: "Max Credit Limit", value: "CREDIT" },
    ];
  }

  get isCountRule() {
    return this.ruleType === "COUNT";
  }
  get isCreditRule() {
    return this.ruleType === "CREDIT";
  }

  get isCourseListTrimmed() {
    return !this.searchKey && (this.allCourses?.length || 0) > this.COURSE_RENDER_LIMIT;
  }
}