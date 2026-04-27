import { LightningElement } from 'lwc';
import communityBasePath from '@salesforce/community/basePath';

const COURSE_CARDS = [
    {
        id: 'course-1',
        title: 'Engineering Mathematics-I',
        code: 'CS45621',
        category: 'Mandatory',
        students: 32,
        courseType: 'Theory',
        program: 'B Tech., EEE',
        imageClass: 'card-banner banner-math'
    },
    {
        id: 'course-2',
        title: 'Data Structures and Algorithms',
        code: 'CS45621',
        category: 'Elective',
        students: 13,
        courseType: 'Theory',
        program: 'Specialization: AI and ML',
        imageClass: 'card-banner banner-dsa'
    },
    {
        id: 'course-3',
        title: 'Engineering Chemistry',
        code: 'CS45621',
        category: 'Mandatory',
        students: 3,
        courseType: 'Practicals',
        program: 'B Tech., EEE',
        imageClass: 'card-banner banner-chem'
    },
    {
        id: 'course-4',
        title: 'Data Structures and Algorithms',
        code: 'CS45621',
        category: 'Elective',
        students: 45,
        courseType: 'Theory',
        program: 'BBA., Human Resource',
        imageClass: 'card-banner banner-mech'
    },
    {
        id: 'course-5',
        title: 'Environmental Science and Sustainability',
        code: 'CS45621',
        category: 'Mandatory',
        students: 1,
        courseType: 'Theory',
        program: 'Specialization: AI and ML',
        imageClass: 'card-banner banner-env'
    }
];

export default class FacultyChooseCourse extends LightningElement {
    selectedSemester = 'semester-1';

    semesterOptions = [
        { label: 'Semester 1', value: 'semester-1' },
        { label: 'Semester 2', value: 'semester-2' },
        { label: 'Semester 3', value: 'semester-3' }
    ];

    get semesterSelectOptions() {
        return this.semesterOptions.map((option) => ({
            ...option,
            selected: option.value === this.selectedSemester
        }));
    }

    get courseCards() {
        return COURSE_CARDS.map((course) => ({
            ...course,
            categoryClass:
                course.category === 'Mandatory'
                    ? 'badge badge-mandatory'
                    : 'badge badge-elective'
        }));
    }

    handleSemesterChange(event) {
        this.selectedSemester = event.target.value;
    }

    handleCourseClick() {
        window.open(this.buildCommunityUrl('my-students'), '_self');
    }

    buildCommunityUrl(path = '') {
        const basePath = communityBasePath || '/';
        const sanitizedPath = path.replace(/^\/+|\/+$/g, '');

        if (basePath === '/') {
            return sanitizedPath ? `/${sanitizedPath}` : '/';
        }

        return sanitizedPath ? `${basePath}/${sanitizedPath}` : basePath;
    }
}