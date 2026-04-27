@IsTest
private class KenNavigationMenuControllerTest {
    @IsTest
    static void testGetUserContactDetailsUsesCurrentAllotment() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'navmenu',
            true,
            false
        );

        System.runAs(context.runUser) {
            KenNavigationMenuController.UserContactDetails details = KenNavigationMenuController.getUserContactDetails();
            System.assertEquals(context.studentAccount.Name, details.studentName);
            System.assertEquals('System Administrator', details.profileName);
        }
    }
}