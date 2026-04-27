global class CustomPaymentGatewayProviderAdapter implements commercepayments.PaymentGatewayAdapter {
    private SalesforceAdapter delegateAdapter;

    global CustomPaymentGatewayProviderAdapter() {
        delegateAdapter = new SalesforceAdapter();
    }

    global commercepayments.GatewayResponse processRequest(
        commercepayments.paymentGatewayContext gatewayContext
    ) {
        return delegateAdapter.processRequest(gatewayContext);
    }
}