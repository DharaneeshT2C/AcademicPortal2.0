@isTest(SeeAllData=false)
/**
 * @description
 *
 * Usage:
 *  - No direct callers found
 */
private class CourseImportBatchTest {
    @TestSetup
    static void makeData() {
        new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias('courseb')
            .create();
    }
    
    @isTest
    static void testBatchRuns() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Learning') || !gd.containsKey('LearningCourse')) {return;}
        User runUser = [SELECT Id FROM User WHERE Alias = 'courseb' LIMIT 1];
        System.runAs(runUser) {
            Map<String, Object> row = new Map<String, Object>{
                'RowNumber' => '1',
                'Name' => 'Course Batch',
                'CourseNumber' => 'COURSE-BATCH-1'
            };
            String jsonRows  = JSON.serialize(new List<Object>{ row });
            
            Test.startTest();
            Id jobId = Database.executeBatch(new KenCourseImportBatch(jsonRows, null,null), 200);
            Test.stopTest();
            
            System.assertNotEquals(null, jobId, 'Batch job id should be returned');
        }
    }
}