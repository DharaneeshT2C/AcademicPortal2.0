/**
 * ************************************************************************************************
 * @className  KenRefundsController
 *
 * @description
 *  Backs `my/refunds` — refund request creation and status tracking.
 *
 *  TODO[SOBJECT]: Wire to `Refund_Request__c` (Student__c, Amount__c,
 *                 Reason__c, Status__c, Original_Payment__c).
 * ************************************************************************************************
 */
public with sharing class KenRefundsController {

    public class RefundDTO {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  requestDate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String  reason;
        @AuraEnabled public String  status;   // 'Pending' | 'Approved' | 'Rejected' | 'Processed'
        @AuraEnabled public String  processedDate;
        @AuraEnabled public String  originalPaymentRef;
    }

    public class RefundRequest {
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String  reason;
        @AuraEnabled public Id      paymentId;
    }

    @AuraEnabled(cacheable=true)
    public static List<RefundDTO> getRefunds() {
        try {
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId == null) return seedRefunds();
            List<RefundDTO> out = new List<RefundDTO>();
            for (Refund_Request__c r : [
                SELECT Id, Amount__c, Reason__c, Status__c, Request_Date__c, Processed_Date__c, Original_Payment__c
                FROM Refund_Request__c
                WHERE Student__c = :contactId
                WITH USER_MODE
                ORDER BY Request_Date__c DESC
                LIMIT 50
            ]) {
                RefundDTO d = new RefundDTO();
                d.id                 = r.Id;
                d.requestDate        = r.Request_Date__c == null ? '' : r.Request_Date__c.format();
                d.amount             = r.Amount__c == null ? 0 : r.Amount__c;
                d.reason             = r.Reason__c;
                d.status             = r.Status__c;
                d.processedDate      = r.Processed_Date__c == null ? null : r.Processed_Date__c.format();
                d.originalPaymentRef = r.Original_Payment__c == null ? '' : String.valueOf(r.Original_Payment__c);
                out.add(d);
            }
            if (out.isEmpty()) return seedRefunds();
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenRefundsController.getRefunds',
                'Unable to load refunds.', e);
            return null;
        }
    }

    @AuraEnabled
    public static Id createRefundRequest(RefundRequest req) {
        try {
            KenAuraExceptionHelper.rejectIf(req == null, 'Request is empty.');
            KenAuraExceptionHelper.rejectIf(req.amount == null || req.amount <= 0, 'Amount must be positive.');
            KenAuraExceptionHelper.rejectIf(String.isBlank(req.reason), 'Reason is required.');
            Id studentId = KenRunningStudentHelper.optionalContactId();
            // Idempotency: same payment + same student in the last 5 minutes is
            // a duplicate. Reason__c is a LongTextArea (can't be in WHERE), so
            // we dedupe on payment + amount + recency only.
            if (studentId != null && req.paymentId != null) {
                Datetime cutoff = Datetime.now().addMinutes(-5);
                List<Refund_Request__c> dupes = [
                    SELECT Id FROM Refund_Request__c
                    WHERE Student__c = :studentId
                      AND Original_Payment__c = :req.paymentId
                      AND Amount__c = :req.amount
                      AND CreatedDate >= :cutoff
                    WITH USER_MODE LIMIT 1
                ];
                if (!dupes.isEmpty()) return dupes[0].Id;
            }
            KenCrudFlsHelper.assertCreateable(Refund_Request__c.SObjectType);
            Refund_Request__c rec = new Refund_Request__c(
                Student__c          = studentId,
                Amount__c           = req.amount,
                Reason__c           = req.reason,
                Status__c           = 'Pending',
                Request_Date__c     = Date.today(),
                Original_Payment__c = req.paymentId
            );
            insert rec;
            return rec.Id;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenRefundsController.createRefundRequest',
                'Could not submit refund request.', e);
            return null;
        }
    }

    private static List<RefundDTO> seedRefunds() {
        List<RefundDTO> out = new List<RefundDTO>();
        out.add(refund(null, '15-Mar-2026', 8500, 'Course dropped — hostel fee refund', 'Processed', '22-Mar-2026', 'PAYU-8Z2L'));
        out.add(refund(null, '10-Apr-2026', 1200, 'Duplicate mess fee',                  'Pending',   null,          'PAYU-9A3M'));
        return out;
    }

    private static RefundDTO refund(Id id, String reqDate, Decimal amt, String reason, String status, String procDate, String origRef) {
        RefundDTO r = new RefundDTO();
        r.id = id; r.requestDate = reqDate; r.amount = amt; r.reason = reason;
        r.status = status; r.processedDate = procDate; r.originalPaymentRef = origRef;
        return r;
    }
}