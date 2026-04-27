import { LightningElement, api, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CurrentPageReference } from "lightning/navigation";
import getActiveLearningProgramPlans from "@salesforce/apex/KenCourseOfferingSyncController.getActiveLearningProgramPlans";
import syncProgramPlansToSession from "@salesforce/apex/KenCourseOfferingSyncController.syncProgramPlansToSession";
import getThemeColors from "@salesforce/apex/UiThemeController.getThemeColors";

export default class CourseOfferingSync extends LightningElement {
  static THEME_PRIMARY_KEY = "org_theme_primary";
  static THEME_SECONDARY_KEY = "org_theme_secondary";
  static HEX_COLOR_RE = /^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i;

  @api recordId; // AcademicSession Id
  @track plans = [];
  selectedPlanIds = [];
  isLoading = false;
  isThemeLoading = true;
  isPlansLoading = true;
  resultMessage = "";
  pendingPrimary;
  pendingSecondary;

  connectedCallback() {
    this.isThemeLoading = !this.applyCachedThemeColor();
    this.loadPlans();
    this.loadThemeColors();
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

  normalizeCachedThemeColor(value) {
    const v = (value || "").trim();
    if (!v) return null;
    if (v === "undefined" || v === "null") return null;
    if (CourseOfferingSync.HEX_COLOR_RE.test(v)) return v;
    return null;
  }

  applyCachedThemeColor() {
    try {
      const cachedPrimaryRaw = window.localStorage.getItem(CourseOfferingSync.THEME_PRIMARY_KEY);
      const cachedSecondaryRaw = window.localStorage.getItem(CourseOfferingSync.THEME_SECONDARY_KEY);
      const cachedPrimary = this.normalizeCachedThemeColor(cachedPrimaryRaw);
      const cachedSecondary = this.normalizeCachedThemeColor(cachedSecondaryRaw);
      const hadAny = !!(cachedPrimary || cachedSecondary);

      if (cachedPrimary) {
        this.setThemePrimary(cachedPrimary);
      } else if (cachedPrimaryRaw) {
        window.localStorage.removeItem(CourseOfferingSync.THEME_PRIMARY_KEY);
      }
      if (cachedSecondary) {
        this.setThemeSecondary(cachedSecondary);
      } else if (cachedSecondaryRaw) {
        window.localStorage.removeItem(CourseOfferingSync.THEME_SECONDARY_KEY);
      }
      return hadAny;
    } catch {
      // ignore cache read errors
    }
    return false;
  }

  async loadThemeColors() {
    const shouldShowSkeleton = this.isThemeLoading;
    try {
      await this.applyThemeColor();
    } catch {
      // ignore theme load errors
    } finally {
      if (shouldShowSkeleton) this.isThemeLoading = false;
    }
  }

  async applyThemeColor() {
    const colors = await getThemeColors();
    if (colors && colors.primary) {
      this.setThemePrimary(colors.primary);
      window.localStorage.setItem(CourseOfferingSync.THEME_PRIMARY_KEY, colors.primary);
    }
    if (colors && colors.secondary) {
      this.setThemeSecondary(colors.secondary);
      window.localStorage.setItem(CourseOfferingSync.THEME_SECONDARY_KEY, colors.secondary);
    }
  }

  @wire(CurrentPageReference)
  getStateParameters(currentPageReference) {
    if (!currentPageReference || this.recordId) return;
    const state = currentPageReference.state || {};
    const fromState = state.c__recordId || state.recordId;
    if (fromState) {
      this.recordId = fromState;
    }
  }

  get planOptions() {
    return this.plans.map((p) => ({ label: p.name, value: p.id }));
  }

  get isSyncDisabled() {
    return this.isLoading || !this.recordId || this.selectedPlanIds.length === 0;
  }

  get isSkeletonLoading() {
    return this.isThemeLoading || this.isPlansLoading;
  }

  async loadPlans() {
    this.isPlansLoading = true;
    try {
      this.plans = await getActiveLearningProgramPlans();
    } catch (e) {
      this.showError("Failed to load Program Plans", e);
    } finally {
      this.isPlansLoading = false;
    }
  }

  handlePlanChange(event) {
    this.selectedPlanIds = event.detail.value;
  }

  async handleSync() {
    this.isLoading = true;
    this.resultMessage = "";
    console.log("Syncing with sessionId", this.recordId, "and planIds", this.selectedPlanIds);
    try {
      const result = await syncProgramPlansToSession({
        academicSessionId: this.recordId,
        planIds: this.selectedPlanIds,
      });
      this.resultMessage = `Offerings matched: ${result.offeringsMatched}. Junctions created: ${result.junctionsCreated}. Skipped: ${result.junctionsSkipped}.`;
      this.showToast("Success", "Sync completed.", "success");
    } catch (e) {
      this.showError("Sync failed", e);
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