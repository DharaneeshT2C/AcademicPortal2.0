import { LightningElement, api } from 'lwc';

export default class DevToolbar extends LightningElement {
    @api currentStage = 'middle';
    @api currentPath = 'placements';
    @api currentViewMode = 'auto';
    @api currentBrand = 'ken';

    get showPathButtons() {
        return this.currentStage === 'ending';
    }

    get stageStartingClass() { return this.currentStage === 'starting' ? 'tb-btn tb-btn-active tb-emerald' : 'tb-btn'; }
    get stageMiddleClass()   { return this.currentStage === 'middle'   ? 'tb-btn tb-btn-active tb-emerald' : 'tb-btn'; }
    get stageEndingClass()   { return this.currentStage === 'ending'   ? 'tb-btn tb-btn-active tb-emerald' : 'tb-btn'; }

    get pathPlacementsClass()       { return this.currentPath === 'placements'       ? 'tb-btn tb-btn-active tb-violet' : 'tb-btn'; }
    get pathHigherStudiesClass()    { return this.currentPath === 'higher-studies'   ? 'tb-btn tb-btn-active tb-violet' : 'tb-btn'; }
    get pathEntrepreneurshipClass() { return this.currentPath === 'entrepreneurship' ? 'tb-btn tb-btn-active tb-violet' : 'tb-btn'; }
    get pathExploringClass()        { return this.currentPath === 'exploring'        ? 'tb-btn tb-btn-active tb-violet' : 'tb-btn'; }

    get viewAutoClass()    { return this.currentViewMode === 'auto'    ? 'tb-btn tb-btn-active tb-sky' : 'tb-btn'; }
    get viewMobileClass()  { return this.currentViewMode === 'mobile'  ? 'tb-btn tb-btn-active tb-sky' : 'tb-btn'; }
    get viewDesktopClass() { return this.currentViewMode === 'desktop' ? 'tb-btn tb-btn-active tb-sky' : 'tb-btn'; }

    get brandKenClass() { return this.currentBrand === 'ken' ? 'tb-btn tb-btn-active tb-indigo' : 'tb-btn'; }
    get brandSmuClass() { return this.currentBrand === 'smu' ? 'tb-btn tb-btn-active tb-indigo' : 'tb-btn'; }

    handleStageClick(event) {
        const stage = event.currentTarget.dataset.stage;
        this.dispatchEvent(new CustomEvent('stagechange', { detail: { stage } }));
    }

    handlePathClick(event) {
        const careerPath = event.currentTarget.dataset.path;
        this.dispatchEvent(new CustomEvent('pathchange', { detail: { careerPath } }));
    }

    handleViewModeClick(event) {
        const viewMode = event.currentTarget.dataset.mode;
        this.dispatchEvent(new CustomEvent('viewmodechange', { detail: { viewMode } }));
    }

    handleBrandClick(event) {
        const brand = event.currentTarget.dataset.brand;
        this.dispatchEvent(new CustomEvent('brandchange', { detail: { brand } }));
    }
}