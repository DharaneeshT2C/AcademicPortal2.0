import { LightningElement, wire } from 'lwc';
import communityBasePath from '@salesforce/community/basePath';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';
import getCurrentUserProfile from '@salesforce/apex/SideNavigationController.getCurrentUserProfile';

const EDUCATION_ITEMS = [
    {
        id: 'e1',
        title: 'B Tech, Electronics and Media Technology',
        institute: 'Sikkim Manipal University',
        timeline: '2010 - 2012 | 7.5 GPA',
        showActions: true
    },
    {
        id: 'e2',
        title: 'Higher Secondary School',
        institute: 'GRG Matric Hr Sec School',
        timeline: '2008 - 2010 | 80%',
        showActions: false
    },
    {
        id: 'e3',
        title: 'Secondary School (SSLC)',
        institute: 'GRG Matric Hr Sec School',
        timeline: '2006 - 2008 | 80%',
        showActions: false
    }
];

const THEORY_ROWS = [
    {
        id: 't1',
        code: 'C2026/23S2',
        course: 'Basics of business communication',
        credit: '2',
        grade: 'A+',
        t1: '69',
        t2: '23',
        total: '92',
        t1Class: '',
        t2Class: 'is-risk',
        totalClass: ''
    },
    {
        id: 't2',
        code: 'C2026/23S2',
        course: 'Operating systems',
        credit: '2',
        grade: 'A+',
        t1: '32',
        t2: '55',
        total: '87',
        t1Class: 'is-risk',
        t2Class: '',
        totalClass: ''
    },
    {
        id: 't3',
        code: 'C2026/23S2',
        course: 'Basics of civil engineering',
        credit: '2',
        grade: 'A+',
        t1: '32',
        t2: '55',
        total: '87',
        t1Class: 'is-risk',
        t2Class: '',
        totalClass: ''
    }
];

const PRACTICAL_ROWS = [
    {
        id: 'p1',
        code: 'C2026/23S2',
        course: 'Artificial Intelligence',
        credit: '2',
        grade: 'A+',
        t1: '24',
        t2: '39',
        total: '63',
        t1Class: '',
        t2Class: 'is-risk',
        totalClass: ''
    },
    {
        id: 'p2',
        code: 'C2026/23S2',
        course: 'Database Management Systems',
        credit: '2',
        grade: 'A+',
        t1: '12',
        t2: '8',
        total: '20',
        t1Class: 'is-risk',
        t2Class: '',
        totalClass: 'is-risk'
    }
];

const SEMESTER_ITEMS = [
    { id: 's1', badge: 'I', label: 'Semester I', cardClass: 'semester-card is-active' },
    { id: 's2', badge: 'I', label: 'Semester I (Back-Log)', cardClass: 'semester-card' },
    { id: 's3', badge: 'II', label: 'Semester II (Current)', cardClass: 'semester-card' },
    { id: 's4', badge: 'III', label: 'Semester III (Upcoming)', cardClass: 'semester-card is-upcoming' },
    { id: 's5', badge: 'IV', label: 'Semester IV (Upcoming)', cardClass: 'semester-card is-upcoming' }
];

const CLUB_ITEMS = [
    { id: 'c1', name: 'Blood Donation Club', role: 'Member', imageClass: 'club-image img-blood' },
    { id: 'c2', name: 'Cultural Club', role: 'Owner', imageClass: 'club-image img-cultural' },
    { id: 'c3', name: 'Entrepreneurship Club', role: 'Member', imageClass: 'club-image img-entrepreneur' },
    { id: 'c4', name: 'Short Film Enthusiasts', role: 'Member', imageClass: 'club-image img-film' }
];

const EXTRA_CURRICULAR_ITEMS = [
    {
        id: 'x1',
        category: 'Clubs',
        title: 'Entrepreneurship Club',
        meta: 'Member | XYZ University | Jan 2022 - Feb 2024',
        showActions: false
    },
    {
        id: 'x2',
        category: 'Sports',
        title: 'Basketball',
        meta: 'Captain | XYZ University | Jan 2026',
        showActions: false
    },
    {
        id: 'x3',
        category: 'Publication',
        title: 'AI-Based Traffic Prediction Model',
        meta: 'IEEE | Jan 2024',
        showActions: true
    }
];

const MONTH_OPTIONS = [
    { label: 'Month', value: '' },
    { label: 'January', value: 'jan' },
    { label: 'February', value: 'feb' },
    { label: 'March', value: 'mar' },
    { label: 'April', value: 'apr' },
    { label: 'May', value: 'may' },
    { label: 'June', value: 'jun' },
    { label: 'July', value: 'jul' },
    { label: 'August', value: 'aug' },
    { label: 'September', value: 'sep' },
    { label: 'October', value: 'oct' },
    { label: 'November', value: 'nov' },
    { label: 'December', value: 'dec' }
];

const YEAR_OPTIONS = [
    { label: 'Year', value: '' },
    { label: '2026', value: '2026' },
    { label: '2025', value: '2025' },
    { label: '2024', value: '2024' },
    { label: '2023', value: '2023' },
    { label: '2022', value: '2022' },
    { label: '2021', value: '2021' },
    { label: '2020', value: '2020' },
    { label: '2019', value: '2019' },
    { label: '2018', value: '2018' }
];

const EXTRA_TYPE_OPTIONS = [
    { label: 'Clubs & Leadership', value: 'clubs_leadership' },
    { label: 'Sports', value: 'sports' },
    { label: 'Cultural/Arts', value: 'cultural_arts' },
    { label: 'Social Work', value: 'social_work' },
    { label: 'Certifications', value: 'certifications' },
    { label: 'Competitions / Hackathons', value: 'competitions_hackathons' },
    { label: 'Internships / Work Experience', value: 'internships_work_experience' },
    { label: 'Conferences / Seminars', value: 'conferences_seminars' },
    { label: 'Consulting Projects', value: 'consulting_projects' },
    { label: 'Research Projects', value: 'research_projects' },
    { label: 'Publications', value: 'publications' },
    { label: 'Patents', value: 'patents' }
];

const SPORTS_LEVEL_OPTIONS = [
    { label: 'Select', value: '' },
    { label: 'School', value: 'school' },
    { label: 'District', value: 'district' },
    { label: 'State', value: 'state' },
    { label: 'National', value: 'national' },
    { label: 'International', value: 'international' }
];

const SPORTS_ACHIEVEMENT_OPTIONS = [
    { label: 'Select', value: '' },
    { label: 'Participation', value: 'participation' },
    { label: 'Winner', value: 'winner' },
    { label: 'Runner Up', value: 'runner_up' },
    { label: 'Gold Medal', value: 'gold_medal' },
    { label: 'Silver Medal', value: 'silver_medal' },
    { label: 'Bronze Medal', value: 'bronze_medal' }
];

const CULTURAL_ACTIVITY_OPTIONS = [
    { label: 'Select', value: '' },
    { label: 'Dance', value: 'dance' },
    { label: 'Music', value: 'music' },
    { label: 'Drama', value: 'drama' },
    { label: 'Fine Arts', value: 'fine_arts' },
    { label: 'Literary', value: 'literary' }
];

const CULTURAL_LEVEL_OPTIONS = [
    { label: 'Select', value: '' },
    { label: 'College', value: 'college' },
    { label: 'Inter-College', value: 'inter_college' },
    { label: 'State', value: 'state' },
    { label: 'National', value: 'national' },
    { label: 'International', value: 'international' }
];

const HACKATHON_RESULT_OPTIONS = [
    { label: 'Select', value: '' },
    { label: 'Participation', value: 'participation' },
    { label: 'Winner', value: 'winner' },
    { label: 'Runner Up', value: 'runner_up' },
    { label: 'Finalist', value: 'finalist' }
];

const INTERNSHIP_LOCATION_OPTIONS = [
    { label: 'Select', value: '' },
    { label: 'Onsite', value: 'onsite' },
    { label: 'Remote', value: 'remote' },
    { label: 'Hybrid', value: 'hybrid' }
];

const CONDUCT_ITEMS = [
    {
        id: 'cond1',
        reference: '#COND2026120',
        title: 'Disciplinary enquiry under review',
        type: 'Inquiry',
        description:
            'A complaint regarding inappropriate behaviour in the campus common area has been filed. The matter is currently under review.',
        dueDate: '20/08/25',
        status: 'Closed',
        statusClass: 'conduct-status is-closed'
    },
    {
        id: 'cond2',
        reference: '#COND2026041',
        title: 'Suspension issued for academic misconduct',
        type: 'Disciplinary Action',
        description:
            'Unauthorised materials were found during the mid-semester examination. The case was reviewed by the academic integrity panel and a suspension notice was issued.',
        dueDate: '20/08/25',
        status: 'In Review',
        statusClass: 'conduct-status is-review'
    },
    {
        id: 'cond3',
        reference: '#20240101',
        title: 'Fine issued for lab equipment damage',
        type: 'Penalty',
        description: '',
        dueDate: '20/08/25',
        status: 'In Review',
        statusClass: 'conduct-status is-review'
    }
];

export default class MyStudentDetails extends LightningElement {
    organizationDefaults = {};
    studentPhotoUrl = '';
    userRole = '';
    activeTab = 'academics';
    isExtraCurricularModalOpen = false;
    isExtraCurricularSuccessOpen = false;
    isDownloadSuccessOpen = false;
    isIdCardModalOpen = false;
    selectedExtraType = 'clubs_leadership';

    get educationItems() {
        return EDUCATION_ITEMS;
    }

    get theoryRows() {
        return THEORY_ROWS;
    }

    get practicalRows() {
        return PRACTICAL_ROWS;
    }

    get semesters() {
        return SEMESTER_ITEMS;
    }

    get clubs() {
        return CLUB_ITEMS;
    }

    get extraCurricularItems() {
        return EXTRA_CURRICULAR_ITEMS;
    }

    get monthOptions() {
        return MONTH_OPTIONS;
    }

    get yearOptions() {
        return YEAR_OPTIONS;
    }

    get extraTypeOptions() {
        return EXTRA_TYPE_OPTIONS;
    }

    get sportsLevelOptions() {
        return SPORTS_LEVEL_OPTIONS;
    }

    get sportsAchievementOptions() {
        return SPORTS_ACHIEVEMENT_OPTIONS;
    }

    get culturalActivityOptions() {
        return CULTURAL_ACTIVITY_OPTIONS;
    }

    get culturalLevelOptions() {
        return CULTURAL_LEVEL_OPTIONS;
    }

    get hackathonResultOptions() {
        return HACKATHON_RESULT_OPTIONS;
    }

    get internshipLocationOptions() {
        return INTERNSHIP_LOCATION_OPTIONS;
    }

    get isSportsTypeSelected() {
        return this.selectedExtraType === 'sports';
    }

    get isCulturalArtsTypeSelected() {
        return this.selectedExtraType === 'cultural_arts';
    }

    get isSocialWorkTypeSelected() {
        return this.selectedExtraType === 'social_work';
    }

    get isCertificationTypeSelected() {
        return this.selectedExtraType === 'certifications';
    }

    get isCompetitionsHackathonsTypeSelected() {
        return this.selectedExtraType === 'competitions_hackathons';
    }

    get isInternshipsTypeSelected() {
        return this.selectedExtraType === 'internships_work_experience';
    }

    get descriptionPlaceholder() {
        if (
            this.isSportsTypeSelected ||
            this.isCulturalArtsTypeSelected ||
            this.isSocialWorkTypeSelected ||
            this.isCertificationTypeSelected ||
            this.isCompetitionsHackathonsTypeSelected ||
            this.isInternshipsTypeSelected
        ) {
            return 'Write a short description';
        }
        return 'What was this award for?';
    }

    get conductItems() {
        return CONDUCT_ITEMS;
    }

    get hasStudentPhoto() {
        return Boolean(this.studentPhotoUrl);
    }

    get isStudentRole() {
        return String(this.userRole || '').trim().toLowerCase() !== 'faculty';
    }

    get isFacultyRole() {
        return !this.isStudentRole;
    }
    get isFacultyRole() {
        return String(this.userRole || '').trim().toLowerCase() === 'faculty';
    }

    handleViewIdCard() {
        this.isIdCardModalOpen = true;
    }

    closeIdCardModal() {
        this.isIdCardModalOpen = false;
    }

    handleIdCardDownload() {
        this.isIdCardModalOpen = false;
        this.isDownloadSuccessOpen = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.isDownloadSuccessOpen = false;
        }, 3000);
    }

    stopIdCardModalClose(event) {
        event.stopPropagation();
    }

    get academicsTabClass() {
        return this.activeTab === 'academics' ? 'tab-btn is-active' : 'tab-btn';
    }

    get educationalTabClass() {
        return this.activeTab === 'educational' ? 'tab-btn is-active' : 'tab-btn';
    }

    get clubsTabClass() {
        return this.activeTab === 'clubs' ? 'tab-btn is-active' : 'tab-btn';
    }

    get extraCurricularsTabClass() {
        return this.activeTab === 'extra' ? 'tab-btn is-active' : 'tab-btn';
    }

    get conductTabClass() {
        return this.activeTab === 'conduct' ? 'tab-btn is-active' : 'tab-btn';
    }

    get isAcademicsTab() {
        return this.activeTab === 'academics';
    }

    get isEducationalTab() {
        return this.activeTab === 'educational';
    }

    get isClubsTab() {
        return this.activeTab === 'clubs';
    }

    get isExtraTab() {
        return this.activeTab === 'extra';
    }

    get isConductTab() {
        return this.activeTab === 'conduct';
    }

    handleTabChange(event) {
        const nextTab = event.currentTarget?.dataset?.tab;
        if (!nextTab) {
            return;
        }
        this.activeTab = nextTab;
    }

    handleOpenExtraCurricularModal() {
        this.isExtraCurricularModalOpen = true;
        this.isExtraCurricularSuccessOpen = false;
    }

    handleCloseExtraCurricularModal() {
        this.isExtraCurricularModalOpen = false;
    }

    handleExtraTypeChange(event) {
        this.selectedExtraType = event.target.value;
    }

    handleExtraCurricularSave() {
        this.isExtraCurricularModalOpen = false;
        this.isExtraCurricularSuccessOpen = true;
    }

    handleCloseExtraCurricularSuccess() {
        this.isExtraCurricularSuccessOpen = false;
    }

    handleDownloadGradeCard() {
        this.isDownloadSuccessOpen = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.isDownloadSuccessOpen = false;
        }, 3000);
    }

    handleConductViewDetails() {
        window.open(this.buildCommunityUrl('conductdetails'), '_self');
    }

    buildCommunityUrl(path = '') {
        const basePath = communityBasePath || '/';
        const normalizedBase = basePath.endsWith('/') ? basePath.slice(0, -1) : basePath;
        const normalizedPath = path ? (path.startsWith('/') ? path : `/${path}`) : '';
        return `${normalizedBase}${normalizedPath}` || '/';
    }

    connectedCallback() {
        this.loadCurrentUserProfile();
    }

    async loadCurrentUserProfile() {
        try {
            const profile = await getCurrentUserProfile();
            this.studentPhotoUrl = profile?.photoUrl || '';
            this.userRole = profile?.roleType || '';
        } catch {
            this.studentPhotoUrl = '';
            this.userRole = '';
        }
    }

    applyOrganizationTheme() {
        if (!this.template?.host) {
            return;
        }
        const primary = this.organizationDefaults?.primary;
        const secondary = this.organizationDefaults?.secondary;

        if (primary && typeof primary === 'string') {
            this.template.host.style.setProperty('--primary-color', primary);
        }
        if (secondary && typeof secondary === 'string') {
            this.template.host.style.setProperty('--secondary-color', secondary);
        }
    }

    @wire(OrganizationDefaultsApiController)
    wiredOrganizationDefaults({ data }) {
        if (data) {
            this.organizationDefaults = data;
            this.applyOrganizationTheme();
        }
    }
}