import { LightningElement } from 'lwc';

function toDataUri(svg) {
    return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
}

const PAGE_ONE_PREVIEW = toDataUri(`
<svg xmlns='http://www.w3.org/2000/svg' width='1100' height='1400' viewBox='0 0 1100 1400'>
  <defs>
    <linearGradient id='sky' x1='0' y1='0' x2='0' y2='1'>
      <stop offset='0%' stop-color='#1b2449'/>
      <stop offset='55%' stop-color='#d37f5a'/>
      <stop offset='100%' stop-color='#f4d3a2'/>
    </linearGradient>
  </defs>
  <rect width='1100' height='850' fill='url(#sky)'/>
  <rect y='850' width='1100' height='550' fill='#f2f3f1'/>
  <path d='M0 730 L130 650 L240 690 L360 620 L500 680 L640 610 L760 670 L910 620 L1100 700 L1100 930 L0 930 Z' fill='#0c1018'/>
  <g stroke='#202733' stroke-width='5'>
    <line x1='100' y1='910' x2='145' y2='700'/><line x1='250' y1='910' x2='300' y2='670'/><line x1='410' y1='910' x2='460' y2='640'/>
    <line x1='575' y1='910' x2='620' y2='690'/><line x1='740' y1='910' x2='790' y2='650'/><line x1='905' y1='910' x2='955' y2='700'/>
  </g>
  <g fill='#1d2531'>
    <circle cx='145' cy='700' r='42'/><circle cx='300' cy='670' r='42'/><circle cx='460' cy='640' r='42'/>
    <circle cx='620' cy='690' r='42'/><circle cx='790' cy='650' r='42'/><circle cx='955' cy='700' r='42'/>
  </g>
  <text x='550' y='1020' text-anchor='middle' fill='#77b539' font-size='72' font-family='Arial' font-weight='700'>isoenergy</text>
  <text x='550' y='1090' text-anchor='middle' fill='#77b539' font-size='40' font-family='Arial'>Heat pump</text>
</svg>
`);

const PAGE_TWO_PREVIEW = toDataUri(`
<svg xmlns='http://www.w3.org/2000/svg' width='1100' height='1400' viewBox='0 0 1100 1400'>
  <rect width='1100' height='1400' fill='#f3f4f0'/>
  <g stroke='#7fb43b' stroke-width='10' fill='none'>
    <rect x='110' y='130' width='220' height='210' rx='14'/>
    <rect x='410' y='130' width='280' height='210' rx='14'/>
    <rect x='760' y='130' width='220' height='210' rx='14'/>
    <path d='M120 520 h900 M120 760 h900 M120 1000 h900'/>
  </g>
  <text x='550' y='1180' text-anchor='middle' fill='#77b539' font-size='76' font-family='Arial' font-weight='700'>isoenergy</text>
  <text x='550' y='1260' text-anchor='middle' fill='#77b539' font-size='36' font-family='Arial'>Ground Source Diagram</text>
</svg>
`);

export default class QuestionPaper extends LightningElement {
    hasAddedQuestionPaper = false;
    isPaper1Open = true;
    isPaper2Open = true;
    isPaper1Deleted = false;
    showDeleteConfirmModal = false;
    showDeleteSuccessModal = false;
    showUploadModal = false;
    showUploadSuccessModal = false;
    showPreviewModal = false;
    selectedPreviewId = '1';
    previewPages = [
        {
            id: '1',
            numberLabel: '1',
            altText: 'Question paper page 1',
            thumbnailSrc: PAGE_ONE_PREVIEW,
            previewSrc: PAGE_ONE_PREVIEW
        },
        {
            id: '2',
            numberLabel: '2',
            altText: 'Question paper page 2',
            thumbnailSrc: PAGE_TWO_PREVIEW,
            previewSrc: PAGE_TWO_PREVIEW
        }
    ];

    get showPaper1Panel() {
        return !this.isPaper1Deleted;
    }

    get paper1ToggleIcon() {
        return this.isPaper1Open ? '⌃' : '⌄';
    }

    get paper2ToggleIcon() {
        return this.isPaper2Open ? '⌃' : '⌄';
    }

    get selectedPreviewPage() {
        return this.previewPages.find((page) => page.id === this.selectedPreviewId) || this.previewPages[0];
    }

    get previewPagesForUi() {
        return this.previewPages.map((page) => ({
            ...page,
            thumbClass: page.id === this.selectedPreviewId ? 'preview-thumb is-active' : 'preview-thumb'
        }));
    }

    handleAddQuestionPaper() {
        this.hasAddedQuestionPaper = true;
        if (!this.isPaper1Deleted) {
            this.isPaper1Open = false;
        }
        this.isPaper2Open = true;
    }

    togglePaper1() {
        this.isPaper1Open = !this.isPaper1Open;
    }

    togglePaper2() {
        this.isPaper2Open = !this.isPaper2Open;
    }

    openDeleteConfirmModal() {
        this.showDeleteConfirmModal = true;
    }

    closeDeleteConfirmModal() {
        this.showDeleteConfirmModal = false;
    }

    confirmDeletePaper1() {
        this.showDeleteConfirmModal = false;
        this.isPaper1Deleted = true;
        this.showDeleteSuccessModal = true;
    }

    closeDeleteSuccessModal() {
        this.showDeleteSuccessModal = false;
    }

    openUploadModal() {
        this.showUploadModal = true;
    }

    closeUploadModal() {
        this.showUploadModal = false;
    }

    handleUploadDone() {
        this.showUploadModal = false;
        this.showUploadSuccessModal = true;
    }

    closeUploadSuccessModal() {
        this.showUploadSuccessModal = false;
    }

    openPreviewModal() {
        this.selectedPreviewId = this.previewPages[0].id;
        this.showPreviewModal = true;
    }

    closePreviewModal() {
        this.showPreviewModal = false;
    }

    handlePreviewSelect(event) {
        this.selectedPreviewId = event.currentTarget.dataset.id;
    }

    stopPropagation(event) {
        event.stopPropagation();
    }
}