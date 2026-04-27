import { api, LightningElement } from 'lwc';
import FORM_FACTOR from '@salesforce/client/formFactor';
import sortSvg from '@salesforce/resourceUrl/sortsvg';
import desktopTemplate from './feePlanModule.html';
import mobileTemplate from './feePlanModuleMobile.html';

function parseDueDate(value) {
    if (!value) {
        return 0;
    }

    return new Date(value).getTime();
}

export default class FeePlanModule extends LightningElement {
    @api feeAssignments = [];
    @api isLoading = false;
    sortIcon = sortSvg;
    sortDirection = 'asc';

    render() {
        return FORM_FACTOR === 'Small' ? mobileTemplate : desktopTemplate;
    }

    get semesters() {
        const assignments = Array.isArray(this.feeAssignments) ? this.feeAssignments : [];
        const totalFee = assignments.reduce(
            (sum, assignment) => sum + Number(assignment?.totalPayable || assignment?.totalAmount || 0),
            0
        );

        return [
            {
                id: 'current-fee-plan',
                program: 'Fee Plan',
                semester: 'Current Plan',
                totalFeeAmount: this.formatCurrency(totalFee),
                expanded: true,
                feeItems: assignments.map((assignment, index) => this.mapAssignment(assignment, index))
            }
        ];
    }

    get semesterRows() {
        return this.semesters.map((semester) => {
            const sortedItems = [...semester.feeItems].sort((first, second) =>
                this.sortDirection === 'asc'
                    ? parseDueDate(first.dueDate) - parseDueDate(second.dueDate)
                    : parseDueDate(second.dueDate) - parseDueDate(first.dueDate)
            );
            const items = sortedItems.map((item, index) => this.decorateFeeItem(item, index));

            return {
                ...semester,
                statuslessHeader: !semester.feeItems.length,
                toggleIcon: semester.expanded ? 'utility:chevronup' : 'utility:chevrondown',
                toggleLabel: semester.expanded ? 'Collapse semester' : 'Expand semester',
                hasItems: items.length > 0,
                rows: this.flattenRows(items)
            };
        });
    }

    get mobileSemesters() {
        return this.semesters.map((semester) => {
            const sortedItems = [...semester.feeItems].sort((first, second) =>
                this.sortDirection === 'asc'
                    ? parseDueDate(first.dueDate) - parseDueDate(second.dueDate)
                    : parseDueDate(second.dueDate) - parseDueDate(first.dueDate)
            );

            return {
                ...semester,
                headerStatusLabel: semester.id === 'semester-1' ? 'Ongoing' : '',
                showHeaderStatus: semester.id === 'semester-1',
                toggleIcon: semester.expanded ? 'utility:chevronup' : 'utility:chevrondown',
                toggleLabel: semester.expanded ? 'Collapse semester' : 'Expand semester',
                items: sortedItems.map((item) => this.decorateMobileItem(item))
            };
        });
    }

    handleSemesterToggle(event) {
        const semesterId = event.currentTarget.dataset.semesterId;
        void semesterId;
    }

    handleFeeToggle(event) {
        const semesterId = event.currentTarget.dataset.semesterId;
        const itemId = event.currentTarget.dataset.itemId;
        void semesterId;
        void itemId;
    }

    handleDueDateSort() {
        this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
    }

    decorateFeeItem(item, index) {
        const sortedChildren = [...(item.children || [])].sort((first, second) =>
            this.sortDirection === 'asc'
                ? parseDueDate(first.dueDate) - parseDueDate(second.dueDate)
                : parseDueDate(second.dueDate) - parseDueDate(first.dueDate)
        );

        return {
            ...item,
            rowClass: index % 2 === 0 ? 'plan-row' : 'plan-row alt-row',
            statusClass: `plan-status ${item.statusVariant}`,
            toggleIcon: item.expanded ? 'utility:chevronup' : 'utility:chevrondown',
            toggleLabel: item.expanded ? 'Collapse fee item' : 'Expand fee item',
            hasChildren: item.children && item.children.length > 0,
            children: sortedChildren.map((child, childIndex) => ({
                ...child,
                rowClass: this.buildChildRowClass(childIndex, sortedChildren.length)
            }))
        };
    }

    flattenRows(items) {
        return items.flatMap((item) => {
            const rows = [
                {
                    ...item,
                    key: `parent-${item.id}`,
                    isParent: true
                }
            ];

            if (item.expanded && item.children.length) {
                item.children.forEach((child) => {
                    rows.push({
                        ...child,
                        key: `child-${item.id}-${child.id}`,
                        isChild: true
                    });
                });
            }

            return rows;
        });
    }

    buildChildRowClass(index, length) {
        let className = 'child-plan-row';

        if (index === 0) {
            className += ' first-child-row';
        }

        if (index === length - 1) {
            className += ' last-child-row';
        }

        return className;
    }

    decorateMobileItem(item) {
        const sortedChildren = [...(item.children || [])].sort((first, second) =>
            this.sortDirection === 'asc'
                ? parseDueDate(first.dueDate) - parseDueDate(second.dueDate)
                : parseDueDate(second.dueDate) - parseDueDate(first.dueDate)
        );

        return {
            ...item,
            showStatus: Boolean(item.status),
            statusClass: item.status ? `plan-status ${item.statusVariant}` : '',
            toggleIcon: item.expanded ? 'utility:chevronup' : 'utility:chevrondown',
            toggleLabel: item.expanded ? 'Collapse fee item' : 'Expand fee item',
            hasChildren: sortedChildren.length > 0,
            children: sortedChildren.map((child) => ({
                ...child,
                hasStatus: Boolean(child.status),
                statusClass: child.status ? `plan-status ${child.statusVariant}` : ''
            }))
        };
    }

    mapAssignment(assignment, index) {
        const totalAmount = Number(assignment?.totalAmount || 0);
        const totalPayable = Number(assignment?.totalPayable ?? totalAmount);
        const paidAmount = Number(assignment?.paidAmount || 0);
        const lineItems = Array.isArray(assignment?.lineItems) ? assignment.lineItems : [];

        return {
            id: assignment?.id || `fee-plan-${index + 1}`,
            name: assignment?.feeItem || `Fee Item ${index + 1}`,
            dueDate: assignment?.dueDate || '--',
            currency: assignment?.currencyIsoCode || 'INR',
            totalAmount: this.formatNumber(totalAmount),
            concession: this.formatNumber(Math.max(totalAmount - totalPayable, 0)),
            tax: this.formatNumber(assignment?.tax || 0),
            tds: this.formatNumber(assignment?.tds || 0),
            totalPayable: this.formatNumber(totalPayable),
            status: totalPayable === 0 ? 'Pending' : paidAmount >= totalPayable ? 'Paid' : paidAmount > 0 ? 'Partially Paid' : 'Pending',
            statusVariant: paidAmount >= totalPayable ? 'fully-paid' : paidAmount > 0 ? 'partially-paid' : 'pending',
            expanded: true,
            children: lineItems.map((lineItem, childIndex) =>
                this.mapLineItem(lineItem, childIndex)
            )
        };
    }

    mapLineItem(lineItem, index) {
        const totalAmount = Number(lineItem?.totalAmount || 0);
        const totalPayable = Number(lineItem?.totalPayable ?? totalAmount);

        return {
            id: lineItem?.id || `fee-plan-line-${index + 1}`,
            name: lineItem?.feeItem || `Line Item ${index + 1}`,
            dueDate: lineItem?.dueDate || '--',
            currency: lineItem?.currencyIsoCode || 'INR',
            totalAmount: this.formatNumber(totalAmount),
            concession: this.formatNumber(Math.max(totalAmount - totalPayable, 0)),
            tax: this.formatNumber(lineItem?.tax || 0),
            tds: this.formatNumber(lineItem?.tds || 0),
            totalPayable: this.formatNumber(totalPayable)
        };
    }

    formatNumber(value) {
        return new Intl.NumberFormat('en-IN', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(Number(value || 0));
    }

    formatCurrency(value) {
        return `₹${this.formatNumber(value)}/-`;
    }
}