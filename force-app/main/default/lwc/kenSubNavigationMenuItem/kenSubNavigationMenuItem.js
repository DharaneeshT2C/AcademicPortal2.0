import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPrimaryColor from '@salesforce/apex/KenPortalConfigController.getPortalConfigs';
// import GalleryIcon from '@salesforce/resourceUrl/GalleryIcon';
// import ResourceIcon from '@salesforce/resourceUrl/ResourceIcon';

const ICON_BY_LABEL = {
    Gallery: 'utility:image',
    Resource: 'utility:opened_folder'
};

export default class KenSubNavigationMenuItem extends NavigationMixin(LightningElement) {
    @api item = {};
    @api isSelected = false;
    @track href = 'javascript:void(0);';

    pageReference;

    connectedCallback() {
        getPrimaryColor().then(color => {
            document.documentElement.style.setProperty('--primary-color', color?.primaryColor);
            document.documentElement.style.setProperty('--secondary-color', color?.secondaryColor);
            document.documentElement.style.setProperty('--tertiary-color', color?.tertiaryColor);  
        }).catch(() => {
            console.log('Error getting primary color');
        });
        const { actionType, actionValue } = this.item;

        if (!actionValue) {
            console.warn(
                'SubNavigationMenuItem missing actionValue:',
                JSON.stringify(this.item)
            );
            return;
        }

        if (actionType === 'InternalLink' || actionType === 'ExternalLink') {
            this.pageReference = {
                type: 'standard__webPage',
                attributes: { url: actionValue }
            };
        }

        if (this.pageReference) {
            this[NavigationMixin.GenerateUrl](this.pageReference).then(url => {
                this.href = url;
            });
        }
    }

    get itemClass() {
        let classes = 'nav-item';

        if (this.isSelected) {
            classes += ' selected';
        }

        if (this.item?.isActive) {
            classes += ' active';
        }
        return classes;
    }

    get textClass() {
        return 'nav-text';
    }

    get label() {
        return this.item?.label || '';
    }

    get iconUrl() {
        return ICON_BY_LABEL[this.item.label];
    }

    get isUtilityIcon() {
        const url = this.iconUrl;
        return url && url.startsWith('utility:');
    }

    handleClick(evt) {
        const selectEvent = new CustomEvent('submenuselect', {
            detail: {
                selectedItem: this.item,
                selectedItemId: this.item.id || this.item.label
            },
            bubbles: true
        });
        this.dispatchEvent(selectEvent);

        evt.stopPropagation();
        evt.preventDefault();

        if (this.pageReference) {
            this[NavigationMixin.GenerateUrl](this.pageReference).then(generatedUrl => {
                const isExternal = this.item.actionType === 'ExternalLink';
                window.open(generatedUrl, isExternal ? '_blank' : '_self');
            });
        } else {
            console.error(
                `Navigation menu actionType "${this.item.actionType}" not implemented for item`,
                JSON.stringify(this.item)
            );
        }
    }
}