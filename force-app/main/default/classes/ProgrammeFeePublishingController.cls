public with sharing class ProgrammeFeePublishingController {
    private static final String ERROR_DUPLICATE_PROGRAMME_FEE =
        'A Programme Fee configuration already exists for this Programme, Batch / Intake, Fee Category, and Frequency.';
    private static final String LINK_LEVEL_LEARNING_PROGRAM_PLAN = 'Learning Program Plan';
    private static final String LINK_LEVEL_LEARNING_PROGRAM = 'Learning Program';
    private static final String LINK_LEVEL_INSTITUTE = 'Institute';

    public class OptionRow {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
    }

    public class BuilderSeedData {
        @AuraEnabled public List<OptionRow> programmeOptions;
        @AuraEnabled public List<OptionRow> feePlanOptions;
        @AuraEnabled public List<OptionRow> feeHeadOptions;
        @AuraEnabled public List<OptionRow> categoryOptions;
        @AuraEnabled public List<OptionRow> quotaOptions;
        @AuraEnabled public List<OptionRow> feeCategoryOptions;
        @AuraEnabled public List<OptionRow> remittanceOptions;
        @AuraEnabled public List<RemittanceMerchantRow> remittanceMerchantRows;
        @AuraEnabled public List<OptionRow> paymentGatewayOptions;
        @AuraEnabled public List<OptionRow> installmentOptions;
        @AuraEnabled public List<OptionRow> feeAssignmentTriggerPointOptions;
        @AuraEnabled public List<OptionRow> penaltyPlanOptions;
        @AuraEnabled public List<ProgrammeYearRangeRow> programmeYearRanges;
    }

    public class RemittanceMerchantRow {
        @AuraEnabled public String remittanceId;
        @AuraEnabled public String merchantIds;
    }

    public class ProgrammeYearRangeRow {
        @AuraEnabled public String programmeId;
        @AuraEnabled public Integer startYear;
        @AuraEnabled public Integer endYear;
    }

    public class PublishConfigRow {
        @AuraEnabled public Integer programYearNumber;
        @AuraEnabled public String academicYearLabel;
        @AuraEnabled public Id feePlanId;
        @AuraEnabled public Id feeHeadId;
        @AuraEnabled public Id categoryId;
        @AuraEnabled public Id quotaId;
        @AuraEnabled public String feeAssignmentTriggerPoint;
        @AuraEnabled public String tag;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Id remittanceOverrideId;
        @AuraEnabled public Id installmentId;
        @AuraEnabled public Id penaltyPlanId;
    }

    public class SaveProgrammeFeeRequest {
        @AuraEnabled public Id feeTypeId;
        @AuraEnabled public Boolean isFeeTypeMode;
        @AuraEnabled public String linkLevel;
        @AuraEnabled public List<LinkedMappingRow> linkedMappings;
        @AuraEnabled public Id programmeId;
        @AuraEnabled public Id learningProgramId;
        @AuraEnabled public Id instituteId;
        @AuraEnabled public String feeCategory;
        @AuraEnabled public String batchIntake;
        @AuraEnabled public Date activationDate;
        @AuraEnabled public String frequency;
        @AuraEnabled public String termSystem;
        @AuraEnabled public Id defaultRemittanceId;
        @AuraEnabled public List<Id> remittanceAccountIds;
        @AuraEnabled public Id paymentGatewayId;
        @AuraEnabled public String notes;

        @AuraEnabled public Id oneTimeFeePlanId;
        @AuraEnabled public Id oneTimeFeeHeadId;
        @AuraEnabled public Id oneTimeCategoryId;
        @AuraEnabled public Id oneTimeQuotaId;
        @AuraEnabled public String oneTimeFeeAssignmentTriggerPoint;
        @AuraEnabled public String oneTimeFeePlanTag;
        @AuraEnabled public Decimal oneTimeAmount;
        @AuraEnabled public Date oneTimeStartDate;
        @AuraEnabled public Date oneTimeDueDate;
        @AuraEnabled public Id oneTimeRemittanceOverrideId;
        @AuraEnabled public Id oneTimeInstallmentId;
        @AuraEnabled public Id oneTimePenaltyPlanId;

        @AuraEnabled public List<PublishConfigRow> configRows;
    }

    public class ProgrammeFeeRow {
        @AuraEnabled public Id feeTypeId;
        @AuraEnabled public String programmeFeeName;
        @AuraEnabled public String feeCategory;
        @AuraEnabled public String programmeName;
        @AuraEnabled public String batchIntake;
        @AuraEnabled public String frequency;
        @AuraEnabled public Date activationDate;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime lastModified;
        @AuraEnabled public Integer usedInAssignments;
    }

    public class ProgrammeFeeRecordData {
        @AuraEnabled public Id feeTypeId;
        @AuraEnabled public String linkLevel;
        @AuraEnabled public Id instituteId;
        @AuraEnabled public Id learningProgramId;
        @AuraEnabled public String contextName;
        @AuraEnabled public String programmeFeeName;
        @AuraEnabled public String feeCategory;
        @AuraEnabled public String programmeName;
        @AuraEnabled public String batchIntake;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public String academicYear;
        @AuraEnabled public String frequency;
        @AuraEnabled public Date activationDate;
        @AuraEnabled public String status;
        @AuraEnabled public String createdByName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Datetime lastModified;
        @AuraEnabled public String defaultRemittanceName;
        @AuraEnabled public List<String> remittanceAccountNames;
        @AuraEnabled public String defaultPenaltyPlanName;
        @AuraEnabled public String paymentGatewayName;
        @AuraEnabled public String notes;
        @AuraEnabled public Integer usedInAssignments;
        @AuraEnabled public List<ProgrammeConfigurationRow> configurationRows;
        @AuraEnabled public List<UsageCategoryRow> usageCategories;
        @AuraEnabled public List<SimpleHistoryRow> amendmentHistory;
        @AuraEnabled public List<SimpleHistoryRow> auditTrail;
    }

    public class ProgrammeConfigurationRow {
        @AuraEnabled public String termLabel;
        @AuraEnabled public Id feePlanId;
        @AuraEnabled public Id feeHeadId;
        @AuraEnabled public Id categoryId;
        @AuraEnabled public Id quotaId;
        @AuraEnabled public String feePlanName;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String remittanceAccounts;
        @AuraEnabled public List<String> remittanceAccountNames;
        @AuraEnabled public String tag;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public String status;
    }

    public class UsageCategoryRow {
        @AuraEnabled public String categoryName;
        @AuraEnabled public Integer students;
    }

    public class LinkedMappingRow {
        @AuraEnabled public String linkedLevel;
        @AuraEnabled public Id linkedEntityId;
    }

    public class SimpleHistoryRow {
        @AuraEnabled public String versionLabel;
        @AuraEnabled public String action;
        @AuraEnabled public String userName;
        @AuraEnabled public Datetime changedAt;
        @AuraEnabled public String details;
        @AuraEnabled public String status;
    }

    private class FeeSetLineSourceRow {
        public Id feeSetId;
        public Id feeHeadId;
        public String studentCategory;
        public Id categoryId;
        public Id quotaId;
        public Decimal amount;
        public Id remittanceAccountId;
        public Id taxId;
    }

    @AuraEnabled(cacheable=true)
    public static List<ProgrammeFeeRow> getProgrammeFees() {
        List<Ken_Fee_Type__c> feeTypes = [
            SELECT Id,
                   Name,
                   Fee_Type_Name__c,
                   Fee_Category__c,
                   Batch__c,
                   Learning_Program_Plan__r.Name,
                   Fee_Collection_Frequency__c,
                   Status__c,
                   CreatedDate,
                   LastModifiedDate
            FROM Ken_Fee_Type__c
            ORDER BY LastModifiedDate DESC
            LIMIT 500
        ];

        if (feeTypes.isEmpty()) {
            return new List<ProgrammeFeeRow>();
        }

        Set<Id> feeTypeIds = new Set<Id>();
        for (Ken_Fee_Type__c feeType : feeTypes) {
            feeTypeIds.add(feeType.Id);
        }

        Map<Id, Integer> assignmentCountByFeeTypeId = new Map<Id, Integer>();
        for (AggregateResult countRow : [
            SELECT Fee_Type__c feeTypeId, COUNT(Id) assignmentCount
            FROM Fee_Assignment__c
            WHERE Fee_Type__c IN :feeTypeIds
            GROUP BY Fee_Type__c
        ]) {
            assignmentCountByFeeTypeId.put(
                (Id) countRow.get('feeTypeId'),
                Integer.valueOf(String.valueOf(countRow.get('assignmentCount')))
            );
        }

        List<ProgrammeFeeRow> rows = new List<ProgrammeFeeRow>();
        for (Ken_Fee_Type__c feeType : feeTypes) {
            ProgrammeFeeRow row = new ProgrammeFeeRow();
            row.feeTypeId = feeType.Id;
            row.programmeFeeName = buildProgrammeFeeDisplayName(
                feeType.Fee_Type_Name__c,
                feeType.Name,
                feeType.Batch__c
            );
            row.feeCategory = feeType.Fee_Category__c;
            row.programmeName = feeType.Learning_Program_Plan__r == null
                ? '-'
                : feeType.Learning_Program_Plan__r.Name;
            row.batchIntake = String.isBlank(feeType.Batch__c) ? '-' : feeType.Batch__c;
            row.frequency = String.isBlank(feeType.Fee_Collection_Frequency__c)
                ? '-'
                : feeType.Fee_Collection_Frequency__c;
            row.activationDate = Date.newInstance(
                feeType.CreatedDate.year(),
                feeType.CreatedDate.month(),
                feeType.CreatedDate.day()
            );
            row.status = String.isBlank(feeType.Status__c) ? 'Draft' : feeType.Status__c;
            row.lastModified = feeType.LastModifiedDate;
            row.usedInAssignments = assignmentCountByFeeTypeId.containsKey(feeType.Id)
                ? assignmentCountByFeeTypeId.get(feeType.Id)
                : 0;
            rows.add(row);
        }

        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static ProgrammeFeeRecordData getProgrammeFeeRecord(Id feeTypeId) {
        if (feeTypeId == null) {
            throw new AuraHandledException('Programme Fee Id is required.');
        }

        String feeTypeRecordQuery =
            'SELECT Id,' +
            ' Name,' +
            ' Fee_Type_Name__c,' +
            ' Fee_Category__c,' +
            ' Batch__c,' +
            ' Institute__c,' +
            ' Institute__r.Name,' +
            ' Total_Amount__c,' +
            ' Fee_Collection_Frequency__c,' +
            ' Status__c,' +
            ' Description__c,' +
            ' CreatedDate,' +
            ' LastModifiedDate,' +
            ' CreatedBy.Name,' +
            ' Learning_Program__c,' +
            ' Learning_Program__r.Name,' +
            ' Learning_Program_Plan__r.Name,' +
            ' Ken_Tax_Definition__r.Name,' +
            ' Late_Fee_Plan__r.Fee_Type_Name__c,' +
            ' Late_Fee_Plan__r.Name';
        String academicYearFieldApiName = resolveAcademicYearFieldApiName();
        if (!String.isBlank(academicYearFieldApiName)) {
            feeTypeRecordQuery += ', ' + academicYearFieldApiName;
        }
        feeTypeRecordQuery += ' FROM Ken_Fee_Type__c WHERE Id = :feeTypeId LIMIT 1';
        Ken_Fee_Type__c feeTypeRecord = (Ken_Fee_Type__c) Database.query(feeTypeRecordQuery);

        List<Ken_Fee_Type_Remittance__c> remittanceLinks = [
            SELECT Remittance_Account__r.Bank_Account_Name__c
            FROM Ken_Fee_Type_Remittance__c
            WHERE Ken_Fee_Type__c = :feeTypeId
            ORDER BY CreatedDate ASC
        ];
        List<String> globalRemittanceNames = new List<String>();
        Set<String> globalRemittanceNameSet = new Set<String>();
        for (Ken_Fee_Type_Remittance__c remittanceLink : remittanceLinks) {
            String accountName = remittanceLink.Remittance_Account__r == null
                ? null
                : remittanceLink.Remittance_Account__r.Bank_Account_Name__c;
            if (!String.isBlank(accountName)) {
                globalRemittanceNameSet.add(accountName);
            }
        }
        if (!globalRemittanceNameSet.isEmpty()) {
            globalRemittanceNames.addAll(globalRemittanceNameSet);
            globalRemittanceNames.sort();
        }

        List<Ken_Fee_Type_Line_Item__c> lineRecords = [
            SELECT Id,
                   Program_Year_Number__c,
                   Fee_Set__c,
                   Fee_Head__c,
                   Start_Date__c,
                   Due_Date__c,
                   Fee_Set__r.Name,
                   Fee_Head__r.Fee_Head_Name__c,
                   Amount__c,
                   Student_Category__c,
                   Remittance_Account__r.Bank_Account_Name__c,
                   Is_Active__c
            FROM Ken_Fee_Type_Line_Item__c
            WHERE Ken_Fee_Type__c = :feeTypeId
            ORDER BY Program_Year_Number__c ASC, Due_Date__c ASC, LastModifiedDate ASC
        ];

        Map<Integer, ProgrammeConfigurationRow> configByYearNumber = new Map<Integer, ProgrammeConfigurationRow>();
        Map<Integer, Set<String>> remittanceNamesByYearNumber = new Map<Integer, Set<String>>();
        Map<String, Integer> usageCountByCategory = new Map<String, Integer>();
        Integer activeLines = 0;

        for (Ken_Fee_Type_Line_Item__c lineRecord : lineRecords) {
            Integer yearNumber = lineRecord.Program_Year_Number__c == null
                ? 1
                : Integer.valueOf(lineRecord.Program_Year_Number__c);

            if (!configByYearNumber.containsKey(yearNumber)) {
                ProgrammeConfigurationRow configRow = new ProgrammeConfigurationRow();
                configRow.termLabel = buildTermLabel(feeTypeRecord.Fee_Collection_Frequency__c, yearNumber);
                configRow.feePlanId = lineRecord.Fee_Set__c;
                configRow.feeHeadId = lineRecord.Fee_Head__c;
                if (lineRecord.Fee_Set__r != null && !String.isBlank(lineRecord.Fee_Set__r.Name)) {
                    configRow.feePlanName = lineRecord.Fee_Set__r.Name;
                } else if (lineRecord.Fee_Head__r != null && !String.isBlank(lineRecord.Fee_Head__r.Fee_Head_Name__c)) {
                    configRow.feePlanName = lineRecord.Fee_Head__r.Fee_Head_Name__c;
                } else {
                    configRow.feePlanName = '-';
                }
                configRow.tag = '-';
                configRow.startDate = lineRecord.Start_Date__c;
                configRow.dueDate = lineRecord.Due_Date__c;
                configRow.amount = lineRecord.Amount__c;
                configRow.status = ((lineRecord.Fee_Set__r != null || lineRecord.Fee_Head__r != null)
                    && lineRecord.Due_Date__c != null)
                    ? 'Planned'
                    : 'Not Planned';
                configByYearNumber.put(yearNumber, configRow);
            }

            if (!remittanceNamesByYearNumber.containsKey(yearNumber)) {
                remittanceNamesByYearNumber.put(yearNumber, new Set<String>());
            }
            if (lineRecord.Remittance_Account__r != null
                && !String.isBlank(lineRecord.Remittance_Account__r.Bank_Account_Name__c)) {
                remittanceNamesByYearNumber.get(yearNumber).add(
                    lineRecord.Remittance_Account__r.Bank_Account_Name__c
                );
            }

            if (!String.isBlank(lineRecord.Student_Category__c)) {
                Integer existingCount = usageCountByCategory.containsKey(lineRecord.Student_Category__c)
                    ? usageCountByCategory.get(lineRecord.Student_Category__c)
                    : 0;
                usageCountByCategory.put(lineRecord.Student_Category__c, existingCount + 1);
            }

            if (lineRecord.Is_Active__c == true) {
                activeLines++;
            }
        }

        List<Integer> sortedKeys = new List<Integer>();
        sortedKeys.addAll(configByYearNumber.keySet());
        sortedKeys.sort();

        List<ProgrammeConfigurationRow> configurationRows = new List<ProgrammeConfigurationRow>();
        for (Integer keyValue : sortedKeys) {
            ProgrammeConfigurationRow configRow = configByYearNumber.get(keyValue);
            Set<String> remittanceNamesForRow = remittanceNamesByYearNumber.get(keyValue);
            if (remittanceNamesForRow != null && !remittanceNamesForRow.isEmpty()) {
                List<String> remittanceNameList = new List<String>();
                remittanceNameList.addAll(remittanceNamesForRow);
                remittanceNameList.sort();
                configRow.remittanceAccounts = String.join(remittanceNameList, ', ');
                configRow.remittanceAccountNames = remittanceNameList;
            } else if (!globalRemittanceNames.isEmpty()) {
                configRow.remittanceAccounts = String.join(globalRemittanceNames, ', ');
                configRow.remittanceAccountNames = new List<String>(globalRemittanceNames);
            } else {
                configRow.remittanceAccounts = '-';
                configRow.remittanceAccountNames = new List<String>();
            }
            configurationRows.add(configRow);
        }

        List<UsageCategoryRow> usageRows = new List<UsageCategoryRow>();
        List<String> usageCategoryNames = new List<String>();
        usageCategoryNames.addAll(usageCountByCategory.keySet());
        usageCategoryNames.sort();
        for (String categoryName : usageCategoryNames) {
            UsageCategoryRow usageRow = new UsageCategoryRow();
            usageRow.categoryName = categoryName;
            usageRow.students = usageCountByCategory.get(categoryName);
            usageRows.add(usageRow);
        }

        ProgrammeFeeRecordData dto = new ProgrammeFeeRecordData();
        dto.feeTypeId = feeTypeRecord.Id;
        dto.programmeFeeName = buildProgrammeFeeDisplayName(
            feeTypeRecord.Fee_Type_Name__c,
            feeTypeRecord.Name,
            feeTypeRecord.Batch__c
        );
        dto.linkLevel = feeTypeRecord.Institute__c == null
            ? (feeTypeRecord.Learning_Program_Plan__r != null ? LINK_LEVEL_LEARNING_PROGRAM_PLAN : LINK_LEVEL_LEARNING_PROGRAM)
            : LINK_LEVEL_INSTITUTE;
        dto.instituteId = feeTypeRecord.Institute__c;
        dto.learningProgramId = feeTypeRecord.Learning_Program__c;
        dto.feeCategory = feeTypeRecord.Fee_Category__c;
        dto.contextName = feeTypeRecord.Institute__r != null && !String.isBlank(feeTypeRecord.Institute__r.Name)
            ? feeTypeRecord.Institute__r.Name
            : (feeTypeRecord.Learning_Program_Plan__r != null && !String.isBlank(feeTypeRecord.Learning_Program_Plan__r.Name)
                ? feeTypeRecord.Learning_Program_Plan__r.Name
                : (feeTypeRecord.Learning_Program__r == null ? '-' : feeTypeRecord.Learning_Program__r.Name));
        dto.programmeName = dto.contextName;
        dto.batchIntake = String.isBlank(feeTypeRecord.Batch__c) ? '-' : feeTypeRecord.Batch__c;
        dto.totalAmount = feeTypeRecord.Total_Amount__c == null ? 0 : feeTypeRecord.Total_Amount__c;
        dto.academicYear = resolveFeeTypeAcademicYearValue(feeTypeRecord);
        dto.frequency = String.isBlank(feeTypeRecord.Fee_Collection_Frequency__c)
            ? '-'
            : feeTypeRecord.Fee_Collection_Frequency__c;
        dto.activationDate = Date.newInstance(
            feeTypeRecord.CreatedDate.year(),
            feeTypeRecord.CreatedDate.month(),
            feeTypeRecord.CreatedDate.day()
        );
        dto.status = String.isBlank(feeTypeRecord.Status__c) ? 'Draft' : feeTypeRecord.Status__c;
        dto.createdByName = feeTypeRecord.CreatedBy == null ? '-' : feeTypeRecord.CreatedBy.Name;
        dto.createdDate = feeTypeRecord.CreatedDate;
        dto.lastModified = feeTypeRecord.LastModifiedDate;
        dto.notes = feeTypeRecord.Description__c;
        dto.defaultPenaltyPlanName = feeTypeRecord.Late_Fee_Plan__r == null
            ? '-'
            : (String.isBlank(feeTypeRecord.Late_Fee_Plan__r.Fee_Type_Name__c)
                ? feeTypeRecord.Late_Fee_Plan__r.Name
                : feeTypeRecord.Late_Fee_Plan__r.Fee_Type_Name__c);
        dto.paymentGatewayName = '-';
        dto.defaultRemittanceName = '-';
        dto.remittanceAccountNames = new List<String>();
        Set<String> remittanceNames = new Set<String>();
        remittanceNames.addAll(globalRemittanceNames);
        if (remittanceNames.isEmpty() && !lineRecords.isEmpty() && lineRecords[0].Remittance_Account__r != null) {
            remittanceNames.add(lineRecords[0].Remittance_Account__r.Bank_Account_Name__c);
        }
        if (!remittanceNames.isEmpty()) {
            List<String> remittanceNameList = new List<String>();
            remittanceNameList.addAll(remittanceNames);
            remittanceNameList.sort();
            dto.defaultRemittanceName = String.join(remittanceNameList, ', ');
            dto.remittanceAccountNames = remittanceNameList;
        }
        dto.usedInAssignments = getAssignmentCountByFeeTypeId(new Set<Id>{ feeTypeId }).get(feeTypeId);
        dto.configurationRows = configurationRows;
        dto.usageCategories = usageRows;

        List<SimpleHistoryRow> amendments = new List<SimpleHistoryRow>();
        SimpleHistoryRow amendmentRow = new SimpleHistoryRow();
        amendmentRow.versionLabel = 'v1.0';
        amendmentRow.changedAt = feeTypeRecord.LastModifiedDate;
        amendmentRow.userName = dto.createdByName;
        amendmentRow.details = dto.status.toLowerCase() == 'active'
            ? 'Initial activation for ' + dto.batchIntake
            : 'Initial draft for ' + dto.batchIntake;
        amendmentRow.status = dto.status;
        amendments.add(amendmentRow);
        dto.amendmentHistory = amendments;

        List<SimpleHistoryRow> audits = new List<SimpleHistoryRow>();
        SimpleHistoryRow createdRow = new SimpleHistoryRow();
        createdRow.action = 'Created';
        createdRow.userName = dto.createdByName;
        createdRow.changedAt = feeTypeRecord.CreatedDate;
        createdRow.details = 'Initial draft created';
        createdRow.status = 'Draft';
        audits.add(createdRow);

        if (dto.status.toLowerCase() == 'active') {
            SimpleHistoryRow activatedRow = new SimpleHistoryRow();
            activatedRow.action = 'Activated';
            activatedRow.userName = dto.createdByName;
            activatedRow.changedAt = feeTypeRecord.LastModifiedDate;
            activatedRow.details = 'Programme Fee configuration activated';
            activatedRow.status = 'Active';
            audits.add(0, activatedRow);
        }
        dto.auditTrail = audits;

        return dto;
    }

    private static String buildProgrammeFeeDisplayName(String preferredName, String fallbackName, String batchIntake) {
        String baseName = String.isBlank(preferredName) ? fallbackName : preferredName;
        if (String.isBlank(baseName)) {
            baseName = 'Programme Fee';
        }

        if (String.isBlank(batchIntake)) {
            return baseName;
        }

        // Normalize "<name> - <batch>" to "<name> | <batch>".
        String legacySuffix = ' - ' + batchIntake;
        if (baseName.endsWith(legacySuffix)) {
            return baseName.substring(0, baseName.length() - legacySuffix.length()) + ' | ' + batchIntake;
        }

        if (baseName.contains(' | ')) {
            return baseName;
        }

        if (!baseName.contains(batchIntake)) {
            return baseName + ' | ' + batchIntake;
        }

        return baseName;
    }

    private static String buildTermLabel(String frequencyValue, Integer yearNumber) {
        Integer safeNumber = yearNumber == null || yearNumber <= 0 ? 1 : yearNumber;
        String normalized = String.valueOf(frequencyValue).toLowerCase();
        if (normalized.contains('semester') || normalized.contains('term')) {
            return 'Semester ' + String.valueOf(safeNumber);
        }
        if (normalized.contains('year')) {
            return 'Year ' + String.valueOf(safeNumber);
        }
        if (normalized.contains('one')) {
            return 'Configuration 1';
        }
        return 'Schedule ' + String.valueOf(safeNumber);
    }

    @AuraEnabled(cacheable=true)
    public static BuilderSeedData getBuilderSeedData() {
        BuilderSeedData seed = new BuilderSeedData();
        seed.programmeOptions = new List<OptionRow>();
        seed.feePlanOptions = new List<OptionRow>();
        seed.feeHeadOptions = new List<OptionRow>();
        seed.categoryOptions = new List<OptionRow>();
        seed.quotaOptions = new List<OptionRow>();
        seed.feeCategoryOptions = new List<OptionRow>();
        seed.remittanceOptions = new List<OptionRow>();
        seed.remittanceMerchantRows = new List<RemittanceMerchantRow>();
        seed.paymentGatewayOptions = new List<OptionRow>();
        seed.installmentOptions = new List<OptionRow>();
        seed.feeAssignmentTriggerPointOptions = new List<OptionRow>();
        seed.penaltyPlanOptions = new List<OptionRow>();
        seed.programmeYearRanges = new List<ProgrammeYearRangeRow>();

        // Programme field should list Learning Program Plans.
        try {
            Schema.DescribeSObjectResult planDescribe = LearningProgramPlan.SObjectType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = planDescribe.fields.getMap();
            if (fieldMap.containsKey('LearningProgramId')) {
                List<String> queryFields = new List<String>{ 'Id', 'Name', 'LearningProgramId', 'LearningProgram.Name' };

                if (fieldMap.containsKey('Start_Year__c')) queryFields.add('Start_Year__c');
                if (fieldMap.containsKey('End_Year__c')) queryFields.add('End_Year__c');
                if (fieldMap.containsKey('Program_Start_Year__c')) queryFields.add('Program_Start_Year__c');
                if (fieldMap.containsKey('Program_End_Year__c')) queryFields.add('Program_End_Year__c');
                if (fieldMap.containsKey('Academic_Start_Year__c')) queryFields.add('Academic_Start_Year__c');
                if (fieldMap.containsKey('Academic_End_Year__c')) queryFields.add('Academic_End_Year__c');
                if (fieldMap.containsKey('StartDate')) queryFields.add('StartDate');
                if (fieldMap.containsKey('EndDate')) queryFields.add('EndDate');

                String queryText = 'SELECT ' + String.join(queryFields, ',') +
                    ' FROM LearningProgramPlan WHERE LearningProgramId != null ORDER BY Name ASC LIMIT 500';

                for (SObject planRecord : Database.query(queryText)) {
                    String planId = String.valueOf(planRecord.get('Id'));
                    String planName = String.valueOf(planRecord.get('Name'));
                    String learningProgramName = null;
                    SObject learningProgram = planRecord.getSObject('LearningProgram');
                    if (learningProgram != null) {
                        learningProgramName = String.valueOf(learningProgram.get('Name'));
                    }

                    OptionRow option = new OptionRow();
                    option.value = planId;
                    option.label = String.isBlank(learningProgramName)
                        ? planName
                        : learningProgramName + ' - ' + planName;
                    seed.programmeOptions.add(option);

                    Integer startYear = extractYearFromPlanRecord(
                        planRecord,
                        new List<String>{ 'Start_Year__c', 'Program_Start_Year__c', 'Academic_Start_Year__c' },
                        'StartDate'
                    );
                    Integer endYear = extractYearFromPlanRecord(
                        planRecord,
                        new List<String>{ 'End_Year__c', 'Program_End_Year__c', 'Academic_End_Year__c' },
                        'EndDate'
                    );

                    if ((startYear != null || endYear != null) && !String.isBlank(planId)) {
                        ProgrammeYearRangeRow yearRange = new ProgrammeYearRangeRow();
                        yearRange.programmeId = planId;
                        yearRange.startYear = startYear;
                        yearRange.endYear = endYear;
                        seed.programmeYearRanges.add(yearRange);
                    }
                }
            }
        } catch (Exception ex) {
            // Keep page functional even when LearningProgramPlan metadata differs by org.
        }

        for (Ken_Fee_Set__c feeSet : [
            SELECT Id, Name
            FROM Ken_Fee_Set__c
            WHERE Name != null
            ORDER BY LastModifiedDate DESC
            LIMIT 300
        ]) {
            OptionRow option = new OptionRow();
            option.value = String.valueOf(feeSet.Id);
            option.label = feeSet.Name;
            seed.feePlanOptions.add(option);
        }

        for (Ken_Master_Fee_Head__c feeHead : [
            SELECT Id, Fee_Head_Name__c
            FROM Ken_Master_Fee_Head__c
            WHERE Fee_Head_Name__c != null AND Is_Active__c = true
            ORDER BY Fee_Head_Name__c ASC
            LIMIT 300
        ]) {
            OptionRow option = new OptionRow();
            option.value = String.valueOf(feeHead.Id);
            option.label = feeHead.Fee_Head_Name__c;
            seed.feeHeadOptions.add(option);
        }

        for (Category__c categoryRow : [
            SELECT Id, Name
            FROM Category__c
            WHERE Name != null
            ORDER BY Name ASC
            LIMIT 300
        ]) {
            OptionRow option = new OptionRow();
            option.value = String.valueOf(categoryRow.Id);
            option.label = categoryRow.Name;
            seed.categoryOptions.add(option);
        }

        for (Quota__c quotaRow : [
            SELECT Id, Name, Code__c
            FROM Quota__c
            WHERE Name != null
            ORDER BY Name ASC
            LIMIT 300
        ]) {
            OptionRow option = new OptionRow();
            option.value = String.valueOf(quotaRow.Id);
            option.label = String.isBlank(quotaRow.Code__c)
                ? quotaRow.Name
                : quotaRow.Name + ' (' + quotaRow.Code__c + ')';
            seed.quotaOptions.add(option);
        }

        for (Schema.PicklistEntry categoryEntry :
            Ken_Fee_Type__c.Fee_Category__c.getDescribe().getPicklistValues()
        ) {
            if (categoryEntry.isActive()) {
                OptionRow option = new OptionRow();
                option.value = categoryEntry.getValue();
                option.label = categoryEntry.getLabel();
                seed.feeCategoryOptions.add(option);
            }
        }

        for (Ken_Bank_Account_Master__c remittance : [
            SELECT Id, Bank_Account_Name__c, Account_Number__c
            FROM Ken_Bank_Account_Master__c
            WHERE Bank_Account_Name__c != null
            ORDER BY Bank_Account_Name__c ASC
            LIMIT 300
        ]) {
            OptionRow option = new OptionRow();
            option.value = String.valueOf(remittance.Id);
            option.label = remittance.Bank_Account_Name__c;
            seed.remittanceOptions.add(option);

            if (!String.isBlank(remittance.Account_Number__c)) {
                RemittanceMerchantRow merchantRow = new RemittanceMerchantRow();
                merchantRow.remittanceId = String.valueOf(remittance.Id);
                merchantRow.merchantIds = remittance.Account_Number__c;
                seed.remittanceMerchantRows.add(merchantRow);
            }
        }

        for (Payment_Gateway__c gateway : [
            SELECT Id, Name
            FROM Payment_Gateway__c
            LIMIT 300
        ]) {
            OptionRow option = new OptionRow();
            option.value = String.valueOf(gateway.Id);
            option.label = String.isBlank(gateway.Name) ? 'Gateway ' + String.valueOf(gateway.Id) : gateway.Name;
            seed.paymentGatewayOptions.add(option);
        }

        for (Payment_Schedule__c scheduleRow : [
            SELECT Id, Name
            FROM Payment_Schedule__c
            WHERE Name != null
            ORDER BY Name ASC
            LIMIT 300
        ]) {
            OptionRow option = new OptionRow();
            option.value = String.valueOf(scheduleRow.Id);
            option.label = scheduleRow.Name;
            seed.installmentOptions.add(option);
        }

        for (Schema.PicklistEntry triggerPointEntry :
            Ken_Fee_Type_Line_Item__c.Fee_Assignment_Trigger_Point__c.getDescribe().getPicklistValues()
        ) {
            OptionRow option = new OptionRow();
            option.value = triggerPointEntry.getValue();
            option.label = triggerPointEntry.getLabel();
            seed.feeAssignmentTriggerPointOptions.add(option);
        }

        for (Ken_Fee_Type__c penaltyRow : [
            SELECT Id, Name, Fee_Type_Name__c
            FROM Ken_Fee_Type__c
            WHERE RecordType.DeveloperName = 'Late_Fee'
            ORDER BY LastModifiedDate DESC
            LIMIT 300
        ]) {
            OptionRow option = new OptionRow();
            option.value = String.valueOf(penaltyRow.Id);
            option.label = String.isBlank(penaltyRow.Fee_Type_Name__c)
                ? penaltyRow.Name
                : penaltyRow.Fee_Type_Name__c;
            seed.penaltyPlanOptions.add(option);
        }

        return seed;
    }

    @AuraEnabled(cacheable=true)
    public static SaveProgrammeFeeRequest getProgrammeFeeConfigurationForEdit(Id feeTypeId) {
        if (feeTypeId == null) {
            throw new AuraHandledException('Programme Fee Id is required.');
        }

        String feeTypeQuery =
            'SELECT Id,' +
            ' Learning_Program_Plan__c,' +
            ' Learning_Program__c,' +
            ' Fee_Category__c,' +
            ' Batch__c,' +
            ' Fee_Collection_Frequency__c,' +
            ' Description__c,' +
            ' Payment_Schedule__c,' +
            ' Late_Fee_Plan__c,' +
            ' CreatedDate';
        if (hasFeeTypeField('Institute__c')) {
            feeTypeQuery += ', Institute__c';
        }
        String academicYearFieldApiName = resolveAcademicYearFieldApiName();
        if (!String.isBlank(academicYearFieldApiName)) {
            feeTypeQuery += ', ' + academicYearFieldApiName;
        }
        feeTypeQuery += ' FROM Ken_Fee_Type__c WHERE Id = :feeTypeId LIMIT 1';
        Ken_Fee_Type__c feeTypeRecord = (Ken_Fee_Type__c) Database.query(feeTypeQuery);

        List<Ken_Fee_Type_Remittance__c> remittanceLinks = [
            SELECT Remittance_Account__c
            FROM Ken_Fee_Type_Remittance__c
            WHERE Ken_Fee_Type__c = :feeTypeId
            ORDER BY CreatedDate ASC
        ];

        String feeTypeLineQuery =
            'SELECT Program_Year_Number__c,' +
            ' Fee_Set__c,' +
            ' Fee_Head__c,' +
            ' Student_Category__c,' +
            ' Fee_Assignment_Trigger_Point__c,' +
            ' Fee_Type_Line_Key__c,' +
            ' Start_Date__c,' +
            ' Due_Date__c,' +
            ' Amount__c,' +
            ' Remittance_Account__c,' +
            ' Fee_Period_Label__c';
        if (hasFeeTypeLineField('Category__c')) {
            feeTypeLineQuery += ', Category__c';
        }
        if (hasFeeTypeLineField('Quota__c')) {
            feeTypeLineQuery += ', Quota__c';
        }
        feeTypeLineQuery +=
            ' FROM Ken_Fee_Type_Line_Item__c' +
            ' WHERE Ken_Fee_Type__c = :feeTypeId' +
            ' ORDER BY Program_Year_Number__c ASC, LastModifiedDate ASC';
        List<Ken_Fee_Type_Line_Item__c> lineRecords = (List<Ken_Fee_Type_Line_Item__c>) Database.query(feeTypeLineQuery);

        SaveProgrammeFeeRequest dto = new SaveProgrammeFeeRequest();
        dto.feeTypeId = feeTypeRecord.Id;
        dto.programmeId = feeTypeRecord.Learning_Program_Plan__c;
        dto.learningProgramId = (Id) feeTypeRecord.get('Learning_Program__c');
        dto.linkLevel = LINK_LEVEL_LEARNING_PROGRAM_PLAN;
        if (hasFeeTypeField('Institute__c')) {
            Object instituteValue = feeTypeRecord.get('Institute__c');
            if (instituteValue != null) {
                dto.instituteId = (Id) instituteValue;
            }
        }
        dto.linkedMappings = buildLinkedMappingsForEdit(dto.programmeId, dto.learningProgramId, dto.instituteId);
        if (dto.programmeId == null && dto.learningProgramId != null) {
            dto.linkLevel = LINK_LEVEL_LEARNING_PROGRAM;
        }
        if (dto.programmeId == null && dto.learningProgramId == null && dto.instituteId != null) {
            dto.linkLevel = LINK_LEVEL_INSTITUTE;
        }
        dto.feeCategory = feeTypeRecord.Fee_Category__c;
        dto.batchIntake = feeTypeRecord.Batch__c;
        dto.frequency = feeTypeRecord.Fee_Collection_Frequency__c;
        dto.notes = feeTypeRecord.Description__c;
        dto.activationDate = Date.newInstance(
            feeTypeRecord.CreatedDate.year(),
            feeTypeRecord.CreatedDate.month(),
            feeTypeRecord.CreatedDate.day()
        );
        dto.remittanceAccountIds = new List<Id>();

        for (Ken_Fee_Type_Remittance__c remittanceLink : remittanceLinks) {
            if (remittanceLink.Remittance_Account__c != null) {
                dto.remittanceAccountIds.add(remittanceLink.Remittance_Account__c);
            }
        }
        if (dto.defaultRemittanceId == null && !dto.remittanceAccountIds.isEmpty()) {
            dto.defaultRemittanceId = dto.remittanceAccountIds[0];
        }

        Map<Integer, PublishConfigRow> configByYear = new Map<Integer, PublishConfigRow>();
        for (Ken_Fee_Type_Line_Item__c lineRecord : lineRecords) {
            Integer rowYearNumber = lineRecord.Program_Year_Number__c == null
                ? 1
                : Integer.valueOf(lineRecord.Program_Year_Number__c);
            if (!configByYear.containsKey(rowYearNumber)) {
                PublishConfigRow row = new PublishConfigRow();
                row.programYearNumber = rowYearNumber;
                row.academicYearLabel = resolveFeeTypeAcademicYearValue(feeTypeRecord);
                row.feePlanId = lineRecord.Fee_Set__c;
                row.feeHeadId = lineRecord.Fee_Head__c;
                row.categoryId = hasFeeTypeLineField('Category__c') ? (Id) lineRecord.get('Category__c') : null;
                row.quotaId = hasFeeTypeLineField('Quota__c') ? (Id) lineRecord.get('Quota__c') : null;
                row.feeAssignmentTriggerPoint = lineRecord.Fee_Assignment_Trigger_Point__c;
                row.tag = lineRecord.Fee_Type_Line_Key__c;
                row.startDate = lineRecord.Start_Date__c;
                row.dueDate = lineRecord.Due_Date__c;
                row.amount = lineRecord.Amount__c;
                row.remittanceOverrideId = lineRecord.Remittance_Account__c;
                row.installmentId = feeTypeRecord.Payment_Schedule__c;
                row.penaltyPlanId = feeTypeRecord.Late_Fee_Plan__c;
                configByYear.put(rowYearNumber, row);
                if (dto.oneTimeAmount == null) {
                    dto.oneTimeAmount = lineRecord.Amount__c;
                }
            }

            if (dto.defaultRemittanceId == null && lineRecord.Remittance_Account__c != null) {
                dto.defaultRemittanceId = lineRecord.Remittance_Account__c;
            }
        }

        String normalizedFrequency = String.valueOf(dto.frequency).toLowerCase();
        if (normalizedFrequency.contains('one')) {
            if (!configByYear.isEmpty()) {
                List<Integer> yearKeys = new List<Integer>();
                yearKeys.addAll(configByYear.keySet());
                yearKeys.sort();
                PublishConfigRow oneTimeRow = configByYear.get(yearKeys[0]);
                dto.oneTimeFeePlanId = oneTimeRow.feePlanId;
                dto.oneTimeFeeHeadId = oneTimeRow.feeHeadId;
                dto.oneTimeCategoryId = oneTimeRow.categoryId;
                dto.oneTimeQuotaId = oneTimeRow.quotaId;
                dto.oneTimeFeeAssignmentTriggerPoint = oneTimeRow.feeAssignmentTriggerPoint;
                dto.oneTimeFeePlanTag = oneTimeRow.tag;
                dto.oneTimeStartDate = oneTimeRow.startDate;
                dto.oneTimeDueDate = oneTimeRow.dueDate;
                dto.oneTimeRemittanceOverrideId = oneTimeRow.remittanceOverrideId;
                dto.oneTimeInstallmentId = feeTypeRecord.Payment_Schedule__c;
                dto.oneTimePenaltyPlanId = feeTypeRecord.Late_Fee_Plan__c;
            }
        } else {
            List<Integer> yearKeys = new List<Integer>();
            yearKeys.addAll(configByYear.keySet());
            yearKeys.sort();

            dto.configRows = new List<PublishConfigRow>();
            for (Integer rowKey : yearKeys) {
                dto.configRows.add(configByYear.get(rowKey));
            }

            if (normalizedFrequency.contains('term')) {
                dto.termSystem = 'Semester';
                String firstDetectedTermSystem;
                for (Ken_Fee_Type_Line_Item__c lineRecord : lineRecords) {
                    String label = String.valueOf(lineRecord.Fee_Period_Label__c).toLowerCase();
                    if (firstDetectedTermSystem == null && label.contains('tri')) {
                        firstDetectedTermSystem = 'Trimester';
                    }
                    if (firstDetectedTermSystem == null && label.contains('quad')) {
                        firstDetectedTermSystem = 'Quadmester';
                    }
                }
                if (!String.isBlank(firstDetectedTermSystem)) {
                    dto.termSystem = firstDetectedTermSystem;
                }
            }
        }

        return dto;
    }

    @AuraEnabled
    public static Id saveProgrammeFeeConfiguration(String requestJson, Boolean activateNow) {
        if (String.isBlank(requestJson)) {
            throw new AuraHandledException('Request payload is required.');
        }

        SaveProgrammeFeeRequest requestData =
            (SaveProgrammeFeeRequest) JSON.deserialize(requestJson, SaveProgrammeFeeRequest.class);

        if (requestData == null) {
            throw new AuraHandledException('Request is required.');
        }
        Map<String, Id> linkedIdsByLevel = normalizeLinkedIdsByLevel(requestData);
        Id learningProgramPlanId = linkedIdsByLevel.get(LINK_LEVEL_LEARNING_PROGRAM_PLAN);
        Id learningProgramId = linkedIdsByLevel.get(LINK_LEVEL_LEARNING_PROGRAM);
        Id instituteId = linkedIdsByLevel.get(LINK_LEVEL_INSTITUTE);
        String normalizedLinkLevel = normalizeLinkLevel(requestData, linkedIdsByLevel);

        if (learningProgramPlanId == null && learningProgramId == null && instituteId == null) {
            throw new AuraHandledException('At least one link level is required.');
        }
        if (instituteId != null && !hasFeeTypeField('Institute__c')) {
            throw new AuraHandledException('Institute linkage is not available in this org.');
        }
        if (learningProgramId != null && !hasFeeTypeField('Learning_Program__c')) {
            throw new AuraHandledException('Learning Program linkage is not available in this org.');
        }
        if (String.isBlank(requestData.batchIntake) && (learningProgramPlanId != null || learningProgramId != null)) {
            throw new AuraHandledException('Batch / Intake is required.');
        }
        if (requestData.activationDate == null) {
            throw new AuraHandledException('Activation Date is required.');
        }
        if (String.isBlank(requestData.frequency)) {
            throw new AuraHandledException('Frequency is required.');
        }
        List<Id> effectiveRemittanceAccountIds = new List<Id>();
        if (requestData.remittanceAccountIds != null) {
            Set<Id> seenRemittanceIds = new Set<Id>();
            for (Id remittanceId : requestData.remittanceAccountIds) {
                if (remittanceId != null && !seenRemittanceIds.contains(remittanceId)) {
                    seenRemittanceIds.add(remittanceId);
                    effectiveRemittanceAccountIds.add(remittanceId);
                }
            }
        }
        if (effectiveRemittanceAccountIds.isEmpty() && requestData.defaultRemittanceId != null) {
            effectiveRemittanceAccountIds.add(requestData.defaultRemittanceId);
        }
        if (effectiveRemittanceAccountIds.isEmpty()) {
            throw new AuraHandledException('At least one Remittance Account is required.');
        }

        String resolvedFeeCategory = normalizeFeeCategoryForSave(requestData.feeCategory);
        Boolean isFeeTypeMode = requestData != null && requestData.isFeeTypeMode == true;
        Boolean isStructureMode = !isFeeTypeMode && isAcademicFeeCategory(resolvedFeeCategory);
        Boolean isOneTime = String.valueOf(requestData.frequency).toLowerCase().contains('one');
        if (isOneTime) {
            Boolean hasOneTimePrimary = requestData.oneTimeFeePlanId != null || requestData.oneTimeFeeHeadId != null;
            if (!hasOneTimePrimary || requestData.oneTimeDueDate == null) {
                throw new AuraHandledException('Fee configuration and Due Date are required for One-time frequency.');
            }
            if (requestData.oneTimeFeeHeadId != null && requestData.oneTimeAmount == null) {
                throw new AuraHandledException('Amount is required when Fee Head is selected.');
            }
        } else {
            if (requestData.configRows == null || requestData.configRows.isEmpty()) {
                throw new AuraHandledException('At least one configuration row is required.');
            }
            for (PublishConfigRow row : requestData.configRows) {
                if (row != null && row.feeHeadId != null && row.amount == null) {
                    throw new AuraHandledException('Amount is required for each Fee Head row.');
                }
            }
        }

        Id selectedContextRecordId = learningProgramPlanId != null
            ? learningProgramPlanId
            : learningProgramId != null
                ? learningProgramId
                : instituteId;

        String parentStatus = activateNow == true ? 'Active' : 'Draft';
        Id preferredPenaltyPlanId = requestData.oneTimePenaltyPlanId;
        Id preferredInstallmentId = requestData.oneTimeInstallmentId;
        if (preferredPenaltyPlanId == null && requestData.configRows != null) {
            for (PublishConfigRow row : requestData.configRows) {
                if (preferredPenaltyPlanId == null && row != null && row.penaltyPlanId != null) {
                    preferredPenaltyPlanId = row.penaltyPlanId;
                }
            }
        }
        if (preferredInstallmentId == null && requestData.configRows != null) {
            for (PublishConfigRow row : requestData.configRows) {
                if (preferredInstallmentId == null && row != null && row.installmentId != null) {
                    preferredInstallmentId = row.installmentId;
                }
            }
        }

        String selectedContextName = resolveSelectedContextName(
            learningProgramPlanId,
            learningProgramId,
            instituteId
        );

        validateNoDuplicateProgrammeFeeConfiguration(
            requestData.feeTypeId,
            learningProgramPlanId,
            learningProgramId,
            instituteId,
            requestData.batchIntake,
            resolvedFeeCategory,
            requestData.frequency
        );

        String generatedName = String.isBlank(requestData.batchIntake)
            ? selectedContextName
            : selectedContextName + ' | ' + requestData.batchIntake;

        Boolean isEditMode = requestData.feeTypeId != null;
        List<PublishConfigRow> effectiveRows = new List<PublishConfigRow>();
        if (isOneTime) {
            PublishConfigRow oneTimeRow = new PublishConfigRow();
            oneTimeRow.programYearNumber = 1;
            oneTimeRow.feePlanId = requestData.oneTimeFeePlanId;
            oneTimeRow.feeHeadId = requestData.oneTimeFeeHeadId;
            oneTimeRow.categoryId = requestData.oneTimeCategoryId;
            oneTimeRow.quotaId = requestData.oneTimeQuotaId;
            oneTimeRow.feeAssignmentTriggerPoint = requestData.oneTimeFeeAssignmentTriggerPoint;
            oneTimeRow.tag = requestData.oneTimeFeePlanTag;
            oneTimeRow.amount = requestData.oneTimeAmount;
            oneTimeRow.startDate = requestData.oneTimeStartDate;
            oneTimeRow.dueDate = requestData.oneTimeDueDate;
            oneTimeRow.remittanceOverrideId = requestData.oneTimeRemittanceOverrideId;
            oneTimeRow.installmentId = requestData.oneTimeInstallmentId;
            oneTimeRow.penaltyPlanId = requestData.oneTimePenaltyPlanId;
            effectiveRows.add(oneTimeRow);
        } else {
            for (PublishConfigRow row : requestData.configRows) {
                if (row != null && rowHasPrimaryConfigForMode(row, isStructureMode) && row.dueDate != null) {
                    effectiveRows.add(row);
                }
            }
            if (effectiveRows.isEmpty()) {
                if (isStructureMode) {
                    throw new AuraHandledException('Configure at least one row with Fee Plan and Due Date.');
                }
                throw new AuraHandledException('Configure at least one row with Fee Head and Due Date.');
            }
        }

        Set<Id> feeSetIds = new Set<Id>();
        Set<Id> feeHeadIds = new Set<Id>();
        Set<Id> categoryIds = new Set<Id>();
        Set<Id> quotaIds = new Set<Id>();
        for (PublishConfigRow row : effectiveRows) {
            if (row.feePlanId != null) {
                feeSetIds.add(row.feePlanId);
            }
            if (row.feeHeadId != null) {
                feeHeadIds.add(row.feeHeadId);
            }
            if (row.categoryId != null) {
                categoryIds.add(row.categoryId);
            }
            if (row.quotaId != null) {
                quotaIds.add(row.quotaId);
            }
        }

        Map<Id, List<FeeSetLineSourceRow>> feeSetLinesById = queryFeeSetLinesById(feeSetIds);
        validateFeePlanSourceLines(effectiveRows, feeSetLinesById, isStructureMode);

        Map<Id, Ken_Master_Fee_Head__c> feeHeadById = new Map<Id, Ken_Master_Fee_Head__c>();
        if (!feeHeadIds.isEmpty()) {
            feeHeadById = new Map<Id, Ken_Master_Fee_Head__c>([
                SELECT Id, Tax_Definition__c, Default_Remittance_Account__c
                FROM Ken_Master_Fee_Head__c
                WHERE Id IN :feeHeadIds
            ]);
        }

        Map<Id, Category__c> categoryById = categoryIds.isEmpty()
            ? new Map<Id, Category__c>()
            : new Map<Id, Category__c>([
                SELECT Id, Name
                FROM Category__c
                WHERE Id IN :categoryIds
            ]);
        Map<Id, Quota__c> quotaById = quotaIds.isEmpty()
            ? new Map<Id, Quota__c>()
            : new Map<Id, Quota__c>([
                SELECT Id, Name, Code__c, Category__c
                FROM Quota__c
                WHERE Id IN :quotaIds
            ]);
        List<Ken_Fee_Type__c> feeTypeRecordsToInsert = new List<Ken_Fee_Type__c>();
        List<PublishConfigRow> parentRows = new List<PublishConfigRow>();
        Id preferredRecordTypeId = resolvePreferredFeeTypeRecordTypeId();
        for (PublishConfigRow configRow : effectiveRows) {
            Integer rowYearNumber = (configRow.programYearNumber == null || configRow.programYearNumber <= 0)
                ? 1
                : configRow.programYearNumber;
            Ken_Fee_Type__c feeTypeRecord = new Ken_Fee_Type__c(
                Fee_Type_Name__c = generatedName + ' | ' + buildLinePeriodLabel(
                    requestData.frequency,
                    requestData.termSystem,
                    rowYearNumber
                ),
                Batch__c = requestData.batchIntake,
                Learning_Program_Plan__c = learningProgramPlanId,
                Fee_Collection_Frequency__c = requestData.frequency,
                Fee_Category__c = resolvedFeeCategory,
                Status__c = parentStatus,
                Description__c = requestData.notes,
                Institute__c = instituteId,
                Payment_Schedule__c = configRow.installmentId != null
                    ? configRow.installmentId
                    : preferredInstallmentId,
                Late_Fee_Plan__c = configRow.penaltyPlanId != null
                    ? configRow.penaltyPlanId
                    : preferredPenaltyPlanId,
                Fee_Type_Plan_Key__c = buildFeeTypePlanKey(
                    new List<PublishConfigRow>{ configRow },
                    requestData.frequency
                )
            );
            applyAcademicYearToFeeType(
                feeTypeRecord,
                resolveAcademicYearValue(configRow, requestData)
            );
            if (hasFeeTypeField('Learning_Program__c')) {
                feeTypeRecord.put('Learning_Program__c', learningProgramId);
            }
            if (preferredRecordTypeId != null) {
                feeTypeRecord.RecordTypeId = preferredRecordTypeId;
            }
            feeTypeRecordsToInsert.add(feeTypeRecord);
            parentRows.add(configRow);
        }

        if (isEditMode && requestData.feeTypeId != null) {
            List<Ken_Fee_Type__c> existingParents = [
                SELECT Id
                FROM Ken_Fee_Type__c
                WHERE Id = :requestData.feeTypeId
            ];
            if (!existingParents.isEmpty()) {
                delete existingParents;
            }
        }

        insert feeTypeRecordsToInsert;

        List<Ken_Fee_Type_Line_Item__c> feeTypeLineRecords = new List<Ken_Fee_Type_Line_Item__c>();
        List<Ken_Fee_Type_Remittance__c> remittanceLinksToSave = new List<Ken_Fee_Type_Remittance__c>();
        for (Integer parentIndex = 0; parentIndex < feeTypeRecordsToInsert.size(); parentIndex++) {
            Ken_Fee_Type__c feeTypeRecord = feeTypeRecordsToInsert[parentIndex];
            PublishConfigRow configRow = parentRows[parentIndex];
            Integer rowYearNumber = (configRow.programYearNumber == null || configRow.programYearNumber <= 0)
                ? 1
                : configRow.programYearNumber;
            List<FeeSetLineSourceRow> sourceLines = feeSetLinesById.get(configRow.feePlanId);
            if (sourceLines != null && !sourceLines.isEmpty()) {
                for (FeeSetLineSourceRow sourceLine : sourceLines) {
                    Ken_Fee_Type_Line_Item__c targetLine = new Ken_Fee_Type_Line_Item__c(
                        Ken_Fee_Type__c = feeTypeRecord.Id,
                        Program_Year_Number__c = rowYearNumber,
                        Fee_Set__c = configRow.feePlanId,
                        Fee_Type_Line_Key__c = String.isBlank(configRow.tag) ? null : configRow.tag.trim(),
                        Fee_Period_Label__c = buildLinePeriodLabel(
                            requestData.frequency,
                            requestData.termSystem,
                            rowYearNumber
                        ),
                        Fee_Assignment_Trigger_Point__c = configRow.feeAssignmentTriggerPoint,
                        Fee_Head__c = sourceLine.feeHeadId,
                        Student_Category__c = sourceLine.studentCategory,
                        Amount__c = sourceLine.amount,
                        Start_Date__c = configRow.startDate,
                        Due_Date__c = configRow.dueDate,
                        Remittance_Account__c = configRow.remittanceOverrideId != null
                            ? configRow.remittanceOverrideId
                            : sourceLine.remittanceAccountId,
                        Tax__c = sourceLine.taxId,
                        Is_Active__c = activateNow == true
                    );
                    PublishConfigRow lineConfig = new PublishConfigRow();
                    lineConfig.categoryId = sourceLine.categoryId != null ? sourceLine.categoryId : configRow.categoryId;
                    lineConfig.quotaId = sourceLine.quotaId != null ? sourceLine.quotaId : configRow.quotaId;
                    applyCategoryQuotaToFeeTypeLine(targetLine, lineConfig, categoryById, quotaById);
                    assignLinkLevelToFeeTypeLine(
                        targetLine,
                        learningProgramPlanId,
                        learningProgramId,
                        instituteId
                    );
                    feeTypeLineRecords.add(targetLine);
                }
            } else if (configRow.feeHeadId != null) {
                Ken_Master_Fee_Head__c selectedFeeHead = feeHeadById.get(configRow.feeHeadId);
                Id resolvedRemittanceId = configRow.remittanceOverrideId;
                if (resolvedRemittanceId == null && selectedFeeHead != null) {
                    resolvedRemittanceId = selectedFeeHead.Default_Remittance_Account__c;
                }
                if (resolvedRemittanceId == null && !effectiveRemittanceAccountIds.isEmpty()) {
                    resolvedRemittanceId = effectiveRemittanceAccountIds[0];
                }

                Ken_Fee_Type_Line_Item__c targetLine = new Ken_Fee_Type_Line_Item__c(
                    Ken_Fee_Type__c = feeTypeRecord.Id,
                    Program_Year_Number__c = rowYearNumber,
                    Fee_Set__c = null,
                    Fee_Type_Line_Key__c = String.isBlank(configRow.tag) ? null : configRow.tag.trim(),
                    Fee_Period_Label__c = buildLinePeriodLabel(
                        requestData.frequency,
                        requestData.termSystem,
                        rowYearNumber
                    ),
                    Fee_Assignment_Trigger_Point__c = configRow.feeAssignmentTriggerPoint,
                    Fee_Head__c = configRow.feeHeadId,
                    Amount__c = configRow.amount,
                    Start_Date__c = configRow.startDate,
                    Due_Date__c = configRow.dueDate,
                    Remittance_Account__c = resolvedRemittanceId,
                    Tax__c = selectedFeeHead == null ? null : selectedFeeHead.Tax_Definition__c,
                    Is_Active__c = activateNow == true
                );
                applyCategoryQuotaToFeeTypeLine(targetLine, configRow, categoryById, quotaById);
                assignLinkLevelToFeeTypeLine(
                    targetLine,
                    learningProgramPlanId,
                    learningProgramId,
                    instituteId
                );
                feeTypeLineRecords.add(targetLine);
            }

            for (Id remittanceId : effectiveRemittanceAccountIds) {
                remittanceLinksToSave.add(new Ken_Fee_Type_Remittance__c(
                    Ken_Fee_Type__c = feeTypeRecord.Id,
                    Remittance_Account__c = remittanceId
                ));
            }
        }

        if (!feeTypeLineRecords.isEmpty()) {
            insert feeTypeLineRecords;
        }
        if (!remittanceLinksToSave.isEmpty()) {
            insert remittanceLinksToSave;
        }

        return feeTypeRecordsToInsert[0].Id;
    }

    private static void validateNoDuplicateProgrammeFeeConfiguration(
        Id feeTypeId,
        Id learningProgramPlanId,
        Id learningProgramId,
        Id instituteId,
        String batchIntake,
        String feeCategory,
        String frequency
    ) {
        List<Ken_Fee_Type__c> existingRecords = [
            SELECT Id
            FROM Ken_Fee_Type__c
            WHERE Learning_Program_Plan__c = :learningProgramPlanId
              AND Learning_Program__c = :learningProgramId
              AND Institute__c = :instituteId
              AND Batch__c = :batchIntake
              AND Fee_Category__c = :feeCategory
              AND Fee_Collection_Frequency__c = :frequency
            LIMIT 2
        ];

        for (Ken_Fee_Type__c existingRecord : existingRecords) {
            if (feeTypeId == null || existingRecord.Id != feeTypeId) {
                throw new AuraHandledException(ERROR_DUPLICATE_PROGRAMME_FEE);
            }
        }
    }

    private static Map<Id, Integer> getAssignmentCountByFeeTypeId(Set<Id> feeTypeIds) {
        Map<Id, Integer> countsByFeeTypeId = new Map<Id, Integer>();
        if (feeTypeIds == null || feeTypeIds.isEmpty()) {
            return countsByFeeTypeId;
        }

        for (AggregateResult countRow : [
            SELECT Fee_Type__c feeTypeId, COUNT(Id) assignmentCount
            FROM Fee_Assignment__c
            WHERE Fee_Type__c IN :feeTypeIds
            GROUP BY Fee_Type__c
        ]) {
            countsByFeeTypeId.put(
                (Id) countRow.get('feeTypeId'),
                Integer.valueOf(String.valueOf(countRow.get('assignmentCount')))
            );
        }

        for (Id feeTypeId : feeTypeIds) {
            if (!countsByFeeTypeId.containsKey(feeTypeId)) {
                countsByFeeTypeId.put(feeTypeId, 0);
            }
        }
        return countsByFeeTypeId;
    }

    private static Boolean rowHasPrimaryConfigForMode(PublishConfigRow row, Boolean isStructureMode) {
        if (row == null) {
            return false;
        }
        if (isStructureMode) {
            return row.feePlanId != null;
        }
        return row.feeHeadId != null;
    }

    private static Map<Id, List<FeeSetLineSourceRow>> queryFeeSetLinesById(Set<Id> feeSetIds) {
        Map<Id, List<FeeSetLineSourceRow>> linesByFeeSetId = new Map<Id, List<FeeSetLineSourceRow>>();
        if (feeSetIds == null || feeSetIds.isEmpty()) {
            return linesByFeeSetId;
        }

        for (Ken_Fee_Set_Line_Item__c lineRow : [
            SELECT Ken_Fee_Set__c,
                   Fee_Head__c,
                   Student_Category__c,
                   Category__c,
                   Quota__c,
                   Amount__c,
                   Remittance_Account__c,
                   Tax__c
            FROM Ken_Fee_Set_Line_Item__c
            WHERE Ken_Fee_Set__c IN :feeSetIds
        ]) {
            addFeeSetLineSource(
                linesByFeeSetId,
                lineRow.Ken_Fee_Set__c,
                lineRow.Fee_Head__c,
                lineRow.Student_Category__c,
                lineRow.Category__c,
                lineRow.Quota__c,
                lineRow.Amount__c,
                lineRow.Remittance_Account__c,
                lineRow.Tax__c
            );
        }

        Set<Id> missingFeeSetIds = new Set<Id>(feeSetIds);
        missingFeeSetIds.removeAll(linesByFeeSetId.keySet());
        if (missingFeeSetIds.isEmpty()) {
            return linesByFeeSetId;
        }

        if (!Schema.getGlobalDescribe().containsKey('Ken_Fee_Set_Line__c')) {
            return linesByFeeSetId;
        }

        for (SObject lineRow : Database.query(
            'SELECT Ken_Fee_Set__c, Fee_Head__c, Student_Category__c, Category__c, Quota__c, Amount__c, Remittance_Account__c, Tax__c ' +
            'FROM Ken_Fee_Set_Line__c WHERE Ken_Fee_Set__c IN :missingFeeSetIds'
        )) {
            addFeeSetLineSource(
                linesByFeeSetId,
                (Id) lineRow.get('Ken_Fee_Set__c'),
                (Id) lineRow.get('Fee_Head__c'),
                (String) lineRow.get('Student_Category__c'),
                (Id) lineRow.get('Category__c'),
                (Id) lineRow.get('Quota__c'),
                (Decimal) lineRow.get('Amount__c'),
                (Id) lineRow.get('Remittance_Account__c'),
                (Id) lineRow.get('Tax__c')
            );
        }
        return linesByFeeSetId;
    }

    private static void addFeeSetLineSource(
        Map<Id, List<FeeSetLineSourceRow>> linesByFeeSetId,
        Id feeSetId,
        Id feeHeadId,
        String studentCategory,
        Id categoryId,
        Id quotaId,
        Decimal amount,
        Id remittanceAccountId,
        Id taxId
    ) {
        if (feeSetId == null) {
            return;
        }
        if (!linesByFeeSetId.containsKey(feeSetId)) {
            linesByFeeSetId.put(feeSetId, new List<FeeSetLineSourceRow>());
        }
        FeeSetLineSourceRow sourceRow = new FeeSetLineSourceRow();
        sourceRow.feeSetId = feeSetId;
        sourceRow.feeHeadId = feeHeadId;
        sourceRow.studentCategory = studentCategory;
        sourceRow.categoryId = categoryId;
        sourceRow.quotaId = quotaId;
        sourceRow.amount = amount;
        sourceRow.remittanceAccountId = remittanceAccountId;
        sourceRow.taxId = taxId;
        linesByFeeSetId.get(feeSetId).add(sourceRow);
    }

    private static void validateFeePlanSourceLines(
        List<PublishConfigRow> effectiveRows,
        Map<Id, List<FeeSetLineSourceRow>> feeSetLinesById,
        Boolean isStructureMode
    ) {
        if (!isStructureMode || effectiveRows == null || effectiveRows.isEmpty()) {
            return;
        }

        List<String> missingConfigLabels = new List<String>();
        for (PublishConfigRow row : effectiveRows) {
            if (row == null || row.feePlanId == null) {
                continue;
            }
            List<FeeSetLineSourceRow> sourceRows = feeSetLinesById.get(row.feePlanId);
            if (sourceRows == null || sourceRows.isEmpty()) {
                Integer labelNumber = row.programYearNumber == null || row.programYearNumber <= 0
                    ? 1
                    : row.programYearNumber;
                missingConfigLabels.add('row ' + String.valueOf(labelNumber));
            }
        }

        if (!missingConfigLabels.isEmpty()) {
            throw new AuraHandledException(
                'Selected Fee Plan has no Fee Set Line Items for '
                + String.join(missingConfigLabels, ', ')
                + '. Add line items to the Fee Plan before creating the Programme Fee.'
            );
        }
    }

    private static String normalizeLinkLevel(SaveProgrammeFeeRequest requestData, Map<String, Id> linkedIdsByLevel) {
        String requestedLevel = requestData == null ? null : requestData.linkLevel;
        if (linkedIdsByLevel != null) {
            if (linkedIdsByLevel.get(LINK_LEVEL_LEARNING_PROGRAM_PLAN) != null) {
                return LINK_LEVEL_LEARNING_PROGRAM_PLAN;
            }
            if (linkedIdsByLevel.get(LINK_LEVEL_LEARNING_PROGRAM) != null) {
                return LINK_LEVEL_LEARNING_PROGRAM;
            }
            if (linkedIdsByLevel.get(LINK_LEVEL_INSTITUTE) != null) {
                return LINK_LEVEL_INSTITUTE;
            }
        }
        if (requestedLevel == LINK_LEVEL_INSTITUTE) {
            return LINK_LEVEL_INSTITUTE;
        }
        if (requestedLevel == LINK_LEVEL_LEARNING_PROGRAM) {
            return LINK_LEVEL_LEARNING_PROGRAM;
        }
        return LINK_LEVEL_LEARNING_PROGRAM_PLAN;
    }

    private static Boolean hasFeeTypeField(String fieldApiName) {
        return !String.isBlank(fieldApiName)
            && Ken_Fee_Type__c.SObjectType.getDescribe().fields.getMap().containsKey(fieldApiName);
    }

    private static String resolveAcademicYearFieldApiName() {
        List<String> candidateFieldApiNames = new List<String>{
            'Academic_Year__c',
            'Academic_Year_Name__c',
            'Academic_Year_Label__c'
        };
        for (String fieldApiName : candidateFieldApiNames) {
            if (hasFeeTypeField(fieldApiName)) {
                return fieldApiName;
            }
        }
        return null;
    }

    private static void applyAcademicYearToFeeType(Ken_Fee_Type__c feeTypeRecord, String academicYearValue) {
        if (feeTypeRecord == null || String.isBlank(academicYearValue)) {
            return;
        }
        String academicYearFieldApiName = resolveAcademicYearFieldApiName();
        if (!String.isBlank(academicYearFieldApiName)) {
            feeTypeRecord.put(academicYearFieldApiName, academicYearValue.trim());
        }
    }

    private static String resolveFeeTypeAcademicYearValue(Ken_Fee_Type__c feeTypeRecord) {
        if (feeTypeRecord == null) {
            return '-';
        }
        String academicYearFieldApiName = resolveAcademicYearFieldApiName();
        if (!String.isBlank(academicYearFieldApiName)) {
            Object rawValue = feeTypeRecord.get(academicYearFieldApiName);
            if (rawValue != null && !String.isBlank(String.valueOf(rawValue))) {
                return String.valueOf(rawValue);
            }
        }
        return String.isBlank(feeTypeRecord.Batch__c) ? '-' : feeTypeRecord.Batch__c;
    }

    private static String resolveAcademicYearValue(
        PublishConfigRow configRow,
        SaveProgrammeFeeRequest requestData
    ) {
        if (configRow != null && !String.isBlank(configRow.academicYearLabel)) {
            return configRow.academicYearLabel.trim();
        }
        return requestData == null || String.isBlank(requestData.batchIntake)
            ? null
            : requestData.batchIntake.trim();
    }

    private static Boolean hasFeeTypeLineField(String fieldApiName) {
        return !String.isBlank(fieldApiName)
            && Ken_Fee_Type_Line_Item__c.SObjectType.getDescribe().fields.getMap().containsKey(fieldApiName);
    }

    private static void assignLinkLevelToFeeTypeLine(
        Ken_Fee_Type_Line_Item__c targetLine,
        Id learningProgramPlanId,
        Id learningProgramId,
        Id instituteId
    ) {
        if (targetLine == null) {
            return;
        }
        if (hasFeeTypeLineField('Institute__c') && instituteId != null) {
            targetLine.put('Institute__c', instituteId);
        }
        if (hasFeeTypeLineField('Learning_Program_Plan__c') && learningProgramPlanId != null) {
            targetLine.put('Learning_Program_Plan__c', learningProgramPlanId);
        }
        if (hasFeeTypeLineField('Learning_Program__c') && learningProgramId != null) {
            targetLine.put('Learning_Program__c', learningProgramId);
        }
    }

    private static String resolveSelectedContextName(Id learningProgramPlanId, Id learningProgramId, Id instituteId) {
        if (learningProgramPlanId == null && learningProgramId == null && instituteId == null) {
            return 'Fee Type';
        }
        List<String> nameParts = new List<String>();
        if (instituteId != null) {
            Account instituteRecord = [
                SELECT Id, Name
                FROM Account
                WHERE Id = :instituteId
                LIMIT 1
            ];
            nameParts.add(String.isBlank(instituteRecord.Name) ? 'Institute' : instituteRecord.Name);
        }
        if (learningProgramId != null) {
            LearningProgram selectedProgram = [
                SELECT Id, Name
                FROM LearningProgram
                WHERE Id = :learningProgramId
                LIMIT 1
            ];
            nameParts.add(String.isBlank(selectedProgram.Name) ? 'Learning Program' : selectedProgram.Name);
        }
        if (learningProgramPlanId != null) {
            LearningProgramPlan selectedPlan = [
                SELECT Id, Name
                FROM LearningProgramPlan
                WHERE Id = :learningProgramPlanId
                LIMIT 1
            ];
            nameParts.add(String.isBlank(selectedPlan.Name) ? 'Learning Program Plan' : selectedPlan.Name);
        }
        return nameParts.isEmpty() ? 'Fee Type' : String.join(nameParts, ' | ');
    }

    private static Map<String, Id> normalizeLinkedIdsByLevel(SaveProgrammeFeeRequest requestData) {
        Map<String, Id> idsByLevel = new Map<String, Id>{
            LINK_LEVEL_LEARNING_PROGRAM_PLAN => null,
            LINK_LEVEL_LEARNING_PROGRAM => null,
            LINK_LEVEL_INSTITUTE => null
        };
        if (requestData == null) {
            return idsByLevel;
        }

        if (requestData.linkedMappings != null) {
            for (LinkedMappingRow row : requestData.linkedMappings) {
                if (row == null || row.linkedEntityId == null || String.isBlank(row.linkedLevel)) {
                    continue;
                }
                if (row.linkedLevel == LINK_LEVEL_LEARNING_PROGRAM_PLAN) {
                    idsByLevel.put(LINK_LEVEL_LEARNING_PROGRAM_PLAN, row.linkedEntityId);
                } else if (row.linkedLevel == LINK_LEVEL_LEARNING_PROGRAM) {
                    idsByLevel.put(LINK_LEVEL_LEARNING_PROGRAM, row.linkedEntityId);
                } else if (row.linkedLevel == LINK_LEVEL_INSTITUTE) {
                    idsByLevel.put(LINK_LEVEL_INSTITUTE, row.linkedEntityId);
                }
            }
        }

        if (idsByLevel.get(LINK_LEVEL_LEARNING_PROGRAM_PLAN) == null && requestData.programmeId != null) {
            idsByLevel.put(LINK_LEVEL_LEARNING_PROGRAM_PLAN, requestData.programmeId);
        }
        if (idsByLevel.get(LINK_LEVEL_LEARNING_PROGRAM) == null && requestData.learningProgramId != null) {
            idsByLevel.put(LINK_LEVEL_LEARNING_PROGRAM, requestData.learningProgramId);
        }
        if (idsByLevel.get(LINK_LEVEL_INSTITUTE) == null && requestData.instituteId != null) {
            idsByLevel.put(LINK_LEVEL_INSTITUTE, requestData.instituteId);
        }
        return idsByLevel;
    }

    private static List<LinkedMappingRow> buildLinkedMappingsForEdit(
        Id learningProgramPlanId,
        Id learningProgramId,
        Id instituteId
    ) {
        List<LinkedMappingRow> rows = new List<LinkedMappingRow>();
        if (learningProgramPlanId != null) {
            LinkedMappingRow row = new LinkedMappingRow();
            row.linkedLevel = LINK_LEVEL_LEARNING_PROGRAM_PLAN;
            row.linkedEntityId = learningProgramPlanId;
            rows.add(row);
        }
        if (learningProgramId != null) {
            LinkedMappingRow row = new LinkedMappingRow();
            row.linkedLevel = LINK_LEVEL_LEARNING_PROGRAM;
            row.linkedEntityId = learningProgramId;
            rows.add(row);
        }
        if (instituteId != null) {
            LinkedMappingRow row = new LinkedMappingRow();
            row.linkedLevel = LINK_LEVEL_INSTITUTE;
            row.linkedEntityId = instituteId;
            rows.add(row);
        }
        return rows;
    }

    private static void applyCategoryQuotaToFeeTypeLine(
        Ken_Fee_Type_Line_Item__c targetLine,
        PublishConfigRow configRow,
        Map<Id, Category__c> categoryById,
        Map<Id, Quota__c> quotaById
    ) {
        if (targetLine == null || configRow == null) {
            return;
        }

        Quota__c selectedQuota = configRow.quotaId == null ? null : quotaById.get(configRow.quotaId);
        Category__c selectedCategory = configRow.categoryId == null ? null : categoryById.get(configRow.categoryId);

        if (hasFeeTypeLineField('Quota__c') && selectedQuota != null) {
            targetLine.put('Quota__c', selectedQuota.Id);
        }
        if (hasFeeTypeLineField('Category__c')) {
            if (selectedQuota != null && selectedQuota.Category__c != null) {
                targetLine.put('Category__c', selectedQuota.Category__c);
            } else if (selectedCategory != null) {
                targetLine.put('Category__c', selectedCategory.Id);
            }
        }

        String resolvedStudentCategory = resolveStudentCategoryPicklistValue(selectedQuota, selectedCategory);
        if (!String.isBlank(resolvedStudentCategory)) {
            targetLine.Student_Category__c = resolvedStudentCategory;
        }
    }

    private static String resolveStudentCategoryPicklistValue(Quota__c selectedQuota, Category__c selectedCategory) {
        Set<String> allowedValues = new Set<String>();
        for (Schema.PicklistEntry entry :
            Ken_Fee_Type_Line_Item__c.Student_Category__c.getDescribe().getPicklistValues()
        ) {
            if (entry != null && entry.isActive() && !String.isBlank(entry.getValue())) {
                allowedValues.add(entry.getValue());
            }
        }

        List<String> preferredValues = new List<String>();
        if (selectedQuota != null) {
            if (!String.isBlank(selectedQuota.Code__c)) {
                preferredValues.add(selectedQuota.Code__c);
            }
            if (!String.isBlank(selectedQuota.Name)) {
                preferredValues.add(selectedQuota.Name);
            }
        }
        if (selectedCategory != null && !String.isBlank(selectedCategory.Name)) {
            preferredValues.add(selectedCategory.Name);
        }

        for (String candidateValue : preferredValues) {
            if (!String.isBlank(candidateValue) && allowedValues.contains(candidateValue)) {
                return candidateValue;
            }
        }
        return null;
    }

    private static Boolean isAcademicFeeCategory(String feeCategoryValue) {
        String normalizedCategory = String.valueOf(feeCategoryValue).trim().toLowerCase();
        return normalizedCategory == 'academic' || normalizedCategory == 'academics';
    }

    private static String buildFeeTypePlanKey(List<PublishConfigRow> rows, String frequencyValue) {
        if (rows == null || rows.isEmpty()) {
            return null;
        }

        Map<Integer, String> tagByYearNumber = new Map<Integer, String>();
        for (PublishConfigRow row : rows) {
            if (row != null && !String.isBlank(row.tag)) {
                Integer yearNumber = (row.programYearNumber == null || row.programYearNumber <= 0)
                    ? 1
                    : row.programYearNumber;
                if (!tagByYearNumber.containsKey(yearNumber)) {
                    tagByYearNumber.put(yearNumber, row.tag.trim());
                }
            }
        }

        if (tagByYearNumber.isEmpty()) {
            return null;
        }

        List<Integer> yearNumbers = new List<Integer>();
        yearNumbers.addAll(tagByYearNumber.keySet());
        yearNumbers.sort();

        if (yearNumbers.size() == 1) {
            return tagByYearNumber.get(yearNumbers[0]);
        }

        List<String> keyParts = new List<String>();
        for (Integer yearNumber : yearNumbers) {
            String label = buildTermLabel(frequencyValue, yearNumber);
            keyParts.add(label + ': ' + tagByYearNumber.get(yearNumber));
        }
        return String.join(keyParts, ' | ');
    }

    private static String buildLinePeriodLabel(String frequencyValue, String termSystemValue, Integer rowNumber) {
        Integer safeRowNumber = rowNumber == null || rowNumber <= 0 ? 1 : rowNumber;
        String normalizedFrequency = String.valueOf(frequencyValue).toLowerCase();

        if (normalizedFrequency.contains('year')) {
            return 'Year ' + String.valueOf(safeRowNumber);
        }

        if (normalizedFrequency.contains('term')) {
            Integer termsPerYear = 2;
            String normalizedTermSystem = String.valueOf(termSystemValue).toLowerCase();
            if (normalizedTermSystem.contains('tri')) {
                termsPerYear = 3;
            } else if (normalizedTermSystem.contains('quad')) {
                termsPerYear = 4;
            }

            Decimal yearDecimal = Math.ceil(Decimal.valueOf(safeRowNumber) / Decimal.valueOf(termsPerYear));
            Integer yearNumber = yearDecimal.intValue();
            if (normalizedTermSystem.contains('tri')) {
                return 'Year ' + String.valueOf(yearNumber) + ' Tri ' + String.valueOf(safeRowNumber);
            }
            if (normalizedTermSystem.contains('quad')) {
                return 'Year ' + String.valueOf(yearNumber) + ' Quad ' + String.valueOf(safeRowNumber);
            }
            return 'Year ' + String.valueOf(yearNumber) + ' Sem ' + String.valueOf(safeRowNumber);
        }

        if (normalizedFrequency.contains('one')) {
            return 'One Time';
        }

        return buildTermLabel(frequencyValue, safeRowNumber);
    }

    private static Integer extractYearFromPlanRecord(
        SObject planRecord,
        List<String> yearFields,
        String dateField
    ) {
        for (String yearField : yearFields) {
            Object rawValue = planRecord.get(yearField);
            Integer parsedYear = parseInteger(rawValue);
            if (parsedYear != null) {
                return parsedYear;
            }
        }

        Object rawDate = planRecord.get(dateField);
        if (rawDate instanceof Date) {
            return ((Date) rawDate).year();
        }
        if (rawDate instanceof Datetime) {
            return ((Datetime) rawDate).year();
        }
        return null;
    }

    private static Integer parseInteger(Object rawValue) {
        if (rawValue == null) {
            return null;
        }
        if (rawValue instanceof Integer) {
            return (Integer) rawValue;
        }
        if (rawValue instanceof Long) {
            return Integer.valueOf(String.valueOf((Long) rawValue));
        }
        if (rawValue instanceof Decimal) {
            return ((Decimal) rawValue).intValue();
        }
        try {
            return Integer.valueOf(String.valueOf(rawValue));
        } catch (Exception ex) {
            return null;
        }
    }

    private static Id resolvePreferredFeeTypeRecordTypeId() {
        Schema.DescribeSObjectResult describeResult = Ken_Fee_Type__c.SObjectType.getDescribe();
        Map<String, Schema.RecordTypeInfo> byDevName = describeResult.getRecordTypeInfosByDeveloperName();

        if (byDevName != null && byDevName.containsKey('Academics_Fee') && byDevName.get('Academics_Fee').isAvailable()) {
            return byDevName.get('Academics_Fee').getRecordTypeId();
        }
        if (byDevName != null && byDevName.containsKey('Non_Academics_Fee') && byDevName.get('Non_Academics_Fee').isAvailable()) {
            return byDevName.get('Non_Academics_Fee').getRecordTypeId();
        }

        for (Schema.RecordTypeInfo recordTypeInfo : describeResult.getRecordTypeInfos()) {
            if (recordTypeInfo.isAvailable() && recordTypeInfo.isDefaultRecordTypeMapping()) {
                return recordTypeInfo.getRecordTypeId();
            }
        }
        return null;
    }

    private static String normalizeFeeCategoryForSave(String inputCategory) {
        String firstActiveValue;
        String academicsValue;
        for (Schema.PicklistEntry entry : Ken_Fee_Type__c.Fee_Category__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                String entryValue = entry.getValue();
                if (String.isBlank(firstActiveValue)) {
                    firstActiveValue = entryValue;
                }
                if (!String.isBlank(entryValue) && entryValue.trim().toLowerCase() == 'academics') {
                    academicsValue = entryValue;
                }
            }
        }

        if (String.isBlank(inputCategory)) {
            return !String.isBlank(academicsValue) ? academicsValue : firstActiveValue;
        }

        String normalizedInput = inputCategory.trim().toLowerCase();
        for (Schema.PicklistEntry entry : Ken_Fee_Type__c.Fee_Category__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                String entryValue = entry.getValue();
                if (!String.isBlank(entryValue) && entryValue.trim().toLowerCase() == normalizedInput) {
                    return entryValue;
                }
            }
        }

        return !String.isBlank(academicsValue) ? academicsValue : firstActiveValue;
    }
}