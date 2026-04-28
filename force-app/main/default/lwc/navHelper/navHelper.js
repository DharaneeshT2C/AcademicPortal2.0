// Maps the legacy SPA route strings to Experience Builder named-page API names.
// Usage: import { pageNameForRoute } from 'c/navHelper';
//        this[NavigationMixin.Navigate]({ type: 'comm__namedPage', attributes: { name: pageNameForRoute(route) } });
const ROUTE_TO_PAGE = {
    'home':               'Home',
    'learn':              'learn__c',
    'attendance':         'attendance__c',
    'my-exams':           'my_exams__c',
    'exam-enrollment':    'exam_enrollment__c',
    'results':            'results__c',
    'semester-detail':    'semester_detail__c',
    'marks-breakdown':    'MarksBreakdown__c',
    'research':           'research__c',
    'thesis':             'thesis__c',
    'course-enrollment':  'course_enrollment__c',
    'program-selection':  'program_selection__c',
    'campus-life':        'campus_life__c',
    'clubs':              'clubs__c',
    'events':             'events__c',
    'hostel-details':     'hostel_details__c',
    'mess-menu':          'mess_menu__c',
    'gate-pass':          'gate_pass__c',
    'create-gate-pass':   'create_gate_pass__c',
    'schedule':           'schedule__c',
    'fee-payment':        'fee_payment__c',
    'fee-payment-detail': 'fee_payment_detail__c',
    'fee-plan':           'fee_plan__c',
    'invoices':           'invoices__c',
    'transactions':       'transaction_history__c',
    'transaction-history':'transaction_history__c',
    'refunds':            'refunds__c',
    'service-support':    'service_support__c',
    'faqs':               'faqs__c',
    'feedback':           'feedback__c',
    'notifications':      'notifications__c',
    'chat':               'chat__c',
    'settings':           'settings__c',
    'placements':         'placements__c',
    'mentors':            'mentors__c',
    'service-request':    'service_request__c',
    'login':              'login__c',
};

export function pageNameForRoute(route) {
    return ROUTE_TO_PAGE[route] || (route.replace(/-/g, '_') + '__c');
}