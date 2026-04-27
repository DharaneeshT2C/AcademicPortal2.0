@IsTest
private class TaxesControllerTest {
    @IsTest
    static void readApis_returnWithoutError() {
        Id parentId = TaxesController.saveTax('ParentTax_' + String.valueOf(DateTime.now().getTime()), 8, null);
        TaxesController.saveTax('ChildTax_' + String.valueOf(DateTime.now().getTime()), 4, parentId);

        Test.startTest();
        List<TaxesController.TaxRow> taxes = TaxesController.getTaxes();
        List<TaxesController.TaxRow> options = TaxesController.getTaxOptions();
        Test.stopTest();

        System.assertNotEquals(null, taxes);
        System.assertNotEquals(null, options);
        System.assert(taxes.size() > 0);
        System.assert(options.size() > 0);
    }

    @IsTest
    static void saveTax_validatesName() {
        try {
            TaxesController.saveTax(' ', 10, null);
            System.assert(false, 'Expected tax name validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }
    }
}