/**
 * ************************************************************************************************
 * @className  CourseImportBatch
 *
 * @description
 *  Batch processor for Course imports.
 *
 *  Responsibilities:
 *  - Parse incoming JSON row payloads
 *  - Create Learning and LearningCourse records
 *  - Detect duplicate Course Number values (in-file and in-org)
 *  - Create related LearningAchievement and LearningOutcomeItem records
 *  - Track validation and DML failures in Audit_Log__c via KenAuditLogHelper
 *
 * @author      Sureka A R K
 * @createdOn   Feb 03, 2026
 *
 * @history
 * ------------------------------------------------------------------------------------------------
 * Version   Date           Author          Description
 * 1.0       Feb 03, 2026   Sureka A R K    Added docs and centralized audit/error handling
 * ************************************************************************************************
 */

@SuppressWarnings('PMD.StdCyclomaticComplexity,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssTypeCount,PMD.NcssMethodCount,PMD.ExcessiveParameterList')
public with sharing class CourseImportBatch implements Database.Batchable<Map<String, Object>>, Database.Stateful {
    private final String jsonRows;
    private final Id providerId;
    private final Id instituteId;
    private Integer successCount = 0;
    private Integer totalCount = 0;
    private final String recordTypeName;
    /**
     * @description Pending audit log records buffered during execution and inserted in bulk.
     */
    private List<Audit_Log__c> pendingLogs = new List<Audit_Log__c>();
    
    /**
     * @description Creates a new batch instance for course import rows.
     * @param jsonRows JSON array string where each item represents one source row.
     * @param providerId Provider lookup used for Learning records.
     * @param instituteId Institute lookup used as issuer for LearningAchievement.
     */
    public CourseImportBatch(String jsonRows, Id providerId, Id instituteId) {
        this.jsonRows = jsonRows;
        this.providerId = providerId;
        this.instituteId = instituteId;
    }
    
    /**
     * @description Deserializes the input JSON string into iterable row maps.
     * @param bc Batch context.
     * @return Iterable row maps consumed by execute.
     */
    public Iterable<Map<String, Object>> start(Database.BatchableContext bc) {
        List<Map<String, Object>> maps = new List<Map<String, Object>>();
        if (String.isBlank(jsonRows)) {return maps;}
        List<Object> rows = (List<Object>) JSON.deserializeUntyped(jsonRows);
        for (Object o : rows) {
            if (o instanceof Map<String, Object>){ maps.add((Map<String, Object>) o);}
        }
        return maps;
    }
    
    /**
     * @description Processes a scope of rows and creates all related records.
     * @param bc Batch context used to derive AsyncApexJob id for logging.
     * @param scope Scope rows for this chunk.
     */
    public void execute(Database.BatchableContext bc, List<Map<String, Object>> scope) {
        Id jobId = bc != null ? bc.getJobId() : null;
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Learning') || !gd.containsKey('LearningCourse')) {return;}
        
        Schema.SObjectType learnType = gd.get('Learning');
        Schema.SObjectType courseType = gd.get('LearningCourse');
        Schema.SObjectType achievementType = gd.containsKey('LearningAchievement') ? gd.get('LearningAchievement') : null;
        Schema.SObjectType outcomeType = gd.containsKey('LearningOutcomeItem') ? gd.get('LearningOutcomeItem') : null;
        Map<String, Schema.SObjectField> learnFields = learnType.getDescribe().fields.getMap();
        Map<String, Schema.SObjectField> courseFields = courseType.getDescribe().fields.getMap();
        Map<String, Schema.SObjectField> achievementFields = achievementType != null
            ? achievementType.getDescribe().fields.getMap()
            : new Map<String, Schema.SObjectField>();
        Map<String, Schema.SObjectField> outcomeFields = outcomeType != null
            ? outcomeType.getDescribe().fields.getMap()
            : new Map<String, Schema.SObjectField>();
        
        List<SObject> learnings = new List<SObject>();
        List<Map<String, Object>> rowMaps = new List<Map<String, Object>>();
        
        for (Object o : scope) {
            if (!(o instanceof Map<String, Object>)) {continue;}
            Map<String, Object> row = (Map<String, Object>) o;
            rowMaps.add(row);
            SObject s = learnType.newSObject();
            if (learnFields.containsKey('Type')) {
                Schema.DescribeFieldResult typeField = learnFields.get('Type').getDescribe();
                if (typeField.isCreateable()) {
                    s.put('Type', 'LearningCourse');
                }
            }
            for (String key : row.keySet()) {
                if (key == 'ProviderId') {
                    continue;
                }
                if (learnFields.containsKey(key)) {
                    Schema.DescribeFieldResult d = learnFields.get(key).getDescribe();
                    if (!d.isCreateable()) {continue;}
                    try {
                        Object val = ImportUtils.convertValue(row.get(key), d);
                        s.put(key, val);
                    } catch (Exception e) {
                        KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord(
                            'Course Import',
                        'Class:CourseImportBatch'
                            );
                        creator.setErrorMessage('CourseImportBatch.execute learning field conversion failed for field ' + key + ': ' + e.getMessage());
                        creator.setStackTrace(e.getStackTraceString());
                        if (jobId != null) {
                            creator.setRecordId(String.valueOf(jobId));
                        }
                        creator.create();
                    }
                }
            }
            if (providerId != null && learnFields.containsKey('ProviderId')) {
                Schema.DescribeFieldResult providerField = learnFields.get('ProviderId').getDescribe();
                if (providerField.isCreateable()) {
                    s.put('ProviderId', providerId);
                }
            }
            learnings.add(s);
        }
        
        List<Id> learningIdByRow = new List<Id>();
        if (!learnings.isEmpty()) {
            Database.SaveResult[] srs = Database.insert(learnings, false);
            for (Integer i=0;i<srs.size();i++){
                if (srs[i].isSuccess()) {
                    learningIdByRow.add((Id)learnings[i].get('Id'));
                } else {
                    learningIdByRow.add(null);
                    logSaveResultErrors('Learning insert', i, rowMaps, srs[i], jobId);
                }
            }
        }
        
        String courseNumberField = null;
        List<String> courseNumberCandidates = new List<String>{'CourseNumber','Course_Number__c','CourseNumber__c','Course_Number__c'};
        for (String cand : courseNumberCandidates){ if (courseFields.containsKey(cand)) { courseNumberField = cand; break; }}
        
        Map<String, Id> existingCourseByNumber = new Map<String, Id>();
        if (courseNumberField != null) {
            Set<String> incomingNumbers = new Set<String>();
            for (Map<String,Object> r : rowMaps) {
                if (r.containsKey(courseNumberField) && r.get(courseNumberField) != null) {
                    incomingNumbers.add(String.valueOf(r.get(courseNumberField)).trim());
                }
            }
            if (!incomingNumbers.isEmpty()) {
                List<String> lits = new List<String>();
                for (String v : incomingNumbers){ lits.add('\''+String.escapeSingleQuotes(v)+'\'');}
                String soql = 'SELECT Id, ' + courseNumberField + ' FROM LearningCourse WHERE ' + courseNumberField + ' IN (' + String.join(lits,',') + ')';
                try {
                    for (SObject ex : Database.query(soql)) {
                        addExistingCourseByNumber(existingCourseByNumber, ex, courseNumberField);
                    }
                } catch (Exception e) {
                    KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord(
                        'Course Import',
                    'Class:CourseImportBatch'
                        );
                    creator.setErrorMessage('CourseImportBatch.execute duplicate check query failed: ' + e.getMessage());
                    creator.setStackTrace(e.getStackTraceString());
                    setAuditRecordIdIfPresent(creator, jobId);
                    creator.create();
                }
            }
        }
        
        List<SObject> courses = new List<SObject>();
        List<Integer> courseRowIndexes = new List<Integer>();
        Set<Id> learningIdsToDelete = new Set<Id>();
        Set<String> seenCourseNumbers = new Set<String>();
        Set<String> courseFieldSkip = new Set<String>{
            'ActiveFromDate',
            'ActiveToDate',
            'Duration',
            'DurationUnit',
            'ProviderId',
            'CipCode',
            'IsActive',
            'AcademicLevel'
        };
        for (Integer i=0;i<rowMaps.size();i++) {
            Map<String, Object> row = rowMaps[i];
            SObject c = courseType.newSObject();
            Id learningIdForRow = getLearningIdByIndex(learningIdByRow, i);
            if (learningIdForRow != null) {
                if (courseFields.containsKey('LearningId')) {
                    c.put('LearningId', learningIdForRow);
                } else if (courseFields.containsKey('Learning__c')) {
                    c.put('Learning__c', learningIdForRow);
                }
            }
            if (courseNumberField != null && row.containsKey(courseNumberField) && row.get(courseNumberField) != null) {
                String num = String.valueOf(row.get(courseNumberField)).trim();
                if (num.length() > 0 && seenCourseNumbers.contains(num.toLowerCase())) {
                    logDuplicate('Duplicate in file', i, rowMaps, courseNumberField, num, jobId);
                    markLearningForDelete(learningIdsToDelete, learningIdForRow);
                    continue;
                }
                if (existingCourseByNumber.containsKey(num)) {
                    logDuplicate('Duplicate in org', i, rowMaps, courseNumberField, num, jobId);
                    markLearningForDelete(learningIdsToDelete, learningIdForRow);
                    continue;
                }
                if (num.length() > 0) {seenCourseNumbers.add(num.toLowerCase());}
            }
            for (String key : row.keySet()) {
                if (courseFieldSkip.contains(key)) {continue;}
                if (courseFields.containsKey(key)) {
                    Schema.DescribeFieldResult d = courseFields.get(key).getDescribe();
                    if (!d.isCreateable()) {continue;}
                    try {
                        Object val = ImportUtils.convertValue(row.get(key), d);
                        c.put(key, val);
                    } catch (Exception e) {
                        KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord(
                            'Course Import',
                        'Class:CourseImportBatch'
                            );
                        creator.setErrorMessage('CourseImportBatch.execute learning course field conversion failed for field ' + key + ': ' + e.getMessage());
                        creator.setStackTrace(e.getStackTraceString());
                        setAuditRecordIdIfPresent(creator, jobId);
                        creator.create();
                    }
                }
            }
            courses.add(c);
            courseRowIndexes.add(i);
        }
        
        List<Integer> successfulCourseIndexes = new List<Integer>();
        if (!courses.isEmpty()) {
            Database.SaveResult[] srs = Database.insert(courses, false);
            for (Integer i=0;i<srs.size();i++){
                if (!srs[i].isSuccess()) {
                    Integer rowIndex = courseRowIndexes[i];
                    markLearningForDelete(learningIdsToDelete, getLearningIdByIndex(learningIdByRow, rowIndex));
                    logSaveResultErrors('Learning Course insert', rowIndex, rowMaps, srs[i], jobId);
                } else {
                    successfulCourseIndexes.add(i);
                }
            }
        }
        
        createLearningAchievementsAndOutcomes(
            rowMaps,
        learningIdByRow,
        courses,
        courseRowIndexes,
        successfulCourseIndexes,
        achievementType,
        outcomeType,
        achievementFields,
        outcomeFields,
        jobId
            );
        
        if (!learningIdsToDelete.isEmpty()) {
            Database.delete(new List<Id>(learningIdsToDelete), false);
        }
        
        flushAuditLogs();
    }
    
    /**
     * @description Finalizes the batch. Logging is already flushed in execute for each chunk.
     * @param bc Batch context.
     */
    public void finish(Database.BatchableContext bc) {
        Id jobId = bc != null ? bc.getJobId() : null;
        String completionMessage = 'Course import batch completed';
        if (jobId != null) {
            completionMessage += ' (JobId=' + String.valueOf(jobId) + ')';
        }
        KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord(
            'Course Import',
        'Class:CourseImportBatch'
            );
        creator.setErrorMessage(completionMessage);
        setAuditRecordIdIfPresent(creator, jobId);
        creator.create();
    }
    
    /**
     * @description Logs first DML error from a SaveResult with row metadata.
     * @param stage Pipeline stage where DML failed.
     * @param rowIndex Zero-based row index.
     * @param rows Source row collection.
     * @param sr Save result for the row.
     * @param jobId Async job id.
     */
    private void logSaveResultErrors(String stage, Integer rowIndex, List<Map<String, Object>> rows, Database.SaveResult sr, Id jobId) {
        if (sr == null || sr.isSuccess() || sr.getErrors() == null || sr.getErrors().isEmpty()) {return;}
        Database.Error e = sr.getErrors()[0];
        Integer rowNum = getRowNumber(rowIndex, rows);
        String rowLabel = rowNum != null ? 'Row ' + rowNum : 'Row';
        String rowHint = getRowHint(rowIndex, rows);
        String msg = stage + ' - ' + rowLabel + rowHint + ': ' + e.getMessage();
        writeAuditLog(msg, jobId);
    }
    
    /**
     * @description Builds a lightweight row identifier suffix for audit messages.
     * @param rowIndex Zero-based row index.
     * @param rows Source rows.
     * @return Row hint string such as course number or name.
     */
    private static String getRowHint(Integer rowIndex, List<Map<String, Object>> rows) {
        if (rowIndex == null || rows == null || rowIndex < 0 || rowIndex >= rows.size()) {return '';}
        Map<String, Object> row = rows[rowIndex];
        if (row == null) {return '';}
        if (row.containsKey('CourseNumber') && row.get('CourseNumber') != null) {return ' (CourseNumber=' + String.valueOf(row.get('CourseNumber')) + ')';}
        if (row.containsKey('Name') && row.get('Name') != null) {return ' (Name=' + String.valueOf(row.get('Name')) + ')';}
        return '';
    }
    
    /**
     * @description Buffers one audit log entry for later bulk insert.
     * @param message Error or warning message.
     * @param jobId Async job id stored as Record Id text.
     */
    private void writeAuditLog(String message, Id jobId) {
        if (String.isBlank(message)) {return;}
        
        KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord(
            'Course Import',
        'Class:CourseImportBatch'
            );
        creator.setErrorMessage(message);
        if (jobId != null) {creator.setRecordId(String.valueOf(jobId));}
        Audit_Log__c log = creator.returnWithoutCreate();
        if (log != null) {pendingLogs.add(log);}
        
    }
    
    /**
     * @description Logs duplicate-course detection details.
     * @param reason Duplicate source reason.
     * @param rowIndex Zero-based row index.
     * @param rows Source rows.
     * @param fieldName Duplicate field name.
     * @param fieldValue Duplicate field value.
     * @param jobId Async job id.
     */
    private void logDuplicate(String reason, Integer rowIndex, List<Map<String, Object>> rows, String fieldName, String fieldValue, Id jobId) {
        Integer rowNum = getRowNumber(rowIndex, rows);
        String rowLabel = rowNum != null ? 'Row ' + rowNum : 'Row';
        String msg = 'Course duplicate skipped (' + reason + ') - ' + rowLabel + ' (' + fieldName + '=' + fieldValue + ')';
        writeAuditLog(msg, jobId);
    }
    
    /**
     * @description Resolves display row number from input metadata when provided.
     * @param rowIndex Zero-based row index.
     * @param rows Source rows.
     * @return One-based row number or null when unavailable.
     */
    private static Integer getRowNumber(Integer rowIndex, List<Map<String, Object>> rows) {
        if (rowIndex == null || rows == null || rowIndex < 0 || rowIndex >= rows.size()) {return null;}
        Map<String, Object> row = rows[rowIndex];
        if (row != null && row.containsKey('RowNumber') && row.get('RowNumber') != null) {
            try {
                return Integer.valueOf(String.valueOf(row.get('RowNumber')).trim());
            } catch (Exception e) {
                KenAuditLogHelper.auditLogRecord(
                    'Course Import',
                'Class:CourseImportBatch'
                    )
                    .setErrorMessage('CourseImportBatch.getRowNumber invalid RowNumber value: ' + e.getMessage())
                    .setStackTrace(e.getStackTraceString())
                    .create();
            }
        }
        return rowIndex + 1;
    }
    
    /**
     * @description Bulk-inserts buffered audit logs with truncation enabled.
     */
    private void flushAuditLogs() {
        if (pendingLogs == null || pendingLogs.isEmpty()) {return;}
        try {
            Database.DMLOptions dmlOptions = new Database.DMLOptions();
            dmlOptions.allowFieldTruncation = true;
            Database.insert(pendingLogs, dmlOptions);
        } catch (Exception ex) {
            KenAuditLogHelper.auditLogRecord(
                'Course Import',
            'Class:CourseImportBatch'
                )
                .setErrorMessage('CourseImportBatch.flushAuditLogs insert failed: ' + ex.getMessage())
                .setStackTrace(ex.getStackTraceString())
                .create();
        } finally {
            pendingLogs.clear();
        }
    }
    
    /**
     * @description Creates LearningAchievement and LearningOutcomeItem for successful course rows.
     * @param rowMaps Source row collection.
     * @param learningIdByRow Learning ids aligned to row indexes.
     * @param courses Inserted course list for this chunk.
     * @param courseRowIndexes Mapping of course list index to original row index.
     * @param successfulCourseIndexes Successful course insert indexes.
     * @param achievementType LearningAchievement sObject type.
     * @param outcomeType LearningOutcomeItem sObject type.
     * @param achievementFields Describe field map for LearningAchievement.
     * @param outcomeFields Describe field map for LearningOutcomeItem.
     * @param jobId Async job id for audit logging.
     */
    private void createLearningAchievementsAndOutcomes(
        List<Map<String, Object>> rowMaps,
    List<Id> learningIdByRow,
    List<SObject> courses,
    List<Integer> courseRowIndexes,
    List<Integer> successfulCourseIndexes,
    Schema.SObjectType achievementType,
    Schema.SObjectType outcomeType,
    Map<String, Schema.SObjectField> achievementFields,
    Map<String, Schema.SObjectField> outcomeFields,
    Id jobId
    ) {
        if (achievementType == null || outcomeType == null) {return;}
        if (!Schema.SObjectType.LearningAchievement.isCreateable() ||
        !Schema.SObjectType.LearningOutcomeItem.isCreateable()) {
            return;
        }
        if (successfulCourseIndexes == null || successfulCourseIndexes.isEmpty()) {return;}
        
        Id learningCourseRtId = getLearningAchievementRecordTypeId();
        List<SObject> achievements = new List<SObject>();
        List<Integer> achievementRowIndexes = new List<Integer>();
        
        for (Integer idx = 0; idx < successfulCourseIndexes.size(); idx++) {
            Integer i = successfulCourseIndexes[idx];
            Integer rowIndex = courseRowIndexes[i];
            if (rowIndex == null || rowIndex >= learningIdByRow.size()) {continue;}
            Id learningId = learningIdByRow[rowIndex];
            if (learningId == null) {continue;}
            
            Map<String, Object> row = rowIndex < rowMaps.size() ? rowMaps[rowIndex] : null;
            SObject a = achievementType.newSObject();
            
            if (learningCourseRtId != null && achievementFields.containsKey('RecordTypeId')) {
                Schema.DescribeFieldResult rtField = achievementFields.get('RecordTypeId').getDescribe();
                if (rtField.isCreateable()) {
                    a.put('RecordTypeId', learningCourseRtId);
                }
            }
            
            String nameVal = getRowString(row, 'Name');
            if (String.isBlank(nameVal)) {nameVal = 'Course';}
            if (achievementFields.containsKey('Name') &&
            achievementFields.get('Name').getDescribe().isCreateable()) {
                a.put('Name', 'Default Achievement: ' + nameVal);
            }
            
            if (achievementFields.containsKey('IssuerId')) {
                Schema.DescribeFieldResult issuerField = achievementFields.get('IssuerId').getDescribe();
                if (issuerField.isCreateable() && instituteId != null) {
                    a.put('IssuerId', instituteId);
                }
            }
            
            setAchievementFieldFromRow(a, row, 'FieldOfStudy', achievementFields);
            setAchievementFieldFromRow(a, row, 'Description', achievementFields);
            setAchievementFieldFromRow(a, row, 'AcademicLevel', achievementFields);
            setAchievementFieldFromRow(a, row, 'Specialization', achievementFields);
            
            if (achievementFields.containsKey('Abbreviation') &&
            achievementFields.get('Abbreviation').getDescribe().isCreateable()) {
                String abbr = getRowString(row, 'Abbreviation');
                if (String.isBlank(abbr)) {abbr = getRowString(row, 'CourseNumber');}
                if (!String.isBlank(abbr)) {
                    try {
                        Object val = ImportUtils.convertValue(abbr, achievementFields.get('Abbreviation').getDescribe());
                        a.put('Abbreviation', val);
                    } catch (Exception e) {
                        KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord(
                            'Course Import',
                        'Class:CourseImportBatch'
                            );
                        creator.setErrorMessage('CourseImportBatch.createLearningAchievementsAndOutcomes abbreviation conversion failed: ' + e.getMessage());
                        creator.setStackTrace(e.getStackTraceString());
                        setAuditRecordIdIfPresent(creator, jobId);
                        creator.create();
                    }
                }
            }
            
            achievements.add(a);
            achievementRowIndexes.add(rowIndex);
        }
        
        if (achievements.isEmpty()) {return;}
        
        Database.SaveResult[] aSrs = Database.insert(achievements, false);
        List<SObject> outcomes = new List<SObject>();
        List<Integer> outcomeRowIndexes = new List<Integer>();
        
        for (Integer i = 0; i < aSrs.size(); i++) {
            Integer rowIndex = achievementRowIndexes[i];
            if (!aSrs[i].isSuccess()) {
                logSaveResultErrors('Learning Achievement insert', rowIndex, rowMaps, aSrs[i], jobId);
                continue;
            }
            Id achievementId = (Id) achievements[i].get('Id');
            if (rowIndex == null || rowIndex >= learningIdByRow.size()) {continue;}
            Id learningId = learningIdByRow[rowIndex];
            if (learningId == null) {continue;}
            
            Map<String, Object> row = rowIndex < rowMaps.size() ? rowMaps[rowIndex] : null;
            SObject loi = outcomeType.newSObject();
            
            if (outcomeFields.containsKey('LearningId') &&
            outcomeFields.get('LearningId').getDescribe().isCreateable()) {
                loi.put('LearningId', learningId);
            }
            if (outcomeFields.containsKey('LearningAchievementId') &&
            outcomeFields.get('LearningAchievementId').getDescribe().isCreateable()) {
                loi.put('LearningAchievementId', achievementId);
            }
            
            setOutcomeFieldFromRow(loi, row, 'Duration', outcomeFields);
            setOutcomeFieldFromRow(loi, row, 'DurationUnit', outcomeFields);
            
            outcomes.add(loi);
            outcomeRowIndexes.add(rowIndex);
        }
        
        if (!outcomes.isEmpty()) {
            Database.SaveResult[] oSrs = Database.insert(outcomes, false);
            for (Integer i = 0; i < oSrs.size(); i++) {
                if (!oSrs[i].isSuccess()) {
                    logSaveResultErrors('Learning Outcome Item insert', outcomeRowIndexes[i], rowMaps, oSrs[i], jobId);
                }
            }
        }
    }
    
    /**
     * @description Looks up LearningAchievement record type used for course achievement creation.
     * @return RecordType Id when found; otherwise null.
     */
    private static Id getLearningAchievementRecordTypeId() {
        try {
            List<RecordType> rts = [
                SELECT Id, Name, DeveloperName
                FROM RecordType
                WHERE SobjectType = 'LearningAchievement'
                AND (
                    DeveloperName IN (
                        'Learning_Course',
                        'LearningCourse'
                    )
                    OR Name IN (
                        'Learning Course',
                        'Learning_Course'
                    )
                )
                LIMIT 1
            ];
            if (!rts.isEmpty()) {
                return rts[0].Id;
            }
        } catch (Exception e) {
            KenAuditLogHelper.auditLogRecord(
                'Course Import',
            'Class:CourseImportBatch'
                )
                .setErrorMessage('CourseImportBatch.getLearningAchievementRecordTypeId lookup failed: ' + e.getMessage())
                .setStackTrace(e.getStackTraceString())
                .create();
        }
        return null;
    }
    
    /**
     * @description Sets one createable LearningAchievement field from row data.
     * @param target Target LearningAchievement record.
     * @param row Source row.
     * @param fieldName Field API name.
     * @param fieldMap Describe field map.
     */
    private static void setAchievementFieldFromRow(
        SObject target,
    Map<String, Object> row,
    String fieldName,
    Map<String, Schema.SObjectField> fieldMap
    ) {
        if (target == null || row == null) {return;}
        if (!row.containsKey(fieldName) || row.get(fieldName) == null) {return;}
        if (!fieldMap.containsKey(fieldName)) {return;}
        Schema.DescribeFieldResult d = fieldMap.get(fieldName).getDescribe();
        if (!d.isCreateable()) {return;}
        try {
            Object val = ImportUtils.convertValue(row.get(fieldName), d);
            target.put(fieldName, val);
        } catch (Exception e) {
            KenAuditLogHelper.auditLogRecord(
                'Course Import',
            'Class:CourseImportBatch'
                )
                .setErrorMessage('CourseImportBatch.setAchievementFieldFromRow conversion failed for field ' + fieldName + ': ' + e.getMessage())
                .setStackTrace(e.getStackTraceString())
                .create();
        }
    }
    
    /**
     * @description Sets one createable LearningOutcomeItem field from row data.
     * @param target Target LearningOutcomeItem record.
     * @param row Source row.
     * @param fieldName Field API name.
     * @param fieldMap Describe field map.
     */
    private static void setOutcomeFieldFromRow(
        SObject target,
    Map<String, Object> row,
    String fieldName,
    Map<String, Schema.SObjectField> fieldMap
    ) {
        if (target == null || row == null) {return;}
        if (!row.containsKey(fieldName) || row.get(fieldName) == null) {return;}
        if (!fieldMap.containsKey(fieldName)) {return;}
        Schema.DescribeFieldResult d = fieldMap.get(fieldName).getDescribe();
        if (!d.isCreateable()) {return;}
        try {
            Object val = ImportUtils.convertValue(row.get(fieldName), d);
            target.put(fieldName, val);
        } catch (Exception e) {
            KenAuditLogHelper.auditLogRecord(
                'Course Import',
            'Class:CourseImportBatch'
                )
                .setErrorMessage('CourseImportBatch.setOutcomeFieldFromRow conversion failed for field ' + fieldName + ': ' + e.getMessage())
                .setStackTrace(e.getStackTraceString())
                .create();
        }
    }
    
    /**
     * @description Reads and trims a string value from the row map.
     * @param row Source row.
     * @param fieldName Field API name.
     * @return Trimmed string value or null.
     */
    private static String getRowString(Map<String, Object> row, String fieldName) {
        if (row == null || String.isBlank(fieldName)) {return null;}
        if (!row.containsKey(fieldName) || row.get(fieldName) == null) {return null;}
        return String.valueOf(row.get(fieldName)).trim();
    }
    
    /**
     * @description Adds existing LearningCourse lookup value to map when key is present and non-blank.
     * @param existingCourseByNumber Map keyed by course number.
     * @param existingCourse Existing LearningCourse record from query.
     * @param courseNumberField Field API name used as key.
     */
    private static void addExistingCourseByNumber(
        Map<String, Id> existingCourseByNumber,
    SObject existingCourse,
    String courseNumberField
    ) {
        if (existingCourseByNumber == null || existingCourse == null || String.isBlank(courseNumberField)) {return;}
        Object courseNumberRaw = existingCourse.get(courseNumberField);
        if (courseNumberRaw == null) {return;}
        String courseNumber = String.valueOf(courseNumberRaw).trim();
        if (String.isBlank(courseNumber)) {return;}
        existingCourseByNumber.put(courseNumber, (Id) existingCourse.get('Id'));
    }
    
    /**
     * @description Returns learning id for a given row index when available.
     * @param learningIdByRow Learning id list aligned to source rows.
     * @param rowIndex Source row index.
     * @return Learning id or null when unavailable.
     */
    private static Id getLearningIdByIndex(List<Id> learningIdByRow, Integer rowIndex) {
        if (learningIdByRow == null || rowIndex == null || rowIndex < 0 || rowIndex >= learningIdByRow.size()) {
            return null;
        }
        return learningIdByRow[rowIndex];
    }
    
    /**
     * @description Adds learning id to delete set when value is present.
     * @param learningIdsToDelete Delete set.
     * @param learningId Learning id candidate.
     */
    private static void markLearningForDelete(Set<Id> learningIdsToDelete, Id learningId) {
        if (learningIdsToDelete == null || learningId == null) {return;}
        learningIdsToDelete.add(learningId);
    }
    
    /**
     * @description Sets record id on an audit creator when job id is provided.
     * @param creator Audit log creator.
     * @param jobId Async job id.
     */
    private static void setAuditRecordIdIfPresent(KenAuditLogHelper.KenAuditLogCreator creator, Id jobId) {
        if (creator == null || jobId == null) {return;}
        creator.setRecordId(String.valueOf(jobId));
    }
    
}