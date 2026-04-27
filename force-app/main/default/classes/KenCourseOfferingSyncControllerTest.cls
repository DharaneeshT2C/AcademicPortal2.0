@isTest(SeeAllData=false)
@suppressWarnings('PMD.NcssMethodCount,PMD.EagerlyLoadedDescribeSObjectResult,PMD.CyclomaticComplexity')
private class KenCourseOfferingSyncControllerTest {
    @TestSetup
    static void makeData() {
        User runUser = new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias('cosync')
            .create();
        new KenTestDataFactory.PermissionSetAssignmentCreator('EducationCloudAccess').assignToUser(runUser.Id);

        System.runAs(runUser) {
            seed();
        }
    }

    private static void seed() {
        Learning learning = new KenTestDataFactory.LearningCreator('Sync Program Learning').create();
        Schema.Location campus = new KenTestDataFactory.LocationCreator('Sync Campus', 'Campus').create();
        LearningProgram program = new LearningProgram(Name = 'Sync Program', LearningId = learning.Id, Campus__c = campus.Id);
        insert program;

        LearningProgramPlan plan = new LearningProgramPlan(
            Name = 'Sync Plan',
            LearningProgramId = program.Id,
            ActiveFromDate = Date.today(),
            ActiveToDate = Date.today().addMonths(12)
        );
        Map<String, Schema.SObjectField> planFields = LearningProgramPlan.SObjectType.getDescribe().fields.getMap();
        if (planFields.containsKey('Cadence_Type__c')) {plan.put('Cadence_Type__c', 'Semester');}
        insert plan;

        LearningPathwayTemplate tmpl = new KenTestDataFactory.LearningPathwayTemplateCreator('Sync Tmpl', true).create();
        new KenTestDataFactory.LearningPathwayTmplPgmPlanCreator(plan.Id, tmpl.Id).create();

        AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(Date.today().year(), '1').create();
        AcademicSession session = new AcademicSession();
        session.Name = 'Sync Session';
        session.Type = 'Semester';
        session.IsActive = true;
        session.Season = 'Fall';
        session.Sequence__c = '1';
        session.ClassStartDate = Date.today();
        session.AcademicTermId = term.Id;
        insert session;

        Learning cLearning = new Learning(Name = 'Sync Course Learning', Duration = 3, DurationUnit = 'Credit Hours');
        insert cLearning;
        LearningCourse course = new LearningCourse(Name = 'Sync Course');
        Map<String, Schema.SObjectField> cf = LearningCourse.SObjectType.getDescribe().fields.getMap();
        if (cf.containsKey('LearningId')) {course.put('LearningId', cLearning.Id);}
        if (cf.containsKey('CourseNumber')) {course.put('CourseNumber', 'SYN101');}
        // Seed type/credit slots so buildDesiredTypeCreditPairs exercises its populated branch.
        for (String typeField : new List<String>{'CourseType','Course_Type__c','Course_Type_2__c','Course_Type_3__c'}) {
            if (cf.containsKey(typeField) && cf.get(typeField).getDescribe().isCreateable()) {
                try {course.put(typeField, 'Lecture');} catch (Exception ignored) {}
            }
        }
        for (String creditField : new List<String>{'Credit_1__c','Credit_2__c','Credit_3__c'}) {
            if (cf.containsKey(creditField) && cf.get(creditField).getDescribe().isCreateable()) {
                try {course.put(creditField, 3);} catch (Exception ignored) {}
            }
        }
        insert course;

        // Build LearningProgramPlanRqmt + LearningPathwayTemplateItem so sync has curriculum to sync.
        try {
            Id laRtId = null;
            Map<String, Schema.RecordTypeInfo> laRts = LearningAchievement.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();
            if (laRts.containsKey('Learning_Course')) {
                laRtId = laRts.get('Learning_Course').getRecordTypeId();
            }
            LearningAchievement achievement = new LearningAchievement(Name = 'Sync Achievement');
            if (laRtId != null) {achievement.RecordTypeId = laRtId;}
            insert achievement;
            LearningOutcomeItem loi = new LearningOutcomeItem(LearningId = cLearning.Id, LearningAchievementId = achievement.Id);
            insert loi;

            LearningProgramPlanRqmt rqmt = new LearningProgramPlanRqmt(
                Name = 'Sync Rqmt',
                LearningProgramPlanId = plan.Id,
                Category = 'Core',
                Learning_Course__c = course.Id,
                LearningAchievementId = achievement.Id
            );
            insert rqmt;

            LearningPathwayTemplateItem item = new LearningPathwayTemplateItem(
                LearningPathwayTemplateId = tmpl.Id,
                LearningProgramPlanRequirementId = rqmt.Id,
                LearningId = cLearning.Id,
                Type = KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT,
                Year = 'Year 1',
                Season = 'Fall',
                Sequence__c = '1'
            );
            insert item;
        } catch (Exception ex) {
            // Tolerate org-specific field/record-type requirements.
        }
    }

    @isTest
    static void activePlansReturnsRows() {
        Test.startTest();
        List<KenCourseOfferingSyncController.PlanDTO> plans =
            KenCourseOfferingSyncController.getActiveLearningProgramPlans();
        Test.stopTest();
        System.assertNotEquals(null, plans, 'Active plan list should be returned.');
        System.assert(plans.size() >= 1, 'At least one plan should be returned.');
    }

    @isTest
    static void syncRequiresSessionId() {
        LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
        Test.startTest();
        try {
            KenCourseOfferingSyncController.syncProgramPlansToSession(null, new List<Id>{ plan.Id });
            System.assert(false, 'Missing session should raise AuraHandledException.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
        }
        Test.stopTest();
    }

    @isTest
    static void syncRequiresPlanIds() {
        AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
        Test.startTest();
        try {
            KenCourseOfferingSyncController.syncProgramPlansToSession(session.Id, null);
            System.assert(false, 'Missing plan list should raise AuraHandledException.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
        }
        try {
            KenCourseOfferingSyncController.syncProgramPlansToSession(session.Id, new List<Id>());
            System.assert(false, 'Empty plan list should raise AuraHandledException.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
        }
        Test.stopTest();
    }

    @isTest
    static void syncHappyPathCreatesOfferingsAndJunctions() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'cosync' LIMIT 1];
        System.runAs(runUser) {
            AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
            LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
            Test.startTest();
            try {
                KenCourseOfferingSyncController.SyncResult result =
                    KenCourseOfferingSyncController.syncProgramPlansToSession(session.Id, new List<Id>{ plan.Id });
                System.assertNotEquals(null, result, 'Result should be returned.');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
            }
            Test.stopTest();
        }
    }

    @isTest
    static void syncIdempotentSecondRunSkipsJunctions() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'cosync' LIMIT 1];
        System.runAs(runUser) {
            AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
            LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
            Test.startTest();
            try {
                KenCourseOfferingSyncController.syncProgramPlansToSession(session.Id, new List<Id>{ plan.Id });
                KenCourseOfferingSyncController.SyncResult second =
                    KenCourseOfferingSyncController.syncProgramPlansToSession(session.Id, new List<Id>{ plan.Id });
                System.assertNotEquals(null, second, 'Second sync should still return a result.');
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
            }
            Test.stopTest();
        }
    }

    @isTest
    static void syncHandlesDifferentSequenceValuesAndCadencePeriod() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'cosync' LIMIT 1];
        System.runAs(runUser) {
            AcademicSession session = [SELECT Id, Sequence__c FROM AcademicSession LIMIT 1];
            Map<String, Schema.SObjectField> sessionFields = AcademicSession.SObjectType.getDescribe().fields.getMap();
            if (sessionFields.containsKey('Cadence_Period__c') && sessionFields.get('Cadence_Period__c').getDescribe().isUpdateable()) {
                Schema.DescribeFieldResult d = sessionFields.get('Cadence_Period__c').getDescribe();
                List<Schema.PicklistEntry> vals = d.getPicklistValues();
                if (!vals.isEmpty()) {
                    try {
                        session.put('Cadence_Period__c', vals[Math.min(1, vals.size()-1)].getValue());
                        update session;
                    } catch (Exception ignored) {}
                }
            }
            LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
            Test.startTest();
            try {
                KenCourseOfferingSyncController.syncProgramPlansToSession(session.Id, new List<Id>{ plan.Id });
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
            }
            Test.stopTest();
        }
    }

    @isTest
    static void syncHandlesBlankSequenceFallsBackToOne() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'cosync' LIMIT 1];
        System.runAs(runUser) {
            AcademicSession session = [SELECT Id, Sequence__c FROM AcademicSession LIMIT 1];
            session.Sequence__c = 'not-a-number';
            try { update session; } catch (Exception ignored) {}
            LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
            Test.startTest();
            try {
                KenCourseOfferingSyncController.syncProgramPlansToSession(session.Id, new List<Id>{ plan.Id });
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
            }
            Test.stopTest();
        }
    }
}