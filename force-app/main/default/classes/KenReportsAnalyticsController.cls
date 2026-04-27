public with sharing class KenReportsAnalyticsController {
    public class CycleOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String status { get; set; }
    }

    public class WindowOption {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String allotmentType { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String startDate { get; set; }
        @AuraEnabled public String endDate { get; set; }
    }

    public class ReportSummaryResponse {
        @AuraEnabled public Integer totalRegistered { get; set; }
        @AuraEnabled public Integer totalAllocations { get; set; }
        @AuraEnabled public Decimal occupancyRate { get; set; }
        @AuraEnabled public Integer pendingApplications { get; set; }
        @AuraEnabled public Integer totalCapacity { get; set; }
        @AuraEnabled public Integer occupiedBeds { get; set; }
        @AuraEnabled public Decimal totalAmountCollected { get; set; }
        @AuraEnabled public Decimal pendingAmount { get; set; }
        @AuraEnabled public List<CategoryRegistrationItem> categoryRegistrations { get; set; }
        @AuraEnabled public List<CategoryOccupancyItem> categoryOccupancy { get; set; }
        @AuraEnabled public List<BuildingOccupancyItem> buildingOccupancy { get; set; }
        @AuraEnabled public List<AllotmentDistributionItem> allotmentDistribution { get; set; }
        @AuraEnabled public List<MonthlyTrendItem> monthlyAllocationTrend { get; set; }
        @AuraEnabled public List<AllotmentPerformanceItem> allotmentPerformanceSummary { get; set; }

        public ReportSummaryResponse() {
            totalRegistered = 0;
            totalAllocations = 0;
            occupancyRate = 0;
            pendingApplications = 0;
            totalCapacity = 0;
            occupiedBeds = 0;
            totalAmountCollected = 0;
            pendingAmount = 0;
            categoryRegistrations = new List<CategoryRegistrationItem>();
            categoryOccupancy = new List<CategoryOccupancyItem>();
            buildingOccupancy = new List<BuildingOccupancyItem>();
            allotmentDistribution = new List<AllotmentDistributionItem>();
            monthlyAllocationTrend = new List<MonthlyTrendItem>();
            allotmentPerformanceSummary = new List<AllotmentPerformanceItem>();
        }
    }

    public class CategoryRegistrationItem {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Integer registeredCount { get; set; }
        @AuraEnabled public Integer allottedCount { get; set; }
        @AuraEnabled public Integer allotmentPercentage { get; set; }

        public CategoryRegistrationItem() {
            label = '';
            registeredCount = 0;
            allottedCount = 0;
            allotmentPercentage = 0;
        }
    }

    public class CategoryOccupancyItem {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Integer occupiedBeds { get; set; }
        @AuraEnabled public Integer totalCapacity { get; set; }
        @AuraEnabled public Integer occupancyPercentage { get; set; }

        public CategoryOccupancyItem() {
            label = '';
            occupiedBeds = 0;
            totalCapacity = 0;
            occupancyPercentage = 0;
        }
    }

    public class BuildingOccupancyItem {
        @AuraEnabled public String buildingId { get; set; }
        @AuraEnabled public String buildingName { get; set; }
        @AuraEnabled public Integer occupiedBeds { get; set; }
        @AuraEnabled public Integer availableBeds { get; set; }
        @AuraEnabled public Integer totalCapacity { get; set; }
        @AuraEnabled public Integer occupiedPercentage { get; set; }
        @AuraEnabled public Integer availablePercentage { get; set; }

        public BuildingOccupancyItem() {
            buildingId = '';
            buildingName = '';
            occupiedBeds = 0;
            availableBeds = 0;
            totalCapacity = 0;
            occupiedPercentage = 0;
            availablePercentage = 0;
        }
    }

    public class AllotmentDistributionItem {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Integer count { get; set; }

        public AllotmentDistributionItem() {
            label = '';
            count = 0;
        }
    }

    public class MonthlyTrendItem {
        @AuraEnabled public String monthKey { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Integer directCount { get; set; }
        @AuraEnabled public Integer provisionalCount { get; set; }
        @AuraEnabled public Integer reassignmentCount { get; set; }

        public MonthlyTrendItem() {
            monthKey = '';
            label = '';
            directCount = 0;
            provisionalCount = 0;
            reassignmentCount = 0;
        }
    }

    public class AllotmentPerformanceItem {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Integer totalApplications { get; set; }
        @AuraEnabled public Integer assignedCount { get; set; }
        @AuraEnabled public Integer rejectedCount { get; set; }
        @AuraEnabled public Integer pendingCount { get; set; }
        @AuraEnabled public String avgAllocationTime { get; set; }
        @AuraEnabled public String trend { get; set; }
        @AuraEnabled public Boolean isTotal { get; set; }

        public AllotmentPerformanceItem() {
            label = '';
            totalApplications = 0;
            assignedCount = 0;
            rejectedCount = 0;
            pendingCount = 0;
            avgAllocationTime = '';
            trend = '';
            isTotal = false;
        }
    }

    private class RoomScope {
        public Set<Id> buildingIds = new Set<Id>();
        public Set<Id> roomCategoryIds = new Set<Id>();
    }

    @AuraEnabled(cacheable=true)
    public static List<CycleOption> getCycleOptions() {
        List<CycleOption> response = new List<CycleOption>();
        for (KenAdminDashboardController.CycleOption source : KenAdminDashboardController.getCycleOptions()) {
            CycleOption option = new CycleOption();
            option.label = sanitize(source != null ? source.label : null);
            option.value = sanitize(source != null ? source.value : null);
            option.name = sanitize(source != null ? source.name : null);
            option.status = sanitize(source != null ? source.status : null);
            response.add(option);
        }
        return response;
    }

    @AuraEnabled(cacheable=true)
    public static List<WindowOption> getWindowOptions(String cycleId) {
        List<WindowOption> response = new List<WindowOption>();
        for (KenAdminDashboardController.WindowOption source : KenAdminDashboardController.getWindowOptions(cycleId)) {
            WindowOption option = new WindowOption();
            option.id = sanitize(source != null ? source.id : null);
            option.label = sanitize(source != null ? source.label : null);
            option.name = sanitize(source != null ? source.name : null);
            option.allotmentType = sanitize(source != null ? source.allotmentType : null);
            option.status = sanitize(source != null ? source.status : null);
            option.startDate = sanitize(source != null ? source.startDate : null);
            option.endDate = sanitize(source != null ? source.endDate : null);
            response.add(option);
        }
        return response;
    }

    @AuraEnabled
    public static ReportSummaryResponse getReportData(String windowId) {
        Id windowRecordId = normalizeId(windowId, 'Invalid window.');
        ReportSummaryResponse response = new ReportSummaryResponse();
        if (windowRecordId == null) {
            return response;
        }

        KenAdminDashboardController.DashboardSummaryResponse dashboardSummary =
            KenAdminDashboardController.getDashboardSummary(String.valueOf(windowRecordId));
        response.totalRegistered = dashboardSummary.totalRegistered;
        response.totalAllocations = dashboardSummary.totalAllocations;
        response.occupancyRate = dashboardSummary.occupancyRate;
        response.totalCapacity = dashboardSummary.totalCapacity;
        response.occupiedBeds = dashboardSummary.occupiedBeds;
        response.totalAmountCollected = dashboardSummary.totalAmountCollected;
        response.pendingAmount = dashboardSummary.pendingAmount;
        response.categoryRegistrations = cloneCategoryRegistrations(dashboardSummary.categoryRegistrations);
        response.categoryOccupancy = cloneCategoryOccupancy(dashboardSummary.categoryOccupancy);

        response.pendingApplications = countPendingApplications(
            KenAccommodationManagementController.getInProgressRows(String.valueOf(windowRecordId))
        );
        response.buildingOccupancy = buildBuildingOccupancy(windowRecordId);
        response.allotmentDistribution = buildAllotmentDistribution(
            KenAccommodationManagementController.getAllocatedRows(String.valueOf(windowRecordId))
        );
        response.monthlyAllocationTrend = buildMonthlyAllocationTrend(windowRecordId);
        response.allotmentPerformanceSummary = buildAllotmentPerformanceSummary(windowRecordId);
        return response;
    }

    private static Integer countPendingApplications(
        List<KenAccommodationManagementController.InProgressRow> inProgressRows
    ) {
        Integer pendingCount = 0;
        for (KenAccommodationManagementController.InProgressRow row : inProgressRows) {
            if (isPendingStatus(row != null ? row.status : null)) {
                pendingCount += 1;
            }
        }
        return pendingCount;
    }

    private static List<CategoryRegistrationItem> cloneCategoryRegistrations(
        List<KenAdminDashboardController.CategoryRegistrationItem> sourceRows
    ) {
        List<CategoryRegistrationItem> response = new List<CategoryRegistrationItem>();
        if (sourceRows == null) {
            return response;
        }
        for (KenAdminDashboardController.CategoryRegistrationItem sourceRow : sourceRows) {
            CategoryRegistrationItem item = new CategoryRegistrationItem();
            item.label = sanitize(sourceRow != null ? sourceRow.label : null);
            item.registeredCount = sourceRow != null ? sourceRow.registeredCount : 0;
            item.allottedCount = sourceRow != null ? sourceRow.allottedCount : 0;
            item.allotmentPercentage = sourceRow != null ? sourceRow.allotmentPercentage : 0;
            response.add(item);
        }
        return response;
    }

    private static List<CategoryOccupancyItem> cloneCategoryOccupancy(
        List<KenAdminDashboardController.CategoryOccupancyItem> sourceRows
    ) {
        List<CategoryOccupancyItem> response = new List<CategoryOccupancyItem>();
        if (sourceRows == null) {
            return response;
        }
        for (KenAdminDashboardController.CategoryOccupancyItem sourceRow : sourceRows) {
            CategoryOccupancyItem item = new CategoryOccupancyItem();
            item.label = sanitize(sourceRow != null ? sourceRow.label : null);
            item.occupiedBeds = sourceRow != null ? sourceRow.occupiedBeds : 0;
            item.totalCapacity = sourceRow != null ? sourceRow.totalCapacity : 0;
            item.occupancyPercentage = sourceRow != null ? sourceRow.occupancyPercentage : 0;
            response.add(item);
        }
        return response;
    }

    private static Boolean isPendingStatus(String statusValue) {
        String normalizedStatus = sanitize(statusValue).toLowerCase();
        if (String.isBlank(normalizedStatus)) {
            return true;
        }
        if (normalizedStatus == 'approved' ||
            normalizedStatus == 'provisional alloted' ||
            normalizedStatus == 'alloted' ||
            normalizedStatus == 'allocated'
        ) {
            return false;
        }
        if (normalizedStatus == 'canceled' ||
            normalizedStatus == 'cancelled' ||
            normalizedStatus == 'rejected' ||
            normalizedStatus == 'completed' ||
            normalizedStatus == 'stay completed'
        ) {
            return false;
        }
        return true;
    }

    private static List<AllotmentDistributionItem> buildAllotmentDistribution(
        List<KenAccommodationManagementController.AllocatedRow> allocatedRows
    ) {
        Map<String, Integer> countByLabel = new Map<String, Integer>();
        for (KenAccommodationManagementController.AllocatedRow row : allocatedRows) {
            String label = resolveDistributionLabel(row != null ? row.allotmentType : null);
            countByLabel.put(label, (countByLabel.containsKey(label) ? countByLabel.get(label) : 0) + 1);
        }

        List<String> orderedLabels = new List<String>();
        for (String preferredLabel : new List<String>{ 'Direct', 'Provisional', 'Other' }) {
            if (countByLabel.containsKey(preferredLabel)) {
                orderedLabels.add(preferredLabel);
            }
        }

        List<AllotmentDistributionItem> response = new List<AllotmentDistributionItem>();
        for (String label : orderedLabels) {
            AllotmentDistributionItem item = new AllotmentDistributionItem();
            item.label = label;
            item.count = countByLabel.get(label);
            response.add(item);
        }
        return response;
    }

    private static String resolveDistributionLabel(String allotmentType) {
        String normalizedKey = normalizeKey(allotmentType);
        if (String.isBlank(normalizedKey)) {
            return 'Other';
        }
        if (normalizedKey.contains('provisional') || normalizedKey.contains('preference')) {
            return 'Provisional';
        }
        if (normalizedKey.contains('direct') || normalizedKey.contains('confirm')) {
            return 'Direct';
        }
        return 'Other';
    }

    private static List<BuildingOccupancyItem> buildBuildingOccupancy(Id windowId) {
        if (windowId == null) {
            return new List<BuildingOccupancyItem>();
        }
        if (!Schema.sObjectType.Ken_Room__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view rooms.');
        }

        RoomScope scope = getRoomScope(windowId);
        Map<Id, BuildingOccupancyItem> buildingItemById = new Map<Id, BuildingOccupancyItem>();
        List<Id> buildingOrder = new List<Id>();

        for (Ken_Room__c room : [
            SELECT
                Building__c,
                Building__r.Name,
                Building__r.Name__c,
                Room_Category__c,
                Capacity__c,
                Occupancy_Status__c,
                Name,
                Room_Number__c
            FROM Ken_Room__c
            WHERE Building__c != null
            ORDER BY Building__r.Name__c ASC NULLS LAST, Building__r.Name ASC NULLS LAST, Name ASC NULLS LAST, Room_Number__c ASC NULLS LAST
            LIMIT 5000
        ]) {
            if (!matchesRoomScope(scope, room.Building__c, room.Room_Category__c)) {
                continue;
            }

            Integer capacity = room.Capacity__c == null ? 0 : Integer.valueOf(room.Capacity__c);
            if (capacity < 0) {
                capacity = 0;
            }
            Integer occupancy = room.Occupancy_Status__c == null ? 0 : Integer.valueOf(room.Occupancy_Status__c);
            if (occupancy < 0) {
                occupancy = 0;
            }
            Integer occupiedBeds = occupancy > capacity ? capacity : occupancy;

            if (!buildingItemById.containsKey(room.Building__c)) {
                BuildingOccupancyItem item = new BuildingOccupancyItem();
                item.buildingId = String.valueOf(room.Building__c);
                item.buildingName = firstNonBlank(new List<String>{
                    room.Building__r != null ? sanitize(room.Building__r.Name__c) : null,
                    room.Building__r != null ? sanitize(room.Building__r.Name) : null,
                    'Unassigned'
                });
                buildingItemById.put(room.Building__c, item);
                buildingOrder.add(room.Building__c);
            }

            BuildingOccupancyItem currentItem = buildingItemById.get(room.Building__c);
            currentItem.totalCapacity += capacity;
            currentItem.occupiedBeds += occupiedBeds;
        }

        List<BuildingOccupancyItem> response = new List<BuildingOccupancyItem>();
        for (Id buildingId : buildingOrder) {
            BuildingOccupancyItem item = buildingItemById.get(buildingId);
            if (item == null || item.totalCapacity <= 0) {
                continue;
            }

            item.availableBeds = Math.max(item.totalCapacity - item.occupiedBeds, 0);
            Decimal occupiedPercentage = (Decimal.valueOf(item.occupiedBeds) * 100) / Decimal.valueOf(item.totalCapacity);
            item.occupiedPercentage = occupiedPercentage.setScale(0, RoundingMode.HALF_UP).intValue();
            item.availablePercentage = Math.max(100 - item.occupiedPercentage, 0);
            response.add(item);
        }
        return response;
    }

    private static List<MonthlyTrendItem> buildMonthlyAllocationTrend(Id windowId) {
        if (windowId == null) {
            return new List<MonthlyTrendItem>();
        }
        if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view residence windows.');
        }
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room allotments.');
        }

        Ken_Windows__c windowRecord = [
            SELECT
                Id,
                Start_Date__c,
                End_Date__c,
                Hostel_Cycle__c,
                Hostel_Cycle__r.Cycle_Start_Date_Time__c,
                Hostel_Cycle__r.Cycle_End_Date_Time__c
            FROM Ken_Windows__c
            WHERE Id = :windowId
            LIMIT 1
        ];

        RoomScope scope = getRoomScope(windowId);
        List<Ken_Room_Allotment__c> scopedAllotments = new List<Ken_Room_Allotment__c>();
        Date earliestActivityMonth;
        Date latestActivityMonth;

        for (Ken_Room_Allotment__c allotment : [
            SELECT
                Id,
                Allotment_Type__c,
                CreatedDate,
                Active__c,
                Room__r.Building__c,
                Room__r.Room_Category__c
            FROM Ken_Room_Allotment__c
            WHERE Window__c = :windowId
                AND Active__c = true
                AND Room__c != null
            ORDER BY CreatedDate ASC
            LIMIT 5000
        ]) {
            Id buildingId = allotment.Room__r != null ? allotment.Room__r.Building__c : null;
            Id roomCategoryId = allotment.Room__r != null ? allotment.Room__r.Room_Category__c : null;
            if (!matchesRoomScope(scope, buildingId, roomCategoryId)) {
                continue;
            }

            scopedAllotments.add(allotment);
            Date activityMonth = firstOfMonth(allotment.CreatedDate != null ? allotment.CreatedDate.date() : null);
            if (activityMonth == null) {
                continue;
            }
            if (earliestActivityMonth == null || activityMonth < earliestActivityMonth) {
                earliestActivityMonth = activityMonth;
            }
            if (latestActivityMonth == null || activityMonth > latestActivityMonth) {
                latestActivityMonth = activityMonth;
            }
        }

        Map<Id, Boolean> reassignedById = getReassignedFlagsByAllotmentId(new Map<Id, Ken_Room_Allotment__c>(scopedAllotments).keySet());

        Date rangeStartMonth = resolveTrendStartMonth(windowRecord, earliestActivityMonth, latestActivityMonth);
        Date rangeEndMonth = resolveTrendEndMonth(windowRecord, rangeStartMonth, latestActivityMonth);
        Integer monthSpan = getMonthSpan(rangeStartMonth, rangeEndMonth);
        if (monthSpan > 12) {
            rangeStartMonth = firstOfMonth(rangeEndMonth.addMonths(-11));
        }

        List<MonthlyTrendItem> response = new List<MonthlyTrendItem>();
        Map<String, MonthlyTrendItem> itemByKey = new Map<String, MonthlyTrendItem>();
        Date monthCursor = rangeStartMonth;
        while (monthCursor != null && monthCursor <= rangeEndMonth) {
            MonthlyTrendItem item = new MonthlyTrendItem();
            item.monthKey = toMonthKey(monthCursor);
            item.label = formatMonthLabel(monthCursor);
            response.add(item);
            itemByKey.put(item.monthKey, item);
            monthCursor = monthCursor.addMonths(1);
        }

        for (Ken_Room_Allotment__c allotment : scopedAllotments) {
            Date activityMonth = firstOfMonth(allotment.CreatedDate != null ? allotment.CreatedDate.date() : null);
            String monthKey = toMonthKey(activityMonth);
            if (String.isBlank(monthKey) || !itemByKey.containsKey(monthKey)) {
                continue;
            }

            MonthlyTrendItem item = itemByKey.get(monthKey);
            String distributionLabel = resolveDistributionLabel(allotment.Allotment_Type__c);
            if (distributionLabel == 'Direct') {
                item.directCount += 1;
            } else if (distributionLabel == 'Provisional') {
                item.provisionalCount += 1;
            }

            if (reassignedById.containsKey(allotment.Id) && reassignedById.get(allotment.Id) == true) {
                item.reassignmentCount += 1;
            }
        }

        return response;
    }

    private static List<AllotmentPerformanceItem> buildAllotmentPerformanceSummary(Id windowId) {
        Map<String, AllotmentPerformanceItem> itemByLabel = initializePerformanceSummaryItems();
        if (windowId == null) {
            return new List<AllotmentPerformanceItem>();
        }
        if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view residence windows.');
        }
        if (!Schema.sObjectType.Ken_Room_Request__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room requests.');
        }

        Ken_Windows__c windowRecord = [
            SELECT Id, Start_Date__c, End_Date__c, Allotment_Type__c
            FROM Ken_Windows__c
            WHERE Id = :windowId
            LIMIT 1
        ];

        List<Ken_Room_Request__c> requestRows = [
            SELECT
                Id,
                Status__c,
                Window__c,
                Window__r.Allotment_Type__c,
                Room_Allotment__c,
                Room_Allotment__r.Allotment_Type__c,
                CreatedDate
            FROM Ken_Room_Request__c
            WHERE Window__c = :windowId
                OR Window__c = null
            ORDER BY CreatedDate DESC
            LIMIT 5000
        ];

        Set<Id> linkedAllotmentIds = new Set<Id>();
        for (Ken_Room_Request__c requestRow : requestRows) {
            if (requestRow.Room_Allotment__c != null) {
                linkedAllotmentIds.add(requestRow.Room_Allotment__c);
            }
        }
        Map<Id, Boolean> reassignedByAllotmentId = getReassignedFlagsByAllotmentId(linkedAllotmentIds);

        for (Ken_Room_Request__c requestRow : requestRows) {
            if (requestRow.Window__c == null && !isReportRequestWithinWindowDates(requestRow, windowRecord)) {
                continue;
            }

            String statusValue = sanitize(requestRow.Status__c);
            if (shouldIgnorePerformanceStatus(statusValue)) {
                continue;
            }

            String performanceLabel = resolvePerformanceSummaryLabel(
                requestRow.Room_Allotment__r != null ? requestRow.Room_Allotment__r.Allotment_Type__c : null,
                requestRow.Room_Allotment__c != null
                    && reassignedByAllotmentId.containsKey(requestRow.Room_Allotment__c)
                    && reassignedByAllotmentId.get(requestRow.Room_Allotment__c) == true,
                firstNonBlank(new List<String>{
                    requestRow.Window__r != null ? requestRow.Window__r.Allotment_Type__c : null,
                    windowRecord.Allotment_Type__c
                })
            );
            if (String.isBlank(performanceLabel) || !itemByLabel.containsKey(performanceLabel)) {
                continue;
            }

            AllotmentPerformanceItem item = itemByLabel.get(performanceLabel);
            if (isAssignedRequestStatus(statusValue)) {
                item.assignedCount += 1;
            } else if (isRejectedRequestStatus(statusValue)) {
                item.rejectedCount += 1;
            } else if (isPendingStatus(statusValue)) {
                item.pendingCount += 1;
            } else {
                continue;
            }
            item.totalApplications = item.assignedCount + item.rejectedCount + item.pendingCount;
        }

        List<AllotmentPerformanceItem> response = new List<AllotmentPerformanceItem>();
        Integer totalApplications = 0;
        Integer totalAssigned = 0;
        Integer totalRejected = 0;
        Integer totalPending = 0;

        for (String label : new List<String>{ 'Direct', 'Provisional', 'Reassignment' }) {
            AllotmentPerformanceItem item = itemByLabel.get(label);
            response.add(item);
            totalApplications += item.totalApplications;
            totalAssigned += item.assignedCount;
            totalRejected += item.rejectedCount;
            totalPending += item.pendingCount;
        }

        AllotmentPerformanceItem totalItem = new AllotmentPerformanceItem();
        totalItem.label = 'Total';
        totalItem.totalApplications = totalApplications;
        totalItem.assignedCount = totalAssigned;
        totalItem.rejectedCount = totalRejected;
        totalItem.pendingCount = totalPending;
        totalItem.isTotal = true;
        response.add(totalItem);
        return response;
    }

    private static Map<String, AllotmentPerformanceItem> initializePerformanceSummaryItems() {
        Map<String, AllotmentPerformanceItem> response = new Map<String, AllotmentPerformanceItem>();
        for (String label : new List<String>{ 'Direct', 'Provisional', 'Reassignment' }) {
            AllotmentPerformanceItem item = new AllotmentPerformanceItem();
            item.label = label;
            response.put(label, item);
        }
        return response;
    }

    private static String resolvePerformanceSummaryLabel(
        String allotmentType,
        Boolean isReassigned,
        String fallbackType
    ) {
        if (isReassigned == true) {
            return 'Reassignment';
        }

        String resolvedLabel = resolveDistributionLabel(firstNonBlank(new List<String>{
            allotmentType,
            fallbackType
        }));
        if (resolvedLabel == 'Direct') {
            return 'Direct';
        }
        if (resolvedLabel == 'Provisional') {
            return 'Provisional';
        }

        String fallbackLabel = resolveDistributionLabel(fallbackType);
        if (fallbackLabel == 'Direct') {
            return 'Direct';
        }
        return 'Provisional';
    }

    private static Boolean shouldIgnorePerformanceStatus(String statusValue) {
        String normalizedStatus = sanitize(statusValue).toLowerCase();
        return normalizedStatus == 'canceled'
            || normalizedStatus == 'cancelled'
            || normalizedStatus == 'completed'
            || normalizedStatus == 'stay completed';
    }

    private static Boolean isAssignedRequestStatus(String statusValue) {
        String normalizedStatus = sanitize(statusValue).toLowerCase();
        return normalizedStatus == 'alloted'
            || normalizedStatus == 'allocated'
            || normalizedStatus == 'provisional alloted';
    }

    private static Boolean isRejectedRequestStatus(String statusValue) {
        return sanitize(statusValue).equalsIgnoreCase('Rejected');
    }

    private static Boolean isReportRequestWithinWindowDates(Ken_Room_Request__c requestRow, Ken_Windows__c windowRecord) {
        if (requestRow == null || requestRow.CreatedDate == null || windowRecord == null) {
            return true;
        }

        Date requestDate = requestRow.CreatedDate.date();
        Boolean startOk = windowRecord.Start_Date__c == null || requestDate >= windowRecord.Start_Date__c;
        Boolean endOk = windowRecord.End_Date__c == null || requestDate <= windowRecord.End_Date__c;
        return startOk && endOk;
    }

    private static Map<Id, Boolean> getReassignedFlagsByAllotmentId(Set<Id> allotmentIds) {
        Map<Id, Boolean> response = new Map<Id, Boolean>();
        if (allotmentIds == null || allotmentIds.isEmpty()) {
            return response;
        }
        if (!Schema.sObjectType.Ken_Room_Allotment__c.fields.getMap().containsKey('Reassigned__c')) {
            return response;
        }

        for (SObject row : Database.query(
            'SELECT Id, Reassigned__c FROM Ken_Room_Allotment__c WHERE Id IN :allotmentIds'
        )) {
            response.put((Id) row.get('Id'), (Boolean) row.get('Reassigned__c'));
        }
        return response;
    }

    private static Date resolveTrendStartMonth(
        Ken_Windows__c windowRecord,
        Date earliestActivityMonth,
        Date latestActivityMonth
    ) {
        Date cycleStartMonth = firstOfMonth(toDate(windowRecord != null && windowRecord.Hostel_Cycle__r != null
            ? windowRecord.Hostel_Cycle__r.Cycle_Start_Date_Time__c
            : null));
        Date windowStartMonth = firstOfMonth(windowRecord != null ? windowRecord.Start_Date__c : null);
        Date fallbackStartMonth = latestActivityMonth != null
            ? firstOfMonth(latestActivityMonth.addMonths(-5))
            : firstOfMonth(Date.today().addMonths(-5));

        Date response = firstNonNullDate(new List<Date>{
            cycleStartMonth,
            windowStartMonth,
            earliestActivityMonth,
            fallbackStartMonth
        });
        if (earliestActivityMonth != null && earliestActivityMonth < response) {
            return earliestActivityMonth;
        }
        return response;
    }

    private static Date resolveTrendEndMonth(
        Ken_Windows__c windowRecord,
        Date startMonth,
        Date latestActivityMonth
    ) {
        Date cycleEndMonth = firstOfMonth(toDate(windowRecord != null && windowRecord.Hostel_Cycle__r != null
            ? windowRecord.Hostel_Cycle__r.Cycle_End_Date_Time__c
            : null));
        Date windowEndMonth = firstOfMonth(windowRecord != null ? windowRecord.End_Date__c : null);
        Date fallbackEndMonth = startMonth != null ? firstOfMonth(startMonth.addMonths(5)) : firstOfMonth(Date.today());

        Date response = firstNonNullDate(new List<Date>{
            cycleEndMonth,
            windowEndMonth,
            latestActivityMonth,
            fallbackEndMonth
        });
        if (latestActivityMonth != null && latestActivityMonth > response) {
            return latestActivityMonth;
        }
        if (startMonth != null && response < startMonth) {
            return startMonth;
        }
        return response;
    }

    private static Integer getMonthSpan(Date startMonth, Date endMonth) {
        if (startMonth == null || endMonth == null || endMonth < startMonth) {
            return 0;
        }
        return ((endMonth.year() - startMonth.year()) * 12) + (endMonth.month() - startMonth.month()) + 1;
    }

    private static Date firstNonNullDate(List<Date> values) {
        if (values == null) {
            return null;
        }
        for (Date value : values) {
            if (value != null) {
                return value;
            }
        }
        return null;
    }

    private static Date firstOfMonth(Date value) {
        if (value == null) {
            return null;
        }
        return Date.newInstance(value.year(), value.month(), 1);
    }

    private static Date toDate(Datetime value) {
        return value == null ? null : Date.newInstance(value.year(), value.month(), value.day());
    }

    private static String toMonthKey(Date value) {
        if (value == null) {
            return '';
        }
        String monthValue = value.month() < 10 ? '0' + String.valueOf(value.month()) : String.valueOf(value.month());
        return String.valueOf(value.year()) + '-' + monthValue;
    }

    private static String formatMonthLabel(Date value) {
        if (value == null) {
            return '';
        }
        return Datetime.newInstance(value, Time.newInstance(0, 0, 0, 0)).format('MMM');
    }

    private static RoomScope getRoomScope(Id windowId) {
        RoomScope scope = new RoomScope();
        if (windowId == null) {
            return scope;
        }
        if (!Schema.sObjectType.Ken_Window_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view window buildings.');
        }
        if (!Schema.sObjectType.Ken_Window_Room_Category__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view window room categories.');
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

    private static Boolean matchesRoomScope(RoomScope scope, Id buildingId, Id roomCategoryId) {
        if (scope == null) {
            return true;
        }
        if (!scope.buildingIds.isEmpty() && !scope.buildingIds.contains(buildingId)) {
            return false;
        }
        if (!scope.roomCategoryIds.isEmpty() && !scope.roomCategoryIds.contains(roomCategoryId)) {
            return false;
        }
        return true;
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

    private static String normalizeKey(String value) {
        return sanitize(value).toLowerCase().replaceAll('\\s+', '');
    }

    private static String sanitize(String value) {
        return value == null ? '' : value.trim();
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
}