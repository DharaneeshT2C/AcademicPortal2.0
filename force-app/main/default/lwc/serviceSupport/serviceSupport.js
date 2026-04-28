import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { pageNameForRoute } from 'c/navHelper';
import { refreshApex } from '@salesforce/apex';
import { serviceSupportData } from 'c/mockData';
import getTickets from '@salesforce/apex/KenServiceSupportController.getTickets';
import raiseTicket from '@salesforce/apex/KenServiceSupportController.raiseTicket';

export default class ServiceSupport extends NavigationMixin(LightningElement) {
    @track activeRequestTab = 'service';
    @track openFaqKeys = {};
    @track openQuestionKeys = {};
    @track showToast = false;
    @track toastMessage = '';
    @track toastVariant = 'success';
    @track _apexTickets;

    @track _wireResp;
    @wire(getTickets)
    wiredTickets(response) {
        this._wireResp = response;
        const { data, error } = response;
        if (data) this._apexTickets = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[serviceSupport] Apex failed, using seed:', error);
        }
    }

    get serviceTabClass() { return this.activeRequestTab === 'service' ? 'tab active' : 'tab'; }
    get ticketTabClass() { return this.activeRequestTab === 'ticket' ? 'tab active' : 'tab'; }
    get isServiceTab() { return this.activeRequestTab === 'service'; }
    get isTicketTab() { return this.activeRequestTab === 'ticket'; }

    get formattedFaqs() {
        return serviceSupportData.faqs.map(faq => {
            const isOpen = !!this.openFaqKeys[faq.category];
            const formattedQuestions = (faq.questions || []).map((q, qi) => {
                const qKey = faq.category + '::' + qi;
                const isQOpen = !!this.openQuestionKeys[qKey];
                return {
                    ...q,
                    key: qKey,
                    isQOpen: isQOpen,
                    hasAnswer: !!q.a,
                    plusMinus: isQOpen ? '\u2212' : '+',
                    questionClass: isQOpen ? 'faq-item faq-item-open' : 'faq-item'
                };
            });
            return {
                ...faq,
                isOpen: isOpen,
                expandIconName: isOpen ? 'expand_less' : 'expand_more',
                categoryClass: isOpen ? 'faq-category faq-category-open' : 'faq-category',
                formattedQuestions: formattedQuestions
            };
        });
    }

    get formattedRequests() {
        const source = (this._apexTickets && this._apexTickets.length)
            ? this._apexTickets
            : serviceSupportData.serviceRequests;
        return source.map(sr => {
            let cls = 'status-badge';
            if (sr.status === 'Closed') { cls = cls + ' closed'; }
            else if (sr.status === 'In Review') { cls = cls + ' review'; }
            else if (sr.status === 'Rejected') { cls = cls + ' rejected'; }
            return { ...sr, srStatusClass: cls, showFeedback: sr.status === 'Closed', hasAttachment: !!sr.attachment };
        });
    }

    navigateTo(route) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: pageNameForRoute(route) }
        });
    }
    handleFaqs() { this.navigateTo('faqs'); }
    handleServiceRequest() { this.navigateTo('service-request'); }
    handleHelpChat() { this.navigateTo('chat'); }

    handleRequestTab(event) { this.activeRequestTab = event.currentTarget.dataset.tab; }

    handleFaqToggle(event) {
        const key = event.currentTarget.dataset.key;
        const updated = Object.assign({}, this.openFaqKeys);
        updated[key] = !updated[key];
        this.openFaqKeys = updated;
    }

    handleQuestionToggle(event) {
        event.stopPropagation();
        const key = event.currentTarget.dataset.qkey;
        const updated = Object.assign({}, this.openQuestionKeys);
        updated[key] = !updated[key];
        this.openQuestionKeys = updated;
    }

    handleMicClick() {
        this.toastMessage = 'Voice search is not supported yet';
        this.toastVariant = 'info';
        this.showToast = true;
    }

    handleAttachmentClick(event) {
        event.stopPropagation();
        // Attachment downloads aren't wired to a real ContentVersion fetch yet — be honest with the user.
        this.toastMessage = 'Attachment download is not yet available; ask the admin team for the file.';
        this.toastVariant = 'info';
        this.showToast = true;
    }

    handleFeedback() {
        this.toastMessage = 'Feedback submitted. Thank you!';
        this.toastVariant = 'success';
        this.showToast = true;
    }

    /**
     * The "View All" button on the requests/tickets row was previously
     * (mis)wired to /faqs. The page already renders the full list inline,
     * so this is now a no-op that just confirms with a toast.
     */
    handleViewAll() {
        this.toastMessage = this.activeRequestTab === 'ticket'
            ? 'All your support tickets are shown above.'
            : 'All your service requests are shown above.';
        this.toastVariant = 'info';
        this.showToast = true;
    }

    handleRaiseTicket(event) {
        const req = (event && event.detail) || {};
        raiseTicket({ req })
            .then(caseId => {
                this.toastMessage = `Ticket raised (id ${caseId || ''})`;
                this.toastVariant = 'success';
                this.showToast = true;
                if (this._wireResp) refreshApex(this._wireResp);
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not raise ticket';
                this.toastMessage = msg;
                this.toastVariant = 'error';
                this.showToast = true;
            });
    }

    handleToastClose() { this.showToast = false; }
}