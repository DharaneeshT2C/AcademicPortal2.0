import { LightningElement, api, track, wire } from 'lwc';
import { initBrand } from 'c/brandConfigService';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import KEN_EVAL_SCHEMA_COMPONENT_OBJECT from '@salesforce/schema/Ken_Evaluation_Schema_Component__c';
import KEN_ASSESSMENT_FIELD from '@salesforce/schema/Ken_Evaluation_Schema_Component__c.Ken_Assessment__c';

const SUB_COMPONENT_RECORDTYPE_LABEL = 'Ken Evaluation Schema Sub Component';

const ENROLLMENT_OPTIONS = [
    { label: 'Auto', value: 'Auto' },
    { label: 'Manual', value: 'Manual' }
];

const REGULAR_COMPONENT_OPTIONS = [
    { label: 'Internal', value: 'Internal' },
    { label: 'External', value: 'External' }
];

const RETEST_COMPONENT_OPTIONS = [
    { label: 'Makeup', value: 'Makeup' },
    { label: 'Re-Test', value: 'Re-Test' },
    { label: 'Supplementary', value: 'Supplementary' }
];

const EMPTY_SCHEMA = {
    id: null,
    name: '',
    description: '',
    totalMarks: 0,
    passingMarks: 40,
    coursesApplied: 0,
    isRequiredForGrading: true,
    components: []
};

// CSS class shorthands
const CLS = {
    input:     'esw-input esw-input--sm',
    inputErr:  'esw-input esw-input--sm esw-input--error',
    select:    'esw-select esw-select--sm',
    selectErr: 'esw-select esw-select--sm esw-input--error',
};

function clone(v) { return JSON.parse(JSON.stringify(v)); }

function normalizeNumber(value) {
    if (value === '' || value === null || value === undefined) return null;
    const n = Number(value);
    return Number.isFinite(n) ? n : null;
}

function toNumberOrZero(value) {
    const n = Number(value);
    return Number.isFinite(n) ? n : 0;
}

export default class EvaluationSchemaWizard extends LightningElement {
    _schemaRecord;
    componentCounter    = 0;
    subComponentCounter = 0;
    saveAttempted       = false;
    subComponentRecordTypeId;

    @track draftSchema     = clone(EMPTY_SCHEMA);
    @track components      = [];
    @track retestEnabled   = false;
    @track retestComponents = [];
    @track validationErrors = [];
    @track assessmentOptions = [];

    // Schema-level inline errors
    @track _schemaNameError = null;

    enrollmentOptions = ENROLLMENT_OPTIONS;

    get regularComponentOptions() { return REGULAR_COMPONENT_OPTIONS; }
    get retestComponentOptions()  { return RETEST_COMPONENT_OPTIONS;  }

    // ── Wire ─────────────────────────────────────────────────────────────────

    @wire(getObjectInfo, { objectApiName: KEN_EVAL_SCHEMA_COMPONENT_OBJECT })
    wiredSchemaComponentObjectInfo({ data, error }) {
        if (data) {
            const rtInfos = data.recordTypeInfos || {};
            const subRtId = Object.keys(rtInfos).find(rtId => rtInfos[rtId]?.name === SUB_COMPONENT_RECORDTYPE_LABEL);
            this.subComponentRecordTypeId = subRtId || data.defaultRecordTypeId;
        }
        if (error) {
            console.error('Failed to load object info for assessment picklist', error);
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$subComponentRecordTypeId', fieldApiName: KEN_ASSESSMENT_FIELD })
    wiredAssessmentPicklist({ data, error }) {
        if (data?.values) {
            this.assessmentOptions = data.values.map(v => ({ label: v.label, value: v.value }));
        }
        if (error) {
            console.error('Failed to load assessment picklist values', error);
        }
    }

    // ── @api ─────────────────────────────────────────────────────────────────

    @api
    get schemaRecord() { return this._schemaRecord; }
    set schemaRecord(value) {
        this._schemaRecord = value ? clone(value) : null;
        this.initializeState();
    }

    connectedCallback() {
        initBrand(this.template.host);
        this.initializeState();
    }

    renderedCallback() {
        // LWC's `value` binding on native <select> does not reliably pre-select
        // an option when (a) data is loaded after first render or (b) options come
        // from an async @wire. Sync the DOM manually after every render cycle.
        this._syncSelectValues();
    }

    _syncSelectValues() {
        this.template.querySelectorAll('select[data-field="kenComponent"]').forEach(sel => {
            const comp = this._findComp(sel.dataset.group, sel.dataset.compId);
            if (comp) sel.value = comp.kenComponent || '';
        });
        this.template.querySelectorAll('select[data-field="kenAssessment"]').forEach(sel => {
            const sub = this._findSub(sel.dataset.group, sel.dataset.compId, sel.dataset.subId);
            if (sub) sel.value = sub.kenAssessment || '';
        });
    }

    _findComp(group, compId) {
        return this._getGroupComponents(group || 'regular').find(c => c.uiId === compId);
    }

    _findSub(group, compId, subId) {
        const comp = this._findComp(group, compId);
        return comp ? comp.subComponents.find(s => s.uiId === subId) : null;
    }

    // ── Computed ──────────────────────────────────────────────────────────────

    get title() {
        return this.draftSchema.id ? 'Edit Evaluation Schema' : 'Create Evaluation Schema';
    }

    get disableSave() {
        return this.saveAttempted && this.validationErrors.length > 0;
    }

    // Inline error getters — only surface after first save attempt
    get schemaNameError() { return this.saveAttempted ? this._schemaNameError : null; }

    get schemaNameInputClass() {
        return (this.saveAttempted && this._schemaNameError) ? CLS.inputErr : CLS.input;
    }

    // ── Init ──────────────────────────────────────────────────────────────────

    initializeState() {
        const source = this._schemaRecord ? clone(this._schemaRecord) : clone(EMPTY_SCHEMA);
        this.componentCounter    = 0;
        this.subComponentCounter = 0;
        this.saveAttempted       = false;
        this._schemaNameError    = null;
        this.validationErrors    = [];

        this.draftSchema = {
            id:                 source.id || null,
            name:               source.name || '',
            description:        source.description || '',
            totalMarks:         source.totalMarks ?? 0,
            passingMarks:       source.passingMarks ?? 40,
            coursesApplied:     source.coursesApplied || 0,
            isRequiredForGrading:
                source.isRequiredForGrading != null
                    ? !!source.isRequiredForGrading
                    : source.Ken_Is_Required_for_Grading__c != null
                        ? !!source.Ken_Is_Required_for_Grading__c
                        : true
        };

        const allSrc       = source.components && source.components.length ? source.components : [];
        const regularSrc   = allSrc.filter(c => c.examType !== 'Retest');
        const retestSrc    = allSrc.filter(c => c.examType === 'Retest');

        this.components = regularSrc.length
            ? regularSrc.map(c => this.normalizeComponent(c))
            : [this.createComponent('Regular')];

        if (retestSrc.length) {
            this.retestEnabled    = true;
            this.retestComponents = retestSrc.map(c => this.normalizeComponent(c));
        } else {
            this.retestEnabled    = false;
            this.retestComponents = [];
        }
    }

    // ── ID counters ───────────────────────────────────────────────────────────

    nextComponentId()    { return `cmp-${++this.componentCounter}`; }
    nextSubComponentId() { return `sub-${++this.subComponentCounter}`; }

    // ── Factory ───────────────────────────────────────────────────────────────

    createComponent(examType = 'Regular') {
        return {
            uiId: this.nextComponentId(),
            id: null,
            kenComponent: null,
            examType,
            effectiveMarks: 0,
            maxMarks: null,
            minMarks: 0,
            passingMarks: null,
            weightage: null,
            enrollmentType: 'Auto',
            considerForPassFail: false,
            kenComponentInputClass:  CLS.select,
            effectiveMarksInputClass: CLS.input,
            kenComponentError:        null,
            effectiveMarksError:      null,
            subComponents: [this.createSubComponent(examType)]
        };
    }

    createSubComponent(examType = 'Regular') {
        return {
            uiId: this.nextSubComponentId(),
            id: null,
            kenAssessment: null,
            examType,
            effectiveMarks: null,
            maxMarks: null,
            minMarks: 0,
            passingMarks: null,
            weightage: null,
            enrollmentType: 'Auto',
            considerForPassFail: false,
            examRequired: true,
            kenAssessmentInputClass: CLS.select,
            kenAssessmentError:      null,
            subEffectiveInputClass:  CLS.input,
            subEffectiveError:       null,
        };
    }

    normalizeComponent(component) {
        const examType = component.examType || component.Ken_Exam_Type__c || 'Regular';
        const normalizedSubs = component.subComponents && component.subComponents.length
            ? component.subComponents.map(s => this.normalizeSubComponent(s, examType))
            : [this.createSubComponent(examType)];
        return {
            ...component,
            uiId: this.nextComponentId(),
            kenComponent:     component.kenComponent || component.Ken_Components__c || null,
            examType,
            effectiveMarks:   toNumberOrZero(component.effectiveMarks),
            maxMarks:         normalizeNumber(component.maxMarks),
            minMarks:         normalizeNumber(component.minMarks) ?? 0,
            passingMarks:     normalizeNumber(component.passingMarks),
            weightage:        normalizeNumber(component.weightage),
            enrollmentType:   component.enrollmentType || 'Auto',
            considerForPassFail: !!component.considerForPassFail,
            kenComponentInputClass:   CLS.select,
            effectiveMarksInputClass: CLS.input,
            kenComponentError:        null,
            effectiveMarksError:      null,
            subComponents: normalizedSubs
        };
    }

    normalizeSubComponent(sub, defaultExamType = 'Regular') {
        return {
            ...sub,
            uiId:          this.nextSubComponentId(),
            kenAssessment: sub.kenAssessment || sub.Ken_Assessment__c || null,
            examType:      sub.examType || sub.Ken_Exam_Type__c || defaultExamType,
            effectiveMarks: normalizeNumber(sub.effectiveMarks),
            maxMarks:       normalizeNumber(sub.maxMarks),
            minMarks:       normalizeNumber(sub.minMarks) ?? 0,
            passingMarks:   normalizeNumber(sub.passingMarks),
            weightage:      normalizeNumber(sub.weightage),
            enrollmentType: sub.enrollmentType || 'Auto',
            considerForPassFail: !!sub.considerForPassFail,
            examRequired: sub.examRequired != null
                ? !!sub.examRequired
                : sub.Ken_Is_Exam_Required__c != null ? !!sub.Ken_Is_Exam_Required__c : true,
            kenAssessmentInputClass: CLS.select,
            kenAssessmentError:      null,
            subEffectiveInputClass:  CLS.input,
            subEffectiveError:       null,
        };
    }

    // ── Group helpers ─────────────────────────────────────────────────────────

    _getGroupComponents(group) {
        return group === 'retest' ? this.retestComponents : this.components;
    }
    _setGroupComponents(group, arr) {
        if (group === 'retest') this.retestComponents = arr;
        else this.components = arr;
    }

    // ── Field change handlers ─────────────────────────────────────────────────

    handleHeaderFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.draftSchema = {
            ...this.draftSchema,
            [field]: ['passingMarks', 'totalMarks'].includes(field) ? normalizeNumber(value) : value
        };
        if (this.saveAttempted) this.validateAndApply();
    }

    handleToggleRetest(event) {
        this.retestEnabled = event.target.checked;
        if (this.retestEnabled && !this.retestComponents.length) {
            this.retestComponents = [this.createComponent('Retest')];
        }
        if (this.saveAttempted) this.validateAndApply();
    }

    handleComponentFieldChange(event) {
        const group       = event.target.dataset.group  || 'regular';
        const componentId = event.target.dataset.compId;
        const field       = event.target.dataset.field;
        const value       = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        const numFields   = ['maxMarks', 'minMarks', 'passingMarks', 'weightage', 'effectiveMarks'];

        const updated = this._getGroupComponents(group).map(comp => {
            if (comp.uiId !== componentId) return comp;
            return {
                ...comp,
                [field]: field === 'considerForPassFail' ? !!value
                    : numFields.includes(field) ? normalizeNumber(value)
                    : value
            };
        });
        this._setGroupComponents(group, updated);
        if (this.saveAttempted) this.validateAndApply();
    }

    handleAddComponent(event) {
        const group    = event.currentTarget.dataset.group || 'regular';
        const examType = group === 'retest' ? 'Retest' : 'Regular';
        this._setGroupComponents(group, [...this._getGroupComponents(group), this.createComponent(examType)]);
        if (this.saveAttempted) this.validateAndApply();
    }

    handleDeleteComponent(event) {
        const group       = event.currentTarget.dataset.group || 'regular';
        const componentId = event.currentTarget.dataset.compId;
        const examType    = group === 'retest' ? 'Retest' : 'Regular';
        let next = this._getGroupComponents(group).filter(c => c.uiId !== componentId);
        if (!next.length) next = [this.createComponent(examType)];
        this._setGroupComponents(group, next);
        if (this.saveAttempted) this.validateAndApply();
    }

    handleSubComponentFieldChange(event) {
        const group       = event.target.dataset.group  || 'regular';
        const componentId = event.target.dataset.compId;
        const subId       = event.target.dataset.subId;
        const field       = event.target.dataset.field;
        const value       = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        const boolFields  = ['considerForPassFail', 'examRequired'];
        const numFields   = ['effectiveMarks', 'maxMarks', 'minMarks', 'passingMarks', 'weightage'];

        const updated = this._getGroupComponents(group).map(comp => {
            if (comp.uiId !== componentId) return comp;
            const updatedSubs = comp.subComponents.map(sub => {
                if (sub.uiId !== subId) return sub;
                return {
                    ...sub,
                    [field]: boolFields.includes(field) ? !!value
                        : numFields.includes(field) ? normalizeNumber(value)
                        : value
                };
            });
            return { ...comp, subComponents: updatedSubs };
        });
        this._setGroupComponents(group, updated);
        if (this.saveAttempted) this.validateAndApply();
    }

    handleAddSubComponent(event) {
        const group       = event.currentTarget.dataset.group  || 'regular';
        const componentId = event.currentTarget.dataset.compId;
        const examType    = group === 'retest' ? 'Retest' : 'Regular';
        const updated = this._getGroupComponents(group).map(comp => {
            if (comp.uiId !== componentId) return comp;
            return { ...comp, subComponents: [...comp.subComponents, this.createSubComponent(examType)] };
        });
        this._setGroupComponents(group, updated);
        if (this.saveAttempted) this.validateAndApply();
    }

    handleDeleteSubComponent(event) {
        const group       = event.currentTarget.dataset.group  || 'regular';
        const componentId = event.currentTarget.dataset.compId;
        const subId       = event.currentTarget.dataset.subId;
        const examType    = group === 'retest' ? 'Retest' : 'Regular';
        const updated = this._getGroupComponents(group).map(comp => {
            if (comp.uiId !== componentId) return comp;
            let nextSubs = comp.subComponents.filter(s => s.uiId !== subId);
            if (!nextSubs.length) nextSubs = [this.createSubComponent(examType)];
            return { ...comp, subComponents: nextSubs };
        });
        this._setGroupComponents(group, updated);
        if (this.saveAttempted) this.validateAndApply();
    }

    // ── Save / Cancel ─────────────────────────────────────────────────────────

    handleSave() {
        this.saveAttempted = true;
        if (!this.validateAndApply()) return;

        const ts = Date.now();
        const buildComp = (comp, idx, examType) => ({
            id:                comp.id || `CMP-${ts}-${examType}-${idx + 1}`,
            name:              comp.kenComponent || '',
            kenComponent:      comp.kenComponent || null,
            examType,
            effectiveMarks:    toNumberOrZero(comp.effectiveMarks),
            maxMarks:          normalizeNumber(comp.maxMarks),
            minMarks:          normalizeNumber(comp.minMarks) ?? 0,
            passingMarks:      normalizeNumber(comp.passingMarks),
            weightage:         normalizeNumber(comp.weightage),
            enrollmentType:    comp.enrollmentType || 'Auto',
            considerForPassFail: !!comp.considerForPassFail,
            type:              comp.kenComponent || 'Internal',
            subComponents: comp.subComponents.map((sub, si) => ({
                id:              sub.id || `SUB-${ts}-${examType}-${idx + 1}-${si + 1}`,
                name:            sub.kenAssessment || '',
                kenAssessment:   sub.kenAssessment || null,
                examType,
                effectiveMarks:  normalizeNumber(sub.effectiveMarks),
                maxMarks:        normalizeNumber(sub.maxMarks),
                minMarks:        normalizeNumber(sub.minMarks) ?? 0,
                passingMarks:    normalizeNumber(sub.passingMarks),
                weightage:       normalizeNumber(sub.weightage),
                enrollmentType:  sub.enrollmentType || 'Auto',
                considerForPassFail: !!sub.considerForPassFail,
                examRequired:    sub.examRequired !== false
            }))
        });

        const payload = {
            id:                this.draftSchema.id,
            name:              this.draftSchema.name,
            description:       this.draftSchema.description,
            totalMarks:        normalizeNumber(this.draftSchema.totalMarks),
            passingMarks:      normalizeNumber(this.draftSchema.passingMarks),
            isRequiredForGrading: !!this.draftSchema.isRequiredForGrading,
            coursesApplied:    Number(this.draftSchema.coursesApplied) || 0,
            components: [
                ...this.components.map((c, i) => buildComp(c, i, 'Regular')),
                ...(this.retestEnabled ? this.retestComponents.map((c, i) => buildComp(c, i, 'Retest')) : [])
            ]
        };

        this.dispatchEvent(new CustomEvent('saveschema', { detail: payload }));
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancelwizard'));
    }

    // ── Validate ──────────────────────────────────────────────────────────────
    //
    // Direction: Total Marks is the master — no error is shown on it.
    // Lower-level fields must be correct relative to their parent:
    //   • Component "Effective Marks" — sum across all components must equal Total Marks
    //   • Sub "Effective"             — sum across a component's subs must equal that
    //                                   component's Effective Marks

    validateAndApply() {
        const errors = [];

        // ── Schema Name ──────────────────────────────────────────────────────
        const schemaNameError = !String(this.draftSchema.name || '').trim()
            ? 'Schema name is required.' : null;
        if (schemaNameError) errors.push(schemaNameError);

        // ── Passing Marks ────────────────────────────────────────────────────
        const totalMarks = toNumberOrZero(this.draftSchema.totalMarks);
        if (totalMarks > 0 && toNumberOrZero(this.draftSchema.passingMarks) > totalMarks) {
            errors.push('Passing marks cannot exceed total marks.');
        }

        // ── Per-group validation ─────────────────────────────────────────────
        const processGroup = (groupComps, prefix) => {
            if (!groupComps.length) {
                errors.push(`${prefix}: at least one component is required.`);
                return groupComps;
            }

            // Sum of all component Effective Marks must equal Total Marks
            const compEffSum      = groupComps.reduce((s, c) => s + toNumberOrZero(c.effectiveMarks), 0);
            const compSumMismatch = compEffSum !== totalMarks;

            return groupComps.map((comp, ci) => {
                // Component selection
                const kenComponentError = !String(comp.kenComponent || '').trim() ? 'Required' : null;
                if (kenComponentError) errors.push(`${prefix} Component ${ci + 1}: component selection required.`);

                // Effective Marks — shown on EACH component's field when the sum doesn't match
                const effectiveMarksError = compSumMismatch
                    ? `Component totals (${compEffSum}) must equal Total Marks (${totalMarks})`
                    : null;
                if (compSumMismatch && ci === 0) {
                    // Push once to the global list (not per-component to avoid duplication)
                    errors.push(`${prefix}: component Effective Marks sum (${compEffSum}) ≠ Total Marks (${totalMarks})`);
                }

                // Sub level — sum of sub Effective must equal this component's Effective Marks
                const compEff        = toNumberOrZero(comp.effectiveMarks);
                const subSum         = (comp.subComponents || []).reduce(
                    (s, sub) => s + toNumberOrZero(sub.effectiveMarks), 0
                );
                const subSumMismatch = subSum !== compEff;

                if (!comp.subComponents || !comp.subComponents.length) {
                    errors.push(`${prefix} Component ${ci + 1}: at least one sub-component is required.`);
                }

                const updatedSubs = (comp.subComponents || []).map((sub, si) => {
                    const kenAssessmentError = !String(sub.kenAssessment || '').trim() ? 'Required' : null;
                    if (kenAssessmentError) errors.push(`${prefix} C${ci + 1} Sub ${si + 1}: assessment required.`);

                    // Sub Effective — each sub field gets the error when sub sum ≠ component effective
                    const subEffectiveError = subSumMismatch
                        ? `Sub totals (${subSum}) must equal Component Effective Marks (${compEff})`
                        : null;
                    if (subSumMismatch && si === 0) {
                        errors.push(`${prefix} C${ci + 1}: sub Effective sum (${subSum}) ≠ Effective Marks (${compEff})`);
                    }

                    return {
                        ...sub,
                        kenAssessmentError,
                        kenAssessmentInputClass: kenAssessmentError ? CLS.selectErr : CLS.select,
                        subEffectiveError,
                        subEffectiveInputClass:  subEffectiveError  ? CLS.inputErr  : CLS.input,
                    };
                });

                return {
                    ...comp,
                    kenComponentError,
                    kenComponentInputClass:   kenComponentError   ? CLS.selectErr : CLS.select,
                    effectiveMarksError,
                    effectiveMarksInputClass: effectiveMarksError ? CLS.inputErr  : CLS.input,
                    subComponents: updatedSubs
                };
            });
        };

        this.components = processGroup(this.components, 'Regular');

        // Retest section — no validation; clear any stale error state only
        if (this.retestEnabled) {
            this.retestComponents = this.retestComponents.map(comp => ({
                ...comp,
                kenComponentError:        null,
                kenComponentInputClass:   CLS.select,
                effectiveMarksError:      null,
                effectiveMarksInputClass: CLS.input,
                subComponents: (comp.subComponents || []).map(sub => ({
                    ...sub,
                    kenAssessmentError:      null,
                    kenAssessmentInputClass: CLS.select,
                    subEffectiveError:       null,
                    subEffectiveInputClass:  CLS.input,
                }))
            }));
        }

        this._schemaNameError = schemaNameError;
        this.validationErrors = errors;
        return errors.length === 0;
    }
}