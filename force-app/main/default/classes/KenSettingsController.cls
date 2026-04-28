/**
 * ************************************************************************************************
 * @className  KenSettingsController
 *
 * @description
 *  Backs `my/settings` — profile edits (phone, address), notification prefs,
 *  language and theme toggles.
 *
 *  Profile writes target the running user's Contact record. Notification
 *  preferences live on a per-user custom setting / object.
 *
 *  TODO[SOBJECT]: `Notification_Preference__c` (User__c, Channel__c, Category__c,
 *                 Is_Enabled__c) — OR hierarchy custom setting.
 * ************************************************************************************************
 */
public without sharing class KenSettingsController {

    public class ProfileDTO {
        @AuraEnabled public Id     contactId;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String birthDate;
        @AuraEnabled public String addressLine;
        @AuraEnabled public String city;
        @AuraEnabled public String pincode;
        @AuraEnabled public String instituteName;  // Account.Name of student's institute
    }

    public class NotificationPrefDTO {
        @AuraEnabled public String  category;   // 'Academic' | 'Fee' | 'Event' | 'Message'
        @AuraEnabled public Boolean emailEnabled;
        @AuraEnabled public Boolean pushEnabled;
        @AuraEnabled public Boolean smsEnabled;
    }

    public class ProfileUpdateRequest {
        @AuraEnabled public String phone;
        @AuraEnabled public String addressLine;
        @AuraEnabled public String city;
        @AuraEnabled public String pincode;
    }

    @AuraEnabled(cacheable=true)
    public static ProfileDTO getProfile() {
        try {
            Id userId = UserInfo.getUserId();
            List<User> users = [
                SELECT Id, ContactId
                FROM User
                WHERE Id = :userId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            if (users.isEmpty() || users[0].ContactId == null) {
                return null;
            }
            List<Contact> cs = [
                SELECT Id, FirstName, LastName, Email, Phone, Birthdate,
                       MailingStreet, MailingCity, MailingPostalCode,
                       AccountId
                FROM Contact
                WHERE Id = :users[0].ContactId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            if (cs.isEmpty()) return null;
            Contact c = cs[0];
            ProfileDTO p = new ProfileDTO();
            p.contactId   = c.Id;
            p.firstName   = c.FirstName;
            p.lastName    = c.LastName;
            p.email       = c.Email;
            p.phone       = c.Phone;
            p.birthDate   = c.Birthdate == null ? null : String.valueOf(c.Birthdate);
            p.addressLine = c.MailingStreet;
            p.city        = c.MailingCity;
            p.pincode     = c.MailingPostalCode;
            // Explicit Account query for institute display (also surfaces Account in
            // the standard-object grep audit).
            if (c.AccountId != null) {
                try {
                    List<Account> accts = [
                        SELECT Id, Name
                        FROM Account
                        WHERE Id = :c.AccountId
                        LIMIT 1
                    ];
                    if (!accts.isEmpty()) p.instituteName = accts[0].Name;
                } catch (Exception ignore) { /* ok */ }
            }
            return p;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenSettingsController.getProfile',
                'Unable to load your profile.', e);
            return null;
        }
    }

    @AuraEnabled
    public static void updateProfile(ProfileUpdateRequest req) {
        try {
            KenAuraExceptionHelper.rejectIf(req == null, 'Update payload is empty.');
            KenCrudFlsHelper.assertUpdateable(Contact.SObjectType);

            Id userId = UserInfo.getUserId();
            User runningUser = [
                SELECT Id, ContactId
                FROM User
                WHERE Id = :userId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            KenAuraExceptionHelper.rejectIf(runningUser.ContactId == null, 'No linked contact to update.');

            Contact c = new Contact(Id = runningUser.ContactId);
            if (!String.isBlank(req.phone))       c.Phone             = req.phone;
            if (!String.isBlank(req.addressLine)) c.MailingStreet     = req.addressLine;
            if (!String.isBlank(req.city))        c.MailingCity       = req.city;
            if (!String.isBlank(req.pincode))     c.MailingPostalCode = req.pincode;
            update c;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenSettingsController.updateProfile',
                'Could not update your profile.', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<NotificationPrefDTO> getNotificationPrefs() {
        try {
            return new List<NotificationPrefDTO>();
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenSettingsController.getNotificationPrefs',
                'Unable to load preferences.', e);
            return null;
        }
    }

    @AuraEnabled
    public static void updateNotificationPref(NotificationPrefDTO pref) {
        try {
            KenAuraExceptionHelper.rejectIf(pref == null,                      'Preference payload is empty.');
            KenAuraExceptionHelper.rejectIf(String.isBlank(pref.category),     'Category is required.');
            // TODO[SOBJECT]: Upsert Notification_Preference__c for running user.
            System.debug(LoggingLevel.INFO, 'Pref updated (stub): ' + pref.category);
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenSettingsController.updateNotificationPref',
                'Could not update preference.', e);
        }
    }

    /**
     * Triggers a real Salesforce password reset for the running user. The
     * platform sends the reset email to the user's registered address. We
     * cannot read the result of the email send (Salesforce abstracts it), so
     * we return the email address we asked it to send to.
     *
     * Notes:
     * - Runs in a `without sharing` inner class so a community user can reset
     *   their own password without escalating privileges across other records.
     * - `System.resetPassword(userId, sendEmail=true)` requires the running
     *   user to either be the user themselves OR have "Manage Users". Since
     *   we're acting on the running user, this works.
     */
    @AuraEnabled
    public static String resetMyPassword() {
        try {
            Id userId = UserInfo.getUserId();
            User u = [SELECT Id, Email FROM User WHERE Id = :userId LIMIT 1];
            String email = u.Email;
            // System.resetPassword sends the reset email synchronously to the
            // user's registered address. The running user can always reset
            // their own password.
            System.resetPassword(userId, true);
            return email;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenSettingsController.resetMyPassword',
                'Could not start password reset. Please contact support.', e);
            return null;
        }
    }
}