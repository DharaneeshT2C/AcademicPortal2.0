import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { pageNameForRoute } from 'c/navHelper';

export default class Header extends NavigationMixin(LightningElement) {
    handleToggleSidebar() {
        this.dispatchEvent(new CustomEvent('togglesidebar'));
    }

    navigateTo(route) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: pageNameForRoute(route) }
        });
    }

    handleSchedule() { this.navigateTo('schedule'); }
    handleChat() { this.navigateTo('chat'); }
    handleSettings() { this.navigateTo('settings'); }
    handleNotifications() { this.navigateTo('notifications'); }
}