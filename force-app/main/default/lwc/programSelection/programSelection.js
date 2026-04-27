import { LightningElement, track } from 'lwc';
import { programOptions } from 'c/mockData';
import selectProgram from '@salesforce/apex/KenLearnController.selectProgram';

export default class ProgramSelection extends LightningElement {
    @track programs = programOptions.map(p => ({ ...p, cardClass: p.selected ? 'prog-card selected' : 'prog-card', dotClass: p.selected ? 'radio-dot checked' : 'radio-dot' }));
    @track _saving = false;
    @track _error;

    handleSelect(event) {
        const id = event.currentTarget.dataset.id;
        this.programs = this.programs.map(p => ({
            ...p,
            selected: p.id === id,
            cardClass: p.id === id ? 'prog-card selected' : 'prog-card',
            dotClass: p.id === id ? 'radio-dot checked' : 'radio-dot'
        }));
    }

    handleSubmit() {
        if (this._saving) return;
        const picked = this.programs.find(p => p.selected);
        if (!picked) {
            this._error = 'Please pick a program before submitting.';
            return;
        }
        this._saving = true;
        this._error = null;
        selectProgram({ programName: picked.title || picked.name || picked.id })
            .then(() => {
                this._saving = false;
                this.dispatchEvent(new CustomEvent('navigate', { detail: { route: 'semester-detail' } }));
            })
            .catch(err => {
                this._saving = false;
                const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not save your selection.';
                this._error = msg;
            });
    }
    get hasError() { return !!this._error; }
    get errorMessage() { return this._error; }
    get submitLabel() { return this._saving ? 'Saving…' : 'Submit'; }
    get isSubmitDisabled() { return this._saving; }

    handleDiscard() {
        this.dispatchEvent(new CustomEvent('navigate', { detail: { route: 'semester-detail' } }));
    }

    handleDownloadBrochure(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        const p = this.programs.find(x => x.id === id) || {};
        const lines = [
            'Program Brochure',
            'Title: ' + (p.title || ''),
            'Description: ' + (p.description || ''),
            'Mandatory credits: ' + (p.mandatoryCredits || ''),
            'Elective credits: ' + (p.electiveCredits || '')
        ];
        try {
            const blob = new Blob([lines.join('\n')], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url; a.download = `brochure-${(p.title || 'program').toLowerCase().replace(/\s+/g, '-')}.txt`;
            document.body.appendChild(a); a.click(); document.body.removeChild(a);
            setTimeout(() => URL.revokeObjectURL(url), 1500);
        } catch (e) { /* noop */ }
    }

    handleViewCourses(event) {
        event.stopPropagation();
        this.dispatchEvent(new CustomEvent('navigate', { detail: { route: 'learn' } }));
    }
}