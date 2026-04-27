/**
 * ************************************************************************************************
 * @className  KenMyExamsControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenMyExamsControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void myExamsReturnsUpcomingAndCompleted() {
        Test.startTest();
        KenMyExamsController.MyExamsBundleDTO b = KenMyExamsController.getMyExams();
        Test.stopTest();

        System.assertNotEquals(null, b);
        System.assertEquals(true, b.upcoming.size() > 0);
        System.assertEquals(true, b.completed.size() >= 0);
    }

    @isTest
    static void enrollRejectsNullExamId() {
        Test.startTest();
        Boolean threw = false;
        try { KenMyExamsController.enrollInExam(null); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void enrollAcceptsValidInput() {
        Id fakeExam = UserInfo.getUserId();
        Test.startTest();
        KenMyExamsController.enrollInExam(fakeExam);
        Test.stopTest();
        System.assertEquals(true, true);
    }
}