import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { studentProfile } from 'c/mockData';
import getProfile             from '@salesforce/apex/KenSettingsController.getProfile';
import getNotificationPrefs   from '@salesforce/apex/KenSettingsController.getNotificationPrefs';
import updateProfile          from '@salesforce/apex/KenSettingsController.updateProfile';
import updateNotificationPref from '@salesforce/apex/KenSettingsController.updateNotificationPref';
import resetMyPassword from '@salesforce/apex/KenSettingsController.resetMyPassword';

export default class Settings extends LightningElement {
    // Fallback seed shown until the @wire calls resolve.
    student = studentProfile;
    @track _apexProfile;
    @track _apexPrefs;
    @track showToast = false;
    @track toastMessage = '';
    @track toastVariant = 'success';

    @track _wireProfileResp;
    @track _wirePrefsResp;

    @wire(getProfile)
    wiredProfile(response) {
        this._wireProfileResp = response;
        const { data } = response;
        if (data) {
            this._apexProfile = data;
            this.student = {
                ...this.student,
                FirstName: data.firstName || this.student.FirstName,
                LastName:  data.lastName  || this.student.LastName,
                Email:     data.email     || this.student.Email,
                Phone:     data.phone     || this.student.Phone
            };
        }
    }

    @wire(getNotificationPrefs)
    wiredPrefs(response) {
        this._wirePrefsResp = response;
        const { data } = response;
        if (data) this._apexPrefs = data;
    }

    get notificationPrefs() { return this._apexPrefs || []; }

    handleToastClose() { this.showToast = false; }

    handleResetPassword() {
        resetMyPassword()
            .then(email => {
                const masked = email ? email.replace(/(.).*(@.*)/, '$1***$2') : 'your registered email';
                this.toastMessage = `Password reset link sent to ${masked}`;
                this.toastVariant = 'success';
                this.showToast = true;
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not start password reset.';
                this.toastMessage = msg;
                this.toastVariant = 'error';
                this.showToast = true;
            });
    }

    handleContactAdmin() {
        // Routes to the existing service-support page; no Apex call needed,
        // and avoids the previous misleading "message sent" toast.
        this.dispatchEvent(new CustomEvent('navigate', { detail: { route: 'service-support' } }));
    }

    handleSaveProfile(event) {
        const detail = event.detail || {};
        // Light client-side validation — server-side guards remain authoritative.
        if (detail.phone && !/^\+?[0-9 \-()]{6,20}$/.test(detail.phone)) {
            this.toastMessage = 'Phone number looks invalid.'; this.toastVariant = 'error'; this.showToast = true; return;
        }
        if (detail.pincode && !/^\d{4,10}$/.test(detail.pincode)) {
            this.toastMessage = 'Pincode looks invalid.'; this.toastVariant = 'error'; this.showToast = true; return;
        }
        updateProfile({ req: detail })
            .then(() => {
                this.toastMessage = 'Profile updated';
                this.toastVariant = 'success';
                this.showToast = true;
                if (this._wireProfileResp) refreshApex(this._wireProfileResp);
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not save your changes';
                this.toastMessage = msg;
                this.toastVariant = 'error';
                this.showToast = true;
            });
    }

    handleTogglePref(event) {
        const pref = event.detail;
        updateNotificationPref({ pref })
            .then(() => {
                if (this._wirePrefsResp) refreshApex(this._wirePrefsResp);
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not save preference.';
                this.toastMessage = msg;
                this.toastVariant = 'error';
                this.showToast = true;
                // Notify the parent component so it can roll back the toggle UI state.
                this.dispatchEvent(new CustomEvent('prefrollback', { detail: pref }));
            });
    }
}