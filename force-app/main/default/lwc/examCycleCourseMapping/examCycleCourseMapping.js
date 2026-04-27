import { LightningElement, api, track, wire } from 'lwc';
import { initBrand } from 'c/brandConfigService';
import getCoursesForMapping from '@salesforce/apex/KenExamCyclePlannerController.getCoursesForMapping';
import getEvaluationSchemas from '@salesforce/apex/KenExamCyclePlannerController.getEvaluationSchemas';
import getCourseOfferingFilterOptions from '@salesforce/apex/KenExamCyclePlannerController.getCourseOfferingFilterOptions';
import getCourseOfferingsByCourse from '@salesforce/apex/KenExamCyclePlannerController.getCourseOfferingsByCourse';
import mapSchema            from '@salesforce/apex/KenExamCyclePlannerController.mapSchema';
import unmapSchema          from '@salesforce/apex/KenExamCyclePlannerController.unmapSchema';
import mapGradeSchema       from '@salesforce/apex/KenExamCyclePlannerController.mapGradeSchema';
import unmapGradeSchema     from '@salesforce/apex/KenExamCyclePlannerController.unmapGradeSchema';

export default class ExamCycleCourseMapping extends LightningElement {
    @api cycleId;
    @api cycleName;
    @api gradeSchemas = [];

    _termId;

    connectedCallback() {
        initBrand(this.template.host);
        // Close dropdown when clicking outside
        this._outsideClickHandler = this._handleOutsideClick.bind(this);
        document.addEventListener('click', this._outsideClickHandler);
    }

    disconnectedCallback() {
        document.removeEventListener('click', this._outsideClickHandler);
    }

    @api
    get termId() { return this._termId; }
    set termId(value) {
        this._termId = value;
        if (value) this._loadCourses();
    }

    @track selectedRowIds        = [];
    @track isLoading             = true;
    @track hasError              = false;
    @track errorMessage          = '';
    @track isSaving              = false;
    @track showSelectionToast    = false;

    // tracks which row's menu is open
    @track openMenuId            = null;

    // tracks which course IDs are being mapped (row or bulk)
    _mappingCourseIds            = [];

    // Evaluation Schema modal
    @track showMapEvalModal      = false;
    @track evalSchemaSearchTerm  = '';
    @track pickedEvalSchemaId    = null;

    // Grade Schema modal
    @track showMapGradeModal     = false;
    @track gradeSchemaSearchTerm = '';
    @track pickedGradeSchemaId   = null;

    @track selectedCourseId = null;
    @track activeCourseDetailTab = 'courseOffering';
    @track selectedAcademicSessionId = '';
    @track selectedEnrollmentType = '';
    @track academicSessionOptions = [];
    @track enrollmentTypeOptions = [];
    @track courseOfferingRowsData = [];
    @track isCourseOfferingsLoading = false;

    _allCourses     = [];
    _allEvalSchemas = [];

    // ── Wire ──────────────────────────────────────────────────────────────────
    @wire(getEvaluationSchemas)
    wiredSchemas({ data, error }) {
        if (data)  this._allEvalSchemas = data;
        if (error) console.error('Failed to load evaluation schemas', error);
    }

    // ── Course load ───────────────────────────────────────────────────────────
    async _loadCourses() {
        this.isLoading = true;
        this.hasError  = false;
        try {
            const data       = await getCoursesForMapping({ termId: this._termId });
            this._allCourses = data || [];
        } catch (err) {
            this.hasError     = true;
            this.errorMessage = this._extractError(err);
            this._allCourses  = [];
        } finally {
            this.isLoading = false;
        }
    }

    // ── Computed ──────────────────────────────────────────────────────────────
    get cycleMetaLine() { return this.termId || ''; }

    get displayedCourses() {
        return this._allCourses.map(c => {
            return {
                ...c,
                hasEvalSchema:   !!c.evaluationSchemaName,
                hasGradeSchema:  !!c.gradeSchemaName,
                isSelected:      this.selectedRowIds.includes(c.id),
                menuOpen:        this.openMenuId === c.id,
                rowClass:        this.selectedRowIds.includes(c.id)
                    ? 'ecm-table-row ecm-table-row--selected'
                    : 'ecm-table-row'
            };
        });
    }

    get hasCourses()    { return this._allCourses.length > 0; }
    get hasSelection()  { return this.selectedRowIds.length > 0; }
    get selectedCount() { return this.selectedRowIds.length; }
    get mappingCount()  { return this._mappingCourseIds.length; }
    get isCourseDetailView() { return !!this.selectedCourseId; }

    get selectedCourse() {
        return this._allCourses.find(course => course.id === this.selectedCourseId) || null;
    }

    get selectedCourseName() {
        const course = this.selectedCourse;
        return course ? course.courseName : '';
    }

    get courseMasterTabClass() {
        return this.activeCourseDetailTab === 'masterCourse'
            ? 'ecm-detail-tab ecm-detail-tab--active'
            : 'ecm-detail-tab';
    }

    get courseOfferingTabClass() {
        return this.activeCourseDetailTab === 'courseOffering'
            ? 'ecm-detail-tab ecm-detail-tab--active'
            : 'ecm-detail-tab';
    }

    get courseOfferingRows() {
        return this.courseOfferingRowsData;
    }

    get hasCourseOfferings() {
        return this.courseOfferingRowsData.length > 0;
    }

    get allSelected() {
        return this._allCourses.length > 0 &&
               this.selectedRowIds.length === this._allCourses.length;
    }

    // ── Toast ─────────────────────────────────────────────────────────────────
    _showToast() {
        this.showSelectionToast = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showSelectionToast = false; }, 3000);
    }

    // ── Checkbox ──────────────────────────────────────────────────────────────
    handleCheckboxChange(event) {
        event.stopPropagation();
        const id      = event.currentTarget.dataset.id;
        const checked = event.target.checked;
        this.selectedRowIds = checked
            ? [...this.selectedRowIds.filter(rid => rid !== id), id]
            : this.selectedRowIds.filter(rid => rid !== id);
    }

    handleSelectAll(event) {
        event.stopPropagation();
        this.selectedRowIds = event.target.checked
            ? this._allCourses.map(c => c.id)
            : [];
    }

    stopEvent(event) {
        event.stopPropagation();
    }

    // ── 3-dot menu toggle ─────────────────────────────────────────────────────
    handleMenuToggle(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this.openMenuId = this.openMenuId === id ? null : id;
    }

    _handleOutsideClick() {
        if (this.openMenuId) this.openMenuId = null;
    }

    // ── Row-level actions (from 3-dot menu) ───────────────────────────────────
    handleCourseClick(event) {
        event.stopPropagation();
        const courseId = event.currentTarget.dataset.id;
        if (!courseId) return;
        this.selectedCourseId = courseId;
        this.activeCourseDetailTab = 'courseOffering';
        this.selectedAcademicSessionId = '';
        this.selectedEnrollmentType = '';
        this.loadCourseOfferingFiltersAndRows();
    }

    handleBackToCourseList() {
        this.selectedCourseId = null;
        this.activeCourseDetailTab = 'courseOffering';
        this.selectedAcademicSessionId = '';
        this.selectedEnrollmentType = '';
        this.academicSessionOptions = [];
        this.enrollmentTypeOptions = [];
        this.courseOfferingRowsData = [];
    }

    handleCourseDetailTabClick(event) {
        const nextTab = event.currentTarget.dataset.detailTab;
        if (nextTab === 'masterCourse') {
            this.handleBackToCourseList();
            return;
        }
        if (nextTab === 'masterCourse' || nextTab === 'courseOffering') {
            this.activeCourseDetailTab = nextTab;
        }
    }

    handleAcademicSessionFilterChange(event) {
        this.selectedAcademicSessionId = event.target.value || '';
        this.loadCourseOfferings();
    }

    handleEnrollmentTypeFilterChange(event) {
        this.selectedEnrollmentType = event.target.value || '';
        this.loadCourseOfferings();
    }

    handleRowMapEval(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this.openMenuId = null;
        this._mappingCourseIds    = [id];
        this.pickedEvalSchemaId   = null;
        this.evalSchemaSearchTerm = '';
        this.showMapEvalModal     = true;
    }

    async handleRowUnmapEval(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this.openMenuId = null;
        if (!this._termId) return;
        this.isSaving = true;
        try {
            await unmapSchema({ learningCourseIds: [id], termId: this._termId });
            await this._loadCourses();
        } catch (err) {
            this.hasError = true; this.errorMessage = this._extractError(err);
        } finally { this.isSaving = false; }
    }

    handleRowMapGrade(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this.openMenuId = null;
        this._mappingCourseIds     = [id];
        this.pickedGradeSchemaId   = null;
        this.gradeSchemaSearchTerm = '';
        this.showMapGradeModal     = true;
    }

    async handleRowUnmapGrade(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this.openMenuId = null;
        await this._unmapGradeSchemas([id]);
    }

    // ── Bulk top-bar actions ──────────────────────────────────────────────────
    handleBulkMapEval() {
        if (!this.hasSelection) { this._showToast(); return; }
        this._mappingCourseIds    = [...this.selectedRowIds];
        this.pickedEvalSchemaId   = null;
        this.evalSchemaSearchTerm = '';
        this.showMapEvalModal     = true;
    }

    async handleBulkUnmapEval() {
        if (!this.hasSelection) { this._showToast(); return; }
        if (!this._termId) return;
        this.isSaving = true;
        try {
            await unmapSchema({ learningCourseIds: this.selectedRowIds, termId: this._termId });
            this.selectedRowIds = [];
            await this._loadCourses();
        } catch (err) {
            this.hasError = true; this.errorMessage = this._extractError(err);
        } finally { this.isSaving = false; }
    }

    handleBulkMapGrade() {
        if (!this.hasSelection) { this._showToast(); return; }
        this._mappingCourseIds     = [...this.selectedRowIds];
        this.pickedGradeSchemaId   = null;
        this.gradeSchemaSearchTerm = '';
        this.showMapGradeModal     = true;
    }

    async handleBulkUnmapGrade() {
        if (!this.hasSelection) { this._showToast(); return; }
        await this._unmapGradeSchemas(this.selectedRowIds);
    }

    // ── Eval Schema modal ─────────────────────────────────────────────────────
    handleCloseEvalModal() {
        this.showMapEvalModal   = false;
        this.pickedEvalSchemaId = null;
        this.evalSchemaSearchTerm = '';
        this._mappingCourseIds  = [];
    }

    handleEvalSchemaSearch(event)    { this.evalSchemaSearchTerm = event.target.value || ''; }
    handleEvalSchemaItemClick(event) { this.pickedEvalSchemaId = event.currentTarget.dataset.id; }
    handleEvalSchemaItemKey(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            this.pickedEvalSchemaId = event.currentTarget.dataset.id;
        }
    }

    get filteredEvalSchemas() {
        const q    = (this.evalSchemaSearchTerm || '').trim().toLowerCase();
        const list = q
            ? this._allEvalSchemas.filter(s => s.name.toLowerCase().includes(q))
            : this._allEvalSchemas;
        return list.map(s => ({
            ...s,
            isSelected: s.id === this.pickedEvalSchemaId,
            itemClass:  s.id === this.pickedEvalSchemaId
                ? 'ecm-schema-item ecm-schema-item--selected'
                : 'ecm-schema-item'
        }));
    }

    get hasFilteredEvalSchemas() { return this.filteredEvalSchemas.length > 0; }
    get evalApplyDisabled()      { return !this.pickedEvalSchemaId || this.isSaving; }

    async handleApplyEvalSchema() {
        if (!this.pickedEvalSchemaId || !this._mappingCourseIds.length || !this._termId) return;
        this.isSaving = true;
        try {
            await mapSchema({
                learningCourseIds: this._mappingCourseIds,
                termId:            this._termId,
                schemaId:          this.pickedEvalSchemaId
            });
            this.selectedRowIds = [];
            this.handleCloseEvalModal();
            await this._loadCourses();
        } catch (err) {
            this.hasError = true; this.errorMessage = this._extractError(err);
        } finally { this.isSaving = false; }
    }

    // ── Grade Schema modal ────────────────────────────────────────────────────
    handleCloseGradeModal() {
        this.showMapGradeModal    = false;
        this.pickedGradeSchemaId  = null;
        this.gradeSchemaSearchTerm = '';
        this._mappingCourseIds    = [];
    }

    handleGradeSchemaSearch(event)    { this.gradeSchemaSearchTerm = event.target.value || ''; }
    handleGradeSchemaItemClick(event) { this.pickedGradeSchemaId = event.currentTarget.dataset.id; }
    handleGradeSchemaItemKey(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            this.pickedGradeSchemaId = event.currentTarget.dataset.id;
        }
    }

    get filteredGradeSchemas() {
        const q    = (this.gradeSchemaSearchTerm || '').trim().toLowerCase();
        const list = q
            ? (this.gradeSchemas || []).filter(s => s.name.toLowerCase().includes(q))
            : (this.gradeSchemas || []);
        return list.map(s => ({
            ...s,
            isSelected: s.id === this.pickedGradeSchemaId,
            itemClass:  s.id === this.pickedGradeSchemaId
                ? 'ecm-schema-item ecm-schema-item--selected'
                : 'ecm-schema-item'
        }));
    }

    get hasFilteredGradeSchemas() { return this.filteredGradeSchemas.length > 0; }
    get gradeApplyDisabled()      { return !this.pickedGradeSchemaId || this.isSaving; }

    async handleApplyGradeSchema() {
        if (!this.pickedGradeSchemaId || !this._mappingCourseIds.length || !this._termId) return;
        this.isSaving = true;
        try {
            await mapGradeSchema({
                learningCourseIds: this._mappingCourseIds,
                termId: this._termId,
                gradeSchemaId: this.pickedGradeSchemaId
            });
            this.selectedRowIds = [];
            this.handleCloseGradeModal();
            await this._loadCourses();
        } catch (err) {
            this.hasError = true;
            this.errorMessage = this._extractError(err);
        } finally {
            this.isSaving = false;
        }
    }

    // ── Navigation ────────────────────────────────────────────────────────────
    handleBack() { this.dispatchEvent(new CustomEvent('back')); }

    // ── Helpers ───────────────────────────────────────────────────────────────
    _extractError(err) {
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'An unexpected error occurred.';
    }

    async _unmapGradeSchemas(courseIds) {
        if (!courseIds || !courseIds.length || !this._termId) return;
        this.isSaving = true;
        try {
            await unmapGradeSchema({
                learningCourseIds: courseIds,
                termId: this._termId
            });
            this.selectedRowIds = [];
            await this._loadCourses();
        } catch (err) {
            this.hasError = true;
            this.errorMessage = this._extractError(err);
        } finally {
            this.isSaving = false;
        }
    }

    async loadCourseOfferingFiltersAndRows() {
        if (!this.selectedCourseId || !this._termId) return;
        this.isCourseOfferingsLoading = true;
        try {
            const options = await getCourseOfferingFilterOptions({
                termId: this._termId,
                learningCourseId: this.selectedCourseId
            });
            const sessionOptions = (options && options.academicSessions ? options.academicSessions : []).map(item => ({
                label: item.name,
                value: item.id
            }));
            const enrollmentOptions = (options && options.enrollmentTypes ? options.enrollmentTypes : []).map(item => ({
                label: item.label,
                value: item.value
            }));
            this.academicSessionOptions = [{ label: 'Select an Option', value: '' }, ...sessionOptions];
            this.enrollmentTypeOptions = [{ label: 'All', value: '' }, ...enrollmentOptions];
            await this.loadCourseOfferings();
        } catch (err) {
            this.hasError = true;
            this.errorMessage = this._extractError(err);
        } finally {
            this.isCourseOfferingsLoading = false;
        }
    }

    async loadCourseOfferings() {
        if (!this.selectedCourseId || !this._termId) return;
        this.isCourseOfferingsLoading = true;
        try {
            const rows = await getCourseOfferingsByCourse({
                termId: this._termId,
                learningCourseId: this.selectedCourseId,
                academicSessionId: this.selectedAcademicSessionId || null,
                enrollmentType: this.selectedEnrollmentType || null
            });
            this.courseOfferingRowsData = (rows || []).map(row => ({
                id: row.id,
                programOffering: row.activeProgramOfferings,
                courseNumber: row.courseNumber,
                courseName: row.courseName,
                enrollmentCapacity: row.enrollmentCapacity,
                filledInCount: row.filledInCount,
                courseType: row.courseType,
                sessionType: row.offeringType
            }));
        } catch (err) {
            this.hasError = true;
            this.errorMessage = this._extractError(err);
            this.courseOfferingRowsData = [];
        } finally {
            this.isCourseOfferingsLoading = false;
        }
    }
}