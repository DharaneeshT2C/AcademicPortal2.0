import { LightningElement } from 'lwc';
import calendarIcon from '@salesforce/resourceUrl/calendarIcon';
import chatIcon from '@salesforce/resourceUrl/chatIcon';
import gearIcon from '@salesforce/resourceUrl/gearIcon';
import notifyIcon from '@salesforce/resourceUrl/notifyIcon';

export default class PortalHeaderRight extends LightningElement {
    calendarIcon = calendarIcon;
    chatIcon = chatIcon;
    gearIcon = gearIcon;
    notifyIcon = notifyIcon;
}