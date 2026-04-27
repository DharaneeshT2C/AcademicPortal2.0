/**
 * ************************************************************************************************
 * @className  KenCampusLifeControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenCampusLifeControllerTest {

    @isTest
    static void overviewReturnsShortcutsAndAnnouncements() {
        Test.startTest();
        KenCampusLifeController.CampusOverviewDTO o = KenCampusLifeController.getCampusOverview();
        Test.stopTest();

        System.assertNotEquals(null, o);
        System.assertEquals(true, o.shortcuts.size() > 0);
        System.assertEquals(true, o.announcements.size() > 0);
    }
}