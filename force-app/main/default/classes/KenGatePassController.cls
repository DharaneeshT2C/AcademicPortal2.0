/**
 * ************************************************************************************************
 * @className  KenGatePassController
 *
 * @description
 *  Backs `my/gatePass` (history + status) and `my/createGatePass` (new request
 *  form).
 *
 *  TODO[SOBJECT]: Wire to `Gate_Pass__c` (Student__c, Out_Time__c, Return_Time__c,
 *                 Reason__c, Destination__c, Status__c, Approver__c).
 * ************************************************************************************************
 */
public without sharing class KenGatePassController {

    public class GatePassDTO {
        @AuraEnabled public Id     id;
        @AuraEnabled public String reason;
        @AuraEnabled public String destination;
        @AuraEnabled public String outDateTime;
        @AuraEnabled public String returnDateTime;
        @AuraEnabled public String status;        // 'Pending' | 'Approved' | 'Rejected' | 'Completed'
        @AuraEnabled public String approverName;
        @AuraEnabled public String qrCode;
    }

    public class GatePassRequest {
        @AuraEnabled public String reason;
        @AuraEnabled public String destination;
        @AuraEnabled public String outDateTime;
        @AuraEnabled public String returnDateTime;
        @AuraEnabled public String requestType; // Student Exit Request | Visitor Request — informational only
    }

    @AuraEnabled(cacheable=true)
    public static List<GatePassDTO> getGatePasses() {
        try {
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId == null) return new List<GatePassDTO>();
            List<GatePassDTO> out = new List<GatePassDTO>();
            for (Gate_Pass__c r : [
                SELECT Id, Reason__c, Destination__c, Out_Date_Time__c, Return_Date_Time__c,
                       Status__c, Approver_Name__c, QR_Code__c
                FROM Gate_Pass__c
                WHERE Student__c = :contactId
                WITH SECURITY_ENFORCED
                ORDER BY Out_Date_Time__c DESC
                LIMIT 50
            ]) {
                GatePassDTO p = new GatePassDTO();
                p.id             = r.Id;
                p.reason         = r.Reason__c;
                p.destination    = r.Destination__c;
                p.outDateTime    = r.Out_Date_Time__c == null ? '' : r.Out_Date_Time__c.format('d-MMM h:mm a');
                p.returnDateTime = r.Return_Date_Time__c == null ? '' : r.Return_Date_Time__c.format('d-MMM h:mm a');
                p.status         = r.Status__c;
                p.approverName   = r.Approver_Name__c;
                p.qrCode         = r.QR_Code__c;
                out.add(p);
            }
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenGatePassController.getGatePasses',
                'Unable to load gate passes.', e);
            return null;
        }
    }

    @AuraEnabled
    public static Id createGatePass(GatePassRequest req) {
        try {
            KenAuraExceptionHelper.rejectIf(req == null, 'Request is empty.');
            KenAuraExceptionHelper.rejectIf(String.isBlank(req.reason),      'Reason is required.');
            KenAuraExceptionHelper.rejectIf(String.isBlank(req.destination), 'Destination is required.');
            KenAuraExceptionHelper.rejectIf(String.isBlank(req.outDateTime), 'Out date/time is required.');

            Datetime outDt = null, retDt = null;
            try {
                if (String.isNotBlank(req.outDateTime))    outDt = Datetime.valueOf(req.outDateTime);
                if (String.isNotBlank(req.returnDateTime)) retDt = Datetime.valueOf(req.returnDateTime);
            } catch (Exception parseEx) {
                throw new AuraHandledException('Date format is invalid (expected yyyy-MM-dd HH:mm:ss).');
            }
            // Validate exit isn't far in the past and return is after exit.
            if (outDt != null && outDt < Datetime.now().addHours(-1)) {
                throw new AuraHandledException('Exit date/time cannot be in the past.');
            }
            if (outDt != null && retDt != null && retDt <= outDt) {
                throw new AuraHandledException('Return date/time must be after the exit date/time.');
            }

            Id studentId = KenRunningStudentHelper.optionalContactId();
            // Idempotency: skip if a Pending pass with same Out time + reason already exists.
            if (studentId != null && outDt != null) {
                List<Gate_Pass__c> dupes = [
                    SELECT Id FROM Gate_Pass__c
                    WHERE Student__c = :studentId
                      AND Out_Date_Time__c = :outDt
                      AND Reason__c = :req.reason
                      AND Status__c IN ('Pending', 'Approved')
                    WITH SECURITY_ENFORCED LIMIT 1
                ];
                if (!dupes.isEmpty()) return dupes[0].Id;
            }
            KenCrudFlsHelper.assertCreateable(Gate_Pass__c.SObjectType);
            Gate_Pass__c rec = new Gate_Pass__c(
                Student__c       = studentId,
                Reason__c        = req.reason == null ? null : req.reason.left(255),
                Destination__c   = req.destination == null ? null : req.destination.left(255),
                Status__c        = 'Pending'
            );
            if (outDt != null) rec.Out_Date_Time__c    = outDt;
            if (retDt != null) rec.Return_Date_Time__c = retDt;
            insert rec;
            return rec.Id;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenGatePassController.createGatePass',
                'Could not submit your gate pass.', e);
            return null;
        }
    }

}