import { LightningElement, api } from 'lwc';

const THEMES = {
    green:  { bg: '#2A7A4B', bg2: '#1e6038', bg3: '#348f59', accent: '#FFD166', accent2: '#fff', accent3: '#A8EDBA' },
    purple: { bg: '#6B3A9E', bg2: '#53228A', bg3: '#8146b8', accent: '#FFD166', accent2: '#fff', accent3: '#CDB5F0' },
    blue:   { bg: '#3B4FD8', bg2: '#2a3ab8', bg3: '#4f62e8', accent: '#FFD166', accent2: '#fff', accent3: '#B0BFFF' },
    orange: { bg: '#C2651A', bg2: '#a34e0d', bg3: '#d97c2a', accent: '#FFD166', accent2: '#fff', accent3: '#FFD6A5' }
};

function makeSvg(t, id) {
    return `<svg xmlns="http://www.w3.org/2000/svg" width="100%" height="140" viewBox="0 0 300 140" preserveAspectRatio="xMidYMid slice">
  <defs>
    <linearGradient id="bg${id}" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="${t.bg2}"/>
      <stop offset="50%" stop-color="${t.bg}"/>
      <stop offset="100%" stop-color="${t.bg3}"/>
    </linearGradient>
    <filter id="sh${id}"><feDropShadow dx="1" dy="2" stdDeviation="2" flood-color="rgba(0,0,0,0.18)"/></filter>
  </defs>
  <rect width="300" height="140" fill="url(#bg${id})"/>
  <!-- dot scatter -->
  <circle cx="12" cy="12" r="2.5" fill="rgba(255,255,255,0.13)"/>
  <circle cx="35" cy="8" r="1.8" fill="rgba(255,255,255,0.1)"/>
  <circle cx="55" cy="20" r="2.2" fill="rgba(255,255,255,0.09)"/>
  <circle cx="8" cy="40" r="1.5" fill="rgba(255,255,255,0.1)"/>
  <circle cx="280" cy="14" r="2.5" fill="rgba(255,255,255,0.1)"/>
  <circle cx="260" cy="28" r="1.8" fill="rgba(255,255,255,0.08)"/>
  <circle cx="292" cy="98" r="2" fill="rgba(255,255,255,0.1)"/>
  <circle cx="248" cy="122" r="1.5" fill="rgba(255,255,255,0.08)"/>
  <circle cx="20" cy="112" r="2" fill="rgba(255,255,255,0.09)"/>
  <circle cx="42" cy="132" r="1.5" fill="rgba(255,255,255,0.07)"/>
  <!-- Clipboard/notebook -->
  <g transform="translate(26,18)" filter="url(#sh${id})">
    <rect x="0" y="8" width="74" height="90" rx="7" fill="${t.accent2}" opacity="0.93"/>
    <rect x="22" y="2" width="30" height="12" rx="4" fill="${t.accent}"/>
    <rect x="28" y="0" width="18" height="9" rx="3" fill="${t.accent}"/>
    <rect x="8" y="27" width="58" height="4" rx="2" fill="${t.bg2}" opacity="0.12"/>
    <rect x="8" y="37" width="46" height="4" rx="2" fill="${t.bg2}" opacity="0.12"/>
    <rect x="8" y="47" width="54" height="4" rx="2" fill="${t.bg2}" opacity="0.12"/>
    <rect x="8" y="57" width="38" height="4" rx="2" fill="${t.bg2}" opacity="0.12"/>
    <rect x="8" y="67" width="50" height="4" rx="2" fill="${t.bg2}" opacity="0.12"/>
    <!-- sticky note -->
    <rect x="38" y="53" width="28" height="28" rx="3" fill="${t.accent}" opacity="0.96"/>
    <rect x="42" y="59" width="20" height="3" rx="1.5" fill="${t.bg2}" opacity="0.28"/>
    <rect x="42" y="65" width="15" height="3" rx="1.5" fill="${t.bg2}" opacity="0.28"/>
    <rect x="42" y="71" width="18" height="3" rx="1.5" fill="${t.bg2}" opacity="0.28"/>
  </g>
  <!-- Calculator -->
  <g transform="translate(174,14)" filter="url(#sh${id})">
    <rect width="70" height="92" rx="8" fill="${t.accent2}" opacity="0.9"/>
    <rect x="6" y="8" width="58" height="23" rx="4" fill="${t.bg2}" opacity="0.78"/>
    <text x="56" y="26" font-size="11" font-family="monospace" text-anchor="end" fill="${t.accent3}" opacity="0.9">42.5</text>
    <rect x="6" y="37" width="13" height="11" rx="2.5" fill="${t.accent3}" opacity="0.7"/>
    <rect x="23" y="37" width="13" height="11" rx="2.5" fill="${t.accent3}" opacity="0.7"/>
    <rect x="40" y="37" width="13" height="11" rx="2.5" fill="${t.accent3}" opacity="0.7"/>
    <rect x="57" y="37" width="7" height="11" rx="2.5" fill="${t.accent}" opacity="0.9"/>
    <rect x="6" y="52" width="13" height="11" rx="2.5" fill="${t.accent3}" opacity="0.6"/>
    <rect x="23" y="52" width="13" height="11" rx="2.5" fill="${t.accent3}" opacity="0.6"/>
    <rect x="40" y="52" width="13" height="11" rx="2.5" fill="${t.accent3}" opacity="0.6"/>
    <rect x="57" y="52" width="7" height="11" rx="2.5" fill="${t.accent}" opacity="0.9"/>
    <rect x="6" y="67" width="13" height="11" rx="2.5" fill="${t.accent3}" opacity="0.6"/>
    <rect x="23" y="67" width="13" height="11" rx="2.5" fill="${t.accent3}" opacity="0.6"/>
    <rect x="40" y="67" width="13" height="11" rx="2.5" fill="${t.accent3}" opacity="0.6"/>
    <rect x="57" y="67" width="7" height="24" rx="2.5" fill="${t.accent}" opacity="0.9"/>
    <rect x="6" y="82" width="30" height="11" rx="2.5" fill="${t.accent3}" opacity="0.6"/>
    <rect x="40" y="82" width="13" height="11" rx="2.5" fill="${t.accent3}" opacity="0.6"/>
  </g>
  <!-- Pencil -->
  <g transform="translate(137,40) rotate(-33)">
    <rect width="11" height="56" rx="2.5" fill="${t.accent}" opacity="0.9"/>
    <polygon points="0,56 11,56 5.5,70" fill="${t.accent2}" opacity="0.88"/>
    <polygon points="2,64 9,64 5.5,70" fill="${t.bg2}" opacity="0.45"/>
    <rect width="11" height="7" rx="2.5" fill="${t.bg2}" opacity="0.2"/>
    <rect x="1.5" y="9" width="8" height="3" rx="1" fill="${t.bg2}" opacity="0.18"/>
    <rect x="1.5" y="14" width="8" height="3" rx="1" fill="${t.bg2}" opacity="0.18"/>
  </g>
  <!-- Ruler -->
  <g transform="translate(20,108) rotate(-7)">
    <rect width="124" height="19" rx="3.5" fill="${t.accent2}" opacity="0.72"/>
    <rect width="124" height="7" rx="3.5" fill="${t.accent}" opacity="0.38"/>
    <line x1="10" y1="7" x2="10" y2="19" stroke="${t.bg2}" stroke-width="1" opacity="0.28"/>
    <line x1="20" y1="7" x2="20" y2="16" stroke="${t.bg2}" stroke-width="1" opacity="0.28"/>
    <line x1="30" y1="7" x2="30" y2="19" stroke="${t.bg2}" stroke-width="1" opacity="0.28"/>
    <line x1="40" y1="7" x2="40" y2="16" stroke="${t.bg2}" stroke-width="1" opacity="0.28"/>
    <line x1="50" y1="7" x2="50" y2="19" stroke="${t.bg2}" stroke-width="1" opacity="0.28"/>
    <line x1="60" y1="7" x2="60" y2="16" stroke="${t.bg2}" stroke-width="1" opacity="0.28"/>
    <line x1="70" y1="7" x2="70" y2="19" stroke="${t.bg2}" stroke-width="1" opacity="0.28"/>
    <line x1="80" y1="7" x2="80" y2="16" stroke="${t.bg2}" stroke-width="1" opacity="0.28"/>
    <line x1="90" y1="7" x2="90" y2="19" stroke="${t.bg2}" stroke-width="1" opacity="0.28"/>
    <line x1="100" y1="7" x2="100" y2="16" stroke="${t.bg2}" stroke-width="1" opacity="0.28"/>
    <line x1="110" y1="7" x2="110" y2="19" stroke="${t.bg2}" stroke-width="1" opacity="0.28"/>
  </g>
  <!-- Sparkles -->
  <text x="156" y="28" font-size="14" fill="${t.accent}" opacity="0.65">✦</text>
  <text x="255" y="114" font-size="10" fill="${t.accent2}" opacity="0.35">✦</text>
  <text x="163" y="124" font-size="8" fill="${t.accent}" opacity="0.45">★</text>
</svg>`;
}

let _seq = 0;

export default class CourseThumbnail extends LightningElement {
    @api theme = 'green';
    @api isCurrent = false;

    _id = 'ct' + (++_seq);

    renderedCallback() {
        const root = this.template.querySelector('.thumb-root');
        if (!root) return;
        const t = THEMES[this.theme] || THEMES.green;
        root.innerHTML = makeSvg(t, this._id);
        if (this.isCurrent) {
            const badge = document.createElement('span');
            badge.textContent = 'Current';
            badge.style.cssText = 'position:absolute;top:10px;right:10px;font-size:11px;padding:4px 12px;border-radius:9999px;background:rgba(255,255,255,0.95);color:#16a34a;font-weight:600;font-family:inherit;pointer-events:none;backdrop-filter:blur(4px);z-index:2;letter-spacing:0.01em';
            root.style.position = 'relative';
            root.appendChild(badge);
        }
    }
}