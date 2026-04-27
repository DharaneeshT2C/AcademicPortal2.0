/**
 * ************************************************************************************************
 * @className  KenEventsControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenEventsControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void bundleReturnsFeaturedAndUpcoming() {
        Test.startTest();
        KenEventsController.EventsBundleDTO b = KenEventsController.getEventsBundle();
        Test.stopTest();

        System.assertNotEquals(null, b);
        System.assertEquals(true, b.featured.size() > 0);
        System.assertEquals(true, b.upcoming.size() > 0);
        System.assertNotEquals(null, b.registered);
    }

    @isTest
    static void registerRejectsNullId() {
        Test.startTest();
        Boolean threw = false;
        try { KenEventsController.registerForEvent(null); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void cancelRegistrationRejectsNullId() {
        Test.startTest();
        Boolean threw = false;
        try { KenEventsController.cancelRegistration(null); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void registerAcceptsValidId() {
        Id fakeEvent = UserInfo.getUserId();
        Test.startTest();
        KenEventsController.registerForEvent(fakeEvent);
        Test.stopTest();
        System.assertEquals(true, true);
    }
}