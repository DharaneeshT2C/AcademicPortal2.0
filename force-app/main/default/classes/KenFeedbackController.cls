/**
 * ************************************************************************************************
 * @className  KenFeedbackController
 *
 * @description
 *  Backs `my/feedbackPage` — NPS survey + open-text feedback. Also used by the
 *  Home dashboard mood check (which calls `KenHomeDashboardController.recordMood`
 *  — this controller covers the larger written survey).
 *
 *  TODO[SOBJECT]: Wire to `Feedback_Submission__c` (Student__c, NPS__c,
 *                 Category__c, Comments__c, Submitted_On__c).
 * ************************************************************************************************
 */
public without sharing class KenFeedbackController {

    public class FeedbackSurveyDTO {
        @AuraEnabled public String       id;
        @AuraEnabled public String       title;
        @AuraEnabled public String       introText;
        @AuraEnabled public List<String> categories;
    }

    public class FeedbackSubmission {
        @AuraEnabled public String surveyId;
        @AuraEnabled public Integer nps;         // 0–10
        @AuraEnabled public String  category;
        @AuraEnabled public String  comments;
    }

    @AuraEnabled(cacheable=true)
    public static FeedbackSurveyDTO getActiveSurvey() {
        try {
            FeedbackSurveyDTO s = new FeedbackSurveyDTO();
            s.id         = 'SURVEY-Q1-2026';
            s.title      = 'Help us improve the portal';
            s.introText  = 'How likely are you to recommend the student portal to a friend?';
            s.categories = new List<String>{ 'Academics', 'Campus Life', 'Fees', 'Support', 'Other' };
            return s;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenFeedbackController.getActiveSurvey',
                'Unable to load survey.', e);
            return null;
        }
    }

    @AuraEnabled
    public static void submitFeedback(FeedbackSubmission s) {
        try {
            KenAuraExceptionHelper.rejectIf(s == null, 'Submission is empty.');
            KenAuraExceptionHelper.rejectIf(s.nps == null || s.nps < 0 || s.nps > 10, 'NPS must be 0-10.');
            Id studentId = KenRunningStudentHelper.optionalContactId();
            // Idempotency: one submission per student per survey.
            if (studentId != null && String.isNotBlank(s.surveyId)) {
                List<Feedback_Submission__c> dupes = [
                    SELECT Id FROM Feedback_Submission__c
                    WHERE Student__c = :studentId AND Survey_Id__c = :s.surveyId
                    WITH SECURITY_ENFORCED LIMIT 1
                ];
                if (!dupes.isEmpty()) return;
            }
            KenCrudFlsHelper.assertCreateable(Feedback_Submission__c.SObjectType);
            insert new Feedback_Submission__c(
                Student__c   = studentId,
                Survey_Id__c = s.surveyId,
                NPS__c       = s.nps,
                Category__c  = s.category,
                Comments__c  = s.comments == null ? null : s.comments.left(1000)
            );
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenFeedbackController.submitFeedback',
                'Could not submit feedback.', e);
        }
    }
}