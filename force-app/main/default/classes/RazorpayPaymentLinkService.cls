public without sharing class RazorpayPaymentLinkService {
    private static final Integer RAZORPAY_REFERENCE_MAX_LENGTH = 40;
    private static final String FEE_ASSIGNMENT_OBJECT_API = 'Fee_Assignment__c';
    private static final String FEE_ASSIGNMENT_LINE_ITEM_OBJECT_API = 'Fee_Assignment_Line_Item__c';
    private static final String FEE_INSTALLMENT_OBJECT_API = 'Fee_Installment__c';
    private static final String FEE_INSTALLMENT_LINE_ITEM_OBJECT_API = 'Fee_Installment_Line_Item__c';
    private static final String INDIVIDUAL_APPLICATION_OBJECT_API = 'IndividualApplication';

    private class ResolvedLineItemRefs {
        public Id feeAssignmentId;
        public Id feeAssignmentLineItemId;
        public Id feeInstallmentId;
        public Id feeInstallmentLineItemId;
        public String accountId;
        public String applicationId;
    }

    // MAIN ENTRY for LWC
    @AuraEnabled
    public static RazorpayDtos.CreatePaymentLinkResponse createPaymentLink(String reqJson) {
        try {
            if (String.isBlank(reqJson)) {
                throw new AuraHandledException('Invalid request payload.');
            }
            RazorpayDtos.CreatePaymentLinkRequest req;
            req = (RazorpayDtos.CreatePaymentLinkRequest) JSON.deserialize(
                reqJson,
                RazorpayDtos.CreatePaymentLinkRequest.class
            );
            req.amount = resolveAmount(req);
            validateRequest(req);

            // Authorization / ownership checks (IMPORTANT)
            // Replace this with your real business logic.
            // Example: ensure Experience Cloud user can access the invoice record.
            enforceAccess(req.relatedRecordId);

            RazorpayConfig.Config cfg = RazorpayConfig.get();

            Long amountPaise = toMinorUnits(req.amount); // INR -> paise
            String currencyType = String.isBlank(req.currencyType) ? cfg.defaultCurrency : req.currencyType.trim();
            String sourceReference = req.reference;
            String paymentReference = generateUniquePaymentReference(sourceReference);

            // Build callback url (optional): your portal page that shows "processing"
            String callbackUrl = buildCallbackUrl(cfg.callbackBaseUrl, paymentReference);

            Map<String, Object> payload = new Map<String, Object>{
                'amount' => amountPaise,
                'currency' => currencyType,
                'description' => req.description,
                'reference_id' => paymentReference,
                'callback_url' => callbackUrl,
                'callback_method' => 'get',
                'notify' => new Map<String, Object>{
                    'sms' => cfg.enableSms,
                    'email' => cfg.enableEmail
                },
                'customer' => new Map<String, Object>{
                    'name' => req.customerName,
                    'email' => req.customerEmail,
                    'contact' => req.customerPhone
                }
            };

            RazorpayCalloutResult calloutResult = processCreatePaymentLinkCallout(payload);
            List<ResolvedLineItemRefs> resolvedLineItems = resolveLineItemReferences(req.lineItems);

            Payment_Transaction__c txn = new Payment_Transaction__c();
            String accountId = !String.isBlank(req.accountId)
                ? req.accountId
                : (resolvedLineItems != null && !resolvedLineItems.isEmpty() ? resolvedLineItems[0].accountId : null);
            Id accountLookupId = tryToId(accountId);
            if (accountLookupId != null) {
                txn.Account__c = accountLookupId;
            }
            txn.Amount__c = req.amount;
            txn.Payment_Status__c = 'Initiated';
            txn.External_Reference__c = paymentReference;
            String transactionRemarks = buildTransactionRemarks(
                sourceReference,
                paymentReference,
                normalizeRedirectUrl(req.successRedirectUrl)
            );
            if (!String.isBlank(transactionRemarks)) {
                txn.Remarks__c = transactionRemarks;
            }
            txn.Provider__c = 'Razorpay';
            txn.CurrencyIsoCode = currencyType;
            Id relatedApplicationId = tryToIdOfType(req.relatedRecordId, INDIVIDUAL_APPLICATION_OBJECT_API);
            if (relatedApplicationId == null) {
                relatedApplicationId = resolveFirstApplicationId(resolvedLineItems);
            }
            if (relatedApplicationId != null) {
                txn.Individual_Application__c = relatedApplicationId;
            }
            putFieldValueIfAvailable(
                txn,
                'Fee_Assignment__c',
                resolveFirstFeeAssignmentId(resolvedLineItems)
            );
            txn.Raw_Payload__c = calloutResult.rawPayload;
            txn.Payment_Gateway_Status__c = calloutResult.status;
            txn.External_Id__c = calloutResult.linkId;
            txn.Pay_URL__c = calloutResult.shortUrl;
            putFieldValueIfAvailable(txn, 'Requery_Attempt__c', 0);
            putFieldValueIfAvailable(txn, 'Next_Requery_At__c', System.now());
            putFieldValueIfAvailable(txn, 'CCA_Requery_Attempt__c', 0);
            putFieldValueIfAvailable(txn, 'CCA_Next_Requery_At__c', System.now());
            insert txn;

            if (req.lineItems != null && !req.lineItems.isEmpty()) {
                List<Payment_Transaction_Line_Item__c> items = new List<Payment_Transaction_Line_Item__c>();
                for (Integer lineIndex = 0; lineIndex < req.lineItems.size(); lineIndex++) {
                    RazorpayDtos.CreatePaymentLinkLineItem li = req.lineItems[lineIndex];
                    ResolvedLineItemRefs resolvedRefs = lineIndex < resolvedLineItems.size()
                        ? resolvedLineItems[lineIndex]
                        : new ResolvedLineItemRefs();
                    Payment_Transaction_Line_Item__c item = new Payment_Transaction_Line_Item__c();
                    item.Payment_Transaction__c = txn.Id;
                    item.Amount__c = resolveTransactionLineAmount(li, req.amount);
                    putFieldValueIfAvailable(item, 'Fee_Assignment__c', resolvedRefs.feeAssignmentId);
                    putFieldValueIfAvailable(item, 'Fee_Assignment_Line_Item__c', resolvedRefs.feeAssignmentLineItemId);
                    putFieldValueIfAvailable(item, 'Fee_Installment__c', resolvedRefs.feeInstallmentId);
                    putFieldValueIfAvailable(item, 'Fee_Installment_Line_Item__c', resolvedRefs.feeInstallmentLineItemId);
                    if (li != null && !String.isBlank(li.applicationId)) {
                        putFieldValueIfAvailable(
                            item,
                            'Individual_Application__c',
                            tryToIdOfType(li.applicationId, INDIVIDUAL_APPLICATION_OBJECT_API)
                        );
                    }
                    items.add(item);
                }
                insert items;
            }

            RazorpayDtos.CreatePaymentLinkResponse out = new RazorpayDtos.CreatePaymentLinkResponse();
            out.paymentRecordId = txn.Id;
            out.shortUrl = txn.Pay_URL__c;
            out.razorpayPaymentLinkId = txn.External_Id__c;
            out.status = txn.Payment_Gateway_Status__c;
            return out;
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new AuraHandledException(
                'Payment initiation failed: ' + ex.getMessage()
            );
        }
    }

    // Optional: polling endpoint for the "processing" page
    @AuraEnabled(cacheable=true)
    public static String getPaymentStatusByReference(String reference) {
        Payment_Transaction__c p = [
            SELECT Payment_Status__c
            FROM Payment_Transaction__c
            WHERE External_Reference__c = :reference
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return p.Payment_Status__c;
    }

    public class PaymentLinkStatusResponse {
        public String status;
        public String rawPayload;
    }

    public static PaymentLinkStatusResponse fetchPaymentLinkStatus(String paymentLinkId) {
        if (String.isBlank(paymentLinkId)) {
            throw new AuraHandledException('Payment link id is required for requery.');
        }

        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');
        request.setEndpoint(
            'callout:Razorpay_NC/v1/payment_links/' + EncodingUtil.urlEncode(paymentLinkId, 'UTF-8')
        );

        HttpResponse response = (new Http()).send(request);
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new AuraHandledException(
                'Razorpay status requery failed: ' + extractRazorpayError(response.getBody())
            );
        }

        Map<String, Object> responseBody =
            (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

        PaymentLinkStatusResponse result = new PaymentLinkStatusResponse();
        result.status = (String) responseBody.get('status');
        result.rawPayload = response.getBody();
        return result;
    }

    private static void validateRequest(RazorpayDtos.CreatePaymentLinkRequest req) {
        if (req == null) throw new AuraHandledException('Invalid request.');
        if (req.amount == null || req.amount <= 0) {
            String feeAssignmentId = null;
            if (req.lineItems != null && !req.lineItems.isEmpty()) {
                feeAssignmentId = req.lineItems[0].feeAssignmentId;
            }
            throw new AuraHandledException(
                'Amount must be greater than 0. Resolved amount=' +
                String.valueOf(req.amount) +
                ', FeeAssignmentId=' +
                String.valueOf(feeAssignmentId)
            );
        }
        if (String.isBlank(req.description)) throw new AuraHandledException('Description is required.');
        if (String.isBlank(req.reference)) throw new AuraHandledException('Reference is required.');
        if (String.isBlank(req.relatedRecordId)) throw new AuraHandledException('Related record is required.');
        if (req.lineItems == null || req.lineItems.isEmpty()) throw new AuraHandledException('At least one line item is required.');
        // Customer fields can be optional depending on your need; Razorpay allows some to be null.
    }

    private static Decimal resolveAmount(RazorpayDtos.CreatePaymentLinkRequest req) {
        if (req == null) {
            return null;
        }
        if (req.amount != null && req.amount > 0) {
            return req.amount;
        }
        if (req.lineItems == null || req.lineItems.isEmpty()) {
            return req.amount;
        }

        Set<Id> feeAssignmentIds = new Set<Id>();
        for (RazorpayDtos.CreatePaymentLinkLineItem lineItem : req.lineItems) {
            if (lineItem == null || String.isBlank(lineItem.feeAssignmentId)) {
                continue;
            }
            String candidateId = lineItem.feeAssignmentId.trim();
            if (candidateId.length() != 15 && candidateId.length() != 18) {
                continue;
            }
            try {
                feeAssignmentIds.add((Id) candidateId);
            } catch (Exception ex) {
                // Ignore invalid ids from client payload.
            }
        }

        if (feeAssignmentIds.isEmpty()) {
            return req.amount;
        }

        Map<Id, Fee_Assignment__c> feeAssignmentsById = new Map<Id, Fee_Assignment__c>([
            SELECT
                Id,
                Remaining_Amount_Formula__c,
                Total_Amount_Payable_Formula__c,
                Paid_Amount__c,
                Fee_Amount__c
            FROM Fee_Assignment__c
            WHERE Id IN :feeAssignmentIds
        ]);

        for (RazorpayDtos.CreatePaymentLinkLineItem lineItem : req.lineItems) {
            if (lineItem == null || String.isBlank(lineItem.feeAssignmentId)) {
                continue;
            }
            Id feeAssignmentId;
            try {
                feeAssignmentId = (Id) lineItem.feeAssignmentId.trim();
            } catch (Exception ex) {
                continue;
            }
            Fee_Assignment__c feeAssignment = feeAssignmentsById.get(feeAssignmentId);
            if (feeAssignment == null) {
                continue;
            }

            Decimal candidateAmount = feeAssignment.Remaining_Amount_Formula__c;
            if (candidateAmount == null || candidateAmount <= 0) {
                Decimal totalPayable = feeAssignment.Total_Amount_Payable_Formula__c == null
                    ? 0
                    : feeAssignment.Total_Amount_Payable_Formula__c;
                Decimal paidAmount = feeAssignment.Paid_Amount__c == null ? 0 : feeAssignment.Paid_Amount__c;
                candidateAmount = totalPayable - paidAmount;
            }
            if (candidateAmount == null || candidateAmount <= 0) {
                candidateAmount = feeAssignment.Fee_Amount__c;
            }
            if (candidateAmount != null && candidateAmount > 0) {
                return candidateAmount;
            }
        }

        return req.amount;
    }

    private static List<ResolvedLineItemRefs> resolveLineItemReferences(
        List<RazorpayDtos.CreatePaymentLinkLineItem> lineItems
    ) {
        List<ResolvedLineItemRefs> resolved = new List<ResolvedLineItemRefs>();
        if (lineItems == null || lineItems.isEmpty()) {
            return resolved;
        }

        Set<Id> feeAssignmentLineItemIdsToQuery = new Set<Id>();
        Set<Id> feeInstallmentLineItemIdsToQuery = new Set<Id>();
        Set<Id> feeInstallmentIdsToQuery = new Set<Id>();

        for (RazorpayDtos.CreatePaymentLinkLineItem lineItem : lineItems) {
            ResolvedLineItemRefs refs = new ResolvedLineItemRefs();
            refs.accountId = lineItem == null ? null : lineItem.accountId;
            refs.applicationId = lineItem == null ? null : lineItem.applicationId;

            if (lineItem != null) {
                assignLookupIdByType(refs, tryToId(lineItem.feeAssignmentId));
                assignLookupIdByType(refs, tryToId(lineItem.feeAssignmentLineItemId));
                assignLookupIdByType(refs, tryToId(lineItem.feeInstallmentId));
                assignLookupIdByType(refs, tryToId(lineItem.feeInstallmentLineItemId));
            }

            if (refs.feeAssignmentLineItemId != null && refs.feeAssignmentId == null) {
                feeAssignmentLineItemIdsToQuery.add(refs.feeAssignmentLineItemId);
            }
            if (refs.feeInstallmentLineItemId != null &&
                (refs.feeInstallmentId == null || refs.feeAssignmentLineItemId == null)
            ) {
                feeInstallmentLineItemIdsToQuery.add(refs.feeInstallmentLineItemId);
            }
            if (refs.feeInstallmentId != null && refs.feeAssignmentId == null) {
                feeInstallmentIdsToQuery.add(refs.feeInstallmentId);
            }

            resolved.add(refs);
        }

        Map<Id, Fee_Assignment_Line_Item__c> feeAssignmentLinesById =
            feeAssignmentLineItemIdsToQuery.isEmpty()
                ? new Map<Id, Fee_Assignment_Line_Item__c>()
                : new Map<Id, Fee_Assignment_Line_Item__c>([
                    SELECT Id, Fee_Assignment__c
                    FROM Fee_Assignment_Line_Item__c
                    WHERE Id IN :feeAssignmentLineItemIdsToQuery
                ]);

        Map<Id, Fee_Installment_Line_Item__c> feeInstallmentLinesById =
            feeInstallmentLineItemIdsToQuery.isEmpty()
                ? new Map<Id, Fee_Installment_Line_Item__c>()
                : new Map<Id, Fee_Installment_Line_Item__c>([
                    SELECT Id, Fee_Installment__c, Fee_Assignment_Line_Item__c
                    FROM Fee_Installment_Line_Item__c
                    WHERE Id IN :feeInstallmentLineItemIdsToQuery
                ]);

        Map<Id, Fee_Installment__c> feeInstallmentsById =
            feeInstallmentIdsToQuery.isEmpty()
                ? new Map<Id, Fee_Installment__c>()
                : new Map<Id, Fee_Installment__c>([
                    SELECT Id, Fee_Assignment__c
                    FROM Fee_Installment__c
                    WHERE Id IN :feeInstallmentIdsToQuery
                ]);

        Set<Id> assignmentLineIdsForInstallmentBackfill = new Set<Id>();
        for (ResolvedLineItemRefs refs : resolved) {
            if (refs != null && refs.feeAssignmentLineItemId != null && refs.feeInstallmentId == null) {
                assignmentLineIdsForInstallmentBackfill.add(refs.feeAssignmentLineItemId);
            }
        }
        Map<Id, Fee_Installment_Line_Item__c> firstInstallmentLineByAssignmentLineId = new Map<Id, Fee_Installment_Line_Item__c>();
        if (!assignmentLineIdsForInstallmentBackfill.isEmpty()) {
            for (Fee_Installment_Line_Item__c installmentLine : [
                SELECT Id, Fee_Installment__c, Fee_Assignment_Line_Item__c
                FROM Fee_Installment_Line_Item__c
                WHERE Fee_Assignment_Line_Item__c IN :assignmentLineIdsForInstallmentBackfill
                ORDER BY CreatedDate DESC
            ]) {
                if (!firstInstallmentLineByAssignmentLineId.containsKey(installmentLine.Fee_Assignment_Line_Item__c)) {
                    firstInstallmentLineByAssignmentLineId.put(
                        installmentLine.Fee_Assignment_Line_Item__c,
                        installmentLine
                    );
                }
            }
        }

        Set<Id> pairInstallmentIds = new Set<Id>();
        Set<Id> pairAssignmentLineItemIds = new Set<Id>();
        for (ResolvedLineItemRefs refs : resolved) {
            if (refs == null) {
                continue;
            }

            if (refs.feeAssignmentId == null && refs.feeAssignmentLineItemId != null) {
                Fee_Assignment_Line_Item__c assignmentLine = feeAssignmentLinesById.get(refs.feeAssignmentLineItemId);
                if (assignmentLine != null) {
                    refs.feeAssignmentId = assignmentLine.Fee_Assignment__c;
                }
            }

            if (refs.feeInstallmentLineItemId != null) {
                Fee_Installment_Line_Item__c installmentLine =
                    feeInstallmentLinesById.get(refs.feeInstallmentLineItemId);
                if (installmentLine != null) {
                    if (refs.feeInstallmentId == null) {
                        refs.feeInstallmentId = installmentLine.Fee_Installment__c;
                    }
                    if (refs.feeAssignmentLineItemId == null) {
                        refs.feeAssignmentLineItemId = installmentLine.Fee_Assignment_Line_Item__c;
                    }
                }
            }

            if (refs.feeAssignmentId == null && refs.feeInstallmentId != null) {
                Fee_Installment__c installment = feeInstallmentsById.get(refs.feeInstallmentId);
                if (installment != null) {
                    refs.feeAssignmentId = installment.Fee_Assignment__c;
                }
            }

            if (refs.feeInstallmentId == null && refs.feeAssignmentLineItemId != null) {
                Fee_Installment_Line_Item__c installmentLine =
                    firstInstallmentLineByAssignmentLineId.get(refs.feeAssignmentLineItemId);
                if (installmentLine != null) {
                    refs.feeInstallmentId = installmentLine.Fee_Installment__c;
                    if (refs.feeInstallmentLineItemId == null) {
                        refs.feeInstallmentLineItemId = installmentLine.Id;
                    }
                }
            }

            if (refs.feeInstallmentLineItemId == null &&
                refs.feeInstallmentId != null &&
                refs.feeAssignmentLineItemId != null
            ) {
                pairInstallmentIds.add(refs.feeInstallmentId);
                pairAssignmentLineItemIds.add(refs.feeAssignmentLineItemId);
            }
        }

        Map<String, Id> feeInstallmentLineByPair = new Map<String, Id>();
        if (!pairInstallmentIds.isEmpty() && !pairAssignmentLineItemIds.isEmpty()) {
            for (Fee_Installment_Line_Item__c installmentLine : [
                SELECT Id, Fee_Installment__c, Fee_Assignment_Line_Item__c
                FROM Fee_Installment_Line_Item__c
                WHERE Fee_Installment__c IN :pairInstallmentIds
                    AND Fee_Assignment_Line_Item__c IN :pairAssignmentLineItemIds
            ]) {
                String key = buildInstallmentLinePairKey(
                    installmentLine.Fee_Installment__c,
                    installmentLine.Fee_Assignment_Line_Item__c
                );
                if (!feeInstallmentLineByPair.containsKey(key)) {
                    feeInstallmentLineByPair.put(key, installmentLine.Id);
                }
            }
        }

        for (ResolvedLineItemRefs refs : resolved) {
            if (refs == null) {
                continue;
            }

            if (refs.feeInstallmentLineItemId == null &&
                refs.feeInstallmentId != null &&
                refs.feeAssignmentLineItemId != null
            ) {
                refs.feeInstallmentLineItemId = feeInstallmentLineByPair.get(
                    buildInstallmentLinePairKey(refs.feeInstallmentId, refs.feeAssignmentLineItemId)
                );
            }

            if (refs.feeAssignmentId == null && refs.feeAssignmentLineItemId != null) {
                Fee_Assignment_Line_Item__c assignmentLine = feeAssignmentLinesById.get(refs.feeAssignmentLineItemId);
                if (assignmentLine != null) {
                    refs.feeAssignmentId = assignmentLine.Fee_Assignment__c;
                }
            }
        }

        return resolved;
    }

    private static void assignLookupIdByType(ResolvedLineItemRefs refs, Id candidateId) {
        if (refs == null || candidateId == null) {
            return;
        }

        String objectApiName = candidateId.getSObjectType().getDescribe().getName();
        if (objectApiName == FEE_ASSIGNMENT_OBJECT_API) {
            refs.feeAssignmentId = candidateId;
        } else if (objectApiName == FEE_ASSIGNMENT_LINE_ITEM_OBJECT_API) {
            refs.feeAssignmentLineItemId = candidateId;
        } else if (objectApiName == FEE_INSTALLMENT_OBJECT_API) {
            refs.feeInstallmentId = candidateId;
        } else if (objectApiName == FEE_INSTALLMENT_LINE_ITEM_OBJECT_API) {
            refs.feeInstallmentLineItemId = candidateId;
        }
    }

    private static String buildInstallmentLinePairKey(Id feeInstallmentId, Id feeAssignmentLineItemId) {
        return String.valueOf(feeInstallmentId) + '::' + String.valueOf(feeAssignmentLineItemId);
    }

    private static Id resolveFirstFeeAssignmentId(List<ResolvedLineItemRefs> resolvedLineItems) {
        if (resolvedLineItems == null) {
            return null;
        }

        for (ResolvedLineItemRefs refs : resolvedLineItems) {
            if (refs != null && refs.feeAssignmentId != null) {
                return refs.feeAssignmentId;
            }
        }
        return null;
    }

    private static Id resolveFirstApplicationId(List<ResolvedLineItemRefs> resolvedLineItems) {
        if (resolvedLineItems == null) {
            return null;
        }

        for (ResolvedLineItemRefs refs : resolvedLineItems) {
            if (refs == null || String.isBlank(refs.applicationId)) {
                continue;
            }

            Id applicationId = tryToIdOfType(refs.applicationId, INDIVIDUAL_APPLICATION_OBJECT_API);
            if (applicationId != null) {
                return applicationId;
            }
        }
        return null;
    }

    private static void putFieldValueIfAvailable(SObject targetRecord, String fieldApiName, Object fieldValue) {
        if (targetRecord == null || String.isBlank(fieldApiName) || fieldValue == null) {
            return;
        }

        Map<String, Schema.SObjectField> fieldsByApiName =
            targetRecord.getSObjectType().getDescribe().fields.getMap();
        if (fieldsByApiName.containsKey(fieldApiName)) {
            targetRecord.put(fieldApiName, fieldValue);
        }
    }

    private static void enforceAccess(String relatedRecordId) {
        // Replace with real checks: sharing, ownership, custom logic
        // Example approach:
        // - Query the related record in USER MODE
        // - Ensure it belongs to current portal user
        // NOTE: This is intentionally a placeholder.
        if (String.isBlank(relatedRecordId)) {
            throw new AuraHandledException('Access denied.');
        }
    }

    private class RazorpayCalloutResult {
        public String rawPayload;
        public String linkId;
        public String shortUrl;
        public String status;
    }

    private static RazorpayCalloutResult processCreatePaymentLinkCallout(Map<String, Object> payload) {
        HttpRequest httpReq = new HttpRequest();
        httpReq.setMethod('POST');
        httpReq.setHeader('Content-Type', 'application/json');
        httpReq.setEndpoint('callout:Razorpay_NC/v1/payment_links');
        httpReq.setBody(JSON.serialize(payload));

        Http http = new Http();
        HttpResponse res = http.send(httpReq);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new AuraHandledException('Razorpay link creation failed: ' + extractRazorpayError(res.getBody()));
        }

        Map<String, Object> resp = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        RazorpayCalloutResult result = new RazorpayCalloutResult();
        result.rawPayload = res.getBody();
        result.linkId = (String) resp.get('id');
        result.shortUrl = (String) resp.get('short_url');
        result.status = (String) resp.get('status');
        return result;
    }

    private static String extractRazorpayError(String rawBody) {
        if (String.isBlank(rawBody)) {
            return 'Unknown gateway error.';
        }
        try {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(rawBody);
            Object errorObj = body.get('error');
            if (errorObj instanceOf Map<String, Object>) {
                Map<String, Object> errorMap = (Map<String, Object>) errorObj;
                String description = (String) errorMap.get('description');
                if (!String.isBlank(description)) {
                    return description;
                }
                String message = (String) errorMap.get('message');
                if (!String.isBlank(message)) {
                    return message;
                }
            }
        } catch (Exception ex) {
            // Fall back to truncated payload.
        }
        return rawBody.length() > 240 ? rawBody.substring(0, 240) : rawBody;
    }

    private static Long toMinorUnits(Decimal major) {
        // INR: rupees -> paise
        Decimal paise = major * 100;
        // Ensure no fraction
        paise = paise.setScale(0);
        return Long.valueOf(String.valueOf(paise));
    }

    private static String buildCallbackUrl(String baseUrl, String reference) {
        if (String.isBlank(baseUrl)) return null;
        String trimmed = baseUrl.endsWith('/') ? baseUrl.left(baseUrl.length()-1) : baseUrl;
        // If baseUrl already points to an Apex REST callback, use as-is
        if (trimmed.contains('/services/apexrest/')) return trimmed;
        // Otherwise, default to a portal status page
        return trimmed + '/s/payment-status?ref=' + EncodingUtil.urlEncode(reference, 'UTF-8');
    }

    private static String generateUniquePaymentReference(String sourceReference) {
        String baseReference = String.isBlank(sourceReference) ? 'REF' : sourceReference.trim();
        String candidate = buildReferenceCandidate(baseReference);
        Integer attemptCount = 0;

        while (attemptCount < 5 && paymentReferenceExists(candidate)) {
            candidate = buildReferenceCandidate(baseReference);
            attemptCount += 1;
        }
        return candidate;
    }

    private static String buildReferenceCandidate(String baseReference) {
        String timestampPart = String.valueOf(Datetime.now().getTime());
        Integer randomInt = Math.abs(Crypto.getRandomInteger());
        String randomRaw = String.valueOf(randomInt);
        String randomPart = randomRaw.length() > 6
            ? randomRaw.substring(randomRaw.length() - 6)
            : randomRaw;
        String suffix = '-' + timestampPart + '-' + randomPart;

        Integer maxBaseLength = RAZORPAY_REFERENCE_MAX_LENGTH - suffix.length();
        if (maxBaseLength < 1) {
            maxBaseLength = 1;
        }
        String normalizedBase = baseReference.length() > maxBaseLength
            ? baseReference.substring(0, maxBaseLength)
            : baseReference;
        String candidate = normalizedBase + suffix;
        return candidate.length() > RAZORPAY_REFERENCE_MAX_LENGTH
            ? candidate.substring(0, RAZORPAY_REFERENCE_MAX_LENGTH)
            : candidate;
    }

    private static Boolean paymentReferenceExists(String referenceValue) {
        return [
            SELECT COUNT()
            FROM Payment_Transaction__c
            WHERE External_Reference__c = :referenceValue
        ] > 0;
    }

    private static String buildTransactionRemarks(
        String sourceReference,
        String paymentReference,
        String successRedirectUrl
    ) {
        List<String> remarkParts = new List<String>();
        if (!String.isBlank(sourceReference) && sourceReference != paymentReference) {
            remarkParts.add('SourceReference=' + sourceReference);
        }
        if (!String.isBlank(successRedirectUrl)) {
            remarkParts.add(
                'SuccessRedirectUrl=' + EncodingUtil.urlEncode(successRedirectUrl, 'UTF-8')
            );
        }
        if (remarkParts.isEmpty()) {
            return null;
        }

        String remarkValue = String.join(remarkParts, ';');
        return remarkValue.length() > 255 ? remarkValue.substring(0, 255) : remarkValue;
    }

    private static String normalizeRedirectUrl(String rawUrl) {
        if (String.isBlank(rawUrl)) {
            return null;
        }
        String trimmed = rawUrl.trim();
        if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) {
            return trimmed;
        }
        return null;
    }

    private static Decimal resolveTransactionLineAmount(
        RazorpayDtos.CreatePaymentLinkLineItem lineItem,
        Decimal fallbackAmount
    ) {
        if (lineItem != null && lineItem.amount != null && lineItem.amount > 0) {
            return lineItem.amount;
        }
        return fallbackAmount;
    }

    private static Id tryToId(String value) {
        if (String.isBlank(value)) return null;
        if (value.length() != 15 && value.length() != 18) return null;
        try {
            return (Id) value;
        } catch (Exception e) {
            return null;
        }
    }

    private static Id tryToIdOfType(String value, String expectedObjectApiName) {
        Id candidateId = tryToId(value);
        if (candidateId == null || String.isBlank(expectedObjectApiName)) {
            return null;
        }

        String actualObjectApiName = candidateId.getSObjectType().getDescribe().getName();
        return actualObjectApiName == expectedObjectApiName ? candidateId : null;
    }
}