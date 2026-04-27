@SuppressWarnings('PMD.ExcessivePublicCount')
@isTest
/**
 * @description
 * This class provides factory methods for creating test data records used across multiple test classes.
 * The inner creator classes allow for setting specific fields before inserting records, and also provide a method to return the record without inserting for cases where the test needs to manipulate the record before saving.
 */
public class TestDataFactory {
    
    public class UserCreator {
        private User item;
        /**
         * @description
         * @param profileName
        
         */
        public UserCreator(String profileName) {
            Profile prof;
            if (profileName != null && profileName != '') {
                prof = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
            }
            item = new User();
            item.FirstName = 'Test';
            item.LastName = 'User' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
            item.Email = 'test.user+' + Datetime.now().getTime() + '@example.com';
            item.Username = 'test.user+' + Datetime.now().getTime() + '@example.com';
            item.TimeZoneSidKey = 'GMT';
            item.LocaleSidKey = 'en_US';
            item.EmailEncodingKey = 'UTF-8';
            item.LanguageLocaleKey = 'en_US';
            item.IsActive = true;
            if (prof != null && prof.Id != null) {
                item.ProfileId = prof.Id;
            }
        }
        /**
         * @description
         * @param alias
        
         */
        public UserCreator setAlias(String alias) { if (alias != null) {item.Alias = alias; }return this; }
        public User create() {
            insert item;
            return item;
        }
        /**
         * @description
        
         */
        public User returnWithoutCreate() {
            return item;
        }
    }
    
    public class AccountCreator {
        private Account item;
        /**
         * @description
         * @param name
        
         */
        public AccountCreator(String name) {
            item = new Account(
                Name = name
                );
        }
        /**
         * @description
         * @param street
         * @param city
        
         */
        public AccountCreator setBilling(String street, String city){ item.BillingStreet = street; item.BillingCity = city; return this; }
        public AccountCreator setRecordTypeId(Id recordTypeId) { item.RecordTypeId = recordTypeId; return this; }
        public AccountCreator setParentId(Id parentId) { item.ParentId = parentId; return this; }
        public Account create() {
            insert item;
            return item;
        }
        /**
         * @description
        
         */
        public Account returnWithoutCreate() {
            return item;
        }
    }
    
    public class ContactCreator {
        private Contact item;
        /**
         * @description
        
         */
        public ContactCreator() {
            item = new Contact(
                FirstName = 'Test',
            LastName = 'Contact' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
                );
        }
        /**
         * @description
         * @param accountId
        
         */
        public ContactCreator setAccount(Id accountId){ item.AccountId = accountId; return this; }
        public ContactCreator setLastName(String lastName){ item.LastName = lastName; return this; }
        /**
         * @description
        
         */
        public Contact create() {
            insert item;
            return item;
        }
        /**
         * @description
        
         */
        public Contact returnWithoutCreate() {
            return item;
        }
    }
    
    // Domain-specific creators used by ProgramEnrollment tests
    public class LearningProgramCreator {
        private LearningProgram item;
        /**
         * @description
         * @param name
        
         */
        public LearningProgramCreator(String name) {
            item = new LearningProgram(
                Name = name
                );
        }
        public LearningProgramCreator setLearningId(Id learningId) {
            if (learningId != null && LearningProgram.SObjectType.getDescribe().fields.getMap().containsKey('LearningId')) {
                item.put('LearningId', learningId);
            }
            return this;
        }
        public LearningProgramCreator setCampus(Id campusId) {
            if (campusId != null && LearningProgram.SObjectType.getDescribe().fields.getMap().containsKey('Campus__c')) {
                item.put('Campus__c', campusId);
            }
            return this;
        }
        /**
         * @description
        
         */
        public LearningProgram create() {
            insert item;
            return item;
        }
        /**
         * @description
        
         */
        public LearningProgram returnWithoutCreate() {
            return item;
        }
    }
    
    public class LearningProgramPlanCreator {
        private LearningProgramPlan item;
        /**
         * @description
         * @param learningProgramId
        
         */
        public LearningProgramPlanCreator(Id learningProgramId) {
            item = new LearningProgramPlan(
                Name = 'Plan',
            LearningProgramId = learningProgramId,
            Cadence_Type__c = 'Semester',
            ActiveFromDate = Date.today(),
            ActiveToDate = Date.today().addMonths(6)
                );
        }
        
        /**
         * @description
        
         */
        public LearningProgramPlan create() {
            insert item;
            return item;
        }
        /**
         * @description
        
         */
        public LearningProgramPlan returnWithoutCreate() {
            return item;
        }
    }
    
    public class LearningPathwayTemplateCreator {
        private LearningPathwayTemplate item;
        /**
         * @description
         * @param name
         * @param isDefault
        
         */
        public LearningPathwayTemplateCreator(String name, Boolean isDefault) {
            item = new LearningPathwayTemplate(
                Name = name,
            Default__c = isDefault
                );
        }
        /**
         * @description
        
         */
        public LearningPathwayTemplate create() {
            insert item;
            return item;
        }
        /**
         * @description
        
         */
        public LearningPathwayTemplate returnWithoutCreate() {
            return item;
        }
    }
    
    public class LearningPathwayTmplPgmPlanCreator {
        private LearningPathwayTmplPgmPlan item;
        /**
         * @description
         * @param planId
         * @param tmplId
        
         */
        public LearningPathwayTmplPgmPlanCreator(Id planId, Id tmplId) {
            item = new LearningPathwayTmplPgmPlan(
                LearningProgramPlanId = planId,
            LearningPathwayTemplateId = tmplId
                );
        }
        /**
         * @description
        
         */
        public LearningPathwayTmplPgmPlan create() {
            insert item;
            return item;
        }
        /**
         * @description
        
         */
        public LearningPathwayTmplPgmPlan returnWithoutCreate() {
            return item;
        }
    }
    
    public class AcademicTermCreator {
        private AcademicTerm item;
        
        /**
         * @description
         * @param startYear
         * @param sequence
        
         */
        public AcademicTermCreator(Integer startYear, String sequence) {
            item = new AcademicTerm(
                Name = 'Term',
            Sequence__c = sequence,
            StartDate = Datetime.newInstance(startYear, 1, 1, 12, 0, 0),
            EndDate = Datetime.newInstance(startYear + 1, 1, 1, 12, 0, 0)
                );
        }
        
        /**
         * @description
         * @param startYear
         * @param sequence
         * @param academicYearId
        
         */
        public AcademicTermCreator(Integer startYear, String sequence, Id academicYearId) {
            item = new AcademicTerm(
                Name = 'Term',
            Sequence__c = sequence,
            AcademicYearId = academicYearId,
            StartDate = Datetime.newInstance(startYear, 1, 1, 12, 0, 0),
            EndDate = Datetime.newInstance(startYear + 1, 1, 1, 12, 0, 0)
                );
        }
        
        /**
         * @description
        
         */
        public AcademicTerm create() {
            insert item;
            return item;
        }
        
        /**
         * @description
        
         */
        public AcademicTerm returnWithoutCreate() {
            return item;
        }
    }
    
    public class AcademicYearCreator {
        private AcademicYear item;
        /**
         * @description
         * @param name
         * @param year
        
         */
        public AcademicYearCreator(String name, String year) {
            item = new AcademicYear();
            if (AcademicYear.SObjectType.getDescribe().fields.getMap().containsKey('Name')) {
                item.Name = name;
            }
            if (AcademicYear.SObjectType.getDescribe().fields.getMap().containsKey('Year')) {
                item.put('Year', year);
            }
        }
        /**
         * @description
        
         */
        public AcademicYear create() {
            insert item;
            return item;
        }
        /**
         * @description
        
         */
        public AcademicYear returnWithoutCreate() {
            return item;
        }
    }
    
    public class LearnerProgramCreator {
        private LearnerProgram item;
        /**
         * @description
         * @param contactId
         * @param planId
        
         */
        public LearnerProgramCreator(Id contactId, Id planId) {
            item = new LearnerProgram(
                LearnerContactId = contactId,
            LearningProgramPlanId = planId
                );
            if (LearnerProgram.SObjectType.getDescribe().fields.getMap().containsKey('Name')) {
                item.put('Name', 'LP ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
            }
        }
        /**
         * @description
         * @param cohort
        
         */
        public LearnerProgramCreator setClassCohort(String cohort) {
            if (LearnerProgram.SObjectType.getDescribe().fields.getMap().containsKey('ClassCohort')) {
                item.put('ClassCohort', cohort);
            }
            return this;
        }
        /**
         * @description
        
         */
        public LearnerProgram create() {
            insert item;
            return item;
        }
        /**
         * @description
        
         */
        public LearnerProgram returnWithoutCreate() {
            return item;
        }
    }
    
    public class AcademicTermEnrollmentCreator {
        private AcademicTermEnrollment item;
        /**
         * @description
         * @param termId
         * @param contactId
         * @param accountId
        
         */
        public AcademicTermEnrollmentCreator(Id termId, Id contactId, Id accountId) {
            item = new AcademicTermEnrollment(
                AcademicTermId = termId,
            LearnerContactId = contactId,
            LearnerAccountId = accountId,
            EnrollmentStatus = 'Active',
            EnrollmentDate = Date.today()
                );
        }
        /**
         * @description
        
         */
        public AcademicTermEnrollment create() {
            insert item;
            return item;
        }
        /**
         * @description
        
         */
        public AcademicTermEnrollment returnWithoutCreate() {
            return item;
        }
    }
    
    public class LearnerProfileCreator {
        private LearnerProfile item;
        /**
         * @description
         * @param contactId
        
         */
        public LearnerProfileCreator(Id contactId) {
            item = new LearnerProfile(
                ContactId = contactId
                );
            if (LearnerProfile.SObjectType.getDescribe().fields.getMap().containsKey('Name')) {
                item.put('Name', 'LPF ' + String.valueOf(Math.abs(Crypto.getRandomInteger())));
            }
        }
        /**
         * @description
         * @param ateId
        
         */
        public LearnerProfileCreator setAcademicTermEnrollment(Id ateId) {
            if (LearnerProfile.SObjectType.getDescribe().fields.getMap().containsKey('AcademicTermEnrollmentId')) {
                item.put('AcademicTermEnrollmentId', ateId);
            }
            return this;
        }
        /**
         * @description
        
         */
        public LearnerProfile create() {
            insert item;
            return item;
        }
        /**
         * @description
        
         */
        public LearnerProfile returnWithoutCreate() {
            return item;
        }
    }
    
    public class LearningCreator {
        private Learning item;
        /**
         * @description
         * @param name
        
         */
        public LearningCreator(String name) {
            item = new Learning(
                Name = name
                );
        }
        /**
         * @description
        
         */
        public Learning create() {
            insert item;
            return item;
        }
        /**
         * @description
        
         */
        public Learning returnWithoutCreate() {
            return item;
        }
    }
    
    public class LocationCreator {
        private Schema.Location item;
        
        /**
         * @description
         * @param locationName
         * @param locationType
        
         */
        public LocationCreator(String locationName, String locationType) {
            item = new Schema.Location(
                Name = locationName,
            LocationType = locationType
                );
        }
        
        /**
         * @description
        
         */
        public Schema.Location create() {
            insert item;
            return item;
        }
        
        /**
         * @description
        
         */
        public Schema.Location returnWithoutCreate() {
            return item;
        }
    }
    
    public class PermissionSetAssignmentCreator {
        private String labelOrName;
        /**
         * @description
         * @param labelOrName
         */
        public PermissionSetAssignmentCreator(String labelOrName) {
            this.labelOrName = labelOrName;
        }
        
        /**
         * Attempts to assign the specified Permission Set (by Label or Name) to the user.
         * Returns the PermissionSetAssignment if inserted, otherwise null.
         * @param userId
        
         */
        public PermissionSetAssignment assignToUser(Id userId) {
            if (userId == null || String.isBlank(labelOrName)) {return null;}
            PermissionSet ps;
            List<PermissionSet> found = [
                SELECT Id, Name, Label FROM PermissionSet WHERE Label = :labelOrName LIMIT 1
            ];
            if (found.isEmpty()) {
                found = [SELECT Id, Name, Label FROM PermissionSet WHERE Name = :labelOrName LIMIT 1];
            }
            if (found.isEmpty()) {return null;}
            ps = found[0];
            PermissionSetAssignment psa = new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = ps.Id);
            try {
                insert psa;
                return psa;
            } catch (Exception e) {
                // ignore failures (e.g., already assigned or permission issues) and return null
                return null;
            }
        }
    }
    
    public class IndividualApplicationCreator {
        private IndividualApplication item;
        /**
         * @description
         * @param contactId
         */
        public IndividualApplicationCreator(Id contactId) {
            item = new IndividualApplication(ContactId = contactId);
        }
        /**
         * @description
         * @param status
         */
        public IndividualApplicationCreator setStatus(String status) { item.Status = status; return this; }
        public IndividualApplicationCreator setAccount(Id accountId) {
            item.AccountId = accountId;
            return this;
        }
        /**
         * @description
         * @param category
         */
        public IndividualApplicationCreator setCategory(String category) {
            item.Category = category;
            return this;
        }
        /**
         * @description
         * @param appliedDate
         */
        public IndividualApplicationCreator setAppliedDate(Date appliedDate) {
            if (appliedDate == null) {return this;}
            try { item.put('Applied_Date__c', appliedDate); } catch(Exception e) {}
            try { item.put('AppliedDate__c', appliedDate); } catch(Exception e) {}
            try { item.put('AppliedDate', appliedDate); } catch(Exception e) {}
            return this;
        }
        /**
         * @description
         */
        public IndividualApplication create() {
            insert item;
            return item;
        }
        /**
         * @description
         */
        public IndividualApplication returnWithoutCreate() { return item; }
    }

    public class OrganizationDefaultsParametersCreator {
        private Organization_Default_Parameters__c item;

        /**
         * @description Initializes an org-default settings record for the current org context.
         */
        public OrganizationDefaultsParametersCreator() {
            item = new Organization_Default_Parameters__c();
            item.SetupOwnerId = UserInfo.getOrganizationId();
        }

        /**
         * @description Sets primary color value.
         * @param primaryColor
         * @return
         */
        public OrganizationDefaultsParametersCreator setPrimaryColor(String primaryColor) {
            item.Primary_Color__c = primaryColor;
            return this;
        }

        /**
         * @description Sets secondary color value.
         * @param secondaryColor
         * @return
         */
        public OrganizationDefaultsParametersCreator setSecondaryColor(String secondaryColor) {
            item.Secondary_Color__c = secondaryColor;
            return this;
        }

        /**
         * @description Sets institute name value.
         * @param instituteName
         * @return
         */
        public OrganizationDefaultsParametersCreator setInstituteName(String instituteName) {
            item.Institute_Name__c = instituteName;
            return this;
        }

        /**
         * @description Sets institute alias value.
         * @param instituteAlias
         * @return
         */
        public OrganizationDefaultsParametersCreator setInstituteAlias(String instituteAlias) {
            item.Institute_Alias__c = instituteAlias;
            return this;
        }

        /**
         * @description Sets primary SF theme color value.
         * @param primaryColorForSF
         * @return
         */
        public OrganizationDefaultsParametersCreator setPrimaryColorForSF(String primaryColorForSF) {
            item.Primary_Color_For_SF__c = primaryColorForSF;
            return this;
        }

        /**
         * @description Sets secondary SF theme color value.
         * @param secondaryColorForSF
         * @return
         */
        public OrganizationDefaultsParametersCreator setSecondaryColorForSF(String secondaryColorForSF) {
            item.Secondary_Color_For_SF__c = secondaryColorForSF;
            return this;
        }

        /**
         * @description Inserts or updates the org-default settings record for the current org.
         * @return
         */
        public Organization_Default_Parameters__c create() {
            List<Organization_Default_Parameters__c> existingSettings = [
                SELECT Id
                FROM Organization_Default_Parameters__c
                WHERE SetupOwnerId = :UserInfo.getOrganizationId()
                LIMIT 1
            ];
            if (existingSettings.isEmpty()) {
                insert item;
            } else {
                item.Id = existingSettings[0].Id;
                update item;
            }
            return item;
        }

        /**
         * @description Returns the in-memory settings record without DML.
         * @return
         */
        public Organization_Default_Parameters__c returnWithoutCreate() {
            return item;
        }
    }
    
}