@IsTest
private class KenTimetableManagementControllerTest {
    @IsTest
    static void returnsActiveTermsAndOfferingsForSelectedTerm() {
        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY 2026', '2026').create();

        AcademicTerm activeTerm = new KenTestDataFactory.AcademicTermCreator(2026, '1', academicYear.Id).create();
        AcademicTerm inactiveTerm = new KenTestDataFactory.AcademicTermCreator(2027, '2', academicYear.Id).create();
        updateTerms(new List<AcademicTerm>{ activeTerm, inactiveTerm });

        AcademicSession activeSession = createSession('Session A', activeTerm.Id, true);
        AcademicSession inactiveSession = createSession('Session B', inactiveTerm.Id, true);

        Id courseOneId = createLearningCourse('Algorithms', 'CS101');
        Id courseTwoId = createLearningCourse('Thermodynamics', 'ME201');

        Contact faculty = createFaculty('Johnson');
        String lectureType = getCourseTypeValue('Lecture');
        String labType = getCourseTypeValue('Lab');

        insertOffering('Algorithms Offering', activeSession.Id, courseOneId, faculty.Id, true, lectureType);
        insertOffering('Thermo Offering', inactiveSession.Id, courseTwoId, faculty.Id, true, labType);

        Test.startTest();
        List<KenTimetableManagementController.TermOptionDTO> terms =
            KenTimetableManagementController.getActiveTerms();
        List<KenTimetableManagementController.CourseOfferingRowDTO> offerings =
            KenTimetableManagementController.getCourseOfferingsByTerm(activeTerm.Id);
        Test.stopTest();

        System.assertEquals(1, terms.size(), 'Only active terms should be returned.');
        System.assertEquals(activeTerm.Id, terms[0].id);
        System.assertEquals(1, offerings.size(), 'Only offerings for the selected term should be returned.');
        System.assertEquals('Algorithms Offering', offerings[0].name);
        System.assertEquals(activeTerm.Id, offerings[0].termId);
        System.assertEquals('Session A', offerings[0].sessionName);
        System.assertEquals('Algorithms', offerings[0].courseName);
        System.assertEquals('CS101', offerings[0].courseCode);
        Contact insertedFaculty = [SELECT Name FROM Contact WHERE Id = :faculty.Id LIMIT 1];
        System.assertEquals(insertedFaculty.Name, offerings[0].facultyName);
        System.assertEquals('Active', offerings[0].status);
        System.assertEquals(lectureType, offerings[0].type);
    }

    @IsTest
    static void returnsEmptyListWhenTermIsMissing() {
        Test.startTest();
        List<KenTimetableManagementController.CourseOfferingRowDTO> offerings =
            KenTimetableManagementController.getCourseOfferingsByTerm(null);
        Test.stopTest();

        System.assertEquals(0, offerings.size());
    }

    @IsTest
    static void appendsEndDateToOpenEndedTemplateRecurrenceRule() {
        String normalized = KenTimetableManagementController.normalizeTemplateRecurrencePattern(
            'RRULE:FREQ=WEEKLY;INTERVAL=1',
            Date.newInstance(2026, 4, 24)
        );

        System.assertEquals('RRULE:FREQ=WEEKLY;INTERVAL=1;UNTIL=20260424T235959Z', normalized);
    }

    @IsTest
    static void leavesTerminatedTemplateRecurrenceRulesUnchanged() {
        System.assertEquals(
            'RRULE:FREQ=WEEKLY;INTERVAL=1;COUNT=10',
            KenTimetableManagementController.normalizeTemplateRecurrencePattern(
                'RRULE:FREQ=WEEKLY;INTERVAL=1;COUNT=10',
                Date.newInstance(2026, 4, 24)
            )
        );
        System.assertEquals(
            'RRULE:FREQ=WEEKLY;INTERVAL=1;UNTIL=20260424',
            KenTimetableManagementController.normalizeTemplateRecurrencePattern(
                'RRULE:FREQ=WEEKLY;INTERVAL=1;UNTIL=20260424',
                Date.newInstance(2026, 5, 1)
            )
        );
    }

    @IsTest
    static void returnsDynamicBuilderDataAndSavesSchedules() {
        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY 2028', '2028').create();
        AcademicTerm activeTerm = new KenTestDataFactory.AcademicTermCreator(2028, '1', academicYear.Id).create();
        updateTerms(new List<AcademicTerm>{ activeTerm });

        AcademicSession activeSession = createSession('Session Builder', activeTerm.Id, true);
        Id scheduledCourseId = createLearningCourse('Physics', 'PH101');
        Id backlogCourseId = createLearningCourse('Chemistry', 'CH101');
        Contact faculty = createFaculty('Builder');
        String lectureType = getCourseTypeValue('Lecture');
        String labType = getCourseTypeValue('Lab');

        Id scheduledOfferingId = insertOffering('Physics Offering', activeSession.Id, scheduledCourseId, faculty.Id, true, lectureType);
        Id backlogOfferingId = insertOffering('Chemistry Offering', activeSession.Id, backlogCourseId, faculty.Id, true, labType);
        insert buildSchedule(scheduledOfferingId, Time.newInstance(9, 0, 0, 0), Time.newInstance(10, 0, 0, 0), true, false);

        Test.startTest();
        KenTimetableManagementController.BuilderDataDTO builderData =
            KenTimetableManagementController.getTimetableBuilderData(activeTerm.Id, backlogOfferingId);

        List<Object> saveRows = new List<Object>{
            buildSaveRow('Tuesday', '11:00', '12:00'),
            buildSaveRow('Thursday', '14:00', '15:00')
        };
        KenTimetableManagementController.SaveScheduleResultDTO saveResult =
            KenTimetableManagementController.saveCourseOfferingSchedules(backlogOfferingId, JSON.serialize(saveRows));
        Test.stopTest();

        System.assertEquals(activeTerm.Id, builderData.academicTermId);
        System.assertEquals(backlogOfferingId, builderData.focusCourseOfferingId);
        System.assertEquals(2, builderData.offerings.size(), 'Both offerings should be present in the builder.');
        System.assertEquals(1, builderData.scheduledEntries.size(), 'Existing schedule rows should be expanded into builder entries.');
        System.assertEquals(true, saveResult.success);
        System.assertEquals(2, saveResult.savedCount);

        List<CourseOfferingSchedule> savedSchedules = [
            SELECT CourseOfferingId, StartTime, EndTime, IsTuesday, IsThursday
            FROM CourseOfferingSchedule
            WHERE CourseOfferingId = :backlogOfferingId
            ORDER BY StartTime
        ];
        System.assertEquals(2, savedSchedules.size());
        System.assertEquals(true, savedSchedules[0].IsTuesday);
        System.assertEquals(true, savedSchedules[1].IsThursday);
    }

    private static void updateTerms(List<AcademicTerm> terms) {
        Map<String, Schema.SObjectField> fields = AcademicTerm.SObjectType.getDescribe().fields.getMap();
        List<AcademicTerm> updates = new List<AcademicTerm>();

        for (Integer i = 0; i < terms.size(); i++) {
            AcademicTerm updateRow = new AcademicTerm(Id = terms[i].Id);
            if (fields.containsKey('IsActive')) {
                updateRow.put('IsActive', i == 0);
            }
            if (fields.containsKey('Name')) {
                updateRow.Name = i == 0 ? 'Fall 2026' : 'Spring 2027';
            }
            updates.add(updateRow);
        }

        update updates;
    }

    private static AcademicSession createSession(String name, Id termId, Boolean isActive) {
        AcademicSession session = new AcademicSession();
        session.Name = name;
        session.Type = KenConstantController.CADENCE_SEMESTER;
        session.Season = KenConstantController.SEASON_FALL;
        session.Sequence__c = '1';
        session.ClassStartDate = Date.today();
        session.AcademicTermId = termId;
        session.IsActive = isActive;
        insert session;
        return session;
    }

    private static Id createLearningCourse(String courseName, String courseNumber) {
        Learning learning = new KenTestDataFactory.LearningCreator(courseName + ' Learning').create();
        LearningCourse course = new LearningCourse();
        course.Name = courseName;
        course.CourseNumber = courseNumber;
        course.put('LearningId', learning.Id);
        insert course;
        return course.Id;
    }

    private static Contact createFaculty(String lastName) {
        Account account = new KenTestDataFactory.AccountCreator(lastName + ' Account').create();
        return new KenTestDataFactory.ContactCreator()
            .setAccount(account.Id)
            .setLastName(lastName)
            .create();
    }

    private static Id insertOffering(
        String name,
        Id sessionId,
        Id courseId,
        Id facultyId,
        Boolean isActive,
        String offeringType
    ) {
        CourseOffering offering = new CourseOffering();
        offering.Name = name;
        offering.AcademicSessionId = sessionId;
        offering.LearningCourseId = courseId;
        offering.PrimaryFacultyId = facultyId;
        offering.IsActive = isActive;
        Map<String, Schema.SObjectField> fields = CourseOffering.SObjectType.getDescribe().fields.getMap();
        if (fields.containsKey('Course_Type__c') && fields.get('Course_Type__c').getDescribe().isCreateable()) {
            offering.put('Course_Type__c', offeringType);
        }
        if (fields.containsKey('OfferingType__c') && fields.get('OfferingType__c').getDescribe().isCreateable()) {
            offering.put('OfferingType__c', getPicklistValue('OfferingType__c', offeringType, offeringType));
        }
        insert offering;
        return offering.Id;
    }

    private static String getCourseTypeValue(String preferredValue) {
        return getPicklistValue('Course_Type__c', preferredValue, 'Standard');
    }

    private static String getPicklistValue(String fieldApiName, String preferredValue, String fallbackValue) {
        Map<String, Schema.SObjectField> fields = CourseOffering.SObjectType.getDescribe().fields.getMap();
        if (!fields.containsKey(fieldApiName)) {
            return fallbackValue;
        }

        Schema.DescribeFieldResult describe = fields.get(fieldApiName).getDescribe();
        if (!describe.isAccessible()) {
            return fallbackValue;
        }
        List<Schema.PicklistEntry> entries = describe.getPicklistValues();
        if (entries.isEmpty()) {
            return preferredValue;
        }

        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive() && (entry.getValue() == preferredValue || entry.getLabel() == preferredValue)) {
                return entry.getValue();
            }
        }
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return fallbackValue;
    }

    private static CourseOfferingSchedule buildSchedule(
        Id offeringId,
        Time startTime,
        Time endTime,
        Boolean isMonday,
        Boolean isTuesday
    ) {
        CourseOfferingSchedule schedule = new CourseOfferingSchedule();
        schedule.CourseOfferingId = offeringId;
        schedule.Description = 'Builder schedule';
        schedule.StartTime = startTime;
        schedule.EndTime = endTime;
        schedule.IsMonday = isMonday;
        schedule.IsTuesday = isTuesday;
        schedule.IsWednesday = false;
        schedule.IsThursday = false;
        schedule.IsFriday = false;
        schedule.IsSaturday = false;
        schedule.IsSunday = false;
        return schedule;
    }

    private static Map<String, Object> buildSaveRow(
        String dayName,
        String startTime,
        String endTime
    ) {
        Map<String, Object> row = new Map<String, Object>();
        row.put('dayName', dayName);
        row.put('startTime', startTime);
        row.put('endTime', endTime);
        return row;
    }
}