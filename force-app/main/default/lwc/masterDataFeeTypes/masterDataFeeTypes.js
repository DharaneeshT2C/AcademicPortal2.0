import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSeedData from '@salesforce/apex/MasterDataFeeTypesController.getSeedData';
import saveFeeTypeConfiguration from '@salesforce/apex/MasterDataFeeTypesController.saveFeeTypeConfiguration';

export default class MasterDataFeeTypes extends LightningElement {
    LINK_LEVEL_LEARNING_PROGRAM_PLAN = 'Learning Program Plan';
    LINK_LEVEL_LEARNING_PROGRAM = 'Learning Program';
    LINK_LEVEL_INSTITUTE = 'Institute';

    isLoading = true;
    isSaving = false;

    linkedMappingCounter = 0;
    feeTypeLinkedMappings = [];

    programmeId = null;
    learningProgramId = null;
    instituteId = null;

    feeCategoryOptions = [];
    feeHeadOptions = [];
    remittanceOptions = [];
    installmentOptions = [];
    penaltyPlanOptions = [];

    programmeYearRangesById = {};
    remittanceMerchantIdsById = {};

    feeCategory = null;
    batchIntake = null;
    activationDate = null;
    frequency = 'One Time';
    statusLabel = 'Draft';

    selectedRemittanceIds = [];
    notes = null;

    oneTimeFeeHeadId = null;
    oneTimeCategoryId = null;
    oneTimeQuotaId = null;
    oneTimeFeePlanTag = null;
    oneTimeAmount = null;
    oneTimeStartDate = null;
    oneTimeDueDate = null;
    oneTimeRemittanceOverrideId = null;
    oneTimeInstallmentId = null;
    oneTimePenaltyPlanId = null;

    frequencyOptions = [
        { label: 'One Time', value: 'One Time' },
        { label: 'Yearly', value: 'Yearly' },
        { label: 'Termly', value: 'Termly' }
    ];

    connectedCallback() {
        this.initializeLinkMappings();
        this.loadSeedData();
    }

    async loadSeedData() {
        this.isLoading = true;
        try {
            const seed = await getSeedData();
            this.feeHeadOptions = seed?.feeHeadOptions || [];
            this.feeCategoryOptions = (seed?.feeCategoryOptions || []).filter((option) => {
                const valueText = String(option?.value || '').trim().toLowerCase();
                const labelText = String(option?.label || '').trim().toLowerCase();
                return valueText === 'hostel' || labelText === 'hostel';
            });
            this.remittanceOptions = seed?.remittanceOptions || [];
            this.installmentOptions = seed?.installmentOptions || [];
            this.penaltyPlanOptions = seed?.penaltyPlanOptions || [];

            this.programmeYearRangesById = {};
            (seed?.programmeYearRanges || []).forEach((row) => {
                this.programmeYearRangesById[row.programmeId] = {
                    startYear: row.startYear,
                    endYear: row.endYear
                };
            });

            this.remittanceMerchantIdsById = {};
            (seed?.remittanceMerchantRows || []).forEach((row) => {
                if (row?.remittanceId && row?.merchantIds) {
                    this.remittanceMerchantIdsById[row.remittanceId] = row.merchantIds;
                }
            });

            this.feeCategory = this.feeCategoryOptions.length
                ? this.feeCategoryOptions[0].value
                : null;
        } catch (error) {
            this.toast('Error', this.parseError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    initializeLinkMappings() {
        this.linkedMappingCounter = 0;
        this.setFeeTypeLinkedMappings([
            this.createFeeTypeLinkedMappingRow(this.LINK_LEVEL_LEARNING_PROGRAM_PLAN, this.programmeId)
        ]);
    }

    createFeeTypeLinkedMappingRow(linkedLevel = '', linkedEntityId = null) {
        this.linkedMappingCounter += 1;
        return {
            key: `fee-type-linked-${this.linkedMappingCounter}`,
            linkedLevel,
            linkedEntityId,
            rowIndex: 1,
            removeDisabled: true,
            availableLinkedLevelOptions: []
        };
    }

    setFeeTypeLinkedMappings(rows) {
        const sourceRows = Array.isArray(rows) && rows.length ? rows : [this.createFeeTypeLinkedMappingRow()];
        const canRemove = sourceRows.length > 1;

        this.feeTypeLinkedMappings = sourceRows.map((row, index) => {
            const usedLevelsByOtherRows = new Set(
                sourceRows
                    .filter((candidate) => candidate.key !== row.key && candidate.linkedLevel)
                    .map((candidate) => candidate.linkedLevel)
            );

            return {
                ...row,
                rowIndex: index + 1,
                removeDisabled: !canRemove || this.isSaving,
                isLearningProgramPlan: row.linkedLevel === this.LINK_LEVEL_LEARNING_PROGRAM_PLAN,
                isLearningProgram: row.linkedLevel === this.LINK_LEVEL_LEARNING_PROGRAM,
                isInstitute: row.linkedLevel === this.LINK_LEVEL_INSTITUTE,
                availableLinkedLevelOptions: this.allLinkLevelOptions.filter(
                    (option) => option.value === row.linkedLevel || !usedLevelsByOtherRows.has(option.value)
                )
            };
        });

        this.syncSelectedLinkageIds();
    }

    syncSelectedLinkageIds() {
        this.programmeId = this.getLinkedEntityIdForLevel(this.LINK_LEVEL_LEARNING_PROGRAM_PLAN);
        this.learningProgramId = this.getLinkedEntityIdForLevel(this.LINK_LEVEL_LEARNING_PROGRAM);
        this.instituteId = this.getLinkedEntityIdForLevel(this.LINK_LEVEL_INSTITUTE);

        const range = this.programmeYearRangesById[this.programmeId];
        if (this.programmeId && !this.batchIntake) {
            this.batchIntake = this.formatBatchIntake(range) || this.batchIntake;
        }
    }

    getLinkedEntityIdForLevel(linkLevel) {
        const matchedRow = (this.feeTypeLinkedMappings || []).find((row) => row.linkedLevel === linkLevel);
        return matchedRow?.linkedEntityId || null;
    }

    handleLinkedLevelChange(event) {
        const rowKey = event.target.dataset.key;
        const value = event.detail.value;

        this.setFeeTypeLinkedMappings(
            this.feeTypeLinkedMappings.map((row) =>
                row.key === rowKey
                    ? { ...row, linkedLevel: value, linkedEntityId: null }
                    : row
            )
        );
    }

    handleLearningProgramPlanChange(event) {
        this.handleLinkedEntityChangeForLevel(this.LINK_LEVEL_LEARNING_PROGRAM_PLAN, event);
    }

    handleLearningProgramChange(event) {
        this.handleLinkedEntityChangeForLevel(this.LINK_LEVEL_LEARNING_PROGRAM, event);
    }

    handleInstituteChange(event) {
        this.handleLinkedEntityChangeForLevel(this.LINK_LEVEL_INSTITUTE, event);
    }

    handleLinkedEntityChangeForLevel(linkLevel, event) {
        const rowKey = event.target.dataset.key;
        const value = this.getSelectedValue(event);

        this.setFeeTypeLinkedMappings(
            this.feeTypeLinkedMappings.map((row) =>
                row.key === rowKey && row.linkedLevel === linkLevel
                    ? { ...row, linkedEntityId: value }
                    : row
            )
        );
    }

    handleAddLinkedLevel() {
        this.setFeeTypeLinkedMappings([...this.feeTypeLinkedMappings, this.createFeeTypeLinkedMappingRow()]);
    }

    handleRemoveLinkedLevel(event) {
        const rowKey = event.currentTarget.dataset.key;
        this.setFeeTypeLinkedMappings(this.feeTypeLinkedMappings.filter((row) => row.key !== rowKey));
    }

    handleFeeCategoryChange(event) {
        this.feeCategory = event.detail.value;
    }

    handleBatchChange(event) {
        this.batchIntake = event.detail.value;
    }

    handleActivationDateChange(event) {
        this.activationDate = event.detail.value;
    }

    handleFrequencyChange(event) {
        this.frequency = event.detail.value;
    }

    handleRemittanceAccountsChange(event) {
        this.selectedRemittanceIds = event.detail.value || [];
    }

    handleNotesChange(event) {
        this.notes = event.detail.value;
    }

    handleOneTimeFeeHeadChange(event) {
        this.oneTimeFeeHeadId = event.detail.value;
    }

    handleOneTimeCategoryChange(event) {
        this.oneTimeCategoryId = this.getSelectedValue(event);
        this.oneTimeQuotaId = null;
    }

    handleOneTimeQuotaChange(event) {
        this.oneTimeQuotaId = this.getSelectedValue(event);
    }

    handleOneTimeFeePlanTagChange(event) {
        this.oneTimeFeePlanTag = event.detail.value;
    }

    handleOneTimeAmountChange(event) {
        this.oneTimeAmount = event.detail.value;
    }

    handleOneTimeStartDateChange(event) {
        this.oneTimeStartDate = event.detail.value;
    }

    handleOneTimeDueDateChange(event) {
        this.oneTimeDueDate = event.detail.value;
    }

    handleOneTimeRemittanceOverrideChange(event) {
        this.oneTimeRemittanceOverrideId = this.getSelectedValue(event);
    }

    handleOneTimeInstallmentChange(event) {
        this.oneTimeInstallmentId = this.getSelectedValue(event);
    }

    handleOneTimePenaltyPlanChange(event) {
        this.oneTimePenaltyPlanId = this.getSelectedValue(event);
    }

    async handleSaveDraft() {
        await this.saveConfiguration(false);
    }

    async handleActivate() {
        await this.saveConfiguration(true);
    }

    async saveConfiguration(activateNow) {
        if (this.isSaving) {
            return;
        }

        const validationMessage = this.getClientValidationMessage();
        if (validationMessage) {
            this.toast('Missing Information', validationMessage, 'error');
            return;
        }

        this.isSaving = true;

        try {
            const payload = {
                linkedMappings: (this.feeTypeLinkedMappings || [])
                    .filter((row) => row.linkedLevel && row.linkedEntityId)
                    .map((row) => ({
                        linkedLevel: row.linkedLevel,
                        linkedEntityId: row.linkedEntityId
                    })),
                programmeId: this.programmeId,
                learningProgramId: this.learningProgramId,
                instituteId: this.instituteId,
                feeCategory: this.feeCategory,
                batchIntake: this.batchIntake,
                activationDate: this.activationDate,
                frequency: this.frequency,
                remittanceAccountIds: this.selectedRemittanceIds,
                notes: this.notes,
                oneTimeFeeHeadId: this.oneTimeFeeHeadId,
                oneTimeCategoryId: this.oneTimeCategoryId,
                oneTimeQuotaId: this.oneTimeQuotaId,
                oneTimeFeePlanTag: this.oneTimeFeePlanTag,
                oneTimeAmount: this.oneTimeAmount,
                oneTimeStartDate: this.oneTimeStartDate,
                oneTimeDueDate: this.oneTimeDueDate,
                oneTimeRemittanceOverrideId: this.oneTimeRemittanceOverrideId,
                oneTimeInstallmentId: this.oneTimeInstallmentId,
                oneTimePenaltyPlanId: this.oneTimePenaltyPlanId
            };

            await saveFeeTypeConfiguration({
                requestJson: JSON.stringify(payload),
                activateNow
            });

            this.statusLabel = activateNow ? 'Active' : 'Draft';
            this.toast(
                'Success',
                activateNow ? 'Fee Type activated successfully.' : 'Fee Type saved as draft.',
                'success'
            );
        } catch (error) {
            this.toast('Error', this.parseError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    getClientValidationMessage() {
        const hasAtLeastOneCompleteLink = (this.feeTypeLinkedMappings || []).some(
            (row) => row.linkedLevel && row.linkedEntityId
        );

        if (!hasAtLeastOneCompleteLink) {
            return 'At least one Link Level and record selection is required.';
        }
        if (!this.feeCategory) {
            return 'Fee Category is required.';
        }
        if (this.isBatchIntakeRequired && !this.batchIntake) {
            return 'Batch / Intake is required.';
        }
        if (!this.activationDate) {
            return 'Activation Date is required.';
        }
        if (!this.frequency) {
            return 'Frequency is required.';
        }
        if (!this.selectedRemittanceIds?.length) {
            return 'At least one Remittance Account is required.';
        }
        if (!this.oneTimeFeeHeadId) {
            return 'Fee Head is required.';
        }
        if (this.oneTimeAmount === null || this.oneTimeAmount === undefined || this.oneTimeAmount === '') {
            return 'Amount is required.';
        }
        if (!this.oneTimeDueDate) {
            return 'Due Date is required.';
        }

        return '';
    }

    formatBatchIntake(range) {
        const startYear = Number(range?.startYear);
        const endYear = Number(range?.endYear);

        if (Number.isFinite(startYear) && Number.isFinite(endYear)) {
            const suffix = String(endYear).slice(-2);
            return `${startYear}-${suffix}`;
        }

        if (Number.isFinite(startYear)) {
            const nextYearSuffix = String(startYear + 1).slice(-2);
            return `${startYear}-${nextYearSuffix}`;
        }

        return '';
    }

    getSelectedValue(event) {
        return event?.detail?.recordId || event?.detail?.value || null;
    }

    parseError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (Array.isArray(error?.body) && error.body.length && error.body[0]?.message) {
            return error.body[0].message;
        }
        return 'Unable to complete Fee Type action.';
    }

    toast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    get allLinkLevelOptions() {
        return [
            { label: this.LINK_LEVEL_LEARNING_PROGRAM_PLAN, value: this.LINK_LEVEL_LEARNING_PROGRAM_PLAN },
            { label: this.LINK_LEVEL_LEARNING_PROGRAM, value: this.LINK_LEVEL_LEARNING_PROGRAM },
            { label: this.LINK_LEVEL_INSTITUTE, value: this.LINK_LEVEL_INSTITUTE }
        ];
    }

    get selectedRemittanceMerchantIds() {
        if (!this.selectedRemittanceIds?.length) {
            return null;
        }

        const values = new Set();
        this.selectedRemittanceIds.forEach((remittanceId) => {
            const merchantIds = this.remittanceMerchantIdsById[remittanceId];
            if (!merchantIds) {
                return;
            }

            String(merchantIds)
                .split(',')
                .map((id) => id.trim())
                .filter((id) => Boolean(id))
                .forEach((id) => values.add(id));
        });

        return values.size ? Array.from(values).join(', ') : null;
    }

    get oneTimeQuotaFilter() {
        if (!this.oneTimeCategoryId) {
            return null;
        }

        return {
            criteria: [
                {
                    fieldPath: 'Category__c',
                    operator: 'eq',
                    value: this.oneTimeCategoryId
                }
            ]
        };
    }

    get instituteAccountFilter() {
        return {
            criteria: [
                {
                    fieldPath: 'RecordType.Name',
                    operator: 'eq',
                    value: 'Institute'
                }
            ]
        };
    }

    get isBatchIntakeRequired() {
        return Boolean(this.programmeId || this.learningProgramId);
    }

    get isAddLinkedLevelDisabled() {
        return this.isSaving || (this.feeTypeLinkedMappings || []).length >= this.allLinkLevelOptions.length;
    }

    get isSaveDraftDisabled() {
        return this.isSaving;
    }

    get isActivateDisabled() {
        return this.isSaving;
    }
}