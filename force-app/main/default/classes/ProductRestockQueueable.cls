public with sharing class ProductRestockQueueable implements Queueable, Database.AllowsCallouts {
    List<Id> currentChunk;
    List<Id> remaining;
    Integer retryCount;
    public ProductRestockQueueable(List<Id> firstChunk, List<Id> remaining, Integer retryCount){
        this.currentChunk = firstChunk;
        this.remaining = remaining;
        this.retryCount = retryCount;
    }

    public class RestockRequestPayload{
        public Id productId;
        public String productCode;
        public String productName;
        public Decimal currentStock;
        public Decimal restockThreshold;
        public Decimal quantityRequested;
    }

    private List<Product__c> getProductsToProcess(){
        try{
            return [
                SELECT Id, Product_Code__c, 
                Name, Stock_Quantity__c, Restock_Threshold__c
                FROM Product__c 
                WHERE Id IN :productList
                FOR UPDATE
            ];
        }catch(QueryException e){
            System.debug('SOQL failed with :' + e.getMessage());
            return new List<Product__c>();  
        }
    }

    private List<RestockRequestPayload> buildRestockRequestPayload(List<Product__c> products){
        List<RestockRequestPayload> payload = new List<RestockRequestPayload>();
        for(Product__c product : products){
            RestockRequestPayload payloadItem = new RestockRequestPayload();
            payloadItem.productId = product.Id;
            payloadItem.productName = product.Name;
            payloadItem.productCode = product.Product_Code__c;
            payloadItem.currentStock = product.Stock_Quantity__c;
            payloadItem.restockThreshold = product.Restock_Threshold__c;
            payloadItem.quantityRequested = product.Restock_Threshold__c * 3;
            payload.add(payloadItem);
        }
        return payload;
    }

    private void updateProductsRestockStatus(List<Product__c> products){
        List<Product__c> toUpdate = new List<Product__c>();
        for(Product__c product : products){
            toUpdate.add(new Product__c(
                Id = product.Id,
                Restock_Status__c = 'Requested'
            ));
        }
        if(!toUpdate.isEmpty()){
            try{
                update toUpdate;
            }catch(Exception e){
                System.debug('Failed to update restock status: ' + e.getMessage());
            }
        }
    }

    private void logAPIError(HttpResponse res){
        try{
            Sync_Error_Log__c errorLog = new Sync_Error_Log__c(
                Error_Message__c = res.getBody(),
                Object_Name__c = 'Product__c',
                Status__c = retryCount >= 3 ? 'Failed' : 'Retrying',
                Retry_Count__c = retryCount
            );
            insert errorLog;
        }catch(Exception e){
            System.debug('Failed to log error: ' + e.getMessage());
        }
    }

    public void execute(QueueableContext qc){
        List<Product__c> products = getProductsToProcess();
        List<RestockRequestPayload> payload = buildRestockRequestPayload(products);
        HttpResponse response = HttpService.doPost('DUMMY URL', JSON.serialize(payload));
        if(response.getStatusCode() == 200){
            updateProductsRestockStatus(products);
            if(!remaining.isEmpty()){
                List<Id> nextChunk = remaining.size() > 200
                ? new List<Id>(remaining.subList(0, 200))
                : remaining;
                List<Id> nextRemaining = remaining.size() > 200
                ? new List<Id>(remaining.subList(200, remaining.size()))
                : new List<Id>();
                System.enqueueJob(new ProductRestockQueueable(nextChunk, nextRemaining, 0));
            }
        }else{
            logAPIError(response);
            if(retryCount < 3){
                System.enqueueJob(new ProductRestockQueueable(currentChunk, remaining, retryCount + 1));
            }else{
                markProductsAsFailed(products);
                if(!remaining.isEmpty()){
                List<Id> nextChunk = remaining.size() > 200
                    ? new List<Id>(remaining.subList(0, 200))
                    : remaining;
                List<Id> nextRemaining = remaining.size() > 200
                    ? new List<Id>(remaining.subList(200, remaining.size()))
                    : new List<Id>();
                System.enqueueJob(new ProductRestockQueueable(nextChunk, nextRemaining, 0));
            }
            }
        }
    }
}