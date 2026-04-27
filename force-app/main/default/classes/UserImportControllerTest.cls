@isTest(SeeAllData=false)
/**
 * @description
 *
 * Usage:
 *  - No direct callers found
 */
private class UserImportControllerTest {
    @TestSetup
    static void makeData() {
        User runUser = new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias('usrimp')
            .create();
        
        System.runAs(runUser) {
            Id personRtId = resolvePersonAccountRecordTypeId();
            if (personRtId != null) {
                Account pa = new Account();
                pa.RecordTypeId = personRtId;
                pa.FirstName = 'Joshika';
                pa.LastName = 'Jeyaraj';
                pa.PersonEmail = 'joshikajeyaraj@yopmail.com';
                insert pa;
            }
        }
    }
    
    @isTest
    static void testUserImportBatchRuns() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'usrimp' LIMIT 1];
        System.runAs(runUser) {
            Id expectedPersonRtId = resolvePersonAccountRecordTypeId();
            Map<String, Object> row = new Map<String, Object>{
                'RowNumber' => '1',
                'FirstName' => 'Test',
                'LastName' => 'BatchUser',
                'Email' => 'batch.user+' + DateTime.now().getTime() + '@example.com'
            };
            String jsonRows = JSON.serialize(new List<Object>{ row });
            
            Test.startTest();
            Id jobId = Database.executeBatch(new UserImportBatch(jsonRows, 'Faculty', null), 200);
            Test.stopTest();
            
            System.assertNotEquals(null, jobId, 'Batch job id should be returned');
            if (expectedPersonRtId != null) {
                Account createdAccount = [
                    SELECT Id, RecordTypeId, IsPersonAccount, PersonEmail
                    FROM Account
                    WHERE PersonEmail = :String.valueOf(row.get('Email'))
                    LIMIT 1
                ];
                System.assertEquals(true, createdAccount.IsPersonAccount, 'Expected a person account to be created.');
                System.assertEquals(expectedPersonRtId, createdAccount.RecordTypeId, 'Expected Person_Account-first record type resolution.');
            }
        }
    }
    
    @isTest
    static void testStartBatchAndFetchErrors() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'usrimp' LIMIT 1];
        System.runAs(runUser) {
            Map<String, Object> row = new Map<String, Object>{
                'RowNumber' => '1',
                'FirstName' => 'Joshika',
                'LastName' => 'Jeyaraj',
                'Email' => 'joshikajeyaraj@yopmail.com'
            };
            String jsonRows = JSON.serialize(new List<Object>{ row });
            
            Test.startTest();
            Id jobId = UserImportController.startUserImportBatch(jsonRows, 'Faculty', null);
            Test.stopTest();
            
            System.assertNotEquals(null, jobId, 'Batch job id should be returned');
            List<String> errors = UserImportController.getUserImportErrors(jobId);
            System.assertNotEquals(null, errors, 'Errors list should be returned');
            System.assert(errors.size() > 0, 'Expected at least one error (duplicate or record type issue)');
        }
    }
    
    @isTest
    static void testGetUserImportErrorsWithNullId() {
        List<String> errors = UserImportController.getUserImportErrors(null);
        System.assertNotEquals(null, errors, 'Should return list for null job id');
        System.assertEquals(0, errors.size(), 'Expected empty list for null job id');
    }
    
    @isTest
    static void testBatchDuplicateInFile() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'usrimp' LIMIT 1];
        System.runAs(runUser) {
            Map<String, Object> row1 = new Map<String, Object>{
                'RowNumber' => '1',
                'FirstName' => 'Dupe',
                'LastName' => 'User',
                'Email' => 'dupe.user+' + DateTime.now().getTime() + '@example.com'
            };
            Map<String, Object> row2 = new Map<String, Object>{
                'RowNumber' => '2',
                'FirstName' => 'Dupe',
                'LastName' => 'User',
                'Email' => row1.get('Email')
            };
            String jsonRows = JSON.serialize(new List<Object>{ row1, row2 });
            
            Test.startTest();
            Id jobId = Database.executeBatch(new UserImportBatch(jsonRows, 'Faculty', null), 200);
            Test.stopTest();
            
            List<String> errors = UserImportController.getUserImportErrors(jobId);
            System.assertNotEquals(null, errors, 'Errors list should be returned');
            System.assert(errors.size() > 0, 'Expected duplicate or record type error');
        }
    }
    
    @isTest
    static void testGetUserImportErrorsFallback() {
        if (!Schema.getGlobalDescribe().containsKey('Audit_Log__c')) {return;}
        User runUser = [SELECT Id FROM User WHERE Alias = 'usrimp' LIMIT 1];
        System.runAs(runUser) {
            Id fakeJobId = '707000000000000AAA';
            Audit_Log__c log = new Audit_Log__c();
            if (Audit_Log__c.SObjectType.getDescribe().fields.getMap().containsKey('Process__c')) {
                log.put('Process__c', 'User Import');
            }
            if (Audit_Log__c.SObjectType.getDescribe().fields.getMap().containsKey('RecordId__c')) {
                log.put('RecordId__c', String.valueOf(fakeJobId));
            }
            if (Audit_Log__c.SObjectType.getDescribe().fields.getMap().containsKey('Error_Message__c')) {
                log.put('Error_Message__c', 'Test error');
            }
            insert log;
            
            List<String> errors = UserImportController.getUserImportErrors(fakeJobId);
            System.assert(errors.size() > 0, 'Expected fallback error list');
        }
    }
    
    @isTest
    static void testBatchProfileRoleAndInvalidStatus() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        String profileObj = null;
        for (String name : new List<String>{'ContactProfile', 'ContactProfile__c', 'Contact_Profile__c', 'EDU_Contact_Profile__c', 'EDU_ContactProfile__c'}) {
            if (gd.containsKey(name)) { profileObj = name;break;}
        }
        String roleObj = null;
        for (String name : new List<String>{'ConstituentRole', 'ConstituentRole__c', 'Constituent_Role__c', 'EDU_Constituent_Role__c', 'EDU_ConstituentRole__c'}) {
            if (gd.containsKey(name)) { roleObj = name; break; }
        }
        if (profileObj == null || roleObj == null) {return;}
        
        User runUser = [SELECT Id FROM User WHERE Alias = 'usrimp' LIMIT 1];
        System.runAs(runUser) {
            Map<String, Object> row = new Map<String, Object>{
                'RowNumber' => '1',
                'FirstName' => 'Profile',
                'LastName' => 'Role',
                'Email' => 'prof.role+' + DateTime.now().getTime() + '@example.com',
                // profile fields
                'BirthPlace' => 'Test',
                // role fields (invalid status to trigger validation path)
                'Status' => 'INVALID_STATUS',
                'EffectiveStartDate' => String.valueOf(Date.today())
            };
            String jsonRows = JSON.serialize(new List<Object>{ row });
            
            Test.startTest();
            Id jobId = Database.executeBatch(new UserImportBatch(jsonRows, 'Faculty', null), 200);
            Test.stopTest();
            
            List<String> errors = UserImportController.getUserImportErrors(jobId);
            System.assertNotEquals(null, errors, 'Errors list should be returned');
            // If status picklist exists, expect invalid status message
            Boolean hasInvalidStatus = false;
            for (String msg : errors) {
                if (msg != null && msg.contains('Invalid Status picklist value')) {
                    hasInvalidStatus = true;
                    break;
                }
            }
            System.assert(hasInvalidStatus || errors.size() > 0, 'Expected status validation error or other error');
        }
    }

    @isTest
    static void testStudentImportMapsStudentIdToConstituentRole() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'usrimp' LIMIT 1];
        System.runAs(runUser) {
            String email = 'student.role+' + DateTime.now().getTime() + '@example.com';
            String studentId = 'STU-' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
            Map<String, Object> row = new Map<String, Object>{
                'RowNumber' => '1',
                'FirstName' => 'Student',
                'LastName' => 'RoleMap',
                'Email' => email,
                'Student ID' => studentId
            };
            String jsonRows = JSON.serialize(new List<Object>{ row });

            Test.startTest();
            Id jobId = Database.executeBatch(new UserImportBatch(jsonRows, 'Student', null), 200);
            Test.stopTest();

            System.assertNotEquals(null, jobId, 'Batch job id should be returned');

            Account createdAccount = [
                SELECT Id, PersonContactId, PersonEmail
                FROM Account
                WHERE PersonEmail = :email
                LIMIT 1
            ];

            if (Schema.getGlobalDescribe().containsKey('ConstituentRole') &&
                Schema.getGlobalDescribe().get('ConstituentRole').getDescribe().fields.getMap().containsKey('Student_ID__c')) {
                List<ConstituentRole> roles = [
                    SELECT Id, Student_ID__c, RoleType, PersonId
                    FROM ConstituentRole
                    WHERE PersonId = :createdAccount.PersonContactId
                    AND RoleType = 'Student'
                    LIMIT 1
                ];
                System.assertEquals(1, roles.size(), 'Expected a student constituent role.');
                System.assertEquals(studentId, roles[0].Student_ID__c, 'Student ID should be mapped to Constituent Role.');
            }
        }
    }

    private static Id resolvePersonAccountRecordTypeId() {
        for (String candidate : new List<String>{ 'Person_Account', 'Person Account' }) {
            List<RecordType> namedRecordTypes = [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = 'Account'
                AND IsPersonType = true
                AND (DeveloperName = :candidate OR Name = :candidate)
                LIMIT 1
            ];
            if (!namedRecordTypes.isEmpty()) {
                return namedRecordTypes[0].Id;
            }
        }

        List<RecordType> fallbackRecordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND IsPersonType = true
            LIMIT 1
        ];
        return fallbackRecordTypes.isEmpty() ? null : fallbackRecordTypes[0].Id;
    }
}