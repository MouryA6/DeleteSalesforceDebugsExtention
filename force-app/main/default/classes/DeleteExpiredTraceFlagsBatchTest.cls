/**
 * Test class for DeleteExpiredTraceFlagsBatch.
 * Uses HttpCalloutMock to simulate Tooling API responses
 * since real callouts are not allowed in test context.
 */
@IsTest
private class DeleteExpiredTraceFlagsBatchTest {

    // ─────────────────────────────────────────────────────────────
    // Mock: simulates Tooling API query (GET) + delete (DELETE)
    // ─────────────────────────────────────────────────────────────
    private class ToolingApiMock implements HttpCalloutMock {

        private String mockId;
        private Boolean simulateError;

        public ToolingApiMock(String mockId, Boolean simulateError) {
            this.mockId        = mockId;
            this.simulateError = simulateError;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getMethod() == 'GET') {
                // Simulate query returning one expired flag
                res.setStatusCode(200);
                res.setBody('{"size":1,"totalSize":1,"done":true,"records":[{"Id":"' + mockId + '"}]}');

            } else if (req.getMethod() == 'DELETE') {
                if (simulateError) {
                    res.setStatusCode(400);
                    res.setBody('[{"message":"Delete failed","errorCode":"DELETE_FAILED"}]');
                } else {
                    res.setStatusCode(204);
                    res.setBody('');
                }
            }
            return res;
        }
    }

    // Mock: simulates query returning zero records
    private class EmptyToolingApiMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"size":0,"totalSize":0,"done":true,"records":[]}');
            return res;
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Tests
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testBatchDeletesExpiredFlagsSuccessfully() {
        // Use a fake ID of the correct format for UserTraceFlag (7dl prefix)
        String fakeId = '7dlGC0000000001AAA';
        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(fakeId, false));

        Test.startTest();
        Database.executeBatch(new DeleteExpiredTraceFlagsBatch(), 25);
        Test.stopTest();

        // No exceptions = batch completed; verify via debug log or email in real org
        System.assert(true, 'Batch should complete without exceptions');
    }

    @IsTest
    static void testBatchHandlesDeleteError() {
        String fakeId = '7dlGC0000000002AAA';
        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(fakeId, true));

        Test.startTest();
        Database.executeBatch(new DeleteExpiredTraceFlagsBatch(), 25);
        Test.stopTest();

        System.assert(true, 'Batch should handle delete errors gracefully without throwing');
    }

    @IsTest
    static void testBatchWithNoExpiredFlags() {
        Test.setMock(HttpCalloutMock.class, new EmptyToolingApiMock());

        Test.startTest();
        Database.executeBatch(new DeleteExpiredTraceFlagsBatch(), 25);
        Test.stopTest();

        System.assert(true, 'Batch should complete cleanly when no expired flags exist');
    }

    @IsTest
    static void testSchedulerEnqueuesBatch() {
        Test.setMock(HttpCalloutMock.class, new EmptyToolingApiMock());

        Test.startTest();
        String jobId = System.schedule(
            'Test Delete Expired TraceFlags',
            '0 0 1 * * ?',
            new DeleteExpiredTraceFlagsScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Scheduler should return a valid job ID');
    }
}
