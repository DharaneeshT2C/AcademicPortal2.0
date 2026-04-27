public with sharing class PaymentGatewaysController {
    private static final String DELETE_BLOCKED_BY_FEE_USAGE_MESSAGE =
        'Cannot delete this Payment Gateway because it is assigned to a Remittance Account used in Fee Structures or Fee Types.';

    public class PaymentGatewayRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String paymentGatewayName;
        @AuraEnabled public String gatewayDisplayName;
        @AuraEnabled public Id paymentGatewayProviderId;
        @AuraEnabled public String paymentGatewayProviderName;
        @AuraEnabled public String externalReference;
        @AuraEnabled public String environment;
        @AuraEnabled public Id merchantCredentialId;
        @AuraEnabled public String merchantCredentialName;
        @AuraEnabled public String status;
        @AuraEnabled public String comments;
        @AuraEnabled public Datetime lastModifiedDate;
    }

    public class OptionRow {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    @AuraEnabled(cacheable=true)
    public static List<PaymentGatewayRow> getPaymentGateways() {
        List<Payment_Gateway__c> rows = [
            SELECT
                Id,
                Name,
                Gateway_Display_Name__c,
                Payment_Gateway_Provider__c,
                External_Reference__c,
                Environment__c,
                Merchant_Credential_Id__c,
                Status__c,
                Comments__c,
                LastModifiedDate
            FROM Payment_Gateway__c
            ORDER BY LastModifiedDate DESC
            LIMIT 500
        ];

        Set<Id> providerIds = new Set<Id>();
        Set<Id> merchantCredentialIds = new Set<Id>();
        for (Payment_Gateway__c row : rows) {
            if (row.Payment_Gateway_Provider__c != null) {
                providerIds.add(row.Payment_Gateway_Provider__c);
            }
            Id merchantCredentialId = toIdIfValid(row.Merchant_Credential_Id__c);
            if (merchantCredentialId != null) {
                merchantCredentialIds.add(merchantCredentialId);
            }
        }

        Map<Id, Payment_Gateway_Provider__c> providerById = providerIds.isEmpty()
            ? new Map<Id, Payment_Gateway_Provider__c>()
            : new Map<Id, Payment_Gateway_Provider__c>([
                SELECT Id, Name
                FROM Payment_Gateway_Provider__c
                WHERE Id IN :providerIds
            ]);
        Map<Id, NamedCredential> merchantCredentialById = merchantCredentialIds.isEmpty()
            ? new Map<Id, NamedCredential>()
            : new Map<Id, NamedCredential>([
                SELECT Id, MasterLabel
                FROM NamedCredential
                WHERE Id IN :merchantCredentialIds
            ]);

        List<PaymentGatewayRow> result = new List<PaymentGatewayRow>();
        for (Payment_Gateway__c row : rows) {
            PaymentGatewayRow mapped = new PaymentGatewayRow();
            mapped.id = row.Id;
            mapped.paymentGatewayName = row.Name;
            mapped.gatewayDisplayName = row.Gateway_Display_Name__c;
            mapped.paymentGatewayProviderId = row.Payment_Gateway_Provider__c;
            mapped.paymentGatewayProviderName = row.Payment_Gateway_Provider__c == null
                ? null
                : providerById.containsKey(row.Payment_Gateway_Provider__c)
                    ? providerById.get(row.Payment_Gateway_Provider__c).Name
                    : null;
            mapped.externalReference = row.External_Reference__c;
            mapped.environment = row.Environment__c;
            mapped.merchantCredentialId = toIdIfValid(row.Merchant_Credential_Id__c);
            mapped.merchantCredentialName = mapped.merchantCredentialId == null
                ? null
                : merchantCredentialById.containsKey(mapped.merchantCredentialId)
                    ? merchantCredentialById.get(mapped.merchantCredentialId).MasterLabel
                    : null;
            mapped.status = row.Status__c;
            mapped.comments = row.Comments__c;
            mapped.lastModifiedDate = row.LastModifiedDate;
            result.add(mapped);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionRow> getProviderOptions() {
        List<Payment_Gateway_Provider__c> rows = [
            SELECT Id, Name
            FROM Payment_Gateway_Provider__c
            WHERE Is_Active__c = true
            ORDER BY Name
            LIMIT 500
        ];

        List<OptionRow> options = new List<OptionRow>();
        for (Payment_Gateway_Provider__c row : rows) {
            OptionRow option = new OptionRow();
            option.label = String.isBlank(row.Name) ? String.valueOf(row.Id) : row.Name;
            option.value = String.valueOf(row.Id);
            options.add(option);
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionRow> getMerchantCredentialOptions() {
        List<NamedCredential> rows = [
            SELECT
                Id,
                MasterLabel,
                DeveloperName
            FROM NamedCredential
            ORDER BY MasterLabel
            LIMIT 500
        ];

        List<OptionRow> options = new List<OptionRow>();
        for (NamedCredential row : rows) {
            OptionRow option = new OptionRow();
            option.label = row.MasterLabel;
            if (String.isBlank(option.label)) {
                option.label = row.DeveloperName;
            }
            if (String.isBlank(option.label)) {
                option.label = String.valueOf(row.Id);
            }
            option.value = String.valueOf(row.Id);
            options.add(option);
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionRow> getStatusOptions() {
        Map<String, String> labelToValue = new Map<String, String>();
        for (Schema.PicklistEntry entry : Payment_Gateway__c.Status__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                labelToValue.put(entry.getLabel(), entry.getValue());
            }
        }

        List<String> labels = new List<String>(labelToValue.keySet());
        labels.sort();

        List<OptionRow> options = new List<OptionRow>();
        for (String label : labels) {
            OptionRow option = new OptionRow();
            option.label = label;
            option.value = labelToValue.get(label);
            options.add(option);
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionRow> getEnvironmentOptions() {
        Map<String, String> labelToValue = new Map<String, String>();
        for (Schema.PicklistEntry entry : Payment_Gateway__c.Environment__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                labelToValue.put(entry.getLabel(), entry.getValue());
            }
        }

        List<String> labels = new List<String>(labelToValue.keySet());
        labels.sort();

        List<OptionRow> options = new List<OptionRow>();
        for (String label : labels) {
            OptionRow option = new OptionRow();
            option.label = label;
            option.value = labelToValue.get(label);
            options.add(option);
        }
        return options;
    }

    @AuraEnabled
    public static Id createPaymentGateway(
        Id paymentGatewayProviderId,
        String paymentGatewayName,
        String gatewayDisplayName,
        String status,
        String environment,
        String externalReference,
        Id merchantCredentialId,
        String comments
    ) {
        Payment_Gateway__c gateway = new Payment_Gateway__c();
        applyGatewayValues(
            gateway,
            paymentGatewayProviderId,
            paymentGatewayName,
            gatewayDisplayName,
            status,
            environment,
            externalReference,
            merchantCredentialId,
            comments
        );

        insert gateway;
        return gateway.Id;
    }

    @AuraEnabled
    public static Id updatePaymentGateway(
        Id paymentGatewayId,
        Id paymentGatewayProviderId,
        String paymentGatewayName,
        String gatewayDisplayName,
        String status,
        String environment,
        String externalReference,
        Id merchantCredentialId,
        String comments
    ) {
        if (paymentGatewayId == null) {
            throw new AuraHandledException('Payment Gateway Id is required.');
        }

        Payment_Gateway__c gateway = [
            SELECT Id
            FROM Payment_Gateway__c
            WHERE Id = :paymentGatewayId
            LIMIT 1
        ];

        applyGatewayValues(
            gateway,
            paymentGatewayProviderId,
            paymentGatewayName,
            gatewayDisplayName,
            status,
            environment,
            externalReference,
            merchantCredentialId,
            comments
        );

        update gateway;
        return gateway.Id;
    }

    @AuraEnabled
    public static void deletePaymentGateway(Id paymentGatewayId) {
        if (paymentGatewayId == null) {
            throw new AuraHandledException('Payment Gateway Id is required.');
        }

        Payment_Gateway__c gateway = [
            SELECT Id, Status__c
            FROM Payment_Gateway__c
            WHERE Id = :paymentGatewayId
            LIMIT 1
        ];

        Map<Id, Integer> referenceCountByGatewayId = getReferenceCountByGatewayId(
            new Set<Id>{ paymentGatewayId },
            new Set<String>{ String.valueOf(paymentGatewayId) }
        );

        Boolean isActive = String.valueOf(gateway.Status__c).toLowerCase() == 'active';
        Boolean isReferenced = referenceCountByGatewayId.containsKey(paymentGatewayId)
            && referenceCountByGatewayId.get(paymentGatewayId) > 0;
        Boolean isUsedViaAssignedRemittance = isGatewayUsedByFeeConfigurations(paymentGatewayId);
        if (isUsedViaAssignedRemittance && !isActive && !isReferenced) {
            throw new AuraHandledException(DELETE_BLOCKED_BY_FEE_USAGE_MESSAGE);
        }
        if (isActive || isReferenced || isUsedViaAssignedRemittance) {
            List<String> blockers = new List<String>();
            if (isActive) {
                blockers.add('it is Active');
            }
            if (isReferenced) {
                blockers.add('it is referenced in child records');
            }
            if (isUsedViaAssignedRemittance) {
                blockers.add('its assigned Remittance Account is used in Fee Structures or Fee Types');
            }
            throw new AuraHandledException(
                'Cannot delete this Payment Gateway because '
                + String.join(blockers, ' and ')
                + '.'
            );
        }

        try {
            delete gateway;
        } catch (DmlException ex) {
            throw new AuraHandledException(extractDeleteErrorMessage(ex));
        }
    }

    private static Map<Id, Integer> getReferenceCountByGatewayId(Set<Id> gatewayIds, Set<String> gatewayIdTexts) {
        Map<Id, Integer> referenceCountByGatewayId = new Map<Id, Integer>();
        if (gatewayIds == null || gatewayIds.isEmpty()) {
            return referenceCountByGatewayId;
        }

        if (gatewayIdTexts != null && !gatewayIdTexts.isEmpty()) {
            mergeTextIdCounts(
                referenceCountByGatewayId,
                [
                    SELECT Payment_Gateway__c gatewayIdText, COUNT(Id) rowCount
                    FROM Remittance_Gateway_Link__c
                    WHERE Payment_Gateway__c IN :gatewayIdTexts
                    GROUP BY Payment_Gateway__c
                ],
                'gatewayIdText',
                'rowCount'
            );
        }

        Schema.DescribeSObjectResult gatewayDescribe = Payment_Gateway__c.SObjectType.getDescribe();
        for (Schema.ChildRelationship childRelationship : gatewayDescribe.getChildRelationships()) {
            if (childRelationship == null
                || childRelationship.getChildSObject() == null
                || childRelationship.getField() == null) {
                continue;
            }

            Schema.DescribeSObjectResult childDescribe = childRelationship.getChildSObject().getDescribe();
            if (childDescribe == null || !childDescribe.isQueryable()) {
                continue;
            }

            String childObjectApiName = childDescribe.getName();
            String relationshipFieldApiName = childRelationship.getField().getDescribe().getName();
            if (String.isBlank(childObjectApiName) || String.isBlank(relationshipFieldApiName)) {
                continue;
            }

            String soql =
                'SELECT ' + relationshipFieldApiName + ' gatewayId, COUNT(Id) rowCount' +
                ' FROM ' + childObjectApiName +
                ' WHERE ' + relationshipFieldApiName + ' IN :gatewayIds' +
                ' GROUP BY ' + relationshipFieldApiName;

            try {
                List<AggregateResult> relatedRows = Database.query(soql);
                mergeCounts(referenceCountByGatewayId, relatedRows, 'gatewayId', 'rowCount');
            } catch (Exception ex) {
                continue;
            }
        }

        return referenceCountByGatewayId;
    }

    private static Boolean isGatewayUsedByFeeConfigurations(Id paymentGatewayId) {
        if (paymentGatewayId == null) {
            return false;
        }

        Set<Id> remittanceAccountIds = new Set<Id>();
        for (Remittance_Gateway_Link__c linkRow : [
            SELECT Remittance_Account__c
            FROM Remittance_Gateway_Link__c
            WHERE Payment_Gateway__c = :String.valueOf(paymentGatewayId)
        ]) {
            if (linkRow.Remittance_Account__c != null) {
                remittanceAccountIds.add(linkRow.Remittance_Account__c);
            }
        }

        if (remittanceAccountIds.isEmpty()) {
            return false;
        }

        if ([SELECT COUNT() FROM Ken_Fee_Set_Line_Item__c WHERE Remittance_Account__c IN :remittanceAccountIds] > 0) {
            return true;
        }
        if ([SELECT COUNT() FROM Ken_Fee_Type_Remittance__c WHERE Remittance_Account__c IN :remittanceAccountIds] > 0) {
            return true;
        }
        if ([SELECT COUNT() FROM Ken_Fee_Type_Line_Item__c WHERE Remittance_Account__c IN :remittanceAccountIds] > 0) {
            return true;
        }

        return false;
    }

    private static void mergeTextIdCounts(
        Map<Id, Integer> totalByGatewayId,
        List<AggregateResult> rows,
        String gatewayIdTextKey,
        String countKey
    ) {
        if (totalByGatewayId == null || rows == null || rows.isEmpty()) {
            return;
        }

        for (AggregateResult row : rows) {
            String rawGatewayId = (String) row.get(gatewayIdTextKey);
            Id gatewayId = toIdIfValid(rawGatewayId);
            if (gatewayId == null) {
                continue;
            }

            Integer rowCount = Integer.valueOf(String.valueOf(row.get(countKey)));
            Integer existingCount = totalByGatewayId.containsKey(gatewayId)
                ? totalByGatewayId.get(gatewayId)
                : 0;
            totalByGatewayId.put(gatewayId, existingCount + rowCount);
        }
    }

    private static void mergeCounts(
        Map<Id, Integer> totalByGatewayId,
        List<AggregateResult> rows,
        String gatewayIdKey,
        String countKey
    ) {
        if (totalByGatewayId == null || rows == null || rows.isEmpty()) {
            return;
        }

        for (AggregateResult row : rows) {
            Id gatewayId = (Id) row.get(gatewayIdKey);
            if (gatewayId == null) {
                continue;
            }

            Integer rowCount = Integer.valueOf(String.valueOf(row.get(countKey)));
            Integer existingCount = totalByGatewayId.containsKey(gatewayId)
                ? totalByGatewayId.get(gatewayId)
                : 0;
            totalByGatewayId.put(gatewayId, existingCount + rowCount);
        }
    }

    private static String extractDeleteErrorMessage(DmlException ex) {
        if (ex == null) {
            return 'Unable to delete payment gateway.';
        }

        String message = null;
        if (ex.getNumDml() > 0) {
            message = ex.getDmlMessage(0);
        }
        if (String.isBlank(message)) {
            message = ex.getMessage();
        }
        if (String.isBlank(message)) {
            return 'Unable to delete payment gateway.';
        }

        Integer markerIndex = message.indexOf('FIELD_CUSTOM_VALIDATION_EXCEPTION,');
        if (markerIndex >= 0) {
            message = message.substring(markerIndex + 'FIELD_CUSTOM_VALIDATION_EXCEPTION,'.length()).trim();
        } else {
            markerIndex = message.indexOf('CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY,');
            if (markerIndex >= 0) {
                message = message.substring(markerIndex + 'CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY,'.length()).trim();
            }
        }

        if (message.endsWith(', []')) {
            message = message.substring(0, message.length() - 5).trim();
        }
        if (String.isBlank(message)) {
            return 'Unable to delete payment gateway.';
        }
        return message;
    }

    private static void applyGatewayValues(
        Payment_Gateway__c gateway,
        Id paymentGatewayProviderId,
        String paymentGatewayName,
        String gatewayDisplayName,
        String status,
        String environment,
        String externalReference,
        Id merchantCredentialId,
        String comments
    ) {
        String normalizedName = paymentGatewayName == null ? '' : paymentGatewayName.trim();
        if (String.isBlank(normalizedName)) {
            throw new AuraHandledException('Payment Gateway Name is required.');
        }

        String normalizedGatewayDisplayName = gatewayDisplayName == null ? '' : gatewayDisplayName.trim();
        if (String.isBlank(normalizedGatewayDisplayName)) {
            throw new AuraHandledException('Gateway Display Name is required.');
        }

        String normalizedExternalReference = externalReference == null ? '' : externalReference.trim();
        if (String.isBlank(normalizedExternalReference)) {
            throw new AuraHandledException('External Reference is required.');
        }

        String normalizedStatus = status == null ? '' : status.trim();
        if (String.isBlank(normalizedStatus)) {
            throw new AuraHandledException('Status is required.');
        }

        String normalizedEnvironment = environment == null ? null : environment.trim();
        if (normalizedEnvironment == '') {
            normalizedEnvironment = null;
        }

        gateway.Name = normalizedName;
        gateway.Payment_Gateway_Provider__c = paymentGatewayProviderId;
        gateway.Gateway_Display_Name__c = normalizedGatewayDisplayName;
        gateway.Status__c = normalizedStatus;
        gateway.Environment__c = normalizedEnvironment;
        gateway.External_Reference__c = normalizedExternalReference;
        gateway.Merchant_Credential_Id__c = merchantCredentialId == null ? null : String.valueOf(merchantCredentialId);
        gateway.Comments__c = comments == null ? null : comments.trim();
    }

    private static Id toIdIfValid(String rawId) {
        String normalizedValue = String.isBlank(rawId) ? null : rawId.trim();
        if (normalizedValue == null) {
            return null;
        }
        if (normalizedValue.length() != 15 && normalizedValue.length() != 18) {
            return null;
        }
        try {
            return (Id) normalizedValue;
        } catch (Exception ex) {
            return null;
        }
    }
}