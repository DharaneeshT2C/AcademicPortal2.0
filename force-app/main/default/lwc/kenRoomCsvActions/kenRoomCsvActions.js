import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import bulkCreateRoomsFromCsv from '@salesforce/apex/KenRoomController.bulkCreateRoomsFromCsv';

const TEMPLATE_COLUMNS = ['Building', 'Floor', 'Room Number', 'Category', 'Capacity', 'Status'];
const TEMPLATE_NOTE_PREFIX = '#';
const TEMPLATE_NOTE_LINES = [
    '# NOTE: This template includes sample reference rows.',
    '# Remove the sample rows before uploading your actual room data.'
];
const TEMPLATE_SAMPLE_ROWS = [
    ['Sample Building', '1', 'SAMPLE-101', 'Sample Category', '2', 'Active'],
    ['Sample Building', '2', 'SAMPLE-201', 'Sample Category', '3', 'Inactive']
];

const REQUIRED_COLUMN_TOKENS = {
    building: ['building'],
    floor: ['floor'],
    roomNumber: ['roomnumber', 'roomno'],
    category: ['category'],
    capacity: ['capacity'],
    status: ['status']
};

const COLUMN_LABEL_BY_FIELD = {
    building: 'Building',
    floor: 'Floor',
    roomNumber: 'Room Number',
    category: 'Category',
    capacity: 'Capacity',
    status: 'Status'
};

export default class KenRoomCsvActions extends LightningElement {
    isUploading = false;
    isErrorModalOpen = false;
    uploadResponse = null;
    csvErrors = [];
    downloadUrls = [];

    disconnectedCallback() {
        this.releaseDownloadUrls();
    }

    get isBusy() {
        return this.isUploading;
    }

    get uploadButtonLabel() {
        return this.isUploading ? 'Uploading...' : 'Upload CSV';
    }

    get errorSummaryText() {
        const processed = this.uploadResponse?.processedCount ?? 0;
        const success = this.uploadResponse?.successCount ?? 0;
        const failure = this.uploadResponse?.failureCount ?? (this.csvErrors || []).length;
        return `Processed ${processed} row(s). Created ${success} room(s). ${failure} row(s) failed.`;
    }

    get templateHelpText() {
        return 'Template has sample rows. Remove them before upload.';
    }

    handleDownloadTemplate() {
        const rows = [
            ...TEMPLATE_NOTE_LINES.map((line) => [line]),
            TEMPLATE_COLUMNS,
            ...TEMPLATE_SAMPLE_ROWS
        ];
        const csvText = `\uFEFF${rows.map((row) => row.map((cell) => this.toCsvCell(cell)).join(',')).join('\n')}\n`;
        this.downloadTextAsFile(csvText, 'Rooms_CSV_Template.csv', 'text/csv;charset=utf-8');
    }

    handleUploadClick() {
        const input = this.getFileInput();
        if (!input) {
            this.showToast('Error', 'File input is not available.', 'error');
            return;
        }
        input.click();
    }

    async handleFileChange(event) {
        const file = event?.target?.files?.[0];
        if (!file) {
            return;
        }

        try {
            const csvText = await this.readFileAsText(file);
            const parsed = this.parseCsv(csvText);
            const relevantRows = this.getRelevantCsvRows(parsed.rows);
            if (!relevantRows.length) {
                this.showToast('Validation Error', 'CSV is empty.', 'warning');
                return;
            }

            const headerRow = relevantRows[0]?.row || [];
            const headerIndexByField = this.resolveHeaderIndexByField(headerRow);
            const missingFields = Object.keys(REQUIRED_COLUMN_TOKENS).filter((field) => headerIndexByField[field] == null);
            if (missingFields.length) {
                const missingLabels = missingFields.map((field) => COLUMN_LABEL_BY_FIELD[field] || field);
                this.showToast(
                    'Validation Error',
                    `Missing required column(s): ${missingLabels.join(', ')}.`,
                    'warning'
                );
                return;
            }

            const inputRows = [];
            for (let i = 1; i < relevantRows.length; i++) {
                const rowItem = relevantRows[i] || {};
                const row = rowItem.row || [];

                inputRows.push({
                    rowNumber: rowItem.rowNumber,
                    building: this.getCellValue(row, headerIndexByField.building),
                    floor: this.getCellValue(row, headerIndexByField.floor),
                    roomNumber: this.getCellValue(row, headerIndexByField.roomNumber),
                    category: this.getCellValue(row, headerIndexByField.category),
                    capacity: this.getCellValue(row, headerIndexByField.capacity),
                    status: this.getCellValue(row, headerIndexByField.status)
                });
            }

            if (!inputRows.length) {
                this.showToast('Validation Error', 'No data rows found in CSV.', 'warning');
                return;
            }
            if (inputRows.length > 2000) {
                this.showToast('Validation Error', 'CSV upload supports up to 2000 rows at a time.', 'warning');
                return;
            }

            await this.uploadCsvRows(inputRows);
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.resetFileInput();
        }
    }

    async uploadCsvRows(inputRows) {
        this.isUploading = true;
        this.uploadResponse = null;
        this.csvErrors = [];
        this.isErrorModalOpen = false;

        try {
            const response = await bulkCreateRoomsFromCsv({ inputRows });
            this.uploadResponse = response;

            const successCount = response?.successCount ?? 0;
            const failureCount = response?.failureCount ?? 0;
            const errorRows = Array.isArray(response?.errors) ? response.errors : [];
            this.csvErrors = errorRows.map((err, idx) => ({
                key: `${err?.rowNumber ?? 'row'}-${idx}`,
                rowNumber: err?.rowNumber ?? '',
                message: err?.message ?? 'Invalid row.'
            }));

            if (failureCount > 0 || this.csvErrors.length) {
                this.isErrorModalOpen = true;
                this.showToast('Upload Completed', `Created ${successCount} room(s). ${failureCount} row(s) failed.`, 'warning');
            } else {
                this.showToast('Success', `Created ${successCount} room(s).`, 'success');
            }

            if (successCount > 0) {
                this.dispatchEvent(new CustomEvent('roomsrefresh'));
            }
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isUploading = false;
        }
    }

    handleCloseErrorModal() {
        this.isErrorModalOpen = false;
    }

    handleDownloadErrorsCsv() {
        if (!this.csvErrors.length) {
            this.showToast('Info', 'No errors to download.', 'info');
            return;
        }

        const rows = [
            ['Row', 'Message'],
            ...this.csvErrors.map((err) => [String(err.rowNumber ?? ''), String(err.message ?? '')])
        ];

        const csvText = rows
            .map((row) => row.map((cell) => this.toCsvCell(cell)).join(','))
            .join('\n')
            .concat('\n');

        this.downloadTextAsFile(csvText, 'Rooms_CSV_Errors.csv', 'text/csv;charset=utf-8');
    }

    getFileInput() {
        return this.template.querySelector('input[type="file"]');
    }

    resetFileInput() {
        const input = this.getFileInput();
        if (input) {
            input.value = '';
        }
    }

    readFileAsText(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onerror = () => reject(new Error('Unable to read the file.'));
            reader.onload = () => resolve(String(reader.result || ''));
            reader.readAsText(file);
        });
    }

    parseCsv(text) {
        const rows = [];
        let row = [];
        let field = '';
        let inQuotes = false;

        const input = String(text || '').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
        for (let i = 0; i < input.length; i++) {
            const char = input[i];

            if (char === '"') {
                const nextChar = input[i + 1];
                if (inQuotes && nextChar === '"') {
                    field += '"';
                    i++;
                } else {
                    inQuotes = !inQuotes;
                }
                continue;
            }

            if (!inQuotes && char === ',') {
                row.push(field);
                field = '';
                continue;
            }

            if (!inQuotes && char === '\n') {
                row.push(field);
                rows.push(row);
                row = [];
                field = '';
                continue;
            }

            field += char;
        }

        if (field.length || row.length) {
            row.push(field);
            rows.push(row);
        }

        return { rows };
    }

    getRelevantCsvRows(rows) {
        return (rows || [])
            .map((row, index) => ({
                row: Array.isArray(row) ? row : [],
                rowNumber: index + 1
            }))
            .filter((rowItem) => !this.isSkippableCsvRow(rowItem.row));
    }

    isSkippableCsvRow(row) {
        if (!Array.isArray(row) || !row.length) {
            return true;
        }
        const firstCell = String(row[0] ?? '').trim();
        const isEmpty = row.every((cell) => !this.hasUsableText(cell));
        if (isEmpty) {
            return true;
        }
        return firstCell.startsWith(TEMPLATE_NOTE_PREFIX);
    }

    resolveHeaderIndexByField(headerRow) {
        const normalizedCells = (headerRow || []).map((cell) => this.normalizeHeaderCell(cell));
        const indexByField = {};

        Object.keys(REQUIRED_COLUMN_TOKENS).forEach((field) => {
            const tokens = REQUIRED_COLUMN_TOKENS[field] || [];
            for (let i = 0; i < normalizedCells.length; i++) {
                const headerCell = normalizedCells[i];
                if (!headerCell) {
                    continue;
                }
                if (tokens.some((token) => headerCell === token)) {
                    indexByField[field] = i;
                    break;
                }
            }
        });

        if (indexByField.roomNumber == null) {
            const idx = normalizedCells.findIndex((cell) => cell === 'room');
            if (idx >= 0) {
                indexByField.roomNumber = idx;
            }
        }

        return indexByField;
    }

    normalizeHeaderCell(value) {
        let text = String(value ?? '');
        if (text.charCodeAt(0) === 0xfeff) {
            text = text.slice(1);
        }
        return text
            .trim()
            .toLowerCase()
            .replace(/\s+/g, '')
            .replace(/-/g, '');
    }

    getCellValue(row, index) {
        if (!Array.isArray(row) || index == null) {
            return '';
        }
        return String(row[index] ?? '').trim();
    }

    toCsvCell(value) {
        const text = String(value ?? '');
        if (text.includes('"') || text.includes(',') || text.includes('\n')) {
            return `"${text.replace(/"/g, '""')}"`;
        }
        return text;
    }

    downloadTextAsFile(text, filename, mimeType) {
        const safeMimeType = mimeType || 'application/octet-stream';
        const safeFilename = filename || 'download';
        const safeText = String(text ?? '');

        try {
            this.releaseDownloadUrls();
            const blob = new Blob([safeText], { type: safeMimeType });
            const url = URL.createObjectURL(blob);
            this.downloadUrls = [url];

            const link = document.createElement('a');
            link.href = url;
            link.setAttribute('download', safeFilename);
            link.style.display = 'none';

            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            return;
        } catch {
            // Fallback: data URI (some environments block blob downloads)
        }

        try {
            const encoded = encodeURIComponent(safeText);
            const dataUri = `data:${safeMimeType},${encoded}`;

            const link = document.createElement('a');
            link.href = dataUri;
            link.setAttribute('download', safeFilename);
            link.style.display = 'none';

            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        } catch {
            this.showToast('Error', 'Unable to download the template. Please try another browser.', 'error');
        }
    }

    releaseDownloadUrls() {
        for (const objectUrl of this.downloadUrls) {
            try {
                URL.revokeObjectURL(objectUrl);
            } catch {
                // no-op
            }
        }
        this.downloadUrls = [];
    }

    hasUsableText(value) {
        return String(value ?? '').trim().length > 0;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    extractErrorMessage(error) {
        const body = error?.body;
        if (Array.isArray(body)) {
            const firstArrayMessage = body.find((item) => item?.message)?.message;
            if (firstArrayMessage) {
                return firstArrayMessage;
            }
        }

        const pageErrorMessage = body?.pageErrors?.find((item) => item?.message)?.message;
        if (pageErrorMessage) {
            return pageErrorMessage;
        }

        const fieldErrorGroups = body?.fieldErrors ? Object.values(body.fieldErrors) : [];
        for (const group of fieldErrorGroups) {
            if (Array.isArray(group)) {
                const fieldMessage = group.find((item) => item?.message)?.message;
                if (fieldMessage) {
                    return fieldMessage;
                }
            }
        }

        return body?.message || error?.message || 'Something went wrong. Please try again.';
    }
}