/**
 * @description
 *
 * Usage:
 *  - No direct callers found
 */
public with sharing class UserImportBatch implements Database.Batchable<Map<String, Object>>, Database.Stateful {
    private final String jsonRows;
    private final String userType;
    private final Id learningProgramPlanId;
    private final String section;
    private final String cycle;
    private List<Audit_Log__c> pendingLogs = new List<Audit_Log__c>();

    public UserImportBatch(String jsonRows, String userType, Id learningProgramPlanId, String section, String cycle) {
        this.jsonRows = jsonRows;
        this.userType = String.isBlank(userType) ? 'Faculty' : userType;
        this.learningProgramPlanId = learningProgramPlanId;
        this.section = section;
        this.cycle = cycle;
    }

    public UserImportBatch(String jsonRows, String userType, Id learningProgramPlanId, String section) {
        this(jsonRows, userType, learningProgramPlanId, section, null);
    }

    public UserImportBatch(String jsonRows, String userType, Id learningProgramPlanId) {
        this(jsonRows, userType, learningProgramPlanId, null, null);
    }
    
    public Iterable<Map<String, Object>> start(Database.BatchableContext bc) {
        List<Map<String, Object>> maps = new List<Map<String, Object>>();
        if (String.isBlank(jsonRows)) {return maps;}
        List<Object> rows = (List<Object>) JSON.deserializeUntyped(jsonRows);
        for (Object o : rows) {
            if (o instanceof Map<String, Object>) {maps.add((Map<String, Object>) o);}
        }
        return maps;
    }
    
    public void execute(Database.BatchableContext bc, List<Map<String, Object>> scope) {
        Id jobId = bc != null ? bc.getJobId() : null;
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Account')) {return;}
        
        Boolean isStudentImport = String.valueOf(userType).trim().toLowerCase() == 'student';
        Schema.SObjectType accountType = gd.get('Account');
        Map<String, Schema.SObjectField> accountFields = accountType.getDescribe().fields.getMap();
        Id personRtId = getPersonAccountRecordTypeId(userType);
        if (personRtId == null) {
            writeAuditLog('Person Account record type not found for ' + userType, jobId);
            return;
        }
        
        String roleObjName = resolveObjectName(gd, new List<String>{'ConstituentRole'});
        Schema.SObjectType roleType = roleObjName != null ? gd.get(roleObjName) : null;
        Map<String, Schema.SObjectField> roleFields = roleType != null ? roleType.getDescribe().fields.getMap() : new Map<String, Schema.SObjectField>();
        String rolePersonField = resolveLinkField(roleFields, new List<String>{'PersonId', 'ContactId', 'Person__c'});
        String roleTypeField = resolveFieldName(roleFields, new List<String>{'RoleType', 'Role_Type__c'});
        String roleStatusField = resolveFieldName(roleFields, new List<String>{'Status', 'Status__c'});
            
        String learnerProfileObjName = resolveObjectName(gd, new List<String>{'LearnerProfile'});
        Schema.SObjectType learnerProfileType = learnerProfileObjName != null ? gd.get(learnerProfileObjName) : null;
        Map<String, Schema.SObjectField> learnerProfileFields = learnerProfileType != null ? learnerProfileType.getDescribe().fields.getMap() : new Map<String, Schema.SObjectField>();
        String learnerProfileContactField = resolveLinkField(learnerProfileFields, new List<String>{'ContactId', 'Contact__c'});
        
        String contactProfileObjName = resolveObjectName(gd, new List<String>{'ContactProfile', 'ContactProfile__c', 'Contact_Profile__c', 'EDU_Contact_Profile__c', 'EDU_ContactProfile__c'});
        Schema.SObjectType contactProfileType = contactProfileObjName != null ? gd.get(contactProfileObjName) : null;
        Map<String, Schema.SObjectField> contactProfileFields = contactProfileType != null ? contactProfileType.getDescribe().fields.getMap() : new Map<String, Schema.SObjectField>();
        String contactProfileContactField = resolveLinkField(contactProfileFields, new List<String>{'ContactId', 'Contact__c'});
        
        String learnerProgramObjName = resolveObjectName(gd, new List<String>{'LearnerProgram'});
        Schema.SObjectType learnerProgramType = learnerProgramObjName != null ? gd.get(learnerProgramObjName) : null;
        Map<String, Schema.SObjectField> learnerProgramFields = learnerProgramType != null
            ? learnerProgramType.getDescribe().fields.getMap()
            : new Map<String, Schema.SObjectField>();
        String learnerProgramContactField = resolveLinkField(learnerProgramFields, new List<String>{'LearnerContactId', 'LearnerContact__c'});
        String learnerProgramAccountField = resolveLinkField(learnerProgramFields, new List<String>{'LearnerAccountId', 'LearnerAccount__c'});
        String learnerProgramPlanField = resolveLinkField(learnerProgramFields, new List<String>{'LearningProgramPlanId', 'LearningProgramPlan__c'});
        
        Set<String> incomingEmails = new Set<String>();
        Set<String> learnerAccountNames = new Set<String>();
        for (Map<String, Object> row : scope) {
            if (row == null) {continue;}
            String email = getRowValue(row, 'Email');
            if (String.isNotBlank(email)) {
                incomingEmails.add(email.toLowerCase());
            }
            if (isStudentImport) {
                String learnerAccountName = getRowValue(row, 'Account Name');
                if (String.isNotBlank(learnerAccountName)) {
                    learnerAccountNames.add(learnerAccountName);
                }
            }
        }
        
        Map<String, Account> existingAccountByEmail = new Map<String, Account>();
        if (!incomingEmails.isEmpty()) {
            for (Account existingAccount : [
                SELECT Id, PersonContactId, PersonEmail
                FROM Account
                WHERE IsPersonAccount = true
                AND PersonEmail IN :incomingEmails
            ]) {
                if (String.isNotBlank(existingAccount.PersonEmail)) {
                    existingAccountByEmail.put(existingAccount.PersonEmail.trim().toLowerCase(), existingAccount);
                }
            }
        }
        
        Map<String, Id> learnerAccountIdByName = new Map<String, Id>();
        if (!learnerAccountNames.isEmpty()) {
            for (Account learnerAccount : [
                SELECT Id, Name
                FROM Account
                WHERE Name IN :learnerAccountNames
            ]) {
                learnerAccountIdByName.put(learnerAccount.Name.trim().toLowerCase(), learnerAccount.Id);
            }
        }
        
        LearningProgramPlan selectedPlan;
        if (isStudentImport && learningProgramPlanId != null) {
            selectedPlan = [
                SELECT Id, Name, ActiveFromDate, ActiveToDate, Cadence_Type__c
                FROM LearningProgramPlan
                WHERE Id = :learningProgramPlanId
                LIMIT 1
            ];
        }
        
        Set<String> seenEmails = new Set<String>();
        List<Map<String, Object>> rowMaps = new List<Map<String, Object>>();
        List<SObject> personAccounts = new List<SObject>();
        List<Boolean> personAccountIsInsert = new List<Boolean>();
        List<Integer> personAccountRowIndexes = new List<Integer>();
        List<Id> existingContactIdByRow = new List<Id>();
        
        for (Integer i = 0; i < scope.size(); i++) {
            Map<String, Object> row = scope[i];
            if (row == null) {continue;}
            String email = getRowValue(row, 'Email');
            if (String.isBlank(email)) {
                writeAuditLog('Row ' + String.valueOf(i + 1) + ': Email is required.', jobId);
                continue;
            }
            String emailKey = email.toLowerCase();
            if (seenEmails.contains(emailKey)) {
                logDuplicate('Duplicate in file', i, scope, email, getRowValueFromKeys(row, new List<String>{'Last Name', 'LastName'}), jobId);
                continue;
            }
            seenEmails.add(emailKey);
            
            Account existingAccount = existingAccountByEmail.get(emailKey);
            Boolean isInsert = existingAccount == null;
            SObject personAccount = isInsert ? accountType.newSObject() : accountType.newSObject(existingAccount.Id);
            if (isInsert) {
                personAccount.put('RecordTypeId', personRtId);
                putAccountValue(personAccount, accountFields, new List<String>{'IsActive', 'Is_Active__c', 'Active__c'}, true, true);
            }
            
            putAccountValue(personAccount, accountFields, new List<String>{'FirstName', 'PersonFirstName'}, getRowValueFromKeys(row, new List<String>{'First Name', 'FirstName'}), isInsert);
            putAccountValue(personAccount, accountFields, new List<String>{'LastName', 'PersonLastName'}, getRowValueFromKeys(row, new List<String>{'Last Name', 'LastName'}), isInsert);
            putAccountValue(personAccount, accountFields, new List<String>{'PersonEmail', 'Email'}, row.get('Email'), isInsert);
            putAccountValue(personAccount, accountFields, new List<String>{'Phone', 'PersonMobilePhone'}, row.get('Phone'), isInsert);
            putAccountValue(personAccount, accountFields, new List<String>{'Birthdate', 'PersonBirthdate'}, row.get('DOB'), isInsert);
            putAccountValue(personAccount, accountFields, new List<String>{'PersonTitle', 'Title'}, userType, isInsert);
            
            if (!isStudentImport) {
                putAccountValue(personAccount, accountFields, new List<String>{'Employee_ID__pc', 'Employee_ID__c', 'ExternalId__pc', 'External_Id__pc'}, row.get('Employee ID'), isInsert);
            }
            
            rowMaps.add(row);
            personAccounts.add(personAccount);
            personAccountIsInsert.add(isInsert);
            personAccountRowIndexes.add(rowMaps.size() - 1);
            existingContactIdByRow.add(existingAccount != null ? existingAccount.PersonContactId : null);
        }
        
        List<Id> contactIdByRow = initializeIdList(rowMaps.size());
        List<Id> accountIdByRow = initializeIdList(rowMaps.size());
        if (!personAccounts.isEmpty()) {
            List<SObject> accountInserts = new List<SObject>();
            List<Integer> insertRowIndexes = new List<Integer>();
            List<SObject> accountUpdates = new List<SObject>();
            List<Integer> updateRowIndexes = new List<Integer>();
            for (Integer i = 0; i < personAccounts.size(); i++) {
                if (personAccountIsInsert[i]) {
                    accountInserts.add(personAccounts[i]);
                    insertRowIndexes.add(personAccountRowIndexes[i]);
                } else {
                    accountUpdates.add(personAccounts[i]);
                    updateRowIndexes.add(personAccountRowIndexes[i]);
                }
            }
            
            if (!accountInserts.isEmpty()) {
                Database.SaveResult[] results = Database.insert(accountInserts, false);
                for (Integer i = 0; i < results.size(); i++) {
                    Integer rowIndex = insertRowIndexes[i];
                    if (results[i].isSuccess()) {
                        accountIdByRow[rowIndex] = (Id) accountInserts[i].get('Id');
                    } else {
                        logSaveResultErrors('Person Account insert', rowIndex, rowMaps, results[i], jobId);
                    }
                }
            }
            if (!accountUpdates.isEmpty()) {
                Database.SaveResult[] results = Database.update(accountUpdates, false);
                for (Integer i = 0; i < results.size(); i++) {
                    Integer rowIndex = updateRowIndexes[i];
                    if (results[i].isSuccess()) {
                        accountIdByRow[rowIndex] = (Id) accountUpdates[i].get('Id');
                    } else {
                        logSaveResultErrors('Person Account update', rowIndex, rowMaps, results[i], jobId);
                    }
                }
            }
            
            Set<Id> accountIds = new Set<Id>();
            for (Id accountIdValue : accountIdByRow) {
                if (accountIdValue != null) {
                    accountIds.add(accountIdValue);
                }
            }
            if (!accountIds.isEmpty()) {
                Map<Id, Account> accountById = new Map<Id, Account>([
                    SELECT Id, PersonContactId
                    FROM Account
                    WHERE Id IN :accountIds
                ]);
                for (Integer i = 0; i < accountIdByRow.size(); i++) {
                    if (accountIdByRow[i] != null && accountById.containsKey(accountIdByRow[i])) {
                        contactIdByRow[i] = accountById.get(accountIdByRow[i]).PersonContactId;
                    } else if (existingContactIdByRow.size() > i) {
                        contactIdByRow[i] = existingContactIdByRow[i];
                    }
                }
            }
        }
        
        syncConstituentRoles(
            rowMaps,
            contactIdByRow,
            roleType,
            roleFields,
            rolePersonField,
            roleTypeField,
            roleStatusField,
            isStudentImport,
            jobId
        );
        
        syncContactProfiles(rowMaps, contactIdByRow, contactProfileType, contactProfileFields, contactProfileContactField, jobId);
        
        if (isStudentImport) {
            syncLearnerProfiles(rowMaps, contactIdByRow, learnerProfileType, learnerProfileFields, learnerProfileContactField, jobId);
            syncLearnerPrograms(
                rowMaps,
            contactIdByRow,
            learnerAccountIdByName,
            learnerProgramType,
            learnerProgramFields,
            learnerProgramContactField,
            learnerProgramAccountField,
            learnerProgramPlanField,
            selectedPlan,
            jobId
                );
        }
        
        flushAuditLogs();
    }
    
    public void finish(Database.BatchableContext bc) {}
    
    private void syncConstituentRoles(
        List<Map<String, Object>> rowMaps,
        List<Id> contactIdByRow,
        Schema.SObjectType roleType,
        Map<String, Schema.SObjectField> roleFields,
        String rolePersonField,
        String roleTypeField,
        String roleStatusField,
        Boolean isStudentImport,
        Id jobId
    ) {
        if (roleType == null || String.isBlank(rolePersonField) || String.isBlank(roleTypeField)) {return;}
        Set<Id> contactIds = new Set<Id>();
        for (Id contactId : contactIdByRow) {
            if (contactId != null) {contactIds.add(contactId);}
        }
        if (contactIds.isEmpty()) {return;}
        
        Map<String, Id> existingRoleIdByKey = new Map<String, Id>();
        for (SObject existingRole : Database.query(
            'SELECT Id, ' + rolePersonField + ', ' + roleTypeField +
            ' FROM ConstituentRole WHERE ' + rolePersonField + ' IN :contactIds AND ' + roleTypeField + ' = :userType'
        )) {
            Id contactId = (Id) existingRole.get(rolePersonField);
            String roleTypeValue = existingRole.get(roleTypeField) == null ? null : String.valueOf(existingRole.get(roleTypeField)).trim().toLowerCase();
            if (contactId != null && String.isNotBlank(roleTypeValue)) {
                existingRoleIdByKey.put(String.valueOf(contactId) + '|' + roleTypeValue, (Id) existingRole.get('Id'));
            }
        }
        
        List<SObject> roleInserts = new List<SObject>();
        List<Integer> roleInsertRows = new List<Integer>();
        List<SObject> roleUpdates = new List<SObject>();
        List<Integer> roleUpdateRows = new List<Integer>();
        for (Integer i = 0; i < rowMaps.size(); i++) {
            if (i >= contactIdByRow.size() || contactIdByRow[i] == null) {continue;}
            Id contactId = contactIdByRow[i];
            String key = String.valueOf(contactId) + '|' + userType.toLowerCase();
            Boolean isInsert = !existingRoleIdByKey.containsKey(key);
            SObject roleRecord = isInsert ? roleType.newSObject() : roleType.newSObject(existingRoleIdByKey.get(key));
            putFieldIfAllowed(roleRecord, roleFields, rolePersonField, contactId, isInsert);
            putFieldIfAllowed(roleRecord, roleFields, roleTypeField, userType, isInsert);
            if (String.isNotBlank(roleStatusField)) {
                putFieldIfAllowed(roleRecord, roleFields, roleStatusField, 'Active', isInsert);
            }
            if (isStudentImport == true) {
                putByCandidates(
                    roleRecord,
                    roleFields,
                    new List<String>{'Student_ID__c', 'StudentIdNumber', 'StudentIdentification'},
                    rowMaps[i].get('Student ID'),
                    isInsert
                );
            }
            if (isInsert) {
                roleInserts.add(roleRecord);
                roleInsertRows.add(i);
            } else {
                roleUpdates.add(roleRecord);
                roleUpdateRows.add(i);
            }
        }
        saveRecords('Constituent Role insert', roleInserts, roleInsertRows, rowMaps, jobId, true);
        saveRecords('Constituent Role update', roleUpdates, roleUpdateRows, rowMaps, jobId, false);
    }
    
    private void syncLearnerProfiles(
        List<Map<String, Object>> rowMaps,
    List<Id> contactIdByRow,
    Schema.SObjectType profileType,
    Map<String, Schema.SObjectField> profileFields,
    String profileContactField,
    Id jobId
    ) {
        if (profileType == null || String.isBlank(profileContactField)) {return;}
        Set<Id> contactIds = new Set<Id>();
        for (Id contactId : contactIdByRow) {
            if (contactId != null) {contactIds.add(contactId);}
        }
        if (contactIds.isEmpty()) {return;}
        
        Map<Id, SObject> existingProfileByContact = new Map<Id, SObject>();
        for (SObject existingProfile : Database.query(
            'SELECT Id, ' + profileContactField + ' FROM ' + profileType.getDescribe().getName() +
            ' WHERE ' + profileContactField + ' IN :contactIds'
        )) {
            Id contactId = (Id) existingProfile.get(profileContactField);
            if (contactId != null) {
                existingProfileByContact.put(contactId, existingProfile);
            }
        }
        
        List<SObject> profileInserts = new List<SObject>();
        List<Integer> profileInsertRows = new List<Integer>();
        List<SObject> profileUpdates = new List<SObject>();
        List<Integer> profileUpdateRows = new List<Integer>();
        for (Integer i = 0; i < rowMaps.size(); i++) {
            if (i >= contactIdByRow.size() || contactIdByRow[i] == null) {continue;}
            Id contactId = contactIdByRow[i];
            Boolean isInsert = !existingProfileByContact.containsKey(contactId);
            SObject profile = isInsert ? profileType.newSObject() : profileType.newSObject((Id) existingProfileByContact.get(contactId).get('Id'));
            putFieldIfAllowed(profile, profileFields, profileContactField, contactId, isInsert);
            putByCandidates(profile, profileFields, new List<String>{'Name'}, buildFullName(rowMaps[i]), isInsert);
            putByCandidates(profile, profileFields, new List<String>{'Email', 'Student_Email__c'}, rowMaps[i].get('Email'), isInsert);
            putByCandidates(profile, profileFields, new List<String>{'StudentIdNumber', 'StudentIdentification', 'Student_ID__c'}, rowMaps[i].get('Student ID'), isInsert);
            putByCandidates(profile, profileFields, new List<String>{'EnrollmentStatus', 'Enrollment_Status__c'}, rowMaps[i].get('Enrollment Status'), isInsert);
            putByCandidates(profile, profileFields, new List<String>{'ExpectedGraduationDate', 'Expected_Graduation_Date__c'}, rowMaps[i].get('Expected Graduation Date'), isInsert);
            putByCandidates(profile, profileFields, new List<String>{'AdmissionDate', 'Admission_Date__c', 'AdmitDate'}, rowMaps[i].get('Admission Date'), isInsert);
            putByCandidates(profile, profileFields, new List<String>{'IsActive', 'Is_Active__c', 'Active__c'}, true, isInsert);
            if (isInsert) {
                profileInserts.add(profile);
                profileInsertRows.add(i);
            } else {
                profileUpdates.add(profile);
                profileUpdateRows.add(i);
            }
        }
        saveRecords('Learner Profile insert', profileInserts, profileInsertRows, rowMaps, jobId, true);
        saveRecords('Learner Profile update', profileUpdates, profileUpdateRows, rowMaps, jobId, false);
    }
    
    private void syncContactProfiles(
        List<Map<String, Object>> rowMaps,
    List<Id> contactIdByRow,
    Schema.SObjectType profileType,
    Map<String, Schema.SObjectField> profileFields,
    String profileContactField,
    Id jobId
    ) {
        if (profileType == null || String.isBlank(profileContactField)) {return;}
        Set<Id> contactIds = new Set<Id>();
        for (Id contactId : contactIdByRow) {
            if (contactId != null) {contactIds.add(contactId);}
        }
        if (contactIds.isEmpty()) {return;}
        
        Map<Id, SObject> existingProfileByContact = new Map<Id, SObject>();
        for (SObject existingProfile : Database.query(
            'SELECT Id, ' + profileContactField + ' FROM ' + profileType.getDescribe().getName() +
            ' WHERE ' + profileContactField + ' IN :contactIds'
        )) {
            Id contactId = (Id) existingProfile.get(profileContactField);
            if (contactId != null) {
                existingProfileByContact.put(contactId, existingProfile);
            }
        }
        
        List<SObject> profileInserts = new List<SObject>();
        List<Integer> profileInsertRows = new List<Integer>();
        List<SObject> profileUpdates = new List<SObject>();
        List<Integer> profileUpdateRows = new List<Integer>();
        for (Integer i = 0; i < rowMaps.size(); i++) {
            if (i >= contactIdByRow.size() || contactIdByRow[i] == null) {continue;}
            Id contactId = contactIdByRow[i];
            Boolean isInsert = !existingProfileByContact.containsKey(contactId);
            SObject profile = isInsert ? profileType.newSObject() : profileType.newSObject((Id) existingProfileByContact.get(contactId).get('Id'));
            putFieldIfAllowed(profile, profileFields, profileContactField, contactId, isInsert);
            putByCandidates(profile, profileFields, new List<String>{'Name'}, buildFullName(rowMaps[i]), isInsert);
            putByCandidates(profile, profileFields, new List<String>{'Email', 'Email__c'}, rowMaps[i].get('Email'), isInsert);
            putByCandidates(profile, profileFields, new List<String>{'Phone', 'Phone__c', 'MobilePhone'}, rowMaps[i].get('Phone'), isInsert);
            putByCandidates(profile, profileFields, new List<String>{'Birthdate', 'DOB__c', 'DateOfBirth__c'}, rowMaps[i].get('DOB'), isInsert);
            putByCandidates(profile, profileFields, new List<String>{'IsActive', 'Is_Active__c', 'Active__c'}, true, isInsert);
            if (isInsert) {
                profileInserts.add(profile);
                profileInsertRows.add(i);
            } else {
                profileUpdates.add(profile);
                profileUpdateRows.add(i);
            }
        }
        saveRecords('Contact Profile insert', profileInserts, profileInsertRows, rowMaps, jobId, true);
        saveRecords('Contact Profile update', profileUpdates, profileUpdateRows, rowMaps, jobId, false);
    }
    
    private void syncLearnerPrograms(
        List<Map<String, Object>> rowMaps,
    List<Id> contactIdByRow,
    Map<String, Id> learnerAccountIdByName,
    Schema.SObjectType learnerProgramType,
    Map<String, Schema.SObjectField> learnerProgramFields,
    String learnerProgramContactField,
    String learnerProgramAccountField,
    String learnerProgramPlanField,
    LearningProgramPlan selectedPlan,
    Id jobId
    ) {
        if (learnerProgramType == null || selectedPlan == null || String.isBlank(learnerProgramContactField) || String.isBlank(learnerProgramPlanField)) {
            return;
        }
        Set<Id> contactIds = new Set<Id>();
        for (Id contactId : contactIdByRow) {
            if (contactId != null) {contactIds.add(contactId);}
        }
        if (contactIds.isEmpty()) {return;}
        
        Map<Id, SObject> existingProgramByContact = new Map<Id, SObject>();
        for (SObject existingProgram : Database.query(
            'SELECT Id, ' + learnerProgramContactField +
            ' FROM ' + learnerProgramType.getDescribe().getName() +
            ' WHERE ' + learnerProgramPlanField + ' = :learningProgramPlanId AND ' + learnerProgramContactField + ' IN :contactIds'
        )) {
            Id contactId = (Id) existingProgram.get(learnerProgramContactField);
            if (contactId != null) {
                existingProgramByContact.put(contactId, existingProgram);
            }
        }
        
        List<SObject> learnerProgramInserts = new List<SObject>();
        List<Integer> learnerProgramInsertRows = new List<Integer>();
        List<SObject> learnerProgramUpdates = new List<SObject>();
        List<Integer> learnerProgramUpdateRows = new List<Integer>();
        for (Integer i = 0; i < rowMaps.size(); i++) {
            if (i >= contactIdByRow.size() || contactIdByRow[i] == null) {continue;}
            Id contactId = contactIdByRow[i];
            Boolean isInsert = !existingProgramByContact.containsKey(contactId);
            SObject learnerProgram = isInsert
                ? learnerProgramType.newSObject()
                : learnerProgramType.newSObject((Id) existingProgramByContact.get(contactId).get('Id'));
            putByCandidates(learnerProgram, learnerProgramFields, new List<String>{'Name'}, buildFullName(rowMaps[i]) + ' ' + selectedPlan.Name, isInsert);
            putFieldIfAllowed(learnerProgram, learnerProgramFields, learnerProgramContactField, contactId, isInsert);
            putFieldIfAllowed(learnerProgram, learnerProgramFields, learnerProgramPlanField, selectedPlan.Id, isInsert);
            if (String.isNotBlank(learnerProgramAccountField)) {
                String learnerAccountName = getRowValue(rowMaps[i], 'Account Name');
                if (String.isNotBlank(learnerAccountName)) {
                    Id learnerAccountId = learnerAccountIdByName.get(learnerAccountName.toLowerCase());
                    if (learnerAccountId != null) {
                        putFieldIfAllowed(learnerProgram, learnerProgramFields, learnerProgramAccountField, learnerAccountId, isInsert);
                    }
                }
            }
            putByCandidates(learnerProgram, learnerProgramFields, new List<String>{'Cadence_Type__c', 'CadenceType'}, selectedPlan.Cadence_Type__c, isInsert);
            putByCandidates(learnerProgram, learnerProgramFields, new List<String>{'StartDate'}, selectedPlan.ActiveFromDate, isInsert);
            putByCandidates(learnerProgram, learnerProgramFields, new List<String>{'EndDate'}, selectedPlan.ActiveToDate, isInsert);
            putByCandidates(learnerProgram, learnerProgramFields, new List<String>{'ClassCohort', 'Class_Cohort__c'}, section, isInsert);
            putByCandidates(learnerProgram, learnerProgramFields, new List<String>{'Cycle__c'}, cycle, isInsert);
            putByCandidates(learnerProgram, learnerProgramFields, new List<String>{'Status', 'Status__c'}, 'Active', isInsert);
            putByCandidates(learnerProgram, learnerProgramFields, new List<String>{'IsActive', 'Is_Active__c', 'Active__c'}, true, isInsert);
            if (isInsert) {
                learnerProgramInserts.add(learnerProgram);
                learnerProgramInsertRows.add(i);
            } else {
                learnerProgramUpdates.add(learnerProgram);
                learnerProgramUpdateRows.add(i);
            }
        }
        saveRecords('Learner Program insert', learnerProgramInserts, learnerProgramInsertRows, rowMaps, jobId, true);
        saveRecords('Learner Program update', learnerProgramUpdates, learnerProgramUpdateRows, rowMaps, jobId, false);

        syncLearnerPathways(rowMaps, contactIdByRow, selectedPlan, jobId);
    }

    private void syncLearnerPathways(
        List<Map<String, Object>> rowMaps,
        List<Id> contactIdByRow,
        LearningProgramPlan selectedPlan,
        Id jobId
    ) {
        if (selectedPlan == null) {return;}
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('LearnerPathway')) {return;}
        Schema.SObjectType lpType = gd.get('LearnerPathway');
        Map<String, Schema.SObjectField> lpFields = lpType.getDescribe().fields.getMap();
        String contactField = resolveFieldName(lpFields, new List<String>{'LearnerContactId', 'LearnerContact__c'});
        if (String.isBlank(contactField)) {return;}

        // Find the default pathway template for this program plan
        List<LearningPathwayTmplPgmPlan> defaultLinks = [
            SELECT LearningPathwayTemplateId, LearningPathwayTemplate.Name
            FROM LearningPathwayTmplPgmPlan
            WHERE LearningProgramPlanId = :selectedPlan.Id
            AND LearningPathwayTemplate.Default__c = true
            LIMIT 1
        ];
        if (defaultLinks.isEmpty() || defaultLinks[0].LearningPathwayTemplate == null) {return;}
        String templateName = defaultLinks[0].LearningPathwayTemplate.Name;
        Id templateId = defaultLinks[0].LearningPathwayTemplateId;
        if (String.isBlank(templateName) || templateId == null) {return;}
        String templateLookupField = resolveFieldName(lpFields, new List<String>{'Learning_Pathway_Template__c', 'LearningPathwayTemplateId'});

        Set<Id> contactIds = new Set<Id>();
        for (Id cid : contactIdByRow) {
            if (cid != null) {contactIds.add(cid);}
        }
        if (contactIds.isEmpty()) {return;}

        // Find existing learner pathways by contact + template
        Set<Id> alreadyEnrolledContacts = new Set<Id>();
        String existingQuery = 'SELECT ' + contactField + ' FROM LearnerPathway WHERE ' + contactField + ' IN :contactIds';
        if (String.isNotBlank(templateLookupField)) {
            existingQuery += ' AND ' + templateLookupField + ' = :templateId';
        } else {
            existingQuery += ' AND Name LIKE :templateName';
        }
        for (SObject existing : Database.query(existingQuery)) {
            Id cid = (Id) existing.get(contactField);
            if (cid != null) {alreadyEnrolledContacts.add(cid);}
        }

        // Build contact name map for pathway naming
        Map<Id, String> contactNameById = new Map<Id, String>();
        for (Integer i = 0; i < rowMaps.size(); i++) {
            if (i >= contactIdByRow.size() || contactIdByRow[i] == null) {continue;}
            contactNameById.put(contactIdByRow[i], buildFullName(rowMaps[i]));
        }

        List<SObject> pathwayInserts = new List<SObject>();
        List<Integer> pathwayInsertRows = new List<Integer>();
        for (Integer i = 0; i < rowMaps.size(); i++) {
            if (i >= contactIdByRow.size() || contactIdByRow[i] == null) {continue;}
            Id contactId = contactIdByRow[i];
            if (alreadyEnrolledContacts.contains(contactId)) {continue;}

            String contactName = contactNameById.get(contactId);
            String pathwayName = (String.isBlank(contactName) ? '' : contactName + ' ') + templateName;

            SObject pathway = lpType.newSObject();
            putFieldIfAllowed(pathway, lpFields, 'Name', pathwayName, true);
            putFieldIfAllowed(pathway, lpFields, contactField, contactId, true);
            if (String.isNotBlank(templateLookupField)) {
                putFieldIfAllowed(pathway, lpFields, templateLookupField, templateId, true);
            }
            putFieldIfAllowed(pathway, lpFields, resolveFieldName(lpFields, new List<String>{'Status', 'Status__c'}), 'Approved', true);
            putFieldIfAllowed(pathway, lpFields, resolveFieldName(lpFields, new List<String>{'IsPrimary', 'Is_Primary__c'}), true, true);
            pathwayInserts.add(pathway);
            pathwayInsertRows.add(i);
        }
        saveRecords('Learner Pathway insert', pathwayInserts, pathwayInsertRows, rowMaps, jobId, true);
    }
    
    private void saveRecords(
        String stage,
    List<SObject> records,
    List<Integer> rowIndexes,
    List<Map<String, Object>> rowMaps,
    Id jobId,
    Boolean isInsert
    ) {
        if (records == null || records.isEmpty()) {return;}
        Database.SaveResult[] results = isInsert ? Database.insert(records, false) : Database.update(records, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                logSaveResultErrors(stage, rowIndexes[i], rowMaps, results[i], jobId);
            }
        }
    }
    
    private static void putAccountValue(
        SObject target,
    Map<String, Schema.SObjectField> fields,
    List<String> candidates,
    Object value,
    Boolean isInsert
    ) {
        putByCandidates(target, fields, candidates, value, isInsert);
    }
    
    private static void putByCandidates(
        SObject target,
    Map<String, Schema.SObjectField> fields,
    List<String> candidates,
    Object value,
    Boolean isInsert
    ) {
        String fieldName = resolveFieldName(fields, candidates);
        if (String.isBlank(fieldName)) {return;}
        putFieldIfAllowed(target, fields, fieldName, value, isInsert);
    }
    
    private static void putFieldIfAllowed(
        SObject target,
    Map<String, Schema.SObjectField> fields,
    String fieldName,
    Object value,
    Boolean isInsert
    ) {
        if (target == null || fields == null || String.isBlank(fieldName) || !fields.containsKey(fieldName)) {return;}
        Schema.DescribeFieldResult d = fields.get(fieldName).getDescribe();
        if ((isInsert && !d.isCreateable()) || (!isInsert && !d.isUpdateable())) {return;}
        try {
            Object converted = KenImportUtils.convertValue(value, d);
            target.put(fieldName, converted);
        } catch (Exception e) {
            // ignore field conversion issues
        }
    }
    
    private static String resolveObjectName(Map<String, Schema.SObjectType> gd, List<String> candidates) {
        if (gd == null || candidates == null) {return null;}
        for (String name : candidates) {
            if (gd.containsKey(name)) {return name;}
        }
        return null;
    }
    
    private static String resolveLinkField(Map<String, Schema.SObjectField> fields, List<String> candidates) {
        return resolveFieldName(fields, candidates);
    }
    
    private static String resolveFieldName(Map<String, Schema.SObjectField> fields, List<String> candidates) {
        if (fields == null || candidates == null) {return null;}
        for (String name : candidates) {
            if (fields.containsKey(name)) {return name;}
        }
        return null;
    }
    
    private static String getRowValue(Map<String, Object> row, String key) {
        if (row == null || String.isBlank(key) || !row.containsKey(key) || row.get(key) == null) {return null;}
        String value = String.valueOf(row.get(key)).trim();
        return String.isBlank(value) ? null : value;
    }
    
    private static String getRowValueFromKeys(Map<String, Object> row, List<String> keys) {
        if (keys == null) {return null;}
        for (String key : keys) {
            String value = getRowValue(row, key);
            if (String.isNotBlank(value)) {
                return value;
            }
        }
        return null;
    }
    
    private static String buildFullName(Map<String, Object> row) {
        String firstName = getRowValueFromKeys(row, new List<String>{'First Name', 'FirstName'});
        String lastName = getRowValueFromKeys(row, new List<String>{'Last Name', 'LastName'});
        if (String.isBlank(firstName)) {return String.isBlank(lastName) ? '' : lastName;}
        if (String.isBlank(lastName)) {return firstName;}
        return firstName + ' ' + lastName;
    }
    
    private static List<Id> initializeIdList(Integer size) {
        List<Id> out = new List<Id>();
        for (Integer i = 0; i < size; i++) {
            out.add(null);
        }
        return out;
    }
    
    private void logSaveResultErrors(String stage, Integer rowIndex, List<Map<String, Object>> rowMaps, Database.SaveResult sr, Id jobId) {
        if (sr == null || sr.isSuccess() || sr.getErrors() == null || sr.getErrors().isEmpty()) {return;}
        Database.Error e = sr.getErrors()[0];
        Integer rowNum = getRowNumber(rowIndex, rowMaps);
        String rowLabel = rowNum != null ? 'Row ' + rowNum : 'Row';
        String rowHint = getRowHint(rowIndex, rowMaps);
        String msg = stage + ' - ' + rowLabel + rowHint + ': ' + e.getMessage();
        writeAuditLog(msg, jobId);
    }
    
    private static String getRowHint(Integer rowIndex, List<Map<String, Object>> rowMaps) {
        if (rowIndex == null || rowMaps == null || rowIndex < 0 || rowIndex >= rowMaps.size()) {return '';}
        Map<String, Object> row = rowMaps[rowIndex];
        if (row == null) {return '';}
        if (row.containsKey('Email') && row.get('Email') != null) {return ' (Email=' + String.valueOf(row.get('Email')) + ')';}
        String lastName = getRowValueFromKeys(row, new List<String>{'Last Name', 'LastName'});
        if (String.isNotBlank(lastName)) {return ' (LastName=' + lastName + ')';}
        return '';
    }
    
    private void writeAuditLog(String message, Id jobId) {
        if (String.isBlank(message)) {return;}
        try {
            KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord('User Import', 'Class:UserImportBatch');
            creator.setErrorMessage(message);
            if (jobId != null) {creator.setRecordId(String.valueOf(jobId));}
            Audit_Log__c log = creator.returnWithoutCreate();
            if (log != null) {pendingLogs.add(log);}
        } catch (Exception ex) {
            // avoid batch failure due to logging
        }
    }
    
    private void logDuplicate(String reason, Integer rowIndex, List<Map<String, Object>> rows, String email, String lastName, Id jobId) {
        Integer rowNum = getRowNumber(rowIndex, rows);
        String rowLabel = rowNum != null ? 'Row ' + rowNum : 'Row';
        String msg = userType + ' duplicate skipped (' + reason + ') - ' + rowLabel + ' (Email=' + email + ', LastName=' + lastName + ')';
        writeAuditLog(msg, jobId);
    }
    
    private static Integer getRowNumber(Integer rowIndex, List<Map<String, Object>> rows) {
        if (rowIndex == null || rows == null || rowIndex < 0 || rowIndex >= rows.size()) {return null;}
        Map<String, Object> row = rows[rowIndex];
        if (row != null && row.containsKey('RowNumber') && row.get('RowNumber') != null) {
            try {
                return Integer.valueOf(String.valueOf(row.get('RowNumber')).trim());
            } catch (Exception e) {
                // fall through to index
            }
        }
        return rowIndex + 1;
    }
    
    private void flushAuditLogs() {
        if (pendingLogs == null || pendingLogs.isEmpty()) {return;}
        try {
            Database.DMLOptions dmlOptions = new Database.DMLOptions();
            dmlOptions.allowFieldTruncation = true;
            Database.insert(pendingLogs, dmlOptions);
        } catch (Exception ex) {
            // ignore logging failures
        } finally {
            pendingLogs.clear();
        }
    }
    
    private static Id getPersonAccountRecordTypeId(String importType) {
        List<String> candidates = new List<String>{
            'Person_Account',
            'Person Account'
        };
        for (String candidate : candidates) {
            Id recordTypeId = getAccountRecordTypeId(candidate, true);
            if (recordTypeId != null) {return recordTypeId;}
        }
        return getAnyPersonAccountRecordTypeId();
    }
    
    private static Id getBusinessAccountRecordTypeId(String recordTypeDevName) {
        return getAccountRecordTypeId(recordTypeDevName, false);
    }
    
    private static Id getAccountRecordTypeId(String recordTypeDevName, Boolean personOnly) {
        if (String.isBlank(recordTypeDevName)) {return null;}
        String soql =
            'SELECT Id FROM RecordType WHERE SObjectType = \'Account\' ' +
            'AND (DeveloperName = :recordTypeDevName OR Name = :recordTypeDevName)';
        if (personOnly == true) {
            soql += ' AND IsPersonType = true';
        } else if (personOnly == false) {
            soql += ' AND IsPersonType = false';
        }
        soql += ' LIMIT 1';
        List<RecordType> rts = Database.query(soql);
        return rts.isEmpty() ? null : rts[0].Id;
    }
    
    private static Id getAnyPersonAccountRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND IsPersonType = true
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }
}