public with sharing class AccountTriggerHandler {
    public static void handleAfterInsert(List<Account> newAccounts){
        CustomerLoyaltyService.initializeLoyalty(newAccounts);
    }
}