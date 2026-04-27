public with sharing class KenBuildingController {
    @AuraEnabled
    public static List<MasterDataRoomCategoryController.BuildingRow> getBuildings(String statusFilter) {
        return MasterDataRoomCategoryController.getBuildings(statusFilter);
    }

    @AuraEnabled
    public static MasterDataRoomCategoryController.BuildingRow getBuildingDetail(String buildingId, String buildingName) {
        return MasterDataRoomCategoryController.getBuildingDetail(buildingId, buildingName);
    }

    @AuraEnabled(cacheable=true)
    public static MasterDataRoomCategoryController.BuildingFormOptions getBuildingFormOptions() {
        return MasterDataRoomCategoryController.getBuildingFormOptions();
    }

    @AuraEnabled
    public static Id createBuilding(MasterDataRoomCategoryController.CreateBuildingRequest inputRequest) {
        return MasterDataRoomCategoryController.createBuilding(inputRequest);
    }

    @AuraEnabled
    public static Id updateBuilding(String buildingId, MasterDataRoomCategoryController.CreateBuildingRequest inputRequest) {
        return MasterDataRoomCategoryController.updateBuilding(buildingId, inputRequest);
    }

    @AuraEnabled
    public static void deleteBuilding(String buildingId) {
        MasterDataRoomCategoryController.deleteBuilding(buildingId);
    }

    @AuraEnabled
    public static List<MasterDataRoomCategoryController.BuildingFloorWardenRow> getBuildingFloorWardenDetails(String buildingId) {
        return MasterDataRoomCategoryController.getBuildingFloorWardenDetails(buildingId);
    }

    @AuraEnabled
    public static Id createFloorWarden(MasterDataRoomCategoryController.CreateFloorWardenRequest inputRequest) {
        return MasterDataRoomCategoryController.createFloorWarden(inputRequest);
    }

    @AuraEnabled
    public static MasterDataRoomCategoryController.BuildingActivityHistoryRow getBuildingActivityHistory(String buildingId) {
        return MasterDataRoomCategoryController.getBuildingActivityHistory(buildingId);
    }
}