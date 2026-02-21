/**
 * Apex controller for the deleteDebugLogs LWC utility bar component.
 * Gated by the custom permission "Delete_Debug_Logs" — only users
 * explicitly assigned this permission can execute the delete.
 *
 * NOTE: ApexLog is a read-only Setup object — standard DML delete is NOT allowed.
 * Each log must be deleted individually via the REST API DELETE endpoint.
 */
public with sharing class DebugLogManagerController {

    private static final String CUSTOM_PERMISSION = 'Delete_Debug_Logs';

    /**
     * Returns whether the running user has the Delete_Debug_Logs custom permission.
     * Called on component load to show/hide the button.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean hasDeletePermission() {
        return FeatureManagement.checkPermission(CUSTOM_PERMISSION);
    }

    /**
     * Queries all ApexLog Ids via REST API, then deletes each one individually.
     * Throws AuraHandledException if the user lacks the custom permission.
     * Returns the count of successfully deleted logs.
     */
    @AuraEnabled
    public static Integer deleteAllDebugLogs() {
        if (!FeatureManagement.checkPermission(CUSTOM_PERMISSION)) {
            throw new AuraHandledException(
                'Access Denied: You do not have permission to delete debug logs.'
            );
        }

        String baseUrl    = URL.getOrgDomainUrl().toExternalForm();
        String sessionId  = UserInfo.getSessionId();
        String apiVersion = 'v62.0';

        // ── Step 1: Query all ApexLog Ids via REST API ────────────
        String query = EncodingUtil.urlEncode('SELECT Id FROM ApexLog', 'UTF-8');

        HttpRequest queryReq = new HttpRequest();
        queryReq.setMethod('GET');
        queryReq.setEndpoint(baseUrl + '/services/data/' + apiVersion + '/query?q=' + query);
        queryReq.setHeader('Authorization', 'Bearer ' + sessionId);
        queryReq.setHeader('Content-Type', 'application/json');

        HttpResponse queryRes = new Http().send(queryReq);

        if (queryRes.getStatusCode() != 200) {
            throw new AuraHandledException(
                'Failed to query ApexLogs: [' + queryRes.getStatusCode() + '] ' + queryRes.getBody()
            );
        }

        Map<String, Object> parsed  = (Map<String, Object>) JSON.deserializeUntyped(queryRes.getBody());
        List<Object>        records = (List<Object>) parsed.get('records');

        if (records == null || records.isEmpty()) {
            return 0;
        }

        // ── Step 2: Delete each log via REST API DELETE ───────────
        Integer deleted = 0;
        for (Object rec : records) {
            Map<String, Object> recMap = (Map<String, Object>) rec;
            String logId = (String) recMap.get('Id');

            HttpRequest delReq = new HttpRequest();
            delReq.setMethod('DELETE');
            delReq.setEndpoint(baseUrl + '/services/data/' + apiVersion + '/sobjects/ApexLog/' + logId);
            delReq.setHeader('Authorization', 'Bearer ' + sessionId);

            HttpResponse delRes = new Http().send(delReq);

            // 204 = No Content = success
            if (delRes.getStatusCode() == 204) {
                deleted++;
            }
        }

        return deleted;
    }
}
