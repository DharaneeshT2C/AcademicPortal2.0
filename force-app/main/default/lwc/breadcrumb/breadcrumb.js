import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

/**
 * Reusable breadcrumb — matches the project's "Home > Page" muted-text pattern.
 *
 * Usage:
 *   <c-breadcrumb items={crumbs} onnavigate={handleCrumbClick}></c-breadcrumb>
 *
 *   crumbs = [
 *     { label: 'Home',             pageName: 'Home' },
 *     { label: 'Course Enrolment', pageName: 'CourseEnrolment__c' },
 *     { label: 'Semester 2' }                  // last item — current page, not clickable
 *   ];
 *
 * Each clickable crumb auto-navigates via comm__namedPage when `pageName` is set.
 * Parents can also listen to the `navigate` event to override or do SPA routing.
 */
export default class Breadcrumb extends NavigationMixin(LightningElement) {
    @api items = [];

    get computedItems() {
        const list = Array.isArray(this.items) ? this.items : [];
        return list.map((item, index) => {
            const isLast = index === list.length - 1;
            return {
                ...item,
                index,
                key: `bc-${index}-${(item && item.label) || ''}`,
                isClickable: !isLast,
                showSeparator: !isLast
            };
        });
    }

    handleClick(event) {
        event.preventDefault();
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const item = (this.items || [])[index];
        if (!item) return;

        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { ...item, index }
        }));

        if (item.pageName) {
            try {
                this[NavigationMixin.Navigate]({
                    type: 'comm__namedPage',
                    attributes: { name: item.pageName },
                    state: item.state || {}
                });
            } catch (e) {
                // Parent's onnavigate handler can take over
            }
        }
    }
}
