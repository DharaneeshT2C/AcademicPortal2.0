/**
 * ************************************************************************************************
 * @className  KenStudentPortalTestDataFactory
 *
 * @description
 *  Fluent builder that produces common fixtures for Student Portal test classes.
 *  Mirrors the `KenTestDataFactory` pattern in the academics-module reference:
 *  one chained builder per root SObject, a `create()` that inserts and returns
 *  the record.
 *
 *  Only references standard SObjects (Contact, User, Account). Fixture helpers
 *  for custom objects (Attendance__c, Fee_Installment__c, …) will be appended
 *  once org schema is live — see `TODO[SOBJECT]` markers in each controller.
 *
 * @author      Student Portal Backend
 * @createdOn   2026
 * ************************************************************************************************
 */
@isTest
public class KenStudentPortalTestDataFactory {

    // ─── Contact ───────────────────────────────────────────────────────────────

    public class ContactBuilder {
        private Contact record;

        public ContactBuilder() {
            record = new Contact(
                FirstName = 'Arjun',
                LastName  = 'R',
                Email     = 'arjun.r.' + generateUniqueSuffix() + '@example.test'
            );
        }

        public ContactBuilder setFirstName(String v) { record.FirstName = v; return this; }
        public ContactBuilder setLastName(String v)  { record.LastName  = v; return this; }
        public ContactBuilder setEmail(String v)     { record.Email     = v; return this; }
        public ContactBuilder setAccount(Id accountId) { record.AccountId = accountId; return this; }

        public Contact create() {
            insert record;
            return record;
        }
    }

    // ─── Account (institute) ──────────────────────────────────────────────────

    public class AccountBuilder {
        private Account record;

        public AccountBuilder() {
            record = new Account(Name = 'Ken University ' + generateUniqueSuffix());
        }

        public AccountBuilder setName(String v) { record.Name = v; return this; }

        public Account create() {
            insert record;
            return record;
        }
    }

    // ─── User (runAs helper) ───────────────────────────────────────────────────

    public class UserBuilder {
        private User record;

        public UserBuilder(String profileName) {
            Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
            String suffix = generateUniqueSuffix();
            record = new User(
                ProfileId         = p.Id,
                Username          = 'sp.user.' + suffix + '@example.test.invalid',
                Email             = 'sp.user.' + suffix + '@example.test',
                Alias             = 'spu' + suffix.substring(0, 4),
                FirstName         = 'Portal',
                LastName          = 'User',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey      = 'en_US',
                EmailEncodingKey  = 'UTF-8',
                TimeZoneSidKey    = 'America/Los_Angeles'
            );
        }

        public UserBuilder setContact(Id contactId) { record.ContactId = contactId; return this; }
        public UserBuilder setAlias(String v)       { record.Alias     = v; return this; }
        public UserBuilder setUsername(String v)    { record.Username  = v; return this; }

        public User create() {
            insert record;
            return record;
        }
    }

    // ─── Utility ───────────────────────────────────────────────────────────────

    private static String generateUniqueSuffix() {
        return String.valueOf(Crypto.getRandomLong()).substring(1, 9);
    }
}