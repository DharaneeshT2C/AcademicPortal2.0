import LightningModal from "lightning/modal";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import createRemittanceAccount from "@salesforce/apex/RemittanceAccountsController.createRemittanceAccount";
import getLinkedEntityOptions from "@salesforce/apex/RemittanceAccountsController.getLinkedEntityOptions";

export default class RemittanceAccountModal extends LightningModal {
    accountName = "";
    bankName = "";
    accountNumber = "";
    ledgerCode = "";
    linkedLevel = "";
    selectedLinkedEntityIds = [];
    linkedEntityOptions = [];
    merchantId1 = "";
    merchantId2 = "";
    merchantId3 = "";
    isActive = true;

    isSaving = false;
    isLoadingLinkedEntities = false;

    linkedLevelOptions = [
        { label: "Institute Level", value: "Institute Level" },
        { label: "Program Level", value: "Program Level" },
        { label: "Fee Head Level", value: "Fee Head Level" }
    ];

    get modalTitle() {
        return "New Remittance Account";
    }

    get linkedEntityLabel() {
        if (this.linkedLevel === "Institute Level") {
            return "Institutes";
        }
        if (this.linkedLevel === "Program Level") {
            return "Programs";
        }
        if (this.linkedLevel === "Fee Head Level") {
            return "Fee Heads";
        }
        return "Linked Records";
    }

    get linkedEntityPlaceholder() {
        if (this.linkedLevel === "Institute Level") {
            return "Select institutes";
        }
        if (this.linkedLevel === "Program Level") {
            return "Select programs";
        }
        if (this.linkedLevel === "Fee Head Level") {
            return "Select fee heads";
        }
        return "Select records";
    }

    get isLinkedEntityDisabled() {
        return !this.linkedLevel || this.isLoadingLinkedEntities;
    }

    handleFieldInput(event) {
        const fieldName = event.target.name;
        const isBooleanInput =
            event.target.type === "checkbox" || event.target.type === "toggle";
        const fieldValue =
            isBooleanInput
                ? event.target.checked
                : event.detail && event.detail.value !== undefined
                  ? event.detail.value
                  : event.target.value;

        if (fieldName === "accountName") {
            this.accountName = fieldValue;
        } else if (fieldName === "bankName") {
            this.bankName = fieldValue;
        } else if (fieldName === "accountNumber") {
            this.accountNumber = fieldValue;
        } else if (fieldName === "ledgerCode") {
            this.ledgerCode = fieldValue;
        } else if (fieldName === "linkedLevel") {
            this.linkedLevel = fieldValue;
            this.selectedLinkedEntityIds = [];
            this.loadLinkedEntityOptions();
        } else if (fieldName === "linkedEntityIds") {
            this.selectedLinkedEntityIds = Array.isArray(fieldValue) ? fieldValue : [];
        } else if (fieldName === "merchantId1") {
            this.merchantId1 = fieldValue;
        } else if (fieldName === "merchantId2") {
            this.merchantId2 = fieldValue;
        } else if (fieldName === "merchantId3") {
            this.merchantId3 = fieldValue;
        } else if (fieldName === "isActive") {
            this.isActive = fieldValue;
        }
    }

    async handleSave() {
        const accountNameInput = this.template.querySelector('[data-id="accountName"]');
        const bankNameInput = this.template.querySelector('[data-id="bankName"]');
        const accountNumberInput = this.template.querySelector('[data-id="accountNumber"]');
        const ledgerCodeInput = this.template.querySelector('[data-id="ledgerCode"]');

        this.accountName = accountNameInput ? accountNameInput.value : this.accountName;
        this.bankName = bankNameInput ? bankNameInput.value : this.bankName;
        this.accountNumber = accountNumberInput ? accountNumberInput.value : this.accountNumber;
        this.ledgerCode = ledgerCodeInput ? ledgerCodeInput.value : this.ledgerCode;
        this.merchantId1 = (this.merchantId1 || "").trim();
        this.merchantId2 = (this.merchantId2 || "").trim();
        this.merchantId3 = (this.merchantId3 || "").trim();

        const normalizedAccountName = (this.accountName || "").trim();
        if (!normalizedAccountName) {
            accountNameInput?.reportValidity?.();
            this.showError("Account Name is required.");
            return;
        }

        const normalizedBankName = (this.bankName || "").trim();
        if (!normalizedBankName) {
            bankNameInput?.reportValidity?.();
            this.showError("Bank is required.");
            return;
        }

        const normalizedAccountNumber = (this.accountNumber || "").trim();
        if (!normalizedAccountNumber) {
            accountNumberInput?.reportValidity?.();
            this.showError("Account Number is required.");
            return;
        }

        const normalizedLedgerCode = (this.ledgerCode || "").trim();
        if (!normalizedLedgerCode) {
            ledgerCodeInput?.reportValidity?.();
            this.showError("Ledger Code is required.");
            return;
        }

        if (!this.linkedLevel) {
            this.showError("Linked Level is required.");
            return;
        }

        this.isSaving = true;
        try {
            await createRemittanceAccount({
                accountName: normalizedAccountName,
                bankName: normalizedBankName,
                accountNumber: normalizedAccountNumber,
                ledgerCode: normalizedLedgerCode,
                linkedLevel: this.linkedLevel,
                linkedEntityIds: this.selectedLinkedEntityIds,
                merchantId1: this.merchantId1 || null,
                merchantId2: this.merchantId2 || null,
                merchantId3: this.merchantId3 || null,
                isActive: this.isActive
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Success",
                    message: "Remittance account created.",
                    variant: "success"
                })
            );
            this.close("saved");
        } catch (error) {
            this.showError(this.getErrorMessage(error));
        } finally {
            this.isSaving = false;
        }
    }

    async loadLinkedEntityOptions() {
        if (!this.linkedLevel) {
            this.linkedEntityOptions = [];
            return;
        }

        this.isLoadingLinkedEntities = true;
        try {
            const rows = await getLinkedEntityOptions({ linkedLevel: this.linkedLevel });
            this.linkedEntityOptions = (Array.isArray(rows) ? rows : []).map((row) => ({
                label: row.label,
                value: row.value
            }));
        } catch (error) {
            this.linkedEntityOptions = [];
            this.showError(this.getErrorMessage(error));
        } finally {
            this.isLoadingLinkedEntities = false;
        }
    }

    showError(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: "Error",
                message,
                variant: "error"
            })
        );
    }

    getErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return "Failed to create remittance account.";
    }

    handleCancel() {
        this.close("cancel");
    }
}