import { LightningElement, track, wire } from 'lwc';
import { initBrand } from 'c/brandConfigService';
import { refreshApex } from '@salesforce/apex';
import getEvaluationSchemaCards from '@salesforce/apex/KenExamCyclePlannerController.getEvaluationSchemaCards';
import getEvaluationSchemaDetail from '@salesforce/apex/KenExamCyclePlannerController.getEvaluationSchemaDetail';
import saveEvaluationSchema from '@salesforce/apex/KenExamCyclePlannerController.saveEvaluationSchema';
import getGradeSchemaCards from '@salesforce/apex/KenExamCyclePlannerController.getGradeSchemaCards';
import getGradeSchemaDetail from '@salesforce/apex/KenExamCyclePlannerController.getGradeSchemaDetail';
import saveGradeSchema from '@salesforce/apex/KenExamCyclePlannerController.saveGradeSchema';

const MOCK_CYCLE_RECORDS = [
    {
        id: 'EC-1001',
        name: 'End Term',
        term: 'Jan-Jun 2026',
        type: 'Regular',
        mappedSchemas: 3,
        courses: 4,
        status: 'Published',
        active: true
    },
    {
        id: 'EC-1002',
        name: 'Semester 3',
        term: 'Jul-Nov 2026',
        type: 'Regular',
        mappedSchemas: 2,
        courses: 3,
        status: 'Draft',
        active: true
    },
    {
        id: 'EC-1003',
        name: 'Supplementary Cycle',
        term: 'Dec 2026',
        type: 'Supplementary',
        mappedSchemas: 1,
        courses: 2,
        status: 'Draft',
        active: false
    }
];

const MOCK_COURSE_MAPPINGS = {
    'EC-1001': [
        {
            id: 'C-101',
            courseName: 'Mathematics I',
            courseCode: 'MTH101',
            credits: 4,
            department: 'Mathematics',
            enrolledStudents: 62,
            evaluationSchemaId: 'SCH-001',
            evaluationSchemaName: 'UG Internal + External',
            maxMarks: 100
        },
        {
            id: 'C-102',
            courseName: 'Physics Fundamentals',
            courseCode: 'PHY101',
            credits: 3,
            department: 'Physics',
            enrolledStudents: 58,
            evaluationSchemaId: 'SCH-002',
            evaluationSchemaName: 'Lab Intensive 75-25',
            maxMarks: 100
        },
        {
            id: 'C-103',
            courseName: 'Programming Basics',
            courseCode: 'CSE101',
            credits: 4,
            department: 'Computer Science',
            enrolledStudents: 71,
            evaluationSchemaId: null,
            evaluationSchemaName: null,
            maxMarks: 0
        },
        {
            id: 'C-104',
            courseName: 'Engineering Graphics',
            courseCode: 'ME101',
            credits: 2,
            department: 'Mechanical',
            enrolledStudents: 45,
            evaluationSchemaId: 'SCH-003',
            evaluationSchemaName: 'Project + Viva Model',
            maxMarks: 100
        }
    ],
    'EC-1002': [
        {
            id: 'C-201',
            courseName: 'Data Structures',
            courseCode: 'CSE201',
            credits: 4,
            department: 'Computer Science',
            enrolledStudents: 52,
            evaluationSchemaId: 'SCH-001',
            evaluationSchemaName: 'UG Internal + External',
            maxMarks: 100
        },
        {
            id: 'C-202',
            courseName: 'Discrete Mathematics',
            courseCode: 'MTH203',
            credits: 3,
            department: 'Mathematics',
            enrolledStudents: 49,
            evaluationSchemaId: null,
            evaluationSchemaName: null,
            maxMarks: 0
        },
        {
            id: 'C-203',
            courseName: 'Digital Electronics',
            courseCode: 'ECE205',
            credits: 3,
            department: 'Electronics',
            enrolledStudents: 47,
            evaluationSchemaId: 'SCH-002',
            evaluationSchemaName: 'Lab Intensive 75-25',
            maxMarks: 100
        }
    ],
    'EC-1003': [
        {
            id: 'C-301',
            courseName: 'Machine Design',
            courseCode: 'ME301',
            credits: 4,
            department: 'Mechanical',
            enrolledStudents: 38,
            evaluationSchemaId: null,
            evaluationSchemaName: null,
            maxMarks: 0
        },
        {
            id: 'C-302',
            courseName: 'Structural Analysis',
            courseCode: 'CE304',
            credits: 4,
            department: 'Civil',
            enrolledStudents: 33,
            evaluationSchemaId: 'SCH-001',
            evaluationSchemaName: 'UG Internal + External',
            maxMarks: 100
        }
    ]
};

function clone(value) {
    return JSON.parse(JSON.stringify(value));
}

export default class ExamManagement extends LightningElement {
    activeTab = 'dashboard';
    activeMasterSection = 'schema'; // ← default open Evaluation Schema

    @track cycleRecords = clone(MOCK_CYCLE_RECORDS);
    @track courseMappingsByCycle = clone(MOCK_COURSE_MAPPINGS);
    @track schemaRecords = [];
    _wiredSchemaCardsResult;

    @track plannerView = 'list';
    @track selectedCycleId;
    @track selectedCycleName;
    @track selectedTermId;

    @track currentView = 'schemaList';
    selectedSchemaId;
    @track editingSchemaRecord;

    @track showCreateCycleModal = false;
    @track showMapSchemaModal = false;
    @track selectedCourseIds = [];
    @track selectedSchemaForMapping = '';

    @track newCycleDraft = {
        name: '',
        term: '',
        type: 'Regular'
    };

    cycleTypeOptions = [
        { label: 'Regular', value: 'Regular' },
        { label: 'Supplementary', value: 'Supplementary' },
        { label: 'Re-exam', value: 'Re-exam' }
    ];

    @track gradeSchemaRecords = [];
    _wiredGradeSchemaCardsResult;
    @track gradeCurrentView = 'gradeList';
    @track editingGradeSchemaRecord;
    selectedGradeSchemaId;

    connectedCallback() {
        initBrand(this.template.host);
    }

    // ── Top-level tab visibility ──────────────────────────────────────────────

    get isDashboardTab()     { return this.activeTab === 'dashboard'; }
    get isMasterDataTab()    { return this.activeTab === 'masterData'; }
    get isExamCycleTab()     { return this.activeTab === 'examCycle'; }
    get isHistoricalDataTab(){ return this.activeTab === 'historicalData'; }

    // ── Master Data sub-tab visibility ────────────────────────────────────────

    get isSchemaTab() { return this.activeMasterSection === 'schema'; }
    get isGradeTab()  { return this.activeMasterSection === 'grade'; }
    get isPolicyTab() { return this.activeMasterSection === 'policy'; }

    // ── Top-level tab classes ─────────────────────────────────────────────────

    get dashboardTabClass() {
        return this.activeTab === 'dashboard' ? 'em-tab-btn em-tab-btn--active' : 'em-tab-btn';
    }
    get masterDataTabClass() {
        return this.activeTab === 'masterData' ? 'em-tab-btn em-tab-btn--active' : 'em-tab-btn';
    }
    get examCycleTabClass() {
        return this.activeTab === 'examCycle' ? 'em-tab-btn em-tab-btn--active' : 'em-tab-btn';
    }
    get historicalDataTabClass() {
        return this.activeTab === 'historicalData' ? 'em-tab-btn em-tab-btn--active' : 'em-tab-btn';
    }

    // ── Master Data sub-tab classes ───────────────────────────────────────────

    get evalSchemaTabClass() {
        return this.activeMasterSection === 'schema'
            ? 'em-master-tab-btn em-master-tab-btn--active'
            : 'em-master-tab-btn';
    }
    get gradeSchemaTabClass() {
        return this.activeMasterSection === 'grade'
            ? 'em-master-tab-btn em-master-tab-btn--active'
            : 'em-master-tab-btn';
    }

    // ── Grade Schema view helpers ─────────────────────────────────────────────

    get isGradeListView()   { return this.gradeCurrentView === 'gradeList'; }
    get isGradeWizardView() { return this.gradeCurrentView === 'gradeWizard'; }

    // ── Handlers ─────────────────────────────────────────────────────────────

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
        if (this.activeTab === 'masterData') {
            // Always land on Evaluation Schema when switching to Master Data
            this.activeMasterSection = 'schema';
        }
        if (this.activeTab === 'examCycle') {
            this.plannerView = 'list';
        }
    }

    handleMasterCardClick(event) {
        const target = event.currentTarget.dataset.target;
        if (target === 'schema' || target === 'grade' || target === 'policy') {
            this.activeMasterSection = target;
        }
    }

    // ── Grade Schema handlers ─────────────────────────────────────────────────

    handleCreateGradeSchema() {
        this.editingGradeSchemaRecord = null;
        this.selectedGradeSchemaId = null;
        this.gradeCurrentView = 'gradeWizard';
    }

    handleGradeSchemaSelected(event) {
        const schemaId = event.detail.schemaId;
        if (!schemaId) return;
        this.selectedGradeSchemaId = schemaId;
        this.editingGradeSchemaRecord = null;

        getGradeSchemaDetail({ schemaId })
            .then((record) => {
                this.editingGradeSchemaRecord = record;
                this.gradeCurrentView = 'gradeWizard';
            })
            .catch((e) => {
                console.error('Failed to load grade schema detail:', JSON.stringify(e));
            });
    }

    async handleSaveGradeSchema(event) {
        const payload = clone(event.detail);

        const request = {
            id: payload.id || null,
            name: payload.name,
            active: payload.active !== false,
            relativeCriteria: payload.relativeCriteria ? {
                id: payload.relativeCriteria.id || null,
                operator: payload.relativeCriteria.operator || null,
                rangeTo: payload.relativeCriteria.rangeTo,
                letterGrades: (payload.relativeCriteria.letterGrades || []).map(lg => ({
                    id: lg.id || null,
                    letterGrade: lg.letterGrade,
                    gradePoint: lg.gradePoint,
                    definition: lg.definition,
                    rangeStart: lg.rangeStart,
                    rangeEnd: lg.rangeEnd
                }))
            } : null,
            absoluteCriteria: payload.absoluteCriteria ? {
                id: payload.absoluteCriteria.id || null,
                operator: payload.absoluteCriteria.operator || null,
                rangeTo: payload.absoluteCriteria.rangeTo,
                letterGrades: (payload.absoluteCriteria.letterGrades || []).map(lg => ({
                    id: lg.id || null,
                    letterGrade: lg.letterGrade,
                    gradePoint: lg.gradePoint,
                    definition: lg.definition,
                    rangeStart: lg.rangeStart,
                    rangeEnd: lg.rangeEnd
                }))
            } : null
        };

        try {
            await saveGradeSchema({ request });
            this.editingGradeSchemaRecord = null;
            this.gradeCurrentView = 'gradeList';
            if (this._wiredGradeSchemaCardsResult) {
                await refreshApex(this._wiredGradeSchemaCardsResult);
            }
        } catch (e) {
            console.error('Save grade schema failed:', JSON.stringify(e));
        }
    }

    handleCancelGradeWizard() {
        this.editingGradeSchemaRecord = null;
        this.gradeCurrentView = 'gradeList';
    }

    // ── Planner helpers ───────────────────────────────────────────────────────

    get isPlannerListView() { return this.plannerView === 'list'; }

    get isSchemaListView()   { return this.currentView === 'schemaList'; }
    get isSchemaDetailView() { return this.currentView === 'schemaDetail'; }
    get isSchemaWizardView() { return this.currentView === 'schemaWizard'; }

    get selectedCycleCourses() {
        if (!this.selectedCycleId) return [];
        return (this.courseMappingsByCycle[this.selectedCycleId] || []).map(c => ({ ...c }));
    }

    get schemaOptions() {
        return this.schemaRecords.map(s => ({ label: s.name, value: s.id }));
    }

    // ── Wire ──────────────────────────────────────────────────────────────────

    @wire(getEvaluationSchemaCards)
    wiredEvaluationSchemaCards(result) {
        this._wiredSchemaCardsResult = result;
        if (result.data) this.schemaRecords = result.data;
    }

    @wire(getGradeSchemaCards)
    wiredGradeSchemaCards(result) {
        this._wiredGradeSchemaCardsResult = result;
        if (result.data) this.gradeSchemaRecords = result.data;
    }

    // ── Cycle modal ───────────────────────────────────────────────────────────

    get selectedCourseCount() { return this.selectedCourseIds.length; }
    get disableApplySchema()  { return !this.selectedSchemaForMapping || this.selectedCourseIds.length === 0; }

    handleOpenCreateModal() { this.showCreateCycleModal = true; }

    handleCloseCreateModal() {
        this.showCreateCycleModal = false;
        this.newCycleDraft = { name: '', term: '', type: 'Regular' };
    }

    handleNewCycleInputChange(event) {
        const fieldName = event.target.dataset.field;
        this.newCycleDraft = { ...this.newCycleDraft, [fieldName]: event.detail.value };
    }

    handleSaveCreateCycle() {
        const { name, term, type } = this.newCycleDraft;
        if (!name || !term || !type) return;

        const newCycleId = `EC-${Date.now()}`;
        const newCycle = { id: newCycleId, name, term, type, mappedSchemas: 0, courses: 0, status: 'Draft', active: false };

        this.cycleRecords = [newCycle, ...this.cycleRecords];
        this.courseMappingsByCycle = { ...this.courseMappingsByCycle, [newCycleId]: [] };
        this.handleCloseCreateModal();
    }

    handleCycleClicked(event) {
        this.selectedCycleId   = event.detail.cycleId;
        this.selectedCycleName = event.detail.cycleName;
        this.selectedTermId    = event.detail.termId;
        this.plannerView = 'mapping';
    }

    handlePlannerBack() {
        this.plannerView       = 'list';
        this.selectedCycleId   = null;
        this.selectedCycleName = null;
        this.selectedTermId    = null;
    }

    // ── Schema handlers ───────────────────────────────────────────────────────

    handleCreateSchema() {
        this.selectedSchemaId = null;
        this.editingSchemaRecord = null;
        this.currentView = 'schemaWizard';
    }

    handleSchemaSelected(event) {
        this.selectedSchemaId = event.detail.schemaId;
        this.currentView = 'schemaDetail';
    }

    handleSchemaBackToList() {
        this.currentView = 'schemaList';
    }

    handleEditSchema(event) {
        const schemaId = event.detail.schemaId || this.selectedSchemaId;
        if (!schemaId) return;

        this.selectedSchemaId = schemaId;
        this.editingSchemaRecord = null;

        getEvaluationSchemaDetail({ schemaId })
            .then((record) => {
                this.editingSchemaRecord = record;
                this.currentView = 'schemaWizard';
            })
            .catch(() => { this.editingSchemaRecord = null; });
    }

    handleDeleteSchema(event) {
        const schemaId = event.detail.schemaId || this.selectedSchemaId;
        if (!schemaId) return;

        this.schemaRecords = this.schemaRecords.filter(s => s.id !== schemaId);

        const nextMappings = {};
        Object.keys(this.courseMappingsByCycle).forEach(cycleId => {
            nextMappings[cycleId] = this.courseMappingsByCycle[cycleId].map(course => {
                if (course.evaluationSchemaId !== schemaId) return course;
                return { ...course, evaluationSchemaId: null, evaluationSchemaName: null, maxMarks: 0 };
            });
        });

        this.courseMappingsByCycle = nextMappings;
        this.refreshAllCycleStats();

        if (this.selectedSchemaId === schemaId) {
            this.selectedSchemaId = null;
            this.currentView = 'schemaList';
        }
    }

    async handleSaveSchema(event) {
        const payload = clone(event.detail);

        const request = {
            id: payload.id || null,
            name: payload.name,
            description: payload.description,
            totalMarks: payload.totalMarks,
            passingMarks: payload.passingMarks,
            isRequiredForGrading: payload.isRequiredForGrading !== false,
            components: (payload.components || []).map(component => ({
                id: component.id || null,
                name: component.name,
                kenComponent: component.kenComponent || null,
                examType: component.examType || 'Regular',
                effectiveMarks: component.effectiveMarks,
                maxMarks: component.maxMarks,
                minMarks: component.minMarks,
                passingMarks: component.passingMarks,
                weightage: component.weightage,
                enrollmentType: component.enrollmentType,
                considerForPassFail: component.considerForPassFail,
                subComponents: (component.subComponents || []).map(sub => ({
                    id: sub.id || null,
                    name: sub.name,
                    kenAssessment: sub.kenAssessment || null,
                    examType: sub.examType || component.examType || 'Regular',
                    examRequired: sub.examRequired !== false,
                    effectiveMarks: sub.effectiveMarks,
                    maxMarks: sub.maxMarks,
                    minMarks: sub.minMarks,
                    passingMarks: sub.passingMarks,
                    weightage: sub.weightage,
                    enrollmentType: sub.enrollmentType,
                    considerForPassFail: sub.considerForPassFail
                }))
            }))
        };

        try {
            const schemaId = await saveEvaluationSchema({ request });
            this.selectedSchemaId = schemaId;
            this.editingSchemaRecord = null;
            this.currentView = 'schemaDetail';
            if (this._wiredSchemaCardsResult) {
                await refreshApex(this._wiredSchemaCardsResult);
            }
        } catch (e) {
            console.error('Save schema failed:', JSON.stringify(e));
        }
    }

    handleCancelWizard() {
        this.editingSchemaRecord = null;
        this.currentView = this.selectedSchemaId ? 'schemaDetail' : 'schemaList';
    }

    // ── Cycle stats helpers ───────────────────────────────────────────────────

    getSchemaName(schemaId) {
        const matched = this.schemaRecords.find(s => s.id === schemaId);
        return matched ? matched.name : null;
    }

    getSchemaTotalMarks(schemaId) {
        const matched = this.schemaRecords.find(s => s.id === schemaId);
        return matched ? Number(matched.totalMarks) : 0;
    }

    refreshAllCycleStats() {
        this.cycleRecords = this.cycleRecords.map(cycle => this.buildCycleStats(cycle));
    }

    refreshCycleStats(cycleId) {
        this.cycleRecords = this.cycleRecords.map(cycle =>
            cycle.id !== cycleId ? cycle : this.buildCycleStats(cycle)
        );
    }

    buildCycleStats(cycleRecord) {
        const cycleCourses = this.courseMappingsByCycle[cycleRecord.id] || [];
        const uniqueSchemas = new Set(
            cycleCourses.filter(c => c.evaluationSchemaId).map(c => c.evaluationSchemaId)
        );
        return { ...cycleRecord, courses: cycleCourses.length, mappedSchemas: uniqueSchemas.size };
    }
}