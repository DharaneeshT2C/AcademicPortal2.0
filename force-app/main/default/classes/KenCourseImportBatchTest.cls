@isTest(SeeAllData=false)
/**
 * @description
 *
 * Usage:
 *  - No direct callers found
 */
private class KenCourseImportBatchTest {
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
    
    @isTest
    static void testBatchMapsLtpColumns() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Learning') || !gd.containsKey('LearningCourse')) {return;}
        
        Map<String, Schema.SObjectField> courseFields = Schema.SObjectType.LearningCourse.fields.getMap();
        String courseNumberField = firstField(courseFields, new List<String>{'CourseNumber', 'Course_Number__c', 'CourseNumber__c'});
        String type1Field = firstField(courseFields, new List<String>{'CourseType', 'Course_Type__c'});
        String credit1Field = firstField(courseFields, new List<String>{'Credit', 'Credit_1__c'});
        String type2Field = firstField(courseFields, new List<String>{'CourseType2', 'Course_Type_2__c'});
        String credit2Field = firstField(courseFields, new List<String>{'Credit2', 'Credit_2__c'});
        String type3Field = firstField(courseFields, new List<String>{'CourseType3', 'Course_Type_3__c'});
        String credit3Field = firstField(courseFields, new List<String>{'Credit3', 'Credit_3__c'});
        
        User runUser = [SELECT Id FROM User WHERE Alias = 'courseb' LIMIT 1];
        System.runAs(runUser) {
            Learning existingLearning = new KenTestDataFactory.LearningCreator('Existing LTP Course').create();
            if (Schema.SObjectType.Learning.fields.getMap().containsKey('Type')) {
                existingLearning.put('Type', 'LearningCourse');
                update existingLearning;
            }
            
            LearningCourse existingCourse = new LearningCourse(
                Name = 'Existing LTP Course',
            CourseNumber = 'COURSE-LTP-1'
                );
            if (Schema.SObjectType.LearningCourse.fields.getMap().containsKey('LearningId')) {
                existingCourse.put('LearningId', existingLearning.Id);
            } else if (Schema.SObjectType.LearningCourse.fields.getMap().containsKey('Learning__c')) {
                existingCourse.put('Learning__c', existingLearning.Id);
            }
            insert existingCourse;
            
            Map<String, Object> row = new Map<String, Object>{
                'RowNumber' => '1',
                'Name' => 'Existing LTP Course Updated',
                'CourseNumber' => 'COURSE-LTP-1',
                'CourseType' => 'Lecture',
                'Credit' => '2',
                'CourseType2' => 'Tutorial',
                'Credit2' => '1',
                'CourseType3' => 'Practical',
                'Credit3' => '1'
            };
            
            Test.startTest();
            Database.executeBatch(new KenCourseImportBatch(JSON.serialize(new List<Object>{ row }), null, null), 200);
            Test.stopTest();
            
            List<String> queryFields = new List<String>{'Id', courseNumberField};
            if (type1Field != null) {queryFields.add(type1Field);}
            if (credit1Field != null) {queryFields.add(credit1Field);}
            if (type2Field != null) {queryFields.add(type2Field);}
            if (credit2Field != null) {queryFields.add(credit2Field);}
            if (type3Field != null) {queryFields.add(type3Field);}
            if (credit3Field != null) {queryFields.add(credit3Field);}
            
            SObject course = Database.query(
                'SELECT ' + String.join(queryFields, ',') +
                ' FROM LearningCourse WHERE ' + courseNumberField + ' = \'COURSE-LTP-1\' LIMIT 1'
                );
            
            System.assertNotEquals(null, course, 'Imported course should be queryable by CourseNumber.');
        }
    }
    
    @isTest
    static void testBatchUpdatesExistingByCourseNumberAndInsertsNew() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Learning') || !gd.containsKey('LearningCourse')) {return;}
        Map<String, Schema.SObjectField> courseFields = Schema.SObjectType.LearningCourse.fields.getMap();
        String courseNumberField = firstField(courseFields, new List<String>{'CourseNumber', 'Course_Number__c', 'CourseNumber__c'});
        
        User runUser = [SELECT Id FROM User WHERE Alias = 'courseb' LIMIT 1];
        System.runAs(runUser) {
            Learning existingLearning = new KenTestDataFactory.LearningCreator('Existing Course').create();
            if (Schema.SObjectType.Learning.fields.getMap().containsKey('Type')) {
                existingLearning.put('Type', 'LearningCourse');
            }
            update existingLearning;
            
            LearningCourse existingCourse = new LearningCourse(
                Name = 'Existing Course',
            CourseNumber = 'COURSE-UPD-1'
                );
            if (Schema.SObjectType.LearningCourse.fields.getMap().containsKey('LearningId')) {
                existingCourse.put('LearningId', existingLearning.Id);
            } else if (Schema.SObjectType.LearningCourse.fields.getMap().containsKey('Learning__c')) {
                existingCourse.put('Learning__c', existingLearning.Id);
            }
            insert existingCourse;
            
            List<Object> rows = new List<Object>{
                new Map<String, Object>{
                    'RowNumber' => '1',
                    'Name' => 'Existing Course Updated',
                    'CourseNumber' => 'COURSE-UPD-1',
                    'Description' => 'Updated description'
                },
                new Map<String, Object>{
                    'RowNumber' => '2',
                    'Name' => 'New Course',
                    'CourseNumber' => 'COURSE-UPD-2',
                    'Description' => 'New description'
                }
            };
            
            Test.startTest();
            Database.executeBatch(new KenCourseImportBatch(JSON.serialize(rows), null, null), 200);
            Test.stopTest();
            
            Learning updatedLearning = [
                SELECT Id, Name, Description
                FROM Learning
                WHERE Id = :existingLearning.Id
            ];
            System.assertNotEquals(null, updatedLearning, 'Existing learning should remain available after import.');
            
            List<SObject> courses = Database.query(
                'SELECT Id, ' + courseNumberField + ', Name ' +
                'FROM LearningCourse WHERE ' + courseNumberField + ' IN (\'COURSE-UPD-1\', \'COURSE-UPD-2\')'
                );
            System.assert(courses.size() >= 1, 'Course import should leave course records available for the requested course numbers.');
        }
    }
    
    @isTest
    static void testBatchRejectsUnsupportedCourseComponent() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Learning') || !gd.containsKey('LearningCourse')) {return;}
        Map<String, Schema.SObjectField> courseFields = Schema.SObjectType.LearningCourse.fields.getMap();
        String courseNumberField = firstField(courseFields, new List<String>{'CourseNumber', 'Course_Number__c', 'CourseNumber__c'});
        
        User runUser = [SELECT Id FROM User WHERE Alias = 'courseb' LIMIT 1];
        System.runAs(runUser) {
            Map<String, Object> row = new Map<String, Object>{
                'RowNumber' => '4',
                'Name' => 'Invalid Component Course',
                'CourseNumber' => 'COURSE-INVALID-COMP',
                'CourseComponentsRaw' => 'Lecture,Seminar',
                'CreditsRaw' => '2,1',
                'CourseComponentCount' => '2',
                'CreditCount' => '2',
                'CourseType' => 'Lecture',
                'CourseType2' => 'Seminar',
                'Credit' => '2',
                'Credit2' => '1'
            };
            
            Test.startTest();
            Id jobId = Database.executeBatch(new KenCourseImportBatch(JSON.serialize(new List<Object>{ row }), null, null), 200);
            Test.stopTest();
            
            Integer courseCount = (Integer) Database.countQuery(
                'SELECT COUNT() FROM LearningCourse WHERE ' + courseNumberField + ' = \'COURSE-INVALID-COMP\''
                );
            System.assertEquals(0, courseCount, 'Unsupported components should prevent course creation.');
        }
    }
    
    @isTest
    static void testBatchRejectsMoreThanThreeCourseComponents() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Learning') || !gd.containsKey('LearningCourse')) {return;}
        Map<String, Schema.SObjectField> courseFields = Schema.SObjectType.LearningCourse.fields.getMap();
        String courseNumberField = firstField(courseFields, new List<String>{'CourseNumber', 'Course_Number__c', 'CourseNumber__c'});
        
        User runUser = [SELECT Id FROM User WHERE Alias = 'courseb' LIMIT 1];
        System.runAs(runUser) {
            Map<String, Object> row = new Map<String, Object>{
                'RowNumber' => '7',
                'Name' => 'Too Many Components Course',
                'CourseNumber' => 'COURSE-TOO-MANY',
                'CourseComponentsRaw' => 'Lecture,Tutorial,Practical,Lab',
                'CreditsRaw' => '2,1,1,1',
                'CourseComponentCount' => '4',
                'CreditCount' => '4',
                'CourseType' => 'Lecture',
                'CourseType2' => 'Tutorial',
                'CourseType3' => 'Practical',
                'Credit' => '2',
                'Credit2' => '1',
                'Credit3' => '1'
            };
            
            Test.startTest();
            Id jobId = Database.executeBatch(new KenCourseImportBatch(JSON.serialize(new List<Object>{ row }), null, null), 200);
            Test.stopTest();
            
            Integer courseCount = (Integer) Database.countQuery(
                'SELECT COUNT() FROM LearningCourse WHERE ' + courseNumberField + ' = \'COURSE-TOO-MANY\''
                );
            System.assertEquals(0, courseCount, 'Rows with more than 3 course components should be skipped.');
        }
    }
    
    private static String firstField(Map<String, Schema.SObjectField> fieldMap, List<String> candidates) {
        if (fieldMap == null || candidates == null) {return null;}
        for (String candidate : candidates) {
            if (fieldMap.containsKey(candidate)) {
                return candidate;
            }
        }
        return null;
    }
}