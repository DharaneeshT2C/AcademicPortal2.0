public with sharing class ScholarshipTransactionsController {
    public class ScholarshipTransactionRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String studentName;
        @AuraEnabled public String studentId;
        @AuraEnabled public String programme;
        @AuraEnabled public String scholarshipName;
        @AuraEnabled public String scholarshipType;
        @AuraEnabled public Decimal amountDeducted;
        @AuraEnabled public Datetime appliedDate;
        @AuraEnabled public String status;
    }

    public class ScholarshipTransactionsDashboardData {
        @AuraEnabled public Integer activeScholarshipDeductions;
        @AuraEnabled public Decimal totalDeductionAmount;
        @AuraEnabled public Integer studentsImpacted;
        @AuraEnabled public Integer recentAdjustments;
        @AuraEnabled public List<ScholarshipTransactionRow> rows;
    }

    @AuraEnabled(cacheable=true)
    public static ScholarshipTransactionsDashboardData getScholarshipTransactionsDashboard() {
        ScholarshipTransactionsDashboardData data = new ScholarshipTransactionsDashboardData();
        data.activeScholarshipDeductions = 0;
        data.totalDeductionAmount = 0;
        data.studentsImpacted = 0;
        data.recentAdjustments = 0;
        data.rows = new List<ScholarshipTransactionRow>();

        Map<String, Schema.SObjectField> paymentTransactionFieldMap =
            Payment_Transaction__c.SObjectType.getDescribe().fields.getMap();
        if (!paymentTransactionFieldMap.containsKey('Transaction_Type__c')) {
            throw new AuraHandledException(
                'Payment Transaction field Transaction_Type__c is not available.'
            );
        }

        String transactionQuery =
            'SELECT Id, Name, Amount__c, Payment_Status__c, CreatedDate, '
            + 'Fee_Assignment__c, '
            + 'Fee_Assignment__r.Application__r.ContactId, '
            + 'Fee_Assignment__r.Application__r.Contact.Name, '
            + 'Fee_Assignment__r.Application__r.Learning_Program_Plan__r.Name, '
            + 'Scholarship_Discount__c, Scholarship_Discount__r.Name, Scholarship_Discount__r.Type__c '
            + 'FROM Payment_Transaction__c '
            + 'WHERE Transaction_Type__c = \'Scholarship\' '
            + 'ORDER BY CreatedDate DESC '
            + 'LIMIT 1000';

        List<Payment_Transaction__c> transactions =
            (List<Payment_Transaction__c>) Database.query(transactionQuery);

        Set<Id> transactionIds = new Set<Id>();
        for (Payment_Transaction__c transactionRecord : transactions) {
            transactionIds.add(transactionRecord.Id);
        }

        Map<Id, List<Payment_Transaction_Line_Item__c>> lineItemsByTransactionId =
            new Map<Id, List<Payment_Transaction_Line_Item__c>>();
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

        Set<String> impactedStudents = new Set<String>();
        Datetime recentThreshold = System.now().addDays(-7);

        for (Payment_Transaction__c transactionRecord : transactions) {
            List<Payment_Transaction_Line_Item__c> lineItems =
                lineItemsByTransactionId.get(transactionRecord.Id);
            Payment_Transaction_Line_Item__c primaryLineItem = (lineItems != null && !lineItems.isEmpty())
                ? lineItems[0]
                : null;

            ScholarshipTransactionRow row = new ScholarshipTransactionRow();
            row.id = transactionRecord.Id;
            row.studentName = resolveStudentName(transactionRecord, primaryLineItem);
            row.studentId = resolveStudentId(transactionRecord, primaryLineItem);
            row.programme = resolveProgramme(transactionRecord, primaryLineItem);
            row.scholarshipName = transactionRecord.Scholarship_Discount__r == null
                ? '--'
                : transactionRecord.Scholarship_Discount__r.Name;
            row.scholarshipType = transactionRecord.Scholarship_Discount__r == null
                ? '--'
                : transactionRecord.Scholarship_Discount__r.Type__c;
            row.amountDeducted = resolveAmountValue(transactionRecord, lineItems);
            row.appliedDate = transactionRecord.CreatedDate;
            row.status = normalizeScholarshipStatus(transactionRecord.Payment_Status__c);
            data.rows.add(row);

            if (row.amountDeducted != null) {
                data.totalDeductionAmount += row.amountDeducted;
            }
            if (row.status == 'Active') {
                data.activeScholarshipDeductions++;
            }
            if (row.appliedDate != null && row.appliedDate >= recentThreshold) {
                data.recentAdjustments++;
            }

            String studentKey = row.studentId;
            if (String.isBlank(studentKey) || studentKey == '--') {
                studentKey = row.studentName;
            }
            if (!String.isBlank(studentKey) && studentKey != '--') {
                impactedStudents.add(studentKey);
            }
        }

        data.studentsImpacted = impactedStudents.size();
        return data;
    }

    private static Decimal resolveAmountValue(
        Payment_Transaction__c transactionRecord,
        List<Payment_Transaction_Line_Item__c> lineItems
    ) {
        if (transactionRecord != null && transactionRecord.Amount__c != null) {
            return transactionRecord.Amount__c;
        }
        if (lineItems == null || lineItems.isEmpty()) {
            return null;
        }

        Decimal total = 0;
        Boolean hasAmount = false;
        for (Payment_Transaction_Line_Item__c lineItem : lineItems) {
            if (lineItem.Amount__c != null) {
                hasAmount = true;
                total += lineItem.Amount__c;
            }
        }
        return hasAmount ? total : null;
    }

    private static String resolveStudentName(
        Payment_Transaction__c transactionRecord,
        Payment_Transaction_Line_Item__c primaryLineItem
    ) {
        String fromTransaction = transactionRecord.Fee_Assignment__r == null
            || transactionRecord.Fee_Assignment__r.Application__r == null
            || transactionRecord.Fee_Assignment__r.Application__r.Contact == null
            ? null
            : transactionRecord.Fee_Assignment__r.Application__r.Contact.Name;
        if (!String.isBlank(fromTransaction)) {
            return fromTransaction;
        }

        String fromLineItem = primaryLineItem == null
            || primaryLineItem.Fee_Assignment__r == null
            || primaryLineItem.Fee_Assignment__r.Application__r == null
            || primaryLineItem.Fee_Assignment__r.Application__r.Contact == null
            ? null
            : primaryLineItem.Fee_Assignment__r.Application__r.Contact.Name;
        return String.isBlank(fromLineItem) ? '--' : fromLineItem;
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
        return contactIdFromLineItem == null ? '--' : String.valueOf(contactIdFromLineItem);
    }

    private static String resolveProgramme(
        Payment_Transaction__c transactionRecord,
        Payment_Transaction_Line_Item__c primaryLineItem
    ) {
        String fromTransaction = transactionRecord.Fee_Assignment__r == null
            || transactionRecord.Fee_Assignment__r.Application__r == null
            || transactionRecord.Fee_Assignment__r.Application__r.Learning_Program_Plan__r == null
            ? null
            : transactionRecord.Fee_Assignment__r.Application__r.Learning_Program_Plan__r.Name;
        if (!String.isBlank(fromTransaction)) {
            return fromTransaction;
        }

        String fromLineItem = primaryLineItem == null
            || primaryLineItem.Fee_Assignment__r == null
            || primaryLineItem.Fee_Assignment__r.Application__r == null
            || primaryLineItem.Fee_Assignment__r.Application__r.Learning_Program_Plan__r == null
            ? null
            : primaryLineItem.Fee_Assignment__r.Application__r.Learning_Program_Plan__r.Name;
        return String.isBlank(fromLineItem) ? '--' : fromLineItem;
    }

    private static String normalizeScholarshipStatus(String paymentStatusValue) {
        String normalized = String.isBlank(paymentStatusValue)
            ? ''
            : paymentStatusValue.trim().toLowerCase();

        if (
            normalized.contains('success')
            || normalized.contains('paid')
            || normalized.contains('complete')
            || normalized.contains('cleared')
            || normalized.contains('active')
        ) {
            return 'Active';
        }

        if (
            normalized.contains('fail')
            || normalized.contains('reject')
            || normalized.contains('error')
            || normalized.contains('cancel')
            || normalized.contains('expire')
            || normalized.contains('reverse')
        ) {
            return 'Expired';
        }

        return 'Pending';
    }
}