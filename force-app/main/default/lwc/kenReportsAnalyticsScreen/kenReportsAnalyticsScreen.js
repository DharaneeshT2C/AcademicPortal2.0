import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCycleOptions from '@salesforce/apex/KenReportsAnalyticsController.getCycleOptions';
import getWindowOptions from '@salesforce/apex/KenReportsAnalyticsController.getWindowOptions';
import getReportData from '@salesforce/apex/KenReportsAnalyticsController.getReportData';

const DEFAULT_REPORT_DATA = Object.freeze({
    totalRegistered: 0,
    totalAllocations: 0,
    occupancyRate: 0,
    pendingApplications: 0,
    totalCapacity: 0,
    occupiedBeds: 0,
    totalAmountCollected: 0,
    pendingAmount: 0,
    categoryRegistrations: [],
    categoryOccupancy: [],
    buildingOccupancy: [],
    allotmentDistribution: [],
    monthlyAllocationTrend: [],
    allotmentPerformanceSummary: []
});

const DISTRIBUTION_COLORS = {
    direct: '#4c56da',
    provisional: '#07b53b',
    other: '#94a3b8'
};
const FINANCE_COLORS = Object.freeze({
    collected: '#16a34a',
    pending: '#f97316'
});
const DONUT_VIEWBOX_SIZE = 180;
const DONUT_CENTER = DONUT_VIEWBOX_SIZE / 2;
const DONUT_RADIUS = 58;
const DONUT_TOOLTIP_RADIUS = 78;
const DONUT_GAP_DEGREES = 2.5;
const TREND_VIEWBOX_WIDTH = 980;
const TREND_VIEWBOX_HEIGHT = 360;
const TREND_MARGIN = Object.freeze({
    top: 22,
    right: 18,
    bottom: 54,
    left: 56
});
const TREND_SERIES = Object.freeze([
    {
        key: 'direct',
        label: 'Direct',
        color: '#4c56da',
        valueField: 'directCount'
    },
    {
        key: 'provisional',
        label: 'Provisional',
        color: '#07b53b',
        valueField: 'provisionalCount'
    },
    {
        key: 'reassignments',
        label: 'Reassignments',
        color: '#f4a000',
        valueField: 'reassignmentCount',
        dashArray: '8 7'
    }
]);

function createDefaultReportData() {
    return {
        ...DEFAULT_REPORT_DATA,
        categoryRegistrations: [],
        categoryOccupancy: [],
        buildingOccupancy: [],
        allotmentDistribution: [],
        monthlyAllocationTrend: [],
        allotmentPerformanceSummary: []
    };
}

function normalizeText(value) {
    return `${value || ''}`.trim();
}

function normalizeKey(value) {
    return normalizeText(value).toLowerCase().replace(/\s+/g, '');
}

function parseCycleLabel(label) {
    const text = normalizeText(label);
    const match = text.match(/^(.*?)(?:\s*\(([^)]+)\))?$/);
    return {
        name: normalizeText(match?.[1] || text),
        status: normalizeText(match?.[2] || '')
    };
}

function formatNumber(value) {
    const numericValue = Number(value);
    if (!Number.isFinite(numericValue)) {
        return '0';
    }
    return new Intl.NumberFormat('en-IN', {
        maximumFractionDigits: 0
    }).format(numericValue);
}

function formatPercent(value) {
    const numericValue = Number(value);
    if (!Number.isFinite(numericValue)) {
        return '0%';
    }
    const roundedValue = Math.round(numericValue * 10) / 10;
    const minimumFractionDigits = Number.isInteger(roundedValue) ? 0 : 1;
    return `${new Intl.NumberFormat('en-IN', {
        minimumFractionDigits,
        maximumFractionDigits: 1
    }).format(roundedValue)}%`;
}

function formatCurrency(value) {
    const numericValue = Number(value);
    if (!Number.isFinite(numericValue)) {
        return '\u20b90';
    }

    return new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR',
        maximumFractionDigits: Number.isInteger(numericValue) ? 0 : 2
    }).format(numericValue);
}

function formatTooltipPercent(value) {
    const numericValue = Number(value);
    if (!Number.isFinite(numericValue)) {
        return '0.0%';
    }
    return `${new Intl.NumberFormat('en-IN', {
        minimumFractionDigits: 1,
        maximumFractionDigits: 1
    }).format(numericValue)}%`;
}

function clampPercentage(value) {
    const numericValue = Number(value);
    if (!Number.isFinite(numericValue)) {
        return 0;
    }
    return Math.max(0, Math.min(100, numericValue));
}

function polarToCartesian(centerX, centerY, radius, angleInDegrees) {
    const angleInRadians = ((angleInDegrees - 90) * Math.PI) / 180;
    return {
        x: centerX + radius * Math.cos(angleInRadians),
        y: centerY + radius * Math.sin(angleInRadians)
    };
}

function describeArc(startAngle, endAngle) {
    const start = polarToCartesian(DONUT_CENTER, DONUT_CENTER, DONUT_RADIUS, endAngle);
    const end = polarToCartesian(DONUT_CENTER, DONUT_CENTER, DONUT_RADIUS, startAngle);
    const largeArcFlag = endAngle - startAngle <= 180 ? '0' : '1';
    return `M ${start.x.toFixed(3)} ${start.y.toFixed(3)} A ${DONUT_RADIUS} ${DONUT_RADIUS} 0 ${largeArcFlag} 0 ${end.x.toFixed(3)} ${end.y.toFixed(3)}`;
}

function buildTooltipStyle(angleInDegrees) {
    const point = polarToCartesian(DONUT_CENTER, DONUT_CENTER, DONUT_TOOLTIP_RADIUS, angleInDegrees);
    const left = (point.x / DONUT_VIEWBOX_SIZE) * 100;
    const top = (point.y / DONUT_VIEWBOX_SIZE) * 100;
    return `left: ${left}%; top: ${top}%;`;
}

function buildTrendTooltipStyle(x, y) {
    const left = (x / TREND_VIEWBOX_WIDTH) * 100;
    const top = (y / TREND_VIEWBOX_HEIGHT) * 100;
    return `left: ${left}%; top: ${top}%;`;
}

function roundTrendMax(value) {
    const numericValue = Number(value);
    const safeValue = Number.isFinite(numericValue) && numericValue > 0 ? numericValue : 10;
    const step = Math.max(5, Math.ceil(safeValue / 4 / 5) * 5);
    return step * 4;
}

function buildSmoothPath(points) {
    if (!Array.isArray(points) || points.length === 0) {
        return '';
    }
    if (points.length === 1) {
        const point = points[0];
        return `M ${point.x} ${point.y}`;
    }

    let path = `M ${points[0].x} ${points[0].y}`;
    for (let index = 0; index < points.length - 1; index += 1) {
        const currentPoint = points[index];
        const nextPoint = points[index + 1];
        const midX = ((currentPoint.x + nextPoint.x) / 2).toFixed(2);
        path += ` C ${midX} ${currentPoint.y.toFixed(2)}, ${midX} ${nextPoint.y.toFixed(
            2
        )}, ${nextPoint.x.toFixed(2)} ${nextPoint.y.toFixed(2)}`;
    }
    return path;
}

function resolveStatusClass(status) {
    const key = normalizeKey(status);
    if (key === 'open' || key === 'active') {
        return 'rep-pill rep-pill--success';
    }
    if (key === 'closed') {
        return 'rep-pill rep-pill--neutral';
    }
    if (key === 'upcoming' || key === 'scheduled' || key === 'draft') {
        return 'rep-pill rep-pill--warning';
    }
    return 'rep-pill';
}

function resolveAllotmentTypeClass(type) {
    const key = normalizeKey(type);
    if (key.includes('provisional') || key.includes('preference')) {
        return 'rep-pill rep-pill--accent';
    }
    if (key.includes('direct') || key.includes('confirm')) {
        return 'rep-pill rep-pill--info';
    }
    return 'rep-pill';
}

function normalizeCycleOption(option) {
    const parsed = parseCycleLabel(option?.label);
    return {
        value: option?.value || '',
        label: option?.label || '',
        name: normalizeText(option?.name) || parsed.name,
        status: normalizeText(option?.status) || parsed.status,
        statusClass: resolveStatusClass(option?.status || parsed.status)
    };
}

function normalizeWindowOption(option) {
    const startDate = normalizeText(option?.startDate);
    const endDate = normalizeText(option?.endDate);
    return {
        id: option?.id || '',
        label: option?.label || '',
        name: normalizeText(option?.name),
        allotmentType: normalizeText(option?.allotmentType),
        status: normalizeText(option?.status),
        startDate,
        endDate,
        dateRange: startDate && endDate ? `${startDate} to ${endDate}` : startDate || endDate || '',
        statusClass: resolveStatusClass(option?.status),
        allotmentTypeClass: resolveAllotmentTypeClass(option?.allotmentType)
    };
}

function resolveDistributionColor(label) {
    const key = normalizeKey(label);
    if (key === 'provisional') {
        return DISTRIBUTION_COLORS.provisional;
    }
    if (key === 'direct') {
        return DISTRIBUTION_COLORS.direct;
    }
    return DISTRIBUTION_COLORS.other;
}

function truncateLabel(value, maxLength = 12) {
    const text = normalizeText(value);
    if (text.length <= maxLength) {
        return text;
    }
    return `${text.slice(0, Math.max(maxLength - 1, 1))}\u2026`;
}

function escapeCsvCell(value) {
    const text = `${value ?? ''}`;
    if (/[",\n]/.test(text)) {
        return `"${text.replace(/"/g, '""')}"`;
    }
    return text;
}

function buildCsvLines(rows) {
    return rows.map((row) => row.map((value) => escapeCsvCell(value)).join(','));
}

export default class KenReportsAnalyticsScreen extends LightningElement {
    cycles = [];
    windows = [];
    reportData = createDefaultReportData();
    selectedCycleId = '';
    selectedWindowId = '';
    activeDistributionKey = '';
    activeBuildingKey = '';
    activeCategoryOccupancyKey = '';
    activeTrendKey = '';
    pendingScrollSection = '';
    isLoadingCycles = false;
    isLoadingWindows = false;
    isLoadingReportData = false;
    windowRequestId = 0;
    reportRequestId = 0;
    initializePromise = null;

    connectedCallback() {
        this.initializePromise = this.loadCycleOptions();
    }

    renderedCallback() {
        this.tryScrollToRequestedSection();
    }

    @api
    async openReportView(cycleId, windowId, sectionKey) {
        if (this.initializePromise) {
            await this.initializePromise;
        }

        const resolvedCycleId = cycleId || this.selectedCycleId || this.cycles?.[0]?.value || '';
        if (!resolvedCycleId) {
            return;
        }

        if (resolvedCycleId !== this.selectedCycleId) {
            this.selectedCycleId = resolvedCycleId;
            this.selectedWindowId = '';
            this.resetReportData();
            await this.loadWindowOptions();
        }

        const resolvedWindowId = windowId || this.selectedWindowId || this.windows?.[0]?.id || '';
        if (!resolvedWindowId) {
            return;
        }

        if (resolvedWindowId !== this.selectedWindowId) {
            this.selectedWindowId = resolvedWindowId;
            this.resetReportData();
            await this.loadReportData();
        }

        this.requestReportSectionScroll(sectionKey);
    }

    get selectedCycle() {
        return this.cycles.find((cycle) => cycle.value === this.selectedCycleId) || null;
    }

    get selectedWindow() {
        if (!this.selectedWindowId) {
            return null;
        }
        return this.windows.find((windowRecord) => windowRecord.id === this.selectedWindowId) || null;
    }

    get hasSelectedWindow() {
        return !!this.selectedWindowId && !!this.selectedWindow;
    }

    get hasWindowOptions() {
        return this.windows.length > 0;
    }

    get showEmptyState() {
        return !this.isLoadingWindows && !this.hasSelectedWindow;
    }

    get exportDisabled() {
        return !this.hasSelectedWindow || this.isLoadingReportData;
    }

    get cycleSelectOptions() {
        return (this.cycles || []).map((option) => ({
            ...option,
            isSelected: option.value === this.selectedCycleId
        }));
    }

    get windowSelectOptions() {
        return (this.windows || []).map((option) => ({
            ...option,
            isSelected: option.id === this.selectedWindowId
        }));
    }

    get isWindowPlaceholderSelected() {
        return !this.selectedWindowId;
    }

    get windowPlaceholderLabel() {
        return this.hasWindowOptions ? 'No window selected' : 'No windows available';
    }

    get selectedCycleName() {
        return this.selectedCycle?.name || '';
    }

    get selectedCycleStatus() {
        return this.selectedCycle?.status || '';
    }

    get selectedCycleStatusClass() {
        return this.selectedCycle?.statusClass || 'rep-pill';
    }

    get selectedWindowName() {
        return this.selectedWindow?.name || '';
    }

    get selectedWindowAllotmentType() {
        return this.selectedWindow?.allotmentType || '';
    }

    get selectedWindowAllotmentTypeClass() {
        return this.selectedWindow?.allotmentTypeClass || 'rep-pill';
    }

    get selectedWindowStatus() {
        return this.selectedWindow?.status || '';
    }

    get selectedWindowStatusClass() {
        return this.selectedWindow?.statusClass || 'rep-pill';
    }

    get selectedWindowDateRange() {
        return this.selectedWindow?.dateRange || '';
    }

    get metricCards() {
        return [
            {
                key: 'totalAllocations',
                label: 'Total Allocations',
                value: formatNumber(this.reportData.totalAllocations),
                helper: 'Rooms Allocated (Active Cycle)',
                iconName: 'utility:home',
                iconClass: 'rep-card-icon rep-card-icon--blue',
                cardClass: 'rep-card rep-card--allocations'
            },
            {
                key: 'occupancyRate',
                label: 'Occupancy Rate',
                value: formatPercent(this.reportData.occupancyRate),
                helper: 'Current Occupancy %',
                iconName: 'utility:chart',
                iconClass: 'rep-card-icon rep-card-icon--green',
                cardClass: 'rep-card rep-card--occupancy'
            },
            {
                key: 'pendingApplications',
                label: 'Pending Applications',
                value: formatNumber(this.reportData.pendingApplications),
                helper: 'Awaiting Assignment (Provisional)',
                iconName: 'utility:clock',
                iconClass: 'rep-card-icon rep-card-icon--amber',
                cardClass: 'rep-card rep-card--pending'
            },
            {
                key: 'totalCapacity',
                label: 'Total Capacity',
                value: formatNumber(this.reportData.totalCapacity),
                helper: 'Total Beds Across Active Buildings',
                iconName: 'utility:groups',
                iconClass: 'rep-card-icon rep-card-icon--violet',
                cardClass: 'rep-card rep-card--capacity'
            }
        ];
    }

    get categoryRegistrationRows() {
        const rows = Array.isArray(this.reportData?.categoryRegistrations)
            ? this.reportData.categoryRegistrations
            : [];
        const maxValue = rows.reduce((currentMax, item) => {
            const registeredCount = Number(item?.registeredCount) || 0;
            return Math.max(currentMax, registeredCount);
        }, 0);
        const safeMax = maxValue > 0 ? maxValue : 1;

        return rows.map((item, index) => {
            const registeredCount = Number(item?.registeredCount) || 0;
            return {
                key: `${index}-${normalizeKey(item?.label) || 'category-registration'}`,
                label: normalizeText(item?.label) || 'Uncategorized',
                registeredCountLabel: formatNumber(registeredCount),
                registeredStyle: `width: ${(registeredCount / safeMax) * 100}%;`
            };
        });
    }

    get hasCategoryRegistrations() {
        return this.categoryRegistrationRows.length > 0;
    }

    get categoryOccupancyChartItems() {
        const rows = Array.isArray(this.reportData?.categoryOccupancy)
            ? this.reportData.categoryOccupancy
            : [];
        return rows.map((item, index) => {
            const occupancyPercentage = clampPercentage(item?.occupancyPercentage);
            const totalCapacity = Number(item?.totalCapacity) || 0;
            const occupiedBeds = Number(item?.occupiedBeds) || 0;
            const availableBeds = Math.max(totalCapacity - occupiedBeds, 0);
            const availablePercentage = totalCapacity > 0 ? Math.max(100 - occupancyPercentage, 0) : 0;
            let tooltipClass = 'rep-building-tooltip';
            if (index === 0) {
                tooltipClass += ' rep-building-tooltip--start';
            } else if (index === rows.length - 1) {
                tooltipClass += ' rep-building-tooltip--end';
            }
            const key = `${index}-${normalizeKey(item?.label) || 'category-occupancy'}`;
            return {
                key,
                categoryName: normalizeText(item?.label) || 'Uncategorized',
                shortLabel: truncateLabel(item?.label || `Category ${index + 1}`),
                occupiedBedsLabel: formatNumber(occupiedBeds),
                availableBedsLabel: formatNumber(availableBeds),
                totalCapacityLabel: formatNumber(totalCapacity),
                occupancyPercentageLabel: formatPercent(occupancyPercentage),
                occupiedPercentageLabel: formatPercent(occupancyPercentage),
                availablePercentageLabel: formatPercent(availablePercentage),
                occupiedStyle: `height: ${occupancyPercentage}%;`,
                availableStyle: `height: ${availablePercentage}%;`,
                tooltipClass,
                tooltipVisible: this.activeCategoryOccupancyKey === key
            };
        });
    }

    get hasCategoryOccupancy() {
        return this.categoryOccupancyChartItems.length > 0;
    }

    get financeReportCards() {
        const collectedAmount = Number(this.reportData?.totalAmountCollected) || 0;
        const pendingAmount = Number(this.reportData?.pendingAmount) || 0;
        const totalAmount = Math.max(collectedAmount + pendingAmount, 0);
        const collectedPercentage = totalAmount > 0 ? (collectedAmount / totalAmount) * 100 : 0;
        const pendingPercentage = totalAmount > 0 ? (pendingAmount / totalAmount) * 100 : 0;
        return [
            {
                key: 'collected',
                label: 'Collected',
                title: 'Total Amount Collected',
                amount: collectedAmount,
                amountLabel: formatCurrency(collectedAmount),
                helper: `${formatPercent(collectedPercentage)} of scoped dues`,
                color: FINANCE_COLORS.collected,
                panelClass: 'rep-panel rep-panel--compact rep-finance-report rep-finance-report--collected',
                reportSection: 'financeCollected'
            },
            {
                key: 'pending',
                label: 'Pending',
                title: 'Pending Amount',
                amount: pendingAmount,
                amountLabel: formatCurrency(pendingAmount),
                helper: `${formatPercent(pendingPercentage)} still outstanding`,
                color: FINANCE_COLORS.pending,
                panelClass: 'rep-panel rep-panel--compact rep-finance-report rep-finance-report--pending',
                reportSection: 'financePending'
            }
        ].map((item) => {
            const percentage = totalAmount > 0 ? (item.amount / totalAmount) * 100 : 0;
            const sweep = totalAmount > 0 ? (item.amount / totalAmount) * 360 : 0;
            const segmentPath = item.amount > 0
                ? describeArc(0, sweep >= 360 ? 359.999 : Math.max(sweep, 0.5))
                : '';
            return {
                ...item,
                percentageLabel: formatPercent(percentage),
                segmentPath,
                segmentStyle: `stroke: ${item.color};`
            };
        });
    }

    get buildingChartItems() {
        const rows = this.reportData?.buildingOccupancy || [];
        return rows.map((item, index) => {
            const occupiedPercentage = clampPercentage(item?.occupiedPercentage);
            const availablePercentage = clampPercentage(item?.availablePercentage);
            let tooltipClass = 'rep-building-tooltip';
            if (index === 0) {
                tooltipClass += ' rep-building-tooltip--start';
            } else if (index === rows.length - 1) {
                tooltipClass += ' rep-building-tooltip--end';
            }
            return {
                key: item?.buildingId || `${index}`,
                buildingName: normalizeText(item?.buildingName) || 'Unassigned',
                shortLabel: truncateLabel(item?.buildingName || `Building ${index + 1}`),
                occupiedBedsLabel: formatNumber(item?.occupiedBeds),
                availableBedsLabel: formatNumber(item?.availableBeds),
                totalCapacityLabel: formatNumber(item?.totalCapacity),
                occupiedPercentageLabel: formatPercent(occupiedPercentage),
                availablePercentageLabel: formatPercent(availablePercentage),
                occupiedStyle: `height: ${occupiedPercentage}%;`,
                availableStyle: `height: ${availablePercentage}%;`,
                tooltipClass,
                tooltipVisible: this.activeBuildingKey === (item?.buildingId || `${index}`)
            };
        });
    }

    get hasBuildingOccupancy() {
        return this.buildingChartItems.length > 0;
    }

    get distributionItems() {
        const rows = (this.reportData?.allotmentDistribution || [])
            .map((item, index) => {
                const label = normalizeText(item?.label) || 'Other';
                return {
                    key: `${index}-${normalizeKey(label) || 'distribution'}`,
                    label,
                    count: Number(item?.count) || 0,
                    countLabel: formatNumber(item?.count),
                    color: resolveDistributionColor(label),
                    swatchStyle: `background: ${resolveDistributionColor(label)};`
                };
            })
            .filter((item) => item.count > 0);

        const totalCount = rows.reduce((sum, item) => sum + item.count, 0);
        let currentAngle = 0;

        return rows.map((item) => {
            const percentage = totalCount > 0 ? (item.count / totalCount) * 100 : 0;
            const sweep = totalCount > 0 ? (item.count / totalCount) * 360 : 0;
            const gap = rows.length > 1 && sweep > DONUT_GAP_DEGREES ? DONUT_GAP_DEGREES : 0;
            const visibleSweep = sweep >= 360 ? 359.999 : Math.max(sweep - gap, 0.5);
            const startAngle = currentAngle + gap / 2;
            const endAngle = startAngle + visibleSweep;
            const midAngle = currentAngle + sweep / 2;
            currentAngle += sweep;

            return {
                ...item,
                percentage,
                percentageLabel: formatTooltipPercent(percentage),
                tooltipText: `${item.label} : ${item.countLabel} (${formatTooltipPercent(percentage)})`,
                tooltipStyle: buildTooltipStyle(midAngle),
                segmentPath: describeArc(startAngle, endAngle),
                segmentStyle: `stroke: ${item.color};`,
                segmentClass:
                    this.activeDistributionKey === item.key
                        ? 'rep-donut-segment rep-donut-segment--active'
                        : 'rep-donut-segment'
            };
        });
    }

    get hasDistribution() {
        return this.distributionItems.length > 0;
    }

    get activeDistributionTooltip() {
        return this.distributionItems.find((item) => item.key === this.activeDistributionKey) || null;
    }

    get allotmentPerformanceRows() {
        return (this.reportData?.allotmentPerformanceSummary || []).map((item, index) => ({
            key: `${index}-${normalizeKey(item?.label) || 'performance'}`,
            label: normalizeText(item?.label) || `Row ${index + 1}`,
            totalApplicationsLabel: formatNumber(item?.totalApplications),
            assignedLabel: formatNumber(item?.assignedCount),
            rejectedLabel: formatNumber(item?.rejectedCount),
            pendingLabel: formatNumber(item?.pendingCount),
            avgAllocationTimeLabel: normalizeText(item?.avgAllocationTime) || '\u2014',
            trendLabel: normalizeText(item?.trend) || '\u2014',
            rowClass: item?.isTotal ? 'rep-performance-row rep-performance-row--total' : 'rep-performance-row'
        }));
    }

    get hasAllotmentPerformanceSummary() {
        return this.allotmentPerformanceRows.length > 0;
    }

    get trendChartData() {
        const rows = Array.isArray(this.reportData?.monthlyAllocationTrend)
            ? this.reportData.monthlyAllocationTrend
            : [];
        if (!rows.length) {
            return null;
        }

        const plotLeft = TREND_MARGIN.left;
        const plotTop = TREND_MARGIN.top;
        const plotWidth = TREND_VIEWBOX_WIDTH - TREND_MARGIN.left - TREND_MARGIN.right;
        const plotHeight = TREND_VIEWBOX_HEIGHT - TREND_MARGIN.top - TREND_MARGIN.bottom;
        const plotBottom = plotTop + plotHeight;
        const plotRight = plotLeft + plotWidth;
        const maxSeriesValue = rows.reduce((currentMax, item) => {
            const itemMax = Math.max(
                Number(item?.directCount) || 0,
                Number(item?.provisionalCount) || 0,
                Number(item?.reassignmentCount) || 0
            );
            return Math.max(currentMax, itemMax);
        }, 0);
        const maxY = roundTrendMax(maxSeriesValue);
        const stepX = rows.length > 1 ? plotWidth / (rows.length - 1) : 0;

        const yTicks = [1, 0.75, 0.5, 0.25, 0].map((ratio, index) => {
            const y = plotTop + plotHeight * (1 - ratio);
            return {
                key: `tick-${index}`,
                label: formatNumber(maxY * ratio),
                y,
                textY: y + 4
            };
        });

        const months = rows.map((item, index) => {
            const x = rows.length > 1 ? plotLeft + stepX * index : plotLeft + plotWidth / 2;
            const previousX = index === 0 ? plotLeft : plotLeft + stepX * (index - 1);
            const nextX = index === rows.length - 1 ? plotRight : plotLeft + stepX * (index + 1);
            const zoneX = index === 0 ? plotLeft : (previousX + x) / 2;
            const zoneEndX = index === rows.length - 1 ? plotRight : (x + nextX) / 2;
            const zoneWidth = zoneEndX - zoneX;
            const directCount = Number(item?.directCount) || 0;
            const provisionalCount = Number(item?.provisionalCount) || 0;
            const reassignmentCount = Number(item?.reassignmentCount) || 0;
            const yBySeries = {
                direct: plotBottom - (directCount / maxY) * plotHeight,
                provisional: plotBottom - (provisionalCount / maxY) * plotHeight,
                reassignments: plotBottom - (reassignmentCount / maxY) * plotHeight
            };
            const tooltipY = Math.max(
                plotTop + 16,
                Math.min(yBySeries.direct, yBySeries.provisional, yBySeries.reassignments) - 18
            );
            let tooltipClassName = 'rep-trend-tooltip';
            if (index === 0) {
                tooltipClassName += ' rep-trend-tooltip--start';
            } else if (index === rows.length - 1) {
                tooltipClassName += ' rep-trend-tooltip--end';
            }

            return {
                key: item?.monthKey || `month-${index}`,
                label: normalizeText(item?.label) || `Month ${index + 1}`,
                x,
                zoneX,
                zoneWidth,
                directCount,
                provisionalCount,
                reassignmentCount,
                directCountLabel: formatNumber(directCount),
                provisionalCountLabel: formatNumber(provisionalCount),
                reassignmentCountLabel: formatNumber(reassignmentCount),
                yBySeries,
                xLabelY: TREND_VIEWBOX_HEIGHT - 18,
                tooltipStyle: buildTrendTooltipStyle(x, tooltipY),
                tooltipClassName,
                gridLineVisible: index > 0,
                gridLineKey: `grid-${item?.monthKey || index}`,
                labelKey: `label-${item?.monthKey || index}`,
                hotspotKey: `hotspot-${item?.monthKey || index}`
            };
        });

        const series = TREND_SERIES.map((seriesConfig) => {
            const points = months.map((month) => ({
                key: `${seriesConfig.key}-${month.key}`,
                x: month.x,
                y: month.yBySeries[seriesConfig.key],
                value: month[seriesConfig.valueField],
                valueLabel: formatNumber(month[seriesConfig.valueField]),
                radius: this.activeTrendKey === month.key ? 5.5 : 4.5
            }));

            return {
                key: seriesConfig.key,
                label: seriesConfig.label,
                swatchStyle: `background: ${seriesConfig.color};`,
                lineStyle: `stroke: ${seriesConfig.color};${
                    seriesConfig.dashArray ? ` stroke-dasharray: ${seriesConfig.dashArray};` : ''
                }`,
                pointStyle: `stroke: ${seriesConfig.color}; fill: #ffffff;`,
                path: buildSmoothPath(points),
                points
            };
        });

        const activeMonth = months.find((month) => month.key === this.activeTrendKey) || null;

        return {
            viewBox: `0 0 ${TREND_VIEWBOX_WIDTH} ${TREND_VIEWBOX_HEIGHT}`,
            plotTop,
            plotBottom,
            plotHeight,
            plotLeft,
            plotRight,
            yTicks,
            months,
            verticalGridLines: months
                .filter((month) => month.gridLineVisible)
                .map((month) => ({
                    key: month.gridLineKey,
                    x: month.x
                })),
            series,
            legend: TREND_SERIES.map((seriesConfig) => ({
                key: seriesConfig.key,
                label: seriesConfig.label,
                swatchStyle: `background: ${seriesConfig.color};`
            })),
            activeGuideLine: activeMonth
                ? {
                      x: activeMonth.x
                  }
                : null,
            activeTooltip: activeMonth
                ? {
                      key: activeMonth.key,
                      label: activeMonth.label,
                      style: activeMonth.tooltipStyle,
                      className: activeMonth.tooltipClassName,
                      rows: [
                          {
                              key: `direct-${activeMonth.key}`,
                              label: 'Direct',
                              value: activeMonth.directCountLabel,
                              swatchStyle: 'background: #4c56da;'
                          },
                          {
                              key: `provisional-${activeMonth.key}`,
                              label: 'Provisional',
                              value: activeMonth.provisionalCountLabel,
                              swatchStyle: 'background: #07b53b;'
                          },
                          {
                              key: `reassignments-${activeMonth.key}`,
                              label: 'Reassignments',
                              value: activeMonth.reassignmentCountLabel,
                              swatchStyle: 'background: #f4a000;'
                          }
                      ]
                  }
                : null
        };
    }

    async loadCycleOptions() {
        this.isLoadingCycles = true;
        try {
            const cycleOptions = await getCycleOptions();
            this.cycles = (Array.isArray(cycleOptions) ? cycleOptions : []).map((item) => normalizeCycleOption(item));
            if (!this.cycles.some((cycle) => cycle.value === this.selectedCycleId)) {
                this.selectedCycleId = this.cycles.length ? this.cycles[0].value : '';
            }
            await this.loadWindowOptions();
        } catch (error) {
            this.cycles = [];
            this.selectedCycleId = '';
            this.windows = [];
            this.selectedWindowId = '';
            this.resetReportData();
            this.showErrorToast('Unable to load report cycles.', error);
        } finally {
            this.isLoadingCycles = false;
        }
    }

    async loadWindowOptions() {
        const requestId = ++this.windowRequestId;
        if (!this.selectedCycleId) {
            this.windows = [];
            this.selectedWindowId = '';
            this.resetReportData();
            return;
        }

        this.isLoadingWindows = true;
        try {
            const windowOptions = await getWindowOptions({ cycleId: this.selectedCycleId });
            if (requestId !== this.windowRequestId) {
                return;
            }

            this.windows = (Array.isArray(windowOptions) ? windowOptions : []).map((item) => normalizeWindowOption(item));
            if (!this.windows.some((windowRecord) => windowRecord.id === this.selectedWindowId)) {
                this.selectedWindowId = this.windows.length ? this.windows[0].id : '';
            }
            await this.loadReportData();
        } catch (error) {
            if (requestId !== this.windowRequestId) {
                return;
            }
            this.windows = [];
            this.selectedWindowId = '';
            this.resetReportData();
            this.showErrorToast('Unable to load report windows.', error);
        } finally {
            if (requestId === this.windowRequestId) {
                this.isLoadingWindows = false;
            }
        }
    }

    async loadReportData() {
        const requestId = ++this.reportRequestId;
        if (!this.selectedWindowId) {
            this.resetReportData();
            return;
        }

        this.isLoadingReportData = true;
        try {
            const reportData = await getReportData({ windowId: this.selectedWindowId });
            if (requestId !== this.reportRequestId) {
                return;
            }

            this.reportData = {
                ...createDefaultReportData(),
                ...(reportData || {})
            };
        } catch (error) {
            if (requestId !== this.reportRequestId) {
                return;
            }
            this.resetReportData();
            this.showErrorToast('Unable to load reports analytics.', error);
        } finally {
            if (requestId === this.reportRequestId) {
                this.isLoadingReportData = false;
            }
        }
    }

    async handleCycleChange(event) {
        this.selectedCycleId = event.target.value;
        this.selectedWindowId = '';
        this.resetReportData();
        await this.loadWindowOptions();
    }

    async handleWindowChange(event) {
        this.selectedWindowId = event.target.value;
        this.resetReportData();
        await this.loadReportData();
    }

    handleBuildingEnter(event) {
        const key = event.currentTarget?.dataset?.key;
        if (key) {
            this.activeBuildingKey = key;
        }
    }

    handleBuildingLeave() {
        this.activeBuildingKey = '';
    }

    handleBuildingActivate(event) {
        const key = event.currentTarget?.dataset?.key;
        if (!key) {
            return;
        }
        this.activeBuildingKey = this.activeBuildingKey === key ? '' : key;
    }

    handleCategoryOccupancyEnter(event) {
        const key = event.currentTarget?.dataset?.key;
        if (key) {
            this.activeCategoryOccupancyKey = key;
        }
    }

    handleCategoryOccupancyLeave() {
        this.activeCategoryOccupancyKey = '';
    }

    handleCategoryOccupancyActivate(event) {
        const key = event.currentTarget?.dataset?.key;
        if (!key) {
            return;
        }
        this.activeCategoryOccupancyKey = this.activeCategoryOccupancyKey === key ? '' : key;
    }

    handleDistributionEnter(event) {
        const key = event.currentTarget?.dataset?.key;
        if (key) {
            this.activeDistributionKey = key;
        }
    }

    handleDistributionLeave() {
        this.activeDistributionKey = '';
    }

    handleDistributionActivate(event) {
        const key = event.currentTarget?.dataset?.key;
        if (!key) {
            return;
        }
        this.activeDistributionKey = this.activeDistributionKey === key ? '' : key;
    }

    handleTrendEnter(event) {
        const key = event.currentTarget?.dataset?.key;
        if (key) {
            this.activeTrendKey = key;
        }
    }

    handleTrendLeave() {
        this.activeTrendKey = '';
    }

    handleTrendActivate(event) {
        const key = event.currentTarget?.dataset?.key;
        if (!key) {
            return;
        }
        this.activeTrendKey = this.activeTrendKey === key ? '' : key;
    }

    handleExportAll() {
        if (this.exportDisabled) {
            return;
        }
        const lines = [
            ...buildCsvLines([
                ['Summary'],
                ['Metric', 'Value'],
                ['Total Allocations', this.reportData.totalAllocations],
                ['Occupancy Rate', formatPercent(this.reportData.occupancyRate)],
                ['Pending Applications', this.reportData.pendingApplications],
                ['Total Capacity', this.reportData.totalCapacity],
                ['Occupied Beds', this.reportData.occupiedBeds],
                ['Registered Students', this.reportData.totalRegistered],
                ['Total Amount Collected', this.reportData.totalAmountCollected],
                ['Pending Amount', this.reportData.pendingAmount]
            ]),
            '',
            ...this.buildBuildingCsvLines(),
            '',
            ...this.buildDistributionCsvLines(),
            '',
            ...this.buildMonthlyTrendCsvLines(),
            '',
            ...this.buildPerformanceSummaryCsvLines(),
            '',
            ...this.buildCategoryRegistrationCsvLines(),
            '',
            ...this.buildFinanceCsvLines(),
            '',
            ...this.buildCategoryOccupancyCsvLines()
        ];
        this.downloadCsv(lines.join('\r\n'), this.buildFileName('reports-analytics'));
    }

    handleSectionExport(event) {
        const section = event.currentTarget?.dataset?.section;
        if (!section || this.exportDisabled) {
            return;
        }

        if (section === 'building') {
            this.downloadCsv(
                this.buildBuildingCsvLines().join('\r\n'),
                this.buildFileName('building-wise-occupancy')
            );
            return;
        }

        if (section === 'distribution') {
            this.downloadCsv(
                this.buildDistributionCsvLines().join('\r\n'),
                this.buildFileName('allotment-type-distribution')
            );
            return;
        }

        if (section === 'trend') {
            this.downloadCsv(
                this.buildMonthlyTrendCsvLines().join('\r\n'),
                this.buildFileName('monthly-allocation-trend')
            );
            return;
        }

        if (section === 'performance') {
            this.downloadCsv(
                this.buildPerformanceSummaryCsvLines().join('\r\n'),
                this.buildFileName('allotment-performance-summary')
            );
            return;
        }

        if (section === 'categoryRegistration') {
            this.downloadCsv(
                this.buildCategoryRegistrationCsvLines().join('\r\n'),
                this.buildFileName('category-registration')
            );
            return;
        }

        if (section === 'finance') {
            this.downloadCsv(
                this.buildFinanceCsvLines().join('\r\n'),
                this.buildFileName('collection-overview')
            );
            return;
        }

        if (section === 'categoryOccupancy') {
            this.downloadCsv(
                this.buildCategoryOccupancyCsvLines().join('\r\n'),
                this.buildFileName('category-wise-occupancy')
            );
            return;
        }
    }

    requestReportSectionScroll(sectionKey) {
        if (!sectionKey) {
            return;
        }

        this.pendingScrollSection = sectionKey;
        Promise.resolve().then(() => {
            this.tryScrollToRequestedSection();
        });
    }

    tryScrollToRequestedSection() {
        if (!this.pendingScrollSection) {
            return;
        }

        const target = this.template.querySelector(`[data-report-section="${this.pendingScrollSection}"]`);
        if (!target) {
            return;
        }

        this.pendingScrollSection = '';
        target.scrollIntoView({
            behavior: 'smooth',
            block: 'start'
        });
    }

    buildCategoryRegistrationCsvLines() {
        return buildCsvLines([
            ['Category-wise Registration'],
            ['Category', 'Registered Students'],
            ...(this.reportData.categoryRegistrations || []).map((item) => [
                normalizeText(item?.label) || 'Uncategorized',
                Number(item?.registeredCount) || 0
            ])
        ]);
    }

    buildFinanceCsvLines() {
        return buildCsvLines([
            ['Collection Overview'],
            ['Metric', 'Amount'],
            ['Total Amount Collected', this.reportData.totalAmountCollected],
            ['Pending Amount', this.reportData.pendingAmount]
        ]);
    }

    buildCategoryOccupancyCsvLines() {
        return buildCsvLines([
            ['Category-wise Occupancy'],
            ['Category', 'Occupied Beds', 'Total Capacity', 'Occupancy %'],
            ...(this.reportData.categoryOccupancy || []).map((item) => [
                normalizeText(item?.label) || 'Uncategorized',
                Number(item?.occupiedBeds) || 0,
                Number(item?.totalCapacity) || 0,
                formatPercent(item?.occupancyPercentage)
            ])
        ]);
    }

    buildBuildingCsvLines() {
        return buildCsvLines([
            ['Building-wise Occupancy'],
            ['Building', 'Occupied Beds', 'Available Beds', 'Total Capacity', 'Occupied %', 'Available %'],
            ...(this.reportData.buildingOccupancy || []).map((item) => [
                normalizeText(item?.buildingName) || 'Unassigned',
                Number(item?.occupiedBeds) || 0,
                Number(item?.availableBeds) || 0,
                Number(item?.totalCapacity) || 0,
                formatPercent(item?.occupiedPercentage),
                formatPercent(item?.availablePercentage)
            ])
        ]);
    }

    buildDistributionCsvLines() {
        return buildCsvLines([
            ['Allotment Type Distribution'],
            ['Allotment Type', 'Count'],
            ...(this.reportData.allotmentDistribution || []).map((item) => [
                normalizeText(item?.label) || 'Other',
                Number(item?.count) || 0
            ])
        ]);
    }

    buildMonthlyTrendCsvLines() {
        return buildCsvLines([
            ['Monthly Allocation Trend'],
            ['Month', 'Direct', 'Provisional', 'Reassignments'],
            ...(this.reportData.monthlyAllocationTrend || []).map((item) => [
                normalizeText(item?.label),
                Number(item?.directCount) || 0,
                Number(item?.provisionalCount) || 0,
                Number(item?.reassignmentCount) || 0
            ])
        ]);
    }

    buildPerformanceSummaryCsvLines() {
        return buildCsvLines([
            ['Allotment Performance Summary'],
            ['Allotment Type', 'Total Applications', 'Assigned', 'Rejected', 'Pending', 'Avg Allocation Time', 'Trend'],
            ...(this.reportData.allotmentPerformanceSummary || []).map((item) => [
                normalizeText(item?.label),
                Number(item?.totalApplications) || 0,
                Number(item?.assignedCount) || 0,
                Number(item?.rejectedCount) || 0,
                Number(item?.pendingCount) || 0,
                normalizeText(item?.avgAllocationTime) || '',
                normalizeText(item?.trend) || ''
            ])
        ]);
    }

    buildFileName(prefix) {
        const cycleName = normalizeText(this.selectedCycleName).replace(/[^a-zA-Z0-9]+/g, '-').replace(/^-|-$/g, '');
        const windowName = normalizeText(this.selectedWindowName).replace(/[^a-zA-Z0-9]+/g, '-').replace(/^-|-$/g, '');
        const parts = [prefix, cycleName, windowName].filter((value) => !!value);
        return `${parts.join('-') || prefix}.csv`;
    }

    downloadCsv(csvContent, fileName) {
        const anchor = document.createElement('a');
        anchor.href = `data:text/csv;charset=utf-8,${encodeURIComponent(csvContent)}`;
        anchor.download = fileName;
        document.body.appendChild(anchor);
        anchor.click();
        document.body.removeChild(anchor);
    }

    resetReportData() {
        this.reportData = createDefaultReportData();
        this.activeBuildingKey = '';
        this.activeCategoryOccupancyKey = '';
        this.activeDistributionKey = '';
        this.activeTrendKey = '';
    }

    showErrorToast(title, error) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message: this.getErrorMessage(error),
                variant: 'error'
            })
        );
    }

    getErrorMessage(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item?.message).filter((message) => !!message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown error';
    }
}