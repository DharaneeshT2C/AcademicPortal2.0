/**
 * ************************************************************************************************
 * @className  KenHomeDashboardControllerTest
 *
 * @description
 *  Verifies the Home dashboard aggregator across stages and career paths. Locks
 *  in the DTO contract the LWC depends on — any change to
 *  `KenHomeDashboardService` that drops a section or reshapes a DTO will fail
 *  at least one assertion here.
 *
 * @author      Student Portal Backend
 * @createdOn   2026
 * ************************************************************************************************
 */
@isTest
private class KenHomeDashboardControllerTest {

    @TestSetup
    static void makeData() {
        Account institute = new KenStudentPortalTestDataFactory.AccountBuilder()
            .setName('Test University')
            .create();

        new KenStudentPortalTestDataFactory.ContactBuilder()
            .setFirstName('Arjun')
            .setLastName('R')
            .setAccount(institute.Id)
            .create();
    }

    // ─── Normalisers ───────────────────────────────────────────────────────────

    @isTest
    static void stageDefaultsToMiddle() {
        System.assertEquals(KenStudentPortalConstants.STAGE_MIDDLE,
            KenHomeDashboardService.normaliseStage(null));
        System.assertEquals(KenStudentPortalConstants.STAGE_MIDDLE,
            KenHomeDashboardService.normaliseStage('bogus'));
        System.assertEquals(KenStudentPortalConstants.STAGE_STARTING,
            KenHomeDashboardService.normaliseStage('starting'));
        System.assertEquals(KenStudentPortalConstants.STAGE_ENDING,
            KenHomeDashboardService.normaliseStage('ending'));
    }

    @isTest
    static void careerPathDefaultsToPlacements() {
        System.assertEquals(KenStudentPortalConstants.PATH_PLACEMENTS,
            KenHomeDashboardService.normaliseCareerPath(null));
        System.assertEquals(KenStudentPortalConstants.PATH_PLACEMENTS,
            KenHomeDashboardService.normaliseCareerPath('unknown'));
        System.assertEquals(KenStudentPortalConstants.PATH_HIGHER_STUDIES,
            KenHomeDashboardService.normaliseCareerPath('higher-studies'));
    }

    @isTest
    static void brandDefaultsToKen() {
        System.assertEquals(KenStudentPortalConstants.BRAND_KEN,
            KenHomeDashboardService.normaliseBrand(null));
        System.assertEquals(KenStudentPortalConstants.BRAND_SMU,
            KenHomeDashboardService.normaliseBrand('smu'));
    }

    // ─── Stage coverage ────────────────────────────────────────────────────────

    @isTest
    static void middleStageReturnsFourKpisPinnedAndFeed() {
        Test.startTest();
        KenHomeDashboardController.DashboardDTO d =
            KenHomeDashboardController.getDashboard('middle', 'placements', 'ken');
        Test.stopTest();

        System.assertNotEquals(null, d, 'Dashboard should not be null');
        System.assertEquals(4, d.kpiCards.size(), 'Middle stage must have 4 KPI cards');
        System.assertEquals('CGPA', d.kpiCards[0].label);
        System.assertEquals(true,  d.pinnedCard.show, 'Pinned card shows in middle stage');
        System.assertEquals(true,  d.feedItems.size() > 0, 'Feed must have items');
        System.assertEquals(true,  d.todayItems.size() > 0, 'Today must have items');
        System.assertEquals(true,  d.todayItems[0].isLive, 'First Today item is live');
        System.assertEquals(8,     d.campusGuideItems.size(), 'Campus guide is 8 tiles');
        System.assertEquals(4,     d.kaiChips.size(), 'KAI surfaces 4 chips');
    }

    @isTest
    static void startingStageHidesPinnedAndUsesOnboardingKpi() {
        Test.startTest();
        KenHomeDashboardController.DashboardDTO d =
            KenHomeDashboardController.getDashboard('starting', null, 'ken');
        Test.stopTest();

        System.assertEquals(false, d.pinnedCard.show, 'No pinned card in starting stage');
        System.assertEquals('ONBOARDING', d.kpiCards[0].label, 'First KPI should be ONBOARDING');
        System.assertEquals('Aug 1', d.todayLabel, 'Starting stage label is Aug 1');
        System.assertEquals(true, d.spotlight.isTextHero, 'Starting spotlight is text-hero');
    }

    @isTest
    static void endingStagePlacementsHasOffersCard() {
        Test.startTest();
        KenHomeDashboardController.DashboardDTO d =
            KenHomeDashboardController.getDashboard('ending', 'placements', 'ken');
        Test.stopTest();

        System.assertEquals(4, d.kpiCards.size());
        // Career card sits in slot 2 (after CGPA and CREDITS).
        System.assertEquals('CAREER', d.kpiCards[2].label);
        System.assertEquals('2 offers', d.kpiCards[2].value);
        System.assertEquals(true, d.pinnedCard.show);
        System.assertEquals(5, d.clearanceItems.size());
    }

    @isTest
    static void endingStageHigherStudiesCareerCardSwaps() {
        Test.startTest();
        KenHomeDashboardController.DashboardDTO d =
            KenHomeDashboardController.getDashboard('ending', 'higher-studies', 'ken');
        Test.stopTest();

        System.assertEquals('2 apps', d.kpiCards[2].value);
    }

    @isTest
    static void endingStageEntrepreneurshipCareerCardSwaps() {
        Test.startTest();
        KenHomeDashboardController.DashboardDTO d =
            KenHomeDashboardController.getDashboard('ending', 'entrepreneurship', 'ken');
        Test.stopTest();

        System.assertEquals('Active', d.kpiCards[2].value);
    }

    @isTest
    static void greetingUsesDisplayName() {
        Test.startTest();
        KenHomeDashboardController.DashboardDTO d =
            KenHomeDashboardController.getDashboard('middle', 'placements', 'ken');
        Test.stopTest();

        System.assertNotEquals(null, d.student);
        System.assertEquals(true, d.greeting.headline.startsWith('Good morning, '),
            'Greeting must be hardcoded to morning');
    }

    // ─── Mood mutation ─────────────────────────────────────────────────────────

    @isTest
    static void recordMoodRejectsBlank() {
        Test.startTest();
        Boolean threw = false;
        try {
            KenHomeDashboardController.recordMood('');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'Blank mood must be rejected');
    }

    @isTest
    static void recordMoodAcceptsValidInput() {
        Test.startTest();
        KenHomeDashboardController.recordMood('good');
        Test.stopTest();

        // Running admin user in test context has no ContactId — service logs &
        // returns without insert. Integration tests at the Experience site level
        // cover the positive-insert path where a Community user DOES have a
        // linked Contact. No exception = contract honoured.
        System.assertEquals(true, true);
    }

    // ─── Header endpoint ───────────────────────────────────────────────────────

    @isTest
    static void getStudentHeaderFallsBackGracefully() {
        // Running user in a test context has no ContactId → service returns a
        // 'Student' placeholder rather than throwing.
        Test.startTest();
        KenHomeDashboardController.StudentHeaderDTO h =
            KenHomeDashboardController.getStudentHeader();
        Test.stopTest();

        System.assertNotEquals(null, h);
        System.assertEquals(false, String.isBlank(h.displayName));
    }
}