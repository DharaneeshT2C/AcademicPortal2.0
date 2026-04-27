public with sharing class TaxesController {
    public class TaxRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal taxRate;
        @AuraEnabled public String parentTaxName;
        @AuraEnabled public Datetime lastModified;
    }

    @AuraEnabled(cacheable=true)
    public static List<TaxRow> getTaxes() {
        List<TaxRow> rows = new List<TaxRow>();

        for (Ken_Tax_Definition__c taxRecord : [
            SELECT Id,
                   Name,
                   Tax_Rate__c,
                   Parent_Tax__r.Name,
                   LastModifiedDate
            FROM Ken_Tax_Definition__c
            ORDER BY LastModifiedDate DESC
            LIMIT 500
        ]) {
            TaxRow row = new TaxRow();
            row.id = taxRecord.Id;
            row.name = taxRecord.Name;
            row.taxRate = taxRecord.Tax_Rate__c;
            row.parentTaxName = taxRecord.Parent_Tax__r == null ? '-' : taxRecord.Parent_Tax__r.Name;
            row.lastModified = taxRecord.LastModifiedDate;
            rows.add(row);
        }

        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<TaxRow> getTaxOptions() {
        List<TaxRow> rows = new List<TaxRow>();

        for (Ken_Tax_Definition__c taxRecord : [
            SELECT Id,
                   Name,
                   Tax_Rate__c,
                   LastModifiedDate
            FROM Ken_Tax_Definition__c
            ORDER BY Name ASC
            LIMIT 500
        ]) {
            TaxRow row = new TaxRow();
            row.id = taxRecord.Id;
            row.name = taxRecord.Name;
            row.taxRate = taxRecord.Tax_Rate__c;
            row.lastModified = taxRecord.LastModifiedDate;
            rows.add(row);
        }

        return rows;
    }

    @AuraEnabled
    public static Id saveTax(String taxName, Decimal taxRate, Id parentTaxId) {
        if (String.isBlank(taxName)) {
            throw new AuraHandledException('Tax Name is required.');
        }

        Ken_Tax_Definition__c recordToInsert = new Ken_Tax_Definition__c(
            Name = taxName.trim(),
            Tax_Rate__c = taxRate,
            Parent_Tax__c = parentTaxId
        );

        insert recordToInsert;
        return recordToInsert.Id;
    }
}