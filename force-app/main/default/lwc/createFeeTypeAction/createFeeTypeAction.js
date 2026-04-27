// createFeeTypeAction.js
import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';

import { getObjectInfo, getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';
import FEE_TYPE_OBJECT from '@salesforce/schema/Ken_Fee_Type__c';

import createFeeType from '@salesforce/apex/FeeTypeCreationService.createFeeType';
import getFeeSetPreview from '@salesforce/apex/FeeTypeCreationService.getFeeSetPreview';

export default class CreateFeeTypeAction extends NavigationMixin(LightningElement) {
    LINK_LEVEL_LEARNING_PROGRAM_PLAN = 'Learning Program Plan';
    LINK_LEVEL_INSTITUTE_PROGRAM_PLAN = 'Institute Program Plan';

    @api recordId;
    @api contextId;
    @wire(CurrentPageReference) pageRef;


    isLoading = true;
    isSaving = false;

    feeTypeRecordTypeId = null;
    feeTypeName = '';
    linkLevel = 'Learning Program Plan';
    instituteProgramPlanId = null;
    selectedLearningProgramPlanId = null;
    feeCategory = null;
    frequency = null;
    status = null;

    paymentScheduleId = null;
    defaultTaxId = null;
    lateFeePlanId = null;

    feeTypeRecordTypeOptions = [];
    feeCategoryOptions = [];
    frequencyOptions = [];
    statusOptions = [];

    programDurationYears = 1;
    yearConfigurations = [];

    isPreviewOpen = false;
    isPreviewLoading = false;
    previewYearNumber = null;
    previewRows = [];

    taxFilter;
    lateFeeFilter;

    previewColumns = [
        { label: 'Student Category', fieldName: 'studentCategory' },
        { label: 'Fee Head', fieldName: 'feeHeadName' },
        { label: 'Amount', fieldName: 'amount', type: 'number' },
        { label: 'Currency', fieldName: 'currencyIsoCode' },
        { label: 'Remittance Account', fieldName: 'remittanceAccountName' },
        { label: 'Tax', fieldName: 'taxName' }
    ];

    connectedCallback() {
        this.selectedLearningProgramPlanId = this.contextLearningProgramPlanId;
        this.rebuildYearConfigurations(this.programDurationYears);
    }

    get contextLearningProgramPlanId() {
        return this.recordId || this.contextId || (this.pageRef && this.pageRef.state && (this.pageRef.state.recordId || this.pageRef.state.c__recordId)) || null;
    }

    get learningProgramPlanId() {
        return this.selectedLearningProgramPlanId || null;
    }

    get linkLevelOptions() {
        return [
            { label: this.LINK_LEVEL_LEARNING_PROGRAM_PLAN, value: this.LINK_LEVEL_LEARNING_PROGRAM_PLAN },
            { label: this.LINK_LEVEL_INSTITUTE_PROGRAM_PLAN, value: this.LINK_LEVEL_INSTITUTE_PROGRAM_PLAN }
        ];
    }

    get isLearningProgramPlanLinkLevel() {
        return this.linkLevel === this.LINK_LEVEL_LEARNING_PROGRAM_PLAN;
    }

    get isInstituteProgramPlanLinkLevel() {
        return this.linkLevel === this.LINK_LEVEL_INSTITUTE_PROGRAM_PLAN;
    }

    get isCreateDisabled() {
        return this.isSaving || this.isLoading;
    }

    get isCopyDisabled() {
        const yearOneRow = this.yearConfigurations.find((row) => row.yearNumber === 1);
        return !yearOneRow || !yearOneRow.feeSetId || !yearOneRow.dueDate;
    }

    get isFooterPreviewDisabled() {
        const yearOneRow = this.yearConfigurations.find((row) => row.yearNumber === 1);
        return !yearOneRow || !yearOneRow.feeSetId;
    }

    @wire(getObjectInfo, { objectApiName: FEE_TYPE_OBJECT })
    wiredObjectInfo({ data, error }) {
        if (data) {
            this.feeTypeRecordTypeOptions = this.buildRecordTypeOptions(data.recordTypeInfos);

            const defaultRecordTypeId = data.defaultRecordTypeId;
            this.feeTypeRecordTypeId = this.getFirstAllowedRecordTypeId(defaultRecordTypeId);

            this.isLoading = false;
        } else if (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
            this.isLoading = false;
        }
    }

    @wire(getPicklistValuesByRecordType, {
        objectApiName: FEE_TYPE_OBJECT,
        recordTypeId: '$feeTypeRecordTypeId'
    })
    wiredPicklists({ data, error }) {
        if (data) {
            this.feeCategoryOptions = this.mapPicklistToOptions(data.picklistFieldValues.Fee_Category__c);
            this.frequencyOptions = this.mapPicklistToOptions(data.picklistFieldValues.Fee_Collection_Frequency__c);
            this.statusOptions = this.mapPicklistToOptions(data.picklistFieldValues.Status__c);
        } else if (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        }
    }

    buildRecordTypeOptions(recordTypeInfos) {
        const options = [];
        for (const recordTypeId in recordTypeInfos) {
            const info = recordTypeInfos[recordTypeId];
            if (info && info.available) {
                if (info.name === 'Academics Fee' || info.name === 'Non Academics Fee') {
                    options.push({ label: info.name, value: recordTypeId });
                }
            }
        }
        options.sort((a, b) => (a.label > b.label ? 1 : -1));
        return options;
    }

    getFirstAllowedRecordTypeId(defaultRecordTypeId) {
        if (this.feeTypeRecordTypeOptions.some((o) => o.value === defaultRecordTypeId)) {
            return defaultRecordTypeId;
        }
        return this.feeTypeRecordTypeOptions.length > 0 ? this.feeTypeRecordTypeOptions[0].value : null;
    }

    mapPicklistToOptions(picklistField) {
        const options = [];
        if (picklistField && picklistField.values) {
            for (const valueRow of picklistField.values) {
                options.push({ label: valueRow.label, value: valueRow.value });
            }
        }
        return options;
    }

    handleHeaderChange(event) {
        const fieldName = event.target.name;
        const fieldValue = event.target.value;

        if (fieldName === 'feeTypeRecordTypeId') {
            this.feeTypeRecordTypeId = fieldValue;
            return;
        }
        if (fieldName === 'feeTypeName') {
            this.feeTypeName = fieldValue;
            return;
        }
        if (fieldName === 'linkLevel') {
            this.linkLevel = fieldValue;
            if (this.isLearningProgramPlanLinkLevel && !this.selectedLearningProgramPlanId) {
                this.selectedLearningProgramPlanId = this.contextLearningProgramPlanId;
            }
            return;
        }
        if (fieldName === 'feeCategory') {
            this.feeCategory = fieldValue;
            return;
        }
        if (fieldName === 'frequency') {
            this.frequency = fieldValue;
            return;
        }
        if (fieldName === 'status') {
            this.status = fieldValue;
        }
    }

    handleLearningProgramPlanPicked(event) {
        this.selectedLearningProgramPlanId = event.detail.recordId || null;
    }

    handleInstituteProgramPlanPicked(event) {
        this.instituteProgramPlanId = event.detail.recordId || null;
    }

    handlePaymentSchedulePicked(event) {
        this.paymentScheduleId = event.detail.recordId;
    }

    handleDefaultTaxPicked(event) {
        this.defaultTaxId = event.detail.recordId;
    }

    handleLateFeePlanPicked(event) {
        this.lateFeePlanId = event.detail.recordId;
    }

    handleProgramDurationChange(event) {
        const years = Number(event.target.value);
        const normalizedYears = Number.isFinite(years) && years > 0 ? years : 1;
        this.programDurationYears = normalizedYears;
        this.rebuildYearConfigurations(normalizedYears);
    }

    rebuildYearConfigurations(numberOfYears) {
        const rows = [];
        for (let index = 1; index <= numberOfYears; index += 1) {
            rows.push({
                key: `Y${index}`,
                yearNumber: index,
                feeSetId: null,
                dueDate: null,
                feeSetError: null,
                dueDateError: null,
                isPreviewDisabled: true
            });
        }
        this.yearConfigurations = rows;
    }

    handleFeeSetPicked(event) {
        const rowKey = event.target.dataset.key;
        const selectedFeeSetId = event.detail.recordId;

        const updatedRows = [];
        for (const row of this.yearConfigurations) {
            if (row.key === rowKey) {
                updatedRows.push({
                    ...row,
                    feeSetId: selectedFeeSetId,
                    feeSetError: null,
                    isPreviewDisabled: !selectedFeeSetId
                });
            } else {
                updatedRows.push(row);
            }
        }
        this.yearConfigurations = updatedRows;
    }

    handleDueDateChange(event) {
        const rowKey = event.target.dataset.key;
        const selectedDueDate = event.target.value;

        const updatedRows = [];
        for (const row of this.yearConfigurations) {
            if (row.key === rowKey) {
                updatedRows.push({
                    ...row,
                    dueDate: selectedDueDate,
                    dueDateError: null
                });
            } else {
                updatedRows.push(row);
            }
        }
        this.yearConfigurations = updatedRows;
    }

    handleCopyYearOneToAll() {
        const yearOneRow = this.yearConfigurations.find((row) => row.yearNumber === 1);
        if (!yearOneRow) {
            return;
        }

        const updatedRows = [];
        for (const row of this.yearConfigurations) {
            updatedRows.push({
                ...row,
                feeSetId: yearOneRow.feeSetId,
                dueDate: yearOneRow.dueDate,
                feeSetError: null,
                dueDateError: null,
                isPreviewDisabled: !yearOneRow.feeSetId
            });
        }
        this.yearConfigurations = updatedRows;
    }

    async handlePreviewRow(event) {
        const rowKey = event.target.dataset.key;
        const selectedRow = this.yearConfigurations.find((row) => row.key === rowKey);

        if (!selectedRow || !selectedRow.feeSetId) {
            this.showToast('Error', 'Please select a Fee Set before preview.', 'error');
            return;
        }

        await this.openPreviewForRow(selectedRow);
    }

    async handlePreviewFooter() {
        const yearOneRow = this.yearConfigurations.find((row) => row.yearNumber === 1);
        if (!yearOneRow || !yearOneRow.feeSetId) {
            this.showToast('Error', 'Please select a Fee Set for Year 1 before preview.', 'error');
            return;
        }

        await this.openPreviewForRow(yearOneRow);
    }

    async openPreviewForRow(row) {
        this.isPreviewOpen = true;
        this.isPreviewLoading = true;
        this.previewYearNumber = row.yearNumber;
        this.previewRows = [];

        try {
            const result = await getFeeSetPreview({ feeSetId: row.feeSetId });
            this.previewRows = (result || []).map((previewRow) => ({ ...previewRow }));
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isPreviewLoading = false;
        }
    }

    handleClosePreview() {
        this.isPreviewOpen = false;
        this.previewYearNumber = null;
        this.previewRows = [];
    }

    async handleCreate() {
        const validationMessage = this.getClientValidationMessage();
        if (validationMessage) {
            this.showToast('Missing Information', validationMessage, 'error');
            return;
        }

        this.isSaving = true;

        try {
            const yearConfigurationsPayload = this.yearConfigurations.map((row) => ({
                programYearNumber: row.yearNumber,
                feeSetId: row.feeSetId,
                dueDate: row.dueDate
            }));

            const requestPayload = {
                linkLevel: this.linkLevel,
                learningProgramPlanId: this.isLearningProgramPlanLinkLevel ? this.learningProgramPlanId : null,
                instituteProgramPlanId: this.isInstituteProgramPlanLinkLevel ? this.instituteProgramPlanId : null,
                feeTypeRecordTypeId: this.feeTypeRecordTypeId,
                feeTypeName: this.feeTypeName,
                feeCategory: this.feeCategory,
                frequency: this.frequency,
                status: this.status,
                paymentScheduleId: this.paymentScheduleId,
                defaultTaxId: this.defaultTaxId,
                lateFeePlanId: this.lateFeePlanId,
                yearConfigurations: yearConfigurationsPayload
            };

            const createdFeeTypeId = await createFeeType({
                requestJson: JSON.stringify(requestPayload)
            });

            this.showToast('Success', 'Fee Type created successfully.', 'success');
            this.dispatchEvent(new CloseActionScreenEvent());

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: createdFeeTypeId,
                    objectApiName: 'Ken_Fee_Type__c',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    getClientValidationMessage() {
        if (!this.feeTypeRecordTypeId) {
            return 'Fee Type Record Type is required.';
        }
        if (!this.feeCategory) {
            return 'Fee Category is required.';
        }
        if (!this.frequency) {
            return 'Fee Collection Frequency is required.';
        }
        if (!this.status) {
            return 'Status is required.';
        }
        if (!this.paymentScheduleId) {
            return 'Payment Schedule is required.';
        }
        if (!this.linkLevel) {
            return 'Link Level is required.';
        }
        if (this.isLearningProgramPlanLinkLevel && !this.learningProgramPlanId) {
            return 'Learning Program Plan is required.';
        }
        if (this.isInstituteProgramPlanLinkLevel && !this.instituteProgramPlanId) {
            return 'Institute Program Plan is required.';
        }

        for (const row of this.yearConfigurations) {
            if (!row.feeSetId) {
                return `Fee Set is required for Year ${row.yearNumber}.`;
            }
            if (!row.dueDate) {
                return `Due Date is required for Year ${row.yearNumber}.`;
            }
        }

        return '';
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    getErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return 'Unexpected error occurred.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}