@IsTest
private class FeeTypeCreationServiceTest {
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

    @IsTest
    static void getFeeSetPreview_withNullId_returnsEmpty() {
        Test.startTest();
        List<FeeTypeCreationService.FeeSetPreviewRow> rows = FeeTypeCreationService.getFeeSetPreview(null);
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertEquals(0, rows.size());
    }

    @IsTest
    static void createFeeType_validatesRequest() {
        try {
            FeeTypeCreationService.createFeeType(null);
            System.assert(false, 'Expected request cannot be null validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        String jsonPayload = '{"feeTypeName":"X"}';
        try {
            FeeTypeCreationService.createFeeType(jsonPayload);
            System.assert(false, 'Expected learning program plan validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        String instituteProgramPlanPayload = '{"linkLevel":"Institute Program Plan","feeTypeName":"X"}';
        try {
            FeeTypeCreationService.createFeeType(instituteProgramPlanPayload);
            System.assert(false, 'Expected institute program plan validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }
    }

    @IsTest(SeeAllData=true)
    static void createFeeType_happyPath() {
        List<LearningProgramPlan> plans = [SELECT Id FROM LearningProgramPlan LIMIT 1];
        System.assert(!plans.isEmpty(), 'LearningProgramPlan data required in org.');

        String feeHeadType = pickValue(Ken_Master_Fee_Head__c.Fee_Head_Type__c.getDescribe(), null);
        String studentCategory = pickValue(Ken_Fee_Set_Line_Item__c.Student_Category__c.getDescribe(), 'NRI');
        String status = pickValue(Ken_Fee_Type__c.Status__c.getDescribe(), 'Draft');
        String feeCategory = pickValue(Ken_Fee_Type__c.Fee_Category__c.getDescribe(), null);
        String frequency = pickValue(Ken_Fee_Type__c.Fee_Collection_Frequency__c.getDescribe(), 'One Time');

        Id remittanceId = RemittanceAccountsController.createRemittanceAccount(
            'FTS_RA',
            'Bank',
            'FTS123',
            'LED-FTS',
            'Program Level',
            null,
            null,
            null,
            null,
            true
        );
        Id taxId = TaxesController.saveTax('FTS_Tax_' + String.valueOf(DateTime.now().getTime()), 10, null);
        Id feeHeadId = FeeHeadsController.createFeeHead(
            'FTS_FH_' + String.valueOf(DateTime.now().getTime()),
            feeHeadType,
            true,
            true,
            true,
            remittanceId,
            taxId,
            null
        );

        FeePlansController.MatrixLineInput line = new FeePlansController.MatrixLineInput();
        line.feeHeadId = feeHeadId;
        line.quotaLabel = studentCategory;
        line.taxId = taxId;
        line.amount = 250;
        FeePlansController.SaveFeePlanRequest feePlanRequest = new FeePlansController.SaveFeePlanRequest();
        feePlanRequest.feePlanName = 'FTS_Set_' + String.valueOf(DateTime.now().getTime());
        feePlanRequest.status = 'Active';
        feePlanRequest.lines = new List<FeePlansController.MatrixLineInput>{ line };
        Id feeSetId = FeePlansController.saveFeePlan(JSON.serialize(feePlanRequest));

        Payment_Schedule__c schedule = new Payment_Schedule__c(
            Name = 'FTS_Schedule_' + String.valueOf(DateTime.now().getTime()),
            Installment_Code__c = 'FTS-INS',
            Status__c = pickValue(Payment_Schedule__c.Status__c.getDescribe(), 'Draft'),
            Number_of_Scheduled_Payments__c = 1,
            Fee_Collection_Start_Date__c = Date.today(),
            Fee_Collection_End_Date__c = Date.today().addDays(10)
        );
        insert schedule;

        Id recordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Ken_Fee_Type__c'
            LIMIT 1
        ].Id;

        FeeTypeCreationService.YearConfiguration yc = new FeeTypeCreationService.YearConfiguration();
        yc.programYearNumber = 1;
        yc.feeSetId = feeSetId;
        yc.dueDate = Date.today().addDays(5);

        FeeTypeCreationService.FeeTypeRequest req = new FeeTypeCreationService.FeeTypeRequest();
        req.linkLevel = 'Learning Program Plan';
        req.learningProgramPlanId = plans[0].Id;
        req.feeTypeRecordTypeId = recordTypeId;
        req.feeTypeName = 'FTS_Type_' + String.valueOf(DateTime.now().getTime());
        req.feeCategory = feeCategory;
        req.frequency = frequency;
        req.status = status;
        req.paymentScheduleId = schedule.Id;
        req.defaultTaxId = taxId;
        req.yearConfigurations = new List<FeeTypeCreationService.YearConfiguration>{ yc };

        Test.startTest();
        List<FeeTypeCreationService.FeeSetPreviewRow> previewRows = FeeTypeCreationService.getFeeSetPreview(feeSetId);
        Id feeTypeId = FeeTypeCreationService.createFeeType(JSON.serialize(req));
        Test.stopTest();

        System.assertNotEquals(null, feeTypeId);
        System.assertNotEquals(null, previewRows);
        Ken_Fee_Type__c feeTypeRecord = [
            SELECT Learning_Program_Plan__c
            FROM Ken_Fee_Type__c
            WHERE Id = :feeTypeId
            LIMIT 1
        ];
        System.assertEquals(plans[0].Id, feeTypeRecord.Learning_Program_Plan__c);
        Integer lineCount = [SELECT Count() FROM Ken_Fee_Type_Line_Item__c WHERE Ken_Fee_Type__c = :feeTypeId];
        System.assert(lineCount > 0);
    }
}