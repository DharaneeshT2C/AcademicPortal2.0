import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import SP_IMAGES from '@salesforce/resourceUrl/StudentPortalImages';
import getClubs from '@salesforce/apex/KenClubsController.getClubs';
import expressInterest from '@salesforce/apex/KenClubsController.expressInterest';
import createClubApex from '@salesforce/apex/KenClubsController.createClub';

const IMG = (p) => (SP_IMAGES ? `${SP_IMAGES}/${p}` : p);

const CLUB_DESCRIPTIONS = {
    'DC001': 'Celebrating arts, traditions and cultural events across all regions of the country.',
    'DC002': 'Create, screen and discuss short films. Open to all skill levels — beginners welcome.',
    'DC003': 'Photography walks, workshops, and exhibitions throughout the academic year.',
    'DC004': 'Explore data science, ML, and AI through hands-on projects and competitions.',
    'DC005': 'Make a difference in the community through organized volunteer work and drives.',
    'DC006': 'Weekly runs, 5K races, and fitness challenges for all levels of runners.',
    'DC007': 'Organizing regular blood donation drives across the campus and local community.',
    'DC008': 'Cultural events, fests and performances celebrating diversity.',
    'DC009': 'Film screenings, critiques, and production workshops for cinema lovers.'
};

const MOCK_MEMBERS = [
    { id: 1, initial: 'A', cls: 'av-indigo' },
    { id: 2, initial: 'P', cls: 'av-emerald' },
    { id: 3, initial: 'K', cls: 'av-violet' }
];

export default class Clubs extends LightningElement {
    friendAvatarsA = [IMG('images/avatars/avatar2.jpg'), IMG('images/avatars/avatar5.jpg'), IMG('images/avatars/avatar6.jpg')];
    friendAvatarsB = [IMG('images/avatars/avatar3.jpg'), IMG('images/avatars/avatar4.jpg'), IMG('images/avatars/avatar7.jpg')];

    @track showToast = false;
    @track toastMessage = '';
    @track toastVariant = 'success';

    @track showCreateModal = false;
    @track showFilterPanel = false;
    @track showClubDetail = false;

    @track joinedClubs = [];
    @track createdClubs = [];

    @track searchText = '';
    @track filterCategory = '';
    @track sortBy = 'popular';

    @track detailClub = null;

    @track newClubName = '';
    @track newClubCategory = 'Cultural';
    @track newClubDescription = '';
    @track newClubPrivacy = 'Public';

    @track carouselOffset = 0;

    @track _apex;
    @track _wireClubsResp;

    @wire(getClubs, { category: '$filterCategory' })
    wiredClubs(response) {
        this._wireClubsResp = response;
        const { data, error } = response;
        if (data) this._apex = data;
        else if (error) {
            const _msg = (error && error.body && error.body.message) || '';
            if (_msg && !_msg.includes('not have access') && !_msg.includes('No rows')) {
                // eslint-disable-next-line no-console
                console.warn('[clubs] Apex failed, using seed:', error);
            }
        }
    }

    _toast(msg, variant) {
        this.toastMessage = msg;
        this.toastVariant = variant || 'success';
        this.showToast = true;
    }

    handleToastClose() { this.showToast = false; }

    navigateTo(route) { this.dispatchEvent(new CustomEvent('navigate', { detail: { route } })); }
    handleBack() { this.navigateTo('campus-life'); }

    _clubImg(c) {
        const provided = c.image || c.imageUrl;
        if (provided) return provided;
        const base = SP_IMAGES || '';
        const n = (c.name || '').toLowerCase();
        const cat = (c.category || '').toLowerCase();
        let file = 'cultural.jpg';
        if (n.includes('cod') || n.includes('tech') || n.includes('robot')) file = 'robotics.jpg';
        else if (n.includes('film') || n.includes('movie')) file = 'film.jpg';
        else if (n.includes('photo')) file = 'photography.jpg';
        else if (n.includes('debate') || n.includes('mun')) file = 'debate.jpg';
        else if (n.includes('data') || n.includes('analytic')) file = 'datascience.jpg';
        else if (n.includes('blood') || n.includes('volunteer')) file = 'blooddonation.jpg';
        else if (cat === 'sports' || n.includes('run') || n.includes('sport')) file = 'robotics.jpg';
        else if (cat === 'cultural' || n.includes('cultur') || n.includes('art')) file = 'cultural.jpg';
        return base + '/images/clubs/' + file;
    }

    get allClubs() {
        const source = (this._apex && this._apex.length) ? this._apex : [];
        return source.map(c => {
            // Apex DTOs don't carry a `suggested` flag — derive it from
            // isJoined so non-joined real clubs appear in the carousel.
            const suggested = (c.suggested === true) || !c.isJoined;
            return Object.assign({}, c, {
                description: c.description || CLUB_DESCRIPTIONS[c.id] || 'Join this club to connect with fellow students.',
                image: this._clubImg(c),
                suggested
            });
        });
    }

    /**
     * Right-rail "Clubs Joined" panel. Sourced from Apex `isJoined=true`
     * so refreshing the page doesn't wipe state. Falls back to the local
     * @track array (used during the optimistic-add flow).
     */
    get effectiveJoinedClubs() {
        const fromApex = !!(this._apex && this._apex.length);
        if (fromApex) {
            return this._apex
                .filter(c => c.isJoined)
                .map(c => Object.assign({}, c, { image: this._clubImg(c) }));
        }
        return this.joinedClubs;
    }
    get hasJoinedClubsApex() { return this.effectiveJoinedClubs.length > 0; }

    get discoverClubs() {
        let clubs = this.allClubs.filter(c => !c.isPrivate);
        const search = (this.searchText || '').toLowerCase().trim();
        if (search) {
            clubs = clubs.filter(c => (c.name || '').toLowerCase().includes(search));
        }
        // Filter by `category` field (not by name). Empty string / "All" = no filter.
        if (this.filterCategory && this.filterCategory !== 'All') {
            const cat = this.filterCategory.toLowerCase();
            clubs = clubs.filter(c => (c.category || '').toLowerCase() === cat);
        }
        return clubs;
    }

    get suggested() {
        let clubs = this.allClubs.filter(c => c.suggested);
        const search = this.searchText.toLowerCase().trim();
        if (search) {
            clubs = clubs.filter(c => c.name.toLowerCase().includes(search));
        }
        return clubs;
    }

    get suggestedCount() {
        const count = this.suggested.length;
        return count < 10 ? '0' + count : String(count);
    }

    get privateClubs() { return this.allClubs.filter(c => c.isPrivate); }
    get hasPrivate() { return this.privateClubs.length > 0; }

    get hasJoinedClubs() { return this.joinedClubs.length > 0; }
    get hasCreatedClubs() { return this.createdClubs.length > 0; }

    get carouselStyle() {
        const offset = this.carouselOffset * 206;
        return 'transform: translateX(-' + offset + 'px); transition: transform 0.35s cubic-bezier(0.4,0,0.2,1);';
    }

    get maxCarousel() { return Math.max(0, this.suggested.length - 2); }
    get isCarouselAtStart() { return this.carouselOffset <= 0; }
    get isCarouselAtEnd() { return this.carouselOffset >= this.maxCarousel; }

    get prevBtnClass() {
        if (this.isCarouselAtStart) { return 'nav-btn nav-btn-disabled'; }
        return 'nav-btn';
    }
    get nextBtnClass() {
        if (this.isCarouselAtEnd) { return 'nav-btn nav-btn-disabled'; }
        return 'nav-btn';
    }

    get detailMembers() { return MOCK_MEMBERS; }

    get detailClubName() {
        if (this.detailClub) { return this.detailClub.name; }
        return '';
    }
    get detailClubDesc() {
        if (this.detailClub) { return this.detailClub.description; }
        return '';
    }
    get detailClubMembers() {
        if (this.detailClub) { return this.detailClub.members; }
        return '';
    }
    get detailClubImage() {
        if (this.detailClub) { return this.detailClub.image; }
        return '';
    }
    get detailAlreadyJoined() {
        if (this.detailClub) {
            const id = this.detailClub.id;
            return this.joinedClubs.some(c => c.id === id);
        }
        return false;
    }
    get joinBtnLabel() {
        if (this.detailAlreadyJoined) { return 'Already Joined'; }
        return 'Join Club';
    }
    get joinBtnClass() {
        if (this.detailAlreadyJoined) { return 'btn-join-done'; }
        return 'btn-join';
    }

    get filterBtnClass() {
        if (this.showFilterPanel) { return 'btn-filter btn-filter-active'; }
        return 'btn-filter';
    }

    handleSearch(event) { this.searchText = event.target.value; }
    handleFilterToggle() { this.showFilterPanel = !this.showFilterPanel; }
    handleCategoryFilter(event) { this.filterCategory = event.target.value; }
    handleSortChange(event) { this.sortBy = event.target.value; }
    handleApplyFilter() { this.showFilterPanel = false; this._toast('Filters applied!', 'info'); }
    handleResetFilter() {
        this.filterCategory = '';
        this.sortBy = 'popular';
        this.showFilterPanel = false;
    }

    handleClubClick(event) {
        const id = event.currentTarget.dataset.id;
        const club = this.allClubs.find(c => c.id === id);
        if (club) {
            this.detailClub = Object.assign({}, club);
            this.showClubDetail = true;
        }
    }
    handleCloseDetail() { this.showClubDetail = false; this.detailClub = null; }
    handleJoinClub() {
        if (!this.detailClub) return;
        const already = this.joinedClubs.some(c => c.id === this.detailClub.id);
        if (already) {
            this.showClubDetail = false; this.detailClub = null; return;
        }
        const clubId = this.detailClub.id;
        const clubName = this.detailClub.name;
        const optimisticEntry = Object.assign({}, this.detailClub);
        // Optimistic update: add to joined list immediately for snappy UI.
        this.joinedClubs = [...this.joinedClubs, optimisticEntry];
        this.showClubDetail = false; this.detailClub = null;
        expressInterest({ clubId })
            .then(() => {
                this._toast('You joined ' + clubName + '!', 'success');
                if (this._wireClubsResp) refreshApex(this._wireClubsResp);
            })
            .catch(err => {
                // Rollback the optimistic entry and show the real error.
                this.joinedClubs = this.joinedClubs.filter(c => c.id !== clubId);
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not join the club.';
                this._toast(msg, 'error');
            });
    }

    stopProp(event) { event.stopPropagation(); }

    handleCarouselPrev() {
        if (this.carouselOffset > 0) { this.carouselOffset = this.carouselOffset - 1; }
    }
    handleCarouselNext() {
        if (this.carouselOffset < this.maxCarousel) { this.carouselOffset = this.carouselOffset + 1; }
    }

    handleDiscover() {
        const el = this.template.querySelector('.discover-section');
        if (el) { el.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
        this._toast('Explore clubs in the Discover section!', 'info');
    }

    handleCreate() { this.showCreateModal = true; }
    handleCloseCreate() {
        this.showCreateModal = false;
        this.newClubName = '';
        this.newClubDescription = '';
        this.newClubPrivacy = 'Public';
    }
    handleClubNameChange(event) { this.newClubName = event.target.value; }
    handleClubCategoryChange(event) { this.newClubCategory = event.target.value; }
    handleClubDescChange(event) { this.newClubDescription = event.target.value; }
    handleClubPrivacyChange(event) { this.newClubPrivacy = event.target.value; }

    handleConfirmCreate() {
        const name = this.newClubName.trim();
        if (!name) { this._toast('Please enter a club name.', 'error'); return; }
        if (name.length > 80) { this._toast('Club name must be 80 characters or fewer.', 'error'); return; }
        if ((this.newClubDescription || '').length > 1000) { this._toast('Description must be 1000 characters or fewer.', 'error'); return; }
        createClubApex({
            name,
            category: this.newClubCategory,
            description: this.newClubDescription.trim()
        })
            .then(saved => {
                const newClub = {
                    id: saved && saved.id ? saved.id : 'CC-' + Date.now(),
                    name: saved && saved.name ? saved.name : name,
                    category: saved && saved.category ? saved.category : this.newClubCategory,
                    description: saved && saved.description ? saved.description : this.newClubDescription.trim(),
                    privacy: this.newClubPrivacy,
                    members: '1',
                    image: 'images/clubs/cultural.jpg'
                };
                this.createdClubs = [...this.createdClubs, newClub];
                this.showCreateModal = false;
                this.newClubName = '';
                this.newClubDescription = '';
                this.newClubPrivacy = 'Public';
                // Reset any active filter so the just-created club is visible.
                this.filterCategory = '';
                this.searchText = '';
                this._toast(`"${newClub.name}" submitted for admin review.`, 'success');
                if (this._wireClubsResp) refreshApex(this._wireClubsResp);
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not create the club.';
                this._toast(msg, 'error');
            });
    }
}