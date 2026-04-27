/**
 * @description
 *
 * Usage:
 *  - No direct callers found
 */
public with sharing class ProgramImportBatch implements Database.Batchable<Map<String, Object>>, Database.Stateful {
    private final String jsonRows;
    private final Id providerId;
    private final Id campusId;
    private Integer insertedCount = 0;
    private Integer updatedCount = 0;
    
    private class ExistingProgramInfo {
        Id programId;
        Id learningId;
    }
    /**
     * @description
     * @return
     */
    private List<Audit_Log__c> pendingLogs = new List<Audit_Log__c>();
    
    /**
     * @description
     * @param jsonRows
     * @param providerId
     * @param campusId
     */
    public ProgramImportBatch(String jsonRows, Id providerId, Id campusId) {
        this.jsonRows = jsonRows;
        this.providerId = providerId;
        this.campusId = campusId;
    }
    
    /**
     * @description
     * @param bc
     * @return
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
     * @param bc
     * @param scope
     */
    public void execute(Database.BatchableContext bc, List<Map<String, Object>> scope) {
        Id jobId = bc != null ? bc.getJobId() : null;
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Learning') || !gd.containsKey('LearningProgram')) {return;}
        
        Schema.SObjectType learnType = gd.get('Learning');
        Schema.SObjectType programType = gd.get('LearningProgram');
        Map<String, Schema.SObjectField> learnFields = learnType.getDescribe().fields.getMap();
        Map<String, Schema.SObjectField> programFields = programType.getDescribe().fields.getMap();
        
        String programLearningField = programFields.containsKey('LearningId')
            ? 'LearningId'
            : (programFields.containsKey('Learning__c') ? 'Learning__c' : null);
        String learningTypeValue = null;
        if (learnFields.containsKey('Type')) {
            Schema.DescribeFieldResult typeField = learnFields.get('Type').getDescribe();
            learningTypeValue = ProgramImportController.resolvePicklistValue(typeField, 'LearningProgram');
        }
        Set<String> incomingCodes = new Set<String>();
        for (Map<String, Object> row : scope) {
            String code = getTrimmedString(row, 'CipCode');
            if (!String.isBlank(code)) {
                incomingCodes.add(code);
            }
        }
        
        Map<String, ExistingProgramInfo> existingProgramByCode = new Map<String, ExistingProgramInfo>();
        if (!incomingCodes.isEmpty() && learnFields.containsKey('CipCode')) {
            Set<Id> learningIds = new Set<Id>();
            Map<Id, String> codeByLearningId = new Map<Id, String>();
            String learningQuery = 'SELECT Id, CipCode FROM Learning WHERE CipCode IN :incomingCodes';
            if (!String.isBlank(learningTypeValue)) {
                learningQuery += ' AND Type = :learningTypeValue';
            }
            for (Learning existingLearning : Database.query(learningQuery)) {
                learningIds.add(existingLearning.Id);
                codeByLearningId.put(existingLearning.Id, String.valueOf(existingLearning.CipCode).trim().toLowerCase());
            }
            if (!learningIds.isEmpty() && !String.isBlank(programLearningField)) {
                for (SObject existingProgram : Database.query(
                    'SELECT Id, ' + programLearningField + ' FROM LearningProgram WHERE ' + programLearningField + ' IN :learningIds'
                )) {
                    Id learningId = (Id) existingProgram.get(programLearningField);
                    if (learningId == null || !codeByLearningId.containsKey(learningId)) {continue;}
                    ExistingProgramInfo info = new ExistingProgramInfo();
                    info.programId = (Id) existingProgram.get('Id');
                    info.learningId = learningId;
                    existingProgramByCode.put(codeByLearningId.get(learningId), info);
                }
            }
        }
        
        List<SObject> learningsToInsert = new List<SObject>();
        List<Integer> learningInsertRowIndexes = new List<Integer>();
        List<SObject> learningUpdates = new List<SObject>();
        List<Integer> learningUpdateRowIndexes = new List<Integer>();
        List<Map<String, Object>> rowMaps = new List<Map<String, Object>>();
        List<Id> existingLearningIdByRow = new List<Id>();
        List<Id> existingProgramIdByRow = new List<Id>();
        Set<String> seenCodesInFile = new Set<String>();
        
        for (Integer i = 0; i < scope.size(); i++) {
            Map<String, Object> row = scope[i];
            if (row == null) {continue;}
            String code = getTrimmedString(row, 'CipCode');
            if (!String.isBlank(code)) {
                String codeKey = code.toLowerCase();
                if (seenCodesInFile.contains(codeKey)) {
                    logDuplicate('Duplicate in file', i, scope, 'CipCode', code, jobId);
                    continue;
                }
                seenCodesInFile.add(codeKey);
            }
            
            ExistingProgramInfo existingInfo = !String.isBlank(code)
                ? existingProgramByCode.get(code.toLowerCase())
                : null;
            
            rowMaps.add(row);
            existingLearningIdByRow.add(existingInfo != null ? existingInfo.learningId : null);
            existingProgramIdByRow.add(existingInfo != null ? existingInfo.programId : null);
            
            if (existingInfo != null && existingInfo.learningId != null) {
                SObject learningUpdate = learnType.newSObject(existingInfo.learningId);
                mapLearningFields(learningUpdate, row, learnFields, false);
                setLearningDefaults(learningUpdate, learnFields, false, learningTypeValue);
                learningUpdates.add(learningUpdate);
                learningUpdateRowIndexes.add(rowMaps.size() - 1);
            } else {
                SObject learningInsert = learnType.newSObject();
                mapLearningFields(learningInsert, row, learnFields, true);
                setLearningDefaults(learningInsert, learnFields, true, learningTypeValue);
                learningsToInsert.add(learningInsert);
                learningInsertRowIndexes.add(rowMaps.size() - 1);
            }
        }
        
        if (!learningUpdates.isEmpty()) {
            Database.SaveResult[] learningUpdateResults = Database.update(learningUpdates, false);
            for (Integer i = 0; i < learningUpdateResults.size(); i++) {
                if (!learningUpdateResults[i].isSuccess()) {
                    logSaveResultErrors('Learning update', learningUpdateRowIndexes[i], rowMaps, learningUpdateResults[i], jobId);
                }
            }
        }
        
        List<Id> learningIdByRow = new List<Id>();
        for (Integer i = 0; i < rowMaps.size(); i++) {
            learningIdByRow.add(existingLearningIdByRow[i]);
        }
        
        if (!learningsToInsert.isEmpty()) {
            Database.SaveResult[] srs = Database.insert(learningsToInsert, false);
            for (Integer i=0;i<srs.size();i++){
                Integer rowIndex = learningInsertRowIndexes[i];
                if (srs[i].isSuccess()) {
                    learningIdByRow[rowIndex] = (Id) learningsToInsert[i].get('Id');
                } else {
                    learningIdByRow[rowIndex] = null;
                    logSaveResultErrors('Learning insert', rowIndex, rowMaps, srs[i], jobId);
                }
            }
        }
        
        List<SObject> programsToInsert = new List<SObject>();
        List<Integer> programInsertRowIndexes = new List<Integer>();
        List<SObject> programUpdates = new List<SObject>();
        List<Integer> programUpdateRowIndexes = new List<Integer>();
        Set<Id> learningIdsToDelete = new Set<Id>();
        Set<String> programFieldSkip = new Set<String>{
            'ActiveFromDate',
            'ActiveToDate',
            'Duration',
            'DurationUnit',
            'Category',
            'CipCode',
            'IsActive',
            'ImageUrl',
            'AcademicLevel'
        };
        for (Integer i=0;i<rowMaps.size();i++) {
            Map<String, Object> row = rowMaps[i];
            Id existingProgramId = existingProgramIdByRow[i];
            Boolean isInsert = existingProgramId == null;
            SObject p = isInsert ? programType.newSObject() : programType.newSObject(existingProgramId);
            if (learningIdByRow[i] != null && !String.isBlank(programLearningField)) {
                Schema.DescribeFieldResult learningFieldDescribe = programFields.get(programLearningField).getDescribe();
                if ((isInsert && learningFieldDescribe.isCreateable()) || (!isInsert && learningFieldDescribe.isUpdateable())) {
                    p.put(programLearningField, learningIdByRow[i]);
                }
            }
            if (campusId != null && programFields.containsKey('Campus__c')) {
                Schema.DescribeFieldResult campusField = programFields.get('Campus__c').getDescribe();
                if ((isInsert && campusField.isCreateable()) || (!isInsert && campusField.isUpdateable())) {
                    p.put('Campus__c', campusId);
                }
            }
            mapProgramFields(p, row, programFields, programFieldSkip, isInsert);
            if (isInsert && programFields.containsKey('IsActive')) {
                Schema.DescribeFieldResult activeField = programFields.get('IsActive').getDescribe();
                if (activeField.isCreateable()) {
                    p.put('IsActive', true);
                }
            }
            if (isInsert) {
                programsToInsert.add(p);
                programInsertRowIndexes.add(i);
            } else {
                programUpdates.add(p);
                programUpdateRowIndexes.add(i);
            }
        }
        
        if (!programsToInsert.isEmpty()) {
            Database.SaveResult[] srs = Database.insert(programsToInsert, false);
            for (Integer i=0;i<srs.size();i++){
                if (!srs[i].isSuccess()) {
                    Integer rowIndex = programInsertRowIndexes[i];
                    if (rowIndex < learningIdByRow.size() && learningIdByRow[rowIndex] != null) {
                        learningIdsToDelete.add(learningIdByRow[rowIndex]);
                    }
                    logSaveResultErrors('Learning Program insert', rowIndex, rowMaps, srs[i], jobId);
                } else {
                    insertedCount++;
                }
            }
        }
        
        if (!programUpdates.isEmpty()) {
            Database.SaveResult[] srs = Database.update(programUpdates, false);
            for (Integer i=0;i<srs.size();i++){
                if (!srs[i].isSuccess()) {
                    Integer rowIndex = programUpdateRowIndexes[i];
                    logSaveResultErrors('Learning Program update', rowIndex, rowMaps, srs[i], jobId);
                } else {
                    updatedCount++;
                }
            }
        }
        
        if (!learningIdsToDelete.isEmpty()) {
            Database.delete(new List<Id>(learningIdsToDelete), false);
        }
        
        flushAuditLogs();
    }
    
    /**
     * @description
     * @param bc
     */
    public void finish(Database.BatchableContext bc) {
        Id jobId = bc != null ? bc.getJobId() : null;
        String message = 'Program import summary: inserted=' + String.valueOf(insertedCount) +
            '; updated=' + String.valueOf(updatedCount);
        KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord(
            'Program Import',
        'Class:ProgramImportBatch'
            );
        creator.setErrorMessage(message);
        if (jobId != null) {creator.setRecordId(String.valueOf(jobId));}
        creator.create();
    }
    
    /**
     * @description
     * @param stage
     * @param rowIndex
     * @param rows
     * @param sr
     * @param jobId
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
     * @description
     * @param rowIndex
     * @param rows
     * @return
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
     * @param rowIndex
     * @param rows
     * @return
     */
    private static Integer getRowNumber(Integer rowIndex, List<Map<String, Object>> rows) {
        if (rowIndex == null || rows == null || rowIndex < 0 || rowIndex >= rows.size()) {return null;}
        Map<String, Object> row = rows[rowIndex];
        if (row != null && row.containsKey('RowNumber') && row.get('RowNumber') != null) {
            try {
                return Integer.valueOf(String.valueOf(row.get('RowNumber')).trim());
            } catch (Exception e) {
                // fall through to index
            }
        }
        return rowIndex + 1;
    }
    
    /**
     * @description
     * @param message
     * @param jobId
     */
    private void writeAuditLog(String message, Id jobId) {
        if (String.isBlank(message)) {return;}
        try {
            KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord('Program Import', 'Class:ProgramImportBatch');
            creator.setErrorMessage(message);
            if (jobId != null) {creator.setRecordId(String.valueOf(jobId));}
            Audit_Log__c log = creator.returnWithoutCreate();
            if (log != null) {pendingLogs.add(log);}
        } catch (Exception ex) {
            // avoid batch failure due to logging
        }
    }
    
    /**
     * @description
     * @param reason
     * @param rowIndex
     * @param rows
     * @param fieldName
     * @param fieldValue
     * @param jobId
     */
    private void logDuplicate(String reason, Integer rowIndex, List<Map<String, Object>> rows, String fieldName, String fieldValue, Id jobId) {
        Integer rowNum = getRowNumber(rowIndex, rows);
        String rowLabel = rowNum != null ? 'Row ' + rowNum : 'Row';
        String msg = 'Program duplicate skipped (' + reason + ') - ' + rowLabel + ' (' + fieldName + '=' + fieldValue + ')';
        writeAuditLog(msg, jobId);
    }
    
    /**
     * @description
     */
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
    
    private void mapLearningFields(SObject target, Map<String, Object> row, Map<String, Schema.SObjectField> learnFields, Boolean isInsert) {
        if (target == null || row == null || learnFields == null) {return;}
        for (String key : row.keySet()) {
            if (key == 'ProviderId') {continue;}
            if (!learnFields.containsKey(key)) {continue;}
            Schema.DescribeFieldResult d = learnFields.get(key).getDescribe();
            if ((isInsert && !d.isCreateable()) || (!isInsert && !d.isUpdateable())) {continue;}
            try {
                Object val = KenImportUtils.convertValue(row.get(key), d);
                target.put(key, val);
            } catch (Exception e) {
                // ignore per-row conversion error in batch
            }
        }
    }
    
    private void setLearningDefaults(SObject target, Map<String, Schema.SObjectField> learnFields, Boolean isInsert, String learningTypeValue) {
        if (target == null || learnFields == null) {return;}
        if (providerId != null && learnFields.containsKey('ProviderId')) {
            Schema.DescribeFieldResult providerField = learnFields.get('ProviderId').getDescribe();
            if ((isInsert && providerField.isCreateable()) || (!isInsert && providerField.isUpdateable())) {
                target.put('ProviderId', providerId);
            }
        }
        if (learnFields.containsKey('Type')) {
            Schema.DescribeFieldResult typeField = learnFields.get('Type').getDescribe();
            if (isInsert && typeField.isCreateable()) {
                if (learningTypeValue != null) {
                    target.put('Type', learningTypeValue);
                }
            }
        }
        if (learnFields.containsKey('IsActive')) {
            Schema.DescribeFieldResult activeField = learnFields.get('IsActive').getDescribe();
            if (isInsert && activeField.isCreateable()) {
                target.put('IsActive', true);
            }
        }
    }
    
    private void mapProgramFields(
        SObject target,
        Map<String, Object> row,
        Map<String, Schema.SObjectField> programFields,
        Set<String> programFieldSkip,
        Boolean isInsert
    ) {
        if (target == null || row == null || programFields == null) {return;}
        for (String key : row.keySet()) {
            if (programFieldSkip != null && programFieldSkip.contains(key)) {continue;}
            if (!programFields.containsKey(key)) {continue;}
            Schema.DescribeFieldResult d = programFields.get(key).getDescribe();
            if ((isInsert && !d.isCreateable()) || (!isInsert && !d.isUpdateable())) {continue;}
            try {
                Object val = KenImportUtils.convertValue(row.get(key), d);
                target.put(key, val);
            } catch (Exception e) {
                // ignore
            }
        }
    }
    
    private static String getTrimmedString(Map<String, Object> row, String key) {
        if (row == null || String.isBlank(key) || !row.containsKey(key) || row.get(key) == null) {return null;}
        return String.valueOf(row.get(key)).trim();
    }
}