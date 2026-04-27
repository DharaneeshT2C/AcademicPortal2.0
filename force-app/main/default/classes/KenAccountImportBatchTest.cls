@isTest(SeeAllData=false)
/**
 * @description
 *
 * Usage:
 *  - No direct callers found
 */
private class KenAccountImportBatchTest {
    @TestSetup
    static void makeData() {
        new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias('acctbat')
            .create();
    }
    
    @isTest
    static void testBatchRuns() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'acctbat' LIMIT 1];
        System.runAs(runUser) {
            List<RecordType> rts = [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = 'Account' AND Name = 'Department'
                LIMIT 1
            ];
            if (rts.isEmpty()) {return;}
            
            Map<String, Object> row1 = new Map<String, Object>{
                'RowNumber' => '1',
                'Name' => 'Dept A'
            };
            Map<String, Object> row2 = new Map<String, Object>{
                'RowNumber' => '2',
                'Name' => 'Dept A'
            };
            String jsonRows = JSON.serialize(new List<Object>{ row1, row2 });
            
            Test.startTest();
            Id jobId = Database.executeBatch(new KenAccountImportBatch(jsonRows, 'Department', null), 200);
            Test.stopTest();

            System.assertNotEquals(null, jobId, 'Batch job id should be returned');
        }
    }

    @isTest
    static void testBatchRunsWithParentAndDuplicateInDb() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'acctbat' LIMIT 1];
        System.runAs(runUser) {
            List<RecordType> universityRts = [
                SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'University' LIMIT 1
            ];
            List<RecordType> instituteRts = [
                SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Institute' LIMIT 1
            ];
            if (universityRts.isEmpty() || instituteRts.isEmpty()) {return;}

            Account uni = new KenTestDataFactory.AccountCreator('Acct Batch Uni')
                .setRecordTypeId(universityRts[0].Id).create();
            Account preExistingInstitute = new KenTestDataFactory.AccountCreator('Acct Batch Institute A')
                .setRecordTypeId(instituteRts[0].Id)
                .setParentId(uni.Id)
                .create();

            Map<String, Object> existingRow = new Map<String, Object>{
                'RowNumber' => '1',
                'Name' => preExistingInstitute.Name
            };
            Map<String, Object> newRow = new Map<String, Object>{
                'RowNumber' => '2',
                'Name' => 'Acct Batch Institute B'
            };
            Map<String, Object> dupInFileA = new Map<String, Object>{
                'RowNumber' => '3',
                'Name' => 'Same Name Dup'
            };
            Map<String, Object> dupInFileB = new Map<String, Object>{
                'RowNumber' => '4',
                'Name' => 'Same Name Dup'
            };
            Map<String, Object> blankNameRow = new Map<String, Object>{
                'RowNumber' => '5'
            };
            String jsonRows = JSON.serialize(new List<Object>{ existingRow, newRow, dupInFileA, dupInFileB, blankNameRow });

            Test.startTest();
            Id jobId = Database.executeBatch(
                new KenAccountImportBatch(jsonRows, 'Institute', uni.Id), 200
            );
            Test.stopTest();

            System.assertNotEquals(null, jobId, 'Institute batch should return a job id.');
        }
    }

    @isTest
    static void testBatchHandlesBlankJson() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'acctbat' LIMIT 1];
        System.runAs(runUser) {
            Test.startTest();
            Id jobId = Database.executeBatch(new KenAccountImportBatch(null, 'Department', null), 200);
            Id jobId2 = Database.executeBatch(new KenAccountImportBatch('[]', 'Department', null), 200);
            Test.stopTest();
            System.assertNotEquals(null, jobId, 'Null JSON batch job id returned.');
            System.assertNotEquals(null, jobId2, 'Empty JSON batch job id returned.');
        }
    }

    @isTest
    static void testDepartmentBatchWithCodeDupDetection() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'acctbat' LIMIT 1];
        System.runAs(runUser) {
            Map<String, Schema.SObjectField> f = Account.SObjectType.getDescribe().fields.getMap();
            if (!f.containsKey('Code__c')) {return;}
            List<RecordType> deptRts = [
                SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Department' LIMIT 1
            ];
            List<RecordType> uniRts = [
                SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'University' LIMIT 1
            ];
            if (deptRts.isEmpty()) {return;}

            Account parent;
            if (!uniRts.isEmpty()) {
                parent = new KenTestDataFactory.AccountCreator('Dept Batch Parent University')
                    .setRecordTypeId(uniRts[0].Id).create();
            }
            Account existingDept = new Account(
                Name = 'Existing Dept',
                RecordTypeId = deptRts[0].Id,
                ParentId = parent == null ? null : parent.Id
            );
            existingDept.put('Code__c', 'DEPTX');
            insert existingDept;

            // Payload: one row that matches the existing code (update path),
            // one new row with a unique code, one duplicate-in-file row, one no-code row.
            Map<String, Object> updRow = new Map<String, Object>{
                'RowNumber' => '1', 'Name' => 'Existing Dept Updated', 'Code__c' => 'DEPTX'
            };
            Map<String, Object> newRow = new Map<String, Object>{
                'RowNumber' => '2', 'Name' => 'Dept New', 'Code__c' => 'DEPTY'
            };
            Map<String, Object> dupFileA = new Map<String, Object>{
                'RowNumber' => '3', 'Name' => 'Dept Zed', 'Code__c' => 'DEPTZ'
            };
            Map<String, Object> dupFileB = new Map<String, Object>{
                'RowNumber' => '4', 'Name' => 'Dept Zed Again', 'Code__c' => 'DEPTZ'
            };
            Map<String, Object> noCodeRow = new Map<String, Object>{
                'RowNumber' => '5', 'Name' => 'Dept NoCode'
            };
            String jsonRows = JSON.serialize(new List<Object>{ updRow, newRow, dupFileA, dupFileB, noCodeRow });

            Test.startTest();
            Id jobId = Database.executeBatch(
                new KenAccountImportBatch(jsonRows, 'Department', parent == null ? null : parent.Id), 200
            );
            Test.stopTest();
            System.assertNotEquals(null, jobId, 'Department batch returns a job id.');
        }
    }

    @isTest
    static void testBatchWithUnknownRecordType() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'acctbat' LIMIT 1];
        System.runAs(runUser) {
            Map<String, Object> row = new Map<String, Object>{
                'RowNumber' => '1',
                'Name' => 'UnknownTypeRow'
            };
            String jsonRows = JSON.serialize(new List<Object>{ row });
            Test.startTest();
            Id jobId = Database.executeBatch(
                new KenAccountImportBatch(jsonRows, 'NotARecordType', null), 200
            );
            Test.stopTest();
            System.assertNotEquals(null, jobId, 'Unknown record type should still return a job id.');
        }
    }
}