import { LightningElement, wire, track } from 'lwc';
import { gatePassList } from 'c/mockData';
import getGatePasses from '@salesforce/apex/KenGatePassController.getGatePasses';

export default class GatePass extends LightningElement {
    @track _apex;
    // Seed fallback.
    passes = gatePassList;

    @wire(getGatePasses)
    wiredPasses({ data, error }) {
        if (data) this._apex = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[gatePass] Apex failed, using seed:', error);
        }
    }

    get effectivePasses() {
        if (this._apex && this._apex.length) return this._apex;
        return this.passes;
    }

    get formattedPasses() {
        return this.effectivePasses.map(p => ({
            ...p,
            statusClass: `status-badge ${p.status.toLowerCase().replace(' ', '-')}`
        }));
    }

    navigateTo(route) { this.dispatchEvent(new CustomEvent('navigate', { detail: { route } })); }
    handleCreate() { this.navigateTo('create-gate-pass'); }
    handleBack() { this.navigateTo('campus-life'); }
}