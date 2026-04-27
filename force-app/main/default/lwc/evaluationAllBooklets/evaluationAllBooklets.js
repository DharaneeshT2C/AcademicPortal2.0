import { LightningElement, track } from 'lwc';
import communityBasePath from '@salesforce/community/basePath';

const BOOKLETS = [
    {
        id: 'booklet-1',
        bookletId: '#BF389DY92',
        totalMarks: '72',
        status: 'Partially Evaluated'
    },
    {
        id: 'booklet-2',
        bookletId: '#BF389DY93',
        totalMarks: '83',
        status: 'Partially Evaluated'
    },
    {
        id: 'booklet-3',
        bookletId: '#BF389DY94',
        totalMarks: '38',
        status: 'Completed'
    },
    {
        id: 'booklet-4',
        bookletId: '#BF389DY95',
        totalMarks: '--',
        status: 'Pending'
    }
];

export default class EvaluationAllBooklets extends LightningElement {
    @track searchKey = '';
    booklets = BOOKLETS;
    isDecisionModalOpen = false;
    isSuccessModalOpen = false;
    decisionModalType = 'full';
    successTimer;

    get filteredBooklets() {
        const key = this.searchKey.trim().toLowerCase();
        const rows = key
            ? this.booklets.filter((item) => item.bookletId.toLowerCase().includes(key))
            : this.booklets;

        return rows.map((item) => ({
            ...item,
            statusClass: this.getStatusClass(item.status)
        }));
    }

    get hasFilteredBooklets() {
        return this.filteredBooklets.length > 0;
    }

    get hasNoFilteredBooklets() {
        return !this.hasFilteredBooklets;
    }

    get hasAnyEvaluatedBooklet() {
        return this.booklets.some((item) => item.status !== 'Pending');
    }

    get evaluationActionLabel() {
        return this.hasAnyEvaluatedBooklet ? 'Resume Evaluation' : 'Start Evaluation';
    }

    get isSubmitDisabled() {
        return !this.hasAnyEvaluatedBooklet;
    }

    get submitButtonClass() {
        return this.isSubmitDisabled ? 'primary-action primary-action-disabled' : 'primary-action';
    }

    get completedCount() {
        return this.booklets.filter((item) => item.status === 'Completed').length;
    }

    get partialCount() {
        return this.booklets.filter((item) => item.status === 'Partially Evaluated').length;
    }

    get pendingCount() {
        return this.booklets.filter((item) => item.status === 'Pending').length;
    }

    get decisionModalTitle() {
        if (this.decisionModalType === 'partial') {
            return 'Some booklets partially evaluated';
        }
        if (this.decisionModalType === 'pending') {
            return 'Some booklets pending';
        }
        if (this.decisionModalType === 'mixed') {
            return 'Some booklets are not fully evaluated';
        }
        return 'Submit bundle?';
    }

    get isFullyEvaluatedModal() {
        return this.decisionModalType === 'full';
    }

    get isPartialOnlyModal() {
        return this.decisionModalType === 'partial';
    }

    get isPendingOnlyModal() {
        return this.decisionModalType === 'pending';
    }

    get isNotFullyEvaluatedModal() {
        return this.decisionModalType === 'mixed';
    }

    get showWarningIcon() {
        return this.decisionModalType !== 'full';
    }

    get secondaryDecisionButtonLabel() {
        return this.decisionModalType === 'full' ? 'Cancel' : 'Go Back';
    }

    get primaryDecisionButtonLabel() {
        return this.decisionModalType === 'full' ? 'Submit' : 'Submit Anyway';
    }

    get pendingCountLabel() {
        return `${this.pendingCount} booklet${this.pendingCount === 1 ? '' : 's'}`;
    }

    get fullyEvaluatedLead() {
        const bundleCount = this.booklets.length;
        const bookletLabel = bundleCount === 1 ? 'booklet' : 'booklets';
        return `All ${bundleCount} ${bookletLabel} have been fully evaluated. Once submitted, you won't be able to make further changes.`;
    }

    handleSearch(event) {
        this.searchKey = event.target.value || '';
    }

    handleSubmitBundle() {
        if (this.isSubmitDisabled) {
            return;
        }

        this.decisionModalType = this.resolveDecisionModalType();
        this.isDecisionModalOpen = true;
    }

    handleOpenMarksEvaluation() {
        window.open(this.buildCommunityUrl('exams/evaluation-requests/booklets/marks-evaluation'), '_self');
    }

    buildCommunityUrl(path = '') {
        const basePath = communityBasePath || '/';
        const sanitizedPath = path.replace(/^\/+|\/+$/g, '');

        if (basePath === '/') {
            return sanitizedPath ? `/${sanitizedPath}` : '/';
        }

        return sanitizedPath ? `${basePath}/${sanitizedPath}` : basePath;
    }

    closeDecisionModal() {
        this.isDecisionModalOpen = false;
    }

    confirmSubmitBundle() {
        this.isDecisionModalOpen = false;
        this.isSuccessModalOpen = true;

        if (this.successTimer) {
            clearTimeout(this.successTimer);
        }

        this.successTimer = setTimeout(() => {
            this.isSuccessModalOpen = false;
            this.successTimer = null;
        }, 1800);
    }

    disconnectedCallback() {
        if (this.successTimer) {
            clearTimeout(this.successTimer);
            this.successTimer = null;
        }
    }

    getStatusClass(status) {
        if (status === 'Completed') {
            return 'status-pill status-completed';
        }
        if (status === 'Partially Evaluated') {
            return 'status-pill status-partial';
        }
        return 'status-pill status-pending';
    }

    resolveDecisionModalType() {
        const hasCompleted = this.completedCount > 0;
        const hasPartial = this.partialCount > 0;
        const hasPending = this.pendingCount > 0;

        if (!hasPartial && !hasPending) {
            return 'full';
        }
        if (hasPartial && !hasPending) {
            return 'partial';
        }
        if (!hasPartial && hasPending) {
            return 'pending';
        }
        if (hasCompleted && hasPartial && hasPending) {
            return 'mixed';
        }
        return 'mixed';
    }
}