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
public with sharing class KenResearchController {

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
            if (contactId == null) {
                b.papers   = seedPapers();
                b.projects = seedProjects();
                return b;
            }
            for (Research_Paper__c p : [
                SELECT Id, Title__c, Authors__c, Venue__c, Year__c, Status__c, Download_Url__c
                FROM Research_Paper__c
                WHERE Student__c = :contactId
                WITH USER_MODE
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
                WITH USER_MODE
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
            if (b.papers.isEmpty() && b.projects.isEmpty()) {
                b.papers   = seedPapers();
                b.projects = seedProjects();
            }
            return b;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenResearchController.getResearchBundle',
                'Unable to load research.', e);
            return null;
        }
    }

    private static List<PaperDTO> seedPapers() {
        List<PaperDTO> out = new List<PaperDTO>();
        out.add(paper('RP001', 'Graph Algorithms for Sparse Networks', 'Arjun R, Dr. Iyer', 'ICML', '2025', 'Published', ''));
        out.add(paper('RP002', 'Reinforcement Learning in Education',  'Arjun R, Dr. Sharma','NeurIPS', '2025', 'Under review', ''));
        return out;
    }

    private static List<ProjectDTO> seedProjects() {
        List<ProjectDTO> out = new List<ProjectDTO>();
        out.add(project('PJ001', 'Smart Campus Energy Monitor', 'Dr. Iyer',   'IoT',   62, 'In progress'));
        out.add(project('PJ002', 'ML for Student Wellness',     'Dr. Sharma', 'ML',    34, 'Kickoff'));
        return out;
    }

    private static PaperDTO paper(String id, String title, String authors, String venue, String year, String status, String url) {
        PaperDTO p = new PaperDTO();
        p.id = id; p.title = title; p.authors = authors; p.venue = venue;
        p.year = year; p.status = status; p.downloadUrl = url;
        return p;
    }

    private static ProjectDTO project(String id, String title, String lead, String track, Decimal pct, String status) {
        ProjectDTO p = new ProjectDTO();
        p.id = id; p.title = title; p.lead = lead; p.track = track;
        p.progressPct = pct; p.status = status;
        return p;
    }
}