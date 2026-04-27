public with sharing class PaymentScheduleInstallmentService {

    public static void createInstallments(List<Payment_Schedule__c> newSchedules) {
        if (newSchedules == null || newSchedules.isEmpty()) {
            return;
        }

        List<Payment_Schedule_Instalment__c> installmentsToInsert = new List<Payment_Schedule_Instalment__c>();

        for (Payment_Schedule__c scheduleRecord : newSchedules) {
            Integer scheduledPaymentsCount = scheduleRecord.Number_of_Scheduled_Payments__c == null
                ? 0
                : Integer.valueOf(scheduleRecord.Number_of_Scheduled_Payments__c);

            if (scheduledPaymentsCount <= 0) {
                continue;
            }

            // Base percent per installment (2 decimals). Adjust last row so total = 100.00 exactly.
            Decimal basePercent = (Decimal.valueOf(100) / Decimal.valueOf(scheduledPaymentsCount)).setScale(2);
            Decimal runningTotal = 0;

            for (Integer installmentIndex = 1; installmentIndex <= scheduledPaymentsCount; installmentIndex++) {
                Decimal installmentPercent = basePercent;

                Boolean isLast = (installmentIndex == scheduledPaymentsCount);
                if (isLast) {
                    installmentPercent = (Decimal.valueOf(100) - runningTotal).setScale(2);
                }

                Payment_Schedule_Instalment__c installmentRecord = new Payment_Schedule_Instalment__c();
                installmentRecord.Payment_Schedule__c = scheduleRecord.Id;
                installmentRecord.Collection_Order__c = installmentIndex;

                installmentRecord.Fee_Collection_Start_Date__c = scheduleRecord.Fee_Collection_Start_Date__c;
                installmentRecord.Fee_Collection_End_Date__c = scheduleRecord.Fee_Collection_End_Date__c;

                installmentRecord.Fee_Collection_Percentage__c = installmentPercent;

                installmentsToInsert.add(installmentRecord);

                runningTotal += installmentPercent;
            }
        }

        if (!installmentsToInsert.isEmpty()) {
            insert installmentsToInsert;
        }
    }
}