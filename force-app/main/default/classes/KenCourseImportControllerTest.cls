@isTest(SeeAllData=false)
private class KenCourseImportControllerTest {

    @TestSetup
    static void makeData() {
        User testUser = new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias('coursec')
            .create();

        List<PermissionSet> permissionSets = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = 'System_Admin_Permission'
            LIMIT 1
        ];
        if (!permissionSets.isEmpty()) {
            insert new PermissionSetAssignment(
                AssigneeId = testUser.Id,
                PermissionSetId = permissionSets[0].Id
            );
        }
    }

    private static User getRunUser() {
        return [SELECT Id FROM User WHERE Alias = 'coursec' LIMIT 1];
    }

    private static Boolean hasAuditLogObject() {
        return Schema.getGlobalDescribe().containsKey('Audit_Log__c');
    }

    private static Map<String, Schema.SObjectField> auditLogFields() {
        return Audit_Log__c.SObjectType.getDescribe().fields.getMap();
    }

    private static void insertAuditLog(Id jobId, String processName, String errorMessage, String stackTrace) {
        Audit_Log__c log = new Audit_Log__c();
        Map<String, Schema.SObjectField> fields = auditLogFields();

        if (fields.containsKey('Process__c')) {
            log.put('Process__c', processName);
        }
        if (fields.containsKey('RecordId__c')) {
            log.put('RecordId__c', String.valueOf(jobId));
        }
        if (fields.containsKey('Error_Message__c')) {
            log.put('Error_Message__c', errorMessage);
        }
        if (fields.containsKey('Stack_Trace__c')) {
            log.put('Stack_Trace__c', stackTrace);
        }

        insert log;
    }

    @isTest
    static void testStartBatchAndErrors() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Learning') || !gd.containsKey('LearningCourse')) {
            return;
        }

        System.runAs(getRunUser()) {
            Map<String, Object> row = new Map<String, Object>{
                'RowNumber' => '1',
                'Name' => 'Course A',
                'CourseNumber' => 'COURSE-001'
            };
            String jsonRows = JSON.serialize(new List<Object>{ row });

            Test.startTest();
            Id jobId = KenCourseImportController.startCourseImportBatch(jsonRows, null, null);
            Test.stopTest();

            System.assertNotEquals(null, jobId, 'Batch job id should be returned.');
            System.assertNotEquals(null, KenCourseImportController.getCourseImportErrors(jobId));
            System.assertNotEquals(null, KenCourseImportController.getCourseImportErrorsLegacy(jobId));
            System.assertNotEquals(null, KenCourseImportController.getCourseImportResult(jobId));
        }
    }

    @isTest
    static void testGetCourseImportResultWithNullJobId() {
        KenCourseImportController.CourseImportResult result =
            KenCourseImportController.getCourseImportResult(null);

        System.assertNotEquals(null, result, 'Null job id should still return a result.');
        System.assertEquals(0, result.errors.size(), 'Errors should be empty for a null job id.');
        System.assertEquals(0, result.insertedCount, 'Inserted count should default to zero.');
        System.assertEquals(0, result.updatedCount, 'Updated count should default to zero.');
        System.assertEquals(0, KenCourseImportController.getCourseImportErrors(null).size());
        System.assertEquals(0, KenCourseImportController.getCourseImportErrorsLegacy(null).size());
    }

    @isTest
    static void testGetCourseImportResultParsesSummaryCompletionAndErrors() {
        if (!hasAuditLogObject()) {
            return;
        }

        System.runAs(getRunUser()) {
            Id fakeJobId = '707000000000009AAA';
            insertAuditLog(fakeJobId, 'Course Import', 'Course Import Summary: inserted=3; updated=2', null);
            insertAuditLog(fakeJobId, 'Course Import', 'Course Import Batch Completed without errors', null);
            insertAuditLog(fakeJobId, 'Course Import', 'Regular validation failure', 'stacktrace here');
            insertAuditLog(fakeJobId, 'Course Import', '   ', 'fallback stack trace');
            insertAuditLog(fakeJobId, 'Course Import', null, null);

            Boolean canReadLogs = KenCourseImportController.canReadCourseImportAuditLogs();

            Test.startTest();
            KenCourseImportController.CourseImportResult result =
                KenCourseImportController.getCourseImportResult(fakeJobId);
            List<String> legacyErrors = KenCourseImportController.getCourseImportErrorsLegacy(fakeJobId);
            Test.stopTest();

            if (canReadLogs) {
                System.assertEquals(3, result.insertedCount, 'Inserted count should be parsed from the summary.');
                System.assertEquals(2, result.updatedCount, 'Updated count should be parsed from the summary.');
                System.assertEquals(2, result.errors.size(), 'Only the standard error and stack-only log should remain.');
                System.assert(result.errors.contains('Regular validation failure'));
                System.assert(result.errors.contains('fallback stack trace'));
            } else {
                System.assertEquals(0, result.insertedCount, 'Counts remain at defaults when audit logs are not readable.');
                System.assertEquals(0, result.updatedCount, 'Counts remain at defaults when audit logs are not readable.');
                System.assertEquals(0, result.errors.size(), 'Errors remain empty when audit logs are not readable.');
            }

            System.assertEquals(result.errors, legacyErrors, 'Legacy method should return the same errors.');
        }
    }

    @isTest
    static void testGetCourseImportResultFallsBackWhenProcessSpecificLogsMissing() {
        if (!hasAuditLogObject()) {
            return;
        }

        System.runAs(getRunUser()) {
            Id fakeJobId = '707000000000001AAA';
            insertAuditLog(fakeJobId, 'Other Process', 'Fallback error', null);
            Boolean canReadLogs = KenCourseImportController.canReadCourseImportAuditLogs();

            Test.startTest();
            KenCourseImportController.CourseImportResult result =
                KenCourseImportController.getCourseImportResult(fakeJobId);
            Test.stopTest();

            if (canReadLogs) {
                System.assertEquals(1, result.errors.size(), 'Fallback query should return logs when process-specific logs are absent.');
                System.assertEquals('Fallback error', result.errors[0]);
            } else {
                System.assertEquals(0, result.errors.size(), 'Errors remain empty when audit logs are not readable.');
            }
        }
    }

    @isTest
    static void testCourseImportResultConstructorDefaults() {
        KenCourseImportController.CourseImportResult result = new KenCourseImportController.CourseImportResult();

        System.assertNotEquals(null, result.errors, 'Errors list should be initialized.');
        System.assertEquals(0, result.errors.size(), 'Errors list should start empty.');
        System.assertEquals(0, result.insertedCount, 'Inserted count should default to zero.');
        System.assertEquals(0, result.updatedCount, 'Updated count should default to zero.');
    }

    @isTest
    static void testHelperMethods() {
        Test.startTest();
        Boolean completionTrue =
            KenCourseImportController.isCompletionMessage('COURSE IMPORT BATCH COMPLETED: 10 records processed');
        Boolean completionFalse = KenCourseImportController.isCompletionMessage('regular error');
        Boolean completionBlank = KenCourseImportController.isCompletionMessage(null);
        Boolean summaryTrue =
            KenCourseImportController.isSummaryMessage('Course Import Summary: inserted=2; updated=1');
        Boolean summaryFalse = KenCourseImportController.isSummaryMessage('Course import finished');
        Boolean summaryBlank = KenCourseImportController.isSummaryMessage('   ');

        KenCourseImportController.CourseImportResult result = new KenCourseImportController.CourseImportResult();
        KenCourseImportController.applySummary(result, 'Course Import Summary: inserted=9; updated=4');
        KenCourseImportController.applySummary(result, 'Course Import Summary: foo; inserted=x; updated=3; extra=1');
        KenCourseImportController.applySummary(result, null);
        KenCourseImportController.applySummary(null, 'Course Import Summary: inserted=1; updated=1');
        Boolean canReadLogs = KenCourseImportController.canReadCourseImportAuditLogs();
        Test.stopTest();

        System.assertEquals(true, completionTrue);
        System.assertEquals(false, completionFalse);
        System.assertEquals(false, completionBlank);
        System.assertEquals(true, summaryTrue);
        System.assertEquals(false, summaryFalse);
        System.assertEquals(false, summaryBlank);
        System.assertEquals(9, result.insertedCount, 'Invalid inserted token should be ignored and prior valid value retained.');
        System.assertEquals(3, result.updatedCount, 'Latest valid updated token should be applied.');
        System.assertNotEquals(null, canReadLogs, 'Accessibility helper should return a boolean.');
    }

    @isTest
    static void testStartCourseImportBatchCatchBlock() {
        System.runAs(getRunUser()) {
            KenCourseImportController.forceStartCourseImportBatchException = true;

            Test.startTest();
            try {
                KenCourseImportController.startCourseImportBatch('[]', null, null);
                System.assert(false, 'An exception should have been thrown.');
            } catch (Exception e) {
                System.assertNotEquals(null, e, 'Forced exception should be rethrown by the controller.');
            }
            Test.stopTest();

            KenCourseImportController.forceStartCourseImportBatchException = false;
        }
    }

    @isTest
    static void testGetCourseImportResultCatchBlock() {
        if (!hasAuditLogObject()) {
            return;
        }

        System.runAs(getRunUser()) {
            Id fakeJobId = '707000000000007AAA';
            Boolean canReadLogs = KenCourseImportController.canReadCourseImportAuditLogs();
            if (!canReadLogs) {
                return;
            }

            KenCourseImportController.forceGetCourseImportResultException = true;

            Test.startTest();
            KenCourseImportController.CourseImportResult result =
                KenCourseImportController.getCourseImportResult(fakeJobId);
            Test.stopTest();

            KenCourseImportController.forceGetCourseImportResultException = false;

            System.assertEquals(1, result.errors.size(), 'Forced exception should add one controller-level error.');
            System.assert(result.errors[0].startsWith('Error fetching audit logs:'),
                'Controller catch block should add the fetch error prefix.');
        }
    }
}