public with sharing class KenCopBulkImportController {
    private static final String PROCESS_NAME = 'Course Offering Participant Bulk Import';

    public class NameOptionDTO {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
    }

    @AuraEnabled(cacheable=true)
    public static List<NameOptionDTO> getCourseOfferingNamesForTerm(Id academicTermId) {
        List<NameOptionDTO> options = new List<NameOptionDTO>();
        if (academicTermId == null) {
            return options;
        }

        for (CourseOffering offering : [
            SELECT Id, Name
            FROM CourseOffering
            WHERE AcademicSession.AcademicTermId = :academicTermId
            ORDER BY Name
        ]) {
            if (String.isBlank(offering.Name)) {
                continue;
            }
            NameOptionDTO dto = new NameOptionDTO();
            dto.value = offering.Name;
            dto.label = offering.Name;
            options.add(dto);
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<NameOptionDTO> getParticipationStatuses() {
        List<NameOptionDTO> options = new List<NameOptionDTO>();
        Map<String, Schema.SObjectField> fields = CourseOfferingParticipant.SObjectType.getDescribe().fields.getMap();
        if (!fields.containsKey('ParticipationStatus')) {
            return options;
        }

        for (Schema.PicklistEntry entry : fields.get('ParticipationStatus').getDescribe().getPicklistValues()) {
            if (entry == null || !entry.isActive()) {
                continue;
            }
            NameOptionDTO dto = new NameOptionDTO();
            dto.value = entry.getValue();
            dto.label = entry.getLabel();
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
            new KenCopBulkImportBatch(jsonRows, academicTermId, PROCESS_NAME),
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