/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : ProgramEnrollmentController
 * Author          : Sureka A R K
 * Created Date    : Jan 28, 2026
 * Last Modified By: Sureka A R K
 * Last Modified On: Jan 28, 2026
 * Description     : This class implements for......
 *
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jan 28, 2026  │ Sureka A R K   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public with sharing class ProgramEnrollmentController {
    
    /**
     * @description Retrieves all Institute Accounts.
     * @return List<Account> List of Institute accounts sorted by Name.
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getInstitutes() {
        Id rtId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('Institute')
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
     *  Retrieves all Institute Departments (Program Specializations).
     *
     * @return List<Account>
     *         List of department accounts sorted by Name.
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getInstituteDepartment() {
        Id rtId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('Program_Specialization')
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
        if (learningProgramId == null) {
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
        if (learningProgramPlanId == null){
            return new List<LearningPathwayTmplPgmPlan>();
        }
        
        return [
            SELECT Id,
                   LearningProgramPlanId,
                   LearningPathwayTemplateId,
                   LearningPathwayTemplate.Name
            FROM LearningPathwayTmplPgmPlan
            WHERE LearningProgramPlanId = :learningProgramPlanId and LearningPathwayTemplate.Default__c = true
             ORDER BY LearningPathwayTemplate.Name 
        ];
    }
    // ==============================
    // DTO
    // ==============================
    public class StudentDTO {
        @AuraEnabled public Id applicationId;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
    }
    
    // ==============================
    // FETCH STUDENTS
    // ==============================
    @AuraEnabled(cacheable=true)
    public static List<StudentDTO> fetchEnrolledStudents(
        Id learningProgramId
    ) {
        List<StudentDTO> result = new List<StudentDTO>();
        
        for (IndividualApplication app : [
            SELECT Id,
                   ContactId,
                   Contact.Name,
                   Contact.Email
            FROM IndividualApplication
            WHERE Status = 'Enrolled'
            
        ]) {
            StudentDTO dto = new StudentDTO();
            dto.applicationId = app.Id;
            dto.contactId = app.ContactId;
            dto.name = app.Contact.Name;
            dto.email = app.Contact.Email;
            result.add(dto);
        }
        return result;
    }
    
    // ==============================
    // ENROLL STUDENTS
    // ==============================
    public class EnrollRequest {
        @AuraEnabled public List<Id> contactIds;
        @AuraEnabled public Id instituteId;
        @AuraEnabled public Id learningProgramPlanId;
        @AuraEnabled public Id learningPathwayTemplateId;
        @AuraEnabled public String section;
    }
    
    @AuraEnabled
    public static void enrollStudents(
        List<Id> contactIds,
    Id instituteId,
    Id learningProgramPlanId,
    Id learningPathwayTemplateId,
    String section
    ) {
        if (contactIds == null || contactIds.isEmpty()) {
            throw new AuraHandledException('No students selected for enrollment.');
        }
        LearningProgramPlan plan = fetchPlan(learningProgramPlanId);
        AcademicTerm firstTerm = fetchFirstTerm(plan);
        
        Map<Id, LearnerProfile> profileByContact = ensureLearnerProfiles(contactIds);
        
        // Reuse existing helper
        EnrollRequest req = new EnrollRequest();
        req.contactIds = contactIds;
        req.instituteId = instituteId;
        req.learningProgramPlanId = learningProgramPlanId;
        req.learningPathwayTemplateId = learningPathwayTemplateId;
        req.section = section;
        
        List<LearnerProgram> learnerPrograms =
            buildLearnerPrograms(req, plan, profileByContact);
        
        insertWithUserModeOrThrow(learnerPrograms, 'Learner Programs');
        
        List<AcademicTermEnrollment> termEnrollments =
            buildTermEnrollments(instituteId, firstTerm.Id, learnerPrograms);
        
        insertWithUserModeOrThrow(termEnrollments, 'Academic Term Enrollments');
        List<LearnerProfile> profilesToUpdate = new List<LearnerProfile>();
        
        for (AcademicTermEnrollment ate : termEnrollments) {
            LearnerProfile lp = profileByContact.get(ate.LearnerContactId);
            if (lp != null) {
                lp.AcademicTermEnrollmentId = ate.Id;
                profilesToUpdate.add(lp);
            }
        }
        
        if (!profilesToUpdate.isEmpty()) {
            // Validate object- and field-level permissions before DML to satisfy security and PMD rules
            if (!Schema.sObjectType.LearnerProfile.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update Learner Profiles.');
            }
            // Validate field-level security for the field being updated
            if (!Schema.sObjectType.LearnerProfile.fields.AcademicTermEnrollmentId.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update Academic Term Enrollment on Learner Profiles.');
            }
            update profilesToUpdate;
        }
    }
    
    // Helpers
    private static LearningProgramPlan fetchPlan(Id learningProgramPlanId) {
        if (learningProgramPlanId == null) {
            throw new AuraHandledException('Learning Program Plan Id is required.');
        }
        return [
            SELECT Id, Name, Start_Year__c, Cadence_Type__c, ActiveFromDate, ActiveToDate
            FROM LearningProgramPlan
            WHERE Id = :learningProgramPlanId
            
            LIMIT 1
        ];
    }
    
    private static AcademicTerm fetchFirstTerm(LearningProgramPlan plan) {
        List<AcademicTerm> terms = [
        SELECT Id
        FROM AcademicTerm
        WHERE Start_Year__c = :plan.Start_Year__c
        AND Sequence__c = '1'
        
        LIMIT 1
    ];
        
        if (terms.isEmpty()) {
            throw new AuraHandledException(
                'First Academic Term (Sequence 1) not found for Start Year ' + plan.Start_Year__c
                );
        }
        return terms[0];
    }
    
    
    private static Map<Id, LearnerProfile> ensureLearnerProfiles(List<Id> contactIds) {
        Map<Id, LearnerProfile> existing = new Map<Id, LearnerProfile>();
        for (LearnerProfile lp : [
            SELECT Id, ContactId
            FROM LearnerProfile
            WHERE ContactId IN :contactIds
            
        ]) {
            existing.put(lp.ContactId, lp);
        }
        List<LearnerProfile> toInsert = new List<LearnerProfile>();
        for (Id cId : contactIds) {
            if (!existing.containsKey(cId)) {
                toInsert.add(new LearnerProfile(ContactId = cId, Name = 'Profile - ' + cId));
            }
        }
        if (!toInsert.isEmpty()) {
            Database.SaveResult[] results = Database.insert(toInsert,false, AccessLevel.USER_MODE);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    Database.Error err = results[i].getErrors().isEmpty() ? null : results[i].getErrors()[0];
                    String msg = (err != null) ? err.getMessage() : 'Unknown error while creating Learner Profiles.';
                    throw new AuraHandledException('Insufficient access or validation failure while creating Learner Profiles: ' + msg);
                }
            }
            for (LearnerProfile lp : toInsert) {
                existing.put(lp.ContactId, lp);
            }
        }
        return existing;
    }
    
    private static List<LearnerProgram> buildLearnerPrograms(EnrollRequest req, LearningProgramPlan plan, Map<Id, LearnerProfile> profileByContact) {
        List<LearnerProgram> out = new List<LearnerProgram>();
        for (Id contactId : req.contactIds) {
            LearnerProfile prof = profileByContact.get(contactId);
            out.add(new LearnerProgram(
                Name = 'LP - ' + contactId + ' - ' + plan.Name,
            LearnerContactId = contactId,
            LearnerAccountId = req.instituteId,
            LearningProgramPlanId = req.learningProgramPlanId,
            Cadence_Type__c = plan.Cadence_Type__c,
            StartDate = plan.ActiveFromDate,
            EndDate = plan.ActiveToDate,
            ClassCohort = req.section,
            Status = 'Active'
                ));
        }
        return out;
    }
    @testVisible
    private static List<AcademicTermEnrollment> buildTermEnrollments(Id instituteId, Id firstTermId, List<LearnerProgram> learnerPrograms) {
        List<AcademicTermEnrollment> out = new List<AcademicTermEnrollment>();
        for (LearnerProgram lp : learnerPrograms) {
            out.add(new AcademicTermEnrollment(
                LearnerContactId = lp.LearnerContactId,
            LearnerAccountId = instituteId,
            AcademicTermId = firstTermId,
            EnrollmentStatus = 'Active',
            EnrollmentDate = Date.today()
                ));
        }
        return out;
    }
    
    private static void insertWithUserModeOrThrow(List<SObject> records, String label) {
        if (records == null || records.isEmpty()) {return;}
        Database.SaveResult[] results = Database.insert(records, false, AccessLevel.USER_MODE);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                Database.Error err = results[i].getErrors().isEmpty() ? null : results[i].getErrors()[0];
                String msg = (err != null) ? err.getMessage() : 'Unknown error.';
                throw new AuraHandledException('Insufficient access or validation failure while creating ' + label + ': ' + msg);
            }
        }
    }
}