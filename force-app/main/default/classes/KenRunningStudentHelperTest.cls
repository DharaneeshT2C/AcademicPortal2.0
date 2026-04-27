/**
 * ************************************************************************************************
 * @className  KenRunningStudentHelperTest
 * ************************************************************************************************
 */
@isTest
private class KenRunningStudentHelperTest {

    @isTest
    static void getContactReturnsNullForUnlinkedUser() {
        Test.startTest();
        Contact c = KenRunningStudentHelper.getContact();
        Test.stopTest();
        // Admin running user in test context has no linked Contact.
        System.assertEquals(null, c);
    }

    @isTest
    static void optionalContactIdIsNullWhenUnlinked() {
        KenRunningStudentHelper.resetCacheForTest();
        Test.startTest();
        Id id = KenRunningStudentHelper.optionalContactId();
        Test.stopTest();
        System.assertEquals(null, id);
    }

    @isTest
    static void requireContactIdThrowsWhenUnlinked() {
        KenRunningStudentHelper.resetCacheForTest();
        Test.startTest();
        Boolean threw = false;
        try { KenRunningStudentHelper.requireContactId(); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();
        System.assertEquals(true, threw);
    }
}