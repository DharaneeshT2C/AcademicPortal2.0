@isTest(SeeAllData=false)
/**
 * @description
 *
 * Usage:
 *  - No direct callers found
 */
private class AccountImportControllerTest {
    @TestSetup
    static void makeData() {
        new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias('acctimp')
            .create();
    }
    
    @isTest
    static void testStartAccountImportBatch() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'acctimp' LIMIT 1];
        System.runAs(runUser) {
            List<RecordType> rts = [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = 'Account' AND Name = 'Department'
                LIMIT 1
            ];
            if (rts.isEmpty()) {return;}
            
            Map<String, Object> row = new Map<String, Object>{
                'RowNumber' => '1',
                'Name' => 'Test Department'
            };
            String jsonRows = JSON.serialize(new List<Object>{ row });
            
            Test.startTest();
            Id jobId = KenAccountImportController.startAccountImportBatch(jsonRows, 'Department', null);
            Test.stopTest();
            
            System.assertNotEquals(null, jobId, 'Batch job id should be returned');
            List<String> errors = KenAccountImportController.getAccountImportErrors(jobId, 'Department Import');
            System.assertNotEquals(null, errors, 'Errors list should be returned');
        }
    }
    
    @isTest
    static void testGetAccountImportErrorsFallback() {
        if (!Schema.getGlobalDescribe().containsKey('Audit_Log__c')) {return;}
        User runUser = [SELECT Id FROM User WHERE Alias = 'acctimp' LIMIT 1];
        System.runAs(runUser) {
            Id fakeJobId = '707000000000002AAA';
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
            
            List<String> errors = KenAccountImportController.getAccountImportErrors(fakeJobId, 'Account Import');
            System.assert(errors.size() > 0, 'Expected fallback error list');
        }
    }
    
    @isTest
    static void testGetAccountImportErrorsNullJob() {
        List<String> errors = KenAccountImportController.getAccountImportErrors(null, 'Account Import');
        System.assertEquals(0, errors.size(), 'Expected empty list for null job id');
    }
}