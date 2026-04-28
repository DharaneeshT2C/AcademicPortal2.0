import { LightningElement } from 'lwc';

export default class Header extends LightningElement {
    handleToggleSidebar() {
        this.dispatchEvent(new CustomEvent('togglesidebar'));
    }

    navigateTo(route) {
        this.dispatchEvent(new CustomEvent('navigate', { detail: { route } }));
    }

    handleSchedule() { this.navigateTo('schedule'); }
    handleChat() { this.navigateTo('chat'); }
    handleSettings() { this.navigateTo('settings'); }
    handleNotifications() { this.navigateTo('notifications'); }
}