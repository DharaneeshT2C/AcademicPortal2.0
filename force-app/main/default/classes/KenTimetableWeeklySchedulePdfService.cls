public with sharing class KenTimetableWeeklySchedulePdfService {
    public class PdfDownloadDTO {
        @AuraEnabled public String fileName;
        @AuraEnabled public String base64Data;
    }

    @AuraEnabled
    public static PdfDownloadDTO generateWeeklySchedulePdf(Id academicTermId, Id programPlanId) {
        KenTimetableManagementController.ProgramPlanWeeklyPreviewDTO dto =
            KenTimetableManagementController.getProgramPlanWeeklyPreview(academicTermId, programPlanId);

        if (dto == null || dto.scheduleEntries == null || dto.scheduleEntries.isEmpty()) {
            throw new AuraHandledException('No scheduled course offerings found for the selected program plan.');
        }

        String termName = String.isBlank(dto.academicTermName) ? 'term' : dto.academicTermName;
        String planName = String.isBlank(dto.programPlanName) ? 'program-plan' : dto.programPlanName;
        String html = buildWeeklyScheduleHtml(dto, termName, planName);

        PdfDownloadDTO result = new PdfDownloadDTO();
        result.fileName = sanitizeFileName(termName + '-' + planName + '-weekly-schedule') + '.pdf';
        result.base64Data = EncodingUtil.base64Encode(Blob.toPdf(html));
        return result;
    }

    private static String buildWeeklyScheduleHtml(
        KenTimetableManagementController.ProgramPlanWeeklyPreviewDTO dto,
        String termName,
        String planName
    ) {
        List<String> days = new List<String>{ 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday' };
        String headerCells = '';
        for (String day : days) {
            headerCells += '<th>' + escapeHtml(day) + '</th>';
        }

        List<KenTimetableManagementController.BuilderScheduleEntryDTO> entries = dto.scheduleEntries;
        List<String> timeSlots = dto.timeSlots == null ? new List<String>() : dto.timeSlots;
        Set<String> hiddenKeys = new Set<String>();
        String bodyRows = '';

        for (Integer timeIndex = 0; timeIndex < timeSlots.size(); timeIndex++) {
            String slotTime = timeSlots[timeIndex];
            String cells = '';
            for (String day : days) {
                String key = day + '-' + slotTime;
                if (hiddenKeys.contains(key)) {
                    continue;
                }

                KenTimetableManagementController.BuilderScheduleEntryDTO matchedEntry;
                for (KenTimetableManagementController.BuilderScheduleEntryDTO entry : entries) {
                    if (entry.dayName == day && entry.startTime == slotTime) {
                        matchedEntry = entry;
                        break;
                    }
                }

                if (matchedEntry == null) {
                    cells += '<td><div class="grid-empty">Drop here</div></td>';
                    continue;
                }

                Integer rowSpan = calculateSlotSpan(matchedEntry.startTime, matchedEntry.endTime);
                Integer availableSpan = Math.max(1, timeSlots.size() - timeIndex);
                rowSpan = Math.min(rowSpan, availableSpan);
                for (Integer offset = 1; offset < rowSpan; offset++) {
                    hiddenKeys.add(day + '-' + timeSlots[timeIndex + offset]);
                }

                String tone = resolveTone(matchedEntry.type);
                String typeMarkup = String.isBlank(matchedEntry.type)
                    ? ''
                    : '<span class="type-pill ' + tone + '">' + escapeHtml(matchedEntry.type) + '</span>';
                String facultyMarkup = String.isBlank(matchedEntry.facultyName)
                    ? ''
                    : '<div class="meta">' + escapeHtml(matchedEntry.facultyName) + '</div>';

                cells +=
                    '<td rowspan="' + rowSpan + '">' +
                        '<div class="cell-wrap">' +
                            '<div class="card ' + tone + '">' +
                                '<strong>' + escapeHtml(String.isBlank(matchedEntry.courseCode) ? matchedEntry.courseName : matchedEntry.courseCode) + '</strong>' +
                                typeMarkup +
                                facultyMarkup +
                                '<div class="meta">' + escapeHtml(formatTimeLabel(matchedEntry.startTime) + ' - ' + formatTimeLabel(matchedEntry.endTime)) + '</div>' +
                            '</div>' +
                        '</div>' +
                    '</td>';
            }

            bodyRows +=
                '<tr>' +
                    '<th class="time-col">' + escapeHtml(formatTimeLabel(slotTime)) + '</th>' +
                    cells +
                '</tr>';
        }

        String title = escapeHtml(planName + ' - ' + termName);
        String summary = escapeHtml(
            dto.scheduledOfferingCount + ' course offering(s) and ' + dto.totalSessions + ' scheduled row(s) loaded.'
        );

        return
            '<html><head><meta charset="UTF-8"/>' +
            '<style>' +
                '@page { size: A4 landscape; margin: 10mm; }' +
                'body { font-family: Arial, sans-serif; color: #18263a; font-size: 11px; }' +
                '.header { margin-bottom: 10px; }' +
                '.eyebrow { font-size: 10px; text-transform: uppercase; color: #7d8ca1; font-weight: bold; }' +
                '.title { margin: 2px 0 4px; font-size: 22px; font-weight: bold; }' +
                '.summary { margin: 0; color: #5f7087; font-size: 11px; }' +
                'table { width: 100%; border-collapse: collapse; table-layout: fixed; }' +
                'th, td { border: 1px solid #dbe6f2; vertical-align: top; }' +
                'thead th { background: #f8fbff; padding: 8px; text-align: left; font-size: 11px; font-weight: bold; }' +
                '.time-col { width: 68px; min-width: 68px; background: #fcfdff; color: #66778f; padding: 8px 6px; white-space: nowrap; text-align: left; font-weight: bold; }' +
                '.grid-empty { padding: 8px; color: #9aa9bb; font-size: 10px; min-height: 54px; }' +
                '.cell-wrap { padding: 5px; min-height: 72px; }' +
                '.card { border-radius: 10px; border: 1px solid #c9daf7; padding: 10px; min-height: 62px; }' +
                '.card strong { display: block; font-size: 13px; margin-bottom: 5px; }' +
                '.card.blue { border-left: 4px solid #3976d5; background: #eef5ff; border-color: #bfd6fb; }' +
                '.card.green { border-left: 4px solid #3976d5; background: #edf9f2; border-color: #c4e8d1; }' +
                '.card.amber { border-left: 4px solid #3976d5; background: #fff6e8; border-color: #f2ddb3; }' +
                '.card.violet { border-left: 4px solid #3976d5; background: #f2ecff; border-color: #d9caf9; }' +
                '.card.slate { border-left: 4px solid #3976d5; background: #f2f5f8; border-color: #d5dee7; }' +
                '.type-pill { display: inline-block; padding: 2px 7px; border-radius: 999px; font-size: 9px; font-weight: bold; margin-bottom: 5px; }' +
                '.type-pill.blue { background: #e7f0ff; color: #2f69c9; }' +
                '.type-pill.green { background: #e6f7ee; color: #218252; }' +
                '.type-pill.amber { background: #fff4df; color: #ad6a00; }' +
                '.type-pill.violet { background: #efe8ff; color: #6f49c6; }' +
                '.type-pill.slate { background: #eef2f6; color: #526273; }' +
                '.meta { font-size: 10px; line-height: 1.4; margin-top: 3px; }' +
            '</style></head><body>' +
                '<div class="header">' +
                    '<div class="eyebrow">Grid</div>' +
                    '<div class="title">' + title + '</div>' +
                    '<p class="summary">' + summary + '</p>' +
                '</div>' +
                '<table>' +
                    '<thead><tr><th class="time-col">Time</th>' + headerCells + '</tr></thead>' +
                    '<tbody>' + bodyRows + '</tbody>' +
                '</table>' +
            '</body></html>';
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

    private static String escapeHtml(String value) {
        return String.isBlank(value) ? '' : value.escapeHtml4();
    }

    private static String sanitizeFileName(String value) {
        String normalized = String.isBlank(value) ? 'weekly-schedule' : value.toLowerCase();
        normalized = normalized.replaceAll('[^a-z0-9]+', '-');
        normalized = normalized.replaceAll('^-+', '');
        normalized = normalized.replaceAll('-+$', '');
        return String.isBlank(normalized) ? 'weekly-schedule' : normalized;
    }
}