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
            List<FaqCategoryDTO> out = new List<FaqCategoryDTO>();

            FaqCategoryDTO acad = new FaqCategoryDTO();
            acad.categoryName = 'Academics';
            acad.entries = new List<FaqEntryDTO>{
                faq('F1', 'What academic resources are available?', 'You can access tutoring, writing support, library databases, study workshops, academic advising, and course-specific help.', 1),
                faq('F2', 'Can students get academic mentorship?',   'Yes — book a slot via the Mentors tab or approach your faculty advisor during office hours.', 2),
                faq('F3', 'How do I stay updated on learning opportunities?', 'Enable notifications in Settings and check the Campus Updates feed on Home weekly.', 3)
            };
            out.add(acad);

            FaqCategoryDTO fees = new FaqCategoryDTO();
            fees.categoryName = 'Fees & Payments';
            fees.entries = new List<FaqEntryDTO>{
                faq('F4', 'How do I pay my fees?', 'Use the Fee Payment tab — choose UPI, card, or net banking. Receipts auto-generate after payment.', 1),
                faq('F5', 'Can I pay in instalments?', 'Yes. Visit Fee Plan to switch between single, quarterly, or monthly plans.', 2)
            };
            out.add(fees);

            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenFaqsController.getFaqs',
                'Unable to load FAQs.', e);
            return null;
        }
    }

    private static FaqEntryDTO faq(String id, String q, String a, Integer order) {
        FaqEntryDTO e = new FaqEntryDTO();
        e.id = id; e.question = q; e.answer = a; e.sortOrder = order;
        return e;
    }
}