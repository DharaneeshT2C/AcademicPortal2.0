// Shared design-system token service extracted from app.js.
// Import individual functions wherever theme initialisation is needed:
//   import { applyStaticTokens, applyBrandTheme, injectInterFont } from 'c/themeService';

export const STATIC_TOKENS = {
    '--bg-main':        '#F8FAFC',
    '--bg-white':       '#ffffff',
    '--border':         '#E2E8F0',
    '--border-light':   '#F1F5F9',
    '--text-primary':   '#1A1D26',
    '--text-secondary': '#64748B',
    '--text-muted':     '#94A3B8',
    '--success':        '#12B76A',
    '--success-light':  '#ECFDF3',
    '--success-dark':   '#039855',
    '--warning':        '#F79009',
    '--warning-light':  '#FFFAEB',
    '--warning-dark':   '#DC6803',
    '--danger':         '#F04438',
    '--danger-light':   '#FEF3F2',
    '--danger-dark':    '#D92D20',
    '--neutral':        '#667085',
    '--neutral-light':  '#F2F4F7',
    '--shadow-sm':      '0 1px 2px rgba(16,24,40,0.04), 0 1px 3px rgba(16,24,40,0.06)',
    '--shadow-md':      '0 2px 4px rgba(16,24,40,0.04), 0 4px 8px rgba(16,24,40,0.06)',
    '--shadow-lg':      '0 4px 6px rgba(16,24,40,0.04), 0 12px 24px rgba(16,24,40,0.08)',
    '--shadow-xl':      '0 8px 16px rgba(16,24,40,0.06), 0 20px 40px rgba(16,24,40,0.1)',
    '--shadow-hover':   '0 4px 12px rgba(16,24,40,0.08)',
    '--radius-sm':      '8px',
    '--radius-md':      '12px',
    '--radius-lg':      '16px',
    '--radius-xl':      '20px',
    '--radius-full':    '9999px',
    '--font-family':    "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
};

export const BRAND_THEMES = {
    ken: {
        '--primary':        '#4C6EF5',
        '--primary-light':  '#EDF2FF',
        '--primary-dark':   '#3B5BDB',
        '--primary-hover':  '#4263EB',
        '--primary-50':     '#EDF2FF',
        '--primary-100':    '#DBE4FF',
        '--primary-500':    '#4C6EF5',
        '--primary-600':    '#4263EB',
        '--primary-700':    '#3B5BDB',
        '--info':           '#4C6EF5',
        '--info-light':     '#EDF2FF',
        '--sidebar-bg':     '#1a1f36',
        '--spotlight-from': '#6366F1',
        '--spotlight-to':   '#8B5CF6'
    },
    smu: {
        '--primary':        '#D97706',
        '--primary-light':  '#FFF7ED',
        '--primary-dark':   '#B45309',
        '--primary-hover':  '#C2660B',
        '--primary-50':     '#FFF7ED',
        '--primary-100':    '#FFEDD5',
        '--primary-500':    '#F97316',
        '--primary-600':    '#EA580C',
        '--primary-700':    '#C2410C',
        '--info':           '#D97706',
        '--info-light':     '#FFF7ED',
        '--sidebar-bg':     '#2E1F18',
        '--spotlight-from': '#F97316',
        '--spotlight-to':   '#FDBA74'
    }
};

export function applyStaticTokens() {
    const root = document.documentElement;
    Object.keys(STATIC_TOKENS).forEach(k => root.style.setProperty(k, STATIC_TOKENS[k]));
    // Apply font-family to body so it cascades into LWC light DOM.
    document.body.style.fontFamily = STATIC_TOKENS['--font-family'];
}

export function applyBrandTheme(brand) {
    const theme = BRAND_THEMES[brand] || BRAND_THEMES.ken;
    const root = document.documentElement;
    Object.keys(theme).forEach(k => root.style.setProperty(k, theme[k]));
}

// Inject Inter @font-face rules using absolute URLs from the static resource.
// Idempotent — safe to call on every page load.
export function injectInterFont(baseUrl) {
    if (!baseUrl) return;
    if (document.getElementById('inter-font-styles')) return;
    const style = document.createElement('style');
    style.id = 'inter-font-styles';
    style.textContent = [
        ['400', 'Inter-Regular'],
        ['500', 'Inter-Medium'],
        ['600', 'Inter-SemiBold'],
        ['700', 'Inter-Bold'],
        ['800', 'Inter-ExtraBold']
    ].map(([weight, file]) =>
        `@font-face{font-family:'Inter';font-style:normal;font-weight:${weight};` +
        `font-display:swap;src:url('${baseUrl}/${file}.woff2') format('woff2');}`
    ).join('\n');
    document.head.appendChild(style);
}
