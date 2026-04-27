import { LightningElement, track } from 'lwc';
import { interviewResultData } from 'c/placementData';

export default class InterviewResults extends LightningElement {
    @track showShareModal = false;
    @track expandedSuggestion = null;

    data = interviewResultData;

    get suggestions() {
        return this.data.suggestions.map(s => ({
            ...s,
            isExpanded: this.expandedSuggestion === s.id,
            expandArrow: this.expandedSuggestion === s.id ? '▲' : '▼',
            bulletItems: s.bullets.map((b, i) => ({ key: 'b' + i, text: b }))
        }));
    }

    get suggestedLessons() {
        return this.data.suggestedLessons.map(l => ({
            ...l,
            tagItems: l.tags.map(t => ({ key: t, label: t }))
        }));
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'prep-hub' } }));
    }

    handleToggleSuggestion(event) {
        const id = event.currentTarget.dataset.id;
        this.expandedSuggestion = this.expandedSuggestion === id ? null : id;
    }

    handleShare() { this.showShareModal = true; }
    handleCloseShare() { this.showShareModal = false; }
    handleRetakeMock() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'prep-hub' } }));
    }
    handleViewMoreCourses() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'prep-hub' } }));
    }
    handleDownloadResults() {
        const lines = ['Interview Results', 'Generated: ' + new Date().toLocaleString(), ''];
        if (this.data.title) lines.push('Title: ' + this.data.title);
        if (this.data.score != null) lines.push('Score: ' + this.data.score);
        (this.data.suggestions || []).forEach(s => {
            lines.push('- ' + (s.title || ''));
            (s.bullets || []).forEach(b => lines.push('  • ' + b));
        });
        try {
            const blob = new Blob([lines.join('\n')], { type: 'text/plain;charset=utf-8' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url; a.download = 'interview-results.txt';
            document.body.appendChild(a); a.click(); document.body.removeChild(a);
            setTimeout(() => URL.revokeObjectURL(url), 1500);
        } catch (e) { /* noop */ }
    }
    handleCopyLink(event) {
        const root = this.template.querySelector('.share-link-input');
        const link = root ? root.value : 'https://link.figma.com/nkPr7...';
        const setText = navigator && navigator.clipboard && navigator.clipboard.writeText
            ? navigator.clipboard.writeText(link)
            : Promise.reject(new Error('clipboard unavailable'));
        setText.then(() => {
            const btn = event && event.currentTarget;
            if (btn) { const orig = btn.textContent; btn.textContent = 'Copied!'; setTimeout(() => { btn.textContent = orig; }, 1500); }
        }).catch(() => {});
    }
    stopProp(event) { event.stopPropagation(); }
}