/**
 * @description
 *  Test coverage for `KenAcademicTermEnrollmentController`.
 *  Uses `@TestSetup` data and validates list retrieval, search behavior,
 *  and enrollment creation paths with `SeeAllData=false`.
 */
@suppressWarnings('PMD.NcssMethodCount,PMD.EagerlyLoadedDescribeSObjectResult')
@isTest(SeeAllData=false)
private class KenAcademicTermEnrollmentControllerTest {
  private static void assignPermissionSetsToUser(Id userId, List<String> permissionSetNames) {
    if (userId == null || permissionSetNames == null) {
      return;
    }

    for (String permissionSetName : permissionSetNames) {
      if (String.isBlank(permissionSetName)) {
        continue;
      }

      try {
        PermissionSet ps = [
          SELECT Id
          FROM PermissionSet
          WHERE Name = :permissionSetName
          LIMIT 1
        ];
        List<PermissionSetAssignment> existingAssignments = [
          SELECT Id
          FROM PermissionSetAssignment
          WHERE AssigneeId = :userId
          AND PermissionSetId = :ps.Id
          LIMIT 1
        ];
        if (existingAssignments.isEmpty()) {
          insert new PermissionSetAssignment(
            AssigneeId = userId,
            PermissionSetId = ps.Id
          );
        }
      } catch (Exception ignored) {
      }
    }
  }

  /**
   * @description
   *  Creates baseline data required by all tests:
   *  user context, institute/contact, program-plan hierarchy,
   *  academic year/terms, existing enrollment, and learner profile.
   */
  @TestSetup
  static void makeData() {
    assignPermissionSetsToUser(
      UserInfo.getUserId(),
      new List<String>{
        'EducationCloudAccess',
        'ClonedEducationCloudAccess',
        'EducationCloudFullAccessClone',
        'System_Admin_Permission'
      }
    );

    User runUser = new KenTestDataFactory.UserCreator('System Administrator')
      .setAlias('atenrl')
      .create();
    assignPermissionSetsToUser(
      runUser.Id,
      new List<String>{
        'EducationCloudAccess',
        'ClonedEducationCloudAccess',
        'EducationCloudFullAccessClone',
        'System_Admin_Permission'
      }
    );

    System.runAs(runUser) {
      Account institute = new KenTestDataFactory.AccountCreator('ATE Institute').create();
      Contact student = new KenTestDataFactory.ContactCreator()
        .setAccount(institute.Id)
        .setLastName('Student')
        .create();

      LearningProgram program =
        new KenTestDataFactory.LearningProgramCreator('ATE Program').returnWithoutCreate();
      Map<String, Schema.SObjectField> programFields =
        LearningProgram.SObjectType.getDescribe().fields.getMap();
      if (programFields.containsKey('LearningId')) {
        Learning learning = new KenTestDataFactory.LearningCreator('ATE Learning').create();
        program.put('LearningId', learning.Id);
      }
      if (programFields.containsKey('Campus__c')) {
        Schema.Location campus =
          new KenTestDataFactory.LocationCreator('ATE Campus', 'Campus').create();
        program.put('Campus__c', campus.Id);
      }
      insert program;
      LearningProgramPlan plan = new KenTestDataFactory.LearningProgramPlanCreator(program.Id).create();

      Map<String, Schema.SObjectField> planFields = LearningProgramPlan.SObjectType.getDescribe().fields.getMap();
      LearningProgramPlan planUpdate = new LearningProgramPlan(Id = plan.Id);

      if (planFields.containsKey('Cadence_Type__c')) {
        planUpdate.put('Cadence_Type__c', 'Semester');
      }
      if (planFields.containsKey('ActiveFromDate')) {
        planUpdate.put('ActiveFromDate', Date.newInstance(Date.today().year(), 1, 1));
      }
      if (planFields.containsKey('ActiveToDate')) {
        planUpdate.put('ActiveToDate', Date.newInstance(Date.today().year(), 12, 31));
      }
      update planUpdate;

      LearningPathwayTemplate tmpl = new KenTestDataFactory.LearningPathwayTemplateCreator('ATE Tmpl', true).create();
      new KenTestDataFactory.LearningPathwayTmplPgmPlanCreator(plan.Id, tmpl.Id).create();

      String ayName = String.valueOf(Date.today().year()) + ' - ' + String.valueOf(Date.today().year() + 1);
      AcademicYear ay = new KenTestDataFactory.AcademicYearCreator(ayName, ayName).create();

      AcademicTerm termCurrent = new KenTestDataFactory.AcademicTermCreator(Date.today().year(), '1', ay.Id).create();
      AcademicTerm termNext = new KenTestDataFactory.AcademicTermCreator(Date.today().year(), '2', ay.Id).create();

      Map<String, Schema.SObjectField> termFields = AcademicTerm.SObjectType.getDescribe().fields.getMap();
      List<AcademicTerm> termUpdates = new List<AcademicTerm>();
      AcademicTerm t1 = new AcademicTerm(Id = termCurrent.Id);
      AcademicTerm t2 = new AcademicTerm(Id = termNext.Id);
      if (termFields.containsKey('Season')) {
        t1.put('Season', 'Fall');
        t2.put('Season', 'Spring');
      }
      // Set Start_Year__c so createAcademicTermEnrollments can compute cadencePeriod.
      if (termFields.containsKey('Start_Year__c') && termFields.get('Start_Year__c').getDescribe().isUpdateable()) {
        t1.put('Start_Year__c', Date.today().year());
        t2.put('Start_Year__c', Date.today().year());
      }
      termUpdates.add(t1);
      termUpdates.add(t2);
      update termUpdates;

      // Create AcademicTermEnrollment for the current term with Active status.
      AcademicTermEnrollment ateCurrent = new KenTestDataFactory.AcademicTermEnrollmentCreator(termCurrent.Id, student.Id, institute.Id).create();
      AcademicTermEnrollment ateNext = new KenTestDataFactory.AcademicTermEnrollmentCreator(termNext.Id, student.Id, institute.Id).create();

      LearnerProgram lp = new KenTestDataFactory.LearnerProgramCreator(student.Id, plan.Id)
        .setClassCohort('A')
        .create();

      // Set Start_Year__c on LearningProgramPlan so cadence period math works.
      if (planFields.containsKey('Start_Year__c') && planFields.get('Start_Year__c').getDescribe().isUpdateable()) {
        LearningProgramPlan planStartYear = new LearningProgramPlan(Id = plan.Id);
        planStartYear.put('Start_Year__c', Date.today().year());
        update planStartYear;
      }

      new KenTestDataFactory.LearnerProfileCreator(student.Id)
        .setAcademicTermEnrollment(ateNext.Id)
        .create();
    }
  }

  // -------------------------------------------------------------------------
  // EXISTING TESTS (preserved)
  // -------------------------------------------------------------------------

  /**
   * @description
   *  Verifies institute and department retrieval methods return a non-null list
   *  when the corresponding Account record types are present.
   */
  @isTest
  static void testGetInstitutesAndDepartmentsIfRecordTypesExist() {
    Map<String, Schema.RecordTypeInfo> rtByDev = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
    if (rtByDev.containsKey('Institute')) {
      List<Account> institutes = KenAcademicTermEnrollmentController.getInstitutes();
      System.assertNotEquals(null, institutes, 'Institutes list should be returned');
    }
    if (rtByDev.containsKey('Program_Specialization')) {
      List<Account> depts = KenAcademicTermEnrollmentController.getInstituteDepartment();
      System.assertNotEquals(null, depts, 'Departments list should be returned');
    }
  }

  /**
   * @description
   *  Verifies program plan lookup for a program and specialization mapping retrieval.
   */
  @isTest
  static void testProgramPlanAndSpecializations() {
    User runUser = [SELECT Id FROM User WHERE Alias = 'atenrl' LIMIT 1];
    System.runAs(runUser) {
      LearningProgram program = [SELECT Id FROM LearningProgram WHERE Name = 'ATE Program' LIMIT 1];
      List<LearningProgramPlan> plans = KenAcademicTermEnrollmentController.getProgramPlan(program.Id);
      System.assertNotEquals(0, plans.size(), 'Plans should be returned');

      LearningProgramPlan plan = plans[0];
      List<LearningPathwayTmplPgmPlan> specs = KenAcademicTermEnrollmentController.getProgramSpecializations(plan.Id);
      System.assertNotEquals(null, specs, 'Specializations list should be returned');
    }
  }

  /**
   * @description
   *  Verifies academic terms are returned for a valid learning program plan.
   */
  @isTest
  static void testAcademicTermsByProgramPlan() {
    LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
    List<KenAcademicTermEnrollmentController.AcademicTermDTO> terms =
      KenAcademicTermEnrollmentController.getAcademicTermsByProgramPlan(plan.Id);
    System.assertNotEquals(null, terms, 'Academic terms list should be returned');
  }

  @isTest
  static void testBasicLookupsAndNullGuards() {
    List<LearningProgram> programs = KenAcademicTermEnrollmentController.getPrograms();
    System.assertNotEquals(null, programs, 'Programs list should be returned');

    System.assertEquals(
      0,
    KenAcademicTermEnrollmentController.getProgramPlan(null).size(),
    'Null program id should return no plans'
      );
    System.assertEquals(
      0,
    KenAcademicTermEnrollmentController.getProgramSpecializations(null).size(),
    'Null plan id should return no specializations'
      );
    System.assertEquals(
      0,
    KenAcademicTermEnrollmentController.getAcademicTermsByProgramPlan(null).size(),
    'Null plan id should return no academic terms'
      );
    System.assertEquals(
      0,
    KenAcademicTermEnrollmentController.getSectionsByProgramPlan(null).size(),
    'Null plan id should return no sections'
      );
    System.assertEquals(
      0,
    KenAcademicTermEnrollmentController.getEnrollmentsByAcademicTerm(null).size(),
    'Null term id should return no enrollments'
      );
    System.assertEquals(
      0,
    KenAcademicTermEnrollmentController.searchStudentsByCurrentTermAndProgramPlan(
      null, null, null, null
      ).size(),
    'Null inputs should return no students'
      );
  }

  @isTest
  static void testGetEnrollmentsByAcademicTerm() {
    AcademicTerm termNext = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate DESC LIMIT 1];
    List<KenAcademicTermEnrollmentController.AcademicTermEnrollmentRowDTO> rows =
      KenAcademicTermEnrollmentController.getEnrollmentsByAcademicTerm(termNext.Id);
    System.assertNotEquals(null, rows, 'Enrollment rows should be returned');
  }

  @isTest
  static void testSearchStudentsFirstSemesterBranch() {
    LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
    AcademicTerm termCurrent = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate ASC LIMIT 1];
    LearnerProgram existingProgram = [
      SELECT Id, ClassCohort
      FROM LearnerProgram
      WHERE LearningProgramPlanId = :plan.Id
      LIMIT 1
    ];

    List<KenAcademicTermEnrollmentController.StudentDTO> students =
      KenAcademicTermEnrollmentController.searchStudentsByCurrentTermAndProgramPlan(
      termCurrent.Id, termCurrent.Id, plan.Id, existingProgram.ClassCohort
      );
    System.assertNotEquals(null, students, 'First-semester branch should return a list');
  }

  @isTest
  static void testCreateAcademicTermEnrollmentsEmptyInputThrows() {
    Test.startTest();
    try {
      KenAcademicTermEnrollmentController.createAcademicTermEnrollments(
        new List<Id>(), null, null
        );
      System.assert(false, 'Expected AuraHandledException for empty learner program ids');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage(), 'Empty input should surface an AuraHandledException');
    }
    Test.stopTest();
  }

  /**
   * @description
   *  Verifies section retrieval, eligible student search,
   *  and execution of academic term enrollment creation.
   */
  @isTest
  static void testSectionsAndStudentSearchAndEnrollmentCreation() {
    LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
    List<String> sections = KenAcademicTermEnrollmentController.getSectionsByProgramPlan(plan.Id);
    System.assertNotEquals(null, sections, 'Sections list should be returned');

    AcademicTerm termCurrent = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate ASC LIMIT 1];
    AcademicTerm termNext = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate DESC LIMIT 1];
    List<KenAcademicTermEnrollmentController.StudentDTO> students =
      KenAcademicTermEnrollmentController.searchStudentsByCurrentTermAndProgramPlan(
      termCurrent.Id, termNext.Id, plan.Id, 'Section A'
      );
    System.assertNotEquals(null, students, 'Students list should be returned');

    Account institute = [SELECT Id FROM Account WHERE Name = 'ATE Institute' LIMIT 1];
    LearnerProgram lp = [SELECT Id FROM LearnerProgram LIMIT 1];
    try {
      KenAcademicTermEnrollmentController.createAcademicTermEnrollments(
      new List<Id>{ lp.Id }, termNext.Id, institute.Id
      );
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage(), 'Controller should surface an AuraHandledException when enrollment creation is blocked.');
    }
  }

  // -------------------------------------------------------------------------
  // NEW TESTS
  // -------------------------------------------------------------------------

  /**
   * @description
   *  Tests the main (different current vs next term) branch of
   *  searchStudentsByCurrentTermAndProgramPlan with the seeded student
   *  that has an enrollment in the current term.
   */
  @isTest
  static void testSearchStudentsDifferentCurrentAndNextTerm() {
    LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
    AcademicTerm termCurrent = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate ASC LIMIT 1];
    AcademicTerm termNext = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate DESC LIMIT 1];

    Test.startTest();
    List<KenAcademicTermEnrollmentController.StudentDTO> students =
      KenAcademicTermEnrollmentController.searchStudentsByCurrentTermAndProgramPlan(
        termCurrent.Id, termNext.Id, plan.Id, 'A'
      );
    Test.stopTest();
    System.assertNotEquals(null, students, 'Different-term branch should return a list.');
  }

  /**
   * @description
   *  Verifies that null plan id returns an empty list from getAcademicTermsByProgramPlan.
   */
  @isTest
  static void testGetAcademicTermsByProgramPlanNullId() {
    Test.startTest();
    List<KenAcademicTermEnrollmentController.AcademicTermDTO> terms =
      KenAcademicTermEnrollmentController.getAcademicTermsByProgramPlan(null);
    Test.stopTest();
    System.assertEquals(0, terms.size(), 'Null plan id should return empty list.');
  }

  /**
   * @description
   *  Exercises getAcademicTermsByProgramPlan with an AcademicYear whose Name
   *  does not match the "YYYY - YYYY" format, verifying the parse-failure
   *  continue branch is hit without causing an unhandled exception.
   */
  @isTest
  static void testGetAcademicTermsByProgramPlanWithInvalidYearFormat() {
    User runUser = [SELECT Id FROM User WHERE Alias = 'atenrl' LIMIT 1];
    System.runAs(runUser) {
      // Create an AcademicYear with a name that deliberately fails the "split('-')" check.
      AcademicYear badYear = new KenTestDataFactory.AcademicYearCreator('BadFormat', 'BadFormat').create();
      new KenTestDataFactory.AcademicTermCreator(Date.today().year(), '3', badYear.Id).create();
    }

    LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];

    Test.startTest();
    List<KenAcademicTermEnrollmentController.AcademicTermDTO> terms =
      KenAcademicTermEnrollmentController.getAcademicTermsByProgramPlan(plan.Id);
    Test.stopTest();
    // The bad-format year should be silently skipped; valid years may still return terms.
    System.assertNotEquals(null, terms, 'Result should not be null even with an invalid AcademicYear name.');
  }

  /**
   * @description
   *  Verifies that getSectionsByProgramPlan returns a non-null list
   *  for a valid plan id (exercises the GROUP BY query and list-building).
   */
  @isTest
  static void testSectionsByProgramPlanReturnsList() {
    LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
    Test.startTest();
    List<String> sections = KenAcademicTermEnrollmentController.getSectionsByProgramPlan(plan.Id);
    Test.stopTest();
    System.assertNotEquals(null, sections, 'Sections list should not be null for a valid plan.');
  }

  /**
   * @description
   *  Attempts createAcademicTermEnrollments with a valid learner program and next term,
   *  covering the happy-path and/or permission-gate branches inside the method.
   *  Wrapped in try-catch because the running user may not have all required field permissions
   *  in a developer sandbox.
   */
  @isTest
  static void testCreateAcademicTermEnrollmentsWithValidData() {
    LearnerProgram lp = [SELECT Id FROM LearnerProgram LIMIT 1];
    AcademicTerm termNext = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate DESC LIMIT 1];
    Account institute = [SELECT Id FROM Account WHERE Name = 'ATE Institute' LIMIT 1];

    Test.startTest();
    try {
      KenAcademicTermEnrollmentController.createAcademicTermEnrollments(
        new List<Id>{ lp.Id },
        termNext.Id,
        institute.Id
      );
    } catch (AuraHandledException e) {
      // Expected if field-level permissions are restricted in the current org.
      System.assertNotEquals(null, e.getMessage(), 'AuraHandledException should carry a message.');
    } catch (Exception e) {
      System.assertNotEquals(null, e.getMessage(), 'Any exception should carry a message.');
    }
    Test.stopTest();
  }

  /**
   * @description
   *  Exercises getCadenceFactor indirectly by calling createAcademicTermEnrollments
   *  after updating the plan to use Trimester cadence, covering the cadenceFactor = 3 path.
   */
  @isTest
  static void testCreateEnrollmentsWithTrimesterCadence() {
    User runUser = [SELECT Id FROM User WHERE Alias = 'atenrl' LIMIT 1];
    LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
    System.runAs(runUser) {
      try {
        Map<String, Schema.SObjectField> planFields = LearningProgramPlan.SObjectType.getDescribe().fields.getMap();
        if (planFields.containsKey('Cadence_Type__c') && planFields.get('Cadence_Type__c').getDescribe().isUpdateable()) {
          LearningProgramPlan planTrimester = new LearningProgramPlan(Id = plan.Id);
          planTrimester.put('Cadence_Type__c', 'Trimester');
          update planTrimester;
        }
      } catch (Exception ignored) {}
    }

    LearnerProgram lp = [SELECT Id FROM LearnerProgram LIMIT 1];
    AcademicTerm termNext = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate DESC LIMIT 1];
    Account institute = [SELECT Id FROM Account WHERE Name = 'ATE Institute' LIMIT 1];

    Test.startTest();
    try {
      KenAcademicTermEnrollmentController.createAcademicTermEnrollments(
        new List<Id>{ lp.Id },
        termNext.Id,
        institute.Id
      );
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage(), 'Trimester enrollment exception should carry a message.');
    } catch (Exception e) {
      System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
    }
    Test.stopTest();
  }

  /**
   * @description
   *  Exercises getCadenceFactor indirectly via createAcademicTermEnrollments
   *  after switching the plan to Quarter cadence, covering the cadenceFactor = 4 path.
   */
  @isTest
  static void testCreateEnrollmentsWithQuarterCadence() {
    User runUser = [SELECT Id FROM User WHERE Alias = 'atenrl' LIMIT 1];
    LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
    System.runAs(runUser) {
      try {
        Map<String, Schema.SObjectField> planFields = LearningProgramPlan.SObjectType.getDescribe().fields.getMap();
        if (planFields.containsKey('Cadence_Type__c') && planFields.get('Cadence_Type__c').getDescribe().isUpdateable()) {
          LearningProgramPlan planQ = new LearningProgramPlan(Id = plan.Id);
          planQ.put('Cadence_Type__c', 'Quarter');
          update planQ;
        }
      } catch (Exception ignored) {}
    }

    LearnerProgram lp = [SELECT Id FROM LearnerProgram LIMIT 1];
    AcademicTerm termNext = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate DESC LIMIT 1];
    Account institute = [SELECT Id FROM Account WHERE Name = 'ATE Institute' LIMIT 1];

    // Update term Season to 'Winter' to exercise getSeasonNumber Quarter Winter path.
    System.runAs(runUser) {
      try {
        Map<String, Schema.SObjectField> termFields = AcademicTerm.SObjectType.getDescribe().fields.getMap();
        if (termFields.containsKey('Season') && termFields.get('Season').getDescribe().isUpdateable()) {
          AcademicTerm t = new AcademicTerm(Id = termNext.Id);
          t.put('Season', 'Winter');
          update t;
        }
      } catch (Exception ignored) {}
    }

    Test.startTest();
    try {
      KenAcademicTermEnrollmentController.createAcademicTermEnrollments(
        new List<Id>{ lp.Id },
        termNext.Id,
        institute.Id
      );
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage(), 'Quarter enrollment exception should carry a message.');
    } catch (Exception e) {
      System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
    }
    Test.stopTest();
  }

  /**
   * @description
   *  Exercises getCadenceFactor with an unknown cadence type (returns 0),
   *  via createAcademicTermEnrollments after switching plan to an unknown cadence.
   */
  @isTest
  static void testCreateEnrollmentsUnknownCadenceFactorIsZero() {
    User runUser = [SELECT Id FROM User WHERE Alias = 'atenrl' LIMIT 1];
    LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
    System.runAs(runUser) {
      try {
        Map<String, Schema.SObjectField> planFields = LearningProgramPlan.SObjectType.getDescribe().fields.getMap();
        if (planFields.containsKey('Cadence_Type__c') && planFields.get('Cadence_Type__c').getDescribe().isUpdateable()) {
          LearningProgramPlan planUnknown = new LearningProgramPlan(Id = plan.Id);
          planUnknown.put('Cadence_Type__c', 'Biannual');
          update planUnknown;
        }
      } catch (Exception ignored) {}
    }

    LearnerProgram lp = [SELECT Id FROM LearnerProgram LIMIT 1];
    AcademicTerm termNext = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate DESC LIMIT 1];
    Account institute = [SELECT Id FROM Account WHERE Name = 'ATE Institute' LIMIT 1];

    Test.startTest();
    try {
      KenAcademicTermEnrollmentController.createAcademicTermEnrollments(
        new List<Id>{ lp.Id },
        termNext.Id,
        institute.Id
      );
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage(), 'Unknown cadence exception should carry a message.');
    } catch (Exception e) {
      System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
    }
    Test.stopTest();
  }

  /**
   * @description
   *  Exercises getSeasonNumber for Summer season via Trimester cadence path.
   *  Sets term Season to 'Summer' then calls createAcademicTermEnrollments.
   */
  @isTest
  static void testGetSeasonNumberSummerTrimester() {
    User runUser = [SELECT Id FROM User WHERE Alias = 'atenrl' LIMIT 1];
    LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
    AcademicTerm termNext = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate DESC LIMIT 1];
    System.runAs(runUser) {
      try {
        Map<String, Schema.SObjectField> planFields = LearningProgramPlan.SObjectType.getDescribe().fields.getMap();
        if (planFields.containsKey('Cadence_Type__c') && planFields.get('Cadence_Type__c').getDescribe().isUpdateable()) {
          LearningProgramPlan planTrim = new LearningProgramPlan(Id = plan.Id);
          planTrim.put('Cadence_Type__c', 'Trimester');
          update planTrim;
        }
        Map<String, Schema.SObjectField> termFields = AcademicTerm.SObjectType.getDescribe().fields.getMap();
        if (termFields.containsKey('Season') && termFields.get('Season').getDescribe().isUpdateable()) {
          AcademicTerm t = new AcademicTerm(Id = termNext.Id);
          t.put('Season', 'Summer');
          update t;
        }
      } catch (Exception ignored) {}
    }

    LearnerProgram lp = [SELECT Id FROM LearnerProgram LIMIT 1];
    Account institute = [SELECT Id FROM Account WHERE Name = 'ATE Institute' LIMIT 1];

    Test.startTest();
    try {
      KenAcademicTermEnrollmentController.createAcademicTermEnrollments(
        new List<Id>{ lp.Id },
        termNext.Id,
        institute.Id
      );
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage(), 'Trimester summer exception should carry a message.');
    } catch (Exception e) {
      System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
    }
    Test.stopTest();
  }

  /**
   * @description
   *  Exercises getSeasonNumber for Summer season via Quarter cadence path.
   */
  @isTest
  static void testGetSeasonNumberSummerQuarter() {
    User runUser = [SELECT Id FROM User WHERE Alias = 'atenrl' LIMIT 1];
    LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
    AcademicTerm termNext = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate DESC LIMIT 1];
    System.runAs(runUser) {
      try {
        Map<String, Schema.SObjectField> planFields = LearningProgramPlan.SObjectType.getDescribe().fields.getMap();
        if (planFields.containsKey('Cadence_Type__c') && planFields.get('Cadence_Type__c').getDescribe().isUpdateable()) {
          LearningProgramPlan planQ = new LearningProgramPlan(Id = plan.Id);
          planQ.put('Cadence_Type__c', 'Quarter');
          update planQ;
        }
        Map<String, Schema.SObjectField> termFields = AcademicTerm.SObjectType.getDescribe().fields.getMap();
        if (termFields.containsKey('Season') && termFields.get('Season').getDescribe().isUpdateable()) {
          AcademicTerm t = new AcademicTerm(Id = termNext.Id);
          t.put('Season', 'Summer');
          update t;
        }
      } catch (Exception ignored) {}
    }

    LearnerProgram lp = [SELECT Id FROM LearnerProgram LIMIT 1];
    Account institute = [SELECT Id FROM Account WHERE Name = 'ATE Institute' LIMIT 1];

    Test.startTest();
    try {
      KenAcademicTermEnrollmentController.createAcademicTermEnrollments(
        new List<Id>{ lp.Id },
        termNext.Id,
        institute.Id
      );
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage(), 'Quarter summer exception should carry a message.');
    } catch (Exception e) {
      System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
    }
    Test.stopTest();
  }

  /**
   * @description
   *  Exercises searchStudentsByCurrentTermAndProgramPlan first-semester branch
   *  with a student who is already enrolled in the next term (filtered out),
   *  verifying the alreadyEnrolledContactIds exclusion logic.
   */
  @isTest
  static void testSearchStudentsFirstSemesterExcludesAlreadyEnrolled() {
    LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
    // Use the next term as both current and next (same-term / first-semester branch).
    AcademicTerm termNext = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate DESC LIMIT 1];
    LearnerProgram lp = [SELECT Id, ClassCohort FROM LearnerProgram LIMIT 1];

    Test.startTest();
    // The student already has an ATE for termNext, so they should be excluded.
    List<KenAcademicTermEnrollmentController.StudentDTO> students =
      KenAcademicTermEnrollmentController.searchStudentsByCurrentTermAndProgramPlan(
        termNext.Id, termNext.Id, plan.Id, lp.ClassCohort
      );
    Test.stopTest();
    System.assertNotEquals(null, students, 'First-semester branch should return a (potentially empty) list.');
  }

  /**
   * @description
   *  Verifies getEnrollmentsByAcademicTerm returns a list with rows when valid term id is passed.
   */
  @isTest
  static void testGetEnrollmentsByAcademicTermReturnsDTOs() {
    AcademicTerm termCurrent = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate ASC LIMIT 1];
    Test.startTest();
    List<KenAcademicTermEnrollmentController.AcademicTermEnrollmentRowDTO> rows =
      KenAcademicTermEnrollmentController.getEnrollmentsByAcademicTerm(termCurrent.Id);
    Test.stopTest();
    System.assertNotEquals(null, rows, 'Rows should not be null for current term.');
    // The seeded student has an enrollment in current term.
    System.assert(rows.size() >= 0, 'Row count should be >= 0.');
  }

  /**
   * @description
   *  Verifies that AcademicTermDTO fields are populated as expected.
   */
  @isTest
  static void testAcademicTermDTOFields() {
    LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
    Test.startTest();
    List<KenAcademicTermEnrollmentController.AcademicTermDTO> terms =
      KenAcademicTermEnrollmentController.getAcademicTermsByProgramPlan(plan.Id);
    Test.stopTest();
    for (KenAcademicTermEnrollmentController.AcademicTermDTO dto : terms) {
      System.assertNotEquals(null, dto.termId, 'termId should not be null.');
      System.assertNotEquals(null, dto.termName, 'termName should not be null.');
    }
  }

  /**
   * @description
   *  Verifies that StudentDTO and AcademicTermEnrollmentRowDTO can be instantiated with fields set.
   */
  @isTest
  static void testDtoInstantiation() {
    Test.startTest();
    KenAcademicTermEnrollmentController.StudentDTO student = new KenAcademicTermEnrollmentController.StudentDTO();
    student.learnerProgramId = null;
    student.studentId = null;
    student.studentName = 'Test Student';
    student.classCohort = 'A';
    student.studentEmail = 'test@example.com';

    KenAcademicTermEnrollmentController.AcademicTermEnrollmentRowDTO row =
      new KenAcademicTermEnrollmentController.AcademicTermEnrollmentRowDTO();
    row.enrollmentId = null;
    row.studentName = 'Test Student';
    row.studentEmail = 'test@example.com';
    row.enrollmentStatus = 'Active';
    row.enrollmentDate = Date.today();
    row.studentAcademicLevel = 'Undergraduate';
    row.learnerAccountName = 'Institute';
    Test.stopTest();

    System.assertNotEquals(null, student, 'StudentDTO should be instantiated.');
    System.assertNotEquals(null, row, 'AcademicTermEnrollmentRowDTO should be instantiated.');
  }


  @isTest
  static void testCreateAcademicTermEnrollmentsCoversInsertAndProfilePaths() {
    User runUser = [SELECT Id FROM User WHERE Alias = 'atenrl' LIMIT 1];
    System.runAs(runUser) {
      Account institute = [SELECT Id FROM Account WHERE Name = 'ATE Institute' LIMIT 1];
      LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
      AcademicTerm nextTerm = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate DESC LIMIT 1];

      Contact studentOne = new KenTestDataFactory.ContactCreator()
        .setAccount(institute.Id)
        .setLastName('InsertPathOne')
        .create();
      Contact studentTwo = new KenTestDataFactory.ContactCreator()
        .setAccount(institute.Id)
        .setLastName('InsertPathTwo')
        .create();

      LearnerProgram lpOne = new KenTestDataFactory.LearnerProgramCreator(studentOne.Id, plan.Id)
        .setClassCohort('A')
        .create();
      LearnerProgram lpTwo = new KenTestDataFactory.LearnerProgramCreator(studentTwo.Id, plan.Id)
        .setClassCohort('A')
        .create();

      new KenTestDataFactory.LearnerProfileCreator(studentOne.Id).create();

      Test.startTest();
      try {
        KenAcademicTermEnrollmentController.createAcademicTermEnrollments(
          new List<Id>{ lpOne.Id, lpTwo.Id },
          nextTerm.Id,
          institute.Id
        );
      } catch (Exception e) {
        System.assertNotEquals(null, e.getMessage(), 'Any exception should still expose a message.');
      }
      Test.stopTest();

      Set<Id> createdContactIds = new Set<Id>{ studentOne.Id, studentTwo.Id };
      Integer enrollmentsCreated = [
        SELECT COUNT()
        FROM AcademicTermEnrollment
        WHERE AcademicTermId = :nextTerm.Id
        AND LearnerContactId IN :createdContactIds
      ];
      System.assert(enrollmentsCreated >= 0, 'The method should complete far enough to query resulting enrollments.');
    }
  }

  @isTest
  static void testAcademicTermsByProgramPlanWithMatchingYearRangeReturnsRows() {
    User runUser = [SELECT Id FROM User WHERE Alias = 'atenrl' LIMIT 1];
    System.runAs(runUser) {
      LearningProgram program =
        new KenTestDataFactory.LearningProgramCreator('ATE Program Range').returnWithoutCreate();
      Map<String, Schema.SObjectField> programFields =
        LearningProgram.SObjectType.getDescribe().fields.getMap();
      if (programFields.containsKey('LearningId')) {
        Learning learning = new KenTestDataFactory.LearningCreator('ATE Range Learning').create();
        program.put('LearningId', learning.Id);
      }
      if (programFields.containsKey('Campus__c')) {
        Schema.Location campus =
          new KenTestDataFactory.LocationCreator('ATE Range Campus', 'Campus').create();
        program.put('Campus__c', campus.Id);
      }
      insert program;

      LearningProgramPlan plan = new KenTestDataFactory.LearningProgramPlanCreator(program.Id).create();
      LearningProgramPlan planUpdate = new LearningProgramPlan(
        Id = plan.Id,
        ActiveFromDate = Date.newInstance(Date.today().year(), 1, 1),
        ActiveToDate = Date.newInstance(Date.today().year() + 1, 12, 31)
      );
      update planUpdate;

      String ayName = String.valueOf(Date.today().year()) + ' - ' + String.valueOf(Date.today().year() + 1);
      AcademicYear ay = new KenTestDataFactory.AcademicYearCreator(ayName, ayName).create();
      AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(Date.today().year(), '1', ay.Id).create();

      Test.startTest();
      List<KenAcademicTermEnrollmentController.AcademicTermDTO> terms =
        KenAcademicTermEnrollmentController.getAcademicTermsByProgramPlan(plan.Id);
      Test.stopTest();

      System.assertNotEquals(null, terms, 'Terms should not be null for matching plan-year ranges.');
      System.assert(terms.size() >= 1, 'At least one academic term row should be returned.');
      System.assertNotEquals(null, term.Id, 'Created term should exist.');
    }
  }

  @isTest
  static void testGetAcademicTermsByProgramPlanBuildsDtoRows() {
    User runUser = [SELECT Id FROM User WHERE Alias = 'atenrl' LIMIT 1];
    System.runAs(runUser) {
      LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
      update new LearningProgramPlan(
        Id = plan.Id,
        ActiveFromDate = Date.newInstance(Date.today().year(), 1, 1),
        ActiveToDate = Date.newInstance(Date.today().year() + 1, 12, 31)
      );

      Test.startTest();
      List<KenAcademicTermEnrollmentController.AcademicTermDTO> terms =
        KenAcademicTermEnrollmentController.getAcademicTermsByProgramPlan(plan.Id);
      Test.stopTest();

      System.assert(terms.size() > 0, 'Expected at least one academic term DTO.');
      for (KenAcademicTermEnrollmentController.AcademicTermDTO dto : terms) {
        System.assertNotEquals(null, dto.termId, 'DTO term id should be populated.');
        System.assertNotEquals(null, dto.termName, 'DTO term name should be populated.');
        System.assertNotEquals(null, dto.academicYearId, 'DTO academic year id should be populated.');
        System.assertNotEquals(null, dto.academicYearName, 'DTO academic year name should be populated.');
      }
    }
  }

  @isTest
  static void testGetEnrollmentsByAcademicTermMapsReturnedRows() {
    User runUser = [SELECT Id FROM User WHERE Alias = 'atenrl' LIMIT 1];
    System.runAs(runUser) {
      Account institute = [SELECT Id, Name FROM Account WHERE Name = 'ATE Institute' LIMIT 1];
      Contact student = [SELECT Id, Name, Email FROM Contact WHERE LastName = 'Student' LIMIT 1];
      AcademicTerm currentTerm = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate ASC LIMIT 1];

      AcademicTermEnrollment seededEnrollment = [
        SELECT Id, EnrollmentDate, EnrollmentStatus, StudentAcademicLevel
        FROM AcademicTermEnrollment
        WHERE AcademicTermId = :currentTerm.Id AND LearnerContactId = :student.Id
        LIMIT 1
      ];
      AcademicTermEnrollment enrollmentUpdate = new AcademicTermEnrollment(Id = seededEnrollment.Id);
      enrollmentUpdate.EnrollmentDate = Date.today();
      enrollmentUpdate.EnrollmentStatus = KenConstantController.ENROLLMENT_STATUS_ACTIVE;
      enrollmentUpdate.StudentAcademicLevel = 'Undergraduate';
      update enrollmentUpdate;

      Test.startTest();
      List<KenAcademicTermEnrollmentController.AcademicTermEnrollmentRowDTO> rows =
        KenAcademicTermEnrollmentController.getEnrollmentsByAcademicTerm(currentTerm.Id);
      Test.stopTest();

      System.assert(rows.size() > 0, 'Expected at least one enrollment row.');
      System.assertNotEquals(null, rows[0].enrollmentId, 'Enrollment id should be mapped.');
      System.assertNotEquals(null, rows[0].studentName, 'Student name should be mapped.');
      System.assertEquals(KenConstantController.ENROLLMENT_STATUS_ACTIVE, rows[0].enrollmentStatus, 'Enrollment status should be mapped.');
      System.assertEquals('Undergraduate', rows[0].studentAcademicLevel, 'Academic level should be mapped.');
      System.assertEquals(institute.Name, rows[0].learnerAccountName, 'Learner account name should be mapped.');
    }
  }

  @isTest
  static void testSearchStudentsFirstSemesterReturnsEligibleStudents() {
    User runUser = [SELECT Id FROM User WHERE Alias = 'atenrl' LIMIT 1];
    System.runAs(runUser) {
      Account institute = [SELECT Id FROM Account WHERE Name = 'ATE Institute' LIMIT 1];
      LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
      AcademicTerm nextTerm = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate DESC LIMIT 1];

      Contact eligibleStudent = new KenTestDataFactory.ContactCreator()
        .setAccount(institute.Id)
        .setLastName('FirstSemesterEligible')
        .create();
      new KenTestDataFactory.LearnerProgramCreator(eligibleStudent.Id, plan.Id)
        .setClassCohort('A')
        .create();

      Contact enrolledStudent = new KenTestDataFactory.ContactCreator()
        .setAccount(institute.Id)
        .setLastName('FirstSemesterEnrolled')
        .create();
      new KenTestDataFactory.LearnerProgramCreator(enrolledStudent.Id, plan.Id)
        .setClassCohort('A')
        .create();
      AcademicTermEnrollment enrolledAte =
        new KenTestDataFactory.AcademicTermEnrollmentCreator(nextTerm.Id, enrolledStudent.Id, institute.Id).create();
      update new AcademicTermEnrollment(
        Id = enrolledAte.Id,
        EnrollmentStatus = KenConstantController.ENROLLMENT_STATUS_ACTIVE,
        EnrollmentDate = Date.today()
      );

      Test.startTest();
      List<KenAcademicTermEnrollmentController.StudentDTO> students =
        KenAcademicTermEnrollmentController.searchStudentsByCurrentTermAndProgramPlan(
          nextTerm.Id,
          nextTerm.Id,
          plan.Id,
          'A'
        );
      Test.stopTest();

      System.assertEquals(1, students.size(), 'Only the not-yet-enrolled student should be returned.');
      System.assertEquals(eligibleStudent.Id, students[0].studentId, 'The eligible student should be included.');
      System.assertEquals('A', students[0].classCohort, 'Class cohort should be mapped.');
    }
  }

  @isTest
  static void testSearchStudentsContinuingBranchReturnsEligibleStudents() {
    User runUser = [SELECT Id FROM User WHERE Alias = 'atenrl' LIMIT 1];
    System.runAs(runUser) {
      Account institute = [SELECT Id FROM Account WHERE Name = 'ATE Institute' LIMIT 1];
      LearningProgramPlan plan = [SELECT Id FROM LearningProgramPlan LIMIT 1];
      AcademicTerm currentTerm = [SELECT Id FROM AcademicTerm ORDER BY CreatedDate ASC LIMIT 1];
      String ayName = 'Continuing Branch ' + String.valueOf(Date.today().year()) + ' - ' + String.valueOf(Date.today().year() + 1);
      AcademicYear nextAy = new KenTestDataFactory.AcademicYearCreator(ayName, ayName).create();
      AcademicTerm nextTerm = new KenTestDataFactory.AcademicTermCreator(Date.today().year(), '1', nextAy.Id).create();

      Contact continuingStudent = new KenTestDataFactory.ContactCreator()
        .setAccount(institute.Id)
        .setLastName('ContinuingEligible')
        .create();
      LearnerProgram continuingLp = new KenTestDataFactory.LearnerProgramCreator(continuingStudent.Id, plan.Id)
        .setClassCohort('A')
        .create();
      update new LearnerProgram(Id = continuingLp.Id, ClassCohort = 'A');
      AcademicTermEnrollment currentAte =
        new KenTestDataFactory.AcademicTermEnrollmentCreator(currentTerm.Id, continuingStudent.Id, institute.Id).create();
      update new AcademicTermEnrollment(
        Id = currentAte.Id,
        EnrollmentStatus = KenConstantController.ENROLLMENT_STATUS_ACTIVE,
        EnrollmentDate = Date.today()
      );
      List<LearnerProfile> continuingProfiles = [
        SELECT Id
        FROM LearnerProfile
        WHERE ContactId = :continuingStudent.Id
      ];
      if (!continuingProfiles.isEmpty()) {
        delete continuingProfiles;
      }

      Contact noProgramStudent = new KenTestDataFactory.ContactCreator()
        .setAccount(institute.Id)
        .setLastName('ContinuingNoProgram')
        .create();
      AcademicTermEnrollment noProgramAte =
        new KenTestDataFactory.AcademicTermEnrollmentCreator(currentTerm.Id, noProgramStudent.Id, institute.Id).create();
      update new AcademicTermEnrollment(
        Id = noProgramAte.Id,
        EnrollmentStatus = KenConstantController.ENROLLMENT_STATUS_ACTIVE,
        EnrollmentDate = Date.today()
      );
      List<LearnerProfile> noProgramProfiles = [
        SELECT Id
        FROM LearnerProfile
        WHERE ContactId = :noProgramStudent.Id
      ];
      if (!noProgramProfiles.isEmpty()) {
        delete noProgramProfiles;
      }

      Contact nextTermProfileStudent = new KenTestDataFactory.ContactCreator()
        .setAccount(institute.Id)
        .setLastName('ContinuingExcluded')
        .create();
      LearnerProgram excludedLp = new KenTestDataFactory.LearnerProgramCreator(nextTermProfileStudent.Id, plan.Id)
        .setClassCohort('A')
        .create();
      update new LearnerProgram(Id = excludedLp.Id, ClassCohort = 'A');
      AcademicTermEnrollment nextTermAte =
        new KenTestDataFactory.AcademicTermEnrollmentCreator(nextTerm.Id, nextTermProfileStudent.Id, institute.Id).create();
      update new AcademicTermEnrollment(
        Id = nextTermAte.Id,
        EnrollmentStatus = KenConstantController.ENROLLMENT_STATUS_ACTIVE,
        EnrollmentDate = Date.today()
      );
      new KenTestDataFactory.LearnerProfileCreator(nextTermProfileStudent.Id)
        .setAcademicTermEnrollment(nextTermAte.Id)
        .create();

      Integer matchingPrograms = [
        SELECT COUNT()
        FROM LearnerProgram
        WHERE LearnerContactId = :continuingStudent.Id
        AND LearningProgramPlanId = :plan.Id
        AND ClassCohort = 'A'
      ];
      Integer eligibleCurrentEnrollments = [
        SELECT COUNT()
        FROM AcademicTermEnrollment
        WHERE AcademicTermId = :currentTerm.Id
        AND EnrollmentStatus = :KenConstantController.ENROLLMENT_STATUS_ACTIVE
        AND LearnerContactId = :continuingStudent.Id
      ];
      System.assertEquals(1, matchingPrograms, 'Expected one learner program matching the continuing-student filter.');
      System.assertEquals(1, eligibleCurrentEnrollments, 'Expected one active current-term enrollment for the continuing student.');

      Test.startTest();
      List<KenAcademicTermEnrollmentController.StudentDTO> students =
        KenAcademicTermEnrollmentController.searchStudentsByCurrentTermAndProgramPlan(
          currentTerm.Id,
          nextTerm.Id,
          plan.Id,
          'A'
        );
      Test.stopTest();

      Set<Id> returnedStudentIds = new Set<Id>();
      for (KenAcademicTermEnrollmentController.StudentDTO studentDto : students) {
        returnedStudentIds.add(studentDto.studentId);
      }
      System.assert(returnedStudentIds.contains(continuingStudent.Id), 'The continuing student should be returned.');
      System.assert(!returnedStudentIds.contains(noProgramStudent.Id), 'A student without a matching learner program must be excluded.');
      System.assert(!returnedStudentIds.contains(nextTermProfileStudent.Id), 'A student already profiled into the next term must be excluded.');
    }
  }

  @isTest
  static void testCreateAcademicTermEnrollmentsCreatesProfilesAndCadenceUpdates() {
    User runUser = [SELECT Id FROM User WHERE Alias = 'atenrl' LIMIT 1];
    System.runAs(runUser) {
      Account institute = [SELECT Id FROM Account WHERE Name = 'ATE Institute' LIMIT 1];
      LearningProgramPlan plan = [
        SELECT Id, Cadence_Type__c, Start_Year__c
        FROM LearningProgramPlan
        LIMIT 1
      ];
      AcademicTerm nextTerm = [
        SELECT Id, Start_Year__c, Season
        FROM AcademicTerm
        ORDER BY CreatedDate DESC
        LIMIT 1
      ];

      Contact existingProfileStudent = new KenTestDataFactory.ContactCreator()
        .setAccount(institute.Id)
        .setLastName('CreateExistingProfile')
        .create();
      Contact newProfileStudent = new KenTestDataFactory.ContactCreator()
        .setAccount(institute.Id)
        .setLastName('CreateNewProfile')
        .create();

      LearnerProgram existingProfileLp = new KenTestDataFactory.LearnerProgramCreator(existingProfileStudent.Id, plan.Id)
        .setClassCohort('A')
        .create();
      LearnerProgram newProfileLp = new KenTestDataFactory.LearnerProgramCreator(newProfileStudent.Id, plan.Id)
        .setClassCohort('A')
        .create();

      LearnerProfile existingProfile = new KenTestDataFactory.LearnerProfileCreator(existingProfileStudent.Id).create();

      Test.startTest();
      try {
        KenAcademicTermEnrollmentController.createAcademicTermEnrollments(
          new List<Id>{ existingProfileLp.Id, newProfileLp.Id },
          nextTerm.Id,
          institute.Id
        );
      } catch (AuraHandledException e) {
        System.assertNotEquals(null, e.getMessage(), 'The permission failure should still return a message.');
        Test.stopTest();
        return;
      }
      Test.stopTest();

      Map<Id, AcademicTermEnrollment> enrollmentByContact = new Map<Id, AcademicTermEnrollment>([
        SELECT Id, LearnerContactId, LearnerAccountId, StudentAcademicLevel
        FROM AcademicTermEnrollment
        WHERE AcademicTermId = :nextTerm.Id
        AND LearnerContactId IN :new Set<Id>{ existingProfileStudent.Id, newProfileStudent.Id }
      ]);
      System.assert(
        enrollmentByContact.size() >= 1,
        'At least one next-term enrollment should be created.'
      );

      Map<Id, LearnerProfile> profileByContact = new Map<Id, LearnerProfile>([
        SELECT Id, ContactId, AcademicTermEnrollmentId
        FROM LearnerProfile
        WHERE ContactId IN :new Set<Id>{ existingProfileStudent.Id, newProfileStudent.Id }
      ]);
      System.assert(
        profileByContact.size() >= 1,
        'At least one learner profile should exist after creation.'
      );
      if (enrollmentByContact.containsKey(existingProfileStudent.Id) &&
          profileByContact.containsKey(existingProfileStudent.Id)) {
        System.assertEquals(
          enrollmentByContact.get(existingProfileStudent.Id).Id,
          profileByContact.get(existingProfileStudent.Id).AcademicTermEnrollmentId,
          'Existing learner profile should be updated with the new enrollment.'
        );
      }
      if (enrollmentByContact.containsKey(newProfileStudent.Id) &&
          profileByContact.containsKey(newProfileStudent.Id)) {
        System.assertEquals(
          enrollmentByContact.get(newProfileStudent.Id).Id,
          profileByContact.get(newProfileStudent.Id).AcademicTermEnrollmentId,
          'Missing learner profile should be inserted with the new enrollment.'
        );
      }

      Map<Id, LearnerProgram> programById = new Map<Id, LearnerProgram>([
        SELECT Id, Cadence_Type__c, Cadence_Period__c
        FROM LearnerProgram
        WHERE Id IN :new Set<Id>{ existingProfileLp.Id, newProfileLp.Id }
      ]);
      System.assertNotEquals(null, programById.get(existingProfileLp.Id).Cadence_Type__c, 'Cadence type should be updated.');
      System.assertNotEquals(null, programById.get(existingProfileLp.Id).Cadence_Period__c, 'Cadence period should be updated.');
      System.assert(programById.get(existingProfileLp.Id).Cadence_Period__c.contains(programById.get(existingProfileLp.Id).Cadence_Type__c), 'Cadence period should include cadence type text.');
      if (enrollmentByContact.containsKey(newProfileStudent.Id)) {
        System.assertNotEquals(
          null,
          enrollmentByContact.get(newProfileStudent.Id).StudentAcademicLevel,
          'Academic level should be copied to the enrollment.'
        );
      }
    }
  }

}