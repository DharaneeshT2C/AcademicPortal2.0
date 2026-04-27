@IsTest
private class QuotaCategoryControllerTest {
    private static String pickValue(Schema.DescribeFieldResult dfr) {
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe != null && pe.isActive()) {
                return pe.getValue();
            }
        }
        return null;
    }

    @IsTest
    static void readApis_returnWithoutError() {
        Id categoryId = QuotaCategoryController.saveCategory(
            null,
            'CtlCat_' + String.valueOf(DateTime.now().getTime()),
            pickValue(Category__c.Category_Type__c.getDescribe()),
            UserInfo.getDefaultCurrency(),
            'Reg',
            true
        );
        QuotaCategoryController.saveQuota(
            null,
            categoryId,
            'CtlQuota_' + String.valueOf(DateTime.now().getTime()),
            'CT' + String.valueOf(Math.mod(DateTime.now().getTime(), 999999)),
            15,
            1,
            true
        );

        Test.startTest();
        List<QuotaCategoryDtos.CategoryRow> rows = QuotaCategoryController.getCategoriesWithQuotas();
        QuotaCategoryDtos.CategoryRow singleRow = QuotaCategoryController.getCategoryWithQuotas(categoryId);
        List<String> typeOptions = QuotaCategoryController.getCategoryTypeOptions();
        QuotaCategoryDtos.CategoryBuilderData builderData = QuotaCategoryController.getCategoryBuilderData(categoryId);
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertNotEquals(null, singleRow);
        System.assertNotEquals(null, typeOptions);
        System.assertNotEquals(null, builderData);
        System.assert(rows.size() > 0);
    }

    @IsTest
    static void writeApis_validateRequiredInputs() {
        try {
            QuotaCategoryController.saveCategory(null, ' ', null, null, null, true);
            System.assert(false, 'Expected category name validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            QuotaCategoryController.saveQuota(null, null, 'Quota', 'CODE', 10, 1, true);
            System.assert(false, 'Expected category id validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            QuotaCategoryController.deleteCategory(null);
            System.assert(false, 'Expected category id validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }

        try {
            QuotaCategoryController.deleteQuota(null);
            System.assert(false, 'Expected quota id validation.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void writeApis_successUpdateDelete() {
        Id categoryId = QuotaCategoryController.saveCategory(
            null,
            'CtlUpd_' + String.valueOf(DateTime.now().getTime()),
            pickValue(Category__c.Category_Type__c.getDescribe()),
            UserInfo.getDefaultCurrency(),
            'Reg',
            true
        );
        Id quotaId = QuotaCategoryController.saveQuota(
            null,
            categoryId,
            'CtlQuotaUpd_' + String.valueOf(DateTime.now().getTime()),
            'CU' + String.valueOf(Math.mod(DateTime.now().getTime(), 999999)),
            20,
            1,
            true
        );

        Id updatedCategoryId = QuotaCategoryController.saveCategory(
            categoryId,
            'CtlUpdRenamed_' + String.valueOf(DateTime.now().getTime()),
            pickValue(Category__c.Category_Type__c.getDescribe()),
            UserInfo.getDefaultCurrency(),
            'Reg2',
            true
        );
        System.assertEquals(categoryId, updatedCategoryId);

        Id updatedQuotaId = QuotaCategoryController.saveQuota(
            quotaId,
            categoryId,
            'CtlQuotaUpdRenamed_' + String.valueOf(DateTime.now().getTime()),
            'CV' + String.valueOf(Math.mod(DateTime.now().getTime(), 999999)),
            22,
            2,
            true
        );
        System.assertEquals(quotaId, updatedQuotaId);

        QuotaCategoryController.deleteQuota(quotaId);
        QuotaCategoryController.deleteCategory(categoryId);
        Integer countAfterDelete = [SELECT Count() FROM Category__c WHERE Id = :categoryId];
        System.assertEquals(0, countAfterDelete);
    }
}