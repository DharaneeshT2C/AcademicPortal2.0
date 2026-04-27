@IsTest
private class InstallmentPlansControllerTest {
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

    private static Id createInstallmentPlan(String codePrefix) {
        InstallmentPlansController.InstallmentInput row = new InstallmentPlansController.InstallmentInput();
        row.order = 1;
        row.percentage = 100;
        row.startDate = Date.today();
        row.dueDays = 20;

        InstallmentPlansController.InstallmentPlanSaveRequest req =
            new InstallmentPlansController.InstallmentPlanSaveRequest();
        req.planName = codePrefix + '_Plan_' + String.valueOf(DateTime.now().getTime());
        req.installmentCode = codePrefix + '_' + String.valueOf(DateTime.now().getTime());
        req.status = pickValue(Payment_Schedule__c.Status__c.getDescribe(), 'Draft');
        req.installments = new List<InstallmentPlansController.InstallmentInput>{ row };
        return InstallmentPlansController.saveInstallmentPlan(JSON.serialize(req));
    }

    @IsTest
    static void listApi_returnsWithoutError() {
        InstallmentPlansController.InstallmentInput row1 = new InstallmentPlansController.InstallmentInput();
        row1.order = 1;
        row1.percentage = 60;
        row1.startDate = Date.today();
        row1.dueDays = 10;
        InstallmentPlansController.InstallmentInput row2 = new InstallmentPlansController.InstallmentInput();
        row2.order = 2;
        row2.percentage = 40;
        row2.startDate = Date.today().addDays(11);
        row2.dueDays = 10;

        InstallmentPlansController.InstallmentPlanSaveRequest req =
            new InstallmentPlansController.InstallmentPlanSaveRequest();
        req.planName = 'InstPlan_' + String.valueOf(DateTime.now().getTime());
        req.installmentCode = 'IC_' + String.valueOf(DateTime.now().getTime());
        req.status = pickValue(Payment_Schedule__c.Status__c.getDescribe(), 'Draft');
        req.installmentFeePercentage = 10;
        req.installments = new List<InstallmentPlansController.InstallmentInput>{ row1, row2 };
        Id scheduleId = InstallmentPlansController.saveInstallmentPlan(JSON.serialize(req));

        Test.startTest();
        List<InstallmentPlansController.InstallmentPlanRow> rows = InstallmentPlansController.getInstallmentPlans();
        InstallmentPlansController.InstallmentPlanDetails details =
            InstallmentPlansController.getInstallmentPlanDetails(scheduleId);
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assert(rows.size() > 0);
        System.assertNotEquals(null, details);
        System.assertEquals(2, details.installments.size());
    }

    @IsTest
    static void detailAndSave_validateRequiredInputs() {
        try {
            InstallmentPlansController.getInstallmentPlanDetails(null);
            System.assert(false, 'Expected schedule id validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            InstallmentPlansController.saveInstallmentPlan(null);
            System.assert(false, 'Expected payload validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            InstallmentPlansController.saveInstallmentPlan('{"planName":"X"}');
            System.assert(false, 'Expected installment code validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            InstallmentPlansController.deleteInstallmentPlan(null);
            System.assert(false, 'Expected schedule id validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void saveInstallmentPlan_editMode_replacesRows() {
        InstallmentPlansController.InstallmentInput row = new InstallmentPlansController.InstallmentInput();
        row.order = 1;
        row.percentage = 100;
        row.startDate = Date.today();
        row.dueDays = 20;

        InstallmentPlansController.InstallmentPlanSaveRequest req =
            new InstallmentPlansController.InstallmentPlanSaveRequest();
        req.planName = 'InstEdit_' + String.valueOf(DateTime.now().getTime());
        req.installmentCode = 'ED_' + String.valueOf(DateTime.now().getTime());
        req.status = pickValue(Payment_Schedule__c.Status__c.getDescribe(), 'Draft');
        req.installments = new List<InstallmentPlansController.InstallmentInput>{ row };
        Id scheduleId = InstallmentPlansController.saveInstallmentPlan(JSON.serialize(req));

        InstallmentPlansController.InstallmentInput updatedRow = new InstallmentPlansController.InstallmentInput();
        updatedRow.order = 1;
        updatedRow.percentage = 100;
        updatedRow.startDate = Date.today().addDays(1);
        updatedRow.dueDays = 30;
        req.scheduleId = scheduleId;
        req.installments = new List<InstallmentPlansController.InstallmentInput>{ updatedRow };

        Id updatedId = InstallmentPlansController.saveInstallmentPlan(JSON.serialize(req));
        System.assertEquals(scheduleId, updatedId);
        Integer lineCount = [
            SELECT Count()
            FROM Payment_Schedule_Instalment__c
            WHERE Payment_Schedule__c = :scheduleId
        ];
        System.assertEquals(1, lineCount);
    }

    @IsTest
    static void saveInstallmentPlan_blocksDuplicateInstallmentCode() {
        InstallmentPlansController.InstallmentInput row = new InstallmentPlansController.InstallmentInput();
        row.order = 1;
        row.percentage = 100;
        row.startDate = Date.today();
        row.dueDays = 20;

        String duplicateCode = 'DUP_' + String.valueOf(DateTime.now().getTime());

        InstallmentPlansController.InstallmentPlanSaveRequest req1 =
            new InstallmentPlansController.InstallmentPlanSaveRequest();
        req1.planName = 'InstDup1_' + String.valueOf(DateTime.now().getTime());
        req1.installmentCode = duplicateCode;
        req1.status = pickValue(Payment_Schedule__c.Status__c.getDescribe(), 'Draft');
        req1.installments = new List<InstallmentPlansController.InstallmentInput>{ row };
        InstallmentPlansController.saveInstallmentPlan(JSON.serialize(req1));

        InstallmentPlansController.InstallmentPlanSaveRequest req2 =
            new InstallmentPlansController.InstallmentPlanSaveRequest();
        req2.planName = 'InstDup2_' + String.valueOf(DateTime.now().getTime());
        req2.installmentCode = duplicateCode;
        req2.status = pickValue(Payment_Schedule__c.Status__c.getDescribe(), 'Draft');
        req2.installments = new List<InstallmentPlansController.InstallmentInput>{ row };

        try {
            InstallmentPlansController.saveInstallmentPlan(JSON.serialize(req2));
            System.assert(false, 'Expected duplicate installment code validation.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Duplicate installment code'));
        }
    }

    @IsTest
    static void editAndDelete_areBlockedWhenInstallmentPlanUsedInProgrammeFees() {
        Id scheduleId = createInstallmentPlan('USED');

        Ken_Fee_Type__c feeType = new Ken_Fee_Type__c(
            Fee_Type_Name__c = 'Installment Usage',
            Status__c = pickValue(Ken_Fee_Type__c.Status__c.getDescribe(), 'Draft'),
            Payment_Schedule__c = scheduleId
        );
        insert feeType;

        List<InstallmentPlansController.InstallmentPlanRow> rows = InstallmentPlansController.getInstallmentPlans();
        InstallmentPlansController.InstallmentPlanRow usedRow;
        for (InstallmentPlansController.InstallmentPlanRow row : rows) {
            if (row.id == scheduleId) {
                usedRow = row;
                break;
            }
        }
        System.assertNotEquals(null, usedRow);
        System.assertEquals(1, usedRow.usedInProgrammeFees);

        InstallmentPlansController.InstallmentPlanDetails details =
            InstallmentPlansController.getInstallmentPlanDetails(scheduleId);
        System.assertEquals(true, details.isEditRestricted);
        System.assert(details.editRestrictionMessage.contains('Cannot edit or delete this installment plan'));
        System.assertEquals(1, details.usedInProgrammeFees);

        InstallmentPlansController.InstallmentInput updatedRow = new InstallmentPlansController.InstallmentInput();
        updatedRow.order = 1;
        updatedRow.percentage = 100;
        updatedRow.startDate = Date.today().addDays(1);
        updatedRow.dueDays = 30;

        InstallmentPlansController.InstallmentPlanSaveRequest req =
            new InstallmentPlansController.InstallmentPlanSaveRequest();
        req.scheduleId = scheduleId;
        req.planName = 'Blocked Update';
        req.installmentCode = 'USED_EDIT_' + String.valueOf(DateTime.now().getTime());
        req.status = pickValue(Payment_Schedule__c.Status__c.getDescribe(), 'Draft');
        req.installments = new List<InstallmentPlansController.InstallmentInput>{ updatedRow };

        try {
            InstallmentPlansController.saveInstallmentPlan(JSON.serialize(req));
            System.assert(false, 'Expected edit restriction when installment plan is used in programme fees.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Cannot edit or delete this installment plan'));
        }

        try {
            InstallmentPlansController.deleteInstallmentPlan(scheduleId);
            System.assert(false, 'Expected delete restriction when installment plan is used in programme fees.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Cannot edit or delete this installment plan'));
        }
    }

    @IsTest
    static void deleteInstallmentPlan_deletesUnusedPlan() {
        Id scheduleId = createInstallmentPlan('FREE');

        InstallmentPlansController.deleteInstallmentPlan(scheduleId);

        Integer scheduleCount = [SELECT Count() FROM Payment_Schedule__c WHERE Id = :scheduleId];
        Integer lineCount = [SELECT Count() FROM Payment_Schedule_Instalment__c WHERE Payment_Schedule__c = :scheduleId];
        System.assertEquals(0, scheduleCount);
        System.assertEquals(0, lineCount);
    }
}