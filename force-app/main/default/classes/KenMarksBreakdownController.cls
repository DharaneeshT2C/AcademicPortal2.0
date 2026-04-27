/**
 * ************************************************************************************************
 * @className  KenMarksBreakdownController
 *
 * @description
 *  Backs the `my/marksBreakdown` LWC page. Returns a per-subject marks
 *  decomposition: internal assessment, midterm, external, assignments.
 *
 *  TODO[SOBJECT]: Wire to `Assessment_Component__c` (Subject__c, Type__c,
 *                 Max_Marks__c, Obtained_Marks__c, Weight__c).
 * ************************************************************************************************
 */
public with sharing class KenMarksBreakdownController {

    public class ComponentRowDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  type;        // 'internal' | 'midterm' | 'external' | 'assignment'
        @AuraEnabled public String  label;
        @AuraEnabled public Decimal maxMarks;
        @AuraEnabled public Decimal obtainedMarks;
        @AuraEnabled public Decimal weightPct;
    }

    public class SubjectBreakdownDTO {
        @AuraEnabled public String                subjectId;
        @AuraEnabled public String                subject;
        @AuraEnabled public String                code;
        @AuraEnabled public Decimal               totalObtained;
        @AuraEnabled public Decimal               totalMax;
        @AuraEnabled public List<ComponentRowDTO> components;
    }

    @AuraEnabled(cacheable=true)
    public static SubjectBreakdownDTO getBreakdown(Id subjectId) {
        try {
            KenAuraExceptionHelper.rejectIf(subjectId == null, 'Subject id is required.');
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId == null) return seedBreakdown(subjectId);
            // Subject__c is itself text, so subjectId here is treated as subject name
            String subjectName = String.valueOf(subjectId);
            List<Assessment_Component__c> comps = [
                SELECT Id, Subject__c, Type__c, Label__c, Max_Marks__c, Obtained_Marks__c, Weight_Pct__c
                FROM Assessment_Component__c
                WHERE Student__c = :contactId AND Subject__c = :subjectName
                WITH USER_MODE
                ORDER BY Type__c
            ];
            if (comps.isEmpty()) return seedBreakdown(subjectId);
            return buildSubjectDTO(subjectName, comps);
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenMarksBreakdownController.getBreakdown',
                'Unable to load marks breakdown.', e);
            return null;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<SubjectBreakdownDTO> getAllBreakdowns() {
        try {
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId == null) return new List<SubjectBreakdownDTO>{ seedBreakdown(null) };
            // Group all the student's assessment components by subject
            Map<String, List<Assessment_Component__c>> bySubject = new Map<String, List<Assessment_Component__c>>();
            for (Assessment_Component__c c : [
                SELECT Id, Subject__c, Type__c, Label__c, Max_Marks__c, Obtained_Marks__c, Weight_Pct__c
                FROM Assessment_Component__c
                WHERE Student__c = :contactId
                WITH USER_MODE
                ORDER BY Subject__c, Type__c
            ]) {
                if (!bySubject.containsKey(c.Subject__c)) bySubject.put(c.Subject__c, new List<Assessment_Component__c>());
                bySubject.get(c.Subject__c).add(c);
            }
            List<SubjectBreakdownDTO> out = new List<SubjectBreakdownDTO>();
            for (String subj : bySubject.keySet()) {
                out.add(buildSubjectDTO(subj, bySubject.get(subj)));
            }
            if (out.isEmpty()) out.add(seedBreakdown(null));
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenMarksBreakdownController.getAllBreakdowns',
                'Unable to load marks.', e);
            return null;
        }
    }

    private static SubjectBreakdownDTO buildSubjectDTO(String subjectName, List<Assessment_Component__c> comps) {
        SubjectBreakdownDTO b = new SubjectBreakdownDTO();
        b.subjectId     = subjectName;
        b.subject       = subjectName;
        b.code          = '';
        b.totalObtained = 0;
        b.totalMax      = 0;
        b.components    = new List<ComponentRowDTO>();
        for (Assessment_Component__c c : comps) {
            ComponentRowDTO r = new ComponentRowDTO();
            r.id            = c.Id;
            r.type          = c.Type__c;
            r.label         = c.Label__c;
            r.maxMarks      = c.Max_Marks__c == null ? 0 : c.Max_Marks__c;
            r.obtainedMarks = c.Obtained_Marks__c == null ? 0 : c.Obtained_Marks__c;
            r.weightPct     = c.Weight_Pct__c == null ? 0 : c.Weight_Pct__c;
            b.components.add(r);
            b.totalObtained += r.obtainedMarks;
            b.totalMax      += r.maxMarks;
        }
        return b;
    }

    private static SubjectBreakdownDTO seedBreakdown(Id subjectId) {
        SubjectBreakdownDTO b = new SubjectBreakdownDTO();
        b.subjectId     = subjectId;
        b.subject       = 'Data Structures';
        b.code          = 'CS301';
        b.totalObtained = 82;
        b.totalMax      = 100;
        b.components    = new List<ComponentRowDTO>{
            row('MB01', 'internal',   'Internal 1',    20, 17, 20),
            row('MB02', 'assignment', 'Assignments',   10,  9, 10),
            row('MB03', 'midterm',    'Midterm',       20, 15, 20),
            row('MB04', 'external',   'Final exam',    50, 41, 50)
        };
        return b;
    }

    private static ComponentRowDTO row(String id, String type, String label, Decimal max, Decimal got, Decimal weight) {
        ComponentRowDTO r = new ComponentRowDTO();
        r.id = id; r.type = type; r.label = label;
        r.maxMarks = max; r.obtainedMarks = got; r.weightPct = weight;
        return r;
    }
}