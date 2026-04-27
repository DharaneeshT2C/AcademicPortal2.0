@isTest(SeeAllData=false)
private class UiThemeControllerTest {
    @isTest
    static void returnsSanitizedColorsWhenSettingsPresent() {
        new KenTestDataFactory.OrganizationDefaultsParametersCreator()
            .setPrimaryColorForSF('aabbcc')
            .setSecondaryColorForSF('#112233')
            .create();

        Test.startTest();
        UiThemeController.ThemeColors colors = UiThemeController.getThemeColors();
        Test.stopTest();

        System.assertEquals('#aabbcc', colors.primary, 'Primary color should be normalized with # prefix.');
        System.assertEquals('#112233', colors.secondary, 'Secondary color should pass through when already valid.');
    }

    @isTest
    static void returnsNullsWhenColorsInvalid() {
        new KenTestDataFactory.OrganizationDefaultsParametersCreator()
            .setPrimaryColorForSF('notahex')
            .setSecondaryColorForSF(null)
            .create();

        Test.startTest();
        UiThemeController.ThemeColors colors = UiThemeController.getThemeColors();
        Test.stopTest();

        System.assertEquals(null, colors.primary, 'Invalid primary color should sanitize to null.');
        System.assertEquals(null, colors.secondary, 'Blank secondary should sanitize to null.');
    }

    @isTest
    static void returnsNullsWhenNoSettingRecord() {
        delete [SELECT Id FROM Organization_Default_Parameters__c];
        Test.startTest();
        UiThemeController.ThemeColors colors = UiThemeController.getThemeColors();
        Test.stopTest();

        System.assertEquals(null, colors.primary, 'No settings row should yield null primary.');
        System.assertEquals(null, colors.secondary, 'No settings row should yield null secondary.');
    }
}