import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { initBrand } from 'c/brandConfigService';
import getExamPlans from '@salesforce/apex/KenExamCyclePlannerController.getExamPlans';
import getExamPlanAssessmentOptions from '@salesforce/apex/KenExamCyclePlannerController.getExamPlanAssessmentOptions';
import createExamPlan from '@salesforce/apex/KenExamCyclePlannerController.createExamPlan';
import getExaminationsByPlan from '@salesforce/apex/KenExamCyclePlannerController.getExaminationsByPlan';
import getEnrollmentProgramsByPlan from '@salesforce/apex/KenExamCyclePlannerController.getEnrollmentProgramsByPlan';
import getEnrollmentCriteriaOptions from '@salesforce/apex/KenExamCyclePlannerController.getEnrollmentCriteriaOptions';
import createEnrollmentCriteria from '@salesforce/apex/KenExamCyclePlannerController.createEnrollmentCriteria';
import getEnrollmentCriteriaDetail from '@salesforce/apex/KenExamCyclePlannerController.getEnrollmentCriteriaDetail';
import getExaminationFeeTypes from '@salesforce/apex/KenExamCyclePlannerController.getExaminationFeeTypes';
import getScheduleRows from '@salesforce/apex/KenExamCyclePlannerController.getScheduleRows';
import saveScheduleConfiguration from '@salesforce/apex/KenExamCyclePlannerController.saveScheduleConfiguration';

const NO_FEE_CRITERIA = 'No Fee Any Students';

export default class ExamCycleCourseWorkspace extends LightningElement {
    @api cycleId;
    @api cycleName;
    @api termId;
    @api gradeSchemas;

    @track activeTab = 'examPlanning';
    @track planningView = 'list';
    @track activePlanningTab = 'exams';
    @track selectedPlanId = null;
    @track selectedProgramIds = [];
    @track showEnrollmentModal = false;

    // ── Exam Plan state ────────────────────────────────────────────────────
    @track plans = [];
    @track plansError = '';
    @track assessmentOptions = [];
    @track showCreatePlanModal = false;
    @track isSavingPlan = false;
    @track planSaveError = '';
    @track newPlan = {
        name: '',
        assessment: '',
        startDate: '',
        endDate: ''
    };
    _wiredPlansRef;

    // ── Examinations (Exams subtab) state ─────────────────────────────────
    @track examRows = [];
    @track examRowsError = '';
    _wiredExamsRef;

    // ─── Enrollment Window (Programs) state ──────────────────────────────────────────────────────
    @track enrollmentPrograms = [];
    @track enrollmentProgramsError = '';
    _wiredEnrollmentRef;

    // ─── Schedule (Schedule subtab) state ────────────────────────────────────
    @track scheduleData = [];
    @track scheduleError = '';
    @track selectedScheduleKeys = [];
    @track showScheduleModal = false;
    @track scheduleModalRow = null;
    @track scheduleSets = [];
    @track scheduleSaveError = '';
    @track isSavingSchedule = false;
    _wiredScheduleRef;
    _scheduleSetCounter = 0;

    @track feeCriteriaOptionsData = [];
    @track backlogOptionsData = [];
    @track regularOptionsData = [];
    @track feeTypeOptionsData = [];
    @track isSavingEnrollment = false;
    @track enrollmentSaveError = '';

    @track showCriteriaViewModal = false;
    @track isLoadingCriteria = false;
    @track criteriaViewError = '';
    @track criteriaView = null;

    _feeRowCounter = 0;

    @track enrollmentDraft = {
        startOn: '',
        endsOn: '',
        lateFineOn: '',
        sameFeeCriteria: false,
        feeCriteria: '',
        feeItems: [],
        regularFeeCriteria: '',
        regularFeeItems: [],
        backlogFeeCriteria: '',
        backlogFeeItems: [],
        allowBacklog: true,
        backlogMode: '',
        allowRegular: true,
        regularMode: '',
        declaration: ''
    };

    connectedCallback() {
        initBrand(this.template.host);
    }

    // ── Wires ──────────────────────────────────────────────────────────────
    @wire(getExamPlans, { cycleId: '$cycleId' })
    wiredPlans(result) {
        this._wiredPlansRef = result;
        if (result.data) {
            this.plans = result.data;
            this.plansError = '';
        } else if (result.error) {
            this.plans = [];
            this.plansError = (result.error.body && result.error.body.message)
                ? result.error.body.message
                : 'Failed to load exam plans.';
        }
    }

    @wire(getExamPlanAssessmentOptions)
    wiredAssessmentOptions({ data, error }) {
        if (data) {
            this.assessmentOptions = data.map((opt) => ({ label: opt.label, value: opt.value }));
        } else if (error) {
            this.assessmentOptions = [];
        }
    }

    @wire(getExaminationsByPlan, { planId: '$selectedPlanId' })
    wiredExams(result) {
        this._wiredExamsRef = result;
        if (result.data) {
            this.examRows = result.data;
            this.examRowsError = '';
        } else if (result.error) {
            this.examRows = [];
            this.examRowsError = (result.error.body && result.error.body.message)
                ? result.error.body.message
                : 'Failed to load examinations.';
        }
    }

    @wire(getEnrollmentCriteriaOptions)
    wiredEnrollmentCriteriaOptions({ data, error }) {
        if (data) {
            this.feeCriteriaOptionsData = (data.feeCriteria || []).map((o) => ({ label: o.label, value: o.value }));
            this.backlogOptionsData = (data.backlogOptions || []).map((o) => ({ label: o.label, value: o.value }));
            this.regularOptionsData = (data.regularOptions || []).map((o) => ({ label: o.label, value: o.value }));
            const defaultFee = this._defaultFeeCriteriaValue();
            const patch = {};
            if (!this.enrollmentDraft.feeCriteria && defaultFee) patch.feeCriteria = defaultFee;
            if (!this.enrollmentDraft.regularFeeCriteria && defaultFee) patch.regularFeeCriteria = defaultFee;
            if (!this.enrollmentDraft.backlogFeeCriteria && defaultFee) patch.backlogFeeCriteria = defaultFee;
            if (!this.enrollmentDraft.backlogMode && this.backlogOptionsData.length) patch.backlogMode = this.backlogOptionsData[0].value;
            if (!this.enrollmentDraft.regularMode && this.regularOptionsData.length) patch.regularMode = this.regularOptionsData[0].value;
            if (Object.keys(patch).length) {
                this.enrollmentDraft = { ...this.enrollmentDraft, ...patch };
            }
        } else if (error) {
            this.feeCriteriaOptionsData = [];
            this.backlogOptionsData = [];
            this.regularOptionsData = [];
        }
    }

    @wire(getExaminationFeeTypes)
    wiredFeeTypes({ data, error }) {
        if (data) {
            this.feeTypeOptionsData = data.map((o) => ({ label: o.label, value: o.value }));
        } else if (error) {
            this.feeTypeOptionsData = [];
        }
    }

    _defaultFeeCriteriaValue() {
        if (!this.feeCriteriaOptionsData || !this.feeCriteriaOptionsData.length) return '';
        const match = this.feeCriteriaOptionsData.find((o) => o.value === NO_FEE_CRITERIA || o.label === NO_FEE_CRITERIA);
        return (match && match.value) || this.feeCriteriaOptionsData[0].value;
    }

    @wire(getScheduleRows, { planId: '$selectedPlanId' })
    wiredSchedule(result) {
        this._wiredScheduleRef = result;
        if (result.data) {
            this.scheduleData = result.data;
            this.scheduleError = '';
            const allowed = new Set((result.data || []).map((r) => r.key));
            this.selectedScheduleKeys = (this.selectedScheduleKeys || []).filter((k) => allowed.has(k));
        } else if (result.error) {
            this.scheduleData = [];
            this.scheduleError = (result.error.body && result.error.body.message)
                ? result.error.body.message
                : 'Failed to load schedule.';
            this.selectedScheduleKeys = [];
        }
    }

    @wire(getEnrollmentProgramsByPlan, { planId: '$selectedPlanId' })
    wiredEnrollmentPrograms(result) {
        this._wiredEnrollmentRef = result;
        if (result.data) {
            this.enrollmentPrograms = result.data;
            this.enrollmentProgramsError = '';
            const allowedIds = new Set((result.data || []).map((r) => r.id));
            this.selectedProgramIds = (this.selectedProgramIds || []).filter((id) => allowedIds.has(id));
        } else if (result.error) {
            this.enrollmentPrograms = [];
            this.enrollmentProgramsError = (result.error.body && result.error.body.message)
                ? result.error.body.message
                : 'Failed to load enrollment programs.';
            this.selectedProgramIds = [];
        }
    }

    get planningCards() {
        return this.plans.map((plan) => ({
            id: plan.id,
            name: plan.name,
            examType: plan.assessment || '—',
            startDate: plan.startDate || '—',
            endDate: plan.endDate || '—',
            status: plan.status || plan.Status || 'Active',
            statusClass: this._planStatusClass(plan.status || plan.Status || 'Active')
        }));
    }

    get hasPlans() { return this.plans && this.plans.length > 0; }

    get selectedPlanName() {
        const matched = this.plans.find((item) => item.id === this.selectedPlanId);
        return matched ? matched.name : 'Exam Plan';
    }

    get selectedPlanDateLine() {
        const matched = this.plans.find((item) => item.id === this.selectedPlanId);
        if (!matched) return '';
        const s = matched.startDate || '';
        const e = matched.endDate || '';
        return s || e ? `${s} - ${e}` : '';
    }

    get enrollmentRows() {
        return (this.enrollmentPrograms || []).map((item) => ({
            ...item,
            isSelected: (this.selectedProgramIds || []).includes(item.id)
        }));
    }

    get hasEnrollmentRows() { return this.enrollmentPrograms && this.enrollmentPrograms.length > 0; }

    get planExamRows() {
        return (this.examRows || []).map((row) => ({
            id:                  row.id,
            code:                row.courseNumber || '—',
            course:              row.courseName || '—',
            enrollmentStatus:    this._statusView(row.enrollment),
            questionPaperStatus: this._statusView(row.questionPaper),
            scheduleStatus:      this._statusView(row.schedule),
            seatingPlanStatus:   this._statusView(row.seatingPlan),
            invigilatorStatus:   this._statusView(row.invigilator),
            marksEntryStatus:    this._statusView(row.marksEntry)
        }));
    }

    get hasExamRows() { return this.examRows && this.examRows.length > 0; }

    get flatScheduleRows() {
        const selected = new Set(this.selectedScheduleKeys || []);
        const out = [];
        (this.scheduleData || []).forEach((row) => {
            const recs = (row.schedules && row.schedules.length) ? row.schedules : [null];
            const code = row.courseNumber || '—';
            const course = row.courseName || '—';
            const students = row.enrolledStudents || 0;
            const isSelected = selected.has(row.key);
            recs.forEach((s, i) => {
                out.push({
                    rowKey: `${row.key}__${i}`,
                    sectionKey: row.key,
                    isFirst: i === 0,
                    rowspan: recs.length,
                    code,
                    course,
                    students,
                    isSelected,
                    booked: s && s.count != null ? s.count : '—',
                    date: s ? this._formatDate(s.startDateTime) : '—',
                    startTime: s ? this._formatTime(s.startDateTime) : '—',
                    endTime: s ? this._formatTime(s.endDateTime) : '—',
                    duration: s ? this._formatDuration(s.durationHours) : '—'
                });
            });
        });
        return out;
    }

    get hasScheduleRows() { return (this.scheduleData || []).length > 0; }
    get hasScheduleSelection() { return (this.selectedScheduleKeys || []).length > 0; }
    get scheduleSelectionCount() { return (this.selectedScheduleKeys || []).length; }
    get configureScheduleLabel() {
        return `Configure Schedule (${this.scheduleSelectionCount})`;
    }
    get isConfigureDisabled() { return !this.hasScheduleSelection; }
    get scheduleModalTitle() {
        if (!this.scheduleModalRow) return 'Configure Schedule';
        return `Configure Schedule — ${this.scheduleModalRow.code} ${this.scheduleModalRow.course}`;
    }
    get scheduleSetsForRender() {
        return (this.scheduleSets || []).map((s, idx) => ({
            ...s,
            label: `Schedule ${idx + 1}`,
            canRemove: this.scheduleSets.length > 1
        }));
    }
    get scheduleSetsTotal() {
        return (this.scheduleSets || []).reduce(
            (sum, s) => sum + (s.count != null && s.count !== '' ? Number(s.count) : 0),
            0
        );
    }
    get scheduleEnrolledTotal() {
        return this.scheduleModalRow ? this.scheduleModalRow.students : 0;
    }
    get scheduleSetsCount() { return (this.scheduleSets || []).length; }

    get seatingRows() {
        return [
            { id: 'sp1', venue: 'A-Block Hall 1', code: 'CS101', course: 'Intro to Computer Science', date: '2026-05-01', capacity: 150, assigned: 145 },
            { id: 'sp2', venue: 'B-Block Hall 2', code: 'MATH201', course: 'Calculus II', date: '2026-05-03', capacity: 100, assigned: 98 },
            { id: 'sp3', venue: 'A-Block Hall 3', code: 'PHY101', course: 'Physics I', date: '2026-05-05', capacity: 130, assigned: 120 }
        ];
    }

    get questionPaperRows() {
        return [
            { id: 'qp1', code: 'CS101', course: 'Intro to Computer Science', type: 'Theory', faculty: 'Dr. John Smith, Dr. Michael Brown', moderator: '-', submission: 'Completed', approval: 'Pending Approval', actionLabel: 'Approve' },
            { id: 'qp2', code: 'MATH201', course: 'Calculus II', type: 'Theory', faculty: '-', moderator: '-', submission: 'Not Configured', approval: '-', actionLabel: 'Request Changes' },
            { id: 'qp3', code: 'PHY101', course: 'Physics I', type: 'Theory + Lab', faculty: 'Dr. Sarah Johnson', moderator: '-', submission: 'In Progress', approval: 'Not Submitted', actionLabel: 'Approve' }
        ];
    }

    get bundlingRows() {
        return [
            { id: 'b1', code: 'CS101', course: 'Data Structures', date: '2024-03-15', time: '09:00 AM - 12:00 PM', submitted: 125, total: 130 },
            { id: 'b2', code: 'CS102', course: 'Algorithms', date: '2024-03-16', time: '02:00 PM - 05:00 PM', submitted: 98, total: 100 },
            { id: 'b3', code: 'CS201', course: 'Database Systems', date: '2024-03-17', time: '09:00 AM - 12:00 PM', submitted: 87, total: 90 }
        ];
    }

    get evaluatorRows() {
        return [
            { id: 'ev1', code: 'CS101', course: 'Intro to Computer Science', evaluator: 'Dr. John Smith', role: 'Chief Examiner', contact: 'jsmith@university.edu', scripts: 145, bundles: 3, moderator: 'Dr. Emily Chen' },
            { id: 'ev2', code: 'MATH201', course: 'Calculus II', evaluator: 'Dr. Alice Johnson', role: 'Chief Examiner', contact: 'ajohnson@university.edu', scripts: 98, bundles: 2, moderator: 'Prof. Michael Brown' },
            { id: 'ev3', code: 'PHY101', course: 'Physics I', evaluator: 'Dr. Sarah Johnson', role: 'Chief Examiner', contact: 'sjohnson@university.edu', scripts: 120, bundles: 4, moderator: 'Dr. Lisa Anderson' }
        ];
    }

    get isMasterCourseTab() { return this.activeTab === 'masterCourse'; }
    get isExamPlanningTab() { return this.activeTab === 'examPlanning'; }
    get isResultsTab() { return this.activeTab === 'results'; }
    get isMarksCardTab() { return this.activeTab === 'marksCard'; }
    get isTranscriptsTab() { return this.activeTab === 'transcripts'; }
    get isPlanningListView() { return this.planningView === 'list'; }

    get isPlanExamsTab() { return this.activePlanningTab === 'exams'; }
    get isPlanEnrollmentTab() { return this.activePlanningTab === 'enrollment'; }
    get isPlanScheduleTab() { return this.activePlanningTab === 'schedule'; }
    get isPlanSeatingTab() { return this.activePlanningTab === 'seating'; }
    get isPlanQuestionPaperTab() { return this.activePlanningTab === 'questionPaper'; }
    get isPlanInvigilatorTab() { return this.activePlanningTab === 'invigilator'; }
    get isPlanBundlingTab() { return this.activePlanningTab === 'bundling'; }
    get isPlanEvaluatorTab() { return this.activePlanningTab === 'evaluator'; }

    get isStartEnrollmentDisabled() {
        return this.selectedProgramIds.length === 0;
    }

    get feeCriteriaOptions() {
        return this.feeCriteriaOptionsData;
    }

    get feeTypeOptions() {
        return this.feeTypeOptionsData;
    }

    get showSingleFeeSection() {
        return !!this.enrollmentDraft.sameFeeCriteria;
    }

    get showSplitFeeSections() {
        return !this.enrollmentDraft.sameFeeCriteria;
    }

    get showSingleFeeDetails() {
        return this._requiresFeeDetails(this.enrollmentDraft.feeCriteria);
    }

    get showRegularFeeDetails() {
        return this._requiresFeeDetails(this.enrollmentDraft.regularFeeCriteria);
    }

    get showBacklogFeeDetails() {
        return this._requiresFeeDetails(this.enrollmentDraft.backlogFeeCriteria);
    }

    get singleFeeRows() {
        return this._renderFeeRows(this.enrollmentDraft.feeItems, 'feeItems');
    }

    get regularFeeRows() {
        return this._renderFeeRows(this.enrollmentDraft.regularFeeItems, 'regularFeeItems');
    }

    get backlogFeeRows() {
        return this._renderFeeRows(this.enrollmentDraft.backlogFeeItems, 'backlogFeeItems');
    }

    _renderFeeRows(rows, listName) {
        const items = rows || [];
        const totalRows = items.length;
        return items.map((row, idx) => ({
            ...row,
            label: `Fee #${idx + 1}`,
            canRemove: totalRows > 1,
            options: this._availableFeeTypeOptions(items, row.feeTypeId),
            listName
        }));
    }

    _availableFeeTypeOptions(rows, currentValue) {
        const taken = new Set(
            (rows || [])
                .map((r) => r.feeTypeId)
                .filter((v) => v && v !== currentValue)
        );
        return (this.feeTypeOptionsData || []).filter((opt) => !taken.has(opt.value));
    }

    _requiresFeeDetails(value) {
        if (!value) return false;
        return value !== NO_FEE_CRITERIA;
    }

    _newFeeRow() {
        this._feeRowCounter += 1;
        return {
            rowKey: `feeRow_${this._feeRowCounter}`,
            feeTypeId: '',
            examFee: null
        };
    }

    _ensureRowsForCriteria(listName, criteriaValue) {
        if (!this._requiresFeeDetails(criteriaValue)) {
            return [];
        }
        const existing = this.enrollmentDraft[listName] || [];
        if (existing.length) return existing;
        return [this._newFeeRow()];
    }

    get backlogRadioOptions() {
        const disabled = !this.enrollmentDraft.allowBacklog;
        const mode = this.enrollmentDraft.backlogMode;
        return this.backlogOptionsData.map((opt) => ({
            label: opt.label,
            value: opt.value,
            checked: mode === opt.value,
            disabled
        }));
    }

    get regularRadioOptions() {
        const disabled = !this.enrollmentDraft.allowRegular;
        const mode = this.enrollmentDraft.regularMode;
        return this.regularOptionsData.map((opt) => ({
            label: opt.label,
            value: opt.value,
            checked: mode === opt.value,
            disabled
        }));
    }

    get selectedProgramLabel() {
        if (!this.selectedProgramIds.length) return '';
        const names = this.selectedProgramIds
            .map((id) => {
                const match = this.enrollmentRows.find((item) => item.id === id);
                return match ? match.program : '';
            })
            .filter(Boolean);
        return names.join(', ');
    }

    get selectedProgramYear() {
        return '2026';
    }

    get masterCourseTabClass() { return this._tabClass('masterCourse', this.activeTab); }
    get examPlanningTabClass() { return this._tabClass('examPlanning', this.activeTab); }
    get resultsTabClass() { return this._tabClass('results', this.activeTab); }
    get marksCardTabClass() { return this._tabClass('marksCard', this.activeTab); }
    get transcriptsTabClass() { return this._tabClass('transcripts', this.activeTab); }

    get planExamsTabClass() { return this._tabClass('exams', this.activePlanningTab); }
    get planEnrollmentTabClass() { return this._tabClass('enrollment', this.activePlanningTab); }
    get planScheduleTabClass() { return this._tabClass('schedule', this.activePlanningTab); }
    get planSeatingTabClass() { return this._tabClass('seating', this.activePlanningTab); }
    get planQuestionPaperTabClass() { return this._tabClass('questionPaper', this.activePlanningTab); }
    get planInvigilatorTabClass() { return this._tabClass('invigilator', this.activePlanningTab); }
    get planBundlingTabClass() { return this._tabClass('bundling', this.activePlanningTab); }
    get planEvaluatorTabClass() { return this._tabClass('evaluator', this.activePlanningTab); }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
        if (this.activeTab !== 'examPlanning') {
            this.planningView = 'list';
        }
    }

    handlePlanningSubTabClick(event) {
        this.activePlanningTab = event.currentTarget.dataset.subtab;
    }

    handlePlanCardClick(event) {
        this.selectedPlanId = event.currentTarget.dataset.id;
        this.planningView = 'detail';
        this.activePlanningTab = 'exams';
        this.selectedProgramIds = [];
    }

    handleBackToPlans() {
        this.planningView = 'list';
        this.activePlanningTab = 'exams';
        this.selectedProgramIds = [];
    }

    handleProgramSelect(event) {
        const programId = event.currentTarget.dataset.id;
        const checked = event.target.checked;
        if (checked) {
            this.selectedProgramIds = [...this.selectedProgramIds.filter((id) => id !== programId), programId];
        } else {
            this.selectedProgramIds = this.selectedProgramIds.filter((id) => id !== programId);
        }
    }

    handleStartEnrollment() {
        if (this.isStartEnrollmentDisabled) return;
        const defaultFee = this._defaultFeeCriteriaValue();
        const feeCriteria = this.enrollmentDraft.feeCriteria || defaultFee;
        const regularFeeCriteria = this.enrollmentDraft.regularFeeCriteria || defaultFee;
        const backlogFeeCriteria = this.enrollmentDraft.backlogFeeCriteria || defaultFee;
        this.enrollmentDraft = {
            ...this.enrollmentDraft,
            feeCriteria,
            regularFeeCriteria,
            backlogFeeCriteria,
            feeItems: this._ensureRowsForCriteria('feeItems', feeCriteria),
            regularFeeItems: this._ensureRowsForCriteria('regularFeeItems', regularFeeCriteria),
            backlogFeeItems: this._ensureRowsForCriteria('backlogFeeItems', backlogFeeCriteria)
        };
        this.enrollmentSaveError = '';
        this.showEnrollmentModal = true;
    }

    handleCloseEnrollmentModal() {
        this.showEnrollmentModal = false;
        this.enrollmentSaveError = '';
    }

    handleEnrollmentFieldChange(event) {
        const fieldName = event.target.dataset.field;
        const element = event.target;
        let nextValue;
        if (element.type === 'checkbox' || element.type === 'toggle') {
            nextValue = element.checked;
        } else if (element.type === 'number') {
            const raw = element.value;
            nextValue = raw === '' || raw === null || raw === undefined ? null : Number(raw);
        } else {
            nextValue = element.value;
        }

        const patch = { [fieldName]: nextValue };

        if (fieldName === 'sameFeeCriteria') {
            const defaultFee = this._defaultFeeCriteriaValue();
            if (nextValue) {
                const feeCriteria = this.enrollmentDraft.feeCriteria || defaultFee;
                patch.feeCriteria = feeCriteria;
                patch.feeItems = this._ensureRowsForCriteria('feeItems', feeCriteria);
            } else {
                const regularFeeCriteria = this.enrollmentDraft.regularFeeCriteria || defaultFee;
                const backlogFeeCriteria = this.enrollmentDraft.backlogFeeCriteria || defaultFee;
                patch.regularFeeCriteria = regularFeeCriteria;
                patch.backlogFeeCriteria = backlogFeeCriteria;
                patch.regularFeeItems = this._ensureRowsForCriteria('regularFeeItems', regularFeeCriteria);
                patch.backlogFeeItems = this._ensureRowsForCriteria('backlogFeeItems', backlogFeeCriteria);
            }
        }

        if (fieldName === 'feeCriteria') {
            patch.feeItems = this._requiresFeeDetails(nextValue)
                ? this._ensureRowsForCriteria('feeItems', nextValue)
                : [];
        }
        if (fieldName === 'regularFeeCriteria') {
            patch.regularFeeItems = this._requiresFeeDetails(nextValue)
                ? this._ensureRowsForCriteria('regularFeeItems', nextValue)
                : [];
        }
        if (fieldName === 'backlogFeeCriteria') {
            patch.backlogFeeItems = this._requiresFeeDetails(nextValue)
                ? this._ensureRowsForCriteria('backlogFeeItems', nextValue)
                : [];
        }

        this.enrollmentDraft = { ...this.enrollmentDraft, ...patch };
    }

    handleAddFeeRow(event) {
        const listName = event.currentTarget.dataset.list;
        if (!listName) return;
        const existing = this.enrollmentDraft[listName] || [];
        this.enrollmentDraft = {
            ...this.enrollmentDraft,
            [listName]: [...existing, this._newFeeRow()]
        };
    }

    handleRemoveFeeRow(event) {
        const listName = event.currentTarget.dataset.list;
        const rowKey = event.currentTarget.dataset.row;
        if (!listName || !rowKey) return;
        const existing = this.enrollmentDraft[listName] || [];
        if (existing.length <= 1) return;
        this.enrollmentDraft = {
            ...this.enrollmentDraft,
            [listName]: existing.filter((row) => row.rowKey !== rowKey)
        };
    }

    handleFeeRowFieldChange(event) {
        const listName = event.currentTarget.dataset.list;
        const rowKey = event.currentTarget.dataset.row;
        const field = event.currentTarget.dataset.rowfield;
        const element = event.target;
        let value;
        if (element.type === 'number') {
            const raw = element.value;
            value = raw === '' || raw === null || raw === undefined ? null : Number(raw);
        } else {
            value = element.value;
        }
        const existing = this.enrollmentDraft[listName] || [];
        this.enrollmentDraft = {
            ...this.enrollmentDraft,
            [listName]: existing.map((row) =>
                row.rowKey === rowKey ? { ...row, [field]: value } : row
            )
        };
    }

    async handleViewEligibility(event) {
        const programPlanId = event.currentTarget.dataset.id;
        if (!this.selectedPlanId || !programPlanId) return;

        this.showCriteriaViewModal = true;
        this.isLoadingCriteria = true;
        this.criteriaView = null;
        this.criteriaViewError = '';

        try {
            const result = await getEnrollmentCriteriaDetail({
                planId: this.selectedPlanId,
                programPlanId
            });
            if (!result) {
                this.criteriaViewError = 'No eligibility criteria has been configured for this program yet.';
            } else {
                this.criteriaView = result;
            }
        } catch (err) {
            this.criteriaViewError = (err && err.body && err.body.message)
                ? err.body.message
                : 'Failed to load eligibility criteria.';
        } finally {
            this.isLoadingCriteria = false;
        }
    }

    handleCloseCriteriaView() {
        this.showCriteriaViewModal = false;
        this.criteriaView = null;
        this.criteriaViewError = '';
    }

    get hasCriteriaView() {
        return this.criteriaView !== null && this.criteriaView !== undefined;
    }

    get hasAutoEnrollmentSettings() {
        return !!(this.criteriaView && (this.criteriaView.backlogMode || this.criteriaView.regularMode));
    }

    get criteriaViewSameFeeLabel() {
        if (!this.criteriaView) return '';
        return this.criteriaView.sameFeeCriteria ? 'Active' : 'Inactive';
    }

    get criteriaViewShowSingleFee() {
        return !!(this.criteriaView && this.criteriaView.sameFeeCriteria && this.criteriaView.feeCriteria);
    }

    get criteriaViewShowSingleFeeDetails() {
        return this.criteriaViewShowSingleFee
            && this._requiresFeeDetails(this.criteriaView.feeCriteria)
            && (this.criteriaView.feeItems || []).length > 0;
    }

    get criteriaViewShowSplitFees() {
        return !!(this.criteriaView && !this.criteriaView.sameFeeCriteria);
    }

    get criteriaViewShowRegularFeeDetails() {
        return this.criteriaViewShowSplitFees
            && this._requiresFeeDetails(this.criteriaView.regularFeeCriteria)
            && (this.criteriaView.regularFeeItems || []).length > 0;
    }

    get criteriaViewShowBacklogFeeDetails() {
        return this.criteriaViewShowSplitFees
            && this._requiresFeeDetails(this.criteriaView.backlogFeeCriteria)
            && (this.criteriaView.backlogFeeItems || []).length > 0;
    }

    get criteriaViewSingleFeeRows() {
        return this._renderViewFeeRows(this.criteriaView && this.criteriaView.feeItems);
    }

    get criteriaViewRegularFeeRows() {
        return this._renderViewFeeRows(this.criteriaView && this.criteriaView.regularFeeItems);
    }

    get criteriaViewBacklogFeeRows() {
        return this._renderViewFeeRows(this.criteriaView && this.criteriaView.backlogFeeItems);
    }

    _renderViewFeeRows(rows) {
        return (rows || []).map((row, idx) => ({
            ...row,
            label: `Fee #${idx + 1}`
        }));
    }

    async handleSaveEnrollment() {
        this.enrollmentSaveError = '';
        if (!this.selectedPlanId) {
            this.enrollmentSaveError = 'Exam Plan is missing.';
            return;
        }
        if (!this.selectedProgramIds.length) {
            this.enrollmentSaveError = 'Select at least one program.';
            return;
        }
        if (!this.enrollmentDraft.startOn || !this.enrollmentDraft.endsOn) {
            this.enrollmentSaveError = 'Start and End date-times are required.';
            return;
        }

        const d = this.enrollmentDraft;
        const sameFee = !!d.sameFeeCriteria;

        let cleanFeeItems = [];
        let cleanRegularItems = [];
        let cleanBacklogItems = [];

        if (sameFee) {
            if (!d.feeCriteria) {
                this.enrollmentSaveError = 'Fee Criteria is required.';
                return;
            }
            if (this._requiresFeeDetails(d.feeCriteria)) {
                const validation = this._validateFeeRows(d.feeItems, 'Fee Type');
                if (validation.error) { this.enrollmentSaveError = validation.error; return; }
                cleanFeeItems = validation.items;
            }
        } else {
            if (!d.regularFeeCriteria) { this.enrollmentSaveError = 'Regular Fee Criteria is required.'; return; }
            if (this._requiresFeeDetails(d.regularFeeCriteria)) {
                const validation = this._validateFeeRows(d.regularFeeItems, 'Regular Fee Type');
                if (validation.error) { this.enrollmentSaveError = validation.error; return; }
                cleanRegularItems = validation.items;
            }
            if (!d.backlogFeeCriteria) { this.enrollmentSaveError = 'Backlog Fee Criteria is required.'; return; }
            if (this._requiresFeeDetails(d.backlogFeeCriteria)) {
                const validation = this._validateFeeRows(d.backlogFeeItems, 'Backlog Fee Type');
                if (validation.error) { this.enrollmentSaveError = validation.error; return; }
                cleanBacklogItems = validation.items;
            }
        }

        this.isSavingEnrollment = true;
        try {
            await createEnrollmentCriteria({
                request: {
                    planId: this.selectedPlanId,
                    programPlanIds: [...this.selectedProgramIds],
                    startOn: d.startOn,
                    endsOn: d.endsOn,
                    lateFineOn: d.lateFineOn || null,
                    sameFeeCriteria: sameFee,
                    feeCriteria: sameFee ? (d.feeCriteria || null) : null,
                    feeItems: sameFee ? cleanFeeItems : [],
                    regularFeeCriteria: !sameFee ? (d.regularFeeCriteria || null) : null,
                    regularFeeItems: !sameFee ? cleanRegularItems : [],
                    backlogFeeCriteria: !sameFee ? (d.backlogFeeCriteria || null) : null,
                    backlogFeeItems: !sameFee ? cleanBacklogItems : [],
                    allowBacklog: !!d.allowBacklog,
                    backlogMode: d.backlogMode || null,
                    allowRegular: !!d.allowRegular,
                    regularMode: d.regularMode || null,
                    declaration: d.declaration || null
                }
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Enrollment started.',
                variant: 'success'
            }));
            this.showEnrollmentModal = false;
            this.selectedProgramIds = [];
            await refreshApex(this._wiredEnrollmentRef);
        } catch (err) {
            this.enrollmentSaveError = (err && err.body && err.body.message)
                ? err.body.message
                : 'Failed to start enrollment.';
        } finally {
            this.isSavingEnrollment = false;
        }
    }

    _validateFeeRows(rows, label) {
        const items = rows || [];
        if (!items.length) {
            return { error: `Add at least one ${label}.`, items: [] };
        }
        const seen = new Set();
        const cleaned = [];
        for (let i = 0; i < items.length; i++) {
            const row = items[i];
            if (!row.feeTypeId) {
                return { error: `${label} is required for Fee #${i + 1}.`, items: [] };
            }
            if (seen.has(row.feeTypeId)) {
                return { error: `${label} must be unique — duplicate at Fee #${i + 1}.`, items: [] };
            }
            if (row.examFee === null || row.examFee === undefined || row.examFee === '') {
                return { error: `Exam Fee is required for Fee #${i + 1}.`, items: [] };
            }
            seen.add(row.feeTypeId);
            cleaned.push({ feeTypeId: row.feeTypeId, examFee: this._toNumber(row.examFee) });
        }
        return { error: '', items: cleaned };
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    // ─── Schedule Tab Handlers ────────────────────────────────────────────────

    handleScheduleSelect(event) {
        const key = event.currentTarget.dataset.key;
        const checked = event.target.checked;
        this.selectedScheduleKeys = checked ? [key] : [];
    }

    handleOpenConfigureSchedule() {
        if (!this.hasScheduleSelection) return;
        const firstKey = this.selectedScheduleKeys[0];
        const row = (this.scheduleData || []).find((r) => r.key === firstKey);
        if (!row) return;

        this.scheduleModalRow = {
            key: row.key,
            code: row.courseNumber || '—',
            course: row.courseName || '—',
            students: row.enrolledStudents || 0,
            examIds: row.examIds || []
        };

        if (row.schedules && row.schedules.length) {
            this.scheduleSets = row.schedules.map((s) => this._buildSetDraft({
                count: s.count != null ? s.count : '',
                startDateTime: this._toLocalInputValue(s.startDateTime),
                endDateTime: this._toLocalInputValue(s.endDateTime)
            }));
        } else {
            this.scheduleSets = [this._buildSetDraft({})];
        }
        this.scheduleSaveError = '';
        this.showScheduleModal = true;
    }

    handleCloseScheduleModal() {
        if (this.isSavingSchedule) return;
        this.showScheduleModal = false;
        this.scheduleModalRow = null;
        this.scheduleSets = [];
        this.scheduleSaveError = '';
    }

    handleAddScheduleSet() {
        this.scheduleSets = [...this.scheduleSets, this._buildSetDraft({})];
    }

    handleRemoveScheduleSet(event) {
        const id = event.currentTarget.dataset.setid;
        if (this.scheduleSets.length <= 1) return;
        this.scheduleSets = this.scheduleSets.filter((s) => s.id !== id);
    }

    handleScheduleSetFieldChange(event) {
        const id = event.currentTarget.dataset.setid;
        const field = event.currentTarget.dataset.field;
        const element = event.target;
        let value;
        if (element.type === 'number') {
            const raw = element.value;
            value = raw === '' || raw === null || raw === undefined ? '' : Number(raw);
        } else {
            value = element.value;
        }
        this.scheduleSets = this.scheduleSets.map((s) => (s.id === id ? { ...s, [field]: value } : s));
    }

    async handleSaveSchedule() {
        this.scheduleSaveError = '';
        if (!this.scheduleModalRow) return;

        const enrolled = this.scheduleModalRow.students || 0;
        if (!this.scheduleSets || !this.scheduleSets.length) {
            this.scheduleSaveError = 'Add at least one schedule.';
            return;
        }

        for (let i = 0; i < this.scheduleSets.length; i++) {
            const s = this.scheduleSets[i];
            const label = `Schedule ${i + 1}`;
            if (s.count === '' || s.count == null || Number(s.count) <= 0) {
                this.scheduleSaveError = `${label}: enter a positive student count.`;
                return;
            }
            if (!s.startDateTime || !s.endDateTime) {
                this.scheduleSaveError = `${label}: start and end date-times are required.`;
                return;
            }
            if (new Date(s.startDateTime).getTime() >= new Date(s.endDateTime).getTime()) {
                this.scheduleSaveError = `${label}: end must be after start.`;
                return;
            }
        }

        if (this.scheduleSetsTotal !== enrolled) {
            this.scheduleSaveError = `Total students to be booked (${this.scheduleSetsTotal}) must equal enrolled students (${enrolled}).`;
            return;
        }

        this.isSavingSchedule = true;
        try {
            await saveScheduleConfiguration({
                request: {
                    examIds: this.scheduleModalRow.examIds,
                    sets: this.scheduleSets.map((s) => ({
                        count: Number(s.count),
                        startDateTime: this._normalizeLocalDatetime(s.startDateTime),
                        endDateTime: this._normalizeLocalDatetime(s.endDateTime)
                    }))
                }
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Schedule saved.',
                variant: 'success'
            }));
            this.showScheduleModal = false;
            this.scheduleModalRow = null;
            this.scheduleSets = [];
            this.selectedScheduleKeys = [];
            await refreshApex(this._wiredScheduleRef);
        } catch (err) {
            this.scheduleSaveError = (err && err.body && err.body.message)
                ? err.body.message
                : 'Failed to save schedule.';
        } finally {
            this.isSavingSchedule = false;
        }
    }

    _buildSetDraft({ count = '', startDateTime = '', endDateTime = '' }) {
        this._scheduleSetCounter += 1;
        return {
            id: `set_${this._scheduleSetCounter}`,
            count,
            startDateTime,
            endDateTime
        };
    }

    _formatDate(value) {
        if (!value) return '—';
        const d = new Date(value);
        if (Number.isNaN(d.getTime())) return '—';
        const yyyy = d.getFullYear();
        const mm = String(d.getMonth() + 1).padStart(2, '0');
        const dd = String(d.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    }

    _formatTime(value) {
        if (!value) return '—';
        const d = new Date(value);
        if (Number.isNaN(d.getTime())) return '—';
        let h = d.getHours();
        const m = String(d.getMinutes()).padStart(2, '0');
        const ampm = h >= 12 ? 'PM' : 'AM';
        h = h % 12 || 12;
        return `${String(h).padStart(2, '0')}:${m} ${ampm}`;
    }

    _formatDuration(hours) {
        if (hours == null || hours === '') return '—';
        const value = Number(hours);
        if (Number.isNaN(value)) return '—';
        if (Math.abs(value - Math.round(value)) < 0.01) return `${Math.round(value)} hrs`;
        return `${value.toFixed(2)} hrs`;
    }

    _toLocalInputValue(value) {
        if (!value) return '';
        const d = new Date(value);
        if (Number.isNaN(d.getTime())) return '';
        const pad = (n) => String(n).padStart(2, '0');
        const yyyy = d.getFullYear();
        const mm = pad(d.getMonth() + 1);
        const dd = pad(d.getDate());
        const hh = pad(d.getHours());
        const mi = pad(d.getMinutes());
        return `${yyyy}-${mm}-${dd}T${hh}:${mi}`;
    }

    _normalizeLocalDatetime(value) {
        if (!value) return '';
        // lightning-input type="datetime-local" sometimes returns an ISO UTC
        // string ending in "Z". Re-emit it as a naive browser-local string
        // so what the user sees in the input is exactly what reaches Apex.
        const d = new Date(value);
        if (Number.isNaN(d.getTime())) return value;
        const pad = (n) => String(n).padStart(2, '0');
        return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` +
            `T${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
    }

    // ── Create Exam Plan ───────────────────────────────────────────────────
    handleOpenCreatePlan() {
        this.newPlan = { name: '', assessment: '', startDate: '', endDate: '' };
        this.planSaveError = '';
        this.showCreatePlanModal = true;
    }

    handleCloseCreatePlan() {
        if (this.isSavingPlan) return;
        this.showCreatePlanModal = false;
        this.planSaveError = '';
    }

    handleNewPlanFieldChange(event) {
        const field = event.target.dataset.field;
        this.newPlan = { ...this.newPlan, [field]: event.target.value };
    }

    async handleCreatePlan() {
        const { name, assessment, startDate, endDate } = this.newPlan;
        this.planSaveError = '';

        if (!name || !name.trim()) {
            this.planSaveError = 'Plan Name is required.';
            return;
        }
        if (!startDate || !endDate) {
            this.planSaveError = 'Start Date and End Date are required.';
            return;
        }
        if (!this.cycleId) {
            this.planSaveError = 'Exam Cycle is missing. Reopen the cycle and try again.';
            return;
        }

        this.isSavingPlan = true;
        try {
            await createExamPlan({
                planName: name.trim(),
                cycleId: this.cycleId,
                assessment: assessment || null,
                startDate,
                endDate
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Exam plan created.',
                variant: 'success'
            }));
            this.showCreatePlanModal = false;
            await refreshApex(this._wiredPlansRef);
        } catch (err) {
            this.planSaveError = (err && err.body && err.body.message)
                ? err.body.message
                : 'Failed to create exam plan.';
        } finally {
            this.isSavingPlan = false;
        }
    }

    _tabClass(expected, current) {
        return expected === current ? 'tab tab--active' : 'tab';
    }

    _toNumber(value) {
        if (value === null || value === undefined || value === '') return null;
        const num = Number(value);
        return Number.isNaN(num) ? null : num;
    }

    _planStatusClass(value) {
        const normalized = (value || '').toLowerCase();
        if (normalized === 'completed') return 'plan-status plan-status--completed';
        if (normalized === 'draft') return 'plan-status plan-status--draft';
        return 'plan-status plan-status--active';
    }

    _statusView(value) {
        const label = value || 'Not Started';
        const normalized = label.toLowerCase();
        if (normalized === 'completed') {
            return {
                label,
                pillClass: 'status-pill status-pill--completed',
                iconClass: 'status-icon status-icon--completed',
                showIcon: true
            };
        }
        if (normalized === 'in progress') {
            return {
                label,
                pillClass: 'status-pill status-pill--progress',
                iconClass: 'status-icon status-icon--progress',
                showIcon: true
            };
        }
        return {
            label,
            pillClass: 'status-pill status-pill--not-started',
            iconClass: '',
            showIcon: false
        };
    }
}