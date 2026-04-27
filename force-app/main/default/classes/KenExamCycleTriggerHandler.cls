public with sharing class KenExamCycleTriggerHandler {

    
    // BEFORE INSERT (ORCHESTRATOR)
   
    public static void handleBeforeInsert(List<Ken_Exam_Cycle__c> newRecords) {
        runFieldUpdates(newRecords);
    }

  
    // BEFORE UPDATE (ORCHESTRATOR)
    
    public static void handleBeforeUpdate(
        List<Ken_Exam_Cycle__c> newRecords,
        Map<Id, Ken_Exam_Cycle__c> oldMap) 
    {
        runFieldUpdatesForUpdate(newRecords, oldMap);
    }
    
    // FIELD UPDATE ENTRY METHODS
    
    private static void runFieldUpdates(List<Ken_Exam_Cycle__c> records) {
        updateActiveFlag(records);
    }

    private static void runFieldUpdatesForUpdate(
        List<Ken_Exam_Cycle__c> newRecords,
        Map<Id, Ken_Exam_Cycle__c> oldMap
    ) {
        List<Ken_Exam_Cycle__c> dateChangedRecords = getDateChangedRecords(newRecords, oldMap);

        if (!dateChangedRecords.isEmpty()) {
            updateActiveFlag(dateChangedRecords);
        }
    }

    
    // FILTER METHOD
    
    private static List<Ken_Exam_Cycle__c> getDateChangedRecords(
        List<Ken_Exam_Cycle__c> newRecords,
        Map<Id, Ken_Exam_Cycle__c> oldMap
    ) {
        List<Ken_Exam_Cycle__c> result = new List<Ken_Exam_Cycle__c>();

        for (Ken_Exam_Cycle__c rec : newRecords) {
            Ken_Exam_Cycle__c oldRec = oldMap.get(rec.Id);

            if (rec.Ken_Start_Date__c != oldRec.Ken_Start_Date__c ||
                rec.Ken_End_Date__c != oldRec.Ken_End_Date__c) {
                
                result.add(rec);
            }
        }

        return result;
    }

    // FIELD UPDATE LOGIC
   
    public static void updateActiveFlag(List<Ken_Exam_Cycle__c> records) {

        Datetime nowDT = System.now();

        for (Ken_Exam_Cycle__c rec : records) {

            if (rec.Ken_Start_Date__c != null && rec.Ken_End_Date__c != null) {

                if (nowDT >= rec.Ken_Start_Date__c &&
                    nowDT <= rec.Ken_End_Date__c) {

                    rec.Ken_Is_Active__c = true;

                } else {
                    rec.Ken_Is_Active__c = false;
                }
            } else {
                rec.Ken_Is_Active__c = false;
            }
        }
    }
}