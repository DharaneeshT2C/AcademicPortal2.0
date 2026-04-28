import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { pageNameForRoute } from 'c/navHelper';
import { messMenuData } from 'c/mockData';
import getWeeklyMenu from '@salesforce/apex/KenMessMenuController.getWeeklyMenu';
import submitMessFeedback from '@salesforce/apex/KenMessMenuController.submitMessFeedback';

export default class MessMenu extends NavigationMixin(LightningElement) {
    @track _apex;
    @track _viewMode = 'day';
    @track _showAllBreakfast = false;
    @track _feedbackMeal;
    @track _feedbackRating = 5;
    @track _feedbackComments = '';
    @track _toastVisible = false;
    @track _toastMessage = '';
    @track _toastVariant = 'success';
    _seed = messMenuData;

    showAToast(msg, v = 'success') { this._toastMessage = msg; this._toastVariant = v; this._toastVisible = true; }
    handleToastClose() { this._toastVisible = false; }
    get showToast() { return this._toastVisible; }
    get toastMessage() { return this._toastMessage; }
    get toastVariant() { return this._toastVariant; }
    get dayBtnClass() { return this._viewMode === 'day' ? 'toggle-btn active' : 'toggle-btn'; }
    get weekBtnClass() { return this._viewMode === 'week' ? 'toggle-btn active' : 'toggle-btn'; }
    get isWeekMode() { return this._viewMode === 'week'; }
    get viewMoreLabel() { return this._showAllBreakfast ? 'Show Less' : 'View More'; }
    get showFeedbackModal() { return !!this._feedbackMeal; }
    get feedbackMeal() { return this._feedbackMeal; }
    get feedbackRating() { return this._feedbackRating; }
    get feedbackComments() { return this._feedbackComments; }
    get feedbackTitle() { return `Feedback for ${this._feedbackMeal || ''}`; }
    get ratingOptions() {
        return [1,2,3,4,5].map(n => ({
            value: String(n),
            label: '★'.repeat(n) + '☆'.repeat(5 - n),
            cls: n === this._feedbackRating ? 'rating-pill active' : 'rating-pill'
        }));
    }
    get weekDays() {
        const week = (this._seed && this._seed.week) || [];
        if (week.length) return week;
        // Fallback: synthesize a week shape from current day data
        return ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].map((d, i) => ({
            day: d,
            breakfast: this.breakfastItems.slice(0, 3).map(x => x.name).join(', '),
            lunch: this.lunchItems.slice(0, 3).map(x => x.name).join(', '),
            dinner: this.dinnerItems.slice(0, 3).map(x => x.name).join(', '),
            key: 'wk-' + i
        }));
    }

    stopProp(e) { e.stopPropagation(); }
    handleViewDay() { this._viewMode = 'day'; }
    handleViewWeek() { this._viewMode = 'week'; }
    handleToggleViewMore() { this._showAllBreakfast = !this._showAllBreakfast; }
    handleGetHelp() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: pageNameForRoute('service-support') }
        });
    }
    handleOpenFeedback(event) {
        this._feedbackMeal = event.currentTarget.dataset.meal || '';
        this._feedbackRating = 5;
        this._feedbackComments = '';
    }
    handleCloseFeedback() { this._feedbackMeal = null; }
    handlePickRating(event) {
        this._feedbackRating = Number(event.currentTarget.dataset.value) || 5;
    }
    handleFeedbackComments(event) { this._feedbackComments = event.target.value || ''; }
    handleSubmitFeedbackModal() {
        const meal = this._feedbackMeal;
        const rating = this._feedbackRating;
        const comments = this._feedbackComments;
        submitMessFeedback({ meal, rating, comments })
            .then(() => { this.showAToast(`Thanks for your ${meal.toLowerCase()} feedback`); this._feedbackMeal = null; })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not submit feedback.';
                this.showAToast(msg, 'error');
            });
    }

    @wire(getWeeklyMenu)
    wiredMenu({ data, error }) {
        if (data) {
            // The Apex method returns a List<DayMenuDTO>; adapt to today's DayMenu shape
            // expected by the seed template. If the list has entries, use first day; fall
            // back to seed if the adapter cannot produce the legacy shape.
            if (Array.isArray(data) && data.length && data[0] && data[0].meals) {
                this._apex = data[0];
            } else if (!Array.isArray(data)) {
                this._apex = data;
            }
        } else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[messMenu] Apex failed, using seed:', error);
        }
    }

    get data() {
        if (this._apex) return Object.assign({}, this._seed, this._apex);
        return this._seed;
    }

    _toItems(arr) {
        return (arr || []).map((name, i) => ({
            name,
            key: 'item-' + i,
            isJain: name === 'Bread Toast'
        }));
    }
    get breakfastItems() {
        const items = (this.data.meals && this.data.meals.breakfast && this.data.meals.breakfast.items) || [];
        return this._toItems(this._showAllBreakfast ? items : items.slice(0, 6));
    }
    get hasMoreBreakfast() {
        const items = (this.data.meals && this.data.meals.breakfast && this.data.meals.breakfast.items) || [];
        return items.length > 6;
    }
    get lunchItems() {
        return this._toItems(this.data.meals && this.data.meals.lunch && this.data.meals.lunch.items);
    }
    get highTeaItems() {
        return this._toItems(this.data.meals && this.data.meals.highTea && this.data.meals.highTea.items);
    }
    get dinnerItems() {
        return this._toItems(this.data.meals && this.data.meals.dinner && this.data.meals.dinner.items);
    }

    handleSubmitFeedback(event) {
        const detail = (event && event.detail) || {};
        const meal = detail.meal || '';
        const rating = typeof detail.rating === 'number' ? detail.rating : 0;
        const comments = detail.comments || '';
        submitMessFeedback({ meal, rating, comments })
            .catch(err => {
                // eslint-disable-next-line no-console
                console.warn('[messMenu] submitMessFeedback failed:', err);
            });
    }

    navigateTo(route) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: pageNameForRoute(route) }
        });
    }
    handleBack() { this.navigateTo('campus-life'); }
}