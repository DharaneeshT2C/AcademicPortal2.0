public with sharing class ExaminationPersonExaminationQueueable implements Queueable {

    @TestVisible
    private static final Integer CHUNK_SIZE = 25;

    private List<Id> examinationIdList;

    public ExaminationPersonExaminationQueueable(Set<Id> examinationIds) {
        this.examinationIdList = new List<Id>(examinationIds);
    }

    private ExaminationPersonExaminationQueueable(List<Id> examinationIds) {
        this.examinationIdList = examinationIds;
    }

    public void execute(QueueableContext context) {
        if (examinationIdList == null || examinationIdList.isEmpty()) {
            return;
        }

        Integer endIndex = Math.min(CHUNK_SIZE, examinationIdList.size());
        List<Id> currentChunk = new List<Id>();
        List<Id> remainingChunk = new List<Id>();

        for (Integer indexValue = 0; indexValue < examinationIdList.size(); indexValue++) {
            if (indexValue < endIndex) {
                currentChunk.add(examinationIdList[indexValue]);
            } else {
                remainingChunk.add(examinationIdList[indexValue]);
            }
        }

        ExaminationPersonExaminationService.process(
            new Set<Id>(currentChunk)
        );

        if (!remainingChunk.isEmpty()) {
            try {
                System.enqueueJob(
                    new ExaminationPersonExaminationQueueable(
                        remainingChunk
                    )
                );
            } catch (Exception queueException) {
                System.debug(
                    LoggingLevel.ERROR,
                    'ExaminationPersonExaminationQueueable chaining failed: '
                    + queueException.getMessage()
                );
            }
        }
    }
}