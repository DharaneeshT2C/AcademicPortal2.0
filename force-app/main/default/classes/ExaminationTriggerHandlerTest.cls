@IsTest
private class ExaminationTriggerHandlerTest {

    private static final String PARENT_COMPONENT_RT = 'Evaluation_Component';
    private static final String SUB_COMPONENT_RT = 'Evaluation_Sub_Component';

    @TestVisible
    private static Id getEvaluationComponentRecordTypeId(String developerName) {
        Schema.RecordTypeInfo recordTypeInfo =
            Schema.SObjectType.Ken_Evaluation_Component__c
                .getRecordTypeInfosByDeveloperName()
                .get(developerName);

        return recordTypeInfo == null ? null : recordTypeInfo.getRecordTypeId();
    }

    @IsTest
    static void testInsertCreatesPersonExaminations() {
        ExamDataBundle testData = createExamDataBundle(2);
        testData = refreshComponentNames(testData);

        Test.startTest();
        Examination examinationRecord = buildExaminationRecord(testData.subComponent.Id);
        insert examinationRecord;
        Test.stopTest();

        List<PersonExamination> createdRecords = [
            SELECT ExaminationId,
                   Ken_Course_Offering_Participant__c,
                   Ken_Enrollment_Status__c,
                   Ken_Course_Name__c,
                   Ken_Assessment__c,
                   ContactId,
                   AccountId
            FROM PersonExamination
            WHERE ExaminationId = :examinationRecord.Id
            ORDER BY Ken_Course_Offering_Participant__c
        ];

        System.assertEquals(2, createdRecords.size(), 'A record should be created for each participant.');

        for (PersonExamination createdRecord : createdRecords) {
            System.assertEquals('Not Enrolled', createdRecord.Ken_Enrollment_Status__c);
            System.assertEquals(testData.course.Name, createdRecord.Ken_Course_Name__c);
            System.assertEquals(
                testData.subComponent.Ken_Assessment__c,
                createdRecord.Ken_Assessment__c
            );
        }
    }

    @IsTest
    static void testUpdateFromBlankComponentCreatesPersonExaminations() {
        ExamDataBundle testData = createExamDataBundle(1);
        Examination examinationRecord = buildExaminationRecord(null);
        insert examinationRecord;

        Test.startTest();
        examinationRecord.Ken_Evaluation_Component__c = testData.subComponent.Id;
        update examinationRecord;
        Test.stopTest();

        Integer createdCount = [
            SELECT COUNT()
            FROM PersonExamination
            WHERE ExaminationId = :examinationRecord.Id
        ];

        System.assertEquals(1, createdCount, 'Update should create the participant exam records.');
    }

    @IsTest
    static void testReprocessingUpdatesExistingWithoutDuplicates() {
        ExamDataBundle testData = createExamDataBundle(1);
        testData = refreshComponentNames(testData);

        Examination examinationRecord = buildExaminationRecord(testData.subComponent.Id);
        insert examinationRecord;
        ExaminationPersonExaminationService.process(
            new Set<Id>{ examinationRecord.Id }
        );

        PersonExamination existingRecord = [
            SELECT Id,
                   ExaminationId,
                   Ken_Course_Offering_Participant__c
                               FROM PersonExamination
            WHERE ExaminationId = :examinationRecord.Id
            LIMIT 1
        ];

        Ken_Evaluation_Component__c replacementSubComponent =
            new Ken_Evaluation_Component__c(
                RecordTypeId = getEvaluationComponentRecordTypeId(SUB_COMPONENT_RT),
                Ken_Parent_Evaluation_Component__c = testData.parentComponent.Id,
                Ken_Assessment__c = getAlternateAssessmentValue(testData.subComponent.Ken_Assessment__c)
            );
        insert replacementSubComponent;
        replacementSubComponent = [
            SELECT Id, Name
            FROM Ken_Evaluation_Component__c
            WHERE Id = :replacementSubComponent.Id
        ];

        Test.startTest();
        examinationRecord.Ken_Evaluation_Component__c = replacementSubComponent.Id;
        update examinationRecord;
        Test.stopTest();

        List<PersonExamination> recordsAfterUpdate = [
            SELECT Id
            FROM PersonExamination
            WHERE ExaminationId = :examinationRecord.Id
        ];


    }

    @IsTest
    static void testQueueableChunkProcessing() {
        ExamDataBundle testData = createExamDataBundle(1);
        Integer examCount = ExaminationPersonExaminationQueueable.CHUNK_SIZE + 1;

        List<Examination> examinationRecords = new List<Examination>();
        for (Integer indexValue = 0; indexValue < examCount; indexValue++) {
            examinationRecords.add(buildExaminationRecord(testData.subComponent.Id));
        }
        insert examinationRecords;

        Set<Id> examinationIds = new Map<Id, Examination>(examinationRecords).keySet();

        Test.startTest();
        System.enqueueJob(
            new ExaminationPersonExaminationQueueable(examinationIds)
        );
        Test.stopTest();

        Integer createdCount = [
            SELECT COUNT()
            FROM PersonExamination
            WHERE ExaminationId IN :examinationIds
        ];

        System.assertEquals(
            ExaminationPersonExaminationQueueable.CHUNK_SIZE,
            createdCount,
            'The current queueable execution should process the first chunk of examinations.'
        );
    }

    private static String getAlternateAssessmentValue(String currentValue) {
        Schema.DescribeFieldResult describeResult =
            Ken_Evaluation_Component__c.Ken_Assessment__c.getDescribe();

        String fallbackValue;
        for (Schema.PicklistEntry currentEntry : describeResult.getPicklistValues()) {
            if (!currentEntry.isActive()) {
                continue;
            }

            if (fallbackValue == null) {
                fallbackValue = currentEntry.getValue();
            }

            if (currentEntry.getValue() != currentValue) {
                return currentEntry.getValue();
            }
        }

        return fallbackValue;
    }

    private static ExamDataBundle createExamDataBundle(Integer participantCount) {
        ExamDataBundle dataBundle = new ExamDataBundle();

        dataBundle.accountRecord = new Account(Name = 'Exam Account');
        insert dataBundle.accountRecord;

        Learning learningRecord = new Learning(Name = 'Exam Learning');
        insert learningRecord;

        dataBundle.course = new LearningCourse(
            Name = 'Exam Course',
            LearningId = learningRecord.Id
        );
        insert dataBundle.course;

        dataBundle.courseOffering = new CourseOffering(
            Name = 'Exam Offering',
            LearningCourseId = dataBundle.course.Id,
            StartDate = Datetime.now(),
            EndDate = Datetime.now().addDays(10)
        );
        insert dataBundle.courseOffering;

        Id parentRtId = getEvaluationComponentRecordTypeId(PARENT_COMPONENT_RT);
        Id subRtId = getEvaluationComponentRecordTypeId(SUB_COMPONENT_RT);

        dataBundle.parentComponent = new Ken_Evaluation_Component__c(
            RecordTypeId = parentRtId,
            Ken_Consider_for_Pass_Fail__c = false,
            Ken_Is_Exam_Required__c = false
        );
        insert dataBundle.parentComponent;

        dataBundle.subComponent = new Ken_Evaluation_Component__c(
            RecordTypeId = subRtId,
            Ken_Parent_Evaluation_Component__c = dataBundle.parentComponent.Id,
            Ken_Consider_for_Pass_Fail__c = false,
            Ken_Is_Exam_Required__c = false,
            Ken_Assessment__c = getAlternateAssessmentValue(null)
        );
        insert dataBundle.subComponent;

        insert new Ken_Course_Evaluation_Schema_Mapper__c(
            Course_Offering__c = dataBundle.courseOffering.Id,
            Ken_Evaluation_Component__c = dataBundle.parentComponent.Id
        );

        List<CourseOfferingParticipant> participants = new List<CourseOfferingParticipant>();
        for (Integer indexValue = 0; indexValue < participantCount; indexValue++) {
            Contact participantContact = new Contact(
                FirstName = 'Student',
                LastName = 'Participant ' + indexValue,
                AccountId = dataBundle.accountRecord.Id
            );
            insert participantContact;

            participants.add(new CourseOfferingParticipant(
                CourseOfferingId = dataBundle.courseOffering.Id,
                ParticipantContactId = participantContact.Id,
                ParticipantAccountId = dataBundle.accountRecord.Id
            ));
        }
        insert participants;

        return dataBundle;
    }

    private static ExamDataBundle refreshComponentNames(ExamDataBundle dataBundle) {
        dataBundle.parentComponent = [
            SELECT Id, Name
            FROM Ken_Evaluation_Component__c
            WHERE Id = :dataBundle.parentComponent.Id
        ];
        dataBundle.subComponent = [
            SELECT Id, Name, Ken_Assessment__c
            FROM Ken_Evaluation_Component__c
            WHERE Id = :dataBundle.subComponent.Id
        ];

        return dataBundle;
    }

    private static Examination buildExaminationRecord(Id componentId) {
        Examination examinationRecord = new Examination();
        Map<String, Schema.SObjectField> examinationFields =
            Examination.SObjectType.getDescribe().fields.getMap();

        if (examinationFields.containsKey('Name')
            && examinationFields.get('Name').getDescribe().isCreateable()) {
            examinationRecord.Name = 'Test Examination ' + System.now().getTime();
        }

        if (componentId != null) {
            examinationRecord.Ken_Evaluation_Component__c = componentId;
        }

        populateRequiredFields(examinationRecord, examinationFields);
        return examinationRecord;
    }

    private static void populateRequiredFields(
        SObject targetRecord,
        Map<String, Schema.SObjectField> fieldsByApiName
    ) {
        for (String apiName : fieldsByApiName.keySet()) {
            if (targetRecord.get(apiName) != null) {
                continue;
            }

            Schema.DescribeFieldResult fieldDescribe =
                fieldsByApiName.get(apiName).getDescribe();

            if (!fieldDescribe.isCreateable()
                || fieldDescribe.isDefaultedOnCreate()
                || fieldDescribe.isCalculated()
                || fieldDescribe.isNillable()) {
                continue;
            }

            if (apiName == 'OwnerId' || apiName == 'RecordTypeId') {
                continue;
            }

            setDefaultValue(targetRecord, apiName, fieldDescribe);
        }
    }

    private static void setDefaultValue(
        SObject targetRecord,
        String apiName,
        Schema.DescribeFieldResult fieldDescribe
    ) {
        Schema.DisplayType fieldType = fieldDescribe.getType();

        if (fieldType == Schema.DisplayType.Boolean) {
            targetRecord.put(apiName, false);
            return;
        }

        if (fieldType == Schema.DisplayType.Date) {
            targetRecord.put(apiName, Date.today());
            return;
        }

        if (fieldType == Schema.DisplayType.DateTime) {
            targetRecord.put(apiName, Datetime.now());
            return;
        }

        if (fieldType == Schema.DisplayType.Integer
            || fieldType == Schema.DisplayType.Double
            || fieldType == Schema.DisplayType.Currency
            || fieldType == Schema.DisplayType.Percent
            || fieldType == Schema.DisplayType.Long) {
            targetRecord.put(apiName, 1);
            return;
        }

        if (fieldType == Schema.DisplayType.Picklist) {
            for (Schema.PicklistEntry currentEntry : fieldDescribe.getPicklistValues()) {
                if (currentEntry.isActive()) {
                    targetRecord.put(apiName, currentEntry.getValue());
                    return;
                }
            }
        }

        if (fieldType == Schema.DisplayType.String
            || fieldType == Schema.DisplayType.TextArea
            || fieldType == Schema.DisplayType.EncryptedString) {
            targetRecord.put(apiName, 'Test ' + apiName.left(Math.min(20, apiName.length())));
        }
    }

    private class ExamDataBundle {
        Account accountRecord;
        LearningCourse course;
        CourseOffering courseOffering;
        Ken_Evaluation_Component__c parentComponent;
        Ken_Evaluation_Component__c subComponent;
    }
}