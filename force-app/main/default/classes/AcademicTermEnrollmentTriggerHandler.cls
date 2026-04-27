public with sharing class AcademicTermEnrollmentTriggerHandler {
    private static final String TERM_ENROLLMENT_TRIGGER_POINT = 'Term Enrollment';

    public static void createFeeAssignmentsForEnrollments(List<AcademicTermEnrollment> enrollments) {
        if (enrollments == null || enrollments.isEmpty()) {
            return;
        }

        Set<Id> contactIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        Set<Id> academicTermIds = new Set<Id>();
        for (AcademicTermEnrollment enrollment : enrollments) {
            if (enrollment == null) {
                continue;
            }
            if (enrollment.LearnerContactId != null) {
                contactIds.add(enrollment.LearnerContactId);
            }
            if (enrollment.LearnerAccountId != null) {
                accountIds.add(enrollment.LearnerAccountId);
            }
            if (enrollment.AcademicTermId != null) {
                academicTermIds.add(enrollment.AcademicTermId);
            }
        }
        if (contactIds.isEmpty() || accountIds.isEmpty()) {
            return;
        }

        Map<Id, Set<Id>> learningProgramPlanIdsByContactId = new Map<Id, Set<Id>>();
        Set<Id> learningProgramPlanIds = new Set<Id>();
        for (LearnerProgram learnerProgram : [
            SELECT Id, LearnerContactId, LearningProgramPlanId
            FROM LearnerProgram
            WHERE LearnerContactId IN :contactIds
            ORDER BY CreatedDate DESC
        ]) {
            if (learnerProgram.LearnerContactId == null || learnerProgram.LearningProgramPlanId == null) {
                continue;
            }
            if (!learningProgramPlanIdsByContactId.containsKey(learnerProgram.LearnerContactId)) {
                learningProgramPlanIdsByContactId.put(learnerProgram.LearnerContactId, new Set<Id>());
            }
            learningProgramPlanIdsByContactId.get(learnerProgram.LearnerContactId).add(
                learnerProgram.LearningProgramPlanId
            );
            learningProgramPlanIds.add(learnerProgram.LearningProgramPlanId);
        }
        if (learningProgramPlanIds.isEmpty()) {
            return;
        }

        Map<Id, AcademicTerm> academicTermById = new Map<Id, AcademicTerm>();
        if (!academicTermIds.isEmpty()) {
            academicTermById = new Map<Id, AcademicTerm>([
                SELECT Id, Name
                FROM AcademicTerm
                WHERE Id IN :academicTermIds
            ]);
        }

        Map<Id, List<Ken_Fee_Type_Line_Item__c>> eligibleFeeTypeLinesByFeeTypeId = new Map<Id, List<Ken_Fee_Type_Line_Item__c>>();
        Map<Id, List<Ken_Fee_Type_Line_Item__c>> fallbackFeeTypeLinesByFeeTypeId = new Map<Id, List<Ken_Fee_Type_Line_Item__c>>();
        Map<Id, Ken_Fee_Type__c> feeTypeById = new Map<Id, Ken_Fee_Type__c>();
        for (Ken_Fee_Type_Line_Item__c feeTypeLine : [
            SELECT
                Id,
                Ken_Fee_Type__c,
                Fee_Head__c,
                Amount__c,
                Tax__c,
                Fee_Assignment_Trigger_Point__c,
                Is_Active__c,
                Ken_Fee_Type__r.Id,
                Ken_Fee_Type__r.Name,
                Ken_Fee_Type__r.Fee_Type_Name__c,
                Ken_Fee_Type__r.Payment_Schedule__c,
                Ken_Fee_Type__r.Status__c,
                Ken_Fee_Type__r.Learning_Program_Plan__c
            FROM Ken_Fee_Type_Line_Item__c
            WHERE Ken_Fee_Type__r.Learning_Program_Plan__c IN :learningProgramPlanIds
              AND Fee_Assignment_Trigger_Point__c = :TERM_ENROLLMENT_TRIGGER_POINT
            ORDER BY CreatedDate ASC
        ]) {
            if (feeTypeLine.Ken_Fee_Type__c == null) {
                continue;
            }
            if (feeTypeLine.Is_Active__c == true && String.valueOf(feeTypeLine.Ken_Fee_Type__r.Status__c) == 'Active') {
                if (!eligibleFeeTypeLinesByFeeTypeId.containsKey(feeTypeLine.Ken_Fee_Type__c)) {
                    eligibleFeeTypeLinesByFeeTypeId.put(
                        feeTypeLine.Ken_Fee_Type__c,
                        new List<Ken_Fee_Type_Line_Item__c>()
                    );
                }
                eligibleFeeTypeLinesByFeeTypeId.get(feeTypeLine.Ken_Fee_Type__c).add(feeTypeLine);
            } else {
                if (!fallbackFeeTypeLinesByFeeTypeId.containsKey(feeTypeLine.Ken_Fee_Type__c)) {
                    fallbackFeeTypeLinesByFeeTypeId.put(
                        feeTypeLine.Ken_Fee_Type__c,
                        new List<Ken_Fee_Type_Line_Item__c>()
                    );
                }
                fallbackFeeTypeLinesByFeeTypeId.get(feeTypeLine.Ken_Fee_Type__c).add(feeTypeLine);
            }
            if (!feeTypeById.containsKey(feeTypeLine.Ken_Fee_Type__c)) {
                feeTypeById.put(feeTypeLine.Ken_Fee_Type__c, feeTypeLine.Ken_Fee_Type__r);
            }
        }
        Map<Id, List<Ken_Fee_Type_Line_Item__c>> feeTypeLinesByFeeTypeId = new Map<Id, List<Ken_Fee_Type_Line_Item__c>>();
        Set<Id> allFeeTypeIds = new Set<Id>();
        allFeeTypeIds.addAll(eligibleFeeTypeLinesByFeeTypeId.keySet());
        allFeeTypeIds.addAll(fallbackFeeTypeLinesByFeeTypeId.keySet());
        for (Id feeTypeId : allFeeTypeIds) {
            if (eligibleFeeTypeLinesByFeeTypeId.containsKey(feeTypeId)) {
                feeTypeLinesByFeeTypeId.put(feeTypeId, eligibleFeeTypeLinesByFeeTypeId.get(feeTypeId));
            } else if (fallbackFeeTypeLinesByFeeTypeId.containsKey(feeTypeId)) {
                feeTypeLinesByFeeTypeId.put(feeTypeId, fallbackFeeTypeLinesByFeeTypeId.get(feeTypeId));
            }
        }
        if (feeTypeLinesByFeeTypeId.isEmpty()) {
            return;
        }

        Set<String> candidateAssignmentNames = new Set<String>();
        Set<Id> feeTypeIds = feeTypeById.keySet();
        Map<String, AcademicTermEnrollment> enrollmentByKey = new Map<String, AcademicTermEnrollment>();
        for (AcademicTermEnrollment enrollment : enrollments) {
            Set<Id> enrollmentPlanIds = learningProgramPlanIdsByContactId.get(enrollment.LearnerContactId);
            if (enrollmentPlanIds == null || enrollmentPlanIds.isEmpty()) {
                continue;
            }

            for (Id feeTypeId : feeTypeIds) {
                Ken_Fee_Type__c feeType = feeTypeById.get(feeTypeId);
                if (
                    feeType == null
                    || !enrollmentPlanIds.contains(feeType.Learning_Program_Plan__c)
                ) {
                    continue;
                }

                String assignmentName = buildAssignmentName(enrollment, academicTermById.get(enrollment.AcademicTermId), feeType);
                candidateAssignmentNames.add(assignmentName);
                enrollmentByKey.put(String.valueOf(enrollment.Id) + ':' + String.valueOf(feeTypeId), enrollment);
            }
        }
        if (candidateAssignmentNames.isEmpty()) {
            return;
        }

        Set<String> existingAssignmentNames = new Set<String>();
        for (Fee_Assignment__c assignment : [
            SELECT Id, Fee_Assignment_Name__c
            FROM Fee_Assignment__c
            WHERE Account__c IN :accountIds
              AND Fee_Type__c IN :feeTypeIds
              AND Fee_Assignment_Name__c IN :candidateAssignmentNames
        ]) {
            existingAssignmentNames.add(assignment.Fee_Assignment_Name__c);
        }

        List<Fee_Assignment__c> assignmentsToInsert = new List<Fee_Assignment__c>();
        List<String> insertedAssignmentKeys = new List<String>();
        for (AcademicTermEnrollment enrollment : enrollments) {
            Set<Id> enrollmentPlanIds = learningProgramPlanIdsByContactId.get(enrollment.LearnerContactId);
            if (enrollmentPlanIds == null || enrollmentPlanIds.isEmpty()) {
                continue;
            }

            for (Id feeTypeId : feeTypeIds) {
                Ken_Fee_Type__c feeType = feeTypeById.get(feeTypeId);
                if (
                    feeType == null
                    || !enrollmentPlanIds.contains(feeType.Learning_Program_Plan__c)
                ) {
                    continue;
                }

                List<Ken_Fee_Type_Line_Item__c> feeTypeLines = feeTypeLinesByFeeTypeId.get(feeTypeId);
                if (feeTypeLines == null || feeTypeLines.isEmpty()) {
                    continue;
                }

                Decimal totalAmount = 0;
                for (Ken_Fee_Type_Line_Item__c feeTypeLine : feeTypeLines) {
                    totalAmount += feeTypeLine.Amount__c == null ? 0 : feeTypeLine.Amount__c;
                }

                String assignmentName = buildAssignmentName(enrollment, academicTermById.get(enrollment.AcademicTermId), feeType);
                if (existingAssignmentNames.contains(assignmentName)) {
                    continue;
                }

                Fee_Assignment__c assignment = new Fee_Assignment__c(
                    Fee_Assignment_Name__c = assignmentName,
                    Account__c = enrollment.LearnerAccountId,
                    Academic_Term_Enrollment__c = enrollment.Id,
                    Fee_Type__c = feeTypeId,
                    Payment_Schedule__c = feeType.Payment_Schedule__c,
                    Fee_Amount__c = totalAmount,
                    Paid_Amount__c = 0,
                    Status__c = 'Active',
                    Active__c = true
                );
                assignmentsToInsert.add(assignment);
                insertedAssignmentKeys.add(String.valueOf(enrollment.Id) + ':' + String.valueOf(feeTypeId));
                existingAssignmentNames.add(assignmentName);
            }
        }
        if (assignmentsToInsert.isEmpty()) {
            return;
        }

        insert assignmentsToInsert;

        List<Fee_Assignment_Line_Item__c> lineItemsToInsert = new List<Fee_Assignment_Line_Item__c>();
        List<Fee_Installment__c> installmentsToInsert = new List<Fee_Installment__c>();
        List<Id> assignmentIdsInOrder = new List<Id>();
        Map<Id, Integer> installmentCountByAssignmentId = new Map<Id, Integer>();
        Map<Id, List<Payment_Schedule_Instalment__c>> scheduleInstallmentsByFeeTypeId = queryScheduleInstallmentsByFeeTypeId(feeTypeById);

        for (Integer index = 0; index < assignmentsToInsert.size(); index++) {
            Fee_Assignment__c insertedAssignment = assignmentsToInsert[index];
            String key = insertedAssignmentKeys[index];
            AcademicTermEnrollment enrollment = enrollmentByKey.get(key);
            if (enrollment == null) {
                continue;
            }
            Id feeTypeId = insertedAssignment.Fee_Type__c;
            List<Ken_Fee_Type_Line_Item__c> feeTypeLines = feeTypeLinesByFeeTypeId.get(feeTypeId);
            if (feeTypeLines == null) {
                continue;
            }
            assignmentIdsInOrder.add(insertedAssignment.Id);

            for (Ken_Fee_Type_Line_Item__c feeTypeLine : feeTypeLines) {
                Fee_Assignment_Line_Item__c lineItem = new Fee_Assignment_Line_Item__c(
                    Fee_Assignment__c = insertedAssignment.Id,
                    Fee_Type_Line_Item__c = feeTypeLine.Id,
                    Fee_Head__c = feeTypeLine.Fee_Head__c,
                    Amount__c = feeTypeLine.Amount__c,
                    Total_Amount__c = feeTypeLine.Amount__c,
                    Tax__c = feeTypeLine.Tax__c,
                    Is_Active__c = true
                );
                lineItemsToInsert.add(lineItem);
            }

            List<Payment_Schedule_Instalment__c> scheduleInstallments = scheduleInstallmentsByFeeTypeId.get(feeTypeId);
            if (scheduleInstallments == null || scheduleInstallments.isEmpty()) {
                continue;
            }

            Integer installmentNumber = 0;
            for (Payment_Schedule_Instalment__c scheduleInstallment : scheduleInstallments) {
                installmentNumber++;
                Decimal installmentPercentage = scheduleInstallment.Fee_Collection_Percentage__c == null
                    ? 0
                    : scheduleInstallment.Fee_Collection_Percentage__c;
                Decimal assignmentAmount = insertedAssignment.Fee_Amount__c == null ? 0 : insertedAssignment.Fee_Amount__c;
                Decimal installmentAmount = (assignmentAmount * installmentPercentage) / 100;
                Decimal installmentTotalAmount = installmentAmount;

                Fee_Installment__c installment = new Fee_Installment__c(
                    Fee_Assignment__c = insertedAssignment.Id,
                    Payment_Schedule_Instalment__c = scheduleInstallment.Id,
                    Payment_Schedule__c = feeTypeById.get(feeTypeId).Payment_Schedule__c,
                    Installment_Number__c = installmentNumber,
                    Number_of_Installments__c = scheduleInstallments.size(),
                    Percentage__c = installmentPercentage,
                    Due_Date__c = scheduleInstallment.Fee_Collection_End_Date__c,
                    Amount__c = installmentAmount.setScale(0),
                    Total_Amount__c = installmentTotalAmount.setScale(2),
                    Status__c = 'Planned',
                    Active__c = true
                );
                installmentsToInsert.add(installment);
            }
            installmentCountByAssignmentId.put(insertedAssignment.Id, scheduleInstallments.size());
        }

        if (!lineItemsToInsert.isEmpty()) {
            insert lineItemsToInsert;
        }

        if (!installmentsToInsert.isEmpty()) {
            insert installmentsToInsert;
        }

        if (!lineItemsToInsert.isEmpty() && !installmentsToInsert.isEmpty()) {
            createInstallmentLineItems(
                assignmentsToInsert,
                lineItemsToInsert,
                installmentsToInsert,
                installmentCountByAssignmentId
            );
        }
    }

    private static String buildAssignmentName(
        AcademicTermEnrollment enrollment,
        AcademicTerm academicTerm,
        Ken_Fee_Type__c feeType
    ) {
        String feeTypeName = String.isBlank(feeType.Fee_Type_Name__c)
            ? feeType.Name
            : feeType.Fee_Type_Name__c;
        String termLabel = academicTerm == null ? String.valueOf(enrollment.AcademicTermId) : academicTerm.Name;
        return feeTypeName + ' - ' + TERM_ENROLLMENT_TRIGGER_POINT + ' - ' + termLabel;
    }

    private static Map<Id, List<Payment_Schedule_Instalment__c>> queryScheduleInstallmentsByFeeTypeId(
        Map<Id, Ken_Fee_Type__c> feeTypeById
    ) {
        Map<Id, List<Payment_Schedule_Instalment__c>> scheduleInstallmentsByFeeTypeId = new Map<Id, List<Payment_Schedule_Instalment__c>>();
        if (feeTypeById == null || feeTypeById.isEmpty()) {
            return scheduleInstallmentsByFeeTypeId;
        }

        Set<Id> paymentScheduleIds = new Set<Id>();
        Map<Id, Id> feeTypeIdByScheduleId = new Map<Id, Id>();
        for (Id feeTypeId : feeTypeById.keySet()) {
            Ken_Fee_Type__c feeType = feeTypeById.get(feeTypeId);
            if (feeType != null && feeType.Payment_Schedule__c != null) {
                paymentScheduleIds.add(feeType.Payment_Schedule__c);
                feeTypeIdByScheduleId.put(feeType.Payment_Schedule__c, feeTypeId);
            }
        }
        if (paymentScheduleIds.isEmpty()) {
            return scheduleInstallmentsByFeeTypeId;
        }

        for (Payment_Schedule_Instalment__c scheduleInstallment : [
            SELECT Id, Payment_Schedule__c, Collection_Order__c, Fee_Collection_Percentage__c, Fee_Collection_End_Date__c
            FROM Payment_Schedule_Instalment__c
            WHERE Payment_Schedule__c IN :paymentScheduleIds
            ORDER BY Collection_Order__c ASC, CreatedDate ASC
        ]) {
            Id feeTypeId = feeTypeIdByScheduleId.get(scheduleInstallment.Payment_Schedule__c);
            if (feeTypeId == null) {
                continue;
            }
            if (!scheduleInstallmentsByFeeTypeId.containsKey(feeTypeId)) {
                scheduleInstallmentsByFeeTypeId.put(feeTypeId, new List<Payment_Schedule_Instalment__c>());
            }
            scheduleInstallmentsByFeeTypeId.get(feeTypeId).add(scheduleInstallment);
        }
        return scheduleInstallmentsByFeeTypeId;
    }

    private static void createInstallmentLineItems(
        List<Fee_Assignment__c> assignments,
        List<Fee_Assignment_Line_Item__c> assignmentLineItems,
        List<Fee_Installment__c> installments,
        Map<Id, Integer> installmentCountByAssignmentId
    ) {
        Map<Id, List<Fee_Assignment_Line_Item__c>> lineItemsByAssignmentId = new Map<Id, List<Fee_Assignment_Line_Item__c>>();
        for (Fee_Assignment_Line_Item__c lineItem : assignmentLineItems) {
            if (!lineItemsByAssignmentId.containsKey(lineItem.Fee_Assignment__c)) {
                lineItemsByAssignmentId.put(lineItem.Fee_Assignment__c, new List<Fee_Assignment_Line_Item__c>());
            }
            lineItemsByAssignmentId.get(lineItem.Fee_Assignment__c).add(lineItem);
        }

        Map<Id, List<Fee_Installment__c>> installmentsByAssignmentId = new Map<Id, List<Fee_Installment__c>>();
        for (Fee_Installment__c installment : installments) {
            if (!installmentsByAssignmentId.containsKey(installment.Fee_Assignment__c)) {
                installmentsByAssignmentId.put(installment.Fee_Assignment__c, new List<Fee_Installment__c>());
            }
            installmentsByAssignmentId.get(installment.Fee_Assignment__c).add(installment);
        }

        List<Fee_Installment_Line_Item__c> installmentLineItemsToInsert = new List<Fee_Installment_Line_Item__c>();
        for (Fee_Assignment__c assignment : assignments) {
            List<Fee_Assignment_Line_Item__c> assignmentLines = lineItemsByAssignmentId.get(assignment.Id);
            List<Fee_Installment__c> assignmentInstallments = installmentsByAssignmentId.get(assignment.Id);
            if (assignmentLines == null || assignmentInstallments == null) {
                continue;
            }

            for (Fee_Installment__c installment : assignmentInstallments) {
                Decimal percentage = installment.Percentage__c == null ? 0 : installment.Percentage__c;
                for (Fee_Assignment_Line_Item__c assignmentLine : assignmentLines) {
                    Decimal assignmentLineAmount = assignmentLine.Amount__c == null ? 0 : assignmentLine.Amount__c;
                    Decimal lineInstallmentAmount = (assignmentLineAmount * percentage) / 100;
                    installmentLineItemsToInsert.add(new Fee_Installment_Line_Item__c(
                        Fee_Installment__c = installment.Id,
                        Fee_Assignment_Line_Item__c = assignmentLine.Id,
                        Payment_Schedule_Instalment__c = installment.Payment_Schedule_Instalment__c,
                        Installment_Number__c = installment.Installment_Number__c,
                        Percentage__c = percentage,
                        Due_Date__c = installment.Due_Date__c,
                        Amount__c = lineInstallmentAmount.setScale(2),
                        Paid_Amount__c = 0,
                        Status__c = 'Planned',
                        Active__c = true
                    ));
                }
            }
        }

        if (!installmentLineItemsToInsert.isEmpty()) {
            insert installmentLineItemsToInsert;
        }
    }
}