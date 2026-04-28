/**
 * ************************************************************************************************
 * @className  KenAuraExceptionHelper
 *
 * @description
 *  Standard rethrow helper used by every @AuraEnabled entry point in the Student Portal
 *  backend. Ensures the LWC layer receives a sanitised, friendly `AuraHandledException`
 *  message while the full stack trace is captured in server logs.
 *
 * @author      Student Portal Backend
 * @createdOn   2026
 * ************************************************************************************************
 */
public with sharing class KenAuraExceptionHelper {

    /**
     * @description
     *  Log the full exception then rethrow as AuraHandledException using a friendly
     *  caller-supplied message. Preserves the original type name in the debug log so
     *  server operators can trace the root cause.
     *
     * @param context        Short caller identifier, e.g. 'KenHomeDashboardController.getDashboard'
     * @param friendlyMessage Message surfaced to the LWC client
     * @param cause          Original exception
     */
    public static void throwAuraHandled(String context, String friendlyMessage, Exception cause) {
        System.debug(LoggingLevel.ERROR,
            '[' + context + '] ' + cause.getTypeName() + ': ' + cause.getMessage() +
            '\n' + cause.getStackTraceString());
        // Best-effort audit log write; never let logging hide the real error.
        try {
            String process = context;
            if (String.isNotBlank(context) && context.contains('.')) {
                String head = context.substringBefore('.');
                // Strip 'Ken' prefix and 'Controller' suffix to derive a friendly process label.
                if (head.startsWith('Ken')) { head = head.substring(3); }
                if (head.endsWith('Controller')) { head = head.removeEnd('Controller'); }
                if (head.endsWith('Service')) { head = head.removeEnd('Service'); }
                if (String.isNotBlank(head)) { process = head; }
            }
            KenAuditLogHelper.auditLogRecord(process, context)
                .setErrorMessage(cause != null ? cause.getMessage() : friendlyMessage)
                .setStackTrace(cause != null ? cause.getStackTraceString() : null)
                .create();
        } catch (Exception ignored) {
            System.debug(LoggingLevel.WARN,
                '[KenAuraExceptionHelper] audit log write failed: ' + ignored.getMessage());
        }
        AuraHandledException e = new AuraHandledException(friendlyMessage);
        e.setMessage(friendlyMessage);
        throw e;
    }

    /**
     * @description
     *  Helper for input validation — throws an AuraHandledException with the given
     *  message if `condition` is true. Keeps guard clauses concise at the top of
     *  @AuraEnabled methods.
     */
    public static void rejectIf(Boolean condition, String message) {
        if (condition) {
            throw new AuraHandledException(message);
        }
    }
}