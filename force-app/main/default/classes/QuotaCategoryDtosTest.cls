@IsTest
private class QuotaCategoryDtosTest {
    @IsTest
    static void dtoClasses_canBeInstantiated() {
        QuotaCategoryDtos.CategoryRow category = new QuotaCategoryDtos.CategoryRow();
        category.categoryName = 'Test Category';

        QuotaCategoryDtos.QuotaRow quota = new QuotaCategoryDtos.QuotaRow();
        quota.quotaName = 'Test Quota';

        QuotaCategoryDtos.SaveCategoryRequest saveCategoryRequest = new QuotaCategoryDtos.SaveCategoryRequest();
        saveCategoryRequest.categoryName = 'Test Category';

        QuotaCategoryDtos.SaveQuotaRequest saveQuotaRequest = new QuotaCategoryDtos.SaveQuotaRequest();
        saveQuotaRequest.quotaName = 'Test Quota';

        QuotaCategoryDtos.CategoryBuilderData builderData = new QuotaCategoryDtos.CategoryBuilderData();
        builderData.categoryTypeOptions = new List<String>();
        builderData.currencyOptions = new List<QuotaCategoryDtos.CurrencyOption>();

        QuotaCategoryDtos.CurrencyOption currencyOption = new QuotaCategoryDtos.CurrencyOption();
        currencyOption.value = 'INR';
        currencyOption.label = 'INR';

        System.assertEquals('Test Category', category.categoryName);
        System.assertEquals('Test Quota', quota.quotaName);
        System.assertNotEquals(null, builderData.categoryTypeOptions);
    }
}