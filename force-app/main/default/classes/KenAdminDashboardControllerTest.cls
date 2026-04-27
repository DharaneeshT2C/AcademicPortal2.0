@IsTest
private class KenAdminDashboardControllerTest {
    private static Account createStudentAccount(String key) {
        return KenHostelTestHelper.createPersonAccount(
            'Student',
            key,
            key.toLowerCase() + '@example.com',
            'Student'
        );
    }

    private static Contact getStudentContact(Account studentAccount) {
        return [
            SELECT Id, Name
            FROM Contact
            WHERE Id = :studentAccount.PersonContactId
            LIMIT 1
        ];
    }

    private static Ken_Windows__c createWindow(
        Id cycleId,
        Id learningProgramPlanId,
        Id buildingId,
        Id roomCategoryId,
        String nameValue,
        String allotmentType,
        Date startDate,
        Date endDate
    ) {
        Ken_Windows__c windowRow = KenHostelTestHelper.createWindowDirect(
            cycleId,
            learningProgramPlanId,
            buildingId,
            roomCategoryId,
            nameValue,
            allotmentType,
            false
        );

        update new Ken_Windows__c(
            Id = windowRow.Id,
            Start_Date__c = startDate,
            End_Date__c = endDate
        );

        return [
            SELECT Id, Name, Allotment_Type__c, Start_Date__c, End_Date__c
            FROM Ken_Windows__c
            WHERE Id = :windowRow.Id
            LIMIT 1
        ];
    }

    private static Ken_Room__c createRoomRecord(
        Id buildingId,
        Id floorId,
        Id roomCategoryId,
        Integer capacity,
        String roomNumber,
        String housingCategory
    ) {
        return KenHostelTestHelper.createRoom(
            buildingId,
            floorId,
            roomCategoryId,
            capacity,
            roomNumber,
            housingCategory
        );
    }

    private static void createRequestForWindow(
        Ken_Windows__c windowRow,
        Ken_Room_Category__c roomCategory,
        String statusValue,
        String key
    ) {
        Account studentAccount = createStudentAccount(key);
        Contact studentContact = getStudentContact(studentAccount);
        KenHostelTestHelper.createRoomRequest(
            studentAccount.Id,
            studentContact.Id,
            windowRow.Id,
            roomCategory.Id,
            roomCategory.Name__c,
            1,
            statusValue
        );
    }

    private static Ken_Room_Allotment__c createAllotmentForWindow(
        Ken_Room__c roomRow,
        Ken_Windows__c windowRow,
        String key,
        String allotmentType,
        Id learningProgramPlanId
    ) {
        Account studentAccount = createStudentAccount(key);
        Contact studentContact = getStudentContact(studentAccount);
        if (learningProgramPlanId != null) {
            KenHostelTestHelper.createLearnerProgram(
                studentAccount.Id,
                studentContact.Id,
                learningProgramPlanId,
                key
            );
        }
        Ken_Room_Allotment__c allotmentRow = KenHostelTestHelper.createRoomAllotment(
            roomRow.Id,
            studentAccount.Id,
            studentContact.Id,
            windowRow.Id,
            null,
            true
        );
        if (String.isNotBlank(allotmentType)) {
            update new Ken_Room_Allotment__c(
                Id = allotmentRow.Id,
                Allotment_Type__c = allotmentType
            );
        }
        return [
            SELECT Id, Allotment_Type__c
            FROM Ken_Room_Allotment__c
            WHERE Id = :allotmentRow.Id
            LIMIT 1
        ];
    }

    private static Map<String, KenAdminDashboardController.WindowOption> mapWindowOptionsById(
        List<KenAdminDashboardController.WindowOption> windowOptions
    ) {
        Map<String, KenAdminDashboardController.WindowOption> response =
            new Map<String, KenAdminDashboardController.WindowOption>();
        for (KenAdminDashboardController.WindowOption option : windowOptions) {
            response.put(option.id, option);
        }
        return response;
    }

    private static Map<String, KenAdminDashboardController.WindowPerformanceItem> mapOverviewByWindowId(
        List<KenAdminDashboardController.WindowPerformanceItem> overviewRows
    ) {
        Map<String, KenAdminDashboardController.WindowPerformanceItem> response =
            new Map<String, KenAdminDashboardController.WindowPerformanceItem>();
        for (KenAdminDashboardController.WindowPerformanceItem item : overviewRows) {
            response.put(item.windowId, item);
        }
        return response;
    }

    @IsTest
    static void testCycleAndWindowOptions() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'dashadm1',
            false,
            false
        );

        Test.startTest();
        List<KenAdminDashboardController.CycleOption> cycleOptions = KenAdminDashboardController.getCycleOptions();
        List<KenAdminDashboardController.WindowOption> windowOptions =
            KenAdminDashboardController.getWindowOptions(String.valueOf(context.cycle.Id));
        Test.stopTest();

        System.assertEquals(true, !cycleOptions.isEmpty(), 'Cycle options should include the created cycle.');
        System.assertEquals(1, windowOptions.size(), 'One window should be returned for the created cycle.');
        System.assertEquals(String.valueOf(context.window.Id), windowOptions[0].id);
        System.assertEquals(context.window.Name, windowOptions[0].name);
    }

    @IsTest
    static void testPublicMethodsHandleNullAndInvalidIds() {
        Test.startTest();
        List<KenAdminDashboardController.WindowOption> emptyWindowOptions =
            KenAdminDashboardController.getWindowOptions(null);
        List<KenAdminDashboardController.WindowPerformanceItem> emptyOverview =
            KenAdminDashboardController.getWindowPerformanceOverview(null);
        KenAdminDashboardController.DashboardSummaryResponse emptySummary =
            KenAdminDashboardController.getDashboardSummary(null);
        Test.stopTest();

        System.assertEquals(0, emptyWindowOptions.size(), 'Blank cycle id should return no windows.');
        System.assertEquals(0, emptyOverview.size(), 'Blank cycle id should return no overview rows.');
        System.assertEquals(0, emptySummary.totalAllocations, 'Blank window id should return empty summary values.');
        System.assertEquals(0, emptySummary.inProgress, 'Blank window id should return empty summary values.');
        System.assertEquals(0, emptySummary.waitlisted, 'Blank window id should return empty summary values.');
        System.assertEquals(0, emptySummary.totalCapacity, 'Blank window id should return empty summary values.');
        System.assertEquals(0, emptySummary.categoryOccupancy.size(), 'Blank window id should not return categories.');
        System.assertEquals(0, emptySummary.allocationBreakdown.size(), 'Blank window id should not return breakdown.');

        try {
            KenAdminDashboardController.getWindowOptions('not-an-id');
            System.assert(false, 'Invalid cycle id should raise an AuraHandledException.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex, 'Invalid cycle id should raise an AuraHandledException.');
        }

        try {
            KenAdminDashboardController.getWindowPerformanceOverview('not-an-id');
            System.assert(false, 'Invalid cycle id should raise an AuraHandledException.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex, 'Invalid cycle id should raise an AuraHandledException.');
        }

        try {
            KenAdminDashboardController.getDashboardSummary('not-an-id');
            System.assert(false, 'Invalid window id should raise an AuraHandledException.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex, 'Invalid window id should raise an AuraHandledException.');
        }
    }

    @IsTest
    static void testCycleAndWindowOptionsShowNormalizedStatusesAndTypes() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'dashopt1',
            false,
            false
        );

        String directType = KenHostelTestHelper.getPicklistValue(
            Ken_Windows__c.Allotment_Type__c,
            'Direct Allotment'
        );
        String provisionalType = KenHostelTestHelper.getPicklistValue(
            Ken_Windows__c.Allotment_Type__c,
            'Provisional Allotment'
        );
        String confirmedType = KenHostelTestHelper.getPicklistValue(
            Ken_Windows__c.Allotment_Type__c,
            'Confirmed Allotment'
        );
        String stayCompletedType = KenHostelTestHelper.getPicklistValue(
            Ken_Windows__c.Allotment_Type__c,
            'Stay Completed'
        );

        Ken_Windows__c futureWindow = createWindow(
            context.cycle.Id,
            context.learningProgramPlan.Id,
            context.building.Id,
            context.roomCategory.Id,
            'Window Future',
            directType,
            Date.today().addDays(12),
            Date.today().addDays(18)
        );
        Ken_Windows__c closedWindow = createWindow(
            context.cycle.Id,
            context.learningProgramPlan.Id,
            context.building.Id,
            context.roomCategory.Id,
            'Window Closed',
            provisionalType,
            Date.today().addDays(-18),
            Date.today().addDays(-8)
        );
        Ken_Windows__c confirmedWindow = createWindow(
            context.cycle.Id,
            context.learningProgramPlan.Id,
            context.building.Id,
            context.roomCategory.Id,
            'Window Confirmed',
            confirmedType,
            Date.today().addDays(-2),
            Date.today().addDays(4)
        );
        Ken_Windows__c stayCompletedWindow = createWindow(
            context.cycle.Id,
            context.learningProgramPlan.Id,
            context.building.Id,
            context.roomCategory.Id,
            'Window Completed',
            stayCompletedType,
            Date.today().addDays(-2),
            Date.today().addDays(4)
        );

        Test.startTest();
        List<KenAdminDashboardController.CycleOption> cycleOptions = KenAdminDashboardController.getCycleOptions();
        List<KenAdminDashboardController.WindowOption> windowOptions =
            KenAdminDashboardController.getWindowOptions(String.valueOf(context.cycle.Id));
        Test.stopTest();

        System.assertEquals(true, !cycleOptions.isEmpty(), 'Cycle options should include the created cycle.');

        Map<String, KenAdminDashboardController.WindowOption> optionsById = mapWindowOptionsById(windowOptions);
        System.assertEquals('Preference Selected', optionsById.get(String.valueOf(context.window.Id)).allotmentType);
        System.assertEquals('Open', optionsById.get(String.valueOf(context.window.Id)).status);

        System.assertEquals('Direct Allotment', optionsById.get(String.valueOf(futureWindow.Id)).allotmentType);
        System.assertEquals('Upcoming', optionsById.get(String.valueOf(futureWindow.Id)).status);
        System.assert(optionsById.get(String.valueOf(futureWindow.Id)).label.contains('Direct Allotment'));
        System.assert(optionsById.get(String.valueOf(futureWindow.Id)).label.contains('Upcoming'));

        System.assertEquals('Provisional Allotment', optionsById.get(String.valueOf(closedWindow.Id)).allotmentType);
        System.assertEquals('Closed', optionsById.get(String.valueOf(closedWindow.Id)).status);

        System.assertEquals('Confirmed Allotment', optionsById.get(String.valueOf(confirmedWindow.Id)).allotmentType);
        System.assertEquals('Open', optionsById.get(String.valueOf(confirmedWindow.Id)).status);

        System.assertEquals('Stay Completed', optionsById.get(String.valueOf(stayCompletedWindow.Id)).allotmentType);
        System.assertEquals('Open', optionsById.get(String.valueOf(stayCompletedWindow.Id)).status);
    }

    @IsTest
    static void testDashboardSummaryForAllocatedWindow() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'dashadm2',
            true,
            false
        );

        Test.startTest();
        KenAdminDashboardController.DashboardSummaryResponse summary =
            KenAdminDashboardController.getDashboardSummary(String.valueOf(context.window.Id));
        Test.stopTest();

        System.assertEquals(1, summary.totalAllocations, 'Allocated student should count toward total allocations.');
        System.assertEquals(0, summary.inProgress, 'No in-progress requests were created in this setup.');
        System.assertEquals(0, summary.waitlisted, 'No in-progress requests should be waitlisted.');
        System.assertEquals(2, summary.totalCapacity, 'Window-scoped room capacity should be summed from room records.');
        System.assertEquals(0, summary.availableRooms, 'Partially occupied room should not count as fully available.');
        System.assertEquals(1, summary.occupiedBeds, 'One active allotment should contribute one occupied bed.');
        System.assertEquals(Decimal.valueOf('50.0'), summary.occupancyRate);
        System.assertEquals(1, summary.categoryOccupancy.size(), 'One scoped room category should be summarized.');
        System.assertEquals(context.roomCategory.Name__c, summary.categoryOccupancy[0].label);
        System.assertEquals(1, summary.categoryOccupancy[0].occupiedBeds);
        System.assertEquals(2, summary.categoryOccupancy[0].totalCapacity);
        System.assertEquals(50, summary.categoryOccupancy[0].occupancyPercentage);
        System.assertEquals(1, summary.allocationBreakdown.size(), 'Allocated allotment types should be grouped.');
        System.assertEquals('Preference Selected', summary.allocationBreakdown[0].label);
        System.assertEquals(1, summary.allocationBreakdown[0].count);
    }

    @IsTest
    static void testDashboardSummaryCountsPendingRequestsAsWaitlisted() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'dashadm3',
            false,
            false
        );
        KenHostelTestHelper.createRoomRequest(
            context.studentAccount.Id,
            context.studentContact.Id,
            context.window.Id,
            context.roomCategory.Id,
            context.roomCategory.Name__c,
            1,
            'Pending'
        );

        Test.startTest();
        KenAdminDashboardController.DashboardSummaryResponse summary =
            KenAdminDashboardController.getDashboardSummary(String.valueOf(context.window.Id));
        Test.stopTest();

        System.assertEquals(0, summary.totalAllocations, 'No allocations were created in this setup.');
        System.assertEquals(1, summary.inProgress, 'Pending request should appear in progress.');
        System.assertEquals(1, summary.waitlisted, 'In-progress request should count as waitlisted.');
        System.assertEquals(2, summary.totalCapacity, 'Scoped room capacity should still be reported.');
        System.assertEquals(1, summary.availableRooms, 'Unoccupied room should be available.');
        System.assertEquals(0, summary.occupiedBeds, 'No active allotments means no occupied beds.');
        System.assertEquals(Decimal.valueOf('0'), summary.occupancyRate);
        System.assertEquals(1, summary.categoryOccupancy.size(), 'Room category occupancy should still be returned.');
        System.assertEquals(context.roomCategory.Name__c, summary.categoryOccupancy[0].label);
        System.assertEquals(0, summary.categoryOccupancy[0].occupiedBeds);
        System.assertEquals(2, summary.categoryOccupancy[0].totalCapacity);
        System.assertEquals(0, summary.categoryOccupancy[0].occupancyPercentage);
        System.assertEquals(0, summary.allocationBreakdown.size(), 'No allocations means no breakdown items.');
    }

    @IsTest
    static void testDashboardSummaryUsesAllRoomFallbackScopeAndPendingFilters() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'dashsum1',
            false,
            false
        );

        String preferenceType = KenHostelTestHelper.getPicklistValue(
            Ken_Windows__c.Allotment_Type__c,
            'Preference Selected'
        );
        Ken_Windows__c allRoomsWindow = createWindow(
            context.cycle.Id,
            null,
            null,
            null,
            'Window All Rooms',
            preferenceType,
            Date.today().addDays(-1),
            Date.today().addDays(10)
        );

        createRoomRecord(
            context.building.Id,
            context.floor.Id,
            context.roomCategory.Id,
            1,
            'R-EXTRA-' + Math.abs(Crypto.getRandomInteger()),
            context.roomCategory.Name__c
        );

        Ken_Room_Category__c zeroCapacityCategory = KenHostelTestHelper.createRoomCategory(
            'Category Zero',
            0
        );
        createRoomRecord(
            context.building.Id,
            context.floor.Id,
            zeroCapacityCategory.Id,
            0,
            'R-ZERO-' + Math.abs(Crypto.getRandomInteger()),
            zeroCapacityCategory.Name__c
        );

        Ken_Building__c secondBuilding = KenHostelTestHelper.createBuildingDirect('Building Summary Two', 1);
        Floor__c secondFloor = KenHostelTestHelper.createFloor(secondBuilding.Id, 1);
        Ken_Room_Category__c secondCategory = KenHostelTestHelper.createRoomCategory('Category Summary Two', 3);
        Ken_Room__c occupiedRoom = createRoomRecord(
            secondBuilding.Id,
            secondFloor.Id,
            secondCategory.Id,
            3,
            'R-OCC-' + Math.abs(Crypto.getRandomInteger()),
            secondCategory.Name__c
        );

        KenHostelTestHelper.createRoomAllotment(
            occupiedRoom.Id,
            context.studentAccount.Id,
            context.studentContact.Id,
            allRoomsWindow.Id,
            null,
            true
        );

        createRequestForWindow(allRoomsWindow, context.roomCategory, 'Pending', 'dashsumReq1');
        createRequestForWindow(allRoomsWindow, context.roomCategory, null, 'dashsumReq2');
        createRequestForWindow(allRoomsWindow, context.roomCategory, 'Alloted', 'dashsumReq3');
        createRequestForWindow(allRoomsWindow, context.roomCategory, 'Canceled', 'dashsumReq4');
        createRequestForWindow(allRoomsWindow, context.roomCategory, 'Rejected', 'dashsumReq5');
        createRequestForWindow(allRoomsWindow, context.roomCategory, 'Stay Completed', 'dashsumReq6');

        Test.startTest();
        KenAdminDashboardController.DashboardSummaryResponse summary =
            KenAdminDashboardController.getDashboardSummary(String.valueOf(allRoomsWindow.Id));
        Test.stopTest();

        System.assertEquals(1, summary.totalAllocations, 'One active allotment should count toward allocations.');
        System.assertEquals(2, summary.inProgress, 'Only pending-like request statuses should remain in progress.');
        System.assertEquals(2, summary.waitlisted, 'Only pending-like statuses should count as waitlisted.');
        System.assertEquals(6, summary.totalCapacity, 'An unscoped window should include all room capacity.');
        System.assertEquals(1, summary.occupiedBeds, 'One active allotment should contribute one occupied bed.');
        System.assertEquals(2, summary.availableRooms, 'Only unoccupied rooms with positive capacity should be available.');
        System.assertEquals(Decimal.valueOf('16.7'), summary.occupancyRate);
        System.assertEquals(2, summary.categoryOccupancy.size(), 'Zero-capacity categories should be excluded.');

        Set<String> categoryLabels = new Set<String>();
        for (KenAdminDashboardController.CategoryOccupancyItem item : summary.categoryOccupancy) {
            categoryLabels.add(item.label);
        }
        System.assert(categoryLabels.contains(context.roomCategory.Name__c));
        System.assert(categoryLabels.contains(secondCategory.Name__c));
        System.assertEquals(false, categoryLabels.contains(zeroCapacityCategory.Name__c));

        System.assertEquals(1, summary.allocationBreakdown.size(), 'One allocation type should be summarized.');
        System.assertEquals('Preference Selected', summary.allocationBreakdown[0].label);
        System.assertEquals(1, summary.allocationBreakdown[0].count);
    }

    @IsTest
    static void testDashboardSummaryOrdersAllocationBreakdown() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'dashord1',
            false,
            false
        );

        String directType = KenHostelTestHelper.getPicklistValue(
            Ken_Room_Allotment__c.Allotment_Type__c,
            'Direct Allotment'
        );
        String provisionalType = KenHostelTestHelper.getPicklistValue(
            Ken_Room_Allotment__c.Allotment_Type__c,
            'Provisional Allotment'
        );
        String preferenceType = KenHostelTestHelper.getPicklistValue(
            Ken_Room_Allotment__c.Allotment_Type__c,
            'Preference Selected'
        );
        String confirmedType = KenHostelTestHelper.getPicklistValue(
            Ken_Room_Allotment__c.Allotment_Type__c,
            'Confirmed Allotment'
        );

        Ken_Room__c roomTwo = createRoomRecord(
            context.building.Id,
            context.floor.Id,
            context.roomCategory.Id,
            1,
            'R-ORD-2-' + Math.abs(Crypto.getRandomInteger()),
            context.roomCategory.Name__c
        );
        Ken_Room__c roomThree = createRoomRecord(
            context.building.Id,
            context.floor.Id,
            context.roomCategory.Id,
            1,
            'R-ORD-3-' + Math.abs(Crypto.getRandomInteger()),
            context.roomCategory.Name__c
        );
        Ken_Room__c roomFour = createRoomRecord(
            context.building.Id,
            context.floor.Id,
            context.roomCategory.Id,
            1,
            'R-ORD-4-' + Math.abs(Crypto.getRandomInteger()),
            context.roomCategory.Name__c
        );

        createAllotmentForWindow(context.room, context.window, 'dashordA', directType, context.learningProgramPlan.Id);
        createAllotmentForWindow(roomTwo, context.window, 'dashordB', provisionalType, context.learningProgramPlan.Id);
        createAllotmentForWindow(roomThree, context.window, 'dashordC', preferenceType, context.learningProgramPlan.Id);
        createAllotmentForWindow(roomFour, context.window, 'dashordD', confirmedType, context.learningProgramPlan.Id);

        Test.startTest();
        KenAdminDashboardController.DashboardSummaryResponse summary =
            KenAdminDashboardController.getDashboardSummary(String.valueOf(context.window.Id));
        Test.stopTest();

        System.assertEquals(4, summary.totalAllocations, 'All active allotments should be counted.');
        System.assertEquals(4, summary.allocationBreakdown.size(), 'Each active allotment type should appear in the breakdown.');
        System.assertEquals('Direct Allotment', summary.allocationBreakdown[0].label);
        System.assertEquals('Provisional Allotment', summary.allocationBreakdown[1].label);
        System.assertEquals('Preference Selected', summary.allocationBreakdown[2].label);
        System.assertEquals('Confirmed Allotment', summary.allocationBreakdown[3].label);
        System.assertEquals(1, summary.allocationBreakdown[0].count);
        System.assertEquals(1, summary.allocationBreakdown[1].count);
        System.assertEquals(1, summary.allocationBreakdown[2].count);
        System.assertEquals(1, summary.allocationBreakdown[3].count);
    }

    @IsTest
    static void testWindowPerformanceOverviewByCycle() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'dashovw1',
            true,
            false
        );

        String preferenceType = KenHostelTestHelper.getPicklistValue(
            Ken_Windows__c.Allotment_Type__c,
            'Preference Selected'
        );
        String directType = KenHostelTestHelper.getPicklistValue(
            Ken_Windows__c.Allotment_Type__c,
            'Direct Allotment'
        );

        Ken_Windows__c pendingWindow = createWindow(
            context.cycle.Id,
            null,
            null,
            null,
            'Window Pending',
            preferenceType,
            Date.today().addDays(-1),
            Date.today().addDays(8)
        );
        Ken_Windows__c closedWindow = createWindow(
            context.cycle.Id,
            null,
            null,
            null,
            'Window Closed Direct',
            directType,
            Date.today().addDays(-10),
            Date.today().addDays(-2)
        );

        createRequestForWindow(pendingWindow, context.roomCategory, 'Pending', 'dashovwReq1');

        Test.startTest();
        List<KenAdminDashboardController.WindowPerformanceItem> overview =
            KenAdminDashboardController.getWindowPerformanceOverview(String.valueOf(context.cycle.Id));
        Test.stopTest();

        Map<String, KenAdminDashboardController.WindowPerformanceItem> rowByWindowId =
            mapOverviewByWindowId(overview);

        System.assertEquals(true, rowByWindowId.containsKey(String.valueOf(context.window.Id)));
        System.assertEquals(true, rowByWindowId.containsKey(String.valueOf(pendingWindow.Id)));
        System.assertEquals(true, rowByWindowId.containsKey(String.valueOf(closedWindow.Id)));

        KenAdminDashboardController.WindowPerformanceItem allocatedWindow =
            rowByWindowId.get(String.valueOf(context.window.Id));
        System.assertEquals(1, allocatedWindow.applications);
        System.assertEquals(1, allocatedWindow.allocated);
        System.assertEquals(0, allocatedWindow.pending);
        System.assertEquals('Preference Selected', allocatedWindow.allotmentType);
        System.assertEquals('Open', allocatedWindow.status);

        KenAdminDashboardController.WindowPerformanceItem pendingRow =
            rowByWindowId.get(String.valueOf(pendingWindow.Id));
        System.assertEquals(true, pendingRow.applications >= 1, 'Pending window should report at least one application.');
        System.assertEquals(1, pendingRow.pending);
        System.assertEquals('Preference Selected', pendingRow.allotmentType);
        System.assertEquals('Open', pendingRow.status);

        KenAdminDashboardController.WindowPerformanceItem closedRow =
            rowByWindowId.get(String.valueOf(closedWindow.Id));
        System.assertEquals('Direct Allotment', closedRow.allotmentType);
        System.assertEquals('Closed', closedRow.status);
    }
}