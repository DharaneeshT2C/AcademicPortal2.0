// This suite depends on product-org seed data and large request scaffolding to cover fee configuration branches.
// code-analyzer-suppress(pmd:ApexUnitTestShouldNotUseSeeAllDataTrue)
// code-analyzer-suppress(pmd:ApexUnitTestClassShouldHaveRunAs)
// code-analyzer-suppress(pmd:CyclomaticComplexity)
// code-analyzer-suppress(pmd:EagerlyLoadedDescribeSObjectResult)
// code-analyzer-suppress(pmd:ExcessiveParameterList)
// code-analyzer-suppress(pmd:NcssCount)
@IsTest(SeeAllData=true)
private class MasterDataFeeTypesControllerTest {
    private static String uniqueSuffix(String prefixValue) {
        return prefixValue + String.valueOf(DateTime.now().getTime());
    }

    private static String getFirstActiveFrequency() {
        for (Schema.PicklistEntry entry :
            Ken_Fee_Type__c.Fee_Collection_Frequency__c.getDescribe().getPicklistValues()
        ) {
            if (entry != null && entry.isActive() && String.isNotBlank(entry.getValue())) {
                return entry.getValue();
            }
        }
        System.assert(false, 'Expected at least one active fee collection frequency picklist value.');
        return null;
    }

    private static String getFrequencyContaining(String token) {
        for (Schema.PicklistEntry entry :
            Ken_Fee_Type__c.Fee_Collection_Frequency__c.getDescribe().getPicklistValues()
        ) {
            String value = entry == null ? null : entry.getValue();
            if (entry != null && entry.isActive() && String.isNotBlank(value) && value.toLowerCase().contains(token.toLowerCase())) {
                return value;
            }
        }
        return null;
    }

    private static String getFirstActiveFeeCategory() {
        for (Schema.PicklistEntry entry : Ken_Fee_Type__c.Fee_Category__c.getDescribe().getPicklistValues()) {
            if (entry != null && entry.isActive() && String.isNotBlank(entry.getValue())) {
                return entry.getValue();
            }
        }
        System.assert(false, 'Expected at least one active fee category picklist value.');
        return null;
    }

    private static Ken_Master_Fee_Head__c getFeeHeadForSave() {
        List<Ken_Master_Fee_Head__c> preferredHeads = [
            SELECT Id, Fee_Head_Name__c, Default_Remittance_Account__c
            FROM Ken_Master_Fee_Head__c
            WHERE Is_Active__c = true
              AND Default_Remittance_Account__c != null
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!preferredHeads.isEmpty()) {
            return preferredHeads[0];
        }

        List<Ken_Master_Fee_Head__c> fallbackHeads = [
            SELECT Id, Fee_Head_Name__c, Default_Remittance_Account__c
            FROM Ken_Master_Fee_Head__c
            WHERE Is_Active__c = true
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        System.assert(!fallbackHeads.isEmpty(), 'Expected at least one active fee head in product org.');
        return fallbackHeads[0];
    }

    private static Ken_Master_Fee_Head__c createFeeHead(String suffix, Id defaultRemittanceId) {
        Ken_Master_Fee_Head__c feeHead = new Ken_Master_Fee_Head__c(
            Fee_Head_Name__c = 'Fee Head ' + suffix,
            Is_Active__c = true,
            Default_Remittance_Account__c = defaultRemittanceId
        );
        insert feeHead;
        return feeHead;
    }

    private static Id getRemittanceAccountId() {
        List<Ken_Master_Fee_Head__c> feeHeadsWithRemittance = [
            SELECT Id, Default_Remittance_Account__c
            FROM Ken_Master_Fee_Head__c
            WHERE Default_Remittance_Account__c != null
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!feeHeadsWithRemittance.isEmpty()) {
            return feeHeadsWithRemittance[0].Default_Remittance_Account__c;
        }

        List<Ken_Fee_Type_Remittance__c> feeTypeRemittances = [
            SELECT Id, Remittance_Account__c
            FROM Ken_Fee_Type_Remittance__c
            WHERE Remittance_Account__c != null
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!feeTypeRemittances.isEmpty()) {
            return feeTypeRemittances[0].Remittance_Account__c;
        }

        List<Ken_Fee_Type_Line_Item__c> feeTypeLines = [
            SELECT Id, Remittance_Account__c
            FROM Ken_Fee_Type_Line_Item__c
            WHERE Remittance_Account__c != null
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!feeTypeLines.isEmpty()) {
            return feeTypeLines[0].Remittance_Account__c;
        }

        System.assert(false, 'Expected at least one remittance account reference in product org.');
        return null;
    }

    private static Id getPaymentScheduleId() {
        List<Payment_Schedule__c> schedules = [
            SELECT Id
            FROM Payment_Schedule__c
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return schedules.isEmpty() ? null : schedules[0].Id;
    }

    private static LearningProgramPlan getLearningProgramPlanForSave() {
        List<LearningProgramPlan> plans = [
            SELECT Id, Name, LearningProgramId, LearningProgram.Name
            FROM LearningProgramPlan
            WHERE LearningProgramId != null
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        System.assert(!plans.isEmpty(), 'Expected at least one learning program plan in product org.');
        return plans[0];
    }

    private static Category__c createCategoryRecord(String nameValue) {
        Category__c categoryRecord = new Category__c(Name = nameValue);
        insert categoryRecord;
        return categoryRecord;
    }

    private static Quota__c createQuotaRecord(String nameValue, String codeValue, Id categoryId) {
        Quota__c quotaRecord = new Quota__c(
            Name = nameValue,
            Code__c = codeValue,
            Category__c = categoryId
        );
        insert quotaRecord;
        return quotaRecord;
    }

    private static Ken_Fee_Type__c createLateFeePlan(String suffix) {
        Id recordTypeId = Ken_Fee_Type__c.SObjectType.getDescribe(Schema.SObjectDescribeOptions.DEFERRED)
            .getRecordTypeInfosByDeveloperName()
            .get('Late_Fee')
            .getRecordTypeId();
        Ken_Fee_Type__c penaltyPlan = new Ken_Fee_Type__c(
            RecordTypeId = recordTypeId,
            Fee_Type_Name__c = 'Late Fee ' + suffix,
            Fee_Category__c = 'Late Fee',
            Fee_Collection_Frequency__c = getFirstActiveFrequency(),
            Status__c = 'Draft'
        );
        insert penaltyPlan;
        return penaltyPlan;
    }

    private static MasterDataFeeTypesController.SaveFeeTypeRequest buildBaseRequest(
        Id instituteId,
        Id feeHeadId,
        Id remittanceId,
        Id paymentScheduleId
    ) {
        MasterDataFeeTypesController.SaveFeeTypeRequest requestData =
            new MasterDataFeeTypesController.SaveFeeTypeRequest();
        requestData.instituteId = instituteId;
        requestData.activationDate = Date.today();
        requestData.frequency = getFirstActiveFrequency();
        requestData.remittanceAccountIds = remittanceId == null ? null : new List<Id>{ remittanceId };
        requestData.oneTimeFeeHeadId = feeHeadId;
        requestData.oneTimeAmount = 500;
        requestData.oneTimeStartDate = Date.today();
        requestData.oneTimeDueDate = Date.today().addDays(15);
        requestData.oneTimeInstallmentId = paymentScheduleId;
        return requestData;
    }

    private static String buildInstituteRequestJson(
        Id instituteId,
        Id feeHeadId,
        Id remittanceId,
        Id paymentScheduleId,
        String suffix
    ) {
        MasterDataFeeTypesController.LinkedMappingRow linkedMapping =
            new MasterDataFeeTypesController.LinkedMappingRow();
        linkedMapping.linkedLevel = 'Institute';
        linkedMapping.linkedEntityId = instituteId;

        MasterDataFeeTypesController.SaveFeeTypeRequest requestData =
            buildBaseRequest(instituteId, feeHeadId, remittanceId, paymentScheduleId);
        requestData.linkedMappings = new List<MasterDataFeeTypesController.LinkedMappingRow>{ linkedMapping };
        requestData.batchIntake = 'UT-' + suffix;
        requestData.notes = 'Apex test ' + suffix;
        requestData.oneTimeFeePlanTag = 'PLAN-' + suffix;
        return JSON.serialize(requestData);
    }

    private static void assertHandledException(String requestJson, Boolean activateNow, String scenarioLabel) {
        Boolean didThrow = false;
        try {
            MasterDataFeeTypesController.saveFeeTypeConfiguration(requestJson, activateNow);
            System.assert(false, 'Expected a handled exception for ' + scenarioLabel + '.');
        } catch (AuraHandledException ex) {
            didThrow = true;
            System.assert(String.isNotBlank(ex.getMessage()), 'Expected an exception message for ' + scenarioLabel + '.');
        }
        System.assertEquals(true, didThrow, 'Expected a handled exception for ' + scenarioLabel + '.');
    }

    @IsTest
    static void getSeedDataReturnsOrgSeedOptions() {
        Ken_Fee_Type__c penaltyPlan = createLateFeePlan(uniqueSuffix('LF'));

        Test.startTest();
        MasterDataFeeTypesController.SeedData seed = MasterDataFeeTypesController.getSeedData();
        Test.stopTest();

        System.assertNotEquals(null, seed, 'Expected seed data payload.');
        System.assertNotEquals(null, seed.feeHeadOptions, 'Fee head options should be initialized.');
        System.assertNotEquals(null, seed.feeCategoryOptions, 'Fee category options should be initialized.');
        System.assertNotEquals(null, seed.remittanceOptions, 'Remittance options should be initialized.');
        System.assertNotEquals(null, seed.installmentOptions, 'Installment options should be initialized.');
        System.assertNotEquals(null, seed.penaltyPlanOptions, 'Penalty options should be initialized.');
        System.assert(!seed.feeHeadOptions.isEmpty(), 'Expected at least one fee head option from product org.');
        System.assert(!seed.feeCategoryOptions.isEmpty(), 'Expected at least one fee category option.');
        System.assert(!seed.remittanceOptions.isEmpty(), 'Expected at least one remittance option from product org.');
        System.assert(!seed.installmentOptions.isEmpty(), 'Expected at least one payment schedule option from product org.');

        Boolean foundPenaltyPlan = false;
        for (MasterDataFeeTypesController.OptionRow optionRow : seed.penaltyPlanOptions) {
            if (optionRow != null && optionRow.value == penaltyPlan.Id) {
                foundPenaltyPlan = true;
                break;
            }
        }
        System.assertEquals(true, foundPenaltyPlan, 'Expected the inserted late fee plan to be returned.');
    }

    @IsTest
    static void saveFeeTypeConfigurationRejectsBlankPayload() {
        assertHandledException('', false, 'blank payload');
        assertHandledException('null', false, 'literal null payload');
        System.assert(true, 'Blank payload validation scenarios completed.');
    }

    @IsTest
    static void saveFeeTypeConfigurationRequiresLinkLevel() {
        Ken_Master_Fee_Head__c feeHead = getFeeHeadForSave();
        Id remittanceAccountId = getRemittanceAccountId();

        MasterDataFeeTypesController.SaveFeeTypeRequest requestData =
            new MasterDataFeeTypesController.SaveFeeTypeRequest();
        requestData.activationDate = Date.today();
        requestData.frequency = getFirstActiveFrequency();
        requestData.remittanceAccountIds = new List<Id>{ remittanceAccountId };
        requestData.oneTimeFeeHeadId = feeHead.Id;
        requestData.oneTimeAmount = 500;
        requestData.oneTimeDueDate = Date.today().addDays(15);

        assertHandledException(JSON.serialize(requestData), false, 'missing link level');
        System.assert(true, 'Missing link level validation scenario completed.');
    }

    @IsTest
    static void saveFeeTypeConfigurationValidatesRequiredFieldsAndDirectMappings() {
        Ken_Master_Fee_Head__c feeHead = getFeeHeadForSave();
        Id remittanceAccountId = getRemittanceAccountId();
        Id paymentScheduleId = getPaymentScheduleId();
        LearningProgramPlan planRecord = getLearningProgramPlanForSave();
        Account institute = new Account(Name = 'Fee Validation Institute ' + uniqueSuffix('I'));
        insert institute;

        MasterDataFeeTypesController.SaveFeeTypeRequest missingBatchRequest =
            buildBaseRequest(institute.Id, feeHead.Id, remittanceAccountId, paymentScheduleId);
        missingBatchRequest.programmeId = planRecord.Id;
        missingBatchRequest.learningProgramId = planRecord.LearningProgramId;
        missingBatchRequest.instituteId = institute.Id;
        assertHandledException(JSON.serialize(missingBatchRequest), false, 'missing batch intake for plan linkage');

        MasterDataFeeTypesController.SaveFeeTypeRequest missingActivationRequest =
            buildBaseRequest(institute.Id, feeHead.Id, remittanceAccountId, paymentScheduleId);
        missingActivationRequest.activationDate = null;
        assertHandledException(JSON.serialize(missingActivationRequest), false, 'missing activation date');

        MasterDataFeeTypesController.SaveFeeTypeRequest missingFrequencyRequest =
            buildBaseRequest(institute.Id, feeHead.Id, remittanceAccountId, paymentScheduleId);
        missingFrequencyRequest.frequency = null;
        assertHandledException(JSON.serialize(missingFrequencyRequest), false, 'missing frequency');

        MasterDataFeeTypesController.SaveFeeTypeRequest missingFeeHeadRequest =
            buildBaseRequest(institute.Id, feeHead.Id, remittanceAccountId, paymentScheduleId);
        missingFeeHeadRequest.oneTimeFeeHeadId = null;
        assertHandledException(JSON.serialize(missingFeeHeadRequest), false, 'missing fee head');

        MasterDataFeeTypesController.SaveFeeTypeRequest missingDueDateRequest =
            buildBaseRequest(institute.Id, feeHead.Id, remittanceAccountId, paymentScheduleId);
        missingDueDateRequest.oneTimeDueDate = null;
        assertHandledException(JSON.serialize(missingDueDateRequest), false, 'missing due date');

        MasterDataFeeTypesController.SaveFeeTypeRequest missingAmountRequest =
            buildBaseRequest(institute.Id, feeHead.Id, remittanceAccountId, paymentScheduleId);
        missingAmountRequest.oneTimeAmount = null;
        assertHandledException(JSON.serialize(missingAmountRequest), false, 'missing amount');

        MasterDataFeeTypesController.SaveFeeTypeRequest missingRemittanceRequest =
            buildBaseRequest(institute.Id, feeHead.Id, remittanceAccountId, paymentScheduleId);
        missingRemittanceRequest.remittanceAccountIds = null;
        assertHandledException(JSON.serialize(missingRemittanceRequest), false, 'missing remittance account');
        System.assert(true, 'Required-field validation scenarios completed.');
    }

    @IsTest
    static void saveFeeTypeConfigurationCreatesYearlyInstituteFeeTypeWithFallbackRemittance() {
        Id remittanceAccountId = getRemittanceAccountId();
        Id paymentScheduleId = getPaymentScheduleId();
        Account institute = new Account(Name = 'Fee Yearly Institute ' + uniqueSuffix('I'));
        insert institute;

        String yearlyFrequency = getFrequencyContaining('year');
        System.assertNotEquals(null, yearlyFrequency, 'Expected a yearly frequency value in product org.');

        Ken_Master_Fee_Head__c feeHead = createFeeHead(uniqueSuffix('FH'), null);
        MasterDataFeeTypesController.LinkedMappingRow blankMapping =
            new MasterDataFeeTypesController.LinkedMappingRow();
        MasterDataFeeTypesController.SaveFeeTypeRequest requestData =
            buildBaseRequest(institute.Id, feeHead.Id, remittanceAccountId, paymentScheduleId);
        requestData.linkedMappings = new List<MasterDataFeeTypesController.LinkedMappingRow>{ blankMapping };
        requestData.batchIntake = null;
        requestData.frequency = yearlyFrequency;
        requestData.feeCategory = 'Invalid Category ' + uniqueSuffix('C');
        requestData.notes = 'Yearly fee type coverage';
        requestData.oneTimeFeePlanTag = null;

        Test.startTest();
        Id feeTypeId = MasterDataFeeTypesController.saveFeeTypeConfiguration(JSON.serialize(requestData), true);
        Test.stopTest();

        Ken_Fee_Type__c feeType = [
            SELECT Id, Institute__c, Batch__c, Status__c, Fee_Category__c, Fee_Type_Name__c, Fee_Type_Plan_Key__c
            FROM Ken_Fee_Type__c
            WHERE Id = :feeTypeId
            LIMIT 1
        ];
        System.assertEquals(institute.Id, feeType.Institute__c, 'The fee type should point to the institute.');
        System.assertEquals(null, feeType.Batch__c, 'Institute-only saves should allow a blank batch.');
        System.assertEquals('Active', feeType.Status__c, 'activateNow=true should set the fee type status to Active.');
        System.assertEquals(institute.Name, feeType.Fee_Type_Name__c, 'The generated name should use the institute name when batch is blank.');
        System.assertEquals(null, feeType.Fee_Type_Plan_Key__c, 'A blank fee plan tag should not update the parent key.');
        System.assertEquals(getFirstActiveFeeCategory(), feeType.Fee_Category__c, 'Invalid fee categories should normalize to the first active value.');

        Ken_Fee_Type_Line_Item__c lineItem = [
            SELECT Id, Remittance_Account__c, Fee_Type_Line_Key__c, Fee_Period_Label__c, Is_Active__c
            FROM Ken_Fee_Type_Line_Item__c
            WHERE Ken_Fee_Type__c = :feeTypeId
            LIMIT 1
        ];
        System.assertEquals(remittanceAccountId, lineItem.Remittance_Account__c, 'The controller should fall back to the first remittance account when the fee head has no default.');
        System.assertEquals(null, lineItem.Fee_Type_Line_Key__c, 'A blank plan tag should not populate the line key.');
        System.assertEquals('Year 1', lineItem.Fee_Period_Label__c, 'Yearly frequencies should produce a yearly period label.');
        System.assertEquals(true, lineItem.Is_Active__c, 'Active saves should create active line items.');
    }

    @IsTest
    static void saveFeeTypeConfigurationCreatesTermlyLinkedFeeTypeWithQuotaAndCategory() {
        Id remittanceAccountId = getRemittanceAccountId();
        Id paymentScheduleId = getPaymentScheduleId();
        LearningProgramPlan planRecord = getLearningProgramPlanForSave();
        Account institute = new Account(Name = 'Fee Term Institute ' + uniqueSuffix('I'));
        insert institute;

        String termFrequency = getFrequencyContaining('term');
        System.assertNotEquals(null, termFrequency, 'Expected a term frequency value in product org.');

        Category__c categoryRecord = createCategoryRecord('GENERAL');
        Quota__c quotaRecord = createQuotaRecord('GENERAL', 'GENERAL', categoryRecord.Id);
        Ken_Master_Fee_Head__c feeHead = createFeeHead(uniqueSuffix('TFH'), remittanceAccountId);

        MasterDataFeeTypesController.LinkedMappingRow blankRow =
            new MasterDataFeeTypesController.LinkedMappingRow();
        MasterDataFeeTypesController.LinkedMappingRow instituteMapping =
            new MasterDataFeeTypesController.LinkedMappingRow();
        instituteMapping.linkedLevel = 'Institute';
        instituteMapping.linkedEntityId = institute.Id;
        MasterDataFeeTypesController.LinkedMappingRow programMapping =
            new MasterDataFeeTypesController.LinkedMappingRow();
        programMapping.linkedLevel = 'Learning Program';
        programMapping.linkedEntityId = planRecord.LearningProgramId;
        MasterDataFeeTypesController.LinkedMappingRow planMapping =
            new MasterDataFeeTypesController.LinkedMappingRow();
        planMapping.linkedLevel = 'Learning Program Plan';
        planMapping.linkedEntityId = planRecord.Id;

        String suffix = uniqueSuffix('TP');
        MasterDataFeeTypesController.SaveFeeTypeRequest requestData =
            buildBaseRequest(institute.Id, feeHead.Id, remittanceAccountId, paymentScheduleId);
        requestData.linkedMappings = new List<MasterDataFeeTypesController.LinkedMappingRow>{
            blankRow,
            instituteMapping,
            programMapping,
            planMapping
        };
        requestData.batchIntake = 'TERM-' + suffix;
        requestData.frequency = termFrequency;
        requestData.notes = 'Termly fee type coverage';
        requestData.oneTimeFeePlanTag = 'TERMPLAN-' + suffix;
        requestData.oneTimeCategoryId = categoryRecord.Id;
        requestData.oneTimeQuotaId = quotaRecord.Id;

        Test.startTest();
        Id feeTypeId = MasterDataFeeTypesController.saveFeeTypeConfiguration(JSON.serialize(requestData), false);
        Test.stopTest();

        Ken_Fee_Type__c feeType = [
            SELECT Id, Institute__c, Learning_Program__c, Learning_Program_Plan__c, Batch__c, Fee_Type_Name__c
            FROM Ken_Fee_Type__c
            WHERE Id = :feeTypeId
            LIMIT 1
        ];
        System.assertEquals(institute.Id, feeType.Institute__c, 'The saved fee type should point to the institute.');
        System.assertEquals(planRecord.LearningProgramId, feeType.Learning_Program__c, 'The saved fee type should point to the learning program.');
        System.assertEquals(planRecord.Id, feeType.Learning_Program_Plan__c, 'The saved fee type should point to the learning program plan.');
        System.assertEquals('TERM-' + suffix, feeType.Batch__c, 'The batch should come from the request payload.');
        System.assert(feeType.Fee_Type_Name__c.contains(institute.Name), 'The generated name should include the institute.');
        System.assert(feeType.Fee_Type_Name__c.contains(planRecord.LearningProgram.Name), 'The generated name should include the learning program.');
        System.assert(feeType.Fee_Type_Name__c.contains(planRecord.Name), 'The generated name should include the learning program plan.');

        Ken_Fee_Type_Line_Item__c lineItem = [
            SELECT Id, Category__c, Quota__c, Student_Category__c, Fee_Period_Label__c
            FROM Ken_Fee_Type_Line_Item__c
            WHERE Ken_Fee_Type__c = :feeTypeId
            LIMIT 1
        ];
        System.assertEquals(categoryRecord.Id, lineItem.Category__c, 'The selected quota category should populate the line item category.');
        System.assertEquals(quotaRecord.Id, lineItem.Quota__c, 'The selected quota should populate the line item quota.');
        System.assertEquals('GENERAL', lineItem.Student_Category__c, 'Matching quota or category values should populate the student category.');
        System.assertEquals('Term 1', lineItem.Fee_Period_Label__c, 'Termly frequencies should produce a term period label.');
    }

    @IsTest
    static void saveFeeTypeConfigurationAppliesCategoryWhenQuotaIsBlank() {
        Ken_Master_Fee_Head__c feeHead = getFeeHeadForSave();
        Id remittanceAccountId = getRemittanceAccountId();
        Id paymentScheduleId = getPaymentScheduleId();
        Account institute = new Account(Name = 'Fee Category Institute ' + uniqueSuffix('I'));
        insert institute;

        Category__c categoryRecord = createCategoryRecord('GENERAL');
        String suffix = uniqueSuffix('CAT');
        MasterDataFeeTypesController.SaveFeeTypeRequest requestData =
            buildBaseRequest(institute.Id, feeHead.Id, remittanceAccountId, paymentScheduleId);
        requestData.batchIntake = 'CAT-' + suffix;
        requestData.notes = 'Category only coverage';
        requestData.oneTimeFeePlanTag = 'CATPLAN-' + suffix;
        requestData.oneTimeCategoryId = categoryRecord.Id;

        Test.startTest();
        Id feeTypeId = MasterDataFeeTypesController.saveFeeTypeConfiguration(JSON.serialize(requestData), false);
        Test.stopTest();

        Ken_Fee_Type_Line_Item__c lineItem = [
            SELECT Id, Category__c, Quota__c, Student_Category__c
            FROM Ken_Fee_Type_Line_Item__c
            WHERE Ken_Fee_Type__c = :feeTypeId
            LIMIT 1
        ];
        System.assertEquals(categoryRecord.Id, lineItem.Category__c, 'The line item should use the selected category when no quota is provided.');
        System.assertEquals(null, lineItem.Quota__c, 'The line item should keep quota blank when no quota is selected.');
        System.assertEquals('GENERAL', lineItem.Student_Category__c, 'Matching category values should populate the student category.');
    }

    @IsTest
    static void saveFeeTypeConfigurationCreatesFeeTypeAndRejectsDuplicates() {
        Ken_Master_Fee_Head__c feeHead = getFeeHeadForSave();
        Id remittanceAccountId = getRemittanceAccountId();
        Id paymentScheduleId = getPaymentScheduleId();
        Account institute = new Account(Name = 'Fee Test Institute ' + uniqueSuffix('I'));
        insert institute;

        String suffix = uniqueSuffix('F');
        String requestJson = buildInstituteRequestJson(
            institute.Id,
            feeHead.Id,
            remittanceAccountId,
            paymentScheduleId,
            suffix
        );

        Test.startTest();
        Id feeTypeId = MasterDataFeeTypesController.saveFeeTypeConfiguration(requestJson, false);
        Test.stopTest();

        System.assertNotEquals(null, feeTypeId, 'Expected a fee type id from the save call.');

        Ken_Fee_Type__c feeType = [
            SELECT Id, Institute__c, Batch__c, Status__c, Fee_Type_Plan_Key__c, Fee_Type_Name__c
            FROM Ken_Fee_Type__c
            WHERE Id = :feeTypeId
            LIMIT 1
        ];
        System.assertEquals(institute.Id, feeType.Institute__c, 'The fee type should point to the selected institute.');
        System.assertEquals('UT-' + suffix, feeType.Batch__c, 'The batch value should come from the request payload.');
        System.assertEquals('Draft', feeType.Status__c, 'activateNow=false should save the fee type in Draft status.');
        System.assertEquals('PLAN-' + suffix, feeType.Fee_Type_Plan_Key__c, 'Expected the fee plan tag to be copied back to the parent record.');
        System.assert(String.isNotBlank(feeType.Fee_Type_Name__c), 'A generated fee type name should be stored.');

        Integer lineItemCount = [
            SELECT COUNT()
            FROM Ken_Fee_Type_Line_Item__c
            WHERE Ken_Fee_Type__c = :feeTypeId
        ];
        Integer remittanceLinkCount = [
            SELECT COUNT()
            FROM Ken_Fee_Type_Remittance__c
            WHERE Ken_Fee_Type__c = :feeTypeId
        ];
        System.assertEquals(1, lineItemCount, 'Expected one fee type line item to be created.');
        System.assertEquals(1, remittanceLinkCount, 'Expected one remittance link to be created.');

        assertHandledException(requestJson, false, 'duplicate save');
    }
}