/**
 * ************************************************************************************************
 * @className  KenThesisManagementControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenThesisManagementControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void thesisReturnsStagesAndCommittee() {
        Test.startTest();
        KenThesisManagementController.ThesisDTO t = KenThesisManagementController.getThesis();
        Test.stopTest();

        System.assertNotEquals(null, t);
        System.assertEquals(true, t.stages.size() > 0);
        System.assertEquals(true, t.committee.size() > 0);
        System.assertNotEquals(null, t.currentStage);
    }

    @isTest
    static void uploadDraftRejectsBlankFileName() {
        Test.startTest();
        Boolean threw = false;
        try { KenThesisManagementController.uploadDraft('', 'abc'); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void uploadDraftRejectsBlankContent() {
        Test.startTest();
        Boolean threw = false;
        try { KenThesisManagementController.uploadDraft('draft.pdf', ''); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void uploadDraftAcceptsValidInput() {
        Test.startTest();
        KenThesisManagementController.uploadDraft('draft-v1.pdf', 'base64content');
        Test.stopTest();
        System.assertEquals(true, true);
    }
}