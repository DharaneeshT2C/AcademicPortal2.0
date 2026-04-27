/**
 * Queueable job that drives KenCourseOfferingEvaluationHandler.processEvaluationGrades().
 *
 * Using Queueable (rather than @future) gives us:
 *  - Higher heap limit  (12 MB vs 6 MB)
 *  - Higher SOQL limit  (200 vs 100)
 *  - Ability to chain jobs when batches are too large
 *  - An AsyncApexJob Id for monitoring
 *
 * Chunking strategy:
 *  If more than CHUNK_SIZE CourseOffering IDs are passed in one go, the job
 *  processes the first CHUNK_SIZE and re-enqueues itself with the remainder.
 *  This keeps each execution well inside all governor limits.
 */
public with sharing class KenEvaluationGradeQueueable implements Queueable {

    // Maximum CourseOffering IDs processed per Queueable execution.
    // Tune this value to balance throughput vs. heap / SOQL headroom.
    @TestVisible
    private static final Integer CHUNK_SIZE = 20;

    private List<Id> courseOfferingIdList;

    // ── Constructor ──────────────────────────────────────────────────────────

    public KenEvaluationGradeQueueable(Set<Id> courseOfferingIds) {
        this.courseOfferingIdList = new List<Id>(courseOfferingIds);
    }

    private KenEvaluationGradeQueueable(List<Id> courseOfferingIdList) {
        this.courseOfferingIdList = courseOfferingIdList;
    }

    // ── Execute ──────────────────────────────────────────────────────────────

    public void execute(QueueableContext context) {

        if (courseOfferingIdList == null || courseOfferingIdList.isEmpty()) {
            return;
        }

        // ── Determine this execution's chunk ─────────────────────────────────
        Integer total     = courseOfferingIdList.size();
        Integer endIndex  = Math.min(CHUNK_SIZE, total);

        List<Id> currentChunk   = new List<Id>();
        List<Id> remainingChunk = new List<Id>();

        for (Integer i = 0; i < total; i++) {
            if (i < endIndex) {
                currentChunk.add(courseOfferingIdList[i]);
            } else {
                remainingChunk.add(courseOfferingIdList[i]);
            }
        }

        // ── Process the current chunk ─────────────────────────────────────────
        try {
            KenCourseOfferingEvaluationHandler.processEvaluationGrades(
                new Set<Id>(currentChunk)
            );
        } catch (Exception ex) {
            // Log the error but do NOT rethrow – a failure in one chunk
            // should not block the remaining chunks from being enqueued.
            System.debug(LoggingLevel.ERROR,
                'KenEvaluationGradeQueueable: Error processing chunk – '
                + ex.getMessage() + '\n' + ex.getStackTraceString());
        }

        // ── Chain next job if there are remaining IDs ─────────────────────────
        if (!remainingChunk.isEmpty()) {
            try {
                System.enqueueJob(new KenEvaluationGradeQueueable(remainingChunk));
            } catch (Exception chainEx) {
                // Async stack-depth / enqueue limits (e.g. during tests) —
                // log and continue; the current chunk has already been processed.
                System.debug(LoggingLevel.ERROR,
                    'KenEvaluationGradeQueueable: Failed to chain next chunk – '
                    + chainEx.getMessage());
            }
        }
    }
}