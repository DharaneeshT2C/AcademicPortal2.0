// code-analyzer-suppress(pmd:ApexUnitTestClassShouldHaveRunAs)
@IsTest
private class KenPortalConfigControllerTest {
    @IsTest
    static void getPortalConfigsReturnsDefaultValues() {
        Test.startTest();
        KenPortalConfigController.portalconfigs response = KenPortalConfigController.getPortalConfigs();
        Test.stopTest();

        System.assertNotEquals(null, response, 'Expected portal configuration payload.');
        System.assertEquals(null, response.primaryColor, 'Primary color should default to null.');
        System.assertEquals(null, response.secondaryColor, 'Secondary color should default to null.');
        System.assertEquals(null, response.tertiaryColor, 'Tertiary color should default to null.');
        System.assertEquals('Kenverse', response.institutionName, 'Institution name should fall back to the hard-coded default.');
        System.assertEquals('Ken42', response.institutionAlias, 'Institution alias should fall back to the hard-coded default.');
    }
}