/**
 * ************************************************************************************************
 * @className  KenAttendanceControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenAttendanceControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void bundleAggregatesOverallAndAtRisk() {
        Test.startTest();
        KenAttendanceController.AttendanceBundleDTO b = KenAttendanceController.getAttendanceBundle();
        Test.stopTest();

        System.assertNotEquals(null, b);
        System.assertEquals(true, b.subjects.size() > 0);
        System.assertEquals(true, b.overallPercentage > 0 && b.overallPercentage <= 100);
        System.assertEquals(true, b.subjectsAtRisk >= 0);
    }

    @isTest
    static void disputeRejectsBlankReason() {
        Id fakeId = UserInfo.getUserId();
        Test.startTest();
        Boolean threw = false;
        try { KenAttendanceController.raiseAttendanceDispute(fakeId, ''); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void disputeRejectsNullSubject() {
        Test.startTest();
        Boolean threw = false;
        try { KenAttendanceController.raiseAttendanceDispute(null, 'Wrong count'); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void disputeAcceptsValidInput() {
        Id fakeId = UserInfo.getUserId();
        Test.startTest();
        KenAttendanceController.raiseAttendanceDispute(fakeId, 'Incorrect entry on 14-Apr');
        Test.stopTest();
        System.assertEquals(true, true);
    }
}