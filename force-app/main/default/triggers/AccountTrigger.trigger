trigger AccountTrigger on Account (after insert) {
    AccountTriggerHandler.handleAfterInsert(Trigger.New);
}