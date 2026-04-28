@isTest(SeeAllData=false)
/**
 * @description
 *
 * Usage:
 *  - No direct callers found
 */
private class KenAuditLogHelperTest {
    @isTest
    static void testAuditLogCreatorBuildsRecord() {
        KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord('Test Process', 'Test Source');
        creator.setErrorMessage('Test error message');
        creator.setStatusCode('500');
        creator.setRecordId('TEST');
        Audit_Log__c log = creator.returnWithoutCreate();
        System.assertNotEquals(null, log, 'Audit log record should be built');
        System.assertEquals('Test Process', log.Process__c);
    }
}