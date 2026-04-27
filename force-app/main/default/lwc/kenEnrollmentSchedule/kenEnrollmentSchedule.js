import { LightningElement } from 'lwc';

export default class KenEnrollmentSchedule extends LightningElement {
    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}