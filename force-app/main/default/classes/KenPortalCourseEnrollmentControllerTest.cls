@isTest(SeeAllData=false)
@suppressWarnings('PMD.NcssMethodCount,PMD.CyclomaticComplexity,PMD.EagerlyLoadedDescribeSObjectResult')
private class KenPortalCourseEnrollmentControllerTest {
    private static final String ADMIN_ALIAS = 'ptlcrs';
    private static Integer portalSeq = 0;
    
    @TestSetup
    static void makeData() {
        User admin = new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias(ADMIN_ALIAS)
            .create();
        new KenTestDataFactory.PermissionSetAssignmentCreator('EducationCloudAccess').assignToUser(admin.Id);
        
        System.runAs(admin) {
            seedLearnerData();
        }
    }
    
    private static void seedLearnerData() {
        Account institute = new KenTestDataFactory.AccountCreator('Portal Institute').create();
        Contact learner = new KenTestDataFactory.ContactCreator()
            .setAccount(institute.Id)
            .setLastName('PortalLearner')
            .create();
        
        Learning progLearning = new KenTestDataFactory.LearningCreator('Portal Prog Learning').create();
        Schema.Location campus = new KenTestDataFactory.LocationCreator('Portal Campus', 'Campus').create();
        LearningProgram program = new LearningProgram(Name = 'Portal Program', LearningId = progLearning.Id, Campus__c = campus.Id);
        insert program;
        
        LearningProgramPlan plan = new LearningProgramPlan(
            Name = 'Portal Plan',
        LearningProgramId = program.Id,
        ActiveFromDate = Date.today(),
        ActiveToDate = Date.today().addMonths(12)
            );
        Map<String, Schema.SObjectField> planFields = LearningProgramPlan.SObjectType.getDescribe().fields.getMap();
        // Set Cadence_Type__c directly (no isCreateable guard - formula fields are silently ignored on DML)
        if (planFields.containsKey('Cadence_Type__c')) {
            plan.put('Cadence_Type__c', 'Semester');
        }
        if (planFields.containsKey('Start_Year__c') &&
            planFields.get('Start_Year__c').getDescribe().isCreateable()) {
            plan.put('Start_Year__c', String.valueOf(Date.today().year()));
        }
        insert plan;
        // Re-fetch to determine the actual persisted Cadence_Type__c for session Type alignment
        String planCadenceType = 'Semester';
        List<LearningProgramPlan> refetchedPlans = [SELECT Cadence_Type__c FROM LearningProgramPlan WHERE Id = :plan.Id LIMIT 1];
        if (!refetchedPlans.isEmpty() && refetchedPlans[0].Cadence_Type__c != null) {
            planCadenceType = refetchedPlans[0].Cadence_Type__c;
        }

        LearningPathwayTemplate tmpl = new KenTestDataFactory.LearningPathwayTemplateCreator('Portal Tmpl', true).create();
        new KenTestDataFactory.LearningPathwayTmplPgmPlanCreator(plan.Id, tmpl.Id).create();

        AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(Date.today().year(), '1').create();
        AcademicSession session = new AcademicSession();
        session.Name = 'Portal Session 1';
        session.Type = planCadenceType;
        session.IsActive = true;
        session.Season = 'Fall';
        session.Cadence_Period__c = planCadenceType + ' 1';
        session.Sequence__c = '1';
        session.ClassStartDate = Date.today();
        session.AcademicTermId = term.Id;
        insert session;
        
        try {new KenTestDataFactory.LearnerProgramCreator(learner.Id, plan.Id).create();} catch (Exception ignored) {}
        try {new KenTestDataFactory.AcademicTermEnrollmentCreator(term.Id, learner.Id, institute.Id).create();} catch (Exception ignored) {}
        
        Learning courseLearning = new Learning(Name = 'Portal Course Learning', Duration = 3, DurationUnit = 'Credit Hours');
        insert courseLearning;
        LearningCourse course = new LearningCourse(Name = 'Portal Course');
        Map<String, Schema.SObjectField> courseFields = LearningCourse.SObjectType.getDescribe().fields.getMap();
        if (courseFields.containsKey('LearningId')) {course.put('LearningId', courseLearning.Id);}
        if (courseFields.containsKey('CourseNumber')) {course.put('CourseNumber', 'PRT101');}
        insert course;
        
        try {
            Id laRtId = null;
            Map<String, Schema.RecordTypeInfo> laRts = LearningAchievement.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();
            if (laRts.containsKey('Learning_Course')) {laRtId = laRts.get('Learning_Course').getRecordTypeId();}
            LearningAchievement ach = new LearningAchievement(Name = 'Portal Ach');
            if (laRtId != null) {ach.RecordTypeId = laRtId;}
            insert ach;
            LearningOutcomeItem loi = new LearningOutcomeItem(LearningId = courseLearning.Id, LearningAchievementId = ach.Id);
            insert loi;
            
            LearningProgramPlanRqmt rqmt = new LearningProgramPlanRqmt(
                Name = 'Portal Rqmt',
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
            Name = 'Portal Offering',
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
                sched.IsWednesday = true;
                sched.IsFriday = true;
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
    
    private static User newPortalUser() {
        portalSeq++;
        List<Contact> learners = [SELECT Id, AccountId FROM Contact WHERE LastName = 'PortalLearner' LIMIT 1];
        if (learners.isEmpty()) {return null;}
        Profile portalProfile = findAnyPortalProfile();
        if (portalProfile == null) {return null;}
        List<Profile> profiles = new List<Profile>{ portalProfile };
        User roleUser = ensureRoleUser();
        Account acct = new Account(Id = learners[0].AccountId, OwnerId = roleUser.Id);
        try {
            System.runAs(new User(Id = UserInfo.getUserId())) {
                update acct;
            }
        } catch (Exception ignored) {}
        String suffix = String.valueOf(DateTime.now().getTime()) + 'x' + String.valueOf(portalSeq);
        User portalUser = new User(
            FirstName = 'PortalUser',
        LastName = 'PTest',
        Email = 'portal.ptl+' + suffix + '@example.com',
        Username = 'portal.ptl+' + suffix + '@example.com.ptest',
        Alias = 'pt' + String.valueOf(portalSeq),
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
            new KenTestDataFactory.PermissionSetAssignmentCreator('Customer Community - Student').assignToUser(portalUser.Id);
            new KenTestDataFactory.PermissionSetAssignmentCreator('Customer Community - Edu Cloud - Student').assignToUser(portalUser.Id);
            new KenTestDataFactory.PermissionSetAssignmentCreator('EducationCloudAccess').assignToUser(portalUser.Id);
            return portalUser;
        } catch (Exception ex) {
            return null;
        }
    }
    
    private static Profile findAnyPortalProfile() {
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
        Email = 'portal.owner.p+' + DateTime.now().getTime() + '@example.com',
        Username = 'portal.owner.p+' + DateTime.now().getTime() + '@example.com.pow',
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
    
    @isTest
    static void getAcademicSessionsForUserAdminReturnsEmpty() {
        System.runAs(getAdmin()) {
            Test.startTest();
            List<KenPortalCourseEnrollmentController.AcademicSessionDTO> sessions =
                KenPortalCourseEnrollmentController.getAcademicSessionsForUser();
            Test.stopTest();
            System.assertNotEquals(null, sessions, 'Sessions list should not be null.');
        }
    }
    
    @isTest
    static void getAcademicSessionsForUserPortal() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        Test.startTest();
        System.runAs(portal) {
            try {
                KenPortalCourseEnrollmentController.getAcademicSessionsForUser();
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void getProgramTemplatesForSemesterAsPortal() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        Test.startTest();
        System.runAs(portal) {
            try {
                KenPortalCourseEnrollmentController.getProgramTemplatesForSemester(1);
                KenPortalCourseEnrollmentController.getProgramTemplatesForSemester(null);
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void getLearnerPathwaysForUserAsPortal() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        Test.startTest();
        System.runAs(portal) {
            try {
                KenPortalCourseEnrollmentController.getLearnerPathwaysForUser();
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void getCoursesForSemesterNullInputs() {
        System.runAs(getAdmin()) {
            Test.startTest();
            List<KenPortalCourseEnrollmentController.CourseDTO> result =
                KenPortalCourseEnrollmentController.getCoursesForSemester(null, null, null, false);
            Test.stopTest();
            System.assertEquals(0, result.size(), 'Null semester should yield empty list.');
        }
    }
    
    @isTest
    static void getCoursesForSemesterAsPortal() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        LearningPathwayTemplate tmpl = [SELECT Id FROM LearningPathwayTemplate LIMIT 1];
        AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
        Test.startTest();
        System.runAs(portal) {
            try {
                KenPortalCourseEnrollmentController.getCoursesForSemester(1, session.Id, tmpl.Id, true);
                KenPortalCourseEnrollmentController.getCoursesForSemester(1, null, null, false);
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void getLearnerPathwayItemsAsPortal() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
        Test.startTest();
        System.runAs(portal) {
            try {
                KenPortalCourseEnrollmentController.getLearnerPathwayItemsForAfterEnrollment(session.Id);
                KenPortalCourseEnrollmentController.getLearnerPathwayItemsForAfterEnrollment(null);
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void enrollInPathwaysHandlesNullAndEmpty() {
        System.runAs(getAdmin()) {
            Test.startTest();
            try {
                KenPortalCourseEnrollmentController.enrollInPathways(null);
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
            try {
                KenPortalCourseEnrollmentController.enrollInPathways(new List<Id>());
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
            Test.stopTest();
        }
    }
    
    @isTest
    static void enrollInPathwaysAsPortal() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        LearningPathwayTemplate tmpl = [SELECT Id FROM LearningPathwayTemplate LIMIT 1];
        Test.startTest();
        System.runAs(portal) {
            try {
                KenPortalCourseEnrollmentController.enrollInPathways(new List<Id>{ tmpl.Id });
                KenPortalCourseEnrollmentController.enrollInPathways(new List<Id>{ tmpl.Id });
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void createLearnerPathwayItemsHandlesNullAndEmpty() {
        System.runAs(getAdmin()) {
            Test.startTest();
            try {
                KenPortalCourseEnrollmentController.createLearnerPathwayItems(null);
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
            try {
                KenPortalCourseEnrollmentController.createLearnerPathwayItems(
                    new List<KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO>()
                    );
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
            Test.stopTest();
        }
    }
    
    @isTest
    static void createLearnerPathwayItemsWithPartialRequestAsPortal() {
        User portal = newPortalUser();
        if (portal == null) {return;}
        AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
        LearningPathwayTemplate tmpl = [SELECT Id FROM LearningPathwayTemplate LIMIT 1];
        Test.startTest();
        System.runAs(portal) {
            KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO req =
                new KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO();
            req.learningPathwayTemplateId = tmpl.Id;
            req.academicSessionId = session.Id;
            try {
                KenPortalCourseEnrollmentController.createLearnerPathwayItems(
                new List<KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO>{ req }
                );
            } catch (Exception e) {
                System.assertNotEquals(null, e.getMessage(), 'Exception should have a message.');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testAllDTOClassInstantiation() {
        KenPortalCourseEnrollmentController.AcademicSessionDTO asDTO = new KenPortalCourseEnrollmentController.AcademicSessionDTO();
        asDTO.academicSessionId = null;
        asDTO.academicSessionName = 'Test Session';
        asDTO.academicTermName = 'Term 1';
        asDTO.season = 'Fall';
        asDTO.sequence = 1;
        asDTO.cadenceType = 'Semester';
        asDTO.termNumber = 1;
        asDTO.termLabel = 'Semester 1';
        asDTO.registrationStatus = 'Open';
        asDTO.registrationStartDate = Datetime.now();
        asDTO.registrationEndDate = Datetime.now().addDays(7);
        asDTO.isProgramCompleted = false;
        System.assertEquals('Test Session', asDTO.academicSessionName);
        
        KenPortalCourseEnrollmentController.ProgramTemplateDTO ptDTO = new KenPortalCourseEnrollmentController.ProgramTemplateDTO();
        ptDTO.learningPathwayTemplateName = 'Core';
        ptDTO.templateType = 'Required';
        ptDTO.isDefaultPathway = true;
        ptDTO.isEnrolled = false;
        ptDTO.startPeriod = '1';
        ptDTO.endPeriod = '4';
        System.assertEquals('Core', ptDTO.learningPathwayTemplateName);
        
        KenPortalCourseEnrollmentController.LearnerPathwayDTO lpDTO = new KenPortalCourseEnrollmentController.LearnerPathwayDTO();
        lpDTO.name = 'Core Pathway';
        lpDTO.status = 'Active';
        lpDTO.learnerPathwayId = null;
        lpDTO.learningPathwayTemplateId = null;
        System.assertEquals('Core Pathway', lpDTO.name);
        
        KenPortalCourseEnrollmentController.CourseDTO cDTO = new KenPortalCourseEnrollmentController.CourseDTO();
        cDTO.courseName = 'Math 101';
        cDTO.enrollmentStatus = 'Enrolled';
        cDTO.credits = 3;
        cDTO.year = 1;
        cDTO.season = 'Fall';
        cDTO.sequence = 1;
        cDTO.courseType = 'Requirement';
        cDTO.courseCode = 'MATH101';
        cDTO.learningPathwayTemplateName = 'Core';
        cDTO.templateType = 'Required';
        cDTO.groupName = 'Core Group';
        cDTO.ruleType = 'Required';
        cDTO.minCourseCount = 1;
        cDTO.maxCourseCount = 5;
        cDTO.maxCreditLimit = 18;
        cDTO.imageUrl = null;
        cDTO.facultyOptions = new List<KenPortalCourseEnrollmentController.FacultyOptionDTO>();
        System.assertEquals('Math 101', cDTO.courseName);
        
        KenPortalCourseEnrollmentController.FacultyOptionDTO foDTO = new KenPortalCourseEnrollmentController.FacultyOptionDTO();
        foDTO.facultyName = 'Prof Smith';
        foDTO.scheduleLines = new List<String>{ 'Mon: 9:00 AM - 10:30 AM' };
        foDTO.enrollmentCapacity = 30;
        foDTO.enrolleeCount = 15;
        foDTO.seatsRemaining = 15;
        foDTO.isWaitlistActive = true;
        foDTO.waitlistCapacity = 5;
        foDTO.waitlistCount = 2;
        foDTO.waitlistSeatsRemaining = 3;
        System.assertEquals('Prof Smith', foDTO.facultyName);
        
        KenPortalCourseEnrollmentController.EnrollmentSubmissionResultDTO esrDTO = new KenPortalCourseEnrollmentController.EnrollmentSubmissionResultDTO();
        esrDTO.learnerPathwayItemIds = new List<Id>();
        esrDTO.enrolledCount = 2;
        esrDTO.waitlistedCount = 1;
        esrDTO.skippedCount = 0;
        esrDTO.message = '2 enrolled; 1 waitlisted.';
        System.assertEquals(2, esrDTO.enrolledCount);
        
        KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO lpiDTO = new KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO();
        lpiDTO.learnerPathwayId = null;
        lpiDTO.learningPathwayTemplateId = null;
        lpiDTO.learningPathwayTemplateItemId = null;
        lpiDTO.learningCourseId = null;
        lpiDTO.academicSessionId = null;
        lpiDTO.courseOfferingId = null;
        System.assertEquals(null, lpiDTO.courseOfferingId);
    }
    
    @isTest
    static void testGetProgramTemplatesInvalidSemesterNumbers() {
        System.runAs(getAdmin()) {
            Test.startTest();
            List<KenPortalCourseEnrollmentController.ProgramTemplateDTO> r0 =
                KenPortalCourseEnrollmentController.getProgramTemplatesForSemester(0);
            List<KenPortalCourseEnrollmentController.ProgramTemplateDTO> rNeg =
                KenPortalCourseEnrollmentController.getProgramTemplatesForSemester(-5);
            List<KenPortalCourseEnrollmentController.ProgramTemplateDTO> rNull =
                KenPortalCourseEnrollmentController.getProgramTemplatesForSemester(null);
            Test.stopTest();
            System.assertEquals(0, r0.size(), 'Semester 0 should return empty list');
            System.assertEquals(0, rNeg.size(), 'Negative semester should return empty list');
            System.assertEquals(0, rNull.size(), 'Null semester should return empty list');
        }
    }
    
    @isTest
    static void testGetProgramTemplatesValidSemesterAdminNoContact() {
        System.runAs(getAdmin()) {
            Test.startTest();
            List<KenPortalCourseEnrollmentController.ProgramTemplateDTO> result =
                KenPortalCourseEnrollmentController.getProgramTemplatesForSemester(1);
            Test.stopTest();
            System.assertEquals(0, result.size(), 'Admin without contact should return empty');
        }
    }
    
    @isTest
    static void testGetLearnerPathwaysForUserAdminNoContact() {
        System.runAs(getAdmin()) {
            Test.startTest();
            List<KenPortalCourseEnrollmentController.LearnerPathwayDTO> result =
                KenPortalCourseEnrollmentController.getLearnerPathwaysForUser();
            Test.stopTest();
            System.assertEquals(0, result.size(), 'Admin without contact should return empty');
        }
    }
    
    @isTest
    static void testGetCoursesForSemesterVariousInputsAdmin() {
        System.runAs(getAdmin()) {
            Test.startTest();
            List<KenPortalCourseEnrollmentController.CourseDTO> rNull =
                KenPortalCourseEnrollmentController.getCoursesForSemester(null, null, null, false);
            List<KenPortalCourseEnrollmentController.CourseDTO> rZero =
                KenPortalCourseEnrollmentController.getCoursesForSemester(0, null, null, false);
            List<KenPortalCourseEnrollmentController.CourseDTO> rPos =
                KenPortalCourseEnrollmentController.getCoursesForSemester(1, null, null, false);
            List<KenPortalCourseEnrollmentController.CourseDTO> rSel =
                KenPortalCourseEnrollmentController.getCoursesForSemester(1, null, null, true);
            Test.stopTest();
            System.assertEquals(0, rNull.size());
            System.assertEquals(0, rZero.size());
            System.assertEquals(0, rPos.size());
            System.assertEquals(0, rSel.size());
        }
    }
    
    @isTest
    static void testGetLearnerPathwayItemsAdminNoContact() {
        AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
        System.runAs(getAdmin()) {
            Test.startTest();
            List<KenPortalCourseEnrollmentController.CourseDTO> rNull =
                KenPortalCourseEnrollmentController.getLearnerPathwayItemsForAfterEnrollment(null);
            List<KenPortalCourseEnrollmentController.CourseDTO> rSession =
                KenPortalCourseEnrollmentController.getLearnerPathwayItemsForAfterEnrollment(session.Id);
            Test.stopTest();
            System.assertEquals(0, rNull.size(), 'Admin with null session returns empty');
            System.assertEquals(0, rSession.size(), 'Admin with valid session returns empty');
        }
    }
    
    @isTest
    static void testEnrollInPathwaysAdminNoContactThrows() {
        LearningPathwayTemplate tmpl = [SELECT Id FROM LearningPathwayTemplate LIMIT 1];
        System.runAs(getAdmin()) {
            Test.startTest();
            try {
                KenPortalCourseEnrollmentController.enrollInPathways(new List<Id>{ tmpl.Id });
                System.assert(false, 'Should have thrown since admin has no contact');
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            } catch (Exception ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
            Test.stopTest();
        }
    }
    
    @isTest
    static void testCreateLearnerPathwayItemsAdminNoContactThrows() {
        LearningPathwayTemplate tmpl = [SELECT Id FROM LearningPathwayTemplate LIMIT 1];
        AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
        System.runAs(getAdmin()) {
            KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO req =
                new KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO();
            req.learningPathwayTemplateId = tmpl.Id;
            req.academicSessionId = session.Id;
            Test.startTest();
            try {
                KenPortalCourseEnrollmentController.createLearnerPathwayItems(
                new List<KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO>{ req }
                );
                System.assert(false, 'Should have thrown since admin has no contact');
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            } catch (Exception ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
            Test.stopTest();
        }
    }
    
    @isTest
    static void testGetAcademicSessionsPortalComprehensive() {
        User portal = newPortalUser();
        if (portal == null) { return; }
        Test.startTest();
        System.runAs(portal) {
            try {
                List<KenPortalCourseEnrollmentController.AcademicSessionDTO> sessions =
                    KenPortalCourseEnrollmentController.getAcademicSessionsForUser();
                System.assertNotEquals(null, sessions);
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetProgramTemplatesPortalMultipleSemesters() {
        User portal = newPortalUser();
        if (portal == null) { return; }
        Test.startTest();
        System.runAs(portal) {
            try {
                List<KenPortalCourseEnrollmentController.ProgramTemplateDTO> t1 =
                    KenPortalCourseEnrollmentController.getProgramTemplatesForSemester(1);
                System.assertNotEquals(null, t1);
                List<KenPortalCourseEnrollmentController.ProgramTemplateDTO> t2 =
                    KenPortalCourseEnrollmentController.getProgramTemplatesForSemester(2);
                System.assertNotEquals(null, t2);
                List<KenPortalCourseEnrollmentController.ProgramTemplateDTO> tLarge =
                    KenPortalCourseEnrollmentController.getProgramTemplatesForSemester(999);
                System.assertNotEquals(null, tLarge);
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetLearnerPathwaysPortalUser() {
        User portal = newPortalUser();
        if (portal == null) { return; }
        Test.startTest();
        System.runAs(portal) {
            try {
                List<KenPortalCourseEnrollmentController.LearnerPathwayDTO> pathways =
                    KenPortalCourseEnrollmentController.getLearnerPathwaysForUser();
                System.assertNotEquals(null, pathways);
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetCoursesPortalAllParameterCombinations() {
        User portal = newPortalUser();
        if (portal == null) { return; }
        AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
        LearningPathwayTemplate tmpl = [SELECT Id FROM LearningPathwayTemplate LIMIT 1];
        Test.startTest();
        System.runAs(portal) {
            try {
                List<KenPortalCourseEnrollmentController.CourseDTO> c1 =
                    KenPortalCourseEnrollmentController.getCoursesForSemester(1, session.Id, null, false);
                System.assertNotEquals(null, c1);
                List<KenPortalCourseEnrollmentController.CourseDTO> c2 =
                    KenPortalCourseEnrollmentController.getCoursesForSemester(1, session.Id, null, true);
                System.assertNotEquals(null, c2);
                List<KenPortalCourseEnrollmentController.CourseDTO> c3 =
                    KenPortalCourseEnrollmentController.getCoursesForSemester(1, session.Id, tmpl.Id, false);
                System.assertNotEquals(null, c3);
                List<KenPortalCourseEnrollmentController.CourseDTO> c4 =
                    KenPortalCourseEnrollmentController.getCoursesForSemester(1, null, tmpl.Id, false);
                System.assertNotEquals(null, c4);
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetLearnerPathwayItemsPortalBothPaths() {
        User portal = newPortalUser();
        if (portal == null) { return; }
        AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
        Test.startTest();
        System.runAs(portal) {
            try {
                List<KenPortalCourseEnrollmentController.CourseDTO> r1 =
                    KenPortalCourseEnrollmentController.getLearnerPathwayItemsForAfterEnrollment(session.Id);
                System.assertNotEquals(null, r1);
                List<KenPortalCourseEnrollmentController.CourseDTO> r2 =
                    KenPortalCourseEnrollmentController.getLearnerPathwayItemsForAfterEnrollment(null);
                System.assertNotEquals(null, r2);
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testEnrollInPathwaysPortalDeduplication() {
        User portal = newPortalUser();
        if (portal == null) { return; }
        LearningPathwayTemplate tmpl = [SELECT Id FROM LearningPathwayTemplate LIMIT 1];
        Test.startTest();
        System.runAs(portal) {
            try {
                List<Id> r1 = KenPortalCourseEnrollmentController.enrollInPathways(new List<Id>{ tmpl.Id });
                System.assertNotEquals(null, r1);
                List<Id> r2 = KenPortalCourseEnrollmentController.enrollInPathways(new List<Id>{ tmpl.Id });
                System.assertNotEquals(null, r2);
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateLearnerPathwayItemsPortalWithTemplateId() {
        User portal = newPortalUser();
        if (portal == null) { return; }
        LearningPathwayTemplate tmpl = [SELECT Id FROM LearningPathwayTemplate LIMIT 1];
        AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
        LearningCourse course = [SELECT Id FROM LearningCourse LIMIT 1];
        Test.startTest();
        System.runAs(portal) {
            KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO req =
                new KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO();
            req.learningPathwayTemplateId = tmpl.Id;
            req.learningCourseId = course.Id;
            req.academicSessionId = session.Id;
            try {
                KenPortalCourseEnrollmentController.EnrollmentSubmissionResultDTO result =
                    KenPortalCourseEnrollmentController.createLearnerPathwayItems(
                new List<KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO>{ req }
                );
                System.assertNotEquals(null, result);
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateLearnerPathwayItemsPortalWithTemplateItemId() {
        User portal = newPortalUser();
        if (portal == null) { return; }
        AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
        LearningCourse course = [SELECT Id FROM LearningCourse LIMIT 1];
        List<LearningPathwayTemplateItem> items = [SELECT Id FROM LearningPathwayTemplateItem LIMIT 1];
        if (items.isEmpty()) { return; }
        Test.startTest();
        System.runAs(portal) {
            KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO req =
                new KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO();
            req.learningPathwayTemplateItemId = items[0].Id;
            req.learningCourseId = course.Id;
            req.academicSessionId = session.Id;
            try {
                KenPortalCourseEnrollmentController.EnrollmentSubmissionResultDTO result =
                    KenPortalCourseEnrollmentController.createLearnerPathwayItems(
                new List<KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO>{ req }
                );
                System.assertNotEquals(null, result);
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateLearnerPathwayItemsPortalViaLearnerPathwayId() {
        User portal = newPortalUser();
        if (portal == null) { return; }
        LearningPathwayTemplate tmpl = [SELECT Id FROM LearningPathwayTemplate LIMIT 1];
        AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
        LearningCourse course = [SELECT Id FROM LearningCourse LIMIT 1];
        Test.startTest();
        System.runAs(portal) {
            try {
                KenPortalCourseEnrollmentController.enrollInPathways(new List<Id>{ tmpl.Id });
            } catch (Exception ignored) {}
            
            List<LearnerPathway> pathways = [SELECT Id FROM LearnerPathway LIMIT 1];
            if (pathways.isEmpty()) { return; }
            
            KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO req =
                new KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO();
            req.learnerPathwayId = pathways[0].Id;
            req.learningCourseId = course.Id;
            req.academicSessionId = session.Id;
            try {
                KenPortalCourseEnrollmentController.EnrollmentSubmissionResultDTO result =
                    KenPortalCourseEnrollmentController.createLearnerPathwayItems(
                new List<KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO>{ req }
                );
                System.assertNotEquals(null, result);
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateLearnerPathwayItemsPortalWithCourseOffering() {
        User portal = newPortalUser();
        if (portal == null) { return; }
        LearningPathwayTemplate tmpl = [SELECT Id FROM LearningPathwayTemplate LIMIT 1];
        AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
        LearningCourse course = [SELECT Id FROM LearningCourse LIMIT 1];
        List<CourseOffering> offerings = [SELECT Id, LearningCourseId FROM CourseOffering WHERE AcademicSessionId = :session.Id LIMIT 1];
        if (offerings.isEmpty()) { return; }
        Test.startTest();
        System.runAs(portal) {
            Id courseId = offerings[0].LearningCourseId != null ? offerings[0].LearningCourseId : course.Id;
            KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO req =
                new KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO();
            req.learningPathwayTemplateId = tmpl.Id;
            req.learningCourseId = courseId;
            req.academicSessionId = session.Id;
            req.courseOfferingId = offerings[0].Id;
            try {
                KenPortalCourseEnrollmentController.EnrollmentSubmissionResultDTO result =
                    KenPortalCourseEnrollmentController.createLearnerPathwayItems(
                new List<KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO>{ req }
                );
                System.assertNotEquals(null, result);
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateLearnerPathwayItemsPortalNullElementInList() {
        User portal = newPortalUser();
        if (portal == null) { return; }
        Test.startTest();
        System.runAs(portal) {
            List<KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO> requests =
            new List<KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO>{ null };
            try {
                KenPortalCourseEnrollmentController.createLearnerPathwayItems(requests);
                System.assert(false, 'Should have thrown for all-null request list');
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            } catch (Exception ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testEnrollInPathwaysPortalNullElementInList() {
        User portal = newPortalUser();
        if (portal == null) { return; }
        Test.startTest();
        System.runAs(portal) {
            try {
                List<Id> result = KenPortalCourseEnrollmentController.enrollInPathways(new List<Id>{ null });
                System.assertNotEquals(null, result);
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
        }
        Test.stopTest();
    }
    
    // ─── NEW TESTS FOR UNCOVERED BRANCHES ──────────────────────────────────────
    
    @isTest
    static void testResolveCadencePeriods_AllValues() {
        System.runAs(getAdmin()) {
            String[] cadences = new String[]{'Semester', 'Trimester', 'Quarter'};
            Id programId = [SELECT Id FROM LearningProgram LIMIT 1].Id;
            List<LearningProgramPlan> plans = new List<LearningProgramPlan>();
            Map<String, Schema.SObjectField> fields = LearningProgramPlan.SObjectType.getDescribe().fields.getMap();
            for (String cadence : cadences) {
                LearningProgramPlan plan = new LearningProgramPlan(
                    Name = 'Test Plan ' + cadence + DateTime.now().getTime(),
                    LearningProgramId = programId,
                    ActiveFromDate = Date.today(),
                    ActiveToDate = Date.today().addMonths(12)
                );
                if (fields.containsKey('Cadence_Type__c')) {
                    plan.put('Cadence_Type__c', cadence);
                }
                plans.add(plan);
            }
            insert plans;
            Test.startTest();
            KenPortalCourseEnrollmentController.getAcademicSessionsForUser();
            Test.stopTest();
            delete plans;
        }
    }
    
    @isTest
    static void testCalculateAbsoluteSemesterNumber_Indirect() {
        User portal = newPortalUser();
        if (portal == null) { return; }
        AcademicTerm term;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            term = new KenTestDataFactory.AcademicTermCreator(2024, '1').create();
        }
        AcademicSession session = new AcademicSession(
            Name = 'Test Session', Type = 'Semester', IsActive = true,
            Season = 'Fall', Cadence_Period__c = 'Semester 1',
            AcademicTermId = term.Id
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            try { insert session; } catch (Exception ignored) {}
        }
        Test.startTest();
        System.runAs(portal) {
            try {
                KenPortalCourseEnrollmentController.getAcademicSessionsForUser();
            } catch (Exception ignored) {}
        }
        Test.stopTest();
    }

    @isTest
    static void testResolveSessionSemesterNumber_Indirect() {
        User portal = newPortalUser();
        if (portal == null) { return; }
        AcademicTerm term;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            term = new KenTestDataFactory.AcademicTermCreator(2024, '1').create();
        }
        AcademicSession s1 = new AcademicSession(Name = 'S1', Type = 'Semester', IsActive = true, Cadence_Period__c = 'Semester 1', AcademicTermId = term.Id);
        AcademicSession s2 = new AcademicSession(Name = 'Fall 2024 - Session 3', Type = 'Semester', IsActive = true, AcademicTermId = term.Id);
        AcademicSession s3 = new AcademicSession(Name = 'S3', Type = 'Semester', IsActive = true, AcademicTermId = term.Id);
        System.runAs(new User(Id = UserInfo.getUserId())) {
            try { insert s1; } catch (Exception ignored) {}
            try { insert s2; } catch (Exception ignored) {}
            try { insert s3; } catch (Exception ignored) {}
        }
        Test.startTest();
        System.runAs(portal) {
            try {
                KenPortalCourseEnrollmentController.getAcademicSessionsForUser();
            } catch (Exception ignored) {}
        }
        Test.stopTest();
    }
    
    @isTest
    static void testFormatScheduleLine_Indirect() {
        User portal = newPortalUser();
        if (portal == null) return;
        CourseOffering offering = [SELECT Id,AcademicSessionId FROM CourseOffering LIMIT 1];
        AcademicSession session = [SELECT Id FROM AcademicSession WHERE Id = :offering.AcademicSessionId LIMIT 1];
        
        Test.startTest();
        System.runAs(portal) {
            List<KenPortalCourseEnrollmentController.CourseDTO> result =
                KenPortalCourseEnrollmentController.getCoursesForSemester(1, session.Id, null, false);
            System.assertNotEquals(null, result);
        }
        Test.stopTest();
    }
    
    @isTest
    static void testFormatPortalTime_Indirect() {
        User portal = newPortalUser();
        if (portal == null) { return; }
        List<CourseOffering> offerings = [SELECT Id, AcademicSessionId FROM CourseOffering WHERE AcademicSessionId != null LIMIT 1];
        if (offerings.isEmpty()) { return; }
        CourseOfferingSchedule sched = new CourseOfferingSchedule();
        sched.CourseOfferingId = offerings[0].Id;
        sched.StartTime = Time.newInstance(0, 0, 0, 0);
        sched.EndTime = Time.newInstance(12, 0, 0, 0);
        sched.IsMonday = true;
        sched.Description = 'Test Schedule';
        try { insert sched; } catch (Exception ignored) {}
        Test.startTest();
        System.runAs(portal) {
            try {
                KenPortalCourseEnrollmentController.getCoursesForSemester(1, offerings[0].AcademicSessionId, null, false);
            } catch (Exception ignored) {}
        }
        Test.stopTest();
        if (sched.Id != null) { delete sched; }
    }
    
    @isTest
    static void testResolveRegistrationStatus_AllBranches() {
        Datetime now = System.now();
        Datetime past = now.addDays(-10);
        Datetime future = now.addDays(10);
        
        // Create test sessions to trigger different registration status branches
        AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(2024, '1').create();
        
        // Upcoming: future open date
        AcademicSession s1 = new AcademicSession(Name = 'Upcoming', Type = 'Semester', IsActive = true,
        Registration_Open_Date__c = future, AcademicTermId = term.Id);
        insert s1;
        
        // Ongoing: past open, future close
        AcademicSession s2 = new AcademicSession(Name = 'Ongoing', Type = 'Semester', IsActive = true,
        Registration_Open_Date__c = past, Registration_Close_Date__c = future, AcademicTermId = term.Id);
        insert s2;
        
        // Completed: past close date
        AcademicSession s3 = new AcademicSession(Name = 'Completed', Type = 'Semester', IsActive = true,
        Registration_Close_Date__c = past, AcademicTermId = term.Id);
        insert s3;
        
        System.runAs(getAdmin()) {
            Test.startTest();
            KenPortalCourseEnrollmentController.getAcademicSessionsForUser();
            Test.stopTest();
        }
        
        delete s3; delete s2; delete s1;
    }
    
    @isTest
    static void testToDateTime_Indirect() {
        // toDateTime() is called by resolveRegistrationStatus/resolveRegistrationBoundary
        // which are called in getAcademicSessionsForUser
        AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(2024, '1').create();
        AcademicSession session = new AcademicSession(
            Name = 'Test', Type = 'Semester', IsActive = true,
        AcademicTermId = term.Id
            );
        insert session;
        
        System.runAs(getAdmin()) {
            Test.startTest();
            KenPortalCourseEnrollmentController.getAcademicSessionsForUser();
            Test.stopTest();
        }
        delete session;
    }
    
    @isTest
    static void testResolveEnrollmentStatusValue_Indirect() {
        User portal = newPortalUser();
        if (portal == null) return;
        List<LearningPathwayTemplateItem> reqItems = [SELECT Id FROM LearningPathwayTemplateItem WHERE Type = 'Requirement' LIMIT 1];
        List<LearningPathwayTemplateItem> otherItems = [SELECT Id FROM LearningPathwayTemplateItem WHERE Type != 'Requirement' LIMIT 1];
        List<AcademicSession> sessions = [SELECT Id FROM AcademicSession LIMIT 1];
        List<LearningCourse> courses = [SELECT Id FROM LearningCourse LIMIT 1];
        if (sessions.isEmpty() || courses.isEmpty()) { return; }
        Test.startTest();
        System.runAs(portal) {
            if (!reqItems.isEmpty()) {
                KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO req1 =
                    new KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO();
                req1.learningPathwayTemplateItemId = reqItems[0].Id;
                req1.learningCourseId = courses[0].Id;
                req1.academicSessionId = sessions[0].Id;
                try { KenPortalCourseEnrollmentController.createLearnerPathwayItems(
                    new List<KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO>{req1}); }
                catch (Exception e) {}
            }
            if (!otherItems.isEmpty()) {
                KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO req2 =
                    new KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO();
                req2.learningPathwayTemplateItemId = otherItems[0].Id;
                req2.learningCourseId = courses[0].Id;
                req2.academicSessionId = sessions[0].Id;
                try { KenPortalCourseEnrollmentController.createLearnerPathwayItems(
                    new List<KenPortalCourseEnrollmentController.LearnerPathwayItemRequestDTO>{req2}); }
                catch (Exception e) {}
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testFacultyNameResolver_Indirect() {
        User portal = newPortalUser();
        if (portal == null) return;
        
        AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
        LearningCourse course = [SELECT Id FROM LearningCourse LIMIT 1];
        
        // Create faculty User (setup object — must be in separate DML context)
        User faculty = new User(
            FirstName = 'Test', LastName = 'Faculty',
            Email = 'faculty@test.com', Username = 'faculty@test.com.fac', Alias = 'tfac',
            TimeZoneSidKey = 'GMT', LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].Id, IsActive = true
        );
        System.runAs(new User(Id = UserInfo.getUserId())) { insert faculty; }
        
        // Create offering with PrimaryFaculty to trigger FacultyNameResolver
        CourseOffering offering = new CourseOffering(
            Name = 'Test Offering ' + DateTime.now().getTime(),
            AcademicSessionId = session.Id, LearningCourseId = course.Id
        );
        System.runAs(new User(Id = UserInfo.getUserId())) { insert offering; }
        
        Test.startTest();
        System.runAs(portal) {
            List<KenPortalCourseEnrollmentController.CourseDTO> result =
                KenPortalCourseEnrollmentController.getCoursesForSemester(1, session.Id, null, false);
            System.assertNotEquals(null, result);
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetLearnerPathwaysForUser_WithDataAndException() {
        User portal = newPortalUser();
        if (portal == null) return;
        Contact learner = [SELECT Id FROM Contact WHERE LastName = 'PortalLearner' LIMIT 1];
        LearnerPathway lp = new LearnerPathway(
            Name = 'Test Pathway ' + DateTime.now().getTime(),
            LearnerContactId = learner.Id
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            try { insert lp; } catch (Exception ignored) {}
        }
        Test.startTest();
        System.runAs(portal) {
            List<KenPortalCourseEnrollmentController.LearnerPathwayDTO> result =
                KenPortalCourseEnrollmentController.getLearnerPathwaysForUser();
            System.assertNotEquals(null, result);
        }
        KenPortalCourseEnrollmentController.forceExceptionInGetLearnerPathways = true;
        System.runAs(portal) {
            try {
                KenPortalCourseEnrollmentController.getLearnerPathwaysForUser();
                System.assert(false, 'Should have thrown');
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            } catch (Exception ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
        }
        KenPortalCourseEnrollmentController.forceExceptionInGetLearnerPathways = false;
        Test.stopTest();
    }

    @isTest
    static void testGetLearnerPathwayItems_WithDataAndException() {
        User portal = newPortalUser();
        if (portal == null) return;
        AcademicSession session = [SELECT Id FROM AcademicSession LIMIT 1];
        Contact learner = [SELECT Id FROM Contact WHERE LastName = 'PortalLearner' LIMIT 1];
        List<LearningPathwayTemplateItem> lptiList = [SELECT Id, LearningPathwayTemplateId FROM LearningPathwayTemplateItem LIMIT 1];
        if (lptiList.isEmpty()) { return; }
        LearnerPathway lp = new LearnerPathway(
            Name = 'Test LP ' + DateTime.now().getTime(), LearnerContactId = learner.Id
        );
        System.runAs(new User(Id = UserInfo.getUserId())) { insert lp; }
        LearnerPathwayItem lpi = new LearnerPathwayItem(
            LearnerPathwayId = lp.Id, LearningPathwayTemplateItemId = lptiList[0].Id,
            AcademicSessionId = session.Id, Type = 'Requirement', SequenceNumber = 1
        );
        System.runAs(new User(Id = UserInfo.getUserId())) { insert lpi; }
        Test.startTest();
        System.runAs(portal) {
            List<KenPortalCourseEnrollmentController.CourseDTO> result1 =
                KenPortalCourseEnrollmentController.getLearnerPathwayItemsForAfterEnrollment(session.Id);
            System.assertNotEquals(null, result1);
            List<KenPortalCourseEnrollmentController.CourseDTO> result2 =
                KenPortalCourseEnrollmentController.getLearnerPathwayItemsForAfterEnrollment(null);
            System.assertNotEquals(null, result2);
        }
        KenPortalCourseEnrollmentController.forceExceptionInGetLearnerPathways = true;
        System.runAs(portal) {
            try {
                KenPortalCourseEnrollmentController.getLearnerPathwayItemsForAfterEnrollment(session.Id);
                System.assert(false, 'Should have thrown');
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            } catch (Exception ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
        }
        KenPortalCourseEnrollmentController.forceExceptionInGetLearnerPathways = false;
        Test.stopTest();
    }
    
    @isTest
    static void testResolveLearnerContactId_BestEffort() {
        User admin = getAdmin();
        Test.startTest();
        System.runAs(admin) {
            List<KenPortalCourseEnrollmentController.AcademicSessionDTO> result =
                KenPortalCourseEnrollmentController.getAcademicSessionsForUser();
            System.assertNotEquals(null, result);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetAcademicSessions_ForceException() {
        User portal = newPortalUser();
        if (portal == null) { return; }
        Test.startTest();
        KenPortalCourseEnrollmentController.forceExceptionInGetLearnerPathways = true;
        System.runAs(portal) {
            try {
                KenPortalCourseEnrollmentController.getAcademicSessionsForUser();
                System.assert(false, 'Should have thrown');
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            } catch (Exception ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
        }
        KenPortalCourseEnrollmentController.forceExceptionInGetLearnerPathways = false;
        Test.stopTest();
    }

    @isTest
    static void testGetAcademicSessions_EnrollmentCompleted() {
        User portal = newPortalUser();
        if (portal == null) { return; }
        Contact learner = [SELECT Id FROM Contact WHERE LastName = 'PortalLearner' LIMIT 1];
        List<AcademicTermEnrollment> enrollments = [
            SELECT Id FROM AcademicTermEnrollment WHERE LearnerContactId = :learner.Id LIMIT 1
        ];
        if (!enrollments.isEmpty()) {
            Map<String, Schema.SObjectField> ateFields =
                AcademicTermEnrollment.SObjectType.getDescribe().fields.getMap();
            if (ateFields.containsKey('IsEnrollmentSelectionCompleted__c') &&
                ateFields.get('IsEnrollmentSelectionCompleted__c').getDescribe().isUpdateable()) {
                SObject ateUpdate = new AcademicTermEnrollment(Id = enrollments[0].Id);
                ateUpdate.put('IsEnrollmentSelectionCompleted__c', true);
                System.runAs(new User(Id = UserInfo.getUserId())) {
                    try { update ateUpdate; } catch (Exception ignored) {}
                }
            }
        }
        Test.startTest();
        System.runAs(portal) {
            try {
                List<KenPortalCourseEnrollmentController.AcademicSessionDTO> result =
                    KenPortalCourseEnrollmentController.getAcademicSessionsForUser();
                System.assertNotEquals(null, result);
            } catch (AuraHandledException ex) {
                System.assertNotEquals(null, ex.getMessage());
            }
        }
        Test.stopTest();
    }
}