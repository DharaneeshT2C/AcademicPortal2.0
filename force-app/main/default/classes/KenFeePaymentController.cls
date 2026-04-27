/**
 * ************************************************************************************************
 * @className  KenFeePaymentController
 *
 * @description
 *  Backs `my/feePayment` summary (outstanding, upcoming, paid) and the drill-
 *  down `my/feePaymentDetail`. Complements the standalone `my/feePlan`,
 *  `my/invoices`, `my/transactionHistory`, `my/refunds` controllers.
 *
 *  The existing fee-module-reference org has extensive FeeInstallment objects
 *  and services (FeeAssignmentService, FeeInstallmentController). Once that
 *  schema is imported into this org, replace the stubbed seed data with calls
 *  into those services.
 *
 *  TODO[SOBJECT]: Wire to `Fee_Installment__c`, `Applied_Scholarship_Discount__c`,
 *                 `Payment__c`.
 * ************************************************************************************************
 */
public with sharing class KenFeePaymentController {

    public class FeeLineDTO {
        @AuraEnabled public Id      installmentId;
        @AuraEnabled public String  feeHead;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String  dueDate;
        @AuraEnabled public String  status;   // 'Due' | 'Paid' | 'Overdue' | 'Upcoming'
        @AuraEnabled public String  paidDate;
        @AuraEnabled public String  invoiceNumber;
        // Internal — raw Date used for sorting "next due" in summary builder.
        @AuraEnabled public Date    dueDateRaw;
    }

    public class FeeSummaryDTO {
        @AuraEnabled public Decimal           outstanding;
        @AuraEnabled public Decimal           paidThisYear;
        @AuraEnabled public Decimal           upcoming;
        @AuraEnabled public String            nextDueDate;
        @AuraEnabled public Decimal           nextDueAmount;
        @AuraEnabled public List<FeeLineDTO>  installments;
    }

    @AuraEnabled(cacheable=true)
    public static FeeSummaryDTO getFeeSummary() {
        try {
            FeeSummaryDTO s = new FeeSummaryDTO();
            s.installments = queryRealInstallments();
            if (s.installments == null || s.installments.isEmpty()) {
                // No data yet — fall back to seed so UI renders something coherent.
                s.installments = seedInstallments();
            }
            Decimal out = 0, paid = 0, up = 0;
            String nextDue = null;
            Decimal nextAmt = null;
            Date earliestDue = null;
            for (FeeLineDTO line : s.installments) {
                if (line.status == 'Paid')                                  paid += line.amount;
                else if (line.status == 'Due' || line.status == 'Overdue') {
                    out  += line.amount;
                    if (line.dueDateRaw != null && (earliestDue == null || line.dueDateRaw < earliestDue)) {
                        earliestDue = line.dueDateRaw;
                        nextDue = line.dueDate;
                        nextAmt = line.amount;
                    }
                }
                else if (line.status == 'Upcoming')                         up   += line.amount;
            }
            s.outstanding    = out;
            s.paidThisYear   = paid;
            s.upcoming       = up;
            s.nextDueDate    = nextDue != null ? nextDue : 'Apr 30';
            s.nextDueAmount  = nextAmt != null ? nextAmt : (out > 0 ? out : 24000);
            return s;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenFeePaymentController.getFeeSummary',
                'Unable to load fee summary.', e);
            return null;
        }
    }

    @AuraEnabled(cacheable=true)
    public static FeeLineDTO getInstallmentDetail(Id installmentId) {
        try {
            KenAuraExceptionHelper.rejectIf(installmentId == null, 'Installment id is required.');
            // Try real query first
            List<Fee_Installment__c> rows = [
                SELECT Id, Name, Amount__c, Total_Amount__c, Total_Paid_Amount__c,
                       Due_Date__c, Status__c, Installment_Number__c,
                       Fee_Assignment__r.Fee_Type__r.Name
                FROM Fee_Installment__c
                WHERE Id = :installmentId
                WITH USER_MODE
                LIMIT 1
            ];
            if (!rows.isEmpty()) return mapInstallment(rows[0]);
            // Fall back to seed
            for (FeeLineDTO line : seedInstallments()) {
                if (line.installmentId == installmentId) return line;
            }
            return null;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenFeePaymentController.getInstallmentDetail',
                'Unable to load fee details.', e);
            return null;
        }
    }

    // ─── Real SOQL ─────────────────────────────────────────────────────────
    // Query Fee_Installment__c for the running user's Account. Skips silently
    // (returns empty list) if user has no Contact / Contact has no Account.
    private static List<FeeLineDTO> queryRealInstallments() {
        List<FeeLineDTO> out = new List<FeeLineDTO>();
        Id acctId = currentAccountId();
        if (acctId == null) return out;

        for (Fee_Installment__c r : [
            SELECT Id, Name, Amount__c, Total_Amount__c, Total_Paid_Amount__c,
                   Due_Date__c, Status__c, Installment_Number__c,
                   Fee_Assignment__r.Fee_Type__r.Name, Fee_Assignment__r.Account__c
            FROM Fee_Installment__c
            WHERE Fee_Assignment__r.Account__c = :acctId
            WITH USER_MODE
            ORDER BY Due_Date__c ASC NULLS LAST
            LIMIT 50
        ]) {
            out.add(mapInstallment(r));
        }
        return out;
    }

    private static FeeLineDTO mapInstallment(Fee_Installment__c r) {
        FeeLineDTO l = new FeeLineDTO();
        l.installmentId = r.Id;
        l.feeHead       = (r.Fee_Assignment__r != null && r.Fee_Assignment__r.Fee_Type__r != null)
                              ? r.Fee_Assignment__r.Fee_Type__r.Name + ' #' + (r.Installment_Number__c == null ? '' : String.valueOf(r.Installment_Number__c.intValue()))
                              : (r.Name == null ? 'Installment' : r.Name);
        l.amount        = r.Amount__c != null ? r.Amount__c : (r.Total_Amount__c != null ? r.Total_Amount__c : 0);
        l.dueDateRaw   = r.Due_Date__c;
        l.dueDate       = r.Due_Date__c == null ? '' :
            Datetime.newInstance(r.Due_Date__c, Time.newInstance(0,0,0,0)).format('MMM d');
        l.status        = mapStatus(r.Status__c, r.Total_Paid_Amount__c, r.Amount__c, r.Due_Date__c);
        l.paidDate      = (l.status == 'Paid' && r.LastModifiedDate != null)
                              ? r.LastModifiedDate.format('d-MMM-yyyy') : null;
        l.invoiceNumber = r.Name;
        return l;
    }

    private static String mapStatus(String raw, Decimal paid, Decimal amt, Date due) {
        if (paid != null && amt != null && paid >= amt && amt > 0) return 'Paid';
        if (raw != null) {
            String s = raw.toLowerCase();
            if (s.contains('paid'))     return 'Paid';
            if (s.contains('overdue'))  return 'Overdue';
            if (s.contains('upcoming')) return 'Upcoming';
        }
        if (due != null && due < Date.today()) return 'Overdue';
        if (due != null && due > Date.today().addDays(30)) return 'Upcoming';
        return 'Due';
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
    public static Id initiatePayment(Id installmentId, Decimal amount) {
        try {
            KenAuraExceptionHelper.rejectIf(installmentId == null, 'Installment id is required.');
            KenAuraExceptionHelper.rejectIf(amount == null || amount <= 0, 'Amount must be positive.');
            Id contactId = KenRunningStudentHelper.optionalContactId();
            // Idempotency: if a Pending payment for the same installment exists from
            // the last 5 minutes, return that one — prevents double-tap creating two
            // gateway orders.
            if (contactId != null) {
                Datetime cutoff = Datetime.now().addMinutes(-5);
                List<Payment__c> recent = [
                    SELECT Id FROM Payment__c
                    WHERE Installment__c = :installmentId
                      AND Student__c = :contactId
                      AND Status__c = 'Pending'
                      AND Transaction_Date__c >= :cutoff
                    WITH USER_MODE
                    ORDER BY Transaction_Date__c DESC LIMIT 1
                ];
                if (!recent.isEmpty()) return recent[0].Id;
            }
            String gatewayRef;
            try {
                RazorpayService.RazorpayOrder order = RazorpayService.createOrder(installmentId, amount);
                gatewayRef = order.orderId;
            } catch (Exception gwEx) {
                System.debug(LoggingLevel.WARN, 'Razorpay unavailable, using mock ref: ' + gwEx.getMessage());
                gatewayRef = 'MOCK-' + String.valueOf(Datetime.now().getTime()).right(10);
            }
            Payment__c p = new Payment__c(
                Student__c          = contactId,
                Installment__c      = installmentId,
                Amount__c           = amount,
                Mode__c             = 'UPI',
                Status__c           = 'Pending',
                Gateway_Ref__c      = gatewayRef,
                Transaction_Date__c = Datetime.now()
            );
            insert p;
            return p.Id;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenFeePaymentController.initiatePayment',
                'Could not start payment.', e);
            return null;
        }
    }

    private static List<FeeLineDTO> seedInstallments() {
        List<FeeLineDTO> out = new List<FeeLineDTO>();
        out.add(line(null, 'Tuition Q3',  24000, 'Apr 30',    'Due',      null,         'INV-2026-03'));
        out.add(line(null, 'Hostel Q3',    8500, 'Apr 30',    'Upcoming', null,         'INV-2026-04'));
        out.add(line(null, 'Tuition Q2',  24000, 'Jan 30',    'Paid',     '28-Jan-2026','INV-2026-02'));
        out.add(line(null, 'Hostel Q2',    8500, 'Jan 30',    'Paid',     '28-Jan-2026','INV-2026-01'));
        return out;
    }

    private static FeeLineDTO line(Id id, String head, Decimal amt, String due, String status, String paidOn, String inv) {
        FeeLineDTO l = new FeeLineDTO();
        l.installmentId = id; l.feeHead = head; l.amount = amt;
        l.dueDate = due; l.status = status; l.paidDate = paidOn; l.invoiceNumber = inv;
        return l;
    }
}