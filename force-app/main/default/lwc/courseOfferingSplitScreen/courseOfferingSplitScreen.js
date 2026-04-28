import { LightningElement, api, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CurrentPageReference } from "lightning/navigation";
import getAcademicSessionsByTerm from "@salesforce/apex/KenCourseOfferingSplitController.getAcademicSessionsByTerm";
import getPlaceholderOfferings from "@salesforce/apex/KenCourseOfferingSplitController.getPlaceholderOfferings";
import getProgramPlansForOffering from "@salesforce/apex/KenCourseOfferingSplitController.getProgramPlansForOffering";
import splitOfferingsJson from "@salesforce/apex/KenCourseOfferingSplitController.splitOfferingsJson";
import getActivePlannedOfferings from "@salesforce/apex/KenCourseOfferingSplitController.getActivePlannedOfferings";
import getCourseOfferingParticipants from "@salesforce/apex/KenCourseOfferingSplitController.getCourseOfferingParticipants";
import getThemeColors from "@salesforce/apex/UiThemeController.getThemeColors";

export default class CourseOfferingSplitScreen extends LightningElement {
  _recordId;
  _academicTermId;
  @track sessions = [];
  @track offerings = [];
  @track viewSessions = [];
  @track viewOfferings = [];

  termId;
  sessionId;
  viewTermId;
  viewSessionId;
  viewEnrollmentType = "All";
  createSearchTerm = "";
  viewSearchTerm = "";
  createSortBy = "Name";
  createSortDirection = "asc";
  viewSortBy = "courseOfferingName";
  viewSortDirection = "asc";

  bulkCourseType = "All";
  combinedGroupName = "";
  combinedOfferingCount = 1;
  combinedCapacity = null;
  selectedOfferingIds = [];
  showBulkSplitModal = false;
  showParticipantsModal = false;
  participants = [];
  selectedParticipantOfferingName = "";
  isPlaceholderSelected = false;
  bulkUserType = "Individual";
  bulkOfferingCount = 1;
  bulkSections = 1;
  bulkCapacity = null;
  @track bulkOfferingPlanPreview = [];

  isLoading = false;
  _initializedContextTermId;
  pageRef;

  @api
  get recordId() {
    return this._recordId;
  }

  set recordId(value) {
    this._recordId = value;
    this.initializeFromRecordContext();
  }

  @api
  get academicTermId() {
    return this._academicTermId;
  }

  set academicTermId(value) {
    this._academicTermId = value;
    this.initializeFromRecordContext();
  }

  bulkUserTypeOptions = [
    { label: "Individual", value: "Individual" },
    { label: "Section", value: "Section" },
    { label: "Combined", value: "Combined" },
  ];

  viewEnrollmentTypeOptions = [
    { label: "All", value: "All" },
    { label: "Core", value: "Core" },
    { label: "Elective", value: "Elective" },
  ];

  connectedCallback() {
    this.applyThemeColor();
    this.initializeFromRecordContext();
  }

  @wire(CurrentPageReference)
  wiredPageRef(value) {
    this.pageRef = value;
    this.initializeFromRecordContext();
  }

  async applyThemeColor() {
    try {
      const colors = await getThemeColors();
      if (colors && colors.primary) {
        this.template.host.style.setProperty("--theme-primary", colors.primary);
      }
      if (colors && colors.secondary) {
        this.template.host.style.setProperty("--theme-secondary", colors.secondary);
      }
    } catch (e) {
      // ignore theme load errors
    }
  }

  get sessionOptions() {
    return this.sessions.map((s) => ({ label: s.Name, value: s.Id }));
  }

  get viewSessionOptions() {
    return this.viewSessions.map((s) => ({ label: s.Name, value: s.Id }));
  }

  get hasOfferings() {
    return this.offerings.length > 0;
  }

  get selectedOfferingsCount() {
    return this.selectedOfferingIds.length;
  }

  get bulkCourseTypeOptions() {
    const values = new Set();
    (this.offerings || []).forEach((o) => {
      const raw = o && o.courseType ? String(o.courseType) : "";
      raw
        .split(",")
        .map((v) => v.trim())
        .filter((v) => !!v)
        .forEach((v) => values.add(v));
    });
    const options = [{ label: "All", value: "All" }];
    Array.from(values)
      .sort()
      .forEach((v) => options.push({ label: v, value: v }));
    return options;
  }

  get displayedSessionOfferings() {
    let rows = this.filteredOfferingsByEnrollmentType;
    if (this.bulkCourseType && this.bulkCourseType !== "All") {
      const target = this.bulkCourseType.toLowerCase();
      rows = (rows || []).filter((o) =>
        String(o.courseType || "")
          .toLowerCase()
          .split(",")
          .map((v) => v.trim())
          .includes(target),
      );
    }
    rows = this.filterBySearch(rows, this.createSearchTerm, ["Name", "courseNumber", "courseName", "courseType"]);
    return this.sortRows(rows, this.createSortBy, this.createSortDirection);
  }

  get filteredOfferingsByEnrollmentType() {
    return this.offerings || [];
  }

  get displayedViewOfferings() {
    const rows = this.filterBySearch(this.viewOfferings || [], this.viewSearchTerm, ["courseOfferingName", "courseNumber", "courseName", "courseType", "offeringType"]);
    return this.sortRows(rows, this.viewSortBy, this.viewSortDirection);
  }

  get isAllDisplayedSelected() {
    const displayed = this.displayedSessionOfferings || [];
    if (!displayed.length) {
      return false;
    }
    const selected = new Set(this.selectedOfferingIds || []);
    return displayed.every((o) => selected.has(o.Id));
  }

  get isProceedBulkDisabled() {
    return this.selectedOfferingIds.length === 0 || this.isLoading;
  }

  get isBulkSectionMode() {
    return this.bulkUserType === "Section";
  }

  get isBulkIndividualMode() {
    return this.bulkUserType === "Individual";
  }

  get isBulkCombinedMode() {
    return this.bulkUserType === "Combined";
  }

  get isBulkSplitDisabled() {
    if (this.isLoading || !this.bulkUserType) {
      return true;
    }
    if (this.isBulkIndividualMode && (!this.bulkOfferingCount || this.bulkOfferingCount < 1)) {
      return true;
    }
    if (this.isBulkSectionMode && (!this.bulkSections || this.bulkSections < 1)) {
      return true;
    }
    if (this.bulkUserType === "Combined") {
      return !this.combinedGroupName || !this.combinedOfferingCount || this.combinedOfferingCount < 1 || !this.hasSelectedCombinedPlans;
    }
    return false;
  }

  get hasBulkOfferingPlanPreview() {
    return this.bulkOfferingPlanPreview && this.bulkOfferingPlanPreview.length > 0;
  }

  get combinedPreviewRows() {
    return (this.bulkOfferingPlanPreview || []).map((row) => ({
      ...row,
      selectedPlanCount: (row.selectedPlanIds || []).length,
      statusText: row.loadError || "Ready",
      statusClass: row.loadError === "Ready" ? "status-pill status-ready" : row.loadError === "No plans found" ? "status-pill status-warning" : "status-pill status-error",
    }));
  }

  get combinedReadyCount() {
    return this.combinedPreviewRows.filter((row) => row.statusText === "Ready").length;
  }

  get combinedTotalPlanCount() {
    return this.combinedPreviewRows.reduce((sum, row) => sum + (Number(row.selectedPlanCount) || 0), 0);
  }

  get selectedCombinedPlanRows() {
    return (this.bulkOfferingPlanPreview || []).flatMap((row) =>
      (row.plans || [])
        .filter((plan) => (row.selectedPlanIds || []).includes(plan.planId))
        .map((plan) => ({
          planId: plan.planId,
          planName: plan.planName,
          enrollmentType: plan.enrollmentType,
          type: this.bulkUserType,
          sections: this.bulkUserType === "Section" ? this.bulkSections : 1,
          selectedSections: [],
          offeringCount: this.bulkUserType === "Individual" ? this.bulkOfferingCount : this.bulkUserType === "Combined" ? this.combinedOfferingCount : null,
          capacity: this.bulkUserType === "Combined" ? this.combinedCapacity : this.bulkCapacity,
        })),
    );
  }

  get hasSelectedCombinedPlans() {
    return this.selectedCombinedPlanRows.length > 0;
  }

  get showNoOfferingsMessage() {
    return !!this.sessionId && !this.hasOfferings;
  }

  get contextTermId() {
    const state = this.pageRef?.state || {};
    const attrs = this.pageRef?.attributes || {};
    return this._academicTermId || this._recordId || attrs.recordId || state.recordId || state.c__recordId || null;
  }

  get isViewSessionDisabled() {
    return !this.viewTermId;
  }

  get showViewEmptyMessage() {
    return !!this.viewTermId && this.viewOfferings.length === 0;
  }

  get showCreateNoResultsMessage() {
    return !!this.sessionId && this.hasOfferings && this.displayedSessionOfferings.length === 0;
  }

  get showViewNoResultsMessage() {
    return !!this.viewTermId && this.viewOfferings.length > 0 && this.displayedViewOfferings.length === 0;
  }

  get createSortSummary() {
    return `Sorted by ${this.getSortLabel(this.createSortBy, "create")} (${this.createSortDirection})`;
  }

  get viewSortSummary() {
    return `Sorted by ${this.getSortLabel(this.viewSortBy, "view")} (${this.viewSortDirection})`;
  }

  get createSortIndicators() {
    return {
      Name: this.getSortIndicator(this.createSortBy, this.createSortDirection, "Name"),
      courseNumber: this.getSortIndicator(this.createSortBy, this.createSortDirection, "courseNumber"),
      courseName: this.getSortIndicator(this.createSortBy, this.createSortDirection, "courseName"),
      courseType: this.getSortIndicator(this.createSortBy, this.createSortDirection, "courseType"),
    };
  }

  get viewSortIndicators() {
    return {
      courseOfferingName: this.getSortIndicator(this.viewSortBy, this.viewSortDirection, "courseOfferingName"),
      courseNumber: this.getSortIndicator(this.viewSortBy, this.viewSortDirection, "courseNumber"),
      courseName: this.getSortIndicator(this.viewSortBy, this.viewSortDirection, "courseName"),
      enrollmentCapacity: this.getSortIndicator(this.viewSortBy, this.viewSortDirection, "enrollmentCapacity"),
      enrolleeCount: this.getSortIndicator(this.viewSortBy, this.viewSortDirection, "enrolleeCount"),
      courseType: this.getSortIndicator(this.viewSortBy, this.viewSortDirection, "courseType"),
      offeringType: this.getSortIndicator(this.viewSortBy, this.viewSortDirection, "offeringType"),
    };
  }

  async initializeFromRecordContext() {
    const contextTermId = this.contextTermId;
    if (!contextTermId) {
      return;
    }
    if (this._initializedContextTermId === contextTermId) {
      return;
    }
    this._initializedContextTermId = contextTermId;
    this.termId = contextTermId;
    this.viewTermId = contextTermId;
    await Promise.all([this.loadSessionsForCreate(), this.loadSessionsAndOfferingsForView()]);
  }

  async loadSessionsForCreate() {
    this.sessionId = null;
    this.sessions = [];
    this.offerings = [];
    this.selectedOfferingIds = [];
    this.bulkCourseType = "All";

    if (!this.termId) {
      return;
    }
    try {
      this.sessions = await getAcademicSessionsByTerm({ academicTermId: this.termId });
    } catch (e) {
      this.showError("Failed to load Academic Sessions", e);
    }
  }

  async loadSessionsAndOfferingsForView() {
    this.viewSessionId = null;
    this.viewSessions = [];
    this.viewOfferings = [];

    if (!this.viewTermId) {
      return;
    }
    try {
      this.viewSessions = await getAcademicSessionsByTerm({ academicTermId: this.viewTermId });
      await this.loadViewOfferingsForTerm();
    } catch (e) {
      this.showError("Failed to load Academic Sessions", e);
    }
  }

  async handleViewSessionChange(event) {
    this.viewSessionId = event.detail.value;
    this.viewOfferings = [];
    this.viewSearchTerm = "";
    if (this.viewSessionId) {
      try {
        const raw = await getActivePlannedOfferings({
          academicSessionId: this.viewSessionId,
          enrollmentType: this.viewEnrollmentType,
        });
        this.viewOfferings = this.normalizeViewOfferings(raw);
      } catch (e) {
        this.showError("Failed to load Course Offerings", e);
      }
    }
  }

  async handleViewEnrollmentTypeChange(event) {
    this.viewEnrollmentType = event.detail.value;
    if (this.viewSessionId) {
      try {
        const raw = await getActivePlannedOfferings({
          academicSessionId: this.viewSessionId,
          enrollmentType: this.viewEnrollmentType,
        });
        this.viewOfferings = this.normalizeViewOfferings(raw);
      } catch (e) {
        this.showError("Failed to load Course Offerings", e);
      }
    } else if (this.viewTermId) {
      await this.loadViewOfferingsForTerm();
    }
  }

  async loadViewOfferingsForTerm() {
    if (!this.viewTermId || !this.viewSessions.length) {
      this.viewOfferings = [];
      return;
    }
    try {
      const results = await Promise.all(
        this.viewSessions.map((s) =>
          getActivePlannedOfferings({
            academicSessionId: s.Id,
            enrollmentType: this.viewEnrollmentType,
          }),
        ),
      );
      const byId = new Map();
      results.forEach((list) => {
        (list || []).forEach((o) => {
          byId.set(o.id, o);
        });
      });
      this.viewOfferings = this.normalizeViewOfferings(Array.from(byId.values()));
    } catch (e) {
      this.showError("Failed to load Course Offerings", e);
    }
  }

  async handleCourseOfferingImportRefresh() {
    if (this.termId) {
      await this.loadSessionsForCreate();
    }
    if (this.viewTermId) {
      await this.loadSessionsAndOfferingsForView();
    }
  }

  normalizeViewOfferings(list) {
    return (list || []).map((o) => ({
      ...o,
      recordUrl: o && o.id ? `/${o.id}` : "",
      hasParticipants: Number(o && o.enrolleeCount) > 0,
    }));
  }

  async handleEnrolleeClick(event) {
    const offeringId = event.currentTarget?.dataset?.id;
    const offeringName = event.currentTarget?.dataset?.name;
    if (!offeringId) {
      return;
    }
    this.selectedParticipantOfferingName = offeringName || "Course Offering";
    this.participants = [];
    this.isLoading = true;
    try {
      const rows = await getCourseOfferingParticipants({ courseOfferingId: offeringId });
      this.participants = (rows || []).map((r) => ({
        ...r,
        participantRecordUrl: r && r.participantId ? `/${r.participantId}` : "",
      }));
      this.showParticipantsModal = true;
    } catch (e) {
      this.showError("Failed to load participants", e);
    } finally {
      this.isLoading = false;
    }
  }

  handleCloseParticipantsModal() {
    this.showParticipantsModal = false;
    this.participants = [];
    this.selectedParticipantOfferingName = "";
  }

  async handleSessionChange(event) {
    this.sessionId = event.detail.value;
    this.offerings = [];
    this.selectedOfferingIds = [];
    this.bulkCourseType = "All";
    this.createSearchTerm = "";
    if (this.sessionId) {
      try {
        const raw = await getPlaceholderOfferings({ academicSessionId: this.sessionId });
        this.offerings = (raw || []).map((o) => ({
          Id: o.Id || o.id,
          Name: o.Name || o.name,
          courseNumber: o.courseNumber || o.CourseNumber,
          courseName: o.courseName || o.CourseName,
          courseType: o.courseType || o.CourseType,
          enrollmentType: o.enrollmentType || o.EnrollmentType,
          recordUrl: o.Id || o.id ? `/${o.Id || o.id}` : "",
          isSelected: false,
        }));
      } catch (e) {
        this.showError("Failed to load Course Offerings", e);
      }
    }
  }

  handleBulkCourseTypeChange(event) {
    this.bulkCourseType = event.detail.value;
  }

  handleCreateSearchChange(event) {
    this.createSearchTerm = event.detail?.value ?? event.target?.value ?? "";
  }

  handleViewSearchChange(event) {
    this.viewSearchTerm = event.detail?.value ?? event.target?.value ?? "";
  }

  handleCreateSort(event) {
    const field = event.currentTarget?.dataset?.field;
    if (!field) {
      return;
    }
    this.createSortDirection = this.createSortBy === field && this.createSortDirection === "asc" ? "desc" : "asc";
    this.createSortBy = field;
  }

  handleViewSort(event) {
    const field = event.currentTarget?.dataset?.field;
    if (!field) {
      return;
    }
    this.viewSortDirection = this.viewSortBy === field && this.viewSortDirection === "asc" ? "desc" : "asc";
    this.viewSortBy = field;
  }

  async handleSelectOfferingFromList(event) {
    const selectedId = event.currentTarget?.dataset?.id;
    if (!selectedId) {
      return;
    }
    const selectedSet = new Set(this.selectedOfferingIds || []);
    if (selectedSet.has(selectedId)) {
      selectedSet.delete(selectedId);
    } else {
      selectedSet.add(selectedId);
    }
    this.selectedOfferingIds = Array.from(selectedSet);
    this.offerings = this.offerings.map((o) => ({
      ...o,
      isSelected: selectedSet.has(o.Id),
    }));
  }

  handleOfferingSelectionChange(event) {
    const selectedId = event.currentTarget?.dataset?.id;
    const checked = !!event.detail.checked;
    if (!selectedId) {
      return;
    }
    const selectedSet = new Set(this.selectedOfferingIds);
    if (checked) {
      selectedSet.add(selectedId);
    } else {
      selectedSet.delete(selectedId);
    }
    this.selectedOfferingIds = Array.from(selectedSet);
    this.offerings = this.offerings.map((o) => ({
      ...o,
      isSelected: selectedSet.has(o.Id),
    }));
  }

  handleSelectAllOfferingsChange(event) {
    const checked = !!event.detail.checked;
    const displayedIds = (this.displayedSessionOfferings || []).map((o) => o.Id);
    const selectedSet = new Set(this.selectedOfferingIds || []);

    if (checked) {
      displayedIds.forEach((id) => selectedSet.add(id));
    } else {
      displayedIds.forEach((id) => selectedSet.delete(id));
    }

    this.selectedOfferingIds = Array.from(selectedSet);
    this.offerings = (this.offerings || []).map((o) => ({
      ...o,
      isSelected: selectedSet.has(o.Id),
    }));
  }

  async handleProceedBulk() {
    if (!this.selectedOfferingIds.length) {
      return;
    }
    this.bulkUserType = "Individual";
    this.bulkOfferingCount = 1;
    this.bulkSections = 1;
    this.bulkCapacity = null;
    this.bulkOfferingPlanPreview = [];
    this.isLoading = true;
    try {
      const nameById = new Map((this.offerings || []).map((o) => [o.Id, o.Name]));
      const previewRows = await Promise.all(
        this.selectedOfferingIds.map(async (selectedOfferingId) => {
          try {
            const plans = await getProgramPlansForOffering({ courseOfferingId: selectedOfferingId });
            const normalizedPlans = (plans || []).map((p) => ({
              planId: p.id,
              planName: p.name,
              enrollmentType: p.enrollmentType,
            }));
            return {
              offeringId: selectedOfferingId,
              offeringName: nameById.get(selectedOfferingId) || selectedOfferingId,
              plans: normalizedPlans,
              planCount: normalizedPlans.length,
              selectedPlanIds: normalizedPlans.map((plan) => plan.planId),
              planOptions: normalizedPlans.map((plan) => ({
                label: plan.planName,
                value: plan.planId,
              })),
              loadError: normalizedPlans.length ? "Ready" : "No plans found",
            };
          } catch (e) {
            return {
              offeringId: selectedOfferingId,
              offeringName: nameById.get(selectedOfferingId) || selectedOfferingId,
              plans: [],
              planCount: 0,
              selectedPlanIds: [],
              planOptions: [],
              loadError: "Failed to load plans",
            };
          }
        }),
      );
      this.bulkOfferingPlanPreview = previewRows;
    } finally {
      this.isLoading = false;
    }
    this.showBulkSplitModal = true;
  }

  handleCloseBulkSplitModal() {
    this.showBulkSplitModal = false;
    this.bulkOfferingPlanPreview = [];
  }

  handleBulkUserTypeChange(event) {
    this.bulkUserType = event.detail.value;
  }

  handleBulkSectionsChange(event) {
    this.bulkSections = Number(event.detail.value);
  }

  handleBulkOfferingCountChange(event) {
    this.bulkOfferingCount = Number(event.detail.value);
  }

  handleBulkCapacityChange(event) {
    this.bulkCapacity = Number(event.detail.value);
  }

  async handleBulkSplitConfirm() {
    if (!this.selectedOfferingIds.length) {
      this.showToast("Error", "Please select at least one course offering.", "error");
      return;
    }

    this.isLoading = true;
    let successCount = 0;
    const failedOfferingIds = [];
    try {
      for (const selectedOfferingId of this.selectedOfferingIds) {
        try {
          const previewRow = (this.bulkOfferingPlanPreview || []).find((row) => row.offeringId === selectedOfferingId);
          const planRows = this.isBulkCombinedMode
            ? this.selectedCombinedPlanRows
            : (previewRow?.plans || []).map((p) => ({
                planId: p.planId,
                planName: p.planName,
                enrollmentType: p.enrollmentType,
                type: this.bulkUserType,
                sections: this.bulkUserType === "Section" ? this.bulkSections : 1,
                selectedSections: [],
                offeringCount: this.bulkUserType === "Individual" ? this.bulkOfferingCount : this.bulkUserType === "Combined" ? this.combinedOfferingCount : null,
                capacity: this.bulkUserType === "Combined" ? this.combinedCapacity : this.bulkCapacity,
              }));

          if (!planRows.length) {
            failedOfferingIds.push(selectedOfferingId);
            continue;
          }

          const payload = {
            placeholderOfferingId: selectedOfferingId,
            combinedGroupName: this.bulkUserType === "Combined" ? this.combinedGroupName : "",
            combinedOfferingCount: this.bulkUserType === "Combined" ? this.combinedOfferingCount : null,
            combinedCapacity: this.bulkUserType === "Combined" ? this.combinedCapacity : null,
            enrollmentType: "All",
            plans: planRows,
          };

          await splitOfferingsJson({ reqJson: JSON.stringify(payload) });
          successCount += 1;
        } catch (e) {
          failedOfferingIds.push(selectedOfferingId);
        }
      }

      if (successCount > 0) {
        const msg = failedOfferingIds.length ? `${successCount} offerings split. ${failedOfferingIds.length} failed.` : `${successCount} offerings split successfully.`;
        this.showToast("Success", msg, failedOfferingIds.length ? "warning" : "success");
      } else {
        this.showToast("Error", "Failed to split selected offerings.", "error");
      }

      this.showBulkSplitModal = false;
      await this.handleSessionChange({ detail: { value: this.sessionId } });
    } finally {
      this.isLoading = false;
    }
  }

  handleCombinedGroupNameChange(event) {
    this.combinedGroupName = event.detail.value;
  }

  handleCombinedOfferingCountChange(event) {
    this.combinedOfferingCount = Number(event.detail.value);
  }

  handleCombinedCapacityChange(event) {
    this.combinedCapacity = Number(event.detail.value);
  }

  handleCombinedPlanSelectionChange(event) {
    const offeringId = event.currentTarget?.dataset?.offeringId;
    const selectedPlanIds = event.detail.value || [];
    if (!offeringId) {
      return;
    }
    this.bulkOfferingPlanPreview = (this.bulkOfferingPlanPreview || []).map((row) =>
      row.offeringId === offeringId
        ? {
            ...row,
            selectedPlanIds: [...selectedPlanIds],
          }
        : row,
    );
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  showError(title, error) {
    let message = "Unknown error";
    if (error && error.body && error.body.message) {
      message = error.body.message;
    } else if (error && error.message) {
      message = error.message;
    }
    this.showToast(title, message, "error");
  }

  filterBySearch(rows, rawSearch, fields) {
    const search = String(rawSearch || "")
      .trim()
      .toLowerCase();
    if (!search) {
      return [...(rows || [])];
    }
    return (rows || []).filter((row) =>
      fields.some((field) =>
        String(row?.[field] || "")
          .toLowerCase()
          .includes(search),
      ),
    );
  }

  sortRows(rows, field, direction) {
    const sorted = [...(rows || [])];
    const multiplier = direction === "desc" ? -1 : 1;
    sorted.sort((a, b) => {
      const left = this.normalizeSortValue(a?.[field]);
      const right = this.normalizeSortValue(b?.[field]);
      if (left < right) {
        return -1 * multiplier;
      }
      if (left > right) {
        return 1 * multiplier;
      }
      return 0;
    });
    return sorted;
  }

  normalizeSortValue(value) {
    if (value === null || value === undefined || value === "") {
      return "";
    }
    if (typeof value === "number") {
      return value;
    }
    const numeric = Number(value);
    if (!Number.isNaN(numeric) && String(value).trim() !== "") {
      return numeric;
    }
    return String(value).toLowerCase();
  }

  getSortLabel(field, tableName) {
    const labelsByTable = {
      create: {
        Name: "Course Offering Name",
        courseNumber: "Course Number",
        courseName: "Course Name",
        courseType: "Course Type",
      },
      view: {
        courseOfferingName: "Course Offering Name",
        courseNumber: "Course Number",
        courseName: "Course Name",
        enrollmentCapacity: "Enrollment Capacity",
        enrolleeCount: "Enrollee Count",
        courseType: "Course Type",
        offeringType: "Offering Type",
      },
    };
    return labelsByTable?.[tableName]?.[field] || field;
  }

  getSortIndicator(activeField, activeDirection, field) {
    if (activeField !== field) {
      return "";
    }
    return activeDirection === "desc" ? "↓" : "↑";
  }
}