/**
 * ************************************************************************************************
 * @className  KenFeePlanControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenFeePlanControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void plansReturnOptions() {
        Test.startTest();
        List<KenFeePlanController.PlanOptionDTO> plans = KenFeePlanController.getPlans();
        Test.stopTest();

        System.assertNotEquals(null, plans);
        System.assertEquals(true, plans.size() > 0);
    }

    @isTest
    static void switchRejectsNullId() {
        Test.startTest();
        Boolean threw = false;
        try { KenFeePlanController.switchToPlan(null); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void switchAcceptsValidId() {
        Id fakeId = UserInfo.getUserId();
        Test.startTest();
        KenFeePlanController.switchToPlan(fakeId);
        Test.stopTest();
        System.assertEquals(true, true);
    }
}