@IsTest
private class KenBuildingControllerTest {
    private static MasterDataRoomCategoryController.CreateBuildingRequest buildRequest(String nameValue, String wardenId) {
        MasterDataRoomCategoryController.CreateBuildingRequest requestRow =
            new MasterDataRoomCategoryController.CreateBuildingRequest();
        requestRow.buildingName = nameValue;
        requestRow.genderValue = KenHostelTestHelper.getPicklistValue(Ken_Building__c.Hostel_Type__c, null);
        requestRow.hostelTypeValue = requestRow.genderValue;
        requestRow.statusValue = KenHostelTestHelper.getPicklistValue(Ken_Building__c.Status__c, 'Active');
        requestRow.numberOfFloors = '2';
        requestRow.wardenMode = KenHostelTestHelper.getPicklistValue(
            Ken_Building__c.Warden_Assignment_Mode__c,
            'Building Level'
        );
        requestRow.buildingWarden = wardenId;
        return requestRow;
    }

    @IsTest
    static void testCreateAndReadBuildingData() {
        Account wardenAccount = KenHostelTestHelper.createPersonAccount(
            'Warden',
            'Building',
            'warden.building@example.com',
            'Warden'
        );

        Id buildingId = KenBuildingController.createBuilding(
            buildRequest('North Hostel', wardenAccount.Id)
        );

        System.assertNotEquals(null, buildingId);

        List<MasterDataRoomCategoryController.BuildingRow> buildings = KenBuildingController.getBuildings(null);
        System.assertEquals(true, !buildings.isEmpty(), 'Created building should appear in the list.');

        MasterDataRoomCategoryController.BuildingRow detail = KenBuildingController.getBuildingDetail(
            String.valueOf(buildingId),
            null
        );
        System.assertEquals('North Hostel', detail.name);
        System.assertEquals(wardenAccount.Name, detail.wardenName);

        List<MasterDataRoomCategoryController.BuildingFloorWardenRow> floorWardens =
            KenBuildingController.getBuildingFloorWardenDetails(String.valueOf(buildingId));
        System.assertEquals(2, floorWardens.size(), 'Building creation should seed two floors.');
        System.assertEquals(true, floorWardens[0].isInheritedFromBuilding);

        MasterDataRoomCategoryController.BuildingActivityHistoryRow history =
            KenBuildingController.getBuildingActivityHistory(String.valueOf(buildingId));
        System.assertNotEquals(null, history);
        System.assertEquals(true, history.events.size() >= 2);
    }

    @IsTest
    static void testUpdateAndDeleteBuilding() {
        Account wardenAccount = KenHostelTestHelper.createPersonAccount(
            'Warden',
            'Update',
            'warden.update@example.com',
            'Warden'
        );

        Id buildingId = KenBuildingController.createBuilding(
            buildRequest('South Hostel', wardenAccount.Id)
        );

        MasterDataRoomCategoryController.CreateBuildingRequest updateRequest =
            buildRequest('South Hostel Updated', wardenAccount.Id);
        updateRequest.numberOfFloors = '3';

        Id updatedId = KenBuildingController.updateBuilding(String.valueOf(buildingId), updateRequest);
        System.assertEquals(buildingId, updatedId);

        MasterDataRoomCategoryController.BuildingRow detail = KenBuildingController.getBuildingDetail(
            String.valueOf(buildingId),
            null
        );
        System.assertEquals('South Hostel Updated', detail.name);

        KenBuildingController.deleteBuilding(String.valueOf(buildingId));

        System.assertEquals(
            0,
            [SELECT Count() FROM Ken_Building__c WHERE Id = :buildingId],
            'Building should be deleted.'
        );
    }
}