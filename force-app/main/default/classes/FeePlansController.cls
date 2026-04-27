public with sharing class FeePlansController {
    private static final String ERROR_FEE_PLAN_EDIT_IN_USE =
        'Cannot edit this fee plan because it is used in programme fees.';

    public class FeeHeadOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
        @AuraEnabled public Id taxId;
        @AuraEnabled public String taxLabel;
    }

    public class TaxOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
    }

    public class QuotaOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
        @AuraEnabled public String code;
        @AuraEnabled public Id categoryId;
        @AuraEnabled public String categoryName;
        @AuraEnabled public String categoryCurrency;
    }

    public class BuilderData {
        @AuraEnabled public List<FeeHeadOption> feeHeads;
        @AuraEnabled public List<QuotaOption> quotas;
        @AuraEnabled public List<TaxOption> taxes;
        @AuraEnabled public List<PicklistOption> currencyOptions;
        @AuraEnabled public String feePlanName;
        @AuraEnabled public String versionLabel;
        @AuraEnabled public String currencyPolicy;
        @AuraEnabled public List<MatrixLineInput> lines;
        @AuraEnabled public Boolean isEditRestricted;
        @AuraEnabled public String editRestrictionMessage;
    }

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class MatrixLineInput {
        @AuraEnabled public Id quotaId;
        @AuraEnabled public Id categoryId;
        @AuraEnabled public String quotaLabel;
        @AuraEnabled public String quotaCode;
        @AuraEnabled public Id feeHeadId;
        @AuraEnabled public Id taxId;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Integer settlementOrder;
    }

    public class SaveFeePlanRequest {
        @AuraEnabled public Id feeSetId;
        @AuraEnabled public String feePlanName;
        @AuraEnabled public String description;
        @AuraEnabled public String currencyPolicy;
        @AuraEnabled public String status;
        @AuraEnabled public List<MatrixLineInput> lines;
    }

    public class FeePlanRow {
        @AuraEnabled public Id feeSetId;
        @AuraEnabled public String feePlanName;
        @AuraEnabled public String status;
        @AuraEnabled public String versionLabel;
        @AuraEnabled public Integer categoryCount;
        @AuraEnabled public Datetime lastModified;
        @AuraEnabled public Integer usedInProgrammeFees;
    }

    public class FeePlanRecordData {
        @AuraEnabled public Id feeSetId;
        @AuraEnabled public String feePlanName;
        @AuraEnabled public String status;
        @AuraEnabled public String versionLabel;
        @AuraEnabled public String currencyPolicy;
        @AuraEnabled public String createdByName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Datetime lastModified;
        @AuraEnabled public String description;
        @AuraEnabled public List<CategoryGroup> categories;
        @AuraEnabled public UsageMetrics usageMetrics;
        @AuraEnabled public List<ProgrammeFeeConfigRow> programmeFeeConfigs;
        @AuraEnabled public List<VersionHistoryRow> versionHistory;
        @AuraEnabled public List<AuditLogRow> auditLogs;
    }

    public class CategoryGroup {
        @AuraEnabled public String categoryName;
        @AuraEnabled public Integer quotaCount;
        @AuraEnabled public List<QuotaEntry> quotas;
        @AuraEnabled public List<FeeStructureRow> feeRows;
        @AuraEnabled public List<String> quotaCodes;
    }

    public class QuotaEntry {
        @AuraEnabled public String quotaName;
        @AuraEnabled public String code;
        @AuraEnabled public String currencyCode;
    }

    public class FeeStructureRow {
        @AuraEnabled public String rowKey;
        @AuraEnabled public String feeHeadName;
        @AuraEnabled public Integer settlementOrder;
        @AuraEnabled public String taxSummary;
        @AuraEnabled public List<String> mappedQuotaCodes;
        @AuraEnabled public List<FeeStructureAmount> quotaAmounts;
    }

    public class FeeStructureAmount {
        @AuraEnabled public String quotaCode;
        @AuraEnabled public Decimal amount;
    }

    public class UsageMetrics {
        @AuraEnabled public Integer programmeFees;
        @AuraEnabled public Integer studentsAssigned;
        @AuraEnabled public Decimal totalRevenue;
    }

    public class ProgrammeFeeConfigRow {
        @AuraEnabled public String programmeName;
        @AuraEnabled public String batch;
        @AuraEnabled public String status;
        @AuraEnabled public Integer students;
    }

    public class VersionHistoryRow {
        @AuraEnabled public String version;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime changedOn;
        @AuraEnabled public String createdBy;
        @AuraEnabled public String changeReason;
    }

    public class AuditLogRow {
        @AuraEnabled public String action;
        @AuraEnabled public String userName;
        @AuraEnabled public Datetime eventAt;
        @AuraEnabled public String details;
    }

    @AuraEnabled
    public static List<FeePlanRow> getFeePlans() {
        List<Ken_Fee_Set__c> feeSets = [
            SELECT Id, Name, Status__c, Version_Number__c, LastModifiedDate
            FROM Ken_Fee_Set__c
            ORDER BY LastModifiedDate DESC
            LIMIT 500
        ];

        if (feeSets.isEmpty()) {
            return new List<FeePlanRow>();
        }

        Set<Id> feeSetIds = new Set<Id>();
        for (Ken_Fee_Set__c feeSet : feeSets) {
            feeSetIds.add(feeSet.Id);
        }

        Map<Id, Set<String>> categoryValuesByFeeSetId = new Map<Id, Set<String>>();
        for (Ken_Fee_Set_Line_Item__c line : [
            SELECT Ken_Fee_Set__c, Category__c, Category__r.Name, Student_Category__c
            FROM Ken_Fee_Set_Line_Item__c
            WHERE Ken_Fee_Set__c IN :feeSetIds
        ]) {
            if (!categoryValuesByFeeSetId.containsKey(line.Ken_Fee_Set__c)) {
                categoryValuesByFeeSetId.put(line.Ken_Fee_Set__c, new Set<String>());
            }
            if (line.Category__c != null) {
                categoryValuesByFeeSetId.get(line.Ken_Fee_Set__c).add(String.valueOf(line.Category__c));
            } else if (!String.isBlank(line.Category__r == null ? null : line.Category__r.Name)) {
                categoryValuesByFeeSetId.get(line.Ken_Fee_Set__c).add(line.Category__r.Name);
            } else if (!String.isBlank(line.Student_Category__c)) {
                categoryValuesByFeeSetId.get(line.Ken_Fee_Set__c).add(line.Student_Category__c);
            }
        }

        Map<Id, Integer> usageCountByFeeSetId = new Map<Id, Integer>();
        for (AggregateResult row : [
            SELECT Fee_Set__c feeSetId, COUNT_DISTINCT(Ken_Fee_Type__c) usedCount
            FROM Ken_Fee_Type_Line_Item__c
            WHERE Fee_Set__c IN :feeSetIds
            GROUP BY Fee_Set__c
        ]) {
            usageCountByFeeSetId.put(
                (Id) row.get('feeSetId'),
                Integer.valueOf(String.valueOf(row.get('usedCount')))
            );
        }

        List<FeePlanRow> result = new List<FeePlanRow>();
        for (Ken_Fee_Set__c feeSet : feeSets) {
            FeePlanRow dto = new FeePlanRow();
            dto.feeSetId = feeSet.Id;
            dto.feePlanName = feeSet.Name;
            dto.status = feeSet.Status__c;
            dto.versionLabel = feeSet.Version_Number__c == null
                ? '-'
                : 'v' + String.valueOf(Integer.valueOf(String.valueOf(feeSet.Version_Number__c)));
            dto.categoryCount = categoryValuesByFeeSetId.containsKey(feeSet.Id)
                ? categoryValuesByFeeSetId.get(feeSet.Id).size()
                : 0;
            dto.lastModified = feeSet.LastModifiedDate;
            dto.usedInProgrammeFees = usageCountByFeeSetId.containsKey(feeSet.Id)
                ? usageCountByFeeSetId.get(feeSet.Id)
                : 0;
            result.add(dto);
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static BuilderData getBuilderData(Id feeSetId) {
        BuilderData data = new BuilderData();
        data.feeHeads = new List<FeeHeadOption>();
        data.quotas = new List<QuotaOption>();
        data.taxes = new List<TaxOption>();
        data.currencyOptions = new List<PicklistOption>();
        data.lines = new List<MatrixLineInput>();

        String firstCurrencyPolicy;
        for (Schema.PicklistEntry pickValue : Ken_Fee_Set__c.Currency_Policy__c.getDescribe().getPicklistValues()) {
            if (pickValue != null && pickValue.isActive()) {
                if (firstCurrencyPolicy == null) {
                    firstCurrencyPolicy = pickValue.getValue();
                }
                PicklistOption option = new PicklistOption();
                option.label = pickValue.getLabel();
                option.value = pickValue.getValue();
                data.currencyOptions.add(option);
            }
        }

        for (Ken_Master_Fee_Head__c feeHead : [
            SELECT Id, Fee_Head_Name__c, Tax_Definition__c, Tax_Definition__r.Name, Is_Active__c
            FROM Ken_Master_Fee_Head__c
            WHERE Is_Active__c = true
            ORDER BY Fee_Head_Name__c ASC
            LIMIT 500
        ]) {
            FeeHeadOption option = new FeeHeadOption();
            option.id = feeHead.Id;
            option.label = String.isBlank(feeHead.Fee_Head_Name__c) ? String.valueOf(feeHead.Id) : feeHead.Fee_Head_Name__c;
            option.taxId = feeHead.Tax_Definition__c;
            option.taxLabel = feeHead.Tax_Definition__r == null ? null : feeHead.Tax_Definition__r.Name;
            data.feeHeads.add(option);
        }

        for (Ken_Tax_Definition__c taxDefinition : [
            SELECT Id, Name
            FROM Ken_Tax_Definition__c
            ORDER BY Name ASC
            LIMIT 500
        ]) {
            TaxOption option = new TaxOption();
            option.id = taxDefinition.Id;
            option.label = taxDefinition.Name;
            data.taxes.add(option);
        }

        for (Quota__c quota : [
            SELECT Id, Name, Code__c, Category__c, Category__r.Name, Category__r.CurrencyIsoCode, Active__c
            FROM Quota__c
            WHERE Active__c = true
            ORDER BY Category__r.Name ASC, Name ASC
            LIMIT 1000
        ]) {
            QuotaOption option = new QuotaOption();
            option.id = quota.Id;
            option.label = quota.Name;
            option.code = quota.Code__c;
            option.categoryId = quota.Category__c;
            option.categoryName = quota.Category__r == null ? null : quota.Category__r.Name;
            option.categoryCurrency = quota.Category__r == null ? null : quota.Category__r.CurrencyIsoCode;
            data.quotas.add(option);
        }

        if (feeSetId != null) {
            if (isFeePlanUsedInProgrammeFees(feeSetId)) {
                data.isEditRestricted = true;
                data.editRestrictionMessage = ERROR_FEE_PLAN_EDIT_IN_USE;
                return data;
            }

            Ken_Fee_Set__c feeSet = [
                SELECT Id, Name, Version_Number__c, Currency_Policy__c
                FROM Ken_Fee_Set__c
                WHERE Id = :feeSetId
                LIMIT 1
            ];
            data.feePlanName = feeSet.Name;
            data.currencyPolicy = feeSet.Currency_Policy__c;
            data.versionLabel = feeSet.Version_Number__c == null
                ? 'v1.0'
                : 'v' + String.valueOf(Integer.valueOf(String.valueOf(feeSet.Version_Number__c))) + '.0';

            List<Ken_Fee_Set_Line_Item__c> existingLines = [
                SELECT Fee_Head__c, Student_Category__c, Quota__c, Quota__r.Name, Quota__r.Code__c,
                    Quota__r.Category__c, Category__c, Category__r.Name, Amount__c, Tax__c, Settlement_Order__c
                FROM Ken_Fee_Set_Line_Item__c
                WHERE Ken_Fee_Set__c = :feeSetId
            ];

            Set<String> storedCategoryValues = new Set<String>();
            for (Ken_Fee_Set_Line_Item__c line : existingLines) {
                if (!String.isBlank(line.Student_Category__c)) {
                    storedCategoryValues.add(line.Student_Category__c);
                }
            }
            Map<String, Quota__c> quotaByNameOrCode = new Map<String, Quota__c>();
            if (!storedCategoryValues.isEmpty()) {
                for (Quota__c quota : [
                    SELECT Id, Name, Code__c, Category__c
                    FROM Quota__c
                    WHERE Name IN :storedCategoryValues OR Code__c IN :storedCategoryValues
                ]) {
                    if (!String.isBlank(quota.Name)) {
                        quotaByNameOrCode.put(quota.Name, quota);
                    }
                    if (!String.isBlank(quota.Code__c)) {
                        quotaByNameOrCode.put(quota.Code__c, quota);
                    }
                }
            }

            for (Ken_Fee_Set_Line_Item__c line : existingLines) {
                MatrixLineInput mappedLine = new MatrixLineInput();
                mappedLine.feeHeadId = line.Fee_Head__c;
                mappedLine.quotaId = line.Quota__c;
                mappedLine.categoryId = line.Category__c;
                if (line.Quota__c != null) {
                    mappedLine.quotaLabel = line.Quota__r == null ? null : line.Quota__r.Name;
                    mappedLine.quotaCode = line.Quota__r == null ? null : line.Quota__r.Code__c;
                    if (mappedLine.categoryId == null && line.Quota__r != null) {
                        mappedLine.categoryId = line.Quota__r.Category__c;
                    }
                } else {
                    Quota__c matchingQuota = String.isBlank(line.Student_Category__c) ? null : quotaByNameOrCode.get(line.Student_Category__c);
                    mappedLine.quotaId = matchingQuota == null ? null : matchingQuota.Id;
                    mappedLine.categoryId = matchingQuota == null ? null : matchingQuota.Category__c;
                    mappedLine.quotaLabel = matchingQuota == null ? line.Student_Category__c : matchingQuota.Name;
                    mappedLine.quotaCode = matchingQuota == null ? line.Student_Category__c : matchingQuota.Code__c;
                }
                mappedLine.amount = line.Amount__c;
                mappedLine.taxId = line.Tax__c;
                mappedLine.settlementOrder = line.Settlement_Order__c == null
                    ? null
                    : Integer.valueOf(String.valueOf(line.Settlement_Order__c));
                data.lines.add(mappedLine);
            }
        }

        if (String.isBlank(data.currencyPolicy)) {
            data.currencyPolicy = firstCurrencyPolicy;
        }

        return data;
    }

    @AuraEnabled
    public static Id saveFeePlan(String requestJson) {
        if (String.isBlank(requestJson)) {
            throw new AuraHandledException('Invalid request.');
        }

        SaveFeePlanRequest request = (SaveFeePlanRequest) JSON.deserialize(requestJson, SaveFeePlanRequest.class);
        if (request == null || String.isBlank(request.feePlanName)) {
            throw new AuraHandledException('Fee Plan Name is required.');
        }

        Ken_Fee_Set__c feeSet;
        Boolean isEditMode = request.feeSetId != null;
        if (isEditMode) {
            if (isFeePlanUsedInProgrammeFees(request.feeSetId)) {
                throw new AuraHandledException(ERROR_FEE_PLAN_EDIT_IN_USE);
            }
            feeSet = [
                SELECT Id, Name, Status__c, Version_Number__c, Currency_Policy__c
                FROM Ken_Fee_Set__c
                WHERE Id = :request.feeSetId
                LIMIT 1
            ];
        } else {
            feeSet = new Ken_Fee_Set__c();
            feeSet.Version_Number__c = 1;
        }

        feeSet.Name = request.feePlanName.trim();
        Set<String> allowedCurrencyPolicies = new Set<String>();
        String fallbackCurrencyPolicy;
        for (Schema.PicklistEntry pickValue : Ken_Fee_Set__c.Currency_Policy__c.getDescribe().getPicklistValues()) {
            if (pickValue != null && pickValue.isActive()) {
                allowedCurrencyPolicies.add(pickValue.getValue());
                if (fallbackCurrencyPolicy == null) {
                    fallbackCurrencyPolicy = pickValue.getValue();
                }
            }
        }
        if (!String.isBlank(request.currencyPolicy) && allowedCurrencyPolicies.contains(request.currencyPolicy)) {
            feeSet.Currency_Policy__c = request.currencyPolicy;
        } else if (!isEditMode && !String.isBlank(fallbackCurrencyPolicy)) {
            feeSet.Currency_Policy__c = fallbackCurrencyPolicy;
        }
        String requestedStatus = String.isBlank(request.status) ? 'Draft' : request.status.trim();
        if (requestedStatus != 'Draft' && requestedStatus != 'Active') {
            throw new AuraHandledException('Unsupported status.');
        }
        feeSet.Status__c = requestedStatus;

        List<Ken_Fee_Set_Line_Item__c> linesToInsert = new List<Ken_Fee_Set_Line_Item__c>();
        Set<Id> requestedQuotaIds = new Set<Id>();
        for (MatrixLineInput row : request.lines == null ? new List<MatrixLineInput>() : request.lines) {
            if (row != null && row.quotaId != null) {
                requestedQuotaIds.add(row.quotaId);
            }
        }
        Map<Id, Quota__c> quotasById = requestedQuotaIds.isEmpty()
            ? new Map<Id, Quota__c>()
            : new Map<Id, Quota__c>([
                SELECT Id, Name, Code__c, Category__c, Category__r.CurrencyIsoCode
                FROM Quota__c
                WHERE Id IN :requestedQuotaIds
            ]);

        Set<String> categoryCurrencies = new Set<String>();
        for (Quota__c quota : quotasById.values()) {
            String categoryCurrency = quota.Category__r == null ? null : quota.Category__r.CurrencyIsoCode;
            if (!String.isBlank(categoryCurrency)) {
                categoryCurrencies.add(categoryCurrency);
            }
        }
        if (categoryCurrencies.size() > 1) {
            List<String> currencies = new List<String>();
            currencies.addAll(categoryCurrencies);
            currencies.sort();
            throw new AuraHandledException(
                'Selected categories use multiple currencies (' + String.join(currencies, ', ')
                + '). Select quotas with a single currency.'
            );
        }
        if (!categoryCurrencies.isEmpty()) {
            String selectedCategoryCurrency;
            for (String currencyValue : categoryCurrencies) {
                selectedCategoryCurrency = currencyValue;
                break;
            }
            if (!allowedCurrencyPolicies.contains(selectedCategoryCurrency)) {
                throw new AuraHandledException(
                    'Currency Policy does not support selected category currency ' + selectedCategoryCurrency + '.'
                );
            }
            feeSet.Currency_Policy__c = selectedCategoryCurrency;
        }

        if (isEditMode) {
            update feeSet;
            delete [
                SELECT Id
                FROM Ken_Fee_Set_Line_Item__c
                WHERE Ken_Fee_Set__c = :feeSet.Id
            ];
        } else {
            insert feeSet;
        }

        Set<String> allowedStudentCategories = new Set<String>();
        for (Schema.PicklistEntry pickValue : Ken_Fee_Set_Line_Item__c.Student_Category__c.getDescribe().getPicklistValues()) {
            allowedStudentCategories.add(pickValue.getValue());
        }

        Map<Id, Integer> settlementOrderByFeeHeadId = new Map<Id, Integer>();
        Map<Integer, Id> feeHeadIdBySettlementOrder = new Map<Integer, Id>();

        for (MatrixLineInput row : request.lines == null ? new List<MatrixLineInput>() : request.lines) {
            if (row != null && row.feeHeadId != null) {
                if (row.settlementOrder != null) {
                    Integer normalizedSettlementOrder = row.settlementOrder < 1 ? 1 : row.settlementOrder;
                    if (settlementOrderByFeeHeadId.containsKey(row.feeHeadId)) {
                        if (settlementOrderByFeeHeadId.get(row.feeHeadId) != normalizedSettlementOrder) {
                            throw new AuraHandledException('Conflicting settlement order found for fee head.');
                        }
                    } else {
                        settlementOrderByFeeHeadId.put(row.feeHeadId, normalizedSettlementOrder);
                    }

                    if (feeHeadIdBySettlementOrder.containsKey(normalizedSettlementOrder)) {
                        if (feeHeadIdBySettlementOrder.get(normalizedSettlementOrder) != row.feeHeadId) {
                            throw new AuraHandledException('Each fee head must have a unique settlement order.');
                        }
                    } else {
                        feeHeadIdBySettlementOrder.put(normalizedSettlementOrder, row.feeHeadId);
                    }
                }

                Ken_Fee_Set_Line_Item__c line = new Ken_Fee_Set_Line_Item__c();
                line.Ken_Fee_Set__c = feeSet.Id;
                line.Fee_Head__c = row.feeHeadId;
                line.Tax__c = row.taxId;
                line.Amount__c = row.amount;
                if (row.settlementOrder != null) {
                    line.Settlement_Order__c = row.settlementOrder < 1 ? 1 : row.settlementOrder;
                }

                Quota__c selectedQuota = row.quotaId == null ? null : quotasById.get(row.quotaId);
                if (row.quotaId != null && selectedQuota == null) {
                    throw new AuraHandledException('Invalid quota selected.');
                }

                if (selectedQuota != null) {
                    line.Quota__c = selectedQuota.Id;
                    line.Category__c = selectedQuota.Category__c;
                    String quotaToken = String.isBlank(selectedQuota.Code__c) ? selectedQuota.Name : selectedQuota.Code__c;
                    if (!String.isBlank(quotaToken) && allowedStudentCategories.contains(quotaToken)) {
                        line.Student_Category__c = quotaToken;
                    }
                } else {
                    String resolvedStudentCategory = null;
                    if (!String.isBlank(row.quotaCode) && allowedStudentCategories.contains(row.quotaCode)) {
                        resolvedStudentCategory = row.quotaCode;
                    } else if (!String.isBlank(row.quotaLabel) && allowedStudentCategories.contains(row.quotaLabel)) {
                        resolvedStudentCategory = row.quotaLabel;
                    }
                    if (!String.isBlank(resolvedStudentCategory)) {
                        line.Student_Category__c = resolvedStudentCategory;
                    }
                }
                linesToInsert.add(line);
            }
        }

        if (!linesToInsert.isEmpty()) {
            insert linesToInsert;
        }

        return feeSet.Id;
    }

    @AuraEnabled
    public static Id cloneFeePlan(Id feeSetId) {
        if (feeSetId == null) {
            throw new AuraHandledException('Fee Plan Id is required.');
        }

        Ken_Fee_Set__c sourceFeeSet = [
            SELECT Id, Name, Status__c, Version_Number__c
            FROM Ken_Fee_Set__c
            WHERE Id = :feeSetId
            LIMIT 1
        ];

        Ken_Fee_Set__c clonedFeeSet = new Ken_Fee_Set__c();
        clonedFeeSet.Name = sourceFeeSet.Name;
        clonedFeeSet.Status__c = 'Draft';
        Integer nextVersion = sourceFeeSet.Version_Number__c == null
            ? 2
            : Integer.valueOf(String.valueOf(sourceFeeSet.Version_Number__c)) + 1;
        for (AggregateResult maxVersionResult : [
            SELECT MAX(Version_Number__c) maxVersion
            FROM Ken_Fee_Set__c
            WHERE Name = :sourceFeeSet.Name
        ]) {
            Decimal maxVersion = (Decimal) maxVersionResult.get('maxVersion');
            if (maxVersion != null) {
                Integer derivedVersion = Integer.valueOf(String.valueOf(maxVersion)) + 1;
                if (derivedVersion > nextVersion) {
                    nextVersion = derivedVersion;
                }
            }
        }
        clonedFeeSet.Version_Number__c = nextVersion;
        insert clonedFeeSet;

        List<Ken_Fee_Set_Line_Item__c> sourceLines = [
            SELECT Fee_Head__c, Student_Category__c, Quota__c, Category__c, Amount__c, Tax__c, Remittance_Account__c, Settlement_Order__c
            FROM Ken_Fee_Set_Line_Item__c
            WHERE Ken_Fee_Set__c = :feeSetId
        ];

        if (!sourceLines.isEmpty()) {
            List<Ken_Fee_Set_Line_Item__c> clonedLines = new List<Ken_Fee_Set_Line_Item__c>();
            for (Ken_Fee_Set_Line_Item__c sourceLine : sourceLines) {
                Ken_Fee_Set_Line_Item__c clonedLine = new Ken_Fee_Set_Line_Item__c();
                clonedLine.Ken_Fee_Set__c = clonedFeeSet.Id;
                clonedLine.Fee_Head__c = sourceLine.Fee_Head__c;
                clonedLine.Student_Category__c = sourceLine.Student_Category__c;
                clonedLine.Quota__c = sourceLine.Quota__c;
                clonedLine.Category__c = sourceLine.Category__c;
                clonedLine.Amount__c = sourceLine.Amount__c;
                clonedLine.Tax__c = sourceLine.Tax__c;
                clonedLine.Remittance_Account__c = sourceLine.Remittance_Account__c;
                clonedLine.Settlement_Order__c = sourceLine.Settlement_Order__c;
                clonedLines.add(clonedLine);
            }
            insert clonedLines;
        }

        return clonedFeeSet.Id;
    }

    @AuraEnabled
    public static void deleteFeePlan(Id feeSetId) {
        if (feeSetId == null) {
            throw new AuraHandledException('Fee Plan Id is required.');
        }

        Integer usageCount = getProgrammeFeeUsageCount(feeSetId);
        if (usageCount > 0) {
            throw new AuraHandledException('Cannot delete this fee plan because it is used in programme fees.');
        }

        delete [
            SELECT Id
            FROM Ken_Fee_Set_Line_Item__c
            WHERE Ken_Fee_Set__c = :feeSetId
        ];

        delete [
            SELECT Id
            FROM Ken_Fee_Set__c
            WHERE Id = :feeSetId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static FeePlanRecordData getFeePlanRecord(Id feeSetId) {
        if (feeSetId == null) {
            throw new AuraHandledException('Fee Plan Id is required.');
        }

        Ken_Fee_Set__c feeSet = [
            SELECT Id, Name, Status__c, Version_Number__c, Currency_Policy__c, CreatedDate, LastModifiedDate, CreatedBy.Name
            FROM Ken_Fee_Set__c
            WHERE Id = :feeSetId
            LIMIT 1
        ];

        List<Ken_Fee_Set_Line_Item__c> lines = [
            SELECT Id, Fee_Head__c, Fee_Head__r.Fee_Head_Name__c, Student_Category__c, Quota__c, Quota__r.Name,
                Quota__r.Code__c, Quota__r.Category__c, Quota__r.Category__r.Name, Quota__r.Category__r.CurrencyIsoCode,
                Category__c, Category__r.Name, Category__r.CurrencyIsoCode, Amount__c,
                Tax__c, Tax__r.Name, Tax__r.Tax_Rate__c, Settlement_Order__c
            FROM Ken_Fee_Set_Line_Item__c
            WHERE Ken_Fee_Set__c = :feeSetId
            ORDER BY Settlement_Order__c ASC, Fee_Head__r.Fee_Head_Name__c ASC
        ];

        Set<String> legacyQuotaTokens = new Set<String>();
        Set<Id> taxIds = new Set<Id>();
        for (Ken_Fee_Set_Line_Item__c line : lines) {
            if (line.Quota__c == null && !String.isBlank(line.Student_Category__c)) {
                legacyQuotaTokens.add(line.Student_Category__c);
            }
            if (line.Tax__c != null) {
                taxIds.add(line.Tax__c);
            }
        }

        Map<Id, List<Ken_Tax_Definition__c>> taxComponentsByParentId = new Map<Id, List<Ken_Tax_Definition__c>>();
        if (!taxIds.isEmpty()) {
            for (Ken_Tax_Definition__c component : [
                SELECT Id, Name, Tax_Rate__c, Parent_Tax__c
                FROM Ken_Tax_Definition__c
                WHERE Parent_Tax__c IN :taxIds
                ORDER BY Name ASC
            ]) {
                if (!taxComponentsByParentId.containsKey(component.Parent_Tax__c)) {
                    taxComponentsByParentId.put(component.Parent_Tax__c, new List<Ken_Tax_Definition__c>());
                }
                taxComponentsByParentId.get(component.Parent_Tax__c).add(component);
            }
        }

        Set<Id> feeTypeIds = new Set<Id>();
        for (AggregateResult usageRow : [
            SELECT Ken_Fee_Type__c feeTypeId
            FROM Ken_Fee_Type_Line_Item__c
            WHERE Fee_Set__c = :feeSetId AND Ken_Fee_Type__c != null
            GROUP BY Ken_Fee_Type__c
        ]) {
            feeTypeIds.add((Id) usageRow.get('feeTypeId'));
        }

        List<ProgrammeFeeConfigRow> programmeFeeConfigs = new List<ProgrammeFeeConfigRow>();
        if (!feeTypeIds.isEmpty()) {
            for (Ken_Fee_Type__c feeType : [
                SELECT Id, Fee_Type_Name__c, Status__c
                FROM Ken_Fee_Type__c
                WHERE Id IN :feeTypeIds
                ORDER BY LastModifiedDate DESC
                LIMIT 100
            ]) {
                ProgrammeFeeConfigRow row = new ProgrammeFeeConfigRow();
                row.programmeName = String.isBlank(feeType.Fee_Type_Name__c) ? 'Programme Fee' : feeType.Fee_Type_Name__c;
                row.batch = '-';
                row.status = String.isBlank(feeType.Status__c) ? 'Draft' : feeType.Status__c;
                row.students = 0;
                programmeFeeConfigs.add(row);
            }
        }

        Decimal totalRevenue = 0;
        for (Ken_Fee_Set_Line_Item__c line : lines) {
            if (line.Amount__c != null) {
                totalRevenue += line.Amount__c;
            }
        }

        UsageMetrics usageMetrics = new UsageMetrics();
        usageMetrics.programmeFees = feeTypeIds.size();
        usageMetrics.studentsAssigned = 0;
        usageMetrics.totalRevenue = totalRevenue;

        List<VersionHistoryRow> versionHistoryRows = new List<VersionHistoryRow>();
        VersionHistoryRow currentVersion = new VersionHistoryRow();
        currentVersion.version = feeSet.Version_Number__c == null
            ? 'v1.0'
            : 'v' + String.valueOf(Integer.valueOf(String.valueOf(feeSet.Version_Number__c))) + '.0';
        currentVersion.status = String.isBlank(feeSet.Status__c) ? 'Draft' : feeSet.Status__c;
        currentVersion.changedOn = feeSet.LastModifiedDate;
        currentVersion.createdBy = feeSet.CreatedBy == null ? null : feeSet.CreatedBy.Name;
        currentVersion.changeReason = 'Initial version';
        versionHistoryRows.add(currentVersion);

        List<AuditLogRow> auditRows = new List<AuditLogRow>();
        AuditLogRow createdAudit = new AuditLogRow();
        createdAudit.action = 'Created';
        createdAudit.userName = feeSet.CreatedBy == null ? null : feeSet.CreatedBy.Name;
        createdAudit.eventAt = feeSet.CreatedDate;
        createdAudit.details = 'Initial draft created';
        auditRows.add(createdAudit);

        if (String.valueOf(feeSet.Status__c).toLowerCase() == 'active') {
            AuditLogRow activeAudit = new AuditLogRow();
            activeAudit.action = 'Activated';
            activeAudit.userName = feeSet.CreatedBy == null ? null : feeSet.CreatedBy.Name;
            activeAudit.eventAt = feeSet.LastModifiedDate;
            activeAudit.details = 'Plan activated';
            auditRows.add(0, activeAudit);
        }

        Map<String, Quota__c> quotaByNameOrCode = new Map<String, Quota__c>();
        if (!legacyQuotaTokens.isEmpty()) {
            for (Quota__c quota : [
                SELECT Id, Name, Code__c, Category__r.Name, Category__r.CurrencyIsoCode
                FROM Quota__c
                WHERE Name IN :legacyQuotaTokens OR Code__c IN :legacyQuotaTokens
            ]) {
                if (!String.isBlank(quota.Name)) {
                    quotaByNameOrCode.put(quota.Name, quota);
                }
                if (!String.isBlank(quota.Code__c)) {
                    quotaByNameOrCode.put(quota.Code__c, quota);
                }
            }
        }

        Map<String, CategoryGroup> groupsByCategory = new Map<String, CategoryGroup>();
        Map<String, Set<String>> quotaCodeSetsByCategory = new Map<String, Set<String>>();
        Map<String, Map<Id, FeeStructureRow>> feeRowsByCategoryByHead = new Map<String, Map<Id, FeeStructureRow>>();
        Map<String, Map<Id, Set<String>>> taxSummariesByCategoryByHead = new Map<String, Map<Id, Set<String>>>();

        for (Ken_Fee_Set_Line_Item__c line : lines) {
            Id quotaId = line.Quota__c;
            String quotaName = line.Quota__r == null ? null : line.Quota__r.Name;
            String quotaCode = line.Quota__r == null ? null : line.Quota__r.Code__c;
            String categoryName = line.Category__r == null ? null : line.Category__r.Name;
            String categoryCurrencyCode = line.Category__r == null ? null : line.Category__r.CurrencyIsoCode;

            if (String.isBlank(categoryName) && line.Quota__r != null && line.Quota__r.Category__r != null) {
                categoryName = line.Quota__r.Category__r.Name;
            }
            if (String.isBlank(categoryCurrencyCode) && line.Quota__r != null && line.Quota__r.Category__r != null) {
                categoryCurrencyCode = line.Quota__r.Category__r.CurrencyIsoCode;
            }

            if (quotaId == null) {
                String quotaToken = line.Student_Category__c;
                Quota__c legacyQuota = String.isBlank(quotaToken) ? null : quotaByNameOrCode.get(quotaToken);
                if (legacyQuota != null) {
                    quotaId = legacyQuota.Id;
                    quotaName = legacyQuota.Name;
                    quotaCode = legacyQuota.Code__c;
                    if (String.isBlank(categoryName) && legacyQuota.Category__r != null) {
                        categoryName = legacyQuota.Category__r.Name;
                    }
                    if (String.isBlank(categoryCurrencyCode) && legacyQuota.Category__r != null) {
                        categoryCurrencyCode = legacyQuota.Category__r.CurrencyIsoCode;
                    }
                }
            }

            if (String.isBlank(categoryName)) {
                categoryName = 'Uncategorized';
            }

            if (!groupsByCategory.containsKey(categoryName)) {
                CategoryGroup categoryGroup = new CategoryGroup();
                categoryGroup.categoryName = categoryName;
                categoryGroup.quotas = new List<QuotaEntry>();
                categoryGroup.feeRows = new List<FeeStructureRow>();
                categoryGroup.quotaCodes = new List<String>();
                groupsByCategory.put(categoryName, categoryGroup);
                quotaCodeSetsByCategory.put(categoryName, new Set<String>());
                feeRowsByCategoryByHead.put(categoryName, new Map<Id, FeeStructureRow>());
                taxSummariesByCategoryByHead.put(categoryName, new Map<Id, Set<String>>());
            }

            if (quotaId != null) {
                Set<String> existingCodes = quotaCodeSetsByCategory.get(categoryName);
                String codeValue = String.isBlank(quotaCode) ? quotaName : quotaCode;
                if (!existingCodes.contains(codeValue)) {
                    existingCodes.add(codeValue);
                    QuotaEntry quotaEntry = new QuotaEntry();
                    quotaEntry.quotaName = quotaName;
                    quotaEntry.code = codeValue;
                    quotaEntry.currencyCode = String.isBlank(categoryCurrencyCode)
                        ? feeSet.Currency_Policy__c
                        : categoryCurrencyCode;
                    groupsByCategory.get(categoryName).quotas.add(quotaEntry);
                }
            }

            if (line.Fee_Head__c != null) {
                Map<Id, FeeStructureRow> rowsByHead = feeRowsByCategoryByHead.get(categoryName);
                if (!rowsByHead.containsKey(line.Fee_Head__c)) {
                    FeeStructureRow row = new FeeStructureRow();
                    row.feeHeadName = line.Fee_Head__r == null || String.isBlank(line.Fee_Head__r.Fee_Head_Name__c)
                        ? 'Fee Head'
                        : line.Fee_Head__r.Fee_Head_Name__c;
                    row.rowKey = String.valueOf(line.Fee_Head__c) + '_' + categoryName;
                    row.settlementOrder = line.Settlement_Order__c == null
                        ? null
                        : Integer.valueOf(String.valueOf(line.Settlement_Order__c));
                    row.taxSummary = '-';
                    row.mappedQuotaCodes = new List<String>();
                    row.quotaAmounts = new List<FeeStructureAmount>();
                    rowsByHead.put(line.Fee_Head__c, row);
                    groupsByCategory.get(categoryName).feeRows.add(row);
                    taxSummariesByCategoryByHead.get(categoryName).put(line.Fee_Head__c, new Set<String>());
                }

                String taxSummary = buildTaxSummary(line.Tax__r, taxComponentsByParentId.get(line.Tax__c));
                if (!String.isBlank(taxSummary) && taxSummary != '-') {
                    Set<String> taxSummarySet = taxSummariesByCategoryByHead.get(categoryName).get(line.Fee_Head__c);
                    if (taxSummarySet == null) {
                        taxSummarySet = new Set<String>();
                        taxSummariesByCategoryByHead.get(categoryName).put(line.Fee_Head__c, taxSummarySet);
                    }
                    taxSummarySet.add(taxSummary);
                    FeeStructureRow rowForTax = rowsByHead.get(line.Fee_Head__c);
                    rowForTax.taxSummary = joinTaxSummaries(taxSummarySet);
                }

                if (quotaId != null) {
                    String codeValue = String.isBlank(quotaCode) ? quotaName : quotaCode;
                    FeeStructureRow row = rowsByHead.get(line.Fee_Head__c);
                    if (!row.mappedQuotaCodes.contains(codeValue)) {
                        row.mappedQuotaCodes.add(codeValue);
                    }
                    FeeStructureAmount existingQuotaAmount = null;
                    for (FeeStructureAmount quotaAmount : row.quotaAmounts) {
                        if (quotaAmount.quotaCode == codeValue && existingQuotaAmount == null) {
                            existingQuotaAmount = quotaAmount;
                        }
                    }
                    if (existingQuotaAmount != null) {
                        existingQuotaAmount.amount = (existingQuotaAmount.amount == null ? 0 : existingQuotaAmount.amount)
                            + (line.Amount__c == null ? 0 : line.Amount__c);
                    } else {
                        FeeStructureAmount quotaAmount = new FeeStructureAmount();
                        quotaAmount.quotaCode = codeValue;
                        quotaAmount.amount = line.Amount__c;
                        row.quotaAmounts.add(quotaAmount);
                    }
                }
            }
        }

        List<String> sortedCategoryNames = new List<String>();
        sortedCategoryNames.addAll(groupsByCategory.keySet());
        sortedCategoryNames.sort();

        List<CategoryGroup> categories = new List<CategoryGroup>();
        for (String categoryName : sortedCategoryNames) {
            CategoryGroup categoryGroup = groupsByCategory.get(categoryName);
            categoryGroup.quotaCount = categoryGroup.quotas == null ? 0 : categoryGroup.quotas.size();

            Set<String> codeSet = quotaCodeSetsByCategory.get(categoryName);
            categoryGroup.quotaCodes = new List<String>();
            if (codeSet != null && !codeSet.isEmpty()) {
                categoryGroup.quotaCodes.addAll(codeSet);
                categoryGroup.quotaCodes.sort();
            }
            if (categoryGroup.feeRows != null && !categoryGroup.feeRows.isEmpty()) {
                categoryGroup.feeRows.sort(new FeeStructureRowSort());
            }
            categories.add(categoryGroup);
        }

        FeePlanRecordData data = new FeePlanRecordData();
        data.feeSetId = feeSet.Id;
        data.feePlanName = feeSet.Name;
        data.status = feeSet.Status__c;
        data.versionLabel = feeSet.Version_Number__c == null
            ? 'v1.0'
            : 'v' + String.valueOf(Integer.valueOf(String.valueOf(feeSet.Version_Number__c))) + '.0';
        data.currencyPolicy = feeSet.Currency_Policy__c;
        data.createdByName = feeSet.CreatedBy == null ? null : feeSet.CreatedBy.Name;
        data.createdDate = feeSet.CreatedDate;
        data.lastModified = feeSet.LastModifiedDate;
        data.description = null;
        data.categories = categories;
        data.usageMetrics = usageMetrics;
        data.programmeFeeConfigs = programmeFeeConfigs;
        data.versionHistory = versionHistoryRows;
        data.auditLogs = auditRows;
        return data;
    }

    private static String buildTaxSummary(Ken_Tax_Definition__c tax, List<Ken_Tax_Definition__c> components) {
        if (tax == null) {
            return '-';
        }

        String baseLabel = formatTaxLabel(tax.Name, tax.Tax_Rate__c);
        if (components == null || components.isEmpty()) {
            return baseLabel;
        }

        List<String> componentLabels = new List<String>();
        for (Ken_Tax_Definition__c component : components) {
            componentLabels.add(formatTaxLabel(component.Name, component.Tax_Rate__c));
        }
        return baseLabel + ' (' + String.join(componentLabels, ' + ') + ')';
    }

    private static String formatTaxLabel(String nameValue, Decimal rateValue) {
        String safeName = String.isBlank(nameValue) ? 'Tax' : nameValue;
        if (rateValue == null) {
            return safeName;
        }
        return safeName + ' ' + String.valueOf(rateValue) + '%';
    }

    private static String joinTaxSummaries(Set<String> summaries) {
        if (summaries == null || summaries.isEmpty()) {
            return '-';
        }
        List<String> labels = new List<String>();
        labels.addAll(summaries);
        labels.sort();
        return String.join(labels, ' | ');
    }

    private static Integer getProgrammeFeeUsageCount(Id feeSetId) {
        if (feeSetId == null) {
            return 0;
        }
        return [
            SELECT COUNT()
            FROM Ken_Fee_Type_Line_Item__c
            WHERE Fee_Set__c = :feeSetId
        ];
    }

    private static Boolean isFeePlanUsedInProgrammeFees(Id feeSetId) {
        return getProgrammeFeeUsageCount(feeSetId) > 0;
    }

    private class FeeStructureRowSort implements Comparator<FeeStructureRow> {
        public Integer compare(FeeStructureRow a, FeeStructureRow b) {
            Integer left = a == null || a.settlementOrder == null ? 2147483647 : a.settlementOrder;
            Integer right = b == null || b.settlementOrder == null ? 2147483647 : b.settlementOrder;
            if (left == right) {
                String leftName = a == null || a.feeHeadName == null ? '' : a.feeHeadName;
                String rightName = b == null || b.feeHeadName == null ? '' : b.feeHeadName;
                return leftName.toLowerCase().compareTo(rightName.toLowerCase());
            }
            return left < right ? -1 : 1;
        }
    }
}