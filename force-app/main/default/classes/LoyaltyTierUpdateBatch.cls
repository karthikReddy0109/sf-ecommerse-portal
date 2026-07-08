public with sharing class LoyaltyTierUpdateBatch implements Database.Batchable<SObject>, Database.Stateful{

    Integer totalRecordsProcessed;
    Integer totalTierChangesMade;
    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator(
            'SELECT Id, Customer__c, Tier__c, Total_Spend__c, Discount_Percent__c, ' + 'Tier_Updated_Date__c ' +
            'FROM Customer_Loyalty__c ' +
            'WHERE Customer_Loyalty__c != null'
        );
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope){
        List<Customer_Loyalty__c> toUpdate = new List<Customer_Loyalty__c>();
        Map<String, Decimal> tierToDiscountMap = new Map<String, Decimal>();
        for(Discount_Rule__mdt rule : Discount_Rule__mdt.getAll().values()){
            tierToDiscountMap.put(rule.Tier__c, rule.Discount_Percent__c);
        }
        for(Customer_Loyalty__c cl : scope){
            String newTier = CustomerLoyaltyService.recalculateTier(cl);
            if(cl.Tier__c != newTier){
                Customer_Loyalty__c loyaltyRec = new Customer_Loyalty__c();
                loyaltyRec.Id = cl.Id;
                loyaltyRec.Tier__c = newTier;
                loyaltyRec.Tier_Updated_Date__c = System.today();
                loyaltyRec.Discount_Percent__c = tierToDiscountMap.containsKey(newTier) ? tierToDiscountMap.get(newTier) : 0;
                toUpdate.add(loyaltyRec);
            }
        }
        try{
            if(!toUpdate.isEmpty()){
                insert toUpdate;
                totalTierChangesMade += toUpdate.size();
            }
        }catch(Exception e){
            System.debug('Error processing batch : ' + e.getMessage());
        } 
        totalRecordsProcessed += scope.size();
    }

    public void finish(Database.BatchableContext bc){
        // Implement email message
    }
}