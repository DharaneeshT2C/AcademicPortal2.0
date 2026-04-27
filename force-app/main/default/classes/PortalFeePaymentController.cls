public without sharing class PortalFeePaymentController {
    private class CurrentUserContext {
        public Id accountId;
        public Id contactId;
    }

    public class FeeAssignmentLineItemRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String feeItem;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public String currencyIsoCode;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Decimal tax;
        @AuraEnabled public Decimal tds;
        @AuraEnabled public Decimal totalPayable;
        @AuraEnabled public Decimal paidAmount;
        @AuraEnabled public String feePeriod;
        @AuraEnabled public String statusLabel;
        @AuraEnabled public Id feeAssignmentId;
        @AuraEnabled public Id feeAssignmentLineItemId;
        @AuraEnabled public Id feeInstallmentId;
        @AuraEnabled public Id feeInstallmentLineItemId;
    }

    public class FeeAssignmentRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String feeItem;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public String currencyIsoCode;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Decimal tax;
        @AuraEnabled public Decimal tds;
        @AuraEnabled public Decimal totalPayable;
        @AuraEnabled public Decimal paidAmount;
        @AuraEnabled public String description;
        @AuraEnabled public String mode;
        @AuraEnabled public Id accountId;
        @AuraEnabled public List<FeeAssignmentLineItemRow> lineItems;
    }

    @AuraEnabled(cacheable=true)
    public static List<FeeAssignmentRow> getCurrentUserFeeAssignments() {
        List<FeeAssignmentRow> responseRows = new List<FeeAssignmentRow>();

        Id accountId = resolveCurrentUserAccountId();
        if (accountId == null) {
            return responseRows;
        }

        List<Fee_Assignment__c> assignments = [
            SELECT
                Id,
                Account__c,
                Name,
                Fee_Assignment_Name__c,
                Paid_Amount__c,
                Remaining_Amount_Formula__c,
                Total_Amount_Payable_Formula__c,
                CurrencyIsoCode,
                Fee_Type__r.Fee_Collection_Frequency__c
            FROM Fee_Assignment__c
            WHERE Account__c = :accountId
              AND Active__c = true
            ORDER BY CreatedDate DESC
        ];
        return buildFeeAssignmentRows(assignments);
    }

    @AuraEnabled(cacheable=true)
    public static List<FeeAssignmentRow> getCurrentUserAllotmentFeeAssignments() {
        List<FeeAssignmentRow> responseRows = new List<FeeAssignmentRow>();

        CurrentUserContext userContext = resolveCurrentUserContext();
        Id currentAllotmentId = resolveCurrentRoomAllotmentId(userContext);
        if (
            currentAllotmentId == null
            || !Schema.sObjectType.Fee_Assignment__c.fields.getMap().containsKey('Room_Allotment__c')
        ) {
            return responseRows;
        }

        List<Fee_Assignment__c> assignments = Database.query(
            'SELECT Id, Account__c, Name, Fee_Assignment_Name__c, Paid_Amount__c, ' +
            'Remaining_Amount_Formula__c, Total_Amount_Payable_Formula__c, CurrencyIsoCode, ' +
            'Fee_Type__r.Fee_Collection_Frequency__c ' +
            'FROM Fee_Assignment__c ' +
            'WHERE Room_Allotment__c = :currentAllotmentId AND Active__c = true ' +
            'ORDER BY CreatedDate DESC'
        );
        return buildFeeAssignmentRows(assignments);
    }

    private static List<FeeAssignmentRow> buildFeeAssignmentRows(List<Fee_Assignment__c> assignments) {
        List<FeeAssignmentRow> responseRows = new List<FeeAssignmentRow>();
        if (assignments == null || assignments.isEmpty()) {
            return responseRows;
        }

        Set<Id> assignmentIds = new Set<Id>();
        for (Fee_Assignment__c assignment : assignments) {
            assignmentIds.add(assignment.Id);
        }

        Map<Id, List<Fee_Installment__c>> installmentsByAssignmentId =
            new Map<Id, List<Fee_Installment__c>>();
        Map<Id, Date> earliestDueDateByAssignmentId = new Map<Id, Date>();
        Set<Id> installmentIds = new Set<Id>();

        for (Fee_Installment__c installment : [
            SELECT
                Id,
                Fee_Assignment__c,
                Installment_Number__c,
                Due_Date__c,
                Total_Amount_Payable_Formula__c,
                Total_Paid_Amount__c,
                Remaining_Amount_Formula__c,
                CurrencyIsoCode,
                Status__c
            FROM Fee_Installment__c
            WHERE Fee_Assignment__c IN :assignmentIds
              AND Active__c = true
            ORDER BY Fee_Assignment__c ASC, Due_Date__c ASC, Installment_Number__c ASC, CreatedDate ASC
        ]) {
            if (installment.Fee_Assignment__c == null) {
                continue;
            }

            installmentIds.add(installment.Id);

            if (!installmentsByAssignmentId.containsKey(installment.Fee_Assignment__c)) {
                installmentsByAssignmentId.put(installment.Fee_Assignment__c, new List<Fee_Installment__c>());
            }
            installmentsByAssignmentId.get(installment.Fee_Assignment__c).add(installment);

            if (!earliestDueDateByAssignmentId.containsKey(installment.Fee_Assignment__c)) {
                earliestDueDateByAssignmentId.put(installment.Fee_Assignment__c, installment.Due_Date__c);
            }
        }

        Map<Id, Id> firstInstallmentLineByInstallmentId = new Map<Id, Id>();
        Map<Id, Id> firstAssignmentLineByInstallmentId = new Map<Id, Id>();
        if (!installmentIds.isEmpty()) {
            for (Fee_Installment_Line_Item__c installmentLine : [
                SELECT Id, Fee_Installment__c, Fee_Assignment_Line_Item__c
                FROM Fee_Installment_Line_Item__c
                WHERE Fee_Installment__c IN :installmentIds
                ORDER BY CreatedDate ASC
            ]) {
                if (installmentLine.Fee_Installment__c == null) {
                    continue;
                }
                if (!firstInstallmentLineByInstallmentId.containsKey(installmentLine.Fee_Installment__c)) {
                    firstInstallmentLineByInstallmentId.put(
                        installmentLine.Fee_Installment__c,
                        installmentLine.Id
                    );
                }
                if (
                    installmentLine.Fee_Assignment_Line_Item__c != null
                    && !firstAssignmentLineByInstallmentId.containsKey(installmentLine.Fee_Installment__c)
                ) {
                    firstAssignmentLineByInstallmentId.put(
                        installmentLine.Fee_Installment__c,
                        installmentLine.Fee_Assignment_Line_Item__c
                    );
                }
            }
        }

        for (Fee_Assignment__c assignment : assignments) {
            List<Fee_Installment__c> assignmentInstallments = installmentsByAssignmentId.containsKey(assignment.Id)
                ? installmentsByAssignmentId.get(assignment.Id)
                : new List<Fee_Installment__c>();

            List<FeeAssignmentLineItemRow> childRows = new List<FeeAssignmentLineItemRow>();
            Decimal childTotalPayableSum = 0;
            Decimal childPaidSum = 0;

            for (Integer index = 0; index < assignmentInstallments.size(); index++) {
                Fee_Installment__c installment = assignmentInstallments[index];
                Decimal installmentTotalPayable =
                    valueOrZero(installment.Total_Amount_Payable_Formula__c);
                Decimal installmentPaid = valueOrZero(installment.Total_Paid_Amount__c);
                Decimal installmentRemaining =
                    valueOrZero(installment.Remaining_Amount_Formula__c);

                if (installmentTotalPayable <= 0) {
                    installmentTotalPayable = installmentPaid + installmentRemaining;
                }
                if (installmentPaid <= 0 && installmentTotalPayable > installmentRemaining) {
                    installmentPaid = installmentTotalPayable - installmentRemaining;
                }
                if (installmentPaid > installmentTotalPayable) {
                    installmentPaid = installmentTotalPayable;
                }

                FeeAssignmentLineItemRow childRow = new FeeAssignmentLineItemRow();
                childRow.id = installment.Id;
                childRow.feeItem = buildInstallmentLabel(installment.Installment_Number__c, index + 1);
                childRow.feePeriod = '--';
                childRow.dueDate = installment.Due_Date__c;
                childRow.currencyIsoCode = String.isBlank(installment.CurrencyIsoCode)
                    ? assignment.CurrencyIsoCode
                    : installment.CurrencyIsoCode;
                childRow.totalAmount = installmentTotalPayable;
                childRow.tax = 0;
                childRow.tds = 0;
                childRow.totalPayable = installmentTotalPayable;
                childRow.paidAmount = installmentPaid;
                childRow.statusLabel = String.isBlank(installment.Status__c)
                    ? deriveStatusLabel(installmentTotalPayable, installmentPaid)
                    : installment.Status__c;
                childRow.feeAssignmentId = assignment.Id;
                childRow.feeAssignmentLineItemId = firstAssignmentLineByInstallmentId.get(installment.Id);
                childRow.feeInstallmentId = installment.Id;
                childRow.feeInstallmentLineItemId = firstInstallmentLineByInstallmentId.get(installment.Id);
                childRows.add(childRow);

                childTotalPayableSum += installmentTotalPayable;
                childPaidSum += installmentPaid;
            }

            Decimal totalPayable = valueOrZero(assignment.Total_Amount_Payable_Formula__c);
            Decimal paidAmount = valueOrZero(assignment.Paid_Amount__c);
            Decimal remainingAmount = valueOrZero(assignment.Remaining_Amount_Formula__c);

            if (totalPayable <= 0) {
                totalPayable = paidAmount + remainingAmount;
            }
            if (totalPayable <= 0) {
                totalPayable = childTotalPayableSum;
            }
            if (paidAmount <= 0 && totalPayable > remainingAmount) {
                paidAmount = totalPayable - remainingAmount;
            }
            if (paidAmount <= 0 && childPaidSum > 0) {
                paidAmount = childPaidSum;
            }
            paidAmount = valueOrZero(paidAmount);
            if (paidAmount > totalPayable) {
                paidAmount = totalPayable;
            }
            Decimal assignmentTotal = totalPayable;

            FeeAssignmentRow mappedAssignment = new FeeAssignmentRow();
            mappedAssignment.id = assignment.Id;
            mappedAssignment.accountId = assignment.Account__c;
            mappedAssignment.mode = assignment.Fee_Type__r == null
                ? null
                : assignment.Fee_Type__r.Fee_Collection_Frequency__c;
            mappedAssignment.feeItem = String.isBlank(assignment.Fee_Assignment_Name__c)
                ? assignment.Name
                : assignment.Fee_Assignment_Name__c;
            mappedAssignment.dueDate = earliestDueDateByAssignmentId.get(assignment.Id);
            mappedAssignment.currencyIsoCode = assignment.CurrencyIsoCode;
            mappedAssignment.totalAmount = assignmentTotal;
            mappedAssignment.tax = 0;
            mappedAssignment.tds = 0;
            mappedAssignment.totalPayable = totalPayable;
            mappedAssignment.paidAmount = paidAmount;
            mappedAssignment.description = 'Fee assignment with installments';
            mappedAssignment.lineItems = childRows;

            responseRows.add(mappedAssignment);
        }

        return responseRows;
    }

    private static Id resolveCurrentRoomAllotmentId(CurrentUserContext userContext) {
        if (userContext == null || (userContext.accountId == null && userContext.contactId == null)) {
            return null;
        }

        List<Ken_Room_Allotment__c> allotments;
        if (userContext.accountId != null && userContext.contactId != null) {
            allotments = [
                SELECT Id, Active__c, Start_Date__c, End_Date__c
                FROM Ken_Room_Allotment__c
                WHERE Room__c != null
                  AND (Tenant_Account__c = :userContext.accountId OR Tenant__c = :userContext.contactId)
                ORDER BY Active__c DESC, End_Date__c DESC NULLS LAST, Start_Date__c DESC NULLS LAST, CreatedDate DESC
                LIMIT 50
            ];
        } else if (userContext.accountId != null) {
            allotments = [
                SELECT Id, Active__c, Start_Date__c, End_Date__c
                FROM Ken_Room_Allotment__c
                WHERE Room__c != null
                  AND Tenant_Account__c = :userContext.accountId
                ORDER BY Active__c DESC, End_Date__c DESC NULLS LAST, Start_Date__c DESC NULLS LAST, CreatedDate DESC
                LIMIT 50
            ];
        } else {
            allotments = [
                SELECT Id, Active__c, Start_Date__c, End_Date__c
                FROM Ken_Room_Allotment__c
                WHERE Room__c != null
                  AND Tenant__c = :userContext.contactId
                ORDER BY Active__c DESC, End_Date__c DESC NULLS LAST, Start_Date__c DESC NULLS LAST, CreatedDate DESC
                LIMIT 50
            ];
        }
        if (allotments.isEmpty()) {
            return null;
        }

        Date today = Date.today();
        for (Ken_Room_Allotment__c allotment : allotments) {
            if (allotment.Active__c == true && isAllotmentInDateRange(allotment, today)) {
                return allotment.Id;
            }
        }

        for (Ken_Room_Allotment__c allotment : allotments) {
            if (isAllotmentInDateRange(allotment, today)) {
                return allotment.Id;
            }
        }

        for (Ken_Room_Allotment__c allotment : allotments) {
            if (allotment.Active__c == true) {
                return allotment.Id;
            }
        }

        return allotments[0].Id;
    }

    private static Boolean isAllotmentInDateRange(Ken_Room_Allotment__c allotment, Date referenceDate) {
        if (allotment == null || referenceDate == null) {
            return false;
        }
        Boolean startsBeforeOrOn = allotment.Start_Date__c == null || allotment.Start_Date__c <= referenceDate;
        Boolean endsAfterOrOn = allotment.End_Date__c == null || allotment.End_Date__c >= referenceDate;
        return startsBeforeOrOn && endsAfterOrOn;
    }

    @AuraEnabled(cacheable=true)
    public static List<FeeAssignmentRow> getCurrentUserPortalPlanAssignments() {
        try {
            List<FeeAssignmentRow> responseRows = new List<FeeAssignmentRow>();
            CurrentUserContext userContext = resolveCurrentUserContext();
            if (userContext.accountId == null) {
                return responseRows;
            }

            List<Fee_Assignment__c> assignments = [
                SELECT
                    Id,
                    Account__c,
                    Name,
                    Fee_Assignment_Name__c,
                    Fee_Amount__c,
                    Paid_Amount__c,
                    Remaining_Amount_Formula__c,
                    Total_Amount_Payable_Formula__c,
                    CurrencyIsoCode,
                    Fee_Type__r.Fee_Collection_Frequency__c
                FROM Fee_Assignment__c
                WHERE Account__c = :userContext.accountId
                ORDER BY Active__c DESC, CreatedDate DESC
            ];
            if (assignments.isEmpty()) {
                return responseRows;
            }

            Set<Id> assignmentIds = new Set<Id>();
            for (Fee_Assignment__c assignment : assignments) {
                assignmentIds.add(assignment.Id);
            }

            Map<Id, Date> earliestDueDateByAssignmentId = new Map<Id, Date>();
            for (AggregateResult dueDateAggregate : [
                SELECT Fee_Assignment__c assignmentId, MIN(Due_Date__c) earliestDueDate
                FROM Fee_Installment__c
                WHERE Fee_Assignment__c IN :assignmentIds
                GROUP BY Fee_Assignment__c
            ]) {
                earliestDueDateByAssignmentId.put(
                    (Id) dueDateAggregate.get('assignmentId'),
                    (Date) dueDateAggregate.get('earliestDueDate')
                );
            }

            Map<Id, List<FeeAssignmentLineItemRow>> lineItemsByAssignmentId =
                new Map<Id, List<FeeAssignmentLineItemRow>>();
            Map<Id, Decimal> totalFromLineItemsByAssignmentId = new Map<Id, Decimal>();
            Set<Id> assignmentLineItemIds = new Set<Id>();

            for (Fee_Assignment_Line_Item__c assignmentLineItem : [
                SELECT
                    Id,
                    Fee_Assignment__c,
                    Fee_Head__r.Name,
                    Amount__c,
                    Total_Amount__c,
                    CurrencyIsoCode
                FROM Fee_Assignment_Line_Item__c
                WHERE Fee_Assignment__c IN :assignmentIds
                ORDER BY Fee_Assignment__c ASC, CreatedDate ASC
            ]) {
                Id assignmentId = assignmentLineItem.Fee_Assignment__c;
                if (assignmentId == null) {
                    continue;
                }

                assignmentLineItemIds.add(assignmentLineItem.Id);

                if (!lineItemsByAssignmentId.containsKey(assignmentId)) {
                    lineItemsByAssignmentId.put(assignmentId, new List<FeeAssignmentLineItemRow>());
                }

                Decimal lineAmount = assignmentLineItem.Total_Amount__c != null
                    ? assignmentLineItem.Total_Amount__c
                    : valueOrZero(assignmentLineItem.Amount__c);

                FeeAssignmentLineItemRow mappedLineItem = new FeeAssignmentLineItemRow();
                mappedLineItem.id = assignmentLineItem.Id;
                mappedLineItem.feeItem = assignmentLineItem.Fee_Head__r == null
                    ? 'Fee Item'
                    : assignmentLineItem.Fee_Head__r.Name;
                mappedLineItem.currencyIsoCode = assignmentLineItem.CurrencyIsoCode;
                mappedLineItem.totalAmount = lineAmount;
                mappedLineItem.tax = 0;
                mappedLineItem.tds = 0;
                mappedLineItem.totalPayable = lineAmount;
                mappedLineItem.paidAmount = 0;
                mappedLineItem.dueDate = earliestDueDateByAssignmentId.get(assignmentId);
                mappedLineItem.feeAssignmentId = assignmentId;
                mappedLineItem.feeAssignmentLineItemId = assignmentLineItem.Id;

                lineItemsByAssignmentId.get(assignmentId).add(mappedLineItem);

                Decimal runningTotal = totalFromLineItemsByAssignmentId.containsKey(assignmentId)
                    ? totalFromLineItemsByAssignmentId.get(assignmentId)
                    : 0;
                totalFromLineItemsByAssignmentId.put(assignmentId, runningTotal + lineAmount);
            }

            Map<Id, Fee_Installment_Line_Item__c> firstInstallmentLineByAssignmentLineId =
                new Map<Id, Fee_Installment_Line_Item__c>();
            if (!assignmentLineItemIds.isEmpty()) {
                for (Fee_Installment_Line_Item__c installmentLine : [
                    SELECT Id, Fee_Assignment_Line_Item__c, Fee_Installment__c
                    FROM Fee_Installment_Line_Item__c
                    WHERE Fee_Assignment_Line_Item__c IN :assignmentLineItemIds
                    ORDER BY CreatedDate ASC
                ]) {
                    if (
                        installmentLine.Fee_Assignment_Line_Item__c != null
                        && !firstInstallmentLineByAssignmentLineId.containsKey(installmentLine.Fee_Assignment_Line_Item__c)
                    ) {
                        firstInstallmentLineByAssignmentLineId.put(
                            installmentLine.Fee_Assignment_Line_Item__c,
                            installmentLine
                        );
                    }
                }
            }

            for (Fee_Assignment__c assignment : assignments) {
                List<FeeAssignmentLineItemRow> childRows = lineItemsByAssignmentId.containsKey(assignment.Id)
                    ? lineItemsByAssignmentId.get(assignment.Id)
                    : new List<FeeAssignmentLineItemRow>();

                for (FeeAssignmentLineItemRow childRow : childRows) {
                    Fee_Installment_Line_Item__c installmentLine =
                        firstInstallmentLineByAssignmentLineId.get(childRow.id);
                    if (installmentLine != null) {
                        childRow.feeInstallmentId = installmentLine.Fee_Installment__c;
                        childRow.feeInstallmentLineItemId = installmentLine.Id;
                    }
                }

                Decimal assignmentTotal = assignment.Fee_Amount__c != null
                    ? assignment.Fee_Amount__c
                    : (
                        totalFromLineItemsByAssignmentId.containsKey(assignment.Id)
                            ? totalFromLineItemsByAssignmentId.get(assignment.Id)
                            : 0
                    );
                Decimal paidAmount = valueOrZero(assignment.Paid_Amount__c);
                Decimal totalPayable = assignment.Total_Amount_Payable_Formula__c != null
                    ? assignment.Total_Amount_Payable_Formula__c
                    : assignmentTotal;
                Decimal remainingAmount = assignment.Remaining_Amount_Formula__c != null
                    ? assignment.Remaining_Amount_Formula__c
                    : Math.max(totalPayable - paidAmount, 0);

                FeeAssignmentRow mappedAssignment = new FeeAssignmentRow();
                mappedAssignment.id = assignment.Id;
                mappedAssignment.accountId = assignment.Account__c;
                mappedAssignment.mode = assignment.Fee_Type__r == null
                    ? null
                    : assignment.Fee_Type__r.Fee_Collection_Frequency__c;
                mappedAssignment.feeItem = String.isBlank(assignment.Fee_Assignment_Name__c)
                    ? assignment.Name
                    : assignment.Fee_Assignment_Name__c;
                mappedAssignment.dueDate = earliestDueDateByAssignmentId.get(assignment.Id);
                mappedAssignment.currencyIsoCode = assignment.CurrencyIsoCode;
                mappedAssignment.totalAmount = assignmentTotal;
                mappedAssignment.tax = 0;
                mappedAssignment.tds = 0;
                mappedAssignment.totalPayable = totalPayable;
                mappedAssignment.paidAmount = totalPayable - remainingAmount;
                mappedAssignment.description = 'Fee details from Fee Assignment.';
                mappedAssignment.lineItems = childRows;

                responseRows.add(mappedAssignment);
            }

            return responseRows;
        } catch (Exception e) {
            throw new AuraHandledException(
                'PortalFeePaymentController.getCurrentUserPortalPlanAssignments failed: '
                + e.getTypeName()
                + ' | '
                + e.getMessage()
                + ' | line '
                + e.getLineNumber()
            );
        }
    }

    private static CurrentUserContext resolveCurrentUserContext() {
        CurrentUserContext userContext = new CurrentUserContext();
        User currentUser = [
            SELECT AccountId, ContactId, Email
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        userContext.accountId = currentUser.AccountId;
        userContext.contactId = currentUser.ContactId;

        if (userContext.accountId == null && userContext.contactId != null) {
            List<Contact> contacts = [
                SELECT AccountId
                FROM Contact
                WHERE Id = :userContext.contactId
                LIMIT 1
            ];
            if (!contacts.isEmpty()) {
                userContext.accountId = contacts[0].AccountId;
            }
        }

        if (userContext.contactId == null && userContext.accountId != null) {
            List<Account> accounts = [
                SELECT PersonContactId
                FROM Account
                WHERE Id = :userContext.accountId
                LIMIT 1
            ];
            if (!accounts.isEmpty()) {
                userContext.contactId = accounts[0].PersonContactId;
            }
        }

        if (userContext.contactId == null && !String.isBlank(currentUser.Email)) {
            List<Contact> contactsByEmail = [
                SELECT Id, AccountId
                FROM Contact
                WHERE Email = :currentUser.Email
                LIMIT 1
            ];
            if (!contactsByEmail.isEmpty()) {
                userContext.contactId = contactsByEmail[0].Id;
                if (userContext.accountId == null) {
                    userContext.accountId = contactsByEmail[0].AccountId;
                }
            }
        }

        return userContext;
    }

    private static Id resolveCurrentUserAccountId() {
        User currentUser = [
            SELECT AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        return currentUser.AccountId;
    }

    private static String buildInstallmentLabel(Decimal installmentNumber, Integer fallbackIndex) {
        if (installmentNumber == null) {
            return 'Installment ' + String.valueOf(fallbackIndex);
        }

        String installmentNumberText = String.valueOf(installmentNumber);
        if (installmentNumberText.endsWith('.0')) {
            installmentNumberText = installmentNumberText.substring(0, installmentNumberText.length() - 2);
        }
        return 'Installment ' + installmentNumberText;
    }

    private static String deriveStatusLabel(Decimal totalPayable, Decimal paidAmount) {
        Decimal payable = valueOrZero(totalPayable);
        Decimal paid = valueOrZero(paidAmount);
        Decimal remaining = Math.max(payable - paid, 0);

        if (remaining == 0) {
            return 'Fully Paid';
        }
        if (paid > 0) {
            return 'Partially Paid';
        }
        return 'Pending';
    }

    private static Decimal valueOrZero(Decimal value) {
        return value == null ? 0 : value;
    }
}