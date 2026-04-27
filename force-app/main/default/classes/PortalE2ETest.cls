@isTest
public class PortalE2ETest {
    @isTest static void runAllAsArjun() {
        User arjun = [SELECT Id FROM User WHERE Username = 'arjun.r@kenverse.portal.test' LIMIT 1];
        Map<String, String> results = new Map<String, String>();

        System.runAs(arjun) {
            // FEE
            try { Object r = KenFeePaymentController.getFeeSummary(); results.put('FeePayment.getFeeSummary', 'OK'); } catch (Exception e) { results.put('FeePayment.getFeeSummary', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenInvoicesController.getInvoices(); results.put('Invoices.getInvoices', 'OK'); } catch (Exception e) { results.put('Invoices.getInvoices', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenTransactionHistoryController.getTransactions(); results.put('Transactions.getTransactions', 'OK'); } catch (Exception e) { results.put('Transactions.getTransactions', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenFeePlanController.getPlans(); results.put('FeePlan.getPlans', 'OK'); } catch (Exception e) { results.put('FeePlan.getPlans', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenRefundsController.getRefunds(); results.put('Refunds.getRefunds', 'OK'); } catch (Exception e) { results.put('Refunds.getRefunds', 'FAIL: ' + e.getMessage().left(80)); }

            // ACADEMICS
            try { Object r = KenLearnController.getLearnBundle(); results.put('Learn.getLearnBundle', 'OK'); } catch (Exception e) { results.put('Learn.getLearnBundle', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenAttendanceController.getAttendanceBundle(); results.put('Attendance.getAttendanceBundle', 'OK'); } catch (Exception e) { results.put('Attendance.getAttendanceBundle', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenMyExamsController.getMyExams(); results.put('MyExams.getMyExams', 'OK'); } catch (Exception e) { results.put('MyExams.getMyExams', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenResultsController.getResultsBundle(); results.put('Results.getResultsBundle', 'OK'); } catch (Exception e) { results.put('Results.getResultsBundle', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenMarksBreakdownController.getAllBreakdowns(); results.put('MarksBreakdown.getAllBreakdowns', 'OK'); } catch (Exception e) { results.put('MarksBreakdown.getAllBreakdowns', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenResearchController.getResearchBundle(); results.put('Research.getResearchBundle', 'OK'); } catch (Exception e) { results.put('Research.getResearchBundle', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenThesisManagementController.getThesis(); results.put('Thesis.getThesis', 'OK'); } catch (Exception e) { results.put('Thesis.getThesis', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenScheduleController.getWeeklySchedule(); results.put('Schedule.getWeeklySchedule', 'OK'); } catch (Exception e) { results.put('Schedule.getWeeklySchedule', 'FAIL: ' + e.getMessage().left(80)); }

            // CAMPUS LIFE
            try { Object r = KenCampusLifeController.getCampusOverview(); results.put('CampusLife.getCampusOverview', 'OK'); } catch (Exception e) { results.put('CampusLife.getCampusOverview', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenClubsController.getClubs(null); results.put('Clubs.getClubs', 'OK'); } catch (Exception e) { results.put('Clubs.getClubs', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenEventsController.getEventsBundle(); results.put('Events.getEventsBundle', 'OK'); } catch (Exception e) { results.put('Events.getEventsBundle', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenGatePassController.getGatePasses(); results.put('GatePass.getGatePasses', 'OK'); } catch (Exception e) { results.put('GatePass.getGatePasses', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenHostelDetailsController.getHostelDetails(); results.put('Hostel.getHostelDetails', 'OK'); } catch (Exception e) { results.put('Hostel.getHostelDetails', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenMessMenuController.getWeeklyMenu(); results.put('MessMenu.getWeeklyMenu', 'OK'); } catch (Exception e) { results.put('MessMenu.getWeeklyMenu', 'FAIL: ' + e.getMessage().left(80)); }

            // DASHBOARD + OTHER
            try { Object r = KenHomeDashboardController.getDashboard('middle','placements','ken'); results.put('Dashboard.getDashboard', 'OK'); } catch (Exception e) { results.put('Dashboard.getDashboard', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenHomeDashboardController.getStudentHeader(); results.put('Dashboard.getStudentHeader', 'OK'); } catch (Exception e) { results.put('Dashboard.getStudentHeader', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenNotificationsController.getNotifications(); results.put('Notifications.getNotifications', 'OK'); } catch (Exception e) { results.put('Notifications.getNotifications', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenNotificationsController.getUnreadCount(); results.put('Notifications.getUnreadCount', 'OK'); } catch (Exception e) { results.put('Notifications.getUnreadCount', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenSettingsController.getProfile(); results.put('Settings.getProfile', 'OK'); } catch (Exception e) { results.put('Settings.getProfile', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenSettingsController.getNotificationPrefs(); results.put('Settings.getNotificationPrefs', 'OK'); } catch (Exception e) { results.put('Settings.getNotificationPrefs', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenFaqsController.getFaqs(); results.put('Faqs.getFaqs', 'OK'); } catch (Exception e) { results.put('Faqs.getFaqs', 'FAIL: ' + e.getMessage().left(80)); }
            try { Object r = KenServiceSupportController.getTickets(); results.put('Support.getTickets', 'OK'); } catch (Exception e) { results.put('Support.getTickets', 'FAIL: ' + e.getMessage().left(80)); }
        }
        for (String k : results.keySet()) System.debug('TEST: ' + k + ' => ' + results.get(k));
    }
}