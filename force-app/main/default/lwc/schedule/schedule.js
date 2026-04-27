import { LightningElement, wire, track } from 'lwc';
import { scheduleData } from 'c/mockData';
import getWeeklySchedule from '@salesforce/apex/KenScheduleController.getWeeklySchedule';

const HOUR_PX = 60;
const START_HOUR = 8;

const BG = {
    blue: 'event-blue', green: 'event-green', amber: 'event-amber',
    violet: 'event-violet', sky: 'event-sky', rose: 'event-rose'
};

function parseTime(str) {
    const clean = (str || '').trim();
    const match = clean.match(/^(\d+):(\d+)\s*(AM|PM)$/i);
    if (!match) return 0;
    let h = parseInt(match[1], 10);
    const m = parseInt(match[2], 10);
    const meridian = match[3].toUpperCase();
    if (meridian === 'PM' && h !== 12) h += 12;
    if (meridian === 'AM' && h === 12) h = 0;
    return h * 60 + m;
}

export default class Schedule extends LightningElement {
    @track _tick = 0;
    @track _apex;
    _timer = null;

    @wire(getWeeklySchedule)
    wiredSchedule({ data, error }) {
        if (data) this._apex = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[schedule] Apex failed, using seed:', error);
        }
    }

    get effectiveSchedule() {
        if (this._apex && this._apex.length) return this._apex;
        return scheduleData;
    }

    get currentDate() {
        return new Date().toLocaleDateString('en-US', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
    }

    get timeSlots() {
        const slots = [];
        for (let h = START_HOUR; h <= 17; h++) {
            const suffix = h >= 12 ? 'PM' : 'AM';
            const display = h > 12 ? h - 12 : h;
            slots.push({ key: 'ts-' + h, label: display + ':00 ' + suffix });
        }
        return slots;
    }

    get formattedEvents() {
        return this.effectiveSchedule.map(e => {
            const startMin = parseTime(e.startTime);
            const endMin = parseTime(e.endTime);
            const durationMin = endMin - startMin;
            const topPx = (startMin - START_HOUR * 60) + 8;
            const heightPx = Math.max(48, durationMin);
            const colorClass = BG[e.color] || 'event-blue';
            const blockStyle = 'top:' + topPx + 'px;height:' + heightPx + 'px;';
            return {
                ...e,
                blockStyle,
                colorClass,
                blockClass: 'event-block ' + colorClass
            };
        });
    }

    get currentTimeStyle() {
        const now = new Date();
        const totalMin = now.getHours() * 60 + now.getMinutes();
        const offsetMin = totalMin - START_HOUR * 60;
        if (offsetMin < 0 || offsetMin > (17 - START_HOUR) * 60) return 'display:none';
        return 'top:' + (offsetMin + 8) + 'px;';
    }

    connectedCallback() {
        this._timer = setInterval(() => { this._tick += 1; }, 60000);
    }

    disconnectedCallback() {
        if (this._timer) { clearInterval(this._timer); this._timer = null; }
    }
}