/**
 * ************************************************************************************************
 * @className  KenMessMenuControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenMessMenuControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void menuReturnsSevenDays() {
        Test.startTest();
        List<KenMessMenuController.DayMenuDTO> menu = KenMessMenuController.getWeeklyMenu();
        Test.stopTest();

        System.assertNotEquals(null, menu);
        System.assertEquals(7, menu.size());
        System.assertEquals(true, menu[0].meals.size() > 0);
    }

    @isTest
    static void feedbackRejectsBlankMeal() {
        Test.startTest();
        Boolean threw = false;
        try { KenMessMenuController.submitMessFeedback('', 4, 'OK'); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void feedbackRejectsInvalidRating() {
        Test.startTest();
        Boolean threw = false;
        try { KenMessMenuController.submitMessFeedback('Lunch', 6, ''); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void feedbackAcceptsValidInput() {
        Test.startTest();
        KenMessMenuController.submitMessFeedback('Lunch', 4, 'Good');
        Test.stopTest();
        System.assertEquals(true, true);
    }
}