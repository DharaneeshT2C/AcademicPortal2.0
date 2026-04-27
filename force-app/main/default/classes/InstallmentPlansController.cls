public with sharing class InstallmentPlansController {
    private static final String ERROR_DUPLICATE_INSTALLMENT_CODE =
        'Duplicate installment code cannot be used. Enter a unique Installment Code.';
    private static final String ERROR_INSTALLMENT_PLAN_IN_USE =
        'Cannot edit or delete this installment plan because it is used in programme fee configurations.';

    public class InstallmentPlanRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String installmentCode;
        @AuraEnabled public String status;
        @AuraEnabled public Integer installmentCount;
        @AuraEnabled public Decimal installmentFeePercentage;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public Datetime lastModified;
        @AuraEnabled public Integer usedInProgrammeFees;
    }

    public class InstallmentInput {
        @AuraEnabled public Id lineId;
        @AuraEnabled public Integer order;
        @AuraEnabled public Decimal percentage;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Integer dueDays;
    }

    public class InstallmentPlanSaveRequest {
        @AuraEnabled public Id scheduleId;
        @AuraEnabled public String planName;
        @AuraEnabled public String installmentCode;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal installmentFeePercentage;
        @AuraEnabled public List<InstallmentInput> installments;
    }

    public class InstallmentPlanDetails {
        @AuraEnabled public Id id;
        @AuraEnabled public String planName;
        @AuraEnabled public String installmentCode;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal installmentFeePercentage;
        @AuraEnabled public Integer installmentCount;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public Datetime lastModified;
        @AuraEnabled public List<InstallmentInput> installments;
        @AuraEnabled public Integer usedInProgrammeFees;
        @AuraEnabled public Boolean isEditRestricted;
        @AuraEnabled public String editRestrictionMessage;
    }

    @AuraEnabled(cacheable=true)
    public static List<InstallmentPlanRow> getInstallmentPlans() {
        List<InstallmentPlanRow> rows = new List<InstallmentPlanRow>();

        List<Payment_Schedule__c> parentSchedules = [
            SELECT Id,
                   Name,
                   Installment_Code__c,
                   Status__c,
                   Installment_Fee_Percentage__c,
                   Number_of_Scheduled_Payments__c,
                   Fee_Collection_Start_Date__c,
                   Fee_Collection_End_Date__c,
                   LastModifiedDate
            FROM Payment_Schedule__c
            ORDER BY LastModifiedDate DESC
            LIMIT 500
        ];

        Set<Id> scheduleIds = new Set<Id>();
        for (Payment_Schedule__c scheduleRecord : parentSchedules) {
            scheduleIds.add(scheduleRecord.Id);
        }

        Map<Id, Integer> usageCountByScheduleId = getProgrammeFeeUsageCountByScheduleId(scheduleIds);

        for (Payment_Schedule__c scheduleRecord : parentSchedules) {
            InstallmentPlanRow row = new InstallmentPlanRow();
            row.id = scheduleRecord.Id;
            row.name = scheduleRecord.Name;
            row.installmentCode = scheduleRecord.Installment_Code__c;
            row.status = scheduleRecord.Status__c;
            row.installmentFeePercentage = scheduleRecord.Installment_Fee_Percentage__c;
            row.installmentCount = scheduleRecord.Number_of_Scheduled_Payments__c == null
                ? 0
                : Integer.valueOf(scheduleRecord.Number_of_Scheduled_Payments__c);
            row.startDate = scheduleRecord.Fee_Collection_Start_Date__c;
            row.endDate = scheduleRecord.Fee_Collection_End_Date__c;
            row.lastModified = scheduleRecord.LastModifiedDate;
            row.usedInProgrammeFees = usageCountByScheduleId.containsKey(scheduleRecord.Id)
                ? usageCountByScheduleId.get(scheduleRecord.Id)
                : 0;
            rows.add(row);
        }

        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static InstallmentPlanDetails getInstallmentPlanDetails(Id scheduleId) {
        if (scheduleId == null) {
            throw new AuraHandledException('Installment Plan Id is required.');
        }

        Payment_Schedule__c scheduleRecord = [
            SELECT Id,
                   Name,
                   Installment_Code__c,
                   Status__c,
                   Installment_Fee_Percentage__c,
                   Number_of_Scheduled_Payments__c,
                   Fee_Collection_Start_Date__c,
                   Fee_Collection_End_Date__c,
                   LastModifiedDate
            FROM Payment_Schedule__c
            WHERE Id = :scheduleId
            LIMIT 1
        ];

        List<Payment_Schedule_Instalment__c> lineRecords = [
            SELECT Id,
                   Collection_Order__c,
                   Fee_Collection_Percentage__c,
                   Fee_Collection_Start_Date__c,
                   Fee_Collection_End_Date__c
            FROM Payment_Schedule_Instalment__c
            WHERE Payment_Schedule__c = :scheduleId
            ORDER BY Collection_Order__c ASC, LastModifiedDate ASC
        ];

        InstallmentPlanDetails dto = new InstallmentPlanDetails();
        dto.id = scheduleRecord.Id;
        dto.planName = scheduleRecord.Name;
        dto.installmentCode = scheduleRecord.Installment_Code__c;
        dto.status = scheduleRecord.Status__c;
        dto.installmentFeePercentage = scheduleRecord.Installment_Fee_Percentage__c;
        dto.installmentCount = scheduleRecord.Number_of_Scheduled_Payments__c == null
            ? 0
            : Integer.valueOf(scheduleRecord.Number_of_Scheduled_Payments__c);
        dto.startDate = scheduleRecord.Fee_Collection_Start_Date__c;
        dto.endDate = scheduleRecord.Fee_Collection_End_Date__c;
        dto.lastModified = scheduleRecord.LastModifiedDate;
        dto.usedInProgrammeFees = getProgrammeFeeUsageCount(scheduleId);
        dto.isEditRestricted = dto.usedInProgrammeFees > 0;
        dto.editRestrictionMessage = dto.isEditRestricted ? ERROR_INSTALLMENT_PLAN_IN_USE : null;
        // De-duplicate by collection order and cap to configured installment count.
        Map<Integer, InstallmentInput> rowByOrder = new Map<Integer, InstallmentInput>();
        Integer fallbackOrder = 100000;
        for (Payment_Schedule_Instalment__c lineRecord : lineRecords) {
            Integer orderValue = lineRecord.Collection_Order__c == null
                ? fallbackOrder++
                : Integer.valueOf(lineRecord.Collection_Order__c);
            if (!rowByOrder.containsKey(orderValue)) {
                InstallmentInput row = new InstallmentInput();
                row.lineId = lineRecord.Id;
                row.order = orderValue;
                row.percentage = lineRecord.Fee_Collection_Percentage__c;
                row.startDate = lineRecord.Fee_Collection_Start_Date__c;
                row.dueDays = (lineRecord.Fee_Collection_Start_Date__c == null || lineRecord.Fee_Collection_End_Date__c == null)
                    ? null
                    : lineRecord.Fee_Collection_Start_Date__c.daysBetween(lineRecord.Fee_Collection_End_Date__c);
                rowByOrder.put(orderValue, row);
            }
        }

        List<Integer> sortedOrders = new List<Integer>();
        sortedOrders.addAll(rowByOrder.keySet());
        sortedOrders.sort();

        dto.installments = new List<InstallmentInput>();
        Integer maxRows = dto.installmentCount == null || dto.installmentCount <= 0
            ? sortedOrders.size()
            : dto.installmentCount;
        for (Integer orderValue : sortedOrders) {
            if (dto.installments.size() < maxRows) {
                dto.installments.add(rowByOrder.get(orderValue));
            }
        }

        return dto;
    }

    @AuraEnabled
    public static Id saveInstallmentPlan(String requestJson) {
        if (String.isBlank(requestJson)) {
            throw new AuraHandledException('Request payload is required.');
        }

        InstallmentPlanSaveRequest requestData =
            (InstallmentPlanSaveRequest) JSON.deserialize(requestJson, InstallmentPlanSaveRequest.class);

        if (requestData == null || String.isBlank(requestData.planName)) {
            throw new AuraHandledException('Installment Plan Name is required.');
        }
        if (String.isBlank(requestData.installmentCode)) {
            throw new AuraHandledException('Installment Code is required.');
        }
        if (String.isBlank(requestData.status)) {
            throw new AuraHandledException('Status is required.');
        }
        if (requestData.installmentFeePercentage != null && requestData.installmentFeePercentage < 0) {
            throw new AuraHandledException('Installment Fee (%) cannot be negative.');
        }
        if (requestData.installments == null || requestData.installments.isEmpty()) {
            throw new AuraHandledException('At least one installment row is required.');
        }

        Date minStartDate;
        Date maxEndDate;
        Integer orderCounter = 0;
        Decimal totalCollectionPercentage = 0;

        for (InstallmentInput row : requestData.installments) {
            orderCounter++;
            if (row == null) {
                throw new AuraHandledException('Installment row ' + orderCounter + ' is empty.');
            }
            if (row.percentage == null || row.percentage <= 0) {
                throw new AuraHandledException('Installment percentage is required for row ' + orderCounter + '.');
            }
            if (row.startDate == null) {
                throw new AuraHandledException('Installment Start Date is required for row ' + orderCounter + '.');
            }
            if (row.dueDays == null || row.dueDays < 0) {
                throw new AuraHandledException('Due days must be zero or greater for row ' + orderCounter + '.');
            }
            totalCollectionPercentage += row.percentage;

            if (minStartDate == null || row.startDate < minStartDate) {
                minStartDate = row.startDate;
            }
            Date rowEndDate = row.startDate.addDays(row.dueDays);
            if (maxEndDate == null || rowEndDate > maxEndDate) {
                maxEndDate = rowEndDate;
            }
        }

        if (Math.abs(totalCollectionPercentage - 100) > 0.01) {
            throw new AuraHandledException('Sum of installment percentage must be exactly 100%.');
        }

        Payment_Schedule__c scheduleRecord;
        Boolean isEditMode = requestData.scheduleId != null;
        validateUniqueInstallmentCode(requestData.installmentCode, requestData.scheduleId);
        if (isEditMode) {
            if (isInstallmentPlanUsedInProgrammeFees(requestData.scheduleId)) {
                throw new AuraHandledException(ERROR_INSTALLMENT_PLAN_IN_USE);
            }
            scheduleRecord = [
                SELECT Id
                FROM Payment_Schedule__c
                WHERE Id = :requestData.scheduleId
                LIMIT 1
            ];
            scheduleRecord.Name = requestData.planName.trim();
            scheduleRecord.Installment_Code__c = requestData.installmentCode.trim();
            scheduleRecord.Status__c = requestData.status;
            scheduleRecord.Installment_Fee_Percentage__c = requestData.installmentFeePercentage;
            scheduleRecord.Number_of_Scheduled_Payments__c = requestData.installments.size();
            scheduleRecord.Fee_Collection_Start_Date__c = minStartDate;
            scheduleRecord.Fee_Collection_End_Date__c = maxEndDate;
            update scheduleRecord;
        } else {
            scheduleRecord = new Payment_Schedule__c(
                Name = requestData.planName.trim(),
                Installment_Code__c = requestData.installmentCode.trim(),
                Status__c = requestData.status,
                Installment_Fee_Percentage__c = requestData.installmentFeePercentage,
                Number_of_Scheduled_Payments__c = requestData.installments.size(),
                Fee_Collection_Start_Date__c = minStartDate,
                Fee_Collection_End_Date__c = maxEndDate
            );
            insert scheduleRecord;
        }

        List<Payment_Schedule_Instalment__c> installmentRecords = new List<Payment_Schedule_Instalment__c>();
        if (isEditMode) {
            List<Payment_Schedule_Instalment__c> existingLineRecords = [
                SELECT Id
                FROM Payment_Schedule_Instalment__c
                WHERE Payment_Schedule__c = :scheduleRecord.Id
            ];
            if (!existingLineRecords.isEmpty()) {
                delete existingLineRecords;
            }
        }

        Integer lineOrder = 0;
        for (InstallmentInput row : requestData.installments) {
            lineOrder++;
            Payment_Schedule_Instalment__c installmentRecord = new Payment_Schedule_Instalment__c(
                Payment_Schedule__c = scheduleRecord.Id,
                Collection_Order__c = lineOrder,
                Fee_Collection_Percentage__c = row.percentage,
                // Additional fee percentage is split proportionally by installment percentage.
                Installment_Fee_Split_Percentage__c = row.percentage,
                Fee_Collection_Start_Date__c = row.startDate,
                Fee_Collection_End_Date__c = row.startDate.addDays(row.dueDays)
            );
            installmentRecords.add(installmentRecord);
        }

        if (!installmentRecords.isEmpty()) {
            insert installmentRecords;
        }

        return scheduleRecord.Id;
    }

    @AuraEnabled
    public static void deleteInstallmentPlan(Id scheduleId) {
        if (scheduleId == null) {
            throw new AuraHandledException('Installment Plan Id is required.');
        }
        if (isInstallmentPlanUsedInProgrammeFees(scheduleId)) {
            throw new AuraHandledException(ERROR_INSTALLMENT_PLAN_IN_USE);
        }

        delete [
            SELECT Id
            FROM Payment_Schedule_Instalment__c
            WHERE Payment_Schedule__c = :scheduleId
        ];

        delete [
            SELECT Id
            FROM Payment_Schedule__c
            WHERE Id = :scheduleId
            LIMIT 1
        ];
    }

    private static void validateUniqueInstallmentCode(String installmentCode, Id scheduleId) {
        String normalizedCode = installmentCode == null ? null : installmentCode.trim();
        if (String.isBlank(normalizedCode)) {
            return;
        }

        List<Payment_Schedule__c> existingSchedules = [
            SELECT Id
            FROM Payment_Schedule__c
            WHERE Installment_Code__c = :normalizedCode
            LIMIT 2
        ];

        for (Payment_Schedule__c existingSchedule : existingSchedules) {
            if (scheduleId == null || existingSchedule.Id != scheduleId) {
                throw new AuraHandledException(ERROR_DUPLICATE_INSTALLMENT_CODE);
            }
        }
    }

    private static Boolean isInstallmentPlanUsedInProgrammeFees(Id scheduleId) {
        return getProgrammeFeeUsageCount(scheduleId) > 0;
    }

    private static Integer getProgrammeFeeUsageCount(Id scheduleId) {
        if (scheduleId == null) {
            return 0;
        }
        Map<Id, Integer> usageCountByScheduleId = getProgrammeFeeUsageCountByScheduleId(
            new Set<Id>{ scheduleId }
        );
        return usageCountByScheduleId.containsKey(scheduleId) ? usageCountByScheduleId.get(scheduleId) : 0;
    }

    private static Map<Id, Integer> getProgrammeFeeUsageCountByScheduleId(Set<Id> scheduleIds) {
        Map<Id, Integer> usageCountByScheduleId = new Map<Id, Integer>();
        if (scheduleIds == null || scheduleIds.isEmpty()) {
            return usageCountByScheduleId;
        }

        for (AggregateResult row : [
            SELECT Payment_Schedule__c scheduleId, COUNT(Id) usedCount
            FROM Ken_Fee_Type__c
            WHERE Payment_Schedule__c IN :scheduleIds
            GROUP BY Payment_Schedule__c
        ]) {
            incrementUsageCount(
                usageCountByScheduleId,
                (Id) row.get('scheduleId'),
                Integer.valueOf(String.valueOf(row.get('usedCount')))
            );
        }

        for (AggregateResult row : [
            SELECT Payment_Schedule__c scheduleId, COUNT(Id) usedCount
            FROM Fee_Assignment__c
            WHERE Payment_Schedule__c IN :scheduleIds
            GROUP BY Payment_Schedule__c
        ]) {
            incrementUsageCount(
                usageCountByScheduleId,
                (Id) row.get('scheduleId'),
                Integer.valueOf(String.valueOf(row.get('usedCount')))
            );
        }

        for (AggregateResult row : [
            SELECT Payment_Schedule__c scheduleId, COUNT(Id) usedCount
            FROM Fee_Installment__c
            WHERE Payment_Schedule__c IN :scheduleIds
            GROUP BY Payment_Schedule__c
        ]) {
            incrementUsageCount(
                usageCountByScheduleId,
                (Id) row.get('scheduleId'),
                Integer.valueOf(String.valueOf(row.get('usedCount')))
            );
        }
        return usageCountByScheduleId;
    }

    private static void incrementUsageCount(Map<Id, Integer> usageCountByScheduleId, Id scheduleId, Integer delta) {
        if (scheduleId == null || delta == null || delta <= 0) {
            return;
        }
        Integer existingValue = usageCountByScheduleId.containsKey(scheduleId)
            ? usageCountByScheduleId.get(scheduleId)
            : 0;
        usageCountByScheduleId.put(scheduleId, existingValue + delta);
    }
}