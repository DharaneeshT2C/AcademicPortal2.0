public with sharing class KenAdminDashboardController {
    private static final Set<String> COLLECTED_PAYMENT_STATUSES = new Set<String>{
        'Success',
        'Authorised',
        'Settled',
        'Shipped'
    };

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

    public class DashboardSummaryResponse {
        @AuraEnabled public Integer totalRegistered { get; set; }
        @AuraEnabled public Integer totalAllocations { get; set; }
        @AuraEnabled public Integer inProgress { get; set; }
        @AuraEnabled public Decimal occupancyRate { get; set; }
        @AuraEnabled public Integer totalCapacity { get; set; }
        @AuraEnabled public Integer availableRooms { get; set; }
        @AuraEnabled public Integer waitlisted { get; set; }
        @AuraEnabled public Integer occupiedBeds { get; set; }
        @AuraEnabled public Decimal totalAmountCollected { get; set; }
        @AuraEnabled public Decimal pendingAmount { get; set; }
        @AuraEnabled public List<CategoryRegistrationItem> categoryRegistrations { get; set; }
        @AuraEnabled public List<CategoryOccupancyItem> categoryOccupancy { get; set; }
        @AuraEnabled public List<AllocationBreakdownItem> allocationBreakdown { get; set; }

        public DashboardSummaryResponse() {
            totalRegistered = 0;
            totalAllocations = 0;
            inProgress = 0;
            occupancyRate = 0;
            totalCapacity = 0;
            availableRooms = 0;
            waitlisted = 0;
            occupiedBeds = 0;
            totalAmountCollected = 0;
            pendingAmount = 0;
            categoryRegistrations = new List<CategoryRegistrationItem>();
            categoryOccupancy = new List<CategoryOccupancyItem>();
            allocationBreakdown = new List<AllocationBreakdownItem>();
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

    public class AllocationBreakdownItem {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Integer count { get; set; }

        public AllocationBreakdownItem() {
            label = '';
            count = 0;
        }
    }

    public class WindowPerformanceItem {
        @AuraEnabled public String windowId { get; set; }
        @AuraEnabled public String windowName { get; set; }
        @AuraEnabled public String allotmentType { get; set; }
        @AuraEnabled public Integer applications { get; set; }
        @AuraEnabled public Integer allocated { get; set; }
        @AuraEnabled public Integer pending { get; set; }
        @AuraEnabled public String status { get; set; }

        public WindowPerformanceItem() {
            windowId = '';
            windowName = '';
            allotmentType = '';
            applications = 0;
            allocated = 0;
            pending = 0;
            status = '';
        }
    }

    private class RoomScope {
        public Set<Id> buildingIds = new Set<Id>();
        public Set<Id> roomCategoryIds = new Set<Id>();
    }

    @AuraEnabled(cacheable=true)
    public static List<CycleOption> getCycleOptions() {
        if (!Schema.sObjectType.Hostel_Cycle__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view hostel cycles.');
        }

        List<CycleOption> response = new List<CycleOption>();
        for (Hostel_Cycle__c cycleRecord : [
            SELECT Id, Name, Status__c, Cycle_Start_Date_Time__c
            FROM Hostel_Cycle__c
            ORDER BY Cycle_Start_Date_Time__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 200
        ]) {
            CycleOption option = new CycleOption();
            option.value = String.valueOf(cycleRecord.Id);
            option.name = sanitize(cycleRecord.Name);
            option.status = sanitize(cycleRecord.Status__c);
            option.label = buildCycleLabel(option.name, option.status);
            response.add(option);
        }
        return response;
    }

    @AuraEnabled(cacheable=true)
    public static List<WindowOption> getWindowOptions(String cycleId) {
        Id cycleRecordId = normalizeId(cycleId, 'Invalid cycle.');
        if (cycleRecordId == null) {
            return new List<WindowOption>();
        }
        if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view residence windows.');
        }

        List<WindowOption> response = new List<WindowOption>();
        for (Ken_Windows__c windowRecord : [
            SELECT Id, Name, Allotment_Type__c, Start_Date__c, End_Date__c
            FROM Ken_Windows__c
            WHERE Hostel_Cycle__c = :cycleRecordId
            ORDER BY Start_Date__c ASC NULLS LAST, Start_Time__c ASC NULLS LAST, CreatedDate ASC
            LIMIT 500
        ]) {
            WindowOption option = new WindowOption();
            option.id = String.valueOf(windowRecord.Id);
            option.name = sanitize(windowRecord.Name);
            option.allotmentType = normalizeAllotmentTypeDisplay(windowRecord.Allotment_Type__c);
            option.status = resolveWindowStatus(windowRecord.Start_Date__c, windowRecord.End_Date__c);
            option.startDate = formatDate(windowRecord.Start_Date__c);
            option.endDate = formatDate(windowRecord.End_Date__c);
            option.label = buildWindowLabel(option.name, option.allotmentType, option.status);
            response.add(option);
        }
        return response;
    }

    @AuraEnabled(cacheable=true)
    public static List<WindowPerformanceItem> getWindowPerformanceOverview(String cycleId) {
        Id cycleRecordId = normalizeId(cycleId, 'Invalid cycle.');
        if (cycleRecordId == null) {
            return new List<WindowPerformanceItem>();
        }
        if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view residence windows.');
        }

        List<WindowPerformanceItem> response = new List<WindowPerformanceItem>();
        for (Ken_Windows__c windowRecord : [
            SELECT Id, Name, Allotment_Type__c, Start_Date__c, End_Date__c
            FROM Ken_Windows__c
            WHERE Hostel_Cycle__c = :cycleRecordId
            ORDER BY Start_Date__c ASC NULLS LAST, Start_Time__c ASC NULLS LAST, CreatedDate ASC
            LIMIT 500
        ]) {
            List<KenAccommodationManagementController.InProgressRow> inProgressRows =
                KenAccommodationManagementController.getInProgressRows(String.valueOf(windowRecord.Id));
            List<KenAccommodationManagementController.AllocatedRow> allocatedRows =
                KenAccommodationManagementController.getAllocatedRows(String.valueOf(windowRecord.Id));

            WindowPerformanceItem item = new WindowPerformanceItem();
            item.windowId = String.valueOf(windowRecord.Id);
            item.windowName = sanitize(windowRecord.Name);
            item.allotmentType = normalizeAllotmentTypeDisplay(windowRecord.Allotment_Type__c);
            item.allocated = allocatedRows.size();
            item.pending = countPendingInProgressRows(inProgressRows);
            item.applications = inProgressRows.size() + allocatedRows.size();
            item.status = resolveWindowStatus(windowRecord.Start_Date__c, windowRecord.End_Date__c);
            response.add(item);
        }
        return response;
    }

    @AuraEnabled
    public static DashboardSummaryResponse getDashboardSummary(String windowId) {
        Id windowRecordId = normalizeId(windowId, 'Invalid window.');
        DashboardSummaryResponse response = new DashboardSummaryResponse();
        if (windowRecordId == null) {
            return response;
        }
        if (!Schema.sObjectType.Ken_Windows__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view residence windows.');
        }

        Ken_Windows__c windowRecord = [
            SELECT Id, Allotment_Type__c, Hostel_Cycle__r.Academic_Years_Display__c
            FROM Ken_Windows__c
            WHERE Id = :windowRecordId
            LIMIT 1
        ];

        List<KenAccommodationManagementController.InProgressRow> inProgressRows =
            KenAccommodationManagementController.getInProgressRows(String.valueOf(windowRecordId));
        List<KenAccommodationManagementController.AllocatedRow> allocatedRows =
            KenAccommodationManagementController.getAllocatedRows(String.valueOf(windowRecordId));

        response.inProgress = inProgressRows.size();
        response.totalAllocations = allocatedRows.size();
        response.waitlisted = inProgressRows.size();
        populateAllocationBreakdown(response, allocatedRows);
        populateCategoryRegistrationMetrics(response, inProgressRows, allocatedRows, windowRecord);

        populateRoomMetrics(response, windowRecordId);
        populatePaymentMetrics(
            response,
            collectStudentAccountIds(inProgressRows, allocatedRows),
            parseAcademicYearLabels(windowRecord.Hostel_Cycle__r != null
                ? windowRecord.Hostel_Cycle__r.Academic_Years_Display__c
                : null)
        );
        return response;
    }

    private static void populateRoomMetrics(DashboardSummaryResponse response, Id windowId) {
        if (response == null || windowId == null) {
            return;
        }
        if (!Schema.sObjectType.Ken_Room__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view rooms.');
        }

        RoomScope scope = getRoomScope(windowId);
        Integer totalCapacity = 0;
        Integer occupiedBeds = 0;
        Integer availableRooms = 0;
        Map<String, CategoryOccupancyItem> categoryItemByKey = new Map<String, CategoryOccupancyItem>();
        List<String> categoryOrder = new List<String>();

        for (Ken_Room__c room : [
            SELECT
                Id,
                Building__c,
                Room_Category__c,
                Room_Category__r.Name,
                Room_Category__r.Name__c,
                Housing_Category__c,
                Capacity__c,
                Occupancy_Status__c
            FROM Ken_Room__c
            WHERE Building__c != null
            ORDER BY Room_Category__r.Name__c ASC NULLS LAST, Room_Category__r.Name ASC NULLS LAST, Name ASC NULLS LAST, Room_Number__c ASC NULLS LAST
            LIMIT 5000
        ]) {
            if (!matchesRoomScope(scope, room.Building__c, room.Room_Category__c)) {
                continue;
            }

            Integer capacity = room.Capacity__c == null ? 0 : Integer.valueOf(room.Capacity__c);
            Integer occupancy = room.Occupancy_Status__c == null ? 0 : Integer.valueOf(room.Occupancy_Status__c);
            Integer normalizedCapacity = Math.max(capacity, 0);
            Integer normalizedOccupancy = Math.max(occupancy, 0);

            totalCapacity += normalizedCapacity;
            occupiedBeds += normalizedOccupancy;
            if (normalizedCapacity > 0 && normalizedOccupancy == 0) {
                availableRooms += 1;
            }

            String categoryKey = room.Room_Category__c != null
                ? String.valueOf(room.Room_Category__c)
                : 'uncategorized';
            String categoryLabel = resolveRoomCategoryLabel(room);
            if (!categoryItemByKey.containsKey(categoryKey)) {
                CategoryOccupancyItem categoryItem = new CategoryOccupancyItem();
                categoryItem.label = categoryLabel;
                categoryItemByKey.put(categoryKey, categoryItem);
                categoryOrder.add(categoryKey);
            }

            CategoryOccupancyItem currentCategory = categoryItemByKey.get(categoryKey);
            currentCategory.totalCapacity += normalizedCapacity;
            currentCategory.occupiedBeds += normalizedOccupancy;
        }

        response.totalCapacity = totalCapacity;
        response.occupiedBeds = occupiedBeds;
        response.availableRooms = availableRooms;
        response.categoryOccupancy = buildCategoryOccupancyItems(categoryItemByKey, categoryOrder);

        if (totalCapacity > 0) {
            Decimal occupancyRate = (Decimal.valueOf(occupiedBeds) * 100) / Decimal.valueOf(totalCapacity);
            Decimal roundedOccupancyRate = occupancyRate.setScale(1, RoundingMode.HALF_UP);
            response.occupancyRate = roundedOccupancyRate > 100
                ? Decimal.valueOf(100)
                : roundedOccupancyRate;
        }
    }

    private static void populateCategoryRegistrationMetrics(
        DashboardSummaryResponse response,
        List<KenAccommodationManagementController.InProgressRow> inProgressRows,
        List<KenAccommodationManagementController.AllocatedRow> allocatedRows,
        Ken_Windows__c windowRecord
    ) {
        if (response == null) {
            return;
        }

        Boolean isPreferenceFlow = isPreferenceFlowWindowType(windowRecord != null ? windowRecord.Allotment_Type__c : null);
        Map<String, CategoryRegistrationItem> itemByLabel = new Map<String, CategoryRegistrationItem>();

        for (KenAccommodationManagementController.InProgressRow row : inProgressRows) {
            String label = resolveCategoryLabel(row != null ? row.category : null);
            initializeCategoryRegistrationItem(itemByLabel, label).registeredCount += 1;
        }

        for (KenAccommodationManagementController.AllocatedRow row : allocatedRows) {
            String label = resolveCategoryLabel(row != null ? row.category : null);
            CategoryRegistrationItem item = initializeCategoryRegistrationItem(itemByLabel, label);
            if (!isPreferenceFlow) {
                item.registeredCount += 1;
            }
            item.allottedCount += 1;
        }

        response.categoryRegistrations = buildCategoryRegistrationItems(itemByLabel);
        response.totalRegistered = 0;
        for (CategoryRegistrationItem item : response.categoryRegistrations) {
            response.totalRegistered += item.registeredCount;
        }
    }

    private static CategoryRegistrationItem initializeCategoryRegistrationItem(
        Map<String, CategoryRegistrationItem> itemByLabel,
        String label
    ) {
        String safeLabel = resolveCategoryLabel(label);
        if (!itemByLabel.containsKey(safeLabel)) {
            CategoryRegistrationItem item = new CategoryRegistrationItem();
            item.label = safeLabel;
            itemByLabel.put(safeLabel, item);
        }
        return itemByLabel.get(safeLabel);
    }

    private static List<CategoryRegistrationItem> buildCategoryRegistrationItems(
        Map<String, CategoryRegistrationItem> itemByLabel
    ) {
        List<CategoryRegistrationItem> response = new List<CategoryRegistrationItem>();
        List<String> orderedLabels = new List<String>(itemByLabel.keySet());
        orderedLabels.sort();

        for (String label : orderedLabels) {
            CategoryRegistrationItem item = itemByLabel.get(label);
            if (item == null) {
                continue;
            }
            if (item.registeredCount < item.allottedCount) {
                item.registeredCount = item.allottedCount;
            }
            if (item.registeredCount > 0) {
                Decimal ratio = (Decimal.valueOf(item.allottedCount) * 100) / Decimal.valueOf(item.registeredCount);
                item.allotmentPercentage = ratio.setScale(0, RoundingMode.HALF_UP).intValue();
            }
            response.add(item);
        }
        return response;
    }

    private static void populatePaymentMetrics(
        DashboardSummaryResponse response,
        Set<Id> accountIds,
        Set<String> academicYearLabels
    ) {
        if (response == null || accountIds == null || accountIds.isEmpty()) {
            return;
        }
        if (!Schema.sObjectType.Payment_Transaction__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view payment transactions.');
        }
        if (!Schema.sObjectType.Fee_Assignment__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view fee assignments.');
        }

        Decimal collectedAmount = 0;
        Decimal pendingAmount = 0;

        if (academicYearLabels != null && !academicYearLabels.isEmpty()) {
            AggregateResult[] paymentResults = [
                SELECT SUM(Amount__c) totalAmount
                FROM Payment_Transaction__c
                WHERE Account__c IN :accountIds
                    AND Payment_Status__c IN :COLLECTED_PAYMENT_STATUSES
                    AND Fee_Assignment__c != null
                    AND Fee_Assignment__r.Fee_Type__r.Fee_Category__c = 'Hostel'
                    AND Fee_Assignment__r.Fee_Type__r.Academic_Year__c IN :academicYearLabels
            ];
            AggregateResult[] feeAssignmentResults = [
                SELECT SUM(Remaining_Amount_Formula__c) totalPending
                FROM Fee_Assignment__c
                WHERE Account__c IN :accountIds
                    AND Active__c = true
                    AND Fee_Type__c != null
                    AND Fee_Type__r.Fee_Category__c = 'Hostel'
                    AND Fee_Type__r.Academic_Year__c IN :academicYearLabels
            ];
            collectedAmount = extractAggregateDecimal(paymentResults, 'totalAmount');
            pendingAmount = extractAggregateDecimal(feeAssignmentResults, 'totalPending');
        } else {
            AggregateResult[] paymentResults = [
                SELECT SUM(Amount__c) totalAmount
                FROM Payment_Transaction__c
                WHERE Account__c IN :accountIds
                    AND Payment_Status__c IN :COLLECTED_PAYMENT_STATUSES
                    AND Fee_Assignment__c != null
                    AND Fee_Assignment__r.Fee_Type__r.Fee_Category__c = 'Hostel'
            ];
            AggregateResult[] feeAssignmentResults = [
                SELECT SUM(Remaining_Amount_Formula__c) totalPending
                FROM Fee_Assignment__c
                WHERE Account__c IN :accountIds
                    AND Active__c = true
                    AND Fee_Type__c != null
                    AND Fee_Type__r.Fee_Category__c = 'Hostel'
            ];
            collectedAmount = extractAggregateDecimal(paymentResults, 'totalAmount');
            pendingAmount = extractAggregateDecimal(feeAssignmentResults, 'totalPending');
        }

        response.totalAmountCollected = collectedAmount;
        response.pendingAmount = pendingAmount < 0 ? Decimal.valueOf(0) : pendingAmount;
    }

    private static Decimal extractAggregateDecimal(List<AggregateResult> rows, String fieldName) {
        if (rows == null || rows.isEmpty() || String.isBlank(fieldName)) {
            return Decimal.valueOf(0);
        }
        Object rawValue = rows[0].get(fieldName);
        return rawValue == null ? Decimal.valueOf(0) : (Decimal) rawValue;
    }

    private static Set<Id> collectStudentAccountIds(
        List<KenAccommodationManagementController.InProgressRow> inProgressRows,
        List<KenAccommodationManagementController.AllocatedRow> allocatedRows
    ) {
        Set<Id> accountIds = new Set<Id>();
        for (KenAccommodationManagementController.InProgressRow row : inProgressRows) {
            Id accountId = normalizeIdValue(row != null ? row.accountId : null);
            if (accountId != null) {
                accountIds.add(accountId);
            }
        }
        for (KenAccommodationManagementController.AllocatedRow row : allocatedRows) {
            Id accountId = normalizeIdValue(row != null ? row.accountId : null);
            if (accountId != null) {
                accountIds.add(accountId);
            }
        }
        return accountIds;
    }

    private static Id normalizeIdValue(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return (Id) value;
        } catch (Exception ex) {
            return null;
        }
    }

    private static Set<String> parseAcademicYearLabels(String value) {
        Set<String> labels = new Set<String>();
        String sanitizedValue = sanitize(value);
        if (String.isBlank(sanitizedValue)) {
            return labels;
        }

        for (String token : sanitizedValue.replace(';', ',').split(',')) {
            String label = sanitize(token);
            if (String.isNotBlank(label)) {
                labels.add(label);
            }
        }
        return labels;
    }

    private static List<CategoryOccupancyItem> buildCategoryOccupancyItems(
        Map<String, CategoryOccupancyItem> categoryItemByKey,
        List<String> categoryOrder
    ) {
        List<CategoryOccupancyItem> response = new List<CategoryOccupancyItem>();
        for (String categoryKey : categoryOrder) {
            CategoryOccupancyItem item = categoryItemByKey.get(categoryKey);
            if (item == null || item.totalCapacity <= 0) {
                continue;
            }
            Decimal occupancyPercentage = (Decimal.valueOf(item.occupiedBeds) * 100) / Decimal.valueOf(item.totalCapacity);
            item.occupancyPercentage = occupancyPercentage.setScale(0, RoundingMode.HALF_UP).intValue();
            response.add(item);
        }
        return response;
    }

    private static void populateAllocationBreakdown(
        DashboardSummaryResponse response,
        List<KenAccommodationManagementController.AllocatedRow> allocatedRows
    ) {
        if (response == null) {
            return;
        }

        Map<String, Integer> countByType = new Map<String, Integer>();
        for (KenAccommodationManagementController.AllocatedRow row : allocatedRows) {
            String label = firstNonBlank(new List<String>{
                sanitize(row != null ? row.allotmentType : null),
                'Other'
            });
            countByType.put(label, (countByType.containsKey(label) ? countByType.get(label) : 0) + 1);
        }

        List<String> orderedLabels = new List<String>();
        for (String preferredLabel : new List<String>{
            'Direct Allotment',
            'Provisional Allotment',
            'Preference Selected',
            'Confirmed Allotment'
        }) {
            if (countByType.containsKey(preferredLabel)) {
                orderedLabels.add(preferredLabel);
            }
        }

        List<String> remainingLabels = new List<String>();
        for (String label : countByType.keySet()) {
            if (!orderedLabels.contains(label)) {
                remainingLabels.add(label);
            }
        }
        remainingLabels.sort();
        orderedLabels.addAll(remainingLabels);

        response.allocationBreakdown = new List<AllocationBreakdownItem>();
        for (String label : orderedLabels) {
            AllocationBreakdownItem item = new AllocationBreakdownItem();
            item.label = label;
            item.count = countByType.get(label);
            response.allocationBreakdown.add(item);
        }
    }

    private static Integer countPendingInProgressRows(
        List<KenAccommodationManagementController.InProgressRow> inProgressRows
    ) {
        Integer pendingCount = 0;
        for (KenAccommodationManagementController.InProgressRow row : inProgressRows) {
            if (isPendingInProgressStatus(row != null ? row.status : null)) {
                pendingCount += 1;
            }
        }
        return pendingCount;
    }

    private static Boolean isPendingInProgressStatus(String statusValue) {
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

    private static String resolveRoomCategoryLabel(Ken_Room__c room) {
        return firstNonBlank(new List<String>{
            room != null && room.Room_Category__r != null ? sanitize(room.Room_Category__r.Name__c) : null,
            room != null && room.Room_Category__r != null ? sanitize(room.Room_Category__r.Name) : null,
            room != null ? sanitize(room.Housing_Category__c) : null,
            'Uncategorized'
        });
    }

    private static String resolveCategoryLabel(String value) {
        String sanitizedValue = sanitize(value);
        return String.isBlank(sanitizedValue) ? 'Uncategorized' : sanitizedValue;
    }

    private static Boolean isPreferenceFlowWindowType(String allotmentType) {
        String normalizedType = normalizeAllotmentTypeDisplay(allotmentType);
        return normalizedType == 'Preference Selected' || normalizedType == 'Provisional Allotment';
    }

    private static String buildCycleLabel(String nameValue, String statusValue) {
        String nameText = sanitize(nameValue);
        String statusText = sanitize(statusValue);
        return String.isBlank(statusText) ? nameText : nameText + ' (' + statusText + ')';
    }

    private static String buildWindowLabel(String nameValue, String allotmentType, String statusValue) {
        String nameText = sanitize(nameValue);
        List<String> parts = new List<String>();
        String allotmentText = sanitize(allotmentType);
        String statusText = sanitize(statusValue);
        if (String.isNotBlank(allotmentText)) {
            parts.add(allotmentText);
        }
        if (String.isNotBlank(statusText)) {
            parts.add(statusText);
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

    private static String formatDate(Date value) {
        return value == null ? '' : String.valueOf(value);
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