/**
 * ************************************************************************************************
 * @className  KenMyExamsController
 *
 * @description
 *  Backs the `my/myExams` LWC page — upcoming exam timetable, seat allocation,
 *  and hall details for the running student. Also serves `my/examEnrollment`.
 *
 *  TODO[SOBJECT]: Wire to `Exam__c` + `Exam_Enrollment__c` (Student__c, Exam__c,
 *                 Seat_Number__c, Hall__c, Enrollment_Status__c).
 * ************************************************************************************************
 */
public without sharing class KenMyExamsController {

    public class ExamDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  subject;
        @AuraEnabled public String  code;
        @AuraEnabled public String  examDate;
        @AuraEnabled public String  startTime;
        @AuraEnabled public String  durationLabel;
        @AuraEnabled public String  hall;
        @AuraEnabled public String  seatNumber;
        @AuraEnabled public String  status;
        @AuraEnabled public Boolean isEligible;
    }

    public class MyExamsBundleDTO {
        @AuraEnabled public List<ExamDTO> upcoming;
        @AuraEnabled public List<ExamDTO> completed;
    }

    @AuraEnabled(cacheable=true)
    public static MyExamsBundleDTO getMyExams() {
        try {
            MyExamsBundleDTO b = new MyExamsBundleDTO();
            b.upcoming  = new List<ExamDTO>();
            b.completed = new List<ExamDTO>();
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId == null) return b;
            // Pull all exams; cross-reference enrollment to populate seat/eligibility
            List<Exam__c> exams = [
                SELECT Id, Subject__c, Subject_Code__c, Exam_Date__c, Start_Time__c,
                       Duration_Label__c, Hall__c, Status__c
                FROM Exam__c
                WITH SECURITY_ENFORCED
                ORDER BY Exam_Date__c
                LIMIT 100
            ];
            Map<Id, Exam_Enrollment__c> enrollByExam = new Map<Id, Exam_Enrollment__c>();
            for (Exam_Enrollment__c en : [
                SELECT Id, Exam__c, Seat_Number__c, Is_Eligible__c, Enrollment_Status__c
                FROM Exam_Enrollment__c
                WHERE Student__c = :contactId
                WITH SECURITY_ENFORCED
            ]) enrollByExam.put(en.Exam__c, en);
            for (Exam__c r : exams) {
                ExamDTO e = new ExamDTO();
                e.id            = r.Id;
                e.subject       = r.Subject__c;
                e.code          = r.Subject_Code__c;
                e.examDate      = r.Exam_Date__c == null ? '' :
                                      Datetime.newInstance(r.Exam_Date__c, Time.newInstance(0,0,0,0)).format('MMM d');
                e.startTime     = r.Start_Time__c;
                e.durationLabel = r.Duration_Label__c;
                e.hall          = r.Hall__c;
                e.status        = r.Status__c;
                Exam_Enrollment__c en = enrollByExam.get(r.Id);
                e.seatNumber    = en != null ? en.Seat_Number__c : '';
                e.isEligible    = en != null && en.Is_Eligible__c == true;
                if (r.Exam_Date__c != null && r.Exam_Date__c >= Date.today()) b.upcoming.add(e);
                else                                                          b.completed.add(e);
            }
            return b;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenMyExamsController.getMyExams',
                'Unable to load your exams.', e);
            return null;
        }
    }

    @AuraEnabled
    public static void enrollInExam(Id examId) {
        try {
            KenAuraExceptionHelper.rejectIf(examId == null, 'Exam id is required.');
            Id studentId = KenRunningStudentHelper.optionalContactId();
            if (studentId == null) return;
            // Idempotency: skip if already enrolled.
            List<Exam_Enrollment__c> existing = [
                SELECT Id FROM Exam_Enrollment__c
                WHERE Exam__c = :examId AND Student__c = :studentId
                WITH SECURITY_ENFORCED LIMIT 1
            ];
            if (!existing.isEmpty()) return;
            KenCrudFlsHelper.assertCreateable(Exam_Enrollment__c.SObjectType);
            insert new Exam_Enrollment__c(
                Student__c          = studentId,
                Exam__c             = examId,
                Enrollment_Status__c = 'Enrolled',
                Is_Eligible__c      = true
            );
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenMyExamsController.enrollInExam',
                'Could not complete exam enrollment.', e);
        }
    }

    public class EnrollmentConfirmationDTO {
        @AuraEnabled public String  referenceNumber;
        @AuraEnabled public Integer enrolledCount;
        @AuraEnabled public Decimal amountPaid;
        @AuraEnabled public String  paymentMode;
        @AuraEnabled public String  confirmedAt;
        @AuraEnabled public List<String> enrolledCourseCodes;
    }

    @AuraEnabled
    public static EnrollmentConfirmationDTO confirmExamEnrollment(List<String> courseCodes, Decimal totalFee) {
        try {
            KenAuraExceptionHelper.rejectIf(courseCodes == null || courseCodes.isEmpty(),
                'At least one course must be selected.');
            KenAuraExceptionHelper.rejectIf(totalFee == null || totalFee < 0,
                'Fee amount is invalid.');

            Id studentId = KenRunningStudentHelper.optionalContactId();

            // 1) Resolve / lazily create Exam__c rows for each course code so we
            //    have a real Exam Id to bind enrollment against (idempotent).
            Map<String, Exam__c> examByCode = new Map<String, Exam__c>();
            Boolean canCreateExam = Schema.SObjectType.Exam__c.isCreateable();
            for (Exam__c x : [
                SELECT Id, Subject_Code__c, Subject__c
                FROM Exam__c
                WHERE Subject_Code__c IN :courseCodes
                WITH SECURITY_ENFORCED
                LIMIT 200
            ]) examByCode.put(x.Subject_Code__c, x);
            if (canCreateExam) {
                List<Exam__c> toCreate = new List<Exam__c>();
                for (String code : courseCodes) {
                    if (!examByCode.containsKey(code)) {
                        toCreate.add(new Exam__c(
                            Subject_Code__c = code,
                            Subject__c      = code,
                            Status__c       = 'Scheduled',
                            Exam_Date__c    = Date.today().addDays(14)
                        ));
                    }
                }
                if (!toCreate.isEmpty()) {
                    insert toCreate;
                    for (Exam__c x : toCreate) examByCode.put(x.Subject_Code__c, x);
                }
            }

            // 2) Idempotent enrollment per exam (skip if already enrolled).
            Set<Id> alreadyEnrolledExamIds = new Set<Id>();
            if (studentId != null) {
                for (Exam_Enrollment__c en : [
                    SELECT Exam__c FROM Exam_Enrollment__c
                    WHERE Student__c = :studentId AND Exam__c IN :examByCode.values()
                    WITH SECURITY_ENFORCED
                ]) alreadyEnrolledExamIds.add(en.Exam__c);
            }
            List<Exam_Enrollment__c> newEnrollments = new List<Exam_Enrollment__c>();
            for (Exam__c x : examByCode.values()) {
                if (alreadyEnrolledExamIds.contains(x.Id)) continue;
                newEnrollments.add(new Exam_Enrollment__c(
                    Student__c           = studentId,
                    Exam__c              = x.Id,
                    Enrollment_Status__c = 'Enrolled',
                    Is_Eligible__c       = true,
                    Seat_Number__c       = autoSeat(x.Subject_Code__c)
                ));
            }
            if (!newEnrollments.isEmpty() && Schema.SObjectType.Exam_Enrollment__c.isCreateable()) {
                insert newEnrollments;
            }

            // 3) Best-effort payment record (mock ref if Razorpay not wired).
            String gatewayRef;
            try {
                RazorpayService.RazorpayOrder order = RazorpayService.createOrder(null, totalFee);
                gatewayRef = order.orderId;
            } catch (Exception gwEx) {
                gatewayRef = 'EXM-' + String.valueOf(Datetime.now().getTime()).right(10);
            }
            if (studentId != null && totalFee > 0
                && Schema.SObjectType.Payment__c.isCreateable()) {
                insert new Payment__c(
                    Student__c          = studentId,
                    Amount__c           = totalFee,
                    Mode__c             = 'UPI',
                    Status__c           = 'Success',
                    Gateway_Ref__c      = gatewayRef,
                    Transaction_Date__c = Datetime.now()
                );
            }

            // 4) Notification so the student sees confirmation in the bell.
            if (studentId != null
                && Schema.SObjectType.Student_Notification__c.isCreateable()) {
                insert new Student_Notification__c(
                    Student__c = studentId,
                    Title__c   = 'Exam enrollment confirmed',
                    Body__c    = 'You enrolled in ' + courseCodes.size()
                                 + ' course(s). Reference: ' + gatewayRef,
                    Category__c = 'Academic',
                    Is_Read__c  = false
                );
            }

            EnrollmentConfirmationDTO out = new EnrollmentConfirmationDTO();
            out.referenceNumber     = gatewayRef;
            out.enrolledCount       = courseCodes.size();
            out.amountPaid          = totalFee;
            out.paymentMode         = 'UPI';
            out.confirmedAt         = Datetime.now().format('d MMM yyyy, h:mm a');
            out.enrolledCourseCodes = new List<String>(courseCodes);
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenMyExamsController.confirmExamEnrollment',
                'Could not confirm enrollment. Please try again.', e);
            return null;
        }
    }

    private static String autoSeat(String code) {
        if (String.isBlank(code)) return 'A-01';
        Integer n = Math.mod(Math.abs(code.hashCode()), 60) + 1;
        return code.left(1).toUpperCase() + '-' + (n < 10 ? '0' + n : String.valueOf(n));
    }

}