public with sharing class ExaminationTriggerHandler {

    public static void handleAfterInsertUpdate(
        List<Examination> newRecords,
        Map<Id, Examination> oldMap
    ) {
        Set<Id> examinationIdsToProcess = getExaminationIdsToProcess(newRecords, oldMap);
        if (examinationIdsToProcess.isEmpty()) {
            return;
        }

        System.enqueueJob(
            new ExaminationPersonExaminationQueueable(examinationIdsToProcess)
        );
    }

    @TestVisible
    private static Set<Id> getExaminationIdsToProcess(
        List<Examination> newRecords,
        Map<Id, Examination> oldMap
    ) {
        Set<Id> examinationIds = new Set<Id>();

        for (Examination examRecord : newRecords) {
            if (examRecord.Ken_Evaluation_Component__c == null) {
                continue;
            }

            Boolean isInsert = oldMap == null || !oldMap.containsKey(examRecord.Id);
            Boolean componentChanged = !isInsert
                && examRecord.Ken_Evaluation_Component__c
                    != oldMap.get(examRecord.Id).Ken_Evaluation_Component__c;

            if (isInsert || componentChanged) {
                examinationIds.add(examRecord.Id);
            }
        }

        return examinationIds;
    }
}