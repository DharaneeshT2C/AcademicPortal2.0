import { LightningElement, track, wire } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import getInstallmentPlanDetails from "@salesforce/apex/InstallmentPlansController.getInstallmentPlanDetails";
import saveInstallmentPlan from "@salesforce/apex/InstallmentPlansController.saveInstallmentPlan";

export default class InstallmentPlanBuilderPage extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track isSaving = false;
    @track installmentRows = [];
    @track notification = null;

    editingScheduleId = null;
    planName = "";
    installmentCode = "";
    status = "Draft";
    installmentFeePercentage = null;
    hasLoaded = false;

    statusOptions = [
        { label: "Draft", value: "Draft" },
        { label: "Active", value: "Active" },
        { label: "Archived", value: "Archived" }
    ];

    @wire(CurrentPageReference)
    setPageReference(pageRef) {
        const nextRecordId = pageRef?.state?.c__recordId || null;
        if (this.hasLoaded && this.editingScheduleId === nextRecordId) {
            return;
        }
        this.editingScheduleId = nextRecordId;
        this.initializeForm();
    }

    async initializeForm() {
        this.isLoading = true;
        try {
            if (this.editingScheduleId) {
                const details = await getInstallmentPlanDetails({ scheduleId: this.editingScheduleId });
                if (details?.isEditRestricted) {
                    this.toast(
                        "Error",
                        details.editRestrictionMessage || "Cannot edit this installment plan because it is used in programme fee configurations.",
                        "error"
                    );
                    this[NavigationMixin.Navigate]({
                        type: "standard__component",
                        attributes: { componentName: "c__installmentPlanRecordPage" },
                        state: { c__recordId: this.editingScheduleId }
                    });
                    return;
                }
                this.planName = details?.planName || "";
                this.installmentCode = details?.installmentCode || "";
                this.status = details?.status || "Draft";
                this.installmentFeePercentage = details?.installmentFeePercentage ?? null;
                this.installmentRows = (details?.installments || []).map((row, index) => ({
                    key: `row-edit-${Date.now()}-${index + 1}`,
                    order: index + 1,
                    percentage: row.percentage,
                    startDate: row.startDate,
                    dueDays: row.dueDays
                }));
                if (!this.installmentRows.length) {
                    this.installmentRows = [this.newInstallmentRow(1)];
                }
            } else {
                this.resetForm();
            }
            this.hasLoaded = true;
        } catch (error) {
            this.toast("Error", this.getErrorMessage(error), "error");
            this.resetForm();
        } finally {
            this.isLoading = false;
        }
    }

    resetForm() {
        this.planName = "";
        this.installmentCode = "";
        this.status = "Draft";
        this.installmentFeePercentage = null;
        this.installmentRows = [this.newInstallmentRow(1)];
    }

    newInstallmentRow(orderValue) {
        return {
            key: `row-${Date.now()}-${orderValue}`,
            order: orderValue,
            percentage: null,
            startDate: null,
            dueDays: null
        };
    }

    handleGoToMasterData() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__masterDataLanding" }
        });
    }

    handleGoToInstallmentPlans() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__installmentPlansPage" }
        });
    }

    handleCancel() {
        if (this.isSaving) {
            return;
        }
        this.handleGoToInstallmentPlans();
    }

    closeModal() {
        this.handleCancel();
    }

    handleHeaderFieldChange(event) {
        const field = event.target.dataset.field;
        if (field === "planName") {
            this.planName = event.target.value;
        } else if (field === "installmentCode") {
            this.installmentCode = event.target.value;
        } else if (field === "status") {
            this.status = event.target.value;
        } else if (field === "installmentFeePercentage") {
            this.installmentFeePercentage = event.target.value;
        }
    }

    handleRowFieldChange(event) {
        const rowKey = event.target.dataset.rowKey;
        const field = event.target.dataset.field;
        const value = event.target.value;

        this.installmentRows = this.installmentRows.map((row) => {
            if (row.key !== rowKey) {
                return row;
            }
            return { ...row, [field]: value === "" ? null : value };
        });
    }

    handleAddInstallment() {
        const nextOrder = this.installmentRows.length + 1;
        this.installmentRows = [...this.installmentRows, this.newInstallmentRow(nextOrder)];
    }

    handleDeleteInstallmentRow(event) {
        const rowKey = event.currentTarget.dataset.rowKey;
        const remainingRows = this.installmentRows.filter((row) => row.key !== rowKey);
        if (!remainingRows.length) {
            this.installmentRows = [this.newInstallmentRow(1)];
            return;
        }

        this.installmentRows = remainingRows.map((row, index) => ({
            ...row,
            order: index + 1
        }));
    }

    handleSaveDraft() {
        this.status = "Draft";
        this.savePlan();
    }

    handleActivate() {
        this.status = "Active";
        this.savePlan();
    }

    handleFooterSave() {
        this.savePlan();
    }

    async savePlan() {
        const nameValue = (this.planName || "").trim();
        if (!nameValue) {
            this.toast("Error", "Installment Plan Name is required.", "error");
            return;
        }
        const codeValue = (this.installmentCode || "").trim();
        if (!codeValue) {
            this.toast("Error", "Installment Code is required.", "error");
            return;
        }
        if (!this.status) {
            this.toast("Error", "Status is required.", "error");
            return;
        }

        const normalizedRows = this.installmentRows.map((row, index) => ({
            percentage: row.percentage === null ? null : Number(row.percentage),
            startDate: row.startDate || null,
            dueDays: row.dueDays === null ? null : Number(row.dueDays),
            order: index + 1
        }));

        const invalidRow = normalizedRows.find((row) => (
            row.percentage === null
            || !row.startDate
            || row.dueDays === null
            || row.percentage <= 0
            || row.dueDays < 0
        ));
        if (invalidRow) {
            this.toast("Error", "Each installment needs Start Date, Percentage, and Due days.", "error");
            return;
        }

        const totalPercentage = normalizedRows.reduce((sum, row) => sum + Number(row.percentage || 0), 0);
        if (Math.abs(totalPercentage - 100) > 0.01) {
            this.toast("Error", "Sum of installment percentage should always be 100%.", "error");
            return;
        }

        this.isSaving = true;
        try {
            await saveInstallmentPlan({
                requestJson: JSON.stringify({
                    scheduleId: this.editingScheduleId,
                    planName: nameValue,
                    installmentCode: codeValue,
                    status: this.status,
                    installmentFeePercentage: this.installmentFeePercentage === null || this.installmentFeePercentage === ""
                        ? null
                        : Number(this.installmentFeePercentage),
                    installments: normalizedRows
                })
            });

            this.toast("Success", "Installment Plan saved successfully.", "success");
            await this.navigateToInstallmentPlansWithReload();
        } catch (error) {
            this.toast("Error", this.getErrorMessage(error), "error");
        } finally {
            this.isSaving = false;
        }
    }

    async navigateToInstallmentPlansWithReload() {
        const pageReference = {
            type: "standard__component",
            attributes: { componentName: "c__installmentPlansPage" },
            state: { c__refresh: Date.now().toString() }
        };
        const generatedUrl = await this[NavigationMixin.GenerateUrl](pageReference);
        window.location.assign(generatedUrl);
    }

    getErrorMessage(error) {
        return error?.body?.message || "Unexpected error occurred.";
    }

    dismissNotification() {
        this.notification = null;
    }

    get hasInstallmentRows() {
        return this.installmentRows.length > 0;
    }

    get totalInstallmentPercentage() {
        return this.installmentRows.reduce((sum, row) => sum + Number(row.percentage || 0), 0).toFixed(2);
    }

    get pageTitle() {
        return this.editingScheduleId ? "Edit Installment Plan" : "New Installment Plan";
    }

    get crumbActionLabel() {
        return this.editingScheduleId ? "Edit" : "New";
    }

    get statusBadgeClass() {
        const normalized = String(this.status || "draft").toLowerCase();
        if (normalized === "active") {
            return "status-badge status-active";
        }
        if (normalized === "archived") {
            return "status-badge status-archived";
        }
        return "status-badge status-draft";
    }

    toast(title, message, variant) {
        const normalizedVariant = variant === "success" ? "success" : variant === "warning" ? "warning" : "error";
        this.notification = {
            title,
            message,
            containerClass: `noticeBanner noticeBanner${normalizedVariant.charAt(0).toUpperCase()}${normalizedVariant.slice(1)}`,
            iconName:
                normalizedVariant === "success"
                    ? "utility:success"
                    : normalizedVariant === "warning"
                      ? "utility:warning"
                      : "utility:error"
        };
    }
}