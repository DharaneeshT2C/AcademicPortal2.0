import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { pageNameForRoute } from 'c/navHelper';
import { examData } from 'c/mockData';
import getAllBreakdowns from '@salesforce/apex/KenMarksBreakdownController.getAllBreakdowns';
import getBreakdown from '@salesforce/apex/KenMarksBreakdownController.getBreakdown';

export default class MarksBreakdown extends NavigationMixin(LightningElement) {
    @track _apex;           // list of breakdowns from @wire
    @track _selectedBreakdown; // drill-down from imperative call
    // Seed fallback retained for template bindings.
    _seed = examData.results.courseDetail;

    @wire(getAllBreakdowns)
    wiredBreakdowns({ data, error }) {
        if (data) this._apex = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[marksBreakdown] Apex failed, using seed:', error);
        }
    }

    get data() {
        if (this._selectedBreakdown) return this._selectedBreakdown;
        if (this._apex && this._apex.length) return this._apex[0];
        return this._seed;
    }

    @track _loadError;
    get hasLoadError() { return !!this._loadError; }
    get loadErrorMessage() { return this._loadError; }
    handleDismissLoadError() { this._loadError = null; }

    handleSubjectClick(event) {
        const subjectId = event.currentTarget.dataset.id;
        if (!subjectId) return;
        this._loadError = null;
        getBreakdown({ subjectId })
            .then(detail => { this._selectedBreakdown = detail; })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not load this subject.';
                this._loadError = msg;
            });
    }

    navigateTo(route) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: pageNameForRoute(route) }
        });
    }
    handleBack() { this.navigateTo('results'); }
}