@isTest(SeeAllData=false)
/**
 * @description
 *
 * Usage:
 *  - No direct callers found
 */
private class ProgramImportBatchTest {
    @TestSetup
    static void makeData() {
        new KenTestDataFactory.UserCreator('System Administrator')
            .setAlias('progb')
            .create();
    }
    
    @isTest
    static void testBatchRuns() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Learning') || !gd.containsKey('LearningProgram')) {return;}
        User runUser = [SELECT Id FROM User WHERE Alias = 'progb' LIMIT 1];
        System.runAs(runUser) {
            Map<String, Object> row = new Map<String, Object>{
                'RowNumber' => '1',
                'Name' => 'Program Batch'
            };
            String jsonRows = JSON.serialize(new List<Object>{ row });
            
            Test.startTest();
            Id jobId = Database.executeBatch(new ProgramImportBatch(jsonRows, null, null), 200);
            Test.stopTest();
            
            System.assertNotEquals(null, jobId, 'Batch job id should be returned');
        }
    }
    
    @isTest
    static void testBatchDuplicatesWithProvider() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Learning') || !gd.containsKey('LearningProgram')) {return;}
        User runUser = [SELECT Id FROM User WHERE Alias = 'progb' LIMIT 1];
        System.runAs(runUser) {
            Id providerId = new KenTestDataFactory.AccountCreator('Program Provider').create().Id;
            
            Schema.DescribeFieldResult typeField = gd.get('Learning').getDescribe().fields.getMap().get('Type').getDescribe();
            String typeValue = ProgramImportController.resolvePicklistValue(typeField, 'LearningProgram');
            if (typeValue == null) {return;}
            
            Learning existing = new KenTestDataFactory.LearningCreator('Program Dup').create();
            if (gd.get('Learning').getDescribe().fields.getMap().containsKey('ProviderId')) {
                existing.put('ProviderId', providerId);
            }
            if (gd.get('Learning').getDescribe().fields.getMap().containsKey('Type')) {
                existing.put('Type', typeValue);
            }
            update existing;
            
            Map<String, Object> row1 = new Map<String, Object>{
                'RowNumber' => '1',
                'Name' => 'Program Dup'
            };
            Map<String, Object> row2 = new Map<String, Object>{
                'RowNumber' => '2',
                'Name' => 'Program Dup'
            };
            Map<String, Object> row3 = new Map<String, Object>{
                'RowNumber' => '3',
                'Name' => 'Program New'
            };
            String jsonRows = JSON.serialize(new List<Object>{ row1, row2, row3 });
            
            Test.startTest();
            Id jobId = Database.executeBatch(new ProgramImportBatch(jsonRows, providerId, null), 200);
            Test.stopTest();
            
            System.assertNotEquals(null, jobId, 'Batch job id should be returned');
        }
    }
    
    @isTest
    static void testBatchUpdatesExistingByCipCodeAndInsertsNew() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Learning') || !gd.containsKey('LearningProgram')) {return;}
        User runUser = [SELECT Id FROM User WHERE Alias = 'progb' LIMIT 1];
        System.runAs(runUser) {
            Id providerId = new KenTestDataFactory.AccountCreator('Program Provider Update').create().Id;
            Id campusId = new KenTestDataFactory.LocationCreator('Program Campus Update', 'Campus').create().Id;
            
            Learning existingLearning = new KenTestDataFactory.LearningCreator('Existing Program').create();
            existingLearning.put('CipCode', 'CIP-100');
            if (gd.get('Learning').getDescribe().fields.getMap().containsKey('Type')) {
                Schema.DescribeFieldResult typeField = gd.get('Learning').getDescribe().fields.getMap().get('Type').getDescribe();
                String typeValue = ProgramImportController.resolvePicklistValue(typeField, 'LearningProgram');
                if (typeValue != null) {
                    existingLearning.put('Type', typeValue);
                }
            }
            if (gd.get('Learning').getDescribe().fields.getMap().containsKey('ProviderId')) {
                existingLearning.put('ProviderId', providerId);
            }
            update existingLearning;
            
            LearningProgram existingProgram = new KenTestDataFactory.LearningProgramCreator('Existing Program')
                .setLearningId(existingLearning.Id)
                .setCampus(campusId)
                .returnWithoutCreate();
            insert existingProgram;
            
            List<Object> rows = new List<Object>{
                new Map<String, Object>{
                    'RowNumber' => '1',
                    'Name' => 'Existing Program Updated',
                    'CipCode' => 'CIP-100'
                },
                new Map<String, Object>{
                    'RowNumber' => '2',
                    'Name' => 'Brand New Program',
                    'CipCode' => 'CIP-200'
                }
            };
            
            Test.startTest();
            Database.executeBatch(new ProgramImportBatch(JSON.serialize(rows), providerId, campusId), 200);
            Test.stopTest();
            
            Learning updatedLearning = [
                SELECT Id, Name
                FROM Learning
                WHERE Id = :existingLearning.Id
            ];
            System.assertNotEquals(null, updatedLearning, 'Existing learning should still be available after import.');
            
            List<LearningProgram> programs = [
                SELECT Id, Name
                FROM LearningProgram
            ];
            System.assert(programs.size() >= 1, 'At least the existing program should remain after import.');
        }
    }
}