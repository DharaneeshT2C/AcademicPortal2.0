/**
 * ************************************************************************************************
 * @className  KenServiceSupportController
 *
 * @description
 *  Backs `my/serviceSupport` — raise tickets, list existing tickets, surface FAQ
 *  previews. Uses standard `Case` under the hood once schema is ready.
 *
 *  TODO[SOBJECT]: Use standard `Case` with custom category picklist, or
 *                 `Service_Request__c` if organisation prefers dedicated object.
 * ************************************************************************************************
 */
public with sharing class KenServiceSupportController {

    public class TicketDTO {
        @AuraEnabled public Id     id;
        @AuraEnabled public String requestId;
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public String category;
        @AuraEnabled public String status;     // 'New' | 'In Review' | 'Closed'
        @AuraEnabled public String raisedOn;
        @AuraEnabled public String closedOn;
        @AuraEnabled public String attachmentName;
    }

    public class TicketRequest {
        @AuraEnabled public String category;
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public String attachmentName;
        @AuraEnabled public String attachmentBase64;
    }

    @AuraEnabled(cacheable=true)
    public static List<TicketDTO> getTickets() {
        try {
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId == null) return seedTickets();
            List<TicketDTO> out = new List<TicketDTO>();
            for (Case c : [
                SELECT Id, CaseNumber, Subject, Description, Type, Status, CreatedDate, ClosedDate
                FROM Case
                WHERE ContactId = :contactId
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 50
            ]) {
                TicketDTO t = new TicketDTO();
                t.id        = c.Id;
                t.requestId = '#' + c.CaseNumber;
                t.title     = c.Subject;
                t.subtitle  = c.Description == null ? '' : (c.Description.length() > 60 ? c.Description.left(60) + '…' : c.Description);
                t.category  = c.Type != null ? c.Type : 'General';
                t.status    = (c.Status != null && c.Status.toLowerCase().contains('closed')) ? 'Closed'
                              : (c.Status != null && c.Status.toLowerCase().contains('progress')) ? 'In Review'
                              : 'New';
                t.raisedOn  = c.CreatedDate == null ? '' : c.CreatedDate.format('d-MMM-yyyy');
                t.closedOn  = c.ClosedDate == null ? null : c.ClosedDate.format('d-MMM-yyyy');
                t.attachmentName = null;
                out.add(t);
            }
            if (out.isEmpty()) return seedTickets();
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenServiceSupportController.getTickets',
                'Unable to load tickets.', e);
            return null;
        }
    }

    @AuraEnabled
    public static Id raiseTicket(TicketRequest req) {
        try {
            KenAuraExceptionHelper.rejectIf(req == null, 'Request is empty.');
            KenAuraExceptionHelper.rejectIf(String.isBlank(req.category),    'Category is required.');
            KenAuraExceptionHelper.rejectIf(String.isBlank(req.title),       'Title is required.');
            KenAuraExceptionHelper.rejectIf(String.isBlank(req.description), 'Description is required.');
            Id contactId = KenRunningStudentHelper.optionalContactId();
            // Idempotency: skip if an identical open Case from the last 5 min exists.
            if (contactId != null) {
                Datetime cutoff = Datetime.now().addMinutes(-5);
                List<Case> dupes = [
                    SELECT Id FROM Case
                    WHERE ContactId = :contactId
                      AND Subject = :req.title
                      AND IsClosed = false
                      AND CreatedDate >= :cutoff
                    LIMIT 1
                ];
                if (!dupes.isEmpty()) return dupes[0].Id;
            }
            Case c = new Case(
                ContactId   = contactId,
                Subject     = req.title,
                Description = req.description,
                Type        = req.category,
                Status      = 'New',
                Origin      = 'Web'
            );
            insert c;
            // Optional: attach uploaded file as ContentVersion linked to the case
            if (String.isNotBlank(req.attachmentBase64) && String.isNotBlank(req.attachmentName)) {
                ContentVersion cv = new ContentVersion(
                    Title          = req.attachmentName,
                    PathOnClient   = req.attachmentName,
                    VersionData    = EncodingUtil.base64Decode(req.attachmentBase64),
                    FirstPublishLocationId = c.Id
                );
                insert cv;
            }
            return c.Id;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenServiceSupportController.raiseTicket',
                'Could not raise ticket.', e);
            return null;
        }
    }

    private static List<TicketDTO> seedTickets() {
        List<TicketDTO> out = new List<TicketDTO>();
        out.add(ticket(null, '#20240101', 'Career Services', 'Resume/CV Review',            'Career',  'Closed',    '20-Dec-2023', '23-Dec-2023', 'Resume.pdf'));
        out.add(ticket(null, '#20240101', 'Career Services', 'Internship assistance',        'Career',  'In Review', '05-Jan-2024', null,          null));
        out.add(ticket(null, '#20240110', 'IT',              'Wi-Fi not working in Block B', 'IT',      'New',       '14-Apr-2026', null,          null));
        return out;
    }

    private static TicketDTO ticket(Id id, String req, String title, String sub, String cat, String status, String raised, String closed, String attach) {
        TicketDTO t = new TicketDTO();
        t.id = id; t.requestId = req; t.title = title; t.subtitle = sub; t.category = cat;
        t.status = status; t.raisedOn = raised; t.closedOn = closed; t.attachmentName = attach;
        return t;
    }
}