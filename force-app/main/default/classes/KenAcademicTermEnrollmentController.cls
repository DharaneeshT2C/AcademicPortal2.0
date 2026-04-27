/**
 * ************************************************************************************************
 * @className  AcademicTermEnrollmentController
 *
 * @description
 *  Aura-enabled controller used for Academic Term Enrollment management.
 *
 *  This class supports UI-driven enrollment workflows and provides methods to:
 *  - Retrieve Institutes, Departments, Programs, Program Plans, and Specializations
 *  - Fetch Academic Years and Academic Terms based on Program Plan duration
 *  - Retrieve Sections (Class Cohorts) for a Program Plan
 *  - Identify eligible students for next Academic Term enrollment
 *  - Create Academic Term Enrollments
 *  - Update related Learner Profile and Learner Program cadence details
 *
 *  All SOQL queries enforce object and field-level security using
 *   or USER_MODE.
 *  All DML operations validate CRUD permissions before execution.
 *
 * @author      Sureka A R K
 * @createdOn  Jan 13, 2026
 *
 * @history
 * ------------------------------------------------------------------------------------------------
 * Version   Date           Author          Description
 * 1.0       Jan 13, 2026   Sureka A R K     Initial version
 * ************************************************************************************************
 */
@suppressWarnings('PMD.ExcessiveParameterList,PMD.StdCyclomaticComplexity,PMD.CyclomaticComplexity,PMD.NcssMethodCount,PMD.CognitiveComplexity,PMD.AvoidNonRestrictiveQueries,PMD.EagerlyLoadedDescribeSObjectResult')
public with sharing class KenAcademicTermEnrollmentController {
    private static Boolean canRead(Schema.SObjectType sobjectType) {
        return sobjectType != null && sobjectType.getDescribe().isAccessible();
    }
    private static Boolean canCreateEnrollmentFields() {
        return AcademicTermEnrollment.AcademicTermId.getDescribe().isCreateable() &&
            AcademicTermEnrollment.LearnerContactId.getDescribe().isCreateable() &&
            AcademicTermEnrollment.LearnerAccountId.getDescribe().isCreateable() &&
            AcademicTermEnrollment.StudentAcademicLevel.getDescribe().isCreateable() &&
            AcademicTermEnrollment.EnrollmentDate.getDescribe().isCreateable() &&
            AcademicTermEnrollment.EnrollmentStatus.getDescribe().isCreateable();
    }
    private static Boolean canUpdateProfileEnrollmentLookup() {
        return LearnerProfile.AcademicTermEnrollmentId.getDescribe().isUpdateable();
    }
    private static Boolean canCreateProfileWithEnrollmentLookup() {
        return Schema.SObjectType.LearnerProfile.isCreateable() &&
            LearnerProfile.Name.getDescribe().isCreateable() &&
            LearnerProfile.ContactId.getDescribe().isCreateable() &&
            LearnerProfile.AcademicTermEnrollmentId.getDescribe().isCreateable();
    }
    private static Boolean canUpdateProgramCadenceFields() {
        return LearnerProgram.Cadence_Type__c.getDescribe().isUpdateable() &&
            LearnerProgram.Cadence_Period__c.getDescribe().isUpdateable();
    }
    /**
     * @description Retrieves all Institute Accounts.
     * @return List<Account> List of Institute accounts sorted by Name.
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getInstitutes() {
        if (!canRead(Account.SObjectType)) {
            return new List<Account>();
        }
        Id rtId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get(KenConstantController.RECORDTYPE_ACCOUNT_INSTITUTE)
            .getRecordTypeId();
        return [
            SELECT Id, Name
            FROM Account 
            WHERE RecordTypeId = :rtId 
            ORDER BY Name
        ];
    }
    /**
     * @description
     * Retrieves all Institute Departments (Program Specializations).
     * @return List<Account>
     *
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getInstituteDepartment() {
        if (!canRead(Account.SObjectType)) {
            return new List<Account>();
        }
        Id rtId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get(KenConstantController.RECORDTYPE_ACCOUNT_DEPARTMENT)
            .getRecordTypeId();
        return [
            SELECT Id, Name
            FROM Account
            WHERE RecordTypeId = :rtId 
            ORDER BY Name
        ];
    }
    /**
     * @description
     *  Retrieves all Learning Programs available in the system.
     *
     * @return List<LearningProgram>
     *         List of learning programs sorted by Name.
     */
    @AuraEnabled(cacheable=true)
    public static List<LearningProgram> getPrograms() {
        if (!canRead(LearningProgram.SObjectType)) {
            return new List<LearningProgram>();
        }
        return [
            SELECT Id, Name
            FROM LearningProgram 
            ORDER BY Name
        ];
    }
    /**
     * @description
     *  Retrieves Program Plans associated with a given Learning Program.
     *
     * @param learningProgramId Id of the Learning Program
     * @return List<LearningProgramPlan>
     *         List of program plans for the specified program.
     */
    @AuraEnabled(cacheable=true)
    public static List<LearningProgramPlan> getProgramPlan(Id learningProgramId) {
        if (learningProgramId == null || !canRead(LearningProgramPlan.SObjectType)) {
            return new List<LearningProgramPlan>();
        }
        return [
            SELECT Id, Name, LearningProgramId
            FROM LearningProgramPlan
            WHERE LearningProgramId = :learningProgramId 
            ORDER BY Name 
        ];
    }
    /**
     * @description
     *  Retrieves Program Specializations (Learning Pathway Templates)
     *  associated with a Learning Program Plan.
     *
     * @param learningProgramPlanId Id of the Learning Program Plan
     * @return List<LearningPathwayTmplPgmPlan>
     *         List of program specializations sorted by name.
     */
    @AuraEnabled(cacheable=true)
    public static List<LearningPathwayTmplPgmPlan> getProgramSpecializations(
        Id learningProgramPlanId
    ) {
        if (learningProgramPlanId == null || !canRead(LearningPathwayTmplPgmPlan.SObjectType)){
            return new List<LearningPathwayTmplPgmPlan>();
        }
        return [
            SELECT Id,
                   LearningProgramPlanId,
                   LearningPathwayTemplateId,
                   LearningPathwayTemplate.Name
            FROM LearningPathwayTmplPgmPlan
            WHERE LearningProgramPlanId = :learningProgramPlanId
             ORDER BY LearningPathwayTemplate.Name 
        ];
    }
    /**
     * @description
     *  Data Transfer Object used to return Academic Term details
     *  along with Academic Year information to the UI.
     */
    public class AcademicTermDTO {
        @AuraEnabled public Id termId;
        @AuraEnabled public String termName;
        @AuraEnabled public Id academicYearId;
        @AuraEnabled public String academicYearName;
        @AuraEnabled public Datetime startDate;
        @AuraEnabled public Datetime endDate;
    }
    /**
     * @description
     *  Returns Academic Terms associated with a Learning Program Plan,
     *  filtered by the Program Plan active years.
     *
     * @param learningProgramPlanId Id of the Learning Program Plan
     * @return List<AcademicTermDTO>
     *         List of Academic Term DTOs containing term and academic year details.
     */
    @AuraEnabled(cacheable=true)
    public static List<AcademicTermDTO> getAcademicTermsByProgramPlan(
        Id learningProgramPlanId
    ) {
        List<AcademicTermDTO> result = new List<AcademicTermDTO>();
        if (learningProgramPlanId == null) {
            return result;
        }
        if (!canRead(LearningProgramPlan.SObjectType) ||
            !canRead(AcademicYear.SObjectType) ||
        !canRead(AcademicTerm.SObjectType)) {
            return result;
        }
        LearningProgramPlan plan = [
            SELECT ActiveFromDate, ActiveToDate  
            FROM LearningProgramPlan
            WHERE Id = :learningProgramPlanId
             LIMIT 1 
        ];
        Integer planStartYear = plan.ActiveFromDate.year();
        Integer planEndYear   = plan.ActiveToDate.year();
        List<AcademicYear> allYears = [
            SELECT Id, Name
            FROM AcademicYear 
        ];
        Map<Id, AcademicYear> validYearMap = new Map<Id, AcademicYear>();
        for (AcademicYear ay : allYears) {
            if (String.isBlank(ay.Name)) {
                continue;
            }
            List<String> parts = ay.Name.split('-');
            if (parts.size() != 2) {
                continue;
            }
            Integer startYear;
            Integer endYear;
            try {
                startYear = Integer.valueOf(parts[0].trim());
                endYear   = Integer.valueOf(parts[1].trim());
            } catch (Exception e) {
                continue;
            }
            if (startYear >= planStartYear && endYear <= planEndYear) {
                validYearMap.put(ay.Id, ay);
            }
        }
        if (validYearMap.isEmpty()) {
            return result;
        }
        List<AcademicTerm> terms = [
            SELECT Id,
                Name,
                AcademicYearId,
                AcademicYear.Name,
                StartDate,
                EndDate
            FROM AcademicTerm
            WHERE AcademicYearId IN :validYearMap.keySet()
             ORDER BY StartDate 
        ];
        for (AcademicTerm t : terms) {
            AcademicTermDTO dto = new AcademicTermDTO();
            dto.termId = t.Id;
            dto.termName = t.Name;
            dto.academicYearId = t.AcademicYearId;
            dto.academicYearName = t.AcademicYear.Name;
            dto.startDate = t.StartDate;
            dto.endDate = t.EndDate;
            result.add(dto);
        }
        return result;
    }
    /**
     * @description
     *  Retrieves distinct Class Cohorts (Sections) for a given Program Plan.
     *
     * @param learningProgramPlanId Id of the Learning Program Plan
     * @return List<String>
     *         List of unique class cohort values.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getSectionsByProgramPlan(
        Id learningProgramPlanId
    ) {
        if (learningProgramPlanId == null || !canRead(LearnerProgram.SObjectType)) {
            return new List<String>();
        }
        List<AggregateResult> results = [
            SELECT ClassCohort cohort
            FROM LearnerProgram
            WHERE LearningProgramPlanId = :learningProgramPlanId
            AND ClassCohort != null 
            GROUP BY ClassCohort
            ORDER BY ClassCohort 
        ];
        List<String> sections = new List<String>();
        for (AggregateResult ar : results) {
            sections.add((String) ar.get('cohort'));
        }
        return sections;
    }
    /**
     * @description
     *  Data Transfer Object representing student and enrollment-related details
     *  used by the UI during Academic Term enrollment.
     */
    public class StudentDTO {
        @AuraEnabled public Id learnerProgramId;
        @AuraEnabled public Id studentId;
        @AuraEnabled public String studentName;
        @AuraEnabled public String classCohort;
        @AuraEnabled public String studentEmail;
    }
    
    /**
     * @description
     *  DTO used by the enrollment split-screen to render Academic Term Enrollment rows.
     *  Each instance maps one AcademicTermEnrollment record into UI-friendly fields.
     */
    public class AcademicTermEnrollmentRowDTO {
        @AuraEnabled public Id enrollmentId;
        @AuraEnabled public String studentName;
        @AuraEnabled public String studentEmail;
        @AuraEnabled public String enrollmentStatus;
        @AuraEnabled public Date enrollmentDate;
        @AuraEnabled public String studentAcademicLevel;
        @AuraEnabled public String learnerAccountName;
    }
    
    /**
     * @description
     *  Returns enrollment rows for a given Academic Term.
     *  Data is transformed into AcademicTermEnrollmentRowDTO for LWC consumption.
     *  Returns an empty list when input is null or user lacks read access.
     *
     * @param academicTermId Id of the AcademicTerm whose enrollments should be fetched.
     * @return List<AcademicTermEnrollmentRowDTO> Enrollment row DTOs ordered by latest enrollment first.
     * @throws AuraHandledException If query execution fails due to runtime/security exceptions.
     */
    @AuraEnabled(cacheable=true)
    public static List<AcademicTermEnrollmentRowDTO> getEnrollmentsByAcademicTerm(Id academicTermId) {
        if (academicTermId == null || !canRead(AcademicTermEnrollment.SObjectType)) {
            return new List<AcademicTermEnrollmentRowDTO>();
        }
        
        List<AcademicTermEnrollmentRowDTO> rows = new List<AcademicTermEnrollmentRowDTO>();
        List<AcademicTermEnrollment> enrollments = [
            SELECT Id,
                EnrollmentDate,
                EnrollmentStatus,
                StudentAcademicLevel,
                LearnerContact.Name,
                LearnerContact.Email,
                LearnerAccount.Name
            FROM AcademicTermEnrollment
            WHERE AcademicTermId = :academicTermId
            
            ORDER BY EnrollmentDate DESC, CreatedDate DESC
        ];
        
        for (AcademicTermEnrollment e : enrollments) {
            AcademicTermEnrollmentRowDTO dto = new AcademicTermEnrollmentRowDTO();
            dto.enrollmentId = e.Id;
            dto.studentName = e.LearnerContact != null ? e.LearnerContact.Name : null;
            dto.studentEmail = e.LearnerContact != null ? e.LearnerContact.Email : null;
            dto.enrollmentStatus = e.EnrollmentStatus;
            dto.enrollmentDate = e.EnrollmentDate;
            dto.studentAcademicLevel = e.StudentAcademicLevel;
            dto.learnerAccountName = e.LearnerAccount != null ? e.LearnerAccount.Name : null;
            rows.add(dto);
        }
        return rows;
    }
    
    /**
     * @description
     *  Retrieves students who are actively enrolled in the current Academic Term,
     *  belong to the specified Program Plan and Class Cohort,
     *  and are not yet enrolled in the next Academic Term.
     *
     * @param currentAcademicTermId Id of the current Academic Term
     * @param nextAcademicTermId    Id of the next Academic Term
     * @param learningProgramPlanId Id of the Learning Program Plan
     * @param classCohort           Class Cohort (Section)
     *
     * @return List<StudentDTO>
     *         List of eligible students with learner and program details.
     */
    @AuraEnabled
    public static List<StudentDTO> searchStudentsByCurrentTermAndProgramPlan(
        Id currentAcademicTermId,
    Id nextAcademicTermId,
    Id learningProgramPlanId,
    String classCohort
    ) {
        if (
            currentAcademicTermId == null ||
            nextAcademicTermId == null ||
            learningProgramPlanId == null ||
            classCohort == null
        ) {
            return new List<StudentDTO>();
        }
        if (!canRead(LearnerProfile.SObjectType) ||
            !canRead(AcademicTermEnrollment.SObjectType) ||
        !canRead(LearnerProgram.SObjectType)) {
            return new List<StudentDTO>();
        }
        
        // Entry-condition / first-semester flow:
        // when current and next terms are the same, search directly from LearnerProgram
        // and exclude students already enrolled in that same term.
        if (currentAcademicTermId == nextAcademicTermId) {
            List<LearnerProgram> firstSemPrograms = [
                SELECT Id,
                    LearnerContactId,
                    LearnerContact.Name,
                    LearnerContact.Email,
                    ClassCohort
                FROM LearnerProgram
                WHERE LearningProgramPlanId = :learningProgramPlanId
                AND ClassCohort = :classCohort
                AND LearnerContactId != null
                
            ];
            if (firstSemPrograms.isEmpty()) {
                return new List<StudentDTO>();
            }
            
            Set<Id> contactIds = new Set<Id>();
            for (LearnerProgram lp : firstSemPrograms) {
                contactIds.add(lp.LearnerContactId);
            }
            
            Set<Id> alreadyEnrolledContactIds = new Set<Id>();
            for (AcademicTermEnrollment ate : [
                SELECT LearnerContactId
                FROM AcademicTermEnrollment
                WHERE AcademicTermId = :nextAcademicTermId
                AND LearnerContactId IN :contactIds
                
            ]) {
                alreadyEnrolledContactIds.add(ate.LearnerContactId);
            }
            
            List<StudentDTO> firstSemResult = new List<StudentDTO>();
            for (LearnerProgram lp : firstSemPrograms) {
                if (alreadyEnrolledContactIds.contains(lp.LearnerContactId)) {
                    continue;
                }
                StudentDTO dto = new StudentDTO();
                dto.learnerProgramId = lp.Id;
                dto.studentId = lp.LearnerContactId;
                dto.studentName = lp.LearnerContact == null ? null : lp.LearnerContact.Name;
                dto.studentEmail = lp.LearnerContact == null ? null : lp.LearnerContact.Email;
                dto.classCohort = lp.ClassCohort;
                firstSemResult.add(dto);
            }
            return firstSemResult;
        }
        
        Set<Id> nextTermContactIds = new Set<Id>();
        for (LearnerProfile lp : [
        SELECT ContactId
        FROM LearnerProfile
        WHERE AcademicTermEnrollment.AcademicTermId = :nextAcademicTermId 
    ]) {
            nextTermContactIds.add(lp.ContactId);
        }
        List<AcademicTermEnrollment> currentEnrollments = [
        SELECT Id,
               LearnerContactId,
               LearnerContact.Name,
               LearnerContact.Email
        FROM AcademicTermEnrollment
        WHERE AcademicTermId = :currentAcademicTermId
        AND EnrollmentStatus = :KenConstantController.ENROLLMENT_STATUS_ACTIVE
        AND LearnerContactId NOT IN :nextTermContactIds 
    ];
        if (currentEnrollments.isEmpty()) {
            return new List<StudentDTO>();
        }
        Set<Id> eligibleContactIds = new Set<Id>();
        for (AcademicTermEnrollment ate : currentEnrollments) {
            eligibleContactIds.add(ate.LearnerContactId);
        }
        List<LearnerProgram> learnerPrograms = [
        SELECT Id,
               LearnerContactId,
               ClassCohort
        FROM LearnerProgram
        WHERE LearnerContactId IN :eligibleContactIds
        AND LearningProgramPlanId = :learningProgramPlanId
        AND ClassCohort = :classCohort 
    ];
        Map<Id, LearnerProgram> contactToProgram = new Map<Id, LearnerProgram>();
        for (LearnerProgram lp : learnerPrograms) {
            contactToProgram.put(lp.LearnerContactId, lp);
        }
        List<StudentDTO> result = new List<StudentDTO>();
        for (AcademicTermEnrollment ate : currentEnrollments) {
            if (!contactToProgram.containsKey(ate.LearnerContactId)) {
                continue;
            }
            LearnerProgram lp = contactToProgram.get(ate.LearnerContactId);
            StudentDTO dto = new StudentDTO();
            dto.learnerProgramId = lp.Id;
            dto.studentId = ate.LearnerContactId;
            dto.studentName = ate.LearnerContact.Name;
            dto.studentEmail = ate.LearnerContact.Email;
            dto.classCohort = lp.ClassCohort;
            result.add(dto);
        }
        return result;
    }
    
    /**
     * @description
     *  Creates Academic Term Enrollments for the specified learners
     *  for the next Academic Term.
     *
     *  This method:
     *  - Inserts AcademicTermEnrollment records
     *  - Updates LearnerProfile with the new enrollment
     *  - Updates LearnerProgram cadence period based on term season and cadence type
     *
     * @param learnerProgramIds List of LearnerProgram record Ids
     * @param nextAcademicTermId Id of the next Academic Term
     * @param learnerAccountId   Legacy fallback Account Id (used only when contact AccountId is unavailable)
     *
     */
    @AuraEnabled
    public static void createAcademicTermEnrollments(
        List<Id> learnerProgramIds,
    Id nextAcademicTermId,
    Id learnerAccountId
    ) {
        try {
            if (learnerProgramIds == null || learnerProgramIds.isEmpty()) {
                throw new AuraHandledException('No learner programs selected for enrollment.');
            }
            if (!canRead(AcademicTerm.SObjectType) ||
                !canRead(LearnerProgram.SObjectType) ||
            !canRead(LearnerProfile.SObjectType)) {
                throw new AuraHandledException('You do not have read access to required records.');
            }
            if (!Schema.SObjectType.AcademicTermEnrollment.isCreateable() ||
                !canCreateEnrollmentFields() ||
                !Schema.SObjectType.LearnerProfile.isUpdateable() ||
                !canUpdateProfileEnrollmentLookup() ||
                !Schema.SObjectType.LearnerProgram.isUpdateable() ||
            !canUpdateProgramCadenceFields()) {
                throw new AuraHandledException(
                    'You do not have the required create/update field permissions.'
                    );
            }
            AcademicTerm nextTerm = [
                SELECT Id,
                    Start_Year__c,
                    Season
                FROM AcademicTerm
                WHERE Id = :nextAcademicTermId 
                LIMIT 1 
            ];
            List<LearnerProgram> lps = [
                SELECT Id,
                    LearnerContactId,
                    LearnerContact.Name,
                    LearnerContact.AccountId,
                    LearningProgramPlan.Start_Year__c,
                    LearningProgramPlan.Cadence_Type__c,
                    LearningProgramPlan.LearningProgram.AcademicLevel
                FROM LearnerProgram
                WHERE Id IN :learnerProgramIds 
            ];
            List<AcademicTermEnrollment> enrollments =
                new List<AcademicTermEnrollment>();
            Set<Id> contactIds = new Set<Id>();
            for (LearnerProgram lp : lps) {
                if (lp.LearnerContactId != null) {
                    contactIds.add(lp.LearnerContactId);
                }
            }
            Map<Id, AcademicTermEnrollment> contactToEnrollment = new Map<Id, AcademicTermEnrollment>();
            if (!contactIds.isEmpty()) {
                for (AcademicTermEnrollment existingAte : [
                    SELECT Id, LearnerContactId
                    FROM AcademicTermEnrollment
                    WHERE AcademicTermId = :nextAcademicTermId
                    AND LearnerContactId IN :contactIds
                    
                ]) {
                    contactToEnrollment.put(existingAte.LearnerContactId, existingAte);
                }
            }
            for (LearnerProgram lp : lps) {
                if (lp.LearnerContactId == null || contactToEnrollment.containsKey(lp.LearnerContactId)) {
                    continue;
                }
                enrollments.add(new AcademicTermEnrollment(
                    AcademicTermId = nextAcademicTermId,
                LearnerContactId = lp.LearnerContactId,
                LearnerAccountId = lp.LearnerContact.AccountId != null
                    ? lp.LearnerContact.AccountId
                    : learnerAccountId,
                StudentAcademicLevel =
                    lp.LearningProgramPlan.LearningProgram.AcademicLevel,
                EnrollmentDate = System.today(),
                EnrollmentStatus = KenConstantController.ENROLLMENT_STATUS_ACTIVE
                    ));
            }
            if (!enrollments.isEmpty()) {
                insert as user enrollments;
                for (AcademicTermEnrollment ate : enrollments) {
                    contactToEnrollment.put(ate.LearnerContactId, ate);
                }
            }
            List<LearnerProfile> profilesToUpdate = new List<LearnerProfile>();
            Set<Id> profiledContactIds = new Set<Id>();
            for (LearnerProfile profile : [
                SELECT Id, ContactId
                FROM LearnerProfile
                WHERE ContactId IN :contactToEnrollment.keySet() 
            ]) {
                profiledContactIds.add(profile.ContactId);
                profilesToUpdate.add(new LearnerProfile(
                    Id = profile.Id,
                AcademicTermEnrollmentId =
                    contactToEnrollment.get(profile.ContactId).Id
                    ));
            }
            if (!profilesToUpdate.isEmpty()) {
                Database.SaveResult[] profileResults =
                    Database.update(profilesToUpdate, false, AccessLevel.USER_MODE);
                for (Database.SaveResult sr : profileResults) {
                    if (!sr.isSuccess()) {
                        Database.Error err = sr.getErrors()[0];
                        throw new AuraHandledException(
                            'Failed to update LearnerProfile. Field access or sharing issue: ' +
                            err.getStatusCode() + ' - ' + err.getMessage()
                            );
                    }
                }
            }
            List<LearnerProfile> profilesToInsert = new List<LearnerProfile>();
            Map<Id, String> contactNameById = new Map<Id, String>();
            for (LearnerProgram lp : lps) {
                if (lp.LearnerContactId != null && lp.LearnerContact != null) {
                    contactNameById.put(lp.LearnerContactId, lp.LearnerContact.Name);
                }
            }
            for (Id contactId : contactToEnrollment.keySet()) {
                if (profiledContactIds.contains(contactId)) {
                    continue;
                }
                if (!canCreateProfileWithEnrollmentLookup()) {
                    throw new AuraHandledException(
                        'Unable to create LearnerProfile for contact ' + contactId +
                        '. Create access for LearnerProfile, Name, ContactId, and AcademicTermEnrollmentId is required.'
                        );
                }
                String contactName = contactNameById.get(contactId);
                String learnerProfileName = String.isBlank(contactName)
                    ? 'Learner Profile - ' + String.valueOf(contactId)
                    : contactName;
                profilesToInsert.add(new LearnerProfile(
                    Name = learnerProfileName,
                ContactId = contactId,
                AcademicTermEnrollmentId = contactToEnrollment.get(contactId).Id
                    ));
            }
            if (!profilesToInsert.isEmpty()) {
                Database.SaveResult[] profileInsertResults =
                    Database.insert(profilesToInsert, false, AccessLevel.USER_MODE);
                for (Database.SaveResult sr : profileInsertResults) {
                    if (!sr.isSuccess()) {
                        Database.Error err = sr.getErrors()[0];
                        throw new AuraHandledException(
                            'Failed to create LearnerProfile. Field access or sharing issue: ' +
                            err.getStatusCode() + ' - ' + err.getMessage()
                            );
                    }
                }
            }
            List<LearnerProgram> programsToUpdate = new List<LearnerProgram>();
            Integer academicYearStart =
                Integer.valueOf(nextTerm.Start_Year__c);
            for (LearnerProgram lp : lps) {
                String cadenceType =
                    lp.LearningProgramPlan.Cadence_Type__c;
                Integer cadenceFactor =
                    getCadenceFactor(cadenceType);
                Integer seasonNumber =
                    getSeasonNumber(cadenceType, nextTerm.Season);
                if (cadenceFactor == null || seasonNumber == null) {
                    continue;
                }
                Integer programPlanStartYear =
                    Integer.valueOf(lp.LearningProgramPlan.Start_Year__c);
                Integer cadencePeriod =
                    (academicYearStart - programPlanStartYear)
                     * cadenceFactor
                + seasonNumber;
                programsToUpdate.add(new LearnerProgram(
                    Id = lp.Id,
                Cadence_Type__c = cadenceType,
                Cadence_Period__c = cadenceType + ' '+String.valueOf(cadencePeriod)
                    ));
            }
            if (!programsToUpdate.isEmpty()) {
                update as user programsToUpdate;
            }
        } catch (Exception e) {
            KenAuditLogHelper.auditLogRecord(
                'Academic Term Enrollment',
            'AcademicTermEnrollmentController'
                )
                .setErrorMessage(e.getMessage())
                .setStackTrace(e.getStackTraceString())
                .create();
            throw e;
        }
    }
    /**
     * @description
     *  Returns the cadence multiplier based on cadence type.
     *
     * @param cadenceType Cadence type (Semester, Trimester, Quarter)
     * @return Integer
     *         Numeric factor representing the cadence frequency.
     */
    private static Integer getCadenceFactor(String cadenceType) {
        if (cadenceType == KenConstantController.CADENCE_SEMESTER) {
            return 2;
        }
        if (cadenceType == KenConstantController.CADENCE_TRIMESTER) {
            return 3;
        }
        if (cadenceType == KenConstantController.CADENCE_QUARTER) {
            return 4;
        }
        return 0;
    }
    /**
     * @description
     *  Returns the numeric order of the season based on cadence type.
     *
     * @param cadenceType Cadence type (Semester, Trimester, Quarter)
     * @param season      Academic Term season name
     * @return Integer
     *         Season sequence number or null if not applicable.
     */
    private static Integer getSeasonNumber(String cadenceType, String season) {
        Map<String, Integer> semesterMap = new Map<String, Integer>{
            KenConstantController.SEASON_FALL => 1,
            KenConstantController.SEASON_SPRING => 2
        };
        Map<String, Integer> trimesterMap = new Map<String, Integer>{
            KenConstantController.SEASON_FALL => 1,
            KenConstantController.SEASON_SPRING => 2,
            KenConstantController.SEASON_SUMMER => 3
        };
        Map<String, Integer> quarterMap = new Map<String, Integer>{
            KenConstantController.SEASON_FALL => 1,
            KenConstantController.SEASON_WINTER => 2,
            KenConstantController.SEASON_SPRING => 3,
            KenConstantController.SEASON_SUMMER => 4
        };
        if (cadenceType == KenConstantController.CADENCE_SEMESTER) {
            return semesterMap.get(season);
        }
        if (cadenceType == KenConstantController.CADENCE_TRIMESTER){
            return trimesterMap.get(season);
        }
        if (cadenceType == KenConstantController.CADENCE_QUARTER) {
            return quarterMap.get(season);
        }
        return null;
    }
}