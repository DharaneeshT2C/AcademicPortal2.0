public with sharing class ExamManagementThemeController {
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getExamManagementTheme() {
        ExamManagementTheme__c theme = fetchTheme();
        
        String primaryColor     = fallback(theme != null ? theme.Primary_Color__c : null,              '#3b6fd4');
        String secondaryColor   = fallback(theme != null ? theme.Secondary_Color__c : null,            '#eef2fb');
        String textColor        = fallback(theme != null ? theme.Text_Color__c : null,                 '#111827');
        String textSecondaryColor = fallback(theme != null ? theme.Text_Secondary_Color__c : null,     '#6b7280');
        String surfaceColor     = fallback(theme != null ? theme.Surface_Color__c : null,              '#ffffff');
        String pageColor        = fallback(theme != null ? theme.Page_Background_Color__c : null,      '#f0f2f5');
        String borderColor      = fallback(theme != null ? theme.Border_Color__c : null,               '#e0e4ea');
        String dangerColor      = fallback(theme != null ? theme.Danger_Color__c : null,               '#da3923');
        
        String buttonColor      = fallback(theme != null ? theme.Button_Color__c : null,               primaryColor);
        String buttonTextColor  = fallback(theme != null ? theme.Button_Text_Color__c : null,          '#ffffff');
        String buttonHoverColor = fallback(theme != null ? theme.Button_Hover_Color__c : null,         '#2d5ab5');
        
        Map<String, String> result = new Map<String, String>();
        result.put('primaryColor',    primaryColor);
        result.put('primaryDark',     '#2d5ab5');
        result.put('primaryLight',    primaryColor);
        result.put('secondaryColor',  secondaryColor);
        result.put('secondaryDark',   '#dde6f9');
        result.put('accentColor',     primaryColor);
        result.put('accentDark',      secondaryColor);
        result.put('textPrimary',     textColor);
        result.put('textSecondary',   textSecondaryColor);
        result.put('textMuted',       textSecondaryColor);
        result.put('textSubtle',      textSecondaryColor);
        result.put('surfaceWhite',    surfaceColor);
        result.put('surfaceSoft',     '#f9fafb');
        result.put('surfacePage',     pageColor);
        result.put('surfaceCard',     surfaceColor);
        result.put('borderDefault',   borderColor);
        result.put('borderSubtle',    borderColor);
        result.put('borderAccent',    borderColor);
        result.put('primaryAlpha10',  hexToRgba(primaryColor, 0.10));
        result.put('primaryAlpha14',  hexToRgba(primaryColor, 0.14));
        result.put('primaryAlpha18',  hexToRgba(primaryColor, 0.18));
        result.put('primaryAlpha28',  hexToRgba(primaryColor, 0.28));
        result.put('primaryAlpha36',  hexToRgba(primaryColor, 0.36));
        result.put('accentAlpha10',   hexToRgba(secondaryColor, 0.10));
        result.put('accentAlpha14',   hexToRgba(secondaryColor, 0.14));
        result.put('shadowXs',        '0 1px 3px rgba(15,23,42,0.06)');
        result.put('shadowSm',        '0 2px 8px rgba(15,23,42,0.08)');
        result.put('shadowMd',        '0 6px 16px rgba(15,23,42,0.10)');
        result.put('shadowLg',        '0 12px 32px rgba(15,23,42,0.12)');
        result.put('shadowHover',     '0 8px 24px rgba(15,23,42,0.12)');
        result.put('dangerColor',     dangerColor);
        result.put('successColor',    '#166738');
        result.put('warningColor',    '#92400e');
        
        result.put('buttonPrimaryBg',   buttonColor);
        result.put('buttonPrimaryText', buttonTextColor);
        result.put('buttonHoverBg',     buttonHoverColor);
        
        result.put('hoverBg',       hexToRgba(primaryColor, 0.06));
        result.put('hoverAccentBg', hexToRgba(primaryColor, 0.10));
        result.put('hoverText',     primaryColor);
        
        return result;
    }
    
    private static ExamManagementTheme__c fetchTheme() {
        return ExamManagementTheme__c.getOrgDefaults();
    }
    
    private static String fallback(String value, String defaultValue) {
        return String.isBlank(value) ? defaultValue : value;
    }
    
    private static String hexToRgba(String hexColor, Decimal alpha) {
        if (String.isBlank(hexColor)) {
            return 'rgba(0,0,0,' + String.valueOf(alpha) + ')';
        }
        
        String raw = hexColor.trim().replace('#', '');
        if (raw.length() == 3) {
            raw = raw.substring(0, 1) + raw.substring(0, 1)
                + raw.substring(1, 2) + raw.substring(1, 2)
                + raw.substring(2, 3) + raw.substring(2, 3);
        }
        if (raw.length() != 6) {
            return 'rgba(0,0,0,' + String.valueOf(alpha) + ')';
        }
        
        Integer r = parseHexByte(raw.substring(0, 2));
        Integer g = parseHexByte(raw.substring(2, 4));
        Integer b = parseHexByte(raw.substring(4, 6));
        return 'rgba(' + r + ',' + g + ',' + b + ',' + String.valueOf(alpha) + ')';
    }
    
    private static Integer parseHexByte(String hexByte) {
        if (String.isBlank(hexByte) || hexByte.length() != 2) {
            return 0;
        }
        return (hexDigitValue(hexByte.substring(0, 1)) * 16) + hexDigitValue(hexByte.substring(1, 2));
    }
    
    private static Integer hexDigitValue(String c) {
        String value = String.isBlank(c) ? '' : c.toLowerCase();
        if (value == '0') return 0;
        if (value == '1') return 1;
        if (value == '2') return 2;
        if (value == '3') return 3;
        if (value == '4') return 4;
        if (value == '5') return 5;
        if (value == '6') return 6;
        if (value == '7') return 7;
        if (value == '8') return 8;
        if (value == '9') return 9;
        if (value == 'a') return 10;
        if (value == 'b') return 11;
        if (value == 'c') return 12;
        if (value == 'd') return 13;
        if (value == 'e') return 14;
        if (value == 'f') return 15;
        return 0;
    }
}