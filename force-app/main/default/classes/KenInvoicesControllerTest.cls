/**
 * ************************************************************************************************
 * @className  KenInvoicesControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenInvoicesControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void invoicesReturnsList() {
        Test.startTest();
        List<KenInvoicesController.InvoiceDTO> invoices = KenInvoicesController.getInvoices();
        Test.stopTest();

        System.assertNotEquals(null, invoices);
        System.assertEquals(true, invoices.size() > 0);
    }

    @isTest
    static void downloadRejectsNullId() {
        Test.startTest();
        Boolean threw = false;
        try { KenInvoicesController.getDownloadUrl(null); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void downloadReturnsUrl() {
        Id fakeId = UserInfo.getUserId();
        Test.startTest();
        String url = KenInvoicesController.getDownloadUrl(fakeId);
        Test.stopTest();

        System.assertNotEquals(null, url);
    }
}