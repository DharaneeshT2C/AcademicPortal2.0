export const placementCycle = {
  id: 'CYC001',
  name: 'Placement Cycle 1 (Jul–Dec 2026)',
  dateRange: 'Jul–Dec 2026',
  closeDate: '31 Dec 2026',
  registrationCloseDate: '30 Jun 2026',
  status: 'open'
};

export const studentPlacementStatus = {
  currentPhase: 2,
  optedIn: true,
  preferences: ['Information Technology', 'Manufacturing & Engineering', 'Consumer Goods', 'EdTech'],
  placedCompany: null,
  placedRole: null
};

export const jobs = [
  {
    id: 'JOB001',
    company: 'Paypal',
    companyInitial: 'P',
    companyColor: '#003087',
    logo: '',
    title: 'Developer',
    industry: 'Information Technology',
    companyType: 'Startup',
    location: ['Remote', 'Mumbai'],
    salary: { min: 500000, max: 800000, currency: '₹' },
    category: 'Dream',
    skillsMatch: 5,
    skillsTotal: 5,
    tags: ['Remote', 'Startup', 'Fintech'],
    description: 'At Paypal, work is more than a job - it\'s a calling: To build. To design. To code. To consult. To think along with clients and sell. To make markets. To invent. To collaborate. Not just to do something better, but to attempt things you\'ve never thought possible. Are you ready to lead in this new era of technology and solve some of the world\'s most challenging problems? If so, lets talk.',
    requirements: ['React.js and JavaScript', 'Build reusable components', 'Optimize components for maximum performance'],
    keyResponsibilities: [
      'Develop new user-facing features using React.js and JavaScript.',
      'Build reusable components and front-end libraries for future use.',
      'Optimize components for maximum performance across various devices and browsers.',
      'Collaborate with back-end developers and web designers to improve usability.',
      'Translate designs and wireframes into high-quality code.',
      'Write application interface code via JavaScript following React.js workflows.',
      'Coordinate with various teams working on distinct layers.',
      'Ensure that all components and the overall application are robust and easy to maintain.'
    ],
    skills: ['CSS', 'HTML', 'JavaScript', 'Node.js', 'ReactJS', 'Redux', 'REST API'],
    certifications: [
      { id: 'CERT1', title: 'Master CSS', duration: '2 weeks', color: '#10B981' },
      { id: 'CERT2', title: 'Advanced HTML', duration: '4 weeks', color: '#3B82F6' },
      { id: 'CERT3', title: 'Node.js Bootcamp', duration: '3 weeks', color: '#8B5CF6' }
    ],
    applicationProcess: [
      { id: 'AP1', stage: 'Initial Screening', date: '7th Oct, 2026' },
      { id: 'AP2', stage: 'Technical Interview', date: '12th Oct, 2026' },
      { id: 'AP3', stage: 'Aptitude Test', date: '16th Oct, 2026' },
      { id: 'AP4', stage: 'Leadership Round', date: '20th Oct, 2026' },
      { id: 'AP5', stage: 'HR Interview', date: '24th Oct, 2026' }
    ],
    applicationCloseDate: '08 Oct, 2026',
    alumniCount: 3,
    website: 'https://www.paypal.com',
    isSaved: false
  },
  {
    id: 'JOB002',
    company: 'Hindustan Unilever',
    companyInitial: 'U',
    companyColor: '#1F5EE0',
    logo: '',
    title: 'Software Engineer',
    industry: 'Consumer Goods',
    companyType: 'Corporate',
    location: ['Remote', 'Chennai'],
    salary: { min: 620000, max: 800000, currency: '₹' },
    category: 'Dream',
    skillsMatch: 4,
    skillsTotal: 5,
    tags: ['Remote', 'Corporate', 'FMCG'],
    description: 'Join Hindustan Unilever and be part of a team that is building technology for tomorrow.',
    keyResponsibilities: ['Build scalable backend services', 'Lead technical reviews', 'Mentor junior engineers'],
    applicationProcess: [
      { id: 'AP1', stage: 'Initial Screening', date: '7th Oct, 2026' },
      { id: 'AP2', stage: 'Aptitude Test', date: '12th Oct, 2026' },
      { id: 'AP3', stage: 'Technical Interview 2', date: '16th Oct, 2026' },
      { id: 'AP4', stage: 'Leadership Round', date: '20th Oct, 2026' },
      { id: 'AP5', stage: 'HR Interview', date: '24th Oct, 2026' }
    ],
    applicationCloseDate: '08 Oct, 2026',
    alumniCount: 8,
    website: 'https://www.hul.co.in',
    isSaved: true,
    notEligible: true,
    notEligibleReason: 'You are not eligible to apply for this job, as it requires a minimum CGPA of 9.0'
  },
  {
    id: 'JOB003',
    company: 'Reliance Industries',
    companyInitial: 'R',
    companyColor: '#CC0000',
    logo: '',
    title: 'Data Scientist',
    industry: 'Manufacturing & Engineering',
    companyType: 'Corporate',
    location: ['Bangalore'],
    salary: { min: 1000000, max: 1200000, currency: '₹' },
    category: 'Super Dream',
    skillsMatch: 5,
    skillsTotal: 5,
    tags: ['Corporate', 'Energy'],
    description: 'Reliance Industries is looking for a Data Scientist to join our analytics team.',
    keyResponsibilities: ['Build ML models', 'Analyze large datasets', 'Present insights to stakeholders'],
    applicationProcess: [
      { id: 'AP1', stage: 'Initial Screening', date: '7th Oct, 2026' },
      { id: 'AP2', stage: 'Technical Interview', date: '12th Oct, 2026' },
      { id: 'AP3', stage: 'Aptitude Test', date: '16th Oct, 2026' },
      { id: 'AP4', stage: 'Leadership Round', date: '20th Oct, 2026' },
      { id: 'AP5', stage: 'HR Interview', date: '24th Oct, 2026' }
    ],
    applicationCloseDate: '08 Oct, 2026',
    alumniCount: 22,
    website: 'https://www.ril.com',
    isSaved: false
  },
  {
    id: 'JOB004',
    company: 'Google',
    companyInitial: 'G',
    companyColor: '#4285F4',
    logo: '',
    title: 'Product Designer',
    industry: 'Information Technology',
    companyType: 'Corporate',
    location: ['Remote', 'Bangalore'],
    salary: { min: 1500000, max: 2000000, currency: '₹' },
    category: 'Super Dream',
    skillsMatch: 4,
    skillsTotal: 5,
    tags: ['Remote', 'Corporate', 'Tech'],
    description: 'Design products used by billions of people worldwide.',
    keyResponsibilities: ['Lead product design initiatives', 'Collaborate with PM and Engineering', 'Design and prototype new features'],
    applicationProcess: [
      { id: 'AP1', stage: 'Portfolio Review', date: '5th Oct, 2026' },
      { id: 'AP2', stage: 'Design Challenge', date: '10th Oct, 2026' },
      { id: 'AP3', stage: 'Technical Interview', date: '15th Oct, 2026' },
      { id: 'AP4', stage: 'Leadership Round', date: '20th Oct, 2026' },
      { id: 'AP5', stage: 'HR Interview', date: '25th Oct, 2026' }
    ],
    applicationCloseDate: '03 Oct, 2026',
    alumniCount: 5,
    website: 'https://www.google.com',
    isSaved: true
  },
  {
    id: 'JOB005',
    company: 'Tata Consultancy Services',
    companyInitial: 'T',
    companyColor: '#002D62',
    logo: '',
    title: 'UX/UI Designer',
    industry: 'Information Technology',
    companyType: 'Corporate',
    location: ['Chennai'],
    salary: { min: 400000, max: 600000, currency: '₹' },
    category: 'Regular',
    skillsMatch: 3,
    skillsTotal: 5,
    tags: ['Corporate', 'IT Services'],
    description: 'Design exceptional user experiences for enterprise software.',
    keyResponsibilities: ['Create wireframes and prototypes', 'Conduct user research', 'Define UX guidelines'],
    applicationProcess: [
      { id: 'AP1', stage: 'Portfolio Review', date: '8th Oct, 2026' },
      { id: 'AP2', stage: 'Design Test', date: '14th Oct, 2026' },
      { id: 'AP3', stage: 'Technical Interview', date: '18th Oct, 2026' },
      { id: 'AP4', stage: 'HR Interview', date: '22nd Oct, 2026' }
    ],
    applicationCloseDate: '05 Oct, 2026',
    alumniCount: 15,
    website: 'https://www.tcs.com',
    isSaved: false
  },
  {
    id: 'JOB006',
    company: 'Infosys',
    companyInitial: 'I',
    companyColor: '#007CC3',
    logo: '',
    title: 'UX Designer',
    industry: 'Information Technology',
    companyType: 'Corporate',
    location: ['Bangalore', 'Hyderabad'],
    salary: { min: 450000, max: 650000, currency: '₹' },
    category: 'Regular',
    skillsMatch: 4,
    skillsTotal: 5,
    tags: ['Corporate', 'IT'],
    description: 'Shape the future of digital experiences at Infosys.',
    keyResponsibilities: ['Design user interfaces', 'Prototype and test designs', 'Collaborate with development teams'],
    applicationProcess: [
      { id: 'AP1', stage: 'Initial Screening', date: '6th Oct, 2026' },
      { id: 'AP2', stage: 'Design Test', date: '12th Oct, 2026' },
      { id: 'AP3', stage: 'Technical Interview', date: '18th Oct, 2026' },
      { id: 'AP4', stage: 'HR Interview', date: '23rd Oct, 2026' }
    ],
    applicationCloseDate: '04 Oct, 2026',
    alumniCount: 12,
    website: 'https://www.infosys.com',
    isSaved: false
  },
  {
    id: 'JOB007',
    company: 'Zoho Corporation',
    companyInitial: 'Z',
    companyColor: '#E42527',
    logo: '',
    title: 'Product Designer',
    industry: 'Information Technology',
    companyType: 'Startup',
    location: ['Chennai', 'Remote'],
    salary: { min: 600000, max: 900000, currency: '₹' },
    category: 'Dream',
    skillsMatch: 5,
    skillsTotal: 5,
    tags: ['Startup', 'SaaS'],
    description: 'Build next-generation SaaS products at Zoho.',
    keyResponsibilities: ['Lead product design', 'Conduct design reviews', 'Build design systems'],
    applicationProcess: [
      { id: 'AP1', stage: 'Initial Screening', date: '9th Oct, 2026' },
      { id: 'AP2', stage: 'Aptitude Test', date: '13th Oct, 2026' },
      { id: 'AP3', stage: 'Technical Interview', date: '17th Oct, 2026' },
      { id: 'AP4', stage: 'HR Interview', date: '22nd Oct, 2026' }
    ],
    applicationCloseDate: '07 Oct, 2026',
    alumniCount: 7,
    website: 'https://www.zoho.com',
    isSaved: false
  },
  {
    id: 'JOB008',
    company: 'Razorpay',
    companyInitial: 'R',
    companyColor: '#072654',
    logo: '',
    title: 'Junior Designer',
    industry: 'Fintech',
    companyType: 'Startup',
    location: ['Bangalore'],
    salary: { min: 500000, max: 700000, currency: '₹' },
    category: 'Super Dream',
    skillsMatch: 4,
    skillsTotal: 5,
    tags: ['Startup', 'Fintech'],
    description: 'Join Razorpay and help design the future of payments.',
    keyResponsibilities: ['Design payment flows', 'Build design components', 'Collaborate cross-functionally'],
    applicationProcess: [
      { id: 'AP1', stage: 'Initial Screening', date: '8th Oct, 2026' },
      { id: 'AP2', stage: 'Design Challenge', date: '14th Oct, 2026' },
      { id: 'AP3', stage: 'Technical Interview', date: '19th Oct, 2026' },
      { id: 'AP4', stage: 'HR Interview', date: '24th Oct, 2026' }
    ],
    applicationCloseDate: '06 Oct, 2026',
    alumniCount: 4,
    website: 'https://www.razorpay.com',
    isSaved: false
  }
];

export const applications = [
  {
    id: 'APP001',
    jobId: 'JOB001',
    company: 'Google',
    companyInitial: 'G',
    companyColor: '#4285F4',
    profile: 'Associate UX/UI Designer',
    appliedDate: '31 Oct, 2026',
    category: 'Dream',
    currentStage: 'HR Interview',
    status: 'shortlisted',
    statusLabel: 'HR Interview',
    canBookSlot: true,
    canWithdraw: true,
    stages: [
      { id: 's1', name: 'Initial Screening', date: '7th Oct, 2026', status: 'completed' },
      { id: 's2', name: 'Technical Interview', date: '12th Oct, 2026', status: 'active' },
      { id: 's3', name: 'Aptitude Test', date: '16th Oct, 2026', status: 'upcoming' },
      { id: 's4', name: 'Leadership Round', date: '20th Oct, 2026', status: 'upcoming' },
      { id: 's5', name: 'HR Interview', date: '24th Oct, 2026', status: 'upcoming' }
    ],
    offer: null
  },
  {
    id: 'APP002',
    jobId: 'JOB005',
    company: 'Tata Consultancy Services',
    companyInitial: 'T',
    companyColor: '#002D62',
    profile: 'UX/UI Designer',
    appliedDate: '31 Oct, 2026',
    category: 'Regular',
    currentStage: 'Advanced to Interviews',
    status: 'advanced',
    statusLabel: 'Advanced to Interviews',
    canBookSlot: true,
    canWithdraw: true,
    stages: [
      { id: 's1', name: 'Initial Screening', date: '7th Oct, 2026', status: 'completed' },
      { id: 's2', name: 'Technical Interview', date: '12th Oct, 2026', status: 'active' },
      { id: 's3', name: 'Aptitude Test', date: '16th Oct, 2026', status: 'upcoming' },
      { id: 's4', name: 'Leadership Round', date: '20th Oct, 2026', status: 'upcoming' },
      { id: 's5', name: 'HR Interview', date: '24th Oct, 2026', status: 'upcoming' }
    ],
    offer: null
  },
  {
    id: 'APP003',
    jobId: 'JOB006',
    company: 'Infosys',
    companyInitial: 'I',
    companyColor: '#007CC3',
    profile: 'UX Designer',
    appliedDate: '31 Oct, 2026',
    category: 'Regular',
    currentStage: 'Initial Screening',
    status: 'rejected',
    statusLabel: 'Rejected',
    canBookSlot: false,
    canWithdraw: false,
    stages: [
      { id: 's1', name: 'Initial Screening', date: '7th Oct, 2026', status: 'rejected' },
      { id: 's2', name: 'Technical Interview', date: '12th Oct, 2026', status: 'upcoming' },
      { id: 's3', name: 'Aptitude Test', date: '16th Oct, 2026', status: 'upcoming' },
      { id: 's4', name: 'Leadership Round', date: '20th Oct, 2026', status: 'upcoming' },
      { id: 's5', name: 'HR Interview', date: '24th Oct, 2026', status: 'upcoming' }
    ],
    offer: null
  },
  {
    id: 'APP004',
    jobId: 'JOB007',
    company: 'Zoho Corporation',
    companyInitial: 'Z',
    companyColor: '#E42527',
    profile: 'Product Designer',
    appliedDate: '31 Oct, 2026',
    category: 'Dream',
    currentStage: 'In Review',
    status: 'inReview',
    statusLabel: 'In Review',
    canBookSlot: false,
    canWithdraw: false,
    stages: [
      { id: 's1', name: 'Initial Screening', date: '7th Oct, 2026', status: 'completed' },
      { id: 's2', name: 'Technical Interview', date: '12th Oct, 2026', status: 'upcoming' },
      { id: 's3', name: 'Aptitude Test', date: '16th Oct, 2026', status: 'upcoming' },
      { id: 's4', name: 'Leadership Round', date: '20th Oct, 2026', status: 'upcoming' },
      { id: 's5', name: 'HR Interview', date: '24th Oct, 2026', status: 'upcoming' }
    ],
    offer: null
  },
  {
    id: 'APP005',
    jobId: 'JOB008',
    company: 'Razorpay',
    companyInitial: 'R',
    companyColor: '#072654',
    profile: 'Junior Designer',
    appliedDate: '31 Sept, 2026',
    category: 'Super Dream',
    currentStage: 'Job Offer Review',
    status: 'offerReceived',
    statusLabel: 'Job Offer Review',
    canBookSlot: false,
    canWithdraw: false,
    stages: [
      { id: 's1', name: 'Initial Screening', date: '7th Oct, 2026', status: 'completed' },
      { id: 's2', name: 'Technical Interview', date: '12th Oct, 2026', status: 'completed' },
      { id: 's3', name: 'Aptitude Test', date: '16th Oct, 2026', status: 'completed' },
      { id: 's4', name: 'Leadership Round', date: '20th Oct, 2026', status: 'completed' },
      { id: 's5', name: 'HR Interview', date: '24th Oct, 2026', status: 'completed' }
    ],
    offer: {
      ctc: 800000,
      fixed: 400000,
      variable: 100000,
      bonus: 300000,
      joiningDate: 'Jan 01, 2026',
      bond: '2 years',
      deadline: 'Nov 15, 2026',
      perks: ['Health Insurance for family', 'Stock options (ESOPs)', 'Flexible working hours'],
      type: 'Super Dream',
      alumniWorking: 15,
      growthText: 'High growth potential with clear promotion path'
    }
  }
];

export const savedJobs = ['JOB002', 'JOB004'];

export const placementSummary = {
  activeApplications: 3,
  offersReceived: 1,
  interviewsScheduled: 2,
  examsScheduled: 1
};

export const resumes = [
  { id: 'RES001', filename: 'Resume_compressed.pdf', lastUsed: '12 Oct 2026', templateId: 'new-york' },
  { id: 'RES002', filename: 'Visual_designer.pdf', lastUsed: '08 Oct 2026', templateId: 'toronto' },
  { id: 'RES003', filename: 'UIUX_designer.pdf', lastUsed: '05 Oct 2026', templateId: 'new-york' }
];

export const prepResources = [
  {
    id: 'PR001',
    title: 'Training Includes Career Choice Upskilling',
    duration: '20 Mins Read',
    type: 'Training Material',
    category: 'Training Materials',
    tags: ['Data Structures', 'Sorting And Searching'],
    isNew: false,
    company: 'Google',
    companyInitial: 'G',
    companyColor: '#4285F4'
  },
  {
    id: 'PR002',
    title: 'Project Oxygen and O2O peer-Learning Focus',
    duration: '20 Mins Read',
    type: 'Certification Course',
    category: 'Training Materials',
    tags: ['Data Structures', 'Sorting And Searching', 'Memory Management'],
    isNew: true,
    company: 'Google',
    companyInitial: 'G',
    companyColor: '#4285F4'
  },
  {
    id: 'PR003',
    title: 'Offers Aspire for grade, Microsoft Learn, and Growth',
    duration: '2 Weeks',
    type: 'Certification Course',
    category: 'Training Materials',
    tags: ['Data Structures', 'Syntax And Semantics'],
    isNew: false,
    company: 'TCS',
    companyInitial: 'T',
    companyColor: '#002D62'
  },
  {
    id: 'PR004',
    title: 'R Level 1 - Data Analytics with R Learning Focus',
    duration: '20 Mins Read',
    type: 'Certification Course',
    category: 'Aptitude Tests',
    tags: ['Data Visualization', 'Data Bridging', 'R Programming'],
    isNew: true,
    company: 'Meta',
    companyInitial: 'M',
    companyColor: '#1877F2'
  },
  {
    id: 'PR005',
    title: 'Logical Reasoning Practice Test',
    duration: '20 Mins Read',
    type: 'Training Material',
    category: 'Aptitude Tests',
    tags: ['Data Structures', 'Syntax And Semantics', 'Memory Management'],
    isNew: false,
    company: 'IBM',
    companyInitial: 'I',
    companyColor: '#006699'
  },
  {
    id: 'PR006',
    title: 'Common Interview Questions & Answers',
    duration: '20 Mins Read',
    type: 'Certification Course',
    category: 'Interview Tips',
    tags: ['Active Listening', 'Presentation Skills', 'Syntax & Non-Verbal Communication'],
    isNew: false,
    company: 'Infosys',
    companyInitial: 'I',
    companyColor: '#007CC3'
  },
  {
    id: 'PR007',
    title: 'Mastering Workplace Communication',
    duration: '20 Mins Read',
    type: 'Certification Course',
    category: 'Interview Tips',
    tags: ['Active Listening', 'Presentation Skills'],
    isNew: false,
    company: 'Wipro',
    companyInitial: 'W',
    companyColor: '#9D2235'
  },
  {
    id: 'PR008',
    title: 'Behavioral Interview Mastery',
    duration: '30 Mins Read',
    type: 'Training Material',
    category: 'Interview Tips',
    tags: ['STAR Method', 'Communication'],
    isNew: false,
    company: 'TCS',
    companyInitial: 'T',
    companyColor: '#002D62'
  }
];

export const mockInterviews = [
  {
    id: 'MI001',
    company: 'Google',
    companyInitial: 'G',
    companyColor: '#4285F4',
    role: 'Product Design',
    duration: '30 min',
    attempts: 2,
    maxAttempts: 3
  },
  {
    id: 'MI002',
    company: 'Netflix',
    companyInitial: 'N',
    companyColor: '#E50914',
    role: 'Platform Engineer',
    duration: '45 min',
    attempts: 0,
    maxAttempts: 3
  },
  {
    id: 'MI003',
    company: 'IBM',
    companyInitial: 'I',
    companyColor: '#0062FF',
    role: 'Product Consulting',
    duration: '30 min',
    attempts: 1,
    maxAttempts: 3
  },
  {
    id: 'MI004',
    company: 'Google',
    companyInitial: 'G',
    companyColor: '#4285F4',
    role: 'Student Design',
    duration: '20 min',
    attempts: 0,
    maxAttempts: 3
  }
];

export const careerCompassQuestions = [
  {
    id: 'CCQ01',
    number: 1,
    question: 'What type of work environment do you thrive in?',
    options: [
      { id: 'a', label: 'A', text: 'Office with a structured schedule' },
      { id: 'b', label: 'B', text: 'Flexible work hours with remote options' },
      { id: 'c', label: 'C', text: 'Hands-on work in a dynamic, fast-paced setting' },
      { id: 'd', label: 'D', text: 'Independent work with minimal supervision' }
    ]
  },
  {
    id: 'CCQ02',
    number: 2,
    question: 'How do you prefer to work on projects?',
    options: [
      { id: 'a', label: 'A', text: 'Collaborating with a team to brainstorm ideas' },
      { id: 'b', label: 'B', text: 'Working solo and making decisions on my own' },
      { id: 'c', label: 'C', text: 'Coordinating between multiple departments and teams' },
      { id: 'd', label: 'D', text: 'Organising tasks and delegating responsibilities' }
    ]
  },
  {
    id: 'CCQ03',
    number: 3,
    question: 'How do you feel about solving complex problems?',
    options: [
      { id: 'a', label: 'A', text: 'I love challenges and enjoy finding solutions' },
      { id: 'b', label: 'B', text: 'I prefer simple tasks that are easy to manage' },
      { id: 'c', label: 'C', text: 'I like working on abstract ideas and brainstorming' },
      { id: 'd', label: 'D', text: 'I prefer routine tasks without too much problem-solving' }
    ]
  },
  {
    id: 'CCQ04',
    number: 4,
    question: 'Which of the following statements best describes your communication style?',
    options: [
      { id: 'a', label: 'A', text: 'I prefer written communication' },
      { id: 'b', label: 'B', text: 'I enjoy speaking with people face-to-face or on the phone' },
      { id: 'c', label: 'C', text: 'I prefer a mix of both verbal and written communication' },
      { id: 'd', label: 'D', text: 'I like working quietly and not interacting too much with others' }
    ]
  },
  {
    id: 'CCQ05',
    number: 5,
    question: 'What motivates you most in a job?',
    options: [
      { id: 'a', label: 'A', text: 'Opportunities for growth and advancement' },
      { id: 'b', label: 'B', text: 'Work-life balance and flexibility' },
      { id: 'c', label: 'C', text: 'Creativity and innovation' },
      { id: 'd', label: 'D', text: 'Stability and security' }
    ]
  },
  {
    id: 'CCQ06',
    number: 6,
    question: 'How do you handle stressful situations?',
    options: [
      { id: 'a', label: 'A', text: 'I stay calm and work through the issue methodically' },
      { id: 'b', label: 'B', text: 'I get anxious but eventually find a solution' },
      { id: 'c', label: 'C', text: 'I enjoy the challenge and thrive under pressure' },
      { id: 'd', label: 'D', text: 'I prefer to avoid stressful situations when possible' }
    ]
  },
  {
    id: 'CCQ07',
    number: 7,
    question: 'Which skill do you enjoy using the most?',
    options: [
      { id: 'a', label: 'A', text: 'Analytical and problem-solving skills' },
      { id: 'b', label: 'B', text: 'Creative and innovative thinking' },
      { id: 'c', label: 'C', text: 'Leadership and decision-making' },
      { id: 'd', label: 'D', text: 'Organisation and attention to detail' }
    ]
  },
  {
    id: 'CCQ08',
    number: 8,
    question: 'How do you feel about routine tasks?',
    options: [
      { id: 'a', label: 'A', text: 'I prefer having a structured routine' },
      { id: 'b', label: 'B', text: 'I enjoy a mix of routine and variety' },
      { id: 'c', label: 'C', text: 'I like to have a different challenge every day' },
      { id: 'd', label: 'D', text: 'I dislike doing repetitive tasks' }
    ]
  },
  {
    id: 'CCQ09',
    number: 9,
    question: 'What type of work would you like to do?',
    options: [
      { id: 'a', label: 'A', text: 'Managing and leading a team' },
      { id: 'b', label: 'B', text: 'Developing and implementing strategies' },
      { id: 'c', label: 'C', text: 'Creating new products or content' },
      { id: 'd', label: 'D', text: 'Providing support and assistance to others' }
    ]
  },
  {
    id: 'CCQ10',
    number: 10,
    question: 'What is your preferred method of learning?',
    options: [
      { id: 'a', label: 'A', text: 'Reading and absorbing information independently' },
      { id: 'b', label: 'B', text: 'Hands-on experience and trial-and-error' },
      { id: 'c', label: 'C', text: 'Learning through discussion and feedback' },
      { id: 'd', label: 'D', text: 'Structured training with guidance' }
    ]
  },
  {
    id: 'CCQ11',
    number: 11,
    question: 'How do you feel about technology in the workplace?',
    options: [
      { id: 'a', label: 'A', text: 'I enjoy using the latest technologies and tools' },
      { id: 'b', label: 'B', text: 'I like using tech but prefer less reliance on it' },
      { id: 'c', label: 'C', text: 'I enjoy tech for certain tasks but prefer human interaction' },
      { id: 'd', label: 'D', text: 'I\'m not very comfortable with new technology' }
    ]
  },
  {
    id: 'CCQ12',
    number: 12,
    question: 'What is your ideal level of responsibility?',
    options: [
      { id: 'a', label: 'A', text: 'Managing a large team or department' },
      { id: 'b', label: 'B', text: 'Leading smaller projects with clear goals' },
      { id: 'c', label: 'C', text: 'Contributing as part of a team or project' },
      { id: 'd', label: 'D', text: 'Focusing on personal tasks without much responsibility' }
    ]
  },
  {
    id: 'CCQ13',
    number: 13,
    question: 'What type of tasks do you prefer?',
    options: [
      { id: 'a', label: 'A', text: 'Strategy and long-term planning' },
      { id: 'b', label: 'B', text: 'Creative problem-solving and idea generation' },
      { id: 'c', label: 'C', text: 'Research and analysis of data' },
      { id: 'd', label: 'D', text: 'Execution and implementation of plans' }
    ]
  },
  {
    id: 'CCQ14',
    number: 14,
    question: 'How do you handle feedback?',
    options: [
      { id: 'a', label: 'A', text: 'I welcome feedback and use it to improve' },
      { id: 'b', label: 'B', text: 'I prefer constructive feedback in a one-on-one setting' },
      { id: 'c', label: 'C', text: 'I like feedback but only if it\'s relevant to my work' },
      { id: 'd', label: 'D', text: 'I find it hard to accept criticism' }
    ]
  },
  {
    id: 'CCQ15',
    number: 15,
    question: 'What kind of impact do you want to have through your work?',
    options: [
      { id: 'a', label: 'A', text: 'I want to drive change and influence others' },
      { id: 'b', label: 'B', text: 'I want to create something that lasts and benefits others' },
      { id: 'c', label: 'C', text: 'I want to provide practical support or solutions' },
      { id: 'd', label: 'D', text: 'I want to ensure things run smoothly and efficiently' }
    ]
  }
];

export const interviewResultData = {
  company: 'Google',
  role: 'Product Design',
  score: 78,
  badge: 'Mock Interview',
  summary: 'Impressive effort. You showcased strong communication and technical skills, with notable clarity in your responses. To further refine, consider working on time management and structuring answers for maximum impact. Keep up the great work and build on this momentum!',
  suggestions: [
    {
      id: 'S1',
      title: 'Lack of Specific Examples',
      text: 'To strengthen your answers, you would benefit from practicing presenting technical concepts in a clear and structured manner. Focusing on simplifying complex ideas for a non-technical audience.',
      bullets: [
        'Lack of Specific Examples: you would benefit from practicing presenting technical concepts in a clear and structured manner.',
        'Engaging in more interviews or public speaking exercises could also help build confidence and improve articulation skills.'
      ]
    },
    {
      id: 'S2',
      title: 'Lack of Emphasis of Teamwork',
      bullets: [
        'Consider highlighting instances where teamwork played a crucial role in achieving goals or solving problems.',
        'This could include group projects, team storms, volunteer work, or professional collaborations.',
        'Mentioning successful teamwork experiences can make you more relatable to interviewers.'
      ]
    }
  ],
  suggestedLessons: [
    {
      id: 'L1',
      title: 'Mastering Behavioral Interview Techniques',
      duration: '40 Mins',
      type: 'Training Material',
      tags: ['Data Analysis', 'Machine Learning', 'Artificial Intelligence']
    },
    {
      id: 'L2',
      title: 'Effective Communication for Job Interviews',
      duration: '40 Mins',
      type: 'Training Material',
      tags: ['Cyber Security', 'Network Security', 'Data Protection']
    }
  ]
};

export const offerComparisons = [
  {
    id: 'OC1',
    jobId: 'JOB001',
    company: 'Developer',
    companyName: 'Paypal',
    companyInitial: 'P',
    companyColor: '#003087',
    category: 'Super Dream',
    ctc: 800000,
    fixed: 400000,
    variable: 100000,
    bonus: 300000,
    location: 'Remote',
    companyType: 'Startup',
    growthText: 'High growth potential with clear promotion path',
    alumniCount: 15,
    perks: ['Health Insurance for family', 'Stock options (ESOPs)', 'Flexible working hours'],
    joiningDate: 'Jan 01, 2026',
    bond: '2 years',
    deadline: 'Nov 15, 2026',
    selected: true
  },
  {
    id: 'OC2',
    jobId: 'JOB002',
    company: 'Software Engineer',
    companyName: 'Hindustan Unilever',
    companyInitial: 'U',
    companyColor: '#1F5EE0',
    category: 'Dream',
    ctc: 620000,
    fixed: 420000,
    variable: 150000,
    bonus: 50000,
    location: 'Remote',
    companyType: 'Corporate',
    growthText: 'Rapid growth with equity upside potential',
    alumniCount: 8,
    perks: ['Premium health Insurance', 'Significant equity package', 'Unlimited PTO'],
    joiningDate: 'Dec 03, 2026',
    bond: 'No Bond',
    deadline: 'Nov 11, 2026',
    selected: true
  },
  {
    id: 'OC3',
    jobId: 'JOB003',
    company: 'Data Scientist',
    companyName: 'Reliance Industries',
    companyInitial: 'R',
    companyColor: '#CC0000',
    category: 'Regular',
    ctc: 1000000,
    fixed: 600000,
    variable: 200000,
    bonus: 200000,
    location: 'Remote',
    companyType: 'Corporate',
    growthText: 'Steady growth with structured career progression',
    alumniCount: 22,
    perks: ['Comprehensive health coverage', 'Provident Fund', 'Annual performance bonus'],
    joiningDate: 'Jan 03, 2026',
    bond: '3 years',
    deadline: 'Nov 02, 2026',
    selected: true
  }
];

export const compareOffersData = {
  offers: [
    {
      id: 'OC1',
      company: 'Paypal',
      companyInitial: 'P',
      companyColor: '#003087',
      role: 'Developer',
      category: 'Dream',
      categoryClass: 'cat-badge cat-dream',
      salary: { amount: 800000, currency: '₹' },
      perks: ['Health Insurance', 'Stock Options (ESOPs)', 'Flexible Hours'],
      comparison: {
        ctc: '₹ 8,00,000',
        fixed: '₹ 4,00,000',
        variable: '₹ 1,00,000',
        bonus: '₹ 3,00,000',
        location: 'Remote',
        joiningDate: 'Jan 01, 2026',
        bond: '2 Years',
        type: 'Startup'
      }
    },
    {
      id: 'OC2',
      company: 'Hindustan Unilever',
      companyInitial: 'U',
      companyColor: '#1F5EE0',
      role: 'Software Engineer',
      category: 'Super Dream',
      categoryClass: 'cat-badge cat-super-dream',
      salary: { amount: 620000, currency: '₹' },
      perks: ['Premium Health Insurance', 'Equity Package', 'Unlimited PTO'],
      comparison: {
        ctc: '₹ 6,20,000',
        fixed: '₹ 4,20,000',
        variable: '₹ 1,50,000',
        bonus: '₹ 50,000',
        location: 'Remote, Chennai',
        joiningDate: 'Dec 03, 2026',
        bond: 'No Bond',
        type: 'Corporate'
      }
    },
    {
      id: 'OC3',
      company: 'Reliance Industries',
      companyInitial: 'R',
      companyColor: '#CC0000',
      role: 'Data Scientist',
      category: 'Regular',
      categoryClass: 'cat-badge cat-regular',
      salary: { amount: 1000000, currency: '₹' },
      perks: ['Health Coverage', 'Provident Fund', 'Annual Bonus'],
      comparison: {
        ctc: '₹ 10,00,000',
        fixed: '₹ 6,00,000',
        variable: '₹ 2,00,000',
        bonus: '₹ 2,00,000',
        location: 'Bangalore',
        joiningDate: 'Jan 03, 2026',
        bond: '3 Years',
        type: 'Corporate'
      }
    }
  ],
  comparisonKeys: [
    { id: 'ctc', label: 'Total CTC' },
    { id: 'fixed', label: 'Fixed Component' },
    { id: 'variable', label: 'Variable Pay' },
    { id: 'bonus', label: 'Joining Bonus' },
    { id: 'location', label: 'Work Location' },
    { id: 'joiningDate', label: 'Joining Date' },
    { id: 'bond', label: 'Bond Period' },
    { id: 'type', label: 'Company Type' }
  ]
};

export const placementInstructions = {
  beforeOptIn: [
    'Review the placement cycle dates and ensure you are eligible to participate.',
    'Your CGPA must meet the minimum requirement of 7.0 to be eligible.',
    'You can only opt into one placement cycle at a time.',
    'Once opted in, you will have access to all job listings and placement resources.'
  ],
  policiesToNote: [
    { title: 'Dream Offer Policy', text: 'Accepting a Dream Offer will restrict you from applying to other jobs.' },
    { title: 'Super Dream Policy', text: 'Accepting a Super Dream Offer will close all other applications immediately.' },
    { title: 'Withdrawal Policy', text: 'Withdrawing from a job after shortlisting may affect your placement eligibility.' }
  ],
  nextSteps: [
    'Record your response to opt into the placement cycle.',
    'Set up your job preferences for better recommendations.',
    'Upload your latest resume to the Resume Library.',
    'Explore Career Compass to identify the best-fit career paths.'
  ]
};