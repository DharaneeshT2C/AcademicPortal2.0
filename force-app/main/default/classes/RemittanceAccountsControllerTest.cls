@IsTest
private class RemittanceAccountsControllerTest {
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

    private static void createFeeStructureUsage(Id remittanceId) {
        Id taxId = TaxesController.saveTax('Tax_RA_' + String.valueOf(DateTime.now().getTime()), 5, null);
        Id feeHeadId = FeeHeadsController.createFeeHead(
            'FH_RA_' + String.valueOf(DateTime.now().getTime()),
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
        request.feePlanName = 'Plan_RA_' + String.valueOf(DateTime.now().getTime());
        request.status = 'Active';
        request.lines = new List<FeePlansController.MatrixLineInput>{ line };

        Id feeSetId = FeePlansController.saveFeePlan(JSON.serialize(request));
        Ken_Fee_Set_Line_Item__c feeSetLine = [
            SELECT Id, Remittance_Account__c
            FROM Ken_Fee_Set_Line_Item__c
            WHERE Ken_Fee_Set__c = :feeSetId
            LIMIT 1
        ];
        feeSetLine.Remittance_Account__c = remittanceId;
        update feeSetLine;
    }

    private static String pickGatewayStatus(String preferred) {
        String fallback;
        for (PaymentGatewaysController.OptionRow row : PaymentGatewaysController.getStatusOptions()) {
            if (row == null || String.isBlank(row.value)) {
                continue;
            }
            if (fallback == null) {
                fallback = row.value;
            }
            if (!String.isBlank(preferred) && row.value.toLowerCase() == preferred.toLowerCase()) {
                return row.value;
            }
        }
        return fallback;
    }

    @IsTest
    static void readApis_returnWithoutError() {
        Id remittanceId = RemittanceAccountsController.createRemittanceAccount(
            'RA Main',
            'Bank',
            'AC123',
            'LED-AC',
            'Program Level',
            null,
            'M1',
            'M2',
            'M3',
            true
        );

        Test.startTest();
        List<RemittanceAccountsController.RemittanceAccountRow> rows = RemittanceAccountsController.getRemittanceAccounts();
        List<RemittanceAccountsController.OptionRow> accountTypeOptions = RemittanceAccountsController.getAccountTypeOptions();
        List<RemittanceAccountsController.OptionRow> unknownLevel = RemittanceAccountsController.getLinkedEntityOptions('Unknown');
        List<RemittanceAccountsController.OptionRow> programLevel =
            RemittanceAccountsController.getLinkedEntityOptions('Program Level');
        List<RemittanceAccountsController.OptionRow> feeHeadLevel =
            RemittanceAccountsController.getLinkedEntityOptions('Fee Head Level');
        List<RemittanceAccountsController.OptionRow> currencyOptions =
            RemittanceAccountsController.getCurrencyOptions();
        List<RemittanceAccountsController.OptionRow> gatewayOptions =
            RemittanceAccountsController.searchPaymentGateways('GW', 10);
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertNotEquals(null, accountTypeOptions);
        System.assertEquals(0, unknownLevel.size());
        System.assertNotEquals(null, programLevel);
        System.assertNotEquals(null, feeHeadLevel);
        System.assertNotEquals(null, currencyOptions);
        System.assertNotEquals(null, gatewayOptions);
        System.assertNotEquals(null, remittanceId);
    }

    @IsTest
    static void createRemittanceAccount_validatesInputs() {
        try {
            RemittanceAccountsController.createRemittanceAccount(' ', 'Bank', '123', 'L1', 'Institute Level', null, null, null, null, true);
            System.assert(false, 'Expected account name validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            RemittanceAccountsController.createRemittanceAccount('Acc', ' ', '123', 'L1', 'Institute Level', null, null, null, null, true);
            System.assert(false, 'Expected bank validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            RemittanceAccountsController.createRemittanceAccount('Acc', 'Bank', ' ', 'L1', 'Institute Level', null, null, null, null, true);
            System.assert(false, 'Expected account number validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            RemittanceAccountsController.createRemittanceAccount('Acc', 'Bank', '123', ' ', 'Institute Level', null, null, null, null, true);
            System.assert(false, 'Expected ledger validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            RemittanceAccountsController.createRemittanceAccount('Acc', 'Bank', '123', 'L1', ' ', null, null, null, null, true);
            System.assert(false, 'Expected linked level validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void remittanceGatewayLink_apisExecute() {
        Id remittanceId = RemittanceAccountsController.createRemittanceAccountV2(
            'RA Link',
            'Bank',
            'AC-LINK',
            'LED-LINK',
            'Program Level',
            null,
            null,
            null,
            null,
            true,
            'PARENT-BASE',
            null
        );

        Id gatewayId;
        List<PaymentGatewaysController.OptionRow> providers = PaymentGatewaysController.getProviderOptions();
        List<PaymentGatewaysController.OptionRow> statuses = PaymentGatewaysController.getStatusOptions();
        List<PaymentGatewaysController.OptionRow> environments = PaymentGatewaysController.getEnvironmentOptions();

        try {
            gatewayId = PaymentGatewaysController.createPaymentGateway(
                providers.isEmpty() ? null : (Id) providers[0].value,
                'GW_LINK_' + String.valueOf(DateTime.now().getTime()),
                'GW Link Display ' + String.valueOf(DateTime.now().getTime()),
                statuses.isEmpty() ? 'Active' : statuses[0].value,
                environments.isEmpty() ? null : environments[0].value,
                'EXT_LINK_' + String.valueOf(DateTime.now().getTime()),
                null,
                'link test'
            );
        } catch (Exception ex) {
            System.assert(!String.isBlank(ex.getMessage()));
            return;
        }

        Test.startTest();
        RemittanceAccountsController.RemittanceGatewayLinkRow seedRow =
            RemittanceAccountsController.getPaymentGatewayMerchantSeed(gatewayId);
        Id linkId = RemittanceAccountsController.upsertRemittanceGatewayLink(
            null,
            remittanceId,
            gatewayId,
            null,
            null,
            true
        );
        List<RemittanceAccountsController.RemittanceGatewayLinkRow> links =
            RemittanceAccountsController.getRemittanceGatewayLinks(remittanceId);
        Test.stopTest();

        System.assertNotEquals(null, linkId);
        System.assert(!links.isEmpty(), 'Expected at least one junction row.');
        System.assertNotEquals(null, seedRow);

        Test.startTest();
        Id updatedLinkId = RemittanceAccountsController.upsertRemittanceGatewayLink(
            linkId,
            remittanceId,
            gatewayId,
            'PARENT-1',
            'SUB-1',
            true
        );
        RemittanceAccountsController.deleteRemittanceGatewayLink(linkId);
        Test.stopTest();

        System.assertEquals(linkId, updatedLinkId);
        System.assertEquals(0, RemittanceAccountsController.getRemittanceGatewayLinks(remittanceId).size());
    }

    @IsTest
    static void deleteRemittanceAccount_returnsBusinessErrorMessage() {
        Id activeRemittanceId = RemittanceAccountsController.createRemittanceAccount(
            'RA Delete Active',
            'Bank',
            'AC-DEL-ACTIVE',
            'LED-DEL-ACTIVE',
            'Program Level',
            null,
            null,
            null,
            null,
            true
        );

        Boolean blocked = false;
        try {
            RemittanceAccountsController.deleteRemittanceAccount(activeRemittanceId);
        } catch (AuraHandledException ex) {
            blocked = true;
        }
        System.assertEquals(true, blocked);
        System.assertEquals(
            1,
            [SELECT Count() FROM Ken_Bank_Account_Master__c WHERE Id = :activeRemittanceId]
        );

        Id inactiveRemittanceId = RemittanceAccountsController.createRemittanceAccount(
            'RA Delete Inactive',
            'Bank',
            'AC-DEL-INACTIVE',
            'LED-DEL-INACTIVE',
            'Program Level',
            null,
            null,
            null,
            null,
            false
        );

        Test.startTest();
        RemittanceAccountsController.deleteRemittanceAccount(inactiveRemittanceId);
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT Count() FROM Ken_Bank_Account_Master__c WHERE Id = :inactiveRemittanceId]
        );
    }

    @IsTest
    static void deleteRemittanceGatewayLink_blocksWhenRemittanceUsedInFeeConfigurations() {
        Id remittanceId = RemittanceAccountsController.createRemittanceAccount(
            'RA Link Used',
            'Bank',
            'AC-LINK-USED',
            'LED-LINK-USED',
            'Program Level',
            null,
            null,
            null,
            null,
            false
        );

        Id gatewayId = PaymentGatewaysController.createPaymentGateway(
            null,
            'GW_RA_' + String.valueOf(DateTime.now().getTime()),
            'GW RA Display ' + String.valueOf(DateTime.now().getTime()),
            pickGatewayStatus('Inactive'),
            null,
            'EXT_RA_' + String.valueOf(DateTime.now().getTime()),
            null,
            'link test'
        );

        Id linkId = RemittanceAccountsController.upsertRemittanceGatewayLink(
            null,
            remittanceId,
            gatewayId,
            null,
            null,
            true
        );

        createFeeStructureUsage(remittanceId);

        try {
            RemittanceAccountsController.deleteRemittanceGatewayLink(linkId);
            System.assert(false, 'Expected fee usage validation.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Fee Structures or Fee Types'));
        }

        System.assertEquals(1, [SELECT COUNT() FROM Remittance_Gateway_Link__c WHERE Id = :linkId]);
    }
}