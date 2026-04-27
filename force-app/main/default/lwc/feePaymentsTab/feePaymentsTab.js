import { LightningElement, track, wire, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';
import getPortalFeePaymentData from '@salesforce/apex/OrganizationDefaultsApiController.getPortalFeePaymentData';

function normalizeStatus(status) {
    const value = String(status || '').trim().toLowerCase();
    if (value === 'success') {
        return 'Success';
    }
    if (value === 'failed') {
        return 'Failed';
    }
    if (value === 'refund') {
        return 'Refund Processed';
    }
    return 'Pending';
}

function formatDate(value) {
    if (!value) {
        return '--';
    }

    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
        return value;
    }

    return new Intl.DateTimeFormat('en-GB', {
        day: '2-digit',
        month: 'short',
        year: 'numeric'
    }).format(date);
}

function formatNumber(value) {
    return new Intl.NumberFormat('en-IN', {
        minimumFractionDigits: 0,
        maximumFractionDigits: 0
    }).format(Number(value || 0));
}

export default class FeePaymentsTab extends LightningElement {
    @track activeTab = 'feePayments';
    @track searchTerm = '';
    @api requestForCard = {};
    accountId;
    isHelpModalOpen = false;
    organizationDefaults = {};
    isLoading = false;
    feeAssignments = [];
    invoiceRows = [];
    transactionRows = [];
    refundRows = [];
    loadError = '';

    tabs = [
        { label: 'Fee Payment', value: 'feePayments' },
        { label: 'Fee Plan', value: 'feePlan' },
        { label: 'Invoices', value: 'invoices' },
        { label: 'Transaction History', value: 'transactionHistory' },
        { label: 'Refunds', value: 'refunds' }
    ];

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.accountId = currentPageReference.state?.c__accountId;
            const requestedTab = currentPageReference.state?.c__tab;
            if (this.tabs.some((tab) => tab.value === requestedTab)) {
                this.activeTab = requestedTab;
            }
        }
    }

    applyOrganizationTheme() {
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
    wiredOrganizationDefaults({ data, error }) {
        if (data) {
            this.organizationDefaults = data;
            this.applyOrganizationTheme();
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Organization Defaults load error', error);
            this.organizationDefaults = {};
        }
    }

    connectedCallback() {
        this.loadPortalData();
    }

    get decoratedTabs() {
        return this.tabs.map((tab) => ({
            ...tab,
            className: this.activeTab === tab.value ? 'tab-link active' : 'tab-link'
        }));
    }

    get headerActionsClass() {
        return this.showSearch ? 'header-actions' : 'header-actions header-actions-mobile-hidden';
    }

    get isFeePaymentsTab() {
        return this.activeTab === 'feePayments';
    }

    get isTransactionHistoryTab() {
        return this.activeTab === 'transactionHistory';
    }

    get isInvoicesTab() {
        return this.activeTab === 'invoices';
    }

    get isRefundsTab() {
        return this.activeTab === 'refunds';
    }

    get isFeePlanTab() {
        return this.activeTab === 'feePlan';
    }

    get activeTabLabel() {
        const active = this.tabs.find((tab) => tab.value === this.activeTab);
        return active ? active.label : '';
    }

    get searchPlaceholder() {
        if (this.activeTab === 'refunds') {
            return 'Search by Keywords or Credit Note No';
        }
        if (this.activeTab === 'transactionHistory') {
            return 'Search for Keywords or Transaction ID';
        }
        return 'Search by Keywords or Invoice ID';
    }

    get defaultIssueType() {
        return this.activeTabLabel || 'Fee Payment';
    }

    get showSearch() {
        return this.isInvoicesTab || this.isTransactionHistoryTab || this.isRefundsTab;
    }

    async loadPortalData() {
        this.isLoading = true;
        this.loadError = '';

        try {
            const responseText = await getPortalFeePaymentData();
            const response =
                typeof responseText === 'string' ? JSON.parse(responseText) : responseText;
            const feeAssignments = Array.isArray(response?.feeAssignments)
                ? response.feeAssignments
                : [];
            const transactions = Array.isArray(response?.transactions)
                ? response.transactions
                : [];
            const invoices = Array.isArray(response?.invoices)
                ? response.invoices
                : [];

            this.feeAssignments = feeAssignments;
            this.invoiceRows = invoices.map((row, index) => ({
                id: row?.id || `invoice-${index + 1}`,
                particulars: row?.title || `Invoice ${index + 1}`,
                invoiceId: row?.reference || `INV-${index + 1}`,
                invoiceDate: '--',
                totalPaid: '--',
                currency: 'INR',
                remaining: '--',
                invoiceAvailable: row?.isAvailable === true
            }));

            this.transactionRows = transactions
                .filter((row) => String(row?.type || '').toLowerCase() !== 'refund')
                .map((row, index) => ({
                    id: row?.id || `transaction-${index + 1}`,
                    transactionId: row?.reference || `TXN-${index + 1}`,
                    transactionDate: formatDate(row?.transactionDate),
                    paymentMode: '--',
                    currency: 'INR',
                    totalPaid: formatNumber(row?.amount),
                    status: normalizeStatus(row?.status),
                    canDownloadReceipt: String(row?.status || '').toLowerCase() === 'success'
                }));

            this.refundRows = transactions
                .filter((row) => String(row?.type || '').toLowerCase() === 'refund')
                .map((row, index) => ({
                    id: row?.id || `refund-${index + 1}`,
                    refundId: row?.reference || `RF-${index + 1}`,
                    initiatedDate: formatDate(row?.transactionDate),
                    currency: 'INR',
                    amount: formatNumber(row?.amount),
                    refundDate: formatDate(row?.transactionDate),
                    transactionId: row?.reference || `TXN-${index + 1}`,
                    status: 'Refund Processed',
                    canDownloadReceipt: true
                }));
        } catch (error) {
            this.feeAssignments = [];
            this.invoiceRows = [];
            this.transactionRows = [];
            this.refundRows = [];
            this.loadError = error?.body?.message || error?.message || 'Unable to load fee payment data.';
        } finally {
            this.isLoading = false;
        }
    }

    handleTabChange(event) {
        this.activeTab = event.currentTarget.dataset.value;
        this.searchTerm = '';
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value || '';
    }

    openHelpModal() {
        this.isHelpModalOpen = true;
    }

    closeHelpModal() {
        this.isHelpModalOpen = false;
    }

    handleHelpSubmit() {
        this.isHelpModalOpen = false;
    }
}