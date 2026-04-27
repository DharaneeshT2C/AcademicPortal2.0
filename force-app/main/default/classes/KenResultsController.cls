/**
 * ************************************************************************************************
 * @className  KenResultsController
 *
 * @description
 *  Backs the `my/results` LWC page and the drill-down `my/semesterDetail`.
 *  Returns CGPA, semester-wise GPA, subject grades.
 *
 *  TODO[SOBJECT]: Wire to `Grade__c` or Education Cloud `LearnerAssessment`.
 * ************************************************************************************************
 */
public with sharing class KenResultsController {

    public class SemesterResultDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  label;
        @AuraEnabled public Decimal gpa;
        @AuraEnabled public Integer creditsEarned;
        @AuraEnabled public String  status;
    }

    public class SubjectGradeDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  subject;
        @AuraEnabled public String  code;
        @AuraEnabled public String  grade;
        @AuraEnabled public Decimal marks;
        @AuraEnabled public Integer credits;
    }

    public class ResultsBundleDTO {
        @AuraEnabled public Decimal                   currentCGPA;
        @AuraEnabled public Integer                   totalCreditsEarned;
        @AuraEnabled public Integer                   totalCreditsRequired;
        @AuraEnabled public List<SemesterResultDTO>   semesters;
    }

    @AuraEnabled(cacheable=true)
    public static ResultsBundleDTO getResultsBundle() {
        try {
            ResultsBundleDTO b = new ResultsBundleDTO();
            b.semesters            = seedSemesters(); // No Semester__c object; keep static
            b.totalCreditsRequired = 160;
            // Compute current CGPA from real Assessment_Component__c if present
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId != null) {
                Decimal sumPct = 0; Integer cnt = 0;
                for (AggregateResult ar : [
                    SELECT Subject__c sub, AVG(Obtained_Marks__c) avgObt, AVG(Max_Marks__c) avgMax
                    FROM Assessment_Component__c
                    WHERE Student__c = :contactId AND Max_Marks__c > 0
                    WITH USER_MODE
                    GROUP BY Subject__c
                ]) {
                    Decimal o = (Decimal) ar.get('avgObt');
                    Decimal m = (Decimal) ar.get('avgMax');
                    if (m != null && m > 0 && o != null) { sumPct += (o / m * 10); cnt++; }
                }
                if (cnt > 0) {
                    b.currentCGPA = (sumPct / cnt).setScale(2);
                    b.totalCreditsEarned = cnt * 4;
                } else {
                    b.currentCGPA        = 8.2;
                    b.totalCreditsEarned = 96;
                }
            } else {
                b.currentCGPA        = 8.2;
                b.totalCreditsEarned = 96;
            }
            return b;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenResultsController.getResultsBundle',
                'Unable to load your results.', e);
            return null;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<SubjectGradeDTO> getSemesterDetail(String semesterId) {
        try {
            KenAuraExceptionHelper.rejectIf(String.isBlank(semesterId), 'Semester id is required.');
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId == null) return seedGrades(semesterId);
            // Aggregate Assessment_Component__c by Subject__c → SubjectGradeDTO
            List<SubjectGradeDTO> out = new List<SubjectGradeDTO>();
            for (AggregateResult ar : [
                SELECT Subject__c sub, SUM(Obtained_Marks__c) obt, SUM(Max_Marks__c) maxx
                FROM Assessment_Component__c
                WHERE Student__c = :contactId AND Max_Marks__c > 0
                WITH USER_MODE
                GROUP BY Subject__c
                ORDER BY Subject__c
            ]) {
                Decimal o = (Decimal) ar.get('obt');
                Decimal m = (Decimal) ar.get('maxx');
                Decimal pct = (m != null && m > 0 && o != null) ? (o / m * 100) : 0;
                SubjectGradeDTO g = new SubjectGradeDTO();
                g.id      = String.valueOf(ar.get('sub'));
                g.subject = String.valueOf(ar.get('sub'));
                g.code    = '';
                g.marks   = pct.setScale(0);
                g.grade   = pct >= 85 ? 'A' : pct >= 75 ? 'A-' : pct >= 65 ? 'B+' : pct >= 55 ? 'B' : 'C';
                g.credits = 4;
                out.add(g);
            }
            if (out.isEmpty()) return seedGrades(semesterId);
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenResultsController.getSemesterDetail',
                'Unable to load semester.', e);
            return null;
        }
    }

    private static List<SemesterResultDTO> seedSemesters() {
        List<SemesterResultDTO> out = new List<SemesterResultDTO>();
        out.add(sem('SEM1', 'Semester 1', 7.8, 22, 'Completed'));
        out.add(sem('SEM2', 'Semester 2', 8.0, 22, 'Completed'));
        out.add(sem('SEM3', 'Semester 3', 8.1, 24, 'Completed'));
        out.add(sem('SEM4', 'Semester 4', 8.4, 24, 'Completed'));
        out.add(sem('SEM5', 'Semester 5', 8.3, 22, 'Completed'));
        out.add(sem('SEM6', 'Semester 6', 8.2, 18, 'In progress'));
        return out;
    }

    private static List<SubjectGradeDTO> seedGrades(String semesterId) {
        List<SubjectGradeDTO> out = new List<SubjectGradeDTO>();
        out.add(grade('G001', 'Data Structures',  'CS301', 'A', 88, 4));
        out.add(grade('G002', 'Operating Systems','CS302', 'A-',81, 4));
        out.add(grade('G003', 'Mathematics III',  'MA301', 'B+',75, 4));
        out.add(grade('G004', 'Soft Skills',      'SS101', 'A', 90, 2));
        out.add(grade('G005', 'Engineering Physics','PH301','A',86, 4));
        return out;
    }

    private static SemesterResultDTO sem(String id, String label, Decimal gpa, Integer credits, String status) {
        SemesterResultDTO s = new SemesterResultDTO();
        s.id = id; s.label = label; s.gpa = gpa; s.creditsEarned = credits; s.status = status;
        return s;
    }

    private static SubjectGradeDTO grade(String id, String subj, String code, String gr, Decimal marks, Integer credits) {
        SubjectGradeDTO g = new SubjectGradeDTO();
        g.id = id; g.subject = subj; g.code = code; g.grade = gr; g.marks = marks; g.credits = credits;
        return g;
    }
}