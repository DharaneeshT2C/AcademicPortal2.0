import { LightningElement, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getMasterDataSummary from "@salesforce/apex/MasterDataController.getMasterDataSummary";

const ACADEMIC_MODULES = [
    {
        key: "quotaCategories",
        title: "Quota & Categories",
        description: "Define category types and quota rules",
        iconName: "utility:groups"
    },
    {
        key: "feeHeads",
        title: "Fee Heads",
        description: "Configure fee components and categories",
        iconName: "utility:file"
    },
    {
        key: "feePlans",
        title: "Fee Plans",
        description: "Create fee structures with category and quota mapping",
        iconName: "utility:change_record_type"
    },
    {
        key: "programmeFeePublishing",
        title: "Fee Structures & Fee Types",
        description: "Publish fee structures for programmes and batches",
        iconName: "utility:collection_alt"
    },
    {
        key: "penaltyPlans",
        title: "Penalty Plans",
        description: "Define late payment rules and penalties",
        iconName: "utility:warning"
    },
    {
        key: "taxes",
        title: "Taxes",
        description: "Configure tax rates and tax mappings",
        iconName: "utility:money"
    },
    {
        key: "installmentPlans",
        title: "Installment Plans",
        description: "Configure installment schedules and split rules",
        iconName: "utility:date_time"
    },
    {
        key: "scholarships",
        title: "Scholarships",
        description: "Manage scholarship schemes and eligibility",
        iconName: "utility:education"
    }
];

const FINANCIAL_MODULES = [
    {
        key: "remittanceAccounts",
        title: "Remittance Accounts",
        description: "Configure bank accounts for fee collection",
        iconName: "utility:moneybag"
    },
    {
        key: "paymentGateways",
        title: "Payment Gateways",
        description: "Manage online payment gateway integrations",
        iconName: "utility:connected_apps"
    }
];

export default class MasterDataLanding extends NavigationMixin(LightningElement) {
    @track isLoading = false;
    @track academicCards = [];
    @track financialCards = [];

    connectedCallback() {
        this.loadSummary();
    }

    async loadSummary() {
        this.isLoading = true;
        try {
            const rows = await getMasterDataSummary();
            const summaryByKey = new Map(
                (Array.isArray(rows) ? rows : []).map((row) => [row.key, row])
            );

            this.academicCards = this.buildCards(ACADEMIC_MODULES, summaryByKey);
            this.financialCards = this.buildCards(FINANCIAL_MODULES, summaryByKey);
        } finally {
            this.isLoading = false;
        }
    }

    buildCards(definitions, summaryByKey) {
        return definitions.map((module) => {
            const summary = summaryByKey.get(module.key) || {};

            return {
                key: module.key,
                title: summary.title || module.title,
                description: summary.description || module.description,
                recordCount: summary.recordCount ?? 0,
                iconName: module.iconName,
                lastUpdatedText: summary.lastUpdated
                    ? new Date(summary.lastUpdated).toLocaleString()
                    : "-"
            };
        });
    }

    handleCardClick(event) {
        const moduleKey = event.currentTarget.dataset.key;

        if (moduleKey === "quotaCategories") {
            this[NavigationMixin.Navigate]({
                type: "standard__component",
                attributes: { componentName: "c__quotaCategoryManager" }
            });
            return;
        }

        if (moduleKey === "feeHeads") {
            this[NavigationMixin.Navigate]({
                type: "standard__component",
                attributes: { componentName: "c__feeHeadsManager" }
            });
            return;
        }

        if (moduleKey === "feePlans") {
            this[NavigationMixin.Navigate]({
                type: "standard__component",
                attributes: { componentName: "c__feePlansPage" }
            });
            return;
        }

        if (moduleKey === "programmeFeePublishing") {
            this[NavigationMixin.Navigate]({
                type: "standard__component",
                attributes: { componentName: "c__programmeFeePublishingPage" }
            });
            return;
        }

        if (moduleKey === "taxes") {
            this[NavigationMixin.Navigate]({
                type: "standard__component",
                attributes: { componentName: "c__taxesPage" }
            });
            return;
        }

        if (moduleKey === "installmentPlans") {
            this[NavigationMixin.Navigate]({
                type: "standard__component",
                attributes: { componentName: "c__installmentPlansPage" }
            });
            return;
        }

        if (moduleKey === "scholarships") {
            this[NavigationMixin.Navigate]({
                type: "standard__component",
                attributes: { componentName: "c__scholarshipsPage" }
            });
            return;
        }

        if (moduleKey === "remittanceAccounts") {
            this[NavigationMixin.Navigate]({
                type: "standard__component",
                attributes: { componentName: "c__remittanceAccountsManager" }
            });
            return;
        }

        if (moduleKey === "paymentGateways") {
            this[NavigationMixin.Navigate]({
                type: "standard__component",
                attributes: { componentName: "c__paymentGatewaysManager" }
            });
        }
    }
}