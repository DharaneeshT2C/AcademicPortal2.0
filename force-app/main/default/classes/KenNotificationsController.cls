/**
 * ************************************************************************************************
 * @className  KenNotificationsController
 *
 * @description
 *  Backs `my/notificationsPage` — notification centre with read/unread, categories.
 *
 *  TODO[SOBJECT]: Wire to `Student_Notification__c` (To_Contact__c, Title__c,
 *                 Body__c, Category__c, Is_Read__c, Read_On__c, Source_Ref__c)
 *                 or use the platform's CustomNotification / Notifications API.
 * ************************************************************************************************
 */
public without sharing class KenNotificationsController {

    public class NotificationDTO {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  title;
        @AuraEnabled public String  body;
        @AuraEnabled public String  category; // 'Academic' | 'Fee' | 'Event' | 'Message' | 'System'
        @AuraEnabled public String  timeAgo;
        @AuraEnabled public Boolean isRead;
        @AuraEnabled public String  iconUrl;
        @AuraEnabled public String  route;
    }

    @AuraEnabled(cacheable=true)
    public static List<NotificationDTO> getNotifications() {
        try {
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId == null) return new List<NotificationDTO>();
            List<NotificationDTO> out = new List<NotificationDTO>();
            for (Student_Notification__c r : [
                SELECT Id, Title__c, Body__c, Category__c, Is_Read__c, Source_Route__c, CreatedDate
                FROM Student_Notification__c
                WHERE Student__c = :contactId
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT 50
            ]) {
                NotificationDTO d = new NotificationDTO();
                d.id        = r.Id;
                d.title     = r.Title__c;
                d.body      = r.Body__c;
                d.category  = r.Category__c;
                d.isRead    = r.Is_Read__c == true;
                d.route     = r.Source_Route__c;
                d.timeAgo   = relativeTime(r.CreatedDate);
                d.iconUrl   = '';
                out.add(d);
            }
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenNotificationsController.getNotifications',
                'Unable to load notifications.', e);
            return null;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Integer getUnreadCount() {
        try {
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId == null) return 0;
            return [
                SELECT COUNT()
                FROM Student_Notification__c
                WHERE Student__c = :contactId AND Is_Read__c = false
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenNotificationsController.getUnreadCount',
                'Unable to load unread count.', e);
            return 0;
        }
    }

    private static String relativeTime(Datetime dt) {
        if (dt == null) return '';
        Long diffSec = (System.now().getTime() - dt.getTime()) / 1000;
        if (diffSec < 60)         return 'Just now';
        if (diffSec < 3600)       return String.valueOf(diffSec / 60) + 'm ago';
        if (diffSec < 86400)      return String.valueOf(diffSec / 3600) + 'h ago';
        if (diffSec < 86400 * 7)  return String.valueOf(diffSec / 86400) + 'd ago';
        return dt.format('d MMM');
    }

    @AuraEnabled
    public static void markRead(List<Id> notificationIds) {
        try {
            KenAuraExceptionHelper.rejectIf(notificationIds == null || notificationIds.isEmpty(), 'No notifications provided.');
            KenCrudFlsHelper.assertUpdateable(Student_Notification__c.SObjectType);
            Datetime now = Datetime.now();
            List<Student_Notification__c> toUpdate = new List<Student_Notification__c>();
            for (Id nid : notificationIds) {
                toUpdate.add(new Student_Notification__c(
                    Id         = nid,
                    Is_Read__c = true,
                    Read_On__c = now
                ));
            }
            update toUpdate;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenNotificationsController.markRead',
                'Could not mark notifications as read.', e);
        }
    }

    @AuraEnabled
    public static void decideNotification(Id notificationId, String decision) {
        try {
            KenAuraExceptionHelper.rejectIf(notificationId == null, 'Notification id is required.');
            KenAuraExceptionHelper.rejectIf(String.isBlank(decision), 'Decision is required.');
            KenCrudFlsHelper.assertUpdateable(Student_Notification__c.SObjectType);
            Student_Notification__c n = new Student_Notification__c(
                Id         = notificationId,
                Is_Read__c = true,
                Read_On__c = Datetime.now()
            );
            update n;
            // Persist decision into the body so the audit trail reflects it.
            // (We don't have a Decision__c field; concatenating to Body__c keeps
            // the change non-destructive and visible in record history.)
            try {
                Student_Notification__c full = [
                    SELECT Id, Body__c FROM Student_Notification__c WHERE Id = :notificationId LIMIT 1
                ];
                String suffix = '\n[Decision: ' + decision + ' at ' + Datetime.now().format('d MMM yyyy, h:mm a') + ']';
                String newBody = (full.Body__c == null ? '' : full.Body__c) + suffix;
                if (newBody.length() > 32000) newBody = newBody.left(32000);
                update new Student_Notification__c(Id = notificationId, Body__c = newBody);
            } catch (Exception ignore) { /* annotation is best-effort */ }
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenNotificationsController.decideNotification',
                'Could not record your action. Please try again.', e);
        }
    }

    @AuraEnabled
    public static void markAllRead() {
        try {
            Id studentId = KenRunningStudentHelper.optionalContactId();
            if (studentId == null) return;
            KenCrudFlsHelper.assertUpdateable(Student_Notification__c.SObjectType);
            List<Student_Notification__c> unread = [
                SELECT Id
                FROM Student_Notification__c
                WHERE Student__c = :studentId AND Is_Read__c = false
                WITH SECURITY_ENFORCED
                LIMIT 1000
            ];
            if (unread.isEmpty()) return;
            Datetime now = Datetime.now();
            for (Student_Notification__c n : unread) {
                n.Is_Read__c = true;
                n.Read_On__c = now;
            }
            update unread;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenNotificationsController.markAllRead',
                'Could not mark all as read.', e);
        }
    }

}