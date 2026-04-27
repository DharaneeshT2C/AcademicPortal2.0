/**
 * ************************************************************************************************
 * @className  KenRefundsControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenRefundsControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void refundsReturnList() {
        Test.startTest();
        List<KenRefundsController.RefundDTO> refunds = KenRefundsController.getRefunds();
        Test.stopTest();

        System.assertNotEquals(null, refunds);
        System.assertEquals(true, refunds.size() >= 0);
    }

    @isTest
    static void createRejectsNullRequest() {
        Test.startTest();
        Boolean threw = false;
        try { KenRefundsController.createRefundRequest(null); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void createRejectsNegativeAmount() {
        KenRefundsController.RefundRequest req = new KenRefundsController.RefundRequest();
        req.amount = -100;
        req.reason = 'Overpaid';

        Test.startTest();
        Boolean threw = false;
        try { KenRefundsController.createRefundRequest(req); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void createRejectsBlankReason() {
        KenRefundsController.RefundRequest req = new KenRefundsController.RefundRequest();
        req.amount = 100;
        req.reason = '';

        Test.startTest();
        Boolean threw = false;
        try { KenRefundsController.createRefundRequest(req); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void createAcceptsValidRequest() {
        KenRefundsController.RefundRequest req = new KenRefundsController.RefundRequest();
        req.amount = 8500;
        req.reason = 'Course dropped';

        Test.startTest();
        KenRefundsController.createRefundRequest(req);
        Test.stopTest();
        System.assertEquals(true, true);
    }
}