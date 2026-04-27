import { LightningElement, wire, track } from 'lwc';
import getResearchBundle from '@salesforce/apex/KenResearchController.getResearchBundle';

export default class Research extends LightningElement {
    @track _apex;

    @wire(getResearchBundle)
    wiredResearch({ data, error }) {
        if (data) this._apex = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[research] Apex failed:', error);
        }
    }
}