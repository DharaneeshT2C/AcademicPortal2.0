public with sharing class FeeHeadsController {
    private static final String ERROR_FEE_HEAD_IN_USE =
        'Cannot delete fee head because it is used in fee plans or programme fee configurations.';

    public class FeeHeadRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String feeHeadName;
        @AuraEnabled public String feeHeadType;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Boolean refundable;
        @AuraEnabled public Boolean taxable;
        @AuraEnabled public Id defaultRemittanceAccountId;
        @AuraEnabled public String defaultRemittanceAccountName;
        @AuraEnabled public String defaultRemittanceAccountNumber;
        @AuraEnabled public Id taxDefinitionId;
        @AuraEnabled public String description;
        @AuraEnabled public Boolean isChild;
        @AuraEnabled public Id parentFeeHeadId;
        @AuraEnabled public String parentFeeHeadName;
        @AuraEnabled public String currencyIsoCode;
        @AuraEnabled public Id ownerId;
        @AuraEnabled public String ownerName;
        @AuraEnabled public Id recordTypeId;
        @AuraEnabled public String recordTypeName;
        @AuraEnabled public Id createdById;
        @AuraEnabled public String createdByName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Id lastModifiedById;
        @AuraEnabled public String lastModifiedByName;
        @AuraEnabled public Datetime lastModifiedDate;
        @AuraEnabled public Integer usedInFeePlans;
        @AuraEnabled public Integer usedInProgrammeFees;
        @AuraEnabled public Integer manualAssignments;
    }

    public class OptionRow {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class TaxOptionRow {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Decimal taxRate;
    }

    @AuraEnabled(cacheable=true)
    public static List<FeeHeadRow> getFeeHeads() {
        List<Ken_Master_Fee_Head__c> rows = [
            SELECT
                Id,
                Name,
                Fee_Head_Name__c,
                Fee_Head_Type__c,
                Is_Active__c,
                Refundable__c,
                Taxable__c,
                Default_Remittance_Account__c,
                Default_Remittance_Account__r.Name,
                Default_Remittance_Account__r.Bank_Account_Name__c,
                Default_Remittance_Account__r.Account_Number__c,
                Tax_Definition__c,
                Description__c,
                Is_Child__c,
                Parent_Fee_Head__c,
                Parent_Fee_Head__r.Fee_Head_Name__c,
                CurrencyIsoCode,
                OwnerId,
                Owner.Name,
                RecordTypeId,
                RecordType.Name,
                CreatedById,
                CreatedBy.Name,
                CreatedDate,
                LastModifiedById,
                LastModifiedBy.Name,
                LastModifiedDate
            FROM Ken_Master_Fee_Head__c
            ORDER BY LastModifiedDate DESC
            LIMIT 500
        ];

        List<FeeHeadRow> result = new List<FeeHeadRow>();
        Set<Id> feeHeadIds = new Set<Id>();
        for (Ken_Master_Fee_Head__c row : rows) {
            feeHeadIds.add(row.Id);
            FeeHeadRow mapped = new FeeHeadRow();
            mapped.id = row.Id;
            mapped.name = row.Name;
            mapped.feeHeadName = row.Fee_Head_Name__c;
            mapped.feeHeadType = row.Fee_Head_Type__c;
            mapped.isActive = (Boolean) row.get('Is_Active__c');
            mapped.refundable = (Boolean) row.get('Refundable__c');
            mapped.taxable = (Boolean) row.get('Taxable__c');
            mapped.defaultRemittanceAccountId = (Id) row.get('Default_Remittance_Account__c');
            mapped.defaultRemittanceAccountName = row.Default_Remittance_Account__r != null
                ? String.isBlank(row.Default_Remittance_Account__r.Bank_Account_Name__c)
                    ? row.Default_Remittance_Account__r.Name
                    : row.Default_Remittance_Account__r.Bank_Account_Name__c
                : null;
            mapped.defaultRemittanceAccountNumber = row.Default_Remittance_Account__r != null
                ? row.Default_Remittance_Account__r.Account_Number__c
                : null;
            mapped.taxDefinitionId = (Id) row.get('Tax_Definition__c');
            mapped.description = (String) row.get('Description__c');
            mapped.isChild = row.Is_Child__c;
            mapped.parentFeeHeadId = row.Parent_Fee_Head__c;
            mapped.parentFeeHeadName = row.Parent_Fee_Head__r != null ? row.Parent_Fee_Head__r.Fee_Head_Name__c : null;
            mapped.currencyIsoCode = row.CurrencyIsoCode;
            mapped.ownerId = row.OwnerId;
            mapped.ownerName = row.Owner != null ? row.Owner.Name : null;
            mapped.recordTypeId = row.RecordTypeId;
            mapped.recordTypeName = row.RecordType != null ? row.RecordType.Name : null;
            mapped.createdById = row.CreatedById;
            mapped.createdByName = row.CreatedBy != null ? row.CreatedBy.Name : null;
            mapped.createdDate = row.CreatedDate;
            mapped.lastModifiedById = row.LastModifiedById;
            mapped.lastModifiedByName = row.LastModifiedBy != null ? row.LastModifiedBy.Name : null;
            mapped.lastModifiedDate = row.LastModifiedDate;
            result.add(mapped);
        }

        Map<Id, Integer> feePlansByHeadId = new Map<Id, Integer>();
        Map<Id, Integer> programmeFeesByHeadId = new Map<Id, Integer>();
        Map<Id, Integer> manualAssignmentsByHeadId = new Map<Id, Integer>();

        if (!feeHeadIds.isEmpty()) {
            for (AggregateResult usageRow : [
                SELECT Fee_Head__c feeHeadId, COUNT_DISTINCT(Ken_Fee_Set__c) planCount
                FROM Ken_Fee_Set_Line_Item__c
                WHERE Fee_Head__c IN :feeHeadIds
                GROUP BY Fee_Head__c
            ]) {
                feePlansByHeadId.put(
                    (Id) usageRow.get('feeHeadId'),
                    (Integer) usageRow.get('planCount')
                );
            }

            for (AggregateResult usageRow : [
                SELECT Fee_Head__c feeHeadId, COUNT_DISTINCT(Ken_Fee_Type__c) programmeCount, COUNT(Id) lineCount
                FROM Ken_Fee_Type_Line_Item__c
                WHERE Fee_Head__c IN :feeHeadIds
                GROUP BY Fee_Head__c
            ]) {
                Id feeHeadId = (Id) usageRow.get('feeHeadId');
                programmeFeesByHeadId.put(feeHeadId, (Integer) usageRow.get('programmeCount'));
                manualAssignmentsByHeadId.put(feeHeadId, (Integer) usageRow.get('lineCount'));
            }
        }

        for (FeeHeadRow mapped : result) {
            mapped.usedInFeePlans = feePlansByHeadId.containsKey(mapped.id) ? feePlansByHeadId.get(mapped.id) : 0;
            mapped.usedInProgrammeFees = programmeFeesByHeadId.containsKey(mapped.id) ? programmeFeesByHeadId.get(mapped.id) : 0;
            mapped.manualAssignments = manualAssignmentsByHeadId.containsKey(mapped.id) ? manualAssignmentsByHeadId.get(mapped.id) : 0;
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionRow> getFeeHeadTypeOptions() {
        Map<String, String> labelToValue = new Map<String, String>();
        for (Schema.PicklistEntry entry : Ken_Master_Fee_Head__c.Fee_Head_Type__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                labelToValue.put(entry.getLabel(), entry.getValue());
            }
        }

        List<String> labels = new List<String>(labelToValue.keySet());
        labels.sort();

        List<OptionRow> options = new List<OptionRow>();
        for (String label : labels) {
            OptionRow option = new OptionRow();
            option.label = label;
            option.value = labelToValue.get(label);
            options.add(option);
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionRow> getRemittanceAccountOptions() {
        List<Ken_Bank_Account_Master__c> rows = [
            SELECT Id, Name, Bank_Account_Name__c, Account_Number__c
            FROM Ken_Bank_Account_Master__c
            ORDER BY Bank_Account_Name__c ASC, Name ASC
            LIMIT 500
        ];

        List<OptionRow> options = new List<OptionRow>();
        for (Ken_Bank_Account_Master__c row : rows) {
            String accountName = String.isBlank(row.Bank_Account_Name__c) ? row.Name : row.Bank_Account_Name__c;
            String accountNumber = String.isBlank(row.Account_Number__c) ? null : row.Account_Number__c;

            OptionRow option = new OptionRow();
            option.label = accountNumber == null ? accountName : accountName + ' - ' + accountNumber;
            option.value = row.Id;
            options.add(option);
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<TaxOptionRow> getTaxDefinitionOptions() {
        List<Ken_Tax_Definition__c> rows = [
            SELECT Id, Name, Tax_Rate__c
            FROM Ken_Tax_Definition__c
            WHERE Parent_Tax__c = null
            ORDER BY Name ASC
            LIMIT 500
        ];

        List<TaxOptionRow> options = new List<TaxOptionRow>();
        for (Ken_Tax_Definition__c row : rows) {
            TaxOptionRow option = new TaxOptionRow();
            option.label = row.Name;
            option.value = row.Id;
            option.taxRate = row.Tax_Rate__c;
            options.add(option);
        }
        return options;
    }

    @AuraEnabled
    public static Id createFeeHead(
        String feeHeadName,
        String feeHeadType,
        Boolean isActive,
        Boolean refundable,
        Boolean taxable,
        Id defaultRemittanceAccountId,
        Id taxDefinitionId,
        String description
    ) {
        String normalizedName = feeHeadName == null ? '' : feeHeadName.trim();
        if (String.isBlank(normalizedName)) {
            throw new AuraHandledException('Fee Head Name is required.');
        }
        if (String.isBlank(feeHeadType)) {
            throw new AuraHandledException('Head Category is required.');
        }

        Ken_Master_Fee_Head__c feeHead = new Ken_Master_Fee_Head__c();
        feeHead.Fee_Head_Name__c = normalizedName;
        feeHead.Fee_Head_Type__c = feeHeadType;
        feeHead.put('Is_Active__c', isActive == null ? true : isActive);
        feeHead.put('Refundable__c', refundable == true);
        feeHead.put('Taxable__c', taxable == true);
        feeHead.put('Default_Remittance_Account__c', defaultRemittanceAccountId);
        feeHead.put('Tax_Definition__c', taxDefinitionId);
        feeHead.put('Description__c', String.isBlank(description) ? null : description.trim());

        insert feeHead;
        return feeHead.Id;
    }

    @AuraEnabled
    public static Id updateFeeHead(
        Id feeHeadId,
        String feeHeadName,
        String feeHeadType,
        Boolean isActive,
        Boolean refundable,
        Boolean taxable,
        Id defaultRemittanceAccountId,
        Id taxDefinitionId,
        String description
    ) {
        if (feeHeadId == null) {
            throw new AuraHandledException('Fee Head is required.');
        }

        String normalizedName = feeHeadName == null ? '' : feeHeadName.trim();
        if (String.isBlank(normalizedName)) {
            throw new AuraHandledException('Fee Head Name is required.');
        }
        if (String.isBlank(feeHeadType)) {
            throw new AuraHandledException('Head Category is required.');
        }

        Ken_Master_Fee_Head__c feeHead = [
            SELECT Id
            FROM Ken_Master_Fee_Head__c
            WHERE Id = :feeHeadId
            LIMIT 1
        ];

        feeHead.Fee_Head_Name__c = normalizedName;
        feeHead.Fee_Head_Type__c = feeHeadType;
        feeHead.put('Is_Active__c', isActive == null ? true : isActive);
        feeHead.put('Refundable__c', refundable == true);
        feeHead.put('Taxable__c', taxable == true);
        feeHead.put('Default_Remittance_Account__c', defaultRemittanceAccountId);
        feeHead.put('Tax_Definition__c', taxDefinitionId);
        feeHead.put('Description__c', String.isBlank(description) ? null : description.trim());
        update feeHead;
        return feeHead.Id;
    }

    @AuraEnabled
    public static void deleteFeeHead(Id feeHeadId) {
        if (feeHeadId == null) {
            throw new AuraHandledException('Fee Head is required.');
        }

        if (isFeeHeadUsedInFeeSetLines(feeHeadId) || isFeeHeadUsedInFeeTypeLines(feeHeadId)) {
            throw new AuraHandledException(ERROR_FEE_HEAD_IN_USE);
        }

        delete [
            SELECT Id
            FROM Ken_Master_Fee_Head__c
            WHERE Id = :feeHeadId
            LIMIT 1
        ];
    }

    private static Boolean isFeeHeadUsedInFeeSetLines(Id feeHeadId) {
        return [
            SELECT Count()
            FROM Ken_Fee_Set_Line_Item__c
            WHERE Fee_Head__c = :feeHeadId
        ] > 0;
    }

    private static Boolean isFeeHeadUsedInFeeTypeLines(Id feeHeadId) {
        return [
            SELECT Count()
            FROM Ken_Fee_Type_Line_Item__c
            WHERE Fee_Head__c = :feeHeadId
        ] > 0;
    }
}