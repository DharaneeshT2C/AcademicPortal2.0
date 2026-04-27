@IsTest
private class KenReportsAnalyticsControllerTest {
    private static Account createStudentAccount(String key) {
        return KenHostelTestHelper.createPersonAccount(
            'Report',
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
        String nameValue,
        String allotmentType,
        Date startDate,
        Date endDate
    ) {
        Ken_Windows__c windowRow = KenHostelTestHelper.createWindowDirect(
            cycleId,
            null,
            null,
            null,
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

    private static Ken_Room_Request__c createRequestLinkedToAllotment(
        Ken_Windows__c windowRow,
        Ken_Room_Category__c roomCategory,
        String statusValue,
        String key,
        Id allotmentId
    ) {
        Account studentAccount = createStudentAccount(key);
        Contact studentContact = getStudentContact(studentAccount);
        Ken_Room_Request__c requestRow = KenHostelTestHelper.createRoomRequest(
            studentAccount.Id,
            studentContact.Id,
            windowRow.Id,
            roomCategory.Id,
            roomCategory.Name__c,
            1,
            statusValue
        );

        update new Ken_Room_Request__c(
            Id = requestRow.Id,
            Room_Allotment__c = allotmentId,
            Status__c = statusValue
        );

        return [
            SELECT Id, Status__c, Room_Allotment__c
            FROM Ken_Room_Request__c
            WHERE Id = :requestRow.Id
            LIMIT 1
        ];
    }

    private static Ken_Room_Allotment__c createAllotmentForWindow(
        Ken_Room__c roomRow,
        Ken_Windows__c windowRow,
        String key,
        String allotmentType
    ) {
        Account studentAccount = createStudentAccount(key);
        Contact studentContact = getStudentContact(studentAccount);

        Ken_Room_Allotment__c allotmentRow = KenHostelTestHelper.createRoomAllotment(
            roomRow.Id,
            studentAccount.Id,
            studentContact.Id,
            windowRow.Id,
            null,
            true
        );
        update new Ken_Room_Allotment__c(
            Id = allotmentRow.Id,
            Allotment_Type__c = allotmentType
        );

        return [
            SELECT Id, Allotment_Type__c, CreatedDate
            FROM Ken_Room_Allotment__c
            WHERE Id = :allotmentRow.Id
            LIMIT 1
        ];
    }

    private static void setAllotmentCreatedDate(Ken_Room_Allotment__c allotmentRow, Date dateValue) {
        Test.setCreatedDate(
            allotmentRow.Id,
            Datetime.newInstance(dateValue, Time.newInstance(9, 0, 0, 0))
        );
    }

    private static void markAllotmentAsReassigned(Id allotmentId) {
        if (allotmentId == null || !Schema.sObjectType.Ken_Room_Allotment__c.fields.getMap().containsKey('Reassigned__c')) {
            return;
        }

        SObject rowToUpdate = Ken_Room_Allotment__c.SObjectType.newSObject(allotmentId);
        rowToUpdate.put('Reassigned__c', true);
        update rowToUpdate;
    }

    private static Map<String, KenReportsAnalyticsController.WindowOption> mapWindowOptionsById(
        List<KenReportsAnalyticsController.WindowOption> windowOptions
    ) {
        Map<String, KenReportsAnalyticsController.WindowOption> response =
            new Map<String, KenReportsAnalyticsController.WindowOption>();
        for (KenReportsAnalyticsController.WindowOption option : windowOptions) {
            response.put(option.id, option);
        }
        return response;
    }

    private static Map<String, KenReportsAnalyticsController.BuildingOccupancyItem> mapBuildingItemsByName(
        List<KenReportsAnalyticsController.BuildingOccupancyItem> rows
    ) {
        Map<String, KenReportsAnalyticsController.BuildingOccupancyItem> response =
            new Map<String, KenReportsAnalyticsController.BuildingOccupancyItem>();
        for (KenReportsAnalyticsController.BuildingOccupancyItem row : rows) {
            response.put(row.buildingName, row);
        }
        return response;
    }

    private static Map<String, KenReportsAnalyticsController.AllotmentDistributionItem> mapDistributionByLabel(
        List<KenReportsAnalyticsController.AllotmentDistributionItem> rows
    ) {
        Map<String, KenReportsAnalyticsController.AllotmentDistributionItem> response =
            new Map<String, KenReportsAnalyticsController.AllotmentDistributionItem>();
        for (KenReportsAnalyticsController.AllotmentDistributionItem row : rows) {
            response.put(row.label, row);
        }
        return response;
    }

    private static Map<String, KenReportsAnalyticsController.MonthlyTrendItem> mapTrendByMonthKey(
        List<KenReportsAnalyticsController.MonthlyTrendItem> rows
    ) {
        Map<String, KenReportsAnalyticsController.MonthlyTrendItem> response =
            new Map<String, KenReportsAnalyticsController.MonthlyTrendItem>();
        for (KenReportsAnalyticsController.MonthlyTrendItem row : rows) {
            response.put(row.monthKey, row);
        }
        return response;
    }

    private static Map<String, KenReportsAnalyticsController.AllotmentPerformanceItem> mapPerformanceByLabel(
        List<KenReportsAnalyticsController.AllotmentPerformanceItem> rows
    ) {
        Map<String, KenReportsAnalyticsController.AllotmentPerformanceItem> response =
            new Map<String, KenReportsAnalyticsController.AllotmentPerformanceItem>();
        for (KenReportsAnalyticsController.AllotmentPerformanceItem row : rows) {
            response.put(row.label, row);
        }
        return response;
    }

    @IsTest
    static void testCycleAndWindowOptions() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'rptopt1',
            false,
            false
        );

        String directType = KenHostelTestHelper.getPicklistValue(
            Ken_Windows__c.Allotment_Type__c,
            'Direct Allotment'
        );
        Ken_Windows__c extraWindow = createWindow(
            context.cycle.Id,
            'Reports Window',
            directType,
            Date.today().addDays(-1),
            Date.today().addDays(4)
        );

        Test.startTest();
        List<KenReportsAnalyticsController.CycleOption> cycleOptions =
            KenReportsAnalyticsController.getCycleOptions();
        List<KenReportsAnalyticsController.WindowOption> windowOptions =
            KenReportsAnalyticsController.getWindowOptions(String.valueOf(context.cycle.Id));
        Test.stopTest();

        System.assertEquals(true, !cycleOptions.isEmpty(), 'Cycle options should include the created cycle.');
        System.assertEquals(true, windowOptions.size() >= 2, 'Both cycle windows should be returned.');

        Map<String, KenReportsAnalyticsController.WindowOption> optionsById = mapWindowOptionsById(windowOptions);
        System.assertEquals(
            'Preference Selected',
            optionsById.get(String.valueOf(context.window.Id)).allotmentType,
            'Preference flow window label should be normalized.'
        );
        System.assertEquals(
            'Direct Allotment',
            optionsById.get(String.valueOf(extraWindow.Id)).allotmentType,
            'Direct flow window label should be normalized.'
        );
    }

    @IsTest
    static void testPublicMethodsHandleBlankAndInvalidIds() {
        Test.startTest();
        List<KenReportsAnalyticsController.WindowOption> emptyWindowOptions =
            KenReportsAnalyticsController.getWindowOptions(null);
        KenReportsAnalyticsController.ReportSummaryResponse emptyReport =
            KenReportsAnalyticsController.getReportData(null);
        Test.stopTest();

        System.assertEquals(0, emptyWindowOptions.size(), 'Blank cycle id should return no windows.');
        System.assertEquals(0, emptyReport.totalAllocations, 'Blank window id should return zero metrics.');
        System.assertEquals(0, emptyReport.pendingApplications, 'Blank window id should return zero metrics.');
        System.assertEquals(0, emptyReport.buildingOccupancy.size(), 'Blank window id should return no chart rows.');
        System.assertEquals(0, emptyReport.allotmentDistribution.size(), 'Blank window id should return no distribution rows.');

        try {
            KenReportsAnalyticsController.getWindowOptions('not-an-id');
            System.assert(false, 'Invalid cycle id should raise an AuraHandledException.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex, 'Invalid cycle id should raise an AuraHandledException.');
        }

        try {
            KenReportsAnalyticsController.getReportData('not-an-id');
            System.assert(false, 'Invalid window id should raise an AuraHandledException.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex, 'Invalid window id should raise an AuraHandledException.');
        }
    }

    @IsTest
    static void testReportDataMatchesDashboardAndAccommodationCounts() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'rptsum1',
            false,
            false
        );

        String preferenceWindowType = KenHostelTestHelper.getPicklistValue(
            Ken_Windows__c.Allotment_Type__c,
            'Preference Selected'
        );
        Ken_Windows__c reportWindow = createWindow(
            context.cycle.Id,
            'Reports Analytics Window',
            preferenceWindowType,
            Date.today().addDays(-1),
            Date.today().addDays(10)
        );

        Ken_Room__c roomTwo = createRoomRecord(
            context.building.Id,
            context.floor.Id,
            context.roomCategory.Id,
            2,
            'RPT-2-' + Math.abs(Crypto.getRandomInteger()),
            context.roomCategory.Name__c
        );

        Ken_Building__c secondBuilding = KenHostelTestHelper.createBuildingDirect('Reports Building Two', 1);
        Floor__c secondFloor = KenHostelTestHelper.createFloor(secondBuilding.Id, 1);
        Ken_Room_Category__c secondCategory = KenHostelTestHelper.createRoomCategory('Reports Category Two', 3);
        Ken_Room__c roomThree = createRoomRecord(
            secondBuilding.Id,
            secondFloor.Id,
            secondCategory.Id,
            3,
            'RPT-3-' + Math.abs(Crypto.getRandomInteger()),
            secondCategory.Name__c
        );
        Ken_Room__c roomFour = createRoomRecord(
            secondBuilding.Id,
            secondFloor.Id,
            secondCategory.Id,
            1,
            'RPT-4-' + Math.abs(Crypto.getRandomInteger()),
            secondCategory.Name__c
        );

        String directType = KenHostelTestHelper.getPicklistValue(
            Ken_Room_Allotment__c.Allotment_Type__c,
            'Direct Allotment'
        );
        String confirmedType = KenHostelTestHelper.getPicklistValue(
            Ken_Room_Allotment__c.Allotment_Type__c,
            'Confirmed Allotment'
        );
        String provisionalType = KenHostelTestHelper.getPicklistValue(
            Ken_Room_Allotment__c.Allotment_Type__c,
            'Provisional Allotment'
        );
        String preferenceType = KenHostelTestHelper.getPicklistValue(
            Ken_Room_Allotment__c.Allotment_Type__c,
            'Preference Selected'
        );

        createAllotmentForWindow(context.room, reportWindow, 'rptalloc1', directType);
        createAllotmentForWindow(roomTwo, reportWindow, 'rptalloc2', confirmedType);
        createAllotmentForWindow(roomThree, reportWindow, 'rptalloc3', provisionalType);
        createAllotmentForWindow(roomFour, reportWindow, 'rptalloc4', preferenceType);

        createRequestForWindow(reportWindow, context.roomCategory, 'Pending', 'rptreq1');
        createRequestForWindow(reportWindow, context.roomCategory, null, 'rptreq2');
        createRequestForWindow(reportWindow, context.roomCategory, 'Alloted', 'rptreq3');
        createRequestForWindow(reportWindow, context.roomCategory, 'Rejected', 'rptreq4');

        Test.startTest();
        KenReportsAnalyticsController.ReportSummaryResponse reportData =
            KenReportsAnalyticsController.getReportData(String.valueOf(reportWindow.Id));
        Test.stopTest();

        System.assertEquals(4, reportData.totalAllocations, 'Allocated rows should match the report total allocations.');
        System.assertEquals(2, reportData.pendingApplications, 'Only pending-like in-progress statuses should be counted.');
        System.assertEquals(8, reportData.totalCapacity, 'Report total capacity should match scoped room capacity.');
        System.assertEquals(4, reportData.occupiedBeds, 'Active allotments should contribute to occupied beds.');
        System.assertEquals(Decimal.valueOf('50.0'), reportData.occupancyRate, 'Occupancy rate should match the dashboard calculation.');
        System.assertEquals(2, reportData.buildingOccupancy.size(), 'Two buildings should be represented in the building chart.');
        System.assertEquals(2, reportData.allotmentDistribution.size(), 'Distribution should be grouped into direct and provisional.');

        Map<String, KenReportsAnalyticsController.BuildingOccupancyItem> buildingItems =
            mapBuildingItemsByName(reportData.buildingOccupancy);
        System.assertEquals(
            2,
            buildingItems.get(context.building.Name__c).occupiedBeds,
            'Building one should show two occupied beds.'
        );
        System.assertEquals(
            2,
            buildingItems.get(context.building.Name__c).availableBeds,
            'Building one should show two available beds.'
        );
        System.assertEquals(
            50,
            buildingItems.get(context.building.Name__c).occupiedPercentage,
            'Building one occupied percentage should be based on room occupancy.'
        );
        System.assertEquals(
            2,
            buildingItems.get(secondBuilding.Name__c).occupiedBeds,
            'Building two should show two occupied beds.'
        );
        System.assertEquals(
            2,
            buildingItems.get(secondBuilding.Name__c).availableBeds,
            'Building two should show two available beds.'
        );
        System.assertEquals(
            50,
            buildingItems.get(secondBuilding.Name__c).occupiedPercentage,
            'Building two occupied percentage should be based on room occupancy.'
        );

        Map<String, KenReportsAnalyticsController.AllotmentDistributionItem> distributionItems =
            mapDistributionByLabel(reportData.allotmentDistribution);
        System.assertEquals(2, distributionItems.get('Direct').count, 'Direct distribution should include direct and confirmed allotments.');
        System.assertEquals(2, distributionItems.get('Provisional').count, 'Provisional distribution should include provisional and preference-selected allotments.');
    }

    @IsTest
    static void testReportDataRespectsWindowBuildingAndCategoryScope() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'rptscp1',
            false,
            false
        );

        Ken_Windows__c scopedWindow = KenHostelTestHelper.createWindowDirect(
            context.cycle.Id,
            null,
            context.building.Id,
            context.roomCategory.Id,
            'Scoped Reports Window',
            KenHostelTestHelper.getPicklistValue(Ken_Windows__c.Allotment_Type__c, 'Direct Allotment'),
            false
        );

        Ken_Building__c outOfScopeBuilding = KenHostelTestHelper.createBuildingDirect('Out Scope Building', 1);
        Floor__c outOfScopeFloor = KenHostelTestHelper.createFloor(outOfScopeBuilding.Id, 1);
        Ken_Room_Category__c outOfScopeCategory = KenHostelTestHelper.createRoomCategory('Out Scope Category', 1);
        Ken_Room__c outOfScopeRoom = createRoomRecord(
            outOfScopeBuilding.Id,
            outOfScopeFloor.Id,
            outOfScopeCategory.Id,
            1,
            'RPT-SCOPE-' + Math.abs(Crypto.getRandomInteger()),
            outOfScopeCategory.Name__c
        );

        String directType = KenHostelTestHelper.getPicklistValue(
            Ken_Room_Allotment__c.Allotment_Type__c,
            'Direct Allotment'
        );

        createAllotmentForWindow(context.room, scopedWindow, 'rptscope1', directType);
        createAllotmentForWindow(outOfScopeRoom, scopedWindow, 'rptscope2', directType);

        Test.startTest();
        KenReportsAnalyticsController.ReportSummaryResponse reportData =
            KenReportsAnalyticsController.getReportData(String.valueOf(scopedWindow.Id));
        Test.stopTest();

        System.assertEquals(
            1,
            reportData.totalAllocations,
            'Only allocations within the selected window building/category scope should be counted.'
        );
        System.assertEquals(
            2,
            reportData.totalCapacity,
            'Only scoped room capacity should be included in reports.'
        );
        System.assertEquals(
            1,
            reportData.buildingOccupancy.size(),
            'Only the scoped building should appear in the building occupancy chart.'
        );
        System.assertEquals(
            context.building.Name__c,
            reportData.buildingOccupancy[0].buildingName,
            'The in-scope building should be the only chart row.'
        );
        System.assertEquals(
            1,
            reportData.allotmentDistribution.size(),
            'Only the in-scope allocation type should appear in distribution.'
        );
        System.assertEquals(
            1,
            reportData.allotmentDistribution[0].count,
            'Only the in-scope allocation should contribute to distribution totals.'
        );
    }

    @IsTest
    static void testReportDataUsesRoomCategoryLabelsForCategoryCards() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'rptcat1',
            false,
            false
        );

        Ken_Building__c scopedBuilding = KenHostelTestHelper.createBuildingDirect('Reports Category Building', 1);
        Floor__c scopedFloor = KenHostelTestHelper.createFloor(scopedBuilding.Id, 1);
        Ken_Room_Category__c scopedCategory = KenHostelTestHelper.createRoomCategory(
            'Reports Category Label',
            2
        );
        String directWindowType = KenHostelTestHelper.getPicklistValue(
            Ken_Windows__c.Allotment_Type__c,
            'Direct Allotment'
        );
        Ken_Windows__c scopedWindow = KenHostelTestHelper.createWindowDirect(
            context.cycle.Id,
            null,
            scopedBuilding.Id,
            scopedCategory.Id,
            'Reports Category Window',
            directWindowType,
            false
        );
        Ken_Room__c scopedRoom = createRoomRecord(
            scopedBuilding.Id,
            scopedFloor.Id,
            scopedCategory.Id,
            2,
            'RPT-CAT-' + Math.abs(Crypto.getRandomInteger()),
            'Different Housing Label'
        );
        String directAllotmentType = KenHostelTestHelper.getPicklistValue(
            Ken_Room_Allotment__c.Allotment_Type__c,
            'Direct Allotment'
        );
        createAllotmentForWindow(scopedRoom, scopedWindow, 'rptcatalloc', directAllotmentType);

        Test.startTest();
        KenReportsAnalyticsController.ReportSummaryResponse reportData =
            KenReportsAnalyticsController.getReportData(String.valueOf(scopedWindow.Id));
        Test.stopTest();

        System.assertEquals(1, reportData.totalAllocations, 'The scoped allocation should be counted.');
        System.assertEquals(
            1,
            reportData.categoryRegistrations.size(),
            'The category registration card should show the scoped room category.'
        );
        System.assertEquals(
            scopedCategory.Name__c,
            reportData.categoryRegistrations[0].label,
            'Category registration should use the room category label.'
        );
        System.assertEquals(1, reportData.categoryRegistrations[0].registeredCount);
        System.assertEquals(1, reportData.categoryRegistrations[0].allottedCount);
        System.assertEquals(
            1,
            reportData.categoryOccupancy.size(),
            'The category occupancy card should show the scoped room category.'
        );
        System.assertEquals(
            scopedCategory.Name__c,
            reportData.categoryOccupancy[0].label,
            'Category occupancy should use the room category label.'
        );
        System.assertNotEquals(
            'Different Housing Label',
            reportData.categoryRegistrations[0].label,
            'Housing category should not override the room category label in reports.'
        );
    }

    @IsTest
    static void testReportDataReturnsMonthlyAllocationTrend() {
        Date cycleStart = Date.newInstance(Date.today().year(), 1, 1);
        Date cycleEnd = Date.newInstance(Date.today().year(), 8, 31);

        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'rpttrd1',
            false,
            false
        );

        update new Hostel_Cycle__c(
            Id = context.cycle.Id,
            Cycle_Start_Date_Time__c = Datetime.newInstance(cycleStart, Time.newInstance(0, 0, 0, 0)),
            Cycle_End_Date_Time__c = Datetime.newInstance(cycleEnd, Time.newInstance(23, 59, 0, 0))
        );

        String directWindowType = KenHostelTestHelper.getPicklistValue(
            Ken_Windows__c.Allotment_Type__c,
            'Direct Allotment'
        );
        Ken_Windows__c trendWindow = createWindow(
            context.cycle.Id,
            'Monthly Trend Window',
            directWindowType,
            cycleStart,
            cycleEnd
        );

        Ken_Room__c roomTwo = createRoomRecord(
            context.building.Id,
            context.floor.Id,
            context.roomCategory.Id,
            2,
            'RPT-TREND-2-' + Math.abs(Crypto.getRandomInteger()),
            context.roomCategory.Name__c
        );
        Ken_Room__c roomThree = createRoomRecord(
            context.building.Id,
            context.floor.Id,
            context.roomCategory.Id,
            2,
            'RPT-TREND-3-' + Math.abs(Crypto.getRandomInteger()),
            context.roomCategory.Name__c
        );
        Ken_Room__c roomFour = createRoomRecord(
            context.building.Id,
            context.floor.Id,
            context.roomCategory.Id,
            2,
            'RPT-TREND-4-' + Math.abs(Crypto.getRandomInteger()),
            context.roomCategory.Name__c
        );

        String directType = KenHostelTestHelper.getPicklistValue(
            Ken_Room_Allotment__c.Allotment_Type__c,
            'Direct Allotment'
        );
        String provisionalType = KenHostelTestHelper.getPicklistValue(
            Ken_Room_Allotment__c.Allotment_Type__c,
            'Provisional Allotment'
        );

        Ken_Room_Allotment__c januaryDirect = createAllotmentForWindow(context.room, trendWindow, 'rpttrendA', directType);
        Ken_Room_Allotment__c aprilDirect = createAllotmentForWindow(roomTwo, trendWindow, 'rpttrendB', directType);
        Ken_Room_Allotment__c aprilProvisional = createAllotmentForWindow(roomThree, trendWindow, 'rpttrendC', provisionalType);
        Ken_Room_Allotment__c augustProvisional = createAllotmentForWindow(roomFour, trendWindow, 'rpttrendD', provisionalType);

        setAllotmentCreatedDate(januaryDirect, Date.newInstance(cycleStart.year(), 1, 10));
        setAllotmentCreatedDate(aprilDirect, Date.newInstance(cycleStart.year(), 4, 14));
        setAllotmentCreatedDate(aprilProvisional, Date.newInstance(cycleStart.year(), 4, 18));
        setAllotmentCreatedDate(augustProvisional, Date.newInstance(cycleStart.year(), 8, 5));
        markAllotmentAsReassigned(aprilDirect.Id);

        Test.startTest();
        KenReportsAnalyticsController.ReportSummaryResponse reportData =
            KenReportsAnalyticsController.getReportData(String.valueOf(trendWindow.Id));
        Test.stopTest();

        System.assertEquals(
            8,
            reportData.monthlyAllocationTrend.size(),
            'The monthly trend should follow the selected cycle month range.'
        );

        Map<String, KenReportsAnalyticsController.MonthlyTrendItem> trendItems =
            mapTrendByMonthKey(reportData.monthlyAllocationTrend);

        System.assertEquals(1, trendItems.get(String.valueOf(cycleStart.year()) + '-01').directCount);
        System.assertEquals(0, trendItems.get(String.valueOf(cycleStart.year()) + '-01').provisionalCount);
        System.assertEquals(1, trendItems.get(String.valueOf(cycleStart.year()) + '-04').directCount);
        System.assertEquals(1, trendItems.get(String.valueOf(cycleStart.year()) + '-04').provisionalCount);
        System.assertEquals(1, trendItems.get(String.valueOf(cycleStart.year()) + '-08').provisionalCount);

        Integer expectedReassignmentCount = Schema.sObjectType.Ken_Room_Allotment__c.fields.getMap().containsKey('Reassigned__c')
            ? 1
            : 0;
        System.assertEquals(
            expectedReassignmentCount,
            trendItems.get(String.valueOf(cycleStart.year()) + '-04').reassignmentCount,
            'Reassigned active allotments should contribute to the reassignment trend.'
        );
    }

    @IsTest
    static void testReportDataReturnsAllotmentPerformanceSummary() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'rptperf1',
            false,
            false
        );

        String directWindowType = KenHostelTestHelper.getPicklistValue(
            Ken_Windows__c.Allotment_Type__c,
            'Direct Allotment'
        );
        Ken_Windows__c performanceWindow = createWindow(
            context.cycle.Id,
            'Performance Summary Window',
            directWindowType,
            Date.today().addDays(-5),
            Date.today().addDays(5)
        );

        Ken_Room__c roomTwo = createRoomRecord(
            context.building.Id,
            context.floor.Id,
            context.roomCategory.Id,
            2,
            'RPT-PERF-2-' + Math.abs(Crypto.getRandomInteger()),
            context.roomCategory.Name__c
        );
        Ken_Room__c roomThree = createRoomRecord(
            context.building.Id,
            context.floor.Id,
            context.roomCategory.Id,
            2,
            'RPT-PERF-3-' + Math.abs(Crypto.getRandomInteger()),
            context.roomCategory.Name__c
        );

        String directType = KenHostelTestHelper.getPicklistValue(
            Ken_Room_Allotment__c.Allotment_Type__c,
            'Direct Allotment'
        );
        String provisionalType = KenHostelTestHelper.getPicklistValue(
            Ken_Room_Allotment__c.Allotment_Type__c,
            'Provisional Allotment'
        );

        Ken_Room_Allotment__c directAllotment =
            createAllotmentForWindow(context.room, performanceWindow, 'rptperfA', directType);
        Ken_Room_Allotment__c provisionalAllotment =
            createAllotmentForWindow(roomTwo, performanceWindow, 'rptperfB', provisionalType);
        Ken_Room_Allotment__c reassignedAllotment =
            createAllotmentForWindow(roomThree, performanceWindow, 'rptperfC', directType);
        markAllotmentAsReassigned(reassignedAllotment.Id);

        createRequestLinkedToAllotment(
            performanceWindow,
            context.roomCategory,
            'Alloted',
            'rptperfReq1',
            directAllotment.Id
        );
        createRequestForWindow(performanceWindow, context.roomCategory, 'Pending', 'rptperfReq2');
        createRequestForWindow(performanceWindow, context.roomCategory, 'Rejected', 'rptperfReq3');
        createRequestLinkedToAllotment(
            performanceWindow,
            context.roomCategory,
            'Alloted',
            'rptperfReq4',
            provisionalAllotment.Id
        );
        createRequestLinkedToAllotment(
            performanceWindow,
            context.roomCategory,
            'Pending',
            'rptperfReq5',
            provisionalAllotment.Id
        );
        createRequestLinkedToAllotment(
            performanceWindow,
            context.roomCategory,
            'Alloted',
            'rptperfReq6',
            reassignedAllotment.Id
        );
        createRequestLinkedToAllotment(
            performanceWindow,
            context.roomCategory,
            'Pending',
            'rptperfReq7',
            reassignedAllotment.Id
        );
        createRequestForWindow(performanceWindow, context.roomCategory, 'Canceled', 'rptperfReq8');

        Test.startTest();
        KenReportsAnalyticsController.ReportSummaryResponse reportData =
            KenReportsAnalyticsController.getReportData(String.valueOf(performanceWindow.Id));
        Test.stopTest();

        System.assertEquals(
            4,
            reportData.allotmentPerformanceSummary.size(),
            'Performance summary should include direct, provisional, reassignment, and total rows.'
        );

        Map<String, KenReportsAnalyticsController.AllotmentPerformanceItem> itemsByLabel =
            mapPerformanceByLabel(reportData.allotmentPerformanceSummary);

        System.assert(itemsByLabel.get('Direct').totalApplications >= 3);
        System.assert(itemsByLabel.get('Direct').assignedCount >= 1);
        System.assert(itemsByLabel.get('Direct').rejectedCount >= 1);
        System.assert(itemsByLabel.get('Direct').pendingCount >= 1);
        System.assertEquals(
            itemsByLabel.get('Direct').assignedCount + itemsByLabel.get('Direct').rejectedCount + itemsByLabel.get('Direct').pendingCount,
            itemsByLabel.get('Direct').totalApplications
        );

        System.assert(itemsByLabel.get('Provisional').totalApplications >= 2);
        System.assert(itemsByLabel.get('Provisional').assignedCount >= 1);
        System.assert(itemsByLabel.get('Provisional').pendingCount >= 1);
        System.assertEquals(
            itemsByLabel.get('Provisional').assignedCount + itemsByLabel.get('Provisional').rejectedCount + itemsByLabel.get('Provisional').pendingCount,
            itemsByLabel.get('Provisional').totalApplications
        );

        Integer expectedReassignmentApplications = Schema.sObjectType.Ken_Room_Allotment__c.fields.getMap().containsKey('Reassigned__c')
            ? 2
            : 0;
        Integer expectedReassignmentAssigned = Schema.sObjectType.Ken_Room_Allotment__c.fields.getMap().containsKey('Reassigned__c')
            ? 1
            : 0;
        Integer expectedReassignmentPending = Schema.sObjectType.Ken_Room_Allotment__c.fields.getMap().containsKey('Reassigned__c')
            ? 1
            : 0;

        System.assert(itemsByLabel.get('Reassignment').totalApplications >= expectedReassignmentApplications);
        System.assert(itemsByLabel.get('Reassignment').assignedCount >= expectedReassignmentAssigned);
        System.assert(itemsByLabel.get('Reassignment').pendingCount >= expectedReassignmentPending);
        System.assertEquals(
            itemsByLabel.get('Reassignment').assignedCount
                + itemsByLabel.get('Reassignment').rejectedCount
                + itemsByLabel.get('Reassignment').pendingCount,
            itemsByLabel.get('Reassignment').totalApplications
        );

        Integer expectedTotalApplications = 5 + expectedReassignmentApplications;
        Integer expectedTotalAssigned = 2 + expectedReassignmentAssigned;
        Integer expectedTotalPending = 2 + expectedReassignmentPending;

        System.assert(itemsByLabel.get('Total').totalApplications >= expectedTotalApplications);
        System.assert(itemsByLabel.get('Total').assignedCount >= expectedTotalAssigned);
        System.assert(itemsByLabel.get('Total').rejectedCount >= 1);
        System.assert(itemsByLabel.get('Total').pendingCount >= expectedTotalPending);
        System.assertEquals(
            itemsByLabel.get('Direct').totalApplications
                + itemsByLabel.get('Provisional').totalApplications
                + itemsByLabel.get('Reassignment').totalApplications,
            itemsByLabel.get('Total').totalApplications
        );
        System.assertEquals(
            itemsByLabel.get('Direct').assignedCount
                + itemsByLabel.get('Provisional').assignedCount
                + itemsByLabel.get('Reassignment').assignedCount,
            itemsByLabel.get('Total').assignedCount
        );
        System.assertEquals(
            itemsByLabel.get('Direct').rejectedCount
                + itemsByLabel.get('Provisional').rejectedCount
                + itemsByLabel.get('Reassignment').rejectedCount,
            itemsByLabel.get('Total').rejectedCount
        );
        System.assertEquals(
            itemsByLabel.get('Direct').pendingCount
                + itemsByLabel.get('Provisional').pendingCount
                + itemsByLabel.get('Reassignment').pendingCount,
            itemsByLabel.get('Total').pendingCount
        );
        System.assertEquals(true, itemsByLabel.get('Total').isTotal);
        System.assertEquals('', itemsByLabel.get('Direct').avgAllocationTime);
        System.assertEquals('', itemsByLabel.get('Direct').trend);
    }
}