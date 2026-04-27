/**
 * Portal login handler — wraps Site.login() so the custom c:login LWC can
 * authenticate users without going through the default community_login:loginForm.
 */
public without sharing class KenPortalLoginController {

    @AuraEnabled
    public static String login(String username, String password, String startUrl) {
        if (String.isBlank(username) || String.isBlank(password)) {
            throw new AuraHandledException('Please enter your username and password.');
        }
        String target = String.isBlank(startUrl) ? '/' : startUrl;
        try {
            ApexPages.PageReference pageRef = Site.login(username, password, target);
            return pageRef != null ? pageRef.getUrl() : target;
        } catch (Exception e) {
            throw new AuraHandledException('Invalid username or password. Please try again.');
        }
    }
}