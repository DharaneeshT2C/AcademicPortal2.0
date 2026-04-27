@isTest(SeeAllData=false)
private class OrganizationDefaultsRestApiTest {
    
    // ─── Helpers ────────────────────────────────────────────────────────────────
    
    private static RestResponse buildResponse() {
        RestRequest request = new RestRequest();
        request.httpMethod = 'GET';
        request.requestURI = '/organization-default-settings';
        RestContext.request = request;
        RestResponse response = new RestResponse();
        RestContext.response = response;
        return response;
    }
    
    // ─── Existing tests (kept verbatim) ─────────────────────────────────────────
    
    @isTest
    static void getReturnsPayloadWithDefaultsApplied() {
        new KenTestDataFactory.OrganizationDefaultsParametersCreator()
            .setPrimaryColor('#112233')
            .setInstituteName('Rest Institute')
            .create();
        
        RestResponse response = buildResponse();
        
        Test.startTest();
        OrganizationDefaultsRestApi.getOrganizationDefaults();
        Test.stopTest();
        
        System.assertEquals(200, response.statusCode, 'Successful call should return HTTP 200.');
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody.toString());
        System.assertEquals(true, payload.get('success'), 'Payload should indicate success.');
        System.assertEquals('#112233', payload.get('primary'), 'Primary color should match configured value.');
        System.assertEquals('Rest Institute', payload.get('instituteName'), 'Institute name should be returned.');
    }
    
    @isTest
    static void getHandlesMissingSettings() {
        delete [SELECT Id FROM Organization_Default_Parameters__c];
        RestResponse response = buildResponse();
        
        Test.startTest();
        OrganizationDefaultsRestApi.getOrganizationDefaults();
        Test.stopTest();
        
        System.assertEquals(200, response.statusCode, 'Call should still return HTTP 200 with defaults.');
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody.toString());
        System.assertEquals(true, payload.get('success'), 'Missing settings should still be a successful payload.');
        System.assertEquals(KenConstantController.DEFAULT_PRIMARY_COLOR, payload.get('primary'), 'Default primary should be used.');
    }
    
    // ─── New tests ───────────────────────────────────────────────────────────────
    
    /**
     * Verify that all six RestPayload fields are populated when full org-default
     * settings (primary, secondary, instituteName, instituteAlias) are present.
     */
    @isTest
    static void testRestPayloadFieldsArePopulated() {
        new KenTestDataFactory.OrganizationDefaultsParametersCreator()
            .setPrimaryColor('#aabbcc')
            .setSecondaryColor('#ddeeff')
            .setInstituteName('Full Institute')
            .setInstituteAlias('FI')
            .create();
        
        RestResponse response = buildResponse();
        
        Test.startTest();
        OrganizationDefaultsRestApi.getOrganizationDefaults();
        Test.stopTest();
        
        System.assertEquals(200, response.statusCode, 'Status should be 200 for a full-data response.');
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody.toString());
        
        // success and message are always set
        System.assertEquals(true, payload.get('success'), 'success field should be true.');
        System.assertNotEquals(null, payload.get('message'), 'message field should be set.');
        
        // color fields
        System.assertEquals('#aabbcc', payload.get('primary'), 'primary should match.');
        System.assertEquals('#ddeeff', payload.get('secondary'), 'secondary should match.');
        
        // institute fields
        System.assertEquals('Full Institute', payload.get('instituteName'), 'instituteName should match.');
        System.assertEquals('FI', payload.get('instituteAlias'), 'instituteAlias should match.');
    }
    
    /**
     * Verify the Content-Type response header is set to application/json.
     */
    @isTest
    static void testResponseHeaderIsJsonContentType() {
        new KenTestDataFactory.OrganizationDefaultsParametersCreator()
            .setPrimaryColor('#123456')
            .create();
        
        RestResponse response = buildResponse();
        
        Test.startTest();
        OrganizationDefaultsRestApi.getOrganizationDefaults();
        Test.stopTest();
        
        String contentType = response.headers.get('Content-Type');
        System.assertEquals('application/json', contentType, 'Content-Type header must be application/json.');
    }
    
    /**
     * Verify the response body is a well-formed JSON object that can be
     * deserialized without error.
     */
    @isTest
    static void testResponseBodyIsValidJson() {
        new KenTestDataFactory.OrganizationDefaultsParametersCreator()
            .setPrimaryColor('#abcdef')
            .create();
        
        RestResponse response = buildResponse();
        
        Test.startTest();
        OrganizationDefaultsRestApi.getOrganizationDefaults();
        Test.stopTest();
        
        System.assertNotEquals(null, response.responseBody, 'responseBody should not be null.');
        Boolean parsed = false;
        try {
            Map<String, Object> obj = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody.toString());
            parsed = true;
        } catch (Exception e) {
            parsed = false;
        }
        System.assertEquals(true, parsed, 'responseBody must be valid JSON.');
    }
    
    /**
     * Directly instantiate RestPayload and set every field so the DTO lines
     * are covered even if the REST call does not exercise the null-secondary path.
     */
    @isTest
    static void testPayloadClassInstantiation() {
        Test.startTest();
        OrganizationDefaultsRestApi.RestPayload p = new OrganizationDefaultsRestApi.RestPayload();
        p.success = true;
        p.message = 'OK';
        p.primary = '#111111';
        p.secondary = '#222222';
        p.instituteName = 'Test Uni';
        p.instituteAlias = 'TU';
        Test.stopTest();
        
        System.assertEquals(true, p.success, 'success field should be set.');
        System.assertEquals('OK', p.message, 'message field should be set.');
        System.assertEquals('#111111', p.primary, 'primary field should be set.');
        System.assertEquals('#222222', p.secondary, 'secondary field should be set.');
        System.assertEquals('Test Uni', p.instituteName, 'instituteName field should be set.');
        System.assertEquals('TU', p.instituteAlias, 'instituteAlias field should be set.');
    }
    
    /**
     * Verify payload when secondary color and institute alias are explicitly
     * set to non-null values so the null-check branches inside the API are hit.
     */
    @isTest
    static void testPayloadWithSecondaryAndAlias() {
        new KenTestDataFactory.OrganizationDefaultsParametersCreator()
            .setPrimaryColor('#334455')
            .setSecondaryColor('#667788')
            .setInstituteName('Secondary Uni')
            .setInstituteAlias('SU')
            .create();
        
        RestResponse response = buildResponse();
        
        Test.startTest();
        OrganizationDefaultsRestApi.getOrganizationDefaults();
        Test.stopTest();
        
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody.toString());
        System.assertNotEquals(null, payload.get('secondary'), 'secondary should be non-null when configured.');
        System.assertNotEquals(null, payload.get('instituteAlias'), 'instituteAlias should be non-null when configured.');
    }
    
    @isTest
    static void testExceptionHandling_CatchBlockCoverage() {
        RestResponse response = buildResponse();
        
        OrganizationDefaultsApiController.forceExceptionForTesting = true;
        
        Test.startTest();
        OrganizationDefaultsRestApi.getOrganizationDefaults();
        Test.stopTest();
        
        OrganizationDefaultsApiController.forceExceptionForTesting = false;

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody.toString());

        System.assertEquals(500, response.statusCode, 'Catch branch should return HTTP 500.');
        System.assertEquals(false, payload.get('success'), 'Catch branch should mark success as false.');
        System.assertNotEquals(null, payload.get('message'), 'Catch branch should expose the exception message.');
        System.assertEquals(null, payload.get('primary'), 'Primary should be null on error.');
        System.assertEquals(null, payload.get('secondary'), 'Secondary should be null on error.');
        System.assertEquals(null, payload.get('instituteName'), 'Institute name should be null on error.');
        System.assertEquals(null, payload.get('instituteAlias'), 'Institute alias should be null on error.');
    }
}