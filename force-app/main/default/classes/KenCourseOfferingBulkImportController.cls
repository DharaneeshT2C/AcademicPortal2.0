public with sharing class KenCourseOfferingBulkImportController {
    private static final String PROCESS_NAME = 'Course Offering Bulk Import';

    public class SessionOptionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }

    @AuraEnabled(cacheable=true)
    public static List<SessionOptionDTO> getAcademicSessionsForTerm(Id academicTermId) {
        if (academicTermId == null) {
            return new List<SessionOptionDTO>();
        }

        List<SessionOptionDTO> options = new List<SessionOptionDTO>();
        for (AcademicSession sessionRow : [
            SELECT Id, Name
            FROM AcademicSession
            WHERE AcademicTermId = :academicTermId
            ORDER BY Name
        ]) {
            SessionOptionDTO dto = new SessionOptionDTO();
            dto.id = sessionRow.Id;
            dto.name = sessionRow.Name;
            options.add(dto);
        }
        return options;
    }

    @AuraEnabled
    public static Id startImport(String jsonRows, Id academicTermId) {
        if (academicTermId == null) {
            throw new AuraHandledException('Academic Term record id is required.');
        }
        if (String.isBlank(jsonRows)) {
            throw new AuraHandledException('Upload at least one row before importing.');
        }

        return Database.executeBatch(
            new KenCourseOfferingBulkImportBatch(jsonRows, academicTermId, PROCESS_NAME),
            200
        );
    }

    @AuraEnabled
    public static List<String> getImportErrors(Id jobId) {
        List<String> errors = new List<String>();
        if (jobId == null) {
            return errors;
        }

        for (Audit_Log__c log : [
            SELECT Error_Message__c, Stack_Trace__c
            FROM Audit_Log__c
            WHERE RecordId__c = :String.valueOf(jobId)
            AND Process__c = :PROCESS_NAME
            ORDER BY CreatedDate DESC
            LIMIT 100
        ]) {
            String message = String.isBlank(log.Error_Message__c) ? log.Stack_Trace__c : log.Error_Message__c;
            if (String.isNotBlank(message)) {
                errors.add(message);
            }
        }
        return errors;
    }
}