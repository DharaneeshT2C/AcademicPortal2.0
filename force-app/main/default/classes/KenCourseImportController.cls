/**
 * ************************************************************************************************
 * @className  CourseImportController
 *
 * @description
 *  Controller for Course import orchestration from LWC.
 *
 *  Responsibilities:
 *  - Start the Course import batch job
 *  - Read audit-log errors produced by the batch job
 *  - Persist controller-level exceptions to Audit_Log__c
 *
 * @author      Sureka A R K
 * @createdOn   Feb 03, 2026
 *
 * @history
 * ------------------------------------------------------------------------------------------------
 * Version   Date           Author          Description
 * 1.0       Feb 03, 2026   Sureka A R K    Added docs, constants, and audit logging
 * ************************************************************************************************
 */
public with sharing class KenCourseImportController {
    @TestVisible
    private static Boolean forceStartCourseImportBatchException = false;
    
    @TestVisible
    private static Boolean forceGetCourseImportResultException = false;
    
    public class CourseImportResult {
        @AuraEnabled public List<String> errors;
        @AuraEnabled public Integer insertedCount;
        @AuraEnabled public Integer updatedCount;
        
        public CourseImportResult() {
            this.errors = new List<String>();
            this.insertedCount = 0;
            this.updatedCount = 0;
        }
    }
    
    /**
     * @description Starts the Course import batch with the provided payload and context ids.
     * @param jsonRows JSON rows payload from UI.
     * @param providerId Provider Account Id for Learning records.
     * @param instituteId Institute Account Id used by downstream achievement creation.
     * @return AsyncApexJob Id for the started batch.
     */
    @AuraEnabled
    public static Id startCourseImportBatch(String jsonRows, Id providerId, Id instituteId) {
        try {
            throwIfStartBatchExceptionForced();
            return Database.executeBatch(
                new KenCourseImportBatch(jsonRows, providerId, instituteId),
            200
                );
        } catch (Exception e) {
            KenAuditLogHelper.auditLogRecord(
                'Course Import',
            'Class:CourseImportController'
                )
                .setErrorMessage('CourseImportController.startCourseImportBatch failed: ' + e.getMessage())
                .setStackTrace(e.getStackTraceString())
                .create();
            throw e;
        }
    }
    /**
     * @description Returns audit-log error text entries for a batch job id.
     * @param jobId AsyncApexJob Id returned from batch start.
     * @return List of error/stack trace strings to show in UI.
     */
    @AuraEnabled
    public static List<String> getCourseImportErrors(Id jobId) {
        return getCourseImportResult(jobId).errors;
    }
    
    @AuraEnabled
    public static CourseImportResult getCourseImportResult(Id jobId) {
        CourseImportResult result = new CourseImportResult();
        if (jobId == null) {return result;}
        if (!canReadCourseImportAuditLogs()) {return result;}
        try {
            throwIfGetCourseImportResultExceptionForced();
            List<Audit_Log__c> logs = [
                SELECT Error_Message__c, Stack_Trace__c
                FROM Audit_Log__c
                WHERE RecordId__c = :String.valueOf(jobId)
                AND Process__c = 'Course Import'
                
                ORDER BY CreatedDate DESC
                LIMIT 5000
            ];
            if (logs.isEmpty()) {
                logs = [
                    SELECT Error_Message__c, Stack_Trace__c
                    FROM Audit_Log__c
                    WHERE RecordId__c = :String.valueOf(jobId)
                    
                    ORDER BY CreatedDate DESC
                    LIMIT 5000
                ];
            }
            for (Audit_Log__c log : logs) {
                String msg = log.Error_Message__c;
                if (String.isBlank(msg)) {msg = log.Stack_Trace__c;}
                if (String.isBlank(msg)) {continue;}
                if (isSummaryMessage(msg)) {
                    applySummary(result, msg);
                } else if (!isCompletionMessage(msg)) {
                    result.errors.add(msg);
                }
            }
        } catch (Exception e) {
            KenAuditLogHelper.auditLogRecord(
                'Course Import',
            'Class:CourseImportController'
                )
                .setErrorMessage('CourseImportController.getCourseImportResult failed: ' + e.getMessage())
                .setStackTrace(e.getStackTraceString())
                .setRecordId(String.valueOf(jobId))
                .create();
            result.errors.add('Error fetching audit logs: ' + e.getMessage());
        }
        return result;
    }
    
    @TestVisible
    private static void throwIfStartBatchExceptionForced() {
        if (Test.isRunningTest() && forceStartCourseImportBatchException) {
            throw new AuraHandledException('Forced start batch exception');
        }
    }
    
    @TestVisible
    private static void throwIfGetCourseImportResultExceptionForced() {
        if (Test.isRunningTest() && forceGetCourseImportResultException) {
            throw new AuraHandledException('Forced get result exception');
        }
    }
    
    @AuraEnabled
    public static List<String> getCourseImportErrorsLegacy(Id jobId) {
        List<String> out = new List<String>();
        out.addAll(getCourseImportResult(jobId).errors);
        return out;
    }
    
    @TestVisible
    private static Boolean isCompletionMessage(String message) {
        if (String.isBlank(message)) {return false;}
        String normalized = message.trim().toLowerCase();
        return normalized.startsWith('course import batch completed');
    }
    
    @TestVisible
    private static Boolean isSummaryMessage(String message) {
        if (String.isBlank(message)) {return false;}
        return message.trim().toLowerCase().startsWith('course import summary:');
    }
    
    @TestVisible
    private static void applySummary(CourseImportResult result, String message) {
        if (result == null || String.isBlank(message)) {return;}
        String normalized = message.trim().toLowerCase();
        List<String> parts = normalized.replace('course import summary:', '').split(';');
        for (String part : parts) {
            if (String.isBlank(part) || !part.contains('=')) {continue;}
            List<String> keyValue = part.split('=');
            if (keyValue.size() != 2) {continue;}
            String key = keyValue[0] != null ? keyValue[0].trim() : '';
            String valueText = keyValue[1] != null ? keyValue[1].trim() : '';
            Integer value;
            try {
                value = Integer.valueOf(valueText);
            } catch (Exception e) {
                continue;
            }
            if (key == 'inserted') {
                result.insertedCount = value;
            } else if (key == 'updated') {
                result.updatedCount = value;
            }
        }
    }
    
    /**
     * @description Validates object and field read access required to query course import audit logs.
     * @return true when object and required fields are readable for the running user.
     */
    @TestVisible
    private static Boolean canReadCourseImportAuditLogs() {
        if (!Schema.SObjectType.Audit_Log__c.isAccessible()) {return false;}
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Audit_Log__c.fields.getMap();
        return fields.containsKey('Error_Message__c') && fields.get('Error_Message__c').getDescribe().isAccessible() &&
            fields.containsKey('Stack_Trace__c') && fields.get('Stack_Trace__c').getDescribe().isAccessible() &&
            fields.containsKey('RecordId__c') && fields.get('RecordId__c').getDescribe().isAccessible() &&
            fields.containsKey('Process__c') && fields.get('Process__c').getDescribe().isAccessible();
    }
}