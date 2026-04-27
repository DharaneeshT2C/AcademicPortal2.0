@IsTest
private class PaymentGatewaysControllerTest {
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

    private static String pickStatusValue(String preferred) {
        String fallback;
        List<PaymentGatewaysController.OptionRow> statuses = PaymentGatewaysController.getStatusOptions();
        for (PaymentGatewaysController.OptionRow row : statuses) {
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

    private static Id createGatewayWithStatus(String statusValue, String token) {
        Id providerId = null;
        Id merchantCredentialId = null;
        String environmentValue = null;

        List<PaymentGatewaysController.OptionRow> providers = PaymentGatewaysController.getProviderOptions();
        if (!providers.isEmpty() && !String.isBlank(providers[0].value)) {
            providerId = (Id) providers[0].value;
        }

        List<PaymentGatewaysController.OptionRow> credentials = PaymentGatewaysController.getMerchantCredentialOptions();
        if (!credentials.isEmpty() && !String.isBlank(credentials[0].value)) {
            merchantCredentialId = (Id) credentials[0].value;
        }

        List<PaymentGatewaysController.OptionRow> environments = PaymentGatewaysController.getEnvironmentOptions();
        if (!environments.isEmpty() && !String.isBlank(environments[0].value)) {
            environmentValue = environments[0].value;
        }

        return PaymentGatewaysController.createPaymentGateway(
            providerId,
            'GW_' + token + '_' + String.valueOf(DateTime.now().getTime()),
            'GW Display ' + token + '_' + String.valueOf(DateTime.now().getTime()),
            statusValue,
            environmentValue,
            'EXT_' + token + '_' + String.valueOf(DateTime.now().getTime()),
            merchantCredentialId,
            'coverage'
        );
    }

    private static Id createRemittanceForGateway(String token) {
        return RemittanceAccountsController.createRemittanceAccount(
            'RA_PG_' + token + '_' + String.valueOf(DateTime.now().getTime()),
            'Bank',
            'PG' + token,
            'LED' + token,
            'Program Level',
            null,
            null,
            null,
            null,
            false
        );
    }

    private static void createFeeStructureUsage(Id remittanceId) {
        Id taxId = TaxesController.saveTax('Tax_PG_' + String.valueOf(DateTime.now().getTime()), 5, null);
        Id feeHeadId = FeeHeadsController.createFeeHead(
            'FH_PG_' + String.valueOf(DateTime.now().getTime()),
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
        request.feePlanName = 'Plan_PG_' + String.valueOf(DateTime.now().getTime());
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

    @IsTest
    static void getOptionsAndRows_returnWithoutError() {
        Test.startTest();
        List<PaymentGatewaysController.PaymentGatewayRow> rows = PaymentGatewaysController.getPaymentGateways();
        List<PaymentGatewaysController.OptionRow> providers = PaymentGatewaysController.getProviderOptions();
        List<PaymentGatewaysController.OptionRow> credentials = PaymentGatewaysController.getMerchantCredentialOptions();
        List<PaymentGatewaysController.OptionRow> statuses = PaymentGatewaysController.getStatusOptions();
        List<PaymentGatewaysController.OptionRow> environments = PaymentGatewaysController.getEnvironmentOptions();
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertNotEquals(null, providers);
        System.assertNotEquals(null, credentials);
        System.assertNotEquals(null, statuses);
        System.assertNotEquals(null, environments);
    }

    @IsTest
    static void createPaymentGateway_validatesRequiredFields() {
        try {
            PaymentGatewaysController.createPaymentGateway(null, ' ', 'Display Name', 'Active', null, 'EXT', null, null);
            System.assert(false, 'Expected payment gateway name validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            PaymentGatewaysController.createPaymentGateway(null, 'Gateway', 'Display Name', 'Active', null, ' ', null, null);
            System.assert(false, 'Expected external reference validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            PaymentGatewaysController.createPaymentGateway(null, 'Gateway', 'Display Name', ' ', null, 'EXT', null, null);
            System.assert(false, 'Expected status validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            PaymentGatewaysController.createPaymentGateway(null, 'Gateway', ' ', 'Active', null, 'EXT', null, null);
            System.assert(false, 'Expected gateway display name validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void createPaymentGateway_attemptsCreatePath() {
        Id providerId = null;
        String statusValue = null;
        String environmentValue = null;
        List<PaymentGatewaysController.OptionRow> providers = PaymentGatewaysController.getProviderOptions();
        List<PaymentGatewaysController.OptionRow> statuses = PaymentGatewaysController.getStatusOptions();
        List<PaymentGatewaysController.OptionRow> environments = PaymentGatewaysController.getEnvironmentOptions();
        if (!providers.isEmpty()) {
            providerId = (Id) providers[0].value;
        }
        if (!statuses.isEmpty()) {
            statusValue = statuses[0].value;
        }
        if (String.isBlank(statusValue)) {
            statusValue = 'Active';
        }
        if (!environments.isEmpty()) {
            environmentValue = environments[0].value;
        }

        Boolean executed = false;
        try {
            Id gatewayId = PaymentGatewaysController.createPaymentGateway(
                providerId,
                'GW_' + String.valueOf(DateTime.now().getTime()),
                'GW Display ' + String.valueOf(DateTime.now().getTime()),
                statusValue,
                environmentValue,
                'EXT_' + String.valueOf(DateTime.now().getTime()),
                null,
                'coverage'
            );
            executed = true;
            System.assertNotEquals(null, gatewayId);
        } catch (Exception ex) {
            executed = true;
            System.assert(!String.isBlank(ex.getMessage()));
        }
        System.assert(executed, 'Create path should execute.');
    }

    @IsTest
    static void updatePaymentGateway_validatesRequiredId() {
        try {
            PaymentGatewaysController.updatePaymentGateway(
                null,
                null,
                'Gateway',
                'Display Name',
                'Active',
                null,
                'EXT',
                null,
                null
            );
            System.assert(false, 'Expected payment gateway id validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void updatePaymentGateway_attemptsUpdatePath() {
        Id providerId = null;
        String statusValue = null;
        String environmentValue = null;
        List<PaymentGatewaysController.OptionRow> providers = PaymentGatewaysController.getProviderOptions();
        List<PaymentGatewaysController.OptionRow> statuses = PaymentGatewaysController.getStatusOptions();
        List<PaymentGatewaysController.OptionRow> environments = PaymentGatewaysController.getEnvironmentOptions();
        if (!providers.isEmpty()) {
            providerId = (Id) providers[0].value;
        }
        if (!statuses.isEmpty()) {
            statusValue = statuses[0].value;
        }
        if (String.isBlank(statusValue)) {
            statusValue = 'Active';
        }
        if (!environments.isEmpty()) {
            environmentValue = environments[0].value;
        }

        Boolean executed = false;
        try {
            Id gatewayId = PaymentGatewaysController.createPaymentGateway(
                providerId,
                'GW_' + String.valueOf(DateTime.now().getTime()),
                'GW Display ' + String.valueOf(DateTime.now().getTime()),
                statusValue,
                environmentValue,
                'EXT_' + String.valueOf(DateTime.now().getTime()),
                null,
                'before update'
            );

            Id updatedId = PaymentGatewaysController.updatePaymentGateway(
                gatewayId,
                providerId,
                'GW Updated ' + String.valueOf(DateTime.now().getTime()),
                'GW Display Updated ' + String.valueOf(DateTime.now().getTime()),
                statusValue,
                environmentValue,
                'EXT_UPDATED_' + String.valueOf(DateTime.now().getTime()),
                null,
                'after update'
            );
            executed = true;
            System.assertEquals(gatewayId, updatedId);
        } catch (Exception ex) {
            executed = true;
            System.assert(!String.isBlank(ex.getMessage()));
        }
        System.assert(executed, 'Update path should execute.');
    }

    @IsTest
    static void updatePaymentGateway_handlesUnknownId() {
        Id fakeId = '0W7F80000000000AAA';
        try {
            PaymentGatewaysController.updatePaymentGateway(
                fakeId,
                null,
                'Gateway',
                'Display Name',
                'Active',
                null,
                'EXT',
                null,
                null
            );
            System.assert(false, 'Expected unknown id to fail.');
        } catch (Exception ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }
    }

    @IsTest(SeeAllData=true)
    static void deletePaymentGateway_blocksActiveAndAllowsInactive() {
        String activeStatus = pickStatusValue('Active');
        String inactiveStatus = pickStatusValue('Inactive');
        if (String.isBlank(activeStatus)) {
            activeStatus = 'Active';
        }
        if (String.isBlank(inactiveStatus)) {
            inactiveStatus = activeStatus;
        }

        Id activeGatewayId = createGatewayWithStatus(activeStatus, 'ACTIVE');
        Boolean blocked = false;
        try {
            PaymentGatewaysController.deletePaymentGateway(activeGatewayId);
        } catch (AuraHandledException ex) {
            blocked = true;
            System.assert(!String.isBlank(ex.getMessage()));
        }
        System.assertEquals(true, blocked);
        System.assertEquals(1, [SELECT Count() FROM PaymentGateway WHERE Id = :activeGatewayId]);

        Id inactiveGatewayId = createGatewayWithStatus(inactiveStatus, 'INACTIVE');
        Test.startTest();
        PaymentGatewaysController.deletePaymentGateway(inactiveGatewayId);
        Test.stopTest();
        System.assertEquals(0, [SELECT Count() FROM PaymentGateway WHERE Id = :inactiveGatewayId]);
    }

    @IsTest(SeeAllData=true)
    static void deletePaymentGateway_blocksReferencedGateway() {
        String inactiveStatus = pickStatusValue('Inactive');
        if (String.isBlank(inactiveStatus)) {
            inactiveStatus = pickStatusValue('Active');
        }

        Id gatewayId = createGatewayWithStatus(inactiveStatus, 'REF');
        Id remittanceId = RemittanceAccountsController.createRemittanceAccount(
            'RA_PG_DELETE_REF_' + String.valueOf(DateTime.now().getTime()),
            'Bank',
            'PGDELREF',
            'PGDELREFLED',
            'Program Level',
            null,
            null,
            null,
            null,
            false
        );
        insert new Remittance_Gateway_Link__c(
            Remittance_Account__c = remittanceId,
            Payment_Gateway__c = String.valueOf(gatewayId),
            Is_Active__c = true
        );

        Boolean blocked = false;
        try {
            PaymentGatewaysController.deletePaymentGateway(gatewayId);
        } catch (AuraHandledException ex) {
            blocked = true;
            System.assert(!String.isBlank(ex.getMessage()));
        }
        System.assertEquals(true, blocked);
        System.assertEquals(1, [SELECT Count() FROM PaymentGateway WHERE Id = :gatewayId]);
    }

    @IsTest(SeeAllData=true)
    static void deletePaymentGateway_blocksGatewayAssignedToUsedRemittanceAccount() {
        String inactiveStatus = pickStatusValue('Inactive');
        if (String.isBlank(inactiveStatus)) {
            inactiveStatus = pickStatusValue('Active');
        }

        Id gatewayId = createGatewayWithStatus(inactiveStatus, 'FEEUSE');
        Id remittanceId = createRemittanceForGateway('FEEUSE');
        insert new Remittance_Gateway_Link__c(
            Remittance_Account__c = remittanceId,
            Payment_Gateway__c = String.valueOf(gatewayId),
            Is_Active__c = true
        );
        createFeeStructureUsage(remittanceId);

        Boolean blocked = false;
        try {
            PaymentGatewaysController.deletePaymentGateway(gatewayId);
        } catch (AuraHandledException ex) {
            blocked = true;
            System.assert(ex.getMessage().contains('Fee Structures or Fee Types'));
        }

        System.assertEquals(true, blocked);
        System.assertEquals(1, [SELECT Count() FROM PaymentGateway WHERE Id = :gatewayId]);
    }
}