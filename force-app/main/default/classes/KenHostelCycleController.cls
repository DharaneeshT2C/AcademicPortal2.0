public with sharing class KenHostelCycleController {
    private static final Time START_OF_DAY = Time.newInstance(0, 0, 0, 0);
    private static final Time END_OF_DAY = Time.newInstance(23, 59, 59, 999);
    private static final String LIMIT_MODE_FULL_CAPACITY = 'Use Full Capacity';
    private static final String LIMIT_MODE_CUSTOM_CAP = 'Custom Cap';

    public class OptionItem {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String buildingValue { get; set; }
        @AuraEnabled public List<String> buildingValues { get; set; }
        @AuraEnabled public List<String> floorValues { get; set; }
    }

    public class BuildingAllocationRow {
        @AuraEnabled public String buildingId { get; set; }
        @AuraEnabled public String building { get; set; }
        @AuraEnabled public Integer roomCount { get; set; }
        @AuraEnabled public Integer totalCapacity { get; set; }
        @AuraEnabled public Integer alreadyAllocated { get; set; }
        @AuraEnabled public String limitMode { get; set; }
        @AuraEnabled public String allocationCap { get; set; }
    }

    private class BuildingAllocationMetrics {
        public Integer roomCount;
        public Integer totalCapacity;
        public Integer alreadyAllocated;

        public BuildingAllocationMetrics() {
            roomCount = 0;
            totalCapacity = 0;
            alreadyAllocated = 0;
        }
    }

    private class AcademicYearSelection {
        public List<Id> ids;
        public List<String> labels;

        public AcademicYearSelection() {
            ids = new List<Id>();
            labels = new List<String>();
        }
    }

    private class CycleAcademicYearInfo {
        public Map<Id, List<String>> idsByCycleId;
        public Map<Id, List<String>> labelsByCycleId;

        public CycleAcademicYearInfo() {
            idsByCycleId = new Map<Id, List<String>>();
            labelsByCycleId = new Map<Id, List<String>>();
        }
    }

    public class CycleRow {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String cycleName { get; set; }
        @AuraEnabled public String academicYear { get; set; }
        @AuraEnabled public List<String> academicYearIds { get; set; }
        @AuraEnabled public String startDate { get; set; }
        @AuraEnabled public String endDate { get; set; }
        @AuraEnabled public String startDateRaw { get; set; }
        @AuraEnabled public String endDateRaw { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String statusClass { get; set; }
        @AuraEnabled public String previousCycleId { get; set; }
        @AuraEnabled public Boolean carryForwardEnabled { get; set; }
        @AuraEnabled public Integer windows { get; set; }
        @AuraEnabled public Integer applications { get; set; }
        @AuraEnabled public String createdBy { get; set; }
        @AuraEnabled public String createdAt { get; set; }
        @AuraEnabled public String lastModifiedBy { get; set; }
        @AuraEnabled public String lastModifiedAt { get; set; }
    }

    public class WindowRow {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String startDate { get; set; }
        @AuraEnabled public String endDate { get; set; }
        @AuraEnabled public String roomAllotmentStartDate { get; set; }
        @AuraEnabled public String roomAllotmentEndDate { get; set; }
        @AuraEnabled public String startTime { get; set; }
        @AuraEnabled public String endTime { get; set; }
        @AuraEnabled public String paymentDeadline { get; set; }
        @AuraEnabled public String allotmentType { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Boolean enableRoomPreference { get; set; }
        @AuraEnabled public String maxRoomPreferences { get; set; }
        @AuraEnabled public Boolean enableMaximumRoomCapacity { get; set; }
        @AuraEnabled public String maxRoomCapacity { get; set; }
        @AuraEnabled public Boolean allowRoommatePreference { get; set; }
        @AuraEnabled public List<String> programPathwayIds { get; set; }
        @AuraEnabled public List<String> buildingIds { get; set; }
        @AuraEnabled public List<String> roomCategoryIds { get; set; }
        @AuraEnabled public List<String> programPathwayLabels { get; set; }
        @AuraEnabled public List<String> buildingLabels { get; set; }
        @AuraEnabled public List<String> roomCategoryLabels { get; set; }
        @AuraEnabled public List<BuildingAllocationRow> buildingAllocationRows { get; set; }
        @AuraEnabled public String createdBy { get; set; }
        @AuraEnabled public String createdAt { get; set; }
        @AuraEnabled public String lastModifiedBy { get; set; }
        @AuraEnabled public String lastModifiedAt { get; set; }
    }

    public class WindowFormOptions {
        @AuraEnabled public List<OptionItem> programPathways { get; set; }
        @AuraEnabled public List<OptionItem> buildings { get; set; }
        @AuraEnabled public List<OptionItem> floors { get; set; }
        @AuraEnabled public List<OptionItem> roomCategories { get; set; }
    }

    public class CreateCycleRequest {
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String academicYear { get; set; }
        @AuraEnabled public List<String> academicYearIds { get; set; }
        @AuraEnabled public String startDate { get; set; }
        @AuraEnabled public String endDate { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Boolean carryForwardEnabled { get; set; }
        @AuraEnabled public String previousCycleId { get; set; }
    }

    public class SaveWindowRequest {
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String startDate { get; set; }
        @AuraEnabled public String endDate { get; set; }
        @AuraEnabled public String roomAllotmentStartDate { get; set; }
        @AuraEnabled public String roomAllotmentEndDate { get; set; }
        @AuraEnabled public String startTime { get; set; }
        @AuraEnabled public String endTime { get; set; }
        @AuraEnabled public String paymentDeadline { get; set; }
        @AuraEnabled public String allotmentType { get; set; }
        @AuraEnabled public Boolean enableRoomPreference { get; set; }
        @AuraEnabled public String maxRoomPreferences { get; set; }
        @AuraEnabled public Boolean enableMaximumRoomCapacity { get; set; }
        @AuraEnabled public String maxRoomCapacity { get; set; }
        @AuraEnabled public Boolean allowRoommatePreference { get; set; }
        @AuraEnabled public List<String> programPathwayIds { get; set; }
        @AuraEnabled public List<String> buildingIds { get; set; }
        @AuraEnabled public List<String> roomCategoryIds { get; set; }
        @AuraEnabled public List<BuildingAllocationRow> buildingAllocationRows { get; set; }
    }

    @AuraEnabled
    public static List<CycleRow> getCycles() {
        if (!Schema.sObjectType.Hostel_Cycle__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view hostel cycles.');
        }
        List<Hostel_Cycle__c> cycleRecords = [
            SELECT
                Id,
                Name,
                Academic_Year__c,
                Academic_Years_Display__c,
                Cycle_Start_Date_Time__c,
                Cycle_End_Date_Time__c,
                Status__c,
                Previous_Cycle__c,
                CreatedBy.Name,
                CreatedDate,
                LastModifiedBy.Name,
                LastModifiedDate
            FROM Hostel_Cycle__c
            ORDER BY Cycle_Start_Date_Time__c DESC, CreatedDate DESC
            LIMIT 500
        ];

        Set<Id> cycleIds = new Set<Id>();
        for (Hostel_Cycle__c row : cycleRecords) {
            cycleIds.add(row.Id);
        }
        Map<Id, Integer> windowCounts = getWindowCountsByCycle(cycleIds);
        Map<Id, Integer> applicationCounts = getApplicationCountsByCycle(cycleIds);
        CycleAcademicYearInfo cycleAcademicYearInfo = getCycleAcademicYearInfo(cycleRecords);

        List<CycleRow> response = new List<CycleRow>();
        for (Hostel_Cycle__c row : cycleRecords) {
            CycleRow item = new CycleRow();
            item.id = row.Id;
            item.cycleName = sanitize(row.Name);
            item.academicYear = resolveCycleAcademicYearDisplay(row, cycleAcademicYearInfo);
            item.academicYearIds = cycleAcademicYearInfo.idsByCycleId.containsKey(row.Id)
                ? new List<String>(cycleAcademicYearInfo.idsByCycleId.get(row.Id))
                : new List<String>();
            item.startDate = formatDateValue(row.Cycle_Start_Date_Time__c);
            item.endDate = formatDateValue(row.Cycle_End_Date_Time__c);
            item.startDateRaw = formatDateTimeLocalValue(row.Cycle_Start_Date_Time__c);
            item.endDateRaw = formatDateTimeLocalValue(row.Cycle_End_Date_Time__c);
            item.status = sanitize(row.Status__c);
            item.statusClass = resolveStatusClass(item.status);
            item.previousCycleId = row.Previous_Cycle__c == null ? null : String.valueOf(row.Previous_Cycle__c);
            item.carryForwardEnabled = row.Previous_Cycle__c != null;
            item.windows = windowCounts.containsKey(row.Id) ? windowCounts.get(row.Id) : 0;
            item.applications = applicationCounts.containsKey(row.Id) ? applicationCounts.get(row.Id) : 0;
            item.createdBy = row.CreatedBy != null ? sanitize(row.CreatedBy.Name) : null;
            item.createdAt = formatDateTimeIso(row.CreatedDate);
            item.lastModifiedBy = row.LastModifiedBy != null ? sanitize(row.LastModifiedBy.Name) : null;
            item.lastModifiedAt = formatDateTimeIso(row.LastModifiedDate);
            response.add(item);
        }

        return response;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionItem> getAcademicYearOptions() {
        List<OptionItem> options = new List<OptionItem>();
        if (!Schema.sObjectType.AcademicYear.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view academic years.');
        }
        for (AcademicYear row : [
            SELECT Id, Name
            FROM AcademicYear
            WHERE Name != null
            ORDER BY Name DESC
            LIMIT 2000
        ]) {
            OptionItem option = new OptionItem();
            option.label = sanitize(row.Name);
            option.value = String.valueOf(row.Id);
            options.add(option);
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionItem> getPreviousCycleOptions() {
        List<OptionItem> options = new List<OptionItem>();
        if (!Schema.sObjectType.Hostel_Cycle__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view hostel cycles.');
        }
        List<Hostel_Cycle__c> cycleRecords = [
            SELECT Id, Name, Academic_Year__c, Academic_Years_Display__c
            FROM Hostel_Cycle__c
            ORDER BY Cycle_Start_Date_Time__c DESC, CreatedDate DESC
            LIMIT 500
        ];
        CycleAcademicYearInfo cycleAcademicYearInfo = getCycleAcademicYearInfo(cycleRecords);

        for (Hostel_Cycle__c row : cycleRecords) {
            OptionItem option = new OptionItem();
            String yearText = resolveCycleAcademicYearDisplay(row, cycleAcademicYearInfo);
            option.label = String.isBlank(yearText) ? row.Name : row.Name + ' (' + yearText + ')';
            option.value = String.valueOf(row.Id);
            options.add(option);
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionItem> getStatusOptions() {
        List<OptionItem> options = new List<OptionItem>();
        for (Schema.PicklistEntry entry : Hostel_Cycle__c.Status__c.getDescribe().getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            OptionItem option = new OptionItem();
            option.label = entry.getLabel();
            option.value = entry.getValue();
            options.add(option);
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static WindowFormOptions getWindowFormOptions() {
        WindowFormOptions response = new WindowFormOptions();
        response.programPathways = new List<OptionItem>();
        response.buildings = new List<OptionItem>();
        response.floors = new List<OptionItem>();
        response.roomCategories = new List<OptionItem>();
        if (!Schema.sObjectType.LearningProgramPlan.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view learning program plans.');
        }
        if (!Schema.sObjectType.Ken_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view buildings.');
        }
        if (!Schema.sObjectType.Ken_Room__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view rooms.');
        }
        if (!Schema.sObjectType.Ken_Room_Category__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room categories.');
        }

        for (LearningProgramPlan row : [
            SELECT Id, Name
            FROM LearningProgramPlan
            WHERE Name != null
            ORDER BY Name
            LIMIT 2000
        ]) {
            response.programPathways.add(toOptionItem(row.Id, row.Name));
        }

        Set<String> seenFloorValues = new Set<String>();
        for (Ken_Building__c row : [
            SELECT Id, Name, Name__c, Number_Of_Floors__c, Total_Floors__c
            FROM Ken_Building__c
            ORDER BY Name__c, Name
            LIMIT 2000
        ]) {
            String buildingLabel = preferredLabel(row.Name__c, row.Name);
            response.buildings.add(toOptionItem(row.Id, buildingLabel));

            Integer totalFloors = extractPositiveIntegerFromText(
                preferredLabel(sanitize(row.Number_Of_Floors__c), sanitize(row.Total_Floors__c))
            );
            for (Integer floorCounter = 1; totalFloors != null && floorCounter <= totalFloors; floorCounter++) {
                String floorScopeValue = buildFloorScopeValue(row.Id, floorCounter);
                if (String.isBlank(floorScopeValue) || seenFloorValues.contains(floorScopeValue)) {
                    continue;
                }

                OptionItem floorOption = new OptionItem();
                floorOption.label = buildingLabel + ' - Floor ' + String.valueOf(floorCounter);
                floorOption.value = floorScopeValue;
                floorOption.buildingValue = String.valueOf(row.Id);
                response.floors.add(floorOption);
                seenFloorValues.add(floorScopeValue);
            }
        }

        Map<Id, Set<String>> roomCategoryBuildingValues = new Map<Id, Set<String>>();
        Map<Id, Set<String>> roomCategoryFloorValues = new Map<Id, Set<String>>();
        for (Ken_Room__c row : [
            SELECT Building__c, Room_Category__c, Floor__c, Floor__r.Name
            FROM Ken_Room__c
            WHERE Building__c != null AND Room_Category__c != null
            LIMIT 5000
        ]) {
            if (!roomCategoryBuildingValues.containsKey(row.Room_Category__c)) {
                roomCategoryBuildingValues.put(row.Room_Category__c, new Set<String>());
            }
            if (!roomCategoryFloorValues.containsKey(row.Room_Category__c)) {
                roomCategoryFloorValues.put(row.Room_Category__c, new Set<String>());
            }

            roomCategoryBuildingValues.get(row.Room_Category__c).add(String.valueOf(row.Building__c));

            Integer floorNumber = extractPositiveIntegerFromText(
                row.Floor__r != null ? row.Floor__r.Name : String.valueOf(row.Floor__c)
            );
            String floorScopeValue = buildFloorScopeValue(row.Building__c, floorNumber);
            if (String.isNotBlank(floorScopeValue)) {
                roomCategoryFloorValues.get(row.Room_Category__c).add(floorScopeValue);
            }
        }

        for (Ken_Room_Category__c row : [
            SELECT Id, Name, Name__c
            FROM Ken_Room_Category__c
            ORDER BY Name__c, Name
            LIMIT 2000
        ]) {
            OptionItem roomCategoryOption = toOptionItem(row.Id, preferredLabel(row.Name__c, row.Name));
            roomCategoryOption.buildingValues = roomCategoryBuildingValues.containsKey(row.Id)
                ? new List<String>(roomCategoryBuildingValues.get(row.Id))
                : new List<String>();
            roomCategoryOption.floorValues = roomCategoryFloorValues.containsKey(row.Id)
                ? new List<String>(roomCategoryFloorValues.get(row.Id))
                : new List<String>();
            response.roomCategories.add(roomCategoryOption);
        }

        return response;
    }

    @AuraEnabled
    public static List<BuildingAllocationRow> getBuildingAllocationPreview(List<String> buildingIds, List<String> roomCategoryIds) {
        List<Id> buildingRecordIds = normalizeIdList(buildingIds, 'Invalid building.');
        List<Id> roomCategoryRecordIds = normalizeIdList(roomCategoryIds, 'Invalid room category.');
        return buildBuildingAllocationRows(buildingRecordIds, roomCategoryRecordIds, null);
    }

    @AuraEnabled
    public static List<WindowRow> getWindows(String cycleId) {
        Id cycleRecordId = toId(cycleId, 'Invalid cycle.');
        if (cycleRecordId == null) {
            throw new AuraHandledException('Cycle is required.');
        }
        if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view windows.');
        }

        List<Ken_Windows__c> windowRecords = [
            SELECT
                Id,
                Name,
                Hostel_Cycle__c,
                Start_Date__c,
                End_Date__c,
                Room_Allotment_Start_Date__c,
                Room_Allotment_End_Date__c,
                Start_Time__c,
                End_Time__c,
                Payment_Deadline__c,
                Allotment_Type__c,
                Enable_Room_Preference__c,
                Maximum_Room_Preference__c,
                Enable_Maximum_Room_Capacity__c,
                Maximum_Room_Capacity__c,
                Allow_Roommate_Preference__c,
                CreatedBy.Name,
                CreatedDate,
                LastModifiedBy.Name,
                LastModifiedDate
            FROM Ken_Windows__c
            WHERE Hostel_Cycle__c = :cycleRecordId
            ORDER BY Start_Date__c ASC, Start_Time__c ASC, CreatedDate ASC
        ];

        Map<Id, WindowRow> windowsById = new Map<Id, WindowRow>();
        List<WindowRow> response = new List<WindowRow>();
        for (Ken_Windows__c row : windowRecords) {
            WindowRow item = new WindowRow();
            item.id = row.Id;
            item.name = sanitize(row.Name);
            item.startDate = formatDateInput(row.Start_Date__c);
            item.endDate = formatDateInput(row.End_Date__c);
            item.roomAllotmentStartDate = formatDateInput(row.Room_Allotment_Start_Date__c);
            item.roomAllotmentEndDate = formatDateInput(row.Room_Allotment_End_Date__c);
            item.startTime = formatTimeInput(row.Start_Time__c);
            item.endTime = formatTimeInput(row.End_Time__c);
            item.paymentDeadline = formatDateInput(row.Payment_Deadline__c);
            item.allotmentType = normalizeWindowAllotmentType(row.Allotment_Type__c);
            item.status = '';
            item.enableRoomPreference = row.Enable_Room_Preference__c;
            item.maxRoomPreferences = formatNumberValue(row.Maximum_Room_Preference__c);
            item.enableMaximumRoomCapacity = row.Enable_Maximum_Room_Capacity__c;
            item.maxRoomCapacity = formatNumberValue(row.Maximum_Room_Capacity__c);
            item.allowRoommatePreference = row.Allow_Roommate_Preference__c;
            item.programPathwayIds = new List<String>();
            item.buildingIds = new List<String>();
            item.roomCategoryIds = new List<String>();
            item.programPathwayLabels = new List<String>();
            item.buildingLabels = new List<String>();
            item.roomCategoryLabels = new List<String>();
            item.buildingAllocationRows = new List<BuildingAllocationRow>();
            item.createdBy = row.CreatedBy != null ? sanitize(row.CreatedBy.Name) : null;
            item.createdAt = formatDateTimeIso(row.CreatedDate);
            item.lastModifiedBy = row.LastModifiedBy != null ? sanitize(row.LastModifiedBy.Name) : null;
            item.lastModifiedAt = formatDateTimeIso(row.LastModifiedDate);
            response.add(item);
            windowsById.put(row.Id, item);
        }

        hydrateWindowScopes(windowsById);
        return response;
    }

    @AuraEnabled
    public static Id createCycle(CreateCycleRequest inputRequest) {
        return upsertCycle(null, inputRequest);
    }

    @AuraEnabled
    public static Id updateCycle(String cycleId, CreateCycleRequest inputRequest) {
        if (String.isBlank(cycleId)) {
            throw new AuraHandledException('Cycle is required.');
        }
        Id cycleRecordId = toId(cycleId, 'Invalid cycle.');
        return upsertCycle(cycleRecordId, inputRequest);
    }

    @AuraEnabled
    public static void deleteCycle(String cycleId) {
        if (String.isBlank(cycleId)) {
            throw new AuraHandledException('Cycle is required.');
        }
        Id cycleRecordId = toId(cycleId, 'Invalid cycle.');
        if (!Schema.sObjectType.Hostel_Cycle__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view hostel cycles.');
        }
        List<Hostel_Cycle__c> cycleRows = [SELECT Id FROM Hostel_Cycle__c WHERE Id = :cycleRecordId LIMIT 1];
        if (cycleRows.isEmpty()) {
            return;
        }
        if (!Schema.sObjectType.Hostel_Cycle__c.isDeletable()) {
            throw new AuraHandledException('You do not have permission to delete hostel cycles.');
        }
        delete cycleRows[0];
    }

    @AuraEnabled
    public static Id createWindow(String cycleId, SaveWindowRequest inputRequest) {
        return upsertWindow(null, cycleId, inputRequest);
    }

    @AuraEnabled
    public static Id updateWindow(String windowId, String cycleId, SaveWindowRequest inputRequest) {
        return upsertWindow(toId(windowId, 'Invalid window.'), cycleId, inputRequest);
    }

    @AuraEnabled
    public static void deleteWindow(String windowId) {
        Id windowRecordId = toId(windowId, 'Invalid window.');
        if (windowRecordId == null) {
            throw new AuraHandledException('Window is required.');
        }

        deleteWindowScopeRecords(windowRecordId);
        if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view windows.');
        }
        List<Ken_Windows__c> windowRows = [SELECT Id FROM Ken_Windows__c WHERE Id = :windowRecordId LIMIT 1];
        if (windowRows.isEmpty()) {
            return;
        }
        if (!Schema.sObjectType.Ken_Windows__c.isDeletable()) {
            throw new AuraHandledException('You do not have permission to delete windows.');
        }
        delete windowRows[0];
    }

    private static Id upsertCycle(Id cycleRecordId, CreateCycleRequest inputRequest) {
        if (inputRequest == null) {
            throw new AuraHandledException('Cycle payload is required.');
        }

        String nameValue = sanitize(inputRequest.name);
        String startDateValue = sanitize(inputRequest.startDate);
        String endDateValue = sanitize(inputRequest.endDate);
        String statusValue = sanitize(inputRequest.status);
        Boolean carryForwardEnabled = inputRequest.carryForwardEnabled == true;
        Id previousCycleId = toId(inputRequest.previousCycleId, 'Invalid previous cycle.');
        AcademicYearSelection academicYearSelection = resolveAcademicYearSelection(
            inputRequest.academicYearIds,
            inputRequest.academicYear
        );

        if (String.isBlank(nameValue)) {
            throw new AuraHandledException('Cycle Name is required.');
        }
        if (academicYearSelection.ids.isEmpty()) {
            throw new AuraHandledException('Academic Year is required.');
        }
        if (String.isBlank(startDateValue)) {
            throw new AuraHandledException('Cycle Start Date & Time is required.');
        }
        if (String.isBlank(endDateValue)) {
            throw new AuraHandledException('Cycle End Date & Time is required.');
        }
        if (String.isBlank(statusValue)) {
            throw new AuraHandledException('Status is required.');
        }
        if (carryForwardEnabled && previousCycleId == null) {
            throw new AuraHandledException('Select Previous Cycle is required when carry forward is enabled.');
        }
        if (carryForwardEnabled && cycleRecordId != null && previousCycleId == cycleRecordId) {
            throw new AuraHandledException('Previous Cycle cannot be the same as the current cycle.');
        }

        Datetime startDateTime = parseToDateTime(startDateValue);
        Datetime endDateTime = parseToDateTime(endDateValue);
        if (cycleRecordId == null && startDateTime.date() < Date.today()) {
            throw new AuraHandledException('Cycle Start Date cannot be in the past.');
        }
        if (cycleRecordId == null && endDateTime <= startDateTime) {
            throw new AuraHandledException('Cycle End Date & Time must be after Start Date & Time.');
        }

        Hostel_Cycle__c cycle;
        if (cycleRecordId == null) {
            cycle = new Hostel_Cycle__c();
        } else {
            if (!Schema.sObjectType.Hostel_Cycle__c.isAccessible()) {
                throw new AuraHandledException('You do not have permission to view hostel cycles.');
            }
            cycle = [SELECT Id FROM Hostel_Cycle__c WHERE Id = :cycleRecordId LIMIT 1];
        }
        cycle.Name = nameValue;
        cycle.Academic_Year__c = null;
        cycle.Academic_Years_Display__c = String.join(academicYearSelection.labels, ', ');
        cycle.Cycle_Start_Date_Time__c = startDateTime;
        cycle.Cycle_End_Date_Time__c = endDateTime;
        cycle.Status__c = statusValue;
        cycle.put('Previous_Cycle__c', carryForwardEnabled ? previousCycleId : null);

        if (cycleRecordId == null) {
            if (!Schema.sObjectType.Hostel_Cycle__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create hostel cycles.');
            }
            insert cycle;
        } else {
            if (!Schema.sObjectType.Hostel_Cycle__c.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update hostel cycles.');
            }
            update cycle;
        }
        syncCycleAcademicYears(cycle.Id, academicYearSelection.ids);
        return cycle.Id;
    }

    private static Id upsertWindow(Id windowRecordId, String cycleId, SaveWindowRequest inputRequest) {
        if (inputRequest == null) {
            throw new AuraHandledException('Window payload is required.');
        }

        Id cycleRecordId = toId(cycleId, 'Invalid cycle.');
        if (cycleRecordId == null) {
            throw new AuraHandledException('Cycle is required.');
        }

        String nameValue = sanitize(inputRequest.name);
        String startDateValue = sanitize(inputRequest.startDate);
        String endDateValue = sanitize(inputRequest.endDate);
        String roomAllotmentStartDateValue = sanitize(inputRequest.roomAllotmentStartDate);
        String roomAllotmentEndDateValue = sanitize(inputRequest.roomAllotmentEndDate);
        String startTimeValue = sanitize(inputRequest.startTime);
        String endTimeValue = sanitize(inputRequest.endTime);
        String paymentDeadlineValue = sanitize(inputRequest.paymentDeadline);
        String allotmentTypeValue = sanitize(inputRequest.allotmentType);
        Boolean enableRoomPreference = inputRequest.enableRoomPreference == true;
        Boolean enableMaximumRoomCapacity = inputRequest.enableMaximumRoomCapacity == true;
        Boolean allowRoommatePreference = inputRequest.allowRoommatePreference == true;
        List<Id> programPathwayIds = normalizeIdList(inputRequest.programPathwayIds, 'Invalid learning program plan.');
        List<Id> buildingIds = normalizeIdList(inputRequest.buildingIds, 'Invalid building.');
        List<Id> roomCategoryIds = normalizeIdList(inputRequest.roomCategoryIds, 'Invalid room category.');

        if (String.isBlank(nameValue)) {
            throw new AuraHandledException('Window Name is required.');
        }
        if (String.isBlank(startDateValue)) {
            throw new AuraHandledException('Start Date is required.');
        }
        if (String.isBlank(endDateValue)) {
            throw new AuraHandledException('End Date is required.');
        }
        if (String.isBlank(startTimeValue)) {
            throw new AuraHandledException('Start Time is required.');
        }
        if (String.isBlank(endTimeValue)) {
            throw new AuraHandledException('End Time is required.');
        }
        if (String.isBlank(paymentDeadlineValue)) {
            throw new AuraHandledException('Payment Deadline is required.');
        }
        if (String.isBlank(allotmentTypeValue)) {
            throw new AuraHandledException('Allotment Type is required.');
        }
        if (programPathwayIds.isEmpty()) {
            throw new AuraHandledException('Select at least one Learning Program Plan.');
        }
        if (buildingIds.isEmpty()) {
            throw new AuraHandledException('Select at least one Building.');
        }

        Date startDate = parseToDate(startDateValue);
        Date endDate = parseToDate(endDateValue);
        Date roomAllotmentStartDate = String.isBlank(roomAllotmentStartDateValue)
            ? null
            : parseToDate(roomAllotmentStartDateValue);
        Date roomAllotmentEndDate = String.isBlank(roomAllotmentEndDateValue)
            ? null
            : parseToDate(roomAllotmentEndDateValue);
        Date paymentDeadline = parseToDate(paymentDeadlineValue);
        Time startTime = parseToTime(startTimeValue);
        Time endTime = parseToTime(endTimeValue);

        if (startDate > endDate) {
            throw new AuraHandledException('Window End Date must be after Start Date.');
        }
        if ((roomAllotmentStartDate == null && roomAllotmentEndDate != null)
            || (roomAllotmentStartDate != null && roomAllotmentEndDate == null)
        ) {
            throw new AuraHandledException('Room Allotment Start Date and End Date must both be provided.');
        }
        if (roomAllotmentStartDate != null && roomAllotmentEndDate != null && roomAllotmentStartDate > roomAllotmentEndDate) {
            throw new AuraHandledException('Room Allotment End Date must be after Start Date.');
        }

        Datetime windowStart = Datetime.newInstance(startDate, startTime);
        Datetime windowEnd = Datetime.newInstance(endDate, endTime);
        if (windowStart >= windowEnd) {
            throw new AuraHandledException('Window End Time must be after Start Time.');
        }

        validateWindowAgainstCycle(cycleRecordId, windowStart, windowEnd);
        validateProgramPlansAreUniqueWithinCycle(cycleRecordId, windowRecordId, programPathwayIds);

        Decimal maximumRoomPreference = null;
        Decimal maximumRoomCapacity = null;
        Boolean isProvisionalAllotment = isProvisionalWindowAllotmentType(allotmentTypeValue);
        if (isProvisionalAllotment) {
            if (enableRoomPreference) {
                maximumRoomPreference = parsePositiveNumber(inputRequest.maxRoomPreferences, 'Maximum Room Preferences');
            }
            if (enableMaximumRoomCapacity) {
                maximumRoomCapacity = parsePositiveNumber(inputRequest.maxRoomCapacity, 'Maximum Room Capacity');
            }
        } else {
            enableRoomPreference = false;
            enableMaximumRoomCapacity = false;
            allowRoommatePreference = false;
        }
        String normalizedAllotmentTypeValue = deriveWindowAllotmentType(
            allotmentTypeValue,
            enableRoomPreference,
            enableMaximumRoomCapacity,
            allowRoommatePreference
        );

        Ken_Windows__c windowRecord;
        if (windowRecordId == null) {
            windowRecord = new Ken_Windows__c();
        } else {
            if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
                throw new AuraHandledException('You do not have permission to view windows.');
            }
            windowRecord = [
                SELECT Id
                FROM Ken_Windows__c
                WHERE Id = :windowRecordId
                LIMIT 1
            ];
        }

        windowRecord.Name = nameValue;
        windowRecord.Hostel_Cycle__c = cycleRecordId;
        windowRecord.Start_Date__c = startDate;
        windowRecord.End_Date__c = endDate;
        windowRecord.Room_Allotment_Start_Date__c = roomAllotmentStartDate;
        windowRecord.Room_Allotment_End_Date__c = roomAllotmentEndDate;
        windowRecord.Start_Time__c = startTime;
        windowRecord.End_Time__c = endTime;
        windowRecord.Payment_Deadline__c = paymentDeadline;
        windowRecord.Allotment_Type__c = normalizedAllotmentTypeValue;
        windowRecord.Enable_Room_Preference__c = enableRoomPreference;
        windowRecord.Maximum_Room_Preference__c = maximumRoomPreference;
        windowRecord.Enable_Maximum_Room_Capacity__c = enableMaximumRoomCapacity;
        windowRecord.Maximum_Room_Capacity__c = maximumRoomCapacity;
        windowRecord.Allow_Roommate_Preference__c = allowRoommatePreference;

        if (windowRecordId == null) {
            if (!Schema.sObjectType.Ken_Windows__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create windows.');
            }
            insert windowRecord;
        } else {
            if (!Schema.sObjectType.Ken_Windows__c.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update windows.');
            }
            update windowRecord;
        }

        Map<Id, BuildingAllocationRow> buildingAllocationRowsById = normalizeBuildingAllocationRows(
            inputRequest.buildingAllocationRows,
            buildingIds,
            roomCategoryIds,
            isProvisionalAllotment
        );

        syncWindowBuildings(windowRecord.Id, windowRecord.Name, buildingIds, buildingAllocationRowsById);
        syncWindowProgramPathways(windowRecord.Id, windowRecord.Name, programPathwayIds);
        syncWindowRoomCategories(windowRecord.Id, windowRecord.Name, roomCategoryIds);
        return windowRecord.Id;
    }

    private static String normalizeWindowAllotmentType(String typeValue) {
        String normalizedValue = sanitize(typeValue);
        String normalizedKey = normalizedValue.toLowerCase();
        if (normalizedKey == 'direct' || normalizedKey == 'direct allotment') {
            return 'Direct Allotment';
        }
        if (normalizedKey == 'provisional' || normalizedKey == 'provisional allotment') {
            return 'Provisional Allotment';
        }
        if (normalizedKey == 'preference selected' || normalizedKey == 'preference allotment') {
            return 'Preference Selected';
        }
        if (normalizedKey == 'final allotment' || normalizedKey == 'confirmed allotment') {
            return 'Confirmed Allotment';
        }
        if (normalizedKey == 'stay completed') {
            return 'Stay Completed';
        }
        return normalizedValue;
    }

    private static Boolean isProvisionalWindowAllotmentType(String typeValue) {
        String normalizedKey = normalizeWindowAllotmentType(typeValue).toLowerCase();
        return normalizedKey == 'provisional allotment' || normalizedKey == 'preference selected';
    }

    private static String deriveWindowAllotmentType(
        String requestedType,
        Boolean enableRoomPreference,
        Boolean enableMaximumRoomCapacity,
        Boolean allowRoommatePreference
    ) {
        if (!isProvisionalWindowAllotmentType(requestedType)) {
            return 'Direct Allotment';
        }
        if (enableRoomPreference == true || enableMaximumRoomCapacity == true || allowRoommatePreference == true) {
            return 'Preference Selected';
        }
        return 'Provisional Allotment';
    }

    private static Map<Id, Integer> getWindowCountsByCycle(Set<Id> cycleIds) {
        Map<Id, Integer> response = new Map<Id, Integer>();
        if (cycleIds == null || cycleIds.isEmpty()) {
            return response;
        }
        if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view windows.');
        }

        for (AggregateResult row : [
            SELECT Hostel_Cycle__c cycleId, COUNT(Id) recordCount
            FROM Ken_Windows__c
            WHERE Hostel_Cycle__c IN :cycleIds
            GROUP BY Hostel_Cycle__c
        ]) {
            response.put(
                (Id) row.get('cycleId'),
                Integer.valueOf(String.valueOf(row.get('recordCount')))
            );
        }
        return response;
    }

    private static Map<Id, Integer> getApplicationCountsByCycle(Set<Id> cycleIds) {
        Map<Id, Integer> response = new Map<Id, Integer>();
        if (cycleIds == null || cycleIds.isEmpty()) {
            return response;
        }
        if (!Schema.sObjectType.Ken_Room_Request__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room requests.');
        }

        Map<Id, Set<String>> applicantKeysByCycleId = new Map<Id, Set<String>>();
        for (Ken_Room_Request__c row : [
            SELECT Window__r.Hostel_Cycle__c, Request_By__c, Requested_By__c
            FROM Ken_Room_Request__c
            WHERE Window__c != null
                AND Window__r.Hostel_Cycle__c IN :cycleIds
                AND (Request_By__c != null OR Requested_By__c != null)
                AND Status__c != null
                AND Status__c != 'Canceled'
                AND Status__c != 'Rejected'
        ]) {
            Id cycleId = row.Window__r != null ? row.Window__r.Hostel_Cycle__c : null;
            if (cycleId == null) {
                continue;
            }

            if (!applicantKeysByCycleId.containsKey(cycleId)) {
                applicantKeysByCycleId.put(cycleId, new Set<String>());
            }

            String applicantKey = row.Request_By__c != null
                ? 'A:' + String.valueOf(row.Request_By__c)
                : 'C:' + String.valueOf(row.Requested_By__c);
            applicantKeysByCycleId.get(cycleId).add(applicantKey);
        }

        for (Id cycleId : applicantKeysByCycleId.keySet()) {
            response.put(cycleId, applicantKeysByCycleId.get(cycleId).size());
        }
        return response;
    }

    private static void deleteWindowScopeRecords(Id windowId) {
        if (windowId == null) {
            return;
        }
        if (!Schema.sObjectType.Ken_Window_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view window buildings.');
        }
        if (!Schema.sObjectType.Ken_Window_Learning_Program_Plan__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view window learning program plans.');
        }
        if (!Schema.sObjectType.Ken_Window_Room_Category__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view window room categories.');
        }
        if (!Schema.sObjectType.Ken_Window_Program_Pathway__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view legacy window program pathways.');
        }

        List<SObject> rowsToDelete = new List<SObject>();
        rowsToDelete.addAll([
            SELECT Id
            FROM Ken_Window_Building__c
            WHERE Windows__c = :windowId
        ]);
        rowsToDelete.addAll([
            SELECT Id
            FROM Ken_Window_Learning_Program_Plan__c
            WHERE Window__c = :windowId
        ]);
        rowsToDelete.addAll([
            SELECT Id
            FROM Ken_Window_Room_Category__c
            WHERE Windows__c = :windowId
        ]);
        rowsToDelete.addAll([
            SELECT Id
            FROM Ken_Window_Program_Pathway__c
            WHERE Window__c = :windowId
        ]);

        if (!rowsToDelete.isEmpty()) {
            if (!Schema.sObjectType.Ken_Window_Building__c.isDeletable()
                || !Schema.sObjectType.Ken_Window_Learning_Program_Plan__c.isDeletable()
                || !Schema.sObjectType.Ken_Window_Room_Category__c.isDeletable()
                || !Schema.sObjectType.Ken_Window_Program_Pathway__c.isDeletable()) {
                throw new AuraHandledException('You do not have permission to delete window scope records.');
            }
            delete rowsToDelete; // NOPMD ApexCRUDViolation - delete permissions are validated explicitly for each scope object type above.
        }
    }

    private static void hydrateWindowScopes(Map<Id, WindowRow> windowsById) {
        if (windowsById == null || windowsById.isEmpty()) {
            return;
        }

        Set<Id> windowIds = windowsById.keySet();
        if (!Schema.sObjectType.Ken_Window_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view window buildings.');
        }
        if (!Schema.sObjectType.Ken_Window_Learning_Program_Plan__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view window learning program plans.');
        }
        if (!Schema.sObjectType.Ken_Window_Room_Category__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view window room categories.');
        }

        for (Ken_Window_Building__c row : [
            SELECT Windows__c, Building__c, Building__r.Name, Building__r.Name__c, Limit_Mode__c, Allocation_Cap__c
            FROM Ken_Window_Building__c
            WHERE Windows__c IN :windowIds
            ORDER BY Building__r.Name__c, Building__r.Name
        ]) {
            WindowRow window = windowsById.get(row.Windows__c);
            if (window == null) {
                continue;
            }
            String buildingLabel = row.Building__r != null
                ? preferredLabel(row.Building__r.Name__c, row.Building__r.Name)
                : null;
            window.buildingIds.add(String.valueOf(row.Building__c));
            window.buildingLabels.add(buildingLabel);
            BuildingAllocationRow buildingAllocationRow = new BuildingAllocationRow();
            buildingAllocationRow.buildingId = String.valueOf(row.Building__c);
            buildingAllocationRow.building = buildingLabel;
            buildingAllocationRow.roomCount = 0;
            buildingAllocationRow.totalCapacity = 0;
            buildingAllocationRow.alreadyAllocated = 0;
            buildingAllocationRow.limitMode = String.isBlank(row.Limit_Mode__c) ? LIMIT_MODE_FULL_CAPACITY : row.Limit_Mode__c;
            buildingAllocationRow.allocationCap = formatNumberValue(row.Allocation_Cap__c);
            window.buildingAllocationRows.add(buildingAllocationRow);
        }

        for (Ken_Window_Learning_Program_Plan__c row : [
            SELECT Window__c, Learning_Program_Plan__c, Learning_Program_Plan__r.Name
            FROM Ken_Window_Learning_Program_Plan__c
            WHERE Window__c IN :windowIds
            ORDER BY Learning_Program_Plan__r.Name
        ]) {
            WindowRow window = windowsById.get(row.Window__c);
            if (window == null) {
                continue;
            }
            window.programPathwayIds.add(String.valueOf(row.Learning_Program_Plan__c));
            window.programPathwayLabels.add(
                row.Learning_Program_Plan__r != null ? sanitize(row.Learning_Program_Plan__r.Name) : null
            );
        }

        for (Ken_Window_Room_Category__c row : [
            SELECT Windows__c, Room_Category__c, Room_Category__r.Name, Room_Category__r.Name__c
            FROM Ken_Window_Room_Category__c
            WHERE Windows__c IN :windowIds
            ORDER BY Room_Category__r.Name__c, Room_Category__r.Name
        ]) {
            WindowRow window = windowsById.get(row.Windows__c);
            if (window == null) {
                continue;
            }
            window.roomCategoryIds.add(String.valueOf(row.Room_Category__c));
            window.roomCategoryLabels.add(
                row.Room_Category__r != null
                    ? preferredLabel(row.Room_Category__r.Name__c, row.Room_Category__r.Name)
                    : null
            );
        }
    }

    private static void syncWindowBuildings(
        Id windowId,
        String windowName,
        List<Id> buildingIds,
        Map<Id, BuildingAllocationRow> buildingAllocationRowsById
    ) {
        if (buildingAllocationRowsById == null) {
            buildingAllocationRowsById = new Map<Id, BuildingAllocationRow>();
        }
        if (!Schema.sObjectType.Ken_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view buildings.');
        }
        if (!Schema.sObjectType.Ken_Window_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view window buildings.');
        }

        Map<Id, String> buildingNamesById = new Map<Id, String>();
        if (!buildingIds.isEmpty()) {
            for (Ken_Building__c row : [
                SELECT Id, Name, Name__c
                FROM Ken_Building__c
                WHERE Id IN :buildingIds
            ]) {
                buildingNamesById.put(row.Id, preferredLabel(row.Name__c, row.Name));
            }
        }

        Map<Id, Ken_Window_Building__c> existingByBuildingId = new Map<Id, Ken_Window_Building__c>();
        for (Ken_Window_Building__c row : [
            SELECT Id, Name, Building__c, Limit_Mode__c, Allocation_Cap__c
            FROM Ken_Window_Building__c
            WHERE Windows__c = :windowId
        ]) {
            existingByBuildingId.put(row.Building__c, row);
        }

        Set<Id> requestedIds = new Set<Id>(buildingIds);
        List<Ken_Window_Building__c> toDelete = new List<Ken_Window_Building__c>();
        for (Ken_Window_Building__c row : existingByBuildingId.values()) {
            if (!requestedIds.contains(row.Building__c)) {
                toDelete.add(row);
            }
        }
        if (!toDelete.isEmpty()) {
            if (!Schema.sObjectType.Ken_Window_Building__c.isDeletable()) {
                throw new AuraHandledException('You do not have permission to delete window buildings.');
            }
            delete toDelete;
        }

        List<Ken_Window_Building__c> toUpdate = new List<Ken_Window_Building__c>();
        for (Id buildingId : buildingIds) {
            Ken_Window_Building__c existingRow = existingByBuildingId.get(buildingId);
            if (existingRow == null) {
                continue;
            }
            String desiredName = buildRelationshipName(windowName, buildingNamesById.get(buildingId));
            BuildingAllocationRow desiredConfig = buildingAllocationRowsById.containsKey(buildingId)
                ? buildingAllocationRowsById.get(buildingId)
                : null;
            String desiredLimitMode = desiredConfig == null || String.isBlank(desiredConfig.limitMode)
                ? LIMIT_MODE_FULL_CAPACITY
                : desiredConfig.limitMode;
            Decimal desiredAllocationCap = String.isBlank(desiredConfig == null ? null : desiredConfig.allocationCap)
                ? null
                : Decimal.valueOf(desiredConfig.allocationCap);

            if (
                existingRow.Name != desiredName ||
                existingRow.Limit_Mode__c != desiredLimitMode ||
                existingRow.Allocation_Cap__c != desiredAllocationCap
            ) {
                existingRow.Name = desiredName;
                existingRow.Limit_Mode__c = desiredLimitMode;
                existingRow.Allocation_Cap__c = desiredAllocationCap;
                toUpdate.add(existingRow);
            }
        }
        if (!toUpdate.isEmpty()) {
            if (!Schema.sObjectType.Ken_Window_Building__c.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update window buildings.');
            }
            update toUpdate;
        }

        List<Ken_Window_Building__c> toInsert = new List<Ken_Window_Building__c>();
        for (Id buildingId : buildingIds) {
            if (existingByBuildingId.containsKey(buildingId)) {
                continue;
            }
            Ken_Window_Building__c row = new Ken_Window_Building__c();
            row.Name = buildRelationshipName(windowName, buildingNamesById.get(buildingId));
            row.Windows__c = windowId;
            row.Building__c = buildingId;
            BuildingAllocationRow desiredConfig = buildingAllocationRowsById.containsKey(buildingId)
                ? buildingAllocationRowsById.get(buildingId)
                : null;
            row.Limit_Mode__c = desiredConfig == null || String.isBlank(desiredConfig.limitMode)
                ? LIMIT_MODE_FULL_CAPACITY
                : desiredConfig.limitMode;
            row.Allocation_Cap__c = String.isBlank(desiredConfig == null ? null : desiredConfig.allocationCap)
                ? null
                : Decimal.valueOf(desiredConfig.allocationCap);
            toInsert.add(row);
        }
        if (!toInsert.isEmpty()) {
            if (!Schema.sObjectType.Ken_Window_Building__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create window buildings.');
            }
            insert toInsert;
        }
    }

    private static void syncWindowProgramPathways(Id windowId, String windowName, List<Id> programPathwayIds) {
        deleteLegacyWindowProgramPathways(windowId);
        if (!Schema.sObjectType.LearningProgramPlan.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view learning program plans.');
        }
        if (!Schema.sObjectType.Ken_Window_Learning_Program_Plan__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view window learning program plans.');
        }

        Map<Id, String> programNamesById = new Map<Id, String>();
        if (!programPathwayIds.isEmpty()) {
            for (LearningProgramPlan row : [
                SELECT Id, Name
                FROM LearningProgramPlan
                WHERE Id IN :programPathwayIds
            ]) {
                programNamesById.put(row.Id, row.Name);
            }
        }

        Map<Id, Ken_Window_Learning_Program_Plan__c> existingByProgramPathwayId =
            new Map<Id, Ken_Window_Learning_Program_Plan__c>();
        for (Ken_Window_Learning_Program_Plan__c row : [
            SELECT Id, Name, Learning_Program_Plan__c
            FROM Ken_Window_Learning_Program_Plan__c
            WHERE Window__c = :windowId
        ]) {
            existingByProgramPathwayId.put(row.Learning_Program_Plan__c, row);
        }

        Set<Id> requestedIds = new Set<Id>(programPathwayIds);
        List<Ken_Window_Learning_Program_Plan__c> toDelete = new List<Ken_Window_Learning_Program_Plan__c>();
        for (Ken_Window_Learning_Program_Plan__c row : existingByProgramPathwayId.values()) {
            if (!requestedIds.contains(row.Learning_Program_Plan__c)) {
                toDelete.add(row);
            }
        }
        if (!toDelete.isEmpty()) {
            if (!Schema.sObjectType.Ken_Window_Learning_Program_Plan__c.isDeletable()) {
                throw new AuraHandledException('You do not have permission to delete window learning program plans.');
            }
            delete toDelete;
        }

        List<Ken_Window_Learning_Program_Plan__c> toUpdate = new List<Ken_Window_Learning_Program_Plan__c>();
        for (Id programPathwayId : programPathwayIds) {
            Ken_Window_Learning_Program_Plan__c existingRow = existingByProgramPathwayId.get(programPathwayId);
            if (existingRow == null) {
                continue;
            }
            String desiredName = buildRelationshipName(windowName, programNamesById.get(programPathwayId));
            if (existingRow.Name != desiredName) {
                existingRow.Name = desiredName;
                toUpdate.add(existingRow);
            }
        }
        if (!toUpdate.isEmpty()) {
            if (!Schema.sObjectType.Ken_Window_Learning_Program_Plan__c.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update window learning program plans.');
            }
            update toUpdate;
        }

        List<Ken_Window_Learning_Program_Plan__c> toInsert = new List<Ken_Window_Learning_Program_Plan__c>();
        for (Id programPathwayId : programPathwayIds) {
            if (existingByProgramPathwayId.containsKey(programPathwayId)) {
                continue;
            }
            Ken_Window_Learning_Program_Plan__c row = new Ken_Window_Learning_Program_Plan__c();
            row.Name = buildRelationshipName(windowName, programNamesById.get(programPathwayId));
            row.Window__c = windowId;
            row.Learning_Program_Plan__c = programPathwayId;
            toInsert.add(row);
        }
        if (!toInsert.isEmpty()) {
            if (!Schema.sObjectType.Ken_Window_Learning_Program_Plan__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create window learning program plans.');
            }
            insert toInsert;
        }
    }

    private static void deleteLegacyWindowProgramPathways(Id windowId) {
        if (windowId == null) {
            return;
        }
        if (!Schema.sObjectType.Ken_Window_Program_Pathway__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view legacy window program pathways.');
        }

        List<Ken_Window_Program_Pathway__c> rows = [
            SELECT Id
            FROM Ken_Window_Program_Pathway__c
            WHERE Window__c = :windowId
        ];
        if (!rows.isEmpty()) {
            if (!Schema.sObjectType.Ken_Window_Program_Pathway__c.isDeletable()) {
                throw new AuraHandledException('You do not have permission to delete legacy window program pathways.');
            }
            delete rows;
        }
    }

    private static void syncWindowRoomCategories(Id windowId, String windowName, List<Id> roomCategoryIds) {
        if (!Schema.sObjectType.Ken_Room_Category__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room categories.');
        }
        if (!Schema.sObjectType.Ken_Window_Room_Category__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view window room categories.');
        }
        Map<Id, String> roomCategoryNamesById = new Map<Id, String>();
        if (!roomCategoryIds.isEmpty()) {
            for (Ken_Room_Category__c row : [
                SELECT Id, Name, Name__c
                FROM Ken_Room_Category__c
                WHERE Id IN :roomCategoryIds
            ]) {
                roomCategoryNamesById.put(row.Id, preferredLabel(row.Name__c, row.Name));
            }
        }

        Map<Id, Ken_Window_Room_Category__c> existingByRoomCategoryId = new Map<Id, Ken_Window_Room_Category__c>();
        for (Ken_Window_Room_Category__c row : [
            SELECT Id, Name, Room_Category__c
            FROM Ken_Window_Room_Category__c
            WHERE Windows__c = :windowId
        ]) {
            existingByRoomCategoryId.put(row.Room_Category__c, row);
        }

        Set<Id> requestedIds = new Set<Id>(roomCategoryIds);
        List<Ken_Window_Room_Category__c> toDelete = new List<Ken_Window_Room_Category__c>();
        for (Ken_Window_Room_Category__c row : existingByRoomCategoryId.values()) {
            if (!requestedIds.contains(row.Room_Category__c)) {
                toDelete.add(row);
            }
        }
        if (!toDelete.isEmpty()) {
            if (!Schema.sObjectType.Ken_Window_Room_Category__c.isDeletable()) {
                throw new AuraHandledException('You do not have permission to delete window room categories.');
            }
            delete toDelete;
        }

        List<Ken_Window_Room_Category__c> toUpdate = new List<Ken_Window_Room_Category__c>();
        for (Id roomCategoryId : roomCategoryIds) {
            Ken_Window_Room_Category__c existingRow = existingByRoomCategoryId.get(roomCategoryId);
            if (existingRow == null) {
                continue;
            }
            String desiredName = buildRelationshipName(windowName, roomCategoryNamesById.get(roomCategoryId));
            if (existingRow.Name != desiredName) {
                existingRow.Name = desiredName;
                toUpdate.add(existingRow);
            }
        }
        if (!toUpdate.isEmpty()) {
            if (!Schema.sObjectType.Ken_Window_Room_Category__c.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update window room categories.');
            }
            update toUpdate;
        }

        List<Ken_Window_Room_Category__c> toInsert = new List<Ken_Window_Room_Category__c>();
        for (Id roomCategoryId : roomCategoryIds) {
            if (existingByRoomCategoryId.containsKey(roomCategoryId)) {
                continue;
            }
            Ken_Window_Room_Category__c row = new Ken_Window_Room_Category__c();
            row.Name = buildRelationshipName(windowName, roomCategoryNamesById.get(roomCategoryId));
            row.Windows__c = windowId;
            row.Room_Category__c = roomCategoryId;
            toInsert.add(row);
        }
        if (!toInsert.isEmpty()) {
            if (!Schema.sObjectType.Ken_Window_Room_Category__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create window room categories.');
            }
            insert toInsert;
        }
    }

    private static void validateWindowAgainstCycle(Id cycleId, Datetime windowStart, Datetime windowEnd) {
        if (!Schema.sObjectType.Hostel_Cycle__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view hostel cycles.');
        }
        SObject cycleRecord = [
            SELECT Cycle_Start_Date_Time__c, Cycle_End_Date_Time__c
            FROM Hostel_Cycle__c
            WHERE Id = :cycleId
            LIMIT 1
        ];

        Date cycleStart = coerceToDate(cycleRecord.get('Cycle_Start_Date_Time__c'));
        Date cycleEnd = coerceToDate(cycleRecord.get('Cycle_End_Date_Time__c'));
        Date windowStartDate = windowStart == null ? null : windowStart.date();
        Date windowEndDate = windowEnd == null ? null : windowEnd.date();

        if (cycleStart != null && windowStartDate != null && windowStartDate < cycleStart) {
            throw new AuraHandledException('Window dates must fall within the parent cycle range.');
        }
        if (cycleEnd != null && windowEndDate != null && windowEndDate > cycleEnd) {
            throw new AuraHandledException('Window dates must fall within the parent cycle range.');
        }
    }

    private static void validateProgramPlansAreUniqueWithinCycle(
        Id cycleId,
        Id currentWindowId,
        List<Id> programPathwayIds
    ) {
        if (cycleId == null || programPathwayIds == null || programPathwayIds.isEmpty()) {
            return;
        }
        if (!Schema.sObjectType.Ken_Window_Learning_Program_Plan__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view window learning program plans.');
        }

        Map<Id, String> programNamesById = new Map<Id, String>();
        Map<Id, Set<String>> windowNamesByProgramId = new Map<Id, Set<String>>();

        for (Ken_Window_Learning_Program_Plan__c row : [
            SELECT Window__c, Window__r.Name, Learning_Program_Plan__c, Learning_Program_Plan__r.Name
            FROM Ken_Window_Learning_Program_Plan__c
            WHERE Window__r.Hostel_Cycle__c = :cycleId
                AND Learning_Program_Plan__c IN :programPathwayIds
        ]) {
            if (row.Window__c == null || row.Learning_Program_Plan__c == null) {
                continue;
            }
            if (currentWindowId != null && row.Window__c == currentWindowId) {
                continue;
            }

            if (!windowNamesByProgramId.containsKey(row.Learning_Program_Plan__c)) {
                windowNamesByProgramId.put(row.Learning_Program_Plan__c, new Set<String>());
            }

            String windowName = sanitize(row.Window__r != null ? row.Window__r.Name : null);
            if (String.isNotBlank(windowName)) {
                windowNamesByProgramId.get(row.Learning_Program_Plan__c).add(windowName);
            }

            String programName = sanitize(row.Learning_Program_Plan__r != null ? row.Learning_Program_Plan__r.Name : null);
            if (String.isNotBlank(programName)) {
                programNamesById.put(row.Learning_Program_Plan__c, programName);
            }
        }

        if (windowNamesByProgramId.isEmpty()) {
            return;
        }

        List<String> duplicateDetails = new List<String>();
        for (Id programPathwayId : programPathwayIds) {
            if (!windowNamesByProgramId.containsKey(programPathwayId)) {
                continue;
            }

            List<String> windowNames = new List<String>();
            windowNames.addAll(windowNamesByProgramId.get(programPathwayId));
            windowNames.sort();

            String programName = programNamesById.containsKey(programPathwayId)
                ? programNamesById.get(programPathwayId)
                : 'Selected Learning Program Plan';
            String windowLabel;
            if (windowNames.isEmpty()) {
                windowLabel = 'another window';
            } else if (windowNames.size() == 1) {
                windowLabel = 'window "' + windowNames[0] + '"';
            } else {
                windowLabel = 'windows "' + String.join(windowNames, '", "') + '"';
            }
            duplicateDetails.add('"' + programName + '" is already assigned to ' + windowLabel);
        }

        if (duplicateDetails.isEmpty()) {
            return;
        }

        if (duplicateDetails.size() == 1) {
            throw new AuraHandledException('Learning Program Plan ' + duplicateDetails[0] + ' in this cycle.');
        }

        throw new AuraHandledException(
            'These Learning Program Plans are already assigned to other windows in this cycle: '
            + String.join(duplicateDetails, '; ')
            + '.'
        );
    }

    private static Date coerceToDate(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Date) {
            return (Date) value;
        }
        if (value instanceof Datetime) {
            return ((Datetime) value).date();
        }
        return null;
    }

    private static Datetime coerceToDatetime(Object value, Boolean isEndBoundary) {
        if (value == null) {
            return null;
        }
        if (value instanceof Datetime) {
            return (Datetime) value;
        }
        if (value instanceof Date) {
            return Datetime.newInstance((Date) value, isEndBoundary ? END_OF_DAY : START_OF_DAY);
        }
        return null;
    }

    private static List<BuildingAllocationRow> buildBuildingAllocationRows(
        List<Id> buildingIds,
        List<Id> roomCategoryIds,
        Map<Id, BuildingAllocationRow> savedConfigsByBuildingId
    ) {
        List<BuildingAllocationRow> response = new List<BuildingAllocationRow>();
        if (buildingIds == null || buildingIds.isEmpty()) {
            return response;
        }
        if (!Schema.sObjectType.Ken_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view buildings.');
        }

        if (savedConfigsByBuildingId == null) {
            savedConfigsByBuildingId = new Map<Id, BuildingAllocationRow>();
        }

        Set<Id> buildingIdSet = new Set<Id>(buildingIds);
        Set<Id> roomCategoryIdSet = roomCategoryIds == null ? new Set<Id>() : new Set<Id>(roomCategoryIds);
        Map<Id, BuildingAllocationMetrics> metricsByBuildingId = getBuildingAllocationMetricsByBuilding(buildingIdSet, roomCategoryIdSet);

        for (Ken_Building__c row : [
            SELECT Id, Name, Name__c
            FROM Ken_Building__c
            WHERE Id IN :buildingIdSet
            ORDER BY Name__c, Name
        ]) {
            BuildingAllocationMetrics metrics = metricsByBuildingId.containsKey(row.Id)
                ? metricsByBuildingId.get(row.Id)
                : new BuildingAllocationMetrics();
            BuildingAllocationRow savedConfig = savedConfigsByBuildingId.get(row.Id);

            BuildingAllocationRow item = new BuildingAllocationRow();
            item.buildingId = String.valueOf(row.Id);
            item.building = preferredLabel(row.Name__c, row.Name);
            item.roomCount = metrics.roomCount;
            item.totalCapacity = metrics.totalCapacity;
            item.alreadyAllocated = metrics.alreadyAllocated;
            item.limitMode = savedConfig == null || String.isBlank(savedConfig.limitMode)
                ? LIMIT_MODE_FULL_CAPACITY
                : savedConfig.limitMode;
            item.allocationCap = item.limitMode == LIMIT_MODE_CUSTOM_CAP
                ? sanitize(savedConfig == null ? null : savedConfig.allocationCap)
                : String.valueOf(metrics.totalCapacity);
            response.add(item);
        }

        return response;
    }

    private static Map<Id, BuildingAllocationRow> normalizeBuildingAllocationRows(
        List<BuildingAllocationRow> rawRows,
        List<Id> buildingIds,
        List<Id> roomCategoryIds,
        Boolean isProvisional
    ) {
        Map<Id, BuildingAllocationRow> response = new Map<Id, BuildingAllocationRow>();
        if (buildingIds == null || buildingIds.isEmpty()) {
            return response;
        }

        Set<Id> buildingIdSet = new Set<Id>(buildingIds);
        Set<Id> roomCategoryIdSet = roomCategoryIds == null ? new Set<Id>() : new Set<Id>(roomCategoryIds);
        Map<Id, BuildingAllocationMetrics> metricsByBuildingId = getBuildingAllocationMetricsByBuilding(buildingIdSet, roomCategoryIdSet);

        if (rawRows != null) {
            for (BuildingAllocationRow rawRow : rawRows) {
                Id buildingId = toId(rawRow == null ? null : rawRow.buildingId, 'Invalid building.');
                if (buildingId == null || !buildingIdSet.contains(buildingId)) {
                    continue;
                }

                BuildingAllocationMetrics metrics = metricsByBuildingId.containsKey(buildingId)
                    ? metricsByBuildingId.get(buildingId)
                    : new BuildingAllocationMetrics();

                BuildingAllocationRow normalizedRow = new BuildingAllocationRow();
                normalizedRow.buildingId = String.valueOf(buildingId);
                normalizedRow.limitMode = !isProvisional || String.isBlank(rawRow.limitMode)
                    ? LIMIT_MODE_FULL_CAPACITY
                    : sanitize(rawRow.limitMode);

                if (normalizedRow.limitMode != LIMIT_MODE_FULL_CAPACITY && normalizedRow.limitMode != LIMIT_MODE_CUSTOM_CAP) {
                    throw new AuraHandledException('Invalid Limit Mode selected.');
                }

                if (isProvisional && normalizedRow.limitMode == LIMIT_MODE_CUSTOM_CAP) {
                    Decimal allocationCap = parseNonNegativeWholeNumber(rawRow.allocationCap, 'Allocation Cap');
                    if (allocationCap.intValue() > metrics.totalCapacity) {
                        throw new AuraHandledException('Allocation Cap cannot exceed Total Capacity for the selected building.');
                    }
                    normalizedRow.allocationCap = String.valueOf(allocationCap.intValue());
                } else {
                    normalizedRow.limitMode = LIMIT_MODE_FULL_CAPACITY;
                    normalizedRow.allocationCap = null;
                }

                response.put(buildingId, normalizedRow);
            }
        }

        for (Id buildingId : buildingIds) {
            if (response.containsKey(buildingId)) {
                continue;
            }
            BuildingAllocationRow normalizedRow = new BuildingAllocationRow();
            normalizedRow.buildingId = String.valueOf(buildingId);
            normalizedRow.limitMode = LIMIT_MODE_FULL_CAPACITY;
            normalizedRow.allocationCap = null;
            response.put(buildingId, normalizedRow);
        }

        return response;
    }

    private static Map<Id, BuildingAllocationMetrics> getBuildingAllocationMetricsByBuilding(
        Set<Id> buildingIds,
        Set<Id> roomCategoryIds
    ) {
        Map<Id, BuildingAllocationMetrics> response = new Map<Id, BuildingAllocationMetrics>();
        if (buildingIds == null || buildingIds.isEmpty()) {
            return response;
        }
        if (!Schema.sObjectType.Ken_Room__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view rooms.');
        }
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room allotments.');
        }

        for (Id buildingId : buildingIds) {
            response.put(buildingId, new BuildingAllocationMetrics());
        }

        List<AggregateResult> roomCapacityRows;
        List<AggregateResult> provisionalAllocationRows;

        if (roomCategoryIds == null || roomCategoryIds.isEmpty()) {
            roomCapacityRows = [
                SELECT Building__c buildingId, COUNT(Id) roomCount, SUM(Capacity__c) totalCapacity
                FROM Ken_Room__c
                WHERE Building__c IN :buildingIds
                GROUP BY Building__c
            ];
            provisionalAllocationRows = [
                SELECT Room__r.Building__c buildingId, COUNT(Id) alreadyAllocated
                FROM Ken_Room_Allotment__c
                WHERE Active__c = true
                    AND Room__r.Building__c IN :buildingIds
                GROUP BY Room__r.Building__c
            ];
        } else {
            roomCapacityRows = [
                SELECT Building__c buildingId, COUNT(Id) roomCount, SUM(Capacity__c) totalCapacity
                FROM Ken_Room__c
                WHERE Building__c IN :buildingIds
                    AND Room_Category__c IN :roomCategoryIds
                GROUP BY Building__c
            ];
            provisionalAllocationRows = [
                SELECT Room__r.Building__c buildingId, COUNT(Id) alreadyAllocated
                FROM Ken_Room_Allotment__c
                WHERE Active__c = true
                    AND Room__r.Building__c IN :buildingIds
                    AND Room__r.Room_Category__c IN :roomCategoryIds
                GROUP BY Room__r.Building__c
            ];
        }

        for (AggregateResult row : roomCapacityRows) {
            Id buildingId = (Id) row.get('buildingId');
            if (!response.containsKey(buildingId)) {
                response.put(buildingId, new BuildingAllocationMetrics());
            }
            response.get(buildingId).roomCount = toIntegerValue(row.get('roomCount'));
            response.get(buildingId).totalCapacity = toIntegerValue(row.get('totalCapacity'));
        }

        for (AggregateResult row : provisionalAllocationRows) {
            Id buildingId = (Id) row.get('buildingId');
            if (!response.containsKey(buildingId)) {
                response.put(buildingId, new BuildingAllocationMetrics());
            }
            response.get(buildingId).alreadyAllocated = toIntegerValue(row.get('alreadyAllocated'));
        }

        return response;
    }

    private static OptionItem toOptionItem(Id recordId, String labelValue) {
        OptionItem item = new OptionItem();
        item.label = sanitize(labelValue);
        item.value = String.valueOf(recordId);
        return item;
    }

    private static String buildFloorScopeValue(Id buildingId, Integer floorNumber) {
        if (buildingId == null || floorNumber == null || floorNumber <= 0) {
            return null;
        }
        return String.valueOf(buildingId) + '::' + String.valueOf(floorNumber);
    }

    private static String preferredLabel(String primaryValue, String fallbackValue) {
        String primary = sanitize(primaryValue);
        if (String.isNotBlank(primary)) {
            return primary;
        }
        return sanitize(fallbackValue);
    }

    private static String resolveCycleAcademicYearDisplay(
        Hostel_Cycle__c cycleRecord,
        CycleAcademicYearInfo cycleAcademicYearInfo
    ) {
        if (cycleRecord == null) {
            return null;
        }

        if (cycleAcademicYearInfo != null && cycleAcademicYearInfo.labelsByCycleId.containsKey(cycleRecord.Id)) {
            List<String> labels = cycleAcademicYearInfo.labelsByCycleId.get(cycleRecord.Id);
            if (labels != null && !labels.isEmpty()) {
                return String.join(labels, ', ');
            }
        }

        String displayValue = sanitize(cycleRecord.Academic_Years_Display__c);
        if (String.isNotBlank(displayValue)) {
            return displayValue;
        }
        return sanitize(cycleRecord.Academic_Year__c);
    }

    private static CycleAcademicYearInfo getCycleAcademicYearInfo(List<Hostel_Cycle__c> cycleRecords) {
        CycleAcademicYearInfo response = new CycleAcademicYearInfo();
        if (cycleRecords == null || cycleRecords.isEmpty()) {
            return response;
        }
        if (!Schema.sObjectType.Hostel_Cycle_Academic_Year__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view cycle academic years.');
        }

        Set<Id> cycleIds = new Set<Id>();
        for (Hostel_Cycle__c row : cycleRecords) {
            if (row != null && row.Id != null) {
                cycleIds.add(row.Id);
            }
        }
        if (cycleIds.isEmpty()) {
            return response;
        }

        for (Hostel_Cycle_Academic_Year__c row : [
            SELECT Hostel_Cycle__c, Academic_Year__c, Academic_Year__r.Name
            FROM Hostel_Cycle_Academic_Year__c
            WHERE Hostel_Cycle__c IN :cycleIds
            ORDER BY Academic_Year__r.Name
        ]) {
            if (!response.labelsByCycleId.containsKey(row.Hostel_Cycle__c)) {
                response.labelsByCycleId.put(row.Hostel_Cycle__c, new List<String>());
                response.idsByCycleId.put(row.Hostel_Cycle__c, new List<String>());
            }
            response.labelsByCycleId.get(row.Hostel_Cycle__c).add(sanitize(row.Academic_Year__r.Name));
            response.idsByCycleId.get(row.Hostel_Cycle__c).add(String.valueOf(row.Academic_Year__c));
        }

        Map<String, AcademicYear> academicYearsByKey = null;
        for (Hostel_Cycle__c row : cycleRecords) {
            if (row == null || row.Id == null || response.labelsByCycleId.containsKey(row.Id)) {
                continue;
            }

            List<String> legacyValues = splitAcademicYearValues(
                String.isNotBlank(row.Academic_Year__c) ? row.Academic_Year__c : row.Academic_Years_Display__c
            );
            if (legacyValues.isEmpty()) {
                continue;
            }

            if (academicYearsByKey == null) {
                academicYearsByKey = getAcademicYearsByNormalizedKey();
            }

            List<String> labels = new List<String>();
            List<String> ids = new List<String>();
            Set<Id> seenAcademicYears = new Set<Id>();
            for (String legacyValue : legacyValues) {
                String normalizedKey = normalizeAcademicYearKey(legacyValue);
                AcademicYear matchedAcademicYear = String.isBlank(normalizedKey)
                    ? null
                    : academicYearsByKey.get(normalizedKey);
                if (matchedAcademicYear != null) {
                    if (!seenAcademicYears.contains(matchedAcademicYear.Id)) {
                        labels.add(sanitize(matchedAcademicYear.Name));
                        ids.add(String.valueOf(matchedAcademicYear.Id));
                        seenAcademicYears.add(matchedAcademicYear.Id);
                    }
                } else if (String.isNotBlank(legacyValue)) {
                    labels.add(legacyValue);
                }
            }

            if (!labels.isEmpty()) {
                response.labelsByCycleId.put(row.Id, labels);
            }
            if (!ids.isEmpty()) {
                response.idsByCycleId.put(row.Id, ids);
            }
        }

        return response;
    }

    private static AcademicYearSelection resolveAcademicYearSelection(
        List<String> rawAcademicYearIds,
        String legacyAcademicYearValue
    ) {
        AcademicYearSelection response = new AcademicYearSelection();
        List<Id> academicYearIds = normalizeIdList(rawAcademicYearIds, 'Invalid academic year.');
        if (!academicYearIds.isEmpty()) {
            if (!Schema.sObjectType.AcademicYear.isAccessible()) {
                throw new AuraHandledException('You do not have permission to view academic years.');
            }
            Map<Id, AcademicYear> academicYearsById = new Map<Id, AcademicYear>([
                SELECT Id, Name
                FROM AcademicYear
                WHERE Id IN :academicYearIds
            ]);
            if (academicYearsById.size() != academicYearIds.size()) {
                throw new AuraHandledException('One or more selected academic years are invalid.');
            }

            for (Id academicYearId : academicYearIds) {
                response.ids.add(academicYearId);
                response.labels.add(sanitize(academicYearsById.get(academicYearId).Name));
            }
            return response;
        }

        List<String> legacyValues = splitAcademicYearValues(legacyAcademicYearValue);
        if (legacyValues.isEmpty()) {
            return response;
        }

        Map<String, AcademicYear> academicYearsByKey = getAcademicYearsByNormalizedKey();
        Set<Id> seenAcademicYears = new Set<Id>();
        for (String legacyValue : legacyValues) {
            String normalizedKey = normalizeAcademicYearKey(legacyValue);
            AcademicYear matchedAcademicYear = String.isBlank(normalizedKey)
                ? null
                : academicYearsByKey.get(normalizedKey);
            if (matchedAcademicYear == null) {
                throw new AuraHandledException('One or more selected academic years are invalid.');
            }
            if (seenAcademicYears.contains(matchedAcademicYear.Id)) {
                continue;
            }
            response.ids.add(matchedAcademicYear.Id);
            response.labels.add(sanitize(matchedAcademicYear.Name));
            seenAcademicYears.add(matchedAcademicYear.Id);
        }

        return response;
    }

    private static void syncCycleAcademicYears(Id cycleId, List<Id> academicYearIds) {
        if (cycleId == null) {
            return;
        }
        if (!Schema.sObjectType.Hostel_Cycle_Academic_Year__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view cycle academic years.');
        }

        List<Hostel_Cycle_Academic_Year__c> existingRows = [
            SELECT Id, Academic_Year__c
            FROM Hostel_Cycle_Academic_Year__c
            WHERE Hostel_Cycle__c = :cycleId
        ];

        Map<Id, Hostel_Cycle_Academic_Year__c> existingByAcademicYearId =
            new Map<Id, Hostel_Cycle_Academic_Year__c>();
        for (Hostel_Cycle_Academic_Year__c row : existingRows) {
            if (row.Academic_Year__c != null) {
                existingByAcademicYearId.put(row.Academic_Year__c, row);
            }
        }

        Set<Id> requestedAcademicYearIds = new Set<Id>();
        if (academicYearIds != null) {
            requestedAcademicYearIds.addAll(academicYearIds);
        }

        List<Hostel_Cycle_Academic_Year__c> rowsToDelete = new List<Hostel_Cycle_Academic_Year__c>();
        for (Hostel_Cycle_Academic_Year__c row : existingRows) {
            if (!requestedAcademicYearIds.contains(row.Academic_Year__c)) {
                rowsToDelete.add(row);
            }
        }

        List<Hostel_Cycle_Academic_Year__c> rowsToInsert = new List<Hostel_Cycle_Academic_Year__c>();
        if (academicYearIds != null) {
            for (Id academicYearId : academicYearIds) {
                if (academicYearId == null || existingByAcademicYearId.containsKey(academicYearId)) {
                    continue;
                }
                rowsToInsert.add(new Hostel_Cycle_Academic_Year__c(
                    Hostel_Cycle__c = cycleId,
                    Academic_Year__c = academicYearId
                ));
            }
        }

        if (!rowsToDelete.isEmpty()) {
            if (!Schema.sObjectType.Hostel_Cycle_Academic_Year__c.isDeletable()) {
                throw new AuraHandledException('You do not have permission to delete cycle academic years.');
            }
            delete rowsToDelete;
        }
        if (!rowsToInsert.isEmpty()) {
            if (!Schema.sObjectType.Hostel_Cycle_Academic_Year__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create cycle academic years.');
            }
            insert rowsToInsert;
        }
    }

    private static Map<String, AcademicYear> getAcademicYearsByNormalizedKey() {
        Map<String, AcademicYear> response = new Map<String, AcademicYear>();
        if (!Schema.sObjectType.AcademicYear.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view academic years.');
        }
        for (AcademicYear row : [
            SELECT Id, Name
            FROM AcademicYear
            WHERE Name != null
            ORDER BY Name DESC
            LIMIT 2000
        ]) {
            String normalizedKey = normalizeAcademicYearKey(row.Name);
            if (String.isBlank(normalizedKey) || response.containsKey(normalizedKey)) {
                continue;
            }
            response.put(normalizedKey, row);
        }
        return response;
    }

    private static List<String> splitAcademicYearValues(String rawValue) {
        List<String> response = new List<String>();
        String cleaned = sanitize(rawValue);
        if (String.isBlank(cleaned)) {
            return response;
        }

        String normalized = cleaned.replace(';', ',');
        for (String segment : normalized.split(',')) {
            String value = sanitize(segment);
            if (String.isNotBlank(value)) {
                response.add(value);
            }
        }
        return response;
    }

    private static String normalizeAcademicYearKey(String rawValue) {
        String cleaned = sanitize(rawValue);
        if (String.isBlank(cleaned)) {
            return null;
        }
        String normalized = cleaned.toLowerCase().replaceAll('[^a-z0-9]', '');
        return String.isBlank(normalized) ? null : normalized;
    }

    private static List<Id> normalizeIdList(List<String> rawIds, String errorMessage) {
        List<Id> response = new List<Id>();
        Set<Id> seenIds = new Set<Id>();
        if (rawIds == null) {
            return response;
        }

        for (String rawId : rawIds) {
            Id value = toId(rawId, errorMessage);
            if (value == null || seenIds.contains(value)) {
                continue;
            }
            response.add(value);
            seenIds.add(value);
        }
        return response;
    }

    private static Decimal parseNonNegativeWholeNumber(String rawValue, String label) {
        String cleaned = sanitize(rawValue);
        if (String.isBlank(cleaned)) {
            throw new AuraHandledException(label + ' is required.');
        }
        try {
            Decimal value = Decimal.valueOf(cleaned);
            if (value < 0 || value.scale() > 0) {
                throw new AuraHandledException(label + ' must be a whole number 0 or greater.');
            }
            return value;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(label + ' must be a whole number 0 or greater.');
        }
    }

    private static Decimal parsePositiveNumber(String rawValue, String label) {
        String cleaned = sanitize(rawValue);
        if (String.isBlank(cleaned)) {
            throw new AuraHandledException(label + ' is required.');
        }
        try {
            Decimal value = Decimal.valueOf(cleaned);
            if (value <= 0 || value.scale() > 0) {
                throw new AuraHandledException(label + ' must be a whole number greater than 0.');
            }
            return value;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(label + ' must be a whole number greater than 0.');
        }
    }

    private static Time parseToTime(String rawValue) {
        String cleaned = sanitize(rawValue);
        if (String.isBlank(cleaned)) {
            return null;
        }

        List<String> segments = cleaned.split(':');
        if (segments.size() < 2) {
            throw new AuraHandledException('Invalid time value: ' + cleaned);
        }

        Integer hour;
        Integer minute;
        Integer second = 0;
        try {
            hour = Integer.valueOf(segments[0]);
            minute = Integer.valueOf(segments[1]);
            if (segments.size() > 2) {
                second = Integer.valueOf(segments[2]);
            }
            return Time.newInstance(hour, minute, second, 0);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid time value: ' + cleaned);
        }
    }

    private static String buildRelationshipName(String windowName, String relatedName) {
        String leftValue = sanitize(windowName);
        String rightValue = sanitize(relatedName);
        String nameValue;
        if (String.isNotBlank(leftValue) && String.isNotBlank(rightValue)) {
            nameValue = leftValue + ' - ' + rightValue;
        } else if (String.isNotBlank(rightValue)) {
            nameValue = rightValue;
        } else if (String.isNotBlank(leftValue)) {
            nameValue = leftValue;
        } else {
            nameValue = 'Window Scope';
        }
        return nameValue.length() > 80 ? nameValue.substring(0, 80) : nameValue;
    }

    private static String resolveStatusClass(String rawStatus) {
        String normalized = sanitize(rawStatus);
        if (String.isBlank(normalized)) {
            return 'hc-status-pill hc-status-closed';
        }
        String key = normalized.toLowerCase().replace(' ', '');
        if (key == 'open' || key == 'active') {
            return 'hc-status-pill hc-status-open';
        }
        if (key == 'scheduled') {
            return 'hc-status-pill hc-status-scheduled';
        }
        return 'hc-status-pill hc-status-closed';
    }

    private static String resolveWindowStatus(Date startDate, Time startTime, Date endDate, Time endTime) {
        Datetime startAt = startDate == null ? null : Datetime.newInstance(startDate, startTime == null ? START_OF_DAY : startTime);
        Datetime endAt = endDate == null ? null : Datetime.newInstance(endDate, endTime == null ? END_OF_DAY : endTime);
        Datetime nowValue = Datetime.now();

        if (startAt != null && nowValue < startAt) {
            return 'Upcoming';
        }
        if (endAt != null && nowValue > endAt) {
            return 'Closed';
        }
        return 'Open';
    }

    private static String formatDateValue(Object value) {
        if (value == null) {
            return '--';
        }
        if (value instanceof Date) {
            return ((Date) value).format();
        }
        if (value instanceof Datetime) {
            Datetime dt = (Datetime) value;
            return Date.newInstance(dt.year(), dt.month(), dt.day()).format();
        }
        return String.valueOf(value);
    }

    private static String formatDateInput(Date value) {
        if (value == null) {
            return null;
        }
        String month = String.valueOf(value.month()).leftPad(2, '0');
        String day = String.valueOf(value.day()).leftPad(2, '0');
        return String.valueOf(value.year()) + '-' + month + '-' + day;
    }

    private static String formatTimeInput(Time value) {
        if (value == null) {
            return null;
        }
        String hour = String.valueOf(value.hour()).leftPad(2, '0');
        String minute = String.valueOf(value.minute()).leftPad(2, '0');
        return hour + ':' + minute;
    }

    private static String formatNumberValue(Decimal value) {
        if (value == null) {
            return null;
        }
        return String.valueOf(value.intValue());
    }

    private static Integer toIntegerValue(Object value) {
        if (value == null) {
            return 0;
        }
        if (value instanceof Decimal) {
            return ((Decimal) value).intValue();
        }
        if (value instanceof Integer) {
            return (Integer) value;
        }
        if (value instanceof Long) {
            return Integer.valueOf(String.valueOf(value));
        }
        return Integer.valueOf(String.valueOf(value));
    }

    private static Integer extractPositiveIntegerFromText(String rawValue) {
        String cleaned = sanitize(rawValue);
        if (String.isBlank(cleaned)) {
            return null;
        }

        Matcher matcher = Pattern.compile('(\\d+)').matcher(cleaned);
        if (!matcher.find()) {
            return null;
        }

        try {
            Integer value = Integer.valueOf(matcher.group(1));
            return value > 0 ? value : null;
        } catch (Exception e) {
            return null;
        }
    }

    private static String formatDateTimeIso(Datetime value) {
        if (value == null) {
            return null;
        }
        return value.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }

    private static String formatDateTimeLocalValue(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Datetime) {
            Datetime dtValue = (Datetime) value;
            String month = String.valueOf(dtValue.month()).leftPad(2, '0');
            String day = String.valueOf(dtValue.day()).leftPad(2, '0');
            String hour = String.valueOf(dtValue.hour()).leftPad(2, '0');
            String minute = String.valueOf(dtValue.minute()).leftPad(2, '0');
            return String.valueOf(dtValue.year()) + '-' + month + '-' + day + 'T' + hour + ':' + minute;
        }
        if (value instanceof Date) {
            Date dateValue = (Date) value;
            String month = String.valueOf(dateValue.month()).leftPad(2, '0');
            String day = String.valueOf(dateValue.day()).leftPad(2, '0');
            return String.valueOf(dateValue.year()) + '-' + month + '-' + day + 'T00:00';
        }
        return null;
    }

    private static void setDateOrDateTimeField(SObject row, String fieldApiName, String rawValue) {
        if (row == null || String.isBlank(fieldApiName)) {
            return;
        }
        String cleaned = sanitize(rawValue);
        if (String.isBlank(cleaned)) {
            row.put(fieldApiName, null);
            return;
        }
        Schema.SObjectType recordType = row.getSObjectType();
        Schema.DescribeSObjectResult objectDescribe = recordType.getDescribe();
        Schema.SObjectField fieldToken = objectDescribe.fields.getMap().get(fieldApiName);
        if (fieldToken == null) {
            return;
        }
        Schema.DisplayType fieldType = fieldToken.getDescribe().getType();
        if (fieldType == Schema.DisplayType.Date) {
            row.put(fieldApiName, parseToDate(cleaned));
            return;
        }
        row.put(fieldApiName, parseToDateTime(cleaned));
    }

    private static Datetime parseToDateTime(String rawValue) {
        String cleaned = sanitize(rawValue);
        if (String.isBlank(cleaned)) {
            return null;
        }
        String normalized = cleaned.replace('T', ' ');
        if (normalized.length() == 16) {
            normalized += ':00';
        }
        try {
            return Datetime.valueOf(normalized);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid date/time value: ' + cleaned);
        }
    }

    private static Date parseToDate(String rawValue) {
        String cleaned = sanitize(rawValue);
        if (String.isBlank(cleaned)) {
            return null;
        }
        String normalized = cleaned;
        if (normalized.contains('T')) {
            normalized = normalized.substring(0, normalized.indexOf('T'));
        }
        try {
            return Date.valueOf(normalized);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid date value: ' + cleaned);
        }
    }

    private static Id toId(String rawId, String errorMessage) {
        if (String.isBlank(rawId)) {
            return null;
        }
        try {
            return (Id) rawId.trim();
        } catch (Exception e) {
            throw new AuraHandledException(errorMessage);
        }
    }

    private static String sanitize(String value) {
        return String.isBlank(value) ? null : value.trim();
    }
}