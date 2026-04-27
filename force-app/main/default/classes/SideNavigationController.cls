public with sharing class SideNavigationController {
    public class CurrentUserProfile {
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String photoUrl;
        @AuraEnabled public String roleType;
    }

    @AuraEnabled(cacheable=true)
    public static CurrentUserProfile getCurrentUserProfile() {
        CurrentUserProfile profile = new CurrentUserProfile();

        User currentUser = [
            SELECT FirstName, LastName, FullPhotoUrl, ContactId, Contact.FirstName, Contact.LastName, Profile.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        profile.firstName = String.isNotBlank(currentUser.FirstName)
            ? currentUser.FirstName
            : (currentUser.Contact != null ? currentUser.Contact.FirstName : null);
        profile.lastName = String.isNotBlank(currentUser.LastName)
            ? currentUser.LastName
            : (currentUser.Contact != null ? currentUser.Contact.LastName : null);
        profile.photoUrl = currentUser.FullPhotoUrl;
        profile.roleType = resolveRoleType(currentUser);

        return profile;
    }

    private static String resolveRoleType(User currentUser) {
        if (currentUser != null && currentUser.ContactId != null) {
            List<ConstituentRole> studentRole = [
                SELECT Id, RoleType
                FROM ConstituentRole
                WHERE PersonId = :currentUser.ContactId
                //AND RoleType = :KenConstantController.ROLETYPE_STUDENT
                //AND Status = :KenConstantController.STATUS_ENROLLED
                LIMIT 1
            ];
            if (!studentRole.isEmpty()) {
                return studentRole[0].RoleType;
            }

            List<ConstituentRole> facultyRole = [
                SELECT Id, RoleType
                FROM ConstituentRole
                WHERE PersonId = :currentUser.ContactId
                AND RoleType = 'Faculty'
                LIMIT 1
            ];
            if (!facultyRole.isEmpty()) {
                return facultyRole[0].RoleType;
            }
        }

        return inferRoleType(currentUser != null && currentUser.Profile != null ? currentUser.Profile.Name : null);
    }

    private static String inferRoleType(String profileName) {
        String normalizedProfileName = String.isNotBlank(profileName) ? profileName.trim().toLowerCase() : '';

        if (normalizedProfileName.contains('faculty')) {
            return 'Faculty';
        }
        if (normalizedProfileName.contains('student')) {
            return 'Student';
        }
        return null;
    }
}