@suppressWarnings('PMD.StdCyclomaticComplexity,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssMethodCount,PMD.ExcessiveParameterList')
public without sharing class ExamCourseResultImportBatch implements Database.Batchable<Map<String, Object>>, Database.Stateful {
    private static final String PROCESS_NAME = 'Exam Course Result Import';
    private static final String SOURCE_NAME = 'Class:ExamCourseResultImportBatch';
    private static final String RECORDTYPE_ACTIVITY_GRADE_COMPONENT = 'Componnet';

    private static final String COMPONENT_INTERNAL = 'Internal';
    private static final String COMPONENT_EXTERNAL = 'External';
    private static final String COMPONENT_RETEST = 'Re-Test';
    private static final String COMPONENT_SUPPLEMENTARY = 'Supplementary';
    private static final String EXAM_TYPE_REGULAR = 'Regular';
    private static final String EXAM_TYPE_RETEST = 'Retest';

    private final String jsonRows;
    private final Id examCycleId;
    private List<Audit_Log__c> pendingLogs = new List<Audit_Log__c>();

    private class StudentContext {
        Id contactId;
        Id accountId;
    }

    private class ComponentCandidate {
        Id evaluationComponentId;
        String componentName;
        String examType;
    }

    public ExamCourseResultImportBatch(String jsonRows, Id examCycleId) {
        this.jsonRows = jsonRows;
        this.examCycleId = examCycleId;
    }

    public Iterable<Map<String, Object>> start(Database.BatchableContext bc) {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        if (String.isBlank(jsonRows)) {
            return rows;
        }
        for (Object row : (List<Object>) JSON.deserializeUntyped(jsonRows)) {
            if (row instanceof Map<String, Object>) {
                rows.add((Map<String, Object>) row);
            }
        }
        return rows;
    }

    public void execute(Database.BatchableContext bc, List<Map<String, Object>> scope) {
        Id jobId = bc == null ? null : bc.getJobId();
        if (scope == null || scope.isEmpty()) {
            return;
        }

        Id academicTermId = resolveAcademicTermId(jobId);
        if (academicTermId == null) {
            flushAuditLogs();
            return;
        }

        Map<String, Schema.SObjectField> roleFields = ConstituentRole.SObjectType.getDescribe().fields.getMap();
        Boolean hasRoleStudentId = roleFields.containsKey('Student_ID__c');

        Set<String> studentIds = new Set<String>();
        Set<String> courseCodes = new Set<String>();
        for (Map<String, Object> row : scope) {
            addTrimmed(studentIds, getRowValue(row, 'Student Registration ID'));
            addTrimmed(courseCodes, getRowValue(row, 'Course Code'));
        }

        Map<String, StudentContext> studentByRegistrationId = getStudentsByRegistrationId(studentIds, hasRoleStudentId);
        Map<Id, AcademicTermEnrollment> ateByContactId = getAcademicTermEnrollments(studentByRegistrationId.values(), academicTermId);
        Map<String, List<CourseOfferingParticipant>> copByAteAndCode = getParticipantsByAteAndCode(ateByContactId.values(), courseCodes);
        Map<Id, List<ComponentCandidate>> componentsByOfferingId = getComponentsByOfferingId(collectOfferingIds(copByAteAndCode));

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        Schema.SObjectType activityGradeType = gd.get('CourseOfrPtcpActvtyGrd');
        Map<String, Schema.SObjectField> activityGradeFields = activityGradeType == null
            ? new Map<String, Schema.SObjectField>()
            : activityGradeType.getDescribe().fields.getMap();
        Id activityGradeRecordTypeId = resolveActivityGradeComponentRecordTypeId(activityGradeType);
        Map<String, Schema.SObjectField> resultFields = CourseOfferingPtcpResult.SObjectType.getDescribe().fields.getMap();

        List<SObject> gradesToInsert = new List<SObject>();
        List<CourseOfferingPtcpResult> resultsToInsert = new List<CourseOfferingPtcpResult>();

        for (Integer i = 0; i < scope.size(); i++) {
            Map<String, Object> row = scope[i];
            String rowNumber = getRowNumber(i, scope);

            String studentRegistrationId = getRowValue(row, 'Student Registration ID');
            String courseCode = getRowValue(row, 'Course Code');
            Decimal courseCredit = toDecimal(getRowValue(row, 'Course Credit'));
            if (String.isBlank(studentRegistrationId)) {
                writeAuditLog('Row ' + rowNumber + ': Student Registration ID is required.', jobId);
                continue;
            }
            if (String.isBlank(courseCode)) {
                writeAuditLog('Row ' + rowNumber + ': Course Code is required.', jobId);
                continue;
            }

            StudentContext student = studentByRegistrationId.get(normalizeKey(studentRegistrationId));
            if (student == null || student.contactId == null) {
                writeAuditLog('Row ' + rowNumber + ': Student was not found for Student Registration ID "' + studentRegistrationId + '".', jobId);
                continue;
            }

            AcademicTermEnrollment ate = ateByContactId.get(student.contactId);
            if (ate == null) {
                writeAuditLog('Row ' + rowNumber + ': Academic Term Enrollment was not found for Student Registration ID "' + studentRegistrationId + '" in the selected Exam Cycle term.', jobId);
                continue;
            }

            List<CourseOfferingParticipant> candidates = copByAteAndCode.get(buildAteCourseKey(ate.Id, courseCode));
            CourseOfferingParticipant matchedCop = pickParticipant(candidates, courseCredit);
            if (matchedCop == null) {
                writeAuditLog(
                    'Row ' + rowNumber + ': Course Offering Participant was not found for Student Registration ID "' +
                    studentRegistrationId + '", Course Code "' + courseCode + '"' +
                    (courseCredit == null ? '' : ', Course Credit "' + String.valueOf(courseCredit) + '"') + '.',
                    jobId
                );
                continue;
            }

            List<ComponentCandidate> offeringComponents = componentsByOfferingId.get(matchedCop.CourseOfferingId);
            appendActivityGrade(
                gradesToInsert,
                activityGradeType,
                activityGradeFields,
                activityGradeRecordTypeId,
                matchedCop,
                student,
                offeringComponents,
                getRowValue(row, 'Internal Total Marks'),
                COMPONENT_INTERNAL,
                EXAM_TYPE_REGULAR,
                rowNumber,
                'Internal Total Marks',
                jobId
            );
            appendActivityGrade(
                gradesToInsert,
                activityGradeType,
                activityGradeFields,
                activityGradeRecordTypeId,
                matchedCop,
                student,
                offeringComponents,
                getRowValue(row, 'External Total Mark'),
                COMPONENT_EXTERNAL,
                EXAM_TYPE_REGULAR,
                rowNumber,
                'External Total Mark',
                jobId
            );
            appendActivityGrade(
                gradesToInsert,
                activityGradeType,
                activityGradeFields,
                activityGradeRecordTypeId,
                matchedCop,
                student,
                offeringComponents,
                getRowValue(row, 'Revaluation Marks'),
                COMPONENT_RETEST,
                EXAM_TYPE_RETEST,
                rowNumber,
                'Revaluation Marks',
                jobId
            );
            appendActivityGrade(
                gradesToInsert,
                activityGradeType,
                activityGradeFields,
                activityGradeRecordTypeId,
                matchedCop,
                student,
                offeringComponents,
                getRowValue(row, 'Retest/Suply Marks'),
                COMPONENT_SUPPLEMENTARY,
                EXAM_TYPE_RETEST,
                rowNumber,
                'Retest/Suply Marks',
                jobId
            );

            CourseOfferingPtcpResult resultRecord = new CourseOfferingPtcpResult();
            putField(resultRecord, resultFields, 'CourseOfferingParticipantId', matchedCop.Id);
            putField(resultRecord, resultFields, 'UnitsEarned', courseCredit);
            putField(resultRecord, resultFields, 'LetterGrade', getRowValue(row, 'Grade'));
            putField(resultRecord, resultFields, 'NumericGrade', toDecimal(getRowValue(row, 'Grade Point')));
            resultsToInsert.add(resultRecord);

            if (String.isNotBlank(getRowValue(row, 'Total Marks'))) {
                writeAuditLog('Row ' + rowNumber + ': Total Marks does not have a mapped destination field in Course Offering Participant Result and was ignored.', jobId);
            }
        }

        insertRecords(gradesToInsert, 'Course Offering Participant Activity Grade', jobId);
        insertRecords(resultsToInsert, 'Course Offering Participant Result', jobId);
        flushAuditLogs();
    }

    public void finish(Database.BatchableContext bc) {}

    private Id resolveAcademicTermId(Id jobId) {
        if (examCycleId == null) {
            writeAuditLog('Exam Cycle is required for Exam Course Result Import.', jobId);
            return null;
        }
        List<SObject> rows = Database.query(
            'SELECT Id, Name, Ken_Academic_Term__c FROM Ken_Exam_Cycle__c WHERE Id = :examCycleId LIMIT 1'
        );
        if (rows.isEmpty()) {
            writeAuditLog('Exam Cycle not found for Id ' + examCycleId + '.', jobId);
            return null;
        }
        Id academicTermId = (Id) rows[0].get('Ken_Academic_Term__c');
        if (academicTermId == null) {
            writeAuditLog('Selected Exam Cycle is not linked to an Academic Term.', jobId);
        }
        return academicTermId;
    }

    private Map<String, StudentContext> getStudentsByRegistrationId(Set<String> studentIds, Boolean hasRoleStudentId) {
        Map<String, StudentContext> out = new Map<String, StudentContext>();
        if (studentIds == null || studentIds.isEmpty()) {
            return out;
        }

        if (hasRoleStudentId) {
            for (ConstituentRole roleRow : [
                SELECT Id, PersonId, Student_ID__c
                FROM ConstituentRole
                WHERE RoleType = :KenConstantController.ROLETYPE_STUDENT
                AND Student_ID__c IN :studentIds
            ]) {
                if (String.isBlank(roleRow.Student_ID__c) || roleRow.PersonId == null) {
                    continue;
                }
                StudentContext ctx = new StudentContext();
                ctx.contactId = roleRow.PersonId;
                out.put(normalizeKey(roleRow.Student_ID__c), ctx);
            }
        }

        if (out.size() == studentIds.size() || !Account.SObjectType.getDescribe().fields.getMap().containsKey('Student_ID__c')) {
            return out;
        }

        for (Account accountRow : Database.query(
            'SELECT Id, PersonContactId, Student_ID__c FROM Account WHERE IsPersonAccount = true AND Student_ID__c IN :studentIds'
        )) {
            String studentId = (String) accountRow.get('Student_ID__c');
            if (String.isBlank(studentId) || accountRow.PersonContactId == null) {
                continue;
            }
            if (!out.containsKey(normalizeKey(studentId))) {
                StudentContext ctx = new StudentContext();
                ctx.contactId = accountRow.PersonContactId;
                ctx.accountId = accountRow.Id;
                out.put(normalizeKey(studentId), ctx);
            }
        }
        return out;
    }

    private Map<Id, AcademicTermEnrollment> getAcademicTermEnrollments(Iterable<StudentContext> students, Id academicTermId) {
        Set<Id> contactIds = new Set<Id>();
        for (StudentContext student : students) {
            if (student != null && student.contactId != null) {
                contactIds.add(student.contactId);
            }
        }

        Map<Id, AcademicTermEnrollment> out = new Map<Id, AcademicTermEnrollment>();
        if (contactIds.isEmpty() || academicTermId == null) {
            return out;
        }

        for (AcademicTermEnrollment ate : [
            SELECT Id, LearnerContactId, LearnerAccountId
            FROM AcademicTermEnrollment
            WHERE AcademicTermId = :academicTermId
            AND LearnerContactId IN :contactIds
        ]) {
            out.put(ate.LearnerContactId, ate);
        }
        return out;
    }

    private Map<String, List<CourseOfferingParticipant>> getParticipantsByAteAndCode(
        Iterable<AcademicTermEnrollment> ates,
        Set<String> courseCodes
    ) {
        Set<Id> ateIds = new Set<Id>();
        for (AcademicTermEnrollment ate : ates) {
            if (ate != null && ate.Id != null) {
                ateIds.add(ate.Id);
            }
        }

        Map<String, List<CourseOfferingParticipant>> out = new Map<String, List<CourseOfferingParticipant>>();
        if (ateIds.isEmpty() || courseCodes == null || courseCodes.isEmpty()) {
            return out;
        }

        for (CourseOfferingParticipant cop : [
            SELECT Id, ParticipantContactId, ParticipantAccountId, AcademicTermEnrollmentId, CourseOfferingId,
                CourseOffering.Credit__c, CourseOffering.LearningCourse.CourseNumber
            FROM CourseOfferingParticipant
            WHERE AcademicTermEnrollmentId IN :ateIds
            AND CourseOffering.LearningCourse.CourseNumber IN :courseCodes
        ]) {
            if (cop.AcademicTermEnrollmentId == null ||
                cop.CourseOffering == null ||
                cop.CourseOffering.LearningCourse == null ||
                String.isBlank(cop.CourseOffering.LearningCourse.CourseNumber)) {
                continue;
            }
            String key = buildAteCourseKey(cop.AcademicTermEnrollmentId, cop.CourseOffering.LearningCourse.CourseNumber);
            if (!out.containsKey(key)) {
                out.put(key, new List<CourseOfferingParticipant>());
            }
            out.get(key).add(cop);
        }
        return out;
    }

    private static Set<Id> collectOfferingIds(Map<String, List<CourseOfferingParticipant>> participantsByKey) {
        Set<Id> offeringIds = new Set<Id>();
        if (participantsByKey == null) {
            return offeringIds;
        }
        for (List<CourseOfferingParticipant> participants : participantsByKey.values()) {
            for (CourseOfferingParticipant participant : participants) {
                if (participant != null && participant.CourseOfferingId != null) {
                    offeringIds.add(participant.CourseOfferingId);
                }
            }
        }
        return offeringIds;
    }

    private Map<Id, List<ComponentCandidate>> getComponentsByOfferingId(Set<Id> offeringIds) {
        Map<Id, List<ComponentCandidate>> out = new Map<Id, List<ComponentCandidate>>();
        if (offeringIds == null || offeringIds.isEmpty()) {
            return out;
        }
        for (SObject mapperRow : Database.query(
            'SELECT Course_Offering__c, Ken_Evaluation_Component__c, ' +
            'Ken_Evaluation_Component__r.Ken_Components__c, ' +
            'Ken_Evaluation_Component__r.Ken_Exam_Type__c ' +
            'FROM Ken_Course_Evaluation_Schema_Mapper__c ' +
            'WHERE Course_Offering__c IN :offeringIds'
        )) {
            Id offeringId = (Id) mapperRow.get('Course_Offering__c');
            SObject componentRow = mapperRow.getSObject('Ken_Evaluation_Component__r');
            if (offeringId == null || componentRow == null || mapperRow.get('Ken_Evaluation_Component__c') == null) {
                continue;
            }
            ComponentCandidate candidate = new ComponentCandidate();
            candidate.evaluationComponentId = (Id) mapperRow.get('Ken_Evaluation_Component__c');
            candidate.componentName = componentRow.get('Ken_Components__c') == null
                ? null
                : String.valueOf(componentRow.get('Ken_Components__c'));
            candidate.examType = componentRow.get('Ken_Exam_Type__c') == null
                ? null
                : String.valueOf(componentRow.get('Ken_Exam_Type__c'));
            if (!out.containsKey(offeringId)) {
                out.put(offeringId, new List<ComponentCandidate>());
            }
            out.get(offeringId).add(candidate);
        }
        return out;
    }

    private static Id resolveActivityGradeComponentRecordTypeId(Schema.SObjectType activityGradeType) {
        if (activityGradeType == null) {
            return null;
        }
        Map<String, Schema.RecordTypeInfo> byDeveloperName = activityGradeType.getDescribe().getRecordTypeInfosByDeveloperName();
        if (byDeveloperName != null && byDeveloperName.containsKey(RECORDTYPE_ACTIVITY_GRADE_COMPONENT)) {
            return byDeveloperName.get(RECORDTYPE_ACTIVITY_GRADE_COMPONENT).getRecordTypeId();
        }
        return null;
    }

    private static CourseOfferingParticipant pickParticipant(List<CourseOfferingParticipant> candidates, Decimal courseCredit) {
        if (candidates == null || candidates.isEmpty()) {
            return null;
        }
        if (courseCredit == null) {
            return candidates[0];
        }
        for (CourseOfferingParticipant candidate : candidates) {
            Decimal candidateCredit = candidate.CourseOffering == null ? null : candidate.CourseOffering.Credit__c;
            if (candidateCredit != null && candidateCredit == courseCredit) {
                return candidate;
            }
        }
        return null;
    }

    private void appendActivityGrade(
        List<SObject> gradesToInsert,
        Schema.SObjectType activityGradeType,
        Map<String, Schema.SObjectField> activityGradeFields,
        Id activityGradeRecordTypeId,
        CourseOfferingParticipant participant,
        StudentContext student,
        List<ComponentCandidate> candidates,
        String scoreRaw,
        String requestedComponent,
        String requestedExamType,
        String rowNumber,
        String sourceColumn,
        Id jobId
    ) {
        if (String.isBlank(scoreRaw) || activityGradeType == null || participant == null) {
            return;
        }
        ComponentCandidate component = selectComponent(candidates, requestedComponent, requestedExamType);
        if (component == null) {
            writeAuditLog(
                'Row ' + rowNumber + ': Ken Evaluation Component was not found for "' + sourceColumn + '" on the matched Course Offering.',
                jobId
            );
            return;
        }

        SObject gradeRecord = activityGradeType.newSObject();
        putField(gradeRecord, activityGradeFields, 'RecordTypeId', activityGradeRecordTypeId);
        putField(gradeRecord, activityGradeFields, 'CourseOfferingParticipantId', participant.Id);
        putField(gradeRecord, activityGradeFields, 'ContactId', student.contactId);
        putField(gradeRecord, activityGradeFields, 'AccountId', participant.ParticipantAccountId != null ? participant.ParticipantAccountId : student.accountId);
        putField(gradeRecord, activityGradeFields, 'ActivityType', 'Exam');
        putField(gradeRecord, activityGradeFields, 'Ken_Evaluation_Component__c', component.evaluationComponentId);
        putField(gradeRecord, activityGradeFields, 'ScoreStatus', 'Fully Graded');
        Decimal scoreValue = toDecimal(scoreRaw);
        if (scoreValue != null) {
            putField(gradeRecord, activityGradeFields, 'Score', scoreValue);
        } else {
            putField(gradeRecord, activityGradeFields, 'Comments', scoreRaw);
        }
        gradesToInsert.add(gradeRecord);
    }

    private static ComponentCandidate selectComponent(
        List<ComponentCandidate> candidates,
        String requestedComponent,
        String requestedExamType
    ) {
        if (candidates == null || candidates.isEmpty()) {
            return null;
        }

        List<String> componentNames = new List<String>();
        if (requestedComponent == COMPONENT_RETEST) {
            componentNames.add(COMPONENT_RETEST);
            componentNames.add(COMPONENT_SUPPLEMENTARY);
            componentNames.add(COMPONENT_EXTERNAL);
        } else if (requestedComponent == COMPONENT_SUPPLEMENTARY) {
            componentNames.add(COMPONENT_SUPPLEMENTARY);
            componentNames.add(COMPONENT_RETEST);
            componentNames.add(COMPONENT_EXTERNAL);
        } else {
            componentNames.add(requestedComponent);
        }

        for (String componentName : componentNames) {
            for (ComponentCandidate candidate : candidates) {
                if (normalizeKey(candidate.componentName) == normalizeKey(componentName) &&
                    (String.isBlank(requestedExamType) || normalizeKey(candidate.examType) == normalizeKey(requestedExamType))) {
                    return candidate;
                }
            }
        }

        if (requestedExamType == EXAM_TYPE_RETEST) {
            for (ComponentCandidate candidate : candidates) {
                if (normalizeKey(candidate.examType) == normalizeKey(EXAM_TYPE_RETEST)) {
                    return candidate;
                }
            }
        }
        return null;
    }

    private void insertRecords(List<SObject> rows, String stage, Id jobId) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        Database.SaveResult[] results = Database.insert(rows, false);
        for (Database.SaveResult result : results) {
            if (result != null && !result.isSuccess() && result.getErrors() != null && !result.getErrors().isEmpty()) {
                writeAuditLog(stage + ': ' + result.getErrors()[0].getMessage(), jobId);
            }
        }
    }

    private void putField(SObject target, Map<String, Schema.SObjectField> fields, String fieldName, Object value) {
        if (target == null || fields == null || String.isBlank(fieldName) || value == null || !fields.containsKey(fieldName)) {
            return;
        }
        Schema.DescribeFieldResult describeResult = fields.get(fieldName).getDescribe();
        if (!describeResult.isCreateable() && !describeResult.isUpdateable()) {
            return;
        }
        try {
            target.put(fieldName, KenImportUtils.convertValue(value, describeResult));
        } catch (Exception ex) {
            // Ignore per-field conversion failures.
        }
    }

    private static void addTrimmed(Set<String> values, String value) {
        if (values != null && String.isNotBlank(value)) {
            values.add(value.trim());
        }
    }

    private static String getRowValue(Map<String, Object> row, String key) {
        if (row == null || String.isBlank(key) || !row.containsKey(key) || row.get(key) == null) {
            return null;
        }
        String value = String.valueOf(row.get(key)).trim();
        return String.isBlank(value) ? null : value;
    }

    private static String getRowNumber(Integer rowIndex, List<Map<String, Object>> rows) {
        if (rowIndex == null || rows == null || rowIndex < 0 || rowIndex >= rows.size()) {
            return String.valueOf(rowIndex == null ? 0 : rowIndex + 1);
        }
        Map<String, Object> row = rows[rowIndex];
        if (row != null && row.containsKey('RowNumber') && row.get('RowNumber') != null) {
            try {
                return String.valueOf(Integer.valueOf(String.valueOf(row.get('RowNumber')).trim()));
            } catch (Exception ex) {
                // Fall through.
            }
        }
        return String.valueOf(rowIndex + 1);
    }

    private static String buildAteCourseKey(Id ateId, String courseCode) {
        return String.valueOf(ateId) + '|' + normalizeKey(courseCode);
    }

    private static String normalizeKey(String value) {
        return String.isBlank(value) ? '' : value.trim().toLowerCase();
    }

    private static Decimal toDecimal(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return Decimal.valueOf(raw.trim());
        } catch (Exception ex) {
            return null;
        }
    }

    private void writeAuditLog(String message, Id jobId) {
        if (String.isBlank(message)) {
            return;
        }
        try {
            KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord(PROCESS_NAME, SOURCE_NAME);
            creator.setErrorMessage(message);
            if (jobId != null) {
                creator.setRecordId(String.valueOf(jobId));
            }
            Audit_Log__c log = creator.returnWithoutCreate();
            if (log != null) {
                pendingLogs.add(log);
            }
        } catch (Exception ex) {
            // Keep batch independent from logging failures.
        }
    }

    private void flushAuditLogs() {
        if (pendingLogs == null || pendingLogs.isEmpty()) {
            return;
        }
        try {
            Database.DMLOptions dmlOptions = new Database.DMLOptions();
            dmlOptions.allowFieldTruncation = true;
            Database.insert(pendingLogs, dmlOptions);
        } catch (Exception ex) {
            // Ignore logging failures.
        } finally {
            pendingLogs.clear();
        }
    }
}