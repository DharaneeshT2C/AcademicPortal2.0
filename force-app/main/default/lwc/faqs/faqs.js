import { LightningElement, wire, track } from 'lwc';
import { serviceSupportData } from 'c/mockData';
import getFaqs from '@salesforce/apex/KenFaqsController.getFaqs';

export default class Faqs extends LightningElement {
    @track _apex;
    @track _openCats = {}; // category name → bool
    @track _openQs = {};   // question key → bool
    @track _searchTerm = '';

    @wire(getFaqs)
    wiredFaqs({ data, error }) {
        if (data) {
            this._apex = data;
            // Auto-open first category for QA visibility
            if (data.length > 0) {
                const firstName = data[0].categoryName || data[0].category;
                if (firstName) this._openCats = { [firstName]: true };
            }
        } else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[faqs] Apex failed, using seed:', error);
        }
    }

    /**
     * Normalise both shapes (Apex DTO uses categoryName/entries/question/answer,
     * legacy mockData uses category/questions/q/a) into a single canonical shape.
     */
    get _normalised() {
        const src = (this._apex && this._apex.length) ? this._apex : serviceSupportData.faqs;
        return (src || []).map(faq => {
            const category = faq.categoryName || faq.category || '';
            const rawQs = faq.entries || faq.questions || [];
            const questions = rawQs.map((q, idx) => ({
                key: (q.id || category + '-' + idx),
                q: q.question || q.q || '',
                a: q.answer || q.a || ''
            }));
            return { category, questions };
        });
    }

    get faqs() {
        const term = (this._searchTerm || '').trim().toLowerCase();
        return this._normalised
            .map(faq => {
                const filtered = term
                    ? faq.questions.filter(q =>
                        (q.q || '').toLowerCase().includes(term) ||
                        (q.a || '').toLowerCase().includes(term))
                    : faq.questions;
                const isOpen = !!this._openCats[faq.category] || !!term;
                const formattedQuestions = filtered.map(q => {
                    const isQOpen = !!this._openQs[q.key];
                    return {
                        ...q,
                        isQOpen,
                        plusMinus: isQOpen ? '−' : '+',
                        hasAnswer: !!q.a,
                        questionClass: 'faq-item' + (isQOpen ? ' open' : '')
                    };
                });
                return {
                    ...faq,
                    hasQuestions: formattedQuestions.length > 0,
                    isOpen,
                    formattedQuestions,
                    expandIconName: isOpen ? 'expand_less' : 'expand_more',
                    categoryClass: 'faq-category' + (isOpen ? ' open' : '')
                };
            })
            .filter(faq => faq.hasQuestions);
    }

    handleCategoryToggle(event) {
        const key = event.currentTarget.dataset.key;
        if (!key) return;
        this._openCats = { ...this._openCats, [key]: !this._openCats[key] };
    }

    handleQuestionToggle(event) {
        const key = event.currentTarget.dataset.qkey;
        if (!key) return;
        this._openQs = { ...this._openQs, [key]: !this._openQs[key] };
    }

    handleSearchChange(event) { this._searchTerm = event.target.value || ''; }

    navigateTo(route) { this.dispatchEvent(new CustomEvent('navigate', { detail: { route } })); }
    handleBack() { this.navigateTo('service-support'); }
}