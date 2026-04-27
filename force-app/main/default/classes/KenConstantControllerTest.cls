@isTest(SeeAllData=false)
private class KenConstantControllerTest {
    @isTest
    static void constantsAreExposed() {
        System.assertEquals('Account', KenConstantController.SOBJECT_ACCOUNT, 'SOBJECT_ACCOUNT must match Account API name.');
        System.assertEquals('Institute', KenConstantController.RECORDTYPE_ACCOUNT_INSTITUTE, 'Institute record type constant mismatch.');
        System.assertEquals('Department', KenConstantController.RECORDTYPE_ACCOUNT_DEPARTMENT, 'Department record type constant mismatch.');
        System.assertEquals('University', KenConstantController.RECORDTYPE_ACCOUNT_UNIVERSITY, 'University record type constant mismatch.');
        System.assertEquals('School', KenConstantController.RECORDTYPE_ACCOUNT_SCHOOL, 'School record type constant mismatch.');
        System.assertEquals('Semester', KenConstantController.CADENCE_SEMESTER, 'Semester cadence constant mismatch.');
        System.assertEquals('Trimester', KenConstantController.CADENCE_TRIMESTER, 'Trimester cadence constant mismatch.');
        System.assertEquals('Quarter', KenConstantController.CADENCE_QUARTER, 'Quarter cadence constant mismatch.');
        System.assertEquals('Yearly', KenConstantController.CADENCE_YEAR, 'Yearly cadence constant mismatch.');
        System.assertEquals('Fall', KenConstantController.SEASON_FALL, 'Fall season constant mismatch.');
        System.assertEquals('Spring', KenConstantController.SEASON_SPRING, 'Spring season constant mismatch.');
        System.assertEquals('Summer', KenConstantController.SEASON_SUMMER, 'Summer season constant mismatch.');
        System.assertEquals('Winter', KenConstantController.SEASON_WINTER, 'Winter season constant mismatch.');
        System.assertEquals('Active', KenConstantController.ENROLLMENT_STATUS_ACTIVE, 'Active enrollment status mismatch.');
        System.assertEquals('Enrolled', KenConstantController.STATUS_ENROLLED, 'Enrolled status mismatch.');
        System.assertEquals('Waitlisted', KenConstantController.STATUS_WAITLISTED, 'Waitlisted status mismatch.');
        System.assertEquals('Student', KenConstantController.ROLETYPE_STUDENT, 'Student role type constant mismatch.');
        System.assertEquals('Year', KenConstantController.CADENCE_YEAR_LABEL_PREFIX, 'Year label prefix mismatch.');
        System.assertEquals('AM', KenConstantController.TIME_PERIOD_AM, 'AM constant mismatch.');
        System.assertEquals('PM', KenConstantController.TIME_PERIOD_PM, 'PM constant mismatch.');
        System.assertEquals('Exception', KenConstantController.RECORDTYPE_NAME_EXCEPTION, 'Exception record type constant mismatch.');
        System.assertEquals('Integration', KenConstantController.RECORDTYPE_NAME_INTEGRATION, 'Integration record type constant mismatch.');
        System.assertEquals('Core', KenConstantController.CURRICULUM_CATEGORY_CORE, 'Core category constant mismatch.');
        System.assertEquals('Elective', KenConstantController.CURRICULUM_CATEGORY_ELECTIVE, 'Elective category constant mismatch.');
        System.assertEquals('Requirement', KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT, 'Requirement item type mismatch.');
        System.assertEquals('RequirementPlaceholder', KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT_PLACEHOLDER, 'Placeholder item type mismatch.');
        System.assertEquals('Year ', KenConstantController.CURRICULUM_YEAR_LABEL_PREFIX, 'Year label prefix with space mismatch.');
        System.assertEquals('#0b5ec0', KenConstantController.DEFAULT_PRIMARY_COLOR, 'Default primary color mismatch.');
        System.assertEquals('#08376c', KenConstantController.DEFAULT_SECONDARY_COLOR, 'Default secondary color mismatch.');

        KenConstantController instance = new KenConstantController();
        System.assertNotEquals(null, instance, 'Default constructor should succeed.');
    }
}