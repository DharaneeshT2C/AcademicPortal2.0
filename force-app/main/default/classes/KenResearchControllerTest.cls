/**
 * ************************************************************************************************
 * @className  KenResearchControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenResearchControllerTest {

    @TestSetup
    static void makeData() {
        new KenStudentPortalTestDataFactory.ContactBuilder().create();
    }

    @isTest
    static void researchBundleReturnsPapersAndProjects() {
        Test.startTest();
        KenResearchController.ResearchBundleDTO b = KenResearchController.getResearchBundle();
        Test.stopTest();

        System.assertNotEquals(null, b);
        System.assertNotEquals(null, b.papers);
        System.assertNotEquals(null, b.projects);
        System.assertEquals(true, b.papers.size() > 0);
        System.assertEquals(true, b.projects.size() > 0);
    }

    @isTest
    static void projectHasValidProgress() {
        Test.startTest();
        KenResearchController.ResearchBundleDTO b = KenResearchController.getResearchBundle();
        Test.stopTest();

        for (KenResearchController.ProjectDTO p : b.projects) {
            System.assertEquals(true, p.progressPct >= 0 && p.progressPct <= 100);
        }
    }
}