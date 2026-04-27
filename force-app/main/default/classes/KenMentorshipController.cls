/**
 * ************************************************************************************************
 * @className  KenMentorshipController
 *
 * @description
 *  Backs the `my/mentorship` LWC page — persistence for mentorship tasks. The
 *  mentor catalog and session list are still rendered from c:mockData; only
 *  the per-student task list is real.
 * ************************************************************************************************
 */
public with sharing class KenMentorshipController {

    public class TaskDTO {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  title;
        @AuraEnabled public String  description;
        @AuraEnabled public String  mentor;
        @AuraEnabled public String  status;
        @AuraEnabled public Date    dueDate;
    }

    @AuraEnabled(cacheable=false)
    public static List<TaskDTO> getTasks() {
        try {
            List<TaskDTO> out = new List<TaskDTO>();
            Id studentId = KenRunningStudentHelper.optionalContactId();
            if (studentId == null) return out;
            for (Mentorship_Task__c t : [
                SELECT Id, Title__c, Description__c, Mentor_Name__c, Status__c, Due_Date__c
                FROM Mentorship_Task__c
                WHERE Student__c = :studentId
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 50
            ]) out.add(toDto(t));
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenMentorshipController.getTasks',
                'Unable to load mentorship tasks.', e);
            return new List<TaskDTO>();
        }
    }

    @AuraEnabled
    public static TaskDTO addTask(String title, String description, String mentorName, Date dueDate) {
        try {
            KenAuraExceptionHelper.rejectIf(String.isBlank(title), 'Task title is required.');
            KenAuraExceptionHelper.rejectIf(title.length() > 200, 'Task title is too long (max 200).');
            Id studentId = KenRunningStudentHelper.optionalContactId();
            // Idempotency: identical title submitted in the last minute is a dupe.
            if (studentId != null) {
                Datetime cutoff = Datetime.now().addMinutes(-1);
                List<Mentorship_Task__c> dupes = [
                    SELECT Id FROM Mentorship_Task__c
                    WHERE Student__c = :studentId AND Title__c = :title
                      AND CreatedDate >= :cutoff
                    WITH USER_MODE LIMIT 1
                ];
                if (!dupes.isEmpty()) {
                    return toDto([
                        SELECT Id, Title__c, Description__c, Mentor_Name__c, Status__c, Due_Date__c
                        FROM Mentorship_Task__c WHERE Id = :dupes[0].Id LIMIT 1
                    ]);
                }
            }
            KenCrudFlsHelper.assertCreateable(Mentorship_Task__c.SObjectType);
            Mentorship_Task__c t = new Mentorship_Task__c(
                Student__c     = studentId,
                Title__c       = title,
                Description__c = description == null ? null : description.left(1000),
                Mentor_Name__c = mentorName == null ? null : mentorName.left(120),
                Due_Date__c    = dueDate,
                Status__c      = 'Pending'
            );
            insert t;
            return toDto([
                SELECT Id, Title__c, Description__c, Mentor_Name__c, Status__c, Due_Date__c
                FROM Mentorship_Task__c WHERE Id = :t.Id LIMIT 1
            ]);
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenMentorshipController.addTask',
                'Could not add the task.', e);
            return null;
        }
    }

    private static TaskDTO toDto(Mentorship_Task__c t) {
        TaskDTO d = new TaskDTO();
        d.id          = t.Id;
        d.title       = t.Title__c;
        d.description = t.Description__c;
        d.mentor      = t.Mentor_Name__c;
        d.status      = t.Status__c;
        d.dueDate     = t.Due_Date__c;
        return d;
    }
}