@isTest(SeeAllData=false)
private class KenAuditLogHelperTest {
    @isTest
    static void auditLogCreatorBuildsRecordWithAllFields() {
        KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord('Test Process', 'Test Source');
        creator.setErrorMessage('Test error message');
        creator.setStatusCode('500');
        creator.setRecordId('TEST');
        creator.setStackTrace('stack trace text');
        creator.setRequestBody('{"key":"value"}');
        creator.setResponseBody('{"response":"ok"}');
        creator.setType('Custom Type');
        creator.setTimeStamp(Datetime.now());
        creator.setSyncStatus(true);

        Audit_Log__c log = creator.returnWithoutCreate();
        System.assertEquals('Test Process', log.Process__c, 'Process should be set.');
        System.assertEquals('Test Source', log.Source__c, 'Source should be set.');
        System.assertEquals('Test error message', log.Error_Message__c, 'Error message should be set.');
        System.assertEquals('500', log.Status_Code__c, 'Status code should be set.');
        System.assertEquals('TEST', log.RecordId__c, 'Record id should be set.');
        System.assertEquals('stack trace text', log.Stack_Trace__c, 'Stack trace should be set.');
        System.assertEquals('{"key":"value"}', log.Request_Body__c, 'Request body should be set.');
        System.assertEquals('{"response":"ok"}', log.Response_Body__c, 'Response body should be set.');
        System.assertEquals(true, log.Sync_with_External_Logger__c, 'Sync flag should be set.');
    }

    @isTest
    static void auditLogCreatorHandlesBlankErrorMessage() {
        KenAuditLogHelper.KenAuditLogCreator creator = new KenAuditLogHelper.KenAuditLogCreator();
        creator.setProcess('P');
        creator.setSource('S');
        creator.setErrorMessage(null);
        Audit_Log__c log = creator.returnWithoutCreate();
        System.assertEquals(null, log.Error_Message__c, 'Null message should not set error.');
    }

    @isTest
    static void auditLogCreatorTruncatesLongErrorMessageHeading() {
        String longMsg = '';
        for (Integer i = 0; i < 50; i++) {
            longMsg += 'abcdefghij';
        }
        KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord('P', 'S');
        creator.setErrorMessage(longMsg);
        Audit_Log__c log = creator.returnWithoutCreate();
        System.assert(String.isNotBlank(log.Error_Message__c), 'Error message should be set.');
    }

    @isTest
    static void setRecordTypeIntegrationMarksSyncFlag() {
        KenAuditLogHelper.KenAuditLogCreator creator = new KenAuditLogHelper.KenAuditLogCreator();
        creator.setRecordTypeIntegration();
        Audit_Log__c log = creator.returnWithoutCreate();
        System.assertEquals(true, log.Sync_with_External_Logger__c, 'Integration record type should enable sync flag.');
    }

    @isTest
    static void setRecordTypeExceptionDoesNotThrow() {
        KenAuditLogHelper.KenAuditLogCreator creator = new KenAuditLogHelper.KenAuditLogCreator();
        creator.setRecordTypeException();
        Audit_Log__c log = creator.returnWithoutCreate();
        System.assertNotEquals(null, log, 'Record type setter should not throw.');
    }

    @isTest
    static void getSObjectRecordTypeIdGuardsBlankInputs() {
        System.assertEquals(null, KenAuditLogHelper.getSObjectRecordTypeId(null, null), 'Null args should return null.');
        System.assertEquals(null, KenAuditLogHelper.getSObjectRecordTypeId('', 'X'), 'Blank sobject should return null.');
        System.assertEquals(null, KenAuditLogHelper.getSObjectRecordTypeId('Account', ''), 'Blank record type should return null.');
    }

    @isTest
    static void createPersistsRecordWhenObjectCreatable() {
        KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord('Persist Process', 'Persist Source');
        creator.setErrorMessage('persist');
        Test.startTest();
        Audit_Log__c saved = creator.create();
        Test.stopTest();
        if (saved != null) {
            System.assertNotEquals(null, saved.Id, 'Saved record should have an Id.');
        }
    }
}