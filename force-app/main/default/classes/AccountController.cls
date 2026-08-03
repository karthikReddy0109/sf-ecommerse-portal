public with sharing class AccountController {
    public class DuplicateAccountDetectorWrapper{
        @AuraEnabled public Boolean isDuplicate;
        @AuraEnabled public Boolean isSuccess;
        // @AuraEnabled public String exceptionMessage;
    }
    @AuraEnabled(cacheable = true)
    public static DuplicateAccountDetectorWrapper findAccount(String accountName){
        DuplicateAccountDetectorWrapper result = new DuplicateAccountDetectorWrapper();
        List<Account> acc = [
                SELECT Id, Name 
                FROM Account
                WHERE Name =: accountName
            ];
        result.isSuccess = true;
        if(!acc.isEmpty()){
            result.isDuplicate = true;
        }else{
            result.isDuplicate = false;
        }
        return result;
    }
}