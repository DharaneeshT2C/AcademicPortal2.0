public with sharing class QuotaCategoryDtos {
    public class CategoryRow {
        @AuraEnabled public Id categoryId;
        @AuraEnabled public String categoryName;
        @AuraEnabled public String categoryType;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public String regulatorySource;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Integer quotaCount;
        @AuraEnabled public List<QuotaRow> quotas;
        @AuraEnabled public String createdByName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Datetime lastUpdated;
    }

    public class QuotaRow {
        @AuraEnabled public Id quotaId;
        @AuraEnabled public Id categoryId;
        @AuraEnabled public String quotaName;
        @AuraEnabled public String code;
        @AuraEnabled public Decimal reservationPercent;
        @AuraEnabled public Integer priorityOrder;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Datetime lastUpdated;
    }

    public class SaveCategoryRequest {
        @AuraEnabled public Id categoryId;
        @AuraEnabled public String categoryName;
        @AuraEnabled public String categoryType;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public String regulatorySource;
        @AuraEnabled public Boolean isActive;
    }

    public class CategoryBuilderData {
        @AuraEnabled public List<String> categoryTypeOptions;
        @AuraEnabled public List<CurrencyOption> currencyOptions;
        @AuraEnabled public CategoryRow category;
    }

    public class CurrencyOption {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
    }

    public class SaveQuotaRequest {
        @AuraEnabled public Id quotaId;
        @AuraEnabled public Id categoryId;
        @AuraEnabled public String quotaName;
        @AuraEnabled public String code;
        @AuraEnabled public Decimal reservationPercent;
        @AuraEnabled public Integer priorityOrder;
        @AuraEnabled public Boolean isActive;
    }
}