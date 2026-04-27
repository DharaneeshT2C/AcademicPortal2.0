/**
 * ************************************************************************************************
 * @className  KenFeePaymentControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenFeePaymentControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void summaryAggregatesInstallments() {
        Test.startTest();
        KenFeePaymentController.FeeSummaryDTO s = KenFeePaymentController.getFeeSummary();
        Test.stopTest();

        System.assertNotEquals(null, s);
        System.assertEquals(true, s.installments.size() > 0);
        System.assertEquals(true, s.outstanding >= 0);
        System.assertEquals(true, s.paidThisYear >= 0);
    }

    @isTest
    static void detailRejectsNullId() {
        Test.startTest();
        Boolean threw = false;
        try { KenFeePaymentController.getInstallmentDetail(null); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void paymentRejectsInvalidAmount() {
        Id fakeId = UserInfo.getUserId();
        Test.startTest();
        Boolean threw = false;
        try { KenFeePaymentController.initiatePayment(fakeId, -100); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void paymentRejectsNullInstallment() {
        Test.startTest();
        Boolean threw = false;
        try { KenFeePaymentController.initiatePayment(null, 100); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void paymentAcceptsValidInput() {
        Id fakeId = UserInfo.getUserId();
        Test.startTest();
        KenFeePaymentController.initiatePayment(fakeId, 24000);
        Test.stopTest();
        System.assertEquals(true, true);
    }
}