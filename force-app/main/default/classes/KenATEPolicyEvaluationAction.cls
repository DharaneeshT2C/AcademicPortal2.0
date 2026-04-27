public with sharing class KenATEPolicyEvaluationAction {
    private static final String ELIGIBLE = 'Eligible';
    private static final String NOT_ELIGIBLE = 'Not Eligible';
    private static final List<String> OUTPUT_KEY_CANDIDATES = new List<String>{
        'var_EligibilityResult',
        'EligibilityResult',
        'eligibility',
        'Eligibility',
        'result',
        'Result',
        'value'
    };
    
    public class Request {
        @InvocableVariable(required=true)
        public Id academicTermEnrollmentId;
    }
    
    public class Response {
        @InvocableVariable
        public String eligibility;
        
        @InvocableVariable
        public Integer evaluatedRuleCount;
        
        @InvocableVariable
        public String message;
    }
    
    private class EvaluationResult {
        String eligibility;
        Integer evaluatedRuleCount = 0;
        String message;
        Map<String, Object> lastOutputParameters;
    }
    
    private class ExpressionSetInvocationResult {
        Boolean success = false;
        Map<String, Object> outputParameters = new Map<String, Object>();
        String message;
    }
    
    @InvocableMethod(
    label='Evaluate Academic Term Policies'
        description='Evaluates all Academic Term policy rules linked to the enrollment Academic Term and returns the final eligibility result.'
        )
    public static List<Response> evaluatePolicies(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }
        
        Set<Id> enrollmentIds = new Set<Id>();
        for (Request requestItem : requests) {
            if (requestItem != null && requestItem.academicTermEnrollmentId != null) {
                enrollmentIds.add(requestItem.academicTermEnrollmentId);
            }
        }
        
        Map<Id, AcademicTermEnrollment> enrollmentById = new Map<Id, AcademicTermEnrollment>();
        if (!enrollmentIds.isEmpty()) {
            enrollmentById = new Map<Id, AcademicTermEnrollment>([
                SELECT Id, AcademicTermId, TermGradePointAverage, Eligibility__c, EnrollmentStatus
                FROM AcademicTermEnrollment
                WHERE Id IN :enrollmentIds
            ]);
        }
        
        for (Request requestItem : requests) {
            Response responseItem = new Response();
            if (requestItem == null || requestItem.academicTermEnrollmentId == null) {
                responseItem.message = 'Academic Term Enrollment Id is required.';
                responses.add(responseItem);
                continue;
            }
            
            AcademicTermEnrollment enrollment = enrollmentById.get(requestItem.academicTermEnrollmentId);
            if (enrollment == null) {
                responseItem.message = 'Academic Term Enrollment not found.';
                responses.add(responseItem);
                continue;
            }
            
            EvaluationResult result = evaluateEnrollment(enrollment);
            responseItem.eligibility = result.eligibility;
            responseItem.evaluatedRuleCount = result.evaluatedRuleCount;
            responseItem.message = result.message;
            responses.add(responseItem);
        }
        
        return responses;
    }
    
    private static EvaluationResult evaluateEnrollment(AcademicTermEnrollment enrollment) {
        EvaluationResult result = new EvaluationResult();
        Integer recognizedOutcomeCount = 0;
        if (enrollment.AcademicTermId == null) {
            result.message = 'Academic Term is missing on the enrollment.';
            return result;
        }

        Id academicTermId = enrollment.AcademicTermId;
        List<AcademicTermPolicyRule> policyRules = [
            SELECT Id, Name, AcademicTermId, PolicyRuleId, UsageType, Description
            FROM AcademicTermPolicyRule
            WHERE AcademicTermId = :academicTermId
        ];

        if (policyRules.isEmpty()) {
            result.message = 'No related academic term policy rules found.';
            return result;
        }

        result.eligibility = ELIGIBLE;
        for (AcademicTermPolicyRule policyRule : policyRules) {
            String expressionSetApiName = resolveExpressionSetApiName(policyRule.PolicyRuleId);
            if (String.isBlank(expressionSetApiName)) {
                continue;
            }
            
            ExpressionSetInvocationResult invocationResult = invokeExpressionSet(
                expressionSetApiName,
            buildInputPayload(enrollment, policyRule, expressionSetApiName)
                );
            if (!invocationResult.success) {
                result.message = invocationResult.message;
                result.eligibility = null;
                return result;
            }
            
            result.evaluatedRuleCount++;
            result.lastOutputParameters = invocationResult.outputParameters;
            String normalizedEligibility = normalizeEligibilityValue(invocationResult.outputParameters);
            if (normalizedEligibility != null) {
                recognizedOutcomeCount++;
            }
            if (normalizedEligibility == NOT_ELIGIBLE) {
                result.eligibility = NOT_ELIGIBLE;
            }
        }
        
        if (result.evaluatedRuleCount == 0) {
            result.eligibility = null;
            result.message = 'No usable expression sets were found on the related policy rules.';
        } else if (recognizedOutcomeCount == 0) {
            result.eligibility = null;
            result.message = buildUnrecognizedOutputMessage(result.lastOutputParameters);
        }
        
        return result;
    }

    private static String resolveExpressionSetApiName(Id expressionSetId) {
        if (expressionSetId == null) {
            return null;
        }
        ExpressionSet expressionSetRecord = [
            SELECT Id, ApiName
            FROM ExpressionSet
            WHERE Id = :expressionSetId
            LIMIT 1
        ];
        return expressionSetRecord.ApiName;
    }
    
    private static ExpressionSetInvocationResult invokeExpressionSet(
        String expressionSetApiName,
        Map<String, Object> inputPayload
    ) {
        ExpressionSetInvocationResult result = new ExpressionSetInvocationResult();
        
        try {
            Invocable.Action action =
                Invocable.Action.createCustomAction('runExpressionSet', expressionSetApiName);
            action.setInvocationParameter(
                'inputs',
            new List<Map<String, Object>>{ inputPayload }
            );
            
            List<Invocable.Action.Result> actionResults = action.invoke();
            if (actionResults.isEmpty()) {
                result.message = 'Expression Set invocation returned no result.';
                return result;
            }
            
            Invocable.Action.Result actionResult = actionResults[0];
            if (!actionResult.isSuccess()) {
                result.message = 'Expression Set invocation failed: ' +
                    JSON.serialize(actionResult.getErrors());
                return result;
            }
            
            result.success = true;
            Map<String, Object> outputParameters = actionResult.getOutputParameters();
            result.outputParameters = outputParameters == null
                ? new Map<String, Object>()
                : outputParameters;
            return result;
        } catch (Exception ex) {
            result.message =
                'Expression Set invocation failed for ' + expressionSetApiName + ': ' + ex.getMessage();
            return result;
        }
    }
    
    @TestVisible
    private static Map<String, Object> buildInputPayload(
        AcademicTermEnrollment enrollment,
        SObject policyRule,
        String expressionSetApiName
    ) {
        Map<String, Object> payload = new Map<String, Object>();

        // Use the exact field API name expected by the active Expression Set.
        payload.put(
            'TermGradePointAverage',
            enrollment.TermGradePointAverage == null
                ? null
                : String.valueOf(enrollment.TermGradePointAverage)
        );

        // Keep identifiers for traceability/debugging.
        payload.put('AcademicTermEnrollmentId', enrollment.Id);
        payload.put('AcademicTermId', enrollment.AcademicTermId);
        payload.put('expressionSetApiName', expressionSetApiName);

        if (policyRule != null) {
            payload.put('policyRuleId', policyRule.get('Id'));
        }
        
        return payload;
    }
    
    @TestVisible
    private static String normalizeEligibilityValue(Object rawValue) {
        if (rawValue == null) {
            return null;
        }
        
        if (rawValue instanceof String) {
            return normalizeStringValue((String) rawValue);
        }
        if (rawValue instanceof Boolean) {
            return ((Boolean) rawValue) ? ELIGIBLE : NOT_ELIGIBLE;
        }
        if (rawValue instanceof Map<String, Object>) {
            Map<String, Object> valueMap = (Map<String, Object>) rawValue;

            if (valueMap.containsKey('simulationResults')) {
                String normalizedFromSimulation =
                    normalizeSimulationResults(valueMap.get('simulationResults'));
                if (normalizedFromSimulation != null) {
                    return normalizedFromSimulation;
                }
            }

            if (valueMap.containsKey('output')) {
                String normalizedFromOutput = normalizeOutputNode(valueMap.get('output'));
                if (normalizedFromOutput != null) {
                    return normalizedFromOutput;
                }
            }

            for (String keyName : OUTPUT_KEY_CANDIDATES) {
                if (valueMap.containsKey(keyName)) {
                    String normalized = normalizeEligibilityValue(valueMap.get(keyName));
                    if (normalized != null) {
                        return normalized;
                    }
                }
            }
            for (Object nestedValue : valueMap.values()) {
                String normalized = normalizeEligibilityValue(nestedValue);
                if (normalized == NOT_ELIGIBLE) {
                    return NOT_ELIGIBLE;
                }
                if (normalized == ELIGIBLE) {
                    return ELIGIBLE;
                }
            }
            return null;
        }
        if (rawValue instanceof List<Object>) {
            String matchedValue;
            for (Object listItem : (List<Object>) rawValue) {
                String normalized = normalizeEligibilityValue(listItem);
                if (normalized == NOT_ELIGIBLE) {
                    return NOT_ELIGIBLE;
                }
                if (normalized == ELIGIBLE) {
                    matchedValue = ELIGIBLE;
                }
            }
            return matchedValue;
        }

        return normalizeStringValue(String.valueOf(rawValue));
    }

    private static String normalizeSimulationResults(Object rawValue) {
        if (!(rawValue instanceof List<Object>)) {
            return null;
        }

        for (Object item : (List<Object>) rawValue) {
            if (!(item instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> resultRow = (Map<String, Object>) item;
            Object nameValue = resultRow.get('name');
            if (
                nameValue != null &&
                String.valueOf(nameValue) == 'var_EligibilityResult' &&
                resultRow.containsKey('value')
            ) {
                return normalizeEligibilityValue(resultRow.get('value'));
            }
        }
        return null;
    }

    private static String normalizeOutputNode(Object rawValue) {
        if (!(rawValue instanceof Map<String, Object>)) {
            return null;
        }

        Map<String, Object> outputNode = (Map<String, Object>) rawValue;
        if (outputNode.containsKey('calculationResults')) {
            return normalizeCalculationResults(outputNode.get('calculationResults'));
        }

        return null;
    }

    private static String normalizeCalculationResults(Object rawValue) {
        if (!(rawValue instanceof List<Object>)) {
            return null;
        }

        for (Object item : (List<Object>) rawValue) {
            String normalized = normalizeEligibilityValue(item);
            if (normalized != null) {
                return normalized;
            }
        }
        return null;
    }

    @TestVisible
    private static String buildUnrecognizedOutputMessage(Map<String, Object> outputParameters) {
        return 'Expression Set outputs did not contain a recognizable eligibility value. Raw output: ' +
            JSON.serialize(outputParameters);
    }
    
    private static String normalizeStringValue(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }
        
        String normalizedValue = rawValue.trim().toLowerCase();
        if (
            normalizedValue == 'eligible' ||
            normalizedValue == 'pass' ||
            normalizedValue == 'passed' ||
            normalizedValue == 'true'
        ) {
            return ELIGIBLE;
        }
        if (
            normalizedValue == 'not eligible' ||
            normalizedValue == 'not_eligible' ||
            normalizedValue == 'fail' ||
            normalizedValue == 'failed' ||
            normalizedValue == 'false'
        ) {
            return NOT_ELIGIBLE;
        }
        return null;
    }
    
}