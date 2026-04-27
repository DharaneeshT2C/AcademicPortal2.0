public with sharing class KenTimetableManagementController {
    private static final List<String> COURSE_OFFERING_TEMPLATE_FIELD_CANDIDATES = new List<String>{
        'CourseOfferingScheduleTmplId',
        'CourseOfferingScheduleTemplate__c',
        'CourseOfferingScheduleTemplateId',
        'ScheduleTemplate__c',
        'TimetableTemplate__c'
    };
    private static final List<String> TEMPLATE_OBJECT_CANDIDATES = new List<String>{
        'CourseOfferingScheduleTmpl',
        'CourseOfferingScheduleTemplate__c',
        'CourseOfferingScheduleTemplate'
    };
    private static final List<String> TEMPLATE_ENTRY_OBJECT_CANDIDATES = new List<String>{
        'CourseOfferingScheduleTmpl',
        'CourseOfferingScheduleTemplateEntry__c',
        'CourseOfferingScheduleTemplateItem__c',
        'ScheduleTemplateEntry__c',
        'ScheduleTemplateItem__c'
    };
    private static final List<String> TEMPLATE_ENTRY_PARENT_FIELD_CANDIDATES = new List<String>{
        'CourseOfferingScheduleTmplId',
        'CourseOfferingScheduleTemplate__c',
        'CourseOfferingScheduleTemplateId',
        'ScheduleTemplate__c'
    };
    private static final List<String> TEMPLATE_ENTRY_START_FIELD_CANDIDATES = new List<String>{
        'StartTime__c',
        'Start_Time__c',
        'StartTime'
    };
    private static final List<String> TEMPLATE_ENTRY_END_FIELD_CANDIDATES = new List<String>{
        'EndTime__c',
        'End_Time__c',
        'EndTime'
    };
    private static final List<String> TEMPLATE_RECURRENCE_FIELD_CANDIDATES = new List<String>{
        'RecurrencePattern',
        'RecurrencePattern__c'
    };
    private static final List<String> TEMPLATE_START_DATE_FIELD_CANDIDATES = new List<String>{
        'StartDate',
        'Start_Date__c',
        'StartDate__c'
    };
    private static final List<String> TEMPLATE_END_DATE_FIELD_CANDIDATES = new List<String>{
        'EndDate',
        'End_Date__c',
        'EndDate__c'
    };
    private static final List<String> DESCRIPTION_FIELD_CANDIDATES = new List<String>{
        'Description',
        'Description__c'
    };
    private static final List<String> ROOM_FIELD_CANDIDATES = new List<String>{
        'Room__c',
        'Location__c',
        'Venue__c',
        'Classroom__c'
    };
    private static final List<DayDescriptor> WEEK_DAYS = new List<DayDescriptor>{
        new DayDescriptor('Monday', 'IsMonday', 'IsMonday__c', 1),
        new DayDescriptor('Tuesday', 'IsTuesday', 'IsTuesday__c', 2),
        new DayDescriptor('Wednesday', 'IsWednesday', 'IsWednesday__c', 3),
        new DayDescriptor('Thursday', 'IsThursday', 'IsThursday__c', 4),
        new DayDescriptor('Friday', 'IsFriday', 'IsFriday__c', 5),
        new DayDescriptor('Saturday', 'IsSaturday', 'IsSaturday__c', 6),
        new DayDescriptor('Sunday', 'IsSunday', 'IsSunday__c', 7)
    };
    
    public class TermOptionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }
    
    public class CourseOfferingRowDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public Id termId;
        @AuraEnabled public String name;
        @AuraEnabled public String termName;
        @AuraEnabled public String sessionName;
        @AuraEnabled public String courseName;
        @AuraEnabled public String courseCode;
        @AuraEnabled public String facultyName;
        @AuraEnabled public String status;
        @AuraEnabled public String type;
        @AuraEnabled public String offeringType;
        @AuraEnabled public Datetime lastUpdated;
    }
    
    public class ProgramPlanOptionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }
    
    public class BuilderDataDTO {
        @AuraEnabled public Id academicTermId;
        @AuraEnabled public String academicTermName;
        @AuraEnabled public Id focusCourseOfferingId;
        @AuraEnabled public Id selectedProgramPlanId;
        @AuraEnabled public List<ProgramPlanOptionDTO> programPlanOptions;
        @AuraEnabled public List<BuilderOfferingDTO> offerings;
        @AuraEnabled public List<BuilderScheduleEntryDTO> scheduledEntries;
        @AuraEnabled public List<String> timeSlots;
        @AuraEnabled public ValidationSummaryDTO validation;
    }
    
    public class BuilderOfferingDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String sessionName;
        @AuraEnabled public String courseName;
        @AuraEnabled public String courseCode;
        @AuraEnabled public Id facultyId;
        @AuraEnabled public String facultyName;
        @AuraEnabled public String type;
        @AuraEnabled public List<String> planEnrollmentTokens;
        @AuraEnabled public Boolean timetableLocked;
        @AuraEnabled public Boolean hasSchedules;
        @AuraEnabled public Integer scheduledEntryCount;
        @AuraEnabled public Id templateId;
        @AuraEnabled public String templateName;
        @AuraEnabled public String templateRecurrencePattern;
        @AuraEnabled public List<BuilderScheduleEntryDTO> templateEntries;
    }
    
    public class TemplateOptionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String recurrencePattern;
        @AuraEnabled public String startDate;
        @AuraEnabled public String endDate;
    }
    
    public class TemplateCreateResultDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String message;
    }

    public class LocationOptionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }
    
    public class BuilderScheduleEntryDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public Id courseOfferingId;
        @AuraEnabled public String offeringName;
        @AuraEnabled public String sessionName;
        @AuraEnabled public String courseName;
        @AuraEnabled public String courseCode;
        @AuraEnabled public Id facultyId;
        @AuraEnabled public String facultyName;
        @AuraEnabled public String type;
        @AuraEnabled public List<String> planEnrollmentTokens;
        @AuraEnabled public Boolean timetableLocked;
        @AuraEnabled public String dayName;
        @AuraEnabled public Integer dayNumber;
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
        @AuraEnabled public Integer durationMinutes;
        @AuraEnabled public String room;
        @AuraEnabled public String roomName;
        @AuraEnabled public String source;
        @AuraEnabled public String templateName;
    }
    
    public class ValidationSummaryDTO {
        @AuraEnabled public Integer totalOfferings;
        @AuraEnabled public Integer scheduledOfferings;
        @AuraEnabled public Integer unscheduledOfferings;
        @AuraEnabled public Integer templateLinkedOfferings;
        @AuraEnabled public Integer conflictCount;
        @AuraEnabled public List<String> warnings;
        @AuraEnabled public List<String> conflicts;
        @AuraEnabled public List<String> suggestions;
    }
    
    public class TimetableDetailDataDTO {
        @AuraEnabled public Id courseOfferingId;
        @AuraEnabled public String offeringName;
        @AuraEnabled public String courseCode;
        @AuraEnabled public String courseName;
        @AuraEnabled public String facultyName;
        @AuraEnabled public String type;
        @AuraEnabled public String createdByName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String lastModifiedByName;
        @AuraEnabled public Datetime lastModifiedDate;
        @AuraEnabled public Integer cohortCount;
        @AuraEnabled public Boolean timetableLocked;
        @AuraEnabled public Integer timetableVersion;
        @AuraEnabled public Integer totalSessions;
        @AuraEnabled public Integer assignedRooms;
        @AuraEnabled public Integer facultyAssigned;
        @AuraEnabled public Integer conflictCount;
        @AuraEnabled public List<String> timeSlots;
        @AuraEnabled public List<BuilderScheduleEntryDTO> scheduleEntries;
    }
    
    public class ProgramPlanWeeklyPreviewDTO {
        @AuraEnabled public Id academicTermId;
        @AuraEnabled public String academicTermName;
        @AuraEnabled public Id programPlanId;
        @AuraEnabled public String programPlanName;
        @AuraEnabled public Integer scheduledOfferingCount;
        @AuraEnabled public Integer totalSessions;
        @AuraEnabled public List<String> timeSlots;
        @AuraEnabled public List<BuilderScheduleEntryDTO> scheduleEntries;
    }
    
    public class TimetableActionResultDTO {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public TimetableDetailDataDTO detail;
    }
    
    public class SaveScheduleResultDTO {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Integer savedCount;
        @AuraEnabled public Integer totalScheduleCount;
        @AuraEnabled public String message;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<TermOptionDTO> getActiveTerms() {
        assertReadable(AcademicTerm.SObjectType, 'Read access is required for Academic Term.');
        
        List<TermOptionDTO> out = new List<TermOptionDTO>();
        for (AcademicTerm term : [
            SELECT Id, Name, Start_Year__c, End_Year__c, Sequence__c
            FROM AcademicTerm
            WHERE IsActive = true
            WITH USER_MODE
            ORDER BY Start_Year__c DESC, Sequence__c ASC, Name ASC
        ]) {
            TermOptionDTO dto = new TermOptionDTO();
            dto.id = term.Id;
            dto.name = buildTermLabel(term);
            out.add(dto);
        }
        return out;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<TemplateOptionDTO> getScheduleTemplateOptions() {
        TemplateSupport templateSupport = discoverTemplateSupport();
        return templateSupport.queryAllTemplateOptions();
    }

    @AuraEnabled(cacheable=true)
    public static List<LocationOptionDTO> getLocationOptions() {
        if (!Schema.Location.SObjectType.getDescribe().isAccessible()) {
            return new List<LocationOptionDTO>();
        }

        List<LocationOptionDTO> out = new List<LocationOptionDTO>();
        for (Schema.Location locationRow : [
            SELECT Id, Name
            FROM Location
            WITH USER_MODE
            ORDER BY Name
            LIMIT 500
        ]) {
            LocationOptionDTO option = new LocationOptionDTO();
            option.id = locationRow.Id;
            option.name = locationRow.Name;
            out.add(option);
        }
        return out;
    }

    @AuraEnabled
    public static TemplateCreateResultDTO createScheduleTemplate(
        String name,
    String recurrencePattern,
    String startDate,
    String endDate,
    String startTime,
    String endTime,
    String description,
    Boolean isMonday,
    Boolean isTuesday,
    Boolean isWednesday,
    Boolean isThursday,
    Boolean isFriday,
    Boolean isSaturday,
    Boolean isSunday
    ) {
        TemplateSupport templateSupport = discoverTemplateSupport();
        if (String.isBlank(templateSupport.templateObjectApiName)) {
            throw new AuraHandledException('Course offering schedule template object is not available.');
        }
        if (String.isBlank(name)) {
            throw new AuraHandledException('Template name is required.');
        }
        if (String.isBlank(startTime) || String.isBlank(endTime)) {
            throw new AuraHandledException('Start time and end time are required.');
        }
        
        Time parsedStartTime = parseTime(startTime);
        Time parsedEndTime = parseTime(endTime);
        if (parsedStartTime == null || parsedEndTime == null || parsedEndTime <= parsedStartTime) {
            throw new AuraHandledException('End time must be later than start time.');
        }
        
        if (!(Boolean.valueOf(isMonday) ||
            Boolean.valueOf(isTuesday) ||
            Boolean.valueOf(isWednesday) ||
            Boolean.valueOf(isThursday) ||
            Boolean.valueOf(isFriday) ||
            Boolean.valueOf(isSaturday) ||
        Boolean.valueOf(isSunday))) {
            throw new AuraHandledException('Select at least one active day for the template.');
        }
        
        Schema.SObjectType templateType = Schema.getGlobalDescribe().get(templateSupport.templateObjectApiName);
        if (templateType == null || !templateType.getDescribe().isCreateable()) {
            throw new AuraHandledException('Create access is required for schedule templates.');
        }
        
        Map<String, Schema.SObjectField> templateFields = templateType.getDescribe().fields.getMap();
        String templateStartTimeField = getExistingFieldName(
            templateFields,
        TEMPLATE_ENTRY_START_FIELD_CANDIDATES
            );
        String templateEndTimeField = getExistingFieldName(
            templateFields,
        TEMPLATE_ENTRY_END_FIELD_CANDIDATES
            );
        Date parsedStartDate = parseDateValue(startDate);
        Date parsedEndDate = parseDateValue(endDate);
        String normalizedRecurrencePattern = normalizeTemplateRecurrencePattern(recurrencePattern, parsedEndDate);
        
        Map<String, Boolean> dayValuesByLabel = new Map<String, Boolean>{
            'Monday' => Boolean.valueOf(isMonday),
            'Tuesday' => Boolean.valueOf(isTuesday),
            'Wednesday' => Boolean.valueOf(isWednesday),
            'Thursday' => Boolean.valueOf(isThursday),
            'Friday' => Boolean.valueOf(isFriday),
            'Saturday' => Boolean.valueOf(isSaturday),
            'Sunday' => Boolean.valueOf(isSunday)
        };
        
        SObject templateRecord = templateType.newSObject();
        validateDuplicateScheduleTemplate(
            templateSupport,
        templateFields,
        templateStartTimeField,
        templateEndTimeField,
        parsedStartDate,
        parsedEndDate,
        parsedStartTime,
        parsedEndTime,
        dayValuesByLabel
            );
        putFieldIfCreateable(templateRecord, templateFields, 'Name', name);
        putFieldIfCreateable(templateRecord, templateFields, templateSupport.templateRecurrenceField, normalizedRecurrencePattern);
        putFieldIfCreateable(templateRecord, templateFields, templateSupport.templateStartDateField, parsedStartDate);
        putFieldIfCreateable(templateRecord, templateFields, templateSupport.templateEndDateField, parsedEndDate);
        putFieldIfCreateable(
            templateRecord,
        templateFields,
        templateStartTimeField,
        parsedStartTime
            );
        putFieldIfCreateable(
            templateRecord,
        templateFields,
        templateEndTimeField,
        parsedEndTime
            );
        putFieldIfCreateable(
            templateRecord,
        templateFields,
        getExistingFieldName(templateFields, DESCRIPTION_FIELD_CANDIDATES),
        description
            );
        for (DayDescriptor descriptor : WEEK_DAYS) {
            String dayField = templateFields.containsKey(descriptor.scheduleFieldName)
                ? descriptor.scheduleFieldName
                : (templateFields.containsKey(descriptor.templateFieldName) ? descriptor.templateFieldName : null);
            putFieldIfCreateable(templateRecord, templateFields, dayField, dayValuesByLabel.get(descriptor.label));
        }
        
        insert templateRecord;
        
        TemplateCreateResultDTO result = new TemplateCreateResultDTO();
        result.id = (Id)templateRecord.get('Id');
        result.name = name;
        result.message = name + ' template created successfully.';
        return result;
    }
    
    @AuraEnabled(cacheable=true)
    public static TemplateOptionDTO getScheduleTemplateOption(Id templateId) {
        if (templateId == null) {
            return null;
        }
        TemplateSupport templateSupport = discoverTemplateSupport();
        Map<Id, TemplateOptionDTO> templateDetailsById = templateSupport.queryTemplateDetails(new Set<Id>{ templateId });
        return templateDetailsById.containsKey(templateId) ? templateDetailsById.get(templateId) : null;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<BuilderScheduleEntryDTO> getScheduleTemplateEntries(Id templateId, Id courseOfferingId) {
        if (templateId == null) {
            return new List<BuilderScheduleEntryDTO>();
        }
        
        BuilderOfferingDTO offeringDto = new BuilderOfferingDTO();
        if (courseOfferingId != null) {
            List<CourseOffering> offerings = [
                SELECT Id,
                       Name,
                       AcademicSession.Name,
                       LearningCourse.Name,
                       LearningCourse.CourseNumber,
                       PrimaryFacultyId,
                       PrimaryFaculty.Name
                FROM CourseOffering
                WHERE Id = :courseOfferingId
                WITH USER_MODE
                LIMIT 1
            ];
            if (!offerings.isEmpty()) {
                CourseOffering offering = offerings[0];
                offeringDto.id = offering.Id;
                offeringDto.name = String.isBlank(offering.Name)
                    ? (offering.LearningCourse == null ? 'Course Offering' : offering.LearningCourse.Name)
                    : offering.Name;
                offeringDto.sessionName = offering.AcademicSession == null ? null : offering.AcademicSession.Name;
                offeringDto.courseName = offering.LearningCourse == null ? null : offering.LearningCourse.Name;
                offeringDto.courseCode = offering.LearningCourse == null ? null : offering.LearningCourse.CourseNumber;
                offeringDto.facultyId = offering.PrimaryFacultyId;
                offeringDto.facultyName = offering.PrimaryFaculty == null ? null : offering.PrimaryFaculty.Name;
            }
        }
        
        TemplateSupport templateSupport = discoverTemplateSupport();
        Map<Id, TemplateOptionDTO> templateDetailsById = templateSupport.queryTemplateDetails(new Set<Id>{ templateId });
        Map<Id, List<BuilderScheduleEntryDTO>> templateEntriesByTemplateId =
            templateSupport.queryTemplateEntries(templateDetailsById);
        return templateEntriesByTemplateId.containsKey(templateId)
            ? cloneEntries(templateEntriesByTemplateId.get(templateId), offeringDto)
            : new List<BuilderScheduleEntryDTO>();
    }
    
    @AuraEnabled(cacheable=true)
    public static List<CourseOfferingRowDTO> getCourseOfferingsByTerm(Id academicTermId) {
        if (academicTermId == null) {
            return new List<CourseOfferingRowDTO>();
        }
        
        assertReadable(CourseOffering.SObjectType, 'Read access is required for Course Offering.');
        assertReadable(AcademicSession.SObjectType, 'Read access is required for Academic Session.');
        
        Set<Id> sessionIds = new Set<Id>();
        for (AcademicSession session : [
            SELECT Id
            FROM AcademicSession
            WHERE AcademicTermId = :academicTermId
            WITH USER_MODE
        ]) {
            sessionIds.add(session.Id);
        }
        
        if (sessionIds.isEmpty()) {
            return new List<CourseOfferingRowDTO>();
        }
        
        String courseTypeField = getExistingFieldName(
            CourseOffering.SObjectType.getDescribe().fields.getMap(),
        new List<String>{ 'Course_Type__c' }
        );
        String offeringTypeField = getExistingFieldName(
            CourseOffering.SObjectType.getDescribe().fields.getMap(),
        new List<String>{ 'OfferingType__c' }
        );
        
        List<String> selectParts = new List<String>{
            'Id',
            'Name',
            'IsActive',
            'LastModifiedDate',
            'AcademicSession.Name',
            'AcademicSession.AcademicTermId',
            'AcademicSession.AcademicTerm.Name',
            'LearningCourse.Name',
            'LearningCourse.CourseNumber',
            'PrimaryFaculty.Name'
        };
        if (String.isNotBlank(courseTypeField)) {
            selectParts.add(courseTypeField);
        }
        if (String.isNotBlank(offeringTypeField)) {
            selectParts.add(offeringTypeField);
        }
        
        String soql =
            'SELECT ' + String.join(selectParts, ', ') +
            ' FROM CourseOffering' +
            ' WHERE AcademicSessionId IN :sessionIds' +
            ' WITH USER_MODE' +
            ' ORDER BY AcademicSession.Name ASC, LearningCourse.CourseNumber ASC, Name ASC';
        
        List<CourseOffering> offeringRows = Database.query(soql);
        
        List<CourseOfferingRowDTO> out = new List<CourseOfferingRowDTO>();
        for (CourseOffering offering : offeringRows) {
            CourseOfferingRowDTO dto = new CourseOfferingRowDTO();
            dto.id = offering.Id;
            dto.termId = offering.AcademicSession == null ? null : offering.AcademicSession.AcademicTermId;
            dto.name = String.isNotBlank(offering.Name)
                ? offering.Name
                : (offering.LearningCourse == null ? null : offering.LearningCourse.Name);
            dto.termName =
                offering.AcademicSession == null || offering.AcademicSession.AcademicTerm == null
                ? null
                : offering.AcademicSession.AcademicTerm.Name;
            dto.sessionName = offering.AcademicSession == null ? null : offering.AcademicSession.Name;
            dto.courseName = offering.LearningCourse == null ? null : offering.LearningCourse.Name;
            dto.courseCode = offering.LearningCourse == null ? null : offering.LearningCourse.CourseNumber;
            dto.facultyName = offering.PrimaryFaculty == null ? null : offering.PrimaryFaculty.Name;
            dto.status = offering.IsActive ? 'Active' : 'Inactive';
            dto.type = String.isBlank(courseTypeField) ? null : String.valueOf(offering.get(courseTypeField));
            if (String.isBlank(dto.type)) {
                dto.type = 'Standard';
            }
            dto.offeringType = String.isBlank(offeringTypeField) ? null : String.valueOf(offering.get(offeringTypeField));
            dto.lastUpdated = offering.LastModifiedDate;
            out.add(dto);
        }
        return out;
    }
    
    @AuraEnabled
    public static TimetableDetailDataDTO getTimetableDetailData(Id courseOfferingId) {
        if (courseOfferingId == null) {
            throw new AuraHandledException('Course offering is required for preview.');
        }
        
        assertReadable(CourseOffering.SObjectType, 'Read access is required for Course Offering.');
        
        Map<String, Schema.SObjectField> offeringFieldMap = CourseOffering.SObjectType.getDescribe().fields.getMap();
        String offeringTypeField = getReadableFieldName(offeringFieldMap, new List<String>{ 'Course_Type__c', 'OfferingType__c' });
        String timetableLockedField = getReadableFieldName(offeringFieldMap, new List<String>{ 'Timetable_Locked__c' });
        String timetableVersionField = getReadableFieldName(offeringFieldMap, new List<String>{ 'Timetable_Version__c' });
        List<String> offeringFields = new List<String>{
            'Id',
            'Name',
            'CreatedDate',
            'CreatedBy.Name',
            'LastModifiedDate',
            'LastModifiedBy.Name',
            'AcademicSession.Name',
            'LearningCourse.Name',
            'LearningCourse.CourseNumber',
            'PrimaryFacultyId',
            'PrimaryFaculty.Name'
        };
        if (String.isNotBlank(offeringTypeField)) {
            offeringFields.add(offeringTypeField);
        }
        if (String.isNotBlank(timetableLockedField)) {
            offeringFields.add(timetableLockedField);
        }
        if (String.isNotBlank(timetableVersionField)) {
            offeringFields.add(timetableVersionField);
        }
        
        String offeringQuery =
            'SELECT ' + String.join(offeringFields, ', ') +
            ' FROM CourseOffering WHERE Id = :courseOfferingId WITH USER_MODE LIMIT 1';
        List<CourseOffering> offeringRows = Database.query(offeringQuery);
        if (offeringRows.isEmpty()) {
            throw new AuraHandledException('Course offering not found.');
        }
        
        CourseOffering offering = offeringRows[0];
        BuilderOfferingDTO offeringDto = new BuilderOfferingDTO();
        offeringDto.id = offering.Id;
        offeringDto.name = String.isBlank(offering.Name)
            ? (offering.LearningCourse == null ? 'Course Offering' : offering.LearningCourse.Name)
            : offering.Name;
        offeringDto.sessionName = offering.AcademicSession == null ? null : offering.AcademicSession.Name;
        offeringDto.courseName = offering.LearningCourse == null ? null : offering.LearningCourse.Name;
        offeringDto.courseCode = offering.LearningCourse == null ? null : offering.LearningCourse.CourseNumber;
        offeringDto.facultyId = offering.PrimaryFacultyId;
        offeringDto.facultyName = offering.PrimaryFaculty == null ? null : offering.PrimaryFaculty.Name;
        offeringDto.type = String.isBlank(offeringTypeField) ? 'Standard' : String.valueOf(offering.get(offeringTypeField));
        if (String.isBlank(offeringDto.type)) {
            offeringDto.type = 'Standard';
        }
        
        TemplateSupport templateSupport = discoverTemplateSupport();
        List<String> scheduleFields = new List<String>{
            'Id',
            'CourseOfferingId',
            'StartTime',
            'EndTime',
            'IsMonday',
            'IsTuesday',
            'IsWednesday',
            'IsThursday',
            'IsFriday',
            'IsSaturday',
            'IsSunday'
        };
        if (String.isNotBlank(templateSupport.scheduleRoomField)) {
            scheduleFields.add(templateSupport.scheduleRoomField);
        }
        
        List<BuilderScheduleEntryDTO> scheduleEntries = new List<BuilderScheduleEntryDTO>();
        String scheduleQuery =
            'SELECT ' + String.join(scheduleFields, ', ') +
            ' FROM CourseOfferingSchedule WHERE CourseOfferingId = :courseOfferingId WITH USER_MODE';
        for (SObject row : Database.query(scheduleQuery)) {
            scheduleEntries.addAll(expandScheduleRow(row, templateSupport.scheduleRoomField, 'Saved', null, offeringDto));
        }
        
        TimetableDetailDataDTO detail = new TimetableDetailDataDTO();
        detail.courseOfferingId = offering.Id;
        detail.offeringName = offeringDto.name;
        detail.courseCode = offeringDto.courseCode;
        detail.courseName = offeringDto.courseName;
        detail.facultyName = offeringDto.facultyName;
        detail.type = offeringDto.type;
        detail.createdByName = offering.CreatedBy == null ? null : offering.CreatedBy.Name;
        detail.createdDate = offering.CreatedDate;
        detail.lastModifiedByName = offering.LastModifiedBy == null ? null : offering.LastModifiedBy.Name;
        detail.lastModifiedDate = offering.LastModifiedDate;
        detail.cohortCount = countDistinctCohortsForOffering(courseOfferingId);
        detail.timetableLocked = getCheckboxValue(offering, timetableLockedField);
        detail.timetableVersion = getIntegerValue(offering, timetableVersionField, 1);
        detail.totalSessions = scheduleEntries.size();
        detail.assignedRooms = countDistinctRooms(scheduleEntries);
        detail.facultyAssigned = offeringDto.facultyId == null ? 0 : 1;
        detail.conflictCount = 0;
        detail.timeSlots = buildTimeSlots(scheduleEntries, new List<BuilderOfferingDTO>());
        detail.scheduleEntries = scheduleEntries;
        return detail;
    }
    
    @AuraEnabled(cacheable=true)
    public static ProgramPlanWeeklyPreviewDTO getProgramPlanWeeklyPreview(Id academicTermId, Id learningProgramPlanId) {
        ProgramPlanWeeklyPreviewDTO dto = new ProgramPlanWeeklyPreviewDTO();
        dto.academicTermId = academicTermId;
        dto.programPlanId = learningProgramPlanId;
        dto.scheduledOfferingCount = 0;
        dto.totalSessions = 0;
        dto.timeSlots = defaultTimeSlots();
        dto.scheduleEntries = new List<BuilderScheduleEntryDTO>();
        
        if (academicTermId == null || learningProgramPlanId == null) {
            return dto;
        }
        
        List<AcademicTerm> terms = [
            SELECT Id, Name, Start_Year__c, End_Year__c, Sequence__c
            FROM AcademicTerm
            WHERE Id = :academicTermId
            WITH USER_MODE
            LIMIT 1
        ];
        if (!terms.isEmpty()) {
            dto.academicTermName = buildTermLabel(terms[0]);
        }
        
        List<LearningProgramPlan> plans = [
            SELECT Id, Name
            FROM LearningProgramPlan
            WHERE Id = :learningProgramPlanId
            WITH USER_MODE
            LIMIT 1
        ];
        if (!plans.isEmpty()) {
            dto.programPlanName = plans[0].Name;
        }
        
        Set<Id> offeringIds = getOfferingIdsForProgramPlan(academicTermId, learningProgramPlanId);
        if (offeringIds.isEmpty()) {
            return dto;
        }
        
        TemplateSupport templateSupport = discoverTemplateSupport();
        Map<String, Schema.SObjectField> offeringFieldMap = CourseOffering.SObjectType.getDescribe().fields.getMap();
        String offeringTypeField = getReadableFieldName(offeringFieldMap, new List<String>{ 'Course_Type__c', 'OfferingType__c' });
        
        List<String> offeringFields = new List<String>{
            'Id',
            'Name',
            'AcademicSession.Name',
            'LearningCourse.Name',
            'LearningCourse.CourseNumber',
            'PrimaryFacultyId',
            'PrimaryFaculty.Name'
        };
        if (String.isNotBlank(offeringTypeField)) {
            offeringFields.add(offeringTypeField);
        }
        
        Map<Id, BuilderOfferingDTO> offeringsById = new Map<Id, BuilderOfferingDTO>();
        List<BuilderOfferingDTO> offerings = new List<BuilderOfferingDTO>();
        String offeringQuery =
            'SELECT ' + String.join(offeringFields, ', ') +
            ' FROM CourseOffering WHERE Id IN :offeringIds WITH USER_MODE' +
            ' ORDER BY AcademicSession.Name ASC, LearningCourse.CourseNumber ASC, Name ASC';
        for (CourseOffering offering : Database.query(offeringQuery)) {
            BuilderOfferingDTO offeringDto = new BuilderOfferingDTO();
            offeringDto.id = offering.Id;
            offeringDto.name = String.isBlank(offering.Name)
                ? (offering.LearningCourse == null ? 'Course Offering' : offering.LearningCourse.Name)
                : offering.Name;
            offeringDto.sessionName = offering.AcademicSession == null ? null : offering.AcademicSession.Name;
            offeringDto.courseName = offering.LearningCourse == null ? null : offering.LearningCourse.Name;
            offeringDto.courseCode = offering.LearningCourse == null ? null : offering.LearningCourse.CourseNumber;
            offeringDto.facultyId = offering.PrimaryFacultyId;
            offeringDto.facultyName = offering.PrimaryFaculty == null ? null : offering.PrimaryFaculty.Name;
            offeringDto.type = String.isBlank(offeringTypeField) ? 'Standard' : String.valueOf(offering.get(offeringTypeField));
            if (String.isBlank(offeringDto.type)) {
                offeringDto.type = 'Standard';
            }
            offeringsById.put(offering.Id, offeringDto);
            offerings.add(offeringDto);
        }
        
        List<String> scheduleFields = new List<String>{
            'Id',
            'CourseOfferingId',
            'StartTime',
            'EndTime',
            'IsMonday',
            'IsTuesday',
            'IsWednesday',
            'IsThursday',
            'IsFriday',
            'IsSaturday',
            'IsSunday'
        };
        if (String.isNotBlank(templateSupport.scheduleRoomField)) {
            scheduleFields.add(templateSupport.scheduleRoomField);
        }
        
        Set<Id> scheduledOfferingIds = new Set<Id>();
        Set<Id> scheduledScopeOfferingIds = offeringsById.keySet();
        String scheduleQuery =
            'SELECT ' + String.join(scheduleFields, ', ') +
            ' FROM CourseOfferingSchedule WHERE CourseOfferingId IN :scheduledScopeOfferingIds WITH USER_MODE';
        for (SObject row : Database.query(scheduleQuery)) {
            Id offeringId = (Id)row.get('CourseOfferingId');
            BuilderOfferingDTO offeringDto = offeringsById.get(offeringId);
            if (offeringDto == null) {
                continue;
            }
            List<BuilderScheduleEntryDTO> expanded = expandScheduleRow(row, templateSupport.scheduleRoomField, 'Saved', null, offeringDto);
            if (expanded.isEmpty()) {
                continue;
            }
            scheduledOfferingIds.add(offeringId);
            dto.scheduleEntries.addAll(expanded);
        }
        
        dto.scheduledOfferingCount = scheduledOfferingIds.size();
        dto.totalSessions = dto.scheduleEntries.size();
        dto.timeSlots = buildTimeSlots(dto.scheduleEntries, offerings);
        return dto;
    }
    
    @AuraEnabled
    public static TimetableActionResultDTO toggleTimetableLock(Id courseOfferingId) {
        if (courseOfferingId == null) {
            throw new AuraHandledException('Course offering is required.');
        }
        
        Map<String, Schema.SObjectField> offeringFieldMap = CourseOffering.SObjectType.getDescribe().fields.getMap();
        String timetableLockedField = getUpdateableFieldName(offeringFieldMap, new List<String>{ 'Timetable_Locked__c' });
        if (String.isBlank(timetableLockedField)) {
            throw new AuraHandledException('Timetable lock field is not available on Course Offering.');
        }
        
        String offeringQuery =
            'SELECT Id, ' + timetableLockedField +
            ' FROM CourseOffering WHERE Id = :courseOfferingId LIMIT 1';
        CourseOffering offering = Database.query(offeringQuery);
        offering.put(timetableLockedField, !getCheckboxValue(offering, timetableLockedField));
        update offering;
        
        TimetableActionResultDTO result = new TimetableActionResultDTO();
        result.success = true;
        result.detail = getTimetableDetailData(courseOfferingId);
        result.message = result.detail.timetableLocked ? 'Timetable locked.' : 'Timetable unlocked.';
        return result;
    }
    
    @AuraEnabled
    public static TimetableActionResultDTO publishProgramPlanTimetable(Id academicTermId, Id learningProgramPlanId) {
        if (academicTermId == null || learningProgramPlanId == null) {
            throw new AuraHandledException('Academic term and program plan are required.');
        }
        
        Map<String, Schema.SObjectField> junctionFields =
            Program_Plan_Course_Junction__c.SObjectType.getDescribe().fields.getMap();
        if (!junctionFields.containsKey('Timetable_Published__c')) {
            throw new AuraHandledException('Timetable Published field is not available on Program Plan Course Junction.');
        }
        assertUpdateable(Program_Plan_Course_Junction__c.SObjectType, 'Update access is required for Program Plan Course Junction.');
        
        Set<Id> offeringIds = getOfferingIdsForProgramPlan(academicTermId, learningProgramPlanId);
        if (offeringIds.isEmpty()) {
            throw new AuraHandledException('No course offerings are linked to the selected program plan in this term.');
        }
        
        List<Program_Plan_Course_Junction__c> junctions = [
            SELECT Id, Timetable_Published__c
            FROM Program_Plan_Course_Junction__c
            WHERE Learning_Program_Plan__c = :learningProgramPlanId
            AND Course_Offering__c IN :offeringIds
            WITH USER_MODE
        ];
        if (junctions.isEmpty()) {
            throw new AuraHandledException('No program plan course junction records were found to publish.');
        }
        
        for (Program_Plan_Course_Junction__c junction : junctions) {
            junction.Timetable_Published__c = true;
        }
        update junctions;
        
        TimetableActionResultDTO result = new TimetableActionResultDTO();
        result.success = true;
        result.message = 'Published weekly timetable for the selected program plan.';
        return result;
    }
    
    @AuraEnabled
    public static BuilderDataDTO getTimetableBuilderData(Id academicTermId, Id focusCourseOfferingId, Id learningProgramPlanId) {
        assertReadable(CourseOffering.SObjectType, 'Read access is required for Course Offering.');
        
        Id resolvedTermId = resolveAcademicTermId(academicTermId, focusCourseOfferingId);
        if (resolvedTermId == null) {
            BuilderDataDTO emptyDto = new BuilderDataDTO();
            emptyDto.programPlanOptions = new List<ProgramPlanOptionDTO>();
            emptyDto.offerings = new List<BuilderOfferingDTO>();
            emptyDto.scheduledEntries = new List<BuilderScheduleEntryDTO>();
            emptyDto.timeSlots = defaultTimeSlots();
            emptyDto.validation = new ValidationSummaryDTO();
            return emptyDto;
        }
        
        AcademicTerm term = [
            SELECT Id, Name, Start_Year__c, End_Year__c, Sequence__c
            FROM AcademicTerm
            WHERE Id = :resolvedTermId
            WITH USER_MODE
            LIMIT 1
        ];
        
        Set<Id> sessionIds = new Set<Id>();
        for (AcademicSession session : [
            SELECT Id
            FROM AcademicSession
            WHERE AcademicTermId = :resolvedTermId
            WITH USER_MODE
        ]) {
            sessionIds.add(session.Id);
        }
        
        BuilderDataDTO dto = new BuilderDataDTO();
        dto.academicTermId = resolvedTermId;
        dto.academicTermName = buildTermLabel(term);
        dto.focusCourseOfferingId = focusCourseOfferingId;
        dto.selectedProgramPlanId = learningProgramPlanId;
        dto.programPlanOptions = getProgramPlansForTerm(resolvedTermId);
        dto.offerings = new List<BuilderOfferingDTO>();
        dto.scheduledEntries = new List<BuilderScheduleEntryDTO>();
        dto.timeSlots = defaultTimeSlots();
        dto.validation = new ValidationSummaryDTO();
        
        if (sessionIds.isEmpty()) {
            dto.validation.warnings = new List<String>{ 'No academic sessions found for the selected term.' };
            dto.validation.conflicts = new List<String>();
            dto.validation.suggestions = new List<String>();
            return dto;
        }
        
        TemplateSupport templateSupport = discoverTemplateSupport();
        Map<String, Schema.SObjectField> offeringFieldMap = CourseOffering.SObjectType.getDescribe().fields.getMap();
        String offeringTypeField = getReadableFieldName(offeringFieldMap, new List<String>{ 'Course_Type__c', 'OfferingType__c' });
        String timetableLockedField = getReadableFieldName(offeringFieldMap, new List<String>{ 'Timetable_Locked__c' });
        List<String> offeringFields = new List<String>{
            'Id',
            'Name',
            'AcademicSession.Name',
            'LearningCourse.Name',
            'LearningCourse.CourseNumber',
            'PrimaryFacultyId',
            'PrimaryFaculty.Name'
        };
        if (String.isNotBlank(offeringTypeField)) {
            offeringFields.add(offeringTypeField);
        }
        if (String.isNotBlank(timetableLockedField)) {
            offeringFields.add(timetableLockedField);
        }
        if (templateSupport.hasOfferingTemplateLookup()) {
            offeringFields.add(templateSupport.offeringTemplateLookupField);
        }
        
        Map<Id, BuilderOfferingDTO> offeringsById = new Map<Id, BuilderOfferingDTO>();
        List<BuilderOfferingDTO> orderedOfferings = new List<BuilderOfferingDTO>();
        Map<Id, Id> templateIdByOfferingId = new Map<Id, Id>();
        Set<Id> allowedOfferingIds = getOfferingIdsForProgramPlan(resolvedTermId, learningProgramPlanId);
        if (learningProgramPlanId != null && allowedOfferingIds.isEmpty()) {
            dto.validation.warnings = new List<String>{ 'No course offerings are linked to the selected program plan in this term.' };
            dto.validation.conflicts = new List<String>();
            dto.validation.suggestions = new List<String>();
            return dto;
        }
        String offeringQuery =
            'SELECT ' + String.join(offeringFields, ', ') +
            ' FROM CourseOffering WHERE AcademicSessionId IN :sessionIds WITH USER_MODE' +
            ' ORDER BY AcademicSession.Name ASC, LearningCourse.CourseNumber ASC, Name ASC';
        for (CourseOffering offering : Database.query(offeringQuery)) {
            if (learningProgramPlanId != null && !allowedOfferingIds.contains(offering.Id)) {
                continue;
            }
            BuilderOfferingDTO offeringDto = new BuilderOfferingDTO();
            offeringDto.id = offering.Id;
            offeringDto.name = String.isBlank(offering.Name)
                ? (offering.LearningCourse == null ? 'Course Offering' : offering.LearningCourse.Name)
                : offering.Name;
            offeringDto.sessionName = offering.AcademicSession == null ? null : offering.AcademicSession.Name;
            offeringDto.courseName = offering.LearningCourse == null ? null : offering.LearningCourse.Name;
            offeringDto.courseCode = offering.LearningCourse == null ? null : offering.LearningCourse.CourseNumber;
            offeringDto.facultyId = offering.PrimaryFacultyId;
            offeringDto.facultyName = offering.PrimaryFaculty == null ? null : offering.PrimaryFaculty.Name;
            offeringDto.type = String.isBlank(offeringTypeField) ? 'Standard' : String.valueOf(offering.get(offeringTypeField));
            if (String.isBlank(offeringDto.type)) {
                offeringDto.type = 'Standard';
            }
            offeringDto.planEnrollmentTokens = new List<String>();
            offeringDto.timetableLocked = getCheckboxValue(offering, timetableLockedField);
            offeringDto.hasSchedules = false;
            offeringDto.scheduledEntryCount = 0;
            offeringDto.templateEntries = new List<BuilderScheduleEntryDTO>();
            if (templateSupport.hasOfferingTemplateLookup()) {
                Id templateId = (Id)offering.get(templateSupport.offeringTemplateLookupField);
                if (templateId != null) {
                    templateIdByOfferingId.put(offering.Id, templateId);
                }
            }
            offeringsById.put(offering.Id, offeringDto);
            orderedOfferings.add(offeringDto);
        }
        
        Map<Id, List<String>> planEnrollmentTokensByOfferingId = getOfferingPlanEnrollmentTokens(
            offeringsById.keySet(),
        resolvedTermId
            );
        for (Id offeringId : offeringsById.keySet()) {
            offeringsById.get(offeringId).planEnrollmentTokens = planEnrollmentTokensByOfferingId.containsKey(offeringId)
                ? planEnrollmentTokensByOfferingId.get(offeringId)
                : new List<String>();
        }
        
        Set<Id> templateIds = new Set<Id>();
        templateIds.addAll(templateIdByOfferingId.values());
        Map<Id, TemplateOptionDTO> templateDetailsById = templateSupport.queryTemplateDetails(templateIds);
        Map<Id, List<BuilderScheduleEntryDTO>> templateEntriesByTemplateId = templateSupport.queryTemplateEntries(
            templateDetailsById
            );
        for (Id offeringId : templateIdByOfferingId.keySet()) {
            BuilderOfferingDTO offeringDto = offeringsById.get(offeringId);
            Id templateId = templateIdByOfferingId.get(offeringId);
            offeringDto.templateId = templateId;
            TemplateOptionDTO templateDetail = templateDetailsById.get(templateId);
            offeringDto.templateName = templateDetail == null ? null : templateDetail.name;
            offeringDto.templateRecurrencePattern = templateDetail == null ? null : templateDetail.recurrencePattern;
            if (templateEntriesByTemplateId.containsKey(templateId)) {
                offeringDto.templateEntries = cloneEntries(templateEntriesByTemplateId.get(templateId), offeringDto);
            }
        }
        
        List<String> scheduleFields = new List<String>{
            'Id',
            'CourseOfferingId',
            'StartTime',
            'EndTime',
            'IsMonday',
            'IsTuesday',
            'IsWednesday',
            'IsThursday',
            'IsFriday',
            'IsSaturday',
            'IsSunday'
        };
        if (String.isNotBlank(templateSupport.scheduleRoomField)) {
            scheduleFields.add(templateSupport.scheduleRoomField);
        }
        
        if (!offeringsById.isEmpty()) {
            Set<Id> offeringIds = offeringsById.keySet();
            String scheduleQuery =
                'SELECT ' + String.join(scheduleFields, ', ') +
                ' FROM CourseOfferingSchedule WHERE CourseOfferingId IN :offeringIds WITH USER_MODE';
            for (SObject row : Database.query(scheduleQuery)) {
                Id offeringId = (Id)row.get('CourseOfferingId');
                BuilderOfferingDTO offeringDto = offeringsById.get(offeringId);
                if (offeringDto == null) {
                    continue;
                }
                List<BuilderScheduleEntryDTO> expanded = expandScheduleRow(row, templateSupport.scheduleRoomField, 'Saved', null, offeringDto);
                if (expanded.isEmpty()) {
                    continue;
                }
                offeringDto.hasSchedules = true;
                offeringDto.scheduledEntryCount += expanded.size();
                dto.scheduledEntries.addAll(expanded);
            }
        }
        
        dto.offerings = orderedOfferings;
        dto.timeSlots = buildTimeSlots(dto.scheduledEntries, dto.offerings);
        dto.validation = buildValidationSummary(dto.offerings, dto.scheduledEntries, dto.programPlanOptions);
        return dto;
    }
    
    public static BuilderDataDTO getTimetableBuilderData(Id academicTermId, Id focusCourseOfferingId) {
        return getTimetableBuilderData(academicTermId, focusCourseOfferingId, null);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<ProgramPlanOptionDTO> getProgramPlansForTerm(Id academicTermId) {
        List<ProgramPlanOptionDTO> out = new List<ProgramPlanOptionDTO>();
        if (academicTermId == null) {
            return out;
        }
        
        Set<Id> planIds = new Set<Id>();
        for (Program_Plan_Course_Junction__c junction : [
            SELECT Learning_Program_Plan__c
            FROM Program_Plan_Course_Junction__c
            WHERE Learning_Program_Plan__c != null
            AND Course_Offering__r.AcademicSession.AcademicTermId = :academicTermId
            WITH USER_MODE
        ]) {
            if (junction.Learning_Program_Plan__c != null) {
                planIds.add(junction.Learning_Program_Plan__c);
            }
        }
        
        if (planIds.isEmpty()) {
            return out;
        }
        
        for (LearningProgramPlan plan : [
            SELECT Id, Name
            FROM LearningProgramPlan
            WHERE Id IN :planIds
            WITH USER_MODE
            ORDER BY Name
        ]) {
            ProgramPlanOptionDTO dto = new ProgramPlanOptionDTO();
            dto.id = plan.Id;
            dto.name = plan.Name;
            out.add(dto);
        }
        return out;
    }
    
    @AuraEnabled
    public static SaveScheduleResultDTO saveCourseOfferingSchedules(
        Id courseOfferingId,
    String scheduleEntriesJson,
    Id templateId,
    String templateRecurrencePattern,
    String templateStartDate,
    String templateEndDate
    ) {
        if (courseOfferingId == null) {
            throw new AuraHandledException('Course offering is required.');
        }
        
        List<Object> requestedEntries = String.isBlank(scheduleEntriesJson)
            ? new List<Object>()
            : (List<Object>)JSON.deserializeUntyped(scheduleEntriesJson);
        
        Map<String, Schema.SObjectField> offeringFieldMap = CourseOffering.SObjectType.getDescribe().fields.getMap();
        String timetableLockedField = getReadableFieldName(offeringFieldMap, new List<String>{ 'Timetable_Locked__c' });
        List<String> offeringFields = new List<String>{ 'Id', 'Name', 'AcademicSession.AcademicTermId' };
        if (String.isNotBlank(timetableLockedField)) {
            offeringFields.add(timetableLockedField);
        }
        String offeringQuery =
            'SELECT ' + String.join(offeringFields, ', ') +
            ' FROM CourseOffering WHERE Id = :courseOfferingId LIMIT 1';
        CourseOffering offering = Database.query(offeringQuery);
        if (getCheckboxValue(offering, timetableLockedField)) {
            throw new AuraHandledException('This course offering timetable is locked. Unlock it before editing.');
        }
        
        TemplateSupport templateSupport = discoverTemplateSupport();
        List<CourseOfferingSchedule> existingSchedules = [
            SELECT Id,
                   CourseOfferingId,
                   StartTime,
                   EndTime,
                   IsMonday,
                   IsTuesday,
                   IsWednesday,
                   IsThursday,
                   IsFriday,
                   IsSaturday,
                   IsSunday
                   ,Description
                   FROM CourseOfferingSchedule
                   WHERE CourseOfferingId = :offering.Id
        ];
        
        Map<Id, CourseOfferingSchedule> existingById = new Map<Id, CourseOfferingSchedule>(existingSchedules);
        Map<String, Id> existingScheduleIdByDay = new Map<String, Id>();
        for (CourseOfferingSchedule existingSchedule : existingSchedules) {
            for (String activeDayName : getActiveDayNames(existingSchedule)) {
                existingScheduleIdByDay.put(activeDayName, existingSchedule.Id);
            }
        }
        
        List<CourseOfferingSchedule> schedulesToInsert = new List<CourseOfferingSchedule>();
        List<CourseOfferingSchedule> schedulesToUpdate = new List<CourseOfferingSchedule>();
        Set<Id> retainedScheduleIds = new Set<Id>();
        Set<Id> consumedScheduleIds = new Set<Id>();
        Set<String> requestedDays = new Set<String>();
        Map<String, ConsolidatedScheduleRequest> requestBySignature = new Map<String, ConsolidatedScheduleRequest>();
        for (Object rawEntry : requestedEntries) {
            if (rawEntry == null || !(rawEntry instanceof Map<String, Object>)) {
                continue;
            }
            
            Map<String, Object> entry = (Map<String, Object>)rawEntry;
            String scheduleIdValue = entry.containsKey('id') ? safeString(entry.get('id')) : null;
            String dayName = entry.containsKey('dayName') ? safeString(entry.get('dayName')) : null;
            String startTimeValue = entry.containsKey('startTime') ? safeString(entry.get('startTime')) : null;
            String endTimeValue = entry.containsKey('endTime') ? safeString(entry.get('endTime')) : null;
            String roomValue = entry.containsKey('room') ? safeString(entry.get('room')) : null;
            
            String trimmedDay = String.isBlank(dayName) ? null : dayName.trim();
            if (String.isBlank(trimmedDay) || String.isBlank(startTimeValue) || String.isBlank(endTimeValue)) {
                throw new AuraHandledException('Each schedule row requires a day, start time, and end time.');
            }
            if (requestedDays.contains(trimmedDay)) {
                throw new AuraHandledException('Only one schedule is allowed for ' + trimmedDay + ' in this course offering.');
            }
            requestedDays.add(trimmedDay);
            
            DayDescriptor descriptor = getDayDescriptor(trimmedDay);
            if (descriptor == null) {
                throw new AuraHandledException('Unsupported day value: ' + trimmedDay);
            }
            
            Time startTime = parseTime(startTimeValue);
            Time endTime = parseTime(endTimeValue);
            if (startTime == null || endTime == null || endTime <= startTime) {
                throw new AuraHandledException('End time must be later than start time.');
            }
            
            String signature = buildScheduleSignature(startTime, endTime, roomValue);
            if (!requestBySignature.containsKey(signature)) {
                requestBySignature.put(signature, new ConsolidatedScheduleRequest(startTime, endTime, roomValue));
            }
            ConsolidatedScheduleRequest requestGroup = requestBySignature.get(signature);
            requestGroup.dayNames.add(trimmedDay);
            requestGroup.scheduleIds.add(toId(scheduleIdValue));
        }
        
        for (ConsolidatedScheduleRequest requestGroup : requestBySignature.values()) {
            Set<Id> candidateIds = new Set<Id>();
            for (Id scheduleId : requestGroup.scheduleIds) {
                if (scheduleId != null && existingById.containsKey(scheduleId)) {
                    candidateIds.add(scheduleId);
                }
            }
            for (String dayName : requestGroup.dayNames) {
                if (existingScheduleIdByDay.containsKey(dayName)) {
                    candidateIds.add(existingScheduleIdByDay.get(dayName));
                }
            }
            
            CourseOfferingSchedule targetSchedule;
            for (Id candidateId : candidateIds) {
                if (!consumedScheduleIds.contains(candidateId)) {
                    targetSchedule = existingById.get(candidateId);
                    break;
                }
            }
            
            if (targetSchedule != null) {
                consumedScheduleIds.add(targetSchedule.Id);
                retainedScheduleIds.add(targetSchedule.Id);
                targetSchedule.StartTime = requestGroup.startTime;
                targetSchedule.EndTime = requestGroup.endTime;
                targetSchedule.Description = buildScheduleDescription(requestGroup.dayNames, requestGroup.startTime, requestGroup.endTime);
                applyDays(targetSchedule, requestGroup.dayNames);
                if (String.isNotBlank(templateSupport.scheduleRoomField)) {
                    targetSchedule.put(templateSupport.scheduleRoomField, requestGroup.room);
                }
                schedulesToUpdate.add(targetSchedule);
            } else {
                CourseOfferingSchedule schedule = new CourseOfferingSchedule();
                schedule.CourseOfferingId = offering.Id;
                schedule.Description = buildScheduleDescription(requestGroup.dayNames, requestGroup.startTime, requestGroup.endTime);
                schedule.StartTime = requestGroup.startTime;
                schedule.EndTime = requestGroup.endTime;
                applyDays(schedule, requestGroup.dayNames);
                if (String.isNotBlank(templateSupport.scheduleRoomField)) {
                    schedule.put(templateSupport.scheduleRoomField, requestGroup.room);
                }
                schedulesToInsert.add(schedule);
            }
        }
        
        if (!requestedEntries.isEmpty() && schedulesToInsert.isEmpty() && schedulesToUpdate.isEmpty()) {
            throw new AuraHandledException('No valid schedule rows were received from the screen.');
        }
        
        validateGridOverlap(offering, requestBySignature.values());
        
        Savepoint savepoint = Database.setSavepoint();
        try {
            List<CourseOfferingSchedule> schedulesToDelete = new List<CourseOfferingSchedule>();
            for (CourseOfferingSchedule existingSchedule : existingSchedules) {
                if (!retainedScheduleIds.contains(existingSchedule.Id)) {
                    schedulesToDelete.add(existingSchedule);
                }
            }
            
            if (!schedulesToDelete.isEmpty()) {
                delete schedulesToDelete;
            }
            
            if (!schedulesToUpdate.isEmpty()) {
                update schedulesToUpdate;
            }
            
            if (!schedulesToInsert.isEmpty()) {
                insert schedulesToInsert;
            }
            
            List<SObject> metadataUpdates = new List<SObject>();
            if (templateSupport.hasOfferingTemplateLookup()) {
                CourseOffering statusUpdate = new CourseOffering(Id = offering.Id);
                statusUpdate.put(templateSupport.offeringTemplateLookupField, templateId);
                metadataUpdates.add(statusUpdate);
            }
            
            if (Program_Plan_Course_Junction__c.SObjectType.getDescribe().isUpdateable() &&
            Program_Plan_Course_Junction__c.SObjectType.getDescribe().fields.getMap().containsKey('Timetable_Published__c')) {
                List<Program_Plan_Course_Junction__c> junctionsToUnpublish = [
                    SELECT Id, Timetable_Published__c
                    FROM Program_Plan_Course_Junction__c
                    WHERE Course_Offering__c = :offering.Id
                    WITH USER_MODE
                ];
                for (Program_Plan_Course_Junction__c junction : junctionsToUnpublish) {
                    junction.Timetable_Published__c = false;
                }
                if (!junctionsToUnpublish.isEmpty()) {
                    update junctionsToUnpublish;
                }
            }
            
            if (templateId != null && String.isNotBlank(templateSupport.templateObjectApiName)) {
                SObject templateUpdate = Schema.getGlobalDescribe().get(templateSupport.templateObjectApiName).newSObject(templateId);
                Boolean shouldUpdateTemplate = false;
                if (String.isNotBlank(templateSupport.templateRecurrenceField)) {
                    templateUpdate.put(templateSupport.templateRecurrenceField, templateRecurrencePattern);
                    shouldUpdateTemplate = true;
                }
                if (String.isNotBlank(templateSupport.templateStartDateField) && String.isNotBlank(templateStartDate)) {
                    templateUpdate.put(templateSupport.templateStartDateField, Date.valueOf(templateStartDate));
                    shouldUpdateTemplate = true;
                }
                if (String.isNotBlank(templateSupport.templateEndDateField) && String.isNotBlank(templateEndDate)) {
                    templateUpdate.put(templateSupport.templateEndDateField, Date.valueOf(templateEndDate));
                    shouldUpdateTemplate = true;
                }
                if (shouldUpdateTemplate) {
                    metadataUpdates.add(templateUpdate);
                }
            }
            
            if (!metadataUpdates.isEmpty()) {
                update metadataUpdates;
            }
            
            Integer totalScheduleCount = [
                SELECT Count()
                FROM CourseOfferingSchedule
                WHERE CourseOfferingId = :offering.Id
            ];
            
            SaveScheduleResultDTO result = new SaveScheduleResultDTO();
            result.success = true;
            result.savedCount = schedulesToInsert.size() + schedulesToUpdate.size();
            result.totalScheduleCount = totalScheduleCount;
            result.message =
                'Saved ' + result.savedCount + ' schedule change(s). ' +
                totalScheduleCount + ' CourseOfferingSchedule row(s) now exist for ' + offering.Name + '.';
            return result;
        } catch (Exception e) {
            Database.rollback(savepoint);
            throw new AuraHandledException(normalizeDmlError(e));
        }
    }
    
    public static SaveScheduleResultDTO saveCourseOfferingSchedules(
        Id courseOfferingId,
    String scheduleEntriesJson
    ) {
        return saveCourseOfferingSchedules(courseOfferingId, scheduleEntriesJson, null, null, null, null);
    }
    
    private static BuilderDataDTO emptyBuilderState() {
        BuilderDataDTO dto = new BuilderDataDTO();
        dto.offerings = new List<BuilderOfferingDTO>();
        dto.scheduledEntries = new List<BuilderScheduleEntryDTO>();
        dto.timeSlots = defaultTimeSlots();
        dto.validation = new ValidationSummaryDTO();
        return dto;
    }
    
    private static Id resolveAcademicTermId(Id academicTermId, Id focusCourseOfferingId) {
        if (academicTermId != null) {
            return academicTermId;
        }
        if (focusCourseOfferingId == null) {
            return null;
        }
        
        List<CourseOffering> offerings = [
            SELECT AcademicSession.AcademicTermId
            FROM CourseOffering
            WHERE Id = :focusCourseOfferingId
            WITH USER_MODE
            LIMIT 1
        ];
        if (offerings.isEmpty() || offerings[0].AcademicSession == null) {
            return null;
        }
        return offerings[0].AcademicSession.AcademicTermId;
    }
    
    private static ValidationSummaryDTO buildValidationSummary(
        List<BuilderOfferingDTO> offerings,
    List<BuilderScheduleEntryDTO> scheduledEntries,
    List<ProgramPlanOptionDTO> planOptions
    ) {
        ValidationSummaryDTO summary = new ValidationSummaryDTO();
        summary.totalOfferings = offerings.size();
        summary.scheduledOfferings = 0;
        summary.unscheduledOfferings = 0;
        summary.templateLinkedOfferings = 0;
        summary.conflictCount = 0;
        summary.warnings = new List<String>();
        summary.conflicts = new List<String>();
        summary.suggestions = new List<String>();
        
        for (BuilderOfferingDTO offering : offerings) {
            if (offering.hasSchedules) {
                summary.scheduledOfferings++;
            } else {
                summary.unscheduledOfferings++;
            }
            if (offering.templateId != null) {
                summary.templateLinkedOfferings++;
            }
        }
        
        Map<String, String> conflictMessages = new Map<String, String>();
        for (Integer index = 0; index < scheduledEntries.size(); index++) {
            BuilderScheduleEntryDTO currentEntry = scheduledEntries[index];
            for (Integer compareIndex = index + 1; compareIndex < scheduledEntries.size(); compareIndex++) {
                BuilderScheduleEntryDTO otherEntry = scheduledEntries[compareIndex];
                if (currentEntry.courseOfferingId == otherEntry.courseOfferingId ||
                    currentEntry.facultyId == null ||
                    currentEntry.facultyId != otherEntry.facultyId ||
                    currentEntry.dayNumber != otherEntry.dayNumber ||
                !timesOverlap(currentEntry.startTime, currentEntry.endTime, otherEntry.startTime, otherEntry.endTime)) {
                    continue;
                }
                
                String key = currentEntry.courseOfferingId + ':' + otherEntry.courseOfferingId + ':' + currentEntry.dayName;
                if (!conflictMessages.containsKey(key)) {
                    conflictMessages.put(
                        key,
                    (String.isBlank(currentEntry.facultyName) ? 'Faculty conflict' : currentEntry.facultyName) +
                        ' is double-booked on ' + currentEntry.dayName +
                        ' between ' + currentEntry.startTime + ' and ' + currentEntry.endTime + '.'
                        );
                }
            }
        }
        summary.conflicts.addAll(conflictMessages.values());
        summary.conflictCount = summary.conflicts.size();
        
        // Elective alignment check:
        // All elective offerings for the same program plan on the same day must share
        // the same time slot so students choosing between electives are not split across
        // different weekly schedules.
        Map<String, String> planNameById = new Map<String, String>();
        if (planOptions != null) {
            for (ProgramPlanOptionDTO opt : planOptions) {
                if (opt != null && opt.id != null) {
                    planNameById.put(String.valueOf(opt.id), opt.name);
                }
            }
        }
        // Key: planId|dayNumber  →  Set of "startTime|endTime" values seen for elective offerings
        Map<String, Set<String>> electiveTimesByPlanDay = new Map<String, Set<String>>();
        for (BuilderScheduleEntryDTO entry : scheduledEntries) {
            if (entry.planEnrollmentTokens == null) {
                continue;
            }
            for (String token : entry.planEnrollmentTokens) {
                if (String.isBlank(token) || !token.contains('|')) {
                    continue;
                }
                List<String> parts = token.split('\\|');
                if (parts.size() < 2 || !isElectiveEnrollmentType(parts[1])) {
                    continue;
                }
                String planId = parts[0];
                String planDayKey = planId + '|' + entry.dayNumber;
                String timeValue = entry.startTime + '|' + entry.endTime;
                if (!electiveTimesByPlanDay.containsKey(planDayKey)) {
                    electiveTimesByPlanDay.put(planDayKey, new Set<String>());
                }
                electiveTimesByPlanDay.get(planDayKey).add(timeValue);
            }
        }
        Set<String> warnedElectivePlanIds = new Set<String>();
        for (String planDayKey : electiveTimesByPlanDay.keySet()) {
            if (electiveTimesByPlanDay.get(planDayKey).size() > 1) {
                String planId = planDayKey.split('\\|')[0];
                if (!warnedElectivePlanIds.contains(planId)) {
                    warnedElectivePlanIds.add(planId);
                    String planLabel = planNameById.containsKey(planId)
                        ? '"' + planNameById.get(planId) + '"'
                        : 'a program plan';
                    summary.warnings.add(
                        'Elective offerings for ' + planLabel + ' are scheduled at different times on the same day. ' +
                        'All electives for the same plan must share one time slot so students can choose between them.'
                        );
                }
            }
        }
        
        if (summary.unscheduledOfferings > 0) {
            summary.warnings.add(summary.unscheduledOfferings + ' course offering(s) still need a timetable.');
        }
        if (summary.templateLinkedOfferings > 0) {
            summary.suggestions.add(summary.templateLinkedOfferings + ' offering(s) have linked schedule templates ready to apply.');
        }
        if (summary.scheduledOfferings > 0) {
            summary.suggestions.add('Open any scheduled course to adjust day-specific timings before publishing.');
        }
        return summary;
    }
    
    private static void validateGridOverlap(
        CourseOffering offering,
    List<ConsolidatedScheduleRequest> requestedGroups
    ) {
        if (offering == null ||
            offering.AcademicSession == null ||
            offering.AcademicSession.AcademicTermId == null ||
            requestedGroups == null ||
        requestedGroups.isEmpty()) {
            return;
        }
        
        List<CourseOfferingSchedule> existingSchedules = [
            SELECT CourseOfferingId,
                   CourseOffering.Name,
                   StartTime,
                   EndTime,
                   IsMonday,
                   IsTuesday,
                   IsWednesday,
                   IsThursday,
                   IsFriday,
                   IsSaturday,
                   IsSunday
            FROM CourseOfferingSchedule
            WHERE CourseOfferingId != :offering.Id
            AND CourseOffering.AcademicSession.AcademicTermId = :offering.AcademicSession.AcademicTermId
            AND StartTime != null
            AND EndTime != null
        ];
        
        Set<Id> comparisonOfferingIds = new Set<Id>{ offering.Id };
        for (CourseOfferingSchedule existingSchedule : existingSchedules) {
            if (existingSchedule.CourseOfferingId != null) {
                comparisonOfferingIds.add(existingSchedule.CourseOfferingId);
            }
        }
        Map<Id, List<String>> planEnrollmentTokensByOfferingId = getOfferingPlanEnrollmentTokens(
            comparisonOfferingIds,
        offering.AcademicSession.AcademicTermId
            );
        List<String> currentOfferingTokens = planEnrollmentTokensByOfferingId.get(offering.Id);
        
        for (CourseOfferingSchedule existingSchedule : existingSchedules) {
            if (!shouldBlockOverlap(
                currentOfferingTokens,
            planEnrollmentTokensByOfferingId.get(existingSchedule.CourseOfferingId)
            )) {
                continue;
            }
            Set<String> existingDays = new Set<String>(getActiveDayNames(existingSchedule));
            if (existingDays.isEmpty()) {
                continue;
            }
            
            for (ConsolidatedScheduleRequest requestGroup : requestedGroups) {
                if (requestGroup == null || requestGroup.startTime == null || requestGroup.endTime == null) {
                    continue;
                }
                
                if (!timesOverlap(
                    formatTime24(requestGroup.startTime),
                formatTime24(requestGroup.endTime),
                formatTime24(existingSchedule.StartTime),
                formatTime24(existingSchedule.EndTime)
                )) {
                    continue;
                }
                
                for (String requestedDay : requestGroup.dayNames) {
                    if (existingDays.contains(requestedDay)) {
                        throw new AuraHandledException(
                            'Schedule overlaps with ' + existingSchedule.CourseOffering.Name +
                            ' on ' + requestedDay +
                            ' between ' + formatTime24(existingSchedule.StartTime) +
                            ' and ' + formatTime24(existingSchedule.EndTime) + '.'
                            );
                    }
                }
            }
        }
    }
    
    private static List<String> buildTimeSlots(
        List<BuilderScheduleEntryDTO> scheduledEntries,
    List<BuilderOfferingDTO> offerings
    ) {
        Set<String> slots = new Set<String>();
        for (String defaultSlot : defaultTimeSlots()) {
            slots.add(defaultSlot);
        }
        for (BuilderScheduleEntryDTO entry : scheduledEntries) {
            if (String.isNotBlank(entry.startTime)) {
                slots.add(entry.startTime);
            }
        }
        for (BuilderOfferingDTO offering : offerings) {
            if (offering.templateEntries == null) {
                continue;
            }
            for (BuilderScheduleEntryDTO entry : offering.templateEntries) {
                if (String.isNotBlank(entry.startTime)) {
                    slots.add(entry.startTime);
                }
            }
        }
        
        List<String> sortedSlots = new List<String>(slots);
        sortedSlots.sort();
        return sortedSlots;
    }
    
    private static List<String> defaultTimeSlots() {
        List<String> slots = new List<String>();
        for (Integer hourValue = 8; hourValue <= 18; hourValue++) {
            slots.add((hourValue < 10 ? '0' : '') + hourValue + ':00');
            if (hourValue < 18) {
                slots.add((hourValue < 10 ? '0' : '') + hourValue + ':30');
            }
        }
        return slots;
    }
    
    private static List<BuilderScheduleEntryDTO> cloneEntries(
        List<BuilderScheduleEntryDTO> sourceEntries,
    BuilderOfferingDTO offering
    ) {
        List<BuilderScheduleEntryDTO> cloned = new List<BuilderScheduleEntryDTO>();
        for (BuilderScheduleEntryDTO source : sourceEntries) {
            BuilderScheduleEntryDTO item = new BuilderScheduleEntryDTO();
            item.courseOfferingId = offering.id;
            item.offeringName = offering.name;
            item.sessionName = offering.sessionName;
            item.courseName = offering.courseName;
            item.courseCode = offering.courseCode;
            item.facultyId = offering.facultyId;
            item.facultyName = offering.facultyName;
            item.type = offering.type;
            item.planEnrollmentTokens = offering.planEnrollmentTokens == null
                ? new List<String>()
                : new List<String>(offering.planEnrollmentTokens);
            item.timetableLocked = offering.timetableLocked;
            item.dayName = source.dayName;
            item.dayNumber = source.dayNumber;
            item.startTime = source.startTime;
            item.endTime = source.endTime;
            item.durationMinutes = source.durationMinutes;
            item.room = source.room;
            item.roomName = source.roomName;
            item.source = 'Template';
            item.templateName = offering.templateName;
            cloned.add(item);
        }
        return cloned;
    }
    
    private static List<BuilderScheduleEntryDTO> expandScheduleRow(
        SObject row,
    String roomField,
    String source,
    String templateName,
    BuilderOfferingDTO offering
    ) {
        Time startTime = (Time)row.get('StartTime');
        Time endTime = (Time)row.get('EndTime');
        if (startTime == null || endTime == null) {
            return new List<BuilderScheduleEntryDTO>();
        }
        
        String room = String.isBlank(roomField) ? null : safeString(row.get(roomField));
        List<DayDescriptor> activeDays = getActiveDays(row, false);
        if (activeDays.isEmpty()) {
            return new List<BuilderScheduleEntryDTO>();
        }
        
        List<BuilderScheduleEntryDTO> items = new List<BuilderScheduleEntryDTO>();
        for (DayDescriptor descriptor : activeDays) {
            BuilderScheduleEntryDTO item = new BuilderScheduleEntryDTO();
            item.id = (Id)row.get('Id');
            item.courseOfferingId = offering.id;
            item.offeringName = offering.name;
            item.sessionName = offering.sessionName;
            item.courseName = offering.courseName;
            item.courseCode = offering.courseCode;
            item.facultyId = offering.facultyId;
            item.facultyName = offering.facultyName;
            item.type = offering.type;
            item.planEnrollmentTokens = offering.planEnrollmentTokens == null
                ? new List<String>()
                : new List<String>(offering.planEnrollmentTokens);
            item.timetableLocked = offering.timetableLocked;
            item.dayName = descriptor.label;
            item.dayNumber = descriptor.dayNumber;
            item.startTime = formatTime24(startTime);
            item.endTime = formatTime24(endTime);
            item.durationMinutes = calculateDuration(startTime, endTime);
            item.room = room;
            item.roomName = room;
            item.source = source;
            item.templateName = templateName;
            items.add(item);
        }
        return items;
    }
    
    private static Integer calculateDuration(Time startTime, Time endTime) {
        return ((endTime.hour() * 60) + endTime.minute()) - ((startTime.hour() * 60) + startTime.minute());
    }
    
    private static List<DayDescriptor> getActiveDays(SObject row, Boolean fallbackToAllDays) {
        List<DayDescriptor> days = new List<DayDescriptor>();
        for (DayDescriptor descriptor : WEEK_DAYS) {
            if (getBooleanField(row, descriptor.scheduleFieldName) || getBooleanField(row, descriptor.templateFieldName)) {
                days.add(descriptor);
            }
        }
        if (days.isEmpty() && fallbackToAllDays) {
            days.addAll(WEEK_DAYS);
        }
        return days;
    }
    
    private static Boolean getBooleanField(SObject row, String fieldName) {
        if (String.isBlank(fieldName) || !row.getSObjectType().getDescribe().fields.getMap().containsKey(fieldName)) {
            return false;
        }
        Object value = row.get(fieldName);
        return value instanceof Boolean && (Boolean)value;
    }
    
    private static DayDescriptor getDayDescriptor(String label) {
        for (DayDescriptor descriptor : WEEK_DAYS) {
            if (descriptor.label == label) {
                return descriptor;
            }
        }
        return null;
    }
    
    private static void applyDay(CourseOfferingSchedule schedule, DayDescriptor descriptor) {
        schedule.IsMonday = descriptor.dayNumber == 1;
        schedule.IsTuesday = descriptor.dayNumber == 2;
        schedule.IsWednesday = descriptor.dayNumber == 3;
        schedule.IsThursday = descriptor.dayNumber == 4;
        schedule.IsFriday = descriptor.dayNumber == 5;
        schedule.IsSaturday = descriptor.dayNumber == 6;
        schedule.IsSunday = descriptor.dayNumber == 7;
    }
    
    private static void applyDays(CourseOfferingSchedule schedule, Set<String> dayNames) {
        Set<String> normalizedDayNames = dayNames == null ? new Set<String>() : new Set<String>(dayNames);
        schedule.IsMonday = normalizedDayNames.contains('Monday');
        schedule.IsTuesday = normalizedDayNames.contains('Tuesday');
        schedule.IsWednesday = normalizedDayNames.contains('Wednesday');
        schedule.IsThursday = normalizedDayNames.contains('Thursday');
        schedule.IsFriday = normalizedDayNames.contains('Friday');
        schedule.IsSaturday = normalizedDayNames.contains('Saturday');
        schedule.IsSunday = normalizedDayNames.contains('Sunday');
    }
    
    private static List<String> getActiveDayNames(CourseOfferingSchedule schedule) {
        List<String> dayNames = new List<String>();
        if (schedule == null) {
            return dayNames;
        }
        if (schedule.IsMonday) { dayNames.add('Monday'); }
        if (schedule.IsTuesday) { dayNames.add('Tuesday'); }
        if (schedule.IsWednesday) { dayNames.add('Wednesday'); }
        if (schedule.IsThursday) { dayNames.add('Thursday'); }
        if (schedule.IsFriday) { dayNames.add('Friday'); }
        if (schedule.IsSaturday) { dayNames.add('Saturday'); }
        if (schedule.IsSunday) { dayNames.add('Sunday'); }
        return dayNames;
    }
    
    private static String buildScheduleSignature(Time startTime, Time endTime, String room) {
        String normalizedRoom = String.isBlank(room) ? '' : room.trim().toLowerCase();
        return String.valueOf(startTime) + '|' + String.valueOf(endTime) + '|' + normalizedRoom;
    }
    
    private static String buildScheduleDescription(Set<String> dayNames, Time startTime, Time endTime) {
        List<String> orderedDays = new List<String>();
        for (DayDescriptor descriptor : WEEK_DAYS) {
            if (dayNames != null && dayNames.contains(descriptor.label)) {
                orderedDays.add(descriptor.label);
            }
        }
        String dayLabel = orderedDays.isEmpty() ? 'Schedule' : String.join(orderedDays, ', ');
        return dayLabel + ' ' + formatTime24(startTime) + ' - ' + formatTime24(endTime);
    }
    
    private static String normalizeDmlError(Exception error) {
        if (error instanceof DmlException) {
            return ((DmlException)error).getDmlMessage(0);
        }
        return error == null ? 'Unable to save timetable.' : error.getMessage();
    }
    
    private static Boolean timesOverlap(String startOne, String endOne, String startTwo, String endTwo) {
        Time startA = parseTime(startOne);
        Time endA = parseTime(endOne);
        Time startB = parseTime(startTwo);
        Time endB = parseTime(endTwo);
        if (startA == null || endA == null || startB == null || endB == null) {
            return false;
        }
        return startA < endB && endA > startB;
    }
    
    private static Time parseTime(String value) {
        if (String.isBlank(value) || !value.contains(':')) {
            return null;
        }
        List<String> parts = value.split(':');
        if (parts.size() != 2) {
            return null;
        }
        Integer hourValue = Integer.valueOf(parts[0]);
        Integer minuteValue = Integer.valueOf(parts[1]);
        return Time.newInstance(hourValue, minuteValue, 0, 0);
    }
    
    private static String formatTime24(Time value) {
        if (value == null) {
            return null;
        }
        String hourText = value.hour() < 10 ? '0' + String.valueOf(value.hour()) : String.valueOf(value.hour());
        String minuteText = value.minute() < 10 ? '0' + String.valueOf(value.minute()) : String.valueOf(value.minute());
        return hourText + ':' + minuteText;
    }
    
    private static String safeString(Object value) {
        return value == null ? null : String.valueOf(value);
    }
    
    private static Integer countDistinctRooms(List<BuilderScheduleEntryDTO> scheduleEntries) {
        Set<String> rooms = new Set<String>();
        for (BuilderScheduleEntryDTO entry : scheduleEntries) {
            if (String.isNotBlank(entry.room)) {
                rooms.add(entry.room);
            }
        }
        return rooms.size();
    }
    
    private static Integer countDistinctCohortsForOffering(Id courseOfferingId) {
        if (courseOfferingId == null) {
            return 0;
        }
        
        try {
            Set<Id> planIds = new Set<Id>();
            for (Program_Plan_Course_Junction__c junction : [
                SELECT Learning_Program_Plan__c
                FROM Program_Plan_Course_Junction__c
                WHERE Course_Offering__c = :courseOfferingId
            ]) {
                if (junction.Learning_Program_Plan__c != null) {
                    planIds.add(junction.Learning_Program_Plan__c);
                }
            }
            if (planIds.isEmpty()) {
                return 0;
            }
            
            Set<String> cohorts = new Set<String>();
            for (AggregateResult row : [
                SELECT ClassCohort cohort
                FROM LearnerProgram
                WHERE LearningProgramPlanId IN :planIds
                AND ClassCohort != null
                GROUP BY ClassCohort
            ]) {
                String cohort = (String)row.get('cohort');
                if (String.isNotBlank(cohort)) {
                    cohorts.add(cohort);
                }
            }
            return cohorts.size();
        } catch (Exception ex) {
            return 0;
        }
    }
    
    private static Set<Id> getOfferingIdsForProgramPlan(Id academicTermId, Id learningProgramPlanId) {
        Set<Id> offeringIds = new Set<Id>();
        if (academicTermId == null || learningProgramPlanId == null) {
            return offeringIds;
        }
        
        for (Program_Plan_Course_Junction__c junction : [
            SELECT Course_Offering__c
            FROM Program_Plan_Course_Junction__c
            WHERE Learning_Program_Plan__c = :learningProgramPlanId
            AND Course_Offering__c != null
            AND Course_Offering__r.AcademicSession.AcademicTermId = :academicTermId
            WITH USER_MODE
        ]) {
            if (junction.Course_Offering__c != null) {
                offeringIds.add(junction.Course_Offering__c);
            }
        }
        return offeringIds;
    }
    
    private static Map<Id, List<String>> getOfferingPlanEnrollmentTokens(Set<Id> offeringIds, Id academicTermId) {
        Map<Id, List<String>> tokensByOfferingId = new Map<Id, List<String>>();
        if (offeringIds == null || offeringIds.isEmpty()) {
            return tokensByOfferingId;
        }
        if (!Schema.getGlobalDescribe().containsKey('Program_Plan_Course_Junction__c')) {
            return tokensByOfferingId;
        }
        
        assertReadable(
            Program_Plan_Course_Junction__c.SObjectType,
        'Read access is required for Program Plan Course Junction.'
            );
        
        Map<String, Schema.SObjectField> junctionFields =
            Program_Plan_Course_Junction__c.SObjectType.getDescribe().fields.getMap();
        String planField = getExistingFieldName(
            junctionFields,
        new List<String>{ 'Learning_Program_Plan__c', 'LearningProgramPlanId' }
        );
        String offeringField = getExistingFieldName(
            junctionFields,
        new List<String>{ 'Course_Offering__c', 'CourseOfferingId' }
        );
        String enrollmentTypeField = getExistingFieldName(
            junctionFields,
        new List<String>{ 'Enrollment_Type__c' }
        );
        if (String.isBlank(planField) || String.isBlank(offeringField)) {
            return tokensByOfferingId;
        }
        String offeringRelationshipName = junctionFields.containsKey(offeringField)
            ? junctionFields.get(offeringField).getDescribe().getRelationshipName()
            : null;
        
        String soql =
            'SELECT ' + offeringField + ', ' + planField +
            (String.isBlank(enrollmentTypeField) ? '' : ', ' + enrollmentTypeField) +
            ' FROM Program_Plan_Course_Junction__c' +
            ' WHERE ' + offeringField + ' IN :offeringIds';
        if (academicTermId != null && String.isNotBlank(offeringRelationshipName)) {
            soql += ' AND ' + offeringRelationshipName + '.AcademicSession.AcademicTermId = :academicTermId';
        }
        soql += ' WITH USER_MODE';
        
        Map<Id, Set<String>> tokenSetByOfferingId = new Map<Id, Set<String>>();
        for (Program_Plan_Course_Junction__c junction : Database.query(soql)) {
            Id offeringId = (Id)junction.get(offeringField);
            Id planId = (Id)junction.get(planField);
            if (offeringId == null || planId == null) {
                continue;
            }
            String normalizedEnrollmentType = normalizeEnrollmentType(
                String.isBlank(enrollmentTypeField) ? null : safeString(junction.get(enrollmentTypeField))
                );
            if (!tokenSetByOfferingId.containsKey(offeringId)) {
                tokenSetByOfferingId.put(offeringId, new Set<String>());
            }
            tokenSetByOfferingId.get(offeringId).add(String.valueOf(planId) + '|' + normalizedEnrollmentType);
        }
        
        for (Id offeringId : tokenSetByOfferingId.keySet()) {
            tokensByOfferingId.put(offeringId, new List<String>(tokenSetByOfferingId.get(offeringId)));
        }
        return tokensByOfferingId;
    }
    
    private static Boolean shouldBlockOverlap(List<String> currentTokens, List<String> otherTokens) {
        if (currentTokens == null || currentTokens.isEmpty() || otherTokens == null || otherTokens.isEmpty()) {
            return true;
        }
        
        Map<String, String> currentByPlan = mapEnrollmentTypeByPlan(currentTokens);
        Map<String, String> otherByPlan = mapEnrollmentTypeByPlan(otherTokens);
        for (String planId : currentByPlan.keySet()) {
            if (!otherByPlan.containsKey(planId)) {
                continue;
            }
            if (!isElectiveEnrollmentType(currentByPlan.get(planId)) ||
            !isElectiveEnrollmentType(otherByPlan.get(planId))) {
                return true;
            }
        }
        return false;
    }
    
    private static Map<String, String> mapEnrollmentTypeByPlan(List<String> tokens) {
        Map<String, String> enrollmentTypeByPlan = new Map<String, String>();
        if (tokens == null) {
            return enrollmentTypeByPlan;
        }
        for (String token : tokens) {
            if (String.isBlank(token) || !token.contains('|')) {
                continue;
            }
            List<String> parts = token.split('\\|');
            if (parts.size() < 2 || String.isBlank(parts[0])) {
                continue;
            }
            enrollmentTypeByPlan.put(parts[0], parts[1]);
        }
        return enrollmentTypeByPlan;
    }
    
    private static String normalizeEnrollmentType(String rawValue) {
        String normalized = String.isBlank(rawValue) ? '' : rawValue.trim().toLowerCase();
        if (normalized.contains('elective')) {
            return 'elective';
        }
        if (normalized.contains('core')) {
            return 'core';
        }
        return String.isBlank(normalized) ? 'core' : normalized;
    }
    
    private static Boolean isElectiveEnrollmentType(String value) {
        return !String.isBlank(value) && value.trim().toLowerCase() == 'elective';
    }
    
    private static String getSingleActiveDayName(CourseOfferingSchedule schedule) {
        if (schedule == null) {
            return null;
        }
        
        List<String> activeDayNames = new List<String>();
        if (schedule.IsMonday) { activeDayNames.add('Monday'); }
        if (schedule.IsTuesday) { activeDayNames.add('Tuesday'); }
        if (schedule.IsWednesday) { activeDayNames.add('Wednesday'); }
        if (schedule.IsThursday) { activeDayNames.add('Thursday'); }
        if (schedule.IsFriday) { activeDayNames.add('Friday'); }
        if (schedule.IsSaturday) { activeDayNames.add('Saturday'); }
        if (schedule.IsSunday) { activeDayNames.add('Sunday'); }
        
        return activeDayNames.size() == 1 ? activeDayNames[0] : null;
    }
    
    private static Id toId(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return (Id)value;
        } catch (Exception ex) {
            return null;
        }
    }
    
    private static Boolean getCheckboxValue(SObject row, String fieldApiName) {
        if (row == null || String.isBlank(fieldApiName) || !row.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApiName)) {
            return false;
        }
        Object value = row.get(fieldApiName);
        return value != null && (Boolean)value;
    }
    
    private static Integer getIntegerValue(SObject row, String fieldApiName, Integer fallbackValue) {
        if (row == null || String.isBlank(fieldApiName) || !row.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApiName)) {
            return fallbackValue;
        }
        Object value = row.get(fieldApiName);
        if (value == null) {
            return fallbackValue;
        }
        if (value instanceof Decimal) {
            return ((Decimal)value).intValue();
        }
        if (value instanceof Integer) {
            return (Integer)value;
        }
        return fallbackValue;
    }
    
    private static Datetime getDatetimeValue(SObject row, String fieldApiName) {
        if (row == null || String.isBlank(fieldApiName) || !row.getSObjectType().getDescribe().fields.getMap().containsKey(fieldApiName)) {
            return null;
        }
        Object value = row.get(fieldApiName);
        return value instanceof Datetime ? (Datetime)value : null;
    }
    
    private static Date parseDateValue(String value) {
        return String.isBlank(value) ? null : Date.valueOf(value);
    }
    
    @TestVisible
    private static String normalizeTemplateRecurrencePattern(String recurrencePattern, Date endDate) {
        if (String.isBlank(recurrencePattern)) {
            return recurrencePattern;
        }
        
        String normalized = recurrencePattern.trim();
        if (!normalized.toUpperCase().startsWith('RRULE:') || hasRecurrenceTerminator(normalized)) {
            return normalized;
        }
        
        return endDate == null ? normalized : normalized + ';UNTIL=' + formatRRuleUntilDate(endDate);
    }
    
    private static Boolean hasRecurrenceTerminator(String recurrencePattern) {
        String ruleBody = recurrencePattern.trim();
        if (ruleBody.toUpperCase().startsWith('RRULE:')) {
            ruleBody = ruleBody.substring(6);
        }
        
        for (String part : ruleBody.split(';')) {
            String token = part == null ? '' : part.trim().toUpperCase();
            if (token.startsWith('UNTIL=') || token.startsWith('COUNT=')) {
                return true;
            }
        }
        return false;
    }
    
    private static String formatRRuleUntilDate(Date endDate) {
        return String.valueOf(endDate.year())
            + leftPadTwo(endDate.month())
            + leftPadTwo(endDate.day())
            + 'T235959Z';
    }
    
    private static String leftPadTwo(Integer value) {
        return value < 10 ? '0' + String.valueOf(value) : String.valueOf(value);
    }
    
    private static void validateDuplicateScheduleTemplate(
        TemplateSupport templateSupport,
    Map<String, Schema.SObjectField> templateFields,
    String templateStartTimeField,
    String templateEndTimeField,
    Date startDate,
    Date endDate,
    Time startTime,
    Time endTime,
    Map<String, Boolean> dayValuesByLabel
    ) {
        if (String.isBlank(templateSupport.templateObjectApiName) || templateFields == null) {
            return;
        }
        
        List<String> selectFields = new List<String>{ 'Id', 'Name' };
        if (String.isNotBlank(templateSupport.templateStartDateField)) {
            selectFields.add(templateSupport.templateStartDateField);
        }
        if (String.isNotBlank(templateSupport.templateEndDateField)) {
            selectFields.add(templateSupport.templateEndDateField);
        }
        if (String.isNotBlank(templateStartTimeField)) {
            selectFields.add(templateStartTimeField);
        }
        if (String.isNotBlank(templateEndTimeField)) {
            selectFields.add(templateEndTimeField);
        }
        for (DayDescriptor descriptor : WEEK_DAYS) {
            String dayField = templateFields.containsKey(descriptor.scheduleFieldName)
                ? descriptor.scheduleFieldName
                : (templateFields.containsKey(descriptor.templateFieldName) ? descriptor.templateFieldName : null);
            if (String.isNotBlank(dayField)) {
                selectFields.add(dayField);
            }
        }
        
        String soql =
            'SELECT ' + String.join(selectFields, ', ') +
            ' FROM ' + templateSupport.templateObjectApiName +
            ' WITH USER_MODE';
        
        for (SObject existingTemplate : Database.query(soql)) {
            if (!sameDateValue(
                startDate,
            String.isBlank(templateSupport.templateStartDateField)
                ? null
                : existingTemplate.get(templateSupport.templateStartDateField)
            )) {
                continue;
            }
            if (!sameDateValue(
                endDate,
            String.isBlank(templateSupport.templateEndDateField)
                ? null
                : existingTemplate.get(templateSupport.templateEndDateField)
            )) {
                continue;
            }
            if (!sameTimeValue(
                startTime,
            String.isBlank(templateStartTimeField)
                ? null
                : existingTemplate.get(templateStartTimeField)
            )) {
                continue;
            }
            if (!sameTimeValue(
                endTime,
            String.isBlank(templateEndTimeField)
                ? null
                : existingTemplate.get(templateEndTimeField)
            )) {
                continue;
            }
            if (!sameTemplateDays(existingTemplate, templateFields, dayValuesByLabel)) {
                continue;
            }
            
            throw new AuraHandledException(
                'A schedule template with the same dates, times, and active days already exists: ' +
                String.valueOf(existingTemplate.get('Name')) + '.'
                );
        }
    }
    
    private static Boolean sameTemplateDays(
        SObject existingTemplate,
    Map<String, Schema.SObjectField> templateFields,
    Map<String, Boolean> dayValuesByLabel
    ) {
        for (DayDescriptor descriptor : WEEK_DAYS) {
            String dayField = templateFields.containsKey(descriptor.scheduleFieldName)
                ? descriptor.scheduleFieldName
                : (templateFields.containsKey(descriptor.templateFieldName) ? descriptor.templateFieldName : null);
            Boolean existingValue = getCheckboxValue(existingTemplate, dayField);
            Boolean requestedValue = dayValuesByLabel != null && dayValuesByLabel.containsKey(descriptor.label)
                ? Boolean.valueOf(dayValuesByLabel.get(descriptor.label))
                : false;
            if (existingValue != requestedValue) {
                return false;
            }
        }
        return true;
    }
    
    private static Boolean sameDateValue(Date expectedValue, Object existingValue) {
        if (expectedValue == null && existingValue == null) {
            return true;
        }
        if (expectedValue == null || existingValue == null) {
            return false;
        }
        if (existingValue instanceof Date) {
            return expectedValue == (Date) existingValue;
        }
        if (existingValue instanceof Datetime) {
            return expectedValue == ((Datetime) existingValue).date();
        }
        return String.valueOf(expectedValue) == String.valueOf(existingValue);
    }
    
    private static Boolean sameTimeValue(Time expectedValue, Object existingValue) {
        if (expectedValue == null && existingValue == null) {
            return true;
        }
        if (expectedValue == null || existingValue == null) {
            return false;
        }
        if (existingValue instanceof Time) {
            return expectedValue == (Time) existingValue;
        }
        return formatTime24(expectedValue) == String.valueOf(existingValue);
    }
    
    private static void putFieldIfCreateable(
        SObject target,
    Map<String, Schema.SObjectField> fields,
    String fieldName,
    Object value
    ) {
        if (target == null || fields == null || String.isBlank(fieldName) || !fields.containsKey(fieldName)) {
            return;
        }
        Schema.DescribeFieldResult describe = fields.get(fieldName).getDescribe();
        if (!describe.isCreateable()) {
            return;
        }
        target.put(fieldName, value);
    }
    
    private static TemplateSupport discoverTemplateSupport() {
        Map<String, Schema.SObjectType> describeMap = Schema.getGlobalDescribe();
        TemplateSupport support = new TemplateSupport();
        
        if (describeMap.containsKey('CourseOffering')) {
            support.offeringTemplateLookupField = getExistingFieldName(
                describeMap.get('CourseOffering').getDescribe().fields.getMap(),
            COURSE_OFFERING_TEMPLATE_FIELD_CANDIDATES
                );
        }
        if (describeMap.containsKey('CourseOfferingSchedule')) {
            support.scheduleRoomField = getExistingFieldName(
                describeMap.get('CourseOfferingSchedule').getDescribe().fields.getMap(),
            ROOM_FIELD_CANDIDATES
                );
        }
        
        for (String objectApiName : TEMPLATE_OBJECT_CANDIDATES) {
            if (describeMap.containsKey(objectApiName)) {
                support.templateObjectApiName = objectApiName;
                support.templateRecurrenceField = getExistingFieldName(
                    describeMap.get(objectApiName).getDescribe().fields.getMap(),
                TEMPLATE_RECURRENCE_FIELD_CANDIDATES
                    );
                support.templateStartDateField = getExistingFieldName(
                    describeMap.get(objectApiName).getDescribe().fields.getMap(),
                TEMPLATE_START_DATE_FIELD_CANDIDATES
                    );
                support.templateEndDateField = getExistingFieldName(
                    describeMap.get(objectApiName).getDescribe().fields.getMap(),
                TEMPLATE_END_DATE_FIELD_CANDIDATES
                    );
                break;
            }
        }
        for (String objectApiName : TEMPLATE_ENTRY_OBJECT_CANDIDATES) {
            if (describeMap.containsKey(objectApiName)) {
                support.templateEntryObjectApiName = objectApiName;
                Map<String, Schema.SObjectField> fields = describeMap.get(objectApiName).getDescribe().fields.getMap();
                support.templateEntryParentField = getExistingFieldName(fields, TEMPLATE_ENTRY_PARENT_FIELD_CANDIDATES);
                support.templateEntryStartField = getExistingFieldName(fields, TEMPLATE_ENTRY_START_FIELD_CANDIDATES);
                support.templateEntryEndField = getExistingFieldName(fields, TEMPLATE_ENTRY_END_FIELD_CANDIDATES);
                support.templateEntryRoomField = getExistingFieldName(fields, ROOM_FIELD_CANDIDATES);
                break;
            }
        }
        return support;
    }
    
    private static String buildTermLabel(AcademicTerm term) {
        if (String.isNotBlank(term.Name) && term.Name != 'Term') {
            return term.Name;
        }
        
        List<String> parts = new List<String>();
        if (term.Start_Year__c != null) {
            parts.add(String.valueOf(term.Start_Year__c));
        }
        if (term.End_Year__c != null) {
            parts.add(String.valueOf(term.End_Year__c));
        }
        
        String label = String.join(parts, ' - ');
        if (String.isNotBlank(term.Sequence__c)) {
            label = String.isNotBlank(label) ? label + ' (Term ' + term.Sequence__c + ')' : 'Term ' + term.Sequence__c;
        }
        return String.isNotBlank(label) ? label : 'Academic Term';
    }
    
    private static String formatTemplateDate(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Date) {
            return String.valueOf((Date)value);
        }
        if (value instanceof Datetime) {
            return ((Datetime)value).formatGmt('yyyy-MM-dd');
        }
        return String.valueOf(value);
    }
    
    private static String getExistingFieldName(Map<String, Schema.SObjectField> fields, List<String> candidates) {
        for (String candidate : candidates) {
            if (fields.containsKey(candidate)) {
                return candidate;
            }
        }
        return null;
    }
    
    private static String getReadableFieldName(Map<String, Schema.SObjectField> fields, List<String> candidates) {
        for (String candidate : candidates) {
            if (fields.containsKey(candidate) && fields.get(candidate).getDescribe().isAccessible()) {
                return candidate;
            }
        }
        return null;
    }
    
    private static String getUpdateableFieldName(Map<String, Schema.SObjectField> fields, List<String> candidates) {
        for (String candidate : candidates) {
            if (fields.containsKey(candidate) && fields.get(candidate).getDescribe().isUpdateable()) {
                return candidate;
            }
        }
        return null;
    }
    
    private static void assertReadable(Schema.SObjectType objectType, String message) {
        if (!objectType.getDescribe().isAccessible()) {
            throw new AuraHandledException(message);
        }
    }
    
    private static void assertUpdateable(Schema.SObjectType objectType, String message) {
        if (!objectType.getDescribe().isUpdateable()) {
            throw new AuraHandledException(message);
        }
    }
    
    private class DayDescriptor {
        private String label;
        private String scheduleFieldName;
        private String templateFieldName;
        private Integer dayNumber;
        
        private DayDescriptor(String label, String scheduleFieldName, String templateFieldName, Integer dayNumber) {
            this.label = label;
            this.scheduleFieldName = scheduleFieldName;
            this.templateFieldName = templateFieldName;
            this.dayNumber = dayNumber;
        }
    }
    
    private class ConsolidatedScheduleRequest {
        private Time startTime;
        private Time endTime;
        private String room;
        private Set<String> dayNames;
        private Set<Id> scheduleIds;
        
        private ConsolidatedScheduleRequest(Time startTime, Time endTime, String room) {
            this.startTime = startTime;
            this.endTime = endTime;
            this.room = room;
            this.dayNames = new Set<String>();
            this.scheduleIds = new Set<Id>();
        }
    }
    
    private class TemplateSupport {
        private String offeringTemplateLookupField;
        private String templateObjectApiName;
        private String templateRecurrenceField;
        private String templateStartDateField;
        private String templateEndDateField;
        private String templateEntryObjectApiName;
        private String templateEntryParentField;
        private String templateEntryStartField;
        private String templateEntryEndField;
        private String templateEntryRoomField;
        private String scheduleRoomField;
        
        private Boolean hasOfferingTemplateLookup() {
            return String.isNotBlank(offeringTemplateLookupField) && String.isNotBlank(templateObjectApiName);
        }
        
        private Map<Id, TemplateOptionDTO> queryTemplateDetails(Set<Id> templateIds) {
            Map<Id, TemplateOptionDTO> detailsById = new Map<Id, TemplateOptionDTO>();
            if (String.isBlank(templateObjectApiName) || templateIds == null || templateIds.isEmpty()) {
                return detailsById;
            }
            
            List<String> selectFields = new List<String>{ 'Id', 'Name' };
            if (String.isNotBlank(templateRecurrenceField)) {
                selectFields.add(templateRecurrenceField);
            }
            if (String.isNotBlank(templateStartDateField)) {
                selectFields.add(templateStartDateField);
            }
            if (String.isNotBlank(templateEndDateField)) {
                selectFields.add(templateEndDateField);
            }
            String soql =
                'SELECT ' + String.join(selectFields, ', ') +
                ' FROM ' + templateObjectApiName + ' WHERE Id IN :templateIds WITH USER_MODE';
            for (SObject row : Database.query(soql)) {
                TemplateOptionDTO option = new TemplateOptionDTO();
                option.id = (Id)row.get('Id');
                option.name = String.valueOf(row.get('Name'));
                option.recurrencePattern = String.isBlank(templateRecurrenceField)
                    ? null
                    : safeString(row.get(templateRecurrenceField));
                option.startDate = String.isBlank(templateStartDateField)
                    ? null
                    : formatTemplateDate(row.get(templateStartDateField));
                option.endDate = String.isBlank(templateEndDateField)
                    ? null
                    : formatTemplateDate(row.get(templateEndDateField));
                detailsById.put(option.id, option);
            }
            return detailsById;
        }
        
        private List<TemplateOptionDTO> queryAllTemplateOptions() {
            List<TemplateOptionDTO> options = new List<TemplateOptionDTO>();
            if (String.isBlank(templateObjectApiName)) {
                return options;
            }
            
            List<String> selectFields = new List<String>{ 'Id', 'Name' };
            if (String.isNotBlank(templateRecurrenceField)) {
                selectFields.add(templateRecurrenceField);
            }
            if (String.isNotBlank(templateStartDateField)) {
                selectFields.add(templateStartDateField);
            }
            if (String.isNotBlank(templateEndDateField)) {
                selectFields.add(templateEndDateField);
            }
            String soql =
                'SELECT ' + String.join(selectFields, ', ') +
                ' FROM ' + templateObjectApiName +
                ' WITH USER_MODE ORDER BY Name ASC';
            for (SObject row : Database.query(soql)) {
                TemplateOptionDTO option = new TemplateOptionDTO();
                option.id = (Id)row.get('Id');
                option.name = String.valueOf(row.get('Name'));
                option.recurrencePattern = String.isBlank(templateRecurrenceField)
                    ? null
                    : safeString(row.get(templateRecurrenceField));
                option.startDate = String.isBlank(templateStartDateField)
                    ? null
                    : formatTemplateDate(row.get(templateStartDateField));
                option.endDate = String.isBlank(templateEndDateField)
                    ? null
                    : formatTemplateDate(row.get(templateEndDateField));
                options.add(option);
            }
            return options;
        }
        
        private Map<Id, List<BuilderScheduleEntryDTO>> queryTemplateEntries(Map<Id, TemplateOptionDTO> templateDetailsById) {
            Map<Id, List<BuilderScheduleEntryDTO>> entriesByTemplateId = new Map<Id, List<BuilderScheduleEntryDTO>>();
            if (templateDetailsById == null || templateDetailsById.isEmpty()) {
                return entriesByTemplateId;
            }
            
            Set<Id> templateIds = templateDetailsById.keySet();
            if (String.isNotBlank(templateEntryObjectApiName) &&
                String.isNotBlank(templateEntryParentField) &&
                String.isNotBlank(templateEntryStartField) &&
            String.isNotBlank(templateEntryEndField)) {
                List<String> queryFields = new List<String>{
                    'Id',
                    templateEntryParentField,
                    templateEntryStartField,
                    templateEntryEndField
                };
                for (DayDescriptor descriptor : WEEK_DAYS) {
                    Map<String, Schema.SObjectField> fields =
                        Schema.getGlobalDescribe().get(templateEntryObjectApiName).getDescribe().fields.getMap();
                    if (fields.containsKey(descriptor.templateFieldName)) {
                        queryFields.add(descriptor.templateFieldName);
                    }
                }
                if (String.isNotBlank(templateEntryRoomField)) {
                    queryFields.add(templateEntryRoomField);
                }
                
                String soql =
                    'SELECT ' + String.join(queryFields, ', ') +
                    ' FROM ' + templateEntryObjectApiName +
                    ' WHERE ' + templateEntryParentField + ' IN :templateIds WITH USER_MODE';
                for (SObject row : Database.query(soql)) {
                    Id templateId = (Id)row.get(templateEntryParentField);
                    if (templateId == null) {
                        continue;
                    }
                    
                    List<DayDescriptor> activeDays = getActiveDays(row, false);
                    if (activeDays.isEmpty()) {
                        continue;
                    }
                    
                    Time startTime = (Time)row.get(templateEntryStartField);
                    Time endTime = (Time)row.get(templateEntryEndField);
                    if (startTime == null || endTime == null) {
                        continue;
                    }
                    
                    if (!entriesByTemplateId.containsKey(templateId)) {
                        entriesByTemplateId.put(templateId, new List<BuilderScheduleEntryDTO>());
                    }
                    
                    for (DayDescriptor descriptor : activeDays) {
                        BuilderScheduleEntryDTO entry = new BuilderScheduleEntryDTO();
                        entry.dayName = descriptor.label;
                        entry.dayNumber = descriptor.dayNumber;
                        entry.startTime = formatTime24(startTime);
                        entry.endTime = formatTime24(endTime);
                        entry.durationMinutes = calculateDuration(startTime, endTime);
                        entry.room = String.isBlank(templateEntryRoomField) ? null : safeString(row.get(templateEntryRoomField));
                        entry.source = 'Template';
                        entry.templateName = templateDetailsById.containsKey(templateId) ? templateDetailsById.get(templateId).name : null;
                        entriesByTemplateId.get(templateId).add(entry);
                    }
                }
            }
            
            if (!entriesByTemplateId.isEmpty() || String.isBlank(templateObjectApiName)) {
                return entriesByTemplateId;
            }
            
            Map<String, Schema.SObjectField> templateFields =
                Schema.getGlobalDescribe().get(templateObjectApiName).getDescribe().fields.getMap();
            String templateStartField = getExistingFieldName(templateFields, TEMPLATE_ENTRY_START_FIELD_CANDIDATES);
            String templateEndField = getExistingFieldName(templateFields, TEMPLATE_ENTRY_END_FIELD_CANDIDATES);
            if (String.isBlank(templateStartField) || String.isBlank(templateEndField)) {
                return entriesByTemplateId;
            }
            
            List<String> templateQueryFields = new List<String>{ 'Id', 'Name', templateStartField, templateEndField };
            for (DayDescriptor descriptor : WEEK_DAYS) {
                if (templateFields.containsKey(descriptor.scheduleFieldName)) {
                    templateQueryFields.add(descriptor.scheduleFieldName);
                }
            }
            
            String templateSoql =
                'SELECT ' + String.join(templateQueryFields, ', ') +
                ' FROM ' + templateObjectApiName +
                ' WHERE Id IN :templateIds WITH USER_MODE';
            for (SObject row : Database.query(templateSoql)) {
                Id templateId = (Id)row.get('Id');
                if (templateId == null) {
                    continue;
                }
                
                List<DayDescriptor> activeDays = getActiveDays(row, false);
                if (activeDays.isEmpty()) {
                    continue;
                }
                
                Time startTime = (Time)row.get(templateStartField);
                Time endTime = (Time)row.get(templateEndField);
                if (startTime == null || endTime == null) {
                    continue;
                }
                
                entriesByTemplateId.put(templateId, new List<BuilderScheduleEntryDTO>());
                for (DayDescriptor descriptor : activeDays) {
                    BuilderScheduleEntryDTO entry = new BuilderScheduleEntryDTO();
                    entry.dayName = descriptor.label;
                    entry.dayNumber = descriptor.dayNumber;
                    entry.startTime = formatTime24(startTime);
                    entry.endTime = formatTime24(endTime);
                    entry.durationMinutes = calculateDuration(startTime, endTime);
                    entry.source = 'Template';
                    entry.templateName = templateDetailsById.containsKey(templateId) ? templateDetailsById.get(templateId).name : null;
                    entriesByTemplateId.get(templateId).add(entry);
                }
            }
            return entriesByTemplateId;
        }
    }
}