import { LightningElement } from 'lwc';

const TABS = [
    { id: 'mypath', label: 'My Path' },
    { id: 'achievements', label: 'Achievements' },
    { id: 'education', label: 'Education' },
    { id: 'research', label: 'Academic research' },
    { id: 'feedback', label: 'Performance feedback' },
    { id: 'assets', label: 'Allocated assets' }
];

const TERM_OPTIONS = [
    { label: 'Select term', value: '' },
    { label: 'Term 1', value: 'term1' },
    { label: 'Term 2', value: 'term2' },
    { label: 'Term 3', value: 'term3' }
];

const COURSE_ITEMS = [
    {
        id: 'c1',
        badge: 'Mandatory',
        students: '32 Students',
        title: 'Engineering Mathematics-I',
        code: 'CS45621',
        type: 'Theory',
        audience: 'B Tech., EEE',
        imageClass: 'course-image image-maths'
    },
    {
        id: 'c2',
        badge: 'Elective',
        students: '13 Students',
        title: 'Data Structures and Algorithms',
        code: 'CS45621',
        type: 'Theory',
        audience: 'Specialization: AI and ML',
        imageClass: 'course-image image-dsa'
    },
    {
        id: 'c3',
        badge: 'Mandatory',
        students: '03 Students',
        title: 'Engineering Chemistry',
        code: 'CS45621',
        type: 'Practicals',
        audience: 'B Tech., EEE',
        imageClass: 'course-image image-chem'
    },
    {
        id: 'c4',
        badge: 'Elective',
        students: '45 Students',
        title: 'Data Structures and Algorithms',
        code: 'CS45621',
        type: 'Theory',
        audience: 'BBA., Human Resource',
        imageClass: 'course-image image-mech'
    },
    {
        id: 'c5',
        badge: 'Mandatory',
        students: '11 Students',
        title: 'Engineering Design Studio',
        code: 'CS45621',
        type: 'Theory',
        audience: 'B Tech., EEE',
        imageClass: 'course-image image-design'
    }
];

const ACHIEVEMENT_ITEMS = [
    {
        id: 'a1',
        category: 'Events',
        title: 'Technical Paper Presentation',
        metaLine: 'Type - Seminar | Role - Speaker | Location - Bangalore',
        description:
            'The Asia-Pacific Conference on Communications (APCC) is a prestigious annual conference that focuses on telecommunication and networking technologies',
        attachment: 'certificate.pdf'
    },
    {
        id: 'a2',
        category: 'Consulting Projects',
        title: 'Advanced IoT and Embedded Applications',
        metaLine: 'Project industry - Texas Instruments | Consulted organization - Siemens | Role - Advisor',
        description:
            'Applications involves the integration of the Internet of Things (IoT) with embedded systems to create smart, connected devices that can collect',
        dateRange: '12 Oct 23 - 12 Nov 23',
        outcome:
            'I will be implementing end-to-end encryption for IoT devices, developing intrusion detection systems for embedded applications, and using blockchain technology to secure IoT data transactions',
        attachment: 'certificate.pdf'
    },
    {
        id: 'a3',
        category: 'Patent',
        title: 'The Impact of Technology Integration in the Classroom',
        metaLine: 'Application Number - 09887365 | Issuing Authority - Indian Patent Office | Status - Published',
        description:
            'A smart system designed to improve energy efficiency by monitoring real-time consumption and optimizing usage patterns using predictive algorithms.',
        dateRange: '12 Oct 23',
        attachment: 'patent.pdf'
    },
    {
        id: 'a4',
        category: 'Grants',
        title: 'Asia-Pacific Conference on Communications',
        metaLine: 'Funding agency - European Commission | Grant amount - ₹2,00,000 | Year - 2025',
        description:
            'The Asia-Pacific Conference on Communications (APCC) is a prestigious annual conference that focuses on telecommunication and networking technologies',
        attachment: 'grants.pdf'
    }
];

const EDUCATION_ITEMS = [
    {
        id: 'e1',
        title: 'Higher Secondary  (Computer Science)',
        institute: 'GRG Matric Hr Sec School',
        timeline: '2010 - 2012'
    },
    {
        id: 'e2',
        title: 'B Tech, Electronics and Media Technology',
        institute: 'Karunya University',
        timeline: '2010 - 2012'
    },
    {
        id: 'e3',
        title: 'M Des, User Interaction and Experience Design',
        institute: 'Jain University',
        timeline: '2018 - 2020'
    }
];

const RESEARCH_ITEMS = [
    {
        id: 'r1',
        title: 'AI-Based Smart Energy Optimization in Buildings',
        type: 'Journal Paper',
        venue: 'IEEE Transactions on Smart Grid',
        publicationYear: '2023',
        link: 'https://example.com/ai-energy-optimization'
    },
    {
        id: 'r2',
        title: 'IoT-Enabled Healthcare Monitoring System',
        type: 'Conference Paper',
        venue: 'International Conference on IoT & Healthcare',
        publicationYear: '2022',
        link: 'https://example.com/iot-healthcare'
    },
    {
        id: 'r3',
        title: 'Machine Learning Models for Predictive Maintenance in Manufacturing',
        type: 'Journal Paper',
        venue: 'Elsevier Journal of Manufacturing Systems',
        publicationYear: '2021',
        link: 'https://example.com/predictive-maintenance'
    }
];


const ALLOCATED_ASSET_ITEMS = [
    {
        id: 'as1',
        serialNo: '01',
        category: 'Equipments',
        assets: [
            {
                id: 'as1-1',
                name: 'Computer & Laptops',
                quantity: '1',
                issuedDateTime: '12-06-24 | 03:21pm',
                returnDate: '12-04-25'
            },
            {
                id: 'as1-2',
                name: 'Lab equipments',
                quantity: '1',
                issuedDateTime: '14-06-24 | 11:40am',
                returnDate: '09-05-25'
            }
        ]
    },
    {
        id: 'as2',
        serialNo: '02',
        category: 'Furniture',
        assets: [
            {
                id: 'as2-1',
                name: 'Desks & Tables',
                quantity: '1',
                issuedDateTime: '12-06-24 | 03:21pm',
                returnDate: '12-04-25'
            },
            {
                id: 'as2-2',
                name: 'Shelves & Cabinets',
                quantity: '1',
                issuedDateTime: '14-06-24 | 11:40am',
                returnDate: '09-05-25'
            },
            {
                id: 'as2-3',
                name: 'Chairs',
                quantity: '1',
                issuedDateTime: '14-06-24 | 11:40am',
                returnDate: '09-05-25'
            }
        ]
    }
];

const RESEARCH_TYPE_OPTIONS = [
    { label: 'Select type', value: '' },
    { label: 'Journal Paper', value: 'Journal Paper' },
    { label: 'Conference Paper', value: 'Conference Paper' },
    { label: 'Book Chapter', value: 'Book Chapter' }
];

const RESEARCH_YEAR_OPTIONS = [
    { label: 'Select year', value: '' },
    { label: '2026', value: '2026' },
    { label: '2025', value: '2025' },
    { label: '2024', value: '2024' },
    { label: '2023', value: '2023' },
    { label: '2022', value: '2022' },
    { label: '2021', value: '2021' },
    { label: '2020', value: '2020' }
];

const FEEDBACK_YEAR_OPTIONS = [
    { label: '2024-25', value: '2024-25' },
    { label: '2023-24', value: '2023-24' },
    { label: '2022-23', value: '2022-23' }
];

const FEEDBACK_CATEGORIES = [
    { id: 'overall', label: 'Overall' },
    { id: 'appraisal', label: 'Appraisal' },
    { id: 'goals', label: 'Goals & Milestone' },
    { id: 'performance', label: 'Performance Feedback' }
];

const FEEDBACK_MILESTONES = [
    {
        id: 'm1',
        title: 'Research Proposal Submission',
        status: 'On track',
        duration: '8 March 2025 - 16 Oct 2025',
        progress: '25%',
        updatedOn: '04/01/2025'
    },
    {
        id: 'm2',
        title: 'Analyze how real-time asset',
        status: 'On track',
        duration: '8 March 2025 - 16 Oct 2025',
        progress: '25%',
        updatedOn: '04/01/2025'
    },
    {
        id: 'm3',
        title: 'Sustainable Practices',
        status: 'On track',
        duration: '8 March 2025 - 16 Oct 2025',
        progress: '25%',
        updatedOn: '04/01/2025'
    }
];

const ACHIEVEMENT_TYPE_OPTIONS = [
    { label: 'Events', value: 'Events' },
    { label: 'Consulting Projects', value: 'Consulting Projects' },
    { label: 'Grants Received', value: 'Grants Received' },
    { label: 'Patent', value: 'Patent' },
    { label: 'Publications', value: 'Publications' }
];

const EVENT_TYPE_OPTIONS = [
    { label: 'Event Type', value: '' },
    { label: 'Conference', value: 'Conference' },
    { label: 'Workshop', value: 'Workshop' },
    { label: 'Seminar', value: 'Seminar' },
    { label: 'Webinar', value: 'Webinar' },
    { label: 'FDP', value: 'FDP' },
    { label: 'Other', value: 'Other' }
];

const ROLE_OPTIONS = [
    { label: 'Select role', value: '' },
    { label: 'Speaker', value: 'Speaker' },
    { label: 'Advisor', value: 'Advisor' },
    { label: 'Participant', value: 'Participant' }
];

const PROJECT_INDUSTRY_OPTIONS = [
    { label: 'Select', value: '' },
    { label: 'Education', value: 'Education' },
    { label: 'Healthcare', value: 'Healthcare' },
    { label: 'Manufacturing', value: 'Manufacturing' },
    { label: 'Technology', value: 'Technology' }
];

const PATENT_STATUS_OPTIONS = [
    { label: 'Select Status', value: '' },
    { label: 'Published', value: 'Published' },
    { label: 'Filed', value: 'Filed' },
    { label: 'Granted', value: 'Granted' }
];

const CURRENCY_OPTIONS = [
    { label: 'Select Currency', value: '' },
    { label: 'INR', value: 'INR' },
    { label: 'USD', value: 'USD' },
    { label: 'EUR', value: 'EUR' }
];

const PUBLICATION_TYPE_OPTIONS = [
    { label: 'Select type', value: '' },
    { label: 'Journal Paper', value: 'Journal Paper' },
    { label: 'Conference Paper', value: 'Conference Paper' },
    { label: 'Book Chapter', value: 'Book Chapter' }
];

const ACHIEVEMENT_YEAR_OPTIONS = [
    { label: 'Select Year', value: '' },
    { label: '2026', value: '2026' },
    { label: '2025', value: '2025' },
    { label: '2024', value: '2024' },
    { label: '2023', value: '2023' },
    { label: '2022', value: '2022' },
    { label: '2021', value: '2021' },
    { label: '2020', value: '2020' }
];

const EMPTY_ACHIEVEMENT_FORM = {
    type: 'Events',
    title: '',
    eventType: '',
    role: '',
    date: '',
    location: '',
    projectIndustry: '',
    clientOrganization: '',
    startDate: '',
    endDate: '',
    outcome: '',
    applicationNumber: '',
    issuingAuthority: '',
    patentStatus: '',
    fundingAgency: '',
    grantAmount: '',
    currency: '',
    year: '',
    publicationType: '',
    journalConferenceName: '',
    publicationYear: '',
    publicationLink: '',
    description: '',
    attachment: ''
};

export default class MyProfileFaculty extends LightningElement {
    activeTab = 'mypath';
    selectedTerm = '';
    feedbackCategory = 'overall';
    feedbackYear = '2024-25';
    achievementItems = [...ACHIEVEMENT_ITEMS];
    isAchievementModalOpen = false;
    achievementForm = { ...EMPTY_ACHIEVEMENT_FORM };
    researchItems = [...RESEARCH_ITEMS];
    isResearchModalOpen = false;
    isResearchSuccessOpen = false;
    researchForm = {
        type: '',
        title: '',
        venue: '',
        publicationYear: '',
        link: ''
    };

    get tabs() {
        return TABS.map((tab) => ({
            ...tab,
            className: tab.id === this.activeTab ? 'tab-btn is-active' : 'tab-btn'
        }));
    }

    get isMyPathTab() {
        return this.activeTab === 'mypath';
    }

    get isAchievementsTab() {
        return this.activeTab === 'achievements';
    }

    get isEducationTab() {
        return this.activeTab === 'education';
    }

    get isResearchTab() {
        return this.activeTab === 'research';
    }

    get isAssetsTab() {
        return this.activeTab === 'assets';
    }

    get isFeedbackTab() {
        return this.activeTab === 'feedback';
    }

    get isFeedbackOverall() {
        return this.feedbackCategory === 'overall';
    }

    get isFeedbackAppraisal() {
        return this.feedbackCategory === 'appraisal';
    }

    get isFeedbackGoals() {
        return this.feedbackCategory === 'goals';
    }

    get isFeedbackPerformance() {
        return this.feedbackCategory === 'performance';
    }

    get termOptions() {
        return TERM_OPTIONS.map((option) => ({
            ...option,
            selected: option.value === this.selectedTerm
        }));
    }

    get courses() {
        return COURSE_ITEMS;
    }

    get achievements() {
        return this.achievementItems;
    }

    get achievementTypeOptions() {
        return ACHIEVEMENT_TYPE_OPTIONS.map((item) => ({
            ...item,
            selected: item.value === this.achievementForm.type
        }));
    }

    get achievementEventTypeOptions() {
        return EVENT_TYPE_OPTIONS.map((item) => ({
            ...item,
            selected: item.value === this.achievementForm.eventType
        }));
    }

    get achievementRoleOptions() {
        return ROLE_OPTIONS.map((item) => ({
            ...item,
            selected: item.value === this.achievementForm.role
        }));
    }

    get achievementIndustryOptions() {
        return PROJECT_INDUSTRY_OPTIONS.map((item) => ({
            ...item,
            selected: item.value === this.achievementForm.projectIndustry
        }));
    }

    get achievementPatentStatusOptions() {
        return PATENT_STATUS_OPTIONS.map((item) => ({
            ...item,
            selected: item.value === this.achievementForm.patentStatus
        }));
    }

    get achievementCurrencyOptions() {
        return CURRENCY_OPTIONS.map((item) => ({
            ...item,
            selected: item.value === this.achievementForm.currency
        }));
    }

    get achievementYearOptions() {
        return ACHIEVEMENT_YEAR_OPTIONS.map((item) => ({
            ...item,
            selected: item.value === this.achievementForm.year
        }));
    }

    get achievementPublicationTypeOptions() {
        return PUBLICATION_TYPE_OPTIONS.map((item) => ({
            ...item,
            selected: item.value === this.achievementForm.publicationType
        }));
    }

    get achievementPublicationYearOptions() {
        return ACHIEVEMENT_YEAR_OPTIONS.map((item) => ({
            ...item,
            selected: item.value === this.achievementForm.publicationYear
        }));
    }

    get isAchievementTypeEvents() {
        return this.achievementForm.type === 'Events';
    }

    get isAchievementTypeConsulting() {
        return this.achievementForm.type === 'Consulting Projects';
    }

    get isAchievementTypePatent() {
        return this.achievementForm.type === 'Patent';
    }

    get isAchievementTypeGrants() {
        return this.achievementForm.type === 'Grants Received';
    }

    get isAchievementTypePublications() {
        return this.achievementForm.type === 'Publications';
    }

    get feedbackCategories() {
        return FEEDBACK_CATEGORIES.map((item) => ({
            ...item,
            className: item.id === this.feedbackCategory ? 'feedback-cat-btn is-active' : 'feedback-cat-btn'
        }));
    }

    get feedbackYearOptions() {
        return FEEDBACK_YEAR_OPTIONS.map((item) => ({
            ...item,
            selected: item.value === this.feedbackYear
        }));
    }

    get feedbackMilestones() {
        return FEEDBACK_MILESTONES.map((item, index) => ({
            ...item,
            milestoneLabel: `Milestone #${index + 1}`
        }));
    }

    get educationItems() {
        return EDUCATION_ITEMS;
    }

    get researchTypeOptions() {
        return RESEARCH_TYPE_OPTIONS.map((option) => ({
            ...option,
            selected: option.value === this.researchForm.type
        }));
    }


    get allocatedAssetRows() {
        return ALLOCATED_ASSET_ITEMS.flatMap((group) =>
            group.assets.map((asset, index) => ({
                id: asset.id,
                showGroupDetails: index === 0,
                rowSpan: group.assets.length,
                serialNo: group.serialNo,
                category: group.category,
                name: asset.name,
                quantity: asset.quantity,
                issuedDateTime: asset.issuedDateTime,
                returnDate: asset.returnDate
            }))
        );
    }

    get researchYearOptions() {
        return RESEARCH_YEAR_OPTIONS.map((option) => ({
            ...option,
            selected: option.value === this.researchForm.publicationYear
        }));
    }

    handleTabChange(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    handleTermChange(event) {
        this.selectedTerm = event.target.value;
    }

    handleFeedbackCategoryChange(event) {
        this.feedbackCategory = event.currentTarget.dataset.category;
    }

    handleFeedbackYearChange(event) {
        this.feedbackYear = event.target.value;
    }

    handleViewIdCard() {
        window.open('/idcard', '_self');
    }

    handleAddAchievement() {
        this.activeTab = 'achievements';
        this.isAchievementModalOpen = true;
    }

    handleCloseAchievementModal() {
        this.isAchievementModalOpen = false;
    }

    handleAchievementBackdropClick() {
        this.handleCloseAchievementModal();
    }

    stopAchievementModalClose(event) {
        event.stopPropagation();
    }

    handleAchievementFormChange(event) {
        const field = event.target.dataset.field;
        if (field === 'type') {
            this.achievementForm = {
                ...EMPTY_ACHIEVEMENT_FORM,
                type: event.target.value
            };
            return;
        }

        this.achievementForm = {
            ...this.achievementForm,
            [field]: event.target.value
        };
    }

    handleAchievementFileChange(event) {
        const file = event.target.files && event.target.files.length ? event.target.files[0] : null;
        this.achievementForm = {
            ...this.achievementForm,
            attachment: file ? file.name : ''
        };
    }

    handleSaveAchievement() {
        const entry = this.buildAchievementPayload();
        if (!entry) return;

        this.achievementItems = [
            entry,
            ...this.achievementItems
        ];

        this.achievementForm = { ...EMPTY_ACHIEVEMENT_FORM };
        this.isAchievementModalOpen = false;
    }

    buildAchievementPayload() {
        const form = this.achievementForm;
        const base = {
            id: `a-${Date.now()}`,
            category: form.type,
            title: '',
            metaLine: '',
            description: form.description.trim() || 'Achievement details submitted for review.',
            attachment: form.attachment || 'certificate.pdf'
        };

        if (form.type === 'Events') {
            if (!form.title.trim() || !form.eventType || !form.role || !form.date || !form.location.trim()) return null;
            return {
                ...base,
                title: form.title.trim(),
                metaLine: `Type - ${form.eventType} | Role - ${form.role} | Location - ${form.location.trim()}`,
                dateRange: this.formatAchievementDate(form.date)
            };
        }

        if (form.type === 'Consulting Projects') {
            if (
                !form.title.trim() ||
                !form.projectIndustry ||
                !form.clientOrganization.trim() ||
                !form.role.trim() ||
                !form.startDate ||
                !form.endDate
            ) {
                return null;
            }
            return {
                ...base,
                title: form.title.trim(),
                metaLine: `Project industry - ${form.projectIndustry} | Consulted organization - ${form.clientOrganization.trim()} | Role - ${form.role.trim()}`,
                description: form.description.trim() || 'Consulting project details submitted for review.',
                outcome: form.outcome.trim(),
                dateRange: `${this.formatAchievementDate(form.startDate)} - ${this.formatAchievementDate(form.endDate)}`
            };
        }

        if (form.type === 'Patent') {
            if (!form.title.trim() || !form.applicationNumber.trim() || !form.issuingAuthority.trim() || !form.patentStatus || !form.date) {
                return null;
            }
            return {
                ...base,
                title: form.title.trim(),
                metaLine: `Application Number - ${form.applicationNumber.trim()} | Issuing Authority - ${form.issuingAuthority.trim()} | Status - ${form.patentStatus}`,
                dateRange: this.formatAchievementDate(form.date)
            };
        }

        if (form.type === 'Grants Received') {
            if (!form.title.trim() || !form.fundingAgency.trim() || !form.grantAmount.trim() || !form.currency || !form.year) {
                return null;
            }
            return {
                ...base,
                title: form.title.trim(),
                metaLine: `Funding agency - ${form.fundingAgency.trim()} | Grant amount - ${form.currency} ${form.grantAmount.trim()} | Year - ${form.year}`,
                dateRange: form.year
            };
        }

        if (form.type === 'Publications') {
            if (!form.publicationType || !form.title.trim() || !form.journalConferenceName.trim() || !form.publicationYear) {
                return null;
            }
            return {
                ...base,
                title: form.title.trim(),
                metaLine: `Type - ${form.publicationType} | Journal / Conference Name - ${form.journalConferenceName.trim()} | Publication Year - ${form.publicationYear}`,
                description: form.description.trim() || form.publicationLink.trim() || 'Publication record added.',
                dateRange: form.publicationYear
            };
        }

        return null;
    }

    formatAchievementDate(dateString) {
        const value = new Date(dateString);
        if (Number.isNaN(value.getTime())) {
            return '';
        }
        return value.toLocaleDateString('en-GB', {
            day: '2-digit',
            month: 'short',
            year: '2-digit'
        });
    }

    handleOpenResearchModal() {
        this.isResearchModalOpen = true;
    }

    handleCloseResearchModal() {
        this.isResearchModalOpen = false;
    }

    handleResearchBackdropClick() {
        this.handleCloseResearchModal();
    }

    stopResearchModalClose(event) {
        event.stopPropagation();
    }

    handleResearchFormChange(event) {
        const field = event.target.dataset.field;
        this.researchForm = {
            ...this.researchForm,
            [field]: event.target.value
        };
    }

    handleSaveResearch() {
        const { type, title, venue, publicationYear } = this.researchForm;
        if (!type || !title.trim() || !venue.trim() || !publicationYear) {
            return;
        }

        this.researchItems = [
            {
                id: `r-${Date.now()}`,
                title: title.trim(),
                type,
                venue: venue.trim(),
                publicationYear,
                link: this.researchForm.link.trim()
            },
            ...this.researchItems
        ];

        this.researchForm = {
            type: '',
            title: '',
            venue: '',
            publicationYear: '',
            link: ''
        };
        this.isResearchModalOpen = false;
        this.isResearchSuccessOpen = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.isResearchSuccessOpen = false;
        }, 1800);
    }
}