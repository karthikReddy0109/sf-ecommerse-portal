public with sharing class Customer360Controller {
    public class Customer360Data{
        @AuraEnabled public Account account = new Account();
        @AuraEnabled public Customer_Loyalty__c loyalty = new Customer_Loyalty__c();
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorMsg;
    }

    @AuraEnabled(cacheable = true)
    public static Customer360Data getCustomer360Data(Id accountId){
        Customer360Data customerDataWrapper = new Customer360Data();
        try{
            Customer_Loyalty__c customerData = [
                SELECT Tier__c, Total_Spend__c, Total_Orders__c, Loyalty_Points__c,Discount_Percent__c, Customer__r.Name, Customer__r.Phone, Customer__r.BillingCity, Customer__r.Industry, Customer__r.BillingState, Customer__c
                FROM Customer_Loyalty__c
                WHERE Customer__c =: accountId
                LIMIT 1
            ];
            customerDataWrapper.account.Name = customerData.Customer__r.Name;
            customerDataWrapper.account.Industry = customerData.Customer__r.Industry;
            customerDataWrapper.account.Phone = customerData.Customer__r.Phone;
            customerDataWrapper.account.BillingCity = customerData.Customer__r.BillingCity;
            customerDataWrapper.loyalty.Tier__c = customerData.Tier__c;
            customerDataWrapper.loyalty.Total_Spend__c = customerData.Total_Spend__c;
            customerDataWrapper.loyalty.Total_Orders__c = customerData.Total_Orders__c;
            customerDataWrapper.loyalty.Loyalty_Points__c = customerData.Loyalty_Points__c;
            customerDataWrapper.loyalty.Discount_Percent__c = customerData.Discount_Percent__c;
            customerDataWrapper.account.BillingState = customerData.Customer__r.BillingState;
            customerDataWrapper.isSuccess = true;
        }catch(System.QueryException qe){
            customerDataWrapper.isSuccess = false;
            customerDataWrapper.errorMsg = qe.getMessage();
        }catch(Exception e){
            customerDataWrapper.isSuccess = false;
            customerDataWrapper.errorMsg = e.getMessage();
        }
        return customerDataWrapper;
    }

    @AuraEnabled(cacheable = true)
    public static List<Order__c> getRecentOrders(Id accountId){
        List<Order__c> recentOrders = new List<Order__c>();
        recentOrders = [
            SELECT Id, Final_Amount__c, Status__c, Order_Date__c, Name, Payment_Status__c, Customer__c
            FROM Order__c
            WHERE Customer__c =: accountId
            ORDER BY Order_Date__c DESC
            LIMIT 10 
        ];
        return recentOrders;
    }

    @AuraEnabled(cacheable = true)
    public static List<Case> getOpenCases(Id accountId){
        List<Case> cases = [
            SELECT Id, CaseNumber, Subject, Status, Priority, CreatedDate, AccountId
            FROM Case
            WHERE Status != 'Closed' AND AccountId =: accountId
            LIMIT 10
        ];
        return cases;
    }
}