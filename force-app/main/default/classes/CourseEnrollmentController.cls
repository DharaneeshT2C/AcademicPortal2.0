/**
 * ************************************************************************************************
 * @className  CourseEnrollmentController
 *
 * @description
 *  Aura-enabled controller for learner course enrollment workflows.
 *
 *  Responsibilities:
 *  - Fetch learner-visible courses for a selected semester/session
 *  - Fetch learner academic sessions and calculated term labels
 *  - Submit enrollment requests for course offerings
 *  - Fetch available program pathways and enroll learner into a pathway
 *  - Build a 30-day student schedule view from offering schedules
 *
 * @author      Sureka A R K
 * @createdOn   Jan 20, 2026
 *
 * @history
 * ------------------------------------------------------------------------------------------------
 * Version   Date           Author          Description
 * 1.0       Jan 20, 2026   Sureka A R K     Initial version
 * ************************************************************************************************
 */
@suppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.NcssMethodCount')
public without sharing class CourseEnrollmentController {
    /**
     * @description
     *  DTO representing a pathway template and learner enrollment state.
     */
    public class ProgramPathDTO {
        @AuraEnabled public String name;
        @AuraEnabled public Id learningPathwayTemplateId;
        @AuraEnabled public String pathwayType;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean isEnrolled;
        @AuraEnabled public Id learnerPathwayId;
    }
    /**
     * @description
     *  Returns learner-eligible courses mapped to the requested semester and academic session.
     *
     * @param semesterNumber Calculated semester number to filter curriculum items.
     * @param academicSessionId AcademicSession Id used to resolve matching offerings.
     * @return List<CourseDTO> Course rows available to the current learner.
     */
    @AuraEnabled(cacheable=true)
    public static List<CourseDTO> getCoursesForSemester(Integer semesterNumber,Id academicSessionId) {
        try {
            List<CourseDTO> result = new List<CourseDTO>();
            if (semesterNumber == null) {
                return result;
            }
            User u = [
            SELECT Id, ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH USER_MODE
            LIMIT 1
        ];
            if (u.ContactId == null) {
                return result;
            }
            LearnerProgram lp = [
            SELECT Id, LearningProgramPlanId
            FROM LearnerProgram
            WHERE LearnerContactId = :u.ContactId
            WITH USER_MODE
            LIMIT 1
        ];
            LearningProgramPlan plan = [
            SELECT Id, Cadence_Type__c
            FROM LearningProgramPlan
            WHERE Id = :lp.LearningProgramPlanId
            WITH USER_MODE
            LIMIT 1
        ];
            String cadenceType = plan.Cadence_Type__c;
            List<LearningPathwayTmplPgmPlan> links = [
            SELECT LearningPathwayTemplateId
            FROM LearningPathwayTmplPgmPlan
            WHERE LearningProgramPlanId = :lp.LearningProgramPlanId
            WITH USER_MODE
        ];
            if (links.isEmpty()) {
                return result;
            }
            Set<Id> templateIds = new Set<Id>();
            for (LearningPathwayTmplPgmPlan l : links) {
                templateIds.add(l.LearningPathwayTemplateId);
            }
            List<LearningPathwayTemplateItem> items = [
            SELECT Id,
                Year,
                Season,
                SequenceNumber,
                Sequence__c,
                LearningProgramPlanRequirement.Learning_Course__c,
                LearningProgramPlanRequirement.Learning_Course__r.Name,
                LearningProgramPlanRequirement.Learning_Course__r.Duration,
                LearningProgramPlanRequirement.Learning_Course__r.Learning.ImageUrl,
                LearningProgramPlanRequirement.Learning_Course__r.CourseNumber,
                        LearningPathwayTemplateId,
            LearningPathwayTemplate.Name,
            LearningPathwayTemplate.Pathway_Type__c,
                    Type
            FROM LearningPathwayTemplateItem
            WHERE LearningPathwayTemplateId IN :templateIds
            WITH USER_MODE
        ];
            Map<Id, LearningPathwayTemplateItem> validItems =
                new Map<Id, LearningPathwayTemplateItem>();
            for (LearningPathwayTemplateItem item : items) {
                Integer yearVal;
                if (item.Year != null) {
                    yearVal = Integer.valueOf(
                        item.Year.replace(KenConstantController.CADENCE_YEAR_LABEL_PREFIX, '').trim()
                        );
                }
                Integer sequenceVal =
                    item.Sequence__c != null
                    ? Integer.valueOf(item.Sequence__c)
                    : null;
                Integer calculatedSemester =
                    calculateSemester(cadenceType, yearVal, sequenceVal);
                if (calculatedSemester == semesterNumber) {
                    validItems.put(
                        item.LearningProgramPlanRequirement.Learning_Course__c,
                    item
                        );
                }
            }
            if (validItems.isEmpty()) {
                return result;
            }
            List<AcademicSession> sessions = [
            SELECT Id, Name, Season, Type, IsActive
            FROM AcademicSession
            WHERE Id = :academicSessionId
            AND IsActive = true
            WITH USER_MODE
        ];
            if (sessions.isEmpty()) {
                return result;
            }
            AcademicSession session = sessions[0];
            List<CourseOffering> offerings = [
            SELECT Id, LearningCourseId
            FROM CourseOffering
            WHERE AcademicSessionId = :session.Id
            AND LearningCourseId IN :validItems.keySet()
            WITH USER_MODE
        ];
            Map<Id, CourseOffering> offeringByCourse =
                new Map<Id, CourseOffering>();
            for (CourseOffering co : offerings) {
                offeringByCourse.put(co.LearningCourseId, co);
            }
            for (Id courseId : validItems.keySet()) {
                if (!offeringByCourse.containsKey(courseId)) {
                    continue;
                }
                LearningPathwayTemplateItem item = validItems.get(courseId);
                CourseOffering offering = offeringByCourse.get(courseId);
                CourseDTO dto = new CourseDTO();
                dto.learningCourseId = courseId;
                dto.courseName =
                    item.LearningProgramPlanRequirement.Learning_Course__r.Name;
                dto.credits =
                    Integer.valueOf(
                    item.LearningProgramPlanRequirement
                    .Learning_Course__r
                    .Duration
                    );
                dto.learningProgramPlanRequirementId = item.LearningProgramPlanRequirementId;
                dto.year = Integer.valueOf(
                    item.Year.replace(KenConstantController.CADENCE_YEAR_LABEL_PREFIX, '').trim()
                    );
                dto.season = item.Season;
                dto.sequence = Integer.valueOf(item.Sequence__c);
                dto.academicSessionId = session.Id;
                dto.courseOfferingId = offering.Id;
                dto.imageUrl = item.LearningProgramPlanRequirement.Learning_Course__r.Learning.ImageUrl;
                dto.courseType = item.Type;
                dto.courseCode = item.LearningProgramPlanRequirement.Learning_Course__r.CourseNumber;
                dto.learningPathwayTemplateName =item.LearningPathwayTemplate.Name;
                dto.learningPathwayTemplateId = item.LearningPathwayTemplateId;
                dto.templateType = item.LearningPathwayTemplate.Pathway_Type__c;
                result.add(dto);
            }
            return result;
        } catch (Exception e) {
            KenAuditLogHelper.auditLogRecord(
                'Course Enrollment',
            'CourseEnrollmentController.getCoursesForSemester'
                )
                .setErrorMessage(e == null ? 'Unknown error' : e.getMessage())
                .setStackTrace(e == null ? null : e.getStackTraceString())
                .create();
            throw new AuraHandledException('Failed to get courses for semester: ' + e.getMessage());
        }
    }
    /**
     * @description
     *  Converts cadence/year/sequence values into an absolute semester index.
     *
     * @param cadence Cadence type (Semester/Trimester/Quarter).
     * @param year Curriculum year number.
     * @param sequence Sequence number within the year.
     * @return Integer Absolute semester number, or null when inputs are invalid.
     */
    private static Integer calculateSemester(
        String cadence,
    Integer year,
    Integer sequence
    ) {
        if (year == null || sequence == null) {return null;}
        if (cadence == KenConstantController.CADENCE_SEMESTER) {
            return (year - 1) * 2 + sequence;
        }
        if (cadence == KenConstantController.CADENCE_TRIMESTER) {
            return (year - 1) * 3 + sequence;
        }
        if (cadence == KenConstantController.CADENCE_QUARTER) {
            return (year - 1) * 4 + sequence;
        }
        return null;
    }
    /**
     * @description
     *  Returns active academic sessions for the current learner with a display label.
     *
     * @return List<AcademicSessionDTO> Ordered learner session rows.
     */
    @AuraEnabled(cacheable=true)
    public static List<AcademicSessionDTO> getAcademicSessionsForUser() {
        try {
            User u = [
        SELECT ContactId
        FROM User
        WHERE Id = :UserInfo.getUserId()
        WITH USER_MODE
        LIMIT 1
    ];
            if (u.ContactId == null) {
                return new List<AcademicSessionDTO>();
            }
            LearnerProgram lp = [
        SELECT LearningProgramPlanId
        FROM LearnerProgram
        WHERE LearnerContactId = :u.ContactId 
        WITH USER_MODE
        LIMIT 1
    ];
            LearningProgramPlan plan = [
        SELECT Cadence_Type__c
        FROM LearningProgramPlan
        WHERE Id = :lp.LearningProgramPlanId 
        WITH USER_MODE
        LIMIT 1
    ];
            String cadenceType = plan.Cadence_Type__c;
            List<AcademicTermEnrollment> enrollments = [
        SELECT AcademicTermId
        FROM AcademicTermEnrollment
        WHERE LearnerContactId = :u.ContactId 
        WITH USER_MODE
    ];
            if (enrollments.isEmpty()) {
                return new List<AcademicSessionDTO>();
            }
            Set<Id> academicTermIds = new Set<Id>();
            for (AcademicTermEnrollment e : enrollments) {
                academicTermIds.add(e.AcademicTermId);
            }
            List<AcademicSession> sessions = [
        SELECT Id,
                Name,
                Season,
                Type,
                ClassStartDate,
                AcademicTerm.Name,Sequence__c
        FROM AcademicSession
        WHERE AcademicTermId IN :academicTermIds
        AND Type = :cadenceType
        AND IsActive = true 
        WITH USER_MODE
        ORDER BY ClassStartDate ASC
    ];
            List<AcademicSessionDTO> result = new List<AcademicSessionDTO>();
            Integer counter = 1;
            for (AcademicSession s : sessions) {
                AcademicSessionDTO dto = new AcademicSessionDTO();
                dto.academicSessionId = s.Id;
                dto.academicSessionName = s.Name;
                dto.academicTermName = s.AcademicTerm.Name;
                dto.season = s.Season;
                dto.sequence = Integer.valueOf(s.Sequence__c);
                dto.cadenceType = cadenceType;
                dto.termNumber = counter;
                dto.termLabel =
                    cadenceType + ' ' + counter + ' - ' + s.AcademicTerm.Name;
                result.add(dto);
                counter++;
            }
            return result;
        } catch (Exception e) {
            KenAuditLogHelper.auditLogRecord(
                'Course Enrollment',
            'CourseEnrollmentController.getAcademicSessionsForUser'
                )
                .setErrorMessage(e == null ? 'Unknown error' : e.getMessage())
                .setStackTrace(e == null ? null : e.getStackTraceString())
                .create();
            throw new AuraHandledException('Failed to get academic sessions: ' + e.getMessage());
        }
    }
    /**
     * @description
     *  Creates course-offering participant records and learner-program requirements
     *  for the current learner based on selected offering and requirement ids.
     *
     * @param courseOfferingIds Selected CourseOffering record ids.
     * @param planRequirementIds Selected LearningProgramPlanRequirement ids.
     * @throws AuraHandledException When no offerings are selected or current user has no contact.
     */
    @AuraEnabled
    public static void submitEnrollmentRequest(
        List<Id> courseOfferingIds,
    List<Id> planRequirementIds
    ) {
        try {
            if (courseOfferingIds == null || courseOfferingIds.isEmpty()) {
                throw new AuraHandledException('No Course Offerings selected');
            }
            User u = [
        SELECT ContactId
        FROM User
        WHERE Id = :UserInfo.getUserId()
        WITH USER_MODE
        LIMIT 1
    ];
            if (u.ContactId == null) {
                throw new AuraHandledException('User has no contact');
            }
            ConstituentRole role = [
            SELECT Id, RoleType
            FROM ConstituentRole
            WHERE PersonId = :u.ContactId
            AND RoleType = :KenConstantController.ROLETYPE_STUDENT
            AND Status = :KenConstantController.STATUS_ENROLLED
            WITH USER_MODE
            LIMIT 1
        ];
            LearnerProgram lp = [
        SELECT Id, LearnerAccountId,Name
        FROM LearnerProgram
        WHERE LearnerContactId = :u.ContactId 
        WITH USER_MODE
        LIMIT 1
    ];
            Map<Id, CourseOffering> offeringMap = new Map<Id, CourseOffering>(
                [SELECT Id,AcademicSessionId,
            AcademicSession.AcademicTermId
    FROM CourseOffering WHERE Id IN :courseOfferingIds
    WITH USER_MODE]
                );
            Set<Id> academicTermIds = new Set<Id>();
            for (CourseOffering co : offeringMap.values()) {
                if (co.AcademicSession.AcademicTermId != null) {
                    academicTermIds.add(co.AcademicSession.AcademicTermId);
                }
            }
            Map<Id, AcademicTermEnrollment> ateByTermId = new Map<Id, AcademicTermEnrollment>();
            for (AcademicTermEnrollment ate : [
        SELECT Id, AcademicTermId
        FROM AcademicTermEnrollment
        WHERE LearnerContactId = :u.ContactId
        AND AcademicTermId IN :academicTermIds
        WITH USER_MODE
    ]) {
                ateByTermId.put(ate.AcademicTermId, ate);
            }
            List<CourseOfferingParticipant> participants = new List<CourseOfferingParticipant>();
            for (Id coId : courseOfferingIds) {
                CourseOffering co = offeringMap.get(coId);
                if (co == null) {
                    continue;
                }
                Id termId = co.AcademicSession.AcademicTermId;
                AcademicTermEnrollment ate = ateByTermId.get(termId);
                if (ate == null) {
                    continue;
                }
                participants.add(new CourseOfferingParticipant(
                    ParticipantAffiliation = role.RoleType,
                ParticipantContactId = u.ContactId,
                ParticipantAccountId = lp.LearnerAccountId,
                CourseOfferingId = coId,
                AcademicTermEnrollmentId = ate.Id,
                ParticipationStatus = KenConstantController.STATUS_ENROLLED
                    ));
            }
            insert as user participants;
            if (planRequirementIds != null && !planRequirementIds.isEmpty()) {
                List<LearnerProgramRequirement> requirements = new List<LearnerProgramRequirement>();
                for (Id rqmtId : planRequirementIds) {
                    requirements.add(new LearnerProgramRequirement(
                        LearningProgramPlanRqmtId = rqmtId,
                    LearnerProgramId = lp.Id,
                    Status = KenConstantController.ENROLLMENT_STATUS_ACTIVE,
                    Name =lp.Name
                        ));
                }
                insert as user requirements;
            }
        } catch (Exception e) {
            KenAuditLogHelper.auditLogRecord(
                'Course Enrollment',
            'CourseEnrollmentController.submitEnrollmentRequest'
                )
                .setErrorMessage(e == null ? 'Unknown error' : e.getMessage())
                .setStackTrace(e == null ? null : e.getStackTraceString())
                .create();
            if (e instanceof AuraHandledException) {
                throw (AuraHandledException) e;
            }
            throw new AuraHandledException('Failed to submit enrollment request: ' + e.getMessage());
        }
    }
    /**
     * @description
     *  Returns non-default pathway templates linked to the learner's program plan,
     *  including whether the learner is already enrolled in each pathway.
     *
     * @return List<ProgramPathDTO> Pathway list with enrollment state.
     */
    @AuraEnabled(cacheable=true)
    public static List<ProgramPathDTO> getProgramPath() {
        try {
            User u = [
        SELECT ContactId
        FROM User
        WHERE Id = :UserInfo.getUserId()
        WITH USER_MODE
        LIMIT 1
    ];
            if (u.ContactId == null) {return new List<ProgramPathDTO>();}
            LearnerProgram lp = [
        SELECT LearningProgramPlanId
        FROM LearnerProgram
        WHERE LearnerContactId = :u.ContactId
        WITH USER_MODE
        LIMIT 1
    ];
            // Templates linked to program plan
            List<LearningPathwayTmplPgmPlan> links = [
        SELECT LearningPathwayTemplateId
        FROM LearningPathwayTmplPgmPlan
        WHERE LearningProgramPlanId = :lp.LearningProgramPlanId
        AND LearningPathwayTemplate.Default__c = false
        WITH USER_MODE
    ];
            Set<Id> templateIds = new Set<Id>();
            for (LearningPathwayTmplPgmPlan l : links) {
                templateIds.add(l.LearningPathwayTemplateId);
            }
            // Fetch templates
            List<LearningPathwayTemplate> templates = [
        SELECT Id, Name, Pathway_Type__c, Status
        FROM LearningPathwayTemplate
        WHERE Id IN :templateIds
        WITH USER_MODE
    ];
            // Fetch learner pathways for THIS contact
            Map<String, LearnerPathway> learnerPathwayByName = new Map<String, LearnerPathway>();
            for (LearnerPathway lpw : [
        SELECT Id, Name, Status
        FROM LearnerPathway
        WHERE LearnerContactId = :u.ContactId
        WITH USER_MODE
    ]) {
                learnerPathwayByName.put(lpw.Name, lpw);
            }
            // Build DTO
            List<ProgramPathDTO> result = new List<ProgramPathDTO>();
            for (LearningPathwayTemplate tpl : templates) {
                ProgramPathDTO dto = new ProgramPathDTO();
                dto.learningPathwayTemplateId = tpl.Id;
                dto.name = tpl.Name;
                dto.pathwayType = tpl.Pathway_Type__c;
                dto.status = tpl.Status;
                if (learnerPathwayByName.containsKey(tpl.Name)) {
                    dto.isEnrolled = true;
                    dto.learnerPathwayId = learnerPathwayByName.get(tpl.Name).Id;
                } else {
                    dto.isEnrolled = false;
                }
                result.add(dto);
            }
            return result;
        } catch (Exception e) {
            KenAuditLogHelper.auditLogRecord(
                'Course Enrollment',
            'CourseEnrollmentController.getProgramPath'
                )
                .setErrorMessage(e == null ? 'Unknown error' : e.getMessage())
                .setStackTrace(e == null ? null : e.getStackTraceString())
                .create();
            throw new AuraHandledException('Failed to get program path: ' + e.getMessage());
        }
    }
    /**
     * @description
     *  Enrolls the current learner into the selected learning pathway template.
     *  If an enrollment already exists for the same template name, returns the existing id.
     *
     * @param learningPathwayTemplateId LearningPathwayTemplate Id to enroll into.
     * @return Id LearnerPathway Id (existing or newly created).
     * @throws AuraHandledException When current user has no contact.
     */
    @AuraEnabled
    public static Id enrollInPathway(Id learningPathwayTemplateId) {
        try {
            User u = [
        SELECT ContactId
        FROM User
        WHERE Id = :UserInfo.getUserId()
        WITH USER_MODE
        LIMIT 1
    ];
            if (u.ContactId == null) {
                throw new AuraHandledException('User has no contact');
            }
            LearningPathwayTemplate tpl = [
        SELECT Id, Name
        FROM LearningPathwayTemplate
        WHERE Id = :learningPathwayTemplateId 
        WITH USER_MODE
        LIMIT 1
    ];
            // Check existing by Contact + Name
            List<LearnerPathway> existing = [
        SELECT Id
        FROM LearnerPathway
        WHERE LearnerContactId = :u.ContactId
        AND Name = :tpl.Name
        WITH USER_MODE
        LIMIT 1
    ];
            if (!existing.isEmpty()) {
                return existing[0].Id;
            }
            LearnerPathway lp = new LearnerPathway();
            lp.Name = tpl.Name;
            lp.LearnerContactId = u.ContactId;
            lp.Status = KenConstantController.STATUS_ENROLLED;
            if(Schema.SObjectType.LearnerPathway.isCreateable() && Schema.SObjectType.LearnerPathway.isAccessible()){
                insert as user lp;
            }
            return lp.Id;
        } catch (Exception e) {
            KenAuditLogHelper.auditLogRecord(
                'Course Enrollment',
            'CourseEnrollmentController.enrollInPathway'
                )
                .setErrorMessage(e == null ? 'Unknown error' : e.getMessage())
                .setStackTrace(e == null ? null : e.getStackTraceString())
                .create();
            if (e instanceof AuraHandledException) {
                throw (AuraHandledException) e;
            }
            throw new AuraHandledException('Failed to enroll in pathway: ' + e.getMessage());
        }
    }
    /**
     * @description
     *  DTO representing an academic session row for learner-facing selection.
     */
    public class AcademicSessionDTO {
        @AuraEnabled public Id academicSessionId;
        @AuraEnabled public String academicSessionName;
        @AuraEnabled public String academicTermName;
        @AuraEnabled public String season;
        @AuraEnabled public String cadenceType;
        @AuraEnabled public Integer termNumber;
        @AuraEnabled public String termLabel;
        @AuraEnabled public Integer sequence;
    }
    /**
     * @description
     *  DTO representing a learner course card/row in the enrollment UI.
     */
    public class CourseDTO {
        @AuraEnabled public Id learningCourseId;
        @AuraEnabled public String courseName;
        @AuraEnabled public Integer credits;
        @AuraEnabled public Integer year;
        @AuraEnabled public Integer sequence;
        @AuraEnabled public String season;
        @AuraEnabled public Id academicSessionId;
        @AuraEnabled public Id learningProgramPlanRequirementId;
        @AuraEnabled public Id courseOfferingId;
        @AuraEnabled public String imageUrl;
        @AuraEnabled public String courseType;
        @AuraEnabled public String courseCode;
        @AuraEnabled public String learningPathwayTemplateName;
        @AuraEnabled public Id learningPathwayTemplateId;
        @AuraEnabled public String templateType;
    }
    /**
     * @description
     *  DTO carrying selected course offering and related plan requirement ids.
     */
    public class SelectedCourseDTO {
        @AuraEnabled public Id courseOfferingId;
        @AuraEnabled public Id learningProgramPlanRequirementId;
    }
    /**
     * @description
     *  DTO representing a client enrollment request item.
     */
    public class EnrollmentRequestDTO {
        @AuraEnabled public Id courseOfferingId;
        @AuraEnabled public Id planRequirementId;
        @AuraEnabled public Id learningPathwayTemplateId;
        @AuraEnabled public Integer sequence;
    }
    /**
     * @description
     *  DTO representing one schedule entry for display in the student schedule view.
     */
    public class ScheduleDTO {
        @AuraEnabled public String dateKey;      // YYYY-MM-DD
        @AuraEnabled public String courseName;
        @AuraEnabled public String facultyName;
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
    }
    /**
     * @description
     *  Comparator used to sort schedule rows by date and then start time.
     */
    public class ScheduleSorter implements Comparator<ScheduleDTO> {
        /**
         * @description
         *  Compares two schedule rows by `dateKey` then `startTime`.
         *
         * @param a First schedule row.
         * @param b Second schedule row.
         * @return Integer Negative/zero/positive compare result.
         */
        public Integer compare(ScheduleDTO a, ScheduleDTO b) {
            if (a.dateKey == b.dateKey) {
                return a.startTime.compareTo(b.startTime);
            }
            return a.dateKey.compareTo(b.dateKey);
        }
    }
    /**
     * @description
     *  Returns a 30-day schedule for the current learner from enrolled offerings.
     *
     * @return List<ScheduleDTO> Date-sorted schedule rows.
     */
    @AuraEnabled(cacheable=true)
    public static List<ScheduleDTO> getStudentSchedule() {
        try {
            User u = [
        SELECT ContactId
        FROM User 
        WHERE Id = :UserInfo.getUserId()
        WITH USER_MODE
        LIMIT 1 
    ];
            if (u.ContactId == null) {return new List<ScheduleDTO>();}
            List<CourseOfferingParticipant> cops = [
        SELECT CourseOfferingId
        FROM CourseOfferingParticipant
        WHERE ParticipantContactId = :u.ContactId
        AND ParticipationStatus = :KenConstantController.STATUS_ENROLLED
        WITH USER_MODE
    ];
            if (cops.isEmpty()){ return new List<ScheduleDTO>();}
            Set<Id> offeringIds = new Set<Id>();
            for (CourseOfferingParticipant cop : cops) {
                offeringIds.add(cop.CourseOfferingId);
            }
            Map<Id, CourseOffering> offeringMap =
                new Map<Id, CourseOffering>([
                SELECT Id, Name, PrimaryFaculty.Name
                FROM CourseOffering
                WHERE Id IN :offeringIds
                WITH USER_MODE
            ]);
            List<CourseOfferingSchedule> schedules = [
        SELECT CourseOfferingId,
               StartTime,
               EndTime,
               IsMonday,
               IsTuesday,
               IsWednesday,
               IsThursday,
               IsFriday,
               IsSaturday,
               IsSunday
        FROM CourseOfferingSchedule
        WHERE CourseOfferingId IN :offeringIds
        WITH USER_MODE
    ];
            List<ScheduleDTO> result = new List<ScheduleDTO>();
            Date today = Date.today();
            for (CourseOfferingSchedule sch : schedules) {
                CourseOffering off = offeringMap.get(sch.CourseOfferingId);
                if (off == null) {
                    continue;
                }
                for (Integer i = 0; i < 30; i++) {
                    Date d = today.addDays(i);
                    Datetime dt =
                        Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
                    Integer weekday =
                        Integer.valueOf(dt.format('u')); // 1=Mon … 7=Sun
                    Boolean match =
                        (weekday == 1 && sch.IsMonday) ||
                        (weekday == 2 && sch.IsTuesday) ||
                        (weekday == 3 && sch.IsWednesday) ||
                        (weekday == 4 && sch.IsThursday) ||
                        (weekday == 5 && sch.IsFriday) ||
                        (weekday == 6 && sch.IsSaturday) ||
                        (weekday == 7 && sch.IsSunday);
                    if (!match) {
                        continue;
                    }
                    ScheduleDTO dto = new ScheduleDTO();
                    dto.dateKey = String.valueOf(d);
                    dto.courseName = off.Name;
                    dto.facultyName =
                        off.PrimaryFaculty != null
                        ? off.PrimaryFaculty.Name
                        : '';
                    dto.startTime = formatTime(sch.StartTime);
                    dto.endTime = formatTime(sch.EndTime);
                    result.add(dto);
                }
            }
            result.sort(new ScheduleSorter());
            return result;
        } catch (Exception e) {
            KenAuditLogHelper.auditLogRecord(
                'Course Enrollment',
            'CourseEnrollmentController.getStudentSchedule'
                )
                .setErrorMessage(e == null ? 'Unknown error' : e.getMessage())
                .setStackTrace(e == null ? null : e.getStackTraceString())
                .create();
            throw new AuraHandledException('Failed to get student schedule: ' + e.getMessage());
        }
    }
    /**
     * @description
     *  Formats a `Time` value into 12-hour format (for example, `9:30 AM`).
     *
     * @param t Time value.
     * @return String Formatted time string, or empty string when input is null.
     */
    private static String formatTime(Time t) {
        if (t == null) {
            return '';
        }
        Integer h = t.hour();
        Integer m = t.minute();
        String ap = h >= 12 ? KenConstantController.TIME_PERIOD_PM : KenConstantController.TIME_PERIOD_AM;
        h = Math.mod(h, 12);
        if (h == 0) {
            h = 12;
        }
        return h + ':' + (m < 10 ? '0' : '') + m + ' ' + ap;
    }
    
}