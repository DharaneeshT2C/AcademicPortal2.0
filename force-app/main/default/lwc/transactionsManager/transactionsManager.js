import { LightningElement } from "lwc";

const TAB_ORDER = ["studentTransactions", "refundsManager", "scholarshipTransactions"];

export default class TransactionsManager extends LightningElement {
    activeTab = "studentTransactions";

    handleTabClick(event) {
        const nextTab = event.currentTarget.dataset.tab;
        if (TAB_ORDER.includes(nextTab)) {
            this.activeTab = nextTab;
        }
    }

    handleTabKeydown(event) {
        const currentIndex = TAB_ORDER.indexOf(this.activeTab);
        let nextIndex = currentIndex;

        if (event.key === "ArrowRight") {
            nextIndex = (currentIndex + 1) % TAB_ORDER.length;
        } else if (event.key === "ArrowLeft") {
            nextIndex = (currentIndex - 1 + TAB_ORDER.length) % TAB_ORDER.length;
        } else if (event.key === "Home") {
            nextIndex = 0;
        } else if (event.key === "End") {
            nextIndex = TAB_ORDER.length - 1;
        } else {
            return;
        }

        event.preventDefault();
        this.activeTab = TAB_ORDER[nextIndex];
        this.focusTab(this.activeTab);
    }

    focusTab(tabName) {
        const tabButton = this.template.querySelector(`button[data-tab="${tabName}"]`);
        if (tabButton) {
            tabButton.focus();
        }
    }

    get isStudentTab() {
        return this.activeTab === "studentTransactions";
    }

    get isRefundsTab() {
        return this.activeTab === "refundsManager";
    }

    get isScholarshipTab() {
        return this.activeTab === "scholarshipTransactions";
    }

    get studentTabClass() {
        return this.isStudentTab ? "tabButton tabButtonActive" : "tabButton";
    }

    get refundsTabClass() {
        return this.isRefundsTab ? "tabButton tabButtonActive" : "tabButton";
    }

    get scholarshipTabClass() {
        return this.isScholarshipTab ? "tabButton tabButtonActive" : "tabButton";
    }

    get studentTabIndex() {
        return this.isStudentTab ? 0 : -1;
    }

    get refundsTabIndex() {
        return this.isRefundsTab ? 0 : -1;
    }

    get scholarshipTabIndex() {
        return this.isScholarshipTab ? 0 : -1;
    }
}