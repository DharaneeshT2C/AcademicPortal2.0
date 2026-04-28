/**
 * ************************************************************************************************
 * @className  KenMessMenuController
 *
 * @description
 *  Backs the `my/messMenu` LWC page — weekly mess menu by day + meal type.
 *
 *  TODO[SOBJECT]: Wire to `Mess_Menu__c` (Day_Of_Week__c, Meal_Type__c, Items__c)
 *                 or publish from a single scheduled custom metadata record.
 * ************************************************************************************************
 */
public without sharing class KenMessMenuController {

    public class MealDTO {
        @AuraEnabled public String mealType;  // 'Breakfast' | 'Lunch' | 'Snacks' | 'Dinner'
        @AuraEnabled public String items;
        @AuraEnabled public String timing;
    }

    public class DayMenuDTO {
        @AuraEnabled public String         dayOfWeek;
        @AuraEnabled public List<MealDTO>  meals;
    }

    @AuraEnabled(cacheable=true)
    public static List<DayMenuDTO> getWeeklyMenu() {
        try {
            // Mess_Menu__c is a global catalog object (no per-student sharing).
            List<Mess_Menu__c> rows = [
                SELECT Day_Of_Week__c, Meal_Type__c, Items__c, Timing__c
                FROM Mess_Menu__c
                WITH SECURITY_ENFORCED
                ORDER BY Day_Of_Week__c, Meal_Type__c
                LIMIT 200
            ];
            if (rows.isEmpty()) return new List<DayMenuDTO>();
            // Group by day in fixed order
            List<String> dayOrder = new List<String>{'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'};
            List<String> mealOrder = new List<String>{'Breakfast','Lunch','Snacks','Dinner'};
            Map<String, Map<String, Mess_Menu__c>> byDay = new Map<String, Map<String, Mess_Menu__c>>();
            for (Mess_Menu__c r : rows) {
                if (!byDay.containsKey(r.Day_Of_Week__c)) byDay.put(r.Day_Of_Week__c, new Map<String, Mess_Menu__c>());
                byDay.get(r.Day_Of_Week__c).put(r.Meal_Type__c, r);
            }
            List<DayMenuDTO> out = new List<DayMenuDTO>();
            for (String day : dayOrder) {
                if (!byDay.containsKey(day)) continue;
                DayMenuDTO d = new DayMenuDTO();
                d.dayOfWeek = day;
                d.meals = new List<MealDTO>();
                for (String mt : mealOrder) {
                    Mess_Menu__c m = byDay.get(day).get(mt);
                    if (m == null) continue;
                    d.meals.add(meal(mt, m.Items__c, m.Timing__c));
                }
                out.add(d);
            }
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenMessMenuController.getWeeklyMenu',
                'Unable to load mess menu.', e);
            return null;
        }
    }

    @AuraEnabled
    public static void submitMessFeedback(String meal, Integer rating, String comments) {
        try {
            KenAuraExceptionHelper.rejectIf(String.isBlank(meal), 'Meal is required.');
            KenAuraExceptionHelper.rejectIf(rating == null || rating < 1 || rating > 5, 'Rating must be 1-5.');
            Id studentId = KenRunningStudentHelper.optionalContactId();
            // Idempotency: one feedback per student per meal per day.
            if (studentId != null) {
                Date today = Date.today();
                Datetime startOfDay = Datetime.newInstance(today, Time.newInstance(0,0,0,0));
                List<Mess_Feedback__c> dupes = [
                    SELECT Id FROM Mess_Feedback__c
                    WHERE Student__c = :studentId
                      AND Meal__c = :meal
                      AND CreatedDate >= :startOfDay
                    WITH SECURITY_ENFORCED LIMIT 1
                ];
                if (!dupes.isEmpty()) return;
            }
            KenCrudFlsHelper.assertCreateable(Mess_Feedback__c.SObjectType);
            insert new Mess_Feedback__c(
                Student__c = studentId,
                Meal__c    = meal,
                Rating__c  = rating,
                Comments__c = comments == null ? null : comments.left(1000)
            );
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenMessMenuController.submitMessFeedback',
                'Could not submit feedback.', e);
        }
    }

    private static MealDTO meal(String type, String items, String timing) {
        MealDTO m = new MealDTO();
        m.mealType = type; m.items = items; m.timing = timing;
        return m;
    }
}