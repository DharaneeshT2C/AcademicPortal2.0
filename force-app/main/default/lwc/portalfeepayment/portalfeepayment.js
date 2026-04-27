import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import FORM_FACTOR from "@salesforce/client/formFactor";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import desktopTemplate from "./portalfeepayment.html";
import mobileTemplate from "./portalfeepaymentMobile.html";
import OrganizationDefaultsApiController from "@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults";
import getCurrentUserPortalPlanAssignments from "@salesforce/apex/PortalFeePaymentController.getCurrentUserPortalPlanAssignments";
import createPaymentLink from "@salesforce/apex/RazorpayPaymentLinkService.createPaymentLink";


const PAYMENT_GATEWAYS = [
  { label: "Credit / Debit Card", value: "card" },
  { label: "Net Banking", value: "netbanking" },
  { label: "UPI", value: "upi" },
];

const INITIAL_INVOICES = [
  {
    id: "inv-1",
    title: "2026 MBA Jul Sem 1",
    reference: "DG3749D9030",
    isAvailable: false,
  },
  {
    id: "inv-2",
    title: "2026 MBA Jan Sem 2",
    reference: "JH3647893894",
    isAvailable: true,
  },
  {
    id: "inv-3",
    title: "2026 MBA Jan Sem 2",
    reference: "JH3647893895",
    isAvailable: true,
  },
];

const INITIAL_TRANSACTIONS = [
  {
    id: "txn-1",
    reference: "DG3749D9030",
    date: "2026-09-17",
    status: "success",
    amount: 40000,
    type: "payment",
  },
  {
    id: "txn-2",
    reference: "DG3749D9031",
    date: "2026-10-18",
    status: "failed",
    amount: 12000,
    type: "payment",
  },
  {
    id: "txn-3",
    reference: "DG3749D9032",
    date: "2026-09-17",
    status: "success",
    amount: 5000,
    type: "refund",
  },
  {
    id: "txn-4",
    reference: "DG3749D9033",
    date: "2026-09-17",
    status: "success",
    amount: 8000,
    type: "payment",
  },
];

function formatCurrency(amount) {
  return `INR ${new Intl.NumberFormat("en-IN", {
    maximumFractionDigits: 0,
  }).format(Number(amount) || 0)}`;
}

function formatDate(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return new Intl.DateTimeFormat("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  }).format(date);
}

function buildTransactionReference(seed) {
  return `DG${String(seed).padStart(10, "0")}`;
}

function buildChildRow(childRow, fallbackId) {
  const paidAmount = Number(childRow.paidAmount || 0);
  const totalPayable = Number(childRow.totalPayable || 0);
  const balanceDue = Math.max(totalPayable - paidAmount, 0);
  const rawStatus = childRow.statusLabel || (balanceDue === 0 ? "Fully Paid" : paidAmount > 0 ? "Partially Paid" : "Pending");

  return {
    ...childRow,
    id: childRow.id || fallbackId,
    totalAmountDisplay: formatCurrency(childRow.totalAmount),
    taxDisplay: formatCurrency(childRow.tax),
    tdsDisplay: formatCurrency(childRow.tds),
    totalPayableDisplay: formatCurrency(childRow.totalPayable),
    concessionDisplay: formatCurrency(childRow.concessionAmount || 0),
    paidAmountDisplay: paidAmount ? formatCurrency(paidAmount) : "--",
    balanceDueDisplay: formatCurrency(balanceDue),
    statusLabel: rawStatus,
    statusClass:
      rawStatus === "Fully Paid"
        ? "status-chip status-chip-success"
        : rawStatus === "Partially Paid"
          ? "status-chip status-chip-warn"
          : "status-chip status-chip-outline",
  };
}

export default class Portalfeepayment extends NavigationMixin(LightningElement) {
  programName = "Master of Business Administration (MBA)";
  cohortLabel = "";
  programStatus = "Ongoing";

  organizationDefaults = {};

  feeRows = [];
  invoiceRows = INITIAL_INVOICES.map((row) => ({ ...row }));
  transactionRows = INITIAL_TRANSACTIONS.map((row) => ({ ...row }));

  showAllInvoices = false;
  showAllTransactions = false;
  showRefundsOnly = false;
  expandAllRows = false;

  isPaymentModalOpen = false;
  isSubmittingPayment = false;
  selectedPayableItemId = null;
  paymentAmount = 10000;
  selectedGateway = PAYMENT_GATEWAYS[0].value;
  retryTransactionId = null;

  applyOrganizationTheme() {
    const primary = this.organizationDefaults?.primary;
    const secondary = this.organizationDefaults?.secondary;

    if (primary && typeof primary === "string") {
      this.template.host.style.setProperty("--primary-color", primary);
    }
    if (secondary && typeof secondary === "string") {
      this.template.host.style.setProperty("--secondary-color", secondary);
    }
  }

  @wire(OrganizationDefaultsApiController)
  wiredOrganizationDefaults({ data, error }) {
    if (data) {
      this.organizationDefaults = data;
      this.applyOrganizationTheme();
    } else if (error) {
      // eslint-disable-next-line no-console
      console.error("Organization Defaults load error", error);
      this.organizationDefaults = {};
    }
  }

  connectedCallback() {
    this.loadFeeRows();
  }

  async loadFeeRows() {
    try {
      const rows = await getCurrentUserPortalPlanAssignments();
      this.feeRows = this.mapFeeRows(rows);

      if (FORM_FACTOR === "Small" && this.feeRows.length) {
        this.feeRows = this.feeRows.map((row, index) => ({
          ...row,
          isExpanded: index === 0,
        }));
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Fee rows load error", error);
      this.feeRows = [];
    }

    this.syncSelectedPayableItem();
  }

  render() {
    return FORM_FACTOR === "Small" ? mobileTemplate : desktopTemplate;
  }

  get mobilePlanRows() {
    return this.planRows;
  }

  get expandButtonLabel() {
    return "View Plan";
  }

  get mobileInvoiceButtonLabel() {
    return "View All";
  }

  get mobileTransactionFooterLabel() {
    return "View all Transactions";
  }

  get gatewayOptions() {
    return PAYMENT_GATEWAYS;
  }

  get totalFee() {
    return this.feeRows.reduce(
      (sum, row) => sum + Number(row.totalPayable || 0),
      0,
    );
  }

  get totalPaid() {
    return this.feeRows.reduce(
      (sum, row) => sum + Number(row.paidAmount || 0),
      0,
    );
  }

  get totalPending() {
    return Math.max(this.totalFee - this.totalPaid, 0);
  }

  get totalFeeDisplay() {
    return formatCurrency(this.totalFee);
  }

  get totalPaidDisplay() {
    return formatCurrency(this.totalPaid);
  }

  get totalPendingDisplay() {
    return formatCurrency(this.totalPending);
  }

  get paymentStatusLabel() {
    return this.totalPending > 0 ? "On Track" : "Completed";
  }

  get paymentStatusDescription() {
    if (this.totalPending > 0) {
      return "Your payments are up to date.";
    }

    return "All fee items are fully paid. New invoices remain available for download.";
  }

  get paymentStatusCardClass() {
    return this.totalPending > 0
      ? "status-card status-card-ontrack"
      : "status-card status-card-complete";
  }

  get paymentStatusPillClass() {
    return this.totalPending > 0
      ? "status-chip status-chip-success"
      : "status-chip status-chip-outline";
  }

  get planSummaryCopy() {
    return `${this.feeRows.length} fee items in the current schedule`;
  }

 

  get invoiceButtonLabel() {
    return "View All";
  }

  get transactionFilterLabel() {
    return this.showRefundsOnly ? "All" : "Refunds";
  }

  get transactionFooterLabel() {
    return "View All Transaction";
  }

  get payableRows() {
    return this.feeRows.filter((row) => this.getPendingForRow(row) > 0);
  }

  get payableLineItemRows() {
    const rows = [];
    this.feeRows.forEach((feeRow) => {
      const childRows = Array.isArray(feeRow.childItems) && feeRow.childItems.length
        ? feeRow.childItems
        : [];
      childRows.forEach((childRow) => {
        if (this.getPendingForRow(childRow) > 0) {
          rows.push({
            ...childRow,
            parentId: feeRow.id,
            parentFeeItem: feeRow.feeItem,
            parentAccountId: feeRow.accountId || null,
            parentApplicationId: feeRow.applicationId || null,
            parentCustomerName: feeRow.customerName || null,
            parentCustomerEmail: feeRow.customerEmail || null,
            parentCustomerPhone: feeRow.customerPhone || null,
          });
        }
      });
    });
    return rows;
  }

  get payableOptions() {
    return this.payableLineItemRows.map((row) => {
      const pendingAmount = this.getPendingForRow(row);
      return {
        id: row.id,
        feeItem: `${row.parentFeeItem} - ${row.feeItem}`,
        pendingAmountDisplay: formatCurrency(pendingAmount),
        selected: row.id === this.selectedPayableItemId,
        optionClass:
          row.id === this.selectedPayableItemId
            ? "option-item option-item-selected"
            : "option-item",
      };
    });
  }

  get selectedPayableRow() {
    return (
      this.payableLineItemRows.find((row) => row.id === this.selectedPayableItemId) ||
      this.payableLineItemRows[0] ||
      null
    );
  }

  get selectedPendingAmount() {
    return this.selectedPayableRow
      ? this.getPendingForRow(this.selectedPayableRow)
      : 0;
  }

  get selectedPendingAmountDisplay() {
    return formatCurrency(this.selectedPendingAmount);
  }

  get paymentAmountDisplay() {
    return formatCurrency(this.paymentAmount);
  }

  get submitPaymentButtonLabel() {
    return this.isSubmittingPayment
      ? "Redirecting..."
      : `Pay ${this.paymentAmountDisplay}`;
  }

  get isSubmitPaymentDisabled() {
    return this.isSubmittingPayment;
  }

  get planRows() {
    return this.feeRows.map((row) => this.decoratePlanRow(row));
  }

  get visibleInvoices() {
    const rows = this.showAllInvoices
      ? this.invoiceRows
      : this.invoiceRows.slice(0, 3);
    return rows.map((invoice) => ({ ...invoice }));
  }

  get visibleTransactions() {
    const rows = this.showRefundsOnly
      ? this.transactionRows.filter(
          (transaction) => transaction.type === "refund",
        )
      : this.transactionRows;

    const limitedRows =
      this.showAllTransactions || this.showRefundsOnly
        ? rows
        : rows.slice(0, 5);
    return limitedRows.map((transaction) => ({
      ...transaction,
      dateDisplay: formatDate(transaction.date),
      statusLabel:
        transaction.status === "failed"
          ? "Failed"
          : transaction.status === "initiated"
            ? "Initiated"
          : transaction.type === "refund"
            ? "Refunded"
            : "Success",
      statusClass:
        transaction.status === "failed"
          ? "status-chip status-chip-error"
          : transaction.status === "initiated"
            ? "status-chip status-chip-outline"
          : transaction.type === "refund"
            ? "status-chip status-chip-outline"
            : "status-chip status-chip-success",
      showRetry: transaction.status === "failed",
    }));
  }

  mapFeeRows(rows) {
    if (!Array.isArray(rows)) {
      return [];
    }

    return rows.map((row, index) => {
      const rowId = row?.id || `fee-assignment-${index + 1}`;
      const totalAmount = Number(row?.totalAmount || 0);
      const totalPayable = Number(row?.totalPayable ?? totalAmount);
      const paidAmount = Number(row?.paidAmount || 0);

      return {
        id: rowId,
        feeItem: row?.feeItem || `Fee Assignment ${index + 1}`,
        dueDate: formatDate(row?.dueDate),
        currency: row?.currencyIsoCode || "INR",
        accountId: row?.accountId || row?.account || null,
        applicationId:
          row?.applicationId ||
          row?.individualApplicationId ||
          row?.relatedRecordId ||
          null,
        customerName: row?.customerName || null,
        customerEmail: row?.customerEmail || null,
        customerPhone: row?.customerPhone || null,
        totalAmount,
        tax: Number(row?.tax || 0),
        tds: Number(row?.tds || 0),
        totalPayable,
        paidAmount,
        description: row?.description || "",
        isExpanded: false,
        childItems: this.mapChildRows(
          row?.lineItems,
          rowId,
          row?.dueDate,
          row?.currencyIsoCode,
          row?.accountId || row?.account || null,
          row?.applicationId || row?.individualApplicationId || row?.relatedRecordId || null,
        ),
      };
    });
  }

  mapChildRows(
    lineItems,
    parentId,
    defaultDueDate,
    defaultCurrencyIsoCode,
    defaultAccountId,
    defaultApplicationId,
  ) {
    if (!Array.isArray(lineItems) || !lineItems.length) {
      return [];
    }

    return lineItems.map((lineItem, index) => {
      const lineId = lineItem?.id || `${parentId}-line-${index + 1}`;
      const totalAmount = Number(lineItem?.totalAmount || 0);
      const totalPayable = Number(lineItem?.totalPayable ?? totalAmount);
      const paidAmount = Number(lineItem?.paidAmount || 0);

      return {
        id: lineId,
        feeItem: lineItem?.feeItem || `Fee Item ${index + 1}`,
        dueDate: formatDate(lineItem?.dueDate || defaultDueDate),
        currency: lineItem?.currencyIsoCode || defaultCurrencyIsoCode || "INR",
        feeAssignmentId:
          lineItem?.feeAssignmentId ||
          lineItem?.assignmentId ||
          parentId ||
          null,
        feeAssignmentLineItemId:
          lineItem?.feeAssignmentLineItemId ||
          lineItem?.feeAssignmentLineId ||
          lineItem?.assignmentLineItemId ||
          lineItem?.id ||
          null,
        feeInstallmentId:
          lineItem?.feeInstallmentId ||
          lineItem?.installmentId ||
          lineItem?.feeInstallment ||
          null,
        feeInstallmentLineItemId:
          lineItem?.feeInstallmentLineItemId ||
          lineItem?.feeInstallmentLineId ||
          lineItem?.installmentLineItemId ||
          null,
        accountId: lineItem?.accountId || defaultAccountId || null,
        applicationId: lineItem?.applicationId || defaultApplicationId || null,
        totalAmount,
        tax: Number(lineItem?.tax || 0),
        tds: Number(lineItem?.tds || 0),
        totalPayable,
        paidAmount,
      };
    });
  }

  syncSelectedPayableItem() {
    const payableItems = this.payableLineItemRows;
    if (!payableItems.length) {
      this.selectedPayableItemId = null;
      this.paymentAmount = 0;
      return;
    }

    const hasCurrentSelection = payableItems.some(
      (row) => row.id === this.selectedPayableItemId,
    );
    if (!hasCurrentSelection) {
      this.selectedPayableItemId = payableItems[0].id;
    }
    this.paymentAmount = this.getSuggestedPaymentAmount(this.selectedPendingAmount);
  }

  decoratePlanRow(row) {
    const pendingAmount = this.getPendingForRow(row);
    const statusLabel =
      pendingAmount === 0
        ? "Paid"
        : row.paidAmount > 0
          ? "Partially Paid"
          : "Pending";
    const statusClass =
      pendingAmount === 0
        ? "status-chip status-chip-success"
        : row.paidAmount > 0
          ? "status-chip status-chip-warn"
          : "status-chip status-chip-outline";

    const childItems = Array.isArray(row.childItems) && row.childItems.length
      ? row.childItems.map((childRow, index) =>
          buildChildRow(childRow, `${row.id}-child-${index}`),
        )
      : [
          buildChildRow(
            {
              id: `${row.id}-child-default`,
              feeItem: row.feeItem,
              dueDate: row.dueDate,
              currency: row.currency,
              totalAmount: row.totalAmount,
              tax: row.tax,
              tds: row.tds,
              totalPayable: row.totalPayable,
            },
            `${row.id}-child-default`,
          ),
        ];

    return {
      ...row,
      totalAmountDisplay: formatCurrency(row.totalAmount),
      taxDisplay: formatCurrency(row.tax),
      tdsDisplay: formatCurrency(row.tds),
      totalPayableDisplay: formatCurrency(row.totalPayable),
      paidAmountDisplay: formatCurrency(row.paidAmount),
      pendingAmountDisplay: formatCurrency(pendingAmount),
      statusLabel,
      statusClass,
      chevronIconName: row.isExpanded ? "utility:chevronup" : "utility:chevrondown",
      childItems,
    };
  }

  getPendingForRow(row) {
    return Math.max(
      Number(row.totalPayable || 0) - Number(row.paidAmount || 0),
      0,
    );
  }

  handleTogglePlanRow(event) {
    const rowId = event.currentTarget.dataset.id;
    this.feeRows = this.feeRows.map((row) =>
      row.id === rowId ? { ...row, isExpanded: !row.isExpanded } : row,
    );
    this.expandAllRows = this.feeRows.every((row) => row.isExpanded);
  }

  handleToggleExpandAll() {
    this.navigateToFeePayment("feePlan");

  }
  navigateToFeePayment(tabValue) {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: {
        name: "MakePaymentFlow__c",
      },
      state: {
        c__tab: tabValue,
      },
    });
  }


 
  handleViewAllInvoices() {
    this.navigateToMakePaymentFlow("invoices");
  }

  handleToggleTransactionFilter() {
    this.navigateToMakeRefundsFlow("refunds");

  }

    navigateToMakeRefundsFlow(tabValue) {
      this[NavigationMixin.Navigate]({
        type: "comm__namedPage",
        attributes: {
          name: "MakePaymentFlow__c",
        },
        state: {
          c__tab: tabValue,
        },
      });
    }

  handleShowAllTransactions() {
    this.navigateToMakePaymentFlow("transactionHistory");
  }

  navigateToMakePaymentFlow(tabValue) {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: {
        name: "MakePaymentFlow__c",
      },
      state: {
        c__tab: tabValue,
      },
    });
  }

  handleDownloadInvoice(event) {
    const invoiceId = event.currentTarget.dataset.id;
    const invoice = this.invoiceRows.find((item) => item.id === invoiceId);
    if (!invoice) {
      return;
    }

    const fileContents = [
      `Invoice: ${invoice.title}`,
      `Reference: ${invoice.reference}`,
      `Student: ${this.programName}`,
      `Total Paid: ${this.totalPaidDisplay}`,
      `Pending: ${this.totalPendingDisplay}`,
    ].join("\n");

    const link = document.createElement("a");
    link.href = `data:text/plain;charset=utf-8,${encodeURIComponent(fileContents)}`;
    link.download = `${invoice.reference}.txt`;
    link.click();

    this.dispatchEvent(
      new ShowToastEvent({
        title: "Invoice downloaded",
        message: `${invoice.reference} has been downloaded.`,
        variant: "success",
      }),
    );
  }

  handleOpenPaymentModal() {
    this.navigateToMakePaymentFlow("feePayments");
  }

  handleClosePaymentModal() {
    this.isPaymentModalOpen = false;
    this.retryTransactionId = null;
  }

  handleSelectPayableItem(event) {
    this.selectedPayableItemId = event.target.value;
    this.paymentAmount = this.getSuggestedPaymentAmount(
      this.selectedPendingAmount,
    );
  }

  handlePaymentAmountChange(event) {
    this.paymentAmount = Number(event.detail.value || event.target.value || 0);
  }

  handleGatewayChange(event) {
    this.selectedGateway = event.target.value;
  }

  handleRetryTransaction(event) {
    const transactionId = event.currentTarget.dataset.id;
    const transaction = this.transactionRows.find(
      (item) => item.id === transactionId,
    );
    if (!transaction) {
      return;
    }

    const firstPayable = this.payableLineItemRows[0];
    if (!firstPayable) {
      return;
    }

    this.retryTransactionId = transactionId;
    this.selectedPayableItemId = firstPayable.id;
    this.paymentAmount = Math.min(
      transaction.amount,
      this.getPendingForRow(firstPayable),
    );
    this.isPaymentModalOpen = true;
  }

  async handleSubmitPayment() {
    const selectedRow = this.selectedPayableRow;
    const amount = Number(this.paymentAmount || 0);
    const maxAllowed = this.selectedPendingAmount;

    if (!selectedRow) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Fee item required",
          message: "Select a fee item to continue.",
          variant: "error",
        }),
      );
      return;
    }

    if (!amount || amount <= 0) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Invalid amount",
          message: "Enter a payment amount greater than zero.",
          variant: "error",
        }),
      );
      return;
    }

    if (amount > maxAllowed) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Amount exceeds pending balance",
          message: `You can pay up to ${formatCurrency(maxAllowed)} for ${selectedRow.feeItem}.`,
          variant: "error",
        }),
      );
      return;
    }

    if (this.isSubmittingPayment) {
      return;
    }

    this.isSubmittingPayment = true;

    try {
      const paymentRequest = this.buildCreatePaymentLinkRequest(selectedRow, amount);
      const response = await createPaymentLink({
        reqJson: JSON.stringify(paymentRequest),
      });

      if (!response?.shortUrl) {
        throw new Error("Payment link was created but no redirect URL was returned.");
      }

      this.addInitiatedTransaction({
        amount,
        reference: response?.razorpayPaymentLinkId || paymentRequest.reference,
      });

      if (this.retryTransactionId) {
        this.transactionRows = this.transactionRows.map((transaction) =>
          transaction.id === this.retryTransactionId
            ? { ...transaction, status: "initiated" }
            : transaction,
        );
      }

      this.isPaymentModalOpen = false;
      this.retryTransactionId = null;

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Payment link created",
          message: "Redirecting to Razorpay to complete the payment.",
          variant: "success",
        }),
      );

      this[NavigationMixin.Navigate]({
        type: "standard__webPage",
        attributes: {
          url: response.shortUrl,
        },
      });
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Payment initiation failed",
          message: this.parseError(error),
          variant: "error",
        }),
      );
    } finally {
      this.isSubmittingPayment = false;
    }
  }

  buildCreatePaymentLinkRequest(selectedRow, amount) {
    const feeAssignmentId =
      selectedRow?.feeAssignmentId ||
      selectedRow?.parentId ||
      null;
    const feeAssignmentLineItemId =
      selectedRow?.feeAssignmentLineItemId ||
      null;
    const feeInstallmentId =
      selectedRow?.feeInstallmentId ||
      null;
    const feeInstallmentLineItemId =
      selectedRow?.feeInstallmentLineItemId ||
      null;
    const accountId =
      selectedRow?.accountId ||
      selectedRow?.parentAccountId ||
      null;
    const applicationId =
      selectedRow?.applicationId ||
      selectedRow?.parentApplicationId ||
      null;
    const reference = this.buildPaymentReference(selectedRow);

    return {
      amount,
      currencyType: selectedRow?.currency || "INR",
      description: `Portal fee payment: ${selectedRow?.parentFeeItem || "Fee"} - ${selectedRow?.feeItem || "Line Item"} (${this.resolveGatewayLabel(this.selectedGateway)})`,
      reference,
      relatedRecordId: this.resolveRelatedRecordId(selectedRow),
      successRedirectUrl: this.getPortalFeePaymentSuccessRedirectUrl(),
      accountId,
      customerName: selectedRow?.parentCustomerName || null,
      customerEmail: selectedRow?.parentCustomerEmail || null,
      customerPhone: selectedRow?.parentCustomerPhone || null,
      lineItems: [
        {
          feeAssignmentId,
          feeAssignmentLineItemId,
          feeInstallmentId,
          feeInstallmentLineItemId,
          accountId,
          applicationId,
        },
      ],
    };
  }

  getPortalFeePaymentSuccessRedirectUrl() {
    try {
      const origin = window?.location?.origin;
      if (!origin) {
        return null;
      }
      return `${origin}/StudentPortalAcademics/feepayment`;
    } catch (error) {
      return null;
    }
  }

  buildPaymentReference(selectedRow) {
    const base = String(selectedRow?.parentId || selectedRow?.id || "PORTALPAY");
    const now = Date.now();
    return `${base}-${now}`.substring(0, 80);
  }

  resolveRelatedRecordId(selectedRow) {
    const applicationId = String(
      selectedRow?.applicationId || selectedRow?.parentApplicationId || "",
    ).trim();
    if (this.isSalesforceId(applicationId)) {
      return applicationId;
    }

    const fallbackId = String(
      selectedRow?.parentId || selectedRow?.feeAssignmentId || selectedRow?.id || "",
    ).trim();
    if (this.isSalesforceId(fallbackId)) {
      return `FEEASSIGN-${fallbackId}`;
    }

    return `PORTALPAY-${Date.now()}`;
  }

  isSalesforceId(value) {
    const candidate = String(value || "").trim();
    return /^[a-zA-Z0-9]{15,18}$/.test(candidate);
  }

  addInitiatedTransaction({ amount, reference }) {
    const nextTransaction = {
      id: `txn-${Date.now()}`,
      reference: reference || this.buildPaymentReference(this.selectedPayableRow),
      date: new Date().toISOString().slice(0, 10),
      status: "initiated",
      amount,
      type: "payment",
    };
    this.transactionRows = [nextTransaction, ...this.transactionRows];
  }

  getSuggestedPaymentAmount(pendingAmount) {
    return pendingAmount >= 10000 ? 10000 : pendingAmount;
  }

  parseError(error) {
    if (error?.body?.message) {
      return error.body.message;
    }
    if (Array.isArray(error?.body) && error.body.length && error.body[0]?.message) {
      return error.body[0].message;
    }
    if (error?.message) {
      return error.message;
    }
    return "Unable to initiate payment. Please try again.";
  }

  resolveGatewayLabel(gatewayValue) {
    return (
      PAYMENT_GATEWAYS.find((gateway) => gateway.value === gatewayValue)
        ?.label || "selected gateway"
    );
  }
}