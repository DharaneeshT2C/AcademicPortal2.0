/**
 * ************************************************************************************************
 * @className  KenScheduleController
 *
 * @description
 *  Backs the `my/schedule` LWC page — weekly timetable grid for the running
 *  student, and the Today strip used by the Home dashboard's right rail.
 *
 *  TODO[SOBJECT]: Wire to `Course_Schedule__c` / `Class_Session__c` keyed to
 *                 the student's enrolled CourseOfferings.
 * ************************************************************************************************
 */
public with sharing class KenScheduleController {

    public class ScheduleBlockDTO {
        @AuraEnabled public String  id;
        @AuraEnabled public String  title;
        @AuraEnabled public String  instructor;
        @AuraEnabled public String  location;
        @AuraEnabled public String  dayOfWeek;  // 'Mon' .. 'Sun'
        @AuraEnabled public String  startTime;
        @AuraEnabled public String  endTime;
        @AuraEnabled public String  colorToken; // 'blue' | 'violet' | 'amber' | 'green' | 'red'
    }

    @AuraEnabled(cacheable=true)
    public static List<ScheduleBlockDTO> getWeeklySchedule() {
        try {
            return seedBlocks();
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenScheduleController.getWeeklySchedule',
                'Unable to load your schedule.', e);
            return null;
        }
    }

    private static List<ScheduleBlockDTO> seedBlocks() {
        List<ScheduleBlockDTO> out = new List<ScheduleBlockDTO>();
        out.add(block('S1', 'Data Structures',      'Dr. Iyer',    'Room 304',    'Mon', '9:00 AM', '10:00 AM', 'violet'));
        out.add(block('S2', 'Operating Systems Lab','Dr. Sharma',  'Lab 2',       'Mon', '10:00 AM','12:00 PM', 'blue'));
        out.add(block('S3', 'Mathematics III',      'Prof. Gupta', 'Room 201',    'Tue', '11:30 AM','12:30 PM', 'green'));
        out.add(block('S4', 'Soft Skills Workshop', 'Ms. Khanna',  'Auditorium',  'Wed', '2:00 PM', '3:00 PM',  'amber'));
        out.add(block('S5', 'Engineering Physics',  'Prof. Raghav','Lab 1',       'Thu', '10:00 AM','12:00 PM', 'blue'));
        out.add(block('S6', 'Electives',            'Various',     'TBD',         'Fri', '3:00 PM', '5:00 PM',  'red'));
        return out;
    }

    private static ScheduleBlockDTO block(String id, String title, String inst, String loc,
                                          String day, String startStr, String endStr, String color) {
        ScheduleBlockDTO b = new ScheduleBlockDTO();
        b.id = id; b.title = title; b.instructor = inst; b.location = loc;
        b.dayOfWeek = day; b.startTime = startStr; b.endTime = endStr; b.colorToken = color;
        return b;
    }
}