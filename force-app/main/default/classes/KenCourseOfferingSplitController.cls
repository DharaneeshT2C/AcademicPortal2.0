/**
 * ************************************************************************************************
 * @className  KenCourseOfferingSplitController
 *
 * @description
 *  Controller used by split-screen UI to split placeholder Course Offering records into
 *  active planned offerings and re-link related program-plan junction records.
 *
 *  Responsibilities:
 *  - Fetch session/term/offering data required by the split UI
 *  - Split placeholder offerings into individual and combined offerings
 *  - Rebuild Program_Plan_Course_Junction__c links for new offerings
 *  - Retire placeholder offering after successful split
 *  - Enforce object-level CRUD checks before SOQL/DML operations
 *
 * @author      Sureka A R K
 * @createdOn   Feb 09, 2026
 *
 * @history
 * ------------------------------------------------------------------------------------------------
 * Version   Date           Author          Description
 * 1.0       Feb 09, 2026   Sureka A R K    Added docs and CRUD safeguards
 * ************************************************************************************************
 */
@suppressWarnings('PMD.ExcessiveParameterList,PMD.CognitiveComplexity,PMD.EagerlyLoadedDescribeSObjectResult,PMD.NcssMethodCount,PMD.StdCyclomaticComplexity,PMD.CyclomaticComplexity,PMD.ApexSOQLInjection')
public with sharing class KenCourseOfferingSplitController {
    private static Id courseOfferingActivePlannedRtId;
    
    /**
     * @description DTO for Learning Program Plan details shown in split UI.
     */
    public class ProgramPlanDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String enrollmentType;
    }
    
    /**
     * @description Input payload for one plan inside split request.
     */
    public class PlanSplitInput {
        @AuraEnabled public Id planId;
        @AuraEnabled public String planName;
        @AuraEnabled public String enrollmentType;
        @AuraEnabled public String type;
        @AuraEnabled public Integer sections;
        @AuraEnabled public List<String> selectedSections;
        @AuraEnabled public Integer offeringCount;
        @AuraEnabled public Integer capacity;
    }
    
    /**
     * @description Top-level request payload from split screen.
     */
    public class SplitRequest {
        @AuraEnabled public Id placeholderOfferingId;
        @AuraEnabled public String combinedGroupName;
        @AuraEnabled public Integer combinedOfferingCount;
        @AuraEnabled public Integer combinedSections;
        @AuraEnabled public Integer combinedCapacity;
        @AuraEnabled public String enrollmentType;
        @AuraEnabled public List<PlanSplitInput> plans;
    }
    
    /**
     * @description DTO representing Active Planned Course Offering row in UI table.
     */
    public class CourseOfferingViewDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String courseOfferingName;
        @AuraEnabled public String courseNumber;
        @AuraEnabled public String courseName;
        @AuraEnabled public Decimal enrollmentCapacity;
        @AuraEnabled public Decimal enrolleeCount;
        @AuraEnabled public String courseType;
        @AuraEnabled public String offeringType;
    }
    
    /**
     * @description DTO representing participant row for a Course Offering.
     */
    public class CourseOfferingParticipantViewDTO {
        @AuraEnabled public Id participantId;
        @AuraEnabled public String participantName;
        @AuraEnabled public String participantEmail;
        @AuraEnabled public String participationStatus;
    }
    
    /**
     * @description DTO representing placeholder/default Course Offering row in create screen.
     */
    public class PlaceholderOfferingDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String courseNumber;
        @AuraEnabled public String courseName;
        @AuraEnabled public String courseType;
        @AuraEnabled public String enrollmentType;
    }
    
    /**
     * @description Returns enrollment types mapped to a given course offering.
     * @param courseOfferingId Course Offering Id.
     * @return Unique list of enrollment type values.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getEnrollmentTypesForOffering(Id courseOfferingId) {
        if (courseOfferingId == null) {return new List<String>();}
        assertReadable(Program_Plan_Course_Junction__c.SObjectType, 'Read access is required for Program Plan Course Junction.');
        Map<String, Schema.SObjectField> junctionFields =
            Program_Plan_Course_Junction__c.SObjectType.getDescribe().fields.getMap();
        String enrollmentTypeField = firstField(junctionFields, new List<String>{
            'Enrollment_Type__c'
        });
        if (enrollmentTypeField == null) {return new List<String>();}
        
        String soql = 'SELECT ' + enrollmentTypeField +
            ' FROM Program_Plan_Course_Junction__c' +
            ' WHERE Course_Offering__c = :courseOfferingId' +
            ' AND ' + enrollmentTypeField + ' != null' +
            ' ';
        
        Set<String> types = new Set<String>();
        for (Program_Plan_Course_Junction__c j : Database.query(soql)) {
            Object val = j.get(enrollmentTypeField);
            if (val != null) {
                types.add(String.valueOf(val));
            }
        }
        return new List<String>(types);
    }
    
    private class OfferingPlanLink {
        CourseOffering offering;
        List<Id> planIds = new List<Id>();
    }
    
    /**
     * @description Returns active Academic Terms for dropdown.
     * @return Active AcademicTerm records ordered by latest year.
     */
    @AuraEnabled(cacheable=true)
    public static List<AcademicTerm> getAcademicTerms() {
        assertReadable(AcademicTerm.SObjectType, 'Read access is required for Academic Term.');
        return [
            SELECT Id, Name, Start_Year__c, End_Year__c, Sequence__c, AcademicYearId
            FROM AcademicTerm
            WHERE IsActive = true
            
            ORDER BY Start_Year__c DESC, Name
        ];
    }
    
    /**
     * @description Returns active sessions under an Academic Term.
     * @param academicTermId Academic Term Id.
     * @return Active AcademicSession records for the term.
     */
    @AuraEnabled(cacheable=true)
    public static List<AcademicSession> getAcademicSessionsByTerm(Id academicTermId) {
        if (academicTermId == null) {return new List<AcademicSession>();}
        assertReadable(AcademicSession.SObjectType, 'Read access is required for Academic Session.');
        return [
            SELECT Id, Name, Type, Sequence__c, IsActive, AcademicTermId, Cadence_Period__c
            FROM AcademicSession
            WHERE AcademicTermId = :academicTermId
            AND IsActive = true
            
            ORDER BY Name
        ];
    }
    
    /**
     * @description Returns placeholder offerings for selected session.
     * @param academicSessionId Academic Session Id.
     * @return Placeholder CourseOffering records not yet split.
     */
    @AuraEnabled(cacheable=true)
    public static List<PlaceholderOfferingDTO> getPlaceholderOfferings(Id academicSessionId) {
        if (academicSessionId == null) {return new List<PlaceholderOfferingDTO>();}
        assertReadable(CourseOffering.SObjectType, 'Read access is required for Course Offering.');
        Map<String, Schema.SObjectField> learningCourseFields = LearningCourse.SObjectType.getDescribe().fields.getMap();
        String learningCourseTypeField = firstField(learningCourseFields, new List<String>{
            'CourseType',
            'Course_Type__c'
        });
        String learningCourseType2Field = firstField(learningCourseFields, new List<String>{
            'Course_Type_2__c'
        });
        String learningCourseType3Field = firstField(learningCourseFields, new List<String>{
            'Course_Type_3__c'
        });
        Map<String, Schema.SObjectField> offeringFields = CourseOffering.SObjectType.getDescribe().fields.getMap();
        String offeringCourseTypeField = firstField(offeringFields, new List<String>{
            'Course_Type__c',
            'CourseType'
        });
        
        Map<String, Schema.SObjectField> fields = CourseOffering.SObjectType.getDescribe().fields.getMap();
        List<String> whereParts = new List<String>();
        whereParts.add('AcademicSessionId = :academicSessionId');
        
        if (fields.containsKey('IsPlaceholder__c')) {
            whereParts.add('IsPlaceholder__c = true');
        } else {
            Id activePlannedRtId = getCourseOfferingRecordTypeId('Active_Planned');
            if (activePlannedRtId != null) {
                whereParts.add('RecordTypeId != :activePlannedRtId');
            }
        }
        if (fields.containsKey('SplitCompleted__c')) {
            whereParts.add('(SplitCompleted__c = false OR SplitCompleted__c = null)');
        }
        
        String soql = 'SELECT Id, Name, LearningCourseId, AcademicSessionId, LearningCourse.Name, LearningCourse.CourseNumber' +
            (String.isNotBlank(offeringCourseTypeField) ? ', ' + offeringCourseTypeField : '') +
            (String.isNotBlank(learningCourseTypeField) ? ', LearningCourse.' + learningCourseTypeField : '') +
            (String.isNotBlank(learningCourseType2Field) ? ', LearningCourse.' + learningCourseType2Field : '') +
            (String.isNotBlank(learningCourseType3Field) ? ', LearningCourse.' + learningCourseType3Field : '') +
            ' FROM CourseOffering WHERE ' +
            String.join(whereParts, ' AND ') + '  ORDER BY Name';
        List<CourseOffering> offerings = Database.query(soql);
        if (offerings.isEmpty()) {
            return new List<PlaceholderOfferingDTO>();
        }
        
        Map<Id, String> enrollmentTypeByOffering = new Map<Id, String>();
        if (Program_Plan_Course_Junction__c.SObjectType.getDescribe().isAccessible()) {
            Map<String, Schema.SObjectField> junctionFields =
                Program_Plan_Course_Junction__c.SObjectType.getDescribe().fields.getMap();
            String enrollmentTypeField = firstField(junctionFields, new List<String>{
                'Enrollment_Type__c'
            });
            if (enrollmentTypeField != null) {
                Set<Id> offeringIds = new Set<Id>();
                for (CourseOffering co : offerings) {
                    offeringIds.add(co.Id);
                }
                String jSoql = 'SELECT Course_Offering__c, ' + enrollmentTypeField +
                    ' FROM Program_Plan_Course_Junction__c' +
                    ' WHERE Course_Offering__c IN :offeringIds' +
                    ' ';
                Map<Id, Set<String>> typesByOffering = new Map<Id, Set<String>>();
                for (Program_Plan_Course_Junction__c j : Database.query(jSoql)) {
                    Id offeringId = j.Course_Offering__c;
                    if (offeringId == null || j.get(enrollmentTypeField) == null) {continue;}
                    String val = String.valueOf(j.get(enrollmentTypeField)).trim();
                    if (String.isBlank(val)) {continue;}
                    if (!typesByOffering.containsKey(offeringId)) {
                        typesByOffering.put(offeringId, new Set<String>());
                    }
                    typesByOffering.get(offeringId).add(val);
                }
                for (Id offeringId : typesByOffering.keySet()) {
                    List<String> types = new List<String>(typesByOffering.get(offeringId));
                    types.sort();
                    enrollmentTypeByOffering.put(offeringId, String.join(types, ', '));
                }
            }
        }
        
        List<PlaceholderOfferingDTO> out = new List<PlaceholderOfferingDTO>();
        for (CourseOffering co : offerings) {
            PlaceholderOfferingDTO dto = new PlaceholderOfferingDTO();
            dto.id = co.Id;
            dto.name = co.Name;
            dto.courseNumber = co.LearningCourse != null ? co.LearningCourse.CourseNumber : null;
            dto.courseName = co.LearningCourse != null ? co.LearningCourse.Name : null;
            String offeringType = null;
            if (String.isNotBlank(offeringCourseTypeField) && co.get(offeringCourseTypeField) != null) {
                offeringType = String.valueOf(co.get(offeringCourseTypeField)).trim();
            }
            if (String.isNotBlank(offeringType)) {
                // Row-level type on CourseOffering is authoritative for filtering.
                dto.courseType = offeringType;
            } else {
                Set<String> courseTypes = new Set<String>();
                if (co.LearningCourse != null && String.isNotBlank(learningCourseTypeField) && co.LearningCourse.get(learningCourseTypeField) != null) {
                    String typeVal = String.valueOf(co.LearningCourse.get(learningCourseTypeField)).trim();
                    if (String.isNotBlank(typeVal)) {courseTypes.add(typeVal);}
                }
                if (co.LearningCourse != null && String.isNotBlank(learningCourseType2Field) && co.LearningCourse.get(learningCourseType2Field) != null) {
                    String typeVal = String.valueOf(co.LearningCourse.get(learningCourseType2Field)).trim();
                    if (String.isNotBlank(typeVal)) {courseTypes.add(typeVal);}
                }
                if (co.LearningCourse != null && String.isNotBlank(learningCourseType3Field) && co.LearningCourse.get(learningCourseType3Field) != null) {
                    String typeVal = String.valueOf(co.LearningCourse.get(learningCourseType3Field)).trim();
                    if (String.isNotBlank(typeVal)) {courseTypes.add(typeVal);}
                }
                if (!courseTypes.isEmpty()) {
                    List<String> types = new List<String>(courseTypes);
                    types.sort();
                    dto.courseType = String.join(types, ', ');
                }
            }
            dto.enrollmentType = enrollmentTypeByOffering.containsKey(co.Id)
                ? enrollmentTypeByOffering.get(co.Id)
                : null;
            out.add(dto);
        }
        return out;
    }
    
    /**
     * @description Returns program plans linked to a course offering.
     * @param courseOfferingId Course Offering Id.
     * @return Program plan DTO list with mapped enrollment type.
     */
    @AuraEnabled(cacheable=true)
    public static List<ProgramPlanDTO> getProgramPlansForOffering(Id courseOfferingId) {
        if (courseOfferingId == null) {return new List<ProgramPlanDTO>();}
        assertReadable(Program_Plan_Course_Junction__c.SObjectType, 'Read access is required for Program Plan Course Junction.');
        assertReadable(LearningProgramPlan.SObjectType, 'Read access is required for Learning Program Plan.');
        
        List<ProgramPlanDTO> out = new List<ProgramPlanDTO>();
        List<Id> planIds = new List<Id>();
        Map<Id, String> enrollmentTypeByPlan = new Map<Id, String>();
        Map<String, Schema.SObjectField> junctionFields =
            Program_Plan_Course_Junction__c.SObjectType.getDescribe().fields.getMap();
        String enrollmentTypeField = firstField(junctionFields, new List<String>{
            'Enrollment_Type__c'
        });
        
        String jSoql = 'SELECT Learning_Program_Plan__c' +
            (enrollmentTypeField != null ? ', ' + enrollmentTypeField : '') +
            ' FROM Program_Plan_Course_Junction__c' +
            ' WHERE Course_Offering__c = :courseOfferingId' +
            ' ';
        for (Program_Plan_Course_Junction__c j : Database.query(jSoql)) {
            Id planId = j.Learning_Program_Plan__c;
            if (planId == null) {continue;}
            planIds.add(planId);
            if (enrollmentTypeField == null || enrollmentTypeByPlan.containsKey(planId)) {continue;}
            Object val = j.get(enrollmentTypeField);
            if (val == null) {continue;}
            enrollmentTypeByPlan.put(planId, String.valueOf(val));
        }
        
        if (planIds.isEmpty()) {return out;}
        
        Map<Id, LearningProgramPlan> plans = new Map<Id, LearningProgramPlan>([
            SELECT Id, Name
            FROM LearningProgramPlan
            WHERE Id IN :planIds
            
        ]);
        
        for (Id pid : planIds) {
            LearningProgramPlan p = plans.get(pid);
            if (p == null) {continue;}
            ProgramPlanDTO dto = new ProgramPlanDTO();
            dto.id = p.Id;
            dto.name = p.Name;
            dto.enrollmentType = enrollmentTypeByPlan.get(p.Id);
            out.add(dto);
        }
        
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getSectionsByProgramPlan(Id learningProgramPlanId) {
        if (learningProgramPlanId == null) {return new List<String>();}
        assertReadable(LearnerProgram.SObjectType, 'Read access is required for Learner Program.');

        List<String> sections = new List<String>();
        for (AggregateResult ar : [
            SELECT ClassCohort cohort
            FROM LearnerProgram
            WHERE LearningProgramPlanId = :learningProgramPlanId
            AND ClassCohort != null
            
            GROUP BY ClassCohort
            ORDER BY ClassCohort
        ]) {
            String cohort = (String) ar.get('cohort');
            if (String.isNotBlank(cohort)) {
                sections.add(cohort);
            }
        }
        return sections;
    }
    
    /**
     * @description Returns active planned offerings for selected session with optional enrollment-type filter.
     * @param academicSessionId Academic Session Id.
     * @param enrollmentType Enrollment Type filter value or 'All'.
     * @return Course Offering view DTO list.
     */
    @AuraEnabled(cacheable=true)
    public static List<CourseOfferingViewDTO> getActivePlannedOfferings(Id academicSessionId, String enrollmentType) {
        if (academicSessionId == null) {return new List<CourseOfferingViewDTO>();}
        assertReadable(CourseOffering.SObjectType, 'Read access is required for Course Offering.');
        assertReadable(Program_Plan_Course_Junction__c.SObjectType, 'Read access is required for Program Plan Course Junction.');
        Id activePlannedRtId = getCourseOfferingRecordTypeId('Active_Planned');
        if (activePlannedRtId == null) {return new List<CourseOfferingViewDTO>();}
        
        Map<String, Schema.SObjectField> fields = CourseOffering.SObjectType.getDescribe().fields.getMap();
        String capacityField = firstField(fields, new List<String>{
            'EnrollmentCapacity'
        });
        String enrolleeField = firstField(fields, new List<String>{
            'EnrolleeCount'
        });
        String courseTypeField = firstField(fields, new List<String>{
            'Course_Type__c',
            'CourseType'
        });
        String offeringTypeField = fields.containsKey('OfferingType__c') ? 'OfferingType__c' : null;
        
        List<String> selectParts = new List<String>{
            'Id',
            'Name',
            'LearningCourse.CourseNumber',
            'LearningCourse.Name'
        };
        if (capacityField != null) {selectParts.add(capacityField);}
        if (enrolleeField != null) {selectParts.add(enrolleeField);}
        if (courseTypeField != null) {selectParts.add(courseTypeField);}
        if (offeringTypeField != null) {selectParts.add(offeringTypeField);}
        
        Set<Id> filteredOfferingIds = null;
        if (String.isNotBlank(enrollmentType) && enrollmentType != 'All') {
            Map<String, Schema.SObjectField> junctionFields =
                Program_Plan_Course_Junction__c.SObjectType.getDescribe().fields.getMap();
            String enrollmentTypeField = firstField(junctionFields, new List<String>{
            'Enrollment_Type__c'            });
            if (enrollmentTypeField == null) {
                KenAuditLogHelper.auditLogRecord(
                    'Course Offering Split',
                'Class:KenCourseOfferingSplitController'
                    )
                    .setErrorMessage('KenCourseOfferingSplitController.getActivePlannedOfferings: enrollment type field not found on Program_Plan_Course_Junction__c; filter skipped.')
                    .create();
            } else {
                String jSoql = 'SELECT Course_Offering__c FROM Program_Plan_Course_Junction__c' +
                    ' WHERE Course_Offering__r.AcademicSessionId = :academicSessionId' +
                    ' AND Course_Offering__r.RecordTypeId = :activePlannedRtId' +
                    ' AND ' + enrollmentTypeField + ' = :enrollmentType' +
                    ' ';
                filteredOfferingIds = new Set<Id>();
                for (Program_Plan_Course_Junction__c j : Database.query(jSoql)) {
                    Id offeringId = j.Course_Offering__c;
                    if (offeringId == null) {continue;}
                    filteredOfferingIds.add(offeringId);
                }
                if (filteredOfferingIds.isEmpty()) {
                    return new List<CourseOfferingViewDTO>();
                }
            }
        }
        
        String soql = 'SELECT ' + String.join(selectParts, ',') +
            ' FROM CourseOffering' +
            ' WHERE AcademicSessionId = :academicSessionId' +
            ' AND RecordTypeId = :activePlannedRtId' +
            (filteredOfferingIds != null ? ' AND Id IN :filteredOfferingIds' : '') +
            ' ' +
            ' ORDER BY LearningCourse.CourseNumber, LearningCourse.Name';
        
        List<CourseOfferingViewDTO> out = new List<CourseOfferingViewDTO>();
        for (CourseOffering co : Database.query(soql)) {
            CourseOfferingViewDTO dto = new CourseOfferingViewDTO();
            dto.id = co.Id;
            dto.courseOfferingName = co.Name;
            dto.courseNumber = co.LearningCourse != null ? co.LearningCourse.CourseNumber : null;
            dto.courseName = co.LearningCourse != null ? co.LearningCourse.Name : null;
            if (capacityField != null && co.get(capacityField) != null) {
                dto.enrollmentCapacity = (Decimal) co.get(capacityField);
            }
            if (enrolleeField != null && co.get(enrolleeField) != null) {
                dto.enrolleeCount = (Decimal) co.get(enrolleeField);
            }
            if (courseTypeField != null && co.get(courseTypeField) != null) {
                dto.courseType = String.valueOf(co.get(courseTypeField));
            }
            if (offeringTypeField != null && co.get(offeringTypeField) != null) {
                dto.offeringType = String.valueOf(co.get(offeringTypeField));
            }
            out.add(dto);
        }
        return out;
    }
    
    /**
     * @description Returns participants linked to a Course Offering.
     * @param courseOfferingId Course Offering Id.
     * @return Participant DTO list.
     */
    @AuraEnabled(cacheable=true)
    public static List<CourseOfferingParticipantViewDTO> getCourseOfferingParticipants(Id courseOfferingId) {
        if (courseOfferingId == null) {
            return new List<CourseOfferingParticipantViewDTO>();
        }
        assertReadable(CourseOfferingParticipant.SObjectType, 'Read access is required for Course Offering Participant.');
        
        List<CourseOfferingParticipantViewDTO> out = new List<CourseOfferingParticipantViewDTO>();
        for (CourseOfferingParticipant cop : [
            SELECT Id,
                   ParticipantContact.Name,
                   ParticipantContact.Email,
                   ParticipationStatus
            FROM CourseOfferingParticipant
            WHERE CourseOfferingId = :courseOfferingId
            
            ORDER BY ParticipantContact.Name
        ]) {
            CourseOfferingParticipantViewDTO dto = new CourseOfferingParticipantViewDTO();
            dto.participantId = cop.Id;
            dto.participantName = cop.ParticipantContact != null ? cop.ParticipantContact.Name : null;
            dto.participantEmail = cop.ParticipantContact != null ? cop.ParticipantContact.Email : null;
            dto.participationStatus = cop.ParticipationStatus;
            out.add(dto);
        }
        return out;
    }
    
    /**
     * @description Splits one placeholder Course Offering into active planned offerings.
     * @param req Split request payload from UI.
     */
    @AuraEnabled
    public static void splitOfferings(SplitRequest req) {
        try {
            splitOfferingsInternal(req);
        } catch (Exception e) {
            KenAuditLogHelper.KenAuditLogCreator creator = KenAuditLogHelper.auditLogRecord(
                'Course Offering Split',
            'Class:KenCourseOfferingSplitController'
                );
            creator.setErrorMessage('KenCourseOfferingSplitController.splitOfferings failed: ' + e.getMessage());
            creator.setStackTrace(e.getStackTraceString());
            if (req != null && req.placeholderOfferingId != null) {
                creator.setRecordId(String.valueOf(req.placeholderOfferingId));
            }
            creator.create();
            throw e;
        }
    }
    
    /**
     * @description Core split implementation used by public entry points.
     * @param req Split request payload from UI.
     */
    private static void splitOfferingsInternal(SplitRequest req) {
        if (req == null || req.placeholderOfferingId == null) {
            throw new AuraHandledException('Placeholder offering id is required.');
        }
        assertReadable(CourseOffering.SObjectType, 'Read access is required for Course Offering.');
        assertReadable(AcademicSession.SObjectType, 'Read access is required for Academic Session.');
        assertReadable(LearningCourse.SObjectType, 'Read access is required for Learning Course.');
        assertReadable(Program_Plan_Course_Junction__c.SObjectType, 'Read access is required for Program Plan Course Junction.');
        assertCreateable(CourseOffering.SObjectType, 'Create access is required for Course Offering.');
        assertCreateable(Program_Plan_Course_Junction__c.SObjectType, 'Create access is required for Program Plan Course Junction.');
        assertUpdateable(CourseOffering.SObjectType, 'Update access is required for Course Offering.');
        assertDeletable(Program_Plan_Course_Junction__c.SObjectType, 'Delete access is required for Program Plan Course Junction.');
        
        if (!Schema.SObjectType.CourseOffering.isAccessible()) {
            throw new AuraHandledException('Read access is required for Course Offering.');
        }
        Map<String, Schema.SObjectField> offeringFields = CourseOffering.SObjectType.getDescribe().fields.getMap();
        String courseTypeField = firstField(offeringFields, new List<String>{
            'Course_Type__c',
            'CourseType'
        });
        String creditField = firstField(offeringFields, new List<String>{
            'Credit__c',
            'Credit'
        });
        Id placeholderOfferingId = req.placeholderOfferingId;
        
        String placeholderSoql = 'SELECT Id, Name, AcademicSessionId, LearningCourseId' +
            (courseTypeField != null ? ', ' + courseTypeField : '') +
            (creditField != null ? ', ' + creditField : '') +
            ' FROM CourseOffering' +
            ' WHERE Id = :placeholderOfferingId' +
            '  FOR UPDATE';
        List<SObject> placeholderRows = Database.query(placeholderSoql);
        if (placeholderRows.isEmpty()) {
            throw new AuraHandledException('Placeholder offering not found.');
        }
        CourseOffering placeholder = (CourseOffering) placeholderRows[0];
        
        if (placeholder.AcademicSessionId == null || placeholder.LearningCourseId == null) {
            throw new AuraHandledException('Placeholder offering is missing Academic Session or Learning Course.');
        }
        
        Object sourceCourseType = courseTypeField != null ? placeholder.get(courseTypeField) : null;
        Object sourceCredit = creditField != null ? placeholder.get(creditField) : null;
        
        if (offeringFields.containsKey('SplitCompleted__c')) {
            Object alreadySplit = placeholder.get('SplitCompleted__c');
            if (alreadySplit != null && (Boolean)alreadySplit) {
                throw new AuraHandledException('Split already completed for this placeholder.');
            }
        }
        
        AcademicSession session = [
            SELECT Id, Name
            FROM AcademicSession
            WHERE Id = :placeholder.AcademicSessionId
            
            LIMIT 1
        ];
        
        LearningCourse course = [
            SELECT Id, Name, CourseNumber
            FROM LearningCourse
            WHERE Id = :placeholder.LearningCourseId
            
            LIMIT 1
        ];
        
        String courseLabel = String.isNotBlank(course.CourseNumber) ? course.CourseNumber : course.Name;
        
        List<PlanSplitInput> plans = req.plans == null ? new List<PlanSplitInput>() : req.plans;
        List<PlanSplitInput> combinedPlans = new List<PlanSplitInput>();
        List<PlanSplitInput> individualPlans = new List<PlanSplitInput>();
        
        for (PlanSplitInput p : plans) {
            if (p == null || p.planId == null) {continue;}
            if (String.valueOf(p.type).equalsIgnoreCase('Combined')) {
                combinedPlans.add(p);
            } else {
                individualPlans.add(p);
            }
        }
        
        Id activePlannedRtId = getCourseOfferingRecordTypeId('Active_Planned');
        List<CourseOffering> newOfferings = new List<CourseOffering>();
        List<OfferingPlanLink> offeringLinks = new List<OfferingPlanLink>();
        List<Program_Plan_Course_Junction__c> newJunctions = new List<Program_Plan_Course_Junction__c>();
        Boolean placeholderReused = false;
        Id placeholderId = placeholder.Id;
        Map<String, Schema.SObjectField> junctionFields =
            Program_Plan_Course_Junction__c.SObjectType.getDescribe().fields.getMap();
        String enrollmentTypeField = firstField(junctionFields, new List<String>{
            'Enrollment_Type__c'
        });
        String selectedEnrollmentType = String.isBlank(req.enrollmentType) || req.enrollmentType == 'All'
            ? null
            : req.enrollmentType;
        Map<Id, String> enrollmentTypeByPlan = new Map<Id, String>();
        Map<Id, String> requestedEnrollmentTypeByPlan = new Map<Id, String>();
        for (PlanSplitInput p : plans) {
            if (p == null || p.planId == null || String.isBlank(p.enrollmentType)) {
                continue;
            }
            requestedEnrollmentTypeByPlan.put(p.planId, p.enrollmentType);
        }
        List<Program_Plan_Course_Junction__c> oldJunctions;
        if (enrollmentTypeField != null) {
            String oldJunctionSoql = 'SELECT Id, Learning_Program_Plan__c, ' + enrollmentTypeField +
                ' FROM Program_Plan_Course_Junction__c' +
                ' WHERE Course_Offering__c = :placeholderId' +
                ' ';
            oldJunctions = Database.query(oldJunctionSoql);
            for (Program_Plan_Course_Junction__c j : oldJunctions) {
                if (j.Learning_Program_Plan__c == null || enrollmentTypeByPlan.containsKey(j.Learning_Program_Plan__c)) {
                    continue;
                }
                Object val = j.get(enrollmentTypeField);
                if (val != null && String.isNotBlank(String.valueOf(val))) {
                    enrollmentTypeByPlan.put(j.Learning_Program_Plan__c, String.valueOf(val));
                }
            }
        } else {
            oldJunctions = [
                SELECT Id
                FROM Program_Plan_Course_Junction__c
                WHERE Course_Offering__c = :placeholderId
                
            ];
        }
        
        // Individual offerings
        for (PlanSplitInput p : individualPlans) {
            List<String> selectedSections = normalizeSelectedSections(p == null ? null : p.selectedSections);
            Integer sections = !selectedSections.isEmpty()
                ? selectedSections.size()
                : (p.sections != null && p.sections > 0 ? p.sections : 1);
            Integer offeringCount = p.offeringCount != null && p.offeringCount > 0 ? p.offeringCount : sections;
            String offeringTypeLabel = String.isBlank(p.type) ? 'Individual' : p.type;
            for (Integer i = 1; i <= offeringCount; i++) {
                String sectionLabel = !selectedSections.isEmpty() && i <= selectedSections.size()
                    ? selectedSections[i - 1]
                    : null;
                CourseOffering co = placeholderReused ? new CourseOffering() : placeholder;
                if (!placeholderReused) {placeholderReused = true;}
                if (activePlannedRtId != null) {co.RecordTypeId = activePlannedRtId;}
                co.AcademicSessionId = session.Id;
                co.LearningCourseId = course.Id;
                co.Name = buildOfferingName(session.Name, courseLabel, p.planName, i, offeringCount, sectionLabel);
                setOfferingFields(
                    co,
                offeringFields,
                p.capacity,
                offeringTypeLabel,
                placeholder.Id,
                sourceCourseType,
                sourceCredit,
                courseTypeField,
                creditField,
                sectionLabel
                    );
                if (co != placeholder) {newOfferings.add(co);}
                OfferingPlanLink link = new OfferingPlanLink();
                link.offering = co;
                link.planIds.add(p.planId);
                offeringLinks.add(link);
            }
        }
        
        // Combined offerings (single group across all combined plans)
        if (!combinedPlans.isEmpty()) {
            Integer offeringCount = req.combinedOfferingCount != null && req.combinedOfferingCount > 0
                ? req.combinedOfferingCount
                : (req.combinedSections != null && req.combinedSections > 0 ? req.combinedSections : 1);
            String groupName = String.isBlank(req.combinedGroupName) ? 'Combined' : req.combinedGroupName;
            for (Integer i = 1; i <= offeringCount; i++) {
                CourseOffering co = placeholderReused ? new CourseOffering() : placeholder;
                if (!placeholderReused) {placeholderReused = true;}
                if (activePlannedRtId != null) {co.RecordTypeId = activePlannedRtId;}
                co.AcademicSessionId = session.Id;
                co.LearningCourseId = course.Id;
                co.Name = buildOfferingName(session.Name, courseLabel, groupName, i, offeringCount, null);
                setOfferingFields(
                    co,
                offeringFields,
                req.combinedCapacity,
                'Combined',
                placeholder.Id,
                sourceCourseType,
                sourceCredit,
                courseTypeField,
                creditField,
                null
                    );
                if (co != placeholder) {newOfferings.add(co);}
                OfferingPlanLink link = new OfferingPlanLink();
                link.offering = co;
                for (PlanSplitInput p : combinedPlans) {
                    link.planIds.add(p.planId);
                }
                offeringLinks.add(link);
            }
        }

        if (placeholderReused) {
            if (!CourseOffering.SObjectType.getDescribe().isUpdateable()) {
                throw new AuraHandledException('Update access is required for Course Offering.');
            }
            update placeholder;
        }
        
        if (!newOfferings.isEmpty()) {
            if (!CourseOffering.SObjectType.getDescribe().isCreateable()) {
                throw new AuraHandledException('Create access is required for Course Offering.');
            }
            insert newOfferings;
        }

        // In reuse mode, old junctions on the same offering id must be removed first.
        if (placeholderReused && !oldJunctions.isEmpty()) {
            if (!Program_Plan_Course_Junction__c.SObjectType.getDescribe().isDeletable()) {
                throw new AuraHandledException('Delete access is required for Program Plan Course Junction.');
            }
            delete oldJunctions;
        }
        
        // Build junctions for new offerings
        for (OfferingPlanLink link : offeringLinks) {
            if (link.offering == null || link.planIds.isEmpty()) {continue;}
            for (Id pid : link.planIds) {
                Program_Plan_Course_Junction__c junction = new Program_Plan_Course_Junction__c(
                    Learning_Program_Plan__c = pid,
                Course_Offering__c = link.offering.Id
                    );
                if (enrollmentTypeField != null) {
                    String mappedType = requestedEnrollmentTypeByPlan.containsKey(pid)
                        ? requestedEnrollmentTypeByPlan.get(pid)
                        : (enrollmentTypeByPlan.containsKey(pid)
                        ? enrollmentTypeByPlan.get(pid)
                        : selectedEnrollmentType);
                    if (String.isNotBlank(mappedType)) {
                        junction.put(enrollmentTypeField, mappedType);
                    }
                }
                newJunctions.add(junction);
            }
        }
        
        if (!newJunctions.isEmpty()) {
            if (!Program_Plan_Course_Junction__c.SObjectType.getDescribe().isCreateable()) {
                throw new AuraHandledException('Create access is required for Program Plan Course Junction.');
            }
            insert newJunctions;
        }
        
        // Remove old junctions and retire placeholder (non-reuse path).
        if (!placeholderReused && !oldJunctions.isEmpty()) {
            if (!Program_Plan_Course_Junction__c.SObjectType.getDescribe().isDeletable()) {
                throw new AuraHandledException('Delete access is required for Program Plan Course Junction.');
            }
            delete oldJunctions;
        }
        
        if (!placeholderReused) {
            retirePlaceholder(placeholder, offeringFields);
            if (!CourseOffering.SObjectType.getDescribe().isUpdateable()) {
                throw new AuraHandledException('Update access is required for Course Offering.');
            }
            update placeholder;
        }
    }
    
    /**
     * @description Deserializes JSON payload and delegates to splitOfferings.
     * @param reqJson Split request JSON.
     */
    @AuraEnabled
    public static void splitOfferingsJson(String reqJson) {
        try {
            if (String.isBlank(reqJson)) {
                throw new AuraHandledException('Placeholder offering id is required.');
            }
            SplitRequest req = (SplitRequest) JSON.deserialize(reqJson, SplitRequest.class);
            splitOfferingsInternal(req);
        } catch (Exception e) {
            KenAuditLogHelper.auditLogRecord(
                'Course Offering Split',
            'Class:KenCourseOfferingSplitController'
                )
                .setErrorMessage('KenCourseOfferingSplitController.splitOfferingsJson failed: ' + e.getMessage())
                .setStackTrace(e.getStackTraceString())
                .create();
            throw e;
        }
    }
    
    /**
     * @description Sets optional CourseOffering fields for new split records.
     * @param co Target CourseOffering record.
     * @param fields Describe field map for CourseOffering.
     * @param capacity Enrollment capacity value from request.
     * @param offeringType Offering type label (Individual/Combined).
     * @param placeholderId Source placeholder offering id.
     */
    private static void setOfferingFields(
        CourseOffering co,
    Map<String, Schema.SObjectField> fields,
    Integer capacity,
    String offeringType,
    Id placeholderId,
    Object sourceCourseType,
    Object sourceCredit,
    String courseTypeField,
    String creditField,
    String sectionLabel
    ) {
        if (capacity != null) {
            String capField = firstField(fields, new List<String>{
                'EnrollmentCapacity'
            });
            if (capField != null) {co.put(capField, capacity);}
        }
        
        if (String.isNotBlank(courseTypeField) && fields.containsKey(courseTypeField) &&
        fields.get(courseTypeField).getDescribe().isCreateable() && sourceCourseType != null) {
            co.put(courseTypeField, sourceCourseType);
        }
        if (String.isNotBlank(creditField) && fields.containsKey(creditField) &&
        fields.get(creditField).getDescribe().isCreateable() && sourceCredit != null) {
            co.put(creditField, sourceCredit);
        }
        
        if (fields.containsKey('OfferingType__c')) {
            co.put('OfferingType__c', offeringType);
        }
        if (String.isNotBlank(sectionLabel) && fields.containsKey('SectionNumber')) {
            co.put('SectionNumber', sectionLabel);
        }
        if (fields.containsKey('IsPlaceholder__c')) {
            co.put('IsPlaceholder__c', false);
        }
        if (fields.containsKey('SplitSourceOfferingId__c')) {
            co.put('SplitSourceOfferingId__c', placeholderId);
        }
    }
    
    /**
     * @description Marks placeholder offering as retired after split completion.
     * @param placeholder Placeholder Course Offering record to update.
     * @param fields Describe field map used to guard optional fields.
     */
    private static void retirePlaceholder(CourseOffering placeholder, Map<String, Schema.SObjectField> fields) {
        if (fields.containsKey('Offering_Status__c')) {
            placeholder.put('Offering_Status__c', 'Superseded');
        }
        if (fields.containsKey('SplitCompleted__c')) {
            placeholder.put('SplitCompleted__c', true);
        }
        if (fields.containsKey('IsPlaceholder__c')) {
            placeholder.put('IsPlaceholder__c', true);
        }
        if (fields.containsKey('IsActive')) {
            placeholder.put('IsActive', false);
        }
    }
    
    /**
     * @description Builds human-readable offering name using session/course/group/section context.
     * @param sessionName Academic Session name.
     * @param courseLabel Course number or name label.
     * @param groupLabel Group/plan label.
     * @param index Section index.
     * @param total Total sections for the group.
     * @return Final offering name text.
     */
    private static String buildOfferingName(String sessionName, String courseLabel, String groupLabel, Integer index, Integer total, String sectionLabel) {
        String base = sessionName + ' - ' + courseLabel;
        if (String.isNotBlank(groupLabel)) {
            base += ' - ' + groupLabel;
        }
        if (String.isNotBlank(sectionLabel)) {
            base += ' - ' + sectionLabel;
        } else if (total != null && total > 1) {
            base += ' - Section ' + String.valueOf(index);
        }
        return base;
    }

    private static List<String> normalizeSelectedSections(List<String> rawSections) {
        List<String> normalized = new List<String>();
        Set<String> seen = new Set<String>();
        if (rawSections == null) {
            return normalized;
        }
        for (String value : rawSections) {
            if (String.isBlank(value)) {
                continue;
            }
            String trimmed = value.trim();
            if (!seen.contains(trimmed)) {
                seen.add(trimmed);
                normalized.add(trimmed);
            }
        }
        return normalized;
    }
    
    /**
     * @description Returns the first field API name found in provided candidates.
     * @param fields Describe field map.
     * @param candidates Candidate field API names in priority order.
     * @return Matching field API name or null.
     */
    private static String firstField(Map<String, Schema.SObjectField> fields, List<String> candidates) {
        for (String c : candidates) {
            if (fields.containsKey(c)) {return c;}
        }
        return null;
    }
    
    /**
     * @description Resolves and caches CourseOffering record type Id by DeveloperName.
     * @param developerName RecordType DeveloperName.
     * @return RecordType Id or null when not found.
     */
    private static Id getCourseOfferingRecordTypeId(String developerName) {
        if (String.isBlank(developerName)) {return null;}
        if (courseOfferingActivePlannedRtId != null) {return courseOfferingActivePlannedRtId;}
        if (!RecordType.SObjectType.getDescribe().isAccessible()) {
            throw new AuraHandledException('Read access is required for RecordType.');
        }
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'CourseOffering'
            AND DeveloperName = :developerName
            
            LIMIT 1
        ];
        if (!rts.isEmpty()) {
            courseOfferingActivePlannedRtId = rts[0].Id;
        }
        return courseOfferingActivePlannedRtId;
    }
    
    /**
     * @description Ensures read access for an object before SOQL.
     * @param sobjectType Object type descriptor.
     * @param message Error message when access is missing.
     */
    private static void assertReadable(Schema.SObjectType sobjectType, String message) {
        if (sobjectType == null || !sobjectType.getDescribe().isAccessible()) {
            throw new AuraHandledException(message);
        }
    }
    
    /**
     * @description Ensures create access for an object before DML insert.
     * @param sobjectType Object type descriptor.
     * @param message Error message when access is missing.
     */
    private static void assertCreateable(Schema.SObjectType sobjectType, String message) {
        if (sobjectType == null || !sobjectType.getDescribe().isCreateable()) {
            throw new AuraHandledException(message);
        }
    }
    
    /**
     * @description Ensures update access for an object before DML update.
     * @param sobjectType Object type descriptor.
     * @param message Error message when access is missing.
     */
    private static void assertUpdateable(Schema.SObjectType sobjectType, String message) {
        if (sobjectType == null || !sobjectType.getDescribe().isUpdateable()) {
            throw new AuraHandledException(message);
        }
    }
    
    /**
     * @description Ensures delete access for an object before DML delete.
     * @param sobjectType Object type descriptor.
     * @param message Error message when access is missing.
     */
    private static void assertDeletable(Schema.SObjectType sobjectType, String message) {
        if (sobjectType == null || !sobjectType.getDescribe().isDeletable()) {
            throw new AuraHandledException(message);
        }
    }
    
}