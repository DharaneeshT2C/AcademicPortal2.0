import { LightningElement, wire } from "lwc";
import getOrganizationDefaults from "@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults";
export default class MasterDataImporter extends LightningElement {
  activeTab = "account";
  isThemeLoading = true;
  renderActiveTab = true;
  refreshSequence = 0;

  tabConfig = [
    { id: "account", label: "Account Import" },
    { id: "program", label: "Program Import" },
    { id: "course", label: "Course Import" },
    { id: "user", label: "User Import" },
  ];

  @wire(getOrganizationDefaults)
  wiredOrganizationDefaults({ data, error }) {
    if (data) {
      this.applyThemeColor(data);
    } else if (error) {
      this.applyThemeColor({});
    }
    this.isThemeLoading = false;
  }

  applyThemeColor(colors) {
    const primary = colors && colors.primaryForSf ? colors.primaryForSf : colors && colors.primary ? colors.primary : "#0b5ec0";
    const secondary = colors && colors.secondaryForSf ? colors.secondaryForSf : colors && colors.secondary ? colors.secondary : "#edf4fb";
    this.template.host.style.setProperty("--theme-primary", primary);
    this.template.host.style.setProperty("--theme-secondary", secondary);
  }

  get tabs() {
    return this.tabConfig.map((tab) => ({
      ...tab,
      className: tab.id === this.activeTab ? "tab-button tab-button-active" : "tab-button",
      ariaSelected: tab.id === this.activeTab ? "true" : "false",
      tabIndex: tab.id === this.activeTab ? "0" : "-1",
    }));
  }

  get isAccountTab() {
    return this.activeTab === "account";
  }

  get isProgramTab() {
    return this.activeTab === "program";
  }

  get isCourseTab() {
    return this.activeTab === "course";
  }

  get isUserTab() {
    return this.activeTab === "user";
  }

  handleTabClick(event) {
    const tabId = event.currentTarget.dataset.tab;
    if (tabId) {
      this.activeTab = tabId;
    }
  }

  handleRefreshImport() {
    const activeTab = this.activeTab;
    const refreshSequence = this.refreshSequence + 1;
    this.refreshSequence = refreshSequence;
    this.renderActiveTab = false;
    Promise.resolve().then(() => {
      if (this.refreshSequence !== refreshSequence) {
        return;
      }
      this.activeTab = activeTab;
      this.renderActiveTab = true;
    });
  }
}