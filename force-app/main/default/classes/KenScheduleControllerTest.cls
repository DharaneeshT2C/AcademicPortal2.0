/**
 * ************************************************************************************************
 * @className  KenScheduleControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenScheduleControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void scheduleReturnsBlocks() {
        Test.startTest();
        List<KenScheduleController.ScheduleBlockDTO> blocks = KenScheduleController.getWeeklySchedule();
        Test.stopTest();

        System.assertNotEquals(null, blocks);
        System.assertEquals(true, blocks.size() > 0);
        for (KenScheduleController.ScheduleBlockDTO b : blocks) {
            System.assertNotEquals(null, b.dayOfWeek);
            System.assertNotEquals(null, b.startTime);
        }
    }
}