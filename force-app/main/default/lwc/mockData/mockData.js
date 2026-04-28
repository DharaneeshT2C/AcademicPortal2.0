import SP_IMAGES from '@salesforce/resourceUrl/StudentPortalImages';

// Prefix helper — resolves relative IMG("images/...") paths against the
// StudentPortalImages static resource at runtime. Works on localhost too
// (in local Rollup dev, SP_IMAGES is undefined and paths stay relative).
const IMG = (p) => (SP_IMAGES ? `${SP_IMAGES}/${p}` : p);

export const studentProfile = {
  Id: 'STU001',
  FirstName: 'Arjun',
  LastName: 'R',
  StudentId: 'URK17MT026',
  Email: 'nupu*****@gmail.com',
  Phone: '+91 81694 *****',
  DateOfBirth: '21-06-1999',
  Gender: 'Male',
  BloodGroup: 'O+ve',
  Allergies: 'None',
  ProfileImage: '',
  Program: 'Master of Business Administration (MBA)',
  Semester: 'Semester 1',
  CGPA: 8.5,
  CreditsEarned: 12,
  TotalCredits: 12,
  PermanentAddress: { house: '', street: '', suburb: '', city: '', pincode: '' },
  CurrentAddress: { house: '29', street: '25 Live Oak Ave', suburb: 'Bay City', city: 'Texas', pincode: '560041' },
  Guardian: { name: 'John David', relationship: 'Father', phone: '9791237955', email: 'johndavid06@gmail.com' },
  AadharNumber: '1234 5678 0987'
};

export const attendanceSnapshot = [
  { subject: 'Applied Physics', percentage: 44 },
  { subject: 'Mathematics-1', percentage: 12 },
  { subject: 'Chemistry 101', percentage: 73 },
  { subject: 'Engineering Drawing', percentage: 73 },
  { subject: 'Business Communication', percentage: 73 }
];

export const todaySchedule = [
  { id: 'SCH001', subject: 'Business English', instructor: 'Ananya Iyer', time: '09:00 AM - 10:00 AM', location: 'Online', status: 'Present', type: 'class' },
  { id: 'SCH002', subject: 'Engineering Drawing', instructor: 'Arjun Varma', time: '01:30 PM - 02:30 PM', location: 'Room no 121, School of Engineering', status: 'Absent', type: 'class' },
  { id: 'SCH003', subject: 'Applied Physics', instructor: 'Renita Jacob', time: '11:00 AM - 12:00 PM', location: '', status: 'Happening now!', type: 'class', isLive: true },
  { id: 'SCH004', subject: 'Career Guidance', instructor: 'Ananya Iyer', time: '', location: '', status: 'Awaiting Approval', type: 'guidance' }
];

export const feedItems = [
  { id: 'F001', title: 'Ruby house- trifecta', description: 'Ruby House has achieved an incredible milestone by winning the sports competition for the third consecutive year, showcasing their unparalleled talent, teamwork, and dedication.', type: 'spotlight', image: '' },
  { id: 'F002', title: 'Symposium Mania', category: 'News', description: 'The symposium has been postponed due to unforeseen circumstances. The dates will be announced later.', date: '24-06-2024 | 25 minutes ago', type: 'news' },
  { id: 'F003', title: 'Creative thinking', category: 'Social Media', description: 'Embrace the power of creative thinking!', type: 'social' }
];

export const semesters = [
  { id: 1, name: 'Semester 1', majorCredits: '12/12', minorCredits: '', status: 'Approved', statusType: 'completed' },
  { id: 2, name: 'Semester 2', majorCredits: '00/12', minorCredits: '', status: 'Ongoing', statusType: 'ongoing' },
  { id: 3, name: 'Semester 3', majorCredits: '', minorCredits: '', status: 'Upcoming', statusType: 'upcoming' },
  { id: 4, name: 'Semester 4', majorCredits: '', minorCredits: '', status: 'Upcoming', statusType: 'upcoming' },
  { id: 5, name: 'Semester 5', majorCredits: '', minorCredits: '', status: 'Upcoming', statusType: 'upcoming' },
  { id: 6, name: 'Semester 6', majorCredits: '', minorCredits: '', status: 'Upcoming', statusType: 'upcoming' },
  { id: 7, name: 'Semester 7', majorCredits: '', minorCredits: '', status: 'Upcoming', statusType: 'upcoming' },
  { id: 8, name: 'Semester 8', majorCredits: '', minorCredits: '', status: 'Upcoming', statusType: 'upcoming' }
];

export const semesterPrograms = [
  { id: 'P001', name: 'BA., Psychology', mandatory: '0 / 12 credits', electives: '0 / 6 credits', status: 'Incomplete', lastDate: '12 May 2026' },
  { id: 'P002', name: 'Minor Program 1', description: 'Choose a minor pathway to get started with course enrolment.', lastDate: '23 April 2026', canEnroll: true },
  { id: 'P003', name: 'Minor Program 2', description: 'Choose a minor pathway to get started with course enrolment.', lastDate: '23 April 2026', canEnroll: true }
];

export const programOptions = [
  { id: 'PO001', name: 'Data Science & Analytics', mandatoryCredits: 24, electiveCredits: 8, selected: false },
  { id: 'PO002', name: 'Artificial Intelligence & Machine Learning', mandatoryCredits: 24, electiveCredits: 12, selected: true },
  { id: 'PO003', name: 'Cyber Security & Ethical Hacking', mandatoryCredits: 12, electiveCredits: 10, selected: false },
  { id: 'PO004', name: 'Business Analytics', mandatoryCredits: 28, electiveCredits: 14, selected: false },
  { id: 'PO005', name: 'Financial Markets & Investment Management', mandatoryCredits: 20, electiveCredits: 12, selected: false }
];

export const courses = [
  { id: 'C001', name: 'Cognitive Psychology', code: 'DS1829', credits: 4, instructor: 'Mrs Smitha Beryl', location: 'Room 201', tags: ['Mandatory', 'Theory'], program: 'BA., Psychology', semester: 'Semester 1', image: '' },
  { id: 'C002', name: 'Environmental Psychology', code: 'DS1830', credits: 4, instructor: 'Mrs Smitha Beryl', location: 'Math Lab', tags: ['Elective', 'Practical'], program: 'BA., Psychology', semester: 'Semester 1', image: '' },
  { id: 'C003', name: 'Forensic Psychology', code: 'DS1831', credits: 4, instructor: 'Mrs Smitha Beryl', location: 'Room 201', tags: ['Mandatory', 'Theory'], program: 'BA., Psychology', semester: 'Semester 1', image: '' },
  { id: 'C004', name: 'Lab Practicals', code: 'DS1832', credits: 4, instructor: 'Mrs Smitha Beryl', location: 'Math Lab', tags: ['Mandatory', 'Theory'], program: 'BA., Psychology', semester: 'Semester 1', image: '' },
  { id: 'C005', name: 'Psychological Testing & Assessment', code: 'DS1833', credits: 4, instructor: 'Mrs Smitha Beryl', location: 'Math Lab', tags: ['Elective', 'Practical'], program: 'BA., Psychology', semester: 'Semester 1', image: '' },
  { id: 'C006', name: 'Psychological Statistics', code: 'DS1834', credits: 4, instructor: 'Mrs Smitha Beryl', location: 'Room 201', tags: ['Mandatory', 'Theory'], program: 'BA., Psychology', semester: 'Semester 1', image: '' },
  { id: 'C007', name: 'Counselling Foundations', code: 'DS1929', credits: 3, instructor: 'Dr Ananya Rao', location: 'Room 312', tags: ['Mandatory', 'Theory'], program: 'BA., Psychology', semester: 'Semester 2', image: '' },
  { id: 'C008', name: 'Behavioural Neuroscience', code: 'DS1930', credits: 4, instructor: 'Dr Ananya Rao', location: 'Lab Block C', tags: ['Mandatory', 'Practical'], program: 'BA., Psychology', semester: 'Semester 2', image: '' },
  // Digital Marketing & E-Commerce
  { id: 'C101', name: 'Digital Marketing Foundations', code: 'DM2101', credits: 4, instructor: 'Dr Karthik Iyer', location: 'Room 410', tags: ['Mandatory', 'Theory'], program: 'Digital Marketing & E-Commerce', semester: 'Semester 1', image: '' },
  { id: 'C102', name: 'SEO & Content Strategy', code: 'DM2102', credits: 3, instructor: 'Mrs Ritika Sen', location: 'Room 411', tags: ['Mandatory', 'Theory'], program: 'Digital Marketing & E-Commerce', semester: 'Semester 1', image: '' },
  { id: 'C103', name: 'E-Commerce Platforms Lab', code: 'DM2103', credits: 4, instructor: 'Mr Joseph Varghese', location: 'E-Lab', tags: ['Mandatory', 'Practical'], program: 'Digital Marketing & E-Commerce', semester: 'Semester 1', image: '' },
  { id: 'C104', name: 'Performance Marketing', code: 'DM2104', credits: 3, instructor: 'Mrs Ritika Sen', location: 'Room 412', tags: ['Elective', 'Theory'], program: 'Digital Marketing & E-Commerce', semester: 'Semester 1', image: '' },
  { id: 'C105', name: 'Brand Storytelling', code: 'DM2201', credits: 3, instructor: 'Dr Karthik Iyer', location: 'Room 410', tags: ['Elective', 'Theory'], program: 'Digital Marketing & E-Commerce', semester: 'Semester 2', image: '' },
  // Financial Markets & Investment Management
  { id: 'C201', name: 'Investment Analysis', code: 'FM3101', credits: 4, instructor: 'Prof Suresh Menon', location: 'Block B-204', tags: ['Mandatory', 'Theory'], program: 'Financial Markets & Investment Management', semester: 'Semester 1', image: '' },
  { id: 'C202', name: 'Financial Derivatives', code: 'FM3102', credits: 4, instructor: 'Prof Suresh Menon', location: 'Block B-205', tags: ['Mandatory', 'Theory'], program: 'Financial Markets & Investment Management', semester: 'Semester 1', image: '' },
  { id: 'C203', name: 'Portfolio Management Lab', code: 'FM3103', credits: 3, instructor: 'Dr Pooja Khandelwal', location: 'Trading Lab', tags: ['Mandatory', 'Practical'], program: 'Financial Markets & Investment Management', semester: 'Semester 1', image: '' },
  { id: 'C204', name: 'Equity Research', code: 'FM3104', credits: 3, instructor: 'Dr Pooja Khandelwal', location: 'Block B-206', tags: ['Elective', 'Theory'], program: 'Financial Markets & Investment Management', semester: 'Semester 1', image: '' },
  { id: 'C205', name: 'Risk & Compliance', code: 'FM3201', credits: 3, instructor: 'Prof Suresh Menon', location: 'Block B-204', tags: ['Mandatory', 'Theory'], program: 'Financial Markets & Investment Management', semester: 'Semester 2', image: '' }
];

export const attendanceData = {
  today: [
    { id: 'A001', subject: 'Finance-BCA | BS2923', time: '08:00 AM to 09:00 AM', status: 'Present' },
    { id: 'A002', subject: 'Date Structure-BCA | DS2922', time: '09:00 AM to 10:00 AM', status: 'Absent' },
    { id: 'A003', subject: 'Economics-BCA | EC2943', time: '10:00 AM to 11:00 AM', status: 'Present' }
  ],
  needsAttention: [
    { subject: 'Mathematics-BCA | DS6922', message: 'Attendance below 50%. Attend upcoming classes to stay eligible.' },
    { subject: 'Date Structure-BCA | DS2922', message: 'Missed 4 of the last 6 classes. Avoid further absences this month.' },
    { subject: 'Economics-BCA | EC2943', message: 'Missed 4 out of 5 classes. Attend the next class to stay on track.' }
  ],
  courseWise: [
    { subject: 'Applied Physi...', code: 'RY18372', percentage: 55, atRisk: false },
    { subject: 'Chemistry', code: 'HDY203', percentage: 45, atRisk: false },
    { subject: 'Mathematics', code: 'MS6202', percentage: 38, atRisk: true },
    { subject: 'English', code: 'ES1827', percentage: 50, atRisk: false },
    { subject: 'Circuits', code: 'DH18392', percentage: 35, atRisk: true },
    { subject: 'Circuits Lab', code: 'CL3728', percentage: 30, atRisk: true },
    { subject: 'Physics Lab', code: 'PH3829', percentage: 0, atRisk: false }
  ],
  leaveRequests: [
    { id: 'LR001', title: 'Going for a vacation', type: 'Personal leave', dates: '21 - 26 Dec 2026', status: 'Approved' },
    { id: 'LR002', title: '24th sports day practice', type: 'Exception', dates: '02 Jan 2026', status: 'In Review' },
    { id: 'LR003', title: 'Annual day - final rehearsal', type: '', dates: '', status: 'Rejected' }
  ]
};

export const thesisData = {
  phases: [
    { id: 1, name: 'Eligibility Requirements', status: 'In Progress' },
    { id: 2, name: 'Supervisor Approval', status: 'Locked' },
    { id: 3, name: 'Proposal Development', status: 'Locked' },
    { id: 4, name: 'Ethics Application', status: 'Locked' }
  ],
  requirements: [
    { text: 'Complete 24 course credits', detail: 'Currently at 12 credits', completed: false },
    { text: 'Finish Semester 2', detail: 'Currently in Semester 1', completed: false },
    { text: 'Maintain minimum GPA requirement', detail: 'Minimum 3.0 GPA required', completed: false },
    { text: 'Complete prerequisite research methods course', detail: 'EDU 501: Research Methodology', completed: false }
  ],
  preparationTips: [
    { title: 'Review thesis guidelines', description: 'Familiarize yourself with thesis formatting and requirements' },
    { title: 'Browse supervisor profiles', description: 'Get to know faculty research interests and expertise' },
    { title: 'Explore research areas', description: 'Start thinking about topics that interest you' }
  ]
};

export const mentors = [
  { id: 'M001', name: 'Tanya Singh', role: 'Executive', organization: 'TatvaOne', location: 'Pune, India', type: 'Alumni', image: '' },
  { id: 'M002', name: 'Ritika Patel', role: 'Assistant Professor', department: 'Mechanical Engineering', location: 'Pune, India', type: 'Primary', image: '' },
  { id: 'M003', name: 'Drishti A', role: 'Technical Program Manager', organization: 'Crafted Labs', department: '', type: 'Alumni', image: '' },
  { id: 'M004', name: 'Roshni S', role: 'Assistant Professor', department: 'Applied Physics', type: 'Primary', image: '' }
];

export const mentorTasks = [
  { id: 'MT001', title: 'Mentorship Session 2', status: 'In Progress', mentor: 'Renita Jacob', description: 'This has to be done in this quarter. Waiting on your reports and test results to take things forward.', priority: 'High', endDate: '17-03-23' },
  { id: 'MT002', title: 'Career Guidance - Follow...', status: 'In Progress', mentor: 'Ananya Iyer', description: 'We need to complete this by the end of the quarter. I\'m waiting for feedback from the alumni department head.', priority: 'Medium', endDate: '17-03-23' },
  { id: 'MT003', title: 'Industrial Automation pro...', status: 'On-Hold', mentor: 'Vidushi Rastogi', description: 'This needs to be completed this quarter. I\'m waiting for feedback from the alumni department head.', priority: 'Low', endDate: '17-03-23' }
];

export const mentorSessions = [
  { id: 'MS001', title: 'Mentorship Session with Renita Jacob', mentor: 'Renita Jacob', time: '09:00 AM - 10:30 AM', status: 'Happening now!', isLive: true },
  { id: 'MS002', title: 'Mentorship Session with Ananya Iyer', mentor: 'Ananya Iyer', time: '09:00 AM - 10:30 AM', status: 'Completed', actions: ['Leave Feedback'] },
  { id: 'MS003', title: 'Career Guidance', mentor: 'Ananya Iyer', time: '', status: 'Awaiting Approval' }
];

export const feeData = {
  program: 'Master of Business Administration (MBA)',
  status: 'Ongoing',
  totalPaid: 40000,
  totalPaidOf: 340000,
  totalPending: 300000,
  totalPendingOf: 340000,
  totalFeeAmount: 340000,
  paymentStatus: 'On Track',
  paymentStatusMessage: 'All your payments are up to date.',
  semesters: [
    {
      name: 'MBA - Semester 1',
      status: 'Ongoing',
      totalFeeAmount: 188000,
      totalDueAmount: 118000,
      totalPaid: 70000,
      fees: [
        { item: 'Academic Fees', dueDate: '16 Aug 2026', currency: 'INR', totalPayable: 118000, totalPaid: 20000, remaining: 98000, lateFee: '', status: 'Partially Paid', children: [
          { item: 'Instalment 1', dueDate: '16 Aug 2026', currency: 'INR', totalPayable: 14750, totalPaid: 0, remaining: 14750, lateFee: 500, status: 'Overdue' },
          { item: 'Instalment 2', dueDate: '16 Aug 2026', currency: 'INR', totalPayable: 29500, totalPaid: 29500, remaining: 0, lateFee: '', status: 'Fully Paid' },
          { item: 'Instalment 3', dueDate: '16 Aug 2026', currency: 'INR', totalPayable: 59000, totalPaid: 20000, remaining: 39000, lateFee: '', status: 'Partially Paid' },
          { item: 'Instalment 4', dueDate: '16 Aug 2026', currency: 'INR', totalPayable: 14750, totalPaid: 0, remaining: 14750, lateFee: '', status: 'Pending' }
        ]},
        { item: 'Annual Assessment fee', dueDate: '16 Aug 2026', currency: 'INR', totalPayable: 28000, totalPaid: 0, remaining: 28000, lateFee: '', status: 'Pending' }
      ]
    },
    { name: 'MBA - Semester 2', status: 'Upcoming', totalFeeAmount: 188000 }
  ],
  invoices: [
    { id: 'INV001', particulars: '2026 MBA Jul Sem 1', invoiceId: 'DG3749D9030', date: '16 Aug 2026', totalPaid: 118000, currency: 'INR', remaining: '', proForma: true, invoice: true },
    { id: 'INV002', particulars: '2026 MBA Jan Sem 2', invoiceId: 'JH3647893894', date: '16 Aug 2026', totalPaid: 70800, currency: 'INR', remaining: 5000, proForma: true, invoice: false },
    { id: 'INV003', particulars: '2026 MBA Jul Sem 3', invoiceId: 'JH3647893894', date: '16 Aug 2026', totalPaid: 70800, currency: 'INR', remaining: 20000, proForma: true, invoice: false },
    { id: 'INV004', particulars: '2027 MBA Feb Sem 4', invoiceId: 'JH3647893894', date: '16 Aug 2026', totalPaid: 70800, currency: 'INR', remaining: '', proForma: true, invoice: true }
  ],
  transactions: [
    { id: 'DG3749D9030', date: '16 Aug 2026', paymentMode: 'Razor Pay', currency: 'INR', totalPaid: 18000, status: 'Success' },
    { id: 'JH3647893894', date: '16 Aug 2026', paymentMode: 'Razor Pay', currency: 'INR', totalPaid: 5000, status: 'Failed' },
    { id: 'JH3647893894', date: '17 Aug 2026', paymentMode: 'Razor Pay', currency: 'INR', totalPaid: 7800, status: 'Success' },
    { id: 'JH3647893894', date: '17 Aug 2026', paymentMode: 'Razor Pay', currency: 'INR', totalPaid: 800, status: 'Success' }
  ],
  feePlan: [
    { item: 'Academic Fees', dueDate: '16 Aug 2026', currency: 'INR', totalAmount: 328000, concession: 200000, tax: 10000, tds: 8000, totalPayable: 128000, status: 'Partially Paid', children: [
      { item: 'Tuition Fee', dueDate: '16 Aug 2026', currency: 'INR', totalAmount: 159000, concession: 100000, tax: 5000, tds: 3000, totalPayable: 59000 },
      { item: 'Registration Fee', dueDate: '16 Aug 2026', currency: 'INR', totalAmount: 79500, concession: 50000, tax: 2500, tds: 2500, totalPayable: 29500 },
      { item: 'Development Fee', dueDate: '16 Aug 2026', currency: 'INR', totalAmount: 79500, concession: 50000, tax: 2500, tds: 2500, totalPayable: 29500 }
    ]},
    { item: 'Annual Assessment fee', dueDate: '16 Aug 2026', currency: 'INR', totalAmount: 28000, concession: 8000, tax: 8000, tds: 8000, totalPayable: 5118000, status: 'Pending' }
  ]
};

export const examData = {
  courses: [
    { name: 'Network Analysis & Synthesis', code: 'ECE101', exam: 'End Semester', credits: 3, format: 'Theory', type: 'Regular', eligibility: 'Eligible', selected: true },
    { name: 'Signals & Systems', code: 'ECE102', exam: 'End Semester', credits: 4, format: 'Theory', type: 'Backlog', eligibility: 'Not Eligible', selected: false },
    { name: 'Human Resource Management', code: 'ECE103', exam: 'End Semester', credits: 3, format: 'Theory', type: 'Backlog', eligibility: 'Eligible', selected: true },
    { name: 'VLSI Design', code: 'ECE104', exam: 'End Semester', credits: 4, format: 'Practical', type: 'Regular', eligibility: 'Eligible', selected: true },
    { name: 'Microwave Engineering', code: 'ECE105', exam: 'End Semester', credits: 3, format: 'Theory', type: 'Regular', eligibility: 'Eligible', selected: true }
  ],
  totalFee: 1000,
  windowCloses: '12:00 minutes',
  results: {
    semesterBreakup: [
      { sem: 'Sem 1', gpa: 7.5 }, { sem: 'Sem 2', gpa: 8.0 }, { sem: 'Sem 3', gpa: 6.1 },
      { sem: 'Sem 4', gpa: 6.2 }, { sem: 'Sem 5', gpa: 6.0 }, { sem: 'Sem 6', gpa: 8.2 },
      { sem: 'Sem 7', gpa: 0 }, { sem: 'Sem 8', gpa: 0 }
    ],
    marksBreakdown: [
      { course: 'Network Analysis & Synthesis', code: 'ECE101', credits: 3, creditsEarned: 3, compositeScore: 79, grade: 'A' },
      { course: 'Signals & Systems', code: 'ECE02', credits: 4, creditsEarned: 4, compositeScore: 79, grade: 'B' },
      { course: 'Human Resource Management', code: 'ECE103', credits: 3, creditsEarned: 3, compositeScore: 79, grade: 'B' },
      { course: 'VLSI Design', code: 'ECE104', credits: 4, creditsEarned: 4, compositeScore: 79, grade: 'A+' },
      { course: 'Microwave Engineering', code: 'ECE105', credits: 3, creditsEarned: 3, compositeScore: 79, grade: 'F' }
    ],
    courseDetail: {
      courseCode: 'MBAG MGT 103',
      courseName: 'Network Analysis & Synthesis',
      section: 'A',
      term: '2026 - NOV - MBAG - term 1 - Singapore',
      components: [
        { name: 'Quiz', maxMarks: 50, weightage: 40 },
        { name: 'Mid Term', maxMarks: 100, weightage: 30 },
        { name: 'End Term', maxMarks: 100, weightage: 30 }
      ],
      composite: 86,
      finalGrade: 'A'
    }
  }
};

export const placementData = {
  cycle: 'Placement Cycle 1 (Jul-Dec 2026)',
  registrationOpen: true,
  instructions: {
    beforeOptIn: [
      'By registering, you agree to participate in Placement Cycle 1 (Jul-Dec 2026).',
      'You must maintain your profile & resume up to date before applying to jobs.',
      'Once opted in, you can view and apply to available jobs.'
    ],
    policiesToNote: [
      { title: 'Dream & Super Dream Rules', text: 'Accepting a Dream/Super Dream offer will restrict further applications.' },
      { title: 'Withdrawals', text: 'You may opt out later only with approval from the placement cell.' },
      { title: 'Eligibility', text: 'Each job may have criteria (CGPA, branch, backlogs). Ineligible applications will be auto-flagged.' }
    ],
    nextSteps: [
      'Use the Career Compass to explore recommended roles.',
      'Book a slot with a Career Counsellor if you need guidance.',
      'Review institution placement guidelines in the Resources section.'
    ]
  },
  resources: [
    { name: 'Resume Library', icon: 'description' },
    { name: 'Preparation Resources', icon: 'menu_book' },
    { name: 'Book Slot with a Counsellor', icon: 'event' },
    { name: 'Support', icon: 'support' }
  ]
};

export const campusLifeData = {
  featuredEvents: [
    { id: 'E001', title: 'Entrepreneurship Bootcamp', type: 'Bootcamp', mode: 'Online', date: '12 Oct 2026', time: '4pm IST', image: '' },
    { id: 'E002', title: 'Workshop: Working with Designers and PMs', type: 'Workshop', mode: 'Offline', date: '12 Oct 2026', time: '4pm IST', image: '' }
  ],
  clubs: [
    { id: 'CL001', name: 'Cultural Club', icon: 'palette', thumb: IMG('images/clubs/cultural.jpg') },
    { id: 'CL002', name: 'Short Film Enthusiasts', icon: 'movie', thumb: IMG('images/clubs/film.jpg') },
    { id: 'CL003', name: 'Photography Club', icon: 'camera_alt', thumb: IMG('images/clubs/photography.jpg') },
    { id: 'CL004', name: 'Data Science Club', icon: 'analytics', thumb: IMG('images/clubs/datascience.jpg') }
  ],
  gatePass: {
    activeCount: 3,
    expiredCount: 10,
    upcomingCount: 3,
    notUsedCount: 0
  },
  hostel: {
    roomNo: 'Room no. 301',
    type: 'Type A Residence',
    building: 'Residence Hall B',
    roommates: ['R1', 'R2', 'R3'],
    warden: { name: 'Toby Maguire', email: 'toby.maguire@ken.edu.in' }
  },
  mess: {
    breakfast: { time: '07:30 onwards', icon: 'free_breakfast' },
    lunch: { time: '13:00 onwards', icon: 'restaurant' },
    snacks: { time: '17:00 onwards', icon: 'local_cafe' },
    dinner: { time: '20:30 onwards', icon: 'dinner_dining' }
  }
};

export const clubsData = [
  { id: 'DC001', name: 'Cultural Club', members: '1.2k', friends: 'Sajin and 24 friends are members', image: IMG('images/clubs/cultural.jpg'), isPrivate: false },
  { id: 'DC002', name: 'Short Film Enthusiasts', members: '1.2k', friends: 'Sajin and 24 friends are members', image: IMG('images/clubs/film.jpg'), isPrivate: false },
  { id: 'DC003', name: 'Photography Club', members: '1.2k', friends: 'Sajin and 24 friends are members', image: IMG('images/clubs/photography.jpg'), isPrivate: false },
  { id: 'DC004', name: 'Data Science Club', members: '1.2k', friends: 'Sajin and 24 friends are members', image: IMG('images/clubs/datascience.jpg'), suggested: true },
  { id: 'DC005', name: 'Volunteering Club', members: '1.2k', friends: 'Sajin and 24 friends are members', image: IMG('images/clubs/debate.jpg'), suggested: true },
  { id: 'DC006', name: '5K Running Club', members: '1.2k', friends: 'Sajin and 24 friends are members', image: IMG('images/clubs/robotics.jpg'), suggested: true },
  { id: 'DC007', name: 'Blood Donation Club', members: '1.2k', image: IMG('images/clubs/blooddonation.jpg'), isPrivate: true },
  { id: 'DC008', name: 'Cultural Club', members: '1.2k', image: IMG('images/clubs/cultural.jpg'), isPrivate: true },
  { id: 'DC009', name: 'Short Film Enthusiasts', members: '1.2k', image: IMG('images/clubs/film.jpg'), isPrivate: true }
];

export const gatePassList = [
  { id: 'GP001', requestId: '#20240101', type: 'Visitor Request', visitor: 'Mohit Sharma (Father)', description: 'Visiting to discuss semester academic progress and upcoming internship plans', entryDateTime: '06 Feb 2026, 10:00 AM', exitDateTime: '07 Feb 2026 - 09 Feb 2026', approvedOn: '02 Oct 2026', status: 'Active', attachment: 'image.png' },
  { id: 'GP002', requestId: '#20240101', type: 'Visitor Request', visitor: 'Rajesh Kumar (Guardian)', description: 'Visiting to attend department faculty meeting and review academic performance.', entryDateTime: '', exitDateTime: '07 Feb 2026 - 09 Feb 2026', submittedOn: '09 Oct 2026', status: 'In Review', attachment: 'image.png' },
  { id: 'GP003', requestId: '#20240101', type: 'Student Exit Request', description: 'Academic Guidance Session', exitDateTime: '07 Feb 2026 - 09 Feb 2026', rejectedOn: '23-12-23', status: 'Rejected' },
  { id: 'GP004', requestId: '#20240101', type: 'Student Exit Request', description: 'Medical Appointment', exitDateTime: '', closedOn: '23-12-23', status: 'Closed' }
];

export const hostelDetailData = {
  room: { number: 'Room no. 301', type: '<Room Type>', location: '<Location of the Room>' },
  roommates: [],
  warden: { name: 'Toby Maguire', phone: '9876543210', email: 'toby.maguire@ken.edu.in' },
  residenceAllocation: { title: 'Residence Allocation 2026-27', description: 'Get started with your allocation for the upcoming year.' },
  billsAndPayments: [
    { title: 'Utility Excess: Rs.4,000', totalUsed: 54000, totalOf: 50000, dueBy: '23 Jan 2026' },
    { title: 'Electricity Excess: Rs.4,000', totalUsed: 54000, totalOf: 50000, dueBy: '23 Jan 2026' }
  ],
  leaveRequests: [
    { id: 'HLR001', requestId: '#20240101', title: '24th sports day practice', type: 'Exception', description: 'I attended the Mathematics class on 12th August, but my attendance is showing as Absent in the portal...', leaveDates: '26 Dec 2026 - 30 Dec 2026 (5 days)', submittedOn: '09 Oct 2026', status: 'In Review' },
    { id: 'HLR002', requestId: '#20240101', title: 'Family Function Leave', type: 'Personal leave', closedOn: '09 Oct 2026', status: 'Closed' }
  ],
  noticeBoard: [
    { title: 'Hostel Admin', type: 'Announcement', message: 'Hostel mess will remain closed on 16 Oct 2026 for Christmas', date: '16 Oct 2026 | 25 minutes ago' },
    { title: 'Hostel Talent Show', type: 'Announcement', message: 'Join us this saturday for a fantastic round of talent show exclusively for our freshers', location: 'Indoor Auditorium, EVR residence', date: '16 Oct 2026 | 25 minutes ago' }
  ]
};

export const messMenuData = {
  messName: 'Mess A',
  date: 'Monday, 12th August, 2026',
  meals: {
    breakfast: {
      time: '08:00 AM - 10:30 AM',
      items: ['Tea', 'Coffee', 'Watermelon juice', 'Corn Flakes', 'Choco Flakes', 'Bread Toast', 'Muesli', 'Muesli', 'Aloo Paratha with Curd & Pickle', 'Chole Bhature', 'Poori Bhaji', 'Medu Vada', 'Dosa', 'Lemon Rice', 'Lemon Rice'],
      jainItems: ['Bread Toast']
    },
    lunch: {
      time: '12:30 PM - 02:30 PM',
      items: ['Soup', 'Salad', 'Gravy veg', 'Dal', 'Rice', 'Roti', 'Curd', 'Pickle', 'Sweet']
    },
    highTea: {
      time: '04:30 PM - 06:30 PM',
      items: ['Tea', 'Coffee', 'Aloo channa chat', 'Green chutney']
    },
    dinner: {
      time: '07:30 PM - 11:00 PM',
      items: ['Hot & sour soup', 'Pani poori', 'Black chana masala', 'Dal kolhapuri', 'Phulka', 'Yellow rice', 'Pickle', 'Roasted papad', 'Tea']
    }
  }
};

export const serviceSupportData = {
  faqs: [
    {
      category: 'Academic resources and support',
      questions: [
        { q: 'What academic resources are available to students?', a: 'You can access tutoring, writing support, library databases, study workshops, academic advising, and course-specific help (TA hours or support centers).' },
        { q: 'Can students get academic guidance or mentorship?', a: '' },
        { q: 'How do I stay updated on academic programs and learning opportunities?', a: '' }
      ]
    },
    { category: 'Can I customize my email preferences?', questions: [] },
    { category: 'What types of events are available, and how can I register?', questions: [] },
    { category: 'Is there a directory to connect with other students or alumni?', questions: [] }
  ],
  serviceRequests: [
    { id: 'SR001', requestId: '#20240101', title: 'Career Services', subtitle: 'Resume/CV Review & Optimization', attachment: 'Resume.pdf', closedOn: '23-12-23', status: 'Closed' },
    { id: 'SR002', requestId: '#20240101', title: 'Career Services', subtitle: 'Internship / Job Placement Assistance', status: 'In Review' }
  ]
};

export const feedbackData = {
  forms: [
    { id: 'FB001', title: 'Courses', count: 10, status: 'pending', icon: 'school' },
    { id: 'FB002', title: 'Faculty', count: 2, status: 'completed', icon: 'person' },
    { id: 'FB003', title: 'Mess', count: 2, status: 'completed', icon: 'restaurant' },
    { id: 'FB004', title: 'Hostel', count: 2, status: 'pending', icon: 'home' }
  ],
  needsAttention: [
    { title: '2026- Physics feedback form', dueIn: 'Due by 2 days', lastDate: '23-03-2026', urgent: true },
    { title: '2026- Business management feedback form', dueIn: '4 days left', lastDate: '23-03-2026', urgent: false }
  ]
};

export const scheduleData = [
  { id: 'SD001', title: 'Applied Physics', instructor: 'Dr Jeshur David', startTime: '9:00 AM', endTime: '10:00 AM', location: 'Room 201', color: 'blue' },
  { id: 'SD002', title: 'Thesis Discussion', instructor: 'Dr Jeshur David', startTime: '10:30 AM', endTime: '11:00 AM', location: 'Room 201', color: 'violet' },
  { id: 'SD003', title: 'Fluid Dynamics', instructor: 'Prof Karen Roshle', startTime: '11:00 AM', endTime: '12:00 PM', location: 'Room 305', color: 'sky' },
  { id: 'SD004', title: 'Lunch Break', instructor: '', startTime: '12:00 PM', endTime: '1:00 PM', location: 'Cafeteria', color: 'green' },
  { id: 'SD005', title: 'Career Bootcamp', instructor: 'Admin', startTime: '1:00 PM', endTime: '1:45 PM', location: 'Room 201', color: 'amber' },
  { id: 'SD006', title: 'Electromagnetic Theory', instructor: 'Dr Raymond Charles', startTime: '2:00 PM', endTime: '3:00 PM', location: 'Lab 1', color: 'blue' }
];

/* ── Peer-to-peer chat data ─────────────────────────────────────────────
 * Each contact has their own message thread. Messages mix formal English
 * with casual Hinglish to reflect realistic Indian university culture.
 * Sent messages from "self" carry a `status` field used to render WhatsApp-
 * style read receipts: 'sent' (✓), 'delivered' (✓✓ grey), 'read' (✓✓ blue).
 */
export const chatData = {
  contacts: [
    { id: 'CT001', name: 'Rohan Sharma',  lastMessage: 'Bro, OS lab notes bhej dena 🙏',         time: 'Just now',   type: 'Classmate · CSE-6',    online: true,  unread: 2, avatar: IMG('images/avatars/avatar3.jpg') },
    { id: 'CT002', name: 'Priya Iyer',    lastMessage: 'Library at 6? Need to finish DS assgn', time: '8m',         type: 'Classmate · CSE-6',    online: true,  unread: 1, avatar: IMG('images/avatars/avatar2.jpg') },
    { id: 'CT003', name: 'Aditya Verma',  lastMessage: 'Goa trip plan after exams confirmed?',  time: '1h',         type: 'Hostel · Block B',     online: false, unread: 0, avatar: IMG('images/avatars/avatar5.jpg') },
    { id: 'CT004', name: 'Ananya Iyer (Mentor)', lastMessage: 'Sent you the internship list. Have a look.', time: 'Yesterday', type: 'Mentor · Alumni',     online: false, unread: 0, avatar: IMG('images/avatars/avatar4.jpg') },
    { id: 'CT005', name: 'Karthik Reddy', lastMessage: 'Coding club practice tomorrow at 5',     time: 'Tue',        type: 'Coding Club',          online: false, unread: 0, avatar: IMG('images/avatars/avatar7.jpg') },
    { id: 'CT006', name: 'Sneha Kapoor',  lastMessage: 'Maths-III ke notes mil gaye?',           time: 'Mon',        type: 'Classmate · CSE-6',    online: true,  unread: 0, avatar: IMG('images/avatars/avatar6.jpg') },
    { id: 'CT007', name: 'Dr. Raghav Iyer', lastMessage: 'Office hours moved to 4 PM tomorrow.', time: 'Sun',        type: 'Faculty · Eng. Physics', online: false, unread: 0, avatar: IMG('images/avatars/avatar4.jpg') }
  ],

  /* Per-contact thread map. Keys match contacts[].id.
     status: only relevant for sender:'self' messages. */
  threads: {
    CT001: [
      { id: 'M1-1', sender: 'other', text: 'Yo Arjun! Kya scene hai?',                                 time: '9:42 AM' },
      { id: 'M1-2', sender: 'self',  text: 'Bas yaar, OS lab ke liye padh raha hoon. Tu?',              time: '9:43 AM', status: 'read' },
      { id: 'M1-3', sender: 'other', text: 'Same. Sharma sir ne assignment de diya, deadline Friday 😩', time: '9:43 AM' },
      { id: 'M1-4', sender: 'other', text: 'Bro, OS lab notes bhej dena 🙏',                            time: '9:55 AM' },
      { id: 'M1-5', sender: 'self',  text: 'Haan rukh, scan karke bhejta hoon shaam tak',               time: '9:56 AM', status: 'delivered' }
    ],
    CT002: [
      { id: 'M2-1', sender: 'self',  text: 'Hey Priya, DS assignment kahan tak pohncha?',                time: '8:15 AM', status: 'read' },
      { id: 'M2-2', sender: 'other', text: 'Tree traversal pe atki hoon. In-order recursion samajh nahi aa raha 🤯', time: '8:18 AM' },
      { id: 'M2-3', sender: 'self',  text: 'Lol same situation. Library aa, sath karte hain',           time: '8:19 AM', status: 'read' },
      { id: 'M2-4', sender: 'other', text: 'Library at 6? Need to finish DS assgn',                      time: '5:46 PM' }
    ],
    CT003: [
      { id: 'M3-1', sender: 'other', text: 'Bhai, exam ke baad Goa chalein? 4 din ka plan sochaa hai',   time: 'Tuesday' },
      { id: 'M3-2', sender: 'self',  text: 'Bas bhai, count me in 🌊. Budget kya soch raha hai?',        time: 'Tuesday', status: 'read' },
      { id: 'M3-3', sender: 'other', text: 'Around 8-10k per head. Hostel + scooty + food',              time: 'Tuesday' },
      { id: 'M3-4', sender: 'self',  text: 'Sounds fair. Karthik aur Rohan ko bhi pakad lete hain',      time: 'Tuesday', status: 'read' },
      { id: 'M3-5', sender: 'other', text: 'Goa trip plan after exams confirmed?',                       time: '1h ago' }
    ],
    CT004: [
      { id: 'M4-1', sender: 'other', text: 'Hi Arjun — based on your profile I have a few internship leads.', time: 'Mon, 4:00 PM' },
      { id: 'M4-2', sender: 'self',  text: 'Thank you ma\'am! That would be amazing.',                   time: 'Mon, 4:02 PM', status: 'read' },
      { id: 'M4-3', sender: 'other', text: 'I\'ve shortlisted 3 firms — fintech, ed-tech, and a product startup. Frontend roles.', time: 'Mon, 4:05 PM' },
      { id: 'M4-4', sender: 'self',  text: 'Sounds great. Should I update my resume first?',             time: 'Mon, 4:07 PM', status: 'read' },
      { id: 'M4-5', sender: 'other', text: 'Yes, polish the projects section. Send me a draft by Wed.',  time: 'Mon, 4:10 PM' },
      { id: 'M4-6', sender: 'other', text: 'Sent you the internship list. Have a look.',                  time: 'Yesterday' }
    ],
    CT005: [
      { id: 'M5-1', sender: 'other', text: 'Coding club practice tomorrow at 5',                         time: 'Tuesday' },
      { id: 'M5-2', sender: 'self',  text: 'Pakka aaunga. Topic kya hai?',                               time: 'Tuesday', status: 'read' },
      { id: 'M5-3', sender: 'other', text: 'Dynamic programming. Bring your laptop.',                    time: 'Tuesday' }
    ],
    CT006: [
      { id: 'M6-1', sender: 'other', text: 'Hey, Maths-III ke notes mil gaye? Class miss ki thi maine.', time: 'Monday' },
      { id: 'M6-2', sender: 'self',  text: 'Haan Sneha, mere paas hain. Drive link bhejta hoon.',        time: 'Monday', status: 'read' },
      { id: 'M6-3', sender: 'self',  text: 'Iyer sir ne 2 chapters cover kiye — Laplace + Fourier basics', time: 'Monday', status: 'read' }
    ],
    CT007: [
      { id: 'M7-1', sender: 'other', text: 'Arjun, your last lab report was solid. Keep it up.',         time: 'Sunday' },
      { id: 'M7-2', sender: 'self',  text: 'Thank you sir!',                                              time: 'Sunday', status: 'read' },
      { id: 'M7-3', sender: 'other', text: 'Office hours moved to 4 PM tomorrow.',                       time: 'Sunday' }
    ]
  }
};

export const notifications = [
  { id: 'N001', title: 'New event update: "Global Alumni Leadership Summit"', date: '15 Mar 2026 | 09:00 AM', time: '8 mins ago', type: 'event', image: '' },
  { id: 'N002', title: 'Your application for Product Analyst at PayPal is under review.', time: '8 mins ago', type: 'application', icon: 'paypal' },
  { id: 'N003', title: 'Happy birthday Joshua!', subtitle: 'On this special day, we wish you all the success in the world!', time: '12:34 pm', type: 'birthday', isYesterday: true },
  { id: 'N004', title: 'Lizzy Mathew has requested to join Movie Buff', time: '12:34 pm', type: 'request', actions: ['Accept', 'Decline'], image: '' },
  { id: 'N005', title: 'Jeshur David has invited you to join "Movie Buff"', time: '12:30pm', type: 'invite', actions: ['Accept', 'Decline'], image: '' },
  { id: 'N006', title: 'You have a new message from John Mathew:', subtitle: '"Hi! Could we discuss the internship..."', time: '11:28 am', type: 'message', image: '' }
];

export const sidebarNavItems = [
  { id: 'home', label: 'Home', icon: 'home', route: 'home' },
  { id: 'academics', label: 'Academics', icon: 'school', children: [
    { id: 'learn', label: 'Learn', route: 'learn' },
    { id: 'attendance', label: 'Attendance', route: 'attendance' },
    { id: 'course-enrolment', label: 'Course Enrolment', route: 'course-enrolment' },
    { id: 'my-exams', label: 'Exams', route: 'my-exams' },
    { id: 'results', label: 'Results', route: 'results' },
  ]},
  // Career (Placements + Mentors) hidden from nav per stakeholder decision.
  // Apex/objects remain deployed and the LWC code is in place if/when re-enabled.
  { id: 'campus-life', label: 'Campus Life', icon: 'apartment', children: [
    { id: 'campus-life-overview', label: 'Overview', route: 'overview' },
    { id: 'events', label: 'Events', route: 'events' },
    { id: 'clubs', label: 'Clubs', route: 'clubs' }
  ]},
  { id: 'fee-payment', label: 'Fee Payment', icon: 'payment', route: 'fee-payment' },
  // { id: 'feedback', label: 'Feedback & Surveys', icon: 'feedback', route: 'feedback' },
  // { id: 'support', label: 'Support', icon: 'support_agent', route: 'service-support' }
];

export const refundsData = [
  { id: 'REF-2026-001', requestDate: '10 Jan 2026', feeItem: 'Hostel Security Deposit', currency: 'INR', amount: '15,000', status: 'Processed', processedOn: '18 Jan 2026' },
  { id: 'REF-2026-002', requestDate: '22 Feb 2026', feeItem: 'Library Fine Reversal', currency: 'INR', amount: '500', status: 'Processed', processedOn: '25 Feb 2026' },
  { id: 'REF-2026-003', requestDate: '05 Mar 2026', feeItem: 'Exam Re-evaluation Fee', currency: 'INR', amount: '2,000', status: 'Pending', processedOn: '--' },
  { id: 'REF-2026-004', requestDate: '12 Mar 2026', feeItem: 'Course Drop - Elective', currency: 'INR', amount: '8,500', status: 'Rejected', processedOn: '--' }
];

export const eventsData = {
  featured: [
    { id: 'EV001', title: 'Entrepreneurship Bootcamp', type: 'Bootcamp', mode: 'Online', date: '12 Oct 2026', time: '4pm IST', image: IMG('images/events/hackathon.jpg') },
    { id: 'EV002', title: 'Workshop: Working with Designers...', type: 'Workshop', mode: 'Offline', date: '12 Oct 2026', time: '4pm IST', image: IMG('images/events/workshop.jpg') },
    { id: 'EV003', title: 'Career Development Workshop', type: 'Career Event', mode: 'Hybrid', date: '12 Oct 2026', time: '4pm IST', image: IMG('images/events/seminar.jpg') }
  ],
  upcoming: [
    { id: 'EV004', title: 'Personal Development and Leadership...', type: 'Others', mode: 'Online', date: '12, 13, 14 Oct, 2026', time: '', image: IMG('images/events/cultural.jpg') },
    { id: 'EV005', title: 'Student Career Panel Discussions', type: 'Networking', mode: 'Online', date: '12 Oct 2026', time: '4pm IST', image: IMG('images/events/seminar.jpg') },
    { id: 'EV006', title: 'Industry-Specific Workshops', type: 'Workshop', mode: 'Hybrid', date: '12 Oct 2026', time: '4pm IST', image: IMG('images/events/hackathon.jpg') }
  ],
  registered: [
    { id: 'REV001', title: 'Workshop: Figma Components and variables', mode: 'Online', startTime: '5:00 PM', endTime: '4:15 PM', image: IMG('images/events/workshop.jpg') },
    { id: 'REV002', title: 'Machine learning', mode: 'Hybrid', startTime: '5:00 PM', endTime: '4:15 PM', image: IMG('images/events/hackathon.jpg') }
  ]
};