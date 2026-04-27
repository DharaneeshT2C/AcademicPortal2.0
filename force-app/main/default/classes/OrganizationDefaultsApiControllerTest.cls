@isTest(SeeAllData=false)
private class OrganizationDefaultsApiControllerTest {
    @isTest
    static void returnsOverridesWhenSettingsConfigured() {
        new KenTestDataFactory.OrganizationDefaultsParametersCreator()
            .setPrimaryColor('#aabbcc')
            .setSecondaryColor('#112233')
            .setPrimaryColorForSF('ddeeff')
            .setSecondaryColorForSF('#445566')
            .setInstituteName('Test Institute')
            .setInstituteAlias('TI')
            .create();
        
        Test.startTest();
        OrganizationDefaultsApiController.OrganizationDefaultsResponse resp =
            OrganizationDefaultsApiController.getOrganizationDefaults();
        Test.stopTest();
        
        System.assertEquals('#aabbcc', resp.primary, 'Primary override should be returned.');
        System.assertEquals('#112233', resp.secondary, 'Secondary override should be returned.');
        System.assertEquals('#ddeeff', resp.primaryForSf, 'PrimaryForSf should be normalized.');
        System.assertEquals('#445566', resp.secondaryForSf, 'SecondaryForSf should be returned.');
        System.assertEquals('Test Institute', resp.instituteName, 'Institute name should be returned.');
        System.assertEquals('TI', resp.instituteAlias, 'Institute alias should be returned.');
    }
    
    @isTest
    static void fallsBackToDefaultsWhenSettingsBlankOrInvalid() {
        new KenTestDataFactory.OrganizationDefaultsParametersCreator()
            .setPrimaryColor('')
            .setSecondaryColor('#08376c')
            .create();
        
        Test.startTest();
        OrganizationDefaultsApiController.OrganizationDefaultsResponse resp =
            OrganizationDefaultsApiController.getOrganizationDefaults();
        Test.stopTest();
        
        System.assertEquals(KenConstantController.DEFAULT_PRIMARY_COLOR, resp.primary, 'Blank primary should fall back to default.');
        System.assertEquals(KenConstantController.DEFAULT_SECONDARY_COLOR, resp.secondary, 'Invalid secondary should fall back to default.');
        System.assertEquals(KenConstantController.DEFAULT_PRIMARY_COLOR, resp.primaryForSf, 'PrimaryForSf should fall back to primary.');
        System.assertEquals(KenConstantController.DEFAULT_SECONDARY_COLOR, resp.secondaryForSf, 'SecondaryForSf should fall back to secondary.');
    }
}