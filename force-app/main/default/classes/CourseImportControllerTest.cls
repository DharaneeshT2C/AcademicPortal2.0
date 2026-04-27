@isTest(SeeAllData=false)
/**
 * @description
 *
 * Usage:
 *  - No direct callers found
 */
private class CourseImportControllerTest {
    @TestSetup
    static void makeData() {
        new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias('coursec')
            .create();
    }
    
    @isTest
    static void testStartBatchAndErrors() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Learning') || !gd.containsKey('LearningCourse')) {return;}
        User runUser = [SELECT Id FROM User WHERE Alias = 'coursec' LIMIT 1];
        System.runAs(runUser) {
            Map<String, Object> row = new Map<String, Object>{
                'RowNumber' => '1',
                'Name' => 'Course A',
                'CourseNumber' => 'COURSE-001'
            };
            String jsonRows = JSON.serialize(new List<Object>{ row });
            
            Test.startTest();
            Id jobId = KenCourseImportController.startCourseImportBatch(jsonRows, null,null);
            Test.stopTest();
            
            System.assertNotEquals(null, jobId, 'Batch job id should be returned');
            List<String> errors = KenCourseImportController.getCourseImportErrors(jobId);
            System.assertNotEquals(null, errors, 'Errors list should be returned');
        }
    }
    
}