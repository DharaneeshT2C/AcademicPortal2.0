public with sharing class KenExamCyclePlannerController {

    // ─── Exam Cycle List ───────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<ExamCycleWrapper> getExamCycles() {
        List<Ken_Exam_Cycle__c> cycles = [
            SELECT Id, Name, Ken_Academic_Term__r.Name, Ken_Is_Active__c, Ken_Academic_Term__c,Ken_Academic_Term__r.StartDate,Ken_Academic_Term__r.EndDate,Ken_Academic_Term__r.AcademicYearId,
Ken_Academic_Term__r.AcademicYear.Name
            FROM Ken_Exam_Cycle__c
            ORDER BY Name ASC
        ];

        Set<Id> termIds = new Set<Id>();
        for (Ken_Exam_Cycle__c cycle : cycles) {
            if (cycle.Ken_Academic_Term__c != null) {
                termIds.add(cycle.Ken_Academic_Term__c);
            }
        }

        Map<Id, List<CourseOffering>> offeringsByTerm = new Map<Id, List<CourseOffering>>();
        if (!termIds.isEmpty()) {
            for (CourseOffering co : [
                SELECT Id, LearningCourseId, LearningCourse.Name, Ken_Evaluation_Schema__c,
                       AcademicSession.AcademicTermId
                FROM CourseOffering
                WHERE AcademicSession.AcademicTermId IN :termIds
            ]) {
                Id termId = co.AcademicSession.AcademicTermId;
                if (!offeringsByTerm.containsKey(termId)) {
                    offeringsByTerm.put(termId, new List<CourseOffering>());
                }
                offeringsByTerm.get(termId).add(co);
            }
        }

        List<ExamCycleWrapper> result = new List<ExamCycleWrapper>();
        for (Ken_Exam_Cycle__c cycle : cycles) {
            ExamCycleWrapper wrapper = new ExamCycleWrapper();
            wrapper.id     = cycle.Id;
            wrapper.name   = cycle.Name;
            wrapper.term   = cycle.Ken_Academic_Term__r != null ? cycle.Ken_Academic_Term__r.Name : '';
            wrapper.termId = cycle.Ken_Academic_Term__c;
            wrapper.isActive = cycle.Ken_Is_Active__c;
            if (cycle.Ken_Academic_Term__r != null) {
                wrapper.academicYear = cycle.Ken_Academic_Term__r.AcademicYear != null
                    ? cycle.Ken_Academic_Term__r.AcademicYear.Name : '';
                wrapper.startDate = cycle.Ken_Academic_Term__r.StartDate != null
                    ? String.valueOf(cycle.Ken_Academic_Term__r.StartDate) : '';
                wrapper.endDate = cycle.Ken_Academic_Term__r.EndDate != null
                    ? String.valueOf(cycle.Ken_Academic_Term__r.EndDate) : '';
            }

            List<CourseOffering> termOfferings = offeringsByTerm.get(cycle.Ken_Academic_Term__c);
            if (termOfferings != null && !termOfferings.isEmpty()) {
                Set<Id>   uniqueCourseIds = new Set<Id>();
                Set<Id>   uniqueSchemaIds = new Set<Id>();
                for (CourseOffering co : termOfferings) {
                    if (co.LearningCourseId != null)       uniqueCourseIds.add(co.LearningCourseId);
                    if (co.Ken_Evaluation_Schema__c != null) uniqueSchemaIds.add(co.Ken_Evaluation_Schema__c);
                }
                wrapper.courses       = uniqueCourseIds.size();
                wrapper.mappedSchemas = uniqueSchemaIds.size();
            } else {
                wrapper.courses       = 0;
                wrapper.mappedSchemas = 0;
            }
            result.add(wrapper);
        }
        return result;
    }

    // ─── Academic Term Lookup (for Create Exam Cycle modal) ───────────────────

    @AuraEnabled(cacheable=true)
    public static List<AcademicTermOption> getAcademicTerms() {
        List<AcademicTermOption> options = new List<AcademicTermOption>();
        for (AcademicTerm t : [SELECT Id, Name FROM AcademicTerm ORDER BY Name ASC]) {
            AcademicTermOption opt = new AcademicTermOption();
            opt.id   = t.Id;
            opt.name = t.Name;
            options.add(opt);
        }
        return options;
    }

    // ─── Create Exam Cycle ────────────────────────────────────────────────────

    @AuraEnabled
    public static Id createExamCycle(String cycleName, Id academicTermId) {
        if (String.isBlank(cycleName)) {
            throw new AuraHandledException('Cycle Name is required.');
        }
        if (academicTermId == null) {
            throw new AuraHandledException('Academic Term is required.');
        }
        Ken_Exam_Cycle__c cycle = new Ken_Exam_Cycle__c(
            Name                   = cycleName,
            Ken_Academic_Term__c   = academicTermId
        );
        insert cycle;
        return cycle.Id;
    }

    // ─── Exam Plans (by cycle) ────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<ExamPlanWrapper> getExamPlans(Id cycleId) {
        List<ExamPlanWrapper> result = new List<ExamPlanWrapper>();
        if (cycleId == null) return result;

        for (Ken_Exam_Plan__c plan : [
            SELECT Id, Name, Ken_Assessment__c, Ken_Start_Date__c, Ken_End_Date__c
            FROM Ken_Exam_Plan__c
            WHERE Ken_Exam_Cycle__c = :cycleId
            ORDER BY Ken_Start_Date__c ASC NULLS LAST, Name ASC
        ]) {
            ExamPlanWrapper w = new ExamPlanWrapper();
            w.id         = plan.Id;
            w.name       = plan.Name;
            w.assessment = plan.Ken_Assessment__c;
            w.startDate  = plan.Ken_Start_Date__c != null ? String.valueOf(plan.Ken_Start_Date__c) : '';
            w.endDate    = plan.Ken_End_Date__c   != null ? String.valueOf(plan.Ken_End_Date__c)   : '';
            result.add(w);
        }
        return result;
    }

    // ─── Assessment Picklist (Ken_Exam_Plan__c.Ken_Assessment__c) ────────────

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getExamPlanAssessmentOptions() {
        List<PicklistOption> options = new List<PicklistOption>();
        Schema.DescribeFieldResult fieldDesc =
            Ken_Exam_Plan__c.Ken_Assessment__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldDesc.getPicklistValues()) {
            if (entry.isActive()) {
                PicklistOption opt = new PicklistOption();
                opt.value = entry.getValue();
                opt.label = entry.getLabel();
                options.add(opt);
            }
        }
        return options;
    }

    // ─── Create Exam Plan ─────────────────────────────────────────────────────

    @AuraEnabled
    public static Id createExamPlan(
        String planName,
        Id cycleId,
        String assessment,
        Date startDate,
        Date endDate
    ) {
        if (String.isBlank(planName)) {
            throw new AuraHandledException('Plan Name is required.');
        }
        if (cycleId == null) {
            throw new AuraHandledException('Exam Cycle is required.');
        }
        if (startDate == null || endDate == null) {
            throw new AuraHandledException('Start Date and End Date are required.');
        }
        if (startDate > endDate) {
            throw new AuraHandledException('End Date cannot be before Start Date.');
        }

        Ken_Exam_Plan__c plan = new Ken_Exam_Plan__c(
            Name              = planName,
            Ken_Exam_Cycle__c = cycleId,
            Ken_Assessment__c = assessment,
            Ken_Start_Date__c = startDate,
            Ken_End_Date__c   = endDate
        );
        insert plan;
        return plan.Id;
    }

    // ─── Examinations (by Exam Plan) — Exams subtab ──────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<ExaminationRowWrapper> getExaminationsByPlan(Id planId) {
        List<ExaminationRowWrapper> result = new List<ExaminationRowWrapper>();
        if (planId == null) return result;

        for (Examination exam : [
            SELECT Id,
                   Ken_Course_Number__c,
                   Ken_Course_Name__c,
                   Ken_Enrollment__c,
                   Ken_Question_Paper__c,
                   Ken_Schedule__c,
                   Ken_Seating_Plan__c,
                   Ken_Marks_Entry__c,
                   Ken_Invigilator__c
            FROM Examination
            WHERE Ken_Exam_Plan__c = :planId
            ORDER BY Ken_Course_Number__c ASC NULLS LAST, Ken_Course_Name__c ASC NULLS LAST
        ]) {
            ExaminationRowWrapper w = new ExaminationRowWrapper();
            w.id             = exam.Id;
            w.courseNumber   = exam.Ken_Course_Number__c;
            w.courseName     = exam.Ken_Course_Name__c;
            w.enrollment     = exam.Ken_Enrollment__c;
            w.questionPaper  = exam.Ken_Question_Paper__c;
            w.schedule       = exam.Ken_Schedule__c;
            w.seatingPlan    = exam.Ken_Seating_Plan__c;
            w.invigilator    = exam.Ken_Invigilator__c;
            w.marksEntry     = exam.Ken_Marks_Entry__c;
            result.add(w);
        }
        return result;
    }

    // ─── Enrollment Window (Programs by Exam Plan) ────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<EnrollmentProgramRowWrapper> getEnrollmentProgramsByPlan(Id planId) {
        List<EnrollmentProgramRowWrapper> result = new List<EnrollmentProgramRowWrapper>();
        if (planId == null) return result;

        List<Ken_Exam_Plan__c> planList = [
            SELECT Id, Ken_Assessment__c, Ken_Exam_Cycle__r.Ken_Academic_Term__c
            FROM Ken_Exam_Plan__c
            WHERE Id = :planId
            LIMIT 1
        ];
        if (planList.isEmpty()) return result;
        String planAssessment = planList[0].Ken_Assessment__c;

        List<Examination> exams;
        if (String.isNotBlank(planAssessment)) {
            exams = [
                SELECT Id,
                       Ken_Evaluation_Component__c,
                       Ken_Evaluation_Component__r.Ken_Parent_Evaluation_Component__c
                FROM Examination
                WHERE Ken_Exam_Plan__c = :planId
                AND Ken_Evaluation_Component__c != null
                AND Ken_Evaluation_Component__r.Ken_Assessment__c = :planAssessment
            ];
        } else {
            exams = [
                SELECT Id,
                       Ken_Evaluation_Component__c,
                       Ken_Evaluation_Component__r.Ken_Parent_Evaluation_Component__c
                FROM Examination
                WHERE Ken_Exam_Plan__c = :planId
                AND Ken_Evaluation_Component__c != null
            ];
        }
        if (exams.isEmpty()) return result;

        Set<Id> examIds = new Set<Id>();
        Set<Id> parentEvalIds = new Set<Id>();
        Map<Id, Id> examIdToParentEvalId = new Map<Id, Id>();

        for (Examination e : exams) {
            examIds.add(e.Id);
            Id parentId = (e.Ken_Evaluation_Component__r != null)
                ? e.Ken_Evaluation_Component__r.Ken_Parent_Evaluation_Component__c
                : null;
            if (parentId == null) parentId = e.Ken_Evaluation_Component__c;
            if (parentId == null) continue;
            parentEvalIds.add(parentId);
            examIdToParentEvalId.put(e.Id, parentId);
        }
        if (parentEvalIds.isEmpty()) return result;

        Map<Id, Integer> examIdToStudentCount = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT ExaminationId examId, COUNT(Id) cnt
            FROM PersonExamination
            WHERE ExaminationId IN :examIds
            GROUP BY ExaminationId
        ]) {
            examIdToStudentCount.put((Id) ar.get('examId'), (Integer) ar.get('cnt'));
        }

        Map<Id, Integer> parentEvalIdToStudents = new Map<Id, Integer>();
        for (Id examId : examIdToParentEvalId.keySet()) {
            Id parentId = examIdToParentEvalId.get(examId);
            Integer cnt = examIdToStudentCount.containsKey(examId) ? examIdToStudentCount.get(examId) : 0;
            parentEvalIdToStudents.put(parentId, (parentEvalIdToStudents.containsKey(parentId) ? parentEvalIdToStudents.get(parentId) : 0) + cnt);
        }

        Map<Id, Set<Id>> offeringIdToParentEvalIds = new Map<Id, Set<Id>>();
        Set<Id> offeringIds = new Set<Id>();

        for (Ken_Course_Evaluation_Schema_Mapper__c jx : [
            SELECT Ken_Evaluation_Component__c, Course_Offering__c
            FROM Ken_Course_Evaluation_Schema_Mapper__c
            WHERE Ken_Evaluation_Component__c IN :parentEvalIds
            AND Course_Offering__c != null
        ]) {
            Id parentId = jx.Ken_Evaluation_Component__c;
            Id offeringId = jx.Course_Offering__c;

            if (!offeringIdToParentEvalIds.containsKey(offeringId)) {
                offeringIdToParentEvalIds.put(offeringId, new Set<Id>());
            }
            offeringIdToParentEvalIds.get(offeringId).add(parentId);

            offeringIds.add(offeringId);
        }
        if (offeringIds.isEmpty()) return result;

        Map<Id, EnrollmentProgramRowWrapper> programPlanIdToRow = new Map<Id, EnrollmentProgramRowWrapper>();
        Map<Id, Set<Id>> programPlanIdToCountedParentEvalIds = new Map<Id, Set<Id>>();

        for (Program_Plan_Course_Junction__c jx : [
            SELECT Id,
                   Course_Offering__c,
                   Learning_Program_Plan__c,
                   Learning_Program_Plan__r.LearningProgram.Id,
                   Learning_Program_Plan__r.LearningProgram.Name,
                   Learning_Program_Plan__r.LearningProgram.CipCode,
                   Learning_Program_Plan__r.LearningProgram.ActiveFromDate,
                   Learning_Program_Plan__r.LearningProgram.ActiveToDate,
                   Learning_Program_Plan__r.LearningProgram.IsActive
            FROM Program_Plan_Course_Junction__c
            WHERE Course_Offering__c IN :offeringIds
            ORDER BY Learning_Program_Plan__r.LearningProgram.Name ASC NULLS LAST
        ]) {
            if (jx.Learning_Program_Plan__c == null
                || jx.Learning_Program_Plan__r == null
                || jx.Learning_Program_Plan__r.LearningProgram == null) continue;
            Id programPlanId = jx.Learning_Program_Plan__c;

            EnrollmentProgramRowWrapper row = programPlanIdToRow.get(programPlanId);
            if (row == null) {
                row = new EnrollmentProgramRowWrapper();
                row.id = programPlanId;
                row.programPlanId = programPlanId;
                row.code = jx.Learning_Program_Plan__r.LearningProgram.CipCode;
                row.program = jx.Learning_Program_Plan__r.LearningProgram.Name;
                row.startDate = jx.Learning_Program_Plan__r.LearningProgram.ActiveFromDate != null
                    ? String.valueOf(jx.Learning_Program_Plan__r.LearningProgram.ActiveFromDate)
                    : '';
                row.endDate = jx.Learning_Program_Plan__r.LearningProgram.ActiveToDate != null
                    ? String.valueOf(jx.Learning_Program_Plan__r.LearningProgram.ActiveToDate)
                    : '';
                row.status = jx.Learning_Program_Plan__r.LearningProgram.IsActive ? 'Active' : 'Inactive';
                row.students = 0;
                programPlanIdToRow.put(programPlanId, row);
                programPlanIdToCountedParentEvalIds.put(programPlanId, new Set<Id>());
            }

            Set<Id> parentIds = offeringIdToParentEvalIds.get(jx.Course_Offering__c);
            if (parentIds == null) continue;

            Set<Id> counted = programPlanIdToCountedParentEvalIds.get(programPlanId);
            for (Id parentId : parentIds) {
                if (counted.contains(parentId)) continue;
                counted.add(parentId);
                row.students += parentEvalIdToStudents.containsKey(parentId) ? parentEvalIdToStudents.get(parentId) : 0;
            }
        }

        result.addAll(programPlanIdToRow.values());
        result.sort();
        return result;
    }

    // ─── Enrollment Criteria Picklists ────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static EnrollmentCriteriaOptionsWrapper getEnrollmentCriteriaOptions() {
        EnrollmentCriteriaOptionsWrapper wrapper = new EnrollmentCriteriaOptionsWrapper();
        wrapper.feeCriteria = describePicklist('Ken_Enrollment_Cretirea__c', 'Ken_Fee_Criteria__c');
        wrapper.backlogOptions = describePicklist('Ken_Enrollment_Cretirea__c', 'Ken_Enrollment_for_Backlog_Courses__c');
        wrapper.regularOptions = describePicklist('Ken_Enrollment_Cretirea__c', 'Ken_Enrollment_for_Regular_Courses__c');
        return wrapper;
    }

    @AuraEnabled(cacheable=true)
    public static List<FeeTypeOptionWrapper> getExaminationFeeTypes() {
        List<FeeTypeOptionWrapper> options = new List<FeeTypeOptionWrapper>();
        for (Ken_Fee_Type__c ft : [
            SELECT Id, Fee_Type_Name__c, Fee_Head__r.Fee_Head_Name__c
            FROM Ken_Fee_Type__c
            WHERE Fee_Head__r.Fee_Head_Name__c = 'Examination'
            ORDER BY Fee_Type_Name__c ASC
        ]) {
            FeeTypeOptionWrapper o = new FeeTypeOptionWrapper();
            o.value = ft.Id;
            o.label = ft.Fee_Type_Name__c;
            options.add(o);
        }
        return options;
    }

    private static List<PicklistOption> describePicklist(String objectApiName, String fieldApiName) {
        List<PicklistOption> options = new List<PicklistOption>();
        Schema.SObjectType sType = Schema.getGlobalDescribe().get(objectApiName);
        if (sType == null) return options;
        Schema.DescribeSObjectResult sDesc = sType.getDescribe();
        Schema.SObjectField field = sDesc.fields.getMap().get(fieldApiName);
        if (field == null) return options;
        for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                PicklistOption opt = new PicklistOption();
                opt.value = entry.getValue();
                opt.label = entry.getLabel();
                options.add(opt);
            }
        }
        return options;
    }

    // ─── Create Enrollment Criteria (Start Enrollment) ────────────────────────

    private static final String NO_FEE_TOKEN = 'No Fee Any Students';
    // CourseOffering.Exam_Type__c is the source of truth for Regular vs. Backlog routing.
    private static final String EXAM_TYPE_REGULAR = 'Regular';
    private static final Set<String> EXAM_TYPES_BACKLOG = new Set<String>{ 'Backlog', 'Retest' };

    // Internal builder that holds everything needed both to insert the
    // criterion record and to decide which exams should map to it.
    private class CriterionPlan {
        Id programPlanId;
        Boolean sameFeeMode;
        // Single-fee mode (sameFeeMode = true)
        String singleFeeCriteria;
        Id singleFeeTypeId;
        String singleFeeTypeName;
        Decimal singleExamFee;
        // Split-fee mode (sameFeeMode = false)
        String regularFeeCriteria;
        Id regularFeeTypeId;
        String regularFeeTypeName;
        Decimal regularExamFee;
        String backlogFeeCriteria;
        Id backlogFeeTypeId;
        String backlogFeeTypeName;
        Decimal backlogExamFee;
        // Mapping scope:
        // - matchCourseType: filter exams by CourseOffering.Course_Type__c (case-insensitive). null → don't filter.
        // - matchExamType:   'REGULAR' / 'BACKLOG' / null (any).
        // - ownsAllRegular / ownsAllBacklog: anchor flags for No-Fee sections.
        //   At most one criterion per programPlan can carry each flag.
        String matchCourseType;
        String matchExamType;
        Boolean ownsAllRegular = false;
        Boolean ownsAllBacklog = false;
        Id insertedId;
    }

    @AuraEnabled
    public static List<Id> createEnrollmentCriteria(EnrollmentCriteriaRequest request) {
        if (request == null) {
            throw new AuraHandledException('Enrollment details are required.');
        }
        if (request.planId == null) {
            throw new AuraHandledException('Exam Plan is required.');
        }
        if (request.programPlanIds == null || request.programPlanIds.isEmpty()) {
            throw new AuraHandledException('Select at least one program.');
        }
        if (String.isBlank(request.startOn) || String.isBlank(request.endsOn)) {
            throw new AuraHandledException('Start and End date-times are required.');
        }

        List<Ken_Exam_Plan__c> planList = [
            SELECT Id, Ken_Assessment__c, Ken_Exam_Cycle__r.Ken_Academic_Term__c
            FROM Ken_Exam_Plan__c
            WHERE Id = :request.planId
            LIMIT 1
        ];
        if (planList.isEmpty()) {
            throw new AuraHandledException('Exam Plan not found.');
        }
        String planAssessment = planList[0].Ken_Assessment__c;
        Id termId = (planList[0].Ken_Exam_Cycle__r != null)
            ? planList[0].Ken_Exam_Cycle__r.Ken_Academic_Term__c
            : null;
        if (termId == null) {
            throw new AuraHandledException('Exam Cycle is missing an Academic Term.');
        }
        if (String.isBlank(planAssessment)) {
            throw new AuraHandledException('Exam Plan is missing an Assessment.');
        }

        Datetime startDt = parseDatetimeLocal(request.startOn);
        Datetime endDt = parseDatetimeLocal(request.endsOn);
        Datetime lateFineDt = String.isNotBlank(request.lateFineOn)
            ? parseDatetimeLocal(request.lateFineOn)
            : null;

        Boolean sameFeeCriteria = request.sameFeeCriteria == true;

        // Validate sections + collect fee type ids so we can resolve their names.
        List<FeeItemRequest> singleItems   = sameFeeCriteria
            ? sanitizeFeeItems(request.feeItems, request.feeCriteria, 'Fee Type')
            : new List<FeeItemRequest>();
        List<FeeItemRequest> regularItems  = !sameFeeCriteria
            ? sanitizeFeeItems(request.regularFeeItems, request.regularFeeCriteria, 'Regular Fee Type')
            : new List<FeeItemRequest>();
        List<FeeItemRequest> backlogItems  = !sameFeeCriteria
            ? sanitizeFeeItems(request.backlogFeeItems, request.backlogFeeCriteria, 'Backlog Fee Type')
            : new List<FeeItemRequest>();

        Set<Id> feeTypeIds = new Set<Id>();
        for (FeeItemRequest it : singleItems)  if (it.feeTypeId != null) feeTypeIds.add(it.feeTypeId);
        for (FeeItemRequest it : regularItems) if (it.feeTypeId != null) feeTypeIds.add(it.feeTypeId);
        for (FeeItemRequest it : backlogItems) if (it.feeTypeId != null) feeTypeIds.add(it.feeTypeId);

        Map<Id, String> feeTypeIdToName = new Map<Id, String>();
        if (!feeTypeIds.isEmpty()) {
            for (Ken_Fee_Type__c ft : [
                SELECT Id, Fee_Type_Name__c
                FROM Ken_Fee_Type__c
                WHERE Id IN :feeTypeIds
            ]) {
                feeTypeIdToName.put(ft.Id, ft.Fee_Type_Name__c);
            }
        }

        // Build per-program criterion plans and the records to insert.
        Map<Id, List<CriterionPlan>> programPlanIdToPlans = new Map<Id, List<CriterionPlan>>();
        List<Ken_Enrollment_Cretirea__c> toInsert = new List<Ken_Enrollment_Cretirea__c>();
        List<CriterionPlan> orderedPlans = new List<CriterionPlan>();

        for (Id programPlanId : request.programPlanIds) {
            List<CriterionPlan> plans = buildCriterionPlans(
                programPlanId,
                sameFeeCriteria,
                request,
                singleItems, regularItems, backlogItems,
                feeTypeIdToName
            );
            programPlanIdToPlans.put(programPlanId, plans);
            for (CriterionPlan p : plans) {
                Ken_Enrollment_Cretirea__c rec = new Ken_Enrollment_Cretirea__c();
                rec.Learning_Program_Plan__c = programPlanId;
                rec.Ken_Enrollment_Start_Date_Time__c = startDt;
                rec.Ken_Enrollment_End_Date_Time__c = endDt;
                rec.Ken_Late_Fine_Applying_Date_Time__c = lateFineDt;
                rec.Ken_Same_Fee_Regular_and_Backlog__c = sameFeeCriteria;
                rec.Ken_Fee_Criteria__c = p.singleFeeCriteria;
                rec.Ken_Fee_Type__c = p.singleFeeTypeId;
                rec.Exam_Fee__c = p.singleExamFee;
                rec.Ken_Regular_Fee_Criteria__c = p.regularFeeCriteria;
                rec.Ken_Regular_Fee_Type__c = p.regularFeeTypeId;
                rec.Regular_Exam_Fee__c = p.regularExamFee;
                rec.Ken_Backlog_Fee_Criteria__c = p.backlogFeeCriteria;
                rec.Ken_Backlog_Fee_Type__c = p.backlogFeeTypeId;
                rec.Backlog_Exam_Fee__c = p.backlogExamFee;
                rec.Ken_Enrollment_for_Backlog_Courses__c = request.allowBacklog ? request.backlogMode : null;
                rec.Ken_Enrollment_for_Regular_Courses__c = request.allowRegular ? request.regularMode : null;
                rec.Ken_Student_Declaration__c = request.declaration;
                toInsert.add(rec);
                orderedPlans.add(p);
            }
        }
        if (toInsert.isEmpty()) return new List<Id>();
        insert toInsert;
        for (Integer i = 0; i < toInsert.size(); i++) {
            orderedPlans[i].insertedId = toInsert[i].Id;
        }

        // Build the program → offering map and remember each offering's
        // Course_Type and Exam_Type — these are the only fields used to route
        // an exam to a criterion plan.
        Map<Id, Set<Id>> programPlanIdToOfferingIds = new Map<Id, Set<Id>>();
        Map<Id, String> offeringIdToCourseType = new Map<Id, String>();
        Map<Id, String> offeringIdToExamType = new Map<Id, String>();
        Set<Id> allOfferingIds = new Set<Id>();
        for (Program_Plan_Course_Junction__c jx : [
            SELECT Id, Course_Offering__c, Learning_Program_Plan__c,
                   Course_Offering__r.Course_Type__c, Course_Offering__r.Exam_Type__c
            FROM Program_Plan_Course_Junction__c
            WHERE Learning_Program_Plan__c IN :request.programPlanIds
            AND Course_Offering__r.AcademicSession.AcademicTermId = :termId
            AND Course_Offering__c != null
        ]) {
            if (!programPlanIdToOfferingIds.containsKey(jx.Learning_Program_Plan__c)) {
                programPlanIdToOfferingIds.put(jx.Learning_Program_Plan__c, new Set<Id>());
            }
            programPlanIdToOfferingIds.get(jx.Learning_Program_Plan__c).add(jx.Course_Offering__c);
            allOfferingIds.add(jx.Course_Offering__c);
            offeringIdToCourseType.put(jx.Course_Offering__c, (String) jx.Course_Offering__r.Course_Type__c);
            offeringIdToExamType.put(jx.Course_Offering__c, (String) jx.Course_Offering__r.Exam_Type__c);
        }
        Set<Id> insertedIds = collectInsertedIds(orderedPlans);
        if (allOfferingIds.isEmpty()) return new List<Id>(insertedIds);

        Map<Id, Set<Id>> offeringIdToParentEvalIds = new Map<Id, Set<Id>>();
        Set<Id> allParentEvalIds = new Set<Id>();
        for (Ken_Course_Evaluation_Schema_Mapper__c jx : [
            SELECT Id, Course_Offering__c, Ken_Evaluation_Component__c
            FROM Ken_Course_Evaluation_Schema_Mapper__c
            WHERE Course_Offering__c IN :allOfferingIds
            AND Ken_Evaluation_Component__c != null
        ]) {
            if (!offeringIdToParentEvalIds.containsKey(jx.Course_Offering__c)) {
                offeringIdToParentEvalIds.put(jx.Course_Offering__c, new Set<Id>());
            }
            offeringIdToParentEvalIds.get(jx.Course_Offering__c).add(jx.Ken_Evaluation_Component__c);
            allParentEvalIds.add(jx.Ken_Evaluation_Component__c);
        }
        if (allParentEvalIds.isEmpty()) return new List<Id>(insertedIds);

        Map<Id, Set<Id>> parentEvalIdToChildEvalIds = new Map<Id, Set<Id>>();
        Set<Id> allChildEvalIds = new Set<Id>();
        for (Ken_Evaluation_Component__c child : [
            SELECT Id, Ken_Parent_Evaluation_Component__c
            FROM Ken_Evaluation_Component__c
            WHERE RecordType.DeveloperName = 'Evaluation_Sub_Component'
            AND Ken_Assessment__c = :planAssessment
            AND Ken_Parent_Evaluation_Component__c IN :allParentEvalIds
        ]) {
            if (!parentEvalIdToChildEvalIds.containsKey(child.Ken_Parent_Evaluation_Component__c)) {
                parentEvalIdToChildEvalIds.put(child.Ken_Parent_Evaluation_Component__c, new Set<Id>());
            }
            parentEvalIdToChildEvalIds.get(child.Ken_Parent_Evaluation_Component__c).add(child.Id);
            allChildEvalIds.add(child.Id);
        }
        if (allChildEvalIds.isEmpty()) return new List<Id>(insertedIds);

        Map<Id, Set<Id>> childEvalIdToExamIds = new Map<Id, Set<Id>>();
        Set<Id> allExamIds = new Set<Id>();
        for (Examination exam : [
            SELECT Id, Ken_Evaluation_Component__c
            FROM Examination
            WHERE Ken_Evaluation_Component__c IN :allChildEvalIds
            AND Ken_Exam_Plan__c = :request.planId
            AND Ken_Evaluation_Component__r.Ken_Assessment__c = :planAssessment
        ]) {
            if (!childEvalIdToExamIds.containsKey(exam.Ken_Evaluation_Component__c)) {
                childEvalIdToExamIds.put(exam.Ken_Evaluation_Component__c, new Set<Id>());
            }
            childEvalIdToExamIds.get(exam.Ken_Evaluation_Component__c).add(exam.Id);
            allExamIds.add(exam.Id);
        }
        if (allExamIds.isEmpty()) return new List<Id>(insertedIds);

        // Route each exam by the (Course_Type, Exam_Type) of the offering it
        // came from and pick the most specific matching criterion.
        Map<Id, Id> examIdToCriteriaId = new Map<Id, Id>();
        for (Id programPlanId : request.programPlanIds) {
            List<CriterionPlan> plans = programPlanIdToPlans.get(programPlanId);
            if (plans == null || plans.isEmpty()) continue;
            Set<Id> offeringIds = programPlanIdToOfferingIds.get(programPlanId);
            if (offeringIds == null) continue;
            for (Id offeringId : offeringIds) {
                String courseType = offeringIdToCourseType.get(offeringId);
                String examType = normalizeExamType(offeringIdToExamType.get(offeringId));
                CriterionPlan match = pickCriterionForExam(plans, courseType, examType);
                if (match == null) continue;
                Set<Id> parentIds = offeringIdToParentEvalIds.get(offeringId);
                if (parentIds == null) continue;
                for (Id parentId : parentIds) {
                    Set<Id> childIds = parentEvalIdToChildEvalIds.get(parentId);
                    if (childIds == null) continue;
                    for (Id childId : childIds) {
                        Set<Id> examIds = childEvalIdToExamIds.get(childId);
                        if (examIds == null) continue;
                        for (Id examId : examIds) {
                            examIdToCriteriaId.put(examId, match.insertedId);
                        }
                    }
                }
            }
        }

        if (!examIdToCriteriaId.isEmpty()) {
            List<Examination> examUpdates = new List<Examination>();
            for (Id examId : examIdToCriteriaId.keySet()) {
                examUpdates.add(new Examination(
                    Id = examId,
                    Ken_Enrollment_Criteria__c = examIdToCriteriaId.get(examId)
                ));
            }
            update examUpdates;

            List<PersonExamination> peUpdates = new List<PersonExamination>();
            for (PersonExamination pe : [
                SELECT Id, ExaminationId
                FROM PersonExamination
                WHERE ExaminationId IN :examIdToCriteriaId.keySet()
            ]) {
                Id criteriaId = examIdToCriteriaId.get(pe.ExaminationId);
                if (criteriaId == null) continue;
                peUpdates.add(new PersonExamination(
                    Id = pe.Id,
                    Ken_Enrollment_Criteria__c = criteriaId
                ));
            }
            if (!peUpdates.isEmpty()) update peUpdates;
        }

        return new List<Id>(insertedIds);
    }

    // Strip blanks, validate that fee items are present when fee criteria
    // requires them, and reject duplicate fee types in the same section.
    private static List<FeeItemRequest> sanitizeFeeItems(
        List<FeeItemRequest> raw, String feeCriteria, String label
    ) {
        List<FeeItemRequest> cleaned = new List<FeeItemRequest>();
        if (raw == null || String.isBlank(feeCriteria) || feeCriteria == NO_FEE_TOKEN) {
            return cleaned;
        }
        Set<Id> seen = new Set<Id>();
        for (FeeItemRequest it : raw) {
            if (it == null || it.feeTypeId == null) continue;
            if (seen.contains(it.feeTypeId)) {
                throw new AuraHandledException(label + ' must be unique within the section.');
            }
            if (it.examFee == null) {
                throw new AuraHandledException('Exam Fee is required for every ' + label + '.');
            }
            seen.add(it.feeTypeId);
            cleaned.add(it);
        }
        if (cleaned.isEmpty()) {
            throw new AuraHandledException('Add at least one ' + label + ' for the selected fee criteria.');
        }
        return cleaned;
    }

    // Translate the request into one criterion plan per record we'll insert,
    // wiring each plan to the (course-type, exam-type) scope it should claim.
    private static List<CriterionPlan> buildCriterionPlans(
        Id programPlanId,
        Boolean sameFeeCriteria,
        EnrollmentCriteriaRequest request,
        List<FeeItemRequest> singleItems,
        List<FeeItemRequest> regularItems,
        List<FeeItemRequest> backlogItems,
        Map<Id, String> feeTypeIdToName
    ) {
        List<CriterionPlan> plans = new List<CriterionPlan>();

        if (sameFeeCriteria) {
            String fc = request.feeCriteria;
            if (String.isBlank(fc)) {
                throw new AuraHandledException('Fee Criteria is required.');
            }
            if (fc == NO_FEE_TOKEN) {
                CriterionPlan p = new CriterionPlan();
                p.programPlanId = programPlanId;
                p.sameFeeMode = true;
                p.singleFeeCriteria = fc;
                p.matchCourseType = null;
                p.matchExamType = null;
                p.ownsAllRegular = true;
                p.ownsAllBacklog = true;
                plans.add(p);
            } else {
                for (FeeItemRequest it : singleItems) {
                    String typeName = feeTypeIdToName.get(it.feeTypeId);
                    CriterionPlan p = new CriterionPlan();
                    p.programPlanId = programPlanId;
                    p.sameFeeMode = true;
                    p.singleFeeCriteria = fc;
                    p.singleFeeTypeId = it.feeTypeId;
                    p.singleFeeTypeName = typeName;
                    p.singleExamFee = it.examFee;
                    p.matchCourseType = typeName;
                    p.matchExamType = null;
                    plans.add(p);
                }
            }
            return plans;
        }

        // Split-fee mode.
        String regCrit = request.regularFeeCriteria;
        String backCrit = request.backlogFeeCriteria;
        if (String.isBlank(regCrit)) {
            throw new AuraHandledException('Regular Fee Criteria is required.');
        }
        if (String.isBlank(backCrit)) {
            throw new AuraHandledException('Backlog Fee Criteria is required.');
        }

        Boolean regNoFee = regCrit == NO_FEE_TOKEN;
        Boolean backNoFee = backCrit == NO_FEE_TOKEN;

        if (regNoFee && backNoFee) {
            // One record carries both no-fee sections.
            CriterionPlan p = new CriterionPlan();
            p.programPlanId = programPlanId;
            p.sameFeeMode = false;
            p.regularFeeCriteria = regCrit;
            p.backlogFeeCriteria = backCrit;
            p.ownsAllRegular = true;
            p.ownsAllBacklog = true;
            plans.add(p);
            return plans;
        }

        if (!regNoFee && backNoFee) {
            // N regular records; the first also owns all backlog exams.
            for (Integer i = 0; i < regularItems.size(); i++) {
                FeeItemRequest it = regularItems[i];
                String typeName = feeTypeIdToName.get(it.feeTypeId);
                CriterionPlan p = new CriterionPlan();
                p.programPlanId = programPlanId;
                p.sameFeeMode = false;
                p.regularFeeCriteria = regCrit;
                p.regularFeeTypeId = it.feeTypeId;
                p.regularFeeTypeName = typeName;
                p.regularExamFee = it.examFee;
                p.backlogFeeCriteria = backCrit; // shared no-fee text on every record
                p.matchCourseType = typeName;
                p.matchExamType = 'REGULAR';
                if (i == 0) p.ownsAllBacklog = true;
                plans.add(p);
            }
            return plans;
        }

        if (regNoFee && !backNoFee) {
            // N backlog records; the first also owns all regular exams.
            for (Integer i = 0; i < backlogItems.size(); i++) {
                FeeItemRequest it = backlogItems[i];
                String typeName = feeTypeIdToName.get(it.feeTypeId);
                CriterionPlan p = new CriterionPlan();
                p.programPlanId = programPlanId;
                p.sameFeeMode = false;
                p.regularFeeCriteria = regCrit; // shared no-fee text on every record
                p.backlogFeeCriteria = backCrit;
                p.backlogFeeTypeId = it.feeTypeId;
                p.backlogFeeTypeName = typeName;
                p.backlogExamFee = it.examFee;
                p.matchCourseType = typeName;
                p.matchExamType = 'BACKLOG';
                if (i == 0) p.ownsAllRegular = true;
                plans.add(p);
            }
            return plans;
        }

        // Both sides have fee items: N + M records, each with one section populated.
        for (FeeItemRequest it : regularItems) {
            String typeName = feeTypeIdToName.get(it.feeTypeId);
            CriterionPlan p = new CriterionPlan();
            p.programPlanId = programPlanId;
            p.sameFeeMode = false;
            p.regularFeeCriteria = regCrit;
            p.regularFeeTypeId = it.feeTypeId;
            p.regularFeeTypeName = typeName;
            p.regularExamFee = it.examFee;
            p.matchCourseType = typeName;
            p.matchExamType = 'REGULAR';
            plans.add(p);
        }
        for (FeeItemRequest it : backlogItems) {
            String typeName = feeTypeIdToName.get(it.feeTypeId);
            CriterionPlan p = new CriterionPlan();
            p.programPlanId = programPlanId;
            p.sameFeeMode = false;
            p.backlogFeeCriteria = backCrit;
            p.backlogFeeTypeId = it.feeTypeId;
            p.backlogFeeTypeName = typeName;
            p.backlogExamFee = it.examFee;
            p.matchCourseType = typeName;
            p.matchExamType = 'BACKLOG';
            plans.add(p);
        }
        return plans;
    }

    // Most-specific-wins: prefer (course-type + exam-type) → course-type only
    // → all-regular / all-backlog anchor → all-anchor.
    private static CriterionPlan pickCriterionForExam(
        List<CriterionPlan> plans, String courseType, String examType
    ) {
        CriterionPlan exactMatch = null;
        CriterionPlan courseTypeOnly = null;
        CriterionPlan typeAnchor = null;
        CriterionPlan globalAnchor = null;
        Boolean isRegular = examType == 'REGULAR';
        Boolean isBacklog = examType == 'BACKLOG';
        String normCourseType = normalizeCourseType(courseType);

        for (CriterionPlan p : plans) {
            String planCourseType = normalizeCourseType(p.matchCourseType);
            if (p.matchCourseType != null && planCourseType == normCourseType) {
                if (p.matchExamType != null) {
                    if (p.matchExamType == examType && exactMatch == null) {
                        exactMatch = p;
                    }
                } else if (courseTypeOnly == null) {
                    courseTypeOnly = p;
                }
            }
            // Anchors are identified by their ownership flags only — in Cases 3/4
            // the anchor is the first fee record (which also carries a course type).
            if (typeAnchor == null) {
                if (isRegular && p.ownsAllRegular) typeAnchor = p;
                else if (isBacklog && p.ownsAllBacklog) typeAnchor = p;
            }
            if (globalAnchor == null && p.ownsAllRegular && p.ownsAllBacklog) {
                globalAnchor = p;
            }
        }

        if (exactMatch != null) return exactMatch;
        if (courseTypeOnly != null) return courseTypeOnly;
        if (typeAnchor != null) return typeAnchor;
        return globalAnchor;
    }

    private static String normalizeCourseType(String value) {
        return value == null ? null : value.trim().toUpperCase();
    }

    private static String normalizeExamType(String value) {
        if (String.isBlank(value)) return 'REGULAR';
        if (EXAM_TYPES_BACKLOG.contains(value)) return 'BACKLOG';
        if (value == EXAM_TYPE_REGULAR) return 'REGULAR';
        return value.toUpperCase();
    }

    private static Set<Id> collectInsertedIds(List<CriterionPlan> plans) {
        Set<Id> ids = new Set<Id>();
        for (CriterionPlan p : plans) if (p.insertedId != null) ids.add(p.insertedId);
        return ids;
    }

    // ─── Enrollment Criteria (read-only view) ─────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static EnrollmentCriteriaDetailWrapper getEnrollmentCriteriaDetail(Id planId, Id programPlanId) {
        if (planId == null || programPlanId == null) return null;

        // Pull only criteria actually wired up to this plan's exams.
        Set<Id> criteriaIds = new Set<Id>();
        for (Examination exam : [
            SELECT Ken_Enrollment_Criteria__c
            FROM Examination
            WHERE Ken_Exam_Plan__c = :planId
            AND Ken_Enrollment_Criteria__c != null
        ]) {
            criteriaIds.add(exam.Ken_Enrollment_Criteria__c);
        }
        if (criteriaIds.isEmpty()) return null;

        List<Ken_Enrollment_Cretirea__c> matches = [
            SELECT Id,
                   Learning_Program_Plan__c,
                   Learning_Program_Plan__r.Name,
                   Ken_Enrollment_Start_Date_Time__c,
                   Ken_Enrollment_End_Date_Time__c,
                   Ken_Late_Fine_Applying_Date_Time__c,
                   Ken_Same_Fee_Regular_and_Backlog__c,
                   Ken_Fee_Criteria__c,
                   Ken_Fee_Type__c,
                   Ken_Fee_Type__r.Fee_Type_Name__c,
                   Exam_Fee__c,
                   Ken_Regular_Fee_Criteria__c,
                   Ken_Regular_Fee_Type__c,
                   Ken_Regular_Fee_Type__r.Fee_Type_Name__c,
                   Regular_Exam_Fee__c,
                   Ken_Backlog_Fee_Criteria__c,
                   Ken_Backlog_Fee_Type__c,
                   Ken_Backlog_Fee_Type__r.Fee_Type_Name__c,
                   Backlog_Exam_Fee__c,
                   Ken_Enrollment_for_Backlog_Courses__c,
                   Ken_Enrollment_for_Regular_Courses__c,
                   Ken_Student_Declaration__c,
                   CreatedDate
            FROM Ken_Enrollment_Cretirea__c
            WHERE Id IN :criteriaIds
            AND Learning_Program_Plan__c = :programPlanId
            ORDER BY CreatedDate ASC
        ];
        if (matches.isEmpty()) return null;

        // The most-recently-created batch shares a CreatedDate window. Take the
        // newest record's window (start/end/late-fine + shared header fields)
        // and aggregate every record from that window into the fee-row lists.
        Ken_Enrollment_Cretirea__c newest = matches[matches.size() - 1];

        EnrollmentCriteriaDetailWrapper w = new EnrollmentCriteriaDetailWrapper();
        w.programPlanId = newest.Learning_Program_Plan__c;
        w.programPlanName = (newest.Learning_Program_Plan__r != null) ? newest.Learning_Program_Plan__r.Name : '';
        w.startOn = formatDatetimeForView(newest.Ken_Enrollment_Start_Date_Time__c);
        w.endsOn = formatDatetimeForView(newest.Ken_Enrollment_End_Date_Time__c);
        w.lateFineOn = formatDatetimeForView(newest.Ken_Late_Fine_Applying_Date_Time__c);
        w.sameFeeCriteria = newest.Ken_Same_Fee_Regular_and_Backlog__c == true;
        w.feeCriteria = newest.Ken_Fee_Criteria__c;
        w.regularFeeCriteria = newest.Ken_Regular_Fee_Criteria__c;
        w.backlogFeeCriteria = newest.Ken_Backlog_Fee_Criteria__c;
        w.backlogMode = newest.Ken_Enrollment_for_Backlog_Courses__c;
        w.regularMode = newest.Ken_Enrollment_for_Regular_Courses__c;
        w.declaration = newest.Ken_Student_Declaration__c;
        w.feeItems = new List<FeeRowView>();
        w.regularFeeItems = new List<FeeRowView>();
        w.backlogFeeItems = new List<FeeRowView>();

        // Records from the latest batch share start/end/late-fine timestamps.
        Datetime latestStart = newest.Ken_Enrollment_Start_Date_Time__c;
        Datetime latestEnd = newest.Ken_Enrollment_End_Date_Time__c;

        for (Ken_Enrollment_Cretirea__c c : matches) {
            if (c.Ken_Enrollment_Start_Date_Time__c != latestStart
                || c.Ken_Enrollment_End_Date_Time__c != latestEnd) continue;

            if (c.Ken_Fee_Type__c != null) {
                FeeRowView row = new FeeRowView();
                row.criteriaId = c.Id;
                row.feeTypeId = c.Ken_Fee_Type__c;
                row.feeTypeName = (c.Ken_Fee_Type__r != null) ? c.Ken_Fee_Type__r.Fee_Type_Name__c : null;
                row.examFee = c.Exam_Fee__c;
                w.feeItems.add(row);
            }
            if (c.Ken_Regular_Fee_Type__c != null) {
                FeeRowView row = new FeeRowView();
                row.criteriaId = c.Id;
                row.feeTypeId = c.Ken_Regular_Fee_Type__c;
                row.feeTypeName = (c.Ken_Regular_Fee_Type__r != null) ? c.Ken_Regular_Fee_Type__r.Fee_Type_Name__c : null;
                row.examFee = c.Regular_Exam_Fee__c;
                w.regularFeeItems.add(row);
            }
            if (c.Ken_Backlog_Fee_Type__c != null) {
                FeeRowView row = new FeeRowView();
                row.criteriaId = c.Id;
                row.feeTypeId = c.Ken_Backlog_Fee_Type__c;
                row.feeTypeName = (c.Ken_Backlog_Fee_Type__r != null) ? c.Ken_Backlog_Fee_Type__r.Fee_Type_Name__c : null;
                row.examFee = c.Backlog_Exam_Fee__c;
                w.backlogFeeItems.add(row);
            }
        }
        return w;
    }

    private static String formatDatetimeForView(Datetime dt) {
        if (dt == null) return '';
        return dt.format('dd MMM yyyy, h:mm a');
    }

    private static Datetime parseDatetimeLocal(String raw) {
        if (String.isBlank(raw)) return null;
        String s = raw;
        // Strip a trailing UTC marker (lightning-input may emit "...Z")
        if (s.endsWith('Z') || s.endsWith('z')) {
            s = s.substring(0, s.length() - 1);
        }
        s = s.replace('T', ' ');
        // Drop fractional seconds, e.g. "...:30.123" → "...:30"
        Integer dotIdx = s.indexOf('.');
        if (dotIdx > 0) s = s.substring(0, dotIdx);
        if (s.length() == 16) s += ':00';
        // Build the Datetime in the user's local time zone, so the wall-clock
        // value entered in the LWC matches what is persisted in Salesforce.
        Integer year   = Integer.valueOf(s.substring(0, 4));
        Integer month  = Integer.valueOf(s.substring(5, 7));
        Integer day    = Integer.valueOf(s.substring(8, 10));
        Integer hour   = Integer.valueOf(s.substring(11, 13));
        Integer minute = Integer.valueOf(s.substring(14, 16));
        Integer second = s.length() >= 19 ? Integer.valueOf(s.substring(17, 19)) : 0;
        return Datetime.newInstance(year, month, day, hour, minute, second);
    }

    // ─── Schedule Tab ────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<ScheduleRowWrapper> getScheduleRows(Id planId) {
        List<ScheduleRowWrapper> result = new List<ScheduleRowWrapper>();
        if (planId == null) return result;

        List<Ken_Exam_Plan__c> planList = [
            SELECT Id, Ken_Assessment__c
            FROM Ken_Exam_Plan__c
            WHERE Id = :planId
            LIMIT 1
        ];
        if (planList.isEmpty()) return result;
        String planAssessment = planList[0].Ken_Assessment__c;

        List<Examination> exams;
        if (String.isNotBlank(planAssessment)) {
            exams = [
                SELECT Id, Ken_Course_Number__c, Ken_Course_Name__c, Ken_Schedule_Count__c
                FROM Examination
                WHERE Ken_Exam_Plan__c = :planId
                AND Ken_Evaluation_Component__r.Ken_Assessment__c = :planAssessment
                ORDER BY Ken_Course_Number__c ASC NULLS LAST, Ken_Course_Name__c ASC NULLS LAST
            ];
        } else {
            exams = [
                SELECT Id, Ken_Course_Number__c, Ken_Course_Name__c, Ken_Schedule_Count__c
                FROM Examination
                WHERE Ken_Exam_Plan__c = :planId
                ORDER BY Ken_Course_Number__c ASC NULLS LAST, Ken_Course_Name__c ASC NULLS LAST
            ];
        }
        if (exams.isEmpty()) return result;

        Set<Id> examIdSet = new Set<Id>();
        Map<String, ScheduleRowWrapper> rowsByKey = new Map<String, ScheduleRowWrapper>();
        List<String> orderedKeys = new List<String>();

        for (Examination e : exams) {
            examIdSet.add(e.Id);
            String key = String.isBlank(e.Ken_Course_Number__c)
                ? ('NO_CODE_' + e.Id)
                : e.Ken_Course_Number__c;
            ScheduleRowWrapper row = rowsByKey.get(key);
            if (row == null) {
                row = new ScheduleRowWrapper();
                row.key = key;
                row.courseNumber = e.Ken_Course_Number__c;
                row.courseName = e.Ken_Course_Name__c;
                row.examIds = new List<Id>();
                row.enrolledStudents = 0;
                row.scheduleCount = 0;
                row.schedules = new List<ScheduleSetWrapper>();
                rowsByKey.put(key, row);
                orderedKeys.add(key);
            }
            row.examIds.add(e.Id);
        }

        Map<Id, Integer> studentCountByExam = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT ExaminationId examId, COUNT(Id) cnt
            FROM PersonExamination
            WHERE ExaminationId IN :examIdSet
            GROUP BY ExaminationId
        ]) {
            studentCountByExam.put((Id) ar.get('examId'), (Integer) ar.get('cnt'));
        }

        Map<Id, List<Ken_Exam_Schedule__c>> schedulesByExam = new Map<Id, List<Ken_Exam_Schedule__c>>();
        for (Ken_Exam_Schedule__c s : [
            SELECT Id, Examination__c,
                   Ken_Number_of_Student_To_Be_booked__c,
                   Ken_Start_Date_Time__c, Ken_End_Date_Time__c,
                   Ken_Duration_in_Hr__c
            FROM Ken_Exam_Schedule__c
            WHERE Examination__c IN :examIdSet
            ORDER BY Ken_Start_Date_Time__c ASC NULLS LAST
        ]) {
            if (!schedulesByExam.containsKey(s.Examination__c)) {
                schedulesByExam.put(s.Examination__c, new List<Ken_Exam_Schedule__c>());
            }
            schedulesByExam.get(s.Examination__c).add(s);
        }

        for (String key : orderedKeys) {
            ScheduleRowWrapper row = rowsByKey.get(key);

            Integer total = 0;
            for (Id eid : row.examIds) {
                total += studentCountByExam.containsKey(eid) ? studentCountByExam.get(eid) : 0;
            }
            row.enrolledStudents = total;

            // Aggregate schedule sets across the group's examinations by start/end signature.
            // (When a group has multiple Examinations sharing the same Course Code, each set
            // produces one Ken_Exam_Schedule__c per Examination — we collapse them for display.)
            Map<String, ScheduleSetWrapper> setsBySig = new Map<String, ScheduleSetWrapper>();
            List<String> sigOrder = new List<String>();
            for (Id eid : row.examIds) {
                List<Ken_Exam_Schedule__c> recs = schedulesByExam.get(eid);
                if (recs == null) continue;
                for (Ken_Exam_Schedule__c rec : recs) {
                    String sig = String.valueOf(rec.Ken_Start_Date_Time__c) + '|' + String.valueOf(rec.Ken_End_Date_Time__c);
                    ScheduleSetWrapper sw = setsBySig.get(sig);
                    if (sw == null) {
                        sw = new ScheduleSetWrapper();
                        sw.startDateTime = rec.Ken_Start_Date_Time__c;
                        sw.endDateTime = rec.Ken_End_Date_Time__c;
                        sw.durationHours = rec.Ken_Duration_in_Hr__c;
                        sw.count = 0;
                        setsBySig.put(sig, sw);
                        sigOrder.add(sig);
                    }
                    sw.count += (rec.Ken_Number_of_Student_To_Be_booked__c != null
                        ? rec.Ken_Number_of_Student_To_Be_booked__c.intValue() : 0);
                }
            }
            for (String sig : sigOrder) row.schedules.add(setsBySig.get(sig));
            row.scheduleCount = row.schedules.size();
            row.hasSchedule = !row.schedules.isEmpty();
            result.add(row);
        }

        result.sort();
        return result;
    }

    @AuraEnabled
    public static void saveScheduleConfiguration(ScheduleSaveRequest request) {
        if (request == null) {
            throw new AuraHandledException('Schedule details are required.');
        }
        if (request.examIds == null || request.examIds.isEmpty()) {
            throw new AuraHandledException('Examination context is missing.');
        }
        if (request.sets == null || request.sets.isEmpty()) {
            throw new AuraHandledException('Add at least one schedule.');
        }

        Set<Id> examIdSet = new Set<Id>();
        for (Id eid : request.examIds) examIdSet.add(eid);

        // Parse and validate each schedule set
        List<ScheduleSetParsed> parsedSets = new List<ScheduleSetParsed>();
        Integer totalRequested = 0;
        for (Integer i = 0; i < request.sets.size(); i++) {
            ScheduleSetRequest s = request.sets[i];
            Integer label = i + 1;
            if (s.count == null || s.count <= 0) {
                throw new AuraHandledException('Schedule #' + label + ': enter a positive student count.');
            }
            if (String.isBlank(s.startDateTime) || String.isBlank(s.endDateTime)) {
                throw new AuraHandledException('Schedule #' + label + ': start and end date-times are required.');
            }
            Datetime sdt = parseDatetimeLocal(s.startDateTime);
            Datetime edt = parseDatetimeLocal(s.endDateTime);
            if (sdt == null || edt == null) {
                throw new AuraHandledException('Schedule #' + label + ': invalid date-time values.');
            }
            if (sdt >= edt) {
                throw new AuraHandledException('Schedule #' + label + ': end must be after start.');
            }
            ScheduleSetParsed p = new ScheduleSetParsed();
            p.index = i;
            p.count = s.count;
            p.startDt = sdt;
            p.endDt = edt;
            Decimal millis = (Decimal) (edt.getTime() - sdt.getTime());
            p.durationHours = (millis / (1000 * 60 * 60)).setScale(2);
            parsedSets.add(p);
            totalRequested += s.count;
        }

        // Internal overlap among submitted sets
        for (Integer i = 0; i < parsedSets.size(); i++) {
            for (Integer j = i + 1; j < parsedSets.size(); j++) {
                if (rangesOverlap(parsedSets[i].startDt, parsedSets[i].endDt,
                                  parsedSets[j].startDt, parsedSets[j].endDt)) {
                    throw new AuraHandledException(
                        'Schedule #' + (i + 1) + ' overlaps with Schedule #' + (j + 1) + '.'
                    );
                }
            }
        }

        // Pull all PersonExaminations for the group's examinations
        List<PersonExamination> peList = [
            SELECT Id, ContactId, ExaminationId, Exam_Schedule__c, EffectiveFrom, EffectiveTo
            FROM PersonExamination
            WHERE ExaminationId IN :examIdSet
            ORDER BY ExaminationId ASC NULLS LAST, Id ASC
        ];

        if (peList.size() != totalRequested) {
            throw new AuraHandledException(
                'Total students to be booked (' + totalRequested + ') must equal enrolled students (' + peList.size() + ').'
            );
        }

        // Distribute PEs to sets in order
        List<Integer> setIndexForPe = new List<Integer>();
        for (ScheduleSetParsed p : parsedSets) {
            for (Integer k = 0; k < p.count; k++) setIndexForPe.add(p.index);
        }

        // Overlap validation against contacts' OTHER PersonExaminations
        Set<Id> contactIds = new Set<Id>();
        Set<Id> peCurrentIds = new Set<Id>();
        for (PersonExamination pe : peList) {
            if (pe.ContactId != null) contactIds.add(pe.ContactId);
            peCurrentIds.add(pe.Id);
        }

        Map<Id, List<PersonExamination>> otherPeByContact = new Map<Id, List<PersonExamination>>();
        if (!contactIds.isEmpty()) {
            for (PersonExamination pe : [
                SELECT Id, ContactId, EffectiveFrom, EffectiveTo, ExaminationId,
                       Examination.Ken_Course_Name__c,
                       Examination.Ken_Evaluation_Component__r.Ken_Assessment__c
                FROM PersonExamination
                WHERE ContactId IN :contactIds
                AND Id NOT IN :peCurrentIds
                AND EffectiveFrom != null
                AND EffectiveTo != null
            ]) {
                if (!otherPeByContact.containsKey(pe.ContactId)) {
                    otherPeByContact.put(pe.ContactId, new List<PersonExamination>());
                }
                otherPeByContact.get(pe.ContactId).add(pe);
            }
        }

        for (Integer i = 0; i < peList.size(); i++) {
            PersonExamination pe = peList[i];
            ScheduleSetParsed assigned = parsedSets[setIndexForPe[i]];
            List<PersonExamination> others = otherPeByContact.get(pe.ContactId);
            if (others == null) continue;
            for (PersonExamination other : others) {
                if (rangesOverlap(assigned.startDt, assigned.endDt, other.EffectiveFrom, other.EffectiveTo)) {
                    String courseName = (other.Examination != null && other.Examination.Ken_Course_Name__c != null)
                        ? other.Examination.Ken_Course_Name__c : '';
                    String assessment = (other.Examination != null
                        && other.Examination.Ken_Evaluation_Component__r != null
                        && other.Examination.Ken_Evaluation_Component__r.Ken_Assessment__c != null)
                        ? other.Examination.Ken_Evaluation_Component__r.Ken_Assessment__c : '';
                    throw new AuraHandledException(
                        'A student in this group is already booked for another exam in this window — Course: ' +
                        (String.isBlank(courseName) ? '—' : courseName) +
                        ', Assessment: ' + (String.isBlank(assessment) ? '—' : assessment) +
                        '. Adjust the schedule windows or counts.'
                    );
                }
            }
        }

        // Replace existing schedules for this group (clean slate)
        List<Ken_Exam_Schedule__c> existing = [
            SELECT Id FROM Ken_Exam_Schedule__c WHERE Examination__c IN :examIdSet
        ];
        if (!existing.isEmpty()) {
            Set<Id> existingScheduleIds = new Set<Id>();
            for (Ken_Exam_Schedule__c s : existing) existingScheduleIds.add(s.Id);
            List<PersonExamination> peClear = [
                SELECT Id, Exam_Schedule__c FROM PersonExamination WHERE Exam_Schedule__c IN :existingScheduleIds
            ];
            if (!peClear.isEmpty()) {
                for (PersonExamination pe : peClear) {
                    pe.Exam_Schedule__c = null;
                }
                update peClear;
            }
            delete existing;
        }

        // Insert one Ken_Exam_Schedule__c per (set × Examination) so the lookup is consistent
        // with the PersonExaminations that reference it.
        Map<String, Ken_Exam_Schedule__c> scheduleByKey = new Map<String, Ken_Exam_Schedule__c>();
        List<Ken_Exam_Schedule__c> toInsert = new List<Ken_Exam_Schedule__c>();
        // Pre-compute counts per (set, exam) from the distribution
        Map<String, Integer> countByKey = new Map<String, Integer>();
        for (Integer i = 0; i < peList.size(); i++) {
            String key = String.valueOf(setIndexForPe[i]) + '|' + peList[i].ExaminationId;
            countByKey.put(key, (countByKey.containsKey(key) ? countByKey.get(key) : 0) + 1);
        }
        for (Integer si = 0; si < parsedSets.size(); si++) {
            ScheduleSetParsed p = parsedSets[si];
            for (Id eid : examIdSet) {
                String key = String.valueOf(si) + '|' + eid;
                Integer cnt = countByKey.containsKey(key) ? countByKey.get(key) : 0;
                if (cnt == 0) continue;
                Ken_Exam_Schedule__c rec = new Ken_Exam_Schedule__c();
                rec.Examination__c = eid;
                rec.Ken_Number_of_Student_To_Be_booked__c = cnt;
                rec.Ken_Start_Date_Time__c = p.startDt;
                rec.Ken_End_Date_Time__c = p.endDt;
                rec.Ken_Duration_in_Hr__c = p.durationHours;
                toInsert.add(rec);
                scheduleByKey.put(key, rec);
            }
        }
        if (!toInsert.isEmpty()) insert toInsert;

        // Update PersonExaminations with their assigned schedule + effective dates
        List<PersonExamination> peUpdates = new List<PersonExamination>();
        for (Integer i = 0; i < peList.size(); i++) {
            PersonExamination pe = peList[i];
            ScheduleSetParsed assigned = parsedSets[setIndexForPe[i]];
            String key = String.valueOf(assigned.index) + '|' + pe.ExaminationId;
            Ken_Exam_Schedule__c sched = scheduleByKey.get(key);
            if (sched == null) continue;
            peUpdates.add(new PersonExamination(
                Id = pe.Id,
                Exam_Schedule__c = sched.Id,
                EffectiveFrom = assigned.startDt,
                EffectiveTo = assigned.endDt
            ));
        }
        if (!peUpdates.isEmpty()) update peUpdates;

        // Update Ken_Schedule_Count__c on each Examination in the group
        List<Examination> examUpdates = new List<Examination>();
        Integer setsCount = parsedSets.size();
        for (Id eid : examIdSet) {
            examUpdates.add(new Examination(
                Id = eid,
                Ken_Schedule_Count__c = setsCount
            ));
        }
        if (!examUpdates.isEmpty()) update examUpdates;
    }

    private static Boolean rangesOverlap(Datetime aStart, Datetime aEnd, Datetime bStart, Datetime bEnd) {
        if (aStart == null || aEnd == null || bStart == null || bEnd == null) return false;
        return aStart < bEnd && bStart < aEnd;
    }

    // ─── Evaluation Schema Management ─────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<EvaluationSchemaCardWrapper> getEvaluationSchemaCards() {
        List<Ken_Evaluation_Schema__c> schemas = [
            SELECT Id, Name, ken_Description__c, Ken_Total_Mark__c, Ken_Passing_Marks__c
            FROM Ken_Evaluation_Schema__c
            ORDER BY Name ASC
        ];
        if (schemas.isEmpty()) return new List<EvaluationSchemaCardWrapper>();

        Set<Id> schemaIds = new Set<Id>();
        for (Ken_Evaluation_Schema__c schema : schemas) schemaIds.add(schema.Id);

        Map<Id, Integer> coursesAppliedBySchema = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Ken_Evaluation_Schema__c schemaId, COUNT_DISTINCT(LearningCourseId) cnt
            FROM CourseOffering
            WHERE Ken_Evaluation_Schema__c IN :schemaIds
            AND LearningCourseId != null
            GROUP BY Ken_Evaluation_Schema__c
        ]) {
            coursesAppliedBySchema.put((Id) ar.get('schemaId'), (Integer) ar.get('cnt'));
        }

        Map<Id, Integer> componentCountBySchema = new Map<Id, Integer>();
        Map<Id, Id> componentIdToSchemaId = new Map<Id, Id>();
        Set<Id> componentIds = new Set<Id>();
        for (Ken_Evaluation_Schema_Component__c component : [
            SELECT Id, Ken_Evaluation_Schema__c
            FROM Ken_Evaluation_Schema_Component__c
            WHERE Ken_Evaluation_Schema__c IN :schemaIds
            AND RecordType.DeveloperName = 'Ken_Evaluation_Schema_Component'
        ]) {
            componentIds.add(component.Id);
            componentIdToSchemaId.put(component.Id, component.Ken_Evaluation_Schema__c);
            Integer nextCount = componentCountBySchema.containsKey(component.Ken_Evaluation_Schema__c)
                ? componentCountBySchema.get(component.Ken_Evaluation_Schema__c) + 1
                : 1;
            componentCountBySchema.put(component.Ken_Evaluation_Schema__c, nextCount);
        }

        Map<Id, Integer> subComponentCountBySchema = new Map<Id, Integer>();
        if (!componentIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT Ken_Evaluation_Schema_Component__c parentId, COUNT(Id) cnt
                FROM Ken_Evaluation_Schema_Component__c
                WHERE Ken_Evaluation_Schema_Component__c IN :componentIds
                AND RecordType.DeveloperName = 'Ken_Evaluation_Schema_Sub_Component'
                GROUP BY Ken_Evaluation_Schema_Component__c
            ]) {
                Id parentId = (Id) ar.get('parentId');
                Id schemaId = componentIdToSchemaId.get(parentId);
                if (schemaId == null) continue;

                Integer prior = subComponentCountBySchema.containsKey(schemaId)
                    ? subComponentCountBySchema.get(schemaId)
                    : 0;
                subComponentCountBySchema.put(schemaId, prior + (Integer) ar.get('cnt'));
            }
        }

        List<EvaluationSchemaCardWrapper> result = new List<EvaluationSchemaCardWrapper>();
        for (Ken_Evaluation_Schema__c schema : schemas) {
            EvaluationSchemaCardWrapper w = new EvaluationSchemaCardWrapper();
            w.id = schema.Id;
            w.name = schema.Name;
            w.description = schema.ken_Description__c;
            w.totalMarks = schema.Ken_Total_Mark__c;
            w.passingMarks = schema.Ken_Passing_Marks__c;
            w.coursesApplied = coursesAppliedBySchema.containsKey(schema.Id) ? coursesAppliedBySchema.get(schema.Id) : 0;
            w.componentCount = componentCountBySchema.containsKey(schema.Id) ? componentCountBySchema.get(schema.Id) : 0;
            w.subComponentCount = subComponentCountBySchema.containsKey(schema.Id) ? subComponentCountBySchema.get(schema.Id) : 0;
            result.add(w);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static EvaluationSchemaDetailWrapper getEvaluationSchemaDetail(Id schemaId) {
        if (schemaId == null) return null;

        Ken_Evaluation_Schema__c schema = [
            SELECT Id, Name, ken_Description__c, Ken_Total_Mark__c, Ken_Passing_Marks__c,
                   Ken_Is_Required_for_Grading__c
            FROM Ken_Evaluation_Schema__c
            WHERE Id = :schemaId
            LIMIT 1
        ];

        Integer coursesApplied = 0;
        for (AggregateResult ar : [
            SELECT Ken_Evaluation_Schema__c schemaId, COUNT_DISTINCT(LearningCourseId) cnt
            FROM CourseOffering
            WHERE Ken_Evaluation_Schema__c = :schemaId
            AND LearningCourseId != null
            GROUP BY Ken_Evaluation_Schema__c
        ]) {
            coursesApplied = (Integer) ar.get('cnt');
        }

        List<Ken_Evaluation_Schema_Component__c> components = [
            SELECT Id, Name, Ken_Exam_Category__c, Ken_Exam_Type__c, Ken_Components__c,
                   Ken_Effective_Marks__c, Ken_Weightage__c,
                   Ken_Maximum_Marks__c, Ken_Minimum_Marks__c, Ken_Passing_Marks__c,
                   Ken_Enrollment__c, Ken_Consider_for_Pass_Fail__c
            FROM Ken_Evaluation_Schema_Component__c
            WHERE Ken_Evaluation_Schema__c = :schemaId
            AND RecordType.DeveloperName = 'Ken_Evaluation_Schema_Component'
            ORDER BY Name ASC
        ];

        Map<Id, EvaluationSchemaComponentWrapper> componentWrapperById = new Map<Id, EvaluationSchemaComponentWrapper>();
        List<EvaluationSchemaComponentWrapper> componentWrappersInOrder = new List<EvaluationSchemaComponentWrapper>();
        Set<Id> componentIds = new Set<Id>();
        for (Ken_Evaluation_Schema_Component__c component : components) {
            componentIds.add(component.Id);
            EvaluationSchemaComponentWrapper cw = new EvaluationSchemaComponentWrapper();
            cw.id = component.Id;
            cw.name = component.Name;
            cw.kenComponent = component.Ken_Components__c;
            cw.examCategory = component.Ken_Exam_Category__c;
            cw.examType = String.isBlank(component.Ken_Exam_Type__c) ? 'Regular' : component.Ken_Exam_Type__c;
            cw.effectiveMarks = component.Ken_Effective_Marks__c;
            cw.maxMarks = component.Ken_Maximum_Marks__c;
            cw.minMarks = component.Ken_Minimum_Marks__c;
            cw.passingMarks = component.Ken_Passing_Marks__c;
            cw.weightage = component.Ken_Weightage__c;
            cw.enrollmentType = component.Ken_Enrollment__c;
            cw.considerForPassFail = component.Ken_Consider_for_Pass_Fail__c;
            cw.type = inferComponentType(component.Name);
            cw.subComponents = new List<EvaluationSchemaSubComponentWrapper>();
            componentWrapperById.put(component.Id, cw);
            componentWrappersInOrder.add(cw);
        }

        Integer subComponentCount = 0;
        if (!componentIds.isEmpty()) {
            for (Ken_Evaluation_Schema_Component__c sub : [
                SELECT Id, Name, Ken_Evaluation_Schema_Component__c,
                       Ken_Exam_Category__c, Ken_Exam_Type__c, Ken_Assessment__c,
                       Ken_Effective_Marks__c, Ken_Maximum_Marks__c, Ken_Minimum_Marks__c,
                       Ken_Passing_Marks__c, Ken_Weightage__c, Ken_Enrollment__c,
                       Ken_Consider_for_Pass_Fail__c, Ken_Is_Exam_Required__c
                FROM Ken_Evaluation_Schema_Component__c
                WHERE Ken_Evaluation_Schema_Component__c IN :componentIds
                AND RecordType.DeveloperName = 'Ken_Evaluation_Schema_Sub_Component'
                ORDER BY Name ASC
            ]) {
                EvaluationSchemaComponentWrapper parent = componentWrapperById.get(sub.Ken_Evaluation_Schema_Component__c);
                if (parent == null) continue;

                EvaluationSchemaSubComponentWrapper sw = new EvaluationSchemaSubComponentWrapper();
                sw.id = sub.Id;
                sw.name = sub.Name;
                sw.kenAssessment = sub.Ken_Assessment__c;
                sw.examCategory = sub.Ken_Exam_Category__c;
                sw.examType = String.isBlank(sub.Ken_Exam_Type__c) ? 'Regular' : sub.Ken_Exam_Type__c;
                sw.effectiveMarks = sub.Ken_Effective_Marks__c;
                sw.maxMarks = sub.Ken_Maximum_Marks__c;
                sw.minMarks = sub.Ken_Minimum_Marks__c;
                sw.passingMarks = sub.Ken_Passing_Marks__c;
                sw.weightage = sub.Ken_Weightage__c;
                sw.enrollmentType = sub.Ken_Enrollment__c;
                sw.considerForPassFail = sub.Ken_Consider_for_Pass_Fail__c;
                sw.examRequired = sub.Ken_Is_Exam_Required__c != null ? sub.Ken_Is_Exam_Required__c : true;
                parent.subComponents.add(sw);
                subComponentCount += 1;
            }
        }

        EvaluationSchemaDetailWrapper result = new EvaluationSchemaDetailWrapper();
        result.id = schema.Id;
        result.name = schema.Name;
        result.description = schema.ken_Description__c;
        result.totalMarks = schema.Ken_Total_Mark__c;
        result.passingMarks = schema.Ken_Passing_Marks__c;
        result.isRequiredForGrading = schema.Ken_Is_Required_for_Grading__c != null
            ? schema.Ken_Is_Required_for_Grading__c : true;
        result.coursesApplied = coursesApplied;
        result.componentCount = componentWrappersInOrder.size();
        result.subComponentCount = subComponentCount;
        result.components = componentWrappersInOrder;
        return result;
    }

    @AuraEnabled
    public static Id saveEvaluationSchema(EvaluationSchemaUpsertRequest request) {
        if (request == null) throw new AuraHandledException('Missing schema payload.');
        if (String.isBlank(request.name)) throw new AuraHandledException('Schema name is required.');
        if (request.components == null || request.components.isEmpty()) {
            throw new AuraHandledException('At least one component is required.');
        }

        // ── Upsert Schema ─────────────────────────────────────────────────────
        // Total Marks is master data entered by the user; persist it as-is.
        Ken_Evaluation_Schema__c schema = new Ken_Evaluation_Schema__c();
        Id existingSchemaId = tryParseId(request.id);
        if (existingSchemaId != null) schema.Id = existingSchemaId;
        schema.Name                            = request.name;
        schema.ken_Description__c             = request.description;
        schema.Ken_Total_Mark__c              = request.totalMarks;
        schema.Ken_Passing_Marks__c           = request.passingMarks;
        schema.Ken_Is_Required_for_Grading__c = request.isRequiredForGrading != null
                                                    ? request.isRequiredForGrading : true;
        upsert schema;

        // ── Fetch Record Type Ids ──────────────────────────────────────────────
        Map<String, Id> rtIds = getEvaluationSchemaComponentRecordTypeIds();
        Id componentRtId    = rtIds.get('Ken_Evaluation_Schema_Component');
        Id subComponentRtId = rtIds.get('Ken_Evaluation_Schema_Sub_Component');
        if (componentRtId == null || subComponentRtId == null) {
            throw new AuraHandledException('Evaluation Schema Component record types are not configured.');
        }

        // ── Upsert Parent Components ───────────────────────────────────────────
        // Ken_Components__c stores the picklist value (e.g. Internal / External / Makeup …).
        // All other marks are user-entered and saved directly — no server-side cross-level
        // recalculation or validation (the LWC handles that before calling save).
        List<EvaluationSchemaComponentUpsertRequest> componentRequests =
            new List<EvaluationSchemaComponentUpsertRequest>();
        List<Ken_Evaluation_Schema_Component__c> componentRecords =
            new List<Ken_Evaluation_Schema_Component__c>();

        for (EvaluationSchemaComponentUpsertRequest compReq : request.components) {
            if (compReq == null) continue;
            componentRequests.add(compReq);

            Ken_Evaluation_Schema_Component__c comp = new Ken_Evaluation_Schema_Component__c();
            Id existingCompId = tryParseId(compReq.id);
            if (existingCompId != null) comp.Id = existingCompId;
            comp.RecordTypeId                    = componentRtId;
            comp.Ken_Evaluation_Schema__c        = schema.Id;
            comp.Ken_Evaluation_Schema_Component__c = null; // parent component has no parent
            comp.Ken_Components__c               = compReq.kenComponent;
            comp.Ken_Exam_Type__c                = String.isBlank(compReq.examType) ? 'Regular' : compReq.examType;
            comp.Ken_Effective_Marks__c          = compReq.effectiveMarks;
            comp.Ken_Maximum_Marks__c            = compReq.maxMarks;
            comp.Ken_Minimum_Marks__c            = compReq.minMarks;
            comp.Ken_Passing_Marks__c            = compReq.passingMarks;
            comp.Ken_Weightage__c                = compReq.weightage;
            comp.Ken_Enrollment__c               = compReq.enrollmentType;
            comp.Ken_Consider_for_Pass_Fail__c   = compReq.considerForPassFail;
            componentRecords.add(comp);
        }
        if (!componentRecords.isEmpty()) upsert componentRecords;

        // ── Delete removed parent components (edit mode only) ──────────────────
        // Any component that existed for this schema but is absent from the
        // incoming request has been removed by the user and must be deleted.
        if (existingSchemaId != null) {
            // Build the incoming set from the upserted SObject list (componentRecords)
            // rather than from componentRequests. New components added during edit have
            // synthetic client-side IDs that tryParseId cannot resolve, but after upsert
            // componentRecords carry real Salesforce Ids. Using componentRecords ensures
            // newly inserted components are not mistakenly treated as "removed".
            Set<Id> incomingCompIds = new Set<Id>();
            for (Ken_Evaluation_Schema_Component__c compRec : componentRecords) {
                if (compRec.Id != null) incomingCompIds.add(compRec.Id);
            }
            List<Id> removedCompIds = new List<Id>();
            for (Ken_Evaluation_Schema_Component__c ec : [
                SELECT Id FROM Ken_Evaluation_Schema_Component__c
                WHERE Ken_Evaluation_Schema__c = :schema.Id
                AND RecordType.DeveloperName = 'Ken_Evaluation_Schema_Component'
            ]) {
                if (!incomingCompIds.contains(ec.Id)) removedCompIds.add(ec.Id);
            }
            if (!removedCompIds.isEmpty()) {
                List<Ken_Evaluation_Schema_Component__c> orphanSubs = [
                    SELECT Id FROM Ken_Evaluation_Schema_Component__c
                    WHERE Ken_Evaluation_Schema_Component__c IN :removedCompIds
                    AND RecordType.DeveloperName = 'Ken_Evaluation_Schema_Sub_Component'
                ];
                if (!orphanSubs.isEmpty()) delete orphanSubs;
                delete [SELECT Id FROM Ken_Evaluation_Schema_Component__c WHERE Id IN :removedCompIds];
            }
        }

        // ── Delete removed sub-components for remaining parents ────────────────
        // For each parent component still in the request, delete any sub-component
        // that exists in the database but was removed from the UI.
        Map<Id, Set<Id>> parentToIncomingSubIds = new Map<Id, Set<Id>>();
        for (Integer i = 0; i < componentRequests.size(); i++) {
            Id parentId = componentRecords[i].Id;
            if (parentId == null) continue;
            Set<Id> incomingSubs = new Set<Id>();
            if (componentRequests[i].subComponents != null) {
                for (EvaluationSchemaSubComponentUpsertRequest subReq : componentRequests[i].subComponents) {
                    Id eid = tryParseId(subReq.id);
                    if (eid != null) incomingSubs.add(eid);
                }
            }
            parentToIncomingSubIds.put(parentId, incomingSubs);
        }
        if (!parentToIncomingSubIds.isEmpty()) {
            List<Ken_Evaluation_Schema_Component__c> subsToDelete = new List<Ken_Evaluation_Schema_Component__c>();
            for (Ken_Evaluation_Schema_Component__c existSub : [
                SELECT Id, Ken_Evaluation_Schema_Component__c
                FROM Ken_Evaluation_Schema_Component__c
                WHERE Ken_Evaluation_Schema_Component__c IN :parentToIncomingSubIds.keySet()
                AND RecordType.DeveloperName = 'Ken_Evaluation_Schema_Sub_Component'
            ]) {
                Set<Id> incoming = parentToIncomingSubIds.get(existSub.Ken_Evaluation_Schema_Component__c);
                if (incoming != null && !incoming.contains(existSub.Id)) {
                    subsToDelete.add(existSub);
                }
            }
            if (!subsToDelete.isEmpty()) delete subsToDelete;
        }

        // ── Upsert Sub-Components ─────────────────────────────────────────────
        // Sub-components are children of a component via Ken_Evaluation_Schema_Component__c.
        // They must NOT populate Ken_Evaluation_Schema__c (that lookup is only for parent records).
        // Ken_Assessment__c stores the sub-component assessment picklist value.
        List<Ken_Evaluation_Schema_Component__c> subComponentRecords =
            new List<Ken_Evaluation_Schema_Component__c>();

        for (Integer i = 0; i < componentRequests.size(); i++) {
            EvaluationSchemaComponentUpsertRequest compReq = componentRequests[i];
            Id parentComponentId = componentRecords[i].Id;
            if (parentComponentId == null || compReq.subComponents == null) continue;

            for (EvaluationSchemaSubComponentUpsertRequest subReq : compReq.subComponents) {
                if (subReq == null) continue;

                Ken_Evaluation_Schema_Component__c sub = new Ken_Evaluation_Schema_Component__c();
                Id existingSubId = tryParseId(subReq.id);
                if (existingSubId != null) sub.Id = existingSubId;
                sub.RecordTypeId                       = subComponentRtId;
                sub.Ken_Evaluation_Schema__c           = null; // sub-components must NOT link to schema directly
                sub.Ken_Evaluation_Schema_Component__c = parentComponentId;
                sub.Ken_Assessment__c                  = subReq.kenAssessment;
                sub.Ken_Exam_Type__c                   = String.isBlank(subReq.examType) ? 'Regular' : subReq.examType;
                sub.Ken_Effective_Marks__c             = subReq.effectiveMarks;
                sub.Ken_Maximum_Marks__c               = subReq.maxMarks;
                sub.Ken_Minimum_Marks__c               = subReq.minMarks;
                sub.Ken_Passing_Marks__c               = subReq.passingMarks;
                sub.Ken_Weightage__c                   = subReq.weightage;
                sub.Ken_Enrollment__c                  = subReq.enrollmentType;
                sub.Ken_Consider_for_Pass_Fail__c      = subReq.considerForPassFail;
                sub.Ken_Is_Exam_Required__c            = subReq.examRequired != null ? subReq.examRequired : true;
                subComponentRecords.add(sub);
            }
        }
        if (!subComponentRecords.isEmpty()) upsert subComponentRecords;

        return schema.Id;
    }

    // ─── Exam Category Picklist Values ────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getExamCategoryPicklistValues() {
        List<PicklistOption> options = new List<PicklistOption>();
        Schema.DescribeFieldResult fieldDesc =
            Ken_Evaluation_Schema_Component__c.Ken_Exam_Category__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldDesc.getPicklistValues()) {
            if (entry.isActive()) {
                PicklistOption opt = new PicklistOption();
                opt.value = entry.getValue();
                opt.label = entry.getLabel();
                options.add(opt);
            }
        }
        return options;
    }

    // ─── Assessment Picklist Values (Ken_Assessment__c — sub-component RT) ───

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getAssessmentPicklistValues() {
        List<PicklistOption> options = new List<PicklistOption>();
        Schema.DescribeFieldResult fieldDesc =
            Ken_Evaluation_Schema_Component__c.Ken_Assessment__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldDesc.getPicklistValues()) {
            if (entry.isActive()) {
                PicklistOption opt = new PicklistOption();
                opt.value = entry.getValue();
                opt.label = entry.getLabel();
                options.add(opt);
            }
        }
        return options;
    }

    // ─── Course Mapping Screen ─────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static List<CourseMappingWrapper> getCoursesForMapping(Id termId) {
        if (termId == null) return new List<CourseMappingWrapper>();

        Set<Id> courseIds = new Set<Id>();
        for (CourseOffering co : [
            SELECT LearningCourseId FROM CourseOffering
            WHERE AcademicSession.AcademicTermId = :termId
        ]) {
            if (co.LearningCourseId != null) courseIds.add(co.LearningCourseId);
        }
        if (courseIds.isEmpty()) return new List<CourseMappingWrapper>();

        Map<Id, LearningCourse> lcMap = new Map<Id, LearningCourse>([
            SELECT Id, Name, CourseNumber, Credit_1__c, Provider.Name
            FROM LearningCourse
            WHERE Id IN :courseIds
        ]);

        Map<Id, Integer> studentCountMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT CourseOffering.LearningCourseId courseId, COUNT(Id) cnt
            FROM CourseOfferingParticipant
            WHERE CourseOffering.LearningCourseId IN :courseIds
            GROUP BY CourseOffering.LearningCourseId
        ]) {
            studentCountMap.put((Id)ar.get('courseId'), Integer.valueOf(ar.get('cnt')));
        }

        Map<Id, CourseOffering> schemaMap = new Map<Id, CourseOffering>();
        for (CourseOffering co : [
            SELECT LearningCourseId, Ken_Evaluation_Schema__c, Ken_Evaluation_Schema__r.Name,
                   Grade_Scheme__c, Grade_Scheme__r.Name
            FROM CourseOffering
            WHERE LearningCourseId IN :courseIds
            AND AcademicSession.AcademicTermId = :termId
            AND (Ken_Evaluation_Schema__c != null OR Grade_Scheme__c != null)
        ]) {
            if (!schemaMap.containsKey(co.LearningCourseId)) {
                schemaMap.put(co.LearningCourseId, co);
            }
        }

        List<CourseMappingWrapper> result = new List<CourseMappingWrapper>();
        for (Id courseId : courseIds) {
            LearningCourse lc = lcMap.get(courseId);
            if (lc == null) continue;

            CourseMappingWrapper w = new CourseMappingWrapper();
            w.id               = courseId;
            w.courseName       = lc.Name;
            w.courseCode       = lc.CourseNumber;
            w.credits          = lc.Credit_1__c != null ? lc.Credit_1__c.intValue() : 0;
            w.department       = lc.Provider != null ? lc.Provider.Name : '';
            w.enrolledStudents = studentCountMap.containsKey(courseId) ? studentCountMap.get(courseId) : 0;

            CourseOffering mapped = schemaMap.get(courseId);
            if (mapped != null) {
                w.evaluationSchemaId   = mapped.Ken_Evaluation_Schema__c;
                w.evaluationSchemaName = mapped.Ken_Evaluation_Schema__r != null
                                         ? mapped.Ken_Evaluation_Schema__r.Name : '';
                w.gradeSchemaId = mapped.Grade_Scheme__c;
                w.gradeSchemaName = mapped.Grade_Scheme__r != null
                                         ? mapped.Grade_Scheme__r.Name : '';
            } else {
                w.evaluationSchemaId   = null;
                w.evaluationSchemaName = null;
                w.gradeSchemaId = null;
                w.gradeSchemaName = null;
            }
            result.add(w);
        }
        result.sort();
        return result;
    }

    // ─── Evaluation Schema Picker ──────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<SchemaPickerWrapper> getEvaluationSchemas() {
        List<SchemaPickerWrapper> result = new List<SchemaPickerWrapper>();
        for (Ken_Evaluation_Schema__c schema : [
            SELECT Id, Name FROM Ken_Evaluation_Schema__c ORDER BY Name ASC
        ]) {
            SchemaPickerWrapper w = new SchemaPickerWrapper();
            w.id   = schema.Id;
            w.name = schema.Name;
            result.add(w);
        }
        return result;
    }

    // ─── DML: Map Schema ──────────────────────────────────────────────────────

    @AuraEnabled
    public static void mapSchema(List<Id> learningCourseIds, Id termId, Id schemaId) {
        if (learningCourseIds == null || learningCourseIds.isEmpty() || termId == null || schemaId == null) return;

        List<CourseOffering> offerings = [
            SELECT Id, LearningCourseId, Ken_Evaluation_Schema__c
            FROM CourseOffering
            WHERE LearningCourseId IN :learningCourseIds
            AND AcademicSession.AcademicTermId = :termId
        ];
        for (CourseOffering co : offerings) {
            co.Ken_Evaluation_Schema__c = schemaId;
        }
        update offerings;

        syncEvaluationComponents(schemaId, offerings);
    }

    // ─── DML: Unmap Schema ─────────────────────────────────────────────────────

    @AuraEnabled
    public static void unmapSchema(List<Id> learningCourseIds, Id termId) {
        if (learningCourseIds == null || learningCourseIds.isEmpty() || termId == null) return;

        List<CourseOffering> offerings = [
            SELECT Id, Ken_Evaluation_Schema__c
            FROM CourseOffering
            WHERE LearningCourseId IN :learningCourseIds
            AND AcademicSession.AcademicTermId = :termId
        ];
        for (CourseOffering co : offerings) {
            co.Ken_Evaluation_Schema__c = null;
        }
        update offerings;

        List<Id> courseOfferingIds = new List<Id>();
        for (CourseOffering co : offerings) courseOfferingIds.add(co.Id);
        deleteEvaluationComponentMappings(courseOfferingIds);
    }

    // ─── Course Offering Detail (Course-level drilldown) ──────────────────────

    @AuraEnabled(cacheable=true)
    public static CourseOfferingFilterOptionsWrapper getCourseOfferingFilterOptions(Id termId, Id learningCourseId) {
        CourseOfferingFilterOptionsWrapper result = new CourseOfferingFilterOptionsWrapper();
        result.academicSessions = new List<SessionOptionWrapper>();
        result.enrollmentTypes = new List<PicklistOption>();
        if (termId == null || learningCourseId == null) return result;

        Map<Id, String> sessionNamesById = new Map<Id, String>();
        for (CourseOffering co : [
            SELECT AcademicSessionId, AcademicSession.Name
            FROM CourseOffering
            WHERE AcademicSession.AcademicTermId = :termId
            AND LearningCourseId = :learningCourseId
            AND AcademicSessionId != null
        ]) {
            if (co.AcademicSessionId != null && !sessionNamesById.containsKey(co.AcademicSessionId)) {
                sessionNamesById.put(co.AcademicSessionId, co.AcademicSession != null ? co.AcademicSession.Name : '');
            }
        }
        for (Id sessionId : sessionNamesById.keySet()) {
            SessionOptionWrapper option = new SessionOptionWrapper();
            option.id = sessionId;
            option.name = sessionNamesById.get(sessionId);
            result.academicSessions.add(option);
        }
        result.academicSessions.sort();

        Schema.DescribeFieldResult offeringTypeDescribe = CourseOffering.OfferingType__c.getDescribe();
        for (Schema.PicklistEntry entry : offeringTypeDescribe.getPicklistValues()) {
            if (!entry.isActive()) continue;
            PicklistOption option = new PicklistOption();
            option.value = entry.getValue();
            option.label = entry.getLabel();
            result.enrollmentTypes.add(option);
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<CourseOfferingDetailWrapper> getCourseOfferingsByCourse(
        Id termId,
        Id learningCourseId,
        Id academicSessionId,
        String enrollmentType
    ) {
        if (termId == null || learningCourseId == null) return new List<CourseOfferingDetailWrapper>();

        String baseQuery =
            'SELECT Id, Name, LearningCourse.CourseNumber, LearningCourse.Name, ' +
            'EnrollmentCapacity, EnrolleeCount, Course_Type__c, OfferingType__c, ' +
            'AcademicSessionId, AcademicSession.Name ' +
            'FROM CourseOffering ' +
            'WHERE AcademicSession.AcademicTermId = :termId ' +
            'AND LearningCourseId = :learningCourseId';

        if (academicSessionId != null) {
            baseQuery += ' AND AcademicSessionId = :academicSessionId';
        }
        if (!String.isBlank(enrollmentType)) {
            baseQuery += ' AND OfferingType__c = :enrollmentType';
        }
        baseQuery += ' ORDER BY Name ASC';

        List<CourseOfferingDetailWrapper> result = new List<CourseOfferingDetailWrapper>();
        for (CourseOffering co : Database.query(baseQuery)) {
            CourseOfferingDetailWrapper row = new CourseOfferingDetailWrapper();
            row.id = co.Id;
            row.activeProgramOfferings = co.Name;
            row.courseNumber = co.LearningCourse != null ? co.LearningCourse.CourseNumber : '';
            row.courseName = co.LearningCourse != null ? co.LearningCourse.Name : '';
            row.enrollmentCapacity = co.EnrollmentCapacity;
            row.filledInCount = co.EnrolleeCount;
            row.courseType = (String) co.get('Course_Type__c');
            row.offeringType = (String) co.get('OfferingType__c');
            row.academicSessionId = co.AcademicSessionId;
            row.academicSessionName = co.AcademicSession != null ? co.AcademicSession.Name : '';
            result.add(row);
        }
        return result;
    }

    // ─── DML: Map Grade Schema (CourseOffering only) ──────────────────────────

    @AuraEnabled
    public static void mapGradeSchema(List<Id> learningCourseIds, Id termId, Id gradeSchemaId) {
        if (learningCourseIds == null || learningCourseIds.isEmpty() || termId == null || gradeSchemaId == null) return;

        List<CourseOffering> offerings = [
            SELECT Id, LearningCourseId, Grade_Scheme__c
            FROM CourseOffering
            WHERE LearningCourseId IN :learningCourseIds
            AND AcademicSession.AcademicTermId = :termId
        ];
        for (CourseOffering co : offerings) {
            co.Grade_Scheme__c = gradeSchemaId;
        }
        if (!offerings.isEmpty()) update offerings;
    }

    // ─── DML: Unmap Grade Schema (CourseOffering only) ────────────────────────

    @AuraEnabled
    public static void unmapGradeSchema(List<Id> learningCourseIds, Id termId) {
        if (learningCourseIds == null || learningCourseIds.isEmpty() || termId == null) return;

        List<CourseOffering> offerings = [
            SELECT Id, LearningCourseId, Grade_Scheme__c
            FROM CourseOffering
            WHERE LearningCourseId IN :learningCourseIds
            AND AcademicSession.AcademicTermId = :termId
        ];
        for (CourseOffering co : offerings) {
            co.Grade_Scheme__c = null;
        }
        if (!offerings.isEmpty()) update offerings;
    }

    // ─── Private helpers ───────────────────────────────────────────────────────

    private static String inferComponentType(String componentName) {
        String normalized = (componentName == null ? '' : componentName).toLowerCase();
        return normalized.contains('external') ? 'External' : 'Internal';
    }

    private static Id tryParseId(String value) {
        if (String.isBlank(value)) return null;
        try {
            return (Id) value;
        } catch (Exception e) {
            return null;
        }
    }

    private static Map<String, Id> getEvaluationSchemaComponentRecordTypeIds() {
        Map<String, Id> result = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Ken_Evaluation_Schema_Component__c'
            AND DeveloperName IN ('Ken_Evaluation_Schema_Component', 'Ken_Evaluation_Schema_Sub_Component')
        ]) {
            result.put(rt.DeveloperName, rt.Id);
        }
        return result;
    }

    private static Decimal nz(Decimal value) {
        return value == null ? 0 : value;
    }

    // ─── Private: Sync Evaluation Components + Junction Records ───────────────
    // Rule: ONE set of Ken_Evaluation_Component__c per LearningCourse.
    //   - Same course, multiple CourseOfferings → reuse the same component set,
    //     add a new junction record per offering.
    //   - Different course mapped to the same schema → separate component set
    //     + separate junction records.
    // All parent inserts and child inserts are batched (no DML inside loops).

    private static void syncEvaluationComponents(Id schemaId, List<CourseOffering> mappedOfferings) {
        if (schemaId == null || mappedOfferings == null || mappedOfferings.isEmpty()) return;

        Map<String, Id> rtIds = getEvaluationComponentRecordTypeIds();
        Id parentRtId = rtIds.get('Evaluation_Component');
        Id childRtId  = rtIds.get('Evaluation_Sub_Component');
        if (parentRtId == null || childRtId == null) return;

        // ── Step 1: Group newly mapped offerings by LearningCourseId ──────────
        Map<Id, List<Id>> courseToNewOfferingIds = new Map<Id, List<Id>>();
        for (CourseOffering co : mappedOfferings) {
            if (co.LearningCourseId == null) continue;
            if (!courseToNewOfferingIds.containsKey(co.LearningCourseId)) {
                courseToNewOfferingIds.put(co.LearningCourseId, new List<Id>());
            }
            courseToNewOfferingIds.get(co.LearningCourseId).add(co.Id);
        }
        if (courseToNewOfferingIds.isEmpty()) return;

        // ── Step 2: Find ALL CourseOfferings for these courses (any term) ─────
        //    to detect whether Ken_Evaluation_Component__c already exist per course.
        Map<Id, Id> allOfferingIdToCourseId = new Map<Id, Id>();
        for (CourseOffering co : [
            SELECT Id, LearningCourseId
            FROM CourseOffering
            WHERE LearningCourseId IN :courseToNewOfferingIds.keySet()
        ]) {
            allOfferingIdToCourseId.put(co.Id, co.LearningCourseId);
        }

        // ── Step 3: Find existing junction records for those offerings ─────────
        //    to determine which courses already have a component set.
        Map<Id, Set<Id>> courseToExistingParentIds = new Map<Id, Set<Id>>();
        Set<String>      existingJunctionKeys       = new Set<String>();

        for (Ken_Course_Evaluation_Schema_Mapper__c jx : [
            SELECT Ken_Evaluation_Component__c, Course_Offering__c
            FROM Ken_Course_Evaluation_Schema_Mapper__c
            WHERE Course_Offering__c IN :allOfferingIdToCourseId.keySet()
        ]) {
            Id courseId = allOfferingIdToCourseId.get(jx.Course_Offering__c);
            if (courseId == null) continue;
            if (!courseToExistingParentIds.containsKey(courseId)) {
                courseToExistingParentIds.put(courseId, new Set<Id>());
            }
            courseToExistingParentIds.get(courseId).add(jx.Ken_Evaluation_Component__c);
            existingJunctionKeys.add(
                String.valueOf(jx.Ken_Evaluation_Component__c) + '-' + String.valueOf(jx.Course_Offering__c)
            );
        }

        // ── Step 4: Determine which courses need a new component set ──────────
        List<Id> coursesNeedingComponents = new List<Id>();
        for (Id courseId : courseToNewOfferingIds.keySet()) {
            Set<Id> existing = courseToExistingParentIds.get(courseId);
            if (existing == null || existing.isEmpty()) {
                coursesNeedingComponents.add(courseId);
            }
        }

        // ── Step 5: Load schema template once and batch-create components ─────
        if (!coursesNeedingComponents.isEmpty()) {
            List<Ken_Evaluation_Schema_Component__c> schemaParents = [
                SELECT Id, Ken_Components__c, Ken_Exam_Type__c,
                       Ken_Effective_Marks__c, Ken_Maximum_Marks__c, Ken_Minimum_Marks__c,
                       Ken_Passing_Marks__c, Ken_Weightage__c, Ken_Enrollment__c,
                       Ken_Consider_for_Pass_Fail__c
                FROM Ken_Evaluation_Schema_Component__c
                WHERE Ken_Evaluation_Schema__c = :schemaId
                AND RecordType.DeveloperName = 'Ken_Evaluation_Schema_Component'
            ];

            if (!schemaParents.isEmpty()) {
                Set<Id> schemaParentIds = new Set<Id>();
                for (Ken_Evaluation_Schema_Component__c sp : schemaParents) schemaParentIds.add(sp.Id);

                List<Ken_Evaluation_Schema_Component__c> schemaChildren = [
                    SELECT Id, Ken_Evaluation_Schema_Component__c, Ken_Assessment__c,
                           Ken_Exam_Type__c, Ken_Effective_Marks__c, Ken_Maximum_Marks__c,
                           Ken_Minimum_Marks__c, Ken_Passing_Marks__c, Ken_Weightage__c,
                           Ken_Enrollment__c, Ken_Consider_for_Pass_Fail__c, Ken_Is_Exam_Required__c
                    FROM Ken_Evaluation_Schema_Component__c
                    WHERE Ken_Evaluation_Schema_Component__c IN :schemaParentIds
                    AND RecordType.DeveloperName = 'Ken_Evaluation_Schema_Sub_Component'
                ];

                // Build ALL parent records for ALL courses in one list (batched insert)
                // Track start index per course so we can map positions after insert.
                List<Ken_Evaluation_Component__c> allParentComps = new List<Ken_Evaluation_Component__c>();
                Map<Id, Integer> courseToParentStartIdx = new Map<Id, Integer>();

                for (Id courseId : coursesNeedingComponents) {
                    courseToParentStartIdx.put(courseId, allParentComps.size());
                    for (Ken_Evaluation_Schema_Component__c sp : schemaParents) {
                        allParentComps.add(new Ken_Evaluation_Component__c(
                            RecordTypeId                 = parentRtId,
                            Ken_Evaluation_Schema__c      = schemaId,
                            Ken_Components__c             = sp.Ken_Components__c,
                            Ken_Exam_Type__c              = sp.Ken_Exam_Type__c,
                            Ken_Effective_Marks__c        = sp.Ken_Effective_Marks__c,
                            Ken_Maximum_Marks__c          = sp.Ken_Maximum_Marks__c,
                            Ken_Minimum_Marks__c          = sp.Ken_Minimum_Marks__c,
                            Ken_Passing_Marks__c          = sp.Ken_Passing_Marks__c,
                            Ken_Weightage__c              = sp.Ken_Weightage__c,
                            Ken_Enrollment__c             = sp.Ken_Enrollment__c,
                            Ken_Consider_for_Pass_Fail__c = sp.Ken_Consider_for_Pass_Fail__c
                        ));
                    }
                }
                insert allParentComps; // single DML for all courses' parents

                // After insert, map each course → its new parent Ids and
                // schemaParentId → evalCompId (for child wiring)
                Map<Id, Map<Id, Id>> courseToSchemaParentToEvalId = new Map<Id, Map<Id, Id>>();
                for (Id courseId : coursesNeedingComponents) {
                    Integer startIdx = courseToParentStartIdx.get(courseId);
                    Map<Id, Id> spToEc = new Map<Id, Id>();
                    Set<Id>     newParentIds = new Set<Id>();
                    for (Integer i = 0; i < schemaParents.size(); i++) {
                        Id ecId = allParentComps[startIdx + i].Id;
                        spToEc.put(schemaParents[i].Id, ecId);
                        newParentIds.add(ecId);
                    }
                    courseToSchemaParentToEvalId.put(courseId, spToEc);
                    courseToExistingParentIds.put(courseId, newParentIds);
                }

                // Build ALL child records for ALL courses in one list (batched insert)
                List<Ken_Evaluation_Component__c> allChildComps = new List<Ken_Evaluation_Component__c>();
                for (Id courseId : coursesNeedingComponents) {
                    Map<Id, Id> spToEc = courseToSchemaParentToEvalId.get(courseId);
                    for (Ken_Evaluation_Schema_Component__c sc : schemaChildren) {
                        Id parentEcId = spToEc.get(sc.Ken_Evaluation_Schema_Component__c);
                        if (parentEcId == null) continue;
                        allChildComps.add(new Ken_Evaluation_Component__c(
                            RecordTypeId                      = childRtId,
                            Ken_Evaluation_Schema__c           = schemaId,
                            Ken_Parent_Evaluation_Component__c = parentEcId,
                            Ken_Assessment__c                 = sc.Ken_Assessment__c,
                            Ken_Exam_Type__c                  = sc.Ken_Exam_Type__c,
                            Ken_Effective_Marks__c            = sc.Ken_Effective_Marks__c,
                            Ken_Maximum_Marks__c              = sc.Ken_Maximum_Marks__c,
                            Ken_Minimum_Marks__c              = sc.Ken_Minimum_Marks__c,
                            Ken_Passing_Marks__c              = sc.Ken_Passing_Marks__c,
                            Ken_Weightage__c                  = sc.Ken_Weightage__c,
                            Ken_Enrollment__c                 = sc.Ken_Enrollment__c,
                            Ken_Consider_for_Pass_Fail__c     = sc.Ken_Consider_for_Pass_Fail__c,
                            Ken_Is_Exam_Required__c           = sc.Ken_Is_Exam_Required__c != null
                                                                ? sc.Ken_Is_Exam_Required__c : true
                        ));
                    }
                }
                if (!allChildComps.isEmpty()) insert allChildComps; // single DML for all courses' children
            }
        }

        // ── Step 6: Create junction records (parent × new offering, per course) ─
        List<Ken_Course_Evaluation_Schema_Mapper__c> junctionRecords = new List<Ken_Course_Evaluation_Schema_Mapper__c>();
        for (Id courseId : courseToNewOfferingIds.keySet()) {
            Set<Id>   parentIds      = courseToExistingParentIds.get(courseId);
            List<Id>  newOfferingIds = courseToNewOfferingIds.get(courseId);
            if (parentIds == null || parentIds.isEmpty()) continue;
            for (Id parentId : parentIds) {
                for (Id offeringId : newOfferingIds) {
                    String key = String.valueOf(parentId) + '-' + String.valueOf(offeringId);
                    if (!existingJunctionKeys.contains(key)) {
                        junctionRecords.add(new Ken_Course_Evaluation_Schema_Mapper__c(
                            Ken_Evaluation_Component__c = parentId,
                            Course_Offering__c          = offeringId
                        ));
                        existingJunctionKeys.add(key);
                    }
                }
            }
        }
        if (!junctionRecords.isEmpty()) insert junctionRecords;
    }

    // ─── Private: Delete Junction Records on Unmap ────────────────────────────

    private static void deleteEvaluationComponentMappings(List<Id> courseOfferingIds) {
        if (courseOfferingIds == null || courseOfferingIds.isEmpty()) return;
        List<Ken_Course_Evaluation_Schema_Mapper__c> toDelete = [
            SELECT Id
            FROM Ken_Course_Evaluation_Schema_Mapper__c
            WHERE Course_Offering__c IN :courseOfferingIds
        ];
        if (!toDelete.isEmpty()) delete toDelete;
    }

    // ─── Private: Get Evaluation Component Record Type Ids ────────────────────

    private static Map<String, Id> getEvaluationComponentRecordTypeIds() {
        Map<String, Id> result = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Ken_Evaluation_Component__c'
            AND DeveloperName IN ('Evaluation_Component', 'Evaluation_Sub_Component')
        ]) {
            result.put(rt.DeveloperName, rt.Id);
        }
        return result;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ─── Grade Schema Management ──────────────────────────────────────────────
    // ═══════════════════════════════════════════════════════════════════════════

    // ─── Grade Schema List (Card View) ────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<GradeSchemaCardWrapper> getGradeSchemaCards() {
        List<Ken_Grade_Scheme__c> schemas = [
            SELECT Id, Name, Ken_Is_Active__c
            FROM Ken_Grade_Scheme__c
            ORDER BY Name ASC
        ];
        if (schemas.isEmpty()) return new List<GradeSchemaCardWrapper>();

        Set<Id> schemaIds = new Set<Id>();
        for (Ken_Grade_Scheme__c s : schemas) schemaIds.add(s.Id);

        // Count criteria by mechanism per schema
        Map<Id, Integer> relativeCounts = new Map<Id, Integer>();
        Map<Id, Integer> absoluteCounts = new Map<Id, Integer>();
        Map<Id, Integer> letterGradeCounts = new Map<Id, Integer>();

        for (AggregateResult ar : [
            SELECT Ken_Grade_Scheme__c schemaId, Ken_Mechnism__c mechanism, COUNT(Id) cnt
            FROM Ken_Grade_Scheme_Critera__c
            WHERE Ken_Grade_Scheme__c IN :schemaIds
            GROUP BY Ken_Grade_Scheme__c, Ken_Mechnism__c
        ]) {
            Id sid = (Id) ar.get('schemaId');
            String mechanism = (String) ar.get('mechanism');
            Integer cnt = (Integer) ar.get('cnt');
            if (mechanism == 'Relative') {
                relativeCounts.put(sid, cnt);
            } else if (mechanism == 'Absolute') {
                absoluteCounts.put(sid, cnt);
            }
        }

        // Count letter grading records per schema (via criteria)
        Set<Id> criteriaIds = new Set<Id>();
        Map<Id, Id> criteriaToSchema = new Map<Id, Id>();
        for (Ken_Grade_Scheme_Critera__c c : [
            SELECT Id, Ken_Grade_Scheme__c
            FROM Ken_Grade_Scheme_Critera__c
            WHERE Ken_Grade_Scheme__c IN :schemaIds
        ]) {
            criteriaIds.add(c.Id);
            criteriaToSchema.put(c.Id, c.Ken_Grade_Scheme__c);
        }

        if (!criteriaIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT Ken_Grade_Scheme_Criteria__c criteriaId, COUNT(Id) cnt
                FROM Ken_Letter_Grading__c
                WHERE Ken_Grade_Scheme_Criteria__c IN :criteriaIds
                GROUP BY Ken_Grade_Scheme_Criteria__c
            ]) {
                Id cId = (Id) ar.get('criteriaId');
                Id sId = criteriaToSchema.get(cId);
                if (sId == null) continue;
                Integer prior = letterGradeCounts.containsKey(sId) ? letterGradeCounts.get(sId) : 0;
                letterGradeCounts.put(sId, prior + (Integer) ar.get('cnt'));
            }
        }

        List<GradeSchemaCardWrapper> result = new List<GradeSchemaCardWrapper>();
        for (Ken_Grade_Scheme__c s : schemas) {
            GradeSchemaCardWrapper w = new GradeSchemaCardWrapper();
            w.id = s.Id;
            w.name = s.Name;
            w.active = s.Ken_Is_Active__c;
            w.relativeCount = relativeCounts.containsKey(s.Id) ? relativeCounts.get(s.Id) : 0;
            w.absoluteCount = absoluteCounts.containsKey(s.Id) ? absoluteCounts.get(s.Id) : 0;
            w.letterGradeCount = letterGradeCounts.containsKey(s.Id) ? letterGradeCounts.get(s.Id) : 0;
            result.add(w);
        }
        return result;
    }

    // ─── Grade Schema Detail (for edit) ───────────────────────────────────────

    @AuraEnabled
    public static GradeSchemaDetailWrapper getGradeSchemaDetail(Id schemaId) {
        if (schemaId == null) return null;

        Ken_Grade_Scheme__c schema = [
            SELECT Id, Name, Ken_Is_Active__c
            FROM Ken_Grade_Scheme__c
            WHERE Id = :schemaId
            LIMIT 1
        ];

        List<Ken_Grade_Scheme_Critera__c> criteriaList = [
            SELECT Id, Ken_Operator__c, Ken_Range_To__c, Ken_Mechnism__c
            FROM Ken_Grade_Scheme_Critera__c
            WHERE Ken_Grade_Scheme__c = :schemaId
            ORDER BY Ken_Mechnism__c ASC
        ];

        Set<Id> criteriaIds = new Set<Id>();
        for (Ken_Grade_Scheme_Critera__c c : criteriaList) criteriaIds.add(c.Id);

        Map<Id, List<GradeSchemaLetterGradeWrapper>> letterGradesByCriteria =
            new Map<Id, List<GradeSchemaLetterGradeWrapper>>();

        if (!criteriaIds.isEmpty()) {
            for (Ken_Letter_Grading__c lg : [
                SELECT Id, Ken_Letter_Grade__c, Ken_Grade_Point__c, Ken_Definition__c,
                       Ken_Range_Start__c, Ken_Range_End__c, Ken_Grade_Scheme_Criteria__c
                FROM Ken_Letter_Grading__c
                WHERE Ken_Grade_Scheme_Criteria__c IN :criteriaIds
                ORDER BY Ken_Range_Start__c DESC
            ]) {
                GradeSchemaLetterGradeWrapper lgw = new GradeSchemaLetterGradeWrapper();
                lgw.id = lg.Id;
                lgw.letterGrade = lg.Ken_Letter_Grade__c;
                lgw.gradePoint = lg.Ken_Grade_Point__c;
                lgw.definition = lg.Ken_Definition__c;
                lgw.rangeStart = lg.Ken_Range_Start__c;
                lgw.rangeEnd = lg.Ken_Range_End__c;

                if (!letterGradesByCriteria.containsKey(lg.Ken_Grade_Scheme_Criteria__c)) {
                    letterGradesByCriteria.put(lg.Ken_Grade_Scheme_Criteria__c,
                        new List<GradeSchemaLetterGradeWrapper>());
                }
                letterGradesByCriteria.get(lg.Ken_Grade_Scheme_Criteria__c).add(lgw);
            }
        }

        GradeSchemaDetailWrapper result = new GradeSchemaDetailWrapper();
        result.id = schema.Id;
        result.name = schema.Name;
        result.active = schema.Ken_Is_Active__c;

        for (Ken_Grade_Scheme_Critera__c c : criteriaList) {
            GradeSchemaCriteriaWrapper cw = new GradeSchemaCriteriaWrapper();
            cw.id = c.Id;
            cw.operator = c.Ken_Operator__c;
            cw.rangeTo = c.Ken_Range_To__c;
            cw.mechanism = c.Ken_Mechnism__c;
            cw.letterGrades = letterGradesByCriteria.containsKey(c.Id)
                ? letterGradesByCriteria.get(c.Id)
                : new List<GradeSchemaLetterGradeWrapper>();

            if (c.Ken_Mechnism__c == 'Relative') {
                result.relativeCriteria = cw;
            } else if (c.Ken_Mechnism__c == 'Absolute') {
                result.absoluteCriteria = cw;
            }
        }

        return result;
    }

    // ─── Save Grade Schema (Create / Update) ─────────────────────────────────

    @AuraEnabled
    public static Id saveGradeSchema(GradeSchemaUpsertRequest request) {
        if (request == null) throw new AuraHandledException('Missing grade schema payload.');
        if (String.isBlank(request.name)) throw new AuraHandledException('Schema name is required.');

        // ── Upsert Grade Scheme ───────────────────────────────────────────────
        Ken_Grade_Scheme__c schema = new Ken_Grade_Scheme__c();
        Id existingSchemaId = tryParseId(request.id);
        if (existingSchemaId != null) schema.Id = existingSchemaId;
        schema.Name = request.name;
        schema.Ken_Is_Active__c = request.active != null ? request.active : true;
        upsert schema;

        // ── Upsert Criteria (Relative + Absolute) ────────────────────────────
        List<GradeSchemaCriteriaUpsertRequest> criteriaRequests = new List<GradeSchemaCriteriaUpsertRequest>();
        List<Ken_Grade_Scheme_Critera__c> criteriaRecords = new List<Ken_Grade_Scheme_Critera__c>();

        if (request.relativeCriteria != null) {
            criteriaRequests.add(request.relativeCriteria);
            criteriaRecords.add(buildCriteriaRecord(request.relativeCriteria, schema.Id, 'Relative'));
        }
        if (request.absoluteCriteria != null) {
            criteriaRequests.add(request.absoluteCriteria);
            criteriaRecords.add(buildCriteriaRecord(request.absoluteCriteria, schema.Id, 'Absolute'));
        }
        if (!criteriaRecords.isEmpty()) upsert criteriaRecords;

        // ── Delete removed criteria (edit mode) ──────────────────────────────
        if (existingSchemaId != null) {
            Set<Id> incomingCriteriaIds = new Set<Id>();
            for (Ken_Grade_Scheme_Critera__c cr : criteriaRecords) {
                if (cr.Id != null) incomingCriteriaIds.add(cr.Id);
            }
            List<Ken_Grade_Scheme_Critera__c> existingCriteria = [
                SELECT Id FROM Ken_Grade_Scheme_Critera__c
                WHERE Ken_Grade_Scheme__c = :schema.Id
            ];
            List<Id> removedCriteriaIds = new List<Id>();
            for (Ken_Grade_Scheme_Critera__c ec : existingCriteria) {
                if (!incomingCriteriaIds.contains(ec.Id)) removedCriteriaIds.add(ec.Id);
            }
            if (!removedCriteriaIds.isEmpty()) {
                delete [SELECT Id FROM Ken_Letter_Grading__c WHERE Ken_Grade_Scheme_Criteria__c IN :removedCriteriaIds];
                delete [SELECT Id FROM Ken_Grade_Scheme_Critera__c WHERE Id IN :removedCriteriaIds];
            }
        }

        // ── Upsert Letter Grades per Criteria ─────────────────────────────────
        for (Integer i = 0; i < criteriaRequests.size(); i++) {
            GradeSchemaCriteriaUpsertRequest cReq = criteriaRequests[i];
            Id criteriaId = criteriaRecords[i].Id;
            if (criteriaId == null || cReq.letterGrades == null) continue;

            // Delete removed letter grades
            Set<Id> incomingLgIds = new Set<Id>();
            for (GradeSchemaLetterGradeUpsertRequest lgReq : cReq.letterGrades) {
                Id eid = tryParseId(lgReq.id);
                if (eid != null) incomingLgIds.add(eid);
            }
            List<Ken_Letter_Grading__c> existingLgs = [
                SELECT Id FROM Ken_Letter_Grading__c
                WHERE Ken_Grade_Scheme_Criteria__c = :criteriaId
            ];
            List<Ken_Letter_Grading__c> lgsToDelete = new List<Ken_Letter_Grading__c>();
            for (Ken_Letter_Grading__c elg : existingLgs) {
                if (!incomingLgIds.contains(elg.Id)) lgsToDelete.add(elg);
            }
            if (!lgsToDelete.isEmpty()) delete lgsToDelete;

            // Upsert letter grades
            List<Ken_Letter_Grading__c> lgRecords = new List<Ken_Letter_Grading__c>();
            for (GradeSchemaLetterGradeUpsertRequest lgReq : cReq.letterGrades) {
                Ken_Letter_Grading__c lg = new Ken_Letter_Grading__c();
                Id existingLgId = tryParseId(lgReq.id);
                if (existingLgId != null) lg.Id = existingLgId;
                lg.Ken_Grade_Scheme_Criteria__c = criteriaId;
                lg.Ken_Letter_Grade__c = lgReq.letterGrade;
                lg.Ken_Grade_Point__c = lgReq.gradePoint;
                lg.Ken_Definition__c = lgReq.definition;
                lg.Ken_Range_Start__c = lgReq.rangeStart;
                lg.Ken_Range_End__c = lgReq.rangeEnd;
                lgRecords.add(lg);
            }
            if (!lgRecords.isEmpty()) upsert lgRecords;
        }

        return schema.Id;
    }

    // ─── Delete Grade Schema ──────────────────────────────────────────────────

    @AuraEnabled
    public static void deleteGradeSchema(Id schemaId) {
        if (schemaId == null) throw new AuraHandledException('Missing schema Id.');

        List<Ken_Grade_Scheme_Critera__c> criteria = [
            SELECT Id FROM Ken_Grade_Scheme_Critera__c WHERE Ken_Grade_Scheme__c = :schemaId
        ];
        Set<Id> criteriaIds = new Set<Id>();
        for (Ken_Grade_Scheme_Critera__c c : criteria) criteriaIds.add(c.Id);

        if (!criteriaIds.isEmpty()) {
            delete [SELECT Id FROM Ken_Letter_Grading__c WHERE Ken_Grade_Scheme_Criteria__c IN :criteriaIds];
        }
        if (!criteria.isEmpty()) delete criteria;
        delete [SELECT Id FROM Ken_Grade_Scheme__c WHERE Id = :schemaId];
    }

    // ─── Operator Picklist (Ken_Operator__c on Ken_Grade_Scheme_Critera__c) ──

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getOperatorPicklistValues() {
        List<PicklistOption> options = new List<PicklistOption>();
        Schema.DescribeFieldResult fieldDesc =
            Ken_Grade_Scheme_Critera__c.Ken_Operator__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldDesc.getPicklistValues()) {
            if (entry.isActive()) {
                PicklistOption opt = new PicklistOption();
                opt.value = entry.getValue();
                opt.label = entry.getLabel();
                options.add(opt);
            }
        }
        return options;
    }

    // ─── Letter Grade Picklist (Ken_Letter_Grade__c on Ken_Letter_Grading__c) ─

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getLetterGradePicklistValues() {
        List<PicklistOption> options = new List<PicklistOption>();
        Schema.DescribeFieldResult fieldDesc =
            Ken_Letter_Grading__c.Ken_Letter_Grade__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldDesc.getPicklistValues()) {
            if (entry.isActive()) {
                PicklistOption opt = new PicklistOption();
                opt.value = entry.getValue();
                opt.label = entry.getLabel();
                options.add(opt);
            }
        }
        return options;
    }

    // ─── Private: Build Criteria SObject ──────────────────────────────────────

    private static Ken_Grade_Scheme_Critera__c buildCriteriaRecord(
        GradeSchemaCriteriaUpsertRequest req, Id schemaId, String mechanism
    ) {
        Ken_Grade_Scheme_Critera__c c = new Ken_Grade_Scheme_Critera__c();
        Id existingId = tryParseId(req.id);
        if (existingId != null) c.Id = existingId;
        c.Ken_Grade_Scheme__c = schemaId;
        c.Ken_Operator__c = req.operator;
        c.Ken_Range_To__c = req.rangeTo;
        c.Ken_Mechnism__c = mechanism;
        return c;
    }

    // ─── Wrapper Classes ───────────────────────────────────────────────────────

    public class ExamCycleWrapper {
        @AuraEnabled public Id      id            { get; set; }
        @AuraEnabled public String  name          { get; set; }
        @AuraEnabled public String  term          { get; set; }
        @AuraEnabled public Id      termId        { get; set; }
        @AuraEnabled public Boolean isActive      { get; set; }
        @AuraEnabled public Integer courses       { get; set; }
        @AuraEnabled public Integer mappedSchemas { get; set; }
        @AuraEnabled public String  academicYear  { get; set; }
        @AuraEnabled public String  startDate     { get; set; }
        @AuraEnabled public String  endDate       { get; set; }
    }

    public class CourseMappingWrapper implements Comparable {
        @AuraEnabled public Id      id                   { get; set; }
        @AuraEnabled public String  courseName           { get; set; }
        @AuraEnabled public String  courseCode           { get; set; }
        @AuraEnabled public Integer credits              { get; set; }
        @AuraEnabled public String  department           { get; set; }
        @AuraEnabled public Integer enrolledStudents     { get; set; }
        @AuraEnabled public Id      evaluationSchemaId   { get; set; }
        @AuraEnabled public String  evaluationSchemaName { get; set; }
        @AuraEnabled public Id      gradeSchemaId        { get; set; }
        @AuraEnabled public String  gradeSchemaName      { get; set; }

        public Integer compareTo(Object other) {
            CourseMappingWrapper o = (CourseMappingWrapper) other;
            return (this.courseName == null ? '' : this.courseName)
                       .compareTo(o.courseName == null ? '' : o.courseName);
        }
    }

    public class SchemaPickerWrapper {
        @AuraEnabled public Id     id   { get; set; }
        @AuraEnabled public String name { get; set; }
    }

    public class PicklistOption {
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String label { get; set; }
    }

    public class AcademicTermOption {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
    }

    public class ExamPlanWrapper {
        @AuraEnabled public Id     id         { get; set; }
        @AuraEnabled public String name       { get; set; }
        @AuraEnabled public String assessment { get; set; }
        @AuraEnabled public String startDate  { get; set; }
        @AuraEnabled public String endDate    { get; set; }
    }

    public class ExaminationRowWrapper {
        @AuraEnabled public Id     id            { get; set; }
        @AuraEnabled public String courseNumber  { get; set; }
        @AuraEnabled public String courseName    { get; set; }
        @AuraEnabled public String enrollment    { get; set; }
        @AuraEnabled public String questionPaper { get; set; }
        @AuraEnabled public String schedule      { get; set; }
        @AuraEnabled public String seatingPlan   { get; set; }
        @AuraEnabled public String invigilator   { get; set; }
        @AuraEnabled public String marksEntry    { get; set; }
    }

    public class EnrollmentProgramRowWrapper implements Comparable {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public Id programPlanId { get; set; }
        @AuraEnabled public String code { get; set; }
        @AuraEnabled public String program { get; set; }
        @AuraEnabled public Integer students { get; set; }
        @AuraEnabled public String startDate { get; set; }
        @AuraEnabled public String endDate { get; set; }
        @AuraEnabled public String status { get; set; }

        public Integer compareTo(Object other) {
            EnrollmentProgramRowWrapper o = (EnrollmentProgramRowWrapper) other;
            String a = this.program == null ? '' : this.program.toLowerCase();
            String b = o.program == null ? '' : o.program.toLowerCase();
            return a.compareTo(b);
        }
    }

    public class EnrollmentCriteriaOptionsWrapper {
        @AuraEnabled public List<PicklistOption> feeCriteria { get; set; }
        @AuraEnabled public List<PicklistOption> backlogOptions { get; set; }
        @AuraEnabled public List<PicklistOption> regularOptions { get; set; }
    }

    public class EnrollmentCriteriaDetailWrapper {
        @AuraEnabled public Id programPlanId { get; set; }
        @AuraEnabled public String programPlanName { get; set; }
        @AuraEnabled public String startOn { get; set; }
        @AuraEnabled public String endsOn { get; set; }
        @AuraEnabled public String lateFineOn { get; set; }
        @AuraEnabled public Boolean sameFeeCriteria { get; set; }
        @AuraEnabled public String feeCriteria { get; set; }
        @AuraEnabled public String regularFeeCriteria { get; set; }
        @AuraEnabled public String backlogFeeCriteria { get; set; }
        @AuraEnabled public String backlogMode { get; set; }
        @AuraEnabled public String regularMode { get; set; }
        @AuraEnabled public String declaration { get; set; }
        @AuraEnabled public List<FeeRowView> feeItems { get; set; }
        @AuraEnabled public List<FeeRowView> regularFeeItems { get; set; }
        @AuraEnabled public List<FeeRowView> backlogFeeItems { get; set; }
    }

    public class FeeRowView {
        @AuraEnabled public Id criteriaId { get; set; }
        @AuraEnabled public Id feeTypeId { get; set; }
        @AuraEnabled public String feeTypeName { get; set; }
        @AuraEnabled public Decimal examFee { get; set; }
    }

    public class EnrollmentCriteriaRequest {
        @AuraEnabled public Id planId { get; set; }
        @AuraEnabled public List<Id> programPlanIds { get; set; }
        @AuraEnabled public String startOn { get; set; }
        @AuraEnabled public String endsOn { get; set; }
        @AuraEnabled public String lateFineOn { get; set; }
        @AuraEnabled public Boolean sameFeeCriteria { get; set; }
        @AuraEnabled public String feeCriteria { get; set; }
        @AuraEnabled public List<FeeItemRequest> feeItems { get; set; }
        @AuraEnabled public String regularFeeCriteria { get; set; }
        @AuraEnabled public List<FeeItemRequest> regularFeeItems { get; set; }
        @AuraEnabled public String backlogFeeCriteria { get; set; }
        @AuraEnabled public List<FeeItemRequest> backlogFeeItems { get; set; }
        @AuraEnabled public Boolean allowBacklog { get; set; }
        @AuraEnabled public String backlogMode { get; set; }
        @AuraEnabled public Boolean allowRegular { get; set; }
        @AuraEnabled public String regularMode { get; set; }
        @AuraEnabled public String declaration { get; set; }
    }

    public class FeeItemRequest {
        @AuraEnabled public Id feeTypeId { get; set; }
        @AuraEnabled public Decimal examFee { get; set; }
    }

    public class FeeTypeOptionWrapper {
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String label { get; set; }
    }

    public class SessionOptionWrapper implements Comparable {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }

        public Integer compareTo(Object other) {
            SessionOptionWrapper o = (SessionOptionWrapper) other;
            return (this.name == null ? '' : this.name)
                .compareTo(o.name == null ? '' : o.name);
        }
    }

    public class CourseOfferingFilterOptionsWrapper {
        @AuraEnabled public List<SessionOptionWrapper> academicSessions { get; set; }
        @AuraEnabled public List<PicklistOption> enrollmentTypes { get; set; }
    }

    public class CourseOfferingDetailWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String activeProgramOfferings { get; set; }
        @AuraEnabled public String courseNumber { get; set; }
        @AuraEnabled public String courseName { get; set; }
        @AuraEnabled public Decimal enrollmentCapacity { get; set; }
        @AuraEnabled public Decimal filledInCount { get; set; }
        @AuraEnabled public String courseType { get; set; }
        @AuraEnabled public String offeringType { get; set; }
        @AuraEnabled public Id academicSessionId { get; set; }
        @AuraEnabled public String academicSessionName { get; set; }
    }

    public class EvaluationSchemaCardWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Decimal totalMarks { get; set; }
        @AuraEnabled public Decimal passingMarks { get; set; }
        @AuraEnabled public Integer coursesApplied { get; set; }
        @AuraEnabled public Integer componentCount { get; set; }
        @AuraEnabled public Integer subComponentCount { get; set; }
    }

    public class EvaluationSchemaDetailWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Decimal totalMarks { get; set; }
        @AuraEnabled public Decimal passingMarks { get; set; }
        @AuraEnabled public Boolean isRequiredForGrading { get; set; }
        @AuraEnabled public Integer coursesApplied { get; set; }
        @AuraEnabled public Integer componentCount { get; set; }
        @AuraEnabled public Integer subComponentCount { get; set; }
        @AuraEnabled public List<EvaluationSchemaComponentWrapper> components { get; set; }
    }

    public class EvaluationSchemaComponentWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String kenComponent { get; set; }
        @AuraEnabled public String examCategory { get; set; }
        @AuraEnabled public String examType { get; set; }
        @AuraEnabled public Decimal effectiveMarks { get; set; }
        @AuraEnabled public Decimal maxMarks { get; set; }
        @AuraEnabled public Decimal minMarks { get; set; }
        @AuraEnabled public Decimal passingMarks { get; set; }
        @AuraEnabled public Decimal weightage { get; set; }
        @AuraEnabled public String enrollmentType { get; set; }
        @AuraEnabled public Boolean considerForPassFail { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public List<EvaluationSchemaSubComponentWrapper> subComponents { get; set; }
    }

    public class EvaluationSchemaSubComponentWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String kenAssessment { get; set; }
        @AuraEnabled public String examCategory { get; set; }
        @AuraEnabled public String examType { get; set; }
        @AuraEnabled public Decimal effectiveMarks { get; set; }
        @AuraEnabled public Decimal maxMarks { get; set; }
        @AuraEnabled public Decimal minMarks { get; set; }
        @AuraEnabled public Decimal passingMarks { get; set; }
        @AuraEnabled public Decimal weightage { get; set; }
        @AuraEnabled public String enrollmentType { get; set; }
        @AuraEnabled public Boolean considerForPassFail { get; set; }
        @AuraEnabled public Boolean examRequired { get; set; }
    }

    public class EvaluationSchemaUpsertRequest {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Decimal totalMarks { get; set; }
        @AuraEnabled public Decimal passingMarks { get; set; }
        @AuraEnabled public Boolean isRequiredForGrading { get; set; }
        @AuraEnabled public List<EvaluationSchemaComponentUpsertRequest> components { get; set; }
    }

    public class EvaluationSchemaComponentUpsertRequest {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String kenComponent { get; set; }
        @AuraEnabled public String examCategory { get; set; }
        @AuraEnabled public String examType { get; set; }
        @AuraEnabled public Decimal effectiveMarks { get; set; }
        @AuraEnabled public Decimal maxMarks { get; set; }
        @AuraEnabled public Decimal minMarks { get; set; }
        @AuraEnabled public Decimal passingMarks { get; set; }
        @AuraEnabled public Decimal weightage { get; set; }
        @AuraEnabled public String enrollmentType { get; set; }
        @AuraEnabled public Boolean considerForPassFail { get; set; }
        @AuraEnabled public List<EvaluationSchemaSubComponentUpsertRequest> subComponents { get; set; }
    }

    public class EvaluationSchemaSubComponentUpsertRequest {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String kenAssessment { get; set; }
        @AuraEnabled public String examCategory { get; set; }
        @AuraEnabled public String examType { get; set; }
        @AuraEnabled public Decimal effectiveMarks { get; set; }
        @AuraEnabled public Decimal maxMarks { get; set; }
        @AuraEnabled public Decimal minMarks { get; set; }
        @AuraEnabled public Decimal passingMarks { get; set; }
        @AuraEnabled public Decimal weightage { get; set; }
        @AuraEnabled public String enrollmentType { get; set; }
        @AuraEnabled public Boolean considerForPassFail { get; set; }
        @AuraEnabled public Boolean examRequired { get; set; }
    }

    // ─── Grade Schema Wrappers ────────────────────────────────────────────────

    public class GradeSchemaCardWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Boolean active { get; set; }
        @AuraEnabled public Integer relativeCount { get; set; }
        @AuraEnabled public Integer absoluteCount { get; set; }
        @AuraEnabled public Integer letterGradeCount { get; set; }
    }

    public class GradeSchemaDetailWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Boolean active { get; set; }
        @AuraEnabled public GradeSchemaCriteriaWrapper relativeCriteria { get; set; }
        @AuraEnabled public GradeSchemaCriteriaWrapper absoluteCriteria { get; set; }
    }

    public class GradeSchemaCriteriaWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String operator { get; set; }
        @AuraEnabled public Decimal rangeTo { get; set; }
        @AuraEnabled public String mechanism { get; set; }
        @AuraEnabled public List<GradeSchemaLetterGradeWrapper> letterGrades { get; set; }
    }

    public class GradeSchemaLetterGradeWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String letterGrade { get; set; }
        @AuraEnabled public Decimal gradePoint { get; set; }
        @AuraEnabled public String definition { get; set; }
        @AuraEnabled public Decimal rangeStart { get; set; }
        @AuraEnabled public Decimal rangeEnd { get; set; }
    }

    public class GradeSchemaUpsertRequest {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Boolean active { get; set; }
        @AuraEnabled public GradeSchemaCriteriaUpsertRequest relativeCriteria { get; set; }
        @AuraEnabled public GradeSchemaCriteriaUpsertRequest absoluteCriteria { get; set; }
    }

    public class GradeSchemaCriteriaUpsertRequest {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String operator { get; set; }
        @AuraEnabled public Decimal rangeTo { get; set; }
        @AuraEnabled public List<GradeSchemaLetterGradeUpsertRequest> letterGrades { get; set; }
    }

    public class GradeSchemaLetterGradeUpsertRequest {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String letterGrade { get; set; }
        @AuraEnabled public Decimal gradePoint { get; set; }
        @AuraEnabled public String definition { get; set; }
        @AuraEnabled public Decimal rangeStart { get; set; }
        @AuraEnabled public Decimal rangeEnd { get; set; }
    }

    // ─── Schedule Wrappers ────────────────────────────────────────────────────

    public class ScheduleRowWrapper implements Comparable {
        @AuraEnabled public String key { get; set; }
        @AuraEnabled public String courseNumber { get; set; }
        @AuraEnabled public String courseName { get; set; }
        @AuraEnabled public Integer enrolledStudents { get; set; }
        @AuraEnabled public List<Id> examIds { get; set; }
        @AuraEnabled public Boolean hasSchedule { get; set; }
        @AuraEnabled public Integer scheduleCount { get; set; }
        @AuraEnabled public List<ScheduleSetWrapper> schedules { get; set; }

        public Integer compareTo(Object other) {
            ScheduleRowWrapper o = (ScheduleRowWrapper) other;
            String a = this.courseNumber == null ? '' : this.courseNumber;
            String b = o.courseNumber == null ? '' : o.courseNumber;
            return a.compareTo(b);
        }
    }

    public class ScheduleSetWrapper {
        @AuraEnabled public Datetime startDateTime { get; set; }
        @AuraEnabled public Datetime endDateTime { get; set; }
        @AuraEnabled public Decimal durationHours { get; set; }
        @AuraEnabled public Integer count { get; set; }
    }

    public class ScheduleSaveRequest {
        @AuraEnabled public List<Id> examIds { get; set; }
        @AuraEnabled public List<ScheduleSetRequest> sets { get; set; }
    }

    public class ScheduleSetRequest {
        @AuraEnabled public Integer count { get; set; }
        @AuraEnabled public String startDateTime { get; set; }
        @AuraEnabled public String endDateTime { get; set; }
    }

    private class ScheduleSetParsed {
        Integer index;
        Integer count;
        Datetime startDt;
        Datetime endDt;
        Decimal durationHours;
    }
}