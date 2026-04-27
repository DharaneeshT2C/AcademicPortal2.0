public without sharing class RazorpayConfig {
    public class Config {
        public String webhookSecret;
        public String callbackBaseUrl;
        public Integer linkExpireMinutes;
        public String defaultCurrency;
        public Boolean enableSms;
        public Boolean enableEmail;
    }

    public static Config get() {
        Config c = new Config();
        c.linkExpireMinutes = 60;
        c.defaultCurrency = 'INR';
        c.enableSms = false;
        c.enableEmail = false;

        if (!Schema.getGlobalDescribe().containsKey('Razorpay_Settings__mdt')) {
            return c;
        }

        List<SObject> settings = Database.query(
            'SELECT Webhook_Secret__c, Callback_Base_Url__c, Link_Expire_Minutes__c, ' +
            'Default_Currency__c, Enable_SMS__c, Enable_Email__c ' +
            'FROM Razorpay_Settings__mdt WHERE DeveloperName = \'Razorpay_Config\' LIMIT 1'
        );
        if (settings.isEmpty()) {
            return c;
        }

        SObject m = settings[0];
        c.webhookSecret = (String) m.get('Webhook_Secret__c');
        c.callbackBaseUrl = (String) m.get('Callback_Base_Url__c');
        Decimal linkExpireMinutes = (Decimal) m.get('Link_Expire_Minutes__c');
        c.linkExpireMinutes = linkExpireMinutes == null ? 60 : Integer.valueOf(linkExpireMinutes);
        String defaultCurrency = (String) m.get('Default_Currency__c');
        c.defaultCurrency = String.isBlank(defaultCurrency) ? 'INR' : defaultCurrency.trim();
        Boolean enableSms = (Boolean) m.get('Enable_SMS__c');
        Boolean enableEmail = (Boolean) m.get('Enable_Email__c');
        c.enableSms = enableSms == null ? false : enableSms;
        c.enableEmail = enableEmail == null ? false : enableEmail;
        return c;
    }
}