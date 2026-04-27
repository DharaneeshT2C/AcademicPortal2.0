public with sharing class MasterDataRoomCategoryController {
    private static Id cachedWardenPersonAccountRecordTypeId;

    public class OptionItem {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String description { get; set; }

        public OptionItem(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class RoomCategoryRow {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String categoryIdentifier { get; set; }
        @AuraEnabled public String categoryName { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String genderAllowed { get; set; }
        @AuraEnabled public String sharing { get; set; }
        @AuraEnabled public String ac { get; set; }
        @AuraEnabled public String bathroom { get; set; }
        @AuraEnabled public String defaultFeeType { get; set; }
        @AuraEnabled public String defaultFeeTypeId { get; set; }
        @AuraEnabled public List<String> defaultFeeTypeIds { get; set; }
        @AuraEnabled public String amenities { get; set; }
        @AuraEnabled public List<String> amenitiesList { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String statusValue { get; set; }
    }

    public class RoomCategoryFormOptions {
        @AuraEnabled public List<OptionItem> genderOptions { get; set; }
        @AuraEnabled public List<OptionItem> feeTypeOptions { get; set; }
        @AuraEnabled public List<OptionItem> amenitiesOptions { get; set; }
        @AuraEnabled public List<OptionItem> statusOptions { get; set; }
    }

    public class CreateRoomCategoryRequest {
        @AuraEnabled public String categoryName { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String genderAllowed { get; set; }
        @AuraEnabled public String sharing { get; set; }
        @AuraEnabled public String ac { get; set; }
        @AuraEnabled public String bathroom { get; set; }
        @AuraEnabled public String defaultFeeTypeId { get; set; }
        @AuraEnabled public List<String> defaultFeeTypeIds { get; set; }
        @AuraEnabled public String statusValue { get; set; }
        @AuraEnabled public List<String> amenities { get; set; }
    }

    public class BuildingRow {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String gender { get; set; }
        @AuraEnabled public String hostelTypeValue { get; set; }
        @AuraEnabled public String buildingIdentifier { get; set; }
        @AuraEnabled public String floors { get; set; }
        @AuraEnabled public String wardenMode { get; set; }
        @AuraEnabled public String wardenId { get; set; }
        @AuraEnabled public String wardenName { get; set; }
        @AuraEnabled public String wardenPhone { get; set; }
        @AuraEnabled public String capacity { get; set; }
        @AuraEnabled public String currentOccupancy { get; set; }
        @AuraEnabled public String occupancyPercent { get; set; }
        @AuraEnabled public String roomsCount { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String statusValue { get; set; }
    }

    public class RoomRow {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String roomNo { get; set; }
        @AuraEnabled public String buildingId { get; set; }
        @AuraEnabled public String building { get; set; }
        @AuraEnabled public String categoryId { get; set; }
        @AuraEnabled public String floorId { get; set; }
        @AuraEnabled public String floor { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String capacity { get; set; }
        @AuraEnabled public String occupancy { get; set; }
        @AuraEnabled public String amenities { get; set; }
        @AuraEnabled public List<String> amenitiesList { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String statusValue { get; set; }
        @AuraEnabled public String roomIdentifier { get; set; }
        @AuraEnabled public String feeType { get; set; }
        @AuraEnabled public String currentOccupancyText { get; set; }
    }

    public class BuildingFormOptions {
        @AuraEnabled public List<OptionItem> genderOptions { get; set; }
        @AuraEnabled public List<OptionItem> hostelTypeOptions { get; set; }
        @AuraEnabled public List<OptionItem> statusOptions { get; set; }
        @AuraEnabled public List<OptionItem> wardenModeOptions { get; set; }
        @AuraEnabled public List<OptionItem> wardenOptions { get; set; }
    }

    public class CreateBuildingRequest {
        @AuraEnabled public String buildingName { get; set; }
        @AuraEnabled public String genderValue { get; set; }
        @AuraEnabled public String hostelTypeValue { get; set; }
        @AuraEnabled public String statusValue { get; set; }
        @AuraEnabled public String numberOfFloors { get; set; }
        @AuraEnabled public String wardenMode { get; set; }
        @AuraEnabled public String buildingWarden { get; set; }
    }

    public class RoomFloorOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String buildingValue { get; set; }
    }

    public class RoomFormOptions {
        @AuraEnabled public List<OptionItem> buildingOptions { get; set; }
        @AuraEnabled public List<RoomFloorOption> floorOptions { get; set; }
        @AuraEnabled public List<OptionItem> categoryOptions { get; set; }
        @AuraEnabled public List<OptionItem> statusOptions { get; set; }
        @AuraEnabled public Map<String, String> categoryCapacityById { get; set; }
    }

    public class BuildingFloorWardenRow {
        @AuraEnabled public Integer floorNumber { get; set; }
        @AuraEnabled public String floorName { get; set; }
        @AuraEnabled public String wardenId { get; set; }
        @AuraEnabled public String wardenName { get; set; }
        @AuraEnabled public String wardenPhone { get; set; }
        @AuraEnabled public String assignmentTypeLabel { get; set; }
        @AuraEnabled public Boolean isInheritedFromBuilding { get; set; }
    }

    public class CreateFloorWardenRequest {
        @AuraEnabled public String buildingId { get; set; }
        @AuraEnabled public String floorNumber { get; set; }
        @AuraEnabled public String wardenId { get; set; }
        @AuraEnabled public String wardenName { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String assignmentType { get; set; }
    }

    public class CreateRoomRequest {
        @AuraEnabled public String buildingValue { get; set; }
        @AuraEnabled public String floorId { get; set; }
        @AuraEnabled public String roomNumber { get; set; }
        @AuraEnabled public String roomCategoryId { get; set; }
        @AuraEnabled public String capacity { get; set; }
        @AuraEnabled public String statusValue { get; set; }
    }

    public class BulkRoomCsvRow {
        @AuraEnabled public Integer rowNumber { get; set; }
        @AuraEnabled public String building { get; set; }
        @AuraEnabled public String floor { get; set; }
        @AuraEnabled public String roomNumber { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String capacity { get; set; }
        @AuraEnabled public String status { get; set; }
    }

    public class BulkRoomCsvError {
        @AuraEnabled public Integer rowNumber { get; set; }
        @AuraEnabled public String message { get; set; }
    }

    public class BulkRoomCsvResponse {
        @AuraEnabled public Integer processedCount { get; set; }
        @AuraEnabled public Integer successCount { get; set; }
        @AuraEnabled public Integer failureCount { get; set; }
        @AuraEnabled public List<BulkRoomCsvError> errors { get; set; }

        public BulkRoomCsvResponse() {
            processedCount = 0;
            successCount = 0;
            failureCount = 0;
            errors = new List<BulkRoomCsvError>();
        }
    }

    public class ActivityHistoryEventRow {
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String subtitle { get; set; }
        @AuraEnabled public Datetime eventAt { get; set; }
    }

    public class BuildingActivityHistoryRow {
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public String createdByName { get; set; }
        @AuraEnabled public Datetime createdDate { get; set; }
        @AuraEnabled public String lastModifiedByName { get; set; }
        @AuraEnabled public Datetime lastModifiedDate { get; set; }
        @AuraEnabled public List<ActivityHistoryEventRow> events { get; set; }
    }

    public class RoomCategoryActivityHistoryRow {
        @AuraEnabled public String createdByName { get; set; }
        @AuraEnabled public Datetime createdDate { get; set; }
        @AuraEnabled public String lastModifiedByName { get; set; }
        @AuraEnabled public Datetime lastModifiedDate { get; set; }
        @AuraEnabled public List<ActivityHistoryEventRow> events { get; set; }
    }

    public class RoomOccupantRow {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String studentName { get; set; }
        @AuraEnabled public String rollNo { get; set; }
        @AuraEnabled public Date checkInDate { get; set; }
        @AuraEnabled public Date checkOutDate { get; set; }
        @AuraEnabled public String allocationType { get; set; }
        @AuraEnabled public String enrollmentCycle { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Boolean active { get; set; }
    }

    public class RoomOccupancyDetailsRow {
        @AuraEnabled public List<RoomOccupantRow> currentOccupants { get; set; }
        @AuraEnabled public List<RoomOccupantRow> pastOccupants { get; set; }
        @AuraEnabled public String createdByName { get; set; }
        @AuraEnabled public Datetime createdDate { get; set; }
        @AuraEnabled public String lastModifiedByName { get; set; }
        @AuraEnabled public Datetime lastModifiedDate { get; set; }
        @AuraEnabled public List<ActivityHistoryEventRow> events { get; set; }
    }

    @AuraEnabled
    public static List<RoomCategoryRow> getRoomCategories(String statusFilter) {
        Boolean isActive;
        if (statusFilter == 'active') {
            isActive = true;
        } else if (statusFilter == 'inactive') {
            isActive = false;
        }
        if (!Schema.sObjectType.Ken_Room_Category__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room categories.');
        }

        Map<String, Schema.SObjectField> roomCategoryFieldMap = Ken_Room_Category__c.SObjectType.getDescribe().fields.getMap();
        String selectClause = 'SELECT Id, Name__c, Name, Description__c, Active__c, Amenities__c, Gender_Allowed__c, Sharing__c, Ac_Non_Ac__c, Bathroom__c, Capacity__c';
        if (roomCategoryFieldMap.containsKey('Custom_Amenity__c')) {
            selectClause += ', Custom_Amenity__c';
        }

        String queryText = selectClause + ' FROM Ken_Room_Category__c';
        if (isActive != null) {
            queryText += ' WHERE Active__c = ' + String.valueOf(isActive);
        }
        queryText += ' ORDER BY LastModifiedDate DESC LIMIT 500';
        List<Ken_Room_Category__c> rows = (List<Ken_Room_Category__c>) Database.query(queryText); // NOPMD ApexSOQLInjection - query text is assembled from schema metadata and internal booleans only.

        Set<Id> roomCategoryIds = new Set<Id>();
        for (Ken_Room_Category__c item : rows) {
            roomCategoryIds.add(item.Id);
        }
        Map<Id, List<OptionItem>> feeTypeSelectionsByCategory = getRoomCategoryFeeTypeSelections(roomCategoryIds);

        List<RoomCategoryRow> response = new List<RoomCategoryRow>();
        for (Ken_Room_Category__c item : rows) {
            response.add(mapRoomCategoryRow(item, feeTypeSelectionsByCategory.get(item.Id)));
        }

        return response;
    }

    @AuraEnabled(cacheable=true)
    public static RoomCategoryFormOptions getRoomCategoryFormOptions() {
        RoomCategoryFormOptions options = new RoomCategoryFormOptions();
        options.genderOptions = new List<OptionItem>();
        options.feeTypeOptions = new List<OptionItem>();
        options.amenitiesOptions = new List<OptionItem>();
        options.statusOptions = new List<OptionItem>{
            new OptionItem('Active', 'active'),
            new OptionItem('Inactive', 'inactive')
        };

        for (Schema.PicklistEntry entry : Ken_Room_Category__c.Gender_Allowed__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                options.genderOptions.add(new OptionItem(entry.getLabel(), entry.getValue()));
            }
        }

        for (Schema.PicklistEntry entry : Ken_Room_Category__c.Amenities__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                options.amenitiesOptions.add(new OptionItem(entry.getLabel(), entry.getValue()));
            }
        }

        // Append custom amenities (if object exists in org) so they can be selected in UI.
        for (String customAmenityName : fetchCustomAmenityNames()) {
            if (!containsOptionValue(options.amenitiesOptions, customAmenityName)) {
                options.amenitiesOptions.add(new OptionItem(customAmenityName, customAmenityName));
            }
        }
        if (!Schema.sObjectType.Ken_Fee_Type__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view fee types.');
        }

        for (Ken_Fee_Type__c feeType : [
            SELECT Id, Name, Fee_Type_Name__c
            FROM Ken_Fee_Type__c
            WHERE Fee_Category__c = 'Hostel'
              AND Status__c = 'Active'
            ORDER BY Fee_Type_Name__c ASC, Name ASC
            LIMIT 500
        ]) {
            String label = getKenFeeTypeLabel(feeType);
            options.feeTypeOptions.add(new OptionItem(label, String.valueOf(feeType.Id)));
        }

        return options;
    }

    @AuraEnabled
    public static Id createRoomCategory(CreateRoomCategoryRequest inputRequest) {
        if (inputRequest == null) {
            throw new AuraHandledException('Room category payload is required.');
        }

        String categoryName = sanitize(inputRequest.categoryName);
        String genderAllowed = sanitize(inputRequest.genderAllowed);
        String sharingInput = sanitize(inputRequest.sharing);
        String acValue = normalizeRoomCategoryAcValue(inputRequest.ac);
        String bathroomValue = normalizeRoomCategoryBathroomValue(inputRequest.bathroom);
        String statusValue = normalizeRoomCategoryStatusValue(inputRequest.statusValue);
        List<Id> feeTypeIds = normalizeRoomCategoryFeeTypeIds(inputRequest.defaultFeeTypeIds, inputRequest.defaultFeeTypeId);
        List<String> selectedAmenities = normalizeAmenities(inputRequest.amenities);
        Integer sharingValue = toPositiveInteger(sharingInput, 'Sharing is required and must be a positive whole number.');

        if (String.isBlank(categoryName)) {
            throw new AuraHandledException('Category Name is required.');
        }
        if (String.isBlank(acValue)) {
            throw new AuraHandledException('AC / Non AC is required.');
        }
        if (String.isBlank(bathroomValue)) {
            throw new AuraHandledException('Bathroom is required.');
        }
        if (String.isBlank(statusValue)) {
            throw new AuraHandledException('Status is required.');
        }

        Set<String> standardAmenityValues = getAmenityPicklistValueSet();
        List<String> standardAmenities = new List<String>();
        List<String> customAmenities = new List<String>();
        for (String amenityValue : selectedAmenities) {
            if (standardAmenityValues.contains(amenityValue)) {
                standardAmenities.add(amenityValue);
            } else {
                customAmenities.add(amenityValue);
            }
        }

        Ken_Room_Category__c recordToInsert = new Ken_Room_Category__c();
        Map<String, Schema.SObjectField> roomCategoryFieldMap = Ken_Room_Category__c.SObjectType.getDescribe().fields.getMap();
        if (roomCategoryFieldMap.containsKey('Name')) {
            Schema.DescribeFieldResult standardNameDescribe = roomCategoryFieldMap.get('Name').getDescribe();
            if (standardNameDescribe.isCreateable() && !standardNameDescribe.isCalculated()) {
                recordToInsert.put('Name', categoryName);
            }
        }
        if (roomCategoryFieldMap.containsKey('Name__c')) {
            Schema.DescribeFieldResult customNameDescribe = roomCategoryFieldMap.get('Name__c').getDescribe();
            if (customNameDescribe.isCreateable() && !customNameDescribe.isCalculated()) {
                recordToInsert.Name__c = categoryName;
            }
        }
        recordToInsert.Description__c = sanitize(inputRequest.description);
        recordToInsert.Gender_Allowed__c = genderAllowed;
        recordToInsert.Sharing__c = sharingValue;
        recordToInsert.Capacity__c = sharingValue;
        recordToInsert.Ac_Non_Ac__c = acValue;
        recordToInsert.Bathroom__c = bathroomValue;
        recordToInsert.Active__c = statusValue == 'active';
        recordToInsert.Amenities__c = standardAmenities.isEmpty() ? null : String.join(standardAmenities, ';');
        // Store non-picklist custom amenities in Custom_Amenity__c if field exists on Ken_Room_Category__c.
        if (!customAmenities.isEmpty() && roomCategoryFieldMap.containsKey('Custom_Amenity__c')) {
            recordToInsert.put('Custom_Amenity__c', String.join(customAmenities, ';'));
        }
        if (!Schema.sObjectType.Ken_Room_Category__c.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create room categories.');
        }

        insert recordToInsert;
        syncRoomCategoryFeeTypes(recordToInsert.Id, feeTypeIds);
        upsertCustomAmenities(customAmenities, recordToInsert.Id);
        return recordToInsert.Id;
    }

    @AuraEnabled
    public static Id updateRoomCategory(String roomCategoryId, CreateRoomCategoryRequest inputRequest) {
        if (String.isBlank(roomCategoryId)) {
            throw new AuraHandledException('Room category is required.');
        }
        if (inputRequest == null) {
            throw new AuraHandledException('Room category payload is required.');
        }

        Id roomCategoryRecordId = toIdValue(roomCategoryId, 'Invalid Room Category value.');
        Map<String, Schema.SObjectField> roomCategoryFieldMap = Ken_Room_Category__c.SObjectType.getDescribe().fields.getMap();
        if (!Schema.sObjectType.Ken_Room_Category__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room categories.');
        }

        String categoryNameInput = sanitize(inputRequest.categoryName);
        String descriptionInput = sanitize(inputRequest.description);
        String rawGenderAllowedInput = inputRequest.genderAllowed;
        String genderAllowedInput = sanitize(rawGenderAllowedInput);
        String sharingInput = sanitize(inputRequest.sharing);
        String acInput = inputRequest.ac;
        String bathroomInput = inputRequest.bathroom;
        String statusValueInput = normalizeRoomCategoryStatusValue(inputRequest.statusValue);
        Boolean hasFeeTypeInput = inputRequest.defaultFeeTypeIds != null || inputRequest.defaultFeeTypeId != null;
        List<Id> feeTypeIdsInput = normalizeRoomCategoryFeeTypeIds(inputRequest.defaultFeeTypeIds, inputRequest.defaultFeeTypeId);
        Boolean hasAmenitiesInput = inputRequest.amenities != null;
        List<String> selectedAmenitiesInput = normalizeAmenities(inputRequest.amenities);
        Boolean hasSharingInput = inputRequest.sharing != null;
        Boolean hasAcInput = inputRequest.ac != null;
        Boolean hasBathroomInput = inputRequest.bathroom != null;

        String queryText =
            'SELECT Id, Name__c, Name, Description__c, Gender_Allowed__c, Sharing__c, Ac_Non_Ac__c, Bathroom__c, Capacity__c, Active__c, Amenities__c';
        if (roomCategoryFieldMap.containsKey('Custom_Amenity__c')) {
            queryText += ', Custom_Amenity__c';
        }
        queryText += ' FROM Ken_Room_Category__c WHERE Id = :roomCategoryRecordId LIMIT 1';

        List<Ken_Room_Category__c> existingRows = (List<Ken_Room_Category__c>) Database.query(queryText); // NOPMD ApexSOQLInjection - query text is assembled from schema metadata and bind variables only.
        if (existingRows.isEmpty()) {
            throw new AuraHandledException('Room category record was not found.');
        }

        Ken_Room_Category__c existingRecord = existingRows[0];
        String categoryName = firstNonBlank(new List<String>{
            categoryNameInput,
            sanitize(existingRecord.Name__c),
            sanitize(existingRecord.Name)
        });
        String genderAllowed = rawGenderAllowedInput != null
            ? genderAllowedInput
            : sanitize(existingRecord.Gender_Allowed__c);
        String statusValue = firstNonBlank(new List<String>{
            statusValueInput,
            existingRecord.Active__c == true ? 'active' : 'inactive'
        });
        String descriptionValue = descriptionInput != null ? descriptionInput : sanitize(existingRecord.Description__c);
        Integer sharingValue = hasSharingInput
            ? toPositiveInteger(sharingInput, 'Sharing is required and must be a positive whole number.')
            : (existingRecord.Sharing__c != null ? existingRecord.Sharing__c.intValue() : toWholeNumber(existingRecord.Capacity__c));
        String acValue = hasAcInput
            ? normalizeRoomCategoryAcValue(acInput)
            : resolveRoomCategoryAcLabel(existingRecord);
        String bathroomValue = hasBathroomInput
            ? normalizeRoomCategoryBathroomValue(bathroomInput)
            : resolveRoomCategoryBathroomLabel(existingRecord);
        List<String> selectedAmenities = hasAmenitiesInput
            ? selectedAmenitiesInput
            : parseAmenities(combineAmenities(existingRecord.Amenities__c, getCustomAmenitiesFromRoomCategory(existingRecord)));

        if (String.isBlank(categoryName)) {
            throw new AuraHandledException('Category Name is required.');
        }
        if (hasAcInput && String.isBlank(acValue)) {
            throw new AuraHandledException('AC / Non AC is required.');
        }
        if (hasBathroomInput && String.isBlank(bathroomValue)) {
            throw new AuraHandledException('Bathroom is required.');
        }
        if (String.isBlank(statusValue)) {
            throw new AuraHandledException('Status is required.');
        }

        Set<String> standardAmenityValues = getAmenityPicklistValueSet();
        List<String> standardAmenities = new List<String>();
        List<String> customAmenities = new List<String>();
        for (String amenityValue : selectedAmenities) {
            if (standardAmenityValues.contains(amenityValue)) {
                standardAmenities.add(amenityValue);
            } else {
                customAmenities.add(amenityValue);
            }
        }

        if (roomCategoryFieldMap.containsKey('Name')) {
            Schema.DescribeFieldResult standardNameDescribe = roomCategoryFieldMap.get('Name').getDescribe();
            if (standardNameDescribe.isUpdateable() && !standardNameDescribe.isCalculated()) {
                existingRecord.put('Name', categoryName);
            }
        }
        if (roomCategoryFieldMap.containsKey('Name__c')) {
            Schema.DescribeFieldResult customNameDescribe = roomCategoryFieldMap.get('Name__c').getDescribe();
            if (customNameDescribe.isUpdateable() && !customNameDescribe.isCalculated()) {
                existingRecord.Name__c = categoryName;
            }
        }
        existingRecord.Description__c = descriptionValue;
        existingRecord.Gender_Allowed__c = genderAllowed;
        existingRecord.Sharing__c = sharingValue;
        existingRecord.Capacity__c = sharingValue;
        existingRecord.Ac_Non_Ac__c = hasAcInput ? acValue : existingRecord.Ac_Non_Ac__c;
        existingRecord.Bathroom__c = hasBathroomInput ? bathroomValue : existingRecord.Bathroom__c;
        existingRecord.Active__c = statusValue == 'active';
        existingRecord.Amenities__c = standardAmenities.isEmpty() ? null : String.join(standardAmenities, ';');
        if (roomCategoryFieldMap.containsKey('Custom_Amenity__c')) {
            existingRecord.put('Custom_Amenity__c', customAmenities.isEmpty() ? null : String.join(customAmenities, ';'));
        }
        if (!Schema.sObjectType.Ken_Room_Category__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update room categories.');
        }

        update existingRecord;
        if (hasFeeTypeInput) {
            syncRoomCategoryFeeTypes(existingRecord.Id, feeTypeIdsInput);
        }
        upsertCustomAmenities(customAmenities, existingRecord.Id);
        return existingRecord.Id;
    }

    @AuraEnabled
    public static void deleteRoomCategory(String roomCategoryId) {
        if (String.isBlank(roomCategoryId)) {
            throw new AuraHandledException('Room category is required.');
        }

        Id roomCategoryRecordId = toIdValue(roomCategoryId, 'Invalid Room Category value.');
        if (!Schema.sObjectType.Ken_Room_Category__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room categories.');
        }
        List<Ken_Room_Category__c> roomCategories = [
            SELECT Id
            FROM Ken_Room_Category__c
            WHERE Id = :roomCategoryRecordId
            LIMIT 1
        ];
        if (roomCategories.isEmpty()) {
            throw new AuraHandledException('Room category record was not found.');
        }
        if (!Schema.sObjectType.Ken_Room_Category__c.isDeletable()) {
            throw new AuraHandledException('You do not have permission to delete room categories.');
        }
        try {
            delete roomCategories[0];
        } catch (DmlException e) {
            throw new AuraHandledException(firstNonBlank(new List<String>{
                e.getDmlMessage(0),
                'Unable to delete room category.'
            }));
        }
    }

    @AuraEnabled
    public static OptionItem addCustomAmenity(String amenityName) {
        String cleanedName = sanitize(amenityName);
        if (String.isBlank(cleanedName)) {
            throw new AuraHandledException('Custom amenity name is required.');
        }

        createCustomAmenityRecord(cleanedName, null);
        return new OptionItem(cleanedName, cleanedName);
    }

    @AuraEnabled
    public static List<BuildingRow> getBuildings(String statusFilter) {
        String normalizedStatusFilter = normalizeBuildingStatusValue(statusFilter);
        if (!Schema.sObjectType.Ken_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view buildings.');
        }

        String queryText = 'SELECT Id, Name, Name__c, Hostel_Type__c, Number_Of_Floors__c, Warden_Assignment_Mode__c, ' +
            'Capacity__c, Total_Rooms__c, Total_Floors__c, Occupancy__c, Current_Occupancy__c, Status__c, Warden__c, Warden__r.Name, Warden__r.Phone ' +
            'FROM Ken_Building__c';
        if (normalizedStatusFilter == 'Active' || normalizedStatusFilter == 'Inactive') {
            queryText += ' WHERE Status__c = :normalizedStatusFilter';
        }
        queryText += ' ORDER BY LastModifiedDate DESC LIMIT 500';
        List<Ken_Building__c> buildings = (List<Ken_Building__c>) Database.query(queryText); // NOPMD ApexSOQLInjection - query text is assembled from constant metadata and bind variables only.
        syncBuildingTotalRooms(buildings, true, false);

        List<BuildingRow> response = new List<BuildingRow>();
        for (Ken_Building__c building : buildings) {
            BuildingRow row = mapBuildingRow(building);
            response.add(row);
        }

        return response;
    }

    @AuraEnabled
    public static BuildingRow getBuildingDetail(String buildingId, String buildingName) {
        Id lookupId = toIdValueAllowNull(buildingId);
        String normalizedName = sanitize(buildingName);
        if (!Schema.sObjectType.Ken_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view buildings.');
        }

        String queryText =
            'SELECT Id, Name, Name__c, Hostel_Type__c, Number_Of_Floors__c, Warden_Assignment_Mode__c, ' +
            'Capacity__c, Total_Rooms__c, Total_Floors__c, Occupancy__c, Current_Occupancy__c, Status__c, Warden__c, Warden__r.Name, Warden__r.Phone ' +
            'FROM Ken_Building__c';
        if (lookupId != null) {
            queryText += ' WHERE Id = :lookupId';
        } else if (String.isNotBlank(normalizedName)) {
            queryText += ' WHERE Name__c = :normalizedName OR Name = :normalizedName';
        } else {
            return null;
        }
        queryText += ' ORDER BY LastModifiedDate DESC LIMIT 1';

        List<Ken_Building__c> results = (List<Ken_Building__c>) Database.query(queryText); // NOPMD ApexSOQLInjection - query text is assembled from constant metadata and bind variables only.
        if (results.isEmpty()) {
            return null;
        }
        syncBuildingTotalRooms(results, true, false);
        return mapBuildingRow(results[0]);
    }

    @AuraEnabled
    public static List<RoomRow> getRooms(String statusFilter) {
        Map<String, Schema.SObjectField> roomFieldMap = Ken_Room__c.SObjectType.getDescribe().fields.getMap();
        Map<String, Schema.SObjectField> roomCategoryFieldMap = Ken_Room_Category__c.SObjectType.getDescribe().fields.getMap();
        if (!Schema.sObjectType.Ken_Room__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view rooms.');
        }

        String selectClause = 'SELECT Id, Name';
        if (roomFieldMap.containsKey('Room_Number__c')) {
            selectClause += ', Room_Number__c';
        }
        if (roomFieldMap.containsKey('Block__c')) {
            selectClause += ', Block__c';
        }
        if (roomFieldMap.containsKey('Floor_No__c')) {
            selectClause += ', Floor_No__c';
        }
        if (roomFieldMap.containsKey('Floor__c')) {
            selectClause += ', Floor__c, Floor__r.Name';
        }
        if (roomFieldMap.containsKey('Housing_Category__c')) {
            selectClause += ', Housing_Category__c';
        }
        if (roomFieldMap.containsKey('Capacity__c')) {
            selectClause += ', Capacity__c';
        }
        if (roomFieldMap.containsKey('Occupancy_Status__c')) {
            selectClause += ', Occupancy_Status__c';
        }
        if (roomFieldMap.containsKey('Building__c')) {
            selectClause += ', Building__c, Building__r.Name__c, Building__r.Name';
        }
        if (roomFieldMap.containsKey('Room_Status__c')) {
            selectClause += ', Room_Status__c';
        }
        if (roomFieldMap.containsKey('Room_Category__c')) {
            selectClause += ', Room_Category__c, Room_Category__r.Name__c, Room_Category__r.Name, Room_Category__r.Amenities__c';
            if (roomCategoryFieldMap.containsKey('Custom_Amenity__c')) {
                selectClause += ', Room_Category__r.Custom_Amenity__c';
            }
        }

        String queryText = selectClause + ' FROM Ken_Room__c ORDER BY LastModifiedDate DESC LIMIT 500';
        List<SObject> roomRecords = Database.query(queryText); // NOPMD ApexSOQLInjection - query text is assembled from schema metadata only.
        String normalizedStatusFilter = normalizeRoomStatusFilter(statusFilter);
        Set<Id> roomCategoryIds = new Set<Id>();
        for (SObject roomRecord : roomRecords) {
            Id roomCategoryId = (Id) getFieldValue(roomRecord, 'Room_Category__c');
            if (roomCategoryId != null) {
                roomCategoryIds.add(roomCategoryId);
            }
        }
        Map<Id, List<OptionItem>> feeTypeSelectionsByCategory = getRoomCategoryFeeTypeSelections(roomCategoryIds);

        List<RoomRow> response = new List<RoomRow>();
        for (SObject roomRecord : roomRecords) {
            Integer capacity = toWholeNumber(getFieldValue(roomRecord, 'Capacity__c'));
            Integer occupancy = toWholeNumber(getFieldValue(roomRecord, 'Occupancy_Status__c'));
            String explicitRoomStatus = getStringValue(roomRecord, 'Room_Status__c');
            String statusValue = resolveRoomStatusValue(occupancy, capacity, explicitRoomStatus);
            Integer effectiveOccupancy = resolveEffectiveRoomOccupancy(occupancy, capacity, statusValue);

            if (normalizedStatusFilter != null && statusValue != normalizedStatusFilter) {
                continue;
            }

            RoomRow row = new RoomRow();
            row.id = (Id) roomRecord.get('Id');
            row.roomNo = firstNonBlank(new List<String>{
                getStringValue(roomRecord, 'Room_Number__c'),
                getStringValue(roomRecord, 'Name')
            });
            row.buildingId = getStringValue(roomRecord, 'Building__c');
            row.building = resolveRoomBuildingLabel(roomRecord);
            row.categoryId = getStringValue(roomRecord, 'Room_Category__c');
            row.floorId = getStringValue(roomRecord, 'Floor__c');
            row.floor = firstNonBlank(new List<String>{
                getStringValue(roomRecord, 'Floor_No__c'),
                getNestedFieldValue(roomRecord, 'Floor__r', 'Name'),
                getStringValue(roomRecord, 'Floor__c'),
                '--'
            });
            row.category = firstNonBlank(new List<String>{
                getStringValue(roomRecord, 'Housing_Category__c'),
                getNestedFieldValue(roomRecord, 'Room_Category__r', 'Name__c'),
                getNestedFieldValue(roomRecord, 'Room_Category__r', 'Name'),
                '--'
            });

            row.capacity = String.valueOf(capacity);
            row.occupancy = String.valueOf(Math.max(0, effectiveOccupancy));

            String amenitiesRaw = getNestedFieldValue(roomRecord, 'Room_Category__r', 'Amenities__c');
            String customAmenitiesRaw = getNestedFieldValue(roomRecord, 'Room_Category__r', 'Custom_Amenity__c');
            String combinedAmenities = combineAmenities(amenitiesRaw, customAmenitiesRaw);
            Integer amenitiesCount = countAmenities(combinedAmenities);
            row.amenities = amenitiesCount > 0 ? String.valueOf(amenitiesCount) + ' amenities' : '--';
            row.amenitiesList = parseAmenities(combinedAmenities);

            row.statusValue = statusValue;
            row.status = getRoomStatusLabel(statusValue);
            row.roomIdentifier = getStringValue(roomRecord, 'Name');
            row.feeType = resolveRoomFeeType(
                (Id) getFieldValue(roomRecord, 'Room_Category__c'),
                feeTypeSelectionsByCategory
            );
            row.currentOccupancyText = String.valueOf(Math.max(0, effectiveOccupancy)) + ' / ' + String.valueOf(Math.max(0, capacity));
            response.add(row);
        }

        return response;
    }

    @AuraEnabled
    public static List<RoomRow> getLinkedRoomsByCategory(String categoryId) {
        Id roomCategoryId = toIdValue(categoryId, 'Invalid Room Category value.');
        if (roomCategoryId == null) {
            return new List<RoomRow>();
        }

        Map<String, Schema.SObjectField> roomFieldMap = Ken_Room__c.SObjectType.getDescribe().fields.getMap();
        Map<String, Schema.SObjectField> roomCategoryFieldMap = Ken_Room_Category__c.SObjectType.getDescribe().fields.getMap();
        if (!Schema.sObjectType.Ken_Room__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view rooms.');
        }

        String selectClause = 'SELECT Id, Name';
        if (roomFieldMap.containsKey('Room_Number__c')) {
            selectClause += ', Room_Number__c';
        }
        if (roomFieldMap.containsKey('Block__c')) {
            selectClause += ', Block__c';
        }
        if (roomFieldMap.containsKey('Floor_No__c')) {
            selectClause += ', Floor_No__c';
        }
        if (roomFieldMap.containsKey('Floor__c')) {
            selectClause += ', Floor__c, Floor__r.Name';
        }
        if (roomFieldMap.containsKey('Housing_Category__c')) {
            selectClause += ', Housing_Category__c';
        }
        if (roomFieldMap.containsKey('Capacity__c')) {
            selectClause += ', Capacity__c';
        }
        if (roomFieldMap.containsKey('Occupancy_Status__c')) {
            selectClause += ', Occupancy_Status__c';
        }
        if (roomFieldMap.containsKey('Building__c')) {
            selectClause += ', Building__c, Building__r.Name__c, Building__r.Name';
        }
        if (roomFieldMap.containsKey('Room_Status__c')) {
            selectClause += ', Room_Status__c';
        }
        if (roomFieldMap.containsKey('Room_Category__c')) {
            selectClause += ', Room_Category__c, Room_Category__r.Name__c, Room_Category__r.Name, Room_Category__r.Amenities__c';
            if (roomCategoryFieldMap.containsKey('Custom_Amenity__c')) {
                selectClause += ', Room_Category__r.Custom_Amenity__c';
            }
        }

        String queryText = selectClause +
            ' FROM Ken_Room__c WHERE Room_Category__c = :roomCategoryId ORDER BY LastModifiedDate DESC LIMIT 500';
        List<SObject> roomRecords = Database.query(queryText); // NOPMD ApexSOQLInjection - query text is assembled from schema metadata and bind variables only.
        Map<Id, List<OptionItem>> feeTypeSelectionsByCategory = getRoomCategoryFeeTypeSelections(new Set<Id>{ roomCategoryId });

        List<RoomRow> response = new List<RoomRow>();
        for (SObject roomRecord : roomRecords) {
            Integer capacity = toWholeNumber(getFieldValue(roomRecord, 'Capacity__c'));
            Integer occupancy = toWholeNumber(getFieldValue(roomRecord, 'Occupancy_Status__c'));
            String explicitRoomStatus = getStringValue(roomRecord, 'Room_Status__c');
            String statusValue = resolveRoomStatusValue(occupancy, capacity, explicitRoomStatus);
            Integer effectiveOccupancy = resolveEffectiveRoomOccupancy(occupancy, capacity, statusValue);

            RoomRow row = new RoomRow();
            row.id = (Id) roomRecord.get('Id');
            row.roomNo = firstNonBlank(new List<String>{
                getStringValue(roomRecord, 'Room_Number__c'),
                getStringValue(roomRecord, 'Name')
            });
            row.buildingId = getStringValue(roomRecord, 'Building__c');
            row.building = resolveRoomBuildingLabel(roomRecord);
            row.categoryId = getStringValue(roomRecord, 'Room_Category__c');
            row.floorId = getStringValue(roomRecord, 'Floor__c');
            row.floor = firstNonBlank(new List<String>{
                getStringValue(roomRecord, 'Floor_No__c'),
                getNestedFieldValue(roomRecord, 'Floor__r', 'Name'),
                getStringValue(roomRecord, 'Floor__c'),
                '--'
            });
            row.category = firstNonBlank(new List<String>{
                getStringValue(roomRecord, 'Housing_Category__c'),
                getNestedFieldValue(roomRecord, 'Room_Category__r', 'Name__c'),
                getNestedFieldValue(roomRecord, 'Room_Category__r', 'Name'),
                '--'
            });

            row.capacity = String.valueOf(capacity);
            row.occupancy = String.valueOf(Math.max(0, effectiveOccupancy));

            String amenitiesRaw = getNestedFieldValue(roomRecord, 'Room_Category__r', 'Amenities__c');
            String customAmenitiesRaw = getNestedFieldValue(roomRecord, 'Room_Category__r', 'Custom_Amenity__c');
            String combinedAmenities = combineAmenities(amenitiesRaw, customAmenitiesRaw);
            Integer amenitiesCount = countAmenities(combinedAmenities);
            row.amenities = amenitiesCount > 0 ? String.valueOf(amenitiesCount) + ' amenities' : '--';
            row.amenitiesList = parseAmenities(combinedAmenities);

            row.statusValue = statusValue;
            row.status = getRoomStatusLabel(statusValue);
            row.roomIdentifier = getStringValue(roomRecord, 'Name');
            row.feeType = resolveRoomFeeType(
                (Id) getFieldValue(roomRecord, 'Room_Category__c'),
                feeTypeSelectionsByCategory
            );
            row.currentOccupancyText = String.valueOf(Math.max(0, effectiveOccupancy)) + ' / ' + String.valueOf(Math.max(0, capacity));
            response.add(row);
        }

        return response;
    }

    @AuraEnabled
    public static RoomCategoryRow getRoomCategoryDetail(String categoryId, String categoryName) {
        Id lookupId = toIdValueAllowNull(categoryId);
        String normalizedName = sanitize(categoryName);
        if (!Schema.sObjectType.Ken_Room_Category__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room categories.');
        }

        Map<String, Schema.SObjectField> roomCategoryFieldMap = Ken_Room_Category__c.SObjectType.getDescribe().fields.getMap();
        String selectClause =
            'SELECT Id, Name__c, Name, Description__c, Active__c, Amenities__c, Gender_Allowed__c, Sharing__c, Ac_Non_Ac__c, Bathroom__c, Capacity__c';
        if (roomCategoryFieldMap.containsKey('Custom_Amenity__c')) {
            selectClause += ', Custom_Amenity__c';
        }

        String queryText = selectClause + ' FROM Ken_Room_Category__c';
        if (lookupId != null) {
            queryText += ' WHERE Id = :lookupId';
        } else if (String.isNotBlank(normalizedName)) {
            queryText += ' WHERE Name__c = :normalizedName OR Name = :normalizedName';
        } else {
            return null;
        }
        queryText += ' ORDER BY LastModifiedDate DESC LIMIT 1';

        List<Ken_Room_Category__c> rows = (List<Ken_Room_Category__c>) Database.query(queryText); // NOPMD ApexSOQLInjection - query text is assembled from schema metadata and bind variables only.
        if (rows.isEmpty()) {
            return null;
        }

        Map<Id, List<OptionItem>> feeTypeSelectionsByCategory = getRoomCategoryFeeTypeSelections(new Set<Id>{ rows[0].Id });
        return mapRoomCategoryRow(rows[0], feeTypeSelectionsByCategory.get(rows[0].Id));
    }

    @AuraEnabled(cacheable=true)
    public static RoomRow getRoomById(String roomId) {
        Id roomRecordId = toIdValueAllowNull(roomId);
        if (roomRecordId == null) {
            return null;
        }

        Map<String, Schema.SObjectField> roomFieldMap = Ken_Room__c.SObjectType.getDescribe().fields.getMap();
        Map<String, Schema.SObjectField> roomCategoryFieldMap = Ken_Room_Category__c.SObjectType.getDescribe().fields.getMap();
        if (!Schema.sObjectType.Ken_Room__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view rooms.');
        }

        String selectClause = 'SELECT Id, Name';
        if (roomFieldMap.containsKey('Room_Number__c')) {
            selectClause += ', Room_Number__c';
        }
        if (roomFieldMap.containsKey('Block__c')) {
            selectClause += ', Block__c';
        }
        if (roomFieldMap.containsKey('Floor_No__c')) {
            selectClause += ', Floor_No__c';
        }
        if (roomFieldMap.containsKey('Floor__c')) {
            selectClause += ', Floor__c, Floor__r.Name';
        }
        if (roomFieldMap.containsKey('Housing_Category__c')) {
            selectClause += ', Housing_Category__c';
        }
        if (roomFieldMap.containsKey('Capacity__c')) {
            selectClause += ', Capacity__c';
        }
        if (roomFieldMap.containsKey('Occupancy_Status__c')) {
            selectClause += ', Occupancy_Status__c';
        }
        if (roomFieldMap.containsKey('Building__c')) {
            selectClause += ', Building__c, Building__r.Name__c, Building__r.Name';
        }
        if (roomFieldMap.containsKey('Room_Status__c')) {
            selectClause += ', Room_Status__c';
        }
        if (roomFieldMap.containsKey('Room_Category__c')) {
            selectClause += ', Room_Category__c, Room_Category__r.Name__c, Room_Category__r.Name, Room_Category__r.Amenities__c';
            if (roomCategoryFieldMap.containsKey('Custom_Amenity__c')) {
                selectClause += ', Room_Category__r.Custom_Amenity__c';
            }
        }

        String queryText = selectClause + ' FROM Ken_Room__c WHERE Id = :roomRecordId LIMIT 1';
        List<SObject> rows = Database.query(queryText); // NOPMD ApexSOQLInjection - query text is assembled from schema metadata and bind variables only.
        if (rows.isEmpty()) {
            return null;
        }

        SObject roomRecord = rows[0];
        Integer capacity = toWholeNumber(getFieldValue(roomRecord, 'Capacity__c'));
        Integer occupancy = toWholeNumber(getFieldValue(roomRecord, 'Occupancy_Status__c'));
        String explicitRoomStatus = getStringValue(roomRecord, 'Room_Status__c');
        String statusValue = resolveRoomStatusValue(occupancy, capacity, explicitRoomStatus);
        Integer effectiveOccupancy = resolveEffectiveRoomOccupancy(occupancy, capacity, statusValue);

        RoomRow row = new RoomRow();
        row.id = (Id) roomRecord.get('Id');
        row.roomNo = firstNonBlank(new List<String>{
            getStringValue(roomRecord, 'Room_Number__c'),
            getStringValue(roomRecord, 'Name')
        });
        row.buildingId = getStringValue(roomRecord, 'Building__c');
        row.building = resolveRoomBuildingLabel(roomRecord);
        row.categoryId = getStringValue(roomRecord, 'Room_Category__c');
        row.floorId = getStringValue(roomRecord, 'Floor__c');
        row.floor = firstNonBlank(new List<String>{
            getStringValue(roomRecord, 'Floor_No__c'),
            getNestedFieldValue(roomRecord, 'Floor__r', 'Name'),
            getStringValue(roomRecord, 'Floor__c'),
            '--'
        });
        row.category = firstNonBlank(new List<String>{
            getStringValue(roomRecord, 'Housing_Category__c'),
            getNestedFieldValue(roomRecord, 'Room_Category__r', 'Name__c'),
            getNestedFieldValue(roomRecord, 'Room_Category__r', 'Name'),
            '--'
        });
        row.capacity = String.valueOf(capacity);
        row.occupancy = String.valueOf(Math.max(0, effectiveOccupancy));

        String amenitiesRaw = getNestedFieldValue(roomRecord, 'Room_Category__r', 'Amenities__c');
        String customAmenitiesRaw = getNestedFieldValue(roomRecord, 'Room_Category__r', 'Custom_Amenity__c');
        String combinedAmenities = combineAmenities(amenitiesRaw, customAmenitiesRaw);
        Integer amenitiesCount = countAmenities(combinedAmenities);
        row.amenities = amenitiesCount > 0 ? String.valueOf(amenitiesCount) + ' amenities' : '--';
        row.amenitiesList = parseAmenities(combinedAmenities);

        row.statusValue = statusValue;
        row.status = getRoomStatusLabel(statusValue);
        row.roomIdentifier = getStringValue(roomRecord, 'Name');
        Id roomCategoryId = (Id) getFieldValue(roomRecord, 'Room_Category__c');
        row.feeType = resolveRoomFeeType(
            roomCategoryId,
            getRoomCategoryFeeTypeSelections(roomCategoryId == null ? new Set<Id>() : new Set<Id>{ roomCategoryId })
        );
        row.currentOccupancyText = String.valueOf(Math.max(0, effectiveOccupancy)) + ' / ' + String.valueOf(Math.max(0, capacity));
        return row;
    }

    @AuraEnabled(cacheable=true)
    public static RoomFormOptions getRoomFormOptions() {
        RoomFormOptions options = new RoomFormOptions();
        options.buildingOptions = new List<OptionItem>();
        options.floorOptions = new List<RoomFloorOption>();
        options.categoryOptions = new List<OptionItem>();
        options.statusOptions = new List<OptionItem>();
        options.categoryCapacityById = new Map<String, String>();

        for (Schema.PicklistEntry entry : Ken_Room__c.Room_Status__c.getDescribe().getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            String normalizedValue = normalizeRoomStatusValue(entry.getValue());
            if (String.isNotBlank(normalizedValue) && !containsOptionValue(options.statusOptions, normalizedValue)) {
                options.statusOptions.add(new OptionItem(entry.getLabel(), normalizedValue));
            }
        }
        if (!Schema.sObjectType.Ken_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view buildings.');
        }
        if (!Schema.sObjectType.Floor__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view floors.');
        }
        if (!Schema.sObjectType.Ken_Room_Category__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room categories.');
        }

        Map<Id, Integer> floorCountByBuildingId = new Map<Id, Integer>();
        for (Ken_Building__c buildingRow : [
            SELECT Id, Name, Name__c, Number_Of_Floors__c, Total_Floors__c
            FROM Ken_Building__c
            ORDER BY LastModifiedDate DESC
            LIMIT 500
        ]) {
            String buildingLabel = firstNonBlank(new List<String>{
                sanitize(buildingRow.Name__c),
                sanitize(buildingRow.Name)
            });
            if (String.isBlank(buildingLabel)) {
                continue;
            }

            String buildingValue = String.valueOf(buildingRow.Id);
            options.buildingOptions.add(new OptionItem(buildingLabel, buildingValue));

            Integer numberOfFloors = toWholeNumber(firstNonBlank(new List<String>{
                sanitize(buildingRow.Number_Of_Floors__c),
                sanitize(buildingRow.Total_Floors__c)
            }));
            if (numberOfFloors <= 0) {
                continue;
            }
            floorCountByBuildingId.put(buildingRow.Id, numberOfFloors);
        }

        Map<Id, Map<Integer, Id>> floorIdByBuildingAndNumber = new Map<Id, Map<Integer, Id>>();
        if (!floorCountByBuildingId.isEmpty()) {
            for (Floor__c floorRow : [
                SELECT Id, Name, Building__c
                FROM Floor__c
                WHERE Building__c IN :floorCountByBuildingId.keySet()
                LIMIT 5000
            ]) {
                if (floorRow.Building__c == null) {
                    continue;
                }
                Integer floorNumber = extractPositiveIntegerFromText(floorRow.Name);
                if (floorNumber == null || floorNumber <= 0) {
                    continue;
                }
                if (!floorIdByBuildingAndNumber.containsKey(floorRow.Building__c)) {
                    floorIdByBuildingAndNumber.put(floorRow.Building__c, new Map<Integer, Id>());
                }
                if (!floorIdByBuildingAndNumber.get(floorRow.Building__c).containsKey(floorNumber)) {
                    floorIdByBuildingAndNumber.get(floorRow.Building__c).put(floorNumber, floorRow.Id);
                }
            }
        }

        for (Id buildingId : floorCountByBuildingId.keySet()) {
            Integer numberOfFloors = floorCountByBuildingId.get(buildingId);
            for (Integer floorCounter = 1; floorCounter <= numberOfFloors; floorCounter++) {
                RoomFloorOption floorOption = new RoomFloorOption();
                floorOption.buildingValue = String.valueOf(buildingId);
                floorOption.label = 'Floor ' + String.valueOf(floorCounter);
                Id existingFloorId = floorIdByBuildingAndNumber.containsKey(buildingId)
                    ? floorIdByBuildingAndNumber.get(buildingId).get(floorCounter)
                    : null;
                floorOption.value = existingFloorId != null
                    ? String.valueOf(existingFloorId)
                    : buildSyntheticFloorValue(String.valueOf(buildingId), floorCounter);
                options.floorOptions.add(floorOption);
            }
        }

        for (Ken_Room_Category__c roomCategory : [
            SELECT Id, Name, Name__c, Capacity__c
            FROM Ken_Room_Category__c
            WHERE Active__c = true
            ORDER BY Name__c ASC, Name ASC
            LIMIT 500
        ]) {
            String categoryLabel = firstNonBlank(new List<String>{ roomCategory.Name__c, roomCategory.Name });
            if (String.isBlank(categoryLabel)) {
                continue;
            }

            String categoryId = String.valueOf(roomCategory.Id);
            options.categoryOptions.add(new OptionItem(categoryLabel, categoryId));
            if (roomCategory.Capacity__c != null) {
                options.categoryCapacityById.put(categoryId, String.valueOf(roomCategory.Capacity__c.intValue()));
            }
        }

        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<BuildingFloorWardenRow> getBuildingFloorWardenDetails(String buildingId) {
        Id buildingRecordId = toIdValueAllowNull(buildingId);
        if (buildingRecordId == null) {
            return new List<BuildingFloorWardenRow>();
        }
        if (!Schema.sObjectType.Ken_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view buildings.');
        }
        if (!Schema.sObjectType.Floor__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view floors.');
        }

        Ken_Building__c buildingRow = [
            SELECT Id, Warden__c, Warden__r.Name, Warden__r.Phone, Warden_Assignment_Mode__c
            FROM Ken_Building__c
            WHERE Id = :buildingRecordId
            LIMIT 1
        ];

        List<Floor__c> floorRows = [
            SELECT Id, Name, Warden__c, Warden__r.Name, Warden__r.Phone
            FROM Floor__c
            WHERE Building__c = :buildingRecordId
            LIMIT 5000
        ];

        Set<Id> wardenAccountIds = new Set<Id>();
        if (buildingRow.Warden__c != null) {
            wardenAccountIds.add(buildingRow.Warden__c);
        }
        for (Floor__c floorRow : floorRows) {
            if (floorRow.Warden__c != null) {
                wardenAccountIds.add(floorRow.Warden__c);
            }
        }
        Set<Id> validWardenAccountIds = getAccountsWithActiveRole(wardenAccountIds, 'Warden');
        Boolean usesPerFloorWardens = normalizeWardenModeValue(buildingRow.Warden_Assignment_Mode__c) == 'Manual';
        Boolean hasValidBuildingWarden =
            buildingRow.Warden__c != null && validWardenAccountIds.contains(buildingRow.Warden__c);

        List<BuildingFloorWardenRow> response = new List<BuildingFloorWardenRow>();
        for (Floor__c floorRow : floorRows) {
            Integer floorNumber = extractPositiveIntegerFromText(floorRow.Name);
            if (floorNumber == null || floorNumber <= 0) {
                continue;
            }

            BuildingFloorWardenRow row = new BuildingFloorWardenRow();
            row.floorNumber = floorNumber;
            row.floorName = floorRow.Name;
            Boolean hasValidFloorWarden =
                floorRow.Warden__c != null && validWardenAccountIds.contains(floorRow.Warden__c);
            Boolean hasDedicatedFloorWarden =
                usesPerFloorWardens &&
                hasValidFloorWarden &&
                (buildingRow.Warden__c == null || floorRow.Warden__c != buildingRow.Warden__c);

            if (hasDedicatedFloorWarden || (!hasValidBuildingWarden && hasValidFloorWarden)) {
                row.wardenId = String.valueOf(floorRow.Warden__c);
                row.wardenName = floorRow.Warden__r != null ? floorRow.Warden__r.Name : null;
                row.wardenPhone = floorRow.Warden__r != null ? floorRow.Warden__r.Phone : null;
                row.assignmentTypeLabel = 'Floor Warden';
                row.isInheritedFromBuilding = false;
            } else if (hasValidBuildingWarden) {
                row.wardenId = String.valueOf(buildingRow.Warden__c);
                row.wardenName = buildingRow.Warden__r != null ? buildingRow.Warden__r.Name : null;
                row.wardenPhone = buildingRow.Warden__r != null ? buildingRow.Warden__r.Phone : null;
                row.assignmentTypeLabel = 'Building Warden';
                row.isInheritedFromBuilding = true;
            } else {
                row.assignmentTypeLabel = 'Building Warden';
                row.isInheritedFromBuilding = true;
            }
            response.add(row);
        }
        return response;
    }

    @AuraEnabled
    public static Id createFloorWarden(CreateFloorWardenRequest inputRequest) {
        if (inputRequest == null) {
            throw new AuraHandledException('Floor warden payload is required.');
        }

        Id buildingRecordId = toIdValue(inputRequest.buildingId, 'Invalid Building value.');
        Integer floorNumber = toPositiveInteger(inputRequest.floorNumber, 'Floor is required.');
        String wardenIdInput = sanitize(inputRequest.wardenId);
        String wardenName = sanitize(inputRequest.wardenName);
        String phone = sanitize(inputRequest.phone);
        String description = inputRequest.description != null ? sanitize(inputRequest.description) : null;
        String assignmentType = normalizeFloorWardenAssignmentType(inputRequest.assignmentType);

        if (String.isBlank(assignmentType)) {
            throw new AuraHandledException('Assignment Type is required.');
        }
        if (!Schema.sObjectType.Ken_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view buildings.');
        }
        if (!Schema.sObjectType.Floor__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view floors.');
        }

        Ken_Building__c buildingRow = [
            SELECT Id, Warden__c, Warden_Assignment_Mode__c, Number_Of_Floors__c, Total_Floors__c
            FROM Ken_Building__c
            WHERE Id = :buildingRecordId
            LIMIT 1
        ];

        List<Floor__c> floorRows = [
            SELECT Id, Name, Warden__c
            FROM Floor__c
            WHERE Building__c = :buildingRecordId
            LIMIT 5000
        ];

        Floor__c targetFloor = null;
        for (Floor__c floorRow : floorRows) {
            if (extractPositiveIntegerFromText(floorRow.Name) == floorNumber) {
                targetFloor = floorRow;
                break;
            }
        }
        if (targetFloor == null) {
            throw new AuraHandledException('Selected floor was not found.');
        }

        String normalizedBuildingWardenMode = normalizeWardenModeValue(buildingRow.Warden_Assignment_Mode__c);
        Boolean usesPerFloorWardens = normalizedBuildingWardenMode == 'Manual';
        Boolean hasDedicatedFloorWarden = usesPerFloorWardens &&
            targetFloor.Warden__c != null &&
            (buildingRow.Warden__c == null || targetFloor.Warden__c != buildingRow.Warden__c);
        Id effectiveFloorWardenId = hasDedicatedFloorWarden ? targetFloor.Warden__c : buildingRow.Warden__c;

        Id wardenAccountId = null;
        Boolean shouldUpdateExistingWardenDescription = false;
        if (String.isNotBlank(wardenIdInput)) {
            wardenAccountId = resolveWardenId(wardenIdInput);
            if (wardenAccountId == null) {
                throw new AuraHandledException('Please select a valid warden.');
            }
            if (!getAccountsWithActiveRole(new Set<Id>{ wardenAccountId }, 'Warden').contains(wardenAccountId)) {
                throw new AuraHandledException('Please select a valid active Warden account.');
            }
            shouldUpdateExistingWardenDescription = inputRequest.description != null;
        } else {
            if (String.isBlank(wardenName)) {
                throw new AuraHandledException('Warden Name is required.');
            }
            if (String.isBlank(phone)) {
                throw new AuraHandledException('Phone is required.');
            }

            Id personAccountRecordTypeId = getWardenPersonAccountRecordTypeId();
            if (personAccountRecordTypeId == null) {
                throw new AuraHandledException('A person account record type is not configured in this org.');
            }

            NameParts nameParts = splitPersonName(wardenName);
            Account wardenAccount = new Account();
            wardenAccount.RecordTypeId = personAccountRecordTypeId;
            wardenAccount.FirstName = nameParts.firstName;
            wardenAccount.LastName = nameParts.lastName;
            wardenAccount.Phone = phone;
            wardenAccount.PersonMobilePhone = phone;
            wardenAccount.Description = description;
            if (!Schema.sObjectType.Account.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create warden accounts.');
            }
            insert wardenAccount;

            if (!Schema.sObjectType.Account.isAccessible()) {
                throw new AuraHandledException('You do not have permission to view warden accounts.');
            }
            wardenAccount = [
                SELECT Id, PersonContactId
                FROM Account
                WHERE Id = :wardenAccount.Id
                LIMIT 1
            ];
            if (wardenAccount.PersonContactId == null) {
                throw new AuraHandledException('Unable to create the warden person account.');
            }

            ConstituentRole roleRow = new ConstituentRole();
            roleRow.PersonId = wardenAccount.PersonContactId;
            roleRow.RoleType = 'Warden';
            roleRow.Status = 'Active';
            if (!Schema.sObjectType.ConstituentRole.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create warden roles.');
            }
            insert roleRow;

            wardenAccountId = wardenAccount.Id;
        }

        if (assignmentType == 'Floor Warden' && effectiveFloorWardenId == wardenAccountId) {
            throw new AuraHandledException('This warden is already assigned to the selected floor.');
        }

        if (
            assignmentType == 'Building Warden' &&
            normalizedBuildingWardenMode == 'Building Level' &&
            buildingRow.Warden__c == wardenAccountId
        ) {
            throw new AuraHandledException('This warden is already assigned to the selected floor.');
        }

        if (shouldUpdateExistingWardenDescription) {
            if (!Schema.sObjectType.Account.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update warden accounts.');
            }
            update new Account(
                Id = wardenAccountId,
                Description = description
            );
        }

        if (assignmentType == 'Building Warden') {
            if (!Schema.sObjectType.Ken_Building__c.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update buildings.');
            }
            update new Ken_Building__c(
                Id = buildingRow.Id,
                Warden__c = wardenAccountId,
                Warden_Assignment_Mode__c = 'Building Level'
            );
            syncFloorMasterRecords(buildingRow.Id, resolveBuildingFloorCount(buildingRow));
            return wardenAccountId;
        }

        if (!Schema.sObjectType.Ken_Building__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update buildings.');
        }
        update new Ken_Building__c(
            Id = buildingRow.Id,
            Warden_Assignment_Mode__c = 'Manual'
        );

        List<Floor__c> floorUpdates = new List<Floor__c>();
        for (Floor__c floorRow : floorRows) {
            if (floorRow.Id == targetFloor.Id) {
                if (floorRow.Warden__c != wardenAccountId) {
                    floorUpdates.add(new Floor__c(
                        Id = floorRow.Id,
                        Warden__c = wardenAccountId
                    ));
                }
                continue;
            }

            if (buildingRow.Warden__c != null && floorRow.Warden__c == buildingRow.Warden__c) {
                floorUpdates.add(new Floor__c(
                    Id = floorRow.Id,
                    Warden__c = null
                ));
            }
        }
        if (!floorUpdates.isEmpty()) {
            if (!Schema.sObjectType.Floor__c.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update floors.');
            }
            update floorUpdates;
        }

        return wardenAccountId;
    }

    @AuraEnabled(cacheable=true)
    public static BuildingActivityHistoryRow getBuildingActivityHistory(String buildingId) {
        Id buildingRecordId = toIdValueAllowNull(buildingId);
        if (buildingRecordId == null) {
            return null;
        }
        if (!Schema.sObjectType.Ken_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view buildings.');
        }

        List<Ken_Building__c> rows = [
            SELECT Id, Owner.Name, CreatedBy.Name, CreatedDate, LastModifiedBy.Name, LastModifiedDate
            FROM Ken_Building__c
            WHERE Id = :buildingRecordId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return null;
        }

        Ken_Building__c building = rows[0];
        BuildingActivityHistoryRow response = new BuildingActivityHistoryRow();
        response.ownerName = building.Owner != null ? building.Owner.Name : null;
        response.createdByName = building.CreatedBy != null ? building.CreatedBy.Name : null;
        response.createdDate = building.CreatedDate;
        response.lastModifiedByName = building.LastModifiedBy != null ? building.LastModifiedBy.Name : null;
        response.lastModifiedDate = building.LastModifiedDate;
        response.events = new List<ActivityHistoryEventRow>();

        ActivityHistoryEventRow ownerEvent = new ActivityHistoryEventRow();
        ownerEvent.title = 'Field Changed • Owner set to ' + firstNonBlank(new List<String>{ response.ownerName, '--' });
        ownerEvent.subtitle = 'by ' + firstNonBlank(new List<String>{ response.lastModifiedByName, '--' });
        ownerEvent.eventAt = response.lastModifiedDate;
        response.events.add(ownerEvent);

        ActivityHistoryEventRow modifiedEvent = new ActivityHistoryEventRow();
        modifiedEvent.title = 'Record Updated';
        modifiedEvent.subtitle = 'by ' + firstNonBlank(new List<String>{ response.lastModifiedByName, '--' });
        modifiedEvent.eventAt = response.lastModifiedDate;
        response.events.add(modifiedEvent);

        ActivityHistoryEventRow createdEvent = new ActivityHistoryEventRow();
        createdEvent.title = 'Record Created';
        createdEvent.subtitle = 'by ' + firstNonBlank(new List<String>{ response.createdByName, '--' });
        createdEvent.eventAt = response.createdDate;
        response.events.add(createdEvent);

        return response;
    }

    @AuraEnabled(cacheable=true)
    public static RoomCategoryActivityHistoryRow getRoomCategoryActivityHistory(String categoryId) {
        Id roomCategoryId = toIdValueAllowNull(categoryId);
        if (roomCategoryId == null) {
            return null;
        }
        if (!Schema.sObjectType.Ken_Room_Category__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room categories.');
        }

        List<Ken_Room_Category__c> rows = [
            SELECT Id, CreatedBy.Name, CreatedDate, LastModifiedBy.Name, LastModifiedDate
            FROM Ken_Room_Category__c
            WHERE Id = :roomCategoryId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return null;
        }

        Ken_Room_Category__c category = rows[0];
        RoomCategoryActivityHistoryRow response = new RoomCategoryActivityHistoryRow();
        response.createdByName = category.CreatedBy != null ? category.CreatedBy.Name : null;
        response.createdDate = category.CreatedDate;
        response.lastModifiedByName = category.LastModifiedBy != null ? category.LastModifiedBy.Name : null;
        response.lastModifiedDate = category.LastModifiedDate;
        response.events = new List<ActivityHistoryEventRow>();

        ActivityHistoryEventRow modifiedEvent = new ActivityHistoryEventRow();
        modifiedEvent.title = 'Record Updated';
        modifiedEvent.subtitle = 'by ' + firstNonBlank(new List<String>{ response.lastModifiedByName, '--' });
        modifiedEvent.eventAt = response.lastModifiedDate;
        response.events.add(modifiedEvent);

        ActivityHistoryEventRow createdEvent = new ActivityHistoryEventRow();
        createdEvent.title = 'Record Created';
        createdEvent.subtitle = 'by ' + firstNonBlank(new List<String>{ response.createdByName, '--' });
        createdEvent.eventAt = response.createdDate;
        response.events.add(createdEvent);

        return response;
    }

    @AuraEnabled(cacheable=true)
    public static RoomOccupancyDetailsRow getRoomOccupancyDetails(String roomId) {
        Id roomRecordId = toIdValueAllowNull(roomId);
        if (roomRecordId == null) {
            return null;
        }
        if (!Schema.sObjectType.Ken_Room__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view rooms.');
        }
        if (!Schema.sObjectType.Ken_Room_Allotment__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room allotments.');
        }

        List<Ken_Room__c> roomRows = [
            SELECT Id, Room_Status__c, Occupancy_Status__c, Capacity__c,
                   Room_Category__c, Room_Category__r.Name, Room_Category__r.Name__c,
                   CreatedBy.Name, CreatedDate, LastModifiedBy.Name, LastModifiedDate
            FROM Ken_Room__c
            WHERE Id = :roomRecordId
            LIMIT 1
        ];
        if (roomRows.isEmpty()) {
            return null;
        }

        Ken_Room__c room = roomRows[0];
        RoomOccupancyDetailsRow response = new RoomOccupancyDetailsRow();
        response.currentOccupants = new List<RoomOccupantRow>();
        response.pastOccupants = new List<RoomOccupantRow>();
        response.createdByName = room.CreatedBy != null ? room.CreatedBy.Name : null;
        response.createdDate = room.CreatedDate;
        response.lastModifiedByName = room.LastModifiedBy != null ? room.LastModifiedBy.Name : null;
        response.lastModifiedDate = room.LastModifiedDate;
        response.events = new List<ActivityHistoryEventRow>();

        Set<Id> tenantAccountIds = new Set<Id>();
        List<Ken_Room_Allotment__c> allotmentRows = [
            SELECT Id, Active__c, Start_Date__c, End_Date__c, Allotment_Type__c,
                Tenant_Account__c, Tenant_Account__r.Name, Tenant_Account__r.Student_ID__c,
                Tenant__c, Tenant__r.Name, Tenant__r.Email
            FROM Ken_Room_Allotment__c
            WHERE Room__c = :roomRecordId
            ORDER BY Start_Date__c DESC, CreatedDate DESC
            LIMIT 1000
        ];
        for (Ken_Room_Allotment__c allotmentRow : allotmentRows) {
            if (allotmentRow.Tenant_Account__c != null) {
                tenantAccountIds.add(allotmentRow.Tenant_Account__c);
            }
        }
        Set<Id> validStudentAccountIds = getAccountsWithActiveRole(tenantAccountIds, 'Student');

        for (Ken_Room_Allotment__c row : allotmentRows) {
            if (row.Tenant_Account__c == null && row.Tenant__c == null) {
                continue;
            }
            if (row.Tenant_Account__c != null && !validStudentAccountIds.contains(row.Tenant_Account__c)) {
                continue;
            }
            RoomOccupantRow occupant = new RoomOccupantRow();
            occupant.id = row.Id;
            occupant.studentName = row.Tenant_Account__r != null
                ? row.Tenant_Account__r.Name
                : row.Tenant__r != null
                    ? row.Tenant__r.Name
                    : null;
            occupant.rollNo = row.Tenant_Account__r != null
                ? String.valueOf(row.Tenant_Account__r.get('Student_ID__c'))
                : row.Tenant__r != null
                    ? row.Tenant__r.Email
                    : null;
            occupant.checkInDate = row.Start_Date__c;
            occupant.checkOutDate = row.End_Date__c;
            occupant.allocationType = row.Allotment_Type__c;
            occupant.enrollmentCycle = null;
            occupant.active = row.Active__c == true;
            occupant.status = occupant.active ? 'Active' : 'Completed';

            if (occupant.active) {
                response.currentOccupants.add(occupant);
            } else {
                response.pastOccupants.add(occupant);
            }
        }

        ActivityHistoryEventRow modifiedEvent = new ActivityHistoryEventRow();
        modifiedEvent.title = 'Record Updated';
        modifiedEvent.subtitle = 'by ' + firstNonBlank(new List<String>{ response.lastModifiedByName, '--' });
        modifiedEvent.eventAt = response.lastModifiedDate;
        response.events.add(modifiedEvent);

        ActivityHistoryEventRow createdEvent = new ActivityHistoryEventRow();
        createdEvent.title = 'Record Created';
        createdEvent.subtitle = 'by ' + firstNonBlank(new List<String>{ response.createdByName, '--' });
        createdEvent.eventAt = response.createdDate;
        response.events.add(createdEvent);

        return response;
    }

    private static Set<Id> getAccountsWithActiveRole(Set<Id> accountIds, String requiredRoleType) {
        Set<Id> validAccountIds = new Set<Id>();
        if (accountIds == null || accountIds.isEmpty() || String.isBlank(requiredRoleType)) {
            return validAccountIds;
        }
        if (!Schema.sObjectType.Account.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view accounts.');
        }
        if (!Schema.sObjectType.ConstituentRole.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view constituent roles.');
        }

        Map<Id, Id> personContactByAccountId = new Map<Id, Id>();
        Set<Id> personContactIds = new Set<Id>();
        for (Account accountRow : [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id IN :accountIds
        ]) {
            if (accountRow.PersonContactId == null) {
                continue;
            }
            personContactByAccountId.put(accountRow.Id, accountRow.PersonContactId);
            personContactIds.add(accountRow.PersonContactId);
        }
        if (personContactIds.isEmpty()) {
            return validAccountIds;
        }

        Set<Id> eligiblePersonContactIds = new Set<Id>();
        for (ConstituentRole roleRow : [
            SELECT PersonId
            FROM ConstituentRole
            WHERE PersonId IN :personContactIds
              AND Status = 'Active'
              AND RoleType = :requiredRoleType
        ]) {
            if (roleRow.PersonId != null) {
                eligiblePersonContactIds.add(roleRow.PersonId);
            }
        }

        for (Id accountId : personContactByAccountId.keySet()) {
            if (eligiblePersonContactIds.contains(personContactByAccountId.get(accountId))) {
                validAccountIds.add(accountId);
            }
        }
        return validAccountIds;
    }

    private static List<Account> getActiveRoleAccounts(String requiredRoleType) {
        List<Account> accounts = new List<Account>();
        if (String.isBlank(requiredRoleType)) {
            return accounts;
        }
        if (!Schema.sObjectType.ConstituentRole.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view constituent roles.');
        }
        if (!Schema.sObjectType.Account.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view accounts.');
        }

        Set<Id> eligiblePersonContactIds = new Set<Id>();
        for (ConstituentRole roleRow : [
            SELECT PersonId
            FROM ConstituentRole
            WHERE Status = 'Active'
              AND RoleType = :requiredRoleType
              AND PersonId != null
            LIMIT 5000
        ]) {
            eligiblePersonContactIds.add(roleRow.PersonId);
        }
        if (eligiblePersonContactIds.isEmpty()) {
            return accounts;
        }

        accounts = [
            SELECT Id, Name, Phone, Description
            FROM Account
            WHERE PersonContactId IN :eligiblePersonContactIds
            ORDER BY Name ASC
            LIMIT 5000
        ];
        return accounts;
    }

    @AuraEnabled
    public static Id createRoom(CreateRoomRequest inputRequest) {
        if (inputRequest == null) {
            throw new AuraHandledException('Room payload is required.');
        }

        String roomNumber = sanitize(inputRequest.roomNumber);
        String floorIdValue = sanitize(inputRequest.floorId);
        String buildingValue = sanitize(inputRequest.buildingValue);
        String roomCategoryIdValue = sanitize(inputRequest.roomCategoryId);
        String capacityValue = sanitize(inputRequest.capacity);
        String normalizedStatus = normalizeRoomStatusValue(inputRequest.statusValue);

        if (String.isBlank(buildingValue)) {
            throw new AuraHandledException('Building is required.');
        }
        if (String.isBlank(floorIdValue)) {
            throw new AuraHandledException('Floor is required.');
        }
        if (String.isBlank(roomNumber)) {
            throw new AuraHandledException('Room Number is required.');
        }
        if (String.isBlank(roomCategoryIdValue)) {
            throw new AuraHandledException('Category is required.');
        }
        if (String.isBlank(capacityValue) || !isPositiveWholeNumber(capacityValue)) {
            throw new AuraHandledException('Capacity must be a positive whole number.');
        }
        if (String.isBlank(normalizedStatus)) {
            throw new AuraHandledException('Status is required.');
        }

        Id buildingId = toIdValue(buildingValue, 'Invalid Building value.');
        Id roomCategoryId = toIdValue(roomCategoryIdValue, 'Invalid Category value.');
        ensureUniqueRoomNumber(roomNumber, null);
        Id selectedFloorId = null;
        Integer floorNumber;
        if (isSyntheticFloorValue(floorIdValue)) {
            Id floorBuildingId = extractBuildingIdFromSyntheticFloorValue(floorIdValue);
            floorNumber = extractFloorNumberFromSyntheticFloorValue(floorIdValue);
            if (floorBuildingId == null || floorNumber == null) {
                throw new AuraHandledException('Selected floor is invalid.');
            }
            if (floorBuildingId != buildingId) {
                throw new AuraHandledException('Please select a floor from the selected building.');
            }
        } else {
            selectedFloorId = toIdValueAllowNull(floorIdValue);
            if (selectedFloorId == null) {
                floorNumber = toWholeNumber(floorIdValue);
                if (floorNumber <= 0) {
                    throw new AuraHandledException('Selected floor is invalid.');
                }
            }
        }

        Map<String, Schema.SObjectField> roomFieldMap = Ken_Room__c.SObjectType.getDescribe().fields.getMap();
        ensureRoomFieldCreateable(roomFieldMap, 'Room_Number__c', 'Room Number');
        ensureRoomFieldCreateable(roomFieldMap, 'Room_Category__c', 'Category');

        Ken_Room__c roomRecord = new Ken_Room__c();
        roomRecord.Room_Number__c = roomNumber;
        roomRecord.Room_Category__c = roomCategoryId;
        if (roomFieldMap.containsKey('Building__c')) {
            Schema.DescribeFieldResult buildingDescribe = roomFieldMap.get('Building__c').getDescribe();
            if (!buildingDescribe.isCalculated()) {
                roomRecord.put('Building__c', buildingId);
            }
        }

        if (roomFieldMap.containsKey('Capacity__c')) {
            Schema.DescribeFieldResult capacityDescribe = roomFieldMap.get('Capacity__c').getDescribe();
            if (capacityDescribe.isCreateable() && !capacityDescribe.isCalculated()) {
                roomRecord.put('Capacity__c', Decimal.valueOf(capacityValue));
            }
        }
        if (roomFieldMap.containsKey('Floor__c')) {
            Schema.DescribeFieldResult floorDescribe = roomFieldMap.get('Floor__c').getDescribe();
            if (floorNumber != null && floorNumber > 0 && buildingId != null && floorDescribe.getType() == Schema.DisplayType.Reference) {
                syncFloorMasterRecords(buildingId, floorNumber);
            }
            Object floorValueToStore = resolveRoomFloorFieldValue(floorDescribe, floorIdValue, floorNumber, buildingId);
            if (floorValueToStore == null && !floorDescribe.isNillable()) {
                throw new AuraHandledException('Selected floor is invalid for the selected building.');
            }
            if (floorValueToStore != null && floorDescribe.isCreateable() && !floorDescribe.isCalculated()) {
                roomRecord.put('Floor__c', floorValueToStore);
            }
        }
        if (roomFieldMap.containsKey('Room_Status__c')) {
            Schema.DescribeFieldResult statusDescribe = roomFieldMap.get('Room_Status__c').getDescribe();
            if (statusDescribe.isCreateable() && !statusDescribe.isCalculated()) {
                String statusToStore = resolveRoomStatusFieldValue(normalizedStatus, statusDescribe);
                if (String.isNotBlank(statusToStore)) {
                    roomRecord.put('Room_Status__c', statusToStore);
                }
            }
        }
        if (!Schema.sObjectType.Ken_Room__c.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create rooms.');
        }

        insert roomRecord;
        syncBuildingTotalRooms(new Set<Id>{ buildingId });
        return roomRecord.Id;
    }

    @AuraEnabled
    public static Id updateRoom(String roomId, CreateRoomRequest inputRequest) {
        if (String.isBlank(roomId)) {
            throw new AuraHandledException('Room is required.');
        }
        if (inputRequest == null) {
            throw new AuraHandledException('Room payload is required.');
        }

        Id roomRecordId = toIdValue(roomId, 'Invalid Room value.');
        String roomNumber = sanitize(inputRequest.roomNumber);
        String floorIdValue = sanitize(inputRequest.floorId);
        String buildingValue = sanitize(inputRequest.buildingValue);
        String roomCategoryIdValue = sanitize(inputRequest.roomCategoryId);
        String capacityValue = sanitize(inputRequest.capacity);
        String normalizedStatus = normalizeRoomStatusValue(inputRequest.statusValue);

        Map<String, Schema.SObjectField> roomFieldMap = Ken_Room__c.SObjectType.getDescribe().fields.getMap();
        if (!Schema.sObjectType.Ken_Room__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view rooms.');
        }

        List<Ken_Room__c> existingRooms = [
            SELECT Id, Room_Number__c, Room_Category__c, Building__c, Capacity__c, Room_Status__c
            FROM Ken_Room__c
            WHERE Id = :roomRecordId
            LIMIT 1
        ];
        if (existingRooms.isEmpty()) {
            throw new AuraHandledException('Room record was not found.');
        }

        Ken_Room__c roomRecord = existingRooms[0];
        Id existingBuildingId = roomRecord.Building__c;
        String existingRoomNumber = sanitize(roomRecord.Room_Number__c);

        String resolvedRoomNumber = firstNonBlank(new List<String>{
            roomNumber,
            existingRoomNumber
        });
        if (String.isBlank(resolvedRoomNumber)) {
            throw new AuraHandledException('Room Number is required.');
        }

        Id buildingId = existingBuildingId;
        if (String.isNotBlank(buildingValue)) {
            buildingId = toIdValue(buildingValue, 'Invalid Building value.');
        }

        Id roomCategoryId = roomRecord.Room_Category__c;
        if (String.isNotBlank(roomCategoryIdValue)) {
            roomCategoryId = toIdValue(roomCategoryIdValue, 'Invalid Category value.');
        }
        if (roomCategoryId == null) {
            throw new AuraHandledException('Category is required.');
        }

        Integer floorNumber = 0;
        Id floorBuildingId = null;
        Id selectedFloorId = null;
        if (String.isNotBlank(floorIdValue)) {
            if (isSyntheticFloorValue(floorIdValue)) {
                floorBuildingId = extractBuildingIdFromSyntheticFloorValue(floorIdValue);
                floorNumber = extractFloorNumberFromSyntheticFloorValue(floorIdValue);
                if (floorBuildingId == null || floorNumber == null) {
                    throw new AuraHandledException('Selected floor is invalid.');
                }
                if (buildingId != null && floorBuildingId != buildingId) {
                    throw new AuraHandledException('Please select a floor from the selected building.');
                }
                if (buildingId == null) {
                    buildingId = floorBuildingId;
                }
            } else {
                selectedFloorId = toIdValueAllowNull(floorIdValue);
                if (selectedFloorId == null) {
                    floorNumber = toWholeNumber(floorIdValue);
                    if (floorNumber <= 0) {
                        throw new AuraHandledException('Selected floor is invalid.');
                    }
                }
            }
        }
        if (String.isNotBlank(floorIdValue) && floorNumber <= 0 && selectedFloorId == null) {
            throw new AuraHandledException('Floor is required.');
        }

        Boolean shouldCheckRoomNumberUniqueness =
            existingRoomNumber != resolvedRoomNumber;
        if (shouldCheckRoomNumberUniqueness) {
            ensureUniqueRoomNumber(resolvedRoomNumber, roomRecordId);
        }

        Boolean shouldUpdateRoomNumber =
            String.isNotBlank(roomNumber) &&
            existingRoomNumber != resolvedRoomNumber;
        Boolean shouldUpdateCategory =
            String.isNotBlank(roomCategoryIdValue) &&
            roomRecord.Room_Category__c != roomCategoryId;
        Boolean shouldUpdateFloor =
            String.isNotBlank(floorIdValue);
        if (shouldUpdateRoomNumber) {
            ensureRoomFieldUpdateable(roomFieldMap, 'Room_Number__c', 'Room Number');
        }
        if (shouldUpdateCategory) {
            ensureRoomFieldUpdateable(roomFieldMap, 'Room_Category__c', 'Category');
        }

        Decimal capacityNumber = roomRecord.Capacity__c;
        if (String.isNotBlank(capacityValue)) {
            if (!Pattern.matches('^\\d+$', capacityValue)) {
                throw new AuraHandledException('Capacity must be a whole number (0 or more).');
            }
            capacityNumber = Decimal.valueOf(capacityValue);
        }
        if (capacityNumber == null) {
            capacityNumber = 0;
        }

        String normalizedStatusValue = normalizedStatus;
        if (String.isBlank(normalizedStatusValue)) {
            normalizedStatusValue = normalizeRoomStatusValue(roomRecord.Room_Status__c);
        }

        if (shouldUpdateRoomNumber) {
            roomRecord.Room_Number__c = resolvedRoomNumber;
        }
        if (shouldUpdateCategory) {
            roomRecord.Room_Category__c = roomCategoryId;
        }
        if (roomFieldMap.containsKey('Building__c')) {
            Schema.DescribeFieldResult buildingDescribe = roomFieldMap.get('Building__c').getDescribe();
            if (!buildingDescribe.isCalculated()) {
                roomRecord.put('Building__c', buildingId);
            }
        }

        if (roomFieldMap.containsKey('Capacity__c')) {
            Schema.DescribeFieldResult capacityDescribe = roomFieldMap.get('Capacity__c').getDescribe();
            if (capacityDescribe.isUpdateable() && !capacityDescribe.isCalculated()) {
                roomRecord.put('Capacity__c', capacityNumber);
            }
        }
        if (roomFieldMap.containsKey('Floor__c') && shouldUpdateFloor) {
            Schema.DescribeFieldResult floorDescribe = roomFieldMap.get('Floor__c').getDescribe();
            if (floorNumber != null && floorNumber > 0 && buildingId != null && floorDescribe.getType() == Schema.DisplayType.Reference) {
                syncFloorMasterRecords(buildingId, floorNumber);
            }
            Object floorValueToStore = resolveRoomFloorFieldValue(floorDescribe, floorIdValue, floorNumber, buildingId);
            if (floorValueToStore == null && !floorDescribe.isNillable()) {
                throw new AuraHandledException('Selected floor is invalid for the selected building.');
            }
            if (floorValueToStore != null && floorDescribe.isUpdateable() && !floorDescribe.isCalculated()) {
                roomRecord.put('Floor__c', floorValueToStore);
            }
        }
        if (roomFieldMap.containsKey('Room_Status__c')) {
            Schema.DescribeFieldResult statusDescribe = roomFieldMap.get('Room_Status__c').getDescribe();
            if (statusDescribe.isUpdateable() && !statusDescribe.isCalculated()) {
                String statusToStore = resolveRoomStatusFieldValue(normalizedStatusValue, statusDescribe);
                if (String.isNotBlank(statusToStore)) {
                    roomRecord.put('Room_Status__c', statusToStore);
                }
            }
        }
        if (!Schema.sObjectType.Ken_Room__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update rooms.');
        }

        update roomRecord;
        syncBuildingTotalRooms(new Set<Id>{ existingBuildingId, buildingId });
        return roomRecord.Id;
    }

    @AuraEnabled
    public static void deleteRoom(String roomId) {
        if (String.isBlank(roomId)) {
            throw new AuraHandledException('Room is required.');
        }
        Id roomRecordId = toIdValue(roomId, 'Invalid Room value.');
        if (!Schema.sObjectType.Ken_Room__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view rooms.');
        }
        List<Ken_Room__c> rooms = [
            SELECT Id, Building__c
            FROM Ken_Room__c
            WHERE Id = :roomRecordId
            LIMIT 1
        ];
        if (rooms.isEmpty()) {
            throw new AuraHandledException('Room record was not found.');
        }
        if (!Schema.sObjectType.Ken_Room__c.isDeletable()) {
            throw new AuraHandledException('You do not have permission to delete rooms.');
        }
        try {
            delete rooms[0];
            syncBuildingTotalRooms(new Set<Id>{ rooms[0].Building__c });
        } catch (DmlException e) {
            throw new AuraHandledException(firstNonBlank(new List<String>{
                e.getDmlMessage(0),
                'Unable to delete room.'
            }));
        }
    }

    @AuraEnabled
    public static BulkRoomCsvResponse bulkCreateRoomsFromCsv(List<BulkRoomCsvRow> inputRows) {
        if (inputRows == null || inputRows.isEmpty()) {
            throw new AuraHandledException('CSV rows are required.');
        }
        if (inputRows.size() > 2000) {
            throw new AuraHandledException('CSV upload supports up to 2000 rows at a time.');
        }

        BulkRoomCsvResponse response = new BulkRoomCsvResponse();
        response.processedCount = inputRows.size();

        Map<String, Schema.SObjectField> roomFieldMap = Ken_Room__c.SObjectType.getDescribe().fields.getMap();
        ensureRoomFieldCreateable(roomFieldMap, 'Room_Number__c', 'Room Number');
        ensureRoomFieldCreateable(roomFieldMap, 'Room_Category__c', 'Category');
        if (roomFieldMap.containsKey('Floor__c')) {
            ensureRoomFieldCreateable(roomFieldMap, 'Floor__c', 'Floor');
        }
        if (!Schema.sObjectType.Ken_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view buildings.');
        }
        if (!Schema.sObjectType.Ken_Room_Category__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room categories.');
        }
        if (!Schema.sObjectType.Floor__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view floors.');
        }

        Set<String> buildingNames = new Set<String>();
        Set<String> categoryNames = new Set<String>();
        for (BulkRoomCsvRow row : inputRows) {
            if (row == null) {
                continue;
            }
            String buildingName = sanitize(row.building);
            if (String.isNotBlank(buildingName)) {
                buildingNames.add(buildingName);
            }
            String categoryName = sanitize(row.category);
            if (String.isNotBlank(categoryName)) {
                categoryNames.add(categoryName);
            }
        }

        Map<String, Id> buildingIdByToken = new Map<String, Id>();
        if (!buildingNames.isEmpty()) {
            for (Ken_Building__c buildingRow : [
                SELECT Id, Name, Name__c
                FROM Ken_Building__c
                WHERE Name__c IN :buildingNames
                    OR Name IN :buildingNames
                LIMIT 5000
            ]) {
                String nameToken = normalizeFloorText(buildingRow.Name);
                if (nameToken != null && !buildingIdByToken.containsKey(nameToken)) {
                    buildingIdByToken.put(nameToken, buildingRow.Id);
                }
                String customNameToken = normalizeFloorText(buildingRow.Name__c);
                if (customNameToken != null && !buildingIdByToken.containsKey(customNameToken)) {
                    buildingIdByToken.put(customNameToken, buildingRow.Id);
                }
            }
        }

        Map<String, Id> categoryIdByToken = new Map<String, Id>();
        if (!categoryNames.isEmpty()) {
            for (Ken_Room_Category__c categoryRow : [
                SELECT Id, Name, Name__c
                FROM Ken_Room_Category__c
                WHERE Name__c IN :categoryNames
                    OR Name IN :categoryNames
                LIMIT 5000
            ]) {
                String nameToken = normalizeFloorText(categoryRow.Name);
                if (nameToken != null && !categoryIdByToken.containsKey(nameToken)) {
                    categoryIdByToken.put(nameToken, categoryRow.Id);
                }
                String customNameToken = normalizeFloorText(categoryRow.Name__c);
                if (customNameToken != null && !categoryIdByToken.containsKey(customNameToken)) {
                    categoryIdByToken.put(customNameToken, categoryRow.Id);
                }
            }
        }

        Schema.DescribeFieldResult buildingDescribe =
            roomFieldMap.containsKey('Building__c') ? roomFieldMap.get('Building__c').getDescribe() : null;
        Schema.DescribeFieldResult floorDescribe =
            roomFieldMap.containsKey('Floor__c') ? roomFieldMap.get('Floor__c').getDescribe() : null;
        Schema.DescribeFieldResult capacityDescribe =
            roomFieldMap.containsKey('Capacity__c') ? roomFieldMap.get('Capacity__c').getDescribe() : null;
        Schema.DescribeFieldResult statusDescribe =
            roomFieldMap.containsKey('Room_Status__c') ? roomFieldMap.get('Room_Status__c').getDescribe() : null;

        List<Ken_Room__c> candidateRooms = new List<Ken_Room__c>();
        List<Integer> candidateRowNumbers = new List<Integer>();
        List<Id> candidateBuildingIds = new List<Id>();
        List<Integer> candidateFloorNumbers = new List<Integer>();

        Map<Id, Integer> maxFloorByBuildingId = new Map<Id, Integer>();

        Integer fallbackRowNumber = 1;
        for (BulkRoomCsvRow inputRow : inputRows) {
            fallbackRowNumber++;
            if (inputRow == null) {
                appendBulkRoomError(response, fallbackRowNumber, 'Row is empty.');
                continue;
            }

            Integer csvRowNumber = inputRow.rowNumber != null ? inputRow.rowNumber : fallbackRowNumber;
            String buildingName = sanitize(inputRow.building);
            String floorText = sanitize(inputRow.floor);
            String roomNumber = sanitize(inputRow.roomNumber);
            String categoryName = sanitize(inputRow.category);
            String capacityValue = sanitize(inputRow.capacity);
            String statusValue = sanitize(inputRow.status);

            if (String.isBlank(buildingName)) {
                appendBulkRoomError(response, csvRowNumber, 'Building is required.');
                continue;
            }
            if (String.isBlank(floorText)) {
                appendBulkRoomError(response, csvRowNumber, 'Floor is required.');
                continue;
            }
            if (String.isBlank(roomNumber)) {
                appendBulkRoomError(response, csvRowNumber, 'Room Number is required.');
                continue;
            }
            if (String.isBlank(categoryName)) {
                appendBulkRoomError(response, csvRowNumber, 'Category is required.');
                continue;
            }
            if (String.isBlank(capacityValue) || !isPositiveWholeNumber(capacityValue)) {
                appendBulkRoomError(response, csvRowNumber, 'Capacity must be a positive whole number.');
                continue;
            }
            String normalizedStatus = normalizeRoomStatusValue(statusValue);
            if (String.isBlank(normalizedStatus)) {
                appendBulkRoomError(response, csvRowNumber, 'Status is required.');
                continue;
            }

            Id buildingId = buildingIdByToken.get(normalizeFloorText(buildingName));
            if (buildingId == null) {
                appendBulkRoomError(response, csvRowNumber, 'Building was not found: ' + buildingName + '.');
                continue;
            }

            Id categoryId = categoryIdByToken.get(normalizeFloorText(categoryName));
            if (categoryId == null) {
                appendBulkRoomError(response, csvRowNumber, 'Category was not found: ' + categoryName + '.');
                continue;
            }

            Integer floorNumber = extractPositiveIntegerFromText(floorText);
            if (floorNumber == null || floorNumber <= 0) {
                appendBulkRoomError(response, csvRowNumber, 'Floor is invalid: ' + floorText + '.');
                continue;
            }

            if (!maxFloorByBuildingId.containsKey(buildingId) || maxFloorByBuildingId.get(buildingId) < floorNumber) {
                maxFloorByBuildingId.put(buildingId, floorNumber);
            }

            Ken_Room__c roomRecord = new Ken_Room__c();
            roomRecord.Room_Number__c = roomNumber;
            roomRecord.Room_Category__c = categoryId;

            if (capacityDescribe != null && capacityDescribe.isCreateable() && !capacityDescribe.isCalculated()) {
                roomRecord.put('Capacity__c', Decimal.valueOf(capacityValue));
            }
            if (statusDescribe != null && statusDescribe.isCreateable() && !statusDescribe.isCalculated()) {
                String statusToStore = resolveRoomStatusFieldValue(normalizedStatus, statusDescribe);
                if (String.isBlank(statusToStore)) {
                    appendBulkRoomError(response, csvRowNumber, 'Status is invalid: ' + statusValue + '.');
                    continue;
                }
                roomRecord.put('Room_Status__c', statusToStore);
            }
            if (buildingDescribe != null && buildingDescribe.isCreateable() && !buildingDescribe.isCalculated()) {
                roomRecord.put('Building__c', buildingId);
            }

            candidateRooms.add(roomRecord);
            candidateRowNumbers.add(csvRowNumber);
            candidateBuildingIds.add(buildingId);
            candidateFloorNumbers.add(floorNumber);
        }

        if (candidateRooms.isEmpty()) {
            response.failureCount = response.errors.size();
            return response;
        }

        Set<Integer> duplicateCandidateIndexes = collectDuplicateRoomCandidateIndexes(
            response,
            candidateRooms,
            candidateRowNumbers
        );

        for (Id buildingId : maxFloorByBuildingId.keySet()) {
            syncFloorMasterRecords(buildingId, maxFloorByBuildingId.get(buildingId));
        }

        Set<Id> buildingIdsToQuery = new Set<Id>();
        buildingIdsToQuery.addAll(maxFloorByBuildingId.keySet());

        Map<String, Id> floorIdByBuildingAndNumber = new Map<String, Id>();
        if (!buildingIdsToQuery.isEmpty()) {
            for (Floor__c floorRow : [
                SELECT Id, Name, Building__c
                FROM Floor__c
                WHERE Building__c IN :buildingIdsToQuery
                LIMIT 5000
            ]) {
                if (floorRow.Building__c == null) {
                    continue;
                }
                Integer parsedNumber = extractPositiveIntegerFromText(floorRow.Name);
                if (parsedNumber == null || parsedNumber <= 0) {
                    continue;
                }
                String key = String.valueOf(floorRow.Building__c) + '|' + String.valueOf(parsedNumber);
                if (!floorIdByBuildingAndNumber.containsKey(key)) {
                    floorIdByBuildingAndNumber.put(key, floorRow.Id);
                }
            }
        }

        List<Ken_Room__c> roomsToInsert = new List<Ken_Room__c>();
        List<Integer> rowNumbersToInsert = new List<Integer>();

        for (Integer index = 0; index < candidateRooms.size(); index++) {
            if (duplicateCandidateIndexes.contains(index)) {
                continue;
            }
            Ken_Room__c roomRecord = candidateRooms[index];
            Integer csvRowNumber = candidateRowNumbers[index];
            Id buildingId = candidateBuildingIds[index];
            Integer floorNumber = candidateFloorNumbers[index];

            String key = String.valueOf(buildingId) + '|' + String.valueOf(floorNumber);
            Id resolvedFloorId = floorIdByBuildingAndNumber.get(key);
            if (resolvedFloorId == null) {
                appendBulkRoomError(response, csvRowNumber, 'Floor was not found for the selected building: ' + String.valueOf(floorNumber) + '.');
                continue;
            }
            if (floorDescribe != null && floorDescribe.isCreateable() && !floorDescribe.isCalculated()) {
                roomRecord.put('Floor__c', resolvedFloorId);
            }

            roomsToInsert.add(roomRecord);
            rowNumbersToInsert.add(csvRowNumber);
        }

        if (roomsToInsert.isEmpty()) {
            response.failureCount = response.errors.size();
            return response;
        }

        Database.SaveResult[] results = Database.insert(roomsToInsert, false);
        Set<Id> successfulBuildingIds = new Set<Id>();
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult sr = results[i];
            Integer csvRowNumber = rowNumbersToInsert[i];
            if (sr != null && sr.isSuccess()) {
                response.successCount++;
                successfulBuildingIds.add(roomsToInsert[i].Building__c);
                continue;
            }
            response.failureCount++;
            if (sr != null && sr.getErrors() != null && sr.getErrors().size() > 0) {
                appendBulkRoomError(response, csvRowNumber, sr.getErrors()[0].getMessage());
            } else {
                appendBulkRoomError(response, csvRowNumber, 'Unable to create room.');
            }
        }

        syncBuildingTotalRooms(successfulBuildingIds);

        // Count any validation errors collected before DML as failures too.
        response.failureCount = response.failureCount + Math.max(0, response.errors.size() - response.failureCount);
        return response;
    }

    private static void ensureUniqueRoomNumber(String roomNumber, Id roomIdToExclude) {
        String cleanedRoomNumber = sanitize(roomNumber);
        if (String.isBlank(cleanedRoomNumber)) {
            return;
        }

        List<Ken_Room__c> matches;
        if (roomIdToExclude == null) {
            matches = [
                SELECT Id
                FROM Ken_Room__c
                WHERE Room_Number__c = :cleanedRoomNumber
                LIMIT 1
            ];
        } else {
            matches = [
                SELECT Id
                FROM Ken_Room__c
                WHERE Room_Number__c = :cleanedRoomNumber
                  AND Id != :roomIdToExclude
                LIMIT 1
            ];
        }

        if (!matches.isEmpty()) {
            throw new AuraHandledException(buildDuplicateRoomNumberMessage(cleanedRoomNumber));
        }
    }

    private static Set<Integer> collectDuplicateRoomCandidateIndexes(
        BulkRoomCsvResponse response,
        List<Ken_Room__c> candidateRooms,
        List<Integer> candidateRowNumbers
    ) {
        Set<Integer> duplicateIndexes = new Set<Integer>();
        if (
            candidateRooms == null ||
            candidateRowNumbers == null ||
            candidateRooms.isEmpty() ||
            candidateRooms.size() != candidateRowNumbers.size()
        ) {
            return duplicateIndexes;
        }

        Map<String, Integer> firstCandidateIndexByKey = new Map<String, Integer>();
        Set<String> roomNumbersToQuery = new Set<String>();

        for (Integer index = 0; index < candidateRooms.size(); index++) {
            String roomNumber = candidateRooms[index] != null ? sanitize(candidateRooms[index].Room_Number__c) : null;
            String roomKey = normalizeRoomNumberToken(roomNumber);
            if (String.isBlank(roomKey)) {
                continue;
            }

            roomNumbersToQuery.add(roomNumber);

            if (firstCandidateIndexByKey.containsKey(roomKey)) {
                duplicateIndexes.add(index);
                appendBulkRoomError(
                    response,
                    candidateRowNumbers[index],
                    buildDuplicateRoomNumberMessage(roomNumber)
                );
                continue;
            }

            firstCandidateIndexByKey.put(roomKey, index);
        }

        if (roomNumbersToQuery.isEmpty()) {
            return duplicateIndexes;
        }

        Set<String> existingRoomKeys = new Set<String>();
        for (Ken_Room__c existingRoom : [
            SELECT Id, Room_Number__c
            FROM Ken_Room__c
            WHERE Room_Number__c IN :roomNumbersToQuery
        ]) {
            String existingKey = normalizeRoomNumberToken(existingRoom.Room_Number__c);
            if (String.isNotBlank(existingKey)) {
                existingRoomKeys.add(existingKey);
            }
        }

        for (Integer index = 0; index < candidateRooms.size(); index++) {
            if (duplicateIndexes.contains(index)) {
                continue;
            }

            String roomNumber = candidateRooms[index] != null ? sanitize(candidateRooms[index].Room_Number__c) : null;
            String roomKey = normalizeRoomNumberToken(roomNumber);
            if (String.isBlank(roomKey) || !existingRoomKeys.contains(roomKey)) {
                continue;
            }

            duplicateIndexes.add(index);
            appendBulkRoomError(
                response,
                candidateRowNumbers[index],
                buildDuplicateRoomNumberMessage(roomNumber)
            );
        }

        return duplicateIndexes;
    }

    private static String buildDuplicateRoomNumberMessage(String roomNumber) {
        String cleanedRoomNumber = sanitize(roomNumber);
        if (String.isBlank(cleanedRoomNumber)) {
            return 'Room Number already exists for the selected building.';
        }
        return 'Room Number "' + cleanedRoomNumber + '" already exists for the selected building.';
    }

    private static String normalizeRoomNumberToken(String roomNumber) {
        String cleanedRoomNumber = sanitize(roomNumber);
        if (String.isBlank(cleanedRoomNumber)) {
            return null;
        }
        return cleanedRoomNumber.toLowerCase().replaceAll('\\s+', ' ');
    }

    private static void appendBulkRoomError(BulkRoomCsvResponse response, Integer rowNumber, String message) {
        if (response == null) {
            return;
        }
        BulkRoomCsvError errorRow = new BulkRoomCsvError();
        errorRow.rowNumber = rowNumber;
        errorRow.message = String.isNotBlank(message) ? message : 'Invalid row.';
        response.errors.add(errorRow);
    }

    @AuraEnabled(cacheable=true)
    public static BuildingFormOptions getBuildingFormOptions() {
        BuildingFormOptions options = new BuildingFormOptions();
        options.genderOptions = new List<OptionItem>();
        options.hostelTypeOptions = new List<OptionItem>();
        options.statusOptions = new List<OptionItem>();
        options.wardenModeOptions = new List<OptionItem>();
        options.wardenOptions = new List<OptionItem>();

        for (Schema.PicklistEntry entry : Ken_Building__c.Hostel_Type__c.getDescribe().getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            String label = getBuildingGenderLabel(entry.getValue());
            options.genderOptions.add(new OptionItem(label, entry.getValue()));
            options.hostelTypeOptions.add(new OptionItem(label, entry.getValue()));
        }

        for (Schema.PicklistEntry entry : Ken_Building__c.Status__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                options.statusOptions.add(new OptionItem(entry.getLabel(), entry.getValue()));
            }
        }

        for (Schema.PicklistEntry entry : Ken_Building__c.Warden_Assignment_Mode__c.getDescribe().getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            options.wardenModeOptions.add(new OptionItem(getBuildingWardenModeOptionLabel(entry.getValue()), entry.getValue()));
        }

        for (Account wardenAccount : getActiveRoleAccounts('Warden')) {
            OptionItem wardenOption = new OptionItem(wardenAccount.Name, String.valueOf(wardenAccount.Id));
            wardenOption.phone = wardenAccount.Phone;
            wardenOption.description = wardenAccount.Description;
            options.wardenOptions.add(wardenOption);
        }

        return options;
    }

    @AuraEnabled
    public static Id createBuilding(CreateBuildingRequest inputRequest) {
        if (inputRequest == null) {
            throw new AuraHandledException('Building payload is required.');
        }

        String buildingName = sanitize(inputRequest.buildingName);
        String hostelTypeValue = normalizeHostelTypeValue(inputRequest.genderValue);
        String statusValue = resolveBuildingStatusPicklistValue(inputRequest.statusValue);
        String numberOfFloors = sanitize(inputRequest.numberOfFloors);
        String wardenModeValue = normalizeWardenModeValue(inputRequest.wardenMode);
        String buildingWardenInput = sanitize(inputRequest.buildingWarden);

        if (String.isBlank(buildingName)) {
            throw new AuraHandledException('Building Name is required.');
        }
        if (String.isBlank(hostelTypeValue)) {
            throw new AuraHandledException('Gender is required.');
        }
        if (String.isBlank(statusValue)) {
            throw new AuraHandledException('Status is required.');
        }
        if (String.isBlank(numberOfFloors)) {
            throw new AuraHandledException('Number of Floors is required.');
        }
        if (!isPositiveWholeNumber(numberOfFloors)) {
            throw new AuraHandledException('Number of Floors must be a positive whole number.');
        }
        if (String.isBlank(wardenModeValue)) {
            wardenModeValue = 'Building Level';
        }
        if (String.isBlank(buildingWardenInput)) {
            throw new AuraHandledException('Building Warden is required.');
        }
        if (!Schema.sObjectType.Ken_Building__c.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create buildings.');
        }

        Ken_Building__c recordToInsert = new Ken_Building__c();
        recordToInsert.Name__c = buildingName;
        recordToInsert.Hostel_Type__c = hostelTypeValue;
        recordToInsert.Status__c = statusValue;
        recordToInsert.Number_Of_Floors__c = numberOfFloors;
        recordToInsert.Total_Floors__c = numberOfFloors;
        recordToInsert.Warden_Assignment_Mode__c = wardenModeValue;
        recordToInsert.Capacity__c = '0';
        recordToInsert.Total_Rooms__c = '0';
        recordToInsert.Occupancy__c = '0';
        recordToInsert.Current_Occupancy__c = '0';

        Id resolvedWardenId = resolveWardenId(buildingWardenInput);
        if (resolvedWardenId != null) {
            if (!getAccountsWithActiveRole(new Set<Id>{ resolvedWardenId }, 'Warden').contains(resolvedWardenId)) {
                throw new AuraHandledException('Please select a valid active Warden account.');
            }
            recordToInsert.Warden__c = resolvedWardenId;
        }

        insert recordToInsert;
        syncFloorMasterRecords(recordToInsert.Id, toWholeNumber(numberOfFloors));
        return recordToInsert.Id;
    }

    @AuraEnabled
    public static Id updateBuilding(String buildingId, CreateBuildingRequest inputRequest) {
        if (String.isBlank(buildingId)) {
            throw new AuraHandledException('Building is required.');
        }
        if (inputRequest == null) {
            throw new AuraHandledException('Building payload is required.');
        }

        Id buildingRecordId = toIdValue(buildingId, 'Invalid Building value.');
        if (!Schema.sObjectType.Ken_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view buildings.');
        }
        String inputBuildingName = sanitize(inputRequest.buildingName);
        String inputHostelTypeValue = normalizeHostelTypeValue(inputRequest.genderValue);
        String inputStatusValue = resolveBuildingStatusPicklistValue(inputRequest.statusValue);
        String inputNumberOfFloors = sanitize(inputRequest.numberOfFloors);
        String inputWardenModeValue = normalizeWardenModeValue(inputRequest.wardenMode);

        List<Ken_Building__c> existingBuildings = [
            SELECT Id, Name, Name__c, Hostel_Type__c, Status__c, Number_Of_Floors__c, Total_Floors__c, Warden_Assignment_Mode__c, Warden__c
            FROM Ken_Building__c
            WHERE Id = :buildingRecordId
            LIMIT 1
        ];
        if (existingBuildings.isEmpty()) {
            throw new AuraHandledException('Building record was not found.');
        }

        Ken_Building__c recordToUpdate = existingBuildings[0];
        String buildingName = firstNonBlank(new List<String>{
            inputBuildingName,
            sanitize(recordToUpdate.Name__c),
            sanitize(recordToUpdate.Name)
        });
        String hostelTypeValue = firstNonBlank(new List<String>{
            inputHostelTypeValue,
            normalizeHostelTypeValue(recordToUpdate.Hostel_Type__c)
        });
        String statusValue = firstNonBlank(new List<String>{
            inputStatusValue,
            resolveBuildingStatusPicklistValue(recordToUpdate.Status__c),
            normalizeBuildingStatusValue(recordToUpdate.Status__c)
        });
        String numberOfFloors = firstNonBlank(new List<String>{
            inputNumberOfFloors,
            sanitize(recordToUpdate.Number_Of_Floors__c),
            sanitize(recordToUpdate.Total_Floors__c)
        });
        String wardenModeValue = firstNonBlank(new List<String>{
            inputWardenModeValue,
            normalizeWardenModeValue(recordToUpdate.Warden_Assignment_Mode__c)
        });

        if (String.isBlank(buildingName)) {
            throw new AuraHandledException('Building Name is required.');
        }
        if (String.isBlank(hostelTypeValue)) {
            throw new AuraHandledException('Gender is required.');
        }
        if (String.isBlank(statusValue)) {
            throw new AuraHandledException('Status is required.');
        }
        if (String.isBlank(numberOfFloors)) {
            throw new AuraHandledException('Number of Floors is required.');
        }
        if (!isPositiveWholeNumber(numberOfFloors)) {
            throw new AuraHandledException('Number of Floors must be a positive whole number.');
        }
        if (String.isBlank(wardenModeValue)) {
            wardenModeValue = 'Building Level';
        }

        recordToUpdate.Name__c = buildingName;
        recordToUpdate.Hostel_Type__c = hostelTypeValue;
        recordToUpdate.Status__c = statusValue;
        recordToUpdate.Number_Of_Floors__c = numberOfFloors;
        recordToUpdate.Total_Floors__c = numberOfFloors;
        recordToUpdate.Warden_Assignment_Mode__c = wardenModeValue;

        String wardenInput = sanitize(inputRequest.buildingWarden);
        if (wardenInput != null) {
            Id resolvedWardenId = resolveWardenId(wardenInput);
            if (resolvedWardenId != null) {
                if (!getAccountsWithActiveRole(new Set<Id>{ resolvedWardenId }, 'Warden').contains(resolvedWardenId)) {
                    throw new AuraHandledException('Please select a valid active Warden account.');
                }
                recordToUpdate.Warden__c = resolvedWardenId;
            }
        }
        if (!Schema.sObjectType.Ken_Building__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update buildings.');
        }

        update recordToUpdate;
        syncFloorMasterRecords(recordToUpdate.Id, toWholeNumber(numberOfFloors));
        return recordToUpdate.Id;
    }

    @AuraEnabled
    public static void deleteBuilding(String buildingId) {
        if (String.isBlank(buildingId)) {
            throw new AuraHandledException('Building is required.');
        }

        Id buildingRecordId = toIdValue(buildingId, 'Invalid Building value.');
        if (!Schema.sObjectType.Ken_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view buildings.');
        }
        List<Ken_Building__c> buildings = [
            SELECT Id
            FROM Ken_Building__c
            WHERE Id = :buildingRecordId
            LIMIT 1
        ];
        if (buildings.isEmpty()) {
            throw new AuraHandledException('Building record was not found.');
        }
        if (!Schema.sObjectType.Ken_Building__c.isDeletable()) {
            throw new AuraHandledException('You do not have permission to delete buildings.');
        }
        try {
            delete buildings[0];
        } catch (DmlException e) {
            throw new AuraHandledException(firstNonBlank(new List<String>{
                e.getDmlMessage(0),
                'Unable to delete building.'
            }));
        }
    }

    private static RoomCategoryRow mapRoomCategoryRow(Ken_Room_Category__c item) {
        return mapRoomCategoryRow(item, null);
    }

    private static RoomCategoryRow mapRoomCategoryRow(Ken_Room_Category__c item, List<OptionItem> selectedFeeTypes) {
        RoomCategoryRow row = new RoomCategoryRow();
        row.id = item.Id;
        row.categoryIdentifier = sanitize(item.Name);
        row.categoryName = sanitize(item.Name__c);
        row.description = sanitize(item.Description__c);
        row.genderAllowed = item.Gender_Allowed__c;
        row.sharing = resolveRoomCategorySharingValue(item);
        row.ac = resolveRoomCategoryAcLabel(item);
        row.bathroom = resolveRoomCategoryBathroomLabel(item);
        row.defaultFeeTypeIds = new List<String>();

        List<String> selectedFeeTypeLabels = new List<String>();
        if (selectedFeeTypes != null) {
            for (OptionItem selectedFeeType : selectedFeeTypes) {
                if (selectedFeeType == null || String.isBlank(selectedFeeType.value)) {
                    continue;
                }
                row.defaultFeeTypeIds.add(selectedFeeType.value);
                selectedFeeTypeLabels.add(selectedFeeType.label);
            }
        }

        row.defaultFeeTypeId = row.defaultFeeTypeIds.isEmpty()
            ? null
            : row.defaultFeeTypeIds[0];
        row.defaultFeeType = !selectedFeeTypeLabels.isEmpty()
            ? String.join(selectedFeeTypeLabels, ', ')
            : '--';

        String combinedAmenities = combineAmenities(item.Amenities__c, getCustomAmenitiesFromRoomCategory(item));
        Integer amenitiesCount = countAmenities(combinedAmenities);
        row.amenities = amenitiesCount > 0 ? String.valueOf(amenitiesCount) + ' amenities' : '--';
        row.amenitiesList = parseAmenities(combinedAmenities);
        row.statusValue = item.Active__c == true ? 'active' : 'inactive';
        row.status = item.Active__c == true ? 'Active' : 'Inactive';
        return row;
    }

    private static String resolveRoomCategorySharingValue(Ken_Room_Category__c item) {
        if (item == null) {
            return null;
        }

        Integer sharingValue = item.Sharing__c != null ? item.Sharing__c.intValue() : toWholeNumber(item.Capacity__c);
        return sharingValue > 0 ? String.valueOf(sharingValue) : null;
    }

    private static String resolveRoomCategoryAcLabel(Ken_Room_Category__c item) {
        if (item == null) {
            return null;
        }

        String explicitValue = normalizeRoomCategoryAcValue(item.Ac_Non_Ac__c);
        if (String.isNotBlank(explicitValue)) {
            return explicitValue;
        }

        String combinedAmenities = combineAmenities(item.Amenities__c, getCustomAmenitiesFromRoomCategory(item));
        if (String.isBlank(combinedAmenities)) {
            return null;
        }

        String normalizedAmenities = combinedAmenities.toLowerCase();
        if (normalizedAmenities.contains('non-ac') || normalizedAmenities.contains('non ac') || normalizedAmenities.contains('without ac')) {
            return 'No';
        }
        if (normalizedAmenities.contains('air conditioning') || normalizedAmenities.contains(' ac')) {
            return 'Yes';
        }
        return null;
    }

    private static String resolveRoomCategoryBathroomLabel(Ken_Room_Category__c item) {
        if (item == null) {
            return null;
        }

        String explicitValue = normalizeRoomCategoryBathroomValue(item.Bathroom__c);
        if (String.isNotBlank(explicitValue)) {
            return explicitValue;
        }

        String combinedAmenities = combineAmenities(item.Amenities__c, getCustomAmenitiesFromRoomCategory(item));
        if (String.isBlank(combinedAmenities)) {
            return null;
        }

        String normalizedAmenities = combinedAmenities.toLowerCase();
        if (normalizedAmenities.contains('attached bathroom') || normalizedAmenities.contains('attached bath') || normalizedAmenities.contains('ensuite')) {
            return 'Attached';
        }
        if (normalizedAmenities.contains('common bathroom') || normalizedAmenities.contains('shared bathroom') || normalizedAmenities.contains('shared bath')) {
            return 'Common';
        }
        return null;
    }

    private static BuildingRow mapBuildingRow(Ken_Building__c building) {
        BuildingRow row = new BuildingRow();
        row.id = building.Id;
        row.name = firstNonBlank(new List<String>{
            sanitize(building.Name__c),
            sanitize(building.Name)
        });
        row.gender = getBuildingGenderLabel(building.Hostel_Type__c);
        row.hostelTypeValue = building.Hostel_Type__c;
        row.buildingIdentifier = sanitize(building.Name);
        row.floors = firstNonBlank(new List<String>{
            sanitize(building.Number_Of_Floors__c),
            sanitize(building.Total_Floors__c),
            '0'
        });
        row.wardenMode = getBuildingWardenModeLabel(building.Warden_Assignment_Mode__c);
        row.wardenId = building.Warden__c == null ? null : String.valueOf(building.Warden__c);
        row.wardenName = building.Warden__r != null ? building.Warden__r.Name : null;
        row.wardenPhone = building.Warden__r != null ? building.Warden__r.Phone : null;
        row.capacity = firstNonBlank(new List<String>{ sanitize(building.Capacity__c), '0' });
        row.currentOccupancy = sanitize(building.Current_Occupancy__c);
        row.occupancyPercent = sanitize(building.Occupancy__c);
        row.roomsCount = firstNonBlank(new List<String>{ sanitize(building.Total_Rooms__c), '0' });
        row.status = firstNonBlank(new List<String>{ normalizeBuildingStatusValue(building.Status__c), 'Inactive' });
        row.statusValue = row.status.toLowerCase();
        return row;
    }

    private static void syncBuildingTotalRooms(Set<Id> buildingIds) {
        Set<Id> resolvedBuildingIds = new Set<Id>();
        if (buildingIds != null) {
            for (Id buildingId : buildingIds) {
                if (buildingId != null) {
                    resolvedBuildingIds.add(buildingId);
                }
            }
        }
        if (resolvedBuildingIds.isEmpty()) {
            return;
        }
        if (!Schema.sObjectType.Ken_Building__c.isAccessible()) {
            return;
        }

        List<Ken_Building__c> buildings = [
            SELECT Id, Total_Rooms__c
            FROM Ken_Building__c
            WHERE Id IN :resolvedBuildingIds
            LIMIT 5000
        ];
        syncBuildingTotalRooms(buildings, true, true);
    }

    private static void syncBuildingTotalRooms(
        List<Ken_Building__c> buildings,
        Boolean persistChanges,
        Boolean failOnPersistError
    ) {
        if (buildings == null || buildings.isEmpty()) {
            return;
        }

        Set<Id> buildingIds = new Set<Id>();
        for (Ken_Building__c building : buildings) {
            if (building != null && building.Id != null) {
                buildingIds.add(building.Id);
            }
        }
        if (buildingIds.isEmpty()) {
            return;
        }

        Map<Id, Integer> roomCountByBuildingId = getRoomCountByBuildingId(buildingIds, failOnPersistError);
        if (roomCountByBuildingId == null) {
            return;
        }
        List<Ken_Building__c> buildingsToUpdate = new List<Ken_Building__c>();
        Boolean canPersist = false;
        if (persistChanges && Schema.sObjectType.Ken_Building__c.isUpdateable()) {
            Map<String, Schema.SObjectField> buildingFieldMap = Ken_Building__c.SObjectType.getDescribe().fields.getMap();
            if (buildingFieldMap.containsKey('Total_Rooms__c')) {
                Schema.DescribeFieldResult totalRoomsDescribe = buildingFieldMap.get('Total_Rooms__c').getDescribe();
                canPersist = totalRoomsDescribe.isUpdateable() && !totalRoomsDescribe.isCalculated();
            }
        }

        for (Ken_Building__c building : buildings) {
            if (building == null || building.Id == null) {
                continue;
            }

            Integer roomCount = roomCountByBuildingId.containsKey(building.Id)
                ? roomCountByBuildingId.get(building.Id)
                : 0;
            String expectedValue = String.valueOf(roomCount);
            String currentValue = firstNonBlank(new List<String>{
                sanitize(building.Total_Rooms__c),
                '0'
            });
            if (currentValue == expectedValue) {
                continue;
            }

            building.Total_Rooms__c = expectedValue;
            if (canPersist) {
                buildingsToUpdate.add(new Ken_Building__c(
                    Id = building.Id,
                    Total_Rooms__c = expectedValue
                ));
            }
        }

        if (!persistChanges || !canPersist || buildingsToUpdate.isEmpty()) {
            return;
        }

        try {
            update buildingsToUpdate;
        } catch (DmlException e) {
            if (failOnPersistError) {
                throw new AuraHandledException(firstNonBlank(new List<String>{
                    e.getDmlMessage(0),
                    'Unable to update building room totals.'
                }));
            }
        }
    }

    private static Map<Id, Integer> getRoomCountByBuildingId(
        Set<Id> buildingIds,
        Boolean failOnPermissionError
    ) {
        if (buildingIds == null || buildingIds.isEmpty()) {
            return new Map<Id, Integer>();
        }
        if (!Schema.sObjectType.Ken_Room__c.isAccessible()) {
            if (failOnPermissionError) {
                throw new AuraHandledException('You do not have permission to view rooms.');
            }
            return null;
        }

        Map<Id, Integer> roomCountByBuildingId = new Map<Id, Integer>();
        for (AggregateResult aggregateRow : [
            SELECT Building__c buildingId, COUNT(Id) roomCount
            FROM Ken_Room__c
            WHERE Building__c IN :buildingIds
            GROUP BY Building__c
        ]) {
            Id buildingId = (Id) aggregateRow.get('buildingId');
            if (buildingId == null) {
                continue;
            }
            roomCountByBuildingId.put(
                buildingId,
                Integer.valueOf(String.valueOf(aggregateRow.get('roomCount')))
            );
        }
        return roomCountByBuildingId;
    }

    private static String buildSyntheticFloorValue(String buildingId, Integer floorNumber) {
        return 'SYNTH::' + sanitize(buildingId) + '::' + String.valueOf(floorNumber);
    }

    private static Boolean isSyntheticFloorValue(String floorValue) {
        String cleaned = sanitize(floorValue);
        return String.isNotBlank(cleaned) && cleaned.startsWith('SYNTH::');
    }

    private static Id extractBuildingIdFromSyntheticFloorValue(String floorValue) {
        List<String> parts = parseSyntheticFloorValue(floorValue);
        if (parts.size() != 3) {
            return null;
        }

        try {
            return (Id) sanitize(parts[1]);
        } catch (Exception e) {
            return null;
        }
    }

    private static Integer extractFloorNumberFromSyntheticFloorValue(String floorValue) {
        List<String> parts = parseSyntheticFloorValue(floorValue);
        if (parts.size() != 3) {
            return null;
        }

        String floorPart = sanitize(parts[2]);
        if (String.isBlank(floorPart) || !Pattern.matches('^[1-9][0-9]*$', floorPart)) {
            return null;
        }

        try {
            return Integer.valueOf(floorPart);
        } catch (Exception e) {
            return null;
        }
    }

    private static List<String> parseSyntheticFloorValue(String floorValue) {
        String cleaned = sanitize(floorValue);
        if (String.isBlank(cleaned)) {
            return new List<String>();
        }
        return cleaned.split('::');
    }

    private static void ensureRoomFieldCreateable(
        Map<String, Schema.SObjectField> roomFieldMap,
        String apiName,
        String label
    ) {
        if (roomFieldMap == null || !roomFieldMap.containsKey(apiName)) {
            throw new AuraHandledException(label + ' field is not available on Ken_Room__c.');
        }
        Schema.DescribeFieldResult describe = roomFieldMap.get(apiName).getDescribe();
        if (!describe.isCreateable() || describe.isCalculated()) {
            throw new AuraHandledException('You do not have permission to set ' + label + '.');
        }
    }

    private static void ensureRoomFieldUpdateable(
        Map<String, Schema.SObjectField> roomFieldMap,
        String apiName,
        String label
    ) {
        if (roomFieldMap == null || !roomFieldMap.containsKey(apiName)) {
            throw new AuraHandledException(label + ' field is not available on Ken_Room__c.');
        }
        Schema.DescribeFieldResult describe = roomFieldMap.get(apiName).getDescribe();
        if (!describe.isUpdateable() || describe.isCalculated()) {
            throw new AuraHandledException('You do not have permission to update ' + label + '.');
        }
    }

    private static Id toIdValue(String rawId, String errorMessage) {
        String cleaned = sanitize(rawId);
        if (String.isBlank(cleaned)) {
            return null;
        }
        try {
            return (Id) cleaned;
        } catch (Exception e) {
            throw new AuraHandledException(errorMessage);
        }
    }

    private static Id toIdValueAllowNull(String rawId) {
        String cleaned = sanitize(rawId);
        if (String.isBlank(cleaned)) {
            return null;
        }
        try {
            return (Id) cleaned;
        } catch (Exception e) {
            return null;
        }
    }

    private static String resolveRoomStatusFieldValue(String normalizedStatus, Schema.DescribeFieldResult statusDescribe) {
        if (String.isBlank(normalizedStatus) || statusDescribe == null) {
            return null;
        }

        if (statusDescribe.getType() == Schema.DisplayType.Picklist) {
            for (Schema.PicklistEntry picklistEntry : statusDescribe.getPicklistValues()) {
                if (!picklistEntry.isActive()) {
                    continue;
                }

                String candidateValue = picklistEntry.getValue();
                String candidateLabel = picklistEntry.getLabel();
                if (
                    normalizeRoomStatusValue(candidateValue) == normalizedStatus ||
                    normalizeRoomStatusValue(candidateLabel) == normalizedStatus
                ) {
                    return candidateValue;
                }
            }
            return null;
        }

        return getRoomStatusLabel(normalizedStatus);
    }

    private static String normalizeRoomStatusFilter(String statusFilter) {
        String cleaned = sanitize(statusFilter);
        if (String.isBlank(cleaned) || cleaned.toLowerCase() == 'all') {
            return null;
        }
        return normalizeRoomStatusValue(cleaned);
    }

    private static String resolveRoomStatusValue(Integer occupancyCount, Integer capacityCount, String explicitStatus) {
        String normalizedExplicit = normalizeRoomStatusValue(explicitStatus);
        if (normalizedExplicit != null) {
            return normalizedExplicit;
        }
        return 'active';
    }

    private static Integer resolveEffectiveRoomOccupancy(Integer occupancyCount, Integer capacityCount, String statusValue) {
        Integer capacity = capacityCount == null ? 0 : Math.max(0, capacityCount);
        Integer occupancy = occupancyCount == null ? 0 : Math.max(0, occupancyCount);

        if (capacity <= 0) {
            return occupancy;
        }
        if (occupancy > capacity) {
            occupancy = capacity;
        }
        if (occupancy > 0) {
            return occupancy;
        }
        if (statusValue == 'occupied') {
            return capacity;
        }
        if (statusValue == 'partiallyOccupied') {
            return Math.min(capacity, 1);
        }
        return occupancy;
    }

    private static String normalizeRoomStatusValue(String rawStatus) {
        String cleaned = sanitize(rawStatus);
        if (String.isBlank(cleaned)) {
            return null;
        }

        String normalized = cleaned.toLowerCase().replace(' ', '').replace('-', '');
        if (normalized.contains('inactive') || normalized.contains('blocked') || normalized.contains('maintenance') || normalized.contains('deactivate')) {
            return 'inactive';
        }
        if (
            normalized.contains('active') ||
            normalized.contains('available') ||
            normalized.contains('vacant') ||
            normalized.contains('occupied') ||
            normalized.contains('partial')
        ) {
            return 'active';
        }
        return null;
    }

    private static String getRoomStatusLabel(String statusValue) {
        if (statusValue == 'inactive') {
            return 'Inactive';
        }
        return 'Active';
    }

    private static String normalizeRoomCategoryAcValue(String value) {
        String cleaned = sanitize(value);
        if (String.isBlank(cleaned)) {
            return null;
        }

        String normalized = cleaned.toLowerCase().replace('-', ' ').replaceAll('\\s+', ' ').trim();
        if (normalized == 'yes' || normalized == 'ac' || normalized == 'with ac') {
            return 'Yes';
        }
        if (normalized == 'no' || normalized == 'non ac' || normalized == 'without ac') {
            return 'No';
        }
        return cleaned;
    }

    private static String normalizeRoomCategoryBathroomValue(String value) {
        String cleaned = sanitize(value);
        if (String.isBlank(cleaned)) {
            return null;
        }

        String normalized = cleaned.toLowerCase().replace('-', ' ').replaceAll('\\s+', ' ').trim();
        if (normalized == 'attached' || normalized == 'attached bathroom' || normalized == 'attached bath' || normalized == 'ensuite') {
            return 'Attached';
        }
        if (normalized == 'common' || normalized == 'common bathroom' || normalized == 'shared bathroom' || normalized == 'shared bath') {
            return 'Common';
        }
        return cleaned;
    }

    private static Integer toWholeNumber(Object value) {
        if (value == null) {
            return 0;
        }
        String raw = sanitize(String.valueOf(value));
        if (String.isBlank(raw)) {
            return 0;
        }
        try {
            Decimal numberValue = Decimal.valueOf(raw);
            return numberValue.intValue();
        } catch (Exception e) {
            return 0;
        }
    }

    private static String resolveRoomBuildingLabel(SObject roomRecord) {
        return firstNonBlank(new List<String>{
            getNestedFieldValue(roomRecord, 'Building__r', 'Name__c'),
            getNestedFieldValue(roomRecord, 'Building__r', 'Name'),
            getStringValue(roomRecord, 'Block__c'),
            '--'
        });
    }

    private static String resolveRoomFeeType(
        Id roomCategoryId,
        Map<Id, List<OptionItem>> feeTypeSelectionsByCategory
    ) {
        if (roomCategoryId == null || feeTypeSelectionsByCategory == null) {
            return '--';
        }
        List<OptionItem> selectedFeeTypes = feeTypeSelectionsByCategory.get(roomCategoryId);
        if (selectedFeeTypes == null || selectedFeeTypes.isEmpty()) {
            return '--';
        }

        List<String> labels = new List<String>();
        for (OptionItem selectedFeeType : selectedFeeTypes) {
            if (selectedFeeType != null && String.isNotBlank(selectedFeeType.label)) {
                labels.add(selectedFeeType.label);
            }
        }
        return labels.isEmpty() ? '--' : String.join(labels, ', ');
    }

    private static Map<Id, List<OptionItem>> getRoomCategoryFeeTypeSelections(Set<Id> roomCategoryIds) {
        Map<Id, List<OptionItem>> selectionsByCategory = new Map<Id, List<OptionItem>>();
        if (roomCategoryIds == null || roomCategoryIds.isEmpty()) {
            return selectionsByCategory;
        }
        if (!Schema.sObjectType.Ken_Room_Category_Fee_Type__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room category fee types.');
        }

        for (Ken_Room_Category_Fee_Type__c junctionRow : [
            SELECT Room_Category__c, Fee_Type__c, Fee_Type__r.Name, Fee_Type__r.Fee_Type_Name__c
            FROM Ken_Room_Category_Fee_Type__c
            WHERE Room_Category__c IN :roomCategoryIds
            ORDER BY Fee_Type__r.Fee_Type_Name__c ASC, Fee_Type__r.Name ASC
        ]) {
            if (!selectionsByCategory.containsKey(junctionRow.Room_Category__c)) {
                selectionsByCategory.put(junctionRow.Room_Category__c, new List<OptionItem>());
            }
            selectionsByCategory.get(junctionRow.Room_Category__c).add(
                new OptionItem(getKenFeeTypeLabel(junctionRow.Fee_Type__r), String.valueOf(junctionRow.Fee_Type__c))
            );
        }

        return selectionsByCategory;
    }

    private static void syncRoomCategoryFeeTypes(Id roomCategoryId, List<Id> feeTypeIds) {
        if (roomCategoryId == null) {
            return;
        }

        List<Id> safeFeeTypeIds = feeTypeIds == null ? new List<Id>() : feeTypeIds;
        Set<Id> selectedFeeTypeIds = new Set<Id>(safeFeeTypeIds);
        if (!Schema.sObjectType.Ken_Room_Category_Fee_Type__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view room category fee types.');
        }

        List<Ken_Room_Category_Fee_Type__c> existingRows = [
            SELECT Id, Fee_Type__c
            FROM Ken_Room_Category_Fee_Type__c
            WHERE Room_Category__c = :roomCategoryId
        ];

        Map<Id, Ken_Room_Category_Fee_Type__c> existingByFeeTypeId = new Map<Id, Ken_Room_Category_Fee_Type__c>();
        List<Ken_Room_Category_Fee_Type__c> rowsToDelete = new List<Ken_Room_Category_Fee_Type__c>();
        for (Ken_Room_Category_Fee_Type__c existingRow : existingRows) {
            if (selectedFeeTypeIds.contains(existingRow.Fee_Type__c)) {
                existingByFeeTypeId.put(existingRow.Fee_Type__c, existingRow);
            } else {
                rowsToDelete.add(existingRow);
            }
        }

        List<Ken_Room_Category_Fee_Type__c> rowsToInsert = new List<Ken_Room_Category_Fee_Type__c>();
        for (Id feeTypeId : safeFeeTypeIds) {
            if (existingByFeeTypeId.containsKey(feeTypeId)) {
                continue;
            }
            rowsToInsert.add(new Ken_Room_Category_Fee_Type__c(
                Room_Category__c = roomCategoryId,
                Fee_Type__c = feeTypeId
            ));
        }

        if (!rowsToDelete.isEmpty()) {
            if (!Schema.sObjectType.Ken_Room_Category_Fee_Type__c.isDeletable()) {
                throw new AuraHandledException('You do not have permission to delete room category fee types.');
            }
            delete rowsToDelete;
        }
        if (!rowsToInsert.isEmpty()) {
            if (!Schema.sObjectType.Ken_Room_Category_Fee_Type__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create room category fee types.');
            }
            insert rowsToInsert;
        }
    }

    private static List<Id> normalizeRoomCategoryFeeTypeIds(List<String> rawFeeTypeIds, String fallbackFeeTypeId) {
        List<Id> feeTypeIds = new List<Id>();
        Set<Id> seenFeeTypeIds = new Set<Id>();

        if (rawFeeTypeIds != null) {
            for (String rawFeeTypeId : rawFeeTypeIds) {
                Id feeTypeId = toIdValue(rawFeeTypeId, 'Invalid Fee Type value.');
                if (feeTypeId != null && !seenFeeTypeIds.contains(feeTypeId)) {
                    seenFeeTypeIds.add(feeTypeId);
                    feeTypeIds.add(feeTypeId);
                }
            }
        }

        if (feeTypeIds.isEmpty()) {
            Id fallbackId = toIdValueAllowNull(fallbackFeeTypeId);
            if (fallbackId != null && !seenFeeTypeIds.contains(fallbackId)) {
                feeTypeIds.add(fallbackId);
                seenFeeTypeIds.add(fallbackId);
            }
        }

        if (feeTypeIds.isEmpty()) {
            return feeTypeIds;
        }
        if (!Schema.sObjectType.Ken_Fee_Type__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view fee types.');
        }

        Map<Id, Ken_Fee_Type__c> validFeeTypesById = new Map<Id, Ken_Fee_Type__c>([
            SELECT Id
            FROM Ken_Fee_Type__c
            WHERE Id IN :feeTypeIds
              AND Fee_Category__c = 'Hostel'
              AND Status__c = 'Active'
        ]);
        if (validFeeTypesById.size() != feeTypeIds.size()) {
            throw new AuraHandledException('Please select only active hostel fee types.');
        }

        return feeTypeIds;
    }

    private static String getKenFeeTypeLabel(Ken_Fee_Type__c feeType) {
        if (feeType == null) {
            return null;
        }
        return firstNonBlank(new List<String>{
            sanitize(feeType.Fee_Type_Name__c),
            sanitize(feeType.Name)
        });
    }

    private static String getKenFeeTypeLabel(SObject feeType) {
        if (feeType == null) {
            return null;
        }
        return firstNonBlank(new List<String>{
            getStringValue(feeType, 'Fee_Type_Name__c'),
            getStringValue(feeType, 'Name')
        });
    }

    private static Object resolveRoomFloorFieldValue(
        Schema.DescribeFieldResult floorDescribe,
        String floorInputRaw,
        Integer floorNumber,
        Id buildingId
    ) {
        if (floorDescribe == null) {
            return null;
        }

        Integer safeFloorNumber = floorNumber == null ? 0 : floorNumber;
        String floorInput = sanitize(floorInputRaw);
        Schema.DisplayType displayType = floorDescribe.getType();

        if (displayType == Schema.DisplayType.Reference) {
            if (isSyntheticFloorValue(floorInput)) {
                Id syntheticBuildingId = extractBuildingIdFromSyntheticFloorValue(floorInput);
                Integer syntheticFloorNumber = extractFloorNumberFromSyntheticFloorValue(floorInput);
                Id effectiveBuildingId = syntheticBuildingId != null ? syntheticBuildingId : buildingId;
                Integer effectiveFloorNumber = syntheticFloorNumber != null ? syntheticFloorNumber : safeFloorNumber;
                return resolveReferenceFloorId(floorDescribe, effectiveBuildingId, effectiveFloorNumber);
            }
            try {
                return (Id) floorInput;
            } catch (Exception e) {
                return resolveReferenceFloorId(floorDescribe, buildingId, safeFloorNumber);
            }
        }

        if (
            displayType == Schema.DisplayType.Integer ||
            displayType == Schema.DisplayType.Double ||
            displayType == Schema.DisplayType.Currency ||
            displayType == Schema.DisplayType.Percent
        ) {
            return safeFloorNumber > 0 ? Decimal.valueOf(String.valueOf(safeFloorNumber)) : null;
        }

        if (displayType == Schema.DisplayType.Picklist) {
            List<String> candidates = new List<String>{
                String.valueOf(safeFloorNumber),
                floorInput,
                getFloorLabelFromNumber(safeFloorNumber)
            };

            for (Schema.PicklistEntry entry : floorDescribe.getPicklistValues()) {
                if (!entry.isActive()) {
                    continue;
                }
                String entryValue = sanitize(entry.getValue());
                String entryLabel = sanitize(entry.getLabel());
                String normalizedValue = normalizeFloorText(entryValue);
                String normalizedLabel = normalizeFloorText(entryLabel);

                for (String candidate : candidates) {
                    String normalizedCandidate = normalizeFloorText(candidate);
                    if (String.isBlank(normalizedCandidate)) {
                        continue;
                    }
                    if (normalizedCandidate == normalizedValue || normalizedCandidate == normalizedLabel) {
                        return entryValue;
                    }
                    if (
                        safeFloorNumber > 0 &&
                        (normalizedValue.contains(String.valueOf(safeFloorNumber)) ||
                            normalizedLabel.contains(String.valueOf(safeFloorNumber)))
                    ) {
                        return entryValue;
                    }
                }
            }
            return safeFloorNumber > 0 ? String.valueOf(safeFloorNumber) : null;
        }

        return safeFloorNumber > 0 ? String.valueOf(safeFloorNumber) : null;
    }

    private static Id resolveReferenceFloorId(
        Schema.DescribeFieldResult floorDescribe,
        Id buildingId,
        Integer floorNumber
    ) {
        if (floorDescribe == null || floorDescribe.getType() != Schema.DisplayType.Reference || floorNumber == null || floorNumber <= 0) {
            return null;
        }

        List<Schema.SObjectType> referenceTargets = floorDescribe.getReferenceTo();
        if (referenceTargets == null || referenceTargets.isEmpty()) {
            return null;
        }

        Schema.SObjectType floorType = referenceTargets[0];
        Schema.DescribeSObjectResult floorDescribeResult = floorType.getDescribe();
        Map<String, Schema.SObjectField> floorFieldMap = floorDescribeResult.fields.getMap();
        if (floorFieldMap == null || floorFieldMap.isEmpty()) {
            return null;
        }
        if (!floorDescribeResult.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view floor records.');
        }

        String buildingLookupField = null;
        for (String fieldApiName : floorFieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = floorFieldMap.get(fieldApiName).getDescribe();
            if (fieldDescribe.getType() != Schema.DisplayType.Reference) {
                continue;
            }
            for (Schema.SObjectType targetType : fieldDescribe.getReferenceTo()) {
                if (targetType == Ken_Building__c.SObjectType) {
                    buildingLookupField = fieldApiName;
                    break;
                }
            }
            if (buildingLookupField != null) {
                break;
            }
        }

        List<String> floorCandidateFields = new List<String>();
        List<String> prioritizedFieldNames = new List<String>{
            'Floor_Number__c',
            'Floor_No__c',
            'Number__c',
            'Level__c',
            'Sequence__c',
            'Name'
        };

        for (String prioritized : prioritizedFieldNames) {
            if (floorFieldMap.containsKey(prioritized)) {
                floorCandidateFields.add(prioritized);
            }
        }
        for (String fieldApiName : floorFieldMap.keySet()) {
            if (floorCandidateFields.contains(fieldApiName)) {
                continue;
            }
            String normalized = normalizeFloorText(fieldApiName);
            if (String.isNotBlank(normalized) && normalized.contains('floor')) {
                floorCandidateFields.add(fieldApiName);
            }
        }
        if (!floorCandidateFields.contains('Name') && floorFieldMap.containsKey('Name')) {
            floorCandidateFields.add('Name');
        }

        String selectClause = 'SELECT Id, Name';
        for (String apiName : floorCandidateFields) {
            if (apiName != 'Id' && apiName != 'Name') {
                selectClause += ', ' + apiName;
            }
        }
        String queryText = selectClause + ' FROM ' + floorDescribeResult.getName();
        if (buildingLookupField != null && buildingId != null) {
            queryText += ' WHERE ' + buildingLookupField + ' = :buildingId';
        }
        queryText += ' ORDER BY LastModifiedDate DESC LIMIT 500';

        List<SObject> floorRows = Database.query(queryText); // NOPMD ApexSOQLInjection - query text is derived from describe metadata and bind variables only.
        for (SObject floorRow : floorRows) {
            if (matchesFloorNumber(floorRow, floorCandidateFields, floorNumber)) {
                return (Id) floorRow.get('Id');
            }
        }
        return null;
    }

    private static Boolean matchesFloorNumber(SObject floorRow, List<String> fieldApiNames, Integer floorNumber) {
        if (floorRow == null || floorNumber == null || floorNumber <= 0) {
            return false;
        }

        String floorToken = String.valueOf(floorNumber);
        String normalizedToken = normalizeFloorText(floorToken);
        for (String fieldApiName : fieldApiNames) {
            if (String.isBlank(fieldApiName)) {
                continue;
            }
            Object rawValue = floorRow.get(fieldApiName);
            if (rawValue == null) {
                continue;
            }

            String stringValue = sanitize(String.valueOf(rawValue));
            if (String.isBlank(stringValue)) {
                continue;
            }

            Integer numericValue = toWholeNumber(stringValue);
            if (numericValue == floorNumber) {
                return true;
            }

            String normalizedValue = normalizeFloorText(stringValue);
            if (normalizedValue == normalizedToken) {
                return true;
            }
            if (normalizedValue != null && normalizedValue.endsWith(normalizedToken)) {
                return true;
            }
        }
        return false;
    }

    private static void syncFloorMasterRecords(Id buildingId, Integer numberOfFloors) {
        if (buildingId == null || numberOfFloors == null || numberOfFloors <= 0) {
            return;
        }
        if (!Schema.sObjectType.Ken_Building__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view buildings.');
        }
        if (!Schema.sObjectType.Floor__c.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view floors.');
        }

        Ken_Building__c buildingRow = [
            SELECT Id, Warden__c, Warden_Assignment_Mode__c
            FROM Ken_Building__c
            WHERE Id = :buildingId
            LIMIT 1
        ];
        Boolean useBuildingLevelWarden = normalizeWardenModeValue(buildingRow.Warden_Assignment_Mode__c) != 'Per Floor';

        Map<Integer, Floor__c> existingFloorsByNumber = new Map<Integer, Floor__c>();
        for (Floor__c floorRow : [
            SELECT Id, Name, Warden__c
            FROM Floor__c
            WHERE Building__c = :buildingId
            LIMIT 5000
        ]) {
            Integer parsedNumber = extractPositiveIntegerFromText(floorRow.Name);
            if (parsedNumber != null && parsedNumber > 0 && !existingFloorsByNumber.containsKey(parsedNumber)) {
                existingFloorsByNumber.put(parsedNumber, floorRow);
            }
        }

        List<Floor__c> floorsToInsert = new List<Floor__c>();
        List<Floor__c> floorsToUpdate = new List<Floor__c>();
        for (Integer floorCounter = 1; floorCounter <= numberOfFloors; floorCounter++) {
            if (existingFloorsByNumber.containsKey(floorCounter)) {
                Floor__c existingFloor = existingFloorsByNumber.get(floorCounter);
                if (useBuildingLevelWarden && existingFloor.Warden__c != buildingRow.Warden__c) {
                    floorsToUpdate.add(new Floor__c(
                        Id = existingFloor.Id,
                        Warden__c = buildingRow.Warden__c
                    ));
                }
                continue;
            }
            floorsToInsert.add(new Floor__c(
                Building__c = buildingId,
                Name = String.valueOf(floorCounter),
                Warden__c = useBuildingLevelWarden ? buildingRow.Warden__c : null
            ));
        }

        if (!floorsToUpdate.isEmpty()) {
            if (!Schema.sObjectType.Floor__c.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update floors.');
            }
            update floorsToUpdate;
        }
        if (!floorsToInsert.isEmpty()) {
            if (!Schema.sObjectType.Floor__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create floors.');
            }
            insert floorsToInsert;
        }
    }

    private static Integer extractPositiveIntegerFromText(String value) {
        String cleaned = sanitize(value);
        if (String.isBlank(cleaned)) {
            return null;
        }

        Matcher matcher = Pattern.compile('(\\d+)').matcher(cleaned);
        if (!matcher.find()) {
            return null;
        }
        String numberText = matcher.group(1);
        if (String.isBlank(numberText)) {
            return null;
        }
        try {
            Integer parsed = Integer.valueOf(numberText);
            return parsed > 0 ? parsed : null;
        } catch (Exception e) {
            return null;
        }
    }

    private static String normalizeFloorText(String value) {
        String cleaned = sanitize(value);
        if (String.isBlank(cleaned)) {
            return null;
        }
        return cleaned.toLowerCase().replace(' ', '').replace('-', '');
    }

    private static String getFloorLabelFromNumber(Integer floorNumber) {
        if (floorNumber == null || floorNumber <= 0) {
            return null;
        }
        if (floorNumber == 1) {
            return 'First Floor';
        }
        if (floorNumber == 2) {
            return 'Second Floor';
        }
        if (floorNumber == 3) {
            return 'Third Floor';
        }
        if (floorNumber == 4) {
            return 'Fourth Floor';
        }
        if (floorNumber == 5) {
            return 'Fifth Floor';
        }
        if (floorNumber == 6) {
            return 'Sixth Floor';
        }
        if (floorNumber == 7) {
            return 'Seventh Floor';
        }
        if (floorNumber == 8) {
            return 'Eighth Floor';
        }
        if (floorNumber == 9) {
            return 'Ninth Floor';
        }
        if (floorNumber == 10) {
            return 'Tenth Floor';
        }
        if (floorNumber == 11) {
            return 'Eleventh Floor';
        }
        if (floorNumber == 12) {
            return 'Twelfth Floor';
        }
        return String.valueOf(floorNumber);
    }

    private static ActivityHistoryEventRow buildRoomHistoryEvent(
        String eventPrefix,
        SObject historyRecord,
        String fieldLabel,
        String currentValue,
        String fallbackByName,
        Datetime fallbackAt
    ) {
        ActivityHistoryEventRow eventRow = new ActivityHistoryEventRow();
        String safeFieldLabel = firstNonBlank(new List<String>{ fieldLabel, 'Field' });
        String safeCurrentValue = firstNonBlank(new List<String>{ sanitize(currentValue), '--' });
        String safeBy = firstNonBlank(new List<String>{ fallbackByName, '--' });
        Datetime safeAt = fallbackAt;

        if (historyRecord != null) {
            String oldValue = sanitize(String.valueOf(historyRecord.get('OldValue')));
            String newValue = sanitize(String.valueOf(historyRecord.get('NewValue')));
            String byName = getNestedFieldValue(historyRecord, 'CreatedBy', 'Name');
            Datetime eventAt = (Datetime) historyRecord.get('CreatedDate');
            if (String.isNotBlank(byName)) {
                safeBy = byName;
            }
            if (eventAt != null) {
                safeAt = eventAt;
            }

            if (String.isNotBlank(oldValue) && String.isNotBlank(newValue) && oldValue != newValue) {
                eventRow.title = eventPrefix + ' • ' + safeFieldLabel + ' from ' + oldValue + ' to ' + newValue;
            } else {
                String latestValue = firstNonBlank(new List<String>{ newValue, safeCurrentValue });
                eventRow.title = eventPrefix + ' • Current ' + safeFieldLabel + ' is ' + latestValue;
            }
        } else {
            eventRow.title = eventPrefix + ' • Current ' + safeFieldLabel + ' is ' + safeCurrentValue;
        }

        eventRow.subtitle = 'by ' + safeBy;
        eventRow.eventAt = safeAt;
        return eventRow;
    }

    private static SObject selectBestStatusHistory(List<SObject> historyRows) {
        if (historyRows == null || historyRows.isEmpty()) {
            return null;
        }

        for (SObject row : historyRows) {
            String oldValue = sanitize(String.valueOf(row.get('OldValue')));
            String newValue = sanitize(String.valueOf(row.get('NewValue')));
            if (String.isNotBlank(oldValue) && String.isNotBlank(newValue) && oldValue != newValue) {
                return row;
            }
        }

        return historyRows[0];
    }

    private static String getNestedFieldValue(SObject record, String relationName, String fieldName) {
        if (record == null || String.isBlank(relationName) || String.isBlank(fieldName)) {
            return null;
        }
        SObject related = null;
        try {
            related = record.getSObject(relationName);
        } catch (Exception e) {
            related = null;
        }
        return getStringValue(related, fieldName);
    }

    private static String getNestedParentFieldValue(
        SObject record,
        String firstRelationName,
        String secondRelationName,
        String fieldName
    ) {
        if (
            record == null ||
            String.isBlank(firstRelationName) ||
            String.isBlank(secondRelationName) ||
            String.isBlank(fieldName)
        ) {
            return null;
        }

        SObject firstRelated = null;
        try {
            firstRelated = record.getSObject(firstRelationName);
        } catch (Exception e) {
            firstRelated = null;
        }
        if (firstRelated == null) {
            return null;
        }
        SObject secondRelated = null;
        try {
            secondRelated = firstRelated.getSObject(secondRelationName);
        } catch (Exception e) {
            secondRelated = null;
        }
        return getStringValue(secondRelated, fieldName);
    }

    private static String getStringValue(SObject record, String fieldName) {
        if (record == null || String.isBlank(fieldName)) {
            return null;
        }
        Object value = getFieldValue(record, fieldName);
        return value == null ? null : sanitize(String.valueOf(value));
    }

    private static Object getFieldValue(SObject record, String fieldName) {
        if (record == null || String.isBlank(fieldName)) {
            return null;
        }
        try {
            return record.get(fieldName);
        } catch (Exception e) {
            return null;
        }
    }

    private static String normalizeBuildingStatusValue(String statusValue) {
        String cleaned = sanitize(statusValue);
        if (String.isBlank(cleaned)) {
            return null;
        }
        String normalized = cleaned.toLowerCase();
        if (normalized == 'active') {
            return 'Active';
        }
        if (normalized == 'inactive') {
            return 'Inactive';
        }
        return cleaned;
    }

    private static String resolveBuildingStatusPicklistValue(String rawStatus) {
        String cleaned = sanitize(rawStatus);
        if (String.isBlank(cleaned)) {
            return null;
        }

        String normalizedInput = cleaned.toLowerCase().replace(' ', '').replace('-', '');
        for (Schema.PicklistEntry entry : Ken_Building__c.Status__c.getDescribe().getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            String value = sanitize(entry.getValue());
            String label = sanitize(entry.getLabel());
            String normalizedValue = value == null ? null : value.toLowerCase().replace(' ', '').replace('-', '');
            String normalizedLabel = label == null ? null : label.toLowerCase().replace(' ', '').replace('-', '');
            if (
                cleaned == value ||
                cleaned == label ||
                (normalizedValue != null && normalizedValue == normalizedInput) ||
                (normalizedLabel != null && normalizedLabel == normalizedInput)
            ) {
                return value;
            }
        }

        return normalizeBuildingStatusValue(cleaned);
    }

    private static String normalizeRoomCategoryStatusValue(String statusValue) {
        String cleaned = sanitize(statusValue);
        if (String.isBlank(cleaned)) {
            return null;
        }
        String normalized = cleaned.toLowerCase();
        if (normalized == 'active') {
            return 'active';
        }
        if (normalized == 'inactive') {
            return 'inactive';
        }
        return normalized;
    }

    private static String normalizeHostelTypeValue(String hostelTypeValue) {
        String cleaned = sanitize(hostelTypeValue);
        if (String.isBlank(cleaned)) {
            return null;
        }

        String normalized = cleaned.toLowerCase();
        if (normalized == 'male' || normalized == 'boys' || normalized == 'boy') {
            return 'Male';
        }
        if (normalized == 'female' || normalized == 'girls' || normalized == 'girl') {
            return 'Female';
        }
        if (normalized == 'co-ed' || normalized == 'coed' || normalized == 'co ed') {
            return 'Co-Ed';
        }
        return cleaned;
    }

    private static String normalizeWardenModeValue(String wardenModeValue) {
        String cleaned = sanitize(wardenModeValue);
        if (String.isBlank(cleaned)) {
            return null;
        }

        String normalized = cleaned.toLowerCase();
        if (
            normalized == 'building level' ||
            normalized == 'building-level' ||
            normalized == 'single warden for entire building'
        ) {
            return 'Building Level';
        }
        if (
            normalized == 'manual' ||
            normalized == 'per-floor' ||
            normalized == 'per floor' ||
            normalized == 'warden per floor'
        ) {
            return 'Manual';
        }
        return cleaned;
    }

    private static String getBuildingGenderLabel(String hostelTypeValue) {
        String normalized = normalizeHostelTypeValue(hostelTypeValue);
        if (normalized == 'Male') {
            return 'Boys';
        }
        if (normalized == 'Female') {
            return 'Girls';
        }
        if (normalized == 'Co-Ed') {
            return 'Co-ed';
        }
        return firstNonBlank(new List<String>{ normalized, '--' });
    }

    private static String getBuildingWardenModeLabel(String wardenModeValue) {
        String normalized = normalizeWardenModeValue(wardenModeValue);
        if (normalized == 'Building Level') {
            return 'Building-level';
        }
        if (normalized == 'Manual') {
            return 'Per-floor';
        }
        return firstNonBlank(new List<String>{ normalized, '--' });
    }

    private static String getBuildingWardenModeOptionLabel(String wardenModeValue) {
        String normalized = normalizeWardenModeValue(wardenModeValue);
        if (normalized == 'Building Level') {
            return 'Single Warden for Entire Building';
        }
        if (normalized == 'Manual') {
            return 'Warden per Floor';
        }
        return firstNonBlank(new List<String>{ normalized, '--' });
    }

    private class NameParts {
        String firstName;
        String lastName;
    }

    private static NameParts splitPersonName(String fullName) {
        String cleaned = sanitize(fullName);
        NameParts parts = new NameParts();
        if (String.isBlank(cleaned)) {
            parts.lastName = 'Warden';
            return parts;
        }

        Integer lastSpace = cleaned.lastIndexOf(' ');
        if (lastSpace > 0) {
            parts.firstName = sanitize(cleaned.substring(0, lastSpace));
            parts.lastName = sanitize(cleaned.substring(lastSpace + 1));
        } else {
            parts.lastName = cleaned;
        }

        if (String.isBlank(parts.lastName)) {
            parts.lastName = cleaned;
        }
        return parts;
    }

    private static Id getWardenPersonAccountRecordTypeId() {
        if (cachedWardenPersonAccountRecordTypeId != null) {
            return cachedWardenPersonAccountRecordTypeId;
        }
        if (!Schema.sObjectType.RecordType.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view record types.');
        }

        List<RecordType> personAccountRecordTypes = [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Account'
              AND IsPersonType = true
        ];
        if (personAccountRecordTypes.isEmpty()) {
            return null;
        }

        List<String> preferredDeveloperNames = new List<String>{
            'Faculty',
            'Admissions_Higher_Ed_Person_Account',
            'Student_Success_Higher_Ed_Student'
        };
        for (String preferredDeveloperName : preferredDeveloperNames) {
            for (RecordType recordTypeRow : personAccountRecordTypes) {
                if (recordTypeRow.DeveloperName == preferredDeveloperName) {
                    cachedWardenPersonAccountRecordTypeId = recordTypeRow.Id;
                    return cachedWardenPersonAccountRecordTypeId;
                }
            }
        }

        cachedWardenPersonAccountRecordTypeId = personAccountRecordTypes[0].Id;
        return cachedWardenPersonAccountRecordTypeId;
    }

    private static Integer resolveBuildingFloorCount(Ken_Building__c buildingRow) {
        if (buildingRow == null) {
            return 0;
        }
        Integer count = toWholeNumber(buildingRow.Number_Of_Floors__c);
        if (count > 0) {
            return count;
        }
        return toWholeNumber(buildingRow.Total_Floors__c);
    }

    private static Integer toPositiveInteger(String value, String errorMessage) {
        String cleaned = sanitize(value);
        if (!isPositiveWholeNumber(cleaned)) {
            throw new AuraHandledException(errorMessage);
        }
        return Integer.valueOf(cleaned);
    }

    private static String normalizeFloorWardenAssignmentType(String assignmentType) {
        String cleaned = sanitize(assignmentType);
        if (String.isBlank(cleaned)) {
            return null;
        }

        String normalized = cleaned.toLowerCase().replace('-', ' ').replaceAll('\\s+', ' ').trim();
        if (normalized == 'building warden' || normalized == 'building level') {
            return 'Building Warden';
        }
        if (normalized == 'floor warden' || normalized == 'per floor') {
            return 'Floor Warden';
        }
        return cleaned;
    }

    private static Boolean isPositiveWholeNumber(String value) {
        String cleaned = sanitize(value);
        return String.isNotBlank(cleaned) && Pattern.matches('^[1-9][0-9]*$', cleaned);
    }

    private static Id resolveWardenId(String rawWardenInput) {
        String cleaned = sanitize(rawWardenInput);
        if (String.isBlank(cleaned)) {
            return null;
        }

        try {
            return (Id) cleaned;
        } catch (Exception e) {
            // Continue with name-based lookup fallback.
        }
        if (!Schema.sObjectType.Account.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view accounts.');
        }

        List<Account> matches = [
            SELECT Id
            FROM Account
            WHERE Name = :cleaned
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return matches.isEmpty() ? null : matches[0].Id;
    }

    private static Integer countAmenities(String amenities) {
        if (String.isBlank(amenities)) {
            return 0;
        }

        Integer count = 0;
        for (String item : amenities.split(';')) {
            if (String.isNotBlank(item)) {
                count++;
            }
        }
        return count;
    }

    private static String getCustomAmenitiesFromRoomCategory(Ken_Room_Category__c roomCategory) {
        if (roomCategory == null) {
            return null;
        }
        Map<String, Schema.SObjectField> fieldMap = Ken_Room_Category__c.SObjectType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey('Custom_Amenity__c')) {
            return null;
        }
        Object value = roomCategory.get('Custom_Amenity__c');
        return value == null ? null : String.valueOf(value);
    }

    private static String combineAmenities(String standardAmenities, String customAmenities) {
        if (String.isBlank(standardAmenities)) {
            return customAmenities;
        }
        if (String.isBlank(customAmenities)) {
            return standardAmenities;
        }
        return standardAmenities + ';' + customAmenities;
    }

    private static List<String> parseAmenities(String amenities) {
        List<String> items = new List<String>();
        if (String.isBlank(amenities)) {
            return items;
        }
        for (String item : amenities.split(';')) {
            String cleaned = sanitize(item);
            if (String.isNotBlank(cleaned)) {
                items.add(cleaned);
            }
        }
        return items;
    }

    private static String firstNonBlank(List<String> values) {
        if (values == null) {
            return null;
        }
        for (String value : values) {
            if (String.isNotBlank(value)) {
                return value;
            }
        }
        return null;
    }

    private static String sanitize(String value) {
        return String.isBlank(value) ? null : value.trim();
    }

    private static List<String> normalizeAmenities(List<String> amenities) {
        List<String> normalized = new List<String>();
        if (amenities == null) {
            return normalized;
        }

        for (String item : amenities) {
            String cleaned = sanitize(item);
            if (String.isNotBlank(cleaned)) {
                normalized.add(cleaned);
            }
        }
        return normalized;
    }

    private static Id toId(String rawId) {
        if (String.isBlank(rawId)) {
            return null;
        }
        try {
            return (Id) rawId.trim();
        } catch (Exception e) {
            throw new AuraHandledException('Invalid Fee Type value.');
        }
    }

    private static Set<String> getAmenityPicklistValueSet() {
        Set<String> values = new Set<String>();
        for (Schema.PicklistEntry entry : Ken_Room_Category__c.Amenities__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                values.add(entry.getValue());
            }
        }
        return values;
    }

    private static Boolean containsOptionValue(List<OptionItem> options, String value) {
        if (options == null) {
            return false;
        }
        for (OptionItem item : options) {
            if (item != null && item.value == value) {
                return true;
            }
        }
        return false;
    }

    private static List<String> fetchCustomAmenityNames() {
        List<String> names = new List<String>();
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey('Custom_Amenity__c')) {
            return names;
        }
        if (!globalDescribe.get('Custom_Amenity__c').getDescribe().isAccessible()) {
            return names;
        }

        List<SObject> records = Database.query('SELECT Id, Name FROM Custom_Amenity__c ORDER BY Name ASC LIMIT 500');
        for (SObject record : records) {
            String nameValue = (String) record.get('Name');
            if (String.isNotBlank(nameValue)) {
                names.add(nameValue);
            }
        }
        return names;
    }

    private static void upsertCustomAmenities(List<String> customAmenityNames, Id roomCategoryId) {
        if (customAmenityNames == null || customAmenityNames.isEmpty()) {
            return;
        }

        for (String amenityName : customAmenityNames) {
            createCustomAmenityRecord(amenityName, roomCategoryId);
        }
    }

    private static void createCustomAmenityRecord(String amenityName, Id roomCategoryId) {
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey('Custom_Amenity__c')) {
            return;
        }

        Schema.SObjectType amenityType = globalDescribe.get('Custom_Amenity__c');
        Map<String, Schema.SObjectField> fieldMap = amenityType.getDescribe().fields.getMap();
        SObject amenityRecord = amenityType.newSObject();
        Boolean hasWritableName = false;

        if (fieldMap.containsKey('Name__c') && fieldMap.get('Name__c').getDescribe().isCreateable()) {
            amenityRecord.put('Name__c', amenityName);
            hasWritableName = true;
        } else if (fieldMap.containsKey('Amenity_Name__c') && fieldMap.get('Amenity_Name__c').getDescribe().isCreateable()) {
            amenityRecord.put('Amenity_Name__c', amenityName);
            hasWritableName = true;
        } else if (fieldMap.containsKey('Name') && fieldMap.get('Name').getDescribe().isCreateable()) {
            amenityRecord.put('Name', amenityName);
            hasWritableName = true;
        }

        if (!hasWritableName) {
            return;
        }
        if (!amenityType.getDescribe().isCreateable()) {
            return;
        }

        if (roomCategoryId != null) {
            if (fieldMap.containsKey('Ken_Room_Category__c') && fieldMap.get('Ken_Room_Category__c').getDescribe().isCreateable()) {
                amenityRecord.put('Ken_Room_Category__c', roomCategoryId);
            } else if (fieldMap.containsKey('Room_Category__c') && fieldMap.get('Room_Category__c').getDescribe().isCreateable()) {
                amenityRecord.put('Room_Category__c', roomCategoryId);
            } else if (fieldMap.containsKey('Housing_Category__c') && fieldMap.get('Housing_Category__c').getDescribe().isCreateable()) {
                amenityRecord.put('Housing_Category__c', roomCategoryId);
            }
        }

        insert amenityRecord; // NOPMD ApexCRUDViolation - create permission is validated dynamically because the custom object may not exist in every org.
    } 
}