/**
 * ************************************************************************************************
 * @className  KenChatController
 *
 * @description
 *  Backs the `my/chat` LWC — conversation with the KAI (AI) assistant.
 *
 *  The reply generator is a stub. Production deployment should integrate with
 *  Einstein GPT (`ConnectApi.EinsteinGPT`) or an external LLM via Named
 *  Credential + `HttpCallout` in a separate service class.
 *
 *  TODO[SOBJECT]:  `Chat_Message__c` with Conversation__c, Role__c (user|assistant),
 *                  Body__c, Created_At__c.
 *  TODO[LLM]:      Named Credential `Callout:KAI_LLM` + service wrapper.
 * ************************************************************************************************
 */
public with sharing class KenChatController {

    public class ChatMessageDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String role;      // 'user' | 'assistant'
        @AuraEnabled public String body;
        @AuraEnabled public String createdAt;
    }

    /**
     * Coerces a String into a Salesforce Id, returning null for any non-Id
     * (seed strings like 'CT001', empty values). Lets us accept loose inputs
     * from LWCs that pass mock conversation ids during onboarding.
     */
    private static Id toId(String value) {
        if (String.isBlank(value)) return null;
        if (value.length() != 15 && value.length() != 18) return null;
        try { return (Id) value; } catch (Exception e) { return null; }
    }

    @AuraEnabled(cacheable=true)
    public static List<ChatMessageDTO> getHistory(String conversationId) {
        try {
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId == null) {
                return new List<ChatMessageDTO>{
                    msg('CM001', 'assistant', 'Hi! I\'m KAI. Ask me anything about your classes, campus, or fees.', '10:00 AM')
                };
            }
            // Find or hint a conversation; if none, fall back to greeting
            Id convId = toId(conversationId);
            if (convId == null) {
                List<Chat_Conversation__c> existing = [
                    SELECT Id FROM Chat_Conversation__c
                    WHERE Student__c = :contactId
                    ORDER BY Last_Message_At__c DESC LIMIT 1
                ];
                if (!existing.isEmpty()) convId = existing[0].Id;
            }
            if (convId == null) {
                return new List<ChatMessageDTO>{
                    msg('CM001', 'assistant', 'Hi! I\'m KAI. Ask me anything about your classes, campus, or fees.', '')
                };
            }
            List<ChatMessageDTO> out = new List<ChatMessageDTO>();
            for (Chat_Message__c m : [
                SELECT Id, Role__c, Body__c, Created_At__c
                FROM Chat_Message__c
                WHERE Conversation__c = :convId
                WITH USER_MODE
                ORDER BY Created_At__c
                LIMIT 100
            ]) {
                ChatMessageDTO d = new ChatMessageDTO();
                d.id        = m.Id;
                d.role      = m.Role__c;
                d.body      = m.Body__c;
                d.createdAt = m.Created_At__c == null ? '' : m.Created_At__c.format('h:mm a');
                out.add(d);
            }
            if (out.isEmpty()) {
                out.add(msg('CM001', 'assistant', 'Hi! I\'m KAI. Ask me anything about your classes, campus, or fees.', ''));
            }
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenChatController.getHistory',
                'Unable to load chat history.', e);
            return null;
        }
    }

    @AuraEnabled
    public static ChatMessageDTO sendMessage(String conversationId, String body) {
        try {
            KenAuraExceptionHelper.rejectIf(String.isBlank(body), 'Message cannot be empty.');
            Id contactId = KenRunningStudentHelper.optionalContactId();
            // Get-or-create conversation. Lazy-create with race-safe retry.
            Id convId = toId(conversationId);
            if (convId == null && contactId != null) {
                List<Chat_Conversation__c> existing = [
                    SELECT Id FROM Chat_Conversation__c
                    WHERE Student__c = :contactId
                    ORDER BY Last_Message_At__c DESC LIMIT 1
                ];
                if (!existing.isEmpty()) {
                    convId = existing[0].Id;
                } else {
                    try {
                        Chat_Conversation__c c = new Chat_Conversation__c(
                            Student__c = contactId, Last_Message_At__c = Datetime.now()
                        );
                        insert c;
                        convId = c.Id;
                    } catch (DmlException dml) {
                        // Concurrent insert race — re-read.
                        List<Chat_Conversation__c> retry = [
                            SELECT Id FROM Chat_Conversation__c
                            WHERE Student__c = :contactId
                            ORDER BY Last_Message_At__c DESC LIMIT 1
                        ];
                        if (!retry.isEmpty()) convId = retry[0].Id;
                        else throw dml;
                    }
                }
            }
            // Insert user message
            if (convId != null) {
                insert new Chat_Message__c(
                    Conversation__c = convId,
                    Role__c         = 'user',
                    Body__c         = body,
                    Created_At__c   = Datetime.now()
                );
            }
            // Generate assistant reply via LLM (stub: rule-based response;
            // production should call out to the LLM via Named Credential).
            String replyText = generateReply(body);
            ChatMessageDTO replyDto;
            if (convId != null) {
                Chat_Message__c reply = new Chat_Message__c(
                    Conversation__c = convId,
                    Role__c         = 'assistant',
                    Body__c         = replyText,
                    Created_At__c   = Datetime.now()
                );
                insert reply;
                update new Chat_Conversation__c(Id = convId, Last_Message_At__c = Datetime.now());
                replyDto = msg(reply.Id, 'assistant', replyText, reply.Created_At__c.format('h:mm a'));
            } else {
                replyDto = msg('CM-reply', 'assistant', replyText, Datetime.now().format('h:mm a'));
            }
            return replyDto;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenChatController.sendMessage',
                'Could not send your message.', e);
            return null;
        }
    }

    // Delegates to KaiLlmService which calls Anthropic Claude when the
    // Anthropic_LLM Named Credential is configured, else returns a rule-based reply.
    private static String generateReply(String userMessage) {
        String studentCtx = '';
        try {
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId != null) {
                List<Contact> cs = [SELECT FirstName FROM Contact WHERE Id = :contactId LIMIT 1];
                if (!cs.isEmpty()) studentCtx = 'Student name: ' + cs[0].FirstName;
            }
        } catch (Exception ignore) {}
        return KaiLlmService.generateReply(userMessage, studentCtx);
    }

    private static ChatMessageDTO msg(String id, String role, String body, String created) {
        ChatMessageDTO m = new ChatMessageDTO();
        m.id = id; m.role = role; m.body = body; m.createdAt = created;
        return m;
    }
}