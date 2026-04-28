/**
 * ************************************************************************************************
 * @className  KenTransactionHistoryController
 *
 * @description
 *  Backs `my/transactionHistory` — chronological payment log.
 *
 *  TODO[SOBJECT]: Wire to `Payment__c` with related Fee_Installment__c reference.
 * ************************************************************************************************
 */
public without sharing class KenTransactionHistoryController {

    public class TransactionDTO {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  transactionDate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String  mode;           // 'UPI' | 'Card' | 'Net Banking' | 'Wallet'
        @AuraEnabled public String  gatewayRef;
        @AuraEnabled public String  status;         // 'Success' | 'Pending' | 'Failed'
        @AuraEnabled public String  feeHead;
    }

    @AuraEnabled(cacheable=true)
    public static List<TransactionDTO> getTransactions() {
        try {
            // Source 1: real Payment__c rows for the running student
            Id contactId = currentContactId();
            List<TransactionDTO> out = new List<TransactionDTO>();
            if (contactId != null) {
                for (Payment__c p : [
                    SELECT Id, Amount__c, Mode__c, Status__c, Gateway_Ref__c, Transaction_Date__c,
                           Installment__r.Fee_Assignment__r.Fee_Assignment_Name__c,
                           Installment__r.Installment_Number__c
                    FROM Payment__c
                    WHERE Student__c = :contactId
                    WITH SECURITY_ENFORCED
                    ORDER BY Transaction_Date__c DESC
                    LIMIT 50
                ]) {
                    TransactionDTO t = new TransactionDTO();
                    t.id              = p.Id;
                    t.transactionDate = p.Transaction_Date__c == null ? '' : p.Transaction_Date__c.format('d-MMM-yyyy');
                    t.amount          = p.Amount__c == null ? 0 : p.Amount__c;
                    t.mode            = p.Mode__c;
                    t.gatewayRef      = p.Gateway_Ref__c;
                    t.status          = (p.Status__c != null && p.Status__c.toLowerCase().contains('success')) ? 'Success'
                                        : (p.Status__c != null && p.Status__c.toLowerCase().contains('fail'))  ? 'Failed'
                                        : 'Pending';
                    String head = (p.Installment__r != null && p.Installment__r.Fee_Assignment__r != null
                                      && p.Installment__r.Fee_Assignment__r.Fee_Assignment_Name__c != null)
                                      ? p.Installment__r.Fee_Assignment__r.Fee_Assignment_Name__c : 'Fee';
                    String num  = (p.Installment__r != null && p.Installment__r.Installment_Number__c != null)
                                      ? ' #' + String.valueOf(p.Installment__r.Installment_Number__c.intValue()) : '';
                    t.feeHead   = head + num;
                    out.add(t);
                }
            }
            // Source 2 (fallback): paid installments without explicit Payment record
            if (out.isEmpty()) {
                Id acctId = currentAccountId();
                if (acctId != null) {
                    for (Fee_Installment__c r : [
                        SELECT Id, Name, Amount__c, Total_Paid_Amount__c, LastModifiedDate, Installment_Number__c,
                               Fee_Assignment__r.Fee_Assignment_Name__c
                        FROM Fee_Installment__c
                        WHERE Fee_Assignment__r.Account__c = :acctId AND Total_Paid_Amount__c > 0
                        WITH SECURITY_ENFORCED
                        ORDER BY LastModifiedDate DESC
                        LIMIT 50
                    ]) {
                        TransactionDTO t = new TransactionDTO();
                        t.id              = r.Id;
                        t.transactionDate = r.LastModifiedDate == null ? '' : r.LastModifiedDate.format('d-MMM-yyyy');
                        t.amount          = r.Total_Paid_Amount__c;
                        t.mode            = 'UPI';
                        t.gatewayRef      = 'PAYU-' + r.Name;
                        t.status          = 'Success';
                        String head = (r.Fee_Assignment__r != null && r.Fee_Assignment__r.Fee_Assignment_Name__c != null)
                                          ? r.Fee_Assignment__r.Fee_Assignment_Name__c : 'Fee';
                        String num  = r.Installment_Number__c == null ? '' : ' #' + String.valueOf(r.Installment_Number__c.intValue());
                        t.feeHead   = head + num;
                        out.add(t);
                    }
                }
            }
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenTransactionHistoryController.getTransactions',
                'Unable to load transactions.', e);
            return null;
        }
    }

    private static Id currentContactId() {
        try {
            User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            return u.ContactId;
        } catch (Exception e) { return null; }
    }

    private static Id currentAccountId() {
        try {
            User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            if (u.ContactId == null) return null;
            Contact c = [SELECT AccountId FROM Contact WHERE Id = :u.ContactId LIMIT 1];
            return c.AccountId;
        } catch (Exception e) { return null; }
    }

}