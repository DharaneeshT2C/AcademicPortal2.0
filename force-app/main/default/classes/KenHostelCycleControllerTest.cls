@IsTest
private class KenHostelCycleControllerTest {
    private static KenHostelCycleController.CreateCycleRequest buildCycleRequest(String nameValue, AcademicYear yearRow) {
        KenHostelCycleController.CreateCycleRequest requestRow = new KenHostelCycleController.CreateCycleRequest();
        requestRow.name = nameValue;
        requestRow.academicYearIds = new List<String>{ String.valueOf(yearRow.Id) };
        requestRow.startDate = String.valueOf(DateTime.newInstance(Date.today().addDays(2), Time.newInstance(10, 0, 0, 0)));
        requestRow.endDate = String.valueOf(DateTime.newInstance(Date.today().addDays(20), Time.newInstance(10, 0, 0, 0)));
        requestRow.status = KenHostelTestHelper.getPicklistValue(Hostel_Cycle__c.Status__c, 'Open');
        requestRow.carryForwardEnabled = false;
        return requestRow;
    }

    private static KenHostelCycleController.SaveWindowRequest buildWindowRequest(
        LearningProgramPlan planRow,
        Ken_Building__c buildingRow,
        Ken_Room_Category__c categoryRow
    ) {
        KenHostelCycleController.SaveWindowRequest requestRow = new KenHostelCycleController.SaveWindowRequest();
        requestRow.name = 'Window Setup';
        requestRow.startDate = String.valueOf(Date.today().addDays(3));
        requestRow.endDate = String.valueOf(Date.today().addDays(8));
        requestRow.startTime = '09:00';
        requestRow.endTime = '18:00';
        requestRow.paymentDeadline = String.valueOf(Date.today().addDays(9));
        requestRow.allotmentType = 'Preference Selected';
        requestRow.enableRoomPreference = true;
        requestRow.maxRoomPreferences = '3';
        requestRow.allowRoommatePreference = false;
        requestRow.enableMaximumRoomCapacity = false;
        requestRow.programPathwayIds = new List<String>{ String.valueOf(planRow.Id) };
        requestRow.buildingIds = new List<String>{ String.valueOf(buildingRow.Id) };
        requestRow.roomCategoryIds = new List<String>{ String.valueOf(categoryRow.Id) };
        requestRow.buildingAllocationRows = new List<KenHostelCycleController.BuildingAllocationRow>();
        return requestRow;
    }

    @IsTest
    static void testCreateCycleAndCycleOptions() {
        AcademicYear yearRow = KenHostelTestHelper.createAcademicYear('2027-2028');
        Id cycleId = KenHostelCycleController.createCycle(buildCycleRequest('Cycle Test', yearRow));

        List<KenHostelCycleController.CycleRow> cycles = KenHostelCycleController.getCycles();
        List<KenHostelCycleController.OptionItem> academicYears = KenHostelCycleController.getAcademicYearOptions();
        List<KenHostelCycleController.OptionItem> previousCycles = KenHostelCycleController.getPreviousCycleOptions();
        List<KenHostelCycleController.OptionItem> statuses = KenHostelCycleController.getStatusOptions();

        Boolean cycleFound = false;
        Boolean academicYearFound = false;
        Boolean previousCycleFound = false;
        for (KenHostelCycleController.CycleRow row : cycles) {
            if (row.id == cycleId) {
                cycleFound = true;
                break;
            }
        }
        for (KenHostelCycleController.OptionItem item : academicYears) {
            if (item.value == String.valueOf(yearRow.Id)) {
                academicYearFound = true;
                break;
            }
        }
        for (KenHostelCycleController.OptionItem item : previousCycles) {
            if (item.value == String.valueOf(cycleId)) {
                previousCycleFound = true;
                break;
            }
        }

        System.assertNotEquals(null, cycleId);
        System.assertEquals(true, cycleFound, 'Created cycle should be returned.');
        System.assertEquals(true, academicYearFound, 'Academic year option should include the created year.');
        System.assertEquals(true, previousCycleFound, 'Previous cycle options should include the created cycle.');
        System.assertEquals(true, !statuses.isEmpty());
    }

    @IsTest
    static void testCreateWindowAndReadWindowData() {
        AcademicYear yearRow = KenHostelTestHelper.createAcademicYear('2028-2029');
        Id cycleId = KenHostelCycleController.createCycle(buildCycleRequest('Window Cycle', yearRow));

        LearningProgramPlan planRow = KenHostelTestHelper.createLearningProgramPlan('window');
        Ken_Building__c buildingRow = KenHostelTestHelper.createBuildingDirect('Window Building', 1);
        Floor__c floorRow = KenHostelTestHelper.createFloor(buildingRow.Id, 1);
        Ken_Room_Category__c categoryRow = KenHostelTestHelper.createRoomCategory('Window Category', 2);
        KenHostelTestHelper.createRoom(
            buildingRow.Id,
            floorRow.Id,
            categoryRow.Id,
            2,
            'W101',
            categoryRow.Name__c
        );

        KenHostelCycleController.WindowFormOptions formOptions = KenHostelCycleController.getWindowFormOptions();
        System.assertEquals(true, !formOptions.programPathways.isEmpty(), 'Program plans should be available.');
        System.assertEquals(true, !formOptions.buildings.isEmpty(), 'Buildings should be available.');
        System.assertEquals(true, !formOptions.floors.isEmpty(), 'Floors should be available.');
        System.assertEquals(true, !formOptions.roomCategories.isEmpty(), 'Room categories should be available.');

        Id windowId = KenHostelCycleController.createWindow(
            String.valueOf(cycleId),
            buildWindowRequest(planRow, buildingRow, categoryRow)
        );

        List<KenHostelCycleController.WindowRow> windows = KenHostelCycleController.getWindows(String.valueOf(cycleId));
        List<KenHostelCycleController.BuildingAllocationRow> preview = KenHostelCycleController.getBuildingAllocationPreview(
            new List<String>{ String.valueOf(buildingRow.Id) },
            new List<String>{ String.valueOf(categoryRow.Id) }
        );

        System.assertNotEquals(null, windowId);
        System.assertEquals(1, windows.size());
        System.assertEquals('Window Setup', windows[0].name);
        System.assertEquals(true, !preview.isEmpty(), 'Allocation preview should include the selected building.');
    }
}