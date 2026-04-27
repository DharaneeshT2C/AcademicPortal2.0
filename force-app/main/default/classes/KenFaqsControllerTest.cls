/**
 * ************************************************************************************************
 * @className  KenFaqsControllerTest
 * ************************************************************************************************
 */
@isTest
private class KenFaqsControllerTest {

    @isTest
    static void faqsReturnCategoriesWithEntries() {
        Test.startTest();
        List<KenFaqsController.FaqCategoryDTO> cats = KenFaqsController.getFaqs();
        Test.stopTest();

        System.assertNotEquals(null, cats);
        System.assertEquals(true, cats.size() > 0);
        for (KenFaqsController.FaqCategoryDTO c : cats) {
            System.assertNotEquals(null, c.categoryName);
            System.assertEquals(true, c.entries.size() > 0);
        }
    }
}