public without sharing class KenExamEnrollmentController {
    private static final String ENROLLMENT_STATUS_ENROLLED = 'Enrolled';
    
    public class ExamEnrollmentResponseDTO {
        @AuraEnabled public String currentSemesterLabel;
        @AuraEnabled public String currentSemesterValue;
        @AuraEnabled public String message;
        @AuraEnabled public List<ExamRowDTO> rows = new List<ExamRowDTO>();
    }
    
    public class MyExamScheduleResponseDTO {
        @AuraEnabled public String currentSemesterLabel;
        @AuraEnabled public String currentSemesterValue;
        @AuraEnabled public Date enrollmentLastDate;
        @AuraEnabled public String message;
        @AuraEnabled public List<MyExamScheduleRowDTO> rows =
        new List<MyExamScheduleRowDTO>();
    }
    
    public class ExamRowDTO {
        @AuraEnabled public Id personExaminationId;
        @AuraEnabled public String rowKey;
        @AuraEnabled public String courseName;
        @AuraEnabled public String courseCode;
        @AuraEnabled public String exam;
        @AuraEnabled public Decimal credits;
        @AuraEnabled public String format;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean eligible;
        @AuraEnabled public String eligibilityLabel;
        @AuraEnabled public String enrollmentStatus;
        @AuraEnabled public String sessionName;
        @AuraEnabled public Datetime examinationDate;
    }
    
    public class MyExamScheduleRowDTO {
        @AuraEnabled public Id personExaminationId;
        @AuraEnabled public String rowKey;
        @AuraEnabled public String courseName;
        @AuraEnabled public String courseCode;
        @AuraEnabled public String exam;
        @AuraEnabled public Decimal credits;
        @AuraEnabled public String format;
        @AuraEnabled public String type;
        @AuraEnabled public Datetime examinationDateTime;
        @AuraEnabled public String venue;
        @AuraEnabled public String status;
    }
    
    private class LearnerContext {
        private Id contactId;
        private Id accountId;
    }
    
    @AuraEnabled
    public static ExamEnrollmentResponseDTO fetchCurrentSemesterExaminations() {
        try {
            ExamEnrollmentResponseDTO response = new ExamEnrollmentResponseDTO();
            LearnerContext learnerContext = resolveLearnerContext();
            if (learnerContext == null || learnerContext.contactId == null) {
                response.message = 'No learner contact is associated with the current user.';
                return response;
            }
            
            LearnerProgram currentProgram = getCurrentLearnerProgram(
                learnerContext.contactId,
            learnerContext.accountId
                );
            if (currentProgram == null) {
                response.message = 'No learner program was found for the current student.';
                return response;
            }
            
            response.currentSemesterLabel = firstNonBlank(
                (String) currentProgram.get('Cadence_Period__c'),
            (String) currentProgram.get('Cadence_Type__c')
                );
            response.currentSemesterValue = normalizeSemesterValue(
                response.currentSemesterLabel
                );
            
            if (String.isBlank(response.currentSemesterLabel)) {
                response.message =
                    'The current semester is not available on the learner program.';
                return response;
            }
            
            response.rows = getMatchingPersonExaminations(
                learnerContext.contactId,
            response.currentSemesterLabel,
            response.currentSemesterValue
                );
            
            if (response.rows.isEmpty()) {
                response.message =
                    'No person examination records were found for the current semester.';
            }
            
            return response;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to load exam enrollments: ' +
                (e == null ? 'Unknown error' : e.getMessage())
                );
        }
    }
    
    @AuraEnabled
    public static MyExamScheduleResponseDTO fetchEnrolledMyExams() {
        try {
            MyExamScheduleResponseDTO response = new MyExamScheduleResponseDTO();
            LearnerContext learnerContext = resolveLearnerContext();
            if (learnerContext == null || learnerContext.contactId == null) {
                response.message = 'No learner contact is associated with the current user.';
                return response;
            }
            
            LearnerProgram currentProgram = getCurrentLearnerProgram(
                learnerContext.contactId,
            learnerContext.accountId
                );
            if (currentProgram != null) {
                response.currentSemesterLabel = firstNonBlank(
                    (String) currentProgram.get('Cadence_Period__c'),
                (String) currentProgram.get('Cadence_Type__c')
                    );
                response.currentSemesterValue = normalizeSemesterValue(
                    response.currentSemesterLabel
                    );
                response.enrollmentLastDate = getEnrollmentLastDateForCurrentSemester(
                    response.currentSemesterLabel,
                response.currentSemesterValue
                    );
            }
            
            Id contactId = learnerContext.contactId;
            for (SObject personExam : Database.query(
                buildEnrolledMyExamsQuery()
            )) {
                MyExamScheduleRowDTO row = new MyExamScheduleRowDTO();
                row.personExaminationId = (Id) personExam.get('Id');
                row.rowKey = String.valueOf(row.personExaminationId);
                SObject participant =
                    personExam.getSObject('Ken_Course_Offering_Participant__r');
                SObject offering =
                    participant == null ? null : participant.getSObject('CourseOffering');
                SObject learningCourse =
                    offering == null ? null : offering.getSObject('LearningCourse');
                SObject session =
                    offering == null ? null : offering.getSObject('AcademicSession');
                SObject examination = personExam.getSObject('Examination');

                if (
                    String.isNotBlank(response.currentSemesterLabel) &&
                    !matchesSemester(
                        session,
                        response.currentSemesterLabel,
                        response.currentSemesterValue
                    )
                ) {
                    continue;
                }

                row.courseName = firstNonBlank(
                    (String) personExam.get('Ken_Course_Name__c'),
                    offering == null ? null : (String) offering.get('Name')
                );
                row.courseCode = learningCourse == null
                    ? null
                    : (String) learningCourse.get('CourseNumber');
                row.exam = (String) personExam.get('Ken_Assessment__c');
                row.credits = getFirstDecimal(
                    offering == null ? null : offering.get('Credit__c'),
                    offering == null ? null : offering.get('Credit_Hours__c')
                );
                row.format = examination == null
                    ? null
                    : (String) examination.get('Ken_Format__c');
                row.type = firstNonBlank(
                    getCourseOfferingExamType(offering),
                    '-'
                );
                row.examinationDateTime =
                    examination == null
                    ? (Datetime) personExam.get('ExaminationDate')
                    : (Datetime) examination.get('Ken_Exam_Start_Date_Time__c');
                row.venue = null;
                row.status = (String) personExam.get('Ken_Enrollment_Status__c');
                response.rows.add(row);
            }
            
            if (response.rows.isEmpty()) {
                response.message =
                    'No enrolled person examination records were found for the current user.';
            }
            return response;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to load my exams: ' +
                (e == null ? 'Unknown error' : e.getMessage())
                );
        }
    }
    
    @AuraEnabled
    public static void enrollPersonExaminations(List<Id> personExaminationIds) {
        try {
            if (personExaminationIds == null || personExaminationIds.isEmpty()) {
                return;
            }
            
            LearnerContext learnerContext = resolveLearnerContext();
            if (learnerContext == null || learnerContext.contactId == null) {
                throw new AuraHandledException(
                    'No learner contact is associated with the current user.'
                    );
            }
            
            List<PersonExamination> rowsToUpdate = new List<PersonExamination>();
            for (PersonExamination personExam : [
                SELECT Id, ContactId, Ken_Enrollment_Status__c
                FROM PersonExamination
                WHERE Id IN :personExaminationIds
                AND ContactId = :learnerContext.contactId
            ]) {
                if (personExam.Ken_Enrollment_Status__c == ENROLLMENT_STATUS_ENROLLED) {
                    continue;
                }
                personExam.Ken_Enrollment_Status__c = ENROLLMENT_STATUS_ENROLLED;
                rowsToUpdate.add(personExam);
            }
            
            if (!rowsToUpdate.isEmpty()) {
                update rowsToUpdate;
            }
        } catch (AuraHandledException handledException) {
            throw handledException;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to enroll examinations: ' +
                (e == null ? 'Unknown error' : e.getMessage())
                );
        }
    }
    
    private static LearnerContext resolveLearnerContext() {
        List<User> users = [
            SELECT Id, ContactId, AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (users.isEmpty()) {
            return null;
        }
        
        User currentUser = users[0];
        LearnerContext learnerContext = new LearnerContext();
        learnerContext.contactId = currentUser.ContactId;
        learnerContext.accountId = currentUser.AccountId;
        
        if (learnerContext.contactId == null && learnerContext.accountId != null) {
            List<Account> accounts = [
                SELECT Id, PersonContactId
                FROM Account
                WHERE Id = :learnerContext.accountId
                LIMIT 1
            ];
            if (!accounts.isEmpty()) {
                learnerContext.contactId = accounts[0].PersonContactId;
            }
        }
        
        if (learnerContext.accountId == null && learnerContext.contactId != null) {
            List<Contact> contacts = [
                SELECT Id, AccountId
                FROM Contact
                WHERE Id = :learnerContext.contactId
                LIMIT 1
            ];
            if (!contacts.isEmpty()) {
                learnerContext.accountId = contacts[0].AccountId;
            }
        }
        
        return learnerContext;
    }
    
    private static LearnerProgram getCurrentLearnerProgram(
        Id learnerContactId,
    Id learnerAccountId
    ) {
        List<LearnerProgram> programs = [
            SELECT Id,
                   Status,
                   Cadence_Type__c,
                   Cadence_Period__c,
                   LastModifiedDate
            FROM LearnerProgram
            WHERE LearnerContactId = :learnerContactId
               OR LearnerAccountId = :learnerAccountId
            ORDER BY LastModifiedDate DESC
            LIMIT 50
        ];
        
        LearnerProgram selectedProgram;
        Integer selectedRank;
        for (LearnerProgram currentProgram : programs) {
            Integer currentRank = getProgramStatusRank(currentProgram.Status);
            if (selectedProgram == null || currentRank < selectedRank) {
                selectedProgram = currentProgram;
                selectedRank = currentRank;
            }
        }
        return selectedProgram;
    }
    
    private static Integer getProgramStatusRank(String statusValue) {
        String normalizedStatus = normalizeSemesterValue(statusValue);
        if (normalizedStatus == 'active') {
            return 0;
        }
        if (
            normalizedStatus == 'current' ||
            normalizedStatus == 'enrolled' ||
            normalizedStatus == 'inprogress' ||
            normalizedStatus == 'ongoing'
        ) {
            return 1;
        }
        if (
            normalizedStatus == 'admitted' ||
            normalizedStatus == 'registered'
        ) {
            return 2;
        }
        if (
            normalizedStatus == 'completed' ||
            normalizedStatus == 'inactive' ||
            normalizedStatus == 'cancelled'
        ) {
            return 4;
        }
        return 3;
    }
    
    private static List<ExamRowDTO> getMatchingPersonExaminations(
        Id learnerContactId,
    String currentSemesterLabel,
    String currentSemesterValue
    ) {
        List<ExamRowDTO> rows = new List<ExamRowDTO>();
        if (learnerContactId == null) {
            return rows;
        }
        
        Map<String, Schema.SObjectField> personExamFields =
            PersonExamination.SObjectType.getDescribe().fields.getMap();
        Boolean hasEligibilityField = personExamFields.containsKey('Ken_Eligiblity__c');
        
        String queryString =
            'SELECT Id, Name, ExaminationDate, Ken_Course_Name__c, Ken_Assessment__c, Ken_Exam_Type__c, ' +
            'Ken_Enrollment_Status__c, ContactId, Ken_Course_Offering_Participant__c, ' +
            'Ken_Enrollment_Criteria__c, ' +
            'Ken_Course_Offering_Participant__r.CourseOfferingId, ' +
            'Ken_Course_Offering_Participant__r.CourseOffering.Name, ' +
            'Ken_Course_Offering_Participant__r.CourseOffering.Course_Type__c, ' +
            'Ken_Course_Offering_Participant__r.CourseOffering.Credit__c, ' +
            'Ken_Course_Offering_Participant__r.CourseOffering.Credit_Hours__c, ' +
            'Ken_Course_Offering_Participant__r.CourseOffering.LearningCourse.CourseNumber, ' +
            'Ken_Course_Offering_Participant__r.CourseOffering.AcademicSessionId, ' +
            'Ken_Course_Offering_Participant__r.CourseOffering.AcademicSession.Name, ' +
            'Ken_Course_Offering_Participant__r.CourseOffering.AcademicSession.Type, ' +
            'Ken_Course_Offering_Participant__r.CourseOffering.AcademicSession.Cadence_Period__c, ' +
            'Ken_Enrollment_Criteria__r.Ken_Fee_Criteria__c';

        queryString += buildCourseOfferingExamTypeSelect(
            'Ken_Course_Offering_Participant__r.CourseOffering.'
        );
        
        if (hasEligibilityField) {
            queryString += ', Ken_Eligiblity__c';
        }
        
        queryString +=
            ' FROM PersonExamination ' +
            'WHERE ContactId = :learnerContactId ' +
            'AND Ken_Course_Offering_Participant__c != null ' +
            'AND (Ken_Enrollment_Status__c = null OR Ken_Enrollment_Status__c != :ENROLLMENT_STATUS_ENROLLED) ' +
            'ORDER BY ExaminationDate ASC, LastModifiedDate DESC';
        
        for (SObject examRecord : Database.query(queryString)) {
            SObject participant =
                examRecord.getSObject('Ken_Course_Offering_Participant__r');
            SObject offering =
                participant == null ? null : participant.getSObject('CourseOffering');
            SObject session =
                offering == null ? null : offering.getSObject('AcademicSession');
            if (!matchesSemester(session, currentSemesterLabel, currentSemesterValue)) {
                continue;
            }
            if (examRecord.get('Ken_Enrollment_Criteria__c') == null) {
                continue;
            }
            
            Object eligibilityValue =
                hasEligibilityField ? examRecord.get('Ken_Eligiblity__c') : null;
            Boolean isEligible = hasEligibilityField
                ? toEligibilityBoolean(eligibilityValue)
                : false;
            
            ExamRowDTO row = new ExamRowDTO();
            row.personExaminationId = (Id) examRecord.get('Id');
            row.rowKey = String.valueOf(row.personExaminationId);
            row.courseName = firstNonBlank(
                (String) examRecord.get('Ken_Course_Name__c'),
            offering == null ? null : (String) offering.get('Name'),
            (String) examRecord.get('Name')
                );
            
            SObject learningCourse =
                offering == null ? null : offering.getSObject('LearningCourse');
            row.courseCode = learningCourse == null
                ? null
                : (String) learningCourse.get('CourseNumber');
            row.exam = firstNonBlank(
                (String) examRecord.get('Ken_Assessment__c'),
                (String) examRecord.get('Name')
            );
            row.credits = getFirstDecimal(
                offering == null ? null : offering.get('Credit__c'),
            offering == null ? null : offering.get('Credit_Hours__c')
                );
            row.format = offering == null
                ? null
                : (String) offering.get('Course_Type__c');
            row.enrollmentStatus =
                (String) examRecord.get('Ken_Enrollment_Status__c');
            row.type = firstNonBlank(
                getCourseOfferingExamType(offering),
                '-'
            );
            row.eligible = isEligible;
            row.eligibilityLabel = hasEligibilityField
                ? deriveEligibilityLabel(eligibilityValue, isEligible)
                : null;
            row.sessionName =
                session == null ? null : (String) session.get('Name');
            row.examinationDate = (Datetime) examRecord.get('ExaminationDate');
            rows.add(row);
        }
        
        return rows;
    }
    
    private static Boolean matchesSemester(
        SObject session,
    String currentSemesterLabel,
    String currentSemesterValue
    ) {
        if (session == null) {
            return false;
        }
        
        String sessionCadencePeriod = (String) session.get('Cadence_Period__c');
        String sessionType = (String) session.get('Type');
        String normalizedSessionPeriod = normalizeSemesterValue(sessionCadencePeriod);
        String normalizedSessionType = normalizeSemesterValue(sessionType);
        String normalizedCurrentLabel = normalizeSemesterValue(currentSemesterLabel);
        String currentDigits = extractDigits(currentSemesterLabel);
        String sessionDigits = extractDigits(sessionCadencePeriod);
        
        if (
            !String.isBlank(currentSemesterValue) &&
            normalizedSessionPeriod == currentSemesterValue
        ) {
            return true;
        }
        
        if (
            !String.isBlank(normalizedCurrentLabel) &&
            normalizedSessionPeriod == normalizedCurrentLabel
        ) {
            return true;
        }
        
        if (
            !String.isBlank(currentDigits) &&
            currentDigits == sessionDigits &&
            (
            normalizedSessionType == 'semester' ||
            normalizedCurrentLabel.contains('semester') ||
            currentSemesterValue.contains('semester')
            )
        ) {
            return true;
        }
        
        return
            String.isNotBlank(normalizedCurrentLabel) &&
            String.isBlank(currentDigits) &&
            normalizedSessionType == normalizedCurrentLabel;
    }
    
    private static Date getEnrollmentLastDateForCurrentSemester(
        String currentSemesterLabel,
    String currentSemesterValue
    ) {
        for (AcademicSession session : [
            SELECT Id, Type, Cadence_Period__c, Ken_Last_Date_To_Enroll__c, IsActive
            FROM AcademicSession
            WHERE IsActive = true
            AND Ken_Last_Date_To_Enroll__c != null
            ORDER BY LastModifiedDate DESC
        ]) {
            if (matchesSemester(session, currentSemesterLabel, currentSemesterValue)) {
                return session.Ken_Last_Date_To_Enroll__c;
            }
        }
        return null;
    }
    
    private static Decimal getFirstDecimal(Object firstValue, Object secondValue) {
        if (firstValue instanceof Decimal) {
            return (Decimal) firstValue;
        }
        if (secondValue instanceof Decimal) {
            return (Decimal) secondValue;
        }
        if (firstValue instanceof Integer) {
            return Decimal.valueOf(String.valueOf(firstValue));
        }
        if (secondValue instanceof Integer) {
            return Decimal.valueOf(String.valueOf(secondValue));
        }
        return null;
    }
    
    private static Boolean toEligibilityBoolean(Object eligibilityValue) {
        if (eligibilityValue == null) {
            return false;
        }
        if (eligibilityValue instanceof Boolean) {
            return (Boolean) eligibilityValue;
        }
        
        String normalizedValue = normalizeSemesterValue(String.valueOf(eligibilityValue));
        return !(
            String.isBlank(normalizedValue) ||
            normalizedValue == 'false' ||
            normalizedValue == 'noteligible' ||
            normalizedValue == 'ineligible' ||
            normalizedValue == 'no' ||
            normalizedValue == 'n' ||
            normalizedValue == '0'
            );
    }
    
    private static String deriveEligibilityLabel(
        Object eligibilityValue,
    Boolean isEligible
    ) {
        if (eligibilityValue != null && !(eligibilityValue instanceof Boolean)) {
            return String.valueOf(eligibilityValue);
        }
        return isEligible ? 'Eligible' : 'Not Eligible';
    }
    
    private static String firstNonBlank(String firstValue, String secondValue) {
        return firstNonBlank(firstValue, secondValue, null);
    }
    
    private static String firstNonBlank(
        String firstValue,
    String secondValue,
    String thirdValue
    ) {
        if (String.isNotBlank(firstValue)) {
            return firstValue;
        }
        if (String.isNotBlank(secondValue)) {
            return secondValue;
        }
        return thirdValue;
    }

    private static String buildEnrolledMyExamsQuery() {
        String queryString =
            'SELECT Id, ' +
            'Ken_Course_Name__c, ' +
            'Ken_Assessment__c, ' +
            'Ken_Enrollment_Status__c, ' +
            'ExaminationDate, ' +
            'Examination.Ken_Exam_Start_Date_Time__c, ' +
            'Examination.Ken_Format__c, ' +
            'Ken_Course_Offering_Participant__r.CourseOffering.Name, ' +
            'Ken_Course_Offering_Participant__r.CourseOffering.Credit__c, ' +
            'Ken_Course_Offering_Participant__r.CourseOffering.Credit_Hours__c, ' +
            'Ken_Course_Offering_Participant__r.CourseOffering.LearningCourse.CourseNumber, ' +
            'Ken_Course_Offering_Participant__r.CourseOffering.AcademicSession.Name, ' +
            'Ken_Course_Offering_Participant__r.CourseOffering.AcademicSession.Type, ' +
            'Ken_Course_Offering_Participant__r.CourseOffering.AcademicSession.Cadence_Period__c';

        queryString += buildCourseOfferingExamTypeSelect(
            'Ken_Course_Offering_Participant__r.CourseOffering.'
        );

        queryString +=
            ' FROM PersonExamination ' +
            'WHERE ContactId = :contactId ' +
            'AND Ken_Enrollment_Status__c = :ENROLLMENT_STATUS_ENROLLED ' +
            'AND Ken_Course_Offering_Participant__c != null ' +
            'ORDER BY Examination.Ken_Exam_Start_Date_Time__c ASC NULLS LAST, ' +
            'ExaminationDate ASC NULLS LAST, ' +
            'LastModifiedDate DESC';

        return queryString;
    }

    private static String buildCourseOfferingExamTypeSelect(String relationshipPrefix) {
        Map<String, Schema.SObjectField> offeringFields =
            CourseOffering.SObjectType.getDescribe().fields.getMap();
        String selectFields = '';
        if (offeringFields.containsKey('Exam_Type__c')) {
            selectFields += ', ' + relationshipPrefix + 'Exam_Type__c';
        }
        if (offeringFields.containsKey('Ken_Exam_Type__c')) {
            selectFields += ', ' + relationshipPrefix + 'Ken_Exam_Type__c';
        }
        return selectFields;
    }

    private static String getCourseOfferingExamType(SObject offering) {
        if (offering == null) {
            return null;
        }

        Map<String, Schema.SObjectField> offeringFields =
            CourseOffering.SObjectType.getDescribe().fields.getMap();
        if (offeringFields.containsKey('Exam_Type__c')) {
            String examType = (String) offering.get('Exam_Type__c');
            if (String.isNotBlank(examType)) {
                return examType;
            }
        }
        if (offeringFields.containsKey('Ken_Exam_Type__c')) {
            String examType = (String) offering.get('Ken_Exam_Type__c');
            if (String.isNotBlank(examType)) {
                return examType;
            }
        }
        return null;
    }
    
    private static String normalizeSemesterValue(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        return value.toLowerCase().replaceAll('[^a-z0-9]+', '');
    }
    
    private static String extractDigits(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        return value.replaceAll('[^0-9]+', '');
    }
}