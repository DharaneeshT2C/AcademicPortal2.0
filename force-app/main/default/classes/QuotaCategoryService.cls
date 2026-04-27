public with sharing class QuotaCategoryService {
    private static final String ERROR_CATEGORY_IN_USE =
        'Cannot delete category because it is used in fee plans or programme fee configurations.';
    private static final String ERROR_QUOTA_IN_USE =
        'Cannot delete quota because it is used in fee plans or programme fee configurations.';
    private static final String ERROR_DUPLICATE_QUOTA_CODE =
        'Quota code already exists. Enter a unique code.';

    public static List<String> getCategoryTypeOptions() {
        return QuotaCategorySelector.selectCategoryTypePicklistValues();
    }

    public static QuotaCategoryDtos.CategoryBuilderData getCategoryBuilderData(Id categoryId) {
        QuotaCategoryDtos.CategoryBuilderData data = new QuotaCategoryDtos.CategoryBuilderData();
        data.categoryTypeOptions = QuotaCategorySelector.selectCategoryTypePicklistValues();
        data.currencyOptions = getCurrencyOptions();
        data.category = getCategoryWithQuotas(categoryId);
        return data;
    }

    public static List<QuotaCategoryDtos.CategoryRow> getCategoriesWithQuotas() {
        List<Category__c> categories = QuotaCategorySelector.selectCategories();

        Set<Id> categoryIds = new Set<Id>();
        for (Category__c categoryRecord : categories) {
            Boolean isValid = categoryRecord != null && categoryRecord.Id != null;
            if (isValid) {
                categoryIds.add(categoryRecord.Id);
            }
        }

        List<Quota__c> quotas = QuotaCategorySelector.selectQuotasByCategoryIds(categoryIds);

        Map<Id, List<QuotaCategoryDtos.QuotaRow>> quotasByCategoryId = new Map<Id, List<QuotaCategoryDtos.QuotaRow>>();
        for (Quota__c quotaRecord : quotas) {
            Boolean isValid = quotaRecord != null && quotaRecord.Category__c != null;
            if (isValid) {
                if (!quotasByCategoryId.containsKey(quotaRecord.Category__c)) {
                    quotasByCategoryId.put(quotaRecord.Category__c, new List<QuotaCategoryDtos.QuotaRow>());
                }
                quotasByCategoryId.get(quotaRecord.Category__c).add(mapQuota(quotaRecord));
            }
        }

        List<QuotaCategoryDtos.CategoryRow> result = new List<QuotaCategoryDtos.CategoryRow>();
        for (Category__c categoryRecord : categories) {
            QuotaCategoryDtos.CategoryRow row = new QuotaCategoryDtos.CategoryRow();
            row.categoryId = categoryRecord.Id;
            row.categoryName = categoryRecord.Name;
            row.categoryType = categoryRecord.Category_Type__c;
            row.currencyCode = getCurrencyCode(categoryRecord);
            row.regulatorySource = categoryRecord.Regulatory_Source__c;
            row.isActive = categoryRecord.Active__c;
            row.createdByName = categoryRecord.CreatedBy == null ? null : categoryRecord.CreatedBy.Name;
            row.createdDate = categoryRecord.CreatedDate;
            row.lastUpdated = categoryRecord.LastModifiedDate;

            List<QuotaCategoryDtos.QuotaRow> childQuotas =
                quotasByCategoryId.containsKey(categoryRecord.Id)
                    ? quotasByCategoryId.get(categoryRecord.Id)
                    : new List<QuotaCategoryDtos.QuotaRow>();

            row.quotas = childQuotas;
            row.quotaCount = childQuotas.size();
            result.add(row);
        }

        return result;
    }

    public static QuotaCategoryDtos.CategoryRow getCategoryWithQuotas(Id categoryId) {
        if (categoryId == null) {
            return null;
        }

        Category__c categoryRecord = QuotaCategorySelector.selectCategoryById(categoryId);
        if (categoryRecord == null) {
            return null;
        }

        List<Quota__c> quotas = QuotaCategorySelector.selectQuotasByCategoryIds(new Set<Id>{ categoryId });
        List<QuotaCategoryDtos.QuotaRow> childQuotas = new List<QuotaCategoryDtos.QuotaRow>();
        for (Quota__c quotaRecord : quotas) {
            childQuotas.add(mapQuota(quotaRecord));
        }

        QuotaCategoryDtos.CategoryRow row = new QuotaCategoryDtos.CategoryRow();
        row.categoryId = categoryRecord.Id;
        row.categoryName = categoryRecord.Name;
        row.categoryType = categoryRecord.Category_Type__c;
        row.currencyCode = getCurrencyCode(categoryRecord);
        row.regulatorySource = categoryRecord.Regulatory_Source__c;
        row.isActive = categoryRecord.Active__c;
        row.createdByName = categoryRecord.CreatedBy == null ? null : categoryRecord.CreatedBy.Name;
        row.createdDate = categoryRecord.CreatedDate;
        row.lastUpdated = categoryRecord.LastModifiedDate;
        row.quotas = childQuotas;
        row.quotaCount = childQuotas.size();
        return row;
    }

    public static Id saveCategory(QuotaCategoryDtos.SaveCategoryRequest requestDto) {
        if (requestDto == null) {
            throw new AuraHandledException('Invalid request.');
        }
        if (String.isBlank(requestDto.categoryName)) {
            throw new AuraHandledException('Category Name is required.');
        }

        Category__c categoryRecord;
        Boolean isUpdate = requestDto.categoryId != null;

        if (isUpdate) {
            categoryRecord = [
                SELECT Id
                FROM Category__c
                WHERE Id = :requestDto.categoryId
                LIMIT 1
            ];
        } else {
            categoryRecord = new Category__c();
        }

        categoryRecord.Name = requestDto.categoryName.trim();
        categoryRecord.Category_Type__c = requestDto.categoryType;
        if (QuotaCategorySelector.hasCurrencyField()) {
            String normalizedCurrency = String.isBlank(requestDto.currencyCode) ? UserInfo.getDefaultCurrency() : requestDto.currencyCode;
            categoryRecord.put('CurrencyIsoCode', normalizedCurrency);
        }
        categoryRecord.Regulatory_Source__c = requestDto.regulatorySource;
        categoryRecord.Active__c = requestDto.isActive == null ? true : requestDto.isActive;

        upsert categoryRecord;
        return categoryRecord.Id;
    }

    public static Id saveQuota(QuotaCategoryDtos.SaveQuotaRequest requestDto) {
        if (requestDto == null) {
            throw new AuraHandledException('Invalid request.');
        }
        if (requestDto.categoryId == null) {
            throw new AuraHandledException('Category is required.');
        }
        if (String.isBlank(requestDto.quotaName)) {
            throw new AuraHandledException('Quota Name is required.');
        }
        if (String.isBlank(requestDto.code)) {
            throw new AuraHandledException('Code is required.');
        }

        validateReservationPercent(requestDto.reservationPercent);
        String normalizedCode = requestDto.code.trim();
        validateDuplicateQuotaCode(normalizedCode, requestDto.quotaId);

        Quota__c quotaRecord;
        Boolean isUpdate = requestDto.quotaId != null;

        if (isUpdate) {
            quotaRecord = [
                SELECT Id
                FROM Quota__c
                WHERE Id = :requestDto.quotaId
                LIMIT 1
            ];
        } else {
            quotaRecord = new Quota__c();
        }

        quotaRecord.Category__c = requestDto.categoryId;
        quotaRecord.Name = requestDto.quotaName.trim();
        quotaRecord.Code__c = normalizedCode;
        quotaRecord.Reservation_Percent__c = requestDto.reservationPercent;
        quotaRecord.Priority_Order__c = requestDto.priorityOrder;
        quotaRecord.Active__c = requestDto.isActive == null ? true : requestDto.isActive;

        try {
            upsert quotaRecord;
        } catch (DmlException ex) {
            if (isDuplicateCodeError(ex)) {
                throw new AuraHandledException(ERROR_DUPLICATE_QUOTA_CODE);
            }
            throw ex;
        }
        return quotaRecord.Id;
    }

    public static void deleteCategory(Id categoryId) {
        if (categoryId == null) {
            throw new AuraHandledException('Category is required.');
        }

        List<Quota__c> quotas = [
            SELECT Id
            FROM Quota__c
            WHERE Category__c = :categoryId
        ];

        Set<Id> quotaIds = new Set<Id>();
        for (Quota__c quotaRecord : quotas) {
            if (quotaRecord != null && quotaRecord.Id != null) {
                quotaIds.add(quotaRecord.Id);
            }
        }

        if (isCategoryUsedInFeeSetLines(categoryId) || isAnyQuotaUsedInFeeSetLines(quotaIds)) {
            throw new AuraHandledException(ERROR_CATEGORY_IN_USE);
        }

        if (!quotas.isEmpty()) {
            delete quotas;
        }

        delete [
            SELECT Id
            FROM Category__c
            WHERE Id = :categoryId
            LIMIT 1
        ];
    }

    public static void deleteQuota(Id quotaId) {
        if (quotaId == null) {
            throw new AuraHandledException('Quota is required.');
        }

        if (isQuotaUsedInFeeSetLines(quotaId)) {
            throw new AuraHandledException(ERROR_QUOTA_IN_USE);
        }

        delete [
            SELECT Id
            FROM Quota__c
            WHERE Id = :quotaId
            LIMIT 1
        ];
    }

    private static Boolean isCategoryUsedInFeeSetLines(Id categoryId) {
        Integer usageCount = [
            SELECT COUNT()
            FROM Ken_Fee_Set_Line_Item__c
            WHERE Category__c = :categoryId
        ];
        return usageCount > 0;
    }

    private static Boolean isAnyQuotaUsedInFeeSetLines(Set<Id> quotaIds) {
        if (quotaIds == null || quotaIds.isEmpty()) {
            return false;
        }
        Integer usageCount = [
            SELECT COUNT()
            FROM Ken_Fee_Set_Line_Item__c
            WHERE Quota__c IN :quotaIds
        ];
        return usageCount > 0;
    }

    private static Boolean isQuotaUsedInFeeSetLines(Id quotaId) {
        Integer usageCount = [
            SELECT COUNT()
            FROM Ken_Fee_Set_Line_Item__c
            WHERE Quota__c = :quotaId
        ];
        return usageCount > 0;
    }

    private static void validateDuplicateQuotaCode(String code, Id currentQuotaId) {
        List<Quota__c> existingQuotas = [
            SELECT Id
            FROM Quota__c
            WHERE Code__c = :code
            LIMIT 2
        ];

        for (Quota__c existingQuota : existingQuotas) {
            if (currentQuotaId == null || existingQuota.Id != currentQuotaId) {
                throw new AuraHandledException(ERROR_DUPLICATE_QUOTA_CODE);
            }
        }
    }

    private static void validateReservationPercent(Decimal reservationPercent) {
        if (reservationPercent == null) {
            return;
        }

        Boolean isLessThanZero = reservationPercent < 0;
        Boolean isGreaterThanHundred = reservationPercent > 100;

        if (isLessThanZero || isGreaterThanHundred) {
            throw new AuraHandledException('Reservation Percent must be between 0 and 100.');
        }
    }

    private static Boolean isDuplicateCodeError(DmlException ex) {
        if (ex == null) {
            return false;
        }

        for (Integer index = 0; index < ex.getNumDml(); index++) {
            if (ex.getDmlType(index) == StatusCode.DUPLICATE_VALUE) {
                return true;
            }
        }

        return ex.getMessage() != null && ex.getMessage().toLowerCase().contains('duplicate value');
    }

    private static QuotaCategoryDtos.QuotaRow mapQuota(Quota__c quotaRecord) {
        QuotaCategoryDtos.QuotaRow row = new QuotaCategoryDtos.QuotaRow();
        row.quotaId = quotaRecord.Id;
        row.categoryId = quotaRecord.Category__c;
        row.quotaName = quotaRecord.Name;
        row.code = quotaRecord.Code__c;
        row.reservationPercent = quotaRecord.Reservation_Percent__c;
        row.priorityOrder = quotaRecord.Priority_Order__c == null ? null : Integer.valueOf(quotaRecord.Priority_Order__c);
        row.isActive = quotaRecord.Active__c;
        row.lastUpdated = quotaRecord.LastModifiedDate;
        return row;
    }

    private static String getCurrencyCode(Category__c categoryRecord) {
        if (categoryRecord == null || !QuotaCategorySelector.hasCurrencyField()) {
            return null;
        }
        Object rawCurrency = categoryRecord.get('CurrencyIsoCode');
        return rawCurrency == null ? null : String.valueOf(rawCurrency);
    }

    private static List<QuotaCategoryDtos.CurrencyOption> getCurrencyOptions() {
        List<QuotaCategoryDtos.CurrencyOption> options = new List<QuotaCategoryDtos.CurrencyOption>();
        try {
            for (CurrencyType currencyRow : [
                SELECT IsoCode, DecimalPlaces
                FROM CurrencyType
                WHERE IsActive = true
                ORDER BY IsoCode ASC
            ]) {
                QuotaCategoryDtos.CurrencyOption option = new QuotaCategoryDtos.CurrencyOption();
                option.value = currencyRow.IsoCode;
                option.label = currencyRow.IsoCode;
                options.add(option);
            }
        } catch (Exception ex) {
            // CurrencyType may be unavailable in orgs where multi-currency is disabled.
        }
        if (options.isEmpty()) {
            QuotaCategoryDtos.CurrencyOption fallbackOption = new QuotaCategoryDtos.CurrencyOption();
            fallbackOption.value = UserInfo.getDefaultCurrency();
            fallbackOption.label = fallbackOption.value;
            options.add(fallbackOption);
        }
        return options;
    }
}