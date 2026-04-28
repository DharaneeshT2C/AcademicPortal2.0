import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { pageNameForRoute } from 'c/navHelper';
import { examData, studentProfile } from 'c/mockData';
import getResultsBundle from '@salesforce/apex/KenResultsController.getResultsBundle';

export default class Results extends NavigationMixin(LightningElement) {
    @track _apex;
    // Seed fallback retained for template bindings.
    student = studentProfile;
    _seed = examData.results;

    @wire(getResultsBundle)
    wiredResults({ data, error }) {
        if (data) this._apex = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[results] Apex failed, using seed:', error);
        }
    }

    get data() {
        if (this._apex) return Object.assign({}, this._seed, this._apex);
        return this._seed;
    }

    get effectiveData() {
        return this.data;
    }

    get semesterBars() {
        return (this.effectiveData.semesterBreakup || []).map(s => ({
            ...s,
            key: 'sb-' + s.sem
        }));
    }

    get linePoints() {
        const items = this.effectiveData.semesterBreakup || [];
        const total = items.length;
        if (total < 2) return '';
        const points = [];
        for (let i = 0; i < total; i++) {
            const x = (i / (total - 1)) * 680 + 10;
            const y = 200 - (items[i].gpa / 10) * 190;
            points.push(x + ',' + y);
        }
        return points.join(' ');
    }

    get chartDots() {
        const items = this.effectiveData.semesterBreakup || [];
        const total = items.length;
        const dots = [];
        for (let i = 0; i < total; i++) {
            if (items[i].gpa > 0) {
                const x = (i / (total - 1)) * 680 + 10;
                const y = 200 - (items[i].gpa / 10) * 190;
                dots.push({ key: 'dot-' + i, cx: String(x), cy: String(y) });
            }
        }
        return dots;
    }

    get chartLabels() {
        const items = this.effectiveData.semesterBreakup || [];
        const total = items.length;
        const labels = [];
        for (let i = 0; i < total; i++) {
            if (items[i].gpa > 0) {
                const x = (i / (total - 1)) * 680 + 10;
                const y = 200 - (items[i].gpa / 10) * 190 - 12;
                labels.push({ key: 'lbl-' + i, x: String(x), y: String(y), text: String(items[i].gpa) });
            }
        }
        return labels;
    }

    navigateTo(route) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: pageNameForRoute(route) }
        });
    }
    handleMarksBreakdown() { this.navigateTo('marks-breakdown'); }
    handleViewGradeCards() { this.navigateTo('marks-breakdown'); }
}