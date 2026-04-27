public class KenCourseOfferingPrimaryFaculty	 {
  
 public static void validatePrimaryFacultyScheduleConflicts(
        List<CourseOffering> newRecords,
        Map<Id, CourseOffering> oldMap
    ) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        Map<Id, CourseOffering> candidateOfferingsById = new Map<Id, CourseOffering>();
        Set<Id> facultyIds = new Set<Id>();

        for (CourseOffering offering : newRecords) {
            if (!shouldValidate(offering, oldMap)) {
                continue;
            }
            if (offering.Id == null) {
                continue;
            }

            candidateOfferingsById.put(offering.Id, offering);
            facultyIds.add(offering.PrimaryFacultyId);
        }

        if (candidateOfferingsById.isEmpty() || facultyIds.isEmpty()) {
            return;
        }

        Map<Id, List<CourseOfferingSchedule>> schedulesByOfferingId =
            querySchedulesByOffering(candidateOfferingsById.keySet());
        if (schedulesByOfferingId.isEmpty()) {
            return;
        }

        Map<Id, List<ScheduleWindow>> windowsByFacultyId = new Map<Id, List<ScheduleWindow>>();

        for (CourseOfferingSchedule schedule : [
            SELECT Id,
                   CourseOfferingId,
                   CourseOffering.Name,
                   CourseOffering.PrimaryFacultyId,
                   StartTime,
                   EndTime
            FROM CourseOfferingSchedule
            WHERE CourseOffering.PrimaryFacultyId IN :facultyIds
            AND StartTime != null
            AND EndTime != null
        ]) {
            if (schedule.CourseOffering == null || schedule.CourseOffering.PrimaryFacultyId == null) {
                continue;
            }
            addWindow(
                windowsByFacultyId,
                schedule.CourseOffering.PrimaryFacultyId,
                new ScheduleWindow(
                    schedule.CourseOfferingId,
                    schedule.CourseOffering.Name,
                    schedule.StartTime,
                    schedule.EndTime
                )
            );
        }

        for (CourseOffering offering : candidateOfferingsById.values()) {
            List<CourseOfferingSchedule> currentSchedules = schedulesByOfferingId.get(offering.Id);
            if (currentSchedules == null || currentSchedules.isEmpty()) {
                continue;
            }

            for (CourseOfferingSchedule currentSchedule : currentSchedules) {
                addWindow(
                    windowsByFacultyId,
                    offering.PrimaryFacultyId,
                    new ScheduleWindow(
                        offering.Id,
                        offering.Name,
                        currentSchedule.StartTime,
                        currentSchedule.EndTime
                    )
                );
            }
        }

        for (CourseOffering offering : candidateOfferingsById.values()) {
            List<CourseOfferingSchedule> currentSchedules = schedulesByOfferingId.get(offering.Id);
            if (currentSchedules == null || currentSchedules.isEmpty()) {
                continue;
            }

            List<ScheduleWindow> facultyWindows = windowsByFacultyId.get(offering.PrimaryFacultyId);
            if (facultyWindows == null || facultyWindows.isEmpty()) {
                continue;
            }

            Boolean hasConflict = false;
            for (CourseOfferingSchedule currentSchedule : currentSchedules) {
                for (ScheduleWindow otherWindow : facultyWindows) {
                    if (otherWindow.offeringId == offering.Id) {
                        continue;
                    }
                    if (!timesOverlap(
                        currentSchedule.StartTime,
                        currentSchedule.EndTime,
                        otherWindow.startTime,
                        otherWindow.endTime
                    )) {
                        continue;
                    }

                    offering.PrimaryFacultyId.addError(buildConflictMessage(otherWindow));
                    hasConflict = true;
                    break;
                }
                if (hasConflict) {
                    break;
                }
            }
        }
    }

    private static Boolean shouldValidate(
        CourseOffering offering,
        Map<Id, CourseOffering> oldMap
    ) {
        if (offering == null || offering.PrimaryFacultyId == null) {
            return false;
        }
        if (oldMap == null || !oldMap.containsKey(offering.Id)) {
            return true;
        }
        return offering.PrimaryFacultyId != oldMap.get(offering.Id).PrimaryFacultyId;
    }

    private static Map<Id, List<CourseOfferingSchedule>> querySchedulesByOffering(Set<Id> offeringIds) {
        Map<Id, List<CourseOfferingSchedule>> schedulesByOfferingId =
            new Map<Id, List<CourseOfferingSchedule>>();

        for (CourseOfferingSchedule schedule : [
            SELECT Id, CourseOfferingId, StartTime, EndTime
            FROM CourseOfferingSchedule
            WHERE CourseOfferingId IN :offeringIds
            AND StartTime != null
            AND EndTime != null
        ]) {
            if (!schedulesByOfferingId.containsKey(schedule.CourseOfferingId)) {
                schedulesByOfferingId.put(schedule.CourseOfferingId, new List<CourseOfferingSchedule>());
            }
            schedulesByOfferingId.get(schedule.CourseOfferingId).add(schedule);
        }

        return schedulesByOfferingId;
    }

    private static void addWindow(
        Map<Id, List<ScheduleWindow>> windowsByFacultyId,
        Id facultyId,
        ScheduleWindow window
    ) {
        if (!windowsByFacultyId.containsKey(facultyId)) {
            windowsByFacultyId.put(facultyId, new List<ScheduleWindow>());
        }
        windowsByFacultyId.get(facultyId).add(window);
    }

    private static Boolean timesOverlap(
        Time startOne,
        Time endOne,
        Time startTwo,
        Time endTwo
    ) {
        return startOne < endTwo && endOne > startTwo;
    }

    private static String buildConflictMessage(ScheduleWindow conflictingWindow) {
        String offeringName = String.isBlank(conflictingWindow.offeringName)
            ? 'another course offering'
            : '"' + conflictingWindow.offeringName + '"';
        return 'This faculty is already assigned to ' + offeringName +
            ' during ' + formatTime(conflictingWindow.startTime) + ' to ' +
            formatTime(conflictingWindow.endTime) + '. Choose another faculty or update the schedule.';
    }

    private static String formatTime(Time value) {
        if (value == null) {
            return '';
        }

        Integer hourValue = value.hour();
        Integer minuteValue = value.minute();
        String meridiem = hourValue >= 12 ? 'PM' : 'AM';

        hourValue = Math.mod(hourValue, 12);
        if (hourValue == 0) {
            hourValue = 12;
        }

        return hourValue + ':' + (minuteValue < 10 ? '0' : '') + minuteValue + ' ' + meridiem;
    }

    private class ScheduleWindow {
        private Id offeringId;
        private String offeringName;
        private Time startTime;
        private Time endTime;

        private ScheduleWindow(
            Id offeringId,
            String offeringName,
            Time startTime,
            Time endTime
        ) {
            this.offeringId = offeringId;
            this.offeringName = offeringName;
            this.startTime = startTime;
            this.endTime = endTime;
        }
    }
}