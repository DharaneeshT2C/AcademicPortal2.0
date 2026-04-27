public with sharing class FeeAssignmentsController {
    public class FeeAssignmentRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String studentName;
        @AuraEnabled public String programme;
        @AuraEnabled public Decimal totalFee;
        @AuraEnabled public Decimal scholarshipApplied;
        @AuraEnabled public Decimal finalPayable;
        @AuraEnabled public String status;
        @AuraEnabled public String currencyIsoCode;
    }

    public class FeeAssignmentMetrics {
        @AuraEnabled public Integer totalFeeAssignments;
        @AuraEnabled public Integer activeAssignments;
        @AuraEnabled public Integer studentsWithScholarships;
        @AuraEnabled public Decimal outstandingBalance;
        @AuraEnabled public String outstandingCurrencyIsoCode;
    }

    public class FeeAssignmentsDashboardResponse {
        @AuraEnabled public List<FeeAssignmentRow> rows;
        @AuraEnabled public FeeAssignmentMetrics metrics;
    }

    @AuraEnabled(cacheable=true)
    public static FeeAssignmentsDashboardResponse getFeeAssignmentsDashboard() {
        FeeAssignmentsDashboardResponse response = new FeeAssignmentsDashboardResponse();
        response.rows = getFeeAssignmentRows();
        response.metrics = getFeeAssignmentMetrics();
        return response;
    }

    @AuraEnabled(cacheable=true)
    public static List<FeeAssignmentRow> getFeeAssignments() {
        return getFeeAssignmentRows();
    }

    private static List<FeeAssignmentRow> getFeeAssignmentRows() {
        List<FeeAssignmentRow> rows = new List<FeeAssignmentRow>();

        List<Fee_Assignment__c> assignments = [
            SELECT
                Id,
                Status__c,
                Scholarship_Discount_Amount__c,
                Fee_Amount_Payable_Formula__c,
                Total_Amount_Payable_Formula__c,
                CurrencyIsoCode,
                Application__r.Account.Name,
                Application__r.Contact.Name,
                Fee_Type__r.Learning_Program_Plan__r.LearningProgram.Name
            FROM Fee_Assignment__c
            ORDER BY LastModifiedDate DESC
            LIMIT 500
        ];

        for (Fee_Assignment__c assignment : assignments) {
            FeeAssignmentRow row = new FeeAssignmentRow();
            row.id = assignment.Id;
            row.studentName = resolveStudentName(assignment);
            row.programme = assignment.Fee_Type__r == null
                || assignment.Fee_Type__r.Learning_Program_Plan__r == null
                || assignment.Fee_Type__r.Learning_Program_Plan__r.LearningProgram == null
                ? null
                : assignment.Fee_Type__r.Learning_Program_Plan__r.LearningProgram.Name;
            row.totalFee = assignment.Fee_Amount_Payable_Formula__c;
            row.scholarshipApplied = assignment.Scholarship_Discount_Amount__c;
            row.finalPayable = assignment.Total_Amount_Payable_Formula__c;
            row.status = assignment.Status__c;
            row.currencyIsoCode = assignment.CurrencyIsoCode;
            rows.add(row);
        }

        return rows;
    }

    private static FeeAssignmentMetrics getFeeAssignmentMetrics() {
        FeeAssignmentMetrics metrics = new FeeAssignmentMetrics();

        metrics.totalFeeAssignments = [SELECT COUNT() FROM Fee_Assignment__c];
        metrics.activeAssignments = [SELECT COUNT() FROM Fee_Assignment__c WHERE Status__c = 'Active'];
        metrics.studentsWithScholarships = [SELECT COUNT() FROM Fee_Assignment__c WHERE Scholarship_Discount_Amount__c > 0];

        AggregateResult outstandingAggregate = [
            SELECT SUM(Remaining_Amount_Formula__c) totalOutstanding
            FROM Fee_Assignment__c
        ];
        metrics.outstandingBalance = (Decimal) outstandingAggregate.get('totalOutstanding');

        List<Fee_Assignment__c> currencyRows = [
            SELECT CurrencyIsoCode
            FROM Fee_Assignment__c
            WHERE CurrencyIsoCode != null
            LIMIT 1
        ];
        metrics.outstandingCurrencyIsoCode = currencyRows.isEmpty() ? 'INR' : currencyRows[0].CurrencyIsoCode;

        return metrics;
    }

    private static String resolveStudentName(Fee_Assignment__c assignment) {
        if (assignment == null || assignment.Application__r == null) {
            return null;
        }

        String accountName = assignment.Application__r.Account == null
            ? null
            : assignment.Application__r.Account.Name;
        if (!String.isBlank(accountName)) {
            return accountName;
        }

        String contactName = assignment.Application__r.Contact == null
            ? null
            : assignment.Application__r.Contact.Name;
        return String.isBlank(contactName) ? null : contactName;
    }
}