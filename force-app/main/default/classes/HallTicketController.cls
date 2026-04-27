public with sharing class HallTicketController {

    // ─── VF page bindings ─────────────────────────────────────────────────────
    public String  studentName { get; private set; }
    public String  examTitle   { get; private set; }
    public List<SubjectRow> subjects { get; private set; }

    public class SubjectRow {
        public String code  { get; set; }
        public String title { get; set; }
    }

    // Empty row padding so the hall ticket keeps a consistent look
    private static final Integer TARGET_ROWS = 11;

    public List<Integer> getPaddingRows() {
        Integer have = subjects == null ? 0 : subjects.size();
        List<Integer> out = new List<Integer>();
        for (Integer i = have; i < TARGET_ROWS; i++) out.add(i);
        return out;
    }

    // Default ctor — invoked when VF page renders. Reads URL params and loads data.
    public HallTicketController() {
        subjects = new List<SubjectRow>();

        Map<String, String> p = ApexPages.currentPage().getParameters();
        String programPlanId = p.get('programPlanId');
        String contactId     = p.get('contactId');
        String assessment    = p.get('assessment');

        if (String.isNotBlank(programPlanId)
            && String.isNotBlank(contactId)
            && String.isNotBlank(assessment)) {
            loadForStudent(programPlanId, contactId, assessment);
        }
    }

    private void loadForStudent(Id programPlanId, Id contactId, String assessment) {
        Set<Id> coIds = getCourseOfferingIds(programPlanId);
        if (coIds.isEmpty()) return;

        List<PersonExamination> rows = [
            SELECT Contact.Name,
                   Ken_Evaluation_Component__r.Ken_Assessment__c,
                   Ken_Course_Offering_Participant__r.CourseOffering.LearningCourse.Name,
                   Ken_Course_Offering_Participant__r.CourseOffering.LearningCourse.CourseNumber
            FROM PersonExamination
            WHERE Ken_Enrollment_Status__c = 'Enrolled'
              AND Ken_Eligiblity__c      = 'Eligible'
             // AND Examination.Ken_Is_Active__c = true
              AND ContactId = :contactId
              AND Ken_Evaluation_Component__r.Ken_Assessment__c = :assessment
              AND Ken_Course_Offering_Participant__r.CourseOfferingId IN :coIds
        ];

        Set<String> seen = new Set<String>();
        for (PersonExamination pe : rows) {
            if (String.isBlank(studentName) && pe.Contact != null) {
                studentName = pe.Contact.Name;
            }
            if (String.isBlank(examTitle) && pe.Ken_Evaluation_Component__r != null) {
                examTitle = pe.Ken_Evaluation_Component__r.Ken_Assessment__c;
            }
            if (pe.Ken_Course_Offering_Participant__r == null
                || pe.Ken_Course_Offering_Participant__r.CourseOffering == null
                || pe.Ken_Course_Offering_Participant__r.CourseOffering.LearningCourse == null) {
                continue;
            }
            String code  = pe.Ken_Course_Offering_Participant__r.CourseOffering.LearningCourse.CourseNumber;
            String name  = pe.Ken_Course_Offering_Participant__r.CourseOffering.LearningCourse.Name;
            String key   = String.valueOf(code) + '|' + String.valueOf(name);
            if (seen.add(key)) {
                SubjectRow r = new SubjectRow();
                r.code  = code;
                r.title = name;
                subjects.add(r);
            }
        }
    }

    // ─── Shared lookup ────────────────────────────────────────────────────────
    public static Set<Id> getCourseOfferingIds(Id programPlanId) {
        Set<Id> ids = new Set<Id>();
        for (Program_Plan_Course_Junction__c j : [
            SELECT Course_Offering__c
            FROM Program_Plan_Course_Junction__c
            WHERE Learning_Program_Plan__c = :programPlanId
              AND Course_Offering__c != NULL
        ]) {
            ids.add(j.Course_Offering__c);
        }
        return ids;
    }

    // ─── LWC entry point ──────────────────────────────────────────────────────
    @AuraEnabled
    public static GenerationResult generateHallTickets(Id programPlanId) {
        if (programPlanId == null) {
            throw new AuraHandledException('Program Plan Id is required.');
        }

        Set<Id> coIds = getCourseOfferingIds(programPlanId);
        if (coIds.isEmpty()) {
            return new GenerationResult(0, 'No course offerings found for this Program Plan.');
        }

        List<PersonExamination> peList = [
            SELECT Id, ContactId, Contact.Name,
                   Ken_Course_Offering_Participant__r.AcademicTermEnrollmentId,
                   Ken_Course_Offering_Participant__r.CourseOfferingId,
                   Ken_Evaluation_Component__r.Ken_Assessment__c
            FROM PersonExamination
            WHERE Ken_Enrollment_Status__c = 'Enrolled'
              AND Ken_Eligiblity__c      = 'Eligible'
          //    AND Examination.Ken_Is_Active__c = true
              AND Ken_Course_Offering_Participant__r.CourseOfferingId IN :coIds
        ];
        if (peList.isEmpty()) {
            return new GenerationResult(0, 'No eligible students found for hall ticket generation.');
        }

        Map<String, GroupBucket> groups = new Map<String, GroupBucket>();
        for (PersonExamination pe : peList) {
            String assessment = pe.Ken_Evaluation_Component__r == null
                ? null : pe.Ken_Evaluation_Component__r.Ken_Assessment__c;
            if (pe.ContactId == null || String.isBlank(assessment)) continue;

            String key = String.valueOf(pe.ContactId) + '|' + assessment;
            GroupBucket g = groups.get(key);
            if (g == null) {
                g = new GroupBucket();
                g.contactId   = pe.ContactId;
                g.assessment  = assessment;
                g.studentName = pe.Contact == null ? '' : pe.Contact.Name;
                groups.put(key, g);
            }
            if (pe.Ken_Course_Offering_Participant__r != null
                && pe.Ken_Course_Offering_Participant__r.AcademicTermEnrollmentId != null) {
                g.atEnrollmentIds.add(pe.Ken_Course_Offering_Participant__r.AcademicTermEnrollmentId);
            }
        }

        List<GroupBucket> ordered = new List<GroupBucket>(groups.values());
        List<ContentVersion> cvs  = new List<ContentVersion>();

        for (GroupBucket g : ordered) {
            PageReference pr = Page.ExamHallticket;
            pr.getParameters().put('programPlanId', String.valueOf(programPlanId));
            pr.getParameters().put('contactId',     String.valueOf(g.contactId));
            pr.getParameters().put('assessment',    g.assessment);

            Blob body = Test.isRunningTest()
                ? Blob.valueOf('test-pdf')
                : pr.getContentAsPDF();

            String baseTitle = (g.studentName + ' ' + g.assessment + ' Hall Ticket').trim();
            String safeName  = baseTitle.replaceAll('[^A-Za-z0-9]+', '_');

            ContentVersion cv = new ContentVersion();
            cv.Title        = baseTitle;
            cv.PathOnClient = safeName + '.pdf';
            cv.VersionData  = body;
            cvs.add(cv);
        }
        insert cvs;

        Set<Id> cvIds = new Set<Id>();
        for (ContentVersion cv : cvs) cvIds.add(cv.Id);
        Map<Id, Id> cvToDoc = new Map<Id, Id>();
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :cvIds
        ]) {
            cvToDoc.put(cv.Id, cv.ContentDocumentId);
        }

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Integer i = 0; i < ordered.size(); i++) {
            Id docId = cvToDoc.get(cvs[i].Id);
            if (docId == null) continue;
            for (Id linkedId : ordered[i].atEnrollmentIds) {
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = docId;
                cdl.LinkedEntityId    = linkedId;
                cdl.ShareType         = 'V';
                cdl.Visibility        = 'AllUsers';
                links.add(cdl);
            }
        }
        if (!links.isEmpty()) insert links;

        return new GenerationResult(cvs.size(),
            'Generated ' + cvs.size() + ' hall ticket(s) for ' + ordered.size() + ' student(s).');
    }

    // ─── Wrappers ─────────────────────────────────────────────────────────────
    public class GenerationResult {
        @AuraEnabled public Integer count   { get; set; }
        @AuraEnabled public String  message { get; set; }
        public GenerationResult(Integer c, String m) { count = c; message = m; }
    }

    private class GroupBucket {
        Id      contactId;
        String  assessment;
        String  studentName;
        Set<Id> atEnrollmentIds = new Set<Id>();
    }
}