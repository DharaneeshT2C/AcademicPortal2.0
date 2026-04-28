/**
 * ************************************************************************************************
 * @className  KenResearchController
 *
 * @description
 *  Backs the `my/research` LWC page — lists research papers and active projects
 *  the running student is associated with.
 *
 *  TODO[SOBJECT]: Wire to `Research_Paper__c` and `Research_Project__c`.
 * ************************************************************************************************
 */
public without sharing class KenResearchController {

    public class PaperDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String authors;
        @AuraEnabled public String venue;
        @AuraEnabled public String year;
        @AuraEnabled public String status;
        @AuraEnabled public String downloadUrl;
    }

    public class ProjectDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  title;
        @AuraEnabled public String  lead;
        @AuraEnabled public String  track;
        @AuraEnabled public Decimal progressPct;
        @AuraEnabled public String  status;
    }

    public class ResearchBundleDTO {
        @AuraEnabled public List<PaperDTO>   papers;
        @AuraEnabled public List<ProjectDTO> projects;
    }

    @AuraEnabled(cacheable=true)
    public static ResearchBundleDTO getResearchBundle() {
        try {
            ResearchBundleDTO b = new ResearchBundleDTO();
            b.papers   = new List<PaperDTO>();
            b.projects = new List<ProjectDTO>();
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId == null) return b;
            for (Research_Paper__c p : [
                SELECT Id, Title__c, Authors__c, Venue__c, Year__c, Status__c, Download_Url__c
                FROM Research_Paper__c
                WHERE Student__c = :contactId
                WITH SECURITY_ENFORCED
                ORDER BY Year__c DESC
                LIMIT 50
            ]) {
                PaperDTO d = new PaperDTO();
                d.id          = p.Id;
                d.title       = p.Title__c;
                d.authors     = p.Authors__c;
                d.venue       = p.Venue__c;
                d.year        = p.Year__c;
                d.status      = p.Status__c;
                d.downloadUrl = p.Download_Url__c;
                b.papers.add(d);
            }
            for (Research_Project__c p : [
                SELECT Id, Title__c, Lead_Faculty__c, Track__c, Progress_Pct__c, Status__c
                FROM Research_Project__c
                WHERE Student__c = :contactId
                WITH SECURITY_ENFORCED
                LIMIT 50
            ]) {
                ProjectDTO d = new ProjectDTO();
                d.id          = p.Id;
                d.title       = p.Title__c;
                d.lead        = p.Lead_Faculty__c;
                d.track       = p.Track__c;
                d.progressPct = p.Progress_Pct__c == null ? 0 : p.Progress_Pct__c;
                d.status      = p.Status__c;
                b.projects.add(d);
            }
            return b;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenResearchController.getResearchBundle',
                'Unable to load research.', e);
            return null;
        }
    }

}