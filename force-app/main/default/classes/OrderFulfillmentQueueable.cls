public with sharing class OrderFulfillmentQueueable implements Queueable {
    Set<Id> orderIds;
    public OrderFulfillmentQueueable(Set<Id> orderIds) {
        this.orderIds = orderIds;
    }

    private Set<Id> deductStock(){
        List<Order_Line_Item__c> lineItems = [
            SELECT Id, Product__c, Order__c, Quantity__c 
            FROM Order_Line_Item__c
            WHERE Order__c IN: orderIds
            AND Product__c != NULL
        ];
        Set<Id> productIds = new Set<Id>();
        Map<Id, List<Order_Line_Item__c>> orderToOrderLineItems = new Map<Id, List<Order_Line_Item__c>>();
        for(Order_Line_Item__c item : lineItems){
            if(!orderToOrderLineItems.containsKey(item.Order__c)){
                orderToOrderLineItems.put(item.Order__c, new List<Order_Line_Item__c>());
            }
            orderToOrderLineItems.get(item.Order__c).add(item);
            productIds.add(item.Product__c);
        }
        if(productIds.isEmpty()) return new Set<Id>();
        // Get products
        Map<Id, Product__c> idToProductMap = new Map<Id, Product__c>(
            [
                SELECT Id, 	Stock_Quantity__c
                FROM Product__c
                WHERE Id IN: productIds
                FOR UPDATE
            ]
        );
        // Update products
        List<Product__c> productsToProcess = new List<Product__c>();
        List<Order__c> ordersToUpdate = new List<Order__c>();
        Set<Id> fulfilledOrderIds = new Set<Id>();
        for(Id orderId : orderIds){
            List<Order_Line_Item__c> orderLineItems = orderToOrderLineItems.get(orderId);
            Order__c order = new Order__c();
            order.Id = orderId;
            if(orderLineItems == null || orderLineItems.isEmpty()){
                order.Status__c = 'Failed';
                order.Notes__c = 'No order line items found for the order';
                ordersToUpdate.add(order);
                continue;
            }
            for(Order_Line_Item__c item : orderLineItems){
                Product__c product = new Product__c();
                product.Id = item.Product__c;
                Decimal currQty = idToProductMap.get(item.Product__c).	Stock_Quantity__c;
                if(currQty < item.Quantity__c){
                    order.Status__c = 'Failed';
                    order.Notes__c = 'Insufficient stock for product: ' + item.Product__c;
                    ordersToUpdate.add(order);
                    continue;
                }
                Decimal updatedQty = currQty - item.Quantity__c;
                product.Stock_Quantity__c = updatedQty;
                productsToProcess.add(product);
            }
            order.Processing_Stage__c = 'Fulfilled';
            ordersToUpdate.add(order);
            fulfilledOrderIds.add(orderId);
        }
        
        if(!productsToProcess.isEmpty()){
            update productsToProcess;
        }
        if(!ordersToUpdate.isEmpty()){
            update ordersToUpdate;
        }
        return fulfilledOrderIds;
    }

    public void execute(QueueableContext qc){
        try{
            Set<Id> fulfilledOrderIds = deductStock();
            if(!fulfilledOrderIds.isEmpty()){
                System.enqueueJob(new ShipmentServiceQueueable(fulfilledOrderIds));
            }
        }catch(Exception e){
            System.debug('An exception occured while deducting stock');
        }
        
    }
}