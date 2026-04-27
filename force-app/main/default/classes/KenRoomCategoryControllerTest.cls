// Wrapper tests intentionally keep compact setup helpers for controller parity checks.
// code-analyzer-suppress(pmd:ApexUnitTestClassShouldHaveRunAs)
// code-analyzer-suppress(pmd:ExcessiveParameterList)
@IsTest
private class KenRoomCategoryControllerTest {
    private static String uniqueSuffix(String prefixValue) {
        return prefixValue + String.valueOf(DateTime.now().getTime());
    }

    private static Ken_Room_Category__c createRoomCategoryDirect(String categoryName, Boolean isActive) {
        Ken_Room_Category__c categoryRow = new Ken_Room_Category__c(
            Name__c = categoryName,
            Description__c = categoryName + ' description',
            Gender_Allowed__c = 'Male',
            Sharing__c = 2,
            Capacity__c = 2,
            Ac_Non_Ac__c = 'Yes',
            Bathroom__c = 'Attached',
            Active__c = isActive,
            Amenities__c = 'King Bed;Air Conditioning;Shower'
        );
        insert categoryRow;
        return categoryRow;
    }

    private static Ken_Building__c createBuildingDirect(String buildingName, Integer floorCount) {
        Ken_Building__c buildingRow = new Ken_Building__c(
            Name__c = buildingName,
            Hostel_Type__c = 'Male',
            Status__c = 'Active',
            Number_Of_Floors__c = String.valueOf(floorCount),
            Total_Floors__c = String.valueOf(floorCount),
            Warden_Assignment_Mode__c = 'Building Level'
        );
        insert buildingRow;

        List<Floor__c> floorsToInsert = new List<Floor__c>();
        for (Integer floorNumber = 1; floorNumber <= floorCount; floorNumber++) {
            floorsToInsert.add(new Floor__c(
                Name = String.valueOf(floorNumber) + ' Floor',
                Building__c = buildingRow.Id
            ));
        }
        insert floorsToInsert;
        return buildingRow;
    }

    private static Id getFloorId(Id buildingId, Integer floorNumber) {
        String floorName = String.valueOf(floorNumber) + ' Floor';
        return [
            SELECT Id
            FROM Floor__c
            WHERE Building__c = :buildingId
              AND Name = :floorName
            LIMIT 1
        ].Id;
    }

    private static Ken_Room__c createRoomDirect(
        Id buildingId,
        Id floorId,
        Id categoryId,
        String roomNumber,
        Integer capacity,
        String statusValue
    ) {
        Ken_Room__c roomRow = new Ken_Room__c(
            Building__c = buildingId,
            Floor__c = floorId,
            Room_Category__c = categoryId,
            Room_Number__c = roomNumber,
            Capacity__c = capacity,
            Room_Status__c = statusValue,
            Consider_For_Allotment__c = true
        );
        insert roomRow;
        return roomRow;
    }

    private static MasterDataRoomCategoryController.CreateRoomCategoryRequest buildRequest(
        String categoryName,
        String statusValue
    ) {
        MasterDataRoomCategoryController.CreateRoomCategoryRequest requestData =
            new MasterDataRoomCategoryController.CreateRoomCategoryRequest();
        requestData.categoryName = categoryName;
        requestData.description = categoryName + ' description';
        requestData.genderAllowed = 'Male';
        requestData.sharing = '2';
        requestData.ac = 'AC';
        requestData.bathroom = 'Attached bathroom';
        requestData.statusValue = statusValue;
        requestData.amenities = new List<String>{ 'King Bed', 'Air Conditioning', 'Wrapper Amenity ' + categoryName };
        return requestData;
    }

    private static Boolean containsCategory(
        List<MasterDataRoomCategoryController.RoomCategoryRow> rows,
        Id categoryId
    ) {
        for (MasterDataRoomCategoryController.RoomCategoryRow row : rows) {
            if (row != null && row.id == categoryId) {
                return true;
            }
        }
        return false;
    }

    private static Boolean containsRoom(
        List<MasterDataRoomCategoryController.RoomRow> rows,
        Id roomId
    ) {
        for (MasterDataRoomCategoryController.RoomRow row : rows) {
            if (row != null && row.id == roomId) {
                return true;
            }
        }
        return false;
    }

    @IsTest
    static void wrapperMethodsDelegateToMasterController() {
        String suffix = uniqueSuffix('KRC');
        Ken_Room_Category__c baseCategory = createRoomCategoryDirect(
            'Wrapper Base Category ' + suffix,
            true
        );
        Ken_Building__c building = createBuildingDirect(
            'Wrapper Category Building ' + suffix,
            1
        );
        Id floorId = getFloorId(building.Id, 1);
        Ken_Room__c linkedRoom = createRoomDirect(
            building.Id,
            floorId,
            baseCategory.Id,
            'KC-101-' + suffix,
            2,
            'Active'
        );

        Test.startTest();
        List<MasterDataRoomCategoryController.RoomCategoryRow> activeCategories =
            KenRoomCategoryController.getRoomCategories('active');
        List<MasterDataRoomCategoryController.RoomRow> linkedRooms =
            KenRoomCategoryController.getLinkedRoomsByCategory(String.valueOf(baseCategory.Id));
        MasterDataRoomCategoryController.RoomCategoryActivityHistoryRow historyRow =
            KenRoomCategoryController.getRoomCategoryActivityHistory(String.valueOf(baseCategory.Id));
        MasterDataRoomCategoryController.RoomCategoryFormOptions formOptions =
            KenRoomCategoryController.getRoomCategoryFormOptions();
        MasterDataRoomCategoryController.RoomCategoryRow detailById =
            KenRoomCategoryController.getRoomCategoryDetail(String.valueOf(baseCategory.Id), null);
        MasterDataRoomCategoryController.RoomCategoryRow detailByName =
            KenRoomCategoryController.getRoomCategoryDetail(null, baseCategory.Name__c);
        MasterDataRoomCategoryController.OptionItem customAmenity =
            KenRoomCategoryController.addCustomAmenity('Wrapper Custom Amenity ' + suffix);

        Id createdCategoryId = KenRoomCategoryController.createRoomCategory(
            buildRequest('Wrapper Created Category ' + suffix, 'active')
        );
        Id updatedCategoryId = KenRoomCategoryController.updateRoomCategory(
            String.valueOf(createdCategoryId),
            buildRequest('Wrapper Updated Category ' + suffix, 'inactive')
        );
        KenRoomCategoryController.deleteRoomCategory(String.valueOf(createdCategoryId));
        Test.stopTest();

        System.assert(containsCategory(activeCategories, baseCategory.Id), 'Wrapper getRoomCategories should return the base category.');
        System.assert(containsRoom(linkedRooms, linkedRoom.Id), 'Wrapper getLinkedRoomsByCategory should return the linked room.');
        System.assertNotEquals(null, historyRow, 'Wrapper history call should return data.');
        System.assert(historyRow.events.size() >= 2, 'Wrapper history should include created and updated events.');
        System.assertNotEquals(null, formOptions, 'Wrapper form options should return data.');
        System.assertNotEquals(null, detailById, 'Wrapper detail lookup by id should work.');
        System.assertNotEquals(null, detailByName, 'Wrapper detail lookup by name should work.');
        System.assertEquals(baseCategory.Id, detailById.id, 'Detail by id should point to the base category.');
        System.assertEquals(baseCategory.Id, detailByName.id, 'Detail by name should point to the base category.');
        System.assertEquals('Wrapper Custom Amenity ' + suffix, customAmenity.value, 'Custom amenity should echo the input value.');
        System.assertEquals(createdCategoryId, updatedCategoryId, 'Update should return the same category id.');
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Ken_Room_Category__c WHERE Id = :createdCategoryId],
            'Wrapper delete should remove the created category.'
        );
    }
}