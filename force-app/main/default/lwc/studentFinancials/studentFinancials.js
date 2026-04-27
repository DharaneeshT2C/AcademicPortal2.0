import { LightningElement, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";

const TAB_ORDER = ["feeAssignments", "scholarshipAssignments"];

export default class StudentFinancials extends LightningElement {
    activeTab = "feeAssignments";

    @wire(CurrentPageReference)
    setPageReference(pageRef) {
        const requestedTab = pageRef?.state?.c__tab;
        if (TAB_ORDER.includes(requestedTab)) {
            this.activeTab = requestedTab;
        }
    }

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

    get isFeeTab() {
        return this.activeTab === "feeAssignments";
    }

    get isScholarshipTab() {
        return this.activeTab === "scholarshipAssignments";
    }

    get feeTabClass() {
        return this.isFeeTab ? "tabButton tabButtonActive" : "tabButton";
    }

    get scholarshipTabClass() {
        return this.isScholarshipTab ? "tabButton tabButtonActive" : "tabButton";
    }

    get feeTabIndex() {
        return this.isFeeTab ? 0 : -1;
    }

    get scholarshipTabIndex() {
        return this.isScholarshipTab ? 0 : -1;
    }
}