import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { initBrand } from 'c/brandConfigService';
import getExamCycles     from '@salesforce/apex/KenExamCyclePlannerController.getExamCycles';
import getAcademicTerms  from '@salesforce/apex/KenExamCyclePlannerController.getAcademicTerms';
import createExamCycle   from '@salesforce/apex/KenExamCyclePlannerController.createExamCycle';

export default class ExamCyclePlannerList extends LightningElement {
    connectedCallback() { initBrand(this.template.host); }

    @track isLoading       = true;
    @track hasError        = false;
    @track errorMessage    = '';
    @track showCreateModal = false;
    @track isSaving        = false;
    @track saveError       = '';

    @track newCycle = { name: '', academicTermId: '' };

    @track termSearchInput  = '';
    @track showTermDropdown = false;

    _allRows         = [];
    _wiredCyclesRef;
    _allTerms        = [];

    // ── Wire ──────────────────────────────────────────────────────────────────
    @wire(getExamCycles)
    wiredCycles(result) {
        this._wiredCyclesRef = result;
        const { error, data } = result;
        this.isLoading = false;
        if (data) {
            this._allRows = data;
            this.hasError = false;
        } else if (error) {
            this.hasError     = true;
            this.errorMessage = (error.body && error.body.message)
                ? error.body.message
                : 'Failed to load exam cycles.';
        }
    }

    @wire(getAcademicTerms)
    wiredTerms({ error, data }) {
        if (data) {
            this._allTerms = data;
        } else if (error) {
            this._allTerms = [];
        }
    }

    // ── Computed ──────────────────────────────────────────────────────────────
    get filteredRows() { return this._allRows; }
    get hasRows()      { return this._allRows.length > 0; }

    get filteredTerms() {
        const q = (this.termSearchInput || '').trim().toLowerCase();
        if (!q) return this._allTerms;
        return this._allTerms.filter(t =>
            t.name && t.name.toLowerCase().includes(q)
        );
    }
    get hasFilteredTerms() { return this.filteredTerms.length > 0; }

    // ── Add New Cycle ─────────────────────────────────────────────────────────
    handleAddNew() {
        this.newCycle        = { name: '', academicTermId: '' };
        this.termSearchInput = '';
        this.showTermDropdown = false;
        this.saveError       = '';
        this.showCreateModal = true;
    }

    handleCloseModal() {
        if (this.isSaving) return;
        this.showCreateModal  = false;
        this.showTermDropdown = false;
        this.saveError        = '';
    }

    handleFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        this.newCycle = { ...this.newCycle, [field]: event.target.value };
    }

    // ── Academic Term Lookup ──────────────────────────────────────────────────
    handleLookupContainerClick(event) {
        // Prevent the document-level click handler from closing the dropdown
        event.stopPropagation();
    }

    handleTermSearchFocus() {
        this.showTermDropdown = true;
    }

    handleTermSearch(event) {
        this.termSearchInput      = event.target.value;
        this.showTermDropdown     = true;
        // Clear the selected term id when user edits the search text
        this.newCycle = { ...this.newCycle, academicTermId: '' };
    }

    handleTermSelect(event) {
        const termId   = event.currentTarget.dataset.id;
        const termName = event.currentTarget.dataset.name;
        this.newCycle         = { ...this.newCycle, academicTermId: termId };
        this.termSearchInput  = termName;
        this.showTermDropdown = false;
    }

    // ── Save ──────────────────────────────────────────────────────────────────
    async handleSaveCycle() {
        const { name, academicTermId } = this.newCycle;
        this.saveError = '';

        if (!name || !name.trim()) {
            this.saveError = 'Cycle Name is required.';
            return;
        }
        if (!academicTermId) {
            this.saveError = 'Please select an Academic Term.';
            return;
        }

        this.isSaving = true;
        try {
            await createExamCycle({ cycleName: name.trim(), academicTermId });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Exam cycle created.',
                variant: 'success'
            }));
            this.showCreateModal  = false;
            this.showTermDropdown = false;
            await refreshApex(this._wiredCyclesRef);
        } catch (err) {
            this.saveError = (err && err.body && err.body.message)
                ? err.body.message
                : 'Failed to create exam cycle.';
        } finally {
            this.isSaving = false;
        }
    }

    // ── Row Click → navigate to course mapping ────────────────────────────────
    handleRowClick(event) {
        const id  = event.currentTarget.dataset.id;
        const row = this._allRows.find(r => r.id === id);
        if (!row) return;

        this.dispatchEvent(new CustomEvent('cycleclicked', {
            detail: { cycleId: row.id, cycleName: row.name, termId: row.termId }
        }));
    }
}