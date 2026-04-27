public with sharing class MasterDataController {
    public class ModuleSummary {
        @AuraEnabled public String key;
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public Integer recordCount;
        @AuraEnabled public Datetime lastUpdated;
    }

    @AuraEnabled(cacheable=true)
    public static List<ModuleSummary> getMasterDataSummary() {
        List<ModuleSummary> summaries = new List<ModuleSummary>();

        ModuleSummary quotaSummary = new ModuleSummary();
        quotaSummary.key = 'quotaCategories';
        quotaSummary.title = 'Quota & Categories';
        quotaSummary.description = 'Define category types and quota rules';
        quotaSummary.recordCount = (Integer) Database.countQuery('SELECT COUNT() FROM Category__c');
        quotaSummary.lastUpdated = getLastUpdated('Category__c');
        summaries.add(quotaSummary);

        ModuleSummary feeHeadSummary = new ModuleSummary();
        feeHeadSummary.key = 'feeHeads';
        feeHeadSummary.title = 'Fee Heads';
        feeHeadSummary.description = 'Configure fee components and categories';
        feeHeadSummary.recordCount = (Integer) Database.countQuery('SELECT COUNT() FROM Ken_Master_Fee_Head__c');
        feeHeadSummary.lastUpdated = getLastUpdated('Ken_Master_Fee_Head__c');
        summaries.add(feeHeadSummary);

        ModuleSummary feePlanSummary = new ModuleSummary();
        feePlanSummary.key = 'feePlans';
        feePlanSummary.title = 'Fee Plans';
        feePlanSummary.description = 'Create fee structures with category and quota mapping';
        feePlanSummary.recordCount = (Integer) Database.countQuery('SELECT COUNT() FROM Ken_Fee_Set__c');
        feePlanSummary.lastUpdated = getLastUpdated('Ken_Fee_Set__c');
        summaries.add(feePlanSummary);

        ModuleSummary programmeFeeSummary = new ModuleSummary();
        programmeFeeSummary.key = 'programmeFeePublishing';
        programmeFeeSummary.title = 'Fee Structures & Fee Types';
        programmeFeeSummary.description = 'Publish fee structures for programmes and batches';
        programmeFeeSummary.recordCount = (Integer) Database.countQuery('SELECT COUNT() FROM Ken_Fee_Type__c');
        Datetime feeTypeUpdated = getLastUpdated('Ken_Fee_Type__c');
        Datetime feeTypeLineUpdated = getLastUpdated('Ken_Fee_Type_Line_Item__c');
        programmeFeeSummary.lastUpdated = getLatest(feeTypeUpdated, feeTypeLineUpdated);
        summaries.add(programmeFeeSummary);

        ModuleSummary taxesSummary = new ModuleSummary();
        taxesSummary.key = 'taxes';
        taxesSummary.title = 'Taxes';
        taxesSummary.description = 'Configure tax rates and tax mappings';
        taxesSummary.recordCount = (Integer) Database.countQuery('SELECT COUNT() FROM Ken_Tax_Definition__c');
        taxesSummary.lastUpdated = getLastUpdated('Ken_Tax_Definition__c');
        summaries.add(taxesSummary);

        ModuleSummary installmentSummary = new ModuleSummary();
        installmentSummary.key = 'installmentPlans';
        installmentSummary.title = 'Installment Plans';
        installmentSummary.description = 'Configure installment schedules and split rules';
        installmentSummary.recordCount = (Integer) Database.countQuery('SELECT COUNT() FROM Payment_Schedule__c');
        Datetime installmentUpdated = getLastUpdated('Payment_Schedule__c');
        Datetime installmentLineUpdated = getLastUpdated('Payment_Schedule_Instalment__c');
        installmentSummary.lastUpdated = getLatest(installmentUpdated, installmentLineUpdated);
        summaries.add(installmentSummary);

        ModuleSummary scholarshipSummary = new ModuleSummary();
        scholarshipSummary.key = 'scholarships';
        scholarshipSummary.title = 'Scholarships';
        scholarshipSummary.description = 'Manage scholarship schemes and eligibility';
        scholarshipSummary.recordCount = (Integer) Database.countQuery('SELECT COUNT() FROM Ken_Scholarship_Discount__c');
        scholarshipSummary.lastUpdated = getLastUpdated('Ken_Scholarship_Discount__c');
        summaries.add(scholarshipSummary);

        ModuleSummary remittanceAccountSummary = new ModuleSummary();
        remittanceAccountSummary.key = 'remittanceAccounts';
        remittanceAccountSummary.title = 'Remittance Accounts';
        remittanceAccountSummary.description = 'Configure bank accounts for fee collection';
        remittanceAccountSummary.recordCount = (Integer) Database.countQuery('SELECT COUNT() FROM Ken_Bank_Account_Master__c');
        remittanceAccountSummary.lastUpdated = getLastUpdated('Ken_Bank_Account_Master__c');
        summaries.add(remittanceAccountSummary);

        ModuleSummary paymentGatewaySummary = new ModuleSummary();
        paymentGatewaySummary.key = 'paymentGateways';
        paymentGatewaySummary.title = 'Payment Gateways';
        paymentGatewaySummary.description = 'Manage online payment gateway integrations';
        paymentGatewaySummary.recordCount = (Integer) Database.countQuery('SELECT COUNT() FROM Payment_Gateway__c');
        paymentGatewaySummary.lastUpdated = getLastUpdated('Payment_Gateway__c');
        summaries.add(paymentGatewaySummary);

        return summaries;
    }

    private static Datetime getLastUpdated(String objectApiName) {
        String queryText = 'SELECT LastModifiedDate FROM ' + objectApiName + ' ORDER BY LastModifiedDate DESC LIMIT 1';
        List<SObject> rows = Database.query(queryText);
        if (rows.isEmpty()) {
            return null;
        }
        return (Datetime) rows[0].get('LastModifiedDate');
    }

    private static Datetime getLatest(Datetime firstValue, Datetime secondValue) {
        if (firstValue == null) {
            return secondValue;
        }
        if (secondValue == null) {
            return firstValue;
        }
        return firstValue.getTime() >= secondValue.getTime() ? firstValue : secondValue;
    }
}