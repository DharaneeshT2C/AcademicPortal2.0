/**
 * ************************************************************************************************
 * @className  KenPlacementsController
 *
 * @description
 *  Backs the placements / careers module: job listings, applications, saved jobs,
 *  offers, and downloadable offer letters. Schema:
 *    • Job_Posting__c     — admin-created job listings (read for students)
 *    • Job_Application__c — per-student application or saved bookmark
 *
 * @author      Student Portal Backend
 * @createdOn   2026
 * ************************************************************************************************
 */
public with sharing class KenPlacementsController {

    public class JobDTO {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  company;
        @AuraEnabled public String  title;
        @AuraEnabled public String  description;
        @AuraEnabled public String  category;
        @AuraEnabled public Decimal salaryMin;
        @AuraEnabled public Decimal salaryMax;
        @AuraEnabled public String  currencyCode;
        @AuraEnabled public List<String> tags;
        @AuraEnabled public Boolean isSaved;
        @AuraEnabled public Boolean hasApplied;
        @AuraEnabled public String  applicationStatus;
    }

    public class ApplicationDTO {
        @AuraEnabled public Id      id;
        @AuraEnabled public Id      jobId;
        @AuraEnabled public String  company;
        @AuraEnabled public String  title;
        @AuraEnabled public String  category;
        @AuraEnabled public String  status;
        @AuraEnabled public String  currentPhase;
        @AuraEnabled public Date    appliedDate;
        @AuraEnabled public Decimal offerSalary;
        @AuraEnabled public Datetime interviewSlot;
    }

    /** Returns all active job postings, decorated with this student's saved/applied state. */
    @AuraEnabled(cacheable=true)
    public static List<JobDTO> getJobs() {
        try {
            Id studentId = KenRunningStudentHelper.optionalContactId();
            // Map jobId → "saved" or "applied/etc" so DTOs reflect status.
            Map<Id, String> myStatus = new Map<Id, String>();
            if (studentId != null) {
                for (Job_Application__c a : [
                    SELECT Id, Job__c, Status__c FROM Job_Application__c
                    WHERE Student__c = :studentId
                    WITH USER_MODE
                    LIMIT 500
                ]) {
                    myStatus.put(a.Job__c, a.Status__c);
                }
            }
            List<JobDTO> out = new List<JobDTO>();
            for (Job_Posting__c j : [
                SELECT Id, Name, Company__c, Title__c, Description__c, Category__c,
                       Salary_Min__c, Salary_Max__c, Currency__c, Tags__c
                FROM Job_Posting__c
                WHERE Is_Active__c = true
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 200
            ]) {
                JobDTO d = new JobDTO();
                d.id = j.Id;
                d.company = j.Company__c;
                d.title   = j.Title__c == null ? j.Name : j.Title__c;
                d.description = j.Description__c;
                d.category = j.Category__c;
                d.salaryMin = j.Salary_Min__c;
                d.salaryMax = j.Salary_Max__c;
                d.currencyCode = j.Currency__c == null ? 'INR' : j.Currency__c;
                d.tags = String.isBlank(j.Tags__c) ? new List<String>() : j.Tags__c.split(',\\s*');
                String s = myStatus.get(j.Id);
                d.isSaved   = s == 'Saved';
                d.hasApplied = s != null && s != 'Saved' && s != 'Withdrawn';
                d.applicationStatus = s;
                out.add(d);
            }
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenPlacementsController.getJobs',
                'Unable to load jobs.', e);
            return null;
        }
    }

    /** Returns the student's active applications (excludes Saved + Withdrawn). */
    @AuraEnabled(cacheable=true)
    public static List<ApplicationDTO> getApplications() {
        try {
            List<ApplicationDTO> out = new List<ApplicationDTO>();
            Id studentId = KenRunningStudentHelper.optionalContactId();
            if (studentId == null) return out;
            for (Job_Application__c a : [
                SELECT Id, Job__c, Status__c, Applied_Date__c, Current_Phase__c, Offer_Salary__c, Interview_Slot__c,
                       Job__r.Company__c, Job__r.Title__c, Job__r.Category__c
                FROM Job_Application__c
                WHERE Student__c = :studentId AND Status__c != 'Saved'
                WITH USER_MODE
                ORDER BY Applied_Date__c DESC
                LIMIT 200
            ]) out.add(toDto(a));
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenPlacementsController.getApplications',
                'Unable to load applications.', e);
            return null;
        }
    }

    @AuraEnabled
    public static Id applyToJob(Id jobId, String resumeName) {
        try {
            KenAuraExceptionHelper.rejectIf(jobId == null, 'Job id is required.');
            Id studentId = KenRunningStudentHelper.optionalContactId();
            if (studentId == null) return null;
            // Idempotency: if active (non-Saved/Withdrawn) application exists, return it.
            List<Job_Application__c> existing = [
                SELECT Id FROM Job_Application__c
                WHERE Job__c = :jobId AND Student__c = :studentId
                  AND Status__c NOT IN ('Saved', 'Withdrawn', 'Rejected')
                WITH USER_MODE LIMIT 1
            ];
            if (!existing.isEmpty()) return existing[0].Id;
            // If a Saved record exists, promote it to Applied.
            List<Job_Application__c> saved = [
                SELECT Id FROM Job_Application__c
                WHERE Job__c = :jobId AND Student__c = :studentId AND Status__c = 'Saved'
                WITH USER_MODE LIMIT 1
            ];
            if (!saved.isEmpty()) {
                Job_Application__c upd = new Job_Application__c(
                    Id = saved[0].Id,
                    Status__c = 'Applied',
                    Applied_Date__c = Date.today(),
                    Resume_Used__c = resumeName,
                    Current_Phase__c = 'Application Review'
                );
                update upd;
                return upd.Id;
            }
            KenCrudFlsHelper.assertCreateable(Job_Application__c.SObjectType);
            Job_Application__c a = new Job_Application__c(
                Student__c = studentId,
                Job__c = jobId,
                Status__c = 'Applied',
                Applied_Date__c = Date.today(),
                Resume_Used__c = resumeName,
                Current_Phase__c = 'Application Review'
            );
            insert a;
            // Notify the student.
            if (Schema.SObjectType.Student_Notification__c.isCreateable()) {
                List<Job_Posting__c> jp = [SELECT Title__c, Company__c FROM Job_Posting__c WHERE Id = :jobId LIMIT 1];
                String label = jp.isEmpty() ? 'a job' : (jp[0].Title__c + ' @ ' + jp[0].Company__c);
                insert new Student_Notification__c(
                    Student__c = studentId,
                    Title__c = 'Application submitted',
                    Body__c  = 'You applied to ' + label + '. Track status under Placements.',
                    Category__c = 'System',
                    Source_Route__c = 'placements',
                    Is_Read__c = false
                );
            }
            return a.Id;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenPlacementsController.applyToJob',
                'Could not submit your application.', e);
            return null;
        }
    }

    @AuraEnabled
    public static void withdrawApplication(Id applicationId) {
        try {
            KenAuraExceptionHelper.rejectIf(applicationId == null, 'Application id is required.');
            KenCrudFlsHelper.assertUpdateable(Job_Application__c.SObjectType);
            update new Job_Application__c(Id = applicationId, Status__c = 'Withdrawn');
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenPlacementsController.withdrawApplication',
                'Could not withdraw application.', e);
        }
    }

    /** Toggle save: returns the new isSaved state (true after save, false after unsave). */
    @AuraEnabled
    public static Boolean toggleSaveJob(Id jobId) {
        try {
            KenAuraExceptionHelper.rejectIf(jobId == null, 'Job id is required.');
            Id studentId = KenRunningStudentHelper.optionalContactId();
            if (studentId == null) return false;
            List<Job_Application__c> existing = [
                SELECT Id, Status__c FROM Job_Application__c
                WHERE Job__c = :jobId AND Student__c = :studentId
                WITH USER_MODE LIMIT 1
            ];
            if (!existing.isEmpty()) {
                Job_Application__c row = existing[0];
                if (row.Status__c == 'Saved') {
                    KenCrudFlsHelper.assertDeletable(Job_Application__c.SObjectType);
                    delete row;
                    return false;
                }
                // Already a real application — saving on top is a no-op.
                return false;
            }
            KenCrudFlsHelper.assertCreateable(Job_Application__c.SObjectType);
            insert new Job_Application__c(
                Student__c = studentId,
                Job__c = jobId,
                Status__c = 'Saved'
            );
            return true;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenPlacementsController.toggleSaveJob',
                'Could not save job.', e);
            return false;
        }
    }

    @AuraEnabled
    public static void bookInterviewSlot(Id applicationId, Datetime slot) {
        try {
            KenAuraExceptionHelper.rejectIf(applicationId == null, 'Application id is required.');
            KenAuraExceptionHelper.rejectIf(slot == null, 'Slot is required.');
            KenCrudFlsHelper.assertUpdateable(Job_Application__c.SObjectType);
            update new Job_Application__c(
                Id = applicationId,
                Interview_Slot__c = slot,
                Status__c = 'Scheduled',
                Current_Phase__c = 'Interview Scheduled'
            );
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenPlacementsController.bookInterviewSlot',
                'Could not book interview slot.', e);
        }
    }

    /**
     * Returns a downloadable offer-letter blob for the application. We don't have
     * a real document repository wired — this returns a structured text string
     * the LWC can save to disk via Blob URL. Replace with a ContentVersion fetch
     * once the placements team starts uploading real PDFs.
     */
    @AuraEnabled(cacheable=true)
    public static String getOfferLetterText(Id applicationId) {
        try {
            KenAuraExceptionHelper.rejectIf(applicationId == null, 'Application id is required.');
            List<Job_Application__c> rows = [
                SELECT Id, Status__c, Offer_Salary__c, Applied_Date__c,
                       Job__r.Company__c, Job__r.Title__c, Job__r.Currency__c,
                       Student__r.FirstName, Student__r.LastName
                FROM Job_Application__c
                WHERE Id = :applicationId
                WITH USER_MODE LIMIT 1
            ];
            if (rows.isEmpty()) return null;
            Job_Application__c a = rows[0];
            String name = (a.Student__r != null) ?
                String.valueOf(a.Student__r.FirstName) + ' ' + String.valueOf(a.Student__r.LastName) : 'Candidate';
            String company = a.Job__r != null ? a.Job__r.Company__c : '';
            String title   = a.Job__r != null ? a.Job__r.Title__c   : '';
            String curCode = a.Job__r != null && a.Job__r.Currency__c != null ? a.Job__r.Currency__c : 'INR';
            String[] lines = new String[]{
                'OFFER LETTER',
                '',
                'Date: ' + Date.today().format(),
                'Candidate: ' + name,
                'Company: ' + company,
                'Position: ' + title,
                'Annual CTC: ' + curCode + ' ' + (a.Offer_Salary__c == null ? 'TBD' : String.valueOf(a.Offer_Salary__c)),
                '',
                'Dear ' + name + ',',
                '',
                'We are pleased to extend an offer for the position of ' + title +
                ' at ' + company + '. Please review the details and respond ' +
                'within 7 days.',
                '',
                'This is a placeholder letter generated by the Student Portal. ' +
                'A signed copy will be shared by the placements office.',
                '',
                'Warm regards,',
                'Placements Office'
            };
            return String.join(lines, '\n');
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenPlacementsController.getOfferLetterText',
                'Could not load offer letter.', e);
            return null;
        }
    }

    @AuraEnabled
    public static Id raiseJobQuery(Id jobId, String queryText) {
        try {
            KenAuraExceptionHelper.rejectIf(jobId == null, 'Job id is required.');
            KenAuraExceptionHelper.rejectIf(String.isBlank(queryText), 'Please describe your query.');
            Id contactId = KenRunningStudentHelper.optionalContactId();
            List<Job_Posting__c> jp = [SELECT Title__c, Company__c FROM Job_Posting__c WHERE Id = :jobId LIMIT 1];
            String subject = jp.isEmpty() ? 'Job query' :
                ('Job query: ' + jp[0].Title__c + ' @ ' + jp[0].Company__c);
            Case c = new Case(
                ContactId   = contactId,
                Subject     = subject.left(255),
                Description = queryText.left(32000),
                Status      = 'New',
                Origin      = 'Web'
            );
            insert c;
            return c.Id;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenPlacementsController.raiseJobQuery',
                'Could not submit your query.', e);
            return null;
        }
    }

    private static ApplicationDTO toDto(Job_Application__c a) {
        ApplicationDTO d = new ApplicationDTO();
        d.id = a.Id;
        d.jobId = a.Job__c;
        d.status = a.Status__c;
        d.currentPhase = a.Current_Phase__c;
        d.appliedDate = a.Applied_Date__c;
        d.offerSalary = a.Offer_Salary__c;
        d.interviewSlot = a.Interview_Slot__c;
        if (a.Job__r != null) {
            d.company = a.Job__r.Company__c;
            d.title   = a.Job__r.Title__c;
            d.category = a.Job__r.Category__c;
        }
        return d;
    }
}