public with sharing class LoyaltyTierUpdateScheduler implements Schedulable {
    public void execute(SchedulableContext sc){
        Database.executeBatch(new LoyaltyTierUpdateBatch(), 200);
    }
}