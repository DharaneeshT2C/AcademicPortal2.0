import { LightningElement, track } from "lwc";
  import { ShowToastEvent } from "lightning/platformShowToastEvent";
  import getEligibleAccounts from "@salesforce/apex/StudentCommunityUserController.getEligibleAccounts";
  import getActiveProgramPlanOptions from "@salesforce/apex/StudentCommunityUserController.getActiveProgramPlanOptions";
  import enableUsers from "@salesforce/apex/StudentCommunityUserController.enableUsers";
  import getThemeColors from "@salesforce/apex/UiThemeController.getThemeColors";

  export default class StudentCommunityUserEnablement extends LightningElement {
    static THEME_PRIMARY_KEY = "person_enablement_theme_primary";
    static THEME_SECONDARY_KEY = "person_enablement_theme_secondary";
    static HEX_COLOR_RE = /^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i;

  allProgramPlansValue = "ALL";
  latestLoadRequestId = 0;
  pendingPrimary;
  pendingSecondary;

    @track allRows = [];
    @track selectedRowIds = [];
    @track results = [];
    @track programPlanOptions = [];

    isLoading = true;
    isLoadingProgramPlans = true;
    isThemeLoading = true;
    isSubmitting = false;
    activeRole = "Student";
    personSearchTerm = "";
    appliedSearchTerm = "";
    selectedProgramPlanId = this.allProgramPlansValue;
    pageSize = 10;
    currentPage = 1;
    pageSizeOptions = [
      { label: "10", value: "10" },
      { label: "25", value: "25" },
      { label: "50", value: "50" },
      { label: "100", value: "100" },
      { label: "All", value: "All" },
    ];

    connectedCallback() {
      this.isThemeLoading = !this.applyCachedThemeColor();
      this.loadThemeColors();
      this.loadProgramPlans();
      this.loadRows();
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

    get columns() {
      const baseColumns = [
        {
          label: `${this.activeRole} Name`,
          fieldName: "accountUrl",
          type: "url",
          typeAttributes: {
            label: { fieldName: "accountName" },
            target: "_blank",
          },
          wrapText: true,
        },
        { label: "Email", fieldName: "email", type: "email" },
        { label: "Phone", fieldName: "phone", type: "phone" },
        { label: "Role Type", fieldName: "roleType" },
      ];
      if (this.isStudentActive) {
        baseColumns.splice(3, 0, {
          label: "Program Plan",
          fieldName: "programPlanName",
          wrapText: true,
        });
      }
      return baseColumns;
    }

    get isWorking() {
      return this.isLoading || this.isSubmitting || this.isThemeLoading;
    }

  get hasRows() {
    return this.filteredRows.length > 0;
  }

    get hasResults() {
      return this.results.length > 0;
    }

  get totalCount() {
    return this.filteredRows.length;
  }

    get totalLabel() {
      return `Total ${this.activeRole}`;
    }

  get readyCount() {
    return this.filteredRows.filter((row) => row.canEnable).length;
  }

    get selectedCount() {
      return this.selectedRowIds.length;
    }

  get disabledRowIds() {
    return this.filteredRows
      .filter((row) => !row.canEnable)
      .map((row) => row.accountId);
  }

    get isSubmitDisabled() {
      return this.isWorking || this.selectedRowIds.length === 0;
    }

    get isSearchDisabled() {
      return this.isWorking;
    }

    get isStudentActive() {
      return this.activeRole === "Student";
    }

    get isFacultyActive() {
      return this.activeRole === "Faculty";
    }

    get studentTabClass() {
      return this.isStudentActive ? "role-tab role-tab-active" : "role-tab";
    }

    get facultyTabClass() {
      return this.isFacultyActive ? "role-tab role-tab-active" : "role-tab";
    }

    get pageTitle() {
      return "Person Account Community Access";
    }

    get pageSubtitle() {
      return "Review eligible student and faculty person accounts, search instantly, and provision Experience Cloud access from one workspace.";
    }

    get searchPlaceholder() {
      return `Search ${this.activeRole.toLowerCase()} name or email`;
    }

    get emptyStateMessage() {
      return `No ${this.activeRole} Person Accounts are ready for review.`;
    }

    get programPlanPlaceholder() {
      return this.isLoadingProgramPlans
        ? "Loading program plans"
        : "All active program plans";
    }

    get showProgramPlanFilter() {
      return this.isStudentActive;
    }

    get searchControlsClass() {
      return this.isStudentActive
        ? "search-controls search-controls-student"
        : "search-controls search-controls-faculty";
    }

    get isSkeletonLoading() {
      return this.isThemeLoading || this.isLoadingProgramPlans || this.isLoading;
    }

  get pageSizeValue() {
    return this.pageSize === "All" ? "All" : String(this.pageSize);
  }

  get normalizedAppliedSearchTerm() {
    return (this.appliedSearchTerm || "").trim().toLowerCase();
  }

  get filteredRows() {
    const searchTerm = this.normalizedAppliedSearchTerm;
    if (!searchTerm) {
      return this.allRows;
    }
    return this.allRows.filter((row) => {
      const accountName = (row.accountName || "").toLowerCase();
      const email = (row.email || "").toLowerCase();
      return accountName.includes(searchTerm) || email.includes(searchTerm);
    });
  }

  getSearchInputValue(event) {
    if (event?.target?.value !== undefined) {
      return event.target.value || "";
    }
    if (event?.detail?.value !== undefined) {
      return event.detail.value || "";
    }
    const searchInput = this.template.querySelector(
      '[data-id="nameEmailSearch"]',
    );
    return searchInput?.value || "";
  }

  applySearchTerm(searchTerm) {
    this.personSearchTerm = searchTerm || "";
    this.appliedSearchTerm = this.personSearchTerm;
    this.currentPage = 1;
  }

  get pagedRows() {
    if (this.pageSize === "All") {
      return this.filteredRows;
    }
    const startIndex = (this.currentPage - 1) * this.pageSize;
    return this.filteredRows.slice(startIndex, startIndex + this.pageSize);
  }

    get totalPages() {
      if (this.pageSize === "All") {
        return 1;
      }
      return Math.max(1, Math.ceil(this.totalCount / this.pageSize));
    }

    get pageSummary() {
      if (!this.totalCount) {
        return "Showing 0 of 0";
      }
      const endCount =
        this.pageSize === "All"
          ? this.totalCount
          : Math.min(this.currentPage * this.pageSize, this.totalCount);
      return `Showing ${endCount} of ${this.totalCount}`;
    }

    get pageLabel() {
      return `Page ${this.currentPage} of ${this.totalPages}`;
    }

    get isPreviousDisabled() {
      return this.currentPage <= 1 || this.isWorking;
    }

    get isNextDisabled() {
      return this.currentPage >= this.totalPages || this.isWorking;
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
      if (!v || v === "undefined" || v === "null") return null;
      return StudentCommunityUserEnablement.HEX_COLOR_RE.test(v) ? v : null;
    }

    applyCachedThemeColor() {
      try {
        const cachedPrimary = this.normalizeCachedThemeColor(
          window.localStorage.getItem(StudentCommunityUserEnablement.THEME_PRIMARY_KEY),
        );
        const cachedSecondary = this.normalizeCachedThemeColor(
          window.localStorage.getItem(StudentCommunityUserEnablement.THEME_SECONDARY_KEY),
        );
        if (cachedPrimary) {
          this.setThemePrimary(cachedPrimary);
        }
        if (cachedSecondary) {
          this.setThemeSecondary(cachedSecondary);
        }
        return !!(cachedPrimary || cachedSecondary);
      } catch {
        return false;
      }
    }

    async loadThemeColors() {
      try {
        const colors = await getThemeColors();
        if (colors?.primary) {
          this.setThemePrimary(colors.primary);
          window.localStorage.setItem(
            StudentCommunityUserEnablement.THEME_PRIMARY_KEY,
            colors.primary,
          );
        }
        if (colors?.secondary) {
          this.setThemeSecondary(colors.secondary);
          window.localStorage.setItem(
            StudentCommunityUserEnablement.THEME_SECONDARY_KEY,
            colors.secondary,
          );
        }
      } catch {
        // ignore theme load errors
      } finally {
        this.isThemeLoading = false;
      }
    }

    async loadProgramPlans() {
      this.isLoadingProgramPlans = true;
      try {
        const options = await getActiveProgramPlanOptions();
        this.programPlanOptions = [
          { label: "All Active Program Plans", value: this.allProgramPlansValue },
          ...(options || []),
        ];
      } catch (error) {
        this.programPlanOptions = [
          { label: "All Active Program Plans", value: this.allProgramPlansValue },
        ];
        this.showToast(
          "Error",
          this.getErrorMessage(error, "Failed to load program plans."),
          "error",
        );
      } finally {
        this.isLoadingProgramPlans = false;
      }
    }

  async loadRows(options = {}) {
    const requestId = ++this.latestLoadRequestId;
    this.isLoading = true;
    if (!options.preserveResults) {
      this.results = [];
    }
    try {
      const data = await getEligibleAccounts({
        roleType: this.activeRole,
        searchTerm: this.normalizedAppliedSearchTerm || null,
        programPlanId: this.isStudentActive
            ? this.selectedProgramPlanId === this.allProgramPlansValue
              ? null
              : this.selectedProgramPlanId
            : null,
      });
      if (requestId !== this.latestLoadRequestId) {
        return;
      }
      this.allRows = (data || []).map((row) => ({
        ...row,
        accountUrl: `/lightning/r/Account/${row.accountId}/view`,
      }));
      this.currentPage = 1;
      this.selectedRowIds = [];
    } catch (error) {
      if (requestId !== this.latestLoadRequestId) {
        return;
      }
      this.allRows = [];
      this.showToast(
        "Error",
        this.getErrorMessage(error, `Failed to load ${this.activeRole.toLowerCase()} records.`),
        "error",
      );
    } finally {
      if (requestId === this.latestLoadRequestId) {
        this.isLoading = false;
      }
    }
  }

  async handleRoleTabClick(event) {
    const nextRole = event.currentTarget.dataset.role;
    if (!nextRole || nextRole === this.activeRole || this.isWorking) {
      return;
    }
    this.activeRole = nextRole;
    this.appliedSearchTerm = this.personSearchTerm;
    if (this.activeRole === "Faculty") {
      this.selectedProgramPlanId = this.allProgramPlansValue;
    }
      this.selectedRowIds = [];
      await this.loadRows();
    }

    handleRowSelection(event) {
      const currentPageIds = this.pagedRows.map((row) => row.accountId);
      const currentSelections = (event.detail.selectedRows || [])
        .filter((row) => row.canEnable)
        .map((row) => row.accountId);
      const preservedSelections = this.selectedRowIds.filter(
        (rowId) => !currentPageIds.includes(rowId),
      );
      this.selectedRowIds = [...preservedSelections, ...currentSelections];
    }

    async handleRefresh() {
      await this.loadRows();
    }

  handlePersonSearchTermChange(event) {
    this.personSearchTerm = this.getSearchInputValue(event);
  }

    async handleProgramPlanChange(event) {
      if (!this.isStudentActive) {
        return;
      }
      this.selectedProgramPlanId = event.detail.value || "";
      this.appliedSearchTerm = this.personSearchTerm;
      this.currentPage = 1;
      await this.loadRows();
    }

    async handleSearchKeydown(event) {
      if (event.key === "Enter") {
        event.preventDefault();
        await this.handleSearch(event);
      }
    }

  async handleSearch(event) {
    this.applySearchTerm(this.getSearchInputValue(event));
    await this.loadRows();
    }

  pruneSelectionsToFilteredRows() {
    const visibleRowIds = new Set(this.filteredRows.map((row) => row.accountId));
    this.selectedRowIds = this.selectedRowIds.filter((rowId) =>
      visibleRowIds.has(rowId),
    );
  }

    async handleClearSearch() {
      this.personSearchTerm = "";
      this.appliedSearchTerm = "";
      this.selectedProgramPlanId = this.allProgramPlansValue;
      this.currentPage = 1;
      await this.loadRows();
    }

    async handleSubmit() {
      if (this.selectedRowIds.length === 0) {
        this.showToast(
          "Select Records",
          `Select at least one ${this.activeRole.toLowerCase()} record.`,
          "warning",
        );
        return;
      }

      this.isSubmitting = true;
      this.results = [];
      try {
        const response = await enableUsers({
          accountIds: this.selectedRowIds,
          roleType: this.activeRole,
        });
        this.results = (response || []).map((result) => ({
          ...result,
          key: `${result.accountId}-${result.userId || "no-user"}`,
          cssClass: result.success
            ? "result-row result-success"
            : "result-row result-error",
          iconName: result.success ? "utility:success" : "utility:error",
          iconAlt: result.success ? "Success" : "Error",
        }));

        const successCount = this.results.filter(
          (result) => result.success,
        ).length;
        const errorCount = this.results.length - successCount;
        this.showToast(
          `${this.activeRole} Users Processed`,
          `${successCount} created, ${errorCount} skipped or failed.`,
          errorCount > 0 ? "warning" : "success",
        );
        await this.loadRows({ preserveResults: true });
      } catch (error) {
        this.showToast(
          "Error",
          this.getErrorMessage(error, `Failed to create ${this.activeRole.toLowerCase()} users.`),
          "error",
        );
      } finally {
        this.isSubmitting = false;
      }
    }

    getErrorMessage(error, fallback) {
      if (Array.isArray(error?.body)) {
        return error.body.map((item) => item.message).join(", ");
      }
      return error?.body?.message || error?.message || fallback;
    }

    showToast(title, message, variant) {
      this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handlePageSizeChange(event) {
      const nextValue = event.detail.value;
      this.pageSize = nextValue === "All" ? "All" : Number(nextValue);
      this.currentPage = 1;
    }

    handlePreviousPage() {
      if (this.currentPage > 1) {
        this.currentPage -= 1;
      }
    }

    handleNextPage() {
      if (this.currentPage < this.totalPages) {
        this.currentPage += 1;
      }
    }
  }