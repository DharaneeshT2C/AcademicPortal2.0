public without sharing class KenCourseOfferingBulkImportBatch implements Database.Batchable<Map<String, Object>>, Database.Stateful {
    private final String jsonRows;
    private final Id academicTermId;
    private final String processName;
    private final Set<String> seenOfferingKeys = new Set<String>();
    private List<Audit_Log__c> pendingLogs = new List<Audit_Log__c>();

    public KenCourseOfferingBulkImportBatch(String jsonRows, Id academicTermId, String processName) {
        this.jsonRows = jsonRows;
        this.academicTermId = academicTermId;
        this.processName = String.isBlank(processName) ? 'Course Offering Bulk Import' : processName;
    }

    public Iterable<Map<String, Object>> start(Database.BatchableContext bc) {
        List<Map<String, Object>> maps = new List<Map<String, Object>>();
        if (String.isBlank(jsonRows)) {
            return maps;
        }

        List<Object> rows = (List<Object>) JSON.deserializeUntyped(jsonRows);
        for (Object row : rows) {
            if (row instanceof Map<String, Object>) {
                maps.add((Map<String, Object>) row);
            }
        }
        return maps;
    }

    public void execute(Database.BatchableContext bc, List<Map<String, Object>> scope) {
        Id jobId = bc == null ? null : bc.getJobId();
        if (scope == null || scope.isEmpty()) {
            return;
        }

        Set<String> sessionNames = new Set<String>();
        Set<String> courseCodes = new Set<String>();
        Set<String> facultyEmails = new Set<String>();
        for (Map<String, Object> row : scope) {
            addTrimmed(sessionNames, getRowValue(row, 'Academic Session'));
            addTrimmed(courseCodes, getRowValue(row, 'Course Code'));
            String facultyEmail = getRowValue(row, 'Faculty Email');
            if (String.isNotBlank(facultyEmail)) {
                facultyEmails.add(facultyEmail.trim().toLowerCase());
            }
        }

        Map<String, AcademicSession> sessionByName = getSessionsByName(sessionNames);
        Map<String, LearningCourse> courseByCode = getCoursesByCode(courseCodes);
        Map<String, Id> facultyContactIdByEmail = getFacultyContactIdsByEmail(facultyEmails);
        Map<String, Schema.SObjectField> coFields = CourseOffering.SObjectType.getDescribe().fields.getMap();
        Id defaultRecordTypeId = getDefaultCourseOfferingRecordTypeId();

        Set<Id> sessionIds = new Set<Id>();
        Set<Id> courseIds = new Set<Id>();
        for (AcademicSession sessionRow : sessionByName.values()) {
            sessionIds.add(sessionRow.Id);
        }
        for (LearningCourse course : courseByCode.values()) {
            courseIds.add(course.Id);
        }
        Set<String> existingKeys = getExistingOfferingKeys(sessionIds, courseIds);

        List<CourseOffering> offeringsToInsert = new List<CourseOffering>();
        List<Integer> rowIndexes = new List<Integer>();

        for (Integer i = 0; i < scope.size(); i++) {
            Map<String, Object> row = scope[i];
            String rowNumber = getRowNumber(i, scope);

            String sessionName = getRowValue(row, 'Academic Session');
            String courseCode = getRowValue(row, 'Course Code');
            String courseType = getRowValue(row, 'Course Type');

            if (String.isBlank(sessionName)) {
                writeAuditLog('Row ' + rowNumber + ': Academic Session is required.', jobId);
                continue;
            }
            if (String.isBlank(courseCode)) {
                writeAuditLog('Row ' + rowNumber + ': Course Code is required.', jobId);
                continue;
            }
            if (String.isBlank(courseType)) {
                writeAuditLog('Row ' + rowNumber + ': Course Type is required.', jobId);
                continue;
            }

            AcademicSession sessionRow = sessionByName.get(normalizeKey(sessionName));
            if (sessionRow == null) {
                writeAuditLog('Row ' + rowNumber + ': Academic Session "' + sessionName + '" was not found under this Academic Term.', jobId);
                continue;
            }

            LearningCourse course = courseByCode.get(normalizeKey(courseCode));
            if (course == null) {
                writeAuditLog('Row ' + rowNumber + ': Learning Course was not found for Course Code "' + courseCode + '".', jobId);
                continue;
            }

            Decimal credit = resolveComponentCredit(course, courseType);
            if (credit == null) {
                writeAuditLog('Row ' + rowNumber + ': Course Type "' + courseType + '" does not match a configured component for Course Code "' + courseCode + '".', jobId);
                continue;
            }

            String offeringKey = buildOfferingKey(sessionRow.Id, course.Id, courseType);
            if (seenOfferingKeys.contains(offeringKey)) {
                writeAuditLog('Row ' + rowNumber + ': Duplicate row for Academic Session "' + sessionName + '", Course Code "' + courseCode + '", Course Type "' + courseType + '".', jobId);
                continue;
            }
            if (existingKeys.contains(offeringKey)) {
                writeAuditLog('Row ' + rowNumber + ': Course Offering already exists for Academic Session "' + sessionName + '", Course Code "' + courseCode + '", Course Type "' + courseType + '".', jobId);
                continue;
            }
            seenOfferingKeys.add(offeringKey);

            CourseOffering offering = new CourseOffering();
            offering.Name = buildOfferingName(course, sessionRow, courseType);
            offering.AcademicSessionId = sessionRow.Id;
            offering.LearningCourseId = course.Id;
            offering.IsActive = true;
            offering.Description = buildDescription(courseCode, courseType, sessionName);
            if (defaultRecordTypeId != null) {
                offering.RecordTypeId = defaultRecordTypeId;
            }

            putFieldValue(offering, coFields, 'Course_Type__c', courseType);
            putFieldValue(offering, coFields, 'Credit__c', credit);
            putFieldValue(offering, coFields, 'SectionNumber', getRowValue(row, 'Section Number'));
            putFieldValue(offering, coFields, 'EnrollmentCapacity', row.get('Enrollment Capacity'));
            putFieldValue(offering, coFields, 'WaitlistCapacity', row.get('Waitlist Capacity'));
            putFieldValue(offering, coFields, 'StartDate', row.get('Start Date'));
            putFieldValue(offering, coFields, 'EndDate', row.get('End Date'));

            String facultyEmail = getRowValue(row, 'Faculty Email');
            if (String.isNotBlank(facultyEmail)) {
                Id facultyContactId = facultyContactIdByEmail.get(facultyEmail.toLowerCase());
                if (facultyContactId == null) {
                    writeAuditLog('Row ' + rowNumber + ': Faculty was not found for email "' + facultyEmail + '".', jobId);
                    continue;
                }
                putFieldValue(offering, coFields, 'PrimaryFacultyId', facultyContactId);
            }

            offeringsToInsert.add(offering);
            rowIndexes.add(i);
        }

        if (!offeringsToInsert.isEmpty()) {
            Database.SaveResult[] results = Database.insert(offeringsToInsert, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    logSaveResultErrors(rowIndexes[i], scope, results[i], jobId);
                }
            }
        }

        flushAuditLogs();
    }

    public void finish(Database.BatchableContext bc) {}

    private Map<String, AcademicSession> getSessionsByName(Set<String> sessionNames) {
        Map<String, AcademicSession> sessionByName = new Map<String, AcademicSession>();
        if (sessionNames == null || sessionNames.isEmpty()) {
            return sessionByName;
        }

        for (AcademicSession sessionRow : [
            SELECT Id, Name
            FROM AcademicSession
            WHERE AcademicTermId = :academicTermId
            AND Name IN :sessionNames
        ]) {
            sessionByName.put(normalizeKey(sessionRow.Name), sessionRow);
        }
        return sessionByName;
    }

    private Map<String, LearningCourse> getCoursesByCode(Set<String> courseCodes) {
        Map<String, LearningCourse> courseByCode = new Map<String, LearningCourse>();
        if (courseCodes == null || courseCodes.isEmpty()) {
            return courseByCode;
        }

        for (LearningCourse course : [
            SELECT Id, Name, CourseNumber, CourseType, Credit_1__c, Course_Type_2__c, Credit_2__c, Course_Type_3__c, Credit_3__c
            FROM LearningCourse
            WHERE CourseNumber IN :courseCodes
        ]) {
            courseByCode.put(normalizeKey(course.CourseNumber), course);
        }
        return courseByCode;
    }

    private Map<String, Id> getFacultyContactIdsByEmail(Set<String> facultyEmails) {
        Map<String, Id> contactIdByEmail = new Map<String, Id>();
        if (facultyEmails == null || facultyEmails.isEmpty()) {
            return contactIdByEmail;
        }

        for (Contact contactRow : [
            SELECT Id, Email
            FROM Contact
            WHERE Email IN :facultyEmails
        ]) {
            if (String.isNotBlank(contactRow.Email)) {
                contactIdByEmail.put(contactRow.Email.trim().toLowerCase(), contactRow.Id);
            }
        }

        for (Account accountRow : [
            SELECT PersonContactId, PersonEmail
            FROM Account
            WHERE IsPersonAccount = true
            AND PersonEmail IN :facultyEmails
        ]) {
            if (accountRow.PersonContactId != null && String.isNotBlank(accountRow.PersonEmail)) {
                contactIdByEmail.put(accountRow.PersonEmail.trim().toLowerCase(), accountRow.PersonContactId);
            }
        }
        return contactIdByEmail;
    }

    private Set<String> getExistingOfferingKeys(Set<Id> sessionIds, Set<Id> courseIds) {
        Set<String> keys = new Set<String>();
        if (sessionIds == null || sessionIds.isEmpty() || courseIds == null || courseIds.isEmpty()) {
            return keys;
        }

        for (CourseOffering offering : [
            SELECT AcademicSessionId, LearningCourseId, Course_Type__c
            FROM CourseOffering
            WHERE AcademicSessionId IN :sessionIds
            AND LearningCourseId IN :courseIds
        ]) {
            keys.add(buildOfferingKey(offering.AcademicSessionId, offering.LearningCourseId, offering.Course_Type__c));
        }
        return keys;
    }

    private static Decimal resolveComponentCredit(LearningCourse course, String courseType) {
        String requested = normalizeKey(courseType);
        if (String.isBlank(requested) || course == null) {
            return null;
        }
        if (requested == normalizeKey(course.CourseType)) {
            return course.Credit_1__c;
        }
        if (requested == normalizeKey(course.Course_Type_2__c)) {
            return course.Credit_2__c;
        }
        if (requested == normalizeKey(course.Course_Type_3__c)) {
            return course.Credit_3__c;
        }
        return null;
    }

    private static String buildOfferingKey(Id sessionId, Id courseId, String courseType) {
        return String.valueOf(sessionId) + '|' + String.valueOf(courseId) + '|' + normalizeKey(courseType);
    }

    private static String buildOfferingName(LearningCourse course, AcademicSession sessionRow, String courseType) {
        List<String> parts = new List<String>();
        if (course != null && String.isNotBlank(course.CourseNumber)) {
            parts.add(course.CourseNumber);
        }
        if (String.isNotBlank(courseType)) {
            parts.add(courseType);
        }
        if (sessionRow != null && String.isNotBlank(sessionRow.Name)) {
            parts.add(sessionRow.Name);
        }
        String name = String.join(parts, ' - ');
        return name.length() > 255 ? name.substring(0, 255) : name;
    }

    private static String buildDescription(String courseCode, String courseType, String sessionName) {
        String description = 'Bulk imported course offering';
        List<String> parts = new List<String>();
        if (String.isNotBlank(courseCode)) {
            parts.add('Course Code: ' + courseCode);
        }
        if (String.isNotBlank(courseType)) {
            parts.add('Course Type: ' + courseType);
        }
        if (String.isNotBlank(sessionName)) {
            parts.add('Academic Session: ' + sessionName);
        }
        if (!parts.isEmpty()) {
            description += ' (' + String.join(parts, ', ') + ')';
        }
        return description;
    }

    private static Id getDefaultCourseOfferingRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> recordTypes =
            CourseOffering.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();
        if (recordTypes.containsKey('Default')) {
            return recordTypes.get('Default').getRecordTypeId();
        }
        return null;
    }

    private static void addTrimmed(Set<String> values, String value) {
        if (values != null && String.isNotBlank(value)) {
            values.add(value.trim());
        }
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
                // Fall through to calculated row number.
            }
        }
        return String.valueOf(rowIndex + 1);
    }

    private static String normalizeKey(String value) {
        return String.isBlank(value) ? '' : value.trim().toLowerCase();
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
                KenAuditLogHelper.auditLogRecord(processName, 'Class:KenCourseOfferingBulkImportBatch');
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