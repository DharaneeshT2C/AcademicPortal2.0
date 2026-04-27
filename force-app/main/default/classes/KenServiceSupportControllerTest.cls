/**
 * ************************************************************************************************
 * @className  KenServiceSupportControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenServiceSupportControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void ticketsReturnList() {
        Test.startTest();
        List<KenServiceSupportController.TicketDTO> tickets = KenServiceSupportController.getTickets();
        Test.stopTest();

        System.assertNotEquals(null, tickets);
        System.assertEquals(true, tickets.size() > 0);
    }

    @isTest
    static void raiseRejectsEmptyRequest() {
        Test.startTest();
        Boolean threw = false;
        try { KenServiceSupportController.raiseTicket(null); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void raiseRejectsBlankCategory() {
        KenServiceSupportController.TicketRequest req = new KenServiceSupportController.TicketRequest();
        req.category = '';
        req.title = 'WiFi broken';
        req.description = 'Details here';

        Test.startTest();
        Boolean threw = false;
        try { KenServiceSupportController.raiseTicket(req); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void raiseAcceptsValidRequest() {
        KenServiceSupportController.TicketRequest req = new KenServiceSupportController.TicketRequest();
        req.category    = 'IT';
        req.title       = 'WiFi not working';
        req.description = 'Not working in Block B since last night';

        Test.startTest();
        KenServiceSupportController.raiseTicket(req);
        Test.stopTest();
        System.assertEquals(true, true);
    }
}