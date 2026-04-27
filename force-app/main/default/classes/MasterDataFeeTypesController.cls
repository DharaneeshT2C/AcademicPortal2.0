public with sharing class MasterDataFeeTypesController {
    private static final String LINK_LEVEL_LEARNING_PROGRAM_PLAN = 'Learning Program Plan';
    private static final String LINK_LEVEL_LEARNING_PROGRAM = 'Learning Program';
    private static final String LINK_LEVEL_INSTITUTE = 'Institute';
    private static final String ERROR_DUPLICATE_FEE_TYPE =
        'A Fee Type configuration already exists for the selected context, Batch / Intake, Fee Category, and Frequency.';

    public class OptionRow {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
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

    public class SeedData {
        @AuraEnabled public List<OptionRow> feeHeadOptions;
        @AuraEnabled public List<OptionRow> feeCategoryOptions;
        @AuraEnabled public List<OptionRow> remittanceOptions;
        @AuraEnabled public List<RemittanceMerchantRow> remittanceMerchantRows;
        @AuraEnabled public List<OptionRow> installmentOptions;
        @AuraEnabled public List<OptionRow> penaltyPlanOptions;
        @AuraEnabled public List<ProgrammeYearRangeRow> programmeYearRanges;
    }

    public class LinkedMappingRow {
        @AuraEnabled public String linkedLevel;
        @AuraEnabled public Id linkedEntityId;
    }

    public class SaveFeeTypeRequest {
        @AuraEnabled public List<LinkedMappingRow> linkedMappings;
        @AuraEnabled public Id programmeId;
        @AuraEnabled public Id learningProgramId;
        @AuraEnabled public Id instituteId;
        @AuraEnabled public String feeCategory;
        @AuraEnabled public String batchIntake;
        @AuraEnabled public Date activationDate;
        @AuraEnabled public String frequency;
        @AuraEnabled public List<Id> remittanceAccountIds;
        @AuraEnabled public String notes;

        @AuraEnabled public Id oneTimeFeeHeadId;
        @AuraEnabled public Id oneTimeCategoryId;
        @AuraEnabled public Id oneTimeQuotaId;
        @AuraEnabled public String oneTimeFeePlanTag;
        @AuraEnabled public Decimal oneTimeAmount;
        @AuraEnabled public Date oneTimeStartDate;
        @AuraEnabled public Date oneTimeDueDate;
        @AuraEnabled public Id oneTimeRemittanceOverrideId;
        @AuraEnabled public Id oneTimeInstallmentId;
        @AuraEnabled public Id oneTimePenaltyPlanId;
    }

    @AuraEnabled(cacheable=true)
    public static SeedData getSeedData() {
        SeedData seed = new SeedData();
        seed.feeHeadOptions = new List<OptionRow>();
        seed.feeCategoryOptions = new List<OptionRow>();
        seed.remittanceOptions = new List<OptionRow>();
        seed.remittanceMerchantRows = new List<RemittanceMerchantRow>();
        seed.installmentOptions = new List<OptionRow>();
        seed.penaltyPlanOptions = new List<OptionRow>();
        seed.programmeYearRanges = new List<ProgrammeYearRangeRow>();
        if (!Schema.sObjectType.Ken_Master_Fee_Head__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view fee heads.');
        }
        if (!Schema.sObjectType.Ken_Bank_Account_Master__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view remittance accounts.');
        }
        if (!Schema.sObjectType.Payment_Schedule__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view payment schedules.');
        }
        if (!Schema.sObjectType.Ken_Fee_Type__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view fee types.');
        }

        for (Ken_Master_Fee_Head__c feeHead : [
            SELECT Id, Fee_Head_Name__c
            FROM Ken_Master_Fee_Head__c
            WHERE Fee_Head_Name__c != null AND Is_Active__c = true
            ORDER BY Fee_Head_Name__c ASC
            LIMIT 500
        ]) {
            OptionRow option = new OptionRow();
            option.value = String.valueOf(feeHead.Id);
            option.label = feeHead.Fee_Head_Name__c;
            seed.feeHeadOptions.add(option);
        }

        for (Schema.PicklistEntry categoryEntry :
            Ken_Fee_Type__c.Fee_Category__c.getDescribe().getPicklistValues()
        ) {
            if (categoryEntry != null && categoryEntry.isActive()) {
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
            LIMIT 500
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

        for (Payment_Schedule__c scheduleRow : [
            SELECT Id, Name
            FROM Payment_Schedule__c
            WHERE Name != null
            ORDER BY Name ASC
            LIMIT 500
        ]) {
            OptionRow option = new OptionRow();
            option.value = String.valueOf(scheduleRow.Id);
            option.label = scheduleRow.Name;
            seed.installmentOptions.add(option);
        }

        for (Ken_Fee_Type__c penaltyRow : [
            SELECT Id, Name, Fee_Type_Name__c
            FROM Ken_Fee_Type__c
            WHERE RecordType.DeveloperName = 'Late_Fee'
            ORDER BY LastModifiedDate DESC
            LIMIT 500
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

    @AuraEnabled
    public static Id saveFeeTypeConfiguration(String requestJson, Boolean activateNow) {
        if (String.isBlank(requestJson)) {
            throw new AuraHandledException('Request payload is required.');
        }

        SaveFeeTypeRequest requestData =
            (SaveFeeTypeRequest) JSON.deserialize(requestJson, SaveFeeTypeRequest.class);
        if (requestData == null) {
            throw new AuraHandledException('Request is required.');
        }

        Map<String, Id> linkedIdsByLevel = normalizeLinkedIdsByLevel(requestData);
        Id learningProgramPlanId = linkedIdsByLevel.get(LINK_LEVEL_LEARNING_PROGRAM_PLAN);
        Id learningProgramId = linkedIdsByLevel.get(LINK_LEVEL_LEARNING_PROGRAM);
        Id instituteId = linkedIdsByLevel.get(LINK_LEVEL_INSTITUTE);

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
        if (requestData.oneTimeFeeHeadId == null) {
            throw new AuraHandledException('Fee Head is required.');
        }
        if (requestData.oneTimeDueDate == null) {
            throw new AuraHandledException('Due Date is required.');
        }
        if (requestData.oneTimeAmount == null) {
            throw new AuraHandledException('Amount is required.');
        }

        List<Id> remittanceIds = normalizeRemittanceIds(requestData.remittanceAccountIds);
        if (remittanceIds.isEmpty()) {
            throw new AuraHandledException('At least one Remittance Account is required.');
        }

        String resolvedFeeCategory = normalizeFeeCategoryForSave(requestData.feeCategory);
        validateNoDuplicateFeeType(
            learningProgramPlanId,
            learningProgramId,
            instituteId,
            requestData.batchIntake,
            resolvedFeeCategory,
            requestData.frequency
        );

        String parentStatus = activateNow == true ? 'Active' : 'Draft';
        String contextName = resolveSelectedContextName(learningProgramPlanId, learningProgramId, instituteId);
        String generatedName = String.isBlank(requestData.batchIntake)
            ? contextName
            : contextName + ' | ' + requestData.batchIntake;

        Ken_Fee_Type__c feeTypeRecord = new Ken_Fee_Type__c(
            Fee_Type_Name__c = generatedName,
            Batch__c = requestData.batchIntake,
            Learning_Program_Plan__c = learningProgramPlanId,
            Fee_Collection_Frequency__c = requestData.frequency,
            Fee_Category__c = resolvedFeeCategory,
            Status__c = parentStatus,
            Description__c = requestData.notes,
            Institute__c = instituteId,
            Payment_Schedule__c = requestData.oneTimeInstallmentId,
            Late_Fee_Plan__c = requestData.oneTimePenaltyPlanId
        );

        if (hasFeeTypeField('Learning_Program__c')) {
            feeTypeRecord.put('Learning_Program__c', learningProgramId);
        }

        Id preferredRecordTypeId = resolvePreferredFeeTypeRecordTypeId();
        if (preferredRecordTypeId != null) {
            feeTypeRecord.RecordTypeId = preferredRecordTypeId;
        }
        if (!Schema.sObjectType.Ken_Fee_Type__c.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create fee types.');
        }

        insert feeTypeRecord;

        if (!Schema.sObjectType.Ken_Master_Fee_Head__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view fee heads.');
        }
        Ken_Master_Fee_Head__c selectedFeeHead = [
            SELECT Id, Tax_Definition__c, Default_Remittance_Account__c
            FROM Ken_Master_Fee_Head__c
            WHERE Id = :requestData.oneTimeFeeHeadId
            LIMIT 1
        ];

        Id resolvedLineRemittanceId = requestData.oneTimeRemittanceOverrideId;
        if (resolvedLineRemittanceId == null) {
            resolvedLineRemittanceId = selectedFeeHead.Default_Remittance_Account__c;
        }
        if (resolvedLineRemittanceId == null && !remittanceIds.isEmpty()) {
            resolvedLineRemittanceId = remittanceIds[0];
        }

        Ken_Fee_Type_Line_Item__c lineRecord = new Ken_Fee_Type_Line_Item__c(
            Ken_Fee_Type__c = feeTypeRecord.Id,
            Program_Year_Number__c = 1,
            Fee_Head__c = requestData.oneTimeFeeHeadId,
            Fee_Type_Line_Key__c = String.isBlank(requestData.oneTimeFeePlanTag)
                ? null
                : requestData.oneTimeFeePlanTag.trim(),
            Fee_Period_Label__c = buildLinePeriodLabel(requestData.frequency),
            Amount__c = requestData.oneTimeAmount,
            Start_Date__c = requestData.oneTimeStartDate,
            Due_Date__c = requestData.oneTimeDueDate,
            Remittance_Account__c = resolvedLineRemittanceId,
            Tax__c = selectedFeeHead.Tax_Definition__c,
            Is_Active__c = activateNow == true
        );

        applyCategoryQuotaToFeeTypeLine(
            lineRecord,
            requestData.oneTimeCategoryId,
            requestData.oneTimeQuotaId
        );
        assignLinkLevelToFeeTypeLine(lineRecord, learningProgramPlanId, learningProgramId, instituteId);
        if (!Schema.sObjectType.Ken_Fee_Type_Line_Item__c.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create fee type line items.');
        }

        insert lineRecord;

        List<Ken_Fee_Type_Remittance__c> remittanceLinksToSave = new List<Ken_Fee_Type_Remittance__c>();
        for (Id remittanceId : remittanceIds) {
            remittanceLinksToSave.add(new Ken_Fee_Type_Remittance__c(
                Ken_Fee_Type__c = feeTypeRecord.Id,
                Remittance_Account__c = remittanceId
            ));
        }
        if (!remittanceLinksToSave.isEmpty()) {
            if (!Schema.sObjectType.Ken_Fee_Type_Remittance__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create fee type remittance links.');
            }
            insert remittanceLinksToSave;
        }

        if (!String.isBlank(requestData.oneTimeFeePlanTag)) {
            feeTypeRecord.Fee_Type_Plan_Key__c = requestData.oneTimeFeePlanTag.trim();
            if (!Schema.sObjectType.Ken_Fee_Type__c.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update fee types.');
            }
            update feeTypeRecord;
        }

        return feeTypeRecord.Id;
    }

    private static void validateNoDuplicateFeeType(
        Id learningProgramPlanId,
        Id learningProgramId,
        Id instituteId,
        String batchIntake,
        String feeCategory,
        String frequency
    ) {
        if (!Schema.sObjectType.Ken_Fee_Type__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view fee types.');
        }
        List<Ken_Fee_Type__c> existingRows = [
            SELECT Id
            FROM Ken_Fee_Type__c
            WHERE Learning_Program_Plan__c = :learningProgramPlanId
              AND Learning_Program__c = :learningProgramId
              AND Institute__c = :instituteId
              AND Batch__c = :batchIntake
              AND Fee_Category__c = :feeCategory
              AND Fee_Collection_Frequency__c = :frequency
              AND Status__c != 'Cancelled'
            LIMIT 1
        ];

        if (!existingRows.isEmpty()) {
            throw new AuraHandledException(ERROR_DUPLICATE_FEE_TYPE);
        }
    }

    private static List<Id> normalizeRemittanceIds(List<Id> incomingIds) {
        List<Id> normalizedIds = new List<Id>();
        if (incomingIds == null) {
            return normalizedIds;
        }

        Set<Id> seenIds = new Set<Id>();
        for (Id incomingId : incomingIds) {
            if (incomingId != null && !seenIds.contains(incomingId)) {
                seenIds.add(incomingId);
                normalizedIds.add(incomingId);
            }
        }
        return normalizedIds;
    }

    private static Map<String, Id> normalizeLinkedIdsByLevel(SaveFeeTypeRequest requestData) {
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

    private static void applyCategoryQuotaToFeeTypeLine(
        Ken_Fee_Type_Line_Item__c targetLine,
        Id categoryId,
        Id quotaId
    ) {
        if (targetLine == null) {
            return;
        }

        Category__c selectedCategory;
        if (categoryId != null) {
            if (!Schema.sObjectType.Category__c.isAccessible()) {
                throw new AuraHandledException('You do not have permission to view categories.');
            }
            selectedCategory = [SELECT Id, Name FROM Category__c WHERE Id = :categoryId LIMIT 1];
        }

        Quota__c selectedQuota;
        if (quotaId != null) {
            if (!Schema.sObjectType.Quota__c.isAccessible()) {
                throw new AuraHandledException('You do not have permission to view quotas.');
            }
            selectedQuota = [SELECT Id, Name, Code__c, Category__c FROM Quota__c WHERE Id = :quotaId LIMIT 1];
        }

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

        String studentCategory = resolveStudentCategoryPicklistValue(selectedQuota, selectedCategory);
        if (!String.isBlank(studentCategory)) {
            targetLine.Student_Category__c = studentCategory;
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
            if (!Schema.sObjectType.Account.isAccessible()) {
                throw new AuraHandledException('You do not have permission to view institutes.');
            }
            Account instituteRecord = [
                SELECT Id, Name
                FROM Account
                WHERE Id = :instituteId
                LIMIT 1
            ];
            nameParts.add(String.isBlank(instituteRecord.Name) ? 'Institute' : instituteRecord.Name);
        }

        if (learningProgramId != null) {
            if (!Schema.sObjectType.LearningProgram.isAccessible()) {
                throw new AuraHandledException('You do not have permission to view learning programs.');
            }
            LearningProgram programRecord = [
                SELECT Id, Name
                FROM LearningProgram
                WHERE Id = :learningProgramId
                LIMIT 1
            ];
            nameParts.add(String.isBlank(programRecord.Name) ? 'Learning Program' : programRecord.Name);
        }

        if (learningProgramPlanId != null) {
            if (!Schema.sObjectType.LearningProgramPlan.isAccessible()) {
                throw new AuraHandledException('You do not have permission to view learning program plans.');
            }
            LearningProgramPlan planRecord = [
                SELECT Id, Name
                FROM LearningProgramPlan
                WHERE Id = :learningProgramPlanId
                LIMIT 1
            ];
            nameParts.add(String.isBlank(planRecord.Name) ? 'Learning Program Plan' : planRecord.Name);
        }

        return nameParts.isEmpty() ? 'Fee Type' : String.join(nameParts, ' | ');
    }

    private static String buildLinePeriodLabel(String frequencyValue) {
        String normalized = String.valueOf(frequencyValue).toLowerCase();
        if (normalized.contains('year')) {
            return 'Year 1';
        }
        if (normalized.contains('term')) {
            return 'Term 1';
        }
        return 'One Time';
    }

    private static Boolean hasFeeTypeField(String fieldApiName) {
        return !String.isBlank(fieldApiName)
            && Ken_Fee_Type__c.SObjectType.getDescribe().fields.getMap().containsKey(fieldApiName);
    }

    private static Boolean hasFeeTypeLineField(String fieldApiName) {
        return !String.isBlank(fieldApiName)
            && Ken_Fee_Type_Line_Item__c.SObjectType.getDescribe().fields.getMap().containsKey(fieldApiName);
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
            if (entry != null && entry.isActive()) {
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
            if (entry != null && entry.isActive()) {
                String entryValue = entry.getValue();
                if (!String.isBlank(entryValue) && entryValue.trim().toLowerCase() == normalizedInput) {
                    return entryValue;
                }
            }
        }

        return !String.isBlank(academicsValue) ? academicsValue : firstActiveValue;
    }

}