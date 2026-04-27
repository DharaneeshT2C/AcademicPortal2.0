/**
 * ************************************************************************************************
 * @className  KenAuditLogHelper
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
public with sharing class KenAuditLogHelper {
    
    private static Map<String, Id> recordTypeCache = new Map<String, Id>();
    
    private static Boolean canRead(Schema.SObjectType sobjectType) {
        return sobjectType != null && sobjectType.getDescribe().isAccessible();
    }
    
    /**
     * @description
     *  Fluent builder class for composing and creating `Audit_Log__c` records.
     */
    public class KenAuditLogCreator {
        Audit_Log__c auditLogRecord;
        /**
         * @description KenAuditLogCreator
         */
        public KenAuditLogCreator() {
            auditLogRecord = new Audit_Log__c();
        }
        /**
         * @description create
         * @return Audit_Log__c
         */
        public Audit_Log__c create() {
            return KenAuditLogHelper.createAuditLog(auditLogRecord);
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
         * @return KenAuditLogCreator
         */
        public KenAuditLogCreator setProcess(String processName) {
            auditLogRecord.Process__c = processName;
            return this;
        }
        /**
         * @description setStackTrace
         * @param stackTrace
         * @return KenAuditLogCreator
         */
        public KenAuditLogCreator setStackTrace(String stackTrace) {
            auditLogRecord.Stack_Trace__c = stackTrace;
            return this;
        }
        /**
         * @description setSyncStatus
         * @param syncWithExternalLogger
         * @return KenAuditLogCreator
         */
        public KenAuditLogCreator setSyncStatus(Boolean syncWithExternalLogger) {
            auditLogRecord.Sync_with_External_Logger__c = syncWithExternalLogger;
            return this;
        }
        /**
         * @description setRecordTypeId
         * @param recordTypeId
         * @return KenAuditLogCreator
         */
        public KenAuditLogCreator setRecordType(Id recordTypeId) {
            auditLogRecord.RecordTypeId = recordTypeId;
            return this;
        }
        /**
         * @description setRecordTypeException
         * @return KenAuditLogCreator
         */
        public KenAuditLogCreator setRecordTypeException() {
            auditLogRecord.RecordTypeId = KenAuditLogHelper.getSObjectRecordTypeId(
                String.valueOf(Audit_Log__c.SObjectType),
            KenConstantController.RECORDTYPE_NAME_EXCEPTION
                );
            return this;
        }
        /**
         * @description setRecordTypeIntegration
         * @return KenAuditLogCreator
         */
        public KenAuditLogCreator setRecordTypeIntegration() {
            auditLogRecord.RecordTypeId = KenAuditLogHelper.getSObjectRecordTypeId(
                String.valueOf(Audit_Log__c.SObjectType),
            KenConstantController.RECORDTYPE_NAME_INTEGRATION
                );
            setSyncStatus(true);
            return this;
        }
        /**
         * @description setRecordId
         * @param recordId
         * @return KenAuditLogCreator
         */
        public KenAuditLogCreator setRecordId(String recordId) {
            auditLogRecord.RecordId__c = recordId;
            return this;
        }
        /**
         * @description setStatusCode
         * @param statusCode
         * @return KenAuditLogCreator
         */
        public KenAuditLogCreator setStatusCode(String statusCode) {
            auditLogRecord.Status_Code__c = statusCode;
            return this;
        }
        /**
         * @description setTimeStamp
         * @param timeStamp
         * @return KenAuditLogCreator
         */
        public KenAuditLogCreator setTimeStamp(Datetime timeStamp) {
            auditLogRecord.Time_Stamp__c = timeStamp;
            return this;
        }
        /**
         * @description setErrorMessage
         * @param errMessage
         * @return KenAuditLogCreator
         */
        public KenAuditLogCreator setErrorMessage(String errMessage) {
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
         * @return KenAuditLogCreator
         */
        public KenAuditLogCreator setType(String typeVal) {
            auditLogRecord.Type__c = typeVal;
            return this;
        }
        /**
         * @description setRequestBody
         * @param requestBody
         * @return KenAuditLogCreator
         */
        public KenAuditLogCreator setRequestBody(String requestBody) {
            auditLogRecord.Request_Body__c = requestBody;
            return this;
        }
        /**
         * @description setResponseBody
         * @param respBody
         * @return KenAuditLogCreator
         */
        public KenAuditLogCreator setResponseBody(String respBody) {
            auditLogRecord.Response_Body__c = respBody;
            return this;
        }
        /**
         * @description setSource
         * @param sourceName
         * @return KenAuditLogCreator
         */
        public KenAuditLogCreator setSource(String sourceName) {
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
     * @return KenAuditLogHelper.KenAuditLogCreator Configured fluent builder instance.
     */
    public static KenAuditLogCreator auditLogRecord(String process, String source) {
        return new KenAuditLogCreator().setProcess(process)
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