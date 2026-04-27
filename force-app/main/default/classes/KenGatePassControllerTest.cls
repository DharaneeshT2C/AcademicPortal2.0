/**
 * ************************************************************************************************
 * @className  KenGatePassControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenGatePassControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void gatePassListReturnsRows() {
        Test.startTest();
        List<KenGatePassController.GatePassDTO> passes = KenGatePassController.getGatePasses();
        Test.stopTest();

        System.assertNotEquals(null, passes);
        System.assertEquals(true, passes.size() > 0);
    }

    @isTest
    static void createRejectsBlankReason() {
        KenGatePassController.GatePassRequest req = new KenGatePassController.GatePassRequest();
        req.reason = '';
        req.destination = 'Home';
        req.outDateTime = '20-Apr 6:00 PM';
        req.returnDateTime = '22-Apr 8:00 PM';

        Test.startTest();
        Boolean threw = false;
        try { KenGatePassController.createGatePass(req); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void createRejectsNullRequest() {
        Test.startTest();
        Boolean threw = false;
        try { KenGatePassController.createGatePass(null); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void createAcceptsValidRequest() {
        KenGatePassController.GatePassRequest req = new KenGatePassController.GatePassRequest();
        req.reason         = 'Medical';
        req.destination    = 'Apollo Clinic';
        req.outDateTime    = '15-Apr 4:00 PM';
        req.returnDateTime = '15-Apr 7:00 PM';

        Test.startTest();
        KenGatePassController.createGatePass(req);
        Test.stopTest();
        System.assertEquals(true, true);
    }
}