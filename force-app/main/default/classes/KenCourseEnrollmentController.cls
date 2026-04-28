/**
 * ************************************************************************************************
 * @className  KenCourseEnrollmentController
 *
 * @description
 *  Backs the `my/courseEnrollment` LWC. Queries STANDARD Salesforce Education
 *  Cloud objects (LearnerProgram, LearningProgramPlan, AcademicTermEnrollment,
 *  AcademicSession, AcademicTerm) — no custom `__c` schema.
 *
 *  Pattern aligned with the academics-code-reference project's
 *  `KenCourseEnrollmentController.getAcademicSessionsForUser`.
 *
 *  Required custom fields on standard objects (already present in the org):
 *    - LearningProgramPlan.Cadence_Type__c
 *    - AcademicSession.Sequence__c
 * ************************************************************************************************
 */
public without sharing class KenCourseEnrollmentController {

    public class AcademicSessionDTO {
        @AuraEnabled public Id      academicSessionId;
        @AuraEnabled public String  academicSessionName;
        @AuraEnabled public String  academicTermName;
        @AuraEnabled public String  season;
        @AuraEnabled public String  cadenceType;
        @AuraEnabled public Integer termNumber;
        @AuraEnabled public String  termLabel;
        @AuraEnabled public Integer sequence;
    }

    @AuraEnabled(cacheable=true)
    public static List<AcademicSessionDTO> getAcademicSessionsForUser() {
        List<AcademicSessionDTO> result = new List<AcademicSessionDTO>();
        try {
            User u = [
                SELECT ContactId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            if (u.ContactId == null) return result;

            // Resolve student → program enrolment.
            List<LearnerProgram> lps = [
                SELECT LearningProgramPlanId
                FROM LearnerProgram
                WHERE LearnerContactId = :u.ContactId
                LIMIT 1
            ];
            if (lps.isEmpty()) return result;
            LearnerProgram lp = lps[0];

            LearningProgramPlan plan = [
                SELECT Cadence_Type__c
                FROM LearningProgramPlan
                WHERE Id = :lp.LearningProgramPlanId
                LIMIT 1
            ];
            String cadenceType = plan.Cadence_Type__c;

            // Term enrolments → academic sessions matching cadence.
            List<AcademicTermEnrollment> enrollments = [
                SELECT AcademicTermId
                FROM AcademicTermEnrollment
                WHERE LearnerContactId = :u.ContactId
            ];
            if (enrollments.isEmpty()) return result;
            Set<Id> academicTermIds = new Set<Id>();
            for (AcademicTermEnrollment e : enrollments) {
                academicTermIds.add(e.AcademicTermId);
            }

            List<AcademicSession> sessions = [
                SELECT Id, Name, Season, Type, ClassStartDate,
                       AcademicTerm.Name, Sequence__c
                FROM AcademicSession
                WHERE AcademicTermId IN :academicTermIds
                  AND Type = :cadenceType
                  AND IsActive = true
                ORDER BY ClassStartDate ASC
            ];

            Integer counter = 1;
            for (AcademicSession s : sessions) {
                AcademicSessionDTO dto = new AcademicSessionDTO();
                dto.academicSessionId   = s.Id;
                dto.academicSessionName = s.Name;
                dto.academicTermName    = s.AcademicTerm.Name;
                dto.season              = s.Season;
                dto.sequence            = (s.Sequence__c == null) ? null : Integer.valueOf(s.Sequence__c);
                dto.cadenceType         = cadenceType;
                dto.termNumber          = counter;
                dto.termLabel           = cadenceType + ' ' + counter + ' - ' + s.AcademicTerm.Name;
                result.add(dto);
                counter++;
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load academic sessions: ' + e.getMessage());
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // Phase-3 pathway DTOs (read-only) — ported from SMU's
    // KenPortalCourseEnrollmentController. Shapes kept identical so an LWC
    // refactor can drop these in without rewiring.
    // ════════════════════════════════════════════════════════════════════════

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

    public class EnrolledCourseDTO {
        @AuraEnabled public Id learnerPathwayItemId;
        @AuraEnabled public Id learnerPathwayId;
        @AuraEnabled public Id learningPathwayTemplateItemId;
        @AuraEnabled public Id learningCourseId;
        @AuraEnabled public String courseName;
        @AuraEnabled public Id courseOfferingId;
        @AuraEnabled public Id academicSessionId;
        @AuraEnabled public String enrollmentStatus;
    }

    private static Id resolveContactId() {
        try {
            User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            return u.ContactId;
        } catch (Exception e) { return null; }
    }

    /**
     * @description Returns the LearningPathwayTemplates linked to the running
     * student's program plan (via LearningPathwayTmplPgmPlan), with a flag
     * indicating whether the student already has a LearnerPathway for it.
     */
    @AuraEnabled(cacheable=true)
    public static List<ProgramTemplateDTO> getProgramPath() {
        List<ProgramTemplateDTO> result = new List<ProgramTemplateDTO>();
        try {
            Id contactId = resolveContactId();
            if (contactId == null) return result;

            List<LearnerProgram> programs = [
                SELECT LearningProgramPlanId
                FROM LearnerProgram
                WHERE LearnerContactId = :contactId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (programs.isEmpty() || programs[0].LearningProgramPlanId == null) return result;

            List<LearningPathwayTmplPgmPlan> links = [
                SELECT LearningPathwayTemplateId,
                       LearningPathwayTemplate.Name,
                       LearningPathwayTemplate.Pathway_Type__c,
                       Default__c, Start_Period__c, End_Period__c
                FROM LearningPathwayTmplPgmPlan
                WHERE LearningProgramPlanId = :programs[0].LearningProgramPlanId
            ];

            // Existing LearnerPathway by template name (matches SMU impl).
            Set<String> templateNames = new Set<String>();
            for (LearningPathwayTmplPgmPlan l : links) {
                if (l.LearningPathwayTemplate != null && String.isNotBlank(l.LearningPathwayTemplate.Name)) {
                    templateNames.add(l.LearningPathwayTemplate.Name.trim());
                }
            }
            Map<String, LearnerPathway> learnerPathwayByName = new Map<String, LearnerPathway>();
            if (!templateNames.isEmpty()) {
                for (LearnerPathway p : [
                    SELECT Id, Name
                    FROM LearnerPathway
                    WHERE LearnerContactId = :contactId
                      AND Name IN :templateNames
                ]) {
                    if (String.isNotBlank(p.Name)) {
                        learnerPathwayByName.put(p.Name.trim().toLowerCase(), p);
                    }
                }
            }

            for (LearningPathwayTmplPgmPlan l : links) {
                ProgramTemplateDTO d = new ProgramTemplateDTO();
                d.learningPathwayTemplateId = l.LearningPathwayTemplateId;
                d.learningPathwayTemplateName = (l.LearningPathwayTemplate == null) ? null : l.LearningPathwayTemplate.Name;
                d.templateType = (l.LearningPathwayTemplate == null) ? null : l.LearningPathwayTemplate.Pathway_Type__c;
                d.isDefaultPathway = l.Default__c == true;
                d.startPeriod = l.Start_Period__c;
                d.endPeriod = l.End_Period__c;
                String key = String.isBlank(d.learningPathwayTemplateName)
                    ? null : d.learningPathwayTemplateName.trim().toLowerCase();
                LearnerPathway lp = (key == null) ? null : learnerPathwayByName.get(key);
                d.isEnrolled = lp != null;
                d.learnerPathwayId = (lp == null) ? null : lp.Id;
                result.add(d);
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load program path: ' + e.getMessage());
        }
    }

    /**
     * @description Returns the LearnerPathways the running student is enrolled in.
     */
    @AuraEnabled(cacheable=true)
    public static List<LearnerPathwayDTO> getLearnerPathwaysForUser() {
        List<LearnerPathwayDTO> result = new List<LearnerPathwayDTO>();
        try {
            Id contactId = resolveContactId();
            if (contactId == null) return result;

            List<LearnerPathway> rows = [
                SELECT Id, Name, Status
                FROM LearnerPathway
                WHERE LearnerContactId = :contactId
                ORDER BY Name ASC
            ];

            // Resolve template Id by matching name against LearningPathwayTemplate.
            Set<String> names = new Set<String>();
            for (LearnerPathway p : rows) {
                if (String.isNotBlank(p.Name)) names.add(p.Name.trim());
            }
            Map<String, Id> tplByName = new Map<String, Id>();
            if (!names.isEmpty()) {
                for (LearningPathwayTemplate t : [
                    SELECT Id, Name FROM LearningPathwayTemplate WHERE Name IN :names
                ]) {
                    if (String.isNotBlank(t.Name) && !tplByName.containsKey(t.Name.trim().toLowerCase())) {
                        tplByName.put(t.Name.trim().toLowerCase(), t.Id);
                    }
                }
            }
            for (LearnerPathway p : rows) {
                LearnerPathwayDTO d = new LearnerPathwayDTO();
                d.learnerPathwayId = p.Id;
                d.name = p.Name;
                d.status = p.Status;
                String key = String.isBlank(p.Name) ? null : p.Name.trim().toLowerCase();
                d.learningPathwayTemplateId = (key == null) ? null : tplByName.get(key);
                result.add(d);
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load learner pathways: ' + e.getMessage());
        }
    }

    /**
     * @description Returns the LearnerPathwayItems (enrolled course rows) for
     * the running student, joined to the LearningCourse for display.
     */
    @AuraEnabled(cacheable=true)
    public static List<EnrolledCourseDTO> getEnrolledCourses() {
        List<EnrolledCourseDTO> result = new List<EnrolledCourseDTO>();
        try {
            Id contactId = resolveContactId();
            if (contactId == null) return result;

            // Find learner pathways for this contact, then their items.
            Set<Id> pathwayIds = new Set<Id>();
            for (LearnerPathway p : [
                SELECT Id FROM LearnerPathway WHERE LearnerContactId = :contactId
            ]) {
                pathwayIds.add(p.Id);
            }
            if (pathwayIds.isEmpty()) return result;

            // NOTE: LearningProgramPlanRequirement (the SMU bridge between
            // template item and LearningCourse) is not enabled in this org's
            // EduCloud licence. We surface what we have on LearnerPathwayItem
            // (template item linkage, academic session, status). Course name is
            // resolved via the linked LearningPathwayTemplateItem.LearningId.
            for (LearnerPathwayItem it : [
                SELECT Id, LearnerPathwayId,
                       LearningPathwayTemplateItemId,
                       AcademicSessionId,
                       Enrollment_Status__c,
                       LearningPathwayTemplateItem.LearningId
                FROM LearnerPathwayItem
                WHERE LearnerPathwayId IN :pathwayIds
            ]) {
                EnrolledCourseDTO d = new EnrolledCourseDTO();
                d.learnerPathwayItemId = it.Id;
                d.learnerPathwayId = it.LearnerPathwayId;
                d.learningPathwayTemplateItemId = it.LearningPathwayTemplateItemId;
                d.academicSessionId = it.AcademicSessionId;
                d.enrollmentStatus = it.Enrollment_Status__c;
                // LearningPathwayTemplateItem.LearningId references parent
                // Learning (not LearningCourse) — left null here; UI can fetch
                // the course separately if needed.
                result.add(d);
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load enrolled courses: ' + e.getMessage());
        }
    }
}