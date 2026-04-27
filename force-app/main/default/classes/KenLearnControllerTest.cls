/**
 * ************************************************************************************************
 * @className  KenLearnControllerTest
 *
 * @description
 *  Locks in the `KenLearnController` @AuraEnabled contract.
 * ************************************************************************************************
 */
@isTest
private class KenLearnControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder()
            .setFirstName('Arjun')
            .setLastName('R')
            .create();
    }

    @isTest
    static void learnBundleReturnsCoursesAndCredits() {
        Test.startTest();
        KenLearnController.LearnBundleDTO b = KenLearnController.getLearnBundle();
        Test.stopTest();

        System.assertNotEquals(null, b, 'Bundle must not be null');
        System.assertNotEquals(null, b.enrolledCourses, 'Enrolled courses must not be null');
        System.assertEquals(true, b.enrolledCourses.size() > 0, 'At least one enrolled course');
        System.assertEquals(true, b.totalCreditsEnrolled > 0, 'Credits are positive');
    }

    @isTest
    static void courseDetailReturnsMatchingRow() {
        Test.startTest();
        KenLearnController.LearnBundleDTO b = KenLearnController.getLearnBundle();
        KenLearnController.CourseDTO c = KenLearnController.getCourseDetail(b.enrolledCourses[0].id);
        Test.stopTest();

        System.assertNotEquals(null, c);
        System.assertEquals(b.enrolledCourses[0].name, c.name);
    }

    @isTest
    static void courseDetailRejectsNullId() {
        Test.startTest();
        Boolean threw = false;
        try { KenLearnController.getCourseDetail(null); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw, 'Null course id must be rejected');
    }
}