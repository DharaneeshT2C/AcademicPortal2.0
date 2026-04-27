/**
 * Handler class for CourseOffering trigger.
 * Processes CourseOfrPtcpActvtyGrd creation when Ken_Evaluation_Schema__c
 * is inserted or updated on a CourseOffering record.
 *
 * Called from: CourseOfferingTrigger (after insert / after update)
 * Async:       KenEvaluationGradeQueueable
 */
public with sharing class KenCourseOfferingEvaluationHandler {

    // ─────────────────────────────────────────────────────────────────────────
    // ENTRY POINT  –  called directly from the trigger (after context)
    // ─────────────────────────────────────────────────────────────────────────

    public static void handleEvaluationSchemaChange(
        List<CourseOffering> newList,
        Map<Id, CourseOffering> oldMap
    ) {
        Set<Id> courseOfferingIds = new Set<Id>();

        for (CourseOffering co : newList) {

            // Skip if no evaluation schema is set
            if (co.Ken_Evaluation_Schema__c == null) {
                continue;
            }

            Boolean isInsert = (oldMap == null || !oldMap.containsKey(co.Id));
            Boolean fieldChanged = !isInsert
                && co.Ken_Evaluation_Schema__c != oldMap.get(co.Id).Ken_Evaluation_Schema__c;

            if (isInsert || fieldChanged) {
                courseOfferingIds.add(co.Id);
            }
        }

        if (courseOfferingIds.isEmpty()) {
            return;
        }

        // Offload heavy processing to a Queueable so we stay clear of
        // synchronous governor limits during the triggering transaction.
        if (!System.isFuture() && !System.isBatch()) {
            System.enqueueJob(new KenEvaluationGradeQueueable(courseOfferingIds));
        } else {
            // Already async – run inline (e.g. invoked from batch/future)
            processEvaluationGrades(courseOfferingIds);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CORE PROCESSING  –  called from KenEvaluationGradeQueueable
    // ─────────────────────────────────────────────────────────────────────────

    public static void processEvaluationGrades(Set<Id> courseOfferingIds) {

        if (courseOfferingIds == null || courseOfferingIds.isEmpty()) {
            return;
        }

        // ── STEP 1: Participants per CourseOffering ───────────────────────────
        Map<Id, List<CourseOfferingParticipant>> participantsByCO =
            new Map<Id, List<CourseOfferingParticipant>>();

        for (CourseOfferingParticipant cop : [
            SELECT Id, ParticipantContactId, CourseOfferingId
            FROM   CourseOfferingParticipant
            WHERE  CourseOfferingId IN :courseOfferingIds
        ]) {
            if (!participantsByCO.containsKey(cop.CourseOfferingId)) {
                participantsByCO.put(cop.CourseOfferingId,
                                     new List<CourseOfferingParticipant>());
            }
            participantsByCO.get(cop.CourseOfferingId).add(cop);
        }

        if (participantsByCO.isEmpty()) {
            return;
        }

        // Flat set of all participant IDs (used in later queries)
        Set<Id> allParticipantIds = new Set<Id>();
        for (List<CourseOfferingParticipant> cops : participantsByCO.values()) {
            for (CourseOfferingParticipant cop : cops) {
                allParticipantIds.add(cop.Id);
            }
        }

        // ── STEP 2: Parent Evaluation Components per CourseOffering ──────────
        //    Source: Ken_Course_Evaluation_Schema_Mapper__c
        //    Filter: RecordType = Evaluation_Component (parent only)
        Map<Id, Set<Id>> parentEvalCompIdsByCO = new Map<Id, Set<Id>>();

        for (Ken_Course_Evaluation_Schema_Mapper__c mapper : [
            SELECT Id,
                   Course_Offering__c,
                   Ken_Evaluation_Component__c,
                   Ken_Evaluation_Component__r.RecordType.DeveloperName
            FROM   Ken_Course_Evaluation_Schema_Mapper__c
            WHERE  Course_Offering__c IN :courseOfferingIds
            AND    Ken_Evaluation_Component__r.RecordType.DeveloperName
                       = 'Evaluation_Component'
        ]) {
            if (!parentEvalCompIdsByCO.containsKey(mapper.Course_Offering__c)) {
                parentEvalCompIdsByCO.put(mapper.Course_Offering__c,
                                          new Set<Id>());
            }
            parentEvalCompIdsByCO.get(mapper.Course_Offering__c)
                                 .add(mapper.Ken_Evaluation_Component__c);
        }

        if (parentEvalCompIdsByCO.isEmpty()) {
            return;
        }

        // Flat set of all parent Evaluation Component IDs
        Set<Id> allParentEvalCompIds = new Set<Id>();
        for (Set<Id> ids : parentEvalCompIdsByCO.values()) {
            allParentEvalCompIds.addAll(ids);
        }

        // ── STEP 3: Child Evaluation Components per Parent ───────────────────
        //    RecordType = Evaluation_Sub_Component, self-lookup field
        Map<Id, List<Id>> childEvalCompIdsByParent = new Map<Id, List<Id>>();

        for (Ken_Evaluation_Component__c child : [
            SELECT Id,
                   Ken_Parent_Evaluation_Component__c,
                   RecordType.DeveloperName
            FROM   Ken_Evaluation_Component__c
            WHERE  Ken_Parent_Evaluation_Component__c IN :allParentEvalCompIds
            AND    RecordType.DeveloperName = 'Evaluation_Sub_Component'
        ]) {
            Id parentId = child.Ken_Parent_Evaluation_Component__c;
            if (!childEvalCompIdsByParent.containsKey(parentId)) {
                childEvalCompIdsByParent.put(parentId, new List<Id>());
            }
            childEvalCompIdsByParent.get(parentId).add(child.Id);
        }

        // Flat set of all child Evaluation Component IDs
        Set<Id> allChildEvalCompIds = new Set<Id>();
        for (List<Id> childIds : childEvalCompIdsByParent.values()) {
            allChildEvalCompIds.addAll(childIds);
        }

        // Full set (parent + child) for duplicate check
        Set<Id> allEvalCompIds = new Set<Id>(allParentEvalCompIds);
        allEvalCompIds.addAll(allChildEvalCompIds);

        // ── STEP 4: Duplicate-prevention check ───────────────────────────────
        //    Key = CourseOfferingParticipantId + '__' + Ken_Evaluation_Component__c
        Set<String> existingGradeKeys = new Set<String>();

        for (CourseOfrPtcpActvtyGrd existing : [
            SELECT Id, CourseOfferingParticipantId, Ken_Evaluation_Component__c
            FROM   CourseOfrPtcpActvtyGrd
            WHERE  CourseOfferingParticipantId IN :allParticipantIds
            AND    Ken_Evaluation_Component__c IN :allEvalCompIds
        ]) {
            existingGradeKeys.add(
                buildKey(existing.CourseOfferingParticipantId,
                         existing.Ken_Evaluation_Component__c)
            );
        }

        // ── STEP 5: Fetch RecordType IDs for CourseOfrPtcpActvtyGrd ──────────
        Map<String, Id> gradeRecordTypeIds = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM   RecordType
            WHERE  SObjectType = 'CourseOfrPtcpActvtyGrd'
            AND    DeveloperName IN ('Componnet', 'Sub_Component')
        ]) {
            gradeRecordTypeIds.put(rt.DeveloperName, rt.Id);
        }

        Id parentGradeRtId = gradeRecordTypeIds.get('Componnet');
        Id childGradeRtId  = gradeRecordTypeIds.get('Sub_Component');

        // ── STEP 6: Build PARENT CourseOfrPtcpActvtyGrd records ──────────────
        //    One parent grade per (Participant × Parent Eval Component)
        List<CourseOfrPtcpActvtyGrd> parentGradesToInsert =
            new List<CourseOfrPtcpActvtyGrd>();

        for (Id coId : courseOfferingIds) {
            List<CourseOfferingParticipant> participants =
                participantsByCO.get(coId);
            Set<Id> parentEvalCompIds =
                parentEvalCompIdsByCO.get(coId);

            if (participants == null || parentEvalCompIds == null) {
                continue;
            }

            for (CourseOfferingParticipant cop : participants) {
                for (Id parentEvalCompId : parentEvalCompIds) {

                    String key = buildKey(cop.Id, parentEvalCompId);
                    if (existingGradeKeys.contains(key)) {
                        continue; // duplicate – skip
                    }

                    CourseOfrPtcpActvtyGrd grade = new CourseOfrPtcpActvtyGrd();
                    grade.CourseOfferingParticipantId = cop.Id;
                    grade.Ken_Evaluation_Component__c  = parentEvalCompId;
                    grade.ContactId                    = cop.ParticipantContactId;
                    grade.ScoreStatus                  = 'Not Submitted';
                    if (parentGradeRtId != null) {
                        grade.RecordTypeId = parentGradeRtId;
                    }
                    parentGradesToInsert.add(grade);

                    // Mark as "to be created" so we don't try again
                    existingGradeKeys.add(key);
                }
            }
        }

        if (!parentGradesToInsert.isEmpty()) {
            insert parentGradesToInsert;
        }

        // ── STEP 7: Build lookup map  participantId+parentEvalCompId → new grade Id
        //    Also pull in ANY pre-existing parent grades so child records can
        //    find their parent grade even when the parent wasn't re-inserted.
        Map<String, Id> parentGradeIdMap = new Map<String, Id>();

        // Freshly inserted
        for (CourseOfrPtcpActvtyGrd g : parentGradesToInsert) {
            parentGradeIdMap.put(
                buildKey(g.CourseOfferingParticipantId,
                         g.Ken_Evaluation_Component__c),
                g.Id
            );
        }

        // Pre-existing parent grades
        for (CourseOfrPtcpActvtyGrd existing : [
            SELECT Id, CourseOfferingParticipantId, Ken_Evaluation_Component__c
            FROM   CourseOfrPtcpActvtyGrd
            WHERE  CourseOfferingParticipantId IN :allParticipantIds
            AND    Ken_Evaluation_Component__c IN :allParentEvalCompIds
        ]) {
            String key = buildKey(existing.CourseOfferingParticipantId,
                                  existing.Ken_Evaluation_Component__c);
            if (!parentGradeIdMap.containsKey(key)) {
                parentGradeIdMap.put(key, existing.Id);
            }
        }

        // ── STEP 8: Build CHILD CourseOfrPtcpActvtyGrd records ───────────────
        //    One child grade per (Participant × Child Eval Component)
        //    COP_Activity_Grade__c  = parent grade record
        //    Ken_Evaluation_Component__c = child Eval Component
        List<CourseOfrPtcpActvtyGrd> childGradesToInsert =
            new List<CourseOfrPtcpActvtyGrd>();

        for (Id coId : courseOfferingIds) {
            List<CourseOfferingParticipant> participants =
                participantsByCO.get(coId);
            Set<Id> parentEvalCompIds =
                parentEvalCompIdsByCO.get(coId);

            if (participants == null || parentEvalCompIds == null) {
                continue;
            }

            for (CourseOfferingParticipant cop : participants) {
                for (Id parentEvalCompId : parentEvalCompIds) {

                    List<Id> childEvalCompIds =
                        childEvalCompIdsByParent.get(parentEvalCompId);
                    if (childEvalCompIds == null || childEvalCompIds.isEmpty()) {
                        continue;
                    }

                    // Look up the parent CourseOfrPtcpActvtyGrd for this pair
                    Id parentGradeId = parentGradeIdMap.get(
                        buildKey(cop.Id, parentEvalCompId)
                    );

                    for (Id childEvalCompId : childEvalCompIds) {

                        String key = buildKey(cop.Id, childEvalCompId);
                        if (existingGradeKeys.contains(key)) {
                            continue; // duplicate – skip
                        }

                        CourseOfrPtcpActvtyGrd childGrade =
                            new CourseOfrPtcpActvtyGrd();
                        childGrade.CourseOfferingParticipantId = cop.Id;
                        childGrade.Ken_Evaluation_Component__c  = childEvalCompId;
                        childGrade.COP_Activity_Grade__c         = parentGradeId;
                        childGrade.ContactId                     = cop.ParticipantContactId;
                        childGrade.ScoreStatus                   = 'Not Submitted';
                        if (childGradeRtId != null) {
                            childGrade.RecordTypeId = childGradeRtId;
                        }
                        childGradesToInsert.add(childGrade);

                        existingGradeKeys.add(key);
                    }
                }
            }
        }

        if (!childGradesToInsert.isEmpty()) {
            insert childGradesToInsert;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HELPER
    // ─────────────────────────────────────────────────────────────────────────

    private static String buildKey(Id participantId, Id evalCompId) {
        return (String) participantId + '__' + (String) evalCompId;
    }
}