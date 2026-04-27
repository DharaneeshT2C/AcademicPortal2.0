import { LightningElement, wire, track } from 'lwc';
import { serviceSupportData } from 'c/mockData';
import getFaqs from '@salesforce/apex/KenFaqsController.getFaqs';

export default class Faqs extends LightningElement {
    @track _apex;

    @wire(getFaqs)
    wiredFaqs({ data, error }) {
        if (data) this._apex = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[faqs] Apex failed, using seed:', error);
        }
    }

    get effectiveFaqs() {
        if (this._apex && this._apex.length) return this._apex;
        return serviceSupportData.faqs;
    }

    get faqs() {
        return this.effectiveFaqs.map(faq => ({
            ...faq,
            hasQuestions: faq.questions && faq.questions.length > 0
        }));
    }

    navigateTo(route) { this.dispatchEvent(new CustomEvent('navigate', { detail: { route } })); }
    handleBack() { this.navigateTo('service-support'); }
}