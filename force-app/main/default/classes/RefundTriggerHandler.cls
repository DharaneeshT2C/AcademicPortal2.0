public with sharing class RefundTriggerHandler {

    public static void handleAfterInsert(List<Refund__c> newRefunds) {
        if (newRefunds == null || newRefunds.isEmpty()) {
            return;
        }

        // 1. Collect Account Ids from Refunds
        Set<Id> accountIds = new Set<Id>();
        Map<Id, List<Refund__c>> refundsByAccountId = new Map<Id, List<Refund__c>>();

        for (Refund__c refundRec : newRefunds) {
            if (refundRec.Account__c == null) {
                continue;
            }

            accountIds.add(refundRec.Account__c);

            if (!refundsByAccountId.containsKey(refundRec.Account__c)) {
                refundsByAccountId.put(refundRec.Account__c, new List<Refund__c>());
            }
            refundsByAccountId.get(refundRec.Account__c).add(refundRec);
        }

        if (accountIds.isEmpty()) {
            return;
        }

        // 2. Fetch related Payment Transactions for those Accounts
        List<Payment_Transaction__c> paymentTransactions = [
            SELECT Id, Account__c, Refund__c
            FROM Payment_Transaction__c
            WHERE Account__c IN :accountIds
            ORDER BY CreatedDate DESC
        ];

        // 3. Group Payment Transactions by Account
        Map<Id, List<Payment_Transaction__c>> paymentTxnsByAccountId = new Map<Id, List<Payment_Transaction__c>>();

        for (Payment_Transaction__c txn : paymentTransactions) {
            if (!paymentTxnsByAccountId.containsKey(txn.Account__c)) {
                paymentTxnsByAccountId.put(txn.Account__c, new List<Payment_Transaction__c>());
            }
            paymentTxnsByAccountId.get(txn.Account__c).add(txn);
        }

        List<Payment_Transaction__c> paymentTransactionsToUpdate = new List<Payment_Transaction__c>();
        List<Fee_Assignment__c> feeAssignmentsToInsert = new List<Fee_Assignment__c>();

        // 4. For each account, pair refunds with payment transactions
        for (Id accountId : refundsByAccountId.keySet()) {
            List<Refund__c> refundsForAccount = refundsByAccountId.get(accountId);
            List<Payment_Transaction__c> txnsForAccount = paymentTxnsByAccountId.get(accountId);

            if (txnsForAccount == null || txnsForAccount.isEmpty()) {
                continue;
            }

            Integer limitSize = Math.min(refundsForAccount.size(), txnsForAccount.size());

            for (Integer i = 0; i < limitSize; i++) {
                Refund__c refundRec = refundsForAccount[i];
                Payment_Transaction__c matchedTxn = txnsForAccount[i];

                // Update Payment Transaction with Refund Id
                if (matchedTxn.Refund__c == null) {
                    paymentTransactionsToUpdate.add(
                        new Payment_Transaction__c(
                            Id = matchedTxn.Id,
                            Refund__c = refundRec.Id
                        )
                    );
                }

                // Create Fee Assignment
                Fee_Assignment__c feeAssignment = new Fee_Assignment__c();
              //  feeAssignment.Refund__c = refundRec.Id;
                feeAssignment.Account__c = refundRec.Account__c;
             //   feeAssignment.Contact__c = refundRec.Contact__c;
            //    feeAssignment.Payment_Transaction__c = matchedTxn.Id;
           //     feeAssignment.Amount__c = refundRec.Refund_Amount__c;
                feeAssignment.Status__c = 'Initiated';

                feeAssignmentsToInsert.add(feeAssignment);
            }
        }

        if (!paymentTransactionsToUpdate.isEmpty()) {
            update paymentTransactionsToUpdate;
        }

        if (!feeAssignmentsToInsert.isEmpty()) {
            insert feeAssignmentsToInsert;
        }
    }
}