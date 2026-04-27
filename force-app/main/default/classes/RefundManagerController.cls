public with sharing class RefundManagerController {
    
    @AuraEnabled(cacheable=true)
    public static RefundDashboardResponse getRefundDashboardData() {
        RefundDashboardResponse response = new RefundDashboardResponse();
        
        response.summary = new SummarySection();
        response.statusOverview = new List<StatusSummary>();
        response.transactions = new List<RefundTransactionRow>();
        
        Map<String, StatusSummary> statusMap = new Map<String, StatusSummary>();
        
        for (AggregateResult ar : [
            SELECT
                Status__c status,
                COUNT(Id) totalCount,
                SUM(Refund_Amount__c) totalAmount
            FROM Refund__c
            GROUP BY Status__c
        ]) {
            String status = (String) ar.get('status');
            Integer countVal = (Integer) ar.get('totalCount');
            Decimal amountVal = (Decimal) ar.get('totalAmount');
            
            StatusSummary ss = new StatusSummary();
            ss.status = status;
            ss.count = countVal != null ? countVal : 0;
            ss.amount = amountVal != null ? amountVal : 0;
            
            statusMap.put(status, ss);
            response.statusOverview.add(ss);
        }
        
        response.summary.refundRequestsToday = [
            SELECT COUNT()
            FROM Refund__c
            WHERE CreatedDate = TODAY
        ];
        
        response.summary.initiatedCount = statusMap.containsKey('Initiated')
            ? statusMap.get('Initiated').count
            : 0;
        
        response.summary.refundedCount = statusMap.containsKey('Refunded')
            ? statusMap.get('Refunded').count
            : 0;
        
        response.summary.rejectedCount = statusMap.containsKey('Rejected')
            ? statusMap.get('Rejected').count
            : 0;
        
        Decimal totalRefunded = 0;
        if (statusMap.containsKey('Refunded')) {
            totalRefunded += statusMap.get('Refunded').amount;
        }
        response.summary.totalRefundedAmount = totalRefunded;
        
        for (Refund__c r : [
            SELECT
                Id,
                Name,
                Account__c,
                Account__r.Name,
                Amount__c,
                Withdrawal_Amount__c,
                Refund_Amount__c,
                Status__c,
                Refund_Date__c,
                UTR_Number__c
            FROM Refund__c
            ORDER BY Refund_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 200
        ]) {
            RefundTransactionRow row = new RefundTransactionRow();
            row.recordId = r.Id;
            row.refundId = r.Name;
            row.studentName = r.Account__r != null ? r.Account__r.Name : null;
            row.accountId = r.Account__c ;
            row.amount = r.Amount__c;
            row.withdrawalAmount = r.Withdrawal_Amount__c;
            row.refundAmount = r.Refund_Amount__c;
            row.status = r.Status__c;
            row.refundDate = r.Refund_Date__c;
            row.utrNumber = r.UTR_Number__c;
            response.transactions.add(row);
        }
        
        return response;
    }
    
    @AuraEnabled
    public static void updateRefunds(List<Id> recordIds, String utrNumber, Date refundedDate) {
        if (recordIds == null || recordIds.isEmpty()) {
            throw new AuraHandledException('Please select at least one refund record.');
        }
        
        List<Refund__c> updates = new List<Refund__c>();
        
        for (Id recordId : recordIds) {
            Refund__c refundRecord = new Refund__c(
                Id = recordId,
                Status__c = 'Refunded',
                Refund_Date__c = refundedDate,
                UTR_Number__c = utrNumber
            );
            updates.add(refundRecord);
        }
        
        update updates;
    }
    
    public class RefundDashboardResponse {
        @AuraEnabled public SummarySection summary;
        @AuraEnabled public List<StatusSummary> statusOverview;
        @AuraEnabled public List<RefundTransactionRow> transactions;
    }
    
    public class SummarySection {
        @AuraEnabled public Integer refundRequestsToday;
        @AuraEnabled public Integer initiatedCount;
        @AuraEnabled public Integer refundedCount;
        @AuraEnabled public Integer rejectedCount;
        @AuraEnabled public Decimal totalRefundedAmount;
    }
    
    public class StatusSummary {
        @AuraEnabled public String status;
        @AuraEnabled public Integer count;
        @AuraEnabled public Decimal amount;
    }
    
    public class RefundTransactionRow {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String refundId;
        @AuraEnabled public String studentName;
        @AuraEnabled public String studentId;
        @AuraEnabled public Id accountId;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Decimal withdrawalAmount;
        @AuraEnabled public Decimal refundAmount;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime refundDate;
        @AuraEnabled public String utrNumber;
    }
}