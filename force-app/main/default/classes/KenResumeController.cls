/**
 * ************************************************************************************************
 * @className  KenResumeController
 *
 * @description
 *  Backs the Resume Library + Resume Editor LWCs. Resume body is stored as JSON
 *  in `Resume__c.Body__c` (long text 32k) — the LWC serializes its formData on
 *  save and deserializes on load.
 * ************************************************************************************************
 */
public with sharing class KenResumeController {

    public class ResumeDTO {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  body;
        @AuraEnabled public Date    lastUsedDate;
        @AuraEnabled public Boolean isDefault;
    }

    @AuraEnabled(cacheable=true)
    public static List<ResumeDTO> getResumes() {
        try {
            List<ResumeDTO> out = new List<ResumeDTO>();
            Id studentId = KenRunningStudentHelper.optionalContactId();
            if (studentId == null) return out;
            for (Resume__c r : [
                SELECT Id, Name, Body__c, Last_Used_Date__c, Is_Default__c
                FROM Resume__c
                WHERE Student__c = :studentId
                WITH USER_MODE
                ORDER BY Last_Used_Date__c DESC NULLS LAST, CreatedDate DESC
                LIMIT 50
            ]) out.add(toDto(r));
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenResumeController.getResumes',
                'Unable to load resumes.', e);
            return null;
        }
    }

    @AuraEnabled
    public static Id createResume(String name, String body) {
        try {
            KenAuraExceptionHelper.rejectIf(String.isBlank(name), 'Resume name is required.');
            Id studentId = KenRunningStudentHelper.optionalContactId();
            KenCrudFlsHelper.assertCreateable(Resume__c.SObjectType);
            String safeBody = body == null ? '' : (body.length() > 32000 ? body.left(32000) : body);
            Resume__c r = new Resume__c(
                Name              = name.left(80),
                Student__c        = studentId,
                Body__c           = safeBody,
                Last_Used_Date__c = Date.today(),
                Is_Default__c     = false
            );
            insert r;
            return r.Id;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenResumeController.createResume',
                'Could not save your resume.', e);
            return null;
        }
    }

    @AuraEnabled
    public static void updateResume(Id resumeId, String name, String body) {
        try {
            KenAuraExceptionHelper.rejectIf(resumeId == null, 'Resume id is required.');
            KenCrudFlsHelper.assertUpdateable(Resume__c.SObjectType);
            String safeBody = body == null ? '' : (body.length() > 32000 ? body.left(32000) : body);
            update new Resume__c(
                Id                = resumeId,
                Name              = String.isBlank(name) ? 'Untitled' : name.left(80),
                Body__c           = safeBody,
                Last_Used_Date__c = Date.today()
            );
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenResumeController.updateResume',
                'Could not update your resume.', e);
        }
    }

    @AuraEnabled
    public static void deleteResume(Id resumeId) {
        try {
            KenAuraExceptionHelper.rejectIf(resumeId == null, 'Resume id is required.');
            KenCrudFlsHelper.assertDeletable(Resume__c.SObjectType);
            delete new Resume__c(Id = resumeId);
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenResumeController.deleteResume',
                'Could not delete the resume.', e);
        }
    }

    @AuraEnabled
    public static void setDefaultResume(Id resumeId) {
        try {
            KenAuraExceptionHelper.rejectIf(resumeId == null, 'Resume id is required.');
            Id studentId = KenRunningStudentHelper.optionalContactId();
            if (studentId == null) return;
            // Clear any existing default, set the new one.
            List<Resume__c> defaults = [
                SELECT Id FROM Resume__c
                WHERE Student__c = :studentId AND Is_Default__c = true
                WITH USER_MODE
            ];
            List<Resume__c> updates = new List<Resume__c>();
            for (Resume__c d : defaults) {
                if (d.Id != resumeId) updates.add(new Resume__c(Id = d.Id, Is_Default__c = false));
            }
            updates.add(new Resume__c(Id = resumeId, Is_Default__c = true));
            KenCrudFlsHelper.assertUpdateable(Resume__c.SObjectType);
            update updates;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenResumeController.setDefaultResume',
                'Could not set as default.', e);
        }
    }

    private static ResumeDTO toDto(Resume__c r) {
        ResumeDTO d = new ResumeDTO();
        d.id = r.Id;
        d.name = r.Name;
        d.body = r.Body__c;
        d.lastUsedDate = r.Last_Used_Date__c;
        d.isDefault = r.Is_Default__c;
        return d;
    }
}