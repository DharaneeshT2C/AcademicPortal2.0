public with sharing class PersonExaminationTriggerHandler {
    private static final String ENROLLMENT_STATUS_ENROLLED = 'Enrolled';
    private static final String AUTO_REGISTER = 'Auto Register';
    private static final String NO_FEE_ANY_STUDENTS = 'No Fee Any Students';
    private static final String EXAM_TYPE_REGULAR = 'Regular';

    public static void handleBeforeInsert(List<PersonExamination> newRecords) {
        applyAutoEnrollment(newRecords, null);
    }

    public static void handleBeforeUpdate(
        List<PersonExamination> newRecords,
        Map<Id, PersonExamination> oldMap
    ) {
        applyAutoEnrollment(newRecords, oldMap);
    }

    public static void handleAfterChange(
        List<PersonExamination> newRecords,
        Map<Id, PersonExamination> oldMap
    ) {
        Set<Id> examinationIds = collectAffectedExaminationIds(newRecords, oldMap);
        PersonExaminationStatusRollup.rollup(examinationIds);
    }

    public static void handleAfterDelete(List<PersonExamination> oldRecords) {
        PersonExaminationStatusRollup.rollup(collectExaminationIds(oldRecords));
    }

    private static Set<Id> collectAffectedExaminationIds(
        List<PersonExamination> newRecords,
        Map<Id, PersonExamination> oldMap
    ) {
        Set<Id> examinationIds = collectExaminationIds(newRecords);
        if (oldMap != null) {
            examinationIds.addAll(collectExaminationIds(oldMap.values()));
        }
        return examinationIds;
    }

    private static Set<Id> collectExaminationIds(Iterable<PersonExamination> records) {
        Set<Id> examinationIds = new Set<Id>();
        if (records == null) {
            return examinationIds;
        }

        for (PersonExamination personExam : records) {
            if (personExam.ExaminationId != null) {
                examinationIds.add(personExam.ExaminationId);
            }
        }
        return examinationIds;
    }

    private static void applyAutoEnrollment(
        List<PersonExamination> newRecords,
        Map<Id, PersonExamination> oldMap
    ) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        Set<Id> criteriaIds = new Set<Id>();
        Set<Id> participantIds = new Set<Id>();
        for (PersonExamination personExam : newRecords) {
            if (!shouldEvaluate(personExam, oldMap)) {
                continue;
            }
            Id criteriaId = (Id) personExam.get('Ken_Enrollment_Criteria__c');
            if (criteriaId != null) {
                criteriaIds.add(criteriaId);
            }
            Id participantId =
                (Id) personExam.get('Ken_Course_Offering_Participant__c');
            if (participantId != null) {
                participantIds.add(participantId);
            }
        }

        if (criteriaIds.isEmpty()) {
            return;
        }

        Map<Id, Ken_Enrollment_Cretirea__c> criteriaById =
            new Map<Id, Ken_Enrollment_Cretirea__c>([
                SELECT Id,
                       Ken_Fee_Criteria__c,
                       Ken_Regular_Fee_Criteria__c,
                       Ken_Backlog_Fee_Criteria__c,
                       Ken_Same_Fee_Regular_and_Backlog__c,
                       Ken_Enrollment_for_Backlog_Courses__c,
                       Ken_Enrollment_for_Regular_Courses__c
                FROM Ken_Enrollment_Cretirea__c
                WHERE Id IN :criteriaIds
            ]);

        Map<Id, CourseOfferingParticipant> participantById =
            participantIds.isEmpty()
            ? new Map<Id, CourseOfferingParticipant>()
            : new Map<Id, CourseOfferingParticipant>([
                SELECT Id,
                       CourseOffering.Exam_Type__c
                FROM CourseOfferingParticipant
                WHERE Id IN :participantIds
            ]);

        for (PersonExamination personExam : newRecords) {
            if (!shouldEvaluate(personExam, oldMap)) {
                continue;
            }

            Id criteriaId = (Id) personExam.get('Ken_Enrollment_Criteria__c');
            Ken_Enrollment_Cretirea__c criteria = criteriaById.get(criteriaId);
            if (criteria == null) {
                continue;
            }

            CourseOfferingParticipant participant = participantById.get(
                (Id) personExam.get('Ken_Course_Offering_Participant__c')
            );

            if (!shouldAutoEnroll(personExam, criteria, participant)) {
                continue;
            }

            personExam.Ken_Enrollment_Status__c = ENROLLMENT_STATUS_ENROLLED;
        }
    }

    private static Boolean shouldEvaluate(
        PersonExamination personExam,
        Map<Id, PersonExamination> oldMap
    ) {
        if (personExam == null) {
            return false;
        }

        if (oldMap == null || !oldMap.containsKey(personExam.Id)) {
            return personExam.get('Ken_Enrollment_Criteria__c') != null;
        }

        PersonExamination oldRecord = oldMap.get(personExam.Id);
        return personExam.get('Ken_Enrollment_Criteria__c')
            != oldRecord.get('Ken_Enrollment_Criteria__c');
    }

    private static Boolean shouldAutoEnroll(
        PersonExamination personExam,
        Ken_Enrollment_Cretirea__c criteria,
        CourseOfferingParticipant participant
    ) {
        if (criteria == null || personExam == null) {
            return false;
        }

        String examType = resolveExamType(personExam, participant);
        String enrollmentMode = getApplicableEnrollmentMode(criteria, examType);
        if (!matchesValue(enrollmentMode, AUTO_REGISTER)) {
            return false;
        }

        String feeCriteria = getApplicableFeeCriteria(criteria, examType);
        return matchesValue(feeCriteria, NO_FEE_ANY_STUDENTS);
    }

    private static String resolveExamType(
        PersonExamination personExam,
        CourseOfferingParticipant participant
    ) {
        if (
            participant != null &&
            participant.CourseOffering != null &&
            String.isNotBlank(participant.CourseOffering.Exam_Type__c)
        ) {
            return participant.CourseOffering.Exam_Type__c;
        }
        return personExam.Ken_Exam_Type__c;
    }

    private static Boolean isRegularExamType(String examType) {
        String normalizedExamType = normalizeValue(examType);
        if (String.isBlank(normalizedExamType)) {
            return true;
        }
        return normalizedExamType.contains(normalizeValue(EXAM_TYPE_REGULAR));
    }

    private static Boolean isBacklogExamType(String examType) {
        return !isRegularExamType(examType);
    }

    private static String getApplicableEnrollmentMode(
        Ken_Enrollment_Cretirea__c criteria,
        String examType
    ) {
        if (criteria == null) {
            return null;
        }

        return isBacklogExamType(examType)
            ? criteria.Ken_Enrollment_for_Backlog_Courses__c
            : criteria.Ken_Enrollment_for_Regular_Courses__c;
    }

    private static String getApplicableFeeCriteria(
        Ken_Enrollment_Cretirea__c criteria,
        String examType
    ) {
        if (criteria == null) {
            return null;
        }

        if (criteria.Ken_Same_Fee_Regular_and_Backlog__c) {
            return criteria.Ken_Fee_Criteria__c;
        }

        return isBacklogExamType(examType)
            ? criteria.Ken_Backlog_Fee_Criteria__c
            : criteria.Ken_Regular_Fee_Criteria__c;
    }

    private static Boolean matchesValue(String currentValue, String expectedValue) {
        return normalizeValue(currentValue) == normalizeValue(expectedValue);
    }

    private static String normalizeValue(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        return value.toLowerCase().replaceAll('[^a-z0-9]+', '');
    }

}