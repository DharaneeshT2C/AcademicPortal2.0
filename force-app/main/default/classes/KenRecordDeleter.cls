/**
 * @description Utility class for deleting records with proper error handling.
 */
public with sharing class KenRecordDeleter {
    
    /**
     * @description Deletes a record by object name and ID.
     * @param sObjectName API name of the object (e.g., 'AcademicTerm')
     * @param recordId Id of the record to delete
     * @return 'SUCCESS' or 'ERROR:<message>'
     */
    @AuraEnabled
    public static String deleteRecord(String sObjectName, Id recordId) {
        try {
            // Validate object exists and is deletable
            Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(sObjectName);
            if (sobjType == null) {
                return 'ERROR:Invalid object type: ' + sObjectName;
            }
            if (!sobjType.getDescribe().isDeletable()) {
                return 'ERROR:Delete access required for ' + sObjectName;
            }
            
            // ✅ Use dynamic SOQL for FROM clause (cannot use bind variable there)
            String safeObjectName = String.escapeSingleQuotes(sObjectName);
            String query = 'SELECT Id, Name FROM ' + safeObjectName + ' WHERE Id = :recordId LIMIT 1';
            SObject record = Database.query(query);
            
            // Delete the record
            delete record;
            return 'SUCCESS';
            
        } catch (QueryException qe) {
            return 'ERROR:Query failed - ' + qe.getMessage();
        } catch (DmlException de) {
            return 'ERROR:Delete failed - ' + de.getMessage();
        } catch (Exception e) {
            return 'ERROR:' + e.getMessage();
        }
    }
}