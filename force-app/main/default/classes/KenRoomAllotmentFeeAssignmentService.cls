public with sharing class KenRoomAllotmentFeeAssignmentService {
    private static final Decimal FULL_PERCENTAGE = 100;
    private static final Integer SINGLE_INSTALLMENT_NUMBER = 1;
    private static final String ASSIGNMENT_STATUS_ACTIVE = 'Active';
    private static final String INSTALLMENT_STATUS_PLANNED = 'Planned';
    private static final String ASSIGNMENT_NAME = 'Room Allotment Fee';

    private class FeeLineData {
        Id feeLineId;
        Id feeTypeId;
        Decimal amount;
        Id feeHeadId;
        Id taxId;
        Date dueDate;
        String currencyIsoCode;
    }

    private class AssignmentBuildData {
        Id accountId;
        Id feeTypeId;
        List<FeeLineData> feeLines;
        Decimal totalAmount;
        Date dueDate;
        String currencyIsoCode;
        Fee_Assignment__c assignmentRecord;
        Fee_Installment__c installmentRecord;
    }

    private class AssignmentLineInsertContext {
        Integer buildIndex;
    }

    public static void createFromRoomAllotments(List<Ken_Room_Allotment__c> newRows) {
        if (newRows == null || newRows.isEmpty()) {
            return;
        }

        Set<Id> roomAllotmentIds = new Set<Id>();
        for (Ken_Room_Allotment__c roomAllotment : newRows) {
            if (roomAllotment != null && roomAllotment.Id != null) {
                roomAllotmentIds.add(roomAllotment.Id);
            }
        }
        if (roomAllotmentIds.isEmpty()) {
            return;
        }

        List<Ken_Room_Allotment__c> roomAllotments = [
            SELECT Id, Tenant_Account__c, Room__c, Room__r.Room_Category__c
            FROM Ken_Room_Allotment__c
            WHERE Id IN :roomAllotmentIds
        ];
        if (roomAllotments.isEmpty()) {
            return;
        }

        Map<Id, Set<Id>> feeTypeIdsByAllotmentId = mapFeeTypeIdsByRoomAllotment(roomAllotments);
        if (feeTypeIdsByAllotmentId.isEmpty()) {
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        Set<Id> feeTypeIds = new Set<Id>();
        for (Ken_Room_Allotment__c roomAllotment : roomAllotments) {
            Set<Id> feeTypeIdsForAllotment = feeTypeIdsByAllotmentId.get(roomAllotment.Id);
            if (roomAllotment.Tenant_Account__c == null || feeTypeIdsForAllotment == null || feeTypeIdsForAllotment.isEmpty()) {
                continue;
            }

            accountIds.add(roomAllotment.Tenant_Account__c);
            feeTypeIds.addAll(feeTypeIdsForAllotment);
        }
        if (accountIds.isEmpty() || feeTypeIds.isEmpty()) {
            return;
        }

        Set<String> existingAssignmentKeys = queryExistingActiveAssignmentKeys(accountIds, feeTypeIds);
        Map<Id, List<FeeLineData>> feeLinesByFeeTypeId = queryFeeLinesByFeeTypeId(feeTypeIds);
        if (feeLinesByFeeTypeId.isEmpty()) {
            return;
        }

        List<AssignmentBuildData> builds = new List<AssignmentBuildData>();
        Set<String> pendingAssignmentKeys = new Set<String>();
        for (Ken_Room_Allotment__c roomAllotment : roomAllotments) {
            if (roomAllotment.Tenant_Account__c == null) {
                continue;
            }

            Set<Id> mappedFeeTypeIds = feeTypeIdsByAllotmentId.get(roomAllotment.Id);
            if (mappedFeeTypeIds == null || mappedFeeTypeIds.isEmpty()) {
                continue;
            }

            for (Id feeTypeId : mappedFeeTypeIds) {
                String assignmentKey = buildAssignmentKey(roomAllotment.Tenant_Account__c, feeTypeId);
                if (existingAssignmentKeys.contains(assignmentKey) || pendingAssignmentKeys.contains(assignmentKey)) {
                    continue;
                }

                List<FeeLineData> feeLines = feeLinesByFeeTypeId.get(feeTypeId);
                if (feeLines == null || feeLines.isEmpty()) {
                    continue;
                }

                AssignmentBuildData build = buildAssignmentData(roomAllotment.Tenant_Account__c, feeTypeId, feeLines);
                if (build.totalAmount == null || build.totalAmount <= 0) {
                    continue;
                }

                builds.add(build);
                pendingAssignmentKeys.add(assignmentKey);
            }
        }
        if (builds.isEmpty()) {
            return;
        }

        List<Fee_Assignment__c> assignmentsToInsert = new List<Fee_Assignment__c>();
        for (AssignmentBuildData build : builds) {
            Fee_Assignment__c assignmentRecord = new Fee_Assignment__c(
                Account__c = build.accountId,
                Fee_Type__c = build.feeTypeId,
                Fee_Assignment_Name__c = ASSIGNMENT_NAME,
                Fee_Amount__c = build.totalAmount,
                Number_of_Installments__c = SINGLE_INSTALLMENT_NUMBER,
                Active__c = true,
                Status__c = ASSIGNMENT_STATUS_ACTIVE
            );
            if (!String.isBlank(build.currencyIsoCode)) {
                assignmentRecord.CurrencyIsoCode = build.currencyIsoCode;
            }

            assignmentsToInsert.add(assignmentRecord);
            build.assignmentRecord = assignmentRecord;
        }
        insert assignmentsToInsert;

        List<Fee_Assignment_Line_Item__c> assignmentLineItemsToInsert = new List<Fee_Assignment_Line_Item__c>();
        List<AssignmentLineInsertContext> assignmentLineContexts = new List<AssignmentLineInsertContext>();
        for (Integer buildIndex = 0; buildIndex < builds.size(); buildIndex++) {
            AssignmentBuildData build = builds[buildIndex];
            for (FeeLineData feeLine : build.feeLines) {
                Fee_Assignment_Line_Item__c assignmentLine = new Fee_Assignment_Line_Item__c(
                    Fee_Assignment__c = build.assignmentRecord.Id,
                    Fee_Type_Line_Item__c = feeLine.feeLineId,
                    Fee_Head__c = feeLine.feeHeadId,
                    Tax__c = feeLine.taxId,
                    Amount__c = feeLine.amount,
                    Total_Amount__c = feeLine.amount,
                    Is_Active__c = true
                );
                assignmentLineItemsToInsert.add(assignmentLine);

                AssignmentLineInsertContext context = new AssignmentLineInsertContext();
                context.buildIndex = buildIndex;
                assignmentLineContexts.add(context);
            }
        }
        if (assignmentLineItemsToInsert.isEmpty()) {
            return;
        }
        insert assignmentLineItemsToInsert;

        List<Fee_Installment__c> installmentsToInsert = new List<Fee_Installment__c>();
        for (AssignmentBuildData build : builds) {
            Fee_Installment__c installment = new Fee_Installment__c(
                Fee_Assignment__c = build.assignmentRecord.Id,
                Amount__c = build.totalAmount,
                Fee_Amount_Payable__c = build.totalAmount,
                Total_Amount__c = build.totalAmount,
                Percentage__c = FULL_PERCENTAGE,
                Installment_Number__c = SINGLE_INSTALLMENT_NUMBER,
                Number_of_Installments__c = SINGLE_INSTALLMENT_NUMBER,
                Due_Date__c = build.dueDate,
                Active__c = true,
                Status__c = INSTALLMENT_STATUS_PLANNED
            );
            if (!String.isBlank(build.currencyIsoCode)) {
                installment.CurrencyIsoCode = build.currencyIsoCode;
            }

            installmentsToInsert.add(installment);
            build.installmentRecord = installment;
        }
        insert installmentsToInsert;

        Map<Integer, List<Fee_Assignment_Line_Item__c>> insertedAssignmentLinesByBuildIndex =
            new Map<Integer, List<Fee_Assignment_Line_Item__c>>();
        for (Integer lineIndex = 0; lineIndex < assignmentLineItemsToInsert.size(); lineIndex++) {
            AssignmentLineInsertContext context = assignmentLineContexts[lineIndex];
            if (!insertedAssignmentLinesByBuildIndex.containsKey(context.buildIndex)) {
                insertedAssignmentLinesByBuildIndex.put(context.buildIndex, new List<Fee_Assignment_Line_Item__c>());
            }
            insertedAssignmentLinesByBuildIndex.get(context.buildIndex).add(assignmentLineItemsToInsert[lineIndex]);
        }

        List<Fee_Installment_Line_Item__c> installmentLineItemsToInsert = new List<Fee_Installment_Line_Item__c>();
        for (Integer buildIndex = 0; buildIndex < builds.size(); buildIndex++) {
            AssignmentBuildData build = builds[buildIndex];
            List<Fee_Assignment_Line_Item__c> insertedLines = insertedAssignmentLinesByBuildIndex.get(buildIndex);
            if (insertedLines == null || insertedLines.isEmpty()) {
                continue;
            }

            Decimal installmentTotal = build.totalAmount == null ? 0 : build.totalAmount;
            Decimal remainingInstallmentAmount = installmentTotal;
            for (Fee_Assignment_Line_Item__c insertedLine : insertedLines) {
                Decimal lineAmount = insertedLine.Total_Amount__c == null ? 0 : insertedLine.Total_Amount__c;
                if (lineAmount <= 0 || remainingInstallmentAmount <= 0) {
                    continue;
                }

                Decimal allocationAmount = lineAmount <= remainingInstallmentAmount
                    ? lineAmount
                    : remainingInstallmentAmount;
                Decimal allocationPercentage = installmentTotal == 0
                    ? 0
                    : (allocationAmount * FULL_PERCENTAGE) / installmentTotal;

                Fee_Installment_Line_Item__c installmentLineItem = new Fee_Installment_Line_Item__c(
                    Fee_Installment__c = build.installmentRecord.Id,
                    Fee_Assignment_Line_Item__c = insertedLine.Id,
                    Amount__c = allocationAmount,
                    Percentage__c = allocationPercentage,
                    Installment_Number__c = SINGLE_INSTALLMENT_NUMBER,
                    Due_Date__c = build.installmentRecord.Due_Date__c,
                    Active__c = true,
                    Status__c = INSTALLMENT_STATUS_PLANNED
                );
                installmentLineItemsToInsert.add(installmentLineItem);

                remainingInstallmentAmount -= allocationAmount;
            }
        }

        if (!installmentLineItemsToInsert.isEmpty()) {
            insert installmentLineItemsToInsert;
        }
    }

    private static Map<Id, Set<Id>> mapFeeTypeIdsByRoomAllotment(List<Ken_Room_Allotment__c> roomAllotments) {
        Map<Id, Set<Id>> feeTypeIdsByAllotmentId = new Map<Id, Set<Id>>();
        if (roomAllotments == null || roomAllotments.isEmpty()) {
            return feeTypeIdsByAllotmentId;
        }

        Set<Id> roomCategoryIds = new Set<Id>();
        for (Ken_Room_Allotment__c roomAllotment : roomAllotments) {
            Id roomCategoryId = roomAllotment.Room__r == null
                ? null
                : roomAllotment.Room__r.Room_Category__c;
            if (roomCategoryId != null) {
                roomCategoryIds.add(roomCategoryId);
            }
        }
        if (roomCategoryIds.isEmpty()) {
            return feeTypeIdsByAllotmentId;
        }

        Map<Id, Set<Id>> feeTypeIdsByRoomCategoryId = new Map<Id, Set<Id>>();
        for (Ken_Room_Category_Fee_Type__c mappingRow : [
            SELECT Room_Category__c, Fee_Type__c
            FROM Ken_Room_Category_Fee_Type__c
            WHERE Room_Category__c IN :roomCategoryIds
              AND Fee_Type__c != null
        ]) {
            if (!feeTypeIdsByRoomCategoryId.containsKey(mappingRow.Room_Category__c)) {
                feeTypeIdsByRoomCategoryId.put(mappingRow.Room_Category__c, new Set<Id>());
            }
            feeTypeIdsByRoomCategoryId.get(mappingRow.Room_Category__c).add(mappingRow.Fee_Type__c);
        }

        for (Ken_Room_Allotment__c roomAllotment : roomAllotments) {
            Id roomCategoryId = roomAllotment.Room__r == null
                ? null
                : roomAllotment.Room__r.Room_Category__c;
            if (roomCategoryId == null || !feeTypeIdsByRoomCategoryId.containsKey(roomCategoryId)) {
                continue;
            }

            feeTypeIdsByAllotmentId.put(
                roomAllotment.Id,
                new Set<Id>(feeTypeIdsByRoomCategoryId.get(roomCategoryId))
            );
        }

        return feeTypeIdsByAllotmentId;
    }

    private static Set<String> queryExistingActiveAssignmentKeys(Set<Id> accountIds, Set<Id> feeTypeIds) {
        Set<String> keys = new Set<String>();
        if (accountIds == null || accountIds.isEmpty() || feeTypeIds == null || feeTypeIds.isEmpty()) {
            return keys;
        }

        for (Fee_Assignment__c assignment : [
            SELECT Account__c, Fee_Type__c
            FROM Fee_Assignment__c
            WHERE Active__c = true
              AND Account__c IN :accountIds
              AND Fee_Type__c IN :feeTypeIds
        ]) {
            if (assignment.Account__c != null && assignment.Fee_Type__c != null) {
                keys.add(buildAssignmentKey(assignment.Account__c, assignment.Fee_Type__c));
            }
        }
        return keys;
    }

    private static Map<Id, List<FeeLineData>> queryFeeLinesByFeeTypeId(Set<Id> feeTypeIds) {
        Map<Id, List<FeeLineData>> result = new Map<Id, List<FeeLineData>>();
        if (feeTypeIds == null || feeTypeIds.isEmpty()) {
            return result;
        }

        String feeLineObjectApiName = resolveFeeLineObjectApiName();
        if (String.isBlank(feeLineObjectApiName)) {
            return result;
        }

        Schema.DescribeSObjectResult describeResult =
            Schema.getGlobalDescribe().get(feeLineObjectApiName).getDescribe();
        Map<String, Schema.SObjectField> fieldMap = describeResult.fields.getMap();

        String feeTypeLookupField = resolveFieldApiName(
            fieldMap,
            new List<String>{ 'Fee_Type__c', 'Ken_Fee_Type__c' }
        );
        if (String.isBlank(feeTypeLookupField) || !fieldMap.containsKey('Amount__c')) {
            return result;
        }

        Boolean hasIsActive = fieldMap.containsKey('Is_Active__c');
        Boolean hasFeeHead = fieldMap.containsKey('Fee_Head__c');
        Boolean hasTax = fieldMap.containsKey('Tax__c');
        Boolean hasDueDate = fieldMap.containsKey('Due_Date__c');
        Boolean hasSettlementOrder = fieldMap.containsKey('Settlement_Order__c');
        Boolean hasCurrency = fieldMap.containsKey('CurrencyIsoCode');

        List<String> selectedFields = new List<String>{ 'Id', feeTypeLookupField, 'Amount__c' };
        if (hasFeeHead) {
            selectedFields.add('Fee_Head__c');
        }
        if (hasTax) {
            selectedFields.add('Tax__c');
        }
        if (hasDueDate) {
            selectedFields.add('Due_Date__c');
        }
        if (hasCurrency) {
            selectedFields.add('CurrencyIsoCode');
        }

        String queryText =
            'SELECT ' + String.join(selectedFields, ',') +
            ' FROM ' + feeLineObjectApiName +
            ' WHERE ' + feeTypeLookupField + ' IN :feeTypeIds';
        if (hasIsActive) {
            queryText += ' AND Is_Active__c = true';
        }
        if (hasSettlementOrder) {
            queryText += ' ORDER BY ' + feeTypeLookupField + ' ASC, Settlement_Order__c ASC, CreatedDate ASC';
        } else {
            queryText += ' ORDER BY ' + feeTypeLookupField + ' ASC, CreatedDate ASC';
        }

        for (SObject feeLineRow : Database.query(queryText)) {
            Id feeTypeId = (Id) feeLineRow.get(feeTypeLookupField);
            if (feeTypeId == null) {
                continue;
            }

            Decimal amount = decimalOrZero(feeLineRow.get('Amount__c'));
            if (amount <= 0) {
                continue;
            }

            FeeLineData data = new FeeLineData();
            data.feeLineId = (Id) feeLineRow.get('Id');
            data.feeTypeId = feeTypeId;
            data.amount = amount;
            data.feeHeadId = hasFeeHead ? (Id) feeLineRow.get('Fee_Head__c') : null;
            data.taxId = hasTax ? (Id) feeLineRow.get('Tax__c') : null;
            data.dueDate = hasDueDate ? (Date) feeLineRow.get('Due_Date__c') : null;
            data.currencyIsoCode = hasCurrency ? (String) feeLineRow.get('CurrencyIsoCode') : null;

            if (!result.containsKey(feeTypeId)) {
                result.put(feeTypeId, new List<FeeLineData>());
            }
            result.get(feeTypeId).add(data);
        }

        return result;
    }

    private static AssignmentBuildData buildAssignmentData(
        Id accountId,
        Id feeTypeId,
        List<FeeLineData> sourceLines
    ) {
        AssignmentBuildData build = new AssignmentBuildData();
        build.accountId = accountId;
        build.feeTypeId = feeTypeId;
        build.feeLines = new List<FeeLineData>();
        build.totalAmount = 0;

        for (FeeLineData line : sourceLines) {
            build.feeLines.add(line);
            build.totalAmount += line.amount;
            if (build.dueDate == null || (line.dueDate != null && line.dueDate < build.dueDate)) {
                build.dueDate = line.dueDate;
            }
            if (String.isBlank(build.currencyIsoCode) && !String.isBlank(line.currencyIsoCode)) {
                build.currencyIsoCode = line.currencyIsoCode;
            }
        }

        return build;
    }

    private static String resolveFeeLineObjectApiName() {
        Map<String, Schema.SObjectType> describeMap = Schema.getGlobalDescribe();
        if (describeMap.containsKey('Ken_Fee_Type_Line__c')) {
            return 'Ken_Fee_Type_Line__c';
        }
        if (describeMap.containsKey('Ken_Fee_Type_Line_Item__c')) {
            return 'Ken_Fee_Type_Line_Item__c';
        }
        return null;
    }

    private static String resolveFieldApiName(
        Map<String, Schema.SObjectField> fieldMap,
        List<String> candidates
    ) {
        if (fieldMap == null || candidates == null || candidates.isEmpty()) {
            return null;
        }

        for (String candidate : candidates) {
            if (fieldMap.containsKey(candidate)) {
                return candidate;
            }
        }
        return null;
    }

    private static Decimal decimalOrZero(Object value) {
        if (value == null) {
            return 0;
        }
        if (value instanceof Decimal) {
            return (Decimal) value;
        }
        return Decimal.valueOf(String.valueOf(value));
    }

    private static String buildAssignmentKey(Id accountId, Id feeTypeId) {
        return String.valueOf(accountId) + '|' + String.valueOf(feeTypeId);
    }
}