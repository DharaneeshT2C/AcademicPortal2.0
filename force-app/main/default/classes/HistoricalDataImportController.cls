/**
 * @description
 *
 * Usage:
 *  - LWC: historicalDataImporter -> HistoricalDataImportController.startCourseOfferingImport
 *  - LWC: historicalDataImporter -> HistoricalDataImportController.startCourseOfferingParticipantImport
 *  - LWC: historicalDataImporter -> HistoricalDataImportController.startExamImport
 *  - LWC: historicalDataImporter -> HistoricalDataImportController.getImportErrors
 */
public with sharing class HistoricalDataImportController {
    public class SessionOptionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }

    public class ExamCycleOptionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Id academicTermId;
        @AuraEnabled public String academicTermName;
    }

    public class PlanOptionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }

    public class ProgramOptionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String alias;
    }

    @AuraEnabled(cacheable=true)
    public static List<SessionOptionDTO> getAcademicSessions() {
        List<SessionOptionDTO> out = new List<SessionOptionDTO>();
        for (AcademicSession sess : [
            SELECT Id, Name
            FROM AcademicSession
            ORDER BY Name
        ]) {
            SessionOptionDTO dto = new SessionOptionDTO();
            dto.id = sess.Id;
            dto.name = sess.Name;
            out.add(dto);
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

    @AuraEnabled
    public static Id startCourseOfferingImport(String jsonRows, Id academicSessionId, Id learningProgramPlanId) {
        return Database.executeBatch(new CourseOfferingImportBatch(jsonRows, academicSessionId, learningProgramPlanId), 200);
    }

    @AuraEnabled
    public static Id startCourseOfferingParticipantImport(String jsonRows, Id academicSessionId) {
        return Database.executeBatch(new CourseOfferingParticipantImportBatch(jsonRows, academicSessionId), 200);
    }

    @AuraEnabled(cacheable=true)
    public static List<ProgramOptionDTO> getLearningPrograms() {
        List<ProgramOptionDTO> out = new List<ProgramOptionDTO>();
        Map<String, Schema.SObjectField> fields = LearningProgram.SObjectType.getDescribe().fields.getMap();
        String soql = 'SELECT Id, Name';
        if (fields.containsKey('Alias__c')) {
            soql += ', Alias__c';
        }
        soql += ' FROM LearningProgram ORDER BY Name';
        for (LearningProgram lp : Database.query(soql)) {
            ProgramOptionDTO dto = new ProgramOptionDTO();
            dto.id = lp.Id;
            dto.name = lp.Name;
            if (fields.containsKey('Alias__c')) {
                Object aliasVal = lp.get('Alias__c');
                dto.alias = aliasVal == null ? null : String.valueOf(aliasVal);
            }
            out.add(dto);
        }
        return out;
    }

    @AuraEnabled
    public static Id startExamImport(String jsonRows, Id learningProgramId) {
        return Database.executeBatch(new ExamImportBatch(jsonRows, learningProgramId), 50);
    }

    @AuraEnabled(cacheable=true)
    public static List<ExamCycleOptionDTO> getExamCycles() {
        List<ExamCycleOptionDTO> out = new List<ExamCycleOptionDTO>();
        if (!Schema.getGlobalDescribe().containsKey('Ken_Exam_Cycle__c')) {
            return out;
        }
        for (SObject row : Database.query(
            'SELECT Id, Name, Ken_Academic_Term__c, Ken_Academic_Term__r.Name FROM Ken_Exam_Cycle__c ORDER BY Name'
        )) {
            ExamCycleOptionDTO dto = new ExamCycleOptionDTO();
            dto.id = (Id) row.get('Id');
            dto.name = (String) row.get('Name');
            dto.academicTermId = (Id) row.get('Ken_Academic_Term__c');
            SObject academicTerm = row.getSObject('Ken_Academic_Term__r');
            dto.academicTermName = academicTerm == null ? null : (String) academicTerm.get('Name');
            out.add(dto);
        }
        return out;
    }

    @AuraEnabled
    public static Id startExamCourseResultImport(String jsonRows, Id examCycleId) {
        return Database.executeBatch(new ExamCourseResultImportBatch(jsonRows, examCycleId), 100);
    }

    @AuraEnabled
    public static Id startExamTermResultImport(String jsonRows, Id examCycleId) {
        return Database.executeBatch(new ExamTermResultImportBatch(jsonRows, examCycleId), 200);
    }

    @AuraEnabled
    public static List<String> getImportErrors(Id jobId, String processName) {
        List<String> out = new List<String>();
        if (jobId == null) {return out;}
        try {
            List<Audit_Log__c> logs = [
                SELECT Error_Message__c, Stack_Trace__c
                FROM Audit_Log__c
                WHERE RecordId__c = :String.valueOf(jobId)
                AND Process__c = :processName
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
}