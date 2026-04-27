import { LightningElement, wire } from "lwc";
import getOrganizationDefaults from "@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults";
export default class HistoricalDataImporter extends LightningElement {
  activeTab = "courseOffering";
  isThemeLoading = true;
  renderActiveTab = true;

  tabConfig = [
    { id: "courseOffering", label: "Course Offering Import" },
    { id: "participant", label: "Participant Import" },
    { id: "examCourseResult", label: "Exam Course Result Upload" },
    { id: "examTermResult", label: "Exam Term Result Upload" },
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

  get isCourseOfferingTab() {
    return this.activeTab === "courseOffering";
  }

  get isParticipantTab() {
    return this.activeTab === "participant";
  }

  get isExamCourseResultTab() {
    return this.activeTab === "examCourseResult";
  }

  get isExamTermResultTab() {
    return this.activeTab === "examTermResult";
  }

  handleTabClick(event) {
    const tabId = event.currentTarget.dataset.tab;
    if (tabId) {
      this.activeTab = tabId;
    }
  }

  handleRefreshImport() {
    const activeTab = this.activeTab;
    this.renderActiveTab = false;
    window.clearTimeout(this.refreshHandle);
    this.refreshHandle = window.setTimeout(() => {
      this.activeTab = activeTab;
      this.renderActiveTab = true;
    }, 0);
  }
}