public with sharing class QuotaCategorySelector {

    public static List<Category__c> selectCategories() {
        List<String> fields = new List<String>{
            'Id',
            'Name',
            'Category_Type__c',
            'Regulatory_Source__c',
            'Active__c',
            'CreatedDate',
            'CreatedBy.Name',
            'LastModifiedDate'
        };
        if (hasCurrencyField()) {
            fields.add('CurrencyIsoCode');
        }
        String queryText =
            'SELECT ' + String.join(fields, ',') +
            ' FROM Category__c ORDER BY LastModifiedDate DESC';
        return (List<Category__c>) Database.query(queryText);
    }

    public static Category__c selectCategoryById(Id categoryId) {
        if (categoryId == null) {
            return null;
        }

        List<String> fields = new List<String>{
            'Id',
            'Name',
            'Category_Type__c',
            'Regulatory_Source__c',
            'Active__c',
            'CreatedDate',
            'CreatedBy.Name',
            'LastModifiedDate'
        };
        if (hasCurrencyField()) {
            fields.add('CurrencyIsoCode');
        }

        String queryText =
            'SELECT ' + String.join(fields, ',') +
            ' FROM Category__c WHERE Id = :categoryId LIMIT 1';

        List<Category__c> rows = Database.query(queryText);
        return rows.isEmpty() ? null : rows[0];
    }

    public static List<Quota__c> selectQuotasByCategoryIds(Set<Id> categoryIds) {
        if (categoryIds == null || categoryIds.isEmpty()) {
            return new List<Quota__c>();
        }

        return [
            SELECT Id, Category__c, Name, Code__c, Reservation_Percent__c, Priority_Order__c, Active__c, LastModifiedDate
            FROM Quota__c
            WHERE Category__c IN :categoryIds
            ORDER BY Priority_Order__c ASC, Name ASC
        ];
    }

    public static List<String> selectCategoryTypePicklistValues() {
        List<String> values = new List<String>();
        for (Schema.PicklistEntry entry : Category__c.Category_Type__c.getDescribe().getPicklistValues()) {
            if (entry != null && entry.isActive()) {
                values.add(entry.getValue());
            }
        }
        return values;
    }

    public static Boolean hasCurrencyField() {
        return Category__c.SObjectType.getDescribe().fields.getMap().containsKey('CurrencyIsoCode');
    }
}