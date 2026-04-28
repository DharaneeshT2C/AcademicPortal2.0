/**
 * ************************************************************************************************
 * @className  KenChatController
 *
 * @description
 *  Backs `my/chat` — peer-to-peer DMs between the running student and their
 *  classmates / mentors / faculty. Each Chat_Conversation__c stores the peer's
 *  display info (name, type, avatar) and links via Student__c to the running
 *  Contact. Chat_Message__c rows hold the actual messages — Role__c='user' for
 *  the student's own sends, Role__c='assistant' for the peer's incoming messages.
 *  (We reuse the existing restricted picklist values to avoid a metadata change.)
 * ************************************************************************************************
 */
public without sharing class KenChatController {

    public class ChatMessageDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String role;      // 'user' (self) | 'assistant' (peer)
        @AuraEnabled public String body;
        @AuraEnabled public String createdAt;
    }

    public class ConversationDTO {
        @AuraEnabled public Id     id;             // Chat_Conversation__c.Id
        @AuraEnabled public String externalId;     // stable handle (e.g. 'CT001')
        @AuraEnabled public String name;           // peer display name
        @AuraEnabled public String type;           // 'Classmate · CSE-6', 'Mentor · Alumni', etc.
        @AuraEnabled public String avatar;         // peer avatar url
        @AuraEnabled public String lastMessage;    // preview text
        @AuraEnabled public String timeAgo;        // relative time of last msg
        @AuraEnabled public Integer unread;        // count of peer-sent unread (currently always 0)
    }

    /**
     * Coerces a String into a Salesforce Id, returning null for any non-Id
     * (mock strings, empty values).
     */
    private static Id toId(String value) {
        if (String.isBlank(value)) return null;
        if (value.length() != 15 && value.length() != 18) return null;
        try { return (Id) value; } catch (Exception e) { return null; }
    }

    /**
     * Returns every conversation the running student has, ordered by most
     * recent activity. Used by the chat LWC to populate the contact rail.
     */
    @AuraEnabled(cacheable=true)
    public static List<ConversationDTO> getConversations() {
        List<ConversationDTO> out = new List<ConversationDTO>();
        try {
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId == null) return out;

            // Pull conversations + their latest message in one round trip.
            List<Chat_Conversation__c> convs = [
                SELECT Id, External_Id__c, Peer_Name__c, Peer_Type__c, Peer_Avatar_Url__c, Last_Message_At__c,
                    (SELECT Id, Role__c, Body__c, Created_At__c
                     FROM Chat_Messages__r
                     ORDER BY Created_At__c DESC
                     LIMIT 1)
                FROM Chat_Conversation__c
                WHERE Student__c = :contactId
                WITH SECURITY_ENFORCED
                ORDER BY Last_Message_At__c DESC NULLS LAST
                LIMIT 50
            ];

            for (Chat_Conversation__c c : convs) {
                ConversationDTO d = new ConversationDTO();
                d.id          = c.Id;
                d.externalId  = c.External_Id__c;
                d.name        = c.Peer_Name__c;
                d.type        = c.Peer_Type__c;
                d.avatar      = c.Peer_Avatar_Url__c;
                d.unread      = 0;
                if (!c.Chat_Messages__r.isEmpty()) {
                    Chat_Message__c last = c.Chat_Messages__r[0];
                    d.lastMessage = last.Body__c;
                    d.timeAgo = relativeTime(last.Created_At__c);
                } else {
                    d.lastMessage = '';
                    d.timeAgo = c.Last_Message_At__c == null ? '' : relativeTime(c.Last_Message_At__c);
                }
                out.add(d);
            }
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenChatController.getConversations',
                'Unable to load conversations.', e);
            return out;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ChatMessageDTO> getHistory(String conversationId) {
        try {
            Id contactId = KenRunningStudentHelper.optionalContactId();
            Id convId = toId(conversationId);

            // No real id passed — return the running student's most recent
            // conversation as a friendly default.
            if (convId == null && contactId != null) {
                List<Chat_Conversation__c> existing = [
                    SELECT Id FROM Chat_Conversation__c
                    WHERE Student__c = :contactId
                    ORDER BY Last_Message_At__c DESC LIMIT 1
                ];
                if (!existing.isEmpty()) convId = existing[0].Id;
            }
            if (convId == null) {
                return new List<ChatMessageDTO>();
            }

            List<ChatMessageDTO> out = new List<ChatMessageDTO>();
            for (Chat_Message__c m : [
                SELECT Id, Role__c, Body__c, Created_At__c
                FROM Chat_Message__c
                WHERE Conversation__c = :convId
                WITH SECURITY_ENFORCED
                ORDER BY Created_At__c
                LIMIT 200
            ]) {
                ChatMessageDTO d = new ChatMessageDTO();
                d.id        = m.Id;
                d.role      = m.Role__c;
                d.body      = m.Body__c;
                d.createdAt = m.Created_At__c == null ? '' : m.Created_At__c.format('h:mm a');
                out.add(d);
            }
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenChatController.getHistory',
                'Unable to load chat history.', e);
            return null;
        }
    }

    /**
     * Saves the student's outgoing message. Peer-to-peer — no auto-generated
     * reply (that's the receiving peer's job). Returns the saved message DTO
     * so the LWC can replace its optimistic temp row with the real id.
     */
    @AuraEnabled
    public static ChatMessageDTO sendMessage(String conversationId, String body) {
        try {
            KenAuraExceptionHelper.rejectIf(String.isBlank(body), 'Message cannot be empty.');
            Id contactId = KenRunningStudentHelper.optionalContactId();
            Id convId = toId(conversationId);

            // If no convId, fall back to the latest conversation for the student.
            if (convId == null && contactId != null) {
                List<Chat_Conversation__c> existing = [
                    SELECT Id FROM Chat_Conversation__c
                    WHERE Student__c = :contactId
                    ORDER BY Last_Message_At__c DESC LIMIT 1
                ];
                if (!existing.isEmpty()) convId = existing[0].Id;
            }

            // No conversation context — return an in-memory echo so the UI
            // doesn't break in unauthenticated previews.
            if (convId == null) {
                return msg('CM-echo', 'user', body, Datetime.now().format('h:mm a'));
            }

            Chat_Message__c saved = new Chat_Message__c(
                Conversation__c = convId,
                Role__c         = 'user',
                Body__c         = body,
                Created_At__c   = Datetime.now()
            );
            insert saved;
            update new Chat_Conversation__c(Id = convId, Last_Message_At__c = Datetime.now());

            return msg(saved.Id, 'user', body, saved.Created_At__c.format('h:mm a'));
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenChatController.sendMessage',
                'Could not send your message.', e);
            return null;
        }
    }

    private static ChatMessageDTO msg(String id, String role, String body, String created) {
        ChatMessageDTO m = new ChatMessageDTO();
        m.id = id; m.role = role; m.body = body; m.createdAt = created;
        return m;
    }

    /** Relative time helper — "Just now", "8m", "1h", "Yesterday", "Mon", or date. */
    private static String relativeTime(Datetime dt) {
        if (dt == null) return '';
        Long diffMs = Datetime.now().getTime() - dt.getTime();
        Long mins = diffMs / 60000L;
        if (mins < 1)  return 'Just now';
        if (mins < 60) return mins + 'm';
        Long hours = mins / 60L;
        if (hours < 24) return hours + 'h';
        Long days = hours / 24L;
        if (days == 1) return 'Yesterday';
        if (days < 7)  return dt.format('EEE');
        return dt.format('d MMM');
    }
}