/**
 * ************************************************************************************************
 * @className  KenCareerCompassController
 *
 * @description
 *  Persists Career Compass preferences (one Career_Preference__c per student).
 *  Used by the placementsLanding "Set up preferences" modal and the careerCompass LWC.
 * ************************************************************************************************
 */
public without sharing class KenCareerCompassController {

    public class PreferencesDTO {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  careerPath;
        @AuraEnabled public List<String> roles;
        @AuraEnabled public List<String> cities;
        @AuraEnabled public Decimal salaryFloor;
        @AuraEnabled public String  workMode;
        @AuraEnabled public Boolean optedIn;
    }

    @AuraEnabled(cacheable=true)
    public static PreferencesDTO getPreferences() {
        try {
            Id studentId = KenRunningStudentHelper.optionalContactId();
            if (studentId == null) return defaultDto();
            List<Career_Preference__c> rows = [
                SELECT Id, Career_Path__c, Preferred_Roles__c, Preferred_Cities__c,
                       Salary_Floor__c, Work_Mode__c, Opted_In__c
                FROM Career_Preference__c
                WHERE Student__c = :studentId
                WITH SECURITY_ENFORCED LIMIT 1
            ];
            if (rows.isEmpty()) return defaultDto();
            return toDto(rows[0]);
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenCareerCompassController.getPreferences',
                'Unable to load preferences.', e);
            return null;
        }
    }

    @AuraEnabled
    public static Id savePreferences(String careerPath, List<String> roles, List<String> cities,
                                     Decimal salaryFloor, String workMode, Boolean optedIn) {
        try {
            Id studentId = KenRunningStudentHelper.optionalContactId();
            if (studentId == null) return null;
            String roleStr = (roles == null || roles.isEmpty()) ? '' : String.join(roles, ',');
            String cityStr = (cities == null || cities.isEmpty()) ? '' : String.join(cities, ',');
            // Validate picklists; default to safe values if mismatch.
            Set<String> validPaths = new Set<String>{ 'placements','higher-studies','entrepreneurship','exploring' };
            if (!validPaths.contains(careerPath)) careerPath = 'placements';
            Set<String> validModes = new Set<String>{ 'Onsite','Hybrid','Remote','Any' };
            if (!validModes.contains(workMode)) workMode = 'Hybrid';

            List<Career_Preference__c> existing = [
                SELECT Id FROM Career_Preference__c
                WHERE Student__c = :studentId
                WITH SECURITY_ENFORCED LIMIT 1
            ];
            if (existing.isEmpty()) {
                KenCrudFlsHelper.assertCreateable(Career_Preference__c.SObjectType);
                Career_Preference__c p = new Career_Preference__c(
                    Student__c          = studentId,
                    Career_Path__c      = careerPath,
                    Preferred_Roles__c  = roleStr.left(500),
                    Preferred_Cities__c = cityStr.left(500),
                    Salary_Floor__c     = salaryFloor,
                    Work_Mode__c        = workMode,
                    Opted_In__c         = optedIn == true
                );
                insert p;
                return p.Id;
            }
            KenCrudFlsHelper.assertUpdateable(Career_Preference__c.SObjectType);
            update new Career_Preference__c(
                Id                  = existing[0].Id,
                Career_Path__c      = careerPath,
                Preferred_Roles__c  = roleStr.left(500),
                Preferred_Cities__c = cityStr.left(500),
                Salary_Floor__c     = salaryFloor,
                Work_Mode__c        = workMode,
                Opted_In__c         = optedIn == true
            );
            return existing[0].Id;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenCareerCompassController.savePreferences',
                'Could not save your preferences.', e);
            return null;
        }
    }

    private static PreferencesDTO defaultDto() {
        PreferencesDTO d = new PreferencesDTO();
        d.careerPath  = 'placements';
        d.roles       = new List<String>();
        d.cities      = new List<String>();
        d.workMode    = 'Hybrid';
        d.salaryFloor = 0;
        d.optedIn     = false;
        return d;
    }

    private static PreferencesDTO toDto(Career_Preference__c r) {
        PreferencesDTO d = new PreferencesDTO();
        d.id          = r.Id;
        d.careerPath  = r.Career_Path__c;
        d.roles       = String.isBlank(r.Preferred_Roles__c)  ? new List<String>() : r.Preferred_Roles__c.split(',\\s*');
        d.cities      = String.isBlank(r.Preferred_Cities__c) ? new List<String>() : r.Preferred_Cities__c.split(',\\s*');
        d.salaryFloor = r.Salary_Floor__c;
        d.workMode    = r.Work_Mode__c == null ? 'Hybrid' : r.Work_Mode__c;
        d.optedIn     = r.Opted_In__c == true;
        return d;
    }
}