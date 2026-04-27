import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { getRecord, getFieldDisplayValue, getFieldValue } from "lightning/uiRecordApi";
import NAME_FIELD from "@salesforce/schema/AcademicTerm.Name";
import IS_ACTIVE_FIELD from "@salesforce/schema/AcademicTerm.IsActive";
import ACADEMIC_YEAR_FIELD from "@salesforce/schema/AcademicTerm.AcademicYearId";
import ACADEMIC_YEAR_NAME_FIELD from "@salesforce/schema/AcademicTerm.AcademicYear.Name";
import SEASON_FIELD from "@salesforce/schema/AcademicTerm.Season";
import START_DATE_FIELD from "@salesforce/schema/AcademicTerm.StartDate";
import END_DATE_FIELD from "@salesforce/schema/AcademicTerm.EndDate";
import START_YEAR_FIELD from "@salesforce/schema/AcademicTerm.Start_Year__c";
import END_YEAR_FIELD from "@salesforce/schema/AcademicTerm.End_Year__c";
import getThemeColors from "@salesforce/apex/UiThemeController.getThemeColors";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { deleteRecord } from "lightning/uiRecordApi";
import LightningConfirm from "lightning/confirm";
import LightningAlert from "lightning/alert";

const TERM_FIELDS = [NAME_FIELD, IS_ACTIVE_FIELD, ACADEMIC_YEAR_FIELD, ACADEMIC_YEAR_NAME_FIELD, SEASON_FIELD, START_DATE_FIELD, END_DATE_FIELD, START_YEAR_FIELD, END_YEAR_FIELD];

export default class AcademicTermWorkspace extends NavigationMixin(LightningElement) {
  @api recordId;
  termRecord;

  @wire(getRecord, { recordId: "$recordId", fields: TERM_FIELDS })
  wiredTerm(value) {
    this.termRecord = value;
  }

  connectedCallback() {
    this.applyThemeColor();
  }

  get termName() {
    return getFieldValue(this.termRecord?.data, NAME_FIELD) || "Academic Term";
  }

  get isActive() {
    return !!getFieldValue(this.termRecord?.data, IS_ACTIVE_FIELD);
  }

  get academicYearLabel() {
    return getFieldValue(this.termRecord?.data, ACADEMIC_YEAR_NAME_FIELD) || getFieldDisplayValue(this.termRecord?.data, ACADEMIC_YEAR_FIELD) || "-";
  }

  get academicYearUrl() {
    const academicYearId = getFieldValue(this.termRecord?.data, ACADEMIC_YEAR_FIELD);
    return academicYearId ? `/${academicYearId}` : "";
  }

  get hasAcademicYear() {
    return !!this.academicYearUrl;
  }

  get seasonLabel() {
    return getFieldValue(this.termRecord?.data, SEASON_FIELD) || "-";
  }

  get startDateLabel() {
    return this.formatDate(getFieldValue(this.termRecord?.data, START_DATE_FIELD));
  }

  get endDateLabel() {
    return this.formatDate(getFieldValue(this.termRecord?.data, END_DATE_FIELD));
  }

  get startYearLabel() {
    return getFieldValue(this.termRecord?.data, START_YEAR_FIELD) || "-";
  }

  get endYearLabel() {
    return getFieldValue(this.termRecord?.data, END_YEAR_FIELD) || "-";
  }

  get statusClass() {
    return this.isActive ? "pill pill-active" : "pill pill-inactive";
  }

  get statusLabel() {
    return this.isActive ? "Active" : "Inactive";
  }

  formatDate(value) {
    if (!value) {
      return "-";
    }
    try {
      const dt = new Date(value);
      return new Intl.DateTimeFormat("en-US", {
        day: "2-digit",
        month: "short",
        year: "numeric",
      }).format(dt);
    } catch (e) {
      return value;
    }
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

  handleEditAcademicTerm() {
    if (!this.recordId) {
      return;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: this.recordId,
        objectApiName: "AcademicTerm",
        actionName: "edit",
      },
    });
  }
 showDeleteModal = false;

handleCloneAcademicTerm() {
    if (!this.recordId) return;
    this[NavigationMixin.Navigate]({
        type: "standard__recordPage",
        attributes: {
            recordId: this.recordId,
            objectApiName: "AcademicTerm",
            actionName: "clone",
        },
    });
}

handleDeleteAcademicTerm() {
    if (!this.recordId) return;
    this.showDeleteModal = true;
}

handleDeleteCancel() {
    this.showDeleteModal = false;
}

async handleDeleteConfirm() {
    this.showDeleteModal = false;
    try {
        await deleteRecord(this.recordId);
        this.dispatchEvent(new ShowToastEvent({
            title: "Success",
            message: `"${this.termName}" was deleted.`,
            variant: "success",
        }));
        this[NavigationMixin.Navigate]({
            type: "standard__objectPage",
            attributes: {
                objectApiName: "AcademicTerm",
                actionName: "list",
            },
        });
    } catch (error) {
        this.dispatchEvent(new ShowToastEvent({
            title: "Delete Failed",
            message: error?.body?.message || "An error occurred while deleting the record.",
            variant: "error",
        }));
    }
}
}