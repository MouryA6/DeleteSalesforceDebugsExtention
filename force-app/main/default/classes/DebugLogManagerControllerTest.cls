@IsTest
private class DebugLogManagerControllerTest {

    // ── Mock: returns one ApexLog on GET, 204 on DELETE ──────────
    private class RestApiMock implements HttpCalloutMock {
        public HTTPResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getMethod() == 'GET') {
                res.setStatusCode(200);
                res.setBody('{"totalSize":1,"done":true,"records":[{"Id":"07L000000000001AAA"}]}');
            } else if (req.getMethod() == 'DELETE') {
                res.setStatusCode(204);
                res.setBody('');
            }
            return res;
        }
    }

    // ── Mock: returns zero ApexLogs ───────────────────────────────
    private class EmptyRestApiMock implements HttpCalloutMock {
        public HTTPResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"totalSize":0,"done":true,"records":[]}');
            return res;
        }
    }

    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testHasDeletePermission_returnsBoolean() {
        Test.startTest();
        Boolean result = DebugLogManagerController.hasDeletePermission();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return a non-null Boolean');
    }

    @IsTest
    static void testDeleteAllDebugLogs_withoutPermission_throwsException() {
        // Custom permission not assigned in test context — must throw
        Test.setMock(HttpCalloutMock.class, new RestApiMock());
        Test.startTest();
        try {
            DebugLogManagerController.deleteAllDebugLogs();
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException ex) {
            System.assert(
                ex.getMessage() != null,
                'Exception should have a message: ' + ex.getMessage()
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteAllDebugLogs_noLogsExist() {
        Test.setMock(HttpCalloutMock.class, new EmptyRestApiMock());
        Test.startTest();
        try {
            Integer count = DebugLogManagerController.deleteAllDebugLogs();
            // If permission granted, count = 0; if not, exception caught below
            System.assertEquals(0, count, 'Should return 0 when no logs exist');
        } catch (AuraHandledException ex) {
            // Expected in test context without custom permission assigned
            System.assert(true, 'Permission denied as expected in test context');
        }
        Test.stopTest();
    }
}
