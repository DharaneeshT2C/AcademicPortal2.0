import { LightningElement, api, track } from 'lwc';

export default class MockInterviewSession extends LightningElement {
    @api interviewId;
    @track sessionState = 'recording';
    @track showCompletionModal = false;
    @track timerDisplay = '10:44';
    @track _micOn = true;
    @track _camOn = true;
    get micBtnClass() { return this._micOn ? 'ctrl-btn ctrl-mic' : 'ctrl-btn ctrl-mic off'; }
    get camBtnClass() { return this._camOn ? 'ctrl-btn ctrl-camera' : 'ctrl-btn ctrl-camera off'; }
    get micLabel() { return this._micOn ? '🎙' : '🚫'; }
    get camLabel() { return this._camOn ? '📷' : '🚫'; }
    handleToggleMic() { this._micOn = !this._micOn; }
    handleToggleCam() { this._camOn = !this._camOn; }

    get isRecording() { return this.sessionState === 'recording'; }

    get transcriptLines() {
        return [
            { key: 'q1', speaker: 'AI', text: 'Hi, Thank you for coming in today. Can you start by telling me a bit about your design process from initial concept to final implementation?' },
            { key: 'a1', speaker: 'You', text: 'Sure, I\'m happy to. My design process typically begins with understanding the project requirements and conducting user research. I gather insights through methods like user interviews, surveys, and usability testing to ensure a clear understanding of user needs...' }
        ];
    }

    handleEndInterview() { this.showCompletionModal = true; }
    handleCloseModal() { this.showCompletionModal = false; }
    handleViewResults() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'interview-results' } }));
    }
    handleBackToPrepHub() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'prep-hub' } }));
    }
    stopProp(event) { event.stopPropagation(); }
}