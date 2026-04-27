public with sharing class KenIdLifecycleManagerController {
    private static final String FIELD_INSTITUTE = 'Institute__c';

    public class KenTemplateSaveRequest {
        @AuraEnabled
        public String templateName { get; set; }

        @AuraEnabled
        public String cardType { get; set; }

        @AuraEnabled
        public List<String> instituteValues { get; set; }

        @AuraEnabled
        public Boolean isActive { get; set; }

        @AuraEnabled
        public Boolean deactive { get; set; }

        @AuraEnabled
        public Boolean includeBackVariantLayout { get; set; }

        @AuraEnabled
        public String description { get; set; }

        @AuraEnabled
        public String primaryLogo { get; set; }

        @AuraEnabled
        public String secondaryLogoUrl { get; set; }

        @AuraEnabled
        public String secondaryLogoFileName { get; set; }

        @AuraEnabled
        public String secondaryLogoFileData { get; set; }

        @AuraEnabled
        public String designTheme { get; set; }

        @AuraEnabled
        public String brandColor { get; set; }

        @AuraEnabled
        public String typographyStyle { get; set; }

        @AuraEnabled
        public String fieldConfigurationJson { get; set; }

        @AuraEnabled
        public String idNumber { get; set; }
    }

    public class KenTemplateSaveResult {
        @AuraEnabled
        public Id recordId { get; set; }

        @AuraEnabled
        public List<String> instituteValues { get; set; }

        @AuraEnabled
        public String instituteName { get; set; }

        @AuraEnabled
        public Boolean isActive { get; set; }

        @AuraEnabled
        public Boolean deactive { get; set; }

        @AuraEnabled
        public String secondaryLogoUrl { get; set; }
    }

    public class KenTemplateSummary {
        @AuraEnabled
        public Id recordId { get; set; }

        @AuraEnabled
        public String templateName { get; set; }

        @AuraEnabled
        public String cardType { get; set; }

        @AuraEnabled
        public String instituteName { get; set; }

        @AuraEnabled
        public Boolean isActive { get; set; }

        @AuraEnabled
        public Boolean deactive { get; set; }

        @AuraEnabled
        public Boolean includeBackVariantLayout { get; set; }

        @AuraEnabled
        public String description { get; set; }

        @AuraEnabled
        public String primaryLogo { get; set; }

        @AuraEnabled
        public String secondaryLogoUrl { get; set; }

        @AuraEnabled
        public String secondaryLogoPreviewUrl { get; set; }

        @AuraEnabled
        public String designTheme { get; set; }

        @AuraEnabled
        public String brandColor { get; set; }

        @AuraEnabled
        public String typographyStyle { get; set; }

        @AuraEnabled
        public Datetime lastModifiedDate { get; set; }

        @AuraEnabled
        public String fieldConfigurationJson { get; set; }

        @AuraEnabled
        public String idNumber { get; set; }
    }

    private class KenTemplateAppearanceConfig {
        public String designTheme;
        public String brandColor;
        public String typographyStyle;
    }

    @AuraEnabled(cacheable=true)
    public static List<KenTemplateSummary> getTemplates() {
        List<KenTemplateSummary> templates = new List<KenTemplateSummary>();
        String templateQuery =
            'SELECT Id, Name, Card_Type__c, ' +
            FIELD_INSTITUTE +
            ', Is_Active__c, Deactive__c, Include_Back_Variant_Layout__c, Description__c, Primary_Logo__c, Secondary_Logo_URL__c, Field_Configuration_JSON__c, ID_Number__c, LastModifiedDate ' +
            'FROM Ken_ID_Card__c ORDER BY Name ASC LIMIT 100';

        for (SObject templateRecord : Database.query(templateQuery)) {
            KenTemplateSummary summary = new KenTemplateSummary();
            summary.recordId = (Id)templateRecord.get('Id');
            summary.templateName = (String)templateRecord.get('Name');
            summary.cardType = (String)templateRecord.get('Card_Type__c');
            summary.instituteName = formatInstituteDisplayValue((String)templateRecord.get(FIELD_INSTITUTE));
            summary.isActive = (Boolean)templateRecord.get('Is_Active__c');
            summary.deactive = (Boolean)templateRecord.get('Deactive__c');
            summary.includeBackVariantLayout = (Boolean)templateRecord.get('Include_Back_Variant_Layout__c');
            summary.description = (String)templateRecord.get('Description__c');
            summary.primaryLogo = (String)templateRecord.get('Primary_Logo__c');
            summary.fieldConfigurationJson = (String)templateRecord.get('Field_Configuration_JSON__c');
            summary.idNumber = (String)templateRecord.get('ID_Number__c');
            summary.lastModifiedDate = (Datetime)templateRecord.get('LastModifiedDate');

            KenTemplateAppearanceConfig appearanceConfig =
                extractAppearanceConfig(summary.fieldConfigurationJson);
            summary.designTheme = appearanceConfig.designTheme;
            summary.brandColor = appearanceConfig.brandColor;
            summary.typographyStyle = appearanceConfig.typographyStyle;

            String secondaryLogoValue = (String)templateRecord.get('Secondary_Logo_URL__c');
            Id contentDocumentId = extractContentDocumentId(secondaryLogoValue);
            if (contentDocumentId != null) {
                summary.secondaryLogoUrl = buildFileViewUrl(contentDocumentId);
                summary.secondaryLogoPreviewUrl = buildFileDownloadUrl(contentDocumentId);
            } else {
                summary.secondaryLogoUrl = secondaryLogoValue;
                summary.secondaryLogoPreviewUrl = secondaryLogoValue;
            }

            templates.add(summary);
        }

        return templates;
    }

    @AuraEnabled
    public static KenTemplateSaveResult saveTemplate(KenTemplateSaveRequest request) {
        if (request == null || String.isBlank(request.templateName)) {
            throw new AuraHandledException('Template Name is required.');
        }

        List<String> normalizedInstituteValues = normalizeInstituteValues(request.instituteValues);
        if (normalizedInstituteValues.isEmpty()) {
            throw new AuraHandledException('Institute is required.');
        }

        String persistedFieldConfigurationJson = buildPersistedFieldConfigurationJson(request);
        Boolean isTemplateDeactive = request.deactive == true;
        Boolean isTemplateActive = !isTemplateDeactive && request.isActive == true;

        Ken_ID_Card__c templateRecord = new Ken_ID_Card__c(
            Name = request.templateName.trim(),
            Card_Type__c = String.isBlank(request.cardType) ? 'Student' : request.cardType,
            Is_Active__c = isTemplateActive,
            Deactive__c = isTemplateDeactive,
            Include_Back_Variant_Layout__c = request.includeBackVariantLayout == true,
            Primary_Logo__c = request.primaryLogo,
            Field_Configuration_JSON__c = persistedFieldConfigurationJson,
            ID_Number__c = String.isBlank(request.idNumber) ? null : request.idNumber.trim()
        );
        templateRecord.put(FIELD_INSTITUTE, String.join(normalizedInstituteValues, ';'));

        if (String.isNotBlank(request.description)) {
            templateRecord.Description__c = request.description.trim();
        }

        insert templateRecord;

        String secondaryLogoUrl = '';
        if (String.isNotBlank(request.secondaryLogoFileData) && String.isNotBlank(request.secondaryLogoFileName)) {
            ContentVersion secondaryLogoVersion = new ContentVersion(
                Title = getFileTitle(request.secondaryLogoFileName),
                PathOnClient = request.secondaryLogoFileName.trim(),
                VersionData = EncodingUtil.base64Decode(request.secondaryLogoFileData),
                FirstPublishLocationId = templateRecord.Id
            );
            insert secondaryLogoVersion;

            secondaryLogoVersion = [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE Id = :secondaryLogoVersion.Id
            ];

            secondaryLogoUrl = buildFileViewUrl(secondaryLogoVersion.ContentDocumentId);

            templateRecord.Secondary_Logo_URL__c = secondaryLogoUrl;
            update templateRecord;
        } else if (String.isNotBlank(request.secondaryLogoUrl)) {
            templateRecord.Secondary_Logo_URL__c = request.secondaryLogoUrl.trim();
            update templateRecord;
            secondaryLogoUrl = templateRecord.Secondary_Logo_URL__c;
        }

        KenTemplateSaveResult response = new KenTemplateSaveResult();
        response.recordId = templateRecord.Id;
        response.instituteValues = normalizedInstituteValues;
        response.instituteName = formatInstituteDisplayValue((String)templateRecord.get(FIELD_INSTITUTE));
        response.isActive = templateRecord.Is_Active__c;
        response.deactive = templateRecord.Deactive__c;
        response.secondaryLogoUrl = secondaryLogoUrl;
        return response;
    }

    private static List<String> normalizeInstituteValues(List<String> selectedInstituteValues) {
        List<String> normalizedInstituteValues = new List<String>();
        if (selectedInstituteValues == null || selectedInstituteValues.isEmpty()) {
            return normalizedInstituteValues;
        }

        Set<String> allowedInstituteValues = getAllowedInstituteValues();
        Set<String> seenInstituteValues = new Set<String>();

        for (String instituteValue : selectedInstituteValues) {
            String trimmedInstituteValue = instituteValue == null ? '' : instituteValue.trim();
            if (String.isBlank(trimmedInstituteValue) || seenInstituteValues.contains(trimmedInstituteValue)) {
                continue;
            }

            if (!allowedInstituteValues.contains(trimmedInstituteValue)) {
                throw new AuraHandledException('Select only configured institute values.');
            }

            normalizedInstituteValues.add(trimmedInstituteValue);
            seenInstituteValues.add(trimmedInstituteValue);
        }

        return normalizedInstituteValues;
    }

    private static Set<String> getAllowedInstituteValues() {
        Set<String> allowedInstituteValues = new Set<String>();
        Schema.SObjectField instituteField = Ken_ID_Card__c.SObjectType.getDescribe().fields.getMap().get(FIELD_INSTITUTE);
        if (instituteField == null) {
            return allowedInstituteValues;
        }

        for (Schema.PicklistEntry instituteEntry : instituteField.getDescribe().getPicklistValues()) {
            if (instituteEntry.isActive()) {
                allowedInstituteValues.add(instituteEntry.getValue());
            }
        }

        return allowedInstituteValues;
    }

    private static String formatInstituteDisplayValue(String storedInstituteValue) {
        if (String.isBlank(storedInstituteValue)) {
            return '';
        }

        List<String> instituteLabels = new List<String>();
        for (String instituteValue : storedInstituteValue.split(';')) {
            if (String.isNotBlank(instituteValue)) {
                instituteLabels.add(instituteValue.trim());
            }
        }

        return String.join(instituteLabels, ', ');
    }

    private static String buildPersistedFieldConfigurationJson(KenTemplateSaveRequest request) {
        Map<String, Object> configuration = new Map<String, Object>();

        if (String.isNotBlank(request.fieldConfigurationJson)) {
            try {
                Object parsedConfiguration = JSON.deserializeUntyped(request.fieldConfigurationJson);
                if (parsedConfiguration instanceof Map<String, Object>) {
                    configuration = (Map<String, Object>)parsedConfiguration;
                }
            } catch (Exception exceptionValue) {
                configuration = new Map<String, Object>();
            }
        }

        Map<String, Object> appearance = new Map<String, Object>();
        if (configuration.containsKey('appearance') && configuration.get('appearance') instanceof Map<String, Object>) {
            appearance = (Map<String, Object>)configuration.get('appearance');
        }

        if (String.isNotBlank(request.designTheme)) {
            appearance.put('designTheme', request.designTheme.trim());
        }
        if (String.isNotBlank(request.brandColor)) {
            appearance.put('brandColor', request.brandColor.trim());
        }
        if (String.isNotBlank(request.typographyStyle)) {
            appearance.put('typographyStyle', request.typographyStyle.trim());
        }

        if (!appearance.isEmpty()) {
            configuration.put('appearance', appearance);
        }
        if (!configuration.containsKey('version')) {
            configuration.put('version', 1);
        }

        return JSON.serialize(configuration);
    }

    private static KenTemplateAppearanceConfig extractAppearanceConfig(String fieldConfigurationJson) {
        KenTemplateAppearanceConfig appearanceConfig = new KenTemplateAppearanceConfig();
        if (String.isBlank(fieldConfigurationJson)) {
            return appearanceConfig;
        }

        try {
            Object parsedConfiguration = JSON.deserializeUntyped(fieldConfigurationJson);
            if (!(parsedConfiguration instanceof Map<String, Object>)) {
                return appearanceConfig;
            }

            Map<String, Object> configuration = (Map<String, Object>)parsedConfiguration;
            if (!(configuration.get('appearance') instanceof Map<String, Object>)) {
                return appearanceConfig;
            }

            Map<String, Object> appearance = (Map<String, Object>)configuration.get('appearance');
            appearanceConfig.designTheme = (String)appearance.get('designTheme');
            appearanceConfig.brandColor = (String)appearance.get('brandColor');
            appearanceConfig.typographyStyle = (String)appearance.get('typographyStyle');
        } catch (Exception exceptionValue) {
            return appearanceConfig;
        }

        return appearanceConfig;
    }

    private static String buildFileViewUrl(Id contentDocumentId) {
        return URL.getOrgDomainUrl().toExternalForm() + '/lightning/r/ContentDocument/' + contentDocumentId + '/view';
    }

    private static String buildFileDownloadUrl(Id contentDocumentId) {
        return URL.getOrgDomainUrl().toExternalForm() + '/sfc/servlet.shepherd/document/download/' + contentDocumentId;
    }

    private static Id extractContentDocumentId(String fileUrl) {
        if (String.isBlank(fileUrl)) {
            return null;
        }

        String trimmedUrl = fileUrl.trim();
        String documentMarker = '/lightning/r/ContentDocument/';
        Integer documentMarkerIndex = trimmedUrl.indexOf(documentMarker);
        if (documentMarkerIndex >= 0) {
            Integer idStart = documentMarkerIndex + documentMarker.length();
            Integer idEnd = trimmedUrl.indexOf('/view', idStart);
            if (idEnd > idStart) {
                String contentDocumentId = trimmedUrl.substring(idStart, idEnd);
                if (contentDocumentId.startsWith('069')) {
                    return (Id)contentDocumentId;
                }
            }
        }

        String downloadMarker = '/sfc/servlet.shepherd/document/download/';
        Integer downloadMarkerIndex = trimmedUrl.indexOf(downloadMarker);
        if (downloadMarkerIndex >= 0) {
            String contentDocumentId = trimmedUrl.substring(downloadMarkerIndex + downloadMarker.length());
            Integer queryMarker = contentDocumentId.indexOf('?');
            if (queryMarker >= 0) {
                contentDocumentId = contentDocumentId.substring(0, queryMarker);
            }

            if (contentDocumentId.startsWith('069')) {
                return (Id)contentDocumentId;
            }
        }

        return null;
    }

    private static String getFileTitle(String fileName) {
        String normalizedFileName = fileName.trim();
        Integer extensionStart = normalizedFileName.lastIndexOf('.');
        if (extensionStart > 0) {
            return normalizedFileName.substring(0, extensionStart);
        }

        return normalizedFileName;
    }

    public class KenGlobalAsset {
        @AuraEnabled
        public Id contentDocumentId { get; set; }

        @AuraEnabled
        public String name { get; set; }

        @AuraEnabled
        public String previewUrl { get; set; }

        @AuraEnabled
        public String downloadUrl { get; set; }

        @AuraEnabled
        public Datetime uploadedOn { get; set; }
    }

    @AuraEnabled
    public static List<KenGlobalAsset> getGlobalAssets() {
        List<KenGlobalAsset> assets = new List<KenGlobalAsset>();
        for (ContentVersion cv : [
            SELECT ContentDocumentId, Title, CreatedDate
            FROM ContentVersion
            WHERE IsLatest = true AND Description = 'KEN_GLOBAL_ASSET'
            ORDER BY Title ASC
            LIMIT 100
        ]) {
            KenGlobalAsset asset = new KenGlobalAsset();
            asset.contentDocumentId = cv.ContentDocumentId;
            asset.name = cv.Title;
            asset.previewUrl = buildFileDownloadUrl(cv.ContentDocumentId);
            asset.downloadUrl = buildFileDownloadUrl(cv.ContentDocumentId);
            asset.uploadedOn = cv.CreatedDate;
            assets.add(asset);
        }
        return assets;
    }

    @AuraEnabled
    public static Id saveGlobalAsset(String fileName, String fileData) {
        if (String.isBlank(fileName) || String.isBlank(fileData)) {
            throw new AuraHandledException('File name and data are required.');
        }

        ContentVersion cv = new ContentVersion(
            Title = getFileTitle(fileName.trim()),
            PathOnClient = fileName.trim(),
            VersionData = EncodingUtil.base64Decode(fileData),
            Description = 'KEN_GLOBAL_ASSET'
        );
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        return cv.ContentDocumentId;
    }

    @AuraEnabled
    public static void deleteGlobalAsset(Id contentDocumentId) {
        List<ContentDocument> docsToDelete = [
            SELECT Id FROM ContentDocument WHERE Id = :contentDocumentId
        ];
        if (!docsToDelete.isEmpty()) {
            delete docsToDelete;
        }
    }
}