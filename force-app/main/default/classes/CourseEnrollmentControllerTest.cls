@isTest(SeeAllData=false)
/**
 * @description
 *
 * Usage:
 *  - No direct callers found
 */
private class CourseEnrollmentControllerTest {
    @TestSetup
    static void makeData() {
        new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias('corsen')
            .create();
    }
    
    @isTest
    static void testGetCoursesForSemesterNull() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'corsen' LIMIT 1];
        System.runAs(runUser) {
            List<KenCourseEnrollmentController.CourseDTO> result =
                KenCourseEnrollmentController.getCoursesForSemester(null, null);
            System.assertEquals(0, result.size(), 'Expected empty list for null semester');
        }
    }
    
    @isTest
    static void testGetAcademicSessionsForUserNoContact() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'corsen' LIMIT 1];
        System.runAs(runUser) {
            List<KenCourseEnrollmentController.AcademicSessionDTO> result =
                KenCourseEnrollmentController.getAcademicSessionsForUser();
            System.assertEquals(0, result.size(), 'Expected empty list when user has no contact');
        }
    }
    
    @isTest
    static void testGetProgramPathNoContact() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'corsen' LIMIT 1];
        System.runAs(runUser) {
            List<KenCourseEnrollmentController.ProgramPathDTO> result =
                KenCourseEnrollmentController.getProgramPath();
            System.assertEquals(0, result.size(), 'Expected empty list when user has no contact');
        }
    }
    
    @isTest
    static void testGetStudentScheduleNoContact() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'corsen' LIMIT 1];
        System.runAs(runUser) {
            List<KenCourseEnrollmentController.ScheduleDTO> result =
                KenCourseEnrollmentController.getStudentSchedule();
            System.assertEquals(0, result.size(), 'Expected empty list when user has no contact');
        }
    }
    
    @isTest
    static void testSubmitEnrollmentRequestNoCourses() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'corsen' LIMIT 1];
        System.runAs(runUser) {
            try {
                KenCourseEnrollmentController.submitEnrollmentRequest(new List<Id>(), null);
                System.assert(false, 'Expected AuraHandledException for empty course list');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('No Course Offerings'), 'Expected no offerings message');
            }
        }
    }
    
    @isTest
    static void testEnrollInPathwayNoContact() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'corsen' LIMIT 1];
        System.runAs(runUser) {
            try {
                KenCourseEnrollmentController.enrollInPathway(null);
                System.assert(false, 'Expected AuraHandledException for user without contact');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('User has no contact'), 'Expected no contact message');
            }
        }
    }
}