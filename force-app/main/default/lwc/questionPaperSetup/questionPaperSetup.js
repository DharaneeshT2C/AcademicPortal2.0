import { LightningElement } from 'lwc';
import communityBasePath from '@salesforce/community/basePath';

export default class QuestionPaperSetup extends LightningElement {
    rows = [
        { id: 'row-1', examType: '2022-Jan-BBA-Term 1', className: 'ECE-Sem I', course: 'Basics of Mechanical Engineering', dueDate: '30-06-2025', submittedOn: '--', status: 'Pending', statusType: 'pending', action: 'Upload', actionType: 'outline' },
        { id: 'row-2', examType: '2022-Jan-BBA-Term 1', className: 'ECE-Sem I', course: 'Basics of Mechanical Engineering', dueDate: '27-06-2025', submittedOn: '--', status: 'Pending', statusType: 'pending', action: 'Upload', actionType: 'outline' },
        { id: 'row-3', examType: '2022-Jan-BBA-Term 1', className: 'ECE-Sem I', course: 'Basics of Mechanical Engineering', dueDate: '24-06-2025', submittedOn: '24-06-2025', status: 'Alteration Requested', statusType: 'alteration', action: 'Re-Upload', actionType: 'outline' },
        { id: 'row-4', examType: '2022-Jan-BBA-Term 1', className: 'ECE-Sem I', course: 'Basics of Mechanical Engineering', dueDate: '23-06-2025', submittedOn: '23-06-2025', status: 'Pending', statusType: 'pending', action: 'Upload', actionType: 'outline' },
        { id: 'row-5', examType: '2022-Jan-BBA-Term 1', className: 'ECE-Sem I', course: 'Basics of Mechanical Engineering', dueDate: '20-06-2025', submittedOn: '20-06-2025', status: 'Approved', statusType: 'approved', action: 'View', actionType: 'primary' },
        { id: 'row-6', examType: '2022-Jan-BBA-Term 1', className: 'ECE-Sem I', course: 'Basics of Mechanical Engineering', dueDate: '18-06-2025', submittedOn: '18-06-2025', status: 'Alteration Requested', statusType: 'alteration', action: 'Re-Upload', actionType: 'outline' },
        { id: 'row-7', examType: '2022-Jan-BBA-Term 1', className: 'ECE-Sem I', course: 'Basics of Mechanical Engineering', dueDate: '15-06-2025', submittedOn: '15-06-2025', status: 'Alteration Requested', statusType: 'alteration', action: 'Re-Upload', actionType: 'outline' },
        { id: 'row-8', examType: '2022-Jan-BBA-Term 1', className: 'ECE-Sem I', course: 'Basics of Mechanical Engineering', dueDate: '13-06-2025', submittedOn: '13-06-2025', status: 'Pending', statusType: 'pending', action: 'Upload', actionType: 'outline' },
        { id: 'row-9', examType: '2022-Jan-BBA-Term 1', className: 'ECE-Sem I', course: 'Basics of Mechanical Engineering', dueDate: '11-06-2025', submittedOn: '11-06-2025', status: 'Submitted', statusType: 'submitted', action: 'View', actionType: 'primary' },
        { id: 'row-10', examType: '2022-Jan-BBA-Term 1', className: 'ECE-Sem I', course: 'Basics of Mechanical Engineering', dueDate: '07-06-2025', submittedOn: '07-06-2025', status: 'Approved', statusType: 'approved', action: 'View', actionType: 'primary' }
    ];

    get tableRows() {
        return this.rows.map((row) => {
            return {
                ...row,
                statusClass: `status-pill status-${row.statusType}`,
                actionClass: row.actionType === 'primary' ? 'action-btn action-primary' : 'action-btn action-outline'
            };
        });
    }

    handleActionClick() {
        window.open(this.buildCommunityUrl('exams/questionpapers/question-paper-setup'), '_self');
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