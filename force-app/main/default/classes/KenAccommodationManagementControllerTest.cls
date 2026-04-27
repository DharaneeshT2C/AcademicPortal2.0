@IsTest
private class KenAccommodationManagementControllerTest {
    @IsTest
    static void testCycleWindowOptionsAndAutoAllotmentConfig() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'accmgmt1',
            false,
            false
        );

        List<KenAccommodationManagementController.OptionItem> cycleOptions =
            KenAccommodationManagementController.getCycleOptions();
        List<KenAccommodationManagementController.WindowItem> windowOptions =
            KenAccommodationManagementController.getWindowOptions(String.valueOf(context.cycle.Id));

        System.assertEquals(true, !cycleOptions.isEmpty(), 'Cycle options should include created cycle.');
        System.assertEquals(1, windowOptions.size(), 'One window should be returned for the created cycle.');

        Test.startTest();
        KenAccommodationManagementController.saveWindowAutoAllotmentConfig(
            String.valueOf(context.window.Id),
            'yearPriority',
            true,
            25,
            'category',
            true
        );
        Test.stopTest();

        Ken_Windows__c updatedWindow = [
            SELECT Auto_Allotment_Allocation_Rule__c,
                   Auto_Allotment_Batch_Processing__c,
                   Auto_Allotment_Batch_Size__c,
                   Auto_Allotment_Batch_Grouping__c,
                   Auto_Allotment_Carry_Forward__c
            FROM Ken_Windows__c
            WHERE Id = :context.window.Id
            LIMIT 1
        ];
        System.assertEquals('yearPriority', updatedWindow.Auto_Allotment_Allocation_Rule__c);
        System.assertEquals(true, updatedWindow.Auto_Allotment_Batch_Processing__c);
        System.assertEquals(25, Integer.valueOf(updatedWindow.Auto_Allotment_Batch_Size__c));
        System.assertEquals('category', updatedWindow.Auto_Allotment_Batch_Grouping__c);
        System.assertEquals(true, updatedWindow.Auto_Allotment_Carry_Forward__c);
    }

    @IsTest
    static void testGetInProgressRowsReturnsPendingRequest() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'accmgmt2',
            false,
            false
        );
        KenHostelTestHelper.createRoomRequest(
            context.studentAccount.Id,
            context.studentContact.Id,
            context.window.Id,
            context.roomCategory.Id,
            context.roomCategory.Name__c,
            1,
            'Pending'
        );

        Test.startTest();
        List<KenAccommodationManagementController.InProgressRow> rows =
            KenAccommodationManagementController.getInProgressRows(String.valueOf(context.window.Id));
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Pending request should show in progress.');
        System.assertEquals(context.studentAccount.Name, rows[0].student);
        System.assertEquals('Pending', rows[0].status);
        System.assertEquals(context.roomCategory.Name__c, rows[0].category);
    }

    @IsTest
    static void testRejectApplicationStoresRejectedReason() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'accmgmtrej',
            false,
            false
        );
        Ken_Room_Request__c requestRow = KenHostelTestHelper.createRoomRequest(
            context.studentAccount.Id,
            context.studentContact.Id,
            context.window.Id,
            context.roomCategory.Id,
            context.roomCategory.Name__c,
            1,
            'Pending'
        );

        Test.startTest();
        KenAccommodationManagementController.rejectApplication(
            String.valueOf(requestRow.Id),
            'Documents were not verified.'
        );
        List<KenAccommodationManagementController.InProgressRow> rows =
            KenAccommodationManagementController.getInProgressRows(String.valueOf(context.window.Id));
        Test.stopTest();

        Ken_Room_Request__c rejectedRequest = [
            SELECT Status__c, Rejected_Reason__c, Room_Allotment__c
            FROM Ken_Room_Request__c
            WHERE Id = :requestRow.Id
            LIMIT 1
        ];

        System.assertEquals('Rejected', rejectedRequest.Status__c);
        System.assertEquals('Documents were not verified.', rejectedRequest.Rejected_Reason__c);
        System.assertEquals(null, rejectedRequest.Room_Allotment__c);
        System.assertEquals(0, rows.size(), 'Rejected requests should not remain in progress.');
    }

    @IsTest
    static void testAssignRoomToAllotmentReassignsExistingAllocation() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'accmgmt3',
            true,
            false
        );
        Ken_Room__c targetRoom = KenHostelTestHelper.createRoom(
            context.building.Id,
            context.floor.Id,
            context.roomCategory.Id,
            2,
            'R' + Math.abs(Crypto.getRandomInteger()),
            context.roomCategory.Name__c
        );

        Ken_Room_Allotment__c existingAllotment = [
            SELECT Id, Room__c
            FROM Ken_Room_Allotment__c
            WHERE Tenant_Account__c = :context.studentAccount.Id
                AND Active__c = true
            LIMIT 1
        ];
        System.assertNotEquals(targetRoom.Id, existingAllotment.Room__c, 'Test setup should use a different target room.');

        Test.startTest();
        String returnedAllotmentId = KenAccommodationManagementController.assignRoomToAllotment(
            String.valueOf(existingAllotment.Id),
            String.valueOf(targetRoom.Id),
            String.valueOf(context.window.Id),
            'Provisional Allotment'
        );
        List<KenAccommodationManagementController.AllocatedRow> allocatedRows =
            KenAccommodationManagementController.getAllocatedRows(String.valueOf(context.window.Id));
        Test.stopTest();

        Ken_Room_Allotment__c updatedAllotment = [
            SELECT Id, Room__c, Allotment_Type__c, Room__r.Name, Room__r.Room_Number__c
            FROM Ken_Room_Allotment__c
            WHERE Id = :returnedAllotmentId
            LIMIT 1
        ];
        Ken_Room_Allotment__c priorAllotment = [
            SELECT Id, Active__c
            FROM Ken_Room_Allotment__c
            WHERE Id = :existingAllotment.Id
            LIMIT 1
        ];
        System.assertNotEquals(existingAllotment.Id, (Id) returnedAllotmentId);
        System.assertEquals(targetRoom.Id, updatedAllotment.Room__c);
        System.assertEquals('Provisional Allotment', updatedAllotment.Allotment_Type__c);
        System.assertEquals(false, priorAllotment.Active__c);
        if (Schema.sObjectType.Ken_Room_Allotment__c.fields.getMap().containsKey('Reassigned__c')) {
            Set<Id> reassignmentIds = new Set<Id>{ existingAllotment.Id, (Id) returnedAllotmentId };
            List<SObject> reassignmentRows = Database.query(
                'SELECT Id, Reassigned__c FROM Ken_Room_Allotment__c WHERE Id IN :reassignmentIds'
            );
            Map<Id, Boolean> reassignedById = new Map<Id, Boolean>();
            for (SObject row : reassignmentRows) {
                reassignedById.put((Id) row.get('Id'), (Boolean) row.get('Reassigned__c'));
            }
            System.assertEquals(true, reassignedById.get(existingAllotment.Id), 'Old allotted record should be flagged as reassigned.');
            System.assertEquals(true, reassignedById.get((Id) returnedAllotmentId), 'New active reassigned record should also be flagged.');
        }

        System.assertEquals(1, allocatedRows.size(), 'Window should still show one allocated row.');
        System.assertEquals(returnedAllotmentId, allocatedRows[0].id);
        System.assertEquals(
            String.isNotBlank(updatedAllotment.Room__r.Name)
                ? updatedAllotment.Room__r.Name
                : updatedAllotment.Room__r.Room_Number__c,
            allocatedRows[0].room
        );
    }

    @IsTest
    static void testRequestAssignmentAndInProgressDetailFlow() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'accmgmtreq',
            false,
            false
        );
        Ken_Room_Request__c requestRow = KenHostelTestHelper.createRoomRequest(
            context.studentAccount.Id,
            context.studentContact.Id,
            context.window.Id,
            context.roomCategory.Id,
            context.roomCategory.Name__c,
            1,
            'Pending'
        );
        Ken_Room__c targetRoom = KenHostelTestHelper.createRoom(
            context.building.Id,
            context.floor.Id,
            context.roomCategory.Id,
            2,
            'R' + Math.abs(Crypto.getRandomInteger()),
            context.roomCategory.Name__c
        );

        Test.startTest();
        KenAccommodationManagementController.ApplicationDetailResponse detail =
            KenAccommodationManagementController.getInProgressApplicationDetail(
                String.valueOf(requestRow.Id),
                String.valueOf(context.window.Id)
            );
        List<KenAccommodationManagementController.RoomAssignmentOption> options =
            KenAccommodationManagementController.getAssignableRooms(
                String.valueOf(requestRow.Id),
                String.valueOf(context.window.Id)
            );
        String assignedAllotmentId = KenAccommodationManagementController.assignRoomToAllotment(
            String.valueOf(requestRow.Id),
            String.valueOf(targetRoom.Id),
            String.valueOf(context.window.Id),
            'Provisional Allotment'
        );
        Test.stopTest();

        Ken_Room_Request__c updatedRequest = [
            SELECT Room_Allotment__c, Status__c
            FROM Ken_Room_Request__c
            WHERE Id = :requestRow.Id
            LIMIT 1
        ];
        Ken_Room_Allotment__c createdAllotment = [
            SELECT Id, Room__c, Active__c, Allotment_Type__c
            FROM Ken_Room_Allotment__c
            WHERE Id = :assignedAllotmentId
            LIMIT 1
        ];
        Boolean foundTargetRoomOption = false;
        for (KenAccommodationManagementController.RoomAssignmentOption option : options) {
            if (option.id == String.valueOf(targetRoom.Id)) {
                foundTargetRoomOption = true;
                break;
            }
        }

        System.assertEquals(String.valueOf(requestRow.Id), detail.allotmentId);
        System.assertEquals(context.studentAccount.Name, detail.studentName);
        System.assertEquals('Preference Selected', detail.allotmentType);
        System.assertEquals(context.roomCategory.Name__c, detail.categoryApplied);
        System.assertEquals('Pending', detail.applicationStatus);
        System.assertEquals(true, options.size() > 0, 'Assignable rooms should be returned for the request.');
        System.assertEquals(true, foundTargetRoomOption, 'Assignable rooms should include the selected target room.');
        System.assertEquals('Alloted', updatedRequest.Status__c);
        System.assertEquals(assignedAllotmentId, String.valueOf(updatedRequest.Room_Allotment__c));
        System.assertEquals(targetRoom.Id, createdAllotment.Room__c);
        System.assertEquals(true, createdAllotment.Active__c);
        System.assertEquals('Provisional Allotment', createdAllotment.Allotment_Type__c);
    }

    @IsTest
    static void testAllocatedDetailAssignableRoomsAndCancelReopensRequest() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'accmgmtcan',
            true,
            false
        );
        Ken_Room_Allotment__c activeAllotment = [
            SELECT Id, Room__c, Room__r.Name, Room__r.Room_Number__c, Allotment_Type__c
            FROM Ken_Room_Allotment__c
            WHERE Tenant_Account__c = :context.studentAccount.Id
                AND Active__c = true
            LIMIT 1
        ];
        Ken_Room_Request__c linkedRequest = new Ken_Room_Request__c(
            Request_By__c = context.studentAccount.Id,
            Requested_By__c = context.studentContact.Id,
            Window__c = context.window.Id,
            Room_Allotment__c = activeAllotment.Id,
            Status__c = 'Alloted',
            Preference_1__c = context.roomCategory.Id,
            Floor_Preference_1__c = KenHostelTestHelper.toFloorLabel(1)
        );
        insert linkedRequest;
        Ken_Room__c alternateRoom = KenHostelTestHelper.createRoom(
            context.building.Id,
            context.floor.Id,
            context.roomCategory.Id,
            2,
            'R' + Math.abs(Crypto.getRandomInteger()),
            context.roomCategory.Name__c
        );

        Test.startTest();
        KenAccommodationManagementController.AllocationDetailResponse detail =
            KenAccommodationManagementController.getAllocatedDetail(
                String.valueOf(activeAllotment.Id),
                String.valueOf(context.window.Id)
            );
        List<KenAccommodationManagementController.RoomAssignmentOption> options =
            KenAccommodationManagementController.getAssignableRooms(
                String.valueOf(activeAllotment.Id),
                String.valueOf(context.window.Id)
            );
        KenAccommodationManagementController.cancelAllocation(
            String.valueOf(activeAllotment.Id),
            String.valueOf(context.window.Id)
        );
        KenAccommodationManagementController.ApplicationDetailResponse reopenedDetail =
            KenAccommodationManagementController.getInProgressApplicationDetail(
                String.valueOf(activeAllotment.Id),
                String.valueOf(context.window.Id)
            );
        List<KenAccommodationManagementController.InProgressRow> inProgressRows =
            KenAccommodationManagementController.getInProgressRows(String.valueOf(context.window.Id));
        Test.stopTest();

        Ken_Room_Allotment__c cancelledAllotment = [
            SELECT Id, Active__c, Allotment_Type__c
            FROM Ken_Room_Allotment__c
            WHERE Id = :activeAllotment.Id
            LIMIT 1
        ];
        Ken_Room_Request__c reopenedRequest = [
            SELECT Room_Allotment__c, Status__c
            FROM Ken_Room_Request__c
            WHERE Id = :linkedRequest.Id
            LIMIT 1
        ];
        Boolean foundAlternateRoomOption = false;
        for (KenAccommodationManagementController.RoomAssignmentOption option : options) {
            if (option.id == String.valueOf(alternateRoom.Id)) {
                foundAlternateRoomOption = true;
                break;
            }
        }

        System.assertEquals(String.valueOf(activeAllotment.Id), detail.allotmentId);
        System.assertEquals(context.studentAccount.Name, detail.studentName);
        System.assertEquals(
            String.isNotBlank(activeAllotment.Room__r.Name)
                ? activeAllotment.Room__r.Name
                : activeAllotment.Room__r.Room_Number__c,
            detail.roomNumber
        );
        System.assertEquals(true, options.size() >= 2, 'Assignable rooms should include the current and alternate rooms.');
        System.assertEquals(true, foundAlternateRoomOption, 'Assignable rooms should include the alternate room.');
        System.assertEquals(false, cancelledAllotment.Active__c);
        System.assertEquals('Preference Selected', cancelledAllotment.Allotment_Type__c);
        System.assertEquals(null, reopenedRequest.Room_Allotment__c);
        System.assertEquals('Pending', reopenedRequest.Status__c);
        System.assertEquals(String.valueOf(activeAllotment.Id), reopenedDetail.allotmentId);
        System.assertEquals('Pending', reopenedDetail.applicationStatus);
        System.assertEquals(1, inProgressRows.size(), 'Cancelled allocation should move the linked request back to in-progress.');
    }

    @IsTest
    static void testCancelledAllocationShowsInProgressForNonPreferenceWindow() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'accmgmtdir',
            true,
            false
        );
        update new Ken_Windows__c(
            Id = context.window.Id,
            Allotment_Type__c = 'Direct Allotment',
            Enable_Room_Preference__c = false
        );

        Ken_Room_Allotment__c activeAllotment = [
            SELECT Id, Room__c, Allotment_Type__c
            FROM Ken_Room_Allotment__c
            WHERE Tenant_Account__c = :context.studentAccount.Id
                AND Active__c = true
            LIMIT 1
        ];

        Test.startTest();
        KenAccommodationManagementController.cancelAllocation(
            String.valueOf(activeAllotment.Id),
            String.valueOf(context.window.Id)
        );
        List<KenAccommodationManagementController.InProgressRow> rows =
            KenAccommodationManagementController.getInProgressRows(String.valueOf(context.window.Id));
        KenAccommodationManagementController.ApplicationDetailResponse detail =
            KenAccommodationManagementController.getInProgressApplicationDetail(
                String.valueOf(activeAllotment.Id),
                String.valueOf(context.window.Id)
            );
        Test.stopTest();

        Ken_Room_Allotment__c cancelledAllotment = [
            SELECT Id, Active__c, Room__c
            FROM Ken_Room_Allotment__c
            WHERE Id = :activeAllotment.Id
            LIMIT 1
        ];

        System.assertEquals(false, cancelledAllotment.Active__c);
        System.assertEquals(1, rows.size(), 'Inactive allotment should be shown in-progress for non-preference windows.');
        System.assertEquals(String.valueOf(activeAllotment.Id), rows[0].id);
        System.assertEquals(context.studentAccount.Name, rows[0].student);
        System.assertEquals(String.valueOf(activeAllotment.Id), detail.allotmentId);
        System.assertEquals(context.studentAccount.Name, detail.studentName);
        System.assertEquals(context.roomCategory.Name__c, detail.categoryApplied);
    }

    @IsTest
    static void testAllocatedRowsPreferRoomCategoryLabelOverHousingCategory() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'accmgmtcat',
            false,
            false
        );
        Ken_Building__c scopedBuilding = KenHostelTestHelper.createBuildingDirect('Accommodation Category Building', 1);
        Floor__c scopedFloor = KenHostelTestHelper.createFloor(scopedBuilding.Id, 1);
        Ken_Room_Category__c scopedCategory = KenHostelTestHelper.createRoomCategory(
            'Accommodation Category Label',
            2
        );
        String windowAllotmentType = KenHostelTestHelper.getPicklistValue(
            Ken_Windows__c.Allotment_Type__c,
            'Direct Allotment'
        );
        String allotmentType = KenHostelTestHelper.getPicklistValue(
            Ken_Room_Allotment__c.Allotment_Type__c,
            'Direct Allotment'
        );
        Ken_Windows__c scopedWindow = KenHostelTestHelper.createWindowDirect(
            context.cycle.Id,
            null,
            scopedBuilding.Id,
            scopedCategory.Id,
            'Accommodation Category Window',
            windowAllotmentType,
            false
        );
        Ken_Room__c scopedRoom = KenHostelTestHelper.createRoom(
            scopedBuilding.Id,
            scopedFloor.Id,
            scopedCategory.Id,
            2,
            'ACC-CAT-' + Math.abs(Crypto.getRandomInteger()),
            'Different Housing Label'
        );
        Ken_Room_Allotment__c allotment = KenHostelTestHelper.createRoomAllotment(
            scopedRoom.Id,
            context.studentAccount.Id,
            context.studentContact.Id,
            scopedWindow.Id,
            null,
            true
        );
        update new Ken_Room_Allotment__c(
            Id = allotment.Id,
            Allotment_Type__c = allotmentType
        );

        Test.startTest();
        List<KenAccommodationManagementController.AllocatedRow> rows =
            KenAccommodationManagementController.getAllocatedRows(String.valueOf(scopedWindow.Id));
        KenAccommodationManagementController.AllocationDetailResponse detail =
            KenAccommodationManagementController.getAllocatedDetail(
                String.valueOf(allotment.Id),
                String.valueOf(scopedWindow.Id)
            );
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Only the scoped allocation should be returned.');
        System.assertEquals(
            scopedCategory.Name__c,
            rows[0].category,
            'Allocated rows should use the room category label.'
        );
        System.assertEquals(
            scopedCategory.Name__c,
            detail.category,
            'Allocated detail should use the room category label.'
        );
        System.assertNotEquals(
            'Different Housing Label',
            rows[0].category,
            'Housing category should not override the room category label.'
        );
    }

    @IsTest
    static void testAssignRoomToAllotmentReturnsSameRecordWhenRoomDoesNotChange() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'accmgmtsame',
            true,
            false
        );
        Ken_Room_Allotment__c activeAllotment = [
            SELECT Id, Room__c
            FROM Ken_Room_Allotment__c
            WHERE Tenant_Account__c = :context.studentAccount.Id
                AND Active__c = true
            LIMIT 1
        ];

        Test.startTest();
        String returnedAllotmentId = KenAccommodationManagementController.assignRoomToAllotment(
            String.valueOf(activeAllotment.Id),
            String.valueOf(activeAllotment.Room__c),
            String.valueOf(context.window.Id),
            'Provisional Allotment'
        );
        Test.stopTest();

        Integer activeAllotmentCount = [
            SELECT COUNT()
            FROM Ken_Room_Allotment__c
            WHERE Tenant_Account__c = :context.studentAccount.Id
                AND Active__c = true
        ];

        System.assertEquals(String.valueOf(activeAllotment.Id), returnedAllotmentId);
        System.assertEquals(1, activeAllotmentCount, 'Reassigning to the same room should not create a new allotment.');
    }

    @IsTest
    static void testLinkedRequestReassignmentAndRejectByAllotment() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'accmgmtlnk',
            true,
            false
        );
        Ken_Room_Allotment__c activeAllotment = [
            SELECT Id, Room__c
            FROM Ken_Room_Allotment__c
            WHERE Tenant_Account__c = :context.studentAccount.Id
                AND Active__c = true
            LIMIT 1
        ];
        Ken_Room_Request__c linkedRequest = new Ken_Room_Request__c(
            Request_By__c = context.studentAccount.Id,
            Requested_By__c = context.studentContact.Id,
            Window__c = context.window.Id,
            Room_Allotment__c = activeAllotment.Id,
            Status__c = 'Alloted',
            Preference_1__c = context.roomCategory.Id,
            Floor_Preference_1__c = KenHostelTestHelper.toFloorLabel(1)
        );
        insert linkedRequest;
        Ken_Room__c replacementRoom = KenHostelTestHelper.createRoom(
            context.building.Id,
            context.floor.Id,
            context.roomCategory.Id,
            2,
            'R' + Math.abs(Crypto.getRandomInteger()),
            context.roomCategory.Name__c
        );

        Test.startTest();
        String reassignedAllotmentId = KenAccommodationManagementController.assignRoomToAllotment(
            String.valueOf(linkedRequest.Id),
            String.valueOf(replacementRoom.Id),
            String.valueOf(context.window.Id),
            'Confirmed Allotment'
        );
        KenAccommodationManagementController.rejectApplication(
            reassignedAllotmentId,
            'Manual rejection'
        );
        Test.stopTest();

        Ken_Room_Allotment__c oldAllotment = [
            SELECT Id, Active__c
            FROM Ken_Room_Allotment__c
            WHERE Id = :activeAllotment.Id
            LIMIT 1
        ];
        Ken_Room_Allotment__c reassignedAllotment = [
            SELECT Id, Room__c, Active__c, Allotment_Type__c
            FROM Ken_Room_Allotment__c
            WHERE Id = :reassignedAllotmentId
            LIMIT 1
        ];
        Ken_Room_Request__c rejectedRequest = [
            SELECT Room_Allotment__c, Status__c, Rejected_Reason__c
            FROM Ken_Room_Request__c
            WHERE Id = :linkedRequest.Id
            LIMIT 1
        ];

        System.assertEquals(false, oldAllotment.Active__c);
        System.assertEquals(replacementRoom.Id, reassignedAllotment.Room__c);
        System.assertEquals(true, reassignedAllotment.Active__c);
        System.assertEquals('Confirmed Allotment', reassignedAllotment.Allotment_Type__c);
        System.assertEquals(null, rejectedRequest.Room_Allotment__c);
        System.assertEquals('Rejected', rejectedRequest.Status__c);
        System.assertEquals('Manual rejection', rejectedRequest.Rejected_Reason__c);
    }

    @IsTest
    static void testInProgressDetailSupportsRoommateAndMultiplePreferences() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'accmgmtpref',
            false,
            true
        );
        Ken_Room_Category__c secondCategory = KenHostelTestHelper.createRoomCategory('Category 2 accmgmtpref', 2);
        Ken_Room_Category__c thirdCategory = KenHostelTestHelper.createRoomCategory('Category 3 accmgmtpref', 2);
        insert new List<Ken_Window_Room_Category__c>{
            new Ken_Window_Room_Category__c(Windows__c = context.window.Id, Room_Category__c = secondCategory.Id),
            new Ken_Window_Room_Category__c(Windows__c = context.window.Id, Room_Category__c = thirdCategory.Id)
        };
        KenHostelTestHelper.createRoom(
            context.building.Id,
            context.floor.Id,
            secondCategory.Id,
            2,
            'R' + Math.abs(Crypto.getRandomInteger()),
            secondCategory.Name__c
        );
        KenHostelTestHelper.createRoom(
            context.building.Id,
            context.floor.Id,
            thirdCategory.Id,
            2,
            'R' + Math.abs(Crypto.getRandomInteger()),
            thirdCategory.Name__c
        );

        Account preferredPartner = KenHostelTestHelper.createPersonAccount(
            'Partner',
            'accmgmtpref',
            'partner_accmgmtpref@example.com',
            'Student'
        );
        Ken_Room_Request__c partnerRequest = KenHostelTestHelper.createRoomRequest(
            preferredPartner.Id,
            preferredPartner.PersonContactId,
            context.window.Id,
            context.roomCategory.Id,
            context.roomCategory.Name__c,
            1,
            'Pending'
        );
        partnerRequest.Preferred_Partner__c = context.studentAccount.Id;
        partnerRequest.Preference_2__c = secondCategory.Id;
        update partnerRequest;

        Ken_Room_Request__c requestRow = KenHostelTestHelper.createRoomRequest(
            context.studentAccount.Id,
            context.studentContact.Id,
            context.window.Id,
            context.roomCategory.Id,
            context.roomCategory.Name__c,
            1,
            'Pending'
        );
        requestRow.Preferred_Partner__c = preferredPartner.Id;
        requestRow.Preference_2__c = secondCategory.Id;
        requestRow.Preference_3__c = thirdCategory.Id;
        update requestRow;

        Test.startTest();
        KenAccommodationManagementController.ApplicationDetailResponse detail =
            KenAccommodationManagementController.getInProgressApplicationDetail(
                String.valueOf(requestRow.Id),
                String.valueOf(context.window.Id)
            );
        List<KenAccommodationManagementController.RoomAssignmentOption> options =
            KenAccommodationManagementController.getAssignableRooms(
                String.valueOf(requestRow.Id),
                String.valueOf(context.window.Id)
            );
        Test.stopTest();

        Boolean foundRoommateMatch = false;
        for (KenAccommodationManagementController.RoomAssignmentOption option : options) {
            if (option.roommateMatch == true) {
                foundRoommateMatch = true;
                break;
            }
        }

        System.assertEquals(3, detail.roomPreferences.size(), 'Three room preferences should be returned.');
        System.assertEquals(preferredPartner.Name, detail.roommatePreference.name);
        System.assertEquals('Mutual Match', detail.roommatePreference.matchLabel);
        System.assertEquals('Yes', detail.roommatePreference.samePreferenceSelected);
        System.assertEquals(true, foundRoommateMatch, 'Assignable rooms should include a roommate match option.');
    }

    @IsTest
    static void testCheckoutDoesNotReturnAllocationToInProgress() {
        KenHostelTestHelper.StudentWindowContext context = KenHostelTestHelper.createStudentWindowContext(
            'accmgmt4',
            true,
            false
        );
        Ken_Room_Allotment__c activeAllotment = [
            SELECT Id, Active__c, Allotment_Type__c
            FROM Ken_Room_Allotment__c
            WHERE Tenant_Account__c = :context.studentAccount.Id
                AND Active__c = true
            LIMIT 1
        ];
        Ken_Room_Request__c linkedRequest = new Ken_Room_Request__c(
            Request_By__c = context.studentAccount.Id,
            Requested_By__c = context.studentContact.Id,
            Window__c = context.window.Id,
            Room_Allotment__c = activeAllotment.Id,
            Status__c = 'Alloted',
            Preference_1__c = context.roomCategory.Id,
            Floor_Preference_1__c = KenHostelTestHelper.toFloorLabel(1)
        );
        insert linkedRequest;

        Test.startTest();
        KenAccommodationManagementController.checkoutAllocation(
            String.valueOf(activeAllotment.Id),
            String.valueOf(context.window.Id)
        );
        List<KenAccommodationManagementController.InProgressRow> inProgressRows =
            KenAccommodationManagementController.getInProgressRows(String.valueOf(context.window.Id));
        List<KenAccommodationManagementController.AllocatedRow> allocatedRows =
            KenAccommodationManagementController.getAllocatedRows(String.valueOf(context.window.Id));
        Test.stopTest();

        Ken_Room_Allotment__c checkedOutAllotment = [
            SELECT Id, Active__c, Allotment_Type__c
            FROM Ken_Room_Allotment__c
            WHERE Id = :activeAllotment.Id
            LIMIT 1
        ];
        Ken_Room_Request__c checkedOutRequest = [
            SELECT Id, Room_Allotment__c, Status__c
            FROM Ken_Room_Request__c
            WHERE Id = :linkedRequest.Id
            LIMIT 1
        ];

        System.assertEquals(false, checkedOutAllotment.Active__c);
        System.assertEquals('Stay Completed', checkedOutAllotment.Allotment_Type__c);
        System.assertEquals(activeAllotment.Id, checkedOutRequest.Room_Allotment__c);
        System.assertEquals('Stay Completed', checkedOutRequest.Status__c);
        System.assertEquals(0, inProgressRows.size(), 'Checked out allocations should not move back to in progress.');
        System.assertEquals(0, allocatedRows.size(), 'Checked out allocations should not stay in allocated.');
    }

}