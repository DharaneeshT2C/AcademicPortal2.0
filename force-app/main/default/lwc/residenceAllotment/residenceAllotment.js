import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getOrganizationDefaults from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';

export default class ResidenceAllotment extends NavigationMixin(LightningElement) {
    static DEFAULT_PRIMARY = '#3061FF';
    static DEFAULT_SECONDARY = '#EAEFFF';

    organizationDefaults = {};
    pendingPrimary = ResidenceAllotment.DEFAULT_PRIMARY;
    pendingSecondary = ResidenceAllotment.DEFAULT_SECONDARY;
    // Room Details
    roomDetails = {
        type: 'Type A Residence',
        sharing: 'Triple-sharing',
        ac: 'AC',
        bathroom: 'Attached bathroom',
        building: 'Residence Hall B',
        roomNumber: 'B-305',
        floor: '3rd Floor',
        checkInDate: '15 June 2026',
        annualFee: '₹1,80,000'
    };

    // Roommate Details
    roommates = [
        {
            id: 1,
            name: 'Rohit Sharma',
            studentId: 'KJS8293',
            avatar: 'data:image/svg+xml;charset=utf-8,%3Csvg xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22 viewBox%3D%220 0 150 150%22%3E%3Crect width%3D%22150%22 height%3D%22150%22 fill%3D%22%23E5E7EB%22/%3E%3Ctext x%3D%2250%25%22 y%3D%2250%25%22 dominant-baseline%3D%22middle%22 text-anchor%3D%22middle%22 font-family%3D%22sans-serif%22 font-size%3D%2260%22 fill%3D%22%239CA3AF%22%3ERS%3C/text%3E%3C/svg%3E'
        },
        {
            id: 2,
            name: 'Ankit Sharma',
            studentId: 'KJS8293',
            avatar: 'data:image/svg+xml;charset=utf-8,%3Csvg xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22 viewBox%3D%220 0 150 150%22%3E%3Crect width%3D%22150%22 height%3D%22150%22 fill%3D%22%23E5E7EB%22/%3E%3Ctext x%3D%2250%25%22 y%3D%2250%25%22 dominant-baseline%3D%22middle%22 text-anchor%3D%22middle%22 font-family%3D%22sans-serif%22 font-size%3D%2260%22 fill%3D%22%239CA3AF%22%3EAS%3C/text%3E%3C/svg%3E'
        }
    ];

    // Payment Details
    paymentDetails = {
        annualFee: '₹60,000',
        securityDeposit: '₹5,000',
        processingFee: '₹500',
        totalDue: '₹65,500',
        deadline: '30 May 2025'
    };

    // Important Information
    importantInfo = [
        'Residence allotment is valid for the academic year 2025-26',
        'Security deposit will be refunded after check-out, subject to room inspection',
        'Failure to complete payment by the deadline will result in cancellation of allotment',
        'Room changes are not permitted after check-in, except in special circumstances'
    ];

    // Image Modal State
    showModal = false;
    currentImageIndex = 0;
    isThemeLoaded = false;

    // Mock Images (Gradients)
    roomImages = [
        { id: 1, src: 'linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%)', active: true },
        { id: 2, src: 'linear-gradient(135deg, #a1c4fd 0%, #c2e9fb 100%)', active: false },
        { id: 3, src: 'linear-gradient(135deg, #d4fc79 0%, #96e6a1 100%)', active: false },
        { id: 4, src: 'linear-gradient(135deg, #ff9a9e 0%, #fecfef 99%, #fecfef 100%)', active: false }
    ];

    get currentImageStyle() {
        return `background: ${this.roomImages[this.currentImageIndex].src}; width: 100%; height: 100%;`;
    }

    // Update active class for thumbnails
    updateImageStates() {
        this.roomImages = this.roomImages.map((img, index) => ({
            ...img,
            active: index === this.currentImageIndex,
            class: index === this.currentImageIndex ? 'thumbnail active' : 'thumbnail',
            style: `background: ${img.src}; width: 100%; height: 100%;`
        }));
    }

    connectedCallback() {
        this.loadOrganizationDefaults();
        this.updateImageStates();
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

    get pageContainerClass() {
        return this.isThemeLoaded ? 'page-container' : 'page-container hidden';
    }

    applyTheme(primary, secondary) {
        const resolvedPrimary = primary || ResidenceAllotment.DEFAULT_PRIMARY;
        const resolvedSecondary = secondary || ResidenceAllotment.DEFAULT_SECONDARY;
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

    handleViewImages() {
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
    }

    prevImage() {
        if (this.currentImageIndex > 0) {
            this.currentImageIndex--;
        } else {
            this.currentImageIndex = this.roomImages.length - 1;
        }
        this.updateImageStates();
    }

    nextImage() {
        if (this.currentImageIndex < this.roomImages.length - 1) {
            this.currentImageIndex++;
        } else {
            this.currentImageIndex = 0;
        }
        this.updateImageStates();
    }

    handleThumbnailClick(event) {
        this.currentImageIndex = parseInt(event.currentTarget.dataset.index, 10);
        this.updateImageStates();
    }

    handleDownloadLetter() {
        // Download allotment letter logic
        console.log('Downloading letter...');
    }

    handleProceedPayment() {
        // Navigate to payment page
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Payment__c'
            }
        });
    }
}