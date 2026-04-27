import { LightningElement, track } from 'lwc';
import { chatData } from 'c/mockData';
import getHistory from '@salesforce/apex/KenChatController.getHistory';
import sendMessage from '@salesforce/apex/KenChatController.sendMessage';

/**
 * Peer-to-peer DM screen.
 *  ─ Left rail: contacts list with unread counts and online dots.
 *  ─ Right pane: WhatsApp/Slack-style bubbles, read receipts on sent msgs,
 *    composer at the bottom.
 *  Apex `getHistory` is wired but per-conversation seed data lives in the
 *  LWC (mockData.chatData.threads) so QA sees realistic conversations even
 *  before any Chat_Message__c rows exist.
 */
export default class Chat extends LightningElement {
    contacts = chatData.contacts;
    _threads = chatData.threads || {};
    @track _apexMessages;
    @track selectedContact = chatData.contacts[0];
    @track newMessage = '';
    @track _chatError;

    connectedCallback() {
        this.loadHistory();
    }

    /**
     * Try to load real Apex history for the selected contact. If the call
     * fails or returns nothing meaningful, we keep `_apexMessages` null and
     * the getter falls back to the per-contact mock thread.
     */
    loadHistory() {
        const conversationId = this.selectedContact && this.selectedContact.id;
        if (!conversationId) return;
        getHistory({ conversationId })
            .then(data => {
                // Only adopt the Apex thread if it has at least one real
                // peer message; otherwise keep the richer mock thread.
                if (data && data.length > 1) this._apexMessages = data;
                else this._apexMessages = null;
            })
            .catch(err => {
                // eslint-disable-next-line no-console
                console.warn('[chat] getHistory failed, using seed:', err);
                this._apexMessages = null;
            });
    }

    /** Source of truth for the active thread. */
    get _activeThread() {
        if (this._apexMessages && this._apexMessages.length) return this._apexMessages;
        const id = this.selectedContact && this.selectedContact.id;
        return (id && this._threads[id]) || [];
    }

    get formattedContacts() {
        return this.contacts.map(c => {
            const isSel = c.id === this.selectedContact.id;
            return {
                ...c,
                isSelected: isSel,
                contactClass: isSel ? 'contact-item selected' : 'contact-item',
                hasUnread: !isSel && c.unread > 0,
                unreadLabel: c.unread > 9 ? '9+' : String(c.unread || '')
            };
        });
    }

    /**
     * Normalise message shape from either:
     *   - Apex DTO  { id, role: 'user'|'assistant', body, createdAt }
     *   - Mock data { id, sender: 'self'|'other', text, time, status }
     * Renders bubble class + read-receipt tick state.
     */
    get formattedMessages() {
        const msgs = this._activeThread || [];
        return msgs.map((m, idx) => {
            const isSelf = (m.sender === 'self') || (m.role === 'user');
            const status = m.status || (isSelf ? 'sent' : null);
            return {
                id: m.id || ('msg-' + idx),
                text: m.text || m.body || '',
                time: m.time || m.createdAt || '',
                isSelf,
                isOther: !isSelf,
                msgClass: isSelf ? 'msg-row self' : 'msg-row other',
                bubbleClass: isSelf ? 'bubble bubble-self' : 'bubble bubble-other',
                showRead:      isSelf && status === 'read',
                showDelivered: isSelf && status === 'delivered',
                showSent:      isSelf && status === 'sent'
            };
        });
    }

    get headerStatus() {
        const c = this.selectedContact || {};
        if (c.online) return 'online';
        return c.type || 'offline';
    }
    get headerStatusClass() {
        return (this.selectedContact && this.selectedContact.online)
            ? 'chat-status online'
            : 'chat-status';
    }
    get hasChatError()       { return !!this._chatError; }
    get chatErrorMessage()   { return this._chatError; }

    handleContactSelect(event) {
        const id = event.currentTarget.dataset.id;
        const next = this.contacts.find(c => c.id === id);
        if (!next || next.id === this.selectedContact.id) return;
        // Clear unread on selection (optimistic).
        if (next.unread) next.unread = 0;
        this.selectedContact = next;
        this._apexMessages = null;
        this.loadHistory();
    }

    handleMessageChange(event) { this.newMessage = event.target.value; }

    handleKeyDown(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            this.handleSend();
        }
    }

    handleSend() {
        const body = (this.newMessage || '').trim();
        if (!body) return;
        const sentBody = body;
        this.newMessage = '';

        // Optimistic insert into the active thread.
        const tempId = 'tmp-' + Date.now();
        const nowLabel = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        const optimistic = { id: tempId, sender: 'self', text: sentBody, time: nowLabel, status: 'sent' };
        const contactId = this.selectedContact && this.selectedContact.id;

        if (this._apexMessages) {
            this._apexMessages = [...this._apexMessages, { id: tempId, role: 'user', body: sentBody, createdAt: nowLabel, status: 'sent' }];
        } else if (contactId) {
            const next = (this._threads[contactId] || []).slice();
            next.push(optimistic);
            this._threads = { ...this._threads, [contactId]: next };
        }

        sendMessage({ conversationId: contactId, body: sentBody })
            .then(() => {
                // Mark the temp message as delivered.
                this._markStatus(contactId, tempId, 'delivered');
                // After a short delay simulate the peer reading it.
                setTimeout(() => this._markStatus(contactId, tempId, 'read'), 1500);
            })
            .catch(err => {
                // Roll back on failure.
                this._removeFromThread(contactId, tempId);
                this.newMessage = sentBody;
                this._chatError = (err && err.body && err.body.message)
                    ? err.body.message
                    : 'Could not send your message.';
            });
    }

    _markStatus(contactId, id, status) {
        if (this._apexMessages) {
            this._apexMessages = this._apexMessages.map(m =>
                m.id === id ? { ...m, status } : m);
            return;
        }
        const arr = (this._threads[contactId] || []).map(m =>
            m.id === id ? { ...m, status } : m);
        this._threads = { ...this._threads, [contactId]: arr };
    }
    _removeFromThread(contactId, id) {
        if (this._apexMessages) {
            this._apexMessages = this._apexMessages.filter(m => m.id !== id);
            return;
        }
        const arr = (this._threads[contactId] || []).filter(m => m.id !== id);
        this._threads = { ...this._threads, [contactId]: arr };
    }

    handleDismissChatError() { this._chatError = null; }
}