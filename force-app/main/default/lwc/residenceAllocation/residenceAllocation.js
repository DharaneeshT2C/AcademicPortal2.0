import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getResidenceAllocationData from '@salesforce/apex/HostelDashboardController.getResidenceAllocationData';
import getOrganizationDefaults from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';

export default class ResidenceAllocation extends NavigationMixin(LightningElement) {
    static DEFAULT_PRIMARY = '#3061FF';
    static DEFAULT_SECONDARY = '#EAEFFF';

    organizationDefaults = {};
    pendingPrimary = ResidenceAllocation.DEFAULT_PRIMARY;
    pendingSecondary = ResidenceAllocation.DEFAULT_SECONDARY;
    // Current state: 'initial', 'underReview', 'rejected', 'provisional', 'allocated'
    currentState = 'initial';
    currentStep = 1; // 1-4 for progress tracker
    hasStateOverrideFromUrl = false;
    isLoading = false;
    isThemeLoaded = false;
    dynamicPreferences = [];
    allocationMessage = null;
    canStart = true;
    allotmentDetails = {
        title: '',
        subtitle: '',
        building: '--',
        roomNumber: '--',
        floor: '--',
        checkInDate: '--',
        annualFee: '--',
        featureLine: ''
    };
    allotmentRoommates = [];
    amenityItems = [];
    paymentDeadline = null;
    submittedOn = null;
    isAmenitiesModalOpen = false;

    @wire(CurrentPageReference)
    setCurrentPageReference(pageRef) {
        if (pageRef) {
            // Check for step parameter in URL (e.g., ?step=2)
            const step = Number.parseInt(pageRef.state?.step, 10);
            if (step === 2) {
                this.hasStateOverrideFromUrl = true;
                this.currentState = 'underReview';
                this.currentStep = 2;
            }
            if (step === 3) {
                this.hasStateOverrideFromUrl = true;
                this.currentState = 'provisional';
                this.currentStep = 3;
            }
            if (step === 1) {
                this.hasStateOverrideFromUrl = true;
                this.currentState = 'initial';
                this.currentStep = 1;
            }
            
            // Check for count parameter
            if (pageRef.state?.count) {
                this.preferenceCount = parseInt(pageRef.state.count, 10);
            }
        }
    }

    connectedCallback() {
        this.loadOrganizationDefaults();
        this.loadResidenceAllocationData();
    }

    renderedCallback() {
        if (this.pendingPrimary || this.pendingSecondary) {
            this.applyTheme(this.pendingPrimary, this.pendingSecondary);
        }
    }

    async loadOrganizationDefaults() {
        try {
            const data = await getOrganizationDefaults();
            if (data) {
                this.organizationDefaults = data;
                this.applyTheme(data.primary, data.secondary);
            } else {
                this.applyTheme();
            }
        } catch (error) {
            console.error('Error loading organization defaults:', error);
            this.applyTheme();
        } finally {
            this.isThemeLoaded = true;
        }
    }

    get allocationPageClass() {
        return this.isThemeLoaded ? 'allocation-page' : 'allocation-page hidden';
    }

    applyTheme(primary, secondary) {
        const resolvedPrimary = primary || ResidenceAllocation.DEFAULT_PRIMARY;
        const resolvedSecondary = secondary || ResidenceAllocation.DEFAULT_SECONDARY;
        this.pendingPrimary = resolvedPrimary;
        this.pendingSecondary = resolvedSecondary;

        if (!this.template?.host) {
            return;
        }

        this.template.host.style.setProperty('--primary-color', resolvedPrimary);
        this.template.host.style.setProperty('--secondary-color', resolvedSecondary);
        this.pendingPrimary = null;
        this.pendingSecondary = null;
    }

    preferenceCount = 3;

    get preferences() {
        if (this.dynamicPreferences.length > 0) {
            return this.dynamicPreferences.slice(0, this.preferenceCount || this.dynamicPreferences.length);
        }
        return this.mockPreferences.slice(0, this.preferenceCount);
    }

    mockPreferences = [
        {
            id: 1,
            type: 'Type A Residence',
            preference: 'Preference 1',
            floor: '1st Floor',
            emails: 'aswin.k@gmail.com',
            sharing: '2',
            ac: 'Non-AC',
            bathroom: 'Attached bathroom',
            // Icon Flags
            isTwin: true,
            isNonAC: true,
            hasBath: true
        },
        {
            id: 2,
            type: 'Type B Residence',
            preference: 'Preference 2',
            floor: '1st Floor',
            emails: 'aswin.k@gmail.com, dhruv.v@gmail.com',
            sharing: '3',
            ac: 'AC',
            // bathroom: null,
            isTriple: true,
            isAC: true
        },
        {
            id: 3,
            type: 'Type E Residence',
            preference: 'Preference 3',
            floor: '4th Floor',
            emails: '', // Single sharing usually no roommate?
            sharing: '1',
            ac: 'AC',
            bathroom: 'Attached bathroom',
            isSingle: true,
            isAC: true,
            hasBath: true
        }
    ];

    // State getters
    get isInitialState() {
        return this.currentState === 'initial';
    }

    get isUnderReviewState() {
        return this.currentState === 'underReview';
    }

    get isRejectedState() {
        return this.currentState === 'rejected';
    }

    get isProvisionalState() {
        return this.currentState === 'provisional';
    }

    get hasPaymentDeadline() {
        return !!this.paymentDeadline;
    }

    get hasAllotmentRoommates() {
        return this.allotmentRoommates.length > 0;
    }

    get hasAmenities() {
        return this.amenityItems.length > 0;
    }

    get initialStateDescription() {
        return (
            this.allocationMessage ||
            'Select up to 3 residence preferences to begin the allocation process.'
        );
    }

    get isGetStartedDisabled() {
        return this.canStart === false;
    }

    // Progress tracker classes
    get step1CircleClass() {
        if (this.currentStep > 1) return 'progress-circle completed';
        if (this.currentStep === 1) return 'progress-circle active';
        return 'progress-circle';
    }

    get step2CircleClass() {
        if (this.currentState === 'rejected') return 'progress-circle rejected';
        if (this.currentStep > 2) return 'progress-circle completed';
        if (this.currentStep === 2) return 'progress-circle active';
        return 'progress-circle';
    }

    get step3CircleClass() {
        if (this.currentStep > 3) return 'progress-circle completed';
        if (this.currentStep === 3) return 'progress-circle active';
        return 'progress-circle';
    }

    get step4CircleClass() {
        if (this.currentStep > 4) return 'progress-circle completed';
        if (this.currentStep === 4) return 'progress-circle active';
        return 'progress-circle';
    }

    get step1BoxClass() {
        if (this.currentStep > 1) return 'progress-box completed';
        if (this.currentStep === 1) return 'progress-box active';
        return 'progress-box';
    }

    get step2BoxClass() {
        if (this.currentState === 'rejected') return 'progress-box rejected';
        if (this.currentStep > 2) return 'progress-box completed';
        if (this.currentStep === 2) return 'progress-box active';
        return 'progress-box';
    }

    get step3BoxClass() {
        if (this.currentStep > 3) return 'progress-box completed';
        if (this.currentStep === 3) return 'progress-box active';
        return 'progress-box';
    }

    get step4BoxClass() {
        if (this.currentStep > 4) return 'progress-box completed';
        if (this.currentStep === 4) return 'progress-box active';
        return 'progress-box';
    }

    get step2Label() {
        return this.currentState === 'rejected' ? 'Rejected' : 'Preference Review';
    }

    async loadResidenceAllocationData() {
        this.isLoading = true;
        try {
            const data = await getResidenceAllocationData();
            this.applyResidenceAllocationData(data);
        } catch (error) {
            console.error('Error loading residence allocation data', error);
        } finally {
            this.isLoading = false;
        }
    }

    applyResidenceAllocationData(data) {
        if (!data) {
            return;
        }

        const mappedPreferences = this.mapPreferencesFromData(data.preferences || []);
        if (mappedPreferences.length > 0) {
            this.dynamicPreferences = mappedPreferences;
            this.preferenceCount = mappedPreferences.length;
        }

        this.submittedOn = this.normalizeText(data.submittedOn);
        this.applyAllotmentData(data);

        if (this.hasStateOverrideFromUrl) {
            return;
        }

        const resolvedState = this.normalizeState(data.state);
        this.allocationMessage = this.normalizeText(data.message);
        this.canStart = data.canStart !== false;
        if (!resolvedState) {
            return;
        }

        this.currentState = resolvedState;
        this.currentStep = this.resolveStep(resolvedState, data.step);
    }

    get submittedOnLabel() {
        return this.submittedOn || '--';
    }

    normalizeState(stateValue) {
        if (!stateValue) {
            return null;
        }

        const normalized = String(stateValue).trim();
        const allowedStates = new Set(['initial', 'underReview', 'rejected', 'provisional']);
        return allowedStates.has(normalized) ? normalized : null;
    }

    resolveStep(stateValue, stepValue) {
        const parsedStep = Number.parseInt(stepValue, 10);
        if (!Number.isNaN(parsedStep) && parsedStep > 0) {
            return parsedStep;
        }

        if (stateValue === 'underReview' || stateValue === 'rejected') {
            return 2;
        }
        if (stateValue === 'provisional') {
            return 3;
        }
        return 1;
    }

    mapPreferencesFromData(preferences = []) {
        return preferences
            .filter((pref) => pref)
            .map((pref, index) => {
                const type = this.normalizeText(pref.type) || `Preference ${index + 1}`;
                const sharing = this.normalizeSharingValue(pref.sharing, type);
                const ac = this.normalizeAcValue(pref.ac, type);
                const bathroom = this.normalizeText(pref.bathroom);
                const sharingCount = Number.parseInt(sharing, 10);

                return {
                    id: pref.id || `${index + 1}`,
                    type,
                    preference: this.normalizeText(pref.preference) || `Preference ${index + 1}`,
                    floor: this.displayFloorLabel(pref.floor),
                    emails: this.normalizeText(pref.emails) || '',
                    sharing,
                    ac,
                    bathroom: bathroom || null,
                    isSingle: sharing === '1' || /single/i.test(sharing || ''),
                    isTwin: sharing === '2' || /twin|double/i.test(sharing || ''),
                    isTriple: sharing === '3' || (!Number.isNaN(sharingCount) && sharingCount >= 3) || /triple|3/i.test(sharing || ''),
                    isAC: ac === 'AC',
                    isNonAC: ac === 'Non AC',
                    hasBath: !!bathroom
                };
            });
    }

    normalizeText(value) {
        if (value === null || value === undefined) {
            return null;
        }
        const normalized = String(value).trim();
        return normalized ? normalized : null;
    }

    displayFloorLabel(floorValue) {
        const v = this.normalizeText(floorValue);
        if (!v || v.toLowerCase() === 'no preference') {
            return '';
        }
        return v;
    }

    normalizeSharingValue(sharingValue, typeLabel) {
        const sharing = this.normalizeText(sharingValue);
        const derivedCount = this.extractSharingCount(sharing) || this.extractSharingCount(typeLabel);

        if (derivedCount) {
            return derivedCount;
        }

        return sharing || null;
    }

    extractSharingCount(value) {
        const normalized = this.normalizeText(value);
        if (!normalized) {
            return null;
        }

        const directCount = normalized.match(/\b(\d+)\b/);
        if (directCount) {
            return directCount[1];
        }
        if (/single/i.test(normalized)) {
            return '1';
        }
        if (/twin|double/i.test(normalized)) {
            return '2';
        }
        if (/triple/i.test(normalized)) {
            return '3';
        }

        return null;
    }

    normalizeAcValue(acValue, typeLabel) {
        const normalized = this.normalizeText(acValue);
        if (normalized) {
            if (/^yes$/i.test(normalized) || /(^|\s)ac(\s|$)/i.test(normalized)) {
                return 'AC';
            }
            if (/^no$/i.test(normalized) || /non[\s-]*ac/i.test(normalized)) {
                return 'Non AC';
            }
        }

        const type = this.normalizeText(typeLabel);
        if (type) {
            if (/non[\s-]*ac/i.test(type)) {
                return 'Non AC';
            }
            if (/^ac\b|[\s-]ac\b/i.test(type)) {
                return 'AC';
            }
        }

        return normalized || null;
    }

    applyAllotmentData(data) {
        const residenceDetails = data?.residenceDetails || {};
        const roomDetails = data?.roomDetails || {};
        const featureLabels = Array.isArray(data?.features)
            ? data.features.map((label) => this.normalizeText(label)).filter((label) => !!label)
            : [];
        const visibleFeatureLabels = featureLabels.length > 1 ? featureLabels.slice(1) : featureLabels;

        this.allotmentDetails = {
            title: this.normalizeText(residenceDetails.title) || this.normalizeText(roomDetails.roomNumber) || '--',
            subtitle: this.normalizeText(residenceDetails.subtitle) || this.normalizeText(roomDetails.type) || 'Residence',
            building: this.normalizeText(roomDetails.hall) || '--',
            roomNumber: this.normalizeText(roomDetails.roomNumber) || this.normalizeText(residenceDetails.title) || '--',
            floor: this.normalizeText(roomDetails.floor) || this.normalizeText(roomDetails.location) || '--',
            checkInDate: this.normalizeText(residenceDetails.checkInDate) || '--',
            annualFee: this.normalizeText(residenceDetails.annualFee) || '--',
            featureLine: visibleFeatureLabels.join(' | ')
        };

        this.paymentDeadline = this.normalizeText(data?.paymentDeadline);
        this.amenityItems = (Array.isArray(data?.amenityLabels) ? data.amenityLabels : [])
            .map((label) => this.normalizeText(label))
            .filter((label) => !!label)
            .map((label, index) => ({
                id: `${index + 1}`,
                label,
                icon: 'utility:check'
            }));

        this.allotmentRoommates = (Array.isArray(data?.roommates) ? data.roommates : []).map((roommate, index) => ({
            id: roommate?.id || `${index + 1}`,
            name: this.normalizeText(roommate?.name) || 'Student',
            studentId: this.normalizeText(roommate?.studentId) || '--'
        }));
    }

    handleGetStarted() {
        if (this.isGetStartedDisabled) {
            return;
        }
        // Redirection to Residence Selection Page
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Residence_Selection__c'
            }
        });
    }

    handleViewDetailsAndPay() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'HostelDetails__c'
            }
        });
    }

    handleOpenAmenities() {
        this.isAmenitiesModalOpen = true;
    }

    handleCloseAmenities() {
        this.isAmenitiesModalOpen = false;
    }

    // For testing different states, you can add these methods
    // and call them from buttons or browser console
    showUnderReview() {
        this.currentState = 'underReview';
        this.currentStep = 2;
    }

    showRejected() {
        this.currentState = 'rejected';
        this.currentStep = 2;
    }

    showProvisional() {
        this.currentState = 'provisional';
        this.currentStep = 3;
    }

    showInitial() {
        this.currentState = 'initial';
        this.currentStep = 1;
    }

    // Help Modal Logic
    isHelpModalOpen = false;

    handleOpenHelpModal() {
        this.isHelpModalOpen = true;
    }

    handleCloseHelpModal() {
        this.isHelpModalOpen = false;
    }

    handleSubmitHelp() {
        // Logic to submit help request
        this.isHelpModalOpen = false;
        this.uploadedFileName = null;
        
        const toast = this.template.querySelector('c-custom-toast');
        if (toast) {
            toast.showToast(
                'Assistance Request Submitted',
                'Your request is under review. We\'ll notify you once there\'s an update.',
                'success'
            );
        }
    }

    // File Upload Logic
    uploadedFileName = null;

    handleUploadClick() {
        const fileInput = this.template.querySelector('.file-input');
        if (fileInput) {
            fileInput.click();
        }
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            this.uploadedFileName = file.name;
        }
    }
}