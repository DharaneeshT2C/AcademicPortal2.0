@isTest(SeeAllData=false)
/**
 * @description
 *
 * Usage:
 *  - No direct callers found
 */
private class ImportUtilsTest {
    @TestSetup
    static void makeData() {
        new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias('imputl')
            .create();
        new KenTestDataFactory.AccountCreator('Test Account').create();
    }
    
    @isTest
    static void testGetAllAccountsAndBatchStatus() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'imputl' LIMIT 1];
        System.runAs(runUser) {
            List<KenImportUtils.IdName> allAccounts = KenImportUtils.getAllAccounts();
            System.assertNotEquals(null, allAccounts, 'All accounts should be returned');
            
            Test.startTest();
            Id jobId = Database.executeBatch(new UserImportBatch('[]', 'Faculty', null), 200);
            Test.stopTest();
            
            KenImportUtils.BatchStatusInfo info = KenImportUtils.getBatchStatus(jobId);
            System.assertNotEquals(null, info, 'Batch status info should be returned');
        }
    }
    
    @isTest
    static void testConvertValue() {
        Schema.DescribeFieldResult d = Account.Name.getDescribe();
        Object val = KenImportUtils.convertValue('Test', d);
        System.assertEquals('Test', String.valueOf(val));
    }
}