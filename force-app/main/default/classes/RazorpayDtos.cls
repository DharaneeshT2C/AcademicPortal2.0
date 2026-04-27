public without sharing class RazorpayDtos {
    public class CreatePaymentLinkRequest {
        @AuraEnabled public Decimal amount;          // rupees (or major unit)
        @AuraEnabled public String currencyType;     // INR
        @AuraEnabled public String description;      // Invoice #...
        @AuraEnabled public String reference;        // your ref
        @AuraEnabled public String relatedRecordId;  // invoice/opportunity id etc
        @AuraEnabled public String successRedirectUrl;
        @AuraEnabled public String accountId;
        @AuraEnabled public String customerName;
        @AuraEnabled public String customerEmail;
        @AuraEnabled public String customerPhone;
        @AuraEnabled public List<CreatePaymentLinkLineItem> lineItems;
    }

    public class CreatePaymentLinkLineItem {
        @AuraEnabled public String feeAssignmentId;
        @AuraEnabled public String feeAssignmentLineItemId;
        @AuraEnabled public String feeInstallmentId;
        @AuraEnabled public String feeInstallmentLineItemId;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String accountId;
        @AuraEnabled public String applicationId;
    }

    public class CreatePaymentLinkResponse {
        @AuraEnabled public Id paymentRecordId;
        @AuraEnabled public String shortUrl;
        @AuraEnabled public String razorpayPaymentLinkId;
        @AuraEnabled public String status;
    }
}