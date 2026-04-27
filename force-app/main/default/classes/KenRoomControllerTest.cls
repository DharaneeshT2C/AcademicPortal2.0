// Wrapper tests intentionally keep compact setup helpers for controller parity checks.
// code-analyzer-suppress(pmd:ApexUnitTestClassShouldHaveRunAs)
// code-analyzer-suppress(pmd:ExcessiveParameterList)
@IsTest
private class KenRoomControllerTest {
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

    private static Ken_Building__c createBuildingDirect(String buildingName, Integer floorCount, Boolean createFloors) {
        Ken_Building__c buildingRow = new Ken_Building__c(
            Name__c = buildingName,
            Hostel_Type__c = 'Male',
            Status__c = 'Active',
            Number_Of_Floors__c = String.valueOf(floorCount),
            Total_Floors__c = String.valueOf(floorCount),
            Warden_Assignment_Mode__c = 'Building Level'
        );
        insert buildingRow;

        if (createFloors == true) {
            List<Floor__c> floorsToInsert = new List<Floor__c>();
            for (Integer floorNumber = 1; floorNumber <= floorCount; floorNumber++) {
                floorsToInsert.add(new Floor__c(
                    Name = String.valueOf(floorNumber) + ' Floor',
                    Building__c = buildingRow.Id
                ));
            }
            insert floorsToInsert;
        }
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

    private static MasterDataRoomCategoryController.CreateRoomRequest buildRoomRequest(
        Id buildingId,
        String floorValue,
        String roomNumber,
        Id categoryId,
        String capacity,
        String statusValue
    ) {
        MasterDataRoomCategoryController.CreateRoomRequest requestData =
            new MasterDataRoomCategoryController.CreateRoomRequest();
        requestData.buildingValue = String.valueOf(buildingId);
        requestData.floorId = floorValue;
        requestData.roomNumber = roomNumber;
        requestData.roomCategoryId = String.valueOf(categoryId);
        requestData.capacity = capacity;
        requestData.statusValue = statusValue;
        return requestData;
    }

    private static MasterDataRoomCategoryController.BulkRoomCsvRow buildBulkRow(
        Integer rowNumber,
        String buildingName,
        String floorValue,
        String roomNumber,
        String categoryName,
        String capacity,
        String statusValue
    ) {
        MasterDataRoomCategoryController.BulkRoomCsvRow row =
            new MasterDataRoomCategoryController.BulkRoomCsvRow();
        row.rowNumber = rowNumber;
        row.building = buildingName;
        row.floor = floorValue;
        row.roomNumber = roomNumber;
        row.category = categoryName;
        row.capacity = capacity;
        row.status = statusValue;
        return row;
    }

    private static String findFloorOptionValue(
        MasterDataRoomCategoryController.RoomFormOptions options,
        Id buildingId,
        Integer floorNumber
    ) {
        if (options == null || options.floorOptions == null) {
            return null;
        }
        for (MasterDataRoomCategoryController.RoomFloorOption option : options.floorOptions) {
            if (
                option != null &&
                option.buildingValue == String.valueOf(buildingId) &&
                option.label == 'Floor ' + String.valueOf(floorNumber)
            ) {
                return option.value;
            }
        }
        return null;
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
    static void wrapperMethodsDelegateToMasterRoomController() {
        String suffix = uniqueSuffix('KRM');
        String bulkRoomNumber = 'WR-301-' + suffix;
        Ken_Room_Category__c existingCategory = createRoomCategoryDirect(
            'Wrapper Room Category ' + suffix,
            true
        );
        Ken_Building__c existingBuilding = createBuildingDirect(
            'Wrapper Existing Building ' + suffix,
            1,
            true
        );
        Id existingFloorId = getFloorId(existingBuilding.Id, 1);
        Ken_Room__c existingRoom = createRoomDirect(
            existingBuilding.Id,
            existingFloorId,
            existingCategory.Id,
            'WR-101-' + suffix,
            2,
            'Active'
        );
        Ken_Building__c createBuilding = createBuildingDirect(
            'Wrapper Create Building ' + suffix,
            2,
            false
        );

        Test.startTest();
        List<MasterDataRoomCategoryController.RoomRow> activeRooms = KenRoomController.getRooms('active');
        MasterDataRoomCategoryController.RoomFormOptions roomFormOptions = KenRoomController.getRoomFormOptions();
        MasterDataRoomCategoryController.RoomRow roomDetail =
            KenRoomController.getRoomById(String.valueOf(existingRoom.Id));
        MasterDataRoomCategoryController.RoomOccupancyDetailsRow occupancyDetails =
            KenRoomController.getRoomOccupancyDetails(String.valueOf(existingRoom.Id));

        String floorOneValue = findFloorOptionValue(roomFormOptions, createBuilding.Id, 1);
        Id createdRoomId = KenRoomController.createRoom(
            buildRoomRequest(createBuilding.Id, floorOneValue, 'WR-201-' + suffix, existingCategory.Id, '2', 'Active')
        );

        MasterDataRoomCategoryController.RoomFormOptions updatedOptions = KenRoomController.getRoomFormOptions();
        String floorTwoValue = findFloorOptionValue(updatedOptions, createBuilding.Id, 2);
        Id updatedRoomId = KenRoomController.updateRoom(
            String.valueOf(createdRoomId),
            buildRoomRequest(createBuilding.Id, floorTwoValue, 'WR-202-' + suffix, existingCategory.Id, '3', 'Inactive')
        );
        List<MasterDataRoomCategoryController.RoomRow> inactiveRooms = KenRoomController.getRooms('inactive');

        MasterDataRoomCategoryController.BulkRoomCsvResponse bulkResponse =
            KenRoomController.bulkCreateRoomsFromCsv(
                new List<MasterDataRoomCategoryController.BulkRoomCsvRow>{
                    buildBulkRow(1, createBuilding.Name__c, '2', bulkRoomNumber, existingCategory.Name__c, '2', 'Active'),
                    buildBulkRow(2, null, '2', 'WR-302-' + suffix, existingCategory.Name__c, '2', 'Active')
                }
            );

        KenRoomController.deleteRoom(String.valueOf(createdRoomId));
        Test.stopTest();

        System.assert(containsRoom(activeRooms, existingRoom.Id), 'Wrapper getRooms should return the existing room.');
        System.assertNotEquals(null, roomFormOptions, 'Wrapper getRoomFormOptions should return room form data.');
        System.assertNotEquals(null, roomDetail, 'Wrapper getRoomById should return room detail.');
        System.assertEquals(existingRoom.Id, roomDetail.id, 'Wrapper getRoomById should point to the existing room.');
        System.assertNotEquals(null, occupancyDetails, 'Wrapper getRoomOccupancyDetails should return data.');
        System.assertEquals(0, occupancyDetails.currentOccupants.size(), 'No allotments means no current occupants.');
        System.assertEquals(0, occupancyDetails.pastOccupants.size(), 'No allotments means no past occupants.');
        System.assertEquals(createdRoomId, updatedRoomId, 'Wrapper updateRoom should return the same room id.');
        System.assert(containsRoom(inactiveRooms, createdRoomId), 'Updated wrapper-created room should appear in the inactive list.');
        System.assertEquals(1, bulkResponse.successCount, 'Wrapper bulk room upload should create the valid row.');
        System.assert(bulkResponse.failureCount >= 1, 'Wrapper bulk room upload should report the invalid row.');
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Ken_Room__c WHERE Id = :createdRoomId],
            'Wrapper deleteRoom should remove the created room.'
        );
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Ken_Room__c WHERE Room_Number__c = :bulkRoomNumber],
            'Wrapper bulk upload should create the valid room.'
        );
    }
}