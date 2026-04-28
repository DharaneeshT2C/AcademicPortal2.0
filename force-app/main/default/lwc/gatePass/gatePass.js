import { LightningElement, wire, track } from 'lwc';
import getGatePasses from '@salesforce/apex/KenGatePassController.getGatePasses';

export default class GatePass extends LightningElement {
    @track _apex;

    @wire(getGatePasses)
    wiredPasses({ data, error }) {
        if (data) this._apex = data;
        else if (error) {
            const _msg = (error && error.body && error.body.message) || '';
            if (_msg && !_msg.includes('not have access') && !_msg.includes('No rows')) {
                // eslint-disable-next-line no-console
                console.warn('[gatePass] Apex failed, using seed:', error);
            }
        }
    }

    get effectivePasses() {
        return (this._apex && this._apex.length) ? this._apex : [];
    }

    get formattedPasses() {
        return this.effectivePasses.map(p => ({
            ...p,
            statusClass: `status-badge ${(p.status || '').toLowerCase().replace(' ', '-')}`
        }));
    }

    navigateTo(route) { this.dispatchEvent(new CustomEvent('navigate', { detail: { route } })); }
    handleCreate() { this.navigateTo('create-gate-pass'); }
    handleBack() { this.navigateTo('campus-life'); }
}