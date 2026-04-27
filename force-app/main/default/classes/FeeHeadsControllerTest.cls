@IsTest
private class FeeHeadsControllerTest {
    private static String pickValue(Schema.DescribeFieldResult dfr) {
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe != null && pe.isActive()) {
                return pe.getValue();
            }
        }
        return null;
    }

    private static Id createFeeSetForUsage() {
        Ken_Fee_Set__c feeSet = new Ken_Fee_Set__c();
        String feeStatus = pickValue(Ken_Fee_Set__c.Status__c.getDescribe());
        if (!String.isBlank(feeStatus)) {
            feeSet.Status__c = feeStatus;
        }
        String currencyPolicy = pickValue(Ken_Fee_Set__c.Currency_Policy__c.getDescribe());
        if (!String.isBlank(currencyPolicy)) {
            feeSet.Currency_Policy__c = currencyPolicy;
        }
        insert feeSet;
        return feeSet.Id;
    }

    @IsTest
    static void getters_returnWithoutError() {
        Id remittanceId = RemittanceAccountsController.createRemittanceAccount(
            'RA FeeHead',
            'Test Bank',
            '12345',
            'LED-1',
            'Program Level',
            null,
            null,
            null,
            null,
            true
        );
        Id taxId = TaxesController.saveTax('Tax For FeeHead', 10, null);
        FeeHeadsController.createFeeHead(
            'Fee Head Test',
            pickValue(Ken_Master_Fee_Head__c.Fee_Head_Type__c.getDescribe()),
            true,
            false,
            true,
            remittanceId,
            taxId,
            'desc'
        );

        Test.startTest();
        List<FeeHeadsController.FeeHeadRow> feeHeads = FeeHeadsController.getFeeHeads();
        List<FeeHeadsController.OptionRow> typeOptions = FeeHeadsController.getFeeHeadTypeOptions();
        List<FeeHeadsController.OptionRow> remittanceOptions = FeeHeadsController.getRemittanceAccountOptions();
        List<FeeHeadsController.TaxOptionRow> taxOptions = FeeHeadsController.getTaxDefinitionOptions();
        Test.stopTest();

        System.assertNotEquals(null, feeHeads);
        System.assertNotEquals(null, typeOptions);
        System.assertNotEquals(null, remittanceOptions);
        System.assertNotEquals(null, taxOptions);
        System.assert(feeHeads.size() > 0);
    }

    @IsTest
    static void createFeeHead_validatesRequiredFields() {
        try {
            FeeHeadsController.createFeeHead('  ', 'Any', true, false, false, null, null, null);
            System.assert(false, 'Expected validation exception for blank name.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            FeeHeadsController.createFeeHead('Test Fee Head', null, true, false, false, null, null, null);
            System.assert(false, 'Expected validation exception for head category.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void deleteFeeHead_blocksWhenUsedInFeePlanOrProgrammeFee() {
        String feeHeadType = pickValue(Ken_Master_Fee_Head__c.Fee_Head_Type__c.getDescribe());

        Id feeHeadUsedInPlanId = FeeHeadsController.createFeeHead(
            'Fee Head Plan ' + String.valueOf(DateTime.now().getTime()),
            feeHeadType,
            true,
            false,
            false,
            null,
            null,
            null
        );

        insert new Ken_Fee_Set_Line_Item__c(
            Ken_Fee_Set__c = createFeeSetForUsage(),
            Fee_Head__c = feeHeadUsedInPlanId
        );

        try {
            FeeHeadsController.deleteFeeHead(feeHeadUsedInPlanId);
            System.assert(false, 'Expected fee head in-use validation for fee plan usage.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Cannot delete fee head'));
        }

        Id feeHeadUsedInProgrammeId = FeeHeadsController.createFeeHead(
            'Fee Head Programme ' + String.valueOf(DateTime.now().getTime()),
            feeHeadType,
            true,
            false,
            false,
            null,
            null,
            null
        );

        Ken_Fee_Type__c feeType = new Ken_Fee_Type__c(
            Fee_Type_Name__c = 'FT ' + String.valueOf(DateTime.now().getTime()),
            Status__c = pickValue(Ken_Fee_Type__c.Status__c.getDescribe())
        );
        insert feeType;

        insert new Ken_Fee_Type_Line_Item__c(
            Ken_Fee_Type__c = feeType.Id,
            Fee_Head__c = feeHeadUsedInProgrammeId,
            Student_Category__c = pickValue(Ken_Fee_Type_Line_Item__c.Student_Category__c.getDescribe()),
            Amount__c = 100,
            Program_Year_Number__c = 1
        );

        try {
            FeeHeadsController.deleteFeeHead(feeHeadUsedInProgrammeId);
            System.assert(false, 'Expected fee head in-use validation for programme fee usage.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Cannot delete fee head'));
        }
    }

    @IsTest
    static void deleteFeeHead_succeedsWhenUnused() {
        Id feeHeadId = FeeHeadsController.createFeeHead(
            'Fee Head Delete ' + String.valueOf(DateTime.now().getTime()),
            pickValue(Ken_Master_Fee_Head__c.Fee_Head_Type__c.getDescribe()),
            true,
            false,
            false,
            null,
            null,
            null
        );

        FeeHeadsController.deleteFeeHead(feeHeadId);

        System.assertEquals(0, [SELECT Count() FROM Ken_Master_Fee_Head__c WHERE Id = :feeHeadId]);
    }
}