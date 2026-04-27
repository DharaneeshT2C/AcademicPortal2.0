/**
 * ************************************************************************************************
 * @className  KenOrganizationDefaultsRestApiTest
 *
 * @description
 *  Test class for OrganizationDefaultsRestApi.
 *
 *  Responsibilities:
 *  - Validate success payload contract for default and valid-setting paths
 *  - Validate fallback behavior for invalid colors
 *  - Validate error payload contract for exception path
 *
 * @author      Sureka A R K
 * @createdOn   Feb 27, 2026
 *
 * @history
 * ------------------------------------------------------------------------------------------------
 * Version   Date           Author          Description
 * 1.0       Feb 27, 2026   Sureka A R K    Added ApexDocs
 * ************************************************************************************************
 */
@isTest
private class KenOrganizationDefaultsRestApiTest {
    /**
     * @description Creates baseline test user required by runAs tests.
     */
    @TestSetup
    static void makeData() {
        new TestDataFactory.UserCreator(ConstantController.SYSTEM_ADMIN)
            .setAlias('usrora')
            .create();
    }

    /**
     * @description Initializes REST request/response context for API invocation.
     */
    private static void initializeRestContext() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/organization-default-settings';
        request.httpMethod = 'GET';
        RestContext.request = request;
        RestContext.response = new RestResponse();
    }

    /**
     * @description Parses response body into an untyped map for assertions.
     * @return Deserialized response payload.
     */
    private static Map<String, Object> getPayloadMap() {
        String body = RestContext.response.responseBody == null
            ? null
            : RestContext.response.responseBody.toString();
        return (Map<String, Object>) JSON.deserializeUntyped(body);
    }

    /**
     * @description Validates 200 response with fallback payload when no setting exists.
     */
    @isTest
    static void getOrganizationDefaultsReturns200AndFallbackPayloadWhenNoSettingExists() {
        User runUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'usrora'
            AND Profile.Name = :ConstantController.SYSTEM_ADMIN
            LIMIT 1
        ];

        System.runAs(runUser) {
            initializeRestContext();
            Test.startTest();
            OrganizationDefaultsRestApi.getOrganizationDefaults();
            Test.stopTest();

            Map<String, Object> payload = getPayloadMap();
            System.assertEquals(200, RestContext.response.statusCode, 'REST call should return HTTP 200 on success.');
            System.assertEquals(
                'application/json',
                RestContext.response.headers.get('Content-Type'),
                'REST response should declare JSON content type.'
            );
            System.assertEquals(true, payload.get('success'), 'Payload success flag should be true.');
            System.assertEquals(
                'Organization defaults fetched successfully.',
                (String) payload.get('message'),
                'Success payload message should match API contract.'
            );
            System.assertEquals(
                ConstantController.DEFAULT_PRIMARY_COLOR,
                (String) payload.get('primary'),
                'Primary color should fall back to the default.'
            );
            System.assertEquals(
                ConstantController.DEFAULT_SECONDARY_COLOR,
                (String) payload.get('secondary'),
                'Secondary color should fall back to the default.'
            );
            System.assertEquals(null, payload.get('instituteName'), 'Institute name should be null when no settings exist.');
            System.assertEquals(null, payload.get('instituteAlias'), 'Institute alias should be null when no settings exist.');
        }
    }

    /**
     * @description Validates 200 response with sanitized payload for valid settings.
     */
    @isTest
    static void getOrganizationDefaultsReturns200AndSanitizedPayloadWhenSettingValid() {
        User runUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'usrora'
            AND Profile.Name =:ConstantController.SYSTEM_ADMIN
            LIMIT 1
        ];

        System.runAs(runUser) {
            new TestDataFactory.OrganizationDefaultsParametersCreator()
                .setPrimaryColor('a1b2c3')
                .setSecondaryColor('  #D4E5F6  ')
                .setInstituteName('Academic Product University')
                .setInstituteAlias('APU')
                .create();

            initializeRestContext();
            Test.startTest();
            OrganizationDefaultsRestApi.getOrganizationDefaults();
            Test.stopTest();

            Map<String, Object> payload = getPayloadMap();
            System.assertEquals(200, RestContext.response.statusCode, 'REST call should return HTTP 200 on success.');
            System.assertEquals(
                'application/json',
                RestContext.response.headers.get('Content-Type'),
                'REST response should declare JSON content type.'
            );
            System.assertEquals(true, payload.get('success'), 'Payload success flag should be true.');
            System.assertEquals('#a1b2c3', (String) payload.get('primary'), 'Primary color should be normalized with #.');
            System.assertEquals('#D4E5F6', (String) payload.get('secondary'), 'Secondary color should be trimmed/normalized.');
            System.assertEquals(
                'Academic Product University',
                (String) payload.get('instituteName'),
                'Institute name should come from setting.'
            );
            System.assertEquals('APU', (String) payload.get('instituteAlias'), 'Institute alias should come from setting.');
        }
    }

    /**
     * @description Validates 200 response with default colors for invalid input values.
     */
    @isTest
    static void getOrganizationDefaultsReturns200AndDefaultColorsWhenColorsInvalid() {
        User runUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'usrora'
            AND Profile.Name = :ConstantController.SYSTEM_ADMIN
            LIMIT 1
        ];

        System.runAs(runUser) {
            new TestDataFactory.OrganizationDefaultsParametersCreator()
                .setPrimaryColor('#ZZZZZZ')
                .setSecondaryColor('12GG34')
                .setInstituteName('Institute Y')
                .setInstituteAlias('IY')
                .create();

            initializeRestContext();
            Test.startTest();
            OrganizationDefaultsRestApi.getOrganizationDefaults();
            Test.stopTest();

            Map<String, Object> payload = getPayloadMap();
            System.assertEquals(200, RestContext.response.statusCode, 'REST call should return HTTP 200 on success.');
            System.assertEquals(true, payload.get('success'), 'Payload success flag should be true.');
            System.assertEquals(
                ConstantController.DEFAULT_PRIMARY_COLOR,
                (String) payload.get('primary'),
                'Invalid primary input should fall back to default.'
            );
            System.assertEquals(
                ConstantController.DEFAULT_SECONDARY_COLOR,
                (String) payload.get('secondary'),
                'Invalid secondary input should fall back to default.'
            );
            System.assertEquals('Institute Y', (String) payload.get('instituteName'), 'Institute name should still be returned.');
            System.assertEquals('IY', (String) payload.get('instituteAlias'), 'Institute alias should still be returned.');
        }
    }

    /**
     * @description Validates 500 response payload when an exception is forced in tests.
     */
    @isTest
    static void getOrganizationDefaultsReturns500WhenExceptionOccurs() {
        User runUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'usrora'
            AND Profile.Name = :ConstantController.SYSTEM_ADMIN
            LIMIT 1
        ];

        System.runAs(runUser) {
            initializeRestContext();
            OrganizationDefaultsRestApi.forceExceptionForTest = true;

            Test.startTest();
            OrganizationDefaultsRestApi.getOrganizationDefaults();
            Test.stopTest();

            OrganizationDefaultsRestApi.forceExceptionForTest = false;

            Map<String, Object> payload = getPayloadMap();
            System.assertEquals(500, RestContext.response.statusCode, 'REST call should return HTTP 500 on exception.');
            System.assertEquals(false, payload.get('success'), 'Payload success flag should be false.');
            System.assertEquals('Forced test exception', (String) payload.get('message'), 'Error message should propagate.');
            System.assertEquals(null, payload.get('primary'), 'Primary should be null in error payload.');
            System.assertEquals(null, payload.get('secondary'), 'Secondary should be null in error payload.');
            System.assertEquals(null, payload.get('instituteName'), 'Institute name should be null in error payload.');
            System.assertEquals(null, payload.get('instituteAlias'), 'Institute alias should be null in error payload.');
        }
    }
}