public with sharing class FeeTypeCreationService {
    private static final String LINK_LEVEL_LEARNING_PROGRAM_PLAN = 'Learning Program Plan';
    private static final String LINK_LEVEL_INSTITUTE_PROGRAM_PLAN = 'Institute Program Plan';


    public class YearConfiguration {
        @AuraEnabled public Integer programYearNumber;
        @AuraEnabled public Id feeSetId;
        @AuraEnabled public Date dueDate;
    }

    public class FeeTypeRequest {
        @AuraEnabled public String linkLevel;
        @AuraEnabled public Id learningProgramPlanId;
        @AuraEnabled public Id instituteProgramPlanId;
        @AuraEnabled public Id feeTypeRecordTypeId;   
        @AuraEnabled public String feeTypeName;       
        @AuraEnabled public String feeCategory;       
        @AuraEnabled public String frequency;         
        @AuraEnabled public String status;           
        @AuraEnabled public Id paymentScheduleId;     
        @AuraEnabled public Id defaultTaxId;          
        @AuraEnabled public Id lateFeePlanId;         
        @AuraEnabled public List<YearConfiguration> yearConfigurations;
    }

    public class FeeSetPreviewRow {
        @AuraEnabled public String rowKey;
        @AuraEnabled public String studentCategory;
        @AuraEnabled public String feeHeadName;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String currencyIsoCode;
        @AuraEnabled public String remittanceAccountName;
        @AuraEnabled public String taxName;
    }


    @AuraEnabled(cacheable=true)
    public static List<FeeSetPreviewRow> getFeeSetPreview(Id feeSetId) {
        List<FeeSetPreviewRow> previewRows = new List<FeeSetPreviewRow>();

        if (feeSetId == null) {
            return previewRows;
        }

        List<Ken_Fee_Set_Line_Item__c> feeSetLineRows = [
            SELECT
                Student_Category__c,
                Amount__c,
                CurrencyIsoCode,
                Fee_Head__r.Fee_Head_Name__c,
                Remittance_Account__r.Bank_Account_Name__c,
                Tax__r.Name
            FROM Ken_Fee_Set_Line_Item__c
            WHERE Ken_Fee_Set__c = :feeSetId
            ORDER BY Student_Category__c, Fee_Head__r.Fee_Head_Name__c
        ];

        for (Ken_Fee_Set_Line_Item__c feeSetLineRow : feeSetLineRows) {
            FeeSetPreviewRow previewRow = new FeeSetPreviewRow();
            previewRow.rowKey = String.valueOf(feeSetLineRow.Id); 
            previewRow.studentCategory = String.valueOf(feeSetLineRow.Student_Category__c);
            previewRow.feeHeadName = (feeSetLineRow.Fee_Head__r != null)
                ? feeSetLineRow.Fee_Head__r.Fee_Head_Name__c
                : null;
            previewRow.amount = feeSetLineRow.Amount__c;
            previewRow.currencyIsoCode = feeSetLineRow.CurrencyIsoCode;
            previewRow.remittanceAccountName = (feeSetLineRow.Remittance_Account__r != null)
                ? feeSetLineRow.Remittance_Account__r.Bank_Account_Name__c
                : null;
            previewRow.taxName = (feeSetLineRow.Tax__r != null)
                ? feeSetLineRow.Tax__r.Name
                : null;

            previewRows.add(previewRow);
        }

        return previewRows;
    }

    @AuraEnabled
    public static Id createFeeType(String requestJson) {
        if (String.isBlank(requestJson)) {
            throw new AuraHandledException('Request cannot be null.');
        }
    
        FeeTypeRequest request =
            (FeeTypeRequest) JSON.deserialize(requestJson, FeeTypeRequest.class);
    
        validateRequest(request);
        String normalizedLinkLevel = normalizeLinkLevel(request);
    
        Id instituteId = resolveInstituteId(
            normalizedLinkLevel,
            request.learningProgramPlanId,
            request.instituteProgramPlanId
        );
    
        Ken_Fee_Type__c feeTypeRecord = new Ken_Fee_Type__c(
            RecordTypeId = request.feeTypeRecordTypeId,
            Learning_Program_Plan__c =
                normalizedLinkLevel == LINK_LEVEL_LEARNING_PROGRAM_PLAN ? request.learningProgramPlanId : null,
            Institute__c = instituteId,
            Fee_Type_Name__c = request.feeTypeName,
            Fee_Category__c = request.feeCategory,
            Fee_Collection_Frequency__c = request.frequency,
            Status__c = request.status,
            Payment_Schedule__c = request.paymentScheduleId,
            Ken_Tax_Definition__c = request.defaultTaxId,
            Late_Fee_Plan__c = request.lateFeePlanId
        );

        if (
            normalizedLinkLevel == LINK_LEVEL_INSTITUTE_PROGRAM_PLAN &&
            request.instituteProgramPlanId != null &&
            hasFeeTypeField('Institute_Program_Plan__c')
        ) {
            feeTypeRecord.put('Institute_Program_Plan__c', request.instituteProgramPlanId);
        }
    
        insert feeTypeRecord;
    
        List<Ken_Fee_Type_Line_Item__c> feeTypeLineRecords =
            buildFeeTypeLines(feeTypeRecord.Id, request.yearConfigurations, request.status);

    
        if (!feeTypeLineRecords.isEmpty()) {
            insert feeTypeLineRecords;
        }
    
        return feeTypeRecord.Id;
    }


    // ----------------------------
    // Validation (messages stay here; NOT in constants)
    // ----------------------------
    private static void validateRequest(FeeTypeRequest request) {
        if (request == null) {
            throw new AuraHandledException('Request cannot be null.');
        }
        String normalizedLinkLevel = normalizeLinkLevel(request);
        if (normalizedLinkLevel == LINK_LEVEL_LEARNING_PROGRAM_PLAN && request.learningProgramPlanId == null) {
            throw new AuraHandledException('Learning Program Plan is required.');
        }
        if (normalizedLinkLevel == LINK_LEVEL_INSTITUTE_PROGRAM_PLAN && request.instituteProgramPlanId == null) {
            throw new AuraHandledException('Institute Program Plan is required.');
        }
        if (request.feeTypeRecordTypeId == null) {
            throw new AuraHandledException('Fee Type record type is required.');
        }
        if (String.isBlank(request.feeCategory)) {
            throw new AuraHandledException('Fee Category is required.');
        }
        if (String.isBlank(request.frequency)) {
            throw new AuraHandledException('Fee Collection Frequency is required.');
        }
        if (String.isBlank(request.status)) {
            throw new AuraHandledException('Status is required.');
        }
        if (request.paymentScheduleId == null) {
            throw new AuraHandledException('Payment Schedule is required.');
        }
        if (request.yearConfigurations == null || request.yearConfigurations.isEmpty()) {
            throw new AuraHandledException('At least one year configuration is required.');
        }

        for (YearConfiguration yearConfig : request.yearConfigurations) {
            if (yearConfig == null) {
                throw new AuraHandledException('Year configuration cannot be null.');
            }
            if (yearConfig.programYearNumber == null) {
                throw new AuraHandledException('Program Year Number is required for each year.');
            }
            if (yearConfig.feeSetId == null) {
                throw new AuraHandledException('Fee Set is required for Year ' + String.valueOf(yearConfig.programYearNumber) + '.');
            }
            if (yearConfig.dueDate == null) {
                throw new AuraHandledException('Due Date is required for Year ' + String.valueOf(yearConfig.programYearNumber) + '.');
            }
        }
        Integer existingCount;
        if (normalizedLinkLevel == LINK_LEVEL_INSTITUTE_PROGRAM_PLAN) {
            if (!hasFeeTypeField('Institute_Program_Plan__c')) {
                throw new AuraHandledException('Institute Program Plan linkage is not available in this org.');
            }
            existingCount = Database.countQuery(
                'SELECT COUNT()' +
                ' FROM Ken_Fee_Type__c' +
                ' WHERE Institute_Program_Plan__c = :request.instituteProgramPlanId' +
                ' AND RecordTypeId = :request.feeTypeRecordTypeId' +
                ' AND Fee_Category__c = :request.feeCategory' +
                ' AND Fee_Collection_Frequency__c = :request.frequency' +
                ' AND Payment_Schedule__c = :request.paymentScheduleId' +
                ' AND Status__c != \'Cancelled\''
            );
        } else {
            existingCount = [
                SELECT COUNT()
                FROM Ken_Fee_Type__c
                WHERE Learning_Program_Plan__c = :request.learningProgramPlanId
                  AND RecordTypeId = :request.feeTypeRecordTypeId
                  AND Fee_Category__c = :request.feeCategory
                  AND Fee_Collection_Frequency__c = :request.frequency
                  AND Payment_Schedule__c = :request.paymentScheduleId
                  AND Status__c != 'Cancelled'
            ];
        }
        
        if (existingCount > 0) {
            throw new AuraHandledException('A Fee Type already exists for the selected link level with the same configuration.');
        }

    }

    private static String normalizeLinkLevel(FeeTypeRequest request) {
        String linkLevel = request == null ? null : request.linkLevel;
        if (String.isBlank(linkLevel)) {
            if (request != null && request.instituteProgramPlanId != null) {
                return LINK_LEVEL_INSTITUTE_PROGRAM_PLAN;
            }
            return LINK_LEVEL_LEARNING_PROGRAM_PLAN;
        }

        String normalized = linkLevel.trim();
        if (normalized == LINK_LEVEL_INSTITUTE_PROGRAM_PLAN) {
            return LINK_LEVEL_INSTITUTE_PROGRAM_PLAN;
        }
        return LINK_LEVEL_LEARNING_PROGRAM_PLAN;
    }

    private static Boolean hasFeeTypeField(String fieldApiName) {
        return !String.isBlank(fieldApiName) &&
            Ken_Fee_Type__c.SObjectType.getDescribe().fields.getMap().containsKey(fieldApiName);
    }

    private static Id resolveInstituteId(String linkLevel, Id learningProgramPlanId, Id instituteProgramPlanId) {
        if (linkLevel == LINK_LEVEL_INSTITUTE_PROGRAM_PLAN) {
            return resolveInstituteIdFromInstituteProgramPlan(instituteProgramPlanId);
        }
        return resolveInstituteIdFromLearningProgramPlan(learningProgramPlanId);
    }

    private static Id resolveInstituteIdFromLearningProgramPlan(Id learningProgramPlanId) {
        LearningProgramPlan planRecord = [
            SELECT Id, LearningProgramId
            FROM LearningProgramPlan
            WHERE Id = :learningProgramPlanId
            LIMIT 1
        ];

        if (planRecord.LearningProgramId == null) {
            return null;
        }

        LearningProgram programRecord = [
            SELECT Id, Institute__c
            FROM LearningProgram
            WHERE Id = :planRecord.LearningProgramId
            LIMIT 1
        ];

        return programRecord.Institute__c;
    }

    private static Id resolveInstituteIdFromInstituteProgramPlan(Id instituteProgramPlanId) {
        if (instituteProgramPlanId == null) {
            return null;
        }

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey('Institute_Program_Plan__c')) {
            return null;
        }

        Schema.DescribeSObjectResult describeResult = globalDescribe.get('Institute_Program_Plan__c').getDescribe();
        if (!describeResult.fields.getMap().containsKey('Institute__c')) {
            return null;
        }

        SObject instituteProgramPlanRecord = Database.query(
            'SELECT Institute__c FROM Institute_Program_Plan__c WHERE Id = :instituteProgramPlanId LIMIT 1'
        );

        return (Id) instituteProgramPlanRecord.get('Institute__c');
    }


    private static List<Ken_Fee_Type_Line_Item__c> buildFeeTypeLines(
        Id feeTypeId,
        List<YearConfiguration> yearConfigurations,
        String feeTypeStatus
    ) {
        Set<Id> feeSetIds = new Set<Id>();

        for (YearConfiguration yearConfig : yearConfigurations) {
            if (yearConfig != null && yearConfig.feeSetId != null) {
                feeSetIds.add(yearConfig.feeSetId);
            }
        }

        Map<Id, List<Ken_Fee_Set_Line_Item__c>> feeSetLinesByFeeSetId =
            queryFeeSetLinesGroupedByFeeSet(feeSetIds);

        List<Ken_Fee_Type_Line_Item__c> feeTypeLineRecords = new List<Ken_Fee_Type_Line_Item__c>();
        Boolean shouldActivateLines = (feeTypeStatus == ConstantsController.FEE_SET_STATUS_ACTIVE); 

        for (YearConfiguration yearConfig : yearConfigurations) {
            List<Ken_Fee_Set_Line_Item__c> feeSetLineRows = feeSetLinesByFeeSetId.get(yearConfig.feeSetId);

            if (feeSetLineRows != null) {
                for (Ken_Fee_Set_Line_Item__c feeSetLineRow : feeSetLineRows) {
                    Ken_Fee_Type_Line_Item__c feeTypeLineRecord = new Ken_Fee_Type_Line_Item__c(
                        Ken_Fee_Type__c = feeTypeId,
                        Program_Year_Number__c = yearConfig.programYearNumber,
                        Fee_Set__c = yearConfig.feeSetId,
                        Fee_Head__c = feeSetLineRow.Fee_Head__c,
                        Student_Category__c = feeSetLineRow.Student_Category__c,
                        Amount__c = feeSetLineRow.Amount__c,
                        Remittance_Account__c = feeSetLineRow.Remittance_Account__c,
                        Tax__c = feeSetLineRow.Tax__c,
                        Due_Date__c = yearConfig.dueDate,
                        Is_Active__c = shouldActivateLines
                    );

                    feeTypeLineRecords.add(feeTypeLineRecord);
                }
            }
        }

        return feeTypeLineRecords;
    }


    private static Map<Id, List<Ken_Fee_Set_Line_Item__c>> queryFeeSetLinesGroupedByFeeSet(Set<Id> feeSetIds) {
        Map<Id, List<Ken_Fee_Set_Line_Item__c>> feeSetLinesByFeeSetId = new Map<Id, List<Ken_Fee_Set_Line_Item__c>>();

        if (!feeSetIds.isEmpty()) {
            for (Ken_Fee_Set_Line_Item__c feeSetLineRow : [
                SELECT
                    Id,
                    Ken_Fee_Set__c,
                    Fee_Head__c,
                    Student_Category__c,
                    Amount__c,
                    Remittance_Account__c,
                    Tax__c
                FROM Ken_Fee_Set_Line_Item__c
                WHERE Ken_Fee_Set__c IN :feeSetIds
            ]) {
                if (!feeSetLinesByFeeSetId.containsKey(feeSetLineRow.Ken_Fee_Set__c)) {
                    feeSetLinesByFeeSetId.put(feeSetLineRow.Ken_Fee_Set__c, new List<Ken_Fee_Set_Line_Item__c>());
                }
                feeSetLinesByFeeSetId.get(feeSetLineRow.Ken_Fee_Set__c).add(feeSetLineRow);
            }
        }

        return feeSetLinesByFeeSetId;
    }


    private static Id getRecordTypeIdByDeveloperName(Schema.SObjectType sObjectType, String recordTypeDeveloperName) {
        if (sObjectType == null || String.isBlank(recordTypeDeveloperName)) {
            return null;
        }

        String sObjectApiName = sObjectType.getDescribe().getName();

        List<RecordType> recordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = :sObjectApiName
              AND DeveloperName = :recordTypeDeveloperName
            LIMIT 1
        ];

        if (recordTypes.isEmpty()) {
            return null;
        }

        return recordTypes[0].Id;
    }

    private static Id getLateFeeRecordTypeId() {
        return getRecordTypeIdByDeveloperName(
            Ken_Fee_Type__c.SObjectType,
            ConstantsController.FEE_TYPE_RT_LATE_FEE
        );
    }

    private static Id getTaxRecordTypeId() {
        return getRecordTypeIdByDeveloperName(
            Ken_Tax_Definition__c.SObjectType,
            ConstantsController.TAX_RT_TAX
        );
    }
}