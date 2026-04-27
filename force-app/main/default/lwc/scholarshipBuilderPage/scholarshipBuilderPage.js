import { LightningElement, track, wire } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import getScholarshipBuilderData from "@salesforce/apex/ScholarshipsController.getScholarshipBuilderData";
import getLinkedEntityOptions from "@salesforce/apex/ScholarshipsController.getLinkedEntityOptions";
import saveScholarship from "@salesforce/apex/ScholarshipsController.saveScholarship";

export default class ScholarshipBuilderPage extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track isSaving = false;

    @track typeOptions = [];
    @track valueTypeOptions = [];
    @track calculationTypeOptions = [];
    @track currencyOptions = [];
    @track linkedMappings = [];

    @track scholarshipName = "";
    @track typeValue = "";
    @track valueTypeValue = "";
    @track calculationTypeValue = "";
    @track fixedValue = null;
    @track rangeStartValue = null;
    @track rangeEndValue = null;
    @track currencyIsoCode = "";
    @track descriptionValue = "";

    recordId = null;
    cloneId = null;
    hasLoaded = false;
    linkedMappingCounter = 0;

    linkedLevelOptions = [
        { label: "Program Level", value: "Program Level" },
        { label: "Fee Head Level", value: "Fee Head Level" },
        { label: "Category Level", value: "Category Level" }
    ];

    @wire(CurrentPageReference)
    setPageReference(pageRef) {
        const nextRecordId = pageRef?.state?.c__recordId || null;
        const nextCloneId = pageRef?.state?.c__cloneId || null;
        if (this.hasLoaded && this.recordId === nextRecordId && this.cloneId === nextCloneId) {
            return;
        }
        this.recordId = nextRecordId;
        this.cloneId = nextCloneId;
        this.initializeForm();
    }

    async initializeForm() {
        this.isLoading = true;
        try {
            const sourceId = this.recordId || this.cloneId;
            const result = await getScholarshipBuilderData({ scholarshipId: sourceId });

            this.typeOptions = result?.typeOptions || [];
            this.valueTypeOptions = result?.valueTypeOptions || [];
            this.calculationTypeOptions = result?.calculationTypeOptions || [];
            this.currencyOptions = result?.currencyOptions || [];

            const row = result?.record;
            if (row) {
                this.scholarshipName = this.cloneId ? `${row.name || ""} - Copy` : row.name || "";
                this.typeValue = row.type || this.getFirstValue(this.typeOptions);
                this.valueTypeValue = row.valueType || this.getFirstValue(this.valueTypeOptions);
                this.calculationTypeValue = row.calculationType || this.getFirstValue(this.calculationTypeOptions);
                this.fixedValue = row.fixedValue;
                this.rangeStartValue = row.rangeStartValue;
                this.rangeEndValue = row.rangeEndValue;
                this.currencyIsoCode = row.currencyIsoCode || this.getFirstValue(this.currencyOptions);
                this.descriptionValue = row.description || "";
                await this.initializeLinkedMappings(row);
            } else {
                this.resetFormWithDefaults();
            }
        } catch (error) {
            this.toast("Error", this.getErrorMessage(error), "error");
            this.resetFormWithDefaults();
        } finally {
            this.hasLoaded = true;
            this.isLoading = false;
        }
    }

    resetFormWithDefaults() {
        this.scholarshipName = "";
        this.typeValue = this.getFirstValue(this.typeOptions);
        this.valueTypeValue = this.getFirstValue(this.valueTypeOptions);
        this.calculationTypeValue = this.getFirstValue(this.calculationTypeOptions);
        this.fixedValue = null;
        this.rangeStartValue = null;
        this.rangeEndValue = null;
        this.currencyIsoCode = this.getFirstValue(this.currencyOptions);
        this.descriptionValue = "";
        this.linkedMappingCounter = 0;
        this.setLinkedMappings([this.createLinkedMappingRow()]);
    }

    getFirstValue(options) {
        return Array.isArray(options) && options.length ? options[0].value : "";
    }

    handleGoToMasterData() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__masterDataLanding" }
        });
    }

    handleGoToScholarships() {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__scholarshipsPage" }
        });
    }

    handleCancel() {
        if (this.isSaving) {
            return;
        }
        this.handleGoToScholarships();
    }

    handleFieldChange(event) {
        const fieldName = event.target.name;
        const fieldValue = event.detail?.value !== undefined ? event.detail.value : event.target.value;

        if (fieldName === "scholarshipName") {
            this.scholarshipName = fieldValue;
        } else if (fieldName === "type") {
            this.typeValue = fieldValue;
        } else if (fieldName === "valueType") {
            this.valueTypeValue = fieldValue;
            if (this.isRangeValueType) {
                this.fixedValue = null;
            } else {
                this.rangeStartValue = null;
                this.rangeEndValue = null;
            }
        } else if (fieldName === "calculationType") {
            this.calculationTypeValue = fieldValue;
        } else if (fieldName === "fixedValue") {
            this.fixedValue = fieldValue;
        } else if (fieldName === "rangeStartValue") {
            this.rangeStartValue = fieldValue;
        } else if (fieldName === "rangeEndValue") {
            this.rangeEndValue = fieldValue;
        } else if (fieldName === "currencyIsoCode") {
            this.currencyIsoCode = fieldValue;
        } else if (fieldName === "description") {
            this.descriptionValue = fieldValue;
        }
    }

    createLinkedMappingRow(linkedLevel = "", selectedLinkedEntityIds = []) {
        this.linkedMappingCounter += 1;
        return {
            key: `linked-mapping-${this.linkedMappingCounter}`,
            linkedLevel,
            selectedLinkedEntityIds: Array.isArray(selectedLinkedEntityIds) ? [...selectedLinkedEntityIds] : [],
            linkedEntityOptions: [],
            linkedEntityLabel: this.getLinkedEntityLabelForLevel(linkedLevel),
            isLoadingOptions: false,
            isLinkedEntityDisabled: true,
            removeDisabled: true,
            rowIndex: 1,
            availableLinkedLevelOptions: [...this.linkedLevelOptions]
        };
    }

    setLinkedMappings(rows) {
        const sourceRows = Array.isArray(rows) && rows.length ? rows : [this.createLinkedMappingRow()];
        const canRemoveRows = sourceRows.length > 1;

        this.linkedMappings = sourceRows.map((row, index) => {
            const usedLevelsByOtherRows = new Set(
                sourceRows
                    .filter((candidate) => candidate.key !== row.key && candidate.linkedLevel)
                    .map((candidate) => candidate.linkedLevel)
            );
            const availableLinkedLevelOptions = this.linkedLevelOptions.filter((option) => {
                return option.value === row.linkedLevel || !usedLevelsByOtherRows.has(option.value);
            });

            return {
                ...row,
                linkedEntityLabel: this.getLinkedEntityLabelForLevel(row.linkedLevel),
                isLinkedEntityDisabled: !row.linkedLevel || row.isLoadingOptions || this.isSaving,
                removeDisabled: !canRemoveRows || this.isSaving,
                rowIndex: index + 1,
                availableLinkedLevelOptions
            };
        });
    }

    async initializeLinkedMappings(row) {
        const sourceMappings = Array.isArray(row?.linkedMappings) ? row.linkedMappings : [];
        const normalizedMappings = sourceMappings
            .map((mapping) => this.createLinkedMappingRow(mapping?.linkedLevel || "", mapping?.linkedEntityIds || []))
            .filter((mapping) => mapping.linkedLevel || mapping.selectedLinkedEntityIds.length > 0);

        if (!normalizedMappings.length && row?.linkedLevel) {
            normalizedMappings.push(this.createLinkedMappingRow(row.linkedLevel, row.linkedEntityIds || []));
        }

        this.setLinkedMappings(normalizedMappings.length ? normalizedMappings : [this.createLinkedMappingRow()]);

        const optionLoadingJobs = this.linkedMappings
            .filter((mapping) => !!mapping.linkedLevel)
            .map((mapping) => this.loadLinkedEntityOptionsForMapping(mapping.key, mapping.linkedLevel));
        if (optionLoadingJobs.length) {
            await Promise.all(optionLoadingJobs);
        }
    }

    async loadLinkedEntityOptionsForMapping(mappingKey, linkedLevel) {
        if (!linkedLevel) {
            const clearedMappings = this.linkedMappings.map((mapping) => {
                if (mapping.key !== mappingKey) {
                    return mapping;
                }
                return {
                    ...mapping,
                    linkedEntityOptions: [],
                    selectedLinkedEntityIds: [],
                    isLoadingOptions: false
                };
            });
            this.setLinkedMappings(clearedMappings);
            return;
        }

        const loadingMappings = this.linkedMappings.map((mapping) => {
            if (mapping.key !== mappingKey) {
                return mapping;
            }
            return {
                ...mapping,
                isLoadingOptions: true,
                linkedEntityOptions: []
            };
        });
        this.setLinkedMappings(loadingMappings);

        try {
            const rows = await getLinkedEntityOptions({ linkedLevel });
            const options = (Array.isArray(rows) ? rows : []).map((rowData) => ({
                label: rowData.label,
                value: rowData.value
            }));
            const validIds = new Set(options.map((option) => option.value));

            const updatedMappings = this.linkedMappings.map((mapping) => {
                if (mapping.key !== mappingKey || mapping.linkedLevel !== linkedLevel) {
                    return mapping;
                }
                return {
                    ...mapping,
                    linkedEntityOptions: options,
                    selectedLinkedEntityIds: (mapping.selectedLinkedEntityIds || []).filter((id) => validIds.has(id)),
                    isLoadingOptions: false
                };
            });
            this.setLinkedMappings(updatedMappings);
        } catch (error) {
            const erroredMappings = this.linkedMappings.map((mapping) => {
                if (mapping.key !== mappingKey) {
                    return mapping;
                }
                return {
                    ...mapping,
                    linkedEntityOptions: [],
                    selectedLinkedEntityIds: [],
                    isLoadingOptions: false
                };
            });
            this.setLinkedMappings(erroredMappings);
            this.toast("Error", this.getErrorMessage(error), "error");
        }
    }

    handleAddLinkedLevel() {
        if (this.linkedMappings.length >= this.linkedLevelOptions.length) {
            this.toast("Info", "All linked levels are already added.", "info");
            return;
        }
        this.setLinkedMappings([...this.linkedMappings, this.createLinkedMappingRow()]);
    }

    handleRemoveLinkedLevel(event) {
        const mappingKey = event.currentTarget.dataset.key;
        if (!mappingKey) {
            return;
        }
        const remainingRows = this.linkedMappings.filter((mapping) => mapping.key !== mappingKey);
        this.setLinkedMappings(remainingRows);
    }

    async handleLinkedLevelChange(event) {
        const mappingKey = event.currentTarget.dataset.key;
        const linkedLevel = event.detail?.value || event.target.value || "";
        if (!mappingKey) {
            return;
        }

        const updatedMappings = this.linkedMappings.map((mapping) => {
            if (mapping.key !== mappingKey) {
                return mapping;
            }
            return {
                ...mapping,
                linkedLevel,
                selectedLinkedEntityIds: [],
                linkedEntityOptions: [],
                isLoadingOptions: false
            };
        });
        this.setLinkedMappings(updatedMappings);
        await this.loadLinkedEntityOptionsForMapping(mappingKey, linkedLevel);
    }

    handleLinkedEntitySelectionChange(event) {
        const mappingKey = event.currentTarget.dataset.key;
        const selectedValues = Array.isArray(event.detail?.value) ? event.detail.value : [];
        if (!mappingKey) {
            return;
        }

        const updatedMappings = this.linkedMappings.map((mapping) => {
            if (mapping.key !== mappingKey) {
                return mapping;
            }
            return {
                ...mapping,
                selectedLinkedEntityIds: selectedValues
            };
        });
        this.setLinkedMappings(updatedMappings);
    }

    handleSaveDraft() {
        this.saveRecord("Draft");
    }

    handleActivate() {
        this.saveRecord("Active");
    }

    handleFooterSave() {
        this.saveRecord(this.isEditMode ? "Active" : "Draft");
    }

    async saveRecord(statusAction) {
        const nameValue = (this.scholarshipName || "").trim();
        if (!nameValue) {
            this.toast("Error", "Scholarship Name is required.", "error");
            return;
        }
        if (!this.typeValue) {
            this.toast("Error", "Type is required.", "error");
            return;
        }
        if (!this.valueTypeValue) {
            this.toast("Error", "Value Type is required.", "error");
            return;
        }
        if (!this.calculationTypeValue) {
            this.toast("Error", "Calculation Type is required.", "error");
            return;
        }
        if (!this.currencyIsoCode) {
            this.toast("Error", "Currency is required.", "error");
            return;
        }

        const normalizedFixedValue = this.fixedValue === "" || this.fixedValue === null ? null : Number(this.fixedValue);
        const normalizedRangeStart = this.rangeStartValue === "" || this.rangeStartValue === null
            ? null
            : Number(this.rangeStartValue);
        const normalizedRangeEnd = this.rangeEndValue === "" || this.rangeEndValue === null
            ? null
            : Number(this.rangeEndValue);

        if (this.isRangeValueType) {
            if (normalizedRangeStart === null || normalizedRangeEnd === null) {
                this.toast("Error", "Range Start Value and Range End Value are required.", "error");
                return;
            }
            if (normalizedRangeEnd < normalizedRangeStart) {
                this.toast("Error", "Range End Value must be greater than or equal to Range Start Value.", "error");
                return;
            }
        } else if (normalizedFixedValue === null) {
            this.toast("Error", "Fixed Value is required.", "error");
            return;
        }

        const linkedMappingsPayload = this.linkedMappings
            .map((mapping) => ({
                linkedLevel: mapping.linkedLevel || null,
                linkedEntityIds: Array.isArray(mapping.selectedLinkedEntityIds) ? mapping.selectedLinkedEntityIds : []
            }))
            .filter((mapping) => mapping.linkedLevel && mapping.linkedEntityIds.length > 0);
        const firstLinkedMapping = linkedMappingsPayload.length ? linkedMappingsPayload[0] : null;

        this.isSaving = true;
        this.setLinkedMappings(this.linkedMappings);
        try {
            const savedId = await saveScholarship({
                requestJson: JSON.stringify({
                    id: this.isEditMode ? this.recordId : null,
                    name: nameValue,
                    type: this.typeValue,
                    valueType: this.valueTypeValue,
                    calculationType: this.calculationTypeValue,
                    fixedValue: this.isRangeValueType ? null : normalizedFixedValue,
                    rangeStartValue: this.isRangeValueType ? normalizedRangeStart : null,
                    rangeEndValue: this.isRangeValueType ? normalizedRangeEnd : null,
                    currencyIsoCode: this.currencyIsoCode,
                    description: this.descriptionValue,
                    linkedLevel: firstLinkedMapping ? firstLinkedMapping.linkedLevel : null,
                    linkedEntityIds: firstLinkedMapping ? firstLinkedMapping.linkedEntityIds : [],
                    linkedMappings: linkedMappingsPayload,
                    statusAction
                })
            });

            this.toast("Success", "Scholarship saved successfully.", "success");
            this.navigateToDetails(savedId);
        } catch (error) {
            this.toast("Error", this.getErrorMessage(error), "error");
        } finally {
            this.isSaving = false;
            this.setLinkedMappings(this.linkedMappings);
        }
    }

    navigateToDetails(recordId) {
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: { componentName: "c__scholarshipDetailsPage" },
            state: { c__recordId: recordId }
        });
    }

    get isEditMode() {
        return !!this.recordId;
    }

    get isCloneMode() {
        return !this.recordId && !!this.cloneId;
    }

    get pageTitle() {
        if (this.isEditMode) {
            return "Edit Scholarship";
        }
        if (this.isCloneMode) {
            return "Clone Scholarship";
        }
        return "New Scholarship";
    }

    get crumbActionLabel() {
        if (this.isEditMode) {
            return "Edit Scholarship";
        }
        if (this.isCloneMode) {
            return "Clone Scholarship";
        }
        return "New Scholarship";
    }

    get isRangeValueType() {
        return (this.valueTypeValue || "").toLowerCase().includes("range");
    }

    get isFixedValueType() {
        return !this.isRangeValueType;
    }

    getLinkedEntityLabelForLevel(linkedLevelValue) {
        if (linkedLevelValue === "Program Level") {
            return "Program Plans";
        }
        if (linkedLevelValue === "Fee Head Level") {
            return "Fee Heads";
        }
        if (linkedLevelValue === "Category Level") {
            return "Categories";
        }
        return "Linked Records";
    }

    get isAddLinkedLevelDisabled() {
        return this.isSaving || this.linkedMappings.length >= this.linkedLevelOptions.length;
    }

    getErrorMessage(error) {
        return error?.body?.message || "Unexpected error occurred.";
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}