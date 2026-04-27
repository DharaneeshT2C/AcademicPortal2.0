/**
 * Razorpay payment gateway integration scaffold.
 *
 * To activate in production:
 *   1. Setup → Named Credentials → New
 *      - Name: Razorpay_Live
 *      - URL: https://api.razorpay.com/v1
 *      - Identity Type: Named Principal
 *      - Auth Protocol: Password Authentication
 *      - Username: <your_key_id>
 *      - Password: <your_key_secret>
 *   2. Setup → Custom Settings → Razorpay Settings → Manage
 *      - Webhook_Secret__c: <your webhook secret>
 *
 * Once configured, KenFeePaymentController.initiatePayment() will use this
 * service to create a real Razorpay order and return the order id. The LWC then
 * opens the Razorpay Checkout widget with that id.
 */
public with sharing class RazorpayService {

    public class RazorpayOrder {
        public String orderId;
        public Decimal amount;
        public String currencyCode;
        public String receipt;
        public String status;
    }

    public class PaymentGatewayException extends Exception {}

    /**
     * Creates a Razorpay order for the given installment.
     * Returns the order id (e.g. "order_FE9SfTfz9V8eVH") to pass to the
     * Razorpay Checkout JS widget on the client.
     */
    public static RazorpayOrder createOrder(Id installmentId, Decimal amount) {
        if (installmentId == null || amount == null || amount <= 0) {
            throw new PaymentGatewayException('Invalid installment or amount.');
        }

        // Razorpay expects amount in paise (smallest currency unit)
        Long paise = (amount * 100).longValue();
        String body = JSON.serialize(new Map<String, Object>{
            'amount'   => paise,
            'currency' => 'INR',
            'receipt'  => 'fi-' + installmentId,
            'notes'    => new Map<String, String>{ 'installment_id' => installmentId }
        });

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Razorpay_Live/orders');  // Named Credential handles auth
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(body);
        req.setTimeout(30000);

        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
                throw new PaymentGatewayException(
                    'Razorpay error ' + res.getStatusCode() + ': ' + res.getBody().left(200)
                );
            }
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            RazorpayOrder o = new RazorpayOrder();
            o.orderId      = (String) parsed.get('id');
            o.amount       = ((Long) parsed.get('amount')) / 100.0;
            o.currencyCode = (String) parsed.get('currency');
            o.receipt      = (String) parsed.get('receipt');
            o.status       = (String) parsed.get('status');
            return o;
        } catch (Exception e) {
            throw new PaymentGatewayException('Razorpay callout failed: ' + e.getMessage());
        }
    }

    /**
     * Verify a Razorpay webhook signature so we don't trust forged success
     * callbacks. Compares HMAC-SHA256 of the raw body against the signature
     * header using the webhook secret stored in Custom Settings.
     */
    public static Boolean verifyWebhook(String rawBody, String signatureHeader, String webhookSecret) {
        if (String.isBlank(rawBody) || String.isBlank(signatureHeader) || String.isBlank(webhookSecret)) return false;
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(rawBody), Blob.valueOf(webhookSecret));
        String expected = EncodingUtil.convertToHex(mac);
        return expected.equalsIgnoreCase(signatureHeader);
    }
}