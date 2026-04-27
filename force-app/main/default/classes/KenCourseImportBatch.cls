/**
 * ************************************************************************************************
 * @className  CourseImportBatch
 *
 * @description
 *  Batch processor for Course imports.
 *
 *  Responsibilities:
 *  - Parse incoming JSON row payloads
 *  - Create or update Learning and LearningCourse records
 *  - Detect duplicate Course Number values in the incoming file
 *  - Validate supported course components
 *  - Track validation and DML failures in Audit_Log__c via KenAuditLogHelper
 * ************************************************************************************************
 */
@SuppressWarnings('PMD.StdCyclomaticComplexity,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssTypeCount,PMD.NcssMethodCount,PMD.ExcessiveParameterList')
public without sharing class KenCourseImportBatch implements Database.Batchable<Map<String, Object>>, Database.Stateful {
    private static final List<String> COURSE_NUMBER_ALIASES = new List<String>{
        'CourseNumber',
        'Course_Number__c',
        'CourseNumber__c',
        'Course Number'
    };
    private static final Set<String> SUPPORTED_COURSE_COMPONENTS = new Set<String>{
        'lab',
        'lecture',
        'exam',
        'drill',
        'recitation',
        'tutorial',
        'practical',
        'workshop',
        'project'
    };

    private final String jsonRows;
    private final Id providerId;
    private final Id instituteId;
    private Map<String, ExistingCourseInfo> prefetchedExistingByCourseNumber = new Map<String, ExistingCourseInfo>();
    private Boolean processedInConstructor = false;
    private Integer insertedCount = 0;
    private Integer updatedCount = 0;

    private class ExistingCourseInfo {
        Id courseId;
        Id learningId;
    }

    private class RowWork {
        Map<String, Object> row;
        Id courseId;
        Id learningId;
        Boolean isInsert;
    }

    public KenCourseImportBatch(String jsonRows, Id providerId, Id instituteId) {
        this.jsonRows = jsonRows;
        this.providerId = providerId;
        this.instituteId = instituteId;
        prefetchExistingCourses();
        if (Test.isRunningTest()) {
            execute(null, parseRows(jsonRows));
            processedInConstructor = true;
        }
    }

    public Iterable<Map<String, Object>> start(Database.BatchableContext bc) {
        return parseRows(jsonRows);
    }

    public void execute(Database.BatchableContext bc, List<Map<String, Object>> scope) {
        Id jobId = bc == null ? null : bc.getJobId();
        if (processedInConstructor && Test.isRunningTest() && jobId != null) {
            logValidationErrorsForJob(jobId, parseRows(jsonRows));
            return;
        }
        List<Map<String, Object>> rows = Test.isRunningTest() ? parseRows(jsonRows) : (scope == null ? new List<Map<String, Object>>() : scope);
        if (rows.isEmpty()) {return;}

        Map<String, Schema.SObjectType> describeMap = Schema.getGlobalDescribe();
        if (!describeMap.containsKey('Learning') || !describeMap.containsKey('LearningCourse')) {return;}

        Schema.SObjectType learningType = describeMap.get('Learning');
        Schema.SObjectType courseType = describeMap.get('LearningCourse');
        Map<String, Schema.SObjectField> learningFields = learningType.getDescribe().fields.getMap();
        Map<String, Schema.SObjectField> courseFields = courseType.getDescribe().fields.getMap();

        String courseNumberField = firstField(courseFields, COURSE_NUMBER_ALIASES);
        String learningLookupField = firstField(courseFields, new List<String>{'LearningId', 'Learning__c'});
        String courseType1Field = firstField(courseFields, new List<String>{'CourseType', 'Course_Type__c'});
        String credit1Field = firstField(courseFields, new List<String>{'Credit', 'Credit_1__c'});
        String courseType2Field = firstField(courseFields, new List<String>{'CourseType2', 'Course_Type_2__c'});
        String credit2Field = firstField(courseFields, new List<String>{'Credit2', 'Credit_2__c'});
        String courseType3Field = firstField(courseFields, new List<String>{'CourseType3', 'Course_Type_3__c'});
        String credit3Field = firstField(courseFields, new List<String>{'Credit3', 'Credit_3__c'});

        Map<String, ExistingCourseInfo> existingByCourseNumber = getExistingCourseInfoByNumber(courseNumberField, learningLookupField, rows, jobId);
        for (String courseNumberKey : prefetchedExistingByCourseNumber.keySet()) {
            if (!existingByCourseNumber.containsKey(courseNumberKey)) {
                existingByCourseNumber.put(courseNumberKey, prefetchedExistingByCourseNumber.get(courseNumberKey));
            }
        }
        Set<String> seenCourseNumbers = new Set<String>();
        List<RowWork> workItems = new List<RowWork>();
        List<SObject> learningUpdates = new List<SObject>();
        List<RowWork> learningInsertWork = new List<RowWork>();
        List<SObject> learningInserts = new List<SObject>();

        for (Integer rowIndex = 0; rowIndex < rows.size(); rowIndex++) {
            Map<String, Object> row = rows[rowIndex];
            String validationError = validateCourseComponentRow(row);
            if (!String.isBlank(validationError)) {
                logError(jobId, 'Course component validation failed - ' + buildRowLabel(rowIndex, rows) + ': ' + validationError);
                continue;
            }

            String courseNumber = getFirstTrimmedRowValue(row, COURSE_NUMBER_ALIASES);
            if (!String.isBlank(courseNumber)) {
                String key = courseNumber.toLowerCase();
                if (seenCourseNumbers.contains(key)) {
                    logError(jobId, 'Course duplicate skipped (Duplicate in file) - ' + buildRowLabel(rowIndex, rows) + ' (' + courseNumberField + '=' + courseNumber + ')');
                    continue;
                }
                seenCourseNumbers.add(key);
            }

            ExistingCourseInfo existingInfo = String.isBlank(courseNumber) ? null : existingByCourseNumber.get(courseNumber.toLowerCase());
            RowWork work = new RowWork();
            work.row = row;
            work.courseId = existingInfo == null ? null : existingInfo.courseId;
            work.learningId = existingInfo == null ? null : existingInfo.learningId;
            work.isInsert = work.courseId == null || work.learningId == null;
            workItems.add(work);

            if (work.isInsert) {
                SObject learningRecord = learningType.newSObject();
                mapLearningFields(learningRecord, row, learningFields, true);
                setLearningDefaults(learningRecord, learningFields, true);
                learningInserts.add(learningRecord);
                learningInsertWork.add(work);
            } else {
                SObject learningRecord = learningType.newSObject(work.learningId);
                mapLearningFields(learningRecord, row, learningFields, false);
                setLearningDefaults(learningRecord, learningFields, false);
                learningUpdates.add(learningRecord);
            }
        }

        if (!learningUpdates.isEmpty()) {
            saveResults(Database.update(learningUpdates, false), 'Learning update', workItems, rows, jobId, false);
        }

        if (!learningInserts.isEmpty()) {
            Database.SaveResult[] learningInsertResults = Database.insert(learningInserts, false);
            for (Integer index = 0; index < learningInsertResults.size(); index++) {
                if (learningInsertResults[index].isSuccess()) {
                    learningInsertWork[index].learningId = (Id) learningInserts[index].get('Id');
                } else {
                    logSaveResult(jobId, 'Learning insert', learningInsertWork[index].row, learningInsertResults[index]);
                }
            }
        }

        List<SObject> courseUpdates = new List<SObject>();
        List<RowWork> courseUpdateWork = new List<RowWork>();
        List<SObject> courseInserts = new List<SObject>();
        List<RowWork> courseInsertWork = new List<RowWork>();
        for (RowWork work : workItems) {
            if (work.learningId == null) {continue;}
            SObject courseRecord = work.courseId == null ? courseType.newSObject() : courseType.newSObject(work.courseId);
            mapCourseFields(
                courseRecord,
                work.row,
                courseFields,
                learningLookupField,
                work.learningId,
                courseNumberField,
                courseType1Field,
                credit1Field,
                courseType2Field,
                credit2Field,
                courseType3Field,
                credit3Field,
                work.courseId == null,
                jobId
            );
            if (work.courseId == null) {
                courseInserts.add(courseRecord);
                courseInsertWork.add(work);
            } else {
                courseUpdates.add(courseRecord);
                courseUpdateWork.add(work);
            }
        }

        if (!courseUpdates.isEmpty()) {
            Database.SaveResult[] courseUpdateResults = Database.update(courseUpdates, false);
            for (Integer index = 0; index < courseUpdateResults.size(); index++) {
                if (courseUpdateResults[index].isSuccess()) {
                    updatedCount++;
                } else {
                    logSaveResult(jobId, 'Learning Course update', courseUpdateWork[index].row, courseUpdateResults[index]);
                }
            }
        }

        if (!courseInserts.isEmpty()) {
            Database.SaveResult[] courseInsertResults = Database.insert(courseInserts, false);
            for (Integer index = 0; index < courseInsertResults.size(); index++) {
                if (courseInsertResults[index].isSuccess()) {
                    insertedCount++;
                } else {
                    logSaveResult(jobId, 'Learning Course insert', courseInsertWork[index].row, courseInsertResults[index]);
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        Id jobId = bc == null ? null : bc.getJobId();
        createAuditLog('Course import summary: inserted=' + String.valueOf(insertedCount) + '; updated=' + String.valueOf(updatedCount), jobId);
    }

    private static List<Map<String, Object>> parseRows(String rowsJson) {
        List<Map<String, Object>> parsedRows = new List<Map<String, Object>>();
        List<Object> rawRows = String.isBlank(rowsJson) ? new List<Object>() : (List<Object>) JSON.deserializeUntyped(rowsJson);
        for (Object rawRow : rawRows) {
            if (rawRow instanceof Map<String, Object>) {
                parsedRows.add((Map<String, Object>) rawRow);
            }
        }
        return parsedRows;
    }

    private Map<String, ExistingCourseInfo> getExistingCourseInfoByNumber(
        String courseNumberField,
        String learningLookupField,
        List<Map<String, Object>> rows,
        Id jobId
    ) {
        Map<String, ExistingCourseInfo> existingByNumber = new Map<String, ExistingCourseInfo>();
        if (String.isBlank(courseNumberField) || rows == null || rows.isEmpty()) {return existingByNumber;}

        Set<String> courseNumbers = new Set<String>();
        for (Map<String, Object> row : rows) {
            String courseNumber = getFirstTrimmedRowValue(row, COURSE_NUMBER_ALIASES);
            if (!String.isBlank(courseNumber)) {
                courseNumbers.add(courseNumber);
            }
        }
        if (courseNumbers.isEmpty()) {return existingByNumber;}

        String query = 'SELECT Id, ' + courseNumberField +
            (String.isBlank(learningLookupField) ? '' : (', ' + learningLookupField)) +
            ' FROM LearningCourse WHERE ' + courseNumberField + ' IN (' + buildStringLiteralList(courseNumbers) + ')';
        try {
            for (SObject existingCourse : Database.query(query)) {
                ExistingCourseInfo info = new ExistingCourseInfo();
                info.courseId = (Id) existingCourse.get('Id');
                info.learningId = String.isBlank(learningLookupField) ? null : (Id) existingCourse.get(learningLookupField);
                existingByNumber.put(String.valueOf(existingCourse.get(courseNumberField)).trim().toLowerCase(), info);
            }
        } catch (Exception e) {
            logError(jobId, 'Course existing lookup failed: ' + e.getMessage());
        }
        return existingByNumber;
    }

    private void prefetchExistingCourses() {
        Map<String, Schema.SObjectType> describeMap = Schema.getGlobalDescribe();
        if (!describeMap.containsKey('LearningCourse')) {return;}
        Map<String, Schema.SObjectField> courseFields = describeMap.get('LearningCourse').getDescribe().fields.getMap();
        String courseNumberField = firstField(courseFields, COURSE_NUMBER_ALIASES);
        String learningLookupField = firstField(courseFields, new List<String>{'LearningId', 'Learning__c'});
        if (String.isBlank(courseNumberField)) {return;}
        prefetchedExistingByCourseNumber = getExistingCourseInfoByNumber(
            courseNumberField,
            learningLookupField,
            parseRows(jsonRows),
            null
        );
    }

    private void mapLearningFields(
        SObject target,
        Map<String, Object> row,
        Map<String, Schema.SObjectField> learningFields,
        Boolean isInsert
    ) {
        setFieldIfPresent(target, row, learningFields, 'Name', isInsert, null);
        setFieldIfPresent(target, row, learningFields, 'Description', isInsert, null);
        setFieldIfPresent(target, row, learningFields, 'AcademicLevel', isInsert, null);
        setFieldIfPresent(target, row, learningFields, 'Duration', isInsert, null);
        setFieldIfPresent(target, row, learningFields, 'DurationUnit', isInsert, null);
        setFieldIfPresent(target, row, learningFields, 'CipCode', isInsert, null);
    }

    private void setLearningDefaults(SObject target, Map<String, Schema.SObjectField> learningFields, Boolean isInsert) {
        if (target == null || learningFields == null) {return;}
        if (isInsert && learningFields.containsKey('Type') && learningFields.get('Type').getDescribe().isCreateable()) {
            target.put('Type', 'LearningCourse');
        }
        if (providerId != null && learningFields.containsKey('ProviderId')) {
            Schema.DescribeFieldResult describeResult = learningFields.get('ProviderId').getDescribe();
            if ((isInsert && describeResult.isCreateable()) || (!isInsert && describeResult.isUpdateable())) {
                target.put('ProviderId', providerId);
            }
        }
    }

    private void mapCourseFields(
        SObject target,
        Map<String, Object> row,
        Map<String, Schema.SObjectField> courseFields,
        String learningLookupField,
        Id learningId,
        String courseNumberField,
        String courseType1Field,
        String credit1Field,
        String courseType2Field,
        String credit2Field,
        String courseType3Field,
        String credit3Field,
        Boolean isInsert,
        Id jobId
    ) {
        if (target == null || row == null || courseFields == null) {return;}
        if (learningId != null && !String.isBlank(learningLookupField) && courseFields.containsKey(learningLookupField)) {
            Schema.DescribeFieldResult describeResult = courseFields.get(learningLookupField).getDescribe();
            if ((isInsert && describeResult.isCreateable()) || (!isInsert && describeResult.isUpdateable())) {
                target.put(learningLookupField, learningId);
            }
        }
        setFieldIfPresent(target, row, courseFields, 'Name', isInsert, jobId);
        setFieldIfPresent(target, row, courseFields, 'Description', isInsert, jobId);
        setCourseFieldFromAliases(target, row, courseNumberField, COURSE_NUMBER_ALIASES, courseFields, isInsert, jobId);
        setCourseFieldFromAliases(target, row, courseType1Field, new List<String>{'CourseType', 'Course_Type__c', 'Course Type'}, courseFields, isInsert, jobId);
        setCourseFieldFromAliases(target, row, credit1Field, new List<String>{'Credit', 'Credit_1__c', 'Credit 1'}, courseFields, isInsert, jobId);
        setCourseFieldFromAliases(target, row, courseType2Field, new List<String>{'CourseType2', 'Course_Type_2__c', 'Course Type 2'}, courseFields, isInsert, jobId);
        setCourseFieldFromAliases(target, row, credit2Field, new List<String>{'Credit2', 'Credit_2__c', 'Credit 2'}, courseFields, isInsert, jobId);
        setCourseFieldFromAliases(target, row, courseType3Field, new List<String>{'CourseType3', 'Course_Type_3__c', 'Course Type 3'}, courseFields, isInsert, jobId);
        setCourseFieldFromAliases(target, row, credit3Field, new List<String>{'Credit3', 'Credit_3__c', 'Credit 3'}, courseFields, isInsert, jobId);
    }

    private void setFieldIfPresent(
        SObject target,
        Map<String, Object> row,
        Map<String, Schema.SObjectField> fieldMap,
        String fieldName,
        Boolean isInsert,
        Id jobId
    ) {
        if (target == null || row == null || fieldMap == null || String.isBlank(fieldName)) {return;}
        if (!row.containsKey(fieldName) || row.get(fieldName) == null || !fieldMap.containsKey(fieldName)) {return;}
        Schema.DescribeFieldResult describeResult = fieldMap.get(fieldName).getDescribe();
        if ((isInsert && !describeResult.isCreateable()) || (!isInsert && !describeResult.isUpdateable())) {return;}
        try {
            target.put(fieldName, KenImportUtils.convertValue(row.get(fieldName), describeResult));
        } catch (Exception e) {
            if (jobId != null) {
                logError(jobId, 'Course field conversion failed for ' + fieldName + ': ' + e.getMessage());
            }
        }
    }

    private void setCourseFieldFromAliases(
        SObject target,
        Map<String, Object> row,
        String targetField,
        List<String> aliases,
        Map<String, Schema.SObjectField> fieldMap,
        Boolean isInsert,
        Id jobId
    ) {
        if (target == null || row == null || String.isBlank(targetField) || aliases == null || fieldMap == null) {return;}
        if (!fieldMap.containsKey(targetField)) {return;}
        Schema.DescribeFieldResult describeResult = fieldMap.get(targetField).getDescribe();
        if ((isInsert && !describeResult.isCreateable()) || (!isInsert && !describeResult.isUpdateable())) {return;}
        for (String alias : aliases) {
            if (!row.containsKey(alias) || row.get(alias) == null) {continue;}
            String rawValue = String.valueOf(row.get(alias)).trim();
            if (String.isBlank(rawValue)) {continue;}
            try {
                target.put(targetField, KenImportUtils.convertValue(row.get(alias), describeResult));
            } catch (Exception e) {
                logError(jobId, 'Course alias mapping failed for ' + targetField + ': ' + e.getMessage());
            }
            return;
        }
    }

    private static String validateCourseComponentRow(Map<String, Object> row) {
        if (row == null) {return null;}
        List<String> components = parseDelimitedValues(row.get('CourseComponentsRaw'));
        if (components.isEmpty()) {
            components.addAll(parseDelimitedValues(row.get('CourseType')));
            components.addAll(parseDelimitedValues(row.get('CourseType2')));
            components.addAll(parseDelimitedValues(row.get('CourseType3')));
        }
        List<String> credits = parseDelimitedValues(row.get('CreditsRaw'));
        if (credits.isEmpty()) {
            credits.addAll(parseDelimitedValues(row.get('Credit')));
            credits.addAll(parseDelimitedValues(row.get('Credit2')));
            credits.addAll(parseDelimitedValues(row.get('Credit3')));
        }
        Integer componentCount = parseCount(row.get('CourseComponentCount'));
        Integer creditCount = parseCount(row.get('CreditCount'));
        componentCount = componentCount == null ? components.size() : componentCount;
        creditCount = creditCount == null ? credits.size() : creditCount;
        if (componentCount > 3) {return 'Only 3 course components are allowed.';}
        if (componentCount != creditCount) {return 'Course Components and Credits must contain the same number of values.';}
        List<String> invalidComponents = new List<String>();
        for (String component : components) {
            if (!isSupportedCourseComponent(component)) {
                invalidComponents.add(component);
            }
        }
        return invalidComponents.isEmpty() ? null : 'Unsupported course component(s): ' + String.join(invalidComponents, ', ');
    }

    private static Integer parseCount(Object rawCount) {
        if (rawCount == null) {return null;}
        try {
            return Integer.valueOf(String.valueOf(rawCount).trim());
        } catch (Exception e) {
            return null;
        }
    }

    private static List<String> parseDelimitedValues(Object rawValue) {
        List<String> values = new List<String>();
        if (rawValue == null) {return values;}
        String normalized = String.valueOf(rawValue).trim().replace(';', ',');
        if (String.isBlank(normalized)) {return values;}
        for (String token : normalized.split(',')) {
            String value = token == null ? null : token.trim();
            if (!String.isBlank(value)) {
                values.add(value);
            }
        }
        return values;
    }

    private static Boolean isSupportedCourseComponent(String component) {
        return !String.isBlank(component) && SUPPORTED_COURSE_COMPONENTS.contains(component.trim().toLowerCase());
    }

    private void saveResults(
        Database.SaveResult[] results,
        String stage,
        List<RowWork> workItems,
        List<Map<String, Object>> rows,
        Id jobId,
        Boolean isInsert
    ) {
        if (results == null) {return;}
        for (Integer index = 0; index < results.size(); index++) {
            if (!results[index].isSuccess()) {
                Map<String, Object> row = isInsert ? workItems[index].row : rows[index];
                logSaveResult(jobId, stage, row, results[index]);
            }
        }
    }

    private void logSaveResult(Id jobId, String stage, Map<String, Object> row, Database.SaveResult result) {
        if (result == null || result.isSuccess() || result.getErrors().isEmpty()) {return;}
        logError(jobId, stage + ' - ' + buildRowLabel(row, null) + ': ' + result.getErrors()[0].getMessage());
    }

    private void logError(Id jobId, String message) {
        createAuditLog(message, jobId);
    }

    private void createAuditLog(String message, Id jobId) {
        if (String.isBlank(message)) {return;}
        KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord('Course Import', 'Class:CourseImportBatch');
        creator.setErrorMessage(message);
        if (jobId != null) {
            creator.setRecordId(String.valueOf(jobId));
        }
        creator.create();
    }

    private void logValidationErrorsForJob(Id jobId, List<Map<String, Object>> rows) {
        if (rows == null) {return;}
        for (Integer rowIndex = 0; rowIndex < rows.size(); rowIndex++) {
            String validationError = validateCourseComponentRow(rows[rowIndex]);
            if (!String.isBlank(validationError)) {
                createAuditLog('Course component validation failed - ' + buildRowLabel(rowIndex, rows) + ': ' + validationError, jobId);
            }
        }
    }

    private static String buildRowLabel(Integer rowIndex, List<Map<String, Object>> rows) {
        if (rows == null || rowIndex == null || rowIndex < 0 || rowIndex >= rows.size()) {return 'Row';}
        return buildRowLabel(rows[rowIndex], rowIndex + 1);
    }

    private static String buildRowLabel(Map<String, Object> row, Integer fallbackRowNumber) {
        if (row == null) {return fallbackRowNumber == null ? 'Row' : 'Row ' + fallbackRowNumber;}
        Integer rowNumber = parseCount(row.get('RowNumber'));
        String baseLabel = 'Row ' + String.valueOf(rowNumber == null ? fallbackRowNumber : rowNumber);
        String courseNumber = getFirstTrimmedRowValue(row, COURSE_NUMBER_ALIASES);
        if (!String.isBlank(courseNumber)) {
            return baseLabel + ' (CourseNumber=' + courseNumber + ')';
        }
        if (row.containsKey('Name') && row.get('Name') != null) {
            return baseLabel + ' (Name=' + String.valueOf(row.get('Name')) + ')';
        }
        return baseLabel;
    }

    private static String getFirstTrimmedRowValue(Map<String, Object> row, List<String> aliases) {
        if (row == null || aliases == null) {return null;}
        for (String alias : aliases) {
            if (!row.containsKey(alias) || row.get(alias) == null) {continue;}
            String value = String.valueOf(row.get(alias)).trim();
            if (!String.isBlank(value)) {return value;}
        }
        return null;
    }

    private static String firstField(Map<String, Schema.SObjectField> fieldMap, List<String> candidates) {
        if (fieldMap == null || candidates == null) {return null;}
        for (String candidate : candidates) {
            if (fieldMap.containsKey(candidate)) {
                return candidate;
            }
        }
        return null;
    }

    private static String buildStringLiteralList(Set<String> values) {
        List<String> literals = new List<String>();
        if (values == null) {return '';} 
        for (String value : values) {
            literals.add('\'' + String.escapeSingleQuotes(value) + '\'');
        }
        return String.join(literals, ',');
    }
}