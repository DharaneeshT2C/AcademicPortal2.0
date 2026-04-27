public without sharing class ResidencePreferenceSelectionController {
    public class ResidencePreferenceItem {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public Integer order { get; set; }
        @AuraEnabled public String categoryId { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public String preference { get; set; }
        @AuraEnabled public String floor { get; set; }
        @AuraEnabled public String emails { get; set; }
        @AuraEnabled public String sharing { get; set; }
        @AuraEnabled public String ac { get; set; }
        @AuraEnabled public String bathroom { get; set; }
        @AuraEnabled public String amenities { get; set; }
    }

    public class ResidenceCategoryItem {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Decimal annualFee { get; set; }
        @AuraEnabled public Decimal capacity { get; set; }
        @AuraEnabled public String amenities { get; set; }
    }

    public class ResidenceSelectionResponse {
        @AuraEnabled public List<ResidenceCategoryItem> residences { get; set; }
        @AuraEnabled public List<ResidencePreferenceItem> selectedPreferences { get; set; }
        @AuraEnabled public Integer selectedCount { get; set; }
        @AuraEnabled public String requestStatus { get; set; }
        @AuraEnabled public String preferredPartnerEmails { get; set; }

        public ResidenceSelectionResponse() {
            residences = new List<ResidenceCategoryItem>();
            selectedPreferences = new List<ResidencePreferenceItem>();
            selectedCount = 0;
            requestStatus = null;
            preferredPartnerEmails = null;
        }
    }

    public class ResidenceSelectionPreferenceInput {
        @AuraEnabled public String residenceId { get; set; }
        @AuraEnabled public Integer order { get; set; }
        @AuraEnabled public String floor { get; set; }
        @AuraEnabled public List<String> roommateEmails { get; set; }
    }

    public class RoommateValidationIssue {
        @AuraEnabled public String residenceId { get; set; }
        @AuraEnabled public Integer order { get; set; }
        @AuraEnabled public Integer slot { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String message { get; set; }
    }

    public class SaveResidencePreferencesResponse {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Integer selectedCount { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public List<RoommateValidationIssue> roommateIssues { get; set; }

        public SaveResidencePreferencesResponse() {
            success = false;
            message = null;
            selectedCount = 0;
            status = null;
            roommateIssues = new List<RoommateValidationIssue>();
        }
    }

    private class RoommateResolutionResult {
        public Id preferredPartnerAccountId { get; set; }
        public List<RoommateValidationIssue> issues { get; set; }

        public RoommateResolutionResult() {
            preferredPartnerAccountId = null;
            issues = new List<RoommateValidationIssue>();
        }
    }

    @AuraEnabled(cacheable=true)
    public static ResidenceSelectionResponse getResidencePreferenceSelectionData() {
        ResidenceSelectionResponse response = new ResidenceSelectionResponse();

        try {
            if (!Schema.sObjectType.User.isAccessible()) {
                throw new AuraHandledException('You do not have permission to view user details.');
            }
            User currentUser = [
                SELECT Id, AccountId, ContactId, Email, Username
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            String normalizedUserEmail = normalizeEmail(currentUser.Email);
            if (String.isBlank(normalizedUserEmail)) {
                normalizedUserEmail = normalizeEmail(currentUser.Username);
            }

            Id resolvedAccountId = resolvePersonAccountId(
                currentUser.AccountId,
                currentUser.ContactId,
                normalizedUserEmail
            );

            Ken_Room_Request__c latestRoomRequest = getLatestRoomRequest(
                resolvedAccountId,
                currentUser.ContactId,
                normalizedUserEmail,
                currentUser.Id
            );
            response.selectedPreferences = mapRoomRequestPreferences(latestRoomRequest);
            response.selectedCount = response.selectedPreferences.size();
            response.requestStatus = latestRoomRequest != null ? latestRoomRequest.Status__c : null;
            response.preferredPartnerEmails =
                latestRoomRequest != null && latestRoomRequest.Preferred_Partner__r != null
                    ? latestRoomRequest.Preferred_Partner__r.PersonEmail
                    : null;

            Set<Id> selectedCategoryIds = new Set<Id>();
            if (latestRoomRequest != null) {
                if (latestRoomRequest.Preference_1__c != null) {
                    selectedCategoryIds.add(latestRoomRequest.Preference_1__c);
                }
                if (latestRoomRequest.Preference_2__c != null) {
                    selectedCategoryIds.add(latestRoomRequest.Preference_2__c);
                }
                if (latestRoomRequest.Preference_3__c != null) {
                    selectedCategoryIds.add(latestRoomRequest.Preference_3__c);
                }
            }

            for (Ken_Room_Category__c category : queryResidenceCategories(selectedCategoryIds)) {
                response.residences.add(mapResidenceCategory(category));
            }

            return response;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load residence selection data: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static SaveResidencePreferencesResponse saveResidencePreferences(
        List<ResidenceSelectionPreferenceInput> selections,
        Boolean submitRequest
    ) {
        SaveResidencePreferencesResponse response = new SaveResidencePreferencesResponse();

        try {
            Map<Integer, Id> preferenceByOrder = new Map<Integer, Id>();
            List<ResidenceSelectionPreferenceInput> normalizedSelections = new List<ResidenceSelectionPreferenceInput>();

            if (selections != null) {
                for (ResidenceSelectionPreferenceInput item : selections) {
                    if (item == null || item.order == null || item.order < 1 || item.order > 3) {
                        continue;
                    }

                    Id categoryId = toId(item.residenceId);
                    if (categoryId == null) {
                        continue;
                    }

                    ResidenceSelectionPreferenceInput normalized = new ResidenceSelectionPreferenceInput();
                    normalized.residenceId = String.valueOf(categoryId);
                    normalized.order = item.order;
                    normalized.floor = item.floor;
                    normalized.roommateEmails = item.roommateEmails;
                    normalizedSelections.add(normalized);
                }
            }

            if (normalizedSelections.isEmpty()) {
                response.message = 'Select at least one residence preference.';
                return response;
            }

            // Normalize to contiguous ranks (1..N) to avoid gaps like only Preference 2/3 being set,
            // which can break org-level validation rules/triggers.
            Map<Integer, List<Id>> categoryIdsByRequestedOrder = new Map<Integer, List<Id>>{
                1 => new List<Id>(),
                2 => new List<Id>(),
                3 => new List<Id>()
            };
            Map<String, List<String>> roommateEmailsByOrderAndCategory = new Map<String, List<String>>();
            for (ResidenceSelectionPreferenceInput item : normalizedSelections) {
                Integer requestedOrder = item != null ? item.order : null;
                if (requestedOrder == null || requestedOrder < 1 || requestedOrder > 3) {
                    continue;
                }
                Id categoryId = toId(item.residenceId);
                if (categoryId == null) {
                    continue;
                }
                categoryIdsByRequestedOrder.get(requestedOrder).add(categoryId);
                String key = String.valueOf(requestedOrder) + '_' + String.valueOf(categoryId);
                roommateEmailsByOrderAndCategory.put(key, item.roommateEmails != null ? item.roommateEmails : new List<String>());
            }

            Integer nextOrder = 1;
            Set<Id> seenCategoryIds = new Set<Id>();
            Map<Integer, List<String>> roommateEmailsByOrder = new Map<Integer, List<String>>();
            for (Integer requestedOrder = 1; requestedOrder <= 3; requestedOrder += 1) {
                for (Id categoryId : categoryIdsByRequestedOrder.get(requestedOrder)) {
                    if (nextOrder > 3) {
                        break;
                    }
                    if (categoryId == null || seenCategoryIds.contains(categoryId)) {
                        continue;
                    }
                    preferenceByOrder.put(nextOrder, categoryId);
                    String key = String.valueOf(requestedOrder) + '_' + String.valueOf(categoryId);
                    List<String> emails = roommateEmailsByOrderAndCategory.get(key);
                    roommateEmailsByOrder.put(nextOrder, emails != null ? emails : new List<String>());
                    seenCategoryIds.add(categoryId);
                    nextOrder += 1;
                }
                if (nextOrder > 3) {
                    break;
                }
            }

            if (preferenceByOrder.isEmpty()) {
                response.message = 'Select at least one residence preference.';
                return response;
            }

            if (!Schema.sObjectType.User.isAccessible()) {
                throw new AuraHandledException('You do not have permission to view user details.');
            }
            User currentUser = [
                SELECT Id, AccountId, ContactId, Email, Username
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            String normalizedUserEmail = normalizeEmail(currentUser.Email);
            if (String.isBlank(normalizedUserEmail)) {
                normalizedUserEmail = normalizeEmail(currentUser.Username);
            }

            Id accountId = resolvePersonAccountId(currentUser.AccountId, currentUser.ContactId, normalizedUserEmail);
            Id requesterContactId = resolveRequesterContactId(currentUser.ContactId, accountId);
            if (requesterContactId == null) {
                response.message = 'No contact is linked to this user.';
                return response;
            }

            Ken_Room_Request__c requestRecord = getLatestRoomRequest(
                accountId,
                requesterContactId,
                normalizedUserEmail,
                currentUser.Id
            );
            if (requestRecord == null) {
                requestRecord = new Ken_Room_Request__c();
            }

            requestRecord.Request_By__c = accountId;
            requestRecord.Requested_By__c = requesterContactId;
            requestRecord.Preference_1__c = preferenceByOrder.containsKey(1) ? preferenceByOrder.get(1) : null;
            requestRecord.Preference_2__c = preferenceByOrder.containsKey(2) ? preferenceByOrder.get(2) : null;
            requestRecord.Preference_3__c = preferenceByOrder.containsKey(3) ? preferenceByOrder.get(3) : null;
            RoommateResolutionResult roommateResolution = resolveRoommateResolution(preferenceByOrder, roommateEmailsByOrder);
            if (!roommateResolution.issues.isEmpty()) {
                response.message = 'One or more roommate emails are not registered in the system.';
                response.roommateIssues.addAll(roommateResolution.issues);
                return response;
            }
            requestRecord.Preferred_Partner__c = roommateResolution.preferredPartnerAccountId;
            if (requestRecord.Window__c == null) {
                requestRecord.Window__c = resolveCurrentPreferenceWindowId();
            }
            String tenantType = resolveTenantTypeFromWindow(requestRecord.Window__c);
            if (tenantType != null) {
                requestRecord.Tenant_type__c = tenantType;
            }

            if (submitRequest == true) {
                requestRecord.Status__c = 'Pending';
            } else if (requestRecord.Id == null || isRejectedStatus(requestRecord.Status__c)) {
                requestRecord.Status__c = null;
            }

            if (requestRecord.Id == null) {
                if (!Schema.sObjectType.Ken_Room_Request__c.isCreateable()) {
                    throw new AuraHandledException('You do not have permission to create room requests.');
                }
                insert requestRecord;
            } else {
                if (!Schema.sObjectType.Ken_Room_Request__c.isUpdateable()) {
                    throw new AuraHandledException('You do not have permission to update room requests.');
                }
                update requestRecord;
            }

            response.success = true;
            response.selectedCount = preferenceByOrder.size();
            response.status = requestRecord.Status__c;
            response.message = submitRequest == true
                ? 'Residence request submitted successfully.'
                : 'Draft saved successfully.';
            return response;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to save residence preferences: ' + e.getMessage());
        }
    }


    private static Ken_Room_Request__c getLatestRoomRequest(
        Id accountId,
        Id contactId,
        String normalizedUserEmail,
        Id userId
    ) {
        if (contactId != null) {
            // When we have a Requested By contact, do not fall back to account/email.
            // Mixing lookup keys can cause us to pick another student's record.
            return queryLatestRoomRequestByContact(contactId);
        }

        Ken_Room_Request__c latestRequest;
        if (accountId != null) {
            latestRequest = queryLatestRoomRequestByAccount(accountId);
            if (latestRequest != null) {
                return latestRequest;
            }
        }

        if (String.isNotBlank(normalizedUserEmail)) {
            latestRequest = queryLatestRoomRequestByEmail(normalizedUserEmail);
            if (latestRequest != null) {
                return latestRequest;
            }
        }

        // Development/internal fallback: keep working even without student account mapping.
        if (userId != null) {
            latestRequest = queryLatestRoomRequestByCreatedBy(userId);
        }

        return latestRequest;
    }

    private static Ken_Room_Request__c queryLatestRoomRequestByContact(Id contactId) {
        if (!Schema.sObjectType.Ken_Room_Request__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room requests.');
        }
        List<Ken_Room_Request__c> rows = [
            SELECT Id, Name, Status__c, Preferred_Partner__c,
                Preferred_Partner__r.PersonEmail,
                Window__c,
                Preference_1__c, Preference_2__c, Preference_3__c,
                Preference_1_Category__c, Preference_2_Category__c, Preference_3_Category__c,
                Preference_1__r.Name,
                Preference_1__r.Name__c,
                Preference_1__r.Capacity__c,
                Preference_1__r.Amenities__c,
                Preference_2__r.Name,
                Preference_2__r.Name__c,
                Preference_2__r.Capacity__c,
                Preference_2__r.Amenities__c,
                Preference_3__r.Name,
                Preference_3__r.Name__c,
                Preference_3__r.Capacity__c,
                Preference_3__r.Amenities__c
            FROM Ken_Room_Request__c
            WHERE Requested_By__c = :contactId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static Ken_Room_Request__c queryLatestRoomRequestByAccount(Id accountId) {
        if (!Schema.sObjectType.Ken_Room_Request__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room requests.');
        }
        List<Ken_Room_Request__c> rows = [
            SELECT Id, Name, Status__c, Preferred_Partner__c,
                Preferred_Partner__r.PersonEmail,
                Window__c,
                Preference_1__c, Preference_2__c, Preference_3__c,
                Preference_1_Category__c, Preference_2_Category__c, Preference_3_Category__c,
                Preference_1__r.Name,
                Preference_1__r.Name__c,
                Preference_1__r.Capacity__c,
                Preference_1__r.Amenities__c,
                Preference_2__r.Name,
                Preference_2__r.Name__c,
                Preference_2__r.Capacity__c,
                Preference_2__r.Amenities__c,
                Preference_3__r.Name,
                Preference_3__r.Name__c,
                Preference_3__r.Capacity__c,
                Preference_3__r.Amenities__c
            FROM Ken_Room_Request__c
            WHERE Request_By__c = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static Ken_Room_Request__c queryLatestRoomRequestByEmail(String normalizedUserEmail) {
        if (!Schema.sObjectType.Ken_Room_Request__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room requests.');
        }
        List<Ken_Room_Request__c> rows = [
            SELECT Id, Name, Status__c, Preferred_Partner__c,
                Preferred_Partner__r.PersonEmail,
                Window__c,
                Preference_1__c, Preference_2__c, Preference_3__c,
                Preference_1_Category__c, Preference_2_Category__c, Preference_3_Category__c,
                Preference_1__r.Name,
                Preference_1__r.Name__c,
                Preference_1__r.Capacity__c,
                Preference_1__r.Amenities__c,
                Preference_2__r.Name,
                Preference_2__r.Name__c,
                Preference_2__r.Capacity__c,
                Preference_2__r.Amenities__c,
                Preference_3__r.Name,
                Preference_3__r.Name__c,
                Preference_3__r.Capacity__c,
                Preference_3__r.Amenities__c
            FROM Ken_Room_Request__c
            WHERE Request_By__r.PersonEmail = :normalizedUserEmail
                OR Requested_By__r.Email = :normalizedUserEmail
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static Ken_Room_Request__c queryLatestRoomRequestByCreatedBy(Id userId) {
        if (!Schema.sObjectType.Ken_Room_Request__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room requests.');
        }
        List<Ken_Room_Request__c> rows = [
            SELECT Id, Name, Status__c, Preferred_Partner__c,
                Preferred_Partner__r.PersonEmail,
                Window__c,
                Preference_1__c, Preference_2__c, Preference_3__c,
                Preference_1_Category__c, Preference_2_Category__c, Preference_3_Category__c,
                Preference_1__r.Name,
                Preference_1__r.Name__c,
                Preference_1__r.Capacity__c,
                Preference_1__r.Amenities__c,
                Preference_2__r.Name,
                Preference_2__r.Name__c,
                Preference_2__r.Capacity__c,
                Preference_2__r.Amenities__c,
                Preference_3__r.Name,
                Preference_3__r.Name__c,
                Preference_3__r.Capacity__c,
                Preference_3__r.Amenities__c
            FROM Ken_Room_Request__c
            WHERE CreatedById = :userId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static List<Ken_Room_Category__c> queryResidenceCategories(Set<Id> selectedCategoryIds) {
        Set<Id> safeSelectedIds = selectedCategoryIds == null ? new Set<Id>() : selectedCategoryIds;
        if (!Schema.sObjectType.Ken_Room_Category__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room categories.');
        }

        List<Ken_Room_Category__c> categories = [
            SELECT Id, Name, Name__c, Capacity__c, Amenities__c, Total_Price__c, Premium_Price__c, Base_Price__c, Active__c
            FROM Ken_Room_Category__c
            WHERE Active__c = true
                OR Id IN :safeSelectedIds
            ORDER BY Active__c DESC, CreatedDate ASC
            LIMIT 50
        ];

        if (!categories.isEmpty()) {
            return categories;
        }

        return [
            SELECT Id, Name, Name__c, Capacity__c, Amenities__c, Total_Price__c, Premium_Price__c, Base_Price__c, Active__c
            FROM Ken_Room_Category__c
            ORDER BY CreatedDate ASC
            LIMIT 50
        ];
    }

    private static ResidenceCategoryItem mapResidenceCategory(Ken_Room_Category__c category) {
        ResidenceCategoryItem row = new ResidenceCategoryItem();
        if (category == null) {
            return row;
        }

        row.id = String.valueOf(category.Id);
        row.name = firstNonBlank(new List<String>{ category.Name__c, category.Name });
        row.capacity = category.Capacity__c;
        row.amenities = category.Amenities__c;
        row.annualFee = resolveCategoryFee(category);
        return row;
    }

    private static Decimal resolveCategoryFee(Ken_Room_Category__c category) {
        if (category == null) {
            return null;
        }

        if (category.Total_Price__c != null) {
            return category.Total_Price__c;
        }
        if (category.Premium_Price__c != null) {
            return category.Premium_Price__c;
        }
        return category.Base_Price__c;
    }

    private static Id resolvePersonAccountId(Id directAccountId, Id directContactId, String normalizedUserEmail) {
        if (!Schema.sObjectType.Account.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view accounts.');
        }
        if (directAccountId != null) {
            List<Account> directAccountRows = [
                SELECT Id
                FROM Account
                WHERE Id = :directAccountId
                    AND IsPersonAccount = true
                LIMIT 1
            ];
            if (!directAccountRows.isEmpty()) {
                return directAccountRows[0].Id;
            }
        }

        if (directContactId != null) {
            List<Account> personAccountsByContact = [
                SELECT Id
                FROM Account
                WHERE IsPersonAccount = true
                    AND PersonContactId = :directContactId
                LIMIT 1
            ];
            if (!personAccountsByContact.isEmpty()) {
                return personAccountsByContact[0].Id;
            }
        }

        return queryPersonAccountIdByEmail(normalizedUserEmail);
    }

    private static Id resolveRequesterContactId(Id directContactId, Id personAccountId) {
        if (directContactId != null) {
            return directContactId;
        }
        if (personAccountId == null) {
            return null;
        }
        if (!Schema.sObjectType.Account.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view accounts.');
        }

        List<Account> accountRows = [
            SELECT PersonContactId
            FROM Account
            WHERE Id = :personAccountId
            LIMIT 1
        ];
        return accountRows.isEmpty() ? null : accountRows[0].PersonContactId;
    }

    private static Id queryPersonAccountIdByEmail(String normalizedUserEmail) {
        if (String.isBlank(normalizedUserEmail)) {
            return null;
        }
        if (!Schema.sObjectType.Account.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view accounts.');
        }

        List<Account> accounts = [
            SELECT Id
            FROM Account
            WHERE IsPersonAccount = true
                AND PersonEmail = :normalizedUserEmail
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return accounts.isEmpty() ? null : accounts[0].Id;
    }

    private static RoommateResolutionResult resolveRoommateResolution(
        Map<Integer, Id> preferenceByOrder,
        Map<Integer, List<String>> roommateEmailsByOrder
    ) {
        RoommateResolutionResult result = new RoommateResolutionResult();
        if (roommateEmailsByOrder == null || roommateEmailsByOrder.isEmpty()) {
            return result;
        }

        List<String> requestedEmails = new List<String>();
        Set<String> uniqueEmails = new Set<String>();
        Map<String, List<RoommateValidationIssue>> issuesByEmail = new Map<String, List<RoommateValidationIssue>>();

        for (Integer order = 1; order <= 3; order += 1) {
            Id residenceId = preferenceByOrder != null && preferenceByOrder.containsKey(order)
                ? preferenceByOrder.get(order)
                : null;
            List<String> roommateEmails = roommateEmailsByOrder.containsKey(order)
                ? roommateEmailsByOrder.get(order)
                : null;
            if (residenceId == null || roommateEmails == null || roommateEmails.isEmpty()) {
                continue;
            }

            for (Integer index = 0; index < roommateEmails.size(); index += 1) {
                String normalizedEmail = normalizeEmail(roommateEmails[index]);
                if (String.isBlank(normalizedEmail)) {
                    continue;
                }

                if (!issuesByEmail.containsKey(normalizedEmail)) {
                    issuesByEmail.put(normalizedEmail, new List<RoommateValidationIssue>());
                }

                RoommateValidationIssue issue = new RoommateValidationIssue();
                issue.residenceId = String.valueOf(residenceId);
                issue.order = order;
                issue.slot = index + 1;
                issue.email = normalizedEmail;
                issuesByEmail.get(normalizedEmail).add(issue);

                if (!uniqueEmails.contains(normalizedEmail)) {
                    requestedEmails.add(normalizedEmail);
                    uniqueEmails.add(normalizedEmail);
                }
            }
        }

        if (uniqueEmails.isEmpty()) {
            return result;
        }
        if (!Schema.sObjectType.Account.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view accounts.');
        }
        if (!Schema.sObjectType.Contact.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view contacts.');
        }

        Map<String, Id> personAccountIdByEmail = new Map<String, Id>();
        for (Account accountRow : [
            SELECT Id, PersonEmail
            FROM Account
            WHERE IsPersonAccount = true
                AND PersonEmail IN :uniqueEmails
            LIMIT 200
        ]) {
            String normalizedAccountEmail = normalizeEmail(accountRow.PersonEmail);
            if (String.isNotBlank(normalizedAccountEmail) && !personAccountIdByEmail.containsKey(normalizedAccountEmail)) {
                personAccountIdByEmail.put(normalizedAccountEmail, accountRow.Id);
            }
        }

        Set<String> contactEmails = new Set<String>();
        Map<String, Id> personAccountIdByContactEmail = new Map<String, Id>();
        for (Contact contactRow : [
            SELECT Id, Email, AccountId, Account.IsPersonAccount
            FROM Contact
            WHERE Email IN :uniqueEmails
            LIMIT 200
        ]) {
            String normalizedContactEmail = normalizeEmail(contactRow.Email);
            if (String.isBlank(normalizedContactEmail)) {
                continue;
            }

            contactEmails.add(normalizedContactEmail);
            if (
                contactRow.AccountId != null &&
                contactRow.Account != null &&
                contactRow.Account.IsPersonAccount == true &&
                !personAccountIdByContactEmail.containsKey(normalizedContactEmail)
            ) {
                personAccountIdByContactEmail.put(normalizedContactEmail, contactRow.AccountId);
            }
        }

        for (String requestedEmail : requestedEmails) {
            if (personAccountIdByEmail.containsKey(requestedEmail)) {
                result.preferredPartnerAccountId = personAccountIdByEmail.get(requestedEmail);
                break;
            }
            if (personAccountIdByContactEmail.containsKey(requestedEmail)) {
                result.preferredPartnerAccountId = personAccountIdByContactEmail.get(requestedEmail);
                break;
            }
        }

        for (String requestedEmail : requestedEmails) {
            if (personAccountIdByEmail.containsKey(requestedEmail) || contactEmails.contains(requestedEmail)) {
                continue;
            }

            for (RoommateValidationIssue issue : issuesByEmail.get(requestedEmail)) {
                issue.message = 'This email is not registered in the system.';
                result.issues.add(issue);
            }
        }

        return result;
    }

    private static Id resolveCurrentPreferenceWindowId() {
        if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view preference windows.');
        }
        List<Ken_Windows__c> windows = [
            SELECT Id, Start_Date__c, End_Date__c
            FROM Ken_Windows__c
            WHERE Allotment_Type__c = 'Preference Selected'
            ORDER BY Start_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 20
        ];

        if (windows.isEmpty()) {
            return null;
        }

        Date today = Date.today();
        for (Ken_Windows__c window : windows) {
            if (isWithinDateWindow(today, window.Start_Date__c, window.End_Date__c)) {
                return window.Id;
            }
        }

        return windows[0].Id;
    }

    private static Boolean isWithinDateWindow(Date referenceDate, Date startDate, Date endDate) {
        Boolean startOk = startDate == null || startDate <= referenceDate;
        Boolean endOk = endDate == null || endDate >= referenceDate;
        return startOk && endOk;
    }

    private static List<ResidencePreferenceItem> mapRoomRequestPreferences(Ken_Room_Request__c roomRequest) {
        List<ResidencePreferenceItem> preferences = new List<ResidencePreferenceItem>();
        if (roomRequest == null) {
            return preferences;
        }

        appendPreferenceItem(
            preferences,
            1,
            roomRequest.Preference_1__c,
            roomRequest.Preference_1_Category__c,
            roomRequest.Preference_1__r,
            roomRequest.Preferred_Partner__r != null ? roomRequest.Preferred_Partner__r.PersonEmail : null
        );
        appendPreferenceItem(
            preferences,
            2,
            roomRequest.Preference_2__c,
            roomRequest.Preference_2_Category__c,
            roomRequest.Preference_2__r,
            roomRequest.Preferred_Partner__r != null ? roomRequest.Preferred_Partner__r.PersonEmail : null
        );
        appendPreferenceItem(
            preferences,
            3,
            roomRequest.Preference_3__c,
            roomRequest.Preference_3_Category__c,
            roomRequest.Preference_3__r,
            roomRequest.Preferred_Partner__r != null ? roomRequest.Preferred_Partner__r.PersonEmail : null
        );

        return preferences;
    }

    private static void appendPreferenceItem(
        List<ResidencePreferenceItem> items,
        Integer preferenceOrder,
        Id categoryId,
        String categoryLabel,
        Ken_Room_Category__c categoryRecord,
        String preferredPartnerEmails
    ) {
        String typeLabel = firstNonBlank(new List<String>{
            categoryLabel,
            categoryRecord != null ? categoryRecord.Name__c : null,
            categoryRecord != null ? categoryRecord.Name : null
        });

        if (String.isBlank(typeLabel) && categoryRecord == null) {
            return;
        }

        String amenities = categoryRecord != null ? categoryRecord.Amenities__c : null;

        ResidencePreferenceItem row = new ResidencePreferenceItem();
        row.id = String.valueOf(preferenceOrder);
        row.order = preferenceOrder;
        row.categoryId = categoryId != null ? String.valueOf(categoryId) : null;
        row.preference = 'Preference ' + String.valueOf(preferenceOrder);
        row.type = String.isNotBlank(typeLabel) ? typeLabel : row.preference;
        row.floor = 'No Preference';
        row.emails = String.isNotBlank(preferredPartnerEmails) ? preferredPartnerEmails : '';
        row.sharing = toSharingCardLabel(categoryRecord != null ? categoryRecord.Capacity__c : null);
        row.ac = resolveAcFromAmenities(amenities);
        row.bathroom = resolveBathroomFromAmenities(amenities);
        row.amenities = amenities;
        items.add(row);
    }

    private static void appendEmails(List<String> target, List<String> emails) {
        if (target == null || emails == null) {
            return;
        }
        for (String emailValue : emails) {
            String normalized = normalizeEmail(emailValue);
            if (String.isNotBlank(normalized)) {
                target.add(normalized);
            }
        }
    }

    private static Id toId(String rawId) {
        if (String.isBlank(rawId)) {
            return null;
        }
        try {
            return (Id) rawId.trim();
        } catch (Exception e) {
            return null;
        }
    }

    private static Boolean isRejectedStatus(String statusValue) {
        if (String.isBlank(statusValue)) {
            return false;
        }

        String normalized = statusValue.toLowerCase();
        return normalized.contains('reject') || normalized.contains('declin') || normalized.contains('not approved');
    }

    private static String normalizeEmail(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }

        String normalized = rawValue.trim().toLowerCase();
        return normalized.contains('@') ? normalized : null;
    }

    private static String toSharingCardLabel(Decimal capacity) {
        String sharingValue = toSharingLabel(capacity);
        return String.isBlank(sharingValue) ? null : sharingValue.replace('-', ' ');
    }

    private static String toSharingLabel(Decimal capacity) {
        if (capacity == null) {
            return null;
        }

        Integer sharingCapacity = Integer.valueOf(String.valueOf(Math.round(capacity)));
        if (sharingCapacity <= 0) {
            return null;
        }
        if (sharingCapacity == 1) {
            return 'Single-sharing';
        }
        if (sharingCapacity == 2) {
            return 'Twin-sharing';
        }
        if (sharingCapacity == 3) {
            return 'Triple-sharing';
        }
        return String.valueOf(sharingCapacity) + '-sharing';
    }

    private static String resolveAcFromAmenities(String amenities) {
        if (String.isBlank(amenities)) {
            return null;
        }

        String normalized = amenities.toLowerCase();
        if (normalized.contains('non-ac') || normalized.contains('non ac') || normalized.contains('without ac')) {
            return 'Non-AC';
        }
        if (normalized.contains('air conditioning') || normalized.contains(' ac')) {
            return 'AC';
        }
        return null;
    }

    private static String resolveBathroomFromAmenities(String amenities) {
        if (String.isBlank(amenities)) {
            return null;
        }

        String normalized = amenities.toLowerCase();
        if (normalized.contains('attached bathroom') || normalized.contains('attached bath') || normalized.contains('ensuite')) {
            return 'Attached bathroom';
        }
        if (normalized.contains('common bathroom') || normalized.contains('shared bathroom') || normalized.contains('shared bath')) {
            return 'Common bathroom';
        }
        return null;
    }

    private static String firstNonBlank(List<String> values) {
        if (values == null) {
            return null;
        }

        for (String value : values) {
            if (String.isNotBlank(value)) {
                return value;
            }
        }
        return null;
    }

    private static String resolveTenantTypeFromWindow(Id windowId) {
        if (windowId == null) {
            return null;
        }
        if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view preference windows.');
        }

        List<Ken_Windows__c> windowRows = [
            SELECT Hostel_Cycle__c, Hostel_Cycle__r.Previous_Cycle__c
            FROM Ken_Windows__c
            WHERE Id = :windowId
            LIMIT 1
        ];
        if (windowRows.isEmpty()) {
            return null;
        }
        Ken_Windows__c windowRecord = windowRows[0];
        Boolean hasCarryForward = windowRecord.Hostel_Cycle__r != null && windowRecord.Hostel_Cycle__r.Previous_Cycle__c != null;
        return hasCarryForward ? 'Existing' : 'Incoming';
    }
}