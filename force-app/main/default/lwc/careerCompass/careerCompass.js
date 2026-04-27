import { LightningElement, track } from 'lwc';
import { careerCompassQuestions } from 'c/placementData';

export default class CareerCompass extends LightningElement {
    @track questionIndex = 0;
    @track answers = [];
    @track showResults = false;

    questions = careerCompassQuestions;

    get currentQuestion() {
        return this.questions[this.questionIndex];
    }

    get progress() {
        return Math.round(((this.questionIndex) / this.questions.length) * 100);
    }

    get progressStyle() {
        return 'width:' + this.progress + '%';
    }

    get questionCountLabel() {
        return (this.questionIndex + 1) + ' of ' + this.questions.length;
    }

    get isFirstQuestion() { return this.questionIndex === 0; }
    get isLastQuestion() { return this.questionIndex === this.questions.length - 1; }

    get currentOptions() {
        const q = this.currentQuestion;
        if (!q) return [];
        const selectedAns = this.answers[this.questionIndex];
        return q.options.map(o => ({
            key: o.id,
            ...o,
            cls: selectedAns === o.id ? 'option-btn option-selected' : 'option-btn'
        }));
    }

    get currentAnswer() { return this.answers[this.questionIndex]; }
    get hasAnswer() { return !!this.answers[this.questionIndex]; }
    get noAnswer() { return !this.answers[this.questionIndex]; }

    get recommendedCareers() {
        return [
            { id: 'c1', title: 'UX/UI Designer', match: 95, desc: 'Perfect for creative thinkers who love solving user problems.', tags: ['Creative', 'Tech', 'Design'] },
            { id: 'c2', title: 'Product Manager', match: 88, desc: 'Ideal for strategic thinkers with leadership skills.', tags: ['Strategy', 'Leadership', 'Tech'] },
            { id: 'c3', title: 'Data Analyst', match: 76, desc: 'Great for analytical minds who love working with insights.', tags: ['Analytical', 'Tech', 'Data'] }
        ].map(c => ({ ...c, matchLabel: c.match + '%', tagItems: c.tags.map(t => ({ key: t, label: t })) }));
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'landing' } }));
    }

    handleSelectOption(event) {
        const id = event.currentTarget.dataset.id;
        const newAnswers = [...this.answers];
        newAnswers[this.questionIndex] = id;
        this.answers = newAnswers;
    }

    handleNext() {
        if (!this.hasAnswer) return;
        if (this.isLastQuestion) {
            this.showResults = true;
        } else {
            this.questionIndex += 1;
        }
    }

    handlePrev() {
        if (!this.isFirstQuestion) this.questionIndex -= 1;
    }

    handleRetake() {
        this.questionIndex = 0;
        this.answers = [];
        this.showResults = false;
    }

    handleGoToPlacements() {
        this.dispatchEvent(new CustomEvent('subnavigate', { detail: { route: 'all-jobs' } }));
    }
}