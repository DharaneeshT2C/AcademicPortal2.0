@IsTest
private class ProgrammeFeePublishingControllerTest {
    private static String pickValue(Schema.DescribeFieldResult dfr, String preferred) {
        String fallback;
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe != null && pe.isActive()) {
                if (fallback == null) {
                    fallback = pe.getValue();
                }
                if (!String.isBlank(preferred) && pe.getValue().toLowerCase() == preferred.toLowerCase()) {
                    return pe.getValue();
                }
            }
        }
        return fallback;
    }

    private static Id createFeeSetForProgramme() {
        Id remittanceId = RemittanceAccountsController.createRemittanceAccount(
            'PFP_RA_' + String.valueOf(DateTime.now().getTime()),
            'Bank',
            'PFP123',
            'LED-PFP',
            'Program Level',
            null,
            null,
            null,
            null,
            true
        );
        Id taxId = TaxesController.saveTax('PFP_Tax_' + String.valueOf(DateTime.now().getTime()), 9, null);
        Id feeHeadId = FeeHeadsController.createFeeHead(
            'PFP_FH_' + String.valueOf(DateTime.now().getTime()),
            pickValue(Ken_Master_Fee_Head__c.Fee_Head_Type__c.getDescribe(), null),
            true,
            true,
            true,
            remittanceId,
            taxId,
            null
        );

        FeePlansController.MatrixLineInput line = new FeePlansController.MatrixLineInput();
        line.feeHeadId = feeHeadId;
        line.taxId = taxId;
        line.amount = 300;
        line.quotaLabel = pickValue(Ken_Fee_Set_Line_Item__c.Student_Category__c.getDescribe(), 'NRI');

        FeePlansController.SaveFeePlanRequest req = new FeePlansController.SaveFeePlanRequest();
        req.feePlanName = 'PFP_Set_' + String.valueOf(DateTime.now().getTime());
        req.status = 'Active';
        req.lines = new List<FeePlansController.MatrixLineInput>{ line };
        return FeePlansController.saveFeePlan(JSON.serialize(req));
    }

    @IsTest
    static void listAndSeedApis_returnWithoutError() {
        createFeeSetForProgramme();

        Test.startTest();
        List<ProgrammeFeePublishingController.ProgrammeFeeRow> rows = ProgrammeFeePublishingController.getProgrammeFees();
        ProgrammeFeePublishingController.BuilderSeedData seed = ProgrammeFeePublishingController.getBuilderSeedData();
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertNotEquals(null, seed);
        System.assertNotEquals(null, seed.feePlanOptions);
        System.assertNotEquals(null, seed.remittanceOptions);
    }

    @IsTest
    static void detailAndSave_validateRequiredInputs() {
        try {
            ProgrammeFeePublishingController.getProgrammeFeeRecord(null);
            System.assert(false, 'Expected fee type id validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            ProgrammeFeePublishingController.getProgrammeFeeConfigurationForEdit(null);
            System.assert(false, 'Expected fee type id validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            ProgrammeFeePublishingController.saveProgrammeFeeConfiguration(null, false);
            System.assert(false, 'Expected payload validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            ProgrammeFeePublishingController.saveProgrammeFeeConfiguration('{"programmeId":null}', false);
            System.assert(false, 'Expected learning program plan validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }
    }

    @IsTest(SeeAllData=true)
    static void saveAndEditProgrammeFeeConfiguration_happyPath() {
        List<LearningProgramPlan> plans = [SELECT Id FROM LearningProgramPlan LIMIT 1];
        System.assert(!plans.isEmpty(), 'LearningProgramPlan data required in org.');
        String uniqueBatchIntake = 'PFP-' + String.valueOf(DateTime.now().getTime());

        Id feeSetId = createFeeSetForProgramme();
        Id remittanceId1 = RemittanceAccountsController.createRemittanceAccount(
            'PFP_RA1_' + String.valueOf(DateTime.now().getTime()),
            'Bank',
            'PFPA1',
            'LED-A1',
            'Program Level',
            null,
            null,
            null,
            null,
            true
        );
        Id remittanceId2 = RemittanceAccountsController.createRemittanceAccount(
            'PFP_RA2_' + String.valueOf(DateTime.now().getTime()),
            'Bank',
            'PFPA2',
            'LED-A2',
            'Program Level',
            null,
            null,
            null,
            null,
            true
        );

        Payment_Schedule__c schedule = new Payment_Schedule__c(
            Name = 'PFP_Schedule_' + String.valueOf(DateTime.now().getTime()),
            Installment_Code__c = 'PFP-INS',
            Status__c = pickValue(Payment_Schedule__c.Status__c.getDescribe(), 'Draft'),
            Number_of_Scheduled_Payments__c = 1,
            Fee_Collection_Start_Date__c = Date.today(),
            Fee_Collection_End_Date__c = Date.today().addDays(5)
        );
        insert schedule;

        String category = pickValue(Ken_Fee_Type__c.Fee_Category__c.getDescribe(), null);
        String oneTimeFrequency = pickValue(Ken_Fee_Type__c.Fee_Collection_Frequency__c.getDescribe(), 'One Time');
        String triggerPoint = pickValue(Ken_Fee_Type_Line_Item__c.Fee_Assignment_Trigger_Point__c.getDescribe(), null);

        ProgrammeFeePublishingController.SaveProgrammeFeeRequest oneTimeReq =
            new ProgrammeFeePublishingController.SaveProgrammeFeeRequest();
        oneTimeReq.programmeId = plans[0].Id;
        oneTimeReq.feeCategory = category;
        oneTimeReq.batchIntake = uniqueBatchIntake;
        oneTimeReq.activationDate = Date.today();
        oneTimeReq.frequency = oneTimeFrequency;
        oneTimeReq.remittanceAccountIds = new List<Id>{ remittanceId1, remittanceId2 };
        oneTimeReq.oneTimeFeePlanId = feeSetId;
        oneTimeReq.oneTimeFeeAssignmentTriggerPoint = triggerPoint;
        oneTimeReq.oneTimeFeePlanTag = 'TAG_' + String.valueOf(DateTime.now().getTime());
        oneTimeReq.oneTimeDueDate = Date.today().addDays(20);
        oneTimeReq.oneTimeRemittanceOverrideId = remittanceId2;
        oneTimeReq.oneTimeInstallmentId = schedule.Id;
        oneTimeReq.notes = 'coverage';

        Test.startTest();
        Id feeTypeId = ProgrammeFeePublishingController.saveProgrammeFeeConfiguration(
            JSON.serialize(oneTimeReq),
            true
        );
        insert new Fee_Assignment__c(
            Fee_Type__c = feeTypeId,
            Status__c = pickValue(Fee_Assignment__c.Status__c.getDescribe(), 'Active')
        );
        ProgrammeFeePublishingController.ProgrammeFeeRecordData recordData =
            ProgrammeFeePublishingController.getProgrammeFeeRecord(feeTypeId);
        List<ProgrammeFeePublishingController.ProgrammeFeeRow> rows =
            ProgrammeFeePublishingController.getProgrammeFees();
        ProgrammeFeePublishingController.SaveProgrammeFeeRequest editSeed =
            ProgrammeFeePublishingController.getProgrammeFeeConfigurationForEdit(feeTypeId);
        Test.stopTest();

        System.assertNotEquals(null, feeTypeId);
        System.assertNotEquals(null, recordData);
        System.assertNotEquals(null, editSeed);
        System.assert(recordData.configurationRows != null && !recordData.configurationRows.isEmpty());
        System.assertEquals(feeSetId, recordData.configurationRows[0].feePlanId);
        System.assertEquals(1, recordData.usedInAssignments);

        ProgrammeFeePublishingController.ProgrammeFeeRow savedRow;
        for (ProgrammeFeePublishingController.ProgrammeFeeRow rowItem : rows) {
            if (rowItem.feeTypeId == feeTypeId) {
                savedRow = rowItem;
                break;
            }
        }
        System.assertNotEquals(null, savedRow);
        System.assertEquals(1, savedRow.usedInAssignments);

        String nonOneTime = null;
        for (Schema.PicklistEntry pe :
            Ken_Fee_Type__c.Fee_Collection_Frequency__c.getDescribe().getPicklistValues()) {
            if (nonOneTime == null
                && pe != null
                && pe.isActive()
                && !pe.getValue().toLowerCase().contains('one')) {
                nonOneTime = pe.getValue();
            }
        }
        if (String.isBlank(nonOneTime)) {
            nonOneTime = oneTimeFrequency;
        }

        ProgrammeFeePublishingController.PublishConfigRow row =
            new ProgrammeFeePublishingController.PublishConfigRow();
        row.programYearNumber = 1;
        row.feePlanId = feeSetId;
        row.feeAssignmentTriggerPoint = triggerPoint;
        row.tag = 'YTAG_' + String.valueOf(DateTime.now().getTime());
        row.startDate = Date.today().addDays(10);
        row.dueDate = Date.today().addDays(30);
        row.remittanceOverrideId = remittanceId1;
        row.installmentId = schedule.Id;

        ProgrammeFeePublishingController.SaveProgrammeFeeRequest updateReq =
            new ProgrammeFeePublishingController.SaveProgrammeFeeRequest();
        updateReq.feeTypeId = feeTypeId;
        updateReq.programmeId = plans[0].Id;
        updateReq.feeCategory = category;
        updateReq.batchIntake = uniqueBatchIntake;
        updateReq.activationDate = Date.today();
        updateReq.frequency = nonOneTime;
        updateReq.remittanceAccountIds = new List<Id>{ remittanceId1 };
        updateReq.configRows = new List<ProgrammeFeePublishingController.PublishConfigRow>{ row };
        updateReq.notes = 'updated';

        Id updatedId = ProgrammeFeePublishingController.saveProgrammeFeeConfiguration(
            JSON.serialize(updateReq),
            false
        );
        System.assertEquals(feeTypeId, updatedId);

        Ken_Fee_Type_Line_Item__c savedLine = [
            SELECT Start_Date__c, Due_Date__c
            FROM Ken_Fee_Type_Line_Item__c
            WHERE Ken_Fee_Type__c = :feeTypeId
            LIMIT 1
        ];
        System.assertEquals(row.startDate, savedLine.Start_Date__c);
        System.assertEquals(row.dueDate, savedLine.Due_Date__c);
    }

    @IsTest(SeeAllData=true)
    static void saveProgrammeFeeConfiguration_blocksDuplicateStructure() {
        List<LearningProgramPlan> plans = [SELECT Id FROM LearningProgramPlan LIMIT 1];
        System.assert(!plans.isEmpty(), 'LearningProgramPlan data required in org.');

        Id feeSetId = createFeeSetForProgramme();
        Id remittanceId = RemittanceAccountsController.createRemittanceAccount(
            'PFP_DUP_RA_' + String.valueOf(DateTime.now().getTime()),
            'Bank',
            'PFPDUP',
            'LED-DUP',
            'Program Level',
            null,
            null,
            null,
            null,
            true
        );

        String category = pickValue(Ken_Fee_Type__c.Fee_Category__c.getDescribe(), null);
        String oneTimeFrequency = pickValue(Ken_Fee_Type__c.Fee_Collection_Frequency__c.getDescribe(), 'One Time');
        String triggerPoint = pickValue(Ken_Fee_Type_Line_Item__c.Fee_Assignment_Trigger_Point__c.getDescribe(), null);
        String batchIntake = 'PFP-DUP-' + String.valueOf(DateTime.now().getTime());

        ProgrammeFeePublishingController.SaveProgrammeFeeRequest requestData =
            new ProgrammeFeePublishingController.SaveProgrammeFeeRequest();
        requestData.programmeId = plans[0].Id;
        requestData.feeCategory = category;
        requestData.batchIntake = batchIntake;
        requestData.activationDate = Date.today();
        requestData.frequency = oneTimeFrequency;
        requestData.remittanceAccountIds = new List<Id>{ remittanceId };
        requestData.oneTimeFeePlanId = feeSetId;
        requestData.oneTimeFeeAssignmentTriggerPoint = triggerPoint;
        requestData.oneTimeDueDate = Date.today().addDays(15);

        ProgrammeFeePublishingController.saveProgrammeFeeConfiguration(
            JSON.serialize(requestData),
            false
        );

        try {
            ProgrammeFeePublishingController.saveProgrammeFeeConfiguration(
                JSON.serialize(requestData),
                false
            );
            System.assert(false, 'Expected duplicate programme fee validation.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Programme Fee configuration already exists'));
        }
    }
}