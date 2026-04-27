@IsTest
private class HostelDashboardControllerTest {
    @IsTest
    static void testGetDashboardDataWithCurrentAllotment() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContextForCurrentUser(
            'hosteld1',
            true,
            false
        );

        HostelDashboardController.DashboardResponse dashboard;
        HostelDashboardController.HostelDetailsResponse details;
        Test.startTest();
        dashboard = HostelDashboardController.getDashboardData();
        details = HostelDashboardController.getHostelDetailsData();
        Test.stopTest();

        System.assertEquals(true, dashboard.hasAllotment);
        System.assertEquals(true, details.hasAllotment);
        System.assertEquals(context.room.Room_Number__c, details.residenceDetails.title);
        System.assertEquals(context.roomCategory.Name__c, details.residenceDetails.subtitle);
    }

    @IsTest
    static void testGetSelectionDataAndSaveResidencePreferences() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContextForCurrentUser(
            'hosteld2',
            false,
            false
        );

        HostelDashboardController.ResidenceSelectionResponse selectionData =
            HostelDashboardController.getResidencePreferenceSelectionData();

        System.assertEquals(1, selectionData.residences.size(), 'Eligible category should be returned.');
        System.assertEquals(
            true,
            selectionData.residences[0].floorOptions.contains(KenHostelTestHelper.toFloorLabel(1))
        );

        HostelDashboardController.ResidenceSelectionPreferenceInput inputRow =
            new HostelDashboardController.ResidenceSelectionPreferenceInput();
        inputRow.residenceId = String.valueOf(context.roomCategory.Id);
        inputRow.order = 1;
        inputRow.floor = KenHostelTestHelper.toFloorLabel(1);
        inputRow.roommateEmails = new List<String>();

        Test.startTest();
        HostelDashboardController.SaveResidencePreferencesResponse saveResponse =
            HostelDashboardController.saveResidencePreferences(
                new List<HostelDashboardController.ResidenceSelectionPreferenceInput>{ inputRow },
                true
            );
        HostelDashboardController.ResidenceAllocationResponse allocationResponse =
            HostelDashboardController.getResidenceAllocationData();
        Test.stopTest();

        System.assertEquals(true, saveResponse.success, saveResponse.message);
        System.assertEquals('Pending', saveResponse.status);
        System.assertEquals(1, allocationResponse.preferenceCount);

        Ken_Room_Request__c savedRequest = [
            SELECT Request_By__c, Requested_By__c, Window__c, Status__c, Preference_1__c, Floor_Preference_1__c
            FROM Ken_Room_Request__c
            WHERE Requested_By__c = :context.studentContact.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(context.studentAccount.Id, savedRequest.Request_By__c);
        System.assertEquals(context.studentContact.Id, savedRequest.Requested_By__c);
        System.assertEquals(context.window.Id, savedRequest.Window__c);
        System.assertEquals('Pending', savedRequest.Status__c);
        System.assertEquals(context.roomCategory.Id, savedRequest.Preference_1__c);
        System.assertEquals(KenHostelTestHelper.toFloorLabel(1), savedRequest.Floor_Preference_1__c);
    }

    @IsTest
    static void testGetDashboardDataAllowsGetStartedWhenEligibleWindowExists() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContextForCurrentUser(
            'hosteld3',
            false,
            false
        );

        HostelDashboardController.DashboardResponse dashboard;
        Test.startTest();
        dashboard = HostelDashboardController.getDashboardData();
        Test.stopTest();

        System.assertEquals(true, dashboard.canStartResidenceAllocation);
        System.assertEquals(String.valueOf(context.window.Start_Date__c), dashboard.windowStartDate);
        System.assertEquals(String.valueOf(context.window.End_Date__c), dashboard.windowEndDate);
    }
}