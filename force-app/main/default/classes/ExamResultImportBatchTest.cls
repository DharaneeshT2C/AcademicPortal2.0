@IsTest
private class ExamResultImportBatchTest {
    @IsTest
    static void importsExamCourseResultsAndActivityGrades() {
        TestContextData ctx = createExamImportContext('Course Result');

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'RowNumber' => '1',
                'Student Registration ID' => ctx.studentRegistrationId,
                'Course Code' => ctx.course.CourseNumber,
                'Course Credit' => '3',
                'Internal Total Marks' => '24',
                'External Total Mark' => '61',
                'Revaluation Marks' => '66',
                'Retest/Suply Marks' => '72',
                'Total Marks' => '85',
                'Grade' => 'A',
                'Grade Point' => '9.5'
            }
        };

        Test.startTest();
        Id jobId = HistoricalDataImportController.startExamCourseResultImport(JSON.serialize(rows), ctx.examCycleId);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch job id should be returned.');

        List<CourseOfferingPtcpResult> results = [
            SELECT CourseOfferingParticipantId, UnitsEarned, LetterGrade, NumericGrade
            FROM CourseOfferingPtcpResult
            WHERE CourseOfferingParticipantId = :ctx.participant.Id
        ];
        System.assertEquals(1, results.size(), 'Expected one COP result row.');
        System.assertEquals(Decimal.valueOf('3'), results[0].UnitsEarned);
        System.assertEquals('A', results[0].LetterGrade);
        System.assertEquals(Decimal.valueOf('9.5'), results[0].NumericGrade);

        Id participantId = ctx.participant.Id;
        List<SObject> activityGrades = Database.query(
            'SELECT CourseOfferingParticipantId, Score, ActivityType, ScoreStatus, Ken_Evaluation_Component__c ' +
            'FROM CourseOfrPtcpActvtyGrd WHERE CourseOfferingParticipantId = :participantId'
        );
        System.assertEquals(4, activityGrades.size(), 'Expected four activity-grade rows.');

        Set<Decimal> actualScores = new Set<Decimal>();
        for (SObject activityGrade : activityGrades) {
            System.assertEquals(ctx.participant.Id, (Id) activityGrade.get('CourseOfferingParticipantId'));
            System.assertEquals('Exam', (String) activityGrade.get('ActivityType'));
            System.assertEquals('Fully Graded', (String) activityGrade.get('ScoreStatus'));
            System.assertNotEquals(null, activityGrade.get('Ken_Evaluation_Component__c'));
            actualScores.add((Decimal) activityGrade.get('Score'));
        }
        System.assertEquals(
            new Set<Decimal>{Decimal.valueOf('24'), Decimal.valueOf('61'), Decimal.valueOf('66'), Decimal.valueOf('72')},
            actualScores
        );

        List<String> errors = HistoricalDataImportController.getImportErrors(jobId, 'Exam Course Result Import');
        System.assertEquals(1, errors.size(), 'Expected one warning for Total Marks.');
        System.assert(errors[0].contains('Total Marks does not have a mapped destination field'));

        List<HistoricalDataImportController.ExamCycleOptionDTO> examCycles = HistoricalDataImportController.getExamCycles();
        Boolean foundCycle = false;
        for (HistoricalDataImportController.ExamCycleOptionDTO option : examCycles) {
            if (option != null && option.id == ctx.examCycleId) {
                foundCycle = true;
                break;
            }
        }
        System.assertEquals(true, foundCycle, 'Created exam cycle should be returned by the controller.');
    }

    @IsTest
    static void importsExamTermResultsAndLogsIgnoredColumns() {
        TestContextData ctx = createExamImportContext('Term Result');

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'RowNumber' => '1',
                'Student Registration ID' => ctx.studentRegistrationId,
                'GPA' => '8.25',
                'CGPA' => '8.10',
                'Total Grade Points' => '33',
                'Credits Earned' => '21',
                'Status' => 'Active'
            }
        };

        Test.startTest();
        Id jobId = HistoricalDataImportController.startExamTermResultImport(JSON.serialize(rows), ctx.examCycleId);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch job id should be returned.');

        AcademicTermEnrollment refreshedAte = [
            SELECT TermGradePointAverage, CumulativeGradePointAverage, EnrollmentStatus
            FROM AcademicTermEnrollment
            WHERE Id = :ctx.academicTermEnrollment.Id
        ];
        System.assertEquals(Decimal.valueOf('8.25'), refreshedAte.TermGradePointAverage);
        System.assertEquals(Decimal.valueOf('8.10'), refreshedAte.CumulativeGradePointAverage);
        System.assertEquals('Active', refreshedAte.EnrollmentStatus);

        List<String> errors = HistoricalDataImportController.getImportErrors(jobId, 'Exam Term Result Import');
        System.assertEquals(2, errors.size(), 'Expected warnings for unmapped term-result columns.');
        System.assert(containsText(errors, 'Credits Earned does not have a mapped field'));
        System.assert(containsText(errors, 'Total Grade Points does not have a mapped field'));
        System.assertEquals(0, HistoricalDataImportController.getImportErrors(null, 'Exam Term Result Import').size());
    }

    @IsTest
    static void logsErrorsForMissingExamCycleAndMissingRequiredFields() {
        TestContextData ctx = createExamImportContext('Error Paths');

        List<Map<String, Object>> courseRows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'RowNumber' => '1',
                'Student Registration ID' => '',
                'Course Code' => '',
                'Course Credit' => '3'
            },
            new Map<String, Object>{
                'RowNumber' => '2',
                'Student Registration ID' => 'UNKNOWN',
                'Course Code' => ctx.course.CourseNumber,
                'Course Credit' => '99'
            }
        };
        List<Map<String, Object>> termRows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'RowNumber' => '1',
                'Student Registration ID' => ''
            },
            new Map<String, Object>{
                'RowNumber' => '2',
                'Student Registration ID' => 'UNKNOWN',
                'Status' => 'NotARealStatus'
            }
        };

        Test.startTest();
        Id missingCycleCourseJobId = HistoricalDataImportController.startExamCourseResultImport(JSON.serialize(courseRows), null);
        Id invalidCourseJobId = HistoricalDataImportController.startExamCourseResultImport(JSON.serialize(courseRows), ctx.examCycleId);
        Id missingCycleTermJobId = HistoricalDataImportController.startExamTermResultImport(JSON.serialize(termRows), null);
        Id invalidTermJobId = HistoricalDataImportController.startExamTermResultImport(JSON.serialize(termRows), ctx.examCycleId);
        Test.stopTest();

        System.assertNotEquals(null, missingCycleCourseJobId);
        System.assertNotEquals(null, invalidCourseJobId);
        System.assertNotEquals(null, missingCycleTermJobId);
        System.assertNotEquals(null, invalidTermJobId);

        List<String> missingCycleCourseErrors =
            HistoricalDataImportController.getImportErrors(missingCycleCourseJobId, 'Exam Course Result Import');
        List<String> invalidCourseErrors =
            HistoricalDataImportController.getImportErrors(invalidCourseJobId, 'Exam Course Result Import');
        List<String> missingCycleTermErrors =
            HistoricalDataImportController.getImportErrors(missingCycleTermJobId, 'Exam Term Result Import');
        List<String> invalidTermErrors =
            HistoricalDataImportController.getImportErrors(invalidTermJobId, 'Exam Term Result Import');

        System.assert(containsText(missingCycleCourseErrors, 'Exam Cycle is required for Exam Course Result Import.'));
        System.assert(containsText(invalidCourseErrors, 'Student Registration ID is required.'));
        System.assert(containsText(invalidCourseErrors, 'Student was not found for Student Registration ID "UNKNOWN"'));

        System.assert(containsText(missingCycleTermErrors, 'Exam Cycle is required for Exam Term Result Import.'));
        System.assert(containsText(invalidTermErrors, 'Student Registration ID is required.'));
        System.assert(containsText(invalidTermErrors, 'Student was not found for Student Registration ID "UNKNOWN"'));
    }

    @IsTest
    static void coversHistoricalDataImportControllerEntryPoints() {
        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY Controller Coverage', '2041').create();
        AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(2041, '1', academicYear.Id).create();
        AcademicSession sessionRow = createSession('Controller Coverage Session', term.Id);
        Learning learning = new KenTestDataFactory.LearningCreator('Controller Coverage Learning').create();
        Schema.Location campus = new KenTestDataFactory.LocationCreator('Controller Coverage Campus', 'Campus').create();
        LearningProgram program = new KenTestDataFactory.LearningProgramCreator('Controller Coverage Program')
            .setLearningId(learning.Id)
            .setCampus(campus.Id)
            .create();
        LearningProgramPlan plan = new KenTestDataFactory.LearningProgramPlanCreator(program.Id).create();
        Id examCycleId = createExamCycle('Controller Coverage Cycle', term.Id);

        Test.startTest();
        List<HistoricalDataImportController.SessionOptionDTO> sessions = HistoricalDataImportController.getAcademicSessions();
        List<HistoricalDataImportController.PlanOptionDTO> plans = HistoricalDataImportController.getActiveProgramPlans();
        List<HistoricalDataImportController.ProgramOptionDTO> programs = HistoricalDataImportController.getLearningPrograms();
        List<HistoricalDataImportController.ExamCycleOptionDTO> examCycles = HistoricalDataImportController.getExamCycles();
        Id courseOfferingJobId = HistoricalDataImportController.startCourseOfferingImport('[]', sessionRow.Id, plan.Id);
        Id participantJobId = HistoricalDataImportController.startCourseOfferingParticipantImport('[]', sessionRow.Id);
        Id examImportJobId = HistoricalDataImportController.startExamImport('[]', program.Id);
        Test.stopTest();

        System.assert(!sessions.isEmpty());
        System.assert(!plans.isEmpty());
        System.assert(!programs.isEmpty());
        System.assert(!examCycles.isEmpty());
        System.assertNotEquals(null, courseOfferingJobId);
        System.assertNotEquals(null, participantJobId);
        System.assertNotEquals(null, examImportJobId);
        System.assertNotEquals(null, HistoricalDataImportController.getImportErrors(courseOfferingJobId, 'Course Offering Import'));
    }

    @IsTest
    static void coversAdditionalExamCourseResultBranches() {
        Integer emptyCourseStartCount = 0;
        for (Map<String, Object> row : new ExamCourseResultImportBatch('', null).start(null)) {
            emptyCourseStartCount++;
        }
        System.assertEquals(0, emptyCourseStartCount);
        new ExamCourseResultImportBatch('[]', null).execute(null, new List<Map<String, Object>>());

        TestContextData ctx = createExamImportContext('Course Branches');
        Contact noAteStudent = createStudent(ctx.institute.Id, 'student.noate.course@example.edu');
        String noAteRegistrationId = 'REG-NOATE-' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        createStudentRole(noAteStudent.Id, noAteRegistrationId);

        Id cycleWithoutTermId = createExamCycle('Course Branches No Term', null);
        Id deletedCycleId = createDeletedExamCycleId();

        List<Map<String, Object>> branchRows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'RowNumber' => '1',
                'Student Registration ID' => ctx.studentRegistrationId,
                'Course Code' => ''
            },
            new Map<String, Object>{
                'RowNumber' => '2',
                'Student Registration ID' => noAteRegistrationId,
                'Course Code' => ctx.course.CourseNumber,
                'Course Credit' => '3'
            },
            new Map<String, Object>{
                'RowNumber' => '3',
                'Student Registration ID' => ctx.studentRegistrationId,
                'Course Code' => ctx.course.CourseNumber,
                'Course Credit' => '99'
            }
        };

        Test.startTest();
        new ExamCourseResultImportBatch(JSON.serialize(branchRows), cycleWithoutTermId).execute(null, branchRows);
        new ExamCourseResultImportBatch(JSON.serialize(branchRows), deletedCycleId).execute(null, branchRows);
        new ExamCourseResultImportBatch(JSON.serialize(branchRows), ctx.examCycleId).execute(null, branchRows);
        Test.stopTest();
    }

    @IsTest
    static void coversAdditionalExamTermResultBranches() {
        Integer emptyTermStartCount = 0;
        for (Map<String, Object> row : new ExamTermResultImportBatch('', null).start(null)) {
            emptyTermStartCount++;
        }
        System.assertEquals(0, emptyTermStartCount);
        new ExamTermResultImportBatch('[]', null).execute(null, new List<Map<String, Object>>());

        TestContextData ctx = createExamImportContext('Term Branches');
        Id cycleWithoutTermId = createExamCycle('Term Branches No Term', null);
        Id deletedCycleId = createDeletedExamCycleId();
        String missingStudentId = 'REG-MISSING-' + String.valueOf(Math.abs(Crypto.getRandomInteger()));

        List<Map<String, Object>> branchRows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'RowNumber' => '1',
                'Student Registration ID' => ctx.studentRegistrationId,
                'Status' => 'DefinitelyInvalidStatus'
            },
            new Map<String, Object>{
                'RowNumber' => '2',
                'Student Registration ID' => missingStudentId,
                'Status' => 'Active'
            }
        };

        Test.startTest();
        new ExamTermResultImportBatch(JSON.serialize(branchRows), cycleWithoutTermId).execute(null, branchRows);
        new ExamTermResultImportBatch(JSON.serialize(branchRows), deletedCycleId).execute(null, branchRows);
        new ExamTermResultImportBatch(JSON.serialize(branchRows), ctx.examCycleId).execute(null, branchRows);
        Test.stopTest();
    }

    private class TestContextData {
        Id examCycleId;
        String studentRegistrationId;
        Account institute;
        Contact student;
        AcademicTermEnrollment academicTermEnrollment;
        LearningCourse course;
        CourseOffering offering;
        CourseOfferingParticipant participant;
    }

    private static TestContextData createExamImportContext(String labelSuffix) {
        TestContextData ctx = new TestContextData();

        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY Exam ' + labelSuffix, '2040').create();
        AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(2040, '1', academicYear.Id).create();
        AcademicSession sessionRow = createSession('Session ' + labelSuffix, term.Id);
        ctx.examCycleId = createExamCycle('Cycle ' + labelSuffix, term.Id);
        ctx.institute = new KenTestDataFactory.AccountCreator('Institute ' + labelSuffix).create();
        ctx.student = createStudent(ctx.institute.Id, 'student.exam.' + labelSuffix.replace(' ', '').toLowerCase() + '@example.edu');
        ctx.studentRegistrationId = 'REG-' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        createStudentRole(ctx.student.Id, ctx.studentRegistrationId);
        ctx.academicTermEnrollment =
            new KenTestDataFactory.AcademicTermEnrollmentCreator(term.Id, ctx.student.Id, ctx.institute.Id).create();
        String randomSuffix = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        if (randomSuffix.length() > 6) {
            randomSuffix = randomSuffix.substring(0, 6);
        }
        ctx.course = createLearningCourse('Course ' + labelSuffix, 'EXAM-' + randomSuffix);
        ctx.offering = createOffering('Offering ' + labelSuffix, sessionRow.Id, ctx.course.Id, Decimal.valueOf('3'));
        ctx.participant = createParticipant(ctx.offering.Id, ctx.student.Id, ctx.institute.Id, ctx.academicTermEnrollment.Id);
        createEvaluationSchemaMapper(ctx.offering.Id, 'Internal', 'Regular');
        createEvaluationSchemaMapper(ctx.offering.Id, 'External', 'Regular');
        createEvaluationSchemaMapper(ctx.offering.Id, 'Re-Test', 'Retest');
        createEvaluationSchemaMapper(ctx.offering.Id, 'Supplementary', 'Retest');

        return ctx;
    }

    private static AcademicSession createSession(String name, Id termId) {
        AcademicSession sessionRow = new AcademicSession();
        sessionRow.Name = name;
        sessionRow.Type = KenConstantController.CADENCE_SEMESTER;
        sessionRow.Season = KenConstantController.SEASON_FALL;
        sessionRow.Sequence__c = '1';
        sessionRow.ClassStartDate = Date.today();
        sessionRow.AcademicTermId = termId;
        sessionRow.IsActive = true;
        insert sessionRow;
        return sessionRow;
    }

    private static LearningCourse createLearningCourse(String name, String courseNumber) {
        Learning learning = new KenTestDataFactory.LearningCreator(name + ' Learning').create();
        LearningCourse course = new LearningCourse();
        course.Name = name;
        course.CourseNumber = courseNumber;
        course.CourseType = 'Lecture';
        course.put('LearningId', learning.Id);
        insert course;
        return course;
    }

    private static CourseOffering createOffering(String name, Id sessionId, Id courseId, Decimal credit) {
        CourseOffering offering = new CourseOffering();
        Map<String, Schema.SObjectField> offeringFields = CourseOffering.SObjectType.getDescribe().fields.getMap();
        offering.Name = name;
        offering.AcademicSessionId = sessionId;
        offering.LearningCourseId = courseId;
        offering.IsActive = true;
        offering.StartDate = Date.newInstance(2040, 1, 1);
        offering.EndDate = Date.newInstance(2040, 3, 31);
        offering.Credit__c = credit;
        if (offeringFields.containsKey('EnrollmentCapacity')) {
            offering.put('EnrollmentCapacity', 50);
        }
        if (offeringFields.containsKey('WaitlistCapacity')) {
            offering.put('WaitlistCapacity', 10);
        }
        if (offeringFields.containsKey('WaitlistStatus')) {
            offering.put('WaitlistStatus', 'Open');
        }
        insert offering;
        return offering;
    }

    private static CourseOfferingParticipant createParticipant(Id offeringId, Id contactId, Id accountId, Id ateId) {
        CourseOfferingParticipant participant = new CourseOfferingParticipant();
        participant.CourseOfferingId = offeringId;
        participant.ParticipantContactId = contactId;
        participant.ParticipantAccountId = accountId;
        participant.AcademicTermEnrollmentId = ateId;
        if (CourseOfferingParticipant.SObjectType.getDescribe().fields.getMap().containsKey('ParticipationStatus')) {
            participant.ParticipationStatus = 'Enrolled';
        }
        if (CourseOfferingParticipant.SObjectType.getDescribe().fields.getMap().containsKey('ParticipantAffiliation')) {
            participant.put('ParticipantAffiliation', 'Student');
        }
        insert participant;
        return participant;
    }

    private static Contact createStudent(Id accountId, String email) {
        Contact student = new KenTestDataFactory.ContactCreator()
            .setAccount(accountId)
            .setLastName('Student')
            .create();
        student.Email = email;
        update student;
        return student;
    }

    private static void createStudentRole(Id contactId, String studentRegistrationId) {
        SObject role = Schema.getGlobalDescribe().get('ConstituentRole').newSObject();
        Map<String, Schema.SObjectField> fields = role.getSObjectType().getDescribe().fields.getMap();
        putIfField(role, fields, 'PersonId', contactId);
        putIfField(role, fields, 'RoleType', KenConstantController.ROLETYPE_STUDENT);
        putIfField(role, fields, 'Student_ID__c', studentRegistrationId);
        if (fields.containsKey('Status')) {
            putIfField(role, fields, 'Status', 'Active');
        }
        insert role;
    }

    private static Id createExamCycle(String name, Id academicTermId) {
        SObject examCycle = Schema.getGlobalDescribe().get('Ken_Exam_Cycle__c').newSObject();
        Map<String, Schema.SObjectField> fields = examCycle.getSObjectType().getDescribe().fields.getMap();
        putIfField(examCycle, fields, 'Name', name);
        putIfField(examCycle, fields, 'Ken_Academic_Term__c', academicTermId);
        if (fields.containsKey('Ken_Is_Active__c')) {
            putIfField(examCycle, fields, 'Ken_Is_Active__c', true);
        }
        insert examCycle;
        return (Id) examCycle.get('Id');
    }

    private static Id createDeletedExamCycleId() {
        Id examCycleId = createExamCycle('Deleted Cycle ' + String.valueOf(Math.abs(Crypto.getRandomInteger())), null);
        SObject examCycle = Schema.getGlobalDescribe().get('Ken_Exam_Cycle__c').newSObject();
        examCycle.put('Id', examCycleId);
        delete examCycle;
        return examCycleId;
    }

    private static void createEvaluationSchemaMapper(Id offeringId, String componentName, String examType) {
        SObject component = Schema.getGlobalDescribe().get('Ken_Evaluation_Component__c').newSObject();
        Map<String, Schema.SObjectField> componentFields = component.getSObjectType().getDescribe().fields.getMap();
        if (componentFields.containsKey('RecordTypeId')) {
            Id componentRecordTypeId = getRecordTypeId('Ken_Evaluation_Component__c', 'Evaluation_Component');
            if (componentRecordTypeId != null) {
                component.put('RecordTypeId', componentRecordTypeId);
            }
        }
        putIfField(component, componentFields, 'Name', componentName + ' ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
        putIfField(component, componentFields, 'Ken_Components__c', componentName);
        putIfField(component, componentFields, 'Ken_Exam_Type__c', examType);
        if (componentFields.containsKey('Ken_Is_Exam_Required__c')) {
            putIfField(component, componentFields, 'Ken_Is_Exam_Required__c', true);
        }
        insert component;

        SObject mapper = Schema.getGlobalDescribe().get('Ken_Course_Evaluation_Schema_Mapper__c').newSObject();
        Map<String, Schema.SObjectField> mapperFields = mapper.getSObjectType().getDescribe().fields.getMap();
        putIfField(mapper, mapperFields, 'Course_Offering__c', offeringId);
        putIfField(mapper, mapperFields, 'Ken_Evaluation_Component__c', component.get('Id'));
        insert mapper;
    }

    private static Id getRecordTypeId(String sobjectName, String developerName) {
        if (String.isBlank(sobjectName) || String.isBlank(developerName)) {
            return null;
        }
        List<RecordType> recordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = :sobjectName
            AND DeveloperName = :developerName
            LIMIT 1
        ];
        return recordTypes.isEmpty() ? null : recordTypes[0].Id;
    }

    private static void putIfField(SObject target, Map<String, Schema.SObjectField> fields, String fieldName, Object value) {
        if (target == null || fields == null || !fields.containsKey(fieldName) || value == null) {
            return;
        }
        Schema.DescribeFieldResult describeField = fields.get(fieldName).getDescribe();
        if (!describeField.isCreateable()) {
            return;
        }
        target.put(fieldName, value);
    }

    private static Boolean containsText(List<String> messages, String expected) {
        for (String message : messages) {
            if (message != null && message.contains(expected)) {
                return true;
            }
        }
        return false;
    }
}