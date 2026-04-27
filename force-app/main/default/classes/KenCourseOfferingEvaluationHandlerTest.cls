/**
 * Test class for:
 *  - KenCourseOfferingEvaluationHandler
 *  - KenEvaluationGradeQueueable
 *  - CourseOfferingTrigger (after-context evaluation-schema path)
 */
@isTest
private class KenCourseOfferingEvaluationHandlerTest {

    // ── Record-Type IDs ──────────────────────────────────────────────────────
    private static Id parentEvalCompRtId {
        get {
            return Schema.SObjectType.Ken_Evaluation_Component__c
                .getRecordTypeInfosByDeveloperName()
                .get('Evaluation_Component').getRecordTypeId();
        }
    }

    private static Id childEvalCompRtId {
        get {
            return Schema.SObjectType.Ken_Evaluation_Component__c
                .getRecordTypeInfosByDeveloperName()
                .get('Evaluation_Sub_Component').getRecordTypeId();
        }
    }

    // ── Test data setup ──────────────────────────────────────────────────────
    @testSetup
    static void setupData() {

        Account acct = new Account(Name = 'Test Institution');
        insert acct;

        Contact student = new Contact(
            FirstName = 'Test',
            LastName  = 'Student',
            AccountId = acct.Id
        );
        insert student;

        Ken_Evaluation_Schema__c schema = new Ken_Evaluation_Schema__c(
            Name = 'Test Evaluation Schema'
        );
        insert schema;

        Ken_Evaluation_Component__c parentComp = new Ken_Evaluation_Component__c(
            RecordTypeId                 = parentEvalCompRtId,
            Ken_Consider_for_Pass_Fail__c = false,
            Ken_Is_Exam_Required__c      = false
        );
        insert parentComp;

        List<Ken_Evaluation_Component__c> children = new List<Ken_Evaluation_Component__c>{
            new Ken_Evaluation_Component__c(
                RecordTypeId                       = childEvalCompRtId,
                Ken_Parent_Evaluation_Component__c = parentComp.Id,
                Ken_Consider_for_Pass_Fail__c      = false,
                Ken_Is_Exam_Required__c            = false
            ),
            new Ken_Evaluation_Component__c(
                RecordTypeId                       = childEvalCompRtId,
                Ken_Parent_Evaluation_Component__c = parentComp.Id,
                Ken_Consider_for_Pass_Fail__c      = false,
                Ken_Is_Exam_Required__c            = false
            )
        };
        insert children;
    }

    // ── Helper: create a CourseOffering without schema set ───────────────────
    private static CourseOffering createCourseOffering(String label) {
        Learning learning = new Learning(Name = 'Test Learning ' + label);
        insert learning;

        LearningCourse lc = new LearningCourse(
            Name       = 'Test Learning Course ' + label,
            LearningId = learning.Id
        );
        insert lc;

        CourseOffering co = new CourseOffering(
            Name             = 'Test Offering ' + label,
            LearningCourseId = lc.Id,
            StartDate        = DateTime.now(),
            EndDate          = DateTime.now().addDays(90)
        );
        insert co;
        return co;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 1 — full flow: trigger → handler → queueable → grades created
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testEvaluationSchemaUpdateCreatesGrades() {

        Contact student = [SELECT Id FROM Contact LIMIT 1];
        Ken_Evaluation_Schema__c schema = [SELECT Id FROM Ken_Evaluation_Schema__c LIMIT 1];

        Ken_Evaluation_Component__c parentComp = [
            SELECT Id FROM Ken_Evaluation_Component__c
            WHERE  Ken_Parent_Evaluation_Component__c = null
            LIMIT 1
        ];

        CourseOffering co = createCourseOffering('A');

        insert new CourseOfferingParticipant(
            CourseOfferingId      = co.Id,
            ParticipantContactId  = student.Id
        );

        insert new Ken_Course_Evaluation_Schema_Mapper__c(
            Course_Offering__c           = co.Id,
            Ken_Evaluation_Component__c  = parentComp.Id
        );

        Test.startTest();
        co.Ken_Evaluation_Schema__c = schema.Id;
        update co;
        Test.stopTest();

        List<CourseOfrPtcpActvtyGrd> parentGrades = [
            SELECT Id
            FROM   CourseOfrPtcpActvtyGrd
            WHERE  Ken_Evaluation_Component__c = :parentComp.Id
        ];
        System.assertEquals(1, parentGrades.size(), 'Expected 1 parent grade');

        Integer totalGrades = [SELECT COUNT() FROM CourseOfrPtcpActvtyGrd];
        System.assertEquals(3, totalGrades, 'Expected 1 parent + 2 child grades');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 2 — CO inserted/updated with no schema → handler skips
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testNoSchemaChangeSkips() {

        Test.startTest();
        CourseOffering co = createCourseOffering('B');
        update co;
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM CourseOfrPtcpActvtyGrd],
            'No grades should be created when schema is not set'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 3 — schema set but no participants/mappers → handler short-circuits
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testSchemaSetWithNoParticipants() {

        Ken_Evaluation_Schema__c schema = [SELECT Id FROM Ken_Evaluation_Schema__c LIMIT 1];

        CourseOffering co = createCourseOffering('C');

        Test.startTest();
        co.Ken_Evaluation_Schema__c = schema.Id;
        update co;
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM CourseOfrPtcpActvtyGrd],
            'No grades should be created without participants'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 4 — duplicate-prevention: call processEvaluationGrades twice
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testDuplicatePrevention() {

        Contact student = [SELECT Id FROM Contact LIMIT 1];

        Ken_Evaluation_Component__c parentComp = [
            SELECT Id FROM Ken_Evaluation_Component__c
            WHERE  Ken_Parent_Evaluation_Component__c = null
            LIMIT 1
        ];

        CourseOffering co = createCourseOffering('D');

        insert new CourseOfferingParticipant(
            CourseOfferingId      = co.Id,
            ParticipantContactId  = student.Id
        );

        insert new Ken_Course_Evaluation_Schema_Mapper__c(
            Course_Offering__c           = co.Id,
            Ken_Evaluation_Component__c  = parentComp.Id
        );

        Set<Id> coIds = new Set<Id>{ co.Id };

        Test.startTest();
        KenCourseOfferingEvaluationHandler.processEvaluationGrades(coIds);
        KenCourseOfferingEvaluationHandler.processEvaluationGrades(coIds); // duplicate run
        Test.stopTest();

        Integer totalGrades = [SELECT COUNT() FROM CourseOfrPtcpActvtyGrd];
        System.assertEquals(
            3, totalGrades,
            'Duplicates should be skipped — 1 parent + 2 child grades only'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 5 — null / empty input paths for handler and queueable
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testEmptyAndNullInputs() {
        Test.startTest();
        KenCourseOfferingEvaluationHandler.processEvaluationGrades(null);
        KenCourseOfferingEvaluationHandler.processEvaluationGrades(new Set<Id>());
        System.enqueueJob(new KenEvaluationGradeQueueable(new Set<Id>()));
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 6 — Queueable chains when input size exceeds CHUNK_SIZE
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testQueueableChunkChaining() {

        // Build more CourseOfferings than CHUNK_SIZE so the Queueable
        // processes the first chunk and re-enqueues the remainder.
        Integer total = KenEvaluationGradeQueueable.CHUNK_SIZE + 2;

        Learning learning = new Learning(Name = 'Bulk Learning');
        insert learning;

        LearningCourse lc = new LearningCourse(
            Name       = 'Bulk Learning Course',
            LearningId = learning.Id
        );
        insert lc;

        List<CourseOffering> cos = new List<CourseOffering>();
        for (Integer i = 0; i < total; i++) {
            cos.add(new CourseOffering(
                Name             = 'Bulk Offering ' + i,
                LearningCourseId = lc.Id,
                StartDate        = DateTime.now(),
                EndDate          = DateTime.now().addDays(30)
            ));
        }
        insert cos;

        Set<Id> coIds = (new Map<Id, CourseOffering>(cos)).keySet();

        Test.startTest();
        System.enqueueJob(new KenEvaluationGradeQueueable(coIds));
        Test.stopTest();

        // No assertions — this test is for coverage of the chunk/chain branches.
    }
}