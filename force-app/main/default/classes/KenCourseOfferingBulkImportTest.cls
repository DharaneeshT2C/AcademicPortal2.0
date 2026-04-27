@IsTest
private class KenCourseOfferingBulkImportTest {
    @IsTest
    static void importsOfferingsWithComponentCredits() {
        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY Bulk Import', '2030').create();
        AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(2030, '1', academicYear.Id).create();
        AcademicSession sessionRow = createSession('Semester 1', term.Id);
        LearningCourse course = createLearningCourse('MIT Workshop', 'MIT001');
        Contact faculty = createFaculty('bulk.faculty@example.edu');

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            buildRow(1, sessionRow.Name, course.CourseNumber, '1', 'Lecture', faculty.Email),
            buildRow(2, sessionRow.Name, course.CourseNumber, '1', 'Practical', faculty.Email)
        };

        Test.startTest();
        Id jobId = KenCourseOfferingBulkImportController.startImport(JSON.serialize(rows), term.Id);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch job id should be returned.');
        System.assertEquals(0, KenCourseOfferingBulkImportController.getImportErrors(jobId).size());

        List<CourseOffering> offerings = [
            SELECT AcademicSessionId, LearningCourseId, Course_Type__c, Credit__c, IsActive, RecordType.DeveloperName
            FROM CourseOffering
            WHERE AcademicSessionId = :sessionRow.Id
            ORDER BY Course_Type__c
        ];
        System.assertEquals(2, offerings.size(), 'Lecture and Practical should both be imported.');

        Map<String, CourseOffering> offeringByType = new Map<String, CourseOffering>();
        for (CourseOffering offering : offerings) {
            offeringByType.put(offering.Course_Type__c, offering);
            System.assertEquals(true, offering.IsActive, 'Imported offerings should be active.');
            System.assertEquals('Default', offering.RecordType.DeveloperName, 'Imported offerings should use the Default record type.');
        }
        System.assertEquals(3, offeringByType.get('Lecture').Credit__c);
        System.assertEquals(1, offeringByType.get('Practical').Credit__c);
    }

    @IsTest
    static void rejectsDuplicateAndMismatchedComponents() {
        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY Bulk Reject', '2031').create();
        AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(2031, '1', academicYear.Id).create();
        AcademicSession sessionRow = createSession('Semester 2', term.Id);
        LearningCourse course = createLearningCourse('MIT Duplicate Workshop', 'MIT002');
        Contact faculty = createFaculty('bulk.reject@example.edu');

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            buildRow(1, sessionRow.Name, course.CourseNumber, '1', 'Lecture', faculty.Email),
            buildRow(2, sessionRow.Name, course.CourseNumber, '2', 'Lecture', faculty.Email),
            buildRow(3, sessionRow.Name, course.CourseNumber, '1', 'Studio', faculty.Email)
        };

        Test.startTest();
        Id jobId = KenCourseOfferingBulkImportController.startImport(JSON.serialize(rows), term.Id);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch job id should be returned.');
        List<String> importErrors = KenCourseOfferingBulkImportController.getImportErrors(jobId);
        System.assert(!importErrors.isEmpty(), 'Controller should return import errors for the completed job.');
        System.assertEquals(1, [
            SELECT count()
            FROM CourseOffering
            WHERE AcademicSessionId = :sessionRow.Id
            AND LearningCourseId = :course.Id
        ]);

        List<Audit_Log__c> logs = [
            SELECT Error_Message__c
            FROM Audit_Log__c
            WHERE RecordId__c = :String.valueOf(jobId)
            ORDER BY CreatedDate
        ];
        System.assert(!logs.isEmpty(), 'Rejected rows should be written to audit logs.');
        System.assert(containsLogMessage(logs, 'Duplicate row'), 'Duplicate course/type should be logged.');
        System.assert(containsLogMessage(logs, 'does not match a configured component'), 'Mismatched component should be logged.');
    }

    @IsTest
    static void returnsSessionsForCurrentTermOnly() {
        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY Session Options', '2032').create();
        AcademicTerm selectedTerm = new KenTestDataFactory.AcademicTermCreator(2032, '1', academicYear.Id).create();
        AcademicTerm otherTerm = new KenTestDataFactory.AcademicTermCreator(2032, '2', academicYear.Id).create();
        createSession('Selected Session', selectedTerm.Id);
        createSession('Other Session', otherTerm.Id);

        Test.startTest();
        List<KenCourseOfferingBulkImportController.SessionOptionDTO> options =
            KenCourseOfferingBulkImportController.getAcademicSessionsForTerm(selectedTerm.Id);
        Test.stopTest();

        System.assertEquals(1, options.size());
        System.assertEquals('Selected Session', options[0].name);
    }

    @IsTest
    static void handlesEmptyControllerInputs() {
        Test.startTest();
        List<KenCourseOfferingBulkImportController.SessionOptionDTO> options =
            KenCourseOfferingBulkImportController.getAcademicSessionsForTerm(null);
        List<String> errors = KenCourseOfferingBulkImportController.getImportErrors(null);
        Boolean threwMissingTerm = false;
        Boolean threwMissingRows = false;
        try {
            KenCourseOfferingBulkImportController.startImport('[]', null);
        } catch (AuraHandledException e) {
            threwMissingTerm = true;
        }
        try {
            AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY Empty Inputs', '2033').create();
            AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(2033, '1', academicYear.Id).create();
            KenCourseOfferingBulkImportController.startImport('', term.Id);
        } catch (AuraHandledException e) {
            threwMissingRows = true;
        }
        Test.stopTest();

        System.assertEquals(0, options.size());
        System.assertEquals(0, errors.size());
        System.assertEquals(true, threwMissingTerm);
        System.assertEquals(true, threwMissingRows);
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
        course.Credit_1__c = 3;
        course.Course_Type_2__c = 'Practical';
        course.Credit_2__c = 1;
        course.put('LearningId', learning.Id);
        insert course;
        return course;
    }

    private static Contact createFaculty(String email) {
        Account account = new KenTestDataFactory.AccountCreator('Bulk Faculty Account').create();
        Contact contactRow = new KenTestDataFactory.ContactCreator()
            .setAccount(account.Id)
            .setLastName('Bulk Faculty')
            .create();
        contactRow.Email = email;
        update contactRow;
        return contactRow;
    }

    private static Map<String, Object> buildRow(
        Integer rowNumber,
        String sessionName,
        String courseCode,
        String sectionNumber,
        String courseType,
        String facultyEmail
    ) {
        Map<String, Object> row = new Map<String, Object>();
        row.put('RowNumber', String.valueOf(rowNumber));
        row.put('Academic Session', sessionName);
        row.put('Course Code', courseCode);
        row.put('Section Number', sectionNumber);
        row.put('Course Type', courseType);
        row.put('Faculty Email', facultyEmail);
        row.put('Enrollment Capacity', '60');
        row.put('Waitlist Capacity', '10');
        row.put('Start Date', String.valueOf(Date.today()));
        row.put('End Date', String.valueOf(Date.today().addMonths(4)));
        return row;
    }

    private static Boolean containsLogMessage(List<Audit_Log__c> logs, String text) {
        for (Audit_Log__c log : logs) {
            if (log.Error_Message__c != null && log.Error_Message__c.contains(text)) {
                return true;
            }
        }
        return false;
    }
}