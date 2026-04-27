import { LightningElement } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import getScholarshipOptions from "@salesforce/apex/AssignScholarshipPageController.getScholarshipOptions";
import searchPersonAccounts from "@salesforce/apex/AssignScholarshipPageController.searchPersonAccounts";
import getProgramOptionsForStudent from "@salesforce/apex/AssignScholarshipPageController.getProgramOptionsForStudent";
import getFeeAssignmentLineItemData from "@salesforce/apex/AssignScholarshipPageController.getFeeAssignmentLineItemData";
import applyScholarship from "@salesforce/apex/AssignScholarshipPageController.applyScholarship";

export default class AssignScholarshipPage extends NavigationMixin(LightningElement) {
    scholarshipRecords = [];

    selectedScholarshipId = "";
    studentSearchTerm = "";
    selectedStudent = null;
    searchMessage = "";
    globalError = "";

    programOptions = [];
    selectedProgramId = "";
    feeHeadOptions = [];
    selectedFeeHeadId = "";
    lineItemRecords = [];
    selectedFeeAssignmentLineItemId = "";
    lineItemMessage = "";

    isScholarshipLoading = true;
    isStudentSearching = false;
    isProgramLoading = false;
    isLineItemLoading = false;
    isSubmitting = false;

    effectiveDate = new Date().toISOString().slice(0, 10);
    expiryDate = "";
    notes = "";

    connectedCallback() {
        this.loadScholarships();
    }

    async loadScholarships() {
        this.isScholarshipLoading = true;
        this.globalError = "";
        try {
            this.scholarshipRecords = await getScholarshipOptions();
        } catch (error) {
            this.scholarshipRecords = [];
            this.globalError = this.getErrorMessage(error, "Unable to load scholarship options.");
        } finally {
            this.isScholarshipLoading = false;
        }
    }

    get scholarshipOptions() {
        return (this.scholarshipRecords || []).map((scholarship) => ({
            label: scholarship.name,
            value: scholarship.id
        }));
    }

    get selectedScholarship() {
        return (this.scholarshipRecords || []).find(
            (scholarship) => scholarship.id === this.selectedScholarshipId
        );
    }

    get selectedLineItem() {
        return (this.lineItemRecords || []).find(
            (lineItem) => lineItem.value === this.selectedFeeAssignmentLineItemId
        );
    }

    get lineItemOptions() {
        return (this.lineItemRecords || []).map((lineItem) => ({
            label: lineItem.label,
            value: lineItem.value
        }));
    }

    get summaryScholarshipLabel() {
        return this.selectedScholarship ? this.selectedScholarship.name : "Not Selected";
    }

    get summaryStudentLabel() {
        return this.selectedStudent
            ? `${this.selectedStudent.name} (${this.selectedStudent.studentId})`
            : "Not Selected";
    }

    get summaryProgramLabel() {
        const selectedProgram = (this.programOptions || []).find(
            (option) => option.value === this.selectedProgramId
        );
        return selectedProgram ? selectedProgram.label : "Not Selected";
    }

    get summaryLineItemLabel() {
        return this.selectedLineItem ? this.selectedLineItem.label : "Not Selected";
    }

    get isApplyDisabled() {
        return (
            this.isSubmitting
            || this.isProgramLoading
            || this.isLineItemLoading
            || !this.selectedScholarship
            || !this.selectedStudent
            || !this.selectedProgramId
            || !this.selectedFeeAssignmentLineItemId
            || !this.effectiveDate
        );
    }

    get searchButtonLabel() {
        return this.isStudentSearching ? "Searching..." : "Search";
    }

    get applyButtonLabel() {
        return this.isSubmitting ? "Applying..." : "Apply Scholarship";
    }

    get isFeeHeadDisabled() {
        return this.isLineItemLoading || !this.selectedProgramId;
    }

    get isFeeAssignmentLineItemDisabled() {
        return this.isLineItemLoading || !this.selectedProgramId;
    }

    handleScholarshipChange(event) {
        this.selectedScholarshipId = event.detail.value;
    }

    handleStudentSearchInput(event) {
        this.studentSearchTerm = event.target.value;
    }

    handleStudentSearchKeydown(event) {
        if (event.key === "Enter") {
            event.preventDefault();
            this.handleSearchStudent();
        }
    }

    async handleSearchStudent() {
        const token = (this.studentSearchTerm || "").trim();
        if (!token) {
            this.selectedStudent = null;
            this.searchMessage = "Enter student name or ID to search.";
            this.resetProgramAndLineItemState();
            return;
        }

        this.isStudentSearching = true;
        this.searchMessage = "";
        this.globalError = "";

        try {
            const rows = await searchPersonAccounts({ searchTerm: token });
            if (rows && rows.length > 0) {
                this.selectedStudent = rows[0];
                this.searchMessage = "";
                await this.loadProgramOptionsForSelectedStudent();
            } else {
                this.selectedStudent = null;
                this.searchMessage = "No Person Account found for the entered keyword.";
                this.resetProgramAndLineItemState();
            }
        } catch (error) {
            this.selectedStudent = null;
            this.searchMessage = "";
            this.globalError = this.getErrorMessage(error, "Unable to search Person Accounts.");
            this.resetProgramAndLineItemState();
        } finally {
            this.isStudentSearching = false;
        }
    }

    async loadProgramOptionsForSelectedStudent() {
        this.isProgramLoading = true;
        this.lineItemMessage = "";
        this.selectedProgramId = "";
        this.selectedFeeHeadId = "";
        this.selectedFeeAssignmentLineItemId = "";
        this.programOptions = [];
        this.feeHeadOptions = [];
        this.lineItemRecords = [];

        try {
            const options = await getProgramOptionsForStudent({
                personAccountId: this.selectedStudent?.id || null
            });
            this.programOptions = Array.isArray(options) ? options : [];
            if (!this.programOptions.length) {
                this.lineItemMessage = "No Learning Program Plan found for the selected student.";
            }
        } catch (error) {
            this.globalError = this.getErrorMessage(error, "Unable to load program options.");
            this.programOptions = [];
            this.lineItemMessage = "";
        } finally {
            this.isProgramLoading = false;
        }
    }

    resetProgramAndLineItemState() {
        this.programOptions = [];
        this.selectedProgramId = "";
        this.feeHeadOptions = [];
        this.selectedFeeHeadId = "";
        this.lineItemRecords = [];
        this.selectedFeeAssignmentLineItemId = "";
        this.lineItemMessage = "";
    }

    async handleProgramChange(event) {
        this.selectedProgramId = event.detail.value || "";
        this.selectedFeeHeadId = "";
        this.selectedFeeAssignmentLineItemId = "";
        this.feeHeadOptions = [];
        this.lineItemRecords = [];
        this.lineItemMessage = "";

        if (this.selectedProgramId) {
            await this.loadFeeAssignmentLineItemData();
        }
    }

    async handleFeeHeadChange(event) {
        this.selectedFeeHeadId = event.detail.value || "";
        console.log("Selected Fee Head ID:", this.selectedFeeHeadId);
        this.selectedFeeAssignmentLineItemId = "";
        await this.loadFeeAssignmentLineItemData();
    }

    handleFeeAssignmentLineItemChange(event) {
        this.selectedFeeAssignmentLineItemId = event.detail.value || "";
    }

    async loadFeeAssignmentLineItemData() {
        if (!this.selectedStudent?.id || !this.selectedProgramId) {
            this.feeHeadOptions = [];
            this.lineItemRecords = [];
            this.lineItemMessage = "";
            return;
        }

        this.isLineItemLoading = true;
        this.globalError = "";
        this.lineItemMessage = "";

        try {
            console.log("Loading line items with filters - Student ID:", this.selectedStudent.id, "Program ID:", this.selectedProgramId, "Fee Head ID:", this.selectedFeeHeadId);
            const data = await getFeeAssignmentLineItemData({
                personAccountId: this.selectedStudent.id,
                personContactId: this.selectedStudent.personContactId || null,
                learningProgramPlanId: this.selectedProgramId,
                feeHeadId: this.selectedFeeHeadId || null
            });

            const feeHeadOptions = Array.isArray(data?.feeHeadOptions) ? data.feeHeadOptions : [];
            this.feeHeadOptions = [{ label: "All Fee Heads", value: "" }, ...feeHeadOptions];
            if (this.selectedFeeHeadId) {
                const selectedFeeHeadStillExists = this.feeHeadOptions.some(
                    (option) => option.value === this.selectedFeeHeadId
                );
                if (!selectedFeeHeadStillExists) {
                    this.selectedFeeHeadId = "";
                }
            }

            const lineItems = Array.isArray(data?.lineItems) ? data.lineItems : [];
            this.lineItemRecords = lineItems;

            if (this.selectedFeeAssignmentLineItemId) {
                const selectedLineStillExists = this.lineItemRecords.some(
                    (lineItem) => lineItem.value === this.selectedFeeAssignmentLineItemId
                );
                if (!selectedLineStillExists) {
                    this.selectedFeeAssignmentLineItemId = "";
                }
            }

            if (!this.lineItemRecords.length) {
                this.lineItemMessage = "No Fee Assignment Line Items found for the selected filters.";
            }
        } catch (error) {
            this.feeHeadOptions = [];
            this.lineItemRecords = [];
            this.lineItemMessage = "";
            this.globalError = this.getErrorMessage(
                error,
                "Unable to load fee assignment line items."
            );
        } finally {
            this.isLineItemLoading = false;
        }
    }

    handleEffectiveDateChange(event) {
        this.effectiveDate = event.target.value;
    }

    handleExpiryDateChange(event) {
        this.expiryDate = event.target.value;
    }

    handleNotesChange(event) {
        this.notes = event.target.value;
    }

    handleCancel() {
        this.handleBackToScholarshipAssignments();
    }

    handleSaveDraft() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: "Draft Saved",
                message: "UI draft state is available in this session only.",
                variant: "info"
            })
        );
    }

    async handleApplyScholarship() {
        if (this.isApplyDisabled) {
            return;
        }

        this.isSubmitting = true;
        this.globalError = "";

        try {
            const result = await applyScholarship({
                scholarshipId: this.selectedScholarshipId,
                personAccountId: this.selectedStudent?.id,
                feeAssignmentLineItemId: this.selectedFeeAssignmentLineItemId,
                effectiveDate: this.effectiveDate,
                expiryDate: this.expiryDate || null,
                notes: this.notes || null
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Scholarship Applied",
                    message: result?.message || "Scholarship assignment created successfully.",
                    variant: "success"
                })
            );
        } catch (error) {
            this.globalError = this.getErrorMessage(
                error,
                "Unable to apply scholarship for the selected student."
            );
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: this.globalError,
                    variant: "error"
                })
            );
        } finally {
            this.isSubmitting = false;
        }
    }

    handleBackToScholarshipAssignments() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: {
                componentName: "c__studentFinancials"
            },
            state: {
                c__tab: "scholarshipAssignments"
            }
        });
    }

    getErrorMessage(error, fallbackMessage) {
        return error?.body?.message || fallbackMessage;
    }
}