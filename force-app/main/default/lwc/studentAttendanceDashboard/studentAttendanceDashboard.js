import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadScript } from 'lightning/platformResourceLoader';
import chartjs from '@salesforce/resourceUrl/chartjs';
import NEEDS_ATTENTION_IMAGE from '@salesforce/resourceUrl/NeedsAttention';
import LEAVE_REQUEST_IMAGE from '@salesforce/resourceUrl/LeaveRequest';

const CURRENT_SEMESTER_VALUE = 'semester1';
const BAR_GUIDE = 50;

const DASHBOARD_SCENARIOS = {
    full: {
        todayDateLabel: '03 Feb 2026',
        todaySessions: [
            { id: 's1', subject: 'Finance-BCA', code: 'BS2923', time: '08:00 AM to 09:00 AM', status: 'Present', statusClass: 'status-pill status-present' },
            { id: 's2', subject: 'Date Structure-BCA', code: 'DS2922', time: '09:00 AM to 10:00 AM', status: 'Absent', statusClass: 'status-pill status-absent' },
            { id: 's3', subject: 'Economics-BCA', code: 'EC2943', time: '10:00 AM to 11:00 AM', status: 'Present', statusClass: 'status-pill status-present' }
        ],
        attentionItems: [
            { id: 'a1', title: 'Mathematics-BCA | DS6922', highlight: 'Attendance below 50%. ', text: 'Attend upcoming classes to stay eligible.' },
            { id: 'a2', title: 'Date Structure-BCA | DS2922', highlight: 'Missed 4 ', text: 'of the last 6 classes. Avoid further absences this month.' },
            { id: 'a3', title: 'Economics-BCA | EC2943', highlight: 'Missed 4 ', text: 'out of 5 classes. Attend the next class to stay on track.' }
        ],
        courseBars: [
            { id: 'b1', percent: 55, tone: 'good', labelTop: 'Applied Physi...', labelBottom: '(RY18372)', showRisk: false },
            { id: 'b2', percent: 82, tone: 'soft', labelTop: 'Chemistry', labelBottom: '(HD9203)', showRisk: false },
            { id: 'b3', percent: 23, tone: 'risk', labelTop: 'Mathematics', labelBottom: '(MS8202)', showRisk: true },
            { id: 'b4', percent: 68, tone: 'soft', labelTop: 'English', labelBottom: '(ES1827)', showRisk: false },
            { id: 'b5', percent: 56, tone: 'soft', labelTop: 'Circuits', labelBottom: '(DH8392)', showRisk: false },
            { id: 'b6', percent: 91, tone: 'soft', labelTop: 'Circuits Lab', labelBottom: '(CL3728)', showRisk: false },
            { id: 'b7', percent: 17, tone: 'risk', labelTop: 'Physics Lab', labelBottom: '(PH3829)', showRisk: true }
        ],
        leaveRequests: [
            { id: 'l1', title: 'Going for a vacation', subtitle: 'Personal leave', date: '21 - 26 Dec 2026', status: 'Approved' },
            { id: 'l2', title: '24th sports day practice', subtitle: 'Exception', date: '02 Jan 2026', status: 'In Review' },
            { id: 'l3', title: 'Annual day - final rehearsal', subtitle: '', date: '', status: 'Rejected' }
        ]
    }
};

function getBarColor(tone) {
    if (tone === 'risk') return '#e7b6bb';
    if (tone === 'good') return '#5f81ed';
    return '#a9bbea';
}

function drawRoundRect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + r);
    ctx.lineTo(x + w, y + h - r);
    ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    ctx.lineTo(x + r, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
    ctx.closePath();
}

const guideLinePlugin = {
    id: 'guideLinePlugin',
    afterDraw(chart, _args, options) {
        const yScale = chart.scales.y;
        const { ctx, chartArea } = chart;
        if (!yScale || !chartArea || typeof options?.value !== 'number') return;
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

const atRiskPlugin = {
    id: 'atRiskPlugin',
    afterDraw(chart) {
        const riskFlags = chart.options.plugins?.atRiskPlugin?.riskFlags;
        if (!riskFlags) return;
        const { ctx, scales } = chart;
        if (!scales.x || !scales.y) return;
        chart.data.datasets[0].data.forEach((value, i) => {
            if (!riskFlags[i]) return;
            const x = scales.x.getPixelForValue(i);
            const y = scales.y.getPixelForValue(value);
            const chipW = 60, chipH = 22;
            const chipX = x - chipW / 2;
            const chipY = y - chipH - 6;
            ctx.save();
            ctx.fillStyle = '#ffffff';
            ctx.strokeStyle = '#f1bfbf';
            ctx.lineWidth = 1;
            drawRoundRect(ctx, chipX, chipY, chipW, chipH, 6);
            ctx.fill();
            ctx.stroke();
            ctx.fillStyle = '#bf555a';
            ctx.font = '600 11px system-ui, -apple-system, sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText('At Risk', x, chipY + chipH / 2);
            ctx.restore();
        });
    }
};

const highlightPlugin = {
    id: 'highlightPlugin',
    afterDraw(chart) {
        const opts = chart.options.plugins?.highlightPlugin;
        if (!opts || typeof opts.value !== 'number') return;
        const { ctx, chartArea, scales } = chart;
        if (!chartArea || !scales.y) return;
        const value = opts.value;
        const y = scales.y.getPixelForValue(value);

        ctx.save();
        ctx.font = '600 12px system-ui, -apple-system, sans-serif';
        const labelText = `${value}%`;
        const textW = ctx.measureText(labelText).width;
        const boxW = textW + 16;
        const boxH = 22;
        const boxX = chartArea.left + 4;
        const boxY = y - boxH / 2;
        const dotX = boxX + boxW + 6;

        // label box
        ctx.fillStyle = '#ffffff';
        ctx.strokeStyle = '#3061ff';
        ctx.lineWidth = 1.5;
        drawRoundRect(ctx, boxX, boxY, boxW, boxH, 5);
        ctx.fill();
        ctx.stroke();

        ctx.fillStyle = '#3061ff';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(labelText, boxX + boxW / 2, y);

        // dot
        ctx.setLineDash([]);
        ctx.fillStyle = '#3061ff';
        ctx.beginPath();
        ctx.arc(dotX, y, 4, 0, Math.PI * 2);
        ctx.fill();

        // dashed line from dot to right edge
        ctx.beginPath();
        ctx.setLineDash([6, 5]);
        ctx.lineWidth = 1.5;
        ctx.strokeStyle = '#3061ff';
        ctx.moveTo(dotX + 5, y);
        ctx.lineTo(chartArea.right, y);
        ctx.stroke();

        ctx.restore();
    }
};

export default class StudentAttendanceDashboard extends NavigationMixin(LightningElement) {
    @api historyPageApiName = 'StudentAttendanceHistory__c';

    selectedSemester = 'semester1';
    selectedScenario = 'full';
    isDropdownOpen = false;
    courseBarChart = null;
    chartJsLoaded = false;

    semesterOptions = [
        { label: 'Semester 1', value: 'semester1', isCurrent: true },
        { label: 'Semester 2', value: 'semester2', isCurrent: false },
        { label: 'Semester 3', value: 'semester3', isCurrent: false }
    ];

    get scenarioData() {
        return DASHBOARD_SCENARIOS[this.selectedScenario] || DASHBOARD_SCENARIOS.full;
    }

    get todayDateLabel() { return this.scenarioData.todayDateLabel; }
    get todaySessions() { return this.scenarioData.todaySessions || []; }
    get attentionItems() { return this.scenarioData.attentionItems || []; }
    get hasTodaySessions() { return this.todaySessions.length > 0; }
    get hasAttentionItems() { return this.attentionItems.length > 0; }
    get hasLeaveItems() { return this.leaveRequests.length > 0; }

    get leaveRequests() {
        return (this.scenarioData.leaveRequests || []).map((leave) => ({
            ...leave,
            statusChipClass: this.resolveLeaveStatusChipClass(leave.status)
        }));
    }

    get needsAttentionImageUrl() { return NEEDS_ATTENTION_IMAGE; }
    get leaveRequestImageUrl() { return LEAVE_REQUEST_IMAGE; }

    get selectedSemesterLabel() {
        const match = this.semesterOptions.find((o) => o.value === this.selectedSemester);
        return match ? match.label : '';
    }

    get showCurrentSemesterChip() {
        return this.selectedSemester === CURRENT_SEMESTER_VALUE;
    }

    connectedCallback() {
        window.addEventListener('resize', this.handleWindowResize);
    }

    renderedCallback() {
        if (this.chartJsLoaded) return;
        this.chartJsLoaded = true;
        this.initializeCourseChart();
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this.handleWindowResize);
        if (this.courseBarChart) {
            this.courseBarChart.destroy();
            this.courseBarChart = null;
        }
    }

    handleWindowResize = () => {
        if (window.Chart && this.chartJsLoaded) {
            this.renderCourseBarChart();
        }
    };

    async initializeCourseChart() {
        try {
            await this.loadChartLibrary();
            this.renderCourseBarChart();
        } catch (e) {
            console.error('Chart.js load failed', e);
        }
    }

    async loadChartLibrary() {
        if (window.Chart) return;
        const candidates = [
            chartjs,
            `${chartjs}/chart.umd.min.js`,
            `${chartjs}/chart.umd.js`,
            `${chartjs}/dist/chart.umd.min.js`,
            `${chartjs}/dist/chart.umd.js`,
            `${chartjs}/Chart.min.js`,
            `${chartjs}/chart.min.js`
        ];
        await this.tryLoadScript(candidates, 0);
    }

    async tryLoadScript(candidates, index) {
        if (index >= candidates.length) throw new Error('Failed to load chartjs');
        try {
            await loadScript(this, candidates[index]);
        } catch {
            await this.tryLoadScript(candidates, index + 1);
        }
    }

    renderCourseBarChart() {
        const canvas = this.template.querySelector('canvas.course-bar-chart');
        if (!canvas || !window.Chart) return;
        if (this.courseBarChart) {
            this.courseBarChart.destroy();
        }
        const ctx = canvas.getContext('2d');
        if (!ctx) return;

        const bars = this.scenarioData.courseBars || [];
        const values = bars.map((b) => b.percent);
        const colors = bars.map((b) => getBarColor(b.tone));
        const riskFlags = bars.map((b) => b.showRisk);
        const labels = bars.map((b) => [b.labelTop, b.labelBottom]);
        const highlightValue = values[0] ?? null;
        const isSmall = window.innerWidth <= 768;

        this.courseBarChart = new window.Chart(ctx, {
            type: 'bar',
            data: {
                labels,
                datasets: [{
                    data: values,
                    backgroundColor: colors,
                    borderSkipped: false,
                    borderRadius: 10,
                    barThickness: isSmall ? 32 : 68
                }]
            },
            plugins: [guideLinePlugin, atRiskPlugin, highlightPlugin],
            options: {
                responsive: true,
                maintainAspectRatio: false,
                layout: { padding: { top: 16, right: 8, left: 8, bottom: 0 } },
                plugins: {
                    legend: { display: false },
                    guideLinePlugin: { value: BAR_GUIDE },
                    atRiskPlugin: { riskFlags },
                    highlightPlugin: { value: highlightValue },
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
                        titleFont: { size: 14, weight: '600' },
                        bodyFont: { size: 14, weight: '500' },
                        padding: { top: 10, right: 16, bottom: 10, left: 16 },
                        callbacks: {
                            title(items) {
                                const rawLabel = items?.[0]?.label;
                                const labelText = Array.isArray(rawLabel) ? rawLabel.join(' ') : rawLabel;
                                return `${labelText}: ${items?.[0]?.raw}%`;
                            },
                            label() { return 'Attendance percentage'; }
                        }
                    }
                },
                interaction: { mode: 'index', intersect: false },
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100,
                        grid: { color: '#DFE4EC' },
                        ticks: {
                            stepSize: 25,
                            color: '#5D6471',
                            font: { size: isSmall ? 12 : 16 },
                            callback(value) {
                                if (value === 0) return '0';
                                if (value === 100) return '100%';
                                return value === 50 ? '50%' : '';
                            }
                        },
                        border: { display: false }
                    },
                    x: {
                        grid: { color: '#DFE4EC' },
                        ticks: {
                            color: '#484F5C',
                            font: { size: isSmall ? 12 : 14 },
                            autoSkip: true,
                            maxTicksLimit: isSmall ? 4 : 7,
                            maxRotation: 0
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
        this.selectedSemester = event.currentTarget.dataset.value;
        this.isDropdownOpen = false;
    }

    closeDropdown() {
        this.isDropdownOpen = false;
    }

    handleAttendanceOverviewClick(event) {
        event.preventDefault();
        event.stopPropagation();

        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: this.historyPageApiName }
        });
    }

    resolveLeaveStatusChipClass(status) {
        if (status === 'Approved') return 'leave-status-pill leave-status-approved';
        if (status === 'In Review') return 'leave-status-pill leave-status-review';
        if (status === 'Rejected') return 'leave-status-pill leave-status-rejected';
        return 'leave-status-pill';
    }
}