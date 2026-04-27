import { LightningElement, api, track } from 'lwc';
import { jobs } from 'c/placementData';
import applyToJob from '@salesforce/apex/KenPlacementsController.applyToJob';
import bookInterviewSlot from '@salesforce/apex/KenPlacementsController.bookInterviewSlot';
import raiseJobQuery from '@salesforce/apex/KenPlacementsController.raiseJobQuery';

export default class JobDetail extends LightningElement {
    @api jobId;
    @track applicationState = 'none';
    @track stageSubState = 'book-slot';
    @track showApplyModal = false;
    @track showSuccessModal = false;
    @track showSlotModal = false;
    @track selectedResume = 'r2';
    @track activeStepIdx = 1;
    @track selectedCalDate = 9;
    @track selectedSlotTime = '09:00 AM IST';
    @track calMonth = 'March 2026';
    @track _calMonthIdx = 2; // March (0-indexed)
    @track _calYear = 2026;
    @track demoIdx = 0;
    @track _bookmarked = false;
    @track _showQueryModal = false;
    @track _queryText = '';
    @track _toastVisible = false;
    @track _toastMessage = '';
    @track _toastVariant = 'success';
    showAToast(msg, v = 'success') { this._toastMessage = msg; this._toastVariant = v; this._toastVisible = true; }
    handleToastClose() { this._toastVisible = false; }
    get showToast() { return this._toastVisible; }
    get toastMessage() { return this._toastMessage; }
    get toastVariant() { return this._toastVariant; }
    get bookmarkBtnTitle() { return this._bookmarked ? 'Remove bookmark' : 'Bookmark'; }
    get bookmarkBtnClass() { return this._bookmarked ? 'btn-icon-sq saved' : 'btn-icon-sq'; }
    get queryText() { return this._queryText; }
    get showQueryModal() { return this._showQueryModal; }
    handleToggleBookmark() {
        this._bookmarked = !this._bookmarked;
        this.showAToast(this._bookmarked ? 'Job bookmarked' : 'Bookmark removed');
    }
    handleShareJob() {
        const url = (typeof window !== 'undefined' && window.location) ? window.location.href : '';
        const setText = navigator && navigator.clipboard && navigator.clipboard.writeText
            ? navigator.clipboard.writeText(url) : Promise.reject(new Error('clipboard'));
        setText.then(() => this.showAToast('Job link copied'))
               .catch(() => this.showAToast('Could not copy link', 'error'));
    }
    handleOpenQuery() { this._showQueryModal = true; this._queryText = ''; }
    handleCloseQuery() { this._showQueryModal = false; }
    handleQueryInput(event) { this._queryText = event.target.value || ''; }
    handleSubmitQuery() {
        if (!this._queryText.trim()) { this.showAToast('Please describe your query', 'error'); return; }
        const jobId = this.jobId;
        if (typeof jobId === 'string' && (jobId.length === 15 || jobId.length === 18)) {
            raiseJobQuery({ jobId, queryText: this._queryText.trim() })
                .then(() => {
                    this._showQueryModal = false;
                    this.showAToast('Query submitted to placements office');
                })
                .catch(err => {
                    const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not submit your query.';
                    this.showAToast(msg, 'error');
                });
        } else {
            // Demo data id — show toast without persisting (Case requires a real job id reference).
            this._showQueryModal = false;
            this.showAToast('Query recorded locally (demo data)');
        }
    }
    handleDownloadResume(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        const filename = `resume-${id || 'doc'}.txt`;
        try {
            const blob = new Blob(['Resume placeholder — your stored resume will be downloaded here.'], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url; a.download = filename;
            document.body.appendChild(a); a.click(); document.body.removeChild(a);
            setTimeout(() => URL.revokeObjectURL(url), 1500);
            this.showAToast('Resume downloaded');
        } catch (e) { this.showAToast('Download failed', 'error'); }
    }
    _MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    _refreshCalLabel() { this.calMonth = `${this._MONTHS[this._calMonthIdx]} ${this._calYear}`; }
    handleCalPrev() {
        this._calMonthIdx = (this._calMonthIdx - 1 + 12) % 12;
        if (this._calMonthIdx === 11) this._calYear -= 1;
        this._refreshCalLabel();
    }
    handleCalNext() {
        this._calMonthIdx = (this._calMonthIdx + 1) % 12;
        if (this._calMonthIdx === 0) this._calYear += 1;
        this._refreshCalLabel();
    }

    get job() {
        const found = jobs.find(j => j.id === this.jobId);
        return found ? found : jobs[0];
    }

    get jobTitle() { return this.job ? this.job.title : ''; }
    get companyName() { return this.job ? this.job.company : ''; }

    get salary() {
        if (!this.job) return '';
        const j = this.job;
        return j.salary.currency + ' ' + this._fmt(j.salary.min) + ' - ' + j.salary.currency + ' ' + this._fmt(j.salary.max);
    }

    get categoryClass() {
        if (!this.job) return 'cat-badge';
        const c = this.job.category;
        if (c === 'Super Dream') return 'cat-badge cat-super-dream';
        if (c === 'Dream') return 'cat-badge cat-dream';
        return 'cat-badge cat-regular';
    }

    get logoStyle() {
        return this.job ? 'background:' + this.job.companyColor : 'background:#4F46E5';
    }

    get companyInitial() { return this.job ? this.job.companyInitial : '?'; }

    get skillsMatchText() {
        if (!this.job) return '';
        return this.job.skillsMatch + '/' + this.job.skillsTotal + ' Skills Match with your Resume';
    }

    get applicationStages() {
        if (!this.job) return [];
        const proc = this.job.applicationProcess;
        return proc.map((stage, i) => {
            const isDone = i < this.activeStepIdx;
            const isActive = i === this.activeStepIdx;
            const isPending = i > this.activeStepIdx;
            const isFirst = i === 0;
            const isLast = i === proc.length - 1;
            let dotClass = 'step-dot';
            let cardClass = 'step-card';
            if (isDone) {
                dotClass += ' step-dot-done';
                cardClass += ' step-card-done';
            } else if (isActive) {
                dotClass += ' step-dot-active';
                cardClass += ' step-card-active';
            } else {
                dotClass += ' step-dot-pending';
                cardClass += ' step-card-pending';
            }
            const leftLineClass = isFirst ? 'step-line step-line-hidden' : (isDone ? 'step-line step-line-done' : (isActive ? 'step-line step-line-active' : 'step-line step-line-pending'));
            const rightLineClass = isLast ? 'step-line step-line-hidden' : (isDone ? 'step-line step-line-done' : (isActive ? 'step-line step-line-active' : 'step-line step-line-pending'));
            return {
                ...stage,
                idx: i,
                isDone,
                isActive,
                isPending,
                dotClass,
                cardClass,
                leftLineClass,
                rightLineClass
            };
        });
    }

    get currentStage() {
        if (!this.job || this.applicationState === 'none') return null;
        return this.job.applicationProcess[this.activeStepIdx];
    }

    get isNone()        { return this.applicationState === 'none'; }
    get isShortlisted() { return this.applicationState === 'shortlisted'; }

    get isBookSlotState()  { return this.isShortlisted && this.stageSubState === 'book-slot'; }
    get isScheduledState() { return this.isShortlisted && this.stageSubState === 'scheduled'; }
    get isInReviewState()  { return this.isShortlisted && this.stageSubState === 'in-review'; }

    get canApply()      { return this.applicationState === 'none' && this.job && !this.job.notEligible; }
    get isNotEligible() { return this.job && this.job.notEligible; }
    get isApplied()     { return this.applicationState !== 'none'; }
    get notApplied()    { return this.applicationState === 'none'; }

    get keyResponsibilities() {
        if (!this.job || !this.job.keyResponsibilities) return [];
        return this.job.keyResponsibilities.map((r, i) => ({ key: 'kr' + i, num: i + 1, text: r }));
    }

    get skillChips() {
        if (!this.job || !this.job.skills) return [];
        return this.job.skills.map(s => ({ key: s, label: s }));
    }

    get certCards() {
        if (!this.job || !this.job.certifications) return [];
        return this.job.certifications.map(c => ({
            ...c,
            iconStyle: 'background:' + c.color,
            durationText: 'Duration: ' + c.duration
        }));
    }

    get hasCertCards() {
        return this.certCards.length > 0;
    }

    get tags() {
        if (!this.job) return [];
        return this.job.tags.map(t => ({ key: t, label: t }));
    }

    get location() {
        if (!this.job) return [];
        return this.job.location.map(l => ({ key: l, label: l }));
    }

    get resumes() {
        return [
            { id: 'r1', name: 'Resume_compressed.pdf', date: 'Last used on 8/7/2024' },
            { id: 'r2', name: 'Visual designer.pdf', date: 'Last used on 6/5/2024' }
        ].map(r => ({
            ...r,
            isSelected: this.selectedResume === r.id,
            cls: this.selectedResume === r.id ? 'resume-option resume-selected' : 'resume-option',
            radioClass: this.selectedResume === r.id ? 'resume-radio resume-radio-checked' : 'resume-radio'
        }));
    }

    get selectedResumeObj() {
        return this.resumes.find(r => r.id === this.selectedResume);
    }

    get hasSelectedResume() { return this.selectedResume !== null; }

    get calDays() {
        const days = [];
        const daysInMonth = 31;
        const startOffset = 4;
        const available = [9, 10, 11, 14, 16];
        for (let i = 0; i < startOffset; i++) {
            days.push({ key: 'empty-' + i, date: null, label: '', isEmpty: true, isAvailable: false, isSelected: false, cls: 'cal-day cal-day-empty' });
        }
        for (let d = 1; d <= daysInMonth; d++) {
            const isAvail = available.includes(d);
            const isSel = d === this.selectedCalDate;
            let cls = 'cal-day';
            if (!isAvail) cls += ' cal-day-disabled';
            else if (isSel) cls += ' cal-day-selected';
            else if (d === 9) cls += ' cal-day-primary';
            else cls += ' cal-day-available';
            days.push({ key: 'day-' + d, date: d, label: '' + d, isEmpty: false, isAvailable: isAvail, isSelected: isSel, cls });
        }
        return days;
    }

    get slotGroups() {
        return [
            {
                key: 'morning',
                label: 'Morning',
                labelClass: 'slot-period-label slot-period-morning',
                slots: [
                    { key: 'sm1', time: '09:00 AM IST', period: 'Morning', periodClass: 'slot-tag slot-tag-morning' },
                    { key: 'sm2', time: '12:00 AM IST', period: 'Morning', periodClass: 'slot-tag slot-tag-morning' }
                ].map(s => ({ ...s, isSelected: this.selectedSlotTime === s.time, cls: this.selectedSlotTime === s.time ? 'slot-time-card slot-time-selected' : 'slot-time-card' }))
            },
            {
                key: 'afternoon',
                label: 'Afternoon',
                labelClass: 'slot-period-label slot-period-afternoon',
                slots: [
                    { key: 'sa1', time: '02:00 PM IST', period: 'Afternoon', periodClass: 'slot-tag slot-tag-afternoon' },
                    { key: 'sa2', time: '03:45 PM IST', period: 'Afternoon', periodClass: 'slot-tag slot-tag-afternoon' }
                ].map(s => ({ ...s, isSelected: this.selectedSlotTime === s.time, cls: this.selectedSlotTime === s.time ? 'slot-time-card slot-time-selected' : 'slot-time-card' }))
            }
        ];
    }

    get calWeekDays() {
        return ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map(d => ({ key: d, label: d }));
    }

    get demoStates() {
        return [
            { key: 'none', label: 'Pre-Apply' },
            { key: 'shortlisted-book', label: 'Shortlisted' },
            { key: 'shortlisted-scheduled', label: 'Scheduled' },
            { key: 'shortlisted-inreview', label: 'In Review' }
        ].map((s, i) => ({ ...s, cls: this.demoIdx === i ? 'demo-btn demo-btn-active' : 'demo-btn' }));
    }

    _fmt(num) {
        const s = num.toString();
        const last3 = s.slice(-3);
        const rest = s.slice(0, -3);
        if (!rest) return last3;
        return rest.replace(/\B(?=(\d{2})+(?!\d))/g, ',') + ',' + last3;
    }

    stopProp(event) { event.stopPropagation(); }

    handleBack() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'all-jobs' } }));
    }

    handleApply() { this.showApplyModal = true; }
    handleCloseApply() { this.showApplyModal = false; }

    handleSelectResume(event) {
        this.selectedResume = event.currentTarget.dataset.id;
    }

    handleSubmitApplication() {
        const jobId = this.jobId;
        // If we have a real Salesforce job id, persist the application; otherwise
        // act as a demo (seed jobs have non-Id strings).
        if (typeof jobId === 'string' && (jobId.length === 15 || jobId.length === 18)) {
            applyToJob({ jobId, resumeName: this.selectedResume || 'default' })
                .then(() => {
                    this.showApplyModal = false;
                    this.showSuccessModal = true;
                })
                .catch(err => {
                    const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not submit application.';
                    this.showAToast(msg, 'error');
                });
        } else {
            this.showApplyModal = false;
            this.showSuccessModal = true;
        }
    }

    handleAfterApply() {
        this.showSuccessModal = false;
        this.applicationState = 'shortlisted';
        this.stageSubState = 'book-slot';
        this.activeStepIdx = 1;
        this.demoIdx = 1;
    }

    handleCloseSuccess() { this.showSuccessModal = false; }

    handleBookSlot() { this.showSlotModal = true; }
    handleCloseSlot() { this.showSlotModal = false; }

    handleSelectCalDate(event) {
        const d = parseInt(event.currentTarget.dataset.date, 10);
        this.selectedCalDate = d;
    }

    handleSelectSlotTime(event) {
        this.selectedSlotTime = event.currentTarget.dataset.time;
    }

    handleConfirmSlot() {
        // Build a real Datetime if we have one (calendar selectedCalDate + slotTime).
        const month = this._calMonthIdx;
        const year  = this._calYear;
        const day   = this.selectedCalDate || 1;
        const time  = (this.selectedSlotTime || '09:00 AM').replace(/\s*IST/, '');
        const slotIso = `${year}-${String(month + 1).padStart(2,'0')}-${String(day).padStart(2,'0')} ${this._toIso24h(time)}:00`;
        // Only call Apex when we have a real job id.
        if (typeof this.jobId === 'string' && (this.jobId.length === 15 || this.jobId.length === 18)) {
            // The slot belongs to an Application record in real flow; for demo,
            // we'd need an applicationId. Skip Apex if not provided.
            if (this._activeApplicationId) {
                bookInterviewSlot({ applicationId: this._activeApplicationId, slot: slotIso })
                    .then(() => {
                        this.showSlotModal = false;
                        this.stageSubState = 'scheduled';
                        this.demoIdx = 2;
                        this.showAToast('Slot booked', 'success');
                    })
                    .catch(err => {
                        const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not book slot.';
                        this.showAToast(msg, 'error');
                    });
                return;
            }
        }
        this.showSlotModal = false;
        this.stageSubState = 'scheduled';
        this.demoIdx = 2;
    }

    @track _activeApplicationId;
    _toIso24h(timeStr) {
        // Converts "09:00 AM" / "12:30 PM" → "09:00" / "12:30"
        const m = String(timeStr || '').match(/(\d{1,2}):(\d{2})\s*(AM|PM)?/i);
        if (!m) return '09:00';
        let h = parseInt(m[1], 10);
        const min = m[2];
        const ampm = (m[3] || '').toUpperCase();
        if (ampm === 'PM' && h < 12) h += 12;
        if (ampm === 'AM' && h === 12) h = 0;
        return String(h).padStart(2, '0') + ':' + min;
    }

    @track showToast = false;
    @track toastMessage = '';
    @track toastVariant = 'success';

    _toast(msg, variant) {
        this.toastMessage = msg;
        this.toastVariant = variant || 'success';
        this.showToast = true;
    }
    handleToastClose() { this.showToast = false; }

    handleJoinMeet() {
        this._toast('Opening video call\u2026 Ensure your camera and mic are enabled.', 'info');
    }

    handleDemoSwitch(event) {
        const state = event.currentTarget.dataset.state;
        if (state === 'none') {
            this.applicationState = 'none';
            this.demoIdx = 0;
        } else if (state === 'shortlisted-book') {
            this.applicationState = 'shortlisted';
            this.stageSubState = 'book-slot';
            this.activeStepIdx = 1;
            this.demoIdx = 1;
        } else if (state === 'shortlisted-scheduled') {
            this.applicationState = 'shortlisted';
            this.stageSubState = 'scheduled';
            this.activeStepIdx = 1;
            this.demoIdx = 2;
        } else if (state === 'shortlisted-inreview') {
            this.applicationState = 'shortlisted';
            this.stageSubState = 'in-review';
            this.activeStepIdx = 1;
            this.demoIdx = 3;
        }
    }
}