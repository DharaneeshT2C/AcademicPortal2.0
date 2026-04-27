public class ProgramPlanInsertQueueable implements Queueable {

    private String plansJson;
    private List<Integer> rowIndexMap;

    public ProgramPlanInsertQueueable(String plansJson, List<Integer> rowIndexMap) {
        this.plansJson = plansJson;
        this.rowIndexMap = rowIndexMap;
    }

    public void execute(QueueableContext context) {
        String jobId = context.getJobId();
        Integer successCount = 0;
        Integer errorCount = 0;
        List<String> errorMessages = new List<String>();

        try {
            List<Object> parsedList = (List<Object>) JSON.deserializeUntyped(this.plansJson);

            List<LearningProgramPlan> allRecords = new List<LearningProgramPlan>();

            for (Integer i = 0; i < parsedList.size(); i++) {
                Map<String, Object> p = (Map<String, Object>) parsedList[i];
                LearningProgramPlan plan = buildPlanRecord(p);
                if (plan != null) {
                    allRecords.add(plan);
                } else {
                    errorCount++;
                    errorMessages.add('Row ' + (i + 1) + ': Name and Program are required.');
                }
            }

            Integer chunkSize = 200;
            for (Integer start = 0; start < allRecords.size(); start += chunkSize) {
                Integer endIdx = Math.min(start + chunkSize, allRecords.size());
                List<LearningProgramPlan> chunk = new List<LearningProgramPlan>();
                for (Integer i = start; i < endIdx; i++) {
                    chunk.add(allRecords[i]);
                }

                List<Database.SaveResult> saveResults = Database.insert(chunk, false);

                for (Integer i = 0; i < saveResults.size(); i++) {
                    if (saveResults[i].isSuccess()) {
                        successCount++;
                    } else {
                        errorCount++;
                        String errMsg = 'Row ' + (start + i + 1) + ': ';
                        for (Database.Error err : saveResults[i].getErrors()) {
                            errMsg += err.getMessage() + '; ';
                        }
                        errorMessages.add(errMsg);
                    }
                }
            }
        } catch (Exception e) {
            errorCount++;
            errorMessages.add('Fatal error: ' + e.getMessage());
        }

        try {
            Audit_Log__c log = new Audit_Log__c();
            log.Name = 'Bulk Program Plan Insert - ' + jobId.substring(0, 15);
            log.RecordId__c = jobId;
            log.Process__c = ConstantController.BULK_PROGRAM_PLAN;
            log.Source__c = ConstantController.PROGRAM_PLAN_INSERT;
            log.Type__c = (errorCount == 0) ? ConstantController.RECORDTYPE_NAME_INTEGRATION : ConstantController.RECORDTYPE_NAME_EXCEPTION;
            log.Status_Code__c = (errorCount == 0) ? '200' : '500';
            log.Time_Stamp__c = Datetime.now();

            String requestSummary = 'Total records: ' + (successCount + errorCount)
                + ' | Attempted via Queueable Job: ' + jobId;
            log.Request_Body__c = requestSummary;

            Map<String, Object> resultMap = new Map<String, Object>();
            resultMap.put('successCount', successCount);
            resultMap.put('errorCount', errorCount);
            resultMap.put('errorDetails', String.join(errorMessages, '\n'));
            String responseJson = JSON.serialize(resultMap);

            if (responseJson.length() > 131072) {
                responseJson = responseJson.substring(0, 131072);
            }
            log.Response_Body__c = responseJson;

            if (!errorMessages.isEmpty()) {
                String stackStr = String.join(errorMessages, '\n');
                if (stackStr.length() > 32768) {
                    stackStr = stackStr.substring(0, 32768);
                }
                log.Stack_Trace__c = stackStr;
            }

            insert log;
        } catch (Exception e) {
            System.debug(' Failed to create audit log: ' + e.getMessage());
        }
    }

    private static LearningProgramPlan buildPlanRecord(Map<String, Object> p) {
        String planName = getStr(p, 'name');
        String programId = getStr(p, 'learningProgramId');

        if (String.isBlank(planName) || String.isBlank(programId)) return null;

        LearningProgramPlan plan = new LearningProgramPlan();
        plan.Name = planName;
        plan.LearningProgramId = programId;

        String providerId = getStr(p, 'providerId');
        if (String.isNotBlank(providerId)) plan.ProviderId = providerId;

        String description = getStr(p, 'description');
        if (String.isNotBlank(description)) plan.Description = description;

        Decimal ver = getDec(p, 'versionNumber');
        if (ver != null) plan.VersionNumber = ver;

        plan.IsActive = getBl(p, 'isActive');

        Date activeFrom = getDt(p, 'activeFromDate');
        if (activeFrom != null) plan.ActiveFromDate = activeFrom;

        Date activeTo = getDt(p, 'activeToDate');
        if (activeTo != null) plan.ActiveToDate = activeTo;

        Decimal grade = getDec(p, 'minimumGradePointAvg');
        if (grade != null) plan.MinimumProgramGradePointAvg = grade;

        String cadence = getStr(p, 'cadenceType');
        if (String.isNotBlank(cadence)) plan.Cadence_Type__c = cadence;

        Decimal intake = getDec(p, 'intakeStrength');
        if (intake != null) plan.Intake_Strength__c = intake;

        plan.IsMonday__c = getBl(p, 'isMonday');
        plan.IsTuesday__c = getBl(p, 'isTuesday');
        plan.IsWednesday__c = getBl(p, 'isWednesday');
        plan.IsThursday__c = getBl(p, 'isThursday');
        plan.IsFriday__c = getBl(p, 'isFriday');
        plan.IsSaturday__c = getBl(p, 'isSaturday');
        plan.IsSunday__c = getBl(p, 'isSunday');

        Decimal dur = getDec(p, 'durationPerSession');
        if (dur != null) plan.Duration_per_Session_in_minutes__c = dur;

        String batch = getStr(p, 'batchNumber');
        if (String.isNotBlank(batch)) plan.Batch_Number__c = batch;

        String section = getStr(p, 'section');
        if (String.isNotBlank(section)) plan.Section__c = section;

        return plan;
    }

    private static String getStr(Map<String, Object> m, String k) {
        Object v = m.get(k);
        return v != null ? String.valueOf(v) : null;
    }

    private static Boolean getBl(Map<String, Object> m, String k) {
        Object v = m.get(k);
        if (v == null) return false;
        if (v instanceof Boolean) return (Boolean) v;
        return String.valueOf(v).equalsIgnoreCase('true');
    }

    private static Decimal getDec(Map<String, Object> m, String k) {
        Object v = m.get(k);
        if (v == null) return null;
        try { return Decimal.valueOf(String.valueOf(v)); }
        catch (Exception e) { return null; }
    }

    private static Date getDt(Map<String, Object> m, String k) {
        Object v = m.get(k);
        if (v == null) return null;
        String s = String.valueOf(v);
        if (String.isBlank(s)) return null;
        try {
            if (s.length() == 10 && s.indexOf('-') == 4) return Date.valueOf(s);
            if (s.length() == 10 && s.indexOf('-') == 2) {
                List<String> pts = s.split('-');
                return Date.newInstance(
                    Integer.valueOf(pts[2]), Integer.valueOf(pts[1]), Integer.valueOf(pts[0])
                );
            }
            return Date.valueOf(s);
        } catch (Exception e) { return null; }
    }
}