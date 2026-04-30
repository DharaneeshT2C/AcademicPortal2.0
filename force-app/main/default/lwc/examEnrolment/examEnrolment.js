import { LightningElement } from 'lwc';
import enrollPersonExaminations from '@salesforce/apex/KenExamEnrollmentController.enrollPersonExaminations';
import fetchCurrentSemesterExaminations from '@salesforce/apex/KenExamEnrollmentController.fetchCurrentSemesterExaminations';

export default class ExamEnrollment extends LightningElement {
    rows = [];
    tooltipRowId;
    isConfirmModalOpen = false;
    isLoading = true;
    isSubmitting = false;
    errorMessage;
    emptyMessage;
    currentSemesterLabel = 'Current Semester';

    get crumbs() {
        return [
            { label: 'Home',     pageName: 'Home' },
            { label: 'My Exams', url: '/my-exams' },
            { label: 'Enrolment' }
        ];
    }

    connectedCallback() {
        this.loadRows();
    }

    get displayRows() {
        return this.rows.map((row) => ({
            ...row,
            isDisabled: !row.eligible,
            showInfoIcon: !row.eligible,
            showTooltip: this.tooltipRowId === row.id,
            eligibilityLabel: row.eligibilityLabel,
            eligibilityClass: row.eligible
                ? 'status-pill status-eligible'
                : 'status-pill status-not-eligible'
        }));
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get isAllEligibleSelected() {
        const eligibleRows = this.rows.filter((row) => row.eligible);
        if (!eligibleRows.length) return false;
        return eligibleRows.every((row) => row.selected);
    }

    get selectedCount() {
        return this.rows.filter((row) => row.eligible && row.selected).length;
    }

    get selectedSummary() {
        const noun = this.selectedCount === 1 ? 'exam' : 'exams';
        return `${this.selectedCount} ${noun} selected`;
    }

    get isProceedDisabled() {
        return this.selectedCount === 0 || this.isSubmitting;
    }

    get selectedPersonExaminationIds() {
        return this.rows
            .filter((row) => row.eligible && row.selected && row.personExaminationId)
            .map((row) => row.personExaminationId);
    }

    async loadRows() {
        this.isLoading = true;
        this.errorMessage = undefined;
        this.emptyMessage = undefined;

        try {
            const response = await fetchCurrentSemesterExaminations();
            this.currentSemesterLabel =
                response?.currentSemesterLabel || 'Current Semester';
            this.rows = (response?.rows || []).map((row) => ({
                id: row.rowKey || row.personExaminationId,
                personExaminationId: row.personExaminationId,
                courseName: row.courseName || '-',
                courseCode: row.courseCode || '-',
                exam: row.exam || '-',
                credits: row.credits ?? '-',
                format: row.format || '-',
                type: row.type || '-',
                eligible: Boolean(row.eligible),
                selected: Boolean(row.eligible),
                eligibilityLabel: row.eligibilityLabel || '-'
            }));

            if (!this.rows.length) {
                this.emptyMessage =
                    response?.message ||
                    'No person examination records are available for the current semester.';
            }
        } catch (error) {
            this.rows = [];
            this.errorMessage =
                error?.body?.message ||
                error?.message ||
                'Unable to load exam enrollment records.';
        } finally {
            this.isLoading = false;
        }
    }

    handleRowToggle(event) {
        const rowId = event.currentTarget.dataset.id;
        const isChecked = event.currentTarget.checked;
        this.rows = this.rows.map((row) => {
            if (row.id !== rowId || !row.eligible) {
                return row;
            }
            return {
                ...row,
                selected: isChecked
            };
        });
    }

    handleSelectAll(event) {
        const isChecked = event.currentTarget.checked;
        this.rows = this.rows.map((row) => {
            if (!row.eligible) {
                return row;
            }
            return {
                ...row,
                selected: isChecked
            };
        });
    }

    showTooltip(event) {
        this.tooltipRowId = event.currentTarget.dataset.id;
    }

    hideTooltip() {
        this.tooltipRowId = null;
    }

    openConfirmModal() {
        if (this.isProceedDisabled) {
            return;
        }
        this.isConfirmModalOpen = true;
    }

    closeConfirmModal() {
        this.isConfirmModalOpen = false;
    }

    stopModalClose(event) {
        event.stopPropagation();
    }

    async handleContinue() {
        if (this.isSubmitting || !this.selectedPersonExaminationIds.length) {
            return;
        }

        this.isSubmitting = true;
        this.errorMessage = undefined;

        try {
            await enrollPersonExaminations({
                personExaminationIds: this.selectedPersonExaminationIds
            });
            this.closeConfirmModal();
            await this.loadRows();
        } catch (error) {
            this.errorMessage =
                error?.body?.message ||
                error?.message ||
                'Unable to complete exam enrollment.';
            this.closeConfirmModal();
        } finally {
            this.isSubmitting = false;
        }
    }
}