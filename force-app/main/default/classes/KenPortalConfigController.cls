public with sharing class KenPortalConfigController {

    public class portalconfigs {
        @AuraEnabled public String primaryColor;
        @AuraEnabled public String secondaryColor;
        @AuraEnabled public String tertiaryColor;
        @AuraEnabled public String institutionName;
        @AuraEnabled public String institutionAlias;

        public portalconfigs(String pri, String sec, String ter, String Name, String Alias) {
            primaryColor = pri;
            secondaryColor = sec;
            tertiaryColor = ter;
			institutionName = Name;
			institutionAlias = Alias;
        }
    }

    @AuraEnabled(cacheable=true)
    public static portalconfigs getPortalConfigs() {
        /*
        // MISSING SCHEMA: Alumni_Org_Parameters__c
        Alumni_Org_Parameters__c cs = Alumni_Org_Parameters__c.getOrgDefaults();

        String primary = cs.Portal_Primary_colour__c;
        String secondary = cs.Portal_Secondary_colour__c;
        String tertiary = cs.Portal_Tertiary_colour__c;
		String institutionName = (cs != null && String.isNotBlank(cs.Institution_Name__c)) ? cs.Institution_Name__c : 'Kenverse';
		String institutionAlias = (cs != null && String.isNotBlank(cs.Institution_Alias__c)) ? cs.Institution_Alias__c : 'Ken42';
        */
        
        String primary = null;
        String secondary = null;
        String tertiary = null;
        String institutionName = 'Kenverse';
        String institutionAlias = 'Ken42';

        return new portalconfigs(primary, secondary, tertiary, institutionName, institutionAlias);
    }
}