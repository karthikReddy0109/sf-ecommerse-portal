public class ValidateOrderQueueable implements Queueable {
	Set<Id> orderIdSet;
    public ValidateOrderQueueable(Set<Id> orderIdSet){
        this.orderIdSet = orderIdSet;
    }
    
    private List<Order_Line_Item__c> getOrderLineItemsForOrders(){
        List<Order_Line_Item__c> orderLineItems = [
            SELECT Id, Product__c, Quantity__c, Product__r.Name, Product__r.Stock_Quantity__c, Order__c
            FROM Order_Line_Item__c
            WHERE Order__c IN: orderIdSet
        ];
        return orderLineItems;
    }
    
    private Set<Id> validateStock(Map<Id, List<Order_Line_Item__c>> orderToOrderLineItems){
        List<Order__c> ordersToUpdate = new List<Order__c>();
        Set<Id> successfulOrderIds = new Set<Id>();
        for(Id orderId : orderIdSet){
            List<Order_Line_Item__c> lineItems = orderToOrderLineItems.get(orderId);
            if(lineItems == null || lineItems.isEmpty()) continue;
            Boolean isValidationFailed = false;
            for(Order_Line_Item__c lineItem : lineItems){
                if(lineItem.Product__r == null) {
                    isValidationFailed = true;
                    break;
                }
                if(lineItem.Quantity__c > lineItem.Product__r.Stock_Quantity__c){
                    isValidationFailed = true;
                    break;
                }
            }
            Order__c order = new Order__c();
            order.Id = orderId;
            if(isValidationFailed){
                String errorMsg = 'Insufficient stock for: ' + lineItem.Product__r.Name + 
                  '. Available: ' + lineItem.Product__r.Stock_Quantity__c + 
                  ', Requested: ' + lineItem.Quantity__c;
                order.Notes__c = errorMsg;
                order.Status__c = 'Failed';
                order.Notes__c = 'Validation failed: insufficient stock for one or more products';
            }else{
                order.Processing_Stage__c = 'Validated';
                successfulOrderIds.add(orderId);
            }
            ordersToUpdate.add(order);
        }
        if(!ordersToUpdate.isEmpty()){
            update ordersToUpdate;
        }
        return successfulOrderIds;
    }
    
    public void execute(QueueableContext qc){
        try{
            List<Order_Line_Item__c> lineItems = getOrderLineItemsForOrders();
            Map<Id, List<Order_Line_Item__c>> orderToOrderLineItems = new Map<Id, List<Order_Line_Item__c>>();
            for(Order_Line_Item__c item : lineItems){
                if(!orderToOrderLineItems.containsKey(item.Order__c)){
                    orderToOrderLineItems.put(item.Order__c, new List<Order_Line_Item__c>());
                }
                orderToOrderLineItems.get(item.Order__c).add(item);
            }
            Set<Id> successfulOrderIds = validateStock(orderToOrderLineItems);
            if(!successfulOrderIds.isEmpty()){
                System.enqueueJob(new PaymentGatewayService(successfulOrderIds));
            }
            
        }catch(Exception e){
            System.debug('Validation failed');
        }
        
    }
}