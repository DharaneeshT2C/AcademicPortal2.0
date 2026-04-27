import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import getStudentCalendarEvents from '@salesforce/apex/KenCourseEnrollmentController.getStudentCalendarEvents';
import FullCalendarJSFromResource from '@salesforce/resourceUrl/FullCalendar';

export default class MySchedule extends NavigationMixin(LightningElement) {
    activeView = 'day';
    selectedDate = new Date().toISOString().slice(0, 10);
    calendarLoaded = false;
    calendarInitialized = false;
    hasLibraryError = false;
    scheduleEvents = [];
    isScheduleCallModalOpen = false;
    isCallRequestedModalOpen = false;
    meetMode = 'online';
    successModalTimer;
    leaveCards = [
        {
            id: 'leave-1',
            title: 'Personal Leave',
            subtitle: 'Going for a Vacation',
            meta: '26th December | 5 days',
            status: 'Leave Approved'
        },
        {
            id: 'leave-2',
            title: 'Personal Leave',
            subtitle: 'Going for a Vacation',
            meta: '26th December | 5 days',
            status: 'Leave Approved'
        }
    ];
    oneOnOneCards = [
        {
            id: 'one-1',
            name: 'Aravind Kumar',
            schedule: '12 March, 2025 | 01:00 PM - 2:00 PM',
            topic: 'Microprocessor lab',
            note: 'Need help with notes',
            showActions: true,
            cardClass: 'one-item one-item-highlight'
        },
        {
            id: 'one-2',
            name: 'Aravind Kumar',
            schedule: '12 March, 2025 | 01:00 PM - 2:00 PM',
            topic: 'Microprocessor lab',
            note: 'Need help with notes',
            showActions: false,
            cardClass: 'one-item'
        }
    ];

    get dayTabClass() {
        return this.activeView === 'day' ? 'tab-btn tab-active' : 'tab-btn';
    }
    get weekTabClass() {
        return this.activeView === 'week' ? 'tab-btn tab-active' : 'tab-btn';
    }
    get monthTabClass() {
        return this.activeView === 'month' ? 'tab-btn tab-active' : 'tab-btn';
    }
    get displayDateLabel() {
        const dateValue = new Date(`${this.selectedDate}T00:00:00`);
        if (this.activeView === 'day') {
            return new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }).format(dateValue);
        }
        return new Intl.DateTimeFormat('en-US', { month: 'long', year: 'numeric' }).format(dateValue);
    }
    get pageClass() {
        return `schedule-page view-${this.activeView}`;
    }
    get isOnlineMode() {
        return this.meetMode === 'online';
    }
    get isInPersonMode() {
        return this.meetMode === 'inPerson';
    }
    get meetLinkPlaceholder() {
        return this.isOnlineMode ? 'Enter meet link (optional)' : 'In-person meeting selected';
    }

    renderedCallback() {
        if (this.calendarLoaded) return;
        this.calendarLoaded = true;
        this.loadResourcesSequentially()
            .then(() => this.waitForDependenciesWithTimeout())
            .catch(() => {
                this.hasLibraryError = true;
            });
        this.loadScheduleEvents();
    }

    disconnectedCallback() {
        const host = this.template.querySelector('.calendar-root');
        if (host && window.$ && window.$.fn && typeof window.$.fn.fullCalendar === 'function') {
            window.$(host).fullCalendar('destroy');
        }
        if (this.successModalTimer) {
            clearTimeout(this.successModalTimer);
            this.successModalTimer = null;
        }
    }

    async loadResourcesSequentially() {
        const loaded = await this.loadLegacyBundle('/fullCalendarV3');
        if (loaded) return;
        await this.loadLegacyBundle('');
    }

    async loadLegacyBundle(basePath) {
        const prefix = `${FullCalendarJSFromResource}${basePath}`;
        try {
            await loadScript(this, `${prefix}/lib/jquery.min.js`);
            if (window.jQuery) window.$ = window.jQuery;
            if (!window.jQuery && window.$) window.jQuery = window.$;
            await loadStyle(this, `${prefix}/fullcalendar.css`);
            await loadScript(this, `${prefix}/lib/moment.min.js`);
            await loadScript(this, `${prefix}/fullcalendar.js`);
            return true;
        } catch (error) {
            if (basePath) return false;
            throw error;
        }
    }

    waitForDependenciesWithTimeout() {
        let attempts = 0;
        const maxAttempts = 30;
        const checkDependencies = () => {
            attempts += 1;
            const jQueryReady = typeof window.$ !== 'undefined' && window.$ && typeof window.$.fn === 'object';
            const fullCalendarReady = jQueryReady && typeof window.$.fn.fullCalendar === 'function';
            const momentReady = typeof window.moment !== 'undefined' && window.moment;
            if (fullCalendarReady && momentReady) {
                setTimeout(() => this.initializeCalendar(), 80);
            } else if (attempts >= maxAttempts) {
                this.hasLibraryError = true;
            } else {
                setTimeout(checkDependencies, 200);
            }
        };
        checkDependencies();
    }

    initializeCalendar() {
        const host = this.template.querySelector('.calendar-root');
        if (!host || !window.$ || !window.$.fn || typeof window.$.fn.fullCalendar !== 'function') {
            this.hasLibraryError = true;
            return;
        }

        this.injectCalendarOverrides(host);
        window.$(host).fullCalendar({
            defaultDate: this.selectedDate,
            defaultView: 'agendaDay',
            header: false,
            allDaySlot: false,
            firstDay: 1,
            minTime: '09:00:00',
            maxTime: '16:00:00',
            slotDuration: '00:30:00',
            slotLabelInterval: '01:00:00',
            axisFormat: 'HH:mm',
            editable: false,
            selectable: false,
            eventOverlap: true,
            eventLimit: true,
            events: this.getEvents(),
            eventRender: (event, element, view) => {
                const eventLike = {
                    title: event.title,
                    extendedProps: {
                        subtitle: event.subtitle,
                        footer: event.footer,
                        location: event.location,
                        variant: event.variant,
                        range: event.range
                    }
                };
                element.html(this.getEventMarkup(eventLike, view.name));
                return element;
            }
        });
        this.calendarInitialized = true;
        this.refreshCalendarEvents();
    }

    async handleViewChange(event) {
        const view = event.currentTarget.dataset.view;
        if (!view) return;

        if (view === 'day' && this.scheduleEvents.length) {
            const hasEventOnSelectedDate = this.scheduleEvents.some((item) => {
                const eventDate = (item.startDateTime || '').slice(0, 10);
                return eventDate === this.selectedDate;
            });
            if (!hasEventOnSelectedDate) {
                this.selectedDate = (this.scheduleEvents[0].startDateTime || this.selectedDate).slice(0, 10);
            }
        }

        this.activeView = view;
        const host = this.template.querySelector('.calendar-root');
        if (host && window.$ && window.$.fn && typeof window.$.fn.fullCalendar === 'function') {
            const legacyView = view === 'day' ? 'agendaDay' : view === 'week' ? 'agendaWeek' : 'month';
            window.$(host).fullCalendar('changeView', legacyView);
            window.$(host).fullCalendar('gotoDate', this.selectedDate);
        }
        await this.loadScheduleEvents();
    }

    async handleDateChange(event) {
        this.selectedDate = event.target.value || this.selectedDate;
        const host = this.template.querySelector('.calendar-root');
        if (host && window.$ && window.$.fn && typeof window.$.fn.fullCalendar === 'function') {
            window.$(host).fullCalendar('gotoDate', this.selectedDate);
        }
        await this.loadScheduleEvents();
    }

    openScheduleCallModal() {
        this.isScheduleCallModalOpen = true;
    }

    closeScheduleCallModal() {
        this.isScheduleCallModalOpen = false;
    }

    handleMeetModeChange(event) {
        this.meetMode = event.target.value;
    }

    sendScheduleRequest() {
        this.isScheduleCallModalOpen = false;
        this.isCallRequestedModalOpen = true;

        if (this.successModalTimer) {
            clearTimeout(this.successModalTimer);
        }

        this.successModalTimer = setTimeout(() => {
            this.isCallRequestedModalOpen = false;
            this.successModalTimer = null;
        }, 1800);
    }

    navigateToAttendanceSummary() {
        const pageReference = {
            type: 'standard__webPage',
            attributes: {
                url: '/attendance/attendance-summary'
            }
        };

        try {
            this[NavigationMixin.Navigate](pageReference);
        } catch (error) {
            window.location.assign('/attendance/attendance-summary');
        }
    }

    getEvents() {
        return (this.scheduleEvents || []).map((item) => ({
            id: item.id,
            title: item.title,
            start: item.startDateTime,
            end: item.endDateTime,
            subtitle: item.subtitle,
            footer: item.footer,
            location: item.location,
            variant: item.variant,
            hexColor: item.hexColor,
            range: this.toDisplayRange(item.startDateTime, item.endDateTime)
        }));
    }

    toDisplayRange(startIso, endIso) {
        const startValue = new Date(startIso);
        const endValue = new Date(endIso);
        const formatter = new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
        return `${formatter.format(startValue)} - ${formatter.format(endValue)}`;
    }

    getEventMarkup(event, viewName) {
        const subtitle = event.extendedProps.subtitle || '';
        const footer = event.extendedProps.footer || '';
        const location = event.extendedProps.location || '';
        const range = event.extendedProps.range || '';
        const variant = event.extendedProps.variant || 'blue';
        const hexColor = event.extendedProps.hexColor || '';
        const palette = {
            blue: { bg: '#dfe7f4', border: '#2f6fff' },
            green: { bg: '#dcece8', border: '#0fb985' },
            yellow: { bg: '#f9efd2', border: '#e4ad2b' },
            purple: { bg: '#e8e5f3', border: '#8157f5' },
            neutral: { bg: '#e9edf1', border: '#8f939d' }
        };
        const style = hexColor
            ? { bg: this.toTintColor(hexColor), border: hexColor }
            : (palette[variant] || palette.blue);

        if (viewName === 'month') {
            return `<div style="background:${style.bg};border-radius:6px;padding:2px 8px;font-size:12px;line-height:1.2;color:#3a404b;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${event.title}</div>`;
        }

        if (viewName === 'agendaWeek') {
            return `<div style="height:100%;background:${style.bg};padding:10px 12px;font-size:12px;line-height:1.3;color:#313844;box-sizing:border-box;overflow:hidden;"><div style="font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${event.title}</div>${subtitle ? `<div style="margin-top:6px;color:#4f5868;">${subtitle}</div>` : ''}${footer ? `<div style="margin-top:8px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${footer}</div>` : ''}</div>`;
        }

        const isLunch = variant === 'neutral';
        const leftContent = isLunch
            ? `<div style="font-style:italic;font-weight:600;">${event.title}</div>`
            : `<div style="font-weight:600;">${event.title}</div>${subtitle ? `<div style="margin-top:8px;color:#4f5868;">${subtitle}</div>` : ''}${footer ? `<div style="margin-top:6px;color:#303744;">${footer}</div>` : ''}`;
        const rightText = `${range}${location ? ` • ${location}` : ''}`;
        return `<div style="height:100%;display:flex;align-items:flex-start;justify-content:space-between;gap:12px;border-left:3px solid ${style.border};background:${style.bg};border-radius:12px;padding:14px;color:#2f3542;box-sizing:border-box;font-size:12px;line-height:1.35;"><div>${leftContent}</div><div style="white-space:nowrap;color:#2c313d;">${rightText}</div></div>`;
    }

    injectCalendarOverrides(host) {
        const styleTag = document.createElement('style');
        styleTag.textContent = `
            .fc { font-family: 'Inter', 'Segoe UI', sans-serif; }
            .fc .fc-toolbar { display: none; }
            .fc .fc-day-header { font-size: 18px; color: #383f4b; font-weight: 500; padding: 12px 0; background: #f8f9fb; }
            .fc .fc-axis, .fc .fc-time { color: #777f8d; font-size: 12px; font-weight: 500; }
            .fc .fc-axis { width: 72px !important; }
            .fc .fc-widget-content, .fc td, .fc th, .fc .fc-slats td { border-color: #d4d9e2; }
            .fc-agendaDay-view .fc-time-grid .fc-slats td { height: 52px; }
            .fc-agendaWeek-view .fc-time-grid .fc-slats td { height: 44px; }
            .fc-event { border: 0 !important; background: transparent !important; box-shadow: none !important; }
            .fc-event .fc-time, .fc-event .fc-title { display: none !important; }
            .fc .fc-content-skeleton td, .fc .fc-content-skeleton th { border: 0 !important; }
            .fc-month-view .fc-day-grid .fc-row { min-height: 150px; }
            .fc-day-grid-event { margin: 2px 6px !important; border-radius: 6px !important; }
            .fc-more { color: #323946 !important; font-size: 12px; font-weight: 600; margin-left: 8px; text-decoration: none; }
            .fc-agendaDay-view .fc-time-grid .fc-event-container { margin: 0 12px 0 8px; }
            .fc-agendaWeek-view .fc-time-grid .fc-event-container { margin: 0 6px; }
            .fc-agendaDay-view .fc-time-grid .fc-slats .fc-minor td { border-top-style: none; }
            .fc-agendaWeek-view .fc-time-grid .fc-slats .fc-minor td { border-top-style: none; }
            .fc-agendaDay-view .fc-axis, .fc-agendaDay-view .fc-time { color: #444b57; font-size: 12px; }
            .fc-agendaDay-view .fc-widget-content { background: #ffffff; }
            .fc-agendaWeek-view .fc-time-grid .fc-widget-content { background: #ffffff; }
            .fc-agendaWeek-view .fc-time-grid .fc-event {
                min-height: 46px;
            }
            .fc-agendaWeek-view .fc-time-grid .fc-content-skeleton .fc-event-container {
                z-index: 4;
            }
            @media (max-width: 768px) {
                .fc-view-container {
                    overflow-x: auto;
                    overflow-y: hidden;
                    -webkit-overflow-scrolling: touch;
                }
                .fc-agendaWeek-view,
                .fc-month-view {
                    min-width: 860px;
                }
                .fc-month-view > table,
                .fc-agendaWeek-view > table,
                .fc-agendaWeek-view .fc-time-grid {
                    min-width: 860px;
                }
                .fc .fc-day-header {
                    font-size: 14px;
                    padding: 10px 0;
                }
                .fc .fc-axis,
                .fc .fc-time {
                    font-size: 11px;
                }
                .fc .fc-axis {
                    width: 56px !important;
                }
                .fc-agendaWeek-view .fc-time-grid .fc-slats td {
                    height: 40px;
                }
                .fc-agendaWeek-view .fc-event {
                    font-size: 11px;
                }
            }
            @media (max-width: 480px) {
                .fc-agendaWeek-view,
                .fc-month-view,
                .fc-month-view > table,
                .fc-agendaWeek-view > table,
                .fc-agendaWeek-view .fc-time-grid {
                    min-width: 920px;
                }
            }
        `;
        host.appendChild(styleTag);
    }

    async loadScheduleEvents() {
        try {
            const result = await getStudentCalendarEvents({
                referenceDateIso: this.selectedDate,
                viewMode: this.activeView
            });
            this.scheduleEvents = result || [];
            this.refreshCalendarEvents();
        } catch (error) {
            this.scheduleEvents = [];
            this.refreshCalendarEvents();
            // keep calendar usable even if schedule load fails
            // eslint-disable-next-line no-console
            console.error('Failed to load student schedule events', error);
        }
    }

    refreshCalendarEvents() {
        const host = this.template.querySelector('.calendar-root');
        if (!this.calendarInitialized || !host || !window.$ || !window.$.fn || typeof window.$.fn.fullCalendar !== 'function') {
            return;
        }
        const calendar = window.$(host);
        calendar.fullCalendar('removeEvents');
        calendar.fullCalendar('addEventSource', this.getEvents());
        calendar.fullCalendar('gotoDate', this.selectedDate);
        calendar.fullCalendar('rerenderEvents');
    }

    toTintColor(hexColor) {
        const normalized = String(hexColor || '').replace('#', '');
        if (!/^[0-9a-fA-F]{6}$/.test(normalized)) {
            return '#dfe7f4';
        }
        const red = parseInt(normalized.slice(0, 2), 16);
        const green = parseInt(normalized.slice(2, 4), 16);
        const blue = parseInt(normalized.slice(4, 6), 16);
        const mix = (channel) => Math.round(channel + (255 - channel) * 0.82);
        return `rgb(${mix(red)}, ${mix(green)}, ${mix(blue)})`;
    }
}