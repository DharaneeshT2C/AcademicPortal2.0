@isTest(SeeAllData=false)
private class SideNavigationControllerTest {
    @isTest
    static void testGetCurrentUserProfileReturnsRunningUserData() {
        Test.startTest();
        SideNavigationController.CurrentUserProfile profile = SideNavigationController.getCurrentUserProfile();
        Test.stopTest();

        User currentUser = [
            SELECT FirstName, LastName, FullPhotoUrl
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        System.assertNotEquals(null, profile, 'Profile should be returned');
        System.assertEquals(currentUser.FirstName, profile.firstName, 'First name should match running user');
        System.assertEquals(currentUser.LastName, profile.lastName, 'Last name should match running user');
        System.assertEquals(currentUser.FullPhotoUrl, profile.photoUrl, 'Photo URL should match running user');
    }
}