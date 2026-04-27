/**
 * @description Controller for portal course-enrollment screen data.
 */
public without sharing class KenPortalCourseEnrollmentController {
    /**
     * @description DTO for learner academic-session tiles/list.
     */
    @TestVisible
    private static Boolean forceExceptionInGetLearnerPathways = false;
    
    @TestVisible
    private static Boolean forceExceptionInGetLearnerPathwayItems = false;
    public class AcademicSessionDTO {
        @AuraEnabled public Id academicSessionId;
        @AuraEnabled public String academicSessionName;
        @AuraEnabled public String academicTermName;
        @AuraEnabled public String season;
        @AuraEnabled public Integer sequence;
        @AuraEnabled public String cadenceType;
        @AuraEnabled public Integer termNumber;
        @AuraEnabled public String termLabel;
        @AuraEnabled public String registrationStatus;
        @AuraEnabled public Datetime registrationStartDate;
        @AuraEnabled public Datetime registrationEndDate;
        @AuraEnabled public Boolean isProgramCompleted;
    }
    
    public class ProgramTemplateDTO {
        @AuraEnabled public Id learningPathwayTemplateId;
        @AuraEnabled public String learningPathwayTemplateName;
        @AuraEnabled public String templateType;
        @AuraEnabled public Boolean isDefaultPathway;
        @AuraEnabled public Boolean isEnrolled;
        @AuraEnabled public Id learnerPathwayId;
        @AuraEnabled public String startPeriod;
        @AuraEnabled public String endPeriod;
    }
    
    public class LearnerPathwayDTO {
        @AuraEnabled public Id learnerPathwayId;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public Id learningPathwayTemplateId;
    }
    
    public class CourseDTO {
        @AuraEnabled public Id learningPathwayTemplateItemId;
        @AuraEnabled public Id learningCourseId;
        @AuraEnabled public String courseName;
        @AuraEnabled public String enrollmentStatus;
        @AuraEnabled public Integer credits;
        @AuraEnabled public Id learningProgramPlanRequirementId;
        @AuraEnabled public Integer year;
        @AuraEnabled public String season;
        @AuraEnabled public Integer sequence;
        @AuraEnabled public Id academicSessionId;
        @AuraEnabled public Id courseOfferingId;
        @AuraEnabled public String imageUrl;
        @AuraEnabled public String courseType;
        @AuraEnabled public String courseCode;
        @AuraEnabled public Id learningPathwayTemplateId;
        @AuraEnabled public String learningPathwayTemplateName;
        @AuraEnabled public String templateType;
        @AuraEnabled public String groupName;
        @AuraEnabled public String ruleType;
        @AuraEnabled public Decimal minCourseCount;
        @AuraEnabled public Decimal maxCourseCount;
        @AuraEnabled public Decimal maxCreditLimit;
        @AuraEnabled public List<FacultyOptionDTO> facultyOptions;
    }
    
    public class FacultyOptionDTO {
        @AuraEnabled public Id courseOfferingId;
        @AuraEnabled public String facultyName;
        @AuraEnabled public List<String> scheduleLines;
        @AuraEnabled public Integer enrollmentCapacity;
        @AuraEnabled public Integer enrolleeCount;
        @AuraEnabled public Integer seatsRemaining;
        @AuraEnabled public Boolean isWaitlistActive;
        @AuraEnabled public Integer waitlistCapacity;
        @AuraEnabled public Integer waitlistCount;
        @AuraEnabled public Integer waitlistSeatsRemaining;
    }
    
    public class EnrollmentSubmissionResultDTO {
        @AuraEnabled public List<Id> learnerPathwayItemIds;
        @AuraEnabled public Integer enrolledCount;
        @AuraEnabled public Integer waitlistedCount;
        @AuraEnabled public Integer skippedCount;
        @AuraEnabled public String message;
    }
    
    private class EnrollmentDecision {
        private LearnerPathwayItemRequestDTO request;
        private String participationStatus;
        private Boolean shouldCreateLearnerPathwayItem;
    }
    
    public class LearnerPathwayItemRequestDTO {
        @AuraEnabled public Id learnerPathwayId { get; set; }
        @AuraEnabled public Id learningPathwayTemplateId { get; set; }
        @AuraEnabled public Id learningPathwayTemplateItemId { get; set; }
        @AuraEnabled public Id learningCourseId { get; set; }
        @AuraEnabled public Id academicSessionId { get; set; }
        @AuraEnabled public Id courseOfferingId { get; set; }
    }
    
    /**
     * @description Returns active academic sessions for current learner.
     * Supports portal users linked via Contact directly or via Person Account.
     * @return Ordered list of learner academic sessions.
     */
    @AuraEnabled(cacheable=true)
    public static List<AcademicSessionDTO> getAcademicSessionsForUser() {
        try {
            if (forceExceptionInGetLearnerPathways) {
                throw new IllegalArgumentException('Test exception');
            }
            Id learnerContactId = resolveLearnerContactId();
            System.debug(LoggingLevel.INFO,
            'KenPortalCourseEnrollmentController.getAcademicSessionsForUser: userId=' +
                UserInfo.getUserId() + ', learnerContactId=' + learnerContactId);
            if (learnerContactId == null) {
                System.debug(LoggingLevel.WARN,
                'KenPortalCourseEnrollmentController.getAcademicSessionsForUser: learnerContactId is null, returning empty list.');
                return new List<AcademicSessionDTO>();
            }
            
            List<LearnerProgram> programs = [
                SELECT LearningProgramPlanId
                FROM LearnerProgram
                WHERE LearnerContactId = :learnerContactId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            System.debug(LoggingLevel.INFO,
            'KenPortalCourseEnrollmentController.getAcademicSessionsForUser: learner programs found=' +
                programs.size() + ', firstPlanId=' + (programs.isEmpty() ? null : programs[0].LearningProgramPlanId));
            if (programs.isEmpty() || programs[0].LearningProgramPlanId == null) {
                System.debug(LoggingLevel.WARN,
                'KenPortalCourseEnrollmentController.getAcademicSessionsForUser: no learner program with plan id, returning empty list.');
                return new List<AcademicSessionDTO>();
            }
            
            LearningProgramPlan plan = [
                SELECT Cadence_Type__c, Start_Year__c
                FROM LearningProgramPlan
                WHERE Id = :programs[0].LearningProgramPlanId
                LIMIT 1
                ];
            String cadenceType = plan.Cadence_Type__c;
            Integer planStartYear = parseYear(plan.Start_Year__c);
            System.debug(LoggingLevel.INFO,
            'KenPortalCourseEnrollmentController.getAcademicSessionsForUser: cadenceType=' + cadenceType +
                ', planStartYear=' + planStartYear);
            
            List<AcademicTermEnrollment> enrollments = [
                SELECT AcademicTermId,
                    IsEnrollmentSelectionCompleted__c,
                    AcademicTerm.Name,
                    AcademicTerm.Start_Year__c,
                    AcademicTerm.Sequence__c,
                    AcademicTerm.Use_Session_Registration_Dates__c,
                    AcademicTerm.RegistrationOpenDate,
                    AcademicTerm.RegistrationCloseDate
                FROM AcademicTermEnrollment
                WHERE LearnerContactId = :learnerContactId
            ];
            System.debug(LoggingLevel.INFO,
            'KenPortalCourseEnrollmentController.getAcademicSessionsForUser: term enrollments found=' + enrollments.size());
            if (enrollments.isEmpty()) {
                System.debug(LoggingLevel.WARN,
                'KenPortalCourseEnrollmentController.getAcademicSessionsForUser: no term enrollments, returning empty list.');
                return new List<AcademicSessionDTO>();
            }
            
            Set<Id> academicTermIds = new Set<Id>();
            Map<Id, Integer> expectedSequenceByTermId = new Map<Id, Integer>();
            Map<Id, String> academicTermNameById = new Map<Id, String>();
            Map<Id, Boolean> useSessionRegistrationByTermId = new Map<Id, Boolean>();
            Map<Id, Object> termRegistrationOpenByTermId = new Map<Id, Object>();
            Map<Id, Object> termRegistrationCloseByTermId = new Map<Id, Object>();
            Map<Id, Boolean> enrollmentSelectionCompletedByTermId = new Map<Id, Boolean>();
            Integer cadencePeriods = resolveCadencePeriods(cadenceType);
            for (AcademicTermEnrollment e : enrollments) {
                if (e.AcademicTermId != null) {
                    academicTermIds.add(e.AcademicTermId);
                    if (e.get('IsEnrollmentSelectionCompleted__c') == true) {
                        enrollmentSelectionCompletedByTermId.put(e.AcademicTermId, true);
                    } else if (!enrollmentSelectionCompletedByTermId.containsKey(e.AcademicTermId)) {
                        enrollmentSelectionCompletedByTermId.put(e.AcademicTermId, false);
                    }
                    if (e.AcademicTerm != null) {
                        academicTermNameById.put(e.AcademicTermId, e.AcademicTerm.Name);
                        useSessionRegistrationByTermId.put(
                            e.AcademicTermId,
                        e.AcademicTerm.Use_Session_Registration_Dates__c
                            );
                        termRegistrationOpenByTermId.put(
                            e.AcademicTermId,
                        e.AcademicTerm.RegistrationOpenDate
                            );
                        termRegistrationCloseByTermId.put(
                            e.AcademicTermId,
                        e.AcademicTerm.RegistrationCloseDate
                            );
                        Integer termStartYear = parseYear(e.AcademicTerm.Start_Year__c);
                        Integer termSequence = resolveTermSequence(e.AcademicTerm.Sequence__c);
                        Integer expectedSequence = calculateAbsoluteSemesterNumber(
                            planStartYear,
                        termStartYear,
                        termSequence,
                        cadencePeriods
                            );
                        if (expectedSequence != null) {
                            expectedSequenceByTermId.put(e.AcademicTermId, expectedSequence);
                        }
                    }
                }
            }
            System.debug(LoggingLevel.INFO,
            'KenPortalCourseEnrollmentController.getAcademicSessionsForUser: unique academicTermIds count=' +
                academicTermIds.size() + ', expectedSequenceByTermId=' + expectedSequenceByTermId);
            if (academicTermIds.isEmpty()) {
                System.debug(LoggingLevel.WARN,
                'KenPortalCourseEnrollmentController.getAcademicSessionsForUser: no non-null academicTermIds, returning empty list.');
                return new List<AcademicSessionDTO>();
            }
            
            // Portal users may not have access to this object/fields. In that case,
            // return an empty state instead of throwing a generic wire error.
            // if (!Schema.SObjectType.AcademicSession.isAccessible() ||
            //     !Schema.SObjectType.AcademicSession.fields.Name.isAccessible() ||
            //     !Schema.SObjectType.AcademicSession.fields.Season.isAccessible() ||
            //     !Schema.SObjectType.AcademicSession.fields.Type.isAccessible() ||
            //     !Schema.SObjectType.AcademicSession.fields.IsActive.isAccessible() ||
            //     !Schema.SObjectType.AcademicSession.fields.AcademicTermId.isAccessible()) {
                //     System.debug(LoggingLevel.WARN,
                //         'KenPortalCourseEnrollmentController.getAcademicSessionsForUser: AcademicSession object/field access missing for current user. Returning empty list.');
                //     return new List<AcademicSessionDTO>();
            // }
            
            List<AcademicSession> sessions = [
                SELECT Id,
                    Name,
                    Season,
                    Type,
                    Sequence__c,
                    Cadence_Period__c,
                    Registration_Open_Date__c,
                    Registration_Close_Date__c,
                    AcademicTermId
                FROM AcademicSession
                WHERE AcademicTermId IN :academicTermIds
                AND Type = :cadenceType
                AND IsActive = true
                ORDER BY AcademicTermId ASC, Name ASC
            ];
            System.debug(LoggingLevel.INFO,
            'KenPortalCourseEnrollmentController.getAcademicSessionsForUser: sessions returned=' +
                sessions.size() + ', cadence filter=' + cadenceType);
            
            Map<Id, AcademicSession> selectedSessionByTermId = new Map<Id, AcademicSession>();
            for (AcademicSession s : sessions) {
                System.debug(LoggingLevel.DEBUG,
                'KenPortalCourseEnrollmentController.getAcademicSessionsForUser: sessionId=' + s.Id +
                    ', sessionName=' + s.Name + ', season=' + s.Season + ', type=' + s.Type +
                    ', sequence=' + s.Sequence__c + ', cadencePeriod=' + s.Cadence_Period__c + ', termId=' + s.AcademicTermId);
                Integer expectedSequence = expectedSequenceByTermId.get(s.AcademicTermId);
                Integer sessionSemesterNumber = resolveSessionSemesterNumber(s);
                if (expectedSequence != null && sessionSemesterNumber != null && sessionSemesterNumber == expectedSequence) {
                    selectedSessionByTermId.put(s.AcademicTermId, s);
                }
            }
            
            List<AcademicSessionDTO> result = new List<AcademicSessionDTO>();
            Map<Integer, List<AcademicSessionDTO>> dtoByTermNumber = new Map<Integer, List<AcademicSessionDTO>>();
            for (Id termId : expectedSequenceByTermId.keySet()) {
                AcademicSession matched = selectedSessionByTermId.get(termId);
                if (matched == null) {
                    continue;
                }
                Integer termNumber = expectedSequenceByTermId.get(termId);
                AcademicSessionDTO dto = new AcademicSessionDTO();
                dto.academicSessionId = matched.Id;
                dto.academicSessionName = matched.Name;
                dto.academicTermName = academicTermNameById.get(termId);
                dto.season = matched.Season;
                dto.sequence = termNumber;
                dto.cadenceType = cadenceType;
                dto.termNumber = termNumber;
                dto.termLabel = cadenceType + ' ' + termNumber;
                dto.registrationStatus = resolveRegistrationStatus(
                    useSessionRegistrationByTermId.get(termId),
                matched.Registration_Open_Date__c,
                matched.Registration_Close_Date__c,
                termRegistrationOpenByTermId.get(termId),
                termRegistrationCloseByTermId.get(termId)
                    );
                dto.registrationStartDate = resolveRegistrationBoundary(
                    useSessionRegistrationByTermId.get(termId),
                matched.Registration_Open_Date__c,
                termRegistrationOpenByTermId.get(termId)
                    );
                dto.registrationEndDate = resolveRegistrationBoundary(
                    useSessionRegistrationByTermId.get(termId),
                matched.Registration_Close_Date__c,
                termRegistrationCloseByTermId.get(termId)
                    );
                dto.isProgramCompleted = enrollmentSelectionCompletedByTermId.get(termId) == true;
                if (!dtoByTermNumber.containsKey(termNumber)) {
                    dtoByTermNumber.put(termNumber, new List<AcademicSessionDTO>());
                }
                dtoByTermNumber.get(termNumber).add(dto);
            }
            List<Integer> termNumbers = new List<Integer>(dtoByTermNumber.keySet());
            termNumbers.sort();
            for (Integer tn : termNumbers) {
                result.addAll(dtoByTermNumber.get(tn));
            }
            System.debug(LoggingLevel.INFO,
            'KenPortalCourseEnrollmentController.getAcademicSessionsForUser: returning rows=' + result.size());
            return result;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
            'KenPortalCourseEnrollmentController.getAcademicSessionsForUser failed: ' +
                (e == null ? 'Unknown error' : e.getMessage()));
            // Do not let audit-log failures break cacheable wire responses.
            try {
                KenAuditLogHelper.auditLogRecord(
                    'Portal Course Enrollment',
                'KenPortalCourseEnrollmentController.getAcademicSessionsForUser'
                    )
                    .setErrorMessage(e == null ? 'Unknown error' : e.getMessage())
                    .setStackTrace(e == null ? null : e.getStackTraceString())
                    .create();
            } catch (Exception ignored) {
                System.debug(LoggingLevel.ERROR, 'Audit log skipped: ' + ignored.getMessage());
            }
            throw new AuraHandledException('Failed to get academic sessions: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<ProgramTemplateDTO> getProgramTemplatesForSemester(Integer semesterNumber) {
        try {
            List<ProgramTemplateDTO> result = new List<ProgramTemplateDTO>();
            if (semesterNumber == null || semesterNumber <= 0) {
                return result;
            }
            
            Id learnerContactId = resolveLearnerContactId();
            if (learnerContactId == null) {
                return result;
            }
            
            List<LearnerProgram> programs = [
                SELECT LearningProgramPlanId
                FROM LearnerProgram
                WHERE LearnerContactId = :learnerContactId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (programs.isEmpty() || programs[0].LearningProgramPlanId == null) {
                return result;
            }
            System.debug(LoggingLevel.INFO,
            'KenPortalCourseEnrollmentController.getCoursesForSemester: resolvedProgramPlanId=' + programs[0].LearningProgramPlanId
                );
            
            List<LearningPathwayTmplPgmPlan> links = [
                SELECT LearningPathwayTemplateId,
                    LearningPathwayTemplate.Name,
                    LearningPathwayTemplate.Pathway_Type__c,
                    Default__c,
                    Start_Period__c,
                    End_Period__c
                FROM LearningPathwayTmplPgmPlan
                WHERE LearningProgramPlanId = :programs[0].LearningProgramPlanId
                ];
            
            Set<String> templateNames = new Set<String>();
            for (LearningPathwayTmplPgmPlan link : links) {
                if (link.LearningPathwayTemplate != null && String.isNotBlank(link.LearningPathwayTemplate.Name)) {
                    templateNames.add(link.LearningPathwayTemplate.Name.trim());
                }
            }
            Map<String, LearnerPathway> learnerPathwayByName = new Map<String, LearnerPathway>();
            if (!templateNames.isEmpty()) {
                for (LearnerPathway pathway : [
                    SELECT Id, Name
                    FROM LearnerPathway
                    WHERE LearnerContactId = :learnerContactId
                    AND Name IN :templateNames
                ]) {
                    if (String.isNotBlank(pathway.Name)) {
                        learnerPathwayByName.put(pathway.Name.trim().toLowerCase(), pathway);
                    }
                }
            }
            
            for (LearningPathwayTmplPgmPlan link : links) {
                Integer startPeriod = parseFirstNumber(link.Start_Period__c);
                Integer endPeriod = parseFirstNumber(link.End_Period__c);
                
                Integer fromPeriod = startPeriod == null ? 1 : startPeriod;
                Integer toPeriod = endPeriod == null ? fromPeriod : endPeriod;
                
                if (semesterNumber < fromPeriod || semesterNumber > toPeriod) {
                    continue;
                }
                
                ProgramTemplateDTO dto = new ProgramTemplateDTO();
                dto.learningPathwayTemplateId = link.LearningPathwayTemplateId;
                dto.learningPathwayTemplateName =
                    link.LearningPathwayTemplate == null ? null : link.LearningPathwayTemplate.Name;
                dto.templateType =
                    link.LearningPathwayTemplate == null ? null : link.LearningPathwayTemplate.Pathway_Type__c;
                dto.isDefaultPathway = link.Default__c == true;
                String templateNameKey = String.isBlank(dto.learningPathwayTemplateName)
                    ? null
                    : dto.learningPathwayTemplateName.trim().toLowerCase();
                LearnerPathway enrolledPathway =
                    templateNameKey == null ? null : learnerPathwayByName.get(templateNameKey);
                dto.isEnrolled = enrolledPathway != null;
                dto.learnerPathwayId = enrolledPathway == null ? null : enrolledPathway.Id;
                dto.startPeriod = link.Start_Period__c;
                dto.endPeriod = link.End_Period__c;
                result.add(dto);
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to get program templates for semester: ' +
                (e == null ? 'Unknown error' : e.getMessage())
                );
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<LearnerPathwayDTO> getLearnerPathwaysForUser() {
        try {
            if (forceExceptionInGetLearnerPathways) {
                throw new IllegalArgumentException('Test exception');
            }
            List<LearnerPathwayDTO> result = new List<LearnerPathwayDTO>();
            Id learnerContactId = resolveLearnerContactId();
            if (learnerContactId == null) {
                return result;
            }
            List<LearnerPathway> learnerPathways = [
                SELECT Id, Name, Status
                FROM LearnerPathway
                WHERE LearnerContactId = :learnerContactId
                ORDER BY Name ASC
            ];
            
            Set<String> pathwayNames = new Set<String>();
            for (LearnerPathway pathway : learnerPathways) {
                if (String.isNotBlank(pathway.Name)) {
                    pathwayNames.add(pathway.Name.trim());
                }
            }
            
            Map<String, Id> templateIdByNameKey = new Map<String, Id>();
            if (!pathwayNames.isEmpty()) {
                List<LearnerProgram> programs = [
                    SELECT LearningProgramPlanId
                    FROM LearnerProgram
                    WHERE LearnerContactId = :learnerContactId
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                Id programPlanId =
                    (programs.isEmpty() || programs[0].LearningProgramPlanId == null)
                    ? null
                    : programs[0].LearningProgramPlanId;
                
                if (programPlanId != null) {
                    for (LearningPathwayTmplPgmPlan link : [
                        SELECT LearningPathwayTemplateId, LearningPathwayTemplate.Name
                        FROM LearningPathwayTmplPgmPlan
                        WHERE LearningProgramPlanId = :programPlanId
                        AND LearningPathwayTemplate.Name IN :pathwayNames
                    ]) {
                        String key =
                            (link.LearningPathwayTemplate == null || String.isBlank(link.LearningPathwayTemplate.Name))
                            ? null
                            : link.LearningPathwayTemplate.Name.trim().toLowerCase();
                        if (key != null && !templateIdByNameKey.containsKey(key)) {
                            templateIdByNameKey.put(key, link.LearningPathwayTemplateId);
                        }
                    }
                }
                
                if (templateIdByNameKey.isEmpty()) {
                    for (LearningPathwayTemplate templateRow : [
                        SELECT Id, Name
                        FROM LearningPathwayTemplate
                        WHERE Name IN :pathwayNames
                    ]) {
                        if (String.isBlank(templateRow.Name)) {
                            continue;
                        }
                        String key = templateRow.Name.trim().toLowerCase();
                        if (!templateIdByNameKey.containsKey(key)) {
                            templateIdByNameKey.put(key, templateRow.Id);
                        }
                    }
                }
            }
            
            for (LearnerPathway pathway : learnerPathways) {
                LearnerPathwayDTO dto = new LearnerPathwayDTO();
                dto.learnerPathwayId = pathway.Id;
                dto.name = pathway.Name;
                dto.status = pathway.Status;
                String nameKey = String.isBlank(pathway.Name) ? null : pathway.Name.trim().toLowerCase();
                dto.learningPathwayTemplateId =
                    nameKey == null ? null : templateIdByNameKey.get(nameKey);
                result.add(dto);
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to load learner pathways: ' +
                (e == null ? 'Unknown error' : e.getMessage())
                );
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<CourseDTO> getCoursesForSemester(
        Integer semesterNumber,
    Id academicSessionId,
    Id learningPathwayTemplateId,
    Boolean selectedPathwaysOnly
    ) {
        try {
            if (forceExceptionInGetLearnerPathways) {
                throw new IllegalArgumentException('Test exception');
            }
            List<CourseDTO> result = new List<CourseDTO>();
            if (semesterNumber == null || semesterNumber <= 0) {
                return result;
            }
            
            Id learnerContactId = resolveLearnerContactId();
            if (learnerContactId == null) {
                return result;
            }
            
            List<LearnerProgram> programs = [
                SELECT LearningProgramPlanId
                FROM LearnerProgram
                WHERE LearnerContactId = :learnerContactId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (programs.isEmpty() || programs[0].LearningProgramPlanId == null) {
                return result;
            }
            
            LearningProgramPlan plan = [
                SELECT Cadence_Type__c
                FROM LearningProgramPlan
                WHERE Id = :programs[0].LearningProgramPlanId
                LIMIT 1
                ];
            
            List<LearningPathwayTmplPgmPlan> pathwayLinks = [
                SELECT LearningPathwayTemplateId,
                    LearningPathwayTemplate.Name
                FROM LearningPathwayTmplPgmPlan
                WHERE LearningProgramPlanId = :programs[0].LearningProgramPlanId
                ];
            
            Set<String> selectedPathwayNames = new Set<String>();
            Set<String> selectedPathwayNamesRaw = new Set<String>();
            if (selectedPathwaysOnly == true) {
                for (LearnerPathway pathway : [
                    SELECT Name
                    FROM LearnerPathway
                    WHERE LearnerContactId = :learnerContactId
                ]) {
                    if (String.isNotBlank(pathway.Name)) {
                        String nameRaw = pathway.Name.trim();
                        selectedPathwayNamesRaw.add(nameRaw);
                        selectedPathwayNames.add(nameRaw.toLowerCase());
                    }
                }
            }
            
            Set<Id> templateIds = new Set<Id>();
            for (LearningPathwayTmplPgmPlan link : pathwayLinks) {
                if (learningPathwayTemplateId != null &&
                link.LearningPathwayTemplateId != learningPathwayTemplateId) {
                    continue;
                }
                if (selectedPathwaysOnly == true &&
                    (link.LearningPathwayTemplate == null ||
                    String.isBlank(link.LearningPathwayTemplate.Name) ||
                !selectedPathwayNames.contains(link.LearningPathwayTemplate.Name.trim().toLowerCase()))) {
                    continue;
                }
                templateIds.add(link.LearningPathwayTemplateId);
            }
            System.debug(LoggingLevel.INFO,
            'KenPortalCourseEnrollmentController.getCoursesForSemester: programPlanId=' + programs[0].LearningProgramPlanId +
                ', pathwayLinks=' + pathwayLinks.size() +
                ', templateIds=' + templateIds
                );
            
            // Fallback: if no template matched via program-plan link, resolve templates
            // directly by LearnerPathway.Name to avoid missing selected pathways.
            if (templateIds.isEmpty() && selectedPathwaysOnly == true && !selectedPathwayNamesRaw.isEmpty()) {
                for (LearningPathwayTemplate templateRow : [
                    SELECT Id, Name
                    FROM LearningPathwayTemplate
                    WHERE Name IN :selectedPathwayNamesRaw
                ]) {
                    if (templateRow == null || String.isBlank(templateRow.Name)) {
                        continue;
                    }
                    if (selectedPathwayNames.contains(templateRow.Name.trim().toLowerCase())) {
                        templateIds.add(templateRow.Id);
                    }
                }
            }
            if (templateIds.isEmpty()) {
                System.debug(LoggingLevel.WARN,
                'KenPortalCourseEnrollmentController.getCoursesForSemester: no template ids resolved.'
                    );
                return result;
            }
            
            Map<Id, LearningPathwayTemplateItem> validItems = new Map<Id, LearningPathwayTemplateItem>();
            for (LearningPathwayTemplateItem item : [
                SELECT Id,
                    Year,
                    Season,
                    SequenceNumber,
                    Sequence__c,
                    LearningProgramPlanRequirementId,
                    LearningProgramPlanRequirement.GroupName,
                    LearningProgramPlanRequirement.Rule_Type__c,
                    LearningProgramPlanRequirement.Min_Course_Count__c,
                    LearningProgramPlanRequirement.Max_Course_Count__c,
                    LearningProgramPlanRequirement.Max_Credit_Limit__c,
                    LearningProgramPlanRequirement.Learning_Course__c,
                    LearningProgramPlanRequirement.Learning_Course__r.Name,
                    LearningProgramPlanRequirement.Learning_Course__r.Duration,
                    LearningProgramPlanRequirement.Learning_Course__r.LearningId,
                    LearningProgramPlanRequirement.Learning_Course__r.CourseNumber,
                    LearningPathwayTemplateId,
                    LearningPathwayTemplate.Name,
                    LearningPathwayTemplate.Pathway_Type__c,
                    Type
                FROM LearningPathwayTemplateItem
                WHERE LearningPathwayTemplateId IN :templateIds
                AND LearningProgramPlanRequirement.LearningProgramPlanId = :programs[0].LearningProgramPlanId
            ]) {
                if (item == null ||
                    item.LearningProgramPlanRequirement == null ||
                item.LearningProgramPlanRequirement.Learning_Course__c == null) {
                    continue;
                }
                Integer yearVal = parseFirstNumber(item.Year);
                Integer sequenceVal = parseInteger(item.Sequence__c);
                if (sequenceVal == null) {
                    sequenceVal = parseInteger(item.SequenceNumber);
                }
                Integer calculatedPeriodNumber = calculatePeriodNumber(plan.Cadence_Type__c, yearVal, sequenceVal);
                if (calculatedPeriodNumber == semesterNumber) {
                    validItems.put(item.LearningProgramPlanRequirement.Learning_Course__c, item);
                }
            }
            if (validItems.isEmpty()) {
                System.debug(LoggingLevel.WARN,
                'KenPortalCourseEnrollmentController.getCoursesForSemester: no valid template items found for semester=' + semesterNumber
                    );
                return result;
            }
            System.debug(LoggingLevel.INFO,
            'KenPortalCourseEnrollmentController.getCoursesForSemester: valid learning course ids=' + validItems.keySet()
                );
            
            Map<Id, List<CourseOffering>> offeringsByCourseId = new Map<Id, List<CourseOffering>>();
            Map<Id, List<String>> scheduleLinesByOfferingId = new Map<Id, List<String>>();
            Map<Id, String> facultyNameById = new Map<Id, String>();
            System.debug('planId=' + programs[0].LearningProgramPlanId);
            System.debug('academicSessionId=' + academicSessionId);
            System.debug('validCourseIds=' + validItems.keySet());
            
            if (academicSessionId != null) {
                try {
                    Set<Id> offeringIds = new Set<Id>();
                    Set<Id> primaryFacultyIds = new Set<Id>();
                    Integer junctionCount = 0;
                    List<Program_Plan_Course_Junction__c> junctionRows = [
    SELECT Course_Offering__c,
           Course_Offering__r.Name,
           Course_Offering__r.LearningCourseId,
           Course_Offering__r.AcademicSessionId,
           Course_Offering__r.PrimaryFacultyId,
           Course_Offering__r.PrimaryFaculty.Name
    FROM Program_Plan_Course_Junction__c
    WHERE Learning_Program_Plan__c = :programs[0].LearningProgramPlanId
                        ];
                    
                    System.debug(LoggingLevel.INFO,
                    'JUNCTION QUERY ROW COUNT=' + junctionRows.size() +
                        ', runtimePlanId=' + programs[0].LearningProgramPlanId +
                        ', runtimeAcademicSessionId=' + academicSessionId +
                        ', runtimeValidCourseIds=' + validItems.keySet()
                        );
                    
                    for (Program_Plan_Course_Junction__c junction : [
                        SELECT Course_Offering__c,
                            Course_Offering__r.Name,
                            Course_Offering__r.LearningCourseId,
                            Course_Offering__r.AcademicSessionId,
                            Course_Offering__r.EnrollmentCapacity,
                            Course_Offering__r.EnrolleeCount,
                            Course_Offering__r.WaitlistCapacity,
                            Course_Offering__r.WaitlistCount,
                            Course_Offering__r.PrimaryFacultyId,
                            Course_Offering__r.PrimaryFaculty.Name
                        FROM Program_Plan_Course_Junction__c
                        WHERE Learning_Program_Plan__c = :programs[0].LearningProgramPlanId
                    ]) {
                        System.debug(LoggingLevel.INFO,
                        'KenPortalCourseEnrollmentController.getCoursesForSemester: JUNCTION ROW => offeringId=' + junction.Course_Offering__c +
                            ', learningCourseId=' + (junction.Course_Offering__r == null ? null : junction.Course_Offering__r.LearningCourseId) +
                            ', academicSessionId=' + (junction.Course_Offering__r == null ? null : junction.Course_Offering__r.AcademicSessionId) +
                            ', faculty=' + (
                            junction.Course_Offering__r == null || junction.Course_Offering__r.PrimaryFaculty == null
                            ? null
                            : junction.Course_Offering__r.PrimaryFaculty.Name
                            )
                            );
                        if (junction.Course_Offering__c == null ||
                            junction.Course_Offering__r == null ||
                            junction.Course_Offering__r.LearningCourseId == null ||
                        junction.Course_Offering__r.AcademicSessionId == null) {
                            continue;
                        }
                        if (junction.Course_Offering__r.AcademicSessionId != academicSessionId) {
                            continue;
                        }
                        if (!validItems.containsKey(junction.Course_Offering__r.LearningCourseId)) {
                            continue;
                        }
                        junctionCount++;
                        offeringIds.add(junction.Course_Offering__c);
                        Id learningCourseId = junction.Course_Offering__r.LearningCourseId;
                        if (!offeringsByCourseId.containsKey(learningCourseId)) {
                            offeringsByCourseId.put(learningCourseId, new List<CourseOffering>());
                        }
                        offeringsByCourseId.get(learningCourseId).add(junction.Course_Offering__r);
                        if (junction.Course_Offering__r.PrimaryFacultyId != null) {
                            primaryFacultyIds.add(junction.Course_Offering__r.PrimaryFacultyId);
                        }
                        System.debug(LoggingLevel.INFO,
                        'KenPortalCourseEnrollmentController.getCoursesForSemester: MAP ADD (junction) => learningCourseId=' + learningCourseId +
                            ', mapSizeForCourse=' + offeringsByCourseId.get(learningCourseId).size()
                            );
                    }
                    System.debug(LoggingLevel.INFO,
                    'KenPortalCourseEnrollmentController.getCoursesForSemester: junctionOfferingsFound=' + junctionCount +
                        ', offeringIdsAfterJunction=' + offeringIds +
                        ', offeringsByCourseIdKeys=' + offeringsByCourseId.keySet()
                        );
                    
                    if (!offeringIds.isEmpty()) {
                        Integer scheduleCount = 0;
                        for (CourseOfferingSchedule schedule : [
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
                            ORDER BY StartTime, EndTime
                        ]) {
                            if (!scheduleLinesByOfferingId.containsKey(schedule.CourseOfferingId)) {
                                scheduleLinesByOfferingId.put(schedule.CourseOfferingId, new List<String>());
                            }
                            scheduleLinesByOfferingId.get(schedule.CourseOfferingId).add(formatScheduleLine(schedule));
                            scheduleCount++;
                        }
                        System.debug(LoggingLevel.INFO,
                        'KenPortalCourseEnrollmentController.getCoursesForSemester: scheduleRowsAfterJunction=' + scheduleCount
                            );
                    }
                    
                    if (offeringsByCourseId.isEmpty()) {
                        Integer fallbackOfferingCount = 0;
                        for (CourseOffering offering : [
                            SELECT Id,
                                Name,
                                LearningCourseId,
                                AcademicSessionId,
                                EnrollmentCapacity,
                                EnrolleeCount,
                                WaitlistCapacity,
                                WaitlistCount,
                                PrimaryFacultyId,
                                PrimaryFaculty.Name
                            FROM CourseOffering
                            WHERE AcademicSessionId = :academicSessionId
                            AND LearningCourseId IN :validItems.keySet()
                        ]) {
                            System.debug(LoggingLevel.INFO,
                            'KenPortalCourseEnrollmentController.getCoursesForSemester: FALLBACK OFFERING => offeringId=' + offering.Id +
                                ', learningCourseId=' + offering.LearningCourseId +
                                ', academicSessionId=' + offering.AcademicSessionId +
                                ', faculty=' + (offering.PrimaryFaculty == null ? null : offering.PrimaryFaculty.Name)
                                );
                            if (offering.LearningCourseId == null) {
                                continue;
                            }
                            fallbackOfferingCount++;
                            if (!offeringsByCourseId.containsKey(offering.LearningCourseId)) {
                                offeringsByCourseId.put(offering.LearningCourseId, new List<CourseOffering>());
                            }
                            offeringsByCourseId.get(offering.LearningCourseId).add(offering);
                            if (offering.PrimaryFacultyId != null) {
                                primaryFacultyIds.add(offering.PrimaryFacultyId);
                            }
                            System.debug(LoggingLevel.INFO,
                            'KenPortalCourseEnrollmentController.getCoursesForSemester: MAP ADD (fallback) => learningCourseId=' + offering.LearningCourseId +
                                ', mapSizeForCourse=' + offeringsByCourseId.get(offering.LearningCourseId).size()
                                );
                            offeringIds.add(offering.Id);
                        }
                        System.debug(LoggingLevel.INFO,
                        'KenPortalCourseEnrollmentController.getCoursesForSemester: fallbackOfferingsFound=' + fallbackOfferingCount +
                            ', offeringIdsAfterFallback=' + offeringIds +
                            ', offeringsByCourseIdKeysAfterFallback=' + offeringsByCourseId.keySet()
                            );
                        
                        if (!offeringIds.isEmpty()) {
                            Integer fallbackScheduleCount = 0;
                            for (CourseOfferingSchedule schedule : [
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
                                ORDER BY StartTime, EndTime
                            ]) {
                                if (!scheduleLinesByOfferingId.containsKey(schedule.CourseOfferingId)) {
                                    scheduleLinesByOfferingId.put(schedule.CourseOfferingId, new List<String>());
                                }
                                scheduleLinesByOfferingId.get(schedule.CourseOfferingId).add(formatScheduleLine(schedule));
                                fallbackScheduleCount++;
                            }
                            System.debug(LoggingLevel.INFO,
                            'KenPortalCourseEnrollmentController.getCoursesForSemester: scheduleRowsAfterFallback=' + fallbackScheduleCount
                                );
                        }
                    }
                    facultyNameById = new FacultyNameResolver().resolve(primaryFacultyIds);
                } catch (Exception ex) {
                    System.debug(LoggingLevel.ERROR,
                    'KenPortalCourseEnrollmentController.getCoursesForSemester: offering enrichment failed: ' +
                        ex.getMessage() + ' | ' + ex.getStackTraceString()
                        );
                }
            }
            
            for (Id courseId : validItems.keySet()) {
                LearningPathwayTemplateItem item = validItems.get(courseId);
                List<CourseOffering> offerings = offeringsByCourseId.get(courseId);
                CourseDTO dto = new CourseDTO();
                dto.learningPathwayTemplateItemId = item.Id;
                dto.learningCourseId = courseId;
                dto.courseName = item.LearningProgramPlanRequirement.Learning_Course__r.Name;
                dto.credits = parseInteger(item.LearningProgramPlanRequirement.Learning_Course__r.Duration);
                if (dto.credits == null) {
                    dto.credits = 0;
                }
                dto.learningProgramPlanRequirementId = item.LearningProgramPlanRequirementId;
                dto.year = parseFirstNumber(item.Year);
                dto.season = item.Season;
                dto.sequence = parseInteger(item.Sequence__c);
                if (dto.sequence == null) {
                    dto.sequence = parseInteger(item.SequenceNumber);
                }
                dto.academicSessionId = academicSessionId;
                dto.courseOfferingId = (offerings == null || offerings.isEmpty()) ? null : offerings[0].Id;
                dto.courseType = item.Type;
                dto.courseCode = item.LearningProgramPlanRequirement.Learning_Course__r.CourseNumber;
                dto.learningPathwayTemplateId = item.LearningPathwayTemplateId;
                dto.learningPathwayTemplateName =
                    item.LearningPathwayTemplate == null ? null : item.LearningPathwayTemplate.Name;
                dto.templateType =
                    item.LearningPathwayTemplate == null ? null : item.LearningPathwayTemplate.Pathway_Type__c;
                dto.groupName = item.LearningProgramPlanRequirement.GroupName;
                dto.ruleType = item.LearningProgramPlanRequirement.Rule_Type__c;
                dto.minCourseCount = item.LearningProgramPlanRequirement.Min_Course_Count__c;
                dto.maxCourseCount = item.LearningProgramPlanRequirement.Max_Course_Count__c;
                dto.maxCreditLimit = item.LearningProgramPlanRequirement.Max_Credit_Limit__c;
                dto.facultyOptions = new List<FacultyOptionDTO>();
                if (offerings != null) {
                    for (CourseOffering offering : offerings) {
                        FacultyOptionDTO facultyDto = new FacultyOptionDTO();
                        facultyDto.courseOfferingId = offering.Id;
                        String resolvedFacultyName =
                            offering.PrimaryFaculty == null || String.isBlank(offering.PrimaryFaculty.Name)
                            ? null
                            : offering.PrimaryFaculty.Name;
                        if (String.isBlank(resolvedFacultyName) && offering.PrimaryFacultyId != null) {
                            resolvedFacultyName = facultyNameById.get(offering.PrimaryFacultyId);
                        }
                        facultyDto.facultyName = String.isBlank(resolvedFacultyName) ? 'Faculty not assigned' : resolvedFacultyName;
                        facultyDto.enrollmentCapacity = parseInteger(offering.EnrollmentCapacity);
                        facultyDto.enrolleeCount = parseInteger(offering.EnrolleeCount);
                        facultyDto.seatsRemaining =
                            facultyDto.enrollmentCapacity == null || facultyDto.enrolleeCount == null
                            ? null
                            : facultyDto.enrollmentCapacity - facultyDto.enrolleeCount;
                        facultyDto.isWaitlistActive = isWaitlistEnabled(offering);
                        facultyDto.waitlistCapacity = parseInteger(offering.WaitlistCapacity);
                        facultyDto.waitlistCount = parseInteger(offering.WaitlistCount);
                        facultyDto.waitlistSeatsRemaining =
                            facultyDto.waitlistCapacity == null || facultyDto.waitlistCount == null
                            ? null
                            : facultyDto.waitlistCapacity - facultyDto.waitlistCount;
                        facultyDto.scheduleLines = scheduleLinesByOfferingId.containsKey(offering.Id)
                            ? scheduleLinesByOfferingId.get(offering.Id)
                        : new List<String>{ 'Schedule unavailable' };
                        dto.facultyOptions.add(facultyDto);
                    }
                }
                System.debug(LoggingLevel.INFO,
                'KenPortalCourseEnrollmentController.getCoursesForSemester: courseId=' + courseId +
                    ', courseName=' + dto.courseName +
                    ', courseOfferingId=' + dto.courseOfferingId +
                    ', facultyOptionsCount=' + (dto.facultyOptions == null ? 0 : dto.facultyOptions.size())
                    );
                System.debug(LoggingLevel.INFO,
                'KenPortalCourseEnrollmentController.getCoursesForSemester: FINAL DTO => courseId=' + dto.learningCourseId +
                    ', courseName=' + dto.courseName +
                    ', facultyOptionsIsNull=' + (dto.facultyOptions == null) +
                    ', facultyOptionsSize=' + (dto.facultyOptions == null ? -1 : dto.facultyOptions.size())
                    );
                result.add(dto);
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to get courses for semester: ' +
                (e == null ? 'Unknown error' : e.getMessage())
                );
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<CourseDTO> getLearnerPathwayItemsForAfterEnrollment(Id academicSessionId) {
        try {
            if (forceExceptionInGetLearnerPathways) {
                throw new IllegalArgumentException('Test exception');
            }
            List<CourseDTO> result = new List<CourseDTO>();
            Id learnerContactId = resolveLearnerContactId();
            if (learnerContactId == null) {
                return result;
            }
            
            List<LearnerPathwayItem> items;
            if (academicSessionId != null) {
                items = [
                    SELECT Id,
                        Enrollment_Status__c,
                        Type,
                        Duration,
                        SequenceNumber,
                        AcademicSessionId,
                        LearningId,
                        Learning.Name,
                        LearnerPathwayId,
                        LearnerPathway.Name,
                        LearningPathwayTemplateItemId,
                        LearningPathwayTemplateItem.LearningPathwayTemplateId,
                        LearningPathwayTemplateItem.LearningPathwayTemplate.Name,
                        LearningPathwayTemplateItem.LearningProgramPlanRequirement.Learning_Course__r.Name,
                        LearningPathwayTemplateItem.LearningProgramPlanRequirement.Learning_Course__r.CourseNumber
                    FROM LearnerPathwayItem
                    WHERE LearnerPathway.LearnerContactId = :learnerContactId
                    AND AcademicSessionId = :academicSessionId
                    ORDER BY LearnerPathway.Name ASC, SequenceNumber ASC, CreatedDate ASC
                ];
            } else {
                items = [
                    SELECT Id,
                        Enrollment_Status__c,
                        Type,
                        Duration,
                        SequenceNumber,
                        AcademicSessionId,
                        LearningId,
                        Learning.Name,
                        LearnerPathwayId,
                        LearnerPathway.Name,
                        LearningPathwayTemplateItemId,
                        LearningPathwayTemplateItem.LearningPathwayTemplateId,
                        LearningPathwayTemplateItem.LearningPathwayTemplate.Name,
                        LearningPathwayTemplateItem.LearningProgramPlanRequirement.Learning_Course__r.Name,
                        LearningPathwayTemplateItem.LearningProgramPlanRequirement.Learning_Course__r.CourseNumber
                    FROM LearnerPathwayItem
                    WHERE LearnerPathway.LearnerContactId = :learnerContactId
                    ORDER BY CreatedDate DESC
                    LIMIT 500
                ];
            }
            
            for (LearnerPathwayItem item : items) {
                CourseDTO dto = new CourseDTO();
                dto.learningPathwayTemplateItemId = item.LearningPathwayTemplateItemId;
                dto.academicSessionId = item.AcademicSessionId;
                dto.sequence = parseInteger(item.SequenceNumber);
                dto.courseType = item.Type;
                dto.enrollmentStatus = (String) item.get('Enrollment_Status__c');
                dto.credits = parseInteger(item.Duration);
                if (dto.credits == null) {
                    dto.credits = 0;
                }
                
                dto.learningPathwayTemplateId =
                    item.LearningPathwayTemplateItem == null
                    ? null
                    : item.LearningPathwayTemplateItem.LearningPathwayTemplateId;
                
                String pathwayLabel =
                    item.LearnerPathway == null || String.isBlank(item.LearnerPathway.Name)
                    ? null
                    : item.LearnerPathway.Name;
                String templateLabel =
                    item.LearningPathwayTemplateItem == null ||
                    item.LearningPathwayTemplateItem.LearningPathwayTemplate == null
                    ? null
                    : item.LearningPathwayTemplateItem.LearningPathwayTemplate.Name;
                dto.learningPathwayTemplateName = String.isNotBlank(pathwayLabel) ? pathwayLabel : templateLabel;
                
                String courseNameFromTemplate =
                    item.LearningPathwayTemplateItem == null ||
                    item.LearningPathwayTemplateItem.LearningProgramPlanRequirement == null ||
                    item.LearningPathwayTemplateItem.LearningProgramPlanRequirement.Learning_Course__r == null
                    ? null
                    : item.LearningPathwayTemplateItem.LearningProgramPlanRequirement.Learning_Course__r.Name;
                String courseCodeFromTemplate =
                    item.LearningPathwayTemplateItem == null ||
                    item.LearningPathwayTemplateItem.LearningProgramPlanRequirement == null ||
                    item.LearningPathwayTemplateItem.LearningProgramPlanRequirement.Learning_Course__r == null
                    ? null
                    : item.LearningPathwayTemplateItem.LearningProgramPlanRequirement.Learning_Course__r.CourseNumber;
                
                dto.courseName = String.isNotBlank(courseNameFromTemplate)
                    ? courseNameFromTemplate
                    : (item.Learning == null ? null : item.Learning.Name);
                dto.courseCode = courseCodeFromTemplate;
                dto.learningCourseId = item.LearningId;
                result.add(dto);
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to get after enrollment details: ' +
                (e == null ? 'Unknown error' : e.getMessage())
                );
        }
    }
    
    @AuraEnabled
    public static List<Id> enrollInPathways(List<Id> learningPathwayTemplateIds) {
        try {
            List<Id> resultIds = new List<Id>();
            if (learningPathwayTemplateIds == null || learningPathwayTemplateIds.isEmpty()) {
                return resultIds;
            }
            
            Id learnerContactId = resolveLearnerContactId();
            if (learnerContactId == null) {
                throw new AuraHandledException('Current user does not have an associated learner contact.');
            }
            
            List<LearningPathwayTemplate> templates = [
                SELECT Id, Name
                FROM LearningPathwayTemplate
                WHERE Id IN :learningPathwayTemplateIds
            ];
            if (templates.isEmpty()) {
                return resultIds;
            }
            
            Set<String> templateNames = new Set<String>();
            for (LearningPathwayTemplate templateRow : templates) {
                if (String.isNotBlank(templateRow.Name)) {
                    templateNames.add(templateRow.Name.trim());
                }
            }
            
            Map<String, LearnerPathway> existingByName = new Map<String, LearnerPathway>();
            if (!templateNames.isEmpty()) {
                for (LearnerPathway existing : [
                    SELECT Id, Name
                    FROM LearnerPathway
                    WHERE LearnerContactId = :learnerContactId
                    AND Name IN :templateNames
                ]) {
                    if (String.isNotBlank(existing.Name)) {
                        existingByName.put(existing.Name.trim().toLowerCase(), existing);
                    }
                }
            }
            
            List<LearnerPathway> toInsert = new List<LearnerPathway>();
            for (LearningPathwayTemplate templateRow : templates) {
                if (String.isBlank(templateRow.Name)) {
                    continue;
                }
                String templateName = templateRow.Name.trim();
                String templateNameKey = templateName.toLowerCase();
                LearnerPathway existing = existingByName.get(templateNameKey);
                if (existing != null) {
                    resultIds.add(existing.Id);
                    continue;
                }
                LearnerPathway pathway = new LearnerPathway();
                pathway.Name = templateName;
                pathway.LearnerContactId = learnerContactId;
                pathway.Status = 'Draft';
                toInsert.add(pathway);
            }
            
            if (!toInsert.isEmpty()) {
                insert toInsert;
                for (LearnerPathway insertedPathway : toInsert) {
                    resultIds.add(insertedPathway.Id);
                }
            }
            return resultIds;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to enroll pathways: ' +
                (e == null ? 'Unknown error' : e.getMessage())
                );
        }
    }
    
    @AuraEnabled
    public static EnrollmentSubmissionResultDTO createLearnerPathwayItems(List<LearnerPathwayItemRequestDTO> requests) {
        try {
            EnrollmentSubmissionResultDTO result = new EnrollmentSubmissionResultDTO();
            result.learnerPathwayItemIds = new List<Id>();
            result.enrolledCount = 0;
            result.waitlistedCount = 0;
            result.skippedCount = 0;
            if (requests == null || requests.isEmpty()) {
                throw new AuraHandledException('No learner pathway item requests were received.');
            }
            System.debug(LoggingLevel.INFO,
            'createLearnerPathwayItems: requestCount=' + requests.size() +
                ', firstRequest=' + JSON.serialize(requests[0])
                );
            
            Id learnerContactId = resolveLearnerContactId();
            if (learnerContactId == null) {
                throw new AuraHandledException('Current user does not have an associated learner contact.');
            }
            System.debug(LoggingLevel.INFO,
            'createLearnerPathwayItems: learnerContactId=' + learnerContactId
                );
            
            Set<Id> templateIds = new Set<Id>();
            Set<Id> courseIds = new Set<Id>();
            Set<Id> learnerPathwayIds = new Set<Id>();
            Set<Id> requestedCourseOfferingIds = new Set<Id>();
            List<LearnerPathwayItemRequestDTO> normalizedRequests = new List<LearnerPathwayItemRequestDTO>();
            for (LearnerPathwayItemRequestDTO req : requests) {
                if (req == null) {
                    continue;
                }
                normalizedRequests.add(req);
                if (req.learningPathwayTemplateId != null) {
                    templateIds.add(req.learningPathwayTemplateId);
                }
                if (req.learningCourseId != null) {
                    courseIds.add(req.learningCourseId);
                }
                if (req.learnerPathwayId != null) {
                    learnerPathwayIds.add(req.learnerPathwayId);
                }
                if (req.courseOfferingId != null) {
                    requestedCourseOfferingIds.add(req.courseOfferingId);
                }
            }
            if (normalizedRequests.isEmpty()) {
                throw new AuraHandledException('No valid learner pathway item requests were received.');
            }
            validateDuplicateCourseEnrollment(normalizedRequests, learnerContactId);
            System.debug(LoggingLevel.INFO,
            'createLearnerPathwayItems: collectedIds templateIds=' + templateIds.size() +
                ', templateItemIds(pending)=' + 'NA' +
                ', courseIds=' + courseIds.size() +
                ', learnerPathwayIds=' + learnerPathwayIds.size()
                );
            Set<Id> templateItemIds = new Set<Id>();
            for (LearnerPathwayItemRequestDTO req : normalizedRequests) {
                if (req != null && req.learningPathwayTemplateItemId != null) {
                    templateItemIds.add(req.learningPathwayTemplateItemId);
                }
            }
            System.debug(LoggingLevel.INFO,
            'createLearnerPathwayItems: templateItemIds=' + templateItemIds.size()
                );
            
            Map<Id, Id> templateIdByLearnerPathwayId = new Map<Id, Id>();
            if (!learnerPathwayIds.isEmpty()) {
                Map<Id, LearnerPathway> learnerPathwayById = new Map<Id, LearnerPathway>([
                    SELECT Id, Name
                    FROM LearnerPathway
                    WHERE Id IN :learnerPathwayIds
                    AND LearnerContactId = :learnerContactId
                ]);
                Set<String> learnerPathwayNames = new Set<String>();
                for (LearnerPathway lp : learnerPathwayById.values()) {
                    if (String.isNotBlank(lp.Name)) {
                        learnerPathwayNames.add(lp.Name.trim());
                    }
                }
                System.debug(LoggingLevel.INFO,
                'createLearnerPathwayItems: learnerPathwayById=' + learnerPathwayById.keySet() +
                    ', learnerPathwayNames=' + learnerPathwayNames
                    );
                Map<String, Id> templateIdByNameKey = new Map<String, Id>();
                if (!learnerPathwayNames.isEmpty()) {
                    for (LearningPathwayTemplate tmpl : [
                        SELECT Id, Name
                        FROM LearningPathwayTemplate
                        WHERE Name IN :learnerPathwayNames
                    ]) {
                        if (String.isNotBlank(tmpl.Name)) {
                            templateIdByNameKey.put(tmpl.Name.trim().toLowerCase(), tmpl.Id);
                        }
                    }
                }
                System.debug(LoggingLevel.INFO,
                'createLearnerPathwayItems: templateIdByNameKeySize=' + templateIdByNameKey.size()
                    );
                for (Id lpId : learnerPathwayById.keySet()) {
                    LearnerPathway lp = learnerPathwayById.get(lpId);
                    if (lp == null || String.isBlank(lp.Name)) {
                        continue;
                    }
                    Id mappedTemplateId = templateIdByNameKey.get(lp.Name.trim().toLowerCase());
                    if (mappedTemplateId != null) {
                        templateIdByLearnerPathwayId.put(lpId, mappedTemplateId);
                        templateIds.add(mappedTemplateId);
                    }
                }
                System.debug(LoggingLevel.INFO,
                'createLearnerPathwayItems: templateIdByLearnerPathwayId=' + templateIdByLearnerPathwayId
                    );
            }
            
            for (LearnerPathwayItemRequestDTO req : normalizedRequests) {
                if (req == null || req.learningPathwayTemplateId != null || req.learnerPathwayId == null) {
                    continue;
                }
                req.learningPathwayTemplateId = templateIdByLearnerPathwayId.get(req.learnerPathwayId);
            }
            // Always prioritize server-side mapping by LearnerPathway.Name -> LearningPathwayTemplate.Name.
            // This avoids mismatches when client passes a stale or incorrect template id.
            for (LearnerPathwayItemRequestDTO req : normalizedRequests) {
                if (req == null || req.learnerPathwayId == null) {
                    continue;
                }
                Id mappedTemplateId = templateIdByLearnerPathwayId.get(req.learnerPathwayId);
                if (mappedTemplateId != null) {
                    req.learningPathwayTemplateId = mappedTemplateId;
                    templateIds.add(mappedTemplateId);
                }
            }
            System.debug(LoggingLevel.INFO,
            'createLearnerPathwayItems: templateIds after mapping=' + templateIds +
                ', templateItemIds=' + templateItemIds
                );
            
            if (templateIds.isEmpty() && templateItemIds.isEmpty()) {
                System.debug(LoggingLevel.ERROR,
                'createLearnerPathwayItems: no valid ids. requestPayload=' + JSON.serialize(requests)
                    );
                throw new AuraHandledException('No valid template/template-item ids found in request.');
            }
            
            Map<Id, LearningPathwayTemplate> templateById = new Map<Id, LearningPathwayTemplate>([
                SELECT Id, Name
                FROM LearningPathwayTemplate
                WHERE Id IN :templateIds
            ]);
            
            Map<Id, Id> learnerPathwayIdByTemplateId = new Map<Id, Id>();
            Set<String> templateNames = new Set<String>();
            for (LearningPathwayTemplate tmpl : templateById.values()) {
                if (String.isNotBlank(tmpl.Name)) {
                    templateNames.add(tmpl.Name.trim());
                }
            }
            Map<String, LearnerPathway> existingPathwayByNameKey = new Map<String, LearnerPathway>();
            if (!templateNames.isEmpty()) {
                for (LearnerPathway existingPathway : [
                    SELECT Id, Name
                    FROM LearnerPathway
                    WHERE LearnerContactId = :learnerContactId
                    AND Name IN :templateNames
                ]) {
                    if (String.isNotBlank(existingPathway.Name)) {
                        existingPathwayByNameKey.put(existingPathway.Name.trim().toLowerCase(), existingPathway);
                    }
                }
            }
            
            for (Id templateId : templateById.keySet()) {
                LearningPathwayTemplate tmpl = templateById.get(templateId);
                if (tmpl == null || String.isBlank(tmpl.Name)) {
                    continue;
                }
                String key = tmpl.Name.trim().toLowerCase();
                LearnerPathway existing = existingPathwayByNameKey.get(key);
                if (existing != null) {
                    learnerPathwayIdByTemplateId.put(templateId, existing.Id);
                }
            }
            
            List<LearnerPathway> pathwaysToInsert = new List<LearnerPathway>();
            for (Id templateId : templateById.keySet()) {
                if (learnerPathwayIdByTemplateId.containsKey(templateId)) {
                    continue;
                }
                LearningPathwayTemplate tmpl = templateById.get(templateId);
                if (tmpl == null || String.isBlank(tmpl.Name)) {
                    continue;
                }
                LearnerPathway pathway = new LearnerPathway();
                pathway.Name = tmpl.Name.trim();
                pathway.LearnerContactId = learnerContactId;
                pathway.Status = 'Draft';
                pathwaysToInsert.add(pathway);
            }
            if (!pathwaysToInsert.isEmpty()) {
                insert pathwaysToInsert;
                for (LearnerPathway insertedPathway : pathwaysToInsert) {
                    String key = String.isBlank(insertedPathway.Name) ? null : insertedPathway.Name.trim().toLowerCase();
                    if (key != null) {
                        existingPathwayByNameKey.put(key, insertedPathway);
                    }
                }
                for (Id templateId : templateById.keySet()) {
                    if (learnerPathwayIdByTemplateId.containsKey(templateId)) {
                        continue;
                    }
                    LearningPathwayTemplate tmpl = templateById.get(templateId);
                    if (tmpl == null || String.isBlank(tmpl.Name)) {
                        continue;
                    }
                    LearnerPathway insertedPathway = existingPathwayByNameKey.get(tmpl.Name.trim().toLowerCase());
                    if (insertedPathway != null) {
                        learnerPathwayIdByTemplateId.put(templateId, insertedPathway.Id);
                    }
                }
            }
            
            Map<Id, LearningPathwayTemplateItem> templateItemById = new Map<Id, LearningPathwayTemplateItem>();
            if (!templateItemIds.isEmpty()) {
                for (LearningPathwayTemplateItem item : [
                    SELECT Id,
                        Type,
                        Year,
                        Season,
                        SequenceNumber,
                        Sequence__c,
                        LearningProgramPlanRequirementId,
                        LearningProgramPlanRequirement.Name,
                        LearningProgramPlanRequirement.Learning_Course__c,
                        LearningProgramPlanRequirement.Learning_Course__r.Duration,
                        LearningProgramPlanRequirement.Learning_Course__r.DurationUnit,
                        LearningProgramPlanRequirement.Learning_Course__r.LearningId,
                        LearningPathwayTemplateId
                    FROM LearningPathwayTemplateItem
                    WHERE Id IN :templateItemIds
                ]) {
                    templateItemById.put(item.Id, item);
                    if (item.LearningPathwayTemplateId != null) {
                        templateIds.add(item.LearningPathwayTemplateId);
                    }
                }
            }
            
            Map<String, LearningPathwayTemplateItem> templateItemByTemplateAndCourse = new Map<String, LearningPathwayTemplateItem>();
            if (!templateIds.isEmpty() && !courseIds.isEmpty()) {
                for (LearningPathwayTemplateItem item : [
                    SELECT Id,
                        Type,
                        Year,
                        Season,
                        SequenceNumber,
                        Sequence__c,
                        LearningProgramPlanRequirementId,
                        LearningProgramPlanRequirement.Name,
                        LearningProgramPlanRequirement.Learning_Course__c,
                        LearningProgramPlanRequirement.Learning_Course__r.Duration,
                        LearningProgramPlanRequirement.Learning_Course__r.DurationUnit,
                        LearningProgramPlanRequirement.Learning_Course__r.LearningId,
                        LearningPathwayTemplateId
                    FROM LearningPathwayTemplateItem
                    WHERE LearningPathwayTemplateId IN :templateIds
                    AND LearningProgramPlanRequirement.Learning_Course__c IN :courseIds
                ]) {
                    if (item.LearningProgramPlanRequirement == null || item.LearningProgramPlanRequirement.Learning_Course__c == null) {
                        continue;
                    }
                    String itemKey = String.valueOf(item.LearningPathwayTemplateId) + '::' +
                        String.valueOf(item.LearningProgramPlanRequirement.Learning_Course__c);
                    if (!templateItemByTemplateAndCourse.containsKey(itemKey)) {
                        templateItemByTemplateAndCourse.put(itemKey, item);
                    }
                }
            }
            
            Map<String, Schema.SObjectField> lpiFields = LearnerPathwayItem.SObjectType.getDescribe().fields.getMap();
            Map<String, Schema.SObjectField> lprFields = LearnerProgramRequirement.SObjectType.getDescribe().fields.getMap();
            EnrollmentDmlService dmlService = new EnrollmentDmlService();
            List<LearnerProgram> learnerPrograms = dmlService.getLearnerProgramsForContact(learnerContactId);
            if (learnerPrograms.isEmpty()) {
                throw new AuraHandledException('No Learner Program found for current learner.');
            }
            LearnerProgram learnerProgramRecord = learnerPrograms[0];
            for (LearnerProgram lp : learnerPrograms) {
                String statusVal = lp.Status == null ? '' : lp.Status.trim().toLowerCase();
                if (statusVal == 'enrolled' || statusVal == 'active' || statusVal == 'current') {
                    learnerProgramRecord = lp;
                    break;
                }
            }
            
            Set<Id> pathwayIdsToCheck = new Set<Id>();
            Set<Id> templateItemIdsToCheck = new Set<Id>();
            List<EnrollmentDecision> enrollmentDecisions = classifyEnrollmentRequests(normalizedRequests, requestedCourseOfferingIds);
            List<LearnerPathwayItemRequestDTO> requestsForLearnerPathwayItems = new List<LearnerPathwayItemRequestDTO>();
            List<LearnerPathwayItemRequestDTO> requestsForParticipants = new List<LearnerPathwayItemRequestDTO>();
            Map<Id, String> participationStatusByOfferingId = new Map<Id, String>();
            for (EnrollmentDecision decision : enrollmentDecisions) {
                if (decision == null || decision.request == null) {
                    continue;
                }
                requestsForParticipants.add(decision.request);
                if (decision.request.courseOfferingId != null && String.isNotBlank(decision.participationStatus)) {
                    participationStatusByOfferingId.put(decision.request.courseOfferingId, decision.participationStatus);
                }
                if (decision.shouldCreateLearnerPathwayItem == true) {
                    requestsForLearnerPathwayItems.add(decision.request);
                    if (KenConstantController.STATUS_ENROLLED == decision.participationStatus || decision.request.courseOfferingId == null) {
                        result.enrolledCount++;
                    }
                } else {
                    result.skippedCount++;
                    if (KenConstantController.STATUS_WAITLISTED == decision.participationStatus) {
                        result.waitlistedCount++;
                    }
                }
            }
            
            for (LearnerPathwayItemRequestDTO req : requestsForLearnerPathwayItems) {
                if (req == null || req.learningPathwayTemplateId == null || req.learningCourseId == null) {
                    continue;
                }
                Id pathwayId = req.learnerPathwayId;
                if (pathwayId == null) {
                    pathwayId = learnerPathwayIdByTemplateId.get(req.learningPathwayTemplateId);
                }
                LearningPathwayTemplateItem matchedItem = req.learningPathwayTemplateItemId == null
                    ? null
                    : templateItemById.get(req.learningPathwayTemplateItemId);
                if (matchedItem == null && req.learningPathwayTemplateId != null && req.learningCourseId != null) {
                    matchedItem = templateItemByTemplateAndCourse.get(
                        String.valueOf(req.learningPathwayTemplateId) + '::' + String.valueOf(req.learningCourseId)
                        );
                }
                if (pathwayId != null && matchedItem != null) {
                    pathwayIdsToCheck.add(pathwayId);
                    templateItemIdsToCheck.add(matchedItem.Id);
                }
            }
            
            Set<String> existingKeys = new Set<String>();
            if (lpiFields.containsKey('LearnerPathwayId') &&
                lpiFields.containsKey('LearningPathwayTemplateItemId') &&
                !pathwayIdsToCheck.isEmpty() &&
            !templateItemIdsToCheck.isEmpty()) {
                String existingSoql =
                    'SELECT Id, LearnerPathwayId, LearningPathwayTemplateItemId ' +
                    'FROM LearnerPathwayItem ' +
                    'WHERE LearnerPathwayId IN :pathwayIdsToCheck ' +
                    'AND LearningPathwayTemplateItemId IN :templateItemIdsToCheck';
                for (SObject row : Database.query(existingSoql)) {
                    Id existingPathwayId = (Id) row.get('LearnerPathwayId');
                    Id existingTemplateItemId = (Id) row.get('LearningPathwayTemplateItemId');
                    if (existingPathwayId != null && existingTemplateItemId != null) {
                        existingKeys.add(String.valueOf(existingPathwayId) + '::' + String.valueOf(existingTemplateItemId));
                    }
                }
            }
            
            List<SObject> toInsert = new List<SObject>();
            List<String> enrollmentStatusesInOrder = new List<String>();
            List<Map<String, Object>> pendingRows = new List<Map<String, Object>>();
            Set<String> preparedKeys = new Set<String>();
            Integer skippedMissingTemplateOrCourse = 0;
            Integer skippedTemplateItemNotFound = 0;
            Integer skippedPathwayNotFound = 0;
            Integer skippedDuplicate = 0;
            Integer skippedLprNotCreatedOrMapped = 0;
            for (LearnerPathwayItemRequestDTO req : requestsForLearnerPathwayItems) {
                if (req == null ||
                (req.learningPathwayTemplateItemId == null && (req.learningPathwayTemplateId == null || req.learningCourseId == null))) {
                    skippedMissingTemplateOrCourse++;
                    continue;
                }
                LearningPathwayTemplateItem item = req.learningPathwayTemplateItemId == null
                    ? null
                    : templateItemById.get(req.learningPathwayTemplateItemId);
                if (item == null && req.learningPathwayTemplateId != null && req.learningCourseId != null) {
                    item = templateItemByTemplateAndCourse.get(
                        String.valueOf(req.learningPathwayTemplateId) + '::' + String.valueOf(req.learningCourseId)
                        );
                }
                if (item == null || item.LearningProgramPlanRequirement == null) {
                    skippedTemplateItemNotFound++;
                    continue;
                }
                Id pathwayId = req.learnerPathwayId;
                if (pathwayId == null) {
                    pathwayId = learnerPathwayIdByTemplateId.get(
                        req.learningPathwayTemplateId == null ? item.LearningPathwayTemplateId : req.learningPathwayTemplateId
                        );
                }
                if (pathwayId == null) {
                    skippedPathwayNotFound++;
                    continue;
                }
                
                String dedupeKey = String.valueOf(pathwayId) + '::' + String.valueOf(item.Id);
                if (existingKeys.contains(dedupeKey) || preparedKeys.contains(dedupeKey)) {
                    skippedDuplicate++;
                    continue;
                }
                
                pendingRows.add(new Map<String, Object>{
                    'pathwayId' => pathwayId,
                    'item' => item,
                    'req' => req
                });
                preparedKeys.add(dedupeKey);
            }
            
            Set<Id> planRequirementIds = new Set<Id>();
            Map<Id, String> planRequirementNameById = new Map<Id, String>();
            for (Map<String, Object> pending : pendingRows) {
                LearningPathwayTemplateItem pendingItem = (LearningPathwayTemplateItem) pending.get('item');
                if (pendingItem != null && pendingItem.LearningProgramPlanRequirementId != null) {
                    planRequirementIds.add(pendingItem.LearningProgramPlanRequirementId);
                    if (pendingItem.LearningProgramPlanRequirement != null &&
                        String.isNotBlank(pendingItem.LearningProgramPlanRequirement.Name) &&
                    !planRequirementNameById.containsKey(pendingItem.LearningProgramPlanRequirementId)) {
                        planRequirementNameById.put(
                            pendingItem.LearningProgramPlanRequirementId,
                        pendingItem.LearningProgramPlanRequirement.Name
                            );
                    }
                }
            }
            
            Map<Id, Id> lprIdByPlanRequirementId = new Map<Id, Id>();
            List<String> lprInsertErrors = new List<String>();
            if (!planRequirementIds.isEmpty()) {
                // Reuse existing requirements for this learner across any learner program.
                for (LearnerProgramRequirement existingLpr : dmlService.getExistingProgramRequirements(
                    learnerContactId,
                planRequirementIds
                )) {
                    if (existingLpr.LearningProgramPlanRqmtId != null) {
                        if (!lprIdByPlanRequirementId.containsKey(existingLpr.LearningProgramPlanRqmtId)) {
                            lprIdByPlanRequirementId.put(existingLpr.LearningProgramPlanRqmtId, existingLpr.Id);
                        }
                    }
                }
                
                List<SObject> lprToInsert = new List<SObject>();
                List<Id> lprPlanRequirementIdsInOrder = new List<Id>();
                for (Id planRequirementId : planRequirementIds) {
                    if (lprIdByPlanRequirementId.containsKey(planRequirementId)) {
                        continue;
                    }
                    SObject lpr = LearnerProgramRequirement.SObjectType.newSObject();
                    setFieldIfCreatable(lpr, lprFields, 'LearningProgramPlanRqmtId', planRequirementId);
                    setFieldIfCreatable(lpr, lprFields, 'LearnerProgramId', learnerProgramRecord.Id);
                    setFieldIfCreatable(lpr, lprFields, 'Status', 'Active');
                    String planRequirementName = planRequirementNameById.get(planRequirementId);
                    String lprName = String.isNotBlank(planRequirementName)
                        ? learnerProgramRecord.Name + ' - ' + planRequirementName
                        : learnerProgramRecord.Name;
                    setFieldIfCreatable(lpr, lprFields, 'Name', lprName);
                    lprToInsert.add(lpr);
                    lprPlanRequirementIdsInOrder.add(planRequirementId);
                }
                if (!lprToInsert.isEmpty()) {
                    Database.SaveResult[] lprResults = dmlService.insertRowsPartial(lprToInsert);
                    for (Integer i = 0; i < lprResults.size(); i++) {
                        Database.SaveResult sr = lprResults[i];
                        Id planRequirementId = i < lprPlanRequirementIdsInOrder.size() ? lprPlanRequirementIdsInOrder[i] : null;
                        if (sr != null && sr.isSuccess()) {
                            if (planRequirementId != null) {
                                lprIdByPlanRequirementId.put(planRequirementId, sr.getId());
                            }
                        } else if (sr != null && sr.getErrors() != null && !sr.getErrors().isEmpty()) {
                            String errMsg = sr.getErrors()[0].getMessage();
                            System.debug(
                                LoggingLevel.ERROR,
                            'createLearnerPathwayItems: LPR insert failed for planRequirementId=' + planRequirementId +
                                ', error=' + errMsg
                                );
                            lprInsertErrors.add('PlanRequirementId=' + planRequirementId + ': ' + errMsg);
                        }
                    }
                }
            }
            
            for (Map<String, Object> pending : pendingRows) {
                Id pathwayId = (Id) pending.get('pathwayId');
                LearningPathwayTemplateItem item = (LearningPathwayTemplateItem) pending.get('item');
                LearnerPathwayItemRequestDTO req = (LearnerPathwayItemRequestDTO) pending.get('req');
                if (pathwayId == null || item == null) {
                    continue;
                }
                Id mappedLprId = lprIdByPlanRequirementId.get(item.LearningProgramPlanRequirementId);
                if (mappedLprId == null) {
                    skippedLprNotCreatedOrMapped++;
                    continue;
                }
                
                SObject learnerPathwayItem = LearnerPathwayItem.SObjectType.newSObject();
                setFieldIfCreatable(learnerPathwayItem, lpiFields, 'LearnerPathwayId', pathwayId);
                setFieldIfCreatable(
                    learnerPathwayItem,
                lpiFields,
                'LearnerProgramRequirementId',
                mappedLprId
                    );
                setFieldIfCreatable(
                    learnerPathwayItem,
                lpiFields,
                'LearningProgramPlanRequirementId',
                item.LearningProgramPlanRequirementId
                    );
                setFieldIfCreatable(learnerPathwayItem, lpiFields, 'Type', item.Type);
                String enrollmentStatusValue = resolveEnrollmentStatusValue(lpiFields, item);
                setFieldIfCreatable(learnerPathwayItem, lpiFields, 'Enrollment_Status__c', enrollmentStatusValue);
                if (req != null && req.courseOfferingId != null) {
                    String existingParticipationStatus = participationStatusByOfferingId.get(req.courseOfferingId);
                    if (String.isBlank(existingParticipationStatus) ||
                    existingParticipationStatus == KenConstantController.STATUS_ENROLLED) {
                        String normalizedEnrollmentStatus = enrollmentStatusValue == null
                            ? ''
                            : enrollmentStatusValue.trim().toLowerCase();
                        if (normalizedEnrollmentStatus == 'in review') {
                            participationStatusByOfferingId.put(req.courseOfferingId, 'In Review');
                        }
                    }
                }
                System.debug(
                    LoggingLevel.INFO,
                'createLearnerPathwayItems: setting Enrollment_Status__c=' + enrollmentStatusValue +
                    ', fieldPresent=' + lpiFields.containsKey('Enrollment_Status__c')
                    );
                setFieldIfCreatable(learnerPathwayItem, lpiFields, 'Season', item.Season);
                setFieldIfCreatable(learnerPathwayItem, lpiFields, 'Year', item.Year);
                setFieldIfCreatable(learnerPathwayItem, lpiFields, 'AcademicSessionId', req == null ? null : req.academicSessionId);
                setFieldIfCreatable(learnerPathwayItem, lpiFields, 'LearningPathwayTemplateItemId', item.Id);
                
                Id learningId =
                    item.LearningProgramPlanRequirement.Learning_Course__r == null
                    ? null
                    : item.LearningProgramPlanRequirement.Learning_Course__r.LearningId;
                Object duration =
                    item.LearningProgramPlanRequirement.Learning_Course__r == null
                    ? null
                    : item.LearningProgramPlanRequirement.Learning_Course__r.Duration;
                String durationUnit =
                    item.LearningProgramPlanRequirement.Learning_Course__r == null
                    ? null
                    : item.LearningProgramPlanRequirement.Learning_Course__r.DurationUnit;
                setFieldIfCreatable(learnerPathwayItem, lpiFields, 'LearningId', learningId);
                setFieldIfCreatable(learnerPathwayItem, lpiFields, 'Duration', duration);
                setFieldIfCreatable(learnerPathwayItem, lpiFields, 'DurationUnit', durationUnit);
                
                Integer sequenceVal = parseInteger(item.Sequence__c);
                if (sequenceVal == null) {
                    sequenceVal = parseInteger(item.SequenceNumber);
                }
                if (lpiFields.containsKey('SequenceNumber') && sequenceVal != null) {
                    learnerPathwayItem.put('SequenceNumber', sequenceVal);
                } else if (lpiFields.containsKey('Sequence__c') && sequenceVal != null) {
                    learnerPathwayItem.put('Sequence__c', String.valueOf(sequenceVal));
                }
                
                toInsert.add(learnerPathwayItem);
                enrollmentStatusesInOrder.add(enrollmentStatusValue);
            }
            
            if (!toInsert.isEmpty()) {
                dmlService.insertRows(toInsert);
                for (Integer i = 0; i < toInsert.size(); i++) {
                    Id createdId = (Id) toInsert[i].get('Id');
                    if (createdId != null) {
                        result.learnerPathwayItemIds.add(createdId);
                    }
                }
                if (lpiFields.containsKey('Enrollment_Status__c') && !result.learnerPathwayItemIds.isEmpty()) {
                    List<SObject> lpiUpdates = new List<SObject>();
                    for (Integer i = 0; i < toInsert.size(); i++) {
                        Id createdId = (Id) toInsert[i].get('Id');
                        if (createdId == null) {
                            continue;
                        }
                        SObject lpiUpdate = new LearnerPathwayItem(Id = createdId);
                        String enrollmentStatusValue = i < enrollmentStatusesInOrder.size()
                            ? enrollmentStatusesInOrder[i]
                            : resolvePicklistValue(lpiFields, 'Enrollment_Status__c', 'In Review');
                        setFieldIfCreatable(lpiUpdate, lpiFields, 'Enrollment_Status__c', enrollmentStatusValue);
                        lpiUpdates.add(lpiUpdate);
                    }
                    dmlService.updateRows(lpiUpdates);
                }
                upsertCourseOfferingParticipants(
                    requestsForParticipants,
                requestedCourseOfferingIds,
                learnerContactId,
                dmlService,
                participationStatusByOfferingId
                    );
                markEnrollmentSelectionComplete(normalizedRequests, learnerContactId, dmlService);
            } else if (!requestsForParticipants.isEmpty()) {
                upsertCourseOfferingParticipants(
                    requestsForParticipants,
                requestedCourseOfferingIds,
                learnerContactId,
                dmlService,
                participationStatusByOfferingId
                    );
                markEnrollmentSelectionComplete(normalizedRequests, learnerContactId, dmlService);
            } else {
                throw new AuraHandledException(
                    'No learner pathway items were created. ' +
                    'Request Count=' + normalizedRequests.size() +
                    ', Missing Template/Course=' + skippedMissingTemplateOrCourse +
                    ', Template Item Not Found=' + skippedTemplateItemNotFound +
                    ', Pathway Not Resolved=' + skippedPathwayNotFound +
                    ', Already Exists=' + skippedDuplicate +
                    ', LPR Not Created/Mapped=' + skippedLprNotCreatedOrMapped +
                    (lprInsertErrors.isEmpty() ? '' : ', LPR Errors=' + String.join(lprInsertErrors, ' | '))
                    );
            }
            result.message = buildEnrollmentSubmissionMessage(result.enrolledCount, result.waitlistedCount);
            return result;
        } catch (Exception e) {
            if (e instanceof AuraHandledException) {
                throw (AuraHandledException) e;
            }
            throw new AuraHandledException(
                'Failed to create learner pathway items: ' +
                (e == null ? 'Unknown error' : e.getMessage())
                );
        }
    }
    
    private static void upsertCourseOfferingParticipants(
        List<LearnerPathwayItemRequestDTO> requests,
    Set<Id> requestedCourseOfferingIds,
    Id learnerContactId,
    EnrollmentDmlService dmlService,
    Map<Id, String> participationStatusByOfferingId
    ) {
        if (requests == null || requests.isEmpty() || requestedCourseOfferingIds == null || requestedCourseOfferingIds.isEmpty() || learnerContactId == null) {
            return;
        }
        
        Contact learnerContact = dmlService.getContactById(learnerContactId);
        Id learnerAccountId = learnerContact == null ? null : learnerContact.AccountId;
        
        Map<Id, CourseOffering> offeringById = new Map<Id, CourseOffering>();
        Set<Id> academicTermIds = new Set<Id>();
        for (CourseOffering offering : [
            SELECT Id, AcademicSessionId, AcademicSession.AcademicTermId
            FROM CourseOffering
            WHERE Id IN :requestedCourseOfferingIds
        ]) {
            offeringById.put(offering.Id, offering);
            if (offering.AcademicSession != null && offering.AcademicSession.AcademicTermId != null) {
                academicTermIds.add(offering.AcademicSession.AcademicTermId);
            }
        }
        if (offeringById.isEmpty() || academicTermIds.isEmpty()) {
            return;
        }
        
        Map<Id, AcademicTermEnrollment> ateByTermId = dmlService.getAcademicTermEnrollmentsByTermId(learnerContactId, academicTermIds);
        if (ateByTermId.isEmpty()) {
            return;
        }
        
        Set<Id> existingOfferingIds = new Set<Id>();
        for (CourseOfferingParticipant participant : dmlService.getExistingCourseOfferingParticipants(learnerContactId, requestedCourseOfferingIds)) {
            if (participant.CourseOfferingId != null) {
                existingOfferingIds.add(participant.CourseOfferingId);
            }
        }
        
        Map<String, Schema.SObjectField> copFields = CourseOfferingParticipant.SObjectType.getDescribe().fields.getMap();
        List<SObject> participantsToInsert = new List<SObject>();
        Set<Id> preparedOfferingIds = new Set<Id>();
        for (LearnerPathwayItemRequestDTO req : requests) {
            if (req == null || req.courseOfferingId == null) {
                continue;
            }
            if (existingOfferingIds.contains(req.courseOfferingId) || preparedOfferingIds.contains(req.courseOfferingId)) {
                continue;
            }
            
            CourseOffering offering = offeringById.get(req.courseOfferingId);
            if (offering == null || offering.AcademicSession == null || offering.AcademicSession.AcademicTermId == null) {
                continue;
            }
            
            AcademicTermEnrollment ate = ateByTermId.get(offering.AcademicSession.AcademicTermId);
            if (ate == null) {
                continue;
            }
            
            SObject participant = CourseOfferingParticipant.SObjectType.newSObject();
            setFieldIfCreatable(participant, copFields, 'ParticipantAffiliation', KenConstantController.ROLETYPE_STUDENT);
            setFieldIfCreatable(participant, copFields, 'ParticipantContactId', learnerContactId);
            setFieldIfCreatable(participant, copFields, 'ParticipantAccountId', learnerAccountId);
            setFieldIfCreatable(participant, copFields, 'CourseOfferingId', req.courseOfferingId);
            setFieldIfCreatable(participant, copFields, 'AcademicTermEnrollmentId', ate.Id);
            String participationStatus = participationStatusByOfferingId == null
                ? null
                : participationStatusByOfferingId.get(req.courseOfferingId);
            if (String.isBlank(participationStatus)) {
                participationStatus = KenConstantController.STATUS_ENROLLED;
            }
            setFieldIfCreatable(
                participant,
            copFields,
            'ParticipationStatus',
            resolvePicklistValue(copFields, 'ParticipationStatus', participationStatus)
                );
            if (KenConstantController.STATUS_WAITLISTED == participationStatus) {
                setFieldIfCreatable(participant, copFields, 'AddedToWaitlist', true);
            }
            participantsToInsert.add(participant);
            preparedOfferingIds.add(req.courseOfferingId);
        }
        
        if (!participantsToInsert.isEmpty()) {
            dmlService.insertRows(participantsToInsert);
        }
    }
    
    private static List<EnrollmentDecision> classifyEnrollmentRequests(
        List<LearnerPathwayItemRequestDTO> requests,
    Set<Id> requestedCourseOfferingIds
    ) {
        List<EnrollmentDecision> decisions = new List<EnrollmentDecision>();
        Map<Id, CourseOffering> offeringById = new Map<Id, CourseOffering>();
        Map<Id, Integer> enrolledReservedByOfferingId = new Map<Id, Integer>();
        Map<Id, Integer> waitlistReservedByOfferingId = new Map<Id, Integer>();
        
        if (requestedCourseOfferingIds != null && !requestedCourseOfferingIds.isEmpty()) {
            for (CourseOffering offering : [
                SELECT Id,
                    EnrollmentCapacity,
                    EnrolleeCount,
                    WaitlistCapacity,
                    WaitlistCount
                FROM CourseOffering
                WHERE Id IN :requestedCourseOfferingIds
            ]) {
                offeringById.put(offering.Id, offering);
            }
        }
        
        for (LearnerPathwayItemRequestDTO req : requests) {
            if (req == null) {
                continue;
            }
            EnrollmentDecision decision = new EnrollmentDecision();
            decision.request = req;
            decision.participationStatus = KenConstantController.STATUS_ENROLLED;
            decision.shouldCreateLearnerPathwayItem = true;
            
            if (req.courseOfferingId != null) {
                CourseOffering offering = offeringById.get(req.courseOfferingId);
                if (offering == null) {
                    throw new AuraHandledException('Selected course offering was not found.');
                }
                
                Integer enrollmentCapacity = parseInteger(offering.EnrollmentCapacity);
                Integer enrolleeCount = parseInteger(offering.EnrolleeCount);
                Integer waitlistCapacity = parseInteger(offering.WaitlistCapacity);
                Integer waitlistCount = parseInteger(offering.WaitlistCount);
                Integer reservedEnrolled = enrolledReservedByOfferingId.containsKey(offering.Id)
                    ? enrolledReservedByOfferingId.get(offering.Id)
                    : 0;
                Integer reservedWaitlisted = waitlistReservedByOfferingId.containsKey(offering.Id)
                    ? waitlistReservedByOfferingId.get(offering.Id)
                    : 0;
                Integer remainingSeats =
                    enrollmentCapacity == null || enrolleeCount == null
                    ? null
                    : enrollmentCapacity - enrolleeCount - reservedEnrolled;
                Integer remainingWaitlistSeats =
                    waitlistCapacity == null || waitlistCount == null
                    ? null
                    : waitlistCapacity - waitlistCount - reservedWaitlisted;
                
                if (remainingSeats == null || remainingSeats > 0) {
                    enrolledReservedByOfferingId.put(offering.Id, reservedEnrolled + 1);
                } else if (isWaitlistEnabled(offering) && remainingWaitlistSeats != null && remainingWaitlistSeats > 0) {
                    decision.participationStatus = KenConstantController.STATUS_WAITLISTED;
                    decision.shouldCreateLearnerPathwayItem = false;
                    waitlistReservedByOfferingId.put(offering.Id, reservedWaitlisted + 1);
                } else {
                    throw new AuraHandledException(
                        'No seats or waitlist slots are available for the selected course offering.'
                        );
                }
            }
            
            decisions.add(decision);
        }
        
        return decisions;
    }
    
    private static String buildEnrollmentSubmissionMessage(Integer enrolledCount, Integer waitlistedCount) {
        List<String> parts = new List<String>();
        if (enrolledCount != null && enrolledCount > 0) {
            parts.add(String.valueOf(enrolledCount) + ' course item(s) enrolled');
        }
        if (waitlistedCount != null && waitlistedCount > 0) {
            parts.add(String.valueOf(waitlistedCount) + ' course item(s) waitlisted');
        }
        if (parts.isEmpty()) {
            return 'No course items were submitted.';
        }
        return String.join(parts, '; ') + '.';
    }
    
    private static void validateDuplicateCourseEnrollment(
        List<LearnerPathwayItemRequestDTO> requests,
    Id learnerContactId
    ) {
        if (requests == null || requests.isEmpty() || learnerContactId == null) {
            return;
        }
        
        Set<Id> requestedLearningCourseIds = new Set<Id>();
        for (LearnerPathwayItemRequestDTO req : requests) {
            if (req != null && req.learningCourseId != null) {
                requestedLearningCourseIds.add(req.learningCourseId);
            }
        }
        if (requestedLearningCourseIds.isEmpty()) {
            return;
        }
        
        Map<Id, String> duplicateCourseNameById = new Map<Id, String>();
        for (CourseOfferingParticipant cop : [
            SELECT Id,
                ParticipationStatus,
                CourseOffering.LearningCourseId,
                CourseOffering.LearningCourse.Name
            FROM CourseOfferingParticipant
            WHERE ParticipantContactId = :learnerContactId
            AND CourseOffering.LearningCourseId IN :requestedLearningCourseIds
        ]) {
            Id learningCourseId = cop.CourseOffering == null ? null : cop.CourseOffering.LearningCourseId;
            if (learningCourseId == null || duplicateCourseNameById.containsKey(learningCourseId)) {
                continue;
            }
            
            String participationStatus = String.valueOf(cop.ParticipationStatus).trim().toLowerCase();
            if (participationStatus == KenConstantController.STATUS_ENROLLED.toLowerCase() ||
            participationStatus == KenConstantController.STATUS_WAITLISTED.toLowerCase()) {
                duplicateCourseNameById.put(
                    learningCourseId,
                cop.CourseOffering.LearningCourse == null || String.isBlank(cop.CourseOffering.LearningCourse.Name)
                    ? 'Course'
                    : cop.CourseOffering.LearningCourse.Name
                    );
            }
        }
        
        if (!duplicateCourseNameById.isEmpty()) {
            List<String> duplicateCourseNames = new List<String>(duplicateCourseNameById.values());
            duplicateCourseNames.sort();
            throw new AuraHandledException(
                'Enrollment is not allowed because these course(s) are already enrolled or waitlisted: ' +
                String.join(duplicateCourseNames, ', ')
                );
        }
    }
    
    private static Boolean isWaitlistEnabled(SObject offeringRow) {
        if (offeringRow == null) {
            return false;
        }
        
        Integer waitlistCapacity = parseInteger(offeringRow.get('WaitlistCapacity'));
        return waitlistCapacity != null && waitlistCapacity > 0;
    }
    
    private static void markEnrollmentSelectionComplete(
        List<LearnerPathwayItemRequestDTO> requests,
    Id learnerContactId,
    EnrollmentDmlService dmlService
    ) {
        if (requests == null || requests.isEmpty() || learnerContactId == null) {
            return;
        }
        
        Set<Id> academicSessionIdsFromRequest = new Set<Id>();
        for (LearnerPathwayItemRequestDTO req : requests) {
            if (req != null && req.academicSessionId != null) {
                academicSessionIdsFromRequest.add(req.academicSessionId);
            }
        }
        if (academicSessionIdsFromRequest.isEmpty()) {
            return;
        }
        
        Set<Id> academicTermIds = new Set<Id>();
        for (AcademicSession sessionRow : [
            SELECT Id, AcademicTermId
            FROM AcademicSession
            WHERE Id IN :academicSessionIdsFromRequest
        ]) {
            if (sessionRow.AcademicTermId != null) {
                academicTermIds.add(sessionRow.AcademicTermId);
            }
        }
        if (academicTermIds.isEmpty()) {
            return;
        }
        
        Map<String, Schema.SObjectField> ateFields = AcademicTermEnrollment.SObjectType.getDescribe().fields.getMap();
        List<SObject> ateUpdates = new List<SObject>();
        for (AcademicTermEnrollment ate : dmlService.getAcademicTermEnrollments(learnerContactId, academicTermIds)) {
            SObject ateUpdate = new AcademicTermEnrollment(Id = ate.Id);
            setFieldIfCreatable(ateUpdate, ateFields, 'IsEnrollmentSelectionCompleted__c', true);
            ateUpdates.add(ateUpdate);
        }
        if (!ateUpdates.isEmpty()) {
            dmlService.updateRows(ateUpdates);
        }
    }
    
    /**
     * @description Resolves learner contact id for current user.
     * Prefers User.ContactId, then PersonAccount.PersonContactId.
     * @return Contact Id used in learner objects.
     */
    private static Id resolveLearnerContactId() {
        if (forceExceptionInGetLearnerPathways) {
            throw new IllegalArgumentException('Test exception');
        }
        List<User> users = [
            SELECT ContactId, AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        System.debug(LoggingLevel.INFO,
        'KenPortalCourseEnrollmentController.resolveLearnerContactId: users fetched=' + users.size());
        if (users.isEmpty()) {
            System.debug(LoggingLevel.WARN,
            'KenPortalCourseEnrollmentController.resolveLearnerContactId: no user row found.');
            return null;
        }
        User u = users[0];
        System.debug(LoggingLevel.INFO,
        'KenPortalCourseEnrollmentController.resolveLearnerContactId: userContactId=' + u.ContactId +
            ', userAccountId=' + u.AccountId);
        if (u.ContactId != null) {
            System.debug(LoggingLevel.INFO,
            'KenPortalCourseEnrollmentController.resolveLearnerContactId: returning User.ContactId.');
            return u.ContactId;
        }
        if (u.AccountId == null) {
            System.debug(LoggingLevel.WARN,
            'KenPortalCourseEnrollmentController.resolveLearnerContactId: accountId is null and contactId is null.');
            return null;
        }
        
        if (!Schema.SObjectType.Account.isAccessible() ||
        !Schema.SObjectType.Account.fields.PersonContactId.isAccessible()) {
            System.debug(LoggingLevel.WARN,
            'KenPortalCourseEnrollmentController.resolveLearnerContactId: missing Account/PersonContactId access.');
            return null;
        }
        
        try {
            List<Account> accounts = [
                SELECT PersonContactId
                FROM Account
                WHERE Id = :u.AccountId
                LIMIT 1
            ];
            System.debug(LoggingLevel.INFO,
            'KenPortalCourseEnrollmentController.resolveLearnerContactId: accounts fetched=' + accounts.size() +
                ', personContactId=' + (accounts.isEmpty() ? null : accounts[0].PersonContactId));
            if (!accounts.isEmpty() && accounts[0].PersonContactId != null) {
                return accounts[0].PersonContactId;
            }
        } catch (Exception ignored) {
            // Ignore fallback failure and return null when portal profile can't read Account.
            System.debug(LoggingLevel.ERROR,
            'KenPortalCourseEnrollmentController.resolveLearnerContactId fallback failed: ' +
                ignored.getMessage());
        }
        System.debug(LoggingLevel.WARN,
        'KenPortalCourseEnrollmentController.resolveLearnerContactId: returning null.');
        return null;
    }
    
    private static Integer parseInteger(Object value) {
        if (value == null) {
            return null;
        }
        try {
            return Integer.valueOf(String.valueOf(value).trim());
        } catch (Exception ex) {
            return null;
        }
    }
    
    private static Integer parseYear(Object value) {
        Integer direct = parseInteger(value);
        if (direct != null) {
            return direct;
        }
        if (value == null) {
            return null;
        }
        String raw = String.valueOf(value);
        if (String.isBlank(raw)) {
            return null;
        }
        Matcher m = Pattern.compile('(\\d{4})').matcher(raw);
        if (m.find()) {
            try {
                return Integer.valueOf(m.group(1));
            } catch (Exception ignored) {
                return null;
            }
        }
        return null;
    }
    
    private static Integer parseFirstNumber(Object value) {
        Integer direct = parseInteger(value);
        if (direct != null) {
            return direct;
        }
        if (value == null) {
            return null;
        }
        String raw = String.valueOf(value);
        if (String.isBlank(raw)) {
            return null;
        }
        Matcher m = Pattern.compile('(\\d+)').matcher(raw);
        if (m.find()) {
            try {
                return Integer.valueOf(m.group(1));
            } catch (Exception ignored) {
                return null;
            }
        }
        return null;
    }
    
    private static Integer resolveCadencePeriods(String cadenceType) {
        if (String.isBlank(cadenceType)) {
            return 2;
        }
        String c = cadenceType.trim().toLowerCase();
        if (c == 'semester') {
            return 2;
        }
        if (c == 'trimester') {
            return 3;
        }
        if (c == 'quarter') {
            return 4;
        }
        if (c == 'year' || c == 'yearly') {
            return 1;
        }
        return 2;
    }
    
    private static Integer calculatePeriodNumber(String cadenceType, Integer year, Integer sequence) {
        if (year == null || sequence == null) {
            return null;
        }
        Integer periodsPerYear = resolveCadencePeriods(cadenceType);
        if (periodsPerYear == null || periodsPerYear <= 0) {
            return null;
        }
        return ((year - 1) * periodsPerYear) + sequence;
    }
    
    private static Integer resolveTermSequence(Object sequenceValue) {
        return parseInteger(sequenceValue);
    }
    
    private static Integer calculateAbsoluteSemesterNumber(
        Integer planStartYear,
    Integer termStartYear,
    Integer termSequence,
    Integer cadencePeriods
    ) {
        if (termSequence == null) {
            return null;
        }
        if (planStartYear == null || termStartYear == null || cadencePeriods == null || cadencePeriods <= 0) {
            return termSequence;
        }
        Integer yearOffset = termStartYear - planStartYear;
        if (yearOffset < 0) {
            return null;
        }
        return (yearOffset * cadencePeriods) + termSequence;
    }
    
    private static Integer resolveSessionSemesterNumber(AcademicSession s) {
        if (s == null) {
            return null;
        }
        Integer byCadencePeriod = parseFirstNumber(s.Cadence_Period__c);
        if (byCadencePeriod != null) {
            return byCadencePeriod;
        }
        Integer byName = parseFirstNumber(s.Name);
        if (byName != null) {
            return byName;
        }
        return parseInteger(s.Sequence__c);
    }
    
    private static String formatScheduleLine(CourseOfferingSchedule schedule) {
        if (schedule == null) {
            return 'Schedule unavailable';
        }
        List<String> activeDays = new List<String>();
        if (schedule.IsMonday) {activeDays.add('Mon');}
        if (schedule.IsTuesday) {activeDays.add('Tu');}
        if (schedule.IsWednesday) {activeDays.add('Wed');}
        if (schedule.IsThursday) {activeDays.add('Thu');}
        if (schedule.IsFriday) {activeDays.add('Fri');}
        if (schedule.IsSaturday) {activeDays.add('Sat');}
        if (schedule.IsSunday) {activeDays.add('Sun');}
        
        String dayText = activeDays.isEmpty() ? 'Schedule' : String.join(activeDays, ', ');
        String startText = formatPortalTime(schedule.StartTime);
        String endText = formatPortalTime(schedule.EndTime);
        if (String.isBlank(startText) || String.isBlank(endText)) {
            return dayText;
        }
        return dayText + ': ' + startText + ' - ' + endText;
    }
    
    private static String formatPortalTime(Time timeValue) {
        if (timeValue == null) {
            return '';
        }
        Integer hour = timeValue.hour();
        Integer minute = timeValue.minute();
        Integer displayHour = Math.mod(hour, 12);
        if (displayHour == 0) {
            displayHour = 12;
        }
        String meridiem = hour >= 12 ? 'PM' : 'AM';
        String minuteText = minute < 10 ? '0' + String.valueOf(minute) : String.valueOf(minute);
        return String.valueOf(displayHour) + ':' + minuteText + ' ' + meridiem;
    }
    
    private static String resolveRegistrationStatus(
        Boolean useSessionRegistrationDates,
    Object sessionOpenDateValue,
    Object sessionCloseDateValue,
    Object termOpenDateValue,
    Object termCloseDateValue
    ) {
        Datetime nowVal = System.now();
        Datetime openDt;
        Datetime closeDt;
        if (useSessionRegistrationDates == true) {
            openDt = toDateTime(sessionOpenDateValue);
            closeDt = toDateTime(sessionCloseDateValue);
        } else {
            openDt = toDateTime(termOpenDateValue);
            closeDt = toDateTime(termCloseDateValue);
        }
        
        if (openDt != null && nowVal < openDt) {
            return 'Upcoming';
        }
        if (openDt != null && closeDt != null && nowVal >= openDt && nowVal <= closeDt) {
            return 'Ongoing';
        }
        if (closeDt != null && nowVal > closeDt) {
            return 'Completed';
        }
        if (openDt != null && closeDt == null && nowVal >= openDt) {
            return 'Ongoing';
        }
        if (openDt == null && closeDt != null) {
            return nowVal <= closeDt ? 'Ongoing' : 'Completed';
        }
        return 'Upcoming';
    }
    
    private static Datetime resolveRegistrationBoundary(
        Boolean useSessionRegistrationDates,
    Object sessionBoundaryValue,
    Object termBoundaryValue
    ) {
        if (useSessionRegistrationDates == true) {
            return toDateTime(sessionBoundaryValue);
        }
        return toDateTime(termBoundaryValue);
    }
    
    private static Datetime toDateTime(Object rawValue) {
        if (rawValue == null) {
            return null;
        }
        if (rawValue instanceof Datetime) {
            return (Datetime) rawValue;
        }
        if (rawValue instanceof Date) {
            Date d = (Date) rawValue;
            return Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
        }
        return null;
    }
    
    private static void setFieldIfCreatable(SObject row, Map<String, Schema.SObjectField> fields, String fieldApiName, Object value) {
        if (row == null || fields == null || String.isBlank(fieldApiName) || value == null) {
            return;
        }
        if (!fields.containsKey(fieldApiName)) {
            return;
        }
        row.put(fieldApiName, value);
    }
    
    private static String resolvePicklistValue(Map<String, Schema.SObjectField> fields, String fieldApiName, String desiredValue) {
        if (fields == null || String.isBlank(fieldApiName) || String.isBlank(desiredValue) || !fields.containsKey(fieldApiName)) {
            return desiredValue;
        }
        try {
            Schema.DescribeFieldResult describe = fields.get(fieldApiName).getDescribe();
            if (describe == null || describe.getType() != Schema.DisplayType.Picklist) {
                return desiredValue;
            }
            String desiredLower = desiredValue.trim().toLowerCase();
            for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
                if (entry == null || String.isBlank(entry.getValue())) {
                    continue;
                }
                if (entry.getValue().trim().toLowerCase() == desiredLower) {
                    return entry.getValue();
                }
            }
        } catch (Exception ignored) {
            return desiredValue;
        }
        return desiredValue;
    }
    
    private static String resolveEnrollmentStatusValue(
        Map<String, Schema.SObjectField> fields,
    LearningPathwayTemplateItem item
    ) {
        String itemType = item == null || String.isBlank(item.Type) ? '' : item.Type.trim().toLowerCase();
        String desiredValue = itemType == 'requirement' ? 'Approved' : 'In Review';
        return resolvePicklistValue(fields, 'Enrollment_Status__c', desiredValue);
    }
    @TestVisible
    private without sharing class FacultyNameResolver {
        private Map<Id, String> resolve(Set<Id> facultyIds) {
            Map<Id, String> namesById = new Map<Id, String>();
            if (facultyIds == null || facultyIds.isEmpty()) {
                return namesById;
            }
            
            Set<Id> userIds = new Set<Id>();
            Set<Id> contactIds = new Set<Id>();
            Set<Id> accountIds = new Set<Id>();
            
            for (Id facultyId : facultyIds) {
                if (facultyId == null) {
                    continue;
                }
                Schema.SObjectType sobjectType = facultyId.getSObjectType();
                if (sobjectType == User.SObjectType) {
                    userIds.add(facultyId);
                } else if (sobjectType == Contact.SObjectType) {
                    contactIds.add(facultyId);
                } else if (sobjectType == Account.SObjectType) {
                    accountIds.add(facultyId);
                }
            }
            
            if (!userIds.isEmpty()) {
                for (User facultyUser : [
                    SELECT Id, Name
                    FROM User
                    WHERE Id IN :userIds
                ]) {
                    namesById.put(facultyUser.Id, facultyUser.Name);
                }
            }
            
            if (!contactIds.isEmpty()) {
                for (Contact facultyContact : [
                    SELECT Id, Name
                    FROM Contact
                    WHERE Id IN :contactIds
                ]) {
                    namesById.put(facultyContact.Id, facultyContact.Name);
                }
            }
            
            if (!accountIds.isEmpty()) {
                for (Account facultyAccount : [
                    SELECT Id, Name
                    FROM Account
                    WHERE Id IN :accountIds
                ]) {
                    namesById.put(facultyAccount.Id, facultyAccount.Name);
                }
            }
            
            return namesById;
        }
    }
    
    private without sharing class EnrollmentDmlService {
        Contact getContactById(Id contactId) {
            if (contactId == null) {
                return null;
            }
            List<Contact> contacts = [
                SELECT Id, AccountId
                FROM Contact
                WHERE Id = :contactId
                LIMIT 1
            ];
            return contacts.isEmpty() ? null : contacts[0];
        }
        
        List<LearnerProgram> getLearnerProgramsForContact(Id learnerContactId) {
            if (learnerContactId == null) {
                return new List<LearnerProgram>();
            }
            return [
                SELECT Id, Name, Status
                FROM LearnerProgram
                WHERE LearnerContactId = :learnerContactId
                ORDER BY CreatedDate DESC
            ];
        }
        
        List<LearnerProgramRequirement> getExistingProgramRequirements(Id learnerContactId, Set<Id> planRequirementIds) {
            if (learnerContactId == null || planRequirementIds == null || planRequirementIds.isEmpty()) {
                return new List<LearnerProgramRequirement>();
            }
            return [
                SELECT Id, LearningProgramPlanRqmtId
                FROM LearnerProgramRequirement
                WHERE LearnerProgram.LearnerContactId = :learnerContactId
                AND LearningProgramPlanRqmtId IN :planRequirementIds
                ORDER BY CreatedDate DESC
            ];
        }
        
        Map<Id, AcademicTermEnrollment> getAcademicTermEnrollmentsByTermId(Id learnerContactId, Set<Id> academicTermIds) {
            Map<Id, AcademicTermEnrollment> ateByTermId = new Map<Id, AcademicTermEnrollment>();
            for (AcademicTermEnrollment ate : getAcademicTermEnrollments(learnerContactId, academicTermIds)) {
                if (ate.AcademicTermId != null && !ateByTermId.containsKey(ate.AcademicTermId)) {
                    ateByTermId.put(ate.AcademicTermId, ate);
                }
            }
            return ateByTermId;
        }
        
        List<AcademicTermEnrollment> getAcademicTermEnrollments(Id learnerContactId, Set<Id> academicTermIds) {
            if (learnerContactId == null || academicTermIds == null || academicTermIds.isEmpty()) {
                return new List<AcademicTermEnrollment>();
            }
            return [
                SELECT Id, AcademicTermId
                FROM AcademicTermEnrollment
                WHERE LearnerContactId = :learnerContactId
                AND AcademicTermId IN :academicTermIds
            ];
        }
        
        List<CourseOfferingParticipant> getExistingCourseOfferingParticipants(Id learnerContactId, Set<Id> courseOfferingIds) {
            if (learnerContactId == null || courseOfferingIds == null || courseOfferingIds.isEmpty()) {
                return new List<CourseOfferingParticipant>();
            }
            return [
                SELECT Id, CourseOfferingId
                FROM CourseOfferingParticipant
                WHERE ParticipantContactId = :learnerContactId
                AND CourseOfferingId IN :courseOfferingIds
            ];
        }
        
        Database.SaveResult[] insertRowsPartial(List<SObject> rows) {
            if (rows == null || rows.isEmpty()) {
                return new List<Database.SaveResult>();
            }
            return Database.insert(rows, false);
        }
        
        void insertRows(List<SObject> rows) {
            if (rows == null || rows.isEmpty()) {
                return;
            }
            insert rows;
        }
        
        void updateRow(SObject row) {
            if (row == null) {
                return;
            }
            update row;
        }
        
        void updateRows(List<SObject> rows) {
            if (rows == null || rows.isEmpty()) {
                return;
            }
            update rows;
        }
    }
    
}