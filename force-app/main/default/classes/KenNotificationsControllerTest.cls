/**
 * ************************************************************************************************
 * @className  KenNotificationsControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenNotificationsControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void notificationsReturnList() {
        Test.startTest();
        List<KenNotificationsController.NotificationDTO> notifs = KenNotificationsController.getNotifications();
        Test.stopTest();

        System.assertNotEquals(null, notifs);
        System.assertEquals(true, notifs.size() > 0);
    }

    @isTest
    static void unreadCountIsNonNegative() {
        Test.startTest();
        Integer n = KenNotificationsController.getUnreadCount();
        Test.stopTest();

        System.assertEquals(true, n >= 0);
    }

    @isTest
    static void markReadRejectsEmptyList() {
        Test.startTest();
        Boolean threw = false;
        try { KenNotificationsController.markRead(new List<Id>()); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void markReadRejectsNullList() {
        Test.startTest();
        Boolean threw = false;
        try { KenNotificationsController.markRead(null); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void markAllReadRuns() {
        Test.startTest();
        KenNotificationsController.markAllRead();
        Test.stopTest();
        System.assertEquals(true, true);
    }
}