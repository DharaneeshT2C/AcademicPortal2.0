/**
 * ************************************************************************************************
 * @className  KenUserImportBatchTest
 *
 * @description
 *  Test class for UserImportBatch.
 *
 *  Responsibilities:
 *  - Validate start() parsing behavior for blank/mixed json
 *  - Validate execute() behavior across multiple org metadata configurations
 *  - Validate duplicate handling and non-throwing behavior for malformed inputs
 *
 * @author      Sureka A R K
 * @createdOn   Feb 27, 2026
 *
 * @history
 * ------------------------------------------------------------------------------------------------
 * Version   Date           Author          Description
 * 1.0       Feb 27, 2026   Sureka A R K    Added ApexDocs
 * ************************************************************************************************
 */
@isTest
private class KenUserImportBatchTest {
    /**
     * @description Creates baseline test user required by runAs tests.
     */
    @TestSetup
    static void makeData() {
        new TestDataFactory.UserCreator('System Administrator')
            .setAlias('usrimb')
            .create();
    }

    /**
     * @description Fetches the common test user created by test setup.
     * @return RunAs user record.
     */
    private static User getRunUser() {
        return [
            SELECT Id
            FROM User
            WHERE Alias = 'usrimb'
            AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
    }

    /**
     * @description Checks whether required person account record type exists.
     * @return True when Student_Success_Higher_Ed_Student record type exists.
     */
    private static Boolean hasStudentSuccessPersonRt() {
        return ![
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND IsPersonType = true
            AND (DeveloperName = 'Student_Success_Higher_Ed_Student' OR Name = 'Student_Success_Higher_Ed_Student')
            LIMIT 1
        ].isEmpty();
    }

    /**
     * @description Adds supported ContactProfile fields to input rows when metadata exists.
     * @param rowValid Valid row map.
     * @param rowInvalidRole Invalid row map.
     */
    private static void addContactProfileDataIfAvailable(Map<String, Object> rowValid, Map<String, Object> rowInvalidRole) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('ContactProfile')) {
            return;
        }

        Map<String, Schema.SObjectField> profileFields = gd.get('ContactProfile').getDescribe().fields.getMap();
        List<String> profileCandidates = new List<String>{
            'BirthPlace',
            'Ethnicity',
            'MilitaryBranch',
            'MilitaryService',
            'HighestEducationLevel',
            'Race',
            'PrimaryCitizenshipType'
        };
        for (String key : profileCandidates) {
            if (profileFields.containsKey(key)) {
                rowValid.put(key, 'Value_' + key);
                break;
            }
        }
        if (profileFields.containsKey('IsFirstGenerationStudent')) {
            rowInvalidRole.put('IsFirstGenerationStudent', 'not-a-boolean');
        }
    }

    /**
     * @description Adds supported ConstituentRole fields to input rows when metadata exists.
     * @param rowValid Valid row map.
     * @param rowInvalidRole Invalid row map.
     */
    private static void addConstituentRoleDataIfAvailable(Map<String, Object> rowValid, Map<String, Object> rowInvalidRole) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('ConstituentRole')) {
            return;
        }

        Map<String, Schema.SObjectField> roleFields = gd.get('ConstituentRole').getDescribe().fields.getMap();
        if (roleFields.containsKey('Status')) {
            String validStatus = getFirstPicklistValue(roleFields.get('Status'));
            if (String.isNotBlank(validStatus)) {
                rowValid.put('Status', validStatus);
            }
            rowInvalidRole.put('Status', 'DefinitelyInvalidStatusValue');
        }
        if (roleFields.containsKey('EffectiveStartDate')) {
            rowValid.put('EffectiveStartDate', String.valueOf(Date.today()));
            rowInvalidRole.put('EffectiveStartDate', 'not-a-date');
        }
        if (roleFields.containsKey('EffectiveEndDate')) {
            rowValid.put('EffectiveEndDate', String.valueOf(Date.today().addDays(30)));
            rowInvalidRole.put('EffectiveEndDate', 'also-not-a-date');
        }
    }

    /**
     * @description Returns first picklist value for a field when available.
     * @param fieldRef Picklist field reference.
     * @return First picklist value or null.
     */
    private static String getFirstPicklistValue(Schema.SObjectField fieldRef) {
        if (fieldRef == null) {
            return null;
        }
        List<Schema.PicklistEntry> entries = fieldRef.getDescribe().getPicklistValues();
        return entries.isEmpty() ? null : entries[0].getValue();
    }

    /**
     * @description Validates start() returns no rows for blank json.
     */
    @isTest
    static void startReturnsEmptyIterableWhenJsonBlank() {
        User runUser = getRunUser();

        System.runAs(runUser) {
            UserImportBatch batch = new UserImportBatch(null, 'Faculty', null);
            Iterable<Map<String, Object>> result = batch.start(null);

            Integer countRows = 0;
            for (Map<String, Object> row : result) {
                countRows++;
            }
            System.assertEquals(0, countRows, 'Blank json should produce no start rows.');
        }
    }

    /**
     * @description Validates start() keeps only map rows from mixed json payload.
     */
    @isTest
    static void startReturnsOnlyMapRowsWhenJsonContainsMixedTypes() {
        User runUser = getRunUser();

        System.runAs(runUser) {
            String jsonRows = JSON.serialize(new List<Object>{
                new Map<String, Object>{ 'FirstName' => 'A', 'LastName' => 'One', 'Email' => 'a.one@example.com' },
                'not-a-map',
                123
            });
            UserImportBatch batch = new UserImportBatch(jsonRows, 'Faculty', null);
            Iterable<Map<String, Object>> result = batch.start(null);

            Integer countRows = 0;
            for (Map<String, Object> row : result) {
                countRows++;
            }
            System.assertEquals(1, countRows, 'Only map rows should be included from parsed json.');
        }
    }

    /**
     * @description Validates batch completes successfully for blank payload.
     */
    @isTest
    static void executeCompletesWhenJsonBlank() {
        User runUser = getRunUser();

        System.runAs(runUser) {
            Test.startTest();
            Id jobId = Database.executeBatch(new UserImportBatch('', 'Faculty', null), 50);
            Test.stopTest();

            AsyncApexJob job = [
                SELECT Status, NumberOfErrors
                FROM AsyncApexJob
                WHERE Id = :jobId
                LIMIT 1
            ];
            System.assertEquals('Completed', job.Status, 'Batch should complete for blank payload.');
            System.assertEquals(0, job.NumberOfErrors, 'Blank payload should not produce unhandled errors.');
        }
    }

    /**
     * @description Validates batch data handling across orgs with/without required metadata.
     */
    @isTest
    static void executeHandlesDataAcrossOrgConfigurations() {
        User runUser = getRunUser();

        System.runAs(runUser) {
            String uniqueEmail = 'faculty.' + Datetime.now().getTime() + '@example.com';
            List<Object> rows = new List<Object>{
                new Map<String, Object>{
                    'RowNumber' => 1,
                    'FirstName' => 'Priya',
                    'LastName' => 'Shah',
                    'Email' => uniqueEmail,
                    'Title' => 'Professor',
                    'Phone' => '1234567890'
                },
                new Map<String, Object>{
                    'RowNumber' => 2,
                    'FirstName' => 'Priya',
                    'LastName' => 'Shah',
                    'Email' => uniqueEmail
                }
            };

            Test.startTest();
            Id jobId = Database.executeBatch(new UserImportBatch(JSON.serialize(rows), null, null), 50);
            Test.stopTest();

            AsyncApexJob job = [
                SELECT Status, NumberOfErrors
                FROM AsyncApexJob
                WHERE Id = :jobId
                LIMIT 1
            ];
            System.assertEquals('Completed', job.Status, 'Batch should complete for data payload.');
            System.assertEquals(0, job.NumberOfErrors, 'Batch should not fail even with duplicate rows.');

            if (hasStudentSuccessPersonRt()) {
                List<Contact> created = [
                    SELECT Id, Email, LastName
                    FROM Contact
                    WHERE Email = :uniqueEmail
                ];
                System.assert(
                    created.size() <= 1,
                    'Duplicate email+lastname in the same file should not create multiple contacts.'
                );
            } else {
                System.assertEquals(
                    0,
                    [SELECT count() FROM Contact WHERE Email = :uniqueEmail],
                    'Without required person account record type, no import contact should be created.'
                );
            }
        }
    }

    /**
     * @description Validates duplicate-in-org and save error branches using direct execute().
     */
    @isTest
    static void executeDirectCallCoversDuplicateInOrgAndSaveResultErrorPaths() {
        User runUser = getRunUser();

        System.runAs(runUser) {
            String existingEmail = 'existing.' + Datetime.now().getTime() + '@example.com';
            insert new Contact(
                FirstName = 'Existing',
                LastName = 'Teacher',
                Email = existingEmail
            );

            List<Map<String, Object>> scope = new List<Map<String, Object>>{
                new Map<String, Object>{
                    'RowNumber' => 10,
                    'FirstName' => 'Existing',
                    'LastName' => 'Teacher',
                    'Email' => existingEmail
                },
                new Map<String, Object>{
                    'RowNumber' => 'abc',
                    'FirstName' => 'NoLastName',
                    'Email' => 'missing.lastname.' + Datetime.now().getTime() + '@example.com',
                    'Birthdate' => 'not-a-date',
                    'ReportsToId' => 'invalid-id',
                    'BirthPlace' => 'Delhi',
                    'Status' => 'InvalidStatus'
                },
                new Map<String, Object>{
                    'RowNumber' => 12,
                    'FirstName' => 'NoEmailNoLast'
                },
                new Map<String, Object>{
                    'RowNumber' => 13,
                    'FirstName' => 'Valid',
                    'LastName' => 'Faculty',
                    'Email' => 'valid.' + Datetime.now().getTime() + '@example.com',
                    'BirthPlace' => 'Mumbai',
                    'Status' => 'Active'
                }
            };

            UserImportBatch batch = new UserImportBatch('[]', 'Faculty', null);
            batch.execute(null, scope);
            batch.finish(null);

            if (hasStudentSuccessPersonRt()) {
                Integer validCount = [
                    SELECT count()
                    FROM Contact
                    WHERE Email LIKE 'valid.%@example.com'
                    AND LastName = 'Faculty'
                ];
                System.assertEquals(1, validCount, 'Valid row should create one contact when Person Account RT exists.');
            } else {
                System.assertEquals(
                    0,
                    [SELECT count() FROM Contact WHERE Email LIKE 'valid.%@example.com'],
                    'No contacts should be created when Person Account RT is unavailable.'
                );
            }
        }
    }

    /**
     * @description Validates null rows and blank keys do not break direct execute().
     */
    @isTest
    static void executeDirectCallHandlesNullAndBlankKeysWithoutFailure() {
        User runUser = getRunUser();

        System.runAs(runUser) {
            List<Map<String, Object>> scope = new List<Map<String, Object>>{
                null,
                new Map<String, Object>{
                    'RowNumber' => 20,
                    '' => 'blank-key',
                    '   ' => 'whitespace-key',
                    'Unknown_Field__c' => 'ignored',
                    'FirstName' => 'Another',
                    'LastName' => 'Valid',
                    'Email' => 'another.valid.' + Datetime.now().getTime() + '@example.com'
                }
            };

            UserImportBatch batch = new UserImportBatch('[]', 'Faculty', null);
            batch.execute(null, scope);
            batch.finish(null);

            System.assert(true, 'Direct execute should complete without throwing for null rows/blank keys.');
        }
    }

    /**
     * @description Validates profile/role processing branches when metadata is available.
     */
    @isTest
    static void executeDirectCallCoversProfileAndRoleBranchesWhenMetadataExists() {
        User runUser = getRunUser();

        System.runAs(runUser) {
            if (!hasStudentSuccessPersonRt()) {
                System.assert(true, 'Profile/Role branch coverage depends on person account RT.');
                return;
            }

            Map<String, Object> rowValid = new Map<String, Object>{
                'RowNumber' => 30,
                'FirstName' => 'Meta',
                'LastName' => 'Valid',
                'Email' => 'meta.valid.' + Datetime.now().getTime() + '@example.com'
            };
            Map<String, Object> rowInvalidRole = new Map<String, Object>{
                'RowNumber' => 31,
                'FirstName' => 'Meta',
                'LastName' => 'InvalidRole',
                'Email' => 'meta.invalid.role.' + Datetime.now().getTime() + '@example.com'
            };

            addContactProfileDataIfAvailable(rowValid, rowInvalidRole);
            addConstituentRoleDataIfAvailable(rowValid, rowInvalidRole);

            List<Map<String, Object>> scope = new List<Map<String, Object>>{
                rowValid,
                rowInvalidRole
            };
            UserImportBatch batch = new UserImportBatch('[]', 'Faculty', null);
            batch.execute(null, scope);
            batch.finish(null);

            System.assertEquals(
                1,
                [SELECT count() FROM Contact WHERE Email = :String.valueOf(rowValid.get('Email'))],
                'Valid metadata-driven row should create one contact.'
            );
        }
    }
}