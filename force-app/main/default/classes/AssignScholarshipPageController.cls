public with sharing class AssignScholarshipPageController {
    public class ScholarshipOptionRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String type;
        @AuraEnabled public String mode;
        @AuraEnabled public String value;
        @AuraEnabled public String scope;
        @AuraEnabled public String approvalRequired;
        @AuraEnabled public String allowsOverride;
    }

    public class PersonAccountRow {
        @AuraEnabled public Id id;
        @AuraEnabled public Id personContactId;
        @AuraEnabled public String name;
        @AuraEnabled public String programme;
        @AuraEnabled public String batch;
        @AuraEnabled public String studentId;
    }

    public class SelectionOptionRow {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class FeeAssignmentLineItemRow {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        @AuraEnabled public Id feeAssignmentId;
        @AuraEnabled public String feeAssignmentName;
        @AuraEnabled public Id feeHeadId;
        @AuraEnabled public String feeHeadName;
        @AuraEnabled public String studentCategory;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Decimal totalAmount;
    }

    public class FeeAssignmentLineItemData {
        @AuraEnabled public List<SelectionOptionRow> feeHeadOptions;
        @AuraEnabled public List<FeeAssignmentLineItemRow> lineItems;
    }

    public class ApplyScholarshipResult {
        @AuraEnabled public Integer createdCount;
        @AuraEnabled public Integer feeAssignmentCount;
        @AuraEnabled public String message;
    }

    public class ScholarshipAssignmentDashboardRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String studentName;
        @AuraEnabled public String programme;
        @AuraEnabled public String scholarshipName;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime appliedDate;
        @AuraEnabled public Decimal feeImpact;
    }

    public class ScholarshipAssignmentDashboardData {
        @AuraEnabled public Integer totalScholarshipsAssigned;
        @AuraEnabled public Integer activeScholarships;
        @AuraEnabled public Integer inactiveScholarships;
        @AuraEnabled public Decimal totalFinancialImpact;
        @AuraEnabled public List<ScholarshipAssignmentDashboardRow> rows;
    }

    private class StudentLookupKeys {
        public Set<Id> accountIds = new Set<Id>();
        public Set<Id> contactIds = new Set<Id>();
    }

    @AuraEnabled(cacheable=true)
    public static List<ScholarshipOptionRow> getScholarshipOptions() {
        List<ScholarshipOptionRow> rows = new List<ScholarshipOptionRow>();

        for (Ken_Scholarship_Discount__c scholarship : [
            SELECT Id, Name, Type__c, Calculation_Type__c, Value_Type__c, Fixed_Value__c, Range_Start_Value__c, Range_End_Value__c
            FROM Ken_Scholarship_Discount__c
            ORDER BY LastModifiedDate DESC
            LIMIT 500
        ]) {
            ScholarshipOptionRow row = new ScholarshipOptionRow();
            row.id = scholarship.Id;
            row.name = scholarship.Name;
            row.type = scholarship.Type__c;
            row.mode = scholarship.Calculation_Type__c;
            row.value = buildValueDisplay(
                scholarship.Value_Type__c,
                scholarship.Calculation_Type__c,
                scholarship.Fixed_Value__c,
                scholarship.Range_Start_Value__c,
                scholarship.Range_End_Value__c
            );
            row.scope = isRangeValueType(scholarship.Value_Type__c) ? 'Selected Heads' : 'Entire Plan';
            row.approvalRequired = isRangeValueType(scholarship.Value_Type__c) ? 'Yes' : 'No';
            row.allowsOverride = 'Yes';
            rows.add(row);
        }

        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static ScholarshipAssignmentDashboardData getScholarshipAssignmentsData() {
        ScholarshipAssignmentDashboardData data = new ScholarshipAssignmentDashboardData();
        data.totalScholarshipsAssigned = 0;
        data.activeScholarships = 0;
        data.inactiveScholarships = 0;
        data.totalFinancialImpact = 0;
        data.rows = new List<ScholarshipAssignmentDashboardRow>();

        for (Applied_Scholarship_Discount__c appliedRecord : [
            SELECT
                Id,
                Is_Active__c,
                CreatedDate,
                Fee_Assignment__r.Application__r.Contact.Name,
                Fee_Assignment__r.Application__r.Learning_Program_Plan__r.Name,
                Fee_Assignment_Line_Item__r.Amount__c,
                Scholarship_Discount__r.Name,
                Scholarship_Discount__r.Calculation_Type__c,
                Scholarship_Discount__r.Value_Type__c,
                Scholarship_Discount__r.Fixed_Value__c
            FROM Applied_Scholarship_Discount__c
            ORDER BY CreatedDate DESC
            LIMIT 2000
        ]) {
            ScholarshipAssignmentDashboardRow row = new ScholarshipAssignmentDashboardRow();
            row.id = appliedRecord.Id;
            row.studentName = appliedRecord.Fee_Assignment__r == null
                || appliedRecord.Fee_Assignment__r.Application__r == null
                || appliedRecord.Fee_Assignment__r.Application__r.Contact == null
                ? '--'
                : appliedRecord.Fee_Assignment__r.Application__r.Contact.Name;
            row.programme = appliedRecord.Fee_Assignment__r == null
                || appliedRecord.Fee_Assignment__r.Application__r == null
                || appliedRecord.Fee_Assignment__r.Application__r.Learning_Program_Plan__r == null
                ? '--'
                : appliedRecord.Fee_Assignment__r.Application__r.Learning_Program_Plan__r.Name;
            row.scholarshipName = appliedRecord.Scholarship_Discount__r == null
                ? '--'
                : appliedRecord.Scholarship_Discount__r.Name;
            row.status = appliedRecord.Is_Active__c ? 'Active' : 'InActive';
            row.appliedDate = appliedRecord.CreatedDate;
            row.feeImpact = calculateScholarshipFeeImpact(appliedRecord);

            data.rows.add(row);
            data.totalScholarshipsAssigned++;
            if (appliedRecord.Is_Active__c) {
                data.activeScholarships++;
            } else {
                data.inactiveScholarships++;
            }
            if (row.feeImpact != null) {
                data.totalFinancialImpact += row.feeImpact;
            }
        }

        return data;
    }

    @AuraEnabled(cacheable=true)
    public static List<PersonAccountRow> searchPersonAccounts(String searchTerm) {
        String normalizedSearchTerm = String.isBlank(searchTerm) ? null : searchTerm.trim();
        if (String.isBlank(normalizedSearchTerm)) {
            return new List<PersonAccountRow>();
        }

        String likeSearchTerm = '%' + normalizedSearchTerm + '%';
        List<Account> personAccounts = [
            SELECT Id, Name, PersonContactId, PersonEmail, PersonMobilePhone
            FROM Account
            WHERE IsPersonAccount = true
            AND (
                Name LIKE :likeSearchTerm
                OR PersonEmail LIKE :likeSearchTerm
                OR PersonMobilePhone LIKE :likeSearchTerm
            )
            ORDER BY LastModifiedDate DESC
            LIMIT 20
        ];

        if (personAccounts.isEmpty() && isPotentialSalesforceId(normalizedSearchTerm)) {
            Id searchId = toIdValue(normalizedSearchTerm);
            if (searchId != null) {
                String idPrefix = String.valueOf(searchId).left(3);
                if (idPrefix == '001') {
                    personAccounts = [
                        SELECT Id, Name, PersonContactId, PersonEmail, PersonMobilePhone
                        FROM Account
                        WHERE IsPersonAccount = true
                        AND Id = :searchId
                        LIMIT 1
                    ];
                } else if (idPrefix == '003') {
                    personAccounts = [
                        SELECT Id, Name, PersonContactId, PersonEmail, PersonMobilePhone
                        FROM Account
                        WHERE IsPersonAccount = true
                        AND PersonContactId = :searchId
                        LIMIT 1
                    ];
                }
            }
        }

        Set<Id> personAccountIds = new Set<Id>();
        for (Account accountRow : personAccounts) {
            personAccountIds.add(accountRow.Id);
        }

        Map<Id, Fee_Assignment__c> latestFeeAssignmentByAccountId = new Map<Id, Fee_Assignment__c>();
        if (!personAccountIds.isEmpty()) {
            for (Fee_Assignment__c feeAssignment : [
                SELECT
                    Id,
                    Account__c,
                    Fee_Type__r.Batch__c,
                    Fee_Type__r.Learning_Program_Plan__r.LearningProgram.Name
                FROM Fee_Assignment__c
                WHERE Account__c IN :personAccountIds
                ORDER BY LastModifiedDate DESC
            ]) {
                if (!latestFeeAssignmentByAccountId.containsKey(feeAssignment.Account__c)) {
                    latestFeeAssignmentByAccountId.put(feeAssignment.Account__c, feeAssignment);
                }
            }
        }

        List<PersonAccountRow> rows = new List<PersonAccountRow>();
        for (Account accountRow : personAccounts) {
            Fee_Assignment__c latestFeeAssignment = latestFeeAssignmentByAccountId.get(accountRow.Id);

            PersonAccountRow row = new PersonAccountRow();
            row.id = accountRow.Id;
            row.personContactId = accountRow.PersonContactId;
            row.name = accountRow.Name;
            row.programme = latestFeeAssignment == null
                || latestFeeAssignment.Fee_Type__r == null
                || latestFeeAssignment.Fee_Type__r.Learning_Program_Plan__r == null
                || latestFeeAssignment.Fee_Type__r.Learning_Program_Plan__r.LearningProgram == null
                ? '--'
                : latestFeeAssignment.Fee_Type__r.Learning_Program_Plan__r.LearningProgram.Name;
            row.batch = latestFeeAssignment == null || latestFeeAssignment.Fee_Type__r == null
                ? '--'
                : String.valueOf(latestFeeAssignment.Fee_Type__r.Batch__c);
            row.studentId = accountRow.PersonContactId == null
                ? String.valueOf(accountRow.Id)
                : String.valueOf(accountRow.PersonContactId);
            rows.add(row);
        }

        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<SelectionOptionRow> getProgramOptionsForStudent(Id personAccountId) {
        List<SelectionOptionRow> options = new List<SelectionOptionRow>();
        if (personAccountId == null) {
            return options;
        }

        StudentLookupKeys studentKeys = resolveStudentLookupKeys(personAccountId);
        if (studentKeys.accountIds.isEmpty() && studentKeys.contactIds.isEmpty()) {
            return options;
        }

        Set<Id> learningProgramPlanIds = new Set<Id>();
        for (IndividualApplication applicationRow : [
            SELECT Learning_Program_Plan__c, Learning_Program_Plan__r.Name
            FROM IndividualApplication
            WHERE (
                AccountId IN :studentKeys.accountIds
                OR ContactId IN :studentKeys.contactIds
            )
            AND Learning_Program_Plan__c != null
            LIMIT 2000
        ]) {
            Id planId = (Id) applicationRow.get('Learning_Program_Plan__c');
            if (planId == null || learningProgramPlanIds.contains(planId)) {
                continue;
            }
            learningProgramPlanIds.add(planId);

            SelectionOptionRow option = new SelectionOptionRow();
            option.label = applicationRow.getSObject('Learning_Program_Plan__r') == null
                ? String.valueOf(planId)
                : String.valueOf(applicationRow.getSObject('Learning_Program_Plan__r').get('Name'));
            option.value = planId;
            options.add(option);
        } 

        return options;
    }

    @AuraEnabled(cacheable=true)
    public static FeeAssignmentLineItemData getFeeAssignmentLineItemData(
        Id personAccountId,
        Id personContactId,
        Id learningProgramPlanId,
        Id feeHeadId
    ) {
        FeeAssignmentLineItemData data = new FeeAssignmentLineItemData();
        data.feeHeadOptions = new List<SelectionOptionRow>();
        data.lineItems = new List<FeeAssignmentLineItemRow>();

        if ((personAccountId == null && personContactId == null) || learningProgramPlanId == null) {
            return data;
        }

        for (Ken_Master_Fee_Head__c feeHeadRow : [
            SELECT Id, Name, Fee_Head_Name__c
            FROM Ken_Master_Fee_Head__c
            ORDER BY Fee_Head_Name__c ASC, Name ASC
        ]) {
            SelectionOptionRow feeHeadOption = new SelectionOptionRow();
            feeHeadOption.value = feeHeadRow.Id;
            feeHeadOption.label = String.isBlank(feeHeadRow.Fee_Head_Name__c)
                ? feeHeadRow.Name
                : feeHeadRow.Fee_Head_Name__c;
            data.feeHeadOptions.add(feeHeadOption);
        }

        List<Fee_Assignment_Line_Item__c> lineItems;
        if (personContactId == null) {
            if (feeHeadId == null) {
                lineItems = [
                    SELECT
                        Id,
                        Fee_Assignment__c,
                        Fee_Assignment__r.Name,
                        Individual_Application__r.AccountId,
                        Individual_Application__r.ContactId,
                        Fee_Head__c,
                        Fee_Head__r.Name,
                        Fee_Head__r.Fee_Head_Name__c,
                        Fee_Type_Line_Item__c,
                        Fee_Type_Line_Item__r.Ken_Fee_Type__r.Learning_Program_Plan__c,
                        Fee_Type_Line_Item__r.Fee_Head__c,
                        Fee_Type_Line_Item__r.Fee_Head__r.Name,
                        Fee_Type_Line_Item__r.Fee_Head__r.Fee_Head_Name__c,
                        Student_Category__c, 
                        Amount__c,
                        Total_Amount__c
                    FROM Fee_Assignment_Line_Item__c
                    WHERE Fee_Type_Line_Item__r.Ken_Fee_Type__r.Learning_Program_Plan__c = :learningProgramPlanId
                    AND Individual_Application__r.AccountId = :personAccountId
                    ORDER BY Fee_Assignment__r.Name ASC, CreatedDate DESC
                    LIMIT 2000
                ];
            } else {
                lineItems = [
                    SELECT
                        Id,
                        Fee_Assignment__c,
                        Fee_Assignment__r.Name,
                        Individual_Application__r.AccountId,
                        Individual_Application__r.ContactId,
                        Fee_Head__c,
                        Fee_Head__r.Name,
                        Fee_Head__r.Fee_Head_Name__c,
                        Fee_Type_Line_Item__c,
                        Fee_Type_Line_Item__r.Ken_Fee_Type__r.Learning_Program_Plan__c,
                        Fee_Type_Line_Item__r.Fee_Head__c,
                        Fee_Type_Line_Item__r.Fee_Head__r.Name,
                        Fee_Type_Line_Item__r.Fee_Head__r.Fee_Head_Name__c,
                        Student_Category__c,
                        Amount__c,
                        Total_Amount__c
                    FROM Fee_Assignment_Line_Item__c
                    WHERE Fee_Type_Line_Item__r.Ken_Fee_Type__r.Learning_Program_Plan__c = :learningProgramPlanId
                    AND Individual_Application__r.AccountId = :personAccountId
                    AND Fee_Type_Line_Item__r.Fee_Head__c = :feeHeadId
                    ORDER BY Fee_Assignment__r.Name ASC, CreatedDate DESC
                    LIMIT 2000
                ];
            }
        } else {
            if (feeHeadId == null) {
                lineItems = [
                    SELECT
                        Id,
                        Fee_Assignment__c,
                        Fee_Assignment__r.Name,
                        Individual_Application__r.AccountId,
                        Individual_Application__r.ContactId,
                        Fee_Head__c,
                        Fee_Head__r.Name,
                        Fee_Head__r.Fee_Head_Name__c,
                        Fee_Type_Line_Item__c,
                        Fee_Type_Line_Item__r.Ken_Fee_Type__r.Learning_Program_Plan__c,
                        Fee_Type_Line_Item__r.Fee_Head__c,
                        Fee_Type_Line_Item__r.Fee_Head__r.Name,
                        Fee_Type_Line_Item__r.Fee_Head__r.Fee_Head_Name__c,
                        Student_Category__c,
                        Amount__c,
                        Total_Amount__c
                    FROM Fee_Assignment_Line_Item__c
                    WHERE Fee_Type_Line_Item__r.Ken_Fee_Type__r.Learning_Program_Plan__c = :learningProgramPlanId
                    AND (
                        Individual_Application__r.AccountId = :personAccountId
                        OR Individual_Application__r.ContactId = :personContactId
                    )
                    ORDER BY Fee_Assignment__r.Name ASC, CreatedDate DESC
                    LIMIT 2000
                ];
            } else {
                lineItems = [
                    SELECT
                        Id,
                        Fee_Assignment__c,
                        Fee_Assignment__r.Name,
                        Individual_Application__r.AccountId,
                        Individual_Application__r.ContactId,
                        Fee_Head__c,
                        Fee_Head__r.Name,
                        Fee_Head__r.Fee_Head_Name__c,
                        Fee_Type_Line_Item__c,
                        Fee_Type_Line_Item__r.Ken_Fee_Type__r.Learning_Program_Plan__c,
                        Fee_Type_Line_Item__r.Fee_Head__c,
                        Fee_Type_Line_Item__r.Fee_Head__r.Name,
                        Fee_Type_Line_Item__r.Fee_Head__r.Fee_Head_Name__c,
                        Student_Category__c,
                        Amount__c,
                        Total_Amount__c
                    FROM Fee_Assignment_Line_Item__c
                    WHERE Fee_Type_Line_Item__r.Ken_Fee_Type__r.Learning_Program_Plan__c = :learningProgramPlanId
                    AND (
                        Individual_Application__r.AccountId = :personAccountId
                        OR Individual_Application__r.ContactId = :personContactId
                    )
                    AND Fee_Type_Line_Item__r.Fee_Head__c = :feeHeadId
                    ORDER BY Fee_Assignment__r.Name ASC, CreatedDate DESC
                    LIMIT 2000
                ];
            }
        }

        for (Fee_Assignment_Line_Item__c lineItem : lineItems) {
            Id resolvedFeeHeadId = resolveFeeHeadId(lineItem);
            String resolvedFeeHeadName = resolveFeeHeadName(lineItem, resolvedFeeHeadId);

            FeeAssignmentLineItemRow mappedRow = new FeeAssignmentLineItemRow();
            mappedRow.value = lineItem.Id;
            mappedRow.feeAssignmentId = lineItem.Fee_Assignment__c;
            mappedRow.feeAssignmentName = lineItem.Fee_Assignment__r == null
                ? String.valueOf(lineItem.Fee_Assignment__c)
                : lineItem.Fee_Assignment__r.Name;
            mappedRow.feeHeadId = resolvedFeeHeadId;
            mappedRow.feeHeadName = resolvedFeeHeadName;
            mappedRow.studentCategory = lineItem.Student_Category__c;
            mappedRow.amount = lineItem.Amount__c;
            mappedRow.totalAmount = lineItem.Total_Amount__c;
            mappedRow.label = buildLineItemLabel(mappedRow);
            data.lineItems.add(mappedRow);
        }

        return data;
    }

    @AuraEnabled
    public static ApplyScholarshipResult applyScholarship(
        Id scholarshipId,
        Id personAccountId,
        Id feeAssignmentLineItemId,
        Date effectiveDate,
        Date expiryDate,
        String notes
    ) {
        if (scholarshipId == null) {
            throw new AuraHandledException('Scholarship is required.');
        }
        if (personAccountId == null) {
            throw new AuraHandledException('Student is required.');
        }
        if (feeAssignmentLineItemId == null) {
            throw new AuraHandledException('Fee Assignment Line Item is required.');
        }
        if (effectiveDate == null) {
            throw new AuraHandledException('Effective Date is required.');
        }
        if (expiryDate != null && expiryDate < effectiveDate) {
            throw new AuraHandledException('Expiry Date cannot be before Effective Date.');
        }

        Fee_Assignment_Line_Item__c selectedLineItem = [
            SELECT
                Id,
                Amount__c,
                Fee_Assignment__c,
                Fee_Assignment__r.Account__c,
                Fee_Assignment__r.Application__r.AccountId,
                Fee_Assignment__r.Application__r.ContactId
            FROM Fee_Assignment_Line_Item__c
            WHERE Id = :feeAssignmentLineItemId
            LIMIT 1
        ];

        Ken_Scholarship_Discount__c selectedScholarshipDiscount = [
            SELECT Calculation_Type__c, Value_Type__c, Fixed_Value__c
            FROM Ken_Scholarship_Discount__c
            WHERE Id = :scholarshipId
            LIMIT 1
        ];

        StudentLookupKeys studentKeys = resolveStudentLookupKeys(personAccountId);
        Id assignmentAccountId = selectedLineItem.Fee_Assignment__r == null
            ? null
            : selectedLineItem.Fee_Assignment__r.Account__c;
        Id applicationAccountId = selectedLineItem.Fee_Assignment__r == null
            || selectedLineItem.Fee_Assignment__r.Application__r == null
            ? null
            : selectedLineItem.Fee_Assignment__r.Application__r.AccountId;
        Id applicationContactId = selectedLineItem.Fee_Assignment__r == null
            || selectedLineItem.Fee_Assignment__r.Application__r == null
            ? null
            : selectedLineItem.Fee_Assignment__r.Application__r.ContactId;
        Boolean isStudentMatch =
            studentKeys.accountIds.contains(assignmentAccountId)
            || studentKeys.accountIds.contains(applicationAccountId)
            || studentKeys.contactIds.contains(applicationContactId);
        if (!isStudentMatch) {
            throw new AuraHandledException('Selected Fee Assignment Line Item does not belong to the chosen student.');
        }

        Applied_Scholarship_Discount__c appliedRecord = new Applied_Scholarship_Discount__c();
        appliedRecord.Fee_Assignment__c = selectedLineItem.Fee_Assignment__c;
        appliedRecord.Fee_Assignment_Line_Item__c = selectedLineItem.Id;
        appliedRecord.Scholarship_Discount__c = scholarshipId;
        appliedRecord.Is_Active__c = true;
        appliedRecord.Effective_Date__c = effectiveDate;
        appliedRecord.Expiry_Date__c = expiryDate;
        appliedRecord.Notes__c = notes;
        insert appliedRecord;

        Payment_Transaction__c paymentTransaction = new Payment_Transaction__c();
        Id paymentTransactionAccountId = assignmentAccountId != null
            ? assignmentAccountId
            : applicationAccountId;
        if (paymentTransactionAccountId == null) {
            paymentTransactionAccountId = personAccountId;
        }
        paymentTransaction.Account__c = paymentTransactionAccountId;
        paymentTransaction.Amount__c = calculateScholarshipDeductionAmount(
            selectedLineItem.Amount__c,
            selectedScholarshipDiscount.Calculation_Type__c,
            selectedScholarshipDiscount.Value_Type__c,
            selectedScholarshipDiscount.Fixed_Value__c
        );
        setScholarshipDiscountOnPaymentTransaction(paymentTransaction, scholarshipId);
        setScholarshipTransactionType(paymentTransaction);
        insert paymentTransaction;

        Payment_Transaction_Line_Item__c paymentTransactionLineItem = new Payment_Transaction_Line_Item__c();
        paymentTransactionLineItem.Payment_Transaction__c = paymentTransaction.Id;
        paymentTransactionLineItem.Fee_Assignment__c = selectedLineItem.Fee_Assignment__c;
        insert paymentTransactionLineItem;

        ApplyScholarshipResult result = new ApplyScholarshipResult();
        result.createdCount = 1;
        result.feeAssignmentCount = 1;
        result.message = 'Applied scholarship and created related payment transaction.';
        return result;
    }

    private static void setScholarshipTransactionType(Payment_Transaction__c paymentTransaction) {
        Map<String, Schema.SObjectField> paymentTransactionFieldMap =
            Payment_Transaction__c.SObjectType.getDescribe().fields.getMap();

        if (!paymentTransactionFieldMap.containsKey('Transaction_Type__c')) {
            throw new AuraHandledException(
                'Payment Transaction field Transaction_Type__c is not available.'
            );
        }

        paymentTransaction.put('Transaction_Type__c', 'Scholarship');
    }

    private static void setScholarshipDiscountOnPaymentTransaction(
        Payment_Transaction__c paymentTransaction,
        Id scholarshipDiscountId
    ) {
        Map<String, Schema.SObjectField> paymentTransactionFieldMap =
            Payment_Transaction__c.SObjectType.getDescribe().fields.getMap();

        if (!paymentTransactionFieldMap.containsKey('Scholarship_Discount__c')) {
            throw new AuraHandledException(
                'Payment Transaction field Scholarship_Discount__c is not available.'
            );
        }

        paymentTransaction.put('Scholarship_Discount__c', scholarshipDiscountId);
    }

    private static Decimal calculateScholarshipFeeImpact(Applied_Scholarship_Discount__c appliedRecord) {
        if (
            appliedRecord == null
            || appliedRecord.Scholarship_Discount__r == null
            || appliedRecord.Fee_Assignment_Line_Item__r == null
        ) {
            return null;
        }

        return calculateScholarshipFeeImpactAmount(
            appliedRecord.Fee_Assignment_Line_Item__r.Amount__c,
            appliedRecord.Scholarship_Discount__r.Calculation_Type__c,
            appliedRecord.Scholarship_Discount__r.Value_Type__c,
            appliedRecord.Scholarship_Discount__r.Fixed_Value__c
        );
    }

    private static Decimal calculateScholarshipFeeImpactAmount(
        Decimal lineItemAmount,
        String calculationType,
        String valueType,
        Decimal fixedValue
    ) {
        if (lineItemAmount == null || fixedValue == null) {
            return null;
        }

        String normalizedCalculationType = String.isBlank(calculationType)
            ? ''
            : calculationType.trim().toLowerCase();
        String normalizedValueType = String.isBlank(valueType)
            ? ''
            : valueType.trim().toLowerCase();

        if (!normalizedValueType.contains('fixed')) {
            return null;
        }

        if (normalizedCalculationType.contains('abosolute') || normalizedCalculationType.contains('absolute')) {
            return lineItemAmount - fixedValue;
        }
        if (normalizedCalculationType.contains('percentage')) {
            return (lineItemAmount * fixedValue) / 100;
        }

        return null;
    }

    private static Decimal calculateScholarshipDeductionAmount(
        Decimal lineItemAmount,
        String calculationType,
        String valueType,
        Decimal fixedValue
    ) {
        if (lineItemAmount == null || fixedValue == null) {
            return null;
        }

        String normalizedCalculationType = String.isBlank(calculationType)
            ? ''
            : calculationType.trim().toLowerCase();
        String normalizedValueType = String.isBlank(valueType)
            ? ''
            : valueType.trim().toLowerCase();

        if (!normalizedValueType.contains('fixed')) {
            return null;
        }

        if (normalizedCalculationType.contains('abosolute') || normalizedCalculationType.contains('absolute')) {
            return fixedValue;
        }
        if (normalizedCalculationType.contains('percentage')) {
            return (lineItemAmount * fixedValue) / 100;
        }

        return null;
    }

    private static Id resolveFeeHeadId(Fee_Assignment_Line_Item__c lineItem) {
        if (lineItem == null) {
            return null;
        }
        if (
            lineItem.Fee_Type_Line_Item__r != null &&
            lineItem.Fee_Type_Line_Item__r.Fee_Head__c != null
        ) {
            return lineItem.Fee_Type_Line_Item__r.Fee_Head__c;
        }
        return lineItem.Fee_Head__c;
    }

    private static String resolveFeeHeadName(Fee_Assignment_Line_Item__c lineItem, Id resolvedFeeHeadId) {
        if (lineItem == null) {
            return '-';
        }
        if (
            lineItem.Fee_Type_Line_Item__r != null &&
            lineItem.Fee_Type_Line_Item__r.Fee_Head__r != null
        ) {
            String feeHeadName = lineItem.Fee_Type_Line_Item__r.Fee_Head__r.Fee_Head_Name__c;
            if (String.isBlank(feeHeadName)) {
                feeHeadName = lineItem.Fee_Type_Line_Item__r.Fee_Head__r.Name;
            }
            if (!String.isBlank(feeHeadName)) {
                return feeHeadName;
            }
        }
        if (lineItem.Fee_Head__r != null) {
            String feeHeadName = lineItem.Fee_Head__r.Fee_Head_Name__c;
            if (String.isBlank(feeHeadName)) {
                feeHeadName = lineItem.Fee_Head__r.Name;
            }
            if (!String.isBlank(feeHeadName)) {
                return feeHeadName;
            }
        }
        return resolvedFeeHeadId == null ? '-' : String.valueOf(resolvedFeeHeadId);
    }

    private static String buildLineItemLabel(FeeAssignmentLineItemRow lineItem) {
        String assignmentName = String.isBlank(lineItem.feeAssignmentName) ? '-' : lineItem.feeAssignmentName;
        String feeHeadName = String.isBlank(lineItem.feeHeadName) ? '-' : lineItem.feeHeadName;
        String amountDisplay = lineItem.amount == null ? '-' : formatCurrency(lineItem.amount);
        return assignmentName + ' | ' + feeHeadName + ' | ' + amountDisplay;
    }

    private static Boolean isRangeValueType(String valueType) {
        return !String.isBlank(valueType) && valueType.toLowerCase().contains('range');
    }

    private static String buildValueDisplay(
        String valueType,
        String calculationType,
        Decimal fixedValue,
        Decimal rangeStartValue,
        Decimal rangeEndValue
    ) {
        if (isRangeValueType(valueType)) {
            return formatCurrency(rangeStartValue) + ' - ' + formatCurrency(rangeEndValue);
        }

        if (!String.isBlank(calculationType) && calculationType.toLowerCase().contains('percentage')) {
            return fixedValue == null ? '--' : String.valueOf(fixedValue) + '%';
        }

        return formatCurrency(fixedValue);
    }

    private static String formatCurrency(Decimal amountValue) {
        return amountValue == null ? '--' : 'INR ' + String.valueOf(amountValue.setScale(2));
    }

    private static Boolean isPotentialSalesforceId(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        Integer lengthValue = value.length();
        return lengthValue == 15 || lengthValue == 18;
    }

    private static Id toIdValue(String value) {
        if (!isPotentialSalesforceId(value)) {
            return null;
        }
        try {
            return (Id) value;
        } catch (Exception ex) {
            return null;
        }
    }

    private static StudentLookupKeys resolveStudentLookupKeys(Id personAccountOrContactId) {
        StudentLookupKeys keys = new StudentLookupKeys();
        if (personAccountOrContactId == null) {
            return keys;
        }

        String idPrefix = String.valueOf(personAccountOrContactId).left(3);
        if (idPrefix == '001') {
            keys.accountIds.add(personAccountOrContactId);
            for (Account accountRow : [
                SELECT PersonContactId
                FROM Account
                WHERE Id = :personAccountOrContactId
                LIMIT 1
            ]) {
                if (accountRow.PersonContactId != null) {
                    keys.contactIds.add(accountRow.PersonContactId);
                }
            }
            return keys;
        }

        if (idPrefix == '003') {
            keys.contactIds.add(personAccountOrContactId);
            for (Contact contactRow : [
                SELECT AccountId
                FROM Contact
                WHERE Id = :personAccountOrContactId
                LIMIT 1
            ]) {
                if (contactRow.AccountId != null) {
                    keys.accountIds.add(contactRow.AccountId);
                }
            }
            return keys;
        }

        keys.accountIds.add(personAccountOrContactId);
        keys.contactIds.add(personAccountOrContactId);
        return keys;
    }
}