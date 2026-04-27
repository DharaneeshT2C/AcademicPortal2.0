import { LightningElement, api, track } from 'lwc';

export default class NavigationMenu extends LightningElement {
    @api studentName;

    @track activeMenu = 'home'; // default

    handleLearnClick() {
        this.activeMenu = 'learn';
        this.fireMenuEvent('learn');
    }

    handleHomeClick() {
        this.activeMenu = 'home';
        this.fireMenuEvent('home');
    }

    handleProgramPathClick() {
        this.activeMenu = 'programPath';
        this.fireMenuEvent('programPath');
    }

    handleScheduleClick() {
        this.activeMenu = 'schedule';
        this.fireMenuEvent('schedule');
    }

    fireMenuEvent(value) {
        this.dispatchEvent(
            new CustomEvent('menuselect', {
                detail: value
            })
        );
    }

    /* ---- dynamic classes ---- */
    get homeClass() {
        return this.activeMenu === 'home' ? 'menu-item active' : 'menu-item';
    }

    get learnClass() {
        return this.activeMenu === 'learn' ? 'menu-item active' : 'menu-item';
    }

    get programPathClass() {
        return this.activeMenu === 'programPath'
            ? 'menu-item active'
            : 'menu-item';
    }

    get scheduleClass() {
        return this.activeMenu === 'schedule'
            ? 'menu-item active'
            : 'menu-item';
    }
}