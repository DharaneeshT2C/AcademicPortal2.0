import { LightningElement, api, track, wire } from 'lwc';
import { initBrand } from 'c/brandConfigService';
import getOperatorPicklistValues from '@salesforce/apex/KenExamCyclePlannerController.getOperatorPicklistValues';
import getLetterGradePicklistValues from '@salesforce/apex/KenExamCyclePlannerController.getLetterGradePicklistValues';

const EMPTY_SCHEMA = {
    id: null,
    name: '',
    active: true
};

const EMPTY_CRITERIA = (type) => ({
    id: null,
    type,
    operator: '',
    rangeTo: '',
    letterGrades: []
});

function clone(v) { return JSON.parse(JSON.stringify(v)); }
let _lgCounter = 0;
function nextLgId() { return `lg-${++_lgCounter}`; }

export default class GradeSchemaWizard extends LightningElement {
    _schemaRecord;
    saveAttempted = false;

    @track _schemaNameError = null;
    @track _relativeOperatorError = null;
    @track _relativeRangeToError = null;
    @track _absoluteOperatorError = null;
    @track _absoluteRangeToError = null;
    @track _relativeLetterGradeErrors = {};
    @track _absoluteLetterGradeErrors = {};
    @track _generalError = null;

    @track draft = clone(EMPTY_SCHEMA);
    @track relativeCriteria = EMPTY_CRITERIA('Relative');
    @track absoluteCriteria = EMPTY_CRITERIA('Absolute');

    @track operatorOptions = [];
    @track letterGradeOptions = [];

    @wire(getOperatorPicklistValues)
    wiredOperators({ data }) {
        if (data) {
            this.operatorOptions = data.map(opt => ({ label: opt.label, value: opt.value }));
        }
    }

    @wire(getLetterGradePicklistValues)
    wiredLetterGrades({ data }) {
        if (data) {
            this.letterGradeOptions = data.map(opt => ({ label: opt.label, value: opt.value }));
        }
    }

    @api
    get schemaRecord() { return this._schemaRecord; }
    set schemaRecord(value) {
        this._schemaRecord = value ? clone(value) : null;
        this._initState();
    }

    connectedCallback() {
        initBrand(this.template.host);
        this._initState();
    }

    renderedCallback() {
        this._syncSelectValues();
    }

    _syncSelectValues() {
        // LWC doesn't reliably bind select values — sync manually after render
        this.template.querySelectorAll('select[data-criteria][data-field]').forEach(sel => {
            const criteria = sel.dataset.criteria;
            const field = sel.dataset.field;
            const lgId = sel.dataset.lgId;
            if (lgId) {
                const src = criteria === 'relative' ? this.relativeCriteria : this.absoluteCriteria;
                const lg = (src.letterGrades || []).find(g => g.uiId === lgId);
                if (lg && sel.value !== (lg[field] || '')) sel.value = lg[field] || '';
            } else {
                const src = criteria === 'relative' ? this.relativeCriteria : this.absoluteCriteria;
                if (sel.value !== (src[field] || '')) sel.value = src[field] || '';
            }
        });
    }

    _initState() {
        const src = this._schemaRecord;
        this.saveAttempted = false;
        this._clearErrors();
        if (!src) {
            this.draft            = clone(EMPTY_SCHEMA);
            this.relativeCriteria = EMPTY_CRITERIA('Relative');
            this.absoluteCriteria = EMPTY_CRITERIA('Absolute');
            return;
        }
        this.draft = { id: src.id || null, name: src.name || '', active: src.active !== false };
        this.relativeCriteria = this._normalizeCriteria(src.relativeCriteria, 'Relative');
        this.absoluteCriteria = this._normalizeCriteria(src.absoluteCriteria, 'Absolute');
    }

    _normalizeCriteria(criteria, type) {
        if (!criteria) return EMPTY_CRITERIA(type);
        return {
            id: criteria.id || null,
            type,
            operator: criteria.operator || '',
            rangeTo:  criteria.rangeTo != null ? String(criteria.rangeTo) : '',
            letterGrades: (criteria.letterGrades || []).map(lg => ({
                ...lg,
                gradePoint: lg.gradePoint != null ? String(lg.gradePoint) : '',
                rangeStart: lg.rangeStart != null ? String(lg.rangeStart) : '',
                rangeEnd:   lg.rangeEnd   != null ? String(lg.rangeEnd)   : '',
                uiId: lg.uiId || nextLgId()
            }))
        };
    }

    _clearErrors() {
        this._schemaNameError = null;
        this._relativeOperatorError = null;
        this._relativeRangeToError = null;
        this._absoluteOperatorError = null;
        this._absoluteRangeToError = null;
        this._relativeLetterGradeErrors = {};
        this._absoluteLetterGradeErrors = {};
        this._generalError = null;
    }

    // ── Computed ──────────────────────────────────────────────────────────────

    get title() {
        return this.draft.id ? 'Edit Grade Schema' : 'Create Grade Schema';
    }

    get relativeCriteriaCount() { return (this.relativeCriteria.letterGrades || []).length; }
    get absoluteCriteriaCount() { return (this.absoluteCriteria.letterGrades || []).length; }
    get hasRelativeGrades() { return this.relativeCriteriaCount > 0; }
    get hasAbsoluteGrades() { return this.absoluteCriteriaCount > 0; }

    get schemaNameError()      { return this.saveAttempted ? this._schemaNameError : null; }
    get schemaNameInputClass() {
        return (this.saveAttempted && this._schemaNameError)
            ? 'gsw-input gsw-input--error'
            : 'gsw-input';
    }

    get relativeOperatorError() { return this.saveAttempted ? this._relativeOperatorError : null; }
    get relativeRangeToError()  { return this.saveAttempted ? this._relativeRangeToError : null; }
    get absoluteOperatorError() { return this.saveAttempted ? this._absoluteOperatorError : null; }
    get absoluteRangeToError()  { return this.saveAttempted ? this._absoluteRangeToError : null; }

    get relativeOperatorClass() {
        return 'gsw-select';
    }
    get relativeRangeToClass() {
        return (this.saveAttempted && this._relativeRangeToError) ? 'gsw-input gsw-input--error' : 'gsw-input';
    }
    get absoluteOperatorClass() {
        return 'gsw-select';
    }
    get absoluteRangeToClass() {
        return (this.saveAttempted && this._absoluteRangeToError) ? 'gsw-input gsw-input--error' : 'gsw-input';
    }

    get generalError() { return this.saveAttempted ? this._generalError : null; }

    // Build letter grades with per-row error info for template
    get relativeLetterGradesWithErrors() {
        return (this.relativeCriteria.letterGrades || []).map(lg => ({
            ...lg,
            errors: this.saveAttempted ? (this._relativeLetterGradeErrors[lg.uiId] || {}) : {}
        }));
    }
    get absoluteLetterGradesWithErrors() {
        return (this.absoluteCriteria.letterGrades || []).map(lg => ({
            ...lg,
            errors: this.saveAttempted ? (this._absoluteLetterGradeErrors[lg.uiId] || {}) : {}
        }));
    }

    // ── Field handlers ────────────────────────────────────────────────────────

    handleSchemaFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.draft = { ...this.draft, [field]: value };
        if (this.saveAttempted) this._validate();
    }

    handleCriteriaFieldChange(event) {
        const criteriaKey = event.target.dataset.criteria;
        const field       = event.target.dataset.field;
        const value       = event.target.value;
        this._updateCriteria(criteriaKey, c => ({ ...c, [field]: value }));
        if (this.saveAttempted) this._validate();
    }

    handleAddLetterGrade(event) {
        const criteriaKey = event.currentTarget.dataset.criteria;
        const newLg = {
            uiId: nextLgId(), id: null,
            letterGrade: '', gradePoint: '',
            definition: '', rangeStart: '', rangeEnd: ''
        };
        this._updateCriteria(criteriaKey, c => ({
            ...c,
            letterGrades: [...(c.letterGrades || []), newLg]
        }));
    }

    handleDeleteLetterGrade(event) {
        const criteriaKey = event.currentTarget.dataset.criteria;
        const lgId        = event.currentTarget.dataset.lgId;
        this._updateCriteria(criteriaKey, c => ({
            ...c,
            letterGrades: (c.letterGrades || []).filter(lg => lg.uiId !== lgId)
        }));
        if (this.saveAttempted) this._validate();
    }

    handleLetterGradeFieldChange(event) {
        const criteriaKey = event.target.dataset.criteria;
        const lgId        = event.target.dataset.lgId;
        const field       = event.target.dataset.field;
        const value       = event.target.value;
        this._updateCriteria(criteriaKey, c => ({
            ...c,
            letterGrades: (c.letterGrades || []).map(lg =>
                lg.uiId === lgId ? { ...lg, [field]: value } : lg
            )
        }));
        if (this.saveAttempted) this._validate();
    }

    _updateCriteria(key, fn) {
        if (key === 'relative') {
            this.relativeCriteria = fn(this.relativeCriteria);
        } else {
            this.absoluteCriteria = fn(this.absoluteCriteria);
        }
    }

    // ── Save / Cancel ─────────────────────────────────────────────────────────

    handleSave() {
        this.saveAttempted = true;
        if (!this._validate()) return;

        const payload = {
            id:               this.draft.id,
            name:             this.draft.name,
            active:           this.draft.active,
            relativeCriteria: this._serializeCriteria(this.relativeCriteria),
            absoluteCriteria: this._serializeCriteria(this.absoluteCriteria)
        };
        this.dispatchEvent(new CustomEvent('saveschema', { detail: payload }));
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancelwizard'));
    }

    // ── Validation ────────────────────────────────────────────────────────────

    _validate() {
        this._clearErrors();
        let valid = true;

        // Schema name required
        if (!String(this.draft.name || '').trim()) {
            this._schemaNameError = 'Schema name is required.';
            valid = false;
        }

        // Validate criteria fields
        valid = this._validateCriteria(this.relativeCriteria, 'relative') && valid;
        valid = this._validateCriteria(this.absoluteCriteria, 'absolute') && valid;

        return valid;
    }

    _validateCriteria(criteria, key) {
        let valid = true;
        const hasGrades = (criteria.letterGrades || []).length > 0;
        const hasOperator = String(criteria.operator || '').trim();
        const hasRangeTo = String(criteria.rangeTo || '').trim();

        // If any letter grades exist, operator and rangeTo are required
        if (hasGrades || hasOperator || hasRangeTo) {
            if (!hasOperator) {
                if (key === 'relative') this._relativeOperatorError = 'Operator is required.';
                else this._absoluteOperatorError = 'Operator is required.';
                valid = false;
            }
            if (!hasRangeTo) {
                if (key === 'relative') this._relativeRangeToError = 'Range To is required.';
                else this._absoluteRangeToError = 'Range To is required.';
                valid = false;
            }
        }

        // Validate each letter grade row
        const errorsMap = {};
        (criteria.letterGrades || []).forEach(lg => {
            const rowErrors = {};
            if (!String(lg.letterGrade || '').trim()) {
                rowErrors.letterGrade = 'Required';
                valid = false;
            }
            if (!String(lg.gradePoint || '').trim()) {
                rowErrors.gradePoint = 'Required';
                valid = false;
            }
            if (!String(lg.definition || '').trim()) {
                rowErrors.definition = 'Required';
                valid = false;
            }
            if (!String(lg.rangeStart || '').trim()) {
                rowErrors.rangeStart = 'Required';
                valid = false;
            }
            if (!String(lg.rangeEnd || '').trim()) {
                rowErrors.rangeEnd = 'Required';
                valid = false;
            }
            if (Object.keys(rowErrors).length > 0) {
                errorsMap[lg.uiId] = rowErrors;
            }
        });

        if (key === 'relative') {
            this._relativeLetterGradeErrors = errorsMap;
        } else {
            this._absoluteLetterGradeErrors = errorsMap;
        }

        return valid;
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    _serializeCriteria(criteria) {
        return {
            id:           criteria.id || null,
            operator:     criteria.operator || null,
            rangeTo:      criteria.rangeTo ? Number(criteria.rangeTo) : null,
            letterGrades: (criteria.letterGrades || []).map(({ uiId, errors, ...rest }) => ({
                ...rest,
                gradePoint: rest.gradePoint ? Number(rest.gradePoint) : null,
                rangeStart: rest.rangeStart ? Number(rest.rangeStart) : null,
                rangeEnd:   rest.rangeEnd   ? Number(rest.rangeEnd)   : null
            }))
        };
    }
}