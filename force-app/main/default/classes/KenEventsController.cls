/**
 * ************************************************************************************************
 * @className  KenEventsController
 *
 * @description
 *  Backs the `my/events` LWC page. Tabs: Featured | Upcoming | Registered.
 *  Handles RSVP / registration.
 *
 *  TODO[SOBJECT]: Wire to `Event__c` + `Event_Registration__c`. Could also use
 *                 the standard `Event` SObject with campus extensions.
 * ************************************************************************************************
 */
public without sharing class KenEventsController {

    public class EventDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  title;
        @AuraEnabled public String  type;
        @AuraEnabled public String  mode;        // 'Online' | 'Offline' | 'Hybrid'
        @AuraEnabled public String  eventDate;
        @AuraEnabled public String  eventTime;
        @AuraEnabled public String  dateLabel;   // Same as eventDate; new field for clarity
        @AuraEnabled public String  timeLabel;   // Same as eventTime
        @AuraEnabled public String  location;
        @AuraEnabled public String  imageUrl;
        @AuraEnabled public Boolean isRegistered;
        @AuraEnabled public String  description;
    }

    public class EventsBundleDTO {
        @AuraEnabled public List<EventDTO> featured;
        @AuraEnabled public List<EventDTO> upcoming;
        @AuraEnabled public List<EventDTO> registered;
    }

    @AuraEnabled(cacheable=true)
    public static EventsBundleDTO getEventsBundle() {
        try {
            EventsBundleDTO b = new EventsBundleDTO();
            b.featured   = new List<EventDTO>();
            b.upcoming   = new List<EventDTO>();
            b.registered = new List<EventDTO>();
            // Campus_Event__c is a global catalog object (no per-student sharing).
            // Use SYSTEM_MODE so community users can read all upcoming events.
            List<Campus_Event__c> rows = [
                SELECT Id, Name, Title__c, Description__c, Event_Date__c, Event_Time__c,
                       Location__c, Mode__c, Type__c, Is_Featured__c, Image_Url__c
                FROM Campus_Event__c
                WITH SECURITY_ENFORCED
                ORDER BY Event_Date__c
                LIMIT 100
            ];
            // Track which events the running student has registered for
            Set<Id> regIds = new Set<Id>();
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId != null) {
                for (Event_Registration__c er : [
                    SELECT Event__c FROM Event_Registration__c
                    WHERE Student__c = :contactId AND Status__c = 'Registered'
                    WITH SECURITY_ENFORCED
                ]) regIds.add(er.Event__c);
            }
            for (Campus_Event__c r : rows) {
                EventDTO d = new EventDTO();
                d.id           = r.Id;
                d.title        = (r.Title__c != null) ? r.Title__c : r.Name;
                d.type         = r.Type__c;
                d.mode         = r.Mode__c;
                d.eventDate    = r.Event_Date__c == null ? '' :
                    Datetime.newInstance(r.Event_Date__c, Time.newInstance(0,0,0,0)).format('d MMM yyyy');
                d.eventTime    = r.Event_Time__c;
                d.dateLabel    = d.eventDate;
                d.timeLabel    = d.eventTime;
                d.location     = r.Location__c;
                d.imageUrl     = r.Image_Url__c;
                d.isRegistered = regIds.contains(r.Id);
                d.description  = r.Description__c;
                if (r.Is_Featured__c == true) b.featured.add(d);
                else                          b.upcoming.add(d);
                if (regIds.contains(r.Id))    b.registered.add(d);
            }
            return b;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenEventsController.getEventsBundle',
                'Unable to load events.', e);
            return null;
        }
    }

    @AuraEnabled
    public static void registerForEvent(Id eventId) {
        try {
            KenAuraExceptionHelper.rejectIf(eventId == null, 'Event id is required.');
            Id studentId = KenRunningStudentHelper.optionalContactId();
            if (studentId == null) return;
            // Idempotency: if a non-cancelled registration exists, no-op.
            List<Event_Registration__c> existing = [
                SELECT Id, Status__c FROM Event_Registration__c
                WHERE Event__c = :eventId AND Student__c = :studentId AND Status__c != 'Cancelled'
                WITH SECURITY_ENFORCED LIMIT 1
            ];
            if (!existing.isEmpty()) return;
            KenCrudFlsHelper.assertCreateable(Event_Registration__c.SObjectType);
            insert new Event_Registration__c(
                Event__c   = eventId,
                Student__c = studentId,
                Status__c  = 'Registered'
            );
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenEventsController.registerForEvent',
                'Could not complete registration.', e);
        }
    }

    @AuraEnabled
    public static void cancelRegistration(Id registrationId) {
        try {
            KenAuraExceptionHelper.rejectIf(registrationId == null, 'Registration id is required.');
            KenCrudFlsHelper.assertUpdateable(Event_Registration__c.SObjectType);
            update new Event_Registration__c(
                Id        = registrationId,
                Status__c = 'Cancelled'
            );
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenEventsController.cancelRegistration',
                'Could not cancel registration.', e);
        }
    }

    @AuraEnabled
    public static Id submitHostedEvent(String title, String dateStr, String timeStr, String mode) {
        try {
            KenAuraExceptionHelper.rejectIf(String.isBlank(title), 'Title is required.');
            KenAuraExceptionHelper.rejectIf(String.isBlank(dateStr), 'Date is required.');
            KenCrudFlsHelper.assertCreateable(Campus_Event__c.SObjectType);
            // Map LWC's "On-campus" to the schema's "Offline" value (restricted picklist).
            String dbMode = mode;
            if (String.isBlank(dbMode) || dbMode == 'On-campus') dbMode = 'Offline';
            Campus_Event__c c = new Campus_Event__c(
                Title__c       = title,
                Type__c        = 'Student-hosted',
                Mode__c        = dbMode,
                Event_Time__c  = timeStr,
                Is_Featured__c = false
            );
            try { c.Event_Date__c = Date.valueOf(dateStr); } catch (Exception ignore) {}
            insert c;
            // Notify the running student that the submission landed.
            Id studentId = KenRunningStudentHelper.optionalContactId();
            if (studentId != null && Schema.SObjectType.Student_Notification__c.isCreateable()) {
                insert new Student_Notification__c(
                    Student__c  = studentId,
                    Title__c    = 'Event submitted for review',
                    Body__c     = '"' + title + '" is awaiting approval.',
                    Category__c = 'Event',
                    Is_Read__c  = false
                );
            }
            return c.Id;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenEventsController.submitHostedEvent',
                'Could not submit your event. Please try again.', e);
            return null;
        }
    }

}