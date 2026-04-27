/**
 * ************************************************************************************************
 * @className  KenMarksBreakdownControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenMarksBreakdownControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void breakdownReturnsComponents() {
        Id fakeSubject = UserInfo.getUserId();
        Test.startTest();
        KenMarksBreakdownController.SubjectBreakdownDTO b = KenMarksBreakdownController.getBreakdown(fakeSubject);
        Test.stopTest();

        System.assertNotEquals(null, b);
        System.assertEquals(true, b.components.size() > 0);
        System.assertEquals(true, b.totalObtained <= b.totalMax);
    }

    @isTest
    static void breakdownRejectsNullId() {
        Test.startTest();
        Boolean threw = false;
        try { KenMarksBreakdownController.getBreakdown(null); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void allBreakdownsReturnsList() {
        Test.startTest();
        List<KenMarksBreakdownController.SubjectBreakdownDTO> all = KenMarksBreakdownController.getAllBreakdowns();
        Test.stopTest();

        System.assertNotEquals(null, all);
        System.assertEquals(true, all.size() > 0);
    }
}