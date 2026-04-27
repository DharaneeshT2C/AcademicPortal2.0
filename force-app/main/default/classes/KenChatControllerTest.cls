/**
 * ************************************************************************************************
 * @className  KenChatControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenChatControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void historyReturnsMessages() {
        Id fakeConv = UserInfo.getUserId();
        Test.startTest();
        List<KenChatController.ChatMessageDTO> msgs = KenChatController.getHistory(fakeConv);
        Test.stopTest();

        System.assertNotEquals(null, msgs);
        System.assertEquals(true, msgs.size() > 0);
    }

    @isTest
    static void sendRejectsBlankBody() {
        Id fakeConv = UserInfo.getUserId();
        Test.startTest();
        Boolean threw = false;
        try { KenChatController.sendMessage(fakeConv, ''); }
        catch (AuraHandledException e) { threw = true; }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @isTest
    static void sendReturnsAssistantReply() {
        Id fakeConv = UserInfo.getUserId();
        Test.startTest();
        KenChatController.ChatMessageDTO reply = KenChatController.sendMessage(fakeConv, 'Where is my next class?');
        Test.stopTest();

        System.assertNotEquals(null, reply);
        System.assertEquals('assistant', reply.role);
    }
}