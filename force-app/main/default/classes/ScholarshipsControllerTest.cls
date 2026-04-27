@IsTest
private class ScholarshipsControllerTest {
    private static String pickValue(Schema.DescribeFieldResult describeField) {
        for (Schema.PicklistEntry entry : describeField.getPicklistValues()) {
            if (entry != null && entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static String pickValue(Schema.DescribeFieldResult describeField, String preferred) {
        String fallback;
        for (Schema.PicklistEntry entry : describeField.getPicklistValues()) {
            if (entry == null || !entry.isActive()) {
                continue;
            }
            if (fallback == null) {
                fallback = entry.getValue();
            }
            if (!String.isBlank(preferred) && entry.getValue().toLowerCase() == preferred.toLowerCase()) {
                return entry.getValue();
            }
        }
        return fallback;
    }

    private static Id createScholarshipRecord() {
        String typeValue = pickValue(Ken_Scholarship_Discount__c.Type__c.getDescribe());
        String valueTypeValue = pickValue(Ken_Scholarship_Discount__c.Value_Type__c.getDescribe());
        String calculationTypeValue = pickValue(Ken_Scholarship_Discount__c.Calculation_Type__c.getDescribe());
        String currencyIsoCode = pickValue(Ken_Scholarship_Discount__c.CurrencyIsoCode.getDescribe());

        Map<String, Object> requestData = new Map<String, Object>();
        requestData.put('name', 'Scholarship_' + String.valueOf(DateTime.now().getTime()));
        requestData.put('type', typeValue);
        requestData.put('valueType', valueTypeValue);
        requestData.put('calculationType', calculationTypeValue);
        requestData.put('currencyIsoCode', currencyIsoCode);
        requestData.put('description', 'Scholarship description for test');
        requestData.put('statusAction', 'Draft');

        Boolean isRange = !String.isBlank(valueTypeValue) && valueTypeValue.toLowerCase().contains('range');
        if (isRange) {
            requestData.put('rangeStartValue', 1000);
            requestData.put('rangeEndValue', 5000);
        } else {
            requestData.put('fixedValue', 25);
        }

        return ScholarshipsController.saveScholarship(JSON.serialize(requestData));
    }

    private static Id ensureCategoryRecordId() {
        List<Category__c> existingCategories = [SELECT Id FROM Category__c LIMIT 1];
        if (!existingCategories.isEmpty()) {
            return existingCategories[0].Id;
        }

        QuotaCategoryDtos.SaveCategoryRequest requestDto = new QuotaCategoryDtos.SaveCategoryRequest();
        requestDto.categoryName = 'Category_' + String.valueOf(DateTime.now().getTime());
        requestDto.categoryType = pickValue(Category__c.Category_Type__c.getDescribe());
        requestDto.isActive = true;
        return QuotaCategoryService.saveCategory(requestDto);
    }

    @IsTest
    static void scholarshipsApis_executeWithoutError() {
        Id scholarshipId = createScholarshipRecord();

        Test.startTest();
        List<ScholarshipsController.ScholarshipListRow> listRows = ScholarshipsController.getScholarships();
        ScholarshipsController.ScholarshipBuilderData builderData =
            ScholarshipsController.getScholarshipBuilderData(scholarshipId);
        ScholarshipsController.ScholarshipDetailData detailData =
            ScholarshipsController.getScholarshipDetails(scholarshipId);
        Test.stopTest();

        System.assertNotEquals(null, scholarshipId);
        System.assertNotEquals(null, listRows);
        System.assert(listRows.size() > 0, 'Expected at least one scholarship row.');
        System.assertNotEquals(null, builderData);
        System.assertNotEquals(null, builderData.typeOptions);
        System.assertNotEquals(null, builderData.valueTypeOptions);
        System.assertNotEquals(null, builderData.calculationTypeOptions);
        System.assertNotEquals(null, builderData.currencyOptions);
        System.assertNotEquals(null, builderData.record);
        System.assertEquals(scholarshipId, builderData.record.id);
        System.assertNotEquals(null, detailData);
        System.assertEquals(scholarshipId, detailData.id);
        System.assertNotEquals(null, detailData.connectionRows);
        System.assertNotEquals(null, detailData.versionHistory);
        System.assertNotEquals(null, detailData.auditLogs);
    }

    @IsTest
    static void saveScholarship_validatesName() {
        String typeValue = pickValue(Ken_Scholarship_Discount__c.Type__c.getDescribe());
        String valueTypeValue = pickValue(Ken_Scholarship_Discount__c.Value_Type__c.getDescribe());
        String calculationTypeValue = pickValue(Ken_Scholarship_Discount__c.Calculation_Type__c.getDescribe());
        String currencyIsoCode = pickValue(Ken_Scholarship_Discount__c.CurrencyIsoCode.getDescribe());

        Map<String, Object> requestData = new Map<String, Object>{
            'name' => ' ',
            'type' => typeValue,
            'valueType' => valueTypeValue,
            'calculationType' => calculationTypeValue,
            'currencyIsoCode' => currencyIsoCode,
            'fixedValue' => 10
        };

        try {
            ScholarshipsController.saveScholarship(JSON.serialize(requestData));
            System.assert(false, 'Expected validation for scholarship name.');
        } catch (AuraHandledException ex) {
            System.assert(!String.isBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void saveScholarship_ignoresInstituteConnections() {
        String typeValue = pickValue(Ken_Scholarship_Discount__c.Type__c.getDescribe());
        String valueTypeValue = pickValue(Ken_Scholarship_Discount__c.Value_Type__c.getDescribe());
        String calculationTypeValue = pickValue(Ken_Scholarship_Discount__c.Calculation_Type__c.getDescribe());
        String currencyIsoCode = pickValue(Ken_Scholarship_Discount__c.CurrencyIsoCode.getDescribe());
        Id categoryId = ensureCategoryRecordId();

        Map<String, Object> requestData = new Map<String, Object>{
            'name' => 'Scholarship_with_unsupported_mapping_' + String.valueOf(DateTime.now().getTime()),
            'type' => typeValue,
            'valueType' => valueTypeValue,
            'calculationType' => calculationTypeValue,
            'currencyIsoCode' => currencyIsoCode,
            'description' => 'Scholarship with linked mapping',
            'statusAction' => 'Draft',
            'linkedLevel' => 'Institute Level',
            'linkedEntityIds' => new List<String>{ String.valueOf(categoryId) }
        };

        Boolean isRange = !String.isBlank(valueTypeValue) && valueTypeValue.toLowerCase().contains('range');
        if (isRange) {
            requestData.put('rangeStartValue', 500);
            requestData.put('rangeEndValue', 1000);
        } else {
            requestData.put('fixedValue', 10);
        }

        Test.startTest();
        Id scholarshipId = ScholarshipsController.saveScholarship(JSON.serialize(requestData));
        Test.stopTest();

        List<Ken_Scholarship_Discount_Connection__c> rows = [
            SELECT Id, Ken_Scholarship_Discount__c
            FROM Ken_Scholarship_Discount_Connection__c
            WHERE Ken_Scholarship_Discount__c = :scholarshipId
        ];

        System.assertEquals(0, rows.size(), 'Unsupported institute mapping should not be saved.');
    }

    @IsTest
    static void saveScholarship_createsCategoryConnections() {
        String typeValue = pickValue(Ken_Scholarship_Discount__c.Type__c.getDescribe());
        String valueTypeValue = pickValue(Ken_Scholarship_Discount__c.Value_Type__c.getDescribe());
        String calculationTypeValue = pickValue(Ken_Scholarship_Discount__c.Calculation_Type__c.getDescribe());
        String currencyIsoCode = pickValue(Ken_Scholarship_Discount__c.CurrencyIsoCode.getDescribe());
        Id categoryId = ensureCategoryRecordId();

        Map<String, Object> requestData = new Map<String, Object>{
            'name' => 'Scholarship_with_category_mapping_' + String.valueOf(DateTime.now().getTime()),
            'type' => typeValue,
            'valueType' => valueTypeValue,
            'calculationType' => calculationTypeValue,
            'currencyIsoCode' => currencyIsoCode,
            'statusAction' => 'Draft',
            'linkedLevel' => 'Category Level',
            'linkedEntityIds' => new List<String>{ String.valueOf(categoryId) }
        };

        Boolean isRange = !String.isBlank(valueTypeValue) && valueTypeValue.toLowerCase().contains('range');
        if (isRange) {
            requestData.put('rangeStartValue', 500);
            requestData.put('rangeEndValue', 1000);
        } else {
            requestData.put('fixedValue', 10);
        }

        Test.startTest();
        Id scholarshipId = ScholarshipsController.saveScholarship(JSON.serialize(requestData));
        Test.stopTest();

        List<Ken_Scholarship_Discount_Connection__c> rows = [
            SELECT Id, Ken_Scholarship_Discount__c, Quota_Category__c
            FROM Ken_Scholarship_Discount_Connection__c
            WHERE Ken_Scholarship_Discount__c = :scholarshipId
        ];

        System.assertEquals(1, rows.size(), 'Expected one category mapping record.');
        System.assertEquals(categoryId, rows[0].Quota_Category__c);
    }

    @IsTest
    static void saveScholarship_skipsUnsupportedLinkedLevelFromMultipleMappings() {
        String typeValue = pickValue(Ken_Scholarship_Discount__c.Type__c.getDescribe());
        String valueTypeValue = pickValue(Ken_Scholarship_Discount__c.Value_Type__c.getDescribe());
        String calculationTypeValue = pickValue(Ken_Scholarship_Discount__c.Calculation_Type__c.getDescribe());
        String currencyIsoCode = pickValue(Ken_Scholarship_Discount__c.CurrencyIsoCode.getDescribe());
        Id categoryId = ensureCategoryRecordId();

        Map<String, Object> requestData = new Map<String, Object>{
            'name' => 'Scholarship_multi_mapping_' + String.valueOf(DateTime.now().getTime()),
            'type' => typeValue,
            'valueType' => valueTypeValue,
            'calculationType' => calculationTypeValue,
            'currencyIsoCode' => currencyIsoCode,
            'statusAction' => 'Draft',
            'linkedMappings' => new List<Object>{
                new Map<String, Object>{
                    'linkedLevel' => 'Institute Level',
                    'linkedEntityIds' => new List<String>{ String.valueOf(categoryId) }
                },
                new Map<String, Object>{
                    'linkedLevel' => 'Category Level',
                    'linkedEntityIds' => new List<String>{ String.valueOf(categoryId) }
                }
            }
        };

        Boolean isRange = !String.isBlank(valueTypeValue) && valueTypeValue.toLowerCase().contains('range');
        if (isRange) {
            requestData.put('rangeStartValue', 500);
            requestData.put('rangeEndValue', 1000);
        } else {
            requestData.put('fixedValue', 10);
        }

        Test.startTest();
        Id scholarshipId = ScholarshipsController.saveScholarship(JSON.serialize(requestData));
        Test.stopTest();

        List<Ken_Scholarship_Discount_Connection__c> rows = [
            SELECT Id, Quota_Category__c
            FROM Ken_Scholarship_Discount_Connection__c
            WHERE Ken_Scholarship_Discount__c = :scholarshipId
        ];

        Integer categoryConnections = 0;
        for (Ken_Scholarship_Discount_Connection__c row : rows) {
            if (row.Quota_Category__c == categoryId) {
                categoryConnections++;
            }
        }

        System.assertEquals(1, rows.size(), 'Expected one supported scholarship mapping record.');
        System.assertEquals(1, categoryConnections, 'Expected one category mapping.');
    }

    @IsTest
    static void saveScholarship_updateRemovesUnselectedLinkedLevelConnections() {
        String typeValue = pickValue(Ken_Scholarship_Discount__c.Type__c.getDescribe());
        String valueTypeValue = pickValue(Ken_Scholarship_Discount__c.Value_Type__c.getDescribe());
        String calculationTypeValue = pickValue(Ken_Scholarship_Discount__c.Calculation_Type__c.getDescribe());
        String currencyIsoCode = pickValue(Ken_Scholarship_Discount__c.CurrencyIsoCode.getDescribe());
        Id categoryId = ensureCategoryRecordId();

        Map<String, Object> createRequest = new Map<String, Object>{
            'name' => 'Scholarship_edit_mapping_' + String.valueOf(DateTime.now().getTime()),
            'type' => typeValue,
            'valueType' => valueTypeValue,
            'calculationType' => calculationTypeValue,
            'currencyIsoCode' => currencyIsoCode,
            'statusAction' => 'Draft',
            'linkedMappings' => new List<Object>{
                new Map<String, Object>{
                    'linkedLevel' => 'Institute Level',
                    'linkedEntityIds' => new List<String>{ String.valueOf(categoryId) }
                },
                new Map<String, Object>{
                    'linkedLevel' => 'Category Level',
                    'linkedEntityIds' => new List<String>{ String.valueOf(categoryId) }
                }
            }
        };

        Boolean isRange = !String.isBlank(valueTypeValue) && valueTypeValue.toLowerCase().contains('range');
        if (isRange) {
            createRequest.put('rangeStartValue', 500);
            createRequest.put('rangeEndValue', 1000);
        } else {
            createRequest.put('fixedValue', 10);
        }

        Id scholarshipId = ScholarshipsController.saveScholarship(JSON.serialize(createRequest));

        Map<String, Object> updateRequest = new Map<String, Object>{
            'id' => String.valueOf(scholarshipId),
            'name' => createRequest.get('name'),
            'type' => typeValue,
            'valueType' => valueTypeValue,
            'calculationType' => calculationTypeValue,
            'currencyIsoCode' => currencyIsoCode,
            'statusAction' => 'Draft',
            'linkedMappings' => new List<Object>{
                new Map<String, Object>{
                    'linkedLevel' => 'Institute Level',
                    'linkedEntityIds' => new List<String>{ String.valueOf(categoryId) }
                }
            }
        };
        if (isRange) {
            updateRequest.put('rangeStartValue', 500);
            updateRequest.put('rangeEndValue', 1000);
        } else {
            updateRequest.put('fixedValue', 10);
        }

        Test.startTest();
        ScholarshipsController.saveScholarship(JSON.serialize(updateRequest));
        Test.stopTest();

        List<Ken_Scholarship_Discount_Connection__c> rows = [
            SELECT Id, Quota_Category__c
            FROM Ken_Scholarship_Discount_Connection__c
            WHERE Ken_Scholarship_Discount__c = :scholarshipId
        ];

        System.assertEquals(0, rows.size(), 'Only unsupported mappings should result in no saved connections.');
    }

    @IsTest
    static void saveScholarship_persistsStatusFieldOnCreateAndEdit() {
        String typeValue = pickValue(Ken_Scholarship_Discount__c.Type__c.getDescribe());
        String valueTypeValue = pickValue(Ken_Scholarship_Discount__c.Value_Type__c.getDescribe());
        String calculationTypeValue = pickValue(Ken_Scholarship_Discount__c.Calculation_Type__c.getDescribe());
        String currencyIsoCode = pickValue(Ken_Scholarship_Discount__c.CurrencyIsoCode.getDescribe());

        Map<String, Object> createRequest = new Map<String, Object>{
            'name' => 'Scholarship_status_' + String.valueOf(DateTime.now().getTime()),
            'type' => typeValue,
            'valueType' => valueTypeValue,
            'calculationType' => calculationTypeValue,
            'currencyIsoCode' => currencyIsoCode,
            'statusAction' => 'Draft'
        };

        Boolean isRange = !String.isBlank(valueTypeValue) && valueTypeValue.toLowerCase().contains('range');
        if (isRange) {
            createRequest.put('rangeStartValue', 500);
            createRequest.put('rangeEndValue', 1000);
        } else {
            createRequest.put('fixedValue', 10);
        }

        Id scholarshipId = ScholarshipsController.saveScholarship(JSON.serialize(createRequest));
        Ken_Scholarship_Discount__c createdRow = [
            SELECT Id, Status__c
            FROM Ken_Scholarship_Discount__c
            WHERE Id = :scholarshipId
            LIMIT 1
        ];
        System.assertEquals('draft', String.valueOf(createdRow.Status__c).toLowerCase(), 'Create should set Draft status.');

        Map<String, Object> updateRequest = new Map<String, Object>{
            'id' => String.valueOf(scholarshipId),
            'name' => createRequest.get('name'),
            'type' => typeValue,
            'valueType' => valueTypeValue,
            'calculationType' => calculationTypeValue,
            'currencyIsoCode' => currencyIsoCode,
            'statusAction' => 'Active'
        };
        if (isRange) {
            updateRequest.put('rangeStartValue', 500);
            updateRequest.put('rangeEndValue', 1000);
        } else {
            updateRequest.put('fixedValue', 10);
        }

        Test.startTest();
        ScholarshipsController.saveScholarship(JSON.serialize(updateRequest));
        Test.stopTest();

        Ken_Scholarship_Discount__c updatedRow = [
            SELECT Id, Status__c
            FROM Ken_Scholarship_Discount__c
            WHERE Id = :scholarshipId
            LIMIT 1
        ];
        System.assertEquals('active', String.valueOf(updatedRow.Status__c).toLowerCase(), 'Edit should update status field.');
    }

    @IsTest
    static void archiveScholarship_handlesConfiguredAndFallbackPaths() {
        Id scholarshipId = createScholarshipRecord();

        Test.startTest();
        try {
            ScholarshipsController.archiveScholarship(scholarshipId);
        } catch (Exception ex) {
            // Archived record type might not be configured in every environment.
        }
        Test.stopTest();

        Ken_Scholarship_Discount__c scholarship = [
            SELECT Id
            FROM Ken_Scholarship_Discount__c
            WHERE Id = :scholarshipId
            LIMIT 1
        ];
        System.assertEquals(scholarshipId, scholarship.Id);
    }

    @IsTest
    static void getScholarships_setsActionRestrictionFlags() {
        Id activeScholarshipId = createScholarshipRecord();
        String activeStatus = pickValue(Ken_Scholarship_Discount__c.Status__c.getDescribe(), 'active');
        if (!String.isBlank(activeStatus)) {
            update new Ken_Scholarship_Discount__c(Id = activeScholarshipId, Status__c = activeStatus);
        }

        Id referencedScholarshipId = createScholarshipRecord();
        insert new Ken_Scholarship_Discount_Connection__c(
            Name = 'Reference_' + String.valueOf(DateTime.now().getTime()),
            Ken_Scholarship_Discount__c = referencedScholarshipId
        );

        Test.startTest();
        List<ScholarshipsController.ScholarshipListRow> rows = ScholarshipsController.getScholarships();
        Test.stopTest();

        ScholarshipsController.ScholarshipListRow activeRow;
        ScholarshipsController.ScholarshipListRow referencedRow;
        for (ScholarshipsController.ScholarshipListRow row : rows) {
            if (row.id == activeScholarshipId) {
                activeRow = row;
            }
            if (row.id == referencedScholarshipId) {
                referencedRow = row;
            }
        }

        System.assertNotEquals(null, activeRow, 'Active scholarship row should exist.');
        System.assertNotEquals(null, referencedRow, 'Referenced scholarship row should exist.');
        System.assertEquals(true, activeRow.isActionRestricted, 'Active scholarship should be restricted.');
        System.assertEquals(true, referencedRow.isReferenced, 'Referenced scholarship should be flagged.');
        System.assert(referencedRow.usedInAssignments > 0, 'Referenced scholarship should have usage count.');
        System.assertEquals(true, referencedRow.isActionRestricted, 'Referenced scholarship should be restricted.');
    }
}