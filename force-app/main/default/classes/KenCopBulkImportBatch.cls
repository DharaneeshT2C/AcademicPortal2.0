public without sharing class KenCopBulkImportBatch implements Database.Batchable<Map<String, Object>>, Database.Stateful {
    private final String jsonRows;
    private final Id academicTermId;
    private final String processName;
    private final Set<String> seenParticipantKeys = new Set<String>();
    private List<Audit_Log__c> pendingLogs = new List<Audit_Log__c>();

    public KenCopBulkImportBatch(String jsonRows, Id academicTermId, String processName) {
        this.jsonRows = jsonRows;
        this.academicTermId = academicTermId;
        this.processName = String.isBlank(processName)
            ? 'Course Offering Participant Bulk Import'
            : processName;
    }

    public Iterable<Map<String, Object>> start(Database.BatchableContext bc) {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        if (String.isBlank(jsonRows)) {
            return rows;
        }

        List<Object> parsedRows = (List<Object>) JSON.deserializeUntyped(jsonRows);
        for (Object row : parsedRows) {
            if (row instanceof Map<String, Object>) {
                rows.add((Map<String, Object>) row);
            }
        }
        return rows;
    }

    public void execute(Database.BatchableContext bc, List<Map<String, Object>> scope) {
        Id jobId = bc == null ? null : bc.getJobId();
        if (scope == null || scope.isEmpty()) {
            return;
        }
        Map<String, Schema.SObjectField> offeringFields = CourseOffering.SObjectType.getDescribe().fields.getMap();
        String examTypeField = resolveFieldName(offeringFields, new List<String>{'Exam_Type__c', 'ExamType__c', 'ExamType'});

        Set<String> offeringNames = new Set<String>();
        Set<String> participantEmails = new Set<String>();
        for (Map<String, Object> row : scope) {
            addTrimmed(offeringNames, getRowValue(row, 'Course Offering Name'));
            String email = getRowValue(row, 'Participant Email');
            if (String.isNotBlank(email)) {
                participantEmails.add(email.trim().toLowerCase());
            }
        }

        Map<String, List<CourseOffering>> offeringsByName = getOfferingsByName(offeringNames, examTypeField);
        Map<String, Contact> contactByEmail = getContactsByEmail(participantEmails);
        Map<Id, AcademicTermEnrollment> ateByContactId = getTermEnrollmentsByContact(contactByEmail.values());
        Set<String> validStatuses = getValidParticipationStatuses();
        Set<String> existingKeys = getExistingCopKeys(flattenOfferings(offeringsByName), ateByContactId.values());
        Map<String, Schema.SObjectField> copFields = CourseOfferingParticipant.SObjectType.getDescribe().fields.getMap();

        List<CourseOfferingParticipant> participantsToInsert = new List<CourseOfferingParticipant>();
        List<Integer> rowIndexes = new List<Integer>();

        for (Integer i = 0; i < scope.size(); i++) {
            Map<String, Object> row = scope[i];
            String rowNumber = getRowNumber(i, scope);

            String offeringName = getRowValue(row, 'Course Offering Name');
            String participantEmail = getRowValue(row, 'Participant Email');
            String examTypeValue = getRowValue(row, 'Exam Type');
            if (String.isBlank(offeringName)) {
                writeAuditLog('Row ' + rowNumber + ': Course Offering Name is required.', jobId);
                continue;
            }
            if (String.isBlank(participantEmail)) {
                writeAuditLog('Row ' + rowNumber + ': Participant Email is required.', jobId);
                continue;
            }

            CourseOffering offering = resolveOffering(offeringsByName.get(normalizeKey(offeringName)), examTypeValue, examTypeField);
            if (offering == null) {
                if (String.isBlank(examTypeValue)) {
                    writeAuditLog('Row ' + rowNumber + ': Course Offering "' + offeringName + '" was not found under this Academic Term.', jobId);
                } else {
                    writeAuditLog('Row ' + rowNumber + ': Course Offering "' + offeringName + '" with Exam Type "' + examTypeValue + '" was not found under this Academic Term.', jobId);
                }
                continue;
            }

            Contact participantContact = contactByEmail.get(participantEmail.trim().toLowerCase());
            if (participantContact == null) {
                writeAuditLog('Row ' + rowNumber + ': Student was not found for email "' + participantEmail + '".', jobId);
                continue;
            }

            AcademicTermEnrollment ate = ateByContactId.get(participantContact.Id);
            if (ate == null) {
                writeAuditLog('Row ' + rowNumber + ': Academic Term Enrollment was not found for student "' + participantEmail + '" in this Academic Term.', jobId);
                continue;
            }

            String status = getRowValue(row, 'Participation Status');
            if (String.isBlank(status)) {
                status = 'Enrolled';
            } else if (!validStatuses.isEmpty() && !validStatuses.contains(normalizeKey(status))) {
                writeAuditLog('Row ' + rowNumber + ': Participation Status "' + status + '" is invalid.', jobId);
                continue;
            }

            String duplicateKey = buildDuplicateKey(offering.Id, ate.Id);
            if (seenParticipantKeys.contains(duplicateKey)) {
                writeAuditLog('Row ' + rowNumber + ': Duplicate row for Course Offering "' + offeringName + '" and Participant Email "' + participantEmail + '".', jobId);
                continue;
            }
            if (existingKeys.contains(duplicateKey)) {
                writeAuditLog('Row ' + rowNumber + ': Course Offering Participant already exists for Course Offering "' + offeringName + '" and Participant Email "' + participantEmail + '".', jobId);
                continue;
            }
            seenParticipantKeys.add(duplicateKey);

            CourseOfferingParticipant participant = new CourseOfferingParticipant();
            participant.CourseOfferingId = offering.Id;
            participant.ParticipantContactId = ate.LearnerContactId;
            putFieldValue(participant, copFields, 'ParticipantAccountId', ate.LearnerAccountId);
            putFieldValue(participant, copFields, 'AcademicTermEnrollmentId', ate.Id);
            putFieldValue(participant, copFields, 'ParticipantAffiliation', 'Student');
            putFieldValue(participant, copFields, 'ParticipationStatus', status);

            Object startDateValue = row.get('Start Date');
            Object endDateValue = row.get('End Date');
            if (startDateValue != null && String.isNotBlank(String.valueOf(startDateValue))) {
                putFieldValue(participant, copFields, 'StartDate', startDateValue);
            } else if (offering.StartDate != null) {
                putFieldValue(participant, copFields, 'StartDate', offering.StartDate);
            }
            if (endDateValue != null && String.isNotBlank(String.valueOf(endDateValue))) {
                putFieldValue(participant, copFields, 'EndDate', endDateValue);
            } else if (offering.EndDate != null) {
                putFieldValue(participant, copFields, 'EndDate', offering.EndDate);
            }

            participantsToInsert.add(participant);
            rowIndexes.add(i);
        }

        if (!participantsToInsert.isEmpty()) {
            Database.SaveResult[] results = Database.insert(participantsToInsert, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    logSaveResultErrors(rowIndexes[i], scope, results[i], jobId);
                }
            }
        }

        flushAuditLogs();
    }

    public void finish(Database.BatchableContext bc) {}

    private Map<String, List<CourseOffering>> getOfferingsByName(Set<String> offeringNames, String examTypeField) {
        Map<String, List<CourseOffering>> offeringsByName = new Map<String, List<CourseOffering>>();
        if (offeringNames == null || offeringNames.isEmpty()) {
            return offeringsByName;
        }

        String soql = 'SELECT Id, Name, StartDate, EndDate';
        if (String.isNotBlank(examTypeField)) {
            soql += ', ' + examTypeField;
        }
        soql +=
            ' FROM CourseOffering' +
            ' WHERE Name IN :offeringNames' +
            ' AND AcademicSession.AcademicTermId = :academicTermId';

        for (CourseOffering offering : (List<CourseOffering>) Database.query(soql)) {
            String key = normalizeKey(offering.Name);
            if (!offeringsByName.containsKey(key)) {
                offeringsByName.put(key, new List<CourseOffering>());
            }
            offeringsByName.get(key).add(offering);
        }
        return offeringsByName;
    }

    private static List<CourseOffering> flattenOfferings(Map<String, List<CourseOffering>> offeringsByName) {
        List<CourseOffering> offerings = new List<CourseOffering>();
        if (offeringsByName == null) {
            return offerings;
        }
        for (List<CourseOffering> rows : offeringsByName.values()) {
            if (rows != null) {
                offerings.addAll(rows);
            }
        }
        return offerings;
    }

    private static CourseOffering resolveOffering(List<CourseOffering> offerings, String examTypeValue, String examTypeField) {
        if (offerings == null || offerings.isEmpty()) {
            return null;
        }
        if (String.isBlank(examTypeValue)) {
            return offerings[0];
        }
        if (String.isBlank(examTypeField)) {
            return null;
        }

        String normalizedExamType = normalizeKey(examTypeValue);
        for (CourseOffering offering : offerings) {
            if (normalizedExamType == normalizeKey(String.valueOf(offering.get(examTypeField)))) {
                return offering;
            }
        }
        return null;
    }

    private Map<String, Contact> getContactsByEmail(Set<String> emails) {
        Map<String, Contact> contactByEmail = new Map<String, Contact>();
        if (emails == null || emails.isEmpty()) {
            return contactByEmail;
        }

        for (Contact contactRow : [
            SELECT Id, Email
            FROM Contact
            WHERE Email IN :emails
        ]) {
            if (String.isNotBlank(contactRow.Email) && !contactByEmail.containsKey(contactRow.Email.trim().toLowerCase())) {
                contactByEmail.put(contactRow.Email.trim().toLowerCase(), contactRow);
            }
        }

        for (Account accountRow : [
            SELECT PersonContactId, PersonEmail
            FROM Account
            WHERE IsPersonAccount = true
            AND PersonEmail IN :emails
        ]) {
            if (accountRow.PersonContactId == null || String.isBlank(accountRow.PersonEmail)) {
                continue;
            }
            if (!contactByEmail.containsKey(accountRow.PersonEmail.trim().toLowerCase())) {
                contactByEmail.put(
                    accountRow.PersonEmail.trim().toLowerCase(),
                    new Contact(Id = accountRow.PersonContactId, Email = accountRow.PersonEmail)
                );
            }
        }
        return contactByEmail;
    }

    private Map<Id, AcademicTermEnrollment> getTermEnrollmentsByContact(Iterable<Contact> contacts) {
        Set<Id> contactIds = new Set<Id>();
        for (Contact contactRow : contacts) {
            if (contactRow != null && contactRow.Id != null) {
                contactIds.add(contactRow.Id);
            }
        }

        Map<Id, AcademicTermEnrollment> ateByContactId = new Map<Id, AcademicTermEnrollment>();
        if (contactIds.isEmpty()) {
            return ateByContactId;
        }

        for (AcademicTermEnrollment ate : [
            SELECT Id, LearnerContactId, LearnerAccountId
            FROM AcademicTermEnrollment
            WHERE AcademicTermId = :academicTermId
            AND LearnerContactId IN :contactIds
        ]) {
            if (ate.LearnerContactId != null && !ateByContactId.containsKey(ate.LearnerContactId)) {
                ateByContactId.put(ate.LearnerContactId, ate);
            }
        }
        return ateByContactId;
    }

    private static Set<String> getValidParticipationStatuses() {
        Set<String> statuses = new Set<String>();
        Map<String, Schema.SObjectField> fields = CourseOfferingParticipant.SObjectType.getDescribe().fields.getMap();
        if (!fields.containsKey('ParticipationStatus')) {
            return statuses;
        }

        for (Schema.PicklistEntry entry : fields.get('ParticipationStatus').getDescribe().getPicklistValues()) {
            if (entry != null && entry.isActive()) {
                statuses.add(normalizeKey(entry.getValue()));
            }
        }
        return statuses;
    }

    private Set<String> getExistingCopKeys(Iterable<CourseOffering> offerings, Iterable<AcademicTermEnrollment> enrollments) {
        Set<Id> offeringIds = new Set<Id>();
        Set<Id> ateIds = new Set<Id>();
        for (CourseOffering offering : offerings) {
            if (offering != null && offering.Id != null) {
                offeringIds.add(offering.Id);
            }
        }
        for (AcademicTermEnrollment ate : enrollments) {
            if (ate != null && ate.Id != null) {
                ateIds.add(ate.Id);
            }
        }

        Set<String> keys = new Set<String>();
        if (offeringIds.isEmpty() || ateIds.isEmpty()) {
            return keys;
        }

        for (CourseOfferingParticipant participant : [
            SELECT CourseOfferingId, AcademicTermEnrollmentId
            FROM CourseOfferingParticipant
            WHERE CourseOfferingId IN :offeringIds
            AND AcademicTermEnrollmentId IN :ateIds
        ]) {
            keys.add(buildDuplicateKey(participant.CourseOfferingId, participant.AcademicTermEnrollmentId));
        }
        return keys;
    }

    private static String buildDuplicateKey(Id offeringId, Id ateId) {
        return String.valueOf(offeringId) + '|' + String.valueOf(ateId);
    }

    private void putFieldValue(SObject target, Map<String, Schema.SObjectField> fields, String fieldName, Object value) {
        if (target == null || fields == null || String.isBlank(fieldName) || !fields.containsKey(fieldName) || value == null) {
            return;
        }
        if (value instanceof String && String.isBlank((String) value)) {
            return;
        }

        Schema.DescribeFieldResult describeResult = fields.get(fieldName).getDescribe();
        if (!describeResult.isCreateable()) {
            return;
        }

        target.put(fieldName, KenImportUtils.convertValue(value, describeResult));
    }

    private static void addTrimmed(Set<String> values, String value) {
        if (values != null && String.isNotBlank(value)) {
            values.add(value.trim());
        }
    }

    private static String getRowValue(Map<String, Object> row, String key) {
        if (row == null || String.isBlank(key) || !row.containsKey(key) || row.get(key) == null) {
            return null;
        }
        String value = String.valueOf(row.get(key)).trim();
        return String.isBlank(value) ? null : value;
    }

    private static String getRowNumber(Integer rowIndex, List<Map<String, Object>> rows) {
        if (rowIndex == null || rows == null || rowIndex < 0 || rowIndex >= rows.size()) {
            return String.valueOf(rowIndex == null ? 0 : rowIndex + 1);
        }
        Map<String, Object> row = rows[rowIndex];
        if (row != null && row.containsKey('RowNumber') && row.get('RowNumber') != null) {
            try {
                return String.valueOf(Integer.valueOf(String.valueOf(row.get('RowNumber')).trim()));
            } catch (Exception e) {
                // Fall through to computed row number.
            }
        }
        return String.valueOf(rowIndex + 1);
    }

    private static String normalizeKey(String value) {
        return String.isBlank(value) ? '' : value.trim().toLowerCase();
    }

    private static String resolveFieldName(Map<String, Schema.SObjectField> fields, List<String> candidates) {
        if (fields == null || candidates == null) {
            return null;
        }
        for (String candidate : candidates) {
            if (String.isNotBlank(candidate) && fields.containsKey(candidate)) {
                return candidate;
            }
        }
        return null;
    }

    private void logSaveResultErrors(Integer rowIndex, List<Map<String, Object>> rowMaps, Database.SaveResult result, Id jobId) {
        if (result == null || result.isSuccess() || result.getErrors() == null || result.getErrors().isEmpty()) {
            return;
        }
        Database.Error error = result.getErrors()[0];
        writeAuditLog('Row ' + getRowNumber(rowIndex, rowMaps) + ': ' + error.getMessage(), jobId);
    }

    private void writeAuditLog(String message, Id jobId) {
        if (String.isBlank(message)) {
            return;
        }
        try {
            KenAuditLogHelper.KenAuditLogCreator creator =
                KenAuditLogHelper.auditLogRecord(processName, 'Class:KenCopBulkImportBatch');
            creator.setErrorMessage(message);
            if (jobId != null) {
                creator.setRecordId(String.valueOf(jobId));
            }
            Audit_Log__c log = creator.returnWithoutCreate();
            if (log != null) {
                pendingLogs.add(log);
            }
        } catch (Exception ex) {
            // Keep import processing independent from audit logging.
        }
    }

    private void flushAuditLogs() {
        if (pendingLogs == null || pendingLogs.isEmpty()) {
            return;
        }
        try {
            Database.DMLOptions dmlOptions = new Database.DMLOptions();
            dmlOptions.allowFieldTruncation = true;
            Database.insert(pendingLogs, dmlOptions);
        } catch (Exception ex) {
            // Ignore logging failures.
        } finally {
            pendingLogs.clear();
        }
    }
}