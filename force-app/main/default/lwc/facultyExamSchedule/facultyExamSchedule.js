import { LightningElement, track } from 'lwc';

const SCHEDULE_ROWS = [
    {
        id: '1',
        examType: '2022-Jan-BBA-Term I',
        className: 'ECE-Sem I',
        exam: 'End semester exam',
        course: 'Mastering digital electronics',
        date: '23-06-2025',
        time: '23-06-2025',
        venue: 'Gandhi hall'
    },
    {
        id: '2',
        examType: '2022-Jan-BBA-Term I',
        className: 'ECE-Sem I',
        exam: 'End semester exam',
        course: 'Basics of Mechanical Engineering',
        date: '20-06-2025',
        time: '20-06-2025',
        venue: 'Class 301'
    },
    {
        id: '3',
        examType: '2022-Jan-BBA-Term I',
        className: 'ECE-Sem I',
        exam: 'End semester exam',
        course: 'Basics of Mechanical Engineering',
        date: '19-06-2025',
        time: '19-06-2025',
        venue: 'Class 304'
    },
    {
        id: '4',
        examType: '2022-Jan-BBA-Term I',
        className: 'ECE-Sem I',
        exam: 'End semester exam',
        course: 'Basics of Mechanical Engineering',
        date: '16-06-2025',
        time: '16-06-2025',
        venue: 'Rajaji hall'
    },
    {
        id: '5',
        examType: '2022-Jan-BBA-Term I',
        className: 'ECE-Sem I',
        exam: 'End semester exam',
        course: 'Basics of Mechanical Engineering',
        date: '12-06-2025',
        time: '12-06-2025',
        venue: 'Gandhi hall'
    },
    {
        id: '6',
        examType: '2022-Jan-BBA-Term I',
        className: 'ECE-Sem I',
        exam: 'End semester exam',
        course: 'Basics of Mechanical Engineering',
        date: '10-06-2025',
        time: '10-06-2025',
        venue: 'Gandhi hall'
    },
    {
        id: '7',
        examType: '2022-Jan-BBA-Term I',
        className: 'ECE-Sem I',
        exam: 'End semester exam',
        course: 'Basics of Mechanical Engineering',
        date: '07-06-2025',
        time: '07-06-2025',
        venue: 'Gandhi hall'
    },
    {
        id: '8',
        examType: '2022-Jan-BBA-Term I',
        className: 'ECE-Sem I',
        exam: 'End semester exam',
        course: 'Basics of Mechanical Engineering',
        date: '05-06-2025',
        time: '05-06-2025',
        venue: 'Gandhi hall'
    },
    {
        id: '9',
        examType: '2022-Jan-BBA-Term I',
        className: 'ECE-Sem I',
        exam: 'End semester exam',
        course: 'Basics of Mechanical Engineering',
        date: '01-06-2025',
        time: '01-06-2025',
        venue: 'Gandhi hall'
    },
    {
        id: '10',
        examType: '2022-Jan-BBA-Term I',
        className: 'ECE-Sem I',
        exam: 'End semester exam',
        course: 'Basics of Mechanical Engineering',
        date: '29-05-2025',
        time: '29-05-2025',
        venue: 'Gandhi hall'
    },
    {
        id: '11',
        examType: '2022-Jan-BBA-Term I',
        className: 'ECE-Sem I',
        exam: 'Mid semester exam',
        course: 'Engineering Mathematics',
        date: '24-05-2025',
        time: '24-05-2025',
        venue: 'Class 210'
    },
    {
        id: '12',
        examType: '2022-Jan-BBA-Term I',
        className: 'ECE-Sem I',
        exam: 'Mid semester exam',
        course: 'Applied Physics',
        date: '21-05-2025',
        time: '21-05-2025',
        venue: 'Class 212'
    },
    {
        id: '13',
        examType: '2022-Jan-BBA-Term I',
        className: 'ECE-Sem I',
        exam: 'Mid semester exam',
        course: 'Engineering Drawing',
        date: '18-05-2025',
        time: '18-05-2025',
        venue: 'Drawing hall'
    }
];

const ROWS_PER_PAGE_OPTIONS = [
    { label: '5', value: '5' },
    { label: '10', value: '10' },
    { label: '20', value: '20' }
];

export default class FacultyExamSchedule extends LightningElement {
    @track selectedYear = '';
    @track selectedExamType = '';
    @track selectedCourse = '';
    @track selectedClassName = '';
    @track searchTerm = '';
    @track rowsPerPage = '10';
    @track currentPage = 1;

    scheduleRows = SCHEDULE_ROWS;

    get yearOptions() {
        const years = [...new Set(this.scheduleRows.map((row) => row.date.split('-')[2]))].sort((a, b) => b - a);
        const options = [{ label: 'Year', value: '' }, ...years.map((year) => ({ label: year, value: year }))];
        return this.withSelectedOption(options, this.selectedYear);
    }

    get examTypeOptions() {
        return this.withSelectedOption(this.getOptions('examType', 'Exam type'), this.selectedExamType);
    }

    get courseOptions() {
        return this.withSelectedOption(this.getOptions('course', 'Course'), this.selectedCourse);
    }

    get classOptions() {
        return this.withSelectedOption(this.getOptions('className', 'Class'), this.selectedClassName);
    }

    get rowOptions() {
        return this.withSelectedOption(ROWS_PER_PAGE_OPTIONS, this.rowsPerPage);
    }

    get filteredRows() {
        const query = this.searchTerm.trim().toLowerCase();
        return this.scheduleRows.filter((row) => {
            const matchesYear = !this.selectedYear || row.date.endsWith(this.selectedYear);
            const matchesExamType = !this.selectedExamType || row.examType === this.selectedExamType;
            const matchesCourse = !this.selectedCourse || row.course === this.selectedCourse;
            const matchesClass = !this.selectedClassName || row.className === this.selectedClassName;
            const matchesSearch =
                !query ||
                [
                    row.examType,
                    row.className,
                    row.exam,
                    row.course,
                    row.date,
                    row.time,
                    row.venue
                ]
                    .join(' ')
                    .toLowerCase()
                    .includes(query);

            return matchesYear && matchesExamType && matchesCourse && matchesClass && matchesSearch;
        });
    }

    get paginatedRows() {
        const start = (this.currentPage - 1) * Number(this.rowsPerPage);
        return this.filteredRows.slice(start, start + Number(this.rowsPerPage));
    }

    get hasPaginatedRows() {
        return this.paginatedRows.length > 0;
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.filteredRows.length / Number(this.rowsPerPage)));
    }

    get startRow() {
        if (!this.filteredRows.length) {
            return 0;
        }
        return (this.currentPage - 1) * Number(this.rowsPerPage) + 1;
    }

    get endRow() {
        return Math.min(this.currentPage * Number(this.rowsPerPage), this.filteredRows.length);
    }

    get paginationLabel() {
        if (!this.filteredRows.length) {
            return '0-0 of 0';
        }
        return `${this.startRow}-${this.endRow} of ${this.filteredRows.length}`;
    }

    get disablePrevious() {
        return this.currentPage <= 1;
    }

    get disableNext() {
        return this.currentPage >= this.totalPages;
    }

    handleYearChange(event) {
        this.selectedYear = this.getValue(event);
        this.resetToFirstPage();
    }

    handleExamTypeChange(event) {
        this.selectedExamType = this.getValue(event);
        this.resetToFirstPage();
    }

    handleCourseChange(event) {
        this.selectedCourse = this.getValue(event);
        this.resetToFirstPage();
    }

    handleClassChange(event) {
        this.selectedClassName = this.getValue(event);
        this.resetToFirstPage();
    }

    handleSearch(event) {
        this.searchTerm = this.getValue(event);
        this.resetToFirstPage();
    }

    handleRowsPerPageChange(event) {
        this.rowsPerPage = this.getValue(event);
        this.resetToFirstPage();
    }

    handlePreviousPage() {
        if (this.currentPage > 1) {
            this.currentPage -= 1;
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage += 1;
        }
    }

    getOptions(fieldName, placeholder) {
        const values = [...new Set(this.scheduleRows.map((row) => row[fieldName]))];
        return [{ label: placeholder, value: '' }, ...values.map((value) => ({ label: value, value }))];
    }

    resetToFirstPage() {
        this.currentPage = 1;
    }

    getValue(event) {
        return event?.detail?.value ?? event?.target?.value ?? '';
    }

    withSelectedOption(options, selectedValue) {
        return options.map((option) => ({
            ...option,
            selected: option.value === selectedValue
        }));
    }
}