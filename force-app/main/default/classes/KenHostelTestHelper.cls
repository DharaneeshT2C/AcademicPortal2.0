@IsTest
public class KenHostelTestHelper {
    public class StudentWindowContext {
        public User runUser;
        public Account studentAccount;
        public Contact studentContact;
        public AcademicYear academicYear;
        public AcademicTerm academicTerm;
        public LearningProgram learningProgram;
        public LearningProgramPlan learningProgramPlan;
        public LearnerProgram learnerProgram;
        public AcademicTermEnrollment termEnrollment;
        public Hostel_Cycle__c cycle;
        public Ken_Windows__c window;
        public Ken_Building__c building;
        public Floor__c floor;
        public Ken_Room_Category__c roomCategory;
        public Ken_Room__c room;
    }

    public static String uniqueText(String prefix) {
        return prefix + '_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
    }

    public static Id getPersonAccountRecordTypeId() {
        List<RecordType> rows = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
                AND IsPersonType = true
            LIMIT 1
        ];
        System.assert(!rows.isEmpty(), 'A Person Account record type is required for hostel tests.');
        return rows[0].Id;
    }

    public static String getPicklistValue(Schema.SObjectField fieldRef, String preferredValue) {
        List<Schema.PicklistEntry> entries = fieldRef.getDescribe().getPicklistValues();
        if (String.isNotBlank(preferredValue)) {
            for (Schema.PicklistEntry entry : entries) {
                if (!entry.isActive()) {
                    continue;
                }
                if (entry.getValue() == preferredValue || entry.getLabel() == preferredValue) {
                    return entry.getValue();
                }
            }
        }
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    public static User createAdminUser(String alias, String email) {
        Profile profileRow = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];

        String safeAlias = String.isBlank(alias) ? 'htstusr' : alias;
        if (safeAlias.length() > 8) {
            safeAlias = safeAlias.substring(0, 8);
        }

        String uniqueKey = String.valueOf(DateTime.now().getTime()) + '_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User userRow = new User(
            FirstName = 'Hostel',
            LastName = 'Tester',
            Alias = safeAlias,
            Email = email,
            Username = uniqueKey + '.' + email,
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profileRow.Id
        );
        insert userRow;
        return userRow;
    }

    public static User createStudentPortalUser(Account personAccount, String alias, String email) {
        List<Profile> portalProfiles = [
            SELECT Id, Name
            FROM Profile
            WHERE UserType IN ('CSPLitePortal', 'CspLitePortal', 'PowerCustomerSuccess', 'PowerPartner')
            ORDER BY Name
            LIMIT 1
        ];
        if (portalProfiles.isEmpty() || personAccount == null || personAccount.PersonContactId == null) {
            return null;
        }

        String safeAlias = String.isBlank(alias) ? 'hstlstd' : alias;
        if (safeAlias.length() > 8) {
            safeAlias = safeAlias.substring(0, 8);
        }

        String resolvedEmail = String.isNotBlank(email) ? email : personAccount.PersonEmail;
        String uniqueKey = String.valueOf(DateTime.now().getTime()) + '_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));

        User userRow = new KenTestDataFactory.UserCreator(portalProfiles[0].Name)
            .setAlias(safeAlias)
            .returnWithoutCreate();
        userRow.Email = resolvedEmail;
        userRow.Username = uniqueKey + '.' + resolvedEmail;
        userRow.ContactId = personAccount.PersonContactId;
        userRow.CommunityNickname = ('hstl' + uniqueKey).left(40);
        try {
            userRow.put('AccountId', personAccount.Id);
        } catch (Exception ignored) {
        }
        insert userRow;
        return userRow;
    }

    public static Account createPersonAccount(String firstName, String lastName, String email, String roleType) {
        Account personAccount = new Account(
            RecordTypeId = getPersonAccountRecordTypeId(),
            FirstName = firstName,
            LastName = lastName,
            PersonEmail = email,
            Phone = '9999999999',
            PersonMobilePhone = '9999999999'
        );
        insert personAccount;

        personAccount = [
            SELECT Id, Name, PersonContactId, PersonEmail
            FROM Account
            WHERE Id = :personAccount.Id
            LIMIT 1
        ];

        if (String.isNotBlank(roleType)) {
            insert new ConstituentRole(
                PersonId = personAccount.PersonContactId,
                RoleType = roleType,
                Status = 'Active'
            );
        }

        return personAccount;
    }

    public static AcademicYear createAcademicYear(String nameValue) {
        return new KenTestDataFactory.AcademicYearCreator(nameValue, nameValue).create();
    }

    public static LearningProgramPlan createLearningProgramPlan(String suffix) {
        Learning learningRow = new KenTestDataFactory.LearningCreator(
            uniqueText('Learning_' + suffix)
        ).create();
        Schema.Location campusRow = new KenTestDataFactory.LocationCreator(
            uniqueText('Campus_' + suffix),
            'Campus'
        ).create();
        LearningProgram learningProgram = new KenTestDataFactory.LearningProgramCreator(
            uniqueText('Program_' + suffix)
        )
            .setLearningId(learningRow.Id)
            .setCampus(campusRow.Id)
            .create();
        LearningProgramPlan plan = new KenTestDataFactory.LearningProgramPlanCreator(learningProgram.Id).returnWithoutCreate();
        plan.Name = uniqueText('Plan_' + suffix);
        insert plan;
        return plan;
    }

    public static LearnerProgram createLearnerProgram(Id accountId, Id contactId, Id planId, String suffix) {
        LearnerProgram learnerProgram = new LearnerProgram(
            Name = uniqueText('LearnerProgram_' + suffix),
            LearnerAccountId = accountId,
            LearnerContactId = contactId,
            LearningProgramPlanId = planId,
            Status = 'Active',
            StartDate = Date.today().addDays(-10)
        );
        insert learnerProgram;
        return learnerProgram;
    }

    public static AcademicTerm createAcademicTerm(Id academicYearId, Integer startYear) {
        return new KenTestDataFactory.AcademicTermCreator(startYear, '1', academicYearId).create();
    }

    public static AcademicTermEnrollment createAcademicTermEnrollment(Id termId, Id contactId, Id accountId) {
        return new KenTestDataFactory.AcademicTermEnrollmentCreator(termId, contactId, accountId).create();
    }

    public static Ken_Building__c createBuildingDirect(String nameValue, Integer floorCount) {
        Ken_Building__c buildingRow = new Ken_Building__c(
            Name__c = nameValue,
            Hostel_Type__c = getPicklistValue(Ken_Building__c.Hostel_Type__c, null),
            Status__c = getPicklistValue(Ken_Building__c.Status__c, 'Active'),
            Number_Of_Floors__c = String.valueOf(floorCount),
            Total_Floors__c = String.valueOf(floorCount),
            Capacity__c = '0',
            Total_Rooms__c = '0',
            Occupancy__c = '0',
            Current_Occupancy__c = '0',
            Warden_Assignment_Mode__c = getPicklistValue(Ken_Building__c.Warden_Assignment_Mode__c, 'Building Level')
        );
        insert buildingRow;
        return buildingRow;
    }

    public static Floor__c createFloor(Id buildingId, Integer floorNumber) {
        Floor__c floorRow = new Floor__c(
            Building__c = buildingId,
            Name = toFloorLabel(floorNumber)
        );
        insert floorRow;
        return floorRow;
    }

    public static Ken_Room_Category__c createRoomCategory(String nameValue, Integer sharingValue) {
        Ken_Room_Category__c categoryRow = new Ken_Room_Category__c(
            Name__c = nameValue,
            Gender_Allowed__c = getPicklistValue(Ken_Room_Category__c.Gender_Allowed__c, null),
            Sharing__c = sharingValue,
            Capacity__c = sharingValue,
            Ac_Non_Ac__c = getPicklistValue(Ken_Room_Category__c.Ac_Non_Ac__c, 'Yes'),
            Bathroom__c = getPicklistValue(Ken_Room_Category__c.Bathroom__c, 'Attached'),
            Active__c = true
        );
        insert categoryRow;
        return categoryRow;
    }

    public static Ken_Room__c createRoom(
        Id buildingId,
        Id floorId,
        Id categoryId,
        Integer capacity,
        String roomNumber,
        String housingCategory
    ) {
        Ken_Room__c roomRow = new Ken_Room__c(
            Building__c = buildingId,
            Floor__c = floorId,
            Room_Category__c = categoryId,
            Capacity__c = capacity,
            Room_Number__c = roomNumber,
            Room_Status__c = getPicklistValue(Ken_Room__c.Room_Status__c, 'Active'),
            Consider_For_Allotment__c = true
        );
        insert roomRow;
        return roomRow;
    }

    public static Hostel_Cycle__c createCycleDirect(String nameValue, AcademicYear academicYearRow, Date startDate, Date endDate) {
        Hostel_Cycle__c cycleRow = new Hostel_Cycle__c(
            Name = nameValue,
            Academic_Years_Display__c = academicYearRow != null ? academicYearRow.Name : null,
            Cycle_Start_Date_Time__c = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0)),
            Cycle_End_Date_Time__c = DateTime.newInstance(endDate, Time.newInstance(23, 59, 0, 0)),
            Status__c = getPicklistValue(Hostel_Cycle__c.Status__c, 'Open')
        );
        insert cycleRow;

        if (academicYearRow != null) {
            insert new Hostel_Cycle_Academic_Year__c(
                Hostel_Cycle__c = cycleRow.Id,
                Academic_Year__c = academicYearRow.Id
            );
        }
        return cycleRow;
    }

    public static Ken_Windows__c createWindowDirect(
        Id cycleId,
        Id learningProgramPlanId,
        Id buildingId,
        Id roomCategoryId,
        String nameValue,
        String allotmentType,
        Boolean allowRoommatePreference
    ) {
        Ken_Windows__c windowRow = new Ken_Windows__c(
            Name = nameValue,
            Hostel_Cycle__c = cycleId,
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c = Date.today().addDays(10),
            Start_Time__c = Time.newInstance(0, 0, 0, 0),
            End_Time__c = Time.newInstance(23, 59, 0, 0),
            Payment_Deadline__c = Date.today().addDays(5),
            Allotment_Type__c = allotmentType,
            Enable_Room_Preference__c = allotmentType == 'Preference Selected',
            Allow_Roommate_Preference__c = allowRoommatePreference
        );
        insert windowRow;

        if (learningProgramPlanId != null) {
            insert new Ken_Window_Learning_Program_Plan__c(
                Window__c = windowRow.Id,
                Learning_Program_Plan__c = learningProgramPlanId
            );
        }
        if (buildingId != null) {
            insert new Ken_Window_Building__c(
                Windows__c = windowRow.Id,
                Building__c = buildingId,
                Limit_Mode__c = 'Use Full Capacity'
            );
        }
        if (roomCategoryId != null) {
            insert new Ken_Window_Room_Category__c(
                Windows__c = windowRow.Id,
                Room_Category__c = roomCategoryId
            );
        }
        return windowRow;
    }

    public static Ken_Room_Request__c createRoomRequest(
        Id accountId,
        Id contactId,
        Id windowId,
        Id categoryId,
        String categoryLabel,
        Integer floorNumber,
        String statusValue
    ) {
        Ken_Room_Request__c requestRow = new Ken_Room_Request__c(
            Request_By__c = accountId,
            Requested_By__c = contactId,
            Window__c = windowId,
            Status__c = statusValue,
            Preference_1__c = categoryId,
            Floor_Preference_1__c = toFloorLabel(floorNumber)
        );
        insert requestRow;
        return requestRow;
    }

    public static Ken_Room_Allotment__c createRoomAllotment(
        Id roomId,
        Id accountId,
        Id contactId,
        Id windowId,
        String housingCategory,
        Boolean active
    ) {
        Ken_Room_Allotment__c allotmentRow = new Ken_Room_Allotment__c(
            Room__c = roomId,
            Tenant_Account__c = accountId,
            Tenant__c = contactId,
            Window__c = windowId,
            Start_Date__c = Date.today().addDays(-1),
            Active__c = active,
            Allotment_Type__c = getPicklistValue(Ken_Room_Allotment__c.Allotment_Type__c, 'Preference Selected')
        );
        insert allotmentRow;
        return allotmentRow;
    }

    public static StudentWindowContext createStudentWindowContext(String key, Boolean withAllotment, Boolean allowRoommatePreference) {
        String email = key.toLowerCase() + '@example.com';
        User runUser = createAdminUser(
            key.length() > 8 ? key.substring(0, 8) : key,
            email
        );
        return buildStudentWindowContext(key, email, runUser, withAllotment, allowRoommatePreference);
    }

    public static StudentWindowContext createStudentWindowContextForCurrentUser(
        String key,
        Boolean withAllotment,
        Boolean allowRoommatePreference
    ) {
        User currentUser = [
            SELECT Id, Email, Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String email = String.isNotBlank(currentUser.Email) ? currentUser.Email : currentUser.Username;
        return buildStudentWindowContext(key, email, currentUser, withAllotment, allowRoommatePreference);
    }

    private static StudentWindowContext buildStudentWindowContext(
        String key,
        String email,
        User runUser,
        Boolean withAllotment,
        Boolean allowRoommatePreference
    ) {
        StudentWindowContext context = new StudentWindowContext();
        context.runUser = runUser;
        context.studentAccount = createPersonAccount('Student', key, email, 'Student');
        context.studentContact = [
            SELECT Id, Name, Email
            FROM Contact
            WHERE Id = :context.studentAccount.PersonContactId
            LIMIT 1
        ];

        context.academicYear = createAcademicYear('AY ' + key);
        context.academicTerm = createAcademicTerm(context.academicYear.Id, Date.today().year());
        context.learningProgramPlan = createLearningProgramPlan(key);
        context.learningProgram = [
            SELECT Id, Name
            FROM LearningProgram
            WHERE Id = :context.learningProgramPlan.LearningProgramId
            LIMIT 1
        ];
        context.learnerProgram = createLearnerProgram(
            context.studentAccount.Id,
            context.studentContact.Id,
            context.learningProgramPlan.Id,
            key
        );
        context.termEnrollment = createAcademicTermEnrollment(
            context.academicTerm.Id,
            context.studentContact.Id,
            context.studentAccount.Id
        );
        context.building = createBuildingDirect('Building ' + key, 1);
        context.floor = createFloor(context.building.Id, 1);
        context.roomCategory = createRoomCategory('Category ' + key, 2);
        context.room = createRoom(
            context.building.Id,
            context.floor.Id,
            context.roomCategory.Id,
            2,
            'R' + Math.abs(Crypto.getRandomInteger()),
            context.roomCategory.Name__c
        );
        context.cycle = createCycleDirect(
            'Cycle ' + key,
            context.academicYear,
            Date.today().addDays(-2),
            Date.today().addDays(30)
        );
        context.window = createWindowDirect(
            context.cycle.Id,
            context.learningProgramPlan.Id,
            context.building.Id,
            context.roomCategory.Id,
            'Window ' + key,
            'Preference Selected',
            allowRoommatePreference
        );

        if (withAllotment) {
            createRoomAllotment(
                context.room.Id,
                context.studentAccount.Id,
                context.studentContact.Id,
                context.window.Id,
                context.roomCategory.Name__c,
                true
            );
        }

        return context;
    }

    public static String toFloorLabel(Integer floorNumber) {
        if (floorNumber == null) {
            return null;
        }
        Integer lastTwoDigits = Math.mod(floorNumber, 100);
        String suffix = 'th';
        if (lastTwoDigits < 11 || lastTwoDigits > 13) {
            Integer lastDigit = Math.mod(floorNumber, 10);
            if (lastDigit == 1) {
                suffix = 'st';
            } else if (lastDigit == 2) {
                suffix = 'nd';
            } else if (lastDigit == 3) {
                suffix = 'rd';
            }
        }
        return String.valueOf(floorNumber) + suffix + ' Floor';
    }
}