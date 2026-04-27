@IsTest
private class KenScholarshipDiscountTriggerHandlerTest {
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

    private static String pickInactiveStatusValue() {
        String draftStatus = pickValue(Ken_Scholarship_Discount__c.Status__c.getDescribe(), 'draft');
        if (!String.isBlank(draftStatus) && draftStatus.toLowerCase() != 'active') {
            return draftStatus;
        }

        for (Schema.PicklistEntry entry : Ken_Scholarship_Discount__c.Status__c.getDescribe().getPicklistValues()) {
            if (entry != null && entry.isActive() && entry.getValue().toLowerCase() != 'active') {
                return entry.getValue();
            }
        }
        return null;
    }

    private static Id createScholarship(String token) {
        String typeValue = pickValue(Ken_Scholarship_Discount__c.Type__c.getDescribe(), null);
        String valueTypeValue = pickValue(Ken_Scholarship_Discount__c.Value_Type__c.getDescribe(), null);
        String calculationTypeValue = pickValue(Ken_Scholarship_Discount__c.Calculation_Type__c.getDescribe(), null);
        String currencyIsoCode = pickValue(Ken_Scholarship_Discount__c.CurrencyIsoCode.getDescribe(), null);

        Map<String, Object> requestData = new Map<String, Object>();
        requestData.put('name', 'Scholarship_' + token + '_' + String.valueOf(DateTime.now().getTime()));
        requestData.put('type', typeValue);
        requestData.put('valueType', valueTypeValue);
        requestData.put('calculationType', calculationTypeValue);
        requestData.put('currencyIsoCode', currencyIsoCode);
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

    private static void setScholarshipActive(Id scholarshipId) {
        String activeStatus = pickValue(Ken_Scholarship_Discount__c.Status__c.getDescribe(), 'active');
        System.assertEquals('active', String.valueOf(activeStatus).toLowerCase(), 'Active status value is required for this test.');
        update new Ken_Scholarship_Discount__c(Id = scholarshipId, Status__c = activeStatus);
    }

    private static void setScholarshipInactive(Id scholarshipId) {
        String inactiveStatus = pickInactiveStatusValue();
        System.assertNotEquals(null, inactiveStatus, 'A non-active status value is required for this test.');
        update new Ken_Scholarship_Discount__c(Id = scholarshipId, Status__c = inactiveStatus);
    }

    @IsTest
    static void delete_blocksActiveScholarship() {
        Id scholarshipId = createScholarship('ACTIVE');
        setScholarshipActive(scholarshipId);

        Test.startTest();
        Database.DeleteResult result = Database.delete(new Ken_Scholarship_Discount__c(Id = scholarshipId), false);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess());
        System.assert(result.getErrors()[0].getMessage().contains('it is Active'));
        System.assertEquals(
            1,
            [SELECT Count() FROM Ken_Scholarship_Discount__c WHERE Id = :scholarshipId]
        );
    }

    @IsTest
    static void delete_blocksReferencedScholarship() {
        Id scholarshipId = createScholarship('REF');
        setScholarshipInactive(scholarshipId);

        insert new Ken_Scholarship_Discount_Connection__c(
            Name = 'Conn_' + String.valueOf(DateTime.now().getTime()),
            Ken_Scholarship_Discount__c = scholarshipId
        );

        Test.startTest();
        Database.DeleteResult result = Database.delete(new Ken_Scholarship_Discount__c(Id = scholarshipId), false);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess());
        System.assert(result.getErrors()[0].getMessage().contains('it is referenced in child records'));
        System.assertEquals(
            1,
            [SELECT Count() FROM Ken_Scholarship_Discount__c WHERE Id = :scholarshipId]
        );
    }

    @IsTest
    static void delete_allowsInactiveUnreferencedScholarship() {
        Id scholarshipId = createScholarship('INACTIVE');
        setScholarshipInactive(scholarshipId);

        Test.startTest();
        Database.DeleteResult result = Database.delete(new Ken_Scholarship_Discount__c(Id = scholarshipId), false);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess());
        System.assertEquals(
            0,
            [SELECT Count() FROM Ken_Scholarship_Discount__c WHERE Id = :scholarshipId]
        );
    }
}