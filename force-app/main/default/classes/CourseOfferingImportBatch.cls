/**
 * @description
 *
 * Usage:
 *  - Apex: classes/HistoricalDataImportController.cls -> CourseOfferingImportBatch
 */
public without sharing class CourseOfferingImportBatch implements Database.Batchable<Map<String, Object>>, Database.Stateful {
    private final String jsonRows;
    private final Id academicSessionId;
    private final Id learningProgramPlanId;
    private List<Audit_Log__c> pendingLogs = new List<Audit_Log__c>();

    public CourseOfferingImportBatch(String jsonRows, Id academicSessionId, Id learningProgramPlanId) {
        this.jsonRows = jsonRows;
        this.academicSessionId = academicSessionId;
        this.learningProgramPlanId = learningProgramPlanId;
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

        // Collect unique course codes, session names, and faculty emails from rows
        Set<String> courseCodes = new Set<String>();
        Set<String> sessionNames = new Set<String>();
        Set<String> facultyEmails = new Set<String>();
        for (Map<String, Object> row : scope) {
            if (row == null) {continue;}
            String courseCode = getRowValue(row, 'Course Code');
            if (String.isNotBlank(courseCode)) {courseCodes.add(courseCode.trim());}
            String sessionName = getRowValue(row, 'Academic Session');
            if (String.isNotBlank(sessionName)) {sessionNames.add(sessionName.trim());}
            String facultyEmail = getRowValue(row, 'Faculty Email');
            if (String.isNotBlank(facultyEmail)) {facultyEmails.add(facultyEmail.toLowerCase());}
        }

        // Resolve LearningCourse by CourseNumber
        Map<String, LearningCourse> courseByCode = new Map<String, LearningCourse>();
        if (!courseCodes.isEmpty()) {
            for (LearningCourse lc : [
                SELECT Id, CourseNumber, Name
                FROM LearningCourse
                WHERE CourseNumber IN :courseCodes
            ]) {
                if (String.isNotBlank(lc.CourseNumber)) {
                    courseByCode.put(lc.CourseNumber.trim(), lc);
                }
            }
        }

        // Resolve AcademicSession by name
        Map<String, AcademicSession> sessionByName = new Map<String, AcademicSession>();
        if (!sessionNames.isEmpty()) {
            for (AcademicSession sess : [
                SELECT Id, Name
                FROM AcademicSession
                WHERE Name IN :sessionNames
            ]) {
                sessionByName.put(sess.Name.trim(), sess);
            }
        }

        // Also fetch the provided academicSessionId for fallback
        AcademicSession defaultSession;
        if (academicSessionId != null) {
            List<AcademicSession> defaultSessions = [
                SELECT Id, Name
                FROM AcademicSession
                WHERE Id = :academicSessionId
                LIMIT 1
            ];
            if (!defaultSessions.isEmpty()) {defaultSession = defaultSessions[0];}
        }

        // Resolve PrimaryFaculty contact by email
        Map<String, Id> facultyContactIdByEmail = new Map<String, Id>();
        if (!facultyEmails.isEmpty()) {
            for (Account acc : [
                SELECT Id, PersonContactId, PersonEmail
                FROM Account
                WHERE IsPersonAccount = true
                AND PersonEmail IN :facultyEmails
            ]) {
                if (String.isNotBlank(acc.PersonEmail) && acc.PersonContactId != null) {
                    facultyContactIdByEmail.put(acc.PersonEmail.trim().toLowerCase(), acc.PersonContactId);
                }
            }
        }

        // Fetch existing CourseOfferings to check duplicates by (LearningCourseId + AcademicSessionId + SectionNumber)
        Set<Id> resolvedCourseIds = new Set<Id>();
        for (LearningCourse lc : courseByCode.values()) {
            resolvedCourseIds.add(lc.Id);
        }
        Set<Id> resolvedSessionIds = new Set<Id>();
        if (defaultSession != null) {resolvedSessionIds.add(defaultSession.Id);}
        for (AcademicSession sess : sessionByName.values()) {
            resolvedSessionIds.add(sess.Id);
        }

        Map<String, Id> existingOfferingByKey = new Map<String, Id>();
        if (!resolvedCourseIds.isEmpty() && !resolvedSessionIds.isEmpty()) {
            for (CourseOffering co : [
                SELECT Id, LearningCourseId, AcademicSessionId, SectionNumber
                FROM CourseOffering
                WHERE LearningCourseId IN :resolvedCourseIds
                AND AcademicSessionId IN :resolvedSessionIds
            ]) {
                String key = String.valueOf(co.LearningCourseId) + '|' +
                    String.valueOf(co.AcademicSessionId) + '|' +
                    (co.SectionNumber != null ? co.SectionNumber.trim() : '');
                existingOfferingByKey.put(key, co.Id);
            }
        }

        // Describe CourseOffering fields for convertValue
        Map<String, Schema.SObjectField> coFields = CourseOffering.SObjectType.getDescribe().fields.getMap();

        List<CourseOffering> offeringsToInsert = new List<CourseOffering>();
        List<Integer> offeringRowIndexes = new List<Integer>();
        List<Map<String, Object>> rowMaps = new List<Map<String, Object>>();

        for (Integer i = 0; i < scope.size(); i++) {
            Map<String, Object> row = scope[i];
            if (row == null) {continue;}
            rowMaps.add(row);
            Integer rowIdx = rowMaps.size() - 1;

            String courseCode = getRowValue(row, 'Course Code');
            if (String.isBlank(courseCode)) {
                writeAuditLog('Row ' + getRowNumber(i, scope) + ': Course Code is required.', jobId);
                continue;
            }

            LearningCourse learningCourse = courseByCode.get(courseCode.trim());
            if (learningCourse == null) {
                writeAuditLog('Row ' + getRowNumber(i, scope) + ': LearningCourse not found for Course Code "' + courseCode + '".', jobId);
                continue;
            }

            // Resolve session
            String sessionName = getRowValue(row, 'Academic Session');
            AcademicSession resolvedSession = defaultSession;
            if (String.isNotBlank(sessionName) && sessionByName.containsKey(sessionName.trim())) {
                resolvedSession = sessionByName.get(sessionName.trim());
            }
            if (resolvedSession == null) {
                writeAuditLog('Row ' + getRowNumber(i, scope) + ': Academic Session could not be resolved.', jobId);
                continue;
            }

            String sectionNumber = getRowValue(row, 'Section Number');

            // Check for duplicate
            String dupKey = String.valueOf(learningCourse.Id) + '|' +
                String.valueOf(resolvedSession.Id) + '|' +
                (String.isNotBlank(sectionNumber) ? sectionNumber.trim() : '');
            if (existingOfferingByKey.containsKey(dupKey)) {
                writeAuditLog('Row ' + getRowNumber(i, scope) + ': CourseOffering already exists for Course Code "' + courseCode + '", Session "' + resolvedSession.Name + '", Section "' + sectionNumber + '". Skipped.', jobId);
                continue;
            }

            // Build CourseOffering record
            CourseOffering co = new CourseOffering();

            String courseType = getRowValue(row, 'Course Type');
            String offeringName = learningCourse.CourseNumber + ' - ' + learningCourse.Name + ' - ' +
                (String.isNotBlank(courseType) ? courseType : '') + ' ' +
                resolvedSession.Name + ' ' + String.valueOf(System.now().getTime());
            co.Name = offeringName.length() > 255 ? offeringName.substring(0, 255) : offeringName;

            co.LearningCourseId = learningCourse.Id;
            co.AcademicSessionId = resolvedSession.Id;

            putFieldValue(co, coFields, 'Course_Type__c', courseType);
            putFieldValue(co, coFields, 'Credit__c', row.get('Credit'));
            putFieldValue(co, coFields, 'Credit_Hours__c', row.get('Credit Hours'));

            if (String.isNotBlank(sectionNumber)) {
                putFieldValue(co, coFields, 'SectionNumber', sectionNumber);
            }

            // Resolve faculty
            String facultyEmail = getRowValue(row, 'Faculty Email');
            if (String.isNotBlank(facultyEmail)) {
                Id facultyContactId = facultyContactIdByEmail.get(facultyEmail.toLowerCase());
                if (facultyContactId != null) {
                    putFieldValue(co, coFields, 'PrimaryFacultyId', facultyContactId);
                } else {
                    writeAuditLog('Row ' + getRowNumber(i, scope) + ': Faculty not found for email "' + facultyEmail + '".', jobId);
                }
            }

            putFieldValue(co, coFields, 'EnrollmentCapacity', row.get('Enrollment Capacity'));
            putFieldValue(co, coFields, 'WaitlistCapacity', row.get('Waitlist Capacity'));

            // Dates: use row values if provided
            Object startDateVal = row.get('Start Date');
            Object endDateVal = row.get('End Date');
            if (startDateVal != null && String.isNotBlank(String.valueOf(startDateVal))) {
                putFieldValue(co, coFields, 'StartDate', startDateVal);
            }
            if (endDateVal != null && String.isNotBlank(String.valueOf(endDateVal))) {
                putFieldValue(co, coFields, 'EndDate', endDateVal);
            }

            putFieldValue(co, coFields, 'isPlaceholder__c', true);
            putFieldValue(co, coFields, 'IsActive', true);

            offeringsToInsert.add(co);
            offeringRowIndexes.add(rowIdx);

            // Mark key as used to avoid duplicates within the same batch
            existingOfferingByKey.put(dupKey, null);
        }

        // Insert CourseOfferings
        List<Id> insertedOfferingIds = new List<Id>();
        List<Integer> successRowIndexes = new List<Integer>();
        if (!offeringsToInsert.isEmpty()) {
            Database.SaveResult[] results = Database.insert(offeringsToInsert, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    insertedOfferingIds.add(results[i].getId());
                    successRowIndexes.add(offeringRowIndexes[i]);
                } else {
                    logSaveResultErrors('Course Offering insert', offeringRowIndexes[i], rowMaps, results[i], jobId);
                }
            }
        }

        // Create Program_Plan_Course_Junction__c for successful inserts
        if (learningProgramPlanId != null && !insertedOfferingIds.isEmpty()) {
            // Check existing junctions
            Set<Id> offeringIdSet = new Set<Id>(insertedOfferingIds);
            Map<String, Id> existingJunctions = new Map<String, Id>();
            for (Program_Plan_Course_Junction__c j : [
                SELECT Id, Learning_Program_Plan__c, Course_Offering__c
                FROM Program_Plan_Course_Junction__c
                WHERE Learning_Program_Plan__c = :learningProgramPlanId
                AND Course_Offering__c IN :offeringIdSet
            ]) {
                existingJunctions.put(
                    String.valueOf(j.Learning_Program_Plan__c) + ':' + String.valueOf(j.Course_Offering__c),
                    j.Id
                );
            }

            List<Program_Plan_Course_Junction__c> junctionsToInsert = new List<Program_Plan_Course_Junction__c>();
            List<Integer> junctionRowIndexes = new List<Integer>();
            for (Integer i = 0; i < insertedOfferingIds.size(); i++) {
                String key = String.valueOf(learningProgramPlanId) + ':' + String.valueOf(insertedOfferingIds[i]);
                if (existingJunctions.containsKey(key)) {continue;}
                Program_Plan_Course_Junction__c junction = new Program_Plan_Course_Junction__c(
                    Learning_Program_Plan__c = learningProgramPlanId,
                    Course_Offering__c = insertedOfferingIds[i]
                );
                junctionsToInsert.add(junction);
                junctionRowIndexes.add(successRowIndexes[i]);
            }
            saveRecords('Program Plan Course Junction insert', junctionsToInsert, junctionRowIndexes, rowMaps, jobId, true);
        }

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
        String courseCode = getRowValue(row, 'Course Code');
        if (String.isNotBlank(courseCode)) {return ' (CourseCode=' + courseCode + ')';}
        return '';
    }

    private void writeAuditLog(String message, Id jobId) {
        if (String.isBlank(message)) {return;}
        try {
            KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord('Course Offering Import', 'Class:CourseOfferingImportBatch');
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