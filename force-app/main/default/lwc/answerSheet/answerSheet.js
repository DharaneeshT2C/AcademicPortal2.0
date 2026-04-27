import { LightningElement } from 'lwc';
import communityBasePath from '@salesforce/community/basePath';

const INITIAL_ROWS = [
    {
        id: 'row-1',
        courseName: 'Network Analysis & Synthesis',
        courseCode: 'ECE101',
        exam: 'End Semester',
        credits: 3,
        format: 'Theory',
        type: 'Regular',
        selected: true
    },
    {
        id: 'row-2',
        courseName: 'Human Resource Management',
        courseCode: 'ECE103',
        exam: 'End Semester',
        credits: 3,
        format: 'Theory',
        type: 'Backlog',
        selected: true
    },
    {
        id: 'row-3',
        courseName: 'Microwave Engineering',
        courseCode: 'ECE105',
        exam: 'End Semester',
        credits: 3,
        format: 'Theory',
        type: 'Regular',
        selected: true
    }
];

export default class AnswerSheet extends LightningElement {
    rows = INITIAL_ROWS;
    isConfirmModalOpen = false;
    isSuccessToastVisible = false;

    get isAllSelected() {
        return this.rows.length > 0 && this.rows.every((row) => row.selected);
    }

    handleSelectAll(event) {
        const isChecked = event.currentTarget.checked;
        this.rows = this.rows.map((row) => ({
            ...row,
            selected: isChecked
        }));
    }

    handleRowToggle(event) {
        const rowId = event.currentTarget.dataset.id;
        const isChecked = event.currentTarget.checked;
        this.rows = this.rows.map((row) => {
            if (row.id !== rowId) {
                return row;
            }
            return {
                ...row,
                selected: isChecked
            };
        });
    }

    openConfirmModal() {
        this.isConfirmModalOpen = true;
    }

        buildCommunityUrl(path = '') {
            const basePath = communityBasePath || '/';
            const sanitizedPath = path.replace(/^\/+|\/+$/g, '');
    
            if (basePath === '/') {
                return sanitizedPath ? `/${sanitizedPath}` : '/';
            }
    
            return sanitizedPath ? `${basePath}/${sanitizedPath}` : basePath;
        }
    

    handleCancelSheet(){
          const targetUrl = this.buildCommunityUrl('my-exams');
        window.open(targetUrl, '_self');
    }

    closeConfirmModal() {
        this.isConfirmModalOpen = false;
    }

    handleConfirmSubmit() {
        this.isSuccessToastVisible = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const targetUrl = this.buildCommunityUrl('my-exams');
            window.open(targetUrl, '_self');
        }, 3000);
    }

    stopModalClose(event) {
        event.stopPropagation();
    }
}