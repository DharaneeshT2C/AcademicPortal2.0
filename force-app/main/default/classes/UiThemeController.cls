public with sharing class UiThemeController {
    public class ThemeColors {
        @AuraEnabled public String primary;
        @AuraEnabled public String secondary;
    }
    
    @AuraEnabled(cacheable=true)
    public static ThemeColors getThemeColors() {
        ThemeColors out = new ThemeColors();
        out.primary = null;
        out.secondary = null;
        
        // Support both settings objects to avoid breaking existing LWCs.
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        String settingObject;
        if (gd.containsKey('Organization_Default_Parameters__c')) {
            settingObject = 'Organization_Default_Parameters__c';
        }  else {
            return out;
        }
        
        String soql =
            'SELECT Primary_Color_For_SF__c, Secondary_Color_For_SF__c ' +
            'FROM ' + settingObject + ' ' +
            'ORDER BY CreatedDate DESC LIMIT 1';
        List<SObject> rows = Database.query(soql);
        if (rows.isEmpty()) {
            return out;
        }
        
        String primaryRaw = (String) rows[0].get('Primary_Color_For_SF__c');
        String secondaryRaw = (String) rows[0].get('Secondary_Color_For_SF__c');
        out.primary = sanitizeHexColor(primaryRaw);
        out.secondary = sanitizeHexColor(secondaryRaw);
        return out;
    }
    
    private static String sanitizeHexColor(String inputColor) {
        if (String.isBlank(inputColor)) {
            return null;
        }
        String value = inputColor.trim();
        if (!value.startsWith('#')) {
            value = '#' + value;
        }
        if (Pattern.matches('^#([0-9a-fA-F]{6})$', value)) {
                    return value;
                }
                return null;
            }
        }