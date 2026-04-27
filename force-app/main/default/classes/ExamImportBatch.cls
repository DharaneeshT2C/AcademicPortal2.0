/**
 * @description
 *  Batch that ingests one historical exam CSV row per student per term, producing:
 *    - up to 12 x 2 CourseOfrPtcpActvtyGrd records (Internal + External per course) with RecordType = Component
 *    - up to 12 CourseOfferingPtcpResult records (Total -> NumericGrade, Grade -> LetterGrade)
 *    - one AcademicTermEnrollment update (TermGradePointAverage, CumulativeGradePointAverage, AcademicStanding)
 *
 *  Lookup strategy:
 *    REGNO -> Person Account (Student_ID__c) -> PersonContactId
 *    ATE located by LearnerContactId + Current_Cadence_Number__c (= SEMESTER) scoped to the selected LearningProgram
 *    CourseOfferingParticipant filtered to those whose CourseOffering.StartDate falls inside the resolved ATE's term window
 *
 * Usage:
 *  - Apex: classes/HistoricalDataImportController.cls -> ExamImportBatch
 */
@suppressWarnings('PMD.StdCyclomaticComplexity,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssMethodCount,PMD.ExcessiveParameterList,PMD.EagerlyLoadedDescribeSObjectResult')
public without sharing class ExamImportBatch implements Database.Batchable<Map<String, Object>>, Database.Stateful {
    private static final Integer MAX_COURSES_PER_ROW = 12;
    private static final String PROCESS_NAME = 'Exam Import';
    private static final String SOURCE_NAME = 'Class:ExamImportBatch';
    private static final String RECORDTYPE_ACTIVITY_GRADE_COMPONENT = 'Componnet';

    private final String jsonRows;
    private final Id learningProgramId;
    private List<Audit_Log__c> pendingLogs = new List<Audit_Log__c>();

    public ExamImportBatch(String jsonRows, Id learningProgramId) {
        this.jsonRows = jsonRows;
        this.learningProgramId = learningProgramId;
    }

    public Iterable<Map<String, Object>> start(Database.BatchableContext bc) {
        List<Map<String, Object>> maps = new List<Map<String, Object>>();
        if (String.isBlank(jsonRows)) {return maps;}
        List<Object> rows = (List<Object>) JSON.deserializeUntyped(jsonRows);
        for (Object o : rows) {
            if (o instanceof Map<String, Object>) {maps.add((Map<String, Object>) o);}
        }
        return maps;
    }

    public void execute(Database.BatchableContext bc, List<Map<String, Object>> scope) {
        Id jobId = bc != null ? bc.getJobId() : null;

        if (learningProgramId == null) {
            writeAuditLog('Learning Program Id is required for Exam Import.', jobId);
            flushAuditLogs();
            return;
        }

        // Collect row-level keys
        Set<String> regNos = new Set<String>();
        Set<String> courseCodes = new Set<String>();
        Set<Decimal> semesters = new Set<Decimal>();
        for (Map<String, Object> row : scope) {
            if (row == null) {continue;}
            String regNo = getRowValue(row, 'REGNO');
            if (String.isNotBlank(regNo)) {regNos.add(regNo);}
            Decimal sem = toDecimal(getRowValue(row, 'SEMESTER'));
            if (sem != null) {semesters.add(sem);}
            for (Integer i = 1; i <= MAX_COURSES_PER_ROW; i++) {
                String code = getRowValue(row, 'CD_' + i);
                if (String.isNotBlank(code)) {courseCodes.add(code);}
            }
        }

        // Resolve LearningProgram + alias
        LearningProgram targetProgram;
        Map<String, Schema.SObjectField> lprgFields = LearningProgram.SObjectType.getDescribe().fields.getMap();
        Boolean lprgHasAlias = lprgFields.containsKey('Alias__c');
        String lpSoql = 'SELECT Id, Name' + (lprgHasAlias ? ', Alias__c' : '') +
            ' FROM LearningProgram WHERE Id = :learningProgramId LIMIT 1';
        List<LearningProgram> programList = Database.query(lpSoql);
        if (programList.isEmpty()) {
            writeAuditLog('Learning Program not found for Id ' + learningProgramId + '.', jobId);
            flushAuditLogs();
            return;
        }
        targetProgram = programList[0];
        String programAlias = lprgHasAlias ? (String) targetProgram.get('Alias__c') : null;

        // Resolve Person Accounts by Student_ID__c
        Map<String, Schema.SObjectField> acctFields = Account.SObjectType.getDescribe().fields.getMap();
        if (!acctFields.containsKey('Student_ID__c')) {
            writeAuditLog('Account.Student_ID__c field is not available in this org.', jobId);
            flushAuditLogs();
            return;
        }
        Map<String, Account> accountByRegNo = new Map<String, Account>();
        Set<Id> contactIds = new Set<Id>();
        if (!regNos.isEmpty()) {
            for (Account a : Database.query(
                'SELECT Id, PersonContactId, Student_ID__c FROM Account ' +
                'WHERE IsPersonAccount = true AND Student_ID__c IN :regNos'
            )) {
                String sid = (String) a.get('Student_ID__c');
                if (String.isNotBlank(sid) && a.get('PersonContactId') != null) {
                    accountByRegNo.put(sid.trim(), a);
                    contactIds.add((Id) a.get('PersonContactId'));
                }
            }
        }

        // Resolve LearnerProgram -> cadence type per student
        Map<Id, String> contactToCadenceType = new Map<Id, String>();
        if (!contactIds.isEmpty()) {
            for (LearnerProgram lp : [
                SELECT Id, LearnerContactId, LearningProgramPlan.Cadence_Type__c
                FROM LearnerProgram
                WHERE LearnerContactId IN :contactIds
                AND LearningProgramPlan.LearningProgramId = :learningProgramId
            ]) {
                if (lp.LearnerContactId != null && lp.LearningProgramPlan != null) {
                    contactToCadenceType.put(lp.LearnerContactId, lp.LearningProgramPlan.Cadence_Type__c);
                }
            }
        }

        // Resolve ATEs
        Map<String, AcademicTermEnrollment> contactSemesterToATE = new Map<String, AcademicTermEnrollment>();
        Map<String, Schema.SObjectField> ateFields = AcademicTermEnrollment.SObjectType.getDescribe().fields.getMap();
        Boolean ateHasCadenceType = ateFields.containsKey('Cadence_Type__c');
        Boolean ateHasCadenceNumber = ateFields.containsKey('Current_Cadence_Number__c');
        if (!contactIds.isEmpty() && !semesters.isEmpty() && ateHasCadenceNumber) {
            String ateSoql = 'SELECT Id, LearnerContactId, LearnerAccountId, ' +
                'AcademicTerm.StartDate, AcademicTerm.EndDate, ' +
                (ateHasCadenceType ? 'Cadence_Type__c, ' : '') +
                'Current_Cadence_Number__c ' +
                'FROM AcademicTermEnrollment ' +
                'WHERE LearnerContactId IN :contactIds ' +
                'AND Current_Cadence_Number__c IN :semesters';
            for (AcademicTermEnrollment ate : Database.query(ateSoql)) {
                Id cid = (Id) ate.get('LearnerContactId');
                Decimal cnum = (Decimal) ate.get('Current_Cadence_Number__c');
                if (cid == null || cnum == null) {continue;}
                if (ateHasCadenceType && contactToCadenceType.containsKey(cid)) {
                    String expectedCadence = contactToCadenceType.get(cid);
                    String actualCadence = (String) ate.get('Cadence_Type__c');
                    if (String.isNotBlank(expectedCadence) && expectedCadence != actualCadence) {
                        continue;
                    }
                }
                contactSemesterToATE.put(String.valueOf(cid) + '|' + String.valueOf(cnum.intValue()), ate);
            }
        }

        // Resolve LearningCourses by CourseNumber
        Map<String, LearningCourse> courseByCode = new Map<String, LearningCourse>();
        Set<Id> resolvedCourseIds = new Set<Id>();
        if (!courseCodes.isEmpty()) {
            for (LearningCourse lc : [
                SELECT Id, CourseNumber, Name
                FROM LearningCourse
                WHERE CourseNumber IN :courseCodes
            ]) {
                if (String.isNotBlank(lc.CourseNumber)) {
                    courseByCode.put(lc.CourseNumber.trim(), lc);
                    resolvedCourseIds.add(lc.Id);
                }
            }
        }

        // Resolve CourseOfferingParticipants for these contacts+courses
        List<CourseOfferingParticipant> cops = new List<CourseOfferingParticipant>();
        if (!contactIds.isEmpty() && !resolvedCourseIds.isEmpty()) {
            cops = [
                SELECT Id, ParticipantContactId, ParticipantAccountId, CourseOfferingId,
                    CourseOffering.LearningCourseId, CourseOffering.StartDate, CourseOffering.EndDate
                FROM CourseOfferingParticipant
                WHERE ParticipantContactId IN :contactIds
                AND CourseOffering.LearningCourseId IN :resolvedCourseIds
            ];
        }

        // Component RecordType for CourseOfrPtcpActvtyGrd
        Id componentRtId;
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        Schema.SObjectType cogType = gd.get('CourseOfrPtcpActvtyGrd');
        Map<String, Schema.SObjectField> cogFields;
        if (cogType != null) {
            Schema.DescribeSObjectResult cogDesc = cogType.getDescribe();
            cogFields = cogDesc.fields.getMap();
            Map<String, Schema.RecordTypeInfo> rtMap = cogDesc.getRecordTypeInfosByDeveloperName();
            if (rtMap != null && rtMap.containsKey(RECORDTYPE_ACTIVITY_GRADE_COMPONENT)) {
                componentRtId = rtMap.get(RECORDTYPE_ACTIVITY_GRADE_COMPONENT).getRecordTypeId();
            }
        }

        Schema.SObjectType resultType = gd.get('CourseOfferingPtcpResult');
        Map<String, Schema.SObjectField> resultFields;
        if (resultType != null) {
            resultFields = resultType.getDescribe().fields.getMap();
        }

        // AcademicStanding picklist allowlist
        Set<String> academicStandingValues = new Set<String>();
        if (ateFields.containsKey('AcademicStanding')) {
            for (Schema.PicklistEntry pe : ateFields.get('AcademicStanding').getDescribe().getPicklistValues()) {
                if (pe.isActive()) {
                    academicStandingValues.add(pe.getValue().toUpperCase());
                }
            }
        }

        List<SObject> gradesToInsert = new List<SObject>();
        List<SObject> resultsToInsert = new List<SObject>();
        List<AcademicTermEnrollment> atesToUpdate = new List<AcademicTermEnrollment>();
        List<Map<String, Object>> rowMaps = new List<Map<String, Object>>();

        for (Integer i = 0; i < scope.size(); i++) {
            Map<String, Object> row = scope[i];
            if (row == null) {continue;}
            rowMaps.add(row);
            Integer rowIdx = rowMaps.size() - 1;

            String regNo = getRowValue(row, 'REGNO');
            if (String.isBlank(regNo)) {
                writeAuditLog('Row ' + getRowNumber(rowIdx, rowMaps) + ': REGNO is required.', jobId);
                continue;
            }

            Account studentAccount = accountByRegNo.get(regNo);
            if (studentAccount == null) {
                writeAuditLog('Row ' + getRowNumber(rowIdx, rowMaps) + ': Person Account not found for REGNO "' + regNo + '".', jobId);
                continue;
            }
            Id contactId = (Id) studentAccount.get('PersonContactId');
            Id accountId = studentAccount.Id;

            String rowCourseAlias = getRowValue(row, 'COURSE');
            if (String.isNotBlank(programAlias) && String.isNotBlank(rowCourseAlias) &&
                programAlias.trim().toUpperCase() != rowCourseAlias.trim().toUpperCase()) {
                writeAuditLog('Row ' + getRowNumber(rowIdx, rowMaps) + ': COURSE "' + rowCourseAlias +
                    '" does not match selected Learning Program alias "' + programAlias + '".', jobId);
                continue;
            }

            Decimal sem = toDecimal(getRowValue(row, 'SEMESTER'));
            if (sem == null) {
                writeAuditLog('Row ' + getRowNumber(rowIdx, rowMaps) + ': SEMESTER is required and must be numeric (REGNO=' + regNo + ').', jobId);
                continue;
            }

            String ateKey = String.valueOf(contactId) + '|' + String.valueOf(sem.intValue());
            AcademicTermEnrollment ate = contactSemesterToATE.get(ateKey);
            if (ate == null) {
                writeAuditLog('Row ' + getRowNumber(rowIdx, rowMaps) + ': AcademicTermEnrollment not found for REGNO=' + regNo +
                    ', SEMESTER=' + sem + '.', jobId);
                continue;
            }

            Datetime ateStart = (Datetime) ate.getSObject('AcademicTerm').get('StartDate');
            Datetime ateEnd = (Datetime) ate.getSObject('AcademicTerm').get('EndDate');

            // Per-course processing — process every filled CD_n slot, skip blanks
            // (supports variable course counts per row: a row with 5 filled, another with 7)
            for (Integer idx = 1; idx <= MAX_COURSES_PER_ROW; idx++) {
                String code = getRowValue(row, 'CD_' + idx);
                if (String.isBlank(code)) {continue;}
                LearningCourse lc = courseByCode.get(code.trim());
                if (lc == null) {
                    writeAuditLog('Row ' + getRowNumber(rowIdx, rowMaps) + ': LearningCourse not found for code "' + code +
                        '" (REGNO=' + regNo + ').', jobId);
                    continue;
                }

                CourseOfferingParticipant matchedCop = pickCop(cops, contactId, lc.Id, ateStart, ateEnd);
                if (matchedCop == null) {
                    writeAuditLog('Row ' + getRowNumber(rowIdx, rowMaps) + ': CourseOfferingParticipant not found for REGNO=' + regNo +
                        ', CD_' + idx + '="' + code + '" within term window.', jobId);
                    continue;
                }

                Id copAccountId = matchedCop.ParticipantAccountId != null ? matchedCop.ParticipantAccountId : accountId;

                // Internal + External activity grades
                SObject internalGrade = buildActivityGrade(cogType, cogFields, componentRtId, matchedCop.Id,
                    contactId, copAccountId, KenConstantController.COMPONENT_INTERNAL,
                    getRowValue(row, 'I_' + idx));
                if (internalGrade != null) {gradesToInsert.add(internalGrade);}

                SObject externalGrade = buildActivityGrade(cogType, cogFields, componentRtId, matchedCop.Id,
                    contactId, copAccountId, KenConstantController.COMPONENT_EXTERNAL,
                    getRowValue(row, 'E_' + idx));
                if (externalGrade != null) {gradesToInsert.add(externalGrade);}

                // Participant result: total + letter grade
                SObject resultRec = buildParticipantResult(resultType, resultFields, matchedCop.Id,
                    getRowValue(row, 'T_' + idx), getRowValue(row, 'GR_' + idx));
                if (resultRec != null) {resultsToInsert.add(resultRec);}
            }

            // ATE update for GPA / CGPA / AcademicStanding
            AcademicTermEnrollment ateUpdate = new AcademicTermEnrollment(Id = ate.Id);
            Boolean hasAteUpdate = false;
            Decimal gpa = toDecimal(getRowValue(row, 'GPA'));
            if (gpa != null && ateFields.containsKey('TermGradePointAverage')) {
                ateUpdate.put('TermGradePointAverage', gpa);
                hasAteUpdate = true;
            }
            Decimal cgpa = toDecimal(getRowValue(row, 'CGPA'));
            if (cgpa != null && ateFields.containsKey('CumulativeGradePointAverage')) {
                ateUpdate.put('CumulativeGradePointAverage', cgpa);
                hasAteUpdate = true;
            }
            String resultText = getRowValue(row, 'RESULT');
            if (String.isNotBlank(resultText) && ateFields.containsKey('AcademicStanding')) {
                if (academicStandingValues.contains(resultText.trim().toUpperCase())) {
                    for (Schema.PicklistEntry pe : ateFields.get('AcademicStanding').getDescribe().getPicklistValues()) {
                        if (pe.isActive() && pe.getValue().toUpperCase() == resultText.trim().toUpperCase()) {
                            ateUpdate.put('AcademicStanding', pe.getValue());
                            hasAteUpdate = true;
                            break;
                        }
                    }
                } else {
                    writeAuditLog('Row ' + getRowNumber(rowIdx, rowMaps) + ': RESULT "' + resultText +
                        '" is not a valid AcademicStanding picklist value; skipping standing update (REGNO=' + regNo + ').', jobId);
                }
            }
            if (hasAteUpdate) {atesToUpdate.add(ateUpdate);}
        }

        // DML
        if (!gradesToInsert.isEmpty()) {
            Database.SaveResult[] gradeResults = Database.insert(gradesToInsert, false);
            for (Integer i = 0; i < gradeResults.size(); i++) {
                if (!gradeResults[i].isSuccess()) {
                    logSaveResultErrors('Activity Grade insert', gradeResults[i], jobId);
                }
            }
        }
        if (!resultsToInsert.isEmpty()) {
            Database.SaveResult[] resultResults = Database.insert(resultsToInsert, false);
            for (Integer i = 0; i < resultResults.size(); i++) {
                if (!resultResults[i].isSuccess()) {
                    logSaveResultErrors('Participant Result insert', resultResults[i], jobId);
                }
            }
        }
        if (!atesToUpdate.isEmpty()) {
            Database.SaveResult[] ateResults = Database.update(atesToUpdate, false);
            for (Integer i = 0; i < ateResults.size(); i++) {
                if (!ateResults[i].isSuccess()) {
                    logSaveResultErrors('ATE update', ateResults[i], jobId);
                }
            }
        }

        flushAuditLogs();
    }

    public void finish(Database.BatchableContext bc) {}

    private SObject buildActivityGrade(
        Schema.SObjectType cogType,
        Map<String, Schema.SObjectField> cogFields,
        Id componentRtId,
        Id copId,
        Id contactId,
        Id accountId,
        String componentValue,
        String scoreRaw
    ) {
        if (cogType == null) {return null;}
        SObject rec = cogType.newSObject();
        putField(rec, cogFields, 'CourseOfferingParticipantId', copId);
        putField(rec, cogFields, 'ContactId', contactId);
        putField(rec, cogFields, 'AccountId', accountId);
        if (componentRtId != null) {
            putField(rec, cogFields, 'RecordTypeId', componentRtId);
        }
        putField(rec, cogFields, 'ActivityType', 'Exam');
        // Ken_Components__c is a formula — derived from Ken_Evaluation_Component__c lookup.
        // Retained here as a no-op so the intent stays visible; safe because putField skips read-only fields.
        putField(rec, cogFields, 'Ken_Components__c', componentValue);

        // Score: numeric if parseable; else stash raw into standard Comments field
        if (String.isNotBlank(scoreRaw)) {
            Decimal scoreNum = toDecimal(scoreRaw);
            if (scoreNum != null) {
                putField(rec, cogFields, 'Score', scoreNum);
            } else {
                putField(rec, cogFields, 'Comments', scoreRaw);
            }
            // Historical imports represent finalized grades.
            putField(rec, cogFields, 'ScoreStatus', 'Fully Graded');
        }
        return rec;
    }

    private SObject buildParticipantResult(
        Schema.SObjectType resultType,
        Map<String, Schema.SObjectField> resultFields,
        Id copId,
        String totalRaw,
        String letterGrade
    ) {
        if (resultType == null) {return null;}
        SObject rec = resultType.newSObject();
        putField(rec, resultFields, 'CourseOfferingParticipantId', copId);
        Decimal totalNum = toDecimal(totalRaw);
        if (totalNum != null) {
            putField(rec, resultFields, 'NumericGrade', totalNum);
        }
        if (String.isNotBlank(letterGrade)) {
            putField(rec, resultFields, 'LetterGrade', letterGrade);
        }
        return rec;
    }

    private CourseOfferingParticipant pickCop(
        List<CourseOfferingParticipant> cops,
        Id contactId,
        Id learningCourseId,
        Datetime ateStart,
        Datetime ateEnd
    ) {
        CourseOfferingParticipant withinRange;
        CourseOfferingParticipant fallback;
        for (CourseOfferingParticipant cop : cops) {
            if (cop.ParticipantContactId != contactId) {continue;}
            if (cop.CourseOffering == null || cop.CourseOffering.LearningCourseId != learningCourseId) {continue;}
            if (fallback == null) {fallback = cop;}
            Datetime offeringStart = cop.CourseOffering.StartDate;
            if (ateStart != null && ateEnd != null && offeringStart != null &&
                offeringStart >= ateStart && offeringStart <= ateEnd) {
                withinRange = cop;
                break;
            }
        }
        return withinRange != null ? withinRange : fallback;
    }

    private static Decimal toDecimal(String raw) {
        if (String.isBlank(raw)) {return null;}
        try {
            return Decimal.valueOf(raw.trim());
        } catch (Exception e) {
            return null;
        }
    }

    private void putField(SObject target, Map<String, Schema.SObjectField> fields, String fieldName, Object value) {
        if (target == null || fields == null || String.isBlank(fieldName) || !fields.containsKey(fieldName)) {return;}
        Schema.DescribeFieldResult d = fields.get(fieldName).getDescribe();
        if (!d.isCreateable() && !d.isUpdateable()) {return;}
        try {
            Object converted = KenImportUtils.convertValue(value, d);
            target.put(fieldName, converted);
        } catch (Exception e) {
            // ignore per-field conversion failures
        }
    }

    private static String getRowValue(Map<String, Object> row, String key) {
        if (row == null || String.isBlank(key) || !row.containsKey(key) || row.get(key) == null) {return null;}
        String value = String.valueOf(row.get(key)).trim();
        return String.isBlank(value) ? null : value;
    }

    private static String getRowNumber(Integer rowIndex, List<Map<String, Object>> rows) {
        if (rowIndex == null || rows == null || rowIndex < 0 || rowIndex >= rows.size()) {
            return String.valueOf(rowIndex != null ? rowIndex + 1 : 0);
        }
        Map<String, Object> row = rows[rowIndex];
        if (row != null && row.containsKey('RowNumber') && row.get('RowNumber') != null) {
            try {
                return String.valueOf(Integer.valueOf(String.valueOf(row.get('RowNumber')).trim()));
            } catch (Exception e) {
                // fall through
            }
        }
        return String.valueOf(rowIndex + 1);
    }

    private void logSaveResultErrors(String stage, Database.SaveResult sr, Id jobId) {
        if (sr == null || sr.isSuccess() || sr.getErrors() == null || sr.getErrors().isEmpty()) {return;}
        Database.Error e = sr.getErrors()[0];
        writeAuditLog(stage + ': ' + e.getMessage(), jobId);
    }

    private void writeAuditLog(String message, Id jobId) {
        if (String.isBlank(message)) {return;}
        try {
            KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord(PROCESS_NAME, SOURCE_NAME);
            creator.setErrorMessage(message);
            if (jobId != null) {creator.setRecordId(String.valueOf(jobId));}
            Audit_Log__c log = creator.returnWithoutCreate();
            if (log != null) {pendingLogs.add(log);}
        } catch (Exception ex) {
            // avoid batch failure due to logging
        }
    }

    private void flushAuditLogs() {
        if (pendingLogs == null || pendingLogs.isEmpty()) {return;}
        try {
            Database.DMLOptions dmlOptions = new Database.DMLOptions();
            dmlOptions.allowFieldTruncation = true;
            Database.insert(pendingLogs, dmlOptions);
        } catch (Exception ex) {
            // ignore logging failures
        } finally {
            pendingLogs.clear();
        }
    }
}