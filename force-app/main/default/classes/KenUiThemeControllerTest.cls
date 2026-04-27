/**
 * ************************************************************************************************
 * @className  KenUiThemeControllerTest
 *
 * @description
 *  Test class for UiThemeController.
 *
 *  Responsibilities:
 *  - Validate null response behavior when no setting exists
 *  - Validate color sanitization for valid values
 *  - Validate null fallback for invalid/blank values
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
private class KenUiThemeControllerTest {
    /**
     * @description Creates baseline test user required by runAs tests.
     */
    @TestSetup
    static void makeData() {
        new TestDataFactory.UserCreator(ConstantController.SYSTEM_ADMIN)
            .setAlias('usrthm')
            .create();
    }

    /**
     * @description Validates null colors when settings record is not present.
     */
    @isTest
    static void getThemeColorsReturnsNullsWhenNoSettingExists() {
        User runUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'usrthm'
            AND Profile.Name = :ConstantController.SYSTEM_ADMIN
            LIMIT 1
        ];

        System.runAs(runUser) {
            Test.startTest();
            UiThemeController.ThemeColors result = UiThemeController.getThemeColors();
            Test.stopTest();

            System.assertNotEquals(null, result, 'Response wrapper should not be null.');
            System.assertEquals(null, result.primary, 'Primary should be null when no setting exists.');
            System.assertEquals(null, result.secondary, 'Secondary should be null when no setting exists.');
        }
    }

    /**
     * @description Validates valid color values are sanitized and returned.
     */
    @isTest
    static void getThemeColorsReturnsSanitizedValuesWhenColorsValid() {
        User runUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'usrthm'
            AND Profile.Name = :ConstantController.SYSTEM_ADMIN
            LIMIT 1
        ];

        System.runAs(runUser) {
            new TestDataFactory.OrganizationDefaultsParametersCreator()
                .setPrimaryColorForSF('a1b2c3')
                .setSecondaryColorForSF('  #D4E5F6  ')
                .create();

            Test.startTest();
            UiThemeController.ThemeColors result = UiThemeController.getThemeColors();
            Test.stopTest();

            System.assertEquals('#a1b2c3', result.primary, 'Missing # should be prefixed for valid hex.');
            System.assertEquals('#D4E5F6', result.secondary, 'Whitespace should be trimmed for valid hex.');
        }
    }

    /**
     * @description Validates null output for invalid or blank color values.
     */
    @isTest
    static void getThemeColorsReturnsNullsWhenInvalidOrBlankColorsProvided() {
        User runUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'usrthm'
            AND Profile.Name = :ConstantController.SYSTEM_ADMIN
            LIMIT 1
        ];

        System.runAs(runUser) {
            new TestDataFactory.OrganizationDefaultsParametersCreator()
                .setPrimaryColorForSF('#ZZZZZZ')
                .setSecondaryColorForSF('   ')
                .create();

            Test.startTest();
            UiThemeController.ThemeColors result = UiThemeController.getThemeColors();
            Test.stopTest();

            System.assertEquals(null, result.primary, 'Invalid hex should return null.');
            System.assertEquals(null, result.secondary, 'Blank color should return null.');
        }
    }

    /**
     * @description Validates null output for hex values with invalid length.
     */
    @isTest
    static void getThemeColorsReturnsNullsWhenHexLengthInvalid() {
        User runUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'usrthm'
            AND Profile.Name = :ConstantController.SYSTEM_ADMIN
            LIMIT 1
        ];

        System.runAs(runUser) {
            new TestDataFactory.OrganizationDefaultsParametersCreator()
                .setPrimaryColorForSF('12345')
                .setSecondaryColorForSF('1234567')
                .create();

            Test.startTest();
            UiThemeController.ThemeColors result = UiThemeController.getThemeColors();
            Test.stopTest();

            System.assertEquals(null, result.primary, '5-digit value should fail validation.');
            System.assertEquals(null, result.secondary, '7-digit value should fail validation.');
        }
    }
}