public with sharing class FacultyImportBatch implements Database.Batchable<Map<String, Object>>, Database.Stateful {
    private final String jsonRows;
    private List<Audit_Log__c> pendingLogs = new List<Audit_Log__c>();

    public FacultyImportBatch(String jsonRows) {
        this.jsonRows = jsonRows;
    }

    public Iterable<Map<String, Object>> start(Database.BatchableContext bc) {
        List<Map<String, Object>> maps = new List<Map<String, Object>>();
        if (String.isBlank(jsonRows)) return maps;
        List<Object> rows = (List<Object>) JSON.deserializeUntyped(jsonRows);
        for (Object o : rows) {
            if (o instanceof Map<String, Object>) maps.add((Map<String, Object>) o);
        }
        return maps;
    }

    public void execute(Database.BatchableContext bc, List<Map<String, Object>> scope) {
        Id jobId = bc != null ? bc.getJobId() : null;
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Contact')) return;

        Schema.SObjectType contactType = gd.get('Contact');
        Map<String, Schema.SObjectField> contactFields = contactType.getDescribe().fields.getMap();

        String profileObjName = resolveObjectName(
            gd,
            new List<String>{'ContactProfile', 'ContactProfile__c', 'Contact_Profile__c', 'EDU_Contact_Profile__c', 'EDU_ContactProfile__c'}
        );
        Schema.SObjectType profileType = profileObjName != null ? gd.get(profileObjName) : null;
        Map<String, Schema.SObjectField> profileFields = profileType != null ? profileType.getDescribe().fields.getMap() : new Map<String, Schema.SObjectField>();
        String profileContactField = resolveLinkField(profileFields, new List<String>{'ContactId', 'Contact__c'});

        String roleObjName = resolveObjectName(
            gd,
            new List<String>{'ConstituentRole', 'ConstituentRole__c', 'Constituent_Role__c', 'EDU_Constituent_Role__c', 'EDU_ConstituentRole__c'}
        );
        Schema.SObjectType roleType = roleObjName != null ? gd.get(roleObjName) : null;
        Map<String, Schema.SObjectField> roleFields = roleType != null ? roleType.getDescribe().fields.getMap() : new Map<String, Schema.SObjectField>();
        String rolePersonField = resolveLinkField(roleFields, new List<String>{'PersonId', 'ContactId', 'Person__c'});

        Set<String> contactKeys = new Set<String>{
            'FirstName','LastName','Salutation','Title','AccountId','OwnerId','Phone','MobilePhone','Email','ReportsToId','CurrencyIsoCode',
            'MailingStreet','MailingCity','MailingState','MailingPostalCode','MailingCountry',
            'OtherStreet','OtherCity','OtherState','OtherPostalCode','OtherCountry',
            'Fax','HomePhone','OtherPhone','AssistantName','AssistantPhone',
            'LeadSource','Birthdate','Department','Description'
        };
        Set<String> profileKeys = new Set<String>{
            'BirthPlace','Ethnicity','MilitaryBranch','MilitaryService','HighestEducationLevel','Race','IsFirstGenerationStudent',
            'PrimaryCitizenshipType','BirthCountryId','PrimaryCitizenshipId','SecondaryCitizenshipId'
        };
        Set<String> roleKeys = new Set<String>{'Status','EffectiveStartDate','EffectiveEndDate','ContextRecordId'};

        Set<String> roleStatusValues = new Set<String>();
        if (roleFields.containsKey('Status')) {
            roleStatusValues = getPicklistValues(roleFields.get('Status').getDescribe());
        }

        Set<String> incomingEmails = new Set<String>();
        for (Map<String, Object> row : scope) {
            if (row == null) continue;
            String em = row.get('Email') == null ? null : String.valueOf(row.get('Email')).trim().toLowerCase();
            String ln = row.get('LastName') == null ? null : String.valueOf(row.get('LastName')).trim().toLowerCase();
            if (String.isNotBlank(em) && String.isNotBlank(ln)) {
                incomingEmails.add(em);
            }
        }

        Map<String, Set<String>> existingByEmail = new Map<String, Set<String>>();
        if (!incomingEmails.isEmpty()) {
            for (Contact c : [SELECT Email, LastName FROM Contact WHERE Email IN :incomingEmails]) {
                if (String.isBlank(c.Email) || String.isBlank(c.LastName)) continue;
                String em = c.Email.trim().toLowerCase();
                String ln = c.LastName.trim().toLowerCase();
                if (!existingByEmail.containsKey(em)) existingByEmail.put(em, new Set<String>());
                existingByEmail.get(em).add(ln);
            }
        }

        Set<String> seenKeys = new Set<String>();
        List<SObject> contacts = new List<SObject>();
        List<Map<String, Object>> rowMaps = new List<Map<String, Object>>();
        List<Boolean> hasProfile = new List<Boolean>();
        List<Boolean> hasRole = new List<Boolean>();

        for (Integer i = 0; i < scope.size(); i++) {
            Map<String, Object> row = scope[i];
            if (row == null) continue;
            String emRaw = row.get('Email') == null ? null : String.valueOf(row.get('Email')).trim();
            String lnRaw = row.get('LastName') == null ? null : String.valueOf(row.get('LastName')).trim();
            String em = String.isBlank(emRaw) ? null : emRaw.toLowerCase();
            String ln = String.isBlank(lnRaw) ? null : lnRaw.toLowerCase();
            if (em != null && ln != null) {
                String key = em + '|' + ln;
                if (seenKeys.contains(key)) {
                    logDuplicate('Duplicate in file', i, scope, emRaw, lnRaw, jobId);
                    continue;
                }
                if (existingByEmail.containsKey(em) && existingByEmail.get(em).contains(ln)) {
                    logDuplicate('Duplicate in org', i, scope, emRaw, lnRaw, jobId);
                    continue;
                }
                seenKeys.add(key);
            }

            rowMaps.add(row);
            SObject c = contactType.newSObject();
            Boolean rowHasProfile = false;
            Boolean rowHasRole = false;

            for (String key : row.keySet()) {
                String target = getTargetForKey(key, contactKeys, profileKeys, roleKeys);
                if (target == null) continue;
                if (target == 'Contact') {
                    if (!contactFields.containsKey(key)) continue;
                    Schema.DescribeFieldResult d = contactFields.get(key).getDescribe();
                    if (!d.isCreateable()) continue;
                    try {
                        Object val = ImportUtils.convertValue(row.get(key), d);
                        c.put(key, val);
                    } catch (Exception e) {
                        // ignore conversion errors in batch
                    }
                } else if (target == 'Profile') {
                    rowHasProfile = true;
                } else if (target == 'Role') {
                    rowHasRole = true;
                }
            }

            contacts.add(c);
            hasProfile.add(rowHasProfile);
            hasRole.add(rowHasRole);
        }

        List<Id> contactIdByRow = new List<Id>();
        if (!contacts.isEmpty()) {
            Database.SaveResult[] srs = Database.insert(contacts, false);
            for (Integer i = 0; i < srs.size(); i++) {
                if (srs[i].isSuccess()) {
                    contactIdByRow.add((Id) contacts[i].get('Id'));
                } else {
                    contactIdByRow.add(null);
                    logSaveResultErrors('Contact insert', i, rowMaps, srs[i], jobId);
                }
            }
        }

        if (profileType != null && profileContactField != null) {
            List<SObject> profiles = new List<SObject>();
            List<Integer> profileRowIndexes = new List<Integer>();
            for (Integer i = 0; i < rowMaps.size(); i++) {
                if (i >= contactIdByRow.size() || contactIdByRow[i] == null) continue;
                if (i >= hasProfile.size() || !hasProfile[i]) continue;
                Map<String, Object> row = rowMaps[i];
                SObject p = profileType.newSObject();
                if (profileFields.containsKey(profileContactField)) {
                    Schema.DescribeFieldResult linkField = profileFields.get(profileContactField).getDescribe();
                    if (linkField.isCreateable()) {
                        p.put(profileContactField, contactIdByRow[i]);
                    }
                }
                for (String key : row.keySet()) {
                    String target = getTargetForKey(key, contactKeys, profileKeys, roleKeys);
                    if (target != 'Profile') continue;
                    if (key == profileContactField) continue;
                    if (!profileFields.containsKey(key)) continue;
                    Schema.DescribeFieldResult d = profileFields.get(key).getDescribe();
                    if (!d.isCreateable()) continue;
                    try {
                        Object val = ImportUtils.convertValue(row.get(key), d);
                        p.put(key, val);
                    } catch (Exception e) {
                        // ignore conversion errors in batch
                    }
                }
                profiles.add(p);
                profileRowIndexes.add(i);
            }

            if (!profiles.isEmpty()) {
                Database.SaveResult[] srs = Database.insert(profiles, false);
                for (Integer i = 0; i < srs.size(); i++) {
                    if (!srs[i].isSuccess()) {
                        Integer rowIndex = profileRowIndexes[i];
                        logSaveResultErrors('Contact Profile insert', rowIndex, rowMaps, srs[i], jobId);
                    }
                }
            }
        }

        if (roleType != null && rolePersonField != null) {
            List<SObject> roles = new List<SObject>();
            List<Integer> roleRowIndexes = new List<Integer>();
            for (Integer i = 0; i < rowMaps.size(); i++) {
                if (i >= contactIdByRow.size() || contactIdByRow[i] == null) continue;
                if (i >= hasRole.size() || !hasRole[i]) continue;
                Map<String, Object> row = rowMaps[i];
                SObject r = roleType.newSObject();
                if (roleFields.containsKey(rolePersonField)) {
                    Schema.DescribeFieldResult linkField = roleFields.get(rolePersonField).getDescribe();
                    if (linkField.isCreateable()) {
                        r.put(rolePersonField, contactIdByRow[i]);
                    }
                }
                if (roleFields.containsKey('RoleType')) {
                    Schema.DescribeFieldResult roleTypeField = roleFields.get('RoleType').getDescribe();
                    if (roleTypeField.isCreateable()) {
                        r.put('RoleType', 'Faculty');
                    }
                }
                for (String key : row.keySet()) {
                    String target = getTargetForKey(key, contactKeys, profileKeys, roleKeys);
                    if (target != 'Role') continue;
                    if (key == rolePersonField || key == 'RoleType') continue;
                    if (!roleFields.containsKey(key)) continue;
                    Schema.DescribeFieldResult d = roleFields.get(key).getDescribe();
                    if (!d.isCreateable()) continue;
                    try {
                        Object val = ImportUtils.convertValue(row.get(key), d);
                        if (key == 'Status' && val != null && !roleStatusValues.isEmpty()) {
                            String statusVal = String.valueOf(val);
                            if (!roleStatusValues.contains(statusVal)) {
                                r.addError('Invalid Status picklist value: ' + statusVal);
                                continue;
                            }
                        }
                        r.put(key, val);
                    } catch (Exception e) {
                        // ignore conversion errors in batch
                    }
                }
                roles.add(r);
                roleRowIndexes.add(i);
            }

            if (!roles.isEmpty()) {
                Database.SaveResult[] srs = Database.insert(roles, false);
                for (Integer i = 0; i < srs.size(); i++) {
                    if (!srs[i].isSuccess()) {
                        Integer rowIndex = roleRowIndexes[i];
                        logSaveResultErrors('Constituent Role insert', rowIndex, rowMaps, srs[i], jobId);
                    }
                }
            }
        }

        flushAuditLogs();
    }

    public void finish(Database.BatchableContext bc) {}

    private static String resolveObjectName(Map<String, Schema.SObjectType> gd, List<String> candidates) {
        if (gd == null || candidates == null) return null;
        for (String name : candidates) {
            if (gd.containsKey(name)) return name;
        }
        return null;
    }

    private static String resolveLinkField(Map<String, Schema.SObjectField> fields, List<String> candidates) {
        if (fields == null || candidates == null) return null;
        for (String name : candidates) {
            if (fields.containsKey(name)) return name;
        }
        return null;
    }

    private static String getTargetForKey(
        String key,
        Set<String> contactKeys,
        Set<String> profileKeys,
        Set<String> roleKeys
    ) {
        if (String.isBlank(key)) return null;
        if (contactKeys != null && contactKeys.contains(key)) return 'Contact';
        if (profileKeys != null && profileKeys.contains(key)) return 'Profile';
        if (roleKeys != null && roleKeys.contains(key)) return 'Role';
        return null;
    }

    private static Set<String> getPicklistValues(Schema.DescribeFieldResult d) {
        Set<String> values = new Set<String>();
        if (d == null) return values;
        for (Schema.PicklistEntry pe : d.getPicklistValues()) {
            if (pe != null) values.add(pe.getValue());
        }
        return values;
    }

    private void logSaveResultErrors(String stage, Integer rowIndex, List<Map<String, Object>> rowMaps, Database.SaveResult sr, Id jobId) {
        if (sr == null || sr.isSuccess() || sr.getErrors() == null || sr.getErrors().isEmpty()) return;
        Database.Error e = sr.getErrors()[0];
        Integer rowNum = getRowNumber(rowIndex, rowMaps);
        String rowLabel = rowNum != null ? 'Row ' + rowNum : 'Row';
        String rowHint = getRowHint(rowIndex, rowMaps);
        String msg = stage + ' - ' + rowLabel + rowHint + ': ' + e.getMessage();
        writeAuditLog(msg, jobId);
    }

    private static String getRowHint(Integer rowIndex, List<Map<String, Object>> rowMaps) {
        if (rowIndex == null || rowMaps == null || rowIndex < 0 || rowIndex >= rowMaps.size()) return '';
        Map<String, Object> row = rowMaps[rowIndex];
        if (row == null) return '';
        if (row.containsKey('Email') && row.get('Email') != null) return ' (Email=' + String.valueOf(row.get('Email')) + ')';
        if (row.containsKey('LastName') && row.get('LastName') != null) return ' (LastName=' + String.valueOf(row.get('LastName')) + ')';
        return '';
    }

    private void writeAuditLog(String message, Id jobId) {
        if (String.isBlank(message)) return;
        try {
            AuditLogHelper.AuditLogCreator creator = AuditLogHelper.auditLogRecord('Faculty Import', 'Class:FacultyImportBatch');
            creator.setErrorMessage(message);
            if (jobId != null) creator.setRecordId(String.valueOf(jobId));
            Audit_Log__c log = creator.returnWithoutCreate();
            if (log != null) pendingLogs.add(log);
        } catch (Exception ex) {
            // avoid batch failure due to logging
        }
    }

    private void logDuplicate(String reason, Integer rowIndex, List<Map<String, Object>> rows, String email, String lastName, Id jobId) {
        Integer rowNum = getRowNumber(rowIndex, rows);
        String rowLabel = rowNum != null ? 'Row ' + rowNum : 'Row';
        String msg = 'Faculty duplicate skipped (' + reason + ') - ' + rowLabel + ' (Email=' + email + ', LastName=' + lastName + ')';
        writeAuditLog(msg, jobId);
    }

    private static Integer getRowNumber(Integer rowIndex, List<Map<String, Object>> rows) {
        if (rowIndex == null || rows == null || rowIndex < 0 || rowIndex >= rows.size()) return null;
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
        if (pendingLogs == null || pendingLogs.isEmpty()) return;
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
}