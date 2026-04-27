/**
 * ************************************************************************************************
 * @className  AuditLogHelper
 *
 * @description
 *  Utility/helper class to build and persist `Audit_Log__c` records.
 *
 *  Responsibilities:
 *  - Provide a fluent builder (`AuditLogCreator`) for audit log fields
 *  - Apply common defaults (process, source, timestamp, type, record type)
 *  - Resolve RecordType Ids with simple in-memory caching
 *  - Persist audit logs with CRUD checks and DML options
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
public with sharing class AuditLogHelper {
    
    private static Map<String, Id> recordTypeCache = new Map<String, Id>();
    
    private static Boolean canRead(Schema.SObjectType sobjectType) {
        return sobjectType != null && sobjectType.getDescribe().isAccessible();
    }
    
    /**
     * @description
     *  Fluent builder class for composing and creating `Audit_Log__c` records.
     */
    public class AuditLogCreator {
        Audit_Log__c auditLogRecord;
        /**
         * @description AuditLogCreator
         */
        public AuditLogCreator() {
            auditLogRecord = new Audit_Log__c();
        }
        /**
         * @description create
         * @return Audit_Log__c
         */
        public Audit_Log__c create() {
            return AuditLogHelper.createAuditLog(auditLogRecord);
        }
        /**
         * @description returnWithoutCreate
         * @return Audit_Log__c
         */
        public Audit_Log__c returnWithoutCreate() {
            return auditLogRecord;
        }
        /**
         * @description setProcess
         * @param processName
         * @return AuditLogCreator
         */
        public AuditLogCreator setProcess(String processName) {
            auditLogRecord.Process__c = processName;
            return this;
        }
        /**
         * @description setStackTrace
         * @param stackTrace
         * @return AuditLogCreator
         */
        public AuditLogCreator setStackTrace(String stackTrace) {
            auditLogRecord.Stack_Trace__c = stackTrace;
            return this;
        }
        /**
         * @description setSyncStatus
         * @param syncWithExternalLogger
         * @return AuditLogCreator
         */
        public AuditLogCreator setSyncStatus(Boolean syncWithExternalLogger) {
            auditLogRecord.Sync_with_External_Logger__c = syncWithExternalLogger;
            return this;
        }
        /**
         * @description setRecordTypeId
         * @param recordTypeId
         * @return AuditLogCreator
         */
        public AuditLogCreator setRecordType(Id recordTypeId) {
            auditLogRecord.RecordTypeId = recordTypeId;
            return this;
        }
        /**
         * @description setRecordTypeException
         * @return AuditLogCreator
         */
        public AuditLogCreator setRecordTypeException() {
            auditLogRecord.RecordTypeId = AuditLogHelper.getSObjectRecordTypeId(
                String.valueOf(Audit_Log__c.SObjectType),
            KenConstantController.RECORDTYPE_NAME_EXCEPTION
                );
            return this;
        }
        /**
         * @description setRecordTypeIntegration
         * @return AuditLogCreator
         */
        public AuditLogCreator setRecordTypeIntegration() {
            auditLogRecord.RecordTypeId = AuditLogHelper.getSObjectRecordTypeId(
                String.valueOf(Audit_Log__c.SObjectType),
            KenConstantController.RECORDTYPE_NAME_INTEGRATION
                );
            setSyncStatus(true);
            return this;
        }
        /**
         * @description setRecordId
         * @param recordId
         * @return AuditLogCreator
         */
        public AuditLogCreator setRecordId(String recordId) {
            auditLogRecord.RecordId__c = recordId;
            return this;
        }
        /**
         * @description setStatusCode
         * @param statusCode
         * @return AuditLogCreator
         */
        public AuditLogCreator setStatusCode(String statusCode) {
            auditLogRecord.Status_Code__c = statusCode;
            return this;
        }
        /**
         * @description setTimeStamp
         * @param timeStamp
         * @return AuditLogCreator
         */
        public AuditLogCreator setTimeStamp(Datetime timeStamp) {
            auditLogRecord.Time_Stamp__c = timeStamp;
            return this;
        }
        /**
         * @description setErrorMessage
         * @param errMessage
         * @return AuditLogCreator
         */
        public AuditLogCreator setErrorMessage(String errMessage) {
            auditLogRecord.Error_Message__c = errMessage;
            if (!String.isBlank(errMessage)) {
                String msg = errMessage;
                if (msg.length() > 80) {msg = msg.substring(0, 80);}
                auditLogRecord.Name =
                    (auditLogRecord.Process__c != null
                    ? auditLogRecord.Process__c
                    : 'Process') +
                    ' - ' +
                    auditLogRecord.Source__c;
            }
            return this;
        }
        /**
         * @description setType
         * @param typeVal
         * @return AuditLogCreator
         */
        public AuditLogCreator setType(String typeVal) {
            auditLogRecord.Type__c = typeVal;
            return this;
        }
        /**
         * @description setRequestBody
         * @param requestBody
         * @return AuditLogCreator
         */
        public AuditLogCreator setRequestBody(String requestBody) {
            auditLogRecord.Request_Body__c = requestBody;
            return this;
        }
        /**
         * @description setResponseBody
         * @param respBody
         * @return AuditLogCreator
         */
        public AuditLogCreator setResponseBody(String respBody) {
            auditLogRecord.Response_Body__c = respBody;
            return this;
        }
        /**
         * @description setSource
         * @param sourceName
         * @return AuditLogCreator
         */
        public AuditLogCreator setSource(String sourceName) {
            auditLogRecord.Source__c = sourceName;
            return this;
        }
    }
    
    /**
     * @description
     *  Initializes a new `AuditLogCreator` with common default values.
     *  Defaults applied:
     *  - `Process__c` from `process`
     *  - `Time_Stamp__c` as current time
     *  - `Source__c` from `source`
     *  - Exception record type
     *  - `Type__c = 'Exception'`
     *
     * @param process Process label for the audit event.
     * @param source Source label (class/module) for the audit event.
     * @return AuditLogHelper.AuditLogCreator Configured fluent builder instance.
     */
    public static AuditLogCreator auditLogRecord(String process, String source) {
        return new AuditLogCreator().setProcess(process)
            .setTimeStamp(System.now())
            .setSource(source)
            .setRecordTypeException()
            .setType(KenConstantController.RECORDTYPE_NAME_EXCEPTION);
    }
    
    /**
     * @description
     *  Returns RecordType Id for the provided sObject API name and record type name.
     *  Uses a per-transaction cache to reduce repeated queries.
     *
     * @param sobjectType Target sObject API name (for example, `Account`).
     * @param recordTypeName Record Type Name.
     * @return Id Matching RecordType Id, or null when not found/invalid/no access.
     */
    public static Id getSObjectRecordTypeId(String sobjectType, String recordTypeName) {
        if (String.isBlank(sobjectType) || String.isBlank(recordTypeName)) {return null;}
        String key = sobjectType + '::' + recordTypeName;
        if (recordTypeCache.containsKey(key)) {return recordTypeCache.get(key);}
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('RecordType') ||
        !canRead(gd.get('RecordType'))) {
            return null;
        }
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = :sobjectType AND Name = :recordTypeName
            WITH USER_MODE
            LIMIT 1
        ];
        Id rtId = rts.isEmpty() ? null : rts[0].Id;
        recordTypeCache.put(key, rtId);
        return rtId;
    }
    
    /**
     * @description
     *  Persists a single `Audit_Log__c` record after validating object-level create access.
     *  Applies DML options with field truncation enabled to prevent failures on oversized text values.
     *
     * @param auditLogRecord `Audit_Log__c` record to insert.
     * @return Audit_Log__c Inserted record when create succeeds; otherwise null.
     */
    private static Audit_Log__c createAuditLog(Audit_Log__c auditLogRecord) {
        if (auditLogRecord == null) {return null;}
        if (Audit_Log__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable()) {
            Database.DMLOptions dmlOptions = new Database.DMLOptions();
            dmlOptions.allowFieldTruncation = true;
            Database.insert(auditLogRecord, dmlOptions);
            return auditLogRecord;
        }
        return null;
    }
}