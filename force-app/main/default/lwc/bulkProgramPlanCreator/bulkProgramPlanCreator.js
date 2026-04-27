import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInitData from '@salesforce/apex/BulkProgramPlanController.getInitData';
import insertProgramPlans from '@salesforce/apex/BulkProgramPlanController.insertProgramPlans';
import checkDuplicates from '@salesforce/apex/BulkProgramPlanController.checkDuplicates';
import getJobStatus from '@salesforce/apex/BulkProgramPlanController.getJobStatus';

const CSV_HEADERS = [
    'Name','Batch_Number__c','Section__c','Cadence_Type__c',
    'ActiveFromDate','ActiveToDate',
    'Intake_Strength__c','Description'
];

const CSV_TO_FIELD = {
    'Name':'name','Batch_Number__c':'batchNumber','Section__c':'section',
    'Cadence_Type__c':'cadenceType',
    'ActiveFromDate':'activeFromDate','ActiveToDate':'activeToDate',
    'Intake_Strength__c':'intakeStrength',
    'Description':'description'
};

const NUM_FIELDS = new Set(['intakeStrength']);
const DEFAULT_ROWS = 5;
const SYNC_LIMIT = 50;
const POLL_INTERVAL = 3000;

export default class BulkProgramPlanCreator extends LightningElement {
    @track rows = [];
    @track isLoading = true;
    @track showSectionModal = false;
    @track showConfirmModal = false;
    @track showBulkApplyModal = false;
    @track showSuccessModal = false;
    @track showHelpModal = false;
    @track isPolling = false;
    @track currentSectionValues = [];
    @track confirmProgramList = [];
    @track bulkApply = {};

    @track importProgramId = '';
    @track importProviderName = '';
    @track importMode = 'append';

    @track lastSuccessCount = 0;
    @track lastErrorCount = 0;
    @track duplicateCount = 0;
    @track hasDuplicates = false;
    @track allExpanded = false;

    _programMap = new Map();
    _programOpts = [];
    _batchOpts = [];
    _cadenceOpts = [];
    _sectionOpts = [];
    _batchValues = new Set();
    _cadenceValues = new Set();
    _sectionValues = new Set();
    _counter = 0;
    _activeSectionRowId = null;
    _pollTimer = null;
    _deletedRows = [];

    // ═══════════════════════════════════════════
    // LIFECYCLE
    // ═══════════════════════════════════════════
    connectedCallback() { 
        console.log('🔍 BulkProgramPlanCreator initialized');
        this._loadInit(); 
    }
    disconnectedCallback() { 
        if (this._pollTimer) clearInterval(this._pollTimer); 
    }

    async _loadInit() {
        try {
            const d = await getInitData();
            d.programs.forEach(p => this._programMap.set(p.id, p));
            this._programOpts = d.programs.map(p => ({ label: p.name, value: p.id }));
            this._batchOpts = d.batchOptions.map(o => ({ label: o.label, value: o.value }));
            this._cadenceOpts = d.cadenceOptions.map(o => ({ label: o.label, value: o.value }));
            this._sectionOpts = d.sectionOptions.map(o => ({ label: o.label, value: o.value }));
            if (d.batchValues) d.batchValues.forEach(v => this._batchValues.add(v));
            if (d.cadenceValues) d.cadenceValues.forEach(v => this._cadenceValues.add(v));
            if (d.sectionValues) d.sectionValues.forEach(v => this._sectionValues.add(v));
            this._addRows(DEFAULT_ROWS);
        } catch (e) {
            console.error('Init error:', e);
            this._toast('Error', this._err(e), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ═══════════════════════════════════════════
    // GETTERS
    // ═══════════════════════════════════════════
    get programOptions() { return this._programOpts; }
    get batchOptions() { return this._batchOpts; }
    get cadenceOptions() { return this._cadenceOpts; }
    get sectionOptions() { return this._sectionOpts; }
    get totalRows() { return this.rows.length; }
    get validRowCount() { return this.rows.filter(r => this._isValid(r) && !r.errorMessage).length; }
    get warningRowCount() { return this.rows.filter(r => r.warningMessage).length; }
    get errorRowCount() { return this.rows.filter(r => r.errorMessage).length; }
    get skippedRowCount() { return this.totalRows - this.validRowCount; }
    get hasSkippedRows() { return this.skippedRowCount > 0; }
    get uniqueProgramCount() {
        return new Set(this.rows.filter(r => r.learningProgramId).map(r => r.learningProgramId)).size;
    }
    get isSaveDisabled() { return this.validRowCount === 0 || this.isLoading; }
    get isDeleteDisabled() { return this.rows.length <= 1; }
    get isImportProgramNotSelected() { return !this.importProgramId; }
    get isImportAppend() { return this.importMode === 'append'; }
    get isImportReplace() { return this.importMode === 'replace'; }
    get importModeLabel() { return this.importMode === 'append' ? 'Append' : 'Replace'; }
    get isAsyncInsert() { return this.validRowCount > SYNC_LIMIT; }
    get hasCreatedIds() { return this.lastSuccessCount > 0; }
    get noErrors() { return this.lastErrorCount === 0; }
    get expandAllIcon() { return this.allExpanded ? 'utility:collapse_all' : 'utility:expand_all'; }
    get isAllSelected() { return this.rows.length > 0 && this.rows.every(r => r.isSelected); }
    get hasSelectedRows() { return this.rows.some(r => r.isSelected); }
    get selectedRowCount() { return this.rows.filter(r => r.isSelected).length; }

    // ═══════════════════════════════════════════
    // HELP MODAL
    // ═══════════════════════════════════════════
    handleHelpClick() { this.showHelpModal = true; }
    handleCloseHelp() { this.showHelpModal = false; }

    // ═══════════════════════════════════════════
    // IMPORT PANEL
    // ═══════════════════════════════════════════
    handleImportProgramChange(e) {
        this.importProgramId = e.detail.value;
        const p = this._programMap.get(this.importProgramId);
        this.importProviderName = p ? (p.providerName || '') : '';
    }
    handleImportOption(e) { this.importMode = e.detail.value; }

    // ═══════════════════════════════════════════
    // ROW MANAGEMENT
    // ═══════════════════════════════════════════
    _createRow(data) {
        this._counter++;
        const id = `r-${this._counter}`;
        const row = {
            id, index: 0,
            learningProgramId: '', providerId: '', providerName: '',
            name: '', batchNumber: '', section: '', sectionValues: [],
            sectionDisplay: 'Select', cadenceType: '',
            activeFromDate: null, activeToDate: null,
            durationPerSession: null, intakeStrength: null,
            description: '',
            isExpanded: false, expandIcon: 'utility:chevronright',
            isSelected: false,
            errorMessage: '', warningMessage: '',
            rowClass: 'grid-row', numberClass: 'row-number',
            statusIcon: '', statusVariant: '', statusText: '',
            dateErrorClass: '', zIndexStyle: ''
        };

        if (data) {
            Object.keys(data).forEach(k => { if (k in row) row[k] = data[k]; });
            if (row.section) {
                row.sectionValues = row.section.split(';').map(s => s.trim()).filter(Boolean);
                row.sectionDisplay = row.sectionValues.join(', ') || 'Select';
            }
        }

        if (row.learningProgramId) {
            row.durationPerSession = this._getDurationFromProgram(row.learningProgramId);
        }

        this._validateRowLive(row);
        return row;
    }

    _getDurationFromProgram(programId) {
        const p = this._programMap.get(programId);
        return (p && p.durationPerSession != null) ? p.durationPerSession : null;
    }

    _addRows(n) {
        const nr = [];
        for (let i = 0; i < n; i++) nr.push(this._createRow());
        this.rows = [...this.rows, ...nr];
        this._reindex();
    }

    _reindex() {
        const total = this.rows.length;
        this.rows = this.rows.map((r, i) => ({
            ...r,
            index: i + 1,
            zIndexStyle: `z-index: ${total - i};`
        }));
    }

    _idx(id) { return this.rows.findIndex(r => r.id === id); }

    _updateRow(id, upd) {
        const i = this._idx(id);
        if (i === -1) return;
        const updated = { ...this.rows[i], ...upd };
        this._validateRowLive(updated);
        const nr = [...this.rows];
        nr[i] = updated;
        this.rows = nr;
    }

    // ═══════════════════════════════════════════
    // LIVE VALIDATION - FIXED
    // ═══════════════════════════════════════════
    _validateRowLive(row) {
        const errors = [];
        const warnings = [];

        if (this._hasAnyData(row)) {
            if (!row.learningProgramId) errors.push('Program is required');
            if (!row.name) errors.push('Plan Name is required');
        }

        // ✅ FIXED: Date validation - From must be STRICTLY earlier than To
        if (row.activeFromDate && row.activeToDate) {
            const fromDate = new Date(row.activeFromDate);
            const toDate = new Date(row.activeToDate);
            
            // Check if From is LATER than OR EQUAL to To
            if (fromDate >= toDate) {
                errors.push('Active From must be strictly earlier than Active To');
                row.dateErrorClass = 'date-error';
            } else {
                row.dateErrorClass = '';
            }
        } else {
            row.dateErrorClass = '';
        }

        if (row.activeFromDate && new Date(row.activeFromDate) < new Date()) {
            warnings.push('Active From is in the past');
        }

        if (row.batchNumber && this._batchValues.size > 0 && !this._batchValues.has(row.batchNumber)) {
            warnings.push(`Batch "${row.batchNumber}" is not a valid picklist value`);
        }
        if (row.cadenceType && this._cadenceValues.size > 0 && !this._cadenceValues.has(row.cadenceType)) {
            warnings.push(`Cadence "${row.cadenceType}" is not a valid picklist value`);
        }
        if (row.sectionValues && row.sectionValues.length > 0 && this._sectionValues.size > 0) {
            const invalid = row.sectionValues.filter(v => !this._sectionValues.has(v));
            if (invalid.length > 0) warnings.push(`Section "${invalid.join(', ')}" not valid`);
        }

        row.errorMessage = errors.join(' | ');
        row.warningMessage = warnings.join(' | ');

        if (errors.length > 0) {
            row.statusIcon = 'utility:error'; 
            row.statusVariant = 'error'; 
            row.statusText = 'Has errors';
            row.numberClass = 'row-number row-number-error'; 
            row.rowClass = 'grid-row grid-row-error';
        } else if (warnings.length > 0) {
            row.statusIcon = 'utility:warning'; 
            row.statusVariant = 'warning'; 
            row.statusText = 'Has warnings';
            row.numberClass = 'row-number row-number-warning'; 
            row.rowClass = 'grid-row grid-row-warning';
        } else if (this._isValid(row)) {
            row.statusIcon = 'utility:check'; 
            row.statusVariant = 'success'; 
            row.statusText = 'Valid';
            row.numberClass = 'row-number row-number-valid'; 
            row.rowClass = 'grid-row grid-row-valid';
        } else {
            row.statusIcon = ''; 
            row.statusVariant = ''; 
            row.statusText = '';
            row.numberClass = 'row-number'; 
            row.rowClass = 'grid-row';
        }
    }

    _isValid(row) { return !!(row.learningProgramId && row.name); }
    _hasAnyData(row) {
        return !!(row.learningProgramId || row.name || row.batchNumber ||
                  row.cadenceType || row.section || row.description);
    }
    _isRowEmpty(row) { return !this._hasAnyData(row); }

    // ═══════════════════════════════════════════
    // FIELD CHANGE HANDLERS
    // ═══════════════════════════════════════════
    handleFieldChange(e) {
        const id = e.target.dataset.rowId;
        const field = e.target.dataset.field;
        const val = e.detail.value;
        const upd = { [field]: val };

        if (field === 'learningProgramId') {
            const p = this._programMap.get(val);
            upd.providerId = p ? (p.providerId || '') : '';
            upd.providerName = p ? (p.providerName || '') : '';
            upd.durationPerSession = this._getDurationFromProgram(val);
        }

        this._updateRow(id, upd);
    }

    // ═══════════════════════════════════════════
    // ROW ACTIONS
    // ═══════════════════════════════════════════
    handleToggleExpand(e) {
        const id = e.target.dataset.rowId;
        const i = this._idx(id);
        if (i === -1) return;
        const exp = !this.rows[i].isExpanded;
        this._updateRow(id, {
            isExpanded: exp,
            expandIcon: exp ? 'utility:chevrondown' : 'utility:chevronright'
        });
    }

    handleAddRow() { this._addRows(1); }
    handleAddFiveRows() { this._addRows(5); }

    handleCloneRow(e) {
        const id = e.target.dataset.rowId;
        const i = this._idx(id);
        if (i === -1) return;
        const src = this.rows[i];
        const data = {};
        const fields = [
            'learningProgramId','providerId','providerName','batchNumber',
            'section','sectionValues','sectionDisplay','cadenceType',
            'activeFromDate','activeToDate','durationPerSession',
            'intakeStrength','description'
        ];
        fields.forEach(f => { data[f] = Array.isArray(src[f]) ? [...src[f]] : src[f]; });
        const nr = this._createRow(data);
        const rows = [...this.rows];
        rows.splice(i + 1, 0, nr);
        this.rows = rows;
        this._reindex();
        this._toast('Cloned', 'Row duplicated. Update the Plan Name.', 'info');
    }

    handleDeleteRow(e) {
        if (this.rows.length <= 1) return;
        const id = e.target.dataset.rowId;
        const i = this._idx(id);
        if (i !== -1) {
            this._deletedRows.push({ ...this.rows[i], _position: i });
            if (this._deletedRows.length > 20) this._deletedRows.shift();
        }
        this.rows = this.rows.filter(r => r.id !== id);
        this._reindex();
        this._toast('Deleted', 'Row removed.', 'info');
    }

    handleClearAll() {
        this.rows = [];
        this._counter = 0;
        this._deletedRows = [];
        this._addRows(DEFAULT_ROWS);
        this._toast('Cleared', 'All rows reset.', 'info');
    }

    // ═══════════════════════════════════════════
    // SELECTION & BULK
    // ═══════════════════════════════════════════
    handleRowSelect(e) { this._updateRow(e.target.dataset.rowId, { isSelected: e.target.checked }); }
    handleSelectAll(e) {
        const checked = e.target.checked;
        this.rows = this.rows.map(r => ({ ...r, isSelected: checked }));
    }

    handleBulkDelete() {
        const selected = this.rows.filter(r => r.isSelected);
        if (this.rows.length - selected.length < 1) {
            this._toast('Cannot Delete', 'At least one row must remain.', 'warning');
            return;
        }
        selected.forEach((r, i) => { this._deletedRows.push({ ...r, _position: i }); });
        this.rows = this.rows.filter(r => !r.isSelected);
        this._reindex();
        this._toast('Deleted', `${selected.length} row(s) removed.`, 'info');
    }

    handleBulkApply() {
        this.bulkApply = {
            learningProgramId: '', namePrefix: '', batchNumber: '',
            cadenceType: '', section: '', sectionValues: [],
            sectionDisplay: 'Select Section',
            activeFromDate: null, activeToDate: null,
            intakeStrength: null, description: ''
        };
        this.showBulkApplyModal = true;
    }

    handleBulkApplyField(e) {
        const f = e.target.dataset.field;
        this.bulkApply = { ...this.bulkApply, [f]: e.detail.value };
    }

    handleBulkSectionClick() {
        this._activeSectionRowId = '__bulk__';
        this.currentSectionValues = [...(this.bulkApply.sectionValues || [])];
        this.showBulkApplyModal = false;
        setTimeout(() => { this.showSectionModal = true; }, 150);
    }

    handleConfirmBulkApply() {
        const updates = {};
        const ba = this.bulkApply;

        if (ba.learningProgramId) {
            updates.learningProgramId = ba.learningProgramId;
            const p = this._programMap.get(ba.learningProgramId);
            updates.providerId = p ? (p.providerId || '') : '';
            updates.providerName = p ? (p.providerName || '') : '';
            updates.durationPerSession = this._getDurationFromProgram(ba.learningProgramId);
        }
        if (ba.batchNumber) updates.batchNumber = ba.batchNumber;
        if (ba.cadenceType) updates.cadenceType = ba.cadenceType;
        if (ba.section) {
            updates.section = ba.section;
            updates.sectionValues = ba.sectionValues;
            updates.sectionDisplay = ba.sectionDisplay;
        }
        if (ba.intakeStrength != null && ba.intakeStrength !== '') updates.intakeStrength = ba.intakeStrength;
        if (ba.activeFromDate) updates.activeFromDate = ba.activeFromDate;
        if (ba.activeToDate) updates.activeToDate = ba.activeToDate;
        if (ba.description) updates.description = ba.description;

        if (Object.keys(updates).length === 0 && !ba.namePrefix) {
            this._toast('Nothing to Apply', 'Fill at least one field.', 'warning');
            return;
        }

        let counter = 0;
        const selectedCount = this.rows.filter(r => r.isSelected).length;

        this.rows = this.rows.map(r => {
            if (!r.isSelected) return r;
            counter++;
            const merged = { ...r, ...updates };
            if (ba.namePrefix) {
                merged.name = selectedCount > 1 ? `${ba.namePrefix} - ${counter}` : ba.namePrefix;
            }
            this._validateRowLive(merged);
            return merged;
        });

        this.showBulkApplyModal = false;
        this._toast('Applied', `Values applied to ${selectedCount} row(s).`, 'success');
    }

    handleCloseBulkApply() { this.showBulkApplyModal = false; }

    // ═══════════════════════════════════════════
    // EXPAND / COLLAPSE ALL
    // ═══════════════════════════════════════════
    handleExpandCollapseAll() {
        this.allExpanded = !this.allExpanded;
        this.rows = this.rows.map(r => ({
            ...r,
            isExpanded: this.allExpanded,
            expandIcon: this.allExpanded ? 'utility:chevrondown' : 'utility:chevronright'
        }));
    }

    // ═══════════════════════════════════════════
    // SECTION MODAL
    // ═══════════════════════════════════════════
    handleSectionClick(e) {
        const id = e.target.dataset.rowId;
        const i = this._idx(id);
        if (i === -1) return;
        this._activeSectionRowId = id;
        this.currentSectionValues = [...(this.rows[i].sectionValues || [])];
        this.showSectionModal = true;
    }
    handleSectionChange(e) { this.currentSectionValues = e.detail.value; }
    handleApplySection() {
        const v = this.currentSectionValues;
        const isBulkMode = this._activeSectionRowId === '__bulk__';
        if (isBulkMode) {
            this.bulkApply = {
                ...this.bulkApply, sectionValues: v,
                sectionDisplay: v.length > 0 ? v.join(', ') : 'Select Section',
                section: v.join(';')
            };
        } else {
            this._updateRow(this._activeSectionRowId, {
                sectionValues: v,
                sectionDisplay: v.length > 0 ? v.join(', ') : 'Select',
                section: v.join(';')
            });
        }
        this.showSectionModal = false;
        this._activeSectionRowId = null;
        if (isBulkMode) {
            setTimeout(() => { this.showBulkApplyModal = true; }, 150);
        }
    }
    handleCloseSectionModal() {
        const isBulkMode = this._activeSectionRowId === '__bulk__';
        this.showSectionModal = false;
        this._activeSectionRowId = null;
        if (isBulkMode) {
            setTimeout(() => { this.showBulkApplyModal = true; }, 150);
        }
    }

generateTemplate() {
    console.log('🔍 Download Template clicked');
    console.log('Import Program ID:', this.importProgramId);
    
    if (!this.importProgramId) {
        this._toast('Select Program', 'Please choose a program first.', 'warning');
        return;
    }
    
    const prog = this._programMap.get(this.importProgramId);
    console.log('Program:', prog);
    
    if (!prog) {
        this._toast('Error', 'Program not found in cache.', 'error');
        return;
    }

    try {
        // ✅ Create CSV with HEADERS ONLY (no example row)
        const csv = CSV_HEADERS.join(',') + '\n';
        
        // Safe filename (remove special chars)
        const safeName = (prog.name || 'Program').replace(/[^a-zA-Z0-9_-]/g, '_');
        const filename = `ProgramPlan_Template_${safeName}.csv`;
        
        console.log('📄 CSV Headers:', csv.trim());
        console.log('📁 Filename:', filename);
        
        // Trigger download
        this._downloadFile(csv, filename);
        this._toast('Downloaded', `Template for "${prog.name}" is ready.`, 'success');
        
    } catch (e) {
        console.error('❌ Template generation failed:', e);
        this._toast('Download Failed', `Error: ${e.message || 'Unknown error'}`, 'error');
    }
}



// ═══════════════════════════════════════════
// UTILITIES - FIXED DOWNLOAD (LWC-Compatible)
// ═══════════════════════════════════════════
_downloadFile(content, filename) {
    console.log('📥 Downloading:', filename);
    
    try {
        // ✅ Use data URL instead of blob for LWC compatibility
        const encodedContent = encodeURIComponent(content);
        const dataUrl = `data:text/csv;charset=utf-8,${encodedContent}`;
        
        const link = document.createElement('a');
        link.setAttribute('href', dataUrl);
        link.setAttribute('download', filename);
        link.style.display = 'none';
        
        // Append, click, remove - with error handling
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        
        console.log('✅ Download triggered successfully');
        return true;
        
    } catch (e) {
        console.error('❌ Download failed:', e);
        // Fallback: try window.open for very restricted environments
        try {
            const encodedContent = encodeURIComponent(content);
            const dataUrl = `data:text/csv;charset=utf-8,${encodedContent}`;
            const newWindow = window.open(dataUrl, '_blank');
            if (newWindow) {
                newWindow.document.title = filename;
                return true;
            }
        } catch (fallbackError) {
            console.error('❌ Fallback download also failed:', fallbackError);
        }
        throw new Error('Download failed: ' + e.message);
    }
}

    // ═══════════════════════════════════════════
    // CSV IMPORT
    // ═══════════════════════════════════════════
    handleImportClick() {
        if (!this.importProgramId) { 
            this._toast('Select Program', 'Choose a program for import.', 'warning'); 
            return; 
        }
        const inp = this.template.querySelector('input[type="file"]');
        if (inp) { inp.value = null; inp.click(); }
    }

    handleFileUpload(e) {
        const file = e.target.files[0];
        if (!file) return;
        if (!file.name.toLowerCase().endsWith('.csv')) {
            this._toast('Invalid File', 'Please upload a .csv file.', 'error'); 
            return;
        }
        this.isLoading = true;
        const reader = new FileReader();
        reader.onload = () => {
            try {
                const imported = this._parseCsv(reader.result);
                if (!imported.length) { 
                    this._toast('Empty', 'No data rows found.', 'warning'); 
                    this.isLoading = false; 
                    return; 
                }
                const prog = this._programMap.get(this.importProgramId);
                const newRows = imported.map(d => {
                    d.learningProgramId = this.importProgramId;
                    d.providerId = prog ? (prog.providerId || '') : '';
                    d.providerName = prog ? (prog.providerName || '') : '';
                    return this._createRow(d);
                });
                if (this.importMode === 'replace') { 
                    this.rows = newRows; 
                } else {
                    const existing = this.rows.filter(r => !this._isRowEmpty(r));
                    this.rows = [...existing, ...newRows];
                }
                this._reindex();
                this._toast('Imported', `${imported.length} row(s) imported.`, 'success');
            } catch (err) { 
                this._toast('Parse Error', err.message || 'CSV parse failed.', 'error'); 
            } finally { 
                this.isLoading = false; 
            }
        };
        reader.onerror = () => { 
            this._toast('Read Error', 'Could not read file.', 'error'); 
            this.isLoading = false; 
        };
        reader.readAsText(file);
    }

    _parseCsv(text) {
        const lines = text.split('\n').map(l => l.trim()).filter(l => l && !l.startsWith('#'));
        if (lines.length < 2) return [];
        const headers = this._csvLine(lines[0]);
        const colMap = {};
        headers.forEach((h, i) => {
            const clean = h.trim().replace(/^"|"$/g, '');
            if (CSV_TO_FIELD[clean]) colMap[i] = CSV_TO_FIELD[clean];
        });
        const rows = [];
        for (let i = 1; i < lines.length; i++) {
            const vals = this._csvLine(lines[i]);
            if (vals.every(v => !v.trim())) continue;
            const rd = {};
            let has = false;
            Object.entries(colMap).forEach(([ci, fn]) => {
                let v = (vals[ci] || '').trim().replace(/^"|"$/g, '');
                if (!v) return;
                has = true;
                if (NUM_FIELDS.has(fn)) { 
                    const n = parseFloat(v); 
                    if (!isNaN(n)) rd[fn] = n; 
                } else {
                    rd[fn] = v;
                }
            });
            if (has) rows.push(rd);
        }
        return rows;
    }

    _csvLine(line) {
        const res = []; 
        let cur = '', inQ = false;
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === '"') {
                if (inQ && i + 1 < line.length && line[i + 1] === '"') { 
                    cur += '"'; 
                    i++; 
                } else {
                    inQ = !inQ;
                }
            } else if (c === ',' && !inQ) { 
                res.push(cur); 
                cur = ''; 
            } else {
                cur += c;
            }
        }
        res.push(cur);
        return res;
    }

    // ═══════════════════════════════════════════
    // VALIDATE - FIXED WITH DUPLICATE CHECK
    // ═══════════════════════════════════════════
    async handleValidate() {
        console.log('🔍 Validate clicked');
        
        // Clear previous warnings/errors
        this.rows = this.rows.map(r => ({
            ...r,
            warningMessage: '',
            errorMessage: '',
            rowClass: this._isValid(r) ? 'grid-row grid-row-valid' : 'grid-row'
        }));

        const valid = this.rows.filter(r => this._isValid(r));
        
        if (valid.length === 0) {
            this._toast('No Valid Rows', 'Please fill in required fields (Program and Plan Name).', 'warning');
            return;
        }

        this.isLoading = true;
        try {
            const payload = valid.map(r => this._buildPayload(r));
            const dupResult = await checkDuplicates({ plans: payload });
            
            let dupCount = 0;
            
            // Mark duplicates in UI
            if (dupResult.duplicates && dupResult.duplicates.length > 0) {
                dupCount = dupResult.duplicates.length;
                
                dupResult.duplicates.forEach(d => {
                    if (d.rowIndex < valid.length) {
                        const row = valid[d.rowIndex];
                        if (row) {
                            const i = this._idx(row.id);
                            if (i !== -1) {
                                // Update row with duplicate warning
                                const newRow = {
                                    ...this.rows[i],
                                    warningMessage: `DUPLICATE: "${d.name}" already exists under program "${d.programName}"`,
                                    rowClass: 'grid-row grid-row-warning',
                                    isExpanded: true
                                };
                                this.rows[i] = newRow;
                            }
                        }
                    }
                });
                
                this.rows = [...this.rows]; // Trigger re-render
            }

            // Show validation summary
            const errorCount = this.rows.filter(r => r.errorMessage).length;
            const warningCount = this.rows.filter(r => r.warningMessage).length;
            
            if (errorCount === 0 && warningCount === 0) {
                this._toast('✅ Validation Passed', `All ${valid.length} rows are valid and ready to save.`, 'success');
            } else if (errorCount === 0) {
                this._toast('⚠️ Warnings Found', `${warningCount} row(s) have warnings (including ${dupCount} duplicates). You can still save, but duplicates will be skipped.`, 'warning');
            } else {
                this._toast('❌ Errors Found', `${errorCount} error(s) must be fixed before saving.`, 'error');
            }
            
        } catch (e) {
            console.error('Validation error:', e);
            this._toast('Validation Error', e.message || 'Failed to validate rows', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ═══════════════════════════════════════════
    // SAVE FLOW - FIXED
    // ═══════════════════════════════════════════
    async handleSave() {
        console.log('📝 Save clicked - Total rows:', this.rows.length);
        
        // Run validation first
        await this.handleValidate();
        
        const valid = this.rows.filter(r => this._isValid(r) && !r.errorMessage);
        const withWarnings = this.rows.filter(r => r.warningMessage);
        
        console.log('Valid rows:', valid.length);
        console.log('Rows with warnings:', withWarnings.length);
        
        if (!valid.length) {
            this._toast('No Valid Rows', 'Fix errors before saving.', 'warning');
            return;
        }

        // Show confirmation
        const progs = new Set();
        valid.forEach(r => {
            const p = this._programMap.get(r.learningProgramId);
            if (p) progs.add(p.name);
        });
        
        this.confirmProgramList = [...progs];
        console.log('Programs to insert:', this.confirmProgramList);
        this.showConfirmModal = true;
    }

    handleCancelSave() { this.showConfirmModal = false; }

    async handleConfirmSave() {
        this.showConfirmModal = false;
        this.isLoading = true;
        try {
            const valid = this.rows.filter(r => this._isValid(r) && !r.errorMessage);
            const payload = valid.map(r => this._buildPayload(r));
            
            console.log('💾 Inserting', payload.length, 'records');
            
            const result = await insertProgramPlans({ plans: payload });
            
            console.log('Insert result:', result);
            
            if (result.isAsync) { 
                this.isLoading = false; 
                this.isPolling = true; 
                this._pollJob(result.jobId); 
                return; 
            }
            
            this._handleSaveResult(result, valid);
        } catch (e) { 
            console.error('Save error:', e);
            this._toast('Error', this._err(e), 'error'); 
        } finally { 
            this.isLoading = false; 
        }
    }

    _handleSaveResult(result, validRows) {
        console.log('Save Result:', result);
        
        // Track which rows had errors
        const errorRowIds = new Set();
        
        if (result.errors && result.errors.length > 0) {
            console.log('Processing', result.errors.length, 'errors');
            
            result.errors.forEach(err => {
                console.log('Error at rowIndex', err.rowIndex, ':', err.message);
                
                const row = validRows[err.rowIndex];
                if (row) {
                    errorRowIds.add(row.id);
                    const i = this._idx(row.id);
                    if (i !== -1) {
                        const updatedRow = {
                            ...this.rows[i],
                            errorMessage: err.message,
                            rowClass: 'grid-row grid-row-error',
                            isExpanded: true // Auto-expand to show error
                        };
                        this.rows[i] = updatedRow;
                    }
                }
            });
        }
        
        this.lastSuccessCount = result.successCount;
        this.lastErrorCount = result.errorCount;
        
        // Remove successfully inserted rows, keep only errors
        if (errorRowIds.size > 0) {
            this.rows = this.rows.filter(r => errorRowIds.has(r.id));
            this._reindex();
            console.log('Kept', this.rows.length, 'error rows in UI');
        } else {
            // All succeeded - clear grid
            this.rows = [];
            this._counter = 0;
            this._addRows(DEFAULT_ROWS);
        }
        
        // Show success modal
        this.showSuccessModal = true;
    }

    // ═══════════════════════════════════════════
    // ASYNC POLLING
    // ═══════════════════════════════════════════
    _pollJob(jobId) {
        let attempts = 0;
        this._pollTimer = setInterval(async () => {
            attempts++;
            try {
                const status = await getJobStatus({ jobId });
                if (['Completed','Failed','Aborted'].includes(status.status)) {
                    clearInterval(this._pollTimer); 
                    this._pollTimer = null; 
                    this.isPolling = false;
                    if (status.status === 'Completed') {
                        this.lastSuccessCount = status.successCount || 0;
                        this.lastErrorCount = status.errorCount || 0;
                        if (this.lastSuccessCount > 0) { 
                            this.rows = []; 
                            this._counter = 0; 
                            this._addRows(DEFAULT_ROWS); 
                        }
                        this.showSuccessModal = true;
                    } else { 
                        this._toast('Job Failed', status.errorMessage || 'Async insert failed.', 'error'); 
                    }
                }
                if (attempts > 60) {
                    clearInterval(this._pollTimer); 
                    this.isPolling = false;
                    this._toast('Timeout', 'Job is still running. Check Bulk Insert Logs.', 'warning');
                }
            } catch (e) { 
                console.error('Poll error:', e); 
            }
        }, POLL_INTERVAL);
    }

    // ═══════════════════════════════════════════
    // ERROR REPORT - FIXED DOWNLOAD
    // ═══════════════════════════════════════════
    handleDownloadErrors() {
        console.log('Download Errors - Rows:', this.rows.length);
        
        // Get rows with errors
        const errorRows = this.rows.filter(r => r.errorMessage);
        
        console.log('Error rows found:', errorRows.length);
        
        if (!errorRows.length) {
            this._toast('No Errors', 'No error rows available to download.', 'info');
            return;
        }
        
        // Build CSV content
        let csvContent = 'Row Number,Plan Name,Program Name,Provider,Error Message\n';
        
        errorRows.forEach((r, idx) => {
            const programName = this._programMap.get(r.learningProgramId)?.name || r.learningProgramId || '';
            const providerName = r.providerName || '';
            
            // Escape quotes and wrap in quotes for CSV
            const rowNumber = r.index || (idx + 1);
            const planName = (r.name || '').replace(/"/g, '""');
            const progName = programName.replace(/"/g, '""');
            const provider = providerName.replace(/"/g, '""');
            const errorMsg = (r.errorMessage || '').replace(/"/g, '""');
            
            csvContent += `${rowNumber},"${planName}","${progName}","${provider}","${errorMsg}"\n`;
        });
        
        console.log('CSV Content:', csvContent.substring(0, 200) + '...');
        
        // Create filename with timestamp
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-').split('T')[0];
        const filename = `ProgramPlan_Errors_${timestamp}.csv`;
        
        // Download file
        try {
            this._downloadFile(csvContent, filename);
            console.log('Download triggered:', filename);
            this._toast('Download Successful', `Error report saved as ${filename}`, 'success');
        } catch (e) {
            console.error('Download failed:', e);
            this._toast('Download Failed', e.message || 'Could not download file', 'error');
        }
    }
    
    handleCloseSuccess() { this.showSuccessModal = false; }

    // ═══════════════════════════════════════════
    // BUILD PAYLOAD
    // ═══════════════════════════════════════════
    _buildPayload(r) {
        return {
            name: r.name || null,
            learningProgramId: r.learningProgramId || null,
            providerId: r.providerId || null,
            description: r.description || null,
            versionNumber: null,
            isActive: true,
            activeFromDate: r.activeFromDate || null,
            activeToDate: r.activeToDate || null,
            minimumGradePointAvg: null,
            cadenceType: r.cadenceType || null,
            intakeStrength: r.intakeStrength != null ? Number(r.intakeStrength) : null,
            isMonday: false, isTuesday: false, isWednesday: false,
            isThursday: false, isFriday: false, isSaturday: false, isSunday: false,
            durationPerSession: r.durationPerSession != null ? Number(r.durationPerSession) : null,
            batchNumber: r.batchNumber || null,
            section: r.section || null
        };
    }



    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _err(e) {
        if (typeof e === 'string') return e;
        return e?.body?.message || e?.message || 'Unexpected error.';
    }
}