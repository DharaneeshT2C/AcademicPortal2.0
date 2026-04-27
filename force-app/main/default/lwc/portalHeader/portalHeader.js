import { LightningElement, wire } from 'lwc';
import OrganizationDefaultsApiController from '@salesforce/apex/OrganizationDefaultsApiController.getOrganizationDefaults';
import KEN42LOGO from '@salesforce/resourceUrl/KEN42LOGO';

const DEFAULT_PRIMARY = '#3061FF';
const DEFAULT_SECONDARY = '#EAEFFF';
const THEME_PRIMARY_STORAGE_KEY = 'ken_theme_primary';
const THEME_SECONDARY_STORAGE_KEY = 'ken_theme_secondary';

export default class PortalHeader extends LightningElement {
    themeLoading = true;
    organizationDefaults = {};
    ken42Logo = KEN42LOGO;

    connectedCallback() {
        const storedTheme = this.getStoredTheme();
        if (storedTheme) {
            this.applyTheme(storedTheme.primary, storedTheme.secondary);
            this.themeLoading = false;
            return;
        }

        this.applyTheme();
        Promise.resolve().then(() => {
            if (this.themeLoading) {
                this.themeLoading = false;
            }
        });
    }

    resolveThemeColor(value, fallback) {
        if (typeof value === 'string' && value.trim()) {
            return value.trim();
        }
        return fallback;
    }

    getStoredTheme() {
        try {
            const primary = window.localStorage.getItem(THEME_PRIMARY_STORAGE_KEY);
            const secondary = window.localStorage.getItem(THEME_SECONDARY_STORAGE_KEY);
            if (!primary && !secondary) {
                return null;
            }
            return {
                primary: this.resolveThemeColor(primary, DEFAULT_PRIMARY),
                secondary: this.resolveThemeColor(secondary, DEFAULT_SECONDARY)
            };
        } catch (e) {
            return null;
        }
    }

    storeTheme(primary, secondary) {
        try {
            window.localStorage.setItem(THEME_PRIMARY_STORAGE_KEY, primary);
            window.localStorage.setItem(THEME_SECONDARY_STORAGE_KEY, secondary);
        } catch (e) {
            // no-op
        }
    }

    applyTheme(primaryInput, secondaryInput) {
        const primary = this.resolveThemeColor(primaryInput || this.organizationDefaults?.primary, DEFAULT_PRIMARY);
        const secondary = this.resolveThemeColor(secondaryInput || this.organizationDefaults?.secondary, DEFAULT_SECONDARY);
        document.documentElement.style.setProperty('--primary-color', primary);
        document.documentElement.style.setProperty('--secondary-color', secondary);
    }

    @wire(OrganizationDefaultsApiController)
    wiredOrganizationDefaults({ data, error }) {
        if (data) {
            this.organizationDefaults = data;
            const primary = this.resolveThemeColor(data.primary, DEFAULT_PRIMARY);
            const secondary = this.resolveThemeColor(data.secondary, DEFAULT_SECONDARY);
            this.storeTheme(primary, secondary);
            this.applyTheme(primary, secondary);
            this.themeLoading = false;
        } else if (error) {
            this.organizationDefaults = {};
            this.applyTheme();
            this.themeLoading = false;
        }
    }

    get showSkeleton() {
        return this.themeLoading;
    }
}