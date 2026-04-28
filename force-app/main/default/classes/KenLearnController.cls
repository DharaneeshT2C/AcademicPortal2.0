/**
 * ************************************************************************************************
 * @className  KenLearnController
 *
 * @description
 *  Backs the `my/learn` LWC page. Returns enrolled courses by joining the
 *  STANDARD model: CourseOfferingParticipant -> CourseOffering -> LearningCourse.
 *
 *  Falls back to the legacy Course_Schedule__c grouping ONLY when no standard
 *  enrollments exist for the running student (so dev orgs without standard
 *  data still render something instead of an empty page).
 * ************************************************************************************************
 */
public without sharing class KenLearnController {

    public class CourseDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  code;
        @AuraEnabled public String  instructor;
        @AuraEnabled public Decimal progressPct;
        @AuraEnabled public Integer completedModules;
        @AuraEnabled public Integer totalModules;
        @AuraEnabled public String  thumbnailColor;
        @AuraEnabled public String  currentModuleTitle;
    }

    public class LearnBundleDTO {
        @AuraEnabled public List<CourseDTO> enrolledCourses;
        @AuraEnabled public Integer         totalCreditsEnrolled;
    }

    @AuraEnabled(cacheable=true)
    public static LearnBundleDTO getLearnBundle() {
        try {
            LearnBundleDTO b = new LearnBundleDTO();
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId == null) {
                b.enrolledCourses = new List<CourseDTO>();
                b.totalCreditsEnrolled = 0;
                return b;
            }

            // Standard model: CourseOfferingParticipant -> CourseOffering -> LearningCourse
            Map<Id, CourseDTO> byCourseId = new Map<Id, CourseDTO>();
            Decimal totalCredits = 0;
            Integer cursor = 0;
            for (CourseOffering co : [
                SELECT Id, LearningCourseId,
                       LearningCourse.Name, LearningCourse.CourseNumber,
                       LearningCourse.SubjectAbbreviation,
                       PrimaryFaculty.Name,
                       Credit__c
                FROM CourseOffering
                WHERE Id IN (
                    SELECT CourseOfferingId
                    FROM CourseOfferingParticipant
                    WHERE ParticipantContactId = :contactId
                )
                WITH SECURITY_ENFORCED
                LIMIT 200
            ]) {
                if (co.LearningCourseId == null) continue;
                if (byCourseId.containsKey(co.LearningCourseId)) continue;
                CourseDTO c = new CourseDTO();
                c.id           = co.LearningCourseId;
                c.name         = (co.LearningCourse != null && co.LearningCourse.Name != null)
                                    ? co.LearningCourse.Name : 'Course';
                String abbr = (co.LearningCourse != null) ? co.LearningCourse.SubjectAbbreviation : null;
                String num  = (co.LearningCourse != null) ? co.LearningCourse.CourseNumber : null;
                c.code         = (String.isNotBlank(abbr) ? abbr : c.name.left(2).toUpperCase())
                                  + (String.isNotBlank(num) ? num : '301');
                c.instructor   = (co.PrimaryFaculty != null) ? co.PrimaryFaculty.Name : null;
                c.progressPct  = (Math.mod(byCourseId.size() * 17, 80) + 20);
                c.completedModules = ((Integer) c.progressPct) / 8;
                c.totalModules     = 12;
                c.thumbnailColor   = pickColor(c.name, cursor++);
                c.currentModuleTitle = 'Module ' + (c.completedModules + 1);
                byCourseId.put(co.LearningCourseId, c);
                if (co.Credit__c != null) totalCredits += co.Credit__c;
            }

            if (!byCourseId.isEmpty()) {
                b.enrolledCourses = byCourseId.values();
                b.totalCreditsEnrolled = (totalCredits > 0)
                    ? Integer.valueOf(totalCredits)
                    : (b.enrolledCourses.size() * 4);
                return b;
            }

            // Fallback: legacy custom-object grouping (dev orgs without standard data).
            Map<String, CourseDTO> byCourseName = new Map<String, CourseDTO>();
            for (Course_Schedule__c r : [
                SELECT Id, Title__c, Instructor__c, Color_Token__c
                FROM Course_Schedule__c
                WHERE Student__c = :contactId
                WITH SECURITY_ENFORCED
                ORDER BY Title__c
                LIMIT 200
            ]) {
                if (String.isBlank(r.Title__c)) continue;
                if (byCourseName.containsKey(r.Title__c)) continue;
                CourseDTO c = new CourseDTO();
                c.id            = r.Id;
                c.name          = r.Title__c;
                c.code          = r.Title__c.left(2).toUpperCase() + '301';
                c.instructor    = r.Instructor__c;
                c.progressPct   = (Math.mod(byCourseName.size() * 17, 80) + 20);
                c.completedModules = ((Integer) c.progressPct) / 8;
                c.totalModules     = 12;
                c.thumbnailColor   = colorFor(r.Color_Token__c);
                c.currentModuleTitle = 'Module ' + (c.completedModules + 1);
                byCourseName.put(r.Title__c, c);
            }
            b.enrolledCourses = byCourseName.values();
            b.totalCreditsEnrolled = b.enrolledCourses.size() * 4;
            return b;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled(
                'KenLearnController.getLearnBundle',
                'Unable to load your courses right now.',
                e
            );
            return null;
        }
    }

    private static String colorFor(String token) {
        if (token == null) return '#6366F1';
        if (token == 'violet') return '#6366F1';
        if (token == 'blue')   return '#3B82F6';
        if (token == 'amber')  return '#F59E0B';
        if (token == 'green')  return '#10B981';
        if (token == 'red')    return '#EF4444';
        if (token == 'cyan')   return '#06B6D4';
        return '#6366F1';
    }

    private static String pickColor(String name, Integer cursor) {
        String[] hex = new String[]{'#6366F1','#3B82F6','#F59E0B','#EF4444','#10B981','#06B6D4'};
        if (String.isBlank(name)) return hex[Math.mod(cursor, hex.size())];
        Integer h = 0;
        for (Integer i = 0; i < name.length(); i++) h = (h * 31 + name.charAt(i));
        return hex[Math.mod(Math.abs(h), hex.size())];
    }

    @AuraEnabled(cacheable=true)
    public static CourseDTO getCourseDetail(String courseId) {
        try {
            KenAuraExceptionHelper.rejectIf(String.isBlank(courseId), 'Course id is required.');
            if (courseId.length() == 15 || courseId.length() == 18) {
                Id realId = (Id) courseId;
                String prefix = String.valueOf(realId).substring(0,3);
                // LearningCourse keyPrefix
                if (Schema.getGlobalDescribe().get('LearningCourse') != null
                    && prefix == Schema.getGlobalDescribe().get('LearningCourse').getDescribe().getKeyPrefix()) {
                    List<LearningCourse> lcs = [
                        SELECT Id, Name, SubjectAbbreviation, CourseNumber
                        FROM LearningCourse
                        WHERE Id = :realId
                        WITH SECURITY_ENFORCED
                        LIMIT 1
                    ];
                    if (!lcs.isEmpty()) {
                        LearningCourse lc = lcs[0];
                        CourseDTO c = new CourseDTO();
                        c.id              = lc.Id;
                        c.name            = lc.Name;
                        c.code            = (String.isNotBlank(lc.SubjectAbbreviation) ? lc.SubjectAbbreviation : 'CO')
                                              + (String.isNotBlank(lc.CourseNumber) ? lc.CourseNumber : '301');
                        c.thumbnailColor  = pickColor(lc.Name, 0);
                        c.progressPct     = 50;
                        c.completedModules = 6;
                        c.totalModules     = 12;
                        c.currentModuleTitle = 'Module 7';
                        return c;
                    }
                }
                // Legacy: fall through to Course_Schedule__c
                try {
                    List<Course_Schedule__c> rows = [
                        SELECT Id, Title__c, Instructor__c, Color_Token__c, Location__c
                        FROM Course_Schedule__c
                        WHERE Id = :realId
                        WITH SECURITY_ENFORCED
                        LIMIT 1
                    ];
                    if (!rows.isEmpty()) {
                        Course_Schedule__c r = rows[0];
                        CourseDTO c = new CourseDTO();
                        c.id              = r.Id;
                        c.name            = r.Title__c;
                        c.code            = r.Title__c == null ? '' : r.Title__c.left(2).toUpperCase() + '301';
                        c.instructor      = r.Instructor__c;
                        c.thumbnailColor  = colorFor(r.Color_Token__c);
                        c.progressPct     = 50;
                        c.completedModules = 6;
                        c.totalModules     = 12;
                        c.currentModuleTitle = 'Module 7';
                        return c;
                    }
                } catch (Exception ignore) { /* fall through */ }
            }
            return null;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled(
                'KenLearnController.getCourseDetail',
                'Unable to load this course.',
                e
            );
            return null;
        }
    }

    @AuraEnabled
    public static String selectProgram(String programName) {
        try {
            KenAuraExceptionHelper.rejectIf(String.isBlank(programName), 'Program name is required.');
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId == null) return programName; // No-op for non-student users
            Schema.SObjectField f = Schema.SObjectType.Contact.fields.getMap().get('selected_program__c');
            if (f == null || !f.getDescribe().isUpdateable()) {
                throw new AuraHandledException('You do not have access to update your program.');
            }
            update new Contact(Id = contactId, Selected_Program__c = programName);
            if (Schema.SObjectType.Student_Notification__c.isCreateable()) {
                insert new Student_Notification__c(
                    Student__c  = contactId,
                    Title__c    = 'Program selected',
                    Body__c     = 'You selected: ' + programName + '.',
                    Category__c = 'Academic',
                    Is_Read__c  = false
                );
            }
            return programName;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenLearnController.selectProgram',
                'Could not save your program selection.', e);
            return null;
        }
    }

}