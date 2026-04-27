public with sharing class ScholarshipsController {
    private static final String LINKED_LEVEL_INSTITUTE = 'Institute Level';
    private static final String LINKED_LEVEL_PROGRAM = 'Program Level';
    private static final String LINKED_LEVEL_FEE_HEAD = 'Fee Head Level';
    private static final String LINKED_LEVEL_CATEGORY = 'Category Level';

    private static String descriptionFieldApiNameCache;

    public class OptionRow {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class ScholarshipListRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String type;
        @AuraEnabled public String valueType;
        @AuraEnabled public String mode;
        @AuraEnabled public String scope;
        @AuraEnabled public Datetime lastModified;
        @AuraEnabled public Integer usedInAssignments;
        @AuraEnabled public Boolean isReferenced;
        @AuraEnabled public Boolean isActionRestricted;
        @AuraEnabled public Id recordTypeId;
        @AuraEnabled public String recordTypeName;
    }

    public class ScholarshipBuilderRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String type;
        @AuraEnabled public String valueType;
        @AuraEnabled public String calculationType;
        @AuraEnabled public Decimal fixedValue;
        @AuraEnabled public Decimal rangeStartValue;
        @AuraEnabled public Decimal rangeEndValue;
        @AuraEnabled public String currencyIsoCode;
        @AuraEnabled public String description;
        @AuraEnabled public String linkedLevel;
        @AuraEnabled public List<Id> linkedEntityIds;
        @AuraEnabled public List<LinkedMappingRow> linkedMappings;
    }

    public class LinkedMappingRow {
        @AuraEnabled public String linkedLevel;
        @AuraEnabled public List<Id> linkedEntityIds;
    }

    public class ScholarshipBuilderData {
        @AuraEnabled public List<OptionRow> typeOptions;
        @AuraEnabled public List<OptionRow> valueTypeOptions;
        @AuraEnabled public List<OptionRow> calculationTypeOptions;
        @AuraEnabled public List<OptionRow> currencyOptions;
        @AuraEnabled public ScholarshipBuilderRow record;
    }

    public class UsageRow {
        @AuraEnabled public String programme;
        @AuraEnabled public String batch;
        @AuraEnabled public String status;
        @AuraEnabled public Integer students;
    }

    public class ScholarshipConnectionRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String connectionName;
        @AuraEnabled public String linkedLevel;
        @AuraEnabled public Id linkedRecordId;
        @AuraEnabled public String linkedRecordName;
        @AuraEnabled public String instituteName;
        @AuraEnabled public String learningProgramPlanName;
        @AuraEnabled public String masterFeeHeadName;
        @AuraEnabled public String categoryName;
    }

    public class VersionRow {
        @AuraEnabled public String version;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime changedOn;
        @AuraEnabled public String createdBy;
        @AuraEnabled public String changeReason;
    }

    public class AuditRow {
        @AuraEnabled public String action;
        @AuraEnabled public String userName;
        @AuraEnabled public Datetime changedOn;
        @AuraEnabled public String details;
    }

    public class ScholarshipDetailData {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String version;
        @AuraEnabled public Boolean isLocked;
        @AuraEnabled public String type;
        @AuraEnabled public String valueType;
        @AuraEnabled public String mode;
        @AuraEnabled public String valueDisplay;
        @AuraEnabled public String scope;
        @AuraEnabled public Decimal maxConcessionAmount;
        @AuraEnabled public String maxConcessionDisplay;
        @AuraEnabled public Boolean requiresApproval;
        @AuraEnabled public String currencyIsoCode;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String createdByName;
        @AuraEnabled public Datetime lastModifiedDate;
        @AuraEnabled public String lastModifiedByName;
        @AuraEnabled public Datetime activatedDate;
        @AuraEnabled public String description;
        @AuraEnabled public Integer studentsAssigned;
        @AuraEnabled public Integer programmes;
        @AuraEnabled public Integer assignmentRules;
        @AuraEnabled public List<String> eligibleQuotas;
        @AuraEnabled public List<String> coveredFeeHeads;
        @AuraEnabled public List<ScholarshipConnectionRow> connectionRows;
        @AuraEnabled public List<UsageRow> usageRows;
        @AuraEnabled public List<VersionRow> versionHistory;
        @AuraEnabled public List<AuditRow> auditLogs;
    }

    @AuraEnabled(cacheable=true)
    public static List<ScholarshipListRow> getScholarships() {
        List<Ken_Scholarship_Discount__c> scholarshipRows = [
            SELECT
                Id,
                Name,
                Type__c,
                Value_Type__c,
                Calculation_Type__c,
                Status__c,
                CurrencyIsoCode,
                RecordTypeId,
                RecordType.Name,
                RecordType.DeveloperName,
                LastModifiedDate
            FROM Ken_Scholarship_Discount__c
            ORDER BY LastModifiedDate DESC
            LIMIT 500
        ];

        List<ScholarshipListRow> rows = new List<ScholarshipListRow>();
        Set<Id> scholarshipIds = new Set<Id>();
        for (Ken_Scholarship_Discount__c scholarship : scholarshipRows) {
            scholarshipIds.add(scholarship.Id);
        }
        Map<Id, Integer> referenceCountByScholarshipId = getReferenceCountByScholarshipId(scholarshipIds);

        for (Ken_Scholarship_Discount__c scholarship : scholarshipRows) {
            ScholarshipListRow row = new ScholarshipListRow();
            row.id = scholarship.Id;
            row.name = scholarship.Name;
            String resolvedStatus = resolveStatusValue(
                scholarship.Status__c,
                scholarship.RecordType == null ? null : scholarship.RecordType.Name,
                scholarship.RecordType == null ? null : scholarship.RecordType.DeveloperName
            );
            row.status = resolvedStatus;
            row.type = scholarship.Type__c;
            row.valueType = scholarship.Value_Type__c;
            row.mode = scholarship.Calculation_Type__c;
            row.scope = deriveScope(scholarship.Value_Type__c, scholarship.Calculation_Type__c);
            row.lastModified = scholarship.LastModifiedDate;
            Integer referenceCount = referenceCountByScholarshipId.containsKey(scholarship.Id)
                ? referenceCountByScholarshipId.get(scholarship.Id)
                : 0;
            row.usedInAssignments = referenceCount;
            row.isReferenced = referenceCount > 0;
            row.isActionRestricted = isActiveStatus(resolvedStatus) || row.isReferenced;
            row.recordTypeId = scholarship.RecordTypeId;
            row.recordTypeName = scholarship.RecordType == null ? null : scholarship.RecordType.Name;
            rows.add(row);
        }

        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static ScholarshipBuilderData getScholarshipBuilderData(Id scholarshipId) {
        ScholarshipBuilderData data = new ScholarshipBuilderData();
        data.typeOptions = toOptions(Ken_Scholarship_Discount__c.Type__c.getDescribe());
        data.valueTypeOptions = toOptions(Ken_Scholarship_Discount__c.Value_Type__c.getDescribe());
        data.calculationTypeOptions = toOptions(Ken_Scholarship_Discount__c.Calculation_Type__c.getDescribe());
        data.currencyOptions = toOptions(Ken_Scholarship_Discount__c.CurrencyIsoCode.getDescribe());
        data.record = null;

        if (scholarshipId != null) {
            Ken_Scholarship_Discount__c scholarship = [
                SELECT
                    Id,
                    Name,
                    Type__c,
                    Value_Type__c,
                    Calculation_Type__c,
                    Fixed_Value__c,
                    Range_Start_Value__c,
                    Range_End_Value__c,
                    CurrencyIsoCode
                FROM Ken_Scholarship_Discount__c
                WHERE Id = :scholarshipId
                LIMIT 1
            ];

            ScholarshipBuilderRow row = new ScholarshipBuilderRow();
            row.id = scholarship.Id;
            row.name = scholarship.Name;
            row.type = scholarship.Type__c;
            row.valueType = scholarship.Value_Type__c;
            row.calculationType = scholarship.Calculation_Type__c;
            row.fixedValue = scholarship.Fixed_Value__c;
            row.rangeStartValue = scholarship.Range_Start_Value__c;
            row.rangeEndValue = scholarship.Range_End_Value__c;
            row.currencyIsoCode = scholarship.CurrencyIsoCode;
            row.description = getDescriptionValue(scholarshipId);
            populateBuilderLinkedMapping(row, scholarshipId);
            data.record = row;
        }

        return data;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionRow> getLinkedEntityOptions(String linkedLevel) {
        String normalizedLinkedLevel = normalizeText(linkedLevel);
        List<OptionRow> options = new List<OptionRow>();

        if (normalizedLinkedLevel == LINKED_LEVEL_PROGRAM) {
            for (LearningProgramPlan planRow : [
                SELECT Id, Name
                FROM LearningProgramPlan
                ORDER BY Name ASC
                LIMIT 500
            ]) {
                OptionRow option = new OptionRow();
                option.label = planRow.Name;
                option.value = planRow.Id;
                options.add(option);
            }
            return options;
        }

        if (normalizedLinkedLevel == LINKED_LEVEL_FEE_HEAD) {
            for (Ken_Master_Fee_Head__c feeHeadRow : [
                SELECT Id, Name, Fee_Head_Name__c
                FROM Ken_Master_Fee_Head__c
                ORDER BY Fee_Head_Name__c ASC, Name ASC
                LIMIT 500
            ]) {
                OptionRow option = new OptionRow();
                option.label = String.isBlank(feeHeadRow.Fee_Head_Name__c)
                    ? feeHeadRow.Name
                    : feeHeadRow.Fee_Head_Name__c;
                option.value = feeHeadRow.Id;
                options.add(option);
            }
            return options;
        }

        if (normalizedLinkedLevel == LINKED_LEVEL_CATEGORY) {
            for (Category__c categoryRow : [
                SELECT Id, Name
                FROM Category__c
                ORDER BY Name ASC
                LIMIT 500
            ]) {
                OptionRow option = new OptionRow();
                option.label = categoryRow.Name;
                option.value = categoryRow.Id;
                options.add(option);
            }
            return options;
        }

        return options;
    }

    @AuraEnabled
    public static Id saveScholarship(String requestJson) {
        if (String.isBlank(requestJson)) {
            throw new AuraHandledException('Request payload is required.');
        }

        Map<String, Object> requestData = (Map<String, Object>) JSON.deserializeUntyped(requestJson);

        Id scholarshipId = toIdValue(requestData.get('id'));
        String name = normalizeText(requestData.get('name'));
        String typeValue = normalizeText(requestData.get('type'));
        String valueTypeValue = normalizeText(requestData.get('valueType'));
        String calculationTypeValue = normalizeText(requestData.get('calculationType'));
        Decimal fixedValue = toDecimal(requestData.get('fixedValue'));
        Decimal rangeStartValue = toDecimal(requestData.get('rangeStartValue'));
        Decimal rangeEndValue = toDecimal(requestData.get('rangeEndValue'));
        String currencyIsoCode = normalizeText(requestData.get('currencyIsoCode'));
        String description = normalizeText(requestData.get('description'));
        String statusAction = normalizeText(requestData.get('statusAction'));
        List<LinkedMappingRow> linkedMappings = toLinkedMappings(requestData.get('linkedMappings'));
        if (linkedMappings.isEmpty()) {
            String linkedLevel = normalizeText(requestData.get('linkedLevel'));
            List<Id> linkedEntityIds = toIdList(requestData.get('linkedEntityIds'));
            if (!String.isBlank(linkedLevel) && !linkedEntityIds.isEmpty()) {
                LinkedMappingRow fallbackMapping = new LinkedMappingRow();
                fallbackMapping.linkedLevel = linkedLevel;
                fallbackMapping.linkedEntityIds = linkedEntityIds;
                linkedMappings.add(fallbackMapping);
            }
        }

        if (String.isBlank(name)) {
            throw new AuraHandledException('Scholarship Name is required.');
        }
        if (String.isBlank(typeValue)) {
            throw new AuraHandledException('Type is required.');
        }
        if (String.isBlank(valueTypeValue)) {
            throw new AuraHandledException('Value Type is required.');
        }
        if (String.isBlank(calculationTypeValue)) {
            throw new AuraHandledException('Calculation Type is required.');
        }
        if (String.isBlank(currencyIsoCode)) {
            throw new AuraHandledException('Currency is required.');
        }

        Boolean isRange = isRangeValueType(valueTypeValue);
        if (isRange) {
            if (rangeStartValue == null || rangeEndValue == null) {
                throw new AuraHandledException('Range Start and Range End values are required.');
            }
            if (rangeEndValue < rangeStartValue) {
                throw new AuraHandledException('Range End must be greater than or equal to Range Start.');
            }
        } else if (fixedValue == null) {
            throw new AuraHandledException('Fixed Value is required.');
        }

        Ken_Scholarship_Discount__c scholarship = scholarshipId == null
            ? new Ken_Scholarship_Discount__c()
            : [
                SELECT Id, Status__c
                FROM Ken_Scholarship_Discount__c
                WHERE Id = :scholarshipId
                LIMIT 1
            ];

        scholarship.Name = name;
        scholarship.Type__c = typeValue;
        scholarship.Value_Type__c = valueTypeValue;
        scholarship.Calculation_Type__c = calculationTypeValue;
        scholarship.CurrencyIsoCode = currencyIsoCode;

        if (isRange) {
            scholarship.Fixed_Value__c = null;
            scholarship.Range_Start_Value__c = rangeStartValue;
            scholarship.Range_End_Value__c = rangeEndValue;
        } else {
            scholarship.Fixed_Value__c = fixedValue;
            scholarship.Range_Start_Value__c = null;
            scholarship.Range_End_Value__c = null;
        }

        scholarship.Status__c = resolveStatusForSave(statusAction, scholarship.Status__c, scholarshipId == null);
        setDescriptionValue(scholarship, description);

        upsert scholarship;
        replaceScholarshipConnections(scholarship.Id, linkedMappings);
        return scholarship.Id;
    }

    @AuraEnabled(cacheable=true)
    public static ScholarshipDetailData getScholarshipDetails(Id scholarshipId) {
        if (scholarshipId == null) {
            return null;
        }

        Ken_Scholarship_Discount__c scholarship = [
            SELECT
                Id,
                Name,
                Type__c,
                Value_Type__c,
                Calculation_Type__c,
                Fixed_Value__c,
                Range_Start_Value__c,
                Range_End_Value__c,
                Status__c,
                CurrencyIsoCode,
                RecordTypeId,
                RecordType.Name,
                RecordType.DeveloperName,
                CreatedDate,
                CreatedById,
                CreatedBy.Name,
                LastModifiedDate,
                LastModifiedById,
                LastModifiedBy.Name
            FROM Ken_Scholarship_Discount__c
            WHERE Id = :scholarshipId
            LIMIT 1
        ];

        ScholarshipDetailData dto = new ScholarshipDetailData();
        dto.id = scholarship.Id;
        dto.name = scholarship.Name;
        dto.status = resolveStatusValue(
            scholarship.Status__c,
            scholarship.RecordType == null ? null : scholarship.RecordType.Name,
            scholarship.RecordType == null ? null : scholarship.RecordType.DeveloperName
        );
        dto.version = 'v1.0';
        dto.isLocked = isActiveStatus(dto.status);
        dto.type = scholarship.Type__c;
        dto.valueType = scholarship.Value_Type__c;
        dto.mode = scholarship.Calculation_Type__c;
        dto.valueDisplay = buildValueDisplay(
            scholarship.Value_Type__c,
            scholarship.Calculation_Type__c,
            scholarship.Fixed_Value__c,
            scholarship.Range_Start_Value__c,
            scholarship.Range_End_Value__c,
            scholarship.CurrencyIsoCode
        );
        dto.scope = deriveScope(scholarship.Value_Type__c, scholarship.Calculation_Type__c);
        dto.maxConcessionAmount = scholarship.Range_End_Value__c != null
            ? scholarship.Range_End_Value__c
            : scholarship.Fixed_Value__c;
        dto.maxConcessionDisplay = formatAmount(dto.maxConcessionAmount, scholarship.CurrencyIsoCode);
        dto.requiresApproval = isRangeValueType(scholarship.Value_Type__c);
        dto.currencyIsoCode = scholarship.CurrencyIsoCode;
        dto.createdDate = scholarship.CreatedDate;
        dto.createdByName = scholarship.CreatedBy == null ? '-' : scholarship.CreatedBy.Name;
        dto.lastModifiedDate = scholarship.LastModifiedDate;
        dto.lastModifiedByName = scholarship.LastModifiedBy == null ? '-' : scholarship.LastModifiedBy.Name;
        dto.activatedDate = isActiveStatus(dto.status) ? scholarship.LastModifiedDate : null;
        dto.description = getDescriptionValue(scholarshipId);
        dto.studentsAssigned = 0;
        dto.programmes = 0;
        dto.assignmentRules = 0;
        dto.eligibleQuotas = new List<String>{ 'General', 'OBC', 'SC/ST' };
        dto.coveredFeeHeads = new List<String>{ 'Tuition Fee', 'Development Fee', 'Lab Fee' };
        dto.connectionRows = new List<ScholarshipConnectionRow>();

        for (Ken_Scholarship_Discount_Connection__c connectionRow : [
            SELECT
                Id,
                Name,
                Institute__c,
                Institute__r.Name,
                Learning_Program_Plan__c,
                Learning_Program_Plan__r.Name,
                Master_Fee_Head__c,
                Master_Fee_Head__r.Name,
                Master_Fee_Head__r.Fee_Head_Name__c,
                Quota_Category__c,
                Quota_Category__r.Name
            FROM Ken_Scholarship_Discount_Connection__c
            WHERE Ken_Scholarship_Discount__c = :scholarshipId
            ORDER BY CreatedDate DESC
            LIMIT 500
        ]) {
            ScholarshipConnectionRow mappedRow = new ScholarshipConnectionRow();
            mappedRow.id = connectionRow.Id;
            mappedRow.connectionName = connectionRow.Name;
            mappedRow.instituteName = connectionRow.Institute__r == null
                ? null
                : connectionRow.Institute__r.Name;
            mappedRow.learningProgramPlanName = connectionRow.Learning_Program_Plan__r == null
                ? null
                : connectionRow.Learning_Program_Plan__r.Name;
            mappedRow.masterFeeHeadName = connectionRow.Master_Fee_Head__r == null
                ? null
                : String.isBlank(connectionRow.Master_Fee_Head__r.Fee_Head_Name__c)
                    ? connectionRow.Master_Fee_Head__r.Name
                    : connectionRow.Master_Fee_Head__r.Fee_Head_Name__c;
            mappedRow.categoryName = connectionRow.Quota_Category__r == null
                ? null
                : connectionRow.Quota_Category__r.Name;

            if (connectionRow.Institute__c != null) {
                mappedRow.linkedLevel = LINKED_LEVEL_INSTITUTE;
                mappedRow.linkedRecordId = connectionRow.Institute__c;
                mappedRow.linkedRecordName = mappedRow.instituteName;
            } else if (connectionRow.Learning_Program_Plan__c != null) {
                mappedRow.linkedLevel = LINKED_LEVEL_PROGRAM;
                mappedRow.linkedRecordId = connectionRow.Learning_Program_Plan__c;
                mappedRow.linkedRecordName = mappedRow.learningProgramPlanName;
            } else if (connectionRow.Master_Fee_Head__c != null) {
                mappedRow.linkedLevel = LINKED_LEVEL_FEE_HEAD;
                mappedRow.linkedRecordId = connectionRow.Master_Fee_Head__c;
                mappedRow.linkedRecordName = mappedRow.masterFeeHeadName;
            } else if (connectionRow.Quota_Category__c != null) {
                mappedRow.linkedLevel = LINKED_LEVEL_CATEGORY;
                mappedRow.linkedRecordId = connectionRow.Quota_Category__c;
                mappedRow.linkedRecordName = mappedRow.categoryName;
            } else {
                mappedRow.linkedLevel = '-';
                mappedRow.linkedRecordId = null;
                mappedRow.linkedRecordName = '-';
            }

            dto.connectionRows.add(mappedRow);
        }

        dto.usageRows = new List<UsageRow>();

        dto.versionHistory = new List<VersionRow>();
        VersionRow currentVersion = new VersionRow();
        currentVersion.version = dto.version;
        currentVersion.status = dto.status;
        currentVersion.changedOn = scholarship.LastModifiedDate;
        currentVersion.createdBy = dto.lastModifiedByName;
        currentVersion.changeReason = 'Initial scholarship configuration';
        dto.versionHistory.add(currentVersion);

        dto.auditLogs = new List<AuditRow>();

        AuditRow createdRow = new AuditRow();
        createdRow.action = 'Created';
        createdRow.userName = dto.createdByName;
        createdRow.changedOn = scholarship.CreatedDate;
        createdRow.details = 'Initial draft created';
        dto.auditLogs.add(createdRow);

        if (scholarship.LastModifiedDate != null && scholarship.LastModifiedDate != scholarship.CreatedDate) {
            AuditRow updatedRow = new AuditRow();
            updatedRow.action = isActiveStatus(dto.status) ? 'Activated' : 'Updated';
            updatedRow.userName = dto.lastModifiedByName;
            updatedRow.changedOn = scholarship.LastModifiedDate;
            updatedRow.details = isActiveStatus(dto.status)
                ? 'Scholarship activated for use'
                : 'Scholarship updated';
            dto.auditLogs.add(updatedRow);
        }

        return dto;
    }

    @AuraEnabled
    public static void archiveScholarship(Id scholarshipId) {
        if (scholarshipId == null) {
            throw new AuraHandledException('Scholarship Id is required.');
        }

        Ken_Scholarship_Discount__c scholarship = [
            SELECT Id, Status__c
            FROM Ken_Scholarship_Discount__c
            WHERE Id = :scholarshipId
            LIMIT 1
        ];
        scholarship.Status__c = resolveStatusForSave('Archived', scholarship.Status__c, false);
        if (String.isBlank(scholarship.Status__c)) {
            throw new AuraHandledException('Archived value is not configured for Status field.');
        }
        update scholarship;
    }

    private static Map<Id, Integer> getReferenceCountByScholarshipId(Set<Id> scholarshipIds) {
        Map<Id, Integer> referenceCountByScholarshipId = new Map<Id, Integer>();
        if (scholarshipIds == null || scholarshipIds.isEmpty()) {
            return referenceCountByScholarshipId;
        }

        for (AggregateResult aggregateRow : [
            SELECT Ken_Scholarship_Discount__c scholarshipId, COUNT(Id) rowCount
            FROM Ken_Scholarship_Discount_Connection__c
            WHERE Ken_Scholarship_Discount__c IN :scholarshipIds
            GROUP BY Ken_Scholarship_Discount__c
        ]) {
            Id scholarshipId = (Id) aggregateRow.get('scholarshipId');
            if (scholarshipId == null) {
                continue;
            }

            Integer rowCount = Integer.valueOf(String.valueOf(aggregateRow.get('rowCount')));
            referenceCountByScholarshipId.put(scholarshipId, rowCount);
        }

        return referenceCountByScholarshipId;
    }

    private static List<OptionRow> toOptions(Schema.DescribeFieldResult describeResult) {
        List<OptionRow> options = new List<OptionRow>();
        if (describeResult == null) {
            return options;
        }

        for (Schema.PicklistEntry entry : describeResult.getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            OptionRow option = new OptionRow();
            option.label = entry.getLabel();
            option.value = entry.getValue();
            options.add(option);
        }
        return options;
    }

    private static void populateBuilderLinkedMapping(ScholarshipBuilderRow row, Id scholarshipId) {
        if (row == null || scholarshipId == null) {
            return;
        }

        row.linkedLevel = null;
        row.linkedEntityIds = new List<Id>();
        row.linkedMappings = new List<LinkedMappingRow>();
        Map<String, List<Id>> idsByLevel = new Map<String, List<Id>>();
        Map<String, Set<Id>> seenIdsByLevel = new Map<String, Set<Id>>();
        List<String> orderedLevels = new List<String>();

        for (Ken_Scholarship_Discount_Connection__c connectionRow : [
            SELECT Learning_Program_Plan__c, Master_Fee_Head__c, Quota_Category__c
            FROM Ken_Scholarship_Discount_Connection__c
            WHERE Ken_Scholarship_Discount__c = :scholarshipId
            ORDER BY CreatedDate ASC
            LIMIT 500
        ]) {
            String mappingLevel;
            Id selectedId;
            if (connectionRow.Learning_Program_Plan__c != null) {
                mappingLevel = LINKED_LEVEL_PROGRAM;
                selectedId = connectionRow.Learning_Program_Plan__c;
            } else if (connectionRow.Master_Fee_Head__c != null) {
                mappingLevel = LINKED_LEVEL_FEE_HEAD;
                selectedId = connectionRow.Master_Fee_Head__c;
            } else if (connectionRow.Quota_Category__c != null) {
                mappingLevel = LINKED_LEVEL_CATEGORY;
                selectedId = connectionRow.Quota_Category__c;
            } else {
                mappingLevel = null;
                selectedId = null;
            }

            if (String.isBlank(mappingLevel) || selectedId == null) {
                continue;
            }

            if (!idsByLevel.containsKey(mappingLevel)) {
                idsByLevel.put(mappingLevel, new List<Id>());
                seenIdsByLevel.put(mappingLevel, new Set<Id>());
                orderedLevels.add(mappingLevel);
            }

            if (!seenIdsByLevel.get(mappingLevel).contains(selectedId)) {
                seenIdsByLevel.get(mappingLevel).add(selectedId);
                idsByLevel.get(mappingLevel).add(selectedId);
            }
        }

        for (String mappingLevel : orderedLevels) {
            LinkedMappingRow mappingRow = new LinkedMappingRow();
            mappingRow.linkedLevel = mappingLevel;
            mappingRow.linkedEntityIds = idsByLevel.get(mappingLevel);
            row.linkedMappings.add(mappingRow);
        }

        if (!row.linkedMappings.isEmpty()) {
            row.linkedLevel = row.linkedMappings[0].linkedLevel;
            row.linkedEntityIds = new List<Id>();
            if (row.linkedMappings[0].linkedEntityIds != null) {
                row.linkedEntityIds.addAll(row.linkedMappings[0].linkedEntityIds);
            }
        }
    }

    private static void replaceScholarshipConnections(Id scholarshipId, List<LinkedMappingRow> linkedMappings) {
        if (scholarshipId == null) {
            return;
        }

        List<Ken_Scholarship_Discount_Connection__c> existingRows = [
            SELECT Id
            FROM Ken_Scholarship_Discount_Connection__c
            WHERE Ken_Scholarship_Discount__c = :scholarshipId
            LIMIT 1000
        ];
        if (!existingRows.isEmpty()) {
            delete existingRows;
        }

        if (linkedMappings == null || linkedMappings.isEmpty()) {
            return;
        }

        List<Ken_Scholarship_Discount_Connection__c> rowsToInsert = new List<Ken_Scholarship_Discount_Connection__c>();
        Set<String> seenMappingKeys = new Set<String>();
        Map<String, Integer> sequenceByLevel = new Map<String, Integer>();

        for (LinkedMappingRow mappingRow : linkedMappings) {
            String normalizedLinkedLevel = normalizeText(mappingRow == null ? null : mappingRow.linkedLevel);
            List<Id> linkedEntityIds = mappingRow == null ? null : mappingRow.linkedEntityIds;
            if (String.isBlank(normalizedLinkedLevel) || linkedEntityIds == null || linkedEntityIds.isEmpty()) {
                continue;
            }

            if (!sequenceByLevel.containsKey(normalizedLinkedLevel)) {
                sequenceByLevel.put(normalizedLinkedLevel, 1);
            }

            Set<Id> uniqueEntityIds = new Set<Id>();
            for (Id linkedEntityId : linkedEntityIds) {
                if (linkedEntityId == null || uniqueEntityIds.contains(linkedEntityId)) {
                    continue;
                }
                uniqueEntityIds.add(linkedEntityId);

                String mappingKey = normalizedLinkedLevel + ':' + String.valueOf(linkedEntityId);
                if (seenMappingKeys.contains(mappingKey)) {
                    continue;
                }

                Integer sequence = sequenceByLevel.get(normalizedLinkedLevel);
                Ken_Scholarship_Discount_Connection__c connectionRow = new Ken_Scholarship_Discount_Connection__c();
                connectionRow.Ken_Scholarship_Discount__c = scholarshipId;
                connectionRow.Name = buildScholarshipConnectionName(normalizedLinkedLevel, sequence);

                if (normalizedLinkedLevel == LINKED_LEVEL_PROGRAM) {
                    connectionRow.Learning_Program_Plan__c = linkedEntityId;
                } else if (normalizedLinkedLevel == LINKED_LEVEL_FEE_HEAD) {
                    connectionRow.Master_Fee_Head__c = linkedEntityId;
                } else if (normalizedLinkedLevel == LINKED_LEVEL_CATEGORY) {
                    connectionRow.Quota_Category__c = linkedEntityId;
                } else {
                    continue;
                }

                sequenceByLevel.put(normalizedLinkedLevel, sequence + 1);
                seenMappingKeys.add(mappingKey);
                rowsToInsert.add(connectionRow);
            }
        }

        if (!rowsToInsert.isEmpty()) {
            insert rowsToInsert;
        }
    }

    private static String buildScholarshipConnectionName(String linkedLevel, Integer sequence) {
        String normalizedLinkedLevel = normalizeText(linkedLevel);
        String prefix = 'Mapping';
        if (normalizedLinkedLevel == LINKED_LEVEL_PROGRAM) {
            prefix = 'Program';
        } else if (normalizedLinkedLevel == LINKED_LEVEL_FEE_HEAD) {
            prefix = 'Fee Head';
        } else if (normalizedLinkedLevel == LINKED_LEVEL_CATEGORY) {
            prefix = 'Category';
        }

        Integer sequenceValue = sequence == null ? 1 : sequence;
        String nameValue = prefix + ' Mapping ' + String.valueOf(sequenceValue);
        return nameValue.length() > 80 ? nameValue.substring(0, 80) : nameValue;
    }

    private static String resolveStatusValue(String statusValue, String recordTypeName, String recordTypeDeveloperName) {
        Map<String, String> allowedStatusesByToken = getAllowedStatusesByToken();
        String statusToken = normalizeStatusToken(statusValue);
        if (allowedStatusesByToken.containsKey(statusToken)) {
            return allowedStatusesByToken.get(statusToken);
        }

        String fallbackToken = deriveStatusTokenFromRecordType(recordTypeName, recordTypeDeveloperName);
        if (allowedStatusesByToken.containsKey(fallbackToken)) {
            return allowedStatusesByToken.get(fallbackToken);
        }

        return getDefaultStatusValue(allowedStatusesByToken);
    }

    private static String resolveStatusForSave(String statusAction, String existingStatusValue, Boolean isCreateMode) {
        Map<String, String> allowedStatusesByToken = getAllowedStatusesByToken();
        String resolvedToken = normalizeStatusToken(statusAction);

        if (resolvedToken == 'activate') {
            resolvedToken = 'active';
        } else if (resolvedToken == 'review') {
            resolvedToken = 'under review';
        } else if (resolvedToken == 'archive') {
            resolvedToken = 'archived';
        }

        if (allowedStatusesByToken.containsKey(resolvedToken)) {
            return allowedStatusesByToken.get(resolvedToken);
        }

        String existingToken = normalizeStatusToken(existingStatusValue);
        if (allowedStatusesByToken.containsKey(existingToken)) {
            return allowedStatusesByToken.get(existingToken);
        }

        if (isCreateMode == true) {
            return getDefaultStatusValue(allowedStatusesByToken);
        }

        return getDefaultStatusValue(allowedStatusesByToken);
    }

    private static Map<String, String> getAllowedStatusesByToken() {
        Map<String, String> statusesByToken = new Map<String, String>();
        for (Schema.PicklistEntry entry : Ken_Scholarship_Discount__c.Status__c.getDescribe().getPicklistValues()) {
            if (entry == null || !entry.isActive()) {
                continue;
            }
            String statusValue = entry.getValue();
            statusesByToken.put(normalizeStatusToken(statusValue), statusValue);
        }
        return statusesByToken;
    }

    private static String getDefaultStatusValue(Map<String, String> statusesByToken) {
        if (statusesByToken == null || statusesByToken.isEmpty()) {
            return null;
        }
        if (statusesByToken.containsKey('draft')) {
            return statusesByToken.get('draft');
        }
        for (String value : statusesByToken.values()) {
            return value;
        }
        return null;
    }

    private static Boolean isActiveStatus(String statusValue) {
        return normalizeStatusToken(statusValue) == 'active';
    }

    private static String deriveStatusTokenFromRecordType(String recordTypeName, String recordTypeDeveloperName) {
        String token = ((recordTypeName == null ? '' : recordTypeName) + ' '
            + (recordTypeDeveloperName == null ? '' : recordTypeDeveloperName)).toLowerCase();

        if (token.contains('archiv')) {
            return 'archived';
        }
        if (token.contains('review')) {
            return 'under review';
        }
        if (token.contains('draft')) {
            return 'draft';
        }
        if (token.contains('active')) {
            return 'active';
        }
        return 'draft';
    }

    private static String normalizeStatusToken(String statusValue) {
        return String.isBlank(statusValue) ? '' : statusValue.trim().toLowerCase();
    }

    private static String deriveScope(String valueType, String calculationType) {
        String valueTypeToken = String.isBlank(valueType) ? '' : valueType.toLowerCase();
        String calculationToken = String.isBlank(calculationType) ? '' : calculationType.toLowerCase();

        if (valueTypeToken.contains('range')) {
            return 'Selected Heads';
        }
        if (calculationToken.contains('fixed')) {
            return 'Payout';
        }
        return 'Entire Fee Plan';
    }

    private static Boolean isRangeValueType(String valueType) {
        return !String.isBlank(valueType) && valueType.toLowerCase().contains('range');
    }

    private static String buildValueDisplay(
        String valueType,
        String calculationType,
        Decimal fixedValue,
        Decimal rangeStartValue,
        Decimal rangeEndValue,
        String currencyIsoCode
    ) {
        if (isRangeValueType(valueType)) {
            return formatAmount(rangeStartValue, currencyIsoCode) + ' - ' + formatAmount(rangeEndValue, currencyIsoCode);
        }

        if (!String.isBlank(calculationType) && calculationType.toLowerCase().contains('percentage')) {
            return fixedValue == null ? '-' : String.valueOf(fixedValue) + '%';
        }

        return formatAmount(fixedValue, currencyIsoCode);
    }

    private static String formatAmount(Decimal amountValue, String currencyIsoCode) {
        if (amountValue == null) {
            return '-';
        }
        String normalizedCurrency = String.isBlank(currencyIsoCode) ? '' : currencyIsoCode + ' ';
        return normalizedCurrency + String.valueOf(amountValue.setScale(2));
    }

    private static String normalizeText(Object rawValue) {
        if (rawValue == null) {
            return null;
        }
        String value = String.valueOf(rawValue).trim();
        return String.isBlank(value) ? null : value;
    }

    private static Decimal toDecimal(Object rawValue) {
        if (rawValue == null) {
            return null;
        }
        String textValue = String.valueOf(rawValue).trim();
        if (String.isBlank(textValue)) {
            return null;
        }
        try {
            return Decimal.valueOf(textValue);
        } catch (Exception ex) {
            return null;
        }
    }

    private static Id toIdValue(Object rawValue) {
        String textValue = normalizeText(rawValue);
        if (textValue == null) {
            return null;
        }
        if (textValue.length() != 15 && textValue.length() != 18) {
            return null;
        }
        try {
            return (Id) textValue;
        } catch (Exception ex) {
            return null;
        }
    }

    private static List<Id> toIdList(Object rawValue) {
        List<Id> idValues = new List<Id>();
        if (rawValue == null) {
            return idValues;
        }

        Set<Id> seenIds = new Set<Id>();
        if (rawValue instanceof List<Object>) {
            for (Object item : (List<Object>) rawValue) {
                Id convertedId = toIdValue(item);
                if (convertedId != null && !seenIds.contains(convertedId)) {
                    seenIds.add(convertedId);
                    idValues.add(convertedId);
                }
            }
            return idValues;
        }

        Id convertedId = toIdValue(rawValue);
        if (convertedId != null) {
            idValues.add(convertedId);
        }
        return idValues;
    }

    private static List<LinkedMappingRow> toLinkedMappings(Object rawValue) {
        List<LinkedMappingRow> mappings = new List<LinkedMappingRow>();
        if (!(rawValue instanceof List<Object>)) {
            return mappings;
        }

        for (Object item : (List<Object>) rawValue) {
            if (!(item instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> mappingData = (Map<String, Object>) item;
            String linkedLevel = normalizeText(mappingData.get('linkedLevel'));
            List<Id> linkedEntityIds = toIdList(mappingData.get('linkedEntityIds'));
            if (String.isBlank(linkedLevel) || linkedEntityIds.isEmpty()) {
                continue;
            }

            LinkedMappingRow mappingRow = new LinkedMappingRow();
            mappingRow.linkedLevel = linkedLevel;
            mappingRow.linkedEntityIds = linkedEntityIds;
            mappings.add(mappingRow);
        }
        return mappings;
    }

    private static String getDescriptionFieldApiName() {
        if (descriptionFieldApiNameCache != null) {
            return descriptionFieldApiNameCache;
        }

        Map<String, Schema.SObjectField> fieldMap = Ken_Scholarship_Discount__c.SObjectType.getDescribe().fields.getMap();
        List<String> candidates = new List<String>{ 'Description__c', 'Description' };

        for (String candidate : candidates) {
            if (fieldMap.containsKey(candidate)) {
                descriptionFieldApiNameCache = candidate;
                return descriptionFieldApiNameCache;
            }
        }

        descriptionFieldApiNameCache = '';
        return descriptionFieldApiNameCache;
    }

    private static String getDescriptionValue(Id scholarshipId) {
        if (scholarshipId == null) {
            return null;
        }

        String fieldApiName = getDescriptionFieldApiName();
        if (String.isBlank(fieldApiName)) {
            return null;
        }

        SObject row = Database.query(
            'SELECT ' + fieldApiName +
            ' FROM Ken_Scholarship_Discount__c WHERE Id = :scholarshipId LIMIT 1'
        );

        Object rawValue = row.get(fieldApiName);
        return rawValue == null ? null : String.valueOf(rawValue);
    }

    private static void setDescriptionValue(SObject scholarship, String descriptionValue) {
        if (scholarship == null) {
            return;
        }

        String fieldApiName = getDescriptionFieldApiName();
        if (String.isBlank(fieldApiName)) {
            return;
        }

        scholarship.put(fieldApiName, String.isBlank(descriptionValue) ? null : descriptionValue.trim());
    }
}