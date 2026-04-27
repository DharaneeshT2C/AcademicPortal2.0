public with sharing class KenBankAccountMasterTriggerHandler {
    public static void handleBeforeDelete(List<Ken_Bank_Account_Master__c> oldRows) {
        if (oldRows == null || oldRows.isEmpty()) {
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        for (Ken_Bank_Account_Master__c row : oldRows) {
            if (row != null && row.Id != null) {
                accountIds.add(row.Id);
            }
        }
        if (accountIds.isEmpty()) {
            return;
        }

        Map<Id, Integer> referenceCountByAccountId = getReferenceCountByAccountId(accountIds);
        for (Ken_Bank_Account_Master__c row : oldRows) {
            if (row == null || row.Id == null) {
                continue;
            }

            Boolean isActive = row.Is_Active__c == true;
            Boolean isReferenced = referenceCountByAccountId.containsKey(row.Id)
                && referenceCountByAccountId.get(row.Id) > 0;
            if (!isActive && !isReferenced) {
                continue;
            }

            List<String> blockers = new List<String>();
            if (isActive) {
                blockers.add('it is Active');
            }
            if (isReferenced) {
                blockers.add('it is referenced in Fee Structures or Fee Types');
            }
            row.addError(
                'Cannot delete this Remittance Account because '
                + String.join(blockers, ' and ')
                + '.'
            );
        }
    }

    private static Map<Id, Integer> getReferenceCountByAccountId(Set<Id> accountIds) {
        Map<Id, Integer> referenceCountByAccountId = new Map<Id, Integer>();
        if (accountIds == null || accountIds.isEmpty()) {
            return referenceCountByAccountId;
        }

        mergeCounts(
            referenceCountByAccountId,
            [
                SELECT Remittance_Account__c accountId, COUNT(Id) rowCount
                FROM Ken_Fee_Set_Line_Item__c
                WHERE Remittance_Account__c IN :accountIds
                GROUP BY Remittance_Account__c
            ],
            'accountId',
            'rowCount'
        );

        mergeCounts(
            referenceCountByAccountId,
            [
                SELECT Remittance_Account__c accountId, COUNT(Id) rowCount
                FROM Ken_Fee_Type_Line_Item__c
                WHERE Remittance_Account__c IN :accountIds
                GROUP BY Remittance_Account__c
            ],
            'accountId',
            'rowCount'
        );

        mergeCounts(
            referenceCountByAccountId,
            [
                SELECT Remittance_Account__c accountId, COUNT(Id) rowCount
                FROM Ken_Fee_Type_Remittance__c
                WHERE Remittance_Account__c IN :accountIds
                GROUP BY Remittance_Account__c
            ],
            'accountId',
            'rowCount'
        );

        return referenceCountByAccountId;
    }

    private static void mergeCounts(
        Map<Id, Integer> totalByAccountId,
        List<AggregateResult> rows,
        String accountIdKey,
        String countKey
    ) {
        if (totalByAccountId == null || rows == null || rows.isEmpty()) {
            return;
        }

        for (AggregateResult row : rows) {
            Id accountId = (Id) row.get(accountIdKey);
            if (accountId == null) {
                continue;
            }

            Integer rowCount = Integer.valueOf(String.valueOf(row.get(countKey)));
            Integer existingCount = totalByAccountId.containsKey(accountId)
                ? totalByAccountId.get(accountId)
                : 0;
            totalByAccountId.put(accountId, existingCount + rowCount);
        }
    }
}