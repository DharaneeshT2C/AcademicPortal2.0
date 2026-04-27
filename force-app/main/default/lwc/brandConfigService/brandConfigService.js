import getExamManagementTheme from '@salesforce/apex/ExamManagementThemeController.getExamManagementTheme';

let _cache = null;
let _pending = null;

function loadTheme() {
    if (_cache) return Promise.resolve(_cache);
    if (_pending) return _pending;

    _pending = getExamManagementTheme()
        .then((data) => {
            _cache = data || {};
            _pending = null;
            return _cache;
        })
        .catch((err) => {
            _pending = null;
            // Keep UI usable with default CSS fallback values.
            console.error('[ExamManagementTheme] Failed to load custom setting values:', err);
            return {};
        });

    return _pending;
}

const KEY_MAP = {
    primaryColor:    '--brand-primary',
    primaryDark:     '--brand-primary-d',
    primaryLight:    '--brand-primary-l',
    secondaryColor:  '--brand-secondary',
    secondaryDark:   '--brand-secondary-d',
    accentColor:     '--brand-accent',
    accentDark:      '--brand-accent-d',
    textPrimary:     '--brand-text',
    textSecondary:   '--brand-text-secondary',
    textMuted:       '--brand-muted',
    textSubtle:      '--brand-text-subtle',
    surfaceWhite:    '--brand-surface',
    surfaceSoft:     '--brand-bg-soft',
    surfacePage:     '--brand-bg-page',
    surfaceCard:     '--brand-bg-card',
    borderDefault:   '--brand-border',
    borderSubtle:    '--brand-border-sub',
    borderAccent:    '--brand-border-accent',
    primaryAlpha10:  '--brand-primary-10',
    primaryAlpha14:  '--brand-primary-14',
    primaryAlpha18:  '--brand-primary-18',
    primaryAlpha28:  '--brand-primary-28',
    primaryAlpha36:  '--brand-primary-36',
    accentAlpha10:   '--brand-accent-10',
    accentAlpha14:   '--brand-accent-14',
    shadowXs:        '--brand-shadow-xs',
    shadowSm:        '--brand-shadow-sm',
    shadowMd:        '--brand-shadow-md',
    shadowLg:        '--brand-shadow-lg',
    shadowHover:     '--brand-shadow-hov',
    dangerColor:     '--brand-danger',
    successColor:    '--brand-success',
    warningColor:    '--brand-warning',
    buttonPrimaryBg:   '--brand-btn-bg',
    buttonPrimaryText: '--brand-btn-text',
    buttonHoverBg:     '--brand-btn-hover-bg',
    hoverBg:           '--brand-hover-bg',
    hoverAccentBg:     '--brand-hover-accent',
    hoverText:         '--brand-hover-text'
};

export function initBrand(hostElement) {
    return loadTheme().then((config) => {
        if (!hostElement) return;
        const style = hostElement.style;
        Object.entries(KEY_MAP).forEach(([jsonKey, cssVar]) => {
            const value = config[jsonKey];
            if (value) {
                style.setProperty(cssVar, value);
            }
        });
    });
}