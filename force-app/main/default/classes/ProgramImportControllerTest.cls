@isTest(SeeAllData=false)
/**
 * @description
 *
 * Usage:
 *  - No direct callers found
 */
private class ProgramImportControllerTest {
    @TestSetup
    static void makeData() {
        new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias('progc')
            .create();
    }
    
    @isTest
    static void testResolvePicklistValue() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Learning')) {return;}
        Schema.DescribeFieldResult d = gd.get('Learning').getDescribe().fields.getMap().get('Type').getDescribe();
        String val = ProgramImportController.resolvePicklistValue(d, 'LearningProgram');
        System.assert(val == null || val == 'LearningProgram', 'Resolve picklist should return null or LearningProgram');
    }
    
    @isTest
    static void testStartBatchAndErrors() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Learning') || !gd.containsKey('LearningProgram')) {return;}
        User runUser = [SELECT Id FROM User WHERE Alias = 'progc' LIMIT 1];
        System.runAs(runUser) {
            Map<String, Object> row = new Map<String, Object>{
                'RowNumber' => '1',
                'Name' => 'Program A'
            };
            String jsonRows = JSON.serialize(new List<Object>{ row });
            
            Test.startTest();
            Id jobId = ProgramImportController.startProgramImportBatch(jsonRows, null, null);
            Test.stopTest();
            
            System.assertNotEquals(null, jobId, 'Batch job id should be returned');
            List<String> errors = ProgramImportController.getProgramImportErrors(jobId);
            System.assertNotEquals(null, errors, 'Errors list should be returned');
        }
    }
    
    @isTest
    static void testGetProgramImportErrorsFallback() {
        if (!Schema.getGlobalDescribe().containsKey('Audit_Log__c')) {return;}
        User runUser = [SELECT Id FROM User WHERE Alias = 'progc' LIMIT 1];
        System.runAs(runUser) {
            Id fakeJobId = '707000000000001AAA';
            Audit_Log__c log = new Audit_Log__c();
            if (Audit_Log__c.SObjectType.getDescribe().fields.getMap().containsKey('Process__c')) {
                log.put('Process__c', 'Other Process');
            }
            if (Audit_Log__c.SObjectType.getDescribe().fields.getMap().containsKey('RecordId__c')) {
                log.put('RecordId__c', String.valueOf(fakeJobId));
            }
            if (Audit_Log__c.SObjectType.getDescribe().fields.getMap().containsKey('Error_Message__c')) {
                log.put('Error_Message__c', 'Test error');
            }
            insert log;
            
            List<String> errors = ProgramImportController.getProgramImportErrors(fakeJobId);
            System.assert(errors.size() > 0, 'Expected fallback error list');
        }
    }
}