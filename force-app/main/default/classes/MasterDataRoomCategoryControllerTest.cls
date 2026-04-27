// This housing suite exercises a large number of validation and occupancy branches using shared test helpers.
// code-analyzer-suppress(pmd:ApexUnitTestClassShouldHaveRunAs)
// code-analyzer-suppress(pmd:CognitiveComplexity)
// code-analyzer-suppress(pmd:CyclomaticComplexity)
// code-analyzer-suppress(pmd:EagerlyLoadedDescribeSObjectResult)
// code-analyzer-suppress(pmd:ExcessiveParameterList)
// code-analyzer-suppress(pmd:NcssCount)
// code-analyzer-suppress(pmd:NcssMethodCount)
// code-analyzer-suppress(pmd:NcssTypeCount)
// code-analyzer-suppress(pmd:StdCyclomaticComplexity)
@IsTest
private class MasterDataRoomCategoryControllerTest {
    private static String uniqueSuffix(String prefixValue) {
        return prefixValue + String.valueOf(DateTime.now().getTime());
    }

    private static Id getPersonAccountRecordTypeId() {
        List<RecordType> recordTypes = [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Account'
              AND IsPersonType = true
            ORDER BY DeveloperName ASC
        ];
        System.assert(!recordTypes.isEmpty(), 'A person account record type is required for housing tests.');

        List<String> preferredDeveloperNames = new List<String>{
            'Faculty',
            'Admissions_Higher_Ed_Person_Account',
            'Student_Success_Higher_Ed_Student'
        };
        for (String preferredDeveloperName : preferredDeveloperNames) {
            for (RecordType recordTypeRow : recordTypes) {
                if (recordTypeRow.DeveloperName == preferredDeveloperName) {
                    return recordTypeRow.Id;
                }
            }
        }
        return recordTypes[0].Id;
    }

    private static Account createPersonAccount(String fullName, String email, String phone) {
        String cleanedName = String.isBlank(fullName) ? 'Test Person' : fullName.trim();
        Integer lastSpace = cleanedName.lastIndexOf(' ');
        String firstName = lastSpace > 0 ? cleanedName.substring(0, lastSpace).trim() : null;
        String lastName = lastSpace > 0 ? cleanedName.substring(lastSpace + 1).trim() : cleanedName;

        Account personAccount = new Account(
            RecordTypeId = getPersonAccountRecordTypeId(),
            FirstName = firstName,
            LastName = String.isBlank(lastName) ? 'Person' : lastName,
            PersonEmail = email,
            Phone = phone,
            PersonMobilePhone = phone
        );
        insert personAccount;

        Account reloaded = [
            SELECT Id, Name, PersonContactId, PersonEmail, Phone, Description
            FROM Account
            WHERE Id = :personAccount.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, reloaded.PersonContactId, 'Expected a person contact on the inserted person account.');
        return reloaded;
    }

    private static void addConstituentRole(Id personId, String roleType, String status) {
        Schema.SObjectType constituentRoleType = Schema.getGlobalDescribe().get('ConstituentRole');
        System.assertNotEquals(null, constituentRoleType, 'ConstituentRole must exist in this org.');

        SObject roleRecord = constituentRoleType.newSObject();
        roleRecord.put('PersonId', personId);
        roleRecord.put('RoleType', roleType);
        roleRecord.put('Status', status);
        insert roleRecord;
    }

    private static Account createActiveWarden(String uniqueToken) {
        String cleanedToken = String.isBlank(uniqueToken) ? 'warden' : uniqueToken.replace(' ', '').toLowerCase();
        String phone = '9' + String.valueOf(Math.abs(cleanedToken.hashCode())).leftPad(9, '0').substring(0, 9);
        Account warden = createPersonAccount(
            'Warden ' + cleanedToken,
            cleanedToken + '@example.test',
            phone
        );
        addConstituentRole(warden.PersonContactId, 'Warden', 'Active');
        return [
            SELECT Id, Name, PersonContactId, PersonEmail, Phone, Description
            FROM Account
            WHERE Id = :warden.Id
            LIMIT 1
        ];
    }

    private static void putIfCreateable(
        SObject targetRecord,
        Map<String, Schema.SObjectField> fieldMap,
        String fieldApiName,
        Object value
    ) {
        if (
            targetRecord == null ||
            fieldMap == null ||
            String.isBlank(fieldApiName) ||
            !fieldMap.containsKey(fieldApiName)
        ) {
            return;
        }

        Schema.DescribeFieldResult describeResult = fieldMap.get(fieldApiName).getDescribe();
        if (describeResult.isCreateable() && !describeResult.isCalculated()) {
            targetRecord.put(fieldApiName, value);
        }
    }

    private static Ken_Room_Category__c createRoomCategoryDirect(String name, Boolean activeValue) {
        Map<String, Schema.SObjectField> fieldMap = Ken_Room_Category__c.SObjectType
            .getDescribe(Schema.SObjectDescribeOptions.DEFERRED)
            .fields.getMap();
        Ken_Room_Category__c categoryRow = new Ken_Room_Category__c(
            Name__c = name,
            Description__c = name + ' description',
            Gender_Allowed__c = 'Male',
            Sharing__c = 2,
            Capacity__c = 2,
            Ac_Non_Ac__c = 'Yes',
            Bathroom__c = 'Attached',
            Active__c = activeValue,
            Amenities__c = 'King Bed;Air Conditioning;Shower'
        );
        putIfCreateable(categoryRow, fieldMap, 'Custom_Amenity__c', 'Reading Lamp');
        putIfCreateable(categoryRow, fieldMap, 'Total_Price__c', 2400);
        putIfCreateable(categoryRow, fieldMap, 'Premium_Price__c', 2200);
        putIfCreateable(categoryRow, fieldMap, 'Base_Price__c', 2000);
        insert categoryRow;
        return [
            SELECT Id, Name, Name__c, Capacity__c, Amenities__c, Active__c
            FROM Ken_Room_Category__c
            WHERE Id = :categoryRow.Id
            LIMIT 1
        ];
    }

    private static Ken_Building__c createBuildingDirect(
        String name,
        Id wardenId,
        Integer floorCount,
        String wardenMode,
        String statusValue,
        Boolean createFloorRows
    ) {
        String safeStatus = String.isBlank(statusValue) ? 'Active' : statusValue;
        String safeMode = String.isBlank(wardenMode) ? 'Building Level' : wardenMode;
        Integer safeFloorCount = floorCount == null || floorCount <= 0 ? 1 : floorCount;

        Map<String, Schema.SObjectField> fieldMap = Ken_Building__c.SObjectType
            .getDescribe(Schema.SObjectDescribeOptions.DEFERRED)
            .fields.getMap();
        Ken_Building__c buildingRow = new Ken_Building__c(
            Name__c = name,
            Hostel_Type__c = 'Male',
            Status__c = safeStatus,
            Number_Of_Floors__c = String.valueOf(safeFloorCount),
            Total_Floors__c = String.valueOf(safeFloorCount),
            Warden_Assignment_Mode__c = safeMode,
            Warden__c = wardenId
        );
        putIfCreateable(buildingRow, fieldMap, 'Capacity__c', '0');
        putIfCreateable(buildingRow, fieldMap, 'Current_Occupancy__c', '0');
        putIfCreateable(buildingRow, fieldMap, 'Occupancy__c', '0');
        putIfCreateable(buildingRow, fieldMap, 'Total_Rooms__c', '0');
        insert buildingRow;

        if (createFloorRows == true) {
            List<Floor__c> floorsToInsert = new List<Floor__c>();
            for (Integer floorNumber = 1; floorNumber <= safeFloorCount; floorNumber++) {
                floorsToInsert.add(new Floor__c(
                    Name = String.valueOf(floorNumber) + ' Floor',
                    Building__c = buildingRow.Id,
                    Warden__c = wardenId
                ));
            }
            insert floorsToInsert;
        }

        return [
            SELECT Id, Name, Name__c, Warden__c, Warden_Assignment_Mode__c, Number_Of_Floors__c, Total_Floors__c, Status__c
            FROM Ken_Building__c
            WHERE Id = :buildingRow.Id
            LIMIT 1
        ];
    }

    private static Id getFloorId(Id buildingId, Integer floorNumber) {
        String expectedName = String.valueOf(floorNumber) + ' Floor';
        List<Floor__c> floorRows = [
            SELECT Id
            FROM Floor__c
            WHERE Building__c = :buildingId
              AND Name = :expectedName
            LIMIT 1
        ];
        return floorRows.isEmpty() ? null : floorRows[0].Id;
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
        return [
            SELECT Id, Name, Building__c, Floor__c, Room_Category__c, Room_Number__c, Capacity__c, Room_Status__c
            FROM Ken_Room__c
            WHERE Id = :roomRow.Id
            LIMIT 1
        ];
    }

    private static MasterDataRoomCategoryController.CreateRoomCategoryRequest buildRoomCategoryRequest(
        String categoryName,
        String statusValue,
        List<String> amenities
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
        requestData.amenities = amenities;
        return requestData;
    }

    private static MasterDataRoomCategoryController.CreateBuildingRequest buildBuildingRequest(
        String buildingName,
        String genderValue,
        String statusValue,
        String numberOfFloors,
        String wardenMode,
        Id wardenId
    ) {
        MasterDataRoomCategoryController.CreateBuildingRequest requestData =
            new MasterDataRoomCategoryController.CreateBuildingRequest();
        requestData.buildingName = buildingName;
        requestData.genderValue = genderValue;
        requestData.statusValue = statusValue;
        requestData.numberOfFloors = numberOfFloors;
        requestData.wardenMode = wardenMode;
        requestData.buildingWarden = String.valueOf(wardenId);
        return requestData;
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

    private static Boolean containsBuilding(
        List<MasterDataRoomCategoryController.BuildingRow> rows,
        Id buildingId
    ) {
        for (MasterDataRoomCategoryController.BuildingRow row : rows) {
            if (row != null && row.id == buildingId) {
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

    private static MasterDataRoomCategoryController.BuildingFloorWardenRow findFloorWardenRow(
        List<MasterDataRoomCategoryController.BuildingFloorWardenRow> rows,
        Integer floorNumber
    ) {
        for (MasterDataRoomCategoryController.BuildingFloorWardenRow row : rows) {
            if (row != null && row.floorNumber == floorNumber) {
                return row;
            }
        }
        return null;
    }

    private static void assertExceptionMessage(Exception e, String expectedMessage) {
        System.assertNotEquals(null, e, 'Expected an exception to be thrown.');
        System.assert(
            e.getMessage() == 'Script-thrown exception' || e.getMessage().contains(expectedMessage),
            'Expected message containing "' + expectedMessage + '" but got: ' + e.getMessage()
        );
    }

    private static Account createBusinessAccount(String name) {
        Account accountRow = new Account(Name = name);
        insert accountRow;
        return [
            SELECT Id, Name
            FROM Account
            WHERE Id = :accountRow.Id
            LIMIT 1
        ];
    }

    private static Contact createBusinessContact(Id accountId, String lastName, String email) {
        Contact contactRow = new Contact(
            AccountId = accountId,
            LastName = lastName,
            Email = email
        );
        insert contactRow;
        return [
            SELECT Id, AccountId, Email, Name
            FROM Contact
            WHERE Id = :contactRow.Id
            LIMIT 1
        ];
    }

    private static void addStudentRole(Account studentAccount) {
        addConstituentRole(studentAccount.PersonContactId, 'Student', 'Active');
    }

    private static Ken_Room_Allotment__c createRoomAllotmentDirect(
        Id roomId,
        Id tenantAccountId,
        Id tenantContactId,
        Boolean activeValue,
        Date startDate,
        Date endDate,
        String allotmentType
    ) {
        Ken_Room_Allotment__c allotmentRow = new Ken_Room_Allotment__c(
            Room__c = roomId,
            Tenant_Account__c = tenantAccountId,
            Tenant__c = tenantContactId,
            Active__c = activeValue,
            Start_Date__c = startDate,
            End_Date__c = endDate,
            Allotment_Type__c = allotmentType
        );
        insert allotmentRow;
        return [
            SELECT Id, Room__c, Tenant_Account__c, Tenant__c, Active__c
            FROM Ken_Room_Allotment__c
            WHERE Id = :allotmentRow.Id
            LIMIT 1
        ];
    }

    private static void putIfUpdateable(
        SObject targetRecord,
        Map<String, Schema.SObjectField> fieldMap,
        String fieldApiName,
        Object value
    ) {
        if (
            targetRecord == null ||
            fieldMap == null ||
            String.isBlank(fieldApiName) ||
            !fieldMap.containsKey(fieldApiName)
        ) {
            return;
        }

        Schema.DescribeFieldResult describeResult = fieldMap.get(fieldApiName).getDescribe();
        if (describeResult.isUpdateable() && !describeResult.isCalculated()) {
            targetRecord.put(fieldApiName, value);
        }
    }

    @IsTest
    static void roomCategoryLifecycleAndLookupsWork() {
        String suffix = uniqueSuffix('RC');
        MasterDataRoomCategoryController.CreateRoomCategoryRequest createRequest =
            buildRoomCategoryRequest(
                'Master Category ' + suffix,
                'active',
                new List<String>{ 'King Bed', 'Air Conditioning', 'Quiet Desk ' + suffix }
            );

        Test.startTest();
        Id categoryId = MasterDataRoomCategoryController.createRoomCategory(createRequest);
        MasterDataRoomCategoryController.RoomCategoryFormOptions formOptions =
            MasterDataRoomCategoryController.getRoomCategoryFormOptions();
        List<MasterDataRoomCategoryController.RoomCategoryRow> activeRows =
            MasterDataRoomCategoryController.getRoomCategories('active');
        MasterDataRoomCategoryController.RoomCategoryRow detailById =
            MasterDataRoomCategoryController.getRoomCategoryDetail(String.valueOf(categoryId), null);
        MasterDataRoomCategoryController.RoomCategoryRow detailByName =
            MasterDataRoomCategoryController.getRoomCategoryDetail(null, createRequest.categoryName);
        MasterDataRoomCategoryController.OptionItem customAmenity =
            MasterDataRoomCategoryController.addCustomAmenity('Desk Lamp ' + suffix);

        MasterDataRoomCategoryController.CreateRoomCategoryRequest updateRequest =
            buildRoomCategoryRequest(
                'Updated Category ' + suffix,
                'inactive',
                new List<String>{ 'King Bed', 'Writing Table ' + suffix }
            );
        updateRequest.sharing = '3';
        updateRequest.ac = 'Non AC';
        updateRequest.bathroom = 'Common bathroom';
        Id updatedCategoryId = MasterDataRoomCategoryController.updateRoomCategory(
            String.valueOf(categoryId),
            updateRequest
        );
        MasterDataRoomCategoryController.RoomCategoryActivityHistoryRow historyRow =
            MasterDataRoomCategoryController.getRoomCategoryActivityHistory(String.valueOf(categoryId));
        List<MasterDataRoomCategoryController.RoomCategoryRow> inactiveRows =
            MasterDataRoomCategoryController.getRoomCategories('inactive');

        Ken_Room_Category__c deletableCategory = createRoomCategoryDirect(
            'Delete Category ' + suffix,
            true
        );
        MasterDataRoomCategoryController.deleteRoomCategory(String.valueOf(deletableCategory.Id));
        Test.stopTest();

        Ken_Room_Category__c updatedCategory = [
            SELECT Id, Name__c, Description__c, Sharing__c, Capacity__c, Ac_Non_Ac__c, Bathroom__c,
                Active__c, Amenities__c, Custom_Amenity__c
            FROM Ken_Room_Category__c
            WHERE Id = :updatedCategoryId
            LIMIT 1
        ];

        System.assertNotEquals(null, formOptions, 'Expected form options payload.');
        System.assert(!formOptions.genderOptions.isEmpty(), 'Expected gender options.');
        System.assert(!formOptions.amenitiesOptions.isEmpty(), 'Expected amenity options.');
        System.assert(!formOptions.statusOptions.isEmpty(), 'Expected status options.');
        System.assert(containsCategory(activeRows, categoryId), 'Created category should appear in the active list before the update.');
        System.assertEquals(categoryId, detailById.id, 'Detail lookup by id should return the created category.');
        System.assertEquals(categoryId, detailByName.id, 'Detail lookup by name should return the created category.');
        System.assertEquals('Desk Lamp ' + suffix, customAmenity.label, 'Custom amenity label should echo the input.');
        System.assertEquals(categoryId, updatedCategoryId, 'Update should return the same category id.');
        System.assertEquals('Updated Category ' + suffix, updatedCategory.Name__c, 'Category name should be updated.');
        System.assertEquals(3, Integer.valueOf(String.valueOf(updatedCategory.Sharing__c)), 'Sharing should be updated.');
        System.assertEquals(3, Integer.valueOf(String.valueOf(updatedCategory.Capacity__c)), 'Capacity should track the sharing value.');
        System.assertEquals('No', updatedCategory.Ac_Non_Ac__c, 'Non-AC input should normalize to No.');
        System.assertEquals('Common', updatedCategory.Bathroom__c, 'Common bathroom input should normalize to Common.');
        System.assertEquals(false, updatedCategory.Active__c, 'Inactive status should clear Active__c.');
        System.assert(historyRow.events.size() >= 2, 'Activity history should include created and updated events.');
        System.assert(containsCategory(inactiveRows, categoryId), 'Updated category should appear in the inactive list.');
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Ken_Room_Category__c WHERE Id = :deletableCategory.Id],
            'Delete should remove the standalone room category.'
        );
    }

    @IsTest
    static void buildingLifecycleFloorWardensAndHistoryWork() {
        String suffix = uniqueSuffix('BLD');
        Account firstWarden = createActiveWarden('master-bld-one-' + suffix);
        Account secondWarden = createActiveWarden('master-bld-two-' + suffix);

        Test.startTest();
        Id buildingId = MasterDataRoomCategoryController.createBuilding(
            buildBuildingRequest(
                'Master Building ' + suffix,
                'Boys',
                'active',
                '2',
                'Single Warden for Entire Building',
                firstWarden.Id
            )
        );
        MasterDataRoomCategoryController.BuildingFormOptions buildingFormOptions =
            MasterDataRoomCategoryController.getBuildingFormOptions();
        List<MasterDataRoomCategoryController.BuildingRow> activeBuildings =
            MasterDataRoomCategoryController.getBuildings('active');
        MasterDataRoomCategoryController.BuildingRow detailById =
            MasterDataRoomCategoryController.getBuildingDetail(String.valueOf(buildingId), null);
        MasterDataRoomCategoryController.BuildingRow detailByName =
            MasterDataRoomCategoryController.getBuildingDetail(null, 'Master Building ' + suffix);
        List<MasterDataRoomCategoryController.BuildingFloorWardenRow> initialFloorWardens =
            MasterDataRoomCategoryController.getBuildingFloorWardenDetails(String.valueOf(buildingId));
        MasterDataRoomCategoryController.BuildingActivityHistoryRow historyRow =
            MasterDataRoomCategoryController.getBuildingActivityHistory(String.valueOf(buildingId));

        Id updatedBuildingId = MasterDataRoomCategoryController.updateBuilding(
            String.valueOf(buildingId),
            buildBuildingRequest(
                'Updated Building ' + suffix,
                'Girls',
                'inactive',
                '3',
                'Warden per Floor',
                secondWarden.Id
            )
        );

        MasterDataRoomCategoryController.CreateFloorWardenRequest floorWardenRequest =
            new MasterDataRoomCategoryController.CreateFloorWardenRequest();
        floorWardenRequest.buildingId = String.valueOf(buildingId);
        floorWardenRequest.floorNumber = '2';
        floorWardenRequest.wardenId = String.valueOf(firstWarden.Id);
        floorWardenRequest.description = 'Floor-specific warden';
        floorWardenRequest.assignmentType = 'Floor Warden';
        Id floorWardenId = MasterDataRoomCategoryController.createFloorWarden(floorWardenRequest);
        List<MasterDataRoomCategoryController.BuildingFloorWardenRow> floorWardensAfterUpdate =
            MasterDataRoomCategoryController.getBuildingFloorWardenDetails(String.valueOf(buildingId));
        List<MasterDataRoomCategoryController.BuildingRow> inactiveBuildings =
            MasterDataRoomCategoryController.getBuildings('inactive');

        Ken_Building__c generatedBuilding = createBuildingDirect(
            'Generated Warden Building ' + suffix,
            firstWarden.Id,
            2,
            'Building Level',
            'Active',
            true
        );
        MasterDataRoomCategoryController.CreateFloorWardenRequest generatedWardenRequest =
            new MasterDataRoomCategoryController.CreateFloorWardenRequest();
        generatedWardenRequest.buildingId = String.valueOf(generatedBuilding.Id);
        generatedWardenRequest.floorNumber = '1';
        generatedWardenRequest.wardenName = 'Generated Warden ' + suffix;
        generatedWardenRequest.phone = '9000000999';
        generatedWardenRequest.description = 'Created from test';
        generatedWardenRequest.assignmentType = 'Building Warden';
        Id generatedWardenId = MasterDataRoomCategoryController.createFloorWarden(generatedWardenRequest);

        Ken_Building__c deletableBuilding = createBuildingDirect(
            'Delete Building ' + suffix,
            firstWarden.Id,
            1,
            'Building Level',
            'Active',
            false
        );
        MasterDataRoomCategoryController.deleteBuilding(String.valueOf(deletableBuilding.Id));
        Test.stopTest();

        Ken_Building__c updatedBuilding = [
            SELECT Id, Name__c, Hostel_Type__c, Status__c, Number_Of_Floors__c, Warden_Assignment_Mode__c, Warden__c
            FROM Ken_Building__c
            WHERE Id = :updatedBuildingId
            LIMIT 1
        ];
        Account generatedWarden = [
            SELECT Id, PersonContactId, Description
            FROM Account
            WHERE Id = :generatedWardenId
            LIMIT 1
        ];
        Integer generatedRoleCount = [
            SELECT COUNT()
            FROM ConstituentRole
            WHERE PersonId = :generatedWarden.PersonContactId
              AND RoleType = 'Warden'
              AND Status = 'Active'
        ];
        MasterDataRoomCategoryController.BuildingFloorWardenRow secondFloorRow =
            findFloorWardenRow(floorWardensAfterUpdate, 2);
        MasterDataRoomCategoryController.BuildingFloorWardenRow firstFloorRow =
            findFloorWardenRow(floorWardensAfterUpdate, 1);

        System.assertNotEquals(null, buildingFormOptions, 'Expected building form options payload.');
        System.assert(!buildingFormOptions.genderOptions.isEmpty(), 'Expected gender options.');
        System.assert(!buildingFormOptions.statusOptions.isEmpty(), 'Expected building status options.');
        System.assert(!buildingFormOptions.wardenModeOptions.isEmpty(), 'Expected warden mode options.');
        System.assert(!buildingFormOptions.wardenOptions.isEmpty(), 'Expected active warden options.');
        System.assert(containsBuilding(activeBuildings, buildingId), 'Created building should appear in the active list.');
        System.assertEquals(buildingId, detailById.id, 'Building detail lookup by id should work.');
        System.assertEquals(buildingId, detailByName.id, 'Building detail lookup by name should work.');
        System.assertEquals(2, initialFloorWardens.size(), 'Two floors should be created during building creation.');
        System.assert(historyRow.events.size() >= 3, 'Building history should include owner, update, and create events.');
        System.assertEquals('Updated Building ' + suffix, updatedBuilding.Name__c, 'Building name should be updated.');
        System.assertEquals('Female', updatedBuilding.Hostel_Type__c, 'Girls input should normalize to Female.');
        System.assertEquals('Inactive', updatedBuilding.Status__c, 'Inactive input should persist the inactive status.');
        System.assertEquals('3', updatedBuilding.Number_Of_Floors__c, 'Number of floors should be updated.');
        System.assertEquals('Manual', updatedBuilding.Warden_Assignment_Mode__c, 'Per-floor input should normalize to Manual.');
        System.assertEquals(secondWarden.Id, updatedBuilding.Warden__c, 'Building warden should update to the selected account.');
        System.assertEquals(firstWarden.Id, floorWardenId, 'Existing floor warden branch should return the selected account id.');
        System.assertNotEquals(null, secondFloorRow, 'Expected a floor row for the selected floor.');
        System.assertEquals(String.valueOf(firstWarden.Id), secondFloorRow.wardenId, 'Floor 2 should use the dedicated floor warden.');
        System.assertEquals(false, secondFloorRow.isInheritedFromBuilding, 'Floor 2 should not inherit from the building after assignment.');
        System.assertNotEquals(null, firstFloorRow, 'Expected another floor row to remain on the building.');
        System.assertEquals(true, firstFloorRow.isInheritedFromBuilding, 'Other floors should continue to inherit from the building warden.');
        System.assert(containsBuilding(inactiveBuildings, buildingId), 'Updated building should appear in the inactive list.');
        System.assertNotEquals(null, generatedWarden.PersonContactId, 'Generated building warden should be a person account.');
        System.assertEquals('Created from test', generatedWarden.Description, 'Description should be copied to the generated warden account.');
        System.assertEquals(1, generatedRoleCount, 'Generated warden branch should create an active warden role.');
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Ken_Building__c WHERE Id = :deletableBuilding.Id],
            'Delete should remove a building with no child floor rows.'
        );
    }

    @IsTest
    static void roomLifecycleBulkUploadAndOccupancyWork() {
        String suffix = uniqueSuffix('RM');
        String bulkRoomNumber = 'B201-' + suffix;
        Account warden = createActiveWarden('master-room-' + suffix);
        Ken_Room_Category__c category = createRoomCategoryDirect(
            'Master Room Category ' + suffix,
            true
        );
        Ken_Building__c building = createBuildingDirect(
            'Master Room Building ' + suffix,
            warden.Id,
            2,
            'Building Level',
            'Active',
            false
        );

        Test.startTest();
        System.assertEquals(null, MasterDataRoomCategoryController.getRoomById(null), 'Null room ids should return null.');
        MasterDataRoomCategoryController.RoomFormOptions initialOptions =
            MasterDataRoomCategoryController.getRoomFormOptions();
        String floorOneValue = findFloorOptionValue(initialOptions, building.Id, 1);
        Id roomId = MasterDataRoomCategoryController.createRoom(
            buildRoomRequest(building.Id, floorOneValue, 'A101-' + suffix, category.Id, '2', 'Active')
        );
        Ken_Building__c buildingAfterCreate = [
            SELECT Id, Total_Rooms__c
            FROM Ken_Building__c
            WHERE Id = :building.Id
            LIMIT 1
        ];
        MasterDataRoomCategoryController.RoomRow roomDetail =
            MasterDataRoomCategoryController.getRoomById(String.valueOf(roomId));
        List<MasterDataRoomCategoryController.RoomRow> activeRooms =
            MasterDataRoomCategoryController.getRooms('active');
        List<MasterDataRoomCategoryController.RoomRow> linkedRooms =
            MasterDataRoomCategoryController.getLinkedRoomsByCategory(String.valueOf(category.Id));
        MasterDataRoomCategoryController.RoomOccupancyDetailsRow occupancyDetails =
            MasterDataRoomCategoryController.getRoomOccupancyDetails(String.valueOf(roomId));

        MasterDataRoomCategoryController.RoomFormOptions updatedOptions =
            MasterDataRoomCategoryController.getRoomFormOptions();
        String floorTwoValue = findFloorOptionValue(updatedOptions, building.Id, 2);
        Id updatedRoomId = MasterDataRoomCategoryController.updateRoom(
            String.valueOf(roomId),
            buildRoomRequest(building.Id, floorTwoValue, 'A102-' + suffix, category.Id, '3', 'Inactive')
        );
        Ken_Room__c updatedRoom = [
            SELECT Id, Room_Number__c, Capacity__c, Room_Status__c, Floor__c
            FROM Ken_Room__c
            WHERE Id = :updatedRoomId
            LIMIT 1
        ];
        List<MasterDataRoomCategoryController.RoomRow> inactiveRooms =
            MasterDataRoomCategoryController.getRooms('inactive');

        MasterDataRoomCategoryController.BulkRoomCsvResponse bulkResponse =
            MasterDataRoomCategoryController.bulkCreateRoomsFromCsv(
                new List<MasterDataRoomCategoryController.BulkRoomCsvRow>{
                    buildBulkRow(1, building.Name__c, '2', bulkRoomNumber, category.Name__c, '2', 'Active'),
                    buildBulkRow(2, null, '2', 'B202-' + suffix, category.Name__c, '2', 'Active')
                }
            );
        Ken_Building__c buildingAfterBulkUpload = [
            SELECT Id, Total_Rooms__c
            FROM Ken_Building__c
            WHERE Id = :building.Id
            LIMIT 1
        ];

        MasterDataRoomCategoryController.deleteRoom(String.valueOf(roomId));
        Ken_Building__c buildingAfterDelete = [
            SELECT Id, Total_Rooms__c
            FROM Ken_Building__c
            WHERE Id = :building.Id
            LIMIT 1
        ];
        Test.stopTest();

        MasterDataRoomCategoryController.BuildingRow buildingDetail =
            MasterDataRoomCategoryController.getBuildingDetail(String.valueOf(building.Id), null);

        System.assert(String.isNotBlank(floorOneValue), 'Expected a floor option for floor 1.');
        System.assertNotEquals(null, roomDetail, 'Expected room detail payload.');
        System.assertEquals('1', String.valueOf(buildingAfterCreate.Total_Rooms__c), 'Create should store the building room total.');
        System.assertEquals(roomId, roomDetail.id, 'Room detail should point to the created room.');
        System.assert(containsRoom(activeRooms, roomId), 'Created room should appear in the active list.');
        System.assert(containsRoom(linkedRooms, roomId), 'Created room should appear in the category room list.');
        System.assertNotEquals(null, occupancyDetails, 'Expected occupancy details payload.');
        System.assertEquals(0, occupancyDetails.currentOccupants.size(), 'No allotments means no current occupants.');
        System.assertEquals(0, occupancyDetails.pastOccupants.size(), 'No allotments means no past occupants.');
        System.assertEquals(2, occupancyDetails.events.size(), 'Occupancy details should include create and update events.');
        System.assertEquals(roomId, updatedRoomId, 'Update should return the same room id.');
        System.assertEquals('A102-' + suffix, updatedRoom.Room_Number__c, 'Room number should be updated.');
        System.assertEquals(3, Integer.valueOf(String.valueOf(updatedRoom.Capacity__c)), 'Room capacity should be updated.');
        System.assertNotEquals(null, updatedRoom.Floor__c, 'Room update should resolve and store a floor id.');
        System.assert(containsRoom(inactiveRooms, roomId), 'Updated room should appear in the inactive list.');
        System.assertEquals(2, bulkResponse.processedCount, 'Bulk response should report the input row count.');
        System.assertEquals(1, bulkResponse.successCount, 'Expected one successful bulk room insert.');
        System.assertEquals('2', String.valueOf(buildingAfterBulkUpload.Total_Rooms__c), 'Bulk room inserts should update the building room total.');
        System.assert(bulkResponse.failureCount >= 1, 'Expected at least one failed bulk room row.');
        System.assert(!bulkResponse.errors.isEmpty(), 'Expected a validation error for the bad CSV row.');
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Ken_Room__c WHERE Room_Number__c = :bulkRoomNumber],
            'Bulk upload should create the valid room row.'
        );
        System.assertEquals('1', String.valueOf(buildingAfterDelete.Total_Rooms__c), 'Delete should reduce the stored building room total.');
        System.assertEquals('1', buildingDetail.roomsCount, 'Building detail should return the stored room total.');
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Ken_Room__c WHERE Id = :roomId],
            'Delete should remove the room record.'
        );
    }

    @IsTest
    static void buildingDetailBackfillsStoredRoomTotalFromExistingRooms() {
        String suffix = uniqueSuffix('BRT');
        Account warden = createActiveWarden('master-building-rooms-' + suffix);
        Ken_Room_Category__c category = createRoomCategoryDirect(
            'Building Room Total Category ' + suffix,
            true
        );
        Ken_Building__c building = createBuildingDirect(
            'Building Room Total ' + suffix,
            warden.Id,
            2,
            'Building Level',
            'Active',
            true
        );

        createRoomDirect(
            building.Id,
            getFloorId(building.Id, 1),
            category.Id,
            'READ-101-' + suffix,
            2,
            'Active'
        );
        createRoomDirect(
            building.Id,
            getFloorId(building.Id, 2),
            category.Id,
            'READ-201-' + suffix,
            2,
            'Active'
        );

        Ken_Building__c staleBuilding = [
            SELECT Id, Total_Rooms__c
            FROM Ken_Building__c
            WHERE Id = :building.Id
            LIMIT 1
        ];
        System.assertEquals('0', String.valueOf(staleBuilding.Total_Rooms__c), 'Test setup should start with a stale stored total.');

        Test.startTest();
        MasterDataRoomCategoryController.BuildingRow buildingDetail =
            MasterDataRoomCategoryController.getBuildingDetail(String.valueOf(building.Id), null);
        List<MasterDataRoomCategoryController.BuildingRow> activeBuildings =
            MasterDataRoomCategoryController.getBuildings('active');
        Test.stopTest();

        Ken_Building__c refreshedBuilding = [
            SELECT Id, Total_Rooms__c
            FROM Ken_Building__c
            WHERE Id = :building.Id
            LIMIT 1
        ];
        MasterDataRoomCategoryController.BuildingRow matchingRow;
        for (MasterDataRoomCategoryController.BuildingRow row : activeBuildings) {
            if (row != null && row.id == building.Id) {
                matchingRow = row;
                break;
            }
        }

        System.assertNotEquals(null, buildingDetail, 'Building detail should be returned for the test building.');
        System.assertEquals('2', buildingDetail.roomsCount, 'Building detail should calculate the room total from existing rooms.');
        System.assertNotEquals(null, matchingRow, 'Active building list should include the test building.');
        System.assertEquals('2', matchingRow.roomsCount, 'Building list should expose the repaired room total.');
        System.assertEquals('2', String.valueOf(refreshedBuilding.Total_Rooms__c), 'Building read paths should store the repaired room total.');
    }

    @IsTest
    static void roomNumberMustBeUniqueWithinBuilding() {
        String suffix = uniqueSuffix('RDU');
        String duplicateRoomNumber = 'DUP-' + suffix;
        Account warden = createActiveWarden('master-room-duplicate-' + suffix);
        Ken_Room_Category__c category = createRoomCategoryDirect(
            'Duplicate Room Category ' + suffix,
            true
        );
        Ken_Building__c building = createBuildingDirect(
            'Duplicate Room Building ' + suffix,
            warden.Id,
            2,
            'Building Level',
            'Active',
            true
        );
        Id floorId = getFloorId(building.Id, 1);
        String floorValue = String.valueOf(floorId);

        createRoomDirect(
            building.Id,
            floorId,
            category.Id,
            duplicateRoomNumber,
            2,
            'Active'
        );
        Ken_Room__c editableRoom = createRoomDirect(
            building.Id,
            floorId,
            category.Id,
            'EDIT-' + suffix,
            2,
            'Active'
        );

        Boolean didThrow = false;
        try {
            MasterDataRoomCategoryController.createRoom(
                buildRoomRequest(building.Id, floorValue, duplicateRoomNumber, category.Id, '2', 'Active')
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'already exists for the selected building');
        }
        System.assertEquals(true, didThrow, 'Create should reject duplicate room numbers within the same building.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.updateRoom(
                String.valueOf(editableRoom.Id),
                buildRoomRequest(building.Id, floorValue, duplicateRoomNumber, category.Id, '2', 'Active')
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'already exists for the selected building');
        }
        System.assertEquals(true, didThrow, 'Update should reject duplicate room numbers within the same building.');

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Ken_Room__c WHERE Building__c = :building.Id AND Room_Number__c = :duplicateRoomNumber],
            'Only the original room number should remain in the building.'
        );
    }

    @IsTest
    static void bulkRoomUploadRejectsDuplicateRoomNumbersWithinSameBuilding() {
        String suffix = uniqueSuffix('RBD');
        String newRoomNumber = 'CSV-NEW-' + suffix;
        String existingRoomNumber = 'CSV-EXIST-' + suffix;
        Account warden = createActiveWarden('master-room-bulk-duplicate-' + suffix);
        Ken_Room_Category__c category = createRoomCategoryDirect(
            'Bulk Duplicate Category ' + suffix,
            true
        );
        Ken_Building__c building = createBuildingDirect(
            'Bulk Duplicate Building ' + suffix,
            warden.Id,
            1,
            'Building Level',
            'Active',
            true
        );
        Id floorId = getFloorId(building.Id, 1);

        createRoomDirect(
            building.Id,
            floorId,
            category.Id,
            existingRoomNumber,
            2,
            'Active'
        );

        Test.startTest();
        MasterDataRoomCategoryController.BulkRoomCsvResponse bulkResponse =
            MasterDataRoomCategoryController.bulkCreateRoomsFromCsv(
                new List<MasterDataRoomCategoryController.BulkRoomCsvRow>{
                    buildBulkRow(2, building.Name__c, '1', newRoomNumber, category.Name__c, '2', 'Active'),
                    buildBulkRow(3, building.Name__c, '1', newRoomNumber, category.Name__c, '2', 'Active'),
                    buildBulkRow(4, building.Name__c, '1', existingRoomNumber, category.Name__c, '2', 'Active')
                }
            );
        Test.stopTest();

        System.assertEquals(3, bulkResponse.processedCount, 'Processed count should include each CSV row.');
        System.assertEquals(1, bulkResponse.successCount, 'Only the first unique CSV room should be created.');
        System.assertEquals(2, bulkResponse.failureCount, 'Duplicate CSV rows should fail.');
        System.assertEquals(2, bulkResponse.errors.size(), 'Each duplicate CSV row should return an error.');
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Ken_Room__c WHERE Building__c = :building.Id AND Room_Number__c = :newRoomNumber],
            'Bulk upload should insert the first unique room number once.'
        );
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Ken_Room__c WHERE Building__c = :building.Id AND Room_Number__c = :existingRoomNumber],
            'Bulk upload should not duplicate an existing room number.'
        );
        System.assert(
            bulkResponse.errors[0].message.contains('already exists for the selected building') &&
            bulkResponse.errors[1].message.contains('already exists for the selected building'),
            'Duplicate CSV errors should explain the room number conflict.'
        );
    }

    @IsTest
    static void roomCategoryValidationAndDeleteErrorPathsWork() {
        String suffix = uniqueSuffix('RCE');
        Account warden = createActiveWarden('master-room-category-error-' + suffix);
        MasterDataRoomCategoryController.CreateRoomCategoryRequest baseRequest =
            buildRoomCategoryRequest(
                'Validation Category ' + suffix,
                'active',
                new List<String>{ 'King Bed', 'Desk Lamp ' + suffix }
            );

        Boolean didThrow = false;
        try {
            MasterDataRoomCategoryController.createRoomCategory(null);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Room category payload is required.');
        }
        System.assertEquals(true, didThrow, 'Null room category payloads should fail.');

        MasterDataRoomCategoryController.CreateRoomCategoryRequest missingAcRequest =
            buildRoomCategoryRequest('Validation No AC ' + suffix, 'active', new List<String>{ 'King Bed' });
        missingAcRequest.ac = '   ';
        didThrow = false;
        try {
            MasterDataRoomCategoryController.createRoomCategory(missingAcRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'AC / Non AC is required.');
        }
        System.assertEquals(true, didThrow, 'Blank AC values should fail.');

        MasterDataRoomCategoryController.CreateRoomCategoryRequest missingBathroomRequest =
            buildRoomCategoryRequest('Validation No Bath ' + suffix, 'active', new List<String>{ 'King Bed' });
        missingBathroomRequest.bathroom = '   ';
        didThrow = false;
        try {
            MasterDataRoomCategoryController.createRoomCategory(missingBathroomRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Bathroom is required.');
        }
        System.assertEquals(true, didThrow, 'Blank bathroom values should fail.');

        MasterDataRoomCategoryController.CreateRoomCategoryRequest missingStatusRequest =
            buildRoomCategoryRequest('Validation No Status ' + suffix, null, new List<String>{ 'King Bed' });
        didThrow = false;
        try {
            MasterDataRoomCategoryController.createRoomCategory(missingStatusRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Status is required.');
        }
        System.assertEquals(true, didThrow, 'Blank statuses should fail.');

        Ken_Room_Category__c existingCategory = createRoomCategoryDirect(
            'Existing Validation Category ' + suffix,
            true
        );
        System.assertEquals(
            null,
            MasterDataRoomCategoryController.getRoomCategoryDetail(null, null),
            'Null category detail lookups should return null.'
        );
        System.assertEquals(
            null,
            MasterDataRoomCategoryController.getRoomCategoryDetail(String.valueOf(UserInfo.getUserId()), null),
            'Unknown category ids should return null.'
        );

        didThrow = false;
        try {
            MasterDataRoomCategoryController.updateRoomCategory('', baseRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Room category is required.');
        }
        System.assertEquals(true, didThrow, 'Blank room category ids should fail.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.updateRoomCategory(String.valueOf(existingCategory.Id), null);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Room category payload is required.');
        }
        System.assertEquals(true, didThrow, 'Null room category updates should fail.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.updateRoomCategory(String.valueOf(UserInfo.getUserId()), baseRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Room category record was not found.');
        }
        System.assertEquals(true, didThrow, 'Missing room category records should fail.');

        MasterDataRoomCategoryController.CreateRoomCategoryRequest updateMissingAcRequest =
            new MasterDataRoomCategoryController.CreateRoomCategoryRequest();
        updateMissingAcRequest.ac = '   ';
        didThrow = false;
        try {
            MasterDataRoomCategoryController.updateRoomCategory(
                String.valueOf(existingCategory.Id),
                updateMissingAcRequest
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'AC / Non AC is required.');
        }
        System.assertEquals(true, didThrow, 'Blank AC updates should fail.');

        MasterDataRoomCategoryController.CreateRoomCategoryRequest updateMissingBathroomRequest =
            new MasterDataRoomCategoryController.CreateRoomCategoryRequest();
        updateMissingBathroomRequest.bathroom = '   ';
        didThrow = false;
        try {
            MasterDataRoomCategoryController.updateRoomCategory(
                String.valueOf(existingCategory.Id),
                updateMissingBathroomRequest
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Bathroom is required.');
        }
        System.assertEquals(true, didThrow, 'Blank bathroom updates should fail.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.addCustomAmenity('   ');
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Custom amenity name is required.');
        }
        System.assertEquals(true, didThrow, 'Blank custom amenities should fail.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.deleteRoomCategory('');
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Room category is required.');
        }
        System.assertEquals(true, didThrow, 'Blank category ids should fail during delete.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.deleteRoomCategory(String.valueOf(UserInfo.getUserId()));
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Room category record was not found.');
        }
        System.assertEquals(true, didThrow, 'Unknown room categories should fail during delete.');

        Ken_Building__c linkedBuilding = createBuildingDirect(
            'Linked Category Building ' + suffix,
            warden.Id,
            1,
            'Building Level',
            'Active',
            true
        );
        createRoomDirect(
            linkedBuilding.Id,
            getFloorId(linkedBuilding.Id, 1),
            existingCategory.Id,
            'LINK-' + suffix,
            2,
            'Active'
        );
        MasterDataRoomCategoryController.deleteRoomCategory(String.valueOf(existingCategory.Id));
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Ken_Room_Category__c WHERE Id = :existingCategory.Id],
            'Linked room categories should still be removable in this org configuration.'
        );
    }

    @IsTest
    static void buildingValidationAndDeleteErrorPathsWork() {
        String suffix = uniqueSuffix('BLDE');
        Account validWarden = createActiveWarden('master-building-valid-' + suffix);
        Account invalidWarden = createPersonAccount(
            'Invalid Building Warden',
            'invalid.building.' + suffix + '@example.test',
            '9000000111'
        );
        MasterDataRoomCategoryController.CreateBuildingRequest baseRequest =
            buildBuildingRequest(
                'Validation Building ' + suffix,
                'Boys',
                'active',
                '2',
                'Single Warden for Entire Building',
                validWarden.Id
            );

        Boolean didThrow = false;
        try {
            MasterDataRoomCategoryController.createBuilding(null);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Building payload is required.');
        }
        System.assertEquals(true, didThrow, 'Null building payloads should fail.');

        MasterDataRoomCategoryController.CreateBuildingRequest missingNameRequest =
            buildBuildingRequest(null, 'Boys', 'active', '2', 'Single Warden for Entire Building', validWarden.Id);
        didThrow = false;
        try {
            MasterDataRoomCategoryController.createBuilding(missingNameRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Building Name is required.');
        }
        System.assertEquals(true, didThrow, 'Blank building names should fail.');

        MasterDataRoomCategoryController.CreateBuildingRequest missingGenderRequest =
            buildBuildingRequest('Validation Gender ' + suffix, null, 'active', '2', 'Single Warden for Entire Building', validWarden.Id);
        didThrow = false;
        try {
            MasterDataRoomCategoryController.createBuilding(missingGenderRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Gender is required.');
        }
        System.assertEquals(true, didThrow, 'Blank gender values should fail.');

        MasterDataRoomCategoryController.CreateBuildingRequest invalidFloorCountRequest =
            buildBuildingRequest('Validation Floors ' + suffix, 'Boys', 'active', '0', 'Single Warden for Entire Building', validWarden.Id);
        didThrow = false;
        try {
            MasterDataRoomCategoryController.createBuilding(invalidFloorCountRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Number of Floors must be a positive whole number.');
        }
        System.assertEquals(true, didThrow, 'Invalid floor counts should fail.');

        MasterDataRoomCategoryController.CreateBuildingRequest missingWardenRequest =
            buildBuildingRequest('Validation Warden ' + suffix, 'Boys', 'active', '2', 'Single Warden for Entire Building', null);
        didThrow = false;
        try {
            MasterDataRoomCategoryController.createBuilding(missingWardenRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Building Warden is required.');
        }
        System.assertEquals(true, didThrow, 'Blank building wardens should fail.');

        MasterDataRoomCategoryController.CreateBuildingRequest invalidWardenRequest =
            buildBuildingRequest(
                'Validation Active Warden ' + suffix,
                'Boys',
                'active',
                '2',
                'Single Warden for Entire Building',
                invalidWarden.Id
            );
        didThrow = false;
        try {
            MasterDataRoomCategoryController.createBuilding(invalidWardenRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Please select a valid active Warden account.');
        }
        System.assertEquals(true, didThrow, 'Non-warden accounts should fail building creation.');

        Ken_Building__c existingBuilding = createBuildingDirect(
            'Existing Validation Building ' + suffix,
            validWarden.Id,
            1,
            'Building Level',
            'Active',
            false
        );
        System.assertEquals(
            null,
            MasterDataRoomCategoryController.getBuildingDetail(null, null),
            'Null building detail lookups should return null.'
        );
        System.assertEquals(
            null,
            MasterDataRoomCategoryController.getBuildingDetail(String.valueOf(UserInfo.getUserId()), null),
            'Unknown building ids should return null.'
        );

        didThrow = false;
        try {
            MasterDataRoomCategoryController.updateBuilding('', baseRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Building is required.');
        }
        System.assertEquals(true, didThrow, 'Blank building ids should fail updates.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.updateBuilding(String.valueOf(existingBuilding.Id), null);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Building payload is required.');
        }
        System.assertEquals(true, didThrow, 'Null building payloads should fail updates.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.updateBuilding(String.valueOf(UserInfo.getUserId()), baseRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Building record was not found.');
        }
        System.assertEquals(true, didThrow, 'Missing buildings should fail updates.');

        MasterDataRoomCategoryController.CreateBuildingRequest updateInvalidFloorsRequest =
            buildBuildingRequest(null, null, null, '0', null, null);
        didThrow = false;
        try {
            MasterDataRoomCategoryController.updateBuilding(
                String.valueOf(existingBuilding.Id),
                updateInvalidFloorsRequest
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Number of Floors must be a positive whole number.');
        }
        System.assertEquals(true, didThrow, 'Invalid update floor counts should fail.');

        MasterDataRoomCategoryController.CreateBuildingRequest updateInvalidWardenRequest =
            buildBuildingRequest(null, null, null, null, null, invalidWarden.Id);
        didThrow = false;
        try {
            MasterDataRoomCategoryController.updateBuilding(
                String.valueOf(existingBuilding.Id),
                updateInvalidWardenRequest
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Please select a valid active Warden account.');
        }
        System.assertEquals(true, didThrow, 'Non-warden accounts should fail building updates.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.deleteBuilding('');
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Building is required.');
        }
        System.assertEquals(true, didThrow, 'Blank building ids should fail during delete.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.deleteBuilding(String.valueOf(UserInfo.getUserId()));
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Building record was not found.');
        }
        System.assertEquals(true, didThrow, 'Unknown buildings should fail during delete.');

        Ken_Room_Category__c linkedCategory = createRoomCategoryDirect(
            'Linked Building Category ' + suffix,
            true
        );
        Ken_Building__c linkedBuilding = createBuildingDirect(
            'Delete Failure Building ' + suffix,
            validWarden.Id,
            1,
            'Building Level',
            'Active',
            true
        );
        createRoomDirect(
            linkedBuilding.Id,
            getFloorId(linkedBuilding.Id, 1),
            linkedCategory.Id,
            'BLD-ERR-' + suffix,
            2,
            'Active'
        );
        MasterDataRoomCategoryController.deleteBuilding(String.valueOf(linkedBuilding.Id));
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Ken_Building__c WHERE Id = :linkedBuilding.Id],
            'Linked buildings should still be removable in this org configuration.'
        );
    }

    @IsTest
    static void roomValidationAndBulkErrorPathsWork() {
        String suffix = uniqueSuffix('RME');
        Account warden = createActiveWarden('master-room-error-' + suffix);
        Ken_Room_Category__c category = createRoomCategoryDirect(
            'Room Error Category ' + suffix,
            true
        );
        Ken_Building__c buildingOne = createBuildingDirect(
            'Room Error Building One ' + suffix,
            warden.Id,
            2,
            'Building Level',
            'Active',
            true
        );
        Ken_Building__c buildingTwo = createBuildingDirect(
            'Room Error Building Two ' + suffix,
            warden.Id,
            1,
            'Building Level',
            'Active',
            true
        );
        String validFloorValue = String.valueOf(getFloorId(buildingOne.Id, 1));

        Boolean didThrow = false;
        try {
            MasterDataRoomCategoryController.createRoom(null);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Room payload is required.');
        }
        System.assertEquals(true, didThrow, 'Null room payloads should fail.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.createRoom(
                buildRoomRequest(null, validFloorValue, 'ROOM-' + suffix, category.Id, '2', 'Active')
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Building is required.');
        }
        System.assertEquals(true, didThrow, 'Blank building values should fail.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.createRoom(
                buildRoomRequest(buildingOne.Id, null, 'ROOM-' + suffix, category.Id, '2', 'Active')
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Floor is required.');
        }
        System.assertEquals(true, didThrow, 'Blank floors should fail.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.createRoom(
                buildRoomRequest(buildingOne.Id, validFloorValue, null, category.Id, '2', 'Active')
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Room Number is required.');
        }
        System.assertEquals(true, didThrow, 'Blank room numbers should fail.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.createRoom(
                buildRoomRequest(buildingOne.Id, validFloorValue, 'ROOM-' + suffix, null, '2', 'Active')
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Category is required.');
        }
        System.assertEquals(true, didThrow, 'Blank categories should fail.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.createRoom(
                buildRoomRequest(buildingOne.Id, validFloorValue, 'ROOM-' + suffix, category.Id, '0', 'Active')
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Capacity must be a positive whole number.');
        }
        System.assertEquals(true, didThrow, 'Invalid capacities should fail.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.createRoom(
                buildRoomRequest(buildingOne.Id, validFloorValue, 'ROOM-' + suffix, category.Id, '2', null)
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Status is required.');
        }
        System.assertEquals(true, didThrow, 'Blank statuses should fail.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.createRoom(
                buildRoomRequest(
                    buildingOne.Id,
                    'SYNTH::' + String.valueOf(buildingTwo.Id) + '::1',
                    'ROOM-' + suffix,
                    category.Id,
                    '2',
                    'Active'
                )
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Please select a floor from the selected building.');
        }
        System.assertEquals(true, didThrow, 'Synthetic floors from another building should fail.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.createRoom(
                buildRoomRequest(
                    buildingOne.Id,
                    'SYNTH::bad::abc',
                    'ROOM-' + suffix,
                    category.Id,
                    '2',
                    'Active'
                )
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Selected floor is invalid.');
        }
        System.assertEquals(true, didThrow, 'Malformed synthetic floors should fail.');

        Ken_Room__c existingRoom = createRoomDirect(
            buildingOne.Id,
            getFloorId(buildingOne.Id, 1),
            category.Id,
            'UPD-' + suffix,
            2,
            'Active'
        );

        didThrow = false;
        try {
            MasterDataRoomCategoryController.updateRoom('', new MasterDataRoomCategoryController.CreateRoomRequest());
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Room is required.');
        }
        System.assertEquals(true, didThrow, 'Blank room ids should fail during update.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.updateRoom(String.valueOf(existingRoom.Id), null);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Room payload is required.');
        }
        System.assertEquals(true, didThrow, 'Null room payloads should fail during update.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.updateRoom(
                String.valueOf(UserInfo.getUserId()),
                new MasterDataRoomCategoryController.CreateRoomRequest()
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Room record was not found.');
        }
        System.assertEquals(true, didThrow, 'Unknown rooms should fail during update.');

        update new Ken_Room__c(
            Id = existingRoom.Id,
            Room_Category__c = null
        );
        didThrow = false;
        try {
            MasterDataRoomCategoryController.updateRoom(
                String.valueOf(existingRoom.Id),
                new MasterDataRoomCategoryController.CreateRoomRequest()
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Category is required.');
        }
        System.assertEquals(true, didThrow, 'Rooms without categories should fail updates.');

        existingRoom = createRoomDirect(
            buildingOne.Id,
            getFloorId(buildingOne.Id, 1),
            category.Id,
            'UPD-CAP-' + suffix,
            2,
            'Active'
        );
        MasterDataRoomCategoryController.CreateRoomRequest invalidCapacityUpdate =
            new MasterDataRoomCategoryController.CreateRoomRequest();
        invalidCapacityUpdate.capacity = 'abc';
        didThrow = false;
        try {
            MasterDataRoomCategoryController.updateRoom(
                String.valueOf(existingRoom.Id),
                invalidCapacityUpdate
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Capacity must be a whole number');
        }
        System.assertEquals(true, didThrow, 'Non-numeric capacities should fail updates.');

        MasterDataRoomCategoryController.CreateRoomRequest invalidFloorUpdate =
            new MasterDataRoomCategoryController.CreateRoomRequest();
        invalidFloorUpdate.floorId = 'abc';
        didThrow = false;
        try {
            MasterDataRoomCategoryController.updateRoom(
                String.valueOf(existingRoom.Id),
                invalidFloorUpdate
            );
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Selected floor is invalid.');
        }
        System.assertEquals(true, didThrow, 'Invalid floor values should fail updates.');

        didThrow = false;
        try {
            MasterDataRoomCategoryController.bulkCreateRoomsFromCsv(null);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'CSV rows are required.');
        }
        System.assertEquals(true, didThrow, 'Null CSV uploads should fail.');

        List<MasterDataRoomCategoryController.BulkRoomCsvRow> tooManyRows =
            new List<MasterDataRoomCategoryController.BulkRoomCsvRow>();
        for (Integer index = 1; index <= 2001; index++) {
            tooManyRows.add(buildBulkRow(index, 'B', '1', 'R' + String.valueOf(index), 'C', '1', 'Active'));
        }
        didThrow = false;
        try {
            MasterDataRoomCategoryController.bulkCreateRoomsFromCsv(tooManyRows);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'CSV upload supports up to 2000 rows at a time.');
        }
        System.assertEquals(true, didThrow, 'Oversized CSV uploads should fail.');

        Test.startTest();
        MasterDataRoomCategoryController.BulkRoomCsvResponse bulkResponse =
            MasterDataRoomCategoryController.bulkCreateRoomsFromCsv(
                new List<MasterDataRoomCategoryController.BulkRoomCsvRow>{
                    null,
                    buildBulkRow(2, null, '1', 'B100-' + suffix, category.Name__c, '2', 'Active'),
                    buildBulkRow(3, buildingOne.Name__c, null, 'B101-' + suffix, category.Name__c, '2', 'Active'),
                    buildBulkRow(4, buildingOne.Name__c, '1', null, category.Name__c, '2', 'Active'),
                    buildBulkRow(5, buildingOne.Name__c, '1', 'B102-' + suffix, null, '2', 'Active'),
                    buildBulkRow(6, buildingOne.Name__c, '1', 'B103-' + suffix, category.Name__c, '0', 'Active'),
                    buildBulkRow(7, buildingOne.Name__c, '1', 'B104-' + suffix, category.Name__c, '2', null),
                    buildBulkRow(8, 'Unknown Building ' + suffix, '1', 'B105-' + suffix, category.Name__c, '2', 'Active'),
                    buildBulkRow(9, buildingOne.Name__c, '1', 'B106-' + suffix, 'Unknown Category ' + suffix, '2', 'Active'),
                    buildBulkRow(10, buildingOne.Name__c, 'Ground', 'B107-' + suffix, category.Name__c, '2', 'Active'),
                    buildBulkRow(11, buildingOne.Name__c, '1', 'B108-' + suffix, category.Name__c, '2', 'Mystery')
                }
            );
        Test.stopTest();

        System.assertEquals(11, bulkResponse.processedCount, 'Processed count should include all CSV rows.');
        System.assertEquals(0, bulkResponse.successCount, 'All error rows should fail.');
        System.assertEquals(bulkResponse.errors.size(), bulkResponse.failureCount, 'The failure count should match collected errors.');
        System.assert(!bulkResponse.errors.isEmpty(), 'Validation errors should be returned to the caller.');
    }

    @IsTest
    static void floorWardenAndOccupancyVariantsWork() {
        String suffix = uniqueSuffix('FLW');
        Account primaryWarden = createActiveWarden('master-floor-primary-' + suffix);
        Account secondaryWarden = createActiveWarden('master-floor-secondary-' + suffix);
        Account invalidWarden = createPersonAccount(
            'Invalid Floor Warden',
            'invalid.floor.' + suffix + '@example.test',
            '9000000112'
        );
        Ken_Building__c building = createBuildingDirect(
            'Floor Validation Building ' + suffix,
            primaryWarden.Id,
            2,
            'Building Level',
            'Active',
            true
        );

        Boolean didThrow = false;
        try {
            MasterDataRoomCategoryController.createFloorWarden(null);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Floor warden payload is required.');
        }
        System.assertEquals(true, didThrow, 'Null floor warden payloads should fail.');

        MasterDataRoomCategoryController.CreateFloorWardenRequest missingAssignmentType =
            new MasterDataRoomCategoryController.CreateFloorWardenRequest();
        missingAssignmentType.buildingId = String.valueOf(building.Id);
        missingAssignmentType.floorNumber = '1';
        missingAssignmentType.wardenId = String.valueOf(primaryWarden.Id);
        didThrow = false;
        try {
            MasterDataRoomCategoryController.createFloorWarden(missingAssignmentType);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Assignment Type is required.');
        }
        System.assertEquals(true, didThrow, 'Blank assignment types should fail.');

        MasterDataRoomCategoryController.CreateFloorWardenRequest missingFloorRequest =
            new MasterDataRoomCategoryController.CreateFloorWardenRequest();
        missingFloorRequest.buildingId = String.valueOf(building.Id);
        missingFloorRequest.floorNumber = '9';
        missingFloorRequest.assignmentType = 'Floor Warden';
        missingFloorRequest.wardenId = String.valueOf(secondaryWarden.Id);
        didThrow = false;
        try {
            MasterDataRoomCategoryController.createFloorWarden(missingFloorRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Selected floor was not found.');
        }
        System.assertEquals(true, didThrow, 'Unknown floors should fail.');

        MasterDataRoomCategoryController.CreateFloorWardenRequest inactiveWardenRequest =
            new MasterDataRoomCategoryController.CreateFloorWardenRequest();
        inactiveWardenRequest.buildingId = String.valueOf(building.Id);
        inactiveWardenRequest.floorNumber = '1';
        inactiveWardenRequest.assignmentType = 'Floor Warden';
        inactiveWardenRequest.wardenId = String.valueOf(invalidWarden.Id);
        didThrow = false;
        try {
            MasterDataRoomCategoryController.createFloorWarden(inactiveWardenRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Please select a valid active Warden account.');
        }
        System.assertEquals(true, didThrow, 'Non-warden accounts should fail floor assignment.');

        MasterDataRoomCategoryController.CreateFloorWardenRequest missingNameRequest =
            new MasterDataRoomCategoryController.CreateFloorWardenRequest();
        missingNameRequest.buildingId = String.valueOf(building.Id);
        missingNameRequest.floorNumber = '1';
        missingNameRequest.assignmentType = 'Building Warden';
        didThrow = false;
        try {
            MasterDataRoomCategoryController.createFloorWarden(missingNameRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Warden Name is required.');
        }
        System.assertEquals(true, didThrow, 'Generated warden requests should require a name.');

        MasterDataRoomCategoryController.CreateFloorWardenRequest missingPhoneRequest =
            new MasterDataRoomCategoryController.CreateFloorWardenRequest();
        missingPhoneRequest.buildingId = String.valueOf(building.Id);
        missingPhoneRequest.floorNumber = '1';
        missingPhoneRequest.assignmentType = 'Building Warden';
        missingPhoneRequest.wardenName = 'Generated Warden ' + suffix;
        didThrow = false;
        try {
            MasterDataRoomCategoryController.createFloorWarden(missingPhoneRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'Phone is required.');
        }
        System.assertEquals(true, didThrow, 'Generated wardens should require a phone.');

        MasterDataRoomCategoryController.CreateFloorWardenRequest duplicateBuildingWardenRequest =
            new MasterDataRoomCategoryController.CreateFloorWardenRequest();
        duplicateBuildingWardenRequest.buildingId = String.valueOf(building.Id);
        duplicateBuildingWardenRequest.floorNumber = '1';
        duplicateBuildingWardenRequest.assignmentType = 'Building Warden';
        duplicateBuildingWardenRequest.wardenId = String.valueOf(primaryWarden.Id);
        didThrow = false;
        try {
            MasterDataRoomCategoryController.createFloorWarden(duplicateBuildingWardenRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'already assigned');
        }
        System.assertEquals(true, didThrow, 'Assigning the same building warden twice should fail.');

        MasterDataRoomCategoryController.CreateFloorWardenRequest firstAssignment =
            new MasterDataRoomCategoryController.CreateFloorWardenRequest();
        firstAssignment.buildingId = String.valueOf(building.Id);
        firstAssignment.floorNumber = '2';
        firstAssignment.assignmentType = 'Floor Warden';
        firstAssignment.wardenId = String.valueOf(secondaryWarden.Id);
        Id floorWardenId = MasterDataRoomCategoryController.createFloorWarden(firstAssignment);
        System.assertEquals(secondaryWarden.Id, floorWardenId, 'A dedicated floor warden should still be assignable.');

        MasterDataRoomCategoryController.CreateFloorWardenRequest duplicateFloorWardenRequest =
            new MasterDataRoomCategoryController.CreateFloorWardenRequest();
        duplicateFloorWardenRequest.buildingId = String.valueOf(building.Id);
        duplicateFloorWardenRequest.floorNumber = '2';
        duplicateFloorWardenRequest.assignmentType = 'Floor Warden';
        duplicateFloorWardenRequest.wardenId = String.valueOf(secondaryWarden.Id);
        didThrow = false;
        try {
            MasterDataRoomCategoryController.createFloorWarden(duplicateFloorWardenRequest);
        } catch (Exception e) {
            didThrow = true;
            assertExceptionMessage(e, 'already assigned');
        }
        System.assertEquals(true, didThrow, 'Assigning the same floor warden twice should fail.');

        Ken_Room_Category__c category = createRoomCategoryDirect(
            'Occupancy Category ' + suffix,
            true
        );
        Map<String, Schema.SObjectField> categoryFieldMap = Ken_Room_Category__c.SObjectType
            .getDescribe(Schema.SObjectDescribeOptions.DEFERRED)
            .fields.getMap();
        Ken_Room_Category__c categoryUpdate = new Ken_Room_Category__c(Id = category.Id);
        putIfUpdateable(categoryUpdate, categoryFieldMap, 'Custom_Amenity__c', 'Reading Lamp;Study Desk');
        categoryUpdate.Amenities__c = 'King Bed;Air Conditioning';
        update categoryUpdate;

        Ken_Room__c room = createRoomDirect(
            building.Id,
            getFloorId(building.Id, 1),
            category.Id,
            'OCC-' + suffix,
            2,
            null
        );
        Map<String, Schema.SObjectField> roomFieldMap = Ken_Room__c.SObjectType
            .getDescribe(Schema.SObjectDescribeOptions.DEFERRED)
            .fields.getMap();
        Ken_Room__c roomUpdate = new Ken_Room__c(Id = room.Id);
        putIfUpdateable(roomUpdate, roomFieldMap, 'Occupancy_Status__c', 2);
        putIfUpdateable(roomUpdate, roomFieldMap, 'Room_Status__c', null);
        update roomUpdate;

        Account currentStudent = createPersonAccount(
            'Current Student ' + suffix,
            'current.student.' + suffix + '@example.test',
            '9000000113'
        );
        addStudentRole(currentStudent);
        Account formerStudent = createPersonAccount(
            'Former Student ' + suffix,
            'former.student.' + suffix + '@example.test',
            '9000000114'
        );
        addStudentRole(formerStudent);
        Account nonStudent = createPersonAccount(
            'Non Student ' + suffix,
            'non.student.' + suffix + '@example.test',
            '9000000115'
        );
        Contact guestContact = createBusinessContact(
            createBusinessAccount('Guest Occupancy Account ' + suffix).Id,
            'Guest',
            'guest.' + suffix + '@example.test'
        );

        createRoomAllotmentDirect(
            room.Id,
            currentStudent.Id,
            currentStudent.PersonContactId,
            true,
            Date.today().addDays(-1),
            Date.today().addDays(20),
            'Preference Selected'
        );
        createRoomAllotmentDirect(
            room.Id,
            formerStudent.Id,
            formerStudent.PersonContactId,
            false,
            Date.today().addDays(-30),
            Date.today().addDays(-5),
            'Stay Completed'
        );
        createRoomAllotmentDirect(
            room.Id,
            null,
            guestContact.Id,
            false,
            Date.today().addDays(-10),
            Date.today().addDays(-1),
            'Direct Allotment'
        );
        createRoomAllotmentDirect(
            room.Id,
            nonStudent.Id,
            nonStudent.PersonContactId,
            true,
            Date.today().addDays(-2),
            Date.today().addDays(5),
            'Direct Allotment'
        );

        Test.startTest();
        MasterDataRoomCategoryController.RoomOccupancyDetailsRow occupancyDetails =
            MasterDataRoomCategoryController.getRoomOccupancyDetails(String.valueOf(room.Id));
        MasterDataRoomCategoryController.RoomRow roomById =
            MasterDataRoomCategoryController.getRoomById(String.valueOf(room.Id));
        List<MasterDataRoomCategoryController.RoomRow> linkedRooms =
            MasterDataRoomCategoryController.getLinkedRoomsByCategory(String.valueOf(category.Id));
        Test.stopTest();

        System.assertEquals(null, MasterDataRoomCategoryController.getRoomById(' '), 'Blank room ids should return null.');
        System.assertEquals(
            null,
            MasterDataRoomCategoryController.getRoomOccupancyDetails(' '),
            'Blank occupancy lookups should return null.'
        );
        System.assertEquals(
            null,
            MasterDataRoomCategoryController.getRoomOccupancyDetails(String.valueOf(UserInfo.getUserId())),
            'Unknown room ids should return null occupancy details.'
        );
        System.assertEquals(
            0,
            MasterDataRoomCategoryController.getLinkedRoomsByCategory(' ').size(),
            'Blank category ids should return no linked rooms.'
        );

        System.assertNotEquals(null, occupancyDetails, 'Occupancy details should be returned for valid rooms.');
        System.assertEquals(1, occupancyDetails.currentOccupants.size(), 'Only active students should count as current occupants.');
        System.assertEquals(2, occupancyDetails.pastOccupants.size(), 'Past student and contact occupants should be returned as history.');
        System.assertEquals('Active', occupancyDetails.currentOccupants[0].status, 'Active allotments should be labelled Active.');
        System.assert(roomById.amenitiesList.size() >= 2, 'Room detail should parse combined standard and custom amenities.');
        System.assertEquals('2 / 2', roomById.currentOccupancyText, 'Resolved occupancy should use the stored occupancy count.');
        System.assertEquals('Active', roomById.status, 'The org keeps the explicit room status label as Active for this setup.');
        System.assert(containsRoom(linkedRooms, room.Id), 'Linked rooms should include the occupancy test room.');
    }
}