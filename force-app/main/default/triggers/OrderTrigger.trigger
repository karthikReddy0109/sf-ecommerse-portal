trigger OrderTrigger on Order__c (after insert, after update) {
    if(trigger.isAfter && trigger.isInsert){
        OrderTriggerHandler.sendOrderConfirmationEmail(Trigger.New);
    }
    if(trigger.isAfter && trigger.isUpdate){
        OrderTriggerHandler.addLoyaltyPoints(Trigger.New, Trigger.oldMap);
        OrderTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}