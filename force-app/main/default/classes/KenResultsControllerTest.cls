/**
 * ************************************************************************************************
 * @className  KenResultsControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenResultsControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void bundleReturnsSemestersAndCGPA() {
        Test.startTest();
        KenResultsController.ResultsBundleDTO b = KenResultsController.getResultsBundle();
        Test.stopTest();

        System.assertNotEquals(null, b);
        System.assertEquals(true, b.semesters.size() > 0);
        System.assertEquals(true, b.currentCGPA > 0);
        System.assertEquals(true, b.totalCreditsEarned <= b.totalCreditsRequired);
    }

    @isTest
    static void semesterDetailRejectsBlankId() {
        Test.startTest();
        Boolean threw = false;
        try { KenResultsController.getSemesterDetail(''); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void semesterDetailReturnsRows() {
        Test.startTest();
        List<KenResultsController.SubjectGradeDTO> rows = KenResultsController.getSemesterDetail('SEM1');
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertEquals(true, rows.size() > 0);
    }
}