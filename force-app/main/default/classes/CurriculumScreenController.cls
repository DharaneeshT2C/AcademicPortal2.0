/**
 * ************************************************************************************************
 * @className  CurriculumScreenController
 *
 * @description
 *  Controller for curriculum setup and course-to-pathway mapping.
 *
 *  Responsibilities:
 *  - Fetch programs, plans, pathways, terms, sessions, and courses for curriculum UI
 *  - Add selected Learning Courses to Program Plan requirements and pathway items
 *  - Return already-added courses grouped by pathway details
 *
 * @author      Sureka A R K
 * @createdOn   Jan 05, 2026
 *
 * @history
 * ------------------------------------------------------------------------------------------------
 * Version   Date           Author          Description
 * 1.0       Jan 05, 2026   Sureka A R K    Added ApexDocs and constant usage
 * ************************************************************************************************
 */
@suppressWarnings('PMD.StdCyclomaticComplexity,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveParameterList,PMD.NcssMehodCount,PMD.EagerlyLoadedDescribeSObjectResult,PMD.AvoidNonRestrictiveQueries,PMD.NcssMethodCount')
public with sharing class CurriculumScreenController {
    
    /**
     * @description Metadata holder for junction object descriptors.
     */
    private class JunctionMeta {
        String objectName;
        String planField;
        String offeringField;
    }
    
    /**
     * @description Returns all Learning Programs ordered by name.
     * @return List of LearningProgram records.
     */
    @AuraEnabled(cacheable=true)
    public static List<LearningProgram> getLearningProgram(){
        try{
            return [SELECT id,name,Duration, DurationUnit from LearningProgram WITH SECURITY_ENFORCED ORDER BY Name];
        } catch (Exception e){
            throw new AuraHandledException('Error retrieving learning programs: ' + e.getMessage());
        }
    }
    
    /**
     * @description Returns Learning Program Plans for a given Learning Program.
     * @param learningProgramId Learning Program Id.
     * @return List of LearningProgramPlan records.
     */
    @AuraEnabled(cacheable=true)
    public static List<LearningProgramPlan> getLearningProgramPlan(Id learningProgramId){
        try{
            return [SELECT id,name from LearningProgramPlan WHERE LearningProgramId = :learningProgramId WITH SECURITY_ENFORCED ORDER BY Name];
        } catch (Exception e){
            throw new AuraHandledException('Error retrieving learning program plan: '+e.getMessage());
        }
    }
    
    /**
     * @description Returns all Academic Terms ordered by name.
     * @return List of AcademicTerm records.
     */
    @AuraEnabled(cacheable=true)
    public static List<AcademicTerm> getAllAcademicTerms() {
        try {
            assertReadable(AcademicTerm.SObjectType, 'Read access is required for AcademicTerm.');
            return [
                SELECT Id, Name
                FROM AcademicTerm
                WITH USER_MODE
                ORDER BY Name
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @description Returns pathways mapped to a selected Learning Program Plan.
     * @param learningProgramPlanId Learning Program Plan Id.
     * @return List of LearningPathwayTemplate records.
     */
    @AuraEnabled(cacheable=true)
    public static List<LearningPathwayTemplate> getPathwaysByProgramPlan(
        Id learningProgramPlanId
    ) {
        try {
            assertReadable(LearningPathwayTemplate.SObjectType, 'Read access is required for LearningPathwayTemplate.');
            assertReadable(LearningPathwayTmplPgmPlan.SObjectType, 'Read access is required for LearningPathwayTmplPgmPlan.');
            return [
                SELECT Id, Name, Pathway_Type__c
                FROM LearningPathwayTemplate
                WHERE Id IN (
                    SELECT LearningPathwayTemplateId
                    FROM LearningPathwayTmplPgmPlan
                    WHERE LearningProgramPlanId = :learningProgramPlanId
                )
                WITH USER_MODE
                ORDER BY Pathway_Type__c, Name
            ];
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error fetching Pathways: ' + e.getMessage()
                );
        }
    }
    
    /**
     * @description Returns Academic Sessions.
     * @return List of AcademicSession records.
     */
    @AuraEnabled(cacheable=true)
    public static List<AcademicSession> getAcademicSessionsByTerm() {
        try {
            assertReadable(AcademicSession.SObjectType, 'Read access is required for AcademicSession.');
            return [
                SELECT id,name,ClassStartDate,ClassEndDate,Type
                FROM AcademicSession 
                WITH USER_MODE
            ];
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error fetching Pathways: ' + e.getMessage()
                );
        }
    }
    
    /**
     * @description Returns all Learning Courses ordered by name.
     * @return List of LearningCourse records.
     */
    @AuraEnabled(cacheable=true)
    public static List<LearningCourse> getAllLearningCourses() {
        assertReadable(LearningCourse.SObjectType, 'Read access is required for LearningCourse.');
        return [
            SELECT Id, Name,CourseNumber,Duration,DurationUnit
            FROM LearningCourse
            WITH USER_MODE
            ORDER BY Name
        ];
    }
    
    /**
     * @description Adds selected courses as Program Plan Requirements and Pathway Template Items.
     * @param learningCourseIds Selected LearningCourse Ids.
     * @param semesterNumber Semester number used to compute year/sequence.
     * @param category Category value from UI.
     * @param groupName Optional group name.
     * @param learningProgramPlanId Learning Program Plan Id.
     * @param learningPathwayTemplateId Learning Pathway Template Id.
     * @param ruleType Optional rule type for elective groups.
     * @param minCourseCount Optional minimum course count.
     * @param maxCourseCount Optional maximum course count.
     * @param maxCreditLimit Optional maximum credit limit.
     */
    @AuraEnabled
    public static void addCoursesToCurriculum(
        List<Id> learningCourseIds,
    Integer semesterNumber,
    String category,
    String groupName,
    Id learningProgramPlanId,
    Id learningPathwayTemplateId,
    String ruleType,
    Integer minCourseCount,
    Integer maxCourseCount,
    Integer maxCreditLimit
    ) {
        Savepoint sp = Database.setSavepoint();
        
        try {
            String normalizedCategory = String.isBlank(category) ? KenConstantController.CURRICULUM_CATEGORY_CORE : category;
            if (normalizedCategory != KenConstantController.CURRICULUM_CATEGORY_CORE &&
                normalizedCategory != KenConstantController.CURRICULUM_CATEGORY_ELECTIVE &&
            String.isNotBlank(groupName)) {
                normalizedCategory = KenConstantController.CURRICULUM_CATEGORY_ELECTIVE;
            }
            
            assertReadable(LearningPathwayTmplPgmPlan.SObjectType, 'Read access is required for LearningPathwayTmplPgmPlan.');
            LearningPathwayTmplPgmPlan planDetails = [
            SELECT Cadence_Type__c
            FROM LearningPathwayTmplPgmPlan
            WHERE LearningProgramPlanId = :learningProgramPlanId
            AND LearningPathwayTemplateId = :learningPathwayTemplateId
            WITH USER_MODE
            LIMIT 1
        ];
            
            String cadence = planDetails.Cadence_Type__c;
            
            Integer yearNum;
            Integer sequence;
            String season;
            
            if (cadence == KenConstantController.CADENCE_SEMESTER) {
                yearNum = (Integer)Math.ceil(semesterNumber / 2.0);
                sequence = Math.mod(semesterNumber - 1, 2) + 1;
                season = sequence == 1 ? KenConstantController.SEASON_FALL : KenConstantController.SEASON_SPRING;
            }
            else if (cadence == KenConstantController.CADENCE_TRIMESTER) {
                yearNum = (Integer)Math.ceil(semesterNumber / 3.0);
                sequence = Math.mod(semesterNumber - 1, 3) + 1;
                
                if (sequence == 1) {season = KenConstantController.SEASON_FALL;}
                else if (sequence == 2) {season = KenConstantController.SEASON_SPRING;}
                else {season = KenConstantController.SEASON_SUMMER;}
            }
            else if (cadence == KenConstantController.CADENCE_QUARTER) {
                yearNum = (Integer)Math.ceil(semesterNumber / 4.0);
                sequence = Math.mod(semesterNumber - 1, 4) + 1;
                
                if (sequence == 1) {season = KenConstantController.SEASON_FALL;}
                else if (sequence == 2) {season = KenConstantController.SEASON_WINTER;}
                else if (sequence == 3) {season = KenConstantController.SEASON_SPRING;}
                else {season = KenConstantController.SEASON_SUMMER;}
            }
            else {
                throw new AuraHandledException('Unsupported cadence type: ' + cadence);
            }
            
            Map<Integer, String> yearMap = new Map<Integer, String>{
                1 => KenConstantController.CURRICULUM_YEAR_LABEL_PREFIX + '1',
                2 => KenConstantController.CURRICULUM_YEAR_LABEL_PREFIX + '2',
                3 => KenConstantController.CURRICULUM_YEAR_LABEL_PREFIX + '3',
                4 => KenConstantController.CURRICULUM_YEAR_LABEL_PREFIX + '4'
            };
            
            Map<Id, LearningCourse> courseMap = new Map<Id, LearningCourse>([
            SELECT Id, LearningId, Duration, DurationUnit, CourseNumber
            FROM LearningCourse
            WHERE Id IN :learningCourseIds
            WITH USER_MODE
        ]);
            
            Set<Id> learningIds = new Set<Id>();
            for (LearningCourse lc : courseMap.values()) {
                learningIds.add(lc.LearningId);
            }
            
            Map<Id, LearningOutcomeItem> outcomeMap = new Map<Id, LearningOutcomeItem>();
            
            assertReadable(LearningOutcomeItem.SObjectType, 'Read access is required for LearningOutcomeItem.');
            for (LearningOutcomeItem loi : [
            SELECT LearningId, LearningAchievementId
            FROM LearningOutcomeItem
            WHERE LearningId IN :learningIds
            WITH USER_MODE
            ORDER BY CreatedDate ASC
        ]) {
                if (!outcomeMap.containsKey(loi.LearningId)) {
                    outcomeMap.put(loi.LearningId, loi);
                }
            }
            
            assertReadable(LearningProgramPlan.SObjectType, 'Read access is required for LearningProgramPlan.');
            LearningProgramPlan lpp = [
            SELECT Id, Name
            FROM LearningProgramPlan
            WHERE Id = :learningProgramPlanId
            WITH USER_MODE
        ];
            
            List<LearningProgramPlanRqmt> lpprs = new List<LearningProgramPlanRqmt>();
            
            for (Id courseId : learningCourseIds) {
                LearningCourse lc = courseMap.get(courseId);
                LearningOutcomeItem loi = outcomeMap.get(lc.LearningId);
                
                lpprs.add(
                    new LearningProgramPlanRqmt(
                    Name = lpp.Name + ' - ' + lc.CourseNumber,
                LearningProgramPlanId = learningProgramPlanId,
                Category = normalizedCategory,
                GroupName = String.isNotBlank(groupName) ? groupName : normalizedCategory,
                Learning_Course__c = courseId,
                LearningAchievementId = loi != null ? loi.LearningAchievementId : null,
                Duration = lc.Duration,
                DurationUnit = lc.DurationUnit
                    )
                    );
                if (normalizedCategory != KenConstantController.CURRICULUM_CATEGORY_CORE) {
                    Map<String, Schema.SObjectField> rqmtFields =
                        LearningProgramPlanRqmt.SObjectType.getDescribe().fields.getMap();
                    LearningProgramPlanRqmt insertedRqmt = lpprs[lpprs.size() - 1];
                    if (rqmtFields.containsKey('Rule_Type__c') && String.isNotBlank(ruleType)) {
                        insertedRqmt.put('Rule_Type__c', ruleType);
                    }
                    if (rqmtFields.containsKey('Min_Course_Count__c') && minCourseCount != null) {
                        insertedRqmt.put('Min_Course_Count__c', minCourseCount);
                    }
                    if (rqmtFields.containsKey('Max_Course_Count__c') && maxCourseCount != null) {
                        insertedRqmt.put('Max_Course_Count__c', maxCourseCount);
                    }
                    if (rqmtFields.containsKey('Max_Credit_Limit__c') && maxCreditLimit != null) {
                        insertedRqmt.put('Max_Credit_Limit__c', maxCreditLimit);
                    }
                }
            }
            
            if (!lpprs.isEmpty()) {
                if (!LearningProgramPlanRqmt.SObjectType.getDescribe().isCreateable()) {
                    throw new AuraHandledException('Create access is required for LearningProgramPlanRqmt.');
                }
                insert lpprs;
            }
            
            List<LearningPathwayTemplateItem> lptis = new List<LearningPathwayTemplateItem>();
            
            for (Integer i = 0; i < lpprs.size(); i++) {
                LearningProgramPlanRqmt lppr = lpprs[i];
                LearningCourse lc = courseMap.get(learningCourseIds[i]);
                
                lptis.add(
                    new LearningPathwayTemplateItem(
                    Type = normalizedCategory == KenConstantController.CURRICULUM_CATEGORY_CORE
                    ? KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT
                    : KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT_PLACEHOLDER,
                LearningId = lc.LearningId,
                Year = yearMap.get(yearNum),
                Season = season,
                Sequence__c = String.ValueOf(sequence),
                Duration = lc.Duration,
                DurationUnit = lc.DurationUnit,
                LearningProgramPlanRequirementId = lppr.Id,
                LearningPathwayTemplateId = learningPathwayTemplateId
                    )
                    );
            }
            
            if (!lptis.isEmpty()) {
                if (!LearningPathwayTemplateItem.SObjectType.getDescribe().isCreateable()) {
                    throw new AuraHandledException('Create access is required for LearningPathwayTemplateItem.');
                }
                insert lptis;
            }
            
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(
                'addCoursesToCurriculum failed → ' + e.getMessage()
                );
        }
    }
    
    /**
     * @description Returns template-plan cadence details.
     * @param learningProgramPlanId Learning Program Plan Id.
     * @param learningPathwayTemplateId Learning Pathway Template Id.
     * @return LearningPathwayTmplPgmPlan record.
     */
    @AuraEnabled(cacheable=true)
    public static LearningPathwayTmplPgmPlan getTemplatePlanDetails(
        Id learningProgramPlanId,
    Id learningPathwayTemplateId
    ) {
        assertReadable(LearningPathwayTmplPgmPlan.SObjectType, 'Read access is required for LearningPathwayTmplPgmPlan.');
        return [
            SELECT Id,
                Cadence_Type__c,
                Start_Period__c,
                End_Period__c
            FROM LearningPathwayTmplPgmPlan
            WHERE LearningProgramPlanId = :learningProgramPlanId
            AND LearningPathwayTemplateId = :learningPathwayTemplateId
            WITH USER_MODE
            LIMIT 1
        ];
    }
    
    /**
     * @description Returns courses already added to a pathway for a specific program plan.
     * @param learningProgramPlanId Learning Program Plan Id.
     * @param learningPathwayTemplateId Learning Pathway Template Id.
     * @return List of row maps for curriculum UI display.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getAddedCoursesByPathway(
        Id learningProgramPlanId,
    Id learningPathwayTemplateId
    ) {
        assertReadable(LearningPathwayTemplateItem.SObjectType, 'Read access is required for LearningPathwayTemplateItem.');
        List<LearningPathwayTemplateItem> items = [
            SELECT
                Year,
                Season,
                Type,
                LearningProgramPlanRequirement.Learning_Course__r.Id,
                LearningProgramPlanRequirement.Learning_Course__r.Name,
                LearningProgramPlanRequirement.Learning_Course__r.CourseNumber,
                LearningProgramPlanRequirement.Category,
                LearningProgramPlanRequirement.GroupName,
                LearningProgramPlanRequirement.Rule_Type__c,
                LearningProgramPlanRequirement.Min_Course_Count__c,
                LearningProgramPlanRequirement.Max_Course_Count__c,
                LearningProgramPlanRequirement.Max_Credit_Limit__c
            FROM LearningPathwayTemplateItem
            WHERE LearningPathwayTemplateId = :learningPathwayTemplateId
            AND LearningProgramPlanRequirement.LearningProgramPlanId = :learningProgramPlanId
            WITH USER_MODE
        ];
        
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        
        for (LearningPathwayTemplateItem item : items) {
            Integer semesterNumber =
                (Integer.valueOf(item.Year.replace(KenConstantController.CURRICULUM_YEAR_LABEL_PREFIX, '')) - 1) * 2
                + (item.Season == KenConstantController.SEASON_FALL ? 1 : 2);
            
            String courseType =
                item.Type == KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT
                ? KenConstantController.CURRICULUM_CATEGORY_CORE
                : KenConstantController.CURRICULUM_CATEGORY_ELECTIVE;
            
            Map<String, Object> row = new Map<String, Object>();
            row.put('semesterNumber', semesterNumber);
            row.put('courseId', item.LearningProgramPlanRequirement.Learning_Course__r.Id);
            row.put('courseCode', item.LearningProgramPlanRequirement.Learning_Course__r.CourseNumber);
            row.put('courseName', item.LearningProgramPlanRequirement.Learning_Course__r.Name);
            row.put('category', item.LearningProgramPlanRequirement.Category);
            row.put('groupName', item.LearningProgramPlanRequirement.GroupName);
            row.put('type', courseType);
            row.put('ruleType', item.LearningProgramPlanRequirement.Rule_Type__c);
            row.put('minCourseCount', item.LearningProgramPlanRequirement.Min_Course_Count__c);
            row.put('maxCourseCount', item.LearningProgramPlanRequirement.Max_Course_Count__c);
            row.put('maxCreditLimit', item.LearningProgramPlanRequirement.Max_Credit_Limit__c);
            
            result.add(row);
        }
        
        return result;
    }
    
    /**
     * @description Ensures read access for object before query.
     * @param sobjectType Object type descriptor.
     * @param message Error message when read access is missing.
     */
    private static void assertReadable(Schema.SObjectType sobjectType, String message) {
        if (sobjectType == null || !sobjectType.getDescribe().isAccessible()) {
            throw new AuraHandledException(message);
        }
    }
    
    /**
     * @description Ensures create access for object before insert.
     * @param sobjectType Object type descriptor.
     * @param message Error message when create access is missing.
     */
    private static void assertCreateable(Schema.SObjectType sobjectType, String message) {
        if (sobjectType == null || !sobjectType.getDescribe().isCreateable()) {
            throw new AuraHandledException(message);
        }
    }
    
    
    
}