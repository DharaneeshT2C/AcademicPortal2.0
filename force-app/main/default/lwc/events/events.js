import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import SP_IMAGES from '@salesforce/resourceUrl/StudentPortalImages';
import { eventsData } from 'c/mockData';
import getEventsBundle from '@salesforce/apex/KenEventsController.getEventsBundle';
import registerForEvent from '@salesforce/apex/KenEventsController.registerForEvent';
import cancelRegistration from '@salesforce/apex/KenEventsController.cancelRegistration';
import submitHostedEvent from '@salesforce/apex/KenEventsController.submitHostedEvent';

export default class Events extends LightningElement {
    @track _apex;
    @track _searchTerm = '';
    @track _filterMode = 'all';
    @track _showFilterMenu = false;
    @track _bookmarks = new Set();
    @track _showAllRegistered = false;
    @track _showHostModal = false;
    @track _hostForm = { title: '', date: '', time: '', mode: 'Offline' };
    @track _toastVisible = false;
    @track _toastMessage = '';
    @track _toastVariant = 'success';

    showAToast(msg, v = 'success') { this._toastMessage = msg; this._toastVariant = v; this._toastVisible = true; }
    handleToastClose() { this._toastVisible = false; }
    get showToast() { return this._toastVisible; }
    get toastMessage() { return this._toastMessage; }
    get toastVariant() { return this._toastVariant; }
    get showFilterMenu() { return this._showFilterMenu; }
    get showHostModal() { return this._showHostModal; }
    get showAllRegistered() { return this._showAllRegistered; }
    get viewAllLabel() { return this._showAllRegistered ? 'Show Less' : 'View All'; }
    get filterLabel() {
        if (this._filterMode === 'all') return 'All';
        if (this._filterMode === 'online') return 'Online only';
        if (this._filterMode === 'offline') return 'In-person only';
        return this._filterMode;
    }
    get hostFormTitle() { return this._hostForm.title; }
    get hostFormDate() { return this._hostForm.date; }
    get hostFormTime() { return this._hostForm.time; }
    get hostFormMode() { return this._hostForm.mode; }

    stopProp(event) { event.stopPropagation(); }
    handleSearchInput(event) { this._searchTerm = event.target.value || ''; }
    handleToggleFilterMenu() { this._showFilterMenu = !this._showFilterMenu; }
    handlePickFilter(event) {
        this._filterMode = event.currentTarget.dataset.value;
        this._showFilterMenu = false;
    }

    _matchSearchAndFilter(ev) {
        const t = (this._searchTerm || '').toLowerCase().trim();
        if (t && !((ev.title || '').toLowerCase().includes(t) || (ev.mode || '').toLowerCase().includes(t) || (ev.type || '').toLowerCase().includes(t))) return false;
        if (this._filterMode === 'online' && !((ev.mode || '').toLowerCase().includes('online'))) return false;
        if (this._filterMode === 'offline' && (ev.mode || '').toLowerCase().includes('online')) return false;
        return true;
    }

    _imgFor(ev) {
        // Prefer Apex `imageUrl`, then seed `image`, then a category-driven default
        // pulled from the StudentPortalImages static resource.
        const provided = ev.imageUrl || ev.image;
        if (provided) return provided;
        const base = SP_IMAGES || '';
        const t = (ev.type || ev.title || '').toLowerCase();
        let file = 'workshop.jpg';
        if (t.includes('hack') || t.includes('coding') || t.includes('tech')) file = 'hackathon.jpg';
        else if (t.includes('cultur') || t.includes('fest') || t.includes('cultural')) file = 'cultural.jpg';
        else if (t.includes('seminar') || t.includes('career') || t.includes('confer') || t.includes('lecture')) file = 'seminar.jpg';
        return base + '/images/events/' + file;
    }

    _decorate(ev) {
        return {
            ...ev,
            image: this._imgFor(ev),
            isBookmarked: this._bookmarks.has(ev.id),
            bookmarkClass: this._bookmarks.has(ev.id) ? 'bookmark-btn saved' : 'bookmark-btn',
            bookmarkIcon: this._bookmarks.has(ev.id) ? 'bookmark' : 'bookmark_border'
        };
    }

    @track _wireResp;
    @wire(getEventsBundle)
    wiredEvents(response) {
        this._wireResp = response;
        const { data, error } = response;
        if (data) this._apex = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[events] Apex failed, using seed:', error);
        }
    }

    get effectiveData() {
        return this._apex || eventsData;
    }

    get featuredEvents() {
        return (this.effectiveData.featured || []).filter(e => this._matchSearchAndFilter(e)).map(e => this._decorate(e));
    }
    get upcomingEvents() {
        return (this.effectiveData.upcoming || []).filter(e => this._matchSearchAndFilter(e)).map(e => this._decorate(e));
    }
    get registeredEvents() {
        const all = (this.effectiveData.registered || []).map(e => Object.assign({}, e, { image: this._imgFor(e) }));
        return this._showAllRegistered ? all : all.slice(0, 3);
    }
    get featuredCount() { return this.featuredEvents.length; }
    get upcomingCount() { return this.upcomingEvents.length; }

    navigateTo(route) {
        this.dispatchEvent(new CustomEvent('navigate', { detail: { route } }));
    }
    handleBack() { this.navigateTo('campus-life'); }

    handleRegister(event) {
        const eventId = event.currentTarget.dataset.id;
        if (!eventId) return;
        registerForEvent({ eventId })
            .then(() => {
                this.showAToast('Registered for event');
                if (this._wireResp) refreshApex(this._wireResp);
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not register.';
                this.showAToast(msg, 'error');
            });
    }

    handleCancel(event) {
        const registrationId = event.currentTarget.dataset.id;
        if (!registrationId) return;
        cancelRegistration({ registrationId })
            .then(() => {
                this.showAToast('Registration cancelled');
                if (this._wireResp) refreshApex(this._wireResp);
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not cancel.';
                this.showAToast(msg, 'error');
            });
    }

    handleToggleBookmark(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        const next = new Set(this._bookmarks);
        if (next.has(id)) { next.delete(id); this.showAToast('Removed bookmark'); }
        else              { next.add(id);    this.showAToast('Event bookmarked'); }
        this._bookmarks = next;
    }

    handleToggleViewAllRegistered() { this._showAllRegistered = !this._showAllRegistered; }

    handleHostEvent() {
        this._hostForm = { title: '', date: '', time: '', mode: 'Offline' };
        this._showHostModal = true;
    }
    handleCloseHost() { this._showHostModal = false; }
    handleHostFormChange(event) {
        const f = event.target.dataset.field;
        if (!f) return;
        this._hostForm = Object.assign({}, this._hostForm, { [f]: event.target.value });
    }
    handleSubmitHost() {
        const f = this._hostForm;
        if (!f.title || !f.title.trim()) { this.showAToast('Please add a title', 'error'); return; }
        if (f.title.trim().length > 120) { this.showAToast('Title must be 120 characters or fewer', 'error'); return; }
        if (!f.date) { this.showAToast('Please pick a date', 'error'); return; }
        const todayIso = new Date().toISOString().slice(0, 10);
        if (f.date < todayIso) { this.showAToast('Event date cannot be in the past', 'error'); return; }
        submitHostedEvent({ title: f.title.trim(), dateStr: f.date, timeStr: f.time, mode: f.mode })
            .then(eventId => {
                this._showHostModal = false;
                this.showAToast(`Submitted "${f.title.trim()}" for review (id ${eventId || ''})`);
                if (this._wireResp) refreshApex(this._wireResp);
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not submit event.';
                this.showAToast(msg, 'error');
            });
    }
}