@isTest(SeeAllData=false)
private class AccountImportBatchTest {
    private static final String PROCESS_SOURCE = 'Class:AccountImportBatch';

    @isTest
    static void testStartParsesOnlyMapRows() {
        String recordTypeName = getSupportedRecordTypeName();

        AccountImportBatch blankBatch = new AccountImportBatch('', recordTypeName, null);
        Integer blankCount = countRows(blankBatch.start(null));
        System.assertEquals(0, blankCount, 'Blank jsonRows should return empty iterable.');

        List<Object> mixedRows = new List<Object>{
            new Map<String, Object>{ 'Name' => 'Row A' },
            'noise',
            123,
            new Map<String, Object>{ 'Name' => 'Row B' }
        };
        AccountImportBatch mixedBatch = new AccountImportBatch(JSON.serialize(mixedRows), recordTypeName, null);
        Integer parsedCount = countRows(mixedBatch.start(null));
        System.assertEquals(2, parsedCount, 'Only map rows should be returned from start().');
    }

    @isTest
    static void testExecuteGuardsAndFinishCoverage() {
        List<Map<String, Object>> emptyScope = new List<Map<String, Object>>();

        new AccountImportBatch('[]', 'University', null).execute(null, emptyScope);
        new AccountImportBatch('[]', 'Institute', null).execute(null, emptyScope);
        new AccountImportBatch('[]', 'Department', null).execute(null, emptyScope);
        new AccountImportBatch('[]', 'School', null).execute(null, emptyScope);
        new AccountImportBatch('[]', 'Unknown', null).execute(null, emptyScope);
        new AccountImportBatch('[]', 'Unknown', null).finish(null);

        System.assert(true, 'Guard and finish paths executed without errors.');
    }

    @isTest
    static void testExecuteDuplicateAndErrorLoggingWithoutParent() {
        String recordTypeName = getSupportedRecordTypeName();
        Id recordTypeId = AccountImportController.getAccountRecordTypeId(recordTypeName);
        System.assertNotEquals(null, recordTypeId, 'Account record type must exist for this test.');

        new TestDataFactory.AccountCreator('Duplicate In Org')
            .setRecordTypeId(recordTypeId)
            .create();

        List<Map<String, Object>> scope = new List<Map<String, Object>>{
            new Map<String, Object>{
                'RowNumber' => '10',
                'Name' => 'Duplicate In Org'
            },
            new Map<String, Object>{
                'RowNumber' => '11',
                'Name' => 'Duplicate In File'
            },
            new Map<String, Object>{
                'RowNumber' => '12',
                'Name' => 'Duplicate In File'
            },
            new Map<String, Object>{
                'RowNumber' => '13',
                'Name' => 'Valid Account',
                'NumberOfEmployees' => 'not-a-number'
            },
            new Map<String, Object>{
                'RowNumber' => 'bad-row-number'
            },
            new Map<String, Object>{
                'RowNumber' => '15',
                'Name' => 'Skip System Keys',
                'RecordTypeId' => 'ignored',
                'RecordType' => 'ignored',
                'RecordType.Name' => 'ignored',
                'ParentId' => 'ignored'
            }
        };

        Test.startTest();
        new AccountImportBatch('[]', recordTypeName, null).execute(null, scope);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE Name = 'Duplicate In Org']);
        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE Name = 'Duplicate In File']);
        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE Name = 'Valid Account']);
        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE Name = 'Skip System Keys']);

        Integer duplicateLogs = [
            SELECT COUNT()
            FROM Audit_Log__c
            WHERE Source__c = :PROCESS_SOURCE
            AND Error_Message__c LIKE 'Account duplicate skipped%'
        ];
        System.assert(duplicateLogs > 0, 'Duplicate rows should be logged.');

        Integer insertErrorLogs = [
            SELECT COUNT()
            FROM Audit_Log__c
            WHERE Source__c = :PROCESS_SOURCE
            AND Error_Message__c LIKE 'Account insert%'
        ];
        System.assert(insertErrorLogs > 0, 'Failed inserts should be logged.');
    }

    @isTest
    static void testExecuteDuplicateAndInsertWithParent() {
        String recordTypeName = getSupportedRecordTypeName();
        Id recordTypeId = AccountImportController.getAccountRecordTypeId(recordTypeName);
        System.assertNotEquals(null, recordTypeId, 'Account record type must exist for this test.');

        Account parent = new TestDataFactory.AccountCreator('Parent Holder').create();

        new TestDataFactory.AccountCreator('Child Duplicate')
            .setRecordTypeId(recordTypeId)
            .setParentId(parent.Id)
            .create();

        List<Map<String, Object>> scope = new List<Map<String, Object>>{
            new Map<String, Object>{
                'RowNumber' => '1',
                'Name' => 'Child Duplicate'
            },
            new Map<String, Object>{
                'RowNumber' => '2',
                'Name' => 'Child Unique'
            }
        };

        Test.startTest();
        new AccountImportBatch('[]', recordTypeName, parent.Id).execute(null, scope);
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Account WHERE Name = 'Child Duplicate' AND ParentId = :parent.Id],
            'Duplicate child should be skipped when parentId is provided.'
        );
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Account WHERE Name = 'Child Unique' AND ParentId = :parent.Id],
            'Unique child should be inserted under the given parent.'
        );
    }

    private static Integer countRows(Iterable<Map<String, Object>> rows) {
        Integer count = 0;
        for (Map<String, Object> row : rows) {
            count++;
        }
        return count;
    }

    private static String getSupportedRecordTypeName() {
        List<String> preferred = new List<String>{ 'Department', 'Institute', 'University', 'School' };
        for (String rtName : preferred) {
            if (AccountImportController.getAccountRecordTypeId(rtName) != null) {
                return rtName;
            }
        }
        List<RecordType> fallback = [
            SELECT Name
            FROM RecordType
            WHERE SObjectType = 'Account'
            LIMIT 1
        ];
        return fallback.isEmpty() ? null : fallback[0].Name;
    }
}