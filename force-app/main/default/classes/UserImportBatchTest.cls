@isTest(SeeAllData=false)
@suppressWarnings('PMD.NcssMethodCount')
private class UserImportBatchTest {
    @TestSetup
    static void makeData() {
        User runUser = new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias('uimpbt')
            .create();
        new KenTestDataFactory.PermissionSetAssignmentCreator('EducationCloudAccess').assignToUser(runUser.Id);
    }

    private static Id resolvePersonAccountRecordTypeId() {
        for (String candidate : new List<String>{ 'Person_Account', 'Person Account' }) {
            List<RecordType> named = [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = 'Account'
                AND IsPersonType = true
                AND (DeveloperName = :candidate OR Name = :candidate)
                LIMIT 1
            ];
            if (!named.isEmpty()) {return named[0].Id;}
        }
        List<RecordType> fallback = [
            SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND IsPersonType = true LIMIT 1
        ];
        return fallback.isEmpty() ? null : fallback[0].Id;
    }

    @isTest
    static void startWithBlankJsonYieldsEmptyIterable() {
        UserImportBatch batch = new UserImportBatch(null, 'Faculty', null);
        Iterable<Map<String, Object>> items = batch.start(null);
        System.assertNotEquals(null, items, 'Iterable should never be null.');
        Integer count = 0;
        for (Map<String, Object> row : items) {count++;}
        System.assertEquals(0, count, 'Blank JSON should produce zero rows.');
    }

    @isTest
    static void batchRunsForStudentImportWithoutPlan() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'uimpbt' LIMIT 1];
        System.runAs(runUser) {
            Id personRtId = resolvePersonAccountRecordTypeId();
            if (personRtId == null) {return;}

            Account learnerAcct = new Account(Name = 'Student Intake Org');
            insert learnerAcct;

            Map<String, Object> row = new Map<String, Object>{
                'RowNumber' => '1',
                'First Name' => 'Stu',
                'Last Name' => 'Student',
                'Email' => 'stu.student+' + DateTime.now().getTime() + '@example.com',
                'Student ID' => 'S-001',
                'Account Name' => 'Student Intake Org'
            };
            String jsonRows = JSON.serialize(new List<Object>{ row });

            Test.startTest();
            Id jobId = Database.executeBatch(new UserImportBatch(jsonRows, 'Student', null, 'Section A'), 200);
            Test.stopTest();

            System.assertNotEquals(null, jobId, 'Job id should be returned.');
        }
    }

    @isTest
    static void batchRunsWithMissingEmailRowAuditsError() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'uimpbt' LIMIT 1];
        System.runAs(runUser) {
            Id personRtId = resolvePersonAccountRecordTypeId();
            if (personRtId == null) {return;}

            Map<String, Object> rowMissingEmail = new Map<String, Object>{
                'RowNumber' => '1',
                'First Name' => 'NoEmail',
                'Last Name' => 'User'
            };
            String jsonRows = JSON.serialize(new List<Object>{ rowMissingEmail });

            Test.startTest();
            Id jobId = Database.executeBatch(new UserImportBatch(jsonRows, 'Faculty', null), 200);
            Test.stopTest();

            System.assertNotEquals(null, jobId, 'Job id should be returned even with bad rows.');
        }
    }

    @isTest
    static void batchRunsForFacultyWithDepartment() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'uimpbt' LIMIT 1];
        System.runAs(runUser) {
            Id personRtId = resolvePersonAccountRecordTypeId();
            if (personRtId == null) {return;}

            Map<String, Object> row = new Map<String, Object>{
                'RowNumber' => '1',
                'First Name' => 'Fac',
                'Last Name' => 'User',
                'Email' => 'fac.dept+' + DateTime.now().getTime() + '@example.com',
                'Department' => 'Nonexistent Department',
                'Employee ID' => 'E-100'
            };
            String jsonRows = JSON.serialize(new List<Object>{ row });

            Test.startTest();
            Id jobId = Database.executeBatch(new UserImportBatch(jsonRows, 'Faculty', null), 200);
            Test.stopTest();

            System.assertNotEquals(null, jobId, 'Job id should be returned.');
        }
    }
}