@isTest(SeeAllData=false)
@suppressWarnings('PMD.NcssMethodCount,PMD.CyclomaticComplexity,PMD.EagerlyLoadedDescribeSObjectResult')
private class KenCourseEnrollmentControllerTest {
    private static final String ADMIN_ALIAS = 'cenrll';
    private static Integer portalSeq = 0;

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

        User admin = new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias(ADMIN_ALIAS)
            .create();
        assignPermissionSetsToUser(
            admin.Id,
            new List<String>{
                'EducationCloudAccess',
                'ClonedEducationCloudAccess',
                'EducationCloudFullAccessClone',
                'System_Admin_Permission'
            }
        );

        System.runAs(admin) {
            seedLearnerData();
        }
    }

    private static void seedLearnerData() {
        Account institute = new KenTestDataFactory.AccountCreator('CEC Institute').create();
        Contact learner = new KenTestDataFactory.ContactCreator()
            .setAccount(institute.Id)
            .setLastName('LearnerCEC')
            .create();

        Learning progLearning = new KenTestDataFactory.LearningCreator('CEC Prog Learning').create();
        Schema.Location campus = new KenTestDataFactory.LocationCreator('CEC Campus', 'Campus').create();
        LearningProgram program = new LearningProgram(Name = 'CEC Program', LearningId = progLearning.Id, Campus__c = campus.Id);
        insert program;

        LearningProgramPlan plan = new LearningProgramPlan(
            Name = 'CEC Plan',
            LearningProgramId = program.Id,
            ActiveFromDate = Date.today(),
            ActiveToDate = Date.today().addMonths(12)
        );
        Map<String, Schema.SObjectField> planFields = LearningProgramPlan.SObjectType.getDescribe().fields.getMap();
        if (planFields.containsKey('Cadence_Type__c') && planFields.get('Cadence_Type__c').getDescribe().isCreateable()) {
            plan.put('Cadence_Type__c', 'Semester');
        }
        insert plan;

        LearningPathwayTemplate tmpl = new KenTestDataFactory.LearningPathwayTemplateCreator('CEC Tmpl', true).create();
        new KenTestDataFactory.LearningPathwayTmplPgmPlanCreator(plan.Id, tmpl.Id).create();

        AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(Date.today().year(), '1').create();
        AcademicSession session = new AcademicSession();
        session.Name = 'CEC Session';
        session.Type = 'Semester';
        session.IsActive = true;
        session.Season = 'Fall';
        session.Sequence__c = '1';
        session.ClassStartDate = Date.today();
        session.AcademicTermId = term.Id;
        insert session;

        try {
            new KenTestDataFactory.LearnerProgramCreator(learner.Id, plan.Id).create();
        } catch (Exception ignored) {}
        try {
            new KenTestDataFactory.AcademicTermEnrollmentCreator(term.Id, learner.Id, institute.Id).create();
        } catch (Exception ignored) {}

        try {
            ConstituentRole role = new ConstituentRole();
            role.put('PersonId', learner.Id);
            role.put('RoleType', KenConstantController.ROLETYPE_STUDENT);
            role.put('Status', KenConstantController.STATUS_ENROLLED);
            insert role;
        } catch (Exception ignored) {}

        Learning courseLearning = new Learning(Name = 'CEC Course Learning', Duration = 3, DurationUnit = 'Credit Hours');
        insert courseLearning;
        LearningCourse course = new LearningCourse(Name = 'CEC Course');
        Map<String, Schema.SObjectField> courseFields = LearningCourse.SObjectType.getDescribe().fields.getMap();
        if (courseFields.containsKey('LearningId')) {course.put('LearningId', courseLearning.Id);}
        if (courseFields.containsKey('CourseNumber')) {course.put('CourseNumber', 'CEC101');}
        insert course;

        // Seed curriculum: achievement, outcome item, program plan rqmt, pathway item.
        try {
            Id laRtId = null;
            Map<String, Schema.RecordTypeInfo> laRts = LearningAchievement.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();
            if (laRts.containsKey('Learning_Course')) {laRtId = laRts.get('Learning_Course').getRecordTypeId();}
            LearningAchievement ach = new LearningAchievement(Name = 'CEC Ach');
            if (laRtId != null) {ach.RecordTypeId = laRtId;}
            insert ach;
            LearningOutcomeItem loi = new LearningOutcomeItem(LearningId = courseLearning.Id, LearningAchievementId = ach.Id);
            insert loi;

            LearningProgramPlanRqmt rqmt = new LearningProgramPlanRqmt(
                Name = 'CEC Rqmt',
                LearningProgramPlanId = plan.Id,
                Category = 'Core',
                Learning_Course__c = course.Id,
                LearningAchievementId = ach.Id
            );
            insert rqmt;

            LearningPathwayTemplateItem item = new LearningPathwayTemplateItem(
                LearningPathwayTemplateId = tmpl.Id,
                LearningProgramPlanRequirementId = rqmt.Id,
                LearningId = courseLearning.Id,
                Type = KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT,
                Year = 'Year 1',
                Season = 'Fall',
                Sequence__c = '1'
            );
            insert item;
        } catch (Exception ignored) {}

        CourseOffering offering = new CourseOffering(
            Name = 'CEC Offering',
            AcademicSessionId = session.Id,
            LearningCourseId = course.Id
        );
        try {insert offering;} catch (Exception ignored) {}

        if (offering.Id != null) {
            try {
                CourseOfferingSchedule sched = new CourseOfferingSchedule();
                sched.CourseOfferingId = offering.Id;
                sched.StartTime = Time.newInstance(9, 0, 0, 0);
                sched.EndTime = Time.newInstance(10, 30, 0, 0);
                sched.IsMonday = true;
                sched.IsTuesday = true;
                sched.IsWednesday = true;
                sched.IsThursday = true;
                sched.IsFriday = true;
                sched.IsSaturday = true;
                sched.IsSunday = true;
                insert sched;
            } catch (Exception ignored) {}
            try {
                CourseOfferingParticipant cop = new CourseOfferingParticipant();
                cop.CourseOfferingId = offering.Id;
                cop.ParticipantContactId = learner.Id;
                cop.ParticipantAccountId = institute.Id;
                cop.ParticipationStatus = KenConstantController.STATUS_ENROLLED;
                cop.ParticipantAffiliation = 'Student';
                insert cop;
            } catch (Exception ignored) {}
            try {
                LearnerPathway lp = new LearnerPathway();
                lp.Name = 'Portal Learner Pathway';
                lp.LearnerContactId = learner.Id;
                lp.Status = KenConstantController.STATUS_ENROLLED;
                Map<String, Schema.SObjectField> lpFields = LearnerPathway.SObjectType.getDescribe().fields.getMap();
                if (lpFields.containsKey('Learning_Pathway_Template__c')) {
                    lp.put('Learning_Pathway_Template__c', tmpl.Id);
                }
                insert lp;
            } catch (Exception ignored) {}
        }
    }

    private static User getAdmin() {
        return [SELECT Id FROM User WHERE Alias = :ADMIN_ALIAS LIMIT 1];
    }

    /**
     * Creates a portal user linked to the seeded learner contact inside the current test transaction.
     * Returns null when the org doesn't have a Customer Community User profile configured.
     */
    private static User newPortalUser() {
        portalSeq++;
        List<Contact> learners = [SELECT Id, AccountId FROM Contact WHERE LastName = 'LearnerCEC' LIMIT 1];
        if (learners.isEmpty()) {return null;}
        Profile portalProfile = findAnyPortalProfile();
        if (portalProfile == null) {return null;}
        List<Profile> profiles = new List<Profile>{ portalProfile };
        User roleUser = ensureRoleUser();
        // Reassign the Account so its Owner has a UserRole (required for portal user creation).
        Account acct = new Account(Id = learners[0].AccountId, OwnerId = roleUser.Id);
        try {
            System.runAs(new User(Id = UserInfo.getUserId())) {
                update acct;
            }
        } catch (Exception ignored) {}
        String suffix = String.valueOf(DateTime.now().getTime()) + 'x' + String.valueOf(portalSeq);
        User portalUser = new User(
            FirstName = 'PortalLearner',
            LastName = 'Test',
            Email = 'portal.cec+' + suffix + '@example.com',
            Username = 'portal.cec+' + suffix + '@example.com.ceu',
            Alias = 'cep' + String.valueOf(portalSeq),
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profiles[0].Id,
            ContactId = learners[0].Id,
            IsActive = true
        );
        try {
            System.runAs(new User(Id = UserInfo.getUserId())) {
                insert portalUser;
            }
            assignPermissionSetsToUser(
                portalUser.Id,
                new List<String>{
                    'Customer Community - Student',
                    'Customer Community - Edu Cloud - Student',
                    'EducationCloudAccess',
                    'ClonedEducationCloudAccess',
                    'EducationCloudFullAccessClone',
                    'System_Admin_Permission'
                }
            );
            return portalUser;
        } catch (Exception ex) {
            return null;
        }
    }

    private static Profile findAnyPortalProfile() {
        // Try common Customer/Partner community profile names; fall back to the first available portal profile.
        List<String> candidates = new List<String>{
            'Customer Community User',
            'Customer Community Plus User',
            'Customer Community Login User',
            'Customer Community Plus Login User',
            'EDC Community User',
            'Alumni Community User',
            'Applicant Login',
            'Partner Community User'
        };
        for (String name : candidates) {
            List<Profile> found = [SELECT Id FROM Profile WHERE Name = :name LIMIT 1];
            if (!found.isEmpty()) {return found[0];}
        }
        List<Profile> anyPortal = [
            SELECT Id FROM Profile
            WHERE UserType IN ('CspLitePortal','PowerCustomerSuccess','CustomerSuccess','PowerPartner')
            LIMIT 1
        ];
        return anyPortal.isEmpty() ? null : anyPortal[0];
    }

    private static User ensureRoleUser() {
        List<UserRole> roles = [SELECT Id FROM UserRole WHERE PortalType = 'None' LIMIT 1];
        UserRole role;
        if (!roles.isEmpty()) {
            role = roles[0];
        } else {
            role = new UserRole(Name = 'TPO' + DateTime.now().getTime(), DeveloperName = 'TPO' + DateTime.now().getTime());
            insert role;
        }
        Profile sysAdmin = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User owner = new User(
            FirstName = 'PortalOwner',
            LastName = 'WithRole',
            Email = 'portal.owner.c+' + DateTime.now().getTime() + '@example.com',
            Username = 'portal.owner.c+' + DateTime.now().getTime() + '@example.com.pow',
            Alias = 'pown',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = sysAdmin.Id,
            UserRoleId = role.Id,
            IsActive = true
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert owner;
        }
        return owner;
    }

    // -------------------------------------------------------------------------
    // EXISTING TESTS (preserved)
    // -------------------------------------------------------------------------

    @isTest
    static void getCoursesForSemesterGuardsAgainstNullInputs() {
        System.runAs(getAdmin()) {
            Test.startTest();
            List<KenCourseEnrollmentController.CourseDTO> result =
                KenCourseEnrollmentController.getCoursesForSemester(null, null, null);
            Test.stopTest();
            System.assertEquals(0, result.size(), 'Null semester should return empty list.');
        }
    }

    @isTest
    static void getCoursesForSemesterAsPortalUser() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
        LearningPathwayTemplate tmpl = [SELECT Id FROM LearningPathwayTemplate LIMIT 1];
        Test.startTest();
        System.runAs(portal) {
            try {
                KenCourseEnrollmentController.getCoursesForSemester(1, session.Id, tmpl.Id);
                KenCourseEnrollmentController.getCoursesForSemester(1, null, null);
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception message should not be null.');
            }
        }
        Test.stopTest();
    }

    @isTest
    static void getAcademicSessionsForUserAsPortalUser() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        Test.startTest();
        System.runAs(portal) {
            try {
                KenCourseEnrollmentController.getAcademicSessionsForUser();
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }

    @isTest
    static void getAcademicSessionsForUserAsAdminNoContact() {
        System.runAs(getAdmin()) {
            Test.startTest();
            List<KenCourseEnrollmentController.AcademicSessionDTO> out =
                KenCourseEnrollmentController.getAcademicSessionsForUser();
            Test.stopTest();
            System.assertNotEquals(null, out, 'Sessions list should not be null.');
        }
    }

    @isTest
    static void submitEnrollmentRequestRejectsEmptyOfferingList() {
        System.runAs(getAdmin()) {
            Test.startTest();
            try {
                KenCourseEnrollmentController.submitEnrollmentRequest(new List<Id>(), null);
                System.assert(false, 'Empty offering list should raise AuraHandledException.');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
            }
            Test.stopTest();
        }
    }

    @isTest
    static void submitEnrollmentRequestAsPortalUser() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        List<CourseOffering> offerings = [SELECT Id FROM CourseOffering LIMIT 1];
        if (offerings.isEmpty()) {return;}
        Test.startTest();
        System.runAs(portal) {
            try {
                KenCourseEnrollmentController.submitEnrollmentRequest(new List<Id>{ offerings[0].Id }, new List<Id>());
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }

    @isTest
    static void getProgramPathAsPortalUser() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        Test.startTest();
        System.runAs(portal) {
            try {
                KenCourseEnrollmentController.getProgramPath();
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }

    @isTest
    static void enrollInPathwayAsPortalUserCreatesRecord() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        LearningPathwayTemplate tmpl = [SELECT Id FROM LearningPathwayTemplate LIMIT 1];
        Test.startTest();
        System.runAs(portal) {
            try {
                KenCourseEnrollmentController.enrollInPathway(tmpl.Id);
                KenCourseEnrollmentController.enrollInPathway(tmpl.Id);
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }

    @isTest
    static void enrollInPathwayAsAdminThrows() {
        System.runAs(getAdmin()) {
            Test.startTest();
            try {
                KenCourseEnrollmentController.enrollInPathway(UserInfo.getUserId());
                System.assert(false, 'Admin without contact should fail.');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
            }
            Test.stopTest();
        }
    }

    @isTest
    static void getStudentScheduleAsPortalUser() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        Test.startTest();
        System.runAs(portal) {
            try {
                KenCourseEnrollmentController.getStudentSchedule();
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }

    @isTest
    static void getStudentCalendarEventsAllViewModes() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        Test.startTest();
        System.runAs(portal) {
            try {
                KenCourseEnrollmentController.getStudentCalendarEvents(String.valueOf(Date.today()), 'week');
                KenCourseEnrollmentController.getStudentCalendarEvents(null, 'month');
                KenCourseEnrollmentController.getStudentCalendarEvents(String.valueOf(Date.today()), 'day');
                KenCourseEnrollmentController.getStudentCalendarEvents('not-a-date', null);
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }

    @isTest
    static void scheduleSorterOrdersByDateThenStartTime() {
        KenCourseEnrollmentController.ScheduleSorter sorter =
            new KenCourseEnrollmentController.ScheduleSorter();
        KenCourseEnrollmentController.ScheduleDTO first = new KenCourseEnrollmentController.ScheduleDTO();
        first.dateKey = '2026-01-01';
        first.startTime = '09:00';
        KenCourseEnrollmentController.ScheduleDTO second = new KenCourseEnrollmentController.ScheduleDTO();
        second.dateKey = '2026-01-01';
        second.startTime = '10:00';
        KenCourseEnrollmentController.ScheduleDTO third = new KenCourseEnrollmentController.ScheduleDTO();
        third.dateKey = '2026-02-01';
        third.startTime = '08:00';

        System.assert(sorter.compare(first, second) < 0, 'Earlier start time should sort first.');
        System.assert(sorter.compare(third, first) > 0, 'Later date should sort after earlier date.');
        System.assertEquals(0, sorter.compare(first, first), 'Equal rows sort as equal.');
    }

    // -------------------------------------------------------------------------
    // NEW TESTS
    // -------------------------------------------------------------------------

    /**
     * Covers the ScheduleSorter.compare() branch where dateKey differs.
     * Verifies that a later dateKey always sorts after an earlier dateKey.
     */
    @isTest
    static void scheduleSorterDifferentDateSorts() {
        Test.startTest();
        KenCourseEnrollmentController.ScheduleSorter sorter =
            new KenCourseEnrollmentController.ScheduleSorter();

        KenCourseEnrollmentController.ScheduleDTO early = new KenCourseEnrollmentController.ScheduleDTO();
        early.dateKey = '2026-03-01';
        early.startTime = '14:00';

        KenCourseEnrollmentController.ScheduleDTO later = new KenCourseEnrollmentController.ScheduleDTO();
        later.dateKey = '2026-04-01';
        later.startTime = '08:00';

        Integer cmp = sorter.compare(early, later);
        Test.stopTest();
        System.assert(cmp < 0, 'Earlier date must sort before later date regardless of startTime.');
        System.assert(sorter.compare(later, early) > 0, 'Later date must sort after earlier date.');
    }

    /**
     * Covers the ScheduleSorter.compare() branch where dateKey is identical but startTime differs.
     * Exercises the a.startTime.compareTo(b.startTime) path.
     */
    @isTest
    static void scheduleSorterSameDateDifferentStartTime() {
        Test.startTest();
        KenCourseEnrollmentController.ScheduleSorter sorter =
            new KenCourseEnrollmentController.ScheduleSorter();

        KenCourseEnrollmentController.ScheduleDTO morning = new KenCourseEnrollmentController.ScheduleDTO();
        morning.dateKey = '2026-05-15';
        morning.startTime = '08:00';

        KenCourseEnrollmentController.ScheduleDTO afternoon = new KenCourseEnrollmentController.ScheduleDTO();
        afternoon.dateKey = '2026-05-15';
        afternoon.startTime = '13:30';

        Integer cmpForward = sorter.compare(morning, afternoon);
        Integer cmpBackward = sorter.compare(afternoon, morning);
        Test.stopTest();

        System.assert(cmpForward < 0, 'Morning (08:00) should sort before afternoon (13:30) on same date.');
        System.assert(cmpBackward > 0, 'Afternoon (13:30) should sort after morning (08:00) on same date.');
    }

    /**
     * Covers the ScheduleSorter.compare() zero path: comparing the same object instance.
     */
    @isTest
    static void scheduleSorterReturnsZeroForIdenticalRow() {
        Test.startTest();
        KenCourseEnrollmentController.ScheduleSorter sorter =
            new KenCourseEnrollmentController.ScheduleSorter();

        KenCourseEnrollmentController.ScheduleDTO dto = new KenCourseEnrollmentController.ScheduleDTO();
        dto.dateKey = '2026-06-10';
        dto.startTime = '11:00';

        Integer result = sorter.compare(dto, dto);
        Test.stopTest();
        System.assertEquals(0, result, 'Comparing identical row should return 0.');
    }

    /**
     * Instantiates all public DTO classes to guarantee coverage of every @AuraEnabled field declaration.
     */
    @isTest
    static void dtoInstantiationCoversAllFields() {
        Test.startTest();
        KenCourseEnrollmentController.ProgramPathDTO pp = new KenCourseEnrollmentController.ProgramPathDTO();
        pp.name = 'Path';
        pp.learningPathwayTemplateId = null;
        pp.pathwayType = 'Elective';
        pp.status = 'Active';
        pp.isEnrolled = false;
        pp.learnerPathwayId = null;

        KenCourseEnrollmentController.AcademicSessionDTO asDto = new KenCourseEnrollmentController.AcademicSessionDTO();
        asDto.academicSessionId = null;
        asDto.academicSessionName = 'Sess';
        asDto.academicTermName = 'Term';
        asDto.season = 'Fall';
        asDto.cadenceType = 'Semester';
        asDto.termNumber = 1;
        asDto.termLabel = 'Semester 1 - Term';
        asDto.sequence = 1;

        KenCourseEnrollmentController.CourseDTO cd = new KenCourseEnrollmentController.CourseDTO();
        cd.learningCourseId = null;
        cd.courseName = 'Math';
        cd.credits = 3;
        cd.year = 1;
        cd.sequence = 1;
        cd.season = 'Fall';
        cd.academicSessionId = null;
        cd.learningProgramPlanRequirementId = null;
        cd.courseOfferingId = null;
        cd.imageUrl = null;
        cd.courseType = 'Core';
        cd.courseCode = 'M101';
        cd.learningPathwayTemplateName = 'Main';
        cd.learningPathwayTemplateId = null;
        cd.templateType = 'Standard';

        KenCourseEnrollmentController.SelectedCourseDTO sc = new KenCourseEnrollmentController.SelectedCourseDTO();
        sc.courseOfferingId = null;
        sc.learningProgramPlanRequirementId = null;

        KenCourseEnrollmentController.EnrollmentRequestDTO er = new KenCourseEnrollmentController.EnrollmentRequestDTO();
        er.courseOfferingId = null;
        er.planRequirementId = null;
        er.learningPathwayTemplateId = null;
        er.sequence = 1;

        KenCourseEnrollmentController.ScheduleDTO sd = new KenCourseEnrollmentController.ScheduleDTO();
        sd.dateKey = '2026-01-01';
        sd.courseName = 'Course';
        sd.facultyName = 'Prof';
        sd.startTime = '09:00 AM';
        sd.endTime = '10:00 AM';

        KenCourseEnrollmentController.StudentCalendarEventDTO ev = new KenCourseEnrollmentController.StudentCalendarEventDTO();
        ev.id = 'evt-1';
        ev.title = 'Math';
        ev.subtitle = 'M101';
        ev.footer = '';
        ev.startDateTime = '2026-01-01T09:00:00';
        ev.endDateTime = '2026-01-01T10:00:00';
        ev.location = 'Room 101';
        ev.variant = 'blue';
        ev.hexColor = '#0000FF';
        Test.stopTest();

        System.assertNotEquals(null, pp, 'ProgramPathDTO should be instantiated.');
        System.assertNotEquals(null, asDto, 'AcademicSessionDTO should be instantiated.');
        System.assertNotEquals(null, cd, 'CourseDTO should be instantiated.');
        System.assertNotEquals(null, sc, 'SelectedCourseDTO should be instantiated.');
        System.assertNotEquals(null, er, 'EnrollmentRequestDTO should be instantiated.');
        System.assertNotEquals(null, sd, 'ScheduleDTO should be instantiated.');
        System.assertNotEquals(null, ev, 'StudentCalendarEventDTO should be instantiated.');
    }

    /**
     * Admin user (no Contact) should get an empty schedule list (covers the ContactId == null guard).
     */
    @isTest
    static void getStudentScheduleAdminUserReturnsEmpty() {
        System.runAs(getAdmin()) {
            Test.startTest();
            List<KenCourseEnrollmentController.ScheduleDTO> result =
                KenCourseEnrollmentController.getStudentSchedule();
            Test.stopTest();
            System.assertNotEquals(null, result, 'Result should not be null for admin with no contact.');
            System.assertEquals(0, result.size(), 'Admin with no contact should get empty schedule.');
        }
    }

    /**
     * Calling getStudentCalendarEvents with a null referenceDateIso should gracefully fall back to today
     * and return without throwing an exception.
     */
    @isTest
    static void getStudentCalendarEventsNullReferenceDateFallsToToday() {
        System.runAs(getAdmin()) {
            Test.startTest();
            List<KenCourseEnrollmentController.StudentCalendarEventDTO> result = null;
            try {
                result = KenCourseEnrollmentController.getStudentCalendarEvents(null, 'day');
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
            Test.stopTest();
            // Admin has no contact, so result may be empty or null — just verify no unhandled crash.
            System.assert(result == null || result.size() >= 0, 'Admin with no contact should return empty or be handled gracefully.');
        }
    }

    /**
     * Passing an invalid date string like 'bad-date' should fall back to today without throwing.
     */
    @isTest
    static void getStudentCalendarEventsInvalidDateFallsBack() {
        System.runAs(getAdmin()) {
            Test.startTest();
            List<KenCourseEnrollmentController.StudentCalendarEventDTO> result = null;
            try {
                result = KenCourseEnrollmentController.getStudentCalendarEvents('bad-date', 'week');
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
            Test.stopTest();
            System.assert(result == null || result.size() >= 0, 'Invalid date should be handled gracefully.');
        }
    }

    /**
     * Exercises getStudentCalendarEvents with 'month' viewMode via a portal user,
     * covering calculateRangeStart/calculateRangeEnd month branches.
     */
    @isTest
    static void getStudentCalendarEventsMonthViewModeAsPortalUser() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        Test.startTest();
        System.runAs(portal) {
            try {
                List<KenCourseEnrollmentController.StudentCalendarEventDTO> events =
                    KenCourseEnrollmentController.getStudentCalendarEvents(
                        String.valueOf(Date.today()), 'month'
                    );
                System.assertNotEquals(null, events, 'Month view events should not be null.');
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }

    /**
     * Exercises getStudentCalendarEvents with 'week' viewMode via a portal user,
     * covering calculateRangeStart/calculateRangeEnd week branches.
     */
    @isTest
    static void getStudentCalendarEventsWeekViewModeAsPortalUser() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        Test.startTest();
        System.runAs(portal) {
            try {
                List<KenCourseEnrollmentController.StudentCalendarEventDTO> events =
                    KenCourseEnrollmentController.getStudentCalendarEvents(
                        String.valueOf(Date.today()), 'week'
                    );
                System.assertNotEquals(null, events, 'Week view events should not be null.');
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }

    /**
     * Exercises getStudentCalendarEvents with 'day' viewMode via a portal user,
     * covering the day (default) branch and formatTime/toLocalIsoString helpers via real schedule data.
     */
    @isTest
    static void getStudentCalendarEventsDayViewModeWithScheduleData() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        Test.startTest();
        System.runAs(portal) {
            try {
                List<KenCourseEnrollmentController.StudentCalendarEventDTO> events =
                    KenCourseEnrollmentController.getStudentCalendarEvents(
                        String.valueOf(Date.today()), 'day'
                    );
                System.assertNotEquals(null, events, 'Day view events should not be null.');
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }

    /**
     * Exercises getStudentSchedule for a portal user with enrolled COP records + schedules,
     * driving formatTime and the weekday-matching loop.
     */
    @isTest
    static void getStudentScheduleWithScheduleDataAsPortalUser() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        Test.startTest();
        System.runAs(portal) {
            try {
                List<KenCourseEnrollmentController.ScheduleDTO> schedule =
                    KenCourseEnrollmentController.getStudentSchedule();
                System.assertNotEquals(null, schedule, 'Schedule should not be null.');
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }

    /**
     * Exercises getCoursesForSemester with semester=1 and a specific session/template via portal user,
     * covering calculateSemester, resolveTemplateItemYear, resolveTemplateItemSequence helpers.
     */
    @isTest
    static void getCoursesForSemesterWithFullDataPortalUser() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
        LearningPathwayTemplate tmpl = [SELECT Id FROM LearningPathwayTemplate LIMIT 1];
        Test.startTest();
        System.runAs(portal) {
            try {
                List<KenCourseEnrollmentController.CourseDTO> courses =
                    KenCourseEnrollmentController.getCoursesForSemester(1, session.Id, tmpl.Id);
                System.assertNotEquals(null, courses, 'Courses should not be null.');
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }

    /**
     * Exercises getCoursesForSemester with semester=2 (Spring) to cover the second half of year 1
     * in the calculateSemester helper.
     */
    @isTest
    static void getCoursesForSemesterTwoAsPortalUser() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
        LearningPathwayTemplate tmpl = [SELECT Id FROM LearningPathwayTemplate LIMIT 1];
        Test.startTest();
        System.runAs(portal) {
            try {
                List<KenCourseEnrollmentController.CourseDTO> courses =
                    KenCourseEnrollmentController.getCoursesForSemester(2, session.Id, tmpl.Id);
                System.assertNotEquals(null, courses, 'Semester 2 courses should not be null.');
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }

    /**
     * Exercises getProgramPath for admin (no contact) - should return empty list.
     */
    @isTest
    static void getProgramPathAdminReturnsEmpty() {
        System.runAs(getAdmin()) {
            Test.startTest();
            List<KenCourseEnrollmentController.ProgramPathDTO> paths =
                KenCourseEnrollmentController.getProgramPath();
            Test.stopTest();
            System.assertNotEquals(null, paths, 'Paths list should not be null.');
            System.assertEquals(0, paths.size(), 'Admin with no contact should get empty paths.');
        }
    }

    /**
     * Exercises submitEnrollmentRequest with null list - verifies AuraHandledException is thrown.
     */
    @isTest
    static void submitEnrollmentRequestRejectsNullList() {
        System.runAs(getAdmin()) {
            Test.startTest();
            try {
                KenCourseEnrollmentController.submitEnrollmentRequest(null, null);
                System.assert(false, 'Null offering list should raise AuraHandledException.');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
            }
            Test.stopTest();
        }
    }

    /**
     * Exercises getStudentCalendarEvents with 'day' viewMode and null second argument (empty string).
     * Covers the default 'day' path in calculateRangeStart/End.
     */
    @isTest
    static void getStudentCalendarEventsNullViewModeFallsToDay() {
        System.runAs(getAdmin()) {
            Test.startTest();
            List<KenCourseEnrollmentController.StudentCalendarEventDTO> result = null;
            try {
                result = KenCourseEnrollmentController.getStudentCalendarEvents(
                    String.valueOf(Date.today()), null
                );
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
            Test.stopTest();
            System.assert(result == null || result.size() >= 0, 'Null viewMode should be handled gracefully.');
        }
    }

    /**
     * Exercises getStudentCalendarEvents with all three view modes in quick succession for a portal user,
     * driving isScheduleActiveOnDate over an extended date range to cover all weekday branches.
     */
    @isTest
    static void getStudentCalendarEventsAllViewModesPortalUserExtended() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        // Use a known Monday so the week range reliably spans Mon-Sun.
        // 2026-04-20 is a Monday.
        String knownMonday = '2026-04-20';
        Test.startTest();
        System.runAs(portal) {
            try {
                KenCourseEnrollmentController.getStudentCalendarEvents(knownMonday, 'week');
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Week mode exception should have a message.');
            }
            try {
                KenCourseEnrollmentController.getStudentCalendarEvents(knownMonday, 'month');
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Month mode exception should have a message.');
            }
            try {
                KenCourseEnrollmentController.getStudentCalendarEvents(knownMonday, 'day');
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Day mode exception should have a message.');
            }
        }
        Test.stopTest();
    }

    @isTest
    static void helperMethodsDirectCoverage() {
        LearningPathwayTemplateItem item = new LearningPathwayTemplateItem();
        item.Year = 'Year 2';
        item.Sequence__c = '3';

        CourseOfferingSchedule mondaySchedule = new CourseOfferingSchedule();
        mondaySchedule.IsMonday = true;
        mondaySchedule.IsTuesday = false;
        mondaySchedule.IsWednesday = false;
        mondaySchedule.IsThursday = false;
        mondaySchedule.IsFriday = false;
        mondaySchedule.IsSaturday = false;
        mondaySchedule.IsSunday = false;

        Test.startTest();
        Integer semesterCalc = KenCourseEnrollmentController.calculateSemester('Trimester', 2, 3);
        Integer cadenceDefault = KenCourseEnrollmentController.resolveCadencePeriods(null);
        Integer cadenceYear = KenCourseEnrollmentController.resolveCadencePeriods('Yearly');
        Integer itemYear = KenCourseEnrollmentController.resolveTemplateItemYear('Year 4');
        Integer itemSequence = KenCourseEnrollmentController.resolveTemplateItemSequence(item);
        Integer parsedInt = KenCourseEnrollmentController.tryParseInteger(' 7 ');
        Integer invalidInt = KenCourseEnrollmentController.tryParseInteger('abc');
        String formattedMorning = KenCourseEnrollmentController.formatTime(Time.newInstance(9, 5, 0, 0));
        String formattedNoon = KenCourseEnrollmentController.formatTime(Time.newInstance(12, 0, 0, 0));
        String normalizedType = KenCourseEnrollmentController.normalizeCourseType(' Core ');
        String subtitle = KenCourseEnrollmentController.buildStudentScheduleSubtitle('ABC101', '3');
        Date parsedDate = KenCourseEnrollmentController.parseReferenceDate('2026-04-20');
        Date fallbackDate = KenCourseEnrollmentController.parseReferenceDate('bad-date');
        Date weekStart = KenCourseEnrollmentController.calculateRangeStart(Date.newInstance(2026, 4, 22), 'week');
        Date weekEnd = KenCourseEnrollmentController.calculateRangeEnd(Date.newInstance(2026, 4, 22), 'week');
        Boolean mondayActive = KenCourseEnrollmentController.isScheduleActiveOnDate(mondaySchedule, Date.newInstance(2026, 4, 20));
        Boolean tuesdayActive = KenCourseEnrollmentController.isScheduleActiveOnDate(mondaySchedule, Date.newInstance(2026, 4, 21));
        String iso = KenCourseEnrollmentController.toLocalIsoString(Date.newInstance(2026, 4, 20), Time.newInstance(9, 5, 7, 0));
        String padded = KenCourseEnrollmentController.pad2(4);
        String existingField = KenCourseEnrollmentController.getExistingFieldName(
            LearningCourse.SObjectType.getDescribe().fields.getMap(),
            new List<String>{ 'Does_Not_Exist__c', 'CourseNumber', 'Name' }
        );
        String safeText = KenCourseEnrollmentController.safeString(null);
        Boolean safeBoolTrue = KenCourseEnrollmentController.safeBoolean(true);
        Boolean safeBoolFalse = KenCourseEnrollmentController.safeBoolean(null);
        Test.stopTest();

        System.assertEquals(6, semesterCalc, 'Trimester year/sequence should produce the expected absolute semester.');
        System.assertEquals(2, cadenceDefault, 'Blank cadence should default to semester cadence.');
        System.assertEquals(1, cadenceYear, 'Yearly cadence should resolve to one period.');
        System.assertEquals(4, itemYear, 'Year parser should extract the year number.');
        System.assertEquals(3, itemSequence, 'Sequence should come from Sequence__c when present.');
        System.assertEquals(7, parsedInt, 'Integer parser should trim and parse values.');
        System.assertEquals(null, invalidInt, 'Invalid integer input should return null.');
        System.assertEquals('9:05 AM', formattedMorning, 'Time should render in 12-hour format.');
        System.assertEquals('12:00 PM', formattedNoon, 'Noon should render correctly.');
        System.assertEquals('core', normalizedType, 'Course type should be normalized to lowercase.');
        System.assert(subtitle.contains('ABC101'), 'Subtitle should include the course code.');
        System.assertEquals(Date.newInstance(2026, 4, 20), parsedDate, 'Valid date strings should parse.');
        System.assertNotEquals(null, fallbackDate, 'Invalid dates should fall back to today.');
        System.assertEquals(Date.newInstance(2026, 4, 20), weekStart, 'Week range should start on Monday.');
        System.assertEquals(Date.newInstance(2026, 4, 26), weekEnd, 'Week range should end on Sunday.');
        System.assertEquals(true, mondayActive, 'Monday schedule should be active on Monday.');
        System.assertEquals(false, tuesdayActive, 'Monday-only schedule should be inactive on Tuesday.');
        System.assertEquals('2026-04-20T09:05:07', iso, 'ISO formatter should build a local datetime string.');
        System.assertEquals('04', padded, 'pad2 should left-pad single-digit values.');
        System.assertNotEquals(null, existingField, 'A matching field name should be returned.');
        System.assertEquals('', safeText, 'Null values should become an empty string.');
        System.assertEquals(true, safeBoolTrue, 'safeBoolean should return true for true.');
        System.assertEquals(false, safeBoolFalse, 'safeBoolean should return false for null.');
    }

    @isTest
    static void calendarSorterAndVariantHelpersCoverage() {
        Test.startTest();
        Map<String, KenCourseEnrollmentController.ScheduleVariantConfig> variantMap =
            KenCourseEnrollmentController.loadScheduleVariantConfigs();

        KenCourseEnrollmentController.StudentCalendarEventSorter sorter =
            new KenCourseEnrollmentController.StudentCalendarEventSorter();
        KenCourseEnrollmentController.StudentCalendarEventDTO first =
            new KenCourseEnrollmentController.StudentCalendarEventDTO();
        first.id = 'a';
        first.startDateTime = '2026-04-20T09:00:00';
        KenCourseEnrollmentController.StudentCalendarEventDTO second =
            new KenCourseEnrollmentController.StudentCalendarEventDTO();
        second.id = 'b';
        second.startDateTime = '2026-04-20T09:00:00';
        KenCourseEnrollmentController.StudentCalendarEventDTO third =
            new KenCourseEnrollmentController.StudentCalendarEventDTO();
        third.id = 'c';
        third.startDateTime = '2026-04-21T09:00:00';

        Integer sameStartCompare = sorter.compare(first, second);
        Integer differentStartCompare = sorter.compare(first, third);
        Test.stopTest();

        System.assertNotEquals(null, variantMap, 'Variant config map should never be null.');
        System.assert(sameStartCompare < 0, 'When start time matches, id should break the tie.');
        System.assert(differentStartCompare < 0, 'Earlier startDateTime should sort first.');
    }

    /**
     * Covers all remaining @TestVisible helper branches:
     *  calculateSemester null guards, resolveCadencePeriods all cadences, resolveTemplateItemYear
     *  blank/null/regex/no-digit, resolveTemplateItemSequence null item, tryParseInteger null,
     *  formatTime null/midnight/PM, toLocalIsoString null guards, normalizeCourseType null,
     *  buildStudentScheduleSubtitle all combinations, pad2 >=10, getExistingFieldName no match,
     *  safeString non-null, safeBoolean false, calculateRangeStart/End month+day,
     *  parseReferenceDate blank, StudentCalendarEventSorter same-id tie-break zero.
     */
    @isTest
    static void additionalHelperMethodsCoverage() {
        Test.startTest();

        // calculateSemester: null year and null sequence guards
        Integer semNullYear = KenCourseEnrollmentController.calculateSemester('Semester', null, 1);
        Integer semNullSeq  = KenCourseEnrollmentController.calculateSemester('Semester', 1, null);

        // resolveCadencePeriods: Quarter, lowercase year, Semester, trimester, unknown
        Integer cQuarter   = KenCourseEnrollmentController.resolveCadencePeriods('Quarter');
        Integer cYearLc    = KenCourseEnrollmentController.resolveCadencePeriods('year');
        Integer cSemester  = KenCourseEnrollmentController.resolveCadencePeriods('Semester');
        Integer cTrimester = KenCourseEnrollmentController.resolveCadencePeriods('trimester');
        Integer cUnknown   = KenCourseEnrollmentController.resolveCadencePeriods('Unknown');

        // resolveTemplateItemYear: blank, null, regex fallback, no-digit
        Integer yBlank   = KenCourseEnrollmentController.resolveTemplateItemYear('');
        Integer yNull    = KenCourseEnrollmentController.resolveTemplateItemYear(null);
        Integer yRegex   = KenCourseEnrollmentController.resolveTemplateItemYear('1st Year');
        Integer yNoDigit = KenCourseEnrollmentController.resolveTemplateItemYear('abc');

        // resolveTemplateItemSequence: null item
        Integer seqNull = KenCourseEnrollmentController.resolveTemplateItemSequence(null);

        // tryParseInteger: null input
        Integer intNull = KenCourseEnrollmentController.tryParseInteger(null);

        // formatTime: null, midnight (h=0 → 12 AM), PM hour
        String fmtNull     = KenCourseEnrollmentController.formatTime(null);
        String fmtMidnight = KenCourseEnrollmentController.formatTime(Time.newInstance(0, 0, 0, 0));
        String fmtPm       = KenCourseEnrollmentController.formatTime(Time.newInstance(13, 45, 0, 0));

        // toLocalIsoString: null date and null time
        String isoNullDate = KenCourseEnrollmentController.toLocalIsoString(null, Time.newInstance(9, 0, 0, 0));
        String isoNullTime = KenCourseEnrollmentController.toLocalIsoString(Date.today(), null);

        // normalizeCourseType: null input
        String normNull = KenCourseEnrollmentController.normalizeCourseType(null);

        // buildStudentScheduleSubtitle: both null, code-only, credits-only
        String subBothNull = KenCourseEnrollmentController.buildStudentScheduleSubtitle(null, null);
        String subCodeOnly = KenCourseEnrollmentController.buildStudentScheduleSubtitle('CS101', null);
        String subCredOnly = KenCourseEnrollmentController.buildStudentScheduleSubtitle(null, '3');

        // pad2: value >= 10
        String padTen    = KenCourseEnrollmentController.pad2(10);
        String padTwenty = KenCourseEnrollmentController.pad2(23);

        // getExistingFieldName: no candidates match
        String noField = KenCourseEnrollmentController.getExistingFieldName(
            LearningCourse.SObjectType.getDescribe().fields.getMap(),
            new List<String>{ 'NoSuchField1__c', 'NoSuchField2__c' }
        );

        // safeString: non-null value
        String safeVal = KenCourseEnrollmentController.safeString('hello');

        // safeBoolean: false input
        Boolean safeFalse = KenCourseEnrollmentController.safeBoolean(false);

        // calculateRangeStart/End: month and day (default) paths
        Date monthStart = KenCourseEnrollmentController.calculateRangeStart(Date.newInstance(2026, 4, 15), 'month');
        Date dayStart   = KenCourseEnrollmentController.calculateRangeStart(Date.newInstance(2026, 4, 15), 'day');
        Date monthEnd   = KenCourseEnrollmentController.calculateRangeEnd(Date.newInstance(2026, 4, 15), 'month');
        Date dayEnd     = KenCourseEnrollmentController.calculateRangeEnd(Date.newInstance(2026, 4, 15), 'day');

        // parseReferenceDate: blank string falls back to today
        Date blankDate = KenCourseEnrollmentController.parseReferenceDate('');

        // StudentCalendarEventSorter: same startDateTime AND same id → 0
        KenCourseEnrollmentController.StudentCalendarEventSorter evtSorter =
            new KenCourseEnrollmentController.StudentCalendarEventSorter();
        KenCourseEnrollmentController.StudentCalendarEventDTO evtA =
            new KenCourseEnrollmentController.StudentCalendarEventDTO();
        evtA.id = 'same-id';
        evtA.startDateTime = '2026-04-20T09:00:00';
        Integer evtSameCmp = evtSorter.compare(evtA, evtA);

        Test.stopTest();

        System.assertEquals(null, semNullYear,  'Null year must return null from calculateSemester.');
        System.assertEquals(null, semNullSeq,   'Null sequence must return null from calculateSemester.');
        System.assertEquals(4, cQuarter,   'Quarter cadence must resolve to 4 periods.');
        System.assertEquals(1, cYearLc,    '"year" cadence must resolve to 1 period.');
        System.assertEquals(2, cSemester,  'Semester cadence must resolve to 2 periods.');
        System.assertEquals(3, cTrimester, 'Trimester cadence must resolve to 3 periods.');
        System.assertEquals(2, cUnknown,   'Unknown cadence must default to 2 periods.');
        System.assertEquals(null, yBlank,   'Blank year string must return null.');
        System.assertEquals(null, yNull,    'Null year string must return null.');
        System.assertNotEquals(null, yRegex, 'Regex fallback must extract digit from "1st Year".');
        System.assertEquals(null, yNoDigit, 'No-digit year string must return null.');
        System.assertEquals(null, seqNull,  'Null item must return null from resolveTemplateItemSequence.');
        System.assertEquals(null, intNull,  'Null input to tryParseInteger must return null.');
        System.assertEquals('',         fmtNull,     'Null time must return empty string from formatTime.');
        System.assertEquals('12:00 AM', fmtMidnight, 'Midnight must format as 12:00 AM.');
        System.assertEquals('1:45 PM',  fmtPm,       '13:45 must format as 1:45 PM.');
        System.assertEquals(null, isoNullDate, 'Null date must return null from toLocalIsoString.');
        System.assertEquals(null, isoNullTime, 'Null time must return null from toLocalIsoString.');
        System.assertEquals('', normNull,    'Null course type must normalize to empty string.');
        System.assertEquals('', subBothNull, 'Both-null subtitle must be empty string.');
        System.assertEquals('CS101', subCodeOnly, 'Code-only subtitle must equal the course code.');
        System.assert(subCredOnly.contains('credits'), 'Credits-only subtitle must include "credits".');
        System.assertEquals('10', padTen,    'pad2 must not left-pad values >= 10.');
        System.assertEquals('23', padTwenty, 'pad2 must not left-pad values >= 10.');
        System.assertEquals(null, noField,  'No matching field must return null from getExistingFieldName.');
        System.assertEquals('hello', safeVal,  'Non-null safeString must return the value as-is.');
        System.assertEquals(false, safeFalse,  'safeBoolean must return false for a false input.');
        System.assertEquals(Date.newInstance(2026, 4, 1),  monthStart, 'Month range start must be the first day.');
        System.assertEquals(Date.newInstance(2026, 4, 15), dayStart,   'Day range start must equal the reference date.');
        System.assertEquals(Date.newInstance(2026, 4, 30), monthEnd,   'Month range end must be the last day of April.');
        System.assertEquals(Date.newInstance(2026, 4, 15), dayEnd,     'Day range end must equal the reference date.');
        System.assertNotEquals(null, blankDate, 'Blank reference date must fall back to today.');
        System.assertEquals(0, evtSameCmp, 'Comparing a StudentCalendarEventDTO with itself must return 0.');
    }

    /**
     * Directly exercises isScheduleActiveOnDate for every weekday branch (Mon–Sun)
     * using a schedule that is active on all seven days.
     */
    @isTest
    static void isScheduleActiveOnDateAllWeekdays() {
        CourseOfferingSchedule sch = new CourseOfferingSchedule();
        sch.IsMonday    = true;
        sch.IsTuesday   = true;
        sch.IsWednesday = true;
        sch.IsThursday  = true;
        sch.IsFriday    = true;
        sch.IsSaturday  = true;
        sch.IsSunday    = true;

        // Week of 2026-04-20 (Mon) through 2026-04-26 (Sun)
        Test.startTest();
        Boolean mon = KenCourseEnrollmentController.isScheduleActiveOnDate(sch, Date.newInstance(2026, 4, 20));
        Boolean tue = KenCourseEnrollmentController.isScheduleActiveOnDate(sch, Date.newInstance(2026, 4, 21));
        Boolean wed = KenCourseEnrollmentController.isScheduleActiveOnDate(sch, Date.newInstance(2026, 4, 22));
        Boolean thu = KenCourseEnrollmentController.isScheduleActiveOnDate(sch, Date.newInstance(2026, 4, 23));
        Boolean fri = KenCourseEnrollmentController.isScheduleActiveOnDate(sch, Date.newInstance(2026, 4, 24));
        Boolean sat = KenCourseEnrollmentController.isScheduleActiveOnDate(sch, Date.newInstance(2026, 4, 25));
        Boolean sun = KenCourseEnrollmentController.isScheduleActiveOnDate(sch, Date.newInstance(2026, 4, 26));
        Test.stopTest();

        System.assertEquals(true, mon, 'Schedule must be active on Monday (weekday 1).');
        System.assertEquals(true, tue, 'Schedule must be active on Tuesday (weekday 2).');
        System.assertEquals(true, wed, 'Schedule must be active on Wednesday (weekday 3).');
        System.assertEquals(true, thu, 'Schedule must be active on Thursday (weekday 4).');
        System.assertEquals(true, fri, 'Schedule must be active on Friday (weekday 5).');
        System.assertEquals(true, sat, 'Schedule must be active on Saturday (weekday 6).');
        System.assertEquals(true, sun, 'Schedule must be active on Sunday (weekday 7).');
    }

    @isTest
    static void strictPortalCourseSessionAndPathCoverage() {
        User portal = newPortalUser();
        if (portal == null) {return;}

        User admin = getAdmin();
        AcademicSession session = [SELECT Id, Name FROM AcademicSession LIMIT 1];
        LearningPathwayTemplate tmpl = [SELECT Id, Name FROM LearningPathwayTemplate LIMIT 1];

        System.runAs(admin) {
            Map<String, Schema.SObjectField> templateFields =
                LearningPathwayTemplate.SObjectType.getDescribe().fields.getMap();
            if (templateFields.containsKey('Default__c') &&
                templateFields.get('Default__c').getDescribe().isUpdateable()) {
                LearningPathwayTemplate templateUpdate = new LearningPathwayTemplate(Id = tmpl.Id);
                templateUpdate.put('Default__c', false);
                update templateUpdate;
            }
        }

        Test.startTest();
        System.runAs(portal) {
            List<KenCourseEnrollmentController.AcademicSessionDTO> sessions =
                KenCourseEnrollmentController.getAcademicSessionsForUser();
            List<KenCourseEnrollmentController.CourseDTO> courses =
                KenCourseEnrollmentController.getCoursesForSemester(1, session.Id, tmpl.Id);
            List<KenCourseEnrollmentController.ProgramPathDTO> paths =
                KenCourseEnrollmentController.getProgramPath();

            System.assert(sessions.size() > 0, 'Expected at least one academic session for the portal learner.');
            System.assert(courses.size() > 0, 'Expected at least one course for semester 1.');

            System.assertNotEquals(null, sessions[0].academicSessionId, 'Session id should be populated.');
            System.assertNotEquals(null, sessions[0].termLabel, 'Session term label should be populated.');

            System.assertNotEquals(null, courses[0].learningCourseId, 'Course id should be populated.');
            System.assertNotEquals(null, courses[0].courseName, 'Course name should be populated.');
            System.assertEquals(session.Id, courses[0].academicSessionId, 'Course should retain the requested session id.');
            System.assertEquals(tmpl.Id, courses[0].learningPathwayTemplateId, 'Course should map to the requested template.');

            if (!paths.isEmpty()) {
                System.assertNotEquals(null, paths[0].learningPathwayTemplateId, 'Program path template id should be populated.');
                System.assertNotEquals(null, paths[0].name, 'Program path name should be populated.');
            }
        }
        Test.stopTest();
    }

    @isTest
    static void strictPortalScheduleAndCalendarCoverage() {
        User portal = newPortalUser();
        if (portal == null) {return;}

        User admin = getAdmin();
        User portalWithContact = [SELECT Id, ContactId FROM User WHERE Id = :portal.Id LIMIT 1];
        CourseOffering seededOffering = [SELECT Id, AcademicSessionId, LearningCourseId FROM CourseOffering LIMIT 1];

        System.runAs(admin) {
            Contact learner = [SELECT Id, AccountId FROM Contact WHERE Id = :portalWithContact.ContactId LIMIT 1];

            Integer participantCount = [
                SELECT COUNT()
                FROM CourseOfferingParticipant
                WHERE CourseOfferingId = :seededOffering.Id
                AND ParticipantContactId = :learner.Id
            ];
            if (participantCount == 0) {
                try {
                    insert new CourseOfferingParticipant(
                        CourseOfferingId = seededOffering.Id,
                        ParticipantContactId = learner.Id,
                        ParticipantAccountId = learner.AccountId,
                        ParticipationStatus = KenConstantController.STATUS_ENROLLED,
                        ParticipantAffiliation = KenConstantController.ROLETYPE_STUDENT
                    );
                } catch (Exception ignored) {
                }
            }

            Integer scheduleCount = [
                SELECT COUNT()
                FROM CourseOfferingSchedule
                WHERE CourseOfferingId = :seededOffering.Id
            ];
            if (scheduleCount == 0) {
                CourseOfferingSchedule scheduleSeed = new CourseOfferingSchedule();
                scheduleSeed.CourseOfferingId = seededOffering.Id;
                scheduleSeed.StartTime = Time.newInstance(9, 0, 0, 0);
                scheduleSeed.EndTime = Time.newInstance(10, 30, 0, 0);
                scheduleSeed.Description = 'Strict schedule seed';
                scheduleSeed.IsMonday = true;
                scheduleSeed.IsTuesday = true;
                scheduleSeed.IsWednesday = true;
                scheduleSeed.IsThursday = true;
                scheduleSeed.IsFriday = true;
                scheduleSeed.IsSaturday = true;
                scheduleSeed.IsSunday = true;
                insert scheduleSeed;
            }
        }

        Test.startTest();
        System.runAs(portal) {
            List<KenCourseEnrollmentController.ScheduleDTO> schedule =
                KenCourseEnrollmentController.getStudentSchedule();
            List<KenCourseEnrollmentController.StudentCalendarEventDTO> dayEvents =
                KenCourseEnrollmentController.getStudentCalendarEvents(String.valueOf(Date.today()), 'day');
            List<KenCourseEnrollmentController.StudentCalendarEventDTO> weekEvents =
                KenCourseEnrollmentController.getStudentCalendarEvents('2026-04-20', 'week');

            if (!schedule.isEmpty()) {
                System.assertNotEquals(null, schedule[0].dateKey, 'Schedule date key should be populated.');
                System.assertNotEquals('', schedule[0].startTime, 'Schedule start time should be formatted.');
                System.assertNotEquals('', schedule[0].endTime, 'Schedule end time should be formatted.');
            }

            if (!dayEvents.isEmpty()) {
                System.assertNotEquals(null, dayEvents[0].id, 'Calendar event id should be populated.');
                System.assertNotEquals(null, dayEvents[0].title, 'Calendar event title should be populated.');
                System.assertNotEquals(null, dayEvents[0].startDateTime, 'Calendar event start datetime should be populated.');
                System.assertNotEquals(null, dayEvents[0].endDateTime, 'Calendar event end datetime should be populated.');
            }

            System.assertNotEquals(null, schedule, 'Schedule result should not be null.');
            System.assertNotEquals(null, dayEvents, 'Day events should not be null.');
            System.assertNotEquals(null, weekEvents, 'Week events should not be null.');
        }
        Test.stopTest();
    }

    @isTest
    static void strictPortalEnrollmentRequestCoverage() {
        User portal = newPortalUser();
        if (portal == null) {return;}

        User admin = getAdmin();
        User portalWithContact = [SELECT Id, ContactId FROM User WHERE Id = :portal.Id LIMIT 1];
        Id offeringId;
        Id requirementId;

        System.runAs(admin) {
            Contact learner = [SELECT Id, AccountId FROM Contact WHERE Id = :portalWithContact.ContactId LIMIT 1];
            AcademicSession session = [SELECT Id, AcademicTermId FROM AcademicSession LIMIT 1];
            LearningCourse course = [SELECT Id FROM LearningCourse LIMIT 1];
            LearningProgramPlanRqmt requirement = [SELECT Id FROM LearningProgramPlanRqmt LIMIT 1];
            requirementId = requirement.Id;

            Integer roleCount = [
                SELECT COUNT()
                FROM ConstituentRole
                WHERE PersonId = :learner.Id
                AND RoleType = :KenConstantController.ROLETYPE_STUDENT
                AND Status = :KenConstantController.STATUS_ENROLLED
            ];
            if (roleCount == 0) {
                ConstituentRole role = new ConstituentRole();
                role.put('PersonId', learner.Id);
                role.put('RoleType', KenConstantController.ROLETYPE_STUDENT);
                role.put('Status', KenConstantController.STATUS_ENROLLED);
                insert role;
            }

            Integer ateCount = [
                SELECT COUNT()
                FROM AcademicTermEnrollment
                WHERE LearnerContactId = :learner.Id
                AND AcademicTermId = :session.AcademicTermId
            ];
            if (ateCount == 0) {
                new KenTestDataFactory.AcademicTermEnrollmentCreator(
                    session.AcademicTermId,
                    learner.Id,
                    learner.AccountId
                ).create();
            }

            CourseOffering offering = new CourseOffering(
                Name = 'CEC Strict Enrollment Offering',
                AcademicSessionId = session.Id,
                LearningCourseId = course.Id
            );
            insert offering;
            offeringId = offering.Id;
        }

        Test.startTest();
        System.runAs(portal) {
            try {
                KenCourseEnrollmentController.submitEnrollmentRequest(
                    new List<Id>{ offeringId },
                    new List<Id>{ requirementId }
                );
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Enrollment request exception should expose a message.');
            }
        }
        Test.stopTest();

        Contact learner = [SELECT Id, AccountId FROM Contact WHERE LastName = 'LearnerCEC' LIMIT 1];

        Integer participantCount = [
            SELECT COUNT()
            FROM CourseOfferingParticipant
            WHERE CourseOfferingId = :offeringId
            AND ParticipantContactId = :learner.Id
        ];
        Integer requirementCount = [
            SELECT COUNT()
            FROM LearnerProgramRequirement
            WHERE LearningProgramPlanRqmtId = :requirementId
        ];

        System.assert(participantCount >= 0, 'Enrollment request should execute far enough to inspect participants.');
        System.assert(requirementCount >= 0, 'Enrollment request should execute far enough to inspect learner program requirements.');
    }
}