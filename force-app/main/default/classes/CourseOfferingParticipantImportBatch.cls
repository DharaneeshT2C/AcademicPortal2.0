/**
 * @description
 *
 * Usage:
 *  - Apex: classes/HistoricalDataImportController.cls -> CourseOfferingParticipantImportBatch
 */
public without sharing class CourseOfferingParticipantImportBatch implements Database.Batchable<Map<String, Object>>, Database.Stateful {
    private final String jsonRows;
    private final Id academicSessionId;
    private List<Audit_Log__c> pendingLogs = new List<Audit_Log__c>();

    public CourseOfferingParticipantImportBatch(String jsonRows, Id academicSessionId) {
        this.jsonRows = jsonRows;
        this.academicSessionId = academicSessionId;
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

        // Collect unique course offering names and participant emails
        Set<String> offeringNames = new Set<String>();
        Set<String> participantEmails = new Set<String>();
        for (Map<String, Object> row : scope) {
            if (row == null) {continue;}
            String offeringName = getRowValue(row, 'Course Offering Name');
            if (String.isNotBlank(offeringName)) {offeringNames.add(offeringName.trim());}
            String email = getRowValue(row, 'Participant Email');
            if (String.isNotBlank(email)) {participantEmails.add(email.toLowerCase());}
        }

        // Resolve CourseOffering by Name
        Map<String, CourseOffering> offeringByName = new Map<String, CourseOffering>();
        if (!offeringNames.isEmpty()) {
            for (CourseOffering co : [
                SELECT Id, Name, StartDate, EndDate
                FROM CourseOffering
                WHERE Name IN :offeringNames
            ]) {
                if (String.isNotBlank(co.Name)) {
                    offeringByName.put(co.Name.trim(), co);
                }
            }
        }

        // Resolve Participant Contact by email via PersonAccount
        Map<String, Account> accountByEmail = new Map<String, Account>();
        if (!participantEmails.isEmpty()) {
            for (Account acc : [
                SELECT Id, PersonContactId, PersonEmail
                FROM Account
                WHERE IsPersonAccount = true
                AND PersonEmail IN :participantEmails
            ]) {
                if (String.isNotBlank(acc.PersonEmail) && acc.PersonContactId != null) {
                    accountByEmail.put(acc.PersonEmail.trim().toLowerCase(), acc);
                }
            }
        }

        // Fetch existing CourseOfferingParticipant to check duplicates by (CourseOfferingId + ParticipantContactId)
        Set<Id> resolvedOfferingIds = new Set<Id>();
        for (CourseOffering co : offeringByName.values()) {
            resolvedOfferingIds.add(co.Id);
        }
        Set<Id> resolvedContactIds = new Set<Id>();
        for (Account acc : accountByEmail.values()) {
            resolvedContactIds.add(acc.PersonContactId);
        }

        Map<String, Id> existingParticipantByKey = new Map<String, Id>();
        if (!resolvedOfferingIds.isEmpty() && !resolvedContactIds.isEmpty()) {
            for (CourseOfferingParticipant cop : [
                SELECT Id, CourseOfferingId, ParticipantContactId
                FROM CourseOfferingParticipant
                WHERE CourseOfferingId IN :resolvedOfferingIds
                AND ParticipantContactId IN :resolvedContactIds
            ]) {
                String key = String.valueOf(cop.CourseOfferingId) + '|' + String.valueOf(cop.ParticipantContactId);
                existingParticipantByKey.put(key, cop.Id);
            }
        }

        // Describe CourseOfferingParticipant fields for convertValue
        Map<String, Schema.SObjectField> copFields = CourseOfferingParticipant.SObjectType.getDescribe().fields.getMap();

        List<CourseOfferingParticipant> participantsToInsert = new List<CourseOfferingParticipant>();
        List<Integer> participantRowIndexes = new List<Integer>();
        List<Map<String, Object>> rowMaps = new List<Map<String, Object>>();

        for (Integer i = 0; i < scope.size(); i++) {
            Map<String, Object> row = scope[i];
            if (row == null) {continue;}
            rowMaps.add(row);
            Integer rowIdx = rowMaps.size() - 1;

            String offeringName = getRowValue(row, 'Course Offering Name');
            if (String.isBlank(offeringName)) {
                writeAuditLog('Row ' + getRowNumber(i, scope) + ': Course Offering Name is required.', jobId);
                continue;
            }

            CourseOffering offering = offeringByName.get(offeringName.trim());
            if (offering == null) {
                writeAuditLog('Row ' + getRowNumber(i, scope) + ': CourseOffering not found for name "' + offeringName + '".', jobId);
                continue;
            }

            String email = getRowValue(row, 'Participant Email');
            if (String.isBlank(email)) {
                writeAuditLog('Row ' + getRowNumber(i, scope) + ': Participant Email is required.', jobId);
                continue;
            }

            Account participantAccount = accountByEmail.get(email.toLowerCase());
            if (participantAccount == null || participantAccount.PersonContactId == null) {
                writeAuditLog('Row ' + getRowNumber(i, scope) + ': Participant not found for email "' + email + '".', jobId);
                continue;
            }

            // Check for duplicate
            String dupKey = String.valueOf(offering.Id) + '|' + String.valueOf(participantAccount.PersonContactId);
            if (existingParticipantByKey.containsKey(dupKey)) {
                writeAuditLog('Row ' + getRowNumber(i, scope) + ': CourseOfferingParticipant already exists for "' + offeringName + '" and email "' + email + '". Skipped.', jobId);
                continue;
            }

            // Build CourseOfferingParticipant record
            CourseOfferingParticipant cop = new CourseOfferingParticipant();
            cop.CourseOfferingId = offering.Id;
            cop.ParticipantContactId = participantAccount.PersonContactId;
            putFieldValue(cop, copFields, 'ParticipantAccountId', participantAccount.Id);
            putFieldValue(cop, copFields, 'ParticipantAffiliation', 'Student');

            String participationStatus = getRowValue(row, 'Participation Status');
            putFieldValue(cop, copFields, 'ParticipationStatus', String.isNotBlank(participationStatus) ? participationStatus : 'Enrolled');

            // Dates: use row values or fall back to offering dates
            Object startDateVal = row.get('Start Date');
            Object endDateVal = row.get('End Date');
            if (startDateVal != null && String.isNotBlank(String.valueOf(startDateVal))) {
                putFieldValue(cop, copFields, 'StartDate', startDateVal);
            } else if (offering.StartDate != null) {
                putFieldValue(cop, copFields, 'StartDate', offering.StartDate);
            }
            if (endDateVal != null && String.isNotBlank(String.valueOf(endDateVal))) {
                putFieldValue(cop, copFields, 'EndDate', endDateVal);
            } else if (offering.EndDate != null) {
                putFieldValue(cop, copFields, 'EndDate', offering.EndDate);
            }

            participantsToInsert.add(cop);
            participantRowIndexes.add(rowIdx);

            // Mark key as used to avoid duplicates within the same batch
            existingParticipantByKey.put(dupKey, null);
        }

        // Insert CourseOfferingParticipant records
        saveRecords('Course Offering Participant insert', participantsToInsert, participantRowIndexes, rowMaps, jobId, true);

        flushAuditLogs();
    }

    public void finish(Database.BatchableContext bc) {}

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

    private void putFieldValue(SObject target, Map<String, Schema.SObjectField> fields, String fieldName, Object value) {
        if (target == null || fields == null || String.isBlank(fieldName) || !fields.containsKey(fieldName)) {return;}
        Schema.DescribeFieldResult d = fields.get(fieldName).getDescribe();
        if (!d.isCreateable()) {return;}
        try {
            Object converted = KenImportUtils.convertValue(value, d);
            target.put(fieldName, converted);
        } catch (Exception e) {
            // ignore field conversion issues
        }
    }

    private static String getRowValue(Map<String, Object> row, String key) {
        if (row == null || String.isBlank(key) || !row.containsKey(key) || row.get(key) == null) {return null;}
        String value = String.valueOf(row.get(key)).trim();
        return String.isBlank(value) ? null : value;
    }

    private static String getRowNumber(Integer rowIndex, List<Map<String, Object>> rows) {
        if (rowIndex == null || rows == null || rowIndex < 0 || rowIndex >= rows.size()) {
            return String.valueOf(rowIndex != null ? rowIndex + 1 : 0);
        }
        Map<String, Object> row = rows[rowIndex];
        if (row != null && row.containsKey('RowNumber') && row.get('RowNumber') != null) {
            try {
                return String.valueOf(Integer.valueOf(String.valueOf(row.get('RowNumber')).trim()));
            } catch (Exception e) {
                // fall through
            }
        }
        return String.valueOf(rowIndex + 1);
    }

    private void logSaveResultErrors(String stage, Integer rowIndex, List<Map<String, Object>> rowMaps, Database.SaveResult sr, Id jobId) {
        if (sr == null || sr.isSuccess() || sr.getErrors() == null || sr.getErrors().isEmpty()) {return;}
        Database.Error e = sr.getErrors()[0];
        String rowLabel = 'Row ' + getRowNumber(rowIndex, rowMaps);
        String rowHint = getRowHint(rowIndex, rowMaps);
        String msg = stage + ' - ' + rowLabel + rowHint + ': ' + e.getMessage();
        writeAuditLog(msg, jobId);
    }

    private static String getRowHint(Integer rowIndex, List<Map<String, Object>> rowMaps) {
        if (rowIndex == null || rowMaps == null || rowIndex < 0 || rowIndex >= rowMaps.size()) {return '';}
        Map<String, Object> row = rowMaps[rowIndex];
        if (row == null) {return '';}
        String email = getRowValue(row, 'Participant Email');
        if (String.isNotBlank(email)) {return ' (Email=' + email + ')';}
        String offeringName = getRowValue(row, 'Course Offering Name');
        if (String.isNotBlank(offeringName)) {return ' (CourseOffering=' + offeringName + ')';}
        return '';
    }

    private void writeAuditLog(String message, Id jobId) {
        if (String.isBlank(message)) {return;}
        try {
            KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord('Course Offering Participant Import', 'Class:CourseOfferingParticipantImportBatch');
            creator.setErrorMessage(message);
            if (jobId != null) {creator.setRecordId(String.valueOf(jobId));}
            Audit_Log__c log = creator.returnWithoutCreate();
            if (log != null) {pendingLogs.add(log);}
        } catch (Exception ex) {
            // avoid batch failure due to logging
        }
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
}