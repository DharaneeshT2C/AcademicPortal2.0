/**
 * @description
 *  Finds Person Accounts by Constituent Role and enables selected records as Experience Cloud users.
 */
public without sharing class StudentCommunityUserController {
    private static final String ROLE_TYPE_STUDENT = 'Student';
    private static final String ROLE_TYPE_FACULTY = 'Faculty';
    private static final Set<String> SUPPORTED_ROLE_TYPES = new Set<String>{
        ROLE_TYPE_STUDENT,
        ROLE_TYPE_FACULTY
    };
    private static final String PROFILE_NAME_STUDENT = 'Student';
    private static final String PROFILE_NAME_FACULTY = 'Faculty';
    private static final String LICENSE_NAME_CUSTOMER_COMMUNITY_PLUS_LOGIN = 'Customer Community Plus Login';
    private static final String PERMISSION_SET_EDU_CLOUD_STUDENT = 'Customer Community - Edu Cloud - Student';
    private static final String PERMISSION_SET_CUSTOMER_COMMUNITY_STUDENT = 'Customer Community - Student';

    public class StudentAccountRow {
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String programPlanName;
        @AuraEnabled public String roleType;
        @AuraEnabled public Boolean hasExistingUser;
        @AuraEnabled public String existingUsername;
        @AuraEnabled public Boolean canEnable;
        @AuraEnabled public String statusMessage;
    }

    public class EnableResult {
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id contactId;
        @AuraEnabled public Id userId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String username;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }

    public class ProgramPlanOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    @AuraEnabled
    public static List<StudentAccountRow> getEligibleStudentAccounts(String searchTerm) {
        return getEligibleAccounts(ROLE_TYPE_STUDENT, searchTerm, null);
    }

    @AuraEnabled
    public static List<StudentAccountRow> getEligibleAccounts(
        String roleType,
        String searchTerm,
        Id programPlanId
    ) {
        String resolvedRoleType = normalizeRoleType(roleType);
        Set<Id> rolePersonIds = getRolePersonIds(resolvedRoleType);
        if (rolePersonIds.isEmpty()) {
            return new List<StudentAccountRow>();
        }
        String normalizedSearchTerm = String.isBlank(searchTerm) ? null : searchTerm.trim();
        String likeSearchTerm = String.isBlank(normalizedSearchTerm)
            ? null
            : '%' + normalizedSearchTerm + '%';
        List<Account> accountRecords;
        if (String.isBlank(likeSearchTerm)) {
            accountRecords = [
                SELECT Id, Name, FirstName, LastName, PersonEmail, PersonContactId, Phone
                FROM Account
                WHERE IsPersonAccount = true
                AND (Id IN :rolePersonIds OR PersonContactId IN :rolePersonIds)
                ORDER BY Name
                LIMIT 2000
            ];
        } else {
            accountRecords = [
                SELECT Id, Name, FirstName, LastName, PersonEmail, PersonContactId, Phone
                FROM Account
                WHERE IsPersonAccount = true
                AND (Id IN :rolePersonIds OR PersonContactId IN :rolePersonIds)
                AND (Name LIKE :likeSearchTerm OR PersonEmail LIKE :likeSearchTerm)
                ORDER BY Name
                LIMIT 2000
            ];
        }
        Map<Id, Account> accountsById = new Map<Id, Account>(accountRecords);

        Map<Id, User> usersByContactId = new Map<Id, User>();
        Set<Id> contactIds = new Set<Id>();
        for (Account accountRecord : accountsById.values()) {
            if (accountRecord.PersonContactId != null) {
                contactIds.add(accountRecord.PersonContactId);
            }
        }
        Map<Id, String> programPlanNamesByAccountId = new Map<Id, String>();
        Map<Id, String> programPlanNamesByContactId = new Map<Id, String>();

        if (!contactIds.isEmpty()) {
            for (User existingUser : [
                SELECT Id, ContactId, Username, IsActive
                FROM User
                WHERE ContactId IN :contactIds
            ]) {
                usersByContactId.put(existingUser.ContactId, existingUser);
            }
        }
        if (!accountsById.isEmpty() || !contactIds.isEmpty()) {
            List<LearnerProgram> learnerPrograms = new List<LearnerProgram>();
            if (programPlanId == null) {
                learnerPrograms = [
                    SELECT LearnerAccountId, LearnerContactId, LearningProgramPlanId, LearningProgramPlan.Name
                    FROM LearnerProgram
                    WHERE LearnerAccountId IN :accountsById.keySet()
                    OR LearnerContactId IN :contactIds
                ];
            } else {
                learnerPrograms = [
                    SELECT LearnerAccountId, LearnerContactId, LearningProgramPlanId, LearningProgramPlan.Name
                    FROM LearnerProgram
                    WHERE (LearnerAccountId IN :accountsById.keySet()
                    OR LearnerContactId IN :contactIds)
                    AND LearningProgramPlanId = :programPlanId
                ];
            }
            for (LearnerProgram learnerProgram : learnerPrograms) {
                String planName = learnerProgram.LearningProgramPlan == null
                    ? null
                    : learnerProgram.LearningProgramPlan.Name;
                if (String.isBlank(planName)) {
                    continue;
                }
                appendProgramPlanName(programPlanNamesByAccountId, learnerProgram.LearnerAccountId, planName);
                appendProgramPlanName(programPlanNamesByContactId, learnerProgram.LearnerContactId, planName);
            }
        }
        List<StudentAccountRow> rows = new List<StudentAccountRow>();
        for (Account accountRecord : accountsById.values()) {
            if (!matchesSearchTerm(accountRecord, normalizedSearchTerm)) {
                continue;
            }
            User existingUser = usersByContactId.get(accountRecord.PersonContactId);
            if (existingUser != null ||
                accountRecord.PersonContactId == null ||
                String.isBlank(accountRecord.PersonEmail) ||
                String.isBlank(accountRecord.LastName)) {
                continue;
            }
            String programPlanName = programPlanNamesByAccountId.get(accountRecord.Id);
            if (String.isBlank(programPlanName)) {
                programPlanName = programPlanNamesByContactId.get(accountRecord.PersonContactId);
            }
            if (programPlanId != null && String.isBlank(programPlanName)) {
                continue;
            }
            StudentAccountRow row = new StudentAccountRow();
            row.accountId = accountRecord.Id;
            row.contactId = accountRecord.PersonContactId;
            row.accountName = accountRecord.Name;
            row.firstName = accountRecord.FirstName;
            row.lastName = accountRecord.LastName;
            row.email = accountRecord.PersonEmail;
            row.phone = accountRecord.Phone;
            row.programPlanName = programPlanName;
            row.roleType = resolvedRoleType;
            row.hasExistingUser = false;
            row.canEnable = true;
            row.statusMessage = 'Ready to enable.';
            rows.add(row);
        }
        return rows;
    }

    private static Boolean matchesSearchTerm(Account accountRecord, String normalizedSearchTerm) {
        if (String.isBlank(normalizedSearchTerm)) {
            return true;
        }
        String searchTerm = normalizedSearchTerm.toLowerCase();
        String accountName = String.isBlank(accountRecord.Name) ? '' : accountRecord.Name.toLowerCase();
        String email = String.isBlank(accountRecord.PersonEmail) ? '' : accountRecord.PersonEmail.toLowerCase();
        return accountName.contains(searchTerm) || email.contains(searchTerm);
    }

    @AuraEnabled
    public static List<ProgramPlanOption> getActiveProgramPlanOptions() {
        Set<Id> seenPlanIds = new Set<Id>();
        List<ProgramPlanOption> options = new List<ProgramPlanOption>();
        for (LearnerProgram learnerProgram : [
            SELECT LearningProgramPlanId, LearningProgramPlan.Name
            FROM LearnerProgram
            WHERE Status = 'Active'
            AND LearningProgramPlanId != null
            ORDER BY LearningProgramPlan.Name
            LIMIT 5000
        ]) {
            if (learnerProgram.LearningProgramPlanId != null &&
                learnerProgram.LearningProgramPlan != null &&
                String.isNotBlank(learnerProgram.LearningProgramPlan.Name) &&
                !seenPlanIds.contains(learnerProgram.LearningProgramPlanId)) {
                seenPlanIds.add(learnerProgram.LearningProgramPlanId);
                ProgramPlanOption option = new ProgramPlanOption();
                option.label = learnerProgram.LearningProgramPlan.Name;
                option.value = String.valueOf(learnerProgram.LearningProgramPlanId);
                options.add(option);
            }
        }
        return options;
    }

    private static void appendProgramPlanName(Map<Id, String> namesById, Id recordId, String planName) {
        if (namesById == null || recordId == null || String.isBlank(planName)) {
            return;
        }
        String existingNames = namesById.get(recordId);
        if (String.isBlank(existingNames)) {
            namesById.put(recordId, planName);
        } else if (!existingNames.contains(planName)) {
            namesById.put(recordId, existingNames + '; ' + planName);
        }
    }

    @AuraEnabled
    public static List<EnableResult> enableStudentUsers(List<Id> accountIds) {
        return enableUsers(accountIds, ROLE_TYPE_STUDENT);
    }

    @AuraEnabled
    public static List<EnableResult> enableUsers(List<Id> accountIds, String roleType) {
        if (accountIds == null || accountIds.isEmpty()) {
            throw new AuraHandledException('Select at least one record.');
        }

        String resolvedRoleType = normalizeRoleType(roleType);
        Set<Id> rolePersonIds = getRolePersonIds(resolvedRoleType);
        Profile communityProfile = getCommunityProfile(resolvedRoleType);
        List<Account> accounts = [
            SELECT Id, Name, FirstName, LastName, PersonEmail, PersonContactId, Phone
            FROM Account
            WHERE Id IN :accountIds
            AND IsPersonAccount = true
            AND (Id IN :rolePersonIds OR PersonContactId IN :rolePersonIds)
            ORDER BY Name
        ];

        Set<Id> contactIds = new Set<Id>();
        for (Account accountRecord : accounts) {
            if (accountRecord.PersonContactId != null) {
                contactIds.add(accountRecord.PersonContactId);
            }
        }

        Map<Id, User> existingUsersByContactId = new Map<Id, User>();
        if (!contactIds.isEmpty()) {
            for (User existingUser : [
                SELECT Id, ContactId, Username
                FROM User
                WHERE ContactId IN :contactIds
            ]) {
                existingUsersByContactId.put(existingUser.ContactId, existingUser);
            }
        }

        List<User> usersToInsert = new List<User>();
        List<EnableResult> orderedResults = new List<EnableResult>();
        List<Integer> insertResultIndexes = new List<Integer>();
        Map<Integer, Id> existingUserIdByResultIndex = new Map<Integer, Id>();
        for (Account accountRecord : accounts) {
            EnableResult result = baseResult(accountRecord);
            orderedResults.add(result);
            Integer resultIndex = orderedResults.size() - 1;

            User existingUser = existingUsersByContactId.get(accountRecord.PersonContactId);
            if (existingUser != null) {
                result.userId = existingUser.Id;
                result.username = existingUser.Username;
                result.success = true;
                result.message = 'User already exists. Permission sets checked.';
                existingUserIdByResultIndex.put(resultIndex, existingUser.Id);
                continue;
            }

            String validationMessage = validateAccountForUser(accountRecord);
            if (String.isNotBlank(validationMessage)) {
                result.success = false;
                result.message = validationMessage;
                continue;
            }

            User userRecord = buildUser(accountRecord, communityProfile.Id);
            usersToInsert.add(userRecord);
            insertResultIndexes.add(resultIndex);
        }

        if (!usersToInsert.isEmpty()) {
            Database.SaveResult[] userResults = Database.insert(usersToInsert, false);
            Map<Integer, Id> createdUserIdByResultIndex = new Map<Integer, Id>();

            for (Integer i = 0; i < userResults.size(); i++) {
                Integer resultIndex = insertResultIndexes[i];
                EnableResult result = orderedResults[resultIndex];
                if (userResults[i].isSuccess()) {
                    Id userId = userResults[i].getId();
                    result.userId = userId;
                    result.username = usersToInsert[i].Username;
                    result.success = true;
                    result.message = 'User created successfully.';
                    createdUserIdByResultIndex.put(resultIndex, userId);
                } else {
                    result.success = false;
                    result.message = firstError(userResults[i]);
                }
            }

            existingUserIdByResultIndex.putAll(createdUserIdByResultIndex);
        }

        Set<Id> permissionSetIds = getConfiguredPermissionSetIds(resolvedRoleType);
        if (permissionSetIds.isEmpty() && !existingUserIdByResultIndex.isEmpty()) {
            appendPermissionSetMessage(
                orderedResults,
                existingUserIdByResultIndex,
                ' No active ' + resolvedRoleType + ' permission set metadata resolved to an assignable permission set.'
            );
        } else if (!existingUserIdByResultIndex.isEmpty()) {
            applyPermissionSets(
                buildMissingPermissionSetAssignments(existingUserIdByResultIndex, permissionSetIds),
                orderedResults,
                existingUserIdByResultIndex
            );
        }

        return orderedResults;
    }

    private static String normalizeRoleType(String roleType) {
        String resolvedRoleType = String.isBlank(roleType) ? ROLE_TYPE_STUDENT : roleType.trim();
        if (!SUPPORTED_ROLE_TYPES.contains(resolvedRoleType)) {
            throw new AuraHandledException('Unsupported role type: ' + resolvedRoleType + '.');
        }
        return resolvedRoleType;
    }

    private static Set<Id> getRolePersonIds(String roleType) {
        Set<Id> rolePersonIds = new Set<Id>();
        for (ConstituentRole role : [
            SELECT PersonId
            FROM ConstituentRole
            WHERE RoleType = :roleType
            AND PersonId != null
            LIMIT 5000
        ]) {
            rolePersonIds.add(role.PersonId);
        }
        return rolePersonIds;
    }

    private static String getRowStatusMessage(StudentAccountRow row) {
        if (row.hasExistingUser == true) {
            return 'User already exists: ' + row.existingUsername;
        }
        if (row.contactId == null) {
            return 'Missing Person Contact Id.';
        }
        if (String.isBlank(row.email)) {
            return 'Missing email.';
        }
        if (String.isBlank(row.lastName)) {
            return 'Missing last name.';
        }
        return 'Ready to enable.';
    }

    private static Profile getCommunityProfile(String roleType) {
        String profileName = getProfileNameForRoleType(roleType);
        List<Profile> profiles = [
            SELECT Id, Name, UserLicense.Name
            FROM Profile
            WHERE Name = :profileName
            AND UserLicense.Name = :LICENSE_NAME_CUSTOMER_COMMUNITY_PLUS_LOGIN
            LIMIT 1
        ];
        if (profiles.isEmpty()) {
            throw new AuraHandledException(
                'Profile "' + profileName + '" with license "' +
                LICENSE_NAME_CUSTOMER_COMMUNITY_PLUS_LOGIN + '" was not found.'
            );
        }
        return profiles[0];
    }

    private static String getProfileNameForRoleType(String roleType) {
        return roleType == ROLE_TYPE_FACULTY
            ? PROFILE_NAME_FACULTY
            : PROFILE_NAME_STUDENT;
    }

    private static EnableResult baseResult(Account accountRecord) {
        EnableResult result = new EnableResult();
        result.accountId = accountRecord.Id;
        result.contactId = accountRecord.PersonContactId;
        result.accountName = accountRecord.Name;
        result.success = false;
        return result;
    }

    private static String validateAccountForUser(Account accountRecord) {
        if (accountRecord.PersonContactId == null) {
            return 'Skipped: Person Account has no Person Contact Id.';
        }
        if (String.isBlank(accountRecord.PersonEmail)) {
            return 'Skipped: email is required to create an Experience Cloud user.';
        }
        if (String.isBlank(accountRecord.LastName)) {
            return 'Skipped: last name is required.';
        }
        return null;
    }

    private static User buildUser(Account accountRecord, Id profileId) {
        String firstName = accountRecord.FirstName;
        String lastName = String.isBlank(accountRecord.LastName) ? accountRecord.Name : accountRecord.LastName;
        String email = accountRecord.PersonEmail.trim();
        String uniqueSuffix = String.valueOf(Crypto.getRandomInteger()).replace('-', '').left(6);
        String username = makeUsername(email, accountRecord.Id, uniqueSuffix);

        User userRecord = new User();
        userRecord.ContactId = accountRecord.PersonContactId;
        userRecord.ProfileId = profileId;
        userRecord.FirstName = firstName;
        userRecord.LastName = lastName;
        userRecord.Email = email;
        userRecord.Username = username;
        userRecord.Phone = accountRecord.Phone;
        userRecord.Alias = makeAlias(firstName, lastName);
        userRecord.CommunityNickname = makeNickname(firstName, lastName, uniqueSuffix);
        userRecord.TimeZoneSidKey = UserInfo.getTimeZone().getID();
        userRecord.LocaleSidKey = UserInfo.getLocale();
        userRecord.EmailEncodingKey = 'UTF-8';
        userRecord.LanguageLocaleKey = UserInfo.getLanguage();
        userRecord.IsActive = true;
        return userRecord;
    }

    private static String makeUsername(String email, Id accountId, String uniqueSuffix) {
        String localPart = email;
        String domainPart = 'student.local';
        Integer atIndex = email.indexOf('@');
        if (atIndex > 0 && atIndex < email.length() - 1) {
            localPart = email.substring(0, atIndex);
            domainPart = email.substring(atIndex + 1);
        }
        String accountToken = String.valueOf(accountId).right(5).toLowerCase();
        String suffix = '+' + accountToken + uniqueSuffix + '@' + domainPart;
        Integer maxLocalLength = 80 - suffix.length();
        if (maxLocalLength < 1) {
            maxLocalLength = 1;
        }
        if (localPart.length() > maxLocalLength) {
            localPart = localPart.left(maxLocalLength);
        }
        return localPart + suffix;
    }

    private static String makeAlias(String firstName, String lastName) {
        String aliasValue = (String.isBlank(firstName) ? '' : firstName.left(1)) +
            (String.isBlank(lastName) ? 'student' : lastName);
        aliasValue = aliasValue.replaceAll('[^A-Za-z0-9]', '');
        if (String.isBlank(aliasValue)) {
            aliasValue = 'student';
        }
        if (aliasValue.length() > 8) {
            aliasValue = aliasValue.left(8);
        }
        return aliasValue.toLowerCase();
    }

    private static String makeNickname(String firstName, String lastName, String uniqueSuffix) {
        String nickname = ((String.isBlank(firstName) ? '' : firstName) +
            (String.isBlank(lastName) ? 'Student' : lastName) +
            uniqueSuffix).replaceAll('[^A-Za-z0-9]', '');
        if (String.isBlank(nickname)) {
            return 'Student' + uniqueSuffix;
        }
        return nickname.length() > 40 ? nickname.left(40) : nickname;
    }

    private static Set<Id> getConfiguredPermissionSetIds(String roleType) {
        String resolvedRoleType = normalizeRoleType(roleType);
        Set<String> permissionSetNamesOrLabels = getDefaultPermissionSetNames(resolvedRoleType);
        Set<Id> explicitIds = new Set<Id>();

        if (resolvedRoleType == ROLE_TYPE_FACULTY) {
            addFacultyConfiguredPermissionSets(permissionSetNamesOrLabels, explicitIds);
        } else {
            addStudentConfiguredPermissionSets(permissionSetNamesOrLabels, explicitIds);
        }

        Set<Id> permissionSetIds = new Set<Id>();
        permissionSetIds.addAll(explicitIds);
        if (!permissionSetNamesOrLabels.isEmpty()) {
            for (PermissionSet ps : [
                SELECT Id
                FROM PermissionSet
                WHERE IsOwnedByProfile = false
                AND (Name IN :permissionSetNamesOrLabels OR Label IN :permissionSetNamesOrLabels)
            ]) {
                permissionSetIds.add(ps.Id);
            }
        }
        return permissionSetIds;
    }

    private static Set<String> getDefaultPermissionSetNames(String roleType) {
        if (roleType == ROLE_TYPE_FACULTY) {
            return new Set<String>();
        }
        return new Set<String>{
            PERMISSION_SET_EDU_CLOUD_STUDENT,
            PERMISSION_SET_CUSTOMER_COMMUNITY_STUDENT
        };
    }

    private static void addStudentConfiguredPermissionSets(
        Set<String> permissionSetNamesOrLabels,
        Set<Id> explicitIds
    ) {
        for (Student_User_Permission_Set__mdt mapping : [
            SELECT Permission_Set_API_Name__c, Permission_Set_Id__c, Active__c
            FROM Student_User_Permission_Set__mdt
            WHERE Active__c = true
        ]) {
            addPermissionSetMapping(mapping.Permission_Set_API_Name__c, mapping.Permission_Set_Id__c, permissionSetNamesOrLabels, explicitIds);
        }
    }

    private static void addFacultyConfiguredPermissionSets(
        Set<String> permissionSetNamesOrLabels,
        Set<Id> explicitIds
    ) {
        for (Faculty_User_Permission_Set__mdt mapping : [
            SELECT Permission_Set_API_Name__c, Permission_Set_Id__c, Active__c
            FROM Faculty_User_Permission_Set__mdt
            WHERE Active__c = true
        ]) {
            addPermissionSetMapping(mapping.Permission_Set_API_Name__c, mapping.Permission_Set_Id__c, permissionSetNamesOrLabels, explicitIds);
        }
    }

    private static void addPermissionSetMapping(
        String permissionSetNameOrLabel,
        String permissionSetId,
        Set<String> permissionSetNamesOrLabels,
        Set<Id> explicitIds
    ) {
        if (String.isNotBlank(permissionSetNameOrLabel)) {
            permissionSetNamesOrLabels.add(permissionSetNameOrLabel.trim());
        }
        if (String.isNotBlank(permissionSetId)) {
            try {
                explicitIds.add((Id) permissionSetId.trim());
            } catch (Exception ignored) {
                // Ignore invalid metadata ids and keep valid API-name mappings working.
            }
        }
    }

    private static List<PermissionSetAssignment> buildMissingPermissionSetAssignments(
        Map<Integer, Id> userIdByResultIndex,
        Set<Id> permissionSetIds
    ) {
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        if (userIdByResultIndex == null || userIdByResultIndex.isEmpty() || permissionSetIds == null || permissionSetIds.isEmpty()) {
            return assignments;
        }

        Set<Id> userIds = new Set<Id>(userIdByResultIndex.values());
        Set<String> existingAssignmentKeys = new Set<String>();
        for (PermissionSetAssignment assignment : [
            SELECT AssigneeId, PermissionSetId
            FROM PermissionSetAssignment
            WHERE AssigneeId IN :userIds
            AND PermissionSetId IN :permissionSetIds
        ]) {
            existingAssignmentKeys.add(makePermissionAssignmentKey(assignment.AssigneeId, assignment.PermissionSetId));
        }

        for (Id userId : userIds) {
            for (Id permissionSetId : permissionSetIds) {
                if (!existingAssignmentKeys.contains(makePermissionAssignmentKey(userId, permissionSetId))) {
                    assignments.add(new PermissionSetAssignment(
                        AssigneeId = userId,
                        PermissionSetId = permissionSetId
                    ));
                }
            }
        }
        return assignments;
    }

    private static String makePermissionAssignmentKey(Id userId, Id permissionSetId) {
        return String.valueOf(userId) + ':' + String.valueOf(permissionSetId);
    }

    private static void applyPermissionSets(
        List<PermissionSetAssignment> assignments,
        List<EnableResult> orderedResults,
        Map<Integer, Id> createdUserIdByResultIndex
    ) {
        if (assignments == null || assignments.isEmpty()) {
            appendPermissionSetMessage(orderedResults, createdUserIdByResultIndex, ' Permission sets were already assigned.');
            return;
        }
        Database.SaveResult[] assignmentResults = Database.insert(assignments, false);
        Set<Id> usersWithAssignmentErrors = new Set<Id>();
        for (Integer i = 0; i < assignmentResults.size(); i++) {
            if (!assignmentResults[i].isSuccess()) {
                usersWithAssignmentErrors.add(assignments[i].AssigneeId);
            }
        }
        if (usersWithAssignmentErrors.isEmpty()) {
            return;
        }
        for (Integer resultIndex : createdUserIdByResultIndex.keySet()) {
            Id userId = createdUserIdByResultIndex.get(resultIndex);
            if (usersWithAssignmentErrors.contains(userId)) {
                orderedResults[resultIndex].message += ' Some permission sets could not be assigned.';
            }
        }
    }

    private static void appendPermissionSetMessage(
        List<EnableResult> orderedResults,
        Map<Integer, Id> userIdByResultIndex,
        String message
    ) {
        if (orderedResults == null || userIdByResultIndex == null || String.isBlank(message)) {
            return;
        }
        for (Integer resultIndex : userIdByResultIndex.keySet()) {
            if (resultIndex >= 0 && resultIndex < orderedResults.size()) {
                orderedResults[resultIndex].message += message;
            }
        }
    }

    private static String firstError(Database.SaveResult result) {
        if (result == null || result.getErrors() == null || result.getErrors().isEmpty()) {
            return 'Unknown error.';
        }
        return result.getErrors()[0].getMessage();
    }
}