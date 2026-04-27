@IsTest
private class QuotaCategoryServiceTest {
    private static String pickValue(Schema.DescribeFieldResult dfr) {
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe != null && pe.isActive()) {
                return pe.getValue();
            }
        }
        return null;
    }

    private static Id createFeeSetForQuotaCategoryUsage() {
        Ken_Fee_Set__c feeSet = new Ken_Fee_Set__c();
        String feeStatus = pickValue(Ken_Fee_Set__c.Status__c.getDescribe());
        if (!String.isBlank(feeStatus)) {
            feeSet.Status__c = feeStatus;
        }
        String currencyPolicy = pickValue(Ken_Fee_Set__c.Currency_Policy__c.getDescribe());
        if (!String.isBlank(currencyPolicy)) {
            feeSet.Currency_Policy__c = currencyPolicy;
        }
        insert feeSet;
        return feeSet.Id;
    }

    @IsTest
    static void readApis_returnWithoutError() {
        QuotaCategoryDtos.SaveCategoryRequest categoryRequest = new QuotaCategoryDtos.SaveCategoryRequest();
        categoryRequest.categoryName = 'SvcCat_' + String.valueOf(DateTime.now().getTime());
        categoryRequest.categoryType = pickValue(Category__c.Category_Type__c.getDescribe());
        categoryRequest.currencyCode = UserInfo.getDefaultCurrency();
        categoryRequest.isActive = true;
        Id categoryId = QuotaCategoryService.saveCategory(categoryRequest);

        QuotaCategoryDtos.SaveQuotaRequest quotaRequest = new QuotaCategoryDtos.SaveQuotaRequest();
        quotaRequest.categoryId = categoryId;
        quotaRequest.quotaName = 'SvcQuota_' + String.valueOf(DateTime.now().getTime());
        quotaRequest.code = 'SV' + String.valueOf(Math.mod(DateTime.now().getTime(), 999999));
        quotaRequest.reservationPercent = 20;
        quotaRequest.priorityOrder = 1;
        quotaRequest.isActive = true;
        Id quotaId = QuotaCategoryService.saveQuota(quotaRequest);

        Test.startTest();
        List<String> typeOptions = QuotaCategoryService.getCategoryTypeOptions();
        QuotaCategoryDtos.CategoryBuilderData builderData = QuotaCategoryService.getCategoryBuilderData(categoryId);
        List<QuotaCategoryDtos.CategoryRow> categories = QuotaCategoryService.getCategoriesWithQuotas();
        QuotaCategoryDtos.CategoryRow singleCategory = QuotaCategoryService.getCategoryWithQuotas(categoryId);
        Test.stopTest();

        System.assertNotEquals(null, typeOptions);
        System.assertNotEquals(null, builderData);
        System.assertNotEquals(null, categories);
        System.assertNotEquals(null, singleCategory);
        System.assertNotEquals(null, quotaId);
    }

    @IsTest
    static void writeApis_validateInputs() {
        try {
            QuotaCategoryService.saveCategory(null);
            System.assert(false, 'Expected invalid request exception.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        QuotaCategoryDtos.SaveCategoryRequest categoryRequest = new QuotaCategoryDtos.SaveCategoryRequest();
        categoryRequest.categoryName = ' ';
        try {
            QuotaCategoryService.saveCategory(categoryRequest);
            System.assert(false, 'Expected category name validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            QuotaCategoryService.saveQuota(null);
            System.assert(false, 'Expected invalid request exception.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        QuotaCategoryDtos.SaveQuotaRequest quotaRequest = new QuotaCategoryDtos.SaveQuotaRequest();
        quotaRequest.categoryId = null;
        quotaRequest.quotaName = 'Quota';
        quotaRequest.code = 'CODE';
        try {
            QuotaCategoryService.saveQuota(quotaRequest);
            System.assert(false, 'Expected category validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            QuotaCategoryService.deleteCategory(null);
            System.assert(false, 'Expected category required validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            QuotaCategoryService.deleteQuota(null);
            System.assert(false, 'Expected quota required validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void writeApis_successUpdateAndDelete() {
        QuotaCategoryDtos.SaveCategoryRequest categoryRequest = new QuotaCategoryDtos.SaveCategoryRequest();
        categoryRequest.categoryName = 'SvcCatUpd_' + String.valueOf(DateTime.now().getTime());
        categoryRequest.categoryType = pickValue(Category__c.Category_Type__c.getDescribe());
        categoryRequest.currencyCode = UserInfo.getDefaultCurrency();
        categoryRequest.isActive = true;
        Id categoryId = QuotaCategoryService.saveCategory(categoryRequest);

        categoryRequest.categoryId = categoryId;
        categoryRequest.categoryName = categoryRequest.categoryName + '_U';
        Id updatedCategoryId = QuotaCategoryService.saveCategory(categoryRequest);
        System.assertEquals(categoryId, updatedCategoryId);

        QuotaCategoryDtos.SaveQuotaRequest quotaRequest = new QuotaCategoryDtos.SaveQuotaRequest();
        quotaRequest.categoryId = categoryId;
        quotaRequest.quotaName = 'SvcQuotaUpd_' + String.valueOf(DateTime.now().getTime());
        quotaRequest.code = 'SU' + String.valueOf(Math.mod(DateTime.now().getTime(), 999999));
        quotaRequest.reservationPercent = 30;
        quotaRequest.priorityOrder = 2;
        quotaRequest.isActive = true;
        Id quotaId = QuotaCategoryService.saveQuota(quotaRequest);

        quotaRequest.quotaId = quotaId;
        quotaRequest.reservationPercent = 40;
        Id updatedQuotaId = QuotaCategoryService.saveQuota(quotaRequest);
        System.assertEquals(quotaId, updatedQuotaId);

        QuotaCategoryService.deleteQuota(quotaId);
        QuotaCategoryService.deleteCategory(categoryId);

        Integer categoryCount = [SELECT Count() FROM Category__c WHERE Id = :categoryId];
        System.assertEquals(0, categoryCount);
    }

    @IsTest
    static void saveQuota_throwsFriendlyErrorForDuplicateCode() {
        QuotaCategoryDtos.SaveCategoryRequest categoryRequest = new QuotaCategoryDtos.SaveCategoryRequest();
        categoryRequest.categoryName = 'SvcCatDup_' + String.valueOf(DateTime.now().getTime());
        categoryRequest.categoryType = pickValue(Category__c.Category_Type__c.getDescribe());
        categoryRequest.currencyCode = UserInfo.getDefaultCurrency();
        categoryRequest.isActive = true;
        Id categoryId = QuotaCategoryService.saveCategory(categoryRequest);

        QuotaCategoryDtos.SaveQuotaRequest firstQuotaRequest = new QuotaCategoryDtos.SaveQuotaRequest();
        firstQuotaRequest.categoryId = categoryId;
        firstQuotaRequest.quotaName = 'SvcQuotaDupA_' + String.valueOf(DateTime.now().getTime());
        firstQuotaRequest.code = 'DUP' + String.valueOf(Math.mod(DateTime.now().getTime(), 999999));
        firstQuotaRequest.isActive = true;
        QuotaCategoryService.saveQuota(firstQuotaRequest);

        QuotaCategoryDtos.SaveQuotaRequest duplicateQuotaRequest = new QuotaCategoryDtos.SaveQuotaRequest();
        duplicateQuotaRequest.categoryId = categoryId;
        duplicateQuotaRequest.quotaName = 'SvcQuotaDupB_' + String.valueOf(DateTime.now().getTime());
        duplicateQuotaRequest.code = firstQuotaRequest.code.toLowerCase();
        duplicateQuotaRequest.isActive = true;

        try {
            QuotaCategoryService.saveQuota(duplicateQuotaRequest);
            System.assert(false, 'Expected duplicate code validation.');
        } catch (AuraHandledException ex) {
            System.assertEquals('Quota code already exists. Enter a unique code.', ex.getMessage());
        }
    }

    @IsTest
    static void deleteApis_blockWhenCategoryOrQuotaUsedInFeePlan() {
        QuotaCategoryDtos.SaveCategoryRequest categoryRequest = new QuotaCategoryDtos.SaveCategoryRequest();
        categoryRequest.categoryName = 'SvcCatUsed_' + String.valueOf(DateTime.now().getTime());
        categoryRequest.categoryType = pickValue(Category__c.Category_Type__c.getDescribe());
        categoryRequest.currencyCode = UserInfo.getDefaultCurrency();
        categoryRequest.isActive = true;
        Id categoryId = QuotaCategoryService.saveCategory(categoryRequest);

        QuotaCategoryDtos.SaveQuotaRequest quotaRequest = new QuotaCategoryDtos.SaveQuotaRequest();
        quotaRequest.categoryId = categoryId;
        quotaRequest.quotaName = 'SvcQuotaUsed_' + String.valueOf(DateTime.now().getTime());
        quotaRequest.code = 'SX' + String.valueOf(Math.mod(DateTime.now().getTime(), 999999));
        quotaRequest.reservationPercent = 10;
        quotaRequest.priorityOrder = 1;
        quotaRequest.isActive = true;
        Id quotaId = QuotaCategoryService.saveQuota(quotaRequest);

        Ken_Fee_Set_Line_Item__c feeSetLine = new Ken_Fee_Set_Line_Item__c(
            Ken_Fee_Set__c = createFeeSetForQuotaCategoryUsage(),
            Category__c = categoryId,
            Quota__c = quotaId
        );
        insert feeSetLine;

        try {
            QuotaCategoryService.deleteQuota(quotaId);
            System.assert(false, 'Expected quota in-use validation.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Cannot delete quota'));
        }

        try {
            QuotaCategoryService.deleteCategory(categoryId);
            System.assert(false, 'Expected category in-use validation.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Cannot delete category'));
        }
    }
}