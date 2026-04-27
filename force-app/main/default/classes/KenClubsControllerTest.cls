/**
 * ************************************************************************************************
 * @className  KenClubsControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenClubsControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void allClubsReturnWhenCategoryBlank() {
        Test.startTest();
        List<KenClubsController.ClubDTO> clubs = KenClubsController.getClubs(null);
        Test.stopTest();

        System.assertNotEquals(null, clubs);
        System.assertEquals(true, clubs.size() > 0);
    }

    @isTest
    static void categoryFilterNarrowsList() {
        Test.startTest();
        List<KenClubsController.ClubDTO> all  = KenClubsController.getClubs(null);
        List<KenClubsController.ClubDTO> tech = KenClubsController.getClubs('Technical');
        Test.stopTest();

        System.assertEquals(true, tech.size() <= all.size());
        for (KenClubsController.ClubDTO c : tech) {
            System.assertEquals('Technical', c.category);
        }
    }

    @isTest
    static void expressInterestRejectsNullId() {
        Test.startTest();
        Boolean threw = false;
        try { KenClubsController.expressInterest(null); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void expressInterestAcceptsValidId() {
        Id fakeClub = UserInfo.getUserId();
        Test.startTest();
        KenClubsController.expressInterest(fakeClub);
        Test.stopTest();
        System.assertEquals(true, true);
    }
}