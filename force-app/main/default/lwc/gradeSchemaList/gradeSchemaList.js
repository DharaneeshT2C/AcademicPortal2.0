import { LightningElement, api } from 'lwc';
import { initBrand } from 'c/brandConfigService';

export default class GradeSchemaList extends LightningElement {
    @api schemas = [];

    connectedCallback() {
        initBrand(this.template.host);
    }

    get schemaCards() {
        return (this.schemas || []).map(schema => {
            const schemaId = schema.id || schema.Id || '';
            const relCount = schema.relativeCount || 0;
            const absCount = schema.absoluteCount || 0;
            const totalGrades = schema.letterGradeCount || (relCount + absCount);
            return {
                ...schema,
                id: schemaId,
                relativeCriteriaCount: relCount,
                absoluteCriteriaCount: absCount,
                totalGrades,
                activeLabel: schema.active ? 'Active' : 'Inactive',
                activeBadgeClass: schema.active ? 'gsl-active-badge gsl-active-badge--on' : 'gsl-active-badge gsl-active-badge--off'
            };
        });
    }

    get hasSchemas() {
        return (this.schemas || []).length > 0;
    }

    handleCreate() {
        this.dispatchEvent(new CustomEvent('createschema'));
    }

    handleCardClick(event) {
        const schemaId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('schemaselected', { detail: { schemaId } }));
    }
}