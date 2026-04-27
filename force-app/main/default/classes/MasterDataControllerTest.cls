@IsTest
private class MasterDataControllerTest {
    private static String pickValue(Schema.DescribeFieldResult dfr) {
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe != null && pe.isActive()) {
                return pe.getValue();
            }
        }
        return null;
    }

    @IsTest
    static void getMasterDataSummary_returnsExpectedModules() {
        TaxesController.saveTax('MDC_Tax_' + String.valueOf(DateTime.now().getTime()), 5, null);
        RemittanceAccountsController.createRemittanceAccount(
            'MDC_RA',
            'Bank',
            'MD123',
            'LED-MD',
            'Program Level',
            null,
            null,
            null,
            null,
            true
        );
        Payment_Schedule__c schedule = new Payment_Schedule__c(
            Name = 'MDC_Schedule',
            Installment_Code__c = 'MDC-INS',
            Status__c = pickValue(Payment_Schedule__c.Status__c.getDescribe()),
            Number_of_Scheduled_Payments__c = 1,
            Fee_Collection_Start_Date__c = Date.today(),
            Fee_Collection_End_Date__c = Date.today().addDays(1)
        );
        insert schedule;

        Test.startTest();
        List<MasterDataController.ModuleSummary> rows = MasterDataController.getMasterDataSummary();
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertEquals(9, rows.size(), 'Expected all master-data modules.');
        for (MasterDataController.ModuleSummary row : rows) {
            System.assertNotEquals(null, row.key);
            System.assertNotEquals(null, row.title);
        }
    }
}