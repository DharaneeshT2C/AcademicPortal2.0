@IsTest
private class KenExamCycleTriggerTest {

    private static Integer sequence = 0;

    private static String uniqueText(String prefix) {
        sequence++;
        return prefix + '_' + String.valueOf(System.now().getTime()) + '_' + sequence;
    }

    private static AcademicTerm createAcademicTerm(Datetime startDt, Datetime endDt) {
        AcademicTerm term = new AcademicTerm(
            Name = uniqueText('TERM'),
            StartDate = startDt,
            EndDate = endDt
        );
        insert term;
        return term;
    }

    private static Ken_Exam_Cycle__c createExamCycle(Id termId) {
        Ken_Exam_Cycle__c cycle = new Ken_Exam_Cycle__c(
            Name = uniqueText('CYCLE'),
            Ken_Academic_Term__c = termId
        );
        insert cycle;
        return cycle;
    }

    @IsTest
    static void testHandlerUpdateActiveFlag_AllBranches() {
        Datetime nowDt = System.now();

        AcademicTerm activeTerm = createAcademicTerm(nowDt.addDays(-2), nowDt.addDays(2));
        AcademicTerm inactiveTerm = createAcademicTerm(nowDt.addDays(-12), nowDt.addDays(-7));

        Ken_Exam_Cycle__c activeCycle = createExamCycle(activeTerm.Id);
        Ken_Exam_Cycle__c inactiveCycle = createExamCycle(inactiveTerm.Id);
        Ken_Exam_Cycle__c noTermCycle = createExamCycle(null);

        List<Ken_Exam_Cycle__c> cycles = [
            SELECT Id, Ken_Start_Date__c, Ken_End_Date__c, Ken_Is_Active__c
            FROM Ken_Exam_Cycle__c
            WHERE Id IN :new Set<Id>{ activeCycle.Id, inactiveCycle.Id, noTermCycle.Id }
        ];

        Test.startTest();
        KenExamCycleTriggerHandler.updateActiveFlag(cycles);
        Test.stopTest();

        Map<Id, Ken_Exam_Cycle__c> cycleById = new Map<Id, Ken_Exam_Cycle__c>(cycles);
        System.assertEquals(true, cycleById.get(activeCycle.Id).Ken_Is_Active__c,
            'Cycle should be active when now is within start/end date range.');
        System.assertEquals(false, cycleById.get(inactiveCycle.Id).Ken_Is_Active__c,
            'Cycle should be inactive when now is outside start/end date range.');
        System.assertEquals(false, cycleById.get(noTermCycle.Id).Ken_Is_Active__c,
            'Cycle should be inactive when derived start/end dates are null.');
    }

    @IsTest
    static void testTriggerBeforeUpdate_NoDateChange_DoesNotRecalculate() {
        Datetime nowDt = System.now();
        AcademicTerm activeTerm = createAcademicTerm(nowDt.addDays(-1), nowDt.addDays(1));
        Ken_Exam_Cycle__c cycle = createExamCycle(activeTerm.Id);

        cycle = [
            SELECT Id, Name, Ken_Is_Active__c, Ken_Academic_Term__c
            FROM Ken_Exam_Cycle__c
            WHERE Id = :cycle.Id
        ];

        cycle.Name = uniqueText('CYCLE_UPDATED');
        cycle.Ken_Is_Active__c = true;

        Test.startTest();
        update cycle;
        Test.stopTest();

        Ken_Exam_Cycle__c updatedCycle = [
            SELECT Ken_Is_Active__c
            FROM Ken_Exam_Cycle__c
            WHERE Id = :cycle.Id
        ];

        System.assertEquals(true, updatedCycle.Ken_Is_Active__c,
            'When term dates are unchanged, handler should skip recalculation.');
    }

    @IsTest
    static void testTriggerBeforeUpdate_DateChange_RecalculatesActiveFlag() {
        Datetime nowDt = System.now();
        AcademicTerm activeTerm = createAcademicTerm(nowDt.addDays(-1), nowDt.addDays(1));
        AcademicTerm futureTerm = createAcademicTerm(nowDt.addDays(8), nowDt.addDays(12));
        Ken_Exam_Cycle__c cycle = createExamCycle(activeTerm.Id);

        cycle = [
            SELECT Id, Ken_Academic_Term__c, Ken_Is_Active__c
            FROM Ken_Exam_Cycle__c
            WHERE Id = :cycle.Id
        ];
        cycle.Ken_Academic_Term__c = futureTerm.Id;
        cycle.Ken_Is_Active__c = true;

        Test.startTest();
        update cycle;
        Test.stopTest();

        Ken_Exam_Cycle__c updatedCycle = [
            SELECT Ken_Is_Active__c
            FROM Ken_Exam_Cycle__c
            WHERE Id = :cycle.Id
        ];

        System.assertEquals(false, updatedCycle.Ken_Is_Active__c,
            'When term dates change to a future range, handler should set active to false.');
    }
}