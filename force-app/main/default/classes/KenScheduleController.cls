/**
 * ************************************************************************************************
 * @className  KenScheduleController
 *
 * @description
 *  Backs the `my/schedule` LWC page. Queries STANDARD Education Cloud schema —
 *  CourseOffering / CourseOfferingSchedule joined via CourseOfferingParticipant
 *  to the running student's Contact. Schedule rows in the standard model use
 *  IsMonday..IsSunday booleans (not a single Day_of_Week column), so we expand
 *  one CourseOfferingSchedule row into one DTO per day flagged true.
 *
 *  Custom `Course_Schedule__c` is no longer queried; the SObject remains in
 *  the org so legacy data isn't lost (drop-in v1.1).
 * ************************************************************************************************
 */
public without sharing class KenScheduleController {

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

    private static final String[] DAY_ORDER = new String[]{'Mon','Tue','Wed','Thu','Fri','Sat','Sun'};

    @AuraEnabled(cacheable=true)
    public static List<ScheduleBlockDTO> getWeeklySchedule() {
        try {
            Id contactId = KenRunningStudentHelper.optionalContactId();
            if (contactId == null) return new List<ScheduleBlockDTO>();

            List<CourseOffering> offerings = [
                SELECT Id,
                       LearningCourse.Name,
                       PrimaryFaculty.Name,
                       Course_Type__c,
                       (SELECT Id, StartTime, EndTime,
                               IsMonday, IsTuesday, IsWednesday, IsThursday,
                               IsFriday, IsSaturday, IsSunday,
                               Location.Name
                        FROM CourseOfferingSchedules
                        ORDER BY StartTime)
                FROM CourseOffering
                WHERE Id IN (
                    SELECT CourseOfferingId
                    FROM CourseOfferingParticipant
                    WHERE ParticipantContactId = :contactId
                )
                WITH SECURITY_ENFORCED
                LIMIT 200
            ];

            List<ScheduleBlockDTO> out = new List<ScheduleBlockDTO>();
            Integer colorCursor = 0;
            for (CourseOffering co : offerings) {
                String title = (co.LearningCourse != null && co.LearningCourse.Name != null)
                    ? co.LearningCourse.Name : 'Course';
                String instructor = (co.PrimaryFaculty != null) ? co.PrimaryFaculty.Name : null;
                String colorToken = pickColor(title, colorCursor++);

                if (co.CourseOfferingSchedules == null) continue;
                for (CourseOfferingSchedule s : co.CourseOfferingSchedules) {
                    String loc = (s.Location != null) ? s.Location.Name : null;
                    Boolean[] flags = new Boolean[]{
                        s.IsMonday, s.IsTuesday, s.IsWednesday, s.IsThursday,
                        s.IsFriday, s.IsSaturday, s.IsSunday
                    };
                    for (Integer i = 0; i < 7; i++) {
                        if (flags[i] == true) {
                            ScheduleBlockDTO b = new ScheduleBlockDTO();
                            b.id          = s.Id + '-' + DAY_ORDER[i];
                            b.title       = title;
                            b.instructor  = instructor;
                            b.location    = loc;
                            b.dayOfWeek   = DAY_ORDER[i];
                            b.startTime   = formatTime(s.StartTime);
                            b.endTime     = formatTime(s.EndTime);
                            b.colorToken  = colorToken;
                            out.add(b);
                        }
                    }
                }
            }
            // Stable order: by day, then start time.
            out.sort(new BlockComparator());
            return out;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenScheduleController.getWeeklySchedule',
                'Unable to load your schedule.', e);
            return null;
        }
    }

    private static String formatTime(Time t) {
        if (t == null) return null;
        Integer h = t.hour();
        Integer m = t.minute();
        return (h < 10 ? '0' : '') + h + ':' + (m < 10 ? '0' : '') + m;
    }

    private static String pickColor(String title, Integer cursor) {
        // Deterministic colour by course title so the same course is always
        // tinted the same. Fallback to cursor-based if title is blank.
        String[] palette = new String[]{'violet','blue','amber','red','green','cyan'};
        if (String.isBlank(title)) return palette[Math.mod(cursor, palette.size())];
        Integer hash = 0;
        for (Integer i = 0; i < title.length(); i++) {
            hash = (hash * 31 + title.charAt(i));
        }
        return palette[Math.mod(Math.abs(hash), palette.size())];
    }

    private class BlockComparator implements Comparator<ScheduleBlockDTO> {
        public Integer compare(ScheduleBlockDTO a, ScheduleBlockDTO b) {
            Integer da = dayIdx(a.dayOfWeek), db = dayIdx(b.dayOfWeek);
            if (da != db) return da - db;
            String sa = a.startTime == null ? '' : a.startTime;
            String sb = b.startTime == null ? '' : b.startTime;
            return sa.compareTo(sb);
        }
        private Integer dayIdx(String d) {
            for (Integer i = 0; i < DAY_ORDER.size(); i++) if (DAY_ORDER[i] == d) return i;
            return 99;
        }
    }
}