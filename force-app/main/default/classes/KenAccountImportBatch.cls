/**
 * ************************************************************************************************
 * @className  AccountImportBatch
 *
 * @description
 *  Batch processor for Account imports (University/Institute/Department/School).
 *
 *  Responsibilities:
 *  - Parse incoming JSON rows
 *  - Detect duplicates (in org + in file)
 *  - Insert Accounts with the correct RecordType and optional ParentId
 *  - Log errors and duplicates to Audit_Log__c
 *
 * @author      Sureka A R K
 * @createdOn   Jan 13, 2026
 *
 * @history
 * ------------------------------------------------------------------------------------------------
 * Version   Date           Author          Description
 * 1.0       Jan 13, 2026   Sureka A R K     Initial version
 * ************************************************************************************************
 */
@suppressWarnings('PMD.StdCyclomaticComplexity,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssMethodCount,PMD.ExcessiveParameterList')
public with sharing class KenAccountImportBatch implements Database.Batchable<Map<String, Object>>, Database.Stateful {
    private final String jsonRows;
    private final String recordTypeName;
    private final Id parentId;
    private Id recordTypeId;
    private Integer totalCount = 0;
    private Integer successCount = 0;
    private List<Audit_Log__c> pendingLogs = new List<Audit_Log__c>();
    private static Boolean loggingFailureHandled = false;
    
    /**
     * @description
     *  Constructs the batch with raw JSON rows and record type context.
     *
     * @param jsonRows JSON array of row maps from the import UI.
     * @param recordTypeName Account record type name to apply.
     * @param parentId Optional parent Account Id for hierarchy imports.
     */
    public KenAccountImportBatch(String jsonRows, String recordTypeName, Id parentId) {
        this.jsonRows = jsonRows;
        this.recordTypeName = recordTypeName;
        this.parentId = parentId;
        this.recordTypeId = KenAccountImportController.getAccountRecordTypeId(recordTypeName);
    }
    
    /**
     * @description
     *  Parses JSON rows into a batchable iterable.
     *
     * @param bc Batch context (unused).
     * @return Iterable of row maps for batch execution.
     */
    public Iterable<Map<String, Object>> start(Database.BatchableContext bc) {
        List<Map<String, Object>> maps = new List<Map<String, Object>>();
        if (String.isBlank(jsonRows)) {return maps;}
        List<Object> rows = (List<Object>) JSON.deserializeUntyped(jsonRows);
        for (Object o : rows) {
            if (o instanceof Map<String, Object>) {maps.add((Map<String, Object>) o);}
        }
        return maps;
    }
    
    /**
     * @description
     *  Processes a scope of rows, inserts Accounts, and logs errors/duplicates.
     *
     * @param bc Batch context containing the job id.
     * @param scope Current batch scope of row maps.
     */
    public void execute(Database.BatchableContext bc, List<Map<String, Object>> scope) {
        Id jobId = bc != null ? bc.getJobId() : null;
        String processName = resolveProcessName(recordTypeName);
        totalCount += (scope == null ? 0 : scope.size());
        if (recordTypeId == null) {return;}
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Account')) {return;}
        Schema.SObjectType accType = gd.get('Account');
        Map<String, Schema.SObjectField> accFields = accType.getDescribe().fields.getMap();
        Boolean isDepartmentImport = recordTypeName == KenConstantController.RECORDTYPE_ACCOUNT_DEPARTMENT;
        
        Set<String> incomingNames = new Set<String>();
        Set<String> incomingCodes = new Set<String>();
        for (Map<String, Object> row : scope) {
            Object nameVal = row.get('Name');
            if (nameVal != null && String.valueOf(nameVal).trim().length() > 0) {
                incomingNames.add(String.valueOf(nameVal).trim());
            }
            Object codeVal = row.get('Code__c');
            if (isDepartmentImport && codeVal != null && String.valueOf(codeVal).trim().length() > 0) {
                incomingCodes.add(String.valueOf(codeVal).trim());
            }
        }
        
        Set<String> existingKeys = new Set<String>();
        Map<String, Id> existingDepartmentByCode = new Map<String, Id>();
        if (isDepartmentImport && accFields.containsKey('Code__c') && !incomingCodes.isEmpty()) {
            if (parentId != null) {
                for (Account a : [
                    SELECT Id, Code__c
                    FROM Account
                    WHERE RecordTypeId = :recordTypeId
                    AND ParentId = :parentId
                    AND Code__c IN :incomingCodes
                ]) {
                    if (String.isNotBlank(a.Code__c)) {
                        existingDepartmentByCode.put(a.Code__c.trim().toLowerCase(), a.Id);
                    }
                }
            } else {
                for (Account a : [
                    SELECT Id, Code__c
                    FROM Account
                    WHERE RecordTypeId = :recordTypeId
                    AND ParentId = null
                    AND Code__c IN :incomingCodes
                ]) {
                    if (String.isNotBlank(a.Code__c)) {
                        existingDepartmentByCode.put(a.Code__c.trim().toLowerCase(), a.Id);
                    }
                }
            }
        }
        if (!incomingNames.isEmpty()) {
            if (parentId != null) {
                for (Account a : [
                    SELECT Id, Name
                    FROM Account
                    WHERE RecordTypeId = :recordTypeId
                    AND ParentId = :parentId
                    AND Name IN :incomingNames
                ]) {
                    existingKeys.add(a.Name.toLowerCase());
                }
            } else {
                for (Account a : [
                    SELECT Id, Name
                    FROM Account
                    WHERE RecordTypeId = :recordTypeId
                    AND ParentId = null
                    AND Name IN :incomingNames
                ]) {
                    existingKeys.add(a.Name.toLowerCase());
                }
            }
        }
        
        List<SObject> accounts = new List<SObject>();
        List<Integer> accountRowIndexes = new List<Integer>();
        List<Boolean> accountIsInsert = new List<Boolean>();
        Integer idx = 0;
        Set<String> newKeys = new Set<String>();
        for (Map<String, Object> row : scope) {
            idx++;
            String nameStr = row.get('Name') == null ? null : String.valueOf(row.get('Name')).trim();
            String codeStr = row.get('Code__c') == null ? null : String.valueOf(row.get('Code__c')).trim();
            Id existingDepartmentId = isDepartmentImport && String.isNotBlank(codeStr)
                ? existingDepartmentByCode.get(codeStr.toLowerCase())
                : null;
            Boolean isInsert = existingDepartmentId == null;
            SObject a = isInsert ? accType.newSObject() : accType.newSObject(existingDepartmentId);
            if (String.isNotBlank(nameStr)) {
                String key = isDepartmentImport && String.isNotBlank(codeStr)
                    ? codeStr.toLowerCase()
                    : nameStr.toLowerCase();
                if (newKeys.contains(key)) {
                    logDuplicate('Duplicate in file', idx - 1, scope, String.isNotBlank(codeStr) ? codeStr : nameStr, jobId, processName);
                    continue;
                }
                if (isInsert && existingKeys.contains(key)) {
                    logDuplicate('Duplicate in org', idx - 1, scope, nameStr, jobId, processName);
                    continue;
                }
                newKeys.add(key);
            }
            if (isInsert) {
                a.put('RecordTypeId', recordTypeId);
            }
            if (parentId != null && accFields.containsKey('ParentId')) {
                Schema.DescribeFieldResult parentField = accFields.get('ParentId').getDescribe();
                if ((isInsert && parentField.isCreateable()) || (!isInsert && parentField.isUpdateable())) {
                    a.put('ParentId', parentId);
                }
            }
            for (String key : row.keySet()) {
                if (key == 'RecordTypeId' || key == 'RecordType' || key == 'RecordType.Name' || key == 'ParentId') {
                    continue;
                }
                if (accFields.containsKey(key)) {
                    Schema.DescribeFieldResult d = accFields.get(key).getDescribe();
                    if ((isInsert && !d.isCreateable()) || (!isInsert && !d.isUpdateable())) {continue;}
                    try {
                        Object val = KenImportUtils.convertValue(row.get(key), d);
                        a.put(key, val);
                    } catch (Exception e) {
                        logCatchException('Row conversion failed for field ' + key, e, jobId, processName);
                    }
                }
            }
            accounts.add(a);
            accountRowIndexes.add(idx - 1);
            accountIsInsert.add(isInsert);
        }
        
        if (!accounts.isEmpty()) {
            List<SObject> inserts = new List<SObject>();
            List<Integer> insertRowIndexes = new List<Integer>();
            List<SObject> updates = new List<SObject>();
            List<Integer> updateRowIndexes = new List<Integer>();
            for (Integer i = 0; i < accounts.size(); i++) {
                if (accountIsInsert[i]) {
                    inserts.add(accounts[i]);
                    insertRowIndexes.add(accountRowIndexes[i]);
                } else {
                    updates.add(accounts[i]);
                    updateRowIndexes.add(accountRowIndexes[i]);
                }
            }
            if (!inserts.isEmpty()) {
                Database.SaveResult[] srs = Database.insert(inserts, false);
                for (Integer i = 0; i < srs.size(); i++) {
                    if (srs[i].isSuccess()) {
                        successCount++;
                    } else {
                        Integer rowIndex = insertRowIndexes[i];
                        logSaveResultErrors('Account insert', rowIndex, scope, srs[i], jobId, processName);
                    }
                }
            }
            if (!updates.isEmpty()) {
                Database.SaveResult[] srs = Database.update(updates, false);
                for (Integer i = 0; i < srs.size(); i++) {
                    if (srs[i].isSuccess()) {
                        successCount++;
                    } else {
                        Integer rowIndex = updateRowIndexes[i];
                        logSaveResultErrors('Account update', rowIndex, scope, srs[i], jobId, processName);
                    }
                }
            }
        }
        
        flushAuditLogs();
    }
    
    /**
     * @description
     *  No-op finish hook for batch completion.
     *
     * @param bc Batch context (unused).
     */
    public void finish(Database.BatchableContext bc) {
        String successMessage =
            'Total count:' + successCount + ' successfully processed out of ' + totalCount + '!';
        KenAuditLogHelper.auditLogRecord(resolveProcessName(recordTypeName), 'Class:AccountImportBatch')
            .setErrorMessage('Batch summary')
            .setStackTrace(successMessage)
            .create();
    }
    
    /**
     * @description
     *  Resolves the Audit Log process name based on record type.
     *
     * @param rtName Account record type name from the import.
     * @return Process name used when writing audit logs.
     */
    private static String resolveProcessName(String rtName) {
        if (rtName == KenConstantController.RECORDTYPE_ACCOUNT_UNIVERSITY) {
            return 'University Import';
        }
        if (rtName == KenConstantController.RECORDTYPE_ACCOUNT_INSTITUTE) {
            return 'Institute Import';
        }
        if (rtName == KenConstantController.RECORDTYPE_ACCOUNT_DEPARTMENT) {
            return 'Department Import';
        }
        if (rtName == KenConstantController.RECORDTYPE_ACCOUNT_SCHOOL) {
            return 'School Import';
        }
        return 'Account Import';
    }
    
    /**
     * @description
     *  Logs errors from failed DML operations.
     *
     * @param stage Friendly label for the DML stage.
     * @param rowIndex Zero-based row index in the scope list.
     * @param rows Current batch scope rows.
     * @param sr SaveResult containing error details.
     * @param jobId Batch job id for correlation.
     * @param processName Audit log process name.
     */
    private void logSaveResultErrors(String stage, Integer rowIndex, List<Map<String, Object>> rows, Database.SaveResult sr, Id jobId, String processName) {
        if (sr == null || sr.isSuccess() || sr.getErrors() == null || sr.getErrors().isEmpty()) {return;}
        Database.Error e = sr.getErrors()[0];
        Integer rowNum = getRowNumber(rowIndex, rows);
        String rowLabel = rowNum != null ? 'Row ' + rowNum : 'Row';
        String rowHint = getRowHint(rowIndex, rows);
        String msg = stage + ' - ' + rowLabel + rowHint + ': ' + e.getMessage();
        writeAuditLog(msg, jobId, processName);
    }
    
    /**
     * @description
     *  Builds a readable row hint for error messages.
     *
     * @param rowIndex Zero-based row index in the scope list.
     * @param rows Current batch scope rows.
     * @return Row hint such as "(Name=...)" or empty string.
     */
    private static String getRowHint(Integer rowIndex, List<Map<String, Object>> rows) {
        if (rowIndex == null || rows == null || rowIndex < 0 || rowIndex >= rows.size()) {return '';}
        Map<String, Object> row = rows[rowIndex];
        if (row == null) {return '';}
        if (row.containsKey('Name') && row.get('Name') != null) {return ' (Name=' + String.valueOf(row.get('Name')) + ')';}
        return '';
    }
    
    /**
     * @description
     *  Resolves the 1-based row number for error reporting.
     *
     * @param rowIndex Zero-based row index in the scope list.
     * @param rows Current batch scope rows.
     * @return 1-based row number when available, otherwise null.
     */
    private static Integer getRowNumber(Integer rowIndex, List<Map<String, Object>> rows) {
        if (rowIndex == null || rows == null || rowIndex < 0 || rowIndex >= rows.size()) {return null;}
        Map<String, Object> row = rows[rowIndex];
        if (row != null && row.containsKey('RowNumber') && row.get('RowNumber') != null) {
            try {
                return Integer.valueOf(String.valueOf(row.get('RowNumber')).trim());
            } catch (Exception e) {
                KenAuditLogHelper.auditLogRecord('Account Import', 'Class:AccountImportBatch')
                    .setErrorMessage(
                    'AccountImportBatch.getRowNumber invalid RowNumber value, falling back to index: ' +
                    e.getMessage()
                    )
                    .setStackTrace(e.getStackTraceString())
                    .create();
            }
        }
        return rowIndex + 1;
    }
    
    /**
     * @description
     *  Adds an Audit Log entry to the pending buffer.
     *
     * @param message Error message to store.
     * @param jobId Batch job id for correlation.
     * @param processName Audit log process name.
     */
    private void writeAuditLog(String message, Id jobId, String processName) {
        if (String.isBlank(message)){ return;}
        try {
            KenAuditLogHelper.KenAuditLogCreator creator =
                KenAuditLogHelper.auditLogRecord(processName, 'Class:AccountImportBatch');
            creator.setErrorMessage(message);
            if (jobId != null) {creator.setRecordId(String.valueOf(jobId));}
            Audit_Log__c log = creator.returnWithoutCreate();
            if (log != null) {pendingLogs.add(log);}
        } catch (Exception ex) {
            logCatchException('writeAuditLog failed', ex, jobId, processName);
        }
    }
    
    /**
     * @description
     *  Logs duplicate row details to the audit log buffer.
     *
     * @param reason Duplicate reason label.
     * @param rowIndex Zero-based row index in the scope list.
     * @param rows Current batch scope rows.
     * @param nameStr Name value used for duplicate detection.
     * @param jobId Batch job id for correlation.
     * @param processName Audit log process name.
     */
    private void logDuplicate(String reason, Integer rowIndex, List<Map<String, Object>> rows, String nameStr, Id jobId, String processName) {
        Integer rowNum = getRowNumber(rowIndex, rows);
        String rowLabel = rowNum != null ? 'Row ' + rowNum : 'Row';
        String msg = 'Account duplicate skipped (' + reason + ') - ' + rowLabel + ' (Name=' + nameStr + ')';
        writeAuditLog(msg, jobId, processName);
    }
    
    /**
     * @description
     *  Persists buffered audit logs in a single DML operation.
     *
     */
    private void flushAuditLogs() {
        if (pendingLogs == null || pendingLogs.isEmpty()) {return;}
        try {
            Database.DMLOptions dmlOptions = new Database.DMLOptions();
            dmlOptions.allowFieldTruncation = true;
            Database.insert(pendingLogs, dmlOptions);
        } catch (Exception ex) {
            logCatchException(
                'flushAuditLogs failed',
            ex,
            null,
            'Account Import'
                );
        } finally {
            pendingLogs.clear();
        }
    }
    
    private void logCatchException(String context, Exception ex, Id jobId, String processName) {
        if (ex == null || loggingFailureHandled) {return;}
        try {
            KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord(
                String.isBlank(processName)
                ? 'Account Import'
                : processName,
            'Class:AccountImportBatch'
                );
            creator.setErrorMessage((String.isBlank(context) ? 'Exception' : context) + ': ' + ex.getMessage());
            creator.setStackTrace(ex.getStackTraceString());
            if (jobId != null) {creator.setRecordId(String.valueOf(jobId));}
            creator.create();
        } catch (Exception ignoreLoggingException) {
            loggingFailureHandled = true;
        }
    }
}