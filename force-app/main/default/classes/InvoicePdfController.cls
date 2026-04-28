/**
 * Backs the InvoicePdf Visualforce page. Loads the Fee_Installment__c (id passed
 * via ?id=) and the student's display name + email so the PDF renders with real
 * billing info.
 */
public without sharing class InvoicePdfController {
    public InvoiceVM inv { get; set; }
    public String studentName { get; set; }
    public String studentEmail { get; set; }

    public InvoicePdfController() {
        Id installmentId = ApexPages.currentPage().getParameters().get('id');
        if (installmentId == null) {
            inv = blankInvoice();
            return;
        }
        try {
            Fee_Installment__c r = [
                SELECT Id, Name, Amount__c, Total_Amount__c, Total_Paid_Amount__c,
                       Due_Date__c, Status__c, Installment_Number__c,
                       Fee_Assignment__r.Fee_Assignment_Name__c,
                       Fee_Assignment__r.Account__c
                FROM Fee_Installment__c
                WHERE Id = :installmentId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            inv = new InvoiceVM();
            inv.invoiceNumber = r.Name;
            inv.amount        = (r.Amount__c == null ? '0' : String.valueOf(r.Amount__c.setScale(2)));
            inv.issuedOn      = (r.Due_Date__c == null ? '' :
                                  Datetime.newInstance(r.Due_Date__c, Time.newInstance(0,0,0,0)).format('d MMM yyyy'));
            String head       = (r.Fee_Assignment__r != null && r.Fee_Assignment__r.Fee_Assignment_Name__c != null)
                                  ? r.Fee_Assignment__r.Fee_Assignment_Name__c : 'Fee';
            String num        = r.Installment_Number__c == null ? '' :
                                  ' — Installment ' + String.valueOf(r.Installment_Number__c.intValue());
            inv.description   = head + num;
            Boolean isPaid    = r.Total_Paid_Amount__c != null && r.Amount__c != null
                                  && r.Total_Paid_Amount__c >= r.Amount__c && r.Amount__c > 0;
            inv.status        = isPaid ? 'Paid'
                                : (r.Due_Date__c != null && r.Due_Date__c < Date.today() ? 'Overdue' : 'Unpaid');
            // Get student info via Contact ↔ Account
            if (r.Fee_Assignment__r != null && r.Fee_Assignment__r.Account__c != null) {
                List<Contact> contacts = [
                    SELECT FirstName, LastName, Email
                    FROM Contact
                    WHERE AccountId = :r.Fee_Assignment__r.Account__c
                    LIMIT 1
                ];
                if (!contacts.isEmpty()) {
                    studentName  = (contacts[0].FirstName == null ? '' : contacts[0].FirstName + ' ') + contacts[0].LastName;
                    studentEmail = contacts[0].Email;
                }
            }
            if (String.isBlank(studentName))  studentName = 'Student';
            if (String.isBlank(studentEmail)) studentEmail = '';
        } catch (Exception e) {
            inv = blankInvoice();
        }
    }

    private static InvoiceVM blankInvoice() {
        InvoiceVM v = new InvoiceVM();
        v.invoiceNumber = 'N/A'; v.amount = '0'; v.issuedOn = '—';
        v.description = 'Invoice not found'; v.status = 'Unpaid';
        return v;
    }

    public class InvoiceVM {
        public String invoiceNumber { get; set; }
        public String amount { get; set; }
        public String issuedOn { get; set; }
        public String description { get; set; }
        public String status { get; set; }
    }
}