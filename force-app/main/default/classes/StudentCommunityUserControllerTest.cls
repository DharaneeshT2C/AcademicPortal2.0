@IsTest
private class StudentCommunityUserControllerTest {
    @IsTest
    static void getEligibleAccountsSupportsStudentAndFacultySearch() {
        Id personAccountRecordTypeId = getPersonAccountRecordTypeId();
        Account studentAccount = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = 'Hakika',
            LastName = 'Student',
            PersonEmail = 'hari.test@example.edu',
            Phone = '5551234567'
        );
        Account facultyAccount = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = 'Hari',
            LastName = 'Faculty',
            PersonEmail = 'ravi.faculty@example.edu',
            Phone = '5557654321'
        );
        insert new List<Account>{ studentAccount, facultyAccount };

        studentAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id = :studentAccount.Id
        ];
        facultyAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id = :facultyAccount.Id
        ];

        insert new List<ConstituentRole>{
            buildConstituentRole(studentAccount.PersonContactId, 'Student'),
            buildConstituentRole(facultyAccount.PersonContactId, 'Faculty')
        };

        Test.startTest();
        List<StudentCommunityUserController.StudentAccountRow> studentRows =
            StudentCommunityUserController.getEligibleAccounts('Student', 'ha', null);
        List<StudentCommunityUserController.StudentAccountRow> facultyRows =
            StudentCommunityUserController.getEligibleAccounts('Faculty', 'hari', null);
        Test.stopTest();

        System.assertEquals(1, studentRows.size(), 'Student partial search should return the matching student account.');
        System.assertEquals(studentAccount.Id, studentRows[0].accountId);
        System.assertEquals('Student', studentRows[0].roleType);
        System.assertEquals(1, facultyRows.size(), 'Faculty case-insensitive partial search should return the faculty account.');
        System.assertEquals(facultyAccount.Id, facultyRows[0].accountId);
        System.assertEquals('Faculty', facultyRows[0].roleType);
    }

    @IsTest
    static void getEligibleAccountsSupportsRoleLinkedToPersonAccount() {
        Id personAccountRecordTypeId = getPersonAccountRecordTypeId();
        Account studentAccount = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = 'Aishitha',
            LastName = 'Kosuri',
            PersonEmail = 'aishitha.kosuri@example.edu'
        );
        insert studentAccount;

        studentAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id = :studentAccount.Id
        ];

        insert buildConstituentRole(studentAccount.Id, 'Student');

        Test.startTest();
        List<StudentCommunityUserController.StudentAccountRow> studentRows =
            StudentCommunityUserController.getEligibleAccounts('Student', 'Aishitha', null);
        Test.stopTest();

        System.assertEquals(1, studentRows.size(), 'A role linked to the Person Account Id should be eligible.');
        System.assertEquals(studentAccount.Id, studentRows[0].accountId);
    }

    @IsTest
    static void getEligibleAccountsReturnsOnlyMatchingNameOrEmailRows() {
        Id personAccountRecordTypeId = getPersonAccountRecordTypeId();
        Account ishaStudent = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = 'Isha',
            LastName = 'Joshi',
            PersonEmail = 'aditya.bose115@student.edu',
            Phone = '987654321'
        );
        Account ishaEmailStudent = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = 'Regular',
            LastName = 'Student',
            PersonEmail = 'isha.student123@student.edu',
            Phone = '987654322'
        );
        Account unrelatedStudent = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = 'Harsh',
            LastName = 'Yadav',
            PersonEmail = 'harsh.yadav59@student.edu',
            Phone = '9845001058'
        );
        insert new List<Account>{ ishaStudent, ishaEmailStudent, unrelatedStudent };

        Map<Id, Account> accountsById = new Map<Id, Account>([
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id IN :new Set<Id>{ ishaStudent.Id, ishaEmailStudent.Id, unrelatedStudent.Id }
        ]);

        insert new List<ConstituentRole>{
            buildConstituentRole(accountsById.get(ishaStudent.Id).PersonContactId, 'Student'),
            buildConstituentRole(accountsById.get(ishaEmailStudent.Id).PersonContactId, 'Student'),
            buildConstituentRole(accountsById.get(unrelatedStudent.Id).PersonContactId, 'Student')
        };

        Test.startTest();
        List<StudentCommunityUserController.StudentAccountRow> rows =
            StudentCommunityUserController.getEligibleAccounts('Student', 'iShA', null);
        Test.stopTest();

        System.assertEquals(2, rows.size(), 'Search should return only rows matching name or email.');
        Set<Id> returnedAccountIds = new Set<Id>();
        for (StudentCommunityUserController.StudentAccountRow row : rows) {
            returnedAccountIds.add(row.accountId);
            String searchableText = (row.accountName + ' ' + row.email).toLowerCase();
            System.assert(searchableText.contains('isha'), 'Every returned row must match the search term.');
        }
        System.assert(returnedAccountIds.contains(ishaStudent.Id), 'Name match should be returned.');
        System.assert(returnedAccountIds.contains(ishaEmailStudent.Id), 'Email match should be returned.');
        System.assert(!returnedAccountIds.contains(unrelatedStudent.Id), 'Unrelated rows must not be returned.');
    }

    @IsTest
    static void getEligibleAccountsSearchWorksForFacultyRows() {
        Id personAccountRecordTypeId = getPersonAccountRecordTypeId();
        Account ishaFaculty = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = 'Isha',
            LastName = 'Faculty',
            PersonEmail = 'faculty.isha@example.edu'
        );
        Account unrelatedFaculty = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = 'Ravi',
            LastName = 'Faculty',
            PersonEmail = 'ravi.faculty@example.edu'
        );
        insert new List<Account>{ ishaFaculty, unrelatedFaculty };

        Map<Id, Account> accountsById = new Map<Id, Account>([
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id IN :new Set<Id>{ ishaFaculty.Id, unrelatedFaculty.Id }
        ]);

        insert new List<ConstituentRole>{
            buildConstituentRole(accountsById.get(ishaFaculty.Id).PersonContactId, 'Faculty'),
            buildConstituentRole(accountsById.get(unrelatedFaculty.Id).PersonContactId, 'Faculty')
        };

        Test.startTest();
        List<StudentCommunityUserController.StudentAccountRow> rows =
            StudentCommunityUserController.getEligibleAccounts('Faculty', 'ISHA', null);
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Faculty search should return only matching name or email rows.');
        System.assertEquals(ishaFaculty.Id, rows[0].accountId);
        System.assertEquals('Faculty', rows[0].roleType);
    }

    @IsTest
    static void enableUsersProcessesStudentAndFacultySelections() {
        Profile studentProfile = getCommunityProfileByName('Student');
        Profile facultyProfile = getCommunityProfileByName('Faculty');
        if (studentProfile == null || facultyProfile == null) {
            return;
        }

        Id personAccountRecordTypeId = getPersonAccountRecordTypeId();
        Account studentAccount = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = 'Meera',
            LastName = 'Learner',
            PersonEmail = 'meera.learner@example.edu'
        );
        Account facultyAccount = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = 'Dev',
            LastName = 'Instructor',
            PersonEmail = 'dev.instructor@example.edu'
        );
        insert new List<Account>{ studentAccount, facultyAccount };

        studentAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id = :studentAccount.Id
        ];
        facultyAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id = :facultyAccount.Id
        ];

        insert new List<ConstituentRole>{
            buildConstituentRole(studentAccount.PersonContactId, 'Student'),
            buildConstituentRole(facultyAccount.PersonContactId, 'Faculty')
        };

        Test.startTest();
        List<StudentCommunityUserController.EnableResult> studentResults;
        List<StudentCommunityUserController.EnableResult> facultyResults;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            studentResults = StudentCommunityUserController.enableUsers(
                new List<Id>{ studentAccount.Id },
                'Student'
            );
            facultyResults = StudentCommunityUserController.enableUsers(
                new List<Id>{ facultyAccount.Id },
                'Faculty'
            );
        }
        Test.stopTest();

        System.assertEquals(1, studentResults.size(), 'Student submit should return one result.');
        System.assertEquals(studentAccount.Id, studentResults[0].accountId);
        System.assertNotEquals(null, studentResults[0].message, 'Student result should include a status message.');
        System.assertEquals(true, studentResults[0].success, 'Student user should be created successfully.');
        System.assertEquals(1, facultyResults.size(), 'Faculty submit should return one result.');
        System.assertEquals(facultyAccount.Id, facultyResults[0].accountId);
        System.assertNotEquals(null, facultyResults[0].message, 'Faculty result should include a status message.');
        System.assertEquals(true, facultyResults[0].success, 'Faculty user should be created successfully.');

        Map<Id, User> usersById = new Map<Id, User>([
            SELECT Id, Profile.Name, ContactId
            FROM User
            WHERE Id IN :new Set<Id>{
                studentResults[0].userId,
                facultyResults[0].userId
            }
        ]);
        System.assertEquals(
            'Student',
            usersById.get(studentResults[0].userId).Profile.Name,
            'Student submit should use the Student profile.'
        );
        System.assertEquals(
            'Faculty',
            usersById.get(facultyResults[0].userId).Profile.Name,
            'Faculty submit should use the Faculty profile.'
        );
    }

    @IsTest
    static void enableUsersSkipsAccountWithoutEmail() {
        Id personAccountRecordTypeId = getPersonAccountRecordTypeId();
        Account studentAccount = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = 'No',
            LastName = 'Email'
        );
        insert studentAccount;

        studentAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id = :studentAccount.Id
        ];
        insert buildConstituentRole(studentAccount.PersonContactId, 'Student');

        Test.startTest();
        List<StudentCommunityUserController.EnableResult> results =
            StudentCommunityUserController.enableUsers(new List<Id>{ studentAccount.Id }, 'Student');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Submit should return one skipped result.');
        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('email'), 'Missing email should be reported.');
    }

    @IsTest
    static void getEligibleAccountsRejectsUnsupportedRole() {
        Test.startTest();
        try {
            StudentCommunityUserController.getEligibleAccounts('Advisor', null, null);
            System.assert(false, 'Expected an AuraHandledException.');
        } catch (AuraHandledException expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void getActiveProgramPlanOptionsReturnsAList() {
        Test.startTest();
        List<StudentCommunityUserController.ProgramPlanOption> options =
            StudentCommunityUserController.getActiveProgramPlanOptions();
        List<StudentCommunityUserController.StudentAccountRow> studentRows =
            StudentCommunityUserController.getEligibleStudentAccounts(null);
        Test.stopTest();

        System.assertNotEquals(null, options, 'Program plan options should never be null.');
        System.assertNotEquals(null, studentRows, 'Student rows should never be null.');
    }

    @IsTest
    static void enableStudentUsersRequiresSelection() {
        Test.startTest();
        try {
            StudentCommunityUserController.enableStudentUsers(new List<Id>());
            System.assert(false, 'Expected an AuraHandledException.');
        } catch (AuraHandledException expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void enableUsersRejectsEmptySelection() {
        Test.startTest();
        try {
            StudentCommunityUserController.enableUsers(new List<Id>(), 'Faculty');
            System.assert(false, 'Expected an AuraHandledException.');
        } catch (AuraHandledException expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        Test.stopTest();
    }

    private static Id getPersonAccountRecordTypeId() {
        List<RecordType> recordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND IsPersonType = true
            LIMIT 1
        ];
        System.assert(!recordTypes.isEmpty(), 'A Person Account record type is required for this test.');
        return recordTypes[0].Id;
    }

    private static ConstituentRole buildConstituentRole(Id personId, String roleType) {
        ConstituentRole role = new ConstituentRole();
        role.PersonId = personId;
        role.RoleType = roleType;
        role.Status = 'Active';
        return role;
    }

    private static Profile getCommunityProfileByName(String profileName) {
        List<Profile> profiles = [
            SELECT Id, Name
            FROM Profile
            WHERE Name = :profileName
            AND UserLicense.Name = 'Customer Community Plus Login'
            LIMIT 1
        ];
        return profiles.isEmpty() ? null : profiles[0];
    }
}