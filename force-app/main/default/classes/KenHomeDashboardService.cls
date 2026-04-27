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
        h.streakLine     = '12-day streak · 82% attendance'; // TODO[SOBJECT]: derive from Attendance__c + Login_Streak__c aggregates
        h.avatarInitials = buildInitials(c.FirstName, c.LastName);
        return h;
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
            WITH USER_MODE LIMIT 1
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
            WITH USER_MODE
            LIMIT 1
        ];
        if (users.isEmpty() || users[0].ContactId == null) {
            return null;
        }
        List<Contact> cs = [
            SELECT Id, FirstName, LastName, Birthdate, Email
            FROM Contact
            WHERE Id = :users[0].ContactId
            WITH USER_MODE
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
        // TODO[SOBJECT]: CGPA from Grade__c aggregate; Attendance from Attendance__c;
        //                Fees from Fee_Installment__c; Credits from Enrollment__c sum.
        KenHomeDashboardController.KpiCardDTO cgpa = kpi('K-M1', 'CGPA', '8.2', KenStudentPortalConstants.ACCENT_INDIGO, '+0.4 this semester', true, false, false);
        cgpa.pillClass    = 'kpi-delta-green';
        cgpa.pillHasArrow = true;
        out.add(cgpa);

        KenHomeDashboardController.KpiCardDTO att = kpi('K-M2', 'ATTENDANCE', '82%', KenStudentPortalConstants.ACCENT_AMBER, '1 subject at risk', true, false, false);
        att.pillClass  = 'kpi-delta-amber';
        att.pillHasDot = true;
        out.add(att);

        KenHomeDashboardController.KpiCardDTO fees = kpi('K-M3', 'FEES DUE', '\u20B924K', KenStudentPortalConstants.ACCENT_RED, 'Due Apr 30 \u00B7 15 days', true, false, false);
        fees.pillClass  = 'kpi-delta-red';
        fees.pillHasDot = true;
        out.add(fees);

        out.add(kpi('K-M4', 'STANDING', 'On Track', KenStudentPortalConstants.ACCENT_GREEN, '96 / 160 credits earned', false, false, true));
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
        if (stage == KenStudentPortalConstants.STAGE_STARTING) {
            p.show = false;
            return p;
        }
        p.show = true;
        if (stage == KenStudentPortalConstants.STAGE_ENDING) {
            p.eyebrow     = 'PINNED · Jun 15';
            p.title       = 'Convocation 2026 — You\'re graduating!';
            p.description = 'Confirm attendance & gown size by Jun 1. Invite family.';
            p.ctaLabel    = 'RSVP now \u2192';
            p.route       = 'events';
        } else {
            p.eyebrow     = 'PINNED · Apr 25–27';
            p.title       = 'Annual Tech Fest — Kenzaa 2026';
            p.description = 'Registrations open. 15+ competitive events, workshops, and keynotes.';
            p.ctaLabel    = 'Register now \u2192';
            p.route       = 'events';
        }
        return p;
    }

    // ─── Feed ──────────────────────────────────────────────────────────────────

    private static List<KenHomeDashboardController.FeedItemDTO> buildFeedItems(String stage, String path) {
        List<Activity_Feed__c> rows = [
            SELECT Id, Name, Description__c, Tag__c, Tag_Class__c,
                   Effective_Date__c, Is_Social__c, Social_Text__c, Sort_Order__c
            FROM Activity_Feed__c
            WHERE Stage__c = :stage
              AND (Career_Path__c = :path OR Career_Path__c = NULL)
            WITH USER_MODE
            ORDER BY Sort_Order__c ASC NULLS LAST, Effective_Date__c DESC
            LIMIT 20
        ];
        if (rows.isEmpty()) {
            // Fallback to seeded content until admins populate Activity_Feed__c.
            if (stage == KenStudentPortalConstants.STAGE_STARTING) return seedStartingFeed();
            if (stage == KenStudentPortalConstants.STAGE_ENDING)   return seedEndingFeed(path);
            return seedMiddleFeed();
        }
        List<KenHomeDashboardController.FeedItemDTO> out = new List<KenHomeDashboardController.FeedItemDTO>();
        for (Activity_Feed__c r : rows) {
            KenHomeDashboardController.FeedItemDTO f = new KenHomeDashboardController.FeedItemDTO();
            f.id          = r.Id;
            f.tag         = r.Tag__c;
            f.tagClass    = r.Tag_Class__c;
            f.title       = r.Name;
            f.description = r.Description__c;
            f.isSocial    = r.Is_Social__c;
            f.socialText  = r.Social_Text__c;
            if (r.Effective_Date__c != null) {
                Datetime dt = Datetime.newInstance(r.Effective_Date__c, Time.newInstance(0,0,0,0));
                f.dateMonth = dt.format('MMM').toUpperCase();
                f.dateDay   = String.valueOf(r.Effective_Date__c.day());
            }
            out.add(f);
        }
        return out;
    }

    private static List<KenHomeDashboardController.FeedItemDTO> seedStartingFeed() {
        List<KenHomeDashboardController.FeedItemDTO> out = new List<KenHomeDashboardController.FeedItemDTO>();
        out.add(feed('FD-S1', 'INTRO',   'tag-event', 'AUG', '1',  'Orientation day schedule released',
                                 'Main auditorium, 9 AM. Bring your admission letter.'));
        out.add(feed('FD-S2', 'WELCOME', 'tag-acad',  'AUG', '1',  'Welcome aboard — Class of 2030!',
                                 'A message from the Vice Chancellor.'));
        out.add(feed('FD-S3', 'EVENT',   'tag-event', 'JUL', '30', 'Freshers Night — Aug 8 at the Open Amphitheatre',
                                 'Music, dance, and meet your batchmates. Free entry.'));
        out.add(feed('FD-S4', 'CLUB',    'tag-club',  'JUL', '29', 'Club fair — explore 30+ student clubs',
                                 'Aug 5, 10 AM – 4 PM, Central Lawn. Sign up on the spot.'));
        out.add(feed('FD-S5', 'LIBRARY', 'tag-reg',   'JUL', '28', 'Library access cards available for pickup',
                                 'Collect from the library front desk with your student ID.'));
        out.add(feed('FD-S6', 'IT',      'tag-alert', 'JUL', '28', 'Set up campus Wi-Fi & student email',
                                 'Follow the IT guide in your portal or visit the helpdesk.'));
        out.add(feed('FD-S7', 'ACAD',    'tag-acad',  'JUL', '27', 'First semester syllabus available',
                                 'Download course outlines from the Academics section.'));
        out.add(feed('FD-S8', 'SUPPORT', 'tag-cert',  'JUL', '27', 'New student helpline is live',
                                 'Call or chat for any setup, hostel, or academic queries.'));
        return out;
    }

    private static List<KenHomeDashboardController.FeedItemDTO> seedMiddleFeed() {
        List<KenHomeDashboardController.FeedItemDTO> out = new List<KenHomeDashboardController.FeedItemDTO>();
        out.add(feed('FD-M1', 'EXAM',  'tag-exam',  'APR', '14', 'Mid-semester exams: Apr 28 – May 5',
                                 'Timetable and seating published on exam portal.'));
        out.add(feed('FD-M2', 'REG',   'tag-reg',   'APR', '15', 'Elective registration for Sem 6 opens Apr 18',
                                 'Portal active at 9 AM. Plan your course trajectory.'));
        out.add(feed('FD-M3', 'CLUB',  'tag-club',  'APR', '14', 'Coding Club Hackathon — 48hr build challenge',
                                 'Theme: AI for Sustainability. Teams of up to 4.'));
        out.add(feed('FD-M4', 'EVENT', 'tag-event', 'APR', '12', 'Guest Lecture: AI in Healthcare — Apr 19',
                                 'Dr. Priya Sharma, Main Auditorium, 3 PM.'));
        out.add(feed('FD-M5', 'CLUB',  'tag-club',  'APR', '11', 'Design Sprint by UI/UX Society — Apr 20',
                                 'Open to all departments. Register before Apr 18.'));
        out.add(feed('FD-M6', 'ACAD',  'tag-acad',  'APR', '10', 'Semester 5 grade cards now available',
                                 'Download from the academics portal under Results.'));
        out.add(feed('FD-M7', 'ALERT', 'tag-alert', 'APR', '9',  'Campus placement drive: TCS, Infosys — May 3',
                                 'Register by Apr 25 via Placements portal.'));
        return out;
    }

    private static List<KenHomeDashboardController.FeedItemDTO> seedEndingFeed(String path) {
        List<KenHomeDashboardController.FeedItemDTO> out = new List<KenHomeDashboardController.FeedItemDTO>();
        out.add(feed('FD-E1', 'CLEAR', 'tag-cert',  'MAY', '20', 'No-dues clearance deadline: Jun 5',
                                 'Visit library, hostel, and lab to collect signatures.'));
        if (path == KenStudentPortalConstants.PATH_HIGHER_STUDIES) {
            out.add(feed('FD-E2', 'ADMIS',  'tag-reg',  'MAY', '18', 'University application deadlines approaching',
                                     '3 shortlisted programs close by Jun 1.'));
            out.add(feed('FD-E3', 'PREP',   'tag-event', 'MAY', '14', 'SOP writing workshop — May 22',
                                     'Get 1-on-1 feedback from the career services team.'));
        } else if (path == KenStudentPortalConstants.PATH_ENTREPRENEURSHIP) {
            out.add(feed('FD-E2', 'STARTUP','tag-club',  'MAY', '18', 'Incubator applications open — batch 2026',
                                     'Apply by Jun 5. Mentorship + seed funding.'));
            out.add(feed('FD-E3', 'EVENT',  'tag-event', 'MAY', '14', 'Startup showcase & demo day — Jun 1',
                                     'Present your idea to investors and alumni founders.'));
        } else {
            out.add(feed('FD-E2', 'PLACE',  'tag-offer', 'MAY', '18', 'Final placement report published',
                                     '92% placement rate. Check your offer status.'));
            out.add(feed('FD-E3', 'CAREER', 'tag-reg',   'MAY', '14', 'Recruiter connect: mock interviews open',
                                     'Book a 1-on-1 mock with industry panelists.'));
        }
        out.add(feed('FD-E4', 'ACAD',   'tag-acad',  'MAY', '15', 'Final semester results declared',
                                 'Download grade card from Results section.'));
        out.add(feed('FD-E5', 'ALUMNI', 'tag-event', 'MAY', '12', 'Join the Ken University alumni network',
                                 'Stay connected. Activate your alumni profile.'));
        out.add(feed('FD-E6', 'EVENT',  'tag-event', 'MAY', '10', 'Farewell ceremony — May 25',
                                 'Main Auditorium, 5 PM. Dress code: formal.'));
        out.add(feed('FD-E7', 'CERT',   'tag-cert',  'MAY', '8',  'Transcript & certificate available after clearance',
                                 'Complete all no-dues steps to unlock downloads.'));
        return out;
    }

    private static KenHomeDashboardController.FeedItemDTO feed(String id, String tag, String tagClass,
                                                                String month, String day, String title, String descText) {
        KenHomeDashboardController.FeedItemDTO f = new KenHomeDashboardController.FeedItemDTO();
        f.id          = id;
        f.tag         = tag;
        f.tagClass    = tagClass;
        f.dateMonth   = month;
        f.dateDay     = day;
        f.title       = title;
        f.description = descText;
        f.isSocial    = false;
        return f;
    }

    // ─── For You / Needs attention ─────────────────────────────────────────────

    private static List<KenHomeDashboardController.ForYouItemDTO> buildForYouItems(String stage, String path) {
        // TODO[SOBJECT]: Personalisation from Recommendation__c (future).
        List<KenHomeDashboardController.ForYouItemDTO> out = new List<KenHomeDashboardController.ForYouItemDTO>();
        if (stage == KenStudentPortalConstants.STAGE_STARTING) {
            out.add(forYou('FY-S1', '\uD83D\uDCC5', 'tile-indigo',  'View your timetable',            'See your classes, rooms & timings', 'schedule'));
            out.add(forYou('FY-S2', '\uD83C\uDFAC', 'tile-violet',  'Watch welcome video',            '2-min portal walkthrough',           null));
            out.add(forYou('FY-S3', '\uD83C\uDFDB', 'tile-amber',   'Find your department office',    'Floor 3, Block B — Prof. Sharma',     null));
            out.add(forYou('FY-S4', '\uD83D\uDC69\u200D\uD83C\uDFEB', 'tile-emerald', 'Meet your faculty advisor', 'Book a slot for your intro meeting', null));
            out.add(forYou('FY-S5', '\uD83C\uDFAD', 'tile-red',     'Explore clubs & communities',    '30+ clubs open for sign-ups',        'clubs'));
            return out;
        }
        if (stage == KenStudentPortalConstants.STAGE_MIDDLE) {
            out.add(forYou('FY-M1', '\uD83C\uDFC6', 'tile-violet',  'Join hackathon team',        'CS dept · 12 batchmates already in', 'events'));
            out.add(forYou('FY-M2', '\uD83C\uDFA4', 'tile-amber',   'Guest Lecture: AI in Healthcare', 'Apr 19, 3 PM · Main Auditorium', 'events'));
            out.add(forYou('FY-M3', '\uD83D\uDCBC', 'tile-emerald', 'Explore summer internships', '8 new openings match your profile', null));
            out.add(forYou('FY-M4', '\uD83D\uDCDA', 'tile-blue',    'Try the new AI study planner', 'Personalized schedule for mid-sems', null));
            return out;
        }
        // ending — shared top
        out.add(forYou('FY-E1', '\uD83C\uDF93', 'tile-indigo',  'RSVP for convocation',         'Confirm attendance & gown size',       null));
        out.add(forYou('FY-E2', '\uD83D\uDCDC', 'tile-amber',   'Download degree certificate',  'Available after clearance complete',   null));
        out.add(forYou('FY-E3', '\uD83E\uDD1D', 'tile-emerald', 'Activate alumni profile',      'Stay connected with batchmates',       null));
        return out;
    }

    private static KenHomeDashboardController.ForYouItemDTO forYou(String id, String icon, String tile, String title, String meta, String route) {
        KenHomeDashboardController.ForYouItemDTO f = new KenHomeDashboardController.ForYouItemDTO();
        f.id = id; f.icon = icon; f.tileClass = tile; f.title = title; f.meta = meta; f.route = route;
        return f;
    }

    private static List<KenHomeDashboardController.AttentionItemDTO> buildNeedsAttention(String stage) {
        List<KenHomeDashboardController.AttentionItemDTO> out = new List<KenHomeDashboardController.AttentionItemDTO>();
        if (stage == KenStudentPortalConstants.STAGE_STARTING) {
            out.add(attn('AT-S1', 'Hostel room allocation pending', 'Complete by Aug 5 to confirm', 'dot-amber'));
            out.add(attn('AT-S2', 'Collect ID card',                'Available at admin office, Block A', 'dot-blue'));
            out.add(attn('AT-S3', 'Set up meal plan',               'Choose your plan before Aug 10', 'dot-amber'));
            return out;
        }
        if (stage == KenStudentPortalConstants.STAGE_ENDING) {
            return out;
        }
        out.add(attn('AT-M1', 'DS assignment due today',      'Submit by 11:59 PM', 'dot-red'));
        out.add(attn('AT-M2', 'Math attendance at 68%',       'Below 75% — meet advisor', 'dot-amber'));
        out.add(attn('AT-M3', 'Fee installment \u20B924,000', 'Due Apr 30 · 15 days left', 'dot-blue'));
        out.add(attn('AT-M4', 'Check exam eligibility',       'Mid-sems start in 13 days', 'dot-amber'));
        out.add(attn('AT-M5', 'Elective registration Apr 18', 'Shortlist courses before deadline', 'dot-orange'));
        return out;
    }

    private static KenHomeDashboardController.AttentionItemDTO attn(String id, String title, String meta, String dot) {
        KenHomeDashboardController.AttentionItemDTO a = new KenHomeDashboardController.AttentionItemDTO();
        a.id = id; a.title = title; a.meta = meta; a.dotClass = dot;
        return a;
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
                WITH USER_MODE
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
        // Fallback to seeded schedule until admins populate Course_Schedule__c.
        List<KenHomeDashboardController.ScheduleItemDTO> out = new List<KenHomeDashboardController.ScheduleItemDTO>();
        if (stage == KenStudentPortalConstants.STAGE_STARTING) {
            out.add(sched('SC-S1', '9:00 AM',  'Orientation \u2014 Welcome Address', 'Main Auditorium',   'background:#4F46E5', true));
            out.add(sched('SC-S2', '10:30 AM', 'Campus Tour',                         'Meet at Gate 1',    'background:#059669', false));
            out.add(sched('SC-S3', '1:00 PM',  'Department Introduction',             'Block B, Room 301', 'background:#7C3AED', false));
            out.add(sched('SC-S4', '3:00 PM',  'Student Services Walkthrough',        'Admin Building',    'background:#D97706', false));
        } else if (stage == KenStudentPortalConstants.STAGE_ENDING) {
            out.add(sched('SC-E1', '10:00 AM', 'Project Viva \u2014 Final Review', 'Room 405',        'background:#E11D48', true));
            out.add(sched('SC-E2', '1:00 PM',  'Clearance: Library',                'Central Library', 'background:#D97706', false));
            out.add(sched('SC-E3', '3:00 PM',  'Alumni Registration Drive',         'Seminar Hall',    'background:#4F46E5', false));
        } else {
            out.add(sched('SC-M1', '9:00 AM',  'Data Structures',      'Room 304',    'background:#7C3AED', true));
            out.add(sched('SC-M2', '10:00 AM', 'Operating Systems Lab', 'Lab 2',       'background:#0891B2', false));
            out.add(sched('SC-M3', '11:30 AM', 'Mathematics III',       'Room 201',    'background:#059669', false));
            out.add(sched('SC-M4', '2:00 PM',  'Soft Skills Workshop',  'Auditorium',  'background:#D97706', false));
        }
        return out;
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

    private static KenHomeDashboardController.ScheduleItemDTO sched(String id, String timeStr, String subj, String loc, String style, Boolean live) {
        KenHomeDashboardController.ScheduleItemDTO s = new KenHomeDashboardController.ScheduleItemDTO();
        s.id = id; s.startTime = timeStr; s.subject = subj; s.location = loc; s.stripeStyle = style; s.isLive = live;
        return s;
    }

    private static KenHomeDashboardController.SpotlightDTO buildSpotlight(String stage) {
        List<Spotlight__c> rows = [
            SELECT Id, Name, Hero_Value__c, Sub_Label__c, Date_Range__c,
                   CTA_Label__c, Route__c, Is_Text_Hero__c
            FROM Spotlight__c
            WHERE Stage__c = :stage AND Active__c = true
            WITH USER_MODE
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
        KenHomeDashboardController.SpotlightDTO sp = new KenHomeDashboardController.SpotlightDTO();
        sp.eyebrow = 'SPOTLIGHT';
        if (stage == KenStudentPortalConstants.STAGE_STARTING) {
            sp.isTextHero = true;
            sp.heroValue  = 'First semester';
            sp.subLabel   = 'Orientation week + classes begin';
            sp.dateRange  = 'Aug 1 \u2014 Dec 15';
            sp.ctaLabel   = 'View schedule \u2192';
            sp.route      = 'schedule';
        } else if (stage == KenStudentPortalConstants.STAGE_ENDING) {
            sp.isTextHero = false;
            sp.heroValue  = '26';
            sp.subLabel   = 'days to convocation';
            sp.dateRange  = 'Jun 15, 2026';
            sp.ctaLabel   = 'RSVP & details \u2192';
            sp.route      = '';
        } else {
            sp.isTextHero = false;
            sp.heroValue  = '13';
            sp.subLabel   = 'days to mid-semester exams';
            sp.dateRange  = 'Apr 28 \u2014 May 5';
            sp.ctaLabel   = 'View timetable \u2192';
            sp.route      = 'my-exams';
        }
        return sp;
    }

    // ─── Quick actions / Guide / KAI / Clearance ───────────────────────────────

    private static List<KenHomeDashboardController.QuickActionDTO> buildQuickActions(String stage, String path) {
        List<KenHomeDashboardController.QuickActionDTO> out = new List<KenHomeDashboardController.QuickActionDTO>();
        if (stage == KenStudentPortalConstants.STAGE_STARTING) {
            out.add(qa('QA-S1', '\uD83D\uDCCB', 'Orientation schedule', 'schedule', null));
            out.add(qa('QA-S2', '\uD83E\uDE6A', 'Download temp ID',     null, 'Temporary ID downloaded'));
            out.add(qa('QA-S3', '\uD83C\uDD98', 'Student services',     'service-support', null));
            out.add(qa('QA-S4', '\uD83D\uDCF6', 'IT helpdesk',          'service-support', null));
            return out;
        }
        if (stage == KenStudentPortalConstants.STAGE_ENDING) {
            out.add(qa('QA-E1', '\uD83D\uDCDC', 'Request transcript', null, 'Transcript request sent'));
            out.add(qa('QA-E2', '\uD83C\uDF93', 'Convocation RSVP',   null, 'RSVP confirmed'));
            out.add(qa('QA-E3', '\uD83D\uDCBC', 'View offers',        null, 'Opening offers'));
            out.add(qa('QA-E4', '\u2705',       'Accept offer',       null, 'Offer acceptance flow'));
            return out;
        }
        out.add(qa('QA-M1', '\u26A0\uFE0F', 'Attendance dispute', 'service-support', null));
        out.add(qa('QA-M2', '\u2708\uFE0F', 'Apply for leave',    null, 'Leave form opened'));
        out.add(qa('QA-M3', '\uD83E\uDDE0', 'Talk to a counselor', null, 'Counselor request sent'));
        out.add(qa('QA-M4', '\uD83D\uDEA9', 'Report an issue',     'service-support', null));
        return out;
    }

    private static KenHomeDashboardController.QuickActionDTO qa(String id, String emoji, String label, String route, String toast) {
        KenHomeDashboardController.QuickActionDTO q = new KenHomeDashboardController.QuickActionDTO();
        q.id = id; q.emoji = emoji; q.label = label; q.route = route; q.toast = toast;
        return q;
    }

    private static List<KenHomeDashboardController.CampusGuideDTO> buildCampusGuide() {
        List<KenHomeDashboardController.CampusGuideDTO> out = new List<KenHomeDashboardController.CampusGuideDTO>();
        out.add(guide('CG1', '\uD83D\uDDFA\uFE0F', 'Campus map',  'campus-map'));
        out.add(guide('CG2', '\uD83D\uDCCB',       'Orientation', null));
        out.add(guide('CG3', '\uD83C\uDFE2',       'Dept office', null));
        out.add(guide('CG4', '\uD83D\uDC68\u200D\uD83C\uDFEB', 'Advisor', 'mentors'));
        out.add(guide('CG5', '\uD83C\uDD98',       'Support',     'service-support'));
        out.add(guide('CG6', '\uD83D\uDCDA',       'Library',     null));
        out.add(guide('CG7', '\uD83C\uDFAD',       'Clubs',       'clubs'));
        out.add(guide('CG8', '\uD83D\uDCF6',       'IT / Wi-Fi',  'service-support'));
        return out;
    }

    private static KenHomeDashboardController.CampusGuideDTO guide(String id, String emoji, String label, String route) {
        KenHomeDashboardController.CampusGuideDTO g = new KenHomeDashboardController.CampusGuideDTO();
        g.id = id; g.emoji = emoji; g.label = label; g.route = route;
        return g;
    }

    private static List<KenHomeDashboardController.KaiChipDTO> buildKaiChips() {
        List<KenHomeDashboardController.KaiChipDTO> out = new List<KenHomeDashboardController.KaiChipDTO>();
        out.add(chip('K1', 'Where is my next class?'));
        out.add(chip('K2', 'How does attendance work?'));
        out.add(chip('K3', 'Where do I get my ID card?'));
        out.add(chip('K4', 'Which clubs can I join?'));
        return out;
    }

    private static KenHomeDashboardController.KaiChipDTO chip(String id, String text) {
        KenHomeDashboardController.KaiChipDTO c = new KenHomeDashboardController.KaiChipDTO();
        c.id = id; c.text = text;
        return c;
    }

    private static List<KenHomeDashboardController.ClearanceItemDTO> buildClearance() {
        List<KenHomeDashboardController.ClearanceItemDTO> out = new List<KenHomeDashboardController.ClearanceItemDTO>();
        out.add(clearance('CL1', 'Library dues cleared',                        true));
        out.add(clearance('CL2', 'Hostel clearance done',                       true));
        out.add(clearance('CL3', 'Lab equipment return — Physics Lab',          false));
        out.add(clearance('CL4', 'Fee settlement — \u20B92,400 pending',        false));
        out.add(clearance('CL5', 'Final transcript — after all clearances',     false));
        return out;
    }

    private static KenHomeDashboardController.ClearanceItemDTO clearance(String id, String text, Boolean done) {
        KenHomeDashboardController.ClearanceItemDTO c = new KenHomeDashboardController.ClearanceItemDTO();
        c.id = id; c.text = text; c.isDone = done;
        return c;
    }
}