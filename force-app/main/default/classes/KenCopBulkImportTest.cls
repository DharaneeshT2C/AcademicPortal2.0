@IsTest
private class KenCopBulkImportTest {
    @IsTest
    static void importsParticipantsWithAcademicTermEnrollment() {
        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY COP Import', '2034').create();
        AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(2034, '1', academicYear.Id).create();
        AcademicSession sessionRow = createSession('Semester 1', term.Id);
        LearningCourse course = createLearningCourse('AR/VR Systems', 'BTCS306');
        CourseOffering offering = createOffering('BTCS306 - AR/VR Systems - Lecture', sessionRow.Id, course.Id, 'Regular');
        Account institute = new KenTestDataFactory.AccountCreator('Ken42 Institute').create();
        Contact student = createStudent(institute.Id, 'student.cop@example.edu');
        AcademicTermEnrollment ate = new KenTestDataFactory.AcademicTermEnrollmentCreator(term.Id, student.Id, institute.Id).create();

        List<KenCopBulkImportController.NameOptionDTO> statuses = KenCopBulkImportController.getParticipationStatuses();
        String statusValue = statuses.isEmpty() ? 'Enrolled' : statuses[0].value;

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            buildRow(1, offering.Name, student.Email, statusValue, '2026-06-01', '2026-12-01', 'Regular')
        };

        Test.startTest();
        Id jobId = KenCopBulkImportController.startImport(JSON.serialize(rows), term.Id);
        Test.stopTest();

        System.assertNotEquals(null, jobId);
        System.assertEquals(0, KenCopBulkImportController.getImportErrors(jobId).size());

        CourseOfferingParticipant cop = [
            SELECT CourseOfferingId, ParticipantContactId, ParticipantAccountId, AcademicTermEnrollmentId, ParticipationStatus, StartDate, EndDate
            FROM CourseOfferingParticipant
            WHERE CourseOfferingId = :offering.Id
            AND AcademicTermEnrollmentId = :ate.Id
            LIMIT 1
        ];
        System.assertEquals(student.Id, cop.ParticipantContactId);
        System.assertEquals(institute.Id, cop.ParticipantAccountId);
        System.assertEquals(ate.Id, cop.AcademicTermEnrollmentId);
        System.assertEquals(statusValue, cop.ParticipationStatus);
        System.assertEquals(Date.newInstance(2026, 6, 1), cop.StartDate);
        System.assertEquals(Date.newInstance(2026, 12, 1), cop.EndDate);
    }

    @IsTest
    static void rejectsInvalidStatusAndMissingAte() {
        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY COP Reject', '2035').create();
        AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(2035, '1', academicYear.Id).create();
        AcademicSession sessionRow = createSession('Semester 2', term.Id);
        LearningCourse course = createLearningCourse('Immersive Lab', 'BTCS307');
        CourseOffering offering = createOffering('BTCS307 - Immersive Lab - Practical', sessionRow.Id, course.Id, 'Regular');
        Account institute = new KenTestDataFactory.AccountCreator('Ken42 Institute Reject').create();
        Contact missingAteStudent = createStudent(institute.Id, 'missing.ate@example.edu');
        Contact invalidStatusStudent = createStudent(institute.Id, 'invalid.status@example.edu');
        new KenTestDataFactory.AcademicTermEnrollmentCreator(term.Id, invalidStatusStudent.Id, institute.Id).create();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            buildRow(1, offering.Name, missingAteStudent.Email, 'Enrolled', '2026-06-01', '2026-12-01', 'Regular'),
            buildRow(2, offering.Name, invalidStatusStudent.Email, 'NotARealStatus', '2026-06-01', '2026-12-01', 'Regular'),
            buildRow(3, offering.Name, invalidStatusStudent.Email, 'Enrolled', '2026-06-01', '2026-12-01', 'WrongType')
        };

        Test.startTest();
        Id jobId = KenCopBulkImportController.startImport(JSON.serialize(rows), term.Id);
        Test.stopTest();

        System.assertNotEquals(null, jobId);
        System.assertEquals(0, [
            SELECT count()
            FROM CourseOfferingParticipant
            WHERE CourseOfferingId = :offering.Id
        ]);

        List<String> errors = KenCopBulkImportController.getImportErrors(jobId);
        System.assert(!errors.isEmpty());
        System.assert(containsText(errors, 'Academic Term Enrollment was not found'));
        System.assert(containsText(errors, 'Participation Status "NotARealStatus" is invalid.'));
        System.assert(containsText(errors, 'with Exam Type "WrongType" was not found'));
    }

    @IsTest
    static void returnsControllerOptionsForCurrentTerm() {
        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY COP Options', '2036').create();
        AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(2036, '1', academicYear.Id).create();
        AcademicTerm otherTerm = new KenTestDataFactory.AcademicTermCreator(2036, '2', academicYear.Id).create();
        AcademicSession sessionOne = createSession('Selected Session', term.Id);
        AcademicSession sessionTwo = createSession('Other Session', otherTerm.Id);
        LearningCourse course = createLearningCourse('Mixed Reality', 'BTCS308');
        createOffering('BTCS308 - Mixed Reality - Lecture', sessionOne.Id, course.Id, 'Regular');
        createOffering('BTCS308 - Mixed Reality - Practical', sessionTwo.Id, course.Id, 'Backlog');

        Test.startTest();
        List<KenCopBulkImportController.NameOptionDTO> offerings =
            KenCopBulkImportController.getCourseOfferingNamesForTerm(term.Id);
        List<KenCopBulkImportController.NameOptionDTO> statuses =
            KenCopBulkImportController.getParticipationStatuses();
        List<String> noErrors = KenCopBulkImportController.getImportErrors(null);
        Test.stopTest();

        System.assertEquals(1, offerings.size());
        System.assertEquals('BTCS308 - Mixed Reality - Lecture', offerings[0].value);
        System.assert(!statuses.isEmpty());
        System.assertEquals(0, noErrors.size());
    }

    @IsTest
    static void handlesEmptyControllerInputs() {
        Test.startTest();
        List<KenCopBulkImportController.NameOptionDTO> noOfferings =
            KenCopBulkImportController.getCourseOfferingNamesForTerm(null);
        List<String> noErrors = KenCopBulkImportController.getImportErrors(null);
        Boolean threwMissingTerm = false;
        Boolean threwMissingRows = false;
        try {
            KenCopBulkImportController.startImport('[]', null);
        } catch (AuraHandledException e) {
            threwMissingTerm = true;
        }
        try {
            AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY COP Empty', '2037').create();
            AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(2037, '1', academicYear.Id).create();
            KenCopBulkImportController.startImport('', term.Id);
        } catch (AuraHandledException e) {
            threwMissingRows = true;
        }
        Test.stopTest();

        System.assertEquals(0, noOfferings.size());
        System.assertEquals(0, noErrors.size());
        System.assertEquals(true, threwMissingTerm);
        System.assertEquals(true, threwMissingRows);
    }

    @IsTest
    static void importsParticipantWhenTypeIsBlank() {
        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY COP Type Match', '2038').create();
        AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(2038, '1', academicYear.Id).create();
        AcademicSession sessionRow = createSession('Semester 3', term.Id);
        LearningCourse course = createLearningCourse('Visual Computing', 'BTCS309');
        CourseOffering offering = createOffering('BTCS309 - Visual Computing - Practical', sessionRow.Id, course.Id, 'Regular');
        Account institute = new KenTestDataFactory.AccountCreator('Ken42 Institute Type Match').create();
        Contact student = createStudent(institute.Id, 'type.blank@example.edu');
        AcademicTermEnrollment ate = new KenTestDataFactory.AcademicTermEnrollmentCreator(term.Id, student.Id, institute.Id).create();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            buildRow(1, offering.Name, student.Email, 'Enrolled', '2026-06-01', '2026-12-01', '')
        };

        Test.startTest();
        Id jobId = KenCopBulkImportController.startImport(JSON.serialize(rows), term.Id);
        Test.stopTest();

        System.assertNotEquals(null, jobId);
        System.assertNotEquals(null, KenCopBulkImportController.getImportErrors(jobId));
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

    private static CourseOffering createOffering(String name, Id sessionId, Id courseId, String examType) {
        CourseOffering offering = new CourseOffering();
        offering.Name = name;
        offering.AcademicSessionId = sessionId;
        offering.LearningCourseId = courseId;
        offering.IsActive = true;
        offering.StartDate = Date.newInstance(2026, 6, 1);
        offering.EndDate = Date.newInstance(2026, 12, 1);
        Map<String, Schema.SObjectField> fields = CourseOffering.SObjectType.getDescribe().fields.getMap();
        for (String fieldName : new List<String>{'Exam_Type__c', 'ExamType__c', 'ExamType'}) {
            if (fields.containsKey(fieldName)) {
                offering.put(fieldName, examType);
                break;
            }
        }
        insert offering;
        return offering;
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

    private static Map<String, Object> buildRow(
        Integer rowNumber,
        String offeringName,
        String participantEmail,
        String participationStatus,
        String startDate,
        String endDate,
        String examTypeValue
    ) {
        Map<String, Object> row = new Map<String, Object>();
        row.put('RowNumber', String.valueOf(rowNumber));
        row.put('Course Offering Name', offeringName);
        row.put('Participant Email', participantEmail);
        row.put('Participation Status', participationStatus);
        row.put('Start Date', startDate);
        row.put('End Date', endDate);
        row.put('Exam Type', examTypeValue);
        return row;
    }

    private static Boolean containsText(List<String> lines, String text) {
        for (String line : lines) {
            if (line != null && line.contains(text)) {
                return true;
            }
        }
        return false;
    }
}