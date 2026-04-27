import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import getKenTemplates from '@salesforce/apex/KenIdLifecycleManagerController.getTemplates';
import saveKenTemplate from '@salesforce/apex/KenIdLifecycleManagerController.saveTemplate';
import getGlobalAssetsApex from '@salesforce/apex/KenIdLifecycleManagerController.getGlobalAssets';
import saveGlobalAssetApex from '@salesforce/apex/KenIdLifecycleManagerController.saveGlobalAsset';
import deleteGlobalAssetApex from '@salesforce/apex/KenIdLifecycleManagerController.deleteGlobalAsset';
import samplePrimaryLogo from '@salesforce/resourceUrl/Ken_ID_Card_Sample_Logo';
import KEN_ID_CARD_OBJECT from '@salesforce/schema/Ken_ID_Card__c';
import INSTITUTE_FIELD from '@salesforce/schema/Ken_ID_Card__c.Institute__c';

const SECTION_CONFIG = [
    { value: 'dashboard', label: 'Dashboard', icon: 'utility:apps' },
    { value: 'cardRecords', label: 'Card Records', icon: 'utility:table' },
    { value: 'photoApproval', label: 'Photo Approval', icon: 'utility:image' },
    { value: 'batchProcessing', label: 'Batch Processing', icon: 'utility:layers' },
    { value: 'templates', label: 'Templates', icon: 'utility:settings' },
    { value: 'visitors', label: 'Visitors', icon: 'utility:people' },
    { value: 'syncLogs', label: 'Sync Logs', icon: 'utility:refresh' },
    { value: 'reports', label: 'Reports', icon: 'utility:file' }
];

const STEP_CONFIG = [
    { value: 1, label: 'Basic Details' },
    { value: 2, label: 'Design Theme' },
    { value: 3, label: 'Field Customization' },
    { value: 4, label: 'Branding' },
    { value: 5, label: 'Review & Save' }
];

const FALLBACK_INSTITUTE_OPTIONS = [
    {
        value: 'Department of Library and Information Science',
        label: 'Department of Library and Information Science'
    },
    {
        value: 'K J Somaiya Institute of Management',
        label: 'K J Somaiya Institute of Management'
    },
    {
        value: 'Somaiya School of Design',
        label: 'Somaiya School of Design'
    },
    {
        value: 'K J Somaiya School of Engineering',
        label: 'K J Somaiya School of Engineering'
    },
    {
        value: 'Somaiya School of Civilisation Studies',
        label: 'Somaiya School of Civilisation Studies'
    },
    {
        value: 'Dr. Shantilal K Somaiya School of Commerce and Business Studies',
        label: 'Dr. Shantilal K Somaiya School of Commerce and Business Studies'
    },
    {
        value: 'Dr. Shantilal K Somaiya School of Art',
        label: 'Dr. Shantilal K Somaiya School of Art'
    },
    {
        value: 'K J Somaiya Institute of Dharma Studies',
        label: 'K J Somaiya Institute of Dharma Studies'
    },
    {
        value: 'K J Somaiya School of Education',
        label: 'K J Somaiya School of Education'
    },
    {
        value: 'Somaiya Sports Academy',
        label: 'Somaiya Sports Academy'
    },
    {
        value: 'K J Somaiya School of Languages and Literature',
        label: 'K J Somaiya School of Languages and Literature'
    },
    {
        value: 'Somaiya School of Humanities and Social Science',
        label: 'Somaiya School of Humanities and Social Science'
    },
    {
        value: 'Maya Somaiya School of Music and Performing Arts',
        label: 'Maya Somaiya School of Music and Performing Arts'
    },
    {
        value: 'Somaiya School of Basic and Applied Sciences',
        label: 'Somaiya School of Basic and Applied Sciences'
    },
    {
        value: 'Somaiya Institute for Research and Consultancy',
        label: 'Somaiya Institute for Research and Consultancy'
    },
    {
        value: 'Somaiya Dhwani Chitram',
        label: 'Somaiya Dhwani Chitram'
    }
];

const DEFAULT_PRIMARY_LOGO_RESOURCE = 'Ken_ID_Card_Sample_Logo';

const PREVIEW_SAMPLE_DATA = {
    Student: {
        fullName: 'Sample Student',
        idNumber: '2023-CS-001'
    },
    Faculty: {
        fullName: 'Faculty Member',
        idNumber: 'FAC-2026-014'
    },
    Staff: {
        fullName: 'Staff Member',
        idNumber: 'STF-2026-018'
    },
    Visitor: {
        fullName: 'Visitor Pass',
        idNumber: 'VIS-2026-041'
    }
};

const THEME_OPTIONS = [
    {
        value: 'classic-professional',
        label: 'Classic Professional',
        description: 'Standard corporate look with top border.',
        accentColor: '#5665f2',
        previewOrientation: 'vertical',
        previewBackEnabled: false,
        tags: ['Vertical', 'Horizontal', '2-Sided'],
        warningTitle: 'Content Overflow Detected',
        warningMessage:
            'Some items are cut off. Try moving fields to the Back Side, removing unused fields, or switching to Horizontal layout.'
    },
    {
        value: 'modern-minimalist',
        label: 'Modern Minimalist',
        description: 'Clean layout with centered elements.',
        accentColor: '#7b84a6',
        previewOrientation: 'vertical',
        previewBackEnabled: false,
        tags: ['Vertical', 'Horizontal', '2-Sided']
    },
    {
        value: 'sleek-tech',
        label: 'Sleek Tech',
        description: 'Dark accents and geometric patterns.',
        accentColor: '#10b6ff',
        previewOrientation: 'vertical',
        previewBackEnabled: true,
        tags: ['Vertical', '2-Sided']
    },
    {
        value: 'traditional-academic',
        label: 'Traditional Academic',
        description: 'Formal serif typography and classic crest placement.',
        accentColor: '#8f6b29',
        previewOrientation: 'horizontal',
        previewBackEnabled: true,
        tags: ['Horizontal', '2-Sided'],
        badgeLabel: 'Incompatible'
    },
    {
        value: 'compact-visitor',
        label: 'Compact Visitor',
        description: 'Simplified view for temporary access.',
        accentColor: '#4aa36d',
        previewOrientation: 'vertical',
        previewBackEnabled: false,
        tags: ['Vertical', 'Horizontal']
    },
    {
        value: 'high-security',
        label: 'High-Security',
        description: 'Holographic patterns and dense data fields.',
        accentColor: '#4252dd',
        previewOrientation: 'vertical',
        previewBackEnabled: true,
        tags: ['Vertical', '2-Sided']
    }
];

const BRAND_COLOR_OPTIONS = ['#5665F2', '#169A47', '#D50000', '#FF9800', '#1F1F1F'];

const TYPOGRAPHY_OPTIONS = [
    {
        value: 'fira-sans',
        label: 'Fira Sans',
        eyebrow: 'MODERN SANS',
        sampleClass: 'branding-typography-sample branding-typography-sample--fira-sans'
    },
    {
        value: 'marcellus',
        label: 'Marcellus',
        eyebrow: 'ELEGANT SERIF',
        sampleClass: 'branding-typography-sample branding-typography-sample--marcellus'
    },
    {
        value: 'general-sans',
        label: 'General Sans',
        eyebrow: 'PROFESSIONAL SANS',
        sampleClass: 'branding-typography-sample branding-typography-sample--general-sans'
    }
];

const REQUIRED_FIELD_DEFINITIONS = [
    {
        key: 'fullName',
        label: 'Full Name',
        previewLabel: 'FULL NAME:',
        required: true,
        defaultShowLabel: true,
        kind: 'text',
        defaultSourceKey: 'accountPerson.name',
        sourceHelpText: 'Mapped from Account (Person) name.',
        sourceBadgeLabel: 'Account (Person)',
        sourceLocked: false
    },
    {
        key: 'photo',
        label: 'Photo',
        previewLabel: 'PHOTO:',
        required: true,
        defaultShowLabel: true,
        kind: 'media',
        defaultSourceKey: 'student.photo',
        sourceHelpText: 'Editable student photo source. Uses the uploaded secondary logo for preview.',
        sourceBadgeLabel: 'Editable',
        sourceLocked: false
    },
    {
        key: 'cardType',
        label: 'Card Type',
        previewLabel: 'CARD TYPE:',
        required: true,
        defaultShowLabel: true,
        kind: 'text',
        defaultSourceKey: 'basicDetails.cardType',
        sourceHelpText: 'Comes directly from Step 1 Basic Details.',
        sourceBadgeLabel: 'Basic Details',
        sourceLocked: true
    },
    {
        key: 'idNumber',
        label: 'ID Number',
        previewLabel: 'ID NUMBER:',
        required: true,
        defaultShowLabel: true,
        kind: 'text',
        defaultSourceKey: 'accountPerson.idNumber',
        sourceHelpText: 'Mapped from Account (Person) ID number.',
        sourceBadgeLabel: 'Account (Person)',
        sourceLocked: false
    },
    {
        key: 'institutionName',
        label: 'Institution Name',
        previewLabel: 'INSTITUTION NAME:',
        required: true,
        defaultShowLabel: false,
        kind: 'header',
        defaultSourceKey: 'basicDetails.instituteName',
        sourceHelpText: 'Comes directly from the selected institute in Step 1.',
        sourceBadgeLabel: 'Basic Details',
        sourceLocked: true
    },
    {
        key: 'institutionLogo',
        label: 'Institution Logo',
        previewLabel: 'INSTITUTION LOGO:',
        required: true,
        defaultShowLabel: false,
        kind: 'logo',
        defaultSourceKey: 'basicDetails.primaryLogo',
        sourceHelpText: 'Comes directly from the primary logo selected in Step 1.',
        sourceBadgeLabel: 'Basic Details',
        sourceLocked: true
    }
];

const OPTIONAL_FIELD_SECTIONS = [
    {
        key: 'identity',
        label: 'Identity',
        fields: [
            {
                key: 'department',
                label: 'Department',
                previewLabel: 'DEPARTMENT:',
                defaultShowLabel: true,
                kind: 'text',
                defaultSourceKey: 'accountPerson.department',
                sourceHelpText: 'Suggested Account (Person) field mapping.',
                sourceBadgeLabel: 'Account (Person)',
                sourceLocked: false
            }
        ]
    },
    {
        key: 'student',
        label: 'Student',
        fields: [
            {
                key: 'program',
                label: 'Program',
                previewLabel: 'PROGRAM:',
                defaultShowLabel: true,
                kind: 'text',
                defaultSourceKey: 'accountPerson.program',
                sourceHelpText: 'Suggested Account (Person) field mapping.',
                sourceBadgeLabel: 'Account (Person)',
                sourceLocked: false
            }
        ]
    },
    {
        key: 'validity',
        label: 'Validity',
        fields: [
            {
                key: 'issueDate',
                label: 'Issue Date',
                previewLabel: 'ISSUE DATE:',
                defaultShowLabel: true,
                kind: 'text',
                defaultSourceKey: 'template.issueDate',
                sourceHelpText: 'Suggested generated date value for the card.',
                sourceBadgeLabel: 'Template',
                sourceLocked: false
            }
        ]
    },
    {
        key: 'access',
        label: 'Access',
        fields: [
            {
                key: 'rfidUid',
                label: 'RFID UID',
                previewLabel: 'RFID UID:',
                defaultShowLabel: true,
                kind: 'text',
                defaultSourceKey: 'accountPerson.rfidUid',
                sourceHelpText: 'Suggested access-control mapping.',
                sourceBadgeLabel: 'Account (Person)',
                sourceLocked: false
            },
            {
                key: 'barcode',
                label: 'Barcode',
                previewLabel: 'BARCODE:',
                defaultShowLabel: true,
                kind: 'text',
                defaultSourceKey: 'accountPerson.barcode',
                sourceHelpText: 'Suggested access-control mapping.',
                sourceBadgeLabel: 'Account (Person)',
                sourceLocked: false
            },
            {
                key: 'qrCode',
                label: 'QR Code',
                previewLabel: 'QR CODE:',
                defaultShowLabel: true,
                kind: 'text',
                defaultSourceKey: 'accountPerson.qrCode',
                sourceHelpText: 'Suggested access-control mapping.',
                sourceBadgeLabel: 'Account (Person)',
                sourceLocked: false
            }
        ]
    },
    {
        key: 'accountPerson',
        label: 'Account (Person)',
        fields: [
            {
                key: 'phoneNumber',
                label: 'Phone Number',
                previewLabel: 'PHONE NUMBER:',
                defaultShowLabel: true,
                kind: 'text',
                defaultSourceKey: 'accountPerson.phone',
                sourceHelpText: 'Mapped from Account (Person) phone.',
                sourceBadgeLabel: 'Account (Person)',
                sourceLocked: false
            },
            {
                key: 'email',
                label: 'Email',
                previewLabel: 'EMAIL:',
                defaultShowLabel: true,
                kind: 'text',
                defaultSourceKey: 'accountPerson.email',
                sourceHelpText: 'Mapped from Account (Person) email.',
                sourceBadgeLabel: 'Account (Person)',
                sourceLocked: false
            },
            {
                key: 'address',
                label: 'Address',
                previewLabel: 'ADDRESS:',
                defaultShowLabel: true,
                kind: 'text',
                defaultSourceKey: 'accountPerson.address',
                sourceHelpText: 'Mapped from Account (Person) address.',
                sourceBadgeLabel: 'Account (Person)',
                sourceLocked: false
            }
        ]
    },
    {
        key: 'custom',
        label: 'Custom',
        fields: [
            {
                key: 'textBox',
                label: 'Text Box',
                previewLabel: 'TEXT:',
                defaultShowLabel: true,
                kind: 'custom',
                allowMultiple: true,
                defaultTextValue: 'Custom Text',
                defaultSourceKey: 'custom.text',
                sourceHelpText: 'Use this for manual JSON-tracked text.',
                sourceBadgeLabel: 'Custom',
                sourceLocked: false
            }
        ]
    }
];

const FIELD_DEFINITION_MAP = [...REQUIRED_FIELD_DEFINITIONS, ...OPTIONAL_FIELD_SECTIONS.flatMap((section) => section.fields)].reduce(
    (definitionMap, definitionValue) => ({
        ...definitionMap,
        [definitionValue.key]: definitionValue
    }),
    {}
);

const FIELD_CUSTOMIZATION_SAMPLE_VALUES = {
    department: 'Computer Science',
    program: 'B.Tech Computer Science',
    rfidUid: 'RFID-2036-001',
    barcode: 'BC-2026-001',
    qrCode: 'Scan to verify',
    phoneNumber: '+91 98765 43210',
    email: 'johnathan.doe@somaiya.edu',
    address: 'Somaiya Campus, Mumbai'
};

function createFieldInstance(definitionValue, sideValue, sequenceValue = 0) {
    return {
        instanceId: definitionValue.allowMultiple ? `${definitionValue.key}-${sequenceValue}` : definitionValue.key,
        fieldKey: definitionValue.key,
        label: definitionValue.label,
        previewLabel: definitionValue.previewLabel,
        side: sideValue,
        required: Boolean(definitionValue.required),
        kind: definitionValue.kind || 'text',
        allowMultiple: Boolean(definitionValue.allowMultiple),
        showLabel: definitionValue.defaultShowLabel !== false,
        textValue: definitionValue.defaultTextValue || '',
        sourceKey: definitionValue.defaultSourceKey || '',
        sourceLocked: Boolean(definitionValue.sourceLocked),
        sourceHelpText: definitionValue.sourceHelpText || '',
        sourceBadgeLabel: definitionValue.sourceBadgeLabel || 'JSON'
    };
}

function createInitialFieldCustomizationState() {
    return {
        front: REQUIRED_FIELD_DEFINITIONS.map((definitionValue, indexValue) =>
            createFieldInstance(definitionValue, 'front', indexValue + 1)
        ),
        back: []
    };
}

const INITIAL_FORM = Object.freeze({
    templateName: '',
    cardType: 'Student',
    instituteValues: [],
    isActive: true,
    deactive: false,
    includeBackVariantLayout: false,
    description: '',
    primaryLogo: DEFAULT_PRIMARY_LOGO_RESOURCE,
    secondaryLogoUrl: '',
    themeColor: '#5665f2',
    themeStyle: 'classic-professional',
    typographyStyle: 'fira-sans'
});

export default class KenIdLifecycleManager extends LightningElement {
    selectedSection = 'templates';
    currentView = 'list';
    templateSubView = 'templates';
    currentStep = 1;
    previewSide = 'front';
    isSaving = false;
    currentSaveMode = '';
    globalSearch = '';
    templateSearch = '';
    assetSearch = '';
    formData = { ...INITIAL_FORM };
    formErrors = {};
    secondaryLogoPreviewSource = '';
    secondaryLogoFileName = '';
    secondaryLogoFileData = '';
    fieldSearch = '';
    fieldCustomization = createInitialFieldCustomizationState();
    fieldInstanceCounter = 1;
    templates = [];
    globalAssets = [];
    selectedTemplateId = '';
    isLoadingTemplates = false;
    isLoadingAssets = false;
    recordTypeId;
    instituteOptions = [...FALLBACK_INSTITUTE_OPTIONS];

    connectedCallback() {
        void this.refreshTemplates();
    }


    @wire(getObjectInfo, { objectApiName: KEN_ID_CARD_OBJECT })
    wiredObjectInfo({ data }) {
        if (data) {
            this.recordTypeId = data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: INSTITUTE_FIELD })
    wiredInstitutePicklist({ data }) {
        if (data?.values?.length) {
            this.instituteOptions = data.values.map((optionValue) => ({
                label: optionValue.label,
                value: optionValue.value
            }));
        }
    }

    get sectionItems() {
        return SECTION_CONFIG.map((section) => ({
            ...section,
            className: `section-tab${this.selectedSection === section.value ? ' is-active' : ''}`
        }));
    }

    get wizardSteps() {
        return STEP_CONFIG.map((step, index) => ({
            ...step,
            showConnector: index < STEP_CONFIG.length - 1,
            circleClass: `step-circle${step.value === this.currentStep ? ' is-current' : ''}${
                step.value < this.currentStep ? ' is-complete' : ''
            }`,
            lineClass: `step-line${step.value < this.currentStep ? ' is-complete' : ''}`,
            labelClass: `step-label${step.value === this.currentStep ? ' is-current' : ''}${
                step.value < this.currentStep ? ' is-complete' : ''
            }`
        }));
    }

    get showTemplatesLanding() {
        return this.selectedSection === 'templates' && this.currentView === 'list';
    }

    get showTemplateWizard() {
        return this.selectedSection === 'templates' && this.currentView === 'wizard';
    }

    get showAppChrome() {
        return !this.showTemplateWizard;
    }

    get showSectionPlaceholder() {
        return this.selectedSection !== 'templates';
    }

    get showBasicDetailsStep() {
        return this.showTemplateWizard && this.currentStep === 1;
    }

    get showDesignThemeStep() {
        return this.showTemplateWizard && this.currentStep === 2;
    }

    get showBrandingStep() {
        return this.showTemplateWizard && this.currentStep === 4;
    }

    get showFieldCustomizationStep() {
        return this.showTemplateWizard && this.currentStep === 3;
    }

    get showReviewSaveStep() {
        return this.showTemplateWizard && this.currentStep === 5;
    }

    get showPlaceholderStep() {
        return false;
    }

    get sectionLabel() {
        return this.sectionItems.find((item) => item.value === this.selectedSection)?.label || 'Templates';
    }

    get currentStepLabel() {
        return STEP_CONFIG.find((item) => item.value === this.currentStep)?.label || 'Template';
    }

    get currentStepTitle() {
        return `Step ${this.currentStep}: ${this.currentStepLabel}`;
    }

    get currentStepSummary() {
        return `Step ${this.currentStep} of ${STEP_CONFIG.length}: ${this.currentStepLabel}`;
    }

    get currentStepPlaceholderCopy() {
        if (this.currentStep === 5) {
            return 'Review & Save is held for the next pass once the wizard branding flow is finalized.';
        }

        return `${this.currentStepLabel} is wired into the step flow. The detailed field mapping for this screen can be built next.`;
    }

    get panelStepCopy() {
        if (this.showFieldCustomizationStep) {
            return 'Choose which fields appear on the front and back of the ID card.';
        }

        if (this.showDesignThemeStep) {
            return "Choose a visual style that matches your institution's brand.";
        }

        if (this.showBrandingStep) {
            return 'Customize the visual identity of your ID cards.';
        }

        if (this.showReviewSaveStep) {
            return 'Confirm the template details before saving it into the system.';
        }

        return '';
    }

    get filteredTemplates() {
        const searchValue = this.templateSearch.trim().toLowerCase();

        return this.templates.filter((template) => {
            if (!template.isActive || template.deactive) {
                return false;
            }

            if (!searchValue) {
                return true;
            }

            const searchFields = [
                template.templateName,
                template.cardType,
                template.instituteName,
                template.designTheme
            ];

            return searchFields.some((fieldValue) => (fieldValue || '').toLowerCase().includes(searchValue));
        });
    }

    get hasTemplates() {
        return this.filteredTemplates.length > 0;
    }

    get templateSummaryDisplay() {
        const templateCount = this.templates.length;
        const label = templateCount === 1 ? 'template' : 'templates';
        return `${templateCount} ${label} • ${this.lastUpdatedDisplay}`;
    }

    get templateTableRows() {
        const searchValue = this.templateSearch.trim().toLowerCase();
        return this.templates
            .filter((template) => {
                if (!searchValue) {
                    return true;
                }
                return [template.templateName, template.cardType, template.instituteName]
                    .some((field) => (field || '').toLowerCase().includes(searchValue));
            })
            .map((template, index) => {
                let statusText = 'Draft';
                let statusClass = 'tt-status tt-status--draft';
                if (template.deactive) {
                    statusText = 'Deactive';
                    statusClass = 'tt-status tt-status--deactive';
                } else if (template.isActive) {
                    statusText = 'Active';
                    statusClass = 'tt-status tt-status--active';
                }
                return {
                    ...template,
                    uniqueIdTag: `T${index + 1}`,
                    createdDateDisplay: this.formatDateDisplay(template.createdDate || template.lastModifiedDate),
                    createdTimeDisplay: this.formatTimeDisplay(template.createdDate || template.lastModifiedDate),
                    statusText,
                    statusClass
                };
            });
    }

    get hasTemplateTableRows() {
        return this.templateTableRows.length > 0;
    }

    get showTemplatesSubView() {
        return this.templateSubView === 'templates';
    }

    get showGlobalAssetsSubView() {
        return this.templateSubView === 'globalAssets';
    }

    get templatesSubTabClass() {
        return `template-sub-tab${this.templateSubView === 'templates' ? ' is-active' : ''}`;
    }

    get globalAssetsSubTabClass() {
        return `template-sub-tab${this.templateSubView === 'globalAssets' ? ' is-active' : ''}`;
    }

    get toolbarSubtitle() {
        if (this.templateSubView === 'globalAssets') {
            return `Global Asset Repository • ${this.lastUpdatedDisplay}`;
        }
        return this.templateSummaryDisplay;
    }

    get toolbarSearchPlaceholder() {
        return this.templateSubView === 'globalAssets' ? 'Search assets...' : 'Search templates...';
    }

    get toolbarPrimaryButtonLabel() {
        return this.templateSubView === 'globalAssets' ? '+ Add Asset' : 'Customize your template';
    }

    get activeSearch() {
        return this.templateSubView === 'globalAssets' ? this.assetSearch : this.templateSearch;
    }

    get filteredGlobalAssets() {
        const searchValue = this.assetSearch.trim().toLowerCase();
        return this.globalAssets.filter((asset) => {
            if (!searchValue) {
                return true;
            }
            return asset.name.toLowerCase().includes(searchValue);
        });
    }

    get hasGlobalAssets() {
        return this.filteredGlobalAssets.length > 0;
    }

    get globalAssetItems() {
        return this.filteredGlobalAssets.map((asset) => ({
            ...asset,
            uploadedOnDateDisplay: this.formatDateDisplay(asset.uploadedOn),
            uploadedOnTimeDisplay: this.formatTimeDisplay(asset.uploadedOn)
        }));
    }

    get lastUpdatedDisplay() {
        if (!this.templates.length) {
            return 'Updated recently';
        }

        const latestTemplate = this.templates.reduce((latestRecord, currentRecord) => {
            if (!latestRecord) {
                return currentRecord;
            }

            return new Date(currentRecord.lastModifiedDate) > new Date(latestRecord.lastModifiedDate)
                ? currentRecord
                : latestRecord;
        }, null);

        return this.getRelativeUpdateLabel(latestTemplate?.lastModifiedDate);
    }

    get templateListItems() {
        return this.filteredTemplates.map((templateRecord) => ({
            ...templateRecord,
            className: `template-list-item${this.selectedTemplate?.recordId === templateRecord.recordId ? ' is-selected' : ''}`
        }));
    }

    get selectedTemplate() {
        if (!this.filteredTemplates.length) {
            return null;
        }

        return this.filteredTemplates.find((templateRecord) => templateRecord.recordId === this.selectedTemplateId) || this.filteredTemplates[0];
    }

    get hasSelectedTemplate() {
        return Boolean(this.selectedTemplate);
    }

    get selectedTemplateThemeConfig() {
        return this.getThemeConfigByStoredValue(this.selectedTemplate?.designTheme);
    }

    get selectedTemplateTypographyValue() {
        return this.getTypographyValueByStoredValue(this.selectedTemplate?.typographyStyle);
    }

    get selectedTemplatePreviewSampleData() {
        return PREVIEW_SAMPLE_DATA[this.selectedTemplate?.cardType] || PREVIEW_SAMPLE_DATA.Student;
    }

    get selectedTemplatePrimaryLogoUrl() {
        return this.resolveAssetUrl(this.selectedTemplate?.primaryLogo);
    }

    get selectedTemplateSecondaryLogoPreviewUrl() {
        return this.selectedTemplate?.secondaryLogoPreviewUrl || '';
    }

    get selectedTemplatePreviewBrandStyle() {
        return this.buildBrandStyle(this.selectedTemplate?.brandColor);
    }

    get selectedTemplatePreviewCardClass() {
        return `preview-card preview-card--${this.selectedTemplateThemeConfig.value} preview-card--font-${this.selectedTemplateTypographyValue}`;
    }

    get selectedTemplatePreviewLandscapeCardClass() {
        return `preview-card preview-card--landscape preview-card--${this.selectedTemplateThemeConfig.value} preview-card--font-${this.selectedTemplateTypographyValue}`;
    }

    get selectedTemplateIsLandscapePreview() {
        return this.selectedTemplateThemeConfig.previewOrientation === 'horizontal';
    }

    get showSelectedTemplateLandscapePreview() {
        return this.hasSelectedTemplate && this.selectedTemplateIsLandscapePreview;
    }

    get showSelectedTemplateVerticalPreview() {
        return this.hasSelectedTemplate && !this.selectedTemplateIsLandscapePreview;
    }

    get selectedTemplatePreviewInstitutionName() {
        return this.selectedTemplate?.instituteName || 'Institution Name';
    }

    get selectedTemplatePreviewTemplateName() {
        return this.selectedTemplate?.templateName || 'IDENTITY CARD';
    }

    get selectedTemplatePreviewFullName() {
        const configuredField = this.selectedTemplateFieldConfiguration?.front?.find((fieldItem) => fieldItem.fieldKey === 'fullName');
        return (
            configuredField?.displayValue?.trim() ||
            configuredField?.textValue?.trim() ||
            this.selectedTemplate?.templateName ||
            this.selectedTemplatePreviewSampleData.fullName
        );
    }

    get selectedTemplatePreviewIdNumber() {
        const configuredField = this.selectedTemplateFieldConfiguration?.front?.find((fieldItem) => fieldItem.fieldKey === 'idNumber');
        return configuredField?.displayValue?.trim() || configuredField?.textValue?.trim() || this.selectedTemplate?.idNumber || '----------';
    }

    get selectedTemplatePreviewCardTypeLabel() {
        return (this.selectedTemplate?.cardType || 'Student').toUpperCase();
    }

    get selectedTemplatePreviewCardTypeTitle() {
        return this.selectedTemplate?.cardType || 'Student';
    }

    get selectedTemplateStatusText() {
        if (this.selectedTemplate?.deactive) {
            return 'Deactive';
        }

        return this.selectedTemplate?.isActive ? 'Active' : 'Draft';
    }

    get selectedTemplateStatusClass() {
        if (this.selectedTemplate?.deactive) {
            return 'template-status is-deactive';
        }

        return `template-status${this.selectedTemplate?.isActive ? ' is-active' : ' is-draft'}`;
    }

    get selectedTemplateCardTypeDisplay() {
        return this.selectedTemplate?.cardType || 'Student';
    }

    get selectedTemplateInstituteDisplay() {
        return this.selectedTemplate?.instituteName || 'Not Set';
    }

    get selectedTemplateDeactiveLabel() {
        return this.selectedTemplate?.deactive ? 'Yes' : 'No';
    }

    get selectedTemplateBrandColorValue() {
        return this.normalizeHexColor(this.selectedTemplate?.brandColor) || '#5665F2';
    }

    get selectedTemplateBrandColorStyle() {
        return `background:${this.selectedTemplateBrandColorValue};`;
    }

    get selectedTemplateFieldConfiguration() {
        if (!this.selectedTemplate?.fieldConfigurationJson) {
            return null;
        }

        try {
            return JSON.parse(this.selectedTemplate.fieldConfigurationJson);
        } catch (error) {
            return null;
        }
    }

    get selectedTemplateDesignThemeDisplay() {
        return this.selectedTemplate?.designTheme || this.selectedTemplateThemeConfig.label;
    }

    get selectedTemplateMappedFields() {
        const configuredFieldLabels = [];
        const fieldConfiguration = this.selectedTemplateFieldConfiguration;

        if (fieldConfiguration?.front?.length) {
            configuredFieldLabels.push(
                ...fieldConfiguration.front.map((fieldItem) => ({
                    key: `front-${fieldItem.instanceId || fieldItem.fieldKey}`,
                    label: fieldItem.label
                }))
            );
        }

        if (fieldConfiguration?.back?.length) {
            configuredFieldLabels.push(
                ...fieldConfiguration.back.map((fieldItem) => ({
                    key: `back-${fieldItem.instanceId || fieldItem.fieldKey}`,
                    label: `Back: ${fieldItem.label}`
                }))
            );
        }

        if (configuredFieldLabels.length) {
            return configuredFieldLabels;
        }

        const fieldMap = {
            Student: ['Name', 'Student ID', 'Program', 'Validity'],
            Faculty: ['Name', 'Faculty ID', 'Department', 'Validity'],
            Staff: ['Name', 'Staff ID', 'Department', 'Validity'],
            Visitor: ['Name', 'Visitor ID', 'Host', 'Validity']
        };

        return (fieldMap[this.selectedTemplate?.cardType] || fieldMap.Student).map((fieldLabel) => ({
            key: `${this.selectedTemplate?.recordId || 'template'}-${fieldLabel.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`,
            label: fieldLabel
        }));
    }

    get instituteSelectOptions() {
        return this.instituteOptions;
    }

    get instituteSelectionOptions() {
        return this.instituteSelectOptions.map((instituteOption) => {
            const isSelected = this.formData.instituteValues.includes(instituteOption.value);
            return {
                ...instituteOption,
                selected: isSelected,
                checkboxItemClass: `institute-checkbox-item${isSelected ? ' is-selected' : ''}`
            };
        });
    }

    get hasInstituteOptions() {
        return this.instituteSelectOptions.length > 0;
    }

    get hasSelectedInstitutes() {
        return this.formData.instituteValues.length > 0;
    }

    get selectedInstituteTags() {
        return this.formData.instituteValues.map((value) => ({ key: value, label: value }));
    }

    get instituteEmptyCopy() {
        return 'No institute values are available.';
    }

    get fieldCustomizationSections() {
        const searchValue = this.fieldSearch.trim().toLowerCase();

        return OPTIONAL_FIELD_SECTIONS.map((sectionValue) => ({
            key: sectionValue.key,
            label: sectionValue.label,
            fields: sectionValue.fields
                .filter((fieldDefinition) => {
                    if (!searchValue) {
                        return true;
                    }

                    return (
                        fieldDefinition.label.toLowerCase().includes(searchValue) ||
                        sectionValue.label.toLowerCase().includes(searchValue)
                    );
                })
                .map((fieldDefinition) => ({
                    ...fieldDefinition,
                    isAdded: !fieldDefinition.allowMultiple && this.isFieldPlaced(fieldDefinition.key),
                    className: `field-library-item${
                        !fieldDefinition.allowMultiple && this.isFieldPlaced(fieldDefinition.key) ? ' is-disabled' : ''
                    }`
                }))
        })).filter((sectionValue) => sectionValue.fields.length > 0);
    }

    get hasFieldCustomizationSections() {
        return this.fieldCustomizationSections.length > 0;
    }

    get frontFieldCards() {
        return this.fieldCustomization.front.map((fieldInstance, indexValue, fieldList) =>
            this.buildFieldCard(fieldInstance, indexValue, fieldList.length, 'front')
        );
    }

    get backFieldCards() {
        return this.fieldCustomization.back.map((fieldInstance, indexValue, fieldList) =>
            this.buildFieldCard(fieldInstance, indexValue, fieldList.length, 'back')
        );
    }

    get frontFieldCountLabel() {
        return `${this.fieldCustomization.front.length} fields`;
    }

    get backFieldCountLabel() {
        return `${this.fieldCustomization.back.length} fields`;
    }

    get frontOptionalPreviewRows() {
        return this.fieldCustomization.front
            .filter((fieldInstance) => !fieldInstance.required)
            .map((fieldInstance) => this.buildPreviewRow(fieldInstance));
    }

    get backPreviewRows() {
        return this.fieldCustomization.back.map((fieldInstance) => this.buildPreviewRow(fieldInstance));
    }

    get hasBackPreviewRows() {
        return this.backPreviewRows.length > 0;
    }

    get hasBackCustomizationFields() {
        return this.fieldCustomization.back.length > 0;
    }

    get showPreviewFullNameLabel() {
        return this.getRequiredFieldCard('fullName')?.showLabel !== false;
    }

    get showPreviewIdNumberLabel() {
        return this.getRequiredFieldCard('idNumber')?.showLabel !== false;
    }

    get showPreviewCardTypeTextLabel() {
        return this.getRequiredFieldCard('cardType')?.showLabel !== false;
    }

    get previewCardHeaderTitle() {
        return 'IDENTITY CARD';
    }

    get selectedThemeConfig() {
        return THEME_OPTIONS.find((theme) => theme.value === this.formData.themeStyle) || THEME_OPTIONS[0];
    }

    get themeCards() {
        return THEME_OPTIONS.map((theme) => ({
            ...theme,
            cardClass: `theme-showcase-card theme-showcase-card--${theme.value}${
                this.formData.themeStyle === theme.value ? ' is-selected' : ''
            }`,
            visualClass: `theme-showcase-visual theme-showcase-visual--${theme.value}`,
            miniCardClass: `theme-mini-card theme-mini-card--${theme.value}${
                theme.previewOrientation === 'horizontal' ? ' theme-mini-card--landscape' : ''
            }`,
            showBadge: Boolean(theme.badgeLabel),
            tagItems: theme.tags.map((tag) => ({
                key: `${theme.value}-${tag.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`,
                label: tag
            }))
        }));
    }

    get brandColorValue() {
        return this.normalizeHexColor(this.formData.themeColor) || '#5665F2';
    }

    get brandColorOptions() {
        return BRAND_COLOR_OPTIONS.map((color) => ({
            value: color,
            className: `brand-color-swatch${this.brandColorValue === color ? ' is-selected' : ''}`,
            style: `background:${color};`
        }));
    }

    get customBrandColorClass() {
        return `brand-color-custom-tile${
            BRAND_COLOR_OPTIONS.includes(this.brandColorValue) ? '' : ' is-selected'
        }`;
    }

    get customBrandColorStyle() {
        return `background:${this.brandColorValue};`;
    }

    get typographyOptions() {
        return TYPOGRAPHY_OPTIONS.map((option) => ({
            ...option,
            className: `branding-typography-card${
                this.formData.typographyStyle === option.value ? ' is-selected' : ''
            }`,
            checkClass: `branding-typography-check${
                this.formData.typographyStyle === option.value ? ' is-visible' : ''
            }`
        }));
    }

    get selectedTypographyOption() {
        return TYPOGRAPHY_OPTIONS.find((option) => option.value === this.formData.typographyStyle) || TYPOGRAPHY_OPTIONS[0];
    }

    get previewEnabled() {
        return Boolean(
            this.formData.templateName.trim() &&
                this.formData.instituteValues.length &&
                this.primaryLogoPreviewUrl
        );
    }

    get primaryLogoPreviewUrl() {
        return this.resolveAssetUrl(this.formData.primaryLogo);
    }

    get secondaryLogoPreviewUrl() {
        return this.secondaryLogoPreviewSource || this.resolveAssetUrl(this.formData.secondaryLogoUrl);
    }

    get effectiveBackPreviewEnabled() {
        return Boolean(
            this.formData.includeBackVariantLayout || this.selectedThemeConfig.previewBackEnabled || this.hasBackCustomizationFields
        );
    }

    get frontPreviewClass() {
        return `preview-toggle-button${this.previewSide === 'front' ? ' is-active' : ''}`;
    }

    get backPreviewClass() {
        return `preview-toggle-button${this.previewSide === 'back' ? ' is-active' : ''}`;
    }

    get backPreviewDisabled() {
        return !this.effectiveBackPreviewEnabled;
    }

    get previewInstitutionName() {
        return this.selectedInstituteDisplay || 'Institution Name';
    }

    get previewTemplateName() {
        return this.formData.templateName.trim() || 'IDENTITY CARD';
    }

    get previewSampleData() {
        return PREVIEW_SAMPLE_DATA[this.formData.cardType] || PREVIEW_SAMPLE_DATA.Student;
    }

    get previewFullName() {
        return this.resolveFieldInstanceDisplayValue(this.getRequiredFieldCard('fullName')) || '----------';
    }

    get previewIdNumber() {
        return this.resolveFieldInstanceDisplayValue(this.getRequiredFieldCard('idNumber')) || '----------';
    }

    get previewCardTypeLabel() {
        return (this.formData.cardType || 'Student').toUpperCase();
    }

    get previewCardTypeTitle() {
        return this.formData.cardType || 'Student';
    }

    get previewDescription() {
        return this.formData.description || 'Template description appears here.';
    }

    get isLandscapePreview() {
        return this.selectedThemeConfig.previewOrientation === 'horizontal';
    }

    get showFrontPreview() {
        return this.previewSide === 'front' || this.backPreviewDisabled;
    }

    get showBackPreview() {
        return this.previewSide === 'back' && !this.backPreviewDisabled;
    }

    get showVerticalFrontPreview() {
        return this.showFrontPreview && !this.isLandscapePreview;
    }

    get showVerticalBackPreview() {
        return this.showBackPreview && !this.isLandscapePreview;
    }

    get showLandscapeFrontPreview() {
        return this.showFrontPreview && this.isLandscapePreview;
    }

    get showLandscapeBackPreview() {
        return this.showBackPreview && this.isLandscapePreview;
    }

    get previewCardClass() {
        return `preview-card preview-card--${this.formData.themeStyle || 'default'} preview-card--font-${
            this.formData.typographyStyle || 'fira-sans'
        }`;
    }

    get mutedPreviewCardClass() {
        return `${this.previewCardClass} is-muted`;
    }

    get previewLandscapeCardClass() {
        return `preview-card preview-card--landscape preview-card--${this.formData.themeStyle || 'default'} preview-card--font-${
            this.formData.typographyStyle || 'fira-sans'
        }`;
    }

    get mutedLandscapePreviewCardClass() {
        return `${this.previewLandscapeCardClass} is-muted`;
    }

    get previewBrandStyle() {
        return this.buildBrandStyle(this.brandColorValue);
    }

    get showPreviewWarning() {
        return Boolean(
            (this.showDesignThemeStep || this.showBrandingStep) &&
                this.showFrontPreview &&
                this.selectedThemeConfig.warningTitle &&
                !this.isLandscapePreview
        );
    }

    get previewWarningTitle() {
        return this.selectedThemeConfig.warningTitle || '';
    }

    get previewWarningMessage() {
        return this.selectedThemeConfig.warningMessage || '';
    }

    get nextButtonLabel() {
        return this.currentStep === STEP_CONFIG.length ? 'Save' : 'Next >';
    }

    get showPreviousAction() {
        return this.currentStep > 1;
    }

    get templateNameError() {
        return this.formErrors.templateName;
    }

    get instituteError() {
        return this.formErrors.instituteValues;
    }

    get designThemeModeLabel() {
        const orientationLabel = this.isLandscapePreview ? 'Horizontal' : 'Vertical';
        const sidedLabel = this.effectiveBackPreviewEnabled ? '2-Sided' : '1-Sided';
        return `${orientationLabel} | ${sidedLabel}`;
    }

    get showSaveActions() {
        return this.showReviewSaveStep;
    }

    get nextActionDisabled() {
        return this.isSaving;
    }

    get saveActionsDisabled() {
        return this.isSaving;
    }

    get saveAsDraftLabel() {
        return this.currentSaveMode === 'draft' ? 'Saving Draft...' : 'Save as Draft';
    }

    get saveAndActivateLabel() {
        return this.currentSaveMode === 'activate' ? 'Saving and Activating...' : 'Save and Activate';
    }

    get reviewReadyCopy() {
        const templateName = this.formData.templateName.trim() || 'Untitled Template';
        return `Template "${templateName}" is configured and ready to be used.`;
    }

    get reviewLayoutLabel() {
        const orientationLabel = this.isLandscapePreview ? 'Horizontal' : 'Vertical';
        const sidedLabel = this.effectiveBackPreviewEnabled ? '2-Sided' : '1-Sided';
        return `${orientationLabel} (${sidedLabel})`;
    }

    get reviewDeactiveLabel() {
        return this.formData.deactive ? 'Yes' : 'No';
    }

    get reviewStatusLabel() {
        if (this.formData.deactive) {
            return 'DEACTIVE';
        }

        return this.formData.isActive ? 'ACTIVE' : 'DRAFT';
    }

    get reviewStatusClass() {
        if (this.formData.deactive) {
            return 'review-status-pill is-deactive';
        }

        return `review-status-pill${this.formData.isActive ? ' is-active' : ' is-draft'}`;
    }

    get selectedInstituteDisplay() {
        return this.formatInstituteDisplay(this.formData.instituteValues);
    }

    handleSectionChange(event) {
        this.selectedSection = event.currentTarget.dataset.section;
        this.currentView = 'list';
        this.currentStep = 1;
        this.previewSide = 'front';

        if (this.selectedSection === 'templates') {
            void this.refreshTemplates(this.selectedTemplateId);
        }
    }

    handleTemplateSubViewChange(event) {
        this.templateSubView = event.currentTarget.dataset.view;
        if (this.templateSubView === 'globalAssets' && !this.globalAssets.length) {
            void this.refreshGlobalAssets();
        }
    }

    handleToolbarPrimaryAction() {
        if (this.templateSubView === 'globalAssets') {
            const fileInput = this.template.querySelector('.global-asset-file-input');
            if (fileInput) {
                fileInput.click();
            }
        } else {
            this.handleStartNewTemplate();
        }
    }

    handleActiveSearchChange(event) {
        if (this.templateSubView === 'globalAssets') {
            this.assetSearch = event.target.value;
        } else {
            this.templateSearch = event.target.value;
        }
    }

    handleGlobalAssetFileChange(event) {
        const selectedFile = event.target.files?.[0];
        if (!selectedFile) {
            return;
        }

        const fileReader = new FileReader();
        fileReader.onload = async () => {
            const fileDataUrl = fileReader.result;
            const dataUrlParts = typeof fileDataUrl === 'string' ? fileDataUrl.split(',') : [];
            const fileData = dataUrlParts.length > 1 ? dataUrlParts[1] : '';
            if (!fileData) {
                return;
            }

            this.isLoadingAssets = true;
            try {
                await saveGlobalAssetApex({ fileName: selectedFile.name, fileData });
                await this.refreshGlobalAssets();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Asset Uploaded',
                        message: `${selectedFile.name} was added to the Global Asset Repository.`,
                        variant: 'success'
                    })
                );
            } catch (error) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Upload Failed',
                        message: this.getErrorMessage(error),
                        variant: 'error'
                    })
                );
            } finally {
                this.isLoadingAssets = false;
                event.target.value = '';
            }
        };
        fileReader.readAsDataURL(selectedFile);
    }

    handleViewGlobalAsset(event) {
        const assetId = event.currentTarget.dataset.id;
        const asset = this.globalAssets.find((a) => a.contentDocumentId === assetId);
        if (asset?.previewUrl) {
            window.open(asset.previewUrl, '_blank');
        }
    }

    handleDownloadGlobalAsset(event) {
        const downloadUrl = event.currentTarget.dataset.url;
        if (downloadUrl) {
            window.open(downloadUrl, '_blank');
        }
    }

    async handleDeleteGlobalAsset(event) {
        const assetId = event.currentTarget.dataset.id;
        this.isLoadingAssets = true;
        try {
            await deleteGlobalAssetApex({ contentDocumentId: assetId });
            await this.refreshGlobalAssets();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Asset Deleted',
                    message: 'The asset was removed from the repository.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Delete Failed',
                    message: this.getErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isLoadingAssets = false;
        }
    }

    async refreshGlobalAssets() {
        this.isLoadingAssets = true;
        try {
            this.globalAssets = (await getGlobalAssetsApex()) || [];
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Load Failed',
                    message: this.getErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isLoadingAssets = false;
        }
    }

    handleGlobalSearchChange(event) {
        this.globalSearch = event.target.value;
    }

    handleTemplateSearchChange(event) {
        this.templateSearch = event.target.value;
    }

    handleFieldSearchChange(event) {
        this.fieldSearch = event.target.value;
    }

    handleTemplateSelect(event) {
        this.selectedTemplateId = event.currentTarget.dataset.id;
    }

    handleStartNewTemplate() {
        this.formData = { ...INITIAL_FORM };
        this.formErrors = {};
        this.currentStep = 1;
        this.templateSearch = '';
        this.previewSide = 'front';
        this.isSaving = false;
        this.currentSaveMode = '';
        this.secondaryLogoPreviewSource = '';
        this.secondaryLogoFileName = '';
        this.secondaryLogoFileData = '';
        this.fieldSearch = '';
        this.fieldCustomization = createInitialFieldCustomizationState();
        this.fieldInstanceCounter = 1;
        this.currentView = 'wizard';
    }

    handleBackToTemplates() {
        this.currentView = 'list';
        this.currentStep = 1;
        this.previewSide = 'front';
        this.isSaving = false;
        this.currentSaveMode = '';
        this.secondaryLogoFileData = '';
    }

    handleCancelWizard() {
        this.handleBackToTemplates();
    }

    handleInputChange(event) {
        const fieldName = event.target.dataset.field;
        this.formData = {
            ...this.formData,
            [fieldName]: event.target.value
        };
        this.clearFieldError(fieldName);
    }

    handleCheckboxChange(event) {
        const fieldName = event.target.dataset.field;
        const nextFormData = {
            ...this.formData,
            [fieldName]: event.target.checked
        };

        if (fieldName === 'deactive' && event.target.checked) {
            nextFormData.isActive = false;
        }
        if (fieldName === 'isActive' && event.target.checked) {
            nextFormData.deactive = false;
        }

        this.formData = nextFormData;

        if (
            fieldName === 'includeBackVariantLayout' &&
            !event.target.checked &&
            !this.selectedThemeConfig.previewBackEnabled &&
            this.previewSide === 'back'
        ) {
            this.previewSide = 'front';
        }
    }

    handleInstituteChange(event) {
        const selectedInstituteValues = Array.from(event.target.selectedOptions || []).map((optionValue) => optionValue.value);
        this.formData = {
            ...this.formData,
            instituteValues: selectedInstituteValues
        };
        this.clearFieldError('instituteValues');
    }

    handleInstituteCheckboxChange(event) {
        const value = event.target.dataset.value;
        const isChecked = event.target.checked;
        let updatedValues = [...this.formData.instituteValues];
        if (isChecked && !updatedValues.includes(value)) {
            updatedValues.push(value);
        } else if (!isChecked) {
            updatedValues = updatedValues.filter((v) => v !== value);
        }
        this.formData = { ...this.formData, instituteValues: updatedValues };
        this.clearFieldError('instituteValues');
    }

    handleRemoveInstituteTag(event) {
        const valueToRemove = event.currentTarget.dataset.value;
        this.formData = {
            ...this.formData,
            instituteValues: this.formData.instituteValues.filter((v) => v !== valueToRemove)
        };
    }

    handleAddField(event) {
        const fieldDefinition = FIELD_DEFINITION_MAP[event.currentTarget.dataset.fieldKey];
        if (!fieldDefinition) {
            return;
        }

        if (!fieldDefinition.allowMultiple && this.isFieldPlaced(fieldDefinition.key)) {
            return;
        }

        this.fieldInstanceCounter += 1;
        const nextFieldInstance = createFieldInstance(fieldDefinition, 'front', this.fieldInstanceCounter);
        this.fieldCustomization = {
            ...this.fieldCustomization,
            front: [...this.fieldCustomization.front, nextFieldInstance]
        };
    }

    handlePreviewSideToggle(event) {
        const requestedSide = event.currentTarget.dataset.side;
        if (requestedSide === 'back' && this.backPreviewDisabled) {
            return;
        }
        this.previewSide = requestedSide;
    }

    handleSecondaryLogoUploadClick() {
        const fileInput = this.template.querySelector('.secondary-logo-input');
        if (fileInput) {
            fileInput.click();
        }
    }

    handleSecondaryLogoFileChange(event) {
        const selectedFile = event.target.files?.[0];
        if (!selectedFile) {
            return;
        }

        this.secondaryLogoFileName = selectedFile.name;
        const fileReader = new FileReader();
        fileReader.onload = () => {
            const fileDataUrl = fileReader.result;
            const dataUrlParts = typeof fileDataUrl === 'string' ? fileDataUrl.split(',') : [];
            this.secondaryLogoPreviewSource = fileDataUrl;
            this.secondaryLogoFileData = dataUrlParts.length > 1 ? dataUrlParts[1] : '';
            this.formData = {
                ...this.formData,
                secondaryLogoUrl: ''
            };
        };
        fileReader.readAsDataURL(selectedFile);
    }

    handleThemeStyleSelect(event) {
        const selectedTheme =
            THEME_OPTIONS.find((theme) => theme.value === event.currentTarget.dataset.value) || THEME_OPTIONS[0];

        this.formData = {
            ...this.formData,
            themeStyle: selectedTheme.value,
            themeColor: selectedTheme.accentColor
        };

        if (!selectedTheme.previewBackEnabled && !this.formData.includeBackVariantLayout && this.previewSide === 'back') {
            this.previewSide = 'front';
        }
    }

    handleFieldCardAction(event) {
        const fieldId = event.currentTarget.dataset.id;
        const fieldSide = event.currentTarget.dataset.side;
        const actionName = event.currentTarget.dataset.action;

        if (!fieldId || !fieldSide || !actionName) {
            return;
        }

        if (actionName === 'move-back') {
            this.moveFieldInstance(fieldId, 'front', 'back');
            return;
        }

        if (actionName === 'move-front') {
            this.moveFieldInstance(fieldId, 'back', 'front');
            return;
        }

        if (actionName === 'delete') {
            this.removeFieldInstance(fieldId, fieldSide);
            return;
        }

        if (actionName === 'move-up') {
            this.reorderFieldInstance(fieldId, fieldSide, -1);
            return;
        }

        if (actionName === 'move-down') {
            this.reorderFieldInstance(fieldId, fieldSide, 1);
        }
    }

    handleFieldLabelToggle(event) {
        const fieldId = event.target.dataset.id;
        const fieldSide = event.target.dataset.side;
        const isChecked = event.target.checked;

        this.updateFieldInstance(fieldId, fieldSide, (fieldInstance) => ({
            ...fieldInstance,
            showLabel: isChecked
        }));
    }

    handleCustomTextChange(event) {
        const fieldId = event.target.dataset.id;
        const fieldSide = event.target.dataset.side;
        const nextValue = event.target.value;

        this.updateFieldInstance(fieldId, fieldSide, (fieldInstance) => ({
            ...fieldInstance,
            textValue: nextValue
        }));
    }

    handleFieldEditorTextChange(event) {
        const fieldId = event.target.dataset.id;
        const fieldSide = event.target.dataset.side;
        const nextValue = event.target.value;

        this.updateFieldInstance(fieldId, fieldSide, (fieldInstance) => ({
            ...fieldInstance,
            textValue: nextValue
        }));
    }

    handleInstituteFieldChange(event) {
        this.handleInstituteChange(event);
    }

    handlePhotoFieldUploadClick() {
        this.handleSecondaryLogoUploadClick();
    }

    handleBrandColorSelect(event) {
        this.formData = {
            ...this.formData,
            themeColor: event.currentTarget.dataset.value
        };
    }

    handleBrandColorInput(event) {
        const normalizedColor = this.normalizeHexColor(event.target.value);
        if (!normalizedColor) {
            return;
        }

        this.formData = {
            ...this.formData,
            themeColor: normalizedColor
        };
    }

    handleTypographyStyleSelect(event) {
        this.formData = {
            ...this.formData,
            typographyStyle: event.currentTarget.dataset.value
        };
    }

    handlePreviousStep() {
        if (this.isSaving) {
            return;
        }

        if (this.currentStep > 1) {
            this.currentStep -= 1;
        }
    }

    handleNextStep() {
        if (this.isSaving) {
            return;
        }

        if (this.currentStep === 1 && !this.validateBasicDetails()) {
            return;
        }

        if (this.currentStep === 2 && !this.formData.themeStyle) {
            this.formData = {
                ...this.formData,
                themeStyle: THEME_OPTIONS[0].value,
                themeColor: THEME_OPTIONS[0].accentColor
            };
        }

        if (this.currentStep < STEP_CONFIG.length) {
            this.currentStep += 1;
            return;
        }

        this.handleBackToTemplates();
    }

    async handleSaveAsDraft() {
        this.formData = {
            ...this.formData,
            isActive: false
        };
        await this.saveTemplate('draft');
    }

    async handleSaveAndActivate() {
        this.formData = {
            ...this.formData,
            isActive: !this.formData.deactive
        };
        await this.saveTemplate('activate');
    }

    validateBasicDetails() {
        const nextErrors = {};

        if (!this.formData.templateName.trim()) {
            nextErrors.templateName = 'Template Name is required.';
        }

        if (!this.formData.instituteValues.length) {
            nextErrors.instituteValues = 'Institute is required.';
        }

        this.formErrors = nextErrors;
        return Object.keys(nextErrors).length === 0;
    }

    clearFieldError(fieldName) {
        if (!this.formErrors[fieldName]) {
            return;
        }

        const nextErrors = { ...this.formErrors };
        delete nextErrors[fieldName];
        this.formErrors = nextErrors;
    }

    resolveAssetUrl(sourceValue) {
        if (!sourceValue) {
            return '';
        }

        if (sourceValue === DEFAULT_PRIMARY_LOGO_RESOURCE) {
            return samplePrimaryLogo;
        }

        if (sourceValue.startsWith('http://') || sourceValue.startsWith('https://') || sourceValue.startsWith('/')) {
            return sourceValue;
        }

        return `/resource/${sourceValue}`;
    }

    buildFieldCard(fieldInstance, indexValue, listLength, sideValue) {
        const editorState = this.buildFieldCardEditorState(fieldInstance);

        return {
            ...fieldInstance,
            actionLabel: sideValue === 'front' ? 'Move to Back' : 'Move to Front',
            actionName: sideValue === 'front' ? 'move-back' : 'move-front',
            canMoveAcross: !fieldInstance.required,
            canDelete: !fieldInstance.required,
            canMoveUp: !fieldInstance.required && indexValue > 0,
            canMoveDown: !fieldInstance.required && indexValue < listLength - 1,
            disableMoveUp: fieldInstance.required || indexValue === 0,
            disableMoveDown: fieldInstance.required || indexValue >= listLength - 1,
            showTextInput: fieldInstance.kind === 'custom',
            inputPlaceholder: 'Enter custom text',
            showRequiredBadge: fieldInstance.required,
            cardClass: `field-card${fieldInstance.required ? ' is-required' : ''}`,
            ...editorState
        };
    }

    buildFieldCardEditorState(fieldInstance) {
        const resolvedDisplayValue = this.resolveFieldInstanceDisplayValue(fieldInstance);

        switch (fieldInstance.fieldKey) {
            case 'fullName':
                return {
                    showValueEditor: true,
                    showValueSummary: true,
                    valueSummaryLabel: 'Current Value',
                    valueSummaryValue: resolvedDisplayValue || 'Will use Template Name from Step 1',
                    valueEditorLabel: 'Full Name',
                    valueEditorPlaceholder: 'Enter full name',
                    valueEditorValue: fieldInstance.textValue || this.formData.templateName.trim(),
                    editorHelpText: 'Defaults to Template Name from Step 1 Basic Details until you override it here.'
                };
            case 'idNumber':
                return {
                    showValueEditor: true,
                    showValueSummary: true,
                    valueSummaryLabel: 'Current Value',
                    valueSummaryValue: resolvedDisplayValue || 'Not set yet',
                    valueEditorLabel: 'ID Number',
                    valueEditorPlaceholder: 'Enter ID number',
                    valueEditorValue: fieldInstance.textValue || '',
                    editorHelpText: 'Enter the ID number that should appear on the card preview.'
                };
            case 'cardType':
                return {
                    showValueSummary: true,
                    valueSummaryLabel: 'From Basic Details',
                    valueSummaryValue: resolvedDisplayValue || 'Student',
                    showCardTypeEditor: true,
                    editorHelpText: 'This stays synced with Step 1 and can also be changed here.'
                };
            case 'institutionName':
                return {
                    showValueSummary: true,
                    valueSummaryLabel: 'From Basic Details',
                    valueSummaryValue: resolvedDisplayValue || 'Select one or more institutes in Step 1',
                    showInstituteEditor: true,
                    editorHelpText: 'This uses the selected institute values from Step 1 and updates here as well.'
                };
            case 'institutionLogo':
                return {
                    showValueSummary: true,
                    valueSummaryLabel: 'From Basic Details',
                    valueSummaryValue: this.formData.primaryLogo || DEFAULT_PRIMARY_LOGO_RESOURCE,
                    showPrimaryLogoEditor: true,
                    primaryLogoPreviewUrl: this.primaryLogoPreviewUrl,
                    primaryLogoResourceValue: this.formData.primaryLogo,
                    editorHelpText: 'Primary logo comes from Step 1 Basic Details and can be adjusted here if needed.'
                };
            case 'photo':
                return {
                    showValueSummary: true,
                    valueSummaryLabel: 'Current Photo',
                    valueSummaryValue: this.secondaryLogoFileName || this.formData.secondaryLogoUrl || 'No photo uploaded yet',
                    showPhotoEditor: true,
                    photoPreviewUrl: this.secondaryLogoPreviewUrl,
                    photoFileName: this.secondaryLogoFileName,
                    editorHelpText: 'Student photo uses the uploaded secondary logo from Basic Details.'
                };
            default:
                return {};
        }
    }

    buildPreviewRow(fieldInstance) {
        return {
            key: fieldInstance.instanceId,
            label: fieldInstance.previewLabel,
            showLabel: fieldInstance.showLabel,
            value: this.getFieldInstanceValue(fieldInstance),
            rowClass: `preview-dynamic-row${fieldInstance.showLabel ? '' : ' preview-dynamic-row--compact'}`
        };
    }

    buildFieldConfigurationJson() {
        return JSON.stringify({
            version: 1,
            appearance: {
                designTheme: this.selectedThemeConfig.label,
                brandColor: this.brandColorValue,
                typographyStyle: this.selectedTypographyOption.label
            },
            front: this.fieldCustomization.front.map((fieldInstance) => this.serializeFieldInstance(fieldInstance)),
            back: this.fieldCustomization.back.map((fieldInstance) => this.serializeFieldInstance(fieldInstance))
        });
    }

    serializeFieldInstance(fieldInstance) {
        return {
            instanceId: fieldInstance.instanceId,
            fieldKey: fieldInstance.fieldKey,
            label: fieldInstance.label,
            previewLabel: fieldInstance.previewLabel,
            side: fieldInstance.side,
            required: fieldInstance.required,
            kind: fieldInstance.kind,
            showLabel: fieldInstance.showLabel,
            textValue: fieldInstance.textValue,
            displayValue: this.resolveFieldInstanceDisplayValue(fieldInstance),
            sourceKey: fieldInstance.sourceKey,
            sourceLocked: fieldInstance.sourceLocked,
            sourceHelpText: fieldInstance.sourceHelpText,
            sourceBadgeLabel: fieldInstance.sourceBadgeLabel
        };
    }

    async saveTemplate(saveMode) {
        if (this.isSaving) {
            return;
        }

        if (!this.validateBasicDetails()) {
            return;
        }

        this.isSaving = true;
        this.currentSaveMode = saveMode;

        const requestPayload = {
            templateName: this.formData.templateName.trim(),
            cardType: this.formData.cardType,
            instituteValues: [...this.formData.instituteValues],
            isActive: this.formData.deactive ? false : this.formData.isActive,
            deactive: this.formData.deactive,
            includeBackVariantLayout: this.formData.includeBackVariantLayout,
            description: this.formData.description?.trim() || '',
            primaryLogo: this.formData.primaryLogo,
            secondaryLogoUrl: this.getSavableSecondaryLogoUrl(),
            secondaryLogoFileName: this.secondaryLogoFileName,
            secondaryLogoFileData: this.secondaryLogoFileData,
            idNumber: this.resolveFieldInstanceDisplayValue(this.getRequiredFieldCard('idNumber')) || '',
            designTheme: this.selectedThemeConfig.label,
            brandColor: this.brandColorValue,
            typographyStyle: this.selectedTypographyOption.label,
            fieldConfigurationJson: this.buildFieldConfigurationJson()
        };

        try {
            const result = await saveKenTemplate({ request: requestPayload });
            const activatedTemplate = Boolean(result.isActive);
            const savedAsDeactive = Boolean(result.deactive);

            this.formData = {
                ...this.formData,
                instituteValues: result.instituteValues || this.formData.instituteValues,
                isActive: typeof result.isActive === 'boolean' ? result.isActive : this.formData.isActive,
                deactive: typeof result.deactive === 'boolean' ? result.deactive : this.formData.deactive,
                secondaryLogoUrl: result.secondaryLogoUrl || this.formData.secondaryLogoUrl
            };

            await this.refreshTemplates(result.recordId);

            this.dispatchEvent(
                new ShowToastEvent({
                    title: savedAsDeactive ? 'Template Saved as Deactive' : activatedTemplate ? 'Template Activated' : 'Draft Saved',
                    message: `${requestPayload.templateName} was saved successfully.`,
                    variant: 'success'
                })
            );

            this.handleBackToTemplates();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Save Failed',
                    message: this.getErrorMessage(error),
                    variant: 'error'
                })
            );
            this.isSaving = false;
            this.currentSaveMode = '';
        }
    }

    getSavableSecondaryLogoUrl() {
        const candidateValue = this.formData.secondaryLogoUrl?.trim();
        if (!candidateValue) {
            return '';
        }

        return /^(https?:\/\/|\/)/i.test(candidateValue) ? candidateValue : '';
    }

    isFieldPlaced(fieldKey) {
        return [...this.fieldCustomization.front, ...this.fieldCustomization.back].some(
            (fieldInstance) => fieldInstance.fieldKey === fieldKey
        );
    }

    getRequiredFieldCard(fieldKey) {
        return this.fieldCustomization.front.find((fieldInstance) => fieldInstance.fieldKey === fieldKey);
    }

    moveFieldInstance(fieldId, sourceSide, targetSide) {
        const sourceFields = [...this.fieldCustomization[sourceSide]];
        const targetFields = [...this.fieldCustomization[targetSide]];
        const sourceIndex = sourceFields.findIndex((fieldInstance) => fieldInstance.instanceId === fieldId);
        if (sourceIndex < 0) {
            return;
        }

        const [fieldInstance] = sourceFields.splice(sourceIndex, 1);
        targetFields.push({
            ...fieldInstance,
            side: targetSide
        });

        this.fieldCustomization = {
            ...this.fieldCustomization,
            [sourceSide]: sourceFields,
            [targetSide]: targetFields
        };

        if (sourceSide === 'back' && !sourceFields.length && !this.formData.includeBackVariantLayout && !this.selectedThemeConfig.previewBackEnabled) {
            this.previewSide = 'front';
        }
    }

    removeFieldInstance(fieldId, sideValue) {
        const nextFields = this.fieldCustomization[sideValue].filter((fieldInstance) => fieldInstance.instanceId !== fieldId);
        this.fieldCustomization = {
            ...this.fieldCustomization,
            [sideValue]: nextFields
        };

        if (sideValue === 'back' && !nextFields.length && !this.formData.includeBackVariantLayout && !this.selectedThemeConfig.previewBackEnabled) {
            this.previewSide = 'front';
        }
    }

    reorderFieldInstance(fieldId, sideValue, directionValue) {
        const nextFields = [...this.fieldCustomization[sideValue]];
        const currentIndex = nextFields.findIndex((fieldInstance) => fieldInstance.instanceId === fieldId);
        const targetIndex = currentIndex + directionValue;

        if (currentIndex < 0 || targetIndex < 0 || targetIndex >= nextFields.length) {
            return;
        }

        [nextFields[currentIndex], nextFields[targetIndex]] = [nextFields[targetIndex], nextFields[currentIndex]];

        this.fieldCustomization = {
            ...this.fieldCustomization,
            [sideValue]: nextFields
        };
    }

    updateFieldInstance(fieldId, sideValue, updateCallback) {
        const nextFields = this.fieldCustomization[sideValue].map((fieldInstance) =>
            fieldInstance.instanceId === fieldId ? updateCallback(fieldInstance) : fieldInstance
        );

        this.fieldCustomization = {
            ...this.fieldCustomization,
            [sideValue]: nextFields
        };
    }

    getFieldInstanceValue(fieldInstance) {
        switch (fieldInstance.fieldKey) {
            case 'fullName':
                return this.resolveFieldInstanceDisplayValue(fieldInstance) || '----------';
            case 'cardType':
                return this.resolveFieldInstanceDisplayValue(fieldInstance) || this.previewCardTypeTitle;
            case 'idNumber':
                return this.resolveFieldInstanceDisplayValue(fieldInstance) || '----------';
            case 'institutionName':
                return this.resolveFieldInstanceDisplayValue(fieldInstance) || this.previewInstitutionName;
            case 'department':
                return FIELD_CUSTOMIZATION_SAMPLE_VALUES.department;
            case 'program':
                return FIELD_CUSTOMIZATION_SAMPLE_VALUES.program;
            case 'issueDate':
                return this.formatDateDisplay(this.getIssueDateSample());
            case 'rfidUid':
                return FIELD_CUSTOMIZATION_SAMPLE_VALUES.rfidUid;
            case 'barcode':
                return FIELD_CUSTOMIZATION_SAMPLE_VALUES.barcode;
            case 'qrCode':
                return FIELD_CUSTOMIZATION_SAMPLE_VALUES.qrCode;
            case 'phoneNumber':
                return FIELD_CUSTOMIZATION_SAMPLE_VALUES.phoneNumber;
            case 'email':
                return FIELD_CUSTOMIZATION_SAMPLE_VALUES.email;
            case 'address':
                return FIELD_CUSTOMIZATION_SAMPLE_VALUES.address;
            case 'textBox':
                return fieldInstance.textValue?.trim() || 'Custom Text';
            default:
                return '';
        }
    }

    resolveFieldInstanceDisplayValue(fieldInstance) {
        if (!fieldInstance) {
            return '';
        }

        const explicitTextValue = fieldInstance.textValue?.trim();
        if (explicitTextValue) {
            return explicitTextValue;
        }

        switch (fieldInstance.fieldKey) {
            case 'fullName':
                return this.formData.templateName.trim();
            case 'cardType':
                return this.formData.cardType || 'Student';
            case 'institutionName':
                return this.selectedInstituteDisplay || '';
            case 'institutionLogo':
                return this.formData.primaryLogo || DEFAULT_PRIMARY_LOGO_RESOURCE;
            case 'photo':
                return this.secondaryLogoFileName || this.formData.secondaryLogoUrl || '';
            case 'idNumber':
                return '';
            default:
                return '';
        }
    }

    getIssueDateSample() {
        return new Date();
    }

    formatInstituteDisplay(instituteValues) {
        if (!Array.isArray(instituteValues) || !instituteValues.length) {
            return '';
        }

        return instituteValues.join(', ');
    }

    getErrorMessage(error) {
        const pageErrors = error?.body?.output?.errors;
        if (pageErrors?.length) {
            return pageErrors[0].message;
        }

        const fieldErrors = error?.body?.output?.fieldErrors;
        if (fieldErrors) {
            const firstFieldError = Object.values(fieldErrors).flat()[0];
            if (firstFieldError?.message) {
                return firstFieldError.message;
            }
        }

        return error?.body?.message || error?.message || 'Unable to save the ID card template.';
    }

    async refreshTemplates(selectedTemplateId = '') {
        this.isLoadingTemplates = true;

        try {
            const templateResults = await getKenTemplates();
            this.templates = templateResults || [];

            if (selectedTemplateId) {
                this.selectedTemplateId = selectedTemplateId;
            } else if (!this.selectedTemplateId || !this.templates.some((templateRecord) => templateRecord.recordId === this.selectedTemplateId)) {
                this.selectedTemplateId = this.templates.find((templateRecord) => templateRecord.isActive)?.recordId || this.templates[0]?.recordId || '';
            }
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Template Load Failed',
                    message: this.getErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isLoadingTemplates = false;
        }
    }

    getThemeConfigByStoredValue(storedThemeValue) {
        return (
            THEME_OPTIONS.find((themeOption) => themeOption.value === storedThemeValue || themeOption.label === storedThemeValue) ||
            THEME_OPTIONS[0]
        );
    }

    getTypographyValueByStoredValue(storedTypographyValue) {
        return (
            TYPOGRAPHY_OPTIONS.find(
                (typographyOption) =>
                    typographyOption.value === storedTypographyValue || typographyOption.label === storedTypographyValue
            )?.value || TYPOGRAPHY_OPTIONS[0].value
        );
    }

    buildBrandStyle(colorValue) {
        const brandColor = this.normalizeHexColor(colorValue) || '#5665F2';
        const darkerColor = this.adjustHexColor(brandColor, -36);
        const lighterColor = this.adjustHexColor(brandColor, 48);
        const paleColor = this.adjustHexColor(brandColor, 100);
        return `--ken-brand-color:${brandColor};--ken-brand-color-dark:${darkerColor};--ken-brand-color-light:${lighterColor};--ken-brand-color-pale:${paleColor};`;
    }

    formatDateDisplay(dateValue) {
        if (!dateValue) {
            return '----------';
        }

        return new Intl.DateTimeFormat('en-US', {
            year: 'numeric',
            month: 'short',
            day: '2-digit'
        }).format(new Date(dateValue));
    }

    formatTimeDisplay(dateValue) {
        if (!dateValue) {
            return '';
        }

        return new Intl.DateTimeFormat('en-US', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: true
        }).format(new Date(dateValue));
    }

    getRelativeUpdateLabel(dateValue) {
        if (!dateValue) {
            return 'Updated recently';
        }

        const differenceMs = Date.now() - new Date(dateValue).getTime();
        const differenceMinutes = Math.max(1, Math.round(differenceMs / 60000));

        if (differenceMinutes < 60) {
            return `Updated ${differenceMinutes}m ago`;
        }

        const differenceHours = Math.round(differenceMinutes / 60);
        if (differenceHours < 24) {
            return `Updated ${differenceHours}h ago`;
        }

        const differenceDays = Math.round(differenceHours / 24);
        return `Updated ${differenceDays}d ago`;
    }

    normalizeHexColor(colorValue) {
        if (!colorValue) {
            return '';
        }

        const trimmedValue = colorValue.trim().toUpperCase();
        const normalizedValue = trimmedValue.startsWith('#') ? trimmedValue : `#${trimmedValue}`;
        return /^#[0-9A-F]{6}$/.test(normalizedValue) ? normalizedValue : '';
    }

    adjustHexColor(colorValue, amount) {
        const normalizedColor = this.normalizeHexColor(colorValue) || '#5665F2';
        const colorNumber = parseInt(normalizedColor.slice(1), 16);
        const red = Math.max(0, Math.min(255, ((colorNumber >> 16) & 255) + amount));
        const green = Math.max(0, Math.min(255, ((colorNumber >> 8) & 255) + amount));
        const blue = Math.max(0, Math.min(255, (colorNumber & 255) + amount));
        return `#${[red, green, blue]
            .map((channel) => channel.toString(16).padStart(2, '0'))
            .join('')
            .toUpperCase()}`;
    }
}