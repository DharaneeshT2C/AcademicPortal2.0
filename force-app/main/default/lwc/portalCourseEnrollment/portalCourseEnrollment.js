import { LightningElement, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getAcademicSessionsForUser from "@salesforce/apex/KenPortalCourseEnrollmentController.getAcademicSessionsForUser";
import OrganizationDefaultsApiController from "@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults";
import rightArrow from '@salesforce/resourceUrl/RightArrow';

export default class PortalCourseEnrollment extends NavigationMixin(LightningElement) {
  @track rows = [];
  @track errorMessage = "";
  showPathwayBanner = true;
  loading = true;
  themeLoading = true;
  translationAttrsApplied = false;
  organizationDefaults = {};

  constructor() {
    super();
    if (typeof document !== "undefined") {
      document.documentElement.setAttribute("translate", "no");
      document.documentElement.setAttribute("lang", "en");
      document.documentElement.classList.add("notranslate");
    }
  }

  renderedCallback() {
    if (this.translationAttrsApplied || !this.template?.host) {
      return;
    }

    this.template.host.setAttribute("lang", "en");
    this.template.host.setAttribute("translate", "no");
    this.template.host.classList.add("notranslate");
    this.translationAttrsApplied = true;
  }

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
      console.log("Organization Defaults loaded", this.organizationDefaults);
      this.applyOrganizationTheme();
      this.themeLoading = false;
    } else if (error) {
      console.error("Organization Defaults load error", error);
      this.organizationDefaults = {};
      this.themeLoading = false;
    }
  }

  get showSkeleton() {
    return this.loading || this.themeLoading;
  }

  @wire(getAcademicSessionsForUser)
  wiredSessions({ data, error }) {
    if (!data && !error) {
      return;
    }

    if (data) {
      this.errorMessage = "";
      this.rows = data.map((s) => ({
        id: s.academicSessionId,
        academicSessionId: s.academicSessionId,
        semesterLabel: s.termLabel,
        termNumber: s.termNumber,
        academicSessionName: s.academicSessionName || "-",
        season: s.season || "-",
        registrationStatus: this.normalizeStatus(s.registrationStatus),
        registrationStartDate: s.registrationStartDate || null,
        registrationEndDate: s.registrationEndDate || null,
        majorCreditsEarned: s.majorCreditsEarned ?? s.majorCreditsCompleted ?? s.earnedMajorCredits ?? null,
        majorCreditsTotal: s.majorCreditsTotal ?? s.totalMajorCredits ?? s.majorCredits ?? null,
        minorCreditsEarned: s.minorCreditsEarned ?? s.minorCreditsCompleted ?? s.earnedMinorCredits ?? null,
        minorCreditsTotal: s.minorCreditsTotal ?? s.totalMinorCredits ?? s.minorCredits ?? null,
        isProgramCompleted: s.isProgramCompleted === true,
      }));
      this.loading = false;
    } else if (error) {
      // eslint-disable-next-line no-console
      console.error("Portal Course Enrollment load error", error);
      this.errorMessage = error?.body?.message || error?.message || "Failed to load academic sessions.";
      this.rows = [];
      this.loading = false;
    }
  }

  get displayCards() {
    if (!this.rows.length) {
      return [];
    }

    const sortedRows = [...this.rows].sort((a, b) => Number(a.termNumber || 0) - Number(b.termNumber || 0));

    return sortedRows.map((row) => {
      const termNumber = Number(row.termNumber || 0);
      const status = this.normalizeStatus(row.registrationStatus);
      const isOngoing = status === "ongoing";
      const isCompleted = status === "completed";
      const canViewDetails = row.isProgramCompleted && isOngoing;
      const isActionable = isOngoing;
      const actionLabel = isOngoing ? (row.isProgramCompleted ? "View Details" : "Get Started") : isCompleted ? "Completed" : "Upcoming";

      return {
        id: row.id,
        title: row.semesterLabel || `Semester ${termNumber}`,
        termNumber,
        academicSessionId: row.academicSessionId,
        majorCreditsText: this.formatCredits(row.majorCreditsEarned, row.majorCreditsTotal),
        minorCreditsText: this.formatCredits(row.minorCreditsEarned, row.minorCreditsTotal),
        startDateText: this.formatDateTime(row.registrationStartDate),
        endDateText: this.formatDateTime(row.registrationEndDate),
        showBadge: true,
        badgeLabel: isOngoing ? "Ongoing" : isCompleted ? "Approved" : "Upcoming",
        badgeClass: isOngoing ? "status-badge status-ongoing" : isCompleted ? "status-badge status-completed" : "status-badge status-upcoming",
        actionLabel,
        actionClass: isActionable ? "card-action action-primary action-dominant" : "card-action action-muted",
        cardClass: isActionable ? "semester-card semester-card-active semester-card-interactive" : "semester-card",
        isActionable,
        targetPath: isActionable ? (canViewDetails ? "/courseafterenrollment" : "/courseenrollmentdetails") : "",
      };
    });
  }

    get rightArrowUrl() {
        return rightArrow;
    }

  get completedSemesterCount() {
    return this.rows.filter((row) => this.normalizeStatus(row.registrationStatus) === "completed").length;
  }

  get totalSemesterCount() {
    return this.rows.length;
  }

  get completionTrackerText() {
    return `${this.completedSemesterCount}/${this.totalSemesterCount} semesters completed`;
  }

  get semesterSectionStyle() {
    return this.showPathwayBanner ? "" : "height: calc(100vh - 152px);";
  }

  normalizeStatus(rawStatus) {
    const status = String(rawStatus || "upcoming")
      .trim()
      .toLowerCase();
    if (status === "ongoing" || status === "in progress") {
      return "ongoing";
    }
    if (status === "completed" || status === "closed") {
      return "completed";
    }
    return "upcoming";
  }

  formatDateTime(value) {
    if (!value) {
      return "-";
    }

    try {
      return new Intl.DateTimeFormat("en-US", {
        day: "2-digit",
        month: "short",
        year: "numeric",
      }).format(new Date(value));
    } catch (e) {
      return value;
    }
  }

  formatCredits(earned, total) {
    const hasEarned = earned !== null && earned !== undefined && String(earned).trim() !== "";
    const hasTotal = total !== null && total !== undefined && String(total).trim() !== "";

    if (!hasEarned && !hasTotal) {
      return "Not available";
    }

    const earnedText = hasEarned ? this.formatCreditPart(earned, true) : "TBD";
    const totalText = hasTotal ? this.formatCreditPart(total, false) : "TBD";

    return `${earnedText}/${totalText}`;
  }

  formatCreditPart(value, shouldPad) {
    const numeric = Number(value);
    if (!Number.isNaN(numeric) && Number.isFinite(numeric)) {
      const intValue = Math.trunc(numeric);
      if (shouldPad && intValue >= 0 && intValue < 10) {
        return `0${intValue}`;
      }
      return String(intValue);
    }
    return String(value).trim() || "--";
  }

  handleEnroll(event) {
    const isActionable = (event.currentTarget.dataset.actionable || "").toLowerCase() !== "false";
    if (!isActionable) {
      return;
    }
    const explicitTargetPath = event.currentTarget.dataset.target || "/courseenrollmentdetails";
    const semesterNumber = Number(event.currentTarget.dataset.term || 0);
    const academicSessionId = event.currentTarget.dataset.session || "";
    const path = window.location.pathname || "";
    const sitePrefixMatch = path.match(/^(.*?\/s)(?:\/|$)/);
    const sitePrefix = sitePrefixMatch ? sitePrefixMatch[1] : "";
    const targetPath = explicitTargetPath.startsWith("/") ? explicitTargetPath : `/${explicitTargetPath}`;
    const queryParts = [];
    if (!Number.isNaN(semesterNumber) && semesterNumber > 0) {
      queryParts.push(`semester=${encodeURIComponent(String(semesterNumber))}`);
    }
    if (academicSessionId) {
      queryParts.push(`academicSessionId=${encodeURIComponent(academicSessionId)}`);
    }
    const queryString = queryParts.length ? `?${queryParts.join("&")}` : "";
    const targetUrl = sitePrefix ? `${sitePrefix}${targetPath}${queryString}` : `${targetPath}${queryString}`;

    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: {
        url: targetUrl,
      },
    });
  }
}