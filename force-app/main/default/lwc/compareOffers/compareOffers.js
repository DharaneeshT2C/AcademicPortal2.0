import { LightningElement, track } from 'lwc';
import { compareOffersData } from 'c/placementData';

export default class CompareOffers extends LightningElement {
    @track selectedOffer = null;
    @track showAcceptModal = false;

    data = compareOffersData;

    get offers() {
        return this.data.offers.map(o => ({
            ...o,
            logoStyle: 'background:' + o.companyColor,
            salaryFormatted: o.salary.currency + ' ' + this._fmt(o.salary.amount),
            isSelected: this.selectedOffer === o.id,
            cardClass: this.selectedOffer === o.id ? 'offer-card offer-card-selected' : 'offer-card',
            perksItems: o.perks.map(p => ({ key: p, label: p }))
        }));
    }

    get hasSelection() { return !!this.selectedOffer; }
    get noSelection() { return !this.selectedOffer; }
    get selectedOfferData() {
        const o = this.data.offers.find(off => off.id === this.selectedOffer);
        if (!o) return { company: '', companyInitial: '', logoStyle: '', role: '' };
        return { ...o, logoStyle: 'background:' + o.companyColor };
    }

    get comparisonRows() {
        const offers = this.data.offers;
        return this.data.comparisonKeys.map(key => ({
            key: key.id,
            label: key.label,
            values: offers.map(o => ({ offerId: o.id, value: o.comparison[key.id] || '—' }))
        }));
    }

    _fmt(num) {
        const s = num.toString();
        const last3 = s.slice(-3);
        const rest = s.slice(0, -3);
        if (!rest) return last3;
        const formatted = rest.replace(/\B(?=(\d{2})+(?!\d))/g, ',');
        return formatted + ',' + last3;
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'landing' } }));
    }

    handleSelectOffer(event) {
        this.selectedOffer = event.currentTarget.dataset.id;
    }

    handleAcceptOffer() {
        if (this.selectedOffer) this.showAcceptModal = true;
    }

    handleConfirmAccept() {
        this.showAcceptModal = false;
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'landing' } }));
    }

    handleCloseModal() { this.showAcceptModal = false; }
    stopProp(event) { event.stopPropagation(); }
}