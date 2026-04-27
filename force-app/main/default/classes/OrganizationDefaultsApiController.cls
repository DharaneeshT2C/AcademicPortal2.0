/**
 * ************************************************************************************************
 * @className  OrganizationDefaultsApiController
 *
 * @description
 *  Provides organization-level branding defaults to client components.
 *
 *  Responsibilities:
 *  - Read org default settings from Organization_Default_Parameters__c
 *  - Return fallback branding values when settings are missing
 *  - Normalize and validate hex color strings
 *
 * @author      Sureka A R K
 * @createdOn   Feb 17, 2026
 *
 * @history
 * ------------------------------------------------------------------------------------------------
 * Version   Date           Author          Description
 * 1.0       Feb 17, 2026   Sureka A R K    Added ApexDocs
 * ************************************************************************************************
 */
public with sharing class OrganizationDefaultsApiController {
    /**
     * @description Response DTO for organization default branding values.
     */
    @TestVisible
    static Boolean forceExceptionForTesting = false;
    
    public class OrganizationDefaultsResponse {
        @AuraEnabled public String primary;
        @AuraEnabled public String secondary;
        @AuraEnabled public String primaryForSf;
        @AuraEnabled public String secondaryForSf;
        @AuraEnabled public String instituteName;
        @AuraEnabled public String instituteAlias;
    }
    
    /**
     * @description Returns organization branding defaults for UI consumption.
     * @return DTO containing primary/secondary colors and institute labels.
     */
    @AuraEnabled(cacheable=true)
    public static OrganizationDefaultsResponse getOrganizationDefaults() {
        if (forceExceptionForTesting) {
            throw new IllegalArgumentException('Test exception for catch block coverage');
        }
        
        final String defaultPrimary = KenConstantController.DEFAULT_PRIMARY_COLOR;
        final String defaultSecondary = KenConstantController.DEFAULT_SECONDARY_COLOR;
        
        Organization_Default_Parameters__c setting = Organization_Default_Parameters__c.getOrgDefaults();
        OrganizationDefaultsResponse response = new OrganizationDefaultsResponse();
        
        response.primary = sanitizeHexColor(
            setting == null ? null : setting.Primary_Color__c,
        defaultPrimary
            );
        response.secondary = sanitizeHexColor(
            setting == null ? null : setting.Secondary_Color__c,
        defaultSecondary
            );
        response.primaryForSf = sanitizeHexColor(
            setting == null ? null : setting.Primary_Color_For_SF__c,
        response.primary
            );
        response.secondaryForSf = sanitizeHexColor(
            setting == null ? null : setting.Secondary_Color_For_SF__c,
        response.secondary
            );
        response.instituteName = setting == null ? null : setting.Institute_Name__c;
        response.instituteAlias = setting == null ? null : setting.Institute_Alias__c;
        return response;
    }
    
    /**
     * @description Validates and normalizes a hex color value.
     * @param inputColor Input color value (with or without # prefix).
     * @param fallbackColor Fallback color when input is blank/invalid.
     * @return Validated hex color in #RRGGBB format, or fallback value.
     */
    private static String sanitizeHexColor(String inputColor, String fallbackColor) {
        if (String.isBlank(inputColor)) {
            return fallbackColor;
        }
        String value = inputColor.trim();
        if (!value.startsWith('#')) {
            value = '#' + value;
        }
        if (Pattern.matches('^#([0-9a-fA-F]{6})$', value)) {
                    return value;
                }
                return fallbackColor;
            }
        }