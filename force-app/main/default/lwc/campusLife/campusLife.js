import { LightningElement, wire, track } from 'lwc';
import SP_IMAGES from '@salesforce/resourceUrl/StudentPortalImages';
import getEventsBundle from '@salesforce/apex/KenEventsController.getEventsBundle';
import getClubs from '@salesforce/apex/KenClubsController.getClubs';
import getGatePasses from '@salesforce/apex/KenGatePassController.getGatePasses';
import getHostelDetails from '@salesforce/apex/KenHostelDetailsController.getHostelDetails';
import getWeeklyMenu from '@salesforce/apex/KenMessMenuController.getWeeklyMenu';

const IMG = (p) => (SP_IMAGES ? `${SP_IMAGES}/${p}` : p);

export default class CampusLife extends LightningElement {
    roommateAvatars = [
        IMG('images/avatars/avatar2.jpg'),
        IMG('images/avatars/avatar5.jpg'),
        IMG('images/avatars/avatar6.jpg')
    ];

    @track _events;
    @track _clubs;
    @track _gatePasses;
    @track _hostel;
    @track _mess;

    @wire(getEventsBundle)
    wiredEvents({ data }) { if (data) this._events = data; }

    @wire(getClubs, { category: null })
    wiredClubs({ data }) { if (data) this._clubs = data; }

    @wire(getGatePasses)
    wiredGatePasses({ data }) { if (data) this._gatePasses = data; }

    @wire(getHostelDetails)
    wiredHostel({ data }) { if (data) this._hostel = data; }

    @wire(getWeeklyMenu)
    wiredMess({ data }) { if (data) this._mess = data; }

    // ── Featured events ────────────────────────────────────────────
    get formattedEvents() {
        const images = [
            'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=320&h=200&fit=crop',
            'https://images.unsplash.com/photo-1517048676732-d65bc937f952?w=320&h=200&fit=crop',
            'https://images.unsplash.com/photo-1505373877841-8d25f7d46678?w=320&h=200&fit=crop'
        ];
        const src = (this._events && (this._events.featured && this._events.featured.length
            ? this._events.featured
            : this._events.upcoming)) || [];
        return src.slice(0, 3).map((e, i) => ({
            id: e.id,
            title: e.title,
            type: e.type,
            mode: e.mode,
            date: e.dateLabel || e.eventDate,
            time: e.timeLabel || e.eventTime,
            imgUrl: e.imageUrl || images[i % images.length]
        }));
    }
    get hasEvents() { return this.formattedEvents.length > 0; }

    // ── Clubs ──────────────────────────────────────────────────────
    get clubsList() {
        const list = (this._clubs || []).filter(c => !c.isJoined).slice(0, 4);
        return list.map(c => ({
            id: c.id,
            name: c.name,
            thumb: c.imageUrl || IMG('images/clubs/default.jpg')
        }));
    }
    get hasClubs() { return this.clubsList.length > 0; }

    // ── Gate Pass counts ──────────────────────────────────────────
    get gatePassCounts() {
        const list = this._gatePasses || [];
        const now = Date.now();
        let active = 0, expired = 0, upcoming = 0, notUsed = 0;
        list.forEach(g => {
            const status = (g.status || '').toLowerCase();
            const out = g.outDateTime ? Date.parse(g.outDateTime) : null;
            const ret = g.returnDateTime ? Date.parse(g.returnDateTime) : null;
            if (status === 'approved' && out && ret && out <= now && now <= ret) active++;
            else if (status === 'completed' || (ret && ret < now)) expired++;
            else if (status === 'approved' && out && out > now) upcoming++;
            else if (status === 'pending') notUsed++;
        });
        return { active, expired, upcoming, notUsed };
    }
    get hasGatePassData() { return (this._gatePasses || []).length > 0; }

    // ── Hostel ────────────────────────────────────────────────────
    get hostel() {
        const h = this._hostel || {};
        return {
            roomNo: h.roomNumber || '—',
            type: h.type || '—',
            building: [h.block, h.floor].filter(Boolean).join(', ') || '—',
            warden: { name: h.wardenName || '—', email: h.wardenPhone || '—' }
        };
    }
    get hasHostel() { return !!(this._hostel && this._hostel.roomNumber); }

    // ── Mess ──────────────────────────────────────────────────────
    get messMeals() {
        const today = (this._mess || [])[0];
        const meals = (today && today.meals) || [];
        const find = (t) => {
            const m = meals.find(x => (x.mealType || '').toLowerCase() === t);
            return { time: (m && m.timing) || '—' };
        };
        return {
            breakfast: find('breakfast'),
            lunch: find('lunch'),
            snacks: find('snacks'),
            dinner: find('dinner')
        };
    }
    get hasMess() { return (this._mess || []).length > 0; }

    // ── Navigation ────────────────────────────────────────────────
    navigateTo(route) {
        try {
            const parts = window.location.pathname.split('/').filter(Boolean);
            const base = parts[0] || 'newportal';
            const target = route === 'home' ? `/${base}/` : `/${base}/${route}`;
            window.location.href = target;
        } catch (e) {
            this.dispatchEvent(new CustomEvent('navigate', { detail: { route } }));
        }
    }
    handleEvents() { this.navigateTo('events'); }
    handleClubs() { this.navigateTo('clubs'); }
    handleGatePass() { this.navigateTo('gate-pass'); }
    handleCreateGatePass() { this.navigateTo('create-gate-pass'); }
    handleHostel() { this.navigateTo('hostel-details'); }
    handleMess() { this.navigateTo('mess-menu'); }
    handleLibrary() { this.navigateTo('library'); }
}