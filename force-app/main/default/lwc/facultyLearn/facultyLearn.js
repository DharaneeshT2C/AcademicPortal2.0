import { LightningElement } from 'lwc';

const COURSES = [
    {
        id: 'c1',
        name: 'Cognitive Psychology',
        program: 'BA Psychology',
        code: 'DSI829',
        credits: '4 credits',
        students: 120,
        room: 'Room 201',
        type: 'Mandatory',
        mode: 'Theory',
        typeClass: 'tag tag-mandatory',
        modeClass: 'tag tag-mode',
        bannerClass: 'banner banner-green'
    },
    {
        id: 'c2',
        name: 'Environmental Psychology',
        program: 'B Tech ECE',
        code: 'DSI829',
        credits: '4 credits',
        students: 24,
        room: 'Room 201',
        type: 'Elective',
        mode: 'Practical',
        typeClass: 'tag tag-elective',
        modeClass: 'tag tag-mode',
        bannerClass: 'banner banner-violet'
    },
    {
        id: 'c3',
        name: 'Forensic Psychology',
        program: 'BA Forensic',
        code: 'DSI829',
        credits: '4 credits',
        students: 120,
        room: 'Room 201',
        type: 'Mandatory',
        mode: 'Theory',
        typeClass: 'tag tag-mandatory',
        modeClass: 'tag tag-mode',
        bannerClass: 'banner banner-green soft'
    },
    {
        id: 'c4',
        name: 'Physics Lab',
        program: 'B Tech EEE',
        code: 'DSI829',
        credits: '4 credits',
        students: 24,
        room: 'Room 201',
        type: 'Elective',
        mode: 'Practical',
        typeClass: 'tag tag-elective',
        modeClass: 'tag tag-mode',
        bannerClass: 'banner banner-violet'
    },
    {
        id: 'c5',
        name: 'Psychological Testing & Assessment',
        program: 'BA Psychology',
        code: 'DSI829',
        credits: '4 credits',
        students: 24,
        room: 'Room 201',
        type: 'Elective',
        mode: 'Practical',
        typeClass: 'tag tag-elective',
        modeClass: 'tag tag-mode',
        bannerClass: 'banner banner-violet'
    },
    {
        id: 'c6',
        name: 'Psychological Statistics',
        program: 'BA Psychology',
        code: 'DSI829',
        credits: '4 credits',
        students: 120,
        room: 'Room 201',
        type: 'Mandatory',
        mode: 'Theory',
        typeClass: 'tag tag-mandatory',
        modeClass: 'tag tag-mode',
        bannerClass: 'banner banner-green soft'
    }
];

export default class FacultyLearn extends LightningElement {
    semesterValue = 'semester1';

    semesterOptions = [
        { label: 'Semester 1', value: 'semester1' },
        { label: 'Semester 2', value: 'semester2' }
    ];

    courses = COURSES;

    get selectedSemesterOptions() {
        return this.semesterOptions.map((option) => ({
            ...option,
            selected: option.value === this.semesterValue
        }));
    }

    handleSemesterChange(event) {
        this.semesterValue = event.target.value;
    }
}