public without sharing class KenNavigationMenuController {

    public class UserContactDetails {
        @AuraEnabled public String profilePhotoUrl { get; set; }
        @AuraEnabled public String graduationYear { get; set; }
        @AuraEnabled public String studentName { get; set; }
        @AuraEnabled public String contactRecordTypeName { get; set; }
        @AuraEnabled public String primaryContactType { get; set; }
        @AuraEnabled public String profileName { get; set; }
    }
    
    @AuraEnabled(cacheable=true)
    public static UserContactDetails getUserContactDetails() {
        UserContactDetails userDetails = new UserContactDetails();
        
        try {
            if (!Schema.sObjectType.User.isAccessible()) {
                throw new AuraHandledException('You do not have permission to view user details.');
            }
            User currentUser = [
                SELECT Id, Name, AccountId, ContactId, Email, Username, Profile.Name, UserType
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            Ken_Room_Allotment__c activeAllotment = getCurrentAllotment(
                currentUser.ContactId,
                currentUser.AccountId,
                currentUser.Email,
                currentUser.Username,
                currentUser.UserType == 'Standard'
            );

            if (activeAllotment != null) {
                userDetails.studentName = activeAllotment.Tenant_Account__r != null
                    ? activeAllotment.Tenant_Account__r.Name
                    : activeAllotment.Tenant__r != null
                        ? activeAllotment.Tenant__r.Name
                        : null;
            } else if (currentUser.ContactId != null) {
                Contact currentContact = [
                    SELECT Id, Name
                    FROM Contact
                    WHERE Id = :currentUser.ContactId
                    WITH SECURITY_ENFORCED
                    LIMIT 1
                ];
                userDetails.studentName = currentContact.Name;
            } else if (currentUser.AccountId != null) {
                List<Account> accountRows = [
                    SELECT Id, Name, IsPersonAccount
                    FROM Account
                    WHERE Id = :currentUser.AccountId
                    WITH SECURITY_ENFORCED
                    LIMIT 1
                ];
                if (!accountRows.isEmpty() && accountRows[0].IsPersonAccount == true) {
                    userDetails.studentName = accountRows[0].Name;
                }
            } else {
                userDetails.studentName = currentUser.Name;
            }

            if (String.isBlank(userDetails.studentName)) {
                userDetails.studentName = currentUser.Name;
            }

            userDetails.profileName = currentUser.Profile.Name;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching user details: ' + e.getMessage());
        }
        
        return userDetails;
    }

    private static Ken_Room_Allotment__c getCurrentAllotment(
        Id contactId,
        Id accountId,
        String userEmail,
        String username,
        Boolean allowPreviewFallback
    ) {
        Ken_Room_Allotment__c selected;

        if (contactId != null) {
            selected = pickBestAllotment(queryAllotmentsByTenantContact(contactId));
            if (selected != null) {
                return selected;
            }
        }

        if (accountId != null) {
            selected = pickBestAllotment(queryAllotmentsByTenantAccount(accountId));
            if (selected != null) {
                return selected;
            }
        }

        String normalizedUserEmail = normalizeEmail(userEmail);
        if (String.isBlank(normalizedUserEmail)) {
            normalizedUserEmail = normalizeEmail(username);
        }

        if (String.isNotBlank(normalizedUserEmail)) {
            selected = pickBestAllotment(queryAllotmentsByTenantEmail(normalizedUserEmail));
            if (selected != null) {
                return selected;
            }
        }

        if (allowPreviewFallback == true) {
            selected = pickBestAllotment(queryActiveAllotmentsForPreview());
            if (selected != null) {
                return selected;
            }
        }

        return null;
    }

    private static List<Ken_Room_Allotment__c> queryAllotmentsByTenantAccount(Id accountId) {
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room allotments.');
        }
        return [
            SELECT Id, Active__c, Start_Date__c, End_Date__c, Room__c, Tenant_Account__c,
                Tenant_Account__r.Name,
                Tenant__c,
                Tenant__r.Name
            FROM Ken_Room_Allotment__c
            WHERE Tenant_Account__c = :accountId
                AND Room__c != null
            ORDER BY Active__c DESC, End_Date__c DESC NULLS LAST, Start_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 20
        ];
    }

    private static List<Ken_Room_Allotment__c> queryAllotmentsByTenantContact(Id contactId) {
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room allotments.');
        }
        return [
            SELECT Id, Active__c, Start_Date__c, End_Date__c, Room__c, Tenant_Account__c,
                Tenant_Account__r.Name,
                Tenant__c,
                Tenant__r.Name
            FROM Ken_Room_Allotment__c
            WHERE Tenant__c = :contactId
                AND Room__c != null
            ORDER BY Active__c DESC, End_Date__c DESC NULLS LAST, Start_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 20
        ];
    }

    private static List<Ken_Room_Allotment__c> queryAllotmentsByTenantEmail(String emailValue) {
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room allotments.');
        }
        return [
            SELECT Id, Active__c, Start_Date__c, End_Date__c, Room__c, Tenant_Account__c,
                Tenant_Account__r.Name,
                Tenant__c,
                Tenant__r.Name
            FROM Ken_Room_Allotment__c
            WHERE (Tenant_Account__r.PersonEmail = :emailValue
                OR Tenant__r.Email = :emailValue)
                AND Room__c != null
            ORDER BY Active__c DESC, End_Date__c DESC NULLS LAST, Start_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 20
        ];
    }

    private static List<Ken_Room_Allotment__c> queryActiveAllotmentsForPreview() {
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room allotments.');
        }
        return [
            SELECT Id, Active__c, Start_Date__c, End_Date__c, Room__c, Tenant_Account__c,
                Tenant_Account__r.Name,
                Tenant__c,
                Tenant__r.Name
            FROM Ken_Room_Allotment__c
            WHERE Room__c != null
                AND (Tenant_Account__c != null OR Tenant__c != null)
            ORDER BY Active__c DESC, CreatedDate ASC
            LIMIT 20
        ];
    }

    private static Ken_Room_Allotment__c pickBestAllotment(List<Ken_Room_Allotment__c> allotments) {
        if (allotments == null || allotments.isEmpty()) {
            return null;
        }

        Date today = Date.today();
        for (Ken_Room_Allotment__c allotment : allotments) {
            if (allotment.Active__c == true && isInDateRange(allotment, today)) {
                return allotment;
            }
        }

        for (Ken_Room_Allotment__c allotment : allotments) {
            if (isInDateRange(allotment, today)) {
                return allotment;
            }
        }

        for (Ken_Room_Allotment__c allotment : allotments) {
            if (allotment.Active__c == true) {
                return allotment;
            }
        }

        return allotments[0];
    }

    private static Boolean isInDateRange(Ken_Room_Allotment__c allotment, Date today) {
        Boolean startDateOk = allotment.Start_Date__c == null || allotment.Start_Date__c <= today;
        Boolean endDateOk = allotment.End_Date__c == null || allotment.End_Date__c >= today;
        return startDateOk && endDateOk;
    }

    private static String normalizeEmail(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }

        String normalized = rawValue.trim().toLowerCase();
        return normalized.contains('@') ? normalized : null;
    }
}