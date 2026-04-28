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


    @IsTest
    static void coversTemplateLocationDetailAndCustomActivityPaths() {
        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY 2029', '2029').create();
        AcademicTerm activeTerm = new KenTestDataFactory.AcademicTermCreator(2029, '1', academicYear.Id).create();
        updateTerms(new List<AcademicTerm>{ activeTerm });
        AcademicSession session = createSession('Template Session', activeTerm.Id, true);
        Contact faculty = createFaculty('TemplateFaculty');
        Id courseId = createLearningCourse('Databases', 'CS220');
        Id offeringId = insertOffering(
            'Database Offering',
            session.Id,
            courseId,
            faculty.Id,
            true,
            getCourseTypeValue('Lecture')
        );
        insert buildSchedule(
            offeringId,
            Time.newInstance(8, 0, 0, 0),
            Time.newInstance(9, 0, 0, 0),
            true,
            false
        );
        createLocation('Room 101');

        Test.startTest();
        List<KenTimetableManagementController.LocationOptionDTO> locations =
            KenTimetableManagementController.getLocationOptions();
        KenTimetableManagementController.TemplateCreateResultDTO templateResult =
            KenTimetableManagementController.createScheduleTemplate(
                'Morning Template',
                'RRULE:FREQ=WEEKLY;INTERVAL=1',
                String.valueOf(Date.today()),
                String.valueOf(Date.today().addDays(7)),
                '08:00',
                '09:00',
                'Template created by test',
                true,
                false,
                false,
                false,
                false,
                false,
                false
            );
        List<KenTimetableManagementController.TemplateOptionDTO> templates =
            KenTimetableManagementController.getScheduleTemplateOptions();
        KenTimetableManagementController.TemplateOptionDTO templateOption =
            KenTimetableManagementController.getScheduleTemplateOption(templateResult.id);
        List<KenTimetableManagementController.BuilderScheduleEntryDTO> templateEntries =
            KenTimetableManagementController.getScheduleTemplateEntries(templateResult.id, offeringId);
        KenTimetableManagementController.SaveScheduleResultDTO templateSaveResult =
            KenTimetableManagementController.saveCourseOfferingSchedules(
                offeringId,
                JSON.serialize(new List<Object>{ buildSaveRow('Friday', '12:00', '13:00', faculty.Id, 'Exam') }),
                templateResult.id,
                'RRULE:FREQ=WEEKLY;INTERVAL=1',
                String.valueOf(Date.today()),
                String.valueOf(Date.today().addDays(14)),
                null,
                null
            );
        KenTimetableManagementController.TimetableDetailDataDTO detail =
            KenTimetableManagementController.getTimetableDetailData(offeringId);
        Test.stopTest();

        System.assert(!locations.isEmpty(), 'At least one location should be returned.');
        System.assertNotEquals(null, templateResult.id, 'Template creation should return an Id.');
        System.assert(!templates.isEmpty(), 'Template list should include created template data.');
        System.assertEquals(templateResult.id, templateOption.id);
        System.assertEquals(1, templateEntries.size(), 'Template row should expand into a Monday entry.');
        System.assertEquals(true, templateSaveResult.success);
        System.assertEquals(1, detail.totalSessions);
    }


    @IsTest
    static void coversProgramPlanPreviewPublishAndLockBranches() {
        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY 2030', '2030').create();
        AcademicTerm activeTerm = new KenTestDataFactory.AcademicTermCreator(2030, '1', academicYear.Id).create();
        updateTerms(new List<AcademicTerm>{ activeTerm });
        AcademicSession session = createSession('Plan Session', activeTerm.Id, true);
        Contact faculty = createFaculty('PlanFaculty');
        Id courseId = createLearningCourse('Operating Systems', 'CS330');
        Id offeringId = insertOffering(
            'OS Offering',
            session.Id,
            courseId,
            faculty.Id,
            true,
            getCourseTypeValue('Lecture')
        );
        insert buildSchedule(
            offeringId,
            Time.newInstance(10, 0, 0, 0),
            Time.newInstance(11, 0, 0, 0),
            false,
            true
        );
        Id planId = createProgramPlan();
        insertJunction(planId, offeringId, 'Core');

        Test.startTest();
        List<KenTimetableManagementController.ProgramPlanOptionDTO> plans =
            KenTimetableManagementController.getProgramPlansForTerm(activeTerm.Id);
        KenTimetableManagementController.ProgramPlanWeeklyPreviewDTO preview =
            KenTimetableManagementController.getProgramPlanWeeklyPreview(activeTerm.Id, planId);
        KenTimetableManagementController.TimetableActionResultDTO publishResult;
        if (Program_Plan_Course_Junction__c.SObjectType.getDescribe().fields.getMap().containsKey('Timetable_Published__c')) {
            publishResult = KenTimetableManagementController.publishProgramPlanTimetable(activeTerm.Id, planId);
        }
        tryToggleLock(offeringId);
        Test.stopTest();

        System.assertEquals(1, plans.size(), 'Program plan should be discoverable for the term.');
        System.assertEquals(planId, plans[0].id);
        System.assertEquals(1, preview.scheduledOfferingCount);
        System.assertEquals(1, preview.totalSessions);
        if (publishResult != null) {
            System.assertEquals(true, publishResult.success);
        }
    }


    @IsTest
    static void savesWeekSpecificCustomActivityAndCoversValidationBranches() {
        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY 2031', '2031').create();
        AcademicTerm activeTerm = new KenTestDataFactory.AcademicTermCreator(2031, '1', academicYear.Id).create();
        updateTerms(new List<AcademicTerm>{ activeTerm });
        AcademicSession session = createSession('Validation Session', activeTerm.Id, true);
        Contact faculty = createFaculty('ValidationFaculty');
        Id courseId = createLearningCourse('Networks', 'CS440');
        Id offeringId = insertOffering(
            'Networks Offering',
            session.Id,
            courseId,
            faculty.Id,
            true,
            getCourseTypeValue('Lecture')
        );

        Date weekStart = Date.today().toStartOfWeek().addDays(1);
        Date weekEnd = weekStart.addDays(6);
        List<Object> saveRows = new List<Object>{
            buildSaveRow('Monday', '09:00', '10:00', faculty.Id, 'Lesson'),
            buildSaveRow('Wednesday', '09:00', '10:00', faculty.Id, 'Project')
        };

        Test.startTest();
        Boolean detailErrorRaised = false;
        try {
            KenTimetableManagementController.getTimetableDetailData(null);
        } catch (AuraHandledException handledException) {
            detailErrorRaised = true;
            System.assertNotEquals(null, handledException.getMessage());
        }
        Boolean missingOfferingErrorRaised = false;
        try {
            KenTimetableManagementController.saveCourseOfferingSchedules(null, '[]');
        } catch (AuraHandledException handledException) {
            missingOfferingErrorRaised = true;
            System.assertNotEquals(null, handledException.getMessage());
        }
        Boolean invalidTimeErrorRaised = false;
        try {
            KenTimetableManagementController.saveCourseOfferingSchedules(
                offeringId,
                JSON.serialize(new List<Object>{ buildSaveRow('Monday', '09:00', '08:00') })
            );
        } catch (AuraHandledException handledException) {
            invalidTimeErrorRaised = true;
            System.assertNotEquals(null, handledException.getMessage());
        }
        Boolean duplicateDayErrorRaised = false;
        try {
            KenTimetableManagementController.saveCourseOfferingSchedules(
                offeringId,
                JSON.serialize(new List<Object>{
                    buildSaveRow('Monday', '09:00', '10:00'),
                    buildSaveRow('Monday', '10:00', '11:00')
                })
            );
        } catch (AuraHandledException handledException) {
            duplicateDayErrorRaised = true;
            System.assertNotEquals(null, handledException.getMessage());
        }
        KenTimetableManagementController.SaveScheduleResultDTO saveResult =
            KenTimetableManagementController.saveCourseOfferingSchedules(
                offeringId,
                JSON.serialize(saveRows),
                null,
                null,
                null,
                null,
                String.valueOf(weekStart),
                String.valueOf(weekEnd)
            );
        Test.stopTest();

        System.assertEquals(true, detailErrorRaised);
        System.assertEquals(true, missingOfferingErrorRaised);
        System.assertEquals(true, invalidTimeErrorRaised);
        System.assertEquals(true, duplicateDayErrorRaised);
        System.assertEquals(true, saveResult.success);
        System.assertEquals(2, saveResult.savedCount, 'Different Activities should be saved as separate schedule rows.');
        List<CourseOfferingSchedule> savedSchedules = [
            SELECT StartDate, EndDate, Activity_Type__c, IsMonday, IsWednesday
            FROM CourseOfferingSchedule
            WHERE CourseOfferingId = :offeringId
            ORDER BY Activity_Type__c
        ];
        System.assertEquals(2, savedSchedules.size());
        System.assertEquals(weekStart, savedSchedules[0].StartDate);
        System.assertEquals(weekEnd, savedSchedules[0].EndDate);
        System.assertEquals('Lesson', savedSchedules[0].Activity_Type__c);
        System.assertEquals(true, savedSchedules[0].IsMonday);
        System.assertEquals('Project', savedSchedules[1].Activity_Type__c);
        System.assertEquals(true, savedSchedules[1].IsWednesday);
    }


    @IsTest
    static void coversGuardClausesAndBuilderEmptyStates() {
        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY 2032', '2032').create();
        AcademicTerm termWithoutSessions = new KenTestDataFactory.AcademicTermCreator(2032, '1', academicYear.Id).create();
        updateTerms(new List<AcademicTerm>{ termWithoutSessions });
        Id planId = createProgramPlan();
        KenTimetableManagementController.TemplateCreateResultDTO duplicateTemplate =
            KenTimetableManagementController.createScheduleTemplate(
                'Duplicate Template',
                'RRULE:FREQ=WEEKLY;INTERVAL=1',
                String.valueOf(Date.today()),
                String.valueOf(Date.today().addDays(7)),
                '07:00',
                '08:00',
                'Template for duplicate validation',
                true,
                false,
                false,
                false,
                false,
                false,
                false
            );

        Test.startTest();
        System.assertEquals(null, KenTimetableManagementController.getScheduleTemplateOption(null));
        System.assertEquals(0, KenTimetableManagementController.getScheduleTemplateEntries(null, null).size());
        System.assertEquals(1, KenTimetableManagementController.getScheduleTemplateEntries(duplicateTemplate.id, null).size());
        System.assertEquals(0, KenTimetableManagementController.getProgramPlansForTerm(null).size());
        System.assertEquals(0, KenTimetableManagementController.getTimetableBuilderData(null, null).offerings.size());
        System.assert(
            !KenTimetableManagementController.getTimetableBuilderData(termWithoutSessions.Id, null).validation.warnings.isEmpty(),
            'Term with no sessions should return a warning.'
        );
        System.assert(
            !KenTimetableManagementController.getTimetableBuilderData(termWithoutSessions.Id, null, planId).validation.warnings.isEmpty(),
            'Plan with no offerings should return a warning.'
        );
        expectTemplateNameError();
        expectTemplateTimeRequiredError();
        expectTemplateInvalidTimeError();
        expectTemplateNoDayError();
        expectDuplicateTemplateError();
        expectPublishEmptyPlanError(termWithoutSessions.Id, planId);
        expectPublishMissingArgumentError();
        expectToggleMissingArgumentError();
        Test.stopTest();
    }


    @IsTest
    static void coversSaveUpdateDeleteAndOverlapBranches() {
        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY 2033', '2033').create();
        AcademicTerm activeTerm = new KenTestDataFactory.AcademicTermCreator(2033, '1', academicYear.Id).create();
        updateTerms(new List<AcademicTerm>{ activeTerm });
        AcademicSession session = createSession('Overlap Session', activeTerm.Id, true);
        Contact faculty = createFaculty('OverlapFaculty');
        Contact mappedFaculty = createFaculty('MappedFaculty');
        Id courseOneId = createLearningCourse('Security', 'CS550');
        Id courseTwoId = createLearningCourse('AI', 'CS560');
        Id firstOfferingId = insertOffering('Security Offering', session.Id, courseOneId, faculty.Id, true, getCourseTypeValue('Lecture'));
        Id secondOfferingId = insertOffering('AI Offering', session.Id, courseTwoId, faculty.Id, true, getCourseTypeValue('Lecture'));
        insertFacultyParticipant(secondOfferingId, mappedFaculty.Id);
        insert buildSchedule(firstOfferingId, Time.newInstance(13, 0, 0, 0), Time.newInstance(14, 0, 0, 0), false, true);

        CourseOfferingSchedule existingSchedule = buildSchedule(
            secondOfferingId,
            Time.newInstance(9, 0, 0, 0),
            Time.newInstance(10, 0, 0, 0),
            true,
            false
        );
        existingSchedule.Faculty_Contact__c = mappedFaculty.Id;
        insert existingSchedule;

        Test.startTest();
        KenTimetableManagementController.SaveScheduleResultDTO blankSaveResult =
            KenTimetableManagementController.saveCourseOfferingSchedules(secondOfferingId, '');
        expectSaveError(secondOfferingId, JSON.serialize(new List<Object>{ null }), null, null);
        expectSaveError(secondOfferingId, JSON.serialize(new List<Object>{ buildSaveRow('', '09:00', '10:00') }), null, null);
        expectSaveError(secondOfferingId, JSON.serialize(new List<Object>{ buildSaveRow('Funday', '09:00', '10:00') }), null, null);
        expectSaveError(secondOfferingId, JSON.serialize(new List<Object>{ buildSaveRow('Monday', '09:00', '10:00') }), String.valueOf(Date.today()), null);
        expectSaveError(
            secondOfferingId,
            JSON.serialize(new List<Object>{ buildSaveRow('Monday', '09:00', '10:00') }),
            String.valueOf(Date.today()),
            String.valueOf(Date.today().addDays(-1))
        );
        expectSaveError(
            secondOfferingId,
            JSON.serialize(new List<Object>{ buildSaveRow('Tuesday', '13:30', '14:30', faculty.Id, 'Lesson') }),
            null,
            null
        );
        KenTimetableManagementController.SaveScheduleResultDTO updateResult =
            KenTimetableManagementController.saveCourseOfferingSchedules(
                secondOfferingId,
                JSON.serialize(new List<Object>{
                    buildSaveRow(existingSchedule.Id, 'Wednesday', '15:00', '16:00', faculty.Id, 'Project')
                })
            );
        KenTimetableManagementController.TimetableDetailDataDTO detail =
            KenTimetableManagementController.getTimetableDetailData(secondOfferingId);
        Test.stopTest();

        System.assertEquals(true, blankSaveResult.success);
        System.assertEquals(true, updateResult.success);
        System.assertEquals(1, detail.totalSessions);
        List<CourseOfferingSchedule> schedules = [
            SELECT IsMonday, IsWednesday, StartTime, EndTime, Faculty_Contact__c, Activity_Type__c
            FROM CourseOfferingSchedule
            WHERE CourseOfferingId = :secondOfferingId
        ];
        System.assertEquals(1, schedules.size(), 'Existing schedule should be updated, not duplicated.');
        System.assertEquals(false, schedules[0].IsMonday);
        System.assertEquals(true, schedules[0].IsWednesday);
        System.assertEquals(faculty.Id, schedules[0].Faculty_Contact__c);
        System.assertEquals('Project', schedules[0].Activity_Type__c);
    }


    @IsTest
    static void coversElectiveValidationWarnings() {
        AcademicYear academicYear = new KenTestDataFactory.AcademicYearCreator('AY 2034', '2034').create();
        AcademicTerm activeTerm = new KenTestDataFactory.AcademicTermCreator(2034, '1', academicYear.Id).create();
        updateTerms(new List<AcademicTerm>{ activeTerm });
        AcademicSession session = createSession('Elective Session', activeTerm.Id, true);
        Contact faculty = createFaculty('ElectiveFaculty');
        Id firstCourseId = createLearningCourse('Elective One', 'EL101');
        Id secondCourseId = createLearningCourse('Elective Two', 'EL102');
        Id firstOfferingId = insertOffering('Elective One Offering', session.Id, firstCourseId, faculty.Id, true, getCourseTypeValue('Lecture'));
        Id secondOfferingId = insertOffering('Elective Two Offering', session.Id, secondCourseId, faculty.Id, true, getCourseTypeValue('Lecture'));
        insert buildSchedule(firstOfferingId, Time.newInstance(9, 0, 0, 0), Time.newInstance(10, 0, 0, 0), true, false);
        insert buildSchedule(secondOfferingId, Time.newInstance(11, 0, 0, 0), Time.newInstance(12, 0, 0, 0), true, false);
        Id planId = createProgramPlan();
        insertJunction(planId, firstOfferingId, 'Elective');
        insertJunction(planId, secondOfferingId, 'Elective');

        Test.startTest();
        KenTimetableManagementController.BuilderDataDTO data =
            KenTimetableManagementController.getTimetableBuilderData(activeTerm.Id, null, planId);
        Test.stopTest();

        System.assertEquals(2, data.scheduledEntries.size());
        System.assert(!data.validation.warnings.isEmpty(), 'Different elective times should create a validation warning.');
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
        setActivityType(schedule, 'Lesson');
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

    private static Map<String, Object> buildSaveRow(
        Id scheduleId,
        String dayName,
        String startTime,
        String endTime,
        Id facultyId,
        String activityType
    ) {
        Map<String, Object> row = buildSaveRow(dayName, startTime, endTime, facultyId, activityType);
        row.put('id', scheduleId);
        return row;
    }

    private static Map<String, Object> buildSaveRow(
        String dayName,
        String startTime,
        String endTime,
        Id facultyId,
        String activityType
    ) {
        Map<String, Object> row = buildSaveRow(dayName, startTime, endTime);
        row.put('facultyId', facultyId);
        row.put('activityType', activityType);
        return row;
    }

    private static void setActivityType(SObject row, String value) {
        if (row.getSObjectType().getDescribe().fields.getMap().containsKey('Activity_Type__c')) {
            row.put('Activity_Type__c', value);
        }
    }

    private static Id createProgramPlan() {
        Learning learning = new KenTestDataFactory.LearningCreator('Program Learning').create();
        Schema.Location campus = new KenTestDataFactory.LocationCreator('Program Campus', 'Site').create();
        LearningProgram program = new KenTestDataFactory.LearningProgramCreator('Engineering Program')
            .setLearningId(learning.Id)
            .setCampus(campus.Id)
            .create();
        LearningProgramPlan plan = new KenTestDataFactory.LearningProgramPlanCreator(program.Id).create();
        return plan.Id;
    }

    private static void insertJunction(Id planId, Id offeringId, String enrollmentType) {
        Program_Plan_Course_Junction__c junction = new Program_Plan_Course_Junction__c();
        junction.Learning_Program_Plan__c = planId;
        junction.Course_Offering__c = offeringId;
        Map<String, Schema.SObjectField> fields = Program_Plan_Course_Junction__c.SObjectType.getDescribe().fields.getMap();
        if (fields.containsKey('Enrollment_Type__c')) {
            junction.Enrollment_Type__c = getJunctionPicklistValue('Enrollment_Type__c', enrollmentType, 'Core');
        }
        insert junction;
    }

    private static String getJunctionPicklistValue(String fieldApiName, String preferredValue, String fallbackValue) {
        Map<String, Schema.SObjectField> fields = Program_Plan_Course_Junction__c.SObjectType.getDescribe().fields.getMap();
        if (!fields.containsKey(fieldApiName)) {
            return fallbackValue;
        }
        for (Schema.PicklistEntry entry : fields.get(fieldApiName).getDescribe().getPicklistValues()) {
            if (entry.isActive() && (entry.getValue() == preferredValue || entry.getLabel() == preferredValue)) {
                return entry.getValue();
            }
        }
        for (Schema.PicklistEntry entry : fields.get(fieldApiName).getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return fallbackValue;
    }

    private static void insertFacultyParticipant(Id offeringId, Id facultyContactId) {
        CourseOfferingParticipant participant = new CourseOfferingParticipant();
        participant.CourseOfferingId = offeringId;
        participant.ParticipantContactId = facultyContactId;
        participant.ParticipantAffiliation = 'Faculty';
        participant.ParticipationStatus = KenConstantController.STATUS_ENROLLED;
        try {
            insert participant;
        } catch (DmlException dmlException) {
            System.assertNotEquals(null, dmlException.getMessage());
        }
    }

    private static void expectTemplateNameError() {
        Boolean raised = false;
        try {
            KenTimetableManagementController.createScheduleTemplate(
                null,
                null,
                null,
                null,
                '08:00',
                '09:00',
                null,
                true,
                false,
                false,
                false,
                false,
                false,
                false
            );
        } catch (AuraHandledException handledException) {
            raised = true;
            System.assertNotEquals(null, handledException.getMessage());
        }
        System.assertEquals(true, raised);
    }

    private static void expectTemplateTimeRequiredError() {
        Boolean raised = false;
        try {
            KenTimetableManagementController.createScheduleTemplate(
                'Missing Time',
                null,
                null,
                null,
                null,
                '09:00',
                null,
                true,
                false,
                false,
                false,
                false,
                false,
                false
            );
        } catch (AuraHandledException handledException) {
            raised = true;
            System.assertNotEquals(null, handledException.getMessage());
        }
        System.assertEquals(true, raised);
    }

    private static void expectTemplateInvalidTimeError() {
        Boolean raised = false;
        try {
            KenTimetableManagementController.createScheduleTemplate(
                'Invalid Time',
                null,
                null,
                null,
                '10:00',
                '09:00',
                null,
                true,
                false,
                false,
                false,
                false,
                false,
                false
            );
        } catch (AuraHandledException handledException) {
            raised = true;
            System.assertNotEquals(null, handledException.getMessage());
        }
        System.assertEquals(true, raised);
    }

    private static void expectTemplateNoDayError() {
        Boolean raised = false;
        try {
            KenTimetableManagementController.createScheduleTemplate(
                'No Day',
                null,
                null,
                null,
                '08:00',
                '09:00',
                null,
                false,
                false,
                false,
                false,
                false,
                false,
                false
            );
        } catch (AuraHandledException handledException) {
            raised = true;
            System.assertNotEquals(null, handledException.getMessage());
        }
        System.assertEquals(true, raised);
    }

    private static void expectDuplicateTemplateError() {
        Boolean raised = false;
        try {
            KenTimetableManagementController.createScheduleTemplate(
                'Duplicate Template Again',
                'RRULE:FREQ=WEEKLY;INTERVAL=1',
                String.valueOf(Date.today()),
                String.valueOf(Date.today().addDays(7)),
                '07:00',
                '08:00',
                'Duplicate validation attempt',
                true,
                false,
                false,
                false,
                false,
                false,
                false
            );
        } catch (AuraHandledException handledException) {
            raised = true;
            System.assertNotEquals(null, handledException.getMessage());
        }
        System.assertEquals(true, raised);
    }

    private static void expectPublishEmptyPlanError(Id termId, Id planId) {
        Boolean raised = false;
        try {
            KenTimetableManagementController.publishProgramPlanTimetable(termId, planId);
        } catch (AuraHandledException handledException) {
            raised = true;
            System.assertNotEquals(null, handledException.getMessage());
        }
        System.assertEquals(true, raised);
    }

    private static void expectPublishMissingArgumentError() {
        Boolean raised = false;
        try {
            KenTimetableManagementController.publishProgramPlanTimetable(null, null);
        } catch (AuraHandledException handledException) {
            raised = true;
            System.assertNotEquals(null, handledException.getMessage());
        }
        System.assertEquals(true, raised);
    }

    private static void expectToggleMissingArgumentError() {
        Boolean raised = false;
        try {
            KenTimetableManagementController.toggleTimetableLock(null);
        } catch (AuraHandledException handledException) {
            raised = true;
            System.assertNotEquals(null, handledException.getMessage());
        }
        System.assertEquals(true, raised);
    }

    private static void expectSaveError(Id offeringId, String jsonRows, String scheduleStartDate, String scheduleEndDate) {
        Boolean raised = false;
        try {
            KenTimetableManagementController.saveCourseOfferingSchedules(
                offeringId,
                jsonRows,
                null,
                null,
                null,
                null,
                scheduleStartDate,
                scheduleEndDate
            );
        } catch (AuraHandledException handledException) {
            raised = true;
            System.assertNotEquals(null, handledException.getMessage());
        }
        System.assertEquals(true, raised);
    }

    private static void createLocation(String name) {
        try {
            new KenTestDataFactory.LocationCreator(name, 'Site').create();
        } catch (DmlException dmlException) {
            System.assertNotEquals(null, dmlException.getMessage());
        }
    }

    private static void tryToggleLock(Id offeringId) {
        try {
            KenTimetableManagementController.toggleTimetableLock(offeringId);
        } catch (AuraHandledException handledException) {
            System.assertNotEquals(null, handledException.getMessage());
        }
    }

}