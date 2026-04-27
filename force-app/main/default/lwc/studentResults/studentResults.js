import { LightningElement, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import communityBasePath from '@salesforce/community/basePath';
import chartjs from '@salesforce/resourceUrl/chartjs';
import eyeIcon from '@salesforce/resourceUrl/eyeIcon';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';
import rightArrow from '@salesforce/resourceUrl/RightArrow';
import MarksBgImage from '@salesforce/resourceUrl/MarksBgImage';

const SEMESTER_LABELS = ['Sem 1', 'Sem 2', 'Sem 3', 'Sem 4', 'Sem 5', 'Sem 6', 'Sem 7', 'Sem 8'];
const SEMESTER_CGPA = [7.5, 8.0, 6.1, 6.2, 6.0, 8.2, null, null];

const MARKS_ROWS = [
    {
        id: '1',
        courseName: 'Network Analysis & Synthesis',
        courseCode: 'ECE101',
        credits: '3',
        creditsEarned: '3',
        compositeScore: '79',
        grade: 'A'
    },
    {
        id: '2',
        courseName: 'Signals & Systems',
        courseCode: 'ECE102',
        credits: '4',
        creditsEarned: '4',
        compositeScore: '79',
        grade: 'B'
    },
    {
        id: '3',
        courseName: 'Human Resource Management',
        courseCode: 'ECE103',
        credits: '3',
        creditsEarned: '3',
        compositeScore: '79',
        grade: 'B'
    },
    {
        id: '4',
        courseName: 'VLSI Design',
        courseCode: 'ECE104',
        credits: '4',
        creditsEarned: '4',
        compositeScore: '79',
        grade: 'A+'
    },
    {
        id: '5',
        courseName: 'Microwave Engineering',
        courseCode: 'ECE105',
        credits: '3',
        creditsEarned: '3',
        compositeScore: '79',
        grade: 'F'
    }
];

const valueTagPlugin = {
    id: 'valueTagPlugin',
    afterDatasetsDraw(chart) {
        const dataset = chart.data?.datasets?.[0];
        const points = chart.getDatasetMeta(0)?.data || [];
        const values = dataset?.data || [];
        const { ctx } = chart;

        ctx.save();
        values.forEach((value, index) => {
            if (typeof value !== 'number') {
                return;
            }

            const point = points[index];
            if (!point) {
                return;
            }

            const label = value.toFixed(1);
            ctx.font = '500 12px system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif';
            const textWidth = ctx.measureText(label).width;
            const boxWidth = Math.max(44, textWidth + 18);
            const boxHeight = 26;
            const x = point.x - boxWidth / 2;
            const y = point.y - 38;

            drawRoundedRect(ctx, x, y, boxWidth, boxHeight, 11);
            ctx.fillStyle = '#ffffff';
            ctx.fill();
            ctx.strokeStyle = '#cfd6e2';
            ctx.lineWidth = 1;
            ctx.stroke();

            ctx.fillStyle = '#626a79';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(label, point.x, y + boxHeight / 2);
        });
        ctx.restore();
    }
};

function drawRoundedRect(ctx, x, y, width, height, radius) {
    const safeRadius = Math.min(radius, width / 2, height / 2);
    ctx.beginPath();
    ctx.moveTo(x + safeRadius, y);
    ctx.lineTo(x + width - safeRadius, y);
    ctx.quadraticCurveTo(x + width, y, x + width, y + safeRadius);
    ctx.lineTo(x + width, y + height - safeRadius);
    ctx.quadraticCurveTo(x + width, y + height, x + width - safeRadius, y + height);
    ctx.lineTo(x + safeRadius, y + height);
    ctx.quadraticCurveTo(x, y + height, x, y + height - safeRadius);
    ctx.lineTo(x, y + safeRadius);
    ctx.quadraticCurveTo(x, y, x + safeRadius, y);
    ctx.closePath();
}

export default class StudentResults extends LightningElement {
    chartJsLoaded = false;
    semesterChart;
    organizationDefaults = {};
    selectedSemester = 'semester1';
    isDropdownOpen = false;

    semesterOptions = [
        { label: 'Semester 1', value: 'semester1', isCurrent: true },
        { label: 'Semester 2', value: 'semester2', isCurrent: false },
        { label: 'Semester 3', value: 'semester3', isCurrent: false }
    ];

    get marksRows() {
        return MARKS_ROWS.map((row) => ({
            ...row,
            gradeClass: row.grade === 'F' ? 'grade-cell grade-fail' : 'grade-cell'
        }));
    }

    get selectedSemesterLabel() {
        const match = this.semesterOptions.find((o) => o.value === this.selectedSemester);
        return match ? match.label : '';
    }

    get selectedSemesterIsCurrent() {
        const match = this.semesterOptions.find((o) => o.value === this.selectedSemester);
        return match ? match.isCurrent : false;
    }

    get eyeIconUrl() {
        return eyeIcon;
    }

    get rightArrowUrl() {
        return rightArrow;
    }

    get marksBgImageUrl() {
        return MarksBgImage;
    }
    

    renderedCallback() {
        this.applyOrganizationTheme();
        if (this.chartJsLoaded) {
            return;
        }

        this.chartJsLoaded = true;
        this.initializeChart();
    }

    disconnectedCallback() {
        if (this.semesterChart) {
            this.semesterChart.destroy();
            this.semesterChart = null;
        }
    }

    async initializeChart() {
        try {
            await this.loadChartLibrary();
            this.renderSemesterChart();
        } catch {
            // Keep the rest of the screen usable if chart resource fails.
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

        await this.loadChartCandidate(scriptCandidates, 0);
    }

    async loadChartCandidate(scriptCandidates, index) {
        if (index >= scriptCandidates.length) {
            throw new Error('Failed to load chartjs static resource.');
        }

        try {
            await loadScript(this, scriptCandidates[index]);
        } catch {
            await this.loadChartCandidate(scriptCandidates, index + 1);
        }
    }

    renderSemesterChart() {
        const canvas = this.template.querySelector('canvas.semester-line-chart');
        if (!canvas || !window.Chart) {
            return;
        }

        if (this.semesterChart) {
            this.semesterChart.destroy();
        }

        const context = canvas.getContext('2d');
        if (!context) {
            return;
        }

        this.semesterChart = new window.Chart(context, {
            type: 'line',
            data: {
                labels: SEMESTER_LABELS,
                datasets: [
                    {
                        data: SEMESTER_CGPA,
                        borderColor: '#69AD73',
                        borderWidth: 2.2,
                        tension: 0.42,
                        fill: false,
                        spanGaps: false,
                        pointRadius: (ctx) => (ctx.raw === null ? 0 : 4),
                        pointHoverRadius: (ctx) => (ctx.raw === null ? 0 : 4),
                        pointBackgroundColor: '#8BC08F',
                        pointBorderWidth: 0
                    }
                ]
            },
            plugins: [valueTagPlugin],
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: { enabled: false }
                },
                layout: {
                    padding: {
                        top: 26,
                        right: 6,
                        left: 4,
                        bottom: 0
                    }
                },
                scales: {
                    y: {
                        min: 0,
                        max: 10,
                        ticks: {
                            stepSize: 2,
                            color: '#7a8190',
                            font: { size: 12 }
                        },
                        grid: { display: false },
                        border: { display: false }
                    },
                    x: {
                        ticks: {
                            color: '#6c7484',
                            font: { size: 14 },
                            maxRotation: 0,
                            minRotation: 0
                        },
                        grid: {
                            color: '#e5e9f0',
                            borderDash: [4, 4],
                            drawTicks: false
                        },
                        border: { display: false }
                    }
                }
            }
        });
    }

    handleDropdownToggle(event) {
        event.stopPropagation();
        this.isDropdownOpen = !this.isDropdownOpen;
    }

    handleOptionSelect(event) {
        event.stopPropagation();
        this.selectedSemester = event.currentTarget.dataset.value;
        this.isDropdownOpen = false;
    }

    closeDropdown() {
        this.isDropdownOpen = false;
    }

    handleViewAllGradeCards() {
        window.open(this.buildCommunityUrl('student-results/grade-cards'), '_self');
    }

    handleMarksBreakdownClick() {
        window.open(this.buildCommunityUrl('student-results/marksbreakdown'), '_self');
    }




    buildCommunityUrl(path = '') {
        const basePath = communityBasePath || '/';
        const sanitizedPath = path.replace(/^\/+|\/+$/g, '');

        if (basePath === '/') {
            return sanitizedPath ? `/${sanitizedPath}` : '/';
        }

        return sanitizedPath ? `${basePath}/${sanitizedPath}` : basePath;
    }

    applyOrganizationTheme() {
        if (!this.template?.host) {
            return;
        }
        const primary = this.organizationDefaults?.primary;
        const secondary = this.organizationDefaults?.secondary;

        if (primary && typeof primary === 'string') {
            this.template.host.style.setProperty('--primary-color', primary);
        }
        if (secondary && typeof secondary === 'string') {
            this.template.host.style.setProperty('--secondary-color', secondary);
        }
    }

    @wire(OrganizationDefaultsApiController)
    wiredOrganizationDefaults({ data }) {
        if (data) {
            this.organizationDefaults = data;
            this.applyOrganizationTheme();
        }
    }
}