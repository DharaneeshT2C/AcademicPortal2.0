/**
 * @description
 *
 * Usage:
 *  - LWC: lwc/userImporter/userImporter.js -> UserImportController.startUserImportBatch
 *  - LWC: lwc/userImporter/userImporter.js -> UserImportController.getUserImportErrors
 *  - Apex: classes/UserImportControllerTest.cls -> UserImportController.startUserImportBatch
 *  - Apex: classes/UserImportControllerTest.cls -> UserImportController.getUserImportErrors
 */
public with sharing class UserImportController {
    public class PlanOptionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }

    /**
     * @description
     * @param jsonRows
     * @param userType
     * @param accountId
     * @return
     */
    @AuraEnabled
    public static Id startUserImportBatch(String jsonRows, String userType, Id learningProgramPlanId, String section) {
        return Database.executeBatch(new UserImportBatch(jsonRows, userType, learningProgramPlanId, section), 200);
    }

    public static Id startUserImportBatch(String jsonRows, String userType, Id learningProgramPlanId) {
        return startUserImportBatch(jsonRows, userType, learningProgramPlanId, null);
    }
    
    /**
     * @description
     * @param jobId
     * @return
     */
    @AuraEnabled
    public static List<String> getUserImportErrors(Id jobId) {
        List<String> out = new List<String>();
        if (jobId == null) {return out;}
        try {
            List<Audit_Log__c> logs = [
                SELECT Error_Message__c, Stack_Trace__c
                FROM Audit_Log__c
                WHERE RecordId__c = :String.valueOf(jobId)
                AND Process__c = 'User Import'
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
            if (logs.isEmpty()) {
                logs = [
                    SELECT Error_Message__c, Stack_Trace__c
                    FROM Audit_Log__c
                    WHERE RecordId__c = :String.valueOf(jobId)
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ];
            }
            for (Audit_Log__c log : logs) {
                String msg = log.Error_Message__c;
                if (String.isBlank(msg)) {msg = log.Stack_Trace__c;}
                if (!String.isBlank(msg)) {out.add(msg);}
            }
        } catch (Exception e) {
            out.add('Error fetching audit logs: ' + e.getMessage());
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static List<PlanOptionDTO> getActiveProgramPlans() {
        List<PlanOptionDTO> out = new List<PlanOptionDTO>();
        Map<String, Schema.SObjectField> fields = LearningProgramPlan.SObjectType.getDescribe().fields.getMap();
        String soql = 'SELECT Id, Name FROM LearningProgramPlan';
        List<String> whereParts = new List<String>();
        if (fields.containsKey('ActiveFromDate')) {
            whereParts.add('ActiveFromDate <= TODAY');
        }
        if (fields.containsKey('ActiveToDate')) {
            whereParts.add('ActiveToDate >= TODAY');
        }
        if (!whereParts.isEmpty()) {
            soql += ' WHERE ' + String.join(whereParts, ' AND ');
        }
        soql += ' ORDER BY Name';
        for (LearningProgramPlan plan : Database.query(soql)) {
            PlanOptionDTO dto = new PlanOptionDTO();
            dto.id = plan.Id;
            dto.name = plan.Name;
            out.add(dto);
        }
        return out;
    }
}