public with sharing class StudentTransactionsController {
    public class StudentTransactionRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String transactionId;
        @AuraEnabled public String studentName;
        @AuraEnabled public String studentId;
        @AuraEnabled public String programme;
        @AuraEnabled public String paymentMode;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime paymentDate;
    }

    public class PaymentModeDistributionRow {
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;
        @AuraEnabled public Integer percentage;
    }

    public class StudentTransactionsDashboardData {
        @AuraEnabled public Integer totalTransactionsToday;
        @AuraEnabled public Decimal totalCollectionToday;
        @AuraEnabled public Integer successfulPaymentsToday;
        @AuraEnabled public Integer failedOrPendingPaymentsToday;
        @AuraEnabled public List<PaymentModeDistributionRow> paymentModes;
        @AuraEnabled public List<StudentTransactionRow> rows;
    }

    @AuraEnabled(cacheable=true)
    public static StudentTransactionsDashboardData getStudentTransactionsDashboard() {
        StudentTransactionsDashboardData data = new StudentTransactionsDashboardData();
        data.totalTransactionsToday = 0;
        data.totalCollectionToday = 0;
        data.successfulPaymentsToday = 0;
        data.failedOrPendingPaymentsToday = 0;
        data.paymentModes = new List<PaymentModeDistributionRow>();
        data.rows = new List<StudentTransactionRow>();

        List<Payment_Transaction__c> transactions = [
            SELECT
                Id,
                Name,
                Transaction_Id__c,
                Account__c,
                Account__r.Name,
                Fee_Assignment__c,
                Fee_Assignment__r.Application__r.ContactId,
                Fee_Assignment__r.Application__r.Contact.Name,
                Fee_Assignment__r.Application__r.Learning_Program_Plan__r.Name,
                Payment_Mode__c,
                Amount__c,
                Payment_Status__c,
                Transaction_Success_Date__c,
                CreatedDate
            FROM Payment_Transaction__c WHERE Transaction_type__c = 'Payment'
            ORDER BY CreatedDate DESC
            LIMIT 1000
        ];

        Set<Id> transactionIds = new Set<Id>();
        for (Payment_Transaction__c transactionRecord : transactions) {
            transactionIds.add(transactionRecord.Id);
        }

        Map<Id, List<Payment_Transaction_Line_Item__c>> lineItemsByTransactionId = new Map<Id, List<Payment_Transaction_Line_Item__c>>();
        if (!transactionIds.isEmpty()) {
            for (Payment_Transaction_Line_Item__c lineItem : [
                SELECT
                    Id,
                    Payment_Transaction__c,
                    Fee_Assignment__c,
                    Amount__c,
                    Fee_Assignment__r.Application__r.ContactId,
                    Fee_Assignment__r.Application__r.Contact.Name,
                    Fee_Assignment__r.Application__r.Learning_Program_Plan__r.Name
                FROM Payment_Transaction_Line_Item__c
                WHERE Payment_Transaction__c IN :transactionIds
                ORDER BY CreatedDate DESC
                LIMIT 5000
            ]) {
                if (!lineItemsByTransactionId.containsKey(lineItem.Payment_Transaction__c)) {
                    lineItemsByTransactionId.put(
                        lineItem.Payment_Transaction__c,
                        new List<Payment_Transaction_Line_Item__c>()
                    );
                }
                lineItemsByTransactionId.get(lineItem.Payment_Transaction__c).add(lineItem);
            }
        }

        Date todayDate = Date.today();
        Integer gatewayCount = 0;
        Integer bankTransferCount = 0;
        Integer cashCount = 0;
        Integer chequeCount = 0;

        for (Payment_Transaction__c transactionRecord : transactions) {
            List<Payment_Transaction_Line_Item__c> transactionLineItems = lineItemsByTransactionId.get(
                transactionRecord.Id
            );
            Payment_Transaction_Line_Item__c primaryLineItem = (
                transactionLineItems != null && !transactionLineItems.isEmpty()
            )
                ? transactionLineItems[0]
                : null;

            String normalizedStatus = normalizeStatus(transactionRecord.Payment_Status__c);
            Datetime paymentDate = transactionRecord.Transaction_Success_Date__c == null
                ? transactionRecord.CreatedDate
                : transactionRecord.Transaction_Success_Date__c;
            Decimal amountValue = resolveAmountValue(transactionRecord, transactionLineItems);

            StudentTransactionRow row = new StudentTransactionRow();
            row.id = transactionRecord.Id;
            row.transactionId = String.isBlank(transactionRecord.Transaction_Id__c)
                ? transactionRecord.Name
                : transactionRecord.Transaction_Id__c;
            row.studentName = resolveStudentName(transactionRecord, primaryLineItem);
            row.studentId = resolveStudentId(transactionRecord, primaryLineItem);
            row.programme = resolveProgramme(transactionRecord, primaryLineItem);
            row.paymentMode = String.isBlank(transactionRecord.Payment_Mode__c)
                ? '--'
                : transactionRecord.Payment_Mode__c;
            row.amount = amountValue;
            row.status = normalizedStatus;
            row.paymentDate = paymentDate;
            data.rows.add(row);

            if (paymentDate != null && paymentDate.date() == todayDate) {
                data.totalTransactionsToday++;
                if (normalizedStatus == 'Success') {
                    data.successfulPaymentsToday++;
                    if (amountValue != null) {
                        data.totalCollectionToday += amountValue;
                    }
                } else {
                    data.failedOrPendingPaymentsToday++;
                }
            }

            String paymentModeBucket = mapPaymentMode(row.paymentMode);
            if (paymentModeBucket == 'Gateway') {
                gatewayCount++;
            } else if (paymentModeBucket == 'Bank Transfer') {
                bankTransferCount++;
            } else if (paymentModeBucket == 'Cash') {
                cashCount++;
            } else if (paymentModeBucket == 'Cheque') {
                chequeCount++;
            }
        }

        Integer totalTransactions = data.rows.size();
        data.paymentModes.add(buildPaymentModeRow('Gateway', gatewayCount, totalTransactions));
        data.paymentModes.add(buildPaymentModeRow('Bank Transfer', bankTransferCount, totalTransactions));
        data.paymentModes.add(buildPaymentModeRow('Cash', cashCount, totalTransactions));
        data.paymentModes.add(buildPaymentModeRow('Cheque', chequeCount, totalTransactions));

        return data;
    }

    private static Decimal resolveAmountValue(
        Payment_Transaction__c transactionRecord,
        List<Payment_Transaction_Line_Item__c> transactionLineItems
    ) {
        if (transactionRecord != null && transactionRecord.Amount__c != null) {
            return transactionRecord.Amount__c;
        }
        if (transactionLineItems == null || transactionLineItems.isEmpty()) {
            return null;
        }

        Decimal lineItemAmountTotal = 0;
        Boolean hasAmount = false;
        for (Payment_Transaction_Line_Item__c lineItem : transactionLineItems) {
            if (lineItem.Amount__c != null) {
                hasAmount = true;
                lineItemAmountTotal += lineItem.Amount__c;
            }
        }
        return hasAmount ? lineItemAmountTotal : null;
    }

    private static String resolveStudentName(
        Payment_Transaction__c transactionRecord,
        Payment_Transaction_Line_Item__c primaryLineItem
    ) {
        String fromTransactionFeeAssignment = transactionRecord.Fee_Assignment__r == null
            || transactionRecord.Fee_Assignment__r.Application__r == null
            || transactionRecord.Fee_Assignment__r.Application__r.Contact == null
            ? null
            : transactionRecord.Fee_Assignment__r.Application__r.Contact.Name;
        if (!String.isBlank(fromTransactionFeeAssignment)) {
            return fromTransactionFeeAssignment;
        }

        String fromLineItemFeeAssignment = primaryLineItem == null
            || primaryLineItem.Fee_Assignment__r == null
            || primaryLineItem.Fee_Assignment__r.Application__r == null
            || primaryLineItem.Fee_Assignment__r.Application__r.Contact == null
            ? null
            : primaryLineItem.Fee_Assignment__r.Application__r.Contact.Name;
        if (!String.isBlank(fromLineItemFeeAssignment)) {
            return fromLineItemFeeAssignment;
        }

        String accountName = transactionRecord.Account__r == null
            ? null
            : transactionRecord.Account__r.Name;
        return String.isBlank(accountName) ? '--' : accountName;
    }

    private static String resolveStudentId(
        Payment_Transaction__c transactionRecord,
        Payment_Transaction_Line_Item__c primaryLineItem
    ) {
        Id contactIdFromTransaction = transactionRecord.Fee_Assignment__r == null
            || transactionRecord.Fee_Assignment__r.Application__r == null
            ? null
            : transactionRecord.Fee_Assignment__r.Application__r.ContactId;
        if (contactIdFromTransaction != null) {
            return String.valueOf(contactIdFromTransaction);
        }

        Id contactIdFromLineItem = primaryLineItem == null
            || primaryLineItem.Fee_Assignment__r == null
            || primaryLineItem.Fee_Assignment__r.Application__r == null
            ? null
            : primaryLineItem.Fee_Assignment__r.Application__r.ContactId;
        if (contactIdFromLineItem != null) {
            return String.valueOf(contactIdFromLineItem);
        }

        return transactionRecord.Account__c == null ? '--' : String.valueOf(transactionRecord.Account__c);
    }

    private static String resolveProgramme(
        Payment_Transaction__c transactionRecord,
        Payment_Transaction_Line_Item__c primaryLineItem
    ) {
        String fromTransactionFeeAssignment = transactionRecord.Fee_Assignment__r == null
            || transactionRecord.Fee_Assignment__r.Application__r == null
            || transactionRecord.Fee_Assignment__r.Application__r.Learning_Program_Plan__r == null
            ? null
            : transactionRecord.Fee_Assignment__r.Application__r.Learning_Program_Plan__r.Name;
        if (!String.isBlank(fromTransactionFeeAssignment)) {
            return fromTransactionFeeAssignment;
        }

        String fromLineItemFeeAssignment = primaryLineItem == null
            || primaryLineItem.Fee_Assignment__r == null
            || primaryLineItem.Fee_Assignment__r.Application__r == null
            || primaryLineItem.Fee_Assignment__r.Application__r.Learning_Program_Plan__r == null
            ? null
            : primaryLineItem.Fee_Assignment__r.Application__r.Learning_Program_Plan__r.Name;

        return String.isBlank(fromLineItemFeeAssignment) ? '--' : fromLineItemFeeAssignment;
    }

    private static String normalizeStatus(String paymentStatusValue) {
        String normalizedValue = String.isBlank(paymentStatusValue)
            ? ''
            : paymentStatusValue.trim().toLowerCase();

        if (
            normalizedValue.contains('success')
            || normalizedValue.contains('paid')
            || normalizedValue.contains('complete')
            || normalizedValue.contains('cleared')
        ) {
            return 'Success';
        }

        if (
            normalizedValue.contains('fail')
            || normalizedValue.contains('reject')
            || normalizedValue.contains('error')
            || normalizedValue.contains('cancel')
        ) {
            return 'Failed';
        }

        return 'Pending';
    }

    private static String mapPaymentMode(String paymentModeValue) {
        String normalizedValue = String.isBlank(paymentModeValue)
            ? ''
            : paymentModeValue.trim().toLowerCase();

        if (normalizedValue.contains('cash')) {
            return 'Cash';
        }
        if (normalizedValue.contains('cheque') || normalizedValue.contains('check')) {
            return 'Cheque';
        }
        if (
            normalizedValue.contains('bank')
            || normalizedValue.contains('neft')
            || normalizedValue.contains('rtgs')
            || normalizedValue.contains('imps')
            || normalizedValue.contains('transfer')
        ) {
            return 'Bank Transfer';
        }
        if (
            normalizedValue.contains('gateway')
            || normalizedValue.contains('upi')
            || normalizedValue.contains('card')
            || normalizedValue.contains('online')
            || normalizedValue.contains('ccavenue')
            || normalizedValue.contains('netbanking')
        ) {
            return 'Gateway';
        }

        return '';
    }

    private static PaymentModeDistributionRow buildPaymentModeRow(
        String label,
        Integer count,
        Integer totalTransactions
    ) {
        PaymentModeDistributionRow row = new PaymentModeDistributionRow();
        row.label = label;
        row.count = count;
        row.percentage = totalTransactions == 0
            ? 0
            : Integer.valueOf(
                (
                    Decimal.valueOf(count * 100)
                    / Decimal.valueOf(totalTransactions)
                ).setScale(0)
            );
        return row;
    }
}