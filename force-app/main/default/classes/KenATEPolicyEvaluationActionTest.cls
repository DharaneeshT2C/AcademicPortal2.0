@IsTest
private class KenATEPolicyEvaluationActionTest {
    @IsTest
    static void evaluatePolicies_requiresEnrollmentId() {
        KenATEPolicyEvaluationAction.Request requestItem =
            new KenATEPolicyEvaluationAction.Request();

        Test.startTest();
        List<KenATEPolicyEvaluationAction.Response> responses =
            KenATEPolicyEvaluationAction.evaluatePolicies(
                new List<KenATEPolicyEvaluationAction.Request>{ requestItem }
            );
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(null, responses[0].eligibility);
        System.assertEquals('Academic Term Enrollment Id is required.', responses[0].message);
    }

    @IsTest
    static void evaluatePolicies_returnsNullWhenNoRulesExist() {
        Account account = new KenTestDataFactory.AccountCreator('ATE Policy Account').create();
        Contact contact = new KenTestDataFactory.ContactCreator().setAccount(account.Id).create();
        AcademicTerm term = new KenTestDataFactory.AcademicTermCreator(2026, '1').create();
        AcademicTermEnrollment ate = new KenTestDataFactory.AcademicTermEnrollmentCreator(
            term.Id,
            contact.Id,
            account.Id
        ).create();

        KenATEPolicyEvaluationAction.Request requestItem =
            new KenATEPolicyEvaluationAction.Request();
        requestItem.academicTermEnrollmentId = ate.Id;

        Test.startTest();
        List<KenATEPolicyEvaluationAction.Response> responses =
            KenATEPolicyEvaluationAction.evaluatePolicies(
                new List<KenATEPolicyEvaluationAction.Request>{ requestItem }
            );
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(null, responses[0].eligibility);
        System.assertEquals(0, responses[0].evaluatedRuleCount);
        System.assertEquals('No related academic term policy rules found.', responses[0].message);
    }

    @IsTest
    static void normalizeEligibilityValue_handlesCommonOutputShapes() {
        System.assertEquals(
            'Eligible',
            KenATEPolicyEvaluationAction.normalizeEligibilityValue('Eligible')
        );
        System.assertEquals(
            'Not Eligible',
            KenATEPolicyEvaluationAction.normalizeEligibilityValue(false)
        );
        System.assertEquals(
            'Eligible',
            KenATEPolicyEvaluationAction.normalizeEligibilityValue(
                new Map<String, Object>{ 'var_EligibilityResult' => 'Eligible' }
            )
        );
        System.assertEquals(
            'Not Eligible',
            KenATEPolicyEvaluationAction.normalizeEligibilityValue(
                new Map<String, Object>{
                    'outputs' => new List<Object>{
                        new Map<String, Object>{
                            'name' => 'var_EligibilityResult',
                            'value' => 'Not Eligible'
                        }
                    }
                }
            )
        );
        System.assertEquals(
            'Eligible',
            KenATEPolicyEvaluationAction.normalizeEligibilityValue(
                new Map<String, Object>{
                    'simulationResults' => new List<Object>{
                        new Map<String, Object>{
                            'datatype' => 'Text',
                            'name' => 'var_EligibilityResult',
                            'value' => 'Eligible'
                        }
                    }
                }
            )
        );
        System.assertEquals(
            'Eligible',
            KenATEPolicyEvaluationAction.normalizeEligibilityValue(
                new Map<String, Object>{
                    'output' => new Map<String, Object>{
                        'calculationResults' => new List<Object>{
                            new Map<String, Object>{
                                'var_EligibilityResult' => 'Eligible'
                            }
                        }
                    }
                }
            )
        );
    }

    @IsTest
    static void buildInputPayload_includesAteAliases() {
        AcademicTermEnrollment ate = new AcademicTermEnrollment(
            Id = 'a0B000000000001AAA',
            AcademicTermId = 'a0C000000000001AAA',
            TermGradePointAverage = 3.7
        );

        Map<String, Object> payload =
            KenATEPolicyEvaluationAction.buildInputPayload(ate, null, 'SampleExpressionSet');

        System.assertEquals('a0B000000000001AAA', (String) payload.get('AcademicTermEnrollmentId'));
        System.assertEquals('a0C000000000001AAA', (String) payload.get('AcademicTermId'));
        System.assertEquals('3.7', payload.get('TermGradePointAverage'));
        System.assertEquals('SampleExpressionSet', payload.get('expressionSetApiName'));
    }

    @IsTest
    static void buildUnrecognizedOutputMessage_containsSerializedPayload() {
        String message = KenATEPolicyEvaluationAction.buildUnrecognizedOutputMessage(
            new Map<String, Object>{
                'simulationResults' => new List<Object>{
                    new Map<String, Object>{
                        'name' => 'unexpectedKey',
                        'value' => 'unexpectedValue'
                    }
                }
            }
        );

        System.assert(message.contains('Raw output:'));
        System.assert(message.contains('unexpectedKey'));
    }
}