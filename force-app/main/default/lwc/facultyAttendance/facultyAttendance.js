import { LightningElement, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import communityBasePath from '@salesforce/community/basePath';
import chartjs from '@salesforce/resourceUrl/chartjs';
import LeaveBgImg from '@salesforce/resourceUrl/LeaveBgImg';
import rightArrow from '@salesforce/resourceUrl/RightArrow';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';

const BAR_LABELS = [
    ['Mechanical', 'Engineering - I'],
    ['Computer', 'Engineering - II'],
    ['Chemical', 'Engineering - III'],
    ['Aerospace', 'Engineering - I'],
    ['Biomedical', 'Engineering - II'],
    ['Environmental', 'Engineering - III'],
    ['Industrial', 'Engineering - I']
];
const MOBILE_BAR_LABELS = ['Mech-I', 'Comp-II', 'Chem-III', 'Aero-I', 'Bio-II', 'Env-III', 'Ind-I'];
const BAR_VALUES = [55, 86, 23, 68, 39, 95, 14];
const BAR_COLORS = ['#5F81ED', '#6E8EEB', '#E5B1B1', '#6E8EEB', '#F0DCA8', '#6B89E5', '#E4A7A7'];
const BAR_GUIDE = 50;

const LINE_LABELS = ['08/03 (Mon)', '09/03 (Tue)', '10/03 (Wed)', '11/03 (Thur)', '12/03 (Fri)', '13/03 (Sat)', '14/03 (Mon)'];
const MOBILE_LINE_LABELS = ['08/03', '09/03', '10/03', '11/03', '12/03', '13/03', '14/03'];
const LINE_VALUES = [72, 67, 67, 60, 55, 49, 40];
const LINE_GUIDE = 60;

const guideLinePlugin = {
    id: 'guideLinePlugin',
    afterDraw(chart, _args, options) {
        const yScale = chart.scales.y;
        const { ctx, chartArea } = chart;
        if (!yScale || !chartArea || typeof options?.value !== 'number') {
            return;
        }

        const y = yScale.getPixelForValue(options.value);
        ctx.save();
        ctx.beginPath();
        ctx.setLineDash([9, 9]);
        ctx.lineWidth = 1.4;
        ctx.strokeStyle = '#8C949F';
        ctx.moveTo(chartArea.left, y);
        ctx.lineTo(chartArea.right, y);
        ctx.stroke();
        ctx.restore();
    }
};

export default class FacultyAttendance extends LightningElement {
    barChart;
    lineChart;
    chartJsLoaded = false;
    errorMessage = '';
    organizationDefaults = {};

    selectedSemester = 'semester-1';
    selectedCourse = 'course-1';
    isSemesterDropdownOpen = false;
    wasSmallScreen;

    semesterOptions = [
        { label: 'Semester 1', value: 'semester-1' },
        { label: 'Semester 2', value: 'semester-2' },
        { label: 'Semester 3', value: 'semester-3' }
    ];

    courseOptions = [
        { label: '<Course1>', value: 'course-1' },
        { label: '<Course2>', value: 'course-2' },
        { label: '<Course3>', value: 'course-3' }
    ];

    get semesterOptionsForDropdown() {
        return this.semesterOptions.map((option) => ({
            ...option,
            isCurrent: option.value === 'semester-1'
        }));
    }

    get selectedSemesterLabel() {
        const current = this.semesterOptions.find((option) => option.value === this.selectedSemester);
        return current ? current.label : '';
    }

    get selectedSemesterIsCurrent() {
        return this.selectedSemester === 'semester-1';
    }

    get courseSelectOptions() {
        return this.courseOptions.map((option) => ({
            ...option,
            selected: option.value === this.selectedCourse
        }));
    }

    todayAttendances = [
        {
            id: 'att-1',
            subject: 'Applied Physics',
            code: 'KJ9844763',
            program: 'B.Tech., Electronics & Engineering',
            time: '11:00 AM to 12:00 AM',
            status: 'Pending',
            statusClass: 'status-pill status-pending'
        },
        {
            id: 'att-2',
            subject: 'Business English',
            code: 'KJ9844763',
            program: 'B.Tech., Electronics & Engineering',
            time: '11:00 AM to 12:00 AM',
            status: 'Attendance Marked',
            statusClass: 'status-pill status-marked'
        },
        {
            id: 'att-3',
            subject: 'Basics of Chemistry',
            code: 'KJ9844763',
            program: 'B.Tech., Electronics & Engineering',
            time: '11:00 AM to 12:00 AM',
            status: 'Attendance Marked',
            statusClass: 'status-pill status-marked'
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
        this.applyOrganizationTheme();
        if (this.chartJsLoaded) {
            return;
        }

        this.chartJsLoaded = true;
        this.initializeCharts();
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this.handleWindowResize);
        this.destroyCharts();
    }

    handleWindowResize = () => {
        const isNowSmallScreen = this.isSmallScreen;
        if (isNowSmallScreen === this.wasSmallScreen) {
            return;
        }

        this.wasSmallScreen = isNowSmallScreen;
        if (this.chartJsLoaded && window.Chart) {
            this.renderBarChart();
            this.renderLineChart();
        }
    };

    async initializeCharts() {
        try {
            await this.loadChartLibrary();
            this.renderBarChart();
            this.renderLineChart();
        } catch {
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

    renderBarChart() {
        const canvas = this.template.querySelector('canvas.attendance-bar-chart');
        if (!canvas || !window.Chart) {
            this.errorMessage = 'Chart is unavailable.';
            return;
        }

        if (this.barChart) {
            this.barChart.destroy();
        }

        const context = canvas.getContext('2d');
        if (!context) {
            this.errorMessage = 'Chart canvas is unavailable.';
            return;
        }

        this.barChart = new window.Chart(context, {
            type: 'bar',
            data: {
                labels: this.isSmallScreen ? MOBILE_BAR_LABELS : BAR_LABELS,
                datasets: [
                    {
                        data: BAR_VALUES,
                        backgroundColor: BAR_COLORS,
                        borderSkipped: false,
                        borderRadius: 10,
                        barThickness: this.isSmallScreen ? 32 : 76
                    }
                ]
            },
            plugins: [guideLinePlugin],
            options: {
                responsive: true,
                maintainAspectRatio: false,
                layout: {
                    padding: {
                        top: 10,
                        right: 8,
                        left: 8,
                        bottom: 0
                    }
                },
                plugins: {
                    legend: { display: false },
                    guideLinePlugin: {
                        value: BAR_GUIDE
                    },
                    tooltip: {
                        enabled: true,
                        displayColors: false,
                        backgroundColor: '#ffffff',
                        borderColor: '#3061ff',
                        borderWidth: 2,
                        cornerRadius: 12,
                        caretSize: 8,
                        caretPadding: 10,
                        titleAlign: 'center',
                        bodyAlign: 'center',
                        titleColor: '#3b4250',
                        bodyColor: '#687181',
                        titleFont: {
                            size: 14,
                            weight: '600'
                        },
                        bodyFont: {
                            size: 14,
                            weight: '500'
                        },
                        padding: {
                            top: 10,
                            right: 16,
                            bottom: 10,
                            left: 16
                        },
                        callbacks: {
                            title(items) {
                                const rawLabel = items?.[0]?.label;
                                const labelText = Array.isArray(rawLabel) ? rawLabel.join(' ') : rawLabel;
                                const value = items?.[0]?.raw;
                                return `${labelText}: ${value}%`;
                            },
                            label() {
                                return 'Attendance percentage';
                            }
                        }
                    }
                },
                interaction: {
                    mode: 'index',
                    intersect: false
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100,
                        grid: {
                            color: '#DFE4EC'
                        },
                        ticks: {
                            stepSize: 25,
                            color: '#5D6471',
                            font: { size: this.isSmallScreen ? 12 : 16 },
                            callback(value) {
                                if (value === 0) {
                                    return '0';
                                }
                                if (value === 100) {
                                    return '100%';
                                }
                                return value === 50 ? '50%' : '';
                            }
                        },
                        border: {
                            display: false
                        }
                    },
                    x: {
                        grid: {
                            color: '#DFE4EC'
                        },
                        ticks: {
                            color: '#484F5C',
                            font: {
                                size: this.isSmallScreen ? 12 : 14
                            },
                            autoSkip: true,
                            maxTicksLimit: this.isSmallScreen ? 4 : 7,
                            maxRotation: 0
                        },
                        border: {
                            display: false
                        }
                    }
                }
            }
        });
    }

    renderLineChart() {
        const canvas = this.template.querySelector('canvas.attendance-line-chart');
        if (!canvas || !window.Chart) {
            this.errorMessage = 'Chart is unavailable.';
            return;
        }

        if (this.lineChart) {
            this.lineChart.destroy();
        }

        const context = canvas.getContext('2d');
        if (!context) {
            this.errorMessage = 'Chart canvas is unavailable.';
            return;
        }

        this.lineChart = new window.Chart(context, {
            type: 'line',
            data: {
                labels: this.isSmallScreen ? MOBILE_LINE_LABELS : LINE_LABELS,
                datasets: [
                    {
                        data: LINE_VALUES,
                        tension: 0,
                        borderWidth: 2.2,
                        segment: {
                            borderColor: (segmentContext) => (segmentContext.p0DataIndex >= 4 ? '#E8BC49' : '#6A8CF1')
                        },
                        pointRadius: this.isSmallScreen ? 3 : 4,
                        pointHoverRadius: this.isSmallScreen ? 3 : 4,
                        pointBackgroundColor: ['#6A8CF1', '#6A8CF1', '#6A8CF1', '#6A8CF1', '#6A8CF1', '#E8BC49', '#E8BC49'],
                        pointBorderWidth: 0,
                        fill: false
                    }
                ]
            },
            plugins: [guideLinePlugin],
            options: {
                responsive: true,
                maintainAspectRatio: false,
                layout: {
                    padding: {
                        top: 10,
                        right: 8,
                        left: 8,
                        bottom: 0
                    }
                },
                plugins: {
                    legend: { display: false },
                    guideLinePlugin: {
                        value: LINE_GUIDE
                    },
                    tooltip: {
                        enabled: true,
                        displayColors: false,
                        backgroundColor: '#ffffff',
                        borderColor: '#3061ff',
                        borderWidth: 2,
                        cornerRadius: 12,
                        caretSize: 8,
                        caretPadding: 10,
                        titleAlign: 'center',
                        bodyAlign: 'center',
                        titleColor: '#3b4250',
                        bodyColor: '#687181',
                        titleFont: {
                            size: 14,
                            weight: '600'
                        },
                        bodyFont: {
                            size: 14,
                            weight: '500'
                        },
                        padding: {
                            top: this.isSmallScreen ? 8 : 10,
                            right: this.isSmallScreen ? 12 : 16,
                            bottom: this.isSmallScreen ? 8 : 10,
                            left: this.isSmallScreen ? 12 : 16
                        },
                        callbacks: {
                            title(items) {
                                const first = items?.[0];
                                const rawLabel = first?.label || '';
                                const match = rawLabel.match(/\(([^)]+)\)/);
                                const day = match ? match[1] : rawLabel;
                                return `${day}: ${first?.raw}%`;
                            },
                            label(context) {
                                const totalStudents = 75;
                                const presentStudents = Math.round((context.raw / 100) * totalStudents);
                                return `${presentStudents}/${totalStudents} students present`;
                            }
                        }
                    }
                },
                interaction: {
                    mode: 'index',
                    intersect: false
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100,
                        grid: {
                            color: '#DFE4EC'
                        },
                        ticks: {
                            stepSize: 20,
                            color: '#5D6471',
                            font: { size: this.isSmallScreen ? 12 : 16 },
                            callback(value) {
                                if (value === 0) {
                                    return '0';
                                }
                                return value % 20 === 0 ? `${value}%` : '';
                            }
                        },
                        border: {
                            display: false
                        }
                    },
                    x: {
                        grid: {
                            color: '#DFE4EC'
                        },
                        ticks: {
                            color: '#646C79',
                            font: {
                                size: this.isSmallScreen ? 12 : 16
                            },
                            maxRotation: this.isSmallScreen ? 50 : 0,
                            minRotation: this.isSmallScreen ? 50 : 0
                        },
                        border: {
                            display: false
                        }
                    }
                }
            }
        });
    }

    destroyCharts() {
        if (this.barChart) {
            this.barChart.destroy();
            this.barChart = null;
        }
        if (this.lineChart) {
            this.lineChart.destroy();
            this.lineChart = null;
        }
    }

    handleSemesterChange(event) {
        const nextValue = event?.target?.value || event?.currentTarget?.dataset?.value;
        if (nextValue) {
            this.selectedSemester = nextValue;
        }
    }

    handleSemesterDropdownToggle(event) {
        event.stopPropagation();
        this.isSemesterDropdownOpen = !this.isSemesterDropdownOpen;
    }

    handleSemesterOptionSelect(event) {
        event.stopPropagation();
        this.handleSemesterChange(event);
        this.isSemesterDropdownOpen = false;
    }

    closeSemesterDropdown() {
        this.isSemesterDropdownOpen = false;
    }

    handleCourseChange(event) {
        this.selectedCourse = event.target.value;
    }

    handleViewHistory() {
        window.open(this.buildCommunityUrl('attendance/attendance-history'), '_self');
    }

    handleTodayAttendanceClick() {
        window.open(this.buildCommunityUrl('attendance/attendance-history/todays-attendance'), '_self');
    }

    handleViewLeaveRequests() {
        window.open(this.buildCommunityUrl('attendance/attendance-leave-history'), '_self');
    }

    get leaveCardStyle() {
        return `background-image: url(${LeaveBgImg});`;
    }

    get rightArrowIconUrl() {
        return rightArrow;
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