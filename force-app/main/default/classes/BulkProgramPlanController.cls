public with sharing class BulkProgramPlanController {
    
    private static final Integer SYNC_DML_LIMIT = 50;
    

    
    public class ProgramWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String providerId;
        @AuraEnabled public String providerName;
        @AuraEnabled public String campus;
        @AuraEnabled public String institute;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Decimal durationPerSession; 
    }
    
    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        
        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    
    public class InitData {
        @AuraEnabled public List<ProgramWrapper> programs;
        @AuraEnabled public List<PicklistOption> batchOptions;
        @AuraEnabled public List<PicklistOption> cadenceOptions;
        @AuraEnabled public List<PicklistOption> sectionOptions;
        @AuraEnabled public List<String> batchValues;
        @AuraEnabled public List<String> cadenceValues;
        @AuraEnabled public List<String> sectionValues;
    }
    
    public class SaveResult {
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer errorCount;
        @AuraEnabled public List<RowError> errors;
        @AuraEnabled public Boolean isAsync;
        @AuraEnabled public String jobId;
        @AuraEnabled public List<String> createdIds;
        
        public SaveResult() {
            this.successCount = 0;
            this.errorCount = 0;
            this.errors = new List<RowError>();
            this.isAsync = false;
            this.createdIds = new List<String>();
        }
    }
    
    public class RowError {
        @AuraEnabled public Integer rowIndex;
        @AuraEnabled public String message;
        
        public RowError(Integer rowIndex, String message) {
            this.rowIndex = rowIndex;
            this.message = message;
        }
    }
    
    public class DuplicateResult {
        @AuraEnabled public List<DuplicateRow> duplicates;
        
        public DuplicateResult() {
            this.duplicates = new List<DuplicateRow>();
        }
    }
    
    public class DuplicateRow {
        @AuraEnabled public Integer rowIndex;
        @AuraEnabled public String existingId;
        @AuraEnabled public String name;
        @AuraEnabled public String programName;
    }
    
    public class JobStatus {
        @AuraEnabled public String status;
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer errorCount;
        @AuraEnabled public String errorMessage;
    }
    

    
    @AuraEnabled(cacheable=true)
    public static InitData getInitData() {
        InitData data = new InitData();
        
        List<LearningProgram> programs = [
            SELECT Id, Name, ProviderId, Provider.Name,
                   Campus__c, Institute__c, IsActive, Duration
            FROM LearningProgram
            WHERE IsActive = true WITH SECURITY_ENFORCED
            ORDER BY Name ASC 
            LIMIT 2000
        ];
        
        data.programs = new List<ProgramWrapper>();
        for (LearningProgram lp : programs) {
            ProgramWrapper pw = new ProgramWrapper();
            pw.id = lp.Id;
            pw.name = lp.Name;
            pw.providerId = lp.ProviderId;
            pw.providerName = lp.Provider?.Name;
            pw.campus = lp.Campus__c;
            pw.institute = lp.Institute__c;
            pw.isActive = lp.IsActive;
            pw.durationPerSession = lp.Duration;
            data.programs.add(pw);
        }
        
        data.batchOptions = getPicklistValues('LearningProgramPlan', 'Batch_Number__c');
        data.cadenceOptions = getPicklistValues('LearningProgramPlan', 'Cadence_Type__c');
        data.sectionOptions = getPicklistValues('LearningProgramPlan', 'Section__c');
        
        data.batchValues = new List<String>();
        for (PicklistOption o : data.batchOptions) {
            data.batchValues.add(o.value);
        }
        data.cadenceValues = new List<String>();
        for (PicklistOption o : data.cadenceOptions) {
            data.cadenceValues.add(o.value);
        }
        data.sectionValues = new List<String>();
        for (PicklistOption o : data.sectionOptions) {
            data.sectionValues.add(o.value);
        }
        
        return data;
    }
    
    @AuraEnabled
    public static DuplicateResult checkDuplicates(List<Object> plans) {
        DuplicateResult result = new DuplicateResult();
        
        if (plans == null || plans.isEmpty()) return result;
        
        String jsonStr = JSON.serialize(plans);
        List<Object> parsedList = (List<Object>) JSON.deserializeUntyped(jsonStr);
        
        Set<String> programIds = new Set<String>();
        Set<String> planNames = new Set<String>();
        
        for (Object item : parsedList) {
            Map<String, Object> p = (Map<String, Object>) item;
            String name = getString(p, 'name');
            String programId = getString(p, 'learningProgramId');
            if (String.isNotBlank(name) && String.isNotBlank(programId)) {
                planNames.add(name);
                programIds.add(programId);
            }
        }
        
        if (planNames.isEmpty()) {
            return result;
        }
        
        Map<String, LearningProgramPlan> existingMap = new Map<String, LearningProgramPlan>();
        for (LearningProgramPlan existing : [
            SELECT Id, Name, LearningProgramId, LearningProgram.Name
            FROM LearningProgramPlan
            WHERE Name IN :planNames
            AND LearningProgramId IN :programIds
            WITH SECURITY_ENFORCED
        ]) {
            String key = existing.Name.toLowerCase().trim() + '|' + existing.LearningProgramId;
            existingMap.put(key, existing);
        }
        
        for (Integer i = 0; i < parsedList.size(); i++) {
            Map<String, Object> p = (Map<String, Object>) parsedList[i];
            String name = getString(p, 'name');
            String programId = getString(p, 'learningProgramId');
            
            if (String.isNotBlank(name) && String.isNotBlank(programId)) {
                String key = name.toLowerCase().trim() + '|' + programId;
                if (existingMap.containsKey(key)) {
                    LearningProgramPlan dup = existingMap.get(key);
                    DuplicateRow dr = new DuplicateRow();
                    dr.rowIndex = i;
                    dr.existingId = dup.Id;
                    dr.name = dup.Name;
                    dr.programName = dup.LearningProgram != null ? dup.LearningProgram.Name : '';
                    result.duplicates.add(dr);
                }
            }
        }
        
        return result;
    }
    
    @AuraEnabled
    public static SaveResult insertProgramPlans(List<Object> plans) {
        SaveResult result = new SaveResult();
        
        if (plans == null || plans.isEmpty()) {
            createAuditLog(null, 0, 0, new List<String>{'Empty payload received'}, 'Sync-Empty');
            return result;
        }
        
        String jsonStr = JSON.serialize(plans);
        List<Object> parsedList = (List<Object>) JSON.deserializeUntyped(jsonStr);
        
        List<LearningProgramPlan> records = new List<LearningProgramPlan>();
        List<Integer> rowIndexMap = new List<Integer>();
        List<String> preValidationErrors = new List<String>();
        
        for (Integer i = 0; i < parsedList.size(); i++) {
            Map<String, Object> p = (Map<String, Object>) parsedList[i];
            LearningProgramPlan plan = buildPlanRecord(p);
            
            if (plan != null) {
                records.add(plan);
                rowIndexMap.add(i);
            } else {
                result.errorCount++;
                String errMsg = 'Row ' + (i + 1) + ': Name and Program are required.';
                preValidationErrors.add(errMsg);
                result.errors.add(new RowError(i, errMsg));
            }
        }
        
        if (records.isEmpty()) {
            createAuditLog(null, 0, result.errorCount, preValidationErrors, 'Sync-NoValidRecords');
            return result;
        }
        
        if (records.size() <= SYNC_DML_LIMIT) {
            executeSyncInsert(records, rowIndexMap, result, preValidationErrors);
        } else {
            String jobId = System.enqueueJob(
                new ProgramPlanInsertQueueable(jsonStr, rowIndexMap)
            );
            result.isAsync = true;
            result.jobId = jobId;
        }
        
        return result;
    }
    
    @AuraEnabled
    public static JobStatus getJobStatus(String jobId) {
        JobStatus status = new JobStatus();
        
        List<AsyncApexJob> jobs = [
            SELECT Status, NumberOfErrors, ExtendedStatus
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];
        
        if (jobs.isEmpty()) {
            status.status = 'NOT_FOUND';
            return status;
        }
        
        AsyncApexJob job = jobs[0];
        status.status = job.Status;
        status.errorMessage = job.ExtendedStatus;
        
        List<Audit_Log__c> logs = [
            SELECT Response_Body__c, Status_Code__c, Type__c
            FROM Audit_Log__c
            WHERE RecordId__c = :jobId
            AND Process__c =: ConstantController.BULK_PROGRAM_PLAN
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        if (!logs.isEmpty()) {
            try {
                String responseBody = logs[0].Response_Body__c;
                if (String.isNotBlank(responseBody)) {
                    Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                    status.successCount = resultMap.containsKey('successCount')
                        ? Integer.valueOf(String.valueOf(resultMap.get('successCount'))) : 0;
                    status.errorCount = resultMap.containsKey('errorCount')
                        ? Integer.valueOf(String.valueOf(resultMap.get('errorCount'))) : 0;
                    if (resultMap.containsKey('errorDetails')) {
                        status.errorMessage = String.valueOf(resultMap.get('errorDetails'));
                    }
                }
            } catch (Exception e) {
                status.errorMessage = logs[0].Response_Body__c;
            }
            
            if (logs[0].Status_Code__c == '500' || logs[0].Type__c == 'Exception') {
                status.status = 'Failed';
            }
        }
        
        return status;
    }
    

    
    private static void executeSyncInsert(
        List<LearningProgramPlan> records,
        List<Integer> rowIndexMap,
        SaveResult result,
        List<String> preValidationErrors
    ) {
        List<Database.SaveResult> saveResults = Database.insert(records, false);
        List<String> errorMessages = new List<String>(preValidationErrors);
        Integer errorCount = 0;
        Integer successCount = 0;
        
        for (Integer i = 0; i < saveResults.size(); i++) {
            Integer originalRowIndex = rowIndexMap[i];
            if (saveResults[i].isSuccess()) {
                successCount++;
                result.createdIds.add(saveResults[i].getId());
            } else {
                errorCount++;
                
                List<String> rowErrors = new List<String>();
                for (Database.Error err : saveResults[i].getErrors()) {
                    rowErrors.add(err.getMessage());
                }
                String errMsg = String.join(rowErrors, '; ');
                
                String fullErrMsg = 'Row ' + (originalRowIndex + 1) + ': ' + errMsg;
                errorMessages.add(fullErrMsg);
                result.errors.add(new RowError(originalRowIndex, errMsg));
            }
        }
        
        result.successCount = successCount;
        result.errorCount += errorCount;
        
        createAuditLog(null, successCount, result.errorCount, errorMessages, 'Sync');
    }
    
    private static LearningProgramPlan buildPlanRecord(Map<String, Object> p) {
        String planName = getString(p, 'name');
        String programId = getString(p, 'learningProgramId');
        
        if (String.isBlank(planName) || String.isBlank(programId)) {
            return null;
        }
        
        LearningProgramPlan plan = new LearningProgramPlan();
        plan.Name = planName;
        plan.LearningProgramId = programId;
        
        String providerId = getString(p, 'providerId');
        if (String.isNotBlank(providerId)) plan.ProviderId = providerId;
        
        String description = getString(p, 'description');
        if (String.isNotBlank(description)) plan.Description = description;
        
        Decimal ver = getDecimal(p, 'versionNumber');
        if (ver != null) plan.VersionNumber = ver;
        
        plan.IsActive = getBool(p, 'isActive');
        
        Date activeFrom = getDateVal(p, 'activeFromDate');
        if (activeFrom != null) plan.ActiveFromDate = activeFrom;
        
        Date activeTo = getDateVal(p, 'activeToDate');
        if (activeTo != null) plan.ActiveToDate = activeTo;
        
        Decimal grade = getDecimal(p, 'minimumGradePointAvg');
        if (grade != null) plan.MinimumProgramGradePointAvg = grade;
        
        String cadence = getString(p, 'cadenceType');
        if (String.isNotBlank(cadence)) plan.Cadence_Type__c = cadence;
        
        Decimal intake = getDecimal(p, 'intakeStrength');
        if (intake != null) plan.Intake_Strength__c = intake;
        
        plan.IsMonday__c = getBool(p, 'isMonday');
        plan.IsTuesday__c = getBool(p, 'isTuesday');
        plan.IsWednesday__c = getBool(p, 'isWednesday');
        plan.IsThursday__c = getBool(p, 'isThursday');
        plan.IsFriday__c = getBool(p, 'isFriday');
        plan.IsSaturday__c = getBool(p, 'isSaturday');
        plan.IsSunday__c = getBool(p, 'isSunday');
        
        Decimal dur = getDecimal(p, 'durationPerSession');
        if (dur != null) plan.Duration_per_Session_in_minutes__c = dur;
        
        String batch = getString(p, 'batchNumber');
        if (String.isNotBlank(batch)) plan.Batch_Number__c = batch;
        
        String section = getString(p, 'section');
        if (String.isNotBlank(section)) plan.Section__c = section;
        
        return plan;
    }
    
    private static String getString(Map<String, Object> m, String key) {
        Object val = m.get(key);
        return val != null ? String.valueOf(val) : null;
    }
    
    private static Boolean getBool(Map<String, Object> m, String key) {
        Object val = m.get(key);
        if (val == null) return false;
        if (val instanceof Boolean) return (Boolean) val;
        return String.valueOf(val).equalsIgnoreCase('true');
    }
    
    private static Decimal getDecimal(Map<String, Object> m, String key) {
        Object val = m.get(key);
        if (val == null) return null;
        try {
            return Decimal.valueOf(String.valueOf(val));
        } catch (Exception e) {
            return null;
        }
    }
    
    private static Date getDateVal(Map<String, Object> m, String key) {
        Object val = m.get(key);
        if (val == null) return null;
        String dateStr = String.valueOf(val);
        if (String.isBlank(dateStr)) return null;
        try {
            if (dateStr.length() == 10 && dateStr.indexOf('-') == 4) {
                return Date.valueOf(dateStr);
            }
            if (dateStr.length() == 10 && dateStr.indexOf('-') == 2) {
                List<String> parts = dateStr.split('-');
                return Date.newInstance(
                    Integer.valueOf(parts[2]),
                    Integer.valueOf(parts[1]),
                    Integer.valueOf(parts[0])
                );
            }
            return Date.valueOf(dateStr);
        } catch (Exception e) {
            return null;
        }
    }
    @testVisible
    private static List<PicklistOption> getPicklistValues(String objectName, String fieldName) {
        List<PicklistOption> options = new List<PicklistOption>();
        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
            if (sot != null) {
                Schema.DescribeFieldResult dfr = sot.getDescribe()
                    .fields.getMap().get(fieldName)?.getDescribe();
                if (dfr != null) {
                    for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
                        if (pe.isActive()) {
                            options.add(new PicklistOption(pe.getLabel(), pe.getValue()));
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error fetching picklist: ' + e.getMessage());
        }
        return options;
    }
    
    /**
     * Creates an Audit_Log__c record for bulk insert operations.
     * Works for both synchronous and asynchronous executions.
     */
    public static void createAuditLog(
        String jobId, 
        Integer successCount, 
        Integer errorCount, 
        List<String> errorMessages, 
        String executionType
    ) {
        try {
            if (errorMessages.isEmpty() && successCount == 0) {
                return;
            }
            
            Audit_Log__c log = new Audit_Log__c();
            String logIdentifier = jobId != null ? jobId : 'Sync-' + String.valueOf(System.now().getTime()).substring(0, 8);
            
            log.Name = 'Bulk Program Plan Insert - ' + 
                (jobId != null ? jobId.substring(0, 15) : logIdentifier.substring(0, 15));
            log.RecordId__c = jobId;
            log.Process__c = ConstantController.BULK_PROGRAM_PLAN;
            log.Source__c = ConstantController.PROGRAM_PLAN_INSERT;
            log.Type__c = (errorCount == 0) 
                ? ConstantController.RECORDTYPE_NAME_INTEGRATION 
                : ConstantController.RECORDTYPE_NAME_EXCEPTION;
            log.Status_Code__c = (errorCount == 0) ? '200' : '500';
            log.Time_Stamp__c = Datetime.now();
            
            String requestSummary = 'Total records: ' + (successCount + errorCount) +
                ' | Execution Type: ' + executionType +
                (jobId != null ? ' | JobId: ' + jobId : '');
            log.Request_Body__c = requestSummary;
            
            Map<String, Object> resultMap = new Map<String, Object>();
            resultMap.put('successCount', successCount);
            resultMap.put('errorCount', errorCount);
            resultMap.put('errorDetails', errorMessages.isEmpty() ? '' : String.join(errorMessages, '\n'));
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
}