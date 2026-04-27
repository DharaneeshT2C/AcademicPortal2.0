import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getResidencePreferenceSelectionData from '@salesforce/apex/HostelDashboardController.getResidencePreferenceSelectionData';
import saveResidencePreferences from '@salesforce/apex/HostelDashboardController.saveResidencePreferences';
import getOrganizationDefaults from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';

const MAX_SELECTION = 3;
const RESIDENCE_ALLOCATION_PAGE_NAME = 'ResidenceAllocation__c';

const RESIDENCE_COLOR_SETS = [
    [
        'background: linear-gradient(135deg, #a8edea 0%, #fed6e3 100%);',
        'background: linear-gradient(135deg, #e0c3fc 0%, #8ec5fc 100%);',
        'background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);'
    ],
    [
        'background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);',
        'background: linear-gradient(135deg, #accbee 0%, #e7f0fd 100%);',
        'background: linear-gradient(135deg, #e6dee9 0%, #af89c2 100%);'
    ],
    [
        'background: linear-gradient(135deg, #e0c3fc 0%, #8ec5fc 100%);',
        'background: linear-gradient(135deg, #cfd9df 0%, #e2ebf0 100%);',
        'background: linear-gradient(135deg, #ebbba7 0%, #cfc7f8 100%);'
    ],
    [
        'background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);',
        'background: linear-gradient(135deg, #89f7fe 0%, #66a6ff 100%);',
        'background: linear-gradient(135deg, #13547a 0%, #80d0c7 100%);'
    ],
    [
        'background: linear-gradient(135deg, #84fab0 0%, #8fd3f4 100%);',
        'background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);',
        'background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);'
    ]
];

export default class ResidencePreferenceSelection extends NavigationMixin(LightningElement) {
    static DEFAULT_PRIMARY = '#3061FF';
    static DEFAULT_SECONDARY = '#EAEFFF';

    organizationDefaults = {};
    pendingPrimary = ResidencePreferenceSelection.DEFAULT_PRIMARY;
    pendingSecondary = ResidencePreferenceSelection.DEFAULT_SECONDARY;

    @track residences = [];
    @track selectedRes = {};
    @track isPreferenceModalOpen = false;
    @track isFinalModalOpen = false;
    @track isAmenitiesModalOpen = false;
    @track amenitiesModalTitle = '';
    @track amenitiesModalItems = [];
    @track currentCarouselIndex = 0;

    @track currentPriority = 1;
    @track floorByPriority = { 1: '', 2: '', 3: '' };
    @track roommateInputsByPriority = {
        1: [{ id: 1, index: 1, value: '' }, { id: 2, index: 2, value: '' }],
        2: [{ id: 1, index: 1, value: '' }, { id: 2, index: 2, value: '' }],
        3: [{ id: 1, index: 1, value: '' }, { id: 2, index: 2, value: '' }]
    };
    // Map of residence category ID to its floor/roommate data by order
    @track floorByResidenceAndOrder = {};
    @track roommatesByResidenceAndOrder = {};
    @track roommateErrors = { 1: '', 2: '' };
    @track floorError = '';
    @track emptyStateMessage = 'No residence options are available right now.';

    isLoading = false;
    isSaving = false;
    isThemeLoaded = false;
    pendingSuccessModalCallback = null;
    successModalAutoCloseDuration = 0;
    successModalAnimationName = 'successModalLifecycleA';
    pendingToastNavigationState = null;
    successModalTimeoutId = null;

    _lastSyncedPriority = null;

    connectedCallback() {
        this.loadOrganizationDefaults();
        this.loadResidencePreferenceData();
    }

    disconnectedCallback() {
        this.clearSuccessModalTimeout();
    }

    renderedCallback() {
        if (this.isPreferenceModalOpen && this._lastSyncedPriority !== this.currentPriority) {
            this._lastSyncedPriority = this.currentPriority;
            this.syncModalInputsToDom();
        }

        if (this.pendingPrimary || this.pendingSecondary) {
            this.applyTheme(this.pendingPrimary, this.pendingSecondary);
        }
    }

    async loadOrganizationDefaults() {
        try {
            const data = await getOrganizationDefaults();
            if (data) {
                this.organizationDefaults = data;
                this.applyTheme(data.primary, data.secondary);
            } else {
                this.applyTheme();
            }
        } catch (error) {
            console.error('Error loading organization defaults:', error);
            this.applyTheme();
        } finally {
            this.isThemeLoaded = true;
        }
    }

    applyTheme(primary, secondary) {
        const resolvedPrimary = primary || ResidencePreferenceSelection.DEFAULT_PRIMARY;
        const resolvedSecondary = secondary || ResidencePreferenceSelection.DEFAULT_SECONDARY;
        this.pendingPrimary = resolvedPrimary;
        this.pendingSecondary = resolvedSecondary;

        if (!this.template?.host) {
            return;
        }

        this.template.host.style.setProperty('--primary-color', resolvedPrimary);
        this.template.host.style.setProperty('--secondary-color', resolvedSecondary);
        this.pendingPrimary = null;
        this.pendingSecondary = null;
    }

    syncModalInputsToDom() {
        const floorSelect = this.template.querySelector('select.preference-select-input');
        if (floorSelect) {
            floorSelect.value = this.displayFloor;
        }

        const emailInputs = this.template.querySelectorAll('input.roommate-email-input');
        const currentEmails = this.roommateInputs;
        if (emailInputs && emailInputs.length) {
            emailInputs.forEach((input) => {
                const idx = Number.parseInt(input.dataset.index, 10);
                const match = currentEmails.find((e) => e.index === idx);
                if (match) {
                    input.value = match.value || '';
                }
            });
        }
    }

    async loadResidencePreferenceData() {
        this.isLoading = true;
        try {
            const data = await getResidencePreferenceSelectionData();
            this.applyResidencePreferenceData(data);
        } catch (error) {
            console.error('Error loading residence preference selection data', error);
            this.applyNoResidenceData('Unable to load residence options right now.');
        } finally {
            this.isLoading = false;
        }
    }

    applyNoResidenceData(message) {
        this.residences = [];
        this.emptyStateMessage = this.normalizeText(message) || 'No residence options are available right now.';
    }

    applyResidencePreferenceData(data) {
        const categoryRows = Array.isArray(data?.residences) ? data.residences : [];
        const selectedRows = Array.isArray(data?.selectedPreferences) ? data.selectedPreferences : [];
        const defaultAllowRoommatePreference = data?.allowRoommatePreference === true;
        const sourceRows =
            categoryRows.length > 0
                ? categoryRows
                : this.mapSelectedRowsToResidenceRows(selectedRows, defaultAllowRoommatePreference);
        const validSourceRows = sourceRows.filter((row) => this.normalizeText(row?.id || row?.categoryId));

        if (!validSourceRows.length) {
            this.applyNoResidenceData(data?.message);
            return;
        }

        this.emptyStateMessage = this.normalizeText(data?.message) || 'No residence options are available right now.';

        const preferenceByCategory = new Map();
        const floorByResAndOrder = {};
        const roommatesByResAndOrder = {};

        selectedRows.forEach((row) => {
            const categoryId = this.normalizeText(row?.categoryId);
            if (categoryId) {
                preferenceByCategory.set(categoryId, row);
                const order = this.parsePreferenceOrder(row?.order, row?.preference);
                if (order >= 1 && order <= 3) {
                    const key = `${categoryId}_${order}`;
                    floorByResAndOrder[key] = this.normalizeText(row?.floor) || '';
                    const em = this.parseEmails(row?.emails) || [];
                    roommatesByResAndOrder[key] = [em[0] || '', em[1] || ''];
                }
            }
        });
        this.floorByResidenceAndOrder = floorByResAndOrder;
        this.roommatesByResidenceAndOrder = roommatesByResAndOrder;

        const fallbackEmails = this.parseEmails(data?.preferredPartnerEmails);

        this.residences = validSourceRows.map((row, index) => {
            const mapped = this.mapServerResidence(row, index, defaultAllowRoommatePreference);
            const selected = preferenceByCategory.get(mapped.id);

            if (selected) {
                mapped.isSelected = true;
                mapped.preferenceOrder = this.parsePreferenceOrder(selected.order, selected.preference);
                mapped.selectedFloor = this.normalizeText(selected.floor) || 'No Preference';
                mapped.floorOptions = this.mergeFloorOptions(mapped.floorOptions, [selected.floor]);
                mapped.sharing = this.normalizeText(mapped.sharing) || this.normalizeText(selected.sharing);
                mapped.ac = this.normalizeText(mapped.ac) || this.normalizeText(selected.ac);
                mapped.bathroom = this.normalizeText(mapped.bathroom) || this.normalizeText(selected.bathroom);

                const selectedEmails = this.parseEmails(selected.emails);
                mapped.roommateEmails = mapped.allowRoommatePreference
                    ? (selectedEmails.length ? selectedEmails : fallbackEmails)
                    : [];
            }

            return this.decorateResidence(mapped, index);
        });

        this.resequenceSelectedPreferences();
    }

    mapSelectedRowsToResidenceRows(selectedRows, defaultAllowRoommatePreference = false) {
        if (!Array.isArray(selectedRows) || !selectedRows.length) {
            return [];
        }

        const rowsById = new Map();
        selectedRows.forEach((row) => {
            const categoryId = this.normalizeText(row?.categoryId);
            if (!categoryId || rowsById.has(categoryId)) {
                return;
            }

            rowsById.set(categoryId, {
                id: categoryId,
                name: this.normalizeText(row?.type),
                sharing: this.normalizeText(row?.sharing),
                ac: this.normalizeText(row?.ac),
                bathroom: this.normalizeText(row?.bathroom),
                floorOptions: this.normalizeSelectedFloorValue(row?.floor)
                    ? [this.normalizeSelectedFloorValue(row.floor)]
                    : [],
                annualFee: null,
                allowRoommatePreference: defaultAllowRoommatePreference === true
            });
        });

        return Array.from(rowsById.values());
    }

    mapServerResidence(row, index, defaultAllowRoommatePreference = false) {
        const palette = this.getColorPalette(index);
        const amenities = this.parseAmenities(row?.amenities);
        const sharing = this.normalizeText(row?.sharing) || this.toSharingLabel(row?.capacity);
        const fee = this.toNumber(row?.annualFee);
        const ac = this.resolveAcLabel(row?.ac, amenities);
        const bathroom = this.resolveBathroomLabel(row?.bathroom, amenities);
        const amenityPreview = amenities.slice(0, 3);
        const amenityExtraCount = Math.max(0, amenities.length - amenityPreview.length);
        const floorOptions = this.parseFloorOptions(row?.floorOptions);
        const hasExplicitRoommateSetting = row && Object.prototype.hasOwnProperty.call(row, 'allowRoommatePreference');
        const allowRoommatePreference = hasExplicitRoommateSetting
            ? row?.allowRoommatePreference === true
            : defaultAllowRoommatePreference === true;

        return {
            id: String(row?.id || row?.categoryId || ''),
            name: this.normalizeText(row?.name) || `Residence ${index + 1}`,
            sharing,
            ac,
            bathroom,
            amenities,
            amenityPreview,
            amenityExtraCount,
            hasAmenityPreview: amenityPreview.length > 0,
            hasAmenityOverflow: amenityExtraCount > 0,
            floorOptions,
            fee,
            feeDisplay: fee !== null ? this.formatInr(fee) : '',
            bgStyle: palette[0],
            carouselStyles: palette,
            isSelected: false,
            preferenceOrder: null,
            selectedFloor: 'No Preference',
            roommateEmails: [],
            allowRoommatePreference
        };
    }

    getColorPalette(index) {
        return RESIDENCE_COLOR_SETS[index % RESIDENCE_COLOR_SETS.length];
    }

    decorateResidence(residence, index) {
        const sharing = this.normalizeText(residence.sharing);
        const ac = this.normalizeText(residence.ac);
        const bathroom = this.normalizeText(residence.bathroom);
        const allowRoommatePreference = residence.allowRoommatePreference === true;
        const roommateEmails = allowRoommatePreference ? this.parseEmails(residence.roommateEmails) : [];
        const floorOptions = this.mergeFloorOptions(
            this.parseFloorOptions(residence.floorOptions),
            [this.normalizeSelectedFloorValue(residence.selectedFloor)]
        );
        const palette =
            Array.isArray(residence.carouselStyles) && residence.carouselStyles.length
                ? residence.carouselStyles
                : this.getColorPalette(index);

        return {
            ...residence,
            id: String(residence.id),
            sharing,
            ac,
            bathroom,
            bgStyle: residence.bgStyle || palette[0],
            carouselStyles: palette,
            feeDisplay:
                residence.feeDisplay !== null && residence.feeDisplay !== undefined
                    ? String(residence.feeDisplay)
                    : '',
            isSelected: !!residence.isSelected,
            preferenceOrder: this.parsePreferenceOrder(residence.preferenceOrder, null),
            selectedFloor: this.normalizeText(residence.selectedFloor) || 'No Preference',
            floorOptions,
            allowRoommatePreference,
            roommateEmails,
            roommateCount: allowRoommatePreference ? roommateEmails.length : 0,
            showRoommatePreferenceSummary: allowRoommatePreference,
            prefDetailRowClass: allowRoommatePreference
                ? 'pref-detail-row'
                : 'pref-detail-row pref-detail-row-no-roommate',
            hasSharing: !!sharing,
            hasAC: !!ac,
            isSingle: /single|\b1\b/i.test(sharing || ''),
            isTwin: /twin|double|\b2\b/i.test(sharing || ''),
            isTriple: /triple|\b3\b/i.test(sharing || ''),
            isAC: /^(yes|ac)$/i.test(ac || '') || (/\bac\b/i.test(ac || '') && !/non/i.test(ac || '')),
            isNonAC: /^(no|non[\s-]*ac)$/i.test(ac || '') || /non/i.test(ac || ''),
            hasBath: !!bathroom
        };
    }

    resequenceSelectedPreferences() {
        const usedOrders = new Set();
        let nextOrder = 1;

        this.residences = this.residences.map((residence, index) => {
            if (!residence.isSelected) {
                return this.decorateResidence({ ...residence, preferenceOrder: null }, index);
            }

            let order = this.parsePreferenceOrder(residence.preferenceOrder, null);
            if (order === null || usedOrders.has(order)) {
                while (usedOrders.has(nextOrder) && nextOrder <= MAX_SELECTION) {
                    nextOrder += 1;
                }
                order = nextOrder <= MAX_SELECTION ? nextOrder : MAX_SELECTION;
            }

            usedOrders.add(order);
            return this.decorateResidence({ ...residence, preferenceOrder: order }, index);
        });
    }

    get selectionPageClass() {
        return this.isThemeLoaded ? 'selection-page' : 'selection-page hidden';
    }

    get selectedCount() {
        return this.residences.filter((residence) => residence.isSelected).length;
    }

    get hasResidences() {
        return this.residences.length > 0;
    }

    get isSubmitDisabled() {
        return this.isSaving;
    }

    get isSaveDraftDisabled() {
        return this.isSaving || !this.hasResidences;
    }

    get pref1Class() {
        return this.currentPriority === 1 ? 'priority-btn selected' : 'priority-btn';
    }

    get pref2Class() {
        return this.currentPriority === 2 ? 'priority-btn selected' : 'priority-btn';
    }

    get pref3Class() {
        return this.currentPriority === 3 ? 'priority-btn selected' : 'priority-btn';
    }

    get isPref1Selected() {
        return this.currentPriority === 1;
    }

    get isPref2Selected() {
        return this.currentPriority === 2;
    }

    get isPref3Selected() {
        return this.currentPriority === 3;
    }

    get displayFloor() {
        // Read directly from stored data to ensure independence per priority
        if (this.selectedRes && this.selectedRes.id) {
            const key = `${this.selectedRes.id}_${this.currentPriority}`;
            const storedFloor = this.floorByResidenceAndOrder[key];
            if (storedFloor !== undefined && storedFloor !== null && storedFloor !== '') {
                return String(storedFloor);
            }
        }
        // Fallback to floorByPriority if no stored data
        const v = this.floorByPriority && this.floorByPriority[this.currentPriority];
        return v !== undefined && v !== null ? String(v) : '';
    }

    get isFloorSelectSelected() {
        return this.displayFloor === '';
    }

    get availableFloorOptions() {
        const selectedFloor = this.normalizeSelectedFloorValue(this.displayFloor);
        return this.mergeFloorOptions(
            this.selectedRes?.floorOptions,
            selectedFloor ? [selectedFloor] : []
        ).map((floor) => ({
            label: floor,
            value: floor
        }));
    }

    get isFloor1stSelected() {
        return this.displayFloor === '1st Floor';
    }

    get isFloor2ndSelected() {
        return this.displayFloor === '2nd Floor';
    }

    get isFloor3rdSelected() {
        return this.displayFloor === '3rd Floor';
    }

    get floorInputClass() {
        return this.floorError
            ? 'form-input preference-select-input input-error'
            : 'form-input preference-select-input';
    }

    get roommateInputs() {
        let v1 = '';
        let v2 = '';
        const id = this.selectedRes?.id;
        if (id) {
            const key = `${id}_${this.currentPriority}`;
            const pair = this.roommatesByResidenceAndOrder[key];
            if (Array.isArray(pair) && pair.length >= 2) {
                v1 = String(pair[0] ?? '');
                v2 = String(pair[1] ?? '');
            } else if (Array.isArray(pair) && pair.length === 1) {
                v1 = String(pair[0] ?? '');
            } else {
                const arr = this.roommateInputsByPriority?.[this.currentPriority];
                if (Array.isArray(arr)) {
                    v1 = arr.find((i) => i.index === 1)?.value || '';
                    v2 = arr.find((i) => i.index === 2)?.value || '';
                }
            }
        }
        const errors = this.roommateErrors || { 1: '', 2: '' };
        return [
            {
                id: 1,
                index: 1,
                value: v1,
                error: errors[1] || '',
                inputClass: errors[1]
                    ? 'form-input roommate-email-input input-error'
                    : 'form-input roommate-email-input'
            },
            {
                id: 2,
                index: 2,
                value: v2,
                error: errors[2] || '',
                inputClass: errors[2]
                    ? 'form-input roommate-email-input input-error'
                    : 'form-input roommate-email-input'
            }
        ];
    }

    get showRoommatePreferenceSection() {
        return this.selectedRes?.allowRoommatePreference === true;
    }

    get displaySharing() {
        const rawSharing = this.normalizeText(this.selectedRes?.sharing);
        const inferredSharing = this.toSharingLabel(this.selectedRes?.capacity);
        const sharing = rawSharing || inferredSharing || '';
        return sharing;
    }

    get displayAC() {
        if (this.selectedRes.ac === 'Non-AC') {
            return 'No';
        }
        if (this.selectedRes.ac === 'AC') {
            return 'Yes';
        }
        return this.selectedRes.ac;
    }

    get displayBath() {
        return this.resolveBathroomLabel(this.selectedRes?.bathroom, []) || '';
    }

    get displayFee() {
        return this.selectedRes.feeDisplay ?? '';
    }

    get currentBgStyle() {
        if (this.selectedRes && this.selectedRes.carouselStyles && this.selectedRes.carouselStyles.length > 0) {
            return this.selectedRes.carouselStyles[this.currentCarouselIndex];
        }
        return this.selectedRes.bgStyle;
    }

    get dot1Class() {
        return this.currentCarouselIndex === 0 ? 'dot active' : 'dot';
    }

    get dot2Class() {
        return this.currentCarouselIndex === 1 ? 'dot active' : 'dot';
    }

    get dot3Class() {
        return this.currentCarouselIndex === 2 ? 'dot active' : 'dot';
    }

    handleCarouselNext() {
        if (this.selectedRes && this.selectedRes.carouselStyles) {
            this.currentCarouselIndex = (this.currentCarouselIndex + 1) % this.selectedRes.carouselStyles.length;
        }
    }

    handleDotClick(event) {
        const index = Number.parseInt(event.target.dataset.index, 10);
        if (!Number.isNaN(index)) {
            this.currentCarouselIndex = index;
        }
    }

    handleAddPreference(event) {
        if (this.selectedCount >= MAX_SELECTION) {
            return;
        }
        const residenceId = event.currentTarget.dataset.id;
        this.openPreferenceModal(residenceId);
    }

    handleEditPreference(event) {
        const residenceId = event.currentTarget.dataset.id;
        this.openPreferenceModal(residenceId);
    }

    handleDeletePreference(event) {
        this.preferenceToDelete = event.currentTarget.dataset.id;
        this.isDeleteConfirmOpen = true;
    }

    handleOpenAmenitiesModal(event) {
        const residenceId = event.currentTarget?.dataset?.id;
        const residence = this.residences.find((item) => item.id === residenceId);
        if (!residence) {
            return;
        }

        this.amenitiesModalTitle = residence.name;
        this.amenitiesModalItems = Array.isArray(residence.amenities) ? residence.amenities : [];
        this.isAmenitiesModalOpen = true;
    }

    closeAmenitiesModal() {
        this.isAmenitiesModalOpen = false;
        this.amenitiesModalTitle = '';
        this.amenitiesModalItems = [];
    }

    openPreferenceModal(residenceId) {
        const residence = this.residences.find((item) => item.id === residenceId);
        if (!residence) {
            return;
        }

        this.selectedRes = { ...residence };
        this.currentCarouselIndex = 0;
        this._lastSyncedPriority = null;
        const order = this.parsePreferenceOrder(residence.preferenceOrder, null) || this.getNextAvailablePriority(residence.id);
        this.currentPriority = order;

        // Load floor and roommate data for THIS specific residence across all three priorities
        // This allows switching between priorities while keeping data separate per residence
        this.floorByPriority = {
            1: this.floorByResidenceAndOrder[`${residenceId}_1`] || '',
            2: this.floorByResidenceAndOrder[`${residenceId}_2`] || '',
            3: this.floorByResidenceAndOrder[`${residenceId}_3`] || ''
        };

        const p1 = residence.allowRoommatePreference
            ? this.normalizeRoommatePair(this.roommatesByResidenceAndOrder[`${residenceId}_1`])
            : ['', ''];
        const p2 = residence.allowRoommatePreference
            ? this.normalizeRoommatePair(this.roommatesByResidenceAndOrder[`${residenceId}_2`])
            : ['', ''];
        const p3 = residence.allowRoommatePreference
            ? this.normalizeRoommatePair(this.roommatesByResidenceAndOrder[`${residenceId}_3`])
            : ['', ''];

        this.roommatesByResidenceAndOrder = {
            ...this.roommatesByResidenceAndOrder,
            [`${residenceId}_1`]: p1,
            [`${residenceId}_2`]: p2,
            [`${residenceId}_3`]: p3
        };

        this.roommateInputsByPriority = {
            1: [
                { id: 1, index: 1, value: p1[0] },
                { id: 2, index: 2, value: p1[1] }
            ],
            2: [
                { id: 1, index: 1, value: p2[0] },
                { id: 2, index: 2, value: p2[1] }
            ],
            3: [
                { id: 1, index: 1, value: p3[0] },
                { id: 2, index: 2, value: p3[1] }
            ]
        };

        this.roommateErrors = { 1: '', 2: '' };
        this.floorError = '';
        this.isPreferenceModalOpen = true;
    }

    getNextAvailablePriority(excludedResidenceId) {
        const used = new Set(
            this.residences
                .filter((item) => item.isSelected && item.id !== excludedResidenceId)
                .map((item) => this.parsePreferenceOrder(item.preferenceOrder, null))
                .filter((order) => order !== null)
        );

        for (let order = 1; order <= MAX_SELECTION; order += 1) {
            if (!used.has(order)) {
                return order;
            }
        }

        return MAX_SELECTION;
    }

    handleClosePreferenceModal() {
        if (this.isPreferenceModalOpen && this.selectedRes?.id) {
            this._flushRoommateAndFloorForPriority(this.currentPriority);
        }
        this.isPreferenceModalOpen = false;
        this.floorError = '';
    }

    /** Persist floor + roommate Email 1 & 2 for one preference priority before switching away. */
    _flushRoommateAndFloorForPriority(priority) {
        if (!this.selectedRes?.id || !this.isPreferenceModalOpen) {
            return;
        }
        const id = this.selectedRes.id;
        const key = `${id}_${priority}`;
        const inputs = this.template.querySelectorAll('input.roommate-email-input');
        let v1 = '';
        let v2 = '';
        inputs.forEach((input) => {
            const idx = Number.parseInt(input.dataset.index, 10);
            if (idx === 1) {
                v1 = input.value || '';
            }
            if (idx === 2) {
                v2 = input.value || '';
            }
        });
        if (this.selectedRes.allowRoommatePreference) {
            this.roommatesByResidenceAndOrder = { ...this.roommatesByResidenceAndOrder, [key]: [v1, v2] };
            this.roommateInputsByPriority = {
                ...this.roommateInputsByPriority,
                [priority]: [
                    { id: 1, index: 1, value: v1 },
                    { id: 2, index: 2, value: v2 }
                ]
            };
        }
        const floorSelect = this.template.querySelector('select.preference-select-input');
        if (floorSelect) {
            const fv = floorSelect.value || '';
            this.floorByPriority = { ...this.floorByPriority, [priority]: fv };
            this.floorByResidenceAndOrder = { ...this.floorByResidenceAndOrder, [key]: fv };
        }
    }

    selectPriority(event) {
        const leaving = this.currentPriority;
        this._flushRoommateAndFloorForPriority(leaving);
        this._lastSyncedPriority = null;
        this.roommateErrors = { 1: '', 2: '' };
        this.floorError = '';
        this.currentPriority = Number.parseInt(event.currentTarget.dataset.val, 10);
    }

    handleFloorChange(event) {
        const value = event.target.value || '';
        this.floorByPriority = { ...this.floorByPriority, [this.currentPriority]: value };

        // Also update the stored data immediately
        if (this.selectedRes && this.selectedRes.id) {
            const key = `${this.selectedRes.id}_${this.currentPriority}`;
            this.floorByResidenceAndOrder = { ...this.floorByResidenceAndOrder, [key]: value };
        }

        if (!this.normalizeSelectedFloorValue(value)) {
            this.floorError = '';
            return;
        }

        const conflict = this.findConflictingFloorSelection(this.selectedRes?.id, this.currentPriority, value);
        this.floorError = this.buildDuplicateFloorMessage(conflict, value);
    }

    handleRoommateChange(event) {
        const index = Number.parseInt(event.target.dataset.index, 10);
        const value = event.target.value || '';
        const current = this.roommateInputsByPriority[this.currentPriority] || [
            { id: 1, index: 1, value: '' },
            { id: 2, index: 2, value: '' }
        ];
        const updated = current.map((input) =>
            input.index === index ? { ...input, value } : input
        );
        this.roommateInputsByPriority = { ...this.roommateInputsByPriority, [this.currentPriority]: updated };

        if (this.selectedRes && this.selectedRes.id) {
            const key = `${this.selectedRes.id}_${this.currentPriority}`;
            const v1 = updated.find((i) => i.index === 1)?.value || '';
            const v2 = updated.find((i) => i.index === 2)?.value || '';
            this.roommatesByResidenceAndOrder = { ...this.roommatesByResidenceAndOrder, [key]: [v1, v2] };
        }

        this.validateRoommateEmailInputs();
    }

    async handleSavePreference(event) {
        event?.preventDefault?.();
        event?.stopPropagation?.();

        if (this.isSaving) {
            return;
        }

        const residenceId = this.selectedRes.id;
        if (!residenceId) {
            this.isPreferenceModalOpen = false;
            return;
        }

        this._flushRoommateAndFloorForPriority(this.currentPriority);

        if (!this.validateCurrentRoommateRequirement()) {
            return;
        }

        if (!this.validateRoommateEmailInputs()) {
            return;
        }

        if (!this.validateCurrentFloorSelection()) {
            return;
        }

        const order = this.parsePreferenceOrder(this.currentPriority, null) || 1;
        const saveKey = `${residenceId}_${order}`;
        const floor = this.normalizeSelectedFloorValue(this.floorByResidenceAndOrder[saveKey]);
        const pair = this.normalizeRoommatePair(this.roommatesByResidenceAndOrder[saveKey]);
        const roommateEmails =
            this.selectedRes?.allowRoommatePreference === true ? this.pairToNonEmptyEmailList(pair) : [];

        const previousResidences = this.residences.map((residence) => ({
            ...residence,
            roommateEmails: Array.isArray(residence.roommateEmails) ? [...residence.roommateEmails] : [],
            carouselStyles: Array.isArray(residence.carouselStyles) ? [...residence.carouselStyles] : []
        }));

        this.residences = this.residences.map((residence, index) => {
            if (residence.id === residenceId) {
                return this.decorateResidence(
                    {
                        ...residence,
                        isSelected: true,
                        preferenceOrder: order,
                        selectedFloor: floor || '',
                        roommateEmails
                    },
                    index
                );
            }

            return residence;
        });

        this.resequenceSelectedPreferences();

        const isSaved = await this.persistPreferences(false);
        if (!isSaved) {
            this.residences = previousResidences;
            return;
        }

        this.floorByResidenceAndOrder = { ...this.floorByResidenceAndOrder, [saveKey]: floor };
        this.roommatesByResidenceAndOrder = {
            ...this.roommatesByResidenceAndOrder,
            [saveKey]: [pair[0], pair[1]]
        };

        this.isPreferenceModalOpen = false;
        this.showSuccessModal('Change Saved Successfully', 'Your changes have been saved successfully.', 1200);
    }

    validateCurrentRoommateRequirement() {
        if (this.selectedRes?.allowRoommatePreference !== true) {
            return true;
        }

        const values = this.getCurrentRoommateRawValues();
        const hasAnyRoommateEmail = values.some((value) => !!this.normalizeText(value));
        if (hasAnyRoommateEmail) {
            return true;
        }

        const message = this.buildMissingRoommateEmailMessage(this.currentPriority);
        this.roommateErrors = { 1: message, 2: '' };
        return false;
    }

    validateCurrentFloorSelection() {
        const residenceId = this.selectedRes?.id;
        const order = this.parsePreferenceOrder(this.currentPriority, null) || 1;
        const key = residenceId ? `${residenceId}_${order}` : null;
        const floorValue = key ? this.floorByResidenceAndOrder[key] : this.displayFloor;
        const normalizedFloor = this.normalizeSelectedFloorValue(floorValue);
        if (!normalizedFloor) {
            this.floorError = this.buildMissingFloorMessage(order);
            return false;
        }

        const conflict = this.findConflictingFloorSelection(residenceId, order, floorValue);
        this.floorError = this.buildDuplicateFloorMessage(conflict, floorValue);
        return !this.floorError;
    }

    buildMissingFloorMessage(order) {
        return `Please select a floor preference for Preference ${order}.`;
    }

    findConflictingFloorSelection(residenceId, order, floorValue) {
        const normalizedFloor = this.normalizeFloorPreferenceValue(floorValue);
        if (!normalizedFloor) {
            return null;
        }

        const selectedResidences = Array.isArray(this.residences) ? this.residences : [];
        for (const residence of selectedResidences) {
            if (!residence?.isSelected || residence.id === residenceId) {
                continue;
            }

            const otherOrder = this.parsePreferenceOrder(residence.preferenceOrder, null);
            if (otherOrder === null) {
                continue;
            }

            const otherKey = `${residence.id}_${otherOrder}`;
            const otherFloor =
                this.floorByResidenceAndOrder[otherKey] ||
                this.normalizeText(residence.selectedFloor) ||
                '';

            if (this.normalizeFloorPreferenceValue(otherFloor) === normalizedFloor) {
                return {
                    order: otherOrder,
                    floor: otherFloor,
                    residenceId: residence.id
                };
            }
        }

        return null;
    }

    buildDuplicateFloorMessage(conflict, floorValue) {
        const floorLabel = this.normalizeSelectedFloorValue(floorValue);
        if (!conflict || !floorLabel) {
            return '';
        }

        return `${floorLabel} is already selected in Preference ${conflict.order}. Choose a different floor.`;
    }

    normalizeFloorPreferenceValue(value) {
        const text = this.normalizeSelectedFloorValue(value);
        if (!text) {
            return null;
        }

        return text.toLowerCase() === 'no preference' ? null : text.toLowerCase();
    }

    @track allergyStatus = 'No';
    @track disabilityStatus = 'No';
    @track idProofFile = null;
    @track medicalFile = null;
    @track emergencyNotes = '';

    get allergyYesClass() {
        return this.allergyStatus === 'Yes' ? 'radio-option selected' : 'radio-option';
    }

    get allergyNoClass() {
        return this.allergyStatus === 'No' ? 'radio-option selected' : 'radio-option';
    }

    get disabilityYesClass() {
        return this.disabilityStatus === 'Yes' ? 'radio-option selected' : 'radio-option';
    }

    get disabilityNoClass() {
        return this.disabilityStatus === 'No' ? 'radio-option selected' : 'radio-option';
    }

    get isAllergyYes() {
        return this.allergyStatus === 'Yes';
    }

    get isAllergyNo() {
        return this.allergyStatus === 'No';
    }

    get isDisabilityYes() {
        return this.disabilityStatus === 'Yes';
    }

    get isDisabilityNo() {
        return this.disabilityStatus === 'No';
    }

    handleAllergyChange(event) {
        this.allergyStatus = event.currentTarget.dataset.value;
    }

    handleDisabilityChange(event) {
        this.disabilityStatus = event.currentTarget.dataset.value;
    }

    handleFileUpload(event) {
        const file = event.target.files[0];
        const type = event.target.dataset.type;
        if (file) {
            if (type === 'idProof') {
                this.idProofFile = file.name;
            } else if (type === 'medical') {
                this.medicalFile = file.name;
            }
        }
    }

    triggerFileUpload(event) {
        const type = event.currentTarget.dataset.type;
        const input = this.template.querySelector(`input[data-file-type="${type}"]`);
        if (input) {
            input.click();
        }
    }

    handleNotesChange(event) {
        this.emergencyNotes = event.target.value;
    }

    handleOpenFinalModal() {
        if (this.selectedCount === 0) {
            this.showErrorToast('Select at least one residence preference.');
            return;
        }

        if (this.selectedCount < MAX_SELECTION && this.selectedCount > 0) {
            this.isLowPrefWarningOpen = true;
        } else if (this.selectedCount === MAX_SELECTION) {
            this.isSubmitConfirmOpen = true;
        } else {
            this.isLowPrefWarningOpen = true;
        }
    }

    @track isSubmitConfirmOpen = false;
    @track isDeleteConfirmOpen = false;
    @track isLowPrefWarningOpen = false;
    preferenceToDelete = null;

    closeDeleteConfirm() {
        this.isDeleteConfirmOpen = false;
        this.preferenceToDelete = null;
    }

    async confirmDelete() {
        const residenceId = this.preferenceToDelete;
        if (!residenceId) {
            this.closeDeleteConfirm();
            return;
        }

        const previousResidences = this.residences.map((residence) => ({
            ...residence,
            roommateEmails: Array.isArray(residence.roommateEmails) ? [...residence.roommateEmails] : [],
            carouselStyles: Array.isArray(residence.carouselStyles) ? [...residence.carouselStyles] : [],
            amenities: Array.isArray(residence.amenities) ? [...residence.amenities] : [],
            amenityPreview: Array.isArray(residence.amenityPreview) ? [...residence.amenityPreview] : []
        }));
        const previousFloorByResidenceAndOrder = { ...this.floorByResidenceAndOrder };
        const previousRoommatesByResidenceAndOrder = this.cloneRoommateMap(this.roommatesByResidenceAndOrder);

        this.residences = this.residences.map((residence, index) => {
            if (residence.id !== residenceId) {
                return residence;
            }

            return this.decorateResidence(
                {
                    ...residence,
                    isSelected: false,
                    preferenceOrder: null,
                    selectedFloor: 'No Preference',
                    roommateEmails: []
                },
                index
            );
        });
        this.floorByResidenceAndOrder = this.removeResidenceOrderEntries(this.floorByResidenceAndOrder, residenceId);
        this.roommatesByResidenceAndOrder = this.removeResidenceOrderEntries(this.roommatesByResidenceAndOrder, residenceId);
        this.roommateErrors = { 1: '', 2: '' };
        this.floorError = '';
        this.resequenceSelectedPreferences();
        this.closeDeleteConfirm();

        const isSaved = await this.persistPreferences(false, { allowEmpty: true });
        if (!isSaved) {
            this.residences = previousResidences;
            this.floorByResidenceAndOrder = previousFloorByResidenceAndOrder;
            this.roommatesByResidenceAndOrder = previousRoommatesByResidenceAndOrder;
            this.resequenceSelectedPreferences();
            return;
        }

        this.showSuccessModal('Preference Deleted Successfully', '', 1000);
    }

    closeSubmitConfirm() {
        this.isSubmitConfirmOpen = false;
    }

    closeLowPrefWarning() {
        this.isLowPrefWarningOpen = false;
    }

    async proceedToSubmit() {
        this.isSubmitConfirmOpen = false;
        this.isLowPrefWarningOpen = false;

        const isSaved = await this.persistPreferences(true);
        if (!isSaved) {
            return;
        }

        this.showSuccessModal(
            'Residence Request Submitted',
            "We've received your preferences. The Residence Office will review your request and notify you once a decision is made.",
            2000,
            () => {
                this.navigateToResidenceAllocation({
                    step: '2',
                    count: String(this.selectedCount)
                });
            }
        );
    }

    @track isSuccessModalOpen = false;
    @track successModalTitle = '';
    @track successModalMessage = '';

    showSuccessModal(title, message, duration, callback) {
        this.successModalTitle = title;
        this.successModalMessage = message;
        this.pendingSuccessModalCallback = typeof callback === 'function' ? callback : null;
        this.successModalAutoCloseDuration = this.resolveAutoCloseDuration(duration);
        this.clearSuccessModalTimeout();
        this.successModalAnimationName =
            this.successModalAnimationName === 'successModalLifecycleA'
                ? 'successModalLifecycleB'
                : 'successModalLifecycleA';
        this.isSuccessModalOpen = true;

        if (this.successModalAutoCloseDuration) {
            this.successModalTimeoutId = window.setTimeout(() => {
                this.finishSuccessModal();
            }, this.successModalAutoCloseDuration);
        }
    }

    closeSuccessModal() {
        this.finishSuccessModal();
    }

    handleCloseFinalModal() {
        this.isFinalModalOpen = false;
    }

    handleCancel() {
        this.navigateToResidenceAllocation();
    }

    async handleSaveDraft() {
        const isSaved = await this.persistPreferences(false);
        if (!isSaved) {
            return;
        }

        const toast = this.template.querySelector('c-custom-toast');
        if (toast) {
            toast.showToast('Draft Saved', 'Your preferences have been saved as a draft.', 'success');
            return;
        }

        this.showSuccessModal('Draft Saved', 'Your preferences have been saved as a draft.', 1200);
    }

    async handleSubmitFinal() {
        this.isFinalModalOpen = false;

        const isSaved = await this.persistPreferences(true);
        if (!isSaved) {
            return;
        }

        const toast = this.template.querySelector('c-custom-toast');
        if (toast) {
            this.pendingToastNavigationState = {
                step: '2',
                count: String(this.selectedCount)
            };
            toast.showToast(
                'Application Submitted',
                'Your residence preference application has been submitted successfully.',
                'success',
                { autoCloseTime: 1500 }
            );
            return;
        }

        this.showSuccessModal(
            'Application Submitted',
            'Your residence preference application has been submitted successfully.',
            1500,
            () => {
                this.navigateToResidenceAllocation({
                    step: '2',
                    count: String(this.selectedCount)
                });
            }
        );
    }

    navigateToResidenceAllocation(state = {}) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: RESIDENCE_ALLOCATION_PAGE_NAME
            },
            state
        });
    }

    async persistPreferences(submitRequest, options = {}) {
        if (this.isSaving) {
            return false;
        }

        const allowEmpty = options?.allowEmpty === true;

        if (!this.validateSelectedResidenceEmails()) {
            return false;
        }

        if (!this.validateSelectedResidenceFloors()) {
            return false;
        }

        const selections = this.buildPreferencePayload();
        if (!selections.length) {
            if (!allowEmpty) {
                this.showErrorToast('Select at least one residence preference.');
                return false;
            }
        }

        this.isSaving = true;
        try {
            const result = await saveResidencePreferences({ selections, submitRequest });
            if (!result || result.success !== true) {
                const appliedRoommateIssues = this.applyRoommateValidationIssues(result?.roommateIssues);
                if (!appliedRoommateIssues) {
                    this.showErrorToast(result?.message || 'Unable to save residence preferences.');
                }
                return false;
            }

            return true;
        } catch (error) {
            console.error('Error saving residence preferences', error);
            this.showErrorToast(this.getErrorMessage(error));
            return false;
        } finally {
            this.isSaving = false;
        }
    }

    buildPreferencePayload() {
        const selected = this.residences
            .filter((residence) => residence.isSelected)
            .sort((a, b) => {
                const aOrder = this.parsePreferenceOrder(a.preferenceOrder, null) || 999;
                const bOrder = this.parsePreferenceOrder(b.preferenceOrder, null) || 999;
                return aOrder - bOrder;
            });

        if (!selected.length) {
            return [];
        }

        const payload = [];
        const usedOrders = new Set();
        let nextOrder = 1;

        selected.forEach((residence) => {
            let order = this.parsePreferenceOrder(residence.preferenceOrder, null);
            if (order === null || usedOrders.has(order)) {
                while (usedOrders.has(nextOrder) && nextOrder <= MAX_SELECTION) {
                    nextOrder += 1;
                }
                order = nextOrder <= MAX_SELECTION ? nextOrder : MAX_SELECTION;
            }

            usedOrders.add(order);
            const numOrder = Number(order);

            // Get floor and roommate data for THIS specific residence at THIS order
            const key = `${residence.id}_${numOrder}`;
            const floorForResidence = this.normalizeSelectedFloorValue(
                this.floorByResidenceAndOrder[key] || this.normalizeText(residence.selectedFloor)
            );
            const pair = this.normalizeRoommatePair(this.roommatesByResidenceAndOrder[key]);
            const emailsForResidence =
                residence.allowRoommatePreference === true
                    ? this.pairToNonEmptyEmailList(pair).length > 0
                        ? this.pairToNonEmptyEmailList(pair)
                        : this.parseEmails(residence.roommateEmails)
                    : [];

            payload.push({
                residenceId: residence.id,
                order: numOrder,
                floor: floorForResidence,
                roommateEmails: residence.allowRoommatePreference === true ? emailsForResidence.slice(0, 2) : []
            });
        });

        return payload.slice(0, MAX_SELECTION);
    }

    validateSelectedResidenceFloors() {
        const selected = this.residences
            .filter((residence) => residence.isSelected)
            .sort((a, b) => {
                const aOrder = this.parsePreferenceOrder(a.preferenceOrder, null) || 999;
                const bOrder = this.parsePreferenceOrder(b.preferenceOrder, null) || 999;
                return aOrder - bOrder;
            });

        for (const residence of selected) {
            const order = this.parsePreferenceOrder(residence.preferenceOrder, null) || 1;
            const key = `${residence.id}_${order}`;
            const floorValue = this.normalizeSelectedFloorValue(
                this.floorByResidenceAndOrder[key] || this.normalizeText(residence.selectedFloor)
            );
            if (floorValue) {
                continue;
            }

            if (!this.isPreferenceModalOpen || this.selectedRes?.id !== residence.id) {
                this.openPreferenceModal(residence.id);
            }

            if (this.currentPriority !== order) {
                this._lastSyncedPriority = null;
                this.roommateErrors = { 1: '', 2: '' };
                this.currentPriority = order;
            }

            this.floorError = this.buildMissingFloorMessage(order);
            return false;
        }

        return true;
    }

    normalizeSelectedFloorValue(value) {
        const floorValue = this.normalizeText(value);
        if (!floorValue) {
            return '';
        }

        const normalized = floorValue.toLowerCase();
        if (normalized === 'no preference' || normalized === 'select floor') {
            return '';
        }

        const match = normalized.match(/(\d+)/);
        if (match) {
            const floorNumber = Number.parseInt(match[1], 10);
            if (!Number.isNaN(floorNumber) && floorNumber > 0) {
                return `${floorNumber}${this.getOrdinalSuffix(floorNumber)} Floor`;
            }
        }

        return floorValue;
    }

    getOrdinalSuffix(value) {
        const absoluteValue = Math.abs(Number(value) || 0);
        const lastTwoDigits = absoluteValue % 100;
        if (lastTwoDigits >= 11 && lastTwoDigits <= 13) {
            return 'th';
        }

        const lastDigit = absoluteValue % 10;
        if (lastDigit === 1) {
            return 'st';
        }
        if (lastDigit === 2) {
            return 'nd';
        }
        if (lastDigit === 3) {
            return 'rd';
        }
        return 'th';
    }

    cloneRoommateMap(source) {
        const clone = {};
        Object.keys(source || {}).forEach((key) => {
            const value = source[key];
            clone[key] = Array.isArray(value) ? [...value] : value;
        });
        return clone;
    }

    removeResidenceOrderEntries(source, residenceId) {
        const updated = {};
        const prefix = `${residenceId}_`;
        Object.keys(source || {}).forEach((key) => {
            if (!key.startsWith(prefix)) {
                updated[key] = source[key];
            }
        });
        return updated;
    }

    parsePreferenceOrder(orderValue, preferenceLabel) {
        const numeric = Number.parseInt(orderValue, 10);
        if (!Number.isNaN(numeric) && numeric >= 1 && numeric <= MAX_SELECTION) {
            return numeric;
        }

        if (preferenceLabel) {
            const match = String(preferenceLabel).match(/(\d+)/);
            if (match) {
                const parsed = Number.parseInt(match[1], 10);
                if (!Number.isNaN(parsed) && parsed >= 1 && parsed <= MAX_SELECTION) {
                    return parsed;
                }
            }
        }

        return null;
    }

    toSharingLabel(capacityValue) {
        const capacity = Number.parseInt(capacityValue, 10);
        if (Number.isNaN(capacity) || capacity <= 0) {
            return null;
        }
        if (capacity === 1) {
            return 'Single sharing';
        }
        if (capacity === 2) {
            return 'Twin sharing';
        }
        if (capacity === 3) {
            return 'Triple sharing';
        }
        return `${capacity} sharing`;
    }

    parseAmenities(value) {
        const items = new Set();

        if (Array.isArray(value)) {
            value.forEach((item) => {
                const text = this.normalizeText(item);
                if (text) {
                    items.add(text);
                }
            });
        } else if (value !== null && value !== undefined) {
            String(value)
                .split(/[;,]/)
                .forEach((item) => {
                    const text = this.normalizeText(item);
                    if (text) {
                        items.add(text);
                    }
                });
        }

        return Array.from(items);
    }

    parseFloorOptions(value) {
        const floorOptions = [];
        const seen = new Set();

        const collect = (item) => {
            const text = this.normalizeSelectedFloorValue(item);
            if (!text) {
                return;
            }
            const key = text.toLowerCase();
            if (seen.has(key)) {
                return;
            }
            floorOptions.push(text);
            seen.add(key);
        };

        if (Array.isArray(value)) {
            value.forEach((item) => collect(item));
        } else if (value !== null && value !== undefined) {
            collect(value);
        }

        return floorOptions.sort((left, right) => left.localeCompare(right, undefined, { numeric: true }));
    }

    mergeFloorOptions(baseOptions, additionalOptions) {
        return this.parseFloorOptions([
            ...(Array.isArray(baseOptions) ? baseOptions : []),
            ...(Array.isArray(additionalOptions) ? additionalOptions : [])
        ]);
    }

    resolveAcLabel(acValue, amenities) {
        const ac = this.normalizeText(acValue);
        if (ac) {
            if (/^(yes|ac)$/i.test(ac)) {
                return 'Yes';
            }
            if (/^(no|non[\s-]*ac)$/i.test(ac)) {
                return 'No';
            }
            return ac;
        }

        const amenityText = (amenities || []).join(' ').toLowerCase();
        if (/non[\s-]*ac|without[\s-]*ac/.test(amenityText)) {
            return 'No';
        }
        if (/\bac\b|air[\s-]*conditioning/.test(amenityText)) {
            return 'Yes';
        }
        return null;
    }

    resolveBathroomLabel(bathroomValue, amenities) {
        const bathroom = this.normalizeText(bathroomValue);
        if (bathroom) {
            if (/^(attached|attached\s*bath(room)?|ensuite)$/i.test(bathroom)) {
                return 'Attached';
            }
            if (/^(common|common\s*bath(room)?|shared\s*bath(room)?)$/i.test(bathroom)) {
                return 'Common';
            }
            return bathroom;
        }

        const amenityText = (amenities || []).join(' ').toLowerCase();
        if (/attached[\s-]*bath|ensuite/.test(amenityText)) {
            return 'Attached';
        }
        if (/common[\s-]*bath|shared[\s-]*bath/.test(amenityText)) {
            return 'Common';
        }
        return null;
    }

    formatInr(amountValue) {
        const amount = this.toNumber(amountValue);
        if (!Number.isFinite(amount)) {
            return 'INR --';
        }

        return `INR ${amount.toLocaleString('en-IN', { maximumFractionDigits: 0 })}`;
    }

    parseEmails(value) {
        const uniqueEmails = new Set();

        const collect = (item) => {
            const normalized = this.normalizeEmail(item);
            if (normalized) {
                uniqueEmails.add(normalized);
            }
        };

        if (Array.isArray(value)) {
            value.forEach((item) => collect(item));
        } else if (value !== null && value !== undefined) {
            String(value)
                .split(/[;,]/)
                .forEach((item) => collect(item));
        }

        return Array.from(uniqueEmails);
    }

    /** Always two slots (Email 1, Email 2) per residence + preference priority. */
    normalizeRoommatePair(value) {
        if (Array.isArray(value) && value.length >= 2) {
            return [String(value[0] ?? '').trim(), String(value[1] ?? '').trim()];
        }
        if (Array.isArray(value) && value.length === 1) {
            return [String(value[0] ?? '').trim(), ''];
        }
        return ['', ''];
    }

    pairToNonEmptyEmailList(pair) {
        const [a, b] = this.normalizeRoommatePair(pair);
        const out = [];
        if (a) {
            out.push(a);
        }
        if (b) {
            out.push(b);
        }
        return out;
    }

    getCurrentRoommateRawValues() {
        const inputs = Array.from(this.template.querySelectorAll('input.roommate-email-input'));
        const currentInputs = this.roommateInputs;

        const rawValues = ['', ''];
        if (inputs.length) {
            inputs.forEach((el) => {
                const idx = Number.parseInt(el.dataset.index, 10);
                if (idx === 1) {
                    rawValues[0] = el?.value ?? '';
                }
                if (idx === 2) {
                    rawValues[1] = el?.value ?? '';
                }
            });
            return rawValues;
        }

        return [
            currentInputs.find((item) => item.index === 1)?.value || '',
            currentInputs.find((item) => item.index === 2)?.value || ''
        ];
    }

    validateRoommateEmailInputs() {
        const inputs = Array.from(this.template.querySelectorAll('input.roommate-email-input'));
        const rawValues = this.getCurrentRoommateRawValues();
        const normalizedValues = rawValues.map((value) => this.normalizeText(value)?.toLowerCase() || null);

        const duplicateEmails = new Set();
        normalizedValues.forEach((value, idx) => {
            if (!value) {
                return;
            }
            const firstIndex = normalizedValues.findIndex((item) => item === value);
            if (firstIndex !== -1 && firstIndex !== idx) {
                duplicateEmails.add(value);
            }
        });

        let hasErrors = false;
        const newErrors = { 1: '', 2: '' };
        const hasAnyRoommateEmail = rawValues.some((raw) => !!this.normalizeText(raw));
        if (this.selectedRes?.allowRoommatePreference === true && !hasAnyRoommateEmail) {
            newErrors[1] = this.buildMissingRoommateEmailMessage(this.currentPriority);
            hasErrors = true;
        }

        rawValues.forEach((raw, idx) => {
            const trimmed = this.normalizeText(raw);
            const normalized = normalizedValues[idx];
            const inputIndex = idx === 0 ? 1 : 2;

            let message = '';
            if (!newErrors[inputIndex] && trimmed) {
                if (/[;,]/.test(trimmed)) {
                    message = 'Enter only one email address per field.';
                } else if (!this.isValidEmail(trimmed)) {
                    message = 'Enter a valid email address.';
                } else if (normalized && duplicateEmails.has(normalized)) {
                    message = 'Duplicate email is not allowed.';
                }
            }

            newErrors[inputIndex] = message;
            if (message) {
                hasErrors = true;
            }
        });

        this.roommateErrors = newErrors;

        // Clear native browser tooltips
        inputs.forEach((el) => {
            if (typeof el.setCustomValidity === 'function') {
                el.setCustomValidity('');
                el.reportValidity();
            }
        });

        return !hasErrors;
    }

    applyRoommateValidationIssues(issues) {
        const normalizedIssues = Array.isArray(issues)
            ? issues.filter((issue) => this.normalizeText(issue?.residenceId))
            : [];

        if (!normalizedIssues.length) {
            return false;
        }

        const firstIssue = normalizedIssues[0];
        const targetResidenceId = this.normalizeText(firstIssue?.residenceId);
        const targetOrder = this.parsePreferenceOrder(firstIssue?.order, null) || 1;
        const hasTargetResidence = (this.residences || []).some((residence) => residence.id === targetResidenceId);
        if (!targetResidenceId || !hasTargetResidence) {
            return false;
        }

        if (!this.isPreferenceModalOpen || this.selectedRes?.id !== targetResidenceId) {
            this.openPreferenceModal(targetResidenceId);
        }

        if (this.currentPriority !== targetOrder) {
            this._lastSyncedPriority = null;
            this.roommateErrors = { 1: '', 2: '' };
            this.currentPriority = targetOrder;
        }

        const newErrors = { 1: '', 2: '' };
        normalizedIssues.forEach((issue) => {
            const issueResidenceId = this.normalizeText(issue?.residenceId);
            const issueOrder = this.parsePreferenceOrder(issue?.order, null) || 1;
            const slot = Number.parseInt(issue?.slot, 10);
            if (issueResidenceId !== targetResidenceId || issueOrder !== targetOrder || (slot !== 1 && slot !== 2)) {
                return;
            }

            newErrors[slot] = this.normalizeText(issue?.message) || 'This email is not registered in the system.';
        });

        this.roommateErrors = newErrors;
        return Object.values(newErrors).some((message) => !!this.normalizeText(message));
    }

    validateSelectedResidenceEmails() {
        const selectedResidences = (this.residences || [])
            .filter((residence) => residence?.isSelected && residence?.allowRoommatePreference === true)
            .sort((a, b) => {
                const aOrder = this.parsePreferenceOrder(a.preferenceOrder, null) || 999;
                const bOrder = this.parsePreferenceOrder(b.preferenceOrder, null) || 999;
                return aOrder - bOrder;
            });

        for (const residence of selectedResidences) {
            const order = this.parsePreferenceOrder(residence.preferenceOrder, null) || 1;
            const key = `${residence.id}_${order}`;
            const pair = this.normalizeRoommatePair(this.roommatesByResidenceAndOrder[key]);
            const emails = this.pairToNonEmptyEmailList(pair).length > 0
                ? this.pairToNonEmptyEmailList(pair)
                : this.parseEmails(residence.roommateEmails);

            if (!emails.length) {
                this.openRoommateValidationForResidence(
                    residence.id,
                    order,
                    this.buildMissingRoommateEmailMessage(order)
                );
                return false;
            }

            if (emails.some((email) => !this.isValidEmail(email))) {
                this.openRoommateValidationForResidence(
                    residence.id,
                    order,
                    'Enter a valid email address.'
                );
                return false;
            }
        }

        return true;
    }

    buildMissingRoommateEmailMessage(order) {
        return `At least one roommate email is mandatory for Preference ${order}.`;
    }

    openRoommateValidationForResidence(residenceId, order, message) {
        if (!this.isPreferenceModalOpen || this.selectedRes?.id !== residenceId) {
            this.openPreferenceModal(residenceId);
        }

        if (this.currentPriority !== order) {
            this._lastSyncedPriority = null;
            this.roommateErrors = { 1: '', 2: '' };
            this.currentPriority = order;
        }

        this.roommateErrors = {
            1: this.normalizeText(message) || 'At least one roommate email is mandatory.',
            2: ''
        };
    }

    isValidEmail(value) {
        const text = this.normalizeText(value);
        if (!text) {
            return false;
        }
        if (/\s/.test(text)) {
            return false;
        }
        // Simple, strict-enough email format check for portal input validation
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(text);
    }

    normalizeEmail(value) {
        const text = this.normalizeText(value);
        if (!text || !this.isValidEmail(text)) {
            return null;
        }
        return text.toLowerCase();
    }

    normalizeText(value) {
        if (value === null || value === undefined) {
            return null;
        }
        const text = String(value).trim();
        return text || null;
    }

    toNumber(value) {
        if (value === null || value === undefined || value === '') {
            return null;
        }
        const numberValue = Number(value);
        return Number.isFinite(numberValue) ? numberValue : null;
    }

    showErrorToast(message) {
        const toast = this.template.querySelector('c-custom-toast');
        if (toast) {
            toast.showToast('Unable to Save', message, 'error');
            return;
        }

        console.error(message);
    }

    handleSuccessModalAnimationEnd(event) {
        if (
            event.target !== event.currentTarget ||
            !this.isSuccessModalOpen ||
            !this.successModalAutoCloseDuration ||
            this.successModalTimeoutId
        ) {
            return;
        }

        this.finishSuccessModal();
    }

    clearSuccessModalTimeout() {
        if (!this.successModalTimeoutId) {
            return;
        }

        window.clearTimeout(this.successModalTimeoutId);
        this.successModalTimeoutId = null;
    }

    finishSuccessModal() {
        this.clearSuccessModalTimeout();

        const callback = this.pendingSuccessModalCallback;
        this.isSuccessModalOpen = false;
        this.pendingSuccessModalCallback = null;
        this.successModalAutoCloseDuration = 0;
        if (callback) {
            callback();
        }
    }

    handleToastClosed() {
        if (!this.pendingToastNavigationState) {
            return;
        }

        const state = { ...this.pendingToastNavigationState };
        this.pendingToastNavigationState = null;
        this.navigateToResidenceAllocation(state);
    }

    resolveAutoCloseDuration(value) {
        const parsed = Number(value);
        return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
    }

    get successModalStyle() {
        if (!this.successModalAutoCloseDuration) {
            return '';
        }

        return `animation-name: ${this.successModalAnimationName}; animation-duration: ${this.successModalAutoCloseDuration}ms;`;
    }

    getErrorMessage(error) {
        if (!error) {
            return 'Unexpected error while saving preferences.';
        }

        if (Array.isArray(error.body)) {
            return error.body.map((item) => item.message).join(', ');
        }

        if (error.body && error.body.message) {
            return error.body.message;
        }

        if (error.message) {
            return error.message;
        }

        return 'Unexpected error while saving preferences.';
    }
}