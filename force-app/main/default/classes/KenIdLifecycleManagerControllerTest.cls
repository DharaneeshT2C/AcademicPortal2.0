@IsTest
private class KenIdLifecycleManagerControllerTest {
    private static final String FIELD_INSTITUTE = 'Institute__c';

    @IsTest
    static void saveTemplateStoresInstituteMultiSelectAndFiles() {
        KenIdLifecycleManagerController.KenTemplateSaveRequest requestValue =
            new KenIdLifecycleManagerController.KenTemplateSaveRequest();
        requestValue.templateName = 'Student Template';
        requestValue.cardType = 'Student';
        requestValue.instituteValues = new List<String>{
            'K J Somaiya Institute of Management',
            'Somaiya School of Design'
        };
        requestValue.isActive = true;
        requestValue.deactive = false;
        requestValue.includeBackVariantLayout = false;
        requestValue.description = 'Template description';
        requestValue.primaryLogo = 'Ken_ID_Card_Sample_Logo';
        requestValue.idNumber = '2027-COE-001';
        requestValue.fieldConfigurationJson =
            '{"version":1,"appearance":{"designTheme":"Classic Professional","brandColor":"#5665F2","typographyStyle":"Fira Sans"},"front":[{"instanceId":"fullName","fieldKey":"fullName","label":"Full Name","sourceKey":"accountPerson.name"}],"back":[{"instanceId":"issueDate","fieldKey":"issueDate","label":"Issue Date","sourceKey":"template.issueDate"}]}';
        requestValue.secondaryLogoFileName = 'student-photo.png';
        requestValue.secondaryLogoFileData = EncodingUtil.base64Encode(Blob.valueOf('fake image content'));

        Test.startTest();
        KenIdLifecycleManagerController.KenTemplateSaveResult resultValue =
            KenIdLifecycleManagerController.saveTemplate(requestValue);
        Test.stopTest();

        System.assertNotEquals(null, resultValue.recordId, 'The template record should be created.');
        System.assertEquals(
            new List<String>{ 'K J Somaiya Institute of Management', 'Somaiya School of Design' },
            resultValue.instituteValues,
            'The selected institute values should be returned.'
        );

        Id savedTemplateId = resultValue.recordId;
        SObject savedTemplate = Database.query(
            'SELECT Name, ' +
            FIELD_INSTITUTE +
            ', Card_Type__c, Is_Active__c, Deactive__c, Secondary_Logo_URL__c, Field_Configuration_JSON__c, ID_Number__c ' +
            'FROM Ken_ID_Card__c WHERE Id = :savedTemplateId'
        );
        System.assertEquals('Student Template', (String)savedTemplate.get('Name'));
        System.assertEquals(
            'K J Somaiya Institute of Management;Somaiya School of Design',
            (String)savedTemplate.get(FIELD_INSTITUTE)
        );
        System.assertEquals('Student', (String)savedTemplate.get('Card_Type__c'));
        System.assertEquals(true, (Boolean)savedTemplate.get('Is_Active__c'));
        System.assertEquals(false, (Boolean)savedTemplate.get('Deactive__c'));
        System.assertEquals('2027-COE-001', (String)savedTemplate.get('ID_Number__c'));
        System.assertNotEquals(null, savedTemplate.get('Secondary_Logo_URL__c'), 'The secondary logo URL should be stored.');
        Map<String, Object> savedConfiguration =
            (Map<String, Object>)JSON.deserializeUntyped((String)savedTemplate.get('Field_Configuration_JSON__c'));
        Map<String, Object> savedAppearance = (Map<String, Object>)savedConfiguration.get('appearance');
        System.assertEquals(
            'Classic Professional',
            (String)savedAppearance.get('designTheme'),
            'The design theme should be stored inside the JSON configuration.'
        );
        System.assertEquals(
            '#5665F2',
            (String)savedAppearance.get('brandColor'),
            'The brand color should be stored inside the JSON configuration.'
        );
        System.assert(
            ((String)savedTemplate.get('Field_Configuration_JSON__c')).contains('"fieldKey":"fullName"'),
            'The field configuration JSON should be stored on the template record.'
        );
        System.assert(
            ((String)savedTemplate.get('Secondary_Logo_URL__c')).contains('/lightning/r/ContentDocument/'),
            'The secondary logo should be stored as a Salesforce file view URL.'
        );
        System.assertEquals((String)savedTemplate.get('Secondary_Logo_URL__c'), resultValue.secondaryLogoUrl);
        System.assertEquals(
            'K J Somaiya Institute of Management, Somaiya School of Design',
            resultValue.instituteName,
            'The response should include a display-friendly institute label.'
        );

        ContentDocumentLink linkedFile = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :savedTemplateId
            LIMIT 1
        ];
        System.assertEquals(savedTemplateId, linkedFile.LinkedEntityId);
    }

    @IsTest
    static void saveGlobalAssetStoresFileWithMarkerAndReturnsContentDocumentId() {
        String fileName = 'somaiya-logo.png';
        String fileData = EncodingUtil.base64Encode(Blob.valueOf('fake image content'));

        Test.startTest();
        Id contentDocumentId = KenIdLifecycleManagerController.saveGlobalAsset(fileName, fileData);
        Test.stopTest();

        System.assertNotEquals(null, contentDocumentId, 'A ContentDocument ID should be returned.');
        ContentVersion savedVersion = [
            SELECT Title, Description
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId AND IsLatest = true
            LIMIT 1
        ];
        System.assertEquals('somaiya-logo', savedVersion.Title, 'Title should strip the file extension.');
        System.assertEquals('KEN_GLOBAL_ASSET', savedVersion.Description, 'Description should be the global asset marker.');
    }

    @IsTest
    static void saveGlobalAssetRejectsBlankInput() {
        try {
            KenIdLifecycleManagerController.saveGlobalAsset('', 'somedata');
            System.assert(false, 'Blank file name should be rejected.');
        } catch (AuraHandledException exceptionValue) {
            System.assertEquals('File name and data are required.', exceptionValue.getMessage());
        }
    }

    @IsTest
    static void getGlobalAssetsReturnsOnlyMarkedFiles() {
        ContentVersion globalAsset = new ContentVersion(
            Title = 'trust-seal',
            PathOnClient = 'trust-seal.png',
            VersionData = Blob.valueOf('image data'),
            Description = 'KEN_GLOBAL_ASSET'
        );
        insert globalAsset;

        ContentVersion templateAsset = new ContentVersion(
            Title = 'template-photo',
            PathOnClient = 'template-photo.png',
            VersionData = Blob.valueOf('photo data')
        );
        insert templateAsset;

        Test.startTest();
        List<KenIdLifecycleManagerController.KenGlobalAsset> assets =
            KenIdLifecycleManagerController.getGlobalAssets();
        Test.stopTest();

        System.assertEquals(1, assets.size(), 'Only files marked KEN_GLOBAL_ASSET should be returned.');
        System.assertEquals('trust-seal', assets[0].name);
        System.assert(
            assets[0].previewUrl.contains('/sfc/servlet.shepherd/document/download/'),
            'Preview URL should be a download endpoint.'
        );
        System.assertNotEquals(null, assets[0].uploadedOn, 'Uploaded on date should be set.');
    }

    @IsTest
    static void deleteGlobalAssetRemovesContentDocument() {
        ContentVersion cv = new ContentVersion(
            Title = 'to-delete',
            PathOnClient = 'to-delete.png',
            VersionData = Blob.valueOf('image data'),
            Description = 'KEN_GLOBAL_ASSET'
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        Id contentDocumentId = cv.ContentDocumentId;

        Test.startTest();
        KenIdLifecycleManagerController.deleteGlobalAsset(contentDocumentId);
        Test.stopTest();

        Integer remaining = [SELECT COUNT() FROM ContentDocument WHERE Id = :contentDocumentId];
        System.assertEquals(0, remaining, 'The ContentDocument should be permanently deleted.');
    }

    @IsTest
    static void saveTemplateDeactiveOverridesActiveFlag() {
        KenIdLifecycleManagerController.KenTemplateSaveRequest requestValue =
            new KenIdLifecycleManagerController.KenTemplateSaveRequest();
        requestValue.templateName = 'Deactive Template';
        requestValue.cardType = 'Staff';
        requestValue.instituteValues = new List<String>{ 'Somaiya Sports Academy' };
        requestValue.isActive = true;
        requestValue.deactive = true;
        requestValue.includeBackVariantLayout = true;
        requestValue.primaryLogo = 'Ken_ID_Card_Sample_Logo';
        requestValue.idNumber = 'STF-2028-015';
        requestValue.fieldConfigurationJson =
            '{"version":1,"appearance":{"designTheme":"Modern Minimalist","brandColor":"#1F1F1F","typographyStyle":"General Sans"},"front":[{"instanceId":"cardType","fieldKey":"cardType","label":"Card Type","sourceKey":"basicDetails.cardType"}],"back":[]}';

        Test.startTest();
        KenIdLifecycleManagerController.KenTemplateSaveResult resultValue =
            KenIdLifecycleManagerController.saveTemplate(requestValue);
        Test.stopTest();

        System.assertEquals(
            false,
            [SELECT Is_Active__c FROM Ken_ID_Card__c WHERE Id = :resultValue.recordId].Is_Active__c,
            'Deactive templates should not remain active.'
        );
        System.assertEquals(true, resultValue.deactive, 'The response should expose the deactive flag.');
    }

    @IsTest
    static void saveTemplateRejectsUnknownInstituteValue() {
        KenIdLifecycleManagerController.KenTemplateSaveRequest requestValue =
            new KenIdLifecycleManagerController.KenTemplateSaveRequest();
        requestValue.templateName = 'Invalid Template';
        requestValue.cardType = 'Student';
        requestValue.instituteValues = new List<String>{ 'Unknown Institute' };

        try {
            KenIdLifecycleManagerController.saveTemplate(requestValue);
            System.assert(false, 'An invalid institute value should be rejected.');
        } catch (AuraHandledException exceptionValue) {
            System.assertEquals('Select only configured institute values.', exceptionValue.getMessage());
        }
    }

    @IsTest
    static void getTemplatesReturnsSavedTemplateSummaries() {
        ContentVersion secondaryLogoVersion = new ContentVersion(
            Title = 'summary-preview',
            PathOnClient = 'summary-preview.png',
            VersionData = Blob.valueOf('preview image')
        );
        insert secondaryLogoVersion;

        secondaryLogoVersion = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :secondaryLogoVersion.Id
        ];

        Ken_ID_Card__c templateRecord = new Ken_ID_Card__c(
            Name = 'Arts Template',
            Card_Type__c = 'Student',
            Is_Active__c = false,
            Deactive__c = true,
            Include_Back_Variant_Layout__c = true,
            Description__c = 'Arts template description',
            Primary_Logo__c = 'Ken_ID_Card_Sample_Logo',
            ID_Number__c = 'ARTS-2027-001',
            Field_Configuration_JSON__c =
                '{"version":1,"appearance":{"designTheme":"Classic Professional","brandColor":"#5665F2","typographyStyle":"Fira Sans"},"front":[{"instanceId":"fullName","fieldKey":"fullName","label":"Full Name"}],"back":[{"instanceId":"barcode","fieldKey":"barcode","label":"Barcode"}]}',
            Secondary_Logo_URL__c =
                URL.getOrgDomainUrl().toExternalForm() +
                '/sfc/servlet.shepherd/document/download/' +
                secondaryLogoVersion.ContentDocumentId
        );
        templateRecord.put(FIELD_INSTITUTE, 'Somaiya School of Design;Somaiya Sports Academy');
        insert templateRecord;

        Test.startTest();
        List<KenIdLifecycleManagerController.KenTemplateSummary> summaries =
            KenIdLifecycleManagerController.getTemplates();
        Test.stopTest();

        System.assertEquals(1, summaries.size());
        System.assertEquals('Arts Template', summaries[0].templateName);
        System.assertEquals('Somaiya School of Design, Somaiya Sports Academy', summaries[0].instituteName);
        System.assertEquals(false, summaries[0].isActive);
        System.assertEquals(true, summaries[0].deactive);
        System.assertEquals('ARTS-2027-001', summaries[0].idNumber);
        System.assertEquals('Classic Professional', summaries[0].designTheme);
        System.assertEquals('#5665F2', summaries[0].brandColor);
        System.assertEquals('Fira Sans', summaries[0].typographyStyle);
        System.assert(
            summaries[0].fieldConfigurationJson.contains('"fieldKey":"fullName"'),
            'The summary should include the stored field configuration JSON.'
        );
        System.assert(
            summaries[0].secondaryLogoUrl.contains('/lightning/r/ContentDocument/' + secondaryLogoVersion.ContentDocumentId + '/view'),
            'The stored file link should be normalized to a Salesforce file view URL.'
        );
        System.assert(
            summaries[0].secondaryLogoPreviewUrl.contains(
                '/sfc/servlet.shepherd/document/download/' + secondaryLogoVersion.ContentDocumentId
            ),
            'The preview URL should keep an embeddable download endpoint.'
        );
    }
}