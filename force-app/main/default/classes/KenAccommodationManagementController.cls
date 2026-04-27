public with sharing class KenAccommodationManagementController {
    private static final Integer DEFAULT_AUTO_ALLOTMENT_BATCH_SIZE = 50;
    private static final String REALLOTMENT_FLAG_FIELD = 'Reassigned__c';

    private class WindowScope {
        public Set<Id> learningProgramPlanIds = new Set<Id>();
        public Set<Id> learningProgramIds = new Set<Id>();
        public Set<Id> buildingIds = new Set<Id>();
        public Set<Id> roomCategoryIds = new Set<Id>();
    }

    private class WindowAcademicYearScope {
        public Set<Id> academicYearIds = new Set<Id>();
        public Map<Id, Integer> priorityByAcademicYearId = new Map<Id, Integer>();
        public Map<String, Integer> priorityByAcademicYearKey = new Map<String, Integer>();
    }

    private class LearnerAcademicYearInfo {
        public Id academicYearId;
        public String academicYearLabel;
        public Integer priorityRank;
        public Datetime termStartDateTime;
        public Datetime createdDateTime;
    }

    public class OptionItem {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
    }

    public class WindowItem {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String allotmentType { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String startDate { get; set; }
        @AuraEnabled public String endDate { get; set; }
        @AuraEnabled public String autoAllotmentRule { get; set; }
        @AuraEnabled public Boolean autoAllotmentBatchProcessing { get; set; }
        @AuraEnabled public Integer autoAllotmentBatchSize { get; set; }
        @AuraEnabled public String autoAllotmentBatchGrouping { get; set; }
        @AuraEnabled public Boolean autoAllotmentPreviousYearCarryForward { get; set; }
        @AuraEnabled public List<String> programPriorityPlanIds { get; set; }
    }

    public class InProgressRow {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String accountId { get; set; }
        @AuraEnabled public String student { get; set; }
        @AuraEnabled public String rollNo { get; set; }
        @AuraEnabled public String program { get; set; }
        @AuraEnabled public String programPlanId { get; set; }
        @AuraEnabled public String year { get; set; }
        @AuraEnabled public String academicYear { get; set; }
        @AuraEnabled public Integer yearPriorityRank { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String payment { get; set; }
        @AuraEnabled public String allotmentType { get; set; }
        @AuraEnabled public String status { get; set; }
    }

    public class AllocatedRow {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String accountId { get; set; }
        @AuraEnabled public String student { get; set; }
        @AuraEnabled public String rollNo { get; set; }
        @AuraEnabled public String program { get; set; }
        @AuraEnabled public String programPlanId { get; set; }
        @AuraEnabled public String year { get; set; }
        @AuraEnabled public String room { get; set; }
        @AuraEnabled public String building { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String allotmentType { get; set; }
        @AuraEnabled public String source { get; set; }
        @AuraEnabled public String payment { get; set; }
        @AuraEnabled public String assignedOn { get; set; }
    }

    public class ApplicationDetailResponse {
        @AuraEnabled public String allotmentId { get; set; }
        @AuraEnabled public String studentName { get; set; }
        @AuraEnabled public String rollNo { get; set; }
        @AuraEnabled public String program { get; set; }
        @AuraEnabled public String year { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String allotmentType { get; set; }
        @AuraEnabled public String categoryApplied { get; set; }
        @AuraEnabled public String applicationStatus { get; set; }
        @AuraEnabled public String paymentStatus { get; set; }
        @AuraEnabled public String appliedOn { get; set; }
        @AuraEnabled public List<RoomPreferenceItem> roomPreferences { get; set; }
        @AuraEnabled public RoommatePreferenceItem roommatePreference { get; set; }

        public ApplicationDetailResponse() {
            roomPreferences = new List<RoomPreferenceItem>();
            roommatePreference = new RoommatePreferenceItem();
        }
    }

    public class AllocationDetailResponse {
        @AuraEnabled public String allotmentId { get; set; }
        @AuraEnabled public String studentName { get; set; }
        @AuraEnabled public String rollNo { get; set; }
        @AuraEnabled public String program { get; set; }
        @AuraEnabled public String year { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String roomNumber { get; set; }
        @AuraEnabled public String building { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String allotmentType { get; set; }
        @AuraEnabled public String paymentStatus { get; set; }
        @AuraEnabled public String assignmentSource { get; set; }
        @AuraEnabled public String assignedOn { get; set; }
    }

    public class RoomAssignmentOption {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String room { get; set; }
        @AuraEnabled public String building { get; set; }
        @AuraEnabled public String floorLabel { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public Integer capacity { get; set; }
        @AuraEnabled public Integer occupancy { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String statusTone { get; set; }
        @AuraEnabled public Boolean preferenceMatch { get; set; }
        @AuraEnabled public Boolean roommateMatch { get; set; }
        @AuraEnabled public Boolean isPreviousRoom { get; set; }
        @AuraEnabled public Boolean selectable { get; set; }
    }

    public class RoomPreferenceItem {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public Integer order { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String subtitle { get; set; }
        @AuraEnabled public String meta { get; set; }
        @AuraEnabled public String availabilityLabel { get; set; }
        @AuraEnabled public String availabilityTone { get; set; }
    }

    public class RoommatePreferenceItem {
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String rollNo { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String currentStatus { get; set; }
        @AuraEnabled public String matchLabel { get; set; }
        @AuraEnabled public String samePreferenceSelected { get; set; }
    }

    private class RoomAvailabilityMetrics {
        public String title;
        public String subtitle;
        public String categoryLabel;
        public Integer availableBeds = 0;
        public Integer totalBeds = 0;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionItem> getCycleOptions() {
        if (!Schema.sObjectType.Hostel_Cycle__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view hostel cycles.');
        }

        List<OptionItem> options = new List<OptionItem>();
        for (Hostel_Cycle__c cycleRecord : [
            SELECT Id, Name, Status__c, Cycle_Start_Date_Time__c
            FROM Hostel_Cycle__c
            ORDER BY Cycle_Start_Date_Time__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 200
        ]) {
            OptionItem item = new OptionItem();
            item.value = String.valueOf(cycleRecord.Id);
            item.label = buildCycleLabel(cycleRecord.Name, cycleRecord.Status__c);
            options.add(item);
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<WindowItem> getWindowOptions(String cycleId) {
        Id cycleRecordId = normalizeId(cycleId, 'Invalid cycle.');
        if (cycleRecordId == null) {
            return new List<WindowItem>();
        }
        if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view residence windows.');
        }
        if (!Schema.sObjectType.Ken_Window_Learning_Program_Plan__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view window learning program plans.');
        }

        List<WindowItem> windows = new List<WindowItem>();
        Map<Id, WindowItem> windowItemById = new Map<Id, WindowItem>();
        for (Ken_Windows__c windowRecord : [
            SELECT
                Id,
                Name,
                Hostel_Cycle__c,
                Allotment_Type__c,
                Start_Date__c,
                End_Date__c,
                Auto_Allotment_Allocation_Rule__c,
                Auto_Allotment_Batch_Processing__c,
                Auto_Allotment_Batch_Size__c,
                Auto_Allotment_Batch_Grouping__c,
                Auto_Allotment_Carry_Forward__c
            FROM Ken_Windows__c
            WHERE Hostel_Cycle__c = :cycleRecordId
            ORDER BY Start_Date__c ASC NULLS LAST, Start_Time__c ASC NULLS LAST, CreatedDate ASC
            LIMIT 500
        ]) {
            WindowItem item = new WindowItem();
            item.id = String.valueOf(windowRecord.Id);
            item.name = sanitize(windowRecord.Name);
            item.allotmentType = normalizeAllotmentTypeDisplay(windowRecord.Allotment_Type__c);
            item.status = resolveWindowStatus(windowRecord.Start_Date__c, windowRecord.End_Date__c);
            item.startDate = formatDate(windowRecord.Start_Date__c);
            item.endDate = formatDate(windowRecord.End_Date__c);
            item.label = buildWindowLabel(item.name, item.allotmentType, item.status);
            item.autoAllotmentRule = normalizeAutoAllotmentRule(windowRecord.Auto_Allotment_Allocation_Rule__c);
            item.autoAllotmentBatchProcessing = windowRecord.Auto_Allotment_Batch_Processing__c == true;
            item.autoAllotmentBatchSize = normalizeAutoAllotmentBatchSize(
                windowRecord.Auto_Allotment_Batch_Size__c == null
                    ? null
                    : windowRecord.Auto_Allotment_Batch_Size__c.intValue()
            );
            item.autoAllotmentBatchGrouping = normalizeAutoAllotmentBatchGrouping(
                windowRecord.Auto_Allotment_Batch_Grouping__c
            );
            item.autoAllotmentPreviousYearCarryForward = windowRecord.Auto_Allotment_Carry_Forward__c == true;
            item.programPriorityPlanIds = new List<String>();
            windows.add(item);
            windowItemById.put(windowRecord.Id, item);
        }

        if (!windowItemById.isEmpty()) {
            for (Ken_Window_Learning_Program_Plan__c row : [
                SELECT Window__c, Learning_Program_Plan__c
                FROM Ken_Window_Learning_Program_Plan__c
                WHERE Window__c IN :windowItemById.keySet()
                ORDER BY Window__c, CreatedDate ASC, Id ASC
            ]) {
                WindowItem item = windowItemById.get(row.Window__c);
                if (item == null || row.Learning_Program_Plan__c == null) {
                    continue;
                }
                item.programPriorityPlanIds.add(String.valueOf(row.Learning_Program_Plan__c));
            }
        }
        return windows;
    }

    @AuraEnabled
    public static void saveWindowAutoAllotmentConfig(
        String windowId,
        String allocationRule,
        Boolean batchProcessing,
        Integer batchSize,
        String batchGrouping,
        Boolean previousYearCarryForward
    ) {
        Id windowRecordId = normalizeId(windowId, 'Invalid window.');
        if (windowRecordId == null) {
            throw new AuraHandledException('Window is required.');
        }
        if (!Schema.sObjectType.Ken_Windows__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update residence windows.');
        }

        update new Ken_Windows__c(
            Id = windowRecordId,
            Auto_Allotment_Allocation_Rule__c = normalizeAutoAllotmentRule(allocationRule),
            Auto_Allotment_Batch_Processing__c = batchProcessing == true,
            Auto_Allotment_Batch_Size__c = normalizeAutoAllotmentBatchSize(batchSize),
            Auto_Allotment_Batch_Grouping__c = normalizeAutoAllotmentBatchGrouping(batchGrouping),
            Auto_Allotment_Carry_Forward__c = previousYearCarryForward == true
        );
    }

    @AuraEnabled
    public static List<InProgressRow> getInProgressRows(String windowId) {
        Id windowRecordId = normalizeId(windowId, 'Invalid window.');
        if (windowRecordId == null) {
            return new List<InProgressRow>();
        }
        if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view residence windows.');
        }
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room allotments.');
        }

        WindowScope scope = getWindowScope(windowRecordId);
        Ken_Windows__c windowRecord = [
            SELECT Id, Allotment_Type__c, Enable_Room_Preference__c, Hostel_Cycle__c
            FROM Ken_Windows__c
            WHERE Id = :windowRecordId
            LIMIT 1
        ];
        WindowAcademicYearScope academicYearScope = getWindowAcademicYearScope(windowRecord.Hostel_Cycle__c);

        String windowAllotmentType = normalizeAllotmentTypeDisplay(windowRecord.Allotment_Type__c);
        String inProgressAllotmentType = isPreferenceFlowWindow(windowRecord)
            ? 'Preference Selected'
            : windowAllotmentType;

        if (inProgressAllotmentType == 'Preference Selected') {
            return getPreferenceSelectedInProgressRows(
                windowRecordId,
                scope,
                academicYearScope,
                inProgressAllotmentType
            );
        }

        List<Ken_Room_Allotment__c> allotments = [
            SELECT
                Id,
                Tenant_Account__c,
                Tenant_Account__r.Name,
                Tenant_Account__r.IsPersonAccount,
                Tenant_Account__r.Roll_No__c,
                Tenant__c,
                Tenant__r.Name,
                Tenant__r.Email,
                Allotment_Type__c,
                Active__c,
                Start_Date__c,
                CreatedDate,
                Room__c,
                Room__r.Building__c,
                Room__r.Room_Category__c,
                Room__r.Room_Category__r.Name,
                Room__r.Room_Category__r.Name__c,
                Room__r.Housing_Category__c
            FROM Ken_Room_Allotment__c
            WHERE Active__c = false
                AND (Tenant_Account__c != null OR Tenant__c != null)
                AND Room__c != null
                AND (Allotment_Type__c = null OR Allotment_Type__c != 'Stay Completed')
            ORDER BY Start_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 2000
        ];

        Set<Id> studentAccountIds = new Set<Id>();
        Set<Id> studentContactIds = new Set<Id>();
        for (Ken_Room_Allotment__c allotment : allotments) {
            if (allotment.Tenant_Account__c != null) {
                studentAccountIds.add(allotment.Tenant_Account__c);
            }
            if (allotment.Tenant__c != null) {
                studentContactIds.add(allotment.Tenant__c);
            }
        }
        Map<Id, LearnerProgram> learnerProgramByAccountId = getRelevantLearnerPrograms(studentAccountIds, scope);
        Map<Id, LearnerProgram> learnerProgramByContactId = getRelevantLearnerProgramsByContact(studentContactIds, scope);
        Map<Id, LearnerAcademicYearInfo> academicYearInfoByAccountId =
            getRelevantAcademicYearsByAccountId(studentAccountIds, academicYearScope);
        Map<Id, LearnerAcademicYearInfo> academicYearInfoByContactId =
            getRelevantAcademicYearsByContactId(studentContactIds, academicYearScope);
        Boolean hasProgramScope = hasWindowProgramScope(scope);

        List<InProgressRow> response = new List<InProgressRow>();
        Set<String> addedStudentKeys = new Set<String>();
        for (Ken_Room_Allotment__c allotment : allotments) {
            String studentKey = buildStudentKey(allotment.Tenant_Account__c, allotment.Tenant__c);
            if (String.isBlank(studentKey) || addedStudentKeys.contains(studentKey)) {
                continue;
            }

            if (!scope.buildingIds.isEmpty() && (allotment.Room__r == null || !scope.buildingIds.contains(allotment.Room__r.Building__c))) {
                continue;
            }

            if (!scope.roomCategoryIds.isEmpty() && (allotment.Room__r == null || !scope.roomCategoryIds.contains(allotment.Room__r.Room_Category__c))) {
                continue;
            }

            LearnerProgram learnerProgram = allotment.Tenant_Account__c != null
                ? learnerProgramByAccountId.get(allotment.Tenant_Account__c)
                : learnerProgramByContactId.get(allotment.Tenant__c);
            LearnerAcademicYearInfo learnerAcademicYearInfo = allotment.Tenant_Account__c != null
                ? academicYearInfoByAccountId.get(allotment.Tenant_Account__c)
                : academicYearInfoByContactId.get(allotment.Tenant__c);
            if (hasProgramScope && learnerProgram == null) {
                continue;
            }

            InProgressRow row = new InProgressRow();
            row.id = String.valueOf(allotment.Id);
            row.accountId = allotment.Tenant_Account__c != null ? String.valueOf(allotment.Tenant_Account__c) : '';
            row.student = getAllotmentStudentName(allotment);
            row.rollNo = getAllotmentStudentRollNo(allotment);
            row.program = resolveLearnerProgramLabel(learnerProgram);
            row.programPlanId = learnerProgram != null ? String.valueOf(learnerProgram.LearningProgramPlanId) : '';
            row.year = deriveLearnerYearLabel(learnerProgram);
            row.academicYear = learnerAcademicYearInfo != null ? sanitize(learnerAcademicYearInfo.academicYearLabel) : '';
            row.yearPriorityRank = learnerAcademicYearInfo != null && learnerAcademicYearInfo.priorityRank != null
                ? learnerAcademicYearInfo.priorityRank
                : deriveLearnerYearPriorityRank(learnerProgram);
            row.category = resolveAllotmentRoomCategoryLabel(allotment);
            row.payment = '';
            row.allotmentType = firstNonBlank(new List<String>{
                normalizeAllotmentTypeDisplay(allotment.Allotment_Type__c),
                normalizeInProgressAllotmentType(windowAllotmentType, null)
            });
            row.status = '';
            response.add(row);
            addedStudentKeys.add(studentKey);
        }

        return response;
    }

    private static Boolean isPreferenceFlowWindow(Ken_Windows__c windowRecord) {
        if (windowRecord == null) {
            return false;
        }
        // Driven only by allotment type: Provisional or Preference Selected show request-driven in-progress.
        // Not based on Enable Room Preference.
        String typeValue = normalizeAllotmentTypeDisplay(windowRecord.Allotment_Type__c);
        return typeValue == 'Preference Selected' || typeValue == 'Provisional Allotment';
    }

    @AuraEnabled
    public static List<AllocatedRow> getAllocatedRows(String windowId) {
        Id windowRecordId = normalizeId(windowId, 'Invalid window.');
        if (windowRecordId == null) {
            return new List<AllocatedRow>();
        }
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room allotments.');
        }

        WindowScope scope = getWindowScope(windowRecordId);
        List<Ken_Room_Allotment__c> allotments = [
            SELECT
                Id,
                Tenant_Account__c,
                Tenant_Account__r.Name,
                Tenant_Account__r.IsPersonAccount,
                Tenant_Account__r.Roll_No__c,
                Tenant__c,
                Tenant__r.Name,
                Tenant__r.Email,
                Allotment_Type__c,
                Payment_Status__c,
                Active__c,
                Room__c,
                Room__r.Name,
                Room__r.Room_Number__c,
                Room__r.Building__c,
                Room__r.Building__r.Name,
                Room__r.Room_Category__c,
                Room__r.Room_Category__r.Name,
                Room__r.Room_Category__r.Name__c,
                Room__r.Housing_Category__c,
                Start_Date__c,
                CreatedDate
            FROM Ken_Room_Allotment__c
            WHERE Active__c = true
                AND (Tenant_Account__c != null OR Tenant__c != null)
                AND Room__c != null
            ORDER BY Start_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 2000
        ];

        Set<Id> studentAccountIds = new Set<Id>();
        Set<Id> studentContactIds = new Set<Id>();
        for (Ken_Room_Allotment__c allotment : allotments) {
            if (allotment.Tenant_Account__c != null) {
                studentAccountIds.add(allotment.Tenant_Account__c);
            }
            if (allotment.Tenant__c != null) {
                studentContactIds.add(allotment.Tenant__c);
            }
        }
        Map<Id, LearnerProgram> learnerProgramByAccountId = getRelevantLearnerPrograms(studentAccountIds, scope);
        Map<Id, LearnerProgram> learnerProgramByContactId = getRelevantLearnerProgramsByContact(studentContactIds, scope);
        Boolean hasProgramScope = hasWindowProgramScope(scope);

        List<AllocatedRow> response = new List<AllocatedRow>();
        for (Ken_Room_Allotment__c allotment : allotments) {
            if (allotment.Tenant_Account__c == null && allotment.Tenant__c == null) {
                continue;
            }

            if (!scope.buildingIds.isEmpty() && (allotment.Room__r == null || !scope.buildingIds.contains(allotment.Room__r.Building__c))) {
                continue;
            }

            if (!scope.roomCategoryIds.isEmpty() && (allotment.Room__r == null || !scope.roomCategoryIds.contains(allotment.Room__r.Room_Category__c))) {
                continue;
            }

            LearnerProgram learnerProgram = allotment.Tenant_Account__c != null
                ? learnerProgramByAccountId.get(allotment.Tenant_Account__c)
                : learnerProgramByContactId.get(allotment.Tenant__c);
            if (hasProgramScope && learnerProgram == null) {
                continue;
            }

            AllocatedRow row = new AllocatedRow();
            row.id = String.valueOf(allotment.Id);
            row.accountId = allotment.Tenant_Account__c != null ? String.valueOf(allotment.Tenant_Account__c) : '';
            row.student = getAllotmentStudentName(allotment);
            row.rollNo = getAllotmentStudentRollNo(allotment);
            row.program = resolveLearnerProgramLabel(learnerProgram);
            row.programPlanId = learnerProgram != null ? String.valueOf(learnerProgram.LearningProgramPlanId) : '';
            row.year = deriveLearnerYearLabel(learnerProgram);
            row.room = firstNonBlank(new List<String>{
                allotment.Room__r != null ? allotment.Room__r.Name : null,
                allotment.Room__r != null ? allotment.Room__r.Room_Number__c : null
            });
            row.building = allotment.Room__r != null && allotment.Room__r.Building__r != null
                ? sanitize(allotment.Room__r.Building__r.Name)
                : '';
            row.category = resolveAllotmentRoomCategoryLabel(allotment);
            row.allotmentType = normalizeAllotmentTypeDisplay(allotment.Allotment_Type__c);
            row.source = '';
            row.payment = sanitize(allotment.Payment_Status__c);
            row.assignedOn = '';
            response.add(row);
        }

        return response;
    }

    @AuraEnabled
    public static ApplicationDetailResponse getInProgressApplicationDetail(String allotmentId, String windowId) {
        Id allotmentRecordId = normalizeId(allotmentId, 'Invalid application.');
        Id windowRecordId = normalizeId(windowId, 'Invalid window.');
        if (allotmentRecordId == null) {
            throw new AuraHandledException('Application is required.');
        }
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room allotments.');
        }

        if (isRoomRequestId(allotmentRecordId)) {
            return buildInProgressApplicationDetailFromRequest(allotmentRecordId, windowRecordId);
        }

        ApplicationDetailResponse response = new ApplicationDetailResponse();
        Ken_Room_Allotment__c allotment = [
            SELECT
                Id,
                Tenant_Account__c,
                Tenant_Account__r.Name,
                Tenant_Account__r.Roll_No__c,
                Tenant_Account__r.PersonEmail,
                Tenant_Account__r.PersonMobilePhone,
                Tenant_Account__r.PersonContactId,
                Tenant__c,
                Tenant__r.Name,
                Tenant__r.Email,
                Tenant__r.MobilePhone,
                Tenant__r.Phone,
                Allotment_Type__c,
                Payment_Status__c,
                Window__c,
                Room__c,
                Room__r.Housing_Category__c,
                Room__r.Room_Category__c,
                Room__r.Room_Category__r.Name,
                Room__r.Room_Category__r.Name__c,
                CreatedDate
            FROM Ken_Room_Allotment__c
            WHERE Id = :allotmentRecordId
            LIMIT 1
        ];

        response.allotmentId = String.valueOf(allotment.Id);
        response.studentName = getAllotmentStudentName(allotment);
        response.rollNo = getAllotmentStudentRollNo(allotment);
        response.email = getAllotmentStudentEmail(allotment);
        response.phone = getAllotmentStudentPhone(allotment);
        response.allotmentType = normalizeAllotmentTypeDisplay(allotment.Allotment_Type__c);
        response.categoryApplied = resolveAllotmentRoomCategoryLabel(allotment);
        response.paymentStatus = sanitize(allotment.Payment_Status__c);

        WindowScope scope = getWindowScope(windowRecordId);
        LearnerProgram learnerProgram = resolveAllotmentLearnerProgram(allotment, scope);
        response.program = resolveLearnerProgramLabel(learnerProgram);
        response.year = deriveLearnerYearLabel(learnerProgram);

        Ken_Room_Request__c roomRequest = getLatestRoomRequestForDetail(
            allotment.Tenant_Account__c,
            getAllotmentContactId(allotment),
            allotment.Window__c,
            allotment.Id
        );

        if (roomRequest != null) {
            response.applicationStatus = sanitize(roomRequest.Status__c);
            response.appliedOn = formatDateTimeToDate(roomRequest.CreatedDate);
            response.roommatePreference = buildRoommatePreference(roomRequest, allotment.Tenant_Account__c);
        }

        response.roomPreferences = buildRoomPreferences(
            roomRequest,
            windowRecordId,
            allotment.Room__r != null ? allotment.Room__r.Room_Category__c : null
        );

        return response;
    }

    @AuraEnabled
    public static AllocationDetailResponse getAllocatedDetail(String allotmentId, String windowId) {
        Id allotmentRecordId = normalizeId(allotmentId, 'Invalid allocation.');
        Id windowRecordId = normalizeId(windowId, 'Invalid window.');
        if (allotmentRecordId == null) {
            throw new AuraHandledException('Allocation is required.');
        }
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room allotments.');
        }

        AllocationDetailResponse response = new AllocationDetailResponse();
        Ken_Room_Allotment__c allotment = [
            SELECT
                Id,
                Tenant_Account__c,
                Tenant_Account__r.Name,
                Tenant_Account__r.Roll_No__c,
                Tenant_Account__r.PersonEmail,
                Tenant_Account__r.PersonMobilePhone,
                Tenant__c,
                Tenant__r.Name,
                Tenant__r.Email,
                Tenant__r.MobilePhone,
                Tenant__r.Phone,
                Allotment_Type__c,
                Payment_Status__c,
                Room__c,
                Room__r.Name,
                Room__r.Room_Number__c,
                Room__r.Housing_Category__c,
                Room__r.Room_Category__r.Name,
                Room__r.Room_Category__r.Name__c,
                Room__r.Building__r.Name,
                Start_Date__c
            FROM Ken_Room_Allotment__c
            WHERE Id = :allotmentRecordId
            LIMIT 1
        ];

        response.allotmentId = String.valueOf(allotment.Id);
        response.studentName = getAllotmentStudentName(allotment);
        response.rollNo = getAllotmentStudentRollNo(allotment);
        response.email = getAllotmentStudentEmail(allotment);
        response.phone = getAllotmentStudentPhone(allotment);
        response.roomNumber = firstNonBlank(new List<String>{
            allotment.Room__r != null ? allotment.Room__r.Name : null,
            allotment.Room__r != null ? allotment.Room__r.Room_Number__c : null
        });
        response.building = allotment.Room__r != null && allotment.Room__r.Building__r != null
            ? sanitize(allotment.Room__r.Building__r.Name)
            : '';
        response.category = resolveAllotmentRoomCategoryLabel(allotment);
        response.allotmentType = normalizeAllotmentTypeDisplay(allotment.Allotment_Type__c);
        response.paymentStatus = sanitize(allotment.Payment_Status__c);
        response.assignmentSource = '';
        response.assignedOn = '';

        WindowScope scope = getWindowScope(windowRecordId);
        LearnerProgram learnerProgram = resolveAllotmentLearnerProgram(allotment, scope);
        response.program = resolveLearnerProgramLabel(learnerProgram);
        response.year = deriveLearnerYearLabel(learnerProgram);

        return response;
    }

    @AuraEnabled
    public static List<RoomAssignmentOption> getAssignableRooms(String allotmentId, String windowId) {
        Id allotmentRecordId = normalizeId(allotmentId, 'Invalid application.');
        Id windowRecordId = normalizeId(windowId, 'Invalid window.');
        if (allotmentRecordId == null || windowRecordId == null) {
            return new List<RoomAssignmentOption>();
        }
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room allotments.');
        }

        Ken_Windows__c windowRecord = queryWindowSchedule(windowRecordId);

        if (isRoomRequestId(allotmentRecordId)) {
            Ken_Room_Request__c roomRequest = queryRoomRequestById(allotmentRecordId);
            Id currentRoomId = null;
            Ken_Room_Allotment__c linkedAllotment;
            if (roomRequest.Room_Allotment__c != null) {
                List<Ken_Room_Allotment__c> linkedAllotments = [
                    SELECT Id, Room__c, Start_Date__c
                    FROM Ken_Room_Allotment__c
                    WHERE Id = :roomRequest.Room_Allotment__c
                    LIMIT 1
                ];
                linkedAllotment = linkedAllotments.isEmpty() ? null : linkedAllotments[0];
                currentRoomId = linkedAllotment != null ? linkedAllotment.Room__c : null;
            }

            Id previousRoomId = resolveCarryForwardRoomId(
                roomRequest.Request_By__c,
                roomRequest.Requested_By__c,
                windowRecord,
                resolveCarryForwardReferenceDate(windowRecord, linkedAllotment, roomRequest.CreatedDate != null ? roomRequest.CreatedDate.date() : null),
                linkedAllotment != null ? linkedAllotment.Id : null
            );
            return buildAssignableRooms(windowRecordId, currentRoomId, previousRoomId, roomRequest, roomRequest.Request_By__c);
        }

        Ken_Room_Allotment__c allotment = [
            SELECT
                Id,
                Room__c,
                Start_Date__c,
                Tenant_Account__c,
                Tenant_Account__r.PersonContactId,
                Tenant__c,
                Window__c
            FROM Ken_Room_Allotment__c
            WHERE Id = :allotmentRecordId
            LIMIT 1
        ];

        Ken_Room_Request__c roomRequest = getLatestRoomRequestForDetail(
            allotment.Tenant_Account__c,
            getAllotmentContactId(allotment),
            allotment.Window__c,
            allotment.Id
        );
        Id previousRoomId = resolveCarryForwardRoomId(
            allotment.Tenant_Account__c,
            getAllotmentContactId(allotment),
            windowRecord,
            resolveCarryForwardReferenceDate(windowRecord, allotment, allotment.Start_Date__c),
            allotment.Id
        );
        return buildAssignableRooms(windowRecordId, allotment.Room__c, previousRoomId, roomRequest, allotment.Tenant_Account__c);
    }

    @AuraEnabled
    public static String assignRoomToAllotment(String allotmentId, String roomId, String windowId, String allotmentType) {
        Id allotmentRecordId = normalizeId(allotmentId, 'Invalid application.');
        Id roomRecordId = normalizeId(roomId, 'Invalid room.');
        Id windowRecordId = normalizeId(windowId, 'Invalid window.');
        String assignmentAllotmentType = normalizeAssignmentAllotmentType(allotmentType);
        if (allotmentRecordId == null) {
            throw new AuraHandledException('Application is required.');
        }
        if (roomRecordId == null) {
            throw new AuraHandledException('Room is required.');
        }
        if (windowRecordId == null) {
            throw new AuraHandledException('Window is required.');
        }

        if (isRoomRequestId(allotmentRecordId)) {
            return assignRoomToRequest(allotmentRecordId, roomRecordId, windowRecordId, assignmentAllotmentType);
        }

        return assignRoomToExistingAllotment(allotmentRecordId, roomRecordId, windowRecordId, assignmentAllotmentType);
    }

    private static String assignRoomToExistingAllotment(
        Id allotmentRecordId,
        Id roomRecordId,
        Id windowRecordId,
        String assignmentAllotmentType
    ) {
        if (allotmentRecordId == null) {
            throw new AuraHandledException('Application is required.');
        }
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room allotments.');
        }
        if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view residence windows.');
        }
        if (!Schema.sObjectType.Ken_Room__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view rooms.');
        }
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update room allotments.');
        }

        Ken_Room_Allotment__c allotment = [
            SELECT Id, Active__c, Allotment_Type__c, Room__c, Start_Date__c, End_Date__c,
                   Tenant_Account__c, Tenant__c, Window__c, Payment_Status__c
            FROM Ken_Room_Allotment__c
            WHERE Id = :allotmentRecordId
            LIMIT 1
            FOR UPDATE
        ];

        if (allotment.Active__c != true) {
            // Allow reactivation of cancelled allocations from the in-progress queue.
        }
        if (sanitize(allotment.Allotment_Type__c).equalsIgnoreCase('Stay Completed')) {
            throw new AuraHandledException('Completed allotments cannot be reassigned.');
        }
        if (allotment.Room__c == roomRecordId && allotment.Active__c == true) {
            return String.valueOf(allotment.Id);
        }

        Ken_Windows__c windowRecord = [
            SELECT Id, Start_Date__c, End_Date__c, Room_Allotment_Start_Date__c, Room_Allotment_End_Date__c
            FROM Ken_Windows__c
            WHERE Id = :windowRecordId
            LIMIT 1
        ];

        WindowScope scope = getWindowScope(windowRecordId);
        Ken_Room__c room = [
            SELECT Id, Building__c, Room_Category__c, Capacity__c, Occupancy_Status__c
            FROM Ken_Room__c
            WHERE Id = :roomRecordId
            LIMIT 1
            FOR UPDATE
        ];

        if (!scope.buildingIds.isEmpty() && !scope.buildingIds.contains(room.Building__c)) {
            throw new AuraHandledException('Selected room is not eligible for this window.');
        }
        if (!scope.roomCategoryIds.isEmpty() && !scope.roomCategoryIds.contains(room.Room_Category__c)) {
            throw new AuraHandledException('Selected room category is not eligible for this window.');
        }

        Integer capacity = room.Capacity__c == null ? 0 : Integer.valueOf(room.Capacity__c);
        Integer occupancy = room.Occupancy_Status__c == null ? 0 : Integer.valueOf(room.Occupancy_Status__c);
        if (capacity <= 0) {
            throw new AuraHandledException('Selected room has no capacity configured.');
        }
        if (occupancy >= capacity) {
            throw new AuraHandledException('Selected room is already full.');
        }

        Date roomAllotmentStartDate = resolveWindowAllotmentStartDate(windowRecord, allotment);
        Date roomAllotmentEndDate = resolveWindowAllotmentEndDate(windowRecord, allotment);
        if (roomAllotmentStartDate != null && roomAllotmentEndDate != null && roomAllotmentStartDate > roomAllotmentEndDate) {
            throw new AuraHandledException('Room allotment end date must be after start date.');
        }

        Ken_Room_Allotment__c newAllotment = new Ken_Room_Allotment__c(
            Room__c = room.Id,
            Tenant_Account__c = allotment.Tenant_Account__c,
            Tenant__c = allotment.Tenant__c,
            Window__c = windowRecordId,
            Active__c = true,
            Allotment_Type__c = assignmentAllotmentType,
            Payment_Status__c = allotment.Payment_Status__c,
            Start_Date__c = roomAllotmentStartDate,
            End_Date__c = roomAllotmentEndDate
        );
        markAsReassigned(newAllotment);
        insert newAllotment;

        Ken_Room_Allotment__c priorAllotmentUpdate = new Ken_Room_Allotment__c(
            Id = allotment.Id,
            Active__c = false,
            End_Date__c = resolveReassignmentEndDate(allotment, roomAllotmentStartDate)
        );
        markAsReassigned(priorAllotmentUpdate);
        update priorAllotmentUpdate;

        relinkLinkedRoomRequests(allotment.Id, newAllotment.Id, assignmentAllotmentType);
        return String.valueOf(newAllotment.Id);
    }

    private static void markAsReassigned(Ken_Room_Allotment__c allotment) {
        if (allotment == null) {
            return;
        }
        if (Schema.sObjectType.Ken_Room_Allotment__c.fields.getMap().containsKey(REALLOTMENT_FLAG_FIELD)) {
            allotment.put(REALLOTMENT_FLAG_FIELD, true);
        }
    }

    private static String assignRoomToRequest(
        Id roomRequestId,
        Id roomRecordId,
        Id windowRecordId,
        String assignmentAllotmentType
    ) {
        if (!Schema.sObjectType.Ken_Room_Request__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room requests.');
        }
        if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view residence windows.');
        }
        if (!Schema.sObjectType.Ken_Room__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view rooms.');
        }
        if (!Schema.sObjectType.Ken_Room_Request__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update room requests.');
        }
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create room allotments.');
        }

        Ken_Room_Request__c roomRequest = [
            SELECT Id, Request_By__c, Requested_By__c, Window__c, Room_Allotment__c
            FROM Ken_Room_Request__c
            WHERE Id = :roomRequestId
            LIMIT 1
            FOR UPDATE
        ];

        if (roomRequest.Room_Allotment__c != null) {
            String existingAllotmentId = assignRoomToExistingAllotment(
                roomRequest.Room_Allotment__c,
                roomRecordId,
                windowRecordId,
                assignmentAllotmentType
            );
            update new Ken_Room_Request__c(
                Id = roomRequest.Id,
                Status__c = deriveAssignedRequestStatus(assignmentAllotmentType)
            );
            return existingAllotmentId;
        }

        Ken_Windows__c windowRecord = [
            SELECT Id, Start_Date__c, End_Date__c, Room_Allotment_Start_Date__c, Room_Allotment_End_Date__c
            FROM Ken_Windows__c
            WHERE Id = :windowRecordId
            LIMIT 1
        ];

        WindowScope scope = getWindowScope(windowRecordId);
        Ken_Room__c room = [
            SELECT Id, Building__c, Room_Category__c, Housing_Category__c, Capacity__c, Occupancy_Status__c
            FROM Ken_Room__c
            WHERE Id = :roomRecordId
            LIMIT 1
            FOR UPDATE
        ];

        if (!scope.buildingIds.isEmpty() && !scope.buildingIds.contains(room.Building__c)) {
            throw new AuraHandledException('Selected room is not eligible for this window.');
        }
        if (!scope.roomCategoryIds.isEmpty() && !scope.roomCategoryIds.contains(room.Room_Category__c)) {
            throw new AuraHandledException('Selected room category is not eligible for this window.');
        }

        Integer capacity = room.Capacity__c == null ? 0 : Integer.valueOf(room.Capacity__c);
        Integer occupancy = room.Occupancy_Status__c == null ? 0 : Integer.valueOf(room.Occupancy_Status__c);
        if (capacity <= 0) {
            throw new AuraHandledException('Selected room has no capacity configured.');
        }
        if (occupancy >= capacity) {
            throw new AuraHandledException('Selected room is already full.');
        }

        Date roomAllotmentStartDate = resolveWindowAllotmentStartDate(windowRecord, null);
        Date roomAllotmentEndDate = resolveWindowAllotmentEndDate(windowRecord, null);
        if (roomAllotmentStartDate != null && roomAllotmentEndDate != null && roomAllotmentStartDate > roomAllotmentEndDate) {
            throw new AuraHandledException('Room allotment end date must be after start date.');
        }

        Ken_Room_Allotment__c newAllotment = new Ken_Room_Allotment__c(
            Room__c = room.Id,
            Tenant_Account__c = roomRequest.Request_By__c,
            Tenant__c = roomRequest.Requested_By__c,
            Window__c = roomRequest.Window__c != null ? roomRequest.Window__c : windowRecordId,
            Active__c = true,
            Allotment_Type__c = assignmentAllotmentType,
            Start_Date__c = roomAllotmentStartDate,
            End_Date__c = roomAllotmentEndDate
        );
        insert newAllotment;

        update new Ken_Room_Request__c(
            Id = roomRequest.Id,
            Window__c = roomRequest.Window__c != null ? roomRequest.Window__c : windowRecordId,
            Room_Allotment__c = newAllotment.Id,
            Status__c = deriveAssignedRequestStatus(assignmentAllotmentType)
        );

        return String.valueOf(newAllotment.Id);
    }

    @AuraEnabled
    public static void cancelAllocation(String allotmentId, String windowId) {
        Id allotmentRecordId = normalizeId(allotmentId, 'Invalid allocation.');
        Id windowRecordId = normalizeId(windowId, 'Invalid window.');
        if (allotmentRecordId == null) {
            throw new AuraHandledException('Allocation is required.');
        }
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room allotments.');
        }
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update room allotments.');
        }

        String windowAllotmentType = getWindowAllotmentType(windowRecordId);
        Ken_Room_Allotment__c allotment = [
            SELECT Id, Active__c, End_Date__c, Allotment_Type__c
            FROM Ken_Room_Allotment__c
            WHERE Id = :allotmentRecordId
            LIMIT 1
            FOR UPDATE
        ];

        if (allotment.Active__c != true) {
            return;
        }

        update new Ken_Room_Allotment__c(
            Id = allotment.Id,
            Active__c = false,
            Allotment_Type__c = sanitize(allotment.Allotment_Type__c).equalsIgnoreCase('Stay Completed')
                ? allotment.Allotment_Type__c
                : normalizeInProgressAllotmentType(windowAllotmentType, allotment.Allotment_Type__c),
            End_Date__c = Date.today()
        );
        reopenLinkedRoomRequests(allotment.Id);
    }

    @AuraEnabled
    public static void checkoutAllocation(String allotmentId, String windowId) {
        Id allotmentRecordId = normalizeId(allotmentId, 'Invalid allocation.');
        normalizeId(windowId, 'Invalid window.');
        if (allotmentRecordId == null) {
            throw new AuraHandledException('Allocation is required.');
        }
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room allotments.');
        }
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update room allotments.');
        }

        Ken_Room_Allotment__c allotment = [
            SELECT Id, Active__c, Allotment_Type__c
            FROM Ken_Room_Allotment__c
            WHERE Id = :allotmentRecordId
            LIMIT 1
            FOR UPDATE
        ];

        if (allotment.Active__c != true && sanitize(allotment.Allotment_Type__c).equalsIgnoreCase('Stay Completed')) {
            return;
        }

        update new Ken_Room_Allotment__c(
            Id = allotment.Id,
            Active__c = false,
            Allotment_Type__c = 'Stay Completed',
            End_Date__c = Date.today()
        );
        completeLinkedRoomRequests(allotment.Id);
    }

    @AuraEnabled
    public static void rejectApplication(String applicationId, String rejectionReason) {
        Id applicationRecordId = normalizeId(applicationId, 'Invalid application.');
        if (applicationRecordId == null) {
            throw new AuraHandledException('Application is required.');
        }
        String normalizedRejectionReason = sanitize(rejectionReason);
        if (String.isBlank(normalizedRejectionReason)) {
            throw new AuraHandledException('Rejection reason is required.');
        }
        if (!Schema.sObjectType.Ken_Room_Request__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room requests.');
        }
        if (!Schema.sObjectType.Ken_Room_Request__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update room requests.');
        }
        if (
            !Schema.sObjectType.Ken_Room_Request__c.fields.Status__c.isUpdateable() ||
            !Schema.sObjectType.Ken_Room_Request__c.fields.Rejected_Reason__c.isUpdateable()
        ) {
            throw new AuraHandledException('You do not have permission to update rejection details.');
        }

        if (isRoomRequestId(applicationRecordId)) {
            update buildRejectedRoomRequestUpdate(applicationRecordId, normalizedRejectionReason);
            return;
        }

        List<Ken_Room_Request__c> linkedRequests = new List<Ken_Room_Request__c>();
        for (Ken_Room_Request__c requestRow : [
            SELECT Id
            FROM Ken_Room_Request__c
            WHERE Room_Allotment__c = :applicationRecordId
        ]) {
            linkedRequests.add(buildRejectedRoomRequestUpdate(requestRow.Id, normalizedRejectionReason));
        }

        if (!linkedRequests.isEmpty()) {
            update linkedRequests;
        }
    }

    private static Ken_Room_Request__c buildRejectedRoomRequestUpdate(Id requestId, String rejectionReason) {
        return new Ken_Room_Request__c(
            Id = requestId,
            Room_Allotment__c = null,
            Status__c = 'Rejected',
            Rejected_Reason__c = rejectionReason
        );
    }

    private static String buildCycleLabel(String nameValue, String statusValue) {
        String cycleName = sanitize(nameValue);
        String status = sanitize(statusValue);
        if (String.isBlank(status)) {
            return cycleName;
        }
        return cycleName + ' (' + status + ')';
    }

    private static String buildWindowLabel(String nameValue, String allotmentTypeValue, String statusValue) {
        String nameText = sanitize(nameValue);
        String allotmentType = sanitize(allotmentTypeValue);
        String status = sanitize(statusValue);

        List<String> parts = new List<String>();
        if (String.isNotBlank(allotmentType)) {
            parts.add(allotmentType);
        }
        if (String.isNotBlank(status)) {
            parts.add(status);
        }

        if (parts.isEmpty()) {
            return nameText;
        }
        return nameText + ' (' + String.join(parts, ' - ') + ')';
    }

    private static String resolveWindowStatus(Date startDate, Date endDate) {
        Date today = System.today();
        if (startDate != null && today < startDate) {
            return 'Upcoming';
        }
        if (endDate != null && today > endDate) {
            return 'Closed';
        }
        if (startDate != null || endDate != null) {
            return 'Open';
        }
        return '';
    }

    private static WindowScope getWindowScope(Id windowId) {
        WindowScope scope = new WindowScope();
        if (windowId == null) {
            return scope;
        }
        if (!Schema.sObjectType.Ken_Window_Learning_Program_Plan__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view window learning program plans.');
        }
        if (!Schema.sObjectType.Ken_Window_Program_Pathway__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view window program pathways.');
        }
        if (!Schema.sObjectType.Ken_Window_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view window buildings.');
        }
        if (!Schema.sObjectType.Ken_Window_Room_Category__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view window room categories.');
        }

        for (Ken_Window_Learning_Program_Plan__c row : [
            SELECT Learning_Program_Plan__c
            FROM Ken_Window_Learning_Program_Plan__c
            WHERE Window__c = :windowId
        ]) {
            if (row.Learning_Program_Plan__c != null) {
                scope.learningProgramPlanIds.add(row.Learning_Program_Plan__c);
            }
        }

        for (Ken_Window_Program_Pathway__c row : [
            SELECT Program_Pathway__c
            FROM Ken_Window_Program_Pathway__c
            WHERE Window__c = :windowId
        ]) {
            if (row.Program_Pathway__c != null) {
                scope.learningProgramIds.add(row.Program_Pathway__c);
            }
        }

        for (Ken_Window_Building__c row : [
            SELECT Building__c
            FROM Ken_Window_Building__c
            WHERE Windows__c = :windowId
        ]) {
            if (row.Building__c != null) {
                scope.buildingIds.add(row.Building__c);
            }
        }

        for (Ken_Window_Room_Category__c row : [
            SELECT Room_Category__c
            FROM Ken_Window_Room_Category__c
            WHERE Windows__c = :windowId
        ]) {
            if (row.Room_Category__c != null) {
                scope.roomCategoryIds.add(row.Room_Category__c);
            }
        }

        return scope;
    }

    private static List<InProgressRow> getPreferenceSelectedInProgressRows(
        Id windowId,
        WindowScope scope,
        WindowAcademicYearScope academicYearScope,
        String windowAllotmentType
    ) {
        if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view residence windows.');
        }
        if (!Schema.sObjectType.Ken_Room_Request__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room requests.');
        }

        Ken_Windows__c windowRecord = [
            SELECT Id, Start_Date__c, End_Date__c
            FROM Ken_Windows__c
            WHERE Id = :windowId
            LIMIT 1
        ];

        List<Ken_Room_Request__c> requests = [
            SELECT
                Id,
                Name,
                Request_By__c,
                Request_By__r.Name,
                Request_By__r.IsPersonAccount,
                Request_By__r.Roll_No__c,
                Request_By__r.PersonEmail,
                Request_By__r.PersonMobilePhone,
                Request_By__r.PersonContactId,
                Requested_By__c,
                Requested_By__r.Name,
                Requested_By__r.Email,
                Requested_By__r.MobilePhone,
                Requested_By__r.Phone,
                Room_Allotment__c,
                Window__c,
                Status__c,
                Preferred_Partner__c,
                Preferred_Partner__r.Name,
                Preferred_Partner__r.PersonEmail,
                Preferred_Partner__r.Roll_No__c,
                Preferred_Partner__r.PersonContactId,
                Preference_1__c,
                Preference_1_Category__c,
                Preference_1__r.Name,
                Preference_1__r.Name__c,
                Preference_1__r.Capacity__c,
                Preference_2__c,
                Preference_2_Category__c,
                Preference_2__r.Name,
                Preference_2__r.Name__c,
                Preference_2__r.Capacity__c,
                Preference_3__c,
                Preference_3_Category__c,
                Preference_3__r.Name,
                Preference_3__r.Name__c,
                Preference_3__r.Capacity__c,
                CreatedDate
            FROM Ken_Room_Request__c
            WHERE (Request_By__c != null OR Requested_By__c != null)
                AND (Window__c = :windowId OR Window__c = null)
                AND (Room_Allotment__c = null OR Room_Allotment__r.Active__c = false)
                AND (Status__c = null OR (
                    Status__c != 'Canceled'
                    AND Status__c != 'Rejected'
                    AND Status__c != 'Completed'
                    AND Status__c != 'Alloted'
                    AND Status__c != 'Stay Completed'
                ))
            ORDER BY CreatedDate DESC
            LIMIT 2000
        ];

        Set<Id> requestAccountIds = new Set<Id>();
        Set<Id> requestContactIds = new Set<Id>();
        for (Ken_Room_Request__c requestRow : requests) {
            if (requestRow.Request_By__c != null) {
                requestAccountIds.add(requestRow.Request_By__c);
            }
            if (requestRow.Requested_By__c != null) {
                requestContactIds.add(requestRow.Requested_By__c);
            }
        }
        Map<Id, LearnerProgram> learnerProgramByAccountId = getRelevantLearnerPrograms(requestAccountIds, scope);
        Map<Id, LearnerProgram> learnerProgramByContactId = getRelevantLearnerProgramsByContact(requestContactIds, scope);
        Map<Id, LearnerAcademicYearInfo> academicYearInfoByAccountId =
            getRelevantAcademicYearsByAccountId(requestAccountIds, academicYearScope);
        Map<Id, LearnerAcademicYearInfo> academicYearInfoByContactId =
            getRelevantAcademicYearsByContactId(requestContactIds, academicYearScope);
        Boolean hasProgramScope = hasWindowProgramScope(scope);

        List<InProgressRow> response = new List<InProgressRow>();
        Set<String> addedStudentKeys = new Set<String>();
        for (Ken_Room_Request__c requestRow : requests) {
            String studentKey = buildStudentKey(requestRow.Request_By__c, requestRow.Requested_By__c);
            if (String.isBlank(studentKey) || addedStudentKeys.contains(studentKey)) {
                continue;
            }

            if (requestRow.Window__c != null) {
                if (requestRow.Window__c != windowId) {
                    continue;
                }
            } else if (!isRequestWithinWindowDates(requestRow, windowRecord)) {
                continue;
            }

            LearnerProgram learnerProgram = requestRow.Request_By__c != null
                ? learnerProgramByAccountId.get(requestRow.Request_By__c)
                : learnerProgramByContactId.get(requestRow.Requested_By__c);
            LearnerAcademicYearInfo learnerAcademicYearInfo = requestRow.Request_By__c != null
                ? academicYearInfoByAccountId.get(requestRow.Request_By__c)
                : academicYearInfoByContactId.get(requestRow.Requested_By__c);
            if (hasProgramScope && learnerProgram == null) {
                continue;
            }

            InProgressRow row = new InProgressRow();
            row.id = String.valueOf(requestRow.Id);
            row.accountId = requestRow.Request_By__c != null ? String.valueOf(requestRow.Request_By__c) : '';
            row.student = getRequestStudentName(requestRow);
            row.rollNo = getRequestStudentRollNo(requestRow);
            row.program = resolveLearnerProgramLabel(learnerProgram);
            row.programPlanId = learnerProgram != null ? String.valueOf(learnerProgram.LearningProgramPlanId) : '';
            row.year = deriveLearnerYearLabel(learnerProgram);
            row.academicYear = learnerAcademicYearInfo != null ? sanitize(learnerAcademicYearInfo.academicYearLabel) : '';
            row.yearPriorityRank = learnerAcademicYearInfo != null && learnerAcademicYearInfo.priorityRank != null
                ? learnerAcademicYearInfo.priorityRank
                : deriveLearnerYearPriorityRank(learnerProgram);
            row.category = resolveRequestCategoryLabel(requestRow);
            row.payment = '';
            row.allotmentType = normalizeInProgressAllotmentType(windowAllotmentType, null);
            row.status = sanitize(requestRow.Status__c);
            response.add(row);
            addedStudentKeys.add(studentKey);
        }

        return response;
    }

    private static Boolean isRequestWithinWindowDates(Ken_Room_Request__c requestRow, Ken_Windows__c windowRecord) {
        if (requestRow == null || requestRow.CreatedDate == null || windowRecord == null) {
            return true;
        }

        Date requestDate = requestRow.CreatedDate.date();
        Boolean startOk = windowRecord.Start_Date__c == null || requestDate >= windowRecord.Start_Date__c;
        Boolean endOk = windowRecord.End_Date__c == null || requestDate <= windowRecord.End_Date__c;
        return startOk && endOk;
    }

    private static String resolveRequestCategoryLabel(Ken_Room_Request__c requestRow) {
        if (requestRow == null) {
            return '';
        }

        return firstNonBlank(new List<String>{
            sanitize(requestRow.Preference_1_Category__c),
            requestRow.Preference_1__r != null ? sanitize(requestRow.Preference_1__r.Name__c) : null,
            requestRow.Preference_1__r != null ? sanitize(requestRow.Preference_1__r.Name) : null,
            sanitize(requestRow.Preference_2_Category__c),
            requestRow.Preference_2__r != null ? sanitize(requestRow.Preference_2__r.Name__c) : null,
            requestRow.Preference_2__r != null ? sanitize(requestRow.Preference_2__r.Name) : null,
            sanitize(requestRow.Preference_3_Category__c),
            requestRow.Preference_3__r != null ? sanitize(requestRow.Preference_3__r.Name__c) : null,
            requestRow.Preference_3__r != null ? sanitize(requestRow.Preference_3__r.Name) : null
        });
    }

    private static String resolveAllotmentRoomCategoryLabel(Ken_Room_Allotment__c allotment) {
        return firstNonBlank(new List<String>{
            allotment != null && allotment.Room__r != null && allotment.Room__r.Room_Category__r != null
                ? sanitize(allotment.Room__r.Room_Category__r.Name__c)
                : null,
            allotment != null && allotment.Room__r != null && allotment.Room__r.Room_Category__r != null
                ? sanitize(allotment.Room__r.Room_Category__r.Name)
                : null,
            allotment != null && allotment.Room__r != null
                ? sanitize(allotment.Room__r.Housing_Category__c)
                : null
        });
    }

    private static String resolveRoomCategoryLabel(Ken_Room__c room) {
        return firstNonBlank(new List<String>{
            room != null && room.Room_Category__r != null ? sanitize(room.Room_Category__r.Name__c) : null,
            room != null && room.Room_Category__r != null ? sanitize(room.Room_Category__r.Name) : null,
            room != null ? sanitize(room.Housing_Category__c) : null
        });
    }

    private static String buildStudentKey(Id accountId, Id contactId) {
        if (accountId != null) {
            return 'A:' + String.valueOf(accountId);
        }
        if (contactId != null) {
            return 'C:' + String.valueOf(contactId);
        }
        return null;
    }

    private static String getRequestStudentName(Ken_Room_Request__c requestRow) {
        return firstNonBlank(new List<String>{
            requestRow != null && requestRow.Request_By__r != null ? sanitize(requestRow.Request_By__r.Name) : null,
            requestRow != null && requestRow.Requested_By__r != null ? sanitize(requestRow.Requested_By__r.Name) : null
        });
    }

    private static String getRequestStudentRollNo(Ken_Room_Request__c requestRow) {
        return requestRow != null && requestRow.Request_By__r != null
            ? sanitize(requestRow.Request_By__r.Roll_No__c)
            : '';
    }

    private static String getRequestStudentEmail(Ken_Room_Request__c requestRow) {
        return firstNonBlank(new List<String>{
            requestRow != null && requestRow.Request_By__r != null ? sanitize(requestRow.Request_By__r.PersonEmail) : null,
            requestRow != null && requestRow.Requested_By__r != null ? sanitize(requestRow.Requested_By__r.Email) : null
        });
    }

    private static String getRequestStudentPhone(Ken_Room_Request__c requestRow) {
        return firstNonBlank(new List<String>{
            requestRow != null && requestRow.Request_By__r != null ? sanitize(requestRow.Request_By__r.PersonMobilePhone) : null,
            requestRow != null && requestRow.Requested_By__r != null ? sanitize(requestRow.Requested_By__r.MobilePhone) : null,
            requestRow != null && requestRow.Requested_By__r != null ? sanitize(requestRow.Requested_By__r.Phone) : null
        });
    }

    private static Id getAllotmentContactId(Ken_Room_Allotment__c allotment) {
        if (allotment == null) {
            return null;
        }
        if (allotment.Tenant__c != null) {
            return allotment.Tenant__c;
        }
        return allotment.Tenant_Account__r != null ? allotment.Tenant_Account__r.PersonContactId : null;
    }

    private static String getAllotmentStudentName(Ken_Room_Allotment__c allotment) {
        return firstNonBlank(new List<String>{
            allotment != null && allotment.Tenant_Account__r != null ? sanitize(allotment.Tenant_Account__r.Name) : null,
            allotment != null && allotment.Tenant__r != null ? sanitize(allotment.Tenant__r.Name) : null
        });
    }

    private static String getAllotmentStudentRollNo(Ken_Room_Allotment__c allotment) {
        return allotment != null && allotment.Tenant_Account__r != null
            ? sanitize(allotment.Tenant_Account__r.Roll_No__c)
            : '';
    }

    private static String getAllotmentStudentEmail(Ken_Room_Allotment__c allotment) {
        return firstNonBlank(new List<String>{
            allotment != null && allotment.Tenant_Account__r != null ? sanitize(allotment.Tenant_Account__r.PersonEmail) : null,
            allotment != null && allotment.Tenant__r != null ? sanitize(allotment.Tenant__r.Email) : null
        });
    }

    private static String getAllotmentStudentPhone(Ken_Room_Allotment__c allotment) {
        return firstNonBlank(new List<String>{
            allotment != null && allotment.Tenant_Account__r != null ? sanitize(allotment.Tenant_Account__r.PersonMobilePhone) : null,
            allotment != null && allotment.Tenant__r != null ? sanitize(allotment.Tenant__r.MobilePhone) : null,
            allotment != null && allotment.Tenant__r != null ? sanitize(allotment.Tenant__r.Phone) : null
        });
    }

    private static Id getPrimaryPreferenceCategoryId(Ken_Room_Request__c requestRow) {
        if (requestRow == null) {
            return null;
        }
        if (requestRow.Preference_1__c != null) {
            return requestRow.Preference_1__c;
        }
        if (requestRow.Preference_2__c != null) {
            return requestRow.Preference_2__c;
        }
        return requestRow.Preference_3__c;
    }

    private static Ken_Room_Request__c queryRoomRequestById(Id roomRequestId) {
        if (!Schema.sObjectType.Ken_Room_Request__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room requests.');
        }

        List<Ken_Room_Request__c> rows = [
            SELECT
                Id,
                Name,
                Request_By__c,
                Request_By__r.Name,
                Request_By__r.Roll_No__c,
                Request_By__r.PersonEmail,
                Request_By__r.PersonMobilePhone,
                Request_By__r.PersonContactId,
                Requested_By__c,
                Requested_By__r.Name,
                Requested_By__r.Email,
                Requested_By__r.MobilePhone,
                Requested_By__r.Phone,
                Room_Allotment__c,
                Window__c,
                Status__c,
                Preferred_Partner__c,
                Preferred_Partner__r.Name,
                Preferred_Partner__r.PersonEmail,
                Preferred_Partner__r.Roll_No__c,
                Preferred_Partner__r.PersonContactId,
                Preference_1__c,
                Preference_1_Category__c,
                Preference_1__r.Name,
                Preference_1__r.Name__c,
                Preference_1__r.Capacity__c,
                Preference_2__c,
                Preference_2_Category__c,
                Preference_2__r.Name,
                Preference_2__r.Name__c,
                Preference_2__r.Capacity__c,
                Preference_3__c,
                Preference_3_Category__c,
                Preference_3__r.Name,
                Preference_3__r.Name__c,
                Preference_3__r.Capacity__c,
                CreatedDate
            FROM Ken_Room_Request__c
            WHERE Id = :roomRequestId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new AuraHandledException('Application is required.');
        }
        return rows[0];
    }

    private static ApplicationDetailResponse buildInProgressApplicationDetailFromRequest(Id roomRequestId, Id windowId) {
        Ken_Room_Request__c roomRequest = queryRoomRequestById(roomRequestId);
        ApplicationDetailResponse response = new ApplicationDetailResponse();
        response.allotmentId = String.valueOf(roomRequest.Id);
        response.studentName = getRequestStudentName(roomRequest);
        response.rollNo = getRequestStudentRollNo(roomRequest);
        response.email = getRequestStudentEmail(roomRequest);
        response.phone = getRequestStudentPhone(roomRequest);
        response.allotmentType = getWindowAllotmentType(windowId);
        response.categoryApplied = resolveRequestCategoryLabel(roomRequest);
        response.applicationStatus = sanitize(roomRequest.Status__c);
        response.paymentStatus = '';
        response.appliedOn = formatDateTimeToDate(roomRequest.CreatedDate);

        WindowScope scope = getWindowScope(windowId);
        LearnerProgram learnerProgram = resolveRequestLearnerProgram(roomRequest, scope);
        response.program = resolveLearnerProgramLabel(learnerProgram);
        response.year = deriveLearnerYearLabel(learnerProgram);
        response.roommatePreference = buildRoommatePreference(roomRequest, roomRequest.Request_By__c);
        response.roomPreferences = buildRoomPreferences(
            roomRequest,
            windowId,
            getPrimaryPreferenceCategoryId(roomRequest)
        );
        return response;
    }

    private static List<RoomAssignmentOption> buildAssignableRooms(
        Id windowRecordId,
        Id currentRoomId,
        Id previousRoomId,
        Ken_Room_Request__c roomRequest,
        Id currentAccountId
    ) {
        if (!Schema.sObjectType.Ken_Room__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view rooms.');
        }

        Set<Id> preferredCategoryIds = getPreferenceCategoryIds(roomRequest);
        Set<Id> roommateMatchCategoryIds = getRoommateMatchCategoryIds(
            roomRequest,
            currentAccountId
        );

        WindowScope scope = getWindowScope(windowRecordId);
        List<RoomAssignmentOption> response = new List<RoomAssignmentOption>();
        for (Ken_Room__c room : [
            SELECT
                Id,
                Name,
                Room_Number__c,
                Building__c,
                Building__r.Name,
                Room_Category__c,
                Room_Category__r.Name,
                Room_Category__r.Name__c,
                Housing_Category__c,
                Capacity__c,
                Occupancy_Status__c,
                Room_Status__c
            FROM Ken_Room__c
            WHERE Building__c != null
            ORDER BY Building__r.Name ASC NULLS LAST, Name ASC NULLS LAST, Room_Number__c ASC NULLS LAST
            LIMIT 1000
        ]) {
            if (!scope.buildingIds.isEmpty() && !scope.buildingIds.contains(room.Building__c)) {
                continue;
            }
            if (!scope.roomCategoryIds.isEmpty() && !scope.roomCategoryIds.contains(room.Room_Category__c)) {
                continue;
            }

            Integer capacity = room.Capacity__c == null ? 0 : Integer.valueOf(room.Capacity__c);
            Integer occupancy = room.Occupancy_Status__c == null ? 0 : Integer.valueOf(room.Occupancy_Status__c);
            Integer availableBeds = capacity - occupancy;
            RoomAssignmentOption option = new RoomAssignmentOption();
            option.id = String.valueOf(room.Id);
            option.room = firstNonBlank(new List<String>{ room.Name, room.Room_Number__c });
            option.building = room.Building__r != null ? sanitize(room.Building__r.Name) : '';
            option.floorLabel = '';
            option.category = resolveRoomCategoryLabel(room);
            option.capacity = capacity;
            option.occupancy = occupancy;

            if (availableBeds <= 0) {
                option.status = 'Full';
                option.statusTone = 'red';
            } else if (occupancy > 0) {
                option.status = 'Partially Occupied';
                option.statusTone = 'amber';
            } else {
                option.status = 'Available';
                option.statusTone = 'green';
            }

            option.preferenceMatch = availableBeds > 0
                && room.Room_Category__c != null
                && preferredCategoryIds.contains(room.Room_Category__c);
            option.roommateMatch = availableBeds > 0
                && room.Room_Category__c != null
                && roommateMatchCategoryIds.contains(room.Room_Category__c);
            option.isPreviousRoom = room.Id == previousRoomId;
            option.selectable = availableBeds > 0 || room.Id == currentRoomId;
            response.add(option);
        }

        return response;
    }

    private static Ken_Windows__c queryWindowSchedule(Id windowRecordId) {
        if (windowRecordId == null) {
            return null;
        }
        if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view residence windows.');
        }

        List<Ken_Windows__c> rows = [
            SELECT
                Id,
                Start_Date__c,
                End_Date__c,
                Room_Allotment_Start_Date__c,
                Room_Allotment_End_Date__c,
                Hostel_Cycle__c,
                Hostel_Cycle__r.Previous_Cycle__c
            FROM Ken_Windows__c
            WHERE Id = :windowRecordId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static Id resolveCarryForwardRoomId(
        Id accountId,
        Id contactId,
        Ken_Windows__c windowRecord,
        Date referenceDate,
        Id excludedAllotmentId
    ) {
        if (referenceDate == null) {
            return null;
        }
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room allotments.');
        }

        Id previousCycleId = windowRecord != null &&
            windowRecord.Hostel_Cycle__r != null
            ? windowRecord.Hostel_Cycle__r.Previous_Cycle__c
            : null;
        if (previousCycleId == null) {
            return null;
        }

        List<Ken_Room_Allotment__c> priorAllotments;
        if (accountId != null) {
            priorAllotments = [
                SELECT Id, Room__c, Active__c, Start_Date__c, End_Date__c, Window__c, Window__r.Hostel_Cycle__c
                FROM Ken_Room_Allotment__c
                WHERE Tenant_Account__c = :accountId
                    AND Room__c != null
                    AND Window__c != null
                    AND Window__r.Hostel_Cycle__c = :previousCycleId
                    AND (
                        (End_Date__c != null AND End_Date__c <= :referenceDate)
                        OR (Active__c = false AND End_Date__c = null AND Start_Date__c != null AND Start_Date__c < :referenceDate)
                    )
                ORDER BY End_Date__c DESC NULLS LAST, Start_Date__c DESC NULLS LAST, CreatedDate DESC
                LIMIT 50
            ];
        } else if (contactId != null) {
            priorAllotments = [
                SELECT Id, Room__c, Active__c, Start_Date__c, End_Date__c, Window__c, Window__r.Hostel_Cycle__c
                FROM Ken_Room_Allotment__c
                WHERE Tenant__c = :contactId
                    AND Room__c != null
                    AND Window__c != null
                    AND Window__r.Hostel_Cycle__c = :previousCycleId
                    AND (
                        (End_Date__c != null AND End_Date__c <= :referenceDate)
                        OR (Active__c = false AND End_Date__c = null AND Start_Date__c != null AND Start_Date__c < :referenceDate)
                    )
                ORDER BY End_Date__c DESC NULLS LAST, Start_Date__c DESC NULLS LAST, CreatedDate DESC
                LIMIT 50
            ];
        } else {
            return null;
        }

        for (Ken_Room_Allotment__c priorAllotment : priorAllotments) {
            if (excludedAllotmentId != null && priorAllotment.Id == excludedAllotmentId) {
                continue;
            }
            return priorAllotment.Room__c;
        }
        return null;
    }

    private static Date resolveCarryForwardReferenceDate(
        Ken_Windows__c windowRecord,
        Ken_Room_Allotment__c allotment,
        Date fallbackDate
    ) {
        if (windowRecord != null) {
            if (windowRecord.Room_Allotment_Start_Date__c != null) {
                return windowRecord.Room_Allotment_Start_Date__c;
            }
            if (windowRecord.Start_Date__c != null) {
                return windowRecord.Start_Date__c;
            }
        }

        if (allotment != null && allotment.Start_Date__c != null) {
            return allotment.Start_Date__c;
        }
        if (fallbackDate != null) {
            return fallbackDate;
        }
        return Date.today();
    }

    private static Boolean isRoomRequestId(Id recordId) {
        return recordId != null && recordId.getSObjectType() == Ken_Room_Request__c.SObjectType;
    }

    private static String deriveAssignedRequestStatus(String assignmentAllotmentType) {
        return 'Alloted';
    }

    private static void syncLinkedRoomRequestStatus(Id allotmentId, String assignmentAllotmentType) {
        if (allotmentId == null) {
            return;
        }
        if (!Schema.sObjectType.Ken_Room_Request__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room requests.');
        }
        if (!Schema.sObjectType.Ken_Room_Request__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update room requests.');
        }

        List<Ken_Room_Request__c> rowsToUpdate = new List<Ken_Room_Request__c>();
        String nextStatus = deriveAssignedRequestStatus(assignmentAllotmentType);
        for (Ken_Room_Request__c requestRow : [
            SELECT Id, Status__c
            FROM Ken_Room_Request__c
            WHERE Room_Allotment__c = :allotmentId
        ]) {
            if (requestRow.Status__c == nextStatus) {
                continue;
            }
            rowsToUpdate.add(new Ken_Room_Request__c(
                Id = requestRow.Id,
                Status__c = nextStatus
            ));
        }

        if (!rowsToUpdate.isEmpty()) {
            update rowsToUpdate;
        }
    }

    private static void relinkLinkedRoomRequests(Id priorAllotmentId, Id nextAllotmentId, String assignmentAllotmentType) {
        if (priorAllotmentId == null) {
            return;
        }
        if (!Schema.sObjectType.Ken_Room_Request__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room requests.');
        }
        if (!Schema.sObjectType.Ken_Room_Request__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update room requests.');
        }

        List<Ken_Room_Request__c> rowsToUpdate = new List<Ken_Room_Request__c>();
        String nextStatus = deriveAssignedRequestStatus(assignmentAllotmentType);
        for (Ken_Room_Request__c requestRow : [
            SELECT Id, Room_Allotment__c, Status__c
            FROM Ken_Room_Request__c
            WHERE Room_Allotment__c = :priorAllotmentId
        ]) {
            rowsToUpdate.add(new Ken_Room_Request__c(
                Id = requestRow.Id,
                Room_Allotment__c = nextAllotmentId,
                Status__c = nextStatus
            ));
        }

        if (!rowsToUpdate.isEmpty()) {
            update rowsToUpdate;
        }
    }

    private static void reopenLinkedRoomRequests(Id allotmentId) {
        if (allotmentId == null) {
            return;
        }
        if (!Schema.sObjectType.Ken_Room_Request__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room requests.');
        }
        if (!Schema.sObjectType.Ken_Room_Request__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update room requests.');
        }

        List<Ken_Room_Request__c> rowsToUpdate = new List<Ken_Room_Request__c>();
        for (Ken_Room_Request__c requestRow : [
            SELECT Id, Room_Allotment__c, Status__c
            FROM Ken_Room_Request__c
            WHERE Room_Allotment__c = :allotmentId
        ]) {
            rowsToUpdate.add(new Ken_Room_Request__c(
                Id = requestRow.Id,
                Room_Allotment__c = null,
                Status__c = 'Pending'
            ));
        }

        if (!rowsToUpdate.isEmpty()) {
            update rowsToUpdate;
        }
    }

    private static void completeLinkedRoomRequests(Id allotmentId) {
        if (allotmentId == null) {
            return;
        }
        if (!Schema.sObjectType.Ken_Room_Request__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room requests.');
        }
        if (!Schema.sObjectType.Ken_Room_Request__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update room requests.');
        }

        List<Ken_Room_Request__c> rowsToUpdate = new List<Ken_Room_Request__c>();
        for (Ken_Room_Request__c requestRow : [
            SELECT Id, Status__c
            FROM Ken_Room_Request__c
            WHERE Room_Allotment__c = :allotmentId
        ]) {
            if (requestRow.Status__c == 'Stay Completed') {
                continue;
            }
            rowsToUpdate.add(new Ken_Room_Request__c(
                Id = requestRow.Id,
                Status__c = 'Stay Completed'
            ));
        }

        if (!rowsToUpdate.isEmpty()) {
            update rowsToUpdate;
        }
    }

    private static Date resolveReassignmentEndDate(Ken_Room_Allotment__c allotment, Date nextStartDate) {
        Date candidateDate = Date.today();
        if (allotment != null && allotment.Start_Date__c != null && allotment.Start_Date__c > candidateDate) {
            candidateDate = allotment.Start_Date__c;
        }
        if (nextStartDate != null && nextStartDate < candidateDate) {
            candidateDate = nextStartDate;
        }
        return candidateDate;
    }

    private static Boolean matchesWindowProgramScope(WindowScope scope, LearnerProgram learnerProgram) {
        Boolean hasPlanScope = scope != null && scope.learningProgramPlanIds != null && !scope.learningProgramPlanIds.isEmpty();
        Boolean hasProgramScope = scope != null && scope.learningProgramIds != null && !scope.learningProgramIds.isEmpty();
        if (!hasPlanScope && !hasProgramScope) {
            return true;
        }

        Id learningProgramPlanId = learnerProgram != null ? learnerProgram.LearningProgramPlanId : null;
        Id learningProgramId = learnerProgram != null && learnerProgram.LearningProgramPlan != null
            ? learnerProgram.LearningProgramPlan.LearningProgramId
            : null;

        if (hasPlanScope && learningProgramPlanId != null && scope.learningProgramPlanIds.contains(learningProgramPlanId)) {
            return true;
        }
        if (hasProgramScope && learningProgramId != null && scope.learningProgramIds.contains(learningProgramId)) {
            return true;
        }
        return false;
    }

    private static Ken_Room_Request__c getLatestRoomRequestForDetail(Id accountId, Id contactId, Id windowRecordId, Id allotmentId) {
        if (!Schema.sObjectType.Ken_Room_Request__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room requests.');
        }

        Ken_Room_Request__c roomRequest;

        if (accountId != null && windowRecordId != null) {
            List<Ken_Room_Request__c> rows = [
                SELECT Id, CreatedDate, Status__c, Preferred_Partner__c,
                    Preferred_Partner__r.Name,
                    Preferred_Partner__r.PersonEmail,
                    Preferred_Partner__r.Roll_No__c,
                    Preferred_Partner__r.PersonContactId,
                    Preference_1__c, Preference_2__c, Preference_3__c,
                    Preference_1_Category__c, Preference_2_Category__c, Preference_3_Category__c,
                    Preference_1__r.Name, Preference_1__r.Name__c, Preference_1__r.Capacity__c,
                    Preference_2__r.Name, Preference_2__r.Name__c, Preference_2__r.Capacity__c,
                    Preference_3__r.Name, Preference_3__r.Name__c, Preference_3__r.Capacity__c
                FROM Ken_Room_Request__c
                WHERE Request_By__c = :accountId
                    AND Window__c = :windowRecordId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!rows.isEmpty()) {
                roomRequest = rows[0];
            }
        }

        if (roomRequest == null && allotmentId != null) {
            List<Ken_Room_Request__c> rows = [
                SELECT Id, CreatedDate, Status__c, Preferred_Partner__c,
                    Preferred_Partner__r.Name,
                    Preferred_Partner__r.PersonEmail,
                    Preferred_Partner__r.Roll_No__c,
                    Preferred_Partner__r.PersonContactId,
                    Preference_1__c, Preference_2__c, Preference_3__c,
                    Preference_1_Category__c, Preference_2_Category__c, Preference_3_Category__c,
                    Preference_1__r.Name, Preference_1__r.Name__c, Preference_1__r.Capacity__c,
                    Preference_2__r.Name, Preference_2__r.Name__c, Preference_2__r.Capacity__c,
                    Preference_3__r.Name, Preference_3__r.Name__c, Preference_3__r.Capacity__c
                FROM Ken_Room_Request__c
                WHERE Room_Allotment__c = :allotmentId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!rows.isEmpty()) {
                roomRequest = rows[0];
            }
        }

        if (roomRequest == null && accountId != null) {
            List<Ken_Room_Request__c> rows = [
                SELECT Id, CreatedDate, Status__c, Preferred_Partner__c,
                    Preferred_Partner__r.Name,
                    Preferred_Partner__r.PersonEmail,
                    Preferred_Partner__r.Roll_No__c,
                    Preferred_Partner__r.PersonContactId,
                    Preference_1__c, Preference_2__c, Preference_3__c,
                    Preference_1_Category__c, Preference_2_Category__c, Preference_3_Category__c,
                    Preference_1__r.Name, Preference_1__r.Name__c, Preference_1__r.Capacity__c,
                    Preference_2__r.Name, Preference_2__r.Name__c, Preference_2__r.Capacity__c,
                    Preference_3__r.Name, Preference_3__r.Name__c, Preference_3__r.Capacity__c
                FROM Ken_Room_Request__c
                WHERE Request_By__c = :accountId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!rows.isEmpty()) {
                roomRequest = rows[0];
            }
        }

        if (roomRequest == null && contactId != null) {
            List<Ken_Room_Request__c> rows = [
                SELECT Id, CreatedDate, Status__c, Preferred_Partner__c,
                    Preferred_Partner__r.Name,
                    Preferred_Partner__r.PersonEmail,
                    Preferred_Partner__r.Roll_No__c,
                    Preferred_Partner__r.PersonContactId,
                    Preference_1__c, Preference_2__c, Preference_3__c,
                    Preference_1_Category__c, Preference_2_Category__c, Preference_3_Category__c,
                    Preference_1__r.Name, Preference_1__r.Name__c, Preference_1__r.Capacity__c,
                    Preference_2__r.Name, Preference_2__r.Name__c, Preference_2__r.Capacity__c,
                    Preference_3__r.Name, Preference_3__r.Name__c, Preference_3__r.Capacity__c
                FROM Ken_Room_Request__c
                WHERE Requested_By__c = :contactId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!rows.isEmpty()) {
                roomRequest = rows[0];
            }
        }

        return roomRequest;
    }

    private static List<RoomPreferenceItem> buildRoomPreferences(Ken_Room_Request__c roomRequest, Id windowId, Id fallbackRoomCategoryId) {
        List<RoomPreferenceItem> items = new List<RoomPreferenceItem>();
        if (roomRequest != null) {
            Set<Id> categoryIds = new Set<Id>();
            if (roomRequest.Preference_1__c != null) {
                categoryIds.add(roomRequest.Preference_1__c);
            }
            if (roomRequest.Preference_2__c != null) {
                categoryIds.add(roomRequest.Preference_2__c);
            }
            if (roomRequest.Preference_3__c != null) {
                categoryIds.add(roomRequest.Preference_3__c);
            }

            Map<Id, RoomAvailabilityMetrics> availabilityByCategoryId = getRoomAvailabilityByCategory(windowId, categoryIds);
            appendRoomPreferenceItem(items, 1, roomRequest.Preference_1__c, roomRequest.Preference_1_Category__c, roomRequest.Preference_1__r, availabilityByCategoryId);
            appendRoomPreferenceItem(items, 2, roomRequest.Preference_2__c, roomRequest.Preference_2_Category__c, roomRequest.Preference_2__r, availabilityByCategoryId);
            appendRoomPreferenceItem(items, 3, roomRequest.Preference_3__c, roomRequest.Preference_3_Category__c, roomRequest.Preference_3__r, availabilityByCategoryId);
        }

        if (items.size() < 3) {
            List<RoomPreferenceItem> fallbackItems = buildFallbackRoomPreferences(windowId, fallbackRoomCategoryId);
            Set<String> existingTitles = new Set<String>();
            for (RoomPreferenceItem item : items) {
                if (String.isNotBlank(item.title)) {
                    existingTitles.add(item.title);
                }
            }

            for (RoomPreferenceItem fallbackItem : fallbackItems) {
                if (String.isBlank(fallbackItem.title) || existingTitles.contains(fallbackItem.title)) {
                    continue;
                }
                fallbackItem.order = items.size() + 1;
                fallbackItem.id = String.valueOf(fallbackItem.order);
                items.add(fallbackItem);
                existingTitles.add(fallbackItem.title);
                if (items.size() >= 3) {
                    break;
                }
            }
        }

        if (!items.isEmpty()) {
            return items;
        }

        return buildFallbackRoomPreferences(windowId, fallbackRoomCategoryId);
    }

    private static List<RoomPreferenceItem> buildFallbackRoomPreferences(Id windowId, Id preferredCategoryId) {
        List<RoomPreferenceItem> items = new List<RoomPreferenceItem>();
        List<RoomAvailabilityMetrics> fallbackRooms = getFallbackRoomPreferenceMetrics(
            windowId,
            preferredCategoryId == null ? new Set<Id>() : new Set<Id>{ preferredCategoryId },
            3
        );

        if (fallbackRooms.isEmpty() && preferredCategoryId != null) {
            fallbackRooms = getFallbackRoomPreferenceMetrics(windowId, new Set<Id>(), 3);
        }

        Integer order = 1;
        for (RoomAvailabilityMetrics metrics : fallbackRooms) {
            RoomPreferenceItem item = new RoomPreferenceItem();
            item.id = String.valueOf(order);
            item.order = order;
            item.title = sanitize(metrics.title);
            item.subtitle = sanitize(metrics.subtitle);
            item.meta = buildRoomPreferenceMeta(metrics);
            item.availabilityLabel = metrics.availableBeds > 0 ? 'Available' : 'Full';
            item.availabilityTone = metrics.availableBeds > 0 ? 'success' : 'danger';
            items.add(item);
            order++;
        }

        return items;
    }

    private static void appendRoomPreferenceItem(
        List<RoomPreferenceItem> items,
        Integer order,
        Id categoryId,
        String categoryLabel,
        Ken_Room_Category__c categoryRecord,
        Map<Id, RoomAvailabilityMetrics> availabilityByCategoryId
    ) {
        if (categoryId == null && String.isBlank(categoryLabel) && categoryRecord == null) {
            return;
        }

        RoomAvailabilityMetrics metrics = categoryId != null ? availabilityByCategoryId.get(categoryId) : null;
        if (metrics == null || metrics.totalBeds <= 0) {
            return;
        }

        RoomPreferenceItem item = new RoomPreferenceItem();
        item.id = String.valueOf(order);
        item.order = order;
        item.title = firstNonBlank(new List<String>{
            metrics != null ? metrics.title : null,
            categoryLabel,
            categoryRecord != null ? categoryRecord.Name__c : null,
            categoryRecord != null ? categoryRecord.Name : null
        });

        item.subtitle = metrics != null ? sanitize(metrics.subtitle) : '';
        item.meta = buildRoomPreferenceMeta(metrics);
        item.availabilityLabel = metrics.availableBeds > 0 ? 'Available' : 'Full';
        item.availabilityTone = metrics.availableBeds > 0 ? 'success' : 'danger';

        items.add(item);
    }

    private static Map<Id, RoomAvailabilityMetrics> getRoomAvailabilityByCategory(Id windowId, Set<Id> requestedCategoryIds) {
        Map<Id, RoomAvailabilityMetrics> metricsByCategoryId = new Map<Id, RoomAvailabilityMetrics>();
        if (requestedCategoryIds == null || requestedCategoryIds.isEmpty()) {
            return metricsByCategoryId;
        }
        if (!Schema.sObjectType.Ken_Room__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view rooms.');
        }

        WindowScope scope = getWindowScope(windowId);
        for (Ken_Room__c room : [
            SELECT
                Id,
                Name,
                Room_Number__c,
                Room_Category__c,
                Room_Category__r.Name,
                Room_Category__r.Name__c,
                Housing_Category__c,
                Building__c,
                Building__r.Name,
                Capacity__c,
                Occupancy_Status__c
            FROM Ken_Room__c
            WHERE Room_Category__c IN :requestedCategoryIds
            ORDER BY Building__r.Name ASC NULLS LAST, Name ASC NULLS LAST, Room_Number__c ASC NULLS LAST
        ]) {
            if (scope != null && !scope.buildingIds.isEmpty() && !scope.buildingIds.contains(room.Building__c)) {
                continue;
            }
            if (scope != null && !scope.roomCategoryIds.isEmpty() && !scope.roomCategoryIds.contains(room.Room_Category__c)) {
                continue;
            }
            if (room.Room_Category__c == null) {
                continue;
            }

            RoomAvailabilityMetrics candidate = toRoomAvailabilityMetrics(room);
            RoomAvailabilityMetrics current = metricsByCategoryId.get(room.Room_Category__c);
            if (shouldReplaceRoomPreferenceCandidate(current, candidate)) {
                metricsByCategoryId.put(room.Room_Category__c, candidate);
            }
        }

        return metricsByCategoryId;
    }

    private static List<RoomAvailabilityMetrics> getFallbackRoomPreferenceMetrics(Id windowId, Set<Id> requestedCategoryIds, Integer maxItems) {
        List<RoomAvailabilityMetrics> preferredRooms = new List<RoomAvailabilityMetrics>();
        List<RoomAvailabilityMetrics> fullRooms = new List<RoomAvailabilityMetrics>();
        if (!Schema.sObjectType.Ken_Room__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view rooms.');
        }
        WindowScope scope = getWindowScope(windowId);

        for (Ken_Room__c room : [
            SELECT
                Id,
                Name,
                Room_Number__c,
                Room_Category__c,
                Room_Category__r.Name,
                Room_Category__r.Name__c,
                Housing_Category__c,
                Building__c,
                Building__r.Name,
                Capacity__c,
                Occupancy_Status__c
            FROM Ken_Room__c
            WHERE Building__c != null
            ORDER BY Building__r.Name ASC NULLS LAST, Name ASC NULLS LAST, Room_Number__c ASC NULLS LAST
        ]) {
            if (scope != null && !scope.buildingIds.isEmpty() && !scope.buildingIds.contains(room.Building__c)) {
                continue;
            }
            if (scope != null && !scope.roomCategoryIds.isEmpty() && !scope.roomCategoryIds.contains(room.Room_Category__c)) {
                continue;
            }
            if (!requestedCategoryIds.isEmpty() && !requestedCategoryIds.contains(room.Room_Category__c)) {
                continue;
            }

            RoomAvailabilityMetrics metrics = toRoomAvailabilityMetrics(room);
            if (metrics.availableBeds > 0) {
                preferredRooms.add(metrics);
            } else {
                fullRooms.add(metrics);
            }
        }

        List<RoomAvailabilityMetrics> orderedRooms = new List<RoomAvailabilityMetrics>();
        orderedRooms.addAll(preferredRooms);
        orderedRooms.addAll(fullRooms);

        List<RoomAvailabilityMetrics> limitedRooms = new List<RoomAvailabilityMetrics>();
        Integer limitSize = maxItems == null || maxItems <= 0 ? orderedRooms.size() : maxItems;
        for (RoomAvailabilityMetrics metrics : orderedRooms) {
            if (limitedRooms.size() >= limitSize) {
                break;
            }
            limitedRooms.add(metrics);
        }
        return limitedRooms;
    }

    private static RoomAvailabilityMetrics toRoomAvailabilityMetrics(Ken_Room__c room) {
        RoomAvailabilityMetrics metrics = new RoomAvailabilityMetrics();
        Integer capacity = room.Capacity__c == null ? 0 : Integer.valueOf(room.Capacity__c);
        Integer occupied = room.Occupancy_Status__c == null ? 0 : Integer.valueOf(room.Occupancy_Status__c);
        Integer availableBeds = capacity - occupied;

        metrics.title = firstNonBlank(new List<String>{
            sanitize(room.Name),
            sanitize(room.Room_Number__c)
        });
        metrics.subtitle = room.Building__r != null ? sanitize(room.Building__r.Name) : '';
        metrics.categoryLabel = resolveRoomCategoryLabel(room);
        metrics.availableBeds = Math.max(availableBeds, 0);
        metrics.totalBeds = Math.max(capacity, 0);
        return metrics;
    }

    private static Boolean shouldReplaceRoomPreferenceCandidate(RoomAvailabilityMetrics current, RoomAvailabilityMetrics candidate) {
        if (candidate == null) {
            return false;
        }
        if (current == null) {
            return true;
        }
        if (candidate.availableBeds != current.availableBeds) {
            return candidate.availableBeds > current.availableBeds;
        }
        if (candidate.totalBeds != current.totalBeds) {
            return candidate.totalBeds > current.totalBeds;
        }
        return false;
    }

    private static String buildRoomPreferenceMeta(RoomAvailabilityMetrics metrics) {
        if (metrics == null || metrics.totalBeds <= 0) {
            return '';
        }

        String bedsLabel = String.valueOf(Math.max(metrics.availableBeds, 0)) + '/' + String.valueOf(metrics.totalBeds) + ' beds available';
        if (String.isBlank(metrics.categoryLabel)) {
            return bedsLabel;
        }
        return metrics.categoryLabel + ' · ' + bedsLabel;
    }

    private static RoommatePreferenceItem buildRoommatePreference(Ken_Room_Request__c roomRequest, Id currentAccountId) {
        RoommatePreferenceItem item = new RoommatePreferenceItem();
        if (roomRequest == null || roomRequest.Preferred_Partner__c == null) {
            return item;
        }
        Account preferredPartner = roomRequest.Preferred_Partner__r;
        if (preferredPartner == null) {
            if (!Schema.sObjectType.Account.isAccessible()) {
                throw new AuraHandledException('You do not have permission to view accounts.');
            }
            preferredPartner = [
                SELECT Id, Name, PersonEmail, Roll_No__c, PersonContactId
                FROM Account
                WHERE Id = :roomRequest.Preferred_Partner__c
                LIMIT 1
            ];
        }

        item.name = preferredPartner != null ? sanitize(preferredPartner.Name) : '';
        item.email = preferredPartner != null ? sanitize(preferredPartner.PersonEmail) : '';
        item.rollNo = preferredPartner != null ? sanitize(preferredPartner.Roll_No__c) : '';

        Ken_Room_Request__c partnerRequest = getLatestRoomRequestForDetail(
            preferredPartner != null ? preferredPartner.Id : null,
            preferredPartner != null ? preferredPartner.PersonContactId : null,
            null,
            null
        );

        if (partnerRequest != null) {
            item.currentStatus = sanitize(partnerRequest.Status__c);
            if (currentAccountId != null && partnerRequest.Preferred_Partner__c == currentAccountId) {
                item.matchLabel = 'Mutual Match';
            }
            item.samePreferenceSelected = hasSharedPreference(roomRequest, partnerRequest) ? 'Yes' : '';
        }

        return item;
    }

    private static Boolean hasSharedPreference(Ken_Room_Request__c firstRequest, Ken_Room_Request__c secondRequest) {
        Set<Id> firstPreferenceIds = new Set<Id>();
        if (firstRequest.Preference_1__c != null) {
            firstPreferenceIds.add(firstRequest.Preference_1__c);
        }
        if (firstRequest.Preference_2__c != null) {
            firstPreferenceIds.add(firstRequest.Preference_2__c);
        }
        if (firstRequest.Preference_3__c != null) {
            firstPreferenceIds.add(firstRequest.Preference_3__c);
        }

        if (secondRequest.Preference_1__c != null && firstPreferenceIds.contains(secondRequest.Preference_1__c)) {
            return true;
        }
        if (secondRequest.Preference_2__c != null && firstPreferenceIds.contains(secondRequest.Preference_2__c)) {
            return true;
        }
        if (secondRequest.Preference_3__c != null && firstPreferenceIds.contains(secondRequest.Preference_3__c)) {
            return true;
        }
        return false;
    }

    private static Set<Id> getPreferenceCategoryIds(Ken_Room_Request__c roomRequest) {
        Set<Id> categoryIds = new Set<Id>();
        if (roomRequest == null) {
            return categoryIds;
        }

        if (roomRequest.Preference_1__c != null) {
            categoryIds.add(roomRequest.Preference_1__c);
        }
        if (roomRequest.Preference_2__c != null) {
            categoryIds.add(roomRequest.Preference_2__c);
        }
        if (roomRequest.Preference_3__c != null) {
            categoryIds.add(roomRequest.Preference_3__c);
        }
        return categoryIds;
    }

    private static Set<Id> getRoommateMatchCategoryIds(Ken_Room_Request__c roomRequest, Id currentAccountId) {
        Set<Id> categoryIds = new Set<Id>();
        if (roomRequest == null || roomRequest.Preferred_Partner__c == null || currentAccountId == null) {
            return categoryIds;
        }
        Account preferredPartner = roomRequest.Preferred_Partner__r;
        if (preferredPartner == null) {
            if (!Schema.sObjectType.Account.isAccessible()) {
                throw new AuraHandledException('You do not have permission to view accounts.');
            }
            preferredPartner = [
                SELECT Id, Name, PersonEmail, Roll_No__c, PersonContactId
                FROM Account
                WHERE Id = :roomRequest.Preferred_Partner__c
                LIMIT 1
            ];
        }
        Ken_Room_Request__c partnerRequest = getLatestRoomRequestForDetail(
            preferredPartner != null ? preferredPartner.Id : null,
            preferredPartner != null ? preferredPartner.PersonContactId : null,
            null,
            null
        );

        if (partnerRequest == null) {
            return categoryIds;
        }

        if (currentAccountId != null && partnerRequest.Preferred_Partner__c != currentAccountId) {
            return categoryIds;
        }

        Set<Id> firstPreferenceIds = getPreferenceCategoryIds(roomRequest);
        if (partnerRequest.Preference_1__c != null && firstPreferenceIds.contains(partnerRequest.Preference_1__c)) {
            categoryIds.add(partnerRequest.Preference_1__c);
        }
        if (partnerRequest.Preference_2__c != null && firstPreferenceIds.contains(partnerRequest.Preference_2__c)) {
            categoryIds.add(partnerRequest.Preference_2__c);
        }
        if (partnerRequest.Preference_3__c != null && firstPreferenceIds.contains(partnerRequest.Preference_3__c)) {
            categoryIds.add(partnerRequest.Preference_3__c);
        }

        return categoryIds;
    }

    private static Set<Id> getActiveStudentAccountIds() {
        Set<Id> accountIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        if (!Schema.sObjectType.ConstituentRole.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view constituent roles.');
        }
        if (!Schema.sObjectType.Contact.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view contacts.');
        }
        if (!Schema.sObjectType.Account.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view accounts.');
        }

        for (ConstituentRole roleRow : [
            SELECT PersonId
            FROM ConstituentRole
            WHERE RoleType = 'Student'
                AND Status = 'Active'
        ]) {
            if (roleRow.PersonId == null) {
                continue;
            }

            Schema.SObjectType personType = roleRow.PersonId.getSObjectType();
            if (personType == Account.SObjectType) {
                accountIds.add(roleRow.PersonId);
            } else if (personType == Contact.SObjectType) {
                contactIds.add(roleRow.PersonId);
            }
        }

        if (!contactIds.isEmpty()) {
            for (Contact contactRow : [
                SELECT Id, AccountId
                FROM Contact
                WHERE Id IN :contactIds
                    AND AccountId != null
            ]) {
                accountIds.add(contactRow.AccountId);
            }
        }

        if (accountIds.isEmpty()) {
            return new Set<Id>();
        }

        Set<Id> personAccountIds = new Set<Id>();
        for (Account accountRow : [
            SELECT Id
            FROM Account
            WHERE Id IN :accountIds
                AND IsPersonAccount = true
        ]) {
            personAccountIds.add(accountRow.Id);
        }
        return personAccountIds;
    }

    private static Boolean hasWindowProgramScope(WindowScope scope) {
        return scope != null && (
            (scope.learningProgramPlanIds != null && !scope.learningProgramPlanIds.isEmpty()) ||
            (scope.learningProgramIds != null && !scope.learningProgramIds.isEmpty())
        );
    }

    private static LearnerProgram resolveRequestLearnerProgram(Ken_Room_Request__c roomRequest, WindowScope scope) {
        if (roomRequest == null) {
            return null;
        }
        if (roomRequest.Request_By__c != null) {
            return getRelevantLearnerPrograms(new Set<Id>{ roomRequest.Request_By__c }, scope).get(roomRequest.Request_By__c);
        }
        if (roomRequest.Requested_By__c != null) {
            return getRelevantLearnerProgramsByContact(new Set<Id>{ roomRequest.Requested_By__c }, scope).get(roomRequest.Requested_By__c);
        }
        return null;
    }

    private static LearnerProgram resolveAllotmentLearnerProgram(Ken_Room_Allotment__c allotment, WindowScope scope) {
        if (allotment == null) {
            return null;
        }
        if (allotment.Tenant_Account__c != null) {
            return getRelevantLearnerPrograms(new Set<Id>{ allotment.Tenant_Account__c }, scope).get(allotment.Tenant_Account__c);
        }
        if (allotment.Tenant__c != null) {
            return getRelevantLearnerProgramsByContact(new Set<Id>{ allotment.Tenant__c }, scope).get(allotment.Tenant__c);
        }
        return null;
    }

    private static Map<Id, LearnerProgram> getRelevantLearnerPrograms(Set<Id> accountIds, WindowScope scope) {
        Map<Id, LearnerProgram> learnerProgramByAccountId = new Map<Id, LearnerProgram>();
        if (accountIds == null || accountIds.isEmpty()) {
            return learnerProgramByAccountId;
        }

        Map<Id, List<LearnerProgram>> learnerProgramsByAccountId = getLearnerProgramsByAccountId(accountIds);
        for (Id accountId : learnerProgramsByAccountId.keySet()) {
            LearnerProgram learnerProgram = resolveRelevantLearnerProgram(scope, learnerProgramsByAccountId.get(accountId));
            if (learnerProgram != null) {
                learnerProgramByAccountId.put(accountId, learnerProgram);
            }
        }

        return learnerProgramByAccountId;
    }

    private static Map<Id, LearnerProgram> getRelevantLearnerProgramsByContact(Set<Id> contactIds, WindowScope scope) {
        Map<Id, LearnerProgram> learnerProgramByContactId = new Map<Id, LearnerProgram>();
        if (contactIds == null || contactIds.isEmpty()) {
            return learnerProgramByContactId;
        }

        Map<Id, List<LearnerProgram>> learnerProgramsByContactId = getLearnerProgramsByContactId(contactIds);
        for (Id contactId : learnerProgramsByContactId.keySet()) {
            LearnerProgram learnerProgram = resolveRelevantLearnerProgram(scope, learnerProgramsByContactId.get(contactId));
            if (learnerProgram != null) {
                learnerProgramByContactId.put(contactId, learnerProgram);
            }
        }

        return learnerProgramByContactId;
    }

    private static WindowAcademicYearScope getWindowAcademicYearScope(Id cycleId) {
        WindowAcademicYearScope scope = new WindowAcademicYearScope();
        if (cycleId == null) {
            return scope;
        }
        if (!Schema.sObjectType.Hostel_Cycle__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view hostel cycles.');
        }
        if (!Schema.sObjectType.Hostel_Cycle_Academic_Year__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view hostel cycle academic years.');
        }

        List<Hostel_Cycle__c> cycleRows = [
            SELECT Academic_Year__c, Academic_Years_Display__c
            FROM Hostel_Cycle__c
            WHERE Id = :cycleId
            LIMIT 1
        ];

        List<String> orderedLabels = new List<String>();
        Set<String> seenLabelKeys = new Set<String>();
        if (!cycleRows.isEmpty()) {
            for (String label : splitAcademicYearLabels(firstNonBlank(new List<String>{
                sanitize(cycleRows[0].Academic_Years_Display__c),
                sanitize(cycleRows[0].Academic_Year__c)
            }))) {
                String normalizedKey = normalizeAcademicYearKey(label);
                if (String.isBlank(normalizedKey) || seenLabelKeys.contains(normalizedKey)) {
                    continue;
                }
                orderedLabels.add(label);
                seenLabelKeys.add(normalizedKey);
            }
        }

        List<Hostel_Cycle_Academic_Year__c> rows = [
            SELECT Academic_Year__c, Academic_Year__r.Name
            FROM Hostel_Cycle_Academic_Year__c
            WHERE Hostel_Cycle__c = :cycleId
            ORDER BY Academic_Year__r.Name ASC NULLS LAST, CreatedDate ASC
        ];

        for (Hostel_Cycle_Academic_Year__c row : rows) {
            String label = row.Academic_Year__r != null ? sanitize(row.Academic_Year__r.Name) : '';
            String normalizedKey = normalizeAcademicYearKey(label);
            if (String.isNotBlank(normalizedKey) && !seenLabelKeys.contains(normalizedKey)) {
                orderedLabels.add(label);
                seenLabelKeys.add(normalizedKey);
            }
        }

        Integer totalLabels = orderedLabels.size();
        Integer labelIndex = 0;
        for (String label : orderedLabels) {
            String normalizedKey = normalizeAcademicYearKey(label);
            if (String.isBlank(normalizedKey)) {
                labelIndex += 1;
                continue;
            }
            scope.priorityByAcademicYearKey.put(normalizedKey, totalLabels - labelIndex);
            labelIndex += 1;
        }

        for (Hostel_Cycle_Academic_Year__c row : rows) {
            if (row.Academic_Year__c == null || scope.academicYearIds.contains(row.Academic_Year__c)) {
                continue;
            }
            String label = row.Academic_Year__r != null ? sanitize(row.Academic_Year__r.Name) : '';
            String normalizedKey = normalizeAcademicYearKey(label);
            Integer rank = String.isBlank(normalizedKey)
                ? null
                : scope.priorityByAcademicYearKey.get(normalizedKey);
            scope.academicYearIds.add(row.Academic_Year__c);
            scope.priorityByAcademicYearId.put(
                row.Academic_Year__c,
                rank == null ? deriveAcademicYearPriorityRank(label) : rank
            );
        }
        return scope;
    }

    private static Map<Id, LearnerAcademicYearInfo> getRelevantAcademicYearsByAccountId(
        Set<Id> accountIds,
        WindowAcademicYearScope academicYearScope
    ) {
        Map<Id, LearnerAcademicYearInfo> response = new Map<Id, LearnerAcademicYearInfo>();
        if (accountIds == null || accountIds.isEmpty()) {
            return response;
        }
        if (!Schema.sObjectType.AcademicTermEnrollment.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view academic term enrollments.');
        }

        Map<Id, List<AcademicTermEnrollment>> enrollmentsByAccountId = new Map<Id, List<AcademicTermEnrollment>>();
        for (AcademicTermEnrollment row : [
            SELECT
                Id,
                LearnerAccountId,
                AcademicTermId,
                AcademicTerm.AcademicYearId,
                AcademicTerm.AcademicYear.Name,
                AcademicTerm.StartDate,
                CreatedDate
            FROM AcademicTermEnrollment
            WHERE LearnerAccountId IN :accountIds
                AND AcademicTermId != null
            ORDER BY CreatedDate DESC
            LIMIT 5000
        ]) {
            if (row.LearnerAccountId == null) {
                continue;
            }
            if (!enrollmentsByAccountId.containsKey(row.LearnerAccountId)) {
                enrollmentsByAccountId.put(row.LearnerAccountId, new List<AcademicTermEnrollment>());
            }
            enrollmentsByAccountId.get(row.LearnerAccountId).add(row);
        }

        for (Id accountId : enrollmentsByAccountId.keySet()) {
            LearnerAcademicYearInfo info = resolveRelevantAcademicYearInfo(
                academicYearScope,
                enrollmentsByAccountId.get(accountId)
            );
            if (info != null) {
                response.put(accountId, info);
            }
        }
        return response;
    }

    private static Map<Id, LearnerAcademicYearInfo> getRelevantAcademicYearsByContactId(
        Set<Id> contactIds,
        WindowAcademicYearScope academicYearScope
    ) {
        Map<Id, LearnerAcademicYearInfo> response = new Map<Id, LearnerAcademicYearInfo>();
        if (contactIds == null || contactIds.isEmpty()) {
            return response;
        }
        if (!Schema.sObjectType.AcademicTermEnrollment.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view academic term enrollments.');
        }

        Map<Id, List<AcademicTermEnrollment>> enrollmentsByContactId = new Map<Id, List<AcademicTermEnrollment>>();
        for (AcademicTermEnrollment row : [
            SELECT
                Id,
                LearnerContactId,
                AcademicTermId,
                AcademicTerm.AcademicYearId,
                AcademicTerm.AcademicYear.Name,
                AcademicTerm.StartDate,
                CreatedDate
            FROM AcademicTermEnrollment
            WHERE LearnerContactId IN :contactIds
                AND AcademicTermId != null
            ORDER BY CreatedDate DESC
            LIMIT 5000
        ]) {
            if (row.LearnerContactId == null) {
                continue;
            }
            if (!enrollmentsByContactId.containsKey(row.LearnerContactId)) {
                enrollmentsByContactId.put(row.LearnerContactId, new List<AcademicTermEnrollment>());
            }
            enrollmentsByContactId.get(row.LearnerContactId).add(row);
        }

        for (Id contactId : enrollmentsByContactId.keySet()) {
            LearnerAcademicYearInfo info = resolveRelevantAcademicYearInfo(
                academicYearScope,
                enrollmentsByContactId.get(contactId)
            );
            if (info != null) {
                response.put(contactId, info);
            }
        }
        return response;
    }

    private static LearnerAcademicYearInfo resolveRelevantAcademicYearInfo(
        WindowAcademicYearScope academicYearScope,
        List<AcademicTermEnrollment> enrollments
    ) {
        if (enrollments == null || enrollments.isEmpty()) {
            return null;
        }

        LearnerAcademicYearInfo preferredScoped;
        LearnerAcademicYearInfo preferredOverall;
        for (AcademicTermEnrollment row : enrollments) {
            LearnerAcademicYearInfo candidate = toLearnerAcademicYearInfo(row, academicYearScope);
            if (candidate == null) {
                continue;
            }

            if (preferredOverall == null || isPreferredAcademicYearInfo(candidate, preferredOverall)) {
                preferredOverall = candidate;
            }
            if (
                academicYearScope != null &&
                isAcademicYearWithinScope(candidate, academicYearScope) &&
                (preferredScoped == null || isPreferredAcademicYearInfo(candidate, preferredScoped))
            ) {
                preferredScoped = candidate;
            }
        }

        return preferredScoped != null ? preferredScoped : preferredOverall;
    }

    private static LearnerAcademicYearInfo toLearnerAcademicYearInfo(
        AcademicTermEnrollment enrollment,
        WindowAcademicYearScope academicYearScope
    ) {
        if (enrollment == null || enrollment.AcademicTerm == null) {
            return null;
        }

        Id academicYearId = (Id) enrollment.AcademicTerm.get('AcademicYearId');
        String academicYearLabel = enrollment.AcademicTerm.AcademicYear != null
            ? sanitize((String) enrollment.AcademicTerm.AcademicYear.get('Name'))
            : '';
        if (academicYearId == null && String.isBlank(academicYearLabel)) {
            return null;
        }

        LearnerAcademicYearInfo response = new LearnerAcademicYearInfo();
        response.academicYearId = academicYearId;
        response.academicYearLabel = academicYearLabel;
        response.termStartDateTime = (Datetime) enrollment.AcademicTerm.get('StartDate');
        response.createdDateTime = enrollment.CreatedDate;

        if (
            academicYearId != null &&
            academicYearScope != null &&
            academicYearScope.priorityByAcademicYearId.containsKey(academicYearId)
        ) {
            response.priorityRank = academicYearScope.priorityByAcademicYearId.get(academicYearId);
        } else if (
            academicYearScope != null &&
            academicYearScope.priorityByAcademicYearKey.containsKey(normalizeAcademicYearKey(academicYearLabel))
        ) {
            response.priorityRank = academicYearScope.priorityByAcademicYearKey.get(normalizeAcademicYearKey(academicYearLabel));
        } else {
            response.priorityRank = deriveAcademicYearPriorityRank(academicYearLabel);
        }

        return response;
    }

    private static Boolean isAcademicYearWithinScope(
        LearnerAcademicYearInfo learnerAcademicYearInfo,
        WindowAcademicYearScope academicYearScope
    ) {
        if (learnerAcademicYearInfo == null || academicYearScope == null) {
            return false;
        }
        if (
            learnerAcademicYearInfo.academicYearId != null &&
            academicYearScope.academicYearIds.contains(learnerAcademicYearInfo.academicYearId)
        ) {
            return true;
        }
        String normalizedKey = normalizeAcademicYearKey(learnerAcademicYearInfo.academicYearLabel);
        return String.isNotBlank(normalizedKey) && academicYearScope.priorityByAcademicYearKey.containsKey(normalizedKey);
    }

    private static Boolean isPreferredAcademicYearInfo(
        LearnerAcademicYearInfo candidate,
        LearnerAcademicYearInfo current
    ) {
        Datetime candidateTermStart = candidate != null ? candidate.termStartDateTime : null;
        Datetime currentTermStart = current != null ? current.termStartDateTime : null;
        if (candidateTermStart != currentTermStart) {
            if (candidateTermStart == null) {
                return false;
            }
            if (currentTermStart == null) {
                return true;
            }
            return candidateTermStart.getTime() > currentTermStart.getTime();
        }

        Datetime candidateCreated = candidate != null ? candidate.createdDateTime : null;
        Datetime currentCreated = current != null ? current.createdDateTime : null;
        if (candidateCreated == currentCreated) {
            return false;
        }
        if (candidateCreated == null) {
            return false;
        }
        if (currentCreated == null) {
            return true;
        }
        return candidateCreated.getTime() > currentCreated.getTime();
    }

    private static Map<Id, List<LearnerProgram>> getLearnerProgramsByAccountId(Set<Id> accountIds) {
        Map<Id, List<LearnerProgram>> learnerProgramsByAccountId = new Map<Id, List<LearnerProgram>>();
        if (accountIds == null || accountIds.isEmpty()) {
            return learnerProgramsByAccountId;
        }
        if (!Schema.sObjectType.LearnerProgram.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view learner programs.');
        }

        for (LearnerProgram learnerProgram : [
            SELECT
                Id,
                Name,
                LearnerAccountId,
                Status,
                StartDate,
                LastModifiedDate,
                LearningProgramPlanId,
                LearningProgramPlan.Name,
                LearningProgramPlan.LearningProgramId
            FROM LearnerProgram
            WHERE LearnerAccountId IN :accountIds
            ORDER BY LastModifiedDate DESC
            LIMIT 2000
        ]) {
            if (learnerProgram.LearnerAccountId == null) {
                continue;
            }
            if (!learnerProgramsByAccountId.containsKey(learnerProgram.LearnerAccountId)) {
                learnerProgramsByAccountId.put(learnerProgram.LearnerAccountId, new List<LearnerProgram>());
            }
            learnerProgramsByAccountId.get(learnerProgram.LearnerAccountId).add(learnerProgram);
        }

        return learnerProgramsByAccountId;
    }

    private static Map<Id, List<LearnerProgram>> getLearnerProgramsByContactId(Set<Id> contactIds) {
        Map<Id, List<LearnerProgram>> learnerProgramsByContactId = new Map<Id, List<LearnerProgram>>();
        if (contactIds == null || contactIds.isEmpty()) {
            return learnerProgramsByContactId;
        }
        if (!Schema.sObjectType.LearnerProgram.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view learner programs.');
        }

        for (LearnerProgram learnerProgram : [
            SELECT
                Id,
                Name,
                LearnerContactId,
                Status,
                StartDate,
                LastModifiedDate,
                LearningProgramPlanId,
                LearningProgramPlan.Name,
                LearningProgramPlan.LearningProgramId
            FROM LearnerProgram
            WHERE LearnerContactId IN :contactIds
            ORDER BY LastModifiedDate DESC
            LIMIT 2000
        ]) {
            if (learnerProgram.LearnerContactId == null) {
                continue;
            }
            if (!learnerProgramsByContactId.containsKey(learnerProgram.LearnerContactId)) {
                learnerProgramsByContactId.put(learnerProgram.LearnerContactId, new List<LearnerProgram>());
            }
            learnerProgramsByContactId.get(learnerProgram.LearnerContactId).add(learnerProgram);
        }

        return learnerProgramsByContactId;
    }

    private static LearnerProgram resolveRelevantLearnerProgram(WindowScope scope, List<LearnerProgram> learnerPrograms) {
        if (learnerPrograms == null || learnerPrograms.isEmpty()) {
            return null;
        }

        LearnerProgram preferredOverall;
        LearnerProgram preferredScoped;
        for (LearnerProgram learnerProgram : learnerPrograms) {
            if (preferredOverall == null || isPreferredLearnerProgram(learnerProgram, preferredOverall)) {
                preferredOverall = learnerProgram;
            }
            if (matchesWindowProgramScope(scope, learnerProgram) &&
                (preferredScoped == null || isPreferredLearnerProgram(learnerProgram, preferredScoped))) {
                preferredScoped = learnerProgram;
            }
        }

        if (preferredScoped != null) {
            return preferredScoped;
        }
        if (hasWindowProgramScope(scope)) {
            return null;
        }
        return preferredOverall;
    }

    private static Map<Id, LearnerProgram> getPreferredLearnerPrograms(Set<Id> accountIds) {
        Map<Id, LearnerProgram> learnerProgramByAccountId = new Map<Id, LearnerProgram>();
        if (accountIds.isEmpty()) {
            return learnerProgramByAccountId;
        }
        if (!Schema.sObjectType.LearnerProgram.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view learner programs.');
        }

        for (LearnerProgram learnerProgram : [
            SELECT
                Id,
                Name,
                LearnerAccountId,
                Status,
                StartDate,
                LastModifiedDate,
                LearningProgramPlanId,
                LearningProgramPlan.Name,
                LearningProgramPlan.LearningProgramId
            FROM LearnerProgram
            WHERE LearnerAccountId IN :accountIds
            ORDER BY LastModifiedDate DESC
            LIMIT 2000
        ]) {
            if (learnerProgram.LearnerAccountId == null) {
                continue;
            }

            LearnerProgram existingProgram = learnerProgramByAccountId.get(learnerProgram.LearnerAccountId);
            if (existingProgram == null || isPreferredLearnerProgram(learnerProgram, existingProgram)) {
                learnerProgramByAccountId.put(learnerProgram.LearnerAccountId, learnerProgram);
            }
        }

        return learnerProgramByAccountId;
    }

    private static String resolveLearnerProgramLabel(LearnerProgram learnerProgram) {
        return firstNonBlank(new List<String>{
            learnerProgram != null && learnerProgram.LearningProgramPlan != null
                ? sanitize(learnerProgram.LearningProgramPlan.Name)
                : null,
            learnerProgram != null ? sanitize(learnerProgram.Name) : null
        });
    }

    private static Boolean isPreferredLearnerProgram(LearnerProgram candidate, LearnerProgram current) {
        Boolean candidateActive = candidate != null && sanitize(candidate.Status).equalsIgnoreCase('Active');
        Boolean currentActive = current != null && sanitize(current.Status).equalsIgnoreCase('Active');
        if (candidateActive != currentActive) {
            return candidateActive;
        }

        Date candidateStartDate = candidate != null ? candidate.StartDate : null;
        Date currentStartDate = current != null ? current.StartDate : null;
        if (candidateStartDate != currentStartDate) {
            if (candidateStartDate == null) {
                return false;
            }
            if (currentStartDate == null) {
                return true;
            }
            return candidateStartDate > currentStartDate;
        }

        Datetime candidateModified = candidate != null ? candidate.LastModifiedDate : null;
        Datetime currentModified = current != null ? current.LastModifiedDate : null;
        if (candidateModified == currentModified) {
            return false;
        }
        if (candidateModified == null) {
            return false;
        }
        if (currentModified == null) {
            return true;
        }
        return candidateModified.getTime() > currentModified.getTime();
    }

    private static Date resolveWindowAllotmentStartDate(Ken_Windows__c windowRecord, Ken_Room_Allotment__c allotment) {
        if (windowRecord != null) {
            if (windowRecord.Room_Allotment_Start_Date__c != null) {
                return windowRecord.Room_Allotment_Start_Date__c;
            }
            if (windowRecord.Start_Date__c != null) {
                return windowRecord.Start_Date__c;
            }
        }

        if (allotment != null && allotment.Active__c == true && allotment.Start_Date__c != null) {
            return allotment.Start_Date__c;
        }
        return Date.today();
    }

    private static Date resolveWindowAllotmentEndDate(Ken_Windows__c windowRecord, Ken_Room_Allotment__c allotment) {
        if (windowRecord != null) {
            if (windowRecord.Room_Allotment_End_Date__c != null) {
                return windowRecord.Room_Allotment_End_Date__c;
            }
            if (windowRecord.End_Date__c != null) {
                return windowRecord.End_Date__c;
            }
        }

        if (allotment != null && allotment.Active__c == true) {
            return allotment.End_Date__c;
        }
        return null;
    }

    private static String deriveLearnerYearLabel(LearnerProgram learnerProgram) {
        if (learnerProgram == null || learnerProgram.StartDate == null) {
            return '';
        }

        Date today = System.today();
        Integer completedYears = today.year() - learnerProgram.StartDate.year();
        if (
            today.month() < learnerProgram.StartDate.month()
            || (today.month() == learnerProgram.StartDate.month() && today.day() < learnerProgram.StartDate.day())
        ) {
            completedYears -= 1;
        }

        Integer currentYear = Math.max(1, completedYears + 1);
        return 'Year ' + String.valueOf(currentYear);
    }

    private static Integer deriveLearnerYearPriorityRank(LearnerProgram learnerProgram) {
        String yearLabel = deriveLearnerYearLabel(learnerProgram);
        if (String.isBlank(yearLabel)) {
            return 0;
        }

        Matcher matcher = Pattern.compile('(\\d+)').matcher(yearLabel);
        if (!matcher.find()) {
            return 0;
        }

        Integer yearValue;
        try {
            yearValue = Integer.valueOf(matcher.group(1));
        } catch (Exception e) {
            return 0;
        }
        return yearValue == null || yearValue < 0 ? 0 : yearValue;
    }

    private static Integer deriveAcademicYearPriorityRank(String academicYearLabel) {
        String normalizedLabel = sanitize(academicYearLabel);
        if (String.isBlank(normalizedLabel)) {
            return 0;
        }

        Matcher matcher = Pattern.compile('(\\d{4})').matcher(normalizedLabel);
        if (!matcher.find()) {
            return 0;
        }

        Integer startYear;
        try {
            startYear = Integer.valueOf(matcher.group(1));
        } catch (Exception e) {
            return 0;
        }
        if (startYear == null) {
            return 0;
        }
        return Math.max(0, 9999 - startYear);
    }

    private static List<String> splitAcademicYearLabels(String rawValue) {
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

    private static String normalizeAutoAllotmentRule(String value) {
        String normalizedValue = sanitize(value);
        if (normalizedValue == 'programPriority' || normalizedValue == 'yearPriority') {
            return normalizedValue;
        }
        return 'firstComeFirstServe';
    }

    private static String normalizeAutoAllotmentBatchGrouping(String value) {
        String normalizedValue = sanitize(value);
        if (normalizedValue == 'year' || normalizedValue == 'category') {
            return normalizedValue;
        }
        return 'program';
    }

    private static Integer normalizeAutoAllotmentBatchSize(Integer value) {
        if (value == null || value <= 0) {
            return DEFAULT_AUTO_ALLOTMENT_BATCH_SIZE;
        }
        return value;
    }

    private static String normalizeAllotmentTypeDisplay(String value) {
        String normalizedValue = sanitize(value);
        String normalizedKey = normalizedValue.toLowerCase();

        if (normalizedKey == 'none' || normalizedKey == 'direct' || normalizedKey == 'direct allotment') {
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

    private static String normalizeAssignmentAllotmentType(String value) {
        String normalizedType = normalizeAllotmentTypeDisplay(value);
        if (normalizedType == 'Confirmed Allotment') {
            return 'Confirmed Allotment';
        }
        if (normalizedType == 'Provisional Allotment') {
            return 'Provisional Allotment';
        }
        return 'Direct Allotment';
    }

    private static String normalizeInProgressAllotmentType(String windowTypeValue, String fallbackTypeValue) {
        String normalizedWindowType = normalizeAllotmentTypeDisplay(windowTypeValue);
        if (normalizedWindowType == 'Preference Selected') {
            return 'Preference Selected';
        }
        if (normalizedWindowType == 'Provisional Allotment') {
            return 'Provisional Allotment';
        }

        String normalizedFallbackType = normalizeAllotmentTypeDisplay(fallbackTypeValue);
        if (normalizedFallbackType == 'Preference Selected') {
            return 'Preference Selected';
        }
        if (normalizedFallbackType == 'Provisional Allotment') {
            return 'Provisional Allotment';
        }
        return 'Provisional Allotment';
    }

    private static String getWindowAllotmentType(Id windowId) {
        if (windowId == null) {
            return '';
        }
        if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view residence windows.');
        }
        List<Ken_Windows__c> windowRecords = [
            SELECT Allotment_Type__c
            FROM Ken_Windows__c
            WHERE Id = :windowId
            LIMIT 1
        ];
        if (windowRecords.isEmpty()) {
            return '';
        }
        return normalizeAllotmentTypeDisplay(windowRecords[0].Allotment_Type__c);
    }

    private static String firstNonBlank(List<String> values) {
        if (values == null) {
            return '';
        }
        for (String value : values) {
            if (String.isNotBlank(value)) {
                return value.trim();
            }
        }
        return '';
    }

    private static Id normalizeId(String value, String errorMessage) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return (Id) value;
        } catch (Exception ex) {
            throw new AuraHandledException(errorMessage);
        }
    }

    private static String formatDate(Date value) {
        return value == null ? '' : String.valueOf(value);
    }

    private static String formatDateTimeToDate(Datetime value) {
        return value == null ? '' : String.valueOf(value.date());
    }

    private static String sanitize(String value) {
        return value == null ? '' : value.trim();
    }
}