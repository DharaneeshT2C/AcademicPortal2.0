/**
 * ************************************************************************************************
 * @className  KenFaqsController
 *
 * @description
 *  Backs `my/faqs` — FAQ accordion grouped by category. Content typically
 *  maintained by admins.
 *
 *  TODO[SOBJECT]: Prefer Custom Metadata `Faq_Entry__mdt` so admins can publish
 *                 edits without code deploys. Until available, returns a seeded
 *                 set keyed by category.
 * ************************************************************************************************
 */
public with sharing class KenFaqsController {

    public class FaqEntryDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String question;
        @AuraEnabled public String answer;
        @AuraEnabled public Integer sortOrder;
    }

    public class FaqCategoryDTO {
        @AuraEnabled public String             categoryName;
        @AuraEnabled public List<FaqEntryDTO>  entries;
    }

    @AuraEnabled(cacheable=true)
    public static List<FaqCategoryDTO> getFaqs() {
        try {
            return new List<FaqCategoryDTO>();
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenFaqsController.getFaqs',
                'Unable to load FAQs.', e);
            return null;
        }
    }
}