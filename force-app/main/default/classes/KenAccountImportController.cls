/**
 * ************************************************************************************************
 * @className  AccountImportController
 *
 * @description
 *  Aura-enabled controller for Account import orchestration and error retrieval.
 *
 *  Responsibilities:
 *  - Start University/Institute/Department/Generic Account import batch jobs
 *  - Resolve Account RecordType Id by name
 *  - Fetch import-related errors from Audit_Log__c for UI display
 *
 * @author      Sureka A R K
 * @createdOn   Feb 03, 2026
 *
 * @history
 * ------------------------------------------------------------------------------------------------
 * Version   Date           Author          Description
 * 1.0       Feb 03, 2026   Sureka A R K     Initial version
 * ************************************************************************************************
 */
@suppressWarnings('PMD.EagerlyLoadedDescribeSObjectResult')
public with sharing class KenAccountImportController {
    private static Boolean canRead(Schema.SObjectType sobjectType) {
        return sobjectType != null && sobjectType.getDescribe().isAccessible();
    }
    
    /**
     * @description
     *  Starts a generic Account import batch for the given record type.
     *
     * @param jsonRows JSON array payload of Account rows.
     * @param recordTypeName Target Account RecordType Name.
     * @param parentId Optional parent Account Id.
     * @return Id AsyncApexJob Id for the started batch.
     */
    @AuraEnabled
    public static Id startAccountImportBatch(String jsonRows, String recordTypeName, Id parentId) {
        return Database.executeBatch(new KenAccountImportBatch(jsonRows, recordTypeName, parentId), 200);
    }
    
    /**
     * @description
     *  Returns audit log messages for a given import batch job.
     *
     * @param jobId AsyncApexJob Id of the import batch.
     * @param processName Audit process name filter; defaults to `Account Import` when blank.
     * @return List<String> Error messages/stack traces in reverse chronological order.
     */
    @AuraEnabled
    public static List<String> getAccountImportErrors(Id jobId, String processName) {
        List<String> out = new List<String>();
        if (jobId == null) {return out;}
        if (!canRead(Audit_Log__c.SObjectType)) {return out;}
        if (String.isBlank(processName)) {processName = 'Account Import';}
        try {
            List<Audit_Log__c> logs = [
                SELECT Error_Message__c, Stack_Trace__c
                FROM Audit_Log__c
                WHERE RecordId__c = :String.valueOf(jobId)
                AND Process__c = :processName
                
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
                if (String.isBlank(msg)) {msg = log.Stack_Trace__c; }
                if (!String.isBlank(msg)) {out.add(msg); }
            }
        } catch (Exception e) {
            KenAuditLogHelper.auditLogRecord('Account Import', 'Class:AccountImportController')
                .setRecordId(String.valueOf(jobId))
                .setErrorMessage('Error fetching audit logs: ' + e.getMessage())
                .setStackTrace(e.getStackTraceString())
                .create();
            out.add('Error fetching audit logs: ' + e.getMessage());
        }
        return out;
    }
    
    /**
     * @description
     *  Returns the Account RecordType Id for the provided record type name.
     *
     * @param recordTypeName Account RecordType Name.
     * @return Id Matching RecordType Id, or null when not found/blank input.
     */
    public static Id getAccountRecordTypeId(String recordTypeName) {
        if (String.isBlank(recordTypeName)) {return null;}
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('RecordType') || !canRead(gd.get('RecordType'))) {return null;}
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = :KenConstantController.SOBJECT_ACCOUNT
            AND Name = :recordTypeName
            
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }
}