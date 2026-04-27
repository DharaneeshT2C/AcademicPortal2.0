/**
 * ************************************************************************************************
 * @className  KenCrudFlsHelper
 *
 * @description
 *  Centralised CRUD / FLS guard checks used by services performing DML in the
 *  Student Portal backend. Complements `WITH USER_MODE` on SOQL reads by making
 *  DML permissions explicit and throwing `AuraHandledException` on access denial.
 *
 * @author      Student Portal Backend
 * @createdOn   2026
 * ************************************************************************************************
 */
public with sharing class KenCrudFlsHelper {

    public static void assertReadable(Schema.SObjectType t) {
        if (!t.getDescribe().isAccessible()) {
            throw new AuraHandledException('You do not have read access to ' + t.getDescribe().getName());
        }
    }

    public static void assertCreateable(Schema.SObjectType t) {
        if (!t.getDescribe().isCreateable()) {
            throw new AuraHandledException('You do not have create access to ' + t.getDescribe().getName());
        }
    }

    public static void assertUpdateable(Schema.SObjectType t) {
        if (!t.getDescribe().isUpdateable()) {
            throw new AuraHandledException('You do not have edit access to ' + t.getDescribe().getName());
        }
    }

    public static void assertDeletable(Schema.SObjectType t) {
        if (!t.getDescribe().isDeletable()) {
            throw new AuraHandledException('You do not have delete access to ' + t.getDescribe().getName());
        }
    }

    public static void assertFieldUpdateable(Schema.SObjectType t, String fieldApi) {
        Schema.SObjectField f = t.getDescribe().fields.getMap().get(fieldApi);
        if (f == null || !f.getDescribe().isUpdateable()) {
            throw new AuraHandledException('You do not have edit access to ' + t.getDescribe().getName() + '.' + fieldApi);
        }
    }
}