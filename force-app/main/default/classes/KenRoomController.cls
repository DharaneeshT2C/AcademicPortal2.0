public with sharing class KenRoomController {
    @AuraEnabled
    public static List<MasterDataRoomCategoryController.RoomRow> getRooms(String statusFilter) {
        return MasterDataRoomCategoryController.getRooms(statusFilter);
    }

    @AuraEnabled(cacheable=true)
    public static MasterDataRoomCategoryController.RoomFormOptions getRoomFormOptions() {
        return MasterDataRoomCategoryController.getRoomFormOptions();
    }

    @AuraEnabled
    public static MasterDataRoomCategoryController.RoomRow getRoomById(String roomId) {
        return MasterDataRoomCategoryController.getRoomById(roomId);
    }

    @AuraEnabled
    public static MasterDataRoomCategoryController.RoomOccupancyDetailsRow getRoomOccupancyDetails(String roomId) {
        return MasterDataRoomCategoryController.getRoomOccupancyDetails(roomId);
    }

    @AuraEnabled
    public static Id createRoom(MasterDataRoomCategoryController.CreateRoomRequest inputRequest) {
        return MasterDataRoomCategoryController.createRoom(inputRequest);
    }

    @AuraEnabled
    public static Id updateRoom(String roomId, MasterDataRoomCategoryController.CreateRoomRequest inputRequest) {
        return MasterDataRoomCategoryController.updateRoom(roomId, inputRequest);
    }

    @AuraEnabled
    public static void deleteRoom(String roomId) {
        MasterDataRoomCategoryController.deleteRoom(roomId);
    }

    @AuraEnabled
    public static MasterDataRoomCategoryController.BulkRoomCsvResponse bulkCreateRoomsFromCsv(
        List<MasterDataRoomCategoryController.BulkRoomCsvRow> inputRows
    ) {
        return MasterDataRoomCategoryController.bulkCreateRoomsFromCsv(inputRows);
    }
}