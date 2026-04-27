import { LightningElement, wire, track } from 'lwc';
import { scheduleData } from 'c/mockData';
import getWeeklySchedule from '@salesforce/apex/KenScheduleController.getWeeklySchedule';

const SLOT_MIN     = 30;            // each grid row = 30 minutes
const START_HOUR   = 8;             // first row at 08:00
const END_HOUR     = 18;            // last row at 18:00
const ROWS         = ((END_HOUR - START_HOUR) * 60) / SLOT_MIN; // 20 rows

const COLOR_CLASSES = {
    blue: 'event-blue', green: 'event-green', amber: 'event-amber',
    violet: 'event-violet', sky: 'event-sky', rose: 'event-rose'
};

function parseTime(str) {
    const m = String(str || '').trim().match(/^(\d+):(\d+)\s*(AM|PM)$/i);
    if (!m) return 0;
    let h = parseInt(m[1], 10);
    const mins = parseInt(m[2], 10);
    const meri = m[3].toUpperCase();
    if (meri === 'PM' && h !== 12) h += 12;
    if (meri === 'AM' && h === 12) h = 0;
    return h * 60 + mins;
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
        return new Date().toLocaleDateString('en-US', {
            weekday: 'long', day: 'numeric', month: 'long', year: 'numeric'
        });
    }

    /** Time labels rendered on the left rail — one per hour. */
    get timeSlots() {
        const slots = [];
        for (let h = START_HOUR; h <= END_HOUR; h++) {
            const suffix = h >= 12 ? 'PM' : 'AM';
            const display = h > 12 ? h - 12 : h;
            slots.push({ key: 'ts-' + h, label: display + ':00 ' + suffix });
        }
        return slots;
    }

    /** Grid row count (used by CSS Grid template inline). */
    get gridRowsStyle() {
        return '--rows:' + ROWS + ';';
    }

    /**
     * Computes one block per event with:
     *   gridRowStart   — 1-indexed grid row (each row = 30 min).
     *   gridRowSpan    — how many rows the event spans.
     *   gridColumnStart — lane index (1-indexed) within an overlap cluster.
     *   laneCount       — total lanes in the cluster (so CSS can split width evenly).
     *
     * Uses CSS variables so the grid layout is driven entirely by CSS — no
     * inline top/left/height/width pixel values.
     */
    get formattedEvents() {
        const events = (this.effectiveSchedule || []).map((e, idx) => {
            const startMin    = parseTime(e.startTime);
            const endMin      = parseTime(e.endTime);
            const durationMin = Math.max(SLOT_MIN, endMin - startMin);
            return { raw: e, idx, startMin, endMin, durationMin };
        }).sort((a, b) => a.startMin - b.startMin || a.endMin - b.endMin);

        // Greedy lane assignment, grouped by overlap clusters.
        const clusters = [];
        let current = null;
        events.forEach(ev => {
            if (!current || ev.startMin >= current.maxEnd) {
                current = { items: [], laneEnds: [], maxEnd: ev.endMin };
                clusters.push(current);
            }
            let lane = current.laneEnds.findIndex(end => end <= ev.startMin);
            if (lane === -1) {
                lane = current.laneEnds.length;
                current.laneEnds.push(ev.endMin);
            } else {
                current.laneEnds[lane] = ev.endMin;
            }
            ev.lane = lane;
            current.items.push(ev);
            if (ev.endMin > current.maxEnd) current.maxEnd = ev.endMin;
        });

        const out = [];
        clusters.forEach(cluster => {
            const laneCount = cluster.laneEnds.length;
            cluster.items.forEach(ev => {
                const e = ev.raw;
                const startRow = Math.max(
                    1,
                    Math.floor((ev.startMin - START_HOUR * 60) / SLOT_MIN) + 1
                );
                const rowSpan = Math.max(
                    1,
                    Math.ceil(ev.durationMin / SLOT_MIN)
                );
                const colorClass = COLOR_CLASSES[e.color] || 'event-blue';
                const blockStyle =
                    '--row-start:' + startRow + ';' +
                    '--row-span:' + rowSpan + ';' +
                    '--lane:' + (ev.lane + 1) + ';' +
                    '--lane-count:' + laneCount + ';';
                out.push({
                    ...e,
                    key: e.id || ('ev-' + ev.idx),
                    blockStyle,
                    colorClass,
                    blockClass: 'event-block ' + colorClass
                });
            });
        });
        return out;
    }

    /** Inline style for the red "now" line — also expressed in grid rows. */
    get currentTimeStyle() {
        const now = new Date();
        const totalMin = now.getHours() * 60 + now.getMinutes();
        const offsetMin = totalMin - START_HOUR * 60;
        if (offsetMin < 0 || offsetMin > (END_HOUR - START_HOUR) * 60) {
            return 'display:none;';
        }
        // Place the bar between rows by using a fractional grid-row.
        const fractionalRow = (offsetMin / SLOT_MIN) + 1;
        return '--now-row:' + fractionalRow.toFixed(3) + ';';
    }

    connectedCallback() {
        this._timer = setInterval(() => { this._tick += 1; }, 60000);
    }
    disconnectedCallback() {
        if (this._timer) { clearInterval(this._timer); this._timer = null; }
    }
}