@isTest(SeeAllData=false)
private class KenMetadataDeployCallbackTest {
    @isTest
    static void handleResultRunsWithoutError() {
        KenMetadataDeployCallback callback = new KenMetadataDeployCallback();
        Metadata.DeployResult result = new Metadata.DeployResult();
        Metadata.DeployCallbackContext context = new Metadata.DeployCallbackContext();
        Test.startTest();
        callback.handleResult(result, context);
        Test.stopTest();
        System.assertNotEquals(null, callback, 'Callback instance should be constructible.');
    }
}