import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCycleOptions from '@salesforce/apex/KenAdminDashboardController.getCycleOptions';
import getWindowOptions from '@salesforce/apex/KenAdminDashboardController.getWindowOptions';
import getDashboardSummary from '@salesforce/apex/KenAdminDashboardController.getDashboardSummary';
import getWindowPerformanceOverview from '@salesforce/apex/KenAdminDashboardController.getWindowPerformanceOverview';

const DEFAULT_SUMMARY = Object.freeze({
    totalRegistered: 0,
    totalAllocations: 0,
    inProgress: 0,
    occupancyRate: 0,
    totalCapacity: 0,
    availableRooms: 0,
    waitlisted: 0,
    occupiedBeds: 0,
    totalAmountCollected: 0,
    pendingAmount: 0,
    categoryRegistrations: [],
    categoryOccupancy: [],
    allocationBreakdown: []
});

const CATEGORY_PROGRESS_COLORS = ['#ff4d6d', '#4c56da', '#9db5ff', '#5861e7', '#b9c8ff', '#7f95ff'];
const REPORT_FINANCE_COLORS = Object.freeze({
    collected: '#109669',
    pending: '#ea7a1a'
});
const ALLOCATION_COLORS_BY_KEY = {
    directallotment: '#4c56da',
    provisionalallotment: '#07b53b',
    preferenceselected: '#8b5cf6',
    confirmedallotment: '#0ea5e9'
};
const FALLBACK_ALLOCATION_COLORS = ['#94a3b8', '#f59e0b', '#ef4444', '#14b8a6'];

function createDefaultSummary() {
    return {
        ...DEFAULT_SUMMARY,
        categoryRegistrations: [],
        categoryOccupancy: [],
        allocationBreakdown: []
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

function resolveStatusClass(status) {
    const key = normalizeKey(status);
    if (key === 'open' || key === 'active') {
        return 'dash-pill dash-pill--success';
    }
    if (key === 'upcoming' || key === 'scheduled') {
        return 'dash-pill dash-pill--warning';
    }
    if (key === 'closed') {
        return 'dash-pill dash-pill--neutral';
    }
    return 'dash-pill';
}

function resolveAllotmentTypeClass(type) {
    const key = normalizeKey(type);
    if (key === 'preferenceselected') {
        return 'dash-pill dash-pill--accent';
    }
    if (key === 'provisionalallotment') {
        return 'dash-pill dash-pill--success';
    }
    if (key === 'confirmedallotment') {
        return 'dash-pill dash-pill--teal';
    }
    if (key === 'directallotment') {
        return 'dash-pill dash-pill--info';
    }
    return 'dash-pill';
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

function clampPercentage(value) {
    const numericValue = Number(value);
    if (!Number.isFinite(numericValue)) {
        return 0;
    }
    return Math.max(0, Math.min(100, numericValue));
}

function formatWholePercent(value) {
    return `${Math.round(clampPercentage(value))}%`;
}

function truncateLabel(value, maxLength = 12) {
    const text = normalizeText(value);
    if (text.length <= maxLength) {
        return text;
    }
    return `${text.slice(0, Math.max(maxLength - 1, 1))}\u2026`;
}

function buildFinanceDonutStyle(amount, totalAmount, color) {
    const safeAmount = Math.max(Number(amount) || 0, 0);
    const safeTotal = Math.max(Number(totalAmount) || 0, 0);
    if (safeAmount <= 0 || safeTotal <= 0) {
        return 'background: conic-gradient(#e8edf5 0deg 360deg);';
    }

    const sweep = Math.min((safeAmount / safeTotal) * 360, 360);
    if (sweep >= 360) {
        return `background: conic-gradient(${color} 0deg 360deg);`;
    }

    return `background: conic-gradient(${color} 0deg ${sweep}deg, #e8edf5 ${sweep}deg 360deg);`;
}

function resolveAllocationLegendLabel(label) {
    const key = normalizeKey(label);
    if (key === 'directallotment') {
        return 'Direct';
    }
    if (key === 'provisionalallotment') {
        return 'Provisional';
    }
    if (key === 'preferenceselected') {
        return 'Preference';
    }
    if (key === 'confirmedallotment') {
        return 'Confirmed';
    }
    return normalizeText(label) || 'Other';
}

function resolveAllocationColor(label, index) {
    const color = ALLOCATION_COLORS_BY_KEY[normalizeKey(label)];
    if (color) {
        return color;
    }
    return FALLBACK_ALLOCATION_COLORS[index % FALLBACK_ALLOCATION_COLORS.length];
}

function buildAllocationChartStyle(items) {
    const total = items.reduce((sum, item) => sum + (Number(item?.count) || 0), 0);
    if (total <= 0) {
        return 'background: conic-gradient(#e8edf5 0deg 360deg);';
    }

    let currentAngle = 0;
    const segments = [];
    items.forEach((item) => {
        const count = Number(item?.count) || 0;
        if (count <= 0) {
            return;
        }
        const sweep = (count / total) * 360;
        const nextAngle = Math.min(currentAngle + sweep, 360);
        segments.push(`${item.color} ${currentAngle}deg ${nextAngle}deg`);
        currentAngle = nextAngle;
    });

    if (currentAngle < 360) {
        segments.push(`#e8edf5 ${currentAngle}deg 360deg`);
    }

    return `background: conic-gradient(${segments.join(', ')});`;
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
        ...option,
        id: option?.id || '',
        name: normalizeText(option?.name),
        allotmentType: normalizeText(option?.allotmentType),
        status: normalizeText(option?.status),
        startDate,
        endDate,
        statusClass: resolveStatusClass(option?.status),
        allotmentTypeClass: resolveAllotmentTypeClass(option?.allotmentType),
        dateRange: startDate && endDate ? `${startDate} to ${endDate}` : startDate || endDate || ''
    };
}

export default class KenDashboardScreen extends NavigationMixin(LightningElement) {
    cycles = [];
    windows = [];
    windowPerformance = [];
    summary = createDefaultSummary();
    selectedCycleId = '';
    selectedWindowId = '';
    isLoadingCycles = false;
    isLoadingWindows = false;
    isLoadingSummary = false;
    isLoadingWindowPerformance = false;
    windowRequestId = 0;
    summaryRequestId = 0;
    windowPerformanceRequestId = 0;

    connectedCallback() {
        this.loadCycleOptions();
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

    get hasSelectedCycle() {
        return !!this.selectedCycleId;
    }

    get hasWindowOptions() {
        return this.windows.length > 0;
    }

    get hasCycleOptions() {
        return this.cycles.length > 0;
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

    get selectedCycleName() {
        return this.selectedCycle?.name || '';
    }

    get selectedCycleStatus() {
        return this.selectedCycle?.status || '';
    }

    get selectedCycleStatusClass() {
        return this.selectedCycle?.statusClass || 'dash-pill';
    }

    get selectedWindowName() {
        return this.selectedWindow?.name || '';
    }

    get selectedWindowAllotmentType() {
        return this.selectedWindow?.allotmentType || '';
    }

    get selectedWindowAllotmentTypeClass() {
        return this.selectedWindow?.allotmentTypeClass || 'dash-pill';
    }

    get selectedWindowStatus() {
        return this.selectedWindow?.status || '';
    }

    get selectedWindowStatusClass() {
        return this.selectedWindow?.statusClass || 'dash-pill';
    }

    get selectedWindowDateRange() {
        return this.selectedWindow?.dateRange || '';
    }

    get showEmptyState() {
        return !this.isLoadingWindows && !this.hasSelectedWindow;
    }

    get metricCards() {
        const summary = this.summary || createDefaultSummary();

        return [
            {
                key: 'allocations',
                label: 'Total Allocations',
                value: formatNumber(summary.totalAllocations),
                helper: 'Rooms assigned this cycle',
                className: 'dash-card dash-card--blue'
            },
            {
                key: 'progress',
                label: 'In Progress',
                value: formatNumber(summary.inProgress),
                helper: 'Across all windows',
                className: 'dash-card dash-card--orange'
            },
            {
                key: 'occupancy',
                label: 'Occupancy Rate',
                value: formatPercent(summary.occupancyRate),
                helper: 'Current active buildings',
                className: 'dash-card dash-card--green'
            },
            {
                key: 'capacity',
                label: 'Total Capacity',
                value: formatNumber(summary.totalCapacity),
                helper: 'Beds across all buildings',
                className: 'dash-card dash-card--violet'
            },
            {
                key: 'available',
                label: 'Available Rooms',
                value: formatNumber(summary.availableRooms),
                helper: 'Ready for allocation',
                className: 'dash-card dash-card--teal'
            },
            {
                key: 'waitlisted',
                label: 'Waitlisted',
                value: formatNumber(summary.waitlisted),
                helper: 'Unassigned students',
                className: 'dash-card dash-card--rose'
            }
        ];
    }

    get hasWindowPerformanceRows() {
        return this.windowPerformanceRows.length > 0;
    }

    get windowPerformanceRows() {
        return (this.windowPerformance || []).map((item, index) => {
            const pendingCount = Number(item?.pending) || 0;
            return {
                key: item?.windowId || `${index}`,
                windowName: normalizeText(item?.windowName) || 'Untitled Window',
                allotmentType: normalizeText(item?.allotmentType) || 'Other',
                allotmentTypeClass: resolveAllotmentTypeClass(item?.allotmentType),
                applicationsLabel: formatNumber(item?.applications),
                allocatedLabel: formatNumber(item?.allocated),
                pendingLabel: formatNumber(pendingCount),
                pendingClass:
                    pendingCount > 0
                        ? 'dash-table-value dash-table-value--danger'
                        : 'dash-table-value dash-table-value--muted',
                status: normalizeText(item?.status),
                statusClass: resolveStatusClass(item?.status)
            };
        });
    }

    get hasCategoryOccupancy() {
        return (this.summary?.categoryOccupancy || []).length > 0;
    }

    get categoryOccupancyRows() {
        const rows = this.summary?.categoryOccupancy || [];
        return rows.map((item, index) => {
            const percentageValue = clampPercentage(item?.occupancyPercentage);
            const color = CATEGORY_PROGRESS_COLORS[index % CATEGORY_PROGRESS_COLORS.length];
            return {
                key: `${index}-${normalizeKey(item?.label) || 'category'}`,
                label: normalizeText(item?.label) || 'Uncategorized',
                valueLabel: `${formatNumber(item?.occupiedBeds)} / ${formatNumber(item?.totalCapacity)}`,
                percentageLabel: formatWholePercent(percentageValue),
                barStyle: `width: ${percentageValue}%; background: ${color};`
            };
        });
    }

    get categoryRegistrationPreviewRows() {
        const rows = Array.isArray(this.summary?.categoryRegistrations) ? this.summary.categoryRegistrations : [];
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
        return this.categoryRegistrationPreviewRows.length > 0;
    }

    get categoryOccupancyChartItems() {
        const rows = Array.isArray(this.summary?.categoryOccupancy) ? this.summary.categoryOccupancy : [];
        return rows.map((item, index) => {
            const occupiedPercentage = clampPercentage(item?.occupancyPercentage);
            const totalCapacity = Number(item?.totalCapacity) || 0;
            const occupiedBeds = Number(item?.occupiedBeds) || 0;
            const availableBeds = Math.max(totalCapacity - occupiedBeds, 0);
            const availablePercentage = totalCapacity > 0 ? Math.max(100 - occupiedPercentage, 0) : 0;

            return {
                key: `${index}-${normalizeKey(item?.label) || 'category-occupancy'}`,
                categoryName: normalizeText(item?.label) || 'Uncategorized',
                shortLabel: truncateLabel(item?.label || `Category ${index + 1}`),
                occupiedPercentageLabel: formatPercent(occupiedPercentage),
                availablePercentageLabel: formatPercent(availablePercentage),
                occupiedStyle: `height: ${occupiedPercentage}%;`,
                availableStyle: `height: ${availablePercentage}%;`,
                occupiedBedsLabel: formatNumber(occupiedBeds),
                availableBedsLabel: formatNumber(availableBeds)
            };
        });
    }

    get hasCategoryOccupancyChart() {
        return this.categoryOccupancyChartItems.length > 0;
    }

    get dashboardFinanceReportCards() {
        const collectedAmount = Number(this.summary?.totalAmountCollected) || 0;
        const pendingAmount = Number(this.summary?.pendingAmount) || 0;
        const totalAmount = Math.max(collectedAmount + pendingAmount, 0);
        const collectedPercentage = totalAmount > 0 ? (collectedAmount / totalAmount) * 100 : 0;
        const pendingPercentage = totalAmount > 0 ? (pendingAmount / totalAmount) * 100 : 0;

        return [
            {
                key: 'collected',
                title: 'Total Amount Collected',
                label: 'Collected',
                amount: collectedAmount,
                amountLabel: formatCurrency(collectedAmount),
                helper: `${formatPercent(collectedPercentage)} of scoped dues`,
                donutStyle: buildFinanceDonutStyle(collectedAmount, totalAmount, REPORT_FINANCE_COLORS.collected),
                className: 'dash-report-panel dash-report-panel--finance dash-report-panel--collected',
                donutClassName: 'dash-report-donut dash-report-donut--collected',
                helperClassName: 'dash-report-helper dash-report-helper--collected',
                reportSection: 'financeCollected'
            },
            {
                key: 'pending',
                title: 'Pending Amount',
                label: 'Pending',
                amount: pendingAmount,
                amountLabel: formatCurrency(pendingAmount),
                helper: `${formatPercent(pendingPercentage)} still outstanding`,
                donutStyle: buildFinanceDonutStyle(pendingAmount, totalAmount, REPORT_FINANCE_COLORS.pending),
                className: 'dash-report-panel dash-report-panel--finance dash-report-panel--pending',
                donutClassName: 'dash-report-donut dash-report-donut--pending',
                helperClassName: 'dash-report-helper dash-report-helper--pending',
                reportSection: 'financePending'
            }
        ];
    }

    get allocationBreakdownItems() {
        const rows = this.summary?.allocationBreakdown || [];
        return rows
            .map((item, index) => {
                const color = resolveAllocationColor(item?.label, index);
                return {
                    key: `${index}-${normalizeKey(item?.label) || 'allocation'}`,
                    label: resolveAllocationLegendLabel(item?.label),
                    count: Number(item?.count) || 0,
                    countLabel: formatNumber(item?.count),
                    color,
                    swatchStyle: `background: ${color};`
                };
            })
            .filter((item) => item.count > 0);
    }

    get hasAllocationBreakdown() {
        return this.allocationBreakdownItems.length > 0;
    }

    get allocationChartStyle() {
        return buildAllocationChartStyle(this.allocationBreakdownItems);
    }

    async loadCycleOptions() {
        this.isLoadingCycles = true;
        try {
            const cycleOptions = await getCycleOptions();
            this.cycles = (Array.isArray(cycleOptions) ? cycleOptions : []).map((option) => normalizeCycleOption(option));

            if (!this.cycles.some((cycle) => cycle.value === this.selectedCycleId)) {
                this.selectedCycleId = this.cycles.length ? this.cycles[0].value : '';
            }

            await Promise.all([this.loadWindowOptions(), this.loadWindowPerformanceOverview()]);
        } catch (error) {
            this.cycles = [];
            this.selectedCycleId = '';
            this.windowPerformance = [];
            this.resetSummary();
            this.showErrorToast('Unable to load dashboard cycles.', error);
        } finally {
            this.isLoadingCycles = false;
        }
    }

    async loadWindowOptions() {
        const requestId = ++this.windowRequestId;
        if (!this.selectedCycleId) {
            this.windows = [];
            this.selectedWindowId = '';
            this.resetSummary();
            return;
        }

        this.isLoadingWindows = true;
        try {
            const windowItems = await getWindowOptions({ cycleId: this.selectedCycleId });
            if (requestId !== this.windowRequestId) {
                return;
            }

            this.windows = (Array.isArray(windowItems) ? windowItems : []).map((item) => normalizeWindowOption(item));
            if (!this.windows.some((windowRecord) => windowRecord.id === this.selectedWindowId)) {
                this.selectedWindowId = this.windows.length ? this.windows[0].id : '';
            }

            await this.loadDashboardSummary();
        } catch (error) {
            if (requestId !== this.windowRequestId) {
                return;
            }
            this.windows = [];
            this.selectedWindowId = '';
            this.resetSummary();
            this.showErrorToast('Unable to load dashboard windows.', error);
        } finally {
            if (requestId === this.windowRequestId) {
                this.isLoadingWindows = false;
            }
        }
    }

    async loadDashboardSummary() {
        const requestId = ++this.summaryRequestId;
        if (!this.selectedWindowId) {
            this.resetSummary();
            return;
        }

        this.isLoadingSummary = true;
        try {
            const summary = await getDashboardSummary({ windowId: this.selectedWindowId });
            if (requestId !== this.summaryRequestId) {
                return;
            }

            this.summary = {
                ...createDefaultSummary(),
                ...(summary || {})
            };
        } catch (error) {
            if (requestId !== this.summaryRequestId) {
                return;
            }
            this.resetSummary();
            this.showErrorToast('Unable to load dashboard metrics.', error);
        } finally {
            if (requestId === this.summaryRequestId) {
                this.isLoadingSummary = false;
            }
        }
    }

    async loadWindowPerformanceOverview() {
        const requestId = ++this.windowPerformanceRequestId;
        if (!this.selectedCycleId) {
            this.windowPerformance = [];
            this.isLoadingWindowPerformance = false;
            return;
        }

        this.isLoadingWindowPerformance = true;
        try {
            const rows = await getWindowPerformanceOverview({ cycleId: this.selectedCycleId });
            if (requestId !== this.windowPerformanceRequestId) {
                return;
            }

            this.windowPerformance = Array.isArray(rows) ? rows : [];
        } catch (error) {
            if (requestId !== this.windowPerformanceRequestId) {
                return;
            }
            this.windowPerformance = [];
            this.showErrorToast('Unable to load cycle window overview.', error);
        } finally {
            if (requestId === this.windowPerformanceRequestId) {
                this.isLoadingWindowPerformance = false;
            }
        }
    }

    async handleCycleChange(event) {
        this.selectedCycleId = event.target.value;
        this.selectedWindowId = '';
        this.windowPerformance = [];
        this.resetSummary();
        await Promise.all([this.loadWindowOptions(), this.loadWindowPerformanceOverview()]);
    }

    async handleWindowChange(event) {
        this.selectedWindowId = event.target.value;
        this.resetSummary();
        await this.loadDashboardSummary();
    }

    handleViewCycle() {
        if (!this.selectedCycleId) {
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.selectedCycleId,
                objectApiName: 'Hostel_Cycle__c',
                actionName: 'view'
            }
        });
    }

    handleViewReports(event) {
        const reportSection = event.currentTarget?.dataset?.section;
        if (!reportSection) {
            return;
        }

        this.dispatchEvent(
            new CustomEvent('quickaction', {
                detail: {
                    action: 'reports',
                    cycleId: this.selectedCycleId || '',
                    windowId: this.selectedWindowId || '',
                    reportSection
                },
                bubbles: true,
                composed: true
            })
        );
    }

    resetSummary() {
        this.summary = createDefaultSummary();
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