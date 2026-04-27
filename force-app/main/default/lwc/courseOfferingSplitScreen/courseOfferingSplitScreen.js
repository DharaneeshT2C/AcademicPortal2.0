import { LightningElement, api, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CurrentPageReference } from "lightning/navigation";
import getAcademicTerms from "@salesforce/apex/KenCourseOfferingSplitController.getAcademicTerms";
import getAcademicSessionsByTerm from "@salesforce/apex/KenCourseOfferingSplitController.getAcademicSessionsByTerm";
import getPlaceholderOfferings from "@salesforce/apex/KenCourseOfferingSplitController.getPlaceholderOfferings";
import getProgramPlansForOffering from "@salesforce/apex/KenCourseOfferingSplitController.getProgramPlansForOffering";
import getSectionsByProgramPlan from "@salesforce/apex/KenCourseOfferingSplitController.getSectionsByProgramPlan";
import getEnrollmentTypesForOffering from "@salesforce/apex/KenCourseOfferingSplitController.getEnrollmentTypesForOffering";
import splitOfferingsJson from "@salesforce/apex/KenCourseOfferingSplitController.splitOfferingsJson";
import getActivePlannedOfferings from "@salesforce/apex/KenCourseOfferingSplitController.getActivePlannedOfferings";
import getCourseOfferingParticipants from "@salesforce/apex/KenCourseOfferingSplitController.getCourseOfferingParticipants";
import getThemeColors from "@salesforce/apex/UiThemeController.getThemeColors";

export default class CourseOfferingSplitScreen extends LightningElement {
  _recordId;
  _academicTermId;
  @track terms = [];
  @track sessions = [];
  @track offerings = [];
  @track plans = [];
  @track allPlans = [];
  @track viewSessions = [];
  @track viewOfferings = [];

  termId;
  sessionId;
  offeringId;
  viewTermId;
  viewSessionId;
  viewEnrollmentType = "All";

  userType = "";
  enrollmentType = "";
  bulkCourseType = "All";
  combinedGroupName = "";
  combinedOfferingCount = 1;
  combinedCapacity = null;
  combinedPlanIds = [];
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

  userTypeOptions = [
    { label: "Individual", value: "Individual" },
    { label: "Section", value: "Section" },
    { label: "Combined", value: "Combined" },
  ];
  bulkUserTypeOptions = [
    { label: "Individual", value: "Individual" },
    { label: "Section", value: "Section" },
  ];

  enrollmentTypeOptions = [];

  viewEnrollmentTypeOptions = [
    { label: "All", value: "All" },
    { label: "Core", value: "Core" },
    { label: "Elective", value: "Elective" },
  ];

  connectedCallback() {
    this.loadTerms();
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

  get termOptions() {
    return this.terms.map((t) => ({ label: t.Name, value: t.Id }));
  }

  get sessionOptions() {
    return this.sessions.map((s) => ({ label: s.Name, value: s.Id }));
  }

  get viewSessionOptions() {
    return this.viewSessions.map((s) => ({ label: s.Name, value: s.Id }));
  }

  get offeringOptions() {
    return [{ label: "Select Course Offering", value: "" }].concat(
      this.filteredOfferingsByEnrollmentType.map((o) => ({ label: o.Name, value: o.Id })),
    );
  }

  get hasOfferings() {
    return this.offerings.length > 0;
  }

  get showSessionOfferingsSection() {
    return this.hasOfferings && !this.isPlaceholderSelected;
  }

  get selectedOfferingsCount() {
    return this.selectedOfferingIds.length;
  }

  get showBulkSelectionWidget() {
    return !this.offeringId;
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
    if (!this.showBulkSelectionWidget) {
      return this.offerings;
    }
    let rows = this.filteredOfferingsByEnrollmentType;
    if (!this.bulkCourseType || this.bulkCourseType === "All") {
      return rows;
    }
    const target = this.bulkCourseType.toLowerCase();
    rows = (rows || []).filter((o) =>
      String(o.courseType || "")
        .toLowerCase()
        .split(",")
        .map((v) => v.trim())
        .includes(target),
    );
    return rows;
  }

  get filteredOfferingsByEnrollmentType() {
    if (!this.enrollmentType || this.enrollmentType === "All") {
      return this.offerings || [];
    }
    const target = String(this.enrollmentType).toLowerCase();
    return (this.offerings || []).filter((o) =>
      String(o.enrollmentType || "")
        .toLowerCase()
        .split(",")
        .map((v) => v.trim())
        .includes(target),
    );
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

  get isBulkSplitDisabled() {
    if (this.isLoading || !this.bulkUserType) {
      return true;
    }
    if (this.bulkUserType === "Combined") {
      return true;
    }
    if (this.isBulkIndividualMode && (!this.bulkOfferingCount || this.bulkOfferingCount < 1)) {
      return true;
    }
    if (this.isBulkSectionMode && (!this.bulkSections || this.bulkSections < 1)) {
      return true;
    }
    return false;
  }

  get hasBulkOfferingPlanPreview() {
    return this.bulkOfferingPlanPreview && this.bulkOfferingPlanPreview.length > 0;
  }

  get showNoOfferingsMessage() {
    return !!this.sessionId && !this.hasOfferings;
  }

  get isSessionDisabled() {
    return !this.termId;
  }

  get isTermLocked() {
    return !!this.contextTermId;
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

  get isOfferingDisabled() {
    return !this.sessionId;
  }

  get isCombinedMode() {
    return this.userType === "Combined";
  }

  get showSectionsColumn() {
    return this.userType === "Section";
  }

  get showCapacityColumn() {
    return this.userType !== "Combined";
  }

  get showOfferingCountColumn() {
    return this.userType === "Individual";
  }

  get disablePlanInputs() {
    return this.userType === "Combined";
  }

  get combinedSelectedCount() {
    return this.combinedPlanIds.length;
  }

  get isCreateDisabled() {
    if (!this.offeringId || this.plans.length === 0 || this.isLoading) {
      return true;
    }
    if (this.userType === "Section") {
      return this.plans.some((p) => !Array.isArray(p.selectedSections) || p.selectedSections.length === 0 || !p.capacity || p.capacity < 1);
    }
    return false;
  }

  get combinedPlanOptions() {
    return this.plans.map((p) => ({ label: p.planName, value: p.planId }));
  }

  async loadTerms() {
    try {
      this.terms = await getAcademicTerms();
    } catch (e) {
      this.showError("Failed to load Academic Terms", e);
    }
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
    this.offeringId = null;
    this.sessions = [];
    this.offerings = [];
    this.plans = [];
    this.allPlans = [];
    this.enrollmentTypeOptions = [];
    this.enrollmentType = "";

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

  async handleTermChange(event) {
    if (this.isTermLocked) {
      return;
    }
    this.termId = event.detail.value;
    await this.loadSessionsForCreate();
  }

  async handleViewTermChange(event) {
    if (this.isTermLocked) {
      return;
    }
    this.viewTermId = event.detail.value;
    await this.loadSessionsAndOfferingsForView();
  }

  async handleViewSessionChange(event) {
    this.viewSessionId = event.detail.value;
    this.viewOfferings = [];
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
    this.offeringId = null;
    this.isPlaceholderSelected = false;
    this.offerings = [];
    this.selectedOfferingIds = [];
    this.plans = [];
    this.allPlans = [];
    this.enrollmentTypeOptions = [];
    this.enrollmentType = "All";
    this.bulkCourseType = "All";
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
          recordUrl: (o.Id || o.id) ? `/${o.Id || o.id}` : "",
          isSelected: false,
        }));
        this.setEnrollmentTypeOptionsFromOfferings();
      } catch (e) {
        this.showError("Failed to load Course Offerings", e);
      }
    }
  }

  setEnrollmentTypeOptionsFromOfferings() {
    const values = new Set();
    (this.offerings || []).forEach((o) => {
      const raw = o && o.enrollmentType ? String(o.enrollmentType) : "";
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
    this.enrollmentTypeOptions = options;
    if (!this.enrollmentType) {
      this.enrollmentType = "All";
    }
  }

  handleBulkCourseTypeChange(event) {
    this.bulkCourseType = event.detail.value;
  }

  async handleOfferingChange(event) {
    this.offeringId = event.detail.value || null;
    this.isPlaceholderSelected = !!this.offeringId;
    this.selectedOfferingIds = [];
    this.offerings = this.offerings.map((o) => ({ ...o, isSelected: false }));
    await this.loadPlansForOffering(this.offeringId);
    await this.loadEnrollmentTypesForOffering(this.offeringId);
  }

  async handleSelectOfferingFromList(event) {
    const selectedId = event.currentTarget?.dataset?.id;
    if (!selectedId) {
      return;
    }
    this.offeringId = selectedId;
    this.isPlaceholderSelected = true;
    this.selectedOfferingIds = [];
    this.offerings = this.offerings.map((o) => ({ ...o, isSelected: false }));
    await this.loadPlansForOffering(this.offeringId);
    await this.loadEnrollmentTypesForOffering(this.offeringId);
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
            };
          } catch (e) {
            return {
              offeringId: selectedOfferingId,
              offeringName: nameById.get(selectedOfferingId) || selectedOfferingId,
              plans: [],
              planCount: 0,
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
    if (this.bulkUserType === "Combined") {
      this.showToast("Error", "Combined type is not supported for bulk split.", "error");
      return;
    }

    this.isLoading = true;
    let successCount = 0;
    const failedOfferingIds = [];
    try {
      for (const selectedOfferingId of this.selectedOfferingIds) {
        try {
          const data = await getProgramPlansForOffering({ courseOfferingId: selectedOfferingId });
          const planRows = (data || []).map((p) => ({
            planId: p.id,
            planName: p.name,
            enrollmentType: p.enrollmentType,
            type: this.bulkUserType,
            sections: this.bulkUserType === "Section" ? this.bulkSections : 1,
            selectedSections: [],
            offeringCount: this.bulkUserType === "Individual" ? this.bulkOfferingCount : null,
            capacity: this.bulkCapacity,
          }));

          const payload = {
            placeholderOfferingId: selectedOfferingId,
            combinedGroupName: "",
            combinedOfferingCount: null,
            combinedCapacity: null,
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

  async loadEnrollmentTypesForOffering(offeringId) {
    this.enrollmentTypeOptions = [];
    this.enrollmentType = "";
    if (!offeringId) {
      this.setEnrollmentTypeOptionsFromOfferings();
      return;
    }
    try {
      const types = await getEnrollmentTypesForOffering({ courseOfferingId: offeringId });
      const list = (types || []).map((t) => String(t)).filter((t) => t);
      const optionList = list.map((t) => ({ label: t, value: t }));
      this.enrollmentTypeOptions = [{ label: "All", value: "All" }].concat(optionList);
      this.enrollmentType = "All";
      this.applyEnrollmentTypeFilter();
    } catch (e) {
      this.enrollmentTypeOptions = [];
    }
  }

  async loadPlansForOffering(offeringId) {
    this.plans = [];
    this.allPlans = [];
    this.combinedPlanIds = [];
    if (!offeringId) return;
    try {
      const data = await getProgramPlansForOffering({ courseOfferingId: offeringId });
      const planRows = await Promise.all(
        (data || []).map(async (p) => {
          let sections = [];
          try {
            sections = await getSectionsByProgramPlan({ learningProgramPlanId: p.id });
          } catch (e) {
            sections = [];
          }
          return {
            planId: p.id,
            planName: p.name,
            enrollmentType: p.enrollmentType,
            offeringCount: 1,
            sections: 1,
            selectedSections: [],
            sectionOptions: (sections || []).map((value) => ({
              label: value,
              value,
            })),
            capacity: null,
          };
        }),
      );
      this.allPlans = planRows;
      this.applyEnrollmentTypeFilter();
    } catch (e) {
      this.showError("Failed to load Program Plans", e);
    }
  }

  handleUserTypeChange(event) {
    this.userType = event.detail.value;
    if (this.userType !== "Combined") {
      this.combinedPlanIds = [];
    }
  }

  handleEnrollmentTypeChange(event) {
    this.enrollmentType = event.detail.value;
    this.applyEnrollmentTypeFilter();
  }

  applyEnrollmentTypeFilter() {
    if (!this.allPlans || this.allPlans.length === 0) {
      this.plans = [];
      return;
    }
    if (!this.enrollmentType || this.enrollmentType === "All") {
      this.plans = this.allPlans.map((p) => ({ ...p }));
      return;
    }
    const target = String(this.enrollmentType).toLowerCase();
    this.plans = this.allPlans.filter((p) => String(p.enrollmentType || "").toLowerCase() === target).map((p) => ({ ...p }));
    if (!this.combinedPlanIds || this.combinedPlanIds.length === 0) {
      return;
    }
    const visiblePlanIds = new Set(this.plans.map((p) => p.planId));
    this.combinedPlanIds = this.combinedPlanIds.filter((id) => visiblePlanIds.has(id));
  }

  handlePlanSectionsChange(event) {
    const index = Number(event.currentTarget.dataset.index);
    const value = Array.isArray(event.detail.value) ? event.detail.value : [];
    this.updatePlanAtIndex(index, {
      selectedSections: value,
      sections: value.length || 1,
    });
  }

  handlePlanCapacityChange(event) {
    const index = Number(event.currentTarget.dataset.index);
    const value = Number(event.detail.value);
    this.updatePlanAtIndex(index, { capacity: value });
  }

  handlePlanOfferingCountChange(event) {
    const index = Number(event.currentTarget.dataset.index);
    const value = Number(event.detail.value);
    this.updatePlanAtIndex(index, { offeringCount: value });
  }

  updatePlanAtIndex(index, changes) {
    if (Number.isNaN(index) || index < 0 || index >= this.plans.length) {
      return;
    }
    const currentPlan = this.plans[index];
    const planId = currentPlan?.planId;
    if (!planId) {
      return;
    }
    this.allPlans = (this.allPlans || []).map((plan) => (plan.planId === planId ? { ...plan, ...changes } : plan));
    this.plans = this.plans.map((plan, planIndex) => (planIndex === index ? { ...plan, ...changes } : plan));
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
    this.combinedPlanIds = event.detail.value;
  }

  async handleCreateOfferings() {
    this.isLoading = true;
    try {
      const offeringValue = this.offeringId ||
        this.template.querySelector('lightning-combobox[label="Default Course Offering"]')?.value;
      this.offeringId = offeringValue;
      if (!this.offeringId) {
        this.showToast("Error", "Please select a default course offering.", "error");
        return;
      }
      const payload = {
        placeholderOfferingId: this.offeringId,
        combinedGroupName: this.combinedGroupName,
        combinedOfferingCount: this.combinedOfferingCount,
        combinedCapacity: this.combinedCapacity,
        enrollmentType: this.enrollmentType,
        plans: this.plans.map((p) => ({
          planId: p.planId,
          planName: p.planName,
          enrollmentType: p.enrollmentType,
          type: this.userType === "Combined" ? (this.combinedPlanIds.includes(p.planId) ? "Combined" : "Individual") : this.userType,
          sections: this.userType === "Section" ? (Array.isArray(p.selectedSections) && p.selectedSections.length ? p.selectedSections.length : p.sections) : 1,
          selectedSections: this.userType === "Section" ? p.selectedSections : [],
          offeringCount: this.userType === "Individual" ? p.offeringCount : null,
          capacity: p.capacity,
        })),
      };
      await splitOfferingsJson({ reqJson: JSON.stringify(payload) });
      this.showToast("Success", "Offerings created successfully.", "success");
      this.handleSessionChange({ detail: { value: this.sessionId } });
    } catch (e) {
      this.showError("Failed to create offerings", e);
    } finally {
      this.isLoading = false;
    }
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
}