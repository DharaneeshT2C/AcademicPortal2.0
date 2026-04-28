/**
 * ************************************************************************************************
 * @className  KenFeePlanController
 *
 * @description
 *  Backs `my/feePlan` — instalment plan view. Student can toggle between
 *  full-payment and instalment breakdowns.
 *
 *  TODO[SOBJECT]: Wire to `Fee_Plan__c` or derive from `Fee_Installment__c`
 *                 grouped by Plan_Code__c.
 * ************************************************************************************************
 */
public without sharing class KenFeePlanController {

    public class PlanOptionDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  planName;
        @AuraEnabled public Integer instalmentCount;
        @AuraEnabled public Decimal instalmentAmount;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String  nextDueDate;
    }

    @AuraEnabled(cacheable=true)
    public static List<PlanOptionDTO> getPlans() {
        try {
            List<Fee_Plan__c> plans = [
                SELECT Id, Plan_Name__c, Instalment_Count__c, Instalment_Amount__c, Total_Amount__c
                FROM Fee_Plan__c
                WITH SECURITY_ENFORCED
                ORDER BY Instalment_Count__c
                LIMIT 50
            ];
            if (plans.isEmpty()) return new List<PlanOptionDTO>();
            // Determine the student's active enrollment if any
            Id contactId = KenRunningStudentHelper.optionalContactId();
            Set<Id> activePlanIds = new Set<Id>();
            if (contactId != null) {
                for (Fee_Plan_Enrollment__c en : [
                    SELECT Plan__c FROM Fee_Plan_Enrollment__c
                    WHERE Student__c = :contactId AND Is_Active__c = true
                    WITH SECURITY_ENFORCED
                ]) activePlanIds.add(en.Plan__c);
            }
            List<PlanOptionDTO> out = new List<PlanOptionDTO>();
            for (Fee_Plan__c p : plans) {
                PlanOptionDTO d = new PlanOptionDTO();
                d.id               = p.Id;
                d.planName         = p.Plan_Name__c;
                d.instalmentCount  = p.Instalment_Count__c == null ? 1 : p.Instalment_Count__c.intValue();
                d.instalmentAmount = p.Instalment_Amount__c == null ? 0 : p.Instalment_Amount__c;
                d.totalAmount      = p.Total_Amount__c == null ? 0 : p.Total_Amount__c;
                d.isActive         = activePlanIds.contains(p.Id);
                d.nextDueDate      = '';
                out.add(d);
            }
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenFeePlanController.getPlans',
                'Unable to load fee plans.', e);
            return null;
        }
    }

    @AuraEnabled
    public static void switchToPlan(Id planId) {
        try {
            KenAuraExceptionHelper.rejectIf(planId == null, 'Plan id is required.');
            Id contactId = KenRunningStudentHelper.optionalContactId();
            KenAuraExceptionHelper.rejectIf(contactId == null, 'No student context.');
            KenCrudFlsHelper.assertUpdateable(Fee_Plan_Enrollment__c.SObjectType);
            // Deactivate existing plan enrollments
            List<Fee_Plan_Enrollment__c> existing = [
                SELECT Id FROM Fee_Plan_Enrollment__c
                WHERE Student__c = :contactId AND Is_Active__c = true
                WITH SECURITY_ENFORCED
            ];
            for (Fee_Plan_Enrollment__c e : existing) e.Is_Active__c = false;
            if (!existing.isEmpty()) update existing;
            // Insert new active enrollment
            KenCrudFlsHelper.assertCreateable(Fee_Plan_Enrollment__c.SObjectType);
            insert new Fee_Plan_Enrollment__c(
                Student__c  = contactId,
                Plan__c     = planId,
                Is_Active__c = true
            );
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenFeePlanController.switchToPlan',
                'Could not switch fee plan.', e);
        }
    }

}