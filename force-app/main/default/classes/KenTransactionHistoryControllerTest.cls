/**
 * ************************************************************************************************
 * @className  KenTransactionHistoryControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenTransactionHistoryControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void transactionsReturnList() {
        Test.startTest();
        List<KenTransactionHistoryController.TransactionDTO> txns = KenTransactionHistoryController.getTransactions();
        Test.stopTest();

        System.assertNotEquals(null, txns);
        System.assertEquals(true, txns.size() > 0);
        for (KenTransactionHistoryController.TransactionDTO t : txns) {
            System.assertNotEquals(null, t.status);
            System.assertNotEquals(null, t.mode);
        }
    }
}