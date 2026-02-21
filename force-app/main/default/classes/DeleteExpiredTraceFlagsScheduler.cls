/**
 * Scheduler for DeleteExpiredTraceFlagsBatch.
 * Schedules the batch to run daily to clean up UserTraceFlags
 * that expired more than 2 days ago.
 *
 * To schedule from Anonymous Apex (runs every day at 1:00 AM):
 *   DeleteExpiredTraceFlagsScheduler.scheduleDaily();
 *
 * To manually abort and re-schedule:
 *   DeleteExpiredTraceFlagsScheduler.abortExisting();
 *   DeleteExpiredTraceFlagsScheduler.scheduleDaily();
 */
public with sharing class DeleteExpiredTraceFlagsScheduler implements Schedulable {

    private static final String JOB_NAME = 'Delete Expired UserTraceFlags Daily';
    // Cron: every day at 01:00 AM
    private static final String DAILY_CRON = '0 0 1 * * ?';

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new DeleteExpiredTraceFlagsBatch(), 200);
    }

    /**
     * Schedules the daily job if it is not already scheduled.
     * Safe to call multiple times — will not create duplicates.
     */
    public static String scheduleDaily() {
        if (isAlreadyScheduled()) {
            System.debug('Scheduler already active: ' + JOB_NAME);
            return null;
        }
        return System.schedule(JOB_NAME, DAILY_CRON, new DeleteExpiredTraceFlagsScheduler());
    }

    /**
     * Aborts all scheduled jobs with the matching job name.
     */
    public static void abortExisting() {
        for (CronTrigger ct : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
              AND State NOT IN ('DELETED', 'COMPLETE')
        ]) {
            System.abortJob(ct.Id);
        }
    }

    private static Boolean isAlreadyScheduled() {
        return [
            SELECT COUNT()
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
              AND State NOT IN ('DELETED', 'COMPLETE')
        ] > 0;
    }
}
