/**
 * ************************************************************************************************
 * @className  KenConstantController
 *
 * @description
 *  Centralized constants used across Apex controllers and batch classes.
 *
 *  Responsibilities:
 *  - Define reusable sObject API-name constants
 *  - Define reusable Account RecordType name constants
 *  - Define shared cadence and season literal values
 *  - Define shared enrollment status and audit helper constants
 *
 * @author      Sureka A R K
 * @createdOn   Feb 23, 2026
 *
 * @history
 * ------------------------------------------------------------------------------------------------
 * Version   Date           Author          Description
 * 1.0       Feb 23, 2026   Sureka A R K     Initial version
 * ************************************************************************************************
 */
public with sharing class KenConstantController {
    
    public static final String SOBJECT_ACCOUNT = 'Account';
    
    public static final String RECORDTYPE_ACCOUNT_INSTITUTE = 'Institute';
    public static final String RECORDTYPE_ACCOUNT_DEPARTMENT = 'Department';
    public static final String RECORDTYPE_ACCOUNT_UNIVERSITY = 'University';
    public static final String RECORDTYPE_ACCOUNT_SCHOOL = 'School';
    
    public static final String CADENCE_SEMESTER = 'Semester';
    public static final String CADENCE_TRIMESTER = 'Trimester';
    public static final String CADENCE_QUARTER = 'Quarter';
    public static final String CADENCE_YEAR = 'Yearly';
    
    public static final String SEASON_FALL = 'Fall';
    public static final String SEASON_SPRING = 'Spring';
    public static final String SEASON_SUMMER = 'Summer';
    public static final String SEASON_WINTER = 'Winter';
    
    public static final String ENROLLMENT_STATUS_ACTIVE = 'Active';
    public static final String STATUS_ENROLLED = 'Enrolled';
    public static final String STATUS_WAITLISTED = 'Waitlisted';
    public static final String ROLETYPE_STUDENT = 'Student';
    public static final String CADENCE_YEAR_LABEL_PREFIX = 'Year';
    public static final String TIME_PERIOD_AM = 'AM';
    public static final String TIME_PERIOD_PM = 'PM';
    
    public static final String RECORDTYPE_NAME_EXCEPTION = 'Exception';
    public static final String RECORDTYPE_NAME_INTEGRATION = 'Integration';
    // Developer name is literally "Componnet" in the target org — matches SF metadata typo
    public static final String RECORDTYPE_ACTIVITY_GRADE_COMPONENT = 'Componnet';
    public static final String COMPONENT_INTERNAL = 'Internal';
    public static final String COMPONENT_EXTERNAL = 'External';
    
    public static final String CURRICULUM_CATEGORY_CORE = 'Core';
    public static final String CURRICULUM_CATEGORY_ELECTIVE = 'Elective';
    public static final String CURRICULUM_ITEM_TYPE_REQUIREMENT = 'Requirement';
    public static final String CURRICULUM_ITEM_TYPE_REQUIREMENT_PLACEHOLDER = 'RequirementPlaceholder';
    public static final String CURRICULUM_YEAR_LABEL_PREFIX = 'Year ';
    public static final String DEFAULT_PRIMARY_COLOR = '#0b5ec0';
    public static final String DEFAULT_SECONDARY_COLOR = '#08376c';
    
}