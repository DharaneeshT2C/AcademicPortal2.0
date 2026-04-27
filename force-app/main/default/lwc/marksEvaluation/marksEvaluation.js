import { LightningElement, track } from 'lwc';

const MAX_MARK_PER_QUESTION = 5;

const QUESTION_COLUMNS = [
    { key: 'q1', label: 'Q1 (05)' },
    { key: 'q2', label: 'Q2 (05)' },
    { key: 'q3', label: 'Q3 (05)' },
    { key: 'q4', label: 'Q4 (05)' },
    { key: 'q5', label: 'Q5 (05)' },
    { key: 'q6', label: 'Q6 (05)' },
    { key: 'q7', label: 'Q7 (05)' },
    { key: 'q8', label: 'Q8 (05)' }
];

const SECTION_GROUPS = [
    {
        key: 'section-a',
        colspan: 3,
        title: 'Section A - 30 marks',
        subtitle: 'All questions will be counted',
        className: 'group-title'
    },
    {
        key: 'section-b',
        colspan: 3,
        title: 'Section B - 30 marks',
        subtitle: 'Any 2 of 3 - best 2 auto-selected',
        className: 'group-title'
    },
    {
        key: 'section-c',
        colspan: 2,
        title: 'Section C - 30 marks',
        subtitle: 'All questions will be counted',
        className: 'group-title'
    },
    {
        key: 'total',
        colspan: 1,
        title: '',
        subtitle: '',
        className: 'group-title group-total'
    }
];

const ROWS = [
    {
        id: '1',
        serial: '1',
        bookletNo: 'BF389DY92',
        marks: { q1: '05', q2: '05', q3: '05', q4: '05', q5: '05', q6: '03', q7: '05', q8: '05' }
    },
    {
        id: '2',
        serial: '2',
        bookletNo: 'BF389DY93',
        marks: { q1: '05', q2: '05', q3: '05', q4: '05', q5: '02', q6: '05', q7: '05', q8: '05' }
    },
    {
        id: '3',
        serial: '3',
        bookletNo: 'BF389DY94',
        marks: { q1: '05', q2: '05', q3: '05', q4: '05', q5: '05', q6: '01', q7: '05', q8: '05' }
    },
    {
        id: '4',
        serial: '4',
        bookletNo: 'BF389DY95',
        marks: { q1: '05', q2: '05', q3: '05', q4: '05', q5: '05', q6: '02', q7: '05', q8: '05' }
    }
];

function getParsedMark(value) {
    if (value === '' || value == null) {
        return 0;
    }

    const parsed = Number.parseInt(value, 10);
    return Number.isNaN(parsed) ? 0 : parsed;
}

export default class MarksEvaluation extends LightningElement {
    sectionGroups = SECTION_GROUPS;
    questionColumns = QUESTION_COLUMNS;

    @track rows = ROWS;
    isSaveModalOpen = false;
    isSaveSuccessful = true;

    get tableRows() {
        return this.rows.map((row) => ({
            ...row,
            cells: this.questionColumns.map((question) => {
                const value = row.marks[question.key] || '';
                const parsed = getParsedMark(value);
                const isEmpty = value === '';
                const hasError = !isEmpty && parsed > MAX_MARK_PER_QUESTION;
                const showSuccess = !isEmpty && !hasError;

                return {
                    key: `${row.id}-${question.key}`,
                    questionKey: question.key,
                    label: `${row.bookletNo} ${question.label}`,
                    value,
                    showSuccess,
                    showError: hasError,
                    inputClass: hasError ? 'mark-input mark-input-error' : 'mark-input'
                };
            }),
            totalMarks: this.calculateRowTotal(row)
        }));
    }

    get hasLimitError() {
        return this.rows.some((row) =>
            this.questionColumns.some((question) => getParsedMark(row.marks[question.key]) > MAX_MARK_PER_QUESTION)
        );
    }

    handleMarkInput(event) {
        const { rowId, questionKey } = event.target.dataset;
        const typedValue = event.target.value || '';
        const cleanedValue = typedValue.replace(/\D/g, '').slice(0, 2);

        this.rows = this.rows.map((row) => {
            if (row.id !== rowId) {
                return row;
            }

            return {
                ...row,
                marks: {
                    ...row.marks,
                    [questionKey]: cleanedValue
                }
            };
        });
    }

    handleSave() {
        this.isSaveSuccessful = !this.hasLimitError;
        this.isSaveModalOpen = true;
    }

    closeSaveModal() {
        this.isSaveModalOpen = false;
    }

    get saveIconClass() {
        return this.isSaveSuccessful ? 'save-check save-check-success' : 'save-check save-check-error';
    }

    get saveIconText() {
        return this.isSaveSuccessful ? '✓' : '!';
    }

    get saveModalMessage() {
        return this.isSaveSuccessful
            ? 'Marks updated successfully!'
            : 'Please correct highlighted marks before saving';
    }

    calculateRowTotal(row) {
        const sectionA = this.sumMarks(row, ['q1', 'q2', 'q3']);
        const sectionBValues = ['q4', 'q5', 'q6']
            .map((key) => getParsedMark(row.marks[key]))
            .sort((first, second) => second - first);
        const sectionB = (sectionBValues[0] || 0) + (sectionBValues[1] || 0);
        const sectionC = this.sumMarks(row, ['q7', 'q8']);

        return String(sectionA + sectionB + sectionC).padStart(2, '0');
    }

    sumMarks(row, keys) {
        return keys.reduce((sum, key) => sum + getParsedMark(row.marks[key]), 0);
    }
}