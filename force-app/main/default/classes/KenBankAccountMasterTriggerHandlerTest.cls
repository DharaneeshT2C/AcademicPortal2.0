@IsTest
private class KenBankAccountMasterTriggerHandlerTest {
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

    private static Id createRemittance(Boolean isActive, String token) {
        return RemittanceAccountsController.createRemittanceAccount(
            'RA_' + token + '_' + String.valueOf(DateTime.now().getTime()),
            'Bank',
            'ACC_' + token,
            'LED_' + token,
            'Program Level',
            null,
            null,
            null,
            null,
            isActive
        );
    }

    private static void createFeeSetLineReference(Id remittanceId) {
        Id taxId = TaxesController.saveTax('Tax_' + String.valueOf(DateTime.now().getTime()), 8, null);
        Id feeHeadId = FeeHeadsController.createFeeHead(
            'FH_' + String.valueOf(DateTime.now().getTime()),
            pickValue(Ken_Master_Fee_Head__c.Fee_Head_Type__c.getDescribe(), null),
            true,
            true,
            true,
            null,
            taxId,
            null
        );

        FeePlansController.MatrixLineInput line = new FeePlansController.MatrixLineInput();
        line.feeHeadId = feeHeadId;
        line.taxId = taxId;
        line.amount = 100;
        line.quotaLabel = pickValue(Ken_Fee_Set_Line_Item__c.Student_Category__c.getDescribe(), 'NRI');

        FeePlansController.SaveFeePlanRequest request = new FeePlansController.SaveFeePlanRequest();
        request.feePlanName = 'Plan_' + String.valueOf(DateTime.now().getTime());
        request.status = 'Active';
        request.lines = new List<FeePlansController.MatrixLineInput>{ line };

        Id feeSetId = FeePlansController.saveFeePlan(JSON.serialize(request));
        Ken_Fee_Set_Line_Item__c row = [
            SELECT Id, Remittance_Account__c
            FROM Ken_Fee_Set_Line_Item__c
            WHERE Ken_Fee_Set__c = :feeSetId
            LIMIT 1
        ];
        row.Remittance_Account__c = remittanceId;
        update row;
    }

    @IsTest
    static void delete_blocksActiveRemittanceAccount() {
        Id remittanceId = createRemittance(true, 'ACTIVE');

        Test.startTest();
        Database.DeleteResult result = Database.delete(new Ken_Bank_Account_Master__c(Id = remittanceId), false);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess());
        System.assert(result.getErrors()[0].getMessage().contains('Active'));
        System.assertEquals(
            1,
            [SELECT Count() FROM Ken_Bank_Account_Master__c WHERE Id = :remittanceId]
        );
    }

    @IsTest
    static void delete_allowsInactiveUnreferencedRemittanceAccount() {
        Id remittanceId = createRemittance(false, 'INACTIVE');

        Test.startTest();
        Database.DeleteResult result = Database.delete(new Ken_Bank_Account_Master__c(Id = remittanceId), false);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess());
        System.assertEquals(
            0,
            [SELECT Count() FROM Ken_Bank_Account_Master__c WHERE Id = :remittanceId]
        );
    }

    @IsTest
    static void delete_blocksRemittanceReferencedByFeeStructure() {
        Id remittanceId = createRemittance(false, 'FEESET');
        createFeeSetLineReference(remittanceId);

        Test.startTest();
        Database.DeleteResult result = Database.delete(new Ken_Bank_Account_Master__c(Id = remittanceId), false);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess());
        System.assert(result.getErrors()[0].getMessage().contains('Fee Structures or Fee Types'));
        System.assertEquals(
            1,
            [SELECT Count() FROM Ken_Bank_Account_Master__c WHERE Id = :remittanceId]
        );
    }

    @IsTest
    static void delete_blocksRemittanceReferencedByFeeType() {
        Id remittanceId = createRemittance(false, 'FEETYPE');

        Ken_Fee_Type__c feeType = new Ken_Fee_Type__c(
            Fee_Type_Name__c = 'FT_' + String.valueOf(DateTime.now().getTime()),
            Status__c = pickValue(Ken_Fee_Type__c.Status__c.getDescribe(), 'Draft')
        );
        insert feeType;

        insert new Ken_Fee_Type_Remittance__c(
            Ken_Fee_Type__c = feeType.Id,
            Remittance_Account__c = remittanceId
        );

        Test.startTest();
        Database.DeleteResult result = Database.delete(new Ken_Bank_Account_Master__c(Id = remittanceId), false);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess());
        System.assert(result.getErrors()[0].getMessage().contains('Fee Structures or Fee Types'));
        System.assertEquals(
            1,
            [SELECT Count() FROM Ken_Bank_Account_Master__c WHERE Id = :remittanceId]
        );
    }
}