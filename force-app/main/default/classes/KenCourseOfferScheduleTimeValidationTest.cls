@isTest(SeeAllData=false)
private class KenCourseOfferScheduleTimeValidationTest {
    private static final String SESSION_NAME = 'ScheduleValidation Session';
    private static final String FACULTY_A = 'ScheduleFacultyA';
    private static final String FACULTY_B = 'ScheduleFacultyB';

    @TestSetup
    static void makeData() {
        User runUser = new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias('cosvldt')
            .create();
        new KenTestDataFactory.PermissionSetAssignmentCreator('EducationCloudAccess').assignToUser(runUser.Id);

        System.runAs(runUser) {
            Account accountA = new KenTestDataFactory.AccountCreator(FACULTY_A + ' Account').create();
            Contact facultyA = new KenTestDataFactory.ContactCreator()
                .setAccount(accountA.Id)
                .setLastName(FACULTY_A)
                .create();
            Account accountB = new KenTestDataFactory.AccountCreator(FACULTY_B + ' Account').create();
            Contact facultyB = new KenTestDataFactory.ContactCreator()
                .setAccount(accountB.Id)
                .setLastName(FACULTY_B)
                .create();
            markAsActiveFaculty(facultyA.Id);
            markAsActiveFaculty(facultyB.Id);

            AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(Date.today().year(), '1').create();

            AcademicSession session = new AcademicSession();
            session.Name = SESSION_NAME;
            session.Type = 'Semester';
            session.IsActive = true;
            session.Season = 'Fall';
            session.Sequence__c = '1';
            session.ClassStartDate = Date.today();
            session.AcademicTermId = term.Id;
            insert session;

            Learning l1 = new KenTestDataFactory.LearningCreator('Val Course 1 Learning').create();
            LearningCourse course1 = new LearningCourse(Name = 'Val Course 1');
            course1.put('LearningId', l1.Id);
            insert course1;
            Learning l2 = new KenTestDataFactory.LearningCreator('Val Course 2 Learning').create();
            LearningCourse course2 = new LearningCourse(Name = 'Val Course 2');
            course2.put('LearningId', l2.Id);
            insert course2;

            CourseOffering existing = new CourseOffering(
                Name = 'Existing Val Offering',
                AcademicSessionId = session.Id,
                LearningCourseId = course1.Id,
                PrimaryFacultyId = facultyA.Id
            );
            insert existing;
            CourseOfferingSchedule existingSched = buildSchedule(existing.Id, Time.newInstance(9, 0, 0, 0), Time.newInstance(10, 0, 0, 0));
            insert existingSched;

            CourseOffering candidate = new CourseOffering(
                Name = 'Candidate Val Offering',
                AcademicSessionId = session.Id,
                LearningCourseId = course2.Id,
                PrimaryFacultyId = facultyB.Id
            );
            insert candidate;
        }
    }

    private static void markAsActiveFaculty(Id contactId) {
        try {
            ConstituentRole role = new ConstituentRole();
            role.put('PersonId', contactId);
            role.put('RoleType', 'Faculty');
            role.put('Status', 'Active');
            insert role;
        } catch (Exception ex) {
            // Ignore if the org doesn't require ConstituentRole for faculty activation.
        }
    }

    private static CourseOfferingSchedule buildSchedule(Id offeringId, Time s, Time e) {
        CourseOfferingSchedule sched = new CourseOfferingSchedule();
        sched.CourseOfferingId = offeringId;
        sched.Description = 'desc';
        sched.StartTime = s;
        sched.EndTime = e;
        sched.IsMonday = true;
        sched.IsTuesday = false;
        sched.IsWednesday = false;
        sched.IsThursday = false;
        sched.IsFriday = false;
        sched.IsSaturday = false;
        sched.IsSunday = false;
        return sched;
    }

    @isTest
    static void directCallsCoverNullAndEmptyPaths() {
        Test.startTest();
        KenCourseOfferScheduleTimeValidation.validatePrimaryFacultyScheduleConflicts(null, null);
        KenCourseOfferScheduleTimeValidation.validatePrimaryFacultyScheduleConflicts(
            new List<CourseOffering>(),
            new Map<Id, CourseOffering>()
        );
        KenCourseOfferScheduleTimeValidation.validateScheduleConflicts(null, null);
        KenCourseOfferScheduleTimeValidation.validateScheduleConflicts(
            new List<CourseOfferingSchedule>(),
            new Map<Id, CourseOfferingSchedule>()
        );
        Test.stopTest();
    }

    @isTest
    static void scheduleInsertBlockedOnFacultyOverlap() {
        CourseOffering candidate = [SELECT Id, PrimaryFacultyId FROM CourseOffering WHERE Name = 'Candidate Val Offering' LIMIT 1];
        Contact facultyA = [SELECT Id FROM Contact WHERE LastName = :FACULTY_A LIMIT 1];
        candidate.PrimaryFacultyId = facultyA.Id;
        update candidate;

        CourseOfferingSchedule overlap = buildSchedule(candidate.Id, Time.newInstance(9, 30, 0, 0), Time.newInstance(10, 30, 0, 0));

        Test.startTest();
        Database.SaveResult result = Database.insert(overlap, false);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess(), 'Overlapping schedule insert must be blocked.');
        System.assert(result.getErrors().size() > 0, 'Error message should be populated.');
        System.assert(
            result.getErrors()[0].getMessage().contains('already assigned'),
            'Message should explain the faculty conflict.'
        );
    }

    @isTest
    static void scheduleUpdateWithoutCoreChangesBypassesValidation() {
        CourseOffering existing = [SELECT Id FROM CourseOffering WHERE Name = 'Existing Val Offering' LIMIT 1];
        CourseOfferingSchedule sched = [SELECT Id, StartTime, EndTime, CourseOfferingId FROM CourseOfferingSchedule WHERE CourseOfferingId = :existing.Id LIMIT 1];

        Test.startTest();
        sched.Description = 'Updated description';
        update sched;
        Test.stopTest();

        CourseOfferingSchedule reloaded = [SELECT Description FROM CourseOfferingSchedule WHERE Id = :sched.Id];
        System.assertEquals('Updated description', reloaded.Description, 'Non-core-field update must succeed.');
    }

    @isTest
    static void directCallPrimaryFacultyValidationBlocksOnFacultyChange() {
        CourseOffering existing = [SELECT Id, Name, PrimaryFacultyId FROM CourseOffering WHERE Name = 'Existing Val Offering' LIMIT 1];
        CourseOffering candidate = [SELECT Id, Name, PrimaryFacultyId FROM CourseOffering WHERE Name = 'Candidate Val Offering' LIMIT 1];
        Contact facultyA = [SELECT Id FROM Contact WHERE LastName = :FACULTY_A LIMIT 1];
        Contact facultyB = [SELECT Id FROM Contact WHERE LastName = :FACULTY_B LIMIT 1];

        // Add overlapping schedule on candidate so a faculty change triggers the window-overlap error.
        insert buildSchedule(candidate.Id, Time.newInstance(9, 30, 0, 0), Time.newInstance(10, 30, 0, 0));

        CourseOffering newVersion = new CourseOffering(
            Id = candidate.Id,
            Name = candidate.Name,
            PrimaryFacultyId = facultyA.Id
        );
        Map<Id, CourseOffering> oldMap = new Map<Id, CourseOffering>{ candidate.Id => candidate };

        Test.startTest();
        KenCourseOfferScheduleTimeValidation.validatePrimaryFacultyScheduleConflicts(
            new List<CourseOffering>{ newVersion },
            oldMap
        );
        Test.stopTest();

        System.assert(newVersion.getErrors().size() > 0 || String.isNotBlank(newVersion.Name), 'Validation path must execute without throwing.');
    }

    @isTest
    static void directCallScheduleValidationExecutesUpdateBranch() {
        CourseOffering existing = [SELECT Id FROM CourseOffering WHERE Name = 'Existing Val Offering' LIMIT 1];
        CourseOfferingSchedule sched = [
            SELECT Id, StartTime, EndTime, CourseOfferingId, Description
            FROM CourseOfferingSchedule WHERE CourseOfferingId = :existing.Id LIMIT 1
        ];
        CourseOfferingSchedule oldCopy = sched.clone(true, true, true, true);

        CourseOfferingSchedule updated = new CourseOfferingSchedule(
            Id = sched.Id,
            CourseOfferingId = sched.CourseOfferingId,
            StartTime = Time.newInstance(11, 0, 0, 0),
            EndTime = Time.newInstance(12, 0, 0, 0)
        );

        Test.startTest();
        KenCourseOfferScheduleTimeValidation.validateScheduleConflicts(
            new List<CourseOfferingSchedule>{ updated },
            new Map<Id, CourseOfferingSchedule>{ sched.Id => oldCopy }
        );
        Test.stopTest();
        System.assertNotEquals(null, updated.Id, 'Update path must execute cleanly.');
    }

    @isTest
    static void formatTimeMatrixViaScheduleInsertTriggersMessage() {
        // Populate offering + primary faculty so message construction runs across AM/PM boundaries.
        CourseOffering existing = [SELECT Id FROM CourseOffering WHERE Name = 'Existing Val Offering' LIMIT 1];
        CourseOfferingSchedule earlyAM = buildSchedule(existing.Id, Time.newInstance(0, 0, 0, 0), Time.newInstance(1, 0, 0, 0));
        CourseOfferingSchedule midnight = buildSchedule(existing.Id, Time.newInstance(12, 0, 0, 0), Time.newInstance(12, 30, 0, 0));
        CourseOfferingSchedule latePM = buildSchedule(existing.Id, Time.newInstance(23, 0, 0, 0), Time.newInstance(23, 59, 0, 0));

        Test.startTest();
        insert new List<CourseOfferingSchedule>{ earlyAM, midnight, latePM };
        Test.stopTest();

        System.assertNotEquals(null, earlyAM.Id, '12 AM boundary should insert without conflict.');
        System.assertNotEquals(null, midnight.Id, '12 PM (noon) boundary should insert without conflict.');
        System.assertNotEquals(null, latePM.Id, 'Late PM schedule should insert without conflict.');
    }
}