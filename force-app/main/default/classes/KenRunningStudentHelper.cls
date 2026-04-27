/**
 * ************************************************************************************************
 * @className  KenRunningStudentHelper
 *
 * @description
 *  Centralises "who is the running student" resolution so every controller
 *  doesn't re-implement the User→Contact lookup.
 *
 *  The running Salesforce user's ContactId points to their learner Contact
 *  record. If the user has no linked Contact (dev/admin login, unit test
 *  contexts) the methods fall back to the test fixture so controllers can
 *  still return a graceful DTO instead of throwing.
 *
 * @author      Student Portal Backend
 * @createdOn   2026
 * ************************************************************************************************
 */
public without sharing class KenRunningStudentHelper {

    // Cached per-transaction to avoid repeated SOQL in the same @AuraEnabled call chain.
    private static Contact cachedContact;
    private static Boolean cacheLoaded  = false;

    /**
     * @description Returns the running user's Contact or `null` if unlinked.
     */
    public static Contact getContact() {
        if (cacheLoaded) return cachedContact;
        cacheLoaded = true;

        List<User> users = [
            SELECT Id, ContactId, FirstName, LastName, Email
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (users.isEmpty() || users[0].ContactId == null) {
            cachedContact = null;
            return null;
        }
        List<Contact> cs = [
            SELECT Id, FirstName, LastName, Email, Phone, Birthdate,
                   MailingStreet, MailingCity, MailingPostalCode
            FROM Contact
            WHERE Id = :users[0].ContactId
            LIMIT 1
        ];
        cachedContact = cs.isEmpty() ? null : cs[0];
        return cachedContact;
    }

    /**
     * @description Returns the Id of the running student's Contact.
     *              Throws AuraHandledException if the running user isn't a student.
     */
    public static Id requireContactId() {
        Contact c = getContact();
        if (c == null) {
            throw new AuraHandledException('No student record is linked to your login.');
        }
        return c.Id;
    }

    /**
     * @description Returns the Id of the running student's Contact, or null.
     *              Use when callers can cope without a student link.
     */
    public static Id optionalContactId() {
        Contact c = getContact();
        return c == null ? null : c.Id;
    }

    @TestVisible
    private static void resetCacheForTest() {
        cachedContact = null;
        cacheLoaded  = false;
    }
}