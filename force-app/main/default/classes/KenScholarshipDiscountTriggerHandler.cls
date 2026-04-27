public with sharing class KenScholarshipDiscountTriggerHandler {
    public static void handleBeforeDelete(List<Ken_Scholarship_Discount__c> oldRows) {
        if (oldRows == null || oldRows.isEmpty()) {
            return;
        }

        Set<Id> scholarshipIds = new Set<Id>();
        for (Ken_Scholarship_Discount__c row : oldRows) {
            if (row != null && row.Id != null) {
                scholarshipIds.add(row.Id);
            }
        }
        if (scholarshipIds.isEmpty()) {
            return;
        }

        Map<Id, Integer> referenceCountByScholarshipId = getReferenceCountByScholarshipId(scholarshipIds);
        for (Ken_Scholarship_Discount__c row : oldRows) {
            if (row == null || row.Id == null) {
                continue;
            }

            Boolean isActive = normalizeStatusToken(row.Status__c) == 'active';
            Boolean isReferenced = referenceCountByScholarshipId.containsKey(row.Id)
                && referenceCountByScholarshipId.get(row.Id) > 0;
            if (!isActive && !isReferenced) {
                continue;
            }

            List<String> blockers = new List<String>();
            if (isActive) {
                blockers.add('it is Active');
            }
            if (isReferenced) {
                blockers.add('it is referenced in child records');
            }
            row.addError(
                'Cannot delete this Scholarship because '
                + String.join(blockers, ' and ')
                + '.'
            );
        }
    }

    private static Map<Id, Integer> getReferenceCountByScholarshipId(Set<Id> scholarshipIds) {
        Map<Id, Integer> referenceCountByScholarshipId = new Map<Id, Integer>();
        if (scholarshipIds == null || scholarshipIds.isEmpty()) {
            return referenceCountByScholarshipId;
        }

        mergeCounts(
            referenceCountByScholarshipId,
            [
                SELECT Ken_Scholarship_Discount__c scholarshipId, COUNT(Id) rowCount
                FROM Ken_Scholarship_Discount_Connection__c
                WHERE Ken_Scholarship_Discount__c IN :scholarshipIds
                GROUP BY Ken_Scholarship_Discount__c
            ],
            'scholarshipId',
            'rowCount'
        );

        return referenceCountByScholarshipId;
    }

    private static void mergeCounts(
        Map<Id, Integer> totalByScholarshipId,
        List<AggregateResult> rows,
        String scholarshipIdKey,
        String countKey
    ) {
        if (totalByScholarshipId == null || rows == null || rows.isEmpty()) {
            return;
        }

        for (AggregateResult row : rows) {
            Id scholarshipId = (Id) row.get(scholarshipIdKey);
            if (scholarshipId == null) {
                continue;
            }

            Integer rowCount = Integer.valueOf(String.valueOf(row.get(countKey)));
            Integer existingCount = totalByScholarshipId.containsKey(scholarshipId)
                ? totalByScholarshipId.get(scholarshipId)
                : 0;
            totalByScholarshipId.put(scholarshipId, existingCount + rowCount);
        }
    }

    private static String normalizeStatusToken(String statusValue) {
        return String.isBlank(statusValue) ? '' : statusValue.trim().toLowerCase();
    }
}