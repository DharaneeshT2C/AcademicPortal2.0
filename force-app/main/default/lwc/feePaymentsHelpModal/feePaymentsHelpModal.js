import { api, LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class FeePaymentsHelpModal extends LightningElement {
  @api defaultIssueType = "Fee Payment";

  description = "";
  issueType = "";
  subject = "";
  fileName = "";

  connectedCallback() {
    this.issueType = this.defaultIssueType || "Fee Payment";
  }

  get issueOptions() {
    return ["Fee Payment", "Fee Plan", "Invoices", "Transaction History", "Refunds"];
  }

  handleFieldChange(event) {
    const { name, value } = event.target;
    this[name] = value;
  }

  handleFileSelect(event) {
    const file = event.target.files && event.target.files[0];
    this.fileName = file ? file.name : "";
  }

  handleAutoCreate() {
    if (!this.description) {
      return;
    }
    this.subject = this.description.trim().slice(0, 80);
  }

  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }

  handleSubmit() {
    if (!this.issueType || !this.subject.trim()) {
      this.dispatchEvent(new ShowToastEvent({ title: "Missing details", message: "Issue type and issue subject are required.", variant: "error" }));
      return;
    }
    this.dispatchEvent(
      new CustomEvent("submithelp", {
        detail: {
          description: this.description,
          issueType: this.issueType,
          subject: this.subject,
          fileName: this.fileName
        }
      })
    );
    this.dispatchEvent(new ShowToastEvent({ title: "Submitted", message: "Your help request has been recorded.", variant: "success" }));
  }
}