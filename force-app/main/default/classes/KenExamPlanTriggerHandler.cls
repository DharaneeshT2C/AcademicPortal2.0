/**
 * Creates/updates Examination records when a Ken_Exam_Plan__c is inserted or
 * has Ken_Exam_Cycle__c / Ken_Assessment__c changed, and removes them when
 * the plan is deleted. Bulk-safe, recursion-guarded, and dedupes against
 * existing Examinations for the same (plan, cycle, evaluation component)
 * tuple.
 */
public with sharing class KenExamPlanTriggerHandler {

    // Recursion guard — avoids re-entry if the DML below fires related
    // triggers that circle back to Ken_Exam_Plan__c.
    private static Boolean isExecuting = false;

    // ── Entry Points ──────────────────────────────────────────────────────────

    public static void handleAfterInsert(List<Ken_Exam_Plan__c> newRecords) {
        if (isExecuting || newRecords == null || newRecords.isEmpty()) return;

        List<Ken_Exam_Plan__c> eligible = filterEligibleForInsert(newRecords);
        if (eligible.isEmpty()) return;

        isExecuting = true;
        try {
            createExaminations(eligible);
        } finally {
            isExecuting = false;
        }
    }

    public static void handleAfterUpdate(
        List<Ken_Exam_Plan__c> newRecords,
        Map<Id, Ken_Exam_Plan__c> oldMap
    ) {
        if (isExecuting || newRecords == null || newRecords.isEmpty()) return;

        List<Ken_Exam_Plan__c> eligible = filterEligibleForUpdate(newRecords, oldMap);
        if (eligible.isEmpty()) return;

        isExecuting = true;
        try {
            createExaminations(eligible);
        } finally {
            isExecuting = false;
        }
    }

    public static void handleAfterDelete(List<Ken_Exam_Plan__c> oldRecords) {
        if (isExecuting || oldRecords == null || oldRecords.isEmpty()) return;

        isExecuting = true;
        try {
            deleteExaminationsForPlans(oldRecords);
        } finally {
            isExecuting = false;
        }
    }

    // ── Filters ───────────────────────────────────────────────────────────────

    private static List<Ken_Exam_Plan__c> filterEligibleForInsert(
        List<Ken_Exam_Plan__c> newRecords
    ) {
        List<Ken_Exam_Plan__c> result = new List<Ken_Exam_Plan__c>();
        for (Ken_Exam_Plan__c plan : newRecords) {
            if (plan.Ken_Exam_Cycle__c != null
                && String.isNotBlank((String) plan.Ken_Assessment__c)) {
                result.add(plan);
            }
        }
        return result;
    }

    private static List<Ken_Exam_Plan__c> filterEligibleForUpdate(
        List<Ken_Exam_Plan__c> newRecords,
        Map<Id, Ken_Exam_Plan__c> oldMap
    ) {
        List<Ken_Exam_Plan__c> result = new List<Ken_Exam_Plan__c>();
        for (Ken_Exam_Plan__c plan : newRecords) {
            Ken_Exam_Plan__c oldPlan = oldMap == null ? null : oldMap.get(plan.Id);
            if (oldPlan == null) continue;

            Boolean cycleChanged      = plan.Ken_Exam_Cycle__c != oldPlan.Ken_Exam_Cycle__c;
            Boolean assessmentChanged = plan.Ken_Assessment__c != oldPlan.Ken_Assessment__c;

            if ((cycleChanged || assessmentChanged)
                && plan.Ken_Exam_Cycle__c != null
                && String.isNotBlank((String) plan.Ken_Assessment__c)) {
                result.add(plan);
            }
        }
        return result;
    }

    // ── Core: Build & Insert/Update Examinations ──────────────────────────────

    private static void createExaminations(List<Ken_Exam_Plan__c> plans) {

        // 1. Re-query plans to pull the fields we need.
        Set<Id> planIds = new Map<Id, Ken_Exam_Plan__c>(plans).keySet();
        Map<Id, Ken_Exam_Plan__c> planMap = new Map<Id, Ken_Exam_Plan__c>([
            SELECT Id, Ken_Exam_Cycle__c, Ken_Assessment__c
            FROM Ken_Exam_Plan__c
            WHERE Id IN :planIds
        ]);

        // 2. Collect cycle Ids → look up their academic term.
        Set<Id> cycleIds = new Set<Id>();
        for (Ken_Exam_Plan__c plan : planMap.values()) {
            if (plan.Ken_Exam_Cycle__c != null) cycleIds.add(plan.Ken_Exam_Cycle__c);
        }
        if (cycleIds.isEmpty()) return;

        Map<Id, Id> cycleToTermId = new Map<Id, Id>();
        for (Ken_Exam_Cycle__c cycle : [
            SELECT Id, Ken_Academic_Term__c
            FROM Ken_Exam_Cycle__c
            WHERE Id IN :cycleIds
        ]) {
            if (cycle.Ken_Academic_Term__c != null) {
                cycleToTermId.put(cycle.Id, cycle.Ken_Academic_Term__c);
            }
        }
        if (cycleToTermId.isEmpty()) return;

        // 3. For each term, find distinct evaluation schemas via CourseOffering.
        Set<Id> termIds = new Set<Id>(cycleToTermId.values());
        Map<Id, Set<Id>> termToSchemaIds = new Map<Id, Set<Id>>();
        for (CourseOffering co : [
            SELECT Id, Ken_Evaluation_Schema__c, AcademicSession.AcademicTermId
            FROM CourseOffering
            WHERE AcademicSession.AcademicTermId IN :termIds
              AND Ken_Evaluation_Schema__c != null
        ]) {
            Id termId = co.AcademicSession.AcademicTermId;
            if (!termToSchemaIds.containsKey(termId)) {
                termToSchemaIds.put(termId, new Set<Id>());
            }
            termToSchemaIds.get(termId).add(co.Ken_Evaluation_Schema__c);
        }
        if (termToSchemaIds.isEmpty()) return;

        // 4. Collect the union of schema Ids + assessment values we need to filter on.
        Set<Id> allSchemaIds = new Set<Id>();
        for (Set<Id> schemaSet : termToSchemaIds.values()) allSchemaIds.addAll(schemaSet);

        Set<String> allAssessments = new Set<String>();
        for (Ken_Exam_Plan__c plan : planMap.values()) {
            if (String.isNotBlank((String) plan.Ken_Assessment__c)) {
                allAssessments.add((String) plan.Ken_Assessment__c);
            }
        }
        if (allSchemaIds.isEmpty() || allAssessments.isEmpty()) return;

        // 5. Query sub-component Ken_Evaluation_Component__c records in one go.
        //    Keyed by schemaId → assessment → List<component>.
        Map<Id, Map<String, List<Ken_Evaluation_Component__c>>> schemaAssessmentToComps
            = new Map<Id, Map<String, List<Ken_Evaluation_Component__c>>>();

        for (Ken_Evaluation_Component__c comp : [
            SELECT Id,
                   Ken_Assessment__c,
                   Ken_Parent_Evaluation_Component__c,
                   Ken_Parent_Evaluation_Component__r.Ken_Components__c,
                   Ken_Parent_Evaluation_Component__r.Ken_Exam_Type__c,
                   Ken_Parent_Evaluation_Component__r.Ken_Evaluation_Schema__c
            FROM Ken_Evaluation_Component__c
            WHERE RecordType.DeveloperName = 'Evaluation_Sub_Component'
              AND Ken_Assessment__c IN :allAssessments
              AND Ken_Parent_Evaluation_Component__r.Ken_Evaluation_Schema__c IN :allSchemaIds
        ]) {
            Id schemaId = comp.Ken_Parent_Evaluation_Component__r == null
                ? null
                : comp.Ken_Parent_Evaluation_Component__r.Ken_Evaluation_Schema__c;
            String assess = (String) comp.Ken_Assessment__c;
            if (schemaId == null || String.isBlank(assess)) continue;

            if (!schemaAssessmentToComps.containsKey(schemaId)) {
                schemaAssessmentToComps.put(schemaId, new Map<String, List<Ken_Evaluation_Component__c>>());
            }
            Map<String, List<Ken_Evaluation_Component__c>> byAssess = schemaAssessmentToComps.get(schemaId);
            if (!byAssess.containsKey(assess)) {
                byAssess.put(assess, new List<Ken_Evaluation_Component__c>());
            }
            byAssess.get(assess).add(comp);
        }
        if (schemaAssessmentToComps.isEmpty()) return;

        // 5b. Resolve course info (number + name) for each PARENT evaluation
        //     component via Ken_Course_Evaluation_Schema_Mapper__c. First
        //     mapper row per parent wins.
        Set<Id> parentComponentIds = new Set<Id>();
        for (Map<String, List<Ken_Evaluation_Component__c>> byAssess : schemaAssessmentToComps.values()) {
            for (List<Ken_Evaluation_Component__c> comps : byAssess.values()) {
                for (Ken_Evaluation_Component__c sub : comps) {
                    if (sub.Ken_Parent_Evaluation_Component__c != null) {
                        parentComponentIds.add(sub.Ken_Parent_Evaluation_Component__c);
                    }
                }
            }
        }

        Map<Id, CourseInfo> parentToCourse = new Map<Id, CourseInfo>();
        if (!parentComponentIds.isEmpty()) {
            for (Ken_Course_Evaluation_Schema_Mapper__c m : [
                SELECT Id,
                       Ken_Evaluation_Component__c,
                       Course_Offering__r.LearningCourse.CourseNumber,
                       Course_Offering__r.LearningCourse.Name
                FROM Ken_Course_Evaluation_Schema_Mapper__c
                WHERE Ken_Evaluation_Component__c IN :parentComponentIds
            ]) {
                Id parentId = m.Ken_Evaluation_Component__c;
                if (parentId == null || parentToCourse.containsKey(parentId)) continue;

                String courseNumber = m.Course_Offering__r != null
                    && m.Course_Offering__r.LearningCourse != null
                    ? m.Course_Offering__r.LearningCourse.CourseNumber : null;
                String courseName = m.Course_Offering__r != null
                    && m.Course_Offering__r.LearningCourse != null
                    ? m.Course_Offering__r.LearningCourse.Name : null;

                CourseInfo info = new CourseInfo();
                info.courseNumber = courseNumber;
                info.courseName   = courseName;
                parentToCourse.put(parentId, info);
            }
        }

        // 6. Build candidate Examinations and capture dedupe keys.
        List<Examination> toInsert = new List<Examination>();
        Set<Id> candidatePlans      = new Set<Id>();
        Set<Id> candidateCycles     = new Set<Id>();
        Set<Id> candidateComponents = new Set<Id>();

        for (Ken_Exam_Plan__c plan : planMap.values()) {
            Id cycleId        = plan.Ken_Exam_Cycle__c;
            String planAssess = (String) plan.Ken_Assessment__c;
            if (cycleId == null || String.isBlank(planAssess)) continue;

            Id termId = cycleToTermId.get(cycleId);
            if (termId == null) continue;

            Set<Id> schemaIds = termToSchemaIds.get(termId);
            if (schemaIds == null || schemaIds.isEmpty()) continue;

            for (Id schemaId : schemaIds) {
                Map<String, List<Ken_Evaluation_Component__c>> byAssess = schemaAssessmentToComps.get(schemaId);
                if (byAssess == null) continue;

                List<Ken_Evaluation_Component__c> comps = byAssess.get(planAssess);
                if (comps == null || comps.isEmpty()) continue;

                for (Ken_Evaluation_Component__c comp : comps) {
                    String parentComponent = comp.Ken_Parent_Evaluation_Component__r != null
                        ? (String) comp.Ken_Parent_Evaluation_Component__r.Ken_Components__c
                        : null;
                    String parentExamType = comp.Ken_Parent_Evaluation_Component__r != null
                        ? (String) comp.Ken_Parent_Evaluation_Component__r.Ken_Exam_Type__c
                        : null;

                    CourseInfo info = comp.Ken_Parent_Evaluation_Component__c != null
                        ? parentToCourse.get(comp.Ken_Parent_Evaluation_Component__c)
                        : null;
                    String courseNumber = info != null ? info.courseNumber : null;
                    String courseName   = info != null ? info.courseName   : null;

                    String examName = buildExaminationName(parentComponent, planAssess);

                    Examination exam = new Examination(
                        Name                        = examName,
                        Ken_Exam_Plan__c            = plan.Id,
                        Ken_Evaluation_Component__c = comp.Id,
                        Ken_Exam_Cycle__c           = cycleId,
                        Ken_Exam_Type__c            = parentExamType,
                        Ken_Course_Number__c        = courseNumber,
                        Ken_Course_Name__c          = courseName
                    );
                    toInsert.add(exam);

                    candidatePlans.add(plan.Id);
                    candidateCycles.add(cycleId);
                    candidateComponents.add(comp.Id);
                }
            }
        }
        if (toInsert.isEmpty()) return;

        // 7. Dedupe against existing Examinations for the same
        //    (plan, cycle, component) tuple. Existing rows whose course
        //    fields differ from the freshly-resolved values are queued for
        //    update so the handler can backfill them.
        Map<String, Examination> existingByKey = new Map<String, Examination>();
        for (Examination existing : [
            SELECT Id, Ken_Exam_Plan__c, Ken_Exam_Cycle__c, Ken_Evaluation_Component__c,
                   Ken_Course_Number__c, Ken_Course_Name__c
            FROM Examination
            WHERE Ken_Exam_Plan__c IN :candidatePlans
              AND Ken_Exam_Cycle__c IN :candidateCycles
              AND Ken_Evaluation_Component__c IN :candidateComponents
        ]) {
            String key = buildDedupeKey(
                existing.Ken_Exam_Plan__c,
                existing.Ken_Exam_Cycle__c,
                existing.Ken_Evaluation_Component__c
            );
            existingByKey.put(key, existing);
        }

        // Split candidates into insert vs update; also dedupe within this batch.
        Set<String> seenInBatch = new Set<String>();
        List<Examination> finalInsert = new List<Examination>();
        List<Examination> finalUpdate = new List<Examination>();
        for (Examination exam : toInsert) {
            String key = buildDedupeKey(
                exam.Ken_Exam_Plan__c,
                exam.Ken_Exam_Cycle__c,
                exam.Ken_Evaluation_Component__c
            );
            if (seenInBatch.contains(key)) continue;
            seenInBatch.add(key);

            Examination existing = existingByKey.get(key);
            if (existing == null) {
                finalInsert.add(exam);
                continue;
            }

            Boolean numberChanged = !stringEquals(existing.Ken_Course_Number__c, exam.Ken_Course_Number__c);
            Boolean nameChanged   = !stringEquals(existing.Ken_Course_Name__c,   exam.Ken_Course_Name__c);
            if (numberChanged || nameChanged) {
                Examination patch = new Examination(Id = existing.Id);
                if (numberChanged) patch.Ken_Course_Number__c = exam.Ken_Course_Number__c;
                if (nameChanged)   patch.Ken_Course_Name__c   = exam.Ken_Course_Name__c;
                finalUpdate.add(patch);
            }
        }

        if (finalInsert.isEmpty() && finalUpdate.isEmpty()) return;

        // 8. Insert/update with partial-success handling so one bad record
        //    does not block the rest.
        if (!finalInsert.isEmpty()) {
            Database.insert(finalInsert, false);
        }
        if (!finalUpdate.isEmpty()) {
            Database.update(finalUpdate, false);
        }
    }

    // ── Core: Delete Examinations tied to removed plans ───────────────────────

    private static void deleteExaminationsForPlans(List<Ken_Exam_Plan__c> oldRecords) {

        Set<Id> planIds = new Set<Id>();
        for (Ken_Exam_Plan__c plan : oldRecords) {
            if (plan.Id != null) planIds.add(plan.Id);
        }
        if (planIds.isEmpty()) return;

        List<Examination> matched = [
            SELECT Id
            FROM Examination
            WHERE Ken_Exam_Plan__c IN :planIds
        ];
        if (matched.isEmpty()) return;

        Database.delete(matched, false);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static String buildExaminationName(String parentComponent, String assessment) {
        String left  = String.isBlank(parentComponent) ? '' : parentComponent;
        String right = String.isBlank(assessment)      ? '' : assessment;
        String joined = (left + ' ' + right).trim();
        // Name field on Examination caps at 80 characters.
        if (joined.length() > 80) joined = joined.substring(0, 80);
        return joined;
    }

    private static String buildDedupeKey(Id planId, Id cycleId, Id componentId) {
        return String.valueOf(planId) + '|'
             + String.valueOf(cycleId) + '|'
             + String.valueOf(componentId);
    }

    private static Boolean stringEquals(String a, String b) {
        if (a == null && b == null) return true;
        if (a == null || b == null) return false;
        return a.equals(b);
    }

    private class CourseInfo {
        String courseNumber;
        String courseName;
    }
}