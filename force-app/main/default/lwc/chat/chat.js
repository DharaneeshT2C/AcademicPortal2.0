import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { chatData } from 'c/mockData';
import getConversations from '@salesforce/apex/KenChatController.getConversations';
import getHistory       from '@salesforce/apex/KenChatController.getHistory';
import sendMessage      from '@salesforce/apex/KenChatController.sendMessage';

/**
 * Peer-to-peer DM screen.
 *  ─ Conversations come from real Chat_Conversation__c records (peer name,
 *    type, avatar live on the conversation row itself).
 *  ─ Messages come from Chat_Message__c rows (Role__c='user' = self,
 *    Role__c='assistant' = peer).
 *  ─ When Apex returns nothing (preview / unauth / fresh org), we fall back
 *    to the rich mock threads in c/mockData so the page is never blank.
 */
export default class Chat extends LightningElement {
    @track _convs = null;             // Apex conversations
    @track _wireConvs;                // wire response, for refreshApex
    @track _apexMessages = null;      // current thread (Apex)
    @track _selectedId = null;        // active conversation id (real or 'CT00x' fallback)
    @track newMessage = '';
    @track _chatError;

    /* Mock contact list kept as a UI config helper so the page is never
       blank in preview/unauth mode. Real message threads come from Apex only. */
    _mockContacts = chatData.contacts;
    _mockThreads  = {};
    @track _mockThreadOverlay = {};   // optimistic sends while in mock mode

    @wire(getConversations)
    wiredConversations(response) {
        this._wireConvs = response;
        const { data, error } = response;
        if (data && data.length) {
            this._convs = data;
            // Auto-select first conversation if none yet
            if (!this._selectedId) {
                this._selectedId = data[0].id;
                this.loadHistory();
            }
        } else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[chat] getConversations failed, using mock contacts:', error);
            this._convs = null;
            if (!this._selectedId && this._mockContacts.length) {
                this._selectedId = this._mockContacts[0].id;
            }
        } else {
            // No real conversations — use mock contacts.
            this._convs = null;
            if (!this._selectedId && this._mockContacts.length) {
                this._selectedId = this._mockContacts[0].id;
            }
        }
    }

    /** True when we have real Apex conversations to render. */
    get _isLive() { return !!(this._convs && this._convs.length); }

    /** Selected contact (either a real conversation row or a mock contact). */
    get selectedContact() {
        if (this._isLive) {
            const c = this._convs.find(x => x.id === this._selectedId) || this._convs[0];
            return {
                id: c.id,
                name: c.name,
                type: c.type,
                avatar: c.avatar,
                online: false
            };
        }
        return this._mockContacts.find(c => c.id === this._selectedId) || this._mockContacts[0];
    }

    get formattedContacts() {
        const list = this._isLive
            ? this._convs.map(c => ({
                id: c.id,
                name: c.name,
                type: c.type,
                avatar: c.avatar,
                lastMessage: c.lastMessage,
                time: c.timeAgo,
                unread: c.unread || 0,
                online: false
              }))
            : this._mockContacts;

        return list.map(c => {
            const isSel = c.id === this._selectedId;
            return {
                ...c,
                isSelected: isSel,
                contactClass: isSel ? 'contact-item selected' : 'contact-item',
                hasUnread: !isSel && (c.unread || 0) > 0,
                unreadLabel: (c.unread || 0) > 9 ? '9+' : String(c.unread || '')
            };
        });
    }

    /** Active thread. Apex when live, mock otherwise. */
    get _activeThread() {
        if (this._isLive) return this._apexMessages || [];
        const overlay = this._mockThreadOverlay[this._selectedId];
        if (overlay) return overlay;
        return this._mockThreads[this._selectedId] || [];
    }

    /**
     * Normalise message shape from either:
     *   - Apex DTO  { id, role: 'user'|'assistant', body, createdAt }
     *   - Mock data { id, sender: 'self'|'other', text, time, status }
     */
    get formattedMessages() {
        const msgs = this._activeThread || [];
        return msgs.map((m, idx) => {
            const isSelf = (m.sender === 'self') || (m.role === 'user');
            const status = m.status || (isSelf ? 'read' : null);
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
        return c.type || '';
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
        if (!id || id === this._selectedId) return;
        this._selectedId = id;
        this._apexMessages = null;
        if (this._isLive) this.loadHistory();
    }

    /** Fetch messages for the active conversation from Apex. */
    loadHistory() {
        if (!this._isLive) return;
        const conversationId = this._selectedId;
        if (!conversationId) return;
        getHistory({ conversationId })
            .then(data => {
                this._apexMessages = data || [];
            })
            .catch(err => {
                // eslint-disable-next-line no-console
                console.warn('[chat] getHistory failed:', err);
                this._apexMessages = [];
            });
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
        const tempId = 'tmp-' + Date.now();
        const nowLabel = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

        if (this._isLive) {
            // Optimistic insert into the apex thread.
            const optimistic = { id: tempId, role: 'user', body: sentBody, createdAt: nowLabel, status: 'sent' };
            this._apexMessages = [...(this._apexMessages || []), optimistic];

            sendMessage({ conversationId: this._selectedId, body: sentBody })
                .then(saved => {
                    // Replace temp with real saved record.
                    this._apexMessages = (this._apexMessages || []).map(m =>
                        m.id === tempId ? { ...saved, status: 'delivered' } : m
                    );
                    setTimeout(() => this._markStatus(saved.id, 'read'), 1500);
                    if (this._wireConvs) refreshApex(this._wireConvs);
                })
                .catch(err => {
                    this._apexMessages = (this._apexMessages || []).filter(m => m.id !== tempId);
                    this.newMessage = sentBody;
                    this._chatError = (err && err.body && err.body.message)
                        ? err.body.message
                        : 'Could not send your message.';
                });
            return;
        }

        // ── Mock-mode path: optimistic local-only echo. ──────────────────
        const optimistic = { id: tempId, sender: 'self', text: sentBody, time: nowLabel, status: 'sent' };
        const base = (this._mockThreadOverlay[this._selectedId] || this._mockThreads[this._selectedId] || []).slice();
        base.push(optimistic);
        this._mockThreadOverlay = { ...this._mockThreadOverlay, [this._selectedId]: base };
        // Simulate progression for visual realism.
        setTimeout(() => this._mockMarkStatus(this._selectedId, tempId, 'delivered'), 400);
        setTimeout(() => this._mockMarkStatus(this._selectedId, tempId, 'read'),      1800);
    }

    _markStatus(id, status) {
        if (!this._isLive) return;
        this._apexMessages = (this._apexMessages || []).map(m =>
            m.id === id ? { ...m, status } : m);
    }
    _mockMarkStatus(contactId, id, status) {
        const arr = (this._mockThreadOverlay[contactId] || []).map(m =>
            m.id === id ? { ...m, status } : m);
        this._mockThreadOverlay = { ...this._mockThreadOverlay, [contactId]: arr };
    }

    handleDismissChatError() { this._chatError = null; }
}