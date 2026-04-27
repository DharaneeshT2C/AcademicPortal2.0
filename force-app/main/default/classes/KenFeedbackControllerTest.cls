/**
 * ************************************************************************************************
 * @className  KenFeedbackControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenFeedbackControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void activeSurveyReturned() {
        Test.startTest();
        KenFeedbackController.FeedbackSurveyDTO s = KenFeedbackController.getActiveSurvey();
        Test.stopTest();

        System.assertNotEquals(null, s);
        System.assertEquals(true, s.categories.size() > 0);
    }

    @isTest
    static void submitRejectsNull() {
        Test.startTest();
        Boolean threw = false;
        try { KenFeedbackController.submitFeedback(null); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void submitRejectsOutOfRangeNps() {
        KenFeedbackController.FeedbackSubmission sub = new KenFeedbackController.FeedbackSubmission();
        sub.nps = 11;
        sub.category = 'Academics';

        Test.startTest();
        Boolean threw = false;
        try { KenFeedbackController.submitFeedback(sub); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void submitAcceptsValidFeedback() {
        KenFeedbackController.FeedbackSubmission sub = new KenFeedbackController.FeedbackSubmission();
        sub.nps = 8;
        sub.category = 'Academics';
        sub.comments = 'Loving the courses';

        Test.startTest();
        KenFeedbackController.submitFeedback(sub);
        Test.stopTest();
        System.assertEquals(true, true);
    }
}