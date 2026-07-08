public with sharing class ProductTriggerHandler {
    private static final Integer CHUNK_SIZE = 200;

    private static List<Id> getChunk(List<Id> productIds, Integer startIndex){
        List<Id> chunk = new List<Id>();
        Integer endIndex = startIndex + CHUNK_SIZE;
        if(endIndex > productIds.size()){
            endIndex = productIds.size();
        }
        for(Integer i = startIndex; i < endIndex; i++){
            chunk.add(productIds[i]);
        }
        return chunk;
    }

    private static List<Id> getRemaining(List<Id> productIds, Integer startIndex){
        List<Id> remaining = new List<Id>();
        for(Integer i = startIndex; i < productIds.size(); i++){
            remaining.add(productIds[i]);
        }
        return remaining;
    }

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
            List<Id> firstChunk = getChunk(productsToProcess, 0);
            List<Id> remaining = productsToProcess.size() > CHUNK_SIZE ? getRemaining(productsToProcess, CHUNK_SIZE) : new List<Id>();
            System.enqueueJob(new ProductRestockQueueable(firstChunk, remaining, 0));
        }
    }
}
