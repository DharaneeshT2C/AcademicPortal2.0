import { LightningElement } from 'lwc';
import THEORY_IMAGE from '@salesforce/resourceUrl/Theory';
import PRACTICAL_IMAGE from '@salesforce/resourceUrl/Practical';
import ContactIcon from '@salesforce/resourceUrl/ContactIcon';
import LocationIcon from '@salesforce/resourceUrl/LocationIcon';

const TAB_OPTIONS = [
    { label: 'BA., Psychology', value: 'ba_psychology' },
    { label: 'Digital Marketing & E-Commerce', value: 'digital_marketing' },
    { label: 'Financial Markets & Investment Management', value: 'finance_markets' }
];

const SAMPLE_COURSES = [
    {
        id: 'c1',
        title: 'Cognitive Psychology',
        code: 'DS1829',
        credits: '4 credits',
        instructor: 'Mrs Smitha Beryl',
        room: 'Room 201',
        requirement: 'mandatory',
        mode: 'Theory',
        bannerType: 'theory'
    },
    {
        id: 'c2',
        title: 'Environmental Psychology',
        code: 'DS1829',
        credits: '4 credits',
        instructor: 'Mrs Smitha Beryl',
        room: 'Math Lab',
        requirement: 'elective',
        mode: 'Practical',
        bannerType: 'practical'
    },
    {
        id: 'c3',
        title: 'Forensic Psychology',
        code: 'DS1829',
        credits: '4 credits',
        instructor: 'Mrs Smitha Beryl',
        room: 'Room 201',
        requirement: 'mandatory',
        mode: 'Theory',
        bannerType: 'theory'
    },
    {
        id: 'c4',
        title: 'Physics Lab',
        code: 'DS1829',
        credits: '4 credits',
        instructor: 'Mrs Smitha Beryl',
        room: 'Math Lab',
        requirement: 'elective',
        mode: 'Practical',
        bannerType: 'practical'
    },
    {
        id: 'c5',
        title: 'Psychological Testing & Assessment',
        code: 'DS1829',
        credits: '4 credits',
        instructor: 'Mrs Smitha Beryl',
        room: 'Room 201',
        requirement: 'elective',
        mode: 'Practical',
        bannerType: 'practical'
    },
    {
        id: 'c6',
        title: 'Psychological Statistics',
        code: 'DS1829',
        credits: '4 credits',
        instructor: 'Mrs Smitha Beryl',
        room: 'Room 201',
        requirement: 'mandatory',
        mode: 'Theory',
        bannerType: 'theory'
    }
];

const CURRENT_SEMESTER = 'semester1';

export default class StudentLearn extends LightningElement {
    activeTab = 'ba_psychology';
    semesterValue = 'semester1';
    isDropdownOpen = false;

    semesterOptions = [
        { label: 'Semester 1', value: 'semester1', isCurrent: true },
        { label: 'Semester 2', value: 'semester2', isCurrent: false },
        { label: 'Semester 3', value: 'semester3', isCurrent: false }
    ];

    get tabs() {
        return TAB_OPTIONS.map((tab) => ({
            ...tab,
            isActive: tab.value === this.activeTab,
            className: tab.value === this.activeTab ? 'tab-btn active' : 'tab-btn'
        }));
    }

    get selectedSemesterLabel() {
        const match = this.semesterOptions.find((o) => o.value === this.semesterValue);
        return match ? match.label : '';
    }

    get selectedSemesterIsCurrent() {
        return this.semesterValue === CURRENT_SEMESTER;
    }

    get semesterOptionsForDropdown() {
        return this.semesterOptions;
    }

    get courses() {
        return SAMPLE_COURSES.map((course) => ({
            ...course,
            imageUrl: course.bannerType === 'theory' ? THEORY_IMAGE : PRACTICAL_IMAGE,
            requirementLabel: course.requirement === 'mandatory' ? 'Mandatory' : 'Elective',
            requirementClass:
                course.requirement === 'mandatory' ? 'tag tag-mandatory' : 'tag tag-elective'
        }));
    }

    handleTabChange(event) {
        this.activeTab = event.currentTarget.dataset.value;
    }

    handleDropdownToggle(event) {
        event.stopPropagation();
        this.isDropdownOpen = !this.isDropdownOpen;
    }

    handleOptionSelect(event) {
        event.stopPropagation();
        this.semesterValue = event.currentTarget.dataset.value;
        this.isDropdownOpen = false;
    }

        get calendarIconUrl() {
            return ContactIcon;
        }
    
        get acceptIconUrl() {
            return LocationIcon;
        }

    closeDropdown() {
        this.isDropdownOpen = false;
    }
}