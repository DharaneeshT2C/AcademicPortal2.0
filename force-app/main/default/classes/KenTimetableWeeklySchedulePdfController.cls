public with sharing class KenTimetableWeeklySchedulePdfController {
    public String titleText { get; private set; }
    public String summaryText { get; private set; }
    public String errorMessage { get; private set; }
    public String cornerHeader { get; private set; }
    public Boolean isHorizontalView { get; private set; }
    public List<String> headerLabels { get; private set; }
    public List<RowWrapper> rows { get; private set; }

    private static final List<String> DAY_LABELS = new List<String>{
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    };

    public KenTimetableWeeklySchedulePdfController() {
        rows = new List<RowWrapper>();
        headerLabels = new List<String>();

        String academicTermId = ApexPages.currentPage().getParameters().get('academicTermId');
        String programPlanId = ApexPages.currentPage().getParameters().get('programPlanId');
        String viewMode = String.valueOf(ApexPages.currentPage().getParameters().get('viewMode')).toLowerCase();
        isHorizontalView = viewMode == 'horizontal';

        if (String.isBlank(academicTermId) || String.isBlank(programPlanId)) {
            errorMessage = 'Academic term and program plan are required.';
            return;
        }

        KenTimetableManagementController.ProgramPlanWeeklyPreviewDTO dto;
        try {
            dto = KenTimetableManagementController.getProgramPlanWeeklyPreview((Id) academicTermId, (Id) programPlanId);
        } catch (Exception ex) {
            errorMessage = ex.getMessage();
            return;
        }

        if (dto == null || dto.scheduleEntries == null || dto.scheduleEntries.isEmpty()) {
            errorMessage = 'No scheduled course offerings found for the selected program plan.';
            return;
        }

        String termName = String.isBlank(dto.academicTermName) ? 'Term' : dto.academicTermName;
        String planName = String.isBlank(dto.programPlanName) ? 'Program Plan' : dto.programPlanName;
        titleText = planName + ' - ' + termName;
        summaryText = dto.scheduledOfferingCount + ' course offering(s) and ' + dto.totalSessions + ' scheduled row(s) loaded.';

        if (isHorizontalView) {
            cornerHeader = 'Day';
            for (String slotTime : dto.timeSlots) {
                headerLabels.add(formatTimeLabel(slotTime));
            }
            rows = buildHorizontalRows(dto.timeSlots, dto.scheduleEntries);
        } else {
            cornerHeader = 'Time';
            headerLabels.addAll(DAY_LABELS);
            rows = buildVerticalRows(dto.timeSlots, dto.scheduleEntries);
        }
    }

    private List<RowWrapper> buildVerticalRows(
        List<String> timeSlots,
        List<KenTimetableManagementController.BuilderScheduleEntryDTO> scheduleEntries
    ) {
        List<RowWrapper> output = new List<RowWrapper>();
        List<String> safeTimeSlots = timeSlots == null ? new List<String>() : timeSlots;
        Set<String> hiddenKeys = new Set<String>();

        for (Integer timeIndex = 0; timeIndex < safeTimeSlots.size(); timeIndex++) {
            String slotTime = safeTimeSlots[timeIndex];
            RowWrapper row = new RowWrapper();
            row.leadingLabel = formatTimeLabel(slotTime);
            row.cells = new List<CellWrapper>();

            for (String dayLabel : DAY_LABELS) {
                String key = dayLabel + '-' + slotTime;
                if (hiddenKeys.contains(key)) {
                    continue;
                }

                KenTimetableManagementController.BuilderScheduleEntryDTO matchedEntry = findEntry(scheduleEntries, dayLabel, slotTime);
                CellWrapper cell = buildCell(matchedEntry);
                if (matchedEntry == null) {
                    row.cells.add(cell);
                    continue;
                }

                Integer rowSpan = calculateSlotSpan(matchedEntry.startTime, matchedEntry.endTime);
                Integer availableSpan = Math.max(1, safeTimeSlots.size() - timeIndex);
                cell.rowSpan = Math.min(rowSpan, availableSpan);
                for (Integer offset = 1; offset < cell.rowSpan; offset++) {
                    hiddenKeys.add(dayLabel + '-' + safeTimeSlots[timeIndex + offset]);
                }
                row.cells.add(cell);
            }

            output.add(row);
        }

        return output;
    }

    private List<RowWrapper> buildHorizontalRows(
        List<String> timeSlots,
        List<KenTimetableManagementController.BuilderScheduleEntryDTO> scheduleEntries
    ) {
        List<RowWrapper> output = new List<RowWrapper>();
        List<String> safeTimeSlots = timeSlots == null ? new List<String>() : timeSlots;
        Set<String> hiddenKeys = new Set<String>();

        for (String dayLabel : DAY_LABELS) {
            RowWrapper row = new RowWrapper();
            row.leadingLabel = dayLabel;
            row.cells = new List<CellWrapper>();

            for (Integer timeIndex = 0; timeIndex < safeTimeSlots.size(); timeIndex++) {
                String slotTime = safeTimeSlots[timeIndex];
                String key = dayLabel + '-' + slotTime;
                if (hiddenKeys.contains(key)) {
                    continue;
                }

                KenTimetableManagementController.BuilderScheduleEntryDTO matchedEntry = findEntry(scheduleEntries, dayLabel, slotTime);
                CellWrapper cell = buildCell(matchedEntry);
                if (matchedEntry == null) {
                    row.cells.add(cell);
                    continue;
                }

                Integer colSpan = calculateSlotSpan(matchedEntry.startTime, matchedEntry.endTime);
                Integer availableSpan = Math.max(1, safeTimeSlots.size() - timeIndex);
                cell.colSpan = Math.min(colSpan, availableSpan);
                for (Integer offset = 1; offset < cell.colSpan; offset++) {
                    hiddenKeys.add(dayLabel + '-' + safeTimeSlots[timeIndex + offset]);
                }
                row.cells.add(cell);
            }

            output.add(row);
        }

        return output;
    }

    private static KenTimetableManagementController.BuilderScheduleEntryDTO findEntry(
        List<KenTimetableManagementController.BuilderScheduleEntryDTO> scheduleEntries,
        String dayLabel,
        String slotTime
    ) {
        for (KenTimetableManagementController.BuilderScheduleEntryDTO entry : scheduleEntries) {
            if (entry.dayName == dayLabel && entry.startTime == slotTime) {
                return entry;
            }
        }
        return null;
    }

    private static CellWrapper buildCell(KenTimetableManagementController.BuilderScheduleEntryDTO entry) {
        CellWrapper cell = new CellWrapper();
        cell.rowSpan = 1;
        cell.colSpan = 1;
        if (entry == null) {
            cell.isEmpty = true;
            return cell;
        }

        cell.isEmpty = false;
        cell.toneClass = resolveTone(entry.type);
        cell.courseCode = String.isBlank(entry.courseCode) ? entry.courseName : entry.courseCode;
        cell.typeLabel = entry.type;
        cell.facultyName = entry.facultyName;
        cell.timeLabel = formatTimeLabel(entry.startTime) + ' - ' + formatTimeLabel(entry.endTime);
        return cell;
    }

    private static Integer calculateSlotSpan(String startTime, String endTime) {
        Time startValue = parseTime(startTime);
        Time endValue = parseTime(endTime);
        if (startValue == null || endValue == null || endValue <= startValue) {
            return 1;
        }
        Integer startMinutes = (startValue.hour() * 60) + startValue.minute();
        Integer endMinutes = (endValue.hour() * 60) + endValue.minute();
        return Math.max(1, Integer.valueOf(Math.ceil((endMinutes - startMinutes) / 30.0)));
    }

    private static Time parseTime(String value) {
        if (String.isBlank(value) || !value.contains(':')) {
            return null;
        }
        List<String> parts = value.split(':');
        if (parts.size() != 2) {
            return null;
        }
        return Time.newInstance(Integer.valueOf(parts[0]), Integer.valueOf(parts[1]), 0, 0);
    }

    private static String formatTimeLabel(String value) {
        Time parsedTime = parseTime(value);
        if (parsedTime == null) {
            return value;
        }
        Integer hourValue = parsedTime.hour();
        Integer minuteValue = parsedTime.minute();
        String suffix = hourValue >= 12 ? 'PM' : 'AM';
        Integer displayHour = Math.mod(hourValue, 12);
        if (displayHour == 0) {
            displayHour = 12;
        }
        return String.valueOf(displayHour) + ':' + String.valueOf(minuteValue).leftPad(2, '0') + ' ' + suffix;
    }

    private static String resolveTone(String typeValue) {
        String normalizedValue = String.valueOf(typeValue).toLowerCase();
        if (normalizedValue.contains('lab') || normalizedValue.contains('practical')) {
            return 'green';
        }
        if (normalizedValue.contains('tutorial')) {
            return 'amber';
        }
        if (normalizedValue.contains('seminar')) {
            return 'violet';
        }
        if (normalizedValue.contains('lecture') || normalizedValue.contains('theory')) {
            return 'blue';
        }
        return 'slate';
    }

    public class RowWrapper {
        public String leadingLabel { get; set; }
        public List<CellWrapper> cells { get; set; }
    }

    public class CellWrapper {
        public Boolean isEmpty { get; set; }
        public Integer rowSpan { get; set; }
        public Integer colSpan { get; set; }
        public String toneClass { get; set; }
        public String courseCode { get; set; }
        public String typeLabel { get; set; }
        public String facultyName { get; set; }
        public String timeLabel { get; set; }
    }
}