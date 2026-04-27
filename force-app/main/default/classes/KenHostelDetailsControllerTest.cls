/**
 * ************************************************************************************************
 * @className  KenHostelDetailsControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenHostelDetailsControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void hostelDetailsReturnRoomAndFacilities() {
        Test.startTest();
        KenHostelDetailsController.HostelDTO h = KenHostelDetailsController.getHostelDetails();
        Test.stopTest();

        System.assertNotEquals(null, h);
        System.assertNotEquals(null, h.roomNumber);
        System.assertEquals(true, h.facilities.size() > 0);
    }
}