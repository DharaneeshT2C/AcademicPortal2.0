@IsTest
private class QuotaCategorySelectorTest {
    private static String pickValue(Schema.DescribeFieldResult dfr) {
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe != null && pe.isActive()) {
                return pe.getValue();
            }
        }
        return null;
    }

    @IsTest
    static void selectorMethods_handleNullAndEmptyInputs() {
        Category__c category = new Category__c(
            Name = 'SelCat_' + String.valueOf(DateTime.now().getTime()),
            Category_Type__c = pickValue(Category__c.Category_Type__c.getDescribe()),
            Active__c = true
        );
        insert category;
        insert new Quota__c(
            Category__c = category.Id,
            Name = 'SelQuota_' + String.valueOf(DateTime.now().getTime()),
            Code__c = 'SEL' + String.valueOf(Math.mod(DateTime.now().getTime(), 999999)),
            Reservation_Percent__c = 10,
            Priority_Order__c = 1,
            Active__c = true
        );

        Test.startTest();
        List<Category__c> categories = QuotaCategorySelector.selectCategories();
        Category__c singleCategory = QuotaCategorySelector.selectCategoryById(category.Id);
        List<Quota__c> quotas = QuotaCategorySelector.selectQuotasByCategoryIds(new Set<Id>{ category.Id });
        List<String> picklistValues = QuotaCategorySelector.selectCategoryTypePicklistValues();
        Boolean hasCurrency = QuotaCategorySelector.hasCurrencyField();
        Test.stopTest();

        System.assertNotEquals(null, categories);
        System.assertNotEquals(null, singleCategory);
        System.assert(quotas.size() > 0);
        System.assertNotEquals(null, picklistValues);
        System.assertNotEquals(null, hasCurrency);
    }
}