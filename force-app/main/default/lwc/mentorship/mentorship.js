import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { mentors, mentorTasks, mentorSessions } from 'c/mockData';
import getTasks from '@salesforce/apex/KenMentorshipController.getTasks';
import addTaskApex from '@salesforce/apex/KenMentorshipController.addTask';

const MENTOR_PHOTOS = [
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&h=200&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=200&h=200&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1573497019940-1c28c88b4f3e?w=200&h=200&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=200&h=200&fit=crop&crop=face'
];

const MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];
const SESSION_DAYS = new Set([7, 12, 14, 21, 26, 27]);

export default class Mentorship extends LightningElement {
    mentors = mentors;
    tasks = mentorTasks;
    sessions = mentorSessions;

    @track currentYear = new Date().getFullYear();
    @track currentMonth = new Date().getMonth();
    @track selectedDay = new Date().getDate();
    @track showToast = false;
    @track toastMessage = '';
    @track toastVariant = 'success';
    @track showScheduleModal = false;
    @track showTaskModal = false;
    @track newTaskTitle = '';
    @track newTaskDeadline = '';

    get monthLabel() {
        return MONTHS[this.currentMonth] + ' ' + this.currentYear;
    }

    get selectedDateLabel() {
        return this.selectedDay + ' ' + MONTHS[this.currentMonth] + ', ' + this.currentYear;
    }

    get calendarDays() {
        const year = this.currentYear;
        const month = this.currentMonth;
        const firstDay = new Date(year, month, 1).getDay();
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const today = new Date();
        const isCurrentMonth = today.getFullYear() === year && today.getMonth() === month;
        const todayDate = today.getDate();
        const days = [];
        for (let i = 0; i < firstDay; i++) {
            days.push({ key: 'e-' + i, day: '', dayClass: 'cal-empty' });
        }
        for (let d = 1; d <= daysInMonth; d++) {
            const isToday = isCurrentMonth && d === todayDate;
            const isSelected = d === this.selectedDay;
            const isHighlight = SESSION_DAYS.has(d);
            let cls = 'cal-day';
            if (isToday) { cls = cls + ' cal-today'; }
            else if (isSelected) { cls = cls + ' cal-selected'; }
            else if (isHighlight) { cls = cls + ' cal-highlight'; }
            days.push({ key: 'd-' + d, day: d, dayClass: cls });
        }
        return days;
    }

    get formattedMentors() {
        return this.mentors.map((m, i) => ({
            ...m,
            typeClass: 'mentor-type ' + m.type.toLowerCase(),
            photo: MENTOR_PHOTOS[i % MENTOR_PHOTOS.length]
        }));
    }

    get formattedTasks() {
        return this.tasks.map(t => ({
            ...t,
            statusClass: 'status-badge ' + t.status.toLowerCase().replace(' ', '-'),
            priorityClass: 'priority ' + t.priority.toLowerCase()
        }));
    }

    get formattedSessions() {
        return this.sessions.map(session => {
            const actions = session.actions || [];
            return {
                ...session,
                colorBarClass: session.isLive ? 'session-color-bar-live' : 'session-color-bar',
                hasActions: actions.length > 0,
                formattedActions: actions.map(a => ({
                    label: a,
                    key: 'act-' + a,
                    btnClass: a === 'Leave Feedback' ? 'btn-feedback-sm' : 'btn-outline-sm'
                }))
            };
        });
    }

    _toast(msg, variant) {
        this.toastMessage = msg;
        this.toastVariant = variant || 'success';
        this.showToast = true;
    }

    handleToastClose() { this.showToast = false; }
    handleFilters() {
        this.toastMessage = 'Filters: showing all mentors';
        this.toastVariant = 'info';
        this.showToast = true;
    }

    handlePrevMonth() {
        if (this.currentMonth === 0) {
            this.currentMonth = 11;
            this.currentYear = this.currentYear - 1;
        } else {
            this.currentMonth = this.currentMonth - 1;
        }
    }

    handleNextMonth() {
        if (this.currentMonth === 11) {
            this.currentMonth = 0;
            this.currentYear = this.currentYear + 1;
        } else {
            this.currentMonth = this.currentMonth + 1;
        }
    }

    handleDayClick(event) {
        const day = parseInt(event.currentTarget.dataset.day, 10);
        if (day > 0) {
            this.selectedDay = day;
        }
    }

    handleConnect(event) {
        const name = event.currentTarget.dataset.name;
        this._toast('Connection request sent to ' + (name || 'mentor') + '!', 'success');
    }

    handleScheduleCall() {
        this.showScheduleModal = true;
    }

    handleCloseScheduleModal() {
        this.showScheduleModal = false;
    }

    handleConfirmSchedule() {
        this.showScheduleModal = false;
        this._toast('Session scheduled! A confirmation will be sent to your email.', 'success');
    }

    handleAddTask() {
        this.showTaskModal = true;
        this.newTaskTitle = '';
        this.newTaskDeadline = '';
    }

    handleCloseTaskModal() {
        this.showTaskModal = false;
    }

    handleTaskTitleChange(event) {
        this.newTaskTitle = event.target.value;
    }

    handleTaskDeadlineChange(event) {
        this.newTaskDeadline = event.target.value;
    }

    @track _persistedTasks = [];
    @track _wireTasksResp;

    @wire(getTasks)
    wiredTasks(response) {
        this._wireTasksResp = response;
        const { data, error } = response;
        if (data) this._persistedTasks = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[mentorship] getTasks failed:', error);
        }
    }

    get visibleTasks() {
        // Persisted tasks (from Apex) shown first, then any seed tasks.
        if (this._persistedTasks && this._persistedTasks.length) return this._persistedTasks;
        return mentorTasks || [];
    }

    handleConfirmTask() {
        const t = (this.newTaskTitle || '').trim();
        if (!t) { this._toast('Please enter a task title', 'error'); return; }
        if (t.length > 200) { this._toast('Task title must be 200 characters or fewer.', 'error'); return; }
        const dueIso = this.newTaskDeadline || null;
        if (dueIso) {
            const todayIso = new Date().toISOString().slice(0, 10);
            if (dueIso < todayIso) { this._toast('Due date cannot be in the past.', 'error'); return; }
        }
        addTaskApex({ title: t, description: '', mentorName: '', dueDate: dueIso })
            .then(saved => {
                this._persistedTasks = [saved, ...(this._persistedTasks || [])];
                this.showTaskModal = false;
                this._toast('Task added successfully!', 'success');
                this.newTaskTitle = '';
                this.newTaskDeadline = '';
                if (this._wireTasksResp) refreshApex(this._wireTasksResp);
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not add the task.';
                this._toast(msg, 'error');
            });
    }

    stopProp(event) { event.stopPropagation(); }

    handleSessionAction(event) {
        const action = event.currentTarget.dataset.action;
        if (action === 'Leave Feedback') {
            this._toast('Thank you for your feedback! It helps us improve mentorship quality.', 'success');
        } else if (action === 'Join Session') {
            this._toast('Opening session link\u2026', 'info');
        } else if (action === 'View Notes') {
            this._toast('Session notes loaded.', 'info');
        }
    }
}