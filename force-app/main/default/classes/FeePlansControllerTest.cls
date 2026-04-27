@IsTest
private class FeePlansControllerTest {
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

    private static Id createFeeSetWithLine() {
        Id remittanceId = RemittanceAccountsController.createRemittanceAccount(
            'RA FP',
            'Bank',
            '1111',
            'LED-FP',
            'Program Level',
            null,
            null,
            null,
            null,
            true
        );
        Id taxId = TaxesController.saveTax('Tax FP', 12, null);
        Id feeHeadId = FeeHeadsController.createFeeHead(
            'FeeHead FP',
            pickValue(Ken_Master_Fee_Head__c.Fee_Head_Type__c.getDescribe(), null),
            true,
            true,
            true,
            remittanceId,
            taxId,
            'desc'
        );

        FeePlansController.MatrixLineInput line = new FeePlansController.MatrixLineInput();
        line.feeHeadId = feeHeadId;
        line.taxId = taxId;
        line.amount = 200;
        line.quotaLabel = pickValue(Ken_Fee_Set_Line_Item__c.Student_Category__c.getDescribe(), 'NRI');

        FeePlansController.SaveFeePlanRequest request = new FeePlansController.SaveFeePlanRequest();
        request.feePlanName = 'Plan_' + String.valueOf(DateTime.now().getTime());
        request.status = 'Active';
        request.lines = new List<FeePlansController.MatrixLineInput>{ line };

        return FeePlansController.saveFeePlan(JSON.serialize(request));
    }

    @IsTest
    static void listAndBuilderApis_workWithoutData() {
        Id feeSetId = createFeeSetWithLine();

        Test.startTest();
        List<FeePlansController.FeePlanRow> rows = FeePlansController.getFeePlans();
        FeePlansController.BuilderData builder = FeePlansController.getBuilderData(feeSetId);
        FeePlansController.FeePlanRecordData recordData = FeePlansController.getFeePlanRecord(feeSetId);
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertNotEquals(null, builder);
        System.assertNotEquals(null, builder.feeHeads);
        System.assertNotEquals(null, builder.quotas);
        System.assertNotEquals(null, builder.taxes);
        System.assertNotEquals(null, builder.lines);
        System.assertNotEquals(null, recordData);
        System.assert(recordData.categories != null);
        System.assert(rows.size() > 0);
    }

    @IsTest
    static void methods_validateNullOrInvalidInputs() {
        try {
            FeePlansController.saveFeePlan(null);
            System.assert(false, 'Expected invalid request exception.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            FeePlansController.cloneFeePlan(null);
            System.assert(false, 'Expected fee plan id validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            FeePlansController.deleteFeePlan(null);
            System.assert(false, 'Expected fee plan id validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            FeePlansController.getFeePlanRecord(null);
            System.assert(false, 'Expected fee plan id validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void cloneAndDelete_successAndBlockedPaths() {
        Id feeSetId = createFeeSetWithLine();
        Id cloneId = FeePlansController.cloneFeePlan(feeSetId);
        System.assertNotEquals(null, cloneId);

        Id feeHeadId = [SELECT Id FROM Ken_Master_Fee_Head__c LIMIT 1].Id;
        Ken_Fee_Type__c feeType = new Ken_Fee_Type__c(
            Fee_Type_Name__c = 'FT linked',
            Status__c = pickValue(Ken_Fee_Type__c.Status__c.getDescribe(), 'Draft')
        );
        insert feeType;
        insert new Ken_Fee_Type_Line_Item__c(
            Ken_Fee_Type__c = feeType.Id,
            Fee_Set__c = feeSetId,
            Fee_Head__c = feeHeadId,
            Student_Category__c = pickValue(Ken_Fee_Type_Line_Item__c.Student_Category__c.getDescribe(), 'NRI'),
            Amount__c = 10,
            Program_Year_Number__c = 1
        );

        Boolean blocked = false;
        try {
            FeePlansController.deleteFeePlan(feeSetId);
        } catch (AuraHandledException ex) {
            blocked = true;
            System.assert(!String.isBlank(ex.getMessage()));
        }
        System.assert(blocked);

        FeePlansController.deleteFeePlan(cloneId);
        Integer cloneCount = [SELECT Count() FROM Ken_Fee_Set__c WHERE Id = :cloneId];
        System.assertEquals(0, cloneCount);
    }

    @IsTest
    static void edit_isBlockedWhenFeePlanUsedInProgrammeFees() {
        Id feeSetId = createFeeSetWithLine();
        Id feeHeadId = [SELECT Id FROM Ken_Master_Fee_Head__c LIMIT 1].Id;

        Ken_Fee_Type__c feeType = new Ken_Fee_Type__c(
            Fee_Type_Name__c = 'FT edit blocked',
            Status__c = pickValue(Ken_Fee_Type__c.Status__c.getDescribe(), 'Draft')
        );
        insert feeType;

        insert new Ken_Fee_Type_Line_Item__c(
            Ken_Fee_Type__c = feeType.Id,
            Fee_Set__c = feeSetId,
            Fee_Head__c = feeHeadId,
            Student_Category__c = pickValue(Ken_Fee_Type_Line_Item__c.Student_Category__c.getDescribe(), 'NRI'),
            Amount__c = 10,
            Program_Year_Number__c = 1
        );

        FeePlansController.BuilderData builderData = FeePlansController.getBuilderData(feeSetId);
        System.assertEquals(true, builderData.isEditRestricted);
        System.assert(builderData.editRestrictionMessage.contains('Cannot edit this fee plan'));

        FeePlansController.MatrixLineInput line = new FeePlansController.MatrixLineInput();
        line.feeHeadId = feeHeadId;
        line.amount = 250;
        line.quotaLabel = pickValue(Ken_Fee_Set_Line_Item__c.Student_Category__c.getDescribe(), 'NRI');

        FeePlansController.SaveFeePlanRequest request = new FeePlansController.SaveFeePlanRequest();
        request.feeSetId = feeSetId;
        request.feePlanName = 'Blocked Update';
        request.status = 'Draft';
        request.lines = new List<FeePlansController.MatrixLineInput>{ line };

        try {
            FeePlansController.saveFeePlan(JSON.serialize(request));
            System.assert(false, 'Expected edit restriction when fee plan is used in programme fees.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Cannot edit this fee plan'));
        }
    }
}