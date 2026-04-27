import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { notifications as seedNotifications } from 'c/mockData';
import getNotifications from '@salesforce/apex/KenNotificationsController.getNotifications';
import markAllRead      from '@salesforce/apex/KenNotificationsController.markAllRead';
import markRead         from '@salesforce/apex/KenNotificationsController.markRead';
import decideNotification from '@salesforce/apex/KenNotificationsController.decideNotification';

export default class NotificationsPage extends LightningElement {
    @track _apex;
    @track _wireResp;
    @track _localOverlay = {}; // map id → { read?, decision? }
    @track _toastMessage = '';
    @track _toastVariant = 'success';
    @track _toastVisible = false;

    @wire(getNotifications)
    wiredNotifications(response) {
        this._wireResp = response;
        const { data, error } = response;
        if (data) this._apex = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[notificationsPage] Apex failed, using seed:', error);
        }
    }

    get formattedNotifications() {
        const source = (this._apex && this._apex.length) ? this._apex : seedNotifications;
        return source.map(n => {
            const overlay = this._localOverlay[n.id] || {};
            const decision = overlay.decision;
            const isRead = overlay.read || n.read;
            return {
                ...n,
                hasActions: !decision && n.actions && n.actions.length > 0,
                decisionLabel: decision ? `${decision} ✓` : '',
                hasDecision: !!decision,
                formattedActions: n.actions ? n.actions.map(a => ({
                    label: a,
                    actionKey: a,
                    notifId: n.id,
                    btnClass: (a === 'Accept' || a === 'Approve') ? 'btn-action accept' : 'btn-action decline'
                })) : [],
                rowClass: isRead ? 'notif-item read' : 'notif-item'
            };
        });
    }

    get showToast() { return this._toastVisible; }
    get toastMessage() { return this._toastMessage; }
    get toastVariant() { return this._toastVariant; }

    showAToast(message, variant = 'success') {
        this._toastMessage = message;
        this._toastVariant = variant;
        this._toastVisible = true;
    }
    handleToastClose() { this._toastVisible = false; }

    handleMarkAllRead() {
        // Optimistic UI: mark every visible notification read locally first.
        const overlay = Object.assign({}, this._localOverlay);
        this.formattedNotifications.forEach(n => {
            overlay[n.id] = Object.assign({}, overlay[n.id] || {}, { read: true });
        });
        this._localOverlay = overlay;
        markAllRead()
            .then(() => {
                this.showAToast('All notifications marked as read');
                if (this._wireResp) refreshApex(this._wireResp);
            })
            .catch(err => {
                // eslint-disable-next-line no-console
                console.warn('[notificationsPage] markAllRead failed:', err);
                this.showAToast('Could not mark all as read', 'error');
            });
    }

    handleMarkOne(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        const overlay = Object.assign({}, this._localOverlay);
        overlay[id] = Object.assign({}, overlay[id] || {}, { read: true });
        this._localOverlay = overlay;
        markRead({ notificationIds: [id] }).catch(err => {
            // Roll back the optimistic read flag and tell the user.
            const rb = Object.assign({}, this._localOverlay);
            if (rb[id]) { delete rb[id].read; }
            this._localOverlay = rb;
            const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not mark as read.';
            this.showAToast(msg, 'error');
        });
    }

    handleAction(event) {
        const id = event.currentTarget.dataset.id;
        const action = event.currentTarget.dataset.action;
        if (!id || !action) return;
        const overlay = Object.assign({}, this._localOverlay);
        overlay[id] = Object.assign({}, overlay[id] || {}, { read: true, decision: action });
        this._localOverlay = overlay;
        decideNotification({ notificationId: id, decision: action })
            .then(() => {
                this.showAToast(`${action} recorded`);
                if (this._wireResp) refreshApex(this._wireResp);
            })
            .catch(err => {
                // eslint-disable-next-line no-console
                console.warn('[notificationsPage] decideNotification failed:', err);
                // Roll back local state on failure
                const rollback = Object.assign({}, this._localOverlay);
                if (rollback[id]) { delete rollback[id].decision; }
                this._localOverlay = rollback;
                this.showAToast('Could not record action', 'error');
            });
    }
}