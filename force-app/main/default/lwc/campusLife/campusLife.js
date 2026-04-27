import { LightningElement, wire, track } from 'lwc';
import { campusLifeData } from 'c/mockData';
import SP_IMAGES from '@salesforce/resourceUrl/StudentPortalImages';
import getCampusOverview from '@salesforce/apex/KenCampusLifeController.getCampusOverview';

const IMG = (p) => (SP_IMAGES ? `${SP_IMAGES}/${p}` : p);

export default class CampusLife extends LightningElement {
    roommateAvatars = [
        IMG('images/avatars/avatar2.jpg'),
        IMG('images/avatars/avatar5.jpg'),
        IMG('images/avatars/avatar6.jpg')
    ];
    @track _apex;
    // Seed fallback retained for template bindings.
    _seed = campusLifeData;

    @wire(getCampusOverview)
    wiredCampus({ data, error }) {
        if (data) this._apex = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.warn('[campusLife] Apex failed, using seed:', error);
        }
    }

    get data() {
        // Merge Apex overview fields (shortcuts, announcements) onto the seed so that
        // template bindings that rely on legacy fields (clubs, gatePass, hostel, mess,
        // featuredEvents) continue to resolve while newer fields come from Apex.
        if (this._apex) {
            return Object.assign({}, this._seed, this._apex);
        }
        return this._seed;
    }

    get formattedEvents() {
        const images = [
            'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=320&h=200&fit=crop',
            'https://images.unsplash.com/photo-1517048676732-d65bc937f952?w=320&h=200&fit=crop'
        ];
        return (this.data.featuredEvents || []).map((e, i) => ({
            ...e,
            imgUrl: images[i % images.length]
        }));
    }

    navigateTo(route) { this.dispatchEvent(new CustomEvent('navigate', { detail: { route } })); }
    handleEvents() { this.navigateTo('events'); }
    handleClubs() { this.navigateTo('clubs'); }
    handleGatePass() { this.navigateTo('gate-pass'); }
    handleCreateGatePass() { this.navigateTo('create-gate-pass'); }
    handleHostel() { this.navigateTo('hostel-details'); }
    handleMess() { this.navigateTo('mess-menu'); }
    handleLibrary() { this.navigateTo('library'); }
}