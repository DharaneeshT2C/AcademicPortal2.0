public with sharing class ExaminationPersonExaminationService {
    
    private static final String SUB_COMPONENT_RT = 'Evaluation_Sub_Component';
    private static final String ENROLLMENT_STATUS_NOT_ENROLLED = 'Not Enrolled';
    private static final String ELIGIBILE = 'Eligible';
    
    public static void process(Set<Id> examinationIds) {
        if (examinationIds == null || examinationIds.isEmpty()) {
            return;
        }
        
        Map<Id, Examination> examinationsById = getEligibleExaminations(examinationIds);
        if (examinationsById.isEmpty()) {
            return;
        }
        
        Set<Id> parentComponentIds = getParentComponentIds(examinationsById.values());
        if (parentComponentIds.isEmpty()) {
            return;
        }
        
        Map<Id, Set<Id>> offeringIdsByParentComponent = getOfferingIdsByParentComponent(parentComponentIds);
        if (offeringIdsByParentComponent.isEmpty()) {
            return;
        }
        
        Set<Id> allOfferingIds = getAllOfferingIds(offeringIdsByParentComponent);
        Map<Id, CourseOffering> offeringsById = getCourseOfferings(allOfferingIds);
        Map<Id, List<CourseOfferingParticipant>> participantsByOfferingId =
            getParticipantsByOffering(allOfferingIds);
        
        if (offeringsById.isEmpty() || participantsByOfferingId.isEmpty()) {
            return;
        }
        
        Set<Id> allParticipantIds = getAllParticipantIds(participantsByOfferingId);
        Map<String, PersonExamination> existingPersonExaminations =
            getExistingPersonExaminations(examinationsById.keySet(), allParticipantIds);
        
        List<PersonExamination> recordsToInsert = new List<PersonExamination>();
        List<PersonExamination> recordsToUpdate = new List<PersonExamination>();
        Set<String> processedKeys = new Set<String>();
        
        for (Examination examinationRecord : examinationsById.values()) {
            Id parentComponentId =
                examinationRecord.Ken_Evaluation_Component__r.Ken_Parent_Evaluation_Component__c;
            
            Set<Id> offeringIds = offeringIdsByParentComponent.get(parentComponentId);
            if (offeringIds == null || offeringIds.isEmpty()) {
                continue;
            }
            
            for (Id offeringId : offeringIds) {
                CourseOffering offeringRecord = offeringsById.get(offeringId);
                List<CourseOfferingParticipant> participants =
                    participantsByOfferingId.get(offeringId);
                
                if (offeringRecord == null || participants == null || participants.isEmpty()) {
                    continue;
                }
                
                for (CourseOfferingParticipant participant : participants) {
                    String uniqueKey = buildKey(examinationRecord.Id, participant.Id);
                    if (processedKeys.contains(uniqueKey)) {
                        continue;
                    }
                    
                    processedKeys.add(uniqueKey);
                    
                    PersonExamination existingRecord =
                        existingPersonExaminations.get(uniqueKey);
                    
                    if (existingRecord == null) {
                        recordsToInsert.add(
                            buildInsertRecord(examinationRecord, offeringRecord, participant)
                            );
                    } else {
                        updateExistingRecord(
                            existingRecord,
                        examinationRecord,
                        offeringRecord,
                        participant
                            );
                        recordsToUpdate.add(existingRecord);
                    }
                }
            }
        }
        
        if (!recordsToInsert.isEmpty()) {
            insert recordsToInsert;
        }
        
        if (!recordsToUpdate.isEmpty()) {
            update recordsToUpdate;
        }
    }
    
    private static Map<Id, Examination> getEligibleExaminations(Set<Id> examinationIds) {
        Map<Id, Examination> examinationsById = new Map<Id, Examination>();
        
        for (Examination examinationRecord : [
            SELECT Id,
                   Ken_Evaluation_Component__c,
                   Ken_Evaluation_Component__r.Name,
                   Ken_Evaluation_Component__r.Ken_Parent_Evaluation_Component__c,
                   Ken_Evaluation_Component__r.Ken_Assessment__c,
                   Ken_Evaluation_Component__r.RecordType.DeveloperName,
                   Ken_Exam_Start_Date_Time__c,
                   Ken_Exam_Type__c
            FROM Examination
            WHERE Id IN :examinationIds
            AND Ken_Evaluation_Component__c != null
        ]) {
            if (examinationRecord.Ken_Evaluation_Component__r == null) {
                continue;
            }
            
            if (
                examinationRecord.Ken_Evaluation_Component__r.RecordType.DeveloperName
                != SUB_COMPONENT_RT
            ) {
                continue;
            }
            
            if (
                examinationRecord.Ken_Evaluation_Component__r.Ken_Parent_Evaluation_Component__c
                == null
            ) {
                continue;
            }
            
            examinationsById.put(examinationRecord.Id, examinationRecord);
        }
        
        return examinationsById;
    }
    
    private static Set<Id> getParentComponentIds(List<Examination> examinationRecords) {
        Set<Id> parentComponentIds = new Set<Id>();
        
        for (Examination examinationRecord : examinationRecords) {
            parentComponentIds.add(
                examinationRecord.Ken_Evaluation_Component__r.Ken_Parent_Evaluation_Component__c
                );
        }
        
        return parentComponentIds;
    }
    
    private static Map<Id, Set<Id>> getOfferingIdsByParentComponent(Set<Id> parentComponentIds) {
        Map<Id, Set<Id>> offeringIdsByParentComponent = new Map<Id, Set<Id>>();
        
        for (Ken_Course_Evaluation_Schema_Mapper__c mapperRecord : [
            SELECT Course_Offering__c, Ken_Evaluation_Component__c
            FROM Ken_Course_Evaluation_Schema_Mapper__c
            WHERE Ken_Evaluation_Component__c IN :parentComponentIds
            AND Course_Offering__c != null
        ]) {
            if (!offeringIdsByParentComponent.containsKey(mapperRecord.Ken_Evaluation_Component__c)) {
                offeringIdsByParentComponent.put(
                    mapperRecord.Ken_Evaluation_Component__c,
                new Set<Id>()
                    );
            }
            
            offeringIdsByParentComponent.get(mapperRecord.Ken_Evaluation_Component__c)
                .add(mapperRecord.Course_Offering__c);
        }
        
        return offeringIdsByParentComponent;
    }
    
    private static Set<Id> getAllOfferingIds(Map<Id, Set<Id>> offeringIdsByParentComponent) {
        Set<Id> offeringIds = new Set<Id>();
        
        for (Set<Id> currentOfferingIds : offeringIdsByParentComponent.values()) {
            offeringIds.addAll(currentOfferingIds);
        }
        
        return offeringIds;
    }
    
    private static Map<Id, CourseOffering> getCourseOfferings(Set<Id> offeringIds) {
        if (offeringIds.isEmpty()) {
            return new Map<Id, CourseOffering>();
        }
        
        return new Map<Id, CourseOffering>([
            SELECT Id, LearningCourseId, LearningCourse.Name
            FROM CourseOffering
            WHERE Id IN :offeringIds
        ]);
    }
    
    private static Map<Id, List<CourseOfferingParticipant>> getParticipantsByOffering(
        Set<Id> offeringIds
    ) {
        Map<Id, List<CourseOfferingParticipant>> participantsByOfferingId =
            new Map<Id, List<CourseOfferingParticipant>>();
        
        for (CourseOfferingParticipant participant : [
            SELECT Id,
                   CourseOfferingId,
                   ParticipantAccountId,
                   ParticipantContactId
            FROM CourseOfferingParticipant
            WHERE CourseOfferingId IN :offeringIds
        ]) {
            if (!participantsByOfferingId.containsKey(participant.CourseOfferingId)) {
                participantsByOfferingId.put(
                    participant.CourseOfferingId,
                new List<CourseOfferingParticipant>()
                    );
            }
            
            participantsByOfferingId.get(participant.CourseOfferingId).add(participant);
        }
        
        return participantsByOfferingId;
    }
    
    private static Set<Id> getAllParticipantIds(
        Map<Id, List<CourseOfferingParticipant>> participantsByOfferingId
    ) {
        Set<Id> participantIds = new Set<Id>();
        
        for (List<CourseOfferingParticipant> participants : participantsByOfferingId.values()) {
            for (CourseOfferingParticipant participant : participants) {
                participantIds.add(participant.Id);
            }
        }
        
        return participantIds;
    }
    
    private static Map<String, PersonExamination> getExistingPersonExaminations(
        Set<Id> examinationIds,
    Set<Id> participantIds
    ) {
        Map<String, PersonExamination> existingRecords = new Map<String, PersonExamination>();
        if (examinationIds.isEmpty() || participantIds.isEmpty()) {
            return existingRecords;
        }
        
        for (PersonExamination personExaminationRecord : [
            SELECT Id,
                   ExaminationId,
                   Ken_Course_Offering_Participant__c,
                   AccountId,
                   ContactId,
                   ExaminationDate,
                   Ken_Course_Name__c,
                   Ken_Evaluation_Component__c,
                   Ken_Exam_Type__c,
                   Ken_Assessment__c,
                   Ken_Enrollment_Status__c,
                   Ken_Eligiblity__c
            FROM PersonExamination
            WHERE ExaminationId IN :examinationIds
            AND Ken_Course_Offering_Participant__c IN :participantIds
        ]) {
            existingRecords.put(
                buildKey(
                personExaminationRecord.ExaminationId,
            personExaminationRecord.Ken_Course_Offering_Participant__c
                ),
            personExaminationRecord
                );
        }
        
        return existingRecords;
    }
    
    private static PersonExamination buildInsertRecord(
        Examination examinationRecord,
    CourseOffering offeringRecord,
    CourseOfferingParticipant participant
    ) {
        PersonExamination personExaminationRecord = new PersonExamination();
        personExaminationRecord.ExaminationId = examinationRecord.Id;
        personExaminationRecord.Ken_Course_Offering_Participant__c = participant.Id;
        personExaminationRecord.Ken_Enrollment_Status__c =
            ENROLLMENT_STATUS_NOT_ENROLLED;
        personExaminationRecord.Ken_Eligiblity__c = ELIGIBILE;
        
        updateSharedFields(
            personExaminationRecord,
        examinationRecord,
        offeringRecord,
        participant
            );
        
        return personExaminationRecord;
    }
    
    private static void updateExistingRecord(
        PersonExamination personExaminationRecord,
    Examination examinationRecord,
    CourseOffering offeringRecord,
    CourseOfferingParticipant participant
    ) {
        updateSharedFields(
            personExaminationRecord,
        examinationRecord,
        offeringRecord,
        participant
            );
    }
    
    private static void updateSharedFields(
        PersonExamination personExaminationRecord,
    Examination examinationRecord,
    CourseOffering offeringRecord,
    CourseOfferingParticipant participant
    ) {
        personExaminationRecord.ContactId = participant.ParticipantContactId;
        personExaminationRecord.AccountId = participant.ParticipantAccountId;
        personExaminationRecord.Ken_Course_Name__c =
            offeringRecord.LearningCourse == null
            ? null
            : offeringRecord.LearningCourse.Name;
        personExaminationRecord.Ken_Assessment__c =
            examinationRecord.Ken_Evaluation_Component__r.Ken_Assessment__c;
        personExaminationRecord.Ken_Evaluation_Component__c =
            examinationRecord.Ken_Evaluation_Component__r.Id;
        personExaminationRecord.Ken_Exam_Type__c =
            examinationRecord.Ken_Exam_Type__c;
        
        if (examinationRecord.Ken_Exam_Start_Date_Time__c != null) {
            personExaminationRecord.ExaminationDate =
                examinationRecord.Ken_Exam_Start_Date_Time__c;
        }
    }
    
    private static String buildKey(Id examinationId, Id participantId) {
        return String.valueOf(examinationId) + '__' + String.valueOf(participantId);
    }
}