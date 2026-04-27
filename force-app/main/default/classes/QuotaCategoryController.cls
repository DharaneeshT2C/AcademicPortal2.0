public with sharing class QuotaCategoryController {

    @AuraEnabled(cacheable=true)
    public static List<QuotaCategoryDtos.CategoryRow> getCategoriesWithQuotas() {
        return QuotaCategoryService.getCategoriesWithQuotas();
    }

    @AuraEnabled(cacheable=true)
    public static QuotaCategoryDtos.CategoryRow getCategoryWithQuotas(Id categoryId) {
        return QuotaCategoryService.getCategoryWithQuotas(categoryId);
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getCategoryTypeOptions() {
        return QuotaCategoryService.getCategoryTypeOptions();
    }

    @AuraEnabled(cacheable=true)
    public static QuotaCategoryDtos.CategoryBuilderData getCategoryBuilderData(Id categoryId) {
        return QuotaCategoryService.getCategoryBuilderData(categoryId);
    }

    @AuraEnabled
    public static Id saveCategory(
        Id categoryId,
        String categoryName,
        String categoryType,
        String currencyCode,
        String regulatorySource,
        Boolean isActive
    ) {
        QuotaCategoryDtos.SaveCategoryRequest requestDto = new QuotaCategoryDtos.SaveCategoryRequest();
        requestDto.categoryId = categoryId;
        requestDto.categoryName = categoryName;
        requestDto.categoryType = categoryType;
        requestDto.currencyCode = currencyCode;
        requestDto.regulatorySource = regulatorySource;
        requestDto.isActive = isActive;
        return QuotaCategoryService.saveCategory(requestDto);
    }

    @AuraEnabled
    public static Id saveQuota(
        Id quotaId,
        Id categoryId,
        String quotaName,
        String code,
        Decimal reservationPercent,
        Integer priorityOrder,
        Boolean isActive
    ) {
        QuotaCategoryDtos.SaveQuotaRequest requestDto = new QuotaCategoryDtos.SaveQuotaRequest();
        requestDto.quotaId = quotaId;
        requestDto.categoryId = categoryId;
        requestDto.quotaName = quotaName;
        requestDto.code = code;
        requestDto.reservationPercent = reservationPercent;
        requestDto.priorityOrder = priorityOrder;
        requestDto.isActive = isActive;
        return QuotaCategoryService.saveQuota(requestDto);
    }

    @AuraEnabled
    public static void deleteCategory(Id categoryId) {
        QuotaCategoryService.deleteCategory(categoryId);
    }

    @AuraEnabled
    public static void deleteQuota(Id quotaId) {
        QuotaCategoryService.deleteQuota(quotaId);
    }
}