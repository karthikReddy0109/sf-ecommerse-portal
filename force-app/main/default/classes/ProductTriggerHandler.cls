public with sharing class ProductTriggerHandler {
    public static void handleAfterUpdate(List<Product__c> newProducts, Map<Id, Product__c> oldMap){
        Set<Id> productIdSet = new Set<Id>();
        for(Product__c product : newProducts){
            if(oldMap.get(product.Id) != null && product.Stock_Quantity__c != oldMap.get(product.Id).Stock_Quantity__c){
                if((product.Stock_Quantity__c < product.Restock_Threshold__c) && (product.Restock_Status__c != 'Requested' && product.Restock_Status__c != 'Fulfilled')){
                    productIdSet.add(product.Id);
                }
            }
        }
        if(!productIdSet.isEmpty()){
            System.enqueueJob(new ProductRestockQueueable(new List<Id>(productIdSet)));
        }
    }
}