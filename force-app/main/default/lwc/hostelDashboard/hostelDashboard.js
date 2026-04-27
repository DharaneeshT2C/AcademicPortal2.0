import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getDashboardData from '@salesforce/apex/HostelDashboardController.getDashboardData';
import getOrganizationDefaults from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';

export default class HostelDashboard extends NavigationMixin(LightningElement) {
    static DEFAULT_PRIMARY = '#3061FF';
    static DEFAULT_SECONDARY = '#EAEFFF';

    hasAllotment = false;
    hasResidenceHistory = false;
    residenceAllocationTitle = 'Residence Allocation';
    canStartResidenceAllocation = null;
    @track windowStartDate = null;
    @track windowEndDate = null;
    organizationDefaults = {};
    pendingPrimary = HostelDashboard.DEFAULT_PRIMARY;
    pendingSecondary = HostelDashboard.DEFAULT_SECONDARY;
    roomDetails = {
        number: 'Room not allotted',
        hall: 'Residence details unavailable',
        type: 'Residence',
        sharing: '',
        amenities: ''
    };

    roommates = [];

    warden = {
        name: 'Not Assigned',
        phone: '--',
        email: '--'
    };

    isLoadingDashboard = false;
    isThemeLoaded = false;

    bills = [
        {
            id: 1,
            label: 'Utility Excess',
            amount: 'Rs 4,000',
            totalUsed: 'Rs 54,000',
            limit: 'Rs 50,000',
            dueDate: 'Due By: 23 Jan 2026',
            isOverdue: true
        },
        {
            id: 2,
            label: 'Electricity Excess',
            amount: 'Rs 4,000',
            totalUsed: 'Rs 54,000',
            limit: 'Rs 50,000',
            dueDate: 'Due By: 23 Jan 2026',
            isOverdue: true
        }
    ];

    notices = [
        {
            id: 1,
            author: 'Hostel Admin',
            tag: 'Announcement',
            title: 'Hostel mess will remain closed on 25-12-2025 for Christmas',
            date: '24-06-2024 | 25 minutes ago',
            type: 'admin',
            isHighPriority: true
        },
        {
            id: 2,
            author: 'Hostel Talent Show',
            tag: 'Announcement',
            title: 'Join us this saturday for a fantastic round of talent show exclusively by our freshers',
            extraInfo: 'Indoor Auditorium, EVR residence',
            date: '24-06-2024 | 25 minutes ago',
            type: 'event',
            isHighPriority: false
        }
    ];

    activeTab = 'in-out';

    inOutRecords = [
        { id: 1, date: '16 Oct 2026', day: 'Wednesday', time: '01:12 PM', status: 'Present', statusClass: 'badge present' },
        { id: 2, date: '17 Oct 2026', day: 'Thursday', time: '09:30 PM', status: 'Present', statusClass: 'badge present' },
        { id: 3, date: '18 Oct 2026', day: 'Friday', time: '08:47 PM', status: 'Absent', statusClass: 'badge absent' }
    ];

    leaveRequests = [
        {
            id: 1,
            requestId: '#20240101',
            title: '24th sports day practice',
            type: 'Exception',
            description: 'I attended the Mathematics class on 12th August, but my attendance is showing as Absent in the portal. I was present for the full session and even resp...',
            dates: '26 Dec 2026 - 30 Dec 2026 (5 days)',
            submittedOn: '09 Oct 2026',
            status: 'In Review',
            statusClass: 'status-tag in-review',
            isClosed: false
        },
        {
            id: 2,
            requestId: '#20240101',
            title: 'Family Function Leave',
            type: 'Personal leave',
            submittedOn: '',
            closedOn: '23-12-23',
            status: 'Closed',
            statusClass: 'status-tag closed',
            isClosed: true
        }
    ];

    isModalOpen = false;
    uploadedFileName = '';

    connectedCallback() {
        this.loadOrganizationDefaults();
        this.loadDashboardData();
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

    applyTheme(primary, secondary) {
        const resolvedPrimary = primary || HostelDashboard.DEFAULT_PRIMARY;
        const resolvedSecondary = secondary || HostelDashboard.DEFAULT_SECONDARY;
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

    get dashboardContainerClass() {
        return this.isThemeLoaded ? 'dashboard-container' : 'dashboard-container hidden';
    }

    get isInOutTab() {
        return this.activeTab === 'in-out';
    }

    get isLeaveRequestsTab() {
        return this.activeTab === 'leave-requests';
    }

    get inOutTabClass() {
        return this.activeTab === 'in-out' ? 'tab active' : 'tab';
    }

    get leaveRequestsTabClass() {
        return this.activeTab === 'leave-requests' ? 'tab active' : 'tab';
    }

    get roomFeaturesText() {
        const parts = [this.roomDetails.sharing, this.roomDetails.amenities].filter((value) => value);
        return parts.join(' | ');
    }

    get isViewDetailsDisabled() {
        return this.hasAllotment !== true && this.hasResidenceHistory !== true;
    }

    get isGetStartedDisabled() {
        const startDate = this.parseDate(this.windowStartDate);
        const endDate = this.parseDate(this.windowEndDate);
        if (startDate && endDate) {
            const today = new Date();
            today.setHours(0, 0, 0, 0);

            startDate.setHours(0, 0, 0, 0);
            endDate.setHours(23, 59, 59, 999);

            return !(today >= startDate && today <= endDate);
        }

        if (typeof this.canStartResidenceAllocation === 'boolean') {
            return !this.canStartResidenceAllocation;
        }

        return true;
    }

    parseDate(dateString) {
        if (!dateString) return null;

        if (/^\d{4}-\d{2}-\d{2}$/.test(dateString)) {
            const [year, month, day] = dateString.split('-').map((value) => parseInt(value, 10));
            return new Date(year, month - 1, day);
        }

        const slashParts = dateString.split('/');
        if (slashParts.length === 3) {
            const first = parseInt(slashParts[0], 10);
            const second = parseInt(slashParts[1], 10);
            const year = parseInt(slashParts[2], 10);

            if (!Number.isNaN(first) && !Number.isNaN(second) && !Number.isNaN(year)) {
                if (first > 12) {
                    return new Date(year, second - 1, first);
                }
                return new Date(year, first - 1, second);
            }
        }

        const parsedDate = new Date(dateString);
        return Number.isNaN(parsedDate.getTime()) ? null : parsedDate;
    }

    async loadDashboardData() {
        this.isLoadingDashboard = true;
        try {
            const data = await getDashboardData();
            this.applyDashboardData(data);
        } catch (error) {
            console.error('Error loading hostel dashboard data', error);
        } finally {
            this.isLoadingDashboard = false;
        }
    }

    applyDashboardData(data) {
        this.hasAllotment = data?.hasAllotment === true;
        this.hasResidenceHistory = data?.hasResidenceHistory === true;
        this.residenceAllocationTitle = data?.residenceAllocationTitle || 'Residence Allocation';
        this.canStartResidenceAllocation =
            typeof data?.canStartResidenceAllocation === 'boolean'
                ? data.canStartResidenceAllocation
                : null;
        this.windowStartDate = data?.windowStartDate || null;
        this.windowEndDate = data?.windowEndDate || null;

        if (!this.hasAllotment || !data?.roomDetails) {
            return;
        }

        const roomDetails = data.roomDetails;
        const roomNumber = this.getFirstNonEmpty([roomDetails.roomNumber, roomDetails.number]);
        const hallName = this.getFirstNonEmpty([roomDetails.hall, roomDetails.location]);

        this.roomDetails = {
            number: roomNumber ? `Room no. ${roomNumber}` : 'Room not allotted',
            hall: hallName || 'Residence details unavailable',
            type: roomDetails.type || 'Residence',
            sharing: roomDetails.sharing || '',
            amenities: roomDetails.amenities || ''
        };

        this.roommates = (data.roommates || []).map((roommate, index) => {
            const initials = this.getInitials(roommate.name);
            return {
                id: roommate.id || `${index}`,
                name: roommate.name || 'Student',
                studentId: roommate.studentId || '',
                initials,
                avatar: this.getAvatarDataUri(initials)
            };
        });

        this.warden = {
            name: data.warden?.name || 'Not Assigned',
            phone: data.warden?.phone || '--',
            email: data.warden?.email || '--'
        };
    }

    getFirstNonEmpty(values = []) {
        return values.find((value) => value && String(value).trim()) || null;
    }

    getInitials(name = '') {
        const parts = name.trim().split(/\s+/).filter(Boolean);
        if (parts.length === 0) {
            return 'NA';
        }
        if (parts.length === 1) {
            return parts[0].substring(0, 2).toUpperCase();
        }
        return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase();
    }

    getAvatarDataUri(initials) {
        const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 150 150"><rect width="150" height="150" fill="#E5E7EB"/><text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" font-family="sans-serif" font-size="60" fill="#9CA3AF">${initials}</text></svg>`;
        return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
    }

    renderedCallback() {
        document.documentElement.style.setProperty('--dxp-c-section-image-overlay-color', '#f6f8fb');

        if (this.pendingPrimary || this.pendingSecondary) {
            this.applyTheme(this.pendingPrimary, this.pendingSecondary);
        }
    }

    handleTabChange(event) {
        this.activeTab = event.target.dataset.tab;
    }

    handleFileUpload(event) {
        const file = event.target.files[0];
        this.uploadedFileName = file ? file.name : '';
    }

    handleOpenModal() {
        this.isModalOpen = true;
    }

    handleCloseModal() {
        this.template.querySelector('c-custom-toast').showToast(
            'Leave Applied Successfully',
            'Your leave request has been submitted for approval.',
            'success'
        );

        this.isModalOpen = false;
        this.uploadedFileName = '';
    }

    handleCancelModal() {
        this.isModalOpen = false;
        this.uploadedFileName = '';
    }

    handleGetStarted() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'ResidenceAllocation__c'
            }
        });
    }

    handleViewDetails() {
        if (this.isViewDetailsDisabled) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'HostelDetails__c'
            }
        });
    }
}