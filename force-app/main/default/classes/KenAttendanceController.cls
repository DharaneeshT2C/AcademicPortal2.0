/**
 * ************************************************************************************************
 * @className  KenAttendanceController
 *
 * @description
 *  Backs the `my/attendance` LWC page. Returns subject-wise attendance
 *  percentages, at-risk warnings, and overall totals for the running student.
 *
 *  TODO[SOBJECT]: Wire to `Attendance__c` (Student__c, Course__c, Session_Date__c,
 *                 Is_Present__c) with aggregated SOQL. Until then returns the
 *                 mock-data snapshot.
 *
 * @author      Student Portal Backend
 * @createdOn   2026
 * ************************************************************************************************
 */
public with sharing class KenAttendanceController {

    public class AttendanceRowDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  subject;
        @AuraEnabled public String  code;
        @AuraEnabled public Decimal percentage;
        @AuraEnabled public Integer totalClasses;
        @AuraEnabled public Integer attendedClasses;
        @AuraEnabled public Boolean isAtRisk;
    }

    public class LeaveRequestDTO {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  title;
        @AuraEnabled public String  leaveType;
        @AuraEnabled public String  status;
        @AuraEnabled public Date    fromDate;
        @AuraEnabled public Date    toDate;
        @AuraEnabled public String  dates;
        @AuraEnabled public String  reason;
    }

    public class AttendanceBundleDTO {
        @AuraEnabled public Decimal                overallPercentage;
        @AuraEnabled public Integer                subjectsAtRisk;
        @AuraEnabled public List<AttendanceRowDTO> subjects;
        @AuraEnabled public List<LeaveRequestDTO>  leaveRequests;
    }

    @AuraEnabled(cacheable=true)
    public static AttendanceBundleDTO getAttendanceBundle() {
        try {
            AttendanceBundleDTO b = new AttendanceBundleDTO();
            b.subjects = seedAttendance();
            Decimal sum = 0; Integer atRisk = 0;
            for (AttendanceRowDTO r : b.subjects) {
                sum += r.percentage;
                if (r.isAtRisk) atRisk++;
            }
            b.overallPercentage = sum / b.subjects.size();
            b.subjectsAtRisk    = atRisk;
            b.leaveRequests     = queryLeaveRequests();
            return b;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled(
                'KenAttendanceController.getAttendanceBundle',
                'Unable to load attendance.',
                e
            );
            return null;
        }
    }

    @AuraEnabled
    public static LeaveRequestDTO submitLeaveRequest(String title, String leaveType,
                                                     Date fromDate, Date toDate, String reason) {
        try {
            KenAuraExceptionHelper.rejectIf(String.isBlank(title), 'Please enter a title.');
            KenAuraExceptionHelper.rejectIf(fromDate == null,   'From date is required.');
            KenAuraExceptionHelper.rejectIf(toDate   == null,   'To date is required.');
            KenAuraExceptionHelper.rejectIf(toDate < fromDate,  'To date must be on or after the from date.');

            Id studentId = KenRunningStudentHelper.optionalContactId();
            // Idempotency: prevent rapid double-submit creating duplicate
            // pending requests with identical title + dates.
            if (studentId != null) {
                List<Leave_Request__c> dupes = [
                    SELECT Id FROM Leave_Request__c
                    WHERE Student__c = :studentId
                      AND Title__c = :title
                      AND From_Date__c = :fromDate
                      AND To_Date__c = :toDate
                      AND Status__c = 'In Review'
                    WITH USER_MODE LIMIT 1
                ];
                if (!dupes.isEmpty()) {
                    return mapLeaveRequest([
                        SELECT Id, Title__c, Type__c, Status__c, From_Date__c, To_Date__c, Reason__c
                        FROM Leave_Request__c WHERE Id = :dupes[0].Id LIMIT 1
                    ]);
                }
            }
            KenCrudFlsHelper.assertCreateable(Leave_Request__c.SObjectType);

            Leave_Request__c lr = new Leave_Request__c(
                Student__c   = studentId,
                Title__c     = title,
                Type__c      = String.isBlank(leaveType) ? 'Personal leave' : leaveType,
                From_Date__c = fromDate,
                To_Date__c   = toDate,
                Reason__c    = reason == null ? null : reason.left(1000),
                Status__c    = 'In Review'
            );
            insert lr;

            if (studentId != null && Schema.SObjectType.Student_Notification__c.isCreateable()) {
                insert new Student_Notification__c(
                    Student__c  = studentId,
                    Title__c    = 'Leave request submitted',
                    Body__c     = title + ' (' + formatDates(fromDate, toDate) + ') is now in review.',
                    Category__c = 'System',
                    Is_Read__c  = false
                );
            }
            return mapLeaveRequest([
                SELECT Id, Title__c, Type__c, Status__c, From_Date__c, To_Date__c, Reason__c
                FROM Leave_Request__c WHERE Id = :lr.Id LIMIT 1
            ]);
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled(
                'KenAttendanceController.submitLeaveRequest',
                'Could not submit your leave request. Please try again.',
                e
            );
            return null;
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<LeaveRequestDTO> getLeaveRequests() {
        try { return queryLeaveRequests(); }
        catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenAttendanceController.getLeaveRequests',
                'Unable to load leave requests.', e);
            return new List<LeaveRequestDTO>();
        }
    }

    private static List<LeaveRequestDTO> queryLeaveRequests() {
        List<LeaveRequestDTO> out = new List<LeaveRequestDTO>();
        Id studentId = KenRunningStudentHelper.optionalContactId();
        if (studentId == null) return seedLeaveRequests();
        try {
            for (Leave_Request__c r : [
                SELECT Id, Title__c, Type__c, Status__c, From_Date__c, To_Date__c, Reason__c
                FROM Leave_Request__c
                WHERE Student__c = :studentId
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 25
            ]) out.add(mapLeaveRequest(r));
        } catch (Exception ignore) { /* object/perms missing — fall through */ }
        if (out.isEmpty()) out = seedLeaveRequests();
        return out;
    }

    private static LeaveRequestDTO mapLeaveRequest(Leave_Request__c r) {
        LeaveRequestDTO d = new LeaveRequestDTO();
        d.id        = r.Id;
        d.title     = r.Title__c;
        d.leaveType = r.Type__c;
        d.status    = r.Status__c;
        d.fromDate  = r.From_Date__c;
        d.toDate    = r.To_Date__c;
        d.dates     = formatDates(r.From_Date__c, r.To_Date__c);
        d.reason    = r.Reason__c;
        return d;
    }

    private static List<LeaveRequestDTO> seedLeaveRequests() {
        List<LeaveRequestDTO> out = new List<LeaveRequestDTO>();
        out.add(seedLeave('Going for a vacation',     'Personal leave',  'Approved',  Date.newInstance(2026, 12, 21), Date.newInstance(2026, 12, 26)));
        out.add(seedLeave('24th sports day practice', 'Exception',       'In Review', Date.newInstance(2026, 1, 2),  Date.newInstance(2026, 1, 2)));
        out.add(seedLeave('Annual day - final rehearsal', 'Personal leave', 'Rejected', Date.newInstance(2026, 1, 5), Date.newInstance(2026, 1, 5)));
        return out;
    }

    private static LeaveRequestDTO seedLeave(String title, String leaveType, String status, Date frm, Date tod) {
        LeaveRequestDTO d = new LeaveRequestDTO();
        d.title = title; d.leaveType = leaveType; d.status = status;
        d.fromDate = frm; d.toDate = tod; d.dates = formatDates(frm, tod);
        return d;
    }

    private static String formatDates(Date frm, Date tod) {
        if (frm == null && tod == null) return '';
        Datetime f = frm != null ? Datetime.newInstance(frm, Time.newInstance(0,0,0,0)) : null;
        Datetime t = tod != null ? Datetime.newInstance(tod, Time.newInstance(0,0,0,0)) : null;
        if (frm != null && tod != null && frm == tod) return f.format('d MMM yyyy');
        if (frm != null && tod != null) {
            // Same month optimisation -> "21 - 26 Dec 2026"
            if (frm.year() == tod.year() && frm.month() == tod.month()) {
                return frm.day() + ' - ' + tod.day() + ' ' + t.format('MMM yyyy');
            }
            return f.format('d MMM') + ' - ' + t.format('d MMM yyyy');
        }
        return f != null ? f.format('d MMM yyyy') : t.format('d MMM yyyy');
    }

    @AuraEnabled
    public static void raiseAttendanceDispute(Id subjectId, String reason) {
        try {
            KenAuraExceptionHelper.rejectIf(subjectId == null, 'Subject is required.');
            KenAuraExceptionHelper.rejectIf(String.isBlank(reason), 'A reason is required.');
            Id studentId = KenRunningStudentHelper.optionalContactId();
            KenCrudFlsHelper.assertCreateable(Attendance_Dispute__c.SObjectType);
            insert new Attendance_Dispute__c(
                Student__c      = studentId,
                Subject_Name__c = String.valueOf(subjectId),
                Reason__c       = reason,
                Status__c       = 'New'
            );
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled(
                'KenAttendanceController.raiseAttendanceDispute',
                'Could not submit your dispute. Please try again.',
                e
            );
        }
    }

    private static List<AttendanceRowDTO> seedAttendance() {
        List<AttendanceRowDTO> out = new List<AttendanceRowDTO>();
        out.add(row('A001', 'Data Structures',       'CS301', 88, 44, 50, false));
        out.add(row('A002', 'Operating Systems',     'CS302', 82, 41, 50, false));
        out.add(row('A003', 'Mathematics III',       'MA301', 68, 34, 50, true));
        out.add(row('A004', 'Soft Skills Workshop',  'SS101', 96, 48, 50, false));
        out.add(row('A005', 'Engineering Physics',   'PH301', 79, 40, 50, false));
        return out;
    }

    private static AttendanceRowDTO row(String id, String subj, String code, Decimal pct, Integer att, Integer tot, Boolean risk) {
        AttendanceRowDTO r = new AttendanceRowDTO();
        r.id = id; r.subject = subj; r.code = code; r.percentage = pct;
        r.attendedClasses = att; r.totalClasses = tot; r.isAtRisk = risk;
        return r;
    }
}