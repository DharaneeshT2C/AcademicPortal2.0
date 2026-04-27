/**
 * ************************************************************************************************
 * @className  KenThesisManagementController
 *
 * @description
 *  Backs the `my/thesisManagement` LWC page — tracks stages (proposal → review →
 *  submission → defence), committee members, file uploads.
 *
 *  TODO[SOBJECT]: Wire to `Thesis__c`, `Thesis_Stage__c`, ContentVersion for file
 *                 uploads.
 * ************************************************************************************************
 */
public with sharing class KenThesisManagementController {

    public class ThesisStageDTO {
        @AuraEnabled public String  key;
        @AuraEnabled public String  label;
        @AuraEnabled public String  status; // 'done' | 'current' | 'pending'
        @AuraEnabled public String  dueDate;
        @AuraEnabled public String  completedOn;
    }

    public class CommitteeMemberDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String role;
        @AuraEnabled public String department;
    }

    public class ThesisDTO {
        @AuraEnabled public Id                       thesisId;
        @AuraEnabled public String                   title;
        @AuraEnabled public String                   abstractText;
        @AuraEnabled public String                   currentStage;
        @AuraEnabled public List<ThesisStageDTO>     stages;
        @AuraEnabled public List<CommitteeMemberDTO> committee;
    }

    @AuraEnabled(cacheable=true)
    public static ThesisDTO getThesis() {
        try {
            ThesisDTO t = new ThesisDTO();
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId == null) {
                t.title        = 'Efficient Graph Algorithms for Sparse Networks';
                t.abstractText = 'Investigating scalable approximation algorithms for pathfinding on sparse academic collaboration graphs.';
                t.currentStage = 'review';
                t.stages       = seedStages();
                t.committee    = seedCommittee();
                return t;
            }
            List<Thesis__c> rows = [
                SELECT Id, Title__c, Abstract__c, Current_Stage__c, Defence_Date__c,
                    (SELECT Id, Stage_Key__c, Label__c, Status__c, Due_Date__c, Completed_On__c
                     FROM Thesis_Stages__r ORDER BY Due_Date__c)
                FROM Thesis__c
                WHERE Student__c = :contactId
                WITH USER_MODE
                LIMIT 1
            ];
            if (rows.isEmpty()) {
                t.title        = 'Efficient Graph Algorithms for Sparse Networks';
                t.abstractText = 'Investigating scalable approximation algorithms for pathfinding on sparse academic collaboration graphs.';
                t.currentStage = 'review';
                t.stages       = seedStages();
                t.committee    = seedCommittee();
                return t;
            }
            Thesis__c r = rows[0];
            t.thesisId     = r.Id;
            t.title        = r.Title__c;
            t.abstractText = r.Abstract__c;
            t.currentStage = r.Current_Stage__c;
            t.stages       = new List<ThesisStageDTO>();
            try {
                for (Thesis_Stage__c s : r.Thesis_Stages__r) {
                    ThesisStageDTO d = new ThesisStageDTO();
                    d.key         = s.Stage_Key__c;
                    d.label       = s.Label__c;
                    d.status      = s.Status__c;
                    d.dueDate     = s.Due_Date__c == null ? '' : s.Due_Date__c.format();
                    d.completedOn = s.Completed_On__c == null ? null : s.Completed_On__c.format();
                    t.stages.add(d);
                }
            } catch (Exception ignored) { /* relationship may not be exposed */ }
            if (t.stages.isEmpty()) t.stages = seedStages();
            t.committee = seedCommittee(); // No committee object exists yet
            return t;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenThesisManagementController.getThesis',
                'Unable to load your thesis.', e);
            return null;
        }
    }

    @AuraEnabled
    public static Id addThesisTask(String title, Date dueDate) {
        try {
            KenAuraExceptionHelper.rejectIf(String.isBlank(title), 'Task title is required.');
            KenAuraExceptionHelper.rejectIf(title.length() > 200, 'Task title is too long (max 200).');
            Id contactId = KenRunningStudentHelper.optionalContactId();
            Id thesisId;
            if (contactId != null) {
                // Find existing thesis. Lazy-create only if absent — guarded by an
                // outer SELECT to mitigate race conditions on rapid double-tap.
                List<Thesis__c> existing = [
                    SELECT Id FROM Thesis__c
                    WHERE Student__c = :contactId WITH USER_MODE LIMIT 1
                ];
                if (!existing.isEmpty()) {
                    thesisId = existing[0].Id;
                } else if (Schema.SObjectType.Thesis__c.isCreateable()) {
                    try {
                        Thesis__c t = new Thesis__c(
                            Student__c     = contactId,
                            Title__c       = 'My Thesis',
                            Current_Stage__c = 'proposal'
                        );
                        insert t;
                        thesisId = t.Id;
                    } catch (DmlException dml) {
                        // Race: another concurrent insert won. Re-read.
                        List<Thesis__c> retry = [SELECT Id FROM Thesis__c WHERE Student__c = :contactId LIMIT 1];
                        if (!retry.isEmpty()) thesisId = retry[0].Id;
                        else throw dml;
                    }
                }
            }
            // Idempotency: identical title within last minute is a dupe.
            if (thesisId != null) {
                Datetime cutoff = Datetime.now().addMinutes(-1);
                List<Thesis_Stage__c> dupes = [
                    SELECT Id FROM Thesis_Stage__c
                    WHERE Thesis__c = :thesisId AND Label__c = :title
                      AND CreatedDate >= :cutoff
                    WITH USER_MODE LIMIT 1
                ];
                if (!dupes.isEmpty()) return dupes[0].Id;
            }
            KenCrudFlsHelper.assertCreateable(Thesis_Stage__c.SObjectType);
            Thesis_Stage__c s = new Thesis_Stage__c(
                Thesis__c    = thesisId,
                Label__c     = title,
                Stage_Key__c = 'task-' + Datetime.now().getTime(),
                Status__c    = 'pending',
                Due_Date__c  = dueDate
            );
            insert s;
            return s.Id;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenThesisManagementController.addThesisTask',
                'Could not add the task.', e);
            return null;
        }
    }

    @AuraEnabled
    public static Id uploadDraft(String fileName, String base64) {
        try {
            KenAuraExceptionHelper.rejectIf(String.isBlank(fileName), 'File name is required.');
            KenAuraExceptionHelper.rejectIf(String.isBlank(base64),   'File content is required.');
            // Find the student's Thesis record to attach the file to
            Id contactId = KenRunningStudentHelper.optionalContactId();
            Id parentId = null;
            if (contactId != null) {
                List<Thesis__c> th = [SELECT Id FROM Thesis__c WHERE Student__c = :contactId LIMIT 1];
                if (!th.isEmpty()) parentId = th[0].Id;
            }
            // Real ContentVersion insert
            ContentVersion cv = new ContentVersion(
                Title          = fileName,
                PathOnClient   = fileName,
                VersionData    = EncodingUtil.base64Decode(base64),
                FirstPublishLocationId = parentId  // Attach to thesis if we have one
            );
            insert cv;
            return cv.Id;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenThesisManagementController.uploadDraft',
                'Could not upload draft.', e);
            return null;
        }
    }

    private static List<ThesisStageDTO> seedStages() {
        List<ThesisStageDTO> out = new List<ThesisStageDTO>();
        out.add(stage('proposal',   'Proposal',    'done',    '15-Feb', '10-Feb-2026'));
        out.add(stage('review',     'Under Review','current', '30-Apr', null));
        out.add(stage('submission', 'Submission',  'pending', '15-May', null));
        out.add(stage('defence',    'Defence',     'pending', '30-May', null));
        return out;
    }

    private static List<CommitteeMemberDTO> seedCommittee() {
        List<CommitteeMemberDTO> out = new List<CommitteeMemberDTO>();
        out.add(member('CM001', 'Dr. Iyer',   'Chair',    'Computer Science'));
        out.add(member('CM002', 'Dr. Sharma', 'Advisor',  'Computer Science'));
        out.add(member('CM003', 'Prof. Gupta','Examiner', 'Mathematics'));
        return out;
    }

    private static ThesisStageDTO stage(String key, String label, String status, String due, String done) {
        ThesisStageDTO s = new ThesisStageDTO();
        s.key = key; s.label = label; s.status = status; s.dueDate = due; s.completedOn = done;
        return s;
    }

    private static CommitteeMemberDTO member(String id, String name, String role, String dept) {
        CommitteeMemberDTO m = new CommitteeMemberDTO();
        m.id = id; m.name = name; m.role = role; m.department = dept;
        return m;
    }
}