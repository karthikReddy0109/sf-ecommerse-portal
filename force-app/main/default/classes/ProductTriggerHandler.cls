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
            List<Id> productsToProcess = new List<Id>(productIdSet);
            // Integer chunkSize = 200;
            // for(Integer i = 0; i < productsToProcess.size(); i += chunkSize){
            //     Integer endIndex = Math.min(i + chunkSize, productsToProcess.size());
            //     List<Id> chunk = productsToProcess.subList(i, endIndex);
            //     System.enqueueJob(new ProductRestockQueueable(chunk, 0));
            // }
            List<Id> firstChunk = productsToProcess.size() > 200 ? new List<Id>(productsToProcess.subList(0, 200)) : productsToProcess.size();
            List<Id> remaining = productsToProcess.size() > 200 ? new List<Id>(productsToProcess.subList(200, productsToProcess.size())) : new List<Id>();
            System.enqueueJob(new ProductRestockQueueable(firstChunk, remaining, 0));
        }
    }
}