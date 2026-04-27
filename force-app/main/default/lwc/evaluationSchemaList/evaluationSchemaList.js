import { LightningElement, api } from 'lwc';
import { initBrand } from 'c/brandConfigService';

export default class EvaluationSchemaList extends LightningElement {
    connectedCallback() { initBrand(this.template.host); }

    @api schemas = [];

    get schemaCards() {
        return (this.schemas || []).map((schema) => {
            const derivedComponentCount = (schema.components || []).length;
            const derivedSubComponentCount = (schema.components || []).reduce(
                (count, component) => count + (component.subComponents || []).length,
                0
            );

            return {
                ...schema,
                componentCount: schema.componentCount ?? derivedComponentCount,
                subComponentCount: schema.subComponentCount ?? derivedSubComponentCount
            };
        });
    }

    get hasSchemas() {
        return (this.schemas || []).length > 0;
    }

    handleCreateSchema() {
        this.dispatchEvent(new CustomEvent('createschema'));
    }

    handleSchemaClick(event) {
        const schemaId = event.currentTarget.dataset.id;
        this.dispatchEvent(
            new CustomEvent('schemaselected', {
                detail: { schemaId }
            })
        );
    }
}