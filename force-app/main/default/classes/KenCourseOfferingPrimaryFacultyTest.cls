@isTest
public class KenCourseOfferingPrimaryFacultyTest {
  private static final String TEST_ALIAS = 'coursec';
    private static final String SESSION_NAME = 'CO Faculty Session';
    private static final String FACULTY_A = 'Faculty A';
    private static final String FACULTY_B = 'Faculty B';
    private static final String COURSE_1 = 'Faculty Course 1';
    private static final String COURSE_2 = 'Faculty Course 2';
    private static final String COURSE_3 = 'Faculty Course 3';

    @TestSetup
    static void createTestData() {
        new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias(TEST_ALIAS)
            .create();

        Contact facultyA = createFacultyContact(FACULTY_A);
        createFacultyContact(FACULTY_B);

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

        Id sessionId = session.Id;
        Id course1Id = createLearningCourse(COURSE_1);
        Id course2Id = createLearningCourse(COURSE_2);
        Id course3Id = createLearningCourse(COURSE_3);

        CourseOffering existingOffering =
            createCourseOffering('Existing Offering', sessionId, course1Id, facultyA.Id);
        insertSchedule(existingOffering.Id, Time.newInstance(10, 0, 0, 0), Time.newInstance(11, 0, 0, 0));

        CourseOffering boundaryOffering =
            createCourseOffering('Boundary Offering', sessionId, course2Id, facultyA.Id);
        insertSchedule(boundaryOffering.Id, Time.newInstance(11, 0, 0, 0), Time.newInstance(12, 0, 0, 0));

        createCourseOffering('Candidate Offering', sessionId, course3Id, getFacultyId(FACULTY_B));
    }

    @isTest
    static void blocksPrimaryFacultyUpdateWhenScheduleTimesOverlap() {
        CourseOffering candidateOffering = getOfferingByName('Candidate Offering');
        insertSchedule(candidateOffering.Id, Time.newInstance(10, 30, 0, 0), Time.newInstance(11, 30, 0, 0));

        Test.startTest();
        candidateOffering.PrimaryFacultyId = getFacultyId(FACULTY_A);
        Database.SaveResult saveResult = Database.update(candidateOffering, false);
        Test.stopTest();

        System.assertEquals(false, saveResult.isSuccess(), 'Expected overlap to block parent save.');
        assertHasConflictError(saveResult);
    }

    @isTest
    static void allowsPrimaryFacultyUpdateWhenTimesOnlyTouchBoundary() {
        Id sessionId = getSessionId();
        Id facultyAId = getFacultyId(FACULTY_A);
        Id facultyBId = getFacultyId(FACULTY_B);
        Id courseId = createLearningCourse('Boundary Candidate Course');

        CourseOffering candidateOffering =
            createCourseOffering('Boundary Candidate', sessionId, courseId, facultyBId);
        insertSchedule(candidateOffering.Id, Time.newInstance(12, 0, 0, 0), Time.newInstance(13, 0, 0, 0));

        Test.startTest();
        candidateOffering.PrimaryFacultyId = facultyAId;
        update candidateOffering;
        Test.stopTest();

        CourseOffering reloadedOffering = [
            SELECT Id, PrimaryFacultyId
            FROM CourseOffering
            WHERE Id = :candidateOffering.Id
        ];
        System.assertEquals(facultyAId, reloadedOffering.PrimaryFacultyId, 'Expected boundary times to be allowed.');
    }

    @isTest
    static void allowsParentUpdateWhenPrimaryFacultyDidNotChange() {
        CourseOffering existingOffering = getOfferingByName('Existing Offering');

        Test.startTest();
        existingOffering.Name = 'Existing Offering Updated';
        update existingOffering;
        Test.stopTest();

        CourseOffering reloadedOffering = [
            SELECT Name
            FROM CourseOffering
            WHERE Id = :existingOffering.Id
        ];
        System.assertEquals('Existing Offering Updated', reloadedOffering.Name, 'Expected non-faculty update to succeed.');
    }

    @isTest
    static void allowsPrimaryFacultyUpdateWhenOfferingHasNoSchedules() {
        Id courseId = createLearningCourse('No Schedule Course');
        CourseOffering candidateOffering =
            createCourseOffering('No Schedule Offering', getSessionId(), courseId, getFacultyId(FACULTY_B));

        Test.startTest();
        candidateOffering.PrimaryFacultyId = getFacultyId(FACULTY_A);
        update candidateOffering;
        Test.stopTest();

        CourseOffering reloadedOffering = [
            SELECT PrimaryFacultyId
            FROM CourseOffering
            WHERE Id = :candidateOffering.Id
        ];
        System.assertEquals(getFacultyId(FACULTY_A), reloadedOffering.PrimaryFacultyId, 'Expected save when no child schedules exist.');
    }

    @isTest
    static void blocksScheduleInsertWhenAnotherOfferingHasOverlap() {
        Id courseId = createLearningCourse('Insert Overlap Course');
        CourseOffering candidateOffering =
            createCourseOffering('Insert Overlap Offering', getSessionId(), courseId, getFacultyId(FACULTY_A));

        CourseOfferingSchedule candidateSchedule =
            buildSchedule(candidateOffering.Id, Time.newInstance(10, 30, 0, 0), Time.newInstance(11, 30, 0, 0));

        Test.startTest();
        Database.SaveResult saveResult = Database.insert(candidateSchedule, false);
        Test.stopTest();

        System.assertEquals(false, saveResult.isSuccess(), 'Expected overlapping child schedule insert to be blocked.');
        assertHasConflictError(saveResult);
    }

    @isTest
    static void blocksScheduleUpdateWhenAnotherOfferingHasOverlap() {
        Id courseId = createLearningCourse('Update Overlap Course');
        CourseOffering candidateOffering =
            createCourseOffering('Update Overlap Offering', getSessionId(), courseId, getFacultyId(FACULTY_A));
        CourseOfferingSchedule candidateSchedule =
            insertSchedule(candidateOffering.Id, Time.newInstance(12, 0, 0, 0), Time.newInstance(13, 0, 0, 0));

        Test.startTest();
        candidateSchedule.StartTime = Time.newInstance(10, 30, 0, 0);
        candidateSchedule.EndTime = Time.newInstance(11, 30, 0, 0);
        Database.SaveResult saveResult = Database.update(candidateSchedule, false);
        Test.stopTest();

        System.assertEquals(false, saveResult.isSuccess(), 'Expected overlapping child schedule update to be blocked.');
        assertHasConflictError(saveResult);
    }

    @isTest
    static void allowsScheduleInsertWhenTimesTouchButDoNotOverlap() {
        Id courseId = createLearningCourse('Allowed Child Course');
        CourseOffering candidateOffering =
            createCourseOffering('Allowed Child Offering', getSessionId(), courseId, getFacultyId(FACULTY_A));

        CourseOfferingSchedule candidateSchedule =
            buildSchedule(candidateOffering.Id, Time.newInstance(12, 0, 0, 0), Time.newInstance(13, 0, 0, 0));

        Test.startTest();
        insert candidateSchedule;
        Test.stopTest();

        System.assertNotEquals(null, candidateSchedule.Id, 'Expected non-overlapping child schedule insert to succeed.');
    }

    @isTest
    static void coversNullEmptyAndUnsavedInputForKenCourseOfferingPrimaryFaculty() {
        Test.startTest();
        KenCourseOfferingPrimaryFaculty.validatePrimaryFacultyScheduleConflicts(null, null);
        KenCourseOfferingPrimaryFaculty.validatePrimaryFacultyScheduleConflicts(
            new List<CourseOffering>(),
            new Map<Id, CourseOffering>()
        );

        CourseOffering unsavedOffering = new CourseOffering();
        unsavedOffering.Name = 'Unsaved Offering';
        unsavedOffering.PrimaryFacultyId = getFacultyId(FACULTY_A);
        KenCourseOfferingPrimaryFaculty.validatePrimaryFacultyScheduleConflicts(
            new List<CourseOffering>{ unsavedOffering },
            null
        );
        Test.stopTest();

        System.assertEquals(null, unsavedOffering.Id, 'Expected unsaved record branch to be exercised without error.');
    }

    private static void assertHasConflictError(Database.SaveResult saveResult) {
        System.assert(saveResult.getErrors().size() > 0, 'Expected at least one validation error.');
        System.assert(
            saveResult.getErrors()[0].getMessage().contains('already assigned'),
            'Expected faculty overlap error message.'
        );
    }

    private static Contact createFacultyContact(String lastName) {
        Account facultyAccount = new KenTestDataFactory.AccountCreator(lastName + ' Account').create();
        return new KenTestDataFactory.ContactCreator()
            .setAccount(facultyAccount.Id)
            .setLastName(lastName)
            .create();
    }

    private static Id createLearningCourse(String courseName) {
        Learning learning = new KenTestDataFactory.LearningCreator(courseName + ' Learning').create();
        LearningCourse course = new LearningCourse();
        course.Name = courseName;
        course.put('LearningId', learning.Id);
        insert course;
        return course.Id;
    }

    private static Id getFacultyId(String lastName) {
        return [
            SELECT Id
            FROM Contact
            WHERE LastName = :lastName
            LIMIT 1
        ].Id;
    }

    private static Id getSessionId() {
        return [
            SELECT Id
            FROM AcademicSession
            WHERE Name = :SESSION_NAME
            LIMIT 1
        ].Id;
    }

    private static CourseOffering getOfferingByName(String offeringName) {
        return [
            SELECT Id, Name, PrimaryFacultyId, AcademicSessionId, LearningCourseId
            FROM CourseOffering
            WHERE Name = :offeringName
            LIMIT 1
        ];
    }

    private static CourseOffering createCourseOffering(
        String offeringName,
        Id sessionId,
        Id courseId,
        Id facultyId
    ) {
        CourseOffering offering = new CourseOffering();
        offering.Name = offeringName;
        offering.AcademicSessionId = sessionId;
        offering.LearningCourseId = courseId;
        offering.PrimaryFacultyId = facultyId;
        insert offering;
        return offering;
    }

    private static CourseOfferingSchedule insertSchedule(Id offeringId, Time startTime, Time endTime) {
        CourseOfferingSchedule schedule = buildSchedule(offeringId, startTime, endTime);
        insert schedule;
        return schedule;
    }

    private static CourseOfferingSchedule buildSchedule(Id offeringId, Time startTime, Time endTime) {
        CourseOfferingSchedule schedule = new CourseOfferingSchedule();
        schedule.CourseOfferingId = offeringId;
        schedule.Description = 'Schedule ' + String.valueOf(startTime);
        schedule.StartTime = startTime;
        schedule.EndTime = endTime;
        schedule.IsMonday = true;
        schedule.IsTuesday = false;
        schedule.IsWednesday = false;
        schedule.IsThursday = false;
        schedule.IsFriday = false;
        schedule.IsSaturday = false;
        schedule.IsSunday = false;
        return schedule;
    }
}