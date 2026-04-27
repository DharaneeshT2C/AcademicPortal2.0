export const studentProfile = {
    FirstName: 'Arjun', LastName: 'Reddy', id: 'URK17MT026',
    branch: 'Computer Science', year: '3rd Year', semester: '6',
    streak: 12, attendance: 82
};

const SP = '0,14 8,11 16,9 24,7 32,5 40,2';
const SD = '0,4 8,4 16,5 24,6 32,10 40,13';
const SF = '0,8 8,8 16,8 24,8 32,8 40,8';
const SU = '0,12 8,10 16,8 24,6 32,4 40,3';
const SS = '0,14 8,12 16,10 24,9 32,9 40,9';

export const kpiData = {
    starting: [
        { id:'K-S1', accentClass:'kpi-accent accent-indigo',  dotClass:'kpi-dot kpi-dot-indigo',  label:'Onboarding', value:'2/6',       sparkPoints:SS, sparklineStyle:'color:#C7D2FE', isCheckValue:false, isClockValue:false, isPlainValue:true, pillClass:'kpi-delta kpi-delta-green', pill:'Steps done',       pillHasArrow:false, pillHasDot:true,  pillDotClass:'delta-dot delta-dot-emerald' },
        { id:'K-S2', accentClass:'kpi-accent accent-emerald', dotClass:'kpi-dot kpi-dot-emerald', label:'Attendance', value:'100%',      sparkPoints:SF, sparklineStyle:'color:#6EE7B7', isCheckValue:false, isClockValue:false, isPlainValue:true, pillClass:'kpi-delta kpi-delta-green', pill:'All clear',        pillHasArrow:false, pillHasDot:true,  pillDotClass:'delta-dot delta-dot-emerald' },
        { id:'K-S3', accentClass:'kpi-accent accent-green',   dotClass:'kpi-dot kpi-dot-green',   label:'Fees',       value:'\u20B90',   sparkPoints:SF, sparklineStyle:'color:#6EE7B7', isCheckValue:false, isClockValue:false, isPlainValue:true, pillClass:'kpi-delta kpi-delta-green', pill:'Nothing pending',  pillHasArrow:false, pillHasDot:true,  pillDotClass:'delta-dot delta-dot-emerald' },
        { id:'K-S4', accentClass:'kpi-accent accent-green',   dotClass:'kpi-dot kpi-dot-green',   label:'Standing',   value:'On Track',  sparkPoints:SU, sparklineStyle:'color:#6EE7B7', isCheckValue:true,  isClockValue:false, isPlainValue:false,pillClass:'kpi-delta kpi-delta-muted', pill:"Let's get started", pillHasArrow:false, pillHasDot:false, pillDotClass:'' }
    ],
    middle: [
        { id:'K-M1', accentClass:'kpi-accent accent-indigo', dotClass:'kpi-dot kpi-dot-indigo', label:'CGPA',       value:'8.2',     sparkPoints:SP, sparklineStyle:'color:#C7D2FE', isCheckValue:false, isClockValue:false, isPlainValue:true, pillClass:'kpi-delta kpi-delta-green', pill:'+0.4',             pillHasArrow:true,  pillHasDot:false, pillDotClass:'' },
        { id:'K-M2', accentClass:'kpi-accent accent-amber',  dotClass:'kpi-dot kpi-dot-amber',  label:'Attendance', value:'82%',     sparkPoints:SD, sparklineStyle:'color:#FDE68A', isCheckValue:false, isClockValue:false, isPlainValue:true, pillClass:'kpi-delta kpi-delta-amber', pill:'\u26A0 1 subject at risk',pillHasArrow:false, pillHasDot:true,  pillDotClass:'delta-dot delta-dot-amber' },
        { id:'K-M3', accentClass:'kpi-accent accent-red',    dotClass:'kpi-dot kpi-dot-red',    label:'Fees',       value:'\u20B924K',sparkPoints:SF, sparklineStyle:'color:#FCA5A5', isCheckValue:false, isClockValue:false, isPlainValue:true, pillClass:'kpi-delta kpi-delta-red',   pill:'Due Apr 30',       pillHasArrow:false, pillHasDot:true,  pillDotClass:'delta-dot delta-dot-red' },
        { id:'K-M4', accentClass:'kpi-accent accent-green',  dotClass:'kpi-dot kpi-dot-green',  label:'Standing',   value:'On Track',sparkPoints:SU, sparklineStyle:'color:#6EE7B7', isCheckValue:true,  isClockValue:false, isPlainValue:false,pillClass:'kpi-delta kpi-delta-muted', pill:'96/160 credits',   pillHasArrow:false, pillHasDot:false, pillDotClass:'' }
    ],
    ending: {
        fixed: [
            { id:'K-E1', accentClass:'kpi-accent accent-indigo', dotClass:'kpi-dot kpi-dot-indigo', label:'CGPA',    value:'8.4',     sparkPoints:SP, sparklineStyle:'color:#C7D2FE', isCheckValue:false, isClockValue:false, isPlainValue:true, pillClass:'kpi-delta kpi-delta-muted', pill:'Final: 8.4',  pillHasArrow:false, pillHasDot:false, pillDotClass:'' },
            { id:'K-E2', accentClass:'kpi-accent accent-violet', dotClass:'kpi-dot kpi-dot-violet', label:'Credits', value:'156/160', sparkPoints:SU, sparklineStyle:'color:#DDD6FE', isCheckValue:false, isClockValue:false, isPlainValue:true, pillClass:'kpi-delta kpi-delta-muted', pill:'4 remaining', pillHasArrow:false, pillHasDot:false, pillDotClass:'' },
            { id:'K-E4', accentClass:'kpi-accent accent-amber',  dotClass:'kpi-dot kpi-dot-amber',  label:'Clearance',value:'Pending',sparkPoints:SF, sparklineStyle:'color:#FDE68A', isCheckValue:false, isClockValue:true,  isPlainValue:false,pillClass:'kpi-delta kpi-delta-amber', pill:'3 of 5 steps',pillHasArrow:false, pillHasDot:true,  pillDotClass:'delta-dot delta-dot-amber' }
        ],
        careerByPath: {
            placements:       { id:'K-EP', accentClass:'kpi-accent accent-emerald', dotClass:'kpi-dot kpi-dot-emerald', label:'Career', value:'2 offers',    sparkPoints:SP, sparklineStyle:'color:#6EE7B7', isCheckValue:false, isClockValue:false, isPlainValue:true, pillClass:'kpi-delta kpi-delta-green', pill:'Respond by May 10',   pillHasArrow:false, pillHasDot:true,  pillDotClass:'delta-dot delta-dot-emerald' },
            'higher-studies': { id:'K-EH', accentClass:'kpi-accent accent-sky',     dotClass:'kpi-dot kpi-dot-sky',     label:'Career', value:'2 apps',      sparkPoints:SP, sparklineStyle:'color:#BAE6FD', isCheckValue:false, isClockValue:false, isPlainValue:true, pillClass:'kpi-delta kpi-delta-amber', pill:'SOP review pending',  pillHasArrow:false, pillHasDot:true,  pillDotClass:'delta-dot delta-dot-amber' },
            entrepreneurship: { id:'K-EE', accentClass:'kpi-accent accent-violet',  dotClass:'kpi-dot kpi-dot-violet',  label:'Career', value:'\uD83D\uDE80 Active', sparkPoints:SP, sparklineStyle:'color:#DDD6FE', isCheckValue:false, isClockValue:false, isPlainValue:true, pillClass:'kpi-delta kpi-delta-muted', pill:'Demo day in 3 wks',   pillHasArrow:false, pillHasDot:false, pillDotClass:'' },
            exploring:        { id:'K-EX', accentClass:'kpi-accent accent-slate',   dotClass:'kpi-dot kpi-dot-slate',   label:'Career', value:'Explore',     sparkPoints:SF, sparklineStyle:'color:#CBD5E1', isCheckValue:false, isClockValue:false, isPlainValue:true, pillClass:'kpi-delta kpi-delta-muted', pill:'3 options available', pillHasArrow:false, pillHasDot:false, pillDotClass:'' }
        }
    }
};

export const pinnedCardData = {
    middle: { label:'PINNED \u00B7 Apr 25\u201327', title:'Annual Tech Fest \u2014 Kenzaa 2026', desc:'Registrations open. 15+ competitive events, workshops, and keynotes from industry leaders.', cta:'Register now \u2192' },
    ending: { label:'PINNED \u00B7 Jun 15',         title:"Convocation 2026 \u2014 You're graduating!",     desc:'Confirm attendance & gown size by Jun 1. Invite family.',                                         cta:'RSVP now \u2192' }
};

export const feedData = {
    starting: [
        { id:'SF1', month:'Aug', day:'1',  tag:'INTRO',   tagClass:'feed-tag tag-reg',   title:'Orientation day schedule released',                desc:'Main auditorium, 9 AM. Bring your admission letter.',    isSocial:false, socialText:'' },
        { id:'SF2', month:'Aug', day:'1',  tag:'WELCOME', tagClass:'feed-tag tag-event', title:'Welcome aboard \u2014 Class of 2030!',              desc:'A message from the Vice Chancellor.',                    isSocial:false, socialText:'' },
        { id:'SF3', month:'Jul', day:'30', tag:'EVENT',   tagClass:'feed-tag tag-event', title:'Freshers Night \u2014 Aug 8 at the Open Amphitheatre', desc:'Music, dance, and meet your batchmates. Free entry.',  isSocial:false, socialText:'' },
        { id:'SF4', month:'Jul', day:'29', tag:'CLUB',    tagClass:'feed-tag tag-club',  title:'Club fair \u2014 explore 30+ student clubs',        desc:'Aug 5, 10 AM \u2013 4 PM, Central Lawn. Sign up on the spot.', isSocial:false, socialText:'' },
        { id:'SF5', month:'Jul', day:'28', tag:'LIBRARY', tagClass:'feed-tag tag-acad',  title:'Library access cards available for pickup',          desc:'Collect from the library front desk with your student ID.', isSocial:false, socialText:'' },
        { id:'SF6', month:'Jul', day:'28', tag:'IT',      tagClass:'feed-tag tag-reg',   title:'Set up campus Wi-Fi & student email',                desc:'Follow the IT guide in your portal or visit the helpdesk.', isSocial:false, socialText:'' },
        { id:'SF7', month:'Jul', day:'27', tag:'ACAD',    tagClass:'feed-tag tag-acad',  title:'First semester syllabus available',                  desc:'Download course outlines from the Academics section.',   isSocial:false, socialText:'' },
        { id:'SF8', month:'Jul', day:'27', tag:'SUPPORT', tagClass:'feed-tag tag-alert', title:'New student helpline is live',                       desc:'Call or chat for any setup, hostel, or academic queries.', isSocial:false, socialText:'' }
    ],
    middle: [
        { id:'MF1', month:'Apr', day:'14', tag:'EXAM',  tagClass:'feed-tag tag-exam',  title:'Mid-semester exams: Apr 28 \u2013 May 5',          desc:'Timetable and seating published on exam portal.',         isSocial:false, socialText:'' },
        { id:'MF2', month:'Apr', day:'15', tag:'REG',   tagClass:'feed-tag tag-reg',   title:'Elective registration for Sem 6 opens Apr 18',     desc:'Portal active at 9 AM. Plan your course trajectory.',     isSocial:false, socialText:'' },
        { id:'MF3', month:'Apr', day:'14', tag:'CLUB',  tagClass:'feed-tag tag-club',  title:'Coding Club Hackathon \u2014 48hr build challenge', desc:'Theme: AI for Sustainability. Teams of up to 4.',         isSocial:false, socialText:'' },
        { id:'MF4', month:'Apr', day:'12', tag:'EVENT', tagClass:'feed-tag tag-event', title:'Guest Lecture: AI in Healthcare \u2014 Apr 19',     desc:'Dr. Priya Sharma, Main Auditorium, 3 PM.',                isSocial:false, socialText:'' },
        { id:'MF5', month:'Apr', day:'11', tag:'CLUB',  tagClass:'feed-tag tag-club',  title:'Design Sprint by UI/UX Society \u2014 Apr 20',      desc:'Open to all departments. Register before Apr 18.',        isSocial:false, socialText:'' },
        { id:'MF6', month:'Apr', day:'10', tag:'ACAD',  tagClass:'feed-tag tag-acad',  title:'Semester 5 grade cards now available',              desc:'Download from the academics portal under Results.',       isSocial:false, socialText:'' },
        { id:'MF7', month:'Apr', day:'9',  tag:'ALERT', tagClass:'feed-tag tag-alert', title:'Campus placement drive: TCS, Infosys \u2014 May 3', desc:'Register by Apr 25 via Placements portal.',               isSocial:false, socialText:'' }
    ],
    ending: {
        common: [
            { id:'EF-C1', month:'May', day:'20', tag:'CLEAR',  tagClass:'feed-tag tag-alert', title:'No-dues clearance deadline: Jun 5',               desc:'Visit library, hostel, and lab to collect signatures.', isSocial:false, socialText:'' },
            { id:'EF-C2', month:'May', day:'15', tag:'ACAD',   tagClass:'feed-tag tag-acad',  title:'Final semester results declared',                  desc:'Download grade card from Results section.',             isSocial:false, socialText:'' },
            { id:'EF-C3', month:'May', day:'12', tag:'ALUMNI', tagClass:'feed-tag tag-reg',   title:'Join the Ken University alumni network',           desc:'Stay connected. Activate your alumni profile.',         isSocial:false, socialText:'' },
            { id:'EF-C4', month:'May', day:'10', tag:'EVENT',  tagClass:'feed-tag tag-event', title:'Farewell ceremony \u2014 May 25',                  desc:'Main Auditorium, 5 PM. Dress code: formal.',            isSocial:false, socialText:'' },
            { id:'EF-C5', month:'May', day:'8',  tag:'CERT',   tagClass:'feed-tag tag-cert',  title:'Transcript & certificate available after clearance', desc:'Complete all no-dues steps to unlock downloads.',     isSocial:false, socialText:'' }
        ],
        byPath: {
            placements: [
                { id:'EP1', month:'May', day:'18', tag:'PLACE',  tagClass:'feed-tag tag-offer', title:'Final placement report published',                 desc:'92% placement rate. Check your offer status.',          isSocial:false, socialText:'' },
                { id:'EP2', month:'May', day:'14', tag:'CAREER', tagClass:'feed-tag tag-acad',  title:'Recruiter connect: mock interviews open',         desc:'Book a 1-on-1 mock with industry panelists.',           isSocial:false, socialText:'' },
                { id:'EP3', month:'',    day:'',   tag:'',       tagClass:'',                   title:'', desc:'',                                                                                                     isSocial:true,  socialText:'24 students from your batch attended the placement prep session' }
            ],
            'higher-studies': [
                { id:'EH1', month:'May', day:'18', tag:'ADMIS', tagClass:'feed-tag tag-reg',  title:'University application deadlines approaching',      desc:'3 shortlisted programs close by Jun 1.',                isSocial:false, socialText:'' },
                { id:'EH2', month:'May', day:'14', tag:'PREP',  tagClass:'feed-tag tag-club', title:'SOP writing workshop \u2014 May 22',               desc:'Get 1-on-1 feedback from the career services team.',    isSocial:false, socialText:'' },
                { id:'EH3', month:'',    day:'',   tag:'',      tagClass:'',                  title:'', desc:'',                                                                                                      isSocial:true,  socialText:'18 students in your dept are pursuing higher studies this year' }
            ],
            entrepreneurship: [
                { id:'EE1', month:'May', day:'18', tag:'STARTUP', tagClass:'feed-tag tag-club',  title:'Incubator applications open \u2014 batch 2026', desc:'Apply by Jun 5. Mentorship + seed funding.',            isSocial:false, socialText:'' },
                { id:'EE2', month:'May', day:'14', tag:'EVENT',   tagClass:'feed-tag tag-event', title:'Startup showcase & demo day \u2014 Jun 1',      desc:'Present your idea to investors and alumni founders.',   isSocial:false, socialText:'' },
                { id:'EE3', month:'',    day:'',   tag:'',        tagClass:'',                   title:'', desc:'',                                                                                                  isSocial:true,  socialText:'18 students registered for the incubator info session' }
            ],
            exploring: [
                { id:'EX1', month:'May', day:'18', tag:'GUIDE',  tagClass:'feed-tag tag-acad', title:'Career paths session \u2014 May 22',            desc:'Open to all final-year students.',                       isSocial:false, socialText:'' },
                { id:'EX2', month:'May', day:'14', tag:'ALUMNI', tagClass:'feed-tag tag-reg',  title:'Explore alumni stories',                        desc:'Real journeys from your department.',                    isSocial:false, socialText:'' },
                { id:'EX3', month:'',    day:'',   tag:'',       tagClass:'',                  title:'', desc:'',                                                                                                  isSocial:true,  socialText:'12 batchmates chose placements \u2014 see what others picked' }
            ]
        }
    }
};

export const forYouData = {
    starting: [
        { id:'FY-S1', icon:'calendar_today', tileClass:'icon-tile tile-indigo',  title:'View your timetable',          context:'See your classes, rooms & timings',         route:'schedule' },
        { id:'FY-S2', icon:'play_circle',    tileClass:'icon-tile tile-violet',  title:'Watch welcome video',           context:'2-min portal walkthrough',                  toastMsg:'Launching welcome video...' },
        { id:'FY-S3', icon:'business',       tileClass:'icon-tile tile-sky',     title:'Find your department office',  context:'Floor 3, Block B \u2014 Prof. Sharma',     route:'campus-life' },
        { id:'FY-S4', icon:'person',         tileClass:'icon-tile tile-emerald', title:'Meet your faculty advisor',     context:'Book a slot for your intro meeting',        route:'mentors' },
        { id:'FY-S5', icon:'groups',         tileClass:'icon-tile tile-amber',   title:'Explore clubs & communities',   context:'30+ clubs open for sign-ups',               route:'clubs' }
    ],
    middle: [
        { id:'FY-M1', icon:'emoji_events',  tileClass:'icon-tile tile-indigo',  title:'Join hackathon team',              context:'CS dept \u00B7 12 batchmates already in', route:'clubs' },
        { id:'FY-M2', icon:'mic',           tileClass:'icon-tile tile-amber',   title:'Guest Lecture: AI in Healthcare',  context:'Apr 19, 3 PM \u00B7 Main Auditorium',     route:'events' },
        { id:'FY-M3', icon:'work',          tileClass:'icon-tile tile-sky',     title:'Explore summer internships',       context:'8 new openings match your profile',       route:'placements' },
        { id:'FY-M4', icon:'book',          tileClass:'icon-tile tile-violet',  title:'Try the new AI study planner',     context:'Personalized schedule for mid-sems',      toastMsg:'Opening study planner...' }
    ],
    ending: {
        placements: [
            { id:'FY-EP1', icon:'celebration',   tileClass:'icon-tile tile-indigo',  title:'RSVP for convocation',        context:'Confirm attendance & gown size',          toastMsg:'RSVP confirmed for Jun 15' },
            { id:'FY-EP2', icon:'article',       tileClass:'icon-tile tile-amber',   title:'Download degree certificate', context:'Available after clearance complete',      toastMsg:'Available after clearance' },
            { id:'FY-EP3', icon:'groups',        tileClass:'icon-tile tile-emerald', title:'Activate alumni profile',     context:'Stay connected with batchmates',          toastMsg:'Alumni profile activated' },
            { id:'FY-EP4', icon:'work',          tileClass:'icon-tile tile-sky',     title:'Accept placement offer',      context:'Respond to 2 offers by May 10',           route:'placements' },
            { id:'FY-EP5', icon:'schedule',      tileClass:'icon-tile tile-rose',    title:'Review offer deadline',       context:'TCS offer expires May 12',                route:'placements' },
            { id:'FY-EP6', icon:'play_circle',   tileClass:'icon-tile tile-violet',  title:'Join pre-joining webinar',    context:'May 28 \u2014 onboarding overview',       toastMsg:'Webinar link sent to your email' }
        ],
        'higher-studies': [
            { id:'FY-EH1', icon:'celebration',  tileClass:'icon-tile tile-indigo',  title:'RSVP for convocation',        context:'Confirm attendance & gown size',          toastMsg:'RSVP confirmed for Jun 15' },
            { id:'FY-EH2', icon:'article',      tileClass:'icon-tile tile-amber',   title:'Download degree certificate', context:'Available after clearance complete',      toastMsg:'Available after clearance' },
            { id:'FY-EH3', icon:'groups',       tileClass:'icon-tile tile-emerald', title:'Activate alumni profile',     context:'Stay connected with batchmates',          toastMsg:'Alumni profile activated' },
            { id:'FY-EH4', icon:'business',     tileClass:'icon-tile tile-sky',     title:'Finalize university apps',    context:'3 programs \u2014 2 pending submission',   route:'service-support' },
            { id:'FY-EH5', icon:'edit',         tileClass:'icon-tile tile-violet',  title:'SOP & recommendation check',  context:'1 recommendation letter pending',         toastMsg:'Reminder sent to Prof. Nair' },
            { id:'FY-EH6', icon:'book',         tileClass:'icon-tile tile-rose',    title:'Entrance prep support',       context:'GRE prep sessions available',             route:'mentors' }
        ],
        entrepreneurship: [
            { id:'FY-EE1', icon:'celebration',   tileClass:'icon-tile tile-indigo',  title:'RSVP for convocation',        context:'Confirm attendance & gown size',          toastMsg:'RSVP confirmed for Jun 15' },
            { id:'FY-EE2', icon:'article',       tileClass:'icon-tile tile-amber',   title:'Download degree certificate', context:'Available after clearance complete',      toastMsg:'Available after clearance' },
            { id:'FY-EE3', icon:'groups',        tileClass:'icon-tile tile-emerald', title:'Activate alumni profile',     context:'Stay connected with batchmates',          toastMsg:'Alumni profile activated' },
            { id:'FY-EE4', icon:'rocket_launch', tileClass:'icon-tile tile-violet',  title:'Apply to incubator',          context:'Batch 2026 applications open',            toastMsg:'Incubator application started' },
            { id:'FY-EE5', icon:'mic',           tileClass:'icon-tile tile-sky',     title:'Join startup showcase',       context:'Demo day Jun 1 \u2014 register now',       toastMsg:'Registration confirmed' },
            { id:'FY-EE6', icon:'person',        tileClass:'icon-tile tile-rose',    title:'Meet venture mentor',         context:'Book a 30-min strategy session',          route:'mentors' }
        ],
        exploring: [
            { id:'FY-EX1', icon:'celebration',  tileClass:'icon-tile tile-indigo',  title:'RSVP for convocation',        context:'Confirm attendance & gown size',          toastMsg:'RSVP confirmed for Jun 15' },
            { id:'FY-EX2', icon:'article',      tileClass:'icon-tile tile-amber',   title:'Download degree certificate', context:'Available after clearance complete',      toastMsg:'Available after clearance' },
            { id:'FY-EX3', icon:'groups',       tileClass:'icon-tile tile-emerald', title:'Activate alumni profile',     context:'Stay connected with batchmates',          toastMsg:'Alumni profile activated' },
            { id:'FY-EX4', icon:'groups',       tileClass:'icon-tile tile-sky',     title:'Attend career paths session', context:'May 22 \u2014 open to all final-year',     route:'events' },
            { id:'FY-EX5', icon:'link',         tileClass:'icon-tile tile-violet',  title:'Explore alumni stories',      context:'Real journeys from your department',      toastMsg:'Opening alumni portal...' },
            { id:'FY-EX6', icon:'help',         tileClass:'icon-tile tile-rose',    title:'Book guidance session',       context:'1-on-1 with career counselor',             route:'mentors' }
        ]
    }
};

export const nextStepsData = {
    placements: [
        { id:'NS-P1', icon:'mail',      tileClass:'icon-tile tile-rose',    title:'Respond to 2 offers by May 10', desc:"Don't miss the deadline" },
        { id:'NS-P2', icon:'work',      tileClass:'icon-tile tile-sky',     title:'Book final resume review',       desc:'Career services, last week of May' }
    ],
    'higher-studies': [
        { id:'NS-H1', icon:'list',      tileClass:'icon-tile tile-sky',   title:'Review university shortlist',    desc:'Narrow down to top 3 choices' },
        { id:'NS-H2', icon:'schedule',  tileClass:'icon-tile tile-amber', title:'Submit application by deadline', desc:'2 programs close Jun 1' }
    ],
    entrepreneurship: [
        { id:'NS-E1', icon:'edit',          tileClass:'icon-tile tile-violet', title:'Complete startup profile',           desc:'Required for incubator application' },
        { id:'NS-E2', icon:'calendar_today',tileClass:'icon-tile tile-amber',  title:'Register for incubator info session', desc:'May 25, 2 PM \u2014 Seminar Hall' }
    ],
    exploring: [
        { id:'NS-X1', icon:'groups', tileClass:'icon-tile tile-slate',  title:'Attend career paths session', desc:'May 22 \u2014 open to all final-year' },
        { id:'NS-X2', icon:'link',   tileClass:'icon-tile tile-indigo', title:'Explore alumni stories',      desc:'Real journeys from your department' }
    ]
};

export const needsAttentionData = {
    starting: [
        { id:'NA-S1', dotClass:'needs-dot dot-amber', rowClass:'needs-row needs-row-amber', title:'Hostel room allocation pending', context:'Complete by Aug 5 to confirm' },
        { id:'NA-S2', dotClass:'needs-dot dot-blue',  rowClass:'needs-row',                 title:'Collect ID card',                context:'Available at admin office, Block A' },
        { id:'NA-S3', dotClass:'needs-dot dot-amber', rowClass:'needs-row needs-row-amber', title:'Set up meal plan',               context:'Choose your plan before Aug 10' }
    ],
    middle: [
        { id:'NA-M1', dotClass:'needs-dot dot-red',    rowClass:'needs-row needs-row-rose',  title:'DS assignment due today',      context:'Submit by 11:59 PM' },
        { id:'NA-M2', dotClass:'needs-dot dot-amber',  rowClass:'needs-row needs-row-amber', title:'Math attendance at 68%',       context:'Below 75% \u2014 meet advisor' },
        { id:'NA-M3', dotClass:'needs-dot dot-blue',   rowClass:'needs-row',                 title:'Fee installment \u20B924,000', context:'Due Apr 30 \u00B7 15 days left' },
        { id:'NA-M4', dotClass:'needs-dot dot-amber',  rowClass:'needs-row needs-row-amber', title:'Check exam eligibility',       context:'Mid-sems start in 13 days' },
        { id:'NA-M5', dotClass:'needs-dot dot-orange', rowClass:'needs-row needs-row-orange',title:'Elective registration Apr 18', context:'Shortlist courses before deadline' }
    ]
};

export const clearanceData = [
    { id:'CL1', text:'Library dues cleared',                    isDone:true,  rowClass:'clearance-row clearance-done', textClass:'clearance-text cl-done-text' },
    { id:'CL2', text:'Hostel clearance done',                   isDone:true,  rowClass:'clearance-row clearance-done', textClass:'clearance-text cl-done-text' },
    { id:'CL3', text:'Lab equipment return \u2014 Physics Lab', isDone:false, rowClass:'clearance-row',                textClass:'clearance-text' },
    { id:'CL4', text:'Fee settlement \u2014 \u20B92,400 pending', isDone:false, rowClass:'clearance-row',              textClass:'clearance-text' },
    { id:'CL5', text:'Final transcript \u2014 after all clearances', isDone:false, rowClass:'clearance-row',           textClass:'clearance-text' }
];

export const scheduleData = {
    starting: [
        { id:'SC-S1', time:'9:00 AM',  subject:'Orientation \u2014 Welcome Address', location:'Main Auditorium',  stripeStyle:'background:#4F46E5', isLive:true  },
        { id:'SC-S2', time:'10:30 AM', subject:'Campus Tour',                         location:'Meet at Gate 1',    stripeStyle:'background:#059669', isLive:false },
        { id:'SC-S3', time:'1:00 PM',  subject:'Department Introduction',             location:'Block B, Room 301', stripeStyle:'background:#7C3AED', isLive:false },
        { id:'SC-S4', time:'3:00 PM',  subject:'Student Services Walkthrough',        location:'Admin Building',    stripeStyle:'background:#D97706', isLive:false }
    ],
    middle: [
        { id:'SC-M1', time:'9:00 AM',  subject:'Data Structures',      location:'Room 304',    stripeStyle:'background:#7C3AED', isLive:true  },
        { id:'SC-M2', time:'10:00 AM', subject:'Operating Systems Lab', location:'Lab 2',       stripeStyle:'background:#0891B2', isLive:false },
        { id:'SC-M3', time:'11:30 AM', subject:'Mathematics III',       location:'Room 201',    stripeStyle:'background:#059669', isLive:false },
        { id:'SC-M4', time:'2:00 PM',  subject:'Soft Skills Workshop',  location:'Auditorium',  stripeStyle:'background:#D97706', isLive:false }
    ],
    ending: [
        { id:'SC-E1', time:'10:00 AM', subject:'Project Viva \u2014 Final Review', location:'Room 405',        stripeStyle:'background:#E11D48', isLive:true  },
        { id:'SC-E2', time:'1:00 PM',  subject:'Clearance: Library',                location:'Central Library', stripeStyle:'background:#D97706', isLive:false },
        { id:'SC-E3', time:'3:00 PM',  subject:'Alumni Registration Drive',         location:'Seminar Hall',    stripeStyle:'background:#4F46E5', isLive:false }
    ]
};

export const spotlightData = {
    starting: { heroText:'First semester', isTextHero:true,  subText:'Orientation week + classes begin', date:'Aug 1 \u2013 Dec 15', cta:'View schedule \u2192'  },
    middle:   { heroText:'13',             isTextHero:false, subText:'days to mid-semester exams',       date:'Apr 28 \u2013 May 5', cta:'View timetable \u2192' },
    ending:   { heroText:'26',             isTextHero:false, subText:'days to convocation',               date:'Jun 15, 2026',        cta:'RSVP & details \u2192' }
};

export const quickActionsData = {
    starting: [
        { id:'QA-S1', icon:'schedule',      tileClass:'icon-tile tile-indigo',  label:'Orientation schedule', route:'schedule' },
        { id:'QA-S2', icon:'badge',         tileClass:'icon-tile tile-sky',     label:'Download temp ID',     toastMsg:'Your temporary ID is downloading' },
        { id:'QA-S3', icon:'support_agent', tileClass:'icon-tile tile-emerald', label:'Student services',     route:'service-support' },
        { id:'QA-S4', icon:'computer',      tileClass:'icon-tile tile-amber',   label:'IT helpdesk',          route:'service-support' }
    ],
    middle: [
        { id:'QA-M1', icon:'report_problem', tileClass:'icon-tile tile-amber',  label:'Attendance dispute',   route:'attendance' },
        { id:'QA-M2', icon:'flight_takeoff', tileClass:'icon-tile tile-sky',    label:'Apply for leave',      route:'service-support' },
        { id:'QA-M3', icon:'chat_bubble',    tileClass:'icon-tile tile-violet', label:'Talk to a counselor',  route:'mentors' },
        { id:'QA-M4', icon:'flag',           tileClass:'icon-tile tile-rose',   label:'Report an issue',      route:'service-support' }
    ],
    ending: {
        byPath: {
            placements: [
                { id:'QA-EP1', icon:'article',     tileClass:'icon-tile tile-indigo',  label:'Request transcript', toastMsg:'Transcript request submitted' },
                { id:'QA-EP2', icon:'celebration', tileClass:'icon-tile tile-violet',  label:'Convocation RSVP',   toastMsg:'RSVP confirmed! See you Jun 15' },
                { id:'QA-EP3', icon:'visibility',  tileClass:'icon-tile tile-emerald', label:'View offers',        route:'placements' },
                { id:'QA-EP4', icon:'check_circle',tileClass:'icon-tile tile-rose',    label:'Accept offer',       route:'placements' }
            ],
            'higher-studies': [
                { id:'QA-EH1', icon:'article',     tileClass:'icon-tile tile-indigo',  label:'Download transcript', toastMsg:'Transcript downloading...' },
                { id:'QA-EH2', icon:'celebration', tileClass:'icon-tile tile-violet',  label:'Convocation RSVP',    toastMsg:'RSVP confirmed! See you Jun 15' },
                { id:'QA-EH3', icon:'recommend',   tileClass:'icon-tile tile-sky',     label:'Request rec letter',  toastMsg:'Recommendation request sent' },
                { id:'QA-EH4', icon:'school',      tileClass:'icon-tile tile-rose',    label:'Higher studies help', route:'mentors' }
            ],
            entrepreneurship: [
                { id:'QA-EE1', icon:'article',       tileClass:'icon-tile tile-indigo', label:'Request transcript',  toastMsg:'Transcript request submitted' },
                { id:'QA-EE2', icon:'celebration',   tileClass:'icon-tile tile-violet', label:'Convocation RSVP',    toastMsg:'RSVP confirmed! See you Jun 15' },
                { id:'QA-EE3', icon:'rocket_launch', tileClass:'icon-tile tile-amber',  label:'Apply to incubator',  toastMsg:'Incubator application started' },
                { id:'QA-EE4', icon:'person',        tileClass:'icon-tile tile-rose',   label:'Meet startup mentor', route:'mentors' }
            ],
            exploring: [
                { id:'QA-EX1', icon:'article',     tileClass:'icon-tile tile-indigo',  label:'Request transcript',   toastMsg:'Transcript request submitted' },
                { id:'QA-EX2', icon:'celebration', tileClass:'icon-tile tile-violet',  label:'Convocation RSVP',     toastMsg:'RSVP confirmed! See you Jun 15' },
                { id:'QA-EX3', icon:'psychology',  tileClass:'icon-tile tile-amber',   label:'Book career session',  route:'mentors' },
                { id:'QA-EX4', icon:'people',      tileClass:'icon-tile tile-rose',    label:'Explore alumni paths', toastMsg:'Opening alumni portal...' }
            ]
        }
    }
};

export const campusGuideData = [
    { id:'CG1', icon:'map',           label:'Campus map',  tileClass:'icon-tile tile-indigo',  route:'campus-life' },
    { id:'CG2', icon:'celebration',   label:'Orientation', tileClass:'icon-tile tile-violet',  route:'schedule' },
    { id:'CG3', icon:'business',      label:'Dept office', tileClass:'icon-tile tile-sky',     route:'campus-life' },
    { id:'CG4', icon:'person',        label:'Advisor',     tileClass:'icon-tile tile-emerald', route:'mentors' },
    { id:'CG5', icon:'support_agent', label:'Support',     tileClass:'icon-tile tile-amber',   route:'service-support' },
    { id:'CG6', icon:'local_library', label:'Library',     tileClass:'icon-tile tile-rose',    route:'campus-life' },
    { id:'CG7', icon:'groups',        label:'Clubs',       tileClass:'icon-tile tile-indigo',  route:'clubs' },
    { id:'CG8', icon:'computer',      label:'IT / Wi-Fi',  tileClass:'icon-tile tile-sky',     route:'service-support' }
];

export const checklistData = [
    { id:'CK1', text:'Complete profile',       isDone:true,  rowClass:'cl-item-row', textClass:'cl-item-text cl-item-done' },
    { id:'CK2', text:'Upload documents',       isDone:true,  rowClass:'cl-item-row', textClass:'cl-item-text cl-item-done' },
    { id:'CK3', text:'Hostel room allocation', isDone:false, rowClass:'cl-item-row', textClass:'cl-item-text' },
    { id:'CK4', text:'Set up meal plan',       isDone:false, rowClass:'cl-item-row', textClass:'cl-item-text' },
    { id:'CK5', text:'Collect ID card',        isDone:false, rowClass:'cl-item-row', textClass:'cl-item-text' },
    { id:'CK6', text:'Verify email & login',   isDone:false, rowClass:'cl-item-row', textClass:'cl-item-text' }
];