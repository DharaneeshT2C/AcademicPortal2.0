import { LightningElement, api, track } from 'lwc';
import createResume from '@salesforce/apex/KenResumeController.createResume';
import updateResume from '@salesforce/apex/KenResumeController.updateResume';

export default class ResumeEditor extends LightningElement {
    @api resumeId;     // Optional: editing an existing resume
    @api initialBody;  // Optional: pre-loaded JSON body
    @track currentStep = 1;
    @track selectedTemplate = 'new-york';
    @track showSaveModal = false;
    @track _saving = false;
    @track _saveError;
    get hasSaveError() { return !!this._saveError; }
    get saveErrorMessage() { return this._saveError; }
    get saveLabel() { return this._saving ? 'Saving…' : 'Save Resume'; }
    get isSaveDisabled() { return this._saving; }

    @track formData = {
        firstName: 'Joshua',
        lastName: 'B',
        gender: 'Male',
        phone: '+91 81694 *****',
        email: 'nupu*****@gmail.com',
        city: 'Chennai',
        country: 'India',
        summary: 'A highly motivated and creative designer with 3+ years of experience in UX/UI design, passionate about creating user-centric digital experiences.'
    };

    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }

    get step1Class() { return this.currentStep >= 1 ? 'wizard-step wizard-step-active' : 'wizard-step'; }
    get step2Class() { return this.currentStep >= 2 ? 'wizard-step wizard-step-active' : 'wizard-step'; }
    get step3Class() { return this.currentStep >= 3 ? 'wizard-step wizard-step-active' : 'wizard-step'; }

    get templates() {
        return [
            { id: 'new-york', name: 'New York', color: '#1E3A8A', selected: this.selectedTemplate === 'new-york' },
            { id: 'toronto', name: 'Toronto', color: '#065F46', selected: this.selectedTemplate === 'toronto' },
            { id: 'london', name: 'London', color: '#7C3AED', selected: this.selectedTemplate === 'london' },
            { id: 'chicago', name: 'Chicago', color: '#B45309', selected: this.selectedTemplate === 'chicago' }
        ].map(t => ({ ...t, cls: t.selected ? 'template-card template-selected' : 'template-card' }));
    }

    get skills() {
        return ['Photoshop', 'Figma', 'AutoLayout', 'Prototyping', 'User Research', 'Wireframing'].map((s, i) => ({ key: 'sk' + i, label: s }));
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'resume-library' } }));
    }

    handleSelectTemplate(event) { this.selectedTemplate = event.currentTarget.dataset.id; }

    handleNext() {
        if (this.currentStep < 3) this.currentStep += 1;
    }

    handlePrev() {
        if (this.currentStep > 1) this.currentStep -= 1;
    }

    handleSave() {
        if (this._saving) return;
        this._saving = true;
        this._saveError = null;
        const name = ((this.formData && (this.formData.firstName || '')) + '_'
                    + (this.formData && (this.formData.lastName || '')))
                    .trim().replace(/_+$/, '') || 'My Resume';
        const body = JSON.stringify(this.formData || {});
        const op = this.resumeId
            ? updateResume({ resumeId: this.resumeId, name, body })
            : createResume({ name, body });
        op.then(() => { this._saving = false; this.showSaveModal = true; })
          .catch(err => {
              this._saving = false;
              const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not save resume.';
              this._saveError = msg;
              // Still show the success modal pattern but flagged with error.
              this.showSaveModal = true;
          });
    }
    handleCloseSaveModal() {
        this.showSaveModal = false;
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'resume-library' } }));
    }

    handleUploadPhoto() {
        const input = document.createElement('input');
        input.type = 'file'; input.accept = 'image/*';
        input.onchange = (e) => {
            const file = e.target.files && e.target.files[0];
            if (!file) return;
            const reader = new FileReader();
            reader.onload = (ev) => { this.formData = Object.assign({}, this.formData, { photoData: ev.target.result }); };
            reader.readAsDataURL(file);
        };
        input.click();
    }

    handleRteFormat(event) {
        const cmd = event.currentTarget.dataset.cmd;
        if (!cmd) return;
        try { document.execCommand(cmd, false, null); } catch (e) { /* deprecated but still works in most browsers */ }
    }

    handleAiContinue() {
        const tip = ' Skilled in collaborative team environments with a track record of shipping user-centred features on schedule.';
        this.formData = Object.assign({}, this.formData, { summary: (this.formData.summary || '') + tip });
    }

    handleAddEducation() {
        const ed = (this.formData.education || []).slice();
        ed.push({ id: 'ed' + Date.now(), school: 'New school', degree: 'New degree', years: '' });
        this.formData = Object.assign({}, this.formData, { education: ed });
    }
    handleAddWork() {
        const ex = (this.formData.experience || []).slice();
        ex.push({ id: 'ex' + Date.now(), title: 'New role', org: 'New employer', range: '' });
        this.formData = Object.assign({}, this.formData, { experience: ex });
    }
    handleAddSkill() {
        const newSkill = (typeof window !== 'undefined' && window.prompt) ? (window.prompt('Add a skill') || '').trim() : '';
        if (!newSkill) return;
        const skills = (this.formData.skills || []).slice();
        skills.push(newSkill);
        this.formData = Object.assign({}, this.formData, { skills });
    }
    handleAddSection(event) {
        const name = event.currentTarget.dataset.section;
        if (!name) return;
        const sections = (this.formData.extraSections || []).slice();
        sections.push({ id: 's' + Date.now(), name, content: '' });
        this.formData = Object.assign({}, this.formData, { extraSections: sections });
    }

    _csvFromForm() {
        const lines = [
            'Resume — ' + ((this.formData.firstName || '') + ' ' + (this.formData.lastName || '')).trim(),
            'City: ' + (this.formData.city || ''),
            '',
            'Summary:',
            this.formData.summary || ''
        ];
        return lines.join('\n');
    }
    handleDownload() {
        try {
            const blob = new Blob([this._csvFromForm()], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url; a.download = 'resume.txt';
            document.body.appendChild(a); a.click(); document.body.removeChild(a);
            setTimeout(() => URL.revokeObjectURL(url), 1500);
        } catch (e) { /* noop */ }
    }

    stopProp(event) { event.stopPropagation(); }
}