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
public without sharing class KenAttendanceController {

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
            Id studentId = KenRunningStudentHelper.optionalContactId();
            List<AttendanceRowDTO> rows = (studentId == null)
                ? new List<AttendanceRowDTO>()
                : queryAttendanceRollup(studentId);
            if (rows == null) rows = new List<AttendanceRowDTO>();
            b.subjects = rows;
            Decimal sum = 0; Integer atRisk = 0;
            for (AttendanceRowDTO r : rows) {
                sum += r.percentage;
                if (r.isAtRisk) atRisk++;
            }
            b.overallPercentage = (rows.isEmpty()) ? 0 : (sum / rows.size()).setScale(1);
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

    /**
     * Aggregates Attendance__c rows into per-subject rollups for the running
     * student. Risk threshold matches the seed: <75% = at risk.
     */
    private static List<AttendanceRowDTO> queryAttendanceRollup(Id studentId) {
        // Aggregate by subject + code: total sessions, attended (Is_Present__c = true).
        List<Attendance__c> all = [
            SELECT Subject__c, Subject_Code__c, Is_Present__c
            FROM Attendance__c
            WHERE Student__c = :studentId
            WITH SECURITY_ENFORCED
            LIMIT 5000
        ];
        if (all.isEmpty()) return new List<AttendanceRowDTO>();

        Map<String, Integer[]> rollup = new Map<String, Integer[]>(); // key -> [attended, total]
        Map<String, String[]>  meta   = new Map<String, String[]>();  // key -> [subject, code]
        for (Attendance__c a : all) {
            String subj = String.isBlank(a.Subject__c) ? '(Unknown)' : a.Subject__c;
            String code = String.isBlank(a.Subject_Code__c) ? '' : a.Subject_Code__c;
            String key  = subj + '|' + code;
            if (!rollup.containsKey(key)) {
                rollup.put(key, new Integer[]{ 0, 0 });
                meta.put(key, new String[]{ subj, code });
            }
            Integer[] counts = rollup.get(key);
            counts[1] += 1;                                  // total
            if (a.Is_Present__c == true) counts[0] += 1;     // attended
        }

        List<AttendanceRowDTO> out = new List<AttendanceRowDTO>();
        Integer idx = 0;
        for (String key : rollup.keySet()) {
            Integer[] c = rollup.get(key);
            String[] m = meta.get(key);
            Integer attended = c[0];
            Integer total    = c[1];
            Decimal pct = (total == 0) ? 0 : ((Decimal) attended * 100 / total).setScale(1);
            AttendanceRowDTO r = new AttendanceRowDTO();
            r.id              = 'AR-' + (++idx);
            r.subject         = m[0];
            r.code            = m[1];
            r.attendedClasses = attended;
            r.totalClasses    = total;
            r.percentage      = pct;
            r.isAtRisk        = pct < 75;
            out.add(r);
        }
        return out;
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
                    WITH SECURITY_ENFORCED LIMIT 1
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
        if (studentId == null) return out;
        try {
            for (Leave_Request__c r : [
                SELECT Id, Title__c, Type__c, Status__c, From_Date__c, To_Date__c, Reason__c
                FROM Leave_Request__c
                WHERE Student__c = :studentId
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT 25
            ]) out.add(mapLeaveRequest(r));
        } catch (Exception ignore) { /* object/perms missing — fall through */ }
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

}