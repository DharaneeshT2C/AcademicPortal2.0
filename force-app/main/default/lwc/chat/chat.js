import { LightningElement, track } from 'lwc';
import { chatData } from 'c/mockData';
import getHistory from '@salesforce/apex/KenChatController.getHistory';
import sendMessage from '@salesforce/apex/KenChatController.sendMessage';

export default class Chat extends LightningElement {
    contacts = chatData.contacts;
    @track _apexMessages;
    // Seed fallback.
    _seedMessages = chatData.messages;
    @track selectedContact = chatData.contacts[0];
    @track newMessage = '';

    connectedCallback() {
        this.loadHistory();
    }

    loadHistory() {
        const conversationId = this.selectedContact && this.selectedContact.id;
        if (!conversationId) return;
        getHistory({ conversationId })
            .then(data => {
                if (data) this._apexMessages = data;
            })
            .catch(err => {
                // eslint-disable-next-line no-console
                console.warn('[chat] getHistory failed, using seed:', err);
            });
    }

    get messages() {
        if (this._apexMessages && this._apexMessages.length) return this._apexMessages;
        return this._seedMessages;
    }

    get formattedContacts() {
        return this.contacts.map(c => ({
            ...c,
            isSelected: c.id === this.selectedContact.id,
            contactClass: c.id === this.selectedContact.id ? 'contact-item selected' : 'contact-item'
        }));
    }
    get formattedMessages() {
        return this.messages.map(m => ({
            ...m,
            msgClass: m.sender === 'self' ? 'message self' : 'message other'
        }));
    }

    handleContactSelect(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedContact = this.contacts.find(c => c.id === id) || this.contacts[0];
        this._apexMessages = null;
        this.loadHistory();
    }

    handleMessageChange(event) { this.newMessage = event.target.value; }
    handleSend() {
        const body = (this.newMessage || '').trim();
        if (!body) return;
        // Save the body so we can restore the input if send fails.
        const sentBody = body;
        this.newMessage = '';
        // Show user's message immediately for responsive feel.
        const tempUserMsg = { id: 'tmp-' + Date.now(), role: 'user', body: sentBody, createdAt: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) };
        this._apexMessages = [...(this._apexMessages || []), tempUserMsg];
        const conversationId = this.selectedContact && this.selectedContact.id;
        sendMessage({ conversationId, body: sentBody })
            .then(msg => {
                if (msg) {
                    const current = this._apexMessages || [];
                    this._apexMessages = [...current, msg];
                }
            })
            .catch(err => {
                // Roll back the optimistic user message and restore the input.
                this._apexMessages = (this._apexMessages || []).filter(m => m.id !== tempUserMsg.id);
                this.newMessage = sentBody;
                this._chatError = (err && err.body && err.body.message) ? err.body.message : 'Could not send your message.';
            });
    }

    @track _chatError;
    get hasChatError() { return !!this._chatError; }
    get chatErrorMessage() { return this._chatError; }
    handleDismissChatError() { this._chatError = null; }
}