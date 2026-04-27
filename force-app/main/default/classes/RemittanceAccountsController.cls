public with sharing class RemittanceAccountsController {
    private static final String LINKED_LEVEL_INSTITUTE = 'Institute Level';
    private static final String LINKED_LEVEL_PROGRAM = 'Program Level';
    private static final String LINKED_LEVEL_FEE_HEAD = 'Fee Head Level';
    private static final String ERROR_GATEWAY_LINK_IN_FEE_USAGE =
        'Cannot delete this Payment Gateway assignment because the Remittance Account is used in Fee Structures or Fee Types.';

    public class RemittanceAccountRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String bankAccountName;
        @AuraEnabled public String bankName;
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String ledgerCode;
        @AuraEnabled public String parentMerchantId;
        @AuraEnabled public String merchantId1;
        @AuraEnabled public String merchantId2;
        @AuraEnabled public String merchantId3;
        @AuraEnabled public String accountType;
        @AuraEnabled public String address;
        @AuraEnabled public String currencyIsoCode;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Id ownerId;
        @AuraEnabled public String ownerName;
        @AuraEnabled public Id createdById;
        @AuraEnabled public String createdByName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Id lastModifiedById;
        @AuraEnabled public String lastModifiedByName;
        @AuraEnabled public Datetime lastModifiedDate;
    }

    public class OptionRow {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Boolean isDefault;
    }

    public class RemittanceGatewayLinkRow {
        @AuraEnabled public Id id;
        @AuraEnabled public Id remittanceAccountId;
        @AuraEnabled public String remittanceAccountName;
        @AuraEnabled public Id paymentGatewayId;
        @AuraEnabled public String paymentGatewayName;
        @AuraEnabled public String gatewayDisplayName;
        @AuraEnabled public Id merchantCredentialId;
        @AuraEnabled public String merchantCredentialName;
        @AuraEnabled public String gatewayExternalReference;
        @AuraEnabled public String parentMerchantId;
        @AuraEnabled public String subMerchantId;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Datetime lastModifiedDate;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionRow> searchPaymentGateways(String searchTerm, Integer limitSize) {
        String normalizedSearchTerm = String.isBlank(searchTerm) ? '' : searchTerm.trim();
        Integer normalizedLimitSize = limitSize == null ? 20 : limitSize;
        if (normalizedLimitSize < 1) {
            normalizedLimitSize = 20;
        }
        if (normalizedLimitSize > 100) {
            normalizedLimitSize = 100;
        }

        String queryTerm = '%' + normalizedSearchTerm + '%';
        List<Payment_Gateway__c> gateways = new List<Payment_Gateway__c>();
        if (String.isBlank(normalizedSearchTerm)) {
            gateways = [
                SELECT
                    Id,
                    Name,
                    Gateway_Display_Name__c,
                    External_Reference__c
                FROM Payment_Gateway__c WHERE Status__c = 'Active'
                ORDER BY Name
                LIMIT :normalizedLimitSize
            ];
        } else {
            gateways = [
                SELECT
                    Id,
                    Name,
                    Gateway_Display_Name__c,
                    External_Reference__c
                FROM Payment_Gateway__c
                WHERE Status__c = 'Active' AND (Name LIKE :queryTerm
                OR Gateway_Display_Name__c LIKE :queryTerm
                OR External_Reference__c LIKE :queryTerm) 
                ORDER BY Name
                LIMIT :normalizedLimitSize
            ];
        }

        List<OptionRow> options = new List<OptionRow>();
        for (Payment_Gateway__c gateway : gateways) {
            OptionRow option = new OptionRow();
            String primaryName = String.isBlank(gateway.Name)
                ? 'Payment Gateway'
                : gateway.Name;
            String secondaryName = String.isBlank(gateway.Gateway_Display_Name__c)
                ? null
                : gateway.Gateway_Display_Name__c;
            String externalReference = String.isBlank(gateway.External_Reference__c)
                ? null
                : gateway.External_Reference__c;
            List<String> labelParts = new List<String>{ primaryName };
            if (secondaryName != null && secondaryName != primaryName) {
                labelParts.add(secondaryName);
            }
            if (externalReference != null) {
                labelParts.add(externalReference);
            }
            option.label = String.join(labelParts, ' - ');
            option.value = gateway.Id;
            options.add(option);
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<RemittanceAccountRow> getRemittanceAccounts() {
        List<Ken_Bank_Account_Master__c> rows = [
            SELECT
                Id,
                Name,
                Bank_Account_Name__c,
                Bank_Name__c,
                Account_Number__c,
                Ledger_Code__c,
                Parent_Merchant_Id__c,
                Merchant_ID_1__c,
                Merchant_ID_2__c,
                Merchant_ID_3__c,
                Account_Type__c,
                Address__c,
                CurrencyIsoCode,
                Is_Active__c,
                OwnerId,
                Owner.Name,
                CreatedById,
                CreatedBy.Name,
                CreatedDate,
                LastModifiedById,
                LastModifiedBy.Name,
                LastModifiedDate
            FROM Ken_Bank_Account_Master__c
            ORDER BY LastModifiedDate DESC
            LIMIT 500
        ];

        List<RemittanceAccountRow> result = new List<RemittanceAccountRow>();
        for (Ken_Bank_Account_Master__c row : rows) {
            RemittanceAccountRow mapped = new RemittanceAccountRow();
            mapped.id = row.Id;
            mapped.name = row.Name;
            mapped.bankAccountName = row.Bank_Account_Name__c;
            mapped.bankName = (String) row.get('Bank_Name__c');
            mapped.accountNumber = row.Account_Number__c;
            mapped.ledgerCode = (String) row.get('Ledger_Code__c');
            mapped.parentMerchantId = (String) row.get('Parent_Merchant_Id__c');
            mapped.merchantId1 = (String) row.get('Merchant_ID_1__c');
            mapped.merchantId2 = (String) row.get('Merchant_ID_2__c');
            mapped.merchantId3 = (String) row.get('Merchant_ID_3__c');
            mapped.accountType = row.Account_Type__c;
            mapped.address = row.Address__c;
            mapped.currencyIsoCode = row.CurrencyIsoCode;
            mapped.isActive = row.Is_Active__c;
            mapped.ownerId = row.OwnerId;
            mapped.ownerName = row.Owner != null ? row.Owner.Name : null;
            mapped.createdById = row.CreatedById;
            mapped.createdByName = row.CreatedBy != null ? row.CreatedBy.Name : null;
            mapped.createdDate = row.CreatedDate;
            mapped.lastModifiedById = row.LastModifiedById;
            mapped.lastModifiedByName = row.LastModifiedBy != null ? row.LastModifiedBy.Name : null;
            mapped.lastModifiedDate = row.LastModifiedDate;
            result.add(mapped);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionRow> getAccountTypeOptions() {
        Map<String, String> labelToValue = new Map<String, String>();
        for (Schema.PicklistEntry entry : Ken_Bank_Account_Master__c.Account_Type__c.getDescribe().getPicklistValues()) {
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
    public static List<OptionRow> getCurrencyOptions() {
        List<OptionRow> options = new List<OptionRow>();
        for (Schema.PicklistEntry entry : Ken_Bank_Account_Master__c.CurrencyIsoCode.getDescribe().getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            OptionRow option = new OptionRow();
            option.label = entry.getLabel();
            option.value = entry.getValue();
            option.isDefault = entry.isDefaultValue();
            options.add(option);
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionRow> getLinkedEntityOptions(String linkedLevel) {
        String normalizedLinkedLevel = linkedLevel == null ? '' : linkedLevel.trim();
        List<OptionRow> options = new List<OptionRow>();

        if (normalizedLinkedLevel == LINKED_LEVEL_INSTITUTE) {
            List<Account> accounts = [
                SELECT Id, Name, RecordType.Name
                FROM Account
                WHERE RecordType.Name = 'Institute'
                ORDER BY Name ASC
                LIMIT 500
            ];
            for (Account accountRow : accounts) {
                OptionRow option = new OptionRow();
                option.label = accountRow.Name;
                option.value = accountRow.Id;
                options.add(option);
            }
            return options;
        }

        if (normalizedLinkedLevel == LINKED_LEVEL_PROGRAM) {
            List<LearningProgram> programs = [
                SELECT Id, Name
                FROM LearningProgram
                ORDER BY Name ASC
                LIMIT 500
            ];
            for (LearningProgram programRow : programs) {
                OptionRow option = new OptionRow();
                option.label = programRow.Name;
                option.value = programRow.Id;
                options.add(option);
            }
            return options;
        }

        if (normalizedLinkedLevel == LINKED_LEVEL_FEE_HEAD) {
            List<Ken_Master_Fee_Head__c> feeHeads = [
                SELECT Id, Name, Fee_Head_Name__c
                FROM Ken_Master_Fee_Head__c
                ORDER BY Fee_Head_Name__c ASC, Name ASC
                LIMIT 500
            ];
            for (Ken_Master_Fee_Head__c feeHeadRow : feeHeads) {
                OptionRow option = new OptionRow();
                option.label = String.isBlank(feeHeadRow.Fee_Head_Name__c)
                    ? feeHeadRow.Name
                    : feeHeadRow.Fee_Head_Name__c;
                option.value = feeHeadRow.Id;
                options.add(option);
            }
            return options;
        }

        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<RemittanceGatewayLinkRow> getRemittanceGatewayLinks(Id remittanceAccountId) {
        if (remittanceAccountId == null) {
            return new List<RemittanceGatewayLinkRow>();
        }

        List<Remittance_Gateway_Link__c> links = [
            SELECT
                Id,
                Remittance_Account__c,
                Remittance_Account__r.Bank_Account_Name__c,
                Payment_Gateway__c,
                Parent_Merchant_Id__c,
                Sub_Merchant_Id__c,
                Is_Active__c,
                LastModifiedDate
            FROM Remittance_Gateway_Link__c
            WHERE Remittance_Account__c = :remittanceAccountId
            ORDER BY LastModifiedDate DESC
        ];

        Set<Id> gatewayIds = new Set<Id>();
        for (Remittance_Gateway_Link__c linkRow : links) {
            Id gatewayId = toIdIfValid(linkRow.Payment_Gateway__c);
            if (gatewayId != null) {
                gatewayIds.add(gatewayId);
            }
        }

        Map<Id, Payment_Gateway__c> gatewayById = new Map<Id, Payment_Gateway__c>();
        Map<Id, NamedCredential> merchantCredentialById = new Map<Id, NamedCredential>();
        if (!gatewayIds.isEmpty()) {
            for (Payment_Gateway__c gateway : [
                SELECT
                    Id,
                    Name,
                    Gateway_Display_Name__c,
                    Merchant_Credential_Id__c,
                    External_Reference__c
                FROM Payment_Gateway__c
                WHERE Id IN :gatewayIds
            ]) {
                gatewayById.put(gateway.Id, gateway);
                Id merchantCredentialId = toIdIfValid(gateway.Merchant_Credential_Id__c);
                if (merchantCredentialId != null) {
                    merchantCredentialById.put(merchantCredentialId, null);
                }
            }
        }

        if (!merchantCredentialById.isEmpty()) {
            merchantCredentialById = new Map<Id, NamedCredential>([
                SELECT Id, MasterLabel
                FROM NamedCredential
                WHERE Id IN :merchantCredentialById.keySet()
            ]);
        }

        List<RemittanceGatewayLinkRow> result = new List<RemittanceGatewayLinkRow>();
        for (Remittance_Gateway_Link__c linkRow : links) {
            RemittanceGatewayLinkRow dto = new RemittanceGatewayLinkRow();
            dto.id = linkRow.Id;
            dto.remittanceAccountId = linkRow.Remittance_Account__c;
            dto.remittanceAccountName = linkRow.Remittance_Account__r == null
                ? null
                : linkRow.Remittance_Account__r.Bank_Account_Name__c;
            dto.paymentGatewayId = toIdIfValid(linkRow.Payment_Gateway__c);
            Payment_Gateway__c matchedGateway = dto.paymentGatewayId == null ? null : gatewayById.get(dto.paymentGatewayId);
            Id merchantCredentialId = matchedGateway == null ? null : toIdIfValid(matchedGateway.Merchant_Credential_Id__c);
            dto.paymentGatewayName = matchedGateway == null ? null : matchedGateway.Name;
            dto.gatewayDisplayName = matchedGateway == null ? null : matchedGateway.Gateway_Display_Name__c;
            dto.merchantCredentialId = merchantCredentialId;
            dto.merchantCredentialName = merchantCredentialId == null
                ? null
                : merchantCredentialById.containsKey(merchantCredentialId)
                    ? merchantCredentialById.get(merchantCredentialId).MasterLabel
                    : null;
            dto.gatewayExternalReference = matchedGateway == null ? null : matchedGateway.External_Reference__c;
            dto.parentMerchantId = linkRow.Parent_Merchant_Id__c;
            dto.subMerchantId = linkRow.Sub_Merchant_Id__c;
            dto.isActive = linkRow.Is_Active__c;
            dto.lastModifiedDate = linkRow.LastModifiedDate;
            result.add(dto);
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static RemittanceGatewayLinkRow getPaymentGatewayMerchantSeed(Id paymentGatewayId) {
        if (paymentGatewayId == null) {
            return null;
        }

        Payment_Gateway__c gateway = [
            SELECT
                Id,
                Name,
                Gateway_Display_Name__c,
                Merchant_Credential_Id__c,
                External_Reference__c
            FROM Payment_Gateway__c
            WHERE Id = :paymentGatewayId
            LIMIT 1
        ];
        Map<String, String> gatewayMerchantValues = getGatewayMerchantValues(paymentGatewayId);
        Id merchantCredentialId = toIdIfValid(gateway.Merchant_Credential_Id__c);
        NamedCredential merchantCredential = null;
        if (merchantCredentialId != null) {
            List<NamedCredential> merchantCredentials = [
                SELECT Id, MasterLabel
                FROM NamedCredential
                WHERE Id = :merchantCredentialId
                LIMIT 1
            ];
            merchantCredential = merchantCredentials.isEmpty() ? null : merchantCredentials[0];
        }

        RemittanceGatewayLinkRow row = new RemittanceGatewayLinkRow();
        row.paymentGatewayId = gateway.Id;
        row.paymentGatewayName = gateway.Name;
        row.gatewayDisplayName = gateway.Gateway_Display_Name__c;
        row.merchantCredentialId = merchantCredentialId;
        row.merchantCredentialName = merchantCredential == null ? null : merchantCredential.MasterLabel;
        row.gatewayExternalReference = gateway.External_Reference__c;
        row.parentMerchantId = gatewayMerchantValues.get('parentMerchantId');
        if (String.isBlank(row.parentMerchantId)) {
            row.parentMerchantId = gateway.External_Reference__c;
        }
        row.subMerchantId = gatewayMerchantValues.get('subMerchantId');
        if (String.isBlank(row.subMerchantId) && merchantCredential != null) {
            row.subMerchantId = merchantCredential.MasterLabel;
        }
        return row;
    }

    @AuraEnabled
    public static Id upsertRemittanceGatewayLink(
        Id remittanceGatewayLinkId,
        Id remittanceAccountId,
        Id paymentGatewayId,
        String parentMerchantId,
        String subMerchantId,
        Boolean isActive
    ) {
        if (remittanceAccountId == null) {
            throw new AuraHandledException('Remittance Account is required.');
        }
        if (paymentGatewayId == null) {
            throw new AuraHandledException('Payment Gateway is required.');
        }

        String paymentGatewayIdText = String.valueOf(paymentGatewayId);
        List<Remittance_Gateway_Link__c> existingPair = [
            SELECT Id
            FROM Remittance_Gateway_Link__c
            WHERE Remittance_Account__c = :remittanceAccountId
            AND Payment_Gateway__c = :paymentGatewayIdText
            AND Id != :remittanceGatewayLinkId
            LIMIT 1
        ];
        if (!existingPair.isEmpty()) {
            throw new AuraHandledException('This Remittance Account is already linked to the selected Payment Gateway.');
        }

        String normalizedParentMerchantId = String.isBlank(parentMerchantId) ? null : parentMerchantId.trim();
        String normalizedSubMerchantId = String.isBlank(subMerchantId) ? null : subMerchantId.trim();

        Remittance_Gateway_Link__c rowToSave;
        if (remittanceGatewayLinkId == null) {
            rowToSave = new Remittance_Gateway_Link__c();
        } else {
            rowToSave = [
                SELECT Id
                FROM Remittance_Gateway_Link__c
                WHERE Id = :remittanceGatewayLinkId
                LIMIT 1
            ];
        }

        rowToSave.Remittance_Account__c = remittanceAccountId;
        rowToSave.Payment_Gateway__c = paymentGatewayIdText;
        rowToSave.Parent_Merchant_Id__c = normalizedParentMerchantId;
        rowToSave.Sub_Merchant_Id__c = normalizedSubMerchantId;
        rowToSave.Is_Active__c = isActive == null ? true : isActive;

        upsert rowToSave;
        return rowToSave.Id;
    }

    private static Map<String, String> getGatewayMerchantValues(Id paymentGatewayId) {
        Map<String, String> result = new Map<String, String>{
            'parentMerchantId' => null,
            'subMerchantId' => null
        };
        if (paymentGatewayId == null) {
            return result;
        }

        Payment_Gateway__c gateway = [
            SELECT Id, Parent_Merchant_Id__c, Sub_Merchant_Id__c
            FROM Payment_Gateway__c
            WHERE Id = :paymentGatewayId
            LIMIT 1
        ];

        result.put('parentMerchantId', gateway.Parent_Merchant_Id__c);
        result.put('subMerchantId', gateway.Sub_Merchant_Id__c);
        return result;
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

    @AuraEnabled
    public static void deleteRemittanceGatewayLink(Id remittanceGatewayLinkId) {
        if (remittanceGatewayLinkId == null) {
            return;
        }
        Remittance_Gateway_Link__c linkRow = [
            SELECT Id, Remittance_Account__c
            FROM Remittance_Gateway_Link__c
            WHERE Id = :remittanceGatewayLinkId
            LIMIT 1
        ];

        if (isRemittanceUsedInFeeConfigurations(linkRow.Remittance_Account__c)) {
            throw new AuraHandledException(ERROR_GATEWAY_LINK_IN_FEE_USAGE);
        }

        delete linkRow;
    }

    private static Boolean isRemittanceUsedInFeeConfigurations(Id remittanceAccountId) {
        if (remittanceAccountId == null) {
            return false;
        }

        if ([SELECT COUNT() FROM Ken_Fee_Set_Line_Item__c WHERE Remittance_Account__c = :remittanceAccountId] > 0) {
            return true;
        }
        if ([SELECT COUNT() FROM Ken_Fee_Type_Remittance__c WHERE Remittance_Account__c = :remittanceAccountId] > 0) {
            return true;
        }
        if ([SELECT COUNT() FROM Ken_Fee_Type_Line_Item__c WHERE Remittance_Account__c = :remittanceAccountId] > 0) {
            return true;
        }

        return false;
    }

    @AuraEnabled
    public static void deleteRemittanceAccount(Id remittanceAccountId) {
        if (remittanceAccountId == null) {
            throw new AuraHandledException('Remittance account is required.');
        }
        try {
            delete [
                SELECT Id
                FROM Ken_Bank_Account_Master__c
                WHERE Id = :remittanceAccountId
                LIMIT 1
            ];
        } catch (DmlException ex) {
            throw new AuraHandledException(extractDeleteErrorMessage(ex));
        }
    }

    private static String extractDeleteErrorMessage(DmlException ex) {
        if (ex == null) {
            return 'Unable to delete remittance account.';
        }

        String message = null;
        if (ex.getNumDml() > 0) {
            message = ex.getDmlMessage(0);
        }
        if (String.isBlank(message)) {
            message = ex.getMessage();
        }
        if (String.isBlank(message)) {
            return 'Unable to delete remittance account.';
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
            return 'Unable to delete remittance account.';
        }
        return message;
    }

    @AuraEnabled
    public static Id createRemittanceAccount(
        String accountName,
        String bankName,
        String accountNumber,
        String ledgerCode,
        String linkedLevel,
        List<Id> linkedEntityIds,
        String merchantId1,
        String merchantId2,
        String merchantId3,
        Boolean isActive
    ) {
        return createRemittanceAccountV2(
            accountName,
            bankName,
            accountNumber,
            ledgerCode,
            linkedLevel,
            linkedEntityIds,
            merchantId1,
            merchantId2,
            merchantId3,
            isActive,
            null,
            null
        );
    }

    @AuraEnabled
    public static Id createRemittanceAccountV2(
        String accountName,
        String bankName,
        String accountNumber,
        String ledgerCode,
        String linkedLevel,
        List<Id> linkedEntityIds,
        String merchantId1,
        String merchantId2,
        String merchantId3,
        Boolean isActive,
        String parentMerchantId,
        String currencyIsoCode
    ) {
        String normalizedAccountName = accountName == null ? '' : accountName.trim();
        if (String.isBlank(normalizedAccountName)) {
            throw new AuraHandledException('Account Name is required.');
        }

        String normalizedBankName = bankName == null ? '' : bankName.trim();
        if (String.isBlank(normalizedBankName)) {
            throw new AuraHandledException('Bank is required.');
        }

        String normalizedAccountNumber = accountNumber == null ? '' : accountNumber.trim();
        if (String.isBlank(normalizedAccountNumber)) {
            throw new AuraHandledException('Account Number is required.');
        }

        String normalizedLedgerCode = ledgerCode == null ? '' : ledgerCode.trim();
        if (String.isBlank(normalizedLedgerCode)) {
            throw new AuraHandledException('Ledger Code is required.');
        }

        String normalizedLinkedLevel = linkedLevel == null ? '' : linkedLevel.trim();
        if (String.isBlank(normalizedLinkedLevel)) {
            throw new AuraHandledException('Linked Level is required.');
        }

        Ken_Bank_Account_Master__c recordToInsert = new Ken_Bank_Account_Master__c();
        recordToInsert.Name = normalizedAccountName;
        recordToInsert.Bank_Account_Name__c = normalizedAccountName;
        recordToInsert.put('Bank_Name__c', normalizedBankName);
        recordToInsert.Account_Number__c = normalizedAccountNumber;
        recordToInsert.put('Ledger_Code__c', normalizedLedgerCode);
        recordToInsert.put('Merchant_ID_1__c', String.isBlank(merchantId1) ? null : merchantId1.trim());
        recordToInsert.put('Merchant_ID_2__c', String.isBlank(merchantId2) ? null : merchantId2.trim());
        recordToInsert.put('Merchant_ID_3__c', String.isBlank(merchantId3) ? null : merchantId3.trim());
        recordToInsert.put('Parent_Merchant_Id__c', String.isBlank(parentMerchantId) ? null : parentMerchantId.trim());
        String normalizedCurrencyIsoCode = String.isBlank(currencyIsoCode) ? null : currencyIsoCode.trim();
        if (!String.isBlank(normalizedCurrencyIsoCode)) {
            recordToInsert.CurrencyIsoCode = normalizedCurrencyIsoCode;
        }
        recordToInsert.Is_Active__c = isActive == null ? true : isActive;

        insert recordToInsert;
        applyLinkedEntityMappings(recordToInsert.Id, normalizedLinkedLevel, linkedEntityIds);
        return recordToInsert.Id;
    }

    @AuraEnabled
    public static Id updateRemittanceAccount(
        Id remittanceAccountId,
        String accountName,
        String bankName,
        String accountNumber,
        String ledgerCode,
        String merchantId1,
        String merchantId2,
        String merchantId3,
        String parentMerchantId,
        Boolean isActive,
        String currencyIsoCode
    ) {
        if (remittanceAccountId == null) {
            throw new AuraHandledException('Remittance account is required.');
        }

        String normalizedAccountName = accountName == null ? '' : accountName.trim();
        if (String.isBlank(normalizedAccountName)) {
            throw new AuraHandledException('Account Name is required.');
        }

        String normalizedBankName = bankName == null ? '' : bankName.trim();
        if (String.isBlank(normalizedBankName)) {
            throw new AuraHandledException('Bank is required.');
        }

        String normalizedAccountNumber = accountNumber == null ? '' : accountNumber.trim();
        if (String.isBlank(normalizedAccountNumber)) {
            throw new AuraHandledException('Account Number is required.');
        }

        String normalizedLedgerCode = ledgerCode == null ? '' : ledgerCode.trim();
        if (String.isBlank(normalizedLedgerCode)) {
            throw new AuraHandledException('Ledger Code is required.');
        }

        Ken_Bank_Account_Master__c existingRecord = [
            SELECT Id, CurrencyIsoCode
            FROM Ken_Bank_Account_Master__c
            WHERE Id = :remittanceAccountId
            LIMIT 1
        ];

        existingRecord.Name = normalizedAccountName;
        existingRecord.Bank_Account_Name__c = normalizedAccountName;
        existingRecord.put('Bank_Name__c', normalizedBankName);
        existingRecord.Account_Number__c = normalizedAccountNumber;
        existingRecord.put('Ledger_Code__c', normalizedLedgerCode);
        existingRecord.put('Merchant_ID_1__c', String.isBlank(merchantId1) ? null : merchantId1.trim());
        existingRecord.put('Merchant_ID_2__c', String.isBlank(merchantId2) ? null : merchantId2.trim());
        existingRecord.put('Merchant_ID_3__c', String.isBlank(merchantId3) ? null : merchantId3.trim());
        existingRecord.put('Parent_Merchant_Id__c', String.isBlank(parentMerchantId) ? null : parentMerchantId.trim());
        String normalizedCurrencyIsoCode = String.isBlank(currencyIsoCode) ? null : currencyIsoCode.trim();
        if (!String.isBlank(normalizedCurrencyIsoCode)) {
            existingRecord.CurrencyIsoCode = normalizedCurrencyIsoCode;
        }
        existingRecord.Is_Active__c = isActive == null ? true : isActive;
        update existingRecord;

        return existingRecord.Id;
    }

    private static void applyLinkedEntityMappings(
        Id remittanceAccountId,
        String linkedLevel,
        List<Id> linkedEntityIds
    ) {
        if (remittanceAccountId == null || linkedEntityIds == null || linkedEntityIds.isEmpty()) {
            return;
        }

        if (linkedLevel == LINKED_LEVEL_INSTITUTE) {
            List<Account> accountsToUpdate = [
                SELECT Id, Remittance_Account__c
                FROM Account
                WHERE Id IN :linkedEntityIds
            ];
            for (Account accountRow : accountsToUpdate) {
                accountRow.put('Remittance_Account__c', remittanceAccountId);
            }
            if (!accountsToUpdate.isEmpty()) {
                update accountsToUpdate;
            }
            return;
        }

        if (linkedLevel == LINKED_LEVEL_PROGRAM) {
            List<LearningProgram> programsToUpdate = [
                SELECT Id, Remittance_Account__c
                FROM LearningProgram
                WHERE Id IN :linkedEntityIds
            ];
            for (LearningProgram programRow : programsToUpdate) {
                programRow.put('Remittance_Account__c', remittanceAccountId);
            }
            if (!programsToUpdate.isEmpty()) {
                update programsToUpdate;
            }
            return;
        }

        if (linkedLevel == LINKED_LEVEL_FEE_HEAD) {
            List<Ken_Master_Fee_Head__c> feeHeadsToUpdate = [
                SELECT Id, Default_Remittance_Account__c
                FROM Ken_Master_Fee_Head__c
                WHERE Id IN :linkedEntityIds
            ];
            for (Ken_Master_Fee_Head__c feeHeadRow : feeHeadsToUpdate) {
                feeHeadRow.put('Default_Remittance_Account__c', remittanceAccountId);
            }
            if (!feeHeadsToUpdate.isEmpty()) {
                update feeHeadsToUpdate;
            }
        }
    }
}