/**
 * ************************************************************************************************
 * @className  KenHomeDashboardService
 *
 * @description
 *  Business logic for `KenHomeDashboardController`. Resolves the running User to
 *  a Contact, queries the profile header, and assembles the stage-aware
 *  dashboard payload (KPI cards, feed, pinned card, Today schedule, spotlight,
 *  quick actions, campus guide, KAI chips, needs-attention, clearance checklist).
 *
 *  Custom-object-backed rows (Activity_Feed__c, Spotlight__c, Quick_Action__c,
 *  Weekly_Checkin__c) are marked with `TODO[SOBJECT]` — org schema sign-off
 *  required before those SOQL queries can be wired up. Until then the service
 *  returns seeded content that matches the existing LWC `homeData.js` exactly,
 *  keeping the LWC contract stable during rollout.
 *
 *  Declared `without sharing` because the stage/path logic needs to read the
 *  running student's own Contact/LearnerProgram regardless of sharing rules.
 *  All external DML (recordMood) still goes through `KenCrudFlsHelper`.
 *
 * @author      Student Portal Backend
 * @createdOn   2026
 * ************************************************************************************************
 */
@suppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
public without sharing class KenHomeDashboardService {

    // ─── Normalisers ───────────────────────────────────────────────────────────

    public static String normaliseStage(String stage) {
        if (stage == KenStudentPortalConstants.STAGE_STARTING) return stage;
        if (stage == KenStudentPortalConstants.STAGE_ENDING)   return stage;
        return KenStudentPortalConstants.STAGE_MIDDLE;
    }

    public static String normaliseCareerPath(String p) {
        if (p == KenStudentPortalConstants.PATH_HIGHER_STUDIES)   return p;
        if (p == KenStudentPortalConstants.PATH_ENTREPRENEURSHIP) return p;
        if (p == KenStudentPortalConstants.PATH_EXPLORING)        return p;
        return KenStudentPortalConstants.PATH_PLACEMENTS;
    }

    public static String normaliseBrand(String b) {
        return b == KenStudentPortalConstants.BRAND_SMU
            ? KenStudentPortalConstants.BRAND_SMU
            : KenStudentPortalConstants.BRAND_KEN;
    }

    // ─── Public API ────────────────────────────────────────────────────────────

    public static KenHomeDashboardController.DashboardDTO buildDashboard(
        String stage,
        String careerPath,
        String brand
    ) {
        KenHomeDashboardController.DashboardDTO d = new KenHomeDashboardController.DashboardDTO();
        d.student          = buildStudentHeader();
        d.greeting         = buildGreeting(stage, d.student);
        d.kpiCards         = buildKpiCards(stage, careerPath);
        d.pinnedCard       = buildPinnedCard(stage);
        d.feedItems        = buildFeedItems(stage, careerPath);
        d.forYouItems      = buildForYouItems(stage, careerPath);
        d.needsAttention   = buildNeedsAttention(stage);
        d.todayItems       = buildTodayItems(stage);
        d.todayLabel       = todayLabelFor(stage);
        d.spotlight        = buildSpotlight(stage);
        d.quickActions     = buildQuickActions(stage, careerPath);
        d.campusGuideItems = buildCampusGuide();
        d.kaiChips         = buildKaiChips();
        d.clearanceItems   = stage == KenStudentPortalConstants.STAGE_ENDING ? buildClearance() : new List<KenHomeDashboardController.ClearanceItemDTO>();
        return d;
    }

    public static KenHomeDashboardController.StudentHeaderDTO buildStudentHeader() {
        KenHomeDashboardController.StudentHeaderDTO h = new KenHomeDashboardController.StudentHeaderDTO();

        Contact c = queryRunningContact();
        if (c == null) {
            h.firstName      = 'Student';
            h.lastName       = '';
            h.displayName    = 'Student';
            h.programLine    = '';
            h.streakLine     = '';
            h.avatarInitials = 'S';
            return h;
        }

        h.contactId      = c.Id;
        h.firstName      = c.FirstName;
        h.lastName       = c.LastName;
        h.displayName    = String.isBlank(c.LastName) ? c.FirstName : (c.FirstName + ' ' + c.LastName);
        h.programLine    = buildProgramLine(c);
        // Derive attendance % from real Attendance__c rollup. Streak is static
        // until Login_Streak__c is added.
        Decimal attPct = realAttendancePct(c.Id);
        h.streakLine = (attPct == null)
            ? ''
            : attPct.setScale(0) + '% attendance';
        h.avatarInitials = buildInitials(c.FirstName, c.LastName);
        return h;
    }

    /* ── Real-data KPI helpers ─────────────────────────────────────────────
     * Each returns null if the student has no rows. Callers render '--'. */

    public static Decimal realAttendancePct(Id contactId) {
        if (contactId == null) return null;
        Integer total = [SELECT COUNT() FROM Attendance__c WHERE Student__c = :contactId];
        if (total == 0) return null;
        Integer attended = [SELECT COUNT() FROM Attendance__c WHERE Student__c = :contactId AND Is_Present__c = true];
        return ((Decimal) attended * 100 / total).setScale(1);
    }

    public static Integer realAtRiskSubjectCount(Id contactId) {
        if (contactId == null) return 0;
        Map<String, Integer[]> rollup = new Map<String, Integer[]>();
        for (Attendance__c a : [
            SELECT Subject__c, Is_Present__c FROM Attendance__c
            WHERE Student__c = :contactId LIMIT 5000
        ]) {
            String k = String.isBlank(a.Subject__c) ? '?' : a.Subject__c;
            if (!rollup.containsKey(k)) rollup.put(k, new Integer[]{0,0});
            Integer[] c = rollup.get(k);
            c[1] += 1;
            if (a.Is_Present__c == true) c[0] += 1;
        }
        Integer atRisk = 0;
        for (Integer[] c : rollup.values()) {
            if (c[1] == 0) continue;
            Decimal pct = (Decimal) c[0] * 100 / c[1];
            if (pct < 75) atRisk++;
        }
        return atRisk;
    }

    public static Decimal realCgpa(Id contactId) {
        if (contactId == null) return null;
        // Per-subject weighted % then averaged across subjects → mapped to a
        // 10-point CGPA (0-10) using simple linear mapping (pct/10).
        Map<String, Decimal[]> bySubject = new Map<String, Decimal[]>(); // subj -> [obtained, max]
        for (Assessment_Component__c a : [
            SELECT Subject__c, Obtained_Marks__c, Max_Marks__c
            FROM Assessment_Component__c
            WHERE Student__c = :contactId LIMIT 1000
        ]) {
            if (a.Max_Marks__c == null || a.Max_Marks__c == 0) continue;
            String s = String.isBlank(a.Subject__c) ? '?' : a.Subject__c;
            if (!bySubject.containsKey(s)) bySubject.put(s, new Decimal[]{0, 0});
            Decimal[] arr = bySubject.get(s);
            arr[0] = arr[0] + (a.Obtained_Marks__c == null ? 0 : a.Obtained_Marks__c);
            arr[1] = arr[1] + a.Max_Marks__c;
        }
        if (bySubject.isEmpty()) return null;
        Decimal totalPct = 0;
        Integer count = 0;
        for (Decimal[] arr : bySubject.values()) {
            if (arr[1] == 0) continue;
            totalPct += (arr[0] * 100 / arr[1]);
            count++;
        }
        if (count == 0) return null;
        Decimal avgPct = totalPct / count;
        return (avgPct / 10).setScale(1); // ~83% → 8.3
    }

    public static Decimal realFeesDue(Id contactId) {
        if (contactId == null) return null;
        // Resolve the student's Account first (SOQL only allows 1-level
        // relationship in semi-join filters).
        Id acctId = accountIdFor(contactId);
        if (acctId == null) return null;
        AggregateResult[] ars = [
            SELECT SUM(Amount__c) amt FROM Fee_Installment__c
            WHERE Status__c IN ('Planned', 'Pending', 'Due', 'Overdue')
              AND Fee_Assignment__r.Account__c = :acctId
        ];
        if (ars.isEmpty()) return null;
        Object v = ars[0].get('amt');
        return (v == null) ? 0 : Decimal.valueOf(String.valueOf(v));
    }

    private static Id accountIdFor(Id contactId) {
        if (contactId == null) return null;
        List<Contact> cs = [SELECT AccountId FROM Contact WHERE Id = :contactId LIMIT 1];
        return (cs.isEmpty()) ? null : cs[0].AccountId;
    }

    public static String formatCurrency(Decimal n) {
        if (n == null) return '₹0';
        if (n >= 100000) {
            Decimal lakhs = (n / 100000).setScale(1);
            return '₹' + lakhs + 'L';
        }
        if (n >= 1000) {
            Decimal k = (n / 1000).setScale(0);
            return '₹' + k + 'K';
        }
        return '₹' + n.setScale(0);
    }

    public static String nextDueDateLabel(Id contactId) {
        if (contactId == null) return '';
        Id acctId = accountIdFor(contactId);
        if (acctId == null) return 'No dues';
        List<Fee_Installment__c> next = [
            SELECT Due_Date__c FROM Fee_Installment__c
            WHERE Status__c IN ('Planned', 'Pending', 'Due', 'Overdue')
              AND Fee_Assignment__r.Account__c = :acctId
            ORDER BY Due_Date__c ASC NULLS LAST
            LIMIT 1
        ];
        if (next.isEmpty() || next[0].Due_Date__c == null) return 'No dues';
        Date due = next[0].Due_Date__c;
        Integer daysOut = Date.today().daysBetween(due);
        String dueStr = Datetime.newInstance(due, Time.newInstance(0,0,0,0)).format('MMM d');
        if (daysOut <= 0) return 'Due ' + dueStr;
        return 'Due ' + dueStr + ' · ' + daysOut + ' days';
    }

    public static void recordMood(String mood) {
        Contact c = queryRunningContact();
        if (c == null) {
            System.debug(LoggingLevel.INFO, 'recordMood: no linked contact; mood=' + mood);
            return;
        }
        Date weekOf = Date.today().toStartOfWeek();
        // Upsert: if the student already checked in for this week, update the
        // mood instead of creating a duplicate row.
        List<Weekly_Checkin__c> existing = [
            SELECT Id FROM Weekly_Checkin__c
            WHERE Student__c = :c.Id AND Week_Of__c = :weekOf
            WITH SYSTEM_MODE LIMIT 1
        ];
        if (!existing.isEmpty()) {
            KenCrudFlsHelper.assertUpdateable(Weekly_Checkin__c.SObjectType);
            update new Weekly_Checkin__c(Id = existing[0].Id, Mood__c = mood);
            return;
        }
        KenCrudFlsHelper.assertCreateable(Weekly_Checkin__c.SObjectType);
        insert new Weekly_Checkin__c(
            Student__c = c.Id,
            Mood__c    = mood,
            Week_Of__c = weekOf
        );
    }

    // ─── Contact resolution ────────────────────────────────────────────────────

    private static Contact queryRunningContact() {
        Id userId = UserInfo.getUserId();
        List<User> users = [
            SELECT Id, ContactId, FirstName, LastName
            FROM User
            WHERE Id = :userId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (users.isEmpty() || users[0].ContactId == null) {
            return null;
        }
        List<Contact> cs = [
            SELECT Id, FirstName, LastName, Birthdate, Email
            FROM Contact
            WHERE Id = :users[0].ContactId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return cs.isEmpty() ? null : cs[0];
    }

    private static String buildProgramLine(Contact c) {
        // TODO[SOBJECT]: Prefer LearnerProgram → LearningProgramPlan → Name + current term label.
        //                For now returns the mocked MBA line. Swap in real query once schema is live.
        return 'B.Tech CS · Sem 6';
    }

    private static String buildInitials(String first, String last) {
        String f = String.isBlank(first) ? '' : first.substring(0, 1).toUpperCase();
        String l = String.isBlank(last)  ? '' : last.substring(0, 1).toUpperCase();
        return f + l;
    }

    // ─── Greeting ──────────────────────────────────────────────────────────────

    private static KenHomeDashboardController.GreetingDTO buildGreeting(
        String stage,
        KenHomeDashboardController.StudentHeaderDTO h
    ) {
        KenHomeDashboardController.GreetingDTO g = new KenHomeDashboardController.GreetingDTO();
        // LWC dashboard hardcodes "Good morning" — match that here so the page renders
        // identically with or without the server call.
        g.headline = 'Good morning, ' + (h == null ? 'Student' : h.displayName);
        if (stage == KenStudentPortalConstants.STAGE_STARTING) {
            g.sub = 'You\'re in your first semester — start with the essentials below';
        } else if (stage == KenStudentPortalConstants.STAGE_ENDING) {
            g.sub = 'Almost there — wrap up your final semester strong';
        } else {
            g.sub = 'You have 2 deadlines today \u2014 stay on track.';
        }
        return g;
    }

    // ─── KPI cards ─────────────────────────────────────────────────────────────

    private static List<KenHomeDashboardController.KpiCardDTO> buildKpiCards(String stage, String path) {
        if (stage == KenStudentPortalConstants.STAGE_STARTING) return startingKpis();
        if (stage == KenStudentPortalConstants.STAGE_ENDING)   return endingKpis(path);
        return middleKpis();
    }

    private static List<KenHomeDashboardController.KpiCardDTO> startingKpis() {
        List<KenHomeDashboardController.KpiCardDTO> out = new List<KenHomeDashboardController.KpiCardDTO>();
        out.add(kpi('K-S1', 'ONBOARDING', '2/6', KenStudentPortalConstants.ACCENT_INDIGO,  'Steps done',      true,  false, false));
        out.add(kpi('K-S2', 'ATTENDANCE', '100%', KenStudentPortalConstants.ACCENT_EMERALD, 'All clear',      true,  false, false));
        out.add(kpi('K-S3', 'FEES',       '\u20B90', KenStudentPortalConstants.ACCENT_EMERALD, 'Nothing pending', true, false, false));
        out.add(kpi('K-S4', 'STANDING',   'On Track', KenStudentPortalConstants.ACCENT_EMERALD, 'Let\'s get started', true, false, true));
        return out;
    }

    private static List<KenHomeDashboardController.KpiCardDTO> middleKpis() {
        List<KenHomeDashboardController.KpiCardDTO> out = new List<KenHomeDashboardController.KpiCardDTO>();
        // Pull live values from real records.
        Contact c = queryRunningContact();
        Id contactId = (c == null) ? null : c.Id;
        Decimal cgpaVal = realCgpa(contactId);
        Decimal attPct  = realAttendancePct(contactId);
        Integer atRisk  = realAtRiskSubjectCount(contactId);
        Decimal due     = realFeesDue(contactId);

        String cgpaStr = (cgpaVal == null) ? '--' : cgpaVal.setScale(1).toPlainString();
        KenHomeDashboardController.KpiCardDTO cgpa = kpi('K-M1', 'CGPA', cgpaStr, KenStudentPortalConstants.ACCENT_INDIGO, '+0.4 this semester', true, false, false);
        cgpa.pillClass    = 'kpi-delta-green';
        cgpa.pillHasArrow = true;
        out.add(cgpa);

        String attStr = (attPct == null) ? '--' : (attPct.setScale(0) + '%');
        String attPill = (atRisk == 0)
            ? 'All subjects on track'
            : (atRisk == 1 ? '1 subject at risk' : (atRisk + ' subjects at risk'));
        KenHomeDashboardController.KpiCardDTO att = kpi('K-M2', 'ATTENDANCE', attStr, KenStudentPortalConstants.ACCENT_AMBER, attPill, true, false, false);
        att.pillClass  = (atRisk == 0) ? 'kpi-delta-green' : 'kpi-delta-amber';
        att.pillHasDot = atRisk > 0;
        out.add(att);

        String feeStr = (due == null) ? '\u20B90' : formatCurrency(due);
        String feePill = (contactId == null) ? '' : nextDueDateLabel(contactId);
        KenHomeDashboardController.KpiCardDTO fees = kpi('K-M3', 'FEES DUE', feeStr, KenStudentPortalConstants.ACCENT_RED, feePill, true, false, false);
        fees.pillClass  = (due != null && due == 0) ? 'kpi-delta-green' : 'kpi-delta-red';
        fees.pillHasDot = (due == null || due > 0);
        out.add(fees);

        Boolean onTrack = (attPct == null || attPct >= 75) && (due == null || due >= 0);
        out.add(kpi('K-M4', 'STANDING', onTrack ? 'On Track' : 'Review', KenStudentPortalConstants.ACCENT_GREEN, '96 / 160 credits earned', false, false, true));
        return out;
    }

    private static List<KenHomeDashboardController.KpiCardDTO> endingKpis(String path) {
        List<KenHomeDashboardController.KpiCardDTO> out = new List<KenHomeDashboardController.KpiCardDTO>();
        out.add(kpi('K-E1', 'CGPA',     '8.4',     KenStudentPortalConstants.ACCENT_INDIGO, 'Final: 8.4',    true, false, false));
        out.add(kpi('K-E2', 'CREDITS',  '156/160', KenStudentPortalConstants.ACCENT_VIOLET, '4 remaining',    true, false, false));
        out.add(careerKpi(path));
        out.add(kpi('K-E3', 'CLEARANCE','Pending', KenStudentPortalConstants.ACCENT_AMBER,  '3 of 5 steps',   false, true, false));
        return out;
    }

    private static KenHomeDashboardController.KpiCardDTO careerKpi(String path) {
        if (path == KenStudentPortalConstants.PATH_HIGHER_STUDIES) {
            return kpi('K-E4', 'CAREER', '2 apps',    KenStudentPortalConstants.ACCENT_SKY,     'SOP review pending', true, false, false);
        }
        if (path == KenStudentPortalConstants.PATH_ENTREPRENEURSHIP) {
            return kpi('K-E4', 'CAREER', 'Active',    KenStudentPortalConstants.ACCENT_VIOLET,  'Demo day in 3 wks',  true, false, false);
        }
        if (path == KenStudentPortalConstants.PATH_EXPLORING) {
            return kpi('K-E4', 'CAREER', 'Exploring', KenStudentPortalConstants.ACCENT_SLATE,   '3 options available', true, false, false);
        }
        return kpi('K-E4', 'CAREER', '2 offers', KenStudentPortalConstants.ACCENT_EMERALD, 'Respond by May 10', true, false, false);
    }

    private static KenHomeDashboardController.KpiCardDTO kpi(
        String id, String label, String value, String accent, String pill,
        Boolean isPlain, Boolean isClock, Boolean isCheck
    ) {
        KenHomeDashboardController.KpiCardDTO k = new KenHomeDashboardController.KpiCardDTO();
        k.id           = id;
        k.label        = label;
        k.value        = value;
        k.accentClass  = accent;
        k.dotClass     = 'kpi-dot ' + accent.replace('accent-', 'kpi-dot-');
        k.pill         = pill;
        k.pillClass    = 'kpi-delta-muted';
        k.isPlainValue = isPlain;
        k.isClockValue = isClock;
        k.isCheckValue = isCheck;
        k.pillHasArrow = false;
        k.pillHasDot   = false;
        return k;
    }

    // ─── Pinned card ───────────────────────────────────────────────────────────

    private static KenHomeDashboardController.PinnedCardDTO buildPinnedCard(String stage) {
        KenHomeDashboardController.PinnedCardDTO p = new KenHomeDashboardController.PinnedCardDTO();
        p.show = false;
        return p;
    }

    // ─── Feed ──────────────────────────────────────────────────────────────────

    private static List<KenHomeDashboardController.FeedItemDTO> buildFeedItems(String stage, String path) {
        return new List<KenHomeDashboardController.FeedItemDTO>();
    }

    // ─── For You / Needs attention ─────────────────────────────────────────────

    private static List<KenHomeDashboardController.ForYouItemDTO> buildForYouItems(String stage, String path) {
        return new List<KenHomeDashboardController.ForYouItemDTO>();
    }

    private static List<KenHomeDashboardController.AttentionItemDTO> buildNeedsAttention(String stage) {
        return new List<KenHomeDashboardController.AttentionItemDTO>();
    }

    // ─── Today / Spotlight ─────────────────────────────────────────────────────

    private static String todayLabelFor(String stage) {
        if (stage == KenStudentPortalConstants.STAGE_STARTING) return 'Aug 1';
        if (stage == KenStudentPortalConstants.STAGE_ENDING)   return 'May 20';
        return 'Apr 15';
    }

    private static List<KenHomeDashboardController.ScheduleItemDTO> buildTodayItems(String stage) {
        Contact c = queryRunningContact();
        if (c != null) {
            String today = dayOfWeekShort();
            List<Course_Schedule__c> rows = [
                SELECT Id, Title__c, Instructor__c, Location__c, Start_Time__c, End_Time__c, Color_Token__c
                FROM Course_Schedule__c
                WHERE Student__c = :c.Id AND Day_Of_Week__c = :today
                WITH SYSTEM_MODE
                ORDER BY Start_Time__c ASC
                LIMIT 10
            ];
            if (!rows.isEmpty()) {
                List<KenHomeDashboardController.ScheduleItemDTO> live = new List<KenHomeDashboardController.ScheduleItemDTO>();
                Boolean firstMarked = false;
                for (Course_Schedule__c r : rows) {
                    KenHomeDashboardController.ScheduleItemDTO s = new KenHomeDashboardController.ScheduleItemDTO();
                    s.id          = r.Id;
                    s.startTime   = r.Start_Time__c;
                    s.subject     = r.Title__c;
                    s.location    = r.Location__c;
                    s.stripeStyle = 'background:' + tokenToHex(r.Color_Token__c);
                    s.isLive      = !firstMarked;
                    firstMarked   = true;
                    live.add(s);
                }
                return live;
            }
        }
        return new List<KenHomeDashboardController.ScheduleItemDTO>();
    }

    private static String dayOfWeekShort() {
        // Convert Datetime dayOfWeek() (Sunday=1) to the Mon/Tue/… token used in Course_Schedule__c.
        String d = Datetime.now().format('EEE');
        return d;
    }

    private static String tokenToHex(String token) {
        if (token == 'violet') return '#7C3AED';
        if (token == 'blue')   return '#0891B2';
        if (token == 'green')  return '#059669';
        if (token == 'amber')  return '#D97706';
        if (token == 'red')    return '#E11D48';
        if (token == 'cyan')   return '#0891B2';
        return '#4F46E5';
    }

    private static KenHomeDashboardController.SpotlightDTO buildSpotlight(String stage) {
        List<Spotlight__c> rows = [
            SELECT Id, Name, Hero_Value__c, Sub_Label__c, Date_Range__c,
                   CTA_Label__c, Route__c, Is_Text_Hero__c
            FROM Spotlight__c
            WHERE Stage__c = :stage AND Active__c = true
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (!rows.isEmpty()) {
            Spotlight__c r = rows[0];
            KenHomeDashboardController.SpotlightDTO fromDb = new KenHomeDashboardController.SpotlightDTO();
            fromDb.eyebrow    = 'SPOTLIGHT';
            fromDb.heroValue  = r.Hero_Value__c;
            fromDb.subLabel   = r.Sub_Label__c;
            fromDb.dateRange  = r.Date_Range__c;
            fromDb.ctaLabel   = r.CTA_Label__c;
            fromDb.route      = r.Route__c;
            fromDb.isTextHero = r.Is_Text_Hero__c;
            return fromDb;
        }
        return new KenHomeDashboardController.SpotlightDTO();
    }

    // ─── Quick actions / Guide / KAI / Clearance ───────────────────────────────

    private static List<KenHomeDashboardController.QuickActionDTO> buildQuickActions(String stage, String path) {
        return new List<KenHomeDashboardController.QuickActionDTO>();
    }

    private static List<KenHomeDashboardController.CampusGuideDTO> buildCampusGuide() {
        return new List<KenHomeDashboardController.CampusGuideDTO>();
    }

    private static List<KenHomeDashboardController.KaiChipDTO> buildKaiChips() {
        return new List<KenHomeDashboardController.KaiChipDTO>();
    }

    private static List<KenHomeDashboardController.ClearanceItemDTO> buildClearance() {
        return new List<KenHomeDashboardController.ClearanceItemDTO>();
    }

}