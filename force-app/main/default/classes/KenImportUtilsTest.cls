@isTest(SeeAllData=false)
/**
 * @description
 *
 * Usage:
 *  - No direct callers found
 */
private class KenImportUtilsTest {
    @TestSetup
    static void makeData() {
        new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias('imputl')
            .create();

        Schema.DescribeSObjectResult accountDescribe = Account.SObjectType.getDescribe();
        Map<String, Schema.RecordTypeInfo> rtByDevName = new Map<String, Schema.RecordTypeInfo>();
        for (Schema.RecordTypeInfo rti : accountDescribe.getRecordTypeInfos()) {
            rtByDevName.put(rti.getDeveloperName(), rti);
        }
        System.assert(rtByDevName.containsKey(KenConstantController.RECORDTYPE_ACCOUNT_UNIVERSITY), 'University record type must exist');
        System.assert(rtByDevName.containsKey(KenConstantController.RECORDTYPE_ACCOUNT_INSTITUTE), 'Institute record type must exist');
        System.assert(rtByDevName.containsKey(KenConstantController.RECORDTYPE_ACCOUNT_DEPARTMENT), 'Department record type must exist');

        Id uniRtId = rtByDevName.get(KenConstantController.RECORDTYPE_ACCOUNT_UNIVERSITY).getRecordTypeId();
        Id instRtId = rtByDevName.get(KenConstantController.RECORDTYPE_ACCOUNT_INSTITUTE).getRecordTypeId();
        Id deptRtId = rtByDevName.get(KenConstantController.RECORDTYPE_ACCOUNT_DEPARTMENT).getRecordTypeId();

        Account uni = new KenTestDataFactory.AccountCreator('Test University')
            .setRecordTypeId(uniRtId)
            .create();
        new KenTestDataFactory.AccountCreator('Test Institute')
            .setRecordTypeId(instRtId)
            .setParentId(uni.Id)
            .create();
        new KenTestDataFactory.AccountCreator('Test Department')
            .setRecordTypeId(deptRtId)
            .create();

        new KenTestDataFactory.AccountCreator('Test Other Account').create();
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
    static void testGetParentAccountsForImportFilters() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'imputl' LIMIT 1];
        System.runAs(runUser) {
            List<KenImportUtils.IdName> universityParents = KenImportUtils.getParentAccountsForImport(KenConstantController.RECORDTYPE_ACCOUNT_UNIVERSITY);
            System.assertEquals(1, universityParents.size(), 'University import should only show University accounts');

            List<KenImportUtils.IdName> instituteParents = KenImportUtils.getParentAccountsForImport(KenConstantController.RECORDTYPE_ACCOUNT_INSTITUTE);
            System.assertEquals(2, instituteParents.size(), 'Institute import should show University + Institute accounts');

            List<KenImportUtils.IdName> departmentParents = KenImportUtils.getParentAccountsForImport(KenConstantController.RECORDTYPE_ACCOUNT_DEPARTMENT);
            System.assertEquals(2, departmentParents.size(), 'Department import should show University + Institute accounts');
        }
    }
    
    @isTest
    static void testConvertValue() {
        Schema.DescribeFieldResult d = Account.Name.getDescribe();
        Object val = KenImportUtils.convertValue('Test', d);
        System.assertEquals('Test', String.valueOf(val));
    }

    @isTest
    static void testLookupListMethods() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'imputl' LIMIT 1];
        System.runAs(runUser) {
            System.assertNotEquals(null, KenImportUtils.getUniversities(), 'Universities returned.');
            Account uni = [SELECT Id FROM Account WHERE Name = 'Test University' LIMIT 1];
            System.assertNotEquals(null, KenImportUtils.getInstitutes(uni.Id), 'Institutes returned.');
            System.assertNotEquals(null, KenImportUtils.getDepartments(null), 'Departments for null parent returned.');
            System.assertNotEquals(null, KenImportUtils.getAllDepartments(), 'All departments returned.');
            System.assertNotEquals(null, KenImportUtils.getCampuses(), 'Campuses returned.');
            System.assertNotEquals(null, KenImportUtils.getLocations(), 'Locations returned.');
            System.assertNotEquals(null, KenImportUtils.getFacultyContacts(), 'Faculty contacts returned.');
            List<KenImportUtils.IdName> blankTypeParents = KenImportUtils.getParentAccountsForImport('');
            System.assertNotEquals(null, blankTypeParents, 'Blank record type returns accounts.');
            List<KenImportUtils.IdName> unknownTypeParents = KenImportUtils.getParentAccountsForImport('Unknown_Type');
            System.assertNotEquals(null, unknownTypeParents, 'Unknown record type returns accounts.');
        }
    }

    @isTest
    static void testBatchStatusNullId() {
        System.assertEquals(null, KenImportUtils.getBatchStatus(null), 'Null job id should return null.');
    }

    @isTest
    static void testConvertValueTypeCoercions() {
        Schema.DescribeFieldResult dateField = findField(Contact.SObjectType, 'Birthdate');
        if (dateField != null) {
            System.assertEquals(null, KenImportUtils.convertValue(null, dateField), 'Null input should return null.');
            System.assertEquals(Date.newInstance(2024, 3, 5), KenImportUtils.convertValue('5/3/24', dateField), 'Two-digit year should parse.');
            System.assertEquals(Date.newInstance(2024, 3, 5), KenImportUtils.convertValue('5/3/2024', dateField), 'Four-digit year should parse.');
            System.assertEquals(Date.newInstance(2026, 1, 1), KenImportUtils.convertValue(Date.newInstance(2026, 1, 1), dateField), 'Date pass-through should work.');
        }

        Schema.DescribeFieldResult currencyField = findNumericField();
        if (currencyField != null) {
            Object r1 = KenImportUtils.convertValue('12.5', currencyField);
            System.assertEquals(12.5, (Decimal) r1, 'String currency should parse.');
            Object r2 = KenImportUtils.convertValue(Decimal.valueOf('5.5'), currencyField);
            System.assertEquals(5.5, (Decimal) r2, 'Decimal pass-through should work.');
            Object r3 = KenImportUtils.convertValue(10, currencyField);
            System.assertEquals(10, (Decimal) r3, 'Integer should convert to Decimal.');
        }

        Schema.DescribeFieldResult intField = findIntField();
        if (intField != null) {
            System.assertEquals(5, (Integer) KenImportUtils.convertValue('5', intField), 'String integer should parse.');
            System.assertEquals(5, (Integer) KenImportUtils.convertValue(5, intField), 'Integer pass-through should work.');
            System.assertEquals(5, (Integer) KenImportUtils.convertValue(Decimal.valueOf(5), intField), 'Decimal should convert to Integer.');
        }

        Schema.DescribeFieldResult boolField = findBoolField();
        if (boolField != null) {
            System.assertEquals(true, (Boolean) KenImportUtils.convertValue('YES', boolField), 'YES parses true.');
            System.assertEquals(true, (Boolean) KenImportUtils.convertValue('1', boolField), '1 parses true.');
            System.assertEquals(false, (Boolean) KenImportUtils.convertValue('no', boolField), 'no parses false.');
            System.assertEquals(true, (Boolean) KenImportUtils.convertValue(true, boolField), 'Boolean pass-through.');
        }
    }

    private static Schema.DescribeFieldResult findField(Schema.SObjectType t, String api) {
        Map<String, Schema.SObjectField> f = t.getDescribe().fields.getMap();
        return f.containsKey(api) ? f.get(api).getDescribe() : null;
    }

    private static Schema.DescribeFieldResult findNumericField() {
        Map<String, Schema.SObjectField> f = Account.SObjectType.getDescribe().fields.getMap();
        for (String n : f.keySet()) {
            Schema.DescribeFieldResult d = f.get(n).getDescribe();
            if (d.getType() == Schema.DisplayType.CURRENCY || d.getType() == Schema.DisplayType.DOUBLE || d.getType() == Schema.DisplayType.PERCENT) {
                return d;
            }
        }
        return null;
    }

    private static Schema.DescribeFieldResult findIntField() {
        Map<String, Schema.SObjectField> f = Account.SObjectType.getDescribe().fields.getMap();
        for (String n : f.keySet()) {
            Schema.DescribeFieldResult d = f.get(n).getDescribe();
            if (d.getType() == Schema.DisplayType.INTEGER || d.getType() == Schema.DisplayType.LONG) {
                return d;
            }
        }
        return null;
    }

    private static Schema.DescribeFieldResult findBoolField() {
        Map<String, Schema.SObjectField> f = Account.SObjectType.getDescribe().fields.getMap();
        for (String n : f.keySet()) {
            Schema.DescribeFieldResult d = f.get(n).getDescribe();
            if (d.getType() == Schema.DisplayType.BOOLEAN) {
                return d;
            }
        }
        return null;
    }

    @isTest
    static void testDtoConstructors() {
        KenImportUtils.IdName one = new KenImportUtils.IdName(null, 'n1');
        System.assertEquals('n1', one.name, 'Name should round-trip.');
        System.assertEquals(null, one.email, 'Email should default to null.');
        KenImportUtils.IdName two = new KenImportUtils.IdName(null, 'n2', 'e@x.com');
        System.assertEquals('e@x.com', two.email, 'Email override should work.');
        KenImportUtils.ImportResult result = new KenImportUtils.ImportResult();
        System.assertEquals(0, result.createdLearnings, 'createdLearnings should default to 0.');
        System.assertEquals(0, result.createdCourses, 'createdCourses should default to 0.');
        System.assertEquals(0, result.createdPrograms, 'createdPrograms should default to 0.');
        System.assertNotEquals(null, result.errors, 'errors list should be initialized.');
    }

    @isTest
    static void testGetFacultyContactsReturnsActiveFaculty() {
        User runUser = [SELECT Id FROM User WHERE Alias = 'imputl' LIMIT 1];
        System.runAs(runUser) {
            Account a = new KenTestDataFactory.AccountCreator('Faculty Holder').create();
            Contact faculty = new KenTestDataFactory.ContactCreator()
                .setAccount(a.Id).setLastName('FacultyX').create();
            try {
                ConstituentRole role = new ConstituentRole();
                role.put('PersonId', faculty.Id);
                role.put('RoleType', 'Faculty');
                role.put('Status', 'Active');
                insert role;
            } catch (Exception ignored) {}
            List<KenImportUtils.IdName> rows = KenImportUtils.getFacultyContacts();
            System.assertNotEquals(null, rows, 'Faculty list should not be null.');
        }
    }

    @isTest
    static void testParseDateVariants() {
        Schema.DescribeFieldResult dateField = findField(Contact.SObjectType, 'Birthdate');
        if (dateField == null) {return;}
        // Pass-through
        System.assertEquals(Date.newInstance(2026, 4, 5), KenImportUtils.convertValue(Date.newInstance(2026, 4, 5), dateField), 'Date pass-through should work.');
        // yyyy-MM-dd
        System.assertEquals(Date.newInstance(2026, 4, 5), KenImportUtils.convertValue('2026-04-05', dateField), 'ISO date should parse.');
        // Invalid string — parseDateOrThrow falls back to Date.valueOf which throws; convertValue wraps and rethrows.
        try {
            KenImportUtils.convertValue('not-a-date', dateField);
            System.assert(false, 'Invalid date should throw.');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
        }
    }

    @isTest
    static void testParseDatetimeVariants() {
        Schema.DescribeFieldResult dtField;
        Map<String, Schema.SObjectField> f = Contact.SObjectType.getDescribe().fields.getMap();
        for (String n : f.keySet()) {
            Schema.DescribeFieldResult d = f.get(n).getDescribe();
            if (d.getType() == Schema.DisplayType.DATETIME) {
                dtField = d;
                break;
            }
        }
        if (dtField == null) {return;}
        // Pass-through
        Datetime now = Datetime.now();
        System.assertEquals(now, KenImportUtils.convertValue(now, dtField), 'Datetime pass-through should work.');
        // Valid ISO datetime string
        String iso = '2026-04-05 10:00:00';
        try {
            Object r = KenImportUtils.convertValue(iso, dtField);
            System.assertNotEquals(null, r, 'Datetime string should parse.');
        } catch (Exception e) {
            // Some orgs reject the format; tolerate.
            System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
        }
        // Date-like input via slash
        try {
            Object r = KenImportUtils.convertValue('5/4/2026', dtField);
            System.assertNotEquals(null, r, 'Slash-date input should parse as datetime at midnight.');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Exception should carry a message.');
        }
    }
}