/**
 * @description
 *
 * Usage:
 *  - LWC: lwc/programImporter/programImporter.js -> ProgramImportController.startProgramImportBatch
 *  - LWC: lwc/programImporter/programImporter.js -> ProgramImportController.getProgramImportErrors
 *  - Apex: classes/ProgramImportBatch.cls -> ProgramImportController.resolvePicklistValue
 *  - Apex: classes/ProgramImportBatchTest.cls -> ProgramImportController.resolvePicklistValue
 *  - Apex: classes/ProgramImportControllerTest.cls -> ProgramImportController.resolvePicklistValue
 *  - Apex: classes/ProgramImportControllerTest.cls -> ProgramImportController.startProgramImportBatch
 *  - Apex: classes/ProgramImportControllerTest.cls -> ProgramImportController.getProgramImportErrors
 */
public with sharing class ProgramImportController {
    public class ProgramImportResult {
        @AuraEnabled public List<String> errors;
        @AuraEnabled public Integer insertedCount;
        @AuraEnabled public Integer updatedCount;
        
        public ProgramImportResult() {
            this.errors = new List<String>();
            this.insertedCount = 0;
            this.updatedCount = 0;
        }
    }

    /**
     * @description
     * @param d
     * @param desired
     * @return
     */
    public static String resolvePicklistValue(Schema.DescribeFieldResult d, String desired) {
        if (d == null || String.isBlank(desired)) {return null;}
        String desiredLower = desired.toLowerCase();
        for (Schema.PicklistEntry pe : d.getPicklistValues()) {
            String val = pe.getValue();
            String label = pe.getLabel();
            if (!String.isBlank(val) && val.toLowerCase() == desiredLower) {return val;}
            if (!String.isBlank(label) && label.toLowerCase() == desiredLower) {return val;}
        }
        return null;
    }
    
    /**
     * @description
     * @param jsonRows
     * @param providerId
     * @param campusId
     * @return
     */
    @AuraEnabled
    public static Id startProgramImportBatch(String jsonRows, Id providerId, Id campusId) {
        return Database.executeBatch(new ProgramImportBatch(jsonRows, providerId, campusId), 200);
    }
    
    /**
     * @description
     * @param jobId
     * @return
     */
    @AuraEnabled
    public static List<String> getProgramImportErrors(Id jobId) {
        return getProgramImportResult(jobId).errors;
    }

    @AuraEnabled
    public static ProgramImportResult getProgramImportResult(Id jobId) {
        ProgramImportResult result = new ProgramImportResult();
        if (jobId == null) {return result;}
        try {
            List<Audit_Log__c> logs = [
                SELECT Error_Message__c, Stack_Trace__c
                FROM Audit_Log__c
                WHERE RecordId__c = :String.valueOf(jobId)
                AND Process__c = 'Program Import'
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
                } else {
                    result.errors.add(msg);
                }
            }
        } catch (Exception e) {
            result.errors.add('Error fetching audit logs: ' + e.getMessage());
        }
        return result;
    }

    private static Boolean isSummaryMessage(String message) {
        if (String.isBlank(message)) {return false;}
        return message.trim().toLowerCase().startsWith('program import summary:');
    }

    private static void applySummary(ProgramImportResult result, String message) {
        if (result == null || String.isBlank(message)) {return;}
        String normalized = message.trim().toLowerCase();
        List<String> parts = normalized.replace('program import summary:', '').split(';');
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
}