public without sharing class HostelDashboardController {
    private static Boolean hasReadAccess(Schema.DescribeSObjectResult describeResult) {
        if (describeResult == null) {
            return false;
        }
        return shouldBypassReadAccessChecks() || describeResult.isAccessible();
    }

    private static void ensureReadable(Schema.DescribeSObjectResult describeResult, String errorMessage) {
        if (!hasReadAccess(describeResult)) {
            throw new AuraHandledException(errorMessage);
        }
    }

    private static void ensureCreateable(Schema.DescribeSObjectResult describeResult, String errorMessage) {
        if (describeResult == null || (!shouldBypassReadAccessChecks() && !describeResult.isCreateable())) {
            throw new AuraHandledException(errorMessage);
        }
    }

    private static void ensureUpdateable(Schema.DescribeSObjectResult describeResult, String errorMessage) {
        if (describeResult == null || (!shouldBypassReadAccessChecks() && !describeResult.isUpdateable())) {
            throw new AuraHandledException(errorMessage);
        }
    }

    private static void ensureDeletable(Schema.DescribeSObjectResult describeResult, String errorMessage) {
        if (describeResult == null || (!shouldBypassReadAccessChecks() && !describeResult.isDeletable())) {
            throw new AuraHandledException(errorMessage);
        }
    }

    private static Boolean shouldBypassReadAccessChecks() {
        String userType = UserInfo.getUserType();
        return String.isNotBlank(userType) && !userType.equalsIgnoreCase('Standard');
    }

    public class DashboardResponse {
        @AuraEnabled public Boolean hasAllotment { get; set; }
        @AuraEnabled public Boolean hasResidenceHistory { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public RoomDetails roomDetails { get; set; }
        @AuraEnabled public List<RoommateDetails> roommates { get; set; }
        @AuraEnabled public WardenDetails warden { get; set; }
        @AuraEnabled public String residenceAllocationTitle { get; set; }
        @AuraEnabled public String windowStartDate { get; set; }
        @AuraEnabled public String windowEndDate { get; set; }
        @AuraEnabled public Boolean canStartResidenceAllocation { get; set; }

        public DashboardResponse() {
            hasAllotment = false;
            hasResidenceHistory = false;
            message = null;
            roomDetails = new RoomDetails();
            roommates = new List<RoommateDetails>();
            warden = new WardenDetails();
            residenceAllocationTitle = 'Residence Allocation';
            windowStartDate = null;
            windowEndDate = null;
            canStartResidenceAllocation = false;
        }
    }

    public class RoomDetails {
        @AuraEnabled public String roomNumber { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public String hall { get; set; }
        @AuraEnabled public String location { get; set; }
        @AuraEnabled public String floor { get; set; }
        @AuraEnabled public String sharing { get; set; }
        @AuraEnabled public String amenities { get; set; }
    }

    public class RoommateDetails {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String studentId { get; set; }
        @AuraEnabled public String department { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String email { get; set; }
    }

    public class WardenDetails {
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String email { get; set; }
    }

    public class HostelDetailsResponse {
        @AuraEnabled public Boolean hasAllotment { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public ResidenceDetails residenceDetails { get; set; }
        @AuraEnabled public List<String> features { get; set; }
        @AuraEnabled public List<String> amenityLabels { get; set; }
        @AuraEnabled public List<ResidenceHistoryRow> residenceHistory { get; set; }
        @AuraEnabled public List<RoommateDetails> roommates { get; set; }
        @AuraEnabled public WardenDetails warden { get; set; }

        public HostelDetailsResponse() {
            hasAllotment = false;
            message = null;
            residenceDetails = new ResidenceDetails();
            features = new List<String>();
            amenityLabels = new List<String>();
            residenceHistory = new List<ResidenceHistoryRow>();
            roommates = new List<RoommateDetails>();
            warden = new WardenDetails();
        }
    }

    public class ResidenceDetails {
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String subtitle { get; set; }
        @AuraEnabled public String checkInDate { get; set; }
        @AuraEnabled public String annualFee { get; set; }
    }

    public class ResidenceHistoryRow {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String academicYear { get; set; }
        @AuraEnabled public String roomType { get; set; }
        @AuraEnabled public String roomNumber { get; set; }
        @AuraEnabled public String floor { get; set; }
        @AuraEnabled public String block { get; set; }
        @AuraEnabled public String movedIn { get; set; }
        @AuraEnabled public String movedOut { get; set; }
    }

    public class ResidenceAllocationResponse {
        @AuraEnabled public String state { get; set; }
        @AuraEnabled public Integer step { get; set; }
        @AuraEnabled public Integer preferenceCount { get; set; }
        @AuraEnabled public List<ResidencePreferenceItem> preferences { get; set; }
        @AuraEnabled public String submittedOn { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Boolean canStart { get; set; }
        @AuraEnabled public ResidenceDetails residenceDetails { get; set; }
        @AuraEnabled public RoomDetails roomDetails { get; set; }
        @AuraEnabled public List<String> features { get; set; }
        @AuraEnabled public List<String> amenityLabels { get; set; }
        @AuraEnabled public List<RoommateDetails> roommates { get; set; }
        @AuraEnabled public String paymentDeadline { get; set; }

        public ResidenceAllocationResponse() {
            state = 'initial';
            step = 1;
            preferenceCount = 0;
            preferences = new List<ResidencePreferenceItem>();
            submittedOn = null;
            message = null;
            canStart = true;
            residenceDetails = new ResidenceDetails();
            roomDetails = new RoomDetails();
            features = new List<String>();
            amenityLabels = new List<String>();
            roommates = new List<RoommateDetails>();
            paymentDeadline = null;
        }
    }

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
    }

    public class ResidenceSelectionResponse {
        @AuraEnabled public List<ResidenceCategoryItem> residences { get; set; }
        @AuraEnabled public List<ResidencePreferenceItem> selectedPreferences { get; set; }
        @AuraEnabled public Integer selectedCount { get; set; }
        @AuraEnabled public String requestStatus { get; set; }
        @AuraEnabled public String preferredPartnerEmails { get; set; }
        @AuraEnabled public Boolean allowRoommatePreference { get; set; }
        @AuraEnabled public String message { get; set; }

        public ResidenceSelectionResponse() {
            residences = new List<ResidenceCategoryItem>();
            selectedPreferences = new List<ResidencePreferenceItem>();
            selectedCount = 0;
            requestStatus = null;
            preferredPartnerEmails = null;
            allowRoommatePreference = false;
            message = null;
        }
    }

    public class ResidenceCategoryItem {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Decimal annualFee { get; set; }
        @AuraEnabled public Decimal capacity { get; set; }
        @AuraEnabled public String amenities { get; set; }
        @AuraEnabled public String sharing { get; set; }
        @AuraEnabled public String ac { get; set; }
        @AuraEnabled public String bathroom { get; set; }
        @AuraEnabled public Boolean allowRoommatePreference { get; set; }
        @AuraEnabled public List<String> floorOptions { get; set; }
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
        public List<ResolvedRoommateRow> resolvedRows { get; set; }

        public RoommateResolutionResult() {
            preferredPartnerAccountId = null;
            issues = new List<RoommateValidationIssue>();
            resolvedRows = new List<ResolvedRoommateRow>();
        }
    }

    private class RoommateMatchCandidate {
        public String email { get; set; }
        public Id accountId { get; set; }
        public Id contactId { get; set; }
    }

    private class ResolvedRoommateRow {
        public Integer order { get; set; }
        public Integer slot { get; set; }
        public String email { get; set; }
        public Id accountId { get; set; }
        public Id contactId { get; set; }
    }

    private class ActiveStudentRoles {
        public Set<Id> accountIds { get; set; }
        public Set<Id> contactIds { get; set; }

        public ActiveStudentRoles() {
            accountIds = new Set<Id>();
            contactIds = new Set<Id>();
        }
    }

    private class WindowScope {
        public Set<Id> learningProgramPlanIds { get; set; }
        public Set<String> learningProgramPlanNames { get; set; }
        public Set<Id> learningProgramIds { get; set; }
        public Set<Id> buildingIds { get; set; }
        public Set<Id> roomCategoryIds { get; set; }
        public Boolean allowRoommatePreference { get; set; }

        public WindowScope() {
            learningProgramPlanIds = new Set<Id>();
            learningProgramPlanNames = new Set<String>();
            learningProgramIds = new Set<Id>();
            buildingIds = new Set<Id>();
            roomCategoryIds = new Set<Id>();
            allowRoommatePreference = false;
        }
    }

    private class WindowDates {
        public Date startDate { get; set; }
        public Date endDate { get; set; }
        public String residenceAllocationTitle { get; set; }
    }

    private class ResidenceWindowContext {
        public Id windowId { get; set; }
        public List<Id> eligibleWindowIds { get; set; }
        public Map<Id, WindowScope> eligibleScopesByWindowId { get; set; }
        public WindowScope scope { get; set; }
        public LearnerProgram learnerProgram { get; set; }
        public Boolean hasEligibleWindow { get; set; }
        public String message { get; set; }

        public ResidenceWindowContext() {
            eligibleWindowIds = new List<Id>();
            eligibleScopesByWindowId = new Map<Id, WindowScope>();
            scope = new WindowScope();
            hasEligibleWindow = false;
            message = null;
        }
    }

    @AuraEnabled
    public static DashboardResponse getDashboardData() {
        DashboardResponse response = new DashboardResponse();

        try {
            ensureReadable(Schema.sObjectType.User, 'You do not have permission to view user details.');
            User currentUser = [
                SELECT Id, AccountId, ContactId, Email, Username, UserType
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            String normalizedUserEmail = normalizeEmail(currentUser.Email);
            if (String.isBlank(normalizedUserEmail)) {
                normalizedUserEmail = normalizeEmail(currentUser.Username);
            }

            Id accountId = resolvePersonAccountId(currentUser.AccountId, currentUser.ContactId, normalizedUserEmail);
            Id contactId = resolveContactId(currentUser.ContactId, accountId);

            WindowDates windowDates = getActiveWindowDates(accountId, contactId);
            if (windowDates != null) {
                response.residenceAllocationTitle = String.isNotBlank(windowDates.residenceAllocationTitle)
                    ? windowDates.residenceAllocationTitle
                    : response.residenceAllocationTitle;
                response.windowStartDate = formatDateForClient(windowDates.startDate);
                response.windowEndDate = formatDateForClient(windowDates.endDate);
                response.canStartResidenceAllocation = true;
            }
            System.debug('getDashboardData - windowStartDate: ' + response.windowStartDate + ', windowEndDate: ' + response.windowEndDate);

            Ken_Room_Allotment__c myAllotment = getCurrentAllotment(
                currentUser.ContactId,
                currentUser.AccountId,
                currentUser.Email,
                currentUser.Username,
                shouldAllowPreviewFallback(currentUser)
            );
            if (myAllotment == null || myAllotment.Room__c == null) {
                List<ResidenceHistoryRow> historyRows = getResidenceHistory(currentUser.AccountId, currentUser.ContactId);
                response.hasResidenceHistory = !historyRows.isEmpty();
                response.message = (currentUser.AccountId == null && currentUser.ContactId == null)
                    ? 'No contact or account is linked to this user.'
                    : 'No active housing allotment found for this user.';
                return response;
            }

            response.hasAllotment = true;
            response.hasResidenceHistory = true;
            response.roomDetails = mapRoomDetails(myAllotment);
            response.roommates = getRoommates(myAllotment.Room__c, myAllotment.Tenant_Account__c, currentUser.ContactId);
            response.warden = mapWardenDetails(myAllotment);
            return response;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load hostel dashboard data: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static HostelDetailsResponse getHostelDetailsData() {
        HostelDetailsResponse response = new HostelDetailsResponse();

        try {
            ensureReadable(Schema.sObjectType.User, 'You do not have permission to view user details.');
            User currentUser = [
                SELECT Id, AccountId, ContactId, Email, Username, UserType
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            Ken_Room_Allotment__c myAllotment = getCurrentAllotment(
                currentUser.ContactId,
                currentUser.AccountId,
                currentUser.Email,
                currentUser.Username,
                shouldAllowPreviewFallback(currentUser)
            );
            if (myAllotment == null || myAllotment.Room__c == null) {
                response.message = (currentUser.AccountId == null && currentUser.ContactId == null)
                    ? 'No contact or account is linked to this user.'
                    : 'No active housing allotment found for this user.';
                return response;
            }

            response.hasAllotment = true;
            response.residenceDetails = mapResidenceDetails(myAllotment);
            response.features = buildFeatureLabels(myAllotment);
            response.amenityLabels = buildAmenityLabels(myAllotment);
            response.residenceHistory = getResidenceHistory(myAllotment.Tenant_Account__c, currentUser.ContactId);
            response.roommates = getRoommates(myAllotment.Room__c, myAllotment.Tenant_Account__c, currentUser.ContactId);
            response.warden = mapWardenDetails(myAllotment);
            return response;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load hostel details data: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static ResidenceAllocationResponse getResidenceAllocationData() {
        ResidenceAllocationResponse response = new ResidenceAllocationResponse();

        try {
            ensureReadable(Schema.sObjectType.User, 'You do not have permission to view user details.');
            User currentUser = [
                SELECT Id, AccountId, ContactId, Email, Username, UserType
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            String normalizedUserEmail = normalizeEmail(currentUser.Email);
            if (String.isBlank(normalizedUserEmail)) {
                normalizedUserEmail = normalizeEmail(currentUser.Username);
            }

            Id accountId = resolvePersonAccountId(currentUser.AccountId, currentUser.ContactId, normalizedUserEmail);
            Id contactId = resolveContactId(currentUser.ContactId, accountId);
            Ken_Room_Request__c latestRoomRequest = getLatestRoomRequest(accountId, contactId, normalizedUserEmail, currentUser.Id);
            response.preferences = mapRoomRequestPreferences(latestRoomRequest);
            response.preferenceCount = response.preferences.size();
            response.submittedOn = latestRoomRequest != null && latestRoomRequest.CreatedDate != null
                ? latestRoomRequest.CreatedDate.format('dd MMM yyyy')
                : null;

            Ken_Room_Allotment__c currentAllotment = getCurrentAllotment(
                contactId,
                accountId,
                currentUser.Email,
                currentUser.Username,
                shouldAllowPreviewFallback(currentUser)
            );

            if (currentAllotment != null && currentAllotment.Room__c != null) {
                populateResidenceAllocationSummary(response, currentAllotment, latestRoomRequest);
                response.state = 'provisional';
                response.step = 3;
                return response;
            }

            if (latestRoomRequest == null) {
                ResidenceWindowContext residenceWindowContext = getResidenceWindowContext(accountId, contactId);
                response.message = residenceWindowContext.message;
                response.canStart = residenceWindowContext.hasEligibleWindow;
                return response;
            }

            if (isRejectedStatus(latestRoomRequest.Status__c)) {
                response.state = 'rejected';
                response.step = 2;
                return response;
            }

            if (isUnderReviewStatus(latestRoomRequest.Status__c)) {
                response.state = 'underReview';
                response.step = 2;
                return response;
            }

            if (isProvisionalStatus(latestRoomRequest.Status__c)) {
                response.state = 'provisional';
                response.step = 3;
                return response;
            }

            return response;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load residence allocation data: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static ResidenceSelectionResponse getResidencePreferenceSelectionData() {
        ResidenceSelectionResponse response = new ResidenceSelectionResponse();

        try {
            ensureReadable(Schema.sObjectType.User, 'You do not have permission to view user details.');
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
            Id contactId = resolveContactId(currentUser.ContactId, accountId);
            ResidenceWindowContext residenceWindowContext = getResidenceWindowContext(accountId, contactId);

            Ken_Room_Request__c latestRoomRequest = getLatestRoomRequest(accountId, contactId, normalizedUserEmail, currentUser.Id);
            Boolean requestWindowEligible = latestRoomRequest != null
                && latestRoomRequest.Window__c != null
                && residenceWindowContext.eligibleScopesByWindowId.containsKey(latestRoomRequest.Window__c);
            response.selectedPreferences = requestWindowEligible
                ? mapRoomRequestPreferences(latestRoomRequest)
                : new List<ResidencePreferenceItem>();
            response.selectedCount = response.selectedPreferences.size();
            response.requestStatus = latestRoomRequest != null ? latestRoomRequest.Status__c : null;
            response.preferredPartnerEmails = latestRoomRequest != null && latestRoomRequest.Preferred_Partner__r != null
                ? latestRoomRequest.Preferred_Partner__r.PersonEmail
                : null;
            response.message = residenceWindowContext.message;

            Set<Id> selectedCategoryIds = new Set<Id>();
            if (requestWindowEligible) {
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

            if (!requestWindowEligible && residenceWindowContext.hasEligibleWindow) {
                response.message = firstNonBlank(new List<String>{
                    response.message,
                    'Your previous residence preferences are not available for the current active window. Please choose preferences again.'
                });
            }

            if (!residenceWindowContext.hasEligibleWindow) {
                if (
                    response.residences.isEmpty() &&
                    response.selectedPreferences.isEmpty() &&
                    String.isBlank(response.message)
                ) {
                    response.message = 'No residence categories are available for your current residence window.';
                }
                return response;
            }

            Id scopedWindowId = residenceWindowContext.windowId;
            if (
                latestRoomRequest != null
                && latestRoomRequest.Window__c != null
                && residenceWindowContext.eligibleScopesByWindowId.containsKey(latestRoomRequest.Window__c)
            ) {
                scopedWindowId = latestRoomRequest.Window__c;
            }
            response.allowRoommatePreference = isRoommatePreferenceAllowedForWindow(
                residenceWindowContext,
                scopedWindowId
            );

            Set<Id> scopedRoomCategoryIds = new Set<Id>();
            // If multiple eligible windows are open (same learning program plan), show categories from all of them.
            // Note: saving still enforces selecting from a single window via resolveRequestWindowId().
            if (residenceWindowContext.hasEligibleWindow) {
                scopedRoomCategoryIds.addAll(residenceWindowContext.scope.roomCategoryIds);
            } else if (scopedWindowId != null && residenceWindowContext.eligibleScopesByWindowId.containsKey(scopedWindowId)) {
                scopedRoomCategoryIds.addAll(residenceWindowContext.eligibleScopesByWindowId.get(scopedWindowId).roomCategoryIds);
            }
            List<Ken_Room_Category__c> residenceCategories = queryResidenceCategories(selectedCategoryIds, scopedRoomCategoryIds);
            Map<Id, Boolean> roommatePreferenceByCategoryId = buildRoommatePreferenceByCategory(
                residenceWindowContext,
                scopedWindowId,
                residenceCategories
            );
            Map<Id, List<String>> floorOptionsByCategoryId = buildFloorOptionsByCategory(
                residenceCategories,
                residenceWindowContext,
                scopedWindowId
            );
            for (Ken_Room_Category__c category : residenceCategories) {
                response.residences.add(
                    mapResidenceCategory(
                        category,
                        roommatePreferenceByCategoryId.containsKey(category.Id)
                            ? roommatePreferenceByCategoryId.get(category.Id)
                            : response.allowRoommatePreference,
                        floorOptionsByCategoryId.containsKey(category.Id)
                            ? floorOptionsByCategoryId.get(category.Id)
                            : new List<String>()
                    )
                );
            }

            if (
                response.residences.isEmpty() &&
                response.selectedPreferences.isEmpty() &&
                String.isBlank(response.message)
            ) {
                response.message = 'No residence categories are available for your current residence window.';
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
            ensureReadable(Schema.sObjectType.User, 'You do not have permission to view user details.');

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
            Id contactId = resolveContactId(currentUser.ContactId, accountId);
            if (contactId == null) {
                throw new AuraHandledException('No contact is linked to this user.');
            }

            if (normalizedSelections.isEmpty()) {
                if (submitRequest == true) {
                    response.message = 'Select at least one residence preference.';
                    return response;
                }

                Ken_Room_Request__c requestRecord = getLatestRoomRequest(accountId, contactId, normalizedUserEmail, currentUser.Id);
                if (requestRecord != null) {
                    requestRecord.Request_By__c = accountId;
                    requestRecord.Requested_By__c = contactId;
                    clearResidencePreferenceFields(requestRecord);
                    requestRecord.Window__c = null;
                    requestRecord.Tenant_type__c = null;
                    requestRecord.Preferred_Partner__c = null;
                    requestRecord.Status__c = null;

                    ensureUpdateable(Schema.sObjectType.Ken_Room_Request__c, 'You do not have permission to update room requests.');
                    update requestRecord;
                    syncRequestRoommates(requestRecord.Id, new List<ResolvedRoommateRow>());
                }

                response.success = true;
                response.selectedCount = 0;
                response.status = null;
                response.message = 'Preferences updated successfully.';
                return response;
            }

            // Normalize to contiguous ranks (1..N) to avoid gaps like only Preference 2/3 being set,
            // which can break org-level validation rules/triggers.
            Map<Integer, List<Id>> categoryIdsByRequestedOrder = new Map<Integer, List<Id>>{
                1 => new List<Id>(),
                2 => new List<Id>(),
                3 => new List<Id>()
            };
            Map<String, String> floorByOrderAndCategory = new Map<String, String>();
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
                floorByOrderAndCategory.put(key, item.floor);
                roommateEmailsByOrderAndCategory.put(key, item.roommateEmails != null ? item.roommateEmails : new List<String>());
            }

            Integer nextOrder = 1;
            Set<Id> seenCategoryIds = new Set<Id>();
            Map<Integer, String> floorByOrder = new Map<Integer, String>();
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
                    floorByOrder.put(nextOrder, floorByOrderAndCategory.get(key));
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

            Set<Id> uniqueCategoryIds = new Set<Id>();
            uniqueCategoryIds.addAll(preferenceByOrder.values());
            if (uniqueCategoryIds.size() != preferenceByOrder.size()) {
                response.message = 'You can’t select the same room category more than once.';
                return response;
            }

            String missingFloorMessage = getMissingFloorPreferenceMessage(preferenceByOrder, floorByOrder);
            if (String.isNotBlank(missingFloorMessage)) {
                response.message = missingFloorMessage;
                return response;
            }

            String duplicateFloorMessage = getDuplicateFloorPreferenceMessage(floorByOrder);
            if (String.isNotBlank(duplicateFloorMessage)) {
                response.message = duplicateFloorMessage;
                return response;
            }

            ResidenceWindowContext residenceWindowContext = getResidenceWindowContext(accountId, contactId);
            if (!residenceWindowContext.hasEligibleWindow) {
                response.message = firstNonBlank(new List<String>{
                    residenceWindowContext.message,
                    'No eligible residence preference window is available for your learning program plan.'
                });
                return response;
            }

            if (!areRequestedCategoriesEligible(preferenceByOrder.values(), residenceWindowContext.scope.roomCategoryIds)) {
                response.message = 'Selected residence preferences are not available for your eligible residence window.';
                return response;
            }

            Ken_Room_Request__c requestRecord = getLatestRoomRequest(accountId, contactId, normalizedUserEmail, currentUser.Id);
            if (requestRecord == null) {
                requestRecord = new Ken_Room_Request__c();
            }

            requestRecord.Request_By__c = accountId;
            requestRecord.Requested_By__c = contactId;
            requestRecord.Preference_1__c = preferenceByOrder.containsKey(1) ? preferenceByOrder.get(1) : null;
            requestRecord.Preference_2__c = preferenceByOrder.containsKey(2) ? preferenceByOrder.get(2) : null;
            requestRecord.Preference_3__c = preferenceByOrder.containsKey(3) ? preferenceByOrder.get(3) : null;
            Id resolvedWindowId = resolveRequestWindowId(
                residenceWindowContext,
                new List<Id>(preferenceByOrder.values()),
                requestRecord.Window__c
            );
            if (resolvedWindowId == null) {
                response.message = 'Selected residence preferences belong to different active windows. Select preferences from a single active window.';
                return response;
            }
            requestRecord.Window__c = resolvedWindowId;
            if (requestRecord.Window__c == null) {
                requestRecord.Window__c = resolveCurrentPreferenceWindowId();
            }
            Boolean allowRoommatePreference = isRoommatePreferenceAllowedForWindow(
                residenceWindowContext,
                requestRecord.Window__c
            );
            WindowScope requestWindowScope = requestRecord.Window__c != null &&
                residenceWindowContext.eligibleScopesByWindowId.containsKey(requestRecord.Window__c)
                ? residenceWindowContext.eligibleScopesByWindowId.get(requestRecord.Window__c)
                : new WindowScope();
            String invalidFloorMessage = getInvalidFloorPreferenceMessage(
                preferenceByOrder,
                floorByOrder,
                requestWindowScope
            );
            if (String.isNotBlank(invalidFloorMessage)) {
                response.message = invalidFloorMessage;
                return response;
            }
            if (allowRoommatePreference) {
                List<RoommateValidationIssue> missingRoommateIssues = getMissingRoommateEmailIssues(
                    preferenceByOrder,
                    roommateEmailsByOrder
                );
                if (!missingRoommateIssues.isEmpty()) {
                    response.message = 'Please correct the roommate details and try again.';
                    response.roommateIssues.addAll(missingRoommateIssues);
                    return response;
                }
            }
            RoommateResolutionResult roommateResolution = allowRoommatePreference
                ? resolveRoommateResolution(preferenceByOrder, roommateEmailsByOrder, requestWindowScope)
                : new RoommateResolutionResult();
            if (!roommateResolution.issues.isEmpty()) {
                response.message = 'Please correct the roommate details and try again.';
                response.roommateIssues.addAll(roommateResolution.issues);
                return response;
            }
            setFloorAndRoommateFields(
                requestRecord,
                floorByOrder,
                allowRoommatePreference ? roommateEmailsByOrder : null
            );
            requestRecord.Preferred_Partner__c = allowRoommatePreference
                ? roommateResolution.preferredPartnerAccountId
                : null;
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
                ensureCreateable(Schema.sObjectType.Ken_Room_Request__c, 'You do not have permission to create room requests.');
                insert requestRecord;
            } else {
                ensureUpdateable(Schema.sObjectType.Ken_Room_Request__c, 'You do not have permission to update room requests.');
                update requestRecord;
            }
            syncRequestRoommates(
                requestRecord.Id,
                allowRoommatePreference ? roommateResolution.resolvedRows : new List<ResolvedRoommateRow>()
            );

            response.success = true;
            response.selectedCount = preferenceByOrder.size();
            response.status = requestRecord.Status__c;
            response.message = submitRequest == true
                ? 'Residence request submitted successfully.'
                : 'Draft saved successfully.';
            return response;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to save residence preferences: ' + e.getMessage());
        }
    }

    private static void clearResidencePreferenceFields(Ken_Room_Request__c requestRecord) {
        if (requestRecord == null) {
            return;
        }

        requestRecord.Preference_1__c = null;
        requestRecord.Preference_2__c = null;
        requestRecord.Preference_3__c = null;
        requestRecord.Floor_Preference_1__c = null;
        requestRecord.Floor_Preference_2__c = null;
        requestRecord.Floor_Preference_3__c = null;
        requestRecord.Preference_1_Roommate_Email_1__c = null;
        requestRecord.Preference_1_Roommate_Email_2__c = null;
        requestRecord.Preference_2_Roommate_Email_1__c = null;
        requestRecord.Preference_2_Roommate_Email_2__c = null;
        requestRecord.Preference_3_Roommate_Email_1__c = null;
        requestRecord.Preference_3_Roommate_Email_2__c = null;
    }

    private static void setFloorAndRoommateFields(
        Ken_Room_Request__c requestRecord,
        Map<Integer, String> floorByOrder,
        Map<Integer, List<String>> roommateEmailsByOrder
    ) {
        for (Integer order = 1; order <= 3; order++) {
            String floor = floorByOrder != null && floorByOrder.containsKey(order) ? floorByOrder.get(order) : null;
            List<String> emails = roommateEmailsByOrder != null && roommateEmailsByOrder.containsKey(order)
                ? roommateEmailsByOrder.get(order)
                : new List<String>();
            String email1 = (emails != null && emails.size() > 0) ? toNonBlank(emails[0]) : null;
            String email2 = (emails != null && emails.size() > 1) ? toNonBlank(emails[1]) : null;
            if (order == 1) {
                requestRecord.Floor_Preference_1__c = toNonBlank(floor);
                requestRecord.Preference_1_Roommate_Email_1__c = email1;
                requestRecord.Preference_1_Roommate_Email_2__c = email2;
            } else if (order == 2) {
                requestRecord.Floor_Preference_2__c = toNonBlank(floor);
                requestRecord.Preference_2_Roommate_Email_1__c = email1;
                requestRecord.Preference_2_Roommate_Email_2__c = email2;
            } else {
                requestRecord.Floor_Preference_3__c = toNonBlank(floor);
                requestRecord.Preference_3_Roommate_Email_1__c = email1;
                requestRecord.Preference_3_Roommate_Email_2__c = email2;
            }
        }
    }

    private static String toNonBlank(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.length() > 0 ? trimmed : null;
    }

    private static String getDuplicateFloorPreferenceMessage(Map<Integer, String> floorByOrder) {
        if (floorByOrder == null || floorByOrder.isEmpty()) {
            return null;
        }

        Set<String> seenFloors = new Set<String>();
        for (Integer order = 1; order <= 3; order += 1) {
            String normalizedFloor = normalizeFloorPreferenceForComparison(
                floorByOrder.containsKey(order) ? floorByOrder.get(order) : null
            );
            if (String.isBlank(normalizedFloor)) {
                continue;
            }
            if (seenFloors.contains(normalizedFloor)) {
                return 'The same floor preference cannot be selected for multiple preferences.';
            }
            seenFloors.add(normalizedFloor);
        }

        return null;
    }

    private static String getInvalidFloorPreferenceMessage(
        Map<Integer, Id> preferenceByOrder,
        Map<Integer, String> floorByOrder,
        WindowScope scope
    ) {
        if (
            preferenceByOrder == null ||
            preferenceByOrder.isEmpty() ||
            floorByOrder == null ||
            floorByOrder.isEmpty()
        ) {
            return null;
        }

        Set<Id> categoryIds = new Set<Id>();
        categoryIds.addAll(preferenceByOrder.values());
        Map<Id, Set<String>> floorOptionsByCategoryId = getFloorOptionValuesByCategory(categoryIds, scope);

        for (Integer order = 1; order <= 3; order += 1) {
            if (!preferenceByOrder.containsKey(order)) {
                continue;
            }

            String selectedFloor = floorByOrder.containsKey(order) ? floorByOrder.get(order) : null;
            String normalizedSelectedFloor = normalizeFloorOptionValue(selectedFloor);
            if (String.isBlank(normalizedSelectedFloor)) {
                continue;
            }

            Id categoryId = preferenceByOrder.get(order);
            Set<String> allowedFloorValues = floorOptionsByCategoryId.containsKey(categoryId)
                ? floorOptionsByCategoryId.get(categoryId)
                : new Set<String>();
            if (allowedFloorValues.contains(normalizedSelectedFloor)) {
                continue;
            }

            return 'Floor ' + selectedFloor + ' is not available for Preference ' + String.valueOf(order) + '.';
        }

        return null;
    }

    private static String getMissingFloorPreferenceMessage(
        Map<Integer, Id> preferenceByOrder,
        Map<Integer, String> floorByOrder
    ) {
        if (preferenceByOrder == null || preferenceByOrder.isEmpty()) {
            return null;
        }

        for (Integer order = 1; order <= 3; order += 1) {
            if (!preferenceByOrder.containsKey(order)) {
                continue;
            }

            String normalizedFloor = normalizeFloorPreferenceForComparison(
                floorByOrder != null && floorByOrder.containsKey(order)
                    ? floorByOrder.get(order)
                    : null
            );
            if (String.isBlank(normalizedFloor)) {
                return 'Please select a floor preference for Preference ' + String.valueOf(order) + '.';
            }
        }

        return null;
    }

    private static List<RoommateValidationIssue> getMissingRoommateEmailIssues(
        Map<Integer, Id> preferenceByOrder,
        Map<Integer, List<String>> roommateEmailsByOrder
    ) {
        List<RoommateValidationIssue> issues = new List<RoommateValidationIssue>();
        if (preferenceByOrder == null || preferenceByOrder.isEmpty()) {
            return issues;
        }

        for (Integer order = 1; order <= 3; order += 1) {
            if (!preferenceByOrder.containsKey(order)) {
                continue;
            }

            List<String> roommateEmails = roommateEmailsByOrder != null && roommateEmailsByOrder.containsKey(order)
                ? roommateEmailsByOrder.get(order)
                : null;
            Boolean hasRoommateEmail = false;
            if (roommateEmails != null) {
                for (String roommateEmail : roommateEmails) {
                    if (String.isNotBlank(normalizeEmail(roommateEmail))) {
                        hasRoommateEmail = true;
                        break;
                    }
                }
            }

            if (hasRoommateEmail) {
                continue;
            }

            RoommateValidationIssue issue = new RoommateValidationIssue();
            issue.residenceId = String.valueOf(preferenceByOrder.get(order));
            issue.order = order;
            issue.slot = 1;
            issue.message = 'At least one roommate email is mandatory for Preference ' + String.valueOf(order) + '.';
            issues.add(issue);
        }

        return issues;
    }

    private static String normalizeFloorPreferenceForComparison(String value) {
        String normalized = normalizeFloorOptionValue(value);
        if (String.isBlank(normalized) || normalized == 'no preference' || normalized == 'select floor') {
            return null;
        }
        return normalized;
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
            selected = pickBestAllotment(queryAllotmentsByContactId(contactId));
            if (selected != null) {
                return selected;
            }
        }

        if (accountId != null) {
            selected = pickBestAllotment(queryAllotmentsByAccountId(accountId));
            if (selected != null) {
                return selected;
            }
        }

        String normalizedUserEmail = normalizeEmail(userEmail);
        if (String.isBlank(normalizedUserEmail)) {
            normalizedUserEmail = normalizeEmail(username);
        }

        if (String.isNotBlank(normalizedUserEmail)) {
            selected = pickBestAllotment(queryAllotmentsByAccountEmail(normalizedUserEmail));
            if (selected != null) {
                return selected;
            }
        }

        // Experience Builder editor runs as an internal standard user (without account context).
        if (allowPreviewFallback == true) {
            selected = pickBestAllotment(queryActiveAllotmentsForPreview());
            if (selected != null) {
                return selected;
            }
        }

        return null;
    }

    private static Boolean shouldAllowPreviewFallback(User currentUser) {
        if (currentUser == null || String.isBlank(currentUser.UserType)) {
            return false;
        }

        // Only allow sample-data preview for internal builder/admin usage with no linked account.
        // Experience Cloud students must never fall back to another student's live allotment.
        return currentUser.UserType == 'Standard' && currentUser.AccountId == null;
    }

    private static Ken_Room_Request__c getLatestRoomRequest(
        Id accountId,
        Id contactId,
        String normalizedUserEmail,
        Id userId
    ) {
        if (contactId != null) {
            return queryLatestRoomRequestByContact(contactId);
        }

        Ken_Room_Request__c latestRequest;
        if (accountId != null) {
            latestRequest = queryLatestRoomRequestByAccount(accountId);
            if (latestRequest != null) {
                return latestRequest;
            }
        }

        if (userId != null) {
            latestRequest = queryLatestRoomRequestByCreatedBy(userId);
            if (latestRequest != null) {
                return latestRequest;
            }
        }

        // Email-based fallback is intentionally avoided here.
        // It can match another user's request when portal user mapping is incomplete.
        return null;
    }

    private static Ken_Room_Request__c queryLatestRoomRequestByContact(Id contactId) {
        ensureReadable(Schema.sObjectType.Ken_Room_Request__c, 'You do not have permission to view room requests.');
        List<Ken_Room_Request__c> rows = [
            SELECT Id, Name, CreatedDate, Status__c, Window__c, Preferred_Partner__c,
                Preferred_Partner__r.PersonEmail,
                Requested_By__c,
                Preference_1__c, Preference_2__c, Preference_3__c,
                Preference_1_Category__c, Preference_2_Category__c, Preference_3_Category__c,
                Floor_Preference_1__c, Floor_Preference_2__c, Floor_Preference_3__c,
                Preference_1_Roommate_Email_1__c, Preference_1_Roommate_Email_2__c,
                Preference_2_Roommate_Email_1__c, Preference_2_Roommate_Email_2__c,
                Preference_3_Roommate_Email_1__c, Preference_3_Roommate_Email_2__c,
                Preference_1__r.Name,
                Preference_1__r.Name__c,
                Preference_1__r.Capacity__c,
                Preference_1__r.Sharing__c,
                Preference_1__r.Ac_Non_Ac__c,
                Preference_1__r.Bathroom__c,
                Preference_1__r.Amenities__c,
                Preference_2__r.Name,
                Preference_2__r.Name__c,
                Preference_2__r.Capacity__c,
                Preference_2__r.Sharing__c,
                Preference_2__r.Ac_Non_Ac__c,
                Preference_2__r.Bathroom__c,
                Preference_2__r.Amenities__c,
                Preference_3__r.Name,
                Preference_3__r.Name__c,
                Preference_3__r.Capacity__c,
                Preference_3__r.Sharing__c,
                Preference_3__r.Ac_Non_Ac__c,
                Preference_3__r.Bathroom__c,
                Preference_3__r.Amenities__c
            FROM Ken_Room_Request__c
            WHERE Requested_By__c = :contactId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static Ken_Room_Request__c queryLatestRoomRequestByAccount(Id accountId) {
        ensureReadable(Schema.sObjectType.Ken_Room_Request__c, 'You do not have permission to view room requests.');
        List<Ken_Room_Request__c> rows = [
            SELECT Id, Name, CreatedDate, Status__c, Window__c, Preferred_Partner__c,
                Preferred_Partner__r.PersonEmail,
                Preference_1__c, Preference_2__c, Preference_3__c,
                Preference_1_Category__c, Preference_2_Category__c, Preference_3_Category__c,
                Floor_Preference_1__c, Floor_Preference_2__c, Floor_Preference_3__c,
                Preference_1_Roommate_Email_1__c, Preference_1_Roommate_Email_2__c,
                Preference_2_Roommate_Email_1__c, Preference_2_Roommate_Email_2__c,
                Preference_3_Roommate_Email_1__c, Preference_3_Roommate_Email_2__c,
                Preference_1__r.Name,
                Preference_1__r.Name__c,
                Preference_1__r.Capacity__c,
                Preference_1__r.Sharing__c,
                Preference_1__r.Ac_Non_Ac__c,
                Preference_1__r.Bathroom__c,
                Preference_1__r.Amenities__c,
                Preference_2__r.Name,
                Preference_2__r.Name__c,
                Preference_2__r.Capacity__c,
                Preference_2__r.Sharing__c,
                Preference_2__r.Ac_Non_Ac__c,
                Preference_2__r.Bathroom__c,
                Preference_2__r.Amenities__c,
                Preference_3__r.Name,
                Preference_3__r.Name__c,
                Preference_3__r.Capacity__c,
                Preference_3__r.Sharing__c,
                Preference_3__r.Ac_Non_Ac__c,
                Preference_3__r.Bathroom__c,
                Preference_3__r.Amenities__c
            FROM Ken_Room_Request__c
            WHERE Request_By__c = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static Ken_Room_Request__c queryLatestRoomRequestByEmail(String normalizedUserEmail) {
        ensureReadable(Schema.sObjectType.Ken_Room_Request__c, 'You do not have permission to view room requests.');
        List<Ken_Room_Request__c> rows = [
            SELECT Id, Name, CreatedDate, Status__c, Window__c, Preferred_Partner__c,
                Preferred_Partner__r.PersonEmail,
                Preference_1__c, Preference_2__c, Preference_3__c,
                Preference_1_Category__c, Preference_2_Category__c, Preference_3_Category__c,
                Floor_Preference_1__c, Floor_Preference_2__c, Floor_Preference_3__c,
                Preference_1_Roommate_Email_1__c, Preference_1_Roommate_Email_2__c,
                Preference_2_Roommate_Email_1__c, Preference_2_Roommate_Email_2__c,
                Preference_3_Roommate_Email_1__c, Preference_3_Roommate_Email_2__c,
                Preference_1__r.Name,
                Preference_1__r.Name__c,
                Preference_1__r.Capacity__c,
                Preference_1__r.Sharing__c,
                Preference_1__r.Ac_Non_Ac__c,
                Preference_1__r.Bathroom__c,
                Preference_1__r.Amenities__c,
                Preference_2__r.Name,
                Preference_2__r.Name__c,
                Preference_2__r.Capacity__c,
                Preference_2__r.Sharing__c,
                Preference_2__r.Ac_Non_Ac__c,
                Preference_2__r.Bathroom__c,
                Preference_2__r.Amenities__c,
                Preference_3__r.Name,
                Preference_3__r.Name__c,
                Preference_3__r.Capacity__c,
                Preference_3__r.Sharing__c,
                Preference_3__r.Ac_Non_Ac__c,
                Preference_3__r.Bathroom__c,
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
        ensureReadable(Schema.sObjectType.Ken_Room_Request__c, 'You do not have permission to view room requests.');
        List<Ken_Room_Request__c> rows = [
            SELECT Id, Name, CreatedDate, Status__c, Window__c, Preferred_Partner__c,
                Preferred_Partner__r.PersonEmail,
                Preference_1__c, Preference_2__c, Preference_3__c,
                Preference_1_Category__c, Preference_2_Category__c, Preference_3_Category__c,
                Floor_Preference_1__c, Floor_Preference_2__c, Floor_Preference_3__c,
                Preference_1_Roommate_Email_1__c, Preference_1_Roommate_Email_2__c,
                Preference_2_Roommate_Email_1__c, Preference_2_Roommate_Email_2__c,
                Preference_3_Roommate_Email_1__c, Preference_3_Roommate_Email_2__c,
                Preference_1__r.Name,
                Preference_1__r.Name__c,
                Preference_1__r.Capacity__c,
                Preference_1__r.Sharing__c,
                Preference_1__r.Ac_Non_Ac__c,
                Preference_1__r.Bathroom__c,
                Preference_1__r.Amenities__c,
                Preference_2__r.Name,
                Preference_2__r.Name__c,
                Preference_2__r.Capacity__c,
                Preference_2__r.Sharing__c,
                Preference_2__r.Ac_Non_Ac__c,
                Preference_2__r.Bathroom__c,
                Preference_2__r.Amenities__c,
                Preference_3__r.Name,
                Preference_3__r.Name__c,
                Preference_3__r.Capacity__c,
                Preference_3__r.Sharing__c,
                Preference_3__r.Ac_Non_Ac__c,
                Preference_3__r.Bathroom__c,
                Preference_3__r.Amenities__c
            FROM Ken_Room_Request__c
            WHERE CreatedById = :userId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static List<Ken_Room_Category__c> queryResidenceCategories(
        Set<Id> selectedCategoryIds,
        Set<Id> scopedRoomCategoryIds
    ) {
        Set<Id> safeSelectedIds = selectedCategoryIds == null ? new Set<Id>() : selectedCategoryIds;
        Set<Id> safeScopedIds = scopedRoomCategoryIds == null ? new Set<Id>() : scopedRoomCategoryIds;
        ensureReadable(Schema.sObjectType.Ken_Room_Category__c, 'You do not have permission to view room categories.');

        List<Ken_Room_Category__c> categories;
        if (!safeScopedIds.isEmpty()) {
            categories = [
                SELECT Id, Name, Name__c, Capacity__c, Sharing__c, Ac_Non_Ac__c, Bathroom__c, Amenities__c, Total_Price__c, Premium_Price__c, Base_Price__c, Active__c
                FROM Ken_Room_Category__c
                WHERE (Active__c = true AND Id IN :safeScopedIds)
                    OR Id IN :safeSelectedIds
                ORDER BY Active__c DESC, CreatedDate ASC
                LIMIT 50
            ];
        } else {
            categories = [
                SELECT Id, Name, Name__c, Capacity__c, Sharing__c, Ac_Non_Ac__c, Bathroom__c, Amenities__c, Total_Price__c, Premium_Price__c, Base_Price__c, Active__c
                FROM Ken_Room_Category__c
                WHERE Active__c = true
                    OR Id IN :safeSelectedIds
                ORDER BY Active__c DESC, CreatedDate ASC
                LIMIT 50
            ];
        }

        return categories;
    }

    private static Map<Id, Boolean> buildRoommatePreferenceByCategory(
        ResidenceWindowContext context,
        Id preferredWindowId,
        List<Ken_Room_Category__c> categories
    ) {
        Map<Id, Boolean> response = new Map<Id, Boolean>();
        if (context == null || categories == null || categories.isEmpty()) {
            return response;
        }

        Set<Id> categoryIds = new Set<Id>();
        for (Ken_Room_Category__c category : categories) {
            if (category != null && category.Id != null) {
                categoryIds.add(category.Id);
            }
        }
        if (categoryIds.isEmpty()) {
            return response;
        }

        List<Id> orderedWindowIds = new List<Id>();
        if (
            preferredWindowId != null &&
            context.eligibleScopesByWindowId != null &&
            context.eligibleScopesByWindowId.containsKey(preferredWindowId)
        ) {
            orderedWindowIds.add(preferredWindowId);
        }
        if (context.eligibleWindowIds != null) {
            for (Id windowId : context.eligibleWindowIds) {
                if (windowId != null && !orderedWindowIds.contains(windowId)) {
                    orderedWindowIds.add(windowId);
                }
            }
        }

        for (Id windowId : orderedWindowIds) {
            WindowScope scope = context.eligibleScopesByWindowId.get(windowId);
            if (scope == null || scope.roomCategoryIds == null || scope.roomCategoryIds.isEmpty()) {
                continue;
            }
            for (Id categoryId : scope.roomCategoryIds) {
                if (
                    categoryId == null ||
                    response.containsKey(categoryId) ||
                    !categoryIds.contains(categoryId)
                ) {
                    continue;
                }
                response.put(categoryId, scope.allowRoommatePreference == true);
            }
        }

        return response;
    }

    private static Map<Id, List<String>> buildFloorOptionsByCategory(
        List<Ken_Room_Category__c> categories,
        ResidenceWindowContext context,
        Id preferredWindowId
    ) {
        Map<Id, List<String>> response = new Map<Id, List<String>>();
        if (categories == null || categories.isEmpty()) {
            return response;
        }
        ensureReadable(Schema.sObjectType.Ken_Room__c, 'You do not have permission to view rooms.');

        Set<Id> categoryIds = new Set<Id>();
        for (Ken_Room_Category__c category : categories) {
            if (category != null && category.Id != null) {
                categoryIds.add(category.Id);
                response.put(category.Id, new List<String>());
            }
        }
        if (categoryIds.isEmpty() || context == null || context.eligibleScopesByWindowId == null) {
            return response;
        }

        List<Id> orderedWindowIds = new List<Id>();
        if (
            preferredWindowId != null &&
            context.eligibleScopesByWindowId.containsKey(preferredWindowId)
        ) {
            orderedWindowIds.add(preferredWindowId);
        }
        if (context.eligibleWindowIds != null) {
            for (Id windowId : context.eligibleWindowIds) {
                if (windowId != null && !orderedWindowIds.contains(windowId)) {
                    orderedWindowIds.add(windowId);
                }
            }
        }
        if (orderedWindowIds.isEmpty()) {
            return response;
        }

        List<WindowScope> eligibleScopes = new List<WindowScope>();
        Set<Id> buildingIds = new Set<Id>();
        Boolean hasBuildingRestriction = false;
        for (Id windowId : orderedWindowIds) {
            WindowScope scope = context.eligibleScopesByWindowId.get(windowId);
            if (scope == null || scope.roomCategoryIds == null || scope.roomCategoryIds.isEmpty()) {
                continue;
            }
            eligibleScopes.add(scope);
            if (scope.buildingIds != null && !scope.buildingIds.isEmpty()) {
                hasBuildingRestriction = true;
                buildingIds.addAll(scope.buildingIds);
            }
        }
        if (eligibleScopes.isEmpty()) {
            return response;
        }

        List<Ken_Room__c> roomRows;
        if (hasBuildingRestriction) {
            roomRows = [
                SELECT Room_Category__c, Building__c, Floor__r.Name
                FROM Ken_Room__c
                WHERE Room_Category__c IN :categoryIds
                    AND Building__c IN :buildingIds
                LIMIT 5000
            ];
        } else {
            roomRows = [
                SELECT Room_Category__c, Building__c, Floor__r.Name
                FROM Ken_Room__c
                WHERE Room_Category__c IN :categoryIds
                LIMIT 5000
            ];
        }

        Map<Id, Set<String>> floorLabelsByCategoryId = new Map<Id, Set<String>>();
        for (Id categoryId : categoryIds) {
            floorLabelsByCategoryId.put(categoryId, new Set<String>());
        }

        for (Ken_Room__c roomRow : roomRows) {
            if (roomRow == null || roomRow.Room_Category__c == null) {
                continue;
            }

            String floorLabel = normalizeFloorOptionLabel(
                roomRow.Floor__r != null ? roomRow.Floor__r.Name : null
            );
            if (String.isBlank(floorLabel)) {
                continue;
            }

            for (WindowScope scope : eligibleScopes) {
                if (
                    scope == null ||
                    scope.roomCategoryIds == null ||
                    !scope.roomCategoryIds.contains(roomRow.Room_Category__c)
                ) {
                    continue;
                }
                if (
                    scope.buildingIds != null &&
                    !scope.buildingIds.isEmpty() &&
                    (roomRow.Building__c == null || !scope.buildingIds.contains(roomRow.Building__c))
                ) {
                    continue;
                }
                floorLabelsByCategoryId.get(roomRow.Room_Category__c).add(floorLabel);
                break;
            }
        }

        for (Id categoryId : floorLabelsByCategoryId.keySet()) {
            List<String> floorLabels = new List<String>(floorLabelsByCategoryId.get(categoryId));
            floorLabels.sort();
            response.put(categoryId, floorLabels);
        }

        return response;
    }

    private static Map<Id, Set<String>> getFloorOptionValuesByCategory(
        Set<Id> categoryIds,
        WindowScope scope
    ) {
        Map<Id, Set<String>> response = new Map<Id, Set<String>>();
        if (categoryIds == null || categoryIds.isEmpty()) {
            return response;
        }
        ensureReadable(Schema.sObjectType.Ken_Room__c, 'You do not have permission to view rooms.');

        for (Id categoryId : categoryIds) {
            if (categoryId != null) {
                response.put(categoryId, new Set<String>());
            }
        }

        List<Ken_Room__c> roomRows;
        if (scope != null && scope.buildingIds != null && !scope.buildingIds.isEmpty()) {
            Set<Id> scopedBuildingIds = new Set<Id>();
            scopedBuildingIds.addAll(scope.buildingIds);
            roomRows = [
                SELECT Room_Category__c, Floor__r.Name
                FROM Ken_Room__c
                WHERE Room_Category__c IN :categoryIds
                    AND Building__c IN :scopedBuildingIds
                LIMIT 5000
            ];
        } else {
            roomRows = [
                SELECT Room_Category__c, Floor__r.Name
                FROM Ken_Room__c
                WHERE Room_Category__c IN :categoryIds
                LIMIT 5000
            ];
        }

        for (Ken_Room__c roomRow : roomRows) {
            if (
                roomRow == null ||
                roomRow.Room_Category__c == null ||
                (scope != null &&
                    scope.roomCategoryIds != null &&
                    !scope.roomCategoryIds.isEmpty() &&
                    !scope.roomCategoryIds.contains(roomRow.Room_Category__c))
            ) {
                continue;
            }

            String normalizedFloorValue = normalizeFloorOptionValue(
                roomRow.Floor__r != null ? roomRow.Floor__r.Name : null
            );
            if (String.isBlank(normalizedFloorValue) || !response.containsKey(roomRow.Room_Category__c)) {
                continue;
            }

            response.get(roomRow.Room_Category__c).add(normalizedFloorValue);
        }

        return response;
    }

    private static Boolean isRoommatePreferenceAllowedForWindow(
        ResidenceWindowContext context,
        Id windowId
    ) {
        if (
            context == null ||
            windowId == null ||
            context.eligibleScopesByWindowId == null ||
            !context.eligibleScopesByWindowId.containsKey(windowId)
        ) {
            return false;
        }
        WindowScope scope = context.eligibleScopesByWindowId.get(windowId);
        return scope != null && scope.allowRoommatePreference == true;
    }

    private static ResidenceCategoryItem mapResidenceCategory(
        Ken_Room_Category__c category,
        Boolean allowRoommatePreference,
        List<String> floorOptions
    ) {
        ResidenceCategoryItem row = new ResidenceCategoryItem();
        if (category == null) {
            return row;
        }

        row.id = String.valueOf(category.Id);
        row.name = firstNonBlank(new List<String>{ category.Name__c, category.Name });
        row.capacity = category.Capacity__c;
        row.amenities = category.Amenities__c;
        row.sharing = resolveResidenceCategorySharing(category);
        row.ac = resolveResidenceCategoryAc(category);
        row.bathroom = resolveResidenceCategoryBathroom(category);
        row.annualFee = resolveCategoryFee(category);
        row.allowRoommatePreference = allowRoommatePreference == true;
        row.floorOptions = floorOptions != null ? floorOptions : new List<String>();
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

    private static Id resolvePersonAccountId(
        Id directAccountId,
        Id directContactId,
        String normalizedUserEmail
    ) {
        ensureReadable(Schema.sObjectType.Account, 'You do not have permission to view accounts.');
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

        return queryAccountIdByPersonEmail(normalizedUserEmail);
    }

    private static Id resolveContactId(Id directContactId, Id accountId) {
        if (directContactId != null) {
            return directContactId;
        }
        if (accountId == null) {
            return null;
        }
        ensureReadable(Schema.sObjectType.Account, 'You do not have permission to view accounts.');

        List<Account> accountRows = [
            SELECT PersonContactId
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        return accountRows.isEmpty() ? null : accountRows[0].PersonContactId;
    }

    private static Id queryAccountIdByPersonEmail(String normalizedUserEmail) {
        if (String.isBlank(normalizedUserEmail)) {
            return null;
        }
        ensureReadable(Schema.sObjectType.Account, 'You do not have permission to view accounts.');

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

    private static Id toId(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }

        try {
            return (Id) rawValue;
        } catch (Exception e) {
            return null;
        }
    }

    private static void appendEmails(List<String> targetEmails, List<String> sourceEmails) {
        if (targetEmails == null || sourceEmails == null) {
            return;
        }

        Set<String> existing = new Set<String>();
        for (String emailItem : targetEmails) {
            if (String.isNotBlank(emailItem)) {
                existing.add(emailItem.toLowerCase());
            }
        }

        for (String rawEmail : sourceEmails) {
            String normalized = normalizeEmail(rawEmail);
            if (String.isBlank(normalized) || existing.contains(normalized)) {
                continue;
            }

            targetEmails.add(normalized);
            existing.add(normalized);
        }
    }

    private static RoommateResolutionResult resolveRoommateResolution(
        Map<Integer, Id> preferenceByOrder,
        Map<Integer, List<String>> roommateEmailsByOrder,
        WindowScope scope
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
        ensureReadable(Schema.sObjectType.Account, 'You do not have permission to view accounts.');
        ensureReadable(Schema.sObjectType.Contact, 'You do not have permission to view contacts.');

        Map<String, RoommateMatchCandidate> candidateByEmail = new Map<String, RoommateMatchCandidate>();
        Set<Id> matchedAccountIds = new Set<Id>();
        Set<Id> matchedContactIds = new Set<Id>();

        for (Account accountRow : [
            SELECT Id, PersonContactId, PersonEmail
            FROM Account
            WHERE IsPersonAccount = true
                AND PersonEmail IN :uniqueEmails
            LIMIT 200
        ]) {
            String normalizedAccountEmail = normalizeEmail(accountRow.PersonEmail);
            if (String.isBlank(normalizedAccountEmail) || candidateByEmail.containsKey(normalizedAccountEmail)) {
                continue;
            }

            RoommateMatchCandidate candidate = new RoommateMatchCandidate();
            candidate.email = normalizedAccountEmail;
            candidate.accountId = accountRow.Id;
            candidate.contactId = accountRow.PersonContactId;
            candidateByEmail.put(normalizedAccountEmail, candidate);
            matchedAccountIds.add(accountRow.Id);
            if (accountRow.PersonContactId != null) {
                matchedContactIds.add(accountRow.PersonContactId);
            }
        }

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

            if (!candidateByEmail.containsKey(normalizedContactEmail)) {
                RoommateMatchCandidate candidate = new RoommateMatchCandidate();
                candidate.email = normalizedContactEmail;
                candidate.contactId = contactRow.Id;
                candidate.accountId =
                    contactRow.AccountId != null &&
                    contactRow.Account != null &&
                    contactRow.Account.IsPersonAccount == true
                        ? contactRow.AccountId
                        : null;
                candidateByEmail.put(normalizedContactEmail, candidate);
            }

            matchedContactIds.add(contactRow.Id);
            if (
                contactRow.AccountId != null &&
                contactRow.Account != null &&
                contactRow.Account.IsPersonAccount == true
            ) {
                matchedAccountIds.add(contactRow.AccountId);
            }
        }

        ActiveStudentRoles activeStudentRoles = getActiveStudentRoles(matchedAccountIds, matchedContactIds);
        Map<Id, LearnerProgram> learnerProgramByAccountId = getRelevantLearnerPrograms(matchedAccountIds, scope);
        Map<Id, LearnerProgram> learnerProgramByContactId = getRelevantLearnerProgramsByContact(matchedContactIds, scope);

        for (String requestedEmail : requestedEmails) {
            RoommateMatchCandidate candidate = candidateByEmail.get(requestedEmail);
            if (candidate == null) {
                for (RoommateValidationIssue issue : issuesByEmail.get(requestedEmail)) {
                    issue.message = 'This email is not registered in the system.';
                    result.issues.add(issue);
                }
                continue;
            }

            if (!hasActiveStudentRole(candidate, activeStudentRoles)) {
                for (RoommateValidationIssue issue : issuesByEmail.get(requestedEmail)) {
                    issue.message = 'Roommate must have a Student role with status Active, Enrolled, Current, or Admitted.';
                    result.issues.add(issue);
                }
                continue;
            }

            if (!isRoommateEligibleForScope(candidate, scope, learnerProgramByAccountId, learnerProgramByContactId)) {
                for (RoommateValidationIssue issue : issuesByEmail.get(requestedEmail)) {
                    issue.message = 'This roommate is not eligible for the selected category.';
                    result.issues.add(issue);
                }
                continue;
            }

            if (result.preferredPartnerAccountId == null && candidate.accountId != null) {
                result.preferredPartnerAccountId = candidate.accountId;
            }

            for (RoommateValidationIssue issue : issuesByEmail.get(requestedEmail)) {
                ResolvedRoommateRow resolvedRow = new ResolvedRoommateRow();
                resolvedRow.order = issue.order;
                resolvedRow.slot = issue.slot;
                resolvedRow.email = issue.email;
                resolvedRow.accountId = candidate.accountId;
                resolvedRow.contactId = candidate.contactId;
                result.resolvedRows.add(resolvedRow);
            }
        }

        return result;
    }

    private static ActiveStudentRoles getActiveStudentRoles(Set<Id> accountIds, Set<Id> contactIds) {
        ActiveStudentRoles activeRoles = new ActiveStudentRoles();
        Set<Id> personIds = new Set<Id>();
        if (accountIds != null) {
            personIds.addAll(accountIds);
        }
        if (contactIds != null) {
            personIds.addAll(contactIds);
        }
        if (personIds.isEmpty()) {
            return activeRoles;
        }
        ensureReadable(Schema.sObjectType.ConstituentRole, 'You do not have permission to view constituent roles.');

        for (ConstituentRole roleRow : [
            SELECT PersonId
            FROM ConstituentRole
            WHERE RoleType = 'Student'
                AND Status IN ('Active', 'Enrolled', 'Current', 'Admitted')
                AND PersonId IN :personIds
        ]) {
            if (roleRow.PersonId == null) {
                continue;
            }

            Schema.SObjectType personType = roleRow.PersonId.getSObjectType();
            if (personType == Account.SObjectType) {
                activeRoles.accountIds.add(roleRow.PersonId);
            } else if (personType == Contact.SObjectType) {
                activeRoles.contactIds.add(roleRow.PersonId);
            }
        }

        return activeRoles;
    }

    private static Boolean hasActiveStudentRole(RoommateMatchCandidate candidate, ActiveStudentRoles activeRoles) {
        if (candidate == null || activeRoles == null) {
            return false;
        }
        if (candidate.accountId != null && activeRoles.accountIds.contains(candidate.accountId)) {
            return true;
        }
        if (candidate.contactId != null && activeRoles.contactIds.contains(candidate.contactId)) {
            return true;
        }
        return false;
    }

    private static Boolean isRoommateEligibleForScope(
        RoommateMatchCandidate candidate,
        WindowScope scope,
        Map<Id, LearnerProgram> learnerProgramByAccountId,
        Map<Id, LearnerProgram> learnerProgramByContactId
    ) {
        if (candidate == null) {
            return false;
        }
        if (!hasWindowProgramScope(scope)) {
            return true;
        }
        if (candidate.contactId != null && learnerProgramByContactId.containsKey(candidate.contactId)) {
            return true;
        }
        if (candidate.accountId != null && learnerProgramByAccountId.containsKey(candidate.accountId)) {
            return true;
        }
        return false;
    }

    private static void syncRequestRoommates(Id requestId, List<ResolvedRoommateRow> roommateRows) {
        if (requestId == null) {
            return;
        }
        ensureReadable(Schema.sObjectType.Ken_Request_Roommate__c, 'You do not have permission to view request roommates.');

        List<Ken_Request_Roommate__c> existingRows = [
            SELECT Id
            FROM Ken_Request_Roommate__c
            WHERE Room_Request__c = :requestId
            LIMIT 200
        ];
        if (!existingRows.isEmpty()) {
            ensureDeletable(Schema.sObjectType.Ken_Request_Roommate__c, 'You do not have permission to delete request roommates.');
            delete existingRows;
        }

        if (roommateRows == null || roommateRows.isEmpty()) {
            return;
        }

        List<Ken_Request_Roommate__c> rowsToInsert = new List<Ken_Request_Roommate__c>();
        for (ResolvedRoommateRow roommateRow : roommateRows) {
            if (roommateRow == null || String.isBlank(roommateRow.email)) {
                continue;
            }

            Ken_Request_Roommate__c childRow = new Ken_Request_Roommate__c();
            childRow.Room_Request__c = requestId;
            childRow.Preference_Order__c = roommateRow.order;
            childRow.Slot__c = roommateRow.slot;
            childRow.Entered_Email__c = roommateRow.email;
            childRow.Matched_Account__c = roommateRow.accountId;
            childRow.Matched_Contact__c = roommateRow.contactId;
            rowsToInsert.add(childRow);
        }

        if (!rowsToInsert.isEmpty()) {
            ensureCreateable(Schema.sObjectType.Ken_Request_Roommate__c, 'You do not have permission to create request roommates.');
            insert rowsToInsert;
        }
    }

    private static ResidenceWindowContext getResidenceWindowContext(Id accountId, Id contactId) {
        ResidenceWindowContext context = new ResidenceWindowContext();
        if (accountId == null && contactId == null) {
            context.message = 'No contact or account is linked to this user.';
            return context;
        }
        ensureReadable(Schema.sObjectType.Ken_Windows__c, 'You do not have permission to view residence windows.');

        List<Ken_Windows__c> candidateWindows = [
            SELECT
                Id,
                Name,
                Start_Date__c,
                End_Date__c,
                Allotment_Type__c,
                Allow_Roommate_Preference__c,
                Enable_Room_Preference__c,
                Hostel_Cycle__r.Cycle_Start_Date_Time__c,
                Hostel_Cycle__r.Cycle_End_Date_Time__c
            FROM Ken_Windows__c
            ORDER BY Start_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 50
        ];
        if (candidateWindows.isEmpty()) {
            context.message = 'No active residence window is available right now.';
            return context;
        }

        Set<Id> candidateWindowIds = new Set<Id>();
        for (Ken_Windows__c windowRow : candidateWindows) {
            if (isResidencePreferenceWindow(windowRow)) {
                candidateWindowIds.add(windowRow.Id);
            }
        }

        Map<Id, WindowScope> windowScopesById = getWindowScopes(candidateWindowIds);
        LearnerProgram learnerProgram = getPreferredLearnerProgram(accountId, contactId);
        Date today = Date.today();
        Boolean hasOpenWindow = false;
        System.debug('getResidenceWindowContext - today: ' + today);
        System.debug('getResidenceWindowContext - candidateWindows count: ' + candidateWindows.size());

        for (Ken_Windows__c windowRow : candidateWindows) {
            if (!isResidencePreferenceWindow(windowRow)) {
                System.debug('Window ' + windowRow.Id + ' is not a residence preference window');
                continue;
            }
            System.debug('Checking window ' + windowRow.Id + ' - Start: ' + windowRow.Start_Date__c + ', End: ' + windowRow.End_Date__c);
            if (!isWithinDateWindow(today, windowRow.Start_Date__c, windowRow.End_Date__c)) {
                System.debug('Window ' + windowRow.Id + ' is NOT within date range');
                continue;
            }
            System.debug('Window ' + windowRow.Id + ' IS within date range');

            hasOpenWindow = true;
            WindowScope windowScope = windowScopesById.containsKey(windowRow.Id)
                ? windowScopesById.get(windowRow.Id)
                : new WindowScope();
            windowScope.allowRoommatePreference = windowRow.Allow_Roommate_Preference__c == true;
            if (!matchesWindowProgramScope(windowScope, learnerProgram)) {
                continue;
            }

            if (context.windowId == null) {
                context.windowId = windowRow.Id;
            }
            context.eligibleWindowIds.add(windowRow.Id);
            context.eligibleScopesByWindowId.put(windowRow.Id, windowScope);
            context.scope.learningProgramPlanIds.addAll(windowScope.learningProgramPlanIds);
            context.scope.learningProgramPlanNames.addAll(windowScope.learningProgramPlanNames);
            context.scope.learningProgramIds.addAll(windowScope.learningProgramIds);
            context.scope.buildingIds.addAll(windowScope.buildingIds);
            context.scope.roomCategoryIds.addAll(windowScope.roomCategoryIds);
            context.learnerProgram = learnerProgram;
            context.hasEligibleWindow = true;
        }

        if (context.hasEligibleWindow) {
            System.debug('getResidenceWindowContext - Returning with hasEligibleWindow = true');
            return context;
        }

        System.debug('getResidenceWindowContext - No eligible window found, hasOpenWindow: ' + hasOpenWindow);
        context.learnerProgram = learnerProgram;
        context.message = buildResidenceWindowMessage(hasOpenWindow, learnerProgram);
        return context;
    }

    private static WindowDates getActiveWindowDates(Id accountId, Id contactId) {
        if (accountId == null && contactId == null) {
            return null;
        }
        ensureReadable(Schema.sObjectType.Ken_Windows__c, 'You do not have permission to view residence windows.');

        List<Ken_Windows__c> candidateWindows = [
            SELECT
                Id,
                Name,
                Start_Date__c,
                End_Date__c,
                Allotment_Type__c,
                Enable_Room_Preference__c,
                Hostel_Cycle__r.Cycle_Start_Date_Time__c,
                Hostel_Cycle__r.Cycle_End_Date_Time__c
            FROM Ken_Windows__c
            ORDER BY Start_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 50
        ];

        if (candidateWindows.isEmpty()) {
            return null;
        }

        Set<Id> candidateWindowIds = new Set<Id>();
        for (Ken_Windows__c windowRow : candidateWindows) {
            if (isResidencePreferenceWindow(windowRow)) {
                candidateWindowIds.add(windowRow.Id);
            }
        }

        Map<Id, WindowScope> windowScopesById = getWindowScopes(candidateWindowIds);
        LearnerProgram learnerProgram = getPreferredLearnerProgram(accountId, contactId);
        Date today = Date.today();

        for (Ken_Windows__c windowRow : candidateWindows) {
            if (!isResidencePreferenceWindow(windowRow)) {
                continue;
            }
            if (!isWithinDateWindow(today, windowRow.Start_Date__c, windowRow.End_Date__c)) {
                continue;
            }

            WindowScope windowScope = windowScopesById.containsKey(windowRow.Id)
                ? windowScopesById.get(windowRow.Id)
                : new WindowScope();

            if (!matchesWindowProgramScope(windowScope, learnerProgram)) {
                continue;
            }

            WindowDates dates = new WindowDates();
            dates.startDate = windowRow.Start_Date__c;
            dates.endDate = windowRow.End_Date__c;
            dates.residenceAllocationTitle = buildResidenceAllocationTitle(
                windowRow.Hostel_Cycle__r != null ? windowRow.Hostel_Cycle__r.Cycle_Start_Date_Time__c : null,
                windowRow.Hostel_Cycle__r != null ? windowRow.Hostel_Cycle__r.Cycle_End_Date_Time__c : null,
                windowRow.Start_Date__c,
                windowRow.End_Date__c
            );
            return dates;
        }

        return null;
    }

    private static String formatDateForClient(Date value) {
        if (value == null) {
            return null;
        }
        return String.valueOf(value);
    }

    private static Boolean isResidencePreferenceWindow(Ken_Windows__c windowRow) {
        if (windowRow == null) {
            return false;
        }
        // Driven only by allotment type: Provisional or Preference Selected show preference flow.
        // Not based on Enable Room Preference.
        String typeValue = windowRow.Allotment_Type__c != null ? windowRow.Allotment_Type__c.trim() : '';
        return typeValue.equalsIgnoreCase('Preference Selected') || typeValue.equalsIgnoreCase('Provisional Allotment');
    }

    private static Map<Id, WindowScope> getWindowScopes(Set<Id> windowIds) {
        Map<Id, WindowScope> scopesByWindowId = new Map<Id, WindowScope>();
        if (windowIds == null || windowIds.isEmpty()) {
            return scopesByWindowId;
        }
        ensureReadable(Schema.sObjectType.Ken_Window_Learning_Program_Plan__c, 'You do not have permission to view window learning program plans.');
        ensureReadable(Schema.sObjectType.Ken_Window_Program_Pathway__c, 'You do not have permission to view window program pathways.');
        ensureReadable(Schema.sObjectType.Ken_Window_Building__c, 'You do not have permission to view window buildings.');
        ensureReadable(Schema.sObjectType.Ken_Window_Room_Category__c, 'You do not have permission to view window room categories.');

        for (Id windowId : windowIds) {
            scopesByWindowId.put(windowId, new WindowScope());
        }

        for (Ken_Window_Learning_Program_Plan__c row : [
            SELECT Window__c, Learning_Program_Plan__c
            FROM Ken_Window_Learning_Program_Plan__c
            WHERE Window__c IN :windowIds
        ]) {
            if (row.Window__c == null || row.Learning_Program_Plan__c == null) {
                continue;
            }
            scopesByWindowId.get(row.Window__c).learningProgramPlanIds.add(row.Learning_Program_Plan__c);
        }

        for (Ken_Window_Program_Pathway__c row : [
            SELECT Window__c, Program_Pathway__c
            FROM Ken_Window_Program_Pathway__c
            WHERE Window__c IN :windowIds
        ]) {
            if (row.Window__c == null || row.Program_Pathway__c == null) {
                continue;
            }
            scopesByWindowId.get(row.Window__c).learningProgramIds.add(row.Program_Pathway__c);
        }

        for (Ken_Window_Building__c row : [
            SELECT Windows__c, Building__c
            FROM Ken_Window_Building__c
            WHERE Windows__c IN :windowIds
        ]) {
            if (row.Windows__c == null || row.Building__c == null) {
                continue;
            }
            scopesByWindowId.get(row.Windows__c).buildingIds.add(row.Building__c);
        }

        for (Ken_Window_Room_Category__c row : [
            SELECT Windows__c, Room_Category__c
            FROM Ken_Window_Room_Category__c
            WHERE Windows__c IN :windowIds
        ]) {
            if (row.Windows__c == null || row.Room_Category__c == null) {
                continue;
            }
            scopesByWindowId.get(row.Windows__c).roomCategoryIds.add(row.Room_Category__c);
        }

        return scopesByWindowId;
    }

    private static LearnerProgram getPreferredLearnerProgram(Id accountId, Id contactId) {
        if (accountId == null && contactId == null) {
            return null;
        }
        ensureReadable(Schema.sObjectType.LearnerProgram, 'You do not have permission to view learner programs.');

        LearnerProgram preferredProgram;
        if (contactId != null) {
            for (LearnerProgram learnerProgram : [
                SELECT
                    Id,
                    Name,
                    LearnerAccountId,
                    LearnerContactId,
                    Status,
                    StartDate,
                    LastModifiedDate,
                    LearningProgramPlanId,
                    LearningProgramPlan.Name,
                    LearningProgramPlan.LearningProgramId
                FROM LearnerProgram
                WHERE LearnerContactId = :contactId
                ORDER BY LastModifiedDate DESC
                LIMIT 200
            ]) {
                if (preferredProgram == null || isPreferredLearnerProgram(learnerProgram, preferredProgram)) {
                    preferredProgram = learnerProgram;
                }
            }
        }

        if (preferredProgram != null || accountId == null) {
            return preferredProgram;
        }

        for (LearnerProgram learnerProgram : [
            SELECT
                Id,
                Name,
                LearnerAccountId,
                LearnerContactId,
                Status,
                StartDate,
                LastModifiedDate,
                LearningProgramPlanId,
                LearningProgramPlan.Name,
                LearningProgramPlan.LearningProgramId
            FROM LearnerProgram
            WHERE LearnerAccountId = :accountId
            ORDER BY LastModifiedDate DESC
            LIMIT 200
        ]) {
            if (preferredProgram == null || isPreferredLearnerProgram(learnerProgram, preferredProgram)) {
                preferredProgram = learnerProgram;
            }
        }

        return preferredProgram;
    }

    private static Map<Id, LearnerProgram> getRelevantLearnerPrograms(Set<Id> accountIds, WindowScope scope) {
        Map<Id, LearnerProgram> learnerProgramByAccountId = new Map<Id, LearnerProgram>();
        if (accountIds == null || accountIds.isEmpty()) {
            return learnerProgramByAccountId;
        }

        Map<Id, List<LearnerProgram>> learnerProgramsByAccountId = getLearnerProgramsByAccountId(accountIds);
        for (Id accountId : learnerProgramsByAccountId.keySet()) {
            LearnerProgram learnerProgram = resolveRelevantLearnerProgram(scope, learnerProgramsByAccountId.get(accountId));
            if (learnerProgram != null) {
                learnerProgramByAccountId.put(accountId, learnerProgram);
            }
        }

        return learnerProgramByAccountId;
    }

    private static Map<Id, LearnerProgram> getRelevantLearnerProgramsByContact(Set<Id> contactIds, WindowScope scope) {
        Map<Id, LearnerProgram> learnerProgramByContactId = new Map<Id, LearnerProgram>();
        if (contactIds == null || contactIds.isEmpty()) {
            return learnerProgramByContactId;
        }

        Map<Id, List<LearnerProgram>> learnerProgramsByContactId = getLearnerProgramsByContactId(contactIds);
        for (Id contactId : learnerProgramsByContactId.keySet()) {
            LearnerProgram learnerProgram = resolveRelevantLearnerProgram(scope, learnerProgramsByContactId.get(contactId));
            if (learnerProgram != null) {
                learnerProgramByContactId.put(contactId, learnerProgram);
            }
        }

        return learnerProgramByContactId;
    }

    private static Map<Id, List<LearnerProgram>> getLearnerProgramsByAccountId(Set<Id> accountIds) {
        Map<Id, List<LearnerProgram>> learnerProgramsByAccountId = new Map<Id, List<LearnerProgram>>();
        if (accountIds == null || accountIds.isEmpty()) {
            return learnerProgramsByAccountId;
        }
        ensureReadable(Schema.sObjectType.LearnerProgram, 'You do not have permission to view learner programs.');

        for (LearnerProgram learnerProgram : [
            SELECT
                Id,
                Name,
                LearnerAccountId,
                Status,
                StartDate,
                LastModifiedDate,
                LearningProgramPlanId,
                LearningProgramPlan.Name,
                LearningProgramPlan.LearningProgramId
            FROM LearnerProgram
            WHERE LearnerAccountId IN :accountIds
            ORDER BY LastModifiedDate DESC
            LIMIT 2000
        ]) {
            if (learnerProgram.LearnerAccountId == null) {
                continue;
            }
            if (!learnerProgramsByAccountId.containsKey(learnerProgram.LearnerAccountId)) {
                learnerProgramsByAccountId.put(learnerProgram.LearnerAccountId, new List<LearnerProgram>());
            }
            learnerProgramsByAccountId.get(learnerProgram.LearnerAccountId).add(learnerProgram);
        }

        return learnerProgramsByAccountId;
    }

    private static Map<Id, List<LearnerProgram>> getLearnerProgramsByContactId(Set<Id> contactIds) {
        Map<Id, List<LearnerProgram>> learnerProgramsByContactId = new Map<Id, List<LearnerProgram>>();
        if (contactIds == null || contactIds.isEmpty()) {
            return learnerProgramsByContactId;
        }
        ensureReadable(Schema.sObjectType.LearnerProgram, 'You do not have permission to view learner programs.');

        for (LearnerProgram learnerProgram : [
            SELECT
                Id,
                Name,
                LearnerContactId,
                Status,
                StartDate,
                LastModifiedDate,
                LearningProgramPlanId,
                LearningProgramPlan.Name,
                LearningProgramPlan.LearningProgramId
            FROM LearnerProgram
            WHERE LearnerContactId IN :contactIds
            ORDER BY LastModifiedDate DESC
            LIMIT 2000
        ]) {
            if (learnerProgram.LearnerContactId == null) {
                continue;
            }
            if (!learnerProgramsByContactId.containsKey(learnerProgram.LearnerContactId)) {
                learnerProgramsByContactId.put(learnerProgram.LearnerContactId, new List<LearnerProgram>());
            }
            learnerProgramsByContactId.get(learnerProgram.LearnerContactId).add(learnerProgram);
        }

        return learnerProgramsByContactId;
    }

    private static LearnerProgram resolveRelevantLearnerProgram(WindowScope scope, List<LearnerProgram> learnerPrograms) {
        if (learnerPrograms == null || learnerPrograms.isEmpty()) {
            return null;
        }

        LearnerProgram preferredOverall;
        LearnerProgram preferredScoped;
        for (LearnerProgram learnerProgram : learnerPrograms) {
            if (preferredOverall == null || isPreferredLearnerProgram(learnerProgram, preferredOverall)) {
                preferredOverall = learnerProgram;
            }
            if (matchesWindowProgramScope(scope, learnerProgram) &&
                (preferredScoped == null || isPreferredLearnerProgram(learnerProgram, preferredScoped))) {
                preferredScoped = learnerProgram;
            }
        }

        if (preferredScoped != null) {
            return preferredScoped;
        }
        if (hasWindowProgramScope(scope)) {
            return null;
        }
        return preferredOverall;
    }

    private static Boolean areRequestedCategoriesEligible(
        List<Id> requestedCategoryIds,
        Set<Id> scopedRoomCategoryIds
    ) {
        if (scopedRoomCategoryIds == null || scopedRoomCategoryIds.isEmpty()) {
            return true;
        }
        if (requestedCategoryIds == null || requestedCategoryIds.isEmpty()) {
            return true;
        }

        for (Id categoryId : requestedCategoryIds) {
            if (categoryId != null && !scopedRoomCategoryIds.contains(categoryId)) {
                return false;
            }
        }
        return true;
    }

    private static Id resolveRequestWindowId(
        ResidenceWindowContext context,
        List<Id> requestedCategoryIds,
        Id existingWindowId
    ) {
        if (context == null || !context.hasEligibleWindow) {
            return null;
        }

        if (
            existingWindowId != null &&
            context.eligibleScopesByWindowId.containsKey(existingWindowId) &&
            areRequestedCategoriesEligible(requestedCategoryIds, context.eligibleScopesByWindowId.get(existingWindowId).roomCategoryIds)
        ) {
            return existingWindowId;
        }

        Id matchedWindowId;
        for (Id windowId : context.eligibleWindowIds) {
            WindowScope scope = context.eligibleScopesByWindowId.get(windowId);
            if (!areRequestedCategoriesEligible(requestedCategoryIds, scope != null ? scope.roomCategoryIds : null)) {
                continue;
            }
            if (matchedWindowId != null) {
                return matchedWindowId;
            }
            matchedWindowId = windowId;
        }

        return matchedWindowId;
    }

    private static String buildResidenceWindowMessage(Boolean hasOpenWindow, LearnerProgram learnerProgram) {
        if (!hasOpenWindow) {
            return 'No active residence window is available right now.';
        }
        if (learnerProgram == null) {
            return 'No learning program plan is linked to this user for the current residence window.';
        }
        return 'Your learning program plan is not eligible for the current residence window.';
    }

    private static Id resolveCurrentPreferenceWindowId() {
        ensureReadable(Schema.sObjectType.Ken_Windows__c, 'You do not have permission to view residence windows.');
        List<Ken_Windows__c> windows = [
            SELECT Id, Start_Date__c, End_Date__c
            FROM Ken_Windows__c
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

    private static List<Ken_Room_Allotment__c> queryAllotmentsByContactId(Id contactId) {
        ensureReadable(Schema.sObjectType.Ken_Room_Allotment__c, 'You do not have permission to view room allotments.');
        return [
            SELECT Id, Active__c, Allotment_Type__c, Start_Date__c, End_Date__c, Amount_Paid__c, Room__c, Tenant_Account__c, Tenant__c, Window__c,
                Room__r.Name,
                Room__r.Room_Number__c,
                Room__r.Housing_Category__c,
                Room__r.Capacity__c,
                Room__r.Price__c,
                Room__r.Overriden_Price__c,
                Room__r.Room_Category__r.Name,
                Room__r.Room_Category__r.Name__c,
                Room__r.Room_Category__r.Amenities__c,
                Room__r.Floor__r.Name,
                Room__r.Floor__r.Building__r.Name,
                Room__r.Floor__r.Building__r.Name__c,
                Room__r.Floor__r.Building__r.Warden__r.Name,
                Room__r.Floor__r.Building__r.Warden__r.Phone,
                Room__r.Floor__r.Building__r.Warden__r.PersonMobilePhone,
                Room__r.Floor__r.Building__r.Warden__r.PersonEmail
            FROM Ken_Room_Allotment__c
            WHERE Tenant__c = :contactId
                AND Room__c != null
            ORDER BY Active__c DESC, End_Date__c DESC NULLS LAST, Start_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 20
        ];
    }

    private static List<Ken_Room_Allotment__c> queryAllotmentsByAccountId(Id accountId) {
        ensureReadable(Schema.sObjectType.Ken_Room_Allotment__c, 'You do not have permission to view room allotments.');
        return [
            SELECT Id, Active__c, Allotment_Type__c, Start_Date__c, End_Date__c, Amount_Paid__c, Room__c, Tenant_Account__c, Tenant__c, Window__c,
                Room__r.Name,
                Room__r.Room_Number__c,
                Room__r.Housing_Category__c,
                Room__r.Capacity__c,
                Room__r.Price__c,
                Room__r.Overriden_Price__c,
                Room__r.Room_Category__r.Name,
                Room__r.Room_Category__r.Name__c,
                Room__r.Room_Category__r.Amenities__c,
                Room__r.Floor__r.Name,
                Room__r.Floor__r.Building__r.Name,
                Room__r.Floor__r.Building__r.Name__c,
                Room__r.Floor__r.Building__r.Warden__r.Name,
                Room__r.Floor__r.Building__r.Warden__r.Phone,
                Room__r.Floor__r.Building__r.Warden__r.PersonMobilePhone,
                Room__r.Floor__r.Building__r.Warden__r.PersonEmail
            FROM Ken_Room_Allotment__c
            WHERE Tenant_Account__c = :accountId
                AND Room__c != null
            ORDER BY Active__c DESC, End_Date__c DESC NULLS LAST, Start_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 20
        ];
    }

    private static List<Ken_Room_Allotment__c> queryAllotmentsByAccountEmail(String emailValue) {
        ensureReadable(Schema.sObjectType.Ken_Room_Allotment__c, 'You do not have permission to view room allotments.');
        return [
            SELECT Id, Active__c, Allotment_Type__c, Start_Date__c, End_Date__c, Amount_Paid__c, Room__c, Tenant_Account__c, Tenant__c, Window__c,
                Room__r.Name,
                Room__r.Room_Number__c,
                Room__r.Housing_Category__c,
                Room__r.Capacity__c,
                Room__r.Price__c,
                Room__r.Overriden_Price__c,
                Room__r.Room_Category__r.Name,
                Room__r.Room_Category__r.Name__c,
                Room__r.Room_Category__r.Amenities__c,
                Room__r.Floor__r.Name,
                Room__r.Floor__r.Building__r.Name,
                Room__r.Floor__r.Building__r.Name__c,
                Room__r.Floor__r.Building__r.Warden__r.Name,
                Room__r.Floor__r.Building__r.Warden__r.Phone,
                Room__r.Floor__r.Building__r.Warden__r.PersonMobilePhone,
                Room__r.Floor__r.Building__r.Warden__r.PersonEmail
            FROM Ken_Room_Allotment__c
            WHERE Tenant_Account__r.PersonEmail = :emailValue
                AND Room__c != null
            ORDER BY Active__c DESC, End_Date__c DESC NULLS LAST, Start_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 20
        ];
    }

    private static List<Ken_Room_Allotment__c> queryActiveAllotmentsForPreview() {
        ensureReadable(Schema.sObjectType.Ken_Room_Allotment__c, 'You do not have permission to view room allotments.');
        return [
            SELECT Id, Active__c, Allotment_Type__c, Start_Date__c, End_Date__c, Amount_Paid__c, Room__c, Tenant_Account__c, Tenant__c, Window__c,
                Room__r.Name,
                Room__r.Room_Number__c,
                Room__r.Housing_Category__c,
                Room__r.Capacity__c,
                Room__r.Price__c,
                Room__r.Overriden_Price__c,
                Room__r.Room_Category__r.Name,
                Room__r.Room_Category__r.Name__c,
                Room__r.Room_Category__r.Amenities__c,
                Room__r.Floor__r.Name,
                Room__r.Floor__r.Building__r.Name,
                Room__r.Floor__r.Building__r.Name__c,
                Room__r.Floor__r.Building__r.Warden__r.Name,
                Room__r.Floor__r.Building__r.Warden__r.Phone,
                Room__r.Floor__r.Building__r.Warden__r.PersonMobilePhone,
                Room__r.Floor__r.Building__r.Warden__r.PersonEmail
            FROM Ken_Room_Allotment__c
            WHERE Room__c != null
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

    private static RoomDetails mapRoomDetails(Ken_Room_Allotment__c allotment) {
        RoomDetails details = new RoomDetails();
        Ken_Room__c room = allotment.Room__r;
        if (room == null) {
            return details;
        }

        details.roomNumber = firstNonBlank(new List<String>{
            room.Room_Number__c,
            room.Name
        });
        details.type = firstNonBlank(new List<String>{
            room.Housing_Category__c,
            room.Room_Category__r != null ? room.Room_Category__r.Name__c : null
        });
        details.hall = firstNonBlank(new List<String>{
            room.Floor__r != null && room.Floor__r.Building__r != null ? room.Floor__r.Building__r.Name__c : null,
            room.Floor__r != null && room.Floor__r.Building__r != null ? room.Floor__r.Building__r.Name : null,
            room.Housing_Category__c
        });
        details.location = firstNonBlank(new List<String>{
            room.Floor__r != null ? room.Floor__r.Name : null,
            room.Floor__r != null && room.Floor__r.Building__r != null ? room.Floor__r.Building__r.Name__c : null
        });
        details.floor = firstNonBlank(new List<String>{
            room.Floor__r != null ? room.Floor__r.Name : null
        });
        details.sharing = toSharingLabel(room.Capacity__c);
        details.amenities = normalizeAmenities(room.Room_Category__r != null ? room.Room_Category__r.Amenities__c : null);
        return details;
    }

    private static WardenDetails mapWardenDetails(Ken_Room_Allotment__c allotment) {
        WardenDetails details = new WardenDetails();
        details.name = firstNonBlank(new List<String>{
            allotment != null &&
            allotment.Room__r != null &&
            allotment.Room__r.Floor__r != null &&
            allotment.Room__r.Floor__r.Building__r != null &&
            allotment.Room__r.Floor__r.Building__r.Warden__r != null
                ? allotment.Room__r.Floor__r.Building__r.Warden__r.Name
                : null,
            'Not Assigned'
        });
        details.phone = firstNonBlank(new List<String>{
            allotment != null &&
            allotment.Room__r != null &&
            allotment.Room__r.Floor__r != null &&
            allotment.Room__r.Floor__r.Building__r != null &&
            allotment.Room__r.Floor__r.Building__r.Warden__r != null
                ? allotment.Room__r.Floor__r.Building__r.Warden__r.Phone
                : null,
            allotment != null &&
            allotment.Room__r != null &&
            allotment.Room__r.Floor__r != null &&
            allotment.Room__r.Floor__r.Building__r != null &&
            allotment.Room__r.Floor__r.Building__r.Warden__r != null
                ? allotment.Room__r.Floor__r.Building__r.Warden__r.PersonMobilePhone
                : null,
            '--'
        });
        details.email = firstNonBlank(new List<String>{
            allotment != null &&
            allotment.Room__r != null &&
            allotment.Room__r.Floor__r != null &&
            allotment.Room__r.Floor__r.Building__r != null &&
            allotment.Room__r.Floor__r.Building__r.Warden__r != null
                ? allotment.Room__r.Floor__r.Building__r.Warden__r.PersonEmail
                : null,
            '--'
        });
        return details;
    }

    private static List<RoommateDetails> getRoommates(Id roomId, Id currentAccountId, Id currentContactId) {
        List<RoommateDetails> roommates = new List<RoommateDetails>();
        Set<Id> accountIdsAdded = new Set<Id>();
        Set<Id> contactIdsAdded = new Set<Id>();
        Date today = Date.today();
        ensureReadable(Schema.sObjectType.Ken_Room_Allotment__c, 'You do not have permission to view room allotments.');

        List<Ken_Room_Allotment__c> candidateAllotments = [
            SELECT Id, Tenant_Account__c, Tenant__c, Active__c, Start_Date__c, End_Date__c,
                Tenant__r.Name,
                Tenant__r.Email,
                Tenant_Account__r.Name,
                Tenant_Account__r.Student_ID__c,
                Tenant_Account__r.Roll_No__c,
                Tenant_Account__r.PersonDepartment,
                Tenant_Account__r.PersonMobilePhone,
                Tenant_Account__r.PersonEmail
            FROM Ken_Room_Allotment__c
            WHERE Room__c = :roomId
                AND (Tenant_Account__c != null OR Tenant__c != null)
            ORDER BY Active__c DESC, End_Date__c DESC NULLS LAST, Start_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 100
        ];

        for (Ken_Room_Allotment__c allotment : candidateAllotments) {
            Id roommateAccountId = allotment.Tenant_Account__c;
            Id roommateContactId = allotment.Tenant__c;
            if (
                (currentContactId != null && roommateContactId == currentContactId) ||
                (currentContactId == null && roommateAccountId == currentAccountId) ||
                (roommateContactId != null && contactIdsAdded.contains(roommateContactId)) ||
                (roommateContactId == null && roommateAccountId != null && accountIdsAdded.contains(roommateAccountId))
            ) {
                continue;
            }
            if (allotment.Active__c != true && !isInDateRange(allotment, today)) {
                continue;
            }

            roommates.add(mapRoommate(allotment));
            if (roommateContactId != null) {
                contactIdsAdded.add(roommateContactId);
            } else if (roommateAccountId != null) {
                accountIdsAdded.add(roommateAccountId);
            }
        }

        if (!roommates.isEmpty()) {
            return roommates;
        }

        for (Ken_Room_Allotment__c allotment : candidateAllotments) {
            Id roommateAccountId = allotment.Tenant_Account__c;
            Id roommateContactId = allotment.Tenant__c;
            if (
                (currentContactId != null && roommateContactId == currentContactId) ||
                (currentContactId == null && roommateAccountId == currentAccountId) ||
                (roommateContactId != null && contactIdsAdded.contains(roommateContactId)) ||
                (roommateContactId == null && roommateAccountId != null && accountIdsAdded.contains(roommateAccountId))
            ) {
                continue;
            }

            roommates.add(mapRoommate(allotment));
            if (roommateContactId != null) {
                contactIdsAdded.add(roommateContactId);
            } else if (roommateAccountId != null) {
                accountIdsAdded.add(roommateAccountId);
            }
        }

        return roommates;
    }

    private static RoommateDetails mapRoommate(Ken_Room_Allotment__c allotment) {
        RoommateDetails roommate = new RoommateDetails();
        if (allotment == null) {
            return roommate;
        }

        if (allotment.Tenant__c != null && allotment.Tenant__r != null) {
            roommate.id = String.valueOf(allotment.Tenant__c);
            roommate.name = allotment.Tenant__r.Name;
            roommate.studentId = firstNonBlank(new List<String>{
                allotment.Tenant_Account__r != null ? allotment.Tenant_Account__r.Roll_No__c : null,
                allotment.Tenant__r.Email
            });
            roommate.email = allotment.Tenant__r.Email;
            return roommate;
        }

        Account roommateAccount = allotment.Tenant_Account__r;
        if (roommateAccount == null) {
            return roommate;
        }

        roommate.id = String.valueOf(roommateAccount.Id);
        roommate.name = roommateAccount.Name;
        roommate.studentId = firstNonBlank(new List<String>{ roommateAccount.Student_ID__c, roommateAccount.Roll_No__c });
        roommate.department = roommateAccount.PersonDepartment;
        roommate.phone = roommateAccount.PersonMobilePhone;
        roommate.email = roommateAccount.PersonEmail;
        return roommate;
    }

    private static ResidenceDetails mapResidenceDetails(Ken_Room_Allotment__c allotment) {
        ResidenceDetails details = new ResidenceDetails();
        if (allotment == null) {
            return details;
        }

        Ken_Room__c room = allotment.Room__r;
        details.title = room != null
            ? firstNonBlank(new List<String>{ room.Room_Number__c, room.Name })
            : null;
        details.subtitle = room != null
            ? firstNonBlank(new List<String>{
                room.Housing_Category__c,
                room.Room_Category__r != null ? room.Room_Category__r.Name__c : null
            })
            : null;
        details.checkInDate = formatDateLabel(allotment.Start_Date__c);

        Decimal annualFeeValue = null;
        if (room != null && room.Overriden_Price__c != null) {
            annualFeeValue = room.Overriden_Price__c;
        } else if (room != null && room.Price__c != null) {
            annualFeeValue = room.Price__c;
        } else if (allotment.Amount_Paid__c != null) {
            annualFeeValue = allotment.Amount_Paid__c;
        }
        details.annualFee = formatCurrencyLabel(annualFeeValue);
        return details;
    }

    private static List<String> buildFeatureLabels(Ken_Room_Allotment__c allotment) {
        List<String> labels = new List<String>();
        Ken_Room__c room = allotment != null ? allotment.Room__r : null;

        String hall = room != null
            ? firstNonBlank(new List<String>{
                room.Floor__r != null && room.Floor__r.Building__r != null ? room.Floor__r.Building__r.Name__c : null,
                room.Floor__r != null && room.Floor__r.Building__r != null ? room.Floor__r.Building__r.Name : null
            })
            : null;
        if (String.isNotBlank(hall)) {
            labels.add(hall);
        }

        String sharing = room != null ? toSharingLabel(room.Capacity__c) : null;
        if (String.isNotBlank(sharing)) {
            labels.add(sharing);
        }

        Set<String> existing = new Set<String>();
        if (String.isNotBlank(hall)) {
            existing.add(hall.toLowerCase());
        }
        if (String.isNotBlank(sharing)) {
            existing.add(sharing.toLowerCase());
        }

        for (String amenityLabel : buildAmenityLabels(allotment)) {
            if (labels.size() >= 4) {
                break;
            }
            String normalized = amenityLabel.toLowerCase();
            if (!existing.contains(normalized)) {
                labels.add(amenityLabel);
                existing.add(normalized);
            }
        }

        return labels;
    }

    private static List<String> buildAmenityLabels(Ken_Room_Allotment__c allotment) {
        List<String> labels = new List<String>();
        String amenities = allotment != null && allotment.Room__r != null && allotment.Room__r.Room_Category__r != null
            ? allotment.Room__r.Room_Category__r.Amenities__c
            : null;
        if (String.isBlank(amenities)) {
            return labels;
        }

        Set<String> seen = new Set<String>();
        for (String amenity : amenities.replace(';', ',').split(',')) {
            String cleanedAmenity = amenity != null ? amenity.trim() : null;
            if (String.isBlank(cleanedAmenity)) {
                continue;
            }

            String normalized = cleanedAmenity.toLowerCase();
            if (seen.contains(normalized)) {
                continue;
            }

            labels.add(cleanedAmenity);
            seen.add(normalized);
        }

        return labels;
    }

    private static List<ResidenceHistoryRow> getResidenceHistory(Id accountId, Id contactId) {
        List<ResidenceHistoryRow> historyRows = new List<ResidenceHistoryRow>();
        if (accountId == null && contactId == null) {
            return historyRows;
        }
        ensureReadable(Schema.sObjectType.Ken_Room_Allotment__c, 'You do not have permission to view room allotments.');

        List<Ken_Room_Allotment__c> allotments;
        if (contactId != null) {
            allotments = [
                SELECT Id, Start_Date__c, End_Date__c, Allotment_Type__c, Housing_Category__c,
                    Room__r.Name,
                    Room__r.Room_Number__c,
                    Room__r.Housing_Category__c,
                    Room__r.Floor__r.Name,
                    Room__r.Floor__r.Building__r.Name,
                    Room__r.Floor__r.Building__r.Name__c,
                    Room__r.Room_Category__r.Name__c
                FROM Ken_Room_Allotment__c
                WHERE Tenant__c = :contactId
                    AND Room__c != null
                ORDER BY Start_Date__c DESC NULLS LAST, End_Date__c DESC NULLS LAST, CreatedDate DESC
                LIMIT 20
            ];
        } else {
            allotments = [
                SELECT Id, Start_Date__c, End_Date__c, Allotment_Type__c, Housing_Category__c,
                    Room__r.Name,
                    Room__r.Room_Number__c,
                    Room__r.Housing_Category__c,
                    Room__r.Floor__r.Name,
                    Room__r.Floor__r.Building__r.Name,
                    Room__r.Floor__r.Building__r.Name__c,
                    Room__r.Room_Category__r.Name__c
                FROM Ken_Room_Allotment__c
                WHERE Tenant_Account__c = :accountId
                    AND Room__c != null
                ORDER BY Start_Date__c DESC NULLS LAST, End_Date__c DESC NULLS LAST, CreatedDate DESC
                LIMIT 20
            ];
        }

        for (Ken_Room_Allotment__c allotment : allotments) {
            historyRows.add(mapHistoryRow(allotment));
        }
        return historyRows;
    }

    private static ResidenceHistoryRow mapHistoryRow(Ken_Room_Allotment__c allotment) {
        ResidenceHistoryRow row = new ResidenceHistoryRow();
        row.id = String.valueOf(allotment.Id);
        row.academicYear = toAcademicYear(allotment.Start_Date__c, allotment.End_Date__c);

        Ken_Room__c room = allotment.Room__r;
        row.roomType = firstNonBlank(new List<String>{
            allotment.Housing_Category__c,
            allotment.Allotment_Type__c,
            room != null ? room.Housing_Category__c : null,
            room != null && room.Room_Category__r != null ? room.Room_Category__r.Name__c : null
        });
        row.roomNumber = firstNonBlank(new List<String>{
            room != null ? room.Room_Number__c : null,
            room != null ? room.Name : null
        });
        row.floor = room != null && room.Floor__r != null ? room.Floor__r.Name : null;
        row.block = room != null && room.Floor__r != null && room.Floor__r.Building__r != null
            ? firstNonBlank(new List<String>{
                room.Floor__r.Building__r.Name__c,
                room.Floor__r.Building__r.Name
            })
            : null;
        row.movedIn = formatDateLabel(allotment.Start_Date__c);
        row.movedOut = formatDateLabel(allotment.End_Date__c);
        return row;
    }

    private static void populateResidenceAllocationSummary(
        ResidenceAllocationResponse response,
        Ken_Room_Allotment__c allotment,
        Ken_Room_Request__c roomRequest
    ) {
        if (response == null || allotment == null || allotment.Room__c == null) {
            return;
        }

        response.residenceDetails = mapResidenceDetails(allotment);
        response.roomDetails = mapRoomDetails(allotment);
        response.features = buildFeatureLabels(allotment);
        response.amenityLabels = buildAmenityLabels(allotment);
        response.roommates = getRoommates(allotment.Room__c, allotment.Tenant_Account__c, allotment.Tenant__c);

        Id windowId = allotment.Window__c != null
            ? allotment.Window__c
            : (roomRequest != null ? roomRequest.Window__c : null);
        response.paymentDeadline = formatResidencePaymentDeadline(windowId);
    }

    private static String formatResidencePaymentDeadline(Id windowId) {
        if (windowId == null) {
            return null;
        }
        ensureReadable(Schema.sObjectType.Ken_Windows__c, 'You do not have permission to view residence windows.');

        List<Ken_Windows__c> rows = [
            SELECT Payment_Deadline__c
            FROM Ken_Windows__c
            WHERE Id = :windowId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return null;
        }

        return formatDateLabel(rows[0].Payment_Deadline__c);
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
            roomRequest.Floor_Preference_1__c,
            roomRequest.Preference_1_Roommate_Email_1__c,
            roomRequest.Preference_1_Roommate_Email_2__c,
            roomRequest.Preferred_Partner__r != null ? roomRequest.Preferred_Partner__r.PersonEmail : null
        );
        appendPreferenceItem(
            preferences,
            2,
            roomRequest.Preference_2__c,
            roomRequest.Preference_2_Category__c,
            roomRequest.Preference_2__r,
            roomRequest.Floor_Preference_2__c,
            roomRequest.Preference_2_Roommate_Email_1__c,
            roomRequest.Preference_2_Roommate_Email_2__c,
            roomRequest.Preferred_Partner__r != null ? roomRequest.Preferred_Partner__r.PersonEmail : null
        );
        appendPreferenceItem(
            preferences,
            3,
            roomRequest.Preference_3__c,
            roomRequest.Preference_3_Category__c,
            roomRequest.Preference_3__r,
            roomRequest.Floor_Preference_3__c,
            roomRequest.Preference_3_Roommate_Email_1__c,
            roomRequest.Preference_3_Roommate_Email_2__c,
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
        String floorPreference,
        String roommateEmail1,
        String roommateEmail2,
        String preferredPartnerEmails
    ) {
        String typeLabel = firstNonBlank(new List<String>{
            categoryLabel,
            categoryRecord != null ? categoryRecord.Name__c : null,
            categoryRecord != null ? categoryRecord.Name : null
        });

        if (categoryId == null && categoryRecord == null) {
            return;
        }

        ResidencePreferenceItem row = new ResidencePreferenceItem();
        row.id = String.valueOf(preferenceOrder);
        row.order = preferenceOrder;
        row.categoryId = categoryId != null ? String.valueOf(categoryId) : null;
        row.preference = 'Preference ' + String.valueOf(preferenceOrder);
        row.type = String.isNotBlank(typeLabel) ? typeLabel : row.preference;
        row.floor = String.isNotBlank(floorPreference) ? floorPreference : 'No Preference';
        row.emails = joinRoommateEmails(roommateEmail1, roommateEmail2, preferredPartnerEmails);
        row.sharing = resolveResidenceCategorySharing(categoryRecord);
        row.ac = resolveResidenceCategoryAc(categoryRecord);
        row.bathroom = resolveResidenceCategoryBathroom(categoryRecord);
        items.add(row);
    }

    private static String resolveResidenceCategorySharing(Ken_Room_Category__c categoryRecord) {
        if (categoryRecord == null) {
            return null;
        }

        Integer sharingValue = categoryRecord.Sharing__c != null
            ? categoryRecord.Sharing__c.intValue()
            : toWholeNumber(categoryRecord.Capacity__c);
        return sharingValue > 0 ? String.valueOf(sharingValue) : null;
    }

    private static String resolveResidenceCategoryAc(Ken_Room_Category__c categoryRecord) {
        if (categoryRecord == null) {
            return null;
        }

        String explicitValue = normalizeResidenceAcValue(categoryRecord.Ac_Non_Ac__c);
        if (String.isNotBlank(explicitValue)) {
            return explicitValue;
        }
        return resolveAcFromAmenities(categoryRecord.Amenities__c);
    }

    private static String resolveResidenceCategoryBathroom(Ken_Room_Category__c categoryRecord) {
        if (categoryRecord == null) {
            return null;
        }

        String explicitValue = normalizeResidenceBathroomValue(categoryRecord.Bathroom__c);
        if (String.isNotBlank(explicitValue)) {
            return explicitValue;
        }
        return resolveBathroomFromAmenities(categoryRecord.Amenities__c);
    }

    private static String joinRoommateEmails(String email1, String email2, String fallback) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(email1)) {
            parts.add(email1.trim());
        }
        if (String.isNotBlank(email2)) {
            parts.add(email2.trim());
        }
        if (!parts.isEmpty()) {
            return String.join(parts, ', ');
        }
        return String.isNotBlank(fallback) ? fallback : '';
    }

    private static String resolveAcFromAmenities(String amenities) {
        if (String.isBlank(amenities)) {
            return null;
        }

        String normalized = amenities.toLowerCase();
        if (normalized.contains('non-ac') || normalized.contains('non ac') || normalized.contains('without ac')) {
            return 'No';
        }
        if (normalized.contains('air conditioning') || normalized.contains(' ac')) {
            return 'Yes';
        }
        return null;
    }

    private static String resolveBathroomFromAmenities(String amenities) {
        if (String.isBlank(amenities)) {
            return null;
        }

        String normalized = amenities.toLowerCase();
        if (normalized.contains('attached bathroom') || normalized.contains('attached bath') || normalized.contains('ensuite')) {
            return 'Attached';
        }
        if (normalized.contains('common bathroom') || normalized.contains('shared bathroom') || normalized.contains('shared bath')) {
            return 'Common';
        }
        return null;
    }

    private static String normalizeResidenceAcValue(String value) {
        String cleaned = sanitize(value);
        if (String.isBlank(cleaned)) {
            return null;
        }

        String normalized = cleaned.toLowerCase().replace('-', ' ').replaceAll('\\s+', ' ').trim();
        if (normalized == 'yes' || normalized == 'ac' || normalized == 'with ac') {
            return 'Yes';
        }
        if (normalized == 'no' || normalized == 'non ac' || normalized == 'without ac') {
            return 'No';
        }
        return cleaned;
    }

    private static String normalizeResidenceBathroomValue(String value) {
        String cleaned = sanitize(value);
        if (String.isBlank(cleaned)) {
            return null;
        }

        String normalized = cleaned.toLowerCase().replace('-', ' ').replaceAll('\\s+', ' ').trim();
        if (normalized == 'attached' || normalized == 'attached bathroom' || normalized == 'attached bath' || normalized == 'ensuite') {
            return 'Attached';
        }
        if (normalized == 'common' || normalized == 'common bathroom' || normalized == 'shared bathroom' || normalized == 'shared bath') {
            return 'Common';
        }
        return cleaned;
    }

    private static Boolean isRejectedStatus(String statusValue) {
        if (String.isBlank(statusValue)) {
            return false;
        }

        String normalized = statusValue.toLowerCase();
        return normalized.contains('reject') || normalized.contains('declin') || normalized.contains('not approved');
    }

    private static Boolean isUnderReviewStatus(String statusValue) {
        if (String.isBlank(statusValue)) {
            return false;
        }

        String normalized = statusValue.toLowerCase();
        return normalized.contains('pending') || normalized.contains('review');
    }

    private static Boolean isProvisionalStatus(String statusValue) {
        if (String.isBlank(statusValue)) {
            return false;
        }

        String normalized = statusValue.toLowerCase();
        return normalized.contains('provisional') || normalized.contains('alloted') || normalized.contains('allotted');
    }

    private static Boolean hasWindowProgramScope(WindowScope scope) {
        return scope != null &&
            (
                (scope.learningProgramPlanIds != null && !scope.learningProgramPlanIds.isEmpty()) ||
                (scope.learningProgramIds != null && !scope.learningProgramIds.isEmpty())
            );
    }

    private static Boolean matchesWindowProgramScope(WindowScope scope, LearnerProgram learnerProgram) {
        Boolean hasPlanScope = scope != null && scope.learningProgramPlanIds != null && !scope.learningProgramPlanIds.isEmpty();
        Boolean hasProgramScope = scope != null && scope.learningProgramIds != null && !scope.learningProgramIds.isEmpty();
        if (!hasPlanScope && !hasProgramScope) {
            return true;
        }

        Id learningProgramPlanId = learnerProgram != null ? learnerProgram.LearningProgramPlanId : null;
        Id learningProgramId = learnerProgram != null && learnerProgram.LearningProgramPlan != null
            ? learnerProgram.LearningProgramPlan.LearningProgramId
            : null;

        if (hasPlanScope && learningProgramPlanId != null && scope.learningProgramPlanIds.contains(learningProgramPlanId)) {
            return true;
        }
        if (hasProgramScope && learningProgramId != null && scope.learningProgramIds.contains(learningProgramId)) {
            return true;
        }
        return false;
    }

    private static Boolean isPreferredLearnerProgram(LearnerProgram candidate, LearnerProgram current) {
        Boolean candidateActive = candidate != null && String.valueOf(candidate.Status).equalsIgnoreCase('Active');
        Boolean currentActive = current != null && String.valueOf(current.Status).equalsIgnoreCase('Active');
        if (candidateActive != currentActive) {
            return candidateActive;
        }

        Date candidateStartDate = candidate != null ? candidate.StartDate : null;
        Date currentStartDate = current != null ? current.StartDate : null;
        if (candidateStartDate != currentStartDate) {
            if (candidateStartDate == null) {
                return false;
            }
            if (currentStartDate == null) {
                return true;
            }
            return candidateStartDate > currentStartDate;
        }

        Datetime candidateModified = candidate != null ? candidate.LastModifiedDate : null;
        Datetime currentModified = current != null ? current.LastModifiedDate : null;
        if (candidateModified == currentModified) {
            return false;
        }
        if (candidateModified == null) {
            return false;
        }
        if (currentModified == null) {
            return true;
        }
        return candidateModified.getTime() > currentModified.getTime();
    }

    private static String sanitize(String value) {
        return value == null ? null : value.trim();
    }

    private static String normalizeFloorOptionLabel(String value) {
        String floorLabel = sanitize(value);
        if (String.isBlank(floorLabel)) {
            return null;
        }

        Matcher floorNumberMatcher = Pattern.compile('(\\d+)').matcher(floorLabel.toLowerCase());
        if (floorNumberMatcher.find()) {
            Integer floorNumber = Integer.valueOf(floorNumberMatcher.group(1));
            if (floorNumber > 0) {
                return String.valueOf(floorNumber) + getOrdinalSuffix(floorNumber) + ' Floor';
            }
        }

        return floorLabel;
    }

    private static String normalizeFloorOptionValue(String value) {
        String floorLabel = normalizeFloorOptionLabel(value);
        return floorLabel != null ? floorLabel.toLowerCase() : null;
    }

    private static String getOrdinalSuffix(Integer value) {
        if (value == null) {
            return 'th';
        }

        Integer absoluteValue = Math.abs(value);
        Integer lastTwoDigits = Math.mod(absoluteValue, 100);
        if (lastTwoDigits >= 11 && lastTwoDigits <= 13) {
            return 'th';
        }

        Integer lastDigit = Math.mod(absoluteValue, 10);
        if (lastDigit == 1) {
            return 'st';
        }
        if (lastDigit == 2) {
            return 'nd';
        }
        if (lastDigit == 3) {
            return 'rd';
        }
        return 'th';
    }

    private static Integer toWholeNumber(Object value) {
        if (value == null) {
            return 0;
        }

        String raw = sanitize(String.valueOf(value));
        if (String.isBlank(raw)) {
            return 0;
        }

        try {
            return Decimal.valueOf(raw).intValue();
        } catch (Exception e) {
            return 0;
        }
    }

    private static String toSharingCardLabel(Decimal capacity) {
        String sharingValue = toSharingLabel(capacity);
        return String.isBlank(sharingValue) ? null : sharingValue.replace('-', ' ');
    }

    private static String toAcademicYear(Date startDateValue, Date endDateValue) {
        if (startDateValue == null && endDateValue == null) {
            return '--';
        }

        Integer startYear = startDateValue != null ? startDateValue.year() : endDateValue.year();
        Integer endYear = endDateValue != null ? endDateValue.year() : startYear + 1;
        return String.valueOf(startYear) + ' - ' + String.valueOf(endYear);
    }

    private static String buildResidenceAllocationTitle(
        Datetime cycleStartDateTime,
        Datetime cycleEndDateTime,
        Date fallbackStartDate,
        Date fallbackEndDate
    ) {
        Date startDateValue = cycleStartDateTime != null ? cycleStartDateTime.date() : fallbackStartDate;
        Date endDateValue = cycleEndDateTime != null ? cycleEndDateTime.date() : fallbackEndDate;
        if (startDateValue == null && endDateValue == null) {
            return 'Residence Allocation';
        }

        Integer startYear = startDateValue != null ? startDateValue.year() : endDateValue.year();
        Integer endYear = endDateValue != null ? endDateValue.year() : startYear + 1;
        String endYearText = String.valueOf(endYear);
        String endYearLabel = endYearText.length() >= 2
            ? endYearText.substring(endYearText.length() - 2, endYearText.length())
            : '0' + endYearText;
        return 'Residence Allocation ' + startYear + '-' + endYearLabel;
    }

    private static String formatDateLabel(Date dateValue) {
        if (dateValue == null) {
            return '--';
        }
        DateTime dateTimeValue = DateTime.newInstance(dateValue, Time.newInstance(0, 0, 0, 0));
        return dateTimeValue.format('dd MMM yyyy');
    }

    private static String formatCurrencyLabel(Decimal amount) {
        if (amount == null) {
            return '--';
        }
        return 'Rs ' + amount.setScale(0).format();
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

    private static String normalizeAmenities(String amenities) {
        if (String.isBlank(amenities)) {
            return null;
        }

        List<String> cleaned = new List<String>();
        for (String item : amenities.split(';')) {
            if (String.isNotBlank(item)) {
                cleaned.add(item.trim());
            }
        }
        return cleaned.isEmpty() ? null : String.join(cleaned, ', ');
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
        ensureReadable(Schema.sObjectType.Ken_Windows__c, 'You do not have permission to view residence windows.');

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