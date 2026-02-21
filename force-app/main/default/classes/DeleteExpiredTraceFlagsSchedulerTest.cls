@IsTest
private class DeleteExpiredTraceFlagsSchedulerTest {

    @IsTest
    static void testSchedulerExecutesBatch() {
        Test.startTest();
        String jobId = System.schedule(
            'Test Delete Expired TraceFlags',
            '0 0 1 * * ?',
            new DeleteExpiredTraceFlagsScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Scheduler should return a job ID');
    }

    @IsTest
    static void testScheduleDailyDoesNotDuplicate() {
        Test.startTest();
        String firstJobId  = DeleteExpiredTraceFlagsScheduler.scheduleDaily();
        String secondJobId = DeleteExpiredTraceFlagsScheduler.scheduleDaily();
        Test.stopTest();

        System.assertNotEquals(null, firstJobId, 'First schedule call should return a job ID');
        System.assertEquals(null, secondJobId, 'Second schedule call should return null (already scheduled)');
    }

    @IsTest
    static void testAbortExisting() {
        Test.startTest();
        DeleteExpiredTraceFlagsScheduler.scheduleDaily();
        DeleteExpiredTraceFlagsScheduler.abortExisting();
        // After abort, scheduling again should succeed
        String newJobId = DeleteExpiredTraceFlagsScheduler.scheduleDaily();
        Test.stopTest();

        System.assertNotEquals(null, newJobId, 'Should be schedulable after aborting existing job');
    }
}
