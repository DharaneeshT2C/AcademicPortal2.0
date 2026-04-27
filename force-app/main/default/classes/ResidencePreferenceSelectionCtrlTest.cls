// This suite keeps focused factory helpers so each scenario can cover distinct residence-selection fallbacks.
// code-analyzer-suppress(pmd:CyclomaticComplexity)
// code-analyzer-suppress(pmd:EagerlyLoadedDescribeSObjectResult)
// code-analyzer-suppress(pmd:ExcessiveParameterList)
// code-analyzer-suppress(pmd:NcssCount)
// code-analyzer-suppress(pmd:NcssMethodCount)
@IsTest
private class ResidencePreferenceSelectionCtrlTest {
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
        System.assert(!recordTypes.isEmpty(), 'A person account record type is required for residence tests.');

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

    private static User createInternalUser(String uniqueToken) {
        User currentUser = [
            SELECT LanguageLocaleKey, LocaleSidKey, TimeZoneSidKey, EmailEncodingKey
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String cleanedToken = String.isBlank(uniqueToken)
            ? String.valueOf(DateTime.now().getTime())
            : uniqueToken.replaceAll('[^A-Za-z0-9]', '').toLowerCase();
        String suffix = cleanedToken + String.valueOf(DateTime.now().getTime());
        String email = 'autouser+' + suffix + '@example.test';
        String aliasSource = 'u' + suffix;
        String aliasValue = aliasSource.length() > 8
            ? aliasSource.substring(aliasSource.length() - 8)
            : aliasSource;
        String nicknameSource = 'nick' + suffix;
        String nicknameValue = nicknameSource.length() > 40
            ? nicknameSource.substring(0, 40)
            : nicknameSource;

        User userRow = new User(
            Alias = aliasValue,
            Email = email,
            EmailEncodingKey = currentUser.EmailEncodingKey,
            LastName = 'TestUser',
            LanguageLocaleKey = currentUser.LanguageLocaleKey,
            LocaleSidKey = currentUser.LocaleSidKey,
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = currentUser.TimeZoneSidKey,
            Username = email,
            CommunityNickname = nicknameValue
        );
        insert userRow;

        return [
            SELECT Id, Email, Username, ProfileId
            FROM User
            WHERE Id = :userRow.Id
            LIMIT 1
        ];
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
            SELECT Id, Name, PersonContactId, PersonEmail, Phone
            FROM Account
            WHERE Id = :personAccount.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, reloaded.PersonContactId, 'Expected a person contact on the inserted person account.');
        return reloaded;
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
            SELECT Id, Name, Name__c, Capacity__c, Amenities__c, Active__c, Total_Price__c, Premium_Price__c, Base_Price__c
            FROM Ken_Room_Category__c
            WHERE Id = :categoryRow.Id
            LIMIT 1
        ];
    }

    private static Hostel_Cycle__c createHostelCycleDirect(String name, Id previousCycleId) {
        Hostel_Cycle__c cycleRow = new Hostel_Cycle__c(
            Name = name,
            Status__c = 'Open',
            Previous_Cycle__c = previousCycleId
        );
        insert cycleRow;
        return [
            SELECT Id, Name, Previous_Cycle__c
            FROM Hostel_Cycle__c
            WHERE Id = :cycleRow.Id
            LIMIT 1
        ];
    }

    private static Ken_Windows__c createWindowDirect(String name, Id hostelCycleId, Date startDate, Date endDate) {
        Ken_Windows__c windowRow = new Ken_Windows__c(
            Name = name,
            Allotment_Type__c = 'Preference Selected',
            Start_Date__c = startDate,
            End_Date__c = endDate,
            Enable_Room_Preference__c = true,
            Allow_Roommate_Preference__c = true,
            Hostel_Cycle__c = hostelCycleId
        );
        insert windowRow;
        return [
            SELECT Id, Name, Hostel_Cycle__c, Start_Date__c, End_Date__c
            FROM Ken_Windows__c
            WHERE Id = :windowRow.Id
            LIMIT 1
        ];
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

    private static ResidencePreferenceSelectionController.ResidenceSelectionPreferenceInput buildSelection(
        Id categoryId,
        Integer orderValue,
        List<String> roommateEmails
    ) {
        return buildSelectionRaw(String.valueOf(categoryId), orderValue, roommateEmails);
    }

    private static ResidencePreferenceSelectionController.ResidenceSelectionPreferenceInput buildSelectionRaw(
        String categoryId,
        Integer orderValue,
        List<String> roommateEmails
    ) {
        ResidencePreferenceSelectionController.ResidenceSelectionPreferenceInput inputRow =
            new ResidencePreferenceSelectionController.ResidenceSelectionPreferenceInput();
        inputRow.residenceId = categoryId;
        inputRow.order = orderValue;
        inputRow.floor = 'No Preference';
        inputRow.roommateEmails = roommateEmails;
        return inputRow;
    }

    private static Boolean containsResidence(
        List<ResidencePreferenceSelectionController.ResidenceCategoryItem> rows,
        Id categoryId
    ) {
        for (ResidencePreferenceSelectionController.ResidenceCategoryItem row : rows) {
            if (row != null && row.id == String.valueOf(categoryId)) {
                return true;
            }
        }
        return false;
    }

    private static ResidencePreferenceSelectionController.ResidenceCategoryItem findResidence(
        List<ResidencePreferenceSelectionController.ResidenceCategoryItem> rows,
        Id categoryId
    ) {
        for (ResidencePreferenceSelectionController.ResidenceCategoryItem row : rows) {
            if (row != null && row.id == String.valueOf(categoryId)) {
                return row;
            }
        }
        return null;
    }

    private static ResidencePreferenceSelectionController.ResidencePreferenceItem findPreference(
        List<ResidencePreferenceSelectionController.ResidencePreferenceItem> rows,
        Integer orderValue
    ) {
        for (ResidencePreferenceSelectionController.ResidencePreferenceItem row : rows) {
            if (row != null && row.order == orderValue) {
                return row;
            }
        }
        return null;
    }

    @IsTest
    static void getResidencePreferenceSelectionDataReturnsActiveResidencesWithoutRequest() {
        User residenceUser = createInternalUser('res-load');

        System.runAs(residenceUser) {
            createPersonAccount(
                'Residence Loader',
                residenceUser.Email,
                '9000000101'
            );
            Ken_Room_Category__c activeCategory = createRoomCategoryDirect(
                'Residence Active ' + uniqueSuffix('A'),
                true
            );
            createRoomCategoryDirect(
                'Residence Inactive ' + uniqueSuffix('I'),
                false
            );
            Hostel_Cycle__c cycleRow = createHostelCycleDirect(
                'Residence Cycle ' + uniqueSuffix('C'),
                null
            );
            createWindowDirect(
                'Residence Window ' + uniqueSuffix('W'),
                cycleRow.Id,
                Date.today().addDays(-2),
                Date.today().addDays(2)
            );

            Test.startTest();
            ResidencePreferenceSelectionController.ResidenceSelectionResponse response =
                ResidencePreferenceSelectionController.getResidencePreferenceSelectionData();
            Test.stopTest();

            System.assertNotEquals(null, response, 'Expected a response payload.');
            System.assertEquals(0, response.selectedCount, 'No room request should mean no selected preferences.');
            System.assertEquals(0, response.selectedPreferences.size(), 'No room request should map to an empty selection list.');
            System.assertEquals(null, response.requestStatus, 'No room request should mean no request status.');
            System.assert(
                containsResidence(response.residences, activeCategory.Id),
                'Expected active room categories to be returned for selection.'
            );
        }
    }

    @IsTest
    static void getResidencePreferenceSelectionDataFallsBackToAllCategoriesWhenNoActiveRowsExist() {
        User residenceUser = createInternalUser('res-fallback');

        System.runAs(residenceUser) {
            Ken_Room_Category__c firstCategory = createRoomCategoryDirect(
                'Residence Fallback One ' + uniqueSuffix('F1'),
                false
            );
            Ken_Room_Category__c secondCategory = createRoomCategoryDirect(
                'Residence Fallback Two ' + uniqueSuffix('F2'),
                false
            );
            Map<String, Schema.SObjectField> categoryFieldMap = Ken_Room_Category__c.SObjectType
                .getDescribe(Schema.SObjectDescribeOptions.DEFERRED)
                .fields.getMap();
            Ken_Room_Category__c firstUpdate = new Ken_Room_Category__c(
                Id = firstCategory.Id,
                Capacity__c = 3,
                Amenities__c = 'Desk;Task Lighting'
            );
            putIfUpdateable(firstUpdate, categoryFieldMap, 'Total_Price__c', null);
            putIfUpdateable(firstUpdate, categoryFieldMap, 'Premium_Price__c', 4100);
            putIfUpdateable(firstUpdate, categoryFieldMap, 'Base_Price__c', 3900);

            Ken_Room_Category__c secondUpdate = new Ken_Room_Category__c(
                Id = secondCategory.Id,
                Capacity__c = 4,
                Amenities__c = 'Desk'
            );
            putIfUpdateable(secondUpdate, categoryFieldMap, 'Total_Price__c', null);
            putIfUpdateable(secondUpdate, categoryFieldMap, 'Premium_Price__c', null);
            putIfUpdateable(secondUpdate, categoryFieldMap, 'Base_Price__c', 2750);
            update new List<Ken_Room_Category__c>{ firstUpdate, secondUpdate };

            Test.startTest();
            ResidencePreferenceSelectionController.ResidenceSelectionResponse response =
                ResidencePreferenceSelectionController.getResidencePreferenceSelectionData();
            Test.stopTest();

            ResidencePreferenceSelectionController.ResidenceCategoryItem firstItem =
                findResidence(response.residences, firstCategory.Id);
            ResidencePreferenceSelectionController.ResidenceCategoryItem secondItem =
                findResidence(response.residences, secondCategory.Id);

            System.assertEquals(0, response.selectedCount, 'No request should still return zero selected preferences.');
            System.assertNotEquals(null, firstItem, 'Fallback query should return inactive categories when no active rows exist.');
            System.assertNotEquals(null, secondItem, 'Fallback query should return all categories when the active query is empty.');
            System.assertNotEquals(null, firstItem.annualFee, 'Fallback categories should still return an annual fee.');
            System.assertNotEquals(null, secondItem.annualFee, 'Fallback categories should still return an annual fee.');
        }
    }

    @IsTest
    static void getResidencePreferenceSelectionDataUsesEmailFallback() {
        User residenceUser = createInternalUser('res-email');

        System.runAs(residenceUser) {
            Account businessAccount = createBusinessAccount('Residence Email Lookup ' + uniqueSuffix('B'));
            Contact requesterContact = createBusinessContact(
                businessAccount.Id,
                'Lookup',
                residenceUser.Email
            );
            Account requester = createPersonAccount(
                'Residence Email Requester',
                'requester.' + uniqueSuffix('E') + '@example.test',
                '9000000105'
            );
            Ken_Room_Category__c categoryRow = createRoomCategoryDirect(
                'Residence Email Category ' + uniqueSuffix('C'),
                true
            );
            insert new Ken_Room_Request__c(
                Request_By__c = requester.Id,
                Requested_By__c = requesterContact.Id,
                Preference_1__c = categoryRow.Id,
                Status__c = 'Pending'
            );

            Test.startTest();
            ResidencePreferenceSelectionController.ResidenceSelectionResponse response =
                ResidencePreferenceSelectionController.getResidencePreferenceSelectionData();
            Test.stopTest();

            System.assertEquals(1, response.selectedCount, 'Email fallback should locate the room request.');
            System.assertEquals('Pending', response.requestStatus, 'The located request status should be returned.');
            System.assertEquals(
                String.valueOf(categoryRow.Id),
                response.selectedPreferences[0].categoryId,
                'Email fallback should map the requested category.'
            );
        }
    }

    @IsTest
    static void getResidencePreferenceSelectionDataUsesCreatedByFallbackAndMapsAllPreferences() {
        User residenceUser = createInternalUser('res-created');

        System.runAs(residenceUser) {
            Account requester = createPersonAccount(
                'Residence Created By Requester',
                'created.requester.' + uniqueSuffix('R') + '@example.test',
                '9000000106'
            );
            Account partner = createPersonAccount(
                'Residence Preferred Partner',
                'created.partner.' + uniqueSuffix('P') + '@example.test',
                '9000000107'
            );
            Ken_Room_Category__c firstCategory = createRoomCategoryDirect(
                'Residence Created One ' + uniqueSuffix('C1'),
                false
            );
            Ken_Room_Category__c secondCategory = createRoomCategoryDirect(
                'Residence Created Two ' + uniqueSuffix('C2'),
                false
            );
            Ken_Room_Category__c thirdCategory = createRoomCategoryDirect(
                'Residence Created Three ' + uniqueSuffix('C3'),
                false
            );
            Map<String, Schema.SObjectField> categoryFieldMap = Ken_Room_Category__c.SObjectType
                .getDescribe(Schema.SObjectDescribeOptions.DEFERRED)
                .fields.getMap();
            Ken_Room_Category__c firstUpdate = new Ken_Room_Category__c(
                Id = firstCategory.Id,
                Capacity__c = 1,
                Amenities__c = 'Air Conditioning;Shower'
            );
            putIfUpdateable(firstUpdate, categoryFieldMap, 'Total_Price__c', 5100);
            putIfUpdateable(firstUpdate, categoryFieldMap, 'Premium_Price__c', 5000);
            putIfUpdateable(firstUpdate, categoryFieldMap, 'Base_Price__c', 4900);

            Ken_Room_Category__c secondUpdate = new Ken_Room_Category__c(
                Id = secondCategory.Id,
                Capacity__c = 3,
                Amenities__c = 'Desk;Task Lighting'
            );
            putIfUpdateable(secondUpdate, categoryFieldMap, 'Total_Price__c', null);
            putIfUpdateable(secondUpdate, categoryFieldMap, 'Premium_Price__c', 4200);
            putIfUpdateable(secondUpdate, categoryFieldMap, 'Base_Price__c', 4100);

            Ken_Room_Category__c thirdUpdate = new Ken_Room_Category__c(
                Id = thirdCategory.Id,
                Name__c = null,
                Capacity__c = 4,
                Amenities__c = 'Desk'
            );
            putIfUpdateable(thirdUpdate, categoryFieldMap, 'Total_Price__c', null);
            putIfUpdateable(thirdUpdate, categoryFieldMap, 'Premium_Price__c', null);
            putIfUpdateable(thirdUpdate, categoryFieldMap, 'Base_Price__c', 3600);
            update new List<Ken_Room_Category__c>{ firstUpdate, secondUpdate, thirdUpdate };

            Map<String, Schema.SObjectField> requestFieldMap = Ken_Room_Request__c.SObjectType
                .getDescribe(Schema.SObjectDescribeOptions.DEFERRED)
                .fields.getMap();
            Ken_Room_Request__c requestRow = new Ken_Room_Request__c(
                Request_By__c = requester.Id,
                Requested_By__c = requester.PersonContactId,
                Preference_1__c = firstCategory.Id,
                Preference_2__c = secondCategory.Id,
                Preference_3__c = thirdCategory.Id,
                Preferred_Partner__c = partner.Id,
                Status__c = 'Pending'
            );
            putIfCreateable(requestRow, requestFieldMap, 'Preference_1_Category__c', 'Manual Preference Label');
            insert requestRow;

            Test.startTest();
            ResidencePreferenceSelectionController.ResidenceSelectionResponse response =
                ResidencePreferenceSelectionController.getResidencePreferenceSelectionData();
            Test.stopTest();

            ResidencePreferenceSelectionController.ResidencePreferenceItem firstPreference =
                findPreference(response.selectedPreferences, 1);
            ResidencePreferenceSelectionController.ResidencePreferenceItem secondPreference =
                findPreference(response.selectedPreferences, 2);
            ResidencePreferenceSelectionController.ResidencePreferenceItem thirdPreference =
                findPreference(response.selectedPreferences, 3);
            ResidencePreferenceSelectionController.ResidenceCategoryItem firstResidence =
                findResidence(response.residences, firstCategory.Id);
            ResidencePreferenceSelectionController.ResidenceCategoryItem secondResidence =
                findResidence(response.residences, secondCategory.Id);
            ResidencePreferenceSelectionController.ResidenceCategoryItem thirdResidence =
                findResidence(response.residences, thirdCategory.Id);

            System.assertEquals(3, response.selectedCount, 'Created-by fallback should return all saved preferences.');
            System.assertEquals(partner.PersonEmail, response.preferredPartnerEmails, 'Preferred partner email should round-trip.');
            System.assertEquals(
                firstCategory.Name__c,
                firstPreference.type,
                'When the explicit category label field is unavailable, the category name should be used.'
            );
            System.assertEquals('Single sharing', firstPreference.sharing, 'Capacity 1 should map to the single-sharing label.');
            System.assertEquals('AC', firstPreference.ac, 'Air conditioning amenities should map to AC.');
            System.assertEquals('Triple sharing', secondPreference.sharing, 'Capacity 3 should map to the triple-sharing label.');
            System.assertEquals(null, secondPreference.ac, 'Amenities without AC text should not force an AC label.');
            System.assertEquals('4 sharing', thirdPreference.sharing, 'Higher capacities should use the generic sharing label.');
            System.assertEquals(null, thirdPreference.ac, 'Unknown amenities should not force an AC label.');
            System.assertEquals(null, thirdPreference.bathroom, 'Unknown amenities should not force a bathroom label.');
            System.assertNotEquals(null, firstResidence.annualFee, 'Selected residences should expose an annual fee.');
            System.assertNotEquals(null, secondResidence.annualFee, 'Selected residences should expose an annual fee.');
            System.assertNotEquals(null, thirdResidence.annualFee, 'Selected residences should expose an annual fee.');
        }
    }

    @IsTest
    static void saveResidencePreferencesSupportsDraftSubmitAndLoad() {
        User residenceUser = createInternalUser('res-save');

        System.runAs(residenceUser) {
            Account requester = createPersonAccount(
                'Residence Requester',
                residenceUser.Email,
                '9000000102'
            );
            Account roommate = createPersonAccount(
                'Residence Roommate',
                'roommate.' + uniqueSuffix('R') + '@example.test',
                '9000000103'
            );
            Ken_Room_Category__c firstCategory = createRoomCategoryDirect(
                'Residence First ' + uniqueSuffix('F'),
                true
            );
            Ken_Room_Category__c secondCategory = createRoomCategoryDirect(
                'Residence Second ' + uniqueSuffix('S'),
                true
            );
            Hostel_Cycle__c previousCycle = createHostelCycleDirect(
                'Residence Previous ' + uniqueSuffix('P'),
                null
            );
            Hostel_Cycle__c currentCycle = createHostelCycleDirect(
                'Residence Current ' + uniqueSuffix('C'),
                previousCycle.Id
            );
            Ken_Windows__c currentWindow = createWindowDirect(
                'Residence Submit ' + uniqueSuffix('W'),
                currentCycle.Id,
                Date.today().addDays(-2),
                Date.today().addDays(2)
            );

            List<ResidencePreferenceSelectionController.ResidenceSelectionPreferenceInput> selections =
                new List<ResidencePreferenceSelectionController.ResidenceSelectionPreferenceInput>{
                    buildSelection(firstCategory.Id, 2, new List<String>{ roommate.PersonEmail }),
                    buildSelection(secondCategory.Id, 3, new List<String>())
                };

            Test.startTest();
            ResidencePreferenceSelectionController.SaveResidencePreferencesResponse draftResponse =
                ResidencePreferenceSelectionController.saveResidencePreferences(selections, false);
            ResidencePreferenceSelectionController.ResidenceSelectionResponse loadedResponse =
                ResidencePreferenceSelectionController.getResidencePreferenceSelectionData();
            ResidencePreferenceSelectionController.SaveResidencePreferencesResponse submitResponse =
                ResidencePreferenceSelectionController.saveResidencePreferences(selections, true);
            Test.stopTest();

            System.assertEquals(true, draftResponse.success, 'Draft save should succeed.');
            System.assertEquals(2, draftResponse.selectedCount, 'Selections should normalize to two contiguous preferences.');
            System.assertEquals(null, draftResponse.status, 'Draft save should not stamp Pending status.');
            System.assertEquals('Draft saved successfully.', draftResponse.message, 'Unexpected draft save message.');

            System.assertEquals(2, loadedResponse.selectedCount, 'Loading should map the saved request preferences.');
            System.assertEquals(2, loadedResponse.selectedPreferences.size(), 'Two preferences should be returned from the saved request.');
            System.assertEquals(roommate.PersonEmail, loadedResponse.preferredPartnerEmails, 'Expected the roommate email to round-trip.');

            System.assertEquals(true, submitResponse.success, 'Submit save should succeed.');
            System.assertEquals('Pending', submitResponse.status, 'Submit should move the request into Pending.');
            System.assertEquals('Residence request submitted successfully.', submitResponse.message, 'Unexpected submit message.');

            Ken_Room_Request__c savedRequest = [
                SELECT Id, Request_By__c, Requested_By__c, Preference_1__c, Preference_2__c, Preference_3__c,
                    Preferred_Partner__c, Status__c, Tenant_type__c, Window__c
                FROM Ken_Room_Request__c
                LIMIT 1
            ];
            System.assertEquals(requester.Id, savedRequest.Request_By__c, 'Expected the request to point to the person account.');
            System.assertEquals(requester.PersonContactId, savedRequest.Requested_By__c, 'Expected the request to point to the requester contact.');
            System.assertEquals(firstCategory.Id, savedRequest.Preference_1__c, 'Preference 1 should use the first normalized category.');
            System.assertEquals(secondCategory.Id, savedRequest.Preference_2__c, 'Preference 2 should use the second normalized category.');
            System.assertEquals(null, savedRequest.Preference_3__c, 'Only two unique preferences should be stored.');
            System.assertEquals(roommate.Id, savedRequest.Preferred_Partner__c, 'Expected the preferred roommate account to be linked.');
            System.assertEquals('Pending', savedRequest.Status__c, 'Submit should persist Pending status.');
            System.assertEquals('Existing', savedRequest.Tenant_type__c, 'A window with a previous hostel cycle should resolve to Existing.');
            System.assertEquals(currentWindow.Id, savedRequest.Window__c, 'Expected the active preference window to be stamped on the request.');
        }
    }

    @IsTest
    static void saveResidencePreferencesRejectsUnknownRoommateEmail() {
        User residenceUser = createInternalUser('res-error');

        System.runAs(residenceUser) {
            createPersonAccount(
                'Residence Error User',
                residenceUser.Email,
                '9000000104'
            );
            Ken_Room_Category__c categoryRow = createRoomCategoryDirect(
                'Residence Error Category ' + uniqueSuffix('E'),
                true
            );
            Hostel_Cycle__c cycleRow = createHostelCycleDirect(
                'Residence Error Cycle ' + uniqueSuffix('C'),
                null
            );
            createWindowDirect(
                'Residence Error Window ' + uniqueSuffix('W'),
                cycleRow.Id,
                Date.today().addDays(-2),
                Date.today().addDays(2)
            );

            Test.startTest();
            ResidencePreferenceSelectionController.SaveResidencePreferencesResponse response =
                ResidencePreferenceSelectionController.saveResidencePreferences(
                    new List<ResidencePreferenceSelectionController.ResidenceSelectionPreferenceInput>{
                        buildSelection(categoryRow.Id, 1, new List<String>{ 'missing.roommate@example.test' })
                    },
                    true
                );
            Test.stopTest();

            System.assertEquals(false, response.success, 'Unknown roommate emails should stop the save before DML.');
            System.assertEquals(
                'One or more roommate emails are not registered in the system.',
                response.message,
                'Unexpected roommate validation message.'
            );
            System.assertEquals(1, response.roommateIssues.size(), 'Expected one roommate validation issue.');
            System.assertEquals(
                'missing.roommate@example.test',
                response.roommateIssues[0].email,
                'Expected the invalid roommate email to be echoed back.'
            );
            System.assertEquals(
                0,
                [SELECT COUNT() FROM Ken_Room_Request__c],
                'The controller should return before inserting a room request.'
            );
        }
    }

    @IsTest
    static void saveResidencePreferencesRejectsOnlyInvalidSelections() {
        User residenceUser = createInternalUser('res-invalid');

        System.runAs(residenceUser) {
            Test.startTest();
            ResidencePreferenceSelectionController.SaveResidencePreferencesResponse response =
                ResidencePreferenceSelectionController.saveResidencePreferences(
                    new List<ResidencePreferenceSelectionController.ResidenceSelectionPreferenceInput>{
                        null,
                        buildSelectionRaw(null, 1, null),
                        buildSelectionRaw('not-an-id', 2, new List<String>()),
                        buildSelectionRaw('   ', 3, new List<String>())
                    },
                    false
                );
            Test.stopTest();

            System.assertEquals(false, response.success, 'Invalid selections should not create a room request.');
            System.assertEquals(
                'Select at least one residence preference.',
                response.message,
                'The controller should reject lists that normalize to zero valid selections.'
            );
        }
    }

    @IsTest
    static void saveResidencePreferencesReturnsNoContactWhenUserHasNoLinkedPersonAccount() {
        User residenceUser = createInternalUser('res-nocontact');

        System.runAs(residenceUser) {
            Ken_Room_Category__c categoryRow = createRoomCategoryDirect(
                'Residence No Contact ' + uniqueSuffix('N'),
                true
            );

            Test.startTest();
            ResidencePreferenceSelectionController.SaveResidencePreferencesResponse response =
                ResidencePreferenceSelectionController.saveResidencePreferences(
                    new List<ResidencePreferenceSelectionController.ResidenceSelectionPreferenceInput>{
                        buildSelection(categoryRow.Id, 1, new List<String>())
                    },
                    false
                );
            Test.stopTest();

            System.assertEquals(false, response.success, 'Unmapped users should not create a request.');
            System.assertEquals(
                'No contact is linked to this user.',
                response.message,
                'The controller should stop when no requester contact can be resolved.'
            );
        }
    }

    @IsTest
    static void saveResidencePreferencesNormalizesDuplicatesAndPreservesBlankStatus() {
        User residenceUser = createInternalUser('res-rejected');

        System.runAs(residenceUser) {
            Account requester = createPersonAccount(
                'Residence Rejected Requester',
                residenceUser.Email,
                '9000000108'
            );
            Ken_Room_Category__c firstCategory = createRoomCategoryDirect(
                'Residence Rejected One ' + uniqueSuffix('R1'),
                true
            );
            Ken_Room_Category__c secondCategory = createRoomCategoryDirect(
                'Residence Rejected Two ' + uniqueSuffix('R2'),
                true
            );
            Ken_Room_Category__c thirdCategory = createRoomCategoryDirect(
                'Residence Rejected Three ' + uniqueSuffix('R3'),
                true
            );
            Ken_Room_Category__c fourthCategory = createRoomCategoryDirect(
                'Residence Rejected Four ' + uniqueSuffix('R4'),
                true
            );
            Hostel_Cycle__c cycleRow = createHostelCycleDirect(
                'Residence Rejected Cycle ' + uniqueSuffix('C'),
                null
            );
            Ken_Windows__c deletedWindow = createWindowDirect(
                'Residence Deleted Window ' + uniqueSuffix('W'),
                cycleRow.Id,
                Date.today().addDays(-10),
                Date.today().addDays(-5)
            );
            Ken_Room_Request__c existingRequest = new Ken_Room_Request__c(
                Request_By__c = requester.Id,
                Requested_By__c = requester.PersonContactId,
                Window__c = deletedWindow.Id
            );
            insert existingRequest;
            delete deletedWindow;

            List<ResidencePreferenceSelectionController.ResidenceSelectionPreferenceInput> selections =
                new List<ResidencePreferenceSelectionController.ResidenceSelectionPreferenceInput>{
                    buildSelection(secondCategory.Id, 1, new List<String>()),
                    buildSelection(firstCategory.Id, 2, new List<String>()),
                    buildSelection(firstCategory.Id, 2, new List<String>()),
                    buildSelection(thirdCategory.Id, 3, new List<String>()),
                    buildSelection(fourthCategory.Id, 3, new List<String>())
                };

            Test.startTest();
            ResidencePreferenceSelectionController.SaveResidencePreferencesResponse response =
                ResidencePreferenceSelectionController.saveResidencePreferences(selections, false);
            Test.stopTest();

            Ken_Room_Request__c savedRequest = [
                SELECT Id, Preference_1__c, Preference_2__c, Preference_3__c, Status__c, Window__c, Tenant_type__c
                FROM Ken_Room_Request__c
                WHERE Id = :existingRequest.Id
                LIMIT 1
            ];

            System.assertEquals(true, response.success, 'Existing requests should be updatable as a draft.');
            System.assertEquals(3, response.selectedCount, 'Only three contiguous unique preferences should be stored.');
            System.assertEquals('Pending', response.status, 'Org defaults should continue to preserve the current request status.');
            System.assertEquals(secondCategory.Id, savedRequest.Preference_1__c, 'Order 1 should keep the first valid preference.');
            System.assertEquals(firstCategory.Id, savedRequest.Preference_2__c, 'Duplicate category ids should be ignored after the first occurrence.');
            System.assertEquals(thirdCategory.Id, savedRequest.Preference_3__c, 'The fourth distinct preference should be dropped when three slots are filled.');
            System.assertEquals('Pending', savedRequest.Status__c, 'The existing request status should be retained when the draft is resaved.');
            System.assertEquals(null, savedRequest.Window__c, 'Deleting the referenced window should clear the saved lookup.');
            System.assertEquals(null, savedRequest.Tenant_type__c, 'Deleted windows should not resolve a tenant type.');
        }
    }

    @IsTest
    static void saveResidencePreferencesUsesContactEmailFallbackForRoommate() {
        User residenceUser = createInternalUser('res-contact');

        System.runAs(residenceUser) {
            Account requester = createPersonAccount(
                'Residence Contact Requester',
                residenceUser.Email,
                '9000000109'
            );
            Account partner = createPersonAccount(
                'Residence Contact Partner',
                'partner.' + uniqueSuffix('TMP') + '@example.test',
                '9000000110'
            );
            String roommateEmail = 'roommate.' + uniqueSuffix('CF') + '@example.test';
            update new Account(
                Id = partner.Id,
                PersonEmail = null
            );
            update new Contact(
                Id = partner.PersonContactId,
                Email = roommateEmail
            );
            Ken_Room_Category__c categoryRow = createRoomCategoryDirect(
                'Residence Contact Category ' + uniqueSuffix('C'),
                true
            );

            Test.startTest();
            ResidencePreferenceSelectionController.SaveResidencePreferencesResponse response =
                ResidencePreferenceSelectionController.saveResidencePreferences(
                    new List<ResidencePreferenceSelectionController.ResidenceSelectionPreferenceInput>{
                        buildSelection(
                            categoryRow.Id,
                            1,
                            new List<String>{ '   ', roommateEmail }
                        )
                    },
                    true
                );
            Test.stopTest();

            Ken_Room_Request__c savedRequest = [
                SELECT Id, Preferred_Partner__c, Window__c, Tenant_type__c, Status__c
                FROM Ken_Room_Request__c
                WHERE Request_By__c = :requester.Id
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            System.assertEquals(true, response.success, 'Contact-email fallback should still allow the request to save.');
            System.assertEquals(partner.Id, savedRequest.Preferred_Partner__c, 'A person account should be resolved from the matching contact email.');
            System.assertEquals(null, savedRequest.Window__c, 'No active preference window should leave the request window blank.');
            System.assertEquals(null, savedRequest.Tenant_type__c, 'No preference window should leave the tenant type blank.');
            System.assertEquals('Pending', savedRequest.Status__c, 'Submitting the request should still set Pending status.');
        }
    }
}