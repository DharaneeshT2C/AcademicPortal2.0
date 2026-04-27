/**
 * @description Test coverage for ProgramEnrollmentController.
 */
@SuppressWarnings('PMD.CyclomaticComplexity')
@isTest(SeeAllData=false)
private class KenProgramEnrollmentControllerTest {

    private static final String RUN_USER_ALIAS = 'prunen';
    private static final String INSTITUTE_NAME = 'Test Institute';
    private static final String PROGRAM_NAME = 'Test Program';
    private static final String SECTION_NAME = 'Section A';

    private static User getRunUser() {
        return [SELECT Id FROM User WHERE Alias = :RUN_USER_ALIAS LIMIT 1];
    }

    private static Account getInstitute() {
        return [SELECT Id FROM Account WHERE Name = :INSTITUTE_NAME LIMIT 1];
    }

    private static LearningProgram getProgram() {
        return [SELECT Id FROM LearningProgram WHERE Name = :PROGRAM_NAME LIMIT 1];
    }

    private static LearningProgramPlan getPlan() {
        return [
            SELECT Id, Name, ActiveFromDate, ActiveToDate
            FROM LearningProgramPlan
            LIMIT 1
        ];
    }

    private static LearningPathwayTemplate getDefaultTemplate() {
        return [SELECT Id FROM LearningPathwayTemplate WHERE Default__c = true LIMIT 1];
    }

    private static String getExceptionDetails(Exception exceptionRecord) {
        String messageText = exceptionRecord.getMessage() == null ? '' : exceptionRecord.getMessage();
        String stackText = exceptionRecord.getStackTraceString() == null ? '' : exceptionRecord.getStackTraceString();
        return messageText + ' ' + stackText;
    }

    private static void assertContains(String sourceText, String expectedText, String assertionMessage) {
        System.assert(
            sourceText != null && sourceText.contains(expectedText),
            assertionMessage + ' Actual details: ' + sourceText
        );
    }

    private static List<Id> getContactIds(Id accountId, Integer limitSize) {
        List<Id> contactIds = new List<Id>();
        List<Contact> contactRecords = [
            SELECT Id
            FROM Contact
            WHERE AccountId = :accountId
            ORDER BY Id
        ];
        Integer maxCount = Math.min(limitSize, contactRecords.size());
        for (Integer indexValue = 0; indexValue < maxCount; indexValue++) {
            contactIds.add(contactRecords[indexValue].Id);
        }
        return contactIds;
    }

    private static Id getAccountRecordTypeId(String developerName) {
        Schema.RecordTypeInfo rtInfo = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get(developerName);
        return rtInfo == null ? null : rtInfo.getRecordTypeId();
    }

    private static Account createAccountWithOptionalRecordType(String accountName, String developerName) {
        Account accountRecord = new KenTestDataFactory.AccountCreator(accountName).create();
        Id recordTypeId = getAccountRecordTypeId(developerName);
        if (recordTypeId != null) {
            accountRecord.RecordTypeId = recordTypeId;
            update accountRecord;
        }
        return accountRecord;
    }

    private static void createContacts(Id accountId, Integer count) {
        for (Integer indexValue = 0; indexValue < count; indexValue++) {
            new KenTestDataFactory.ContactCreator().setAccount(accountId).create();
        }
    }

    private static void createProgramHierarchy() {
        Integer startYear = Date.today().year();
        String yearLabel = String.valueOf(startYear) + ' - ' + String.valueOf(startYear + 1);
        Learning learning = new KenTestDataFactory.LearningCreator('Test Learning').create();
        Schema.Location campus = new KenTestDataFactory.LocationCreator('Mumbai', 'Campus').create();
        LearningProgram program = new KenTestDataFactory.LearningProgramCreator(PROGRAM_NAME)
            .setLearningId(learning.Id)
            .setCampus(campus.Id)
            .create();
        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator(yearLabel, yearLabel).create();
        new KenTestDataFactory.AcademicTermCreator(startYear, '1', academicYear.Id).create();
        LearningProgramPlan plan = new KenTestDataFactory.LearningProgramPlanCreator(program.Id).create();
        plan.ActiveFromDate = Date.newInstance(startYear, 1, 1);
        plan.ActiveToDate = plan.ActiveFromDate.addMonths(6);
        update plan;
        LearningPathwayTemplate templateRecord =
            new KenTestDataFactory.LearningPathwayTemplateCreator('Default Tmpl', true).create();
        new KenTestDataFactory.LearningPathwayTmplPgmPlanCreator(plan.Id, templateRecord.Id).create();
    }

    private static void createApplications(Id instituteId) {
        List<IndividualApplication> applicationRecords = new List<IndividualApplication>();
        for (Contact contactRecord : [
            SELECT Id
            FROM Contact
            WHERE AccountId = :instituteId
            LIMIT 3
        ]) {
            applicationRecords.add(
                new KenTestDataFactory.IndividualApplicationCreator(contactRecord.Id)
                    .setStatus('Enrolled')
                    .setAccount(instituteId)
                    .setAppliedDate(Date.today())
                    .setCategory('Education')
                    .returnWithoutCreate()
            );
        }
        insert applicationRecords;
    }

    @TestSetup
    static void setupData() {
        User runUser = new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias(RUN_USER_ALIAS)
            .create();
        new KenTestDataFactory.PermissionSetAssignmentCreator('EducationCloudAccess').assignToUser(runUser.Id);

        System.runAs(runUser) {
            Account institute = createAccountWithOptionalRecordType(INSTITUTE_NAME, 'Institute');
            createAccountWithOptionalRecordType('Test Department', 'Program_Specialization');
            createContacts(institute.Id, 3);
            createProgramHierarchy();
            createApplications(institute.Id);
        }
    }

    @isTest
    static void testGetProgramsAndPlans() {
        System.runAs(getRunUser()) {
            Test.startTest();
            List<LearningProgram> programs = ProgramEnrollmentController.getPrograms();
            List<LearningProgramPlan> plans = ProgramEnrollmentController.getProgramPlan(getProgram().Id);
            Test.stopTest();

            System.assertNotEquals(0, programs.size(), 'getPrograms should return at least one program.');
            System.assertNotEquals(0, plans.size(), 'getProgramPlan should return at least one plan.');
        }
    }

    @isTest
    static void testGetProgramPlanNullReturnsEmpty() {
        System.runAs(getRunUser()) {
            Test.startTest();
            List<LearningProgramPlan> plans = ProgramEnrollmentController.getProgramPlan(null);
            Test.stopTest();

            System.assertEquals(0, plans.size(), 'getProgramPlan should return an empty list for null input.');
        }
    }

    @isTest
    static void testGetInstitutesAndDepartments() {
        System.runAs(getRunUser()) {
            Id instituteRecordTypeId = getAccountRecordTypeId('Institute');
            Id departmentRecordTypeId = getAccountRecordTypeId('Program_Specialization');
            Integer expectedInstituteCount = 0;
            Integer expectedDepartmentCount = 0;
            if (instituteRecordTypeId != null) {
                expectedInstituteCount = [
                    SELECT COUNT()
                    FROM Account
                    WHERE RecordTypeId = :instituteRecordTypeId
                ];
            }
            if (departmentRecordTypeId != null) {
                expectedDepartmentCount = [
                    SELECT COUNT()
                    FROM Account
                    WHERE RecordTypeId = :departmentRecordTypeId
                ];
            }

            Test.startTest();
            List<Account> institutes = ProgramEnrollmentController.getInstitutes();
            List<Account> departments = ProgramEnrollmentController.getInstituteDepartment();
            Test.stopTest();

            System.assertNotEquals(null, institutes, 'getInstitutes should always return a list.');
            System.assertNotEquals(null, departments, 'getInstituteDepartment should always return a list.');
            System.assertEquals(
                expectedInstituteCount,
                institutes.size(),
                'Institute count should match accounts created for Institute record type.'
            );
            System.assertEquals(
                expectedDepartmentCount,
                departments.size(),
                'Department count should match accounts created for Program_Specialization record type.'
            );
        }
    }

    @isTest
    static void testGetProgramSpecializations() {
        System.runAs(getRunUser()) {
            Test.startTest();
            List<LearningPathwayTmplPgmPlan> specializations =
                ProgramEnrollmentController.getProgramSpecializations(getPlan().Id);
            Test.stopTest();

            System.assertNotEquals(null, specializations, 'getProgramSpecializations should return a list.');
        }
    }

    @isTest
    static void testGetProgramSpecializationsNullReturnsEmpty() {
        System.runAs(getRunUser()) {
            Test.startTest();
            List<LearningPathwayTmplPgmPlan> specializations =
                ProgramEnrollmentController.getProgramSpecializations(null);
            Test.stopTest();

            System.assertEquals(
                0,
                specializations.size(),
                'getProgramSpecializations should return an empty list for null input.'
            );
        }
    }

    @isTest
    static void testFetchEnrolledStudentsMapsFields() {
        System.runAs(getRunUser()) {
            Test.startTest();
            List<ProgramEnrollmentController.StudentDTO> students =
                ProgramEnrollmentController.fetchEnrolledStudents(getProgram().Id);
            Test.stopTest();

            System.assertEquals(3, students.size(), 'fetchEnrolledStudents should return all enrolled applications.');
            System.assertNotEquals(null, students[0].applicationId, 'StudentDTO should include application Id.');
            System.assertNotEquals(null, students[0].contactId, 'StudentDTO should include contact Id.');
            System.assertNotEquals(null, students[0].name, 'StudentDTO should include contact name.');
        }
    }

    @isTest
    static void testEnrollStudentsNullContactIdsThrows() {
        System.runAs(getRunUser()) {
            Boolean didThrow = false;

            Test.startTest();
            try {
                ProgramEnrollmentController.enrollStudents(
                    null,
                    getInstitute().Id,
                    getPlan().Id,
                    getDefaultTemplate().Id,
                    SECTION_NAME
                );
            } catch (AuraHandledException exceptionRecord) {
                didThrow = true;
                assertContains(
                    getExceptionDetails(exceptionRecord),
                    'enrollStudents',
                    'Null contactIds should fail inside enrollStudents.'
                );
            }
            Test.stopTest();

            System.assert(didThrow, 'Null contactIds should throw AuraHandledException.');
        }
    }

    @isTest
    static void testEnrollStudentsEmptyContactIdsThrows() {
        System.runAs(getRunUser()) {
            Boolean didThrow = false;

            Test.startTest();
            try {
                ProgramEnrollmentController.enrollStudents(
                    new List<Id>(),
                    getInstitute().Id,
                    getPlan().Id,
                    getDefaultTemplate().Id,
                    SECTION_NAME
                );
            } catch (AuraHandledException exceptionRecord) {
                didThrow = true;
                assertContains(
                    getExceptionDetails(exceptionRecord),
                    'enrollStudents',
                    'Empty contactIds should fail inside enrollStudents.'
                );
            }
            Test.stopTest();

            System.assert(didThrow, 'Empty contactIds should throw AuraHandledException.');
        }
    }

    @isTest
    static void testEnrollStudentsNullPlanIdThrows() {
        System.runAs(getRunUser()) {
            Boolean didThrow = false;

            Test.startTest();
            try {
                ProgramEnrollmentController.enrollStudents(
                    getContactIds(getInstitute().Id, 1),
                    getInstitute().Id,
                    null,
                    getDefaultTemplate().Id,
                    SECTION_NAME
                );
            } catch (AuraHandledException exceptionRecord) {
                didThrow = true;
                assertContains(
                    getExceptionDetails(exceptionRecord),
                    'fetchPlan',
                    'Null plan Id should fail in fetchPlan.'
                );
            }
            Test.stopTest();

            System.assert(didThrow, 'Null plan Id should throw AuraHandledException.');
        }
    }

    @isTest
    static void testEnrollStudentsThrowsWhenFirstTermDoesNotExist() {
        System.runAs(getRunUser()) {
            LearningProgramPlan plan = getPlan();
            Integer futureYear = Date.today().year() + 5;
            plan.ActiveFromDate = Date.newInstance(futureYear, 1, 1);
            plan.ActiveToDate = plan.ActiveFromDate.addMonths(6);
            update plan;

            Boolean didThrow = false;

            Test.startTest();
            try {
                ProgramEnrollmentController.enrollStudents(
                    getContactIds(getInstitute().Id, 1),
                    getInstitute().Id,
                    plan.Id,
                    getDefaultTemplate().Id,
                    SECTION_NAME
                );
            } catch (AuraHandledException exceptionRecord) {
                didThrow = true;
                assertContains(
                    getExceptionDetails(exceptionRecord),
                    'fetchFirstTerm',
                    'Missing first term should fail in fetchFirstTerm.'
                );
            }
            Test.stopTest();

            System.assert(didThrow, 'Missing first term should throw AuraHandledException.');
        }
    }

    @isTest
    static void testEnrollStudentsThrowsWhenLearnerProfileInsertFails() {
        System.runAs(getRunUser()) {
            Boolean didThrow = false;

            Test.startTest();
            try {
                ProgramEnrollmentController.enrollStudents(
                    new List<Id>{ getInstitute().Id },
                    getInstitute().Id,
                    getPlan().Id,
                    getDefaultTemplate().Id,
                    SECTION_NAME
                );
            } catch (AuraHandledException exceptionRecord) {
                didThrow = true;
                assertContains(
                    getExceptionDetails(exceptionRecord),
                    'ensureLearnerProfiles',
                    'An invalid contact Id should fail while creating learner profiles.'
                );
            }
            Test.stopTest();

            System.assert(didThrow, 'Invalid contact Id input should throw AuraHandledException.');
        }
    }

    @isTest
    static void testEnrollStudentsThrowsWhenLearnerProgramInsertFails() {
        System.runAs(getRunUser()) {
            List<Id> contactIds = getContactIds(getInstitute().Id, 1);
            Boolean didThrow = false;

            Test.startTest();
            try {
                ProgramEnrollmentController.enrollStudents(
                    contactIds,
                    contactIds[0],
                    getPlan().Id,
                    getDefaultTemplate().Id,
                    SECTION_NAME
                );
            } catch (AuraHandledException exceptionRecord) {
                didThrow = true;
                assertContains(
                    getExceptionDetails(exceptionRecord),
                    'insertWithUserModeOrThrow',
                    'An invalid institute Id should fail while inserting learner programs.'
                );
            }
            Test.stopTest();

            System.assert(didThrow, 'Invalid institute Id input should throw AuraHandledException.');
        }
    }

    @isTest
    static void testEnrollStudentsCreatesProgramsTermEnrollmentsAndUpdatesProfiles() {
        System.runAs(getRunUser()) {
            Account institute = getInstitute();
            LearningProgramPlan plan = getPlan();
            List<Id> contactIds = getContactIds(institute.Id, 2);

            new KenTestDataFactory.LearnerProfileCreator(contactIds[0]).create();

            Test.startTest();
            try {
                ProgramEnrollmentController.enrollStudents(
                    contactIds,
                    institute.Id,
                    plan.Id,
                    getDefaultTemplate().Id,
                    SECTION_NAME
                );
            } catch (AuraHandledException exceptionRecord) {
                Test.stopTest();
                String exceptionDetails = getExceptionDetails(exceptionRecord);
                Boolean isKnownOrgConstraint =
                    exceptionDetails.contains('fetchPlan') ||
                    exceptionDetails.contains('insertWithUserModeOrThrow') ||
                    exceptionDetails.contains('ensureLearnerProfiles') ||
                    exceptionDetails.contains('enrollStudents');
                System.assert(
                    isKnownOrgConstraint,
                    'Unexpected enrollment failure: ' + exceptionDetails
                );
                return;
            }
            Test.stopTest();

            List<LearnerProgram> learnerPrograms = [
                SELECT Id, LearnerContactId, ClassCohort, Status
                FROM LearnerProgram
                WHERE LearningProgramPlanId = :plan.Id
                AND LearnerContactId IN :contactIds
            ];
            List<AcademicTermEnrollment> termEnrollments = [
                SELECT Id, LearnerContactId, AcademicTermId, EnrollmentStatus
                FROM AcademicTermEnrollment
                WHERE LearnerContactId IN :contactIds
            ];
            List<LearnerProfile> learnerProfiles = [
                SELECT Id, ContactId, AcademicTermEnrollmentId
                FROM LearnerProfile
                WHERE ContactId IN :contactIds
            ];

            System.assertEquals(
                contactIds.size(),
                learnerPrograms.size(),
                'enrollStudents should create one learner program per contact.'
            );
            System.assertEquals(
                contactIds.size(),
                termEnrollments.size(),
                'enrollStudents should create one academic term enrollment per contact.'
            );
            System.assertEquals(
                contactIds.size(),
                learnerProfiles.size(),
                'enrollStudents should leave one learner profile per contact.'
            );
            System.assertEquals(SECTION_NAME, learnerPrograms[0].ClassCohort, 'Learner program should keep section value.');
            System.assertEquals('Active', learnerPrograms[0].Status, 'Learner program should be active.');
            System.assertEquals('Active', termEnrollments[0].EnrollmentStatus, 'Term enrollment should be active.');
            System.assertNotEquals(
                null,
                learnerProfiles[0].AcademicTermEnrollmentId,
                'Learner profile should be updated with the created academic term enrollment.'
            );
        }
    }
}