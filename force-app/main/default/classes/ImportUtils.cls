/**
 * ************************************************************************************************
 * @className  ImportUtils
 *
 * @description
 *  Utility helpers used by import controllers and batch classes.
 *
 *  Responsibilities:
 *  - Provide lookup data for import UI filters (accounts/campuses)
 *  - Expose async batch status for running import jobs
 *  - Convert raw string/object input values to typed field values
 *  - Parse date strings in import-friendly formats
 *
 * @author      Sureka A R K
 * @createdOn   Feb 02, 2026
 *
 * @history
 * ------------------------------------------------------------------------------------------------
 * Version   Date           Author          Description
 * 1.0       Feb 02, 2026   Sureka A R K    Added ApexDocs and constant usage
 * ************************************************************************************************
 */
@suppressWarnings('PMD.StdCyclomaticComplexity,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssMethodCount,PMD.EagerlyLoadedDescribeSObjectResult')
public with sharing class ImportUtils {
    /**
     * @description DTO for AsyncApexJob batch status.
     */
    public class BatchStatusInfo {
        @AuraEnabled public String status;
        @AuraEnabled public Integer processed;
        @AuraEnabled public Integer total;
        @AuraEnabled public Integer errors;
    }
    
    /**
     * @description DTO for import execution counts and error collection.
     */
    public class ImportResult {
        @AuraEnabled public Integer createdLearnings = 0;
        @AuraEnabled public Integer createdCourses = 0;
        @AuraEnabled public Integer createdPrograms = 0;
        @AuraEnabled public Integer errorCount = 0;
        @AuraEnabled public List<String> errors = new List<String>();
    }
    
    /**
     * @description Generic id-name DTO used by combobox/list endpoints.
     */
    public class IdName {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        /**
         * @description Creates an id-name row DTO.
         * @param id Record Id.
         * @param name Record display name.
         */
        public IdName(Id id, String name) {
            this.id = id;
            this.name = name;
        }
    }
    
    /**
     * @description Returns university accounts.
     * @return Id-name rows for University record type.
     */
    @AuraEnabled(cacheable=true)
    public static List<IdName> getUniversities() {
        return getAccountsByRecordType(KenConstantController.RECORDTYPE_ACCOUNT_UNIVERSITY, null);
    }
    
    /**
     * @description Returns institute accounts under a university.
     * @param universityId Parent university account id.
     * @return Id-name rows for Institute record type.
     */
    @AuraEnabled(cacheable=true)
    public static List<IdName> getInstitutes(Id universityId) {
        return getAccountsByRecordType(KenConstantController.RECORDTYPE_ACCOUNT_INSTITUTE, universityId);
    }
    
    /**
     * @description Returns department accounts under an institute.
     * @param instituteId Parent institute account id.
     * @return Id-name rows for Department record type.
     */
    @AuraEnabled(cacheable=true)
    public static List<IdName> getDepartments(Id instituteId) {
        return getAccountsByRecordType(KenConstantController.RECORDTYPE_ACCOUNT_DEPARTMENT, instituteId);
    }
    
    /**
     * @description Returns all departments.
     * @return Id-name rows for Department record type.
     */
    @AuraEnabled(cacheable=true)
    public static List<IdName> getAllDepartments() {
        return getAccountsByRecordType(KenConstantController.RECORDTYPE_ACCOUNT_DEPARTMENT, null);
    }
    
    /**
     * @description Returns all non-person accounts.
     * @return Id-name rows for Account records.
     */
    @AuraEnabled(cacheable=true)
    public static List<IdName> getAllAccounts() {
        if (!Account.SObjectType.getDescribe().isAccessible()) {
            throw new AuraHandledException('Read access is required for Account.');
        }
        List<IdName> out = new List<IdName>();
        for (Account a : [
            SELECT Id, Name
            FROM Account
            WHERE IsPersonAccount != true
            WITH USER_MODE
            ORDER BY Name
        ]) {
            out.add(new IdName(a.Id, a.Name));
        }
        return out;
    }
    
    /**
     * @description Returns campus location records.
     * @return Id-name rows for Location records where LocationType = Campus.
     */
    @AuraEnabled(cacheable=true)
    public static List<IdName> getCampuses() {
        List<IdName> out = new List<IdName>();
        for (SObject loc : Database.query(
            'SELECT Id, Name FROM Location WHERE LocationType = \'Campus\' ORDER BY Name'
        )) {
            out.add(new IdName((Id)loc.get('Id'), (String)loc.get('Name')));
        }
        return out;
    }
    
    /**
     * @description Returns async batch status details for a job.
     * @param jobId AsyncApexJob id.
     * @return Batch status DTO or null when job id is null.
     */
    @AuraEnabled
    public static BatchStatusInfo getBatchStatus(Id jobId) {
        if (jobId == null) {return null;}
        if (!AsyncApexJob.SObjectType.getDescribe().isAccessible()) {
            throw new AuraHandledException('Read access is required for AsyncApexJob.');
        }
        AsyncApexJob job = [
            SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
            WITH USER_MODE
            LIMIT 1
        ];
        BatchStatusInfo info = new BatchStatusInfo();
        info.status = job.Status;
        info.processed = Integer.valueOf(job.JobItemsProcessed);
        info.total = Integer.valueOf(job.TotalJobItems);
        info.errors = Integer.valueOf(job.NumberOfErrors);
        return info;
    }
    
    /**
     * @description Queries account rows by record type developer name and optional parent.
     * @param recordTypeDevName Account RecordType developer name.
     * @param parentId Optional parent account id.
     * @return Id-name rows that match the filter.
     */
    private static List<IdName> getAccountsByRecordType(String recordTypeDevName, Id parentId) {
        if (String.isBlank(recordTypeDevName)) {return new List<IdName>();}
        if (!Account.SObjectType.getDescribe().isAccessible()) {return new List<IdName>();}
        List<IdName> out = new List<IdName>();
        List<Account> accounts;
        if (parentId == null) {
            accounts = [
                SELECT Id, Name
                FROM Account
                WHERE RecordType.DeveloperName = :recordTypeDevName
                WITH USER_MODE
                ORDER BY Name
            ];
        } else {
            accounts = [
                SELECT Id, Name
                FROM Account
                WHERE RecordType.DeveloperName = :recordTypeDevName
                AND ParentId = :parentId
                WITH USER_MODE
                ORDER BY Name
            ];
        }
        for (Account a : accounts) {
            out.add(new IdName(a.Id, a.Name));
        }
        return out;
    }
    
    /**
     * @description Converts a raw import value to the Apex type expected by target field describe.
     * @param raw Raw input value.
     * @param d Target field describe result.
     * @return Converted value in appropriate Apex type.
     */
    public static Object convertValue(Object raw, Schema.DescribeFieldResult d) {
        if (raw == null) {return null;}
        Schema.DisplayType dt = d.getType();
        try {
            if (dt == Schema.DisplayType.DATE) {
                if (raw instanceof String) {
                    String s = ((String)raw).trim();
                    return parseDateOrThrow(s);
                }
                if (raw instanceof Date) {return raw;}
            } else if (dt == Schema.DisplayType.DATETIME) {
                if (raw instanceof String) {
                    String s = ((String)raw).trim();
                    return parseDatetimeFromString(s);
                }
                if (raw instanceof Datetime) {return raw;}
            } else if (dt == Schema.DisplayType.CURRENCY || dt == Schema.DisplayType.DOUBLE || dt == Schema.DisplayType.PERCENT) {
                if (raw instanceof String) {return Decimal.valueOf(((String)raw).trim());}
                if (raw instanceof Decimal) {return raw;}
                if (raw instanceof Integer) {return Decimal.valueOf(((Integer)raw));}
                if (raw instanceof Double) {return Decimal.valueOf(String.valueOf(raw));}
            } else if (dt == Schema.DisplayType.INTEGER || dt == Schema.DisplayType.LONG) {
                if (raw instanceof String) {return Integer.valueOf(((String)raw).trim());}
                if (raw instanceof Integer) {return raw;}
                if (raw instanceof Decimal) {return Integer.valueOf(((Decimal)raw).intValue());}
                if (raw instanceof Double) {return Integer.valueOf(((Double)raw).intValue());}
            } else if (dt == Schema.DisplayType.BOOLEAN) {
                if (raw instanceof String) {
                    String s = ((String)raw).toLowerCase();
                    return s == 'true' || s == '1' || s == 'yes' || s == 'y';
                }
                if (raw instanceof Boolean) {return raw;}
            }
        } catch (Exception e) {
            throw e;
        }
        return String.valueOf(raw);
    }
    
    /**
     * @description Parses flexible date strings (dd/MM/yyyy, dd/MM/yy, yyyy-MM-dd).
     * @param s Raw date string.
     * @return Parsed Date value or null when parsing fails.
     */
    private static Date parseDateString(String s) {
        if (String.isBlank(s)) {return null;}
        try {
            if (!s.contains('/')) {
                return Date.valueOf(s);
            }
            String[] parts = s.split('/');
            if (parts.size() != 3) {return Date.valueOf(s);}
            return parseSlashDate(parts);
        } catch (Exception e) {
            return null;
        }
    }
    
    private static Date parseDateOrThrow(String s) {
        Date parsed = parseDateString(s);
        if (parsed != null) {return parsed;}
        return Date.valueOf(s);
    }
    
    private static Datetime parseDatetimeFromString(String s) {
        try {
            return Datetime.valueOf(s);
        } catch (Exception ex) {
            Date dte = parseDateString(s);
            if (dte == null) {throw ex;}
            return Datetime.newInstance(dte, Time.newInstance(0,0,0,0));
        }
    }
    
    private static Date parseSlashDate(String[] parts) {
        Integer d = Integer.valueOf(parts[0]);
        Integer m = Integer.valueOf(parts[1]);
        Integer y = Integer.valueOf(parts[2]);
        if (parts[2].length() == 2) {
            y += 2000;
        }
        return Date.newInstance(y, m, d);
    }
}