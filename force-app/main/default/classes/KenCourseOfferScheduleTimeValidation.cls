public class KenCourseOfferScheduleTimeValidation {
private static final String CONFLICT_ERROR_SUFFIX =
        '. Choose another faculty or update the schedule.';

    public static void validatePrimaryFacultyScheduleConflicts(
        List<CourseOffering> newRecords,
        Map<Id, CourseOffering> oldMap
    ) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        Map<Id, CourseOffering> offeringsToValidate = getOfferingsToValidate(newRecords, oldMap);
        if (offeringsToValidate.isEmpty()) {
            return;
        }

        Map<Id, List<TimeWindow>> currentSchedulesByOfferingId =
            getSchedulesByOfferingId(offeringsToValidate.keySet());
        if (currentSchedulesByOfferingId.isEmpty()) {
            return;
        }

        Map<Id, List<TimeWindow>> schedulesByFacultyId =
            getSchedulesByFacultyId(offeringsToValidate.values(), currentSchedulesByOfferingId);

        for (CourseOffering offering : offeringsToValidate.values()) {
            List<TimeWindow> currentSchedules = currentSchedulesByOfferingId.get(offering.Id);
            List<TimeWindow> facultySchedules = schedulesByFacultyId.get(offering.PrimaryFacultyId);

            if (currentSchedules == null || facultySchedules == null) {
                continue;
            }

            TimeWindow conflictingWindow =
                findConflictingWindow(offering.Id, currentSchedules, facultySchedules);
            if (conflictingWindow != null) {
                offering.PrimaryFacultyId.addError(buildConflictMessage(conflictingWindow));
            }
        }
    }

    public static void validateScheduleConflicts(
        List<CourseOfferingSchedule> newRecords,
        Map<Id, CourseOfferingSchedule> oldMap
    ) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        List<CourseOfferingSchedule> schedulesToValidate = getSchedulesToValidate(newRecords, oldMap);
        if (schedulesToValidate.isEmpty()) {
            return;
        }

        Map<Id, CourseOffering> offeringsById = new Map<Id, CourseOffering>([
            SELECT Id, Name, PrimaryFacultyId
            FROM CourseOffering
            WHERE Id IN :getCourseOfferingIds(schedulesToValidate)
        ]);

        Map<Id, List<TimeWindow>> schedulesByFacultyId =
            getSchedulesByFacultyId(getFacultyIds(offeringsById.values()));

        for (CourseOfferingSchedule candidateSchedule : schedulesToValidate) {
            CourseOffering candidateOffering = offeringsById.get(candidateSchedule.CourseOfferingId);
            if (candidateOffering == null || candidateOffering.PrimaryFacultyId == null) {
                continue;
            }

            addWindow(
                schedulesByFacultyId,
                candidateOffering.PrimaryFacultyId,
                new TimeWindow(
                    candidateSchedule.CourseOfferingId,
                    candidateOffering.Name,
                    candidateSchedule.StartTime,
                    candidateSchedule.EndTime
                )
            );
        }

        for (CourseOfferingSchedule schedule : schedulesToValidate) {
            CourseOffering parentOffering = offeringsById.get(schedule.CourseOfferingId);
            if (parentOffering == null || parentOffering.PrimaryFacultyId == null) {
                continue;
            }

            List<TimeWindow> facultySchedules = schedulesByFacultyId.get(parentOffering.PrimaryFacultyId);
            if (facultySchedules == null) {
                continue;
            }

            TimeWindow currentWindow = new TimeWindow(
                schedule.CourseOfferingId,
                parentOffering.Name,
                schedule.StartTime,
                schedule.EndTime
            );

            TimeWindow conflictingWindow =
                findConflictingWindow(schedule.CourseOfferingId, currentWindow, facultySchedules);
            if (conflictingWindow != null) {
                schedule.StartTime.addError(buildConflictMessage(conflictingWindow));
            }
        }
    }

    private static Map<Id, CourseOffering> getOfferingsToValidate(
        List<CourseOffering> newRecords,
        Map<Id, CourseOffering> oldMap
    ) {
        Map<Id, CourseOffering> offeringsToValidate = new Map<Id, CourseOffering>();

        for (CourseOffering offering : newRecords) {
            if (!shouldValidateFaculty(offering, oldMap)) {
                continue;
            }
            offeringsToValidate.put(offering.Id, offering);
        }

        return offeringsToValidate;
    }

    private static Boolean shouldValidateFaculty(
        CourseOffering offering,
        Map<Id, CourseOffering> oldMap
    ) {
        if (offering == null || offering.Id == null || offering.PrimaryFacultyId == null) {
            return false;
        }

        if (oldMap == null || !oldMap.containsKey(offering.Id)) {
            return true;
        }

        return offering.PrimaryFacultyId != oldMap.get(offering.Id).PrimaryFacultyId;
    }

    private static List<CourseOfferingSchedule> getSchedulesToValidate(
        List<CourseOfferingSchedule> newRecords,
        Map<Id, CourseOfferingSchedule> oldMap
    ) {
        List<CourseOfferingSchedule> schedulesToValidate = new List<CourseOfferingSchedule>();
        for (CourseOfferingSchedule schedule : newRecords) {
            if (!shouldValidateSchedule(schedule, oldMap)) {
                continue;
            }
            schedulesToValidate.add(schedule);
        }

        return schedulesToValidate;
    }

    private static Boolean shouldValidateSchedule(
        CourseOfferingSchedule schedule,
        Map<Id, CourseOfferingSchedule> oldMap
    ) {
        if (schedule == null ||
            schedule.CourseOfferingId == null ||
            schedule.StartTime == null ||
            schedule.EndTime == null) {
            return false;
        }

        if (oldMap == null || !oldMap.containsKey(schedule.Id)) {
            return true;
        }

        CourseOfferingSchedule oldSchedule = oldMap.get(schedule.Id);
        return schedule.CourseOfferingId != oldSchedule.CourseOfferingId ||
            schedule.StartTime != oldSchedule.StartTime ||
            schedule.EndTime != oldSchedule.EndTime;
    }

    private static Map<Id, List<TimeWindow>> getSchedulesByOfferingId(Set<Id> offeringIds) {
        Map<Id, List<TimeWindow>> schedulesByOfferingId = new Map<Id, List<TimeWindow>>();

        for (CourseOfferingSchedule schedule : [
            SELECT CourseOfferingId, StartTime, EndTime
            FROM CourseOfferingSchedule
            WHERE CourseOfferingId IN :offeringIds
            AND StartTime != null
            AND EndTime != null
        ]) {
            addWindow(
                schedulesByOfferingId,
                schedule.CourseOfferingId,
                new TimeWindow(schedule.CourseOfferingId, null, schedule.StartTime, schedule.EndTime)
            );
        }

        return schedulesByOfferingId;
    }

    private static Map<Id, List<TimeWindow>> getSchedulesByFacultyId(
        List<CourseOffering> offeringsToValidate,
        Map<Id, List<TimeWindow>> currentSchedulesByOfferingId
    ) {
        Map<Id, List<TimeWindow>> schedulesByFacultyId = new Map<Id, List<TimeWindow>>();
        Set<Id> facultyIds = getFacultyIds(offeringsToValidate);
        schedulesByFacultyId.putAll(getSchedulesByFacultyId(facultyIds));

        for (CourseOffering offering : offeringsToValidate) {
            List<TimeWindow> currentSchedules = currentSchedulesByOfferingId.get(offering.Id);
            if (currentSchedules == null) {
                continue;
            }

            for (TimeWindow currentSchedule : currentSchedules) {
                addWindow(
                    schedulesByFacultyId,
                    offering.PrimaryFacultyId,
                    new TimeWindow(
                        offering.Id,
                        offering.Name,
                        currentSchedule.startTime,
                        currentSchedule.endTime
                    )
                );
            }
        }

        return schedulesByFacultyId;
    }

    private static Map<Id, List<TimeWindow>> getSchedulesByFacultyId(Set<Id> facultyIds) {
        Map<Id, List<TimeWindow>> schedulesByFacultyId = new Map<Id, List<TimeWindow>>();
        if (facultyIds.isEmpty()) {
            return schedulesByFacultyId;
        }

        for (CourseOfferingSchedule schedule : [
            SELECT CourseOfferingId,
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
                schedulesByFacultyId,
                schedule.CourseOffering.PrimaryFacultyId,
                new TimeWindow(
                    schedule.CourseOfferingId,
                    schedule.CourseOffering.Name,
                    schedule.StartTime,
                    schedule.EndTime
                )
            );
        }

        return schedulesByFacultyId;
    }

    private static TimeWindow findConflictingWindow(
        Id currentOfferingId,
        List<TimeWindow> currentSchedules,
        List<TimeWindow> facultySchedules
    ) {
        for (TimeWindow currentSchedule : currentSchedules) {
            for (TimeWindow facultySchedule : facultySchedules) {
                if (facultySchedule.courseOfferingId == currentOfferingId) {
                    continue;
                }

                if (isOverlapping(currentSchedule, facultySchedule)) {
                    return facultySchedule;
                }
            }
        }

        return null;
    }

    private static TimeWindow findConflictingWindow(
        Id currentOfferingId,
        TimeWindow currentSchedule,
        List<TimeWindow> facultySchedules
    ) {
        for (TimeWindow facultySchedule : facultySchedules) {
            if (facultySchedule.courseOfferingId == currentOfferingId) {
                continue;
            }

            if (isOverlapping(currentSchedule, facultySchedule)) {
                return facultySchedule;
            }
        }

        return null;
    }

    private static String buildConflictMessage(TimeWindow conflictingWindow) {
        return 'This faculty is already assigned to ' +
            getOfferingLabel(conflictingWindow.courseOfferingName) +
            ' during ' + formatTime(conflictingWindow.startTime) +
            ' to ' + formatTime(conflictingWindow.endTime) +
            CONFLICT_ERROR_SUFFIX;
    }

    private static Boolean isOverlapping(TimeWindow firstWindow, TimeWindow secondWindow) {
        return firstWindow.startTime < secondWindow.endTime &&
            firstWindow.endTime > secondWindow.startTime;
    }

    private static void addWindow(
        Map<Id, List<TimeWindow>> windowsByKey,
        Id key,
        TimeWindow window
    ) {
        if (!windowsByKey.containsKey(key)) {
            windowsByKey.put(key, new List<TimeWindow>());
        }

        windowsByKey.get(key).add(window);
    }

    private static void addWindow(List<TimeWindow> windows, TimeWindow window) {
        windows.add(window);
    }

    private static Set<Id> getFacultyIds(List<CourseOffering> offerings) {
        Set<Id> facultyIds = new Set<Id>();
        for (CourseOffering offering : offerings) {
            if (offering.PrimaryFacultyId != null) {
                facultyIds.add(offering.PrimaryFacultyId);
            }
        }
        return facultyIds;
    }

    private static Set<Id> getCourseOfferingIds(List<CourseOfferingSchedule> schedules) {
        Set<Id> courseOfferingIds = new Set<Id>();
        for (CourseOfferingSchedule schedule : schedules) {
            if (schedule.CourseOfferingId != null) {
                courseOfferingIds.add(schedule.CourseOfferingId);
            }
        }
        return courseOfferingIds;
    }

    private static String getOfferingLabel(String offeringName) {
        if (String.isBlank(offeringName)) {
            return 'another course offering';
        }

        return '"' + offeringName + '"';
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

    private class TimeWindow {
        private Id courseOfferingId;
        private String courseOfferingName;
        private Time startTime;
        private Time endTime;

        private TimeWindow(
            Id courseOfferingId,
            String courseOfferingName,
            Time startTime,
            Time endTime
        ) {
            this.courseOfferingId = courseOfferingId;
            this.courseOfferingName = courseOfferingName;
            this.startTime = startTime;
            this.endTime = endTime;
        }
    }
}