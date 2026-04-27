// code-analyzer-suppress(pmd:ApexUnitTestClassShouldHaveRunAs)
@IsTest
private class KenServiceBreadcrumbControllerTest {
    @IsTest
    static void getServiceNameHandlesBlankInvalidValidAndDeletedIds() {
        Account serviceAccount = new Account(Name = 'Breadcrumb Service Account');
        insert serviceAccount;

        Test.startTest();
        String blankValue = KenServiceBreadcrumbController.getServiceName(null);
        String invalidValue = KenServiceBreadcrumbController.getServiceName('not-an-id');
        String validValue = KenServiceBreadcrumbController.getServiceName(String.valueOf(serviceAccount.Id));
        delete serviceAccount;
        String deletedValue = KenServiceBreadcrumbController.getServiceName(String.valueOf(serviceAccount.Id));
        Test.stopTest();

        System.assertEquals(null, blankValue, 'Blank ids should return null.');
        System.assertEquals(null, invalidValue, 'Invalid ids should return null.');
        System.assertEquals(serviceAccount.Name, validValue, 'Expected the dynamic query to return the record name.');
        System.assertEquals(null, deletedValue, 'Deleted records should return null.');
    }
}