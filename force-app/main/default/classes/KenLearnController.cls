/**
 * ************************************************************************************************
 * @className  KenLearnController
 *
 * @description
 *  Backs the `my/learn` LWC page. Returns enrolled courses with progress and
 *  content tree for the currently-enrolled student.
 *
 *  TODO[SOBJECT]: Wire SOQL to LearnerProgram + CourseEnrollment + Learning
 *                 progress objects once the reference academics schema is
 *                 imported. Until then returns seeded data shaped to the LWC.
 *
 * @author      Student Portal Backend
 * @createdOn   2026
 * ************************************************************************************************
 */
public with sharing class KenLearnController {

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
                b.enrolledCourses = seedCourses();
                b.totalCreditsEnrolled = 18;
                return b;
            }
            // Course_Schedule__c rows are class slots; group by Title__c to get
            // unique enrolled courses for the student.
            Map<String, CourseDTO> byCourse = new Map<String, CourseDTO>();
            for (Course_Schedule__c r : [
                SELECT Id, Title__c, Instructor__c, Color_Token__c
                FROM Course_Schedule__c
                WHERE Student__c = :contactId
                WITH USER_MODE
                ORDER BY Title__c
                LIMIT 200
            ]) {
                if (String.isBlank(r.Title__c)) continue;
                if (byCourse.containsKey(r.Title__c)) continue;
                CourseDTO c = new CourseDTO();
                c.id            = r.Id;
                c.name          = r.Title__c;
                c.code          = r.Title__c.left(2).toUpperCase() + '301';
                c.instructor    = r.Instructor__c;
                c.progressPct   = (Math.mod(byCourse.size() * 17, 80) + 20);
                c.completedModules = ((Integer) c.progressPct) / 8;
                c.totalModules     = 12;
                c.thumbnailColor   = colorFor(r.Color_Token__c);
                c.currentModuleTitle = 'Module ' + (c.completedModules + 1);
                byCourse.put(r.Title__c, c);
            }
            b.enrolledCourses = byCourse.values();
            if (b.enrolledCourses.isEmpty()) b.enrolledCourses = seedCourses();
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

    @AuraEnabled(cacheable=true)
    public static CourseDTO getCourseDetail(String courseId) {
        try {
            KenAuraExceptionHelper.rejectIf(String.isBlank(courseId), 'Course id is required.');
            // Try real Course_Schedule__c lookup if the id is a Salesforce Id.
            if (courseId.length() == 15 || courseId.length() == 18) {
                try {
                    Id realId = (Id) courseId;
                    List<Course_Schedule__c> rows = [
                        SELECT Id, Title__c, Instructor__c, Color_Token__c, Location__c
                        FROM Course_Schedule__c
                        WHERE Id = :realId
                        WITH USER_MODE
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
                } catch (Exception ignore) { /* fall through to seed */ }
            }
            for (CourseDTO c : seedCourses()) {
                if (String.valueOf(c.id) == courseId) return c;
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
            // Verify the field is updateable on Contact for the running user.
            Schema.SObjectField f = Schema.SObjectType.Contact.fields.getMap().get('selected_program__c');
            if (f == null || !f.getDescribe().isUpdateable()) {
                throw new AuraHandledException('You do not have access to update your program.');
            }
            update new Contact(Id = contactId, Selected_Program__c = programName);
            // Audit trail via notification.
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

    private static List<CourseDTO> seedCourses() {
        List<CourseDTO> out = new List<CourseDTO>();
        out.add(buildCourse('C001', 'Data Structures',           'CS301', 'Dr. Iyer',      72,  9, 12, '#6366F1', 'Balanced Trees'));
        out.add(buildCourse('C002', 'Operating Systems',         'CS302', 'Dr. Sharma',    55,  7, 13, '#10B981', 'Process Scheduling'));
        out.add(buildCourse('C003', 'Mathematics III',           'MA301', 'Prof. Gupta',   41,  5, 12, '#F59E0B', 'Differential Equations'));
        out.add(buildCourse('C004', 'Soft Skills Workshop',      'SS101', 'Ms. Khanna',    88, 11, 13, '#EF4444', 'Public Speaking'));
        return out;
    }

    private static CourseDTO buildCourse(String id, String name, String code, String inst,
                                         Decimal pct, Integer done, Integer total, String color, String moduleTitle) {
        CourseDTO c = new CourseDTO();
        c.id = id; c.name = name; c.code = code; c.instructor = inst;
        c.progressPct = pct; c.completedModules = done; c.totalModules = total;
        c.thumbnailColor = color; c.currentModuleTitle = moduleTitle;
        return c;
    }
}