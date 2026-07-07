public with sharing class CustomerLoyaltyService {

    public class DiscountResult {
        @AuraEnabled public String tierApplied;
        @AuraEnabled public Decimal discountPercent;
        @AuraEnabled public Decimal discountAmount;
        @AuraEnabled public Boolean discountApplied;
        @AuraEnabled public String reason; // why discount was not applied if discountApplied = false
    }

    public static void initializeLoyalty(List<Account> accounts){
        Set<Id> accountIdSet = new Set<Id>();
        for(Account acc : accounts){
            accountIdSet.add(acc.Id);
        }
        try{
            Map<Id, Customer_Loyalty__c> idToCustomerLoyaltyMap = new Map<Id, Customer_Loyalty__c>(
                [SELECT Id, Customer__c, Name FROM Customer_Loyalty__c WHERE Customer__c IN: accountIdSet]
            );
            List<Customer_Loyalty__c> loyaltyRecordsToInsert = new List<Customer_Loyalty__c>();
            for(Account acc : accounts){
                if(!idToCustomerLoyaltyMap.containsKey(acc.Id)){
                    Customer_Loyalty__c loyaltyRec = new Customer_Loyalty__c(
                        Name = 'CUST ' + acc.Name,
                        Customer__c = acc.Id,
                        Tier__c = 'Bronze'
                    );
                    loyaltyRecordsToInsert.add(loyaltyRec);
                }
            }
            if(!loyaltyRecordsToInsert.isEmpty()){
                insert loyaltyRecordsToInsert;
            }
        }catch(QueryException qe){
            throw new AuraHandledException('SOQL failed : ' + qe.getMessage());
        }catch(DmlException de){
            throw new AuraHandledException('DML failed : ' + qe.getMessage());
        }catch(Exception e){
            throw new AuraHandledException('An exception occured : ' + e.getMessage());
        }
    }

    public static DiscountResult applyLoyaltyDiscount(Id accountId, Decimal orderAmount){
        List<Customer_Loyalty__c> custLoyalty = [
            SELECT Id, Tier__c, Customer__c
            FROM Customer_Loyalty__c
            WHERE Customer__c =: accountId
        ];
        if(custLoyalty.isEmpty()){
            return new DiscountResult(
                discountApplied = false,
                reason = 'No loyalty record found'
            );
        }
        String customerTier = custLoyalty[0].Tier__c;
        Map<String, Discount_Rule__mdt> tierToDiscount = new Map<String, Discount_Rule__mdt>();
        for(Discount_Rule__mdt rule : Discount_Rule__mdt.getAll().values()){
            tierToDiscount.put(rule.Tier__c, rule);
        }
        Decimal discountPercentage = tierToDiscount.containsKey(customerTier) ? tierToDiscount.get(customerTier).Discount_Percent__c : 0;
        Decimal minOrderAmount = tierToDiscount.containsKey(customerTier) ? tierToDiscount.get(customerTier).Min_Order_Amount__c : 0;
        if(orderAmount < minOrderAmount){
            return new DiscountResult(
                discountApplied = false,
                reason = 'Order below minimum threshold'
            );
        }
        Decimal discountAmount = orderAmount * (discountPercentage / 100);
        DiscountResult result = new DiscountResult();
        result.discountAmount = discountAmount;
        result.discountApplied = true;
        result.discountPercent = discountPercentage;
        result.tierApplied = customerTier;
        return result;
    }

    // Build re calculate tier method
}