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
public without sharing class KenResultsController {

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
            b.semesters            = new List<SemesterResultDTO>();
            b.totalCreditsRequired = 160;
            // Compute current CGPA from real Assessment_Component__c if present
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId != null) {
                Decimal sumPct = 0; Integer cnt = 0;
                for (AggregateResult ar : [
                    SELECT Subject__c sub, AVG(Obtained_Marks__c) avgObt, AVG(Max_Marks__c) avgMax
                    FROM Assessment_Component__c
                    WHERE Student__c = :contactId AND Max_Marks__c > 0
                    WITH SECURITY_ENFORCED
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
                    b.currentCGPA        = null;
                    b.totalCreditsEarned = 0;
                }
            } else {
                b.currentCGPA        = null;
                b.totalCreditsEarned = 0;
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
            if (contactId == null) return new List<SubjectGradeDTO>();
            // Aggregate Assessment_Component__c by Subject__c → SubjectGradeDTO
            List<SubjectGradeDTO> out = new List<SubjectGradeDTO>();
            for (AggregateResult ar : [
                SELECT Subject__c sub, SUM(Obtained_Marks__c) obt, SUM(Max_Marks__c) maxx
                FROM Assessment_Component__c
                WHERE Student__c = :contactId AND Max_Marks__c > 0
                WITH SECURITY_ENFORCED
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
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenResultsController.getSemesterDetail',
                'Unable to load semester.', e);
            return null;
        }
    }

}