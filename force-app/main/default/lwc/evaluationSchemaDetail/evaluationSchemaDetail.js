import { LightningElement, api, wire } from 'lwc';
import { initBrand } from 'c/brandConfigService';
import getEvaluationSchemaDetail from '@salesforce/apex/KenExamCyclePlannerController.getEvaluationSchemaDetail';

export default class EvaluationSchemaDetail extends LightningElement {
    connectedCallback() { initBrand(this.template.host); }

    @api schemaId;
    @api schemaRecords = [];

    schema;
    _wireResult;

    @wire(getEvaluationSchemaDetail, { schemaId: '$schemaId' })
    wiredSchema(result) {
        this._wireResult = result;
        const { data } = result;
        if (data) {
            this.schema = data;
        }
    }

    get records() {
        return this.schemaRecords && this.schemaRecords.length ? this.schemaRecords : [];
    }

    get selectedSchema() {
        if (!this.schemaId) {
            return null;
        }
        return this.schema || this.records.find((schema) => schema.id === this.schemaId) || null;
    }

    get componentRows() {
        if (!this.selectedSchema) {
            return [];
        }

        return (this.selectedSchema.components || []).map((component) => {
            const normalizedType = component.type || 'Internal';
            return {
                ...component,
                examCategory: component.examCategory || '',
                examType: component.examType || 'Regular',
                typeClass:
                    normalizedType.toLowerCase() === 'external'
                        ? 'es-type-badge es-type-external'
                        : 'es-type-badge es-type-internal',
                subComponents: (component.subComponents || []).map((subComponent) => ({
                    ...subComponent,
                    enrollmentClass:
                        (subComponent.enrollmentType || '').toLowerCase() === 'auto'
                            ? 'es-enroll-badge es-enroll-auto'
                            : 'es-enroll-badge es-enroll-manual'
                }))
            };
        });
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleEditSchema() {
        this.dispatchEvent(
            new CustomEvent('editschema', {
                detail: { schemaId: this.schemaId }
            })
        );
    }

    handleDeleteSchema() {
        this.dispatchEvent(
            new CustomEvent('deleteschema', {
                detail: { schemaId: this.schemaId }
            })
        );
    }
}