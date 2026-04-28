/**
 * ************************************************************************************************
 * @className  KenInvoicesController
 *
 * @description
 *  Backs `my/invoices` — list invoices with download links.
 *
 *  TODO[SOBJECT]: Wire to `Invoice__c` + ContentDocumentLink for PDF storage.
 * ************************************************************************************************
 */
public without sharing class KenInvoicesController {

    public class InvoiceDTO {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  invoiceNumber;
        @AuraEnabled public String  description;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String  issuedOn;
        @AuraEnabled public String  status;       // 'Paid' | 'Unpaid' | 'Overdue'
        @AuraEnabled public String  downloadUrl;
    }

    @AuraEnabled(cacheable=true)
    public static List<InvoiceDTO> getInvoices() {
        try {
            Id acctId = currentAccountId();
            if (acctId == null) return new List<InvoiceDTO>();
            List<InvoiceDTO> out = new List<InvoiceDTO>();
            for (Fee_Installment__c r : [
                SELECT Id, Name, Amount__c, Total_Amount__c, Total_Paid_Amount__c,
                       Due_Date__c, Status__c, Installment_Number__c,
                       Fee_Assignment__r.Fee_Type__r.Name, Fee_Assignment__r.Fee_Assignment_Name__c
                FROM Fee_Installment__c
                WHERE Fee_Assignment__r.Account__c = :acctId
                WITH SECURITY_ENFORCED
                ORDER BY Due_Date__c DESC NULLS LAST
                LIMIT 50
            ]) {
                InvoiceDTO i = new InvoiceDTO();
                i.id            = r.Id;
                i.invoiceNumber = r.Name;
                String head     = (r.Fee_Assignment__r != null && r.Fee_Assignment__r.Fee_Assignment_Name__c != null)
                                      ? r.Fee_Assignment__r.Fee_Assignment_Name__c : 'Fee';
                String num      = r.Installment_Number__c == null ? '' : ' #' + String.valueOf(r.Installment_Number__c.intValue());
                i.description   = head + num;
                i.amount        = r.Amount__c != null ? r.Amount__c : (r.Total_Amount__c != null ? r.Total_Amount__c : 0);
                i.issuedOn      = r.Due_Date__c == null ? '' :
                                      Datetime.newInstance(r.Due_Date__c, Time.newInstance(0,0,0,0)).format('d-MMM-yyyy');
                Boolean isPaid  = r.Total_Paid_Amount__c != null && r.Amount__c != null
                                      && r.Total_Paid_Amount__c >= r.Amount__c && r.Amount__c > 0;
                i.status        = isPaid ? 'Paid'
                                  : (r.Due_Date__c != null && r.Due_Date__c < Date.today() ? 'Overdue' : 'Unpaid');
                i.downloadUrl   = '';
                out.add(i);
            }
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenInvoicesController.getInvoices',
                'Unable to load invoices.', e);
            return null;
        }
    }

    private static Id currentAccountId() {
        try {
            User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            if (u.ContactId == null) return null;
            Contact c = [SELECT AccountId FROM Contact WHERE Id = :u.ContactId LIMIT 1];
            return c.AccountId;
        } catch (Exception e) { return null; }
    }

    @AuraEnabled
    public static String getDownloadUrl(Id invoiceId) {
        try {
            KenAuraExceptionHelper.rejectIf(invoiceId == null, 'Invoice id is required.');
            // Look for any file attached to this Fee_Installment__c (or Fee_Assignment__c)
            // via ContentDocumentLink. Return the latest published Salesforce file URL.
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :invoiceId
                ORDER BY SystemModstamp DESC
                LIMIT 1
            ];
            if (links.isEmpty()) {
                // No file attached — generate the PDF on-the-fly via Visualforce
                return '/apex/InvoicePdf?id=' + invoiceId;
            }
            // Standard Salesforce file download endpoint
            return '/sfc/servlet.shepherd/document/download/' + links[0].ContentDocumentId;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenInvoicesController.getDownloadUrl',
                'Could not generate invoice link.', e);
            return null;
        }
    }

}