/**
 * ************************************************************************************************
 * @className  CourseOfferingSyncController
 *
 * @description
 *  Synchronizes Program Plan curriculum courses to Course Offering and
 *  Program_Plan_Course_Junction__c records for a selected Academic Session.
 *
 *  Responsibilities:
 *  - Fetch active Learning Program Plans for selection UI
 *  - Resolve curriculum items by session cadence (year/sequence)
 *  - Create missing default Course Offerings for required courses
 *  - Create missing plan-to-offering junction records
 *  - Log sync failures to audit logs
 *
 * @author      Sureka A R K
 * @createdOn   Feb 10, 2026
 *
 * @history
 * ------------------------------------------------------------------------------------------------
 * Version   Date           Author          Description
 * 1.0       Feb 10, 2026   Sureka A R K    Added ApexDocs
 * ************************************************************************************************
 */
@suppressWarnings('PMD.StdCyclomaticComplexity,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssMethodCount,PMD.EagerlyLoadedDescribeSObjectResult')
public with sharing class CourseOfferingSyncController {
    private static Id courseOfferingDefaultRtId;
    
    private class TypeCreditPair {
        String courseType;
        Decimal credit;
        String key;
    }
    
    /**
     * @description DTO for Learning Program Plan selector rows.
     */
    public class PlanDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }
    
    /**
     * @description DTO that summarizes sync execution output counts.
     */
    public class SyncResult {
        @AuraEnabled public Integer offeringsMatched;
        @AuraEnabled public Integer offeringsCreated;
        @AuraEnabled public Integer junctionsCreated;
        @AuraEnabled public Integer junctionsSkipped;
    }
    
    /**
     * @description Returns active Learning Program Plans for sync selection.
     * @return List of plan DTOs containing plan id and name.
     */
    @AuraEnabled(cacheable=true)
    public static List<PlanDTO> getActiveLearningProgramPlans() {
        List<PlanDTO> out = new List<PlanDTO>();
        Map<String, Schema.SObjectField> fields = LearningProgramPlan.SObjectType.getDescribe().fields.getMap();
        
        String soql = 'SELECT Id, Name FROM LearningProgramPlan';
        List<String> whereParts = new List<String>();
        
        if (!whereParts.isEmpty()) {
            soql += ' WHERE ' + String.join(whereParts, ' AND ');
        }
        soql += ' ORDER BY Name';
        
        for (LearningProgramPlan p : Database.query(soql)) {
            PlanDTO dto = new PlanDTO();
            dto.id = p.Id;
            dto.name = p.Name;
            out.add(dto);
        }
        
        return out;
    }
    
    /**
     * @description Syncs selected Program Plans to Course Offerings for one Academic Session.
     * @param academicSessionId Target Academic Session Id.
     * @param planIds Selected Learning Program Plan ids.
     * @return Sync result counts for matched/created/skipped records.
     */
    @AuraEnabled
    public static SyncResult syncProgramPlansToSession(Id academicSessionId, List<Id> planIds) {
        if (academicSessionId == null) {
            throw new AuraHandledException('Academic Session is required.');
        }
        if (planIds == null || planIds.isEmpty()) {
            throw new AuraHandledException('Please select at least one Program Plan.');
        }
        
        try {
            SyncResult result = new SyncResult();
            result.offeringsMatched = 0;
            result.offeringsCreated = 0;
            result.junctionsCreated = 0;
            result.junctionsSkipped = 0;
            
            AcademicSession session = [
                SELECT Id, Name, Type, Sequence__c, Cadence_Period__c
                FROM AcademicSession
                WHERE Id = :academicSessionId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            Integer[] yearSeq = computeYearAndSequence(session.Type, session.Cadence_Period__c, session.Sequence__c);
            Integer targetYear = yearSeq[0];
            Integer targetSeq = yearSeq[1];
            String yearLabel = 'Year ' + String.valueOf(targetYear);
            String seqLabel = String.valueOf(targetSeq);
            
            Set<Id> templateIds = new Set<Id>();
            for (LearningPathwayTmplPgmPlan link : [
                SELECT LearningPathwayTemplateId, LearningProgramPlanId
                FROM LearningPathwayTmplPgmPlan
                WHERE LearningProgramPlanId IN :planIds
                WITH SECURITY_ENFORCED
            ]) {
                if (link.LearningPathwayTemplateId != null) {
                    templateIds.add(link.LearningPathwayTemplateId);
                }
            }
            
            Map<Id, Set<Id>> courseIdsByPlan = new Map<Id, Set<Id>>();
            Map<String, String> categoryByPlanCourse = new Map<String, String>();
            Set<Id> allCourseIds = new Set<Id>();
            
            if (!templateIds.isEmpty()) {
                for (LearningPathwayTemplateItem item : [
                    SELECT LearningProgramPlanRequirement.LearningProgramPlanId,
                           LearningProgramPlanRequirement.Learning_Course__c,
                           LearningProgramPlanRequirement.Category,
                           LearningPathwayTemplateId,
                           Year,
                           Sequence__c
                    FROM LearningPathwayTemplateItem
                    WHERE LearningPathwayTemplateId IN :templateIds
                    AND LearningProgramPlanRequirement.LearningProgramPlanId IN :planIds
                    AND LearningProgramPlanRequirement.Learning_Course__c != null
                    AND Year = :yearLabel
                    AND Sequence__c = :seqLabel
                    WITH SECURITY_ENFORCED
                ]) {
                    Id planId = item.LearningProgramPlanRequirement.LearningProgramPlanId;
                    Id courseId = item.LearningProgramPlanRequirement.Learning_Course__c;
                    if (!courseIdsByPlan.containsKey(planId)) {
                        courseIdsByPlan.put(planId, new Set<Id>());
                    }
                    courseIdsByPlan.get(planId).add(courseId);
                    allCourseIds.add(courseId);
                    if (item.LearningProgramPlanRequirement == null ||
                    String.isBlank(item.LearningProgramPlanRequirement.Category)) {
                        continue;
                    }
                    String key = String.valueOf(planId) + ':' + String.valueOf(courseId);
                    if (categoryByPlanCourse.containsKey(key)) {continue;}
                    categoryByPlanCourse.put(key, item.LearningProgramPlanRequirement.Category);
                }
            }
            
            if (allCourseIds.isEmpty()) {
                throw new AuraHandledException(
                    'No curriculum items found for ' + yearLabel + ' / Sequence ' + seqLabel +
                    '. Check Learning Pathway Template Items or Academic Session cadence.'
                    );
            }
            
            Map<String, Schema.SObjectField> offeringFields = CourseOffering.SObjectType.getDescribe().fields.getMap();
            String offeringCourseTypeField = firstField(offeringFields, new List<String>{
                'Course_Type__c',
                'CourseType'
            });
            String offeringCreditField = firstField(offeringFields, new List<String>{
                'Credit__c',
                'Credit'
            });
            
            String existingOfferingSoql = 'SELECT Id, LearningCourseId' +
                (offeringCourseTypeField != null ? ', ' + offeringCourseTypeField : '') +
                (offeringCreditField != null ? ', ' + offeringCreditField : '') +
                ' FROM CourseOffering' +
                ' WHERE AcademicSessionId = :academicSessionId' +
                ' AND LearningCourseId IN :allCourseIds' +
                ' WITH USER_MODE';
            List<CourseOffering> offerings = Database.query(existingOfferingSoql);
            
            Map<Id, List<CourseOffering>> offeringsByCourse = new Map<Id, List<CourseOffering>>();
            for (CourseOffering co : offerings) {
                if (!offeringsByCourse.containsKey(co.LearningCourseId)) {
                    offeringsByCourse.put(co.LearningCourseId, new List<CourseOffering>());
                }
                offeringsByCourse.get(co.LearningCourseId).add(co);
            }
            
            Set<Id> offeringIds = new Set<Id>();
            for (CourseOffering co : offerings) {
                offeringIds.add(co.Id);
            }
            result.offeringsMatched = offerings.size();
            
            Map<Id, Set<String>> existingTypeCreditKeysByCourse = new Map<Id, Set<String>>();
            for (CourseOffering co : offerings) {
                if (co.LearningCourseId == null) {continue;}
                if (!existingTypeCreditKeysByCourse.containsKey(co.LearningCourseId)) {
                    existingTypeCreditKeysByCourse.put(co.LearningCourseId, new Set<String>());
                }
                existingTypeCreditKeysByCourse.get(co.LearningCourseId).add(
                    buildTypeCreditKey(
                    offeringCourseTypeField != null ? co.get(offeringCourseTypeField) : null,
                offeringCreditField != null ? co.get(offeringCreditField) : null
                    )
                    );
            }
            
            List<CourseOffering> toInsertOfferings = new List<CourseOffering>();
            Id defaultRtId = getCourseOfferingDefaultRecordTypeId();
            Boolean canSetPlaceholder = offeringFields.containsKey('IsPlaceholder__c') &&
                offeringFields.get('IsPlaceholder__c').getDescribe().isCreateable();
            Boolean canSetOfferingCourseType = offeringCourseTypeField != null &&
                offeringFields.get(offeringCourseTypeField).getDescribe().isCreateable();
            Boolean canSetOfferingCredit = offeringCreditField != null &&
                offeringFields.get(offeringCreditField).getDescribe().isCreateable();
            
            Map<String, Schema.SObjectField> learningCourseFields = LearningCourse.SObjectType.getDescribe().fields.getMap();
            String type1Field = firstField(learningCourseFields, new List<String>{'CourseType', 'Course_Type__c'});
            String type2Field = firstField(learningCourseFields, new List<String>{'Course_Type_2__c'});
            String type3Field = firstField(learningCourseFields, new List<String>{'Course_Type_3__c'});
            String credit1Field = firstField(learningCourseFields, new List<String>{'Credit_1__c', 'Credit'});
            String credit2Field = firstField(learningCourseFields, new List<String>{'Credit_2__c'});
            String credit3Field = firstField(learningCourseFields, new List<String>{'Credit_3__c'});
            
            String courseSoql = 'SELECT Id, Name, CourseNumber' +
                (type1Field != null ? ', ' + type1Field : '') +
                (type2Field != null ? ', ' + type2Field : '') +
                (type3Field != null ? ', ' + type3Field : '') +
                (credit1Field != null ? ', ' + credit1Field : '') +
                (credit2Field != null ? ', ' + credit2Field : '') +
                (credit3Field != null ? ', ' + credit3Field : '') +
                ' FROM LearningCourse WHERE Id IN :allCourseIds WITH USER_MODE';
            Map<Id, SObject> courseById = new Map<Id, SObject>(Database.query(courseSoql));
            
            for (Id courseId : allCourseIds) {
                SObject lc = courseById.get(courseId);
                List<TypeCreditPair> desiredPairs = buildDesiredTypeCreditPairs(
                    lc,
                type1Field,
                type2Field,
                type3Field,
                credit1Field,
                credit2Field,
                credit3Field
                    );
                if (!existingTypeCreditKeysByCourse.containsKey(courseId)) {
                    existingTypeCreditKeysByCourse.put(courseId, new Set<String>());
                }
                Set<String> existingKeys = existingTypeCreditKeysByCourse.get(courseId);
                
                for (TypeCreditPair pair : desiredPairs) {
                    if (pair == null || existingKeys.contains(pair.key)) {continue;}
                    CourseOffering co = new CourseOffering();
                    if (defaultRtId != null) {
                        co.RecordTypeId = defaultRtId;
                    }
                    co.AcademicSessionId = academicSessionId;
                    co.LearningCourseId = courseId;
                    if (canSetPlaceholder) {
                        co.put('IsPlaceholder__c', true);
                    }
                    if (canSetOfferingCourseType && String.isNotBlank(pair.courseType)) {
                        co.put(offeringCourseTypeField, pair.courseType);
                    }
                    if (canSetOfferingCredit && pair.credit != null) {
                        co.put(offeringCreditField, pair.credit);
                    }
                    
                    String courseNumber = lc != null && lc.get('CourseNumber') != null ? String.valueOf(lc.get('CourseNumber')) : null;
                    String courseName = lc != null && lc.get('Name') != null ? String.valueOf(lc.get('Name')) : null;
                    String label = String.isNotBlank(courseNumber) ? courseNumber : courseName;
                    if (String.isNotBlank(label) && String.isNotBlank(courseName) && label != courseName) {
                        co.Name = label + ' - ' + courseName + (String.isNotBlank(pair.courseType) ? ' - ' + pair.courseType : '');
                    } else if (String.isNotBlank(label)) {
                        co.Name = label + (String.isNotBlank(pair.courseType) ? ' - ' + pair.courseType : '');
                    }
                    toInsertOfferings.add(co);
                    existingKeys.add(pair.key);
                }
            }
            
            if (!toInsertOfferings.isEmpty()) {
                if (!CourseOffering.SObjectType.getDescribe().isCreateable()) {
                    throw new AuraHandledException('Create access is required for Course Offering.');
                }
                insert toInsertOfferings;
                result.offeringsCreated = toInsertOfferings.size();
                offerings.addAll(toInsertOfferings);
            }
            
            offeringsByCourse.clear();
            offeringIds.clear();
            for (CourseOffering co : offerings) {
                offeringIds.add(co.Id);
                if (!offeringsByCourse.containsKey(co.LearningCourseId)) {
                    offeringsByCourse.put(co.LearningCourseId, new List<CourseOffering>());
                }
                offeringsByCourse.get(co.LearningCourseId).add(co);
            }
            
            Map<String, Program_Plan_Course_Junction__c> existing = new Map<String, Program_Plan_Course_Junction__c>();
            if (!offeringIds.isEmpty()) {
                for (Program_Plan_Course_Junction__c j : [
                    SELECT Id, Learning_Program_Plan__c, Course_Offering__c
                    FROM Program_Plan_Course_Junction__c
                    WHERE Learning_Program_Plan__c IN :planIds
                    AND Course_Offering__c IN :offeringIds
                    WITH SECURITY_ENFORCED
                ]) {
                    existing.put(String.valueOf(j.Learning_Program_Plan__c) + ':' + String.valueOf(j.Course_Offering__c), j);
                }
            }
            
            List<Program_Plan_Course_Junction__c> toInsert = new List<Program_Plan_Course_Junction__c>();
            Map<String, Schema.SObjectField> junctionFields =
                Program_Plan_Course_Junction__c.SObjectType.getDescribe().fields.getMap();
            String enrollmentTypeField = firstField(junctionFields, new List<String>{
                'Enrollment_Type__c'
            });
            Boolean canSetEnrollmentType = enrollmentTypeField != null;
            
            for (Id planId : courseIdsByPlan.keySet()) {
                Set<Id> courseIds = courseIdsByPlan.get(planId);
                for (Id courseId : courseIds) {
                    List<CourseOffering> relatedOfferings = offeringsByCourse.get(courseId);
                    if (relatedOfferings == null || relatedOfferings.isEmpty()) {continue;}
                    for (CourseOffering co : relatedOfferings) {
                        String key = String.valueOf(planId) + ':' + String.valueOf(co.Id);
                        if (existing.containsKey(key)) {
                            result.junctionsSkipped++;
                            continue;
                        }
                        Program_Plan_Course_Junction__c junction = new Program_Plan_Course_Junction__c(
                            Learning_Program_Plan__c = planId,
                        Course_Offering__c = co.Id
                            );
                        if (canSetEnrollmentType) {
                            String categoryKey = String.valueOf(planId) + ':' + String.valueOf(courseId);
                            String category = categoryByPlanCourse.get(categoryKey);
                            if (String.isNotBlank(category)) {
                                junction.put(enrollmentTypeField, category);
                            }
                        }
                        toInsert.add(junction);
                    }
                }
            }
            
            if (!toInsert.isEmpty()) {
                if (!Program_Plan_Course_Junction__c.SObjectType.getDescribe().isCreateable()) {
                    throw new AuraHandledException('Create access is required for Program Plan Course Junction.');
                }
                insert toInsert;
                result.junctionsCreated = toInsert.size();
            }
            
            return result;
        } catch (Exception e) {
            logSyncError(academicSessionId, planIds, e);
            if (e instanceof AuraHandledException) {
                throw (AuraHandledException)e;
            }
            throw new AuraHandledException('Sync failed. Please check audit logs for details.');
        }
    }
    
    /**
     * @description Computes year label index and sequence-within-year from cadence metadata.
     * @param cadenceType Cadence type (Semester/Trimester/Quarter).
     * @param cadencePeriod Cadence period label on session.
     * @param sessionSequence Session sequence fallback value.
     * @return Integer array where index 0 = year number and index 1 = sequence in year.
     */
    private static Integer[] computeYearAndSequence(String cadenceType, String cadencePeriod, String sessionSequence) {
        Integer perYear = cadenceType == 'Trimester' ? 3 : (cadenceType == 'Quarter' ? 4 : 2);
        Integer periodNum = null;
        if (String.isNotBlank(cadencePeriod)) {
            List<String> parts = cadencePeriod.split(' ');
            if (!parts.isEmpty()) {
                try {
                    periodNum = Integer.valueOf(parts[parts.size() - 1]);
                } catch (Exception e) {
                    periodNum = null;
                }
            }
        }
        if (periodNum == null && String.isNotBlank(sessionSequence)) {
            try {
                periodNum = Integer.valueOf(sessionSequence);
            } catch (Exception e) {
                periodNum = 1;
            }
        }
        if (periodNum == null) {periodNum = 1;}
        
        Integer yearNum = ((periodNum - 1) / perYear) + 1;
        Integer seqWithinYear = Math.mod((periodNum - 1), perYear) + 1;
        return new Integer[] { yearNum, seqWithinYear };
    }
    
    /**
     * @description Resolves and caches CourseOffering record type id for default creation.
     * @return CourseOffering record type id or null when not found.
     */
    private static Id getCourseOfferingDefaultRecordTypeId() {
        if (courseOfferingDefaultRtId != null) {
            return courseOfferingDefaultRtId;
        }
        if (!RecordType.SObjectType.getDescribe().isAccessible()) {
            throw new AuraHandledException('Read access is required for RecordType.');
        }
        List<RecordType> rts = [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'CourseOffering'
            AND DeveloperName = 'Default'
            WITH USER_MODE
            LIMIT 2
        ];
        for (RecordType rt : rts) {
            if (rt.DeveloperName == 'Default') {
                courseOfferingDefaultRtId = rt.Id;
                return courseOfferingDefaultRtId;
            }
        }
        
        return null;
    }
    
    /**
     * @description Builds desired unique type/credit combinations from up to 3 learning-course slots.
     * @param learningCourseRow Dynamic LearningCourse row.
     * @param type1Field Type slot 1 field api name.
     * @param type2Field Type slot 2 field api name.
     * @param type3Field Type slot 3 field api name.
     * @param credit1Field Credit slot 1 field api name.
     * @param credit2Field Credit slot 2 field api name.
     * @param credit3Field Credit slot 3 field api name.
     * @return Unique pair list; when no slot has values, returns one blank pair.
     */
    private static List<TypeCreditPair> buildDesiredTypeCreditPairs(
        SObject learningCourseRow,
    String type1Field,
    String type2Field,
    String type3Field,
    String credit1Field,
    String credit2Field,
    String credit3Field
    ) {
        List<TypeCreditPair> out = new List<TypeCreditPair>();
        Set<String> seen = new Set<String>();
        List<String> typeFields = new List<String>{type1Field, type2Field, type3Field};
        List<String> creditFields = new List<String>{credit1Field, credit2Field, credit3Field};
        
        for (Integer i = 0; i < typeFields.size(); i++) {
            String typeField = typeFields[i];
            String creditField = creditFields[i];
            Object typeRaw = (learningCourseRow != null && String.isNotBlank(typeField)) ? learningCourseRow.get(typeField) : null;
            Object creditRaw = (learningCourseRow != null && String.isNotBlank(creditField)) ? learningCourseRow.get(creditField) : null;
            
            String courseType = typeRaw == null ? null : String.valueOf(typeRaw).trim();
            Decimal credit = toDecimal(creditRaw);
            if (String.isBlank(courseType) && credit == null) {continue;}
            
            String key = buildTypeCreditKey(courseType, credit);
            if (seen.contains(key)) {continue;}
            seen.add(key);
            
            TypeCreditPair pair = new TypeCreditPair();
            pair.courseType = String.isBlank(courseType) ? null : courseType;
            pair.credit = credit;
            pair.key = key;
            out.add(pair);
        }
        
        if (out.isEmpty()) {
            TypeCreditPair blank = new TypeCreditPair();
            blank.courseType = null;
            blank.credit = null;
            blank.key = buildTypeCreditKey(null, null);
            out.add(blank);
        }
        
        return out;
    }
    
    /**
     * @description Creates a normalized key used to compare existing and requested type/credit rows.
     * @param courseType Course type value.
     * @param credit Credit value.
     * @return Normalized key string.
     */
    private static String buildTypeCreditKey(Object courseType, Object credit) {
        String typePart = courseType == null ? '' : String.valueOf(courseType).trim().toLowerCase();
        Decimal creditDecimal = toDecimal(credit);
        String creditPart = creditDecimal == null ? '' : String.valueOf(creditDecimal);
        return typePart + '|' + creditPart;
    }
    
    /**
     * @description Converts arbitrary value to Decimal when possible.
     * @param raw Input value.
     * @return Decimal value or null.
     */
    private static Decimal toDecimal(Object raw) {
        if (raw == null) {return null;}
        if (raw instanceof Decimal) {return (Decimal) raw;}
        try {
            return Decimal.valueOf(String.valueOf(raw).trim());
        } catch (Exception e) {
            return null;
        }
    }
    
    /**
     * @description Returns the first field name present in describe map from candidate list.
     * @param fields Describe field map.
     * @param candidates Candidate field API names in priority order.
     * @return Matching field API name or null.
     */
    private static String firstField(Map<String, Schema.SObjectField> fields, List<String> candidates) {
        if (fields == null || candidates == null) {return null;}
        for (String c : candidates) {
            if (fields.containsKey(c)) {return c;}
        }
        return null;
    }
    
    /**
     * @description Writes sync error details to audit log record.
     * @param academicSessionId Session context id for record link.
     * @param planIds Selected plan ids serialized as request payload.
     * @param e Exception raised during sync.
     */
    private static void logSyncError(Id academicSessionId, List<Id> planIds, Exception e) {
        try {
            String planPayload = (planIds == null) ? null : JSON.serialize(planIds);
            KenAuditLogHelper.auditLogRecord('Course Offering Sync', 'CourseOfferingSyncController')
                .setRecordId(academicSessionId == null ? null : String.valueOf(academicSessionId))
                .setRequestBody(planPayload)
                .setErrorMessage(e == null ? 'Unknown error' : e.getMessage())
                .setStackTrace(e == null ? null : e.getStackTraceString())
                .create();
        } catch (Exception ignoreLogFailure) {
            KenAuditLogHelper.auditLogRecord('Course Offering Sync', 'CourseOfferingSyncController.logSyncError')
                .setRecordId(academicSessionId == null ? null : String.valueOf(academicSessionId))
                .setErrorMessage('Primary error logging failed: ' + ignoreLogFailure.getMessage())
                .setStackTrace(ignoreLogFailure.getStackTraceString())
                .create();
            
        }
    }
}