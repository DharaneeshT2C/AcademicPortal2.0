import { LightningElement, track, wire } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import getBuilderSeedData from "@salesforce/apex/ProgrammeFeePublishingController.getBuilderSeedData";
import getProgrammeFeeConfigurationForEdit from "@salesforce/apex/ProgrammeFeePublishingController.getProgrammeFeeConfigurationForEdit";
import saveProgrammeFeeConfiguration from "@salesforce/apex/ProgrammeFeePublishingController.saveProgrammeFeeConfiguration";
import getFeeSetPreview from "@salesforce/apex/FeeTypeCreationService.getFeeSetPreview";

export default class ProgrammeFeePublishingBuilderPage extends NavigationMixin(LightningElement) {
    LINK_LEVEL_LEARNING_PROGRAM_PLAN = "Learning Program Plan";
    LINK_LEVEL_LEARNING_PROGRAM = "Learning Program";
    LINK_LEVEL_INSTITUTE = "Institute";

    @track isLoading = true;
    @track isSaving = false;
    @track notification = null;

    @track programmeOptions = [];
    @track feePlanOptions = [];
    @track feeHeadOptions = [];
    @track categoryOptions = [];
    @track quotaOptions = [];
    @track feeCategoryOptions = [];
    @track feeTypeCategoryOptions = [];
    @track remittanceOptions = [];
    remittanceMerchantIdsById = {};
    @track paymentGatewayOptions = [];
    @track installmentOptions = [];
    @track feeAssignmentTriggerPointOptions = [];
    installmentLabelById = {};
    feePlanLabelById = {};
    feeHeadLabelById = {};
    feeAssignmentTriggerPointLabelByValue = {};
    @track penaltyPlanOptions = [];
    penaltyPlanLabelById = {};
    @track termRows = [];
    @track previewRows = [];
    @track isPreviewOpen = false;

    feeTypeId;
    feeMode = "structure";
    isEditMode = false;
    seedLoaded = false;
    programmeId;
    learningProgramId;
    instituteId;
    linkedMappingCounter = 0;
    @track feeTypeLinkedMappings = [];
    programmeYearRangesById = {};
    batchIntake;
    activationDate;
    frequency;
    feeCategory;

    selectedRemittanceIds = [];
    paymentGatewayId;
    notes;

    oneTimeFeePlanId;
    oneTimeFeeHeadId;
    oneTimeCategoryId;
    oneTimeQuotaId;
    oneTimeFeeAssignmentTriggerPoint;
    oneTimeFeePlanTag;
    oneTimeAmount;
    oneTimeStartDate;
    oneTimeDueDate;
    oneTimeRemittanceOverrideId;
    oneTimeInstallmentId;
    oneTimePenaltyPlanId;
    previewTitle;
    termSystem = "Semester";
    termSystemOptions = [
        { label: "Semester", value: "Semester" },
        { label: "Trimester", value: "Trimester" },
        { label: "Quadmester", value: "Quadmester" }
    ];
    frequencyOptions = [
        { label: "One Time", value: "One Time" },
        { label: "Yearly", value: "Yearly" },
        { label: "Termly", value: "Termly" }
    ];

    connectedCallback() {
        this.loadSeedData();
    }

    @wire(CurrentPageReference)
    setPageReference(pageRef) {
        const nextId = pageRef?.state?.c__recordId || null;
        const requestedMode = pageRef?.state?.c__feeMode;
        this.feeMode = requestedMode === "type" ? "type" : "structure";
        this.feeTypeId = nextId;
        this.isEditMode = Boolean(nextId);
        if (this.seedLoaded && this.isEditMode) {
            this.loadEditData();
        }
    }

    async loadSeedData() {
        this.isLoading = true;
        try {
            const seed = await getBuilderSeedData();
            this.programmeOptions = seed?.programmeOptions || [];
            this.feePlanOptions = seed?.feePlanOptions || [];
            this.feeHeadOptions = seed?.feeHeadOptions || [];
            this.categoryOptions = seed?.categoryOptions || [];
            this.quotaOptions = seed?.quotaOptions || [];
            this.feeCategoryOptions = seed?.feeCategoryOptions || [];
            this.feeTypeCategoryOptions = this.feeCategoryOptions.filter(
                (option) => String(option?.value || "").trim().toLowerCase() !== "academics"
            );
            this.feePlanLabelById = {};
            this.feePlanOptions.forEach((option) => {
                if (option?.value) {
                    this.feePlanLabelById[option.value] = option.label;
                }
            });
            this.feeHeadLabelById = {};
            this.feeHeadOptions.forEach((option) => {
                if (option?.value) {
                    this.feeHeadLabelById[option.value] = option.label;
                }
            });
            this.categoryLabelById = {};
            this.categoryOptions.forEach((option) => {
                if (option?.value) {
                    this.categoryLabelById[option.value] = option.label;
                }
            });
            this.quotaLabelById = {};
            this.quotaOptions.forEach((option) => {
                if (option?.value) {
                    this.quotaLabelById[option.value] = option.label;
                }
            });
            this.remittanceOptions = seed?.remittanceOptions || [];
            this.remittanceMerchantIdsById = {};
            (seed?.remittanceMerchantRows || []).forEach((row) => {
                if (row?.remittanceId && row?.merchantIds) {
                    this.remittanceMerchantIdsById[row.remittanceId] = row.merchantIds;
                }
            });
            this.paymentGatewayOptions = seed?.paymentGatewayOptions || [];
            this.installmentOptions = seed?.installmentOptions || [];
            this.feeAssignmentTriggerPointOptions = seed?.feeAssignmentTriggerPointOptions || [];
            this.feeAssignmentTriggerPointLabelByValue = {};
            this.feeAssignmentTriggerPointOptions.forEach((option) => {
                if (option?.value) {
                    this.feeAssignmentTriggerPointLabelByValue[option.value] = option.label;
                }
            });
            this.installmentLabelById = {};
            this.installmentOptions.forEach((option) => {
                if (option?.value) {
                    this.installmentLabelById[option.value] = option.label;
                }
            });
            this.penaltyPlanOptions = seed?.penaltyPlanOptions || [];
            this.penaltyPlanLabelById = {};
            this.penaltyPlanOptions.forEach((option) => {
                if (option?.value) {
                    this.penaltyPlanLabelById[option.value] = option.label;
                }
            });
            this.programmeYearRangesById = {};
            (seed?.programmeYearRanges || []).forEach((row) => {
                this.programmeYearRangesById[row.programmeId] = {
                    startYear: row.startYear,
                    endYear: row.endYear
                };
            });
            this.seedLoaded = true;
            if (this.isEditMode && this.feeTypeId) {
                await this.loadEditData();
            } else {
                if (!this.frequency) {
                    this.frequency = "One Time";
                }
                this.initializeFeeTypeLinkedMappings();
                this.applyDefaultFeeCategory();
                this.regenerateConfigurationRows();
            }
        } catch (e) {
            this.toast("Error", "Unable to load programme fee configuration data.", "error");
        } finally {
            this.isLoading = false;
        }
    }

    async loadEditData() {
        if (!this.feeTypeId) {
            return;
        }
        try {
            const editData = await getProgrammeFeeConfigurationForEdit({ feeTypeId: this.feeTypeId });
            this.programmeId = editData?.programmeId || null;
            this.instituteId = editData?.instituteId || null;
            this.learningProgramId = editData?.learningProgramId || null;
            this.feeCategory = editData?.feeCategory || null;
            const normalizedCategory = String(this.feeCategory || "").trim().toLowerCase();
            if (normalizedCategory && normalizedCategory !== "academics") {
                this.feeMode = "type";
            } else {
                this.feeMode = "structure";
            }
            this.batchIntake = editData?.batchIntake || null;
            this.activationDate = editData?.activationDate || null;
            this.frequency = editData?.frequency || "One Time";
            this.termSystem = editData?.termSystem || "Semester";
            this.selectedRemittanceIds = Array.isArray(editData?.remittanceAccountIds)
                && editData.remittanceAccountIds.length
                ? editData.remittanceAccountIds
                : (editData?.defaultRemittanceId ? [editData.defaultRemittanceId] : []);
            this.paymentGatewayId = null;
            this.notes = editData?.notes || null;

            this.oneTimeFeePlanId = editData?.oneTimeFeePlanId || null;
            this.oneTimeFeeHeadId = editData?.oneTimeFeeHeadId || null;
            this.oneTimeCategoryId = editData?.oneTimeCategoryId || null;
            this.oneTimeQuotaId = editData?.oneTimeQuotaId || null;
            this.oneTimeFeeAssignmentTriggerPoint = editData?.oneTimeFeeAssignmentTriggerPoint || null;
            this.oneTimeFeePlanTag = editData?.oneTimeFeePlanTag || null;
            this.oneTimeAmount = editData?.oneTimeAmount ?? null;
            this.oneTimeStartDate = editData?.oneTimeStartDate || null;
            this.oneTimeDueDate = editData?.oneTimeDueDate || null;
            this.oneTimeRemittanceOverrideId = editData?.oneTimeRemittanceOverrideId || null;
            this.oneTimeInstallmentId = editData?.oneTimeInstallmentId || null;
            this.oneTimePenaltyPlanId = editData?.oneTimePenaltyPlanId || null;

            this.initializeFeeTypeLinkedMappings(editData?.linkedMappings || null);

            if (this.isOneTime) {
                this.termRows = [];
                return;
            }

            const rows = (editData?.configRows || []).map((row, index) => ({
                key: `${this.isYearly ? "year" : "term"}-${row.programYearNumber || index + 1}`,
                termLabel: this.getTermLabelFromRow(row),
                feePeriodLabel: this.getFeePeriodLabelFromRow(row),
                programYearNumber: row.programYearNumber || index + 1,
                academicYearLabel: row.academicYearLabel || this.getTermLabelFromRow(row),
                feePlanId: row.feePlanId || null,
                feeHeadId: row.feeHeadId || null,
                categoryId: row.categoryId || null,
                quotaId: row.quotaId || null,
                feeAssignmentTriggerPoint: row.feeAssignmentTriggerPoint || null,
                tag: row.tag || "",
                startDate: row.startDate || null,
                dueDate: row.dueDate || null,
                amount: row.amount ?? null,
                remittanceOverrideId: row.remittanceOverrideId || null,
                installmentId: row.installmentId || null,
                penaltyPlanId: row.penaltyPlanId || null,
                status: this.hasPrimaryConfigSelection(row) && row.dueDate ? "Planned" : "Not Planned"
            }));
            this.termRows = this.decorateTermRows(rows);
        } catch (error) {
            this.toast("Error", "Unable to load record for editing.", "error");
        }
    }

    getTermLabelFromRow(row) {
        const programYearNumber = Number(row?.programYearNumber || 1);
        if (this.isYearly) {
            const range = this.getChosenYearRange();
            const startYear = Number(range?.startYear);
            if (Number.isFinite(startYear)) {
                const fromYear = startYear + programYearNumber - 1;
                return `${fromYear}-${fromYear + 1}`;
            }
            return `Year ${programYearNumber}`;
        }
        return `${this.termSystem || "Term"} ${programYearNumber}`;
    }

    getFeePeriodLabelFromRow(row) {
        const programYearNumber = Number(row?.programYearNumber || 1);
        if (this.isYearly) {
            return `Year ${programYearNumber}`;
        }
        return this.getFeePeriodLabelForTerm(Math.ceil(programYearNumber / this.termsPerYear), programYearNumber);
    }

    handleProgrammeChange(event) {
        this.programmeId = event?.detail?.recordId || event?.detail?.value || null;
        const range = this.programmeYearRangesById[this.programmeId];
        this.batchIntake = this.formatBatchIntake(range);
        this.regenerateConfigurationRows();
    }

    initializeFeeTypeLinkedMappings(mappings) {
        if (!this.isFeeTypeMode) {
            this.feeTypeLinkedMappings = [];
            return;
        }
        this.linkedMappingCounter = 0;
        const sourceMappings = Array.isArray(mappings) && mappings.length
            ? mappings
            : this.buildDefaultLinkedMappingsFromSelectedIds();
        this.setFeeTypeLinkedMappings(
            sourceMappings.length
                ? sourceMappings.map((mapping) =>
                    this.createFeeTypeLinkedMappingRow(mapping?.linkedLevel, mapping?.linkedEntityId)
                )
                : [this.createFeeTypeLinkedMappingRow()]
        );
    }

    buildDefaultLinkedMappingsFromSelectedIds() {
        const mappings = [];
        if (this.programmeId) {
            mappings.push({
                linkedLevel: this.LINK_LEVEL_LEARNING_PROGRAM_PLAN,
                linkedEntityId: this.programmeId
            });
        }
        if (this.learningProgramId) {
            mappings.push({
                linkedLevel: this.LINK_LEVEL_LEARNING_PROGRAM,
                linkedEntityId: this.learningProgramId
            });
        }
        if (this.instituteId) {
            mappings.push({
                linkedLevel: this.LINK_LEVEL_INSTITUTE,
                linkedEntityId: this.instituteId
            });
        }
        return mappings;
    }

    createFeeTypeLinkedMappingRow(linkedLevel = "", linkedEntityId = null) {
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
        this.regenerateConfigurationRows();
    }

    handleInstituteChange(event) {
        this.handleLinkedEntityChangeForLevel(this.LINK_LEVEL_INSTITUTE, event);
    }

    handleLearningProgramChange(event) {
        this.handleLinkedEntityChangeForLevel(this.LINK_LEVEL_LEARNING_PROGRAM, event);
    }

    handleLearningProgramPlanChange(event) {
        this.handleLinkedEntityChangeForLevel(this.LINK_LEVEL_LEARNING_PROGRAM_PLAN, event);
    }

    handleLinkedEntityChangeForLevel(linkLevel, event) {
        const rowKey = event.target.dataset.key;
        const value = event?.detail?.recordId || event?.detail?.value || null;
        this.setFeeTypeLinkedMappings(
            this.feeTypeLinkedMappings.map((row) =>
                row.key === rowKey && row.linkedLevel === linkLevel
                    ? { ...row, linkedEntityId: value }
                    : row
            )
        );
        this.regenerateConfigurationRows();
    }

    handleAddLinkedLevel() {
        this.setFeeTypeLinkedMappings([...this.feeTypeLinkedMappings, this.createFeeTypeLinkedMappingRow()]);
    }

    handleRemoveLinkedLevel(event) {
        const rowKey = event.currentTarget.dataset.key;
        this.setFeeTypeLinkedMappings(this.feeTypeLinkedMappings.filter((row) => row.key !== rowKey));
        this.regenerateConfigurationRows();
    }

    handleBatchChange(event) {
        this.batchIntake = event.detail.value;
        if (this.isYearly) {
            this.generateYearRows();
        } else if (this.isTermWise) {
            this.generateTermRows();
        }
    }

    handleActivationDateChange(event) {
        this.activationDate = event.detail.value;
    }

    handleFrequencyChange(event) {
        this.frequency = event.detail.value;
        this.regenerateConfigurationRows();
    }

    handleFeeCategoryChange(event) {
        this.feeCategory = event.detail.value;
    }

    handleTermSystemChange(event) {
        this.termSystem = event.detail.value;
        if (this.isTermWise) {
            this.generateTermRows();
        }
    }

    handleRemittanceAccountsChange(event) {
        this.selectedRemittanceIds = event.detail.value || [];
    }

    handlePaymentGatewayChange(event) {
        this.paymentGatewayId = event.detail.value;
    }

    handleNotesChange(event) {
        this.notes = event.detail.value;
    }

    handleOneTimeFeePlanChange(event) {
        this.oneTimeFeePlanId = this.getSelectedValue(event);
    }

    handleOneTimeFeeHeadChange(event) {
        this.oneTimeFeeHeadId = this.getSelectedValue(event);
    }

    handleOneTimeCategoryChange(event) {
        this.oneTimeCategoryId = this.getSelectedValue(event);
        this.oneTimeQuotaId = null;
    }

    handleOneTimeQuotaChange(event) {
        this.oneTimeQuotaId = this.getSelectedValue(event);
    }

    handleOneTimeFeeAssignmentTriggerPointChange(event) {
        this.oneTimeFeeAssignmentTriggerPoint = event.detail.value;
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

    generateTermRows() {
        const termsPerYear = this.termsPerYear;
        const yearCount = this.getAcademicYearCount();
        const totalTerms = Math.max(termsPerYear * yearCount, 1);
        const labelPrefix = this.termSystem || "Term";
        const rows = [];
        for (let termNumber = 1; termNumber <= totalTerms; termNumber += 1) {
            const yearNumber = Math.ceil(termNumber / termsPerYear);
            rows.push({
                key: `term-${termNumber}`,
                termLabel: `${labelPrefix} ${termNumber}`,
                feePeriodLabel: this.getFeePeriodLabelForTerm(yearNumber, termNumber),
                academicYearLabel: "",
                feePlanId: null,
                feeHeadId: null,
                categoryId: null,
                quotaId: null,
                feeAssignmentTriggerPoint: null,
                tag: "",
                startDate: null,
                dueDate: null,
                programYearNumber: termNumber,
                installmentId: null,
                penaltyPlanId: null,
                status: "Not Planned"
            });
        }
        this.termRows = this.decorateTermRows(rows);
    }

    generateYearRows() {
        const chosenRange = this.getChosenYearRange();
        const startYear = Number(chosenRange?.startYear);
        const yearCount = this.getAcademicYearCount();

        const rows = [];
        for (let yearNumber = 1; yearNumber <= yearCount; yearNumber += 1) {
            let displayYear = "";
            if (Number.isFinite(startYear)) {
                const fromYear = startYear + yearNumber - 1;
                const toYear = fromYear + 1;
                displayYear = `${fromYear}-${toYear}`;
            }
            rows.push({
                key: `year-${yearNumber}`,
                termLabel: displayYear || `Year ${yearNumber}`,
                feePeriodLabel: `Year ${yearNumber}`,
                programYearNumber: yearNumber,
                academicYearLabel: displayYear || `Year ${yearNumber}`,
                feePlanId: null,
                feeHeadId: null,
                categoryId: null,
                quotaId: null,
                feeAssignmentTriggerPoint: null,
                tag: "",
                startDate: null,
                dueDate: null,
                installmentId: null,
                penaltyPlanId: null,
                status: "Not Planned"
            });
        }
        this.termRows = this.decorateTermRows(rows);
    }

    parseYearRange(value) {
        const text = String(value || "").trim();
        if (!text) {
            return null;
        }

        // Accept ranges like: 2024-28, 2024-2028, 2024/28, 2024–28, 2024 to 2028.
        const match = text.match(/(\d{4})\D+(\d{2,4})/);
        if (match) {
            const startYear = Number(match[1]);
            let endYear = Number(match[2]);

            if (!Number.isFinite(startYear) || !Number.isFinite(endYear)) {
                return null;
            }

            if (String(match[2]).length === 2) {
                const centuryBase = Math.floor(startYear / 100) * 100;
                endYear = centuryBase + endYear;
                if (endYear < startYear) {
                    endYear += 100;
                }
            }

            return { startYear, endYear };
        }

        const singleYear = text.match(/\b(\d{4})\b/);
        if (singleYear) {
            const year = Number(singleYear[1]);
            if (Number.isFinite(year)) {
                return { startYear: year, endYear: year };
            }
        }

        return null;
    }

    getChosenYearRange() {
        const batchRange = this.parseYearRange(this.batchIntake);
        const programmeRange = this.programmeYearRangesById[this.programmeId] || {};
        return batchRange
            || (Number.isFinite(Number(programmeRange.startYear)) || Number.isFinite(Number(programmeRange.endYear))
                ? { startYear: Number(programmeRange.startYear), endYear: Number(programmeRange.endYear) }
                : null);
    }

    getAcademicYearCount() {
        const chosenRange = this.getChosenYearRange();
        const startYear = Number(chosenRange?.startYear);
        const endYear = Number(chosenRange?.endYear);
        if (Number.isFinite(startYear) && Number.isFinite(endYear) && endYear >= startYear) {
            return Math.max(endYear - startYear, 1);
        }
        if (Number.isFinite(startYear)) {
            return 1;
        }
        return 1;
    }

    formatBatchIntake(range) {
        const startYear = Number(range?.startYear);
        const endYear = Number(range?.endYear);
        if (!Number.isFinite(startYear)) {
            return "";
        }
        if (!Number.isFinite(endYear) || endYear < startYear) {
            return String(startYear);
        }
        return `${startYear}-${String(endYear).slice(-2)}`;
    }

    regenerateConfigurationRows() {
        if (this.isTermWise) {
            this.generateTermRows();
            return;
        }
        if (this.isYearly) {
            this.generateYearRows();
            return;
        }
        this.termRows = [];
    }

    handleTermFieldChange(event) {
        const rowKey = event.target.dataset.rowKey;
        const field = event.target.dataset.field;
        const value = this.getSelectedValue(event);

        this.termRows = this.termRows.map((row) => {
            if (row.key !== rowKey) {
                return row;
            }
            const updated = {
                ...row,
                [field]: value,
                ...(field === "categoryId" ? { quotaId: null } : {})
            };
            if (this.hasPrimaryConfigSelection(updated) && updated.dueDate) {
                updated.status = "Planned";
            } else {
                updated.status = "Not Planned";
            }
            updated.quotaFilter = this.buildQuotaFilter(updated.categoryId);
            return updated;
        });
    }

    decorateTermRows(rows) {
        return (rows || []).map((row) => ({
            ...row,
            quotaFilter: this.buildQuotaFilter(row?.categoryId)
        }));
    }

    buildQuotaFilter(categoryId) {
        if (!categoryId) {
            return null;
        }
        return {
            criteria: [
                {
                    fieldPath: "Category__c",
                    operator: "eq",
                    value: categoryId
                }
            ]
        };
    }

    async handlePreviewTerms() {
        const configuredRows = (this.termRows || []).filter((row) => this.hasPrimaryConfigSelection(row));
        if (!configuredRows.length) {
            this.toast("Info", "Select a Fee Plan or Fee Head to preview.", "info");
            return;
        }

        if (this.isFeeTypeMode) {
            this.openFeeHeadPreview(configuredRows, "Preview - All Configured Rows");
            return;
        }

        try {
            const previewPromises = configuredRows.map((row) => getFeeSetPreview({ feeSetId: row.feePlanId }));
            const previewResults = await Promise.all(previewPromises);
            const mergedRows = [];
            let counter = 0;

            previewResults.forEach((rows, index) => {
                const configRow = configuredRows[index];
                (rows || []).forEach((previewRow) => {
                    counter += 1;
                    mergedRows.push({
                        ...previewRow,
                        configLabel: configRow.termLabel,
                        feePlanName: this.resolveFeePlanLabel(configRow.feePlanId),
                        feeAssignmentTriggerPointName: this.resolveFeeAssignmentTriggerPointLabel(
                            configRow.feeAssignmentTriggerPoint
                        ),
                        startDate: configRow.startDate || "-",
                        dueDate: configRow.dueDate || "-",
                        penaltyPlanName: this.resolvePenaltyPlanLabel(configRow.penaltyPlanId),
                        installmentName: this.resolveInstallmentLabel(configRow.installmentId),
                        previewKey: `${configRow.key}-${previewRow.rowKey || counter}-${counter}`
                    });
                });
            });

            this.previewRows = mergedRows;
            this.previewTitle = "Preview - All Configured Rows";
            this.isPreviewOpen = true;
        } catch (error) {
            this.toast("Error", "Unable to fetch preview rows.", "error");
        }
    }

    async handlePreviewTermRow(event) {
        const rowKey = event.currentTarget.dataset.rowKey;
        const selectedRow = this.termRows.find((row) => row.key === rowKey);
        if (!this.hasPrimaryConfigSelection(selectedRow)) {
            this.toast("Info", "Select a Fee Plan or Fee Head in this row to preview.", "info");
            return;
        }
        if (this.isFeeTypeMode) {
            this.openFeeHeadPreview([selectedRow], `Preview - ${selectedRow.termLabel || "Selected Row"}`);
            return;
        }
        await this.openPreviewForFeeSet(selectedRow);
    }

    async openPreviewForFeeSet(selectedRow) {
        const feeSetId = selectedRow?.feePlanId;
        const label = selectedRow?.termLabel || "Selected Row";
        try {
            const rows = await getFeeSetPreview({ feeSetId });
            let counter = 0;
            this.previewRows = (rows || []).map((row) => {
                counter += 1;
                return {
                    ...row,
                    configLabel: label,
                    feePlanName: this.resolveFeePlanLabel(selectedRow?.feePlanId),
                    feeAssignmentTriggerPointName: this.resolveFeeAssignmentTriggerPointLabel(
                        selectedRow?.feeAssignmentTriggerPoint
                    ),
                    startDate: selectedRow?.startDate || "-",
                    dueDate: selectedRow?.dueDate || "-",
                    penaltyPlanName: this.resolvePenaltyPlanLabel(selectedRow?.penaltyPlanId),
                    installmentName: this.resolveInstallmentLabel(selectedRow?.installmentId),
                    previewKey: `${label}-${row.rowKey || counter}-${counter}`
                };
            });
            this.previewTitle = `Preview - ${label}`;
            this.isPreviewOpen = true;
        } catch (error) {
            this.toast("Error", "Unable to fetch preview rows.", "error");
        }
    }

    closePreview() {
        this.isPreviewOpen = false;
        this.previewRows = [];
        this.previewTitle = null;
    }

    handleActivate() {
        if (this.isActivateDisabled) {
            return;
        }
        this.saveConfiguration(true);
    }

    handleSaveDraft() {
        this.saveConfiguration(false);
    }

    async saveConfiguration(activateNow) {
        if (this.isSaving) {
            return;
        }
        if (activateNow && this.isActivateDisabled) {
            this.toast("Error", "Fill all required fields before activating.", "error");
            return;
        }
        this.isSaving = true;
        try {
            const requestPayload = {
                feeTypeId: this.feeTypeId,
                isFeeTypeMode: this.isFeeTypeMode,
                linkLevel: this.primaryLinkLevel,
                programmeId: this.selectedContextRecordId,
                learningProgramId: this.isFeeTypeMode ? this.learningProgramId : null,
                instituteId: this.isFeeTypeMode ? this.instituteId : null,
                linkedMappings: this.isFeeTypeMode
                    ? (this.feeTypeLinkedMappings || [])
                        .filter((row) => row.linkedLevel && row.linkedEntityId)
                        .map((row) => ({
                            linkedLevel: row.linkedLevel,
                            linkedEntityId: row.linkedEntityId
                        }))
                    : [],
                feeCategory: this.feeCategoryForSave,
                batchIntake: this.batchIntake,
                activationDate: this.activationDate,
                frequency: this.frequency,
                termSystem: this.isTermWise ? this.termSystem : null,
                defaultRemittanceId: this.defaultRemittanceIdForSave,
                remittanceAccountIds: this.selectedRemittanceIds,
                paymentGatewayId: null,
                notes: this.notes,
                oneTimeFeePlanId: this.oneTimeFeePlanId,
                oneTimeFeeHeadId: this.oneTimeFeeHeadId,
                oneTimeCategoryId: this.oneTimeCategoryId,
                oneTimeQuotaId: this.oneTimeQuotaId,
                oneTimeFeeAssignmentTriggerPoint: this.oneTimeFeeAssignmentTriggerPoint,
                oneTimeFeePlanTag: this.oneTimeFeePlanTag,
                oneTimeAmount: this.oneTimeAmount,
                oneTimeStartDate: this.oneTimeStartDate,
                oneTimeDueDate: this.oneTimeDueDate,
                oneTimeRemittanceOverrideId: this.oneTimeRemittanceOverrideId,
                oneTimeInstallmentId: this.oneTimeInstallmentId,
                oneTimePenaltyPlanId: this.oneTimePenaltyPlanId,
                configRows: (this.termRows || []).map((row) => ({
                    programYearNumber: row.programYearNumber,
                    academicYearLabel: row.academicYearLabel || row.termLabel,
                    feePlanId: row.feePlanId,
                    feeHeadId: row.feeHeadId,
                    categoryId: row.categoryId,
                    quotaId: row.quotaId,
                    feeAssignmentTriggerPoint: row.feeAssignmentTriggerPoint,
                    tag: row.tag,
                    startDate: row.startDate,
                    dueDate: row.dueDate,
                    amount: row.amount,
                    remittanceOverrideId: row.remittanceOverrideId,
                    installmentId: row.installmentId,
                    penaltyPlanId: row.penaltyPlanId
                }))
            };

            const savedId = await saveProgrammeFeeConfiguration({
                requestJson: JSON.stringify(requestPayload),
                activateNow
            });

            this.toast(
                "Success",
                activateNow
                    ? (this.isFeeTypeMode ? "Fee type configuration activated." : "Programme fee configuration activated.")
                    : (this.isFeeTypeMode ? "Fee type configuration saved as draft." : "Programme fee configuration saved as draft."),
                "success"
            );

            if (savedId) {
                await this.navigateToProgrammeFeePublishingWithReload();
            }
        } catch (error) {
            this.toast("Error", this.parseError(error), "error");
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.handleGoToProgrammeFeePublishing();
    }

    handleGoToMasterData() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__masterDataLanding" }
        });
    }

    handleGoToProgrammeFeePublishing() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__programmeFeePublishingPage" },
            state: { c__tab: this.isFeeTypeMode ? "type" : "structure" }
        });
    }

    async navigateToProgrammeFeePublishingWithReload() {
        const pageReference = {
            type: "standard__component",
            attributes: { componentName: "c__programmeFeePublishingPage" },
            state: {
                c__refresh: Date.now().toString(),
                c__tab: this.isFeeTypeMode ? "type" : "structure"
            }
        };
        const generatedUrl = await this[NavigationMixin.GenerateUrl](pageReference);
        window.location.assign(generatedUrl);
    }

    get isOneTime() {
        const value = String(this.frequency || "").toLowerCase();
        return value.includes("one");
    }

    get isTermWise() {
        const value = String(this.frequency || "").toLowerCase();
        return value.includes("term") || value.includes("sem");
    }

    get isYearly() {
        const value = String(this.frequency || "").toLowerCase();
        return value.includes("year");
    }

    get showConfigRowsSection() {
        return this.isTermWise || this.isYearly;
    }

    get configSectionTitle() {
        return this.isYearly ? "Year Configuration" : "Term Configuration";
    }

    get configPrimaryLabel() {
        return this.isYearly ? "Year" : "Term";
    }

    get configRowsHint() {
        if (this.isYearly) {
            const range = this.parseYearRange(this.batchIntake)
                || this.programmeYearRangesById[this.programmeId]
                || {};
            if (range.startYear && range.endYear && Number(range.endYear) >= Number(range.startYear)) {
                return `${Math.max(Number(range.endYear) - Number(range.startYear), 1)} academic years configured`;
            }
            return `${this.termRows.length} year row${this.termRows.length === 1 ? "" : "s"} configured`;
        }
        if (this.isTermWise) {
            return `${this.termRows.length} ${String(this.termSystem || "Term").toLowerCase()} row${this.termRows.length === 1 ? "" : "s"} configured`;
        }
        return `${this.termRows.length} term row${this.termRows.length === 1 ? "" : "s"} configured`;
    }

    get isBatchAutoFilled() {
        if (this.isFeeTypeMode && !this.programmeId) {
            return false;
        }
        const range = this.programmeYearRangesById[this.programmeId];
        return Number.isFinite(Number(range?.startYear));
    }

    get hasPreviewRows() {
        return Array.isArray(this.previewRows) && this.previewRows.length > 0;
    }

    get hasContextValues() {
        return Boolean(
            this.selectedContextRecordId
                && (!this.isBatchIntakeRequired || this.batchIntake)
                && this.activationDate
                && this.frequency
                && this.feeCategoryForSave
        );
    }

    get isActivateDisabled() {
        if (this.isSaving) {
            return true;
        }
        if (!this.hasContextValues || !this.selectedRemittanceIds?.length) {
            return true;
        }

        if (this.isOneTime) {
            return !(this.oneTimePrimaryConfigId && this.oneTimeDueDate && this.hasRequiredAmount(this.oneTimeAmount));
        }

        if (this.showConfigRowsSection) {
            if (!this.termRows.length) {
                return true;
            }
            const configuredRows = this.termRows.filter(
                (row) => this.hasPrimaryConfigSelection(row) && row.dueDate && this.hasRequiredAmount(row.amount)
            );
            return configuredRows.length === 0;
        }

        return true;
    }

    get termsPerYear() {
        const current = String(this.termSystem || "").toLowerCase();
        if (current.includes("tri")) {
            return 3;
        }
        if (current.includes("quad")) {
            return 4;
        }
        return 2;
    }

    getFeePeriodLabelForTerm(yearNumber, termNumber) {
        const system = String(this.termSystem || "Semester").toLowerCase();
        if (system.includes("tri")) {
            return `Year ${yearNumber} Tri ${termNumber}`;
        }
        if (system.includes("quad")) {
            return `Year ${yearNumber} Quad ${termNumber}`;
        }
        return `Year ${yearNumber} Sem ${termNumber}`;
    }

    getSelectedValue(event) {
        return event?.detail?.recordId || event?.detail?.value || null;
    }

    get isSaveDraftDisabled() {
        return this.isSaving;
    }

    get pageTitle() {
        if (this.isFeeTypeMode) {
            return this.isEditMode ? "Edit Fee Type Configuration" : "New Fee Type Configuration";
        }
        return this.isEditMode ? "Edit Programme Fee Configuration" : "New Programme Fee Configuration";
    }

    get crumbActionLabel() {
        return this.isEditMode ? "Edit" : "New";
    }

    get selectedRemittanceMerchantIds() {
        if (!this.selectedRemittanceIds?.length) {
            return null;
        }
        const ids = new Set();
        this.selectedRemittanceIds.forEach((remittanceId) => {
            const merchants = this.remittanceMerchantIdsById[remittanceId];
            if (!merchants) {
                return;
            }
            String(merchants)
                .split(",")
                .map((value) => value.trim())
                .filter((value) => Boolean(value))
                .forEach((value) => ids.add(value));
        });
        return ids.size ? Array.from(ids).join(", ") : null;
    }

    get remittanceOverrideOptions() {
        if (!this.selectedRemittanceIds?.length) {
            return this.remittanceOptions;
        }
        const selectedSet = new Set(this.selectedRemittanceIds);
        return this.remittanceOptions.filter((option) => selectedSet.has(option.value));
    }

    get defaultRemittanceIdForSave() {
        return null;
    }

    get instituteAccountFilter() {
        return {
            criteria: [
                {
                    fieldPath: "RecordType.Name",
                    operator: "eq",
                    value: "Institute"
                }
            ]
        };
    }

    get isFeeTypeMode() {
        return this.feeMode === "type";
    }

    get showFeeCategoryPicklist() {
        return this.isFeeTypeMode;
    }

    get linkLevelOptions() {
        return this.allLinkLevelOptions;
    }

    get primaryLinkLevel() {
        if (this.programmeId) {
            return this.LINK_LEVEL_LEARNING_PROGRAM_PLAN;
        }
        if (this.learningProgramId) {
            return this.LINK_LEVEL_LEARNING_PROGRAM;
        }
        if (this.instituteId) {
            return this.LINK_LEVEL_INSTITUTE;
        }
        return this.LINK_LEVEL_LEARNING_PROGRAM_PLAN;
    }

    get allLinkLevelOptions() {
        return [
            { label: this.LINK_LEVEL_LEARNING_PROGRAM_PLAN, value: this.LINK_LEVEL_LEARNING_PROGRAM_PLAN },
            { label: this.LINK_LEVEL_LEARNING_PROGRAM, value: this.LINK_LEVEL_LEARNING_PROGRAM },
            { label: this.LINK_LEVEL_INSTITUTE, value: this.LINK_LEVEL_INSTITUTE }
        ];
    }

    get isLearningProgramPlanLinkLevel() {
        return this.hasLinkedLevel(this.LINK_LEVEL_LEARNING_PROGRAM_PLAN);
    }

    get isLearningProgramLinkLevel() {
        return this.hasLinkedLevel(this.LINK_LEVEL_LEARNING_PROGRAM);
    }

    get isInstituteLinkLevel() {
        return this.hasLinkedLevel(this.LINK_LEVEL_INSTITUTE);
    }

    hasLinkedLevel(linkLevel) {
        return (this.feeTypeLinkedMappings || []).some((row) => row.linkedLevel === linkLevel && row.linkedEntityId);
    }

    get selectedContextRecordId() {
        if (!this.isFeeTypeMode) {
            return this.programmeId;
        }
        return this.programmeId || this.learningProgramId || this.instituteId;
    }

    get isBatchIntakeRequired() {
        if (!this.isFeeTypeMode) {
            return true;
        }
        return Boolean(this.programmeId || this.learningProgramId);
    }

    get showFeeCategoryReadOnly() {
        return !this.isFeeTypeMode;
    }

    get feeCategoryReadOnlyLabel() {
        return this.resolveAcademicsCategoryValue() || "Academics";
    }

    get feeCategoryForSave() {
        if (this.isFeeTypeMode) {
            return this.feeCategory;
        }
        return this.resolveAcademicsCategoryValue() || this.feeCategory || "Academics";
    }

    applyDefaultFeeCategory() {
        if (this.isFeeTypeMode) {
            if (!this.feeCategory && this.feeTypeCategoryOptions.length) {
                this.feeCategory = this.feeTypeCategoryOptions[0].value;
            }
            return;
        }
        this.feeCategory = this.resolveAcademicsCategoryValue() || this.feeCategory || "Academics";
    }

    resolveAcademicsCategoryValue() {
        const academicsOption = (this.feeCategoryOptions || []).find(
            (option) => String(option?.value || "").trim().toLowerCase() === "academics"
        );
        return academicsOption?.value || null;
    }

    parseError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (Array.isArray(error?.body) && error.body.length && error.body[0]?.message) {
            return error.body[0].message;
        }
        return "Unable to save programme fee configuration.";
    }

    resolveInstallmentLabel(installmentId) {
        if (!installmentId) {
            return "-";
        }
        return this.installmentLabelById[installmentId] || installmentId;
    }

    resolveFeePlanLabel(feePlanId) {
        if (!feePlanId) {
            return "-";
        }
        return this.feePlanLabelById[feePlanId] || feePlanId;
    }

    resolveFeeHeadLabel(feeHeadId) {
        if (!feeHeadId) {
            return "-";
        }
        return this.feeHeadLabelById[feeHeadId] || feeHeadId;
    }

    hasPrimaryConfigSelection(row) {
        return Boolean(row?.feePlanId || row?.feeHeadId);
    }

    hasRequiredAmount(value) {
        if (!this.isFeeTypeMode) {
            return true;
        }
        return value !== null && value !== undefined && value !== "";
    }

    get oneTimePrimaryConfigId() {
        return this.isFeeTypeMode ? this.oneTimeFeeHeadId : this.oneTimeFeePlanId;
    }

    get feeConfigurationLabel() {
        return this.isFeeTypeMode ? "Fee Head" : "Fee Plan";
    }

    get isAddLinkedLevelDisabled() {
        return this.isSaving || (this.feeTypeLinkedMappings || []).length >= this.allLinkLevelOptions.length;
    }

    get feeTagLabel() {
        return this.isFeeTypeMode ? "Fee Head Tag" : "Fee Plan Tag";
    }

    get feeConfigurationOptions() {
        return this.isFeeTypeMode ? this.feeHeadOptions : this.feePlanOptions;
    }

    get oneTimeQuotaFilter() {
        return this.buildQuotaFilter(this.oneTimeCategoryId);
    }

    resolvePrimaryConfigurationLabel(row) {
        if (row?.feeHeadId) {
            return this.resolveFeeHeadLabel(row.feeHeadId);
        }
        return this.resolveFeePlanLabel(row?.feePlanId);
    }

    openFeeHeadPreview(rows, title) {
        let counter = 0;
        const selectedRows = rows || [];
        this.previewRows = selectedRows.map((row) => {
            counter += 1;
            return {
                configLabel: row.termLabel || "-",
                feePlanName: this.resolvePrimaryConfigurationLabel(row),
                feeAssignmentTriggerPointName: this.resolveFeeAssignmentTriggerPointLabel(row.feeAssignmentTriggerPoint),
                startDate: row.startDate || "-",
                dueDate: row.dueDate || "-",
                studentCategory: "-",
                feeHeadName: this.resolveFeeHeadLabel(row.feeHeadId),
                amount: "-",
                remittanceAccountName: "-",
                installmentName: this.resolveInstallmentLabel(row.installmentId),
                penaltyPlanName: this.resolvePenaltyPlanLabel(row.penaltyPlanId),
                previewKey: `${row.key || "row"}-${counter}`
            };
        });
        this.previewTitle = title;
        this.isPreviewOpen = true;
    }

    resolveFeeAssignmentTriggerPointLabel(triggerPointValue) {
        if (!triggerPointValue) {
            return "-";
        }
        return this.feeAssignmentTriggerPointLabelByValue[triggerPointValue] || triggerPointValue;
    }

    resolvePenaltyPlanLabel(penaltyPlanId) {
        if (!penaltyPlanId) {
            return "-";
        }
        return this.penaltyPlanLabelById[penaltyPlanId] || penaltyPlanId;
    }

    get previewSummary() {
        if (!this.previewRows?.length) {
            return "No line items to preview.";
        }
        const configCount = new Set(this.previewRows.map((row) => row.configLabel)).size;
        return `${configCount} configured row${configCount === 1 ? "" : "s"} • ${this.previewRows.length} fee line item${this.previewRows.length === 1 ? "" : "s"}`;
    }

    toast(title, message, variant) {
        const normalizedVariant =
            variant === "success" ? "success" : variant === "info" ? "info" : variant === "warning" ? "warning" : "error";
        this.notification = {
            title,
            message,
            containerClass: `noticeBanner noticeBanner${normalizedVariant.charAt(0).toUpperCase()}${normalizedVariant.slice(1)}`,
            iconName:
                normalizedVariant === "success"
                    ? "utility:success"
                    : normalizedVariant === "info"
                      ? "utility:info"
                      : normalizedVariant === "warning"
                        ? "utility:warning"
                        : "utility:error"
        };
    }

    dismissNotification() {
        this.notification = null;
    }
}