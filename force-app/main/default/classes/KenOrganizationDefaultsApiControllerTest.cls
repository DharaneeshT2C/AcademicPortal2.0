/**
 * ************************************************************************************************
 * @className  KenOrganizationDefaultsApiControllerTest
 *
 * @description
 *  Test class for OrganizationDefaultsApiController.
 *
 *  Responsibilities:
 *  - Validate fallback behavior when org defaults are missing
 *  - Validate hex color sanitization and normalization
 *  - Validate institute name and alias pass-through
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
private class KenOrganizationDefaultsApiControllerTest {
    /**
     * @description Creates baseline test user required by runAs tests.
     */
    @TestSetup
    static void makeData() {
        new TestDataFactory.UserCreator('System Administrator')
            .setAlias('usrimp')
            .create();
    }

    /**
     * @description Verifies defaults are returned when org-level setting is absent.
     */
    @isTest
    static void getOrganizationDefaultsReturnsFallbacksWhenSettingMissing() {
        User runUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'usrimp'
            AND Profile.Name = :ConstantController.SYSTEM_ADMIN
            LIMIT 1
        ];

        System.runAs(runUser) {
            Test.startTest();
            OrganizationDefaultsApiController.OrganizationDefaultsResponse response =
                OrganizationDefaultsApiController.getOrganizationDefaults();
            Test.stopTest();

            System.assertNotEquals(null, response, 'Response should never be null.');
            System.assertEquals(
                ConstantController.DEFAULT_PRIMARY_COLOR,
                response.primary,
                'Primary color should fall back when no org setting exists.'
            );
            System.assertEquals(
                ConstantController.DEFAULT_SECONDARY_COLOR,
                response.secondary,
                'Secondary color should fall back when no org setting exists.'
            );
            System.assertEquals(
                null,
                response.instituteName,
                'Institute name should be null when no setting exists.'
            );
            System.assertEquals(
                null,
                response.instituteAlias,
                'Institute alias should be null when no setting exists.'
            );
        }
    }

    /**
     * @description Verifies valid colors are sanitized and institute fields are returned.
     */
    @isTest
    static void getOrganizationDefaultsReturnsSanitizedColorsAndInstituteFieldsWhenSettingValid() {
        User runUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'usrimp'
            AND Profile.Name = :ConstantController.SYSTEM_ADMIN
            LIMIT 1
        ];

        System.runAs(runUser) {
            new TestDataFactory.OrganizationDefaultsParametersCreator()
                .setPrimaryColor('a1b2c3')
                .setSecondaryColor('  #D4E5F6  ')
                .setInstituteName('Academic Product University')
                .setInstituteAlias('APU')
                .create();

            Test.startTest();
            OrganizationDefaultsApiController.OrganizationDefaultsResponse response =
                OrganizationDefaultsApiController.getOrganizationDefaults();
            Test.stopTest();

            System.assertEquals('#a1b2c3', response.primary, 'Color should be prefixed with # when missing.');
            System.assertEquals('#D4E5F6', response.secondary, 'Color should be trimmed and preserved when valid.');
            System.assertEquals(
                'Academic Product University',
                response.instituteName,
                'Institute name should be returned from the org defaults setting.'
            );
            System.assertEquals('APU', response.instituteAlias, 'Institute alias should be returned from the org defaults setting.');
        }
    }

    /**
     * @description Verifies fallback colors are used for invalid and blank values.
     */
    @isTest
    static void getOrganizationDefaultsUsesFallbacksWhenColorsInvalidOrBlank() {
        User runUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'usrimp'
            AND Profile.Name = :ConstantController.SYSTEM_ADMIN
            LIMIT 1
        ];

        System.runAs(runUser) {
            new TestDataFactory.OrganizationDefaultsParametersCreator()
                .setPrimaryColor('12345')
                .setSecondaryColor('   ')
                .setInstituteName('Institute X')
                .setInstituteAlias('IX')
                .create();

            Test.startTest();
            OrganizationDefaultsApiController.OrganizationDefaultsResponse response =
                OrganizationDefaultsApiController.getOrganizationDefaults();
            Test.stopTest();

            System.assertEquals(
                ConstantController.DEFAULT_PRIMARY_COLOR,
                response.primary,
                'Invalid 5-digit hex should fall back.'
            );
            System.assertEquals(
                ConstantController.DEFAULT_SECONDARY_COLOR,
                response.secondary,
                'Blank secondary color should fall back.'
            );
            System.assertEquals('Institute X', response.instituteName, 'Institute name should still be returned.');
            System.assertEquals('IX', response.instituteAlias, 'Institute alias should still be returned.');
        }
    }

    /**
     * @description Verifies fallback colors are used when non-hex characters are provided.
     */
    @isTest
    static void getOrganizationDefaultsUsesFallbacksWhenNonHexCharactersProvided() {
        User runUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'usrimp'
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

            Test.startTest();
            OrganizationDefaultsApiController.OrganizationDefaultsResponse response =
                OrganizationDefaultsApiController.getOrganizationDefaults();
            Test.stopTest();

            System.assertEquals(
                ConstantController.DEFAULT_PRIMARY_COLOR,
                response.primary,
                'Non-hex characters should fail validation and use fallback.'
            );
            System.assertEquals(
                ConstantController.DEFAULT_SECONDARY_COLOR,
                response.secondary,
                'Non-hex characters should fail validation and use fallback.'
            );
            System.assertEquals('Institute Y', response.instituteName, 'Institute name should still be returned.');
            System.assertEquals('IY', response.instituteAlias, 'Institute alias should still be returned.');
        }
    }
}