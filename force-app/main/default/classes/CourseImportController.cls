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
public with sharing class CourseImportController {
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
            return Database.executeBatch(
                new CourseImportBatch(jsonRows, providerId, instituteId),
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
        List<String> out = new List<String>();
        if (jobId == null) {return out;}
        if (!canReadCourseImportAuditLogs()) {return out;}
        try {
            List<Audit_Log__c> logs = [
                SELECT Error_Message__c, Stack_Trace__c
                FROM Audit_Log__c
                WHERE RecordId__c = :String.valueOf(jobId)
                AND Process__c = 'Course Import'
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 5000
            ];
            if (logs.isEmpty()) {
                logs = [
                    SELECT Error_Message__c, Stack_Trace__c
                    FROM Audit_Log__c
                    WHERE RecordId__c = :String.valueOf(jobId)
                    WITH USER_MODE
                    ORDER BY CreatedDate DESC
                    LIMIT 5000
                ];
            }
            for (Audit_Log__c log : logs) {
                String msg = log.Error_Message__c;
                if (String.isBlank(msg)) {msg = log.Stack_Trace__c;}
                if (!String.isBlank(msg)) {out.add(msg);}
            }
        } catch (Exception e) {
            KenAuditLogHelper.auditLogRecord(
                'Course Import',
            'Class:CourseImportController'
                )
                .setErrorMessage('CourseImportController.getCourseImportErrors failed: ' + e.getMessage())
                .setStackTrace(e.getStackTraceString())
                .setRecordId(String.valueOf(jobId))
                .create();
            out.add('Error fetching audit logs: ' + e.getMessage());
        }
        return out;
    }
    /**
     * @description Validates object and field read access required to query course import audit logs.
     * @return true when object and required fields are readable for the running user.
     */
    private static Boolean canReadCourseImportAuditLogs() {
        if (!Schema.SObjectType.Audit_Log__c.isAccessible()) {return false;}
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Audit_Log__c.fields.getMap();
        return fields.containsKey('Error_Message__c') && fields.get('Error_Message__c').getDescribe().isAccessible() &&
            fields.containsKey('Stack_Trace__c') && fields.get('Stack_Trace__c').getDescribe().isAccessible() &&
            fields.containsKey('RecordId__c') && fields.get('RecordId__c').getDescribe().isAccessible() &&
            fields.containsKey('Process__c') && fields.get('Process__c').getDescribe().isAccessible();
    }
}