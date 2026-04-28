/**
 * ************************************************************************************************
 * @className  KenCampusLifeController
 *
 * @description
 *  Backs the `my/campusLife` overview page. Returns featured events preview,
 *  hostel/mess/transport shortcuts, and campus-level announcements.
 * ************************************************************************************************
 */
public without sharing class KenCampusLifeController {

    public class ShortcutDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String icon;
        @AuraEnabled public String label;
        @AuraEnabled public String route;
        @AuraEnabled public String meta;
    }

    public class CampusOverviewDTO {
        @AuraEnabled public List<ShortcutDTO> shortcuts;
        @AuraEnabled public List<String>      announcements;
    }

    @AuraEnabled(cacheable=true)
    public static CampusOverviewDTO getCampusOverview() {
        try {
            CampusOverviewDTO o = new CampusOverviewDTO();
            o.shortcuts = new List<ShortcutDTO>{
                shortcut('SC1', 'apartment',  'Hostel',    'hostel-details', 'Room 215, Block B'),
                shortcut('SC2', 'restaurant', 'Mess menu', 'mess-menu',      'Today: South Indian'),
                shortcut('SC3', 'directions_bus', 'Transport', null,         '3 shuttle routes'),
                shortcut('SC4', 'map',       'Campus map','campus-map',      'Interactive view')
            };
            o.announcements = new List<String>{
                'Library extended hours during exam week',
                'Hostel mess feedback survey open till Apr 28'
            };
            return o;
        } catch (Exception e) {
            KenAuraExceptionHelper.throwAuraHandled('KenCampusLifeController.getCampusOverview',
                'Unable to load campus life.', e);
            return null;
        }
    }

    private static ShortcutDTO shortcut(String id, String icon, String label, String route, String meta) {
        ShortcutDTO s = new ShortcutDTO();
        s.id = id; s.icon = icon; s.label = label; s.route = route; s.meta = meta;
        return s;
    }
}