/**
 * ************************************************************************************************
 * @className  KenCurriculumScreenController
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
public with sharing class KenCurriculumScreenController {
    
    public class CourseAddError {
        @AuraEnabled public Id courseId;
        @AuraEnabled public String message;
    }
    
    public class EnrollmentTypeConfig {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean requiresGroup;
        @AuraEnabled public Boolean allowsDirectCourses;
        @AuraEnabled public Boolean allowsGroupedCourses;
        @AuraEnabled public String courseManagementMode;
        @AuraEnabled public String requirementNature;
        @AuraEnabled public String pathwayItemType;
        @AuraEnabled public Integer sortOrder;
    }
    
    public class CreateEnrollmentTypeResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public EnrollmentTypeConfig enrollmentType;
    }
    
    public class AcademicCycleConfig {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String programPlanName;
        @AuraEnabled public String description;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Integer sortOrder;
    }
    
    public class CreateAcademicCycleResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public AcademicCycleConfig cycle;
    }
    
    public class AddCoursesToCurriculumResult {
        @AuraEnabled public List<Id> addedCourseIds;
        @AuraEnabled public List<Id> skippedCourseIds;
        @AuraEnabled public List<CourseAddError> errors;
    }
    
    private static void throwHandled(String message) {
        String msg = String.isBlank(message) ? 'Unexpected error.' : message;
        AuraHandledException ex = new AuraHandledException(msg);
        ex.setMessage(msg);
        throw ex;
    }
    
    /**
     * @description Metadata holder for junction object descriptors.
     */
    private class JunctionMeta {
        String objectName;
        String planField;
        String offeringField;
    }
    
    @TestVisible
    private class EnrollmentTypeConfigInternal {
        String key;
        String label;
        Boolean requiresGroup;
        Boolean allowsDirectCourses;
        Boolean allowsGroupedCourses;
        String courseManagementMode;
        String requirementNature;
        String pathwayItemType;
        Integer sortOrder;
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
    
    @AuraEnabled
    public static List<EnrollmentTypeConfig> getEnrollmentTypes() {
        List<EnrollmentTypeConfigInternal> configs = loadEnrollmentTypeConfigs();
        List<EnrollmentTypeConfig> response = new List<EnrollmentTypeConfig>();
        for (EnrollmentTypeConfigInternal config : configs) {
            response.add(toEnrollmentTypeConfig(config));
        }
        return response;
    }
    
    @AuraEnabled
    public static CreateEnrollmentTypeResult createEnrollmentType(String label, String courseManagementMode, String requirementNature) {
        if (String.isBlank(label)) {
            throwHandled('Enrollment type name is required.');
        }
        
        String normalizedLabel = label.trim();
        List<EnrollmentTypeConfigInternal> configs = loadEnrollmentTypeConfigs();
        for (EnrollmentTypeConfigInternal config : configs) {
            if (config.label != null && config.label.equalsIgnoreCase(normalizedLabel)) {
                throwHandled('An enrollment type with this name already exists.');
            }
        }
        
        String normalizedMode = normalizeCourseManagementMode(courseManagementMode);
        String normalizedRequirementNature = normalizeRequirementNature(requirementNature);
        String developerName = toUniqueDeveloperName(normalizedLabel, configs);
        Integer nextSortOrder = 10;
        for (EnrollmentTypeConfigInternal config : configs) {
            Integer currentOrder = config.sortOrder == null ? 0 : config.sortOrder;
            nextSortOrder = Math.max(nextSortOrder, currentOrder + 10);
        }
        
        Metadata.CustomMetadata record = new Metadata.CustomMetadata();
        record.fullName = 'Ken_Curriculum_Enrollment_Type__mdt.' + developerName;
        record.label = normalizedLabel;
        record.values = new List<Metadata.CustomMetadataValue>();
        record.values.add(buildMetadataValue('Is_Active__c', true));
        record.values.add(buildMetadataValue('Requires_Group__c', normalizedMode != 'Direct'));
        record.values.add(buildMetadataValue('Course_Management_Mode__c', normalizedMode));
        record.values.add(buildMetadataValue('Requirement_Nature__c', normalizedRequirementNature));
        record.values.add(buildMetadataValue(
            'Pathway_Item_Type__c',
        normalizedMode == 'Grouped'
            ? KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT_PLACEHOLDER
            : KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT
            ));
        record.values.add(buildMetadataValue('Sort_Order__c', nextSortOrder));
        
        Metadata.DeployContainer container = new Metadata.DeployContainer();
        container.addMetadata(record);
        Metadata.Operations.enqueueDeployment(container, new KenMetadataDeployCallback());
        
        CreateEnrollmentTypeResult result = new CreateEnrollmentTypeResult();
        result.success = true;
        result.message = 'Enrollment type deployment started.';
        result.enrollmentType = new EnrollmentTypeConfig();
        result.enrollmentType.key = developerName;
        result.enrollmentType.label = normalizedLabel;
        result.enrollmentType.requiresGroup = normalizedMode != 'Direct';
        result.enrollmentType.allowsDirectCourses = normalizedMode == 'Direct' || normalizedMode == 'Both';
        result.enrollmentType.allowsGroupedCourses = normalizedMode == 'Grouped' || normalizedMode == 'Both';
        result.enrollmentType.courseManagementMode = normalizedMode;
        result.enrollmentType.requirementNature = normalizedRequirementNature;
        result.enrollmentType.pathwayItemType = normalizedMode == 'Grouped'
            ? KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT_PLACEHOLDER
            : KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT;
        result.enrollmentType.sortOrder = nextSortOrder;
        return result;
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
    public static AddCoursesToCurriculumResult addCoursesToCurriculum(
        List<Id> learningCourseIds,
    Integer semesterNumber,
    String category,
    String groupName,
    Id learningProgramPlanId,
    Id learningPathwayTemplateId,
    String ruleType,
    Integer minCourseCount,
    Integer maxCourseCount,
    Integer maxCreditLimit,
    String cycleName
    ) {
        try {
            AddCoursesToCurriculumResult result = new AddCoursesToCurriculumResult();
            result.addedCourseIds = new List<Id>();
            result.skippedCourseIds = new List<Id>();
            result.errors = new List<CourseAddError>();
            
            if (learningCourseIds == null || learningCourseIds.isEmpty()) {
                return result;
            }
            
            Set<Id> requestedIdSet = new Set<Id>(learningCourseIds);
            List<Id> requestedIds = new List<Id>(requestedIdSet);
            
            EnrollmentTypeConfigInternal enrollmentTypeConfig = getEnrollmentTypeConfigByIdentifier(category);
            if (enrollmentTypeConfig == null) {
                enrollmentTypeConfig = buildTransientEnrollmentTypeConfig(
                    category,
                String.isNotBlank(groupName) || String.isNotBlank(ruleType)
                    );
            }
            Boolean isGroupedSelection = String.isNotBlank(groupName);
            String normalizedCategory = enrollmentTypeConfig.label;
            String effectiveGroupName = isGroupedSelection
                ? groupName
                : null;
            
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
            else if (cadence == KenConstantController.CADENCE_YEAR) {
                yearNum = (Integer)Math.ceil(semesterNumber / 1.0);
                sequence = Math.mod(semesterNumber - 1, 1) + 1;
                season = KenConstantController.SEASON_FALL;
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
                throwHandled('Unsupported cadence type: ' + cadence);
            }
            
            Map<Integer, String> yearMap = new Map<Integer, String>{
                1 => KenConstantController.CURRICULUM_YEAR_LABEL_PREFIX + '1',
                2 => KenConstantController.CURRICULUM_YEAR_LABEL_PREFIX + '2',
                3 => KenConstantController.CURRICULUM_YEAR_LABEL_PREFIX + '3',
                4 => KenConstantController.CURRICULUM_YEAR_LABEL_PREFIX + '4'
            };
            
            String yearLabel = yearMap.get(yearNum);
            if (String.isBlank(yearLabel)) {
                throwHandled('Invalid year calculated for semesterNumber: ' + semesterNumber);
            }
            
            Set<Id> existingCourseIds = new Set<Id>();
            assertReadable(LearningPathwayTemplateItem.SObjectType, 'Read access is required for LearningPathwayTemplateItem.');
            List<LearningPathwayTemplateItem> existingItems = isGroupedSelection
                ? [
                    SELECT LearningProgramPlanRequirement.Learning_Course__c
                    FROM LearningPathwayTemplateItem
                    WHERE LearningPathwayTemplateId = :learningPathwayTemplateId
                    AND LearningProgramPlanRequirement.LearningProgramPlanId = :learningProgramPlanId
                    AND Year = :yearLabel
                    AND Season = :season
                    AND LearningProgramPlanRequirement.Category = :normalizedCategory
                    AND LearningProgramPlanRequirement.GroupName = :effectiveGroupName
                    AND LearningProgramPlanRequirement.Learning_Course__c IN :requestedIds
                    WITH USER_MODE
                ]
                : [
                    SELECT LearningProgramPlanRequirement.Learning_Course__c
                    FROM LearningPathwayTemplateItem
                    WHERE LearningPathwayTemplateId = :learningPathwayTemplateId
                    AND LearningProgramPlanRequirement.LearningProgramPlanId = :learningProgramPlanId
                    AND Year = :yearLabel
                    AND Season = :season
                    AND LearningProgramPlanRequirement.Category = :normalizedCategory
                    AND LearningProgramPlanRequirement.GroupName = null
                    AND LearningProgramPlanRequirement.Learning_Course__c IN :requestedIds
                    WITH USER_MODE
                ];
            for (LearningPathwayTemplateItem existingItem : existingItems) {
                if (existingItem.LearningProgramPlanRequirement != null &&
                existingItem.LearningProgramPlanRequirement.Learning_Course__c != null) {
                    existingCourseIds.add(existingItem.LearningProgramPlanRequirement.Learning_Course__c);
                }
            }
            
            List<Audit_Log__c> auditLogsToInsert = new List<Audit_Log__c>();
            String auditProcess = 'Curriculum Setup';
            String auditSource = 'KenCurriculumScreenController.addCoursesToCurriculum';
            Map<String, Object> auditContext = new Map<String, Object>{
                'semesterNumber' => semesterNumber,
                'category' => normalizedCategory,
                'groupName' => effectiveGroupName,
                'learningProgramPlanId' => learningProgramPlanId,
                'learningPathwayTemplateId' => learningPathwayTemplateId
            };
            
            List<Id> courseIdsToInsert = new List<Id>();
            for (Id cid : requestedIds) {
                if (existingCourseIds.contains(cid)) {
                    result.skippedCourseIds.add(cid);
                    CourseAddError err = new CourseAddError();
                    err.courseId = cid;
                    err.message = 'Duplicate: Course already added in this group for this period.';
                    result.errors.add(err);
                    Map<String, Object> ctx = new Map<String, Object>(auditContext);
                    ctx.put('courseId', cid);
                    auditLogsToInsert.add(
                        KenAuditLogHelper.auditLogRecord(auditProcess, auditSource)
                        .setRecordId(String.valueOf(cid))
                        .setErrorMessage(err.message)
                        .setRequestBody(JSON.serialize(ctx))
                        .returnWithoutCreate()
                        );
                } else {
                    courseIdsToInsert.add(cid);
                }
            }
            // If everything is duplicate, return errors + audit logs (no exception).
            if (courseIdsToInsert.isEmpty()) {
                insertAuditLogs(auditLogsToInsert);
                return result;
            }
            
            Map<Id, LearningCourse> courseMap = new Map<Id, LearningCourse>([
            SELECT Id, LearningId, Duration, DurationUnit, CourseNumber
            FROM LearningCourse
            WHERE Id IN :courseIdsToInsert
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
            
            List<Id> rqmtCourseIds = new List<Id>();
            for (Id courseId : courseIdsToInsert) {
                LearningCourse lc = courseMap.get(courseId);
                LearningOutcomeItem loi = outcomeMap.get(lc.LearningId);
                
                LearningProgramPlanRqmt rqmt = new LearningProgramPlanRqmt(
                    Name = lpp.Name + ' - ' + lc.CourseNumber,
                LearningProgramPlanId = learningProgramPlanId,
                Category = normalizedCategory,
                GroupName = effectiveGroupName,
                Learning_Course__c = courseId,
                LearningAchievementId = loi != null ? loi.LearningAchievementId : null,
                Duration = lc.Duration,
                DurationUnit = lc.DurationUnit
                    );
                if (String.isNotBlank(cycleName)) {
                    Map<String, Schema.SObjectField> rqmtFieldMap =
                        LearningProgramPlanRqmt.SObjectType.getDescribe().fields.getMap();
                    if (rqmtFieldMap.containsKey('Cycle__c')) {
                        rqmt.put('Cycle__c', cycleName.trim());
                    }
                }
                lpprs.add(rqmt);
                rqmtCourseIds.add(courseId);
                if (enrollmentTypeConfig.requiresGroup) {
                    Map<String, Schema.SObjectField> rqmtFields =
                        LearningProgramPlanRqmt.SObjectType.getDescribe().fields.getMap();
                    LearningProgramPlanRqmt insertedRqmt = lpprs[lpprs.size() - 1];
                    if (isGroupedSelection && rqmtFields.containsKey('Rule_Type__c') && String.isNotBlank(ruleType)) {
                        insertedRqmt.put('Rule_Type__c', ruleType);
                    }
                    if (isGroupedSelection && rqmtFields.containsKey('Min_Course_Count__c') && minCourseCount != null) {
                        insertedRqmt.put('Min_Course_Count__c', minCourseCount);
                    }
                    if (isGroupedSelection && rqmtFields.containsKey('Max_Course_Count__c') && maxCourseCount != null) {
                        insertedRqmt.put('Max_Course_Count__c', maxCourseCount);
                    }
                    if (isGroupedSelection && rqmtFields.containsKey('Max_Credit_Limit__c') && maxCreditLimit != null) {
                        insertedRqmt.put('Max_Credit_Limit__c', maxCreditLimit);
                    }
                }
            }
            
            if (!lpprs.isEmpty()) {
                if (!LearningProgramPlanRqmt.SObjectType.getDescribe().isCreateable()) {
                    throwHandled('Create access is required for LearningProgramPlanRqmt.');
                }
                Database.SaveResult[] rqmtResults = Database.insert(lpprs, false);
                Map<Id, Id> rqmtIdByCourseId = new Map<Id, Id>();
                for (Integer i = 0; i < rqmtResults.size(); i++) {
                    Id courseId = rqmtCourseIds[i];
                    Database.SaveResult sr = rqmtResults[i];
                    if (sr != null && sr.isSuccess()) {
                        rqmtIdByCourseId.put(courseId, lpprs[i].Id);
                    } else {
                        String msg = 'Failed to add requirement.';
                        if (sr != null && sr.getErrors() != null && !sr.getErrors().isEmpty()) {
                            msg = sr.getErrors()[0].getMessage();
                        }
                        CourseAddError err = new CourseAddError();
                        err.courseId = courseId;
                        err.message = msg;
                        result.errors.add(err);
                        Map<String, Object> ctx = new Map<String, Object>(auditContext);
                        ctx.put('courseId', courseId);
                        ctx.put('stage', 'RequirementInsert');
                        auditLogsToInsert.add(
                            KenAuditLogHelper.auditLogRecord(auditProcess, auditSource)
                            .setRecordId(String.valueOf(courseId))
                            .setErrorMessage(msg)
                            .setRequestBody(JSON.serialize(ctx))
                            .returnWithoutCreate()
                            );
                    }
                }
                
                // Build pathway items only for successful requirement inserts.
                List<LearningPathwayTemplateItem> lptis = new List<LearningPathwayTemplateItem>();
                List<Id> lptiCourseIds = new List<Id>();
                List<Id> lptiRqmtIds = new List<Id>();
                
                for (Id courseId : rqmtIdByCourseId.keySet()) {
                    LearningCourse lc = courseMap.get(courseId);
                    if (lc == null) {
                        CourseAddError err = new CourseAddError();
                        err.courseId = courseId;
                        err.message = 'Failed to resolve course details for pathway item creation.';
                        result.errors.add(err);
                        Map<String, Object> ctx = new Map<String, Object>(auditContext);
                        ctx.put('courseId', courseId);
                        ctx.put('stage', 'CourseResolve');
                        auditLogsToInsert.add(
                            KenAuditLogHelper.auditLogRecord(auditProcess, auditSource)
                            .setRecordId(String.valueOf(courseId))
                            .setErrorMessage(err.message)
                            .setRequestBody(JSON.serialize(ctx))
                            .returnWithoutCreate()
                            );
                        continue;
                    }
                    Id rqmtId = rqmtIdByCourseId.get(courseId);
                    lptis.add(
                        new LearningPathwayTemplateItem(
                        Type = isGroupedSelection
                        ? KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT_PLACEHOLDER
                        : KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT,
                    LearningId = lc.LearningId,
                    Year = yearLabel,
                    Season = season,
                    Sequence__c = String.ValueOf(sequence),
                    Duration = lc.Duration,
                    DurationUnit = lc.DurationUnit,
                    LearningProgramPlanRequirementId = rqmtId,
                    LearningPathwayTemplateId = learningPathwayTemplateId
                        )
                        );
                    lptiCourseIds.add(courseId);
                    lptiRqmtIds.add(rqmtId);
                }
                
                if (!lptis.isEmpty()) {
                    if (!LearningPathwayTemplateItem.SObjectType.getDescribe().isCreateable()) {
                        throwHandled('Create access is required for LearningPathwayTemplateItem.');
                    }
                    Database.SaveResult[] lptiResults = Database.insert(lptis, false);
                    List<Id> rqmtIdsToDelete = new List<Id>();
                    
                    for (Integer i = 0; i < lptiResults.size(); i++) {
                        Id courseId = lptiCourseIds[i];
                        Id rqmtId = lptiRqmtIds[i];
                        Database.SaveResult sr = lptiResults[i];
                        if (sr != null && sr.isSuccess()) {
                            result.addedCourseIds.add(courseId);
                        } else {
                            String msg = 'Failed to add pathway item.';
                            if (sr != null && sr.getErrors() != null && !sr.getErrors().isEmpty()) {
                                msg = sr.getErrors()[0].getMessage();
                            }
                            CourseAddError err = new CourseAddError();
                            err.courseId = courseId;
                            err.message = msg;
                            result.errors.add(err);
                            
                            Map<String, Object> ctx = new Map<String, Object>(auditContext);
                            ctx.put('courseId', courseId);
                            ctx.put('stage', 'PathwayItemInsert');
                            auditLogsToInsert.add(
                                KenAuditLogHelper.auditLogRecord(auditProcess, auditSource)
                                .setRecordId(String.valueOf(courseId))
                                .setErrorMessage(msg)
                                .setRequestBody(JSON.serialize(ctx))
                                .returnWithoutCreate()
                                );
                            if (rqmtId != null) {
                                rqmtIdsToDelete.add(rqmtId);
                            }
                        }
                    }
                    
                    // Cleanup: delete any requirements whose pathway item insert failed.
                    if (!rqmtIdsToDelete.isEmpty() &&
                    LearningProgramPlanRqmt.SObjectType.getDescribe().isDeletable()) {
                        try {
                            Database.delete(rqmtIdsToDelete, false);
                        } catch (Exception cleanupEx) {
                            Map<String, Object> ctx = new Map<String, Object>(auditContext);
                            ctx.put('stage', 'CleanupDelete');
                            auditLogsToInsert.add(
                                KenAuditLogHelper.auditLogRecord(auditProcess, auditSource)
                                .setErrorMessage('Cleanup failed: ' + cleanupEx.getMessage())
                                .setRequestBody(JSON.serialize(ctx))
                                .returnWithoutCreate()
                                );
                        }
                    }
                }
            }
            insertAuditLogs(auditLogsToInsert);
            return result;
            
        } catch (Exception e) {
            String err =
                'addCoursesToCurriculum failed → ' +
                e.getTypeName() +
                (String.isBlank(e.getMessage()) ? '' : (': ' + e.getMessage()));
            AuraHandledException ex = new AuraHandledException(err);
            ex.setMessage(err);
            throw ex;
        }
    }
    
    private static void insertAuditLogs(List<Audit_Log__c> logs) {
        if (logs == null || logs.isEmpty()) {return;}
        if (!Audit_Log__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable()) {return;}
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.allowFieldTruncation = true;
        Database.insert(logs, dmlOptions);
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
        List<EnrollmentTypeConfigInternal> configs = loadEnrollmentTypeConfigs();
        Map<String, EnrollmentTypeConfigInternal> configByLabel = new Map<String, EnrollmentTypeConfigInternal>();
        for (EnrollmentTypeConfigInternal config : configs) {
            if (config.label != null) {
                configByLabel.put(config.label.toLowerCase(), config);
            }
        }
        LearningPathwayTmplPgmPlan planDetails = [
            SELECT Cadence_Type__c
            FROM LearningPathwayTmplPgmPlan
            WHERE LearningProgramPlanId = :learningProgramPlanId
            AND LearningPathwayTemplateId = :learningPathwayTemplateId
            LIMIT 1
        ];
        assertReadable(LearningPathwayTemplateItem.SObjectType, 'Read access is required for LearningPathwayTemplateItem.');
        List<LearningPathwayTemplateItem> items = [
            SELECT
                Year,
                Season,
                Sequence__c,
                SequenceNumber,
                Type,
                LearningProgramPlanRequirement.Learning_Course__r.Id,
                LearningProgramPlanRequirement.Learning_Course__r.Name,
                LearningProgramPlanRequirement.Learning_Course__r.CourseNumber,
                LearningProgramPlanRequirement.Learning_Course__r.Duration,
                LearningProgramPlanRequirement.Category,
                LearningProgramPlanRequirement.GroupName,
                LearningProgramPlanRequirement.Rule_Type__c,
                LearningProgramPlanRequirement.Min_Course_Count__c,
                LearningProgramPlanRequirement.Max_Course_Count__c,
                LearningProgramPlanRequirement.Max_Credit_Limit__c,
                LearningProgramPlanRequirement.Cycle__c
            FROM LearningPathwayTemplateItem
            WHERE LearningPathwayTemplateId = :learningPathwayTemplateId
            AND LearningProgramPlanRequirement.LearningProgramPlanId = :learningProgramPlanId
        ];
        
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        
        for (LearningPathwayTemplateItem item : items) {
            Integer semesterNumber = derivePeriodNumber(item, planDetails.Cadence_Type__c);
            
            LearningProgramPlanRqmt requirement = item.LearningProgramPlanRequirement;
            if (requirement == null || requirement.Learning_Course__r == null) {
                continue;
            }
            EnrollmentTypeConfigInternal config =
                requirement.Category == null
                ? null
                : configByLabel.get(requirement.Category.toLowerCase());
            
            Map<String, Object> row = new Map<String, Object>();
            row.put('semesterNumber', semesterNumber);
            row.put('courseId', requirement.Learning_Course__r.Id);
            row.put('courseCode', requirement.Learning_Course__r.CourseNumber);
            row.put('courseName', requirement.Learning_Course__r.Name);
            row.put('courseCredits', requirement.Learning_Course__r.Duration);
            row.put('category', requirement.Category);
            row.put('categoryKey', config != null ? config.key : requirement.Category);
            row.put('groupName', requirement.GroupName);
            row.put('type', item.Type);
            row.put('requiresGroup', config != null ? config.requiresGroup : item.Type == KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT_PLACEHOLDER);
            row.put('pathwayItemType', config != null ? config.pathwayItemType : item.Type);
            row.put('ruleType', requirement.Rule_Type__c);
            row.put('minCourseCount', requirement.Min_Course_Count__c);
            row.put('maxCourseCount', requirement.Max_Course_Count__c);
            row.put('maxCreditLimit', requirement.Max_Credit_Limit__c);
            row.put('cycleName', requirement.Cycle__c);
            
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
    
    @TestVisible
    private static Integer derivePeriodNumber(LearningPathwayTemplateItem item, String cadenceType) {
        Integer yearNumber = item.Year == null
            ? null
            : Integer.valueOf(item.Year.replace(KenConstantController.CURRICULUM_YEAR_LABEL_PREFIX, ''));
        if (yearNumber == null) {
            return null;
        }
        
        Integer sequenceNumber = null;
        if (item.Sequence__c != null) {
            sequenceNumber = Integer.valueOf(item.Sequence__c);
        } else if (item.SequenceNumber != null) {
            sequenceNumber = Integer.valueOf(item.SequenceNumber);
        }
        
        if (cadenceType == KenConstantController.CADENCE_SEMESTER) {
            if (item.Season == KenConstantController.SEASON_FALL) {
                return ((yearNumber - 1) * 2) + 1;
            }
            if (item.Season == KenConstantController.SEASON_SPRING) {
                return ((yearNumber - 1) * 2) + 2;
            }
            return sequenceNumber == null ? null : ((yearNumber - 1) * 2) + sequenceNumber;
        }
        
        if (cadenceType == KenConstantController.CADENCE_TRIMESTER) {
            return sequenceNumber == null ? null : ((yearNumber - 1) * 3) + sequenceNumber;
        }
        
        if (cadenceType == KenConstantController.CADENCE_QUARTER) {
            return sequenceNumber == null ? null : ((yearNumber - 1) * 4) + sequenceNumber;
        }
        if (cadenceType == KenConstantController.CADENCE_YEAR) {
            return yearNumber;
        }
        
        return sequenceNumber == null ? yearNumber : sequenceNumber;
    }
    
    @TestVisible
    private static List<EnrollmentTypeConfigInternal> loadEnrollmentTypeConfigs() {
        List<EnrollmentTypeConfigInternal> configs = new List<EnrollmentTypeConfigInternal>();
        for (Ken_Curriculum_Enrollment_Type__mdt row : [
            SELECT DeveloperName, MasterLabel, Is_Active__c, Requires_Group__c, Course_Management_Mode__c, Requirement_Nature__c, Pathway_Item_Type__c, Sort_Order__c
            FROM Ken_Curriculum_Enrollment_Type__mdt
            WHERE Is_Active__c = true
            ORDER BY Sort_Order__c ASC, MasterLabel ASC
        ]) {
            EnrollmentTypeConfigInternal config = new EnrollmentTypeConfigInternal();
            config.key = row.DeveloperName;
            config.label = row.MasterLabel;
            config.requiresGroup = row.Requires_Group__c;
            config.courseManagementMode = normalizeCourseManagementMode(row.Course_Management_Mode__c);
            config.allowsDirectCourses = config.courseManagementMode == 'Direct' || config.courseManagementMode == 'Both';
            config.allowsGroupedCourses = config.courseManagementMode == 'Grouped' || config.courseManagementMode == 'Both';
            config.requirementNature = normalizeRequirementNature(row.Requirement_Nature__c);
            config.pathwayItemType = String.isBlank(row.Pathway_Item_Type__c)
                ? (config.courseManagementMode == 'Grouped'
                ? KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT_PLACEHOLDER
                : KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT)
                : row.Pathway_Item_Type__c;
            config.sortOrder = row.Sort_Order__c == null ? null : (Integer) row.Sort_Order__c;
            configs.add(config);
        }
        
        if (configs.isEmpty()) {
            EnrollmentTypeConfigInternal fallbackCore = new EnrollmentTypeConfigInternal();
            fallbackCore.key = KenConstantController.CURRICULUM_CATEGORY_CORE;
            fallbackCore.label = KenConstantController.CURRICULUM_CATEGORY_CORE;
            fallbackCore.requiresGroup = true;
            fallbackCore.allowsDirectCourses = true;
            fallbackCore.allowsGroupedCourses = true;
            fallbackCore.courseManagementMode = 'Both';
            fallbackCore.requirementNature = 'Mandatory';
            fallbackCore.pathwayItemType = KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT;
            fallbackCore.sortOrder = 10;
            configs.add(fallbackCore);
            
            EnrollmentTypeConfigInternal fallbackElective = new EnrollmentTypeConfigInternal();
            fallbackElective.key = KenConstantController.CURRICULUM_CATEGORY_ELECTIVE;
            fallbackElective.label = KenConstantController.CURRICULUM_CATEGORY_ELECTIVE;
            fallbackElective.requiresGroup = true;
            fallbackElective.allowsDirectCourses = true;
            fallbackElective.allowsGroupedCourses = true;
            fallbackElective.courseManagementMode = 'Both';
            fallbackElective.requirementNature = 'Not Mandatory';
            fallbackElective.pathwayItemType = KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT;
            fallbackElective.sortOrder = 20;
            configs.add(fallbackElective);
        }
        
        return configs;
    }
    
    @TestVisible
    private static EnrollmentTypeConfigInternal getEnrollmentTypeConfigByIdentifier(String identifier) {
        List<EnrollmentTypeConfigInternal> configs = loadEnrollmentTypeConfigs();
        if (!String.isBlank(identifier)) {
            String normalized = identifier.trim().toLowerCase();
            for (EnrollmentTypeConfigInternal config : configs) {
                if ((config.key != null && config.key.toLowerCase() == normalized) ||
                (config.label != null && config.label.toLowerCase() == normalized)) {
                    return config;
                }
            }
        }
        
        return null;
    }
    
    @TestVisible
    private static EnrollmentTypeConfigInternal buildTransientEnrollmentTypeConfig(String identifier, Boolean requiresGroup) {
        EnrollmentTypeConfigInternal config = new EnrollmentTypeConfigInternal();
        String normalizedIdentifier = String.isBlank(identifier) ? 'Enrollment Type' : identifier.trim();
        config.key = normalizedIdentifier;
        config.label = normalizedIdentifier;
        config.requiresGroup = requiresGroup == true;
        config.courseManagementMode = requiresGroup == true ? 'Grouped' : 'Direct';
        config.allowsDirectCourses = requiresGroup != true;
        config.allowsGroupedCourses = requiresGroup == true;
        config.requirementNature = requiresGroup == true ? 'Not Mandatory' : 'Mandatory';
        config.pathwayItemType = KenConstantController.CURRICULUM_ITEM_TYPE_REQUIREMENT;
        config.sortOrder = null;
        return config;
    }
    
    @TestVisible
    private static EnrollmentTypeConfig toEnrollmentTypeConfig(EnrollmentTypeConfigInternal config) {
        EnrollmentTypeConfig result = new EnrollmentTypeConfig();
        result.key = config.key;
        result.label = config.label;
        result.requiresGroup = config.requiresGroup;
        result.allowsDirectCourses = config.allowsDirectCourses;
        result.allowsGroupedCourses = config.allowsGroupedCourses;
        result.courseManagementMode = config.courseManagementMode;
        result.requirementNature = config.requirementNature;
        result.pathwayItemType = config.pathwayItemType;
        result.sortOrder = config.sortOrder;
        return result;
    }
    
    @TestVisible
    private static String normalizeCourseManagementMode(String mode) {
        String normalized = String.isBlank(mode) ? '' : mode.trim().toLowerCase();
        if (normalized == 'grouped') {
            return 'Grouped';
        }
        if (normalized == 'both') {
            return 'Both';
        }
        return 'Direct';
    }
    
    @TestVisible
    private static String normalizeRequirementNature(String value) {
        String normalized = String.isBlank(value) ? '' : value.trim().toLowerCase();
        if (normalized == 'zero credit') {
            return 'Zero Credit';
        }
        if (normalized == 'not mandatory') {
            return 'Not Mandatory';
        }
        return 'Mandatory';
    }
    
    @TestVisible
    private static Metadata.CustomMetadataValue buildMetadataValue(String fieldApiName, Object fieldValue) {
        Metadata.CustomMetadataValue value = new Metadata.CustomMetadataValue();
        value.field = fieldApiName;
        value.value = fieldValue;
        return value;
    }
    
    @TestVisible
    private static String toUniqueDeveloperName(String label, List<EnrollmentTypeConfigInternal> configs) {
        String baseName = sanitizeDeveloperName(label);
        Set<String> existingNames = new Set<String>();
        for (EnrollmentTypeConfigInternal config : configs) {
            if (config.key != null) {
                existingNames.add(config.key.toLowerCase());
            }
        }
        
        if (!existingNames.contains(baseName.toLowerCase())) {
            return baseName;
        }
        
        Integer suffix = 2;
        while (existingNames.contains((baseName + '_' + suffix).toLowerCase())) {
            suffix++;
        }
        return baseName + '_' + suffix;
    }
    
    @TestVisible
    private static String sanitizeDeveloperName(String label) {
        String value = String.isBlank(label) ? 'Enrollment_Type' : label.trim();
        value = value.replaceAll('[^A-Za-z0-9]+', '_');
        value = value.replaceAll('^_+', '');
        value = value.replaceAll('_+$', '');
        if (String.isBlank(value)) {
            value = 'Enrollment_Type';
        }
        if (!Pattern.matches('^[A-Za-z].*', value)) {
            value = 'ET_' + value;
        }
        return value.length() > 40 ? value.substring(0, 40) : value;
    }
    @AuraEnabled
    public static List<AcademicCycleConfig> getAcademicCycles(String programPlanName) {
        List<AcademicCycleConfig> result = new List<AcademicCycleConfig>();
        if (String.isBlank(programPlanName)) {
            return result;
        }
        String normalizedPlanName = programPlanName.trim();
        for (Ken_Academic_Cycle__mdt record : [
            SELECT DeveloperName, Label, Program_Plan_Name__c, Description__c,
                   Is_Active__c, Sort_Order__c
            FROM Ken_Academic_Cycle__mdt
            WHERE Is_Active__c = true
            AND Program_Plan_Name__c = :normalizedPlanName
            ORDER BY Sort_Order__c NULLS LAST, Label
        ]) {
            AcademicCycleConfig config = new AcademicCycleConfig();
            config.key = record.DeveloperName;
            config.label = record.Label;
            config.programPlanName = record.Program_Plan_Name__c;
            config.description = record.Description__c;
            config.isActive = record.Is_Active__c;
            config.sortOrder = record.Sort_Order__c != null ? Integer.valueOf(record.Sort_Order__c) : null;
            result.add(config);
        }
        return result;
    }
    
    @AuraEnabled
    public static CreateAcademicCycleResult createAcademicCycle(String label, String programPlanName, String description) {
        if (String.isBlank(label)) {
            throwHandled('Cycle name is required.');
        }
        if (String.isBlank(programPlanName)) {
            throwHandled('Program plan name is required.');
        }
        
        String normalizedLabel = label.trim();
        String normalizedPlanName = programPlanName.trim();
        
        List<Ken_Academic_Cycle__mdt> existing = [
            SELECT Label,Sort_Order__c
            FROM Ken_Academic_Cycle__mdt
            WHERE Is_Active__c = true
            AND Program_Plan_Name__c = :normalizedPlanName
        ];
        for (Ken_Academic_Cycle__mdt record : existing) {
            if (record.Label != null && record.Label.equalsIgnoreCase(normalizedLabel)) {
                throwHandled('A cycle with this name already exists for the selected program plan.');
            }
        }
        
        Integer nextSortOrder = 10;
        for (Ken_Academic_Cycle__mdt record : existing) {
            nextSortOrder = Math.max(nextSortOrder, (record.Sort_Order__c != null ? Integer.valueOf(record.Sort_Order__c) : 0) + 10);
        }
        
        String developerName = sanitizeCycleDeveloperName(normalizedLabel, normalizedPlanName);
        
        Metadata.CustomMetadata record = new Metadata.CustomMetadata();
        record.fullName = 'Ken_Academic_Cycle__mdt.' + developerName;
        record.label = normalizedLabel;
        record.values = new List<Metadata.CustomMetadataValue>();
        record.values.add(buildMetadataValue('Program_Plan_Name__c', normalizedPlanName));
        record.values.add(buildMetadataValue('Is_Active__c', true));
        record.values.add(buildMetadataValue('Sort_Order__c', nextSortOrder));
        if (String.isNotBlank(description)) {
            record.values.add(buildMetadataValue('Description__c', description.trim()));
        }
        
        Metadata.DeployContainer container = new Metadata.DeployContainer();
        container.addMetadata(record);
        Metadata.Operations.enqueueDeployment(container, new KenMetadataDeployCallback());
        
        CreateAcademicCycleResult result = new CreateAcademicCycleResult();
        result.success = true;
        result.message = 'Academic cycle deployment started.';
        result.cycle = new AcademicCycleConfig();
        result.cycle.key = developerName;
        result.cycle.label = normalizedLabel;
        result.cycle.programPlanName = normalizedPlanName;
        result.cycle.description = String.isNotBlank(description) ? description.trim() : null;
        result.cycle.isActive = true;
        result.cycle.sortOrder = nextSortOrder;
        return result;
    }
    
    private static String sanitizeCycleDeveloperName(String label, String planName) {
        String combined = (String.isBlank(planName) ? '' : planName.trim() + '_') + (String.isBlank(label) ? 'Cycle' : label.trim());
        String value = combined.replaceAll('[^A-Za-z0-9]+', '_');
        value = value.replaceAll('^_+', '');
        value = value.replaceAll('_+$', '');
        if (String.isBlank(value)) {
            value = 'Academic_Cycle';
        }
        if (!Pattern.matches('^[A-Za-z].*', value)) {
            value = 'AC_' + value;
        }
        return value.length() > 40 ? value.substring(0, 40) : value;
    }
}