import { LightningElement } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import communityBasePath from '@salesforce/community/basePath';
import chartjs from '@salesforce/resourceUrl/chartjs';
import rightArrow from '@salesforce/resourceUrl/RightArrow';

const GRADE_LABELS = ['Grade O', 'Grade A', 'Grade B', 'Grade C', 'Grade D', 'Grade E', 'Grade F'];
const GRADE_DISTRIBUTION = [58, 88, 23, 70, 58, 97, 14];
const BAR_COLORS = ['#6c86df', '#a3b1dd', '#3d63dd', '#6c86df', '#6c86df', '#a3b1dd', '#3d63dd'];
const GUIDE_LINE_VALUE = 62;
const guideLinePlugin = {
    id: 'guideLinePlugin',
    beforeDatasetsDraw(chart) {
        const yScale = chart.scales.y;
        const { ctx, chartArea } = chart;
        if (!yScale || !chartArea) {
            return;
        }

        const y = yScale.getPixelForValue(GUIDE_LINE_VALUE);
        ctx.save();
        ctx.beginPath();
        ctx.setLineDash([8, 8]);
        ctx.lineWidth = 1.5;
        ctx.strokeStyle = '#9ba1ad';
        ctx.moveTo(chartArea.left, y);
        ctx.lineTo(chartArea.right, y);
        ctx.stroke();
        ctx.restore();
    }
};

export default class FacultyExams extends LightningElement {
    chart;
    chartJsLoaded = false;
    rightArrowUrl = rightArrow;
    errorMessage = '';
    wasSmallScreen;
    showRequestModal = false;
    showAcceptModal = false;
    selectedScheduleId = null;
    substituteReason = '';
    selectedClass = 'ece-sem-vi';
    selectedSemester = 'semester-1';

    classOptions = [
        { label: 'ECE- Sem VI', value: 'ece-sem-vi' },
        { label: 'CSE- Sem VI', value: 'cse-sem-vi' },
        { label: 'ME- Sem VI', value: 'me-sem-vi' }
    ];

    semesterOptions = [
        { label: 'Semester 1', value: 'semester-1' },
        { label: 'Semester 2', value: 'semester-2' },
        { label: 'Semester 3', value: 'semester-3' }
    ];

    invigilationSchedules = [
        {
            id: 'inv-1',
            room: 'Room no. 312',
            dateTime: '24-05-2025 | 11:00 am',
            duration: '2 Hrs',
            examTitle: 'End semester examination-2025',
            subject: 'Basics of Civil engineering',
            semester: 'ECE-Sem VI',
            showActions: true
        },
        {
            id: 'inv-2',
            room: 'Room no. 312',
            dateTime: '24-05-2025 | 11:00 am',
            duration: '2 Hrs',
            examTitle: 'End semester examination-2025',
            subject: 'Basics of Civil engineering',
            semester: 'ECE-Sem VI',
            showSubstituteRequested: true
        }
    ];

    questionPapers = [
        {
            id: 'qp-1',
            title: 'Microelectronics',
            type: 'Quarterly exam',
            semester: 'ECE - II'
        }
    ];

    evaluationRequests = [
        {
            id: 'eval-1',
            title: 'Mastering Digital Electro...',
            type: 'Quarterly exam',
            semester: 'ECE - II'
        },
        {
            id: 'eval-2',
            title: 'Soft skill analysis',
            type: 'Quarterly exam',
            semester: 'ECE - II'
        }
    ];

    upcomingExams = [
        {
            id: 'up-1',
            title: 'Applied Physics',
            semester: 'ECE - Sem II',
            duration: '2:30 Hours',
            time: '09:00 AM'
        },
        {
            id: 'up-2',
            title: 'Digital Signal Processing',
            semester: 'ECE - Sem I',
            duration: '2:30 Hours',
            time: '09:00 AM'
        },
        {
            id: 'up-3',
            title: 'Circuits and Electronics',
            semester: 'ECE - Sem III',
            duration: '2:30 Hours',
            time: '09:00 AM'
        }
    ];

    get isSmallScreen() {
        return window.innerWidth <= 768;
    }

    connectedCallback() {
        this.wasSmallScreen = this.isSmallScreen;
        window.addEventListener('resize', this.handleWindowResize);
    }

    renderedCallback() {
        this.syncFilterSelections();
        if (this.chartJsLoaded) {
            return;
        }
        this.chartJsLoaded = true;
        this.initializeChart();
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this.handleWindowResize);
        this.destroyChart();
    }

    handleWindowResize = () => {
        const isNowSmallScreen = this.isSmallScreen;
        if (isNowSmallScreen === this.wasSmallScreen) {
            return;
        }

        this.wasSmallScreen = isNowSmallScreen;
        if (this.chartJsLoaded && window.Chart) {
            this.renderChart();
        }
    };

    async initializeChart() {
        try {
            await this.loadChartLibrary();
            this.renderChart();
        } catch (error) {
            this.errorMessage = 'Unable to load chart library. Verify static resource "chartjs".';
        }
    }

    async loadChartLibrary() {
        if (window.Chart) {
            return;
        }

        const scriptCandidates = [
            chartjs,
            `${chartjs}/chart.umd.min.js`,
            `${chartjs}/chart.umd.js`,
            `${chartjs}/dist/chart.umd.min.js`,
            `${chartjs}/dist/chart.umd.js`,
            `${chartjs}/Chart.min.js`,
            `${chartjs}/chart.min.js`
        ];

        for (let index = 0; index < scriptCandidates.length; index += 1) {
            try {
                await loadScript(this, scriptCandidates[index]);
                return;
            } catch (error) {
                if (index === scriptCandidates.length - 1) {
                    throw error;
                }
            }
        }
    }

    renderChart() {
        const canvas = this.template.querySelector('canvas.faculty-exams-chart');
        if (!canvas || !window.Chart) {
            this.errorMessage = 'Chart is unavailable.';
            return;
        }

        this.destroyChart();

        let context;
        try {
            context = canvas.getContext('2d');
        } catch (error) {
            this.errorMessage = 'Chart canvas is unavailable.';
            return;
        }

        if (!context) {
            this.errorMessage = 'Chart canvas is unavailable.';
            return;
        }

        this.chart = new window.Chart(context, {
            type: 'bar',
            data: {
                labels: GRADE_LABELS,
                datasets: [
                    {
                        data: GRADE_DISTRIBUTION,
                        backgroundColor: BAR_COLORS,
                        borderRadius: 8,
                        borderSkipped: false,
                        barThickness: this.isSmallScreen ? 34 : 70
                    }
                ]
            },
            plugins: [guideLinePlugin],
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    title: {
                        display: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100,
                        grid: {
                            color: '#e7eaef'
                        },
                        ticks: {
                            stepSize: 25,
                            color: '#5a6270',
                            callback(value) {
                                if (value === 0) {
                                    return '0';
                                }
                                if (value === 100) {
                                    return '100%';
                                }
                                return value % 50 === 0 ? `${value}%` : '';
                            }
                        },
                        border: {
                            display: false
                        }
                    },
                    x: {
                        grid: {
                            color: '#e7eaef'
                        },
                        ticks: {
                            color: '#404855',
                            font: {
                                size: this.isSmallScreen ? 12 : 16
                            },
                            autoSkip: true,
                            maxRotation: 0,
                            minRotation: 0
                        },
                        border: {
                            display: false
                        }
                    }
                }
            }
        });
    }

    handleClassChange(event) {
        this.selectedClass = event.target.value;
    }

    handleSemesterChange(event) {
        this.selectedSemester = event.target.value;
    }

    openRequestModal(event) {
        this.selectedScheduleId = event.currentTarget.dataset.id;
        this.substituteReason = '';
        this.showAcceptModal = false;
        this.showRequestModal = true;
    }

    openAcceptModal(event) {
        this.selectedScheduleId = event.currentTarget.dataset.id;
        this.showRequestModal = false;
        this.showAcceptModal = true;
    }

    handleReasonChange(event) {
        this.substituteReason = event.target.value;
    }

    submitSubstituteRequest() {
        this.invigilationSchedules = this.invigilationSchedules.map((schedule) => {
            if (schedule.id !== this.selectedScheduleId) {
                return schedule;
            }

            return {
                ...schedule,
                showActions: false,
                showSubstituteRequested: true
            };
        });
        this.closeAllModals();
    }

    confirmAcceptRequest() {
        this.closeAllModals();
    }

    closeAllModals() {
        this.showRequestModal = false;
        this.showAcceptModal = false;
        this.selectedScheduleId = null;
    }

    handleModalContainerClick(event) {
        event.stopPropagation();
    }

    navigateToQuestionPaperSetup() {
        window.open(this.buildCommunityUrl('exams/questionpapers'), '_self');
    }

    navigateToInvigilation() {
        window.open(this.buildCommunityUrl('exams/invigilation'), '_self');
    }

    navigateToEvaluation() {
        window.open(this.buildCommunityUrl('exams/evaluation-requests'), '_self');
    }

    navigateToEvaluationBooklets() {
        window.open(this.buildCommunityUrl('exams/evaluation-requests/booklets'), '_self');
    }

    buildCommunityUrl(path = '') {
        const basePath = communityBasePath || '/';
        const sanitizedPath = path.replace(/^\/+|\/+$/g, '');

        if (basePath === '/') {
            return sanitizedPath ? `/${sanitizedPath}` : '/';
        }

        return sanitizedPath ? `${basePath}/${sanitizedPath}` : basePath;
    }

    syncFilterSelections() {
        const classSelect = this.template.querySelector('.class-select');
        const semesterSelect = this.template.querySelector('.semester-select');

        if (classSelect) {
            classSelect.value = this.selectedClass;
        }
        if (semesterSelect) {
            semesterSelect.value = this.selectedSemester;
        }
    }

    destroyChart() {
        if (this.chart) {
            this.chart.destroy();
            this.chart = null;
        }
    }
}