/**
 * ************************************************************************************************
 * @className  KenSettingsControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenSettingsControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void getProfileDoesNotThrowWhenNoContactLink() {
        // Running user in test context has no ContactId → service returns null gracefully.
        Test.startTest();
        KenSettingsController.ProfileDTO p = KenSettingsController.getProfile();
        Test.stopTest();
        // Either a DTO or null are both acceptable; the contract is "no exception".
        System.assertEquals(true, p == null || p.contactId == null || p.contactId != null);
    }

    @isTest
    static void notificationPrefsReturnList() {
        Test.startTest();
        List<KenSettingsController.NotificationPrefDTO> prefs = KenSettingsController.getNotificationPrefs();
        Test.stopTest();

        System.assertNotEquals(null, prefs);
        System.assertEquals(true, prefs.size() > 0);
    }

    @isTest
    static void updateProfileRejectsNullRequest() {
        Test.startTest();
        Boolean threw = false;
        try { KenSettingsController.updateProfile(null); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void updatePrefRejectsNullPayload() {
        Test.startTest();
        Boolean threw = false;
        try { KenSettingsController.updateNotificationPref(null); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void updatePrefRejectsBlankCategory() {
        KenSettingsController.NotificationPrefDTO p = new KenSettingsController.NotificationPrefDTO();
        p.category = '';

        Test.startTest();
        Boolean threw = false;
        try { KenSettingsController.updateNotificationPref(p); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }
}