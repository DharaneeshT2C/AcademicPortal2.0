import { LightningElement, track } from 'lwc';
import { prepResources, mockInterviews } from 'c/placementData';

export default class PrepHub extends LightningElement {
    @track activeTab = 'learning';
    @track activeCategory = 'all';
    @track showFilters = false;
    @track selectedInterview = null;
    @track showMockDetail = false;

    get isLearning() { return this.activeTab === 'learning'; }
    get isMockInterview() { return this.activeTab === 'mock-interview'; }

    get learningTabClass() { return this.activeTab === 'learning' ? 'tab-btn tab-active' : 'tab-btn'; }
    get mockTabClass() { return this.activeTab === 'mock-interview' ? 'tab-btn tab-active' : 'tab-btn'; }

    get categoryPills() {
        return ['all', 'Question Papers', 'Training Materials', 'Interview Tips', 'Aptitude Tests'].map(c => ({
            key: c,
            label: c === 'all' ? 'View All' : c,
            cls: this.activeCategory === c ? 'cat-pill cat-active' : 'cat-pill'
        }));
    }

    get filteredResources() {
        let list = prepResources;
        if (this.activeCategory !== 'all') {
            list = list.filter(r => r.category === this.activeCategory);
        }
        return list.map(r => ({
            ...r,
            tagItems: r.tags.map(t => ({ key: t, label: t })),
            badgeStyle: 'background:' + r.companyColor
        }));
    }

    get mockInterviewList() {
        return mockInterviews.map(m => ({
            ...m,
            logoStyle: 'background:' + m.companyColor,
            attemptsText: m.attempts + '/' + m.maxAttempts + ' Attempts'
        }));
    }

    get selectedInterviewData() {
        const m = mockInterviews.find(i => i.id === this.selectedInterview);
        if (!m) return { company: '', companyInitial: '', logoStyle: '', attempts: 0, maxAttempts: 3, role: '', duration: '' };
        return {
            ...m,
            logoStyle: 'background:' + m.companyColor
        };
    }

    handleTabSwitch(event) { this.activeTab = event.currentTarget.dataset.tab; }
    handleCategorySwitch(event) { this.activeCategory = event.currentTarget.dataset.cat; }
    handleToggleFilters() { this.showFilters = !this.showFilters; }

    handleBack() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'landing' } }));
    }

    handleStartMock(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedInterview = id;
        this.showMockDetail = true;
    }

    handleCloseMockDetail() { this.showMockDetail = false; }

    handleBeginInterview() {
        this.showMockDetail = false;
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'mock-interview', interviewId: this.selectedInterview } }));
    }

    stopProp(event) { event.stopPropagation(); }
}