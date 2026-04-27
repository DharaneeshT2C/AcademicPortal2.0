import { api, LightningElement } from 'lwc';
import sortSvg from '@salesforce/resourceUrl/sortsvg';
import FORM_FACTOR from '@salesforce/client/formFactor';
import desktopTemplate from './feePaymentsModule.html';
import mobileTemplate from './feePaymentsModuleMobile.html';

function normalizeAmount(value) {
    return value === '--' || value === null || value === undefined ? 0 : Number(value);
}

function getDefaultPaymentAmount(record) {
    return normalizeAmount(record.remaining) + normalizeAmount(record.lateFee);
}

function parseDueDate(value) {
    if (!value) {
        return 0;
    }

    return new Date(value).getTime();
}

export default class FeePaymentsModule extends LightningElement {
    @api feeAssignments = [];
    @api isLoading = false;
    selectedCategory = 'academic';
    sortDirection = 'asc';
    activeInfoRowId = null;
    activeInfoPopoverPosition = 'bottom';
    sortIcon = sortSvg;


       render() {
        return FORM_FACTOR === 'Small' ? mobileTemplate : desktopTemplate;
    }
    
    feeCategories = [
        { id: 'academic', label: 'Academic Fees' },
        { id: 'nonAcademic', label: 'Non - Academic Fees' }
    ];

    get programData() {
        return this.initializeProgramData({
            academic: [this.buildProgram('academic')],
            nonAcademic: [this.buildProgram('nonAcademic')]
        });
    }

    get categoryTabs() {
        return this.feeCategories.map((category) => ({
            ...category,
            className: this.selectedCategory === category.id ? 'category-tab active' : 'category-tab'
        }));
    }

    get programs() {
        const programs = this.programData[this.selectedCategory] || [];

        return programs.map((program) => {
            const summaryItems = this.buildSummaryItems(program);
            const sortedFeeItems = [...program.feeItems].sort((first, second) =>
                this.sortDirection === 'asc'
                    ? parseDueDate(first.dueDate) - parseDueDate(second.dueDate)
                    : parseDueDate(second.dueDate) - parseDueDate(first.dueDate)
            );
            const feeItems = sortedFeeItems.map((item, index) => this.decorateFeeItem(item, index));

            return {
                ...program,
                headerClass: program.expanded ? 'semester-card expanded' : 'semester-card collapsed',
                statusClass: `semester-status ${program.statusVariant}`,
                showStatusDot: program.statusVariant === 'ongoing',
                toggleLabel: program.expanded ? 'Collapse semester' : 'Expand semester',
                toggleIcon: program.expanded ? 'utility:chevronup' : 'utility:chevrondown',
                hasFeeItems: program.feeItems.length > 0,
                summaryItems,
                decoratedFeeItems: feeItems,
                tableRows: this.buildTableRows(feeItems)
            };
        });
    }

    get selectedAmountDisplay() {
        const total = (this.programData[this.selectedCategory] || []).reduce(
            (programTotal, program) =>
                programTotal + program.feeItems.reduce((itemTotal, item) => itemTotal + this.getSelectedAmount(item), 0),
            0
        );

        return total ? this.formatCurrency(total) : '--';
    }

    get showFeePeriod() {
        return this.selectedCategory === 'nonAcademic';
    }

    get feesTableClass() {
        return this.showPaymentAmountColumn ? 'fees-table has-payment-amount' : 'fees-table';
    }

    get emptyColspan() {
        let count = this.showFeePeriod ? 10 : 9;

        if (this.showPaymentAmountColumn) {
            count += 1;
        }

        return String(count);
    }

    get showPaymentAmountColumn() {
        return (this.programData[this.selectedCategory] || []).some((program) =>
            program.feeItems.some(
                (item) => item.selected || (item.children || []).some((child) => child.selected)
            )
        );
    }

    handleCategoryClick(event) {
        this.selectedCategory = event.currentTarget.dataset.category;
    }

    handleDueDateSort() {
        this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
    }

    handleInfoToggle(event) {
        const rowId = event.currentTarget.dataset.rowId;
        const isClosing = this.activeInfoRowId === rowId;
        this.activeInfoRowId = isClosing ? null : rowId;
        this.activeInfoPopoverPosition = 'bottom';

        if (!isClosing) {
            requestAnimationFrame(() => this.updateInfoPopoverPosition());
        }
    }

    updateInfoPopoverPosition() {
        const popover = this.template.querySelector('.info-popover');
        const trigger = this.template.querySelector(`.info-chip[data-row-id="${this.activeInfoRowId}"]`);
        const scrollContainer = this.template.querySelector('.container-div');

        if (!popover || !trigger || !scrollContainer) {
            return;
        }

        const popoverRect = popover.getBoundingClientRect();
        const triggerRect = trigger.getBoundingClientRect();
        const containerRect = scrollContainer.getBoundingClientRect();
        const wouldOverflowBottom = popoverRect.bottom > containerRect.bottom;
        const topSpace = triggerRect.top - containerRect.top;
        const needsTopPlacement = wouldOverflowBottom && topSpace >= popoverRect.height + 12;

        if (needsTopPlacement) {
            this.activeInfoPopoverPosition = 'top';
        }
    }

    handleProgramToggle(event) {
        const programId = event.currentTarget.dataset.programId;
        void programId;
    }

    handleItemToggle(event) {
        const programId = event.currentTarget.dataset.programId;
        const itemId = event.currentTarget.dataset.itemId;
        void programId;
        void itemId;
    }

    handleCheckboxChange(event) {
        void event;
    }

    handlePaymentAmountChange(event) {
        void event;
    }

    decorateFeeItem(item, index) {
        const hasChildren = item.children && item.children.length > 0;
        const childSelectionCount = hasChildren ? item.children.filter((child) => child.selected).length : 0;
        const isPartial = hasChildren && childSelectionCount > 0 && childSelectionCount < item.children.length;
        const itemAmount = hasChildren
            ? item.children.reduce((total, child) => total + child.remaining, 0)
            : item.remaining;
        const sortedChildren = [...(item.children || [])].sort((first, second) =>
            this.sortDirection === 'asc'
                ? parseDueDate(first.dueDate) - parseDueDate(second.dueDate)
                : parseDueDate(second.dueDate) - parseDueDate(first.dueDate)
        );

        return {
            ...item,
            rowClass: index % 2 === 0 ? 'fee-row' : 'fee-row zebra',
            feeParentClass: hasChildren ? 'fee-parent fee-parent--plain' : 'fee-parent',
            amountDisplay: this.formatNumber(item.totalPayable),
            paidDisplay: this.formatNumber(item.totalPaid),
            remainingDisplay: this.formatNumber(item.remaining),
            lateFeeDisplay: this.formatLateFee(item.lateFee),
            feePeriodDisplay: item.feePeriod || '--',
            statusClass: `payment-status ${item.statusVariant}`,
            hasChildren,
            infoPopoverClass:
                this.activeInfoRowId === item.id && this.activeInfoPopoverPosition === 'top'
                    ? 'info-popover info-popover-top'
                    : 'info-popover',
            toggleLabel: item.expanded ? 'Collapse fee row' : 'Expand fee row',
            toggleIcon: item.expanded ? 'utility:chevronup' : 'utility:chevrondown',
            selectionAmount: this.formatCurrency(itemAmount),
            paymentAmountDisplay: item.selected ? this.formatNumber(item.paymentAmount || getDefaultPaymentAmount(item)) : '',
            isPaymentEditable: false,
            showInfoPopover: this.activeInfoRowId === item.id,
            partialClass: isPartial ? 'checkbox-shell partial' : 'checkbox-shell',
            children: sortedChildren.map((child, childIndex) => ({
                ...child,
                rowClass: this.buildChildRowClass(childIndex, item.children.length),
                amountDisplay: this.formatNumber(child.totalPayable),
                paidDisplay: this.formatNumber(child.totalPaid),
                remainingDisplay: this.formatNumber(child.remaining),
                lateFeeDisplay: this.formatLateFee(child.lateFee),
                feePeriodDisplay: child.feePeriod || '--',
                statusClass: `payment-status ${child.statusVariant}`,
                paymentAmountDisplay: child.selected ? this.formatNumber(child.paymentAmount || getDefaultPaymentAmount(child)) : '',
                isPaymentEditable: child.selected
            }))
        };
    }

    buildSummaryItems(program) {
        const items = [
            {
                label: 'Total Fee Amount',
                value: this.formatCurrency(program.totals.fee)
            }
        ];

        if (program.expanded) {
            items.push(
                {
                    label: 'Total Due Amount',
                    value: this.formatCurrency(program.totals.due)
                },
                {
                    label: 'Total Paid',
                    value: this.formatCurrency(program.totals.paid)
                }
            );
        }

        return items;
    }

    buildTableRows(feeItems) {
        return feeItems.flatMap((item) => {
            const rows = [
                {
                    ...item,
                    key: `parent-${item.id}`,
                    isParent: true,
                    sourceItemId: item.id
                }
            ];

	            if (item.expanded && item.children.length) {
	                item.children.forEach((child) => {
	                    rows.push({
	                        ...child,
	                        key: `child-${item.id}-${child.id}`,
	                        isChild: true,
	                        parentId: item.id,
	                        isSelectionDisabled: item.selected,
	                        sourceItemId: item.id,
	                        partialClass: 'checkbox-shell'
	                    });
	                });
	            }

            return rows;
        });
    }

    getSelectedAmount(item) {
        if (item.selected) {
            return item.paymentAmount || getDefaultPaymentAmount(item);
        }

        if (item.children && item.children.length) {
            return item.children.reduce((total, child) => total + (child.selected ? child.paymentAmount || getDefaultPaymentAmount(child) : 0), 0);
        }

        return item.selected ? item.paymentAmount || getDefaultPaymentAmount(item) : 0;
    }

    formatLateFee(value) {
        return value === '--' ? value : this.formatNumber(value);
    }

    formatCurrency(value) {
        return `₹${this.formatNumber(value)}/-`;
    }

    formatNumber(value) {
        return new Intl.NumberFormat('en-IN', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(value);
    }

    buildChildRowClass(index, length) {
        let className = 'child-row';

        if (index === 0) {
            className += ' first-child-row';
        }

        if (index === length - 1) {
            className += ' last-child-row';
        }

        return className;
    }

    initializeProgramData(data) {
        return Object.fromEntries(
            Object.entries(data).map(([category, programs]) => [
                category,
                programs.map((program) => ({
                    ...program,
                    feeItems: program.feeItems.map((item) => ({
                        ...item,
                        paymentAmount: getDefaultPaymentAmount(item),
                        children: (item.children || []).map((child) => ({
                            ...child,
                            paymentAmount: getDefaultPaymentAmount(child)
                        }))
                    }))
                }))
            ])
        );
    }

    parseAmount(value) {
        const parsed = Number(String(value).replace(/,/g, '').trim());
        return Number.isFinite(parsed) ? parsed : 0;
    }

    buildProgram(category) {
        const feeItems = category === 'academic'
            ? this.mapAssignments(Array.isArray(this.feeAssignments) ? this.feeAssignments : [])
            : [];

        const totalFee = feeItems.reduce((sum, item) => sum + normalizeAmount(item.totalPayable), 0);
        const totalPaid = feeItems.reduce((sum, item) => sum + normalizeAmount(item.totalPaid), 0);
        const totalDue = feeItems.reduce((sum, item) => sum + normalizeAmount(item.remaining), 0);

        return {
            id: `${category}-fees`,
            program: category === 'academic' ? 'Fee Payments' : 'Non-Academic Fees',
            semester: category === 'academic' ? 'Current Assignments' : 'Current Assignments',
            statusLabel: totalDue > 0 ? 'Ongoing' : 'Completed',
            statusVariant: totalDue > 0 ? 'ongoing' : 'upcoming',
            expanded: true,
            totals: {
                fee: totalFee,
                due: totalDue,
                paid: totalPaid
            },
            feeItems
        };
    }

    mapAssignments(assignments) {
        return assignments.map((assignment, index) => {
            const totalPayable = Number(assignment?.totalPayable || 0);
            const totalPaid = Number(assignment?.paidAmount || 0);
            const remaining = Math.max(totalPayable - totalPaid, 0);
            const lineItems = Array.isArray(assignment?.lineItems) ? assignment.lineItems : [];

            return {
                id: assignment?.id || `assignment-${index + 1}`,
                name: assignment?.feeItem || `Fee Item ${index + 1}`,
                dueDate: assignment?.dueDate || '--',
                currency: assignment?.currencyIsoCode || 'INR',
                totalPayable,
                totalPaid,
                remaining,
                lateFee: '--',
                status: remaining === 0 ? 'Fully Paid' : totalPaid > 0 ? 'Partially Paid' : 'Pending',
                statusVariant: remaining === 0 ? 'fully-paid' : totalPaid > 0 ? 'partially-paid' : 'pending',
                expanded: true,
                info: true,
                infoDetails: {
                    title: assignment?.feeItem || `Fee Item ${index + 1}`,
                    totalPayable: `INR ${this.formatNumber(totalPayable)}`,
                    totalFees: `INR ${this.formatNumber(assignment?.totalAmount || totalPayable)}`,
                    concession: `INR ${this.formatNumber(Math.max(Number(assignment?.totalAmount || totalPayable) - totalPayable, 0))}`,
                    tax: `INR ${this.formatNumber(assignment?.tax || 0)}`,
                    tds: `INR ${this.formatNumber(assignment?.tds || 0)}`
                },
                selected: false,
                paymentAmount: remaining,
                children: lineItems.map((lineItem, childIndex) =>
                    this.mapLineItem(lineItem, assignment, childIndex)
                )
            };
        });
    }

    mapLineItem(lineItem, assignment, index) {
        const assignmentTotal = Number(assignment?.totalPayable || assignment?.totalAmount || 0);
        const assignmentPaid = Number(assignment?.paidAmount || 0);
        const lineTotalPayable = Number(lineItem?.totalPayable || lineItem?.totalAmount || 0);
        const linePaid = assignmentTotal > 0
            ? Math.min(lineTotalPayable, (assignmentPaid / assignmentTotal) * lineTotalPayable)
            : 0;
        const remaining = Math.max(lineTotalPayable - linePaid, 0);

        return {
            id: lineItem?.id || `line-item-${index + 1}`,
            name: lineItem?.feeItem || `Installment ${index + 1}`,
            dueDate: lineItem?.dueDate || assignment?.dueDate || '--',
            currency: lineItem?.currencyIsoCode || assignment?.currencyIsoCode || 'INR',
            totalPayable: lineTotalPayable,
            totalPaid: linePaid,
            remaining,
            lateFee: '--',
            status: remaining === 0 ? 'Fully Paid' : linePaid > 0 ? 'Partially Paid' : 'Pending',
            statusVariant: remaining === 0 ? 'fully-paid' : linePaid > 0 ? 'partially-paid' : 'pending',
            selected: false,
            paymentAmount: remaining
        };
    }
}