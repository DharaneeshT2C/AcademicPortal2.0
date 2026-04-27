/**
 * KAI assistant LLM integration scaffold (Anthropic Claude / OpenAI / Einstein GPT).
 *
 * To activate Anthropic Claude in production:
 *   1. Setup → Named Credentials → New
 *      - Name: Anthropic_LLM
 *      - URL: https://api.anthropic.com/v1
 *      - Auth Protocol: Anonymous
 *      - Allow Merge Fields in HTTP Header: true
 *      - Header: X-API-Key = <your_anthropic_key>
 *      - Header: anthropic-version = 2023-06-01
 *   2. Optionally add Setup → CSP Trusted Sites for api.anthropic.com.
 *
 * Falls back gracefully to a rule-based reply if the Named Credential isn't
 * configured (so dev/sandbox keep working without keys).
 */
public with sharing class KaiLlmService {

    public class LlmException extends Exception {}

    /**
     * Generate an assistant reply for the given user message.
     * Returns the reply text. Falls back to a rule-based response if the LLM
     * Named Credential isn't reachable.
     */
    public static String generateReply(String userMessage, String studentContext) {
        if (String.isBlank(userMessage)) return 'How can I help?';
        try {
            return callAnthropic(userMessage, studentContext);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'LLM unavailable, using rule-based reply: ' + e.getMessage());
            return ruleBasedReply(userMessage);
        }
    }

    private static String callAnthropic(String userMessage, String studentContext) {
        String systemPrompt =
            'You are KAI, an assistant inside a student portal. ' +
            'Be concise (under 80 words), friendly, factual. ' +
            'Use the student context below if relevant. Never invent grades, fees, or dates. ' +
            'If you do not know, say so and point to the relevant portal section. ' +
            'Student context: ' + (studentContext == null ? 'unknown' : studentContext);

        Map<String, Object> body = new Map<String, Object>{
            'model'      => 'claude-haiku-4-5',
            'max_tokens' => 200,
            'system'     => systemPrompt,
            'messages'   => new List<Object>{
                new Map<String, String>{ 'role' => 'user', 'content' => userMessage }
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Anthropic_LLM/messages');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(body));
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new LlmException('LLM error ' + res.getStatusCode() + ': ' + res.getBody().left(150));
        }
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> content = (List<Object>) parsed.get('content');
        if (content == null || content.isEmpty()) throw new LlmException('Empty LLM response');
        Map<String, Object> first = (Map<String, Object>) content[0];
        String text = (String) first.get('text');
        return String.isBlank(text) ? 'I am here to help. What would you like to know?' : text;
    }

    private static String ruleBasedReply(String userMessage) {
        String q = userMessage.toLowerCase();
        if (q.contains('exam'))       return 'Mid-semester exams run Apr 28 – May 5. Your timetable is on the Exams tab.';
        if (q.contains('fee'))        return 'Your next installment of ₹24,000 is due Apr 30. Tap Fee Payment to pay or set up a plan.';
        if (q.contains('attendance')) return 'Your overall attendance is 82%. One subject is below 75% — tap Attendance to see details.';
        if (q.contains('schedule') || q.contains('class')) return 'Your full weekly schedule is on the Schedule tab.';
        if (q.contains('club'))       return 'You can browse and join clubs from Campus Life → Clubs.';
        if (q.contains('hostel') || q.contains('room')) return 'Your hostel allocation details are under Campus Life → Hostel Details.';
        if (q.contains('mess') || q.contains('food'))   return 'This week\'s mess menu is on the Mess Menu tab.';
        if (q.contains('gate pass') || q.contains('leave')) return 'Use Gate Pass to request short leave. Active passes show there too.';
        if (q.contains('result') || q.contains('grade')) return 'Your CGPA is 8.2 across 96 credits earned. Drill into any semester from Results.';
        return 'I can help with classes, exams, fees, attendance, hostel, mess, gate pass, clubs and results.';
    }
}