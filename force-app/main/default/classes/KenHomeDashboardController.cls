/**
 * ************************************************************************************************
 * @className  KenHomeDashboardController
 *
 * @description
 *  Single aggregator entry-point that backs `my/dashboard` (the Home page).
 *
 *  The LWC invokes `getDashboard(stage, careerPath, brand)` once on mount and
 *  again whenever the dev toolbar changes stage or path. The method returns a
 *  `DashboardDTO` that maps 1:1 onto the getters in `dashboard.js`
 *  (kpiCards, feedItems, pinnedCard, todayItems, spotlight, quickActions,
 *  campusGuideItems, kaiChips, greeting, student display name).
 *
 *  Heavy lifting is delegated to `KenHomeDashboardService`.
 *
 * @author      Student Portal Backend
 * @createdOn   2026
 * ************************************************************************************************
 */
public with sharing class KenHomeDashboardController {

    // ─── DTOs ───────────────────────────────────────────────────────────────────

    public class DashboardDTO {
        @AuraEnabled public StudentHeaderDTO       student;
        @AuraEnabled public GreetingDTO            greeting;
        @AuraEnabled public List<KpiCardDTO>       kpiCards;
        @AuraEnabled public PinnedCardDTO          pinnedCard;
        @AuraEnabled public List<FeedItemDTO>      feedItems;
        @AuraEnabled public List<ForYouItemDTO>    forYouItems;
        @AuraEnabled public List<AttentionItemDTO> needsAttention;
        @AuraEnabled public List<ScheduleItemDTO>  todayItems;
        @AuraEnabled public String                 todayLabel;
        @AuraEnabled public SpotlightDTO           spotlight;
        @AuraEnabled public List<QuickActionDTO>   quickActions;
        @AuraEnabled public List<CampusGuideDTO>   campusGuideItems;
        @AuraEnabled public List<KaiChipDTO>       kaiChips;
        @AuraEnabled public List<ClearanceItemDTO> clearanceItems;
    }

    public class StudentHeaderDTO {
        @AuraEnabled public Id      contactId;
        @AuraEnabled public String  firstName;
        @AuraEnabled public String  lastName;
        @AuraEnabled public String  displayName;
        @AuraEnabled public String  programLine;
        @AuraEnabled public String  streakLine;
        @AuraEnabled public String  avatarInitials;
    }

    public class GreetingDTO {
        @AuraEnabled public String headline;
        @AuraEnabled public String sub;
    }

    public class KpiCardDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  label;
        @AuraEnabled public String  value;
        @AuraEnabled public String  accentClass;
        @AuraEnabled public String  dotClass;
        @AuraEnabled public String  pill;
        @AuraEnabled public String  pillClass;
        @AuraEnabled public Boolean pillHasArrow;
        @AuraEnabled public Boolean pillHasDot;
        @AuraEnabled public String  pillDotClass;
        @AuraEnabled public Boolean isPlainValue;
        @AuraEnabled public Boolean isCheckValue;
        @AuraEnabled public Boolean isClockValue;
        @AuraEnabled public String  sparkPoints;
        @AuraEnabled public String  sparklineStyle;
    }

    public class PinnedCardDTO {
        @AuraEnabled public Boolean show;
        @AuraEnabled public String  eyebrow;
        @AuraEnabled public String  title;
        @AuraEnabled public String  description;
        @AuraEnabled public String  ctaLabel;
        @AuraEnabled public String  route;
    }

    public class FeedItemDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  tag;
        @AuraEnabled public String  tagClass;
        @AuraEnabled public String  dateMonth;
        @AuraEnabled public String  dateDay;
        @AuraEnabled public String  title;
        @AuraEnabled public String  description;
        @AuraEnabled public Boolean isSocial;
        @AuraEnabled public String  socialText;
    }

    public class ForYouItemDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String icon;
        @AuraEnabled public String tileClass;
        @AuraEnabled public String title;
        @AuraEnabled public String meta;
        @AuraEnabled public String route;
        @AuraEnabled public String toast;
    }

    public class AttentionItemDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String meta;
        @AuraEnabled public String dotClass;
    }

    public class ScheduleItemDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  startTime;
        @AuraEnabled public String  subject;
        @AuraEnabled public String  location;
        @AuraEnabled public String  stripeStyle;
        @AuraEnabled public Boolean isLive;
    }

    public class SpotlightDTO {
        @AuraEnabled public String eyebrow;
        @AuraEnabled public String heroValue;
        @AuraEnabled public String subLabel;
        @AuraEnabled public String dateRange;
        @AuraEnabled public String ctaLabel;
        @AuraEnabled public String route;
        @AuraEnabled public Boolean isTextHero;
    }

    public class QuickActionDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String emoji;
        @AuraEnabled public String label;
        @AuraEnabled public String route;
        @AuraEnabled public String toast;
    }

    public class CampusGuideDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String emoji;
        @AuraEnabled public String label;
        @AuraEnabled public String route;
    }

    public class KaiChipDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String text;
    }

    public class ClearanceItemDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  text;
        @AuraEnabled public Boolean isDone;
    }

    // ─── Entry points ──────────────────────────────────────────────────────────

    /**
     * @description
     *  Primary aggregator. Returns the full dashboard payload for the current
     *  running user, parameterised by stage + career path + brand.
     *
     * @param stage      'starting' | 'middle' | 'ending'. Defaults to 'middle'.
     * @param careerPath Only consulted when `stage == 'ending'`. One of
     *                   'placements', 'higher-studies', 'entrepreneurship', 'exploring'.
     * @param brand      'ken' | 'smu'. Passed through unmodified for now; reserved
     *                   for branded copy (e.g. "Ken University" vs "SMU") in future.
     * @return DashboardDTO
     */
    @AuraEnabled(cacheable=true)
    public static DashboardDTO getDashboard(String stage, String careerPath, String brand) {
        try {
            String s = KenHomeDashboardService.normaliseStage(stage);
            String p = KenHomeDashboardService.normaliseCareerPath(careerPath);
            String b = KenHomeDashboardService.normaliseBrand(brand);
            return KenHomeDashboardService.buildDashboard(s, p, b);
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled(
                'KenHomeDashboardController.getDashboard',
                'Unable to load your dashboard right now. Please try again.',
                e
            );
            return null;
        }
    }

    /**
     * @description
     *  Lightweight endpoint used by the sidebar to render the student header
     *  (avatar initials, name, program line, streak). Split from `getDashboard`
     *  so the sidebar can cache it independently with `@wire`.
     */
    @AuraEnabled(cacheable=true)
    public static StudentHeaderDTO getStudentHeader() {
        try {
            return KenHomeDashboardService.buildStudentHeader();
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled(
                'KenHomeDashboardController.getStudentHeader',
                'Unable to load your profile.',
                e
            );
            return null;
        }
    }

    /**
     * @description
     *  Writes the selected mood to the student's weekly check-in record.
     *  Not cacheable (DML).
     *
     * @param mood 'good' | 'okay' | 'rough'
     */
    @AuraEnabled
    public static void recordMood(String mood) {
        try {
            KenAuraExceptionHelper.rejectIf(String.isBlank(mood), 'Mood value is required.');
            KenHomeDashboardService.recordMood(mood);
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled(
                'KenHomeDashboardController.recordMood',
                'Could not save your check-in. Please try again.',
                e
            );
        }
    }
}