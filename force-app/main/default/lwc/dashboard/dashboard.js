import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { pageNameForRoute } from 'c/navHelper';
import getDashboard  from '@salesforce/apex/KenHomeDashboardController.getDashboard';
import recordMoodApex from '@salesforce/apex/KenHomeDashboardController.recordMood';

const SCHEDULE_PAGE = 'Schedule__c';

export default class Dashboard extends NavigationMixin(LightningElement) {
    @track _stage = 'middle';
    @track _careerPath = 'placements';
    @track _brand = 'ken';
    @track _apex;                // DashboardDTO from getDashboard (undefined until wire resolves)
    @track checklistExpanded = false;
    @track selectedMood = '';
    @track showToast = false;
    @track toastMessage = '';
    @track toastVariant = 'success';
    @track placementPhase = 2;   // dev-only Career preview, session-only in Salesforce

    student = {};

    @api
    get stage() { return this._stage; }
    set stage(v) { this._stage = v || 'middle'; }

    @api
    get careerPath() { return this._careerPath; }
    set careerPath(v) { this._careerPath = v || 'placements'; }

    @api
    get brand() { return this._brand; }
    set brand(v) { this._brand = v || 'ken'; }

    // ── Apex wire ───────────────────────────────────────────────────────────
    @wire(getDashboard, { stage: '$_stage', careerPath: '$_careerPath', brand: '$_brand' })
    wiredDashboard({ data, error }) {
        if (data) {
            this._apex = this._normalizeApex(data);
        } else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[dashboard] Apex getDashboard failed, using seed:', error);
        }
    }

    // Translate Apex DTO field names to what the LWC template expects.
    // Apex uses: eyebrow/description/ctaLabel/heroValue/subLabel/dateRange/dateMonth/dateDay/meta/toast
    // Template expects: label/desc/cta/heroText/subText/date/month/day/context/toastMsg
    _normalizeApex(d) {
        if (!d) return d;
        const out = Object.assign({}, d);
        if (d.pinnedCard) {
            out.pinnedCard = Object.assign({}, d.pinnedCard, {
                label: d.pinnedCard.label || d.pinnedCard.eyebrow,
                desc:  d.pinnedCard.desc  || d.pinnedCard.description,
                cta:   d.pinnedCard.cta   || d.pinnedCard.ctaLabel
            });
        }
        if (d.spotlight) {
            out.spotlight = Object.assign({}, d.spotlight, {
                heroText: d.spotlight.heroText || d.spotlight.heroValue,
                subText:  d.spotlight.subText  || d.spotlight.subLabel,
                date:     d.spotlight.date     || d.spotlight.dateRange,
                cta:      d.spotlight.cta      || d.spotlight.ctaLabel
            });
        }
        if (Array.isArray(d.feedItems)) {
            out.feedItems = d.feedItems.map(f => Object.assign({}, f, {
                month: f.month || f.dateMonth,
                day:   f.day   || f.dateDay,
                desc:  f.desc  || f.description
            }));
        }
        if (Array.isArray(d.forYouItems)) {
            out.forYouItems = d.forYouItems.map(f => Object.assign({}, f, {
                context:  f.context  || f.meta,
                toastMsg: f.toastMsg || f.toast
            }));
        }
        if (Array.isArray(d.needsAttention)) {
            out.needsAttention = d.needsAttention.map(n => Object.assign({}, n, {
                context: n.context || n.meta,
                rowClass: n.rowClass || 'needs-row'
            }));
        }
        if (Array.isArray(d.quickActions)) {
            out.quickActions = d.quickActions.map(q => Object.assign({}, q, {
                toastMsg: q.toastMsg || q.toast
            }));
        }
        return out;
    }

    // ── Stage flags ─────────────────────────────────────────────────────────
    get isStarting() { return this._stage === 'starting'; }
    get isMiddle()   { return this._stage === 'middle'; }
    get isEnding()   { return this._stage === 'ending'; }

    // ── Greeting ────────────────────────────────────────────────────────────
    get greetingText() {
        return (this._apex && this._apex.greeting && this._apex.greeting.headline)
            ? this._apex.greeting.headline.replace(/,\s*.+$/, '')
            : 'Good morning';
    }

    get displayName() {
        const apexFirst = this._apex && this._apex.student && this._apex.student.firstName;
        // Apex returns 'Student' as the default placeholder when the running user
        // has no linked Contact (e.g. admin previewing in Experience Builder).
        // In that case, fall back to the seeded student profile.
        if (apexFirst && apexFirst !== 'Student') return apexFirst;
        if (this._apex && this._apex.student && this._apex.student.displayName
            && this._apex.student.displayName !== 'Student') {
            return this._apex.student.displayName.split(' ')[0];
        }
        return '';
    }

    get greetingSub() {
        if (this._apex && this._apex.greeting && this._apex.greeting.sub) return this._apex.greeting.sub;
        if (this._stage === 'starting') return "You're in your first semester — start with the essentials below";
        if (this._stage === 'ending')   return 'Almost there — wrap up your final semester strong';
        return 'You have 2 deadlines today';
    }

    // ── KPI cards ───────────────────────────────────────────────────────────
    get kpiCards() {
        return (this._apex && this._apex.kpiCards) || [];
    }

    // ── Pinned card ─────────────────────────────────────────────────────────
    get showPinnedCard() {
        return !!(this._apex && this._apex.pinnedCard && this._apex.pinnedCard.show);
    }

    get pinnedCard() {
        if (this._apex && this._apex.pinnedCard && this._apex.pinnedCard.show) return this._apex.pinnedCard;
        return {};
    }

    // ── Feed ────────────────────────────────────────────────────────────────
    get feedItems() {
        return (this._apex && this._apex.feedItems) || [];
    }

    // ── For-you panel ───────────────────────────────────────────────────────
    get forYouTitle() {
        if (this._stage === 'starting') return 'Start here';
        if (this._stage === 'ending')   return 'Before you go';
        return 'For you right now';
    }

    get forYouItems() {
        return (this._apex && this._apex.forYouItems) || [];
    }

    get showNeedsAttention() { return this._stage !== 'ending'; }

    get needsAttentionItems() {
        return (this._apex && this._apex.needsAttention) || [];
    }

    get clearanceItems() {
        return (this._apex && this._apex.clearanceItems) || [];
    }

    get nextStepsItems() { return (this._apex && this._apex.nextStepsItems) || []; }

    // ── Today ───────────────────────────────────────────────────────────────
    get todayLabel() {
        if (this._apex && this._apex.todayLabel) return this._apex.todayLabel;
        if (this._stage === 'starting') return 'Aug 1';
        if (this._stage === 'ending')   return 'May 20';
        return 'Apr 15';
    }

    get todayItems() {
        return (this._apex && this._apex.todayItems) || [];
    }

    // ── Spotlight ───────────────────────────────────────────────────────────
    get spotlight() {
        return (this._apex && this._apex.spotlight) || {};
    }

    get isSpotlightTextHero() {
        if (this._apex && this._apex.spotlight) return this._apex.spotlight.isTextHero;
        return this._stage === 'starting';
    }

    get isSpotlightCountHero() {
        if (this._apex && this._apex.spotlight) return !this._apex.spotlight.isTextHero;
        return this._stage !== 'starting';
    }

    // ── Quick actions / Campus guide ────────────────────────────────────────
    get quickActionsItems() {
        return (this._apex && this._apex.quickActions) || [];
    }

    get campusGuideItems() {
        return (this._apex && this._apex.campusGuideItems) || [];
    }

    // ── Checklist (starting stage) ──────────────────────────────────────────
    get checklistItems() { return (this._apex && this._apex.checklistItems) || []; }

    get checklistDoneCount() {
        return this.checklistItems.filter(i => i.isDone).length;
    }

    get checklistTotal() { return this.checklistItems.length || 1; }

    get checklistProgressStyle() {
        const pct = Math.round((this.checklistDoneCount / this.checklistTotal) * 100);
        return 'width:' + pct + '%';
    }

    get checklistToggleLabel() {
        return this.checklistExpanded ? 'Collapse' : 'Expand';
    }

    get checklistChevronClass() {
        return this.checklistExpanded ? 'checklist-chevron checklist-chevron-up' : 'checklist-chevron';
    }

    // ── Mood ────────────────────────────────────────────────────────────────
    get moodQuestion() {
        if (this._stage === 'starting') return "How's your first week going?";
        return 'How are you feeling this week?';
    }

    get showPathSwitcher() { return this._stage === 'ending'; }

    get moodGoodClass()  { return this.selectedMood === 'good'  ? 'mood-pill mood-pill-selected' : 'mood-pill'; }
    get moodOkayClass()  { return this.selectedMood === 'okay'  ? 'mood-pill mood-pill-selected' : 'mood-pill'; }
    get moodRoughClass() { return this.selectedMood === 'rough' ? 'mood-pill mood-pill-selected' : 'mood-pill'; }

    get spotlightRoute() {
        if (this._apex && this._apex.spotlight && this._apex.spotlight.route) return this._apex.spotlight.route;
        if (this._stage === 'starting') return 'schedule';
        if (this._stage === 'middle')   return 'my-exams';
        return '';
    }

    // ── Has-X getters for empty-state gating ────────────────────────────────
    get hasFeedItems()      { return (this.feedItems || []).length > 0; }
    get hasForYouItems()    { return (this.forYouItems || []).length > 0; }
    get hasNeedsAttention() { return (this.needsAttentionItems || []).length > 0; }
    get hasQuickActions()   { return (this.quickActionsItems || []).length > 0; }
    get hasCampusGuide()    { return (this.campusGuideItems || []).length > 0; }
    get hasClearance()      { return (this.clearanceItems || []).length > 0; }
    get hasSpotlight() {
        const s = this._apex && this._apex.spotlight;
        if (!s) return false;
        return !!(s.heroText || s.heroValue || s.subText || s.subLabel);
    }
    get hasPinned() {
        const p = this._apex && this._apex.pinnedCard;
        return !!(p && p.show);
    }

    // ── Events / actions ────────────────────────────────────────────────────
    navigateTo(route) { this.dispatchEvent(new CustomEvent('navigate', { detail: { route } })); }
    navigateWithMixin(route) {
        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: pageNameForRoute(route) }
            });
        } catch (e) {
            this.navigateTo(route);
        }
    }

    _showToast(msg, variant) {
        this.toastMessage = msg;
        this.toastVariant = variant || 'success';
        this.showToast = true;
    }

    handleToastClose() { this.showToast = false; }

    handleMoodSelect(event) {
        const mood = event.currentTarget.dataset.mood;
        const previousMood = this.selectedMood;
        this.selectedMood = mood;
        recordMoodApex({ mood }).catch(err => {
            // Roll back the visual selection so the dashboard reflects truth.
            this.selectedMood = previousMood;
            const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not save mood.';
            this._showToast(msg, 'error');
        });
    }

    handleQuickAction(event) {
        const route    = event.currentTarget.dataset.route;
        const toastMsg = event.currentTarget.dataset.toast;
        if (toastMsg) { this._showToast(toastMsg, 'success'); }
        else if (route) { this.navigateTo(route); }
    }

    handleCampusGuide(event) {
        const route = event.currentTarget.dataset.route;
        if (route) { this.navigateTo(route); }
    }

    handleForYouRow(event) {
        const route    = event.currentTarget.dataset.route;
        const toastMsg = event.currentTarget.dataset.toast;
        if (toastMsg) { this._showToast(toastMsg, 'info'); }
        else if (route) { this.navigateTo(route); }
    }

    handleNextStepRow(event) {
        const route    = event.currentTarget.dataset.route;
        const toastMsg = event.currentTarget.dataset.toast;
        if (toastMsg) { this._showToast(toastMsg, 'info'); }
        else if (route) { this.navigateTo(route); }
    }

    handleViewAll()      { this.navigateTo('events'); }
    handleViewCalendar() {
        try {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: SCHEDULE_PAGE }
            });
        } catch (e) {
            this.navigateTo('schedule');
        }
    }
    handleKaiChat()      { this.navigateTo('chat'); }
    handleViewFeedItem() { this.navigateTo('events'); }

    handleSpotlightCta() {
        if (this.spotlightRoute) { this.navigateWithMixin(this.spotlightRoute); }
        else { this._showToast('RSVP confirmed for Convocation 2026!', 'success'); }
    }

    handlePinnedCta() {
        if (this._stage === 'middle') { this.navigateTo('events'); }
        else { this._showToast('RSVP confirmed! See you on Jun 15.', 'success'); }
    }

    handleToggleChecklist() {
        this.checklistExpanded = !this.checklistExpanded;
    }

    get placementPhaseBtns() {
        const labels = { '-1':'Out', 0:'P0', 1:'P1', 2:'P2', 3:'P3', 5:'P5' };
        return [-1, 0, 1, 2, 3, 5].map(p => ({
            id: 'pp' + p,
            phase: p,
            label: labels[p],
            activeClass: this.placementPhase === p ? 'dev-btn dev-btn-active' : 'dev-btn'
        }));
    }

    handlePlacementPhaseSwitch(event) {
        const p = parseInt(event.currentTarget.dataset.phase, 10);
        this.placementPhase = p;
    }
}