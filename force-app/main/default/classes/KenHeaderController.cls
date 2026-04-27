public without sharing class KenHeaderController {
    @TestVisible private static Boolean TEST_MODE = false;

    @AuraEnabled(cacheable=true)
    public static List<ConnectApi.NavigationMenuItem> getNavigationMenuItems(
        String navigationLinkSetMasterLabel,
        String publishStatus,
        Boolean addHomeMenuItem,
        Boolean includeImageUrl
    ) {
        if (TEST_MODE) {
            ConnectApi.NavigationMenuItem mockItem = new ConnectApi.NavigationMenuItem();
            mockItem.label = 'Home';
            mockItem.actionValue = '/alumni/home';
            mockItem.actionType = ConnectApi.NavigationMenuItemActionType.InternalLink;
            return new List<ConnectApi.NavigationMenuItem>{ mockItem };
        }

        navigationLinkSetMasterLabel = String.isNotBlank(navigationLinkSetMasterLabel)
            ? navigationLinkSetMasterLabel
            : 'Default Navigation';

        ConnectApi.PublishStatus publishStatusEnum =
            publishStatus.equalsIgnoreCase(ConnectApi.PublishStatus.Draft.name())
                ? ConnectApi.PublishStatus.Draft
                : ConnectApi.PublishStatus.Live;

        List<ConnectApi.NavigationMenuItemType> menuItemsToSkip = new List<ConnectApi.NavigationMenuItemType>{
            ConnectApi.NavigationMenuItemType.Event,
            ConnectApi.NavigationMenuItemType.SystemLink
        };

        String networkId = Network.getNetworkId();
        String navigationLinkSetDeveloperName = getNavigationLinkSetDeveloperName(navigationLinkSetMasterLabel);

        if (String.isBlank(navigationLinkSetDeveloperName)) {
            navigationLinkSetDeveloperName = 'Default_Navigation';
        }

        ConnectApi.NavigationMenuItemCollection menu = ConnectApi.NavigationMenu.getCommunityNavigationMenu(
            networkId,
            null,
            navigationLinkSetDeveloperName,
            publishStatusEnum,
            includeImageUrl,
            addHomeMenuItem,
            menuItemsToSkip
        );

        return menu.menuItems;
    }

    @TestVisible
    private static String getNavigationLinkSetDeveloperName(String navigationLinkSetMasterLabel) {
        String networkId = Network.getNetworkId();
        if (!Schema.sObjectType.NavigationLinkSet.isAccessible()) {
            throw new AuraHandledException('You do not have permission to view navigation link sets.');
        }

        List<NavigationLinkSet> navigationLinkSets = [
            SELECT DeveloperName
            FROM NavigationLinkSet
            WHERE NetworkId = :networkId
              AND MasterLabel = :navigationLinkSetMasterLabel
            LIMIT 1
        ];

        return navigationLinkSets.isEmpty()
            ? null
            : navigationLinkSets[0].DeveloperName;
    }
}