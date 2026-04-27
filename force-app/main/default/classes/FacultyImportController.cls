public with sharing class FacultyImportController {
    @AuraEnabled
    public static Id startFacultyImportBatch(String jsonRows) {
        return Database.executeBatch(new FacultyImportBatch(jsonRows), 200);
    }

    @AuraEnabled
    public static ImportUtils.ImportResult importFaculty(String jsonRows) {
        ImportUtils.ImportResult result = new ImportUtils.ImportResult();
        if (String.isBlank(jsonRows)) {
            result.errors.add('No data provided');
            result.errorCount = result.errors.size();
            return result;
        }

        List<Object> rows = (List<Object>) JSON.deserializeUntyped(jsonRows);
        if (rows.isEmpty()) return result;

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Contact')) {
            result.errors.add('Contact object not found in org');
            result.errorCount = result.errors.size();
            return result;
        }

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

        List<SObject> contacts = new List<SObject>();
        List<Map<String, Object>> rowMaps = new List<Map<String, Object>>();
        List<Boolean> hasProfile = new List<Boolean>();
        List<Boolean> hasRole = new List<Boolean>();

        Integer idx = 0;
        for (Object o : rows) {
            idx++;
            if (!(o instanceof Map<String, Object>)) continue;
            Map<String, Object> row = (Map<String, Object>) o;
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
                    if (!d.isCreateable()) {
                        result.errors.add('Row ' + idx + ' - contact field not createable: ' + key);
                        continue;
                    }
                    try {
                        Object val = ImportUtils.convertValue(row.get(key), d);
                        c.put(key, val);
                    } catch (Exception e) {
                        result.errors.add('Row ' + idx + ' - contact field error for ' + key + ': ' + e.getMessage());
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
                    result.errors.add('Row ' + (i + 1) + ' - contact insert error: ' + srs[i].getErrors()[0].getMessage());
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
                    if (!d.isCreateable()) {
                        result.errors.add('Row ' + (i + 1) + ' - profile field not createable: ' + key);
                        continue;
                    }
                    try {
                        Object val = ImportUtils.convertValue(row.get(key), d);
                        p.put(key, val);
                    } catch (Exception e) {
                        result.errors.add('Row ' + (i + 1) + ' - profile field error for ' + key + ': ' + e.getMessage());
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
                        result.errors.add('Row ' + (rowIndex + 1) + ' - profile insert error: ' + srs[i].getErrors()[0].getMessage());
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
                    if (!d.isCreateable()) {
                        result.errors.add('Row ' + (i + 1) + ' - role field not createable: ' + key);
                        continue;
                    }
                    try {
                        Object val = ImportUtils.convertValue(row.get(key), d);
                        if (key == 'Status' && val != null && !roleStatusValues.isEmpty()) {
                            String statusVal = String.valueOf(val);
                            if (!roleStatusValues.contains(statusVal)) {
                                result.errors.add('Row ' + (i + 1) + ' - invalid Status picklist value: ' + statusVal);
                                continue;
                            }
                        }
                        r.put(key, val);
                    } catch (Exception e) {
                        result.errors.add('Row ' + (i + 1) + ' - role field error for ' + key + ': ' + e.getMessage());
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
                        result.errors.add('Row ' + (rowIndex + 1) + ' - role insert error: ' + srs[i].getErrors()[0].getMessage());
                    }
                }
            }
        }

        result.errorCount = result.errors.size();
        return result;
    }

    @AuraEnabled
    public static List<String> getFacultyImportErrors(Id jobId) {
        List<String> out = new List<String>();
        if (jobId == null) return out;
        try {
            List<Audit_Log__c> logs = [
                SELECT Error_Message__c, Stack_Trace__c
                FROM Audit_Log__c
                WHERE RecordId__c = :String.valueOf(jobId)
                AND Process__c = 'Faculty Import'
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
            if (logs.isEmpty()) {
                logs = [
                    SELECT Error_Message__c, Stack_Trace__c
                    FROM Audit_Log__c
                    WHERE RecordId__c = :String.valueOf(jobId)
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ];
            }
            for (Audit_Log__c log : logs) {
                String msg = log.Error_Message__c;
                if (String.isBlank(msg)) msg = log.Stack_Trace__c;
                if (!String.isBlank(msg)) out.add(msg);
            }
        } catch (Exception e) {
            out.add('Error fetching audit logs: ' + e.getMessage());
        }
        return out;
    }

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
}