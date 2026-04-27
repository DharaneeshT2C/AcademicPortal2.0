/**
 * ************************************************************************************************
 * @className  KenCourseEnrollmentController
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
public without sharing class KenCourseEnrollmentController {
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
    public static List<CourseDTO> getCoursesForSemester(
        Integer semesterNumber,
    Id academicSessionId,
    Id learningPathwayTemplateId
    ) {
        try {
            List<CourseDTO> result = new List<CourseDTO>();
            if (semesterNumber == null) {
                return result;
            }
            User u = [
            SELECT Id, ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
            if (u.ContactId == null) {
                return result;
            }
            LearnerProgram lp = [
            SELECT Id, LearningProgramPlanId
            FROM LearnerProgram
            WHERE LearnerContactId = :u.ContactId
            LIMIT 1
        ];
            LearningProgramPlan plan = [
            SELECT Id, Cadence_Type__c
            FROM LearningProgramPlan
            WHERE Id = :lp.LearningProgramPlanId
            LIMIT 1
        ];
            String cadenceType = plan.Cadence_Type__c;
            List<LearningPathwayTmplPgmPlan> links = [
            SELECT LearningPathwayTemplateId
            FROM LearningPathwayTmplPgmPlan
            WHERE LearningProgramPlanId = :lp.LearningProgramPlanId
        ];
            if (links.isEmpty()) {
                return result;
            }
            Set<Id> templateIds = new Set<Id>();
            for (LearningPathwayTmplPgmPlan l : links) {
                if (learningPathwayTemplateId != null &&
                l.LearningPathwayTemplateId != learningPathwayTemplateId) {
                    continue;
                }
                templateIds.add(l.LearningPathwayTemplateId);
            }
            if (templateIds.isEmpty()) {
                return result;
            }
            List<LearningPathwayTemplateItem> items = [
            SELECT Id,
                Year,
                Season,
                SequenceNumber,
                Sequence__c,
                LearningProgramPlanRequirementId,
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
        ];
            Map<Id, LearningPathwayTemplateItem> validItems =
                new Map<Id, LearningPathwayTemplateItem>();
            for (LearningPathwayTemplateItem item : items) {
                if (item == null ||
                    item.LearningProgramPlanRequirement == null ||
                item.LearningProgramPlanRequirement.Learning_Course__c == null) {
                    continue;
                }
                Integer yearVal = resolveTemplateItemYear(item.Year);
                Integer sequenceVal = resolveTemplateItemSequence(item);
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
            Map<Id, CourseOffering> offeringByCourse =
                new Map<Id, CourseOffering>();
            if (academicSessionId != null) {
                List<CourseOffering> offerings = [
                SELECT Id, LearningCourseId
                FROM CourseOffering
                WHERE AcademicSessionId = :academicSessionId
                AND LearningCourseId IN :validItems.keySet()
            ];
                for (CourseOffering co : offerings) {
                    offeringByCourse.put(co.LearningCourseId, co);
                }
            }
            for (Id courseId : validItems.keySet()) {
                LearningPathwayTemplateItem item = validItems.get(courseId);
                CourseOffering offering = offeringByCourse.get(courseId);
                CourseDTO dto = new CourseDTO();
                dto.learningCourseId = courseId;
                dto.courseName =
                    item.LearningProgramPlanRequirement.Learning_Course__r.Name;
                dto.credits = tryParseInteger(
                    item.LearningProgramPlanRequirement
                    .Learning_Course__r
                    .Duration
                    );
                if (dto.credits == null) {
                    dto.credits = 0;
                }
                dto.learningProgramPlanRequirementId = item.LearningProgramPlanRequirementId;
                dto.year = resolveTemplateItemYear(item.Year);
                dto.season = item.Season;
                dto.sequence = resolveTemplateItemSequence(item);
                dto.academicSessionId = academicSessionId;
                dto.courseOfferingId = offering == null ? null : offering.Id;
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
    @TestVisible
    private static Integer calculateSemester(
        String cadence,
    Integer year,
    Integer sequence
    ) {
        if (year == null || sequence == null) {
            return null;
        }
        Integer periodsPerYear = resolveCadencePeriods(cadence);
        if (periodsPerYear == null || periodsPerYear <= 0) {
            return null;
        }
        // Generic business rule across cadences:
        // absolutePeriod = ((year - 1) * periodsPerYear) + sequence
        return ((year - 1) * periodsPerYear) + sequence;
    }
    
    @TestVisible
    private static Integer resolveCadencePeriods(String cadence) {
        if (String.isBlank(cadence)) {
            return 2;
        }
        String normalized = cadence.trim().toLowerCase();
        if (normalized == 'semester') {
            return 2;
        }
        if (normalized == 'trimester') {
            return 3;
        }
        if (normalized == 'quarter') {
            return 4;
        }
        if (normalized == 'year' || normalized == 'yearly') {
            return 1;
        }
        return 2;
    }
    
    @TestVisible
    private static Integer resolveTemplateItemYear(String yearValue) {
        if (String.isBlank(yearValue)) {
            return null;
        }
        String normalized = yearValue.replace(KenConstantController.CADENCE_YEAR_LABEL_PREFIX, '').trim();
        Integer parsed = tryParseInteger(normalized);
        if (parsed != null) {
            return parsed;
        }
        Matcher matcher = Pattern.compile('(\\d+)').matcher(yearValue);
        if (matcher.find()) {
            return tryParseInteger(matcher.group(1));
        }
        return null;
    }
    
    @TestVisible
    private static Integer resolveTemplateItemSequence(LearningPathwayTemplateItem item) {
        if (item == null) {
            return null;
        }
        Integer fromCustom = tryParseInteger(item.Sequence__c);
        if (fromCustom != null) {
            return fromCustom;
        }
        return tryParseInteger(item.SequenceNumber);
    }
    
    @TestVisible
    private static Integer tryParseInteger(Object value) {
        if (value == null) {
            return null;
        }
        try {
            return Integer.valueOf(String.valueOf(value).trim());
        } catch (Exception ignored) {
            return null;
        }
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
        LIMIT 1
    ];
            if (u.ContactId == null) {
                return new List<AcademicSessionDTO>();
            }
            LearnerProgram lp = [
        SELECT LearningProgramPlanId
        FROM LearnerProgram
        WHERE LearnerContactId = :u.ContactId 
        LIMIT 1
    ];
            LearningProgramPlan plan = [
        SELECT Cadence_Type__c
        FROM LearningProgramPlan
        WHERE Id = :lp.LearningProgramPlanId 
        LIMIT 1
    ];
            String cadenceType = plan.Cadence_Type__c;
            List<AcademicTermEnrollment> enrollments = [
        SELECT AcademicTermId
        FROM AcademicTermEnrollment
        WHERE LearnerContactId = :u.ContactId 
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

            LIMIT 1
        ];
            LearnerProgram lp = [
        SELECT Id, LearnerAccountId,Name
        FROM LearnerProgram
        WHERE LearnerContactId = :u.ContactId 
        LIMIT 1
    ];
            Map<Id, CourseOffering> offeringMap = new Map<Id, CourseOffering>(
                [SELECT Id,AcademicSessionId,
            AcademicSession.AcademicTermId
    FROM CourseOffering WHERE Id IN :courseOfferingIds
    ]
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
        LIMIT 1
    ];
            if (u.ContactId == null) {return new List<ProgramPathDTO>();}
            LearnerProgram lp = [
        SELECT LearningProgramPlanId
        FROM LearnerProgram
        WHERE LearnerContactId = :u.ContactId
        LIMIT 1
    ];
            // Templates linked to program plan
            List<LearningPathwayTmplPgmPlan> links = [
        SELECT LearningPathwayTemplateId
        FROM LearningPathwayTmplPgmPlan
        WHERE LearningProgramPlanId = :lp.LearningProgramPlanId
        AND LearningPathwayTemplate.Default__c = false
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
    ];
            // Fetch learner pathways for THIS contact
            Map<String, LearnerPathway> learnerPathwayByName = new Map<String, LearnerPathway>();
            for (LearnerPathway lpw : [
        SELECT Id, Name, Status
        FROM LearnerPathway
        WHERE LearnerContactId = :u.ContactId
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
        SELECT ContactId, Contact.Name
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
    ];
            if (u.ContactId == null) {
                throw new AuraHandledException('User has no contact');
            }
            LearningPathwayTemplate tpl = [
        SELECT Id, Name
        FROM LearningPathwayTemplate
        WHERE Id = :learningPathwayTemplateId
        LIMIT 1
    ];
            // Check existing by Contact + Template lookup
            Map<String, Schema.SObjectField> lpFields = LearnerPathway.SObjectType.getDescribe().fields.getMap();
            String templateLookupField = lpFields.containsKey('Learning_Pathway_Template__c') ? 'Learning_Pathway_Template__c' : null;
            
            List<LearnerPathway> existing;
            if (String.isNotBlank(templateLookupField)) {
                existing = [
                    SELECT Id FROM LearnerPathway
                    WHERE LearnerContactId = :u.ContactId
                    AND Learning_Pathway_Template__c = :tpl.Id
                    LIMIT 1
                ];
            } else {
                existing = [
                    SELECT Id FROM LearnerPathway
                    WHERE LearnerContactId = :u.ContactId
                    AND Name = :tpl.Name
                    LIMIT 1
                ];
            }
            if (!existing.isEmpty()) {
                return existing[0].Id;
            }
            String contactName = (u.Contact != null && String.isNotBlank(u.Contact.Name)) ? u.Contact.Name : '';
            String pathwayName = (String.isBlank(contactName) ? '' : contactName + ' ') + tpl.Name;
            
            LearnerPathway lp = new LearnerPathway();
            lp.Name = pathwayName;
            lp.LearnerContactId = u.ContactId;
            lp.Status = KenConstantController.STATUS_ENROLLED;
            if (String.isNotBlank(templateLookupField)) {
                lp.put('Learning_Pathway_Template__c', tpl.Id);
            }
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
    public class StudentCalendarEventDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public String footer;
        @AuraEnabled public String startDateTime;
        @AuraEnabled public String endDateTime;
        @AuraEnabled public String location;
        @AuraEnabled public String variant;
        @AuraEnabled public String hexColor;
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
        LIMIT 1 
    ];
            if (u.ContactId == null) {return new List<ScheduleDTO>();}
            List<CourseOfferingParticipant> cops = [
        SELECT CourseOfferingId
        FROM CourseOfferingParticipant
        WHERE ParticipantContactId = :u.ContactId
        AND ParticipationStatus = :KenConstantController.STATUS_ENROLLED
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
    
    @AuraEnabled(cacheable=true)
    public static List<StudentCalendarEventDTO> getStudentCalendarEvents(String referenceDateIso, String viewMode) {
        try {
            User u = [
                SELECT ContactId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            if (u.ContactId == null) {
                return new List<StudentCalendarEventDTO>();
            }
            
            List<CourseOfferingParticipant> participants = [
                SELECT CourseOfferingId
                FROM CourseOfferingParticipant
                WHERE ParticipantContactId = :u.ContactId
                AND ParticipationStatus = :KenConstantController.STATUS_ENROLLED
            ];
            if (participants.isEmpty()) {
                return new List<StudentCalendarEventDTO>();
            }
            
            Set<Id> offeringIds = new Set<Id>();
            for (CourseOfferingParticipant participant : participants) {
                if (participant.CourseOfferingId != null) {
                    offeringIds.add(participant.CourseOfferingId);
                }
            }
            if (offeringIds.isEmpty()) {
                return new List<StudentCalendarEventDTO>();
            }
            
            Map<Id, CourseOffering> offeringMap = new Map<Id, CourseOffering>([
                SELECT Id,
                    Name,
                    Course_Type__c,
                    Credit__c,
                    LearningCourse.CourseNumber
                FROM CourseOffering
                WHERE Id IN :offeringIds
            ]);
            
            Map<String, ScheduleVariantConfig> variantByCourseType = loadScheduleVariantConfigs();
            String scheduleLocationField = getExistingFieldName(
                CourseOfferingSchedule.SObjectType.getDescribe().fields.getMap(),
            new List<String>{ 'Room__c', 'Location__c', 'Venue__c', 'Classroom__c' }
            );
            
            List<String> scheduleFields = new List<String>{
                'Id',
                'CourseOfferingId',
                'StartTime',
                'EndTime',
                'IsMonday',
                'IsTuesday',
                'IsWednesday',
                'IsThursday',
                'IsFriday',
                'IsSaturday',
                'IsSunday'
            };
            if (String.isNotBlank(scheduleLocationField)) {
                scheduleFields.add(scheduleLocationField);
            }
            
            List<SObject> schedules = Database.query(
                'SELECT ' + String.join(scheduleFields, ',') +
                ' FROM CourseOfferingSchedule WHERE CourseOfferingId IN :offeringIds'
                );
            
            Date referenceDate = parseReferenceDate(referenceDateIso);
            Date rangeStart = calculateRangeStart(referenceDate, viewMode);
            Date rangeEnd = calculateRangeEnd(referenceDate, viewMode);
            
            List<StudentCalendarEventDTO> result = new List<StudentCalendarEventDTO>();
            for (SObject row : schedules) {
                Id offeringId = (Id) row.get('CourseOfferingId');
                CourseOffering offering = offeringMap.get(offeringId);
                if (offering == null) {
                    continue;
                }
                
                Time startTime = (Time) row.get('StartTime');
                Time endTime = (Time) row.get('EndTime');
                if (startTime == null || endTime == null) {
                    continue;
                }
                
                String normalizedCourseType = normalizeCourseType(offering.Course_Type__c);
                ScheduleVariantConfig variantConfig = variantByCourseType.get(normalizedCourseType);
                String courseCode = offering.LearningCourse == null ? null : offering.LearningCourse.CourseNumber;
                String credits = offering.Credit__c == null ? null : String.valueOf(offering.Credit__c);
                String subtitle = buildStudentScheduleSubtitle(courseCode, credits);
                String location = String.isBlank(scheduleLocationField) ? '' : safeString(row.get(scheduleLocationField));
                
                for (Date currentDate = rangeStart; currentDate <= rangeEnd; currentDate = currentDate.addDays(1)) {
                    if (!isScheduleActiveOnDate(row, currentDate)) {
                        continue;
                    }
                    
                    StudentCalendarEventDTO dto = new StudentCalendarEventDTO();
                    dto.id = String.valueOf(row.get('Id')) + '-' + String.valueOf(currentDate);
                    dto.title = String.isBlank(offering.Name) ? 'Course Offering' : offering.Name;
                    dto.subtitle = subtitle;
                    dto.footer = '';
                    dto.startDateTime = toLocalIsoString(currentDate, startTime);
                    dto.endDateTime = toLocalIsoString(currentDate, endTime);
                    dto.location = location;
                    dto.variant = variantConfig == null ? 'blue' : variantConfig.variant;
                    dto.hexColor = variantConfig == null ? null : variantConfig.hexColor;
                    result.add(dto);
                }
            }
            
            result.sort(new StudentCalendarEventSorter());
            return result;
        } catch (Exception e) {
            KenAuditLogHelper.auditLogRecord(
                'Course Enrollment',
            'CourseEnrollmentController.getStudentCalendarEvents'
                )
                .setErrorMessage(e == null ? 'Unknown error' : e.getMessage())
                .setStackTrace(e == null ? null : e.getStackTraceString())
                .create();
            throw new AuraHandledException('Failed to get student calendar events: ' + e.getMessage());
        }
    }
    /**
     * @description
     *  Formats a `Time` value into 12-hour format (for example, `9:30 AM`).
     *
     * @param t Time value.
     * @return String Formatted time string, or empty string when input is null.
     */
    @TestVisible
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
    
    @TestVisible
    private class ScheduleVariantConfig {
        private String variant;
        private String hexColor;
    }
    
    @TestVisible
    private class StudentCalendarEventSorter implements Comparator<StudentCalendarEventDTO> {
        public Integer compare(StudentCalendarEventDTO a, StudentCalendarEventDTO b) {
            if (a.startDateTime == b.startDateTime) {
                return a.id.compareTo(b.id);
            }
            return a.startDateTime.compareTo(b.startDateTime);
        }
    }
    
    @TestVisible
    private static Map<String, ScheduleVariantConfig> loadScheduleVariantConfigs() {
        Map<String, ScheduleVariantConfig> result = new Map<String, ScheduleVariantConfig>();
        if (!Schema.getGlobalDescribe().containsKey('Ken_Course_Type_Variant__mdt')) {
            return result;
        }
        
        for (Ken_Course_Type_Variant__mdt row : [
            SELECT Course_Type__c, Variant__c, Hex_Color__c, Is_Active__c
            FROM Ken_Course_Type_Variant__mdt
            WHERE Is_Active__c = true
        ]) {
            String key = normalizeCourseType(row.Course_Type__c);
            if (String.isBlank(key)) {
                continue;
            }
            ScheduleVariantConfig config = new ScheduleVariantConfig();
            config.variant = String.isBlank(row.Variant__c) ? 'blue' : row.Variant__c.trim().toLowerCase();
            config.hexColor = String.isBlank(row.Hex_Color__c) ? null : row.Hex_Color__c.trim();
            result.put(key, config);
        }
        return result;
    }
    
    @TestVisible
    private static String normalizeCourseType(String value) {
        return String.isBlank(value) ? '' : value.trim().toLowerCase();
    }
    
    @TestVisible
    private static String buildStudentScheduleSubtitle(String courseCode, String credits) {
        List<String> bits = new List<String>();
        if (String.isNotBlank(courseCode)) {
            bits.add(courseCode);
        }
        if (String.isNotBlank(credits)) {
            bits.add(credits + ' credits');
        }
        return String.join(bits, '  •  ');
    }
    
    @TestVisible
    private static Date parseReferenceDate(String referenceDateIso) {
        if (String.isBlank(referenceDateIso)) {
            return Date.today();
        }
        try {
            return Date.valueOf(referenceDateIso);
        } catch (Exception ex) {
            return Date.today();
        }
    }
    
    @TestVisible
    private static Date calculateRangeStart(Date referenceDate, String viewMode) {
        String normalizedView = String.isBlank(viewMode) ? 'day' : viewMode.trim().toLowerCase();
        if (normalizedView == 'month') {
            return Date.newInstance(referenceDate.year(), referenceDate.month(), 1);
        }
        if (normalizedView == 'week') {
            Integer weekday = Integer.valueOf(Datetime.newInstance(referenceDate, Time.newInstance(0, 0, 0, 0)).format('u'));
            return referenceDate.addDays(1 - weekday);
        }
        return referenceDate;
    }
    
    @TestVisible
    private static Date calculateRangeEnd(Date referenceDate, String viewMode) {
        String normalizedView = String.isBlank(viewMode) ? 'day' : viewMode.trim().toLowerCase();
        if (normalizedView == 'month') {
            return Date.newInstance(referenceDate.year(), referenceDate.month(), Date.daysInMonth(referenceDate.year(), referenceDate.month()));
        }
        if (normalizedView == 'week') {
            return calculateRangeStart(referenceDate, viewMode).addDays(6);
        }
        return referenceDate;
    }
    
    @TestVisible
    private static Boolean isScheduleActiveOnDate(SObject schedule, Date currentDate) {
        Integer weekday = Integer.valueOf(Datetime.newInstance(currentDate, Time.newInstance(0, 0, 0, 0)).format('u'));
        return (weekday == 1 && safeBoolean(schedule.get('IsMonday'))) ||
            (weekday == 2 && safeBoolean(schedule.get('IsTuesday'))) ||
            (weekday == 3 && safeBoolean(schedule.get('IsWednesday'))) ||
            (weekday == 4 && safeBoolean(schedule.get('IsThursday'))) ||
            (weekday == 5 && safeBoolean(schedule.get('IsFriday'))) ||
            (weekday == 6 && safeBoolean(schedule.get('IsSaturday'))) ||
            (weekday == 7 && safeBoolean(schedule.get('IsSunday')));
    }
    
    @TestVisible
    private static String toLocalIsoString(Date dateValue, Time timeValue) {
        if (dateValue == null || timeValue == null) {
            return null;
        }
        return String.valueOf(dateValue) + 'T' + pad2(timeValue.hour()) + ':' + pad2(timeValue.minute()) + ':' + pad2(timeValue.second());
    }
    
    @TestVisible
    private static String pad2(Integer value) {
        return value < 10 ? '0' + String.valueOf(value) : String.valueOf(value);
    }
    
    @TestVisible
    private static String getExistingFieldName(Map<String, Schema.SObjectField> fields, List<String> candidates) {
        for (String candidate : candidates) {
            if (fields.containsKey(candidate)) {
                return candidate;
            }
        }
        return null;
    }
    
    @TestVisible
    private static String safeString(Object value) {
        return value == null ? '' : String.valueOf(value);
    }
    
    @TestVisible
    private static Boolean safeBoolean(Object value) {
        return value != null && (Boolean) value;
    }
    
}