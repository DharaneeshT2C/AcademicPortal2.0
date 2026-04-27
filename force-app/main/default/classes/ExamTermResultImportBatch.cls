public without sharing class ExamTermResultImportBatch implements Database.Batchable<Map<String, Object>>, Database.Stateful {
    private static final String PROCESS_NAME = 'Exam Term Result Import';
    private static final String SOURCE_NAME = 'Class:ExamTermResultImportBatch';

    private final String jsonRows;
    private final Id examCycleId;
    private List<Audit_Log__c> pendingLogs = new List<Audit_Log__c>();

    private class StudentContext {
        Id contactId;
    }

    public ExamTermResultImportBatch(String jsonRows, Id examCycleId) {
        this.jsonRows = jsonRows;
        this.examCycleId = examCycleId;
    }

    public Iterable<Map<String, Object>> start(Database.BatchableContext bc) {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        if (String.isBlank(jsonRows)) {
            return rows;
        }
        for (Object row : (List<Object>) JSON.deserializeUntyped(jsonRows)) {
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

        Id academicTermId = resolveAcademicTermId(jobId);
        if (academicTermId == null) {
            flushAuditLogs();
            return;
        }

        Set<String> studentIds = new Set<String>();
        for (Map<String, Object> row : scope) {
            addTrimmed(studentIds, getRowValue(row, 'Student Registration ID'));
        }

        Boolean hasRoleStudentId = ConstituentRole.SObjectType.getDescribe().fields.getMap().containsKey('Student_ID__c');
        Map<String, StudentContext> studentByRegistrationId = getStudentsByRegistrationId(studentIds, hasRoleStudentId);
        Map<Id, AcademicTermEnrollment> ateByContactId = getAcademicTermEnrollments(studentByRegistrationId.values(), academicTermId);
        Map<String, Schema.SObjectField> ateFields = AcademicTermEnrollment.SObjectType.getDescribe().fields.getMap();
        Map<String, String> academicStandingByKey = buildPicklistMap(ateFields, 'AcademicStanding');
        Map<String, String> enrollmentStatusByKey = buildPicklistMap(ateFields, 'EnrollmentStatus');

        List<AcademicTermEnrollment> atesToUpdate = new List<AcademicTermEnrollment>();
        for (Integer i = 0; i < scope.size(); i++) {
            Map<String, Object> row = scope[i];
            String rowNumber = getRowNumber(i, scope);
            String studentRegistrationId = getRowValue(row, 'Student Registration ID');
            if (String.isBlank(studentRegistrationId)) {
                writeAuditLog('Row ' + rowNumber + ': Student Registration ID is required.', jobId);
                continue;
            }

            StudentContext student = studentByRegistrationId.get(normalizeKey(studentRegistrationId));
            if (student == null || student.contactId == null) {
                writeAuditLog('Row ' + rowNumber + ': Student was not found for Student Registration ID "' + studentRegistrationId + '".', jobId);
                continue;
            }

            AcademicTermEnrollment ate = ateByContactId.get(student.contactId);
            if (ate == null) {
                writeAuditLog('Row ' + rowNumber + ': Academic Term Enrollment was not found for Student Registration ID "' + studentRegistrationId + '" in the selected Exam Cycle term.', jobId);
                continue;
            }

            AcademicTermEnrollment updateRow = new AcademicTermEnrollment(Id = ate.Id);
            Boolean hasChanges = false;

            Decimal gpa = toDecimal(getRowValue(row, 'GPA'));
            if (gpa != null && ateFields.containsKey('TermGradePointAverage')) {
                updateRow.put('TermGradePointAverage', gpa);
                hasChanges = true;
            }

            Decimal cgpa = toDecimal(getRowValue(row, 'CGPA'));
            if (cgpa != null && ateFields.containsKey('CumulativeGradePointAverage')) {
                updateRow.put('CumulativeGradePointAverage', cgpa);
                hasChanges = true;
            }

            String statusValue = getRowValue(row, 'Status');
            if (String.isNotBlank(statusValue)) {
                String normalizedStatus = normalizeKey(statusValue);
                if (academicStandingByKey.containsKey(normalizedStatus)) {
                    updateRow.put('AcademicStanding', academicStandingByKey.get(normalizedStatus));
                    hasChanges = true;
                } else if (enrollmentStatusByKey.containsKey(normalizedStatus)) {
                    updateRow.put('EnrollmentStatus', enrollmentStatusByKey.get(normalizedStatus));
                    hasChanges = true;
                } else {
                    writeAuditLog('Row ' + rowNumber + ': Status "' + statusValue + '" is not a valid Academic Standing or Enrollment Status value.', jobId);
                }
            }

            if (String.isNotBlank(getRowValue(row, 'Credits Earned'))) {
                writeAuditLog('Row ' + rowNumber + ': Credits Earned does not have a mapped field in Academic Term Enrollment and was ignored.', jobId);
            }
            if (String.isNotBlank(getRowValue(row, 'Total Grade Points'))) {
                writeAuditLog('Row ' + rowNumber + ': Total Grade Points does not have a mapped field in Academic Term Enrollment and was ignored.', jobId);
            }

            if (hasChanges) {
                atesToUpdate.add(updateRow);
            }
        }

        if (!atesToUpdate.isEmpty()) {
            Database.SaveResult[] results = Database.update(atesToUpdate, false);
            for (Database.SaveResult result : results) {
                if (result != null && !result.isSuccess() && result.getErrors() != null && !result.getErrors().isEmpty()) {
                    writeAuditLog('Academic Term Enrollment update: ' + result.getErrors()[0].getMessage(), jobId);
                }
            }
        }

        flushAuditLogs();
    }

    public void finish(Database.BatchableContext bc) {}

    private Id resolveAcademicTermId(Id jobId) {
        if (examCycleId == null) {
            writeAuditLog('Exam Cycle is required for Exam Term Result Import.', jobId);
            return null;
        }
        List<SObject> rows = Database.query(
            'SELECT Id, Ken_Academic_Term__c FROM Ken_Exam_Cycle__c WHERE Id = :examCycleId LIMIT 1'
        );
        if (rows.isEmpty()) {
            writeAuditLog('Exam Cycle not found for Id ' + examCycleId + '.', jobId);
            return null;
        }
        Id academicTermId = (Id) rows[0].get('Ken_Academic_Term__c');
        if (academicTermId == null) {
            writeAuditLog('Selected Exam Cycle is not linked to an Academic Term.', jobId);
        }
        return academicTermId;
    }

    private Map<String, StudentContext> getStudentsByRegistrationId(Set<String> studentIds, Boolean hasRoleStudentId) {
        Map<String, StudentContext> out = new Map<String, StudentContext>();
        if (studentIds == null || studentIds.isEmpty()) {
            return out;
        }

        if (hasRoleStudentId) {
            for (ConstituentRole roleRow : [
                SELECT Id, PersonId, Student_ID__c
                FROM ConstituentRole
                WHERE RoleType = :KenConstantController.ROLETYPE_STUDENT
                AND Student_ID__c IN :studentIds
            ]) {
                if (String.isBlank(roleRow.Student_ID__c) || roleRow.PersonId == null) {
                    continue;
                }
                StudentContext ctx = new StudentContext();
                ctx.contactId = roleRow.PersonId;
                out.put(normalizeKey(roleRow.Student_ID__c), ctx);
            }
        }

        if (out.size() == studentIds.size() || !Account.SObjectType.getDescribe().fields.getMap().containsKey('Student_ID__c')) {
            return out;
        }

        for (Account accountRow : Database.query(
            'SELECT PersonContactId, Student_ID__c FROM Account WHERE IsPersonAccount = true AND Student_ID__c IN :studentIds'
        )) {
            String studentId = (String) accountRow.get('Student_ID__c');
            if (String.isBlank(studentId) || accountRow.PersonContactId == null) {
                continue;
            }
            if (!out.containsKey(normalizeKey(studentId))) {
                StudentContext ctx = new StudentContext();
                ctx.contactId = accountRow.PersonContactId;
                out.put(normalizeKey(studentId), ctx);
            }
        }
        return out;
    }

    private Map<Id, AcademicTermEnrollment> getAcademicTermEnrollments(Iterable<StudentContext> students, Id academicTermId) {
        Set<Id> contactIds = new Set<Id>();
        for (StudentContext student : students) {
            if (student != null && student.contactId != null) {
                contactIds.add(student.contactId);
            }
        }

        Map<Id, AcademicTermEnrollment> out = new Map<Id, AcademicTermEnrollment>();
        if (contactIds.isEmpty() || academicTermId == null) {
            return out;
        }
        for (AcademicTermEnrollment ate : [
            SELECT Id, LearnerContactId
            FROM AcademicTermEnrollment
            WHERE AcademicTermId = :academicTermId
            AND LearnerContactId IN :contactIds
        ]) {
            out.put(ate.LearnerContactId, ate);
        }
        return out;
    }

    private static Map<String, String> buildPicklistMap(Map<String, Schema.SObjectField> fields, String fieldName) {
        Map<String, String> out = new Map<String, String>();
        if (fields == null || String.isBlank(fieldName) || !fields.containsKey(fieldName)) {
            return out;
        }
        for (Schema.PicklistEntry entry : fields.get(fieldName).getDescribe().getPicklistValues()) {
            if (entry != null && entry.isActive()) {
                out.put(normalizeKey(entry.getValue()), entry.getValue());
                out.put(normalizeKey(entry.getLabel()), entry.getValue());
            }
        }
        return out;
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
            } catch (Exception ex) {
                // Fall through.
            }
        }
        return String.valueOf(rowIndex + 1);
    }

    private static String normalizeKey(String value) {
        return String.isBlank(value) ? '' : value.trim().toLowerCase();
    }

    private static Decimal toDecimal(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return Decimal.valueOf(raw.trim());
        } catch (Exception ex) {
            return null;
        }
    }

    private void writeAuditLog(String message, Id jobId) {
        if (String.isBlank(message)) {
            return;
        }
        try {
            KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord(PROCESS_NAME, SOURCE_NAME);
            creator.setErrorMessage(message);
            if (jobId != null) {
                creator.setRecordId(String.valueOf(jobId));
            }
            Audit_Log__c log = creator.returnWithoutCreate();
            if (log != null) {
                pendingLogs.add(log);
            }
        } catch (Exception ex) {
            // Ignore logging failures.
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