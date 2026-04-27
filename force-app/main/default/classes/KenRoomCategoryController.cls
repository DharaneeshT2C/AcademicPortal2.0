public with sharing class KenRoomCategoryController {
    @AuraEnabled
    public static List<MasterDataRoomCategoryController.RoomCategoryRow> getRoomCategories(String statusFilter) {
        return MasterDataRoomCategoryController.getRoomCategories(statusFilter);
    }

    @AuraEnabled
    public static List<MasterDataRoomCategoryController.RoomRow> getLinkedRoomsByCategory(String categoryId) {
        return MasterDataRoomCategoryController.getLinkedRoomsByCategory(categoryId);
    }

    @AuraEnabled
    public static MasterDataRoomCategoryController.RoomCategoryActivityHistoryRow getRoomCategoryActivityHistory(String categoryId) {
        return MasterDataRoomCategoryController.getRoomCategoryActivityHistory(categoryId);
    }

    @AuraEnabled(cacheable=true)
    public static MasterDataRoomCategoryController.RoomCategoryFormOptions getRoomCategoryFormOptions() {
        return MasterDataRoomCategoryController.getRoomCategoryFormOptions();
    }

    @AuraEnabled
    public static Id createRoomCategory(MasterDataRoomCategoryController.CreateRoomCategoryRequest inputRequest) {
        return MasterDataRoomCategoryController.createRoomCategory(inputRequest);
    }

    @AuraEnabled
    public static Id updateRoomCategory(String roomCategoryId, MasterDataRoomCategoryController.CreateRoomCategoryRequest inputRequest) {
        return MasterDataRoomCategoryController.updateRoomCategory(roomCategoryId, inputRequest);
    }

    @AuraEnabled
    public static void deleteRoomCategory(String roomCategoryId) {
        MasterDataRoomCategoryController.deleteRoomCategory(roomCategoryId);
    }

    @AuraEnabled
    public static MasterDataRoomCategoryController.OptionItem addCustomAmenity(String amenityName) {
        return MasterDataRoomCategoryController.addCustomAmenity(amenityName);
    }

    @AuraEnabled
    public static MasterDataRoomCategoryController.RoomCategoryRow getRoomCategoryDetail(String categoryId, String categoryName) {
        return MasterDataRoomCategoryController.getRoomCategoryDetail(categoryId, categoryName);
    }
}