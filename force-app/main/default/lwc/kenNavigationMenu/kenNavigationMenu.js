import { LightningElement, api, wire, track } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import KenLogo from '@salesforce/resourceUrl/KenLogo';

import getUserContactDetails from '@salesforce/apex/KenNavigationMenuController.getUserContactDetails';
import getNavigationMenuItems from '@salesforce/apex/KenHeaderController.getNavigationMenuItems';

// import HomeIcon from '@salesforce/resourceUrl/HomeIcon';
// import MyFeedIcon from '@salesforce/resourceUrl/MyFeedIcon';
// import EventIcon from '@salesforce/resourceUrl/EventIcon';
// import JobIcon from '@salesforce/resourceUrl/JobIcon';
// import MentorshipIcon from '@salesforce/resourceUrl/MentorshipIcon';
// import FundraiseIcon from '@salesforce/resourceUrl/FundraiseIcon';
// import NetworkIcon from '@salesforce/resourceUrl/NetworkIcon';
// import GroupIcon from '@salesforce/resourceUrl/GroupIcon';
// import BusinessDirectoryIcon from '@salesforce/resourceUrl/BusinessDirectoryIcon';
// import InfoHubIcon from '@salesforce/resourceUrl/InfoHubIcon';
// import SurveyIcon from '@salesforce/resourceUrl/SurveyIcon';
// import ServiceSupportIcon from '@salesforce/resourceUrl/ServiceSupportIcon';
// import LogoutIcon from '@salesforce/resourceUrl/LogoutIcon';
// import SideLogo from '@salesforce/resourceUrl/sidelogo';
// import getPrimaryColor from '@salesforce/apex/KenPortalConfigController.getPortalConfigs';

const ICON_BY_LABEL = {
    'Home': 'utility:home',
    'Attendance': 'utility:date_input',
    'Academics': 'utility:education',
    'Mentors': 'utility:user',
    'Fee Payment': 'utility:moneybag',
    'Exams': 'utility:description',
    'Placements': 'utility:case',
    'Campus Life': 'data:image/svg+xml;charset=utf-8,%3Csvg width%3D%2224%22 height%3D%2224%22 viewBox%3D%220 0 24 24%22 fill%3D%22none%22 xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Cg clip-path%3D%22url(%23clip0_17200_150942)%22%3E%3Cpath d%3D%22M3.52344 3.20709L11.9369 0.703125L20.4717 3.20709L11.9369 5.51677L3.52344 3.20709Z%22 stroke%3D%22%233061FF%22 stroke-width%3D%221.5%22 stroke-miterlimit%3D%2210%22 stroke-linecap%3D%22round%22 stroke-linejoin%3D%22round%22%2F%3E%3Cpath d%3D%22M17.348 4.05469V8.82042H14.4498C13.068 8.82042 11.948 9.94106 11.948 11.3235C11.948 9.94106 10.8278 8.82042 9.44614 8.82042H6.52344V4.05469%22 stroke%3D%22%233061FF%22 stroke-width%3D%221.5%22 stroke-miterlimit%3D%2210%22 stroke-linecap%3D%22round%22 stroke-linejoin%3D%22round%22%2F%3E%3Cpath d%3D%22M16.1793 21.1086C16.8953 21.1086 17.4758 20.5281 17.4758 19.8121C17.4758 19.0961 16.8953 18.5156 16.1793 18.5156C15.4633 18.5156 14.8828 19.0961 14.8828 19.8121C14.8828 20.5281 15.4633 21.1086 16.1793 21.1086Z%22 stroke%3D%22%233061FF%22 stroke-width%3D%221.5%22 stroke-miterlimit%3D%2210%22 stroke-linecap%3D%22round%22 stroke-linejoin%3D%22round%22%2F%3E%3Cpath d%3D%22M21.9996 23.3039C22.7156 23.3039 23.2961 22.7234 23.2961 22.0074C23.2961 21.2914 22.7156 20.7109 21.9996 20.7109C21.2836 20.7109 20.7031 21.2914 20.7031 22.0074C20.7031 22.7234 21.2836 23.3039 21.9996 23.3039Z%22 stroke%3D%22%233061FF%22 stroke-width%3D%221.5%22 stroke-miterlimit%3D%2210%22 stroke-linecap%3D%22round%22 stroke-linejoin%3D%22round%22%2F%3E%3Cpath d%3D%22M17.4766 19.8149V13.3594L23.2984 14.9435V22.0036%22 stroke%3D%22%233061FF%22 stroke-width%3D%221.5%22 stroke-miterlimit%3D%2210%22 stroke-linecap%3D%22round%22 stroke-linejoin%3D%22round%22%2F%3E%3Cpath d%3D%22M0.703125 16.8188C0.703125 15.3008 1.93069 14.0703 3.44498 14.0703C4.61025 14.0703 5.60555 14.799 6.00258 15.8265C6.39956 14.799 7.39491 14.0703 8.56017 14.0703C10.2371 14.0675 11.3258 15.3753 11.2947 17.0264C11.2209 20.9468 6.00075 23.2933 6.00075 23.2933C5.95298 23.2861 0.703125 21.0415 0.703125 16.8188Z%22 stroke%3D%22%233061FF%22 stroke-width%3D%221.5%22 stroke-miterlimit%3D%2210%22 stroke-linecap%3D%22round%22 stroke-linejoin%3D%22round%22%2F%3E%3C%2Fg%3E%3Cdefs%3E%3CclipPath id%3D%22clip0_17200_150942%22%3E%3Crect width%3D%2224%22 height%3D%2224%22 fill%3D%22white%22%2F%3E%3C%2FclipPath%3E%3C%2Fdefs%3E%3C%2Fsvg%3E',
    'Service & Support': 'utility:chat',
    'Feedback': 'utility:question_post',
    'Mess': 'utility:list',
    'Logout': 'utility:logout'
};

const HARDCODED_PROFILE = {
    profilePhotoUrl: 'https://img.freepik.com/free-photo/portrait-white-man-isolated_53876-40306.jpg',
    studentName: 'Joshuva B',
    graduationYear: 'URK17MT026'
};

const CAMPUS_LIFE_ROUTE_SEGMENTS = new Set([
    'campuslife',
    'residenceallocation',
    'residenceselection',
    'hosteldetails'
]);

const ROOT_ROUTE_SEGMENTS = new Set([
    'home',
    'campuslife',
    'mess-dashboard',
    'feed',
    'events',
    'jobs',
    'mentorship',
    ...CAMPUS_LIFE_ROUTE_SEGMENTS
]);

function resolveCommunityBasePath(pathname) {
    const safePathname =
        typeof pathname === 'string' && pathname.trim()
            ? pathname
            : typeof window !== 'undefined' && window.location
                ? window.location.pathname || '/'
                : '/';
    const segments = safePathname.split('/').filter(Boolean);
    if (!segments.length) {
        return '/';
    }

    const routingIndex = segments.findIndex((segment) => segment.toLowerCase() === 's');
    if (routingIndex === 0) {
        return '/';
    }
    if (routingIndex > 0) {
        return `/${segments[routingIndex - 1]}`;
    }

    const [firstSegment] = segments;
    if (segments.length === 1 && ROOT_ROUTE_SEGMENTS.has(firstSegment.toLowerCase())) {
        return '/';
    }

    return `/${firstSegment}`;
}

const FALLBACK_PROFILE_IMAGE =
    'data:image/svg+xml;charset=utf-8,%3Csvg xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22 width%3D%22160%22 height%3D%22160%22 viewBox%3D%220 0 160 160%22%3E%3Ccircle cx%3D%2280%22 cy%3D%2280%22 r%3D%2278%22 fill%3D%22%23E5E7EB%22 stroke%3D%22%233B82F6%22 stroke-width%3D%224%22%2F%3E%3Cpath d%3D%22M80 84c18 0 32-14 32-32S98 20 80 20 48 34 48 52s14 32 32 32zm0 12c-21.5 0-40 10.8-40 24v10h80v-10c0-13.2-18.5-24-40-24z%22 fill%3D%22%239CA3AF%22%2F%3E%3C%2Fsvg%3E';

export default class KenNavigationMenu extends NavigationMixin(LightningElement) {

    @api linkSetMasterLabel = 'Default Navigation';
    @api addHomeMenuItem = false;
    @api includeImageUrls = false;

    @track menuItems = [];
    @track selectedItemId = null;

    profilePhotoUrl = HARDCODED_PROFILE.profilePhotoUrl;
    studentName = HARDCODED_PROFILE.studentName;
    graduationYear = HARDCODED_PROFILE.graduationYear;
    sideLogoUrl = KenLogo;

    publishStatus;
    isLoaded = false;

    @wire(CurrentPageReference)
    setCurrentPageReference(ref) {
        const app = ref?.state?.app;
        this.publishStatus = app === 'commeditor' ? 'Draft' : 'Live';
        Promise.resolve().then(() => this.updateSelectedItem());
    }

    @wire(getNavigationMenuItems, {
        navigationLinkSetMasterLabel: '$linkSetMasterLabel',
        publishStatus: '$publishStatus',
        addHomeMenuItem: '$addHomeMenuItem',
        includeImageUrl: false
    })
    wiredMenuItems() {
        // Hardcoded data for demonstration
        const hardcodedData = [
            { label: 'Campus Life', actionValue: '/campuslife', actionType: 'InternalLink', subMenu: [] },
            { label: 'Mess', actionValue: '/mess-dashboard', actionType: 'InternalLink', subMenu: [] }
        ];

        this.menuItems = hardcodedData.map((item, index) => {
            const basePath = this.getCommunityBasePath();
            const rawTarget = item.actionValue || '';
            const normalizedTarget = this.normalizePath(rawTarget || (item.label === 'Home' ? basePath : ''), basePath);

            const subMenu = (item.subMenu || []).map((sub, subIndex) => {
                const rawSub = sub.actionValue || '';
                const normalizedSub = this.normalizePath(rawSub, basePath);

                return {
                    ...sub,
                    id: `${index}-${subIndex}`,
                    normalizedActionValue: normalizedSub,
                    iconName: ICON_BY_LABEL[sub.label] || null
                };
            });

            return {
                id: index,
                label: item.label,
                type: item.actionType,
                target: rawTarget || basePath,
                normalizedTarget,
                subMenu,
                iconName: ICON_BY_LABEL[item.label] || null
            };
        });

        this.isLoaded = true;
        this.updateSelectedItem();
    }

    @wire(getUserContactDetails)
    wiredUserDetails({ error, data }) {
        this.profilePhotoUrl = HARDCODED_PROFILE.profilePhotoUrl;
        this.graduationYear = HARDCODED_PROFILE.graduationYear;
        this.studentName = HARDCODED_PROFILE.studentName;

        if (error) {
            console.error('NavigationMenu: user details fetch ignored in hardcoded mode', error);
        }
        if (data) {
            this.studentName = data.studentName || HARDCODED_PROFILE.studentName;
        }
    }

    connectedCallback() {
        this.updateSelectedItem();
        window.addEventListener('popstate', () => {
            this.updateSelectedItem();
        });
    }

    handleItemSelect(event) {
        this.selectedItemId = event.detail.selectedItemId;

        this.menuItems = this.menuItems.map(item => ({
            ...item,
            subMenu: item.subMenu.map(sub => ({ ...sub, isSelected: false }))
        }));
    }

    handleSubMenuSelect(event) {
        const { parentItemId, selectedItemId } = event.detail;
        this.selectedItemId = parentItemId;

        this.menuItems = this.menuItems.map(item => ({
            ...item,
            subMenu: item.subMenu.map(sub => ({
                ...sub,
                isSelected: item.id === parentItemId && sub.id === selectedItemId
            }))
        }));
    }

    updateSelectedItem() {

        if (!this.menuItems?.length) return;

        const basePath = this.getCommunityBasePath();
        const currentPath = this.normalizePath(window.location.pathname, basePath);
        const currentRouteSegment =
            currentPath
                .replace(basePath, '')
                .replace(/^\/+/, '')
                .split('/')
                .filter(Boolean)[0]
                ?.toLowerCase() || '';
        let bestMatch = { id: null, score: -1 };

        const considerMatch = (id, target) => {
            if (!target) return;
            if (target === currentPath) {
                const score = target.length + 1000;
                if (score > bestMatch.score) bestMatch = { id, score };
            } else if (currentPath.startsWith(target + '/')) {
                const score = target.length;
                if (score > bestMatch.score) bestMatch = { id, score };
            }
        };

        this.menuItems.forEach(item => {
            considerMatch(item.id, item.normalizedTarget);
            item.subMenu.forEach(sub => considerMatch(item.id, sub.normalizedActionValue));
        });

        if (bestMatch.id === null && CAMPUS_LIFE_ROUTE_SEGMENTS.has(currentRouteSegment)) {
            const campusLifeItem = this.menuItems.find(item => item.label === 'Campus Life');
            if (campusLifeItem) {
                bestMatch = { id: campusLifeItem.id, score: 0 };
            }
        }

        this.selectedItemId = bestMatch.id;
    }

    normalizePath(path, basePath = '/') {
        if (!path) return '';

        if (/^https?:\/\//i.test(path)) {
            return '';
        }

        let normalized = path.trim();
        if (!normalized.startsWith('/')) {
            normalized = '/' + normalized;
        }

        normalized = normalized.replace(/\/+$/, '');
        if (normalized === '') normalized = '/';

        if (basePath !== '/' && normalized !== basePath && !normalized.startsWith(basePath + '/')) {
            const baseParts = basePath.split('/').filter(Boolean);
            const communityRoot = baseParts.length > 0 ? `/${baseParts[0]}` : '/';

            if (normalized === communityRoot || normalized.startsWith(communityRoot + '/')) {
                normalized = normalized.replace(communityRoot, basePath);
            } else {
                normalized = `${basePath}${normalized}`;
            }
        }

        normalized = normalized.replace(/\/+$/, '');
        if (normalized === '') normalized = basePath !== '/' ? basePath : '/';

        return normalized;
    }

    getCommunityBasePath() {
        return resolveCommunityBasePath();
    }

    get menuItemsToDisplay() {
        return this.menuItems.map(item => ({
            ...item,
            isSelected: item.id === this.selectedItemId
        }));
    }

    get regularMenuItems() {
        return this.menuItemsToDisplay.filter(item => item.label !== 'Logout');
    }

    get logoutMenuItems() {
        return this.menuItemsToDisplay.filter(item => item.label === 'Logout');
    }

    handleImageError(event) {
        event.target.src = FALLBACK_PROFILE_IMAGE;
    }

    navigateToHomePage() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'Home' }
        });
    }
}