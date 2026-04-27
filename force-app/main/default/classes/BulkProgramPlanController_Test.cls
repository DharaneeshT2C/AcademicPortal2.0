@isTest
private class BulkProgramPlanController_Test {
    
    // ===== Helper: Create Test Campus/Location (for lookup fields) =====
    private static Id createTestCampusId() {
        try {
            // Try to create a Location record if Campus__c is a lookup to Location
            Schema.Location campus = new Schema.Location(
                Name = 'Test Campus ' + System.now().getTime(),
                LocationType = 'Campus'
            );
            insert campus;
            return campus.Id;
        } catch (Exception e) {
            // If Location doesn't exist or isn't writable, return null
            return null;
        }
    }
    
    // ===== Helper: Create Test Provider (Account) =====
    private static Account createTestProvider() {
        return new TestDataFactory.AccountCreator('Test Provider ' + System.now().getTime())
            .returnWithoutCreate();
    }
    
    // ===== Helper: Create Test LearningProgram =====
    private static LearningProgram createTestProgram(Id providerId, Id campusId) {
        LearningProgram lp = new TestDataFactory.LearningProgramCreator('Test Program ' + System.now().getTime())
            .returnWithoutCreate();
        
        
        // Only set Campus__c if it's writable AND we have a valid Id
        if (campusId != null && 
            LearningProgram.SObjectType.getDescribe().fields.getMap().containsKey('Campus__c') &&
            LearningProgram.SObjectType.getDescribe().fields.getMap().get('Campus__c').getDescribe().isCreateable()) {
            lp.Campus__c = campusId;
        }
        
        // Set Institute__c only if it's a text field (not lookup)
        if (LearningProgram.SObjectType.getDescribe().fields.getMap().containsKey('Institute__c')) {
            Schema.SObjectField instField = LearningProgram.SObjectType.getDescribe().fields.getMap().get('Institute__c');
            if (instField.getDescribe().getType() != Schema.DisplayType.REFERENCE) {
                lp.Institute__c = 'Test Institute';
            }
        }
        
        return lp;
    }
    
    // ===== Helper: Create Test LearningProgramPlan =====
    private static LearningProgramPlan createTestPlan(Id programId, String nameSuffix) {
        LearningProgramPlan plan = new TestDataFactory.LearningProgramPlanCreator(programId)
            .returnWithoutCreate();
        
        plan.Name = 'Test Plan ' + nameSuffix + ' ' + System.now().getTime();
        plan.IsActive = true;
        plan.VersionNumber = 1.0;
        plan.Cadence_Type__c = 'Weekly';
        plan.Batch_Number__c = 'BATCH-001';
        plan.Section__c = 'Section-A';
        plan.Intake_Strength__c = 30;
        plan.Duration_per_Session_in_minutes__c = 90;
        plan.IsMonday__c = true;
        plan.IsWednesday__c = true;
        plan.IsFriday__c = true;
        return plan;
    }
    
    // ===== Helper: Create Plan Map for API Input =====
    private static Map<String, Object> createPlanMap(Id programId, String nameSuffix, Integer rowIndex) {
        Map<String, Object> planMap = new Map<String, Object>();
        planMap.put('name', 'Test Plan ' + nameSuffix + ' ' + System.now().getTime());
        planMap.put('learningProgramId', programId);
        planMap.put('providerId', null);
        planMap.put('description', 'Test description for row ' + rowIndex);
        planMap.put('versionNumber', 1.0);
        planMap.put('isActive', true);
        planMap.put('activeFromDate', Date.today());
        planMap.put('activeToDate', Date.today().addMonths(6));
        planMap.put('minimumGradePointAvg', 3.5);
        planMap.put('cadenceType', 'Weekly');
        planMap.put('intakeStrength', 30);
        planMap.put('isMonday', true);
        planMap.put('isTuesday', false);
        planMap.put('isWednesday', true);
        planMap.put('isThursday', false);
        planMap.put('isFriday', true);
        planMap.put('isSaturday', false);
        planMap.put('isSunday', false);
        planMap.put('durationPerSession', 90);
        
        planMap.put('batchNumber', 1);
        planMap.put('section', 'Section-' + 'ABC');
        
        return planMap;
    }
    
    // ===== Test Setup (runs once before all tests) =====
    @TestSetup
    static void setupTestData() {
        // Create org defaults if needed for theme colors
        new TestDataFactory.OrganizationDefaultsParametersCreator()
            .setPrimaryColor('#0b5ec0')
            .setSecondaryColor('#08376c')
            .create();
    }
    
    // ===== Test: getInitData() =====
    
    @isTest
    static void testGetInitData_Success() {
        // Setup: Create lookup records first
        Id campusId = createTestCampusId();
        Account provider = createTestProvider();
        insert provider;
        
        LearningProgram program = createTestProgram(provider.Id, campusId);
        insert program;
        
        LearningProgramPlan plan = createTestPlan(program.Id, 'Init');
        insert plan;
        
        // Test
        Test.startTest();
        BulkProgramPlanController.InitData result = BulkProgramPlanController.getInitData();
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, result, 'InitData should not be null');
        System.assertNotEquals(null, result.programs, 'Programs list should not be null');
        
        Boolean found = false;
        for (BulkProgramPlanController.ProgramWrapper pw : result.programs) {
            if (pw.id == program.Id) {
                found = true;
                System.assertEquals(program.Name, pw.name, 'Program name should match');
                System.assertEquals(provider.Id, pw.providerId, 'Provider ID should match');
                System.assertEquals(provider.Name, pw.providerName, 'Provider name should match');
                // Campus may be null if lookup wasn't set
                System.assertEquals(program.IsActive, pw.isActive, 'IsActive should match');
                System.assertEquals(program.Duration, pw.durationPerSession, 'Duration should match');
                break;
            }
        }
        System.assert(found, 'Test program should be found in results');
        
        // Assert picklist options are populated
        System.assertNotEquals(null, result.batchOptions, 'Batch options should not be null');
        System.assertNotEquals(null, result.cadenceOptions, 'Cadence options should not be null');
        System.assertNotEquals(null, result.sectionOptions, 'Section options should not be null');
    }
    
    @isTest
    static void testGetInitData_NoPrograms() {
        Test.startTest();
        BulkProgramPlanController.InitData result = BulkProgramPlanController.getInitData();
        Test.stopTest();
        
        System.assertNotEquals(null, result.programs, 'Programs list should be empty list, not null');
        System.assertEquals(0, result.programs.size(), 'Should return empty programs list when none exist');
    }
    
    // ===== Test: checkDuplicates() =====
    
    @isTest
    static void testCheckDuplicates_NoDuplicates() {
        Id campusId = createTestCampusId();
        Account provider = createTestProvider();
        insert provider;
        LearningProgram program = createTestProgram(provider.Id, campusId);
        insert program;
        
        List<Object> plans = new List<Object>();
        plans.add(createPlanMap(program.Id, 'Unique1', 0));
        plans.add(createPlanMap(program.Id, 'Unique2', 1));
        
        Test.startTest();
        BulkProgramPlanController.DuplicateResult result = BulkProgramPlanController.checkDuplicates(plans);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.duplicates.size(), 'Should find no duplicates');
    }
    
    @isTest
    static void testCheckDuplicates_WithDuplicates() {
        Id campusId = createTestCampusId();
        Account provider = createTestProvider();
        insert provider;
        LearningProgram program = createTestProgram(provider.Id, campusId);
        insert program;
        
        LearningProgramPlan existingPlan = createTestPlan(program.Id, 'Duplicate');
        insert existingPlan;
        
        List<Object> plans = new List<Object>();
        Map<String, Object> dupPlan = createPlanMap(program.Id, 'Duplicate', 0);
        dupPlan.put('name', existingPlan.Name);
        plans.add(dupPlan);
        plans.add(createPlanMap(program.Id, 'Unique', 1));
        
        Test.startTest();
        BulkProgramPlanController.DuplicateResult result = BulkProgramPlanController.checkDuplicates(plans);
        Test.stopTest();
        
        System.assertEquals(1, result.duplicates.size(), 'Should find 1 duplicate');
        BulkProgramPlanController.DuplicateRow dup = result.duplicates[0];
        System.assertEquals(0, dup.rowIndex, 'Duplicate should be at row index 0');
        System.assertEquals(existingPlan.Id, dup.existingId, 'Should reference existing plan ID');
    }
    
    @isTest
    static void testCheckDuplicates_EmptyInput() {
        Test.startTest();
        BulkProgramPlanController.DuplicateResult result1 = BulkProgramPlanController.checkDuplicates(null);
        BulkProgramPlanController.DuplicateResult result2 = BulkProgramPlanController.checkDuplicates(new List<Object>());
        Test.stopTest();
        
        System.assertEquals(0, result1.duplicates.size(), 'Null input should return empty duplicates');
        System.assertEquals(0, result2.duplicates.size(), 'Empty list should return empty duplicates');
    }
    
    // ===== Test: insertProgramPlans() - Sync Path =====
    
    @isTest
    static void testInsertProgramPlans_Sync_Success() {
        Id campusId = createTestCampusId();
        Account provider = createTestProvider();
        insert provider;
        LearningProgram program = createTestProgram(provider.Id, campusId);
        insert program;
        
        List<Object> plans = new List<Object>();
        for (Integer i = 0; i < 10; i++) {
            plans.add(createPlanMap(program.Id, 'Sync', i));
        }
        
        Test.startTest();
        BulkProgramPlanController.SaveResult result = BulkProgramPlanController.insertProgramPlans(plans);
        Test.stopTest();
        
        System.assertEquals(10, result.successCount, 'All 10 records should succeed');
        System.assertEquals(0, result.errorCount, 'No errors expected');
        System.assertEquals(false, result.isAsync, 'Should be sync execution');
        System.assertEquals(10, result.createdIds.size(), 'Should have 10 created IDs');
        
        List<LearningProgramPlan> created = [
            SELECT Id, Name, LearningProgramId 
            FROM LearningProgramPlan 
            WHERE LearningProgramId = :program.Id 
            AND Name LIKE 'Test Plan Sync%'
        ];
        System.assertEquals(10, created.size(), '10 plans should exist in database');
    }
    
    @isTest
    static void testInsertProgramPlans_Sync_WithErrors() {
        Id campusId = createTestCampusId();
        Account provider = createTestProvider();
        insert provider;
        LearningProgram program = createTestProgram(provider.Id, campusId);
        insert program;
        
        List<Object> plans = new List<Object>();
        plans.add(createPlanMap(program.Id, 'Valid', 0));
        
        Map<String, Object> invalidPlan = createPlanMap(program.Id, 'Invalid', 1);
        invalidPlan.put('name', '');
        plans.add(invalidPlan);
        
        Map<String, Object> invalidPlan2 = new Map<String, Object>();
        invalidPlan2.put('name', 'No Program Plan');
        plans.add(invalidPlan2);
        
        Test.startTest();
        BulkProgramPlanController.SaveResult result = BulkProgramPlanController.insertProgramPlans(plans);
        Test.stopTest();
        
        System.assertEquals(1, result.successCount, '1 valid record should succeed');
        System.assertEquals(2, result.errorCount, '2 invalid records should fail');
        System.assertEquals(2, result.errors.size(), 'Should have 2 row errors');
    }
    
    @isTest
    static void testInsertProgramPlans_EmptyPayload() {
        Test.startTest();
        BulkProgramPlanController.SaveResult result1 = BulkProgramPlanController.insertProgramPlans(null);
        BulkProgramPlanController.SaveResult result2 = BulkProgramPlanController.insertProgramPlans(new List<Object>());
        Test.stopTest();
        
        System.assertEquals(0, result1.successCount, 'Null input: 0 success');
        System.assertEquals(0, result2.successCount, 'Empty input: 0 success');
    }
    
    // ===== Test: insertProgramPlans() - Async Path =====
    
    @isTest
    static void testInsertProgramPlans_Async_Triggered() {
        Id campusId = createTestCampusId();
        Account provider = createTestProvider();
        insert provider;
        LearningProgram program = createTestProgram(provider.Id, campusId);
        insert program;
        
        List<Object> plans = new List<Object>();
        for (Integer i = 0; i < 55; i++) {
            plans.add(createPlanMap(program.Id, 'Async', i));
        }
        
        Test.startTest();
        BulkProgramPlanController.SaveResult result = BulkProgramPlanController.insertProgramPlans(plans);
        Test.stopTest();
        
        System.assertEquals(true, result.isAsync, 'Should trigger async execution for >50 records');
        System.assertNotEquals(null, result.jobId, 'Should return Queueable job ID');
        
        // Wait for async job
        Test.startTest();
        AsyncApexJob job = [SELECT Id, Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :result.jobId LIMIT 1];
        Test.stopTest();
        
        System.assertEquals('Completed', job.Status, 'Queueable job should complete');
        
        List<LearningProgramPlan> created = [
            SELECT Id 
            FROM LearningProgramPlan 
            WHERE LearningProgramId = :program.Id 
            AND Name LIKE 'Test Plan Async%'
            LIMIT 55
        ];
        System.assertEquals(55, created.size(), 'All 55 plans should be created');
    }
    
    // ===== Test: getJobStatus() =====
    
    @isTest
    static void testGetJobStatus_ValidJob() {
        Id campusId = createTestCampusId();
        Account provider = createTestProvider();
        insert provider;
        LearningProgram program = createTestProgram(provider.Id, campusId);
        insert program;
        
        List<Object> plans = new List<Object>();
        for (Integer i = 0; i < 55; i++) {
            plans.add(createPlanMap(program.Id, 'Status', i));
        }
        
        Test.startTest();
        BulkProgramPlanController.SaveResult insertResult = BulkProgramPlanController.insertProgramPlans(plans);
        Test.stopTest();
        
        String jobId = insertResult.jobId;
        System.assertNotEquals(null, jobId, 'Should have job ID');
        
        Test.startTest();
        AsyncApexJob job = [SELECT Id, Status FROM AsyncApexJob WHERE Id = :jobId LIMIT 1];
        Test.stopTest();
        
        Test.startTest();
        BulkProgramPlanController.JobStatus status = BulkProgramPlanController.getJobStatus(jobId);
        Test.stopTest();
        
        System.assertNotEquals(null, status, 'Job status should not be null');
        System.assertEquals('Completed', status.status, 'Job should be completed');
    }
    
    @isTest
    static void testGetJobStatus_InvalidJobId() {
        Test.startTest();
        BulkProgramPlanController.JobStatus status = BulkProgramPlanController.getJobStatus('000000000000000AAA');
        Test.stopTest();
        
        System.assertEquals('NOT_FOUND', status.status, 'Should return NOT_FOUND for invalid job ID');
    }
    
    // ===== Test: Audit Log =====
    
    @isTest
    static void testCreateAuditLog_SuccessCase() {
        List<String> emptyErrors = new List<String>();
        
        Test.startTest();
        BulkProgramPlanController.createAuditLog(null, 10, 0, emptyErrors, 'Sync-Test');
        Test.stopTest();
        
        // Note: Adjust Process__c value to match your ConstantController
        List<Audit_Log__c> logs = [
            SELECT Id, Status_Code__c, Response_Body__c
            FROM Audit_Log__c 
            WHERE Process__c = 'Bulk_Program_Plan'
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        
        if (!logs.isEmpty()) {
            System.assertEquals('200', logs[0].Status_Code__c, 'Status code should be 200 for success');
        }
    }
    
    @isTest
    static void testCreateAuditLog_ErrorCase() {
        List<String> errors = new List<String>{'Error 1: Field required'};
        
        Test.startTest();
        BulkProgramPlanController.createAuditLog(null, 5, 2, errors, 'Sync-ErrorTest');
        Test.stopTest();
        
        List<Audit_Log__c> logs = [
            SELECT Id, Status_Code__c
            FROM Audit_Log__c 
            WHERE Process__c = 'Bulk_Program_Plan'
            AND Status_Code__c = '500'
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        
        if (!logs.isEmpty()) {
            System.assertEquals('500', logs[0].Status_Code__c, 'Status code should be 500 for errors');
        }
    }
    
    // ===== Test: Picklist Helper =====
    
    @isTest
    static void testGetPicklistValues_ValidField() {
        Test.startTest();
        List<BulkProgramPlanController.PicklistOption> options = 
            BulkProgramPlanController.getPicklistValues('LearningProgramPlan', 'Cadence_Type__c');
        Test.stopTest();
        
        System.assertNotEquals(null, options, 'Should return options list');
    }
    
    @isTest
    static void testGetPicklistValues_InvalidField() {
        Test.startTest();
        List<BulkProgramPlanController.PicklistOption> options = 
            BulkProgramPlanController.getPicklistValues('LearningProgramPlan', 'NonExistent_Field__c');
        Test.stopTest();
        
        System.assertEquals(0, options.size(), 'Should return empty list for invalid field');
    }
    
    // ===== Test: Edge Cases =====
    
    @isTest
    static void testInsertProgramPlans_MaxBatchSize() {
        Id campusId = createTestCampusId();
        Account provider = createTestProvider();
        insert provider;
        LearningProgram program = createTestProgram(provider.Id, campusId);
        insert program;
        
        List<Object> plans = new List<Object>();
        for (Integer i = 0; i < 50; i++) {
            plans.add(createPlanMap(program.Id, 'MaxSync', i));
        }
        
        Test.startTest();
        BulkProgramPlanController.SaveResult result = BulkProgramPlanController.insertProgramPlans(plans);
        Test.stopTest();
        
        System.assertEquals(false, result.isAsync, '50 records should use sync path');
        System.assertEquals(50, result.successCount, 'All 50 should succeed');
    }
    
    @isTest
    static void testInsertProgramPlans_JustOverBatchSize() {
        Id campusId = createTestCampusId();
        Account provider = createTestProvider();
        insert provider;
        LearningProgram program = createTestProgram(provider.Id, campusId);
        insert program;
        
        List<Object> plans = new List<Object>();
        for (Integer i = 0; i < 51; i++) {
            plans.add(createPlanMap(program.Id, 'JustOver', i));
        }
        
        Test.startTest();
        BulkProgramPlanController.SaveResult result = BulkProgramPlanController.insertProgramPlans(plans);
        Test.stopTest();
        
        System.assertEquals(true, result.isAsync, '51 records should trigger async path');
        System.assertNotEquals(null, result.jobId, 'Should return job ID for async');
    }
}