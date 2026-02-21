/**
 * Batch class to delete expired UserTraceFlags.
 *
 * WHY TOOLING API:
 *   UserTraceFlag is a Tooling API-only object. It is NOT queryable via
 *   standard SOQL or Database.getQueryLocator(). The only way to query it
 *   in Apex is via an HTTP callout to the Tooling API REST endpoint.
 *
 * HOW IT WORKS:
 *   1. start()  — calls Tooling API to get Ids of flags expired > 2 days ago.
 *   2. execute() — deletes each Id via Tooling API DELETE REST callout.
 *   3. finish()  — sends a summary email to the running user.
 *
 * SETUP REQUIRED:
 *   - Named Credential named "SalesforceToolingAPI" pointing to your org's
 *     base URL (e.g. https://yourorg.my.salesforce.com) with "Named Principal"
 *     auth using OAuth (Session ID or Connected App).
 *   - OR: replace callout:SalesforceToolingAPI with URL.getOrgDomainUrl().toExternalForm()
 *     and pass the session ID header manually (see comments below).
 */
public with sharing class DeleteExpiredTraceFlagsBatch implements Database.Batchable<Id>, Database.Stateful, Database.AllowsCallouts {

    private Integer       totalDeleted = 0;
    private List<String>  errors       = new List<String>();
    private List<Id>      flagIds      = new List<Id>();

    // ─────────────────────────────────────────────────────────────
    // start: query expired flag Ids via Tooling API
    // ─────────────────────────────────────────────────────────────
    public Iterable<Id> start(Database.BatchableContext bc) {
        // Cutoff: 2 days ago
        Datetime cutoff = Datetime.now().addDays(-2);

        // Format for SOQL used in Tooling API query param
        String cutoffStr = cutoff.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');

        // IMPORTANT: The Tooling API object name is "TraceFlag" (NOT "UserTraceFlag").
        // "UserTraceFlag" is only the UI label. LogType = 'USER_DEBUG' filters to user trace flags.
        String query = EncodingUtil.urlEncode(
            'SELECT Id FROM TraceFlag WHERE LogType = \'USER_DEBUG\' AND ExpirationDate <= ' + cutoffStr,
            'UTF-8'
        );

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(
            URL.getOrgDomainUrl().toExternalForm() +
            '/services/data/v62.0/tooling/query?q=' + query
        );
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res  = new Http().send(req);
        String       body = res.getBody();

        if (res.getStatusCode() != 200) {
            throw new CalloutException(
                'Tooling API query failed [' + res.getStatusCode() + ']: ' + body
            );
        }

        // Parse JSON: {"records":[{"Id":"..."},{"Id":"..."}]}
        Map<String, Object> parsed  = (Map<String, Object>) JSON.deserializeUntyped(body);
        List<Object>        records = (List<Object>) parsed.get('records');

        for (Object rec : records) {
            Map<String, Object> recMap = (Map<String, Object>) rec;
            flagIds.add((Id) recMap.get('Id'));
        }

        System.debug('UserTraceFlags to delete: ' + flagIds.size());
        return flagIds;
    }

    // ─────────────────────────────────────────────────────────────
    // execute: delete each flag via Tooling API DELETE callout
    // ─────────────────────────────────────────────────────────────
    public void execute(Database.BatchableContext bc, List<Id> scope) {
        for (Id flagId : scope) {
            HttpRequest req = new HttpRequest();
            req.setMethod('DELETE');
            req.setEndpoint(
                URL.getOrgDomainUrl().toExternalForm() +
                '/services/data/v62.0/tooling/sobjects/TraceFlag/' + flagId
            );
            req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());

            HttpResponse res = new Http().send(req);

            // 204 = success (No Content)
            if (res.getStatusCode() == 204) {
                totalDeleted++;
            } else {
                errors.add(
                    'Failed to delete UserTraceFlag ' + flagId +
                    ' | HTTP ' + res.getStatusCode() +
                    ' | ' + res.getBody()
                );
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // finish: log summary to debug log
    // ─────────────────────────────────────────────────────────────
    public void finish(Database.BatchableContext bc) {
        System.debug('DeleteExpiredTraceFlagsBatch completed. Total deleted: ' + totalDeleted);
        if (!errors.isEmpty()) {
            System.debug('Errors: ' + String.join(errors, '\n'));
        }
    }
}
